#region Private Helper Functions

# Returns path to logs folder
function Get-LogsFolderPath {
    [CmdletBinding()]
    param()

    try {
        $scriptRoot = Split-Path -Parent $PSScriptRoot
        $logsFolderPath = Join-Path -Path $scriptRoot -ChildPath "logs"
        return $logsFolderPath
    }
    catch {
        Write-Error "Failed to determine logs folder path: $_"
        throw
    }
}

#endregion

#region Public Functions

# Checks if logs folder exists
function Test-LogFolderExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $logsFolderPath = Get-LogsFolderPath

        if (Test-Path -Path $logsFolderPath -PathType Container) {
            return $true
        }

        Write-Warning "Logs folder not found at: $logsFolderPath"
        return $false
    }
    catch {
        Write-Error "Failed to test logs folder existence: $_"
        return $false
    }
}

# Returns array of .log file paths from logs folder
function Get-LogFiles {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    try {
        # Validate logs folder exists
        if (-not (Test-LogFolderExists)) {
            Write-Warning "Cannot get log files - logs folder does not exist."
            return @()
        }

        $logsFolderPath = Get-LogsFolderPath

        # Get all .log files
        try {
            $logFiles = Get-ChildItem -Path $logsFolderPath -Filter "*.log" -File -ErrorAction Stop

            if ($logFiles.Count -eq 0) {
                Write-Warning "No .log files found in: $logsFolderPath"
                return @()
            }

            Write-Verbose "Found $($logFiles.Count) log file(s) in logs folder."
            return $logFiles.FullName
        }
        catch {
            Write-Error "Failed to retrieve log files: $_"
            return @()
        }
    }
    catch {
        Write-Error "Failed to get log files: $_"
        return @()
    }
}

# Gets file metadata (name, size, modified time)
function Get-LogFileMetadata {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    try {
        # Validate file exists
        if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
            Write-Error "Log file not found: $FilePath"
            return $null
        }

        # Get file info
        try {
            $fileInfo = Get-Item -Path $FilePath -ErrorAction Stop

            $metadata = [PSCustomObject]@{
                Name = $fileInfo.Name
                SizeBytes = $fileInfo.Length
                SizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
                SizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                LastModified = $fileInfo.LastWriteTime
                FullPath = $fileInfo.FullName
            }

            return $metadata
        }
        catch {
            Write-Error "Failed to retrieve file metadata: $_"
            return $null
        }
    }
    catch {
        Write-Error "Failed to get log file metadata: $_"
        return $null
    }
}

# Reads complete content from a single log file
function Read-LogFileContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    try {
        # Validate file exists
        if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
            Write-Error "Log file not found: $FilePath"
            return $null
        }

        # Get file metadata and warn if large
        $metadata = Get-LogFileMetadata -FilePath $FilePath
        if ($metadata.SizeMB -gt 10) {
            Write-Warning "Large log file detected: $($metadata.Name) ($($metadata.SizeMB) MB)"
        }

        # Read file content with UTF-8 encoding
        try {
            $content = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "Successfully read log file: $($metadata.Name)"
            return $content
        }
        catch {
            Write-Error "Failed to read log file content: $_"
            return $null
        }
    }
    catch {
        Write-Error "Failed to read log file: $_"
        return $null
    }
}

# Combines all log files with separators
function Get-CombinedLogContent {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        # Get all log files
        $logFilePaths = Get-LogFiles

        if ($logFilePaths.Count -eq 0) {
            Write-Warning "No log files available to read."
            return $null
        }

        # Build combined content with separators
        $combinedContent = New-Object System.Text.StringBuilder

        foreach ($logFilePath in $logFilePaths) {
            $metadata = Get-LogFileMetadata -FilePath $logFilePath
            if ($null -eq $metadata) {
                Write-Warning "Failed to get metadata for: $logFilePath"
                continue
            }

            $fileContent = Read-LogFileContent -FilePath $logFilePath
            if ($null -eq $fileContent) {
                Write-Warning "Failed to read content for: $logFilePath"
                continue
            }

            # Add separator header
            [void]$combinedContent.AppendLine("=" * 80)
            [void]$combinedContent.AppendLine("FILE: $($metadata.Name)")
            [void]$combinedContent.AppendLine("SIZE: $($metadata.SizeKB) KB")
            [void]$combinedContent.AppendLine("MODIFIED: $($metadata.LastModified)")
            [void]$combinedContent.AppendLine("=" * 80)
            [void]$combinedContent.AppendLine("")

            # Add file content
            [void]$combinedContent.AppendLine($fileContent)
            [void]$combinedContent.AppendLine("")
        }

        Write-Host "Combined $($logFilePaths.Count) log file(s) successfully."
        return $combinedContent.ToString()
    }
    catch {
        Write-Error "Failed to get combined log content: $_"
        return $null
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Test-LogFolderExists',
    'Get-LogFiles',
    'Get-LogFileMetadata',
    'Read-LogFileContent',
    'Get-CombinedLogContent'
)
