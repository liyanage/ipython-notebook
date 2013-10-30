#!/bin/sh

set -e
set -x

# Using a git archive until OpenCV 2.4.7 is released, because of http://code.opencv.org/issues/3191
USE_GIT=true

if $USE_GIT; then
    VERSION=2.4
else
    VERSION=2.4.6
fi
VERSION_DIR=$VERSION
SOURCEDIR=opencv-$VERSION

DOWNLOAD_DIR="$TARGET_TEMP_DIR"
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

if $USE_GIT; then
    ZIPFILE=$SOURCEDIR.zip
    if [ ! -e $ZIPFILE ]; then
        curl -L --fail -o $ZIPFILE https://github.com/Itseez/opencv/archive/$VERSION.zip
    fi
else
    TARBALL=$SOURCEDIR.tar.gz
    if [ ! -e $TARBALL ]; then
        curl -L --fail -o $TARBALL http://superb-dca3.dl.sourceforge.net/project/opencvlibrary/opencv-unix/$VERSION_DIR/$TARBALL
    fi
fi


if [ ! -d cmake-* ]; then
    curl -L --fail -o cmake.tar.gz http://www.cmake.org/files/v2.8/cmake-2.8.11-Darwin64-universal.tar.gz
    tar -xf cmake.tar.gz
fi


export CMAKE=$(echo "$DOWNLOAD_DIR"/cmake-*/CMake*.app/Contents/bin/cmake)
[ -e "$CMAKE" ]

echo $MACOSX_DEPLOYMENT_TARGET

rm -rf opencv-$VERSION_DIR

if $USE_GIT; then
    unzip "$ZIPFILE"
else
    tar -xf $TARBALL
fi

cd opencv-$VERSION_DIR

rm -rf build
mkdir build
cd build

LIBPNG_INSTALL=$(dirname "$SCRIPT_OUTPUT_FILE_0")/libpng

"$CMAKE" -G "Unix Makefiles" \
-D CMAKE_LIBRARY_PATH="$LIBPNG_INSTALL/lib" \
-D CMAKE_INCLUDE_PATH="$LIBPNG_INSTALL/include" \
-D CMAKE_INSTALL_PREFIX="$SCRIPT_OUTPUT_FILE_0" \
-D WITH_QT=OFF \
-D BUILD_DOCS=OFF \
-D BUILD_PERF_TESTS=OFF \
-D BUILD_opencv_apps=OFF \
-D BUILD_PNG=OFF \
-D BUILD_opencv_java=OFF \
-D PYTHON_EXECUTABLE=/usr/bin/python \
..

make -j $(sysctl hw.ncpu | awk '{print $2}') install

touch "$SCRIPT_OUTPUT_FILE_0"

