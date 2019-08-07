function InstallAndLoadModule {
    param([string]$name)
    if (-not(Get-Module -ListAvailable -Name $name)) {
        Write-Host "  Module $name is absent > Install to current user.  " -ForegroundColor Black -BackgroundColor Yellow
        Install-Module $name -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $name
}

Export-ModuleMember -Function InstallAndLoadModule
