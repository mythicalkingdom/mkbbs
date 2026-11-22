Unit CCvt;


Interface


Uses MKCfgAbs;



Procedure CvtCfg(Var IConfig: CfgObj; Var OConfig: CfgObj);
Procedure CvtMsg(Var IConfig: CfgObj; Var OConfig: CfgObj);
Procedure CvtEcho(Var IConfig: CfgObj; Var OConfig: CfgObj);
Procedure CvtFile(Var IConfig: CfgObj; Var OConfig: CfgObj);


Implementation


Uses MKGlobT, CfgGlob, MKString;


Procedure CvtEcho(Var IConfig: CfgObj; Var OConfig: CfgObj);
  Var
    i: Word;
    j: Word;
    Addr: AddrType;
    Mail: ^MailerCfgType;
    Ev: ^EventsCfgType;
    FE: ^FileEchoCfgType;

  Begin
  If IConfig.HasMailer And OConfig.HasMailer Then
    Begin                              {the mailer settings, when both formats keep them}
    New(Mail);
    IConfig.GetMailer(Mail^);
    OConfig.SetMailer(Mail^);
    Dispose(Mail);
    End;
  If IConfig.HasFileEcho And OConfig.HasFileEcho Then
    Begin                              {the file echoes, when both formats keep them}
    New(FE);
    IConfig.GetFileEcho(FE^);
    OConfig.SetFileEcho(FE^);
    Dispose(FE);
    End;
  If IConfig.HasEventExt And OConfig.HasEventExt Then
    Begin                              {what the events do, when both formats keep it}
    New(Ev);
    IConfig.GetEventExt(Ev^);
    OConfig.SetEventExt(Ev^);
    Dispose(Ev);
    End;
  OConfig.SetEchoMaxPkt(IConfig.GetEchoMaxPkt);
  OConfig.SetEchoInPath(IConfig.GetEchoInPath);
  OConfig.SetEchoOutPath(IConfig.GetEchoOutPath);
  For i := 1 to 32 Do
    Begin
    IConfig.GetEchoToAddr(i, Addr);
    OConfig.SetEchoToAddr(i, Addr);
    OConfig.SetEchoToPacker(i, IConfig.GetEchoToPacker(i));
    OConfig.SetEchoToMailType(i, IConfig.GetEchoToMailType(i));
    OConfig.SetEchoToPwd(i, IConfig.GetEchoToPwd(i));
    For j := 1 to 32 Do
      OConfig.SetEchoToNetwork(i, j, IConfig.GetEchoToNetwork(i, j));
    For j := 1 to 500 Do
      OConfig.SetEchoToArea(i, j, IConfig.GetEchoToArea(i, j));
    End;
  End;


Procedure CvtFile(Var IConfig: CfgObj; Var OConfig: CfgObj);
  Var
    i: Word;
    Sec: SecType;

  Begin
  For i := 1 to 300 Do
    Begin
    OConfig.SetFileAreaName(i, IConfig.GetFileAreaName(i));
    OConfig.SetFileShortName(i, IConfig.GetFileShortName(i));
    OConfig.SetFileSelect(i, IConfig.GetFileSelect(i));
    OConfig.SetFileAreaPath(i, IConfig.GetFileAreaPath(i));
    IConfig.GetFileViewSecurity(i, Sec);
    OConfig.SetFileViewSecurity(i, Sec);
    IConfig.GetFileULSecurity(i, Sec);
    OConfig.SetFileULSecurity(i, Sec);
    IConfig.GetFileDLSecurity(i, Sec);
    OConfig.SetFileDLSecurity(i, Sec);
    IConfig.GetFilePvtSecurity(i, Sec);
    OConfig.SetFilePvtSecurity(i, Sec);
    OConfig.SetFileNoUl(i, IConfig.GetFileNoUL(i));
    OConfig.SetFileFree(i, IConfig.GetFileFree(i));
    OConfig.SetFileNoTime(i, IConfig.GetFileNoTime(i));
    OConfig.SetFileNoBaud(i, IConfig.GetFileNoBaud(i));
    End;
  End;


Procedure CvtMsg(Var IConfig: CfgObj; Var OConfig: CfgObj);
  Var
    i: Word;
    j: Word;
    Sec: SecType;

  Begin
  For i := 1 to 500 Do
    Begin
    OConfig.SetMsgName(i, IConfig.GetMsgName(i));
    OConfig.SetMsgShortName(i, IConfig.GetMsgShortName(i));
    OConfig.SetMsgSelect(i, IConfig.GetMsgSelect(i));
    OConfig.SetMsgAddrNum(i, IConfig.GetMsgAddrNum(i));
    OConfig.SetMsgBaseType(i, IConfig.GetMsgBaseType(i));
    OConfig.SetMsgFileId(i, IConfig.GetMsgFileId(i));
    OConfig.SetMsgPathNum(i, IConfig.GetMsgPathNum(i));
    For j := 1 to 31 Do
      OConfig.SetMsgNetwork(i, j, IConfig.GetMsgNetwork(i, j));
    OConfig.SetMsgType(i, IConfig.GetMsgType(i));
    OConfig.SetMsgAllowPriv(i, IConfig.MsgAllowPriv(i));
    OConfig.SetMsgAllowPubl(i, IConfig.MsgAllowPubl(i));
    OConfig.SetMsgAllowReal(i, IConfig.MsgAllowReal(i));
    OConfig.SetMsgAllowHdl(i, IConfig.MsgAllowHdl(i));
    OConfig.SetMsgAllowAnon(i, IConfig.MsgAllowAnon(i));
    OConfig.SetMsgAddFido(i, IConfig.MsgAddFido(i));
    OConfig.SetMsgAllowAnsi(i, IConfig.MsgAllowAnsi(i));
    OConfig.SetMsgAllowHiBit(i, IConfig.MsgAllowHiBit(i));
    OConfig.SetMsgAllowTag(i, IConfig.MsgAllowTag(i));
    OConfig.SetMsgAllowOffline(i, IConfig.GetMsgAllowOffline(i));
    OConfig.SetMsgForceOffline(i, IConfig.GetMsgForceOffline(i));
    OConfig.SetMsgAllowCombined(i, IConfig.GetMsgAllowCombined(i));
    OConfig.SetMsgDefCombined(i, IConfig.GetMsgDefCombined(i));
    OConfig.SetMsgReaderTear(i, IConfig.GetMsgReaderTear(i));
    OConfig.SetMsgReaderOrig(i, IConfig.GetMsgReaderOrig(i));
    OConfig.SetMsgDays(i, IConfig.GetMsgDays(i));
    OConfig.SetMsgRcvdDays(i, IConfig.GetMsgRcvdDays(i));
    OConfig.SetMsgsKept(i, IConfig.GetMsgsKept(i));
    IConfig.GetMsgReadSecurity(i, Sec);
    OConfig.SetMsgReadSecurity(i, Sec);
    IConfig.GetMsgWriteSecurity(i, Sec);
    OConfig.SetMsgWriteSecurity(i, Sec);
    IConfig.GetMsgSysopSecurity(i, Sec);
    OConfig.SetMsgSysopSecurity(i, Sec);
    OConfig.SetEchoAreaTag(i, IConfig.GetEchoAreaTag(i));
    OConfig.SetEchoAreaImportPath(i, IConfig.GetEchoAreaImportPath(i));
    OConfig.SetEchoAreaHidePath(i, IConfig.GetEchoAreaHidePath(i));
    OConfig.SetEchoAreaImportSeen(i, IConfig.GetEchoAreaImportSeen(i));
    OConfig.SetEchoAreaHideSeen(i, IConfig.GetEchoAreaHideSeen(i));
    OConfig.SetEchoAreaPassThru(i, IConfig.GetEchoAreaPassThru(i));
    OConfig.SetMsgOrigNum(i, IConfig.GetMsgOrigNum(i));
    End;
  End;


Procedure CvtCfg(Var IConfig: CfgObj; Var OConfig: CfgObj);
  Var
    i: Word;
    j: Word;
    Addr: AddrType;
    Sec: SecType;

  Begin
  For i := 1 to 10 Do
    Begin
    OConfig.SetMsgPath(i, IConfig.GetMsgPath(i));
    End;
  For i := 1 to 10 Do
    Begin
    OConfig.SetTxtPath(i, IConfig.GetTxtPath(i));
    OConfig.SetMnuPath(i, IConfig.GetMnuPath(i));
    End;
  For i := 1 to 10 Do
    OConfig.SetOffTypeAvail(i, IConfig.GetOffTypeAvail(i));
  For i := 1 to 10 Do
    OConfig.SetOffBulls(i, IConfig.GetOffBulls(i));
  For i := 1 to 5 Do
    OConfig.SetOffScrns(i, IConfig.GetOffScrns(i));
  OConfig.SetDefaultPort(IConfig.GetDefaultPort);
  OConfig.SetNetPath(IConfig.GetNetPath);
  OConfig.SetTempPath(IConfig.GetTempPath);
  OConfig.SetLogFileName(IConfig.GetLogFileName);
  OConfig.SetEditCmdPath(IConfig.GetEditCmdPath);
  OConfig.SetNodeListPath(IConfig.GetNodeListPath);
  OConfig.SetAttachPath(IConfig.GetAttachPath);
  OConfig.SetSemaphorePath(IConfig.GetSemaphorePath);
  OConfig.SetQuoteStr(IConfig.GetQuoteStr);
  For i := 1 to 11 Do
    Begin
    IConfig.GetAddr(i, Addr);
    OConfig.SetAddr(i, Addr);
    End;
  For i := 1 to 20 Do
    OConfig.SetOrigStr(i, IConfig.GetOrigStr(i));
  OConfig.SetBbsName(IConfig.GetBbsName);
  OConfig.SetBbsLoc(IConfig.GetBbsLoc);
  OConfig.SetBbsPhone(IConfig.GetBbsPhone);
  OConfig.SetBbsId(IConfig.GetBbsId);
  OConfig.SetDirectWrite(IConfig.GetDirectWrite);
  OConfig.SetSnowCheck(IConfig.GetSnowCheck);
  OConfig.SetMonoMode(IConfig.GetMonoMode);
  OConfig.SetForceKillYes(IConfig.GetForceKillYes);
  OConfig.SetForceKillAsk(IConfig.GetForceKillAsk);
  OConfig.SetMailCheckDetail(IConfig.GetMailCheckDetail);
  OConfig.SetMailCheckTotal(IConfig.GetMailCheckTotal);
  OConfig.SetPrnName(IConfig.GetPrnName);
  For i := 0 to 7 Do
    Begin
    OConfig.SetPageStart(i, IConfig.GetPageStart(i));
    OConfig.SetPageStop(i, IConfig.GetPageStop(i));
    End;
  OConfig.SetPageMsgArea(IConfig.GetPageMsgArea);
  OConfig.SetMaxPageTimes(IConfig.GetMaxPageTimes);
  OConfig.SetPageLength(IConfig.GetPageLength);
  OConfig.SetDefaultPage(IConfig.GetDefaultPage);
  OConfig.SetAskPageReason(IConfig.GetAskPageReason);
  For i := 1 to 10 Do
    Begin
    OConfig.SetLangName(i, IConfig.GetLangName(i));
    OConfig.SetLangFile(i, IConfig.GetLangFile(i));
    OConfig.SetLangQuesPath(i, IConfig.GetLangQuesPath(i));
    End;
  OConfig.SetAskVoicePhone(IConfig.GetAskVoicePhone);
  OConfig.SetAskDataPhone(IConfig.GetAskDataPhone);
  OConfig.SetNewUserNMCredit(IConfig.GetNewUserNMCredit);
  OConfig.SetAskBirthDate(IConfig.GetAskBirthDate);
  OConfig.SetAskGender(IConfig.GetAskGender);
  OConfig.SetAskAddr(IConfig.GetAskAddr);
  OConfig.SetSevenBitNames(IConfig.GetSevenBitNames);
  OConfig.SetOneWordName(IConfig.GetOneWordName);
  OConfig.SetReAsk(IConfig.GetReAsk);
  OConfig.SetAskHandle(IConfig.GetAskHandle);
  OConfig.SetPwdTries(IConfig.GetPwdTries);
  OConfig.SetPwdExpire(IConfig.GetPwdExpire);
  OConfig.SetLockFails(IConfig.GetLockFails);
  OConfig.SetLockMinutes(IConfig.GetLockMinutes);
  OConfig.SetPwdWarn(IConfig.GetPwdWarn);
  OConfig.SetBDCheck(IConfig.GetBDCheck);
  OConfig.SetPhoneCheck(IConfig.GetPhoneCheck);
  OConfig.SetMinPwd(IConfig.GetMinPwd);
  OConfig.SetMinPhone(IConfig.GetMinPhone);
  OConfig.SetStrictPwd(IConfig.GetStrictPwd);
  OConfig.SetRemoteSysop(IConfig.GetRemoteSysop);
  OConfig.SetFastLocal(IConfig.GetFastLocal);
  IConfig.GetNewUserSec(Sec);
  OConfig.SetNewUserSec(Sec);
  IConfig.GetAttachSec(Sec);
  OConfig.SetAttachSec(Sec);
  IConfig.GetRequestSec(Sec);
  OConfig.SetRequestSec(Sec);
  IConfig.GetCrashNMSec(Sec);
  OConfig.SetCrashNMSec(Sec);
  IConfig.GetForceCrashNMSec(Sec);
  OConfig.SetForceCrashNMSec(Sec);
  IConfig.GetDeleteSec(Sec);
  OConfig.SetDeleteSec(Sec);
  ICOnfig.GetUnRcvSec(Sec);
  OConfig.SetUnRcvSec(Sec);
  For i := 1 to 11 Do
    Begin
    OConfig.SetModemResp(i, IConfig.GetModemResp(i));
    OConfig.SetErrorLevel(i, IConfig.GetErrorLevel(i));
    End;
  OConfig.SetDLStart(IConfig.GetDLStart);
  OConfig.SetDLStop(IConfig.GetDLStop);
  OConfig.SetLoBaudStart(IConfig.GetLoBaudStart);
  OConfig.SetLoBaudStop(IConfig.GetLoBaudStop);
  OConfig.SetMinXferBaud(IConfig.GetMinXferBaud);
  OConfig.SetULCredit(IConfig.GetULCredit);
  OConfig.SetMinDesc(IConfig.GetMinDesc);
  OConfig.SetMaxDesc(IConfig.GetMaxDesc);
  OConfig.SetMinFree(IConfig.GetMinFree);
  OConfig.SetAskNewFiles(IConfig.GetAskNewFiles);
  OConfig.SetForceNewFiles(IConfig.GetForceNewFiles);
  OConfig.SetEchoLog(IConfig.GetEchoLog);
  For i := 1 to 5 Do
    OConfig.SetSystemColor(i, IConfig.GetSystemColor(i));
  OConfig.SetSysopName(IConfig.GetSysopName);
  For i := 1 to 30 Do
    Begin
    OConfig.SetEventStatus(i, IConfig.GetEventStatus(i));
    OConfig.SetEventTime(i, IConfig.GetEventTime(i));
    OConfig.SetEventEL(i, IConfig.GetEventEL(i));
    OConfig.SetEventDays(i, IConfig.GetEventDays(i));
    OConfig.SetEventForced(i, IConfig.GetEventForced(i));
    End;
  For i := 1 to 10 Do
    Begin
    IConfig.GetDoorSec(i, Sec);
    OConfig.SetDoorSec(i, Sec);
    OConfig.SetDoorData(i, IConfig.GetDoorData(i));
    End;
  For i := 1 to 20 Do
    Begin
    OConfig.SetProtNormAvail(i, IConfig.GetProtNormAvail(i));
    OConfig.SetProtSpecAvail(i, IConfig.GetProtSpecAvail(i));
    OConfig.SetProtChar(i, IConfig.GetProtChar(i));
    OConfig.SetProtName(i, IConfig.GetProtName(i));
    End;
  OConfig.SetOffAllowNew(IConfig.GetOffAllowNew);
  OConfig.SetOffForceNew(IConfig.GetOffForceNew);
  OConfig.SetOffAllowScrn(IConfig.GetOffAllowScrn);
  OConfig.SetOffForceScrn(IConfig.GetOffForceScrn);
  OConfig.SetOffAllowBull(IConfig.GetOffAllowBull);
  OConfig.SetOffForceBull(IConfig.GetOffForceBull);
  OConfig.SetOffAllowFreq(IConfig.GetOffAllowFreq);
  OConfig.SetOffMax(IConfig.GetOffMax);
  OConfig.SetOffConfMax(IConfig.GetOffConfMax);
  OConfig.SetOffCompRate(IConfig.GetOffCompRate);
  OConfig.SetOffSafetyMin(IConfig.GetOffSafetyMin);
{  MKCfg.TimeOut := 240;}
{  MKCfg.LogInTime := 15;}
{  MKCfg.AnsiBaud := 1200;}
{  MKCfg.WaitTime := 0; }
{  MKCfg.OfflineMax := 1000; }
{  MKCfg.OfflineConfMax := 200;}
{  MKCfg.Default := 1; }
{  MKCfg.Announce := 200; }
{  For i := 1 to 40 Do
     MKCfg.AddOn[i] := 0; }
{  MKCfg.LogAttr := laOpus + laNormal; }
  End;


End.
