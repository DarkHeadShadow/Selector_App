param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir
)

$ErrorActionPreference = "Stop"
$pythonVersion = "3.12.10"
$pythonInstallerUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
$popplerUrl = "https://github.com/oschwartz10612/poppler-windows/releases/download/v26.09.0-0/Release-26.09.0-0.zip"
$popplerSha256 = "7a6f256a0ddf7536182246a5733331bf4677cbcc34f4663774947ad34556c8d0"
$pythonRoot = Join-Path $InstallDir "python"
$venvRoot = Join-Path $InstallDir "venv"
$python = Join-Path $venvRoot "Scripts\python.exe"
$tempRoot = Join-Path $env:TEMP ("Selector-app-install-" + [guid]::NewGuid().ToString("N"))

function Invoke-CheckedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$FailureMessage
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage (kilépési kód: $LASTEXITCODE)"
    }
}

try {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "A Selector-app telepítője 64 bites Windowst igényel."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $InstallDir "Selector-app.py"))) {
        throw "A telepítési mappában nem található a Selector-app.py."
    }

    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $pythonInstaller = Join-Path $tempRoot "python-installer.exe"
    $popplerArchive = Join-Path $tempRoot "poppler.zip"
    $popplerExtract = Join-Path $tempRoot "poppler"

    Write-Host "[1/5] Python $pythonVersion letöltése a python.org oldalról..."
    Invoke-WebRequest -UseBasicParsing -Uri $pythonInstallerUrl -OutFile $pythonInstaller
    $signature = Get-AuthenticodeSignature -FilePath $pythonInstaller
    if ($signature.Status -ne "Valid" -or $signature.SignerCertificate.Subject -notmatch "Python Software Foundation") {
        throw "A Python telepítő digitális aláírása nem érvényes vagy nem a Python Software Foundationtől származik."
    }

    Write-Host "[2/5] Alkalmazás saját Python futtatókörnyezetének telepítése..."
    $pythonArgs = @(
        "/quiet",
        "InstallAllUsers=0",
        ('TargetDir="{0}"' -f $pythonRoot),
        "Include_launcher=0",
        "Include_pip=1",
        "Include_tcltk=1",
        "Include_test=0",
        "PrependPath=0",
        "Shortcuts=0",
        "AssociateFiles=0"
    )
    $pythonInstall = Start-Process -FilePath $pythonInstaller -ArgumentList $pythonArgs -Wait -PassThru
    if ($pythonInstall.ExitCode -notin @(0, 3010)) {
        throw "A Python telepítése sikertelen (kilépési kód: $($pythonInstall.ExitCode))."
    }
    $basePython = Join-Path $pythonRoot "python.exe"
    if (-not (Test-Path -LiteralPath $basePython)) {
        throw "A Python telepítése lefutott, de a futtatókörnyezet nem található."
    }

    if (Test-Path -LiteralPath $venvRoot) {
        Remove-Item -LiteralPath $venvRoot -Recurse -Force
    }
    Invoke-CheckedProcess -FilePath $basePython -ArgumentList @("-m", "venv", $venvRoot) -FailureMessage "A Python virtuális környezet létrehozása sikertelen."

    Write-Host "[3/5] PaddlePaddle CPU és alkalmazásfüggőségek telepítése..."
    Invoke-CheckedProcess -FilePath $python -ArgumentList @("-m", "pip", "install", "--upgrade", "pip") -FailureMessage "A pip frissítése sikertelen."
    Invoke-CheckedProcess -FilePath $python -ArgumentList @(
        "-m", "pip", "install", "paddlepaddle==3.2.0",
        "--index-url", "https://www.paddlepaddle.org.cn/packages/stable/cpu/"
    ) -FailureMessage "A PaddlePaddle CPU telepítése sikertelen."
    Invoke-CheckedProcess -FilePath $python -ArgumentList @(
        "-m", "pip", "install", "-r", (Join-Path $InstallDir "requirements.txt")
    ) -FailureMessage "A Selector-app függőségeinek telepítése sikertelen."

    Write-Host "[4/5] PP-OCRv6 modellek letöltése és helyi telepítése..."
    $modelSetup = @'
from paddleocr import PaddleOCR
PaddleOCR(
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
    text_detection_model_name="PP-OCRv6_medium_det",
    text_recognition_model_name="PP-OCRv6_medium_rec",
    engine="paddle",
)
'@
    Invoke-CheckedProcess -FilePath $python -ArgumentList @("-c", $modelSetup) -FailureMessage "A PP-OCRv6 modellek letöltése sikertelen."

    $cacheRoot = Join-Path $env:USERPROFILE ".paddlex\official_models"
    $modelsRoot = Join-Path $InstallDir "models"
    foreach ($model in @("PP-OCRv6_medium_det", "PP-OCRv6_medium_rec")) {
        $source = Join-Path $cacheRoot $model
        $destination = Join-Path $modelsRoot $model
        $modelFiles = if (Test-Path -LiteralPath $source) {
            @(Get-ChildItem -LiteralPath $source -File -Recurse)
        } else {
            @()
        }
        if ($modelFiles.Count -eq 0) {
            throw "A letöltött OCR modell hiányzik vagy üres: $source"
        }
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
    }

    Write-Host "[5/5] Poppler letöltése, ellenőrzése és telepítése..."
    Invoke-WebRequest -UseBasicParsing -Uri $popplerUrl -OutFile $popplerArchive
    $actualHash = (Get-FileHash -LiteralPath $popplerArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $popplerSha256) {
        throw "A Poppler archívum SHA-256 ellenőrzése sikertelen."
    }
    Expand-Archive -LiteralPath $popplerArchive -DestinationPath $popplerExtract -Force
    $pdfInfo = Get-ChildItem -LiteralPath $popplerExtract -Filter "pdfinfo.exe" -File -Recurse |
        Select-Object -First 1
    if (-not $pdfInfo) {
        throw "A Poppler csomagban nem található a pdfinfo.exe."
    }
    $popplerBin = $pdfInfo.Directory.FullName
    if (-not (Test-Path -LiteralPath (Join-Path $popplerBin "pdftoppm.exe"))) {
        throw "A Poppler csomagból hiányzik a pdftoppm.exe."
    }
    $popplerRoot = if ($pdfInfo.Directory.Parent.Name -eq "Library") {
        $pdfInfo.Directory.Parent.Parent.FullName
    } else {
        $pdfInfo.Directory.Parent.FullName
    }
    $destinationPoppler = Join-Path $InstallDir "poppler"
    New-Item -ItemType Directory -Force -Path $destinationPoppler | Out-Null
    Copy-Item -Path (Join-Path $popplerRoot "*") -Destination $destinationPoppler -Recurse -Force

    Write-Host "A Selector-app és minden futásához szükséges összetevő telepítése befejeződött."
} catch {
    Write-Error $_
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
