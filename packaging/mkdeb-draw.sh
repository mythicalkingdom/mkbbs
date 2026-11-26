#!/bin/sh
# Builds build/mkdraw_<version>_<arch>.deb: mkdraw and mkcat, their manual pages, the example list of screen codes and a short document, for systems that have no BBS.
# The package mkbbs has the same programs (it Provides / Conflicts / Replaces mkdraw), so one or the other is installed.
#
#   packaging/mkdeb-draw.sh                  version 0.2+git<date>.<commit>, maintainer from git
#   VERSION=1.0 packaging/mkdeb-draw.sh      another version
#   DEB_MAINTAINER="Name <mail>" ...         another maintainer line
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
cd "$here"
ARCH=$(dpkg --print-architecture)
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
VERSION=${VERSION:-0.2+git$(date +%Y%m%d).$COMMIT}
NAME=$(git config user.name 2>/dev/null || echo "MK BBS")
MAINTAINER=${DEB_MAINTAINER:-"$NAME <$NAME@users.noreply.github.com>"}
STAGE=build/deb-draw/stage
OUT=build/mkdraw_${VERSION}_${ARCH}.deb

[ -x build/mkdraw ] && [ -x build/mkcat ] || { echo "mkdeb-draw: build/mkdraw and build/mkcat are not there: run make first" >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo "mkdeb-draw: dpkg-deb is needed" >&2; exit 1; }

rm -rf build/deb-draw
mkdir -p "$STAGE"

# the files, with the layout of a package
make -s -o build/.built install-draw DESTDIR="$here/$STAGE" PREFIX=/usr >/dev/null
find "$STAGE/usr/share/man" -type f -name '*.1' -exec gzip -9n {} +

doc="$STAGE/usr/share/doc/mkdraw"
mkdir -p "$doc"
install -m 644 MKDRAW.md "$doc/MKDRAW.md"
cat > "$doc/copyright" <<'CR'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: mkbbs
Source: https://github.com/mythicalkingdom/mkbbs

Files: *
Copyright: 2026 Mark May and contributors (the MK toolkit and its conversion to Free Pascal)
License: GPL-3+
 This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free
 Software Foundation, either version 3 of the License, or (at your option) any later version.
 .
 On Debian systems the full text of the GNU General Public License version 3 is in /usr/share/common-licenses/GPL-3.
CR
{
    echo "mkdraw ($VERSION) unstable; urgency=low"
    echo
    echo "  * Built from commit $COMMIT."
    echo
    echo " -- $MAINTAINER  $(date -R)"
} | gzip -9n > "$doc/changelog.gz"

# strip the programs: the FPC binaries carry their symbols
for f in "$STAGE"/usr/bin/*; do
    strip --strip-unneeded "$f" 2>/dev/null || true
done

# lintian: what FPC programs are (static, no PIE)
mkdir -p "$STAGE/usr/share/lintian/overrides"
cat > "$STAGE/usr/share/lintian/overrides/mkdraw" <<'LO'
mkdraw: statically-linked-binary [usr/bin/*]
mkdraw: hardening-no-pie [usr/bin/*]
LO

mkdir -p "$STAGE/DEBIAN"
size=$(du -sk "$STAGE" | cut -f1)
sed -e "s|@VERSION@|$VERSION|" -e "s|@ARCH@|$ARCH|" -e "s|@MAINTAINER@|$MAINTAINER|" -e "s|@SIZE@|$size|" packaging/deb/control-draw.in > "$STAGE/DEBIAN/control"
(cd "$STAGE" && find . -type f ! -path './DEBIAN/*' -print0 | sort -z | xargs -0 md5sum | sed 's| \./| |') > "$STAGE/DEBIAN/md5sums"

find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f ! -path "$STAGE/usr/bin/*" ! -path "$STAGE/DEBIAN/*" -exec chmod 644 {} +
chmod 755 "$STAGE"/usr/bin/*

if command -v fakeroot >/dev/null; then
    fakeroot dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$OUT" >/dev/null
else
    dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$OUT" >/dev/null
fi
echo "$OUT"
