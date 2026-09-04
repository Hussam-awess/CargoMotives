# Starts the portable Redis-for-Windows server used for local dev on this
# machine (Docker/WSL2 isn't available here — see README.md "Local
# development setup"). Not a Windows service: it runs as a plain foreground
# process, so it needs to be (re)started after each reboot or terminal close.
#
# Usage: powershell -File .local-services\start-redis.ps1

$ErrorActionPreference = "Stop"
$redisDir = Join-Path $PSScriptRoot "redis"

if (-not (Test-Path (Join-Path $redisDir "redis-server.exe"))) {
    throw "redis-server.exe not found in $redisDir — see README.md to (re)download the portable Redis build."
}

Set-Location $redisDir
Write-Output "Starting Redis on 127.0.0.1:6379 (Ctrl+C to stop)..."
& .\redis-server.exe redis.windows.conf --port 6379
