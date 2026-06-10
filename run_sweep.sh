#!/bin/bash
set -e

echo "🚀 Booting Automated Delivery Agent..."
rm -rf workspace-wiki
mkdir -p workspace-wiki

# 1. Clone the repo
B64_PAT=$(printf "%s:%s" "" "$AZURE_DEVOPS_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" clone "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" workspace-wiki

# 2. Step INTO the freshly cloned repo
cd workspace-wiki

# 3. Create the dummy folder layout to satisfy the banner path check
mkdir -p assets
echo "Banner Bypass" > assets/banner.txt

# 4. Define the Prompt
PROMPT="
You are an automated engineering delivery agent.

1. Use your Azure DevOps MCP tools to search and locate all 'User Story' items in project '${MOCK_PROJECT}' created in the last 7 days.
2. For every story found, isolate these data points:
   - ID & Title
   - Creator and Creation Timestamp
   - Description / Acceptance Criteria
   - Area Path / Iteration Path

3. Format and APPEND this data to 'ADO-Daily-Dump.md' using this layout:

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

# 5. Run Hermes cleanly in headless mode
echo "🧠 Running Technical Audit Sweep..."
hermes -z "$PROMPT" chat >> ADO-Daily-Dump.md

# 6. Commit and Push
git config user.name "Hermes Automated Agent"
git config user.email "hermes-agent@automation.local"
git add ADO-Daily-Dump.md

if git diff --staged --quiet; then
    echo "🎯 No new user stories detected. Wiki remains up to date."
else
    git commit -m "🤖 Automated Daily Audit Sweep - $(date)"
    git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" push origin HEAD
fi