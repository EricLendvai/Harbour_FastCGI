@echo off

call "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64
set PATH=C:\Harbour\bin\win\msvc64;%PATH%

set HB_COMPILER=msvc64

set HB_PATH=C:\Harbour

echo HB_PATH     = %HB_PATH%
echo HB_COMPILER = %HB_COMPILER%
echo PATH        = %PATH%

Prompt HarbourMSCV64 $p$g

"C:\WINDOWS\system32\cmd.exe"