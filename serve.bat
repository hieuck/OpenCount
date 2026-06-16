@echo off
cd /d "%~dp0"
echo.
echo === OpenCount Web Server ===
echo.
echo Starting server at http://localhost:8080
echo Open this URL in your browser.
echo Press Ctrl+C to stop.
echo.
python -m http.server 8080 --directory "apps\web"
pause
