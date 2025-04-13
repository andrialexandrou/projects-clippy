# Item Clustering Solution: Product Requirements Document

## Overview

The Issue Clustering Solution is a toolset designed to help engineering teams identify patterns across large sets of GitHub issues, allowing them to address related issues efficiently. The solution includes tools for fetching GitHub issues from project boards and clustering them into solution-oriented groups.

## Problem Statement

Engineering teams working with large backlogs of GitHub issues face challenges in:

1. Identifying groups of issues that can be solved with similar technical approaches
2. Prioritizing work efficiently across dozens or hundreds of issues
3. Finding patterns across seemingly unrelated bugs or feature requests
4. Organizing issues by solution patterns rather than just by component or label

## Goals

1. Provide tools to extract issues from GitHub organization project boards
2. Intelligently cluster issues based on solution patterns using AI
3. Identify issues that share implementation strategies
4. Generate human-readable output that helps engineering teams plan their work
5. Support flexible filtering and search capabilities for issue extraction
6. Reduce the cognitive load of triaging large volumes of issues

## Components

The solution consists of two primary components:

### 1. GitHub Issue Fetcher (`FETCH-PROJECT-ITEMS.coffee`)

A tool that extracts issues from GitHub project boards with advanced filtering capabilities.

**Key Features:**

- Fetching issues from GitHub organization project boards using GraphQL API
- Filtering issues using advanced search queries
- Supporting custom project fields, labels, milestones, and text search
- Providing detailed logging and output format compatible with the clustering tool

### 2. Issue Clustering Tool (`CLUSTER-ITEMS.coffee`)

A tool that uses AI to cluster issues based on solution patterns.

**Key Features:**

- Processing issues in configurable batch sizes
- Using OpenAI's models to identify patterns across issues
- Two-pass clustering approach for maximum coverage
- Recursive refinement of large clusters into specific subclusters
- Detailed output with hierarchical cluster names
- Comprehensive logging and progress tracking

## Technical Requirements

### Issue Fetcher

1. **Input:**
   - GitHub organization project URL
   - Optional search query for filtering
   - Optional custom log file path

2. **Output:**
   - JSON file with one issue per line
   - Each issue containing original content and custom field values
   - Detailed log file with execution information

3. **Authentication:**
   - Rely on GitHub CLI (gh) authentication

4. **Search Capabilities:**
   - Filter by issue state (open/closed)
   - Filter by labels and milestones
   - Filter by custom fields in the project
   - Text search in title and body
   - Support for excluding items with specific criteria

### Issue Clustering Tool

1. **Input:**
   - JSON file of issues (from the fetcher or custom source)
   - OpenAI API key from command line, .env file, or environment variable
   - Optional batch size, model, temperature, and other configuration options

2. **Output:**
   - JSON file with clustered issues
   - Each cluster containing a descriptive name and list of issues
   - Detailed log file with execution information

3. **API Integration:**
   - Secure handling of OpenAI API key
   - Configurable model selection
   - Temperature settings for controlling creativity

4. **Clustering Approach:**
   - Process issues in batches to handle large volumes
   - First pass: Identify clear patterns
   - Second pass: Process uncategorized issues with more flexible criteria
   - Recursive refinement: Break down large clusters into specific subclusters

## User Experience

### Issue Fetcher Workflow

1. User authenticates with GitHub using the gh CLI
2. User runs the script with a project URL and optional search query
3. Script outputs progress information during execution
4. User receives a JSON file ready for clustering

### Issue Clustering Workflow

1. User provides an OpenAI API key
2. User runs the script with the issues file and optional configuration
3. Script outputs progress information during clustering
4. User receives a JSON file with organized clusters
5. Large clusters are automatically refined into more specific groups

## Success Metrics

The solution will be considered successful if it:

1. Reduces the time needed to identify related issues by at least 70%
2. Groups at least 80% of issues into meaningful clusters
3. Provides cluster names that accurately describe the solution patterns
4. Maintains high performance with project boards containing 1,000+ issues
5. Produces output that engineering teams find actionable for planning work

## Future Enhancements

1. Web-based interface for running the tools
2. Integration with GitHub Actions for automated clustering
3. Visualization tools for cluster relationships
4. Direct integration with GitHub API without requiring gh CLI
5. Support for additional AI models beyond OpenAI
6. Automatic issue labeling based on cluster assignments
