@echo off
setlocal enabledelayedexpansion

:: --- CONFIGURATION ---
set "TOOL_3DS=3DS Tool\3dstool.exe"
set "VGM=vgmstream\vgmstream-cli.exe"

echo -------------------------------------------------------
echo 3DS Banner Jingle Extractor (Batch Mode)
echo -------------------------------------------------------

for %%f in (*.3ds *.cci) do (
    echo [Processing] %%f...

    "%TOOL_3DS%" -xvtf cci "%%f" -0 partition0.cxi >nul 2>&1
    "%TOOL_3DS%" -xvtf cxi partition0.cxi --exefs exefs.bin --exefs-auto-key >nul 2>&1
    "%TOOL_3DS%" -xvtfu exefs exefs.bin --exefs-dir exefs_dir >nul 2>&1

    if exist exefs_dir\banner.bnr (

        copy exefs_dir\banner.bnr banner.bin >nul
        "%TOOL_3DS%" -xvtf banner banner.bin --banner-dir banner_dir >nul 2>&1

        :: Fix BCWAV size
        python -c "import struct;d=open('banner_dir/banner.bcwav','rb').read();s=struct.unpack('<I',d[12:16])[0];open('banner_dir/banner.bcwav','wb').write(d[:s])"

        :: Raw filename
        set "RAW=%%~nf"
        set "RAWNAME=!RAW!"

        :: Sanitize filename using Python
        for /f "delims=" %%s in ('python -c "import os,re,unicodedata;s=os.environ['RAWNAME'];s=unicodedata.normalize('NFKD',s);s=''.join(c for c in s if not unicodedata.combining(c));s=s.encode('ascii','ignore').decode();s=s.replace(\"'\",'');s=re.sub(r'\([^)]*\)','',s);s=re.sub(r' *- *','-',s);s=s.replace(' ','-');s=re.sub(r'[^A-Za-z0-9-]+','',s);s=re.sub(r'-+','-',s).strip('-').lower();print(s+'.wav')"') do set "FINAL=%%s"

        "%VGM%" banner_dir\banner.bcwav -o "!FINAL!" >nul 2>&1

        echo [Success] Saved as: !FINAL!

    ) else (
        echo [Error] No banner found in %%f
    )

    if exist exefs_dir rd /s /q exefs_dir
    if exist banner_dir rd /s /q banner_dir
    if exist partition0.cxi del partition0.cxi
    if exist exefs.bin del exefs.bin
    if exist banner.bin del banner.bin

    echo -------------------------------------------------------
)

echo Extraction Complete!
pause
