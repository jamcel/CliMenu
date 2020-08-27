Import-Module Pester

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests.ps1', ''
$basePathNoExt = "$here\$sut"
if(Test-Path "$basePathNoExt.psm1")  {
  import-module "$basePathNoExt.psm1" -force }
elseif(Test-Path "$here\$sut.ps1"){
  . "$here\$sut.ps1"}
else{
  Write-Error "Couldn't derive script name to test from this script's name."
  Exit 1
}

$global:simInputBuffer = ""
$global:simInputPosCnt = 0
function global:Set-InputBuffer($word){
  $global:simInputBuffer = $word
  $global:simInputPosCnt = 0
}

function global:Get-NextInputFromBufferAsKey{
  # mock function for [console]::readkey()
  # reads characters sequentially from $global:simInputBuffer

  # note: to list all enumvalues of an enum type you can use the property .declaredFields or .declaredMembers
  #     e.g.   [System.ConsoleModifiers].declaredFields
  $retKey =  [PSCustomObject]@{
    Key = [consoleKey]::Enter
    KeyChar = ''
    Modifiers = ''
  }

  if($global:simInputPosCnt -lt $global:simInputBuffer.Length){
    [string]$char = $global:simInputBuffer[$global:simInputPosCnt++]
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
  }
  $retKey.KeyChar = [char]$retKey.KeyChar[0]
  return $retKey
}


Describe "Read-Input" -Tag "Read-Input" {

    # disable console line updates - they mess up the pester output
    Mock Update-ConsoleLine -ModuleName "CliMenu" -MockWith { }
    Mock ReadKeyWrapper -ModuleName "CliMenu" -MockWith { Get-NextInputFromBufferAsKey }
    Mock Write-Host -ModuleName "CliMenu" -MockWith { }

  # ******************************************************************

    # **********************
    context "    Check that it ouputs the prompt message" {
      $cases = @( @{cmdOpts =""; userInput=""},
                  @{cmdOpts ="-options @('aaa')"; userInput="aaa`n"},
                  @{cmdOpts ="-options @('aaa') -noRequireEnter"; userInput="aaa`n"}
                )

      It "when called with params: '<cmdOpts>')" -TestCases $cases{
        param($cmdOpts,
              $userInput
        )

        # *** prepare the test
        Mock Read-Host -ModuleName "CliMenu" -MockWith { }
        Set-InputBuffer $userInput

        # *** invoke command under test
        Invoke-Expression "Read-Input ""Prompt message"" $cmdOpts"

        if($cmdOpts -notlike "*options*"){
          Assert-MockCalled  Read-Host -ModuleName "CliMenu" -Exactly 1 -Scope It -ParameterFilter { $Prompt -eq "Prompt message" }
        }else{
          Assert-MockCalled  Write-Host -ModuleName "CliMenu"  -Exactly 1 -Scope It -ParameterFilter { $Object -eq "Prompt message" }
          Assert-MockCalled  ReadKeyWrapper -ModuleName "CliMenu"
        }
      }
    }

    # **********************
    It "Should return the user input that was confirmed with Enter" {
      Mock Read-Host -ModuleName "CliMenu" -MockWith {
        "abcd"
      }
      Read-Input "Prompt message" | Should be "abcd"
    }

    # **********************
    It "Should not accept the option -noRequireEnter without options given" {
      $cmd = Get-Command Read-Input
      $paramSetsContainingNoRequireEnter = @() + ($cmd.parametersets | Where-Object { $_.Parameters.Name -contains 'noRequireEnter' })
      $paramSetsContainingNoRequireEnter | ForEach-Object{
        $optParam = $_.Parameters | Where-Object {$_.Name -eq 'options'}
        $optParam | Should Not be $null
        $optParam.IsMandatory | Should be $true
      }
    }

  # ******************************************************************
  Context "   -options @(...)"{

    # ********************************************

    # **********************
    It "Should return the user input that was confirmed with Enter" {
      Set-InputBuffer "Hello`nxxx"
      Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") | Should be "Hello"
    }

    # **********************
    It "Should show a warning as soon as no matching option can be found" {
      Set-InputBuffer "ae`nxxx"
      Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") | Should Be "ae"
      Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                            -Scope It `
                                            -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") }
    }

    # **********************
    It "Should tab-complete the single matching option" {
      Set-InputBuffer "aabc`t`nxxx"
      Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") | Should Be "aabccc"
    }

    # **********************
    It "Should tab-complete up to the next ambiguity of multiple potential matches." {
      Set-InputBuffer "a`ta`tb`t`nxxx"

      # Note: don't know how to properly mock 'TabComplete'
      #       therefore we can't check whether it was called the
      #       right number of times

      #$global:TabCompleteFcn = Get-Command TabComplete -CommandType Function
      #Mock TabComplete -ModuleName CliMenu -MockWith {
      #   & $global:TabCompleteFcn
      #}

      Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") `
      | Should be "aabbcc"

      #Assert-MockCalled  TabComplete -ModuleName "CliMenu" -Times 3
      Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                            -Scope It `
                                            -Times 1 `
                                            -ParameterFilter { ($y -eq 0) -and ($message -eq "aab") }
      Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                            -Scope It `
                                            -Times 1 `
                                            -ParameterFilter { ($y -eq 0) -and ($message -eq "aabbcc") }
    }

    # ********************************************
    Context "   -multiSelectSeparator ','"{

      # **********************
      It "Should return multiple values when separated with commas" {
        Set-InputBuffer "aabbcc,abc`n"
        Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") -multiSelectSeparator ',' `
          | Should be @("aabbcc","abc")
      }

    }
    # ********************************************
    Context "   -showProposals"{

      # **********************
      It "Should output the prompt message" {

        # mock Write-Host in order to be able to check whether and how it was called
        Mock Write-Host -ModuleName "CliMenu" -MockWith { }
        Set-InputBuffer ""
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") -showProposals
        Assert-MockCalled  Write-Host -ModuleName "CliMenu"  -Exactly 1 -Scope It -ParameterFilter { $Object -eq "Prompt message" }
        Assert-MockCalled  ReadKeyWrapper -ModuleName "CliMenu"
      }

      # **********************
      It "Should ignore case when checking proposals" {
        Set-InputBuffer "Aabcxxxxxxx"
        $retVal = Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") -showProposals
        $retval | Should BeExactly "aabccc"

        Set-InputBuffer "Aabcxxxxxxx"
        $retVal = Read-Input "Prompt message" -noRequireEnter -options @("Abc","Aabbcc","Aabccc") -showProposals
        $retval | Should BeExactly "Aabccc"

        Set-InputBuffer "aabcxxxxxxx"
        $retVal = Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") -showProposals
        $retval | Should BeExactly "aabccc"

        Set-InputBuffer "aabcxxxxxxx"
        $retVal = Read-Input "Prompt message" -noRequireEnter -options @("Abc","Aabbcc","Aabccc") -showProposals
        $retval | Should BeExactly "Aabccc"

        Set-InputBuffer "AABCxxxxxxx"
        $retVal = Read-Input "Prompt message" -noRequireEnter -options @("Abc","Aabbcc","Aabccc") -showProposals
        $retval | Should BeExactly "Aabccc"

        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                            -Scope It `
                                            -Times 0 `
                                            -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") }
      }

      # **********************
      It "Should show a list of matching options as soon as the user enters input" {
        Set-InputBuffer "aabcxxxxxxx"
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") -showProposals
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
          -Scope It `
          -Times 1 `
          -ParameterFilter {  ($message -eq "abc|aabbcc|aabccc") }
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
          -Scope It `
          -Times 1 `
          -ParameterFilter {  ($message -eq "aabbcc|aabccc") }
      }

      # **********************
      It "Should reset the list of matching options when a new item begins" {

        Set-InputBuffer "abc,aabc`t`nxxxxxxx"

        Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") -multiSelectSeparator ',' -showProposals

        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
          -Scope It `
          -Times 1 `
          -ParameterFilter {  ($message -eq "abc") }
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
          -Scope It `
          -Times 1 `
          -ParameterFilter {  ($message -eq "aabccc") }
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
          -Scope It `
          -Times 0 `
          -ParameterFilter {  ($message -eq "[no option matches]") }
      }

      # **********************
      It "Should keep showing previous matches when using -multiSelectSeparator and tab-completing the current input." {

        Set-InputBuffer "abc,aabc`t`nxxxxxxx"

        Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") -multiSelectSeparator ',' -showProposals

        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
          -Scope It `
          -Times 1 `
          -ParameterFilter {  ($y -eq 0 ) -and ($message -eq "abc,aabccc") }
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
          -Scope It `
          -Times 0 `
          -ParameterFilter {  ($y -eq 0 ) -and ($message -eq "aabccc") }
      }

      # **********************
      It "Should allow input corrections with backspace when using -multiSelectSeparator" {
        Set-InputBuffer "aabbcc,ab`b`b`b`b`b`bc`t`nxxx"
        Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") -multiSelectSeparator "," `
        | Should be "aabccc"
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -Times 0 `
                                              -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") }
      }
    }

    # ********************************************
    Context "   -noRequireEnter" {

      # **********************
      It "Should output the prompt message" {

        # mock Write-Host in order to be able to check whether and how it was called
        Mock Write-Host -ModuleName "CliMenu" -MockWith { }
        Set-InputBuffer ""
        Read-Input "Prompt message" -options @("abc","aabbcc","aabccc") -noRequireEnter
        Assert-MockCalled  Write-Host -ModuleName "CliMenu"  -Exactly 1 -Scope It -ParameterFilter { $Object -eq "Prompt message" }
        Assert-MockCalled  ReadKeyWrapper -ModuleName "CliMenu"
      }

      # **********************
      It "Should allow input corrections using backspace" {
        Set-InputBuffer "ae`bbxxx"
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") `
        | Should be "abc"
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") }
        $global:simInputPosCnt | Should be 4
      }

      # **********************
      It "Should return the first matching value of options as soon as the input isn't ambiguous" {
        Set-InputBuffer "aabcxxxxxxx"
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") -showProposals | Should be "aabccc"
        # check that the function returned after the the first four characters
        $global:simInputPosCnt | Should be 4
      }

      # **********************
      It "Should show a warning if no matching option can be found" {
        Set-InputBuffer "aeee`nxxx"
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc")
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") }
      }

      # **********************
      It "Should reset the warning if previously no matching option could be found but the user corrected the input" {

        Set-InputBuffer "ae`babcxxx"
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") | should be "aabccc"

        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") }
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -ParameterFilter { ($message -eq "") }
      }

      # **********************
      It "Should not affect input if backspace is pressed before entering other characters" {

        Set-InputBuffer "`babxxx"
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") | should be "abc"

        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") } `
                                              -Times 0
      }

      # **********************
      It "Should tab-complete up to the next ambiguity of multiple potential matches." {
        Set-InputBuffer "a`ta`tb`txxx" # no '`n' should be needed

        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") `
        | Should be "aabbcc"

        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -Times 1 `
                                              -ParameterFilter { ($y -eq 0) -and ($message -eq "aab") }
      }

      # **********************
      It "Should return the first matching value" {
        Set-InputBuffer "abxxx"
        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") | Should be "abc"
      }

      # **********************
      It "Should return the 'invalid' user input string if it was forced by pressing ENTER" {

        Set-InputBuffer "aeee`nxxx"

        Read-Input "Prompt message" -noRequireEnter -options @("abc","aabbcc","aabccc") | Should be "aeee"
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
                                              -Scope It `
                                              -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") }
        $global:simInputPosCnt | Should be 5
      }
    }
  }
}

Describe "Show-Menu" -Tag "Show-Menu" {

  # disable console line updates - they mess up the pester output
  Mock Update-ConsoleLine -ModuleName "CliMenu" -MockWith { }
  Mock ReadKeyWrapper -ModuleName "CliMenu" -MockWith { Get-NextInputFromBufferAsKey }
  Mock Write-Host -ModuleName "CliMenu" -MockWith { }

# ******************************************************************

  # **********************
  context "    Check that it returns the expected value" {
    $cases = @( @{menuItems= @("a","b","c"); cmdOpts =@{isSubMenu=$true}; userInput="2"; expRetVal="b"},
                @{menuItems= @("a","b","c"); cmdOpts =@{isSubMenu=$true; valuesAsKeys=$true}; userInput="b"; expRetVal="b"},
                @{menuItems= @("a","b","c"); cmdOpts =@{isSubMenu=$true; noRequireEnter=$true}; userInput="2xxx"; expRetVal="b"},
                @{menuItems= @("a","b","c"); cmdOpts =@{isSubMenu=$true; noRequireEnter=$true; valuesAsKeys=$true}; userInput="bxxx"; expRetVal="b"},
                @{menuItems= @("a","b","c"); cmdOpts =@{isSubMenu=$true; noRequireEnter=$true; valuesAsKeys=$true}; userInput="xbxx"; expRetVal=$null},
                @{menuItems= $null;          cmdOpts =@{isSubMenu=$true; noRequireEnter=$true; valuesAsKeys=$true}; userInput="bxxx"; expRetVal=$null}
              )

    It "with menu items 'a','b','c' and user input '<userInput>'. Expected retVal: '<expRetVal>'" -TestCases $cases -Test {
      param(
            $menuItems,
            $cmdOpts,
            $userInput,
            $expRetVal
      )

      Set-InputBuffer $userInput

      # *** invoke command under test
      $retVal = Show-Menu -menuItems $menuItems -Title "Prompt message" @cmdOpts
      $retVal | should be $expRetVal
    }
  }

  context "    Check that it returns the expected value" {
    $cases = @( @{menuItems= $null; cmdOpts =@{isSubMenu=$true}; userInput="b`bb`nc"; expRetVal=$null}
              )

    It "with no (normal) menu items and user input '<userInput>'. Expected retVal: '<expRetVal>'" -TestCases $cases -Test {
      param(
            $menuItems,
            $cmdOpts,
            $userInput,
            $expRetVal
      )

      # *** prepare the test

      Set-InputBuffer $userInput

      # *** invoke command under test
      $retVal = Show-Menu -menuItems $menuItems -Title "Prompt message" @cmdOpts
      $retVal | should be $expRetVal

      Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
      -Scope It `
      -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") } `
      -Times 0
    }
  }

  context "    Check that it proposes normal and special item values when typing starts" {
    $cases = @(
        @{menuItems= @("boo","X"); cmdOpts =@{isSubMenu=$true; showProposals=$true;  valuesAsKeys=$true};  userInput="b`n"; expRetVal=$null; expProposals=@(@{string="boo|b";count=1})},
        @{menuItems= @("y","X");   cmdOpts =@{isSubMenu=$true; showProposals=$false; valuesAsKeys=$true};  userInput="b`n"; expRetVal=$null; expProposals=@(@{string="b";count=1})},
        # the following revealed a bug when having only one menu item: '[no option matches]' was shown for any user input even matches and matches to special options (b/q).
        @{menuItems= @("X");       cmdOpts =@{isSubMenu=$true; showProposals=$false; valuesAsKeys=$true};  userInput="b`n"; expRetVal=$null; expProposals=@(@{string="b";count=1})},
        @{menuItems= @("X");       cmdOpts =@{isSubMenu=$true; showProposals=$false; valuesAsKeys=$false}; userInput="b`n"; expRetVal=$null; expProposals=@(@{string="b";count=1})},
        # dont test user input "q`n" without mocking the quit functionality. Otherwise pester will fail with
        #       'Exception calling "LeaveTestGroup" with "2" argument(s) ...
        # workaround for checking correct proposal after user input "q": add "`bb`n"
        @{menuItems= @("Qualle");  cmdOpts =@{isSubMenu=$true; showProposals=$false; valuesAsKeys=$false}; userInput="q`b1`n"; expRetVal="Qualle"; expProposals=@()}
        @{menuItems= @("Qualle");  cmdOpts =@{isSubMenu=$true; showProposals=$false; valuesAsKeys=$true};  userInput="q`bQu`n"; expRetVal=$null; expProposals=@()}
        @{menuItems= @("X");       cmdOpts =@{isSubMenu=$true; showProposals=$false; valuesAsKeys=$false}; userInput="q`b1`n"; expRetVal="X"; expProposals=@()}
        @{menuItems= @("X");       cmdOpts =@{isSubMenu=$true; showProposals=$false; valuesAsKeys=$true};  userInput="q`bX`n"; expRetVal="X"; expProposals=@()}
    )

  It "with normal and special menu items and user input '<userInput>'." -TestCases $cases -Test {
      param(
            $menuItems,
            $cmdOpts,
            $userInput,
            $expRetVal,
            $expProposals
      )

      # *** prepare the test


      Set-InputBuffer $userInput

      # *** invoke command under test
      $retVal = Show-Menu -menuItems $menuItems -Title "Prompt message" @cmdOpts
      $retVal | should be $expRetVal

      Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
      -Scope It `
      -ParameterFilter { ($foreGroundColor -eq "red") -and ($message -eq "[no option matches]") } `
      -Exactly 0

      foreach($expProposal in $expProposals){
        Assert-MockCalled  Update-ConsoleLine -ModuleName "CliMenu" `
        -Scope It `
        -ParameterFilter {  ($message -eq $expProposal.string) } `
        -Times $expProposal.count
      }
    }
  }
}
