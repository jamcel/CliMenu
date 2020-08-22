# CliMenu
Powershell module for quickly creating a console menu based application.

In its most basic form it shows a list of options the user can select from and waits for user input.
When the user enters his selection an associated value is returned or an associated task (ScriptBlock)
is run and the main menu screen is shown again. Thus, by default Show-Menu works in loop mode.

Submenus: menu item tasks can call Show-Menu recursiveley with other options in order to
act as a sub-menu. In this case, you don't want to show the sub-menu over and over again and
need to return to the calling function after a selection. This is done using the -isSubmenu switch.
You can also use this to show a menu not running in loop mode.

The most common use case is that you have a list of strings that a user should choose from.

Example:
        Show-Menu -MenuItems @("do this","do that","do nothing") -isSubMenu
Output:
        [1]  do this
        [2]  do that
        [3]  do nothing
        ----------
        [b] back   [q] quit

        Please make your choice:

This simple line shows a nicely formatted menu that saves you a lot of unnecessary code overhead.
Especially when used frequently or in more complicated cases.

Additional options/features:
    - add ScriptBlock to each menu item to be processed when selected
    - show/hide default special menu items "quit" and "back" (only shown if -isSubmenu was set)
    - add additional special menu items (at bottom) with custom ScriptBlocks
    - don't require the user to press enter after the selection (faster)
    - don't use item numbering (-valuesAsKeys): the user has to enter the item string to select it
    - [with -valuesAsKeys] preview filtered item selection when the user starts entering an item value
    - [with -valuesAsKeys] tab complete item selection (bash style)
    - [with -valuesAsKeys] allow multi-select mode: the user can select multiple options by separating them with
         his chosen separator (default: ';'). Preview and tab completion still work for each separate value.




