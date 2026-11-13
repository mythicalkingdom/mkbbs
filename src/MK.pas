Program MK;

{$I MKB.Def}
{$X+}

Uses
  MKScrn, MKVCrt, MKSess,
MKGlobT, MKMenus, MKCmd, MKDoor, MKString, MKLogEnt, MKComAbs,
MKSys, MKCodes, MKFile, MKCfgAbs, MKRCfgMK, MKRCfgRA, MKCfgQB, MKCfgSB,
MKLogOn, MKAvatar, MKSnoop, Dos
  ;




Var
  ExitLevel: Byte;
  i: Word;
  BbsType: Word;
  TmpStr: String;
  MailerStr: String;
  SessType: String;
  SessAddr: String;
  SessRate: LongInt;
  SessProxy: Boolean;
  RunDir: String;

Begin
StartUpPath := GetCurrentPath;
{Standard output is the caller (MKComStd): anything the units Write() as plain
 local display goes to the virtual screen instead.  Fatal start up messages
 use StdErr.}
AssignVCrt(Output);
Rewrite(Output);
SessType := '';
SessAddr := '';
SessRate := 0;
SessProxy := False;
i := 1;
While i <= ParamCount Do
  Begin
  TmpStr := Upper(ParamStr(i));
  If ((TmpStr[1] = '-') or (TmpStr[1] = '/')) Then
    Begin
    Case TmpStr[2] of
      'A': SessAddr := Copy(ParamStr(i), 3, 64);
      'B': Begin
           SessRate := Str2Long(Copy(TmpStr,3,7)); {asked for: emulate that line speed}
           If SessRate > 65535 Then
             UserBaud := 65535         {the user record keeps a Word}
           Else
             UserBaud := SessRate;
           End;
      'S': SessType := Copy(TmpStr,3,10);
      'H': SessProxy := True;      {PROXY header first on the connection}
      'P': LogToPrinter := True;
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
      'R': Reload := True;
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
BbsType := DetectBbsType;
Case BbsType Of
  1: Config := New(MKRCfgObjPtr, Init);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory');
  Halt(1);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, Long2Str(Config^.GetError) + ': Error loading config files');
  Halt(0);
  End;
DirectVideo := Config^.GetDirectWrite;
CheckSnow := Config^.GetSnowCheck;
User.Init;
User.SetUserBbsType(BbsType);
User.SetUserLineNum(NodeNumber);
User.PostStatus(uoWait);
{The caller is this process's standard input/output: a socket from inetd,
 the pty of telnetd / sshd, or the sysop's own terminal.}
ComSession := CreateSession(SessType, SessRate, SessAddr, SessProxy);
If ComSession = Nil Then
  Begin
  WriteLn(StdErr, SessionError);
  Halt(1);
  End;
{The sysop monitor (mkmon) may watch this node: mklisten says where the
 sockets live (environment MKRUN).}
RunDir := GetEnv('MKRUN');
If (RunDir <> '') And (NodeNumber > 0) Then
  ComSession := New(SnoopComPtr, Init(ComSession, True,
    RunDir + '/node' + Long2Str(NodeNumber) + '.snoop'));
CurrentPort := 1;
If UserBaud = 0 Then
  UserBaud := 38400;                    {nominal speed of a network session}
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
If Not LocalMode Then
  AnsiSoundOn := False;                 {the caller's terminal plays the music}
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
  LogEntry.WriteEntry('Session = ' + GetCommInfo);
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
Dispose(ComSession, Done);
ComSession := Nil;
Halt(ExitLevel);
End.
