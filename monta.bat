@echo off

if exist %1.obj del %1.obj
if exist %1.exe del %1.exe

ml /c /coff %1.asm
if errorlevel 1 goto errasm

Link /SUBSYSTEM:CONSOLE /OPT:NOREF %1.obj
if errorlevel 1 goto errlink


cls

%1.exe

goto TheEnd

:errlink
    echo
    echo Erro de Link
    goto TheEnd

:errasm
    echo
    echo Erro de montagem
    goto TheEnd


:TheEnd