# GitHub Project Accessibility Issues Fetcher

A command-line utility that fetches accessibility-related issues from GitHub organization project boards using the GitHub GraphQL API.

## Requirements

- Node.js
- CoffeeScript (`npm install -g coffeescript`)
- GitHub CLI (`gh`) installed and authenticated

## Installation

1. Clone this repository or download the script
2. Make the script executable:

```shell
chmod +x fetch-a11y-issues.coffee
```

## Usage

```shell
coffee fetch-a11y-issues.coffee --project <PROJECT_URL> [--query <SEARCH_QUERY>] [--log-file <LOG_FILE>]
```

### Parameters

- `--project` or `-p`: Required. URL of the GitHub organization project
- `--query` or `-q`: Optional. Search query to filter issues
- `--log-file` or `-l`: Optional. Specify a custom log file path

### Output

The script generates:

- A timestamped text file (`accessibility-issues_YYYY-MM-DD_HH-MM-SS.txt`) containing the matching issues in JSON format, one issue per line.
- A log file (`fetch-a11y-issues_YYYY-MM-DD_HH-MM-SS.log`) with detailed information about the script execution.

## Example Usage

### Fetch All Issues from a Project

```bash
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/your-org/projects/123
```

### Filter Issues by Label

```bash
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/your-org/projects/123 --query "label:accessibility"
```

### Exclude Issues with a Specific Label

```bash
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/your-org/projects/123 --query "-label:wontfix"
```

### Filter by Status and Category

```bash
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/your-org/projects/123 --query "status:\"In Progress\" category:\"Core Experience\""
```

### Search for Text in Issue Title or Body

```bash
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/your-org/projects/123 --query "screen reader"
```

### Exclude Issues Containing Specific Text

```bash
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/your-org/projects/123 --query "-flaky"
```

### Combine Multiple Filters and Exclusions

```bash
coffee fetch-a11y-issues.coffee --project https://github.com/orgs/your-org/projects/123 --query "label:bug -label:wontfix is:open milestone:\"Q3 2023\""
```

## Available Search Fields

The script supports filtering by the following fields:

- `is:open` or `is:closed` - Filter by issue state
- `label:value` - Filter by label name
- `-label:value` - Exclude issues with a specific label
- `milestone:value` - Filter by milestone title
- `-milestone:value` - Exclude issues with a specific milestone
- `status:value` - Filter by the Status custom field
- `category:value` - Filter by the Category custom field
- Any other custom field name used in your project

Prefix any field with `-` to exclude items matching that criteria.

## Example Output

Each line in the output file contains a JSON object with the issue content and custom fields:

```json
{
  "content": {
    "title": "Improve keyboard navigation in dropdown menu",
    "number": 123,
    "url": "https://github.com/your-org/your-repo/issues/123",
    "body": "Users have reported issues navigating the dropdown menu with keyboard...",
    "state": "OPEN",
    "labels": {
      "nodes": [
        { "name": "accessibility" },
        { "name": "bug" }
      ]
    },
    "milestone": {
      "title": "Q3 Goals"
    }
  },
  "customFields": {
    "Status": "In Progress",
    "Category": "Core Experience",
    "Iteration": "Sprint 4"
  }
}
```

## Tips

- Use quotes for search terms with spaces: `status:"In Progress"`
- The search is case-insensitive and matches partial values
- For text searches (without a field specifier), the script searches in both the title and body
- Use `-` prefix to exclude items: `-label:wontfix` excludes all issues with the "wontfix" label
