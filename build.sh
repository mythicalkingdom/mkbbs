#!/bin/sh
# Build all converted MK units and run the tests.
# Usage: ./build.sh                 build everything and run the tests (objects go to ./build)
#        ./build.sh --build-only    just the programs (what "make" does)
set -e
cd "$(dirname "$0")"
mkdir -p build
for u in MKString Crc32 MKMisc Crc16 MKPlat MKDos MKFile MKGlobT MKFFile MKMsgAbs MKMsgEzy MKMsgFid MKMsgHud MKMsgJam MKMsgPkt MKMsgSqu MKMsgMer MKMsgSyn MKComAbs MKStr MKDupe MKCfgAbs MKLogEnt MKCfgMK MKCfgQB MKCfgSB MKRCfgMK MKRCfgRA MKCfgRA CfgGlob Default CfgForm CfgPal CfgColor CfgSec2 CfgPath CfgGen CfgNuser CfgSec CfgPage CfgResp CfgEl CfgXfer CfgEopt CfgAddr CfgFile CfgLang CfgPack CfgList CfgPLan CfgPAddr CfgPPack CfgFArea CfgOff CfgFast CfgEPack CfgNet CfgESys CfgPSys CfgMail CfgOrig CfgDoor CfgOffp CfgEvent CfgMsg CfgMArea CfgMenu CfgBox MKNSrch MKCfgTxt MKRBan QuoteCvt MkTagLn MKReadO MKReadCf HdrEnt MKVCrt MKScrn MKMusic MKAvatar MKDoor MKComFd MKComStd MKComTelnet MKComWS MKProxy MKSess MKSnoop; do
  fpc -B -Fusrc -FEbuild -FUbuild -vew src/$u.pas
done
# menu command 169 runs BASIC programs with the mkbasic interpreter (a separate project): found next to this
# one or named by MKBASIC; without it the command only says that BASIC is not available
BASIC_SRC="${MKBASIC:-../mkbasic-fpc/src}"
BASICFLAGS=""
if [ -f "$BASIC_SRC/Basic.pas" ]; then
  BASICFLAGS="-dMKBASIC -Fu$BASIC_SRC"
  echo "BASIC interpreter: $BASIC_SRC"
else
  echo "BASIC interpreter not found in $BASIC_SRC (set MKBASIC): menu command 169 will be a stub"
fi
# menu command 170 runs Pascal programs with the mkpascal interpreter (also a separate project): ../mkpascal-fpc/src or MKPASCAL
PASCAL_SRC="${MKPASCAL:-../mkpascal-fpc/src}"
PASCALFLAGS=""
if [ -f "$PASCAL_SRC/mkpascal.pas" ]; then
  # its units get their language mode from its own compiler flags (not from directives in the files), so they are
  # compiled on their own, with those flags, into build/pascal; mk then only sees the compiled units
  mkdir -p build/pascal
  fpc -Mobjfpc -Sh -O2 -vewn -Fu"$PASCAL_SRC" -FUbuild/pascal -FEbuild/pascal "$PASCAL_SRC/mkpascal.pas" > /dev/null
  PASCALFLAGS="-dMKPASCAL -Fubuild/pascal"
  echo "Pascal interpreter: $PASCAL_SRC"
else
  echo "Pascal interpreter not found in $PASCAL_SRC (set MKPASCAL): menu command 170 will be a stub"
fi
fpc -B -Fusrc -FEbuild -FUbuild -vew $BASICFLAGS $PASCALFLAGS -omk src/MK.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklisten src/MKListen.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkmon src/MKMon.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkconfig src/MKConfig.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkread src/MKRead.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkmenu src/MKMenu.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkusered src/MKUserEd.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklc src/MKLC.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklist src/MKList.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omknodelist src/MKNodeList.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omknodeidx src/MKNodeIdx.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkcfgcvt src/MKCfgCvt.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkbinkcfg src/MKBinkCfg.pas
if [ "$1" = "--build-only" ]; then touch build/.built; exit 0; fi   # make / make install
for t in smoke mertest merstress comtest dupetest doortest stdtest opentest syntest teltest wstest fakemk listentest charsettest; do
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
(cd build/work && ../charsettest) | grep -E "FAIL|failures"
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
# MKMenu: edit, pick a command, insert, delete, save a private copy of a sample menu
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/menuwork
  python3 tests/menutest.py build/menuwork | grep -E "^(ok|FAIL)" | tee build/menuwork/result.txt
  if grep -q FAIL build/menuwork/result.txt; then exit 1; fi
fi
# mailer settings: mkconfig pages, Mailer.Mk, mkbinkcfg (and mkbink check when that project is built next to this one)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/mailertest.py build/mailwork | grep -E "^(ok|FAIL|skip)" | tee build/mailresult.txt
  if grep -q FAIL build/mailresult.txt; then exit 1; fi
fi
# mklisten runs the mailer (fake programs, then the real ones when mkbink is built next to this project)
python3 tests/mailerlistentest.py build/mlwork | grep -E "^(ok|FAIL|skip)" | tee build/mlresult.txt
if grep -q FAIL build/mlresult.txt; then exit 1; fi
# language compiler: the sample LC files must compile back to the same bytes; area list and nodelist tools
mkdir -p build/work/lc build/work/tools
python3 tests/lctest.py build/mklc build/work/lc | grep -E "^(FAIL|failures)"
python3 tests/toolstest.py build build/work/tools | grep -E "^(FAIL|failures)"
python3 tests/nodetest.py build build/work/nodetest | grep -E "^(FAIL|failures)"
# configuration converter: Remote Access -> MK / QuickBBS / SuperBBS on a copy of the sample BBS
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/cvttest.py build build/work/cvt | grep -E "^(FAIL|failures)"
fi
# menu command 169 (BASIC programs): unit test on a scripted session, then the real mk over telnet
if [ -n "$BASICFLAGS" ]; then
  mkdir -p build/work/basic
  fpc -B -Fusrc -FEbuild -FUbuild -vew $BASICFLAGS tests/basictest.pas
  MK=$PWD/build/work/basic build/basictest build/work/basic original/PROMPTS.LC | grep -E "^(FAIL|failures)"
  if [ -f bbs/bbsc/ra/config.mk ]; then
    python3 tests/basicmenutest.py build/work/basicmenu | grep -E "^(FAIL|failures)"
  fi
fi
# menu command 170 (Pascal programs): unit test on a scripted session, then the real mk over telnet
if [ -n "$PASCALFLAGS" ]; then
  mkdir -p build/work/pascal
  fpc -B -Fusrc -FEbuild -FUbuild -vew $PASCALFLAGS tests/pascaltest.pas
  MK=$PWD/build/work/pascal build/pascaltest build/work/pascal original/PROMPTS.LC | grep -E "^(FAIL|failures)"
  if [ -f bbs/bbsc/ra/config.mk ]; then
    python3 tests/pascalmenutest.py build/work/pascalmenu | grep -E "^(FAIL|failures)"
  fi
fi
# CP437 -> UTF-8 by terminal type: real telnet callers with different terminal types and ports
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/charsetnettest.py build/work/charsetnet | grep -E "^(FAIL|failures)"
fi
# MKUserEd: browse, edit, delete, search, add, validate on a private copy of the sample user files
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/userwork
  python3 tests/usertest.py build/userwork | grep -E "^(ok|FAIL)" | tee build/userwork/result.txt
  if grep -q FAIL build/userwork/result.txt; then exit 1; fi
fi
# the real mk with the sysop monitor: log in, chat from the monitor, time, kick (private copy of the sample BBS)
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/chatwork
  python3 tests/chattest.py build/chatwork | grep -E "^(ok|FAIL)" | tee build/chatwork/result.txt
  if grep -q FAIL build/chatwork/result.txt; then exit 1; fi
fi

