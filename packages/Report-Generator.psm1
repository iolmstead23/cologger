<#
.SYNOPSIS
    Report generation module for CoLogger application.

.DESCRIPTION
    Provides functions to generate and save markdown reports from
    log analysis results. Handles report formatting and file management.

.NOTES
    Module: Report-Generator
    Author: CoLogger Development Team
    Version: 1.0.0
#>

#region Private Helper Functions

<#
.SYNOPSIS
    Gets the reports folder path relative to the script root.
#>
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

<#
.SYNOPSIS
    Tests if the reports folder exists.

.DESCRIPTION
    Validates that the reports folder exists in the expected location.
    Returns true if exists, false otherwise.

.EXAMPLE
    Test-ReportFolderExists
    Returns $true if reports folder exists.

.OUTPUTS
    System.Boolean
#>
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

<#
.SYNOPSIS
    Generates a timestamped filename for a report.

.DESCRIPTION
    Creates a filename with format: Report_YYYY-MM-DD_HHMMSS.md
    Uses the current date and time.

.EXAMPLE
    $filename = Get-ReportFileName
    Returns "Report_2026-01-01_143022.md"

.OUTPUTS
    System.String - The generated filename.
#>
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

<#
.SYNOPSIS
    Formats a report section with markdown headers.

.DESCRIPTION
    Creates a properly formatted markdown section with a header and content.
    Supports different header levels.

.PARAMETER HeaderText
    The text for the section header.

.PARAMETER Content
    The content for the section.

.PARAMETER HeaderLevel
    The markdown header level (1-6). Default is 2 (##).

.EXAMPLE
    $section = Format-ReportSection -HeaderText "Summary" -Content "All systems operational" -HeaderLevel 2

.OUTPUTS
    System.String - The formatted markdown section.
#>
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

<#
.SYNOPSIS
    Creates a markdown report from analysis data.

.DESCRIPTION
    Generates a complete markdown report including summary, errors,
    log sources, and detailed analysis. Follows a standard template.

.PARAMETER AnalysisText
    The LLM's analysis text.

.PARAMETER LogFileNames
    Array of log file names that were analyzed.

.PARAMETER Summary
    Optional summary text. If not provided, uses a default message.

.EXAMPLE
    $report = New-CoLoggerReport -AnalysisText $analysis -LogFileNames @("app.log", "system.log")

.OUTPUTS
    System.String - The complete markdown report content.
#>
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

<#
.SYNOPSIS
    Saves report content to a markdown file.

.DESCRIPTION
    Writes the provided report content to a timestamped markdown file
    in the reports folder. Creates the folder if it doesn't exist.

.PARAMETER ReportContent
    The markdown report content to save.

.PARAMETER CustomFileName
    Optional custom filename. If not provided, generates timestamped name.

.EXAMPLE
    $success = Save-ReportToFile -ReportContent $report
    Saves report with auto-generated filename.

.OUTPUTS
    System.Boolean - Returns $true if save succeeded, $false otherwise.
#>
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
