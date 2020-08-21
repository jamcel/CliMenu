$basePath = & {if($PSScriptRoot){$PSScriptRoot}else{"."}}
import-module "$basePath\CliMenu.psm1" -force
import-module "$basePath\..\GmailCli\EmailOrderExtractor.psm1" -force


$main0_sub0 = New-MenuItem -Description "choice 1" -Action {param($a,$b); "A is $a and B is $b"} -Args 1,2

$main_items = @()
$main_items += New-MenuItem -Description "Go to simple submenu 1" -Key "s1" -Action {
    $retval = Show-Menu -isSubMenu -MenuItems $main0_sub0 -Title "Submenu 1"
    Write-Host "Submenu returned $retval"
  }

$subItms =  @("aaab","aac","cba","bda","cbsa","bba","cbssa")

$main_items  += New-MenuItem -Description "Show choices from list (-valuesAsKeys)" `
                            -Action {
                                param($subMenuItms)
                                $retval = Show-Menu -isSubMenu -MenuItems $subMenuItms -Title "Submenu simple list" -valuesAsKeys
                                Write-Host "Submenu returned $retval"
                              }`
                             -Args (,$subItms)

# ***** dynamic list as main menu

$dynArray = (65..90) | ForEach-Object { [char]$_ }

#$retval = Show-MenuDynamicList `
#                            -RefList ([ref]$dynArray)  `
#                            -Title "Main menu dynamic list"
#Write-Host "Main menu returned $retval"


# ***** dynamic list as submenu
$main_items  += New-MenuItem `
                            -Description "Show choices from dynamic list" `
                            -Action {
                                param([ref]$refDynList)
                                Show-MenuDynamicList  -isSubMenu `
                                                      -RefList $refDynList  `
                                                      -Title "Submenu dynamic list"
                              }`
                            -Args ([ref]$dynArray)

# ***** long dynamic list as submenu
$longDynList=Get-EmailOrderTags
$main_items  += New-MenuItem `
                            -Description "Show choices from very long dynamic list (with -showProposals)" `
                            -Action {
                                param([ref]$refDynList)
                                Show-MenuDynamicList  -isSubMenu `
                                                      -RefList $refDynList  `
                                                      -Title "Submenu long dynamic list (with -showProposals)" `
                                                      -valuesAsKeys `
                                                      -showProposals `
                                                      -multiSelectSeparator ','
                              }`
                            -Args ([ref]$longDynList)

Show-Menu -MenuItems $main_items -noRequireEnter -Title "Test Menu for CliMenu"