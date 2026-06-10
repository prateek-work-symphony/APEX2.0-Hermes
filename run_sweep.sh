#!/bin/bash
set -e

# Disable UI animations
export TERM=dumb

echo "🚀 Booting Automated Delivery Agent..."
rm -rf workspace-wiki
mkdir -p workspace-wiki

# Clone the Wiki
B64_PAT=$(printf "%s:%s" "" "$AZURE_DEVOPS_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" clone "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" workspace-wiki

# Prevent the startup banner
mkdir -p /app/assets
touch /app/assets/banner.txt

PROMPT="
You are an automated engineering delivery agent. Your output will be piped directly into a Markdown file. 

1. Use your Azure DevOps MCP tool to search for all 'User Story' items in project '${MOCK_PROJECT}' created in the last 7 days.

🚨 STRICT OPERATING RULES:
- DO NOT use any browser, web_extract, or search tools. Only use the Azure DevOps MCP tool.
- If your search returns 0 results, output EXACTLY and ONLY: '🎯 No new user stories detected in the last 7 days.'
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

# 🌟 THE V9 + V7 FIX: Pipe the Enter key to bypass the wizard, 
# and write the file to the system /tmp/ folder to avoid all Permission errors.
echo "" | hermes -z "$PROMPT" chat > /tmp/Daily-Audit-Report.md

# Copy the safe file into the Git repository
cp /tmp/Daily-Audit-Report.md workspace-wiki/Daily-Audit-Report.md

cd workspace-wiki
git config user.name "Hermes Automated Agent"
git config user.email "hermes-agent@automation.local"
git add Daily-Audit-Report.md

if git diff --staged --quiet; then
    echo "🎯 No changes detected. Wiki remains up to date."
else
    git commit -m "🤖 Automated Daily Audit Sweep - $(date)"
    git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" push origin HEAD
fi