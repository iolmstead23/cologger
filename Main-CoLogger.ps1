<#
.SYNOPSIS
    CoLogger - IT Service Desk Log Analysis Tool

.DESCRIPTION
    Main entry point for the CoLogger application. Analyzes log files using
    a local LLM API and generates markdown reports with analysis results.

.NOTES
    Script: Main-CoLogger.ps1
    Author: CoLogger Development Team
    Version: 1.0.0

.EXAMPLE
    .\Main-CoLogger.ps1
    Starts the CoLogger application with interactive menu.
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

#region Initialization

<#
.SYNOPSIS
    Validates that all required package modules exist.
#>
function Test-PackageModules {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Host "Validating package modules..." -ForegroundColor Cyan

        $requiredModules = @(
            'Configuration-Manager.psm1',
            'Menu-Display.psm1',
            'Log-File-Reader.psm1',
            'LLM-API-Client.psm1',
            'Report-Generator.psm1'
        )

        $packagesPath = Join-Path -Path $PSScriptRoot -ChildPath "packages"

        foreach ($moduleName in $requiredModules) {
            $modulePath = Join-Path -Path $packagesPath -ChildPath $moduleName
            if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
                Write-Error "Required module not found: $moduleName at $modulePath"
                return $false
            }
        }

        Write-Host "All package modules validated successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to validate package modules: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Imports all package modules into the current session.
#>
function Import-PackageModules {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Host "Importing package modules..." -ForegroundColor Cyan

        $modulesToImport = @(
            'Configuration-Manager',
            'Menu-Display',
            'Log-File-Reader',
            'LLM-API-Client',
            'Report-Generator'
        )

        $packagesPath = Join-Path -Path $PSScriptRoot -ChildPath "packages"

        foreach ($moduleName in $modulesToImport) {
            try {
                $modulePath = Join-Path -Path $packagesPath -ChildPath "$moduleName.psm1"
                Import-Module -Name $modulePath -Force -ErrorAction Stop
                Write-Verbose "Imported module: $moduleName"
            }
            catch {
                Write-Error "Failed to import module $moduleName : $_"
                return $false
            }
        }

        Write-Host "All package modules imported successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to import package modules: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Validates that required folders exist, creates them if missing.
#>
function Initialize-RequiredFolders {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Host "Validating required folders..." -ForegroundColor Cyan

        $requiredFolders = @('logs', 'reports')

        foreach ($folderName in $requiredFolders) {
            $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folderName

            if (Test-Path -Path $folderPath -PathType Container) {
                continue
            }

            # Folder doesn't exist, create it
            Write-Warning "Folder '$folderName' does not exist. Creating it now..."
            try {
                New-Item -Path $folderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Host "Created folder: $folderPath" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to create folder '$folderName': $_"
                return $false
            }
        }

        Write-Host "All required folders validated successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to initialize required folders: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Initializes application configuration.
#>
function Initialize-ApplicationConfiguration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Host "Initializing application configuration..." -ForegroundColor Cyan

        # Test if configuration file exists and is valid
        if (-not (Test-CoLoggerConfigurationFile)) {
            Write-Warning "Configuration file not found or invalid."

            # Initialize default configuration
            if (-not (Initialize-CoLoggerConfiguration)) {
                Write-Error "Failed to initialize default configuration."
                return $false
            }
        }

        # Load configuration to validate it works
        $config = Get-CoLoggerConfiguration
        if ($null -eq $config) {
            Write-Error "Failed to load configuration."
            return $false
        }

        Write-Host "Configuration initialized successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to initialize application configuration: $_"
        return $false
    }
}

#endregion

#region Menu Handlers

<#
.SYNOPSIS
    Handles the "Test LLM Connection" menu option.

.DESCRIPTION
    Tests connectivity to the local LLM API endpoint by loading configuration,
    validating settings, and attempting a simple connection test. Provides
    color-coded feedback and troubleshooting guidance if connection fails.

.NOTES
    This function orchestrates the LLM connection test workflow by calling
    the Get-CoLoggerConfiguration and Test-LLMConnection functions from
    the Configuration-Manager and LLM-API-Client modules respectively.
#>
function Invoke-TestLLMConnection {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n" -NoNewline
        Write-Host "=== Test LLM Connection ===" -ForegroundColor Cyan
        Write-Host ""

        #========================================================================
        # Step 1: Load Configuration
        # Retrieve API settings from config.json needed for LLM connectivity
        #========================================================================
        Write-Host "Loading configuration..." -ForegroundColor Cyan
        $configuration = Get-CoLoggerConfiguration

        # Validate that configuration was loaded successfully
        if ($null -eq $configuration) {
            Write-Error "Failed to load configuration file"
            Write-Host "Suggestion: Ensure config.json exists and is valid JSON" -ForegroundColor Yellow
            Write-Host "The configuration should have been created during startup." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        #========================================================================
        # Step 2: Validate Configuration Settings
        # Ensure all required API connection fields are present and valid
        #========================================================================
        Write-Host "Validating configuration settings..." -ForegroundColor Cyan

        # Check for required API endpoint
        if ([string]::IsNullOrWhiteSpace($configuration.apiEndpoint)) {
            Write-Error "Configuration missing 'apiEndpoint' field"
            Write-Host "Suggestion: Edit config.json and add 'apiEndpoint' field" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        # Check for required API port (must be valid port number)
        if ($null -eq $configuration.apiPort -or $configuration.apiPort -lt 1 -or $configuration.apiPort -gt 65535) {
            Write-Error "Configuration has invalid 'apiPort' value"
            Write-Host "Suggestion: Edit config.json and set 'apiPort' to a valid port (1-65535)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        # Check for required API path
        if ([string]::IsNullOrWhiteSpace($configuration.apiPath)) {
            Write-Error "Configuration missing 'apiPath' field"
            Write-Host "Suggestion: Edit config.json and add 'apiPath' field (e.g., '/v1/chat/completions')" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        #========================================================================
        # Step 3: Display Connection Details
        # Show user what endpoint we're attempting to connect to
        #========================================================================
        $fullApiUrl = "$($configuration.apiEndpoint):$($configuration.apiPort)$($configuration.apiPath)"
        Write-Host "  API Endpoint: $fullApiUrl" -ForegroundColor Gray
        Write-Host ""

        #========================================================================
        # Step 4: Test LLM Connection
        # Attempt to connect to the LLM API using the Test-LLMConnection function
        #========================================================================
        Write-Host "Testing connection to LLM API..." -ForegroundColor Cyan

        # Get timeout setting from config, default to 10 seconds for connection test
        if ($configuration.timeoutSeconds) {
            $timeoutSeconds = $configuration.timeoutSeconds
        } else {
            $timeoutSeconds = 10
        }

        # Call the Test-LLMConnection function from LLM-API-Client module
        $connectionSuccessful = Test-LLMConnection -ApiEndpoint $configuration.apiEndpoint -ApiPort $configuration.apiPort -ApiPath $configuration.apiPath -Model $configuration.model -TimeoutSeconds $timeoutSeconds

        #========================================================================
        # Step 5: Display Results
        # Provide color-coded feedback based on connection test result
        #========================================================================
        Write-Host ""
        if ($connectionSuccessful) {
            # Connection succeeded - display success message
            Write-Host "✓ LLM API connection successful!" -ForegroundColor Green
            Write-Host "  The LLM service is reachable and responding." -ForegroundColor Green
        }
        else {
            # Connection failed - display failure message with troubleshooting guidance
            Write-Host "✗ LLM API connection failed" -ForegroundColor Red
            Write-Host ""
            Write-Host "Troubleshooting Steps:" -ForegroundColor Yellow
            Write-Host "  1. Verify your LLM service (e.g. LM Studio, Ollama) is running" -ForegroundColor Yellow
            Write-Host "  2. Check the API endpoint in config.json: $fullApiUrl" -ForegroundColor Yellow
            Write-Host "  3. Ensure firewall is not blocking port $($configuration.apiPort)" -ForegroundColor Yellow
            Write-Host "  4. Test connectivity: Test-NetConnection localhost -Port $($configuration.apiPort)" -ForegroundColor Yellow
            Write-Host "  5. Verify the API path is correct for your LLM service" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        # Catch any unexpected errors during the connection test process
        Write-Error "An unexpected error occurred while testing LLM connection: $_"
        Write-Host "Suggestion: Check the error message above for details" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}

<#
.SYNOPSIS
    Handles the "Analyze Logs and Generate Report" menu option.

.DESCRIPTION
    Orchestrates the complete log analysis workflow including:
    - Validating logs folder and reading all .log files
    - Testing LLM connectivity
    - Sending combined logs to LLM for analysis
    - Generating markdown report from analysis results
    - Saving report with timestamp to reports folder

    This function coordinates all package modules to deliver the end-to-end
    log analysis functionality.

.NOTES
    This is the primary workflow function that ties together all CoLogger
    modules to perform comprehensive log analysis. It includes extensive
    error handling and user feedback at each step.
#>
function Invoke-AnalyzeLogsAndGenerateReport {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n" -NoNewline
        Write-Host "=== Analyze Logs and Generate Report ===" -ForegroundColor Cyan
        Write-Host ""

        #========================================================================
        # Phase A: Pre-flight Validation
        # Validates that logs exist and are readable before attempting analysis
        #========================================================================

        #------------------------------------------------------------------------
        # Step 1: Check Logs Folder Exists
        # Verify the logs folder is present in the application directory
        #------------------------------------------------------------------------
        Write-Host "Checking logs folder..." -ForegroundColor Cyan
        $logFolderExists = Test-LogFolderExists

        if (-not $logFolderExists) {
            Write-Error "Logs folder not found"
            Write-Host "Suggestion: Ensure the 'logs' folder exists in the application directory" -ForegroundColor Yellow
            Write-Host "Place your .log files in the logs folder before running analysis" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        #------------------------------------------------------------------------
        # Step 2: Get Log Files
        # Retrieve all .log files from the logs folder
        #------------------------------------------------------------------------
        Write-Host "Scanning for log files..." -ForegroundColor Cyan
        $logFiles = Get-LogFiles

        # Check if any log files were found
        if ($null -eq $logFiles -or $logFiles.Count -eq 0) {
            Write-Warning "No .log files found in logs folder"
            Write-Host "Suggestion: Place .log files in the logs folder before running analysis" -ForegroundColor Yellow
            Write-Host "Supported format: *.log files" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        # Display count of log files found
        Write-Host "  → Found $($logFiles.Count) log file(s) to analyze" -ForegroundColor Gray
        Write-Host ""

        #------------------------------------------------------------------------
        # Step 3: Read and Combine Log Contents
        # Read all log files and combine them with metadata separators
        #------------------------------------------------------------------------
        Write-Host "Reading log file contents..." -ForegroundColor Cyan
        $combinedLogContent = Get-CombinedLogContent

        # Validate that log content was successfully read
        if ([string]::IsNullOrWhiteSpace($combinedLogContent)) {
            Write-Error "Failed to read log file contents"
            Write-Host "Suggestion: Check that log files are not locked or corrupted" -ForegroundColor Yellow
            Write-Host "Verify file permissions allow read access" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        # Display size information about the combined logs
        $logSizeKB = [math]::Round($combinedLogContent.Length / 1KB, 2)
        Write-Host "  → Combined log size: $logSizeKB KB" -ForegroundColor Gray

        # Warn user if logs are very large (may take longer to process)
        if ($logSizeKB -gt 100) {
            Write-Warning "Large log files detected. Analysis may take longer than usual."
        }
        Write-Host ""

        #========================================================================
        # Phase B: LLM Communication
        # Tests connectivity and sends logs to LLM for analysis
        #========================================================================

        #------------------------------------------------------------------------
        # Step 4: Load Configuration
        # Retrieve LLM API settings from config.json
        #------------------------------------------------------------------------
        Write-Host "Loading LLM configuration..." -ForegroundColor Cyan
        $configuration = Get-CoLoggerConfiguration

        # Validate configuration was loaded successfully
        if ($null -eq $configuration) {
            Write-Error "Failed to load configuration"
            Write-Host "Suggestion: Ensure config.json exists and is valid" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        Write-Host "  → Configuration loaded" -ForegroundColor Gray
        Write-Host ""

        #------------------------------------------------------------------------
        # Step 5: Test LLM Connection
        # Verify LLM API is reachable before sending large log payload
        #------------------------------------------------------------------------
        Write-Host "Testing LLM connectivity..." -ForegroundColor Cyan
        if ($configuration.timeoutSeconds) {
            $timeoutSeconds = $configuration.timeoutSeconds
        } else {
            $timeoutSeconds = 10
        }
        $llmConnectionSuccessful = Test-LLMConnection -ApiEndpoint $configuration.apiEndpoint -ApiPort $configuration.apiPort -ApiPath $configuration.apiPath -Model $configuration.model -TimeoutSeconds $timeoutSeconds

        # If connection test fails, abort analysis
        if (-not $llmConnectionSuccessful) {
            Write-Error "Cannot connect to LLM API"
            Write-Host "Suggestion: Run 'Test LLM Connection' menu option for detailed troubleshooting" -ForegroundColor Yellow
            Write-Host "Ensure your LLM service (e.g., LM Studio, Ollama) is running" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        Write-Host "  → LLM connection verified" -ForegroundColor Gray
        Write-Host ""

        #------------------------------------------------------------------------
        # Step 6: Send Logs to LLM for Analysis
        # Transmit combined log content to LLM and receive analysis results
        #------------------------------------------------------------------------
        Write-Host "Sending logs to LLM for analysis..." -ForegroundColor Cyan
        Write-Host "  (This may take a while depending on log size and model speed)" -ForegroundColor Gray
        Write-Host ""

        # Call Invoke-LLMAnalysis with all required parameters from configuration
        $analysisResult = Invoke-LLMAnalysis -LogContent $combinedLogContent -ApiEndpoint $configuration.apiEndpoint -ApiPort $configuration.apiPort -ApiPath $configuration.apiPath -SystemPrompt $configuration.systemPrompt -Model $configuration.model -Temperature $configuration.temperature -MaxTokens $configuration.maxTokens -TimeoutSeconds $configuration.timeoutSeconds

        # Validate that analysis was received
        if ([string]::IsNullOrWhiteSpace($analysisResult)) {
            Write-Error "Failed to receive analysis from LLM"
            Write-Host "Suggestion: Check LLM service logs for errors" -ForegroundColor Yellow
            Write-Host "Verify LLM has sufficient resources (RAM + GPU) to process request" -ForegroundColor Yellow
            Write-Host "Consider reducing log size or maxTokens setting" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        Write-Host "  → Analysis received from LLM" -ForegroundColor Gray
        Write-Host ""

        #========================================================================
        # Phase C: Report Generation
        # Creates and saves markdown report with analysis results
        #========================================================================

        #------------------------------------------------------------------------
        # Step 7: Extract Log File Names for Report Metadata
        # Get just the filenames (not full paths) for report header
        #------------------------------------------------------------------------
        Write-Host "Generating report..." -ForegroundColor Cyan
        $logFileNames = $logFiles | ForEach-Object { Split-Path -Path $_ -Leaf }

        #------------------------------------------------------------------------
        # Step 8: Generate Markdown Report
        # Create formatted report with analysis results and metadata
        #------------------------------------------------------------------------
        $reportSummary = "Analysis of $($logFiles.Count) log file(s) totaling $logSizeKB KB"
        $reportContent = New-CoLoggerReport -AnalysisText $analysisResult -LogFileNames $logFileNames -Summary $reportSummary

        # Validate report was generated successfully
        if ([string]::IsNullOrWhiteSpace($reportContent)) {
            Write-Error "Failed to generate report"
            Write-Host "Suggestion: Check that Report-Generator module is working correctly" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        Write-Host "  → Report generated" -ForegroundColor Gray
        Write-Host ""

        #------------------------------------------------------------------------
        # Step 9: Save Report to File
        # Write report to reports folder with timestamped filename
        #------------------------------------------------------------------------
        Write-Host "Saving report..." -ForegroundColor Cyan
        $reportSaved = Save-ReportToFile -ReportContent $reportContent

        # Validate report was saved successfully
        if (-not $reportSaved) {
            Write-Error "Failed to save report"
            Write-Host "Suggestion: Check that reports folder exists and is writable" -ForegroundColor Yellow
            Write-Host "Verify disk space is available" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        #------------------------------------------------------------------------
        # Step 10: Display Success Message
        # Show user the analysis is complete with report details
        #------------------------------------------------------------------------
        Write-Host ""
        Write-Host "✓ Analysis complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Report Details:" -ForegroundColor Cyan
        Write-Host "  Files Analyzed: $($logFiles.Count)" -ForegroundColor White
        Write-Host "  Total Size: $logSizeKB KB" -ForegroundColor White
        Write-Host "  Report Location: .\reports\" -ForegroundColor White
        Write-Host ""
        Write-Host "Check the reports folder for your analysis results." -ForegroundColor Green
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        # Catch any unexpected errors during the analysis workflow
        Write-Error "An unexpected error occurred during log analysis: $_"
        Write-Host "Suggestion: Check the error message above for details" -ForegroundColor Yellow
        Write-Host "Review log files for potential issues (corrupted data, invalid encoding)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}

#endregion

#region Main Application Loop

<#
.SYNOPSIS
    Main application entry point and menu loop.
#>
function Start-CoLoggerApplication {
    [CmdletBinding()]
    param()

    try {
        # Perform startup validation
        Write-Host ""
        Write-Host "Starting CoLogger..." -ForegroundColor Cyan
        Write-Host ""

        # Validate package modules exist
        if (-not (Test-PackageModules)) {
            Write-Error "Package validation failed. Cannot continue."
            return
        }

        # Import package modules
        if (-not (Import-PackageModules)) {
            Write-Error "Module import failed. Cannot continue."
            return
        }

        # Initialize required folders
        if (-not (Initialize-RequiredFolders)) {
            Write-Error "Folder initialization failed. Cannot continue."
            return
        }

        # Initialize configuration
        if (-not (Initialize-ApplicationConfiguration)) {
            Write-Error "Configuration initialization failed. Cannot continue."
            return
        }

        Write-Host ""
        Write-Host "CoLogger initialized successfully!" -ForegroundColor Green
        Write-Host ""
        Start-Sleep -Seconds 2

        # Main menu loop
        $isRunning = $true

        while ($isRunning) {
            try {
                # Display menu and get user choice
                $userChoice = Show-MainMenu

                # Handle invalid input
                if ($userChoice -eq -1) {
                    Write-Host "Press any key to try again..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    continue
                }

                # Process user choice
                switch ($userChoice) {
                    1 {
                        # Test LLM Connection
                        Invoke-TestLLMConnection
                    }
                    2 {
                        # Analyze Logs & Generate Report
                        Invoke-AnalyzeLogsAndGenerateReport
                    }
                    3 {
                        # Exit
                        Write-Host ""
                        Write-Host "Thank you for using CoLogger!" -ForegroundColor Cyan
                        Write-Host "Exiting..." -ForegroundColor Cyan
                        $isRunning = $false
                    }
                    default {
                        Write-Warning "Invalid menu option selected."
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    }
                }
            }
            catch {
                Write-Error "An error occurred in the menu loop: $_"
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
        }
    }
    catch {
        Write-Error "Fatal error in CoLogger application: $_"
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}

#endregion

# Start the application
Start-CoLoggerApplication
