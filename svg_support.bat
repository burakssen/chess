@echo off
setlocal

REM Check if a file is provided
if "%~1"=="" (
    echo Usage: %0 filename
    exit /b 1
)

REM Check if the file exists
if not exist "%~1" (
    echo Error: File '%~1' does not exist.
    exit /b 1
)

REM Check if the file is writable
:: Create a temporary file to check write access
echo test > "%~1.tmp"
if errorlevel 1 (
    echo Error: File '%~1' is not writable.
    exit /b 1
)
del "%~1.tmp"

REM Replace //#define SUPPORT_FILEFORMAT_SVG with #define SUPPORT_FILEFORMAT_SVG
set "file=%~1"
set "success=false"

for /f "tokens=*" %%i in ('type "%file%"') do (
    set "line=%%i"
    setlocal enabledelayedexpansion
    echo !line! | findstr /r /c:"//#define SUPPORT_FILEFORMAT_SVG      1" >nul
    if !errorlevel! == 0 (
        echo #define SUPPORT_FILEFORMAT_SVG      1 >> "%file%.new"
        set "success=true"
    ) else (
        echo %%i >> "%file%.new"
    )
    endlocal
)

if "%success%"=="false" (
    echo Error: The pattern was not found in the file.
    del "%file%.new"
    exit /b 1
)

move /y "%file%.new" "%file%" >nul
if errorlevel 1 (
    echo Error: Failed to update the file.
    exit /b 1
)

echo Successfully updated '%file%'.
