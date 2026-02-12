@echo off
setlocal

echo Setting up Android SDK...
powershell -ExecutionPolicy Bypass -File scripts\setup_windows_android_toolkit.ps1
if %errorlevel% neq 0 goto error

echo Setting environment variables...
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\tools;%ANDROID_HOME%\tools\bin;%ANDROID_HOME%\cmdline-tools\latest\bin

echo Installing dependencies...
powershell -ExecutionPolicy Bypass -File scripts\install.ps1
if %errorlevel% neq 0 goto error

echo Building APK...
flutter build apk --release
if %errorlevel% neq 0 goto error

echo APK built successfully!
echo APK location: build\app\outputs\flutter-apk\app-release.apk
goto end

:error
echo An error occurred during the build process.
echo Check the output above for details.

:end
echo.
echo Press any key to exit...
pause >nul