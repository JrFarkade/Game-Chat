@echo off
title GameChat Cloudflare Tunnel (Port 3000)
echo ========================================================
echo   Starting Cloudflare Tunnel for http://localhost:3000...
echo   Look below for your public HTTPS address:
echo   Example: https://xxxx-xxxx-xxxx.trycloudflare.com
echo ========================================================
echo.

where cloudflared >nul 2>nul
if %errorlevel% equ 0 (
    cloudflared tunnel --url http://localhost:3000
) else if exist "C:\Program Files (x86)\cloudflared\cloudflared.exe" (
    "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://localhost:3000
) else (
    echo [ERROR] cloudflared is not found.
    echo Please install it or run: winget install Cloudflare.cloudflared
)
pause
