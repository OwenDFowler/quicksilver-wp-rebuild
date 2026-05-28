[CmdletBinding()]
param(
    [string]$RailwayDir
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RailwayDir)) {
    $RailwayDir = Join-Path (Split-Path -Parent $RepoRoot) 'quicksilver-wp-railway'
}

if (-not (Test-Path -LiteralPath $RailwayDir)) {
    throw "Railway link directory not found: $RailwayDir"
}

Push-Location $RailwayDir
try {
    railway service list --json
    railway volume list --json
}
finally {
    Pop-Location
}
