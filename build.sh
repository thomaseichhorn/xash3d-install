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
	ext=.dll
elif [ "$(expr substr $(uname -s) 1 10)" = "MINGW64_NT" ]; then
	machine=Win64
	ext=.dll
elif [ "$(uname -sm)" = "Linux x86_64" ]; then
	machine=Linux64
	ext=.so
elif [ "$(uname -sm)" = "Linux i686" ]; then
	machine=Linux32
	ext=.so
elif [ "$(uname -sm)" = "Linux armv6l" ] || [ "$(uname -sm)" = "Linux armv7l" ]; then
	# pi uses v6, even on pi2/3/4?
	machine=LinuxArm
	arch=_armv6hf
	ext=.so
else
	echo "Can't get machine identity, exiting!"
	exit
fi
echo
echo "Running $machine"

# Linux: install packages and set paths
if [ "$(expr substr $machine 1 5)" = "Linux" ]; then
	echo
	read -p 'Install packages? [y/N] ' installpkg
	if [ "$installpkg" = "y" ] || [ "$installpkg" = "Y" ]; then

		echo
		echo "Installing packages..."
		if [ -n "$(command -v apt-get)" ]; then
			sudo apt update
			if [ "$machine" = "LinuxArm" ]; then
				sudo apt install libfontconfig1-dev git build-essential cmake libsdl2-dev
			elif [ "$machine" = "Linux32" ] || [ "$machine" = "Linux64" ]; then
				sudo apt install libfontconfig1-dev git build-essential cmake libfreetype6-dev:i386 gcc-multilib g++-multilib libsdl2-dev:i386 libfontconfig-dev:i386
			fi
		elif [ -n "$(command -v yum)" ]; then
			sudo yum check-update
			sudo yum install epel-release
			sudo yum config-manager --set-enabled powertools
			sudo yum update
			sudo yum install cmake gcc-c++ freetype-devel urw-fonts git libgcc.{i686,x86_64} glibc-devel.{i686,x86_64} libstdc++-devel.{i686,x86_64} libxml2-devel.{i686,x86_64} fontconfig.{i686,x86_64} fontconfig-devel.{i686,x86_64} fontconfig-devel pkgconf.{i686,x86_64} freetype-devel.{i686,x86_64} SDL2-devel.{i686,x86_64} mesa-dri-drivers.{i686,x86_64}
		else
			echo
			echo "Neither apt nor yum found, please install packages by hand!"
			exit
		fi
	fi

	# Find where we are
	basedir=$PWD
	gamedir=$basedir/HL
	mkdir -p $gamedir
	sourcedir=$basedir/sources
	mkdir -p $sourcedir
	addondir=$basedir/buildfiles
	echo
	echo "Installing to $gamedir"
	echo "Sources will be downloaded to $sourcedir"

	echo
	read -p 'Build Xash3D? [y/N] ' buildxash

	if [ "$buildxash" = "y" ] || [ "$buildxash" = "Y" ]; then

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

		engineversion=new

		# Engine version check
		if [ "$engineversion" = "old" ]; then
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

		else

			git clone --recursive https://github.com/thomaseichhorn/xash3d-fwgs.git $xash3ddir
			cd $xash3ddir
                        if [ "$machine" = "LinuxArm" ] || [ "$machine" = "Linux32" ]; then
				./waf configure -T release --prefix=$gamedir --enable-gles1 --disable-gl --disable-vgui
                        elif [ "$machine" = "Linux64" ]; then
				./waf configure -T release --prefix=$gamedir
			fi
			./waf build
			./waf install
		fi

	fi

	echo
	read -p 'Build HL SDK? [y/N] ' buildhlsdk

	if [ "$buildhlsdk" = "y" ] || [ "$buildhlsdk" = "Y" ]; then

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
		cp cl_dll/client.so $addondir/valve/cl_dlls/client$arch$ext
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
		cp cl_dll/client.so $addondir/dmc/cl_dlls/client$arch$ext
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
		cp cl_dll/client.so $addondir/gearbox/cl_dlls/client$arch$ext
		cp dlls/opfor.so $addondir/gearbox/dlls/opfor.so

		# Bshift
		cd $hlsdkdir
		git checkout --track origin/bshift
		git submodule init
		git submodule update
		cd build
		rm -rf *
		cmake ..
		make -j$(nproc)
		cp cl_dll/client.so $addondir/bshift/cl_dlls/client$arch$ext
		cp dlls/bshift.so $addondir/bshift/dlls/bshift.so

		git checkout master

	fi

	echo
	read -p 'Build CS Client? [y/N] ' buildcs

	if [ "$buildcs" = "y" ] || [ "$buildcs" = "Y" ]; then

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
		cp libclient.so $addondir/cstrike/cl_dlls/client$arch$ext

	fi

	echo
	read -p 'Build Parabot? [y/N] ' buildbot

	if [ "$buildbot" = "y" ] || [ "$buildbot" = "Y" ]; then

		cd $sourcedir
		botdir=$sourcedir/Parabot
		# If the source already exists, delete
		if [ -d "$botdir" ]; then
			rm -Rf $botdir
		fi
		git clone https://github.com/thomaseichhorn/Parabot.git $botdir
		cd $botdir/dlls
		if [ "$(make -j$(nproc))" ]; then
			# Replace liblist.gam entries
			sed -i '13s/.*/gamedll_linux "addons\/parabot\/dlls\/parabot.so"/' $addondir/dmc/liblist.gam
			sed -i '11s/.*/gamedll_linux "addons\/parabot\/dlls\/parabot.so"/' $addondir/gearbox/liblist.gam
			sed -i '9s/.*/gamedll_linux "addons\/parabot\/dlls\/parabot.so"/' $addondir/valve/liblist.gam
			cp parabot.so ../addons/parabot/dlls/parabot$arch$ext
			cp -R ../addons/ $addondir/dmc/.
			cp -R ../addons/ $addondir/gearbox/.
			cp -R ../addons/ $addondir/valve/.
		else
			echo "Couldn't build Parabot!"
		fi
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
	echo "Finished build!"
	echo
	echo "Now copy your valve (optional: and bshift, cstrike, dmc, gearbox) folder to $gamedir."
	echo "Then copy the contents of the folder $addondir to $gamedir, overwriting all files."
	exit $?

fi

if [ "$machine" = "Win32" ]; then

	# Default environment:
	export PATH="$PATH:/C/Program Files (x86)/mingw-w64/i686-8.1.0-posix-dwarf-rt_v6-rev0/mingw32/bin"

	# Find where we are
	basedir="$PWD"
	gamedir="$basedir/HL"
	mkdir -p "$gamedir"
	sourcedir="$basedir/sources"
	mkdir -p "$sourcedir"
	addondir="$basedir/buildfiles"
	echo
	echo "Installing to $gamedir"
	echo "Sources will be downloaded to $sourcedir"

	echo
	read -p 'Build Xash3D? [y/N] ' buildxash

	if [ "$buildxash" = "y" ] || [ "$buildxash" = "Y" ]; then

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
	read -p 'Build HL SDK? [y/N] ' buildhlsdk

	if [ "$buildhlsdk" = "y" ] || [ "$buildhlsdk" = "Y" ]; then

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
		cp dlls/opfor.dll "$addondir/gearbox/dlls/opfor.dll"

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
		cp dlls/bshift.dll "$addondir/bshift/dlls/bshift.dll"

		git checkout master

	fi

	echo
	read -p 'Build CS Client? [y/N] ' buildcs

	if [ "$buildcs" = "y" ] || [ "$buildcs" = "Y" ]; then

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
	read -p 'Build Parabot? [y/N] ' buildbot

	if [ "$buildbot" = "y" ] || [ "$buildbot" = "Y" ]; then

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
		sed -i '12s/.*/gamedll "addons\\parabot\\dlls\\parabot.dll"/' $addondir/dmc/liblist.gam
		sed -i '10s/.*/gamedll "addons\\parabot\\dlls\\parabot.dll"/' $addondir/gearbox/liblist.gam
		sed -i '8s/.*/gamedll "addons\\parabot\\dlls\\parabot.dll"/' $addondir/valve/liblist.gam
	fi

	echo "#!/bin/bash" > $gamedir/run.sh
	echo "cd $gamedir" >> $gamedir/run.sh
	echo "export LIBGL_FB=1" >> $gamedir/run.sh
	echo "export LIBGL_BATCH=1" >> $gamedir/run.sh
	echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$gamedir" >> $gamedir/run.sh
	echo "./xash.exe -console -debug" >> $gamedir/run.sh

	echo "#!/bin/bash" > $gamedir/server.sh
	echo "cd $gamedir" >> $gamedir/server.sh
	echo "export LIBGL_FB=1" >> $gamedir/server.sh
	echo "export LIBGL_BATCH=1" >> $gamedir/server.sh
	echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$gamedir" >> $gamedir/server.sh
	echo "./xash.exe -console -dev 5 -dedicated +exec server.cfg +maxplayers 32" >> $gamedir/server.sh

	echo
	echo "Finished build!"
	echo
	echo "Now copy your valve (optional: and bshift, cstrike, dmc, gearbox) folder to $gamedir."
	echo "Then copy the contents of the folder $addondir to $gamedir, overwriting all files."
	exit $?

fi

# Windows with no compiler and/or tools
:SCRIPTWIN
ECHO Running %COMSPEC%! You need to install mingw64, cmake and git!
PAUSE
