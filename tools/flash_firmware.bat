@echo off
setlocal enabledelayedexpansion
echo ========================================
echo ESP32 Firmware Flash Tool
echo ========================================
echo.

REM Set venv path
set VENV_DIR=%~dp0.venv
set PYTHON_EXE=%VENV_DIR%\Scripts\python.exe

REM Use LOCAL PlatformIO core
set PLATFORMIO_CORE_DIR=%~dp0.pio_core

REM Check if venv exists
if not exist "%PYTHON_EXE%" (
    echo ERROR: Virtual environment not found!
    echo Please run build_production.bat first to setup the environment.
    pause
    exit /b 1
)

echo Using Python from virtual environment...
"%PYTHON_EXE%" --version
echo.

REM Check if PlatformIO is installed
"%PYTHON_EXE%" -m pip show platformio >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: PlatformIO not found in virtual environment!
    echo Please run build_production.bat first.
    pause
    exit /b 1
)

REM Check if firmware exists
set FIRMWARE_FILE=.pio\build\esp32dev\firmware.bin
if not exist "%FIRMWARE_FILE%" (
    echo ERROR: Firmware not found at %FIRMWARE_FILE%
    echo Please build the firmware first with build_production.bat
    pause
    exit /b 1
)

echo Firmware found: %FIRMWARE_FILE%
for %%A in ("%FIRMWARE_FILE%") do echo Firmware size: %%~zA bytes
echo.

REM List available serial ports
echo Detecting available serial ports...
"%PYTHON_EXE%" -m platformio device list
echo.

REM Ask user for upload method
echo Upload Options:
echo   1. Auto-detect serial port (recommended)
echo   2. Specify port manually
echo   3. Cancel
echo.
set /p UPLOAD_CHOICE="Select option (1-3): "

if "%UPLOAD_CHOICE%"=="3" (
    echo Upload cancelled.
    pause
    exit /b 0
)

if "%UPLOAD_CHOICE%"=="2" (
    echo.
    set /p UPLOAD_PORT="Enter COM port (e.g., COM3): "
    echo Uploading firmware to !UPLOAD_PORT!...
    "%PYTHON_EXE%" -m platformio run -e esp32dev -t upload --upload-port !UPLOAD_PORT!
) else (
    echo Auto-detecting serial port and uploading firmware...
    echo.
    echo IMPORTANT: Make sure your ESP32 is connected via USB!
    echo Some boards may require holding the BOOT button during upload.
    echo.
    pause
    "%PYTHON_EXE%" -m platformio run -e esp32dev -t upload
)

if !errorlevel! neq 0 (
    echo.
    echo ========================================
    echo ERROR: Firmware upload failed!
    echo ========================================
    echo.
    echo Troubleshooting tips:
    echo   1. Check USB cable connection
    echo   2. Try holding BOOT button on ESP32
    echo   3. Check device manager for COM port
    echo   4. Try a different USB port
    echo   5. Install CH340/CP2102 drivers if needed
    echo.
    pause
    exit /b !errorlevel!
)

echo.
echo ========================================
echo Firmware uploaded successfully!
echo ========================================
echo.
echo You can now open the serial monitor with:
echo   monitor_serial.bat
echo.
pause
