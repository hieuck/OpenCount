@echo off
cd /d "%~dp0"
echo === OpenCount Build Script ===
echo.
echo 1. Run tests
.\gradlew.bat :packages:shared:desktopTest --no-daemon
if %ERRORLEVEL% NEQ 0 ( echo Tests FAILED! & pause & exit /b 1 )
echo.
echo 2. Build Desktop
.\gradlew.bat :apps:desktop:compileKotlinDesktop --no-daemon
if %ERRORLEVEL% NEQ 0 ( echo Desktop FAILED! & pause & exit /b 1 )
echo.
echo 3. Build Android
.\gradlew.bat :apps:android:assembleDebug --no-daemon
if %ERRORLEVEL% NEQ 0 ( echo Android FAILED! & pause & exit /b 1 )
echo.
echo 4. Build Web
.\gradlew.bat :apps:web:compileKotlinJs --no-daemon
if %ERRORLEVEL% NEQ 0 ( echo Web FAILED! & pause & exit /b 1 )
echo.
echo === ALL BUILDS PASSED ===
pause
