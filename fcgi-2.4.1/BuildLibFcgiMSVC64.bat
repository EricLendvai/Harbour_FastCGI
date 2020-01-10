@echo off
cls

if %HB_PATH%. == . goto MissingHB_PATH
if NOT %HB_COMPILER%. == msvc64. goto InvalidHB_COMPILER

:: echo Using -comp=msvc64

::hbmk2 libfcgi.hbp -comp=msvc64 -b
Echo No support yet for back command build. Open Solution .\Win32\FastCGI.sln with Visual Studion 2019 and do a 64-bit release build


goto End

:MissingHB_PATH
echo Run a HarbourTerminal Batch file first.
goto End

:InvalidHB_COMPILER
echo Run a HarbourTerminalMSVC64 Batch file first.
goto End

:End
