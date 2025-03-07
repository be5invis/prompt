﻿##########################################################################
# Configuration

$rightPromptGutterSymbol = " ┆ "
$rightPromptGutterSymbolWidth = 3
$gitBranch = @{
    symbol = ""
    width = 1
}
$gitChangeSymbol = @{
    working = "●";
    indexed = "○";
    both    = "◉";
    width   = 1;
}
$gitAheadBehind = @{
    ahead = " ↑"
    behind = " ↓"
    width = 2
}
$promptLeaderUpper = ""
$promptLeader = "┖▶"
$locationIconSet = @{
    unknown = " ┌─┐ `n └─┘ "
    dir = " ┌─┐ `n └─╜ "
    registry = " ┌╥╖ `n └╨╜ "
}
$longCommandTime = 5 # in seconds
$HGutterChar = "─"

$Purple = "`e[38;5;105m"
$ResetColor = "`e[0m"

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
    $startPosX = $Host.UI.RawUI.windowsize.width - $rightCharCount
    $startPosY = $Host.UI.RawUI.CursorPosition.Y
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startPosX, $startPosY
}

function local:moveCursor {
    param ([int] $deltaX, [int] $deltaY);
    $startPosX = $Host.UI.RawUI.CursorPosition.X + $deltaX;
    $startPosY = $Host.UI.RawUI.CursorPosition.Y + $deltaY;
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startPosX, $startPosY
}

function local:reservePromptSpace {
    $startPosX = $Host.UI.RawUI.CursorPosition.X
    Write-Host "`n"
    $startPosY = $Host.UI.RawUI.CursorPosition.Y
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startPosX, ($startPosY - 1)
}

$local:userName = $env:UserName
$local:isAdmin = (Test-Administrator)
$local:userBadgeColor = "Blue"
if ($isAdmin) {
    $userBadgeColor = "Red"
}

function local:rightPromptGutterWidth {
    param ([int] $startColumn);
    if ($startColumn -gt 0) {
        return $rightPromptGutterSymbolWidth
    } else {
        return 0
    }
}

function local:rightPromptGutter {
    param ([int] $startColumn);
    if ($startColumn -gt 0) {
        Write-Host $rightPromptGutterSymbol -NoNewline -ForegroundColor DarkGray
    }
}

function local:rightPromptUser {
    param ([int] $startColumn);
    
    if (-not $isAdmin) { return $startColumn; }
    
    $userBadgeText = $userName
    $userBadgeTextWidth = $userBadgeText.Length
    
    $nextColumn = 1 + $startColumn + $userBadgeTextWidth + (rightPromptGutterWidth $startColumn)

    reserveRightSpace $nextColumn
    Write-Host $userBadgeText -nonewline -foregroundcolor $userBadgeColor
    rightPromptGutter $startColumn

    return $nextColumn
}

function local:gitChangeWidth([int] $working, [int] $index) {
    if($working -gt 0 -or $index -gt 0) {
        return (1 + $gitChangeSymbol.width)
    } else {
        return 0
    }
}

function local:writeGitChangeSymbol([int] $working, [int] $index, [string] $color) {
    if($working -gt 0 -and $index -gt 0) {
        Write-Host (" " + $gitChangeSymbol.both) -NoNewline -ForegroundColor $color
    }
    elseif($working -gt 0 ) {
        Write-Host (" " + $gitChangeSymbol.working) -NoNewline -ForegroundColor $color
    }
    elseif($index -gt 0 ) {
        Write-Host (" " + $gitChangeSymbol.indexed) -NoNewline -ForegroundColor $color
    }
}

function local:rightPromptGit {
    param ([int] $startColumn);

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
        

        $nextColumn = $startColumn + $gitBranch.width + $git_branchNameWidth + $git_changesDisplayWidth + (rightPromptGutterWidth $startColumn)
        reserveRightSpace $nextColumn
        
        Write-Host $gitBranch.symbol -nonewline -foregroundcolor Blue
        Write-Host $git_branchName -nonewline
        writeGitChangeSymbol $status.Working.Added.Count    $status.Index.Added.Count    Green
        writeGitChangeSymbol $status.Working.Modified.Count $status.Index.Modified.Count Yellow
        writeGitChangeSymbol $status.Working.Deleted.Count  $status.Index.Deleted.Count  Red
        writeGitChangeSymbol $status.Working.Unmerged.Count $status.Index.Unmerged.Count Magenta
        if ($status.aheadBy -gt 0) { Write-Host $gitAheadBehind.ahead -NoNewLine -ForegroundColor Cyan }
        if ($status.behindBy -gt 0) { Write-Host $gitAheadBehind.behind -NoNewLine -ForegroundColor Cyan }
        rightPromptGutter $startColumn

        return $nextColumn
    }
    else {
        return $startColumn
    }
}

function local:rightPromptLastCommandTime {
    param ([int] $startColumn);

    $historyList = (Get-History)
    if ($null -eq $historyList) {
        return $startColumn
    }

    $lastCommand = $historyList[-1]    
    $duration = $lastCommand.EndExecutionTime - $lastCommand.StartExecutionTime
    if ($duration.totalSeconds -le $longCommandTime) {
        return $startColumn
    }

    $timeDisplay = "$([Math]::floor($duration.TotalSeconds))s"
    if ($duration.TotalMinutes -gt 2.0) {
        $timeDisplay = "$([Math]::floor($duration.TotalMinutes))m"
    }
    if ($duration.TotalHours -gt 2.0) {
        $timeDisplay = "$([Math]::floor($duration.TotalHours))h"
    }

    $nextColumn = $startColumn + $timeDisplay.Length + (rightPromptGutterWidth $startColumn)
    reserveRightSpace $nextColumn
    Write-Host $timeDisplay -NoNewline -ForegroundColor Yellow
    rightPromptGutter $startColumn

    return $nextColumn
}

function local:rightPromptSpace {
    param ([int] $startColumn);
    if ($startColumn -eq 0) {
        return $startColumn
    } else {
        $nextColumn = $startColumn + 1
        reserveRightSpace $nextColumn
        Write-Host " " -NoNewLine
        return $nextColumn
    }
}

function local:rightPrompt {
    $c1 = rightPromptUser            0
    $c2 = rightPromptGit             $c1
    $c3 = rightPromptLastCommandTime $c2
    rightPromptSpace $c3 | Out-Null
}

function local:hasPrefix {
    param ([string] $a, [string] $b);
    ($b.Length -and $a.Length -gt $b.length -and $a.Substring(0, $b.Length) -eq $b);
}

function local:hGutterPrompt {
    $str = ""
    $startPosX = $Host.UI.RawUI.CursorPosition.X;
    $startPosY = $Host.UI.RawUI.CursorPosition.Y;
    foreach ($n in (($startPosX + 1) .. ($Host.UI.RawUI.windowsize.width))) { $str += $HGutterChar }
    Write-Host $str -NoNewLine -ForegroundColor DarkGray
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startPosX, $startPosY
}

function local:pathPrompt {
    param ([string] $locationIconColor, [string] $leaderColor);

    $quailifier = Split-Path -Path $pwd -Qualifier
    Write-Host $promptLeaderUpper -NoNewline -ForegroundColor $leaderColor
    Write-Host $quailifier -NoNewline -ForegroundColor $locationIconColor
    if (hasPrefix $pwd.Path $quailifier) {
        Write-Host ($pwd.Path.Substring($quailifier.Length)) -NoNewline -ForegroundColor Green
    }
    Write-Host " " -NoNewLine
}

function gitFancyPrompt {
	# Reset prompt color
	if ((get-host).Name -eq "ConsoleHost") {
		Write-Host -NoNewLine $ResetColor # Hope the client supports ANSI
	}
	
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
    hGutterPrompt

    $startPosX = $Host.UI.RawUI.CursorPosition.X;
    $startPosY = $Host.UI.RawUI.CursorPosition.Y + 1;

    pathPrompt $locationIconColor $exitStress
    rightPrompt
    
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startPosX, $startPosY
   	if ((get-host).Name -eq "ConsoleHost") {
        Write-Host "$Purple$promptLeader$ResetColor" -NoNewLine
    } else {
        Write-Host $promptLeader -NoNewLine -ForegroundColor Cyan
    }
    $global:LASTEXITCODE = $realLASTEXITCODE
    return " "
}

Export-ModuleMember -Function gitFancyPrompt
