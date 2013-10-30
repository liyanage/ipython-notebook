#!/bin/sh

set -e
#set -x

SOURCEDIR=libpng-1.6.6
TARBALL=$SOURCEDIR.tar.gz
DOWNLOAD_DIR="$TARGET_TEMP_DIR"
mkdir -p "$DOWNLOAD_DIR"

cd "$DOWNLOAD_DIR"
if [ ! -e $TARBALL ]; then
	curl -L -o $TARBALL http://download.sourceforge.net/libpng/$TARBALL
fi

echo $MACOSX_DEPLOYMENT_TARGET
rm -rf $SOURCEDIR
tar -xzf $TARBALL
cd $SOURCEDIR
rm -rf "$SCRIPT_OUTPUT_FILE_0"
./configure --prefix="$SCRIPT_OUTPUT_FILE_0"
make install
install_name_tool -id "@rpath/libpng.dylib" "$SCRIPT_OUTPUT_FILE_0"/lib/libpng.dylib


