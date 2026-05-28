[CmdletBinding()]
param(
    [string]$RailwayDir,

    [string]$ProjectId = '9680e4f9-863d-4987-92f5-bcb2d643331a',

    [string]$Environment = 'production',

    [string]$Service = 'WordPress',

    [string]$IdentityFile
)

$ErrorActionPreference = 'Stop'

$common = @{
    ProjectId = $ProjectId
    Environment = $Environment
    Service = $Service
}

if (-not [string]::IsNullOrWhiteSpace($RailwayDir)) {
    $common['RailwayDir'] = $RailwayDir
}

if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
    $common['IdentityFile'] = $IdentityFile
}

$wpCliInfo = & $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('--info')
& $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('core', 'is-installed')
$siteUrl = & $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('option', 'get', 'siteurl')
$activeThemeJson = & $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('theme', 'list', '--status=active', '--fields=name,status,version', '--format=json')
$activeTheme = ($activeThemeJson -join "`n") | ConvertFrom-Json
& $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('theme', 'is-installed', 'quicksilver-construction')
$quicksilverThemeStatus = & $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('theme', 'status', 'quicksilver-construction')

[pscustomobject]@{
    WpCliAvailable = $true
    WpCliInfo = $wpCliInfo
    CoreInstalled = $true
    SiteUrl = ($siteUrl | Select-Object -Last 1)
    ActiveTheme = @($activeTheme)
    QuickSilverThemeStatus = ($quicksilverThemeStatus -join "`n")
}
