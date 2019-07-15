##########################################################################
# Configuration

$rightPromptGutterSymbol = " ┆"
$rightPromptGutterSymbolWidth = 3
$gitBranch = @{
    symbol = ""
    width = 1
}
$gitChangeSymbol = @{
    working = "◇";
    indexed = "◆";
    both    = "◈";
    width   = 1;
}
$gitAheadBehind = @{
    ahead = "↑"
    behind = "↓"
    width = 1
}
$promptLeaderUpper = ""
$promptLeader = "╰▷"
$locationIconSet = @{
    unknown = " ┌─┐ `n └─┘ "
    dir = " ┌─┐ `n └─╜ "
    registry = " ┌╥╖ `n └╨╜ "
}
$longCommandTime = 5 # in seconds

##########################################################################

Import-Module posh-git

function local:hasIdentifierFile {
    param ([string] $detector);

    if ((Test-Path $detector) -eq $TRUE) {
        return $TRUE
    }
    
    # Test within parent dirs
    $checkIn = (Get-Item .).parent
    while ($NULL -ne $checkIn) {
        $pathToTest = Join-Path -Path $checkIn.fullname $detector
        if ((Test-Path $pathToTest) -eq $TRUE) {
            return $TRUE
        }
        else {
            $checkIn = $checkIn.parent
        }
    }
    
    return $FALSE
}

function local:Test-Administrator {
    if ($PSVersionTable.Platform -eq 'Unix') {
        return ((id -u) -eq 0);
    }
    else {
        $user = [Security.Principal.WindowsIdentity]::GetCurrent();
        return (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    }
}

function local:reserveRightSpace {
    param ([int] $rightCharCount);
    $startposx = $Host.UI.RawUI.windowsize.width - $rightCharCount
    $startposy = $Host.UI.RawUI.CursorPosition.Y
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startposx, $startposy
}

function local:moveCursor {
    param ([int] $deltaX, [int] $deltaY);
    $startposx = $Host.UI.RawUI.CursorPosition.X + $deltaX;
    $startposy = $Host.UI.RawUI.CursorPosition.Y + $deltaY;
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startposx, $startposy
}

function local:reservePromptSpace {
    Write-Host " "
    Write-Host " "
    $startposx = $Host.UI.RawUI.CursorPosition.X
    $startposy = $Host.UI.RawUI.CursorPosition.Y
    if ($startposy -gt 2) {
        $startposy -= 1
    }
    else {
        $startposy -= 2
    }
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startposx, $startposy
}

$local:userName = $env:UserName
$local:isAdmin = (Test-Administrator)
$local:userBadgeColor = "Blue"
if ($isAdmin) {
    $userBadgeColor = "Red"
}

function local:rightPromptGutterWidtth {
    param ([bool] $show);
    if ($show) {
        return $rightPromptGutterSymbolWidth
    }
    else {
        return 0
    }
}

function local:rightPromptGutter {
    param ([bool] $show);
    if ($show) {
        Write-Host $rightPromptGutterSymbol -NoNewline -ForegroundColor DarkGray
    }
}

function local:rightPromptUser {
    param ([int] $startColumn, [bool] $cont);

    
    $userBadgeText = $userName
    $userBadgeTextWidth = $userBadgeText.Length
    
    $nextColumn = 1 + $startColumn + $userBadgeTextWidth + (rightPromptGutterWidtth $cont)

    reserveRightSpace $nextColumn
    Write-Host $userBadgeText -nonewline -foregroundcolor $userBadgeColor
    rightPromptGutter $cont

    return $nextColumn
}

function local:gitChangeWidth([int] $working, [int] $index) {
    if($working -gt 0 -or $index -gt 0) {
        return ($gitChangeSymbol.width)
    } else {
        return 0
    }
}

function local:writeGitChangeSymbol([int] $working, [int] $index, [string] $color) {
    if($working -gt 0 -and $index -gt 0) {
        Write-Host $gitChangeSymbol.both -NoNewline -ForegroundColor $color
    }
    elseif($working -gt 0 ) {
        Write-Host $gitChangeSymbol.working -NoNewline -ForegroundColor $color
    }
    elseif($index -gt 0 ) {
        Write-Host $gitChangeSymbol.indexed -NoNewline -ForegroundColor $color
    }
}

function local:rightPromptGit {
    param ([int] $startColumn, [bool] $cont);

    if (hasIdentifierFile ".git") {
        $status = Get-GitStatus

        # Grab current branch
        $git_branchName = " " + $status.branch
        $git_branchNameWidth = $git_branchName.length

        # Check if workspace has changes
        $git_changesDisplayWidth = 0
        $git_changesDisplayWidth += gitChangeWidth $status.Working.Added.Count    $status.Index.Added.Count
        $git_changesDisplayWidth += gitChangeWidth $status.Working.Modified.Count $status.Index.Modified.Count
        $git_changesDisplayWidth += gitChangeWidth $status.Working.Deleted.Count  $status.Index.Deleted.Count
        $git_changesDisplayWidth += gitChangeWidth $status.Working.Unmerged.Count $status.Index.Unmerged.Count
        if ($status.aheadBy -gt 0) { $git_changesDisplayWidth += $gitAheadBehind.width }
        if ($status.behindBy -gt 0) { $git_changesDisplayWidth += $gitAheadBehind.width }
        if ($git_changesDisplayWidth -gt 0) { $git_changesDisplayWidth += 1 }
        

        $nextColumn = $startColumn + $gitBranch.width + $git_branchNameWidth + $git_changesDisplayWidth + (rightPromptGutterWidtth $cont)
        reserveRightSpace $nextColumn
        
        Write-Host $gitBranch.symbol -nonewline -foregroundcolor Blue
        Write-Host $git_branchName -nonewline
        if ($git_changesDisplayWidth -gt 0) { Write-Host " " -NoNewLine }
        writeGitChangeSymbol $status.Working.Added.Count    $status.Index.Added.Count    Green
        writeGitChangeSymbol $status.Working.Modified.Count $status.Index.Modified.Count Yellow
        writeGitChangeSymbol $status.Working.Deleted.Count  $status.Index.Deleted.Count  Red
        writeGitChangeSymbol $status.Working.Unmerged.Count $status.Index.Unmerged.Count Magenta
        if ($status.aheadBy -gt 0) { Write-Host $gitAheadBehind.ahead -NoNewLine -ForegroundColor Cyan }
        if ($status.behindBy -gt 0) { Write-Host $gitAheadBehind.behind -NoNewLine -ForegroundColor Cyan }
        rightPromptGutter $cont

        return $nextColumn
    }
    else {
        return $startColumn
    }
}

function local:rightPromptLastCommandTime {
    param ([int] $startColumn, [bool] $cont);

    $historyList = (Get-History)
    if ($null -eq $historyList) {
        return $startColumn
    }

    $lastCommand = $historyList[-1]    
    $duration = $lastCommand.EndExecutionTime - $lastCommand.StartExecutionTime
    if ($duration.totalSeconds -le $longCommandTime) {
        return $startColumn
    }

    $timeDisplay = "$($duration.Seconds)s"
    if ($duration.Minutes -gt 0) {
        $timeDisplay = "$($duration.Minutes)m"
    }
    if ($duration.TotalHours -ge 1) {
        $timeDisplay = "$([math]::floor($duration.TotalHours))h"
    }

    $nextColumn = $startColumn + $timeDisplay.Length + (rightPromptGutterWidtth $cont)
    reserveRightSpace $nextColumn
    Write-Host $timeDisplay -NoNewline -ForegroundColor Yellow
    rightPromptGutter $cont

    return $nextColumn
}

function local:rightPrompt {
    $c1 = rightPromptUser 0 $false
    $c2 = rightPromptGit $c1 $true
    rightPromptLastCommandTime $c2 $true | Out-Null
}

function local:hasPrefix {
    param ([string] $a, [string] $b);
    ($b.Length -and $a.Length -gt $b.length -and $a.Substring(0, $b.Length) -eq $b);
}

function local:pathPrompt {
    param ([string] $locationIconColor, [string] $leaderColor);

    $quailifier = Split-Path -Path $pwd -Qualifier
    Write-Host $promptLeaderUpper -NoNewline -ForegroundColor $leaderColor
    Write-Host $quailifier -NoNewline -ForegroundColor $locationIconColor
    if (hasPrefix $pwd.Path $quailifier) {
        Write-Host ($pwd.Path.Substring($quailifier.Length)) -NoNewline -ForegroundColor Green
    }
}

function gitFancyPrompt {
    $realCommandStatus = $?
    $realLASTEXITCODE = $LASTEXITCODE

    if ( $realCommandStatus -eq $True ) {
        $exitStress = "Cyan"
    }
    else {
        $exitStress = "Red"
    }

    reservePromptSpace

    $locationIconColor = "Cyan"
    $locationIcon = $locationIconSet.unknown
    if ((get-location).Drive.Provider.Name -eq "FileSystem") {
        $locationIcon = $locationIconSet.dir
        $locationIconColor = "Yellow"
    }
    elseif ((get-location).Drive.Provider.Name -eq "Registry") {
        $locationIcon = $locationIconSet.registry
    }

    Write-Host $locationIcon -NoNewLine -ForegroundColor $locationIconColor
    moveCursor 0 (-1)

    $startposx = $Host.UI.RawUI.CursorPosition.X;
    $startposy = $Host.UI.RawUI.CursorPosition.Y + 1;

    pathPrompt $locationIconColor $exitStress
    rightPrompt
    
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startposx, $startposy
    Write-Host $promptLeader -NoNewLine -ForegroundColor $exitStress

    $global:LASTEXITCODE = $realLASTEXITCODE
    return " "
}

Export-ModuleMember -Function gitFancyPrompt
