<#
.SYNOPSIS
    Interactive menu display module for CoLogger application.

.DESCRIPTION
    Provides functions to display and handle the interactive menu system
    for the CoLogger log analysis tool. Handles user input and validation.

.NOTES
    Module: Menu-Display
    Author: CoLogger Development Team
    Version: 1.0.0
#>

#region Public Functions

<#
.SYNOPSIS
    Clears the console screen for a clean menu display.

.DESCRIPTION
    Clears the PowerShell console screen to provide a clean slate
    for displaying the menu interface.

.EXAMPLE
    Clear-MenuScreen
    Clears the console screen.
#>
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

<#
.SYNOPSIS
    Displays the application header banner.

.DESCRIPTION
    Shows a formatted header with the CoLogger application name
    and decorative borders.

.EXAMPLE
    Show-MenuHeader
    Displays the application header.
#>
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

<#
.SYNOPSIS
    Formats and displays a single menu option.

.DESCRIPTION
    Displays a menu option with consistent formatting including
    the option number and description.

.PARAMETER OptionNumber
    The numeric identifier for the menu option (1, 2, 3, etc.).

.PARAMETER OptionText
    The descriptive text for what this menu option does.

.EXAMPLE
    Show-MenuOption -OptionNumber 1 -OptionText "Test LLM Connection"
    Displays: 1. Test LLM Connection
#>
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

<#
.SYNOPSIS
    Prompts the user for menu input and validates it.

.DESCRIPTION
    Displays a prompt for the user to enter their menu choice,
    validates the input is within the valid range, and returns
    the selection as an integer.

.PARAMETER MinChoice
    The minimum valid choice number.

.PARAMETER MaxChoice
    The maximum valid choice number.

.EXAMPLE
    $choice = Get-UserMenuChoice -MinChoice 1 -MaxChoice 3
    Prompts for input and returns validated choice between 1-3.

.OUTPUTS
    System.Int32 - The validated user menu choice.
#>
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

<#
.SYNOPSIS
    Displays the main menu and returns the user's selection.

.DESCRIPTION
    Shows the complete CoLogger main menu with all available options,
    prompts for user input, and returns the validated selection.
    Returns -1 if input is invalid.

.EXAMPLE
    $selection = Show-MainMenu
    if ($selection -eq 1) { Test-LLMConnection }

.OUTPUTS
    System.Int32 - The user's menu selection (1-3), or -1 if invalid.
#>
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
