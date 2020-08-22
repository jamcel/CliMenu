<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE

        Update-ConsoleLine "Beginning process..." -ForegroundColor "White" -StayOnSameLine -ClearLine
        Sleep(1)
        Update-ConsoleLine "Progress: [..........]" -ForegroundColor "DarkGray" -StayOnSameLine -ClearLine
        Sleep(2)
        Update-ConsoleLine "Progress: [ooo.......]" -ForegroundColor "DarkGray" -StayOnSameLine -ClearLine
        Sleep(2)
        Update-ConsoleLine "Progress: [ooooooo...]" -ForegroundColor "Cyan" -StayOnSameLine -ClearLine
        Sleep(2)
        Update-ConsoleLine "Progress: [oooooooooo]" -ForegroundColor "Green" -StayOnSameLine -ClearLine
        Sleep(1)
        Update-ConsoleLine "Process Completed." -ForegroundColor "DarkGreen"
        Update-ConsoleLine "Begining Next process..." -ForegroundColor "DarkGreen"

#>



#
# Function to implement Same line printing
#
function Update-ConsoleLine (
    # Message to be printed
    [Parameter(Position = 0)]
    [string] $Message,

    # Cursor position where message is to be printed
    [int] $x = -1,
    [int] $y = -1,
    [switch] $xIsRelative,
    [switch] $yIsRelative,

    # Foreground and Background colors for the message
    [System.ConsoleColor] $ForegroundColor = [System.Console]::ForegroundColor,
    [System.ConsoleColor] $BackgroundColor = [System.Console]::BackgroundColor,

    # Clear whatever is typed on this line currently
    [switch] $ClearLine,

    # After printing the message, return the cursor back to its initial position.
    [switch] $noResetCursorToOrigin
)
{
    # Save the current positions. If StayOnSameLine switch is supplied, we should go back to these.
    $CurrCursorLeft = [System.Console]::get_CursorLeft()
    $CurrCursorTop = [System.Console]::get_CursorTop()
    $CurrForegroundColor = [System.Console]::ForegroundColor
    $CurrBackgroundColor = [System.Console]::BackgroundColor


    # Get the passed values of foreground and backgroun colors, and left and top cursor positions
    $NewForegroundColor = $ForegroundColor
    $NewBackgroundColor = $BackgroundColor

    $offsetLeft = 0
    $offsetTop = 0

    if($xIsRelative){
        $offsetLeft = $CurrCursorLeft
    }

    if($yIsRelative){
        $offsetTop = $CurrCursorTop
    }

    $NewCursorLeft = $offsetLeft + $x
    if ($NewCursorLeft -lt 0) {
        $NewCursorLeft = $CurrCursorLeft
    }

    $NewCursorTop = $offsetTop + $y
    if ($NewCursorTop -lt 0) {
        $NewCursorTop = $CurrCursorTop
    }

    # if clearline switch is present, clear the current line on the console by writing " "
    if ( $ClearLine ) {
        $clearmsg = " " * ([System.Console]::WindowWidth - 1)
        [System.Console]::SetCursorPosition(0, $NewCursorTop)
        [System.Console]::Write($clearmsg)
    }

    # Update the console with the message.
    [System.Console]::ForegroundColor = $NewForegroundColor
    [System.Console]::BackgroundColor = $NewBackgroundColor
    [System.Console]::SetCursorPosition($NewCursorLeft, $NewCursorTop)

    # Crop message
    if($Message.length -gt ([System.Console]::WindowWidth -1) ){
        $Message = $Message -replace "^(.{0,$([System.Console]::WindowWidth-5)}).*","`$1..."
    }
    [System.Console]::Write($Message)
    if (! $noResetCursorToOrigin ) {
        [System.Console]::SetCursorPosition($CurrCursorLeft, $CurrCursorTop)
    }

    # Set foreground and backgroun colors back to original values.
    [System.Console]::ForegroundColor = $CurrForegroundColor
    [System.Console]::BackgroundColor = $CurrBackgroundColor

}

Export-ModuleMember -Function *

