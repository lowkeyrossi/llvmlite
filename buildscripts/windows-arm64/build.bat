@echo off
setlocal enabledelayedexpansion

REM Setup VS2022 ARM64 cross-compilation environment
for /F "usebackq tokens=*" %%i in (`vswhere.exe -nologo -products * -version "[17.0,18.0)" -property installationPath`) do (
  set "VSINSTALLDIR=%%i\\"
)
if not exist "%VSINSTALLDIR%" (
  echo Could not find VS 2022
  exit /B 1
)

call "%VSINSTALLDIR%VC\\Auxiliary\\Build\\vcvarsall.bat" arm64

REM Set version and paths
set LLVM_VERSION=15.0.7
set BUILD_DIR=%CD%\build-arm64
set INSTALL_DIR=C:\llvm-arm64
set SOURCE_DIR=%CD%\llvm-project-%LLVM_VERSION%.src

REM Download and extract LLVM source if not present
if not exist "%SOURCE_DIR%" (
  curl -L -o llvm-project-%LLVM_VERSION%.src.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM_VERSION%/llvm-project-%LLVM_VERSION%.src.tar.xz
  if %ERRORLEVEL% neq 0 exit /B 1
  
  tar -xf llvm-project-%LLVM_VERSION%.src.tar.xz
  if %ERRORLEVEL% neq 0 exit /B 1
)

REM Create build directory
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"
cd "%BUILD_DIR%"

REM Configure build environment
set "CXXFLAGS=-MD"
set "CC=cl.exe"
set "CXX=cl.exe"

REM Configure with CMake
cmake -G "Ninja" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR% ^
    -DCMAKE_SYSTEM_NAME=Windows ^
    -DCMAKE_SYSTEM_PROCESSOR=ARM64 ^
    -DLLVM_TARGET_ARCH=AArch64 ^
    -DLLVM_TARGETS_TO_BUILD="AArch64;X86" ^
    -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-pc-windows-msvc ^
    -DLLVM_HOST_TRIPLE=aarch64-pc-windows-msvc ^
    -DLLVM_USE_INTEL_JITEVENTS=OFF ^
    -DLLVM_ENABLE_LIBXML2=OFF ^
    -DLLVM_ENABLE_RTTI=ON ^
    -DLLVM_ENABLE_ZLIB=OFF ^
    -DLLVM_ENABLE_ZSTD=OFF ^
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
    "%SOURCE_DIR%\llvm"

if %ERRORLEVEL% neq 0 exit /B 1

REM Build
cmake --build . --config Release
if %ERRORLEVEL% neq 0 exit /B 1

REM Install
cmake --build . --target install --config Release
if %ERRORLEVEL% neq 0 exit /B 1

cd ..
