@echo off
setlocal disabledelayedexpansion

:: --- CONFIGURATION ---
set "TOOL_DOLPHIN=%~dp0tools\windows\dolphin-tool.exe"
set "TOOL_WSZST=%~dp0tools\windows\wszst.exe"
set "VGM=%~dp0..\tools\windows\vgmstream-cli.exe"
set "WIITDB=%~dp0tools\wiitdb.xml"

echo -------------------------------------------------------
echo Wii Banner Jingle Extractor (Batch Mode)
echo -------------------------------------------------------

if not exist "%~dp0_sanitize.py" (
    echo [Error] _sanitize.py not found.
    pause & exit /b 1
)
if not exist "%~dp0_game_title.py" (
    echo [Error] _game_title.py not found.
    pause & exit /b 1
)
if not exist "%~dp0_extract_arc.py" (
    echo [Error] _extract_arc.py not found.
    pause & exit /b 1
)
if not exist "%~dp0_update_index.py" (
    echo [Error] _update_index.py not found.
    pause & exit /b 1
)
if not exist "%TOOL_DOLPHIN%" (
    echo [Error] dolphin-tool.exe not found at: %TOOL_DOLPHIN%
    pause & exit /b 1
)
if not exist "%TOOL_WSZST%" (
    echo [Error] wszst.exe not found at: %TOOL_WSZST%
    pause & exit /b 1
)
if not exist "%VGM%" (
    echo [Error] vgmstream-cli.exe not found at: %VGM%
    pause & exit /b 1
)
if not exist "%WIITDB%" (
    echo [Error] wiitdb.xml not found at: %WIITDB%
    pause & exit /b 1
)

pushd "%~dp0"
set "SCRIPT_DIR=%CD%"
cd ..\..
set "REPO_ROOT=%CD%"
popd

set "JINGLES_DIR=%REPO_ROOT%\jingles\wii"
set "INDEX_JSON=%REPO_ROOT%\index.json"
set "GAMES_DIR=%SCRIPT_DIR%\games"

if not exist "%JINGLES_DIR%" mkdir "%JINGLES_DIR%"
if not exist "%GAMES_DIR%" mkdir "%GAMES_DIR%"

for %%f in ("%GAMES_DIR%\*.rvz" "%GAMES_DIR%\*.iso") do (
    echo [Processing] %%~nxf...

    if not exist "%TEMP%\wii_bnr_extract" mkdir "%TEMP%\wii_bnr_extract"

    "%TOOL_DOLPHIN%" extract -i "%%f" -s opening.bnr -o "%TEMP%\wii_bnr_extract" >nul 2>&1

    if exist "%TEMP%\wii_bnr_extract\DATA\files\opening.bnr" (
        python "%~dp0_extract_arc.py" "%TEMP%\wii_bnr_extract\DATA\files\opening.bnr" "%TEMP%\wii_opening.arc"

        if exist "%TEMP%\wii_opening.arc" (
            if exist "%TEMP%\wii_bnr_out" rd /s /q "%TEMP%\wii_bnr_out"
            "%TOOL_WSZST%" extract "%TEMP%\wii_opening.arc" --dest "%TEMP%\wii_bnr_out" >nul 2>&1

            call :find_sound "%TEMP%\wii_bnr_out" SOUND_FILE
            if defined SOUND_FILE (
                :: Get Game ID from dolphin-tool header
                set "GAME_ID="
                for /f "tokens=2 delims=: " %%g in ('"%TOOL_DOLPHIN%" header -i "%%f" ^| findstr /i "Game ID"') do (
                    set "GAME_ID=%%g"
                )

                setlocal enabledelayedexpansion
                if not defined GAME_ID (
                    echo [Skip] Could not read Game ID from %%~nxf
                    endlocal
                ) else (
                    call :process_rom "!GAME_ID!" "!SOUND_FILE!"
                    endlocal
                )
            ) else (
                echo [Skip] No sound.bin found in %%~nxf
            )
        ) else (
            echo [Skip] Could not find U8 header in %%~nxf
        )
    ) else (
        echo [Skip] dolphin-tool did not extract opening.bnr from %%~nxf
    )

    if exist "%TEMP%\wii_bnr_extract" rd /s /q "%TEMP%\wii_bnr_extract"
    if exist "%TEMP%\wii_opening.arc" del "%TEMP%\wii_opening.arc"
    if exist "%TEMP%\wii_bnr_out" rd /s /q "%TEMP%\wii_bnr_out"

    echo -------------------------------------------------------
)

echo Extraction Complete!
pause
goto :eof

:find_sound
setlocal
set "SEARCH_DIR=%~1"
set "RESULT="
for /r "%SEARCH_DIR%" %%s in (sound.bin) do (
    if exist "%%s" (
        if not defined RESULT set "RESULT=%%s"
    )
)
endlocal & set "%~2=%RESULT%"
goto :eof

:process_rom
setlocal enabledelayedexpansion
set "GAME_ID=%~1"
set "SOUND_FILE=%~2"

for /f "delims=" %%t in ('python "%~dp0_game_title.py" "!GAME_ID!" "!WIITDB!"') do set "GAME_TITLE=%%t"
if not defined GAME_TITLE (
    echo [Skip] Game ID !GAME_ID! not found in wiitdb.xml
    endlocal
    goto :eof
)

for /f "delims=" %%s in ('python "%~dp0_sanitize.py" "!GAME_TITLE!"') do set "FINAL=%%s"

"%VGM%" "!SOUND_FILE!" -o "!JINGLES_DIR!\!FINAL!" >nul 2>&1
echo [Success] !GAME_TITLE! -> !FINAL!

python "%~dp0_update_index.py" "!INDEX_JSON!" "!GAME_TITLE!" "jingles/wii/!FINAL!"

endlocal
goto :eof
