#!/bin/bash
function quit(){
	local ret=$?
	if [ "$ret" != "0" ]; then
		echo "[ERROR] ret=$ret"
		shift
		echo $@
		exit $ret
	fi
}

function check_enviroment(){
	PACKAGES="git gnupg flex bison gperf build-essential zip bzr curl libc6-dev libncurses5-dev:i386 x11proto-core-dev libx11-dev:i386 libreadline6-dev:i386 libgl1-mesa-glx:i386 libgl1-mesa-dev g++-multilib mingw32 tofrodos python-markdown libxml2-utils xsltproc zlib1g-dev:i386 schedtool"
	for package in ${PACKAGES}; do
		dpkg -l | grep ${package} > /dev/null
		quit $?
	done
}

function main(){
	BUILD_DIR=~/kindle-build
	LOG=${BUILD_DIR}/log.log

	if [ "$#" == "1" ]; then
		TARGET=$1
	else
		TARGET=jem
	fi

	echo "Check git config"
	git config --get user.name > /dev/null
	quit $? "Not set user.name in gitconfig"
	git config --get user.email > /dev/null
	quit $? "Not set user.email in gitconfig"

	echo "Check build enviroment"
	#check_enviroment

	echo "Init"
	mkdir -p ${BUILD_DIR}/.repo
	cd ${BUILD_DIR}

	repo init -u git://github.com/CyanogenMod/android.git -b cm-10.1

	CPUCORES=$(grep processor /proc/cpuinfo | wc -l)
	if [ "${CPUCORES}" -ge "8" ]; then
		JOBS=8
	else
		JOBS=${CPUCORES}
	fi

	echo "Init customized manifest"
	curl -L -o .repo/local_manifest.xml -O -L https://raw.github.com/KFire-Android/android_local_manifest/cm-10.1/local_manifest.xml
	quit $?
	repo sync -j${JOBS}
	quit $?

	vendor/cm/get-prebuilts

	echo "Start build"
	. build/envsetup.sh
	rm -rf $LOG && time brunch ${TARGET} -j${CPUCORES} 2>&1 | tee -a $LOG
}

main $@
