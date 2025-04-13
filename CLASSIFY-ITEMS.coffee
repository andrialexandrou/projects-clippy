fs = require 'fs'
path = require 'path'
https = require 'https'
readline = require 'readline'

# Default input and configuration settings
defaultInputFile = null 
defaultProjectNumber = null # No default project number
defaultFieldName = null # No default field name
defaultOrgLogin = null # No default organization login

# Function to parse command line arguments
parseArgs = ->
  args = process.argv.slice(2)
  config = 
    inputFile: defaultInputFile
    projectNumber: defaultProjectNumber
    fieldName: defaultFieldName
    orgLogin: defaultOrgLogin
    dryRun: false
    reset: false  # Add reset option
  
  for arg, i in args
    if arg == '--input' or arg == '-i'
      config.inputFile = args[i + 1]
    else if arg == '--project' or arg == '-p'
      config.projectNumber = args[i + 1]
    else if arg == '--field-name' or arg == '-n'
      config.fieldName = args[i + 1]
    else if arg == '--org' or arg == '-o'
      config.orgLogin = args[i + 1]
    else if arg == '--dry-run'
      config.dryRun = true
    else if arg == '--reset'  # Add reset flag
      config.reset = true
  
  # Validate required parameters
  missingParams = []
  if !config.inputFile  # Input file required for both regular and reset mode
    missingParams.push('--input / -i')
  if !config.projectNumber
    missingParams.push('--project / -p')
  if !config.fieldName
    missingParams.push('--field-name / -n')
  if !config.orgLogin
    missingParams.push('--org / -o')
    
  if missingParams.length > 0
    console.error "Error: Missing required parameters: #{missingParams.join(', ')}"
    console.error "\nUsage: GITHUB_TOKEN=your_token coffee CLASSIFY-PROJECT-ISSUES.coffee --input input.json --project 13291 --field-name 'Clusters' --org 'github' [--dry-run]"
    console.error "  or to reset fields: GITHUB_TOKEN=your_token coffee CLASSIFY-PROJECT-ISSUES.coffee --reset --input input.json --project 13291 --field-name 'Clusters' --org 'github' [--dry-run]"
    process.exit(1)
    
  return config

# Function to load and parse the JSON file
loadClusters = (filePath) ->
  try
    data = fs.readFileSync(filePath, 'utf8')
    return JSON.parse(data)
  catch error
    console.error "Error reading or parsing the JSON file: #{error.message}"
    process.exit(1)

# Function to fetch project field ID from field name
fetchFieldId = (projectNumber, fieldName, orgLogin, callback) ->
  # Ensure we have a GitHub token
  githubToken = process.env.GITHUB_TOKEN
  unless githubToken
    console.error "Error: GITHUB_TOKEN environment variable is required to fetch field ID"
    process.exit(1)
  
  console.log "Fetching project fields for #{orgLogin}/#{projectNumber}"
  
  query = """
  query {
    organization(login: "#{orgLogin}") {
      projectV2(number: #{projectNumber}) {
        id
        fields(first: 100) {
          nodes {
            ... on ProjectV2Field {
              id
              name
            }
            ... on ProjectV2IterationField {
              id
              name
            }
            ... on ProjectV2SingleSelectField {
              id
              name
            }
          }
        }
      }
    }
  }
  """
  
  requestOptions = {
    hostname: 'api.github.com',
    path: '/graphql',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': "Bearer #{githubToken}",
      'User-Agent': 'node.js'
    }
  }
  
  req = https.request requestOptions, (res) ->
    data = ''
    res.on 'data', (chunk) -> data += chunk
    res.on 'end', ->
      if res.statusCode != 200
        console.error "Error: GitHub API returned status code #{res.statusCode}"
        console.error data
        process.exit(1)
      
      response = JSON.parse(data)
      if response.errors
        console.error "Error from GitHub API:", response.errors
        process.exit(1)
      
      if !response.data?.organization?.projectV2
        console.error "Error: Project not found or not accessible"
        process.exit(1)
        
      projectId = response.data.organization.projectV2.id
      fields = response.data.organization.projectV2.fields.nodes
      field = fields.find((f) -> f.name.toLowerCase() == fieldName.toLowerCase())
      
      unless field
        console.error "Error: Could not find field with name '#{fieldName}' in the project"
        console.error "Available fields:", fields.map((f) -> f.name).join(", ")
        process.exit(1)
      
      # Minimal logging - just the essential info
      console.log "✅ Found project and field"
      console.log "Project ID: #{projectId}"
      console.log "Field ID (#{field.name}): #{field.id}"
      
      # Store these values in a log file without console output
      logMessage = """
      GraphQL IDs Information:
      Project: #{orgLogin}/#{projectNumber}
      Project ID: #{projectId}
      Field name: #{field.name}
      Field ID: #{field.id}
      Retrieved at: #{new Date().toISOString()}
      
      """
      try
        fs.appendFileSync('graphql-ids.log', logMessage)
      catch err
        # Silent fail for log file writing
      
      callback(field.id, projectId)
  
  req.on 'error', (error) ->
    console.error "Error making request to GitHub API:", error
    process.exit(1)
    
  req.write JSON.stringify({ query: query })
  req.end()

# Function to generate the GraphQL mutation for a single issue
generateMutation = (issueId, clusterName, projectId, fieldId, clientMutationId = null) ->
  # Validate that all required IDs are present
  if !issueId || !projectId || !fieldId
    console.error "Error: Missing required parameters for mutation"
    console.error "Item ID: #{issueId || 'MISSING'}"
    console.error "Project ID: #{projectId || 'MISSING'}"
    console.error "Field ID: #{fieldId || 'MISSING'}"
    return null
  
  # Ensure item ID has correct format (assuming PVTI_ format based on documentation)
  formattedIssueId = issueId
  
  # Generate a unique client mutation ID if not provided
  mutationId = clientMutationId || "classify-#{Date.now()}-#{Math.random().toString(36).substring(2, 15)}"
  
  # Create value object based on whether we have a clusterName or not
  valueObj = if clusterName?
    "value: {\n        text: \"#{clusterName.replace(/"/g, '\\"')}\"\n      }"
  else
    "value: {\n        text: \"\"\n      }"
  
  # Create a properly formatted mutation with a named mutation and conforming to the documentation format
  """
  mutation UpdateFieldValue {
    updateProjectV2ItemFieldValue(
      input: {
        projectId: "#{projectId}"
        itemId: "#{formattedIssueId}"
        fieldId: "#{fieldId}"
        #{valueObj}
        clientMutationId: "#{mutationId}"
      }
    ) {
      clientMutationId
      projectV2Item {
        id
      }
    }
  }
  """

# Function to generate all mutations
generateAllMutations = (clusters, config) ->
  mutations = []
  issueMap = {}
  
  # Create a map of issue IDs to cluster names
  for cluster in clusters
    clusterName = cluster.clusterName
    for card in cluster.cards
      if card.id? # Make sure the issue has an ID
        issueMap[card.id] = clusterName
  
  # Minimal log output - just count
  console.log "Found #{Object.keys(issueMap).length} items to update"
  
  # Generate mutations for each issue
  for issueId, clusterName of issueMap
    mutation = generateMutation(issueId, clusterName, config.projectId, config.fieldId)
    mutations.push
      issueId: issueId
      clusterName: clusterName
      mutation: mutation
  
  return mutations

# Function to save mutations to a file
saveMutations = (mutations, outputPath) ->
  output = mutations.map((m) -> 
    """
    # Issue ID: #{m.issueId}
    # Cluster: #{m.clusterName}
    #{m.mutation}
    
    """
  ).join('\n')
  
  fs.writeFileSync(outputPath, output)
  console.log "Saved #{mutations.length} GraphQL mutations to #{outputPath}"

# Function to get user confirmation
getUserConfirmation = (message, callback) ->
  rl = readline.createInterface
    input: process.stdin
    output: process.stdout
  
  rl.question "#{message} (Y/n): ", (answer) ->
    rl.close()
    confirmed = answer.toLowerCase() != 'n'
    callback(confirmed)

# Function to execute a GraphQL mutation with additional validation
executeMutation = (mutation, callback) ->
  # Ensure we have a GitHub token
  githubToken = process.env.GITHUB_TOKEN
  unless githubToken
    console.error "Error: GITHUB_TOKEN environment variable is required to execute mutations"
    process.exit(1)
  
  # Skip further processing if mutation is null
  unless mutation
    console.error "Error: Cannot execute null mutation"
    callback(false, { errors: [{ message: "Null mutation provided" }] })
    return
  
  # For normal mutations (not queries), validate it has required fields
  if mutation.includes('mutation ') && !mutation.includes('query ')
    if !mutation.includes('projectId:') || !mutation.includes('itemId:') || !mutation.includes('fieldId:') || !mutation.includes('value:')
      console.error "Error: Mutation is missing required fields"
      callback(false, { errors: [{ message: "Mutation is missing required fields" }] })
      return
  
  # Skip detailed mutation logging
  
  # Create a properly formatted request body with the query
  requestBody = JSON.stringify({ query: mutation })
  
  # Continue with the request
  requestOptions = {
    hostname: 'api.github.com',
    path: '/graphql',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': "Bearer #{githubToken}",
      'User-Agent': 'node.js'
    }
  }
  
  req = https.request requestOptions, (res) ->
    data = ''
    res.on 'data', (chunk) -> data += chunk
    res.on 'end', ->
      if res.statusCode != 200
        console.error "Error: GitHub API returned status code #{res.statusCode}"
        callback(false, data)
        return
      
      try
        response = JSON.parse(data)
      catch e
        console.error "Error parsing JSON response"
        callback(false, { errors: [{ message: "Failed to parse JSON response" }] })
        return
      
      if response.errors
        # Simplified error reporting for non-test queries
        if mutation.includes('mutation ')
          console.error "Error: GraphQL mutation failed"
          error = response.errors[0]
          console.error "  #{error.message}"
          
          if error.type == 'NOT_FOUND'
            console.error "  => This indicates that one of the IDs could not be found"
        else
          # For test queries, we still want detailed errors
          console.error "\n=== GraphQL Error ==="
          console.error response.errors[0].message
          if response.errors[0].type
            console.error "Type: #{response.errors[0].type}"
          console.error "==================\n"
        
        callback(false, response.errors)
        return
      
      # Skip detailed response logging
      callback(true, response.data)
  
  req.on 'error', (error) ->
    console.error "Network error making request to GitHub API:", error.message
    callback(false, error)
    
  req.write requestBody
  req.end()

# Function to execute all mutations with batching and appropriate delays
executeAllMutations = (mutations, index, successCount, failedIds, callback) ->
  batchSize = 10 # Number of mutations to process before taking a longer break
  
  if index >= mutations.length
    callback(successCount, failedIds)
    return
  
  current = mutations[index]
  # Show progress as percentage
  progressPct = Math.round((index / mutations.length) * 100)
  console.log "Progress: #{progressPct}% (#{index}/#{mutations.length}) - Processing: #{current.issueId}"
  
  executeMutation current.mutation, (success, response) ->
    if success
      console.log "✅ #{current.issueId}: Updated to '#{current.clusterName}'"
      successCount++
    else
      console.error "❌ #{current.issueId}: Failed to update"
      failedIds.push(current.issueId)
    
    # Determine the delay before the next request
    isLargeBatch = mutations.length > 50
    isBatchBoundary = (index + 1) % batchSize == 0 && index < mutations.length - 1
    delay = if isLargeBatch && isBatchBoundary then 3000 else 300
    
    if isBatchBoundary
      console.log "## Pausing to avoid rate limits... ##"
    
    # Schedule the next mutation with appropriate delay
    setTimeout ->
      executeAllMutations(mutations, index + 1, successCount, failedIds, callback)
    , delay

# Function to process mutations after confirmation
processMutations = (mutations, config) ->
  if config.dryRun
    console.log "Dry run mode - no changes will be made"
    # In dry run mode, only show counts
    console.log "Would update #{mutations.length} items"
    console.log "First item sample: #{mutations[0]?.issueId} -> '#{mutations[0]?.clusterName}'" if mutations.length > 0
  else
    # Log all the IDs being used in a file without console output
    idLogFileName = "item-ids-log_#{new Date().toISOString().replace(/:/g, '-')}.txt"
    idLogFilePath = path.join(path.dirname(config.inputFile), idLogFileName)
    
    idLogContent = mutations.map((m) -> 
      """
      Item ID: #{m.issueId}
      Cluster: #{m.clusterName}
      
      """
    ).join('\n')
    
    fs.writeFileSync(idLogFilePath, idLogContent)
    
    # Save mutations to a log file without console output
    logFileName = "update-clusters-log_#{new Date().toISOString().replace(/:/g, '-')}.txt"
    logFilePath = path.join(path.dirname(config.inputFile), logFileName)
    saveMutations(mutations, logFilePath)
    
    # Execute the mutations with minimal logging
    console.log "\nStarting update of #{mutations.length} items..."
    executeAllMutations mutations, 0, 0, [], (successCount, failedIds) ->
      console.log "\n✨ Update complete"
      console.log "Success: #{successCount}/#{mutations.length} items"
      
      if successCount < mutations.length
        console.log "Failed: #{failedIds.length} items"
        console.log "Check the log file for details."

# Add a function to test a single mutation before proceeding with all updates
testSingleMutation = (config, callback) ->
  console.log "Running connectivity test..."

  # Check token is set (without exposing it)
  githubToken = process.env.GITHUB_TOKEN
  if !githubToken
    console.error "❌ Error: GITHUB_TOKEN environment variable is not set"
    callback(false)
    return

  # Create a simple test query that doesn't show too much info
  query = """
  query {
    node(id: "#{config.projectId}") {
      ... on ProjectV2 {
        id
        title
      }
    }
  }
  """
  
  executeMutation query, (success, response) ->
    if success
      console.log "✅ Test successful - Connected to GitHub API"
      
      if response?.node?.title
        console.log "Project: #{response.node.title}"
        callback(true)
      else
        console.error "⚠️ Warning: Project found but data is incomplete"
        getUserConfirmation "Continue anyway?", (confirmed) ->
          callback(confirmed)
    else
      console.error "❌ Test failed - Could not connect to project"
      
      # Only show error details if we get a specific error
      if response?.errors?[0]?.message.includes("Could not resolve")
        console.error "Error: Project ID is incorrect or not accessible with your token"
      
      getUserConfirmation "Continue anyway despite the test failure?", (confirmed) ->
        callback(confirmed)

# Add function to fetch all items in a project
fetchProjectItems = (projectId, callback) ->
  # Ensure we have a GitHub token
  githubToken = process.env.GITHUB_TOKEN
  unless githubToken
    console.error "Error: GITHUB_TOKEN environment variable is required to fetch items"
    process.exit(1)
  
  console.log "Fetching all items in project..."
  
  query = """
  query {
    node(id: "#{projectId}") {
      ... on ProjectV2 {
        items(first: 100) {
          nodes {
            id
            content {
              ... on Issue {
                title
                number
              }
              ... on PullRequest {
                title
                number
              }
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    }
  }
  """
  
  requestOptions = {
    hostname: 'api.github.com',
    path: '/graphql',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': "Bearer #{githubToken}",
      'User-Agent': 'node.js'
    }
  }
  
  allItems = []
  
  fetchPage = (cursor = null) ->
    # If we have a cursor, add it to the query
    cursorString = if cursor then ", after: \"#{cursor}\"" else ""
    paginatedQuery = query.replace("items(first: 100)", "items(first: 100#{cursorString})")
    
    req = https.request requestOptions, (res) ->
      data = ''
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', ->
        if res.statusCode != 200
          console.error "Error: GitHub API returned status code #{res.statusCode}"
          console.error data
          process.exit(1)
        
        response = JSON.parse(data)
        if response.errors
          console.error "Error from GitHub API:", response.errors
          process.exit(1)
        
        if !response.data?.node?.items?.nodes
          console.error "Error: Project items not found or not accessible"
          process.exit(1)
          
        # Add items from this page
        items = response.data.node.items.nodes
        allItems = allItems.concat(items)
        
        # Check if there are more pages
        pageInfo = response.data.node.items.pageInfo
        if pageInfo.hasNextPage
          console.log "Fetched #{allItems.length} items so far, getting more..."
          fetchPage(pageInfo.endCursor)
        else
          console.log "✅ Fetched all #{allItems.length} items"
          callback(allItems)
    
    req.on 'error', (error) ->
      console.error "Error making request to GitHub API:", error
      process.exit(1)
      
    req.write JSON.stringify({ query: paginatedQuery })
    req.end()
  
  # Start fetching the first page
  fetchPage()

# Function to reset field values for items in the input file
resetFieldValues = (config, callback) ->
  console.log "Preparing to reset '#{config.fieldName}' values for items in #{config.inputFile}..."
  
  # Load the data file
  data = loadClusters(config.inputFile)
  
  # Extract just the IDs from the clusters data
  items = []
  for cluster in data.clusters
    for card in cluster.cards
      if card.id?
        items.push
          id: card.id
  
  console.log "Found #{items.length} items to reset from input file"
  
  # Generate mutations to reset those fields
  mutations = []
  for item in items
    # Generate a mutation with null cluster name to reset it
    mutation = generateMutation(item.id, null, config.projectId, config.fieldId)
    mutations.push
      issueId: item.id
      clusterName: "(empty)"  # Just for display
      mutation: mutation
  
  # Confirm with user
  boardName = "#{config.orgLogin}/#{config.projectNumber}"
  getUserConfirmation "Ready to RESET #{mutations.length} field values on board #{boardName}. Are you sure?", (confirmed) ->
    if confirmed
      if config.dryRun
        console.log "Dry run mode - no changes will be made"
        console.log "Would reset #{mutations.length} items"
        callback()
      else
        console.log "\nStarting field reset for #{mutations.length} items..."
        executeAllMutations mutations, 0, 0, [], (successCount, failedIds) ->
          console.log "\n✨ Reset complete"
          console.log "Success: #{successCount}/#{mutations.length} items"
          
          if successCount < mutations.length
            console.log "Failed: #{failedIds.length} items"
          
          callback()
    else
      console.log "Reset operation cancelled by user."
      callback(false)

# Main function
main = ->
  config = parseArgs()
  
  if config.reset
    console.log "RESET MODE: Will clear '#{config.fieldName}' values for items in #{config.inputFile}"
  else
    console.log "Processing clusters from #{config.inputFile}"
  
  # Fetch the field ID from the field name
  console.log "Resolving field ID for '#{config.fieldName}'..."
  fetchFieldId config.projectNumber, config.fieldName, config.orgLogin, (fieldId, projectId) ->
    config.fieldId = fieldId
    config.projectId = projectId
    
    # Test a single query before proceeding
    testSingleMutation config, (testPassed) ->
      if !testPassed
        console.log "Operation cancelled due to test failure"
        process.exit(1)
      
      # Handle reset mode or normal mode
      if config.reset
        resetFieldValues config, (success) ->
          if success == false
            console.log "Reset operation cancelled"
          process.exit(0)
      else
        # Continue with normal cluster assignment
        data = loadClusters(config.inputFile)
        
        # Generate mutations
        mutations = generateAllMutations(data.clusters, config)
        
        # Ask for confirmation before proceeding
        boardName = "#{config.orgLogin}/#{config.projectNumber}"
        getUserConfirmation "Ready to update #{mutations.length} items on board #{boardName}. Proceed?", (confirmed) ->
          if confirmed
            processMutations(mutations, config)
          else
            console.log "Operation cancelled by user."

# Run the main function
main()