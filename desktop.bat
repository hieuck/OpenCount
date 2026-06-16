@echo off
cd /d "%~dp0"
echo Building and running OpenCount Desktop...
.\gradlew.bat :apps:desktop:run --no-daemon
pause
