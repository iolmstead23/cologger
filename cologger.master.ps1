<#
COLOGGER MASTER - STANDALONE BUILD
CONFIGURATION: Edit variables below
REQUIREMENTS: PowerShell 5.1+, LLM API service (Ollama/LM Studio)
EXTERNAL FILES: prompts/ folder with .txt templates
USAGE: .\CoLogger-Master.ps1
#>
#Requires -Version 5.1
$ErrorActionPreference='Stop'
$LLM_ENDPOINT='http://localhost'
$LLM_PORT=11434
$LLM_PATH='/v1/chat/completions'
$LLM_MODEL='qwen2.5:latest'
$LLM_TEMPERATURE=0.3
$LLM_MAX_TOKENS=4096
$LLM_TIMEOUT=30
$DEFAULT_PROMPT='You are an expert log analysis assistant for IT Service Desk. Analyze the provided logs and identify errors, warnings, and issues. Provide clear, actionable insights.'
$SCRIPT_ROOT=$PSScriptRoot
function Get-Configuration{
param()
try{
return [PSCustomObject]@{
apiEndpoint=$LLM_ENDPOINT;apiPort=$LLM_PORT;apiPath=$LLM_PATH
model=$LLM_MODEL;temperature=$LLM_TEMPERATURE;maxTokens=$LLM_MAX_TOKENS
timeoutSeconds=$LLM_TIMEOUT;systemPrompt=$DEFAULT_PROMPT
}
}catch{Write-Error "Failed to load configuration: $_";throw}
}
function Clear-Screen{Clear-Host}
function Show-Header{
try{
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "    CoLogger - Log Analysis    " -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
}catch{Write-Error "Failed to display menu header: $_"}
}
function Show-Option{
param([Parameter(Mandatory=$true)][int]$OptionNumber,[Parameter(Mandatory=$true)][string]$OptionText)
try{Write-Host "$OptionNumber. $OptionText" -ForegroundColor White}catch{Write-Error "Failed to display menu option: $_"}
}
function Get-Choice{
param([Parameter(Mandatory=$true)][int]$MinChoice,[Parameter(Mandatory=$true)][int]$MaxChoice)
try{
Write-Host ""
$userInput=Read-Host "Enter your choice ($MinChoice-$MaxChoice)"
$choiceNumber=0
if(-not [int]::TryParse($userInput,[ref]$choiceNumber)){
Write-Warning "Invalid input. Please enter a number between $MinChoice and $MaxChoice."
return -1
}
if($choiceNumber -lt $MinChoice -or $choiceNumber -gt $MaxChoice){
Write-Warning "Invalid choice. Please select a number between $MinChoice and $MaxChoice."
return -1
}
return $choiceNumber
}catch{Write-Error "Failed to get user menu choice: $_";return -1}
}
function Show-Menu{
try{
Clear-Screen
Show-Header
Show-Option -OptionNumber 1 -OptionText "Test LLM Connection"
Show-Option -OptionNumber 2 -OptionText "Analyze Logs & Generate Report"
Show-Option -OptionNumber 3 -OptionText "Exit"
$userChoice=Get-Choice -MinChoice 1 -MaxChoice 3
return $userChoice
}catch{Write-Error "Failed to display main menu: $_";return -1}
}
function Test-LogFolder{
param()
$path=Join-Path $SCRIPT_ROOT 'logs'
if(Test-Path $path -PathType Container){return $true}
Write-Warning "Logs folder not found: $path"
return $false
}
function Get-Logs{
try{
if(-not (Test-LogFolder)){
Write-Warning "Cannot get log files - logs folder does not exist."
return @()
}
$path=Join-Path $SCRIPT_ROOT 'logs'
try{
$logFiles=Get-ChildItem -Path $path -Filter "*.log" -File -ErrorAction Stop
if($logFiles.Count -eq 0){
Write-Warning "No .log files found in: $path"
return @()
}
return $logFiles.FullName
}catch{Write-Error "Failed to retrieve log files: $_";return @()}
}catch{Write-Error "Failed to get log files: $_";return @()}
}
function Get-Metadata{
param([Parameter(Mandatory=$true)][string]$FilePath)
try{
if(-not (Test-Path -Path $FilePath -PathType Leaf)){
Write-Error "Log file not found: $FilePath"
return $null
}
try{
$fileInfo=Get-Item -Path $FilePath -ErrorAction Stop
$metadata=[PSCustomObject]@{
Name=$fileInfo.Name;SizeBytes=$fileInfo.Length
SizeKB=[math]::Round($fileInfo.Length/1KB,2);SizeMB=[math]::Round($fileInfo.Length/1MB,2)
LastModified=$fileInfo.LastWriteTime;FullPath=$fileInfo.FullName
}
return $metadata
}catch{Write-Error "Failed to retrieve file metadata: $_";return $null}
}catch{Write-Error "Failed to get log file metadata: $_";return $null}
}
function Read-Log{
param([Parameter(Mandatory=$true)][string]$FilePath)
try{
if(-not (Test-Path -Path $FilePath -PathType Leaf)){
Write-Error "Log file not found: $FilePath"
return $null
}
$metadata=Get-Metadata -FilePath $FilePath
if($metadata.SizeMB -gt 10){
Write-Warning "Large log file detected: $($metadata.Name) ($($metadata.SizeMB) MB)"
}
try{
$content=Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
return $content
}catch{Write-Error "Failed to read log file content: $_";return $null}
}catch{Write-Error "Failed to read log file: $_";return $null}
}
function Get-Combined{
try{
$logFilePaths=Get-Logs
if($logFilePaths.Count -eq 0){
Write-Warning "No log files available to read."
return $null
}
$combinedContent=New-Object System.Text.StringBuilder
foreach($logFilePath in $logFilePaths){
$metadata=Get-Metadata -FilePath $logFilePath
if($null -eq $metadata){
Write-Warning "Failed to get metadata for: $logFilePath"
continue
}
$fileContent=Read-Log -FilePath $logFilePath
if($null -eq $fileContent){
Write-Warning "Failed to read content for: $logFilePath"
continue
}
[void]$combinedContent.AppendLine("=" * 80)
[void]$combinedContent.AppendLine("FILE: $($metadata.Name)")
[void]$combinedContent.AppendLine("SIZE: $($metadata.SizeKB) KB")
[void]$combinedContent.AppendLine("MODIFIED: $($metadata.LastModified)")
[void]$combinedContent.AppendLine("=" * 80)
[void]$combinedContent.AppendLine("")
[void]$combinedContent.AppendLine($fileContent)
[void]$combinedContent.AppendLine("")
}
Write-Host "Combined $($logFilePaths.Count) log file(s) successfully."
return $combinedContent.ToString()
}catch{Write-Error "Failed to get combined log content: $_";return $null}
}
function Build-Payload{
param([Parameter(Mandatory=$true)][string]$SystemPrompt,[Parameter(Mandatory=$true)][string]$UserMessage,[string]$Model='default',[ValidateRange(0.0,1.0)][double]$Temperature=0.3,[ValidateRange(1,100000)][int]$MaxTokens=4096)
try{
$requestObject=@{
model=$Model;messages=@(@{role='system';content=$SystemPrompt},@{role='user';content=$UserMessage})
temperature=$Temperature;max_tokens=$MaxTokens
}
try{
$jsonPayload=$requestObject|ConvertTo-Json -Depth 10 -ErrorAction Stop
return $jsonPayload
}catch{Write-Error "Failed to convert request object to JSON: $_";return $null}
}catch{Write-Error "Failed to build LLM request payload: $_";return $null}
}
function Send-Request{
param([Parameter(Mandatory=$true)][string]$ApiUrl,[Parameter(Mandatory=$true)][string]$JsonPayload,[ValidateRange(1,300)][int]$TimeoutSeconds=30)
try{
try{
$response=Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $JsonPayload -ContentType "application/json" -TimeoutSec $TimeoutSeconds -ErrorAction Stop
return $response
}catch{Write-Error "Failed to send request to LLM API: $_";return $null}
}catch{Write-Error "Failed to execute LLM request: $_";return $null}
}
function Test-Connection{
param([Parameter(Mandatory=$true)][string]$ApiEndpoint,[Parameter(Mandatory=$true)][ValidateRange(1,65535)][int]$ApiPort,[Parameter(Mandatory=$true)][string]$ApiPath,[string]$Model='qwen2.5:latest',[ValidateRange(1,60)][int]$TimeoutSeconds=10)
try{
$apiUrl="$($ApiEndpoint):$($ApiPort)$($ApiPath)"
Write-Host "Testing LLM connection to: $apiUrl"
$testPayload=Build-Payload -SystemPrompt "You are a helpful assistant." -UserMessage "Respond with OK if you can read this." -Model $Model -Temperature 0.1 -MaxTokens 10
if($null -eq $testPayload){
Write-Error "Failed to build test payload"
return $false
}
$response=Send-Request -ApiUrl $apiUrl -JsonPayload $testPayload -TimeoutSeconds $TimeoutSeconds
if($null -eq $response){
Write-Warning "LLM API did not respond or returned an error"
return $false
}
Write-Host "LLM connection successful!" -ForegroundColor Green
return $true
}catch{Write-Error "Failed to test LLM connection: $_";return $false}
}
function Invoke-Analysis{
param([Parameter(Mandatory=$true)][string]$LogContent,[Parameter(Mandatory=$true)][string]$ApiEndpoint,[Parameter(Mandatory=$true)][ValidateRange(1,65535)][int]$ApiPort,[Parameter(Mandatory=$true)][string]$ApiPath,[Parameter(Mandatory=$true)][string]$SystemPrompt,[string]$Model='default',[ValidateRange(0.0,1.0)][double]$Temperature=0.3,[ValidateRange(1,100000)][int]$MaxTokens=4096,[ValidateRange(1,300)][int]$TimeoutSeconds=30)
try{
$apiUrl="$($ApiEndpoint):$($ApiPort)$($ApiPath)"
Write-Host "Sending logs to LLM for analysis..."
$userMessage="Please analyze the following logs and identify any errors, warnings, or issues. Provide clear, actionable insights:`n`n$LogContent"
$payload=Build-Payload -SystemPrompt $SystemPrompt -UserMessage $userMessage -Model $Model -Temperature $Temperature -MaxTokens $MaxTokens
if($null -eq $payload){
Write-Error "Failed to build analysis request payload"
return $null
}
$response=Send-Request -ApiUrl $apiUrl -JsonPayload $payload -TimeoutSeconds $TimeoutSeconds
if($null -eq $response){
Write-Error "Failed to get analysis response from LLM"
return $null
}
try{
$analysisText=$response.choices[0].message.content
Write-Host "Analysis received successfully from LLM" -ForegroundColor Green
return $analysisText
}catch{Write-Error "Failed to extract analysis text from response: $_";return $null}
}catch{Write-Error "Failed to invoke LLM analysis: $_";return $null}
}
function Test-ReportFolder{
param()
$path=Join-Path $SCRIPT_ROOT 'reports'
if(Test-Path $path -PathType Container){return $true}
Write-Warning "Reports folder not found: $path"
return $false
}
function Get-ReportName{
try{
$timestamp=Get-Date -Format "yyyy-MM-dd_HHmmss"
$filename="Report_$timestamp.md"
return $filename
}catch{Write-Error "Failed to generate report filename: $_";return $null}
}
function Format-Section{
param([Parameter(Mandatory=$true)][string]$HeaderText,[Parameter(Mandatory=$true)][AllowEmptyString()][string]$Content,[ValidateRange(1,6)][int]$HeaderLevel=2)
try{
$headerPrefix="#"*$HeaderLevel
$formattedSection="$headerPrefix $HeaderText`n`n$Content`n"
return $formattedSection
}catch{Write-Error "Failed to format report section: $_";return $null}
}
function New-Report{
param([Parameter(Mandatory=$true)][string]$AnalysisText,[Parameter(Mandatory=$true)][string[]]$LogFileNames,[string]$Summary='Log analysis completed successfully.')
try{
$reportBuilder=New-Object System.Text.StringBuilder
$timestamp=Get-Date -Format "yyyy-MM-dd HH:mm:ss"
[void]$reportBuilder.AppendLine("# Log Analysis Report")
[void]$reportBuilder.AppendLine("**Generated:** $timestamp")
[void]$reportBuilder.AppendLine("")
$summarySection=Format-Section -HeaderText "Summary" -Content $Summary -HeaderLevel 2
[void]$reportBuilder.Append($summarySection)
[void]$reportBuilder.AppendLine("")
$logSourcesList=($LogFileNames|ForEach-Object{"- $_"})-join "`n"
$logSourcesSection=Format-Section -HeaderText "Log Sources Analyzed" -Content $logSourcesList -HeaderLevel 2
[void]$reportBuilder.Append($logSourcesSection)
[void]$reportBuilder.AppendLine("")
$analysisSection=Format-Section -HeaderText "Detailed Analysis" -Content $AnalysisText -HeaderLevel 2
[void]$reportBuilder.Append($analysisSection)
return $reportBuilder.ToString()
}catch{Write-Error "Failed to create report: $_";return $null}
}
function Save-Report{
param([Parameter(Mandatory=$true)][string]$ReportContent,[string]$CustomFileName)
try{
if(-not (Test-ReportFolder)){
Write-Warning "Reports folder does not exist. Creating it now..."
$path=Join-Path $SCRIPT_ROOT 'reports'
New-Item -Path $path -ItemType Directory -Force|Out-Null
}
$fileName=if($CustomFileName){$CustomFileName}else{Get-ReportName}
if($null -eq $fileName){
Write-Error "Failed to determine report filename"
return $false
}
$path=Join-Path $SCRIPT_ROOT 'reports'
$fullPath=Join-Path -Path $path -ChildPath $fileName
try{
Set-Content -Path $fullPath -Value $ReportContent -Encoding UTF8 -ErrorAction Stop
Write-Host "Report saved successfully: $fullPath" -ForegroundColor Green
return $true
}catch{Write-Error "Failed to write report file: $_";return $false}
}catch{Write-Error "Failed to save report to file: $_";return $false}
}
function Test-PromptsFolder{
param()
$path=Join-Path $SCRIPT_ROOT 'prompts'
if(Test-Path $path -PathType Container){return $true}
Write-Warning "Prompts folder not found: $path"
return $false
}
function Get-Templates{
try{
if(-not (Test-PromptsFolder)){return @()}
$path=Join-Path $SCRIPT_ROOT 'prompts'
try{
$templateFiles=Get-ChildItem -Path $path -Filter "*.txt" -File -ErrorAction Stop|Where-Object{$_.Name -ne "README.txt"}
if($templateFiles.Count -eq 0){return @()}
$templates=@()
foreach($file in $templateFiles){
$baseName=[System.IO.Path]::GetFileNameWithoutExtension($file.Name)
$withSpaces=$baseName -replace '[-_]',' '
$words=$withSpaces -split '\s+'
$titleCasedWords=$words|ForEach-Object{if($_.Length -gt 0){$_.Substring(0,1).ToUpper()+$_.Substring(1).ToLower()}}
$displayName=($titleCasedWords -join ' ')
$templates+=[PSCustomObject]@{DisplayName=$displayName;FileName=$file.Name;FilePath=$file.FullName}
}
return $templates
}catch{Write-Error "Failed to retrieve template files: $_";return @()}
}catch{Write-Error "Failed to get prompt templates: $_";return @()}
}
function Read-Template{
param([Parameter(Mandatory=$true)][string]$FilePath)
try{
if(-not (Test-Path -Path $FilePath -PathType Leaf)){
Write-Error "Template file not found: $FilePath"
return $null
}
try{
$content=Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
$trimmedContent=$content.Trim()
return $trimmedContent
}catch{Write-Error "Failed to read template file content: $_";return $null}
}catch{Write-Error "Failed to read template file: $_";return $null}
}
function Show-PromptMenu{
try{
Clear-Host
Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "   Select Analysis Prompt Template" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
$templates=Get-Templates
$optionNumber=1
$menuOptions=@{}
foreach($template in $templates){
Write-Host "$optionNumber. $($template.DisplayName)" -ForegroundColor White
$menuOptions[$optionNumber]=$template
$optionNumber++
}
Write-Host "$optionNumber. Default (Standard IT Service Desk analysis)" -ForegroundColor White
$menuOptions[$optionNumber]=@{DisplayName="Default";PromptSource="default"}
$maxChoice=$optionNumber
Write-Host ""
$userInput=Read-Host "Enter your choice (1-$maxChoice)"
$choice=0
if(-not [int]::TryParse($userInput,[ref]$choice)){
Write-Warning "Invalid input. Using default prompt."
return @{PromptSource="default";TemplateContent="";CustomText=""}
}
if($choice -lt 1 -or $choice -gt $maxChoice){
Write-Warning "Invalid choice. Using default prompt."
return @{PromptSource="default";TemplateContent="";CustomText=""}
}
$selectedOption=$menuOptions[$choice]
Write-Host ""
Write-Host "Selected: $($selectedOption.DisplayName)" -ForegroundColor Green
Write-Host ""
$templateContent=""
if($selectedOption.PromptSource -ne "default"){
$templateContent=Read-Template -FilePath $selectedOption.FilePath
if([string]::IsNullOrWhiteSpace($templateContent)){
Write-Error "Failed to read template file. Using default prompt."
return @{PromptSource="default";TemplateContent="";CustomText=""}
}
}
Write-Host "Would you like to add custom instructions? (Y/N)" -NoNewline
$addCustom=Read-Host " "
$customText=""
if($addCustom -eq "Y" -or $addCustom -eq "y"){
Write-Host ""
Write-Host "Enter custom text to append:" -ForegroundColor Cyan
$customText=Read-Host
}
return @{
PromptSource=if($selectedOption.PromptSource -eq "default"){"default"}else{"template"}
TemplateContent=$templateContent;CustomText=$customText
}
}catch{Write-Error "Failed to show prompt selection menu: $_";return @{PromptSource="default";TemplateContent="";CustomText=""}}
}
function Build-Prompt{
param([Parameter(Mandatory=$true)][string]$TemplateContent,[string]$CustomText='')
try{
if([string]::IsNullOrWhiteSpace($CustomText)){return $TemplateContent}
$finalPrompt="$TemplateContent`n`n--- Additional Instructions ---`n$CustomText"
return $finalPrompt
}catch{Write-Error "Failed to build final system prompt: $_";return $TemplateContent}
}
function Get-DefaultPrompt{
try{
$defaultPrompt="You are an expert log analysis assistant for IT Service Desk. Analyze the provided logs and identify errors, warnings, and issues. Provide clear, actionable insights."
return $defaultPrompt
}catch{Write-Error "Failed to get default system prompt: $_";throw}
}
function Initialize-Folders{
try{
Write-Host "Validating required folders..." -ForegroundColor Cyan
$requiredFolders=@('logs','reports','prompts')
foreach($folderName in $requiredFolders){
$folderPath=Join-Path -Path $SCRIPT_ROOT -ChildPath $folderName
if(Test-Path -Path $folderPath -PathType Container){continue}
Write-Warning "Folder '$folderName' does not exist. Creating it now..."
try{
New-Item -Path $folderPath -ItemType Directory -Force -ErrorAction Stop|Out-Null
Write-Host "Created folder: $folderPath" -ForegroundColor Green
}catch{Write-Error "Failed to create folder '$folderName': $_";return $false}
}
Write-Host "All required folders validated successfully." -ForegroundColor Green
return $true
}catch{Write-Error "Failed to initialize required folders: $_";return $false}
}
function Invoke-TestConnection{
try{
Write-Host "`n" -NoNewline
Write-Host "=== Test LLM Connection ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Loading configuration..." -ForegroundColor Cyan
$config=Get-Configuration
if($null -eq $config){
Write-Error "Failed to load configuration"
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host "Validating configuration settings..." -ForegroundColor Cyan
if([string]::IsNullOrWhiteSpace($config.apiEndpoint)){
Write-Error "Configuration missing 'apiEndpoint' field"
Write-Host "Suggestion: Edit script variables at top of CoLogger-Master.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
if($null -eq $config.apiPort -or $config.apiPort -lt 1 -or $config.apiPort -gt 65535){
Write-Error "Configuration has invalid 'apiPort' value"
Write-Host "Suggestion: Edit script variables at top of CoLogger-Master.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
if([string]::IsNullOrWhiteSpace($config.apiPath)){
Write-Error "Configuration missing 'apiPath' field"
Write-Host "Suggestion: Edit script variables at top of CoLogger-Master.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
$fullApiUrl="$($config.apiEndpoint):$($config.apiPort)$($config.apiPath)"
Write-Host "  API Endpoint: $fullApiUrl" -ForegroundColor Gray
Write-Host ""
Write-Host "Testing connection to LLM API..." -ForegroundColor Cyan
$timeoutSeconds=if($config.timeoutSeconds){$config.timeoutSeconds}else{10}
$connectionSuccessful=Test-Connection -ApiEndpoint $config.apiEndpoint -ApiPort $config.apiPort -ApiPath $config.apiPath -Model $config.model -TimeoutSeconds $timeoutSeconds
Write-Host ""
if($connectionSuccessful){
Write-Host "[OK] LLM API connection successful!" -ForegroundColor Green
Write-Host "  The LLM service is reachable and responding." -ForegroundColor Green
}else{
Write-Host "[FAILED] LLM API connection failed" -ForegroundColor Red
Write-Host ""
Write-Host "Troubleshooting Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify your LLM service (e.g. LM Studio, Ollama) is running" -ForegroundColor Yellow
Write-Host "  2. Check the API endpoint: $fullApiUrl" -ForegroundColor Yellow
Write-Host "  3. Ensure firewall is not blocking port $($config.apiPort)" -ForegroundColor Yellow
Write-Host "  4. Test connectivity: Test-NetConnection localhost -Port $($config.apiPort)" -ForegroundColor Yellow
Write-Host "  5. Verify the API path is correct for your LLM service" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}catch{
Write-Error "An unexpected error occurred while testing LLM connection: $_"
Write-Host "Suggestion: Check the error message above for details" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
}
function Invoke-Analyze{
try{
Write-Host "`n" -NoNewline
Write-Host "=== Analyze Logs and Generate Report ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checking logs folder..." -ForegroundColor Cyan
$logFolderExists=Test-LogFolder
if(-not $logFolderExists){
Write-Error "Logs folder not found"
Write-Host "Suggestion: Ensure the 'logs' folder exists in the application directory" -ForegroundColor Yellow
Write-Host "Place your .log files in the logs folder before running analysis" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host "Scanning for log files..." -ForegroundColor Cyan
$logFiles=Get-Logs
if($null -eq $logFiles -or $logFiles.Count -eq 0){
Write-Warning "No .log files found in logs folder"
Write-Host "Suggestion: Place .log files in the logs folder before running analysis" -ForegroundColor Yellow
Write-Host "Supported format: *.log files" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host "  → Found $($logFiles.Count) log file(s) to analyze" -ForegroundColor Gray
Write-Host ""
Write-Host "Reading log file contents..." -ForegroundColor Cyan
$combinedLogContent=Get-Combined
if([string]::IsNullOrWhiteSpace($combinedLogContent)){
Write-Error "Failed to read log file contents"
Write-Host "Suggestion: Check that log files are not locked or corrupted" -ForegroundColor Yellow
Write-Host "Verify file permissions allow read access" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
$logSizeKB=[math]::Round($combinedLogContent.Length/1KB,2)
Write-Host "  → Combined log size: $logSizeKB KB" -ForegroundColor Gray
if($logSizeKB -gt 100){
Write-Warning "Large log files detected. Analysis may take longer than usual."
}
Write-Host ""
Write-Host "Loading LLM configuration..." -ForegroundColor Cyan
$config=Get-Configuration
if($null -eq $config){
Write-Error "Failed to load configuration"
Write-Host "Suggestion: Edit script variables at top of CoLogger-Master.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host "  → Configuration loaded" -ForegroundColor Gray
Write-Host ""
Write-Host "Selecting analysis prompt..." -ForegroundColor Cyan
$promptSelection=Show-PromptMenu
if($null -eq $promptSelection){
Write-Error "Failed to select prompt template"
Write-Host "Using default prompt as fallback..." -ForegroundColor Yellow
$finalSystemPrompt=Get-DefaultPrompt
}else{
$basePrompt=if($promptSelection.PromptSource -eq "template"){$promptSelection.TemplateContent}else{Get-DefaultPrompt}
$finalSystemPrompt=Build-Prompt -TemplateContent $basePrompt -CustomText $promptSelection.CustomText
}
Write-Host "  → Prompt configured" -ForegroundColor Gray
Write-Host ""
Write-Host "Testing LLM connectivity..." -ForegroundColor Cyan
$timeoutSeconds=if($config.timeoutSeconds){$config.timeoutSeconds}else{10}
$llmConnectionSuccessful=Test-Connection -ApiEndpoint $config.apiEndpoint -ApiPort $config.apiPort -ApiPath $config.apiPath -Model $config.model -TimeoutSeconds $timeoutSeconds
if(-not $llmConnectionSuccessful){
Write-Error "Cannot connect to LLM API"
Write-Host "Suggestion: Run 'Test LLM Connection' menu option for detailed troubleshooting" -ForegroundColor Yellow
Write-Host "Ensure your LLM service (e.g. LM Studio, Ollama) is running" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host "  → LLM connection verified" -ForegroundColor Gray
Write-Host ""
Write-Host "Sending logs to LLM for analysis..." -ForegroundColor Cyan
Write-Host "  (This may take a while depending on log size and model speed)" -ForegroundColor Gray
Write-Host ""
$analysisResult=Invoke-Analysis -LogContent $combinedLogContent -ApiEndpoint $config.apiEndpoint -ApiPort $config.apiPort -ApiPath $config.apiPath -SystemPrompt $finalSystemPrompt -Model $config.model -Temperature $config.temperature -MaxTokens $config.maxTokens -TimeoutSeconds $config.timeoutSeconds
if([string]::IsNullOrWhiteSpace($analysisResult)){
Write-Error "Failed to receive analysis from LLM"
Write-Host "Suggestion: Check LLM service logs for errors" -ForegroundColor Yellow
Write-Host "Verify LLM has sufficient resources (RAM + GPU) to process request" -ForegroundColor Yellow
Write-Host "Consider reducing log size or maxTokens setting" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host "  → Analysis received from LLM" -ForegroundColor Gray
Write-Host ""
Write-Host "Generating report..." -ForegroundColor Cyan
$logFileNames=$logFiles|ForEach-Object{Split-Path -Path $_ -Leaf}
$reportSummary="Analysis of $($logFiles.Count) log file(s) totaling $logSizeKB KB"
$reportContent=New-Report -AnalysisText $analysisResult -LogFileNames $logFileNames -Summary $reportSummary
if([string]::IsNullOrWhiteSpace($reportContent)){
Write-Error "Failed to generate report"
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host "  → Report generated" -ForegroundColor Gray
Write-Host ""
Write-Host "Saving report..." -ForegroundColor Cyan
$reportSaved=Save-Report -ReportContent $reportContent
if(-not $reportSaved){
Write-Error "Failed to save report"
Write-Host "Suggestion: Check that reports folder exists and is writable" -ForegroundColor Yellow
Write-Host "Verify disk space is available" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
return
}
Write-Host ""
Write-Host "[OK] Analysis complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Report Details:" -ForegroundColor Cyan
Write-Host "  Files Analyzed: $($logFiles.Count)" -ForegroundColor White
Write-Host "  Total Size: $logSizeKB KB" -ForegroundColor White
Write-Host "  Report Location: .\reports\" -ForegroundColor White
Write-Host ""
Write-Host "Check the reports folder for your analysis results." -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}catch{
Write-Error "An unexpected error occurred during log analysis: $_"
Write-Host "Suggestion: Check the error message above for details" -ForegroundColor Yellow
Write-Host "Review log files for potential issues (corrupted data, invalid encoding)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
}
function Start-App{
try{
Write-Host ""
Write-Host "Starting CoLogger..." -ForegroundColor Cyan
Write-Host ""
if(-not (Initialize-Folders)){
Write-Error "Folder initialization failed. Cannot continue."
return
}
Write-Host ""
Write-Host "CoLogger initialized successfully!" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 2
$isRunning=$true
while($isRunning){
try{
$userChoice=Show-Menu
if($userChoice -eq -1){
Write-Host "Press any key to try again..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
continue
}
switch($userChoice){
1{Invoke-TestConnection}
2{Invoke-Analyze}
3{
Write-Host ""
Write-Host "Thank you for using CoLogger!" -ForegroundColor Cyan
Write-Host "Exiting..." -ForegroundColor Cyan
$isRunning=$false
}
default{
Write-Warning "Invalid menu option selected."
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
}
}catch{
Write-Error "An error occurred in the menu loop: $_"
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
}
}catch{
Write-Error "Fatal error in CoLogger application: $_"
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
}
Start-App
