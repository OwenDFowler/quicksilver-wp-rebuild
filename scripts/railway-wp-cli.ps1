[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$WpArgs,

    [string]$RailwayDir,

    [string]$ProjectId = '9680e4f9-863d-4987-92f5-bcb2d643331a',

    [string]$Environment = 'production',

    [string]$Service = 'WordPress',

    [string]$IdentityFile,

    [string]$WordPressPath = '/var/www/html'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RailwayDir)) {
    $RailwayDir = Join-Path (Split-Path -Parent $RepoRoot) 'quicksilver-wp-railway'
}

if ([string]::IsNullOrWhiteSpace($IdentityFile)) {
    if ([string]::IsNullOrWhiteSpace($env:RAILWAY_SSH_IDENTITY_FILE)) {
        $IdentityFile = Join-Path $env:USERPROFILE '.ssh\id_ed25519_railway_quicksilver'
    }
    else {
        $IdentityFile = $env:RAILWAY_SSH_IDENTITY_FILE
    }
}

if ($null -eq $WpArgs -or $WpArgs.Count -eq 0) {
    throw "Pass a WP-CLI command, for example: scripts\railway-wp-cli.ps1 core is-installed"
}

if (-not (Test-Path -LiteralPath $RailwayDir -PathType Container)) {
    throw "Railway link directory not found: $RailwayDir"
}

if (-not (Test-Path -LiteralPath $IdentityFile -PathType Leaf)) {
    throw "Railway SSH identity file not found: $IdentityFile"
}

if ([string]::IsNullOrWhiteSpace($Service)) {
    throw "Railway WordPress service name is required."
}

if ([string]::IsNullOrWhiteSpace($WordPressPath)) {
    throw "WordPress path is required."
}

& $PSScriptRoot\assert-railway-wordpress-target.ps1 `
    -RailwayDir $RailwayDir `
    -ProjectId $ProjectId `
    -Environment $Environment `
    -Service $Service | Out-Null

$remoteArgs = @('wp', "--path=$WordPressPath", '--allow-root') + $WpArgs
$sshArgs = @('ssh', '--service', $Service, '--identity-file', $IdentityFile, '--') + $remoteArgs

Push-Location $RailwayDir
try {
    & railway @sshArgs
    if ($LASTEXITCODE -ne 0) {
        throw "WP-CLI command failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
