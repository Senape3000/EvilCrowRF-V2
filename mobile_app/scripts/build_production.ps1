# Build Flutter app in production/release mode
Write-Host "Building Flutter app in RELEASE mode..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "APK location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
Write-Host ""

