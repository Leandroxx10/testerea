@echo off
if /i "%~1"=="--worker" goto :main
"%ComSpec%" /d /k ""%~f0" --worker"
exit /b
:main
setlocal
chcp 65001 >nul
cd /d "%~dp0"
echo MEMORIA STUDIO - APLICATIVO INDEPENDENTE
if exist "%~dp0MemoriaStudio.exe" (
 start "Memoria Studio" "%~dp0MemoriaStudio.exe"
 exit /b 0
)
py -3.12 -c "import struct; assert struct.calcsize('P')==8" >nul 2>&1
if errorlevel 1 goto :nopython
if exist "%~dp0.venv\Scripts\python.exe" goto :dependencies
py -3.12 -m venv "%~dp0.venv"
if errorlevel 1 goto :failure
:dependencies
"%~dp0.venv\Scripts\python.exe" -c "import PySide6, capstone" >nul 2>&1
if not errorlevel 1 goto :launch
echo Preparando a interface. Aguarde o download das dependencias...
"%~dp0.venv\Scripts\python.exe" -m pip install -r "%~dp0requirements.txt"
if errorlevel 1 goto :failure
:launch
"%~dp0.venv\Scripts\python.exe" "%~dp0launch.py"
if errorlevel 1 goto :failure
exit /b 0
:nopython
echo Esta versao em codigo-fonte precisa do Python 3.12 de 64 bits.
echo Instale pelo site python.org ou use: winget install Python.Python.3.12
echo Depois abra novamente este arquivo. Nenhum arquivo do Cheat Engine foi alterado.
pause
exit /b 1
:failure
echo O aplicativo nao iniciou. Copie a mensagem de erro acima para diagnostico.
pause
exit /b 1
