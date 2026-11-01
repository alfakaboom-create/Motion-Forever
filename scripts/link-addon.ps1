# Links the addon folder in this repo into your WoW AddOns folder, so the
# game loads it straight from the repo. Edit, type /reload in game, done.
#
# Usage (pass the folder that contains "Interface"):
#   .\scripts\link-addon.ps1 -WowPath "C:\Program Files (x86)\World of Warcraft\_retail_"
#
# Uses a directory junction, which doesn't need admin rights.

param(
    [Parameter(Mandatory = $true)]
    [string]$WowPath
)

$ErrorActionPreference = "Stop"

$source = (Resolve-Path (Join-Path $PSScriptRoot "..\Motion-Forever")).Path
$addonsDir = Join-Path $WowPath "Interface\AddOns"
$target = Join-Path $addonsDir "Motion-Forever"

if (-not (Test-Path $WowPath)) {
    Write-Error "WoW folder not found: $WowPath"
}

if (-not (Test-Path $addonsDir)) {
    New-Item -ItemType Directory -Force -Path $addonsDir | Out-Null
}

if (Test-Path $target) {
    $item = Get-Item $target -Force
    if ($item.LinkType) {
        Write-Host "Already linked: $target -> $($item.Target)"
        exit 0
    }
    Write-Error "A normal Motion-Forever folder already exists at $target. Move or delete it, then run this again."
}

New-Item -ItemType Junction -Path $target -Target $source | Out-Null
Write-Host "Linked $target -> $source"
