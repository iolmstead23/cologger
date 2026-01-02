#region Private Helper Functions

# Returns path to prompts folder
function Get-PromptsFolderPath {
    [CmdletBinding()]
    param()

    try {
        $scriptRoot = Split-Path -Parent $PSScriptRoot
        $promptsFolderPath = Join-Path -Path $scriptRoot -ChildPath "prompts"
        return $promptsFolderPath
    }
    catch {
        Write-Error "Failed to determine prompts folder path: $_"
        throw
    }
}

#endregion

#region Public Functions

# Checks if prompts folder exists
function Test-PromptsFolderExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $promptsFolderPath = Get-PromptsFolderPath

        if (Test-Path -Path $promptsFolderPath -PathType Container) {
            return $true
        }

        Write-Warning "Prompts folder not found at: $promptsFolderPath"
        return $false
    }
    catch {
        Write-Error "Failed to test prompts folder existence: $_"
        return $false
    }
}

# Returns array of template objects from prompts folder
function Get-PromptTemplates {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    try {
        # Check if prompts folder exists
        if (-not (Test-PromptsFolderExists)) {
            Write-Verbose "Prompts folder does not exist. Returning empty array."
            return @()
        }

        $promptsFolderPath = Get-PromptsFolderPath

        # Get all .txt files except README.txt
        try {
            $templateFiles = Get-ChildItem -Path $promptsFolderPath -Filter "*.txt" -File -ErrorAction Stop | Where-Object { $_.Name -ne "README.txt" }

            if ($templateFiles.Count -eq 0) {
                Write-Verbose "No template files found in prompts folder."
                return @()
            }

            # Build template objects with display names
            $templates = @()
            foreach ($file in $templateFiles) {
                # Convert filename to display name
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $withSpaces = $baseName -replace '[-_]', ' '
                $words = $withSpaces -split '\s+'
                $titleCasedWords = $words | ForEach-Object {
                    if ($_.Length -gt 0) {
                        $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
                    }
                }
                $displayName = ($titleCasedWords -join ' ')

                $templates += [PSCustomObject]@{
                    DisplayName = $displayName
                    FileName = $file.Name
                    FilePath = $file.FullName
                }
            }

            Write-Verbose "Found $($templates.Count) template file(s) in prompts folder."
            return $templates
        }
        catch {
            Write-Error "Failed to retrieve template files: $_"
            return @()
        }
    }
    catch {
        Write-Error "Failed to get prompt templates: $_"
        return @()
    }
}

# Reads template file content
function Read-PromptTemplateContent {
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
            Write-Error "Template file not found: $FilePath"
            return $null
        }

        # Read file content with UTF-8 encoding
        try {
            $content = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
            $trimmedContent = $content.Trim()
            Write-Verbose "Successfully read template file: $FilePath"
            return $trimmedContent
        }
        catch {
            Write-Error "Failed to read template file content: $_"
            return $null
        }
    }
    catch {
        Write-Error "Failed to read template file: $_"
        return $null
    }
}

# Interactive template selection menu
function Show-PromptSelectionMenu {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    try {
        Clear-Host

        Write-Host ""
        Write-Host "===================================" -ForegroundColor Cyan
        Write-Host "   Select Analysis Prompt Template" -ForegroundColor Cyan
        Write-Host "===================================" -ForegroundColor Cyan
        Write-Host ""

        # Get available templates
        $templates = Get-PromptTemplates

        # Build menu options
        $optionNumber = 1
        $menuOptions = @{}

        # Add templates
        foreach ($template in $templates) {
            Write-Host "$optionNumber. $($template.DisplayName)" -ForegroundColor White
            $menuOptions[$optionNumber] = $template
            $optionNumber++
        }

        # Always add default option last
        Write-Host "$optionNumber. Default (Standard IT Service Desk analysis)" -ForegroundColor White
        $menuOptions[$optionNumber] = @{ DisplayName = "Default"; PromptSource = "default" }
        $maxChoice = $optionNumber

        Write-Host ""

        # Get user selection
        $userInput = Read-Host "Enter your choice (1-$maxChoice)"

        # Validate input
        $choice = 0
        if (-not [int]::TryParse($userInput, [ref]$choice)) {
            Write-Warning "Invalid input. Using default prompt."
            return @{ PromptSource = "default"; TemplateContent = ""; CustomText = "" }
        }

        if ($choice -lt 1 -or $choice -gt $maxChoice) {
            Write-Warning "Invalid choice. Using default prompt."
            return @{ PromptSource = "default"; TemplateContent = ""; CustomText = "" }
        }

        # Get selected option
        $selectedOption = $menuOptions[$choice]
        Write-Host ""
        Write-Host "Selected: $($selectedOption.DisplayName)" -ForegroundColor Green
        Write-Host ""

        # Read template content if not default
        $templateContent = ""
        if ($selectedOption.PromptSource -ne "default") {
            $templateContent = Read-PromptTemplateContent -FilePath $selectedOption.FilePath
            if ([string]::IsNullOrWhiteSpace($templateContent)) {
                Write-Error "Failed to read template file. Using default prompt."
                return @{ PromptSource = "default"; TemplateContent = ""; CustomText = "" }
            }
        }

        # Ask about custom text
        Write-Host "Would you like to add custom instructions? (Y/N)" -NoNewline
        $addCustom = Read-Host " "

        $customText = ""
        if ($addCustom -eq "Y" -or $addCustom -eq "y") {
            Write-Host ""
            Write-Host "Enter custom text to append:" -ForegroundColor Cyan
            $customText = Read-Host
        }

        # Return selection object
        return @{
            PromptSource = if ($selectedOption.PromptSource -eq "default") { "default" } else { "template" }
            TemplateContent = $templateContent
            CustomText = $customText
        }
    }
    catch {
        Write-Error "Failed to show prompt selection menu: $_"
        return @{ PromptSource = "default"; TemplateContent = ""; CustomText = "" }
    }
}

# Combines template and custom text into final system prompt
function Build-FinalSystemPrompt {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplateContent,

        [Parameter(Mandatory = $false)]
        [string]$CustomText = ""
    )

    try {
        # If no custom text, return template as-is
        if ([string]::IsNullOrWhiteSpace($CustomText)) {
            return $TemplateContent
        }

        # Combine template and custom text with clear separator
        $finalPrompt = "$TemplateContent`n`n--- Additional Instructions ---`n$CustomText"
        Write-Verbose "Combined template with custom text successfully"
        return $finalPrompt
    }
    catch {
        Write-Error "Failed to build final system prompt: $_"
        return $TemplateContent
    }
}

# Returns hardcoded default system prompt
function Get-DefaultSystemPrompt {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $defaultPrompt = "You are an expert log analysis assistant for IT Service Desk. Analyze the provided logs and identify errors, warnings, and issues. Provide clear, actionable insights."
        return $defaultPrompt
    }
    catch {
        Write-Error "Failed to get default system prompt: $_"
        throw
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Test-PromptsFolderExists',
    'Get-PromptTemplates',
    'Read-PromptTemplateContent',
    'Show-PromptSelectionMenu',
    'Build-FinalSystemPrompt',
    'Get-DefaultSystemPrompt'
)
