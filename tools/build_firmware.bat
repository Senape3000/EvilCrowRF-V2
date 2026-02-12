@echo off
setlocal enabledelayedexpansion
echo ========================================
echo Building ESP32 Firmware
echo ========================================
echo.

REM Set venv path
set VENV_DIR=%~dp0.venv
set PYTHON_EXE=%VENV_DIR%\Scripts\python.exe

REM Use LOCAL PlatformIO core
set PLATFORMIO_CORE_DIR=%~dp0.pio_core

REM Check if venv already exists and is valid
if exist "%PYTHON_EXE%" (
    echo Virtual environment found. Checking Python version...
    for /f "tokens=2" %%i in ('"%PYTHON_EXE%" --version 2^>^&1') do set VENV_VERSION=%%i
    echo venv Python version: !VENV_VERSION!
    
    REM Extract major and minor version
    for /f "tokens=1,2 delims=." %%a in ("!VENV_VERSION!") do (
        set VENV_MAJOR=%%a
        set VENV_MINOR=%%b
    )
    
    REM Check if version is compatible (3.10-3.13)
    if "!VENV_MAJOR!"=="3" (
        if !VENV_MINOR! GEQ 10 (
            if !VENV_MINOR! LEQ 13 (
                echo Virtual environment is compatible with PlatformIO.
                goto :check_platformio
            )
        )
    )
    
    echo Virtual environment has incompatible Python version. Recreating...
    rmdir /s /q "%VENV_DIR%"
)

echo Creating virtual environment...

REM Try to find a compatible Python version (3.10-3.13)
set COMPATIBLE_PYTHON=

REM Try Python Launcher with specific versions
for %%v in (3.13 3.12 3.11 3.10) do (
    py -%%v --version >nul 2>&1
    if !errorlevel! equ 0 (
        echo Found Python %%v via py launcher
        set COMPATIBLE_PYTHON=py -%%v
        goto :create_venv
    )
)

REM Check default python
where python >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do set DEFAULT_VERSION=%%i
    for /f "tokens=1,2 delims=." %%a in ("!DEFAULT_VERSION!") do (
        set DEF_MAJOR=%%a
        set DEF_MINOR=%%b
    )
    
    if "!DEF_MAJOR!"=="3" (
        if !DEF_MINOR! GEQ 10 (
            if !DEF_MINOR! LEQ 13 (
                echo Using default Python !DEFAULT_VERSION!
                set COMPATIBLE_PYTHON=python
                goto :create_venv
            )
        )
    )
)

REM No compatible version found, need to install
echo.
echo ERROR: No compatible Python version found (3.10-3.13 required)!
echo Installing Python 3.13...
echo.

set PYTHON_VERSION=3.13.1
set PYTHON_URL=https://www.python.org/ftp/python/!PYTHON_VERSION!/python-!PYTHON_VERSION!-amd64.exe
set PYTHON_INSTALLER=%TEMP%\python-installer-3.13.exe
set PYTHON_PATH=C:\Python313

curl -L -o "%PYTHON_INSTALLER%" "!PYTHON_URL!"
if !errorlevel! neq 0 (
    echo ERROR: Failed to download Python installer!
    pause
    exit /b !errorlevel!
)

"%PYTHON_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=0 TargetDir="%PYTHON_PATH%" Include_test=0 Include_launcher=1
if !errorlevel! neq 0 (
    echo ERROR: Python installation failed!
    del "%PYTHON_INSTALLER%"
    pause
    exit /b !errorlevel!
)

del "%PYTHON_INSTALLER%"
echo Python 3.13 installed successfully!
set COMPATIBLE_PYTHON=%PYTHON_PATH%\python.exe

:create_venv
echo Creating virtual environment with !COMPATIBLE_PYTHON!...
!COMPATIBLE_PYTHON! -m venv "%VENV_DIR%"
if !errorlevel! neq 0 (
    echo ERROR: Failed to create virtual environment!
    pause
    exit /b !errorlevel!
)
echo Virtual environment created successfully!
echo.

:check_platformio
REM Check if PlatformIO is installed in venv
"%PYTHON_EXE%" -m pip show platformio >nul 2>&1
if !errorlevel! neq 0 (
    echo Installing PlatformIO in virtual environment...
    "%PYTHON_EXE%" -m pip install --upgrade pip
    "%PYTHON_EXE%" -m pip install platformio
    
    "%PYTHON_EXE%" -m pip show platformio >nul 2>&1
    if !errorlevel! neq 0 (
        echo ERROR: PlatformIO installation failed!
        pause
        exit /b 1
    )
    echo PlatformIO installed successfully!
)
echo.

REM Build ESP32 firmware in production mode
echo Building ESP32 firmware (production)...
"%PYTHON_EXE%" -m platformio run -e esp32dev
if !errorlevel! neq 0 (
    echo ERROR: Firmware build failed!
    pause
    exit /b !errorlevel!
)
echo.

echo ========================================
echo Firmware build completed successfully!
echo ========================================
echo Firmware: .pio\build\esp32dev\firmware.bin
echo.
echo To flash firmware to ESP32:
echo   flash_firmware.bat
echo.
pause
