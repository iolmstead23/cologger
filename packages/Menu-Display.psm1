#region Public Functions

# Clears console for clean display
function Clear-MenuScreen {
    [CmdletBinding()]
    param()

    try {
        Clear-Host
    }
    catch {
        Write-Error "Failed to clear screen: $_"
    }
}

# Displays application banner
function Show-MenuHeader {
    [CmdletBinding()]
    param()

    try {
        Write-Host ""
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host "    CoLogger - Log Analysis    " -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Error "Failed to display menu header: $_"
    }
}

# Displays a formatted menu option
function Show-MenuOption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [int]$OptionNumber,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OptionText
    )

    try {
        Write-Host "$OptionNumber. $OptionText" -ForegroundColor White
    }
    catch {
        Write-Error "Failed to display menu option: $_"
    }
}

# Prompts and validates user menu choice
function Get-UserMenuChoice {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [int]$MinChoice,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [int]$MaxChoice
    )

    try {
        Write-Host ""
        $userInput = Read-Host "Enter your choice ($MinChoice-$MaxChoice)"

        # Validate input is a number
        $choiceNumber = 0
        if (-not [int]::TryParse($userInput, [ref]$choiceNumber)) {
            Write-Warning "Invalid input. Please enter a number between $MinChoice and $MaxChoice."
            return -1
        }

        # Validate input is within range
        if ($choiceNumber -lt $MinChoice -or $choiceNumber -gt $MaxChoice) {
            Write-Warning "Invalid choice. Please select a number between $MinChoice and $MaxChoice."
            return -1
        }

        return $choiceNumber
    }
    catch {
        Write-Error "Failed to get user menu choice: $_"
        return -1
    }
}

# Displays main menu and returns user selection
function Show-MainMenu {
    [CmdletBinding()]
    [OutputType([int])]
    param()

    try {
        # Clear screen for clean display
        Clear-MenuScreen

        # Display header
        Show-MenuHeader

        # Display menu options
        Show-MenuOption -OptionNumber 1 -OptionText "Test LLM Connection"
        Show-MenuOption -OptionNumber 2 -OptionText "Analyze Logs & Generate Report"
        Show-MenuOption -OptionNumber 3 -OptionText "Exit"

        # Get and return user choice
        $userChoice = Get-UserMenuChoice -MinChoice 1 -MaxChoice 3
        return $userChoice
    }
    catch {
        Write-Error "Failed to display main menu: $_"
        return -1
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Clear-MenuScreen',
    'Show-MenuHeader',
    'Show-MenuOption',
    'Get-UserMenuChoice',
    'Show-MainMenu'
)
