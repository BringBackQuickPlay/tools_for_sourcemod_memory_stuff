@echo off
setlocal
set "PS1=%~dp0sm_hex_converter.ps1"
if not exist "%PS1%" (
  echo sm_hex_converter.ps1 not found beside this .bat 1>&2
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
endlocal & exit /b %ERRORLEVEL%
