$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

$compiler = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
if ($compiler) {
    $compilerPath = $compiler.Source
} else {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 7\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 7\ISCC.exe")
    )
    $compilerPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $compilerPath) {
    throw "Az Inno Setup fordítója (ISCC.exe) nincs telepítve. Telepítsd az Inno Setup 6-ot, majd futtasd újra ezt a szkriptet."
}

Write-Host "Online telepítő fordítása..."
& $compilerPath ".\installer_ppocrv6.iss"
if ($LASTEXITCODE -ne 0) {
    throw "Az Inno Setup fordítása hibával leállt (kilépési kód: $LASTEXITCODE)."
}

$installerPath = Join-Path $projectDir "installer_output\Selector-app-Setup-PP-OCRv6.exe"
if (-not (Test-Path -LiteralPath $installerPath)) {
    throw "A fordítás nem hozta létre a várt telepítőt: $installerPath"
}

Write-Host ""
Write-Host "Kész online telepítő: $installerPath"
