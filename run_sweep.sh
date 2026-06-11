#!/bin/bash
set -e

export TERM=dumb
export GIT_TERMINAL_PROMPT=0

echo "🚀 Booting Automated Delivery Agent..."
rm -rf workspace-wiki
mkdir -p workspace-wiki

# Clone the Wiki
B64_PAT=$(printf "%s:%s" "" "$AZURE_DEVOPS_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" clone "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" workspace-wiki

cd workspace-wiki
mkdir -p assets
touch assets/banner.txt

PROMPT="
You are an automated engineering delivery agent.

1. Use your Azure DevOps MCP tool to search for all 'User Story' items in project '${MOCK_PROJECT}' created in the last 14 days.

🚨 STRICT OPERATING RULES:
- DO NOT use any browser, web_extract, or search tools. Only use the Azure DevOps MCP tool.
- You MUST begin your final output with exactly this delimiter on its own line:
---BEGIN_REPORT---
- If your search returns 0 results, output EXACTLY and ONLY: '🎯 No new user stories detected in the last 14 days.' below the delimiter.
- Output ONLY the raw Markdown. No code blocks (\`\`\`markdown), no conversational filler, and no internal thoughts.

---
## 🛠️ ${MOCK_PROJECT} New Story Technical Audit — [Insert Current Local Date/Time]

### 📝 Strategic Content Breakdown
* **[ID]** \`[Story Title]\`
  - *Origin:* Created by [Creator] on [Creation Date]
  - *Target Location:* \`[Area Path or Iteration Path]\`
  - *Core Objective:* _[1-sentence description summary]_

### 🔍 Architecture & Alignment Note
- Provide a quick 1-sentence evaluation on whether these new stories are targeting the current sprint.
"

echo "🧠 Running Technical Audit Sweep..."

# 🌟 FIX 1: The "Trickle Pipe"
# We pause for 2 seconds between each 'Enter' key. This ensures the CLI has time 
# to render the next question before we send the keystroke, bypassing the buffer flush.
(
    sleep 2; echo ""
    sleep 2; echo ""
    sleep 2; echo ""
    sleep 120
) | hermes -z "$PROMPT" chat > /tmp/raw_dump.md 2>&1 || true

# 🌟 FIX 2: The Delimiter Extractor
# We search for the exact delimiter token instead of the markdown table.
# This guarantees extraction even if the LLM returns the 0-results state!
sed -n '/---BEGIN_REPORT---/,$p' /tmp/raw_dump.md | sed '1d' > /tmp/Daily-Audit-Report.md

if [ ! -s /tmp/Daily-Audit-Report.md ]; then
    echo "❌ FATAL: The extracted Markdown file is completely empty. Printing raw dump for debugging:"
    cat /tmp/raw_dump.md
    exit 1
fi

cp /tmp/Daily-Audit-Report.md Daily-Audit-Report.md

git config user.name "Hermes Automated Agent"
git config user.email "hermes-agent@automation.local"
git add Daily-Audit-Report.md

if git diff --staged --quiet; then
    echo "🎯 No changes detected. Wiki remains up to date."
else
    git commit -m "🤖 Automated Daily Audit Sweep - $(date)"
    echo "🚀 Pushing update to Azure DevOps Wiki..."
    git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" push origin HEAD
fi

echo "✅ Audit completed successfully. Shutting down container."
exit 0