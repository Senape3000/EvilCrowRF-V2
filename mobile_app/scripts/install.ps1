# Evil Crow RF v2 Mobile App - Flutter Dependencies Installer
# PowerShell Script

Write-Host "Installing Flutter dependencies for Evil Crow RF v2 Mobile App..." -ForegroundColor Green
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Flutter found:" -ForegroundColor Green
        Write-Host $flutterVersion -ForegroundColor Cyan
        Write-Host ""
    } else {
        throw "Flutter not found"
    }
} catch {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter from https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Check Flutter doctor
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
flutter doctor

Write-Host ""
Write-Host "Installing dependencies..." -ForegroundColor Yellow

# Install dependencies
flutter pub get

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Dependencies installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run the app:" -ForegroundColor Cyan
    Write-Host "1. Connect your Android device or start an emulator" -ForegroundColor White
    Write-Host "2. Run: flutter run" -ForegroundColor White
    Write-Host ""
    Write-Host "To build APK:" -ForegroundColor Cyan
    Write-Host "Run: flutter build apk" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to install dependencies" -ForegroundColor Red
    Write-Host ""
}

Read-Host "Press Enter to exit (or continue)"

