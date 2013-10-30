#!/bin/bash

set -e

WD=$PWD
PRODUCT_SHORTNAME=ipython-notebook

#[ "$CONFIGURATION" = Release ] || { echo Distribution target requires "'Release'" build style; false; }

VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Info" CFBundleVersion)
[ "$VERSION" = "$CURRENT_PROJECT_VERSION" ] || { echo "Info.plist CFBundleVersion ($VERSION) not equal to CURRENT_PROJECT_VERSION ($CURRENT_PROJECT_VERSION), clean build required?"; false; }

DOWNLOAD_BASE_URL="http://cdn.entropy.ch/software/$PRODUCT_SHORTNAME"
RELEASENOTES_URL="http://cdn.entropy.ch/software/$PRODUCT_SHORTNAME/release-notes.html#version-$VERSION"

ARCHIVE_FILENAME="$PRODUCT_NAME $VERSION.zip"
ARCHIVE_FILENAME_UNVERSIONED="$PRODUCT_NAME.zip"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
KEYCHAIN_PRIVKEY_NAME="Sparkle Private Key 1"

cd "$BUILT_PRODUCTS_DIR"
rm -f "$PRODUCT_NAME"*.zip
ditto -ck --keepParent "$PRODUCT_NAME.app" "$ARCHIVE_FILENAME"

SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(date +"%a, %d %b %G %T %z")
SIGNATURE=$(
	openssl dgst -sha1 -binary < "$ARCHIVE_FILENAME" \
	| openssl dgst -dss1 -sign <(security find-generic-password -g -s "$KEYCHAIN_PRIVKEY_NAME" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g') \
	| openssl enc -base64
)

[ $SIGNATURE ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }

cat <<EOF
		<item>
			<title>Version $VERSION</title>
			<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
			<sparkle:minimumSystemVersion>10.9</sparkle:minimumSystemVersion>
			<pubDate>$PUBDATE</pubDate>
			<enclosure
				url="$DOWNLOAD_URL"
				sparkle:version="$VERSION"
				type="application/octet-stream"
				length="$SIZE"
				sparkle:dsaSignature="$SIGNATURE"
			/>
		</item>
EOF

echo scp "'$BUILT_PRODUCTS_DIR/$ARCHIVE_FILENAME'" cdn.entropy.ch:software/$PRODUCT_SHORTNAME/
echo scp "'$BUILT_PRODUCTS_DIR/$ARCHIVE_FILENAME'" "\"cdn.entropy.ch:'software/$PRODUCT_SHORTNAME/$ARCHIVE_FILENAME_UNVERSIONED'\""

echo scp "'$WD/Resources/release-notes.html'" cdn.entropy.ch:software/$PRODUCT_SHORTNAME/release-notes.html
echo scp "'$WD/appcast.xml'" cdn.entropy.ch:software/$PRODUCT_SHORTNAME/appcast.xml

echo git commit -a -m "'version $VERSION'"
echo git tag -a "'v$VERSION'" -m "'version $VERSION'"
echo git push --all
echo git push --tags
echo git push --all github
echo git push --tags github
echo

open "$BUILT_PRODUCTS_DIR"