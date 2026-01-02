#Requires -Version 5.1

[CmdletBinding()]
param()

#region Initialization

# Validates required package modules exist
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
            'Report-Generator.psm1',
            'Prompt-Manager.psm1'
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

# Imports all package modules into session
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
            'Report-Generator',
            'Prompt-Manager'
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

# Creates logs and reports folders if missing
function Initialize-RequiredFolders {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Host "Validating required folders..." -ForegroundColor Cyan

        $requiredFolders = @('logs', 'reports', 'prompts')

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

# Loads or creates config.json
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

# Menu handler: Test LLM API connectivity
function Invoke-TestLLMConnection {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n" -NoNewline
        Write-Host "=== Test LLM Connection ===" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "Loading configuration..." -ForegroundColor Cyan
        $configuration = Get-CoLoggerConfiguration

        if ($null -eq $configuration) {
            Write-Error "Failed to load configuration file"
            Write-Host "Suggestion: Ensure config.json exists and is valid JSON" -ForegroundColor Yellow
            Write-Host "The configuration should have been created during startup." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        Write-Host "Validating configuration settings..." -ForegroundColor Cyan

        if ([string]::IsNullOrWhiteSpace($configuration.apiEndpoint)) {
            Write-Error "Configuration missing 'apiEndpoint' field"
            Write-Host "Suggestion: Edit config.json and add 'apiEndpoint' field" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        if ($null -eq $configuration.apiPort -or $configuration.apiPort -lt 1 -or $configuration.apiPort -gt 65535) {
            Write-Error "Configuration has invalid 'apiPort' value"
            Write-Host "Suggestion: Edit config.json and set 'apiPort' to a valid port (1-65535)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        if ([string]::IsNullOrWhiteSpace($configuration.apiPath)) {
            Write-Error "Configuration missing 'apiPath' field"
            Write-Host "Suggestion: Edit config.json and add 'apiPath' field (e.g., '/v1/chat/completions')" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        $fullApiUrl = "$($configuration.apiEndpoint):$($configuration.apiPort)$($configuration.apiPath)"
        Write-Host "  API Endpoint: $fullApiUrl" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Testing connection to LLM API..." -ForegroundColor Cyan

        if ($configuration.timeoutSeconds) {
            $timeoutSeconds = $configuration.timeoutSeconds
        } else {
            $timeoutSeconds = 10
        }

        $connectionSuccessful = Test-LLMConnection -ApiEndpoint $configuration.apiEndpoint -ApiPort $configuration.apiPort -ApiPath $configuration.apiPath -Model $configuration.model -TimeoutSeconds $timeoutSeconds

        Write-Host ""
        if ($connectionSuccessful) {
            Write-Host "✓ LLM API connection successful!" -ForegroundColor Green
            Write-Host "  The LLM service is reachable and responding." -ForegroundColor Green
        }
        else {
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
        Write-Error "An unexpected error occurred while testing LLM connection: $_"
        Write-Host "Suggestion: Check the error message above for details" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}

# Menu handler: Full log analysis workflow
function Invoke-AnalyzeLogsAndGenerateReport {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`n" -NoNewline
        Write-Host "=== Analyze Logs and Generate Report ===" -ForegroundColor Cyan
        Write-Host ""

        # Pre-flight validation
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

        Write-Host "Scanning for log files..." -ForegroundColor Cyan
        $logFiles = Get-LogFiles

        if ($null -eq $logFiles -or $logFiles.Count -eq 0) {
            Write-Warning "No .log files found in logs folder"
            Write-Host "Suggestion: Place .log files in the logs folder before running analysis" -ForegroundColor Yellow
            Write-Host "Supported format: *.log files" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        Write-Host "  → Found $($logFiles.Count) log file(s) to analyze" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Reading log file contents..." -ForegroundColor Cyan
        $combinedLogContent = Get-CombinedLogContent

        if ([string]::IsNullOrWhiteSpace($combinedLogContent)) {
            Write-Error "Failed to read log file contents"
            Write-Host "Suggestion: Check that log files are not locked or corrupted" -ForegroundColor Yellow
            Write-Host "Verify file permissions allow read access" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

        $logSizeKB = [math]::Round($combinedLogContent.Length / 1KB, 2)
        Write-Host "  → Combined log size: $logSizeKB KB" -ForegroundColor Gray

        if ($logSizeKB -gt 100) {
            Write-Warning "Large log files detected. Analysis may take longer than usual."
        }
        Write-Host ""

        # LLM communication
        Write-Host "Loading LLM configuration..." -ForegroundColor Cyan
        $configuration = Get-CoLoggerConfiguration

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

        # Prompt template selection
        Write-Host "Selecting analysis prompt..." -ForegroundColor Cyan
        $promptSelection = Show-PromptSelectionMenu

        if ($null -eq $promptSelection) {
            Write-Error "Failed to select prompt template"
            Write-Host "Using default prompt as fallback..." -ForegroundColor Yellow
            $finalSystemPrompt = Get-DefaultSystemPrompt
        }
        else {
            # Build final prompt from selection
            $basePrompt = if ($promptSelection.PromptSource -eq "template") {
                $promptSelection.TemplateContent
            } else {
                Get-DefaultSystemPrompt
            }

            $finalSystemPrompt = Build-FinalSystemPrompt -TemplateContent $basePrompt -CustomText $promptSelection.CustomText
        }
        Write-Host "  → Prompt configured" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Testing LLM connectivity..." -ForegroundColor Cyan
        if ($configuration.timeoutSeconds) {
            $timeoutSeconds = $configuration.timeoutSeconds
        } else {
            $timeoutSeconds = 10
        }
        $llmConnectionSuccessful = Test-LLMConnection -ApiEndpoint $configuration.apiEndpoint -ApiPort $configuration.apiPort -ApiPath $configuration.apiPath -Model $configuration.model -TimeoutSeconds $timeoutSeconds

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

        Write-Host "Sending logs to LLM for analysis..." -ForegroundColor Cyan
        Write-Host "  (This may take a while depending on log size and model speed)" -ForegroundColor Gray
        Write-Host ""

        $analysisResult = Invoke-LLMAnalysis -LogContent $combinedLogContent -ApiEndpoint $configuration.apiEndpoint -ApiPort $configuration.apiPort -ApiPath $configuration.apiPath -SystemPrompt $finalSystemPrompt -Model $configuration.model -Temperature $configuration.temperature -MaxTokens $configuration.maxTokens -TimeoutSeconds $configuration.timeoutSeconds

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

        # Report generation
        Write-Host "Generating report..." -ForegroundColor Cyan
        $logFileNames = $logFiles | ForEach-Object { Split-Path -Path $_ -Leaf }

        $reportSummary = "Analysis of $($logFiles.Count) log file(s) totaling $logSizeKB KB"
        $reportContent = New-CoLoggerReport -AnalysisText $analysisResult -LogFileNames $logFileNames -Summary $reportSummary

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

        Write-Host "Saving report..." -ForegroundColor Cyan
        $reportSaved = Save-ReportToFile -ReportContent $reportContent

        if (-not $reportSaved) {
            Write-Error "Failed to save report"
            Write-Host "Suggestion: Check that reports folder exists and is writable" -ForegroundColor Yellow
            Write-Host "Verify disk space is available" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }

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

# Main application entry point
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
