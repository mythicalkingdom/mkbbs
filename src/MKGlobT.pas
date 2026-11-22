Unit MKGlobT;

{$I MKB.Def}

Interface

{
     MKGlobT - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Uses
  Dos;

Type AddrType = Record                 {Used for Fido style addresses}
  Zone: Word;
  Net: Word;
  Node: Word;
  Point: Word;
  End;

Type SecType = Record
  Level: Word;                         {Security level}
  Flags: LongInt;                      {32 bitmapped flags}
  End;

Type MKDateType = Record
  Year: Word;
  Month: Word;
  Day: Word;
  End;

Type MKDateTime = Record
  Year: Word;
  Month: Word;
  Day: Word;
  Hour: Word;
  Min: Word;
  Sec: Word;
  End;

Const
  BbsVersion = 'Mythical Kingdom Bbs - Version 0.01 Alpha';
  Copyright  = 'Copyright 1992, 1993 by Mark May';
  Contact    = 'Contact 1:110/290  (513)237-7737 v34/vFC/v32';


Const
  uoNotAvail = 0;
  uoBrowse =  1;
  uoXfer   =  2;
  uoMsg    =  3;
  uoDoor   =  4;
  uoChat   =  5;
  uoQuest  =  6;
  uoReady  =  7;
  uoMail   =  8;
  uoWait   =  9;
  uoLogIn  = 10;

{ The binkp mailer (mkbink) settings: file Mailer.Mk, one record.  The mailer's own address, name, sysop and
  location come from Config.Mk, its inbound / BSO outbound directories from EchoCfg.Mk (EchoMail Options).
  Expansion is room for fields added later (the record keeps its size); the Req fields are for file requests. }

Const
  MaxMailLinks = 64;
  MailerCfgVersion = 1;

  mcEnabled       = 1;                 {the mailer runs (mklisten starts it)}
  mcListen        = 2;                 {accept calls}
  mcRequireCram   = 4;                 {refuse cleartext passwords}
  mcPlz           = 8;                 {offer PLZ compression}
  mcNr            = 16;                {ask for non-reliable mode}
  mcAcceptUnknown = 32;                {let a system without a link call, with UnknownPwd}
  mcFileReq       = 64;                {answer file requests (mkfreq; mkbink's on-freq)}
  rqUnsecure      = 1;                 {ReqAttr: answer file requests also from callers without a password}
  rqAnswerMail    = 2;                 {ReqAttr: a netmail tells the requester what was found and what was not}
  mcNoMultiBatch  = 256;               {do not offer multiple batches (OPT MB): the default, bit clear, is to offer it}
  mcTosser        = 128;               {the tosser (mktoss) runs: after mail arrives (on-inbound) and from mklisten's scan}

  mlAnswerOnly = 1;                    {never call this link, only answer its calls}
  mlDisabled   = 2;                    {kept in the list but not used}
  mlPlzOn      = 4;                    {PLZ for this link whatever the global setting}
  mlPlzOff     = 8;
  mlNrOn       = 16;                   {NR for this link}
  mlNrOff      = 32;

Type MailLinkType = Record
  Addr: AddrType;                      {address of the link, Zone 0 = unused entry}
  Name: String[30];                    {for the displays}
  Host: String[60];                    {host name or address to call, blank = cannot be called}
  Port: Word;                          {0 = the binkp port, 24554}
  Password: String[30];                {session password, blank = none}
  Flags: Word;                         {ml constants}
  PollMin: Word;                       {call every N minutes, 0 = only when mail is waiting}
  UseAka: Byte;                        {which of our addresses (1..10) is presented first, 0 = the main one}
  ReqSec: SecType;                     {reserved: file request access of this link, Level 0 = the global one}
  ReqAttr: Word;                       {reserved}
  Expansion: Array[1..32] of Byte;
  End;

{Netmail routing: the first route whose patterns fit the address of a netmail decides which echo system gets it.}
Const
  MaxRoutes = 12;
  rfDefault = 0;                       {Route.Flav: the flavour of the message / of the system}
  rfImmediate = 1;
  rfCrash = 2;
  rfNormal = 3;
  rfHold = 4;
  rfDirect = 5;

Type RouteType = Record
  Pat: String[40];                     {address patterns, blank separated: 1:110/* 2:*/* !1:110/5 ; ! = not; * = anything}
  Via: Byte;                           {the echo system (1..32) that gets the mail, 0 = this entry is not used}
  Flav: Byte;                          {rf constants}
  End;

Type MailerCfgType = Record
  Version: Word;                       {MailerCfgVersion}
  Flags: Word;                         {mc constants}
  Port: Word;                          {listen port}
  Bind: String[40];                    {listen address, blank = all}
  MaxSessions: Byte;                   {callers served at once}
  MaxPolls: Byte;                      {calls made at once}
  Timeout: Word;                       {seconds without activity}
  RetryMin: Word;                      {seconds before the first retry of a failed call}
  RetryMax: Word;                      {... doubled each time, up to this}
  ScanInterval: Word;                  {seconds between looks at the outbound}
  Domain: String[20];                  {network domain for addresses, e.g. fidonet}
  UnknownPwd: String[30];              {password for systems without a link (mcAcceptUnknown)}
  ReqSec: SecType;                     {reserved: file request security (level and flags): the access of a system that has none of its own}
  ReqMagicFile: String[60];            {reserved: file with the magic names and their passwords}
  ReqMaxFiles: Word;                   {reserved}
  ReqMaxKb: LongInt;                   {reserved}
  ReqAttr: Word;                       {reserved}
  Links: Array[1..MaxMailLinks] of MailLinkType;
  {taken from the expansion room, so the record and the offsets above are unchanged}
  UnsecureIn: String[60];              {inbound directory for callers without a password, blank = the same as the inbound}
  OnInbound: String[100];              {command run after a session that received files (a tosser), blank = none}
  HookTimeout: Word;                   {seconds before that command is killed, 0 = 300}
  PktPwd: Array[1..32] of String[8];   {packet password of each echo system (EchoCfg.EchoSys), blank = none}
  Routes: Array[1..MaxRoutes] of RouteType; {netmail routing, in order}
  Expansion: Array[1..56] of Byte;     {room for new settings}
  End;

{What an event does and how it is handled when it is missed.  The times, days and status are in Config.Mk (EventType in
 Struct.MK); these are in Events.Mk, one record for each event with the same number.  See EVENTS-PLAN.md.}
Const
  EventsCfgVersion = 1;
  MaxEventExt = 30;
  eaNone = 0;                          {EventExtType.Action: nothing (the errorlevel script, if the errorlevel is set)}
  eaCommand = 1;                       {run the command line in Cmd}
  eaHubPass = 3;                       {a QWK hub pass: Cmd names the hub (later)}
  eaMailPoll = 4;                      {mailer: POLL Cmd (an address or *)}
  eaMailHold = 5;                      {mailer: HOLD Cmd}
  eaMailFree = 6;                      {mailer: FREE Cmd}
  efExclusive = 1;                     {EventExtType.Flags: nothing else runs, and no one logs on, while it runs}
  efLogOutput = 2;                     {the output of the command goes into the log}
  elSkip = 0;                          {EventExtType.Late: a missed occurrence is dropped}
  elWithin = 1;                        {... run once if it was at most LateMin minutes ago}
  elRun = 2;                           {... run once, however late}
  elPerMiss = 3;                       {... run once for each missed occurrence, at most LateMax}

Type EventExtType = Record
  Action: Byte;                        {ea constants}
  Flags: Word;                         {ef constants}
  Late: Byte;                          {el constants}
  LateMin: Word;                       {minutes of grace for elWithin}
  LateMax: Byte;                       {most runs for elPerMiss}
  Cmd: String[100];                    {command line, or the address / hub for the other actions}
  TimeoutMin: Word;                    {killed after this many minutes, 0 = 60}
  Reserved: Array[1..40] of Byte;
  End;

{File echoes (TIC): FileEcho.Mk.  See TIC-PLAN.md.  The systems are the echo systems of EchoCfg.Mk (the same numbers 1..32).}
Const
  FileEchoCfgVersion = 1;
  MaxFileEchoes = 300;
  feReplaces = 1;                      {FileEchoAreaType.Attr: the TIC may name files it replaces}
  feNoCheck = 2;                       {the check command is not run for this echo}
  feKeepPath = 4;                      {keep the Path / Seenby lines of the TIC when it is passed on (otherwise the Seenby lines are cut to the systems that get it)}

Type FileEchoSysType = Record
  TicPwd: String[8];                   {the password in the TIC of this system (blank = none)}
  FixPwd: String[15];                  {the FileFix password (blank = the Areafix password of the system)}
  Groups: LongInt;                     {the groups (bit 0 = A ... bit 25 = Z) of the echoes it may list and link to}
  Expansion: Array[1..12] of Byte;
  End;

Type FileEchoAreaType = Record
  Tag: String[40];                     {the name of the file echo: blank = unused}
  Desc: String[40];                    {what it is (the Areadesc line of the TIC)}
  FileArea: Word;                      {the file area (files.mk) the files go to, 0 = pass-through: no copy is kept}
  EchoTo: LongInt;                     {the systems that get the files (bit 0 = system 1 ...)}
  Hub: Byte;                           {the system the echo comes from (0 = none)}
  Groups: LongInt;                     {groups the echo belongs to (A..Z as above); 0 = any system may link to it}
  Attr: Word;                          {fe constants}
  Expansion: Array[1..10] of Byte;
  End;

Type FileEchoCfgType = Record
  Version: Word;                       {FileEchoCfgVersion}
  CheckCmd: String[100];               {a command run for each file before it is accepted (%F = the file, %T = the TIC); not 0 = refused; blank = none}
  CheckTimeout: Word;                  {seconds before the check is stopped (counts as refused); 0 = 60}
  SpoolPath: String[60];               {where the files of pass-through echoes wait (blank = <outbound>/mktoss/tic)}
  PassDays: Word;                      {days a pass-through file waits for a system that has not fetched it, 0 = 14}
  PassMaxMB: Word;                     {the most the pass-through spool may hold in MB, 0 = no limit}
  Flags: Word;
  Expansion: Array[1..40] of Byte;
  Sys: Array[1..32] of FileEchoSysType;
  Area: Array[1..MaxFileEchoes] of FileEchoAreaType;
  End;

Procedure FileEchoDefaults(Var F: FileEchoCfgType);

Type EventsCfgType = Record
  Version: Word;                       {EventsCfgVersion}
  Ev: Array[1..MaxEventExt] of EventExtType;
  End;

Procedure EventsDefaults(Var E: EventsCfgType);

Procedure MailerDefaults(Var M: MailerCfgType);

Function  AddrStr(Addr: AddrType): String;
Function  PointlessAddrStr(Var Addr: AddrType): String;
Function  ParseAddr(AStr: String; CurrAddr: AddrType; Var DestAddr: AddrType): Boolean;
Function  IsValidAddr(Addr: AddrType): Boolean;
Function  Access(USec: SecType; RSec: SecType): Boolean;
Function  EstimateXferTime(FS: LongInt; BaudRate: Word; Effic: Word): LongInt;
  {Result in seconds}
Function  NameCrcCode(Str: String): LongInt; {Get CRC code for name}
Function  Flag2Str(Number: Byte): String;
Function  Str2Flag(St: String): Byte;
Function  ValidMKDate(DT: MKDateTime): Boolean;
Procedure DT2MKDT(Var DT: DateTime; Var DT2: MKDateTime);
Procedure MKDT2DT(Var DT: MKDateTime; Var DT2: DateTime);
Procedure Str2MKD(St: String; Var MKD: MKDateType);
Function MKD2Str(MKD: MKDateType): String;
Function GetCompiled: String;
Function AddrEqual(Addr1: AddrType; Addr2: AddrType):Boolean;
Procedure SetTimeToEvent(Minutes: LongInt);
  {mk -T: remembers the minutes and when mk was started}
Function SecsToEvent: LongInt;
  {Seconds left until that event, -1 when mk was not told of one (it can be 0 or less when it is due)}

Var
  StartUpPath: String[128];

Const
  UseEms: Boolean = True;
  LocalMode: Boolean = False;
  LogToPrinter: Boolean = False;
  ReLoad: Boolean = False;
  NodeNumber: Byte = 1;
  OverRidePort: Byte = 0;
  OverRideBaud: Word = 0;
  UserBaud: Word = 0;
  ExitErrorLevel: Byte = 0;
  TimeToEvent: LongInt = 0;            {mk -T<min>: minutes from the start of mk to the next event that needs the BBS quiet (an exclusive one)}
  TimeToEventAt: Int64 = 0;
  ShellToMailer: Boolean = False;

Implementation

Uses MKString, Crc32, MKMisc, MKPlat;


Procedure SetTimeToEvent(Minutes: LongInt);
  Begin
  TimeToEvent := Minutes;
  TimeToEventAt := MKTicks;
  End;


Function SecsToEvent: LongInt;
  Begin
  If TimeToEvent <= 0 Then
    SecsToEvent := -1
  Else
    SecsToEvent := TimeToEvent * 60 - LongInt((MKTicks - TimeToEventAt) Div 1000);
  End;


Procedure EventsDefaults(Var E: EventsCfgType);
  Var
    i: Word;

  Begin
  FillChar(E, SizeOf(E), 0);
  E.Version := EventsCfgVersion;
  For i := 1 To MaxEventExt Do
    Begin
    E.Ev[i].Late := elWithin;
    E.Ev[i].LateMin := 10;
    E.Ev[i].LateMax := 5;
    End;
  End;


Procedure FileEchoDefaults(Var F: FileEchoCfgType);
  Begin
  FillChar(F, SizeOf(F), 0);
  F.Version := FileEchoCfgVersion;
  F.CheckTimeout := 60;
  F.PassDays := 14;
  End;


Procedure MailerDefaults(Var M: MailerCfgType);
  Begin
  FillChar(M, SizeOf(M), 0);
  M.Version := MailerCfgVersion;
  M.Flags := mcListen;
  M.Port := 24554;
  M.MaxSessions := 8;
  M.MaxPolls := 1;
  M.Timeout := 120;
  M.RetryMin := 60;
  M.RetryMax := 3600;
  M.ScanInterval := 30;
  End;


{$I Compiled.Inc}

Function Flag2Str(Number: Byte): String;
  Var
    Temp1: Byte;
    Temp2: Byte;
    i: Word;
    TempStr: String[8];

  Begin
  Temp1 := 0;
  Temp2 := $01;
  For i := 1 to 8 Do
    Begin
    If (Number and Temp2) <> 0 Then
      TempStr[i] := 'X'
    Else
      TempStr[i] := '-';
    Temp2 := Temp2 shl 1;
    End;
  TempStr[0] := #8;
  Flag2Str := TempStr;
  End;


Function Str2Flag(St: String): Byte;
  Var
    i: Word;
    Temp1: Byte;
    Temp2: Byte;

  Begin
  St := StripBoth(St,' ');
  St := PadLeft(St,'-',8);
  Temp1 := 0;
  Temp2 := $01;
  For i := 1 to 8 Do
    Begin
    If UpCase(St[i]) = 'X' Then
      Inc(Temp1,Temp2);
    Temp2 := Temp2 shl 1;
    End;
  Str2Flag := Temp1;
  End;




Function AddrStr(Addr: AddrType): String;
  Begin
  If Addr.Point = 0 Then
    AddrStr := Long2Str(Addr.Zone) + ':' + Long2Str(Addr.Net) + '/' +
      Long2Str(Addr.Node)
  Else
    AddrStr := Long2Str(Addr.Zone) + ':' + Long2Str(Addr.Net) + '/' +
      Long2Str(Addr.Node) + '.' + Long2Str(Addr.Point);
  End;


Function PointlessAddrStr(Var Addr: AddrType): String;
  Begin
  PointlessAddrStr := Long2Str(Addr.Zone) + ':' + Long2Str(Addr.Net) + '/' +
      Long2Str(Addr.Node);
  End;


Function Access(USec: SecType; RSec: SecType): Boolean;
  Begin
  If (USec.Level >=  RSec.Level) Then
    Access :=  ((RSec.Flags and Not(USec.Flags)) = 0)
  Else
    Access := False;
  End;


Function EstimateXferTime(FS: LongInt; BaudRate: Word; Effic: Word): LongInt;
  Begin
  If BaudRate > 0 Then
    EstimateXferTime := ((FS * 100) Div Effic) Div (BaudRate Div 10)
  Else
    EstimateXferTime := ((FS * 100) Div Effic) Div (960);
  End;


Function NameCrcCode(Str: String): LongInt;
  Var
    NCode: LongInt;
    i: WOrd;

  Begin
  NCode := UpdC32(Length(Str),-1);
  i := 1;
  While i < Length(Str) Do
    Begin
    NCode := Updc32(Ord(UpCase(Str[i])), NCode);
    Inc(i);
    End;
  NameCrcCode := NCode;
  End;


Function ParseAddr(AStr: String; CurrAddr: AddrType; Var DestAddr: AddrType): Boolean;
  Var
    SPos: Word;
    EPos: Word;
    TempStr: String;
    Code: Word;
    BadAddr: Boolean;

  Begin
  BadAddr := False;
  AStr := StripBoth(Upper(AStr), ' ');
  EPos := Length(AStr);
  {thanks for the fix domain problem to Ryan Murray @ 1:153/942}
  Code := Pos('@', AStr);
  If Code > 0 then
    Delete(Astr, Code, Length(Astr) + 1 - Code);
  SPos := Pos(':',AStr) + 1;
  If SPos > 1 Then
    Begin
    TempStr := StripBoth(Copy(AStr,1,Spos - 2), ' ');
    Val(TempStr,DestAddr.Zone,Code);
    If Code <> 0 Then
      BadAddr := True;
    AStr := Copy(AStr,Spos,Length(AStr));
    End
  Else
    DestAddr.Zone := CurrAddr.Zone;
  SPos := Pos('/',AStr) + 1;
  If SPos > 1 Then
    Begin
    TempStr := StripBoth(Copy(AStr,1,Spos - 2), ' ');
    Val(TempStr,DestAddr.Net,Code);
    If Code <> 0 Then
      BadAddr := True;
    AStr := Copy(AStr,Spos,Length(AStr));
    End
  Else
    DestAddr.Net := CurrAddr.Net;
  EPos := Pos('.', AStr) + 1;
  If EPos > 1 Then
    Begin
    TempStr := StripBoth(Copy(AStr,EPos,Length(AStr)), ' ');
    Val(TempStr,DestAddr.Point,Code);
    If Code <> 0 Then
      DestAddr.Point := 0;
    AStr := Copy(AStr,1,EPos -2);
    End
  Else
    DestAddr.Point := 0;
  TempStr := StripBoth(AStr,' ');
  If Length(TempStr) > 0 Then
    Begin
    Val(TempStr,DestAddr.Node,Code);
    If Code <> 0 Then
      BadAddr := True;
    End
  Else
    DestAddr.Node := CurrAddr.Node;
  ParseAddr := Not BadAddr;
  End;


Procedure DT2MKDT(Var DT: DateTime; Var DT2: MKDateTime);

  Begin
  DT2.Year := DT.Year;
  DT2.Month := DT.Month;
  DT2.Day := DT.Day;
  DT2.Hour := DT.Hour;
  DT2.Min := DT.Min;
  DT2.Sec := DT.Sec;
  End;


Procedure MKDT2DT(Var DT: MKDateTime; Var DT2: DateTime);

  Begin
  DT2.Year := DT.Year;
  DT2.Month := DT.Month;
  DT2.Day := DT.Day;
  DT2.Hour := DT.Hour;
  DT2.Min := DT.Min;
  DT2.Sec := DT.Sec;
  End;


Function  ValidMKDate(DT: MKDateTime): Boolean;
  Var
    DT2: DateTime;

  Begin
  MKDT2DT(DT, DT2);
  ValidMKDate := ValidDate(DT2);
  End;


Procedure Str2MKD(St: String; Var MKD: MKDateType);
  Begin
  FillChar(MKD, SizeOf(MKD), #0);
  MKD.Year := Str2Long(Copy(St, 7, 2));
  MKD.Month := Str2Long(Copy(St, 1, 2));
  MKD.Day := Str2Long(Copy(St, 4, 2));
  If MKD.Year < 80 Then
    Inc(MKD.Year, 2000)
  Else
    Inc(MKD.Year, 1900);
  End;


Function MKD2Str(MKD: MKDateType): String;
  Begin
  MKD2Str := PadLeft(Long2Str(MKD.Month),'0',2) + '-' +
             PadLeft(Long2Str(MKD.Day), '0',2) + '-' +
             PadLeft(Long2Str(MKD.Year Mod 100), '0', 2);
  End;


Function GetCompiled: String;
  Begin
  GetCompiled := Compiled;
  End;


Function AddrEqual(Addr1: AddrType; Addr2: AddrType):Boolean;
  Begin
  AddrEqual := ((Addr1.Zone = Addr2.Zone) and (Addr1.Net = Addr2.Net)
    and (Addr1.Node = Addr2.Node) and (Addr1.Point = Addr2.Point));
  End;



Function  IsValidAddr(Addr: AddrType): Boolean;
  Begin
  IsValidAddr := ((Addr.Zone = 0) And (Addr.Net = 0));
    { We have to skip administrative '/0' addresses}
  End;


End.
