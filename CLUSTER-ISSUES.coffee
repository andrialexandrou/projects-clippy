#!/usr/bin/env coffee

# Import required modules
fs = require 'fs'
{ execSync } = require 'child_process'
readline = require 'readline'
path = require 'path'

# Function to load environment variables from .env file
loadEnvFile = (filePath = '.env') ->
  try
    if fs.existsSync(filePath)
      content = fs.readFileSync(filePath, 'utf8')
      lines = content.split('\n')
      
      envVars = {}
      for line in lines
        # Skip comments and empty lines
        if line.trim() && !line.startsWith('#')
          # Split on first equals sign
          parts = line.split('=', 2)
          if parts.length == 2
            key = parts[0].trim()
            value = parts[1].trim()
            # Remove quotes if present
            if (value.startsWith('"') && value.endsWith('"')) || 
               (value.startsWith("'") && value.endsWith("'"))
              value = value.substring(1, value.length - 1)
            envVars[key] = value
      
      return envVars
    return {}
  catch error
    console.error("Error loading .env file:", error.message)
    return {}

# Parse command line arguments
args = process.argv.slice(2)
inputFile = null
batchSize = 50
openaiKey = null
temperature = "normal" # Default to normal temperature
model = "gpt-4o" # Default model
logFile = null
maxRefineBatchSize = 50 # Default maximum batch size for refining uncategorized issues
skipRecursiveRefinement = false # Flag to skip recursive refinement

# Parse arguments
for arg, i in args
  if arg == '--input' || arg == '-i'
    inputFile = args[i + 1] if i + 1 < args.length
  else if arg == '--batch-size' || arg == '-b'
    batchSize = parseInt(args[i + 1], 10) if i + 1 < args.length
  else if arg == '--api-key' || arg == '-k'
    openaiKey = args[i + 1] if i + 1 < args.length
  else if arg == '--temperature' || arg == '-t'
    temperature = args[i + 1]?.toLowerCase() if i + 1 < args.length
  else if arg == '--model' || arg == '-m'
    model = args[i + 1] if i + 1 < args.length
  else if arg == '--log-file' || arg == '-l'
    logFile = args[i + 1] if i + 1 < args.length
  else if arg == '--max-refine-batch' || arg == '-mrb'
    maxRefineBatchSize = parseInt(args[i + 1], 10) if i + 1 < args.length
  else if arg == '--no-recursive-refinement' || arg == '-nrr'
    skipRecursiveRefinement = true

# If no log file specified, create one based on timestamp
timestamp = new Date().toISOString().replace(/:/g, '-').replace(/\..+/, '').replace('T', '_')
logFile = logFile || "cluster-issues_#{timestamp}.log"

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

# Load API key with priority: CLI arg > .env file > environment variable
if !openaiKey
  # Try loading from .env file
  envVars = loadEnvFile()
  openaiKey = envVars['OPENAI_API_TOKEN']
  
  # If still not found, try environment variable
  if !openaiKey
    openaiKey = process.env.OPENAI_API_TOKEN

# Validate input file
unless inputFile
  log 'Error: Input file is required. Use --input or -i to specify it.', true
  log 'Usage: coffee cluster-issues.coffee --input <INPUT_FILE> [--batch-size <SIZE>] [--api-key <OPENAI_API_TOKEN>] [--temperature <low|normal|high>] [--model <MODEL_NAME>] [--log-file <LOG_FILE>] [--max-refine-batch <SIZE>] [--no-recursive-refinement]', true
  process.exit(1)

# Validate API key
unless openaiKey
  log 'Error: OpenAI API key is required. Provide it with --api-key, in .env file, or set OPENAI_API_TOKEN environment variable.', true
  process.exit(1)

# Validate and map temperature
temperatureMap = {
  'low': 0.3,
  'normal': 0.7,
  'high': 1.0
}

unless temperatureMap[temperature]?
  log "Warning: Invalid temperature setting '#{temperature}'. Using 'normal' (0.7).", true
  temperature = "normal"

log "Using temperature setting: #{temperature} (#{temperatureMap[temperature]})"
log "Using model: #{model}"
log "Maximum refine batch size: #{maxRefineBatchSize}"
log "Recursive refinement: #{if skipRecursiveRefinement then 'Disabled' else 'Enabled'}"

# Initialize variables
outputFile = "clusters_#{timestamp}.json"
existingClusters = []
allIssues = []
allClusters = []

# Function to read issues from file
readIssues = ->
  try
    # Read all lines and parse JSON
    log "Reading file: #{inputFile}"
    fileContent = fs.readFileSync(inputFile, 'utf8')
    lines = fileContent.split('\n').filter((line) -> line.trim() != '')
    
    # Parse each line as JSON
    issues = []
    for line, index in lines
      try
        log "Parsing line #{index + 1} of #{lines.length}"
        data = JSON.parse(line)
        
        # Extract issue data
        issue = 
          id: data.id || "issue_#{issues.length}" # Use the Project V2 Item ID from fetch script
          nodeId: data.id || null # Store the original node ID separately
          issueNumber: data.content?.number?.toString() || data.number?.toString() || "unknown"
          title: data.title || data.content?.title || "Untitled Issue"
          body: data.body || data.content?.body || ""
          url: data.url || data.content?.url || ""
          state: data.state || data.content?.state || ""
        
        # Extract stack traces and error messages from the body for better clustering
        errorMatches = issue.body.match(/```[\s\S]*?```/g)
        if errorMatches
          issue.errorDetails = errorMatches.join('\n')
        
        # Extract labels if available
        if data.labels?.nodes || data.content?.labels?.nodes
          issue.labels = (data.labels?.nodes || data.content?.labels?.nodes).map((label) -> label.name)
        
        # Add custom fields if available
        if data.customFields
          issue.customFields = data.customFields
        
        issues.push(issue)
      catch error
        log "Error parsing line #{index + 1}: #{error}"
        log "Problematic line content: #{line.substring(0, 200)}..."
    
    return issues
  catch error
    log "Error reading issues file: #{error}"
    process.exit(1)

# Function to call OpenAI API
callOpenAI = (prompt) ->
  try
    # Create a temporary file for the prompt
    promptFile = "temp_prompt.txt"
    fs.writeFileSync(promptFile, prompt)
    
    # First, create a properly escaped JSON payload in a temp file
    jsonPayloadFile = "temp_payload.json"
    payload = {
      model: model,
      messages: [
        {
          role: "user",
          content: prompt
        }
      ],
      temperature: temperatureMap[temperature]
    }
    
    # Write the JSON payload to a file with proper formatting
    fs.writeFileSync(jsonPayloadFile, JSON.stringify(payload, null, 2))
    
    # Log API call (but don't include the full prompt in logs)
    log "Calling OpenAI API with model: #{model}, temperature: #{temperatureMap[temperature]}"
    log "Prompt length: #{prompt.length} characters"
    
    # Call OpenAI API using curl with the payload file instead of inline JSON
    command = """
    curl https://api.openai.com/v1/chat/completions \\
      -H "Content-Type: application/json" \\
      -H "Authorization: Bearer #{openaiKey}" \\
      -d @#{jsonPayloadFile} \\
      --silent
    """
    
    result = execSync(command, { encoding: 'utf8' })
    
    # Clean up temporary files
    fs.unlinkSync(promptFile)
    fs.unlinkSync(jsonPayloadFile)
    
    # Parse the response
    try
      response = JSON.parse(result)
      
      # Check if there's an error in the response
      if response.error
        log "OpenAI API Error: #{JSON.stringify(response.error)}"
        return { clusters: [] }
        
      # Extract content from the response
      content = response.choices[0].message.content
      log "Received response (${content.length} characters)"
      
      # Try to parse the content as JSON
      try
        return JSON.parse(content)
      catch jsonError
        log "Error parsing response as JSON: #{jsonError}"
        
        # If it's not valid JSON, try to extract JSON object
        jsonMatch = content.match(/(\{[\s\S]*\})/m)
        if jsonMatch && jsonMatch[1]
          try
            log "Attempting to parse extracted JSON"
            return JSON.parse(jsonMatch[1])
          catch extractError
            log "Error parsing extracted JSON: #{extractError}"
            log "Extracted content: #{jsonMatch[1].substring(0, 200)}..."
            return { clusters: [] }
        else
          log "Error: OpenAI response is not valid JSON"
          log "Response begins with: #{content.substring(0, 200)}..."
          return { clusters: [] }
    catch parseError
      log "Error parsing API response: #{parseError}"
      log "Raw response begins with: #{result.substring(0, 200)}..."
      return { clusters: [] }
    
  catch error
    log "Error calling OpenAI API: #{error}"
    return { clusters: [] }

# Function to create batches
createBatches = (issues, size) ->
  batches = []
  for i in [0...issues.length] by size
    batches.push(issues.slice(i, i + size))
  return batches

# Function to build prompt for OpenAI
buildPrompt = (issues, existingClusters, batchInfo, isRefinement = false) ->
  # Build the list of cards to cluster
  log "Building prompt for batch #{batchInfo.current}/#{batchInfo.total} with #{issues.length} issues" + (if isRefinement then " (REFINEMENT)" else "")
  
  cardsText = issues.map((issue) ->
    # Include error details if available for better clustering of test failures
    errorSection = if issue.errorDetails then "\nError Details: #{issue.errorDetails.substring(0, 500)}#{if issue.errorDetails.length > 500 then '...' else ''}" else ""
    labelsSection = if issue.labels then "\nLabels: #{issue.labels.join(', ')}" else ""
    
    "- \"#{issue.title}\" (ID: #{issue.id}, Issue ##{issue.issueNumber})#{labelsSection}\nDescription: #{issue.body.substring(0, 200)}#{if issue.body.length > 200 then '...' else ''}#{errorSection}"
  ).join('\n\n')
  
  # Build existing clusters text if any
  existingClustersText = ""
  if existingClusters.length > 0 && !isRefinement
    log "Including #{existingClusters.length} existing clusters in prompt"
    existingClustersText = "\nExisting clusters from previous batches:\n"
    existingClustersText += existingClusters.map((cluster) -> "- \"#{cluster}\"").join('\n')
    existingClustersText += "\n\nIMPORTANT: When appropriate, use these existing cluster names to categorize new cards. This ensures consistency across batches. Only create a new cluster when a card doesn't fit well into any existing cluster."
  
  # Add batch information
  batchInfoText = "\nThis is batch #{batchInfo.current} of #{batchInfo.total} total batches."
  
  # Different prompt for refinement of uncategorized issues
  if isRefinement
    prompt = """
You are a clustering assistant. You are working with issues that were not assigned to any cluster in the previous pass.

Your goal is to identify groups of issues that can be solved with similar types of engineering work. You are clustering by how the problems can be solved, not by what kind of issue they are or who reported them.

This is a second pass. You are now working only with issues that did not match any cluster previously.

Guidelines:
- You may now be more flexible in your pattern recognition.
- If two or more issues could *plausibly* be addressed with the same kind of solution, cluster them together.
- Look for subtle patterns in code references, components affected, or error types.
- You may create smaller clusters (as few as 2-3 cards) if they share a likely resolution path.
- Every issue should be assigned to a cluster if at all possible.
- Be creative but maintain focus on solution patterns.
- Create descriptive cluster names that indicate the type of engineering work needed.
- It's better to create more specific clusters than to leave issues uncategorized.

Cards to cluster:
#{cardsText}

Respond ONLY with a valid JSON object without any explanatory text. The JSON should have this exact structure:
{"clusters": [{"clusterName": "descriptive_name", "cards": [{"id": "card_id", "title": "card_title"}]}]}
"""
  else
    # Standard first pass prompt
    prompt = """
You are a clustering assistant. Your task is to organize the following list of software issues into logical groups.

Your goal is to identify groups of issues that can be solved with similar types of engineering work. You are clustering by how the problems can be solved, not by what kind of issue they are or who reported them.

Guidelines:
- Use your judgment to group issues that likely share the same implementation strategy, fix location in the code, or team responsible.
- Use evidence from the reproduction steps, code references, or component names in the issue text to find clusters.
- Favor practical, useful clusters even if they are not perfect. If two issues likely require a similar kind of fix, group them.
- Only create a cluster when multiple issues clearly share a common solution pattern — but don't be too strict; be pragmatic.
- Avoid clustering by issue tags, source (e.g., "support escalation"), or vague themes like "rendering."
- Name each cluster according to the kind of fix or change required (e.g., "Fix dropdown keyboard behavior," "Adjust contrast tokens").
- Try to create at least 10 clusters per batch if possible, up to 30 if meaningful groupings emerge.
- Look for shared resolution patterns — e.g., multiple components needing better focus handling, or updates to a shared utility.
- When in doubt, ask: could this be solved by the same type of code change, utility function, or design refactor?

Cards to cluster:
#{cardsText}
#{existingClustersText}

Respond ONLY with a valid JSON object without any explanatory text. The JSON should have this exact structure:
{"clusters": [{"clusterName": "descriptive_name", "cards": [{"id": "card_id", "title": "card_title"}]}]}

If clustering is not possible, return: {"clusters": []}
"""
  
  log "Prompt built successfully (${prompt.length} characters)"
  return prompt

# Function to extract cluster names from results
extractClusterNames = (clusterResults) ->
  clusterNames = []
  for cluster in clusterResults.clusters
    clusterNames.push(cluster.clusterName) unless clusterNames.includes(cluster.clusterName)
  return clusterNames

# Function to process batches
processBatches = (batches, isRefinement = false) ->
  allResults = []
  localExistingClusters = if isRefinement then [] else [...existingClusters]
  
  # Process each batch
  for batch, index in batches
    log "Processing batch #{index + 1} of #{batches.length}..." + (if isRefinement then " (REFINEMENT)" else ""), true
    log "Using temperature: #{temperature} (#{temperatureMap[temperature]})"
    
    # Build the prompt
    prompt = buildPrompt(batch, localExistingClusters, {
      current: index + 1, 
      total: batches.length
    }, isRefinement)
    
    # Call OpenAI
    log "Calling OpenAI for batch #{index + 1}..."
    result = callOpenAI(prompt)
    
    # Store the results
    if result.clusters && result.clusters.length > 0
      allResults.push(result)
      
      # Extract cluster names to use for next batches (not needed for refinement)
      unless isRefinement
        newClusters = extractClusterNames(result)
        for clusterName in newClusters
          localExistingClusters.push(clusterName) unless localExistingClusters.includes(clusterName)
      
      log "Batch #{index + 1} processed. Found #{result.clusters.length} clusters:"
      for cluster in result.clusters
        log "  - #{cluster.clusterName} (#{cluster.cards.length} issues)"
    else
      log "Batch #{index + 1} processed. No clusters found."
    
    # Add a delay to avoid rate limiting
    if index < batches.length - 1
      log "Waiting 3 seconds before processing next batch...", true
      execSync('sleep 3')
  
  return allResults

# Function to merge all results
mergeResults = (batchResults) ->
  mergedClusters = {}
  
  log "Merging results from #{batchResults.length} batches..."
  
  # Merge all clusters
  for result in batchResults
    for cluster in result.clusters
      clusterName = cluster.clusterName
      
      # Create cluster if it doesn't exist
      unless mergedClusters[clusterName]
        mergedClusters[clusterName] = []
      
      # Add cards to cluster
      for card in cluster.cards
        # Avoid duplicates
        unless mergedClusters[clusterName].some((c) -> c.id == card.id)
          # Find the corresponding issue to get the URL and preserve the Project V2 Item ID
          issue = issueMap[card.id]
          cardWithUrl = {
            id: card.id, # This is the Project V2 Item ID
            issueNumber: issue?.issueNumber || card.issueNumber || "",
            title: card.title,
            url: issue?.url || ""
          }
          mergedClusters[clusterName].push(cardWithUrl)
  
  # Convert to final format
  finalClusters = []
  for clusterName, cards of mergedClusters
    finalClusters.push({
      clusterName: clusterName,
      cards: cards
    })
  
  # Sort clusters by size (largest first)
  finalClusters.sort((a, b) -> b.cards.length - a.cards.length)
  
  log "Merged into #{finalClusters.length} unique clusters"
  return { clusters: finalClusters }

# Function to find uncategorized issues
findUncategorizedIssues = (allIssues, clusters) ->
  # Create a set of all issue IDs that have been categorized
  categorizedIds = new Set()
  for cluster in clusters
    for card in cluster.cards
      categorizedIds.add(card.id)
  
  # Find issues that are not in any cluster
  uncategorizedIssues = allIssues.filter((issue) -> !categorizedIds.has(issue.id))
  return uncategorizedIssues

# Function to build prompt for refining a specific cluster
buildRefinementPrompt = (clusterName, issues) ->
  # Build the list of cards to refine
  cardsText = issues.map((issue) ->
    # Include error details if available for better clustering of test failures
    errorSection = if issue.errorDetails then "\nError Details: #{issue.errorDetails.substring(0, 500)}#{if issue.errorDetails.length > 500 then '...' else ''}" else ""
    labelsSection = if issue.labels then "\nLabels: #{issue.labels.join(', ')}" else ""
    
    "- \"#{issue.title}\" (ID: #{issue.id})#{labelsSection}\nDescription: #{issue.body.substring(0, 200)}#{if issue.body.length > 200 then '...' else ''}#{errorSection}"
  ).join('\n\n')
  
  # Construct the prompt for refining with the new prompt text
  prompt = """
You are a clustering assistant specializing in software issues. Your task is to break down a previously grouped cluster of issues into smaller, more specific clusters.

The original cluster is named "#{clusterName}". Your job is to divide the issues from this cluster into 2–5 smaller groups, each with a more specific shared solution pattern.

### Guidelines:
- Create 2–5 refined clusters based on how the issues can be fixed.
- Cluster names should start with "#{clusterName}: " followed by a specific fix type, affected component, or shared technical pattern.
- Each cluster should ideally have 5–10 issues, though smaller clusters are okay if they represent a very targeted problem.
- Avoid vague terms like "UI/UX", "Miscellaneous", or "Rendering" unless the issues genuinely share the same fix.
- Prefer naming clusters after solution strategies (e.g., "Fix alt text", "Adjust sidebar layout", "Correct dropdown behavior").
- Reuse specific fix-based cluster names across parent clusters when they describe the same kind of solution.
- If any issues don't clearly fit a subcluster, group them under: "#{clusterName}: One-off Fixes (Unclustered)"
- Every issue must be assigned to exactly one cluster.

### Examples of refined cluster names:
- Fix markdown rendering: Incorrect MathJax output
- Improve focus handling: Keyboard trap in modals
- Project sidebar layout: Misaligned on zoom
- GraphQL errors: Missing required field on mutation

Issues to refine:
#{cardsText}

### Output format:
Return a JSON object with this structure:

{
  "clusters": [
    {
      "clusterName": "#{clusterName}: Specific Subcluster",
      "cards": [
        { "id": "card_id", "title": "card_title" },
        ...
      ]
    },
    ...
  ]
}

If further refinement is not possible or the cluster is already specific enough, return the original cluster:
{"clusters": [{"clusterName": "#{clusterName}", "cards": [{"id": "card_id", "title": "card_title"}]}]}
"""
  
  log "Refinement prompt built for '#{clusterName}' with #{issues.length} issues"
  return prompt

# Function to refine clusters recursively
refineClusters = (clusters, issueMap, minSize = 11, maxDepth = 3, currentDepth = 0) ->
  log "Refining clusters, depth #{currentDepth}/#{maxDepth}", true
  
  # If we've reached the maximum recursion depth, stop refining
  if currentDepth >= maxDepth
    log "Maximum recursion depth reached, stopping refinement"
    return clusters
  
  refinedClusters = []
  
  # Process each cluster
  for cluster in clusters
    # Skip small clusters that don't need refinement
    if cluster.cards.length < minSize
      refinedClusters.push(cluster)
      continue
    
    # Get the full issue objects for this cluster
    clusterIssues = cluster.cards.map((card) -> issueMap[card.id])
    
    log "Refining cluster '#{cluster.clusterName}' with #{cluster.cards.length} issues...", true
    
    # Build refinement prompt
    prompt = buildRefinementPrompt(cluster.clusterName, clusterIssues)
    
    # Call OpenAI for refinement
    log "Calling OpenAI to refine cluster '#{cluster.clusterName}'..."
    result = callOpenAI(prompt)
    
    if result.clusters && result.clusters.length > 1
      log "Successfully refined '#{cluster.clusterName}' into #{result.clusters.length} subclusters"
      
      # Add each refined subcluster with URLs
      for subcluster in result.clusters
        # Add URL to each card in the subcluster
        cardsWithUrls = subcluster.cards.map((card) ->
          # Find original card with URL from the parent cluster
          originalCard = cluster.cards.find((c) -> c.id == card.id) || {}
          return {
            id: card.id,
            title: card.title,
            url: originalCard.url || issueMap[card.id]?.url || ""
          }
        )
        
        # Create the subcluster with the enhanced cards
        refinedClusters.push({
          clusterName: subcluster.clusterName,
          cards: cardsWithUrls
        })
    else
      # Couldn't refine further or got only one subcluster, keep the original
      log "Could not further refine '#{cluster.clusterName}', keeping as is"
      refinedClusters.push(cluster)
    
    # Add a delay to avoid rate limiting
    execSync('sleep 1')
  
  # If we successfully refined some clusters, recurse on the result
  if refinedClusters.length > clusters.length
    return refineClusters(refinedClusters, issueMap, minSize, maxDepth, currentDepth + 1)
  else
    # No more refinement possible
    return refinedClusters

# Process uncategorized issues in batches
processUncategorizedIssues = (uncategorizedIssues) ->
  log "Processing #{uncategorizedIssues.length} uncategorized issues in batches...", true
  
  # Create batches of uncategorized issues
  refineBatches = createBatches(uncategorizedIssues, maxRefineBatchSize)
  log "Created #{refineBatches.length} batches for uncategorized issues refinement", true
  
  # Process each batch
  refinementResults = processBatches(refineBatches, true)
  
  # Merge the refinement results
  mergedRefinements = mergeResults(refinementResults)
  
  log "Uncategorized issues refinement complete. Found #{mergedRefinements.clusters.length} new clusters", true
  
  return mergedRefinements.clusters

# Main process
log "Reading issues from #{inputFile}...", true
allIssues = readIssues()
log "Found #{allIssues.length} issues.", true

# Create a map of issue ID to issue object for quick lookup
issueMap = {}
for issue in allIssues
  issueMap[issue.id] = issue

log "Creating batches of #{batchSize} issues...", true
batches = createBatches(allIssues, batchSize)
log "Created #{batches.length} batches.", true

log "Processing batches...", true
batchResults = processBatches(batches)

log "Merging results...", true
firstPassResult = mergeResults(batchResults)

# Find uncategorized issues
uncategorizedIssues = findUncategorizedIssues(allIssues, firstPassResult.clusters)
log "Found #{uncategorizedIssues.length} uncategorized issues", true

# Save the first pass results
firstPassOutputFile = "clusters_first_pass_#{timestamp}.json"
fs.writeFileSync(firstPassOutputFile, JSON.stringify(firstPassResult, null, 2))
log "First pass clusters saved to: #{firstPassOutputFile}", true

# Process uncategorized issues separately if there are many
uncategorizedClusters = []
if uncategorizedIssues.length > 0
  log "Processing uncategorized issues...", true
  uncategorizedClusters = processUncategorizedIssues(uncategorizedIssues.map((issue) -> issue))
  
  # Add the new clusters to the first pass results
  for cluster in uncategorizedClusters
    firstPassResult.clusters.push(cluster)
  
  # Check for any remaining uncategorized issues
  stillUncategorized = findUncategorizedIssues(allIssues, firstPassResult.clusters)
  
  if stillUncategorized.length > 0
    log "After refinement, #{stillUncategorized.length} issues remain uncategorized", true
    # Add these to a special "No cluster" group with URLs
    firstPassResult.clusters.push({
      clusterName: "No cluster - requires manual review",
      cards: stillUncategorized.map((issue) -> {
        id: issue.id, 
        title: issue.title || "Unknown Issue",
        url: issue.url || ""  # Include URL here too
      })
    })

# Apply recursive refinement if not skipped
finalClusters = firstPassResult.clusters
if !skipRecursiveRefinement
  # Refine large clusters recursively
  log "Starting recursive cluster refinement...", true
  finalClusters = refineClusters(firstPassResult.clusters, issueMap, 11, 3)

# Create the final result
finalResult = { clusters: finalClusters }

# Write the final results
log "Writing refined results to #{outputFile}...", true
fs.writeFileSync(outputFile, JSON.stringify(finalResult, null, 2))

# Remove the first pass file
try
  log "Removing first pass file: #{firstPassOutputFile}", true
  fs.unlinkSync(firstPassOutputFile)
  log "First pass file removed successfully"
catch error
  log "Warning: Could not remove first pass file: #{error}"

totalCards = 0
for cluster in finalResult.clusters
  totalCards += cluster.cards.length

log "Done! Found #{finalResult.clusters.length} refined clusters with #{totalCards} total issues.", true
log "Results saved to: #{outputFile}", true

# Print top clusters summary
if finalResult.clusters.length > 0
  log "\nTop clusters:", true
  topClusters = finalResult.clusters.slice(0, 50) # Show more clusters since we've refined them
  for cluster, index in topClusters
    log "#{index + 1}. #{cluster.clusterName} (#{cluster.cards.length} issues)", true

log "Log file saved to: #{logFile}", true
