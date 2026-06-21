#!/bin/sh

# This script is used to generate the control file for the Debian package.
if [ $# -ge 1 ]; then
    VERSION=$1
    VERSION=${VERSION#v}
else
    VERSION=$(./get-version.sh)
fi

# Create the layout directory
mkdir -p layout/DEBIAN

# Write the control file
cat > layout/DEBIAN/control << __EOF__
Package: ch.xxtou.hudapp.jb
Name: TrollSpeed JB
Version: $VERSION
Section: Tweaks
Depends: firmware (>= 14.0)
Architecture: iphoneos-arm
Author: Lessica <82flex@gmail.com>
Maintainer: Lessica <82flex@gmail.com>
Description: Troll your speed, but jailbroken.
__EOF__

# Set permissions
chmod 0644 layout/DEBIAN/control
# Debian 维护脚本必须可执行（Windows 检出后常为 644）
if [ -f layout/DEBIAN/prerm ]; then
    chmod 0755 layout/DEBIAN/prerm
fi
for script in layout/DEBIAN/preinst layout/DEBIAN/postinst layout/DEBIAN/postrm; do
    if [ -f "$script" ]; then
        chmod 0755 "$script"
    fi
done

RAND_BUILD_STR=$(openssl rand -hex 4)

# Write the Info.plist file
defaults write $PWD/Resources/Info.plist CFBundleShortVersionString $VERSION
defaults write $PWD/Resources/Info.plist CFBundleVersion $RAND_BUILD_STR
plutil -convert xml1 $PWD/Resources/Info.plist
chmod 0644 $PWD/Resources/Info.plist

defaults write $PWD/supports/Sandbox-Info.plist CFBundleShortVersionString $VERSION
defaults write $PWD/supports/Sandbox-Info.plist CFBundleVersion $RAND_BUILD_STR
plutil -convert xml1 $PWD/supports/Sandbox-Info.plist
chmod 0644 $PWD/supports/Sandbox-Info.plist

XCODE_PROJ_PBXPROJ=$PWD/TrollSpeed.xcodeproj/project.pbxproj
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" $XCODE_PROJ_PBXPROJ