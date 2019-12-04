@echo off

if %EXEName%. == . goto MissingEnvironmentVariables
if %BuildMode%. == . goto MissingEnvironmentVariables
if %WebsiteFolder%. ==. goto MissingEnvironmentVariables

if not exist %EXEName%.hbp (
	echo Invalid Workspace Folder. Missing file %EXEName%.hbp
	goto End
)

if %BuildMode%. == debug.   goto GoodParameters
if %BuildMode%. == release. goto GoodParameters

echo You must set Environment Variable BuildMode as "debug" or "release"
goto End

:GoodParameters

taskkill /IM FCGI%EXEName%.exe /f /t 2>nul

call "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64

set HB_COMPILER=msvc64
set HB_PATH=C:\Harbour

set PATH=%HB_PATH%\bin\win\msvc64;C:\HarbourTools;%PATH%

echo HB_PATH     = %HB_PATH%
echo HB_COMPILER = %HB_COMPILER%
echo PATH        = %PATH%

md "%BuildMode%"

del "%BuildMode%"\%EXEName%.exe
if exist "%BuildMode%"\%EXEName%.exe (
	echo Could not delete previous version of %EXEName%.exe
	goto End
)

if %BuildMode% == debug (
    hbmk2 %EXEName%.hbp -b
) else (
    hbmk2 %EXEName%.hbp
)

if not exist %BuildMode%\%EXEName%.exe (
	echo Failed To build %EXEName%.exe
) else (
	if errorlevel 0 (
		echo.
		echo No Errors

		del %WebsiteDrive%%WebsiteFolder%%EXEName%.exe
		del %WebsiteDrive%%WebsiteFolder%FCGI%EXEName%.exe

		if exist %WebsiteDrive%%WebsiteFolder%FCGI%EXEName%.exe (
			echo Failed to delete previous version of %WebsiteDrive%%WebsiteFolder%FCGI%EXEName%.exe
			goto End
		)

		copy %BuildMode%\%EXEName%.exe %WebsiteDrive%%WebsiteFolder%FCGI%EXEName%.exe
		if exist %WebsiteDrive%%WebsiteFolder%FCGI%EXEName%.exe (
			echo Copied file %BuildMode%\%EXEName%.exe to %WebsiteDrive%%WebsiteFolder%FCGI%EXEName%.exe
		) else (
			echo Failed to update file %WebsiteDrive%%WebsiteFolder%FCGI%EXEName%.exe
		)

		echo.
		echo Ready            BuildMode = %BuildMode%
		
	) else (
		echo Compilation Error
		if errorlevel  1 echo Unknown platform
		if errorlevel  2 echo Unknown compiler
		if errorlevel  3 echo Failed Harbour detection
		if errorlevel  5 echo Failed stub creation
		if errorlevel  6 echo Failed in compilation (Harbour, C compiler, Resource compiler)
		if errorlevel  7 echo Failed in final assembly (linker or library manager)
		if errorlevel  8 echo Unsupported
		if errorlevel  9 echo Failed to create working directory
		if errorlevel 19 echo Help
		if errorlevel 10 echo Dependency missing or disabled
		if errorlevel 20 echo Plugin initialization
		if errorlevel 30 echo Too deep nesting
		if errorlevel 50 echo Stop requested
	)
)

goto End
:MissingEnvironmentVariables
echo Missing Environment Variables
:End