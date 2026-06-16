@echo off
cd /d "%~dp0"
echo === OpenCount Web App ===
echo.
echo 1. Building web app...
call .\gradlew.bat :apps:web:compileKotlinJs --no-daemon
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FAILED!
    pause
    exit /b 1
)
echo.
echo 2. Copying standalone HTML...
copy /Y apps\web\opencount.html apps\web\build\distributions\opencount.html >nul
echo.
echo === READY ===
echo.
echo File: apps\web\build\distributions\opencount.html
echo.
echo Cach mo:
echo   - Double-click opencount.html de mo tren trinh duyet
echo   - Hoac dung server: npx serve apps\web\build\distributions\
echo.
echo AI that (TensorFlow.js): COCO-SSD, chay trong browser
echo Luu anh: iOS Share Sheet / Download
echo.
pause
