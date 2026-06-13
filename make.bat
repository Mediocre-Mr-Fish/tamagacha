@echo off
setlocal EnableDelayedExpansion
pushd "%CD%"

copy /Y "includes\IS_HTML_true.p8.lua" "includes\IS_HTML.p8.lua"

set "pico8=%CD%\..\..\pico8.exe"
set "temp_dir=_temp"

set "output=%~1"
if not defined output (
    echo Error: output HTML file not specified.
    echo Usage: %~nx0 output.html
    exit /b 1
)

if exist "%temp_dir%" rmdir /s /q "%temp_dir%"

mkdir "%temp_dir%"
mkdir "%temp_dir%\pets"
mkdir "%temp_dir%\games"
mkdir "%temp_dir%\assets"


"%pico8%" "tamagatcha.p8" -export "%temp_dir%\tamagatcha.p8.png"

"%pico8%" "collection.p8" -export "%temp_dir%\collection.p8.png"
set "carts= collection.p8.png"
set /a cart_count+=1

call :export_folder pets
call :export_folder games
call :export_folder assets

echo Additional carts: !cart_count!
echo carts=[!carts!]

pushd "%temp_dir%"
"%pico8%" "tamagatcha.p8.png" -export "-f %output%!carts!"
    set "srcFolder=%output:.html=_html%"
    set "zipFile=%output:.html=.zip%"

    pushd "%srcFolder%"
    tar -a -c -f "..\%zipFile%" *
    popd
popd
if exist "%~2\" (
    if exist "%~2\%srcFolder%" rmdir /s /q "%~2\%srcFolder%"
    move "%temp_dir%\%srcFolder%" "%~2\"
    move "%temp_dir%\%zipFile%" "%~2\"
)

copy /Y "includes\IS_HTML_false.p8.lua" "includes\IS_HTML.p8.lua"

popd
exit /b

:export_folder
for %%F in ("%~1\*.p8") do (
    "%pico8%" "%%F" -export "%temp_dir%\%~1\%%~nF.p8.png"
    set "carts=!carts! %~1/%%~nF.p8.png"
    set /a cart_count+=1
)
exit /b