#!/usr/bin/env bash

# Check machine architecture
if [ "$(uname)" == "Darwin" ]; then
	machine=OSX
	echo "OSX is not supported!"
	exit
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
	machine=Win32
	echo "Windows is not supported!"
	exit
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
	machine=Win64
	echo "Windows is not supported!"
	exit
elif [ "$(uname -sm)" == "Linux x86_64" ]; then
	machine=Linux64
elif [ "$(uname -sm)" == "Linux i686" ]; then
	machine=Linux32
elif [ "$(uname -sm)" == "Linux arm" ]; then
	machine=LinuxArm
else
	echo "Can't get machine identity, exiting!"
	exit
fi
echo "Running $machine"

# Linux: install packages
if [ "$(expr substr $machine 1 5)" == "Linux" ]; then
	echo 
	read -p 'Install packages? ' installpkg
	if [ "$installpkg" = "y" ]; then

		echo
		echo "Installing packages: libfontconfig1-dev git"
		if [ -n "$(command -v apt-get)" ]; then
			sudo apt-get update || echo "Unable to update sources, are you root?"; exit
			sudo apt-get install -y libfontconfig1-dev git || echo "Unable to install packages, are you root?"; exit
		elif [ -n "$(command -v yum)" ]; then
			echo "ToDo!"
		else
			echo "Neither apt nor yum found, please install packages by hand!"
		fi
	fi
fi

# Find where we are
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
addondir=$basedir/addons
gamedir=$basedir/HL
mkdir -p $gamedir
sourcedir=$basedir/sources
mkdir -p $sourcedir
echo
echo "Installing to $gamedir"
echo "Sources will be downloaded to $sourcedir"

echo 
read -p 'Build Xash3D? ' buildxash

if [ "$buildxash" = "y" ]; then

	cd $sourcedir

	# Arm needs SDL
	if [ "$machine" = "LinuxArm" ]; then
		wget http://www.libsdl.org/release/SDL2-2.0.10.tar.gz
		tar xvf SDL2-2.0.10.tar.gz
		cd SDL2-2.0.10
		mkdir -p build
		cd build
		cmake ..
		make
		sudo make install
	fi

	xash3ddir=$sourcedir/xash3d
	# If the source already exists, delete
	if [ -d "$xash3ddir" ]; then
		rm -Rf $xash3ddir
	fi
	git clone --recursive https://github.com/thomaseichhorn/xash3d.git $xash3ddir
	cd $xash3ddir/engine
	git clone https://github.com/thomaseichhorn/nanogl.git
	cd ..
	git clone https://github.com/thomaseichhorn/halflife.git hlsdk/
	mkdir -p build
	cd build

	if [ "$machine" = "LinuxArm" ]; then
		cmake -DHL_SDK_DIR=../hlsdk -DXASH_VGUI=no -DXASH_NANOGL=yes -DXASH_GLES=yes ..
	elif [ "$machine" = "Linux32" ]; then
		cmake -DHL_SDK_DIR=../hlsdk -DXASH_SDL=yes -DXASH_VGUI=yes ..
	elif [ "$machine" = "Linux64" ]; then
		cmake -DHL_SDK_DIR=../hlsdk -DXASH_SDL=yes -DXASH_VGUI=yes -DCMAKE_C_FLAGS="-m32" -DCMAKE_CXX_FLAGS="-m32" -DCMAKE_EXE_LINKER_FLAGS="-m32" ..
	fi

	make

	cp engine/libxash.so $gamedir
	cp game_launch/xash3d $gamedir
	cp mainui/libxashmenu.so $gamedir

fi

echo 
read -p 'Build HLsdk? ' buildhlsdk

if [ "$buildhlsdk" = "y" ]; then

	cd $sourcedir
	hlsdkdir=$sourcedir/hlsdkdir-xash3d
	# If the source already exists, delete
	if [ -d "$hlsdkdir" ]; then
		rm -Rf $hlsdkdir
	fi
	git clone https://github.com/thomaseichhorn/hlsdk-xash3d.git $hlsdkdir
	cd $hlsdkdir
	mkdir -p build
	cd build
	cmake ..
	make
	cp cl_dll/client.so $gamedir
	cp dlls/hl.so $gamedir
fi

echo 
read -p 'Build Parabot? ' buildbot

if [ "$buildbot" = "y" ]; then

	cd $sourcedir
	botdir=$sourcedir/Parabot
	# If the source already exists, delete
	if [ -d "$botdir" ]; then
		rm -Rf $botdir
	fi
	git clone https://github.com/thomaseichhorn/Parabot.git $botdir
	cd $botdir/dlls
	make
	cp parabot.so ../addons/parabot/dlls/.
	cp -R ../addons/ $addondir/.
fi

echo "#!/bin/bash" > $gamedir/run.sh
echo "cd $gamedir" >> $gamedir/run.sh
echo "LIBGL_FB=1" >> $gamedir/run.sh
echo "LIBGL_BATCH=1" >> $gamedir/run.sh
echo "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$gamedir" >> $gamedir/run.sh
echo "./xash3d -console -debug" >> $gamedir/run.sh

echo "Done!"