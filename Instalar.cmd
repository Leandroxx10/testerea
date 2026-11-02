@echo off
setlocal
chcp 65001 >nul
set "CE_DIR=%ProgramFiles%\Cheat Engine"
if not "%~1"=="" set "CE_DIR=%~1"
if not exist "%CE_DIR%\Cheat Engine.exe" (
 echo Pasta do Cheat Engine não encontrada: "%CE_DIR%"
 echo Execute: Instalar.cmd "C:\caminho\Cheat Engine"
 exit /b 1
)
echo Feche o Cheat Engine antes de continuar.
pause
set "BACKUP=%CE_DIR%\CE-Modern-backup-%RANDOM%-%RANDOM%"
if exist "%CE_DIR%\autorun\ce_modern.lua" (
 mkdir "%BACKUP%" || goto :failure
 copy /y "%CE_DIR%\autorun\ce_modern.lua" "%BACKUP%\ce_modern.lua" >nul || goto :failure
 if exist "%CE_DIR%\autorun\ce_modern" xcopy "%CE_DIR%\autorun\ce_modern" "%BACKUP%\ce_modern\" /e /i /y >nul
 if errorlevel 1 goto :failure
 echo Cópia de segurança criada em "%BACKUP%".
)
if not exist "%CE_DIR%\autorun" mkdir "%CE_DIR%\autorun" || goto :failure
xcopy "%~dp0autorun" "%CE_DIR%\autorun\" /e /i /y >nul || goto :failure
echo Instalação concluída. Abra o Cheat Engine para usar o CE Modern.
echo Os demais scripts da pasta autorun foram preservados.
pause
exit /b 0
:failure
echo Não foi possível concluir a cópia. Confira o caminho e as permissões.
echo Para Program Files, execute este instalador como administrador.
exit /b 1
