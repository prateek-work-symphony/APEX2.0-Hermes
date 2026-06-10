#!/bin/bash
set -e

echo "🚀 Booting Automated Delivery Agent..."
rm -rf workspace-wiki
mkdir -p workspace-wiki

# 1. Secure Authentication & Clone
B64_PAT=$(printf "%s:%s" "" "$AZURE_DEVOPS_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" clone "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" workspace-wiki

# 2. Step INTO the freshly cloned repo
cd workspace-wiki

# 3. Establish internal asset paths to ensure clean CLI execution
mkdir -p assets
echo "Banner Bypass" > assets/banner.txt

# --- THE PROMPT ---
PROMPT="
You are an automated engineering delivery agent. Your output will be piped directly into a Markdown file. 

1. Use your Azure DevOps MCP tool to search for all 'User Story' items in project '${MOCK_PROJECT}' created in the last 7 days.

🚨 STRICT OPERATING RULES:
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

# 🌟 THE NON-INTERACTIVE FIX: 
# We call hermes directly using the execution flag rather than launching the 'chat' sub-shell.
# This prevents the interactive onboarding questionnaire from triggering.
hermes --non-interactive -z "$PROMPT" >> ADO-Daily-Dump.md

# 4. Commit and Push back to the Wiki
git config user.name "Hermes Automated Agent"
git config user.email "hermes-agent@automation.local"
git add ADO-Daily-Dump.md

if git diff --staged --quiet; then
    echo "🎯 No changes detected. Wiki remains up to date."
else
    git commit -m "🤖 Automated Daily Audit Sweep - $(date)"
    git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" push origin HEAD
fi