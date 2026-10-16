<#
.SYNOPSIS
    Builds Last Battle Royale into a .gma and publishes / updates it on the Steam Workshop.

.EXAMPLE
    .\publish.ps1 -BuildOnly
    .\publish.ps1 -Changes "Fixed zone damage"
    .\publish.ps1 -Changes "New icon" -UpdateIcon
#>
param(
    # Changelog shown on the Workshop page (used when updating)
    [string]$Changes = "",
    # Only build the .gma, do not upload
    [switch]$BuildOnly,
    # Also replace the Workshop icon when updating
    [switch]$UpdateIcon,
    # Garry's Mod install folder (auto-detected from Steam if omitted)
    [string]$GModPath = ""
)

$ErrorActionPreference = "Stop"

$PublishDir = $PSScriptRoot
$RepoRoot   = Split-Path $PublishDir -Parent
$OutDir     = Join-Path $PublishDir "out"
$GmaPath    = Join-Path $OutDir "lastbattleroyale.gma"
$IconPath   = Join-Path $PublishDir "icon.jpg"
$IdFile     = Join-Path $PublishDir "workshop_id.txt"

function Find-GMod {
    if ($GModPath) { return $GModPath }

    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
    if (!$steam) { throw "Steam not found. Pass -GModPath 'X:\...\GarrysMod'." }

    $libraries = @($steam -replace '/', '\')
    $vdf = Join-Path $libraries[0] "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        Select-String -Path $vdf -Pattern '"path"\s+"(.+)"' | ForEach-Object {
            $libraries += $_.Matches[0].Groups[1].Value -replace '\\\\', '\'
        }
    }

    foreach ($lib in $libraries) {
        $candidate = Join-Path $lib "steamapps\common\GarrysMod"
        if (Test-Path (Join-Path $candidate "bin\gmad.exe")) { return $candidate }
    }
    throw "Garry's Mod not found in Steam libraries. Pass -GModPath 'X:\...\GarrysMod'."
}

function Test-Icon {
    if (!(Test-Path $IconPath)) { throw "Missing $IconPath (512x512 JPG)." }
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($IconPath)
    try {
        $isJpeg = $img.RawFormat.Equals([System.Drawing.Imaging.ImageFormat]::Jpeg)
        if (!$isJpeg -or $img.Width -ne 512 -or $img.Height -ne 512) {
            throw "icon.jpg must be a 512x512 JPEG (found $($img.Width)x$($img.Height), jpeg=$isJpeg)."
        }
    } finally { $img.Dispose() }
}

$gmod       = Find-GMod
$gmad       = Join-Path $gmod "bin\gmad.exe"
$gmpublish  = Join-Path $gmod "bin\gmpublish.exe"
Write-Host "Garry's Mod: $gmod"

# addon.json sanity check (title, type, tags)
$addon = Get-Content (Join-Path $RepoRoot "addon.json") -Raw | ConvertFrom-Json
if (!$addon.title -or !$addon.type) { throw "addon.json needs 'title' and 'type'." }
if (@($addon.tags).Count -gt 2) { throw "addon.json: Workshop allows at most 2 tags." }
Write-Host "Addon: $($addon.title) [$($addon.type)] tags: $(@($addon.tags) -join ', ')"

# Build
New-Item -ItemType Directory -Force $OutDir | Out-Null
if (Test-Path $GmaPath) { Remove-Item $GmaPath }
& $gmad create -folder $RepoRoot -out $GmaPath
if ($LASTEXITCODE -ne 0 -or !(Test-Path $GmaPath)) { throw "gmad failed." }
Write-Host "Built: $GmaPath" -ForegroundColor Green

if ($BuildOnly) { return }

Test-Icon
Write-Host "Steam must be running and logged in with the account that owns the addon."

$workshopId = if (Test-Path $IdFile) { (Get-Content $IdFile -Raw).Trim() } else { "" }

if ($workshopId) {
    # Update existing Workshop item
    if (!$Changes) { $Changes = Read-Host "Changelog for this update" }
    $publishArgs = @("update", "-addon", $GmaPath, "-id", $workshopId, "-changes", $Changes)
    if ($UpdateIcon) { $publishArgs += @("-icon", $IconPath) }
    & $gmpublish @publishArgs
    if ($LASTEXITCODE -ne 0) { throw "gmpublish update failed." }
    Write-Host "Updated: https://steamcommunity.com/sharedfiles/filedetails/?id=$workshopId" -ForegroundColor Green
} else {
    # First upload: create the Workshop item and remember its ID
    $output = & $gmpublish create -addon $GmaPath -icon $IconPath 2>&1 | Tee-Object -Variable log
    if ($LASTEXITCODE -ne 0) { throw "gmpublish create failed." }

    $match = [regex]::Match(($log -join "`n"), '(?:UID|id)\D{0,5}(\d{6,})', 'IgnoreCase')
    if ($match.Success) {
        $match.Groups[1].Value | Set-Content $IdFile -NoNewline
        Write-Host "Created: https://steamcommunity.com/sharedfiles/filedetails/?id=$($match.Groups[1].Value)" -ForegroundColor Green
        Write-Host "Saved the ID to publish\workshop_id.txt - commit it so future runs update instead of creating."
    } else {
        Write-Warning "Could not read the Workshop ID from the output. Copy it from the Workshop URL into publish\workshop_id.txt."
    }
    Write-Host "New items are uploaded as HIDDEN: open the page to set description, screenshots and visibility."
}
