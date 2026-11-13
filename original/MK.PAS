Program MK;
{$IFDEF WINDOWS}
{$M 32768, 8196}
{$ELSE}
{$M 32768, 200000, 655360}
{$ENDIF}

{$I MKB.Def}
{$X+}

{$IFDEF WINDOWS}
Uses MKWCrt, WinDos,
{$ELSE}
  Uses
  {$IFNDEF DPMI}
  Overlay,
  {$ENDIF}
  Extend, MKScrn,
  {$IFDEF OPRO}
  OpCrt,
  {$ELSE}
  Crt,
  {$ENDIF}
{$ENDIF}
MKGlobT, MKMenus, MKCmd, MKDoor, MKString, MKLogEnt, MKFossil,
MKSys, MKCodes, MKFile, MKCfgAbs, MKRCfgMK, MKRCfgRA, MKCfgQb, MKCfgSb,
MKLogOn, MKAvatar
{$IFDEF WINDOWS}
;
{$ELSE}
  {$IFNDEF DPMI}
  ,ExecAcc, ExecSwap;
  {$ELSE}
  ;
  {$ENDIF}
{$ENDIF}


{$IFNDEF WINDOWS}
{$IFNDEF DPMI}
{.$O MKCmd}
{$O MKMiscB}
{$O MKProt}
{$O MKRCfgMK}
{$O MKRCfgRA}
{$O MKCfgQB}
{$O MKCfgSB}
{$O MKCFile}
{$O MKMRead}
{$O MKEnter}
{$O MKBFile}
{$O MKPage}
{$O MKMusic}
{$O MKQuest}
{$O MKPack}
{$O MKMsgEzy}
{$O MKCodes}
{$O MKMsgFid}
{$O MKMsgHud}
{$O MKMsgSqu}
{$O MKMsgJam}
{$O MKMsgAbs}
{$O MKOpen}
{.$O MKShell}
{$O MKMsgSel}
{.$O MKName}
{.$O MKLogEnt}
{$O MKLogOn}
{$O CRC16}
{$O CRC32}
{$O MKCD}
{$O MKOffAbs}
{$O MKOffQwk}
{$O MKOffBwv}
{$O MKOffXrs}
{$O MKOffTxt}
{$O MKOffLin}
{$ENDIF}
{$ENDIF}


Var
  ExitLevel: Byte;
  i: Word;
  BbsType: Word;
  TmpStr: String;
  MailerStr: String;

Begin
StartUpPath := GetCurrentPath;
{$IFDEF OPRO}
  {$IFNDEF WINDOWS}
  DetectMultitasking := True;
  ReInitCrt;
  {$ENDIF}
{$ENDIF}
{$IFNDEF WINDOWS}
{$IFNDEF DPMI}
OvrFileMode := 64; {readonly + denynone}
OvrInit('MK.OVR');
If OvrResult <> 0 Then
  Begin
  WriteLn(Long2Str(OvrResult) + ' Error loading MK.OVR');
  Halt(1);
  End;
OvrSetBuf(80000);
ExecAcc.NWInitExecSwap := ExecSwap.InitExecSwap;
ExecAcc.NWShutDownExecSwap := ExecSwap.ShutDownExecSwap;
ExecAcc.ExecWithSwap := ExecSwap.ExecWithSwap;
ExecAcc.NWUseEMSSwap := ExecSwap.NWUseEMSSwap;
{$ENDIF}
{$ENDIF}
i := 1;
While i <= ParamCount Do
  Begin
  TmpStr := Upper(ParamStr(i));
  If ((TmpStr[1] = '-') or (TmpStr[1] = '/')) Then
    Begin
    Case TmpStr[2] of
      'B': UserBaud := Str2Long(Copy(TmpStr,3,5));
      'C': OverridePort := Str2Long(Copy(TmpStr,3,5));
      'E': ExitErrorLevel := Str2Long(Copy(TmpStr,3,5));
      'L': LocalMode := True;
      'M': Begin
           ShellToMailer := True;
           MailerStr := Copy(TmpStr,3,128);
           End;
      'N': Begin
           If Copy(TmpStr,2,5) = 'NOEMS' Then
             UseEms := False
           Else
             NodeNumber := Str2Long(Copy(TmpStr,3,5));
           End;
      'P': LogToPrinter := True;
      'R': Reload := True;
      'S': Case TmpStr[3] of
             'D': CommForce := 2;
             'F': CommForce := 1;
             End;
      'T': TimeToEvent := Str2Long(Copy(TmpStr,3,5));
      'V': Begin
           ScrnWidth := 80;
           ScrnHeight := 25;
           End;
      'Z': OverrideBaud := Str2Long(Copy(TmpStr,3,5));
      End;
    End;
  Inc(i);
  End;
{$IFNDEF WINDOWS}
{$IFNDEF DPMI}
If UseEMS Then
  Begin
  OvrInitEMS;
  If ((OvrResult < 0) and (OvrResult > -5)) Then
    Begin
    WriteLn(Long2Str(OvrResult) + ' Error loading MK.OVR' );
    Halt(1);
    End;
  End;
NWUseEmsSwap(UseEMS);
{$ENDIF}
{$ENDIF}
BbsType := DetectBbsType;
Case BbsType Of
  1: Config := New(MKRCfgObjPtr, Init);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(Long2Str(Config^.GetError) + ': Error loading config files');
  Halt(0);
  End;
DirectVideo := Config^.GetDirectWrite;
CheckSnow := Config^.GetSnowCheck;
User.Init;
User.SetUserBbsType(BbsType);
User.SetUserLineNum(NodeNumber);
User.PostStatus(uoWait);
If OverridePort <> 0 Then
  CurrentPort := OverridePort
Else
  CurrentPort := Config^.GetDefaultPort;
LogEntry.Init;
If IoResult <> 0 Then;
If LogToPrinter Then
  LogEntry.SetPrnName(Config^.GetPrnName);
ClrScr;
Sem.Init;
Sem.SetNode(NodeNumber);
Sem.SetCheckPath(Config^.GetSemaphorePath);
Sem.SetCheckDelay(100);
Sem.CI^.ShowOut := True;
Sem.CI^.CheckIn := True;
Prompts.Init;
Prompts.Load(Config^.FindBbsFile(Config^.GetLangFile(1) + '.LC') +
  Config^.GetLangFile(1) + '.LC');
CommaChar := Prompts.GetChar(320);
SysStats.Load;
If LocalMode Then
  Begin
  CurrentPort := 0;
  UserBaud := 0;
  End
Else
  Begin
  AnsiSoundOn := False;
  If OverRidePort <> 0 Then
    CurrentPort := OverRidePort
  Else
    CurrentPort := 1; {Config^.GetCommPort;}
  End;
If ShellToMailer Then
  Begin
  User.PostStatus(uoWait);
  DoMailer(MailerStr);
  End;
BbsDisplay.Init;
User.SetSessionTimeLimit(600);
User.SetStartTime;
User.SetIdleTimeLimit(240);
User.StatusDisplay(User.GetStatusType);
User.SetUserBaud(UserBaud);
If Reload Then
  Begin
  User.ReadExit('');
  User.ReadDorInfo('');
  If CurrentPort <> 0 Then
    Begin
    CommInit;
    CommFlow(fcHard);
    End;
  If OverrideBaud = 0 Then
    CommSetBaud(UserBaud)
  Else
    CommSetBaud(OverrideBaud);
  End
Else
  Begin
  If CurrentPort <> 0 Then
    Begin
    CommInit;
    CommFlow(fcHard);
    End;
  If OverrideBaud = 0 Then
    CommSetBaud(UserBaud)
  Else
    CommSetBaud(OverrideBaud);
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(344));
  User.DetectAnsi;
  User.DisplayStr(#13 + PadRight('',' ', Length(Prompts.GetString(344)) + 10) + #13);
  User.SetUserAnsi(User.WasAnsiDetected);
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(BbsVersion);
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStrLn(Copyright);
  User.DisplayNewLine;
  DoLanguage;
  BbsDisplay.DisplayBbsFile('LOGO', '');
  StartUpUser;
  AskName;
  End;
User.GetUserSec(Sec);
User.ClearScreen;
User.DisplayNewLine;
User.StatusDisplay(User.GetStatusType);
User.ClearScreen;
User.DisplayAttr(Config^.GetSystemColor(1));
User.SetMore(True);
If IoResult <> 0 Then;
Menu.Init;
Menu.SetSecurity(Sec);
Menu.Load('TOP');
Menu.GlobalLoad('GLOBAL');
If Menu.GetError <> 0 Then
  Begin
  User.DisplayStrLn('Unable to load top menu ' + Long2Str(Menu.GetError));
  Halt(1);
  End;
MenuState := 1;
Process;
User.WriteUser;
User.WriteExit('');
If User.UserIsLoaded Then
  Begin
  LogEntry.WriteEntry('Offline Reason = ' + Long2Str(User.GetNotOkReason));
  LogEntry.WriteEntry('Comm Port = ' + Long2Str(CurrentPort));
  LogEntry.WriteEntry('Current Baud = ' + Long2Str(UserBaud));
  LogEntry.WriteEntry('User off-line');
  LogOffSysInfo;
  End;
User.PostStatus(uoWait);
BbsDisplay.Done;
Menu.Done;
If DoorExit Then
  ExitLevel := DoorLevel
Else
  Begin
  ExitLevel := ExitErrorLevel;
  End;
User.PostStatus(uoNotAvail);
User.Done;
LogEntry.WriteEntry('Leaving MK Bbs');
LogEntry.Done;
Config^.Done;
Sem.Done;
CommRelease;
Halt(ExitLevel);
End.
