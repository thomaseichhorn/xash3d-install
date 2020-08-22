: # Detect if Windows batch, if so goto end section
:<<"::CMDLITERAL"
@ECHO OFF
GOTO :SCRIPTWIN
::CMDLITERAL

#!/usr/bin/env bash

# Check machine architecture
if [ "$(uname)" = "Darwin" ]; then
	machine=OSX
	echo "OSX is not supported!"
	exit
elif [ "$(expr substr $(uname -s) 1 10)" = "MINGW32_NT" ]; then
	machine=Win32
elif [ "$(expr substr $(uname -s) 1 10)" = "MINGW64_NT" ]; then
	machine=Win64
elif [ "$(uname -sm)" = "Linux x86_64" ]; then
	machine=Linux64
elif [ "$(uname -sm)" = "Linux i686" ]; then
	machine=Linux32
elif [ "$(uname -sm)" = "Linux armv7l" ]; then
	machine=LinuxArm
else
	echo "Can't get machine identity, exiting!"
	exit
fi
echo
echo "Running $machine"

# Linux: install packages and set paths
if [ "$(expr substr $machine 1 5)" = "Linux" ]; then
	echo 
	read -p 'Install packages? ' installpkg
	if [ "$installpkg" = "y" ]; then

		echo
		echo "Installing packages..."
		if [ -n "$(command -v apt-get)" ]; then
			arch=Debian
			sudo apt-get update
			if [ "$machine" = "LinuxArm" ]; then
				sudo apt-get install libfontconfig1-dev git build-essential cmake
			elif [ "$machine" = "Linux32" ] || [ "$machine" = "Linux64" ]; then
				sudo apt-get install libfontconfig1-dev git build-essential cmake libfreetype6-dev:i386 gcc-multilib g++-multilib libsdl2-dev:i386 libfontconfig-dev:i386
			fi
						
		elif [ -n "$(command -v yum)" ]; then
			arch=RHEL
			sudo yum check-update
			sudo yum install epel-release
			sudo yum config-manager --set-enabled PowerTools
			sudo yum update
			sudo yum install urw-fonts git libgcc.i686 glibc-devel.i686 libstdc++-devel.i686 libxml2-devel.i686 fontconfig.i686 fontconfig-devel.i686 fontconfig-devel pkgconf.i686 freetype-devel.i686 SDL2-devel.i686 mesa-dri-drivers.i686
		else
			echo
			echo "Neither apt nor yum found, please install packages by hand!"
			exit
		fi
	fi

	# Find where we are
	basedir=$PWD
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

		# ARM needs SDL
		if [ "$machine" = "LinuxArm" ]; then
			wget http://www.libsdl.org/release/SDL2-2.0.10.tar.gz
			tar xvf SDL2-2.0.10.tar.gz
			cd SDL2-2.0.10
			mkdir -p build
			cd build
			cmake ..
			make -j$(nproc)
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

		make -j$(nproc)

		cp engine/libxash.so $gamedir
		cp game_launch/xash3d $gamedir
		cp mainui/libxashmenu.so $gamedir

	fi

	echo 
	read -p 'Build HL SDK? ' buildhlsdk

	if [ "$buildhlsdk" = "y" ]; then

		# First (default) valve
		cd $sourcedir
		hlsdkdir=$sourcedir/hlsdk-xash3d
		# If the source already exists, delete
		if [ -d "$hlsdkdir" ]; then
			rm -Rf $hlsdkdir
		fi
		git clone --recursive https://github.com/thomaseichhorn/hlsdk-xash3d.git $hlsdkdir
		cd $hlsdkdir
		git fetch origin
		git remote add upstream https://github.com/FWGS/hlsdk-xash3d.git
		git submodule init
		git submodule update
		mkdir -p build
		cd build
		cmake ..
		make -j$(nproc)
		cp cl_dll/client.so $gamedir
		cp dlls/hl.so $gamedir
		cp cl_dll/client.so $addondir/valve/cl_dlls/client.so
		cp dlls/hl.so $addondir/valve/dlls/hl.so

		# DMC
		cd $hlsdkdir
		git checkout --track origin/dmc
		git submodule init
		git submodule update
		cd build
		rm -rf *
		cmake ..
		make -j$(nproc)
		cp cl_dll/client.so $addondir/dmc/cl_dlls/client.so
		cp dlls/hl.so $addondir/dmc/dlls/dmc.so

		# OpFor
		cd $hlsdkdir
		git checkout --track origin/opfor
		git submodule init
		git submodule update
		cd build
		rm -rf *
		cmake ..
		make -j$(nproc)
		cp cl_dll/client.so $addondir/gearbox/cl_dlls/client.so
		cp dlls/hl.so $addondir/gearbox/dlls/opfor.so

		# Bshift
		cd $hlsdkdir
		git checkout --track origin/bshift
		git submodule init
		git submodule update
		cd build
		rm -rf *
		cmake ..
		make -j$(nproc)
		cp cl_dll/client.so $addondir/bshift/cl_dlls/client.so
		cp dlls/hl.so $addondir/bshift/dlls/bshift.so

		git checkout master

	fi

	echo 
	read -p 'Build CS Client? ' buildcs

	if [ "$buildcs" = "y" ]; then

		cd $sourcedir
		csdir=$sourcedir/cs16-client
		# If the source already exists, delete
		if [ -d "$csdir" ]; then
			rm -Rf $csdir
		fi
		git clone https://github.com/thomaseichhorn/cs16-client.git $csdir
		cd $csdir/cl_dll
		mkdir build
		cd build
		cmake ..
		make -j$(nproc)
		cp libclient.so $addondir/cstrike/cl_dlls/client.so

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
		make -j$(nproc)
		cp parabot.so ../addons/parabot/dlls/.
		cp -R ../addons/ $addondir/dmc/.
		cp -R ../addons/ $addondir/gearbox/.
		cp -R ../addons/ $addondir/valve/.

		# Replace liblist.gam entries
		sed -i 's/gamedll_linux "dlls\/dmc.so"/\/\/gamedll_linux "dlls\/dmc.so""/g' $addondir/dmc/liblist.gam
		sed -i 's/gamedll_linux "dlls\/opfor.so"/\/\/gamedll_linux "dlls\/opfor.so"/g' $addondir/gearbox/liblist.gam
		sed -i 's/gamedll_linux "dlls\/hl.so"/\/\/gamedll_linux "dlls\/hl.so"/g' $addondir/valve/liblist.gam
		echo "gamedll_linux "addons/parabot/dlls/parabot.so"" >> $addondir/dmc/liblist.gam
		echo "gamedll_linux "addons/parabot/dlls/parabot.so"" >> $addondir/gearbox/liblist.gam
		echo "gamedll_linux "addons/parabot/dlls/parabot.so"" >> $addondir/valve/liblist.gam
	fi

	echo "#!/bin/bash" > $gamedir/run.sh
	echo "cd $gamedir" >> $gamedir/run.sh
	echo "export LIBGL_FB=1" >> $gamedir/run.sh
	echo "export LIBGL_BATCH=1" >> $gamedir/run.sh
	echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$gamedir" >> $gamedir/run.sh
	echo "./xash3d -console -debug" >> $gamedir/run.sh

	echo "#!/bin/bash" > $gamedir/server.sh
	echo "cd $gamedir" >> $gamedir/server.sh
	echo "export LIBGL_FB=1" >> $gamedir/server.sh
	echo "export LIBGL_BATCH=1" >> $gamedir/server.sh
	echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$gamedir" >> $gamedir/server.sh
	echo "./xash3d -console -dev 5 -dedicated +exec server.cfg +maxplayers 32" >> $gamedir/server.sh

	echo
	echo "Done!"
	exit $?

fi

if [ "$machine" = "Win32" ]; then

	# Find where we are
	basedir="$PWD"
	addondir="$basedir/addons"
	gamedir="$basedir/HL"
	mkdir -p "$gamedir"
	sourcedir="$basedir/sources"
	mkdir -p "$sourcedir"
	echo
	echo "Installing to $gamedir"
	echo "Sources will be downloaded to $sourcedir"

	echo
	read -p 'Build Xash3D? ' buildxash

	if [ "$buildxash" = "y" ]; then

		cd "$sourcedir"

		xash3ddir="$sourcedir/xash3d"
		# If the source already exists, delete
		if [ -d "$xash3ddir" ]; then
			rm -Rf "$xash3ddir"
		fi
		git clone --recursive https://github.com/thomaseichhorn/xash3d.git "$xash3ddir"
		cd "$xash3ddir/engine"
		git clone https://github.com/thomaseichhorn/nanogl.git
		cd ..
		git clone https://github.com/thomaseichhorn/halflife.git hlsdk/
		mkdir -p build
		cd build

		cmake .. -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND"

		mingw32-make -j$(nproc)

		cp engine/xash_sdl.dll "$gamedir"
		cp game_launch/xash.exe "$gamedir"
		cp mainui/menu.dll "$gamedir"
		cp SDL2/SDL2-2.0.7/i686-w64-mingw32/bin/SDL2.dll "$gamedir"
		cp VGUI/vgui-dev-master/lib/win32_vc6/vgui.dll "$gamedir"
		cp vgui_support_prebuilt/vgui_support_bin-master/vgui_support.dll "$gamedir"

	fi

	echo 
	read -p 'Build HL SDK? ' buildhlsdk

	if [ "$buildhlsdk" = "y" ]; then

		# First (default) valve
		cd "$sourcedir"
		hlsdkdir="$sourcedir/hlsdk-xash3d"
		# If the source already exists, delete
		if [ -d "$hlsdkdir" ]; then
			rm -Rf "$hlsdkdir"
		fi
		git clone --recursive https://github.com/thomaseichhorn/hlsdk-xash3d.git "$hlsdkdir"
		cd "$hlsdkdir"
		git fetch origin
		git remote add upstream https://github.com/FWGS/hlsdk-xash3d.git
		git submodule init
		git submodule update
		mkdir -p build
		cd build
		cmake .. -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND"
		mingw32-make -j$(nproc)
		cp cl_dll/client.dll "$gamedir"
		cp dlls/hl.dll "$gamedir"
		cp cl_dll/client.dll "$addondir/valve/cl_dlls/client.dll"
		cp dlls/hl.dll "$addondir/valve/dlls/hl.dll"

		# DMC
		cd "$hlsdkdir"
		git checkout --track origin/dmc
		git submodule init
		git submodule update
		cd build
		rm -rf *
		cmake .. -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND"
		mingw32-make -j$(nproc)
		cp cl_dll/client.dll "$addondir/dmc/cl_dlls/client.dll"
		cp dlls/hl.dll "$addondir/dmc/dlls/dmc.dll"

		# OpFor
		cd "$hlsdkdir"
		git checkout --track origin/opfor
		git submodule init
		git submodule update
		cd build
		rm -rf *
		cmake .. -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND"
		mingw32-make -j$(nproc)
		cp cl_dll/client.dll "$addondir/gearbox/cl_dlls/client.dll"
		cp dlls/hl.dll "$addondir/gearbox/dlls/opfor.dll"

		# Bshift
		cd "$hlsdkdir"
		git checkout --track origin/bshift
		git submodule init
		git submodule update
		cd build
		rm -rf *
		cmake .. -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND"
		mingw32-make -j$(nproc)
		cp cl_dll/client.dll "$addondir/bshift/cl_dlls/client.dll"
		cp dlls/hl.dll "$addondir/bshift/dlls/bshift.dll"

		git checkout master

	fi

	echo 
	read -p 'Build CS Client? ' buildcs

	if [ "$buildcs" = "y" ]; then

		cd "$sourcedir"
		csdir="$sourcedir/cs16-client"
		# If the source already exists, delete
		if [ -d "$csdir" ]; then
			rm -Rf "$csdir"
		fi
		git clone https://github.com/thomaseichhorn/cs16-client.git "$csdir"
		cd "$csdir/cl_dll"
		mkdir build
		cd build
		cmake .. -G "MinGW Makefiles" -DCMAKE_SH="CMAKE_SH-NOTFOUND"
		mingw32-make -j$(nproc)
		cp libclient.dll $addondir/cstrike/cl_dlls/client.dll

	fi

	echo 
	read -p 'Build Parabot? ' buildbot

	if [ "$buildbot" = "y" ]; then

		cd "$sourcedir"
		botdir="$sourcedir/Parabot"
		# If the source already exists, delete
		if [ -d "$botdir" ]; then
			rm -Rf "$botdir"
		fi
		git clone https://github.com/thomaseichhorn/Parabot.git "$botdir"
		cd "$botdir/dlls"
		mingw32-make -j$(nproc)
		cp parabot.dll ../addons/parabot/dlls/.
		cp -R ../addons/ $addondir/dmc/.
		cp -R ../addons/ $addondir/gearbox/.
		cp -R ../addons/ $addondir/valve/.

		# Replace liblist.gam entries
		echo "gamedll "addons\parabot\dlls\parabot.so"" >> "$addondir/dmc/liblist.gam"
		echo "gamedll "addons\parabot\dlls\parabot.so"" >> "$addondir/gearbox/liblist.gam"
		echo "gamedll "addons\parabot\dlls\parabot.so"" >> "$addondir/valve/liblist.gam"
	fi

	echo
	echo "Done!"

fi

# Windows with no compiler and/or tools
:SCRIPTWIN
ECHO Running %COMSPEC%! You need to install mingw64, cmake and git!
PAUSE
