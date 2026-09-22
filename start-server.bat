@echo off
title GameChat Signaling Server (Port 3000)
cd /d "%~dp0server"
echo ========================================================
echo   Starting GameChat Signaling Server on Port 3000...
echo ========================================================
node index.js
pause
