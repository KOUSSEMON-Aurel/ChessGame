@echo off
REM Chess Game - Windows Setup Script
REM This script prepares the development environment and downloads Stockfish

echo =========================================
echo Chess Game - Setup Script (Windows)
echo =========================================
echo.

REM Check if Go is installed
where go >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Go is not installed or not in PATH
    echo Please install Go from https://go.dev/dl/
    echo After installation, restart your terminal and run this script again.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('go version') do set GO_VERSION=%%i
echo [OK] Go found: %GO_VERSION%
echo.

REM Create directories
echo Creating necessary directories...
if not exist "bin\linux" mkdir "bin\linux"
if not exist "bin\windows" mkdir "bin\windows"
if not exist "bin\macos" mkdir "bin\macos"
if not exist "engine" mkdir "engine"
echo [OK] Directories created
echo.

REM Build Go binaries for Windows
echo Building Go binaries for Windows...
set GOOS=windows
set GOARCH=amd64
go build -o bin\windows\iopiper.exe src\engine\iopiper.go
go build -o bin\windows\sampler.exe src\engine\sampler.go
go build -o bin\windows\ping-server.exe src\engine\ping-server.go
echo [OK] Windows binaries built
echo.

REM Download Stockfish
echo Downloading Stockfish chess engine for Windows...
set STOCKFISH_URL=https://github.com/official-stockfish/Stockfish/releases/download/sf_16.1/stockfish-windows-x86-64-avx2.zip
set STOCKFISH_ZIP=engine\stockfish-windows.zip
set STOCKFISH_BINARY=stockfish-windows-x64.exe

REM Use PowerShell to download (works on Windows 7+)
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%STOCKFISH_URL%' -OutFile '%STOCKFISH_ZIP%'}"

if exist "%STOCKFISH_ZIP%" (
    echo Extracting Stockfish...
    powershell -Command "& {Expand-Archive -Path '%STOCKFISH_ZIP%' -DestinationPath 'engine' -Force}"
    
    REM Find and rename the Stockfish executable
    set FOUND=0
    for /r "engine" %%f in (stockfish*.exe) do (
        if not "%%~nxf"=="%STOCKFISH_BINARY%" (
            echo Found Stockfish binary: %%f
            move "%%f" "engine\%STOCKFISH_BINARY%" >nul 2>nul
            set FOUND=1
            goto :stockfish_found
        ) else (
            set FOUND=1
            goto :stockfish_found
        )
    )
    
    :stockfish_found
    if "%FOUND%"=="1" (
        del "%STOCKFISH_ZIP%"
        echo [OK] Stockfish installed: engine\%STOCKFISH_BINARY%
    ) else (
        echo WARNING: Stockfish executable not found in extracted files.
        echo Please check the engine directory manually.
    )
) else (
    echo WARNING: Failed to download Stockfish
    echo You can manually download it from:
    echo %STOCKFISH_URL%
)

echo.
echo =========================================
echo [OK] Setup complete!
echo =========================================
echo.
echo Next steps:
echo 1. Open the project in Godot 4
echo 2. Run the game from the Godot editor
echo.
echo To build for other platforms:
echo   make build-linux    # Build Linux binaries
echo   make build-all      # Build for all platforms
echo.
pause
