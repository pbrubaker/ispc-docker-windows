#
# Released under MIT License
#
# Copyright (c) 2023-2024 Pete Brubaker
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

function PrintHelp()
{
	Write-Host "command_script can be called with one parameter.  The parameters are setup, build, clean and rebuild."
}

function setup()
{
	# if the directories already exist exit with error to remove them
	if((Test-Path "$Env:ISPC_HOME") -or (Test-Path "$Env:LLVM_HOME")) {
		Write-Host "Cannot perform setup as ISPC_HOME and LLVM_HOME directories exist"
		PrintHelp
		exit 1
	}
	
	# create destination directories
	mkdir $Env:ISPC_HOME > $null
	mkdir $Env:LLVM_HOME > $null
	
	# clone ISPC
	git clone --recurse-submodules $Env:ISPC_URL $Env:ISPC_HOME
	
	# call alloy.py to pull, patch and build llvm
	cd $Env:ISPC_HOME
	python alloy.py -b --version=$Env:LLVM_VERSION --verbose
	
	# mark these directories as safe with git
	# on windows the this container username will change from
	# run to run as the container is transient.  This allows 
	# that to happen and prevents git from having a fit about it.
	git config --global --add safe.directory "$Env:ISPC_HOME"
	git config --global --add safe.directory "$Env:LLVM_HOME"
	
	# generate solution
	cmake -G "Visual Studio 17" -Thost=x64 -DCMAKE_INSTALL_PREFIX="$Env:ISPC_INSTALL_HOME" `
		-DISPC_INCLUDE_EXAMPLES="$Env:ISPC_INCLUDE_EXAMPLES" -DISPC_INCLUDE_TESTS="$Env:ISPC_INCLUDE_TESTS" `
		-DISPC_INCLUDE_UTILS="$Env:ISPC_INCLUDE_UTILS" -H"$Env:ISPC_HOME" -B"$Env:ISPC_HOME\build"
	
	# call build and exit
	build

	return
}

function build()
{
	# verify the directories exist, if not exit with error
	if(!(Test-Path "$Env:ISPC_HOME") -or !(Test-Path "$Env:LLVM_HOME")) {
		Write-Host "Cannot perform build as ISPC_HOME and LLVM_HOME directories do not exist."
		PrintHelp
		exit 1
	}
	
	# if the build directory doesn't exist create it
	if(!(Test-Path "$Env:ISPC_BUILD_DIR")) {
		mkdir $Env:ISPC_HOME\\build > $null
	}
	
	# build ispc for the given target specified in environment variables
	cmake --build c:\ispc\ispc\build --target "$Env:ISPC_TARGET" --config "$Env:ISPC_CONFIG"
	
	return
}

function clean()
{
	# verify the directories exist, if not exit with error
	if(!(Test-Path "$Env:ISPC_HOME") -or !(Test-Path "$Env:LLVM_HOME")) {
		Write-Host "Cannot perform clean as ISPC_HOME and LLVM_HOME directories do not exist."
		PrintHelp
		exit 1
	}
	
	# call cmake clean
	cmake --build c:\ispc\ispc\build --target clean
	
	# rebuild the solution
	cmake --fresh -G "Visual Studio 17" -Thost=x64 -DCMAKE_INSTALL_PREFIX="$Env:ISPC_INSTALL_HOME" `
		-DISPC_INCLUDE_EXAMPLES="$Env:ISPC_INCLUDE_EXAMPLES" -DISPC_INCLUDE_TESTS="$Env:ISPC_INCLUDE_TESTS" `
		-DISPC_INCLUDE_UTILS="$Env:ISPC_INCLUDE_UTILS" -H"$Env:ISPC_HOME" -B"$Env:ISPC_HOME\build"
	
	return
}

function rebuild()
{
	# verify the directories exist, if not exit with error
	if(!(Test-Path "$Env:ISPC_HOME") -or !(Test-Path "$Env:LLVM_HOME")) {
		Write-Host "Cannot perform rebuild as ISPC_HOME and LLVM_HOME directories do not exist."
		PrintHelp
		exit 1
	}
	
	# call clean
	clean
	
	# call build
	build
	
	return
}

$StopWatch = New-Object System.Diagnostics.Stopwatch
$StopWatch.Start()

# get the first parameter - that's all we care about
$param1=$args[0]

if ( $param1 -eq $null -or $args.Count -gt 1 )
{
	Write-Host "Error: no commands specified, or number of commands exceeds one."
	
	printHelp
}

if ( $param1 -ieq "setup" ) {
	Write-Host "Setup Called"
	setup
}

if ( $param1 -ieq "build" ) {
	Write-Host "Build Called"
	build
}

if ( $param1 -ieq "clean" ) {
	Write-Host "Clean Called"
	clean
}

if ( $param1 -ieq "rebuild" ) {
	Write-Host "Rebuild Called"
	rebuild
}

if ( $param1 -ieq "/?" -or $param1 -ieq "-?" -or $param1 -ieq "-h" -or $param1 -ieq "--?" ) {
	PrintHelp
	powershell
}

$StopWatch.Stop()

Write-Host "Time elapsed: " $StopWatch.Elapsed