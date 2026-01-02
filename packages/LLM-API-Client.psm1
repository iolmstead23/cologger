#region Public Functions

# Builds OpenAI-compatible request payload for LLM
function Build-LLMRequestPayload {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SystemPrompt,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserMessage,

        [Parameter(Mandatory = $false)]
        [string]$Model = "default",

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.0, 1.0)]
        [double]$Temperature = 0.3,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100000)]
        [int]$MaxTokens = 4096
    )

    try {
        # Build request object
        $requestObject = @{
            model = $Model
            messages = @(
                @{
                    role = "system"
                    content = $SystemPrompt
                },
                @{
                    role = "user"
                    content = $UserMessage
                }
            )
            temperature = $Temperature
            max_tokens = $MaxTokens
        }

        # Convert to JSON
        try {
            $jsonPayload = $requestObject | ConvertTo-Json -Depth 10 -ErrorAction Stop
            return $jsonPayload
        }
        catch {
            Write-Error "Failed to convert request object to JSON: $_"
            return $null
        }
    }
    catch {
        Write-Error "Failed to build LLM request payload: $_"
        return $null
    }
}

# Sends HTTP POST request to LLM API endpoint
function Send-LLMRequest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$JsonPayload,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-Verbose "Sending request to LLM API: $ApiUrl"

        # Send HTTP POST request
        try {
            $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $JsonPayload -ContentType "application/json" -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            Write-Verbose "Successfully received response from LLM API"
            return $response
        }
        catch {
            Write-Error "Failed to send request to LLM API: $_"
            return $null
        }
    }
    catch {
        Write-Error "Failed to execute LLM request: $_"
        return $null
    }
}

# Tests LLM API connectivity with simple request
function Test-LLMConnection {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$ApiPort,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Model = "qwen2.5:latest",

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]$TimeoutSeconds = 10
    )

    try {
        # Build API URL
        $apiUrl = "$($ApiEndpoint):$($ApiPort)$($ApiPath)"
        Write-Host "Testing LLM connection to: $apiUrl"

        # Build simple test payload
        $testPayload = Build-LLMRequestPayload -SystemPrompt "You are a helpful assistant." -UserMessage "Respond with OK if you can read this." -Model $Model -Temperature 0.1 -MaxTokens 10

        if ($null -eq $testPayload) {
            Write-Error "Failed to build test payload"
            return $false
        }

        # Send test request
        $response = Send-LLMRequest -ApiUrl $apiUrl -JsonPayload $testPayload -TimeoutSeconds $TimeoutSeconds

        if ($null -eq $response) {
            Write-Warning "LLM API did not respond or returned an error"
            return $false
        }

        Write-Host "LLM connection successful!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to test LLM connection: $_"
        return $false
    }
}

# Sends log content to LLM and returns analysis
function Invoke-LLMAnalysis {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogContent,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$ApiPort,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SystemPrompt,

        [Parameter(Mandatory = $false)]
        [string]$Model = "default",

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.0, 1.0)]
        [double]$Temperature = 0.3,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100000)]
        [int]$MaxTokens = 4096,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 30
    )

    try {
        # Build API URL
        $apiUrl = "$($ApiEndpoint):$($ApiPort)$($ApiPath)"
        Write-Host "Sending logs to LLM for analysis..."

        # Build user message with log content
        $userMessage = "Please analyze the following logs and identify any errors, warnings, or issues. Provide clear, actionable insights:`n`n$LogContent"

        # Build request payload
        $payload = Build-LLMRequestPayload -SystemPrompt $SystemPrompt -UserMessage $userMessage -Model $Model -Temperature $Temperature -MaxTokens $MaxTokens

        if ($null -eq $payload) {
            Write-Error "Failed to build analysis request payload"
            return $null
        }

        # Send analysis request
        $response = Send-LLMRequest -ApiUrl $apiUrl -JsonPayload $payload -TimeoutSeconds $TimeoutSeconds

        if ($null -eq $response) {
            Write-Error "Failed to get analysis response from LLM"
            return $null
        }

        # Extract analysis text from response
        try {
            $analysisText = $response.choices[0].message.content
            Write-Host "Analysis received successfully from LLM" -ForegroundColor Green
            return $analysisText
        }
        catch {
            Write-Error "Failed to extract analysis text from response: $_"
            return $null
        }
    }
    catch {
        Write-Error "Failed to invoke LLM analysis: $_"
        return $null
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Build-LLMRequestPayload',
    'Send-LLMRequest',
    'Test-LLMConnection',
    'Invoke-LLMAnalysis'
)
