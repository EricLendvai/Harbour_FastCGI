
REM  THIS IS STILL UNDER DEVELOPMENT !!!!

@echo off
cls

if %HB_PATH%. == . goto MissingHB_PATH
if NOT %HB_COMPILER%. == mingw64. goto InvalidHB_COMPILER

echo Using -comp=mingw64

:: hbmk2 libfcgi.hbp -comp=mingw64 -b
hbmk2 libfcgi.hbp -comp=mingw64

goto End

:MissingHB_PATH
echo Run a HarbourTerminal Batch file first.
goto End

:InvalidHB_COMPILER
echo Run a HarbourTerminalMinGW64 Batch file first.
goto End

:End
