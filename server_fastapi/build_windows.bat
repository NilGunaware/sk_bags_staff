@echo off
setlocal

cd /d "%~dp0"

echo Installing desktop build dependencies...
python -m pip install --upgrade pip
python -m pip install -r desktop_requirements.txt

if not exist .env (
  copy .env.example .env >nul
)

echo Building Windows desktop package...
pyinstaller --noconfirm --clean desktop_app.spec

echo.
echo Build complete.
echo Main executable:
echo %cd%\dist\SKBagsDesktop.exe
pause
