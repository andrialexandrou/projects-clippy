# Project board cluster classifier

Required tokens:

- GITHUB_TOKEN
  - org-owned by github
  - read for repos, pull requests, issues, discussions; write for projects
- OPENAI_API_TOKEN (until converted to use GitHub models API)

Environment:

- Node.js
- coffeescript

## Usage

```shell
# 1. Get the issues, provide project board and query if desired. `is:open` recommended
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/github/projects/13291 --query "category:Accessibility is:open"

# 2. Request clustering logic, which will also sort cards into clusters, through reflexive sorting that will go until clusters are about 5 issues in size
coffee cluster-issues.coffee --input accessibility-issues.txt --batch-size 200 --temperature low [--api-key YOUR_OPENAI_API_KEY]

# 3. Make the mutation (behind a confirmation that will tell you how many actions you're performing)
coffee classify-project-issues.coffee -o github --project 13291 --field-name "Cluster" --input accessibility-clusters.json [--reset]
```

## Next steps

<details><summary>Expand</summary>

1. Dogfood script to determine optimal temperature and prompt
2. Convert to use GitHub models
3. Migrate script to Hubot

</details>
