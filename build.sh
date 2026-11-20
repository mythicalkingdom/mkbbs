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
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkpwconv src/MKPwConv.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklc src/MKLC.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklist src/MKList.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omknodelist src/MKNodeList.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omknodeidx src/MKNodeIdx.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkcfgcvt src/MKCfgCvt.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkbinkcfg src/MKBinkCfg.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklower src/MKLower.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omktoss src/MKToss.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkqwk src/MKQwk.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkqwkcfg src/MKQwkCfg.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkcat src/MKCat.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkdraw src/MKDraw.pas
# tosstest needs it (a clean build directory has none yet)
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/pkttest tests/pkttest.pas 2>&1 | grep -E "Error|Fatal" || true
for t in tosssetup tossdump tossmake tosscfg qwkmsgtest netsetup prottest clienttest clientxfer scripttest postmsg useradd setlr pwdtest; do fpc -B -Fusrc -FEbuild -FUbuild -vew -o$t tests/$t.pas 2>&1 | grep -E "Error|Fatal" || true; done
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
build/pwdtest | grep -E 'FAIL|failures'
mkdir -p build/work/pwconv
python3 tests/pwconvtest.py build build/work/pwconv | grep -E '^(ok|FAIL|skip|failures)'
build/opentest build/work | grep -E 'FAIL|failures'
build/syntest selftest build/work | grep -E 'FAIL|failures'
build/teltest | grep -E "FAIL|failures"
(cd build/work && ../charsettest) | grep -E "FAIL|failures"
build/wstest | grep -E "FAIL|failures"
build/listentest build/mklisten build/fakemk build/work 2>&1 | grep -E "^(FAIL|failures)"
mkdir -p build/work/mon
python3 tests/montest.py build/mklisten build/fakemk build/mkmon build/work/mon | grep -E "^(FAIL|failures)"
python3 tests/monlocaltest.py build/mklisten build/mkmon build/work/monlocal | grep -E "^(FAIL|failures)"
# the real Synchronet sample base (from the JS project): every index CRC must match ours
if [ -f javascript/message_bases/synchronet/fsx_bbs.shd ]; then
  cp javascript/message_bases/synchronet/fsx_bbs.s?? build/work/
  build/syntest check build/work/fsx_bbs | grep -E 'FAIL|failures'
fi
[ "$(printf 'abc' | build/stdtest)" = 'ABC' ] && echo 'ok   MKComStd on a pipe' || { echo 'FAIL MKComStd on a pipe'; exit 1; }
# configuration editor: edit a path on a copy of the sample config through a pseudo terminal, check the file
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/cfgwork/ra; (cd bbs/bbsc/ra && tar cf - --exclude='mkbink.conf*' --exclude='Mailer.Mk' .) | tar xf - -C build/cfgwork/ra
  CFGDIR=$PWD/build/cfgwork/ra python3 tests/cfgshot.py '\x1bg' '\x1b[B' '\r' '\t\t\t\t' '/x\\y' '\r' '\x1bx' 'y' > /dev/null 2>&1
  strings build/cfgwork/ra/config.mk | grep -q '^/x/y/' && echo 'ok   mkconfig: edited path saved with slashes' || { echo 'FAIL mkconfig: edit not saved'; exit 1; }
  # General screen (converted layout): replace the BBS id, save
  CFGDIR=$PWD/build/cfgwork/ra python3 tests/cfgshot.py '\x1bg' '\r' '\t\t\t' 'ZZQ' '\r' '\x1bx' 'y' > /dev/null 2>&1
  strings build/cfgwork/ra/config.mk | grep -q 'ZZQ' && echo 'ok   mkconfig: General screen edit saved' || { echo 'FAIL mkconfig: General edit not saved'; exit 1; }
  # Events list -> event 1 -> Space changes the status choice -> OK, quit and save: the config file must change
  mkdir -p build/cfgwork2/ra; (cd bbs/bbsc/ra && tar cf - --exclude='mkbink.conf*' --exclude='Mailer.Mk' .) | tar xf - -C build/cfgwork2/ra
  CFGDIR=$PWD/build/cfgwork2/ra python3 tests/cfgshot.py '\x1be' '\r' ' ' '\r' '\x1b' '\x1bx' 'y' > /dev/null 2>&1
  N=$(cmp -l bbs/bbsc/ra/config.mk build/cfgwork2/ra/config.mk | wc -l)
  [ "$N" -ge 1 ] && [ "$N" -le 4 ] && echo 'ok   mkconfig: event status choice saved' || { echo "FAIL mkconfig: event edit ($N bytes differ)"; exit 1; }
  # Transfer Protocols (General menu): external protocol 11 gets a key and a "send | receive" command line
  mkdir -p build/cfgwork3/ra; (cd bbs/bbsc/ra && tar cf - --exclude='mkbink.conf*' --exclude='Mailer.Mk' .) | tar xf - -C build/cfgwork3/ra
  CFGDIR=$PWD/build/cfgwork3/ra python3 tests/cfgshot.py '\x1bg' 't' '\x1b[B' '\x1b[B' '\x1b[B' '\x1b[B' '\x1b[B' '\x1b[B' '\x1b[B' '\x1b[B' '\x1b[B' '\x1b[B' '\r' 'Zed' '\t' 'R' '\t' '\t' '\t' 'sz %F | rz' '\r' '\x1b' '\x1bx' 'y' > /dev/null 2>&1
  strings build/cfgwork3/ra/config.mk | grep -q 'sz %F | rz' && echo 'ok   mkconfig: external protocol command line saved' || { echo 'FAIL mkconfig: protocol edit not saved'; exit 1; }
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
# hold in the abstract message object (False where a base has no such flag)
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/holdabstest tests/holdabstest.pas 2>&1 | grep -E "Error|Fatal" || true
build/holdabstest | grep -E "^(ok|FAIL|failures)" | tee build/holdabsresult.txt
if grep -q FAIL build/holdabsresult.txt; then exit 1; fi
# hold in JAM, Squish and Merlin (written, read back, changed)
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/holdbasetest tests/holdbasetest.pas 2>&1 | grep -E "Error|Fatal" || true
mkdir -p build/holdwork
build/holdbasetest build/holdwork | grep -E "^(ok|FAIL|failures)" | tee build/holdbaseresult.txt
if grep -q FAIL build/holdbaseresult.txt; then exit 1; fi
# what the scanner of mktoss reads from a message (local, echo, sent) in JAM, Squish and Merlin
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/scanflagstest tests/scanflagstest.pas 2>&1 | grep -E "Error|Fatal" || true
mkdir -p build/scanflagswork
build/scanflagstest build/scanflagswork | grep -E "^(ok|FAIL|failures)" | tee build/scanflagsresult.txt
if grep -q FAIL build/scanflagsresult.txt; then exit 1; fi
# the defaults of a new configuration
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/defaultstest tests/defaultstest.pas 2>&1 | grep -E "Error|Fatal" || true
build/defaultstest | tee build/defaultsresult.txt
if grep -q FAIL build/defaultsresult.txt; then exit 1; fi
# Fido *.msg: the hold flag
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/fidtest tests/fidtest.pas 2>&1 | grep -E "Error|Fatal" || true
mkdir -p build/fidwork
build/fidtest build/fidwork | grep -E "^(ok|FAIL|failures)" | tee build/fidresult.txt
if grep -q FAIL build/fidresult.txt; then exit 1; fi
# menu command 007 (external programs, doors): paths, parameters, drop files, the caller's input, a program that is not there
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/doormenutest.py build/work/doormenu | grep -E "^(ok|FAIL|skip)" | tee build/doormenuresult.txt
  if grep -q FAIL build/doormenuresult.txt; then exit 1; fi
fi
# mkdraw: the screen editor (ANSI / AVATAR / ASCII screens) through a pseudo terminal
python3 tests/drawtest.py build build/work/draw | grep -E "^(FAIL|failures)"
# mkcat: CP437 text to the terminal
python3 tests/cattest.py build build/work/cat | grep -E "^(FAIL|failures)"
# the offline mail door (mkqwk): local mode on a private copy of the sample BBS, a real QWK packet
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/qwktest.py build build/qwkwork | grep -E "^(ok|FAIL|skip)" | tee build/qwkresult.txt
  if grep -q FAIL build/qwkresult.txt; then exit 1; fi
fi
# MKProt (Zmodem both ways) against the real lrzsz over a socketpair
python3 tests/prottest.py build build/work/prot | grep -E "^(ok|FAIL|skip|failures)" | tee build/protresult.txt
if grep -q FAIL build/protresult.txt; then exit 1; fi
# mk -G<id>: a pass with a QWK network system (reply packet, packet of the hub, last read past the imported messages)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/qwknettest.py build build/work/qwknet | grep -E "^(ok|FAIL|skip|failures)" | tee build/qwknetresult.txt
  if grep -q FAIL build/qwknetresult.txt; then exit 1; fi
fi
# mk -G with a hub in the map file: two private copies of the sample BBS, the hub is mk -Q behind mklisten (Zmodem both ways)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/hubpasstest.py build build/work/hubpass | grep -E "^(FAIL|skip|failures)" | tee build/hubpassresult.txt
  if grep -q FAIL build/hubpassresult.txt; then exit 1; fi
fi
# mkqwkcfg: the configuration of the offline mail door (config.mko, users.mko, confs.mko)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/qwkcfgtest.py build build/work/qwkcfg | grep -E "^(ok|FAIL|skip|failures)" | tee build/qwkcfgresult.txt
  if grep -q FAIL build/qwkcfgresult.txt; then exit 1; fi
fi
# the client session (MKComClient: TCP + Telnet client mode), alone and against mklisten with a "qwk" port (mk -Q) with Zmodem both ways
python3 tests/clienttest.py build | grep -E "^(FAIL|failures)" | tee build/clientresult.txt
if grep -q FAIL build/clientresult.txt; then exit 1; fi
# the script engine (MKHubScr) against fake hubs that vary
python3 tests/scripthubtest.py build build/work/scripthub | grep -E "^(FAIL|failures)" | tee build/scripthubresult.txt
if grep -q FAIL build/scripthubresult.txt; then exit 1; fi
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/clientxfertest.py build build/work/clientxfer | grep -E "^(FAIL|skip|failures)" | tee build/clientxferresult.txt
  if grep -q FAIL build/clientxferresult.txt; then exit 1; fi
fi
# mk -Q: the login of a QWK network system (Login:, Password:, QWK: D/U/B/Q)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/qwkpassivetest.py build build/work/qwklogin | grep -E "^(ok|FAIL|skip|failures)" | tee build/qwkloginresult.txt
  if grep -q FAIL build/qwkloginresult.txt; then exit 1; fi
fi
# the tosser (mktoss) on a private copy of the sample BBS, with packets made by MessagePacket.js
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/tosstest.py build build/tosswork | grep -E "^(ok|FAIL|skip)" | tee build/tossresult.txt
  if grep -q FAIL build/tossresult.txt; then exit 1; fi
fi
# the way in: a mkbink calls the mkbink of the BBS, the on-inbound command (mktoss) tosses the packet
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/tosshooktest.py build build/hookwork | grep -E "^(ok|FAIL|skip)" | tee build/hookresult.txt
  if grep -q FAIL build/hookresult.txt; then exit 1; fi
fi
# message packets: the unit's own tests and a comparison with javascript/MessagePacket.js (node)
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/pkttest tests/pkttest.pas 2>&1 | grep -E "Error|Fatal" || true
python3 tests/pkttest.py build build/pktwork | grep -E "^(ok|FAIL|skip)" | tee build/pktresult.txt
if grep -q FAIL build/pktresult.txt; then exit 1; fi
# QWK message files (MESSAGES.DAT, REP): the unit's own tests and a comparison with javascript/MessageQWK.js (node)
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/qwkmsgtest tests/qwkmsgtest.pas 2>&1 | grep -E "Error|Fatal" || true
python3 tests/qwkmsgtest.py build build/qwkwork | grep -E "^(ok|FAIL|skip|failures)" | tee build/qwkmsgresult.txt
if grep -q FAIL build/qwkmsgresult.txt; then exit 1; fi
# the reply / packet import (MKQwkImp): a REP into message areas
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/qwkimptest tests/qwkimptest.pas 2>&1 | grep -E "Error|Fatal" || true
rm -rf build/qwkimpwork; mkdir -p build/qwkimpwork
build/qwkimptest build/qwkimpwork | grep -E "^(ok|FAIL|failures)" | tee build/qwkimpresult.txt
if grep -q FAIL build/qwkimpresult.txt; then exit 1; fi
# links without a host: looked up in the nodelist
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/nlhosttest.py build build/nlwork | grep -E "^(ok|FAIL|skip)" | tee build/nlresult.txt
  if grep -q FAIL build/nlresult.txt; then exit 1; fi
fi
# mklisten runs the mailer (fake programs, then the real ones when mkbink is built next to this project)
python3 tests/mailerlistentest.py build/mlwork | grep -E "^(ok|FAIL|skip)" | tee build/mlresult.txt
if grep -q FAIL build/mlresult.txt; then exit 1; fi
# the Mailer screen of mkmon (needs the real mkbink next to this project)
python3 tests/mailmontest.py build/mmwork | grep -E "^(ok|FAIL|skip)" | tee build/mmresult.txt
if grep -q FAIL build/mmresult.txt; then exit 1; fi
# mklower: references in mixed case made lower case (private copy of the sample BBS)
python3 tests/lowertest.py build/mklower | grep -E "^(ok|FAIL|skip)" | tee build/lowerresult.txt
if grep -q FAIL build/lowerresult.txt; then exit 1; fi
# language compiler: the sample LC files must compile back to the same bytes; area list and nodelist tools
mkdir -p build/work/lc build/work/tools
python3 tests/lctest.py build/mklc build/work/lc | grep -E "^(FAIL|failures)"
python3 tests/toolstest.py build build/work/tools | grep -E "^(FAIL|failures)"
python3 tests/nodetest.py build build/work/nodetest | grep -E "^(FAIL|failures)"
# configuration converter: Remote Access -> MK / QuickBBS / SuperBBS on a copy of the sample BBS
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/cvttest.py build build/work/cvt | grep -E "^(FAIL|failures)"
  # the MK configuration in one JSON file (MKJSON, bbsconfig.json)
  python3 tests/jsoncfgtest.py build build/work/jsoncfg | grep -E "^(FAIL|failures)"
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

