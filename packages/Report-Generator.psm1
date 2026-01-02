#region Private Helper Functions

# Returns path to reports folder
function Get-ReportsFolderPath {
    [CmdletBinding()]
    param()

    try {
        $scriptRoot = Split-Path -Parent $PSScriptRoot
        $reportsFolderPath = Join-Path -Path $scriptRoot -ChildPath "reports"
        return $reportsFolderPath
    }
    catch {
        Write-Error "Failed to determine reports folder path: $_"
        throw
    }
}

#endregion

#region Public Functions

# Checks if reports folder exists
function Test-ReportFolderExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $reportsFolderPath = Get-ReportsFolderPath

        if (Test-Path -Path $reportsFolderPath -PathType Container) {
            return $true
        }

        Write-Warning "Reports folder not found at: $reportsFolderPath"
        return $false
    }
    catch {
        Write-Error "Failed to test reports folder existence: $_"
        return $false
    }
}

# Generates timestamped filename for report
function Get-ReportFileName {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $filename = "Report_$timestamp.md"
        return $filename
    }
    catch {
        Write-Error "Failed to generate report filename: $_"
        return $null
    }
}

# Formats markdown section with header and content
function Format-ReportSection {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HeaderText,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 6)]
        [int]$HeaderLevel = 2
    )

    try {
        $headerPrefix = "#" * $HeaderLevel
        $formattedSection = "$headerPrefix $HeaderText`n`n$Content`n"
        return $formattedSection
    }
    catch {
        Write-Error "Failed to format report section: $_"
        return $null
    }
}

# Creates complete markdown report from analysis
function New-CoLoggerReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AnalysisText,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string[]]$LogFileNames,

        [Parameter(Mandatory = $false)]
        [string]$Summary = "Log analysis completed successfully."
    )

    try {
        # Build report using StringBuilder for efficiency
        $reportBuilder = New-Object System.Text.StringBuilder

        # Add title and timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        [void]$reportBuilder.AppendLine("# Log Analysis Report")
        [void]$reportBuilder.AppendLine("**Generated:** $timestamp")
        [void]$reportBuilder.AppendLine("")

        # Add summary section
        $summarySection = Format-ReportSection -HeaderText "Summary" -Content $Summary -HeaderLevel 2
        [void]$reportBuilder.Append($summarySection)
        [void]$reportBuilder.AppendLine("")

        # Add log sources section
        $logSourcesList = ($LogFileNames | ForEach-Object { "- $_" }) -join "`n"
        $logSourcesSection = Format-ReportSection -HeaderText "Log Sources Analyzed" -Content $logSourcesList -HeaderLevel 2
        [void]$reportBuilder.Append($logSourcesSection)
        [void]$reportBuilder.AppendLine("")

        # Add detailed analysis section
        $analysisSection = Format-ReportSection -HeaderText "Detailed Analysis" -Content $AnalysisText -HeaderLevel 2
        [void]$reportBuilder.Append($analysisSection)

        Write-Verbose "Report generated successfully"
        return $reportBuilder.ToString()
    }
    catch {
        Write-Error "Failed to create report: $_"
        return $null
    }
}

# Saves report content to timestamped markdown file
function Save-ReportToFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ReportContent,

        [Parameter(Mandatory = $false)]
        [string]$CustomFileName
    )

    try {
        # Ensure reports folder exists
        if (-not (Test-ReportFolderExists)) {
            Write-Warning "Reports folder does not exist. Creating it now..."
            $reportsFolderPath = Get-ReportsFolderPath
            New-Item -Path $reportsFolderPath -ItemType Directory -Force | Out-Null
        }

        # Get filename
        $fileName = if ($CustomFileName) { $CustomFileName } else { Get-ReportFileName }

        if ($null -eq $fileName) {
            Write-Error "Failed to determine report filename"
            return $false
        }

        # Build full path
        $reportsFolderPath = Get-ReportsFolderPath
        $fullPath = Join-Path -Path $reportsFolderPath -ChildPath $fileName

        # Write report to file
        try {
            Set-Content -Path $fullPath -Value $ReportContent -Encoding UTF8 -ErrorAction Stop
            Write-Host "Report saved successfully: $fullPath" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Error "Failed to write report file: $_"
            return $false
        }
    }
    catch {
        Write-Error "Failed to save report to file: $_"
        return $false
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Test-ReportFolderExists',
    'Get-ReportFileName',
    'Format-ReportSection',
    'New-CoLoggerReport',
    'Save-ReportToFile'
)
