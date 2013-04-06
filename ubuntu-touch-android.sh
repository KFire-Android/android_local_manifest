#!/bin/bash

usage(){
	cat <<EOF
usage: $(basename $0) <-d DEVICE> [-v VENDORS] [-h] [-j JOBS] [-p BUILD_JOBS] [-c] [-r REFERENCE]

Phablet build script

Required arguments:
	-d DEVICE			Target device to build

Optional arguments:
	-v VENDORS			Comma separated list of devices to Setup such as
						maguro, manta, mako, grouper
	-h HELP				Show this help message and exit
	-j JOBS				Amount of sync jobs
	-c CONTINUE			Continue a previously started sync
	-r REFERENCE		Use another dev enviroment as reference for git
	-l LOCAL_MANIFEST 	Local manifest address
	-p BUILD_JOBS		Amount of build jobs

EOF
	exit 1
}

JOBS=""
CONTINUE=0
REFERENCE=""
LOCAL_MANIFEST=""
BUILD_JOBS=$(grep processor /proc/cpuinfo | wc -l)

while getopts hd:v:j:cr:l:p: opt; do
	case $opt in
		h) usage;;
		d) DEVICE=$OPTARG;;
		v) VENDORS=$OPTARG;;
		j) JOBS=$OPTARG;;
		c) CONTINUE=1;;
		r) REFERENCE=$OPTARG;;
		l) LOCAL_MANIFEST=$OPTARG;;
		p) BUILD_JOBS=$OPTARG;;
		*) usage;;
	esac
done

[ "$DEVICE" == "" ] && usage

# check if is root
if [ "$(id -u)" == "0" ]; then
	SUDO=""
else
	SUDO="sudo"
fi

builddir=phablet-build-$DEVICE

[ "$(dpkg --print-architecture)" == "amd64" ] || exit 1

# set up multiarch
dpkg --print-foreign-architectures | grep -q i386 || dpkg --add-architecture i386
$SUDO apt-get update

# add cross build env including the needed i386 packages
$SUDO apt-get -y install git gnupg flex bison gperf build-essential \
    zip bzr curl libc6-dev libncurses5-dev:i386 x11proto-core-dev \
    libx11-dev:i386 libreadline6-dev:i386 libgl1-mesa-glx:i386 \
    libgl1-mesa-dev g++-multilib mingw32 tofrodos phablet-tools \
    python-markdown libxml2-utils xsltproc zlib1g-dev:i386 schedtool \
	openjdk-6-jdk

# get the git tree
[ "$VENDORS" == "" ] || ARGS=" -v $VENDORS"
[ "$JOBS" == "" ] || ARGS="$ARGS -j $JOBS"
[ "$CONTINUE" == "0" ] || ARGS="$ARGS -c"
[ "$REFERENCE" == "" ] || ARGS="$ARGS -r $REFERENCE"
phablet-dev-bootstrap $ARGS $builddir

cd $builddir
repo forall -c 'git reset --hard && git clean -xdf'

# get local manifest
[ "$LOCAL_MANIFEST" == "" ] || curl -L -o .repo/local_manifest.xml -O -L $LOCAL_MANIFEST

[ "$JOBS" == "" ] || JOBS=" -j $JOBS"
repo sync $JOBS

. build/envsetup.sh
brunch $DEVICE -j $BUILD_JOBS

cd -
cp $builddir/out/target/product/$DEVICE/*-*$DEVICE.zip ./livecd.ubuntu-touch-$DEVICE.zip
for image in system recovery boot; do
	cp $builddir/out/target/product/$DEVICE/$image.img ./livecd.ubuntu-touch-$DEVICE.$image.img
done
#rm -rf $builddir
