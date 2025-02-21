@REM Copyright (c) Microsoft. All rights reserved.
@REM Licensed under the MIT license. See LICENSE file in the project root for full license information.

@setlocal EnableExtensions EnableDelayedExpansion
@echo off

set current-path=%~dp0
rem // remove trailing slash
set current-path=%current-path:~0,-1%

echo Current Path: %current-path%

set build-root=%current-path%\..\..
rem // resolve to fully qualified path
for %%i in ("%build-root%") do set build-root=%%~fi

set repo_root=%build-root%\..\..
rem // resolve to fully qualified path
for %%i in ("%repo_root%") do set repo_root=%%~fi

echo Build Root: %build-root%
echo Repo Root: %repo_root%

rem -----------------------------------------------------------------------------
rem -- check prerequisites
rem -----------------------------------------------------------------------------


rem -----------------------------------------------------------------------------
rem -- parse script arguments
rem -----------------------------------------------------------------------------

rem // default build options
set build-clean=0
set build-config=Debug
set build-platform=Win32
set CMAKE_run_unittests=OFF
set CMAKE_DIR=umqtt_win32
set MAKE_NUGET_PKG=no

:args-loop
if "%1" equ "" goto args-done
if "%1" equ "-c" goto arg-build-clean
if "%1" equ "--clean" goto arg-build-clean
if "%1" equ "--config" goto arg-build-config
if "%1" equ "--platform" goto arg-build-platform
if "%1" equ "--run-unittests" goto arg-run-unittests
if "%1" equ "--make_nuget" goto arg-build-nuget
call :usage && exit /b 1

:arg-build-clean
set build-clean=1
goto args-continue

:arg-build-config
shift
if "%1" equ "" call :usage && exit /b 1
set build-config=%1
goto args-continue

:arg-build-platform
shift
if "%1" equ "" call :usage && exit /b 1
set build-platform=%1
if %build-platform% == x64 (
    set CMAKE_DIR=umqtt_x64
) else if %build-platform% == arm (
    set CMAKE_DIR=umqtt_arm
)
goto args-continue

:arg-run-unittests
set CMAKE_run_unittests=ON
goto args-continue

:arg-build-nuget
shift
if "%1" equ "" call :usage && exit /b 1
set MAKE_NUGET_PKG=%1
set CMAKE_run_unittests=OFF
goto args-continue

:args-continue
shift
goto args-loop

:args-done

rem -----------------------------------------------------------------------------
rem -- build with CMAKE and run tests
rem -----------------------------------------------------------------------------

echo CMAKE Output Path: %build-root%\cmake\%CMAKE_DIR%

if EXIST %build-root%\cmake\%CMAKE_DIR% (
    rmdir /s/q %build-root%\cmake\%CMAKE_DIR%
    rem no error checking
)

echo %build-root%\cmake\%CMAKE_DIR%
mkdir %build-root%\cmake\%CMAKE_DIR%
pushd %build-root%\cmake\%CMAKE_DIR%

echo ***checking msbuild***
where /q msbuild
IF ERRORLEVEL 1 (
echo ***setting VC paths***
    IF EXIST "%ProgramFiles(x86)%\Microsoft Visual Studio\2017\Enterprise\Common7\Tools\VsMSBuildCmd.bat" call "%ProgramFiles(x86)%\Microsoft Visual Studio\2017\Enterprise\Common7\Tools\VsMSBuildCmd.bat"
)
where msbuild

if %MAKE_NUGET_PKG% == yes (
    echo ***Running CMAKE for Win32***
    cmake %build-root% -Drun_unittests:BOOL=%CMAKE_run_unittests%
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
    popd

    echo ***Running CMAKE for Win64***
    if EXIST %build-root%\cmake\umqtt_x64 (
        rmdir /s/q %build-root%\cmake\umqtt_x64
    )
    mkdir %build-root%\cmake\umqtt_x64
    pushd %build-root%\cmake\umqtt_x64
    cmake -Drun_unittests:BOOL=%CMAKE_run_unittests% %build-root% -G "Visual Studio 15 2017" -A x64
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
    popd

    echo ***Running CMAKE for ARM***
    if EXIST %build-root%\cmake\umqtt_arm (
        rmdir /s/q %build-root%\cmake\umqtt_arm
    )
    mkdir %build-root%\cmake\umqtt_arm
    pushd %build-root%\cmake\umqtt_arm
    echo ***Running CMAKE for ARM***
    cmake -Drun_unittests:BOOL=%CMAKE_run_unittests% %build-root% -G "Visual Studio 15 2017" -A ARM
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!

) else if %build-platform% == Win32 (
    echo ***Running CMAKE for Win32***
    cmake %build-root% -Drun_unittests:BOOL=%CMAKE_run_unittests% -G "Visual Studio 15 2017" -A Win32
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
) else if %build-platform% == arm (
    echo ***Running CMAKE for ARM***
    cmake -Drun_unittests:BOOL=%CMAKE_run_unittests% %build-root% -G "Visual Studio 15 2017" -A ARM
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
) else (
    echo ***Running CMAKE for Win64***
    cmake -Drun_unittests:BOOL=%CMAKE_run_unittests% %build-root% -G "Visual Studio 15 2017" -A x64
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
)

if %MAKE_NUGET_PKG% == yes (
        echo ***Building all configurations***
        msbuild /m %build-root%\cmake\umqtt_win32\umqtt.sln /p:Configuration=Release
        msbuild /m %build-root%\cmake\umqtt_win32\umqtt.sln /p:Configuration=Debug
        if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!

        msbuild /m %build-root%\cmake\umqtt_x64\umqtt.sln /p:Configuration=Release
        msbuild /m %build-root%\cmake\umqtt_x64\umqtt.sln /p:Configuration=Debug
        if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!

        msbuild /m %build-root%\cmake\umqtt_arm\umqtt.sln /p:Configuration=Release
        msbuild /m %build-root%\cmake\umqtt_arm\umqtt.sln /p:Configuration=Debug
        if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
) else (
    rem msbuild /m umqtt.sln
    call :_run-msbuild "Build" umqtt.sln %2 %3
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!

    echo Build Config: %build-config%
    echo Build Platform: %build-platform%

    if %build-platform% neq arm (
        echo Build Platform: %build-platform%

        if "%build-config%" == "Debug" (
            ctest -C "debug" -V
            if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
        )
    )
)
popd
goto :eof

rem -----------------------------------------------------------------------------
rem -- subroutines
rem -----------------------------------------------------------------------------

:clean-a-solution
call :_run-msbuild "Clean" %1 %2 %3
goto :eof

:build-a-solution
call :_run-msbuild "Build" %1 %2 %3
goto :eof

:run-unit-tests
call :_run-tests %1 "UnitTests"
goto :eof

:usage
echo build.cmd [options]
echo options:
echo  -c, --clean             delete artifacts from previous build before building
echo  --config ^<value^>      [Debug] build configuration (e.g. Debug, Release)
echo  --platform ^<value^>    [Win32] build platform (e.g. Win32, x64, arm, ...)
echo  --run-unittests         run the unit tests
echo  --make_nuget ^<value^>  [no] generates the binaries to be used for nuget packaging (e.g. yes, no)
goto :eof

rem -----------------------------------------------------------------------------
rem -- helper subroutines
rem -----------------------------------------------------------------------------

echo build config: %build-config%
echo platform:     %build-platform%

:_run-msbuild
rem // optionally override configuration|platform
setlocal EnableExtensions
set build-target=
if "%~1" neq "Build" set "build-target=/t:%~1"
if "%~3" neq "" set build-config=%~3
if "%~4" neq "" set build-platform=%~4

msbuild /m %build-target% "/p:Configuration=%build-config%;Platform=%build-platform%" %2
if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
goto :eof

:_run-tests
rem // discover tests
set test-dlls-list=
set test-dlls-path=%build-root%\%~1\build\windows\%build-platform%\%build-config%
for /f %%i in ('dir /b %test-dlls-path%\*%~2*.dll') do set test-dlls-list="%test-dlls-path%\%%i" !test-dlls-list!

if "%test-dlls-list%" equ "" (
    echo No unit tests found in %test-dlls-path%
    exit /b 1
)

rem // run tests
echo Test DLLs: %test-dlls-list%
echo.
vstest.console.exe %test-dlls-list%
if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
goto :eof

echo done