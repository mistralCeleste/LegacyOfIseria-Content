@echo off
for %%f in ("*.png") do (
    set "name=%%~nf"
    setlocal enabledelayedexpansion

    rem Replace " [back]" with "_back"
    set "newname=!name: [back]=_back!"

    rem Replace " [face]" with "_face"
    set "newname=!newname: [face]=_face!"

    ren "%%f" "!newname!%%~xf"
    endlocal
)
