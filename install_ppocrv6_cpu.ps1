$ErrorActionPreference = "Stop"

Write-Host "[1/4] Python ellenőrzése..."
python --version
python -c "import platform; print('arch:', platform.architecture()[0], platform.machine())"

Write-Host "[2/4] pip frissítése..."
python -m pip install --upgrade pip

Write-Host "[3/4] PaddlePaddle 3.2.0 CPU telepítése..."
python -m pip install paddlepaddle==3.2.0 -i https://www.paddlepaddle.org.cn/packages/stable/cpu/

Write-Host "[4/4] Selector függőségek telepítése..."
python -m pip install -r .\requirements.txt
python -m pip install -r .\requirements-build.txt

Write-Host ""
Write-Host "Kész. Ellenőrzés:"
python -c "import paddle, paddleocr; print('paddle', paddle.__version__); print('paddleocr', paddleocr.__version__)"
