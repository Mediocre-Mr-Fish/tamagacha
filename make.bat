@echo off
setlocal EnableDelayedExpansion

set "pico8=..\..\pico8.exe"
set "carts="
set /a cart_count=0

set "output=%~1"
if not defined output (
    echo Error: output HTML file not specified.
    echo Usage: %~nx0 output.html
    exit /b 1
)

for %%D in (temp temp\pets temp\games temp\assets) do (
    if not exist "%%D" mkdir "%%D"
)

"%pico8%" "collection.p8" -export "temp\collection.p8.png"
set "carts=!carts! collection.p8.png"
set /a cart_count+=1

"%pico8%" "tamagatcha.p8" -export "temp\tamagatcha.p8.png"

call :export_folder pets
call :export_folder games
call :export_folder assets

echo Additional carts: !cart_count!
echo carts=[!carts!]

pushd temp
"..\%pico8%" "tamagatcha.p8.png" -export "-f %output%!carts!"
    set "srcFolder=%output:.html=_html%"
    set "zipFile=%output:.html=.zip%"

    pushd "%srcFolder%"
    tar -a -c -f "..\%zipFile%" *
    popd
popd
if exist "%~2\" (
    move "temp\%srcFolder%" "%~2\"
    move "temp\%zipFile%" "%~2\"
)

exit /b

:export_folder
for %%F in ("%~1\*.p8") do (
    "%pico8%" "%%F" -export "temp\%~1\%%~nF.p8.png"
    set "carts=!carts! %~1/%%~nF.p8.png"
    set /a cart_count+=1
)
exit /b