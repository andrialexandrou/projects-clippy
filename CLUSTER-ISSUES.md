# Issue Clustering Tool

A command-line tool that uses AI to automatically cluster GitHub issues by solution patterns, helping teams identify related issues that can be addressed together.

## Features

- Intelligently clusters issues based on how they would likely be solved
- Recursively refines large clusters into smaller, more specific groupings
- Identifies uncategorized issues and assigns them to a dedicated group
- Supports configurable batch sizes, OpenAI models, and temperature settings
- Provides detailed logging and progress tracking
- Generates JSON output of all clustered issues
- Optimized for handling large sets of GitHub issues

## Requirements

- Node.js
- CoffeeScript (`npm install -g coffeescript`)
- An OpenAI API key

## Installation

1. Clone this repository or download the script files
2. Ensure you have CoffeeScript installed globally:

```bash
npm install -g coffeescript
```

3. Make the script executable:

```bash
chmod +x cluster-issues.coffee
```

4. Set your OpenAI API key as an environment variable (recommended):

```bash
export OPENAI_API_KEY="your-api-key-here"
```

## Usage

```bash
coffee cluster-issues.coffee --input <ISSUES_FILE> [OPTIONS]
```

### Required Parameters

- `--input` or `-i`: Path to the JSON file containing GitHub issues

### Optional Parameters

- `--batch-size` or `-b`: Number of issues to process in each batch (default: 50)
- `--api-key` or `-k`: OpenAI API key (if not set as environment variable)
- `--temperature` or `-t`: AI temperature setting - "low", "normal", or "high" (default: "normal")
- `--model` or `-m`: OpenAI model to use (default: "gpt-4o")
- `--log-file` or `-l`: Custom log file path
- `--max-refine-batch` or `-mrb`: Maximum size of a batch for refining uncategorized issues (default: 50)
- `--no-recursive-refinement` or `-nrr`: Skip recursive refinement of large clusters

### Examples

Basic usage:

```bash
coffee cluster-issues.coffee --input issues.json
```

With custom settings:

```bash
coffee cluster-issues.coffee --input issues.json --batch-size 30 --temperature low --model gpt-4-turbo
```

For large sets of uncategorized issues:

```bash
coffee cluster-issues.coffee --input issues.json --max-refine-batch 40
```

## Input Format

The input file should contain one GitHub issue per line in JSON format. Each issue should have at least a title and body. The format can be the raw JSON output from the GitHub API or a simplified format:

```json
{"title":"Issue title here","number":123,"url":"https://github.com/org/repo/issues/123","body":"Issue description here","state":"OPEN","labels":{"nodes":[{"name":"bug"},{"name":"priority:high"}]}}
```

You can use the `fetch-a11y-issues.coffee` script to fetch issues from a GitHub project with this format.

## Output

The tool generates three main outputs:

1. **First Pass Clusters**: `clusters_first_pass_[TIMESTAMP].json` - Initial clustering results
2. **Final Refined Clusters**: `clusters_[TIMESTAMP].json` - Final results with refined subclusters
3. **Log File**: `cluster-issues_[TIMESTAMP].log` - Detailed execution log

The cluster JSON format looks like this:

```json
{
  "clusters": [
    {
      "clusterName": "Fix Keyboard Navigation Issues",
      "cards": [
        {"id": "12345", "title": "Dropdown not keyboard accessible"},
        {"id": "67890", "title": "Focus trap not working in modal"}
      ]
    },
    {
      "clusterName": "Fix Keyboard Navigation Issues: Dropdown Components",
      "cards": [
        {"id": "13579", "title": "Cannot navigate dropdown menu with arrow keys"},
        {"id": "24680", "title": "Dropdown menu doesn't close on Escape key"}
      ]
    }
  ]
}
```

## How It Works

1. **Initial Clustering**: The script first divides issues into batches and sends them to the OpenAI API for clustering.
2. **Handling Uncategorized Issues**: Any issues not assigned to a cluster are grouped into a "No cluster" category.
3. **Recursive Refinement**: Large clusters (>10 issues) are further refined into smaller, more specific subclusters.
4. **Hierarchical Naming**: Subclusters maintain the parent cluster name as a prefix to show the relationship.

## Tips

- For large repositories, start with a higher batch size (80-100) for faster processing
- For more precise clusters, use the "low" temperature setting
- For more creative clustering, use the "high" temperature setting
- The log file contains detailed information about the clustering process and is useful for debugging
- The first-pass output is useful for comparing with the final refined output

## Troubleshooting

### Missing or Few Clusters

If you're seeing too many uncategorized issues:

1. Try reducing your batch size to 30-50 issues per batch for better quality
2. Use the "low" temperature setting for more consistent clustering
3. Make sure your input data has sufficient context in the issue descriptions
4. For large "No cluster" groups, the tool will automatically split them into manageable batches

### API Rate Limiting

If you encounter rate limiting from OpenAI:
1. Increase the delay between API calls (modify the `sleep` parameters)
2. Reduce batch sizes
3. Use a different API key

## License

MIT
