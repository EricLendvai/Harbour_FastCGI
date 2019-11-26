@echo off
cls

if %HB_PATH%. == . goto MissingHB_PATH
if NOT %HB_COMPILER%. == msvc64. goto InvalidHB_COMPILER

echo Using -comp=msvc64

del libfcgi.dll

hbmk2 libfcgi.hbp -comp=msvc64 -b

goto End

:MissingHB_PATH
echo Run a HarbourTerminal Batch file first.
goto End

:InvalidHB_COMPILER
echo Run a HarbourTerminalMSVC64 Batch file first.
goto End

:End
