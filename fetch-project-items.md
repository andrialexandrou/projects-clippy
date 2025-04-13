# GitHub Project Items Fetcher

A command-line utility that fetches issues from GitHub organization project boards using the GitHub GraphQL API, with powerful filtering capabilities.

## Requirements

- Node.js
- CoffeeScript (`npm install -g coffeescript`)
- GitHub CLI (`gh`) installed and authenticated

## Installation

1. Clone this repository or download the script
2. Make the script executable:

```shell
chmod +x FETCH-PROJECT-ITEMS.coffee
```

## Usage

```shell
coffee FETCH-PROJECT-ITEMS.coffee --project <PROJECT_URL> [--query <SEARCH_QUERY>] [--log-file <LOG_FILE>]
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
coffee FETCH-PROJECT-ITEMS.coffee --project https://github.com/orgs/your-org/projects/123
```

### Filter Issues by Label

```bash
coffee FETCH-PROJECT-ITEMS.coffee --project https://github.com/orgs/your-org/projects/123 --query "label:accessibility"
```

### Exclude Issues with a Specific Label

```bash
coffee FETCH-PROJECT-ITEMS.coffee --project https://github.com/orgs/your-org/projects/123 --query "-label:wontfix"
```

### Filter by Status and Category

```bash
coffee FETCH-PROJECT-ITEMS.coffee --project https://github.com/orgs/your-org/projects/123 --query "status:\"In Progress\" category:\"Core Experience\""
```

### Search for Text in Issue Title or Body

```bash
coffee FETCH-PROJECT-ITEMS.coffee --project https://github.com/orgs/your-org/projects/123 --query "screen reader"
```

### Exclude Issues Containing Specific Text

```bash
coffee FETCH-PROJECT-ITEMS.coffee --project https://github.com/orgs/your-org/projects/123 --query "-flaky"
```

### Combine Multiple Filters and Exclusions

```bash
coffee FETCH-PROJECT-ITEMS.coffee --project https://github.com/orgs/your-org/projects/123 --query "label:bug -label:wontfix is:open milestone:\"Q3 2023\""
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

## How Filtering Works

- Searches are case-insensitive and match partial values
- For text searches (without a field specifier), the script searches in both the title and body
- Multiple filters create an AND condition (all criteria must match)
- Field names are case-sensitive and should match your GitHub project's custom field names exactly
- Use quotes for values containing spaces: `status:"In Progress"`
- The script supports all custom field types: text, single-select, date, iteration, and number

## Output Format

Each line in the output file contains a JSON object with the issue content and custom fields:

```json
{
  "id": "PVTI_lADOAxx123456789",
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
    "Iteration": "Sprint 4",
    "Priority": "High"
  }
}
```

## Tips

- Use quotes for search terms with spaces: `status:"In Progress"`
- For complex queries, build them gradually to ensure they work as expected
- The tool fetches up to 100 items per page, with automatic pagination
- If your project has more than 100 items, the script will automatically fetch multiple pages
- Review the log file for detailed information about the filtering process
- The ID field contains the Project V2 Item ID, which is useful for other scripts
- The script includes all available custom fields in the output, even those not used in filtering

## Troubleshooting

### Authentication Issues

If you encounter authentication problems:

1. Ensure you've authenticated with `gh auth login`
2. Verify you have access to the project
3. Check the GitHub CLI is working with `gh auth status`

### No Items Returned

If no items are returned:

1. Check your search query for typos
2. Verify custom field names match exactly what's in GitHub
3. Try a simpler query first, then add more filters
4. Review the log file to see how filtering is applied

## Related Documentation

For more detailed information about requirements and specifications, please refer to the [PRD document](./GITHUB-PROJECT-ITEMS-FETCHER-PRD.md).

## License

MIT
