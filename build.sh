#!/bin/sh
# Build all converted MK units and run the tests.
# Usage: ./build.sh   (objects go to ./build)
set -e
cd "$(dirname "$0")"
mkdir -p build
for u in MKString Crc32 MKMisc Crc16 MKPlat MKDos MKFile MKGlobT MKFFile MKMsgAbs MKMsgEzy MKMsgFid MKMsgHud MKMsgJam MKMsgPkt MKMsgSqu MKMsgMer MKMsgSyn MKComAbs MKStr MKDupe MKCfgAbs MKLogEnt MKCfgMK MKCfgQB MKCfgSB MKRCfgMK MKRCfgRA MKCfgRA CfgGlob Default CfgForm CfgPal CfgColor CfgSec2 CfgPath CfgGen CfgNuser CfgSec CfgPage CfgResp CfgEl CfgXfer CfgEopt CfgAddr CfgFile CfgLang CfgPack CfgList CfgPLan CfgPAddr CfgPPack CfgFArea CfgOff CfgFast CfgEPack CfgNet CfgESys CfgPSys CfgOrig CfgDoor CfgOffp CfgEvent CfgMsg CfgMArea CfgMenu CfgBox MKNSrch MKCfgTxt MKRBan QuoteCvt MkTagLn MKReadO MKReadCf HdrEnt MKVCrt MKScrn MKMusic MKAvatar MKRemote MKDoor MKComFd MKComStd MKComTelnet MKComWS MKProxy MKSess MKSnoop; do
  fpc -B -Fusrc -FEbuild -FUbuild -vew src/$u.pas
done
fpc -B -Fusrc -FEbuild -FUbuild -vew -omk src/MK.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklisten src/MKListen.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkmon src/MKMon.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkconfig src/MKConfig.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkread src/MKRead.pas
for t in smoke mertest merstress comtest dupetest doortest stdtest opentest syntest teltest wstest fakemk listentest; do
  fpc -B -Fusrc -FEbuild -FUbuild -vew tests/$t.pas
done
mkdir -p build/work
build/smoke build/work
build/mertest build/work | grep -E 'FAIL|failures'
build/merstress build/work | grep -E 'FAIL|failures'
build/comtest | grep -E 'FAIL|failures'
build/dupetest build/work | grep -E 'FAIL|failures'
build/doortest build/work | grep -E 'FAIL|failures'
build/opentest build/work | grep -E 'FAIL|failures'
build/syntest selftest build/work | grep -E 'FAIL|failures'
build/teltest | grep -E "FAIL|failures"
build/wstest | grep -E "FAIL|failures"
build/listentest build/mklisten build/fakemk build/work 2>&1 | grep -E "^(FAIL|failures)"
mkdir -p build/work/mon
python3 tests/montest.py build/mklisten build/fakemk build/mkmon build/work/mon | grep -E "^(FAIL|failures)"
# the real Synchronet sample base (from the JS project): every index CRC must match ours
if [ -f javascript/message_bases/synchronet/fsx_bbs.shd ]; then
  cp javascript/message_bases/synchronet/fsx_bbs.s?? build/work/
  build/syntest check build/work/fsx_bbs | grep -E 'FAIL|failures'
fi
[ "$(printf 'abc' | build/stdtest)" = 'ABC' ] && echo 'ok   MKComStd on a pipe' || { echo 'FAIL MKComStd on a pipe'; exit 1; }
# configuration editor: edit a path on a copy of the sample config through a pseudo terminal, check the file
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/cfgwork/ra; cp -a bbs/bbsc/ra/. build/cfgwork/ra/
  CFGDIR=$PWD/build/cfgwork/ra python3 tests/cfgshot.py '\x1bg' '\x1b[B' '\r' '\t\t\t\t' '/x\\y' '\r' '\x1bx' 'y' > /dev/null 2>&1
  strings build/cfgwork/ra/config.mk | grep -q '^/x/y/' && echo 'ok   mkconfig: edited path saved with slashes' || { echo 'FAIL mkconfig: edit not saved'; exit 1; }
  # General screen (converted layout): replace the BBS id, save
  CFGDIR=$PWD/build/cfgwork/ra python3 tests/cfgshot.py '\x1bg' '\r' '\t\t\t' 'ZZQ' '\r' '\x1bx' 'y' > /dev/null 2>&1
  strings build/cfgwork/ra/config.mk | grep -q 'ZZQ' && echo 'ok   mkconfig: General screen edit saved' || { echo 'FAIL mkconfig: General edit not saved'; exit 1; }
  # Events list -> event 1 -> Space changes the status choice -> OK, quit and save: the config file must change
  mkdir -p build/cfgwork2/ra; cp -a bbs/bbsc/ra/. build/cfgwork2/ra/
  CFGDIR=$PWD/build/cfgwork2/ra python3 tests/cfgshot.py '\x1be' '\r' ' ' '\r' '\x1b' '\x1bx' 'y' > /dev/null 2>&1
  N=$(cmp -l bbs/bbsc/ra/config.mk build/cfgwork2/ra/config.mk | wc -l)
  [ "$N" -ge 1 ] && [ "$N" -le 4 ] && echo 'ok   mkconfig: event status choice saved' || { echo "FAIL mkconfig: event edit ($N bytes differ)"; exit 1; }
fi
# MKRead: read a message and write a reply on a private copy of the sample BBS
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/readwork
  python3 tests/readtest.py build/readwork | grep -E "^(ok|FAIL)" | tee build/readwork/result.txt
  if grep -q FAIL build/readwork/result.txt; then exit 1; fi
fi

