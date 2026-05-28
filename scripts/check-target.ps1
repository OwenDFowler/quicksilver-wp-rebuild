[CmdletBinding()]
param(
    [string]$BaseUrl = $env:WORDPRESS_BASE_URL
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = 'https://wordpress-production-49a8.up.railway.app'
}

$BaseUrl = $BaseUrl.TrimEnd('/')
$routes = @('/', '/wp-json/', '/wp-json/wp/v2/types')

foreach ($route in $routes) {
    $url = "$BaseUrl$route"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 30

    if ($response.StatusCode -ne 200) {
        throw "Unexpected HTTP $($response.StatusCode) for $url"
    }

    $title = ([regex]'<title>(.*?)</title>').Match($response.Content).Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = '(no title)'
    }

    [pscustomobject]@{
        Url = $url
        Status = $response.StatusCode
        Title = $title
    }
}
