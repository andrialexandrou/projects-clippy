# Product Requirements Document: Project Issue Classifier

## Overview

The Project Issue Classifier is a command-line tool designed to automate the process of categorizing GitHub issues within a GitHub Project by applying cluster labels to issues based on predetermined classifications.

## Problem Statement

When organizing large numbers of issues in a GitHub Project, manually categorizing them into clusters or groups is time-consuming and error-prone. This tool addresses this challenge by automating the process of applying cluster classifications to issues based on a pre-processed JSON file.

## User Stories

- As a project manager, I want to automatically apply cluster labels to multiple issues at once so that I can organize my project view more efficiently.
- As a developer, I want to categorize issues by their type/cluster to help with prioritization and workload management.
- As a team lead, I want to ensure consistent labeling across issues to improve project tracking and reporting.

## Requirements

### Functional Requirements

1. The tool must accept a JSON file containing issue clusters and their associated issues
2. The tool must resolve a GitHub Project field ID from a user-provided field name
3. The tool must generate GraphQL mutations to update the specified field for each issue
4. The tool must save these mutations to a file for execution
5. The tool must support a dry-run mode to preview mutations before execution

### Non-Functional Requirements

1. Security: The tool must use GitHub's authentication token system
2. Performance: The tool should handle large numbers of issues efficiently
3. Usability: The tool should provide clear feedback and error messages
4. Compatibility: The tool should work with GitHub Projects v2

## Technical Specifications

### Input Format

The tool expects a JSON file with a structure like:

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

### Command Line Arguments

- `--input`, `-i`: Path to the input JSON file
- `--project`, `-p`: GitHub Project ID
- `--field-name`, `-n`: Name of the field to update with cluster values
- `--dry-run`: Run in simulation mode without saving mutations

### Output

The tool generates a GraphQL file containing mutations that can be executed against GitHub's API to update the specified field for each issue.

## Future Enhancements

1. Add direct execution of the GraphQL mutations
2. Support for multiple projects in a single run
3. Add authentication through GitHub Apps
4. Support for other field types beyond text fields
5. Integration with CI/CD pipelines

## Success Criteria

1. Successfully apply cluster classifications to at least 95% of issues in a given project
2. Reduce the time required to categorize issues by 80% compared to manual methods
3. Maintain data consistency and accuracy in the application of labels
