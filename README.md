# ISPC Windows Docker Build Environment (ver. 0.1.1)

## Building the container

Make sure you have Docker Desktop installed, and that the container type is switched to Windows Containers.

Open a `cmd` or PowerShell Window in the container directory.

Build command: 

    docker build -t ispc_windows:latest .

Specify `--no-cache` before `-t` to completely rebuild the image.

If you wish to change any of the build arguments, specify them on the command file like this.

    docker build --build-arg GITHUB_URL=https://github.com/ispc/ispc

Available build time arguments, and their defualt values are:

    GITHUB_URL = "https://github.com/ispc/ispc"
    LLVM_VERSION = "14.0"
    INCLUDE_EXAMPLES = off
    INCLUDE_TESTS = off
    INCLUDE_UTILS = off
    TARGET = INSTALL
    CONFIG = Release

# Running the container

Run command: 

    docker run --storage-opt size=40G --cpus="16" --memory 32G --rm -v c:\temp\ispc:c:\ispc --name ispc_build -i ispc_windows:latest <command>

You must specify an empty directory for the `-v` or `--volume` command.  The first directory `c:\temp\ispc` should be replaced with a directory on your local machine.  This is where build artifacts are stored, and it is mapped to `c:\ispc` within the container.

Make sure to set the appropriate amount of `--memory` for the number of `--cpus` selected.

Containers used in this fasion are temporary and the `--rm` flag instructs Docker to remove this container after running.

The container `--name` can be whatever you want it to be.

`<command>` can be `setup`, `build`, `clean` or `rebuild`

Substitute `-i` with `-it`, comment out the default command, and swap the comments on entrypoint lines in the `Dockerfile` to open a PowerShell in the container.  The following configuration will give you a shell to issue build commands.
   
    #ENTRYPOINT ["C:\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", "c:\\BuildTools\\command_script.ps1"]

    ENTRYPOINT ["C:\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]

    # the default command is setup which will initialize the envronment in the C:\\ispc volume.
    #CMD ["setup"]

# Executing build scripts in the container.

Generate Solution Files:

    cmake -G "Visual Studio 17" -Thost=x64 -DCMAKE_INSTALL_PREFIX="$Env:ISPC_INSTALL_HOME" -H"$Env:ISPC_HOME" -B"$Env:ISPC_HOME\build"

Example of building the `ALL_BUILD` target with `Debug` configuration.
    
    cmake --build c:\ispc\ispc\build --target ALL_BUILD --config Debug

Example of building `INSTALL` target with `Release` configuraiton.

    cmake --build c:\ispc\ispc\build --target INSTALL --config Release

# About

This container was developed to make it easier for contributors to get their environment setup, or to build ISPC with specific versions of LLVM.

Created by: Pete Brubaker <pbrubaker@intel.com> - Twitter: [@pbrubaker](https://twitter.com/pbrubaker)

MIT License, see the `LICENSE` file in the repo folder.
