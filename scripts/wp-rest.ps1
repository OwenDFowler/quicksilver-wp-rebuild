[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
    [string]$Method = 'GET',

    [string]$BodyJson,

    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $RepoRoot '.env.local'
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing local env file: $EnvFile"
}

$values = @{}
Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#')) {
        return
    }

    $parts = $line.Split('=', 2)
    if ($parts.Count -ne 2) {
        throw "Invalid env line: $line"
    }

    $values[$parts[0]] = $parts[1]
}

$baseUrl = $values['WORDPRESS_BASE_URL']
$username = $values['WORDPRESS_USERNAME']
$appPassword = $values['WORDPRESS_APPLICATION_PASSWORD']

if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($appPassword)) {
    throw "WORDPRESS_BASE_URL, WORDPRESS_USERNAME, and WORDPRESS_APPLICATION_PASSWORD must all be set in .env.local."
}

$baseUrl = $baseUrl.TrimEnd('/')
$restPath = $Path.TrimStart('/')
if (-not $restPath.StartsWith('wp-json/')) {
    $restPath = "wp-json/$restPath"
}

$normalizedPassword = ($appPassword -replace '\s+', '')
$tokenBytes = [System.Text.Encoding]::UTF8.GetBytes("${username}:${normalizedPassword}")
$headers = @{
    Authorization = 'Basic ' + [Convert]::ToBase64String($tokenBytes)
}

$request = @{
    Uri = "$baseUrl/$restPath"
    Headers = $headers
    Method = $Method
}

if (-not [string]::IsNullOrWhiteSpace($BodyJson)) {
    $request['Body'] = $BodyJson
    $request['ContentType'] = 'application/json'
}

Invoke-RestMethod @request
