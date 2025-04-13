# GitHub Project Accessibility Issues Fetcher - Product Requirements Document

## Overview

The `fetch-a11y-issues.coffee` script is a command-line utility designed to retrieve accessibility-related issues from a GitHub organization project board. It uses GitHub's GraphQL API to fetch issues, filters them based on optional search criteria, and saves the results to a text file.

## Functionality

### Command Line Interface

- The script accepts the following command-line arguments:
  - `--project` or `-p`: Required. URL of the GitHub organization project (e.g., `https://github.com/orgs/github/projects/4017`)
  - `--query` or `-q`: Optional. Search query to filter issues

### Project URL Parsing

- Extracts the organization name and project number from the provided URL
- Validates that the URL follows the expected format: `https://github.com/orgs/ORGANIZATION/projects/NUMBER`
- Returns appropriate error messages for invalid or missing project URLs

### Search Query Functionality

- Parses search queries into structured formats for filtering
- Supports field-specific searches using the format `field:value`
- Maps user-friendly field names to internal GitHub field names
- Handles quoted values in search queries to support search terms with spaces
- Supported search fields include:
  - `category` (maps to "Category")
  - `is` (maps to "state")
  - `label` (maps to "Labels")
  - `milestone` (maps to "Milestone")
  - `status` (maps to "Status")
- Terms without a field specifier are treated as text search (searching in title and body)
- Logs the parsed search terms to console for debugging and transparency

### Data Retrieval

- Uses GitHub CLI (`gh`) to execute GraphQL queries against the GitHub API
- Implements pagination to retrieve all matching issues (100 issues per page)
- Uses cursor-based pagination to efficiently navigate through large result sets
- Fetches the following data for each issue:
  - Title
  - Issue number
  - URL
  - Body
  - State (open/closed)
  - Labels (up to 10)
  - Milestone
  - Custom field values (up to 20)
- Supports all common field types in GitHub projects:
  - Text fields
  - Single-select fields
  - Date fields
  - Iteration fields
  - Number fields

### Filtering Capabilities

- Filters issues based on the provided search query
- Supports filtering by:
  - Issue state (open/closed)
  - Labels (partial or exact matches)
  - Milestone (partial or exact matches)
  - Text content (in title or body)
  - Custom fields defined in the project
- Implements a type-aware field value retrieval system that correctly handles different field types:
  - Properly extracts values based on the field's `__typename`
  - Handles `ProjectV2ItemFieldSingleSelectValue` for dropdown/select fields
  - Handles `ProjectV2ItemFieldTextValue` for text fields
  - Handles `ProjectV2ItemFieldDateValue` for date fields
  - Handles `ProjectV2ItemFieldIterationValue` for iteration/sprint fields
  - Handles `ProjectV2ItemFieldNumberValue` for numeric fields
- Performs case-insensitive substring matching for text-based fields
- Converts non-string values to strings for consistent comparison
- Provides proper null handling to prevent errors with missing fields
- Skips items without content (e.g., draft issues)

### Output

- Generates a timestamped output file (`accessibility-issues_YYYY-MM-DD_HH-MM-SS.txt`)
- Saves each matching issue as a JSON object on a separate line
- Includes both issue content and custom field values in the output
- Reports progress during fetching (page number, issues per page, total issues)
- Displays summary upon completion
- Provides detailed debugging information about the matching process
- Preserves core issue metadata in the output for further processing

### Performance Optimization

- Uses temporary file for storing intermediate API responses
- Implements a 1-second delay between API calls to prevent rate limiting
- Breaks pagination loop if no more results are available or cursor is null
- Caches parsed query terms for consistent reuse

### Error Handling

- Validates required command-line arguments
- Provides clear error messages for missing or invalid arguments
- Reports errors when executing GitHub API commands
- Gracefully handles invalid project URLs
- Contains null-checks throughout to prevent runtime errors
- Gracefully handles the cleanup of temporary files

### Technical Details

- Written in CoffeeScript
- Uses Node.js built-in modules:
  - `child_process` for executing shell commands
  - `fs` for file operations
  - `path` for path manipulations
- Uses temporary file for storing intermediate API responses
- Implements pagination with cursor-based navigation
- Cleans up temporary files after execution
- Compatible with all major operating systems where Node.js is supported
