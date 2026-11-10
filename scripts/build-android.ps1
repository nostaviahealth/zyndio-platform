# PowerShell script to build Zyndio Android Release artifacts locally
Param(
    [switch]$BundleOnly,
    [switch]$ApkOnly
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$flutterAppDir = Join-Path $workspaceRoot "flutter_app"

Write-Host "=== Building Zyndio Android Release Artifacts ===" -ForegroundColor Cyan

# Set up local Java & Android paths if present
if (Test-Path "C:\Program Files\Android\Android Studio\jbr") {
    $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
    Write-Host "Configured JAVA_HOME: $env:JAVA_HOME" -ForegroundColor DarkGray
}

if (Test-Path "$env:LOCALAPPDATA\Android\Sdk") {
    $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
    Write-Host "Configured ANDROID_HOME: $env:ANDROID_HOME" -ForegroundColor DarkGray
}

# Add Flutter to path if found in Downloads
$flutterCandidates = @(
    "$env:USERPROFILE\Downloads\flutter_windows_3.47.8-stable\flutter\bin",
    "$env:USERPROFILE\Downloads\flutter_windows_3.38.5-stable\flutter\bin"
)
foreach ($candidate in $flutterCandidates) {
    if (Test-Path $candidate) {
        $env:PATH = "$candidate;$env:JAVA_HOME\bin;$env:PATH"
        Write-Host "Using Flutter at: $candidate" -ForegroundColor DarkGray
        break
    }
}

Set-Location $flutterAppDir

Write-Host "`n1. Running flutter pub get..." -ForegroundColor Yellow
flutter pub get

if (-not $BundleOnly) {
    Write-Host "`n2. Building Android Release APK..." -ForegroundColor Yellow
    flutter build apk --release --dart-define-from-file=dart_defines.json
    Write-Host "APK output: flutter_app/build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Green
}

if (-not $ApkOnly) {
    Write-Host "`n3. Building Google Play App Bundle (AAB)..." -ForegroundColor Yellow
    flutter build appbundle --release --dart-define-from-file=dart_defines.json
    Write-Host "AAB output: flutter_app/build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Green
}

Write-Host "`n=== Build Complete ===" -ForegroundColor Cyan
