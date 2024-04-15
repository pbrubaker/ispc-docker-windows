#
# Released under MIT License
#
# Copyright (c) 2023 Pete Brubaker
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the “Software”), to deal in
# the Software without restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
# Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# base image
FROM mcr.microsoft.com/windows/servercore:20H2

# set the shell
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"] 

# make sure the temporary directory is created
RUN mkdir C:\temp > $null

# Download channel
ADD https://aka.ms/vs/17/release/channel C:\\TEMP\\VisualStudio.chman

# Download Build Tools for Visual Studio 2022
ADD https://aka.ms/vs/17/release/vs_buildtools.exe C:\\TEMP\\vs_buildtools.exe

# Download msys2
ADD https://github.com/msys2/msys2-installer/releases/download/nightly-x86_64/msys2-base-x86_64-latest.sfx.exe C:\\TEMP\\msys2.exe

# Download libgw
ADD https://github.com/ispc/ispc.dependencies/releases/download/gnuwin32-mirror/libgw32c-0.4-lib.zip C:\\temp\\libgw32c-0.4-lib.zip

# download python
ADD https://www.python.org/ftp/python/3.12.3/python-3.12.3-amd64.exe C:\\temp\\python-3.12.3-amd64.exe

# download git
ADD https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe C:\\temp\\Git-2.44.0-64-bit.exe

# install git
RUN C:\\temp\\Git-2.44.0-64-bit.exe /VERYSILENT /NORESTART

# install python
RUN C:\\temp\\python-3.12.3-amd64.exe /quiet InstallAllUsers=1 PrependPath=1

# install msys2
RUN (C:\\TEMP\\msys2.exe -y -oC:\\) -and (Clear-RecycleBin -Force -DriveLetter C)

# Install libgw
RUN Expand-Archive -LiteralPath C:\\temp\\libgw32c-0.4-lib.zip -DestinationPath C:\\libgw32c

# Install Msbuild tools
RUN C:\\TEMP\\vs_buildtools.exe --quiet --wait --norestart --nocache \
    --channelUri C:\\TEMP\\VisualStudio.chman \
    --installChannelUri C:\\TEMP\\VisualStudio.chman \
    --add Microsoft.VisualStudio.Workload.VCTools \
	--add Microsoft.VisualStudio.Component.VC.CMake.Project	 \
	--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
	--add Microsoft.Component.VC.Runtime.UCRTSDK \
	--add Microsoft.VisualStudio.Component.VC.CLI.Support \
	--add Microsoft.VisualStudio.Component.VC.ATL \
	--add Microsoft.VisualStudio.Component.Windows10SDK.20348 \
    --installPath C:\\BuildTools
	
# update msys2 & install packages - M4 is a dependency of flex/bison so no need to install it here
RUN function msys() { C:\\msys64\\usr\\bin\\bash.exe @('-lc') + @Args; } \
	msys ' '; \
	msys 'pacman --noconfirm -Syuu'; \
	msys 'pacman --noconfirm -Scc'; \
	msys 'pacman --noconfirm -S msys/bison'; \
	msys 'pacman --noconfirm -S msys/flex'; \
	Clear-RecycleBin -Force -DriveLetter C

# sleep here to get around a race condition
RUN Start-Sleep -Seconds 10

# remove temporary files
RUN Get-ChildItem -File C:\\temp\\* | Remove-Item

# add the command script script to the image
ADD command_script.ps1 C:\\BuildTools\\command_script.ps1

# create the volume for the source
# all commands to sync and build will be relative to this base path
# this path should be accessable by visual studio on the host
VOLUME C:\\ispc

# setup ISPC environment variables
# github URL, llvm directory, source directory,
ARG GITHUB_URL
ARG LLVM_VERSION
ENV ISPC_URL=${GITHUB_URL:-https://github.com/ispc/ispc}
ENV LLVM_HOME=C:\\ispc\\llvm
ENV LLVM_VERSION=${LLVM_VERSION:-17.0}
ENV ISPC_HOME=C:\\ispc\\ispc
ENV ISPC_BUILD_DIR=${ISPC_HOME}\\build
ENV ISPC_INSTALL_HOME=C:\\ispc\\install
ENV ISPC_GNUWIN32_PATH=C:\\libgw32c
ENV LLVM_BIN_DIR=${LLVM_HOME}\\bin-${LLVM_VERSION}\\bin

ARG INCLUDE_EXAMPLES
ARG INCLUDE_TESTS
ARG INCLUDE_UTILS
ENV ISPC_INCLUDE_EXAMPLES=${INCLUDE_EXAMPLES:-on}
ENV ISPC_INCLUDE_TESTS=${INCLUDE_TESTS:-on}
ENV ISPC_INCLUDE_UTILS=${INCLUDE_UTILS:-on}

ARG TARGET
ARG CONFIG
ENV ISPC_TARGET=${TARGET:-INSTALL}
ENV ISPC_CONFIG=${CONFIG:-Release}

# add msys, cmake and build tools to the path
RUN setx /M PATH $(${Env:PATH} + \";\" + ${Env:LLVM_BIN_DIR} + \";C:\buildtools\MSBuild\Current\Bin;C:\buildtools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\msys64\usr\bin\;C:\buildtools \")

# enter the container and call the build script
ENTRYPOINT ["C:\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", "C:\\BuildTools\\command_script.ps1"]
#ENTRYPOINT ["C:\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]

# run commands
# setup, build, clean, rebuild

# the default command is setup which will initialize the envronment in the C:\\ispc volume.
CMD ["setup"]


