#!/bin/sh
# A script to download and build libsodium for iOS, including arm64
# Adapted from https://raw2.github.com/seb-m/CryptoPill/master/libsodium.sh

rm -rf libsodium
set -e
curl -O -L https://github.com/jedisct1/libsodium/releases/download/1.0.18-RELEASE/libsodium-1.0.18.tar.gz
tar xzf libsodium-1.0.18.tar.gz
rm libsodium-1.0.18.tar.gz
mv libsodium-1.0.18 libsodium

LIBNAME="libsodium.a"
ARCHS=${ARCHS:-"armv7 armv7s arm64 x86_64"}
DEVELOPER=$(xcode-select -print-path)
LIPO=$(xcrun -sdk iphoneos -find lipo)
#LIPO=lipo
# Script's directory
SCRIPTDIR=$( (cd -P $(dirname $0) && pwd) )
# libsodium root directory
LIBDIR=$( (cd "${SCRIPTDIR}/libsodium"  && pwd) )
# Destination directory for build and install
DSTDIR=${SCRIPTDIR}
BUILDDIR="${DSTDIR}/libsodium_build"
DISTDIR="${DSTDIR}/libsodium_dist"
DISTLIBDIR="${DISTDIR}/lib"
# http://libwebp.webm.googlecode.com/git/iosbuild.sh
# Extract the latest SDK version from the final field of the form: iphoneosX.Y
SDK=$(xcodebuild -showsdks \
    | grep iphoneos | sort | tail -n 1 | awk '{print substr($NF, 9)}'
    )

OTHER_CFLAGS="-Os -Qunused-arguments"

# Cleanup
if [ -d $BUILDDIR ]
then
    rm -rf $BUILDDIR
fi
if [ -d $DISTDIR ]
then
    rm -rf $DISTDIR
fi
mkdir -p $BUILDDIR $DISTDIR

# Generate autoconf files
cd ${LIBDIR}; ./autogen.sh

# Iterate over archs and compile static libs
for ARCH in $ARCHS
do
    BUILDARCHDIR="$BUILDDIR/$ARCH"
    mkdir -p ${BUILDARCHDIR}

    case ${ARCH} in
        armv7)
	    PLATFORM="iPhoneOS"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS}"
	    export LDFLAGS="-mthumb -arch ${ARCH} -isysroot ${ISDKROOT}"
            ;;
        armv7s)
	    PLATFORM="iPhoneOS"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS}"
	    export LDFLAGS="-mthumb -arch ${ARCH} -isysroot ${ISDKROOT}"
            ;;
        arm64)
	    PLATFORM="iPhoneSimulator"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} -miphoneos-version-min=${SDK} ${OTHER_CFLAGS}"
	    export LDFLAGS="-arch ${ARCH}"
            ;;
        x86_64)
	    PLATFORM="iPhoneSimulator"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} -miphoneos-version-min=${SDK} ${OTHER_CFLAGS}"
	    export LDFLAGS="-arch ${ARCH}"
            ;;
        *)
            echo "Unsupported architecture ${ARCH}"
            exit 1
            ;;
    esac

    export PATH="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin:${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/sbin:$PATH"

    echo "Configuring for ${ARCH}..."
    ${LIBDIR}/configure \
	--prefix=${BUILDARCHDIR} \
	--disable-shared \
	--enable-static \
	--host=${HOST}

    echo "Building ${LIBNAME} for ${ARCH}..."
    cd ${LIBDIR}
    make clean
    make -j8 V=0
    make install

    LIBLIST+="${BUILDARCHDIR}/lib/${LIBNAME} "
done

# Copy headers and generate a single fat library file
mkdir -p ${DISTLIBDIR}
${LIPO} -create ${LIBLIST} -output ${DISTLIBDIR}/${LIBNAME}
for ARCH in $ARCHS
do
    cp -R $BUILDDIR/$ARCH/include ${DISTDIR}
    break
done

# Cleanup
rm -rf ${BUILDDIR}
