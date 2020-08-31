<#
.SYNOPSIS
    .
.DESCRIPTION
    This is a module for supplying a simple CLI menu.

    Since this module defines a class type you need to specify:

             using module .\ps_modules\agilent.fw.cliMenu.psm1

    in your script.

        For detailed help about parameters use:
         get-help <this_script_name>.ps1 -Parameter <parameter name>
      or get-help <this_script_name>.ps1 -Parameter *
      or get-help <this_script_name>.ps1 -detailed

.NOTES
    Date: 01/2020
    Author: gottscha

    CAUTION when modifying ps modules:
    The commands imported from ps modules might be cached (especially when using PowerShell ISE).

    To refresh the cache and reload your module changes in the command line modify the command for calling
    exported functions of this module to:

    import-module <this_module_name>.psm1 -force; your-command-to-run
#>

#**************************************#
#     script config values
#**************************************#

#**************************************#
#     imports (external libraries)
#**************************************#

#import-module "$PSScriptRoot\..\utils\utils.psm1"
import-module "$PSScriptRoot\console.psm1" -force

#**************************************#
#     classes/types
#**************************************#

# *** Problemes with this class definition?
#
# [03/2020 rigo: changed from class usage to function due to these issues]
#
# Defining this class may have been a mistake.
# Importing classes in Powershell is a pain in the a**.
# Potential problem:
#     After making changes to this module your calling script (that worked perfectly before)
#     gives you the error message:
#
#     Cannot convert the "MenuItem" value of type "MenuItem" to type "MenuItem".
#
#     The simple solution (but hard to find out) is to make a pseudo change to the calling script and save it.

# *********************************************
#      internal functions
# *********************************************
function New-MenuItem {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Description,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Action,

        $Args = $null,
        [string] $Key = ""
    )

    [PSCustomObject]@{
        Description = $Description
        Action      = $Action
        Args        = $Args
        Key         = $Key
    }
}

# *********************************************
# using a wrapper for [console]::Readkey so it can be mocked with Pester
function ReadKeyWrapper(){
    return [console]::ReadKey()
}

# *********************************************
function IfShowProposalsUpdateConsoleLine{
    param(
        [switch] $showProposals,
        $Message,
        $x,
        [switch] $xIsRelative,
        $y,
        [switch] $yIsRelative,
        [switch] $clearLine,
        [ConsoleColor] $foregroundColor = [Console]::ForegroundColor,
        [ConsoleColor] $backgroundColor = [Console]::BackgroundColor,
        [switch] $noResetCursorToOrigin
    )
    if($showProposals){
        Update-ConsoleLine -x $x -y $y -xIsRelative:$xIsRelative -yIsRelative:$yIsRelative `
                            -ClearLine:$clearLine  -Message $Message `
                            -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor `
                            -noResetCursorToOrigin:$noResetCursorToOrigin
    }
}

function Convert-CharToConsoleKey([string]$char){
    # note: to list all enumvalues of an enum type you can use the property .declaredFields or .declaredMembers
    #     e.g.   [System.ConsoleModifiers].declaredFields
    $retKey =  [PSCustomObject]@{
      Key = [consoleKey]::Enter
      KeyChar = ''
      Modifiers = ''
    }

    if($char -eq "`b"){
        $retKey.Key = [system.consolekey]::Backspace
        $retKey.KeyChar = $char
    }elseif($char -eq "`n"){
        $retKey.Key = [system.consolekey]::Enter
        $retKey.KeyChar = [char]13
    }elseif($char -eq "`t"){
        $retKey.Key = [system.consolekey]::Tab
        $retKey.KeyChar = $char
    }elseif($char -eq ","){
        $retKey.Key = [system.consolekey]::OemComma
        $retKey.KeyChar = $char
    }
    else{
        $retKey.Key = [system.consolekey].declaredFields.Name | Where-Object {$_ -eq $char}
        $isUpper = -not($char -ceq $char.toLower())
        if($isUpper){
            $retKey.Modifiers = [System.ConsoleModifiers]::Shift
        }
        $retKey.KeyChar = $char.toLower()
    }
    $retKey.KeyChar = [char]$retKey.KeyChar

    return $retKey
}

$script:confirmingKeys = @(
                            [ConsoleKey]::Enter
                        )

$script:specialKeys = $script:confirmingKeys +@(
    [ConsoleKey]::Tab,
    [ConsoleKey]::UpArrow,
    [ConsoleKey]::DownArrow,
    [ConsoleKey]::LeftArrow,
    [ConsoleKey]::RightArrow
)

# *********************************************
function Add-ConfirmingKey([char]$char) {
    $consoleKey = Convert-CharToConsoleKey $char
    if($script:confirmingKeys -notcontains $consoleKey){
        $script:confirmingKeys += $consoleKey
    }
}

# *********************************************
function Remove-ConfirmingKey([char]$char) {
    $consoleKey = Convert-CharToConsoleKey $char
    $script:confirmingKeys = $script:confirmingKeys | where-object {$_ -ne $consoleKey}
}

# *********************************************
function IsSpecialKey($keyInfo) {
    return ($script:specialKeys -contains $keyInfo.Key)
}

# *********************************************
function IsNoSpecialKey ($keyInfo){
    return (-not(IsSpecialKey($keyInfo)))
}

# *********************************************
function IsConfirmingKey($keyInfo) {
    return ($script:confirmingKeys -contains $keyInfo.Key)
}

# *********************************************
function IsNoConfirmingKey ($keyInfo){
    return (-not(IsConfirmingKey($keyInfo)))
}

# *********************************************
function Update-ProposalsLine{
    param(
        [Parameter(ValueFromPipeline=$true, Position=0, Mandatory=$true)]
        [AllowEmptyString()]
        [string]$msg,

        # if this evaluates to $false the function does nothing
        $condition = $null,
        [ConsoleColor] $foregroundColor = [Console]::ForegroundColor,
        [ConsoleColor] $backgroundColor= [Console]::BackgroundColor
    )

    if($condition -ne $false){ # $null shall be handled just like $true
        Update-ConsoleLine -x 0 -y -2 -yIsRelative -ClearLine `
                            -Message:$msg `
                            -ForegroundColor:$foregroundColor `
                            -BackgroundColor:$backgroundColor
    }
}

# *********************************************
function TabComplete{
    param(
        $matches,
        [string]$inputString
    )
    [string]$newInputString = $inputString
    if($matches.count -eq 1){
        # auto-complete
        $newInputString = $matches[0]
    }elseif($matches.count -gt 1){
        $mismatchFound = $false
        $pos = $newInputString.length

        while(-not($mismatchFound)){
            #$matches | ForEach-Object {
            #    if($_.length -le $pos){
            #        $mismatchFound = $true
            #        break
            #    }
            #}
            # take next letter from first match
            $nextLetter =$matches[0][($pos)]
            # ... and compare with next letter from other matches
            for($i=1; $i -lt $matches.count; $i++){
                if($matches[$i][$pos] -ne $nextLetter){
                    $mismatchFound = $true
                    break
                }
            }
            if(!$mismatchFound){
                $pos++
                $newInputString += $nextLetter
            }
        }
        if(-not($mismatchFound)){
            $finalMatches = @() +($matches | where-object {$_.startsWith($newInputString,'CurrentCultureIgnoreCase')})
            if($finalMatches.count -eq 1){
                # when full match was found replace input with full match (for correct case)
                $newInputString = $finalMatches[0]
            }
        }
    }

    return $newInputString
}

# *********************************************
# main function code
# *********************************************
function Read-Input{
    [CmdletBinding(DefaultParameterSetName="NoOptionsGiven")]
    param(
        # The string to display before awaiting user input.
        [Parameter(Position=0)]
        [string]$prompt="",

        # allow selection of multiple items separated by the character defined with this option
        [AllowNull()]
        [char]$multiSelectSeparator = $null,

        # a list of options (allowed values) can be used for tab-completion
        # or reading input without requiring the user to press Enter to confirm.
        [Parameter(ParameterSetName="WithOptionsGiven", Mandatory=$true)]
        [string[]] $options,

        # automatically return the option value which is the only possible match
        # for the input typed so far.
        [Parameter(ParameterSetName="WithOptionsGiven")]
        [switch]$noRequireEnter,

        # show potential matches as user types the input
        [Parameter(ParameterSetName="WithOptionsGiven")]
        [switch]$showProposals
    )
    $itemSeparatorKey = $null
    if($multiSelectSeparator){
        $itemSeparatorKey = (Convert-CharToConsoleKey $multiSelectSeparator)
    }

    if($options){
        Write-Host ""    # this line is used for messages/proposals
        Write-Host $prompt

        # ********* read first user input ************
        $keyInfo = ReadKeyWrapper

        $retvals = @()
        [string]$inputLine = ""
        while ($keyInfo.Key -ne [ConsoleKey]::Enter){

            if(($keyInfo.Key -eq [ConsoleKey]::Backspace)){
                # handle backspace (remove last character)
                $inputLine = $inputLine -replace ".$"
                Update-ConsoleLine -x 0 -y 0 -yIsRelative -ClearLine -Message $inputLine
            }elseif(IsNoSpecialKey($keyInfo)){
                # handle normal character and add it to input string
                $inputLine += $keyInfo.KeyChar.ToString()
            }

            if($multiSelectSeparator){
                if ($keyInfo.Key -eq $itemSeparatorKey.Key){
                    $inputWord = ""
                    $inputLineWithoutInputWord = $inputLine
                }else{
                    $words = $inputLine.split($multiSelectSeparator)
                    $inputWord = $words[-1]
                    $inputLineWithoutInputWord = $inputLine -replace "$inputWord$",""
                }
            }else{
                $inputWord = $inputLine
            }

            if($options){
                if($inputWord.length -eq 0){
                    # clear proposals line
                    Update-ProposalsLine ""
                }
                else{
                    $matches = @()+ ($options | Where-Object {$_.StartsWith($inputWord,'CurrentCultureIgnoreCase')})

                    if($matches.count -eq 0){
                        Update-ProposalsLine "[no option matches]" -foregroundColor Red
                    }else{
                        if(($matches.count -eq 1) ){
                            if($noRequireEnter){
                                Update-ProposalsLine ""
                                Write-Host ""
                                return $matches[0]
                            }
                            # if current word has an exact match but wrong case
                            # 'correct' the case setting of the current inputWord
                            if($inputWord -eq $matches[0]){
                                $inputWord = $matches[0]
                                $inputLine =$inputLineWithoutInputWord + $inputWord
                                Update-ConsoleLine -x 0 -y 0 -yIsRelative -ClearLine  -Message $inputLine -noResetCursorToOrigin
                            }
                        }
                        # handle tab keypress
                        if($keyInfo.Key -eq [ConsoleKey]::Tab){
                            $inputWord = TabComplete -matches $matches -inputString $inputWord
                            $inputLine =$inputLineWithoutInputWord + $inputWord
                            Update-ConsoleLine -x 0 -y 0 -yIsRelative -ClearLine  -Message $inputLine -noResetCursorToOrigin
                        }
                        $matchesStr = $matches -join "|"
                        Update-ProposalsLine $matchesStr -condition $showProposals -ForegroundColor Magenta
                    }
                }
            }
            # ********* read next user input ************
            $keyInfo = ReadKeyWrapper
        }
        Update-ProposalsLine ""
        Write-Host ""
        $inputLine = $inputLine.trim($multiSelectSeparator)
        $retvals = $inputLine.Split($multiSelectSeparator)
    }
    else{
        $retvals = (@()+(Read-Host -Prompt $prompt))
    }

    return $retvals
}

#**************************************#
#     main script/function
#**************************************#
function Show-Menu {
    Param(
        # A menu item can be either an object created with New-MenuItem() or simply a string.
        # Strings will be converted to menu items with the same return value as their description: the input string.
        # It is possible not to pass any Items for example if only special menu items are used
        [Parameter(Position = 0)]
        [Object[]]$MenuItems,

        # use this switch for simple string menu items if you don't want each item to be listed as a key-value pair
        # but only the strings themselves which will then be used as keys
        [switch] $valuesAsKeys,

        # Special menu items act the same as normal items but are listed at the bottom with 'quit' and 'back'
        [Object[]]$specialMenuItems = @(),

        [string] $Title,

        # if set to true the menu will return the result (within the pipeline, not to console) after the selected action
        # otherwise the result will be shown (on the console) and the main menu is shown again
        [switch] $isSubMenu,

        # Don't create an automatich option for 'back'
        [switch] $noBackOption,

        # Don't create an automatich option for 'quit'
        [switch] $noQuitOption,

        [switch] $sortItems,

        # show narrowed down list of matching options as you are typing your choice
        [switch] $showProposals,

        # allow selection of multiple items separated by the character defined with this option
        [AllowNull()]
        [char]$multiSelectSeparator = $null,

        # select a menu option as soon as the typed key matches (without needing to press enter)
        [switch] $noRequireEnter
    )

    # ************************************************************
    #  Extend/normalize menu items:
    #    - if the item is a simple string convert it to a MenuItem structure
    #    - if the item has no 'key' assigned yet assign an automatic one

    # normalize items
    foreach($refItmList in @([ref]$MenuItems,[ref]$SpecialMenuItems)){
        if($refItmList.value){ # empty lists are allowed
            $refItmList.value = $refItmList.value | foreach-object {
                if(-not $_.Description){
                    New-MenuItem -Description $_ -Action ([Scriptblock]::Create("""$($_)""")) -Key (iif $valuesAsKeys $_ $null)
                }else{
                    $_
                }
            }
        }
    }

    # automatic keys: digits 1 to 9, characters A to Z
    $presetKeys = $MenuItems + $SpecialMenuItems | ForEach-Object {if($_.Key){$_.Key}}
    $autoKeys = (49..57) + (65..90) | ForEach-Object { "$([char]$_)" } | where-object {-not($presetKeys -contains $_)}
    $keyIdx=0

    # reorder items
    if($sortItems){
        $MenuItems = $MenuItems | sort-object -property Description
    }

    # assign auto-keys
    foreach($itemList in @($MenuItems,$specialMenuItems)){
        for($i=0; $i -lt $itemList.Count; $i++){
            if(-not $itemList[$i].Key)
            {
                $itemList[$i].Key = $autoKeys[$keyIdx++]
            }
        }
    }

    $usedKeys = @()+($MenuItems + $specialMenuItems).foreach{$_.key}

    # *****  create built-in special menu items (quit/back) to display in separate section
    $specialMenuItems = @() + $specialMenuItems

    if(-not($noBackOption)){
        $key = iif($usedKeys -contains "b") ":b" "b"
        $menuItemBack = New-MenuItem -Description "back" -Action { throw "menu:back" } -Key $key
        if ($isSubMenu) {
            $specialMenuItems += $menuItemBack
            $usedKeys += $key
        }
    }
    if(-not($noQuitOption)){
        $key = iif($usedKeys -contains "q") ":q" "q"
        $menuItemQuit = New-MenuItem -Description "quit" -Action { exit 0 } -Key "q"
        $specialMenuItems += $menuItemQuit
        $usedKeys += $key
    }


    # *****  create main item list to display
    $header = $null
    $len = [math]::Max((($MenuItems).Description | Measure-Object -Maximum -Property Length).Maximum, $Title.Length)
    $dashedLine = '-' * $len
    if (![string]::IsNullOrWhiteSpace($Title)) {
        $header = '{0}{1}{2}{3}' -f $Title, [Environment]::NewLine, $dashedLine, [Environment]::NewLine
    }

    $items =@()+($MenuItems | ForEach-Object {
                if($valuesAsKeys){
                    $_.Description
                }else{
                    if($null -ne $_){
                        '[{0}]  {1}' -f $_.Key, $_.Description
                    }
                }
            }
        )


    $lines = @()

    if($items.count -gt 0){
        $maxVertCount = 10
        $numCols = [int]($items.count / $maxVertCount + 0.5)
        $vertCount = [int]($items.count / $numCols + 0.5)
        if($numCols -eq 1){$vertCount = $items.count}
        #$colWidth=[System.Console]::WindowWidth/$numCols
        (0..($vertCount-1)) | ForEach-Object{
            $lineIdx = $_
            $line = ""
            (0..($numCols-1)) | ForEach-Object {
                $colIdx = $_
                $line += "{0,-40}" -f ($items[($colIdx*$vertCount)+$lineIdx])
            }
            $lines += $line
        }
    }
    $itemList = $lines -join "`n"

    if($specialMenuItems.Count -gt 0){
        $specialItemList = ($specialMenuItems | ForEach-Object {
        '[{0}] {1}' -f $_.Key, $_.Description }) -join "   "
    }

    $itemList += "`n$dashedLine`n" +  $specialItemList

    if($usedKeys.count -eq 0){
        Write-Error "Cannot run Show-Menu with no menu options and no special options (`$usedKeys=0)"
    }
    # display the menu and return the chosen option
    while ($true) {
        #cls
        if ($header) { Write-Host $header -ForegroundColor Yellow }
        Write-Host $itemList
        Write-Host

        $returnedKeys = (Read-Input `
                               -Prompt 'Please make your choice' `
                               -options $usedKeys `
                               -multiSelectSeparator:$multiSelectSeparator `
                               -showProposals:$showProposals `
                               -noRequireEnter:$noRequireEnter
        )

        $availableItems = @() + $MenuItems + $specialMenuItems
        $selectedItems = @()
        foreach($returnedKey in $returnedKeys){
            if($availableItems.Key -notcontains $returnedKey){
                # You can handle invalid options here.
                # Read-Input should already have indicated to the user that this option is invalid
                # so we will just ignore this item
            }else{
                # Avoid selecting multiple options if they have the same key but different casing. E.g. 'a' and 'A' might be used for different options
                # first try case sensitive key match
                $keyMatchedItems = ($availableItems | Where-Object {$_.key -ceq $returnedKey})
                if(-not $keyMatchedItems.count){
                    # then try case insensitive key match
                    $keyMatchedItems = ($availableItems | Where-Object {$_.key -eq $returnedKey})
                }
                $selectedItems += $keyMatchedItems
            }
        }

        $menuRetVals = @()
        foreach($selectedItem in $selectedItems){
            try {
                Write-verbose "Invoking script for item `"$($selectedItem.Description)`" with args: $($selectedItem.Args `
                                        | ForEach-Object {if($_){"type:{0} value:{1}" -f $_.getType(),$_}} )"

                if($selectedItem.Action){
                    $menuRetVals += Invoke-Command -noNewScope -ScriptBlock $selectedItem.Action -ArgumentList $selectedItem.Args
                }
            }
            catch {
                    if($PSItem.Exception.Message -ne "menu:back"){
                        throw $PSItem
                    }
                    return
            }
        }

        if ($isSubMenu) {
            # End this menu and return the result value
            Write-Verbose "returning value: $ret"
            return $menuRetVals
        }
        else {
            # don't return from loop that reads user input
            # Clear-Host
            Write-Host ($menuRetVals | out-string) -foregroundColor blue
        }
    }
}

# This function uses a (referenced) list as input for its options.
# It also shows the option 'add new value' which lets the user enter a new value which is returned
# and added to the list.
function Show-MenuDynamicList {
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        # A dynamic list must be passed as [ref] in order to be able to extend it with new values
        [ref]$RefList,

        [switch] $valuesAsKeys,

        # Special menu items act the same as normal items but are listed at the bottom with 'quit' and 'back'
        [Object[]]$specialMenuItems = @(),

        # ----- all other parameters will be passed on directly to Show-Menu
        [string] $Title,

        [switch] $isSubMenu,

        # Don't create an automatich option for 'back'
        [switch] $noBackOption,

        # Don't create an automatich option for 'quit'
        [switch] $noQuitOption,

        # allow selection of multiple items separated by the character defined with this option
        [AllowNull()]
        [char]$multiSelectSeparator = $null,

        # show narrowed down list of matching options as you are typing your choice
        [switch] $showProposals,

        # select a menu option as soon as the typed key matches (without needing to press enter)
        [switch] $noRequireEnter
    )

    $addItm = New-MenuItem -Description "<Add new value>" -Key "A" -Action ([scriptblock]::create("""A"""))

    $RefListShallowCopy = @()
    $RefList.Value | foreach-object {$RefListShallowCopy += $_}

    $retval = Show-Menu -MenuItems $RefListShallowCopy `
                        -Title $Title `
                        -isSubMenu:$isSubMenu `
                        -specialMenuItems (@() + $addItm + $specialMenuItems) `
                        -valuesAsKeys:$valuesAsKeys `
                        -showProposals:$showProposals `
                        -multiSelectSeparator:$multiSelectSeparator `
                        -noRequireEnter:$noRequireEnter `
                        -noBackOption:$noBackOption `
                        -noQuitOption:$noQuitOption

    if(@("a","<Add new value>") -contains $retval[0]){
        $newItms=@()
        do{
            $newItm = Read-Host "Enter new value (type ### to end new value input)"
            if($newItm -ne '###'){
                $newItms += $newItm
                Write-Host "Added '$($newItms[-1])'"
            }
        }while($newItm -ne '###')
        if($newItms){ $newItms | foreach-object { $RefList.Value += $_ } }
        $retval = $newItms
    }
    return $retval
}

Export-ModuleMember -function Read-Input,New-MenuItem,Show-Menu,Show-MenuDynamicList,TabComplete


