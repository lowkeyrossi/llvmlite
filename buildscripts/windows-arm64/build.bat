@echo off
setlocal enabledelayedexpansion

REM Set LLVM version tag
set "LLVM_TAG=llvmorg-15.0.7"
set "INSTALL_DIR=C:\llvm-arm64"

REM Locate Visual Studio 2022 installation path
for /F "usebackq tokens=*" %%i in (`vswhere.exe -nologo -products * -version "[17.0,18.0)" -property installationPath`) do (
  set "VSINSTALLDIR=%%i"
)

if not exist "!VSINSTALLDIR!" (
  echo [ERROR] Could not find Visual Studio 2022.
  exit /B 1
)

echo [INFO] Using Visual Studio at: !VSINSTALLDIR!

REM Set up MSVC environment for native ARM64 compilation
call "!VSINSTALLDIR!\VC\Auxiliary\Build\vcvarsall.bat" arm64
if errorlevel 1 exit /B 1

REM Clone LLVM repository using sparse checkout to reduce size and skip symlinks
if exist llvm-project (
  echo [INFO] Removing existing llvm-project directory...
  rmdir /s /q llvm-project
)

echo [INFO] Cloning LLVM source from GitHub...
git clone --depth 1 --branch %LLVM_TAG% https://github.com/llvm/llvm-project.git llvm-project || exit /B 1
cd llvm-project
git sparse-checkout init --cone || exit /B 1
git sparse-checkout set llvm clang lld compiler-rt || exit /B 1
cd ..

REM Clean and create build and install directories
if exist build rmdir /s /q build
mkdir build
cd build

REM Set build flags
set "CXXFLAGS=-MD"
set "CC=cl.exe"
set "CXX=cl.exe"

REM Configure CMake
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
  %~dp0llvm-project\llvm || exit /B 1

REM Build and install
cmake --build . || exit /B 1
cmake --build . --target install || exit /B 1

echo [INFO] LLVM build and install completed successfully.

REM Optional: Show install path content (for packaging/debug)
dir /s /b "%INSTALL_DIR%"
