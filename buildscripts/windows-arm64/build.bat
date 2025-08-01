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
set VCPKG_ROOT=%CD%\vcpkg

REM Install vcpkg if not present
if not exist "%VCPKG_ROOT%" (
  git clone https://github.com/Microsoft/vcpkg.git
  if %ERRORLEVEL% neq 0 exit /B 1
  cd vcpkg
  call bootstrap-vcpkg.bat
  if %ERRORLEVEL% neq 0 exit /B 1
  cd ..
)

REM Clean up any existing zstd installations to avoid conflicts
call "%VCPKG_ROOT%\vcpkg.exe" remove zstd --recurse 2>nul
call "%VCPKG_ROOT%\vcpkg.exe" remove zstd:arm64-windows --recurse 2>nul
call "%VCPKG_ROOT%\vcpkg.exe" remove zstd:arm64-windows-static --recurse 2>nul

REM Install only essential dependencies (skip zstd entirely)
call "%VCPKG_ROOT%\vcpkg.exe" install zlib:arm64-windows-static libxml2:arm64-windows-static
if %ERRORLEVEL% neq 0 exit /B 1

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

REM Configure with CMake - Disable zstd completely to avoid issues
cmake -G "Ninja" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR% ^
    -DCMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake ^
    -DVCPKG_TARGET_TRIPLET=arm64-windows-static ^
    -DVCPKG_LIBRARY_LINKAGE=static ^
    -DVCPKG_CRT_LINKAGE=dynamic ^
    -DLLVM_USE_INTEL_JITEVENTS=ON ^
    -DLLVM_ENABLE_LIBXML2=FORCE_ON ^
    -DLLVM_ENABLE_RTTI=ON ^
    -DLLVM_ENABLE_ZLIB=FORCE_ON ^
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

echo Build completed successfully!
echo LLVM installed to: %INSTALL_DIR%
