#!/bin/bash
set -e

# Disable all UI animations to guarantee clean Markdown formatting
export TERM=dumb

echo "🚀 Booting Automated Delivery Agent..."
rm -rf workspace-wiki
mkdir -p workspace-wiki

# Secure Authentication & Clone
B64_PAT=$(printf "%s:%s" "" "$AZURE_DEVOPS_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" clone "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" workspace-wiki

# 🌟 THE FIX: Create a completely empty banner file so nothing prints to the terminal
mkdir -p assets
touch assets/banner.txt

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

# 1. Execute Hermes in /app (where it is pre-configured) and write to a BRAND NEW filename
hermes -z "$PROMPT" chat < /dev/null > Daily-Audit-Report.md

# 2. Force-copy the new report into the Git repository (bypassing any read-only locks)
cp -f Daily-Audit-Report.md workspace-wiki/Daily-Audit-Report.md

# 3. Step into the repo, commit, and push
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