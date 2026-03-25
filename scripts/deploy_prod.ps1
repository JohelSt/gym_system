param(
  [switch]$NoPubGet
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildWebPath = Join-Path $projectRoot "build\web"
$prepareScript = Join-Path $PSScriptRoot "prepare_vercel_web.ps1"

Set-Location $projectRoot

if ($NoPubGet) {
  powershell -ExecutionPolicy Bypass -File $prepareScript -NoPubGet
} else {
  powershell -ExecutionPolicy Bypass -File $prepareScript
}

Set-Location $buildWebPath
vercel --prod
