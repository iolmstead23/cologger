#region Private Helper Functions

# Returns path to config.json
function Get-ConfigurationFilePath {
    [CmdletBinding()]
    param()

    try {
        $scriptRoot = Split-Path -Parent $PSScriptRoot
        $configFilePath = Join-Path -Path $scriptRoot -ChildPath "config.json"
        return $configFilePath
    }
    catch {
        Write-Error "Failed to determine configuration file path: $_"
        throw
    }
}

#endregion

#region Public Functions

# Validates config.json exists and contains valid JSON
function Test-CoLoggerConfigurationFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $configFilePath = Get-ConfigurationFilePath

        # Check if file exists
        if (-not (Test-Path -Path $configFilePath -PathType Leaf)) {
            Write-Warning "Configuration file not found at: $configFilePath"
            return $false
        }

        # Attempt to parse JSON to validate format
        try {
            $configContent = Get-Content -Path $configFilePath -Raw -ErrorAction Stop
            $null = $configContent | ConvertFrom-Json -ErrorAction Stop
            return $true
        }
        catch {
            Write-Error "Configuration file contains invalid JSON: $_"
            return $false
        }
    }
    catch {
        Write-Error "Failed to test configuration file: $_"
        return $false
    }
}

# Creates default config.json if missing
function Initialize-CoLoggerConfiguration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $configFilePath = Get-ConfigurationFilePath

        # Check if configuration already exists
        if (Test-Path -Path $configFilePath -PathType Leaf) {
            Write-Host "Configuration file already exists at: $configFilePath"
            return $true
        }

        # Create default configuration object
        $defaultConfiguration = @{
            apiEndpoint = "http://localhost"
            apiPort = 1234
            apiPath = "/v1/chat/completions"
            model = "default"
            temperature = 0.3
            maxTokens = 4096
            timeoutSeconds = 30
            systemPrompt = "You are an expert log analysis assistant for IT Service Desk. Analyze the provided logs and identify errors, warnings, and issues. Provide clear, actionable insights."
        }

        # Write default configuration to file
        try {
            $defaultConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -ErrorAction Stop
            Write-Host "Default configuration file created successfully at: $configFilePath"
            return $true
        }
        catch {
            Write-Error "Failed to write default configuration file: $_"
            return $false
        }
    }
    catch {
        Write-Error "Failed to initialize configuration: $_"
        return $false
    }
}

# Loads configuration from config.json
function Get-CoLoggerConfiguration {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    try {
        # Validate configuration file exists and is valid
        if (-not (Test-CoLoggerConfigurationFile)) {
            Write-Error "Configuration file is missing or invalid. Run Initialize-CoLoggerConfiguration first."
            return $null
        }

        $configFilePath = Get-ConfigurationFilePath

        # Read and parse configuration file
        try {
            $configContent = Get-Content -Path $configFilePath -Raw -ErrorAction Stop
            $configurationObject = $configContent | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose "Configuration loaded successfully from: $configFilePath"
            return $configurationObject
        }
        catch {
            Write-Error "Failed to read or parse configuration file: $_"
            return $null
        }
    }
    catch {
        Write-Error "Failed to get configuration: $_"
        return $null
    }
}

# Saves configuration object to config.json
function Set-CoLoggerConfiguration {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$ConfigurationObject
    )

    try {
        $configFilePath = Get-ConfigurationFilePath

        # Validate required fields exist
        $requiredFields = @('apiEndpoint', 'apiPort', 'apiPath', 'model', 'systemPrompt')
        foreach ($fieldName in $requiredFields) {
            if (-not ($ConfigurationObject.PSObject.Properties.Name -contains $fieldName)) {
                Write-Error "Configuration object is missing required field: $fieldName"
                return $false
            }
        }

        # Write configuration to file
        try {
            $ConfigurationObject | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -ErrorAction Stop
            Write-Host "Configuration saved successfully to: $configFilePath"
            return $true
        }
        catch {
            Write-Error "Failed to write configuration file: $_"
            return $false
        }
    }
    catch {
        Write-Error "Failed to set configuration: $_"
        return $false
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Test-CoLoggerConfigurationFile',
    'Initialize-CoLoggerConfiguration',
    'Get-CoLoggerConfiguration',
    'Set-CoLoggerConfiguration'
)
