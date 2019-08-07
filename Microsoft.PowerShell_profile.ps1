Clear-Host

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
import-module $scriptDir\loader.psm1

###############################################################################

InstallAndLoadModule posh-git
import-module $scriptDir\prompt.psm1

function prompt { gitFancyPrompt }

###############################################################################

Import-Module PSReadLine

Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 4000
# history substring search
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

# Tab completion
Set-PSReadlineKeyHandler -Chord 'Shift+Tab' -Function Complete
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

###############################################################################

If (-Not (Test-Path Variable:PSise)) {  # Only run this in the console and not in the ISE
    InstallAndLoadModule Get-ChildItemColor
    
    Set-Alias l Get-ChildItem -option AllScope
    Set-Alias ls Get-ChildItemColorFormatWide -option AllScope
}

###############################################################################

InstallAndLoadModule ZLocation