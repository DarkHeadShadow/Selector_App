$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host "PP-OCRv6-medium modellek letöltése/cache-elése..."
python -c "from paddleocr import PaddleOCR; PaddleOCR(use_doc_orientation_classify=False,use_doc_unwarping=False,use_textline_orientation=False,text_detection_model_name='PP-OCRv6_medium_det',text_recognition_model_name='PP-OCRv6_medium_rec',engine='paddle'); print('PP-OCRv6 modellek cache-ben.')"

$cacheRoot = Join-Path $HOME ".paddlex\official_models"
$destRoot = Join-Path $projectDir "models"
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

$models = @("PP-OCRv6_medium_det", "PP-OCRv6_medium_rec")
foreach ($model in $models) {
    $src = Join-Path $cacheRoot $model
    $dst = Join-Path $destRoot $model
    if (!(Test-Path $src)) {
        throw "Nem található a cache-ben: $src"
    }
    if (Test-Path $dst) {
        Remove-Item -Recurse -Force $dst
    }
    Copy-Item -Recurse -Force $src $dst
    Write-Host "Másolva: $model -> $dst"
}

Write-Host ""
Write-Host "Kész. Az offline modellek a .\models mappában vannak."
