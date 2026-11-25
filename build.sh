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
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkfreq src/MKFreq.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkevents src/MKEvents.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkbackup src/MKBackup.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkmaint src/MKMaint.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkstats src/MKStatsRep.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkuserpurge src/MKUserPurge.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkfilecheck src/MKFileCheck.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkuserpack src/MKUserPack.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkapi src/MKApi.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkapitoken src/MKApiTokTool.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omsgput tests/msgput.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omksetup src/MKSetup.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkcheck src/MKCheck.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omerlr tests/merlr.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklc src/MKLC.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklistmsgarea src/MKListMsgArea.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omknodelist src/MKNodeList.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omknodeidx src/MKNodeIdx.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkcfgcvt src/MKCfgCvt.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkbinkcfg src/MKBinkCfg.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omklower src/MKLower.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omktoss src/MKToss.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkhatch src/MKHatch.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkbbsssh src/MKBbsSsh.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkqwk src/MKQwk.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkqwkcfg src/MKQwkCfg.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkcat src/MKCat.pas
fpc -B -Fusrc -FEbuild -FUbuild -vew -omkdraw src/MKDraw.pas
# tosstest needs it (a clean build directory has none yet)
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/pkttest tests/pkttest.pas 2>&1 | grep -E "Error|Fatal" || true
for t in tosssetup tossdump tossmake tosscfg qwkmsgtest netsetup prottest clienttest clientxfer scripttest postmsg useradd setlr pwdtest pwusertest pwstate eventtest hubexectest hubreplayunit; do fpc -B -Fusrc -FEbuild -FUbuild -vew -o$t tests/$t.pas 2>&1 | grep -E "Error|Fatal" || true; done
if [ "$1" = "--build-only" ]; then touch build/.built; exit 0; fi   # make / make install
for t in smoke mertest merstress comtest dupetest doortest stdtest opentest syntest teltest wstest fakemk listentest charsettest; do
  fpc -B -Fusrc -FEbuild -FUbuild -vew tests/$t.pas
done
mkdir -p build/work
# the tests copy a snapshot of the sample BBS (build/fixture), not the sample that a running BBS may use; at the end it says if anything changed meanwhile
if [ -f bbs/bbsc/ra/config.mk ]; then python3 tests/fixture.py make > /dev/null; fi
build/smoke build/work
# The slow tests run in four lanes at the same time (a lane runs its tests one after the other, in the order they are given here),
# next to the rest of the tests, which run one after the other.  Each lane writes its own log; the logs are shown, and the build
# fails if a lane failed, at the end.  The tests of different lanes use other ports and other work directories.
LANEJOBS=""
lane() {                               # lane <A-D> <function>
  L=$1; F=$2
  mkdir -p build/lanes
  ( flock 9; "$F" ) 9> build/lanes/lock.$L > build/lanes/$F.log 2>&1 &
  LANEJOBS="$LANEJOBS $!:$F"
}
lanewait() {                           # waits for the lanes, shows what they said, fails if one failed
  LANEBAD=0
  for J in $LANEJOBS; do
    P=${J%%:*}; F=${J#*:}
    if wait "$P"; then :; else LANEBAD=1; echo "FAIL lane job $F (see above)"; fi
    cat build/lanes/$F.log
  done
  [ "$LANEBAD" = 0 ] || exit 1
}
build/mertest build/work | grep -E 'FAIL|failures'
build/merstress build/work | grep -E 'FAIL|failures'
build/comtest | grep -E 'FAIL|failures'
build/dupetest build/work | grep -E 'FAIL|failures'
build/doortest build/work | grep -E 'FAIL|failures'
build/pwdtest | grep -E 'FAIL|failures'
# events: when an event is due (days, occurrences, the four ways to handle a missed one)
build/eventtest | grep -E 'FAIL|failures'
mkdir -p build/work/pwconv
python3 tests/pwconvtest.py build build/work/pwconv | grep -E '^(ok|FAIL|skip|failures)'
par_1() {
if [ -f bbs/bbsc/ra/config.mk ]; then
  rm -rf build/work/pwuser; mkdir -p build/work/pwuser; cp -r "$(python3 tests/fixture.py path ra)"/. build/work/pwuser/ 2>/dev/null || true
  MK=$PWD/build/work/pwuser build/pwusertest | grep -E 'FAIL|failures'
  python3 tests/pwlogintest.py build build/work/pwlogin | grep -E '^(FAIL|skip|failures)'
fi
}
lane B par_1
build/opentest build/work | grep -E 'FAIL|failures'
build/syntest selftest build/work | grep -E 'FAIL|failures'
build/teltest | grep -E "FAIL|failures"
(cd build/work && ../charsettest) | grep -E "FAIL|failures"
build/wstest | grep -E "FAIL|failures"
build/listentest build/mklisten build/fakemk build/work 2>&1 | grep -E "^(FAIL|failures)"
par_2() {
mkdir -p build/work/mon
python3 tests/montest.py build/mklisten build/fakemk build/mkmon build/work/mon | grep -E "^(FAIL|failures)"
}
lane C par_2
# password limits: locking after wrong passwords, the expiry of a password; the login guard of mklisten (counts failed log-ons per address)
par_pwlimits() {
  if [ -f bbs/bbsc/ra/config.mk ]; then
    python3 tests/pwlimittest.py build/work/pwlimit | grep -E "^(ok|FAIL|skip)" | tee build/pwlimitresult.txt
    if grep -q FAIL build/pwlimitresult.txt; then exit 1; fi
    python3 tests/loginguardtest.py build/work/loginguard | grep -E "^(ok|FAIL|skip)" | tee build/loginguardresult.txt
    if grep -q FAIL build/loginguardresult.txt; then exit 1; fi
  fi
}
lane C par_pwlimits
python3 tests/monlocaltest.py build/mklisten build/mkmon build/work/monlocal | grep -E "^(FAIL|failures)"
# the real Synchronet sample base (from the JS project): every index CRC must match ours
if [ -f javascript/message_bases/synchronet/fsx_bbs.shd ]; then
  cp javascript/message_bases/synchronet/fsx_bbs.s?? build/work/
  build/syntest check build/work/fsx_bbs | grep -E 'FAIL|failures'
fi
[ "$(printf 'abc' | build/stdtest)" = 'ABC' ] && echo 'ok   MKComStd on a pipe' || { echo 'FAIL MKComStd on a pipe'; exit 1; }
# configuration editor: edits through a pseudo terminal on private copies of the sample config (paths patched: a save cannot reach the sample), the saved file is checked
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/cfgedittest.py build/work/cfgedit | grep -E "^(ok|FAIL|skip|failures)"
fi
# MKRead: read a message and write a reply on a private copy of the sample BBS
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/readwork
  python3 tests/readtest.py build/readwork | grep -E "^(ok|FAIL)" | tee build/readwork/result.txt
  if grep -q FAIL build/readwork/result.txt; then exit 1; fi
fi
# MKMenu: edit, pick a command, insert, delete, save a private copy of a sample menu
par_3() {
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/menuwork
  python3 tests/menutest.py build/menuwork | grep -E "^(ok|FAIL)" | tee build/menuwork/result.txt
  if grep -q FAIL build/menuwork/result.txt; then exit 1; fi
fi
}
lane D par_3
# mailer settings: mkconfig pages, Mailer.Mk, mkbinkcfg (and mkbink check when that project is built next to this one)
par_4() {
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/mailertest.py build/mailwork | grep -E "^(ok|FAIL|skip)" | tee build/mailresult.txt
  if grep -q FAIL build/mailresult.txt; then exit 1; fi
fi
}
lane D par_4
# TIC files (file echoes): MKTic reads and writes them, the CRC of a file, the Path and Seenby lines, dates, Replaces
fpc -B -Fusrc -FEbuild -FUbuild -vew -obuild/tictest tests/tictest.pas 2>&1 | grep -E "Error|Fatal" || true
mkdir -p build/work/tic
build/tictest build/work/tic | grep -E "^(ok|FAIL|failures)" | tee build/ticresult.txt
if grep -q FAIL build/ticresult.txt; then exit 1; fi
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
par_5() {
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/doormenutest.py build/work/doormenu | grep -E "^(ok|FAIL|skip)" | tee build/doormenuresult.txt
  if grep -q FAIL build/doormenuresult.txt; then exit 1; fi
fi
}
lane A par_5
# mkdraw: the screen editor (ANSI / AVATAR / ASCII screens) through a pseudo terminal
par_6() {
python3 tests/drawtest.py build build/work/draw | grep -E "^(FAIL|failures)"
}
lane D par_6
# mkcat: CP437 text to the terminal
python3 tests/cattest.py build build/work/cat | grep -E "^(FAIL|failures)"
# the offline mail door (mkqwk): local mode on a private copy of the sample BBS, a real QWK packet
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/qwktest.py build build/qwkwork | grep -E "^(ok|FAIL|skip)" | tee build/qwkresult.txt
  if grep -q FAIL build/qwkresult.txt; then exit 1; fi
  # the extras of a packet: screens, bulletins, the new files list (MKOffExt)
  python3 tests/qwkextratest.py build build/work/qwkextra | grep -E "^(ok|FAIL|skip)" | tee build/qwkextraresult.txt
  if grep -q FAIL build/qwkextraresult.txt; then exit 1; fi
  # mk and the rest of MK are independent of the old offline mail door: only mkqwk and mkqwkcfg know its files (config.mko, users.mko, confs.mko)
  for p in mk mklisten mkconfig mkmon mktoss mkfreq mkevents mkbinkcfg mkread mkusered mkcfgcvt; do
    if strings -a build/$p | grep -qi 'config\.mko\|users\.mko\|confs\.mko'; then echo "FAIL independence: $p knows the files of the offline mail door"; fi
  done | tee build/qwkindepresult.txt
  if grep -q FAIL build/qwkindepresult.txt; then exit 1; fi
fi
# MKProt (Zmodem both ways) against the real lrzsz over a socketpair
par_7() {
python3 tests/prottest.py build build/work/prot | grep -E "^(ok|FAIL|skip|failures)" | tee build/protresult.txt
if grep -q FAIL build/protresult.txt; then exit 1; fi
}
lane A par_7
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
# the exec transport of a hub (get / put programs) and the hub profiles as files
if [ -f bbs/bbsc/ra/config.mk ]; then
  build/hubexectest | grep -E "^(FAIL|failures)" | tee build/hubexecunit.txt
  build/hubreplayunit | grep -E "^(FAIL|failures)" | tee -a build/hubexecunit.txt
  python3 tests/hubtalktest.py build build/work/hubtalk | grep -E "^(FAIL|skip|failures)" | tee -a build/hubexecresult.txt
  python3 tests/hubftptest.py build build/work/hubftp | grep -E "^(FAIL|skip|failures)" | tee -a build/hubexecresult.txt
  python3 tests/hubexectest.py build build/work/hubexec | grep -E "^(FAIL|skip|failures)" | tee build/hubexecresult.txt
  if grep -q FAIL build/hubexecunit.txt build/hubexecresult.txt; then exit 1; fi
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
  # TIC files (file echoes): checks, the file area, files.bbs, replaces, bad TICs, the check command
  python3 tests/tictosstest.py build build/tictosswork | grep -E "^(ok|FAIL|skip)" | tee build/tictossresult.txt
  if grep -q FAIL build/tictossresult.txt; then exit 1; fi
  # the Debian package (packaging/mkdeb.sh): its contents, the scripts, lintian, the programs from the unpacked package
python3 tests/debtest.py build build/work/deb | grep -E "^(FAIL|skip|failures)" | tee build/debresult.txt
if grep -q FAIL build/debresult.txt; then exit 1; fi
# mk logs a language file, menu, screen or questionnaire that it cannot load (real mk over telnet, private copy)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/missingtest.py build/work/missing | grep -E "^(ok|FAIL|skip|failures)" | tee build/missingresult.txt
  if grep -q FAIL build/missingresult.txt; then exit 1; fi
fi
# mk -G with transport https against a real hub (two BBSs): the packet, the reply, the acknowledgement after the posting, TLS (QWK-API-PLAN.md phase 4)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/qwkhttptest.py build/work/qwkhttp | grep -E "^(ok|FAIL|skip|failures)" | tee build/qwkhttpresult.txt
  if grep -q "^FAIL" build/qwkhttpresult.txt; then exit 1; fi
fi
# menu command 172, a door of doors.cfg (DOORS-PLAN.md A): a fake dosemu, a native door, the drop files, the work directory
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/doortest.py build/work/door | grep -E "^(ok|FAIL|skip|failures)" | tee build/doorresult.txt
  if grep -q "^FAIL" build/doorresult.txt; then exit 1; fi
fi
# the door sandbox (bubblewrap; skipped when bwrap is not installed)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/sandboxtest.py build/work/sandbox | grep -E "^(ok|FAIL|skip|failures)" | tee build/sandboxresult.txt
  if grep -q "^FAIL" build/sandboxresult.txt; then exit 1; fi
fi
# the same with the real dosemu2 (skipped when it is not installed)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/dosdoorcmdtest.py build/work/dosdoorcmd | grep -E "^(ok|FAIL|skip|failures)" | tee build/dosdoorcmdresult.txt
  if grep -q "^FAIL" build/dosdoorcmdresult.txt; then exit 1; fi
fi
# statistics display codes ^T (screens and menu prompts)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/statcodestest.py build/work/statcodes | grep -E "^(ok|FAIL|skip|failures)" | tee build/statcodesresult.txt
  if grep -q "^FAIL" build/statcodesresult.txt; then exit 1; fi
fi
# QWK packets over the JSON API: the packet, the acknowledgement, the pointers, the expiry (QWK-API-PLAN.md phase 2)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/qwkapitest.py build/work/qwkapi | grep -E "^(ok|FAIL|skip|failures)" | tee build/qwkapiresult.txt
  if grep -q "^FAIL" build/qwkapiresult.txt; then exit 1; fi
fi
# the JSON API: request bodies, binary answers (QWK-API-PLAN.md phase 1)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/apibodytest.py build/work/apibody | grep -E "^(ok|FAIL|skip|failures)" | tee build/apibodyresult.txt
  if grep -q "^FAIL" build/apibodyresult.txt; then exit 1; fi
fi
# the JSON API: tokens, mkapi over HTTP and TLS, the login guard
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/apitest.py build/work/api | grep -E "^(ok|FAIL|skip|failures)" | tee build/apiresult.txt
  if grep -q "^FAIL" build/apiresult.txt; then exit 1; fi
fi
# mkcheck: a BBS that mksetup made is fine, and each thing broken in a copy is reported
if [ -f lang/AMERICAN.lc ]; then
  python3 tests/checktest.py build build/work/check | grep -E "^(ok|FAIL|skip|failures)" | tee build/checkresult.txt
  if grep -q "^FAIL" build/checkresult.txt; then exit 1; fi
fi
# mksetup: a new BBS that mk runs (a new caller registers, reads, lists files, says goodbye)
if [ -f lang/AMERICAN.lc ]; then
  python3 tests/setuptest.py build build/work/setup | grep -E "^(ok|FAIL|skip|failures)" | tee build/setupresult.txt
  if grep -q "^FAIL" build/setupresult.txt; then exit 1; fi
fi
# backslash codes in menu prompts (the real mk over telnet)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/promptesctest.py build/work/promptesc | grep -E "^(ok|FAIL|skip|failures)" | tee build/promptescresult.txt
  if grep -q "^FAIL" build/promptescresult.txt; then exit 1; fi
fi
# housekeeping of users (mkuserpurge) and of the file areas (mkfilecheck), on private copies
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/userpurgetest.py build build/work/userpurge | grep -E "^(ok|FAIL|skip|failures)" | tee build/userpurgeresult.txt
  python3 tests/filechecktest.py build build/work/filecheck | grep -E "^(ok|FAIL|skip|failures)" | tee build/filecheckresult.txt
  python3 tests/userpacktest.py build build/work/userpack | grep -E "^(ok|FAIL|skip|failures)" | tee build/userpackresult.txt
  if grep -q "^FAIL" build/userpurgeresult.txt build/filecheckresult.txt build/userpackresult.txt; then exit 1; fi
fi
# the statistics screen of the sysop monitor (S)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/statsmontest.py build/work/statsmon | grep -E "^(ok|FAIL|skip|failures)" | tee build/statsmonresult.txt
  if grep -q FAIL build/statsmonresult.txt; then exit 1; fi
fi
# the statistics: mk writes a line for each call, mkstats reports (real mk over telnet, private copy)
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/statstest.py build build/work/stats | grep -E "^(ok|FAIL|skip|failures)" | tee build/statsresult.txt
  if grep -q FAIL build/statsresult.txt; then exit 1; fi
fi
# mkmaint: the purge of message areas by their limits, on private copies
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/maintest.py build build/work/maint | grep -E "^(ok|FAIL|skip|failures)" | tee build/maintresult.txt
  if grep -q FAIL build/maintresult.txt; then exit 1; fi
fi
# mkbackup: backup, list, test, restore on a private copy
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/backuptest.py build build/work/backup | grep -E "^(ok|FAIL|skip|failures)" | tee build/backupresult.txt
  if grep -q FAIL build/backupresult.txt; then exit 1; fi
fi
# native TLS in mklisten ("tls": true): fakemk behind it, a self-signed certificate, no stunnel
python3 tests/tlstest.py build build/work/tls | grep -E "^(FAIL|skip|failures)" | tee build/tlsresult.txt
if grep -q FAIL build/tlsresult.txt; then exit 1; fi
# the SSH front: mkbbsssh between an SSH daemon (OpenSSH, Dropbear) and mklisten (skipped without ssh and sshd)
  python3 tests/sshtest.py build/work/ssh | grep -E "^(ok|FAIL|skip)" | tee build/sshresult.txt
  if grep -q FAIL build/sshresult.txt; then exit 1; fi
  # DOS doors: tools/mkdosdoor runs a door in dosemu2 with COM1 on the terminal (skipped without dosemu2)
  python3 tests/dosdoortest.py build/work/dosdoor | grep -E "^(ok|FAIL|skip)" | tee build/dosdoorresult.txt
  if grep -q FAIL build/dosdoorresult.txt; then exit 1; fi
  # FileFix: netmail to FileFix links and unlinks file echoes
  python3 tests/filefixtest.py build build/filefixwork | grep -E "^(ok|FAIL|skip)" | tee build/filefixresult.txt
  if grep -q FAIL build/filefixresult.txt; then exit 1; fi
fi
# the way in: a mkbink calls the mkbink of the BBS, the on-inbound command (mktoss) tosses the packet
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/tosshooktest.py build build/hookwork | grep -E "^(ok|FAIL|skip)" | tee build/hookresult.txt
  if grep -q FAIL build/hookresult.txt; then exit 1; fi
fi
# file requests: mkfreq (areas, profiles, magic names, passwords, limits), and the whole way in with mkbink
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/work/mkfreq build/work/freqrt
  python3 tests/mkfreqtest.py build build/work/mkfreq | grep -E "^(FAIL|skip|failures)" | tee build/freqresult.txt
  python3 tests/freqroundtrip.py build build/work/freqrt | grep -E "^(FAIL|skip|failures)" | tee -a build/freqresult.txt
  # a file echo, the whole way: a hub, the BBS (tosses, stores, passes on), a second system, mkhatch
  mkdir -p build/work/ticrt
  python3 tests/ticroundtrip.py build build/work/ticrt | grep -E "^(FAIL|skip|failures)" | tee -a build/freqresult.txt
  if grep -q FAIL build/freqresult.txt; then exit 1; fi
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
# mklisten runs the events: commands, events.sh, mailer actions, missed events, exclusive events
par_8() {
python3 tests/eventlistentest.py build/work/eventlisten | grep -E "^(ok|FAIL|skip)" | tee build/evresult.txt
if grep -q FAIL build/evresult.txt; then exit 1; fi
}
lane C par_8
# a caller before an exclusive event: told when the BBS closes, the call is cut to that (mk -T)
python3 tests/eventclosetest.py build/work/eventclose | grep -E "^(ok|FAIL|skip)" | tee build/evclose.txt
if grep -q FAIL build/evclose.txt; then exit 1; fi
# a caller who is on when an exclusive event waits is told (plain, and forced with "warn")
par_9() {
( python3 tests/eventwarntest.py build/work/eventwarn0 0; python3 tests/eventwarntest.py build/work/eventwarn1 1 ) | grep -E "^(ok|FAIL|skip)" | tee build/evwarn.txt
if grep -q FAIL build/evwarn.txt; then exit 1; fi
}
lane B par_9
# the events screen of mkmon
python3 tests/eventsmontest.py build/work/eventsmon | grep -E "^(ok|FAIL|skip)" | tee build/evmon.txt
if grep -q FAIL build/evmon.txt; then exit 1; fi
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
  # events.mk (what the events do): file, JSON, defaults
  python3 tests/eventscfgtest.py build build/work/eventscfg | grep -E "^(FAIL|failures)"
  # the event editor of mkconfig (action, command, late handling, exclusive)
  python3 tests/eventsedittest.py build/work/eventsedit | grep -E "^(FAIL|failures)"
  # the file echo pages of mkconfig (TIC: the echoes, the options, the systems)
  python3 tests/fileechoedittest.py build/work/fileechoedit | grep -E "^(FAIL|failures)"
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
par_10() {
if [ -f bbs/bbsc/ra/config.mk ]; then
  python3 tests/charsetnettest.py build/work/charsetnet | grep -E "^(FAIL|failures)"
fi
}
lane C par_10
# MKUserEd: browse, edit, delete, search, add, validate on a private copy of the sample user files
par_11() {
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/userwork
  python3 tests/usertest.py build/userwork | grep -E "^(ok|FAIL)" | tee build/userwork/result.txt
  if grep -q FAIL build/userwork/result.txt; then exit 1; fi
fi
}
lane A par_11
# the real mk with the sysop monitor: log in, chat from the monitor, time, kick (private copy of the sample BBS)
par_12() {
if [ -f bbs/bbsc/ra/config.mk ]; then
  mkdir -p build/chatwork
  python3 tests/chattest.py build/chatwork | grep -E "^(ok|FAIL)" | tee build/chatwork/result.txt
  if grep -q FAIL build/chatwork/result.txt; then exit 1; fi
fi
}
lane B par_12
lanewait
# nothing of the live sample and nothing of the snapshot may have changed during the run
if [ -f build/fixture/live.json ]; then python3 tests/fixture.py verify; fi
