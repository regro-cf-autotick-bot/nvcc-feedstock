@echo on

set CUDA_VERSION=None

conda.exe install -yq shyaml
shyaml -h
if errorlevel 1 (
    echo ERROR! shyaml not installed but is required!
    exit /b 1
)

:: Pipe %CONFIG%.yaml into shyaml and output `cuda_compiler_version` to temporary file `cuda.version`
<.ci_support\%CONFIG%.yaml shyaml get-value cuda_compiler_version.0 None > cuda.version
<cuda.version set /p CUDA_VERSION=

if "%CUDA_VERSION%" == "None" (
    echo Skipping CUDA install...
    goto after_cuda
)

:: Define a default subset of components to be installed
:: This speeds up the installation subtly; the other ones are provided by the cudatoolkit anyway
:: Overwrite for individual versions if needed

set "CUDA_COMPONENTS=nvcc_11.1 Display.Driver"

if "%CUDA_VERSION%" == "9.2" goto cuda92
if "%CUDA_VERSION%" == "10.0" goto cuda100
if "%CUDA_VERSION%" == "10.1" goto cuda101
if "%CUDA_VERSION%" == "10.2" goto cuda102
if "%CUDA_VERSION%" == "11.0" goto cuda110

echo CUDA %CUDA_VERSION% is not supported
exit /b 1

:: Define URLs per version
:cuda92
set "CUDA_INSTALLER_URL=https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers2/cuda_9.2.148_win10"
set "CUDA_INSTALLER_CHECKSUM=f6c170a7452098461070dbba3e6e58f1"
set "CUDA_PATCH_URL=https://developer.nvidia.com/compute/cuda/9.2/Prod2/patches/1/cuda_9.2.148.1_windows"
set "CUDA_PATCH_CHECKSUM=09e20653f1346d2461a9f8f1a7178ba2"
goto cuda_common


:cuda100
set "CUDA_INSTALLER_URL=https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_411.31_win10"
set "CUDA_INSTALLER_CHECKSUM=90fafdfe2167ac25432db95391ca954e"
goto cuda_common


:cuda101
set "CUDA_INSTALLER_URL=http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_426.00_win10.exe"
set "CUDA_INSTALLER_CHECKSUM=b54cf32683f93e787321dcc2e692ff69"
goto cuda_common


:cuda102
set "CUDA_INSTALLER_URL=http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_441.22_win10.exe"
set "CUDA_INSTALLER_CHECKSUM=d9f5b9f24c3d3fc456a3c789f9b43419"
set "CUDA_PATCH_URL=http://developer.download.nvidia.com/compute/cuda/10.2/Prod/patches/1/cuda_10.2.1_win10.exe"
set "CUDA_PATCH_CHECKSUM=9d751ae129963deb7202f1d85149c69d"
goto cuda_common


:cuda110
set "CUDA_INSTALLER_URL=http://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_451.82_win10.exe"
set "CUDA_INSTALLER_CHECKSUM=80ae0fdbe04759123f3cab81f2aadabd"
goto cuda_common


:cuda111
set "CUDA_INSTALLER_URL=https://developer.download.nvidia.com/compute/cuda/11.1.1/local_installers/cuda_11.1.1_456.81_win10.exe"
set "CUDA_INSTALLER_CHECKSUM=a89dfad35fc1adf02a848a9c06cfff15"
goto cuda_common


:: The actual installation logic
:cuda_common

echo Downloading CUDA version %CUDA_VERSION% installer from %CUDA_INSTALLER_URL%
echo Expected MD5: %CUDA_INSTALLER_CHECKSUM%

:: Download installer
curl -k -L %CUDA_INSTALLER_URL% --output cuda_installer.exe
if errorlevel 1 (
    echo Problem downloading installer...
    exit /b 1
)

:: Check md5
openssl md5 cuda_installer.exe | findstr %CUDA_INSTALLER_CHECKSUM%
if errorlevel 1 (
    echo Checksum does not match!
    exit /b 1
)

:: Run installer
cuda_installer.exe -s %CUDA_COMPONENTS%
if errorlevel 1 (
    echo Problem running installer...
    exit /b 1
)

:: If patches are needed, download and apply
if not "%CUDA_PATCH_URL%"=="" (
    echo This version requires an additional patch
    curl -k -L %CUDA_PATCH_URL% --output cuda_patch.exe
    if errorlevel 1 (
        echo Problem downloading patch installer...
        exit /b 1
    )
    openssl md5 cuda_patch.exe | findstr %CUDA_PATCH_CHECKSUM%
    if errorlevel 1 (
        echo Checksum does not match!
        exit /b 1
    )
    cuda_patch.exe -s
    if errorlevel 1 (
        echo Problem running patch installer...
        exit /b 1
    )
)

:: Add to PATH
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v%CUDA_VERSION%"

if "%CI%" == "azure" (
    echo Exporting and adding $CUDA_PATH ('%CUDA_PATH%') to $PATH
    @echo off
    echo ##vso[task.prependpath]%CUDA_PATH%\bin
    echo ##vso[task.setvariable variable=CUDA_PATH;]%CUDA_PATH%
    echo ##vso[task.setvariable variable=CUDA_HOME;]%CUDA_PATH%
    @echo on
)

:after_cuda
echo Continuing with rest of the script...
