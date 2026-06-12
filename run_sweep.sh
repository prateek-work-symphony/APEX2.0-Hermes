#!/bin/bash
set -e

echo "🚀 Booting Automated Delivery Agent..."
rm -rf workspace-wiki
mkdir -p workspace-wiki

# 1. Authenticate Git with the MOCK_PAT
B64_MOCK_PAT=$(printf "%s:%s" "" "$MOCK_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_MOCK_PAT" clone "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" workspace-wiki

# 2. Authenticate the MCP Tool with the COMPANY_PAT
export AZURE_DEVOPS_PAT="$COMPANY_PAT"

# 🌟 THE FIX: We architect the prompt to force the LLM to supply wildcard parameters,
# ensuring the Hermes CLI NEVER tries to render an interactive dropdown.
export PROMPT="
You are an automated engineering delivery agent.

1. Use your Azure DevOps MCP tool to search for all 'User Story', 'Task', and 'Bug' items in project '${COMPANY_PROJECT}' within organization '${COMPANY_ORG}' created or updated in the last 7 days.

🚨 STRICT OPERATING RULES:
- TOOL EXECUTION: When invoking the Azure DevOps search tool, you MUST explicitly define all optional parameters (like 'state', 'assignedTo', etc.). Pass wildcards or empty strings if you want all results. DO NOT leave parameters undefined.
- DO NOT use any browser, web_extract, or search tools. Only use the Azure DevOps MCP tool.
- You MUST wrap your final markdown report exactly within these tags on their own lines:
[START_REPORT]
<Your raw markdown goes here>
[END_REPORT]
- If your search returns 0 results, output EXACTLY and ONLY: '🎯 No new production items detected in the last 7 days.' between the tags.
- Output ONLY the raw Markdown. No code blocks (\`\`\`markdown).

---
## 🛠️ ${COMPANY_PROJECT} Production Audit (Synced: [Insert Local Date])

### 📝 Strategic Content Breakdown
* **[ID]** \`[Item Title]\`
  - *Type:* [User Story / Bug / Task]
  - *Origin:* Created/Updated by [User] on [Date]
  - *Core Objective:* _[1-sentence description summary]_

### 🔍 Architecture & Alignment Note
- Provide a quick 1-sentence evaluation on whether these items appear aligned with the current active sprint.
"

echo "🧠 Running Technical Audit Sweep..."

# 🌟 THE CLEAN EXECUTION
# We pipe < /dev/null to cleanly close the session after the LLM finishes its first thought.
# We append '-y' (or the equivalent auto-approve flag for your CLI) to prevent tool approval prompts.
hermes -z "$PROMPT" chat -y < /dev/null > /tmp/raw_dump.md || true

# Extract strictly between the LLM tags
sed -n '/\[START_REPORT\]/,/\[END_REPORT\]/p' /tmp/raw_dump.md | sed '1d;$d' > /tmp/Daily-Audit-Report.md

if [ ! -s /tmp/Daily-Audit-Report.md ]; then
    echo "❌ FATAL: The extracted Markdown file is completely empty. Printing raw dump for debugging:"
    cat /tmp/raw_dump.md
    exit 1
fi

echo "✅ Audit generated successfully. Pushing to Mock Wiki..."

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