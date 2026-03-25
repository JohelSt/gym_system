param(
  [switch]$NoPubGet
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildWebPath = Join-Path $projectRoot "build\web"
$vercelConfigPath = Join-Path $buildWebPath "vercel.json"

Set-Location $projectRoot

if (-not $NoPubGet) {
  flutter pub get
}

flutter build web --release

$vercelConfig = @'
{
  "cleanUrls": true,
  "trailingSlash": false,
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/flutter_service_worker.js",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "no-cache"
        }
      ]
    },
    {
      "source": "/firebase-messaging-sw.js",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "no-cache"
        }
      ]
    }
  ]
}
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
  $vercelConfigPath,
  $vercelConfig,
  $utf8NoBom
)

Write-Host ""
Write-Host "Flutter web listo para Vercel en: $buildWebPath" -ForegroundColor Green
Write-Host "Archivo generado: $vercelConfigPath" -ForegroundColor Green
Write-Host ""
Write-Host "Siguiente paso:" -ForegroundColor Cyan
Write-Host "  cd build/web"
Write-Host "  vercel"
Write-Host "  vercel --prod"
