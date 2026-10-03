$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host "[1/6] PyInstaller build-függőség ellenőrzése..."
& python -m pip install -r .\requirements-build.txt
if ($LASTEXITCODE -ne 0) { throw "A build-függőségek telepítése sikertelen." }

Write-Host "[2/6] Régi build törlése..."
Remove-Item -Recurse -Force .\build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\dist -ErrorAction SilentlyContinue
Remove-Item -Force .\Selector-app.spec -ErrorAction SilentlyContinue

Write-Host "[3/6] Függőségek ellenőrzése..."
python -c "import paddle, paddleocr, numpy, PIL; print('paddle', paddle.__version__); print('paddleocr', paddleocr.__version__)"

Write-Host "[4/6] PyInstaller paraméterek összeállítása..."
$argsList = @(
    "-m", "PyInstaller",
    "--noconfirm",
    "--clean",
    "--onedir",
    "--windowed",
    "--name", "Selector-app",
    "--collect-all", "paddleocr",
    "--collect-all", "paddlex",
    "--collect-all", "paddle",
    "--collect-all", "ttkbootstrap",
    "--collect-all", "extract_msg"
)

if (Test-Path ".\Selector-app.ico") {
    $argsList += @("--icon", ".\Selector-app.ico")
}

$argsList += ".\Selector-app.py"

Write-Host "[5/6] EXE készítése..."
& python @argsList
if ($LASTEXITCODE -ne 0) { throw "PyInstaller hibával leállt." }

Write-Host "[6/6] Opcionális offline modellek másolása..."
if (Test-Path ".\models") {
    Copy-Item -Recurse -Force ".\models" ".\dist\Selector-app\models"
}

Write-Host ""
Write-Host "Kész: .\dist\Selector-app\Selector-app.exe"
Write-Host "Megjegyzés: a Paddle/PaddleOCR miatt a build jelentősen nagyobb lesz, mint a Tesseract-os változat."
