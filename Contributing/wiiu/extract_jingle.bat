@echo off
setlocal disabledelayedexpansion

:: --- CONFIGURATION ---
set "TOOL_WUA=%~dp0tools\windows\wua_extract_file.exe"
set "VGM=%~dp0..\tools\windows\vgmstream-cli.exe"

echo -------------------------------------------------------
echo Wii U Banner Jingle Extractor (Batch Mode)
echo -------------------------------------------------------

if not exist "%~dp0_sanitize.py" (
    echo [Error] _sanitize.py not found.
    pause & exit /b 1
)
if not exist "%~dp0_game_title.py" (
    echo [Error] _game_title.py not found.
    pause & exit /b 1
)
if not exist "%~dp0_update_index.py" (
    echo [Error] _update_index.py not found.
    pause & exit /b 1
)
if not exist "%TOOL_WUA%" (
    echo [Error] wua_extract_file.exe not found at: %TOOL_WUA%
    pause & exit /b 1
)
if not exist "%VGM%" (
    echo [Error] vgmstream-cli.exe not found at: %VGM%
    pause & exit /b 1
)

pushd "%~dp0"
set "SCRIPT_DIR=%CD%"
cd ..\..
set "REPO_ROOT=%CD%"
popd

set "JINGLES_DIR=%REPO_ROOT%\jingles\wiiu"
set "INDEX_JSON=%REPO_ROOT%\index.json"
set "GAMES_DIR=%SCRIPT_DIR%\games"

if not exist "%JINGLES_DIR%" mkdir "%JINGLES_DIR%"
if not exist "%GAMES_DIR%" mkdir "%GAMES_DIR%"

for %%f in ("%GAMES_DIR%\*.wua") do (
    echo [Processing] %%~nxf...

    "%TOOL_WUA%" "%%f" meta/bootSound.btsnd "%TEMP%\wiiu_out.btsnd" >nul 2>&1
    "%TOOL_WUA%" "%%f" meta/meta.xml "%TEMP%\wiiu_meta.xml" >nul 2>&1

    if not exist "%TEMP%\wiiu_meta.xml" (
        echo [Skip] Could not extract meta.xml from %%~nxf
        goto :cleanup
    )
    if not exist "%TEMP%\wiiu_out.btsnd" (
        echo [Skip] Could not extract bootSound.btsnd from %%~nxf
        goto :cleanup
    )

    setlocal enabledelayedexpansion
    call :process_rom "%TEMP%\wiiu_out.btsnd" "%TEMP%\wiiu_meta.xml"
    endlocal

    :cleanup
    if exist "%TEMP%\wiiu_out.btsnd" del "%TEMP%\wiiu_out.btsnd"
    if exist "%TEMP%\wiiu_meta.xml" del "%TEMP%\wiiu_meta.xml"

    echo -------------------------------------------------------
)

echo Extraction Complete!
pause
goto :eof

:process_rom
setlocal enabledelayedexpansion
set "BTSND=%~1"
set "METAXML=%~2"

for /f "delims=" %%t in ('python "%~dp0_game_title.py" "!METAXML!"') do set "GAME_TITLE=%%t"
if not defined GAME_TITLE (
    echo [Skip] Could not determine title from meta.xml
    endlocal
    goto :eof
)

for /f "delims=" %%s in ('python "%~dp0_sanitize.py" "!GAME_TITLE!"') do set "FINAL=%%s"

"%VGM%" "!BTSND!" -o "!JINGLES_DIR!\!FINAL!" >nul 2>&1
echo [Success] !GAME_TITLE! -> !FINAL!

python "%~dp0_update_index.py" "!INDEX_JSON!" "!GAME_TITLE!" "jingles/wiiu/!FINAL!"

endlocal
goto :eof
