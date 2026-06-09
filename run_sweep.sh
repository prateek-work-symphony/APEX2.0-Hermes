#!/bin/bash
set -e

echo "🚀 Booting Automated Delivery Agent..."

# 1. Clear out historical runs inside the container workspace
rm -rf workspace-wiki
mkdir -p workspace-wiki

# 2. Clone the ADO Wiki repository using the plain text PAT
git clone "https://${EUyQUa9Nr90Fo7rJMK2SRmgmgqQkRSrKXyyZ9MJIbbehL4kAyhpaJQQJ99CFACAAAAAAAAAAAAASAZDO1o4o}@dev.azure.com/PrateekSymphony/APEX2.0-Mock/_git/APEX2.0-Mock.wiki" workspace-wiki

cd workspace-wiki

# 3. Define the prompt, ensuring it targets the mock project explicitly
PROMPT='
You are an automated engineering delivery agent.

1. Use your Azure DevOps MCP tools to search and locate all "User Story" items in project "APEX2.0-Mock" created in the last 7 days.
2. For every story found, isolate these data points:
   - ID & Title
   - Creator and Creation Timestamp
   - Description / Acceptance Criteria (Provide a concise, 1-sentence summary of the objective)
   - Area Path / Iteration Path

3. Format and APPEND this data to "ADO-Daily-Dump.md" using this layout:

---
## 🛠️ APEX2.0-Mock New Story Technical Audit — [Insert Current Local Date/Time]

### 📝 Strategic Content Breakdown
* **[ID]** `[Story Title]`
  - *Origin:* Created by [Creator] on [Creation Date]
  - *Target Location:* `[Area Path or Iteration Path]`
  - *Core Objective:* _[1-sentence description summary]_

### 🔍 Architecture & Alignment Note
- Provide a quick 1-sentence evaluation on whether these new stories are targeting the current sprint or if they are being correctly parked in the product backlog for future refinement.
'

# 4. Trigger Hermes to dump into the markdown file
echo "🧠 Running Technical Audit Sweep..."
hermes -z "$PROMPT" chat >> ADO-Daily-Dump.md

# 5. Git Commit and Push back to the Wiki
git config user.name "Hermes Automated Agent"
git config user.email "hermes-agent@automation.local"

git add ADO-Daily-Dump.md

if git diff --staged --quiet; then
    echo "🎯 No new user stories detected. Wiki remains up to date."
else
    git commit -m "🤖 Automated Daily Audit Sweep - $(date)"
    # Note: If your Wiki uses 'main' instead of 'wikiMain', change the branch name below
    git push origin wikiMain 
fi