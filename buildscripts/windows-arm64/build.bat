@echo off
setlocal enabledelayedexpansion

REM ==============================================
REM Configuration
REM ==============================================
set LLVM_VERSION=15.0.7
set LLVM_ARCHIVE=llvm-%LLVM_VERSION%.src.tar.xz
set LLVM_TAR=llvm-%LLVM_VERSION%.src.tar
set LLVM_FOLDER=llvm-project-%LLVM_VERSION%.src
set LLVM_DIR=llvm

REM ==============================================
REM Download and extract LLVM source if not present
REM ==============================================
if not exist %LLVM_DIR%\ (
    echo [INFO] Downloading LLVM %LLVM_VERSION% source...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM_VERSION%/llvm-project-%LLVM_VERSION%.src.tar.xz' -OutFile '%LLVM_ARCHIVE%'"
    
    echo [INFO] Extracting LLVM .tar.xz...
    7z x %LLVM_ARCHIVE% >nul || exit /B 1
    echo [INFO] Extracting LLVM .tar...
    7z x %LLVM_TAR% >nul || exit /B 1

    echo [INFO] Renaming extracted directory...
    ren %LLVM_FOLDER% %LLVM_DIR%

    del %LLVM_ARCHIVE%
    del %LLVM_TAR%
)

REM ==============================================
REM Locate Visual Studio
REM ==============================================
for /F "usebackq tokens=*" %%i in (`vswhere.exe -nologo -products * -version "[17.0,18.0)" -property installationPath`) do (
    set "VSINSTALLDIR=%%i"
)
if not exist "!VSINSTALLDIR!" (
    echo [ERROR] Could not find Visual Studio 2022.
    exit /B 1
)
echo [INFO] Using Visual Studio at: !VSINSTALLDIR!

REM ==============================================
REM Set up MSVC environment for ARM64
REM ==============================================
call "!VSINSTALLDIR!\VC\Auxiliary\Build\vcvarsall.bat" arm64
if errorlevel 1 exit /B 1

REM ==============================================
REM Prepare build directory
REM ==============================================
set INSTALL_DIR=C:\llvm-arm64

if exist build rmdir /s /q build
mkdir build
cd build

set "CXXFLAGS=-MD"
set "CC=cl.exe"
set "CXX=cl.exe"

REM ==============================================
REM Run CMake configuration
REM ==============================================
cmake -G "Ninja" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR% ^
  -DLLVM_USE_INTEL_JITEVENTS=ON ^
  -DLLVM_ENABLE_LIBXML2=FORCE_ON ^
  -DLLVM_ENABLE_RTTI=ON ^
  -DLLVM_ENABLE_ZLIB=FORCE_ON ^
  -DLLVM_ENABLE_ZSTD=FORCE_ON ^
  -DLLVM_INCLUDE_BENCHMARKS=OFF ^
  -DLLVM_INCLUDE_DOCS=OFF ^
  -DLLVM_INCLUDE_EXAMPLES=OFF ^
  -DLLVM_INCLUDE_TESTS=ON ^
  -DLLVM_INCLUDE_UTILS=ON ^
  -DLLVM_INSTALL_UTILS=ON ^
  -DLLVM_UTILS_INSTALL_DIR=libexec\llvm ^
  -DLLVM_BUILD_LLVM_C_DYLIB=OFF ^
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly ^
  -DCMAKE_POLICY_DEFAULT_CMP0111=NEW ^
  -DLLVM_ENABLE_PROJECTS="lld;compiler-rt" ^
  -DLLVM_ENABLE_ASSERTIONS=ON ^
  -DLLVM_ENABLE_DIA_SDK=OFF ^
  -DCOMPILER_RT_BUILD_BUILTINS=ON ^
  -DCOMPILER_RT_BUILTINS_HIDE_SYMBOLS=OFF ^
  -DCOMPILER_RT_BUILD_LIBFUZZER=OFF ^
  -DCOMPILER_RT_BUILD_CRT=OFF ^
  -DCOMPILER_RT_BUILD_MEMPROF=OFF ^
  -DCOMPILER_RT_BUILD_PROFILE=OFF ^
  -DCOMPILER_RT_BUILD_SANITIZERS=OFF ^
  -DCOMPILER_RT_BUILD_XRAY=OFF ^
  -DCOMPILER_RT_BUILD_GWP_ASAN=OFF ^
  -DCOMPILER_RT_BUILD_ORC=OFF ^
  -DCOMPILER_RT_INCLUDE_TESTS=OFF ^
  %~dp0..\..\llvm
if errorlevel 1 exit /B 1

REM ==============================================
REM Build and install LLVM
REM ==============================================
cmake --build . || exit /B 1
cmake --build . --target install || exit /B 1

echo [INFO] LLVM build and install completed successfully.

REM ==============================================
REM Optional: List installed files
REM ==============================================
dir /s /b "%INSTALL_DIR%"
