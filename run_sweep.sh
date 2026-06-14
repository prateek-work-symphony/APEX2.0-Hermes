#!/bin/bash
set -e

echo "🚀 Booting Automated Delivery Agent..."

# ── Phase 1: The vsts Config Lockout Fix ──────────────────────────────
# Azure DevOps' ghost user (vsts) breaks Node's home directory resolution.
# We force a known HOME so Hermes finds its pre-baked config.yaml and
# NEVER triggers the first-time setup wizard (? Name of the agency).
export HOME=/tmp/safe_home
mkdir -p "$HOME/.hermes"
cp /opt/hermes/config.yaml "$HOME/.hermes/config.yaml"
# Create an empty .env so Hermes doesn't prompt for API keys interactively
touch "$HOME/.hermes/.env"

# ── Phase 2: Headless Environment Lockdown ────────────────────────────
# Defense-in-depth: tell every Node.js CLI tool (Inquirer.js, etc.)
# that we are running in a non-interactive CI environment.
export CI=true
export HERMES_NON_INTERACTIVE=1
export NODE_NO_READLINE=1

# ── Phase 3: Clone the Mock Wiki ──────────────────────────────────────
rm -rf workspace-wiki
mkdir -p workspace-wiki

B64_MOCK_PAT=$(printf "%s:%s" "" "$MOCK_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_MOCK_PAT" clone \
  "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" \
  workspace-wiki

# ── Phase 4: Authenticate the MCP Tool ────────────────────────────────
# The @azure-devops/mcp package reads PERSONAL_ACCESS_TOKEN (base64-encoded PAT).
# Our config.yaml uses PLACEHOLDER_PAT and PLACEHOLDER_ORG as literals —
# we inject the real values here at runtime via sed.
sed -i "s|PLACEHOLDER_ORG|${COMPANY_ORG}|g" "$HOME/.hermes/config.yaml"
sed -i "s|PLACEHOLDER_PAT|${B64_COMPANY_PAT}|g" "$HOME/.hermes/config.yaml"

# Write credentials into .env so Hermes can pick them up for LLM auth
echo "AZURE_FOUNDRY_API_KEY=$AZURE_FOUNDRY_API_KEY" >> "$HOME/.hermes/.env"
export AZURE_FOUNDRY_API_KEY="$AZURE_FOUNDRY_API_KEY"

# ── Phase 5: Construct the LLM Prompt ────────────────────────────────
# The prompt forces the LLM to supply ALL tool parameters explicitly,
# ensuring the Hermes CLI NEVER renders an interactive dropdown.
export PROMPT="
You are an automated engineering delivery agent running in a headless CI/CD pipeline.

1. Use the mcp_azure_devops_search_workitem tool to search for ALL work items (Bug, Task, User Story) under area path 'Spark (AI)' in project '${COMPANY_PROJECT}' within organization '${COMPANY_ORG}'.
2. For each work item returned, include: ID, Title, Type, State, Assigned To, and a 1-sentence Description summary.
3. Format the results as a detailed markdown table with a timestamp header.

🚨 STRICT OPERATING RULES:
- TOOL EXECUTION: When invoking the Azure DevOps search tool, you MUST explicitly define all optional parameters (like 'state', 'assignedTo', 'top', 'areaPath', etc.). Pass wildcards or empty strings for parameters you want unfiltered. DO NOT leave parameters undefined.
- Set 'areaPath' to 'Spark (AI)'.
- DO NOT filter by state — return items in any state (Active, New, Closed, Resolved, etc.).
- DO NOT use any browser, web_extract, or search tools. Only use the Azure DevOps MCP tool.
- You MUST wrap your final markdown report exactly within these tags on their own lines:
[START_REPORT]
<Your raw markdown goes here>
[END_REPORT]
- If your search returns 0 results, output EXACTLY and ONLY: '🎯 No work items found under Spark (AI) area path.' between the tags.
- Output ONLY the raw Markdown. No code blocks (\`\`\`markdown).

---
## 📋 ${COMPANY_PROJECT} — Spark (AI) Work Items ($(date '+%Y-%m-%d %H:%M UTC'))

| ID | Title | Type | State | Assigned To | Description |
|----|-------|------|-------|-------------|-------------|
| [ID] | \`[Title]\` | [Bug/Task/Story] | [State] | [Name] | _[1-sentence summary]_ |
"

echo "🧠 Running Technical Audit Sweep..."

# ── Phase 5b: Diagnostic Dump (remove once stable) ───────────────────
echo "🔍 [DIAG] Config MCP section:"
grep -A 10 "mcp_servers:" "$HOME/.hermes/config.yaml" || echo "[DIAG] No mcp_servers in config!"
echo "🔍 [DIAG] .env contents (redacted):"
cat "$HOME/.hermes/.env" | sed 's/=.*/=***REDACTED***/'
echo "🔍 [DIAG] AZURE_DEVOPS_PAT set: $([ -n \"$AZURE_DEVOPS_PAT\" ] && echo YES || echo NO)"
echo "🔍 [DIAG] AZURE_DEVOPS_ORG_URL: $AZURE_DEVOPS_ORG_URL"
echo "🔍 [DIAG] npx @azure-devops/mcp location:"
npx -y @azure-devops/mcp@latest --help 2>&1 | head -5 || echo "[DIAG] npx MCP failed!"
echo "🔍 [DIAG] hermes mcp list:"
hermes mcp 2>&1 | head -20 || echo "[DIAG] hermes mcp failed!"
echo "🔍 [DIAG] End diagnostics"

# ── Phase 6: The Clean Execution ──────────────────────────────────────
# - hermes chat: starts a chat session
# - -q "$PROMPT": single-query non-interactive mode (sends prompt and exits)
# - --yolo: auto-approve all tool calls without asking
# - -Q: quiet/programmatic mode (suppresses banners, spinners, tool previews)
# - < /dev/null: cleanly closes stdin so Hermes never blocks waiting for input
# - timeout 300: kills the process after 5 minutes to prevent pipeline hangs
# - || true: ensures we reach our own diagnostics even if hermes exits non-zero
timeout 300 hermes chat -q "$PROMPT" --yolo -Q < /dev/null > /tmp/raw_dump.md 2>&1 || true

# ── Phase 7: Extract the Report ───────────────────────────────────────
sed -n '/\[START_REPORT\]/,/\[END_REPORT\]/p' /tmp/raw_dump.md | sed '1d;$d' > /tmp/Daily-Audit-Report.md

RAW_SIZE=$(wc -c < /tmp/raw_dump.md | tr -d ' ')
REPORT_SIZE=$(wc -c < /tmp/Daily-Audit-Report.md | tr -d ' ')
echo "📊 Raw dump: ${RAW_SIZE} bytes | Extracted report: ${REPORT_SIZE} bytes"

if [ ! -s /tmp/Daily-Audit-Report.md ]; then
    echo "❌ FATAL: The extracted Markdown file is completely empty."
    echo "── Raw dump (first 200 lines) ──"
    head -200 /tmp/raw_dump.md
    echo "── End of raw dump ──"
    exit 1
fi

echo "✅ Audit generated successfully. Pushing to Mock Wiki..."

# ── Phase 8: Push to Wiki ─────────────────────────────────────────────
cp /tmp/Daily-Audit-Report.md workspace-wiki/Daily-Audit-Report.md
cd workspace-wiki

git config user.name "Hermes Automated Agent"
git config user.email "hermes-agent@automation.local"
git add Daily-Audit-Report.md

if git diff --staged --quiet; then
    echo "🎯 No changes detected. Wiki remains up to date."
else
    git commit -m "🤖 Automated Prod-to-Mock Audit Sweep - $(date)"
    echo "🚀 Pushing update to Azure DevOps Mock Wiki..."
    git -c http.extraheader="AUTHORIZATION: Basic $B64_MOCK_PAT" push origin HEAD
fi

echo "✅ Pipeline completed successfully. Shutting down container."
exit 0