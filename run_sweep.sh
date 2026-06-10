#!/bin/bash
set -e

echo "🚀 Booting Automated Delivery Agent..."
rm -rf workspace-wiki
mkdir -p workspace-wiki

B64_PAT=$(printf "%s:%s" "" "$AZURE_DEVOPS_PAT" | base64 | tr -d '\n')
git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" clone "https://dev.azure.com/${MOCK_ORG}/${MOCK_PROJECT}/_git/${MOCK_PROJECT}.wiki" workspace-wiki

cd workspace-wiki
mkdir -p assets
echo "Banner Bypass" > assets/banner.txt

# --- THE GUARDRAILED PROMPT ---
PROMPT="
You are an automated engineering delivery agent. Your output will be piped directly into a Markdown file. 

1. Use your Azure DevOps MCP tool to search for all 'User Story' items in project '${MOCK_PROJECT}' created in the last 7 days.

🚨 ESCAPE HATCH: If your search returns 0 results, you MUST NOT invent or hallucinate data. You must output EXACTLY and ONLY this sentence: '🎯 No new user stories detected in the last 7 days.' Do not add anything else.

2. If stories ARE found, format the data using the layout below. 

🚨 STRICT FORMATTING RULES:
- Output ONLY the raw Markdown.
- Do NOT output your internal thought process.
- Do NOT include any conversational filler (e.g., 'Here is the data', 'Sure!').
- Do NOT wrap the output in markdown code blocks (\`\`\`markdown).

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
# Execute the agent and pipe only the final clean output
hermes chat <<< "$PROMPT" >> ADO-Daily-Dump.md

git config user.name "Hermes Automated Agent"
git config user.email "hermes-agent@automation.local"
git add ADO-Daily-Dump.md

if git diff --staged --quiet; then
    echo "🎯 No changes detected. Wiki remains up to date."
else
    git commit -m "🤖 Automated Daily Audit Sweep - $(date)"
    git -c http.extraheader="AUTHORIZATION: Basic $B64_PAT" push origin HEAD
fi