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
	BUILD_DIR=~/phablet
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

	echo "Init phablet"
	mkdir -p ${BUILD_DIR}/.repo
	[ -d "${BUILD_DIR}/../phablet_projects" ] && mv ${BUILD_DIR}/../phablet_projects ${BUILD_DIR}/.repo/
	CPUCORES=$(grep processor /proc/cpuinfo | wc -l)
	if [ "${CPUCORES}" -ge "8" ]; then
		JOBS=8
	else
		JOBS=${CPUCORES}
	fi
	phablet-dev-bootstrap ${BUILD_DIR} -j${JOBS} -c
	quit $?

	echo "Init customized manifest"
	cd ${BUILD_DIR}
	curl -L -o .repo/local_manifest.xml -O -L https://raw.github.com/JoeyJiao/android_local_manifest/phablet/local_manifest.xml
	quit $?
	repo sync -j${JOBS}
	quit $?

	echo "Start build"
	. build/envsetup.sh
	rm -rf log.log && time brunch ${TARGET} -j${CPUCORES} 2>&1 | tee -a log.log
	[ -d "${BUILD_DIR}/.repo/projects" ] && mv ${BUILD_DIR}/.repo/projects ${BUILD_DIR}/../phablet_projects/
}

main $@
