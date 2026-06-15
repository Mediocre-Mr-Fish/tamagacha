@echo off
setlocal EnableDelayedExpansion
pushd "%CD%"

copy /Y "includes\IS_DEMO_true.p8.lua" "includes\IS_DEMO.p8.lua"

set "pico8=%CD%\..\..\pico8.exe"
set "temp_dir=_temp"

set "output=%~nx1"
set "output_dir=%~dp1"


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


"%pico8%" "tamagacha.p8" -export "%temp_dir%\tamagacha.p8.png"

"%pico8%" "collection.p8" -export "%temp_dir%\collection.p8.png"
set "carts= collection.p8.png"
set /a cart_count=1

for %%F in ("assets\*.p8") do (
    "%pico8%" "%%F" -export "%temp_dir%\assets\%%~nF.png"
    set "carts=!carts! assets/%%~nF.png"
    set /a cart_count+=1
)

for %%F in (
    "collection.p8"
    "games/fishing.p8"
    "games/math.p8"
    "games/maze.p8"
    "games/_secret.p8"
    "pets/duk.p8"
    "pets/che.p8"
    "pets/ymk.p8"
    "pets/owl.p8"
    "pets/hrs.p8"
) do (
    "%pico8%" "%%~F" -export "%temp_dir%\%%~F.png"
    set "carts=!carts! %%~F.png"
    set /a cart_count+=1
)


echo Additional carts: !cart_count!
echo carts=[!carts!]

pushd "%temp_dir%"
"%pico8%" "tamagacha.p8.png" -export "-f %output%!carts!"
    set "srcFolder=%output:.html=_html%"
    set "zipFile=%output:.html=_html.zip%"

    pushd "%srcFolder%"
    tar -a -c -f "..\%zipFile%" *
    popd
popd

set "dstFolder=%srcFolder:.bin=_bin%"

if exist "%output_dir%\" (
    if exist "%output_dir%\%dstFolder%" rmdir /s /q "%output_dir%\%dstFolder%"
    move "%temp_dir%\%srcFolder%" "%output_dir%\%dstFolder%"
    move "%temp_dir%\%zipFile%" "%output_dir%\"
)

copy /Y "includes\IS_DEMO_false.p8.lua" "includes\IS_DEMO.p8.lua"

popd
