Selector-app – PP-OCRv6 változat
================================
Készítő: Szabolcs Bálint
Verzió: 2.1 / PP-OCRv6 online telepítő
Dátum: 2026-09-06

FŐ VÁLTOZÁS
-----------
A Tesseract OCR réteg kikerült. A képek és a képalapú PDF-oldalak OCR-je
PaddleOCR PP-OCRv6-medium modellel történik.

Megmaradt:
- TXT / HTML / CSV keresés
- PDF szövegréteg keresés
- DOCX, XLSX/XLS, ODT/ODS
- EML / MSG
- ZIP / RAR
- képek
- keresőszavankénti találati mappák
- sötét GUI
- OCR debug és search_report.txt
- ékezet- és kis/nagybetű-független keresés
- Poppler alapú PDF renderelés

A találati mappák megőrzik a forrás almappastruktúráját, ezért az azonos
nevű fájlok nem írják felül egymást. A kimeneti mappa nem lehet azonos a
forrásmappával; forrás alatti kimeneti mappa esetén a Selector kihagyja a
kimenetet a keresésből.

ÚJ OCR MŰKÖDÉS
--------------
OCR motor: PP-OCRv6_medium
Detection modell: PP-OCRv6_medium_det
Recognition modell: PP-OCRv6_medium_rec

A PP-OCRv6 egyetlen többnyelvű recognition modellt használ; ezért nincs már
hun+eng Tesseract nyelvi kapcsoló.

Az OCR motor lustán töltődik be: csak akkor inicializálódik, ha bekapcsolod a
"PP-OCRv6 PDF-hez" vagy "PP-OCRv6 képekhez" opciót és tényleges OCR szükséges.

FORENSIC / DEBUG
----------------
Az OCR debug fájlok helye:
  %LOCALAPPDATA%\Selector-app\ocr_debug

A confidence értékek a debug fájlban megmaradnak, de NEM vesznek részt a
keresőszavas egyezésben. Ez megakadályozza, hogy egy numerikus keresőszó egy
OCR confidence értékre adjon téves találatot.

A search_report.txt rögzíti többek között:
- OCR motor nevét
- PaddleOCR elérhetőségét
- helyi modellek útvonalát
- OCR confidence thresholdot
- Poppler útvonalat
- OCR inicializálási hibát, ha volt

ONLINE TELEPÍTŐ KÉSZÍTÉSE
-------------------------
1. A build gépre telepítsd az Inno Setup 6-ot.
2. PowerShellből, a projekt mappájában futtasd:
   .\build_installer_online.ps1
3. Az elkészült telepítő:
   .\installer_output\Selector-app-Setup-PP-OCRv6.exe

TELEPÍTÉS
---------
Indítsd el a fenti Setup EXE-t internetkapcsolattal. A telepítő az
alkalmazás mellé saját Python 3.12.10 futtatókörnyezetet és virtuális
környezetet állít be, majd letölti a PaddlePaddle 3.2.0 CPU csomagot,
a requirements.txt függőségeit, a PP-OCRv6 detection/recognition modelleket
és a Poppler PDF-eszközöket. A modell- és Poppler-csomag telepítés előtt
ellenőrzésre kerül. Az alkalmazás használatához nem kell külön Pythont vagy
OCR-csomagot telepíteni; a Start menü parancsikonja az alkalmazás saját
futtatókörnyezetét indítja.

A telepítéshez stabil internetkapcsolat szükséges. A csomagok a python.org,
az official PaddlePaddle CPU package index, a PyPI és a Poppler Windows
GitHub release oldaláról töltődnek le. A telepítő adminisztrátori jogot kér,
mert alapértelmezésben a Program Files mappába telepít.
Az Inno Setup fordítója és a PyInstaller csak a build gépen szükséges; a
végfelhasználói telepítés nem rakja fel ezeket a fejlesztői eszközöket.

FEJLESZTŐI / KÉZI TELEPÍTÉS
---------------------------
A forrásból futtatáshoz továbbra is használható:
  .\install_ppocrv6_cpu.ps1
  python .\Selector-app.py

Offline modellek előkészítéséhez:
  .\prepare_offline_models.ps1

KÖRNYEZETI VÁLTOZÓK – OPCIONÁLIS
---------------------------------
SELECTOR_PADDLE_MODEL_ROOT
  Saját modell gyökérmappa.

SELECTOR_PADDLE_DET_MODEL
  Saját PP-OCRv6 detection modell mappa.

SELECTOR_PADDLE_REC_MODEL
  Saját PP-OCRv6 recognition modell mappa.

SELECTOR_OCR_MIN_CONFIDENCE
  Minimum recognition confidence. Alapérték: 0.0.

POPPLER_PATH
  Poppler bin mappa a PDF rendereléshez.

FONTOS
------
Az online telepítő a Python, PaddlePaddle, Python-függőségek, OCR-modellek és
Poppler letöltését/telepítését automatizálja. Maga a telepítő EXE az Inno Setup
fordítóval készül a build gépen; az alkalmazás számítógépére nem kell külön
Inno Setupot telepíteni.
