#!/bin/bash
cd "$(dirname "$0")/.."
rm -rf scripts/rime_icon.iconset
mkdir -p scripts/rime_icon.iconset

for s in 16 32 64 128 256 512; do
    sips -z $s $s scripts/rime_icon_1024.png --out "scripts/rime_icon.iconset/icon_${s}x${s}.png" > /dev/null 2>&1
done

cp scripts/rime_icon_1024.png scripts/rime_icon.iconset/icon_512x512@2x.png
iconutil -c icns scripts/rime_icon.iconset -o scripts/AppIcon.icns
echo "Icon generated: scripts/AppIcon.icns"
