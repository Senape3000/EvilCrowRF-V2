@echo off
echo ========================================
echo    EvilCrow-RF-V2 Mobile App Tester
echo ========================================
echo.
echo Select preview option:
echo 1. Desktop (Windows) - Fast native preview
echo 2. Android Emulator - Real Android simulation
echo 3. Web (Chrome) - Browser preview
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto desktop
if "%choice%"=="2" goto emulator
if "%choice%"=="3" goto web
echo Invalid choice. Exiting.
pause
exit /b 1

:desktop
echo.
echo === Setting up for Desktop Preview ===
powershell -ExecutionPolicy Bypass -File scripts\setup_windows_android_toolkit.ps1 >nul 2>&1
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\tools;%ANDROID_HOME%\tools\bin;%ANDROID_HOME%\cmdline-tools\latest\bin
powershell -ExecutionPolicy Bypass -File scripts\install.ps1 >nul 2>&1
echo.
echo === Launching App on Desktop ===
flutter run -d windows
goto end

:emulator
echo.
echo === Setting up for Android Emulator ===
powershell -ExecutionPolicy Bypass -File scripts\setup_windows_android_toolkit.ps1 >nul 2>&1
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\tools;%ANDROID_HOME%\tools\bin;%ANDROID_HOME%\cmdline-tools\latest\bin
powershell -ExecutionPolicy Bypass -File scripts\install.ps1 >nul 2>&1
echo.
echo === Checking Available Emulators ===
flutter emulators
echo.
set EMULATOR_COUNT=
for /f %%c in ('powershell -Command "$output = flutter emulators; if ($output -match ''(\d+) available emulator'') { $matches[1] } else { 0 }"') do set EMULATOR_COUNT=%%c
if "%EMULATOR_COUNT%"=="0" (
    set /p install="No emulators found. Do you want to install a default emulator? (Y/n): "
    if /i "!install!"=="y" (
        echo Installing system image...
        call "%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat" "system-images;android-33;google_apis;x86_64" --verbose
        echo Creating emulator...
        echo | call "%ANDROID_HOME%\cmdline-tools\latest\bin\avdmanager.bat" create avd -n Default_Emulator -k "system-images;android-33;google_apis;x86_64" --force
        echo Emulator installed. Checking again...
        flutter emulators
    ) else (
        echo Exiting.
        pause
        exit /b 1
    )
)
echo.
echo === Launching Android Emulator ===
echo Note: If no emulator is available, create one first with Android Studio.
set EMULATOR_ID=
for /f "tokens=*" %%i in ('powershell -Command "flutter emulators | ConvertFrom-Csv -Delimiter '•' -Header Id,Name,Manufacturer,Platform | Select-Object -First 1 -ExpandProperty Id"') do set EMULATOR_ID=%%i
if "%EMULATOR_ID%"=="" (
    echo No emulator found. Please ensure an Android emulator is created and available.
    echo You can create one in Android Studio: Tools > Device Manager
    pause
    exit /b 1
)
flutter emulators --launch %EMULATOR_ID% 2>nul || (
    echo Failed to launch emulator %EMULATOR_ID%.
    pause
    exit /b 1
)
timeout /t 10 /nobreak >nul
echo.
echo === Launching App on Android Emulator ===
flutter run -d %EMULATOR_ID%
goto end

:web
echo.
echo === Setting up for Web Preview ===
powershell -ExecutionPolicy Bypass -File scripts\install.ps1 >nul 2>&1
echo.
echo === Launching App on Web (Chrome) ===
flutter run -d chrome
goto end

:end
echo.
echo App preview completed.
pause