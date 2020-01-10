@echo off

set PATH=C:\Program Files\mingw-w64\x86_64-8.1.0-win32-seh-rt_v6-rev0\mingw64\bin;C:\Harbour\bin\win\mingw64;%PATH%

::seh
::dwarf
::sjlj


set HB_COMPILER=mingw64

set HB_PATH=C:\Harbour

echo HB_PATH     = %HB_PATH%
echo HB_COMPILER = %HB_COMPILER%
echo PATH        = %PATH%


Prompt HarbourMinGW64 $p$g

:: C:
:: cd "C:\HarbourTestCode-64\"

"C:\WINDOWS\system32\cmd.exe"