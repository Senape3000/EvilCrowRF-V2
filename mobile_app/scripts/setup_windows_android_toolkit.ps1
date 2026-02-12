<#
setup_windows_android_toolkit.ps1

Simple, robust setup script to prepare Android SDK components for Flutter on Windows.

This script will:
- Check for Java (prompt if missing)
- Ensure Android SDK root exists
- Ensure Android command-line tools are present (download if missing)
- Install platform-tools, build-tools and platforms only if absent
- Try to accept SDK licenses or instruct user to do so
- Update android/local.properties with sdk.dir

Usage: run from project root: .\scripts\setup_windows_android_toolkit.ps1
#>

param(
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$CmdlineToolsUrl = 'https://dl.google.com/android/repository/commandlinetools-win-9477386_latest.zip',
    [string]$AndroidPlatforms = 'android-33',
    [string]$BuildToolsVersion = '33.0.2'
)

function Write-Heading([string]$s){ Write-Host "`n== $s ==`n" -ForegroundColor Cyan }

Write-Heading "Check Java"
$javaResult = & java -version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Java not found in PATH. Install OpenJDK 11 (Temurin) and re-run." -ForegroundColor Yellow
    Write-Host "Example with winget: winget install -e --id Eclipse.Temurin.11" -ForegroundColor Gray
    Read-Host "Press Enter after installing Java to continue, or Ctrl+C to abort"
} else {
    Write-Host "Java detected:" -ForegroundColor Green
    Write-Host $javaResult
}

Write-Heading "Ensure SDK root"
if (!(Test-Path -Path $SdkRoot)) { New-Item -ItemType Directory -Path $SdkRoot -Force | Out-Null; Write-Host "Created $SdkRoot" }

$tmpZip = Join-Path $env:TEMP "cmdline-tools.zip"

Write-Host "Checking for command-line tools..."
$cmdlineDir = Join-Path $SdkRoot 'cmdline-tools'
$cmdlineLatest = Join-Path $cmdlineDir 'latest'

if (Test-Path (Join-Path $cmdlineLatest 'bin\sdkmanager.bat')) {
    Write-Host "Command-line tools found at: $cmdlineLatest" -ForegroundColor Green
} else {
    Write-Host "Command-line tools not found. Downloading from $CmdlineToolsUrl"
    try { Invoke-WebRequest -Uri $CmdlineToolsUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop } catch { Write-Error "Download failed: $_.Exception.Message"; exit 1 }
    if (Test-Path $cmdlineLatest) { Remove-Item -Recurse -Force $cmdlineLatest }
    New-Item -ItemType Directory -Path $cmdlineLatest -Force | Out-Null
    Expand-Archive -Path $tmpZip -DestinationPath $env:TEMP -Force
    $extracted = Join-Path $env:TEMP 'cmdline-tools'
    if (Test-Path $extracted) { Get-ChildItem -Path $extracted | ForEach-Object { Move-Item -Path $_.FullName -Destination $cmdlineLatest } ; Remove-Item -Recurse -Force $extracted }
    Remove-Item -Force $tmpZip
    Write-Host "Command-line tools installed to: $cmdlineLatest" -ForegroundColor Green
}

$sdkmanager = Join-Path (Join-Path $cmdlineLatest 'bin') 'sdkmanager.bat'
if (!(Test-Path $sdkmanager)) { Write-Error "sdkmanager not found at expected path: $sdkmanager"; exit 1 }

Write-Host "Updating PATH for this session"
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:PATH = $env:PATH + ';' + (Join-Path $SdkRoot 'platform-tools') + ';' + (Join-Path $cmdlineLatest 'bin')

Write-Heading "Install missing SDK components"
$toInstall = @()
if (!(Test-Path (Join-Path $SdkRoot 'platform-tools'))) { $toInstall += 'platform-tools' }
if (!(Test-Path (Join-Path $SdkRoot ("build-tools/$BuildToolsVersion")))) { $toInstall += "build-tools;${BuildToolsVersion}" }
if (!(Test-Path (Join-Path $SdkRoot ("platforms/$AndroidPlatforms")))) { $toInstall += "platforms;${AndroidPlatforms}" }

if ($toInstall.Count -eq 0) {
    Write-Host "All required components present. Nothing to install." -ForegroundColor Green
} else {
    Write-Host ("Installing: " + ($toInstall -join ', '))
    & $sdkmanager --sdk_root=$SdkRoot $toInstall --verbose
}

Write-Heading "Accept licenses"
try {
    & $sdkmanager --sdk_root=$SdkRoot --licenses | Out-Null
    Write-Host "SDK licenses accepted (if any)." -ForegroundColor Green
} catch {
    Write-Warning "Could not accept all licenses automatically. Run: & $sdkmanager --licenses and accept manually if prompted."
}

Write-Heading "Update android/local.properties"
$projectRoot = (Get-Location).Path
# Find the project root by looking for android directory
while (!(Test-Path (Join-Path $projectRoot 'android'))) {
    $parent = Split-Path $projectRoot -Parent
    if ($null -eq $parent -or $parent -eq $projectRoot) {
        Write-Error "Could not find android directory in project hierarchy. Current dir: $projectRoot"
        exit 1
    }
    $projectRoot = $parent
}
$localPropsFile = Join-Path $projectRoot 'android\local.properties'
$sdkDirValue = $SdkRoot -replace '\\','/'
if (Test-Path $localPropsFile) {
    $lines = Get-Content $localPropsFile | Where-Object { $_ -notmatch '^sdk.dir=' }
    $lines += "sdk.dir=$sdkDirValue"
    Set-Content -Path $localPropsFile -Value $lines -Encoding UTF8
    Write-Host "Updated $localPropsFile"
} else {
    Set-Content -Path $localPropsFile -Value @("sdk.dir=$sdkDirValue") -Encoding UTF8
    Write-Host "Created $localPropsFile"
}

Write-Host "Done. SDK root: $SdkRoot" -ForegroundColor Green
Exit 0
