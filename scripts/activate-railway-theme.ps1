[CmdletBinding()]
param(
    [string]$RailwayDir,

    [string]$ProjectId = '9680e4f9-863d-4987-92f5-bcb2d643331a',

    [string]$Environment = 'production',

    [string]$Service = 'WordPress',

    [string]$IdentityFile,

    [switch]$ConfirmActivation
)

$ErrorActionPreference = 'Stop'

$ThemeSlug = 'quicksilver-construction'

if (-not $ConfirmActivation) {
    throw "Theme activation is a WordPress DB write. Re-run with -ConfirmActivation after verifying the target and accepting that the script will capture and print a rollback command."
}

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

$currentActiveTheme = & $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('theme', 'list', '--status=active', '--field=name')
if (@($currentActiveTheme).Count -ne 1 -or [string]::IsNullOrWhiteSpace($currentActiveTheme[0])) {
    throw "Expected exactly one active theme before activation."
}

& $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('theme', 'is-installed', $ThemeSlug)
& $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('theme', 'activate', $ThemeSlug)
$themeStatus = & $PSScriptRoot\railway-wp-cli.ps1 @common -WpArgs @('theme', 'status', $ThemeSlug)

[pscustomobject]@{
    ActivatedTheme = $ThemeSlug
    PreviousActiveTheme = $currentActiveTheme[0]
    ThemeStatus = ($themeStatus -join "`n")
    RollbackCommand = ".\scripts\railway-wp-cli.ps1 theme activate $($currentActiveTheme[0])"
}
