#!/bin/sh

set -e
#set -x

SOURCEDIR=freetype-2.4.11
TARBALL=$SOURCEDIR.tar.gz
DOWNLOAD_DIR="$TARGET_TEMP_DIR"
mkdir -p "$DOWNLOAD_DIR"

cd "$DOWNLOAD_DIR"
if [ ! -e $TARBALL ]; then
	curl -L -o $TARBALL http://download.savannah.gnu.org/releases/freetype/$TARBALL
fi

rm -rf $SOURCEDIR
tar -xzf $TARBALL
cd $SOURCEDIR
rm -rf "$SCRIPT_OUTPUT_FILE_0"
./configure --prefix="$SCRIPT_OUTPUT_FILE_0"
make install 2>/dev/null
install_name_tool -id "@rpath/libfreetype.dylib" "$SCRIPT_OUTPUT_FILE_0"/lib/libfreetype.dylib

