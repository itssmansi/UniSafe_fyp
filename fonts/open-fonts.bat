@echo off
netstat -ano | findstr :8765 | findstr LISTENING >nul
if errorlevel 1 (
  start "" http://localhost:8765/index.html
  node "%~dp0server.js"
) else (
  start "" http://localhost:8765/index.html
)
