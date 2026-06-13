@echo off
setlocal EnableDelayedExpansion
pushd "%CD%"

set "pico8=%CD%\..\..\pico8.exe"

set "output=%~1"
if not defined output (
    echo Error: output dir not specified.
    echo Usage: %~nx0 carts
    exit /b 1
)

for %%D in ("%output%" "%output%\pets" "%output%\games" "%output%\assets") do (
    if not exist "%%D" mkdir "%%D"
)


"%pico8%" "collection.p8" -export "%output%\collection.p8.png"
"%pico8%" "save_editor.p8" -export "%output%\save_editor.p8.png"
"%pico8%" "gallery.p8" -export "%output%\gallery.p8.png"
"%pico8%" "tamagatcha.p8" -export "%output%\tamagatcha.p8.png"

set /a cart_count=3

call :export_folder pets
call :export_folder games
call :export_folder assets

exit /b

:export_folder
for %%F in ("%~1\*.p8") do (
    "%pico8%" "%%F" -export "%output%\%~1\%%~nF.p8.png"
    set /a cart_count+=1
)
exit /b