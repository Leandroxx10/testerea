# Copies only CE Modern files; existing unrelated autorun scripts are preserved.
param([string]$CheatEnginePath = 'C:\Program Files\Cheat Engine')
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'autorun'
if (-not (Test-Path -LiteralPath (Join-Path $CheatEnginePath 'Cheat Engine.exe'))) {
    throw 'Pasta do Cheat Engine não encontrada. Informe -CheatEnginePath com a pasta correta.'
}
$files = @('ce_modern.lua', 'ce_modern\core.lua', 'ce_modern\engine.lua', 'ce_modern\voice.ps1')
foreach ($relative in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $relative) -PathType Leaf)) {
        throw "Arquivo ausente no pacote: $relative"
    }
}
$target = Join-Path $CheatEnginePath 'autorun'
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($relative in $files) {
    if (Test-Path -LiteralPath (Join-Path $target $relative)) {
        throw 'CE Modern já está instalado ou existe um arquivo com o mesmo nome. Faça uma cópia de segurança e remova somente os arquivos CE Modern antes de reinstalar.'
    }
}
$written = @()
try {
    New-Item -ItemType Directory -Path (Join-Path $target 'ce_modern') -Force | Out-Null
    foreach ($relative in $files) {
        $destination = Join-Path $target $relative
        # No overwrite: preserve any file created after the existence check.
        [IO.File]::Copy((Join-Path $source $relative), $destination, $false)
        $written += $destination
    }
    Write-Host 'CE Modern instalado. Abra o Cheat Engine para começar.'
} catch {
    foreach ($path in $written) { Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue }
    throw
}
