Program MK;

{$I MKB.Def}
{$X+}

Uses
  MKScrn, MKVCrt, MKSess,
MKGlobT, MKMenus, MKCmd, MKDoor, MKString, MKLogEnt, MKComAbs,
MKSys, MKCodes, MKFile, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB,
MKLogOn, MKAvatar, MKSnoop, MKQwkNet, MKQwkLog, MKOfflin, MKPwd, Dos
  ;




Function SysopCommand(Cmd: Char; Arg: LongInt): String;
  {The sysop watching this node (mkmon) asks for something}
  Var
    Adj, Left: LongInt;

  Begin
  SysopCommand := '';
  Case Cmd Of
    'K': Begin
         LogEntry.WriteEntry('Sysop disconnected the caller');
         SysopCommand := 'Node ' + Long2Str(NodeNumber) + ' disconnected';
         End;
    'C': Begin
         SysopChatWanted := True;
         LogEntry.WriteEntry('Sysop asked for a chat');
         SysopCommand := 'Chat requested: it starts when the BBS is ready';
         End;
    '+': Begin
         User.AdjustTime(Arg * 60);
         LogEntry.WriteEntry('Sysop added ' + Long2Str(Arg) + ' minutes');
         SysopCommand := 'Added ' + Long2Str(Arg) + ' min, ' +
           Long2Str(User.TimeRemain Div 60) + ' min left';
         End;
    '-': Begin
         Left := User.TimeRemain;
         Adj := Arg * 60;
         If Adj > Left - 60 Then
           Adj := Left - 60;               {at least a minute stays: kick to end}
         If Adj <= 0 Then
           SysopCommand := 'Only ' + Long2Str(Left Div 60) + ' min left, not reduced'
         Else
           Begin
           User.AdjustTime(-Adj);
           LogEntry.WriteEntry('Sysop took ' + Long2Str(Adj Div 60) + ' minutes');
           SysopCommand := 'Took ' + Long2Str(Adj Div 60) + ' min, ' +
             Long2Str(User.TimeRemain Div 60) + ' min left';
           End;
         End;
    End;
  End;


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
  NetId: String;
  QwkMode: Boolean;

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
NetId := '';
QwkMode := False;
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
      'G': NetId := Copy(ParamStr(i), 3, 40);   {a pass with a QWK network system (MKQwkNet): no caller}
      'H': SessProxy := True;      {PROXY header first on the connection}
      'Q': QwkMode := True;          {the login of a QWK network system / script: MKQwkLog}
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
      'U': Begin                       {character set of the caller's text}
           If (Copy(TmpStr,3,10) = 'UTF8') Or (Copy(TmpStr,3,10) = 'UTF-8') Then
             CharsetMode := 2
           Else If Copy(TmpStr,3,10) = 'CP437' Then
             CharsetMode := 1
           Else
             CharsetMode := 0;         {AUTO: by the terminal type}
           End;
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
  1: Config := NewMKConfig(True);
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
If BbsType = 1 Then
  If ExtUsersFormat(Config^.FindBbsFile('extusers.bbs') + 'extusers.bbs') <> 0 Then
    Begin
    WriteLn(StdErr, 'extusers.bbs has the record of the older version: run  mkpwconv -x  once (it keeps the old file as extusers.bbs.old)');
    Halt(43);
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
  Begin
  SnoopHandler := SysopCommand;
  ComSession := New(SnoopComPtr, Init(ComSession, True,
    RunDir + '/node' + Long2Str(NodeNumber) + '.snoop'));
  End;
CurrentPort := 1;
If UserBaud = 0 Then
  UserBaud := 38400;                    {nominal speed of a network session}
LogEntry.Init;
If IoResult <> 0 Then;
If LogToPrinter Then
  LogEntry.SetPrnName(Config^.GetPrnName);
ClrScr;
Prompts.Init;
Prompts.Load(Config^.FindBbsFile(Config^.GetLangFile(1) + '.lc') +
  Config^.GetLangFile(1) + '.lc');
CommaChar := Prompts.GetChar(320);
SysStats.Load;
If NetId <> '' Then
  Begin
  {mk -G<id>: the mail of a QWK network system is exchanged, nobody is on line}
  LocalMode := True;
  CurrentPort := 0;
  User.SetSessionTimeLimit(3600);
  User.SetStartTime;
  User.SetIdleTimeLimit(3600);
  LogEntry.WriteEntry('QWK network pass with ' + NetId);
  ExitLevel := QwkNetPass(NetId);
  LogEntry.WriteEntry('QWK network pass ended: ' + Long2Str(ExitLevel));
  User.PostStatus(uoNotAvail);
  User.Done;
  LogEntry.Done;
  Config^.Done;
  Dispose(ComSession, Done);
  ComSession := Nil;
  Halt(ExitLevel);
  End;
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
  If QwkMode Then
    User.SetUserAnsi(False)
  Else
    Begin
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(344));
    User.DetectAnsi;
    User.DisplayStr(#13 + PadRight('',' ', Length(Prompts.GetString(344)) + 10) + #13);
    User.SetUserAnsi(User.WasAnsiDetected);
    User.ClearScreen;                     {a clean screen for the version and copyright lines}
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(BbsVersion);
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStrLn(Copyright);
    User.DisplayNewLine;
    DoLanguage;
    BbsDisplay.DisplayBbsFile('logo', '');
    StartUpUser;
    AskName;
    End;
  End;
If QwkMode Then
  QwkSession
Else
  Begin
  User.GetUserSec(Sec);
  User.ClearScreen;
  User.DisplayNewLine;
  User.ClearScreen;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.SetMore(True);
  If IoResult <> 0 Then;
  Menu.Init;
  Menu.SetSecurity(Sec);
  Menu.Load('top');
  Menu.GlobalLoad('GLOBAL');
  If Menu.GetError <> 0 Then
    Begin
    User.DisplayStrLn('Unable to load top menu ' + Long2Str(Menu.GetError));
    Halt(1);
    End;
  MenuState := 1;
  Process;
  End;
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
If Not QwkMode Then
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
CommRelease;
Dispose(ComSession, Done);
ComSession := Nil;
Halt(ExitLevel);
End.
