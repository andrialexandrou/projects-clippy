# GitHub Project Items Fetcher - Product Requirements Document

## Overview

The GitHub Project Items Fetcher is a command-line utility designed to extract and filter issues from GitHub organization project boards using the GitHub GraphQL API. It enables users to retrieve project items based on various criteria including labels, status, milestone, and text content.

## Problem Statement

GitHub Projects is a powerful tool for organizing work, but extracting specific items for reporting or analysis purposes is challenging through the web interface. Users need a programmatic way to:

- Retrieve all items from a GitHub project board
- Filter items based on various criteria
- Export the data in a parseable format for further processing

## Target Users

- Engineering Managers tracking project status
- Program Managers generating accessibility reports
- Developers exporting issues for documentation or analysis
- Technical writers gathering issue content for knowledge bases
- QA Engineers tracking bugs and their statuses

## Requirements

### Functional Requirements

1. **Project Access**
   - Must accept a GitHub project URL as input
   - Must parse organization name and project number from the URL
   - Must verify project exists and is accessible

2. **Search and Filtering**
   - Must support filtering items by:
     - Issue state (open/closed)
     - Labels (inclusion and exclusion)
     - Milestone
     - Custom field values (status, category, etc.)
     - Text content (in title and body)
   - Must support excluding items with specific criteria
   - Must support combining multiple search criteria
   - Must respect case-insensitivity for matching values

3. **Data Retrieval**
   - Must fetch item metadata including:
     - Title, number, URL, body, state
     - Labels
     - Milestone information
     - Custom field values from the project
     - Project item ID (for referencing in other scripts)
   - Must handle pagination for projects with more than 100 items
   - Must process up to 100 items per API request

4. **Output**
   - Must output matching items to a timestamped file
   - Must format each item as a JSON object
   - Must include all retrieved data in the output
   - Must log detailed execution information to a separate log file

### Non-Functional Requirements

1. **Performance**
   - Must include a 1-second delay between API requests to avoid rate limiting
   - Should process and filter results efficiently

2. **Usability**
   - Must provide clear command-line parameters
   - Must generate intuitive error messages
   - Must display progress information during execution

3. **Compatibility**
   - Must work with GitHub's GraphQL API v4
   - Must be compatible with Node.js environments
   - Must be executable as a CoffeeScript script

## Features

### Core Features

1. **Project Item Access**
   - Access GitHub organization project boards via URL
   - Authenticate using GitHub CLI credentials

2. **Advanced Search Capabilities**
   - Filter by any combination of criteria
   - Support for complex queries with inclusion and exclusion
   - Support for text search across title and body fields

3. **Comprehensive Data Export**
   - Export all issue metadata and custom field values
   - Store results in a parseable JSON format (one object per line)
   - Include project item IDs for follow-up actions

4. **Detailed Logging**
   - Log all actions and decisions during execution
   - Provide progress updates for multi-page retrievals
   - Create timestamped log files for debugging

## Implementation Details

### Technologies

- CoffeeScript for script execution
- Node.js for runtime environment
- GitHub CLI for authentication
- GitHub GraphQL API for data retrieval

### Dependencies

- child_process module for executing GitHub CLI commands
- fs module for file operations
- path module for file path handling

### Input Parameters

- `--project` or `-p`: URL of the GitHub organization project (required)
- `--query` or `-q`: Search query to filter issues (optional)
- `--log-file` or `-l`: Custom log file path (optional)

### Output Format

- JSON objects, one per line, with the following structure:
  - id: Project V2 Item ID
  - content: Issue details (title, number, URL, body, state, labels, milestone)
  - customFields: Object containing all custom field values

## Success Criteria

- Successfully retrieves items from GitHub project boards
- Correctly filters items based on search criteria
- Provides accurate and complete data in the output file
- Generates helpful logs for troubleshooting
- Handles pagination and large projects efficiently
- Properly escapes and formats all data

## Future Enhancements

- Support for additional item types beyond issues (e.g., PRs, draft issues)
- Output format options (CSV, markdown, etc.)
- Interactive mode for building complex queries
- Batch processing of multiple projects
- Email or Slack notifications upon completion
- Options to configure pagination size and delay between requests
