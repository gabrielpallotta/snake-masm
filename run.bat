@echo off
cd src
if not exist ../res/rsrc.rc goto over1
C:\masm32\bin\rc /v ../res/rsrc.rc
C:\masm32\bin\cvtres /machine:ix86 ../res/rsrc.res
:over1

if exist snake.obj del snake.obj
if exist snake.exe del snake.exe

C:\masm32\bin\ml /c /coff snake.asm
if errorlevel 1 goto errasm

if not exist ../res/rsrc.obj goto nores

C:\masm32\bin\Link /SUBSYSTEM:WINDOWS /OPT:NOREF snake.obj ../res/rsrc.obj
if errorlevel 1 goto errlink

dir snake.*
snake.exe
goto TheEnd

:nores
C:\masm32\bin\Link /SUBSYSTEM:WINDOWS /OPT:NOREF snake.obj
if errorlevel 1 goto errlink
dir snake.*
snake.exe
goto TheEnd

:errlink
echo _
echo Link error
goto TheEnd

:errasm
echo _
echo Assembly Error
goto TheEnd

:TheEnd
cd ..
pause
