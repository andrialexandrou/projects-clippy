# GitHub Project Issue Classifier

A tool to automatically classify GitHub issues in GitHub Projects using pre-defined clusters.

## Overview

This script helps you categorize issues in GitHub Projects by updating a custom text field with cluster names. It takes a JSON file containing issues grouped by clusters and generates the necessary GraphQL mutations to update the issues in your GitHub Project.

## Prerequisites

- Node.js and npm/yarn installed
- CoffeeScript installed (`npm install -g coffee-script`)
- A GitHub personal access token with appropriate permissions
- A GitHub Project v2 with issues
- A custom text field in your project for categorizing issues

## Installation

1. Clone this repository or download the script
2. Install dependencies:

```bash
npm install
```

## Usage

Basic usage:

```bash
GITHUB_TOKEN=your_github_token coffee CLASSIFY-PROJECT-ISSUES.coffee --project "PVT_kwDOAbc123" --field-name "Clusters" --input "clusters.json"
```

### Command Line Options

- `--input`, `-i`: Path to the input JSON file (default: 'project-triage-shared-fr.json')
- `--project`, `-p`: GitHub Project ID (default: configured in script)
- `--field-name`, `-n`: Name of the field to update with cluster values (default: 'Clusters')
- `--dry-run`: Run in simulation mode without saving mutations

### Input File Format

The input JSON file should have the following structure:

```json
{
  "clusters": [
    {
      "clusterName": "Documentation",
      "cards": [
        { "id": "issue_id_1" },
        { "id": "issue_id_2" }
      ]
    },
    {
      "clusterName": "Bug",
      "cards": [
        { "id": "issue_id_3" }
      ]
    }
  ]
}
```

### Environment Variables

- `GITHUB_TOKEN`: Your GitHub personal access token (required)

## How It Works

1. The script loads the specified JSON file containing issue clusters
2. It queries the GitHub API to find the project field ID for the field name you specified
3. It generates GraphQL mutations for each issue to update the field with the appropriate cluster name
4. It saves these mutations to a file named 'update-clusters.graphql' in the same directory as your input file
5. You can then execute these mutations against the GitHub API to update your project

## Example Workflow

1. Generate your cluster JSON file (this could be from a machine learning model, manual classification, etc.)
2. Run the script:

    ```bash
    GITHUB_TOKEN=your_token coffee CLASSIFY-PROJECT-ISSUES.coffee --project "PVT_kwDOAbc123" --field-name "Clusters" --input "my-clusters.json"
    ```

3. Review the generated GraphQL mutations in 'update-clusters.graphql'
4. Execute the mutations against GitHub's GraphQL API

## Troubleshooting

- **Error: GITHUB_TOKEN environment variable is required**: Make sure to set your GitHub token as an environment variable
- **Error: Could not find field with name**: Check that the field name you specified exists in your project
- **Error from GitHub API**: Check your GitHub token permissions and project ID

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[MIT](LICENSE)
