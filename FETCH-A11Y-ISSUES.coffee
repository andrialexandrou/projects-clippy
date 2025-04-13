#!/usr/bin/env coffee

# Import required modules
{ execSync } = require 'child_process'
fs = require 'fs'
path = require 'path'

# Parse command line arguments
args = process.argv.slice(2)
projectUrl = null
searchQuery = null
logFile = null

# Parse arguments
for arg, i in args
  if arg == '--project' || arg == '-p'
    projectUrl = args[i + 1] if i + 1 < args.length
  else if arg == '--query' || arg == '-q'
    searchQuery = args[i + 1] if i + 1 < args.length
  else if arg == '--log-file' || arg == '-l'
    logFile = args[i + 1] if i + 1 < args.length

# If no log file specified, create one based on timestamp
timestamp = new Date().toISOString().replace(/:/g, '-').replace(/\..+/, '').replace('T', '_')
logFile = logFile || "fetch-a11y-issues_#{timestamp}.log"

# Set up logging function
log = (message, printToConsole = false) ->
  # Get current timestamp
  now = new Date().toISOString()
  logMessage = "[#{now}] #{message}"
  
  # Write to log file
  fs.appendFileSync(logFile, logMessage + '\n')
  
  # Only print to console if explicitly requested
  if printToConsole
    console.log(message)

# Initialize log file
fs.writeFileSync(logFile, "")
log "Logging to file: #{logFile}"

# Validate project URL
unless projectUrl
  log 'Error: Project URL is required. Use --project or -p to specify it.'
  log 'Usage: coffee fetch-a11y-issues.coffee --project <PROJECT_URL> [--query <SEARCH_QUERY>] [--log-file <LOG_FILE>]'
  process.exit(1)

# Extract organization and project number from URL
# Example URL format: https://github.com/orgs/github/projects/4017
urlParts = projectUrl.split('/')
orgName = null
projectNumber = null

if urlParts.length >= 5 && urlParts[3] == 'orgs'
  orgName = urlParts[4]
  projectNumber = parseInt(urlParts[urlParts.length - 1], 10)

unless orgName && projectNumber
  log 'Error: Invalid project URL format. Expected: https://github.com/orgs/ORGANIZATION/projects/NUMBER'
  process.exit(1)

# Initialize variables
cursor = ""
hasNextPage = true
outputFile = "accessibility-issues_#{timestamp}.txt"
tempFile = "temp_results.json"

# Clear the output file if it exists
fs.writeFileSync outputFile, ''

# Track issue count
totalCount = 0
pageNumber = 1

# Default field mapping - can be expanded
fieldMappings = {
  'category': 'Category', # Change this to match the actual field name in GitHub
  'is': 'state',
  'label': 'Labels',
  'milestone': 'Milestone',
  'status': 'Status'
}

# Parse search query terms into structured format
parseSearchQuery = (query) ->
  return null unless query
  
  terms = {}
  
  # Split by space, but respect quoted values
  parts = query.match(/(?:[^\s"]+|"[^"]*")+/g) || []
  
  for part in parts
    if part.includes(':')
      isExclusion = part.startsWith('-')
      # Remove the leading minus if it's an exclusion
      cleanPart = if isExclusion then part.substring(1) else part
      
      [field, value] = cleanPart.split(':', 2)
      # Remove quotes if present
      value = value.replace(/^"(.*)"$/, '$1')
      
      # Map the field to its internal representation if needed
      mappedField = fieldMappings[field.toLowerCase()] || field
      
      # Store as an object that includes the exclusion flag
      terms[mappedField] = {
        value: value,
        exclude: isExclusion
      }
    else if part.startsWith('-')
      # Handle text exclusion
      terms['text'] = {
        value: part.substring(1),
        exclude: true
      }
    else
      # Terms without a field are treated as text search
      terms['text'] = {
        value: part,
        exclude: false
      }
  
  return terms

# Parse the search query
searchTerms = parseSearchQuery(searchQuery)

# Show what we're searching for
if searchQuery
  log "Using search query: #{searchQuery}"
  log "Parsed search terms:", searchTerms
else
  log "No search query provided. Retrieving all items."

# Function to run shell command and return output
runCommand = (command) ->
  try
    log "Executing command: #{command.split('\n')[0]}..." # Log just the first line of the command
    return execSync(command, { encoding: 'utf8' })
  catch error
    log "Error executing command: #{error}"
    process.exit(1)

# Function to execute GraphQL query
fetchPage = ->
  log "Fetching page #{pageNumber}...", true  # Print to console for progress tracking
  
  # Build the cursor parameter - fix the escaping
  cursorParam = if cursor && cursor != "null" then ", after: \"#{cursor}\"" else ""
  
  # Build the query - add id field to get the Project V2 Item ID
  query = """
  query {
    organization(login: "#{orgName}") {
      projectV2(number: #{projectNumber}) {
        items(
          first: 100
          #{cursorParam}
        ) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id # Get the Project V2 Item ID (important for later scripts)
            content {
              ... on Issue {
                title
                number
                url
                body
                state
                labels(first: 10) {
                  nodes {
                    name
                  }
                }
                milestone {
                  title
                }
              }
            }
            # Fetch custom field values for filtering
            fieldValues(first: 20) {
              nodes {
                __typename
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field {
                    ... on ProjectV2FieldCommon {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldTextValue {
                  text
                  field {
                    ... on ProjectV2FieldCommon {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldDateValue {
                  date
                  field {
                    ... on ProjectV2FieldCommon {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldIterationValue {
                  title
                  field {
                    ... on ProjectV2FieldCommon {
                      id
                      name
                    }
                  }
                }
                ... on ProjectV2ItemFieldNumberValue {
                  number
                  field {
                    ... on ProjectV2FieldCommon {
                      id
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  """
  
  # Log that we're executing the query
  log "Executing GraphQL query for page #{pageNumber}..."
  
  # Execute the GraphQL query with proper escaping
  # Write query to a temporary file to avoid command line escaping issues
  fs.writeFileSync "#{tempFile}.graphql", query
  runCommand "gh api graphql -F query=@#{tempFile}.graphql > #{tempFile}"
  
  # Parse the results
  log "Parsing results from API..."
  result = JSON.parse(fs.readFileSync(tempFile, 'utf8'))
  
  # Get pagination info
  hasNextPage = result.data.organization.projectV2.items.pageInfo.hasNextPage
  cursor = result.data.organization.projectV2.items.pageInfo.endCursor
  
  log "Page has #{result.data.organization.projectV2.items.nodes.length} items, hasNextPage: #{hasNextPage}"
  
  # Process and filter nodes based on search terms
  filteredNodes = result.data.organization.projectV2.items.nodes.filter (node) ->
    return true unless searchTerms # If no search terms, include all
    
    # Skip items without content (e.g., draft issues)
    return false unless node.content
    
    # Helper to get field value by name
    getFieldValue = (fieldName) ->
      return null unless node.fieldValues?.nodes
      for fieldValue in node.fieldValues.nodes
        if fieldValue.field?.name == fieldName
          # Return the appropriate value based on the field type
          switch fieldValue.__typename
            when "ProjectV2ItemFieldSingleSelectValue" then return fieldValue.name
            when "ProjectV2ItemFieldTextValue" then return fieldValue.text
            when "ProjectV2ItemFieldDateValue" then return fieldValue.date
            when "ProjectV2ItemFieldIterationValue" then return fieldValue.title
            when "ProjectV2ItemFieldNumberValue" then return fieldValue.number
            else return null
      return null
    
    # Log item being checked
    log "Checking item: #{node.content.title} (#{node.content.number})"
    
    # Check each search term against the appropriate fields
    matched = true
    for field, termData of searchTerms
      # Get the value and exclusion flag
      value = termData.value
      exclude = termData.exclude
      
      log "  Checking field: #{field} for #{exclude ? 'excluding' : 'including'} value: #{value}"
      
      # Special handling for state
      if field == 'state'
        stateMatches = false
        if value.toLowerCase() == 'open'
          stateMatches = node.content.state == 'OPEN'
        else if value.toLowerCase() == 'closed'
          stateMatches = node.content.state == 'CLOSED'
        
        log "    State #{node.content.state} #{stateMatches ? 'matches' : 'does not match'} #{value}"
        
        # If excluding, we want the opposite result
        if (exclude && stateMatches) || (!exclude && !stateMatches)
          log "    State condition not satisfied"
          matched = false
          break
          
      # Special handling for labels
      else if field == 'Labels'
        hasLabel = false
        matchingLabel = null
        
        if node.content.labels?.nodes
          for label in node.content.labels.nodes
            if label.name.toLowerCase().includes(value.toLowerCase())
              hasLabel = true
              matchingLabel = label.name
              break
        
        if hasLabel
          log "    Found matching label: #{matchingLabel}"
        else
          log "    No matching label found"
        
        # If excluding, we want items WITHOUT the label
        # If including, we want items WITH the label
        if (exclude && hasLabel) || (!exclude && !hasLabel)
          log "    Label condition not satisfied"
          matched = false
          break
          
      # Special handling for milestone
      else if field == 'Milestone'
        hasMilestone = node.content.milestone?.title.toLowerCase().includes(value.toLowerCase())
        
        if hasMilestone
          log "    Milestone matches: #{node.content.milestone.title}"
        else
          log "    Milestone does not match"
        
        # If excluding, we want items WITHOUT the milestone
        # If including, we want items WITH the milestone
        if (exclude && hasMilestone) || (!exclude && !hasMilestone)
          log "    Milestone condition not satisfied"
          matched = false
          break
          
      # Check text search in title and body
      else if field == 'text'
        titleMatch = node.content.title?.toLowerCase().includes(value.toLowerCase())
        bodyMatch = node.content.body?.toLowerCase().includes(value.toLowerCase())
        textMatches = titleMatch || bodyMatch
        
        if textMatches
          log "    Found text match in: #{titleMatch ? 'title' : ''}#{bodyMatch ? (titleMatch ? ' and ' : '') + 'body' : ''}"
        else
          log "    No text match in title or body"
        
        # If excluding, we don't want text matches
        # If including, we want text matches
        if (exclude && textMatches) || (!exclude && !textMatches)
          log "    Text condition not satisfied"
          matched = false
          break
          
      # Check custom fields
      else
        fieldValue = getFieldValue(field)
        if fieldValue
          # Convert to string for comparison
          fieldValueStr = String(fieldValue).toLowerCase()
          valueStr = value.toLowerCase()
          fieldMatches = fieldValueStr.includes(valueStr)
          
          if fieldMatches
            log "    Field value matched: #{fieldValueStr} includes #{valueStr}"
          else
            log "    Field value mismatch: #{fieldValueStr} doesn't include #{valueStr}"
          
          # If excluding, we don't want matches
          # If including, we want matches
          if (exclude && fieldMatches) || (!exclude && !fieldMatches)
            log "    Custom field condition not satisfied"
            matched = false
            break
        else
          # If the field doesn't exist, it depends on whether we're excluding or including
          if !exclude
            # If including, field must exist
            log "    Field not found: #{field}"
            matched = false
            break
          else
            # If excluding, missing field is OK (equivalent to not matching)
            log "    Field not found: #{field} - this is OK for exclusion"
    
    # Log match result
    if matched
      log "  MATCH: #{node.content.title}"
    else
      log "  NO MATCH: #{node.content.title}"
    
    return matched
  
  # Process the filtered nodes and include field values for output
  matchCount = 0
  for node in filteredNodes
    if node.content
      matchCount++
      # Create a more comprehensive output that includes field values and projectV2ItemId
      outputData = {
        id: node.id, # Store the Project V2 Item ID
        content: node.content,
        customFields: {}
      }
      
      # Add custom fields to the output
      if node.fieldValues?.nodes
        for fieldValue in node.fieldValues.nodes
          if fieldValue.field?.name
            fieldName = fieldValue.field.name
            fieldVal = null
            
            switch fieldValue.__typename
              when "ProjectV2ItemFieldSingleSelectValue" then fieldVal = fieldValue.name
              when "ProjectV2ItemFieldTextValue" then fieldVal = fieldValue.text
              when "ProjectV2ItemFieldDateValue" then fieldVal = fieldValue.date
              when "ProjectV2ItemFieldIterationValue" then fieldVal = fieldValue.title
              when "ProjectV2ItemFieldNumberValue" then fieldVal = fieldValue.number
            
            if fieldVal
              outputData.customFields[fieldName] = fieldVal
      
      fs.appendFileSync outputFile, JSON.stringify(outputData) + '\n'
  
  # Return count of items found on this page
  log "Found #{matchCount} matching items on page #{pageNumber}"
  return matchCount

# Main loop to fetch all pages
while hasNextPage
  pageCount = fetchPage()
  totalCount += pageCount
  
  log "Retrieved #{pageCount} issues on page #{pageNumber}. Total: #{totalCount}", true  # Print to console
  
  # Break the loop if we've reached the end or cursor is null
  if !hasNextPage || cursor == "null"
    log "No more pages to fetch.", true  # Print to console
    break
  
  # Increment page number and add a small delay
  pageNumber++
  log "Waiting 1 second before fetching next page...", true  # Print to console
  execSync('sleep 1')

log "Completed. Retrieved #{totalCount} issues total.", true  # Print final summary to console
log "Results saved to: #{outputFile}", true  # Print to console
log "Log file saved to: #{logFile}", true  # Print to console

# Clean up temp files
try
  log "Cleaning up temporary files..."
  fs.unlinkSync tempFile
  fs.unlinkSync "#{tempFile}.graphql"
  log "Temporary files removed successfully"
catch error
  log "Warning: Error when deleting temporary files: #{error}"
