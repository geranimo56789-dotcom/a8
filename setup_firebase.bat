@echo off
echo 🚀 VAR6 Betting App - Firebase Setup
echo ==========================================
echo.
echo This will set up Firebase automatically for you!
echo.
echo Requirements:
echo - Node.js installed (https://nodejs.org/)
echo - Google account for Firebase
echo.
pause
echo.
echo Starting Firebase setup...
echo.
powershell -ExecutionPolicy Bypass -File "scripts\setup_firebase.ps1"
pause
