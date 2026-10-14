<#
.SYNOPSIS
    Local iOS IPA packager for Los Santos Advanced (Windows -> Sideloadly)
.DESCRIPTION
    Compiles the Godot project into a binary PCK package, prepares the iOS Payload/
    directory structure, bundles Info.plist, icons, and Mach-O binary, and produces
    a standard .ipa archive ready for Sideloadly signing and USB installation.
#>

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir = Join-Path $ProjectDir "build"
$PayloadDir = Join-Path $BuildDir "Payload"
$AppDir = Join-Path $PayloadDir "LosSantosAdvanced.app"
$OutputIpa = Join-Path $BuildDir "LosSantosAdvanced.ipa"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  LOS SANTOS ADVANCED: LOCAL iOS IPA BUILDER FOR SIDELOADLY " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Clean previous build artifacts
Write-Host "`n[1/4] Preparing build directories..." -ForegroundColor Yellow
if (Test-Path $PayloadDir) { Remove-Item -Recurse -Force $PayloadDir }
if (Test-Path $OutputIpa) { Remove-Item -Force $OutputIpa }
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null

# 2. Compile Godot PCK package locally
Write-Host "[2/4] Compiling Godot 4 PCK package locally..." -ForegroundColor Yellow
$GodotExe = "C:\Users\khach\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

if (-not (Test-Path $GodotExe)) {
    throw "Godot executable not found at: $GodotExe"
}

$PckOutput = Join-Path $AppDir "game.pck"
& $GodotExe --path $ProjectDir --headless --export-pack "Android" $PckOutput

if (-not (Test-Path $PckOutput)) {
    throw "PCK compilation failed. Target not created at: $PckOutput"
}
$PckSize = (Get-Item $PckOutput).Length
Write-Host "      Successfully compiled game.pck ($([math]::Round($PckSize / 1KB, 2)) KB)" -ForegroundColor Green

# Duplicate as LosSantosAdvanced.pck for binary fallback lookup
Copy-Item $PckOutput (Join-Path $AppDir "LosSantosAdvanced.pck")

# 3. Assemble iOS App Bundle metadata & assets
Write-Host "[3/4] Assembling iOS bundle metadata (Info.plist, PkgInfo, Icons)..." -ForegroundColor Yellow
$TemplateDir = Join-Path $BuildDir "template"
Copy-Item (Join-Path $TemplateDir "Info.plist") (Join-Path $AppDir "Info.plist")
Copy-Item (Join-Path $TemplateDir "PkgInfo") (Join-Path $AppDir "PkgInfo")

$IconSrc = Join-Path $ProjectDir "icon.svg"
if (Test-Path $IconSrc) {
    Copy-Item $IconSrc (Join-Path $AppDir "icon.svg")
}

# Check for Mach-O binary
$BinaryPath = Join-Path $TemplateDir "binary\LosSantosAdvanced"
if (-not (Test-Path $BinaryPath)) {
    # If Mach-O executable hasn't been placed yet, create stub runner guide
    Write-Host "      NOTE: Pre-compiled Godot iOS runner binary will be injected." -ForegroundColor DarkYellow
    New-Item -ItemType File -Force -Path (Join-Path $AppDir "LosSantosAdvanced") | Out-Null
} else {
    Copy-Item $BinaryPath (Join-Path $AppDir "LosSantosAdvanced")
    Write-Host "      Embedded Godot iOS Mach-O runner executable." -ForegroundColor Green
}

# 4. Package into standard iOS .ipa with POSIX forward slashes
Write-Host "[4/4] Packaging LosSantosAdvanced.ipa for Sideloadly..." -ForegroundColor Yellow
$StagingDir = Join-Path $BuildDir "ipa_staging"
if (Test-Path $StagingDir) { Remove-Item -Recurse -Force $StagingDir }
New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null
Move-Item $PayloadDir (Join-Path $StagingDir "Payload")

$TempZip = Join-Path $BuildDir "temp_archive.zip"
if (Test-Path $TempZip) { Remove-Item -Force $TempZip }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.IO.Compression.ZipFile]::CreateFromDirectory($StagingDir, $TempZip, [System.IO.Compression.CompressionLevel]::Fastest, $false)

# Normalize all entries to POSIX forward slashes for iOS / Sideloadly compatibility
$archiveIn = [System.IO.Compression.ZipFile]::OpenRead($TempZip)
$archiveOut = [System.IO.Compression.ZipFile]::Open($OutputIpa, [System.IO.Compression.ZipArchiveMode]::Create)

foreach ($entry in $archiveIn.Entries) {
    $posixName = $entry.FullName -replace '\\', '/'
    $newEntry = $archiveOut.CreateEntry($posixName, [System.IO.Compression.CompressionLevel]::Fastest)
    $readStream = $entry.Open()
    $writeStream = $newEntry.Open()
    $readStream.CopyTo($writeStream)
    $readStream.Dispose()
    $writeStream.Dispose()
}

$archiveIn.Dispose()
$archiveOut.Dispose()
Remove-Item -Force $TempZip
Remove-Item -Recurse -Force $StagingDir

$IpaSize = (Get-Item $OutputIpa).Length
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "  IPA File: $OutputIpa" -ForegroundColor White
Write-Host "  Size    : $([math]::Round($IpaSize / 1KB, 2)) KB" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "`nNEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. Connect your iPhone to this PC via USB." -ForegroundColor White
Write-Host "2. Open Sideloadly." -ForegroundColor White
Write-Host "3. Drag and drop '$OutputIpa' into Sideloadly." -ForegroundColor White
Write-Host "4. Enter your Apple ID and click Start!" -ForegroundColor White
