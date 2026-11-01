# Builds dist\Motion-Forever-<version>.zip, ready to share or upload.
# The version is read from Motion-Forever.toc.
#
# Usage:  .\scripts\package.ps1

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$addon = Join-Path $root "Motion-Forever"
$toc = Join-Path $addon "Motion-Forever.toc"

$versionLine = Select-String -Path $toc -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) { Write-Error "No '## Version:' line in $toc" }
$version = $versionLine.Matches[0].Groups[1].Value.Trim()

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist "Motion-Forever-$version.zip"
if (Test-Path $zip) { Remove-Item $zip -Confirm:$false }

# Zipping the folder itself keeps "Motion-Forever\" at the top of the zip,
# which is what players expect to drop into Interface\AddOns.
Compress-Archive -Path $addon -DestinationPath $zip
Write-Host "Created $zip"
