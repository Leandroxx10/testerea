@echo off
if /i "%~1"=="--ce-modern-worker" goto :main
"%ComSpec%" /d /k ""%~f0" --ce-modern-worker %*"
exit /b

:main
shift /1
setlocal
chcp 65001 >nul
set "CE_MODERN_LOGDIR=%LOCALAPPDATA%\CE-Modern"
if not exist "%CE_MODERN_LOGDIR%" mkdir "%CE_MODERN_LOGDIR%"
set "CE_MODERN_LOG=%CE_MODERN_LOGDIR%\instalacao.log"
echo ==== CE Modern - instalacao %DATE% %TIME% ==== >>"%CE_MODERN_LOG%"
echo.
echo CE MODERN - INSTALACAO
 echo Este arquivo instala o pacote ja extraido; nao baixa o Cheat Engine.
echo Registro de erros: "%CE_MODERN_LOG%"
echo.
set "CE_DIR=%ProgramFiles%\Cheat Engine"
if not "%~1"=="" set "CE_DIR=%~1"
if exist "%CE_DIR%\Cheat Engine.exe" goto :sourcecheck
if exist "%CE_DIR%\cheatengine-x86_64.exe" goto :sourcecheck
if exist "%CE_DIR%\cheatengine-i386.exe" goto :sourcecheck
echo O Cheat Engine nao foi encontrado em "%CE_DIR%".
echo Informe a pasta onde ele esta instalado. Exemplo: C:\Program Files\Cheat Engine 7.5
set /p "CE_DIR=Pasta do Cheat Engine: "
set "CE_DIR=%CE_DIR:"=%"
if exist "%CE_DIR%\Cheat Engine.exe" goto :sourcecheck
if exist "%CE_DIR%\cheatengine-x86_64.exe" goto :sourcecheck
if exist "%CE_DIR%\cheatengine-i386.exe" goto :sourcecheck
echo ERRO: nenhum executavel do Cheat Engine foi encontrado nessa pasta.
goto :failure

:sourcecheck
for %%F in ("ce_modern.lua" "ce_modern\core.lua" "ce_modern\engine.lua" "ce_modern\voice.ps1") do if not exist "%~dp0autorun\%%~F" goto :missingfiles
echo Pasta de destino: "%CE_DIR%"
echo Feche todas as janelas do Cheat Engine antes de continuar.
pause
set "BACKUP=%CE_DIR%\CE-Modern-backup-%RANDOM%-%RANDOM%"
if not exist "%CE_DIR%\autorun\ce_modern.lua" goto :copyfiles
mkdir "%BACKUP%" >>"%CE_MODERN_LOG%" 2>&1
if errorlevel 1 goto :failure
copy /y "%CE_DIR%\autorun\ce_modern.lua" "%BACKUP%\ce_modern.lua" >>"%CE_MODERN_LOG%" 2>&1
if errorlevel 1 goto :failure
if not exist "%CE_DIR%\autorun\ce_modern" goto :backupdone
xcopy "%CE_DIR%\autorun\ce_modern" "%BACKUP%\ce_modern\" /e /i /y >>"%CE_MODERN_LOG%" 2>&1
if errorlevel 1 goto :failure
:backupdone
echo Copia da versao anterior: "%BACKUP%"

:copyfiles
if exist "%CE_DIR%\autorun\ce_modern" goto :copyready
mkdir "%CE_DIR%\autorun\ce_modern" >>"%CE_MODERN_LOG%" 2>&1
if errorlevel 1 goto :failure
:copyready
copy /y "%~dp0autorun\ce_modern.lua" "%CE_DIR%\autorun\ce_modern.lua" >>"%CE_MODERN_LOG%" 2>&1
if errorlevel 1 goto :failure
for %%F in (core.lua engine.lua voice.ps1) do (
 copy /y "%~dp0autorun\ce_modern\%%F" "%CE_DIR%\autorun\ce_modern\%%F" >>"%CE_MODERN_LOG%" 2>&1
 if errorlevel 1 goto :failure
)
echo.
echo INSTALACAO CONCLUIDA. Abra o Cheat Engine para usar o CE Modern.
echo Nenhuma configuracao de voz ou politica do PowerShell foi alterada.
echo Instalacao concluida. >>"%CE_MODERN_LOG%"
pause
exit /b 0

:missingfiles
echo ERRO: os arquivos da pasta autorun nao estao ao lado deste instalador.
echo Extraia o ZIP inteiro antes de instalar. Nao execute de dentro do ZIP.
goto :failure

:failure
echo.
echo A INSTALACAO NAO FOI CONCLUIDA.
echo Confira o caminho e se o ZIP foi completamente extraido.
echo Se aparecer Acesso negado, feche esta janela e execute Instalar.cmd como administrador.
echo Consulte o registro: "%CE_MODERN_LOG%"
echo Instalacao interrompida. >>"%CE_MODERN_LOG%"
pause
exit /b 1
