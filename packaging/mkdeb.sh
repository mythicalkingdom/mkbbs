#!/bin/sh
# Builds build/mkbbs_<version>_<arch>.deb from the programs in build/ (make deb builds them first).
#
#   packaging/mkdeb.sh                      version 0.1+git<date>.<commit>, maintainer from git
#   VERSION=1.0 packaging/mkdeb.sh          another version
#   DEB_MAINTAINER="Name <mail>" ...        another maintainer line
#   MKBINK=../mkbink                        the binkp mailer project: its program goes in the package when it is built there
#
# The package: programs in /usr/bin, the listener unit in /usr/lib/systemd/system, /etc/mkbbs/mklisten.example.json, language files and hub profiles
# in /usr/share/mkbbs, documentation in /usr/share/doc/mkbbs.  Needs dpkg-deb; fakeroot makes the files belong to root (without it they are
# made by the build user's number: use fakeroot).
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
cd "$here"
MKBINK=${MKBINK:-../mkbink}
ARCH=$(dpkg --print-architecture)
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
VERSION=${VERSION:-0.1+git$(date +%Y%m%d).$COMMIT}
NAME=$(git config user.name 2>/dev/null || echo "MK BBS")
MAINTAINER=${DEB_MAINTAINER:-"$NAME <$NAME@users.noreply.github.com>"}
STAGE=build/deb/stage
OUT=build/mkbbs_${VERSION}_${ARCH}.deb

[ -x build/mk ] || { echo "mkdeb: build/mk is not there: run make first" >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo "mkdeb: dpkg-deb is needed" >&2; exit 1; }

rm -rf build/deb
mkdir -p "$STAGE"

# the files, with the layout of a package: /usr, the unit in /usr/lib/systemd/system
make -s -o build/.built install DESTDIR="$here/$STAGE" PREFIX=/usr UNITDIR=/usr/lib/systemd/system MKBINK="$MKBINK" SYSTEMD=auto >/dev/null
# what the package does not ship: the configuration and the log directory are made by postinst (they are not conffiles: they hold your passwords and paths)
rm -f "$STAGE/etc/mkbbs/mklisten.json"
rm -rf "$STAGE/var"
# the example is in the documentation (postinst makes the configuration from it); nothing of this package is a conffile
rm -f "$STAGE/etc/mkbbs/mklisten.example.json"
rmdir "$STAGE/etc/mkbbs" "$STAGE/etc" 2>/dev/null || true
sed -i 's|file:/etc/mkbbs/mklisten.example.json|file:/usr/share/doc/mkbbs/examples/mklisten.example.json|' "$STAGE/usr/lib/systemd/system/mklisten.service"

# the language files: the text, and what mklc makes of it
mkdir -p "$STAGE/usr/share/mkbbs/lang" build/deb/lang
cp lang/*.TXT build/deb/lang/
for t in MKMENU AMERICAN ENGLISH; do
    (cd build/deb/lang && "$here/build/mklc" "$t.TXT" >/dev/null 2>&1)
done
cp build/deb/lang/* "$STAGE/usr/share/mkbbs/lang/"

# the documentation and the examples
doc="$STAGE/usr/share/doc/mkbbs"
mkdir -p "$doc/examples"
for f in GETTING-STARTED MKBBS MKLISTEN NETWORKING HUBS TOSSER SSH PASSWORDS DOS-DOORS; do
    [ -f "$f.md" ] && install -m 644 "$f.md" "$doc/$f.md"
done
install -m 644 mklisten.example.json "$doc/examples/"
install -m 644 bbsconfig_mkfreq_example.json "$doc/examples/" 2>/dev/null || true
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
    echo "mkbbs ($VERSION) unstable; urgency=low"
    echo
    echo "  * Built from commit $COMMIT."
    echo
    echo " -- $MAINTAINER  $(date -R)"
} | gzip -9n > "$doc/changelog.gz"
# a short README for the package
cat > "$doc/README.Debian" <<'RD'
mkbbs for Debian
================

* Nothing is started by the package.  Edit /etc/mkbbs/mklisten.json (the paths, the ports, the sysop password), make a BBS directory with mkconfig
  (GETTING-STARTED.md), then:   systemctl enable --now mklisten
* The listener runs as the user mkbbs (made by the package); that user must be able to read and write the BBS directory.
* Language files: /usr/share/mkbbs/lang (the text, and the compiled .lc files); copy them into the BBS directory.
* Hub profiles: /usr/share/mkbbs/hubs.  SSH front end templates: /usr/share/mkbbs/ssh (SSH.md).
* The programs have short names (mk, mkread, mkcat ...): they are all in /usr/bin.
* Removing the package keeps the user mkbbs, /var/log/mkbbs and your BBS directories; purging also removes /etc/mkbbs/mklisten.json.
RD

# strip the programs: the FPC binaries carry their symbols
for f in "$STAGE"/usr/bin/*; do
    case $(file -b "$f") in
    ELF*) strip --strip-unneeded "$f" 2>/dev/null || true ;;
    esac
done

# lintian: what FPC programs are (static, no PIE, no manual pages)
mkdir -p "$STAGE/usr/share/lintian/overrides"
cat > "$STAGE/usr/share/lintian/overrides/mkbbs" <<'LO'
mkbbs: statically-linked-binary [usr/bin/*]
mkbbs: hardening-no-pie [usr/bin/*]
mkbbs: no-manual-page [usr/bin/*]
LO

# DEBIAN
mkdir -p "$STAGE/DEBIAN"
size=$(du -sk "$STAGE" | cut -f1)
sed -e "s|@VERSION@|$VERSION|" -e "s|@ARCH@|$ARCH|" -e "s|@MAINTAINER@|$MAINTAINER|" -e "s|@SIZE@|$size|" packaging/deb/control.in > "$STAGE/DEBIAN/control"
install -m 755 packaging/deb/postinst packaging/deb/prerm packaging/deb/postrm "$STAGE/DEBIAN/"
# md5sums
(cd "$STAGE" && find . -type f ! -path './DEBIAN/*' -print0 | sort -z | xargs -0 md5sum | sed 's| \./| |') > "$STAGE/DEBIAN/md5sums"

# the permissions of a package: directories 755, files 644 or 755, owner root
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f ! -path "$STAGE/usr/bin/*" ! -path "$STAGE/DEBIAN/*" -exec chmod 644 {} +
chmod 755 "$STAGE"/usr/bin/*

if command -v fakeroot >/dev/null; then
    fakeroot dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$OUT" >/dev/null
else
    dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$OUT" >/dev/null
fi
echo "$OUT"
