{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit Default;   {Default values for a new configuration; paths are relative to the BBS directory}

{$I MKB.Def}

Interface


Uses MKCfgAbs, MKCfgMK;



Procedure SetCfgDefaults(Var DConfig: CfgObj);
Procedure SetMsgDefaults(Var DConfig: CfgObj);
Procedure SetEchoDefaults(Var DConfig: CfgObj);
Procedure SetFileDefaults(Var DConfig: CfgObj);


Implementation


Uses MKGlobT, CfgGlob, MKString;


Procedure SetEchoDefaults(Var DConfig: CfgObj);
  Var
    i: Word;
    j: Word;
    Addr: AddrType;

  Begin
  Addr.Zone := 0;
  Addr.Net := 0;
  Addr.Node := 0;
  Addr.Point := 0;
  DConfig.SetEchoMaxPkt(100000);
  DConfig.SetEchoInPath('files/');
  DConfig.SetEchoOutPath('mail/');
  For i := 1 to 32 Do
    Begin
    DConfig.SetEchoToAddr(i, Addr);
    DConfig.SetEchoToPacker(i, 1);
    DConfig.SetEchoToMailType(i, esNormal);   {Normal: Hold mail is only sent when the other system calls us}
    DConfig.SetEchoToPwd(i, '');
    For j := 1 to 32 Do
      DConfig.SetEchoToNetwork(i, j, False);
    For j := 1 to 500 Do
      DConfig.SetEchoToArea(i, j, False);
    End;
  End;


Procedure SetFileDefaults(Var DConfig: CfgObj);
  Var
    i: Word;
    Sec: SecType;
    PSec: SecType;

  Begin
  Sec.Level := 10;
  PSec.Level := 100;
  Sec.Flags := 0;
  PSec.Flags := 0;
  For i := 1 to 300 Do
    Begin
    DConfig.SetFileAreaName(i, '');
    DConfig.SetFileShortName(i, '');
    DConfig.SetFileSelect(i, '');
    DConfig.SetFileAreaPath(i, '');
    DConfig.SetFileViewSecurity(i, Sec);
    DConfig.SetFileULSecurity(i, Sec);
    DConfig.SetFileDLSecurity(i, Sec);
    DConfig.SetFilePvtSecurity(i, PSec);
    DConfig.SetFileNoUl(i, False);
    DConfig.SetFileFree(i, False);
    DConfig.SetFileNoTime(i, False);
    DConfig.SetFileNoBaud(i, False);
    End;
  End;


Procedure SetMsgDefaults(Var DConfig: CfgObj);
  Var
    i: Word;
    j: Word;
    RSec: SecType;
    WSec: SecType;
    SSec: SecType;

  Begin
  RSec.Level := 5;
  WSec.Level := 10;
  SSec.Level := 100;
  RSec.Flags := 0;
  WSec.Flags := 0;
  SSec.Flags := 0;
  For i := 1 to 500 Do
    Begin
    DConfig.SetMsgPathNum(i, 1);
    DConfig.SetMsgBaseType(i, 'S');
    DConfig.SetMsgFileId(i,'');
    DConfig.SetMsgOrigNum(i, 1);
    DConfig.SetMsgName(i, '');
    DConfig.SetMsgShortName(i, '');
    DConfig.SetMsgSelect(i, '');
    DConfig.SetMsgAddrNum(i, 1);
    For j := 1 to 31 Do
      DConfig.SetMsgNetwork(i, j, False);
    DConfig.SetMsgType(i, Normal);
    DConfig.SetMsgAllowPriv(i, True);
    DConfig.SetMsgAllowPubl(i, True);
    DConfig.SetMsgAllowReal(i, True);
    DConfig.SetMsgAllowHdl(i, False);
    DConfig.SetMsgAllowAnon(i, False);
    DConfig.SetMsgAddFido(i, True);
    DConfig.SetMsgAllowAnsi(i, False);
    DConfig.SetMsgAllowHiBit(i, False);
    DConfig.SetMsgAllowTag(i, False);
    DConfig.SetMsgAllowOffline(i, True);
    DConfig.SetMsgForceOffline(i, False);
    DConfig.SetMsgAllowCombined(i, True);
    DConfig.SetMsgDefCombined(i, False);
    DConfig.SetMsgReaderTear(i, False);
    DConfig.SetMsgReaderOrig(i, False);
    DConfig.SetMsgDays(i, 7);
    DConfig.SetMsgRcvdDays(i, 7);
    DConfig.SetMsgsKept(i, 200);
    DConfig.SetMsgReadSecurity(i, RSec);
    DConfig.SetMsgWriteSecurity(i, WSec);
    DConfig.SetMsgSysopSecurity(i, SSec);
    DConfig.SetEchoAreaTag(i, '');
    DConfig.SetEchoAreaImportPath(i, True);
    DConfig.SetEchoAreaHidePath(i, True);
    DConfig.SetEchoAreaImportSeen(i, False);
    DConfig.SetEchoAreaHideSeen(i, True);
    DConfig.SetEchoAreaPassThru(i, False);
    End;
  End;


Procedure SetCfgDefaults(Var DConfig: CfgObj);
  Var
    i: Word;
    j: Word;
    Addr: AddrType;
    Sec1: SecType;
    Sec2: SecType;

  Begin
  Sec1.Level := 5;
  Sec2.Level := 100;
  Sec1.Flags := 0;
  Sec2.Flags := 0;
  Addr.Zone := 0;
  Addr.Net := 0;
  Addr.Node := 0;
  Addr.Point := 0;
  For i := 1 to 10 Do
    Begin
    DConfig.SetMsgPath(i, '');
    End;
  For i := 1 to 10 Do
    Begin
    DConfig.SetTxtPath(i, '');
    DConfig.SetMnuPath(i, '');
    End;
  For i := 1 to 10 Do
    DConfig.SetOffTypeAvail(i, False);
  For i := 1 to 10 Do
    DConfig.SetOffBulls(i, '');
  For i := 1 to 5 Do
    DConfig.SetOffScrns(i, '');
  DConfig.SetDefaultPort(1);
  DConfig.SetNetPath('mail/');
  DConfig.SetTempPath('');
  DConfig.SetLogFileName('mk.log');
  DConfig.SetEditCmdPath('');
  DConfig.SetNodeListPath('nodelist/');
  DConfig.SetAttachPath('attach/');
  DConfig.SetSemaphorePath('sem/');
  DConfig.SetEchoLog('echotoss.log');
  DConfig.SetQuoteStr(' @>');
  For i := 1 to 11 Do
    DConfig.SetAddr(i, Addr);
  For i := 1 to 20 Do
    DConfig.SetOrigStr(i, '');
  DConfig.SetOrigStr(1, 'MK Bbs - Default Origin String');
  DConfig.SetBbsName('MK Bbs');
  DConfig.SetBbsLoc('AnyCity, State/Country');
  DConfig.SetBbsPhone('513-237-7737');
  DConfig.SetBbsId('MKBBS');
  DConfig.SetDirectWrite(True);
  DConfig.SetSnowCheck(False);
  DConfig.SetMonoMode(False);
  DConfig.SetMailCheckDetail(False);
  DConfig.SetMailCheckTotal(True);
  DConfig.SetForceKillYes(False);
  DConfig.SetForceKillAsk(False);
  For i := 0 to 7 Do
    Begin
    DConfig.SetPageStart(i, $0800);
    DConfig.SetPageStop(i, $1600);
    End;
  DConfig.SetMaxPageTimes(4);
  DConfig.SetPageLength(10);
  DConfig.SetDefaultPage(1);
  DConfig.SetAskPageReason(True);
  For i := 1 to 10 Do
    Begin
    DConfig.SetLangName(i, '');
    DConfig.SetLangFile(i, '');
    DConfig.SetLangQuesPath(i, '');
    End;
  DConfig.SetLangName(1, 'Normal');
  DConfig.SetLangFile(1, 'prompts');
  DConfig.SetAskVoicePhone(True);
  DConfig.SetAskDataPhone(True);
  DConfig.SetNewUserNMCredit(0);
  DConfig.SetAskBirthDate(True);
  DConfig.SetAskGender(True);
  DConfig.SetAskAddr(True);
  DConfig.SetSevenBitNames(True);
  DConfig.SetOneWordName(False);
  DConfig.SetReAsk(True);
  DConfig.SetAskHandle(False);
  DConfig.SetPwdTries(3);
  DConfig.SetPwdExpire(0);
  DConfig.SetLockFails(0);
  DConfig.SetLockMinutes(15);
  DConfig.SetPwdWarn(0);
  DConfig.SetBDCheck(11);
  DConfig.SetPhoneCheck(7);
  DConfig.SetMinPwd(4);
  DConfig.SetMinPhone(10);
  DConfig.SetStrictPwd(False);
  DConfig.SetRemoteSysop(True);
  DConfig.SetFastLocal(False);
  DConfig.SetNewUserSec(Sec1);
  DConfig.SetAttachSec(Sec2);
  DConfig.SetRequestSec(Sec2);
  DConfig.SetCrashNMSec(Sec2);
  DConfig.SetForceCrashNMSec(Sec2);
  DConfig.SetDeleteSec(Sec1);
  DConfig.SetUnRcvSec(Sec1);
  DConfig.SetModemResp(1,'');
  DConfig.SetModemResp(2,'CONNECT|');
  DConfig.SetModemResp(3,'CONNECT 1200');
  DConfig.SetModemResp(4,'CONNECT 2400');
  DConfig.SetModemResp(5,'CONNECT 4800');
  DConfig.SetModemResp(6,'CONNECT 7200');
  DConfig.SetModemResp(7,'CONNECT 9600');
  DConfig.SetModemResp(8,'CONNECT 12000');
  DConfig.SetModemResp(9,'CONNECT 14400');
  DConfig.SetModemResp(10,'CONNECT 19200');
  DConfig.SetModemResp(11,'CONNECT 38400');
  For i := 1 to 11 Do
    DConfig.SetErrorLevel(i, 0);
  DConfig.SetDLStart(0);
  DConfig.SetDLStop($1800);
  DConfig.SetLoBaudStart(0);
  DConfig.SetLoBaudStop($1800);
  DConfig.SetMinXferBaud(1200);
  DConfig.SetULCredit(0);
  DConfig.SetMinDesc(10);
  DConfig.SetMaxDesc(240);
  DConfig.SetMinFree(512000);
  DConfig.SetAskNewFiles(False);
  DConfig.SetForceNewFiles(False);
  DConfig.SetSystemColor(1, 15);
  DConfig.SetSystemColor(2, 11);
  DConfig.SetSystemColor(3, 10);
  DConfig.SetSystemColor(4, 09);
  DConfig.SetSystemColor(5, 15);
  DConfig.SetSysopName('Mark May');
  DConfig.SetPageMsgArea(200);
  For i := 1 to 30 Do
    Begin
    DConfig.SetEventStatus(i, 0);
    DConfig.SetEventTime(i, $0000);
    DConfig.SetEventEL(i, 0);
    DConfig.SetEventDays(i, 0);
    DConfig.SetEventForced(i, 0);
    End;
  For i := 1 to 10 Do
    Begin
    DConfig.SetDoorSec(i, Sec1);
    DConfig.SetDoorData(i, '');
    End;
  For i := 08 to 20 Do
    Begin
    DConfig.SetProtNormAvail(i, False);
    DConfig.SetProtSpecAvail(i, False);
    DConfig.SetProtChar(i, ' ');
    DConfig.SetProtName(i, '');
    End;
  For i := 1 to 7 Do
    Begin
    DConfig.SetProtNormAvail(i, True);
    DConfig.SetProtSpecAvail(i, True);
    End;
  DConfig.SetProtChar(1,'X');
  DConfig.SetProtChar(2,'O');
  DConfig.SetProtChar(3,'Y');
  DConfig.SetProtChar(4,'Z');
  DConfig.SetProtChar(5,'G');
  DConfig.SetProtChar(6,'Q');
  DConfig.SetProtChar(7,'S');
  DConfig.SetProtName(1, 'Xmodem');
  DConfig.SetProtName(2, '1k-Xmodem');
  DConfig.SetProtName(3, 'Ymodem');
  DConfig.SetProtName(4, 'Zmodem');
  DConfig.SetProtName(5, 'Ymodem-G');
  DConfig.SetProtName(6, 'Xmodem-G');
  DConfig.SetProtName(7, 'Sealink');
  DConfig.SetPackAvail(1, True);
  DConfig.SetPackAvail(2, True);
  DConfig.SetPackAvail(3, True);
  DConfig.SetPackAvail(4, False);
  DConfig.SetPackAvail(4, False);
  DConfig.SetPackAvail(5, False);
  DConfig.SetPackAvail(6, False);
  DConfig.SetPackAvail(7, False);
  DConfig.SetPackAvail(8, False);
  DConfig.SetPackAvail(9, False);
  DConfig.SetPackAvail(10, False);
  DConfig.SetPackChar(1, 'L');
  DConfig.SetPackChar(2, 'Z');
  DConfig.SetPackChar(3, 'A');
  DConfig.SetPackChar(4, 'O');
  DConfig.SetPackChar(5, 'D');
  DConfig.SetPackChar(6, 'J');
  DConfig.SetPackChar(7, 'H');
  DConfig.SetPackChar(8, ' ');
  DConfig.SetPackChar(9, ' ');
  DConfig.SetPackChar(10, ' ');
  DConfig.SetPackName(1, 'LHA/LZH');
  DConfig.SetPackName(2, 'ZIP');
  DConfig.SetPackName(3, 'ARC');
  DConfig.SetPackName(4, 'ZOO');
  DConfig.SetPackName(5, 'DWC');
  DConfig.SetPackName(6, 'ARJ');
  DConfig.SetPackName(7, 'HYP');
  DConfig.SetPackName(8, '');
  DConfig.SetPackName(9, '');
  DConfig.SetPackName(10, '');
  DConfig.SetPackCmdLine(1,'LHA.EXE a -m');
  DConfig.SetUnPackCmdLine(1,'LHA.EXE e -m');
  DConfig.SetPackCmdLine(2,'PKZIP.EXE -a');
  DConfig.SetUnPackCmdLine(2,'PKUNZIP.EXE -ed -o');
  DConfig.SetPackCmdLine(3,'PKUNPAK.EXE -a');
  DConfig.SetUnPackCmdLine(3,'PKPAK.EXE -r');
  DConfig.SetPackCmdLine(4,'ZOO.EXE a');
  DConfig.SetUnPackCmdLine(4,'ZOO.EXE eoo');
  DConfig.SetPackCmdLine(5,'DWC.EXE a');
  DConfig.SetUnPackCmdLine(5,'DWC.EXE e');
  DConfig.SetPackCmdLine(6,'ARJ.EXE a -y');
  DConfig.SetUnPackCmdLine(6,'ARJ.EXE e -y');
  DConfig.SetPackCmdLine(7,'HYPER.EXE -a');
  DConfig.SetUnPackCmdLine(7,'HYPER.EXE -xo');
  DConfig.SetOffAllowNew(True);
  DConfig.SetOffForceNew(False);
  DConfig.SetOffAllowScrn(True);
  DConfig.SetOffForceScrn(False);
  DConfig.SetOffAllowBull(True);
  DConfig.SetOffForceBull(False);
  DConfig.SetOffAllowFreq(True);
  DConfig.SetOffMax(2000);
  DConfig.SetOffConfMax(900);
  DConfig.SetOffCompRate(50);
  DConfig.SetOffSafetyMin(5);
{  MKCfg.TimeOut := 240;}
{  MKCfg.LogInTime := 15;}
{  MKCfg.AnsiBaud := 1200;}
{  MKCfg.WaitTime := 0; }
{  MKCfg.Default := 1; }
{  MKCfg.Announce := 200; }
{  For i := 1 to 40 Do
     MKCfg.AddOn[i] := 0; }
{  MKCfg.LogAttr := laOpus + laNormal; }
  End;


End.
