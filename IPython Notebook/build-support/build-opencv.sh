#!/bin/sh

set -e
set -x

VERSION_DIR=2.4.4
VERSION=2.4.4a
SOURCEDIR=OpenCV-$VERSION
TARBALL=$SOURCEDIR.tar.bz2
DOWNLOAD_DIR="$TARGET_TEMP_DIR"
mkdir -p "$DOWNLOAD_DIR"

cd "$DOWNLOAD_DIR"
if [ ! -e $TARBALL ]; then
	curl -L --fail -o $TARBALL http://downloads.sourceforge.net/project/opencvlibrary/opencv-unix/$VERSION_DIR/$TARBALL
fi

if [ ! -d cmake-* ]; then
    curl -L --fail -o cmake.tar.gz http://www.cmake.org/files/v2.8/cmake-2.8.10.2-Darwin64-universal.tar.gz
    tar -xf cmake.tar.gz
fi
export CMAKE=$(echo "$DOWNLOAD_DIR"/cmake-*/CMake*.app/Contents/bin/cmake)
[ -e "$CMAKE" ]

echo $MACOSX_DEPLOYMENT_TARGET
rm -rf opencv-$VERSION_DIR
tar -xf $TARBALL
cd opencv-$VERSION_DIR
mkdir build
cd build

LIBPNG_INSTALL=$(dirname "$SCRIPT_OUTPUT_FILE_0")/libpng

"$CMAKE" -G "Unix Makefiles" \
-D CMAKE_LIBRARY_PATH="$LIBPNG_INSTALL/lib" \
-D CMAKE_INCLUDE_PATH="$LIBPNG_INSTALL/include" \
-D CMAKE_INSTALL_PREFIX="$SCRIPT_OUTPUT_FILE_0" \
-D BUILD_PNG=OFF \
-D BUILD_opencv_java=OFF \
-D BUILD_PYTHON_SUPPORT=ON \
..

make -j $(sysctl hw.ncpu | awk '{print $2}') install

touch "$SCRIPT_OUTPUT_FILE_0"

