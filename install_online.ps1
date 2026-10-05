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
$logFile = Join-Path $InstallDir "install_log.txt"
try { Start-Transcript -LiteralPath $logFile -Force | Out-Null } catch { }
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"

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
    # A Python MSI-csomagjait "adminisztratív" módban bontjuk ki: így a Python nem
    # regisztrálódik a Windowsban, és egy korábbi (félbemaradt) telepítés sem zavarja.
    $basePython = Join-Path $pythonRoot "python.exe"
    if (Test-Path -LiteralPath $basePython) {
        Write-Host "A beépített Python már megtalálható, a telepítés kihagyva."
    } else {
        # Az MSI-csomagokat közvetlenül a python.org-ról töltjük le, mert a Python
        # telepítője kihagyja azokat, amelyeket a gépen már telepítettnek hisz.
        $layoutDir = Join-Path $tempRoot "python-msi"
        New-Item -ItemType Directory -Force -Path $layoutDir | Out-Null
        $msiBaseUrl = "https://www.python.org/ftp/python/$pythonVersion/amd64"
        foreach ($msiName in @("core.msi", "exe.msi", "lib.msi", "tcltk.msi")) {
            $msi = Join-Path $layoutDir $msiName
            Write-Host "  $msiName letöltése..."
            Invoke-WebRequest -UseBasicParsing -Uri "$msiBaseUrl/$msiName" -OutFile $msi
            $sig = Get-AuthenticodeSignature -FilePath $msi
            if ($sig.Status -ne "Valid" -or $sig.SignerCertificate.Subject -notmatch "Python Software Foundation") {
                throw "A(z) $msiName digitális aláírása nem érvényes."
            }
        }
        New-Item -ItemType Directory -Force -Path $pythonRoot | Out-Null
        foreach ($msiName in @("core.msi", "exe.msi", "lib.msi", "tcltk.msi")) {
            $msi = Join-Path $layoutDir $msiName
            if (-not (Test-Path -LiteralPath $msi)) {
                throw "Hiányzó Python-összetevő: $msiName"
            }
            Write-Host "  $msiName kibontása..."
            $msiLog = Join-Path $InstallDir ("python_" + $msiName + ".log")
            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
                "/a", ('"{0}"' -f $msi), "/qn", ('TARGETDIR="{0}"' -f $pythonRoot), "/l*v", ('"{0}"' -f $msiLog)
            ) -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                throw "A(z) $msiName kibontása sikertelen (kilépési kód: $($proc.ExitCode)). Napló: $msiLog"
            }
            Remove-Item -LiteralPath $msiLog -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -LiteralPath $pythonRoot -Filter "*.msi" -File | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath $basePython)) {
        $found = Get-ChildItem -LiteralPath $pythonRoot -Filter "python.exe" -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { $basePython = $found.FullName }
    }
    if (-not (Test-Path -LiteralPath $basePython)) {
        throw "A Python kibontása lefutott, de a futtatókörnyezet nem található ($basePython)."
    }

    if (Test-Path -LiteralPath $venvRoot) {
        Remove-Item -LiteralPath $venvRoot -Recurse -Force
    }
    Invoke-CheckedProcess -FilePath $basePython -ArgumentList @("-m", "venv", $venvRoot) -FailureMessage "A Python virtuális környezet létrehozása sikertelen."

    Write-Host "[3/5] PaddlePaddle CPU és alkalmazásfüggőségek telepítése..."
    Invoke-CheckedProcess -FilePath $python -ArgumentList @("-m", "pip", "install", "--upgrade", "pip") -FailureMessage "A pip frissítése sikertelen."
    & $python -m pip install "paddlepaddle==3.2.0" --index-url "https://www.paddlepaddle.org.cn/packages/stable/cpu/"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "A PaddlePaddle saját tárolója nem elérhető, próbálkozás a PyPI-ról..."
        Invoke-CheckedProcess -FilePath $python -ArgumentList @(
            "-m", "pip", "install", "paddlepaddle==3.2.0"
        ) -FailureMessage "A PaddlePaddle CPU telepítése sikertelen."
    }
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
    $modelSetupFile = Join-Path $tempRoot "model_setup.py"
    Set-Content -LiteralPath $modelSetupFile -Value $modelSetup -Encoding UTF8
    Invoke-CheckedProcess -FilePath $python -ArgumentList @($modelSetupFile) -FailureMessage "A PP-OCRv6 modellek letöltése sikertelen."

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
    $exitCode = 0
} catch {
    Write-Host ""
    Write-Host "HIBA: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Részletek: $logFile"
    $exitCode = 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    try { Stop-Transcript | Out-Null } catch { }
}
exit $exitCode
