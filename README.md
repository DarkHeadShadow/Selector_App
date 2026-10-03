# Selector App — PP-OCRv6

Windowsos, grafikus fájlkereső többek között PDF, Office, szöveg-, e-mail-,
kép- és archívumfájlokhoz. Az alkalmazás ékezet- és kis-/nagybetű-független
keresést, opcionális PP-OCRv6 képfelismerést, valamint keresési jelentést
biztosít.

## Online telepítő készítése

1. Telepítsd az [Inno Setup 6](https://jrsoftware.org/isinfo.php) programot
   a build gépre.
2. PowerShellből, ebből a mappából futtasd:

   ```powershell
   .\build_installer_online.ps1
   ```

3. A telepítő itt készül el:
   `installer_output\Selector-app-Setup-PP-OCRv6.exe`

Az elkészült telepítőt futtató számítógépre nem kell külön Pythont telepíteni.
Az alkalmazás telepítés közben internetkapcsolatot igényel: saját Python
futtatókörnyezetet hoz létre, telepíti a CPU-s PaddlePaddle-t és a Python
függőségeket, letölti a PP-OCRv6 modelleket és a PDF-feldolgozáshoz szükséges
Popplert. Az OCR-modellek és a Poppler telepítés előtt ellenőrzésre kerülnek.

## Fejlesztői telepítés

PowerShellből:

```powershell
.\install_ppocrv6_cpu.ps1
python .\Selector-app.py
```

Az `.xls` fájlok olvasásához az `xlrd` függőség szükséges, amely szerepel a
`requirements.txt` fájlban.

## Tesztek

```powershell
python -m unittest discover -s .\tests -v
```

## Megjegyzések

- Az offline OCR-modell-előkészítéshez használd a
  `.\prepare_offline_models.ps1` szkriptet.
- A `models` mappába kerülő modellfájlok és a buildelt telepítő nincsenek
  verziókezelve; a telepítő a szükséges modelleket telepítés közben tölti le.
- A függőségek listája a `requirements.txt` és a buildhez külön használt
  `requirements-build.txt` fájlban található.
- További részletek: [README_PP-OCRv6.txt](README_PP-OCRv6.txt).
