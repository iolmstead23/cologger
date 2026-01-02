<#
.SYNOPSIS
    LLM API client module for CoLogger application.

.DESCRIPTION
    Provides functions to communicate with a local LLM API using OpenAI-compatible
    format. Handles connection testing, request building, and log analysis.

.NOTES
    Module: LLM-API-Client
    Author: CoLogger Development Team
    Version: 1.0.0
#>

#region Public Functions

<#
.SYNOPSIS
    Builds an OpenAI-compatible request payload for LLM analysis.

.DESCRIPTION
    Creates a properly formatted JSON request body for OpenAI-compatible APIs.
    Includes system prompt and user message with log content.

.PARAMETER SystemPrompt
    The system prompt that defines the LLM's role and behavior.

.PARAMETER UserMessage
    The user message containing the log content to analyze.

.PARAMETER Model
    The model name to use for the request.

.PARAMETER Temperature
    The temperature parameter for response randomness (0.0-1.0).

.PARAMETER MaxTokens
    The maximum number of tokens in the response.

.EXAMPLE
    $payload = Build-LLMRequestPayload -SystemPrompt "You are a log analyst" -UserMessage "Analyze these logs..."

.OUTPUTS
    System.String - JSON string containing the request payload.
#>
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

<#
.SYNOPSIS
    Sends an HTTP POST request to the LLM API endpoint.

.DESCRIPTION
    Makes an HTTP POST request to the LLM API with the provided JSON payload.
    Handles timeouts and connection errors.

.PARAMETER ApiUrl
    The complete URL to the LLM API endpoint.

.PARAMETER JsonPayload
    The JSON request payload to send.

.PARAMETER TimeoutSeconds
    The timeout in seconds for the HTTP request.

.EXAMPLE
    $response = Send-LLMRequest -ApiUrl "http://localhost:1234/v1/chat/completions" -JsonPayload $payload

.OUTPUTS
    PSCustomObject - The parsed API response, or $null if failed.
#>
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

<#
.SYNOPSIS
    Tests the connection to the LLM API.

.DESCRIPTION
    Validates that the LLM API is reachable and responding.
    Sends a simple test request and checks for a valid response.

.PARAMETER ApiEndpoint
    The base API endpoint (e.g., "http://localhost").

.PARAMETER ApiPort
    The API port number.

.PARAMETER ApiPath
    The API path (e.g., "/v1/chat/completions").

.PARAMETER Model
    The LLM model name to test (e.g., "qwen2.5:latest", "llama2:latest"). Defaults to "qwen2.5:latest".

.PARAMETER TimeoutSeconds
    The timeout in seconds for the connection test.

.EXAMPLE
    $isConnected = Test-LLMConnection -ApiEndpoint "http://localhost" -ApiPort 1234 -ApiPath "/v1/chat/completions" -Model "qwen2.5:latest"

.OUTPUTS
    System.Boolean - $true if connection successful, $false otherwise.
#>
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

<#
.SYNOPSIS
    Sends log content to the LLM for analysis.

.DESCRIPTION
    Takes log content, constructs an appropriate prompt, sends it to the LLM API,
    and returns the analysis results.

.PARAMETER LogContent
    The combined log content to analyze.

.PARAMETER ApiEndpoint
    The base API endpoint (e.g., "http://localhost").

.PARAMETER ApiPort
    The API port number.

.PARAMETER ApiPath
    The API path (e.g., "/v1/chat/completions").

.PARAMETER SystemPrompt
    The system prompt defining the LLM's analysis role.

.PARAMETER Model
    The model name to use.

.PARAMETER Temperature
    The temperature parameter for response randomness.

.PARAMETER MaxTokens
    The maximum number of tokens in the response.

.PARAMETER TimeoutSeconds
    The timeout in seconds for the request.

.EXAMPLE
    $analysis = Invoke-LLMAnalysis -LogContent $logs -ApiEndpoint "http://localhost" -ApiPort 1234

.OUTPUTS
    System.String - The LLM's analysis text, or $null if failed.
#>
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
