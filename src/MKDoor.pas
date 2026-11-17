Unit MKDoor;

{$I MKB.Def}

{$i-}

{$X+}

Interface

Uses MKGlobT, MKStr, MKSnoop, MKPty, MKRCfgMK, MKRCfgRA, MKCfgSB, MKCfgQB, MKMsgHud,
  Dos;


Const
  ShellEnvVar = {$IFDEF UNIX}'SHELL'{$ELSE}'COMSPEC'{$ENDIF};  {names the program for Alt-J}

Var
  DoorRemote: Boolean;                 {Drop file says the caller is remote}


Type UserInfoType = Record
  Ok: Boolean;
  NotOkReason: Word;
  Tagging: Boolean;
  StartDay: Word;
  StartTime: LongInt;
  TimeLimit: Word;
  CurrLines: Word;
  SessScrnLen: Word;                    {Screen length from the caller's terminal, 0 = none}
  SessWinVer: Word;                     {Window report it came from}
  StopMore: Boolean;
  DoMore: Boolean;
  TwoMinWarn: Boolean;
  OneMinWarn: Boolean;
  TimeOverWarn: Boolean;
  Chat: Boolean;
  ChatStart: LongInt;
  ChatReason: String[50];
  IdleLimit: LongInt;
  IdleWarn: Boolean;
  IdleTime: Word;
  ExitInfo: ExitInfoType;
  Extra: Array[1..4000] of Byte;
  ExitSize: Word;
  BatchMode: Boolean;
  BbsType: Byte;
  TemplateMsg: Word;
  TemplateFile: Word;
  TemplateDoor: Word;
  LastLoaded: Array[1..4] of Boolean;
  LastModified: Array[1..4] of Boolean;
  LineNum: Word;
  UserLoaded: Boolean;
  MsgsToday: Word;
  DLToday: Word;
  ULToday: Word;
  LastStatus: Word;
  AnsiDet: Boolean;
  End;


Type DoorUser = Object
  UserInfo: ^UserInfoType;
  Procedure Init;                        {Initialize}
  Procedure Done;                        {Done}
  Procedure ClrEOL;                      {Clear to eol if ansi on}
  Procedure ClearScreen;                 {Clear screen if ansi on}
  Function  UserFound: Boolean;          {Returns user found?}
  Procedure SetMore(More: Boolean);      {This session ask more?}
  Function  GetMore: Boolean;            {Will more prompts be done?}
  Function  StopMore: Boolean;           {More? answer of NO}
  Procedure SetStopMore(St: Boolean);    {Set more? answer}
  Procedure ResetLines(Ct: Word);        {Reset more line count}
  Function  CurrentTime: LongInt;        {Seconds since midnight of log-on day}
  Function  GetCurrentDay: Word;         {Get Day of Month}
  Procedure SetIdleTimeLimit(ITL: Word); {Set idle timer limit in seconds}
  Procedure SetTimeOut;                  {Set Idle timer for IdleTime seconds
                                          from now}
  Function  TimeRemain: LongInt;         {Seconds remaining}
  Procedure TimeWarn;                    {Check time remaining and give
                                          warning if needed}
  Function  OkTime: Boolean;             {False if Time Limit exceeded}
  Function  OK: Boolean;                 {After CheckInput is all ok?}
  Function  GetNotOkReason: Word;        {Get reason ok is false}
  Procedure SetOk(St: Boolean); {Set ok to false}
  Function  GetChatReason: String;       {Get chat reason}
  Procedure SetChatReason(Reason: String); {Set chat reason}
  Procedure CheckInput;                  {Check time remain, carrier, etc}
  Procedure CheckIdle;                   {Check for idle timeout}
  Function  CheckHot(HotStr: String): Char; {Check for hot key - #0 = none}
  Procedure DisplayChr (OutChr:Char);    {Display character remote & local}
  Procedure DisplayStr (OutStr:String);  {Display string remote & local}
  Procedure DisplayStrLn (OutStr:String);{Display string with new line}
  Procedure DisplayCenterStrLn(OutStr: String);  {Display string centered}
  Procedure DisplayNewLine;              {Display CR/LF}
  Procedure DisplayColor (Fr:Byte;Br:Byte); {Set ansi fore/back colors}
  Function  GetAttrStr(Attr:Byte): String; {Get attribute setting string}
  Procedure DisplayAttr (Attr:Byte);     {Set ansi color attribute}
  Procedure DisplayBkSpc;                {Display backspace}
  Procedure TimeOver;                    {Tell user time is over}
  Procedure CheckMore;                   {Inc line count and check for more}
  Procedure DetectWindow;                {Take the caller's terminal size (if reported)}
  Procedure AnsiChat;                    {Internal use}
  Procedure AvatarChat;                  {Internal use}
  Procedure DoChat;                      {Start chat}
  Procedure WaitEnter;                   {Wait for enter to be pressed}
  Procedure PressEnter;                  {Ask user to Press Enter}
  Function  InputChr(Var Ch:Char): Boolean; {True if char read and returned
                                          in CH}
  Procedure DisplayFile(FileName: String);
  Function  DisplayHotFile(FileName: String; HotStr: String):Char;
  Procedure AskMore;
  Function  AskDate(Var DT: DateTime): Boolean; {Ask user date}
  Function  AskFormatted(FMStr: String): String;
    {Ask string using FMStr for formatting 9=num a=alpha x=anything}
  Function  AskPhone: String;
    {Ask for phone number using language format string}
  Function  AskChoice(ChStr: String): Char;  {Get char limited to ChStr}
  Procedure AskYN(Quest: String; Var Option: Boolean); {Ask Y/N Question}
  Function  AskNumber(Num: LongInt; Min: LongInt; Max: LongInt): LongInt;
  Function  DefaultNumStr(Num: LongInt): String; {returns (enter = xx)}
  Function  InputStr (InStr:String; MaxLen:Byte): String;
  Function  InputProper(MaxLen: Byte): String;
  Procedure WWInputStr (Var Str:String; Var Extra: String; MaxLen:Byte;
    Ansi: Boolean; HiBit: Boolean);
    {Input a word wrapped string, excess in extra}
  Function  InputPwd (MaxLen:Byte): String;  {Input password}
  Procedure DetectAnsi; {Detect ansi}
  Function  WasAnsiDetected: Boolean;
  Procedure ReadUser; {Read user based on UserRecNum in ExitInfo}
  Procedure WriteUser;
  Procedure AddUser;
  Procedure AdjustTime(Adj: LongInt);
  Procedure GetUserPos(Name: String);
  Procedure ReadExit(EPath: String);   {Read ExitInfo from given path}
  Procedure WriteExit(EPath: String);  {Write ExitInfo to given path}
  Procedure ReadDorInfo(DPath: String); {Read DorInfo1.Def from given path}
  Function  GetUserLineNum: Word;      {Get caller line number}
  Procedure SetUserLineNum(Ln: Word);  {Set caller line number}
  Function  GetUserSecondsOn: Word;    {Get seconds user has beeen connected}
  Procedure GetUserSec(Var Sec: SecType); {Get user security level/flags}
  Procedure SetUserSec(Sec: SecType);  {Set user security level/flags}
  Function  GetUserName: String;       {Get users name}
  Procedure SetUserName(NStr: String); {Set users name}
  Function  GetUserCity: String;       {Get users city}
  Procedure SetUserCity(CStr: String); {Set users city}
  Function  GetUserPwd: String;        {Get users password}
  Procedure SetUserPwd(PwdStr: String); {Set users password}
  Function  GetUserDataPhone: String;  {Get users data phone}
  Procedure SetUserDataPhone(Phone: String); {Set users data phone}
  Function  GetUserVoicePhone: String; {Get users voice phone}
  Procedure SetUserVoicePhone(Voice: String); {Set users voice phone}
  Function  GetUserCredit: Integer;    {Get users netmail credit}
  Procedure SetUserCredit(Credit: Integer); {Set users netmail credit}
  Function  GetUserPending: Integer;   {Get users pending netmail cost}
  Procedure SetUserPending(Pending: Integer); {Set users pending cost}
  Function  GetUserScrLength: Word;    {Get users screen length}
  Procedure SetUserScrLength(Scr: Word); {Set users screen length}
  Function  GetUserMsgsEntered: Word;  {Get number of msgs entered}
  Procedure SetUserMsgsEntered(MsgE: Word); {Set nbr of msgs entered}
  Function  GetUserTimesCalled: Word;  {Get number of times called}
  Procedure SetUserTimesCalled(Calls: Word); {Set nbr of times called}
  Function  GetUserCombRead: Word;     {Get combined last read}
  Procedure SetUserCombRead(Comb: Word); {Set combined last read}
  Function  GetUserTodayK: Integer;    {Get net "k" transfered today}
  Procedure SetUserTodayK (TK: Integer); {Set net "k" transfered today}
  Function  GetUserULK: Word;    {Get "k" uploaded}
  Procedure SetUserULK (TK: Word); {Set "k" uploaded}
  Function  GetUserDLK: Word;    {Get "k" downloaded}
  Procedure SetUserDLK (TK: Word); {Set "k" downloaded}
  Function  GetUserULFiles: Word;    {Get Num Files uploaded}
  Procedure SetUserULFiles (TK: Word); {Set Num Files uploaded}
  Function  GetUserDLFiles: Word;    {Get Num Files downloaded}
  Procedure SetUserDLFiles (TK: Word); {Set Num Files downloaded}
  Function  GetUserElapsed: Integer;    {Get Elapsed time prior calls today}
  Procedure SetUserElapsed (TK: Integer); {Set Elapsed time}
  Function  GetUserLastDate: String;   {Get user last called date}
  Procedure SetUserLastDate (LD: String); {Set last called date}
  Function  GetUserLastTime: String;   {Get user last called time}
  Procedure SetUserLastTime (LT: String); {Set last called time}
  Procedure GetUserNewFileDate(Var DT: DateTime); {Get user new file search date}
  Procedure SetUserNewFileDate(DT: DateTime); {Set user new file search date}
  Function  GetUserBbsType: Byte;      {Get Bbs type}
  Procedure SetUserBbsType(BT: Byte);  {Set Bbs type}
  Function  GetUserAvatar: Boolean;    {Get avatar setting}
  Procedure SetUserAvatar(AV: Boolean);{Set user avatar}
  Function  GetUserFullEd: Boolean;    {Get full-screen editor setting}
  Procedure SetUserFullEd(FE: Boolean);{Set full-screen editor setting}
  Function  GetUserMore: Boolean;      {Get ask more setting}
  Procedure SetUserMore(Mo: Boolean);  {Set ask more setting}
  Function  GetUserScrnClr: Boolean;   {Get screen clear setting}
  Procedure SetUserScrnClr(Cl: Boolean); {Set screen clear setting}
  Function  GetUserAnsi: Boolean;      {Get ansi setting}
  Procedure SetUserAnsi(UA: Boolean);  {Set user ansi}
  Function  GetUserLanguage: Byte;     {Get user lang number}
  Procedure SetUserLanguage(Ln: Byte); {Set user lang number}
  Function  GetUserBaud: Word;         {Get user baud rate}
  Procedure SetUserBaud(Bd: Word);     {Set user baud rate}
  Function  GetUserMsgTemplate: Word; {Get user msg template area}
  Procedure SetUserMsgTemplate(Tm: Word); {Set user msg template area}
  Function  GetUserFileTemplate: Word; {Get user file template area}
  Procedure SetUserFileTemplate(Tm: Word); {Set user file template area}
  Function  GetUserDoorTemplate: Word; {Get user door template area}
  Procedure SetUserDoorTemplate(Tm: Word); {Set user door template area}
  Function  GetUserPageTimes: Word;    {Get number of times has paged}
  Procedure SetUserPageTimes(Pg: Word);{Set number of times has paged}
  Function  GetUserTimeLimit: Integer; {Get user time limit}
  Procedure SetUserTimeLimit(TL: Word);{Set user time limit}
  Function  GetUserDLLimit: Word;      {Get user DL limit}
  Procedure SetUserDLLimit(DL: Word);  {Set user DL limit}
  Function  GetUserHandle: String;     {Get users handle}
  Procedure SetUserHandle(Hd: String); {Set users handle}
  Function  GetUserPageTune: Byte;     {Get user page tune}
  Procedure SetUserPageTune(Tune: Byte); {Set user page tune}
  Function  GetUserBirthDate: String; {Get user birthdate MM-DD-YY}
  Procedure SetUserBirthDate(BD: String); {Set user birthdate MM-DD-YY}
  Function  GetUserFirstDate: String; {Get user first call MM-DD-YY}
  Procedure SetUserFirstDate(BD: String); {Set user first call MM-DD-YY}
  Function  GetUserCombined(Area: Word): Boolean; {Get user combined setting}
  Procedure SetUserCombined(Area: Word; St: Boolean); {Set user combined}
  Function  GetUserOffline(Area: Word): Boolean; {Get user offline mail}
  Procedure SetUserOffline(Area: Word; St: Boolean); {Set user offline mail}
  Function  GetSystemCalls: LongInt;   {Get system number of calls}
  Procedure SetSystemCalls(CL: LongInt); {Set system number of calls}
  Function  GetSystemLastCaller: String; {Get system last caller name}
  Procedure SetSystemLastCaller(LC: String); {Set system last caller name}
  Function  GetNextEventStr: String;   {Get next event time string}
  Procedure ClearGoSub;                {Clear gosub menu stack}
  Procedure GoSub(MN: String);         {Add MenuName MN to gosub stack}
  Function  GoSubReturn: String;       {Return MenuName from gosub stack}
  Function  GetUserRecNum: Word;       {Get user record number}
  Function  GetSessionTimeLimit: LongInt; {Seconds this call allowed}
  Procedure SetSessionTimeLimit(TL: LongInt); {Seconds allowed this call}
  Procedure SetStartTime; {Set start time}
  Procedure SetSysInfo(Var SysInfo: SysInfoType); {Set SysInfo into ExitInfo}
  Procedure UpdateForMsg; {Increment msgs posted count}
  Procedure UpdateForDL(FSize: LongInt); {Increment DL count and update K}
  Procedure UpdateForUL(FSize: LongInt); {Increment UL count and update K}
  Function  UserIsLoaded: Boolean;
  Procedure PostStatus(Status: Byte);
  Function  GetUserNumber: Word;
  Function  GetUserProt: Char;  {Get user default protocol}
  Procedure SetUserProt(PT: Char); {Set user default protocol}
  Function  GetUserPacker: Char;  {Get user default packer}
  Procedure SetUserPacker(PT: Char); {Set user default packer}
  Function  GetUserOffType: Char; {Get user offline pkt type}
  Procedure SetUserOffType(OT: Char); {Set user offline pkt type}
  Function  GetUserOffMax: Word; {Get offline max msg per pkt}
  Procedure SetUserOffMax(OM: Word); {set offline max}
  Function  GetUserOffConfMax: Word; {Get offline max msgs per area}
  Procedure SetUserOffConfMax(OM: Word); {Set max msgs per area}
  Function  GetUserOffNew: Boolean; {Get user offline new files list}
  Procedure SetUserOffNew(OA: Boolean); {Set new files list setting}
  Function  GetUserOffScrn: Boolean; {Get user offline screens}
  Procedure SetUserOffScrn(OA: Boolean); {Set user wants screens}
  Function  GetUserOffBull: Boolean; {Get user wants bulletins}
  Procedure SetUserOffBull(OA: Boolean); {Set user wants bulletins}
  Function  GetUserOffVerify: Boolean; {Get user wants verify}
  Procedure SetUserOffVerify(OA: Boolean); {Set user wants verify}
  Function  GetUserOffFlag: Boolean; {Flag as read}
  Procedure SetUserOffFlag(OA: Boolean); {Flag as read}
  Function  GetUserOffOwn: Boolean; {Get own msgs}
  Procedure SetUserOffOwn(OA: Boolean); {Get own msgs}
  Function  GetUserOffAllYour: Boolean; {All areas for your mail}
  Procedure SetUserOffAllYour(OA: Boolean); {All areas for your mail}
  Function  GetUserOffZero: Boolean; {Wants zero msg pkts}
  Procedure SetUserOffZero(OA: Boolean); {Wants zero msg pkts}
  Function  GetUserOffGate: Boolean; {User is gating msgs to another network}
  Procedure SetUserOffGate(OA: Boolean); {User is gating msgs}
  Function  GetMsgNetwork(Net: Byte): Boolean;
  Procedure SetMsgNetwork(Net: Byte; MN: Boolean);
  Function  GetUserNetStatus: LongInt;
  Procedure SetUserNetStatus(NS: LongInt);
  End;

Var
  Prompts: StrObj;
  User:DoorUser;


Procedure DoShell(Cmd: String; DoSwap: Boolean; DoWindow: Boolean);
Function DoorPtyWanted: Boolean;       {a program is run on a pseudo terminal (a caller is connected, no *S, MK_NOPTY not set)}
Var
  DoorRaw: Boolean;                    {the next DoShell gives the program the caller's connection itself (TypeSeven *S), no terminal}
  ShellError: Word;                    {what DoShell could not do: 0 = it ran the program, 2 = no such program, else the DOS error}
  CharsetMode: Byte;                   {0 = by the terminal type, 1 = CP437 as it is, 2 = UTF-8 (mk -U, the menu command)}
  SysopChatWanted: Boolean;            {the sysop (mkmon) asked for a chat; DoChat starts at the next InputChr}

Function SysopWaiting: Boolean;        {the sysop asked for a chat, or typed a key for the chat / the page}
Function CallerUtf8: Boolean;          {text for the caller is sent as UTF-8 (CP437 translated)}

Implementation

Uses
    MKVCrt,
    MKScrn,
  MKString, MKFile, MKAvatar, MKComAbs, MKCfgAbs, MKMisc, MKDos, MKCp437;


Type
  RaExitInfoPtr = ^RaExitInfoRecord;

Function CallerUtf8: Boolean;
  Const
    LastTerm: String[40] = '#';
    LastUtf8: Boolean = False;
  Var
    T: String;

  Begin
  Case CharsetMode Of
    1: CallerUtf8 := False;
    2: CallerUtf8 := True;
    Else
      Begin
      If ComSession = Nil Then
        T := ''
      Else
        T := ComSession^.GetTermType;
      If T <> LastTerm Then
        Begin
        LastTerm := T;
        LastUtf8 := TermWantsUtf8(T);
        End;
      CallerUtf8 := LastUtf8;
      End;
    End;
  End;


Var
  BgInit: Boolean;                     {the black background was set for this caller}
  SgrState: Byte;                      {0 text, 1 after ESC, 2 inside ESC [ ...}
  SgrNum: Integer;                     {the number being read, -1 = none yet}
  SgrReset, SgrBg, SgrFg: Boolean;     {this sequence resets / sets a background / sets a foreground}


Procedure SendRaw(Const S: String);
  {Bytes of our own for the caller, all of them}
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    While (Not CommSendNw(S[i])) And User.OK Do
      User.CheckInput;
  End;


Procedure SgrNumber;
  Begin
  If SgrNum < 0 Then
    SgrNum := 0;                       {an empty parameter means 0}
  If SgrNum = 0 Then
    SgrReset := True;
  If ((SgrNum >= 40) And (SgrNum <= 48)) Or ((SgrNum >= 100) And (SgrNum <= 107)) Then
    SgrBg := True;
  If ((SgrNum >= 30) And (SgrNum <= 39)) Or ((SgrNum >= 90) And (SgrNum <= 97)) Then
    SgrFg := True;
  SgrNum := -1;
  End;


Procedure TrackSgr(Ch: Char);
  {Watch the text going out: after an ANSI colour reset that sets no foreground or background, add light gray / black.
   The art is drawn for a DOS screen and a themed terminal's default colours are not those.}
  Begin
  Case SgrState Of
    0: If Ch = #27 Then
         SgrState := 1;
    1: If Ch = '[' Then
         Begin
         SgrState := 2;
         SgrNum := -1;
         SgrReset := False;
         SgrBg := False;
         SgrFg := False;
         End
       Else
         SgrState := 0;
    Else
      If Ch In ['0'..'9'] Then
        Begin
        If SgrNum < 0 Then
          SgrNum := 0;
        If SgrNum < 1000 Then
          SgrNum := SgrNum * 10 + Ord(Ch) - 48;
        End
      Else If Ch = ';' Then
        SgrNumber
      Else If (Ch >= #64) And (Ch <= #126) Then
        Begin
        SgrState := 0;
        If Ch = 'm' Then
          Begin
          SgrNumber;
          If SgrReset And Not (SgrBg And SgrFg) Then
            Begin                      {the DOS defaults: light gray on black}
            If SgrFg Then
              SendRaw(#27'[40m')
            Else If SgrBg Then
              SendRaw(#27'[37m')
            Else
              SendRaw(#27'[37;40m');
            End;
          End;
        End
      Else If Not (Ch In [#32..#63]) Then
        SgrState := 0;
    End;
  End;


Function SendText(Ch: Char): Boolean;
  {One character of text for the caller: as it is, or as the UTF-8 of its CP437 meaning.  False =
   nothing was sent (the line is full), try again; a character of several bytes is sent whole.}
  Var
    S: String;
    i: Word;
    Sent: Boolean;

  Begin
  If Not CallerUtf8 Then
    Begin
    SendText := CommSendNw(Ch);
    Exit;
    End;
  If (Not BgInit) And (SgrState = 0) Then
    Begin
    BgInit := True;
    SendRaw(#27'[37;40m');
    End;
  If Ch < #128 Then
    Begin
    Sent := CommSendNw(Ch);
    If Sent Then
      TrackSgr(Ch);
    SendText := Sent;
    Exit;
    End;
  S := Cp437ToUtf8(Ord(Ch));
  If Not CommSendNw(S[1]) Then
    Begin
    SendText := False;
    Exit;
    End;
  For i := 2 To Length(S) Do
    While (Not CommSendNw(S[i])) And User.OK Do
      User.CheckInput;
  SendText := True;
  End;


Function RecvText: Char;
  {One character the caller typed (CommRecv is waiting): a UTF-8 caller's letters are turned back into CP437}
  Var
    First, B: Char;
    Need, i: Byte;
    U: LongInt;
    Got: Boolean;

  Begin
  First := CommRecv;
  RecvText := First;
  If (First < #$C0) Or (Not CallerUtf8) Then
    Exit;
  If First >= #$F0 Then
    Need := 3
  Else If First >= #$E0 Then
    Need := 2
  Else
    Need := 1;
  U := Ord(First) And ($3F Shr Need);
  Got := True;
  For i := 1 To Need Do
    Begin
    If CommInEmpty And (ComSession <> Nil) Then
      ComSession^.WaitForChar(100);
    If CommInEmpty Then
      Got := False
    Else
      Begin
      B := CommPeek;
      If (B < #$80) Or (B >= #$C0) Then
        Got := False
      Else
        Begin
        B := CommRecv;
        U := (U Shl 6) Or (Ord(B) And $3F);
        End;
      End;
    If Not Got Then
      Break;
    End;
  If Got And (U <= $FFFF) And (Utf8ToCp437(U) <> 0) Then
    RecvText := Chr(Utf8ToCp437(U))
  Else
    RecvText := '?';
  End;


Function SysopWaiting: Boolean;
  Begin
  SysopWaiting := SysopChatWanted Or SysopKeyPressed;
  End;


Function DoorUser.GetUserNumber: Word;
  Begin
  GetUserNumber := UserInfo^.ExitInfo.UserRecNum;
  End;


Procedure DoorUser.SetMore(More: Boolean);
  Begin
  UserInfo^.DoMore := More;
  End;


Function DoorUser.GetMore: Boolean;    {Will more prompts be done?}
  Begin
  GetMore := UserInfo^.DoMore;
  End;


Function DoorUser.StopMore: Boolean;   {More? answer of NO}
  Begin
  StopMore := UserInfo^.StopMore;
  End;


Procedure DoorUser.ResetLines(Ct: Word); {Reset more line count}
  Begin
  UserInfo^.CurrLines := Ct;
  End;


Procedure DoorUser.SetStopMore(St: Boolean);
  Begin
  UserInfo^.StopMore := St;
  End;


Procedure DoorUser.ClearScreen;
  Begin
  If GetUserAvatar Then
    Begin
    DisplayChr('');
    UserInfo^.CurrLines := 1;
    End
  Else
    If GetUserAnsi Then
      Begin
      DisplayStr('[40m[1H[2J');
      UserInfo^.CurrLines := 1;
      End;
  End;


Procedure DoorUser.ClrEOL;
  Begin
  If GetUserAvatar Then
    DisplayStr('')
  Else
    If GetUserAnsi Then
      DisplayStr('[K');
  End;


Function DoorUser.CurrentTime: LongInt; {Seconds since midnight of Log-On date}
  Var
    Temp: LongInt;
    Year: Word;
    Month: Word;
    Day: Word;
    TempDay: Word;
    DOW: Word;

  Begin
  GetDate(Year,Month,Day,DOW);
  Temp := (10 * TimeCounter Div 182);   {Temp is ticks since midnight / 18.2}
  GetDate(Year,Month,TempDay,DOW);
  If TempDay <> Day Then             {If Day changed get time again}
    Temp := (10 * TimeCounter Div 182);
  If UserInfo^.StartDay <>  Day Then {If Date doesn't match logon date}
    Inc(Temp,86400);                 {increase by 24hrs * 60min * 60sec}
  CurrentTime := Temp;
  End;


Procedure DoorUser.AdjustTime(Adj: LongInt);
  Begin
  UserInfo^.TimeLimit := UserInfo^.TimeLimit + Adj;
  UserInfo^.ExitInfo.TimeLimit := UserInfo^.ExitInfo.TimeLimit + (Adj Div 60);
  End;




Function DoorUser.GetCurrentDay: Word;
  Var
    Year: Word;
    Month: Word;
    DOW: Word;
    Day: Word;

  Begin
  GetDate(Year, Month, Day, DOW);
  GetCurrentDay := Day;
  End;


Procedure DoorUser.SetTimeOut;
  Begin
  UserInfo^.IdleWarn := False;
  UserInfo^.IdleLimit := CurrentTime + UserInfo^.IdleTime;
  End;


Procedure DoorUser.SetIdleTimeLimit(ITL: Word);
  Begin
  UserInfo^.IdleTime := ITL;
  End;


Function DoorUser.TimeRemain: LongInt;          {Seconds remaining}
  Var
    TempTime: LongInt;

  Begin
  TempTime := UserInfo^.TimeLimit + UserInfo^.StartTime - CurrentTime;
  If UserInfo^.Chat Then
    TimeRemain := TempTime + (CurrentTime - UserInfo^.ChatStart)
  Else
    TimeRemain := TempTime;
  End;



Function DoorUser.GetUserSecondsOn: Word;    {Get seconds user has beeen connected}
  Begin
  GetUserSecondsOn := CurrentTime - UserInfo^.StartTime;
  End;


Procedure DoorUser.TimeWarn;
  Var
    TempTime: LongInt;

  Begin
  TempTime := TimeRemain;
  If TempTime < 60 Then
    Begin
    If Not UserInfo^.OneMinWarn Then
      Begin
      UserInfo^.OneMinWarn := True;
      DisplayStrLn(Prompts.GetString(97));
      End;
    End
  Else
    If TempTime < 120 Then
      If Not UserInfo^.TwoMinWarn Then
        Begin
        UserInfo^.TwoMinWarn := True;
        DisplayStrLn(Prompts.GetString(98));
        End;
  End;


Function DoorUser.OkTime: Boolean;              {False if Time Limit exceeded}
  Var
    TempTime: LongInt;

  Begin
  TempTime := TimeRemain;
  OkTime := (TempTime > 0);
  If TempTime > 0 Then
    TimeWarn
  Else
    TimeOver;
  End;


Function  DoorUser.OK: Boolean;        {After CheckInput is all ok?}
  Begin
  Ok := UserInfo^.Ok;
  End;


Procedure DoorUser.SetOk(St: Boolean); {Set ok to false}
  Begin
  UserInfo^.Ok := St;
  UserInfo^.NotOkReason := 1;
  End;

Function DoorUser.GetChatReason: String;
  Begin
  GetChatReason := UserInfo^.ChatReason;
  End;


Procedure DoorUser.SetChatReason(Reason: String);
  Begin
  UserInfo^.ChatReason := Copy(Reason, 1, 50);
  End;


Procedure DoorUser.CheckInput;
  Begin
  If Not OkTime Then
    Begin
    UserInfo^.Ok := False;
    UserInfo^.NotOkReason := 2;
    End;
  If CommActive Then
    If (Not CommCarrier) Then
      Begin
      UserInfo^.Ok := False;
      UserInfo^.NotOkReason := 3;
      End;
  End;


Procedure DoorUser.CheckIdle;
  Begin
  If UserInfo^.IdleTime <> 0 Then
    Begin
    If ((Not UserInfo^.IdleWarn) and
    ((UserInfo^.IdleLimit - CurrentTime) < 30)) Then
      Begin
      UserInfo^.IdleWarn := True;
      DisplayAttr(White);
      DisplayNewLine;
      DisplayStrLn(Prompts.GetString(99));
      DisplayNewLine;
      End;
    If UserInfo^.IdleLimit <= CurrentTime Then
      Begin
      UserInfo^.Ok := False;
      UserInfo^.NotOkReason := 4;
      End;
    End;
  End;


Function DoorUser.CheckHot(HotStr: String): Char;
  Var
    TChar: Char;

  Begin
  CheckHot := #0;
  If User.InputChr(TChar) Then
    Begin
    TChar := UpCase(TChar);
    If (Pos(TChar, HotStr) > 0) Then
      CheckHot := TChar;
    End;
  End;


Procedure DoorUser.DisplayChr (OutChr:Char);
  Var
    CharWait: LongInt;

  Begin
  If CommActive Then
    Begin
    If Not SendText(OutChr) Then
      Begin
      CharWait := CurrentTime + UserInfo^.IdleTime;
      While ((Not SendText(OutChr)) and UserInfo^.OK And
      (CurrentTime <= CharWait)) Do
        CheckInput;
      If (CommActive and (CurrentTime > CharWait)) Then
        Begin
        UserInfo^.Ok := False;
        UserInfo^.NotOkReason := 5;
        End;
      End;
    End;
  AvatarChar(OutChr);
  End;


Procedure DoorUser.DisplayStr (OutStr:String);
  Var
    i: Integer;

  Begin
  i := 1;
  While ((i <= Length(OutStr)) and UserInfo^.Ok) Do
    Begin
    If CommActive Then
      While ((Not SendText(OutStr[i])) and UserInfo^.OK) Do
        CheckInput;
    AvatarChar(OutStr[I]);
    Inc(I);
    End;
  End;


Procedure DoorUser.TimeOver;
  Begin
  If Not UserInfo^.TimeOverWarn Then
    Begin
    UserInfo^.TimeOverWarn := True;
    DisplayStrLn(Prompts.GetString(96));
    End;
  End;


Procedure DoorUser.DetectWindow;
  {The session reports the caller's window (Telnet NAWS).  Its height, less the
   line for the prompt, is used as the screen length of this session; the value
   in the user record is not touched.  Choosing a length yourself (the
   SetUserScrLength of the screen length prompt) takes precedence again.}
  Var
    C, R: Word;

  Begin
  UserInfo^.SessWinVer := CommWindowVersion;
  If CommWindowSize(C, R) And (R >= 6) Then
    Begin
    If R - 1 > 66 Then
      UserInfo^.SessScrnLen := 66
    Else
      UserInfo^.SessScrnLen := R - 1;
    End;
  End;


Procedure DoorUser.CheckMore;
  Begin
  If CommWindowVersion <> UserInfo^.SessWinVer Then
    DetectWindow;                        {the caller resized the window}
  Inc(UserInfo^.CurrLines);
  If UserInfo^.CurrLines >= GetUserScrLength Then
    Begin
    If Not OkTime Then
      TimeOver;
    If ((UserInfo^.ExitInfo.User.Attr And 4) > 0) Then
      If Not UserInfo^.BatchMode Then
        AskMore;
    End;
  End;


Procedure DoorUser.AnsiChat;
  Const
    ChatWrap = 65;

  Var
    ChatDone: Boolean;
    ChChar: Char;
    ChatPos: Word;

  Begin
  UserInfo^.CurrLines := 1;
  If GetUserAnsi Then
    ClearScreen
  Else
    Begin
    DisplayNewLine;
    DisplayNewLine;
    End;
  DisplayStrLn(Prompts.GetString(78));
  DisplayNewLine;
  ChatDone := False;
  ChatPos := 0;
  While ((Not ChatDone) and CommCarrier) Do
    Begin
    If SysopKeyPressed Then
      Begin
      ChChar := SysopReadKey;
      Case ChChar of
        #008, #$7f: Begin
              If (ChatPos > 0) Then
                Begin
                Dec(ChatPos);
                DisplayChr(#8);
                DisplayChr(' ');
                DisplayChr(#8);
                End;
              End;
        #013: Begin
              ChatPos := 0;
              DisplayChr(#13);
              DisplayChr(#10);
              End;
        #027: ChatDone := True;
        #032: If ChatPos > ChatWrap Then
                Begin
                DisplayChr(#13);
                DisplayChr(#10);
                ChatPos := 0;
                End
              Else
                Begin
                DisplayChr(' ');
                Inc(ChatPos);
                End;
        Else
              Begin
              If ChatPos > 79 Then
                Begin
                ChatPos := 0;
                DisplayChr(#13);
                DisplayChr(#10);
                End;
              DisplayAttr(LightCyan);
              DisplayChr(ChChar);
              Inc(ChatPos);
              End;
        End;
      End;
    If Not CommInEmpty Then
      Begin
      ChChar := RecvText;
      Case ChChar Of
        #008, #$7f: Begin
              If (ChatPos > 0) Then
                Begin
                Dec(ChatPos);
                DisplayChr(#8);
                DisplayChr(' ');
                DisplayChr(#8);
                End;
              End;
        #027: Begin
              End;
        #013: Begin
              ChatPos := 0;
              DisplayChr(#13);
              DisplayChr(#10);
              End;
        #032: If ChatPos > ChatWrap Then
                Begin
                DisplayChr(#13);
                DisplayChr(#10);
                ChatPos := 0;
                End
              Else
                Begin
                DisplayChr(' ');
                Inc(ChatPos);
                End;
        Else
              Begin
              If ChatPos > 79 Then
                Begin
                ChatPos := 0;
                DisplayChr(#13);
                DisplayChr(#10);
                End;
              DisplayAttr(LightGreen);
              DisplayChr(ChChar);
              Inc(ChatPos);
              End;
        End;
      End;
    End;
  DisplayNewLine;
  DisplayNewLine;
  DisplayStrLn(Prompts.GetString(79));
  DisplayNewLine;
  If GetUserAnsi Then
    ClearScreen
  Else
    Begin
    DisplayNewLine;
    DisplayNewLine;
    End;
  End;


Procedure DoorUser.AvatarChat;
  Const
    ChatWrap = 65;
    CallerAttr = LightGreen;
    SysopAttr = LightCyan;

  Var
    CallerBeg: Byte;
    CallerEnd: Byte;
    SysopBeg: Byte;
    SysopEnd: Byte;
    SysopX, SysopY: Byte;
    CallerX, CallerY: Byte;
    ChatDone: Boolean;
    ChChar: Char;

  Begin
  SysopEnd := GetUserScrLength;
  If SysopEnd < 16 Then
    SysopEnd := 16;
  If (SysopEnd > ((ScrnHeight) - 3)) Then
    SysopEnd := ScrnHeight - 3;
  CallerBeg := 3;
  CallerEnd := (SysopEnd Div 2) - 1;
  SysopBeg := CallerEnd + 4;
  ClearScreen;
  UserInfo^.CurrLines := 1;
  DisplayAttr(CallerAttr);
  DisplayStr('' + Chr(CallerBeg - 2) + Chr(35));
  DisplayStr(Prompts.GetString(105));
  DisplayAttr(SysopAttr);
  DisplayStr('' + Chr(SysopBeg - 2) + Chr(35));
  DisplayStr(Prompts.GetString(106));
  DisplayStr('' + Chr(SysopBeg) + Chr(1));
  ChatDone := False;
  SysopX := 1;
  SysopY := SysopBeg;
  CallerX := 1;
  CallerY := CallerBeg;
  While ((Not ChatDone) and CommCarrier) Do
    Begin
    If SysopKeyPressed Then
      Begin
      DisplayStr('' + Chr(SysopY) + Chr(SysopX));
      DisplayAttr(SysopAttr);
      ChChar := SysopReadKey;
      Case ChChar of
        #008, #$7f: Begin
              If (SysopX > 1) Then
                Begin
                Dec(SysopX);
                DisplayChr(#8);
                DisplayChr(' ');
                DisplayChr(#8);
                End;
              End;
        #013: Begin
              SysopX := 1;
              Inc(SysopY);
              If SysopY > SysopEnd Then
                Begin
                SysopY := SysopEnd;
                DisplayStr('' + Chr(10) + Chr(1) + Chr(SysopBeg) + Chr(1) +
                  Chr(SysopEnd) + Chr(80));
                End;
              DisplayStr('' + Chr(SysopY) + Chr(SysopX));
              End;
        #027: ChatDone := True;
        #032: Begin
              If SysopX > ChatWrap Then
                Begin
                SysopX := 1;
                Inc(SysopY);
                If SysopY > SysopEnd Then
                  Begin
                  SysopY := SysopEnd;
                  DisplayStr('' + Chr(10) + Chr(1) + Chr(SysopBeg) + Chr(1) +
                    Chr(SysopEnd) + Chr(80));
                  End;
                DisplayStr('' + Chr(SysopY) + Chr(SysopX));
                End
              Else
                Begin
                DisplayChr(' ');
                Inc(SysopX);
                End;
              End;
        Else
              Begin
              If SysopX > 79 Then
                Begin
                SysopX := 1;
                Inc(SysopY);
                If SysopY > SysopEnd Then
                  Begin
                  SysopY := SysopEnd;
                  DisplayStr('' + Chr(10) + Chr(1) + Chr(SysopBeg) + Chr(1) +
                    Chr(SysopEnd) + Chr(80));
                  End;
                DisplayStr('' + Chr(SysopX) + Chr(SysopY));
                End;
              DisplayChr(ChChar);
              Inc(SysopX);
              End;
        End;
      End;
    If Not CommInEmpty Then
      Begin
      DisplayStr('' + Chr(CallerY) + Chr(CallerX));
      DisplayAttr(CallerAttr);
      ChChar := RecvText;
      Case ChChar Of
        #008, #$7f: Begin
              If (CallerX > 1) Then
                Begin
                Dec(CallerX);
                DisplayChr(#8);
                DisplayChr(' ');
                DisplayChr(#8);
                End;
              End;
        #013: Begin
              CallerX := 1;
              Inc(CallerY);
              If CallerY > CallerEnd Then
                Begin
                CallerY := CallerEnd;
                DisplayStr('' + Chr(10) + Chr(1) + Chr(CallerBeg) + Chr(1) +
                  Chr(CallerEnd) + Chr(80));
                End;
              DisplayStr('' + Chr(CallerY) + Chr(CallerX));
              End;
        #027: ChatDone := True;
        #032: Begin
              If CallerX > ChatWrap Then
                Begin
                CallerX := 1;
                Inc(CallerY);
                If CallerY > CallerEnd Then
                  Begin
                  CallerY := CallerEnd;
                  DisplayStr('' + Chr(10) + Chr(1) + Chr(CallerBeg) + Chr(1) +
                    Chr(CallerEnd) + Chr(80));
                  End;
                DisplayStr('' + Chr(CallerY) + Chr(CallerX));
                End
              Else
                Begin
                DisplayChr(' ');
                Inc(CallerX);
                End;
              End;
        Else
              Begin
              If CallerX > 79 Then
                Begin
                CallerX := 1;
                Inc(CallerY);
                If CallerY > CallerEnd Then
                  Begin
                  CallerY := CallerEnd;
                  DisplayStr('' + Chr(10) + Chr(1) + Chr(CallerBeg) + Chr(1) +
                    Chr(CallerEnd) + Chr(80));
                  End;
                DisplayStr('' + Chr(CallerY) + Chr(CallerX));
                End;
              DisplayChr(ChChar);
              Inc(CallerX);
              End;
        End;
      End;
    End;
  ClearScreen;
  DisplayAttr(White);
  DisplayNewLine;
  DisplayStrLn(Prompts.GetString(79));
  End;


Procedure DoorUser.DoChat;
  Begin
  If CommActive Then
    Begin
    UserInfo^.Chat := True;
    PostStatus(uoChat);
    UserInfo^.ChatStart := CurrentTime;
    SysopChatWanted := False;
    SysopFlushKeys;
    SnoopNotify('Chat started: type to the caller, Esc ends');
    If GetUserAvatar Then
      AvatarChat
    Else
      AnsiChat;
    SnoopNotify('Chat ended');
    Inc(UserInfo^.ExitInfo.TimeLimit, ((CurrentTime - UserInfo^.ChatStart) Div 60));
    Inc(UserInfo^.TimeLimit, (CurrentTime - UserInfo^.ChatStart));
    UserInfo^.Chat := False;
    End
  Else
    Begin
    DisplayNewLine;
    DisplayNewLine;
    DisplayStrLn(Prompts.GetString(100));
    DisplayNewLine;
    PressEnter;
    End;
  End;


Procedure DoorUser.DisplayNewLine;
  Begin
  DisplayChr(#13);
  DisplayChr(#10);
  CheckMore;
  If OkTime Then;
  End;


Procedure DoorUser.DisplayStrLn (OutStr:String);
  Begin
  DisplayStr(OutStr);
  DisplayNewLine;
  End;


Procedure DoorUser.DisplayCenterStrLn(OutStr: String);
  Begin
  If Length(OutStr) < 79 Then
    User.DisplayStr(PadRight('',' ',(80 - Length(OutStr)) Div 2));
  DisplayStrLn(OutStr);
  End;


Procedure DoorUser.DetectAnsi; {Detect ansi}
  Var
    STime: LongInt;
    Finished: Boolean;
    Ch: Char;

  Begin
  If Not CommActive Then
    UserInfo^.AnsiDet := True
  Else
    Begin
    UserInfo^.AnsiDet := False;
    DisplayStr(#27 + '[6n');
    CommFlushIn;
    STime := CurrentTime;
    Inc(STime, 1);
    Finished := False;
    While (CurrentTime <= STime) and (Not Finished) Do
      Begin
      If Not CommInEmpty Then
        Begin
        Ch := CommRecv;
         If (Ch in [#27,'0'..'9','[','H']) then
           Begin
           UserInfo^.AnsiDet := True;
           Finished := True;
           End;
        End;
      End;
    Delay(250);
    CommFlushIn;
    End;
  End;


Function DoorUser.WasAnsiDetected: Boolean;
  Begin
  WasAnsiDetected := UserInfo^.AnsiDet;
  End;


Function DoorUser.InputChr(Var Ch:Char): Boolean;
  Begin
  InputChr := False;
  If SysopChatWanted Then
    Begin                                {the sysop asked for a chat (mkmon)}
    SysopChatWanted := False;
    DoChat;
    SetTimeOut;
    End
  Else
    Begin
    If (CommActive and (Not CommInEmpty)) Then
      Begin
      InputChr := True;
      Ch := RecvText;
      SetTimeOut;
      End
    Else
      Begin
      End;
    End;
  End;


Procedure DoorUser.WaitEnter;
  Var
    TmpChr: Char;

  Begin
  SetTimeOut;
  If InputChr(TmpChr) Then;
  While (UserInfo^.Ok and (TmpChr <> #13)) Do
    Begin
    CheckInput;
    CheckIdle;
    If InputChr(TmpChr) Then;
    End;
  UserInfo^.CurrLines := 1;
  End;


Procedure DoorUser.PressEnter;
  Var
    TmpChr: Char;

  Begin
  If CommActive Then
    Begin
    While ((Not CommOutEmpty) and UserInfo^.Ok) Do
      Begin
      CheckInput;
      If CheckHot(' ') = ' ' Then
        CommFlushOut;
      End;
    End;
  UserInfo^.CurrLines := 1;
  User.DisplayAttr(Config^.GetSystemColor(1));
  DisplayStr(Prompts.GetString(6));
  WaitEnter;
  DisplayNewLine;
  End;


Procedure DoorUser.DisplayColor(Fr:Byte;Br:Byte);
  Begin
  If GetUserAvatar Then
    DisplayStr(''+Chr(Fr + (Br shl 4)))
  Else
    If GetUserAnsi Then
      DisplayStr(AnsiColor(Fr,Br));
  End;


Function DoorUser.GetAttrStr(Attr:Byte): String;
  Begin
  If GetUserAvatar Then
    GetAttrStr := '' + Chr(Attr)
  Else
    Begin
    If GetUserAnsi Then
      GetAttrStr := AnsiColor(Attr and 15, Attr Shr 4)
    Else
      GetAttrStr := '';
    End;
  End;


Procedure DoorUser.DisplayAttr(Attr:Byte);
  Begin
  If GetUserAvatar Then
    DisplayStr('' + Chr(Attr))
  Else
    If GetUserAnsi Then
      DisplayColor(Attr and 15, Attr Shr 4);
  End;



Procedure DoorUser.DisplayBkSpc;       {Display backspace}
  Begin
  DisplayChr(#8);
  DisplayChr(' ');
  DisplayChr(#8);
  End;


Procedure DoorUser.DisplayFile(FileName: String);

  Var
    AFile: File;
    TempChar: Char;
    Buffer: Array[1..256] of Char;
    I: Word;
    NumRead: Word;
    Found: Boolean;
    Ext: String[4];

  Begin
  If Not shAssign (Afile,FileName) Then;
  FileMode := fmReadOnly + fmDenyNone;
  If shReset (Afile,1) Then
    Begin
    While ((Not Eof(Afile)) and UserInfo^.OK) Do
      Begin
      BlockRead(Afile,Buffer, 255, NumRead);
      If IoResult <> 0 Then
        WriteLn(VOut, 'Error reading TxtFile');
      i := 1;
      While i <= NumRead Do
        Begin
        If CommActive Then
          While ((Not SendText(Buffer[i])) and UserInfo^.Ok) Do
            Begin
            CheckInput;
            If CheckHot(' ') = ' ' Then
              CommFlushOut;
            End;
        AvatarChar(Buffer[i]);
        Inc(i);
        End;
      End;
    Close(Afile);
    If IoResult <> 0 Then
      WriteLn(VOut, 'Error closing TxtFile');
    End
  Else
    WriteLn(VOut, 'Cannot Open TxtFile ' + FileName);
  End;


Function DoorUser.DisplayHotFile(FileName: String; HotStr: String): Char;
  Var
    AFile: File;
    TempChar: Char;
    Buffer: Array[1..256] of Char;
    I: Word;
    NumRead: Word;
    Found: Boolean;
    Ext: String[4];
    IChr: Char;
    HotStop: Boolean;

  Begin
  HotStop := False;
  If Not shAssign (Afile,FileName) Then;
  FileMode := fmReadOnly + fmDenyNone;
  If shReset (Afile,1) Then
    Begin
    While ((Not Eof(Afile)) and UserInfo^.OK and (Not HotStop)) Do
      Begin
      If InputChr(IChr) Then
        Begin
        If ((IChr <> #0) and (Pos(IChr, HotStr) > 0)) Then
          HotStop := True;
        End;
      If Not HotStop Then
        Begin
        BlockRead(Afile,Buffer,255,NumRead);
        If IoResult <> 0 Then
          WriteLn(VOut, 'Error reading TxtFile');
        i := 1;
        While i <= NumRead Do
          Begin
          If CommActive Then
            While ((Not SendText(Buffer[i])) and UserInfo^.Ok) Do
              Begin
              CheckInput;
              End;
          AvatarChar(Buffer[i]);
          Inc(i);
          End;
        End;
      End;
    Close(Afile);
    If IoResult <> 0 Then
      WriteLn(VOut, 'Error closing TxtFile');
    If HotStop Then
      DisplayHotFile := IChr
    Else
      DisplayHotFile := #0;
    End
  Else
    WriteLn(VOut, 'Cannot Open TxtFile ' + FileName);
  End;



Procedure DoorUser.Askmore;
  var
    tempchr:    char;
    tempstat:   byte;
    valid:      boolean;
    origfore:   integer;
    origback:   integer;
    YChar: Char;
    NChar: Char;
    CChar: Char;
    CmdStr: String[5];
    i: Word;

  Begin
  If CommActive Then
    While ((Not CommOutEmpty) and UserInfo^.Ok) Do
      Begin
      CheckInput;
      If CheckHot(' ') = ' ' Then
        CommFlushOut;
      End;
  ResetLines(1);
  If UserInfo^.DoMore Then
    Begin
    origfore := textattr and 15;
    origback := textattr shr 4;
    DisplayAttr (White);
    DisplayStr (Prompts.GetString(7));
    Displaycolor (origfore,origback);
    valid := false;
    SetTimeOut;
    CmdStr := Copy(Prompts.GetString(1),1,1) +
      Copy(Prompts.GetString(2),1,1) +
      Copy(Prompts.GetString(11),1,1) + #13;
    While ((Not Valid) and UserInfo^.Ok) do
      Begin
      If InputChr(TempChr) Then
        Begin
        TempChr := UpCase(TempChr);
        Case Pos(TempChr, CmdStr) of
          04:  Begin
               valid := true;
               End;
          03:  Begin
               valid := true;
               UserInfo^.DoMore := false;
               end;
          01:  Begin
               valid := true;
               end;
          02:  Begin
               valid := true;
               UserInfo^.Stopmore := true;
             End;
           End;
         End
       Else
         Begin
         CheckInput;
         CheckIdle;
         End;
      End;
    i := 1;
    While i <= Length(Prompts.GetString(7)) Do
      Begin
      Inc(i);
      DisplayBkSpc;
      End;
    End;
  End;


Function DoorUser.InputStr (InStr:String;MaxLen:Byte): String;
  Var
    ChrCnt: Byte;
    InDone: Boolean;
    TmpChr: Char;

  Begin
  InDone:=False;
  SetTimeOut;
  chrcnt:= Ord(Instr[0]);
  while ((not InDone) and UserInfo^.Ok) do
    Begin
    CheckInput;
    CheckIdle;
    If InputChr(tmpchr) Then
      Begin
      SetTimeOut;
      Case TmpChr of
        #00..#07:;
        #08, #$7f: Begin
             If ChrCnt > 0 Then
               Begin
               Dec(chrcnt);
               DisplayBkSpc;
               End;
             End;
        #09..#12:;
        #13: Begin
             InDone := True;
             End;
        #14..#31:;
        Else
             Begin
             If ChrCnt < MaxLen Then
               Begin
               Inc(ChrCnt);
               InStr[ChrCnt] := TmpChr;
               DisplayChr(TmpChr);
               End;
             End;
        End;
      End;
    End;
  InStr[0] := Chr(ChrCnt);
  UserInfo^.CurrLines := 1;
  InputStr := InStr;
  End;


Function DoorUser.InputProper(MaxLen: Byte): String;
  Var
    ChrCnt: Byte;
    InDone: Boolean;
    TmpStr: String;
    TmpChr: Char;

  Begin
  InDone:=False;
  SetTimeOut;
  ChrCnt:= 0;
  TmpStr := '';
  While ((Not InDone) and UserInfo^.Ok) do
    Begin
    CheckInput;
    CheckIdle;
    If InputChr(TmpChr) Then
      Begin
      SetTimeOut;
      Case TmpChr of
        #00..#07:;
        #08, #$7f: Begin
             If ChrCnt > 0 Then
               Begin
               Dec(ChrCnt);
               DisplayBkSpc;
               End;
             End;
        #09..#12:;
        #13: InDone := True;
        #14..#31:;
        Else
             Begin
             If ChrCnt < MaxLen Then
               Begin
               If ((ChrCnt = 0) or (Not (UpCase(TmpStr[ChrCnt]) in ['A'..'Z']))) Then
                 TmpChr := UpCase(TmpChr)
               Else
                 TmpChr := LoCase(TmpChr);
               Inc(ChrCnt);
               TmpStr[ChrCnt] := TmpChr;
               DisplayChr(TmpChr);
               End;
             End;
        End;
      End;
    End;
  TmpStr[0] := Chr(ChrCnt);
  DisplayNewLine;
  UserInfo^.CurrLines := 1;
  InputProper := TmpStr;
  End;




Procedure DoorUser.WWInputStr (Var Str:String; Var Extra: String;
  MaxLen:Byte; Ansi: Boolean; HiBit: Boolean);

  Var
    ChrCnt: Byte;
    InDone: Boolean;
    TmpChr: Char;
    LastSpace: Word;
    CrEnd: Boolean;
    i: Word;
    NumChars: Word;

  Const
    TabStop = 8;

  Begin
  Extra := '';
  LastSpace := 0;
  InDone:=False;
  SetTimeOut;
  ChrCnt:= Ord(Str[0]);
  While ((Not InDone) and UserInfo^.Ok) do
    Begin
    CheckInput;
    CheckIdle;
    If InputChr(TmpChr) Then
      Begin
      SetTimeOut;
      Case TmpChr of
        #00..#07:;
        #08, #$7f: Begin
             If ChrCnt > 0 Then
               Begin
               If Str[ChrCnt] = ' ' Then
                 Begin
                 While ((LastSpace <= 0) and (Str[LastSpace] <> ' ')) Do
                   Dec(LastSpace);
                 End;
               Dec(ChrCnt);
               DisplayBkSpc;
               End;
             End;
        #09: Begin
             NumChars := (((ChrCnt Div TabStop) + 1) * TabStop) - ChrCnt;
             If (NumChars + ChrCnt) > MaxLen Then
               Begin
               InDone := True;
               End
             Else
               Begin
               For i := (ChrCnt + 1) to (ChrCnt + NumChars) Do
                 Begin
                 Str[i] := ' ';
                 DisplayChr(' ');
                 End;
               ChrCnt := ChrCnt + NumChars;
               LastSpace := ChrCnt + NumChars;
               End;
             End;
        #10..#12:;
        #13: Begin
             InDone := True;
             Inc(ChrCnt);
             Str[ChrCnt] := TmpChr;
             End;
        #14..#26:;
        #27..#31:;
        Else
             Begin
             If ((TmpChr > #127) And (Not HiBit)) Then
               TmpChr := CleanChar(TmpChr);
             If ((TmpChr = #27) And (Not Ansi)) Then
               TmpChr := '`';
             If ChrCnt < MaxLen Then
               Begin
               Inc(ChrCnt);
               Str[ChrCnt] := TmpChr;
               If TmpChr = ' ' Then
                 LastSpace := ChrCnt;
               DisplayChr(TmpChr);
               End
             Else
               Begin
               If LastSpace > 0 Then
                 Begin
                 InDone := True;
                 Str[0] := Chr(ChrCnt);
                 Extra := Copy(Str, LastSpace + 1, ChrCnt - LastSpace);
                 i := Length(Extra);
                 While i > 0 Do
                   Begin
                   DisplayBkSpc;
                   Dec(i);
                   End;
                 Extra := Extra + TmpChr;
                 ChrCnt := LastSpace;
                 End
               Else
                 Begin
                 InDone := True;
                 Extra := TmpChr;
                 End
               End;
             End;
        End;
      End;
    End;
  Str[0] := Chr(ChrCnt);
  DisplayNewLine;
  UserInfo^.CurrLines := 1;
  End;


Function DoorUser.InputPwd (MaxLen:Byte): String;
  Var
    ChrCnt: Byte;
    InDone: Boolean;
    TmpChr: Char;
    InStr: String;
    PwdChr: Char;

  Begin
  PwdChr := Prompts.GetChar(20);
  InStr := '';
  InDone:=False;
  SetTimeOut;
  chrcnt:= Ord(Instr[0]);
  while ((not InDone) and UserInfo^.Ok) do
    Begin
    CheckInput;
    CheckIdle;
    If InputChr(tmpchr) Then
      Begin
      SetTimeOut;
      Case TmpChr of
        #00..#07:;
        #08, #$7f: Begin
             If ChrCnt > 0 Then
               Begin
               Dec(ChrCnt);
               DisplayBkSpc;
               End;
             End;
        #09..#12:;
        #13: InDone := True;
        #14..#31:;
        Else
             Begin
             If ChrCnt < MaxLen Then
               Begin
               Inc(ChrCnt);
               InStr[ChrCnt] := TmpChr;
               DisplayChr(PwdChr);
               End;
             End;
        End;
      End;
    End;
  InStr[0] := Chr(ChrCnt);
  DisplayNewLine;
  UserInfo^.CurrLines := 1;
  InputPwd := InStr;
  End;


Procedure DoorUser.Init;
  Var
    i: Word;

  Begin
  New(UserInfo);
  FillChar(UserInfo^.ExitInfo, SizeOf(UserInfo^.ExitInfo), 0);
  FillChar(UserInfo^.Extra, SizeOf(UserInfo^.Extra), 0);
  UserInfo^.UserLoaded := False;
  UserInfo^.Ok := True;
  UserInfo^.NotOkReason := 0;
  UserInfo^.Tagging := False;
  UserInfo^.CurrLines := 0;
  UserInfo^.SessScrnLen := 0;
  UserInfo^.SessWinVer := 0;
  UserInfo^.StopMore := False;
  UserInfo^.DoMore := True;
  UserInfo^.TwoMinWarn := False;
  UserInfo^.OneMinWarn := False;
  UserInfo^.TimeOverWarn := False;
  UserInfo^.BatchMode := False;
  UserInfo^.Chat := False;
  UserInfo^.IdleTime := 180;
  UserInfo^.TimeLimit := 3600;
  UserInfo^.StartDay := GetCurrentDay;
  UserInfo^.StartTime := CurrentTime;
  UserInfo^.BbsType := 0;
  UserInfo^.LineNum := 1;
  UserInfo^.TemplateMsg := 1;
  UserInfo^.TemplateFile := 1;
  UserInfo^.ChatReason := '';
  UserInfo^.MsgsToday := 0;
  UserInfo^.DLToday := 0;
  UserInfo^.ULToday := 0;
  UserInfo^.AnsiDet := False;
  UserInfo^.LastStatus := $ffff;
  For i := 1 To 4 Do
    Begin
    UserInfo^.LastLoaded[i] := False;
    UserInfo^.LastModified[i] := False;
    End;
  End;


Procedure DoorUser.Done;
  Begin
  If CommActive Then
    CommRelease;
  Dispose(UserInfo);
  End;


Procedure DoorUser.ReadUser;
  Var
    i: LongInt;
    RaExitPtr: ^RaExitInfoRecord;

  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitSize := SizeOf(ExitInfoType);
    2: UserInfo^.ExitSize := SizeOf(RAExitInfoRecord);
    3: UserInfo^.ExitSize := SizeOf(QBExitRecord);
    4: UserInfo^.ExitSize := SizeOf(SBExitRecord);
    Else
      UserInfo^.ExitSize := SizeOf(ExitInfoType);
    End;
  i := UserInfo^.ExitInfo.UserRecNum;
  i := i * SizeOf(UsersType);
  UserInfo^.UserLoaded :=
    (LoadFilePos(Config^.FindBbsFile('users.bbs') + 'users.bbs',
    UserInfo^.ExitInfo.User, SizeOf(UsersType), i) = 0);
  For i := 1 To 4 Do
    Begin
    UserInfo^.LastLoaded[i] := False;
    UserInfo^.LastModified[i] := False;
    End;
  Case UserInfo^.BbsType of
    1: Begin
       i := UserInfo^.ExitInfo.UserRecNum;
       i := i * SizeOf(ExtUserType);
       If LoadFilePos(Config^.FindBbsFile('extusers.bbs') + 'extusers.bbs',
         UserInfo^.ExitInfo.ExtUser, SizeOf(ExtUserType), i) = 0 Then;
       End;
    2: Begin
       RaExitPtr := @UserInfo^.ExitInfo;
       i := RaExitPtr^.UserInfo.XIRecord;
       i := i * SizeOf(RAUsersXIRecord);
       If LoadFilePos(Config^.FindBbsFile('usersxi.bbs') + 'usersxi.bbs',
         RaExitPtr^.UserXIInfo, SizeOf(RAUsersXIRecord), i) = 0 Then;
       End;
    End;
  End;


Procedure DoorUser.WriteUser;
  Var
    UPath: String;
    UPos: LongInt;
    NameIdx: UsersIdxType;
    RAExitPtr: ^RAExitInfoRecord;

  Begin
  If UserInfo^.UserLoaded Then
    Begin
    If GetUserLastDate = DateStr(GetDosDate) Then
      SetUserElapsed((GetUserSecondsOn Div 60)+ GetUserElapsed)
    Else
      SetUserElapsed(GetUserSecondsOn Div 60);
    SetUserLastDate(DateStr(GetDosDate));
    SetUserLastTime(TimeStr(GetDosDate));
    UPath := Config^.FindBbsFile('users.bbs') + 'users.bbs';
    UPos := UserInfo^.ExitInfo.UserRecNum;
    UPos := UPos * SizeOf(UsersType);
    If SaveFilePos(UPath, UserInfo^.ExitInfo.User, SizeOf(UsersType), UPos) = 0 Then;
    Case UserInfo^.BbsType Of
      1,2: Begin                  {Update UsersIdx.Bbs file}
        NameIdx.NameCrc := NameCrcCode(GetUserName);
        NameIdx.HandleCrc := NameCrcCode(GetUserHandle);
        UPos := UserInfo^.ExitInfo.UserRecNum;
        UPos := UPos * SizeOf(UsersIdxType);
        If SaveFilePos(Config^.FindBbsFile('usersidx.bbs') + 'usersidx.bbs',
          NameIdx, SizeOf(NameIdx), UPos) = 0 Then;
        End;
      End;
    Case UserInfo^.BbsType Of
      1: Begin                    {Update ExtUsers.Bbs}
         UPos := UserInfo^.ExitInfo.UserRecNum;
         UPos := UPos * SizeOf(ExtUserType);
         If SaveFilePos(Config^.FindBbsFile('extusers.bbs') + 'extusers.bbs',
           UserInfo^.ExitInfo.ExtUser, SizeOf(ExtUserType), UPos) = 0 Then;
         End;
      2: Begin                    {Update UsersXi.Bbs}
         RaExitPtr := @UserInfo^.ExitInfo;
         UPos := RaExitPtr^.UserInfo.XIRecord;
         UPos := UPos * SizeOf(RAUsersXIRecord);
         If SaveFilePos(Config^.FindBbsFile('usersxi.bbs') + 'usersxi.bbs',
           RaExitPtr^.UserXIInfo, SizeOf(RAUsersXIRecord), UPos) = 0 Then;
         End;
      End;
    End;
  End;


Procedure DoorUser.AddUser;
  Var
    USize: LongInt;
    LastCtr: Word;
    RAExitPtr: ^RAExitInfoRecord;

  Begin
  USize := SizeFile(Config^.FindBbsFile('users.bbs') + 'users.bbs');
  UserInfo^.ExitInfo.UserRecNum := USize Div SizeOf(UsersType);
  RaExitPtr := @UserInfo^.ExitInfo;
  RaExitPtr^.UserInfo.XIRecord :=
    SizeFile(Config^.FindBbsFile('usersxi.bbs') + 'usersxi.bbs') Div
    SizeOf(RAUsersXIRecord);
  UserInfo^.UserLoaded := True;
  WriteUser;
  USize := UserInfo^.ExitInfo.UserRecNum;
  End;


Procedure DoorUser.GetUserPos(Name: String);
  Const
    BufferSize = 20;

  Var
    UserBuffer: Array[1..BufferSize] of UsersType;
    UserFilePos : LongInt;
    UsersFile: File;
    Found: Boolean;
    NumRead: Word;
    UserCnt: Word;
    TempName: String[35];

  Begin
  If Not (FileExist(Config^.FindBbsFile('users.bbs') + 'users.bbs')) Then
    UserInfo^.ExitInfo.UserRecNum := $ffff
  Else
    Begin
    TempName := Upper(Name);
    If Not shAssign(UsersFile, Config^.FindBbsFile('users.bbs') + 'users.bbs') Then
      WriteLN('Error assigning users.bbs');
    FileMode := fmReadOnly + fmDenyNone;
    If Not shReset(UsersFile, SizeOf(UsersType)) Then
      WriteLn(VOut, 'Error resetting users.bbs');
    Found := False;
    While Not Eof(UsersFile) And Not (Found) Do
      Begin
      UserFilePos := FilePos(UsersFile);
      BlockRead(UsersFile,UserBuffer, BufferSize, NumRead);
      UserCnt := 0;
      While ((UserCnt < NumRead) and (Not Found)) Do
        Begin
          Inc(UserCnt);
          If Upper(UserBuffer[UserCnt].Name) = TempName Then
            Found := True;
        End;
      End;
    Close(UsersFile);
    If IoResult <> 0 Then
      WriteLn(VOut, 'Error closing users.bbs');
    If Found Then
      UserInfo^.ExitInfo.UserRecNum := UserFilePos + UserCnt - 1
    Else
      UserInfo^.ExitInfo.UserRecNum := $ffff;
    End;
  End;



Function DoorUser.UserFound: Boolean;          {Returns user found?}
  Begin
  UserFound := UserInfo^.ExitInfo.UserRecNum <> $ffff;
  End;


Procedure DoorUser.ReadExit(EPath: String);
  Var
    ExitInfoFile: File;
    i: Word;

  Begin
  If Not shAssign(ExitInfoFile, EPath + 'exitinfo.bbs') Then;
  FileMode := fmReadWrite + fmDenyNone;
  If Not shReset(ExitInfoFile, 1) Then
    WriteLn(VOut, 'Error resetting exitinfo.bbs');
  BlockRead(ExitInfoFile,UserInfo^.ExitInfo, SizeOf(UserInfo^.ExitInfo)
    + SizeOf(UserInfo^.Extra), UserInfo^.ExitSize);
  If IoResult <> 0 Then
    WriteLn(VOut, 'Error reading exitinfo.bbs');
  Close(ExitInfoFile);
  If IoResult <> 0 Then
    WriteLn(VOut, 'Error closing exitinfo.bbs');
  For i := 1 To 4 Do
    Begin
    UserInfo^.LastModified[i] := False;
    UserInfo^.LastLoaded[i] := False;
    End;
  End;


Procedure DoorUser.WriteExit(EPath: String);
  Var
    ExitInfoFile: File;

  Begin
  Case UserInfo^.BBSType of
    1: UserInfo^.ExitSize := SizeOf(ExitInfoType); {MK}
    2: UserInfo^.ExitSize := SizeOf(RAExitInfoRecord); {RA}
    3: UserInfo^.ExitSize := SizeOf(QBExitRecord); {Quick}
    4: UserInfo^.ExitSize := SizeOf(SBExitRecord); {Super}
    Else
      UserInfo^.ExitSize := SizeOf(ExitInfoType);
    End;
  If Not shAssign(ExitInfoFile, EPath + 'exitinfo.bbs') Then;
  FileMode := fmReadWrite + fmDenyNone;
  If FileExist(EPath + 'exitinfo.bbs') Then
    Begin
    If Not shReset(ExitInfoFile, 1) Then;
    End
  Else
    Begin
    ReWrite(ExitInfoFile, 1);
    If IoResult <> 1 Then;
    End;
  BlockWrite(ExitInfoFile,UserInfo^.ExitInfo,UserInfo^.ExitSize);
  If IoResult <> 0 Then;
  Close(ExitInfoFile);
  If IoResult <> 0 Then;
  End;


Procedure DoorUser.ReadDorInfo(DPath: String);
  Var
    I: Word;
    TmpStr: String;
    Code: Word;
    DFile: TFile;


  Begin
  DFile.Init;
  If Not FileExist(DPath + 'dorinfo1.def') Then
    WriteLn(VOut, 'Unable to find ' + DPath + 'dorinfo1.def');
  If Not DFile.OpenTextFile(DPath + 'dorinfo1.def') Then
    WriteLn(VOut, 'Unable to open dorinfo1.def');
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  DoorRemote := (Ord(TmpStr[4]) - Ord('0')) > 0;   {COMn in the drop file: caller is remote}
  TmpStr := DFile.GetString;
  I := Pos(' ',TmpStr);
  Val(Copy(TmpStr, 1, i-1), UserInfo^.ExitInfo.Baud, Code);
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  Val(TmpStr,UserInfo^.TimeLimit,Code);
  UserInfo^.TimeLimit := 60 * UserInfo^.TimeLimit;
  UserInfo^.StartDay := GetCurrentDay;
  UserInfo^.StartTime := CurrentTime;
  If Not DFile.CloseTextFile Then
    WriteLn(VOut, 'Unable to close dorinfo1.def');
  DFile.Done;
  If DoorRemote Then
    CommInit;                            {the program attached ComSession before}
  End;


Procedure DoorUser.GetUserSec(Var Sec: SecType); {Get user security level/flags}
  Begin
  Sec.Level := UserInfo^.ExitInfo.User.Security;
  Sec.Flags := UserInfo^.ExitInfo.User.Flags;
  End;



Procedure DoorUser.SetUserSec(Sec: SecType);
  Begin
  UserInfo^.ExitInfo.User.Security := Sec.Level;
  UserInfo^.ExitInfo.User.Flags := Sec.Flags;
  End;


Function DoorUser.GetUserLineNum: Word;
  Begin
  GetUserLineNum := UserInfo^.LineNum;
  End;


Procedure DoorUser.SetUserLineNum(Ln: Word);
  Begin
  UserInfo^.LineNum := Ln;
  End;


Function DoorUser.GetUserName: String;       {Get users name}
  Begin
  GetUserName := UserInfo^.ExitInfo.User.Name;
  End;


Procedure DoorUser.SetUserName(NStr: String); {Set users name}
  Begin
  UserInfo^.ExitInfo.User.Name := Copy(NStr,1,35);
  End;


Function DoorUser.GetUserCity: String;       {Get users city}
  Begin
  GetUserCity := UserInfo^.ExitInfo.User.City;
  End;


Procedure DoorUser.SetUserCity(CStr: String); {Set users city}
  Begin
  UserInfo^.ExitInfo.User.City := Copy(CStr,1,25);
  End;


Function DoorUser.GetUserPwd: String;        {Get users password}
  Begin
  GetUserPwd := UserInfo^.ExitInfo.User.Pwd;
  End;


Procedure DoorUser.SetUserPwd(PwdStr: String);{Set users password}
  Begin
  UserInfo^.ExitInfo.User.Pwd := Copy(PwdStr,1,15);
  End;


Function DoorUser.GetUserDataPhone: String;  {Get users data phone}
  Begin
  GetUserDataPhone := UserInfo^.ExitInfo.User.DPhone;
  End;


Procedure DoorUser.SetUserDataPhone(Phone: String); {Set users data phone}
  Begin
  UserInfo^.ExitInfo.User.DPhone := Copy(Phone,1,12);
  End;


Function DoorUser.GetUserVoicePhone: String; {Get users voice phone}
  Begin
  GetUserVoicePhone := UserInfo^.ExitInfo.User.HPhone;
  End;


Procedure DoorUser.SetUserVoicePhone(Voice: String); {Set users voice phone}
  Begin
  UserInfo^.ExitInfo.User.HPhone := Copy(Voice,1,12);
  End;


Function DoorUser.GetUserCredit: Integer;    {Get users netmail credit}
  Begin
  GetUserCredit := UserInfo^.ExitInfo.User.Credit;
  End;


Procedure DoorUser.SetUserCredit(Credit: Integer); {Set users netmail credit}
  Begin
  UserInfo^.ExitInfo.User.Credit := Credit;
  End;


Function DoorUser.GetUserPending: Integer;   {Get users pending netmail cost}
  Begin
  GetUserPending := UserInfo^.ExitInfo.User.Pending;
  End;


Procedure DoorUser.SetUserPending(Pending: Integer); {Set users pending cost}
  Begin
  UserInfo^.ExitInfo.User.Pending := Pending;
  End;


Function DoorUser.GetUserScrLength: Word;    {Get users screen length}
  Begin
  If CommWindowVersion <> UserInfo^.SessWinVer Then
    DetectWindow;
  If UserInfo^.SessScrnLen > 0 Then
    GetUserScrLength := UserInfo^.SessScrnLen
  Else
    GetUserScrLength := UserInfo^.ExitInfo.User.ScrnLen;
  End;


Procedure DoorUser.SetUserScrLength(Scr: Word); {Set users screen length}
  Begin
  UserInfo^.ExitInfo.User.ScrnLen := Scr;
  UserInfo^.SessScrnLen := 0;            {an explicit choice beats the terminal's size}
  End;

Function DoorUser.GetUserMsgsEntered: Word;  {Get number of msgs entered}
  Begin
  GetUserMsgsEntered := UserInfo^.ExitInfo.User.MsgsEntered;
  End;


Procedure DoorUser.SetUserMsgsEntered(MsgE: Word); {Set nbr of msgs entered}
  Begin
  UserInfo^.ExitInfo.User.MsgsEntered := MsgE;
  End;


Function DoorUser.GetUserTimesCalled: Word;  {Get number of times called}
  Begin
  GetUserTimesCalled := UserInfo^.ExitInfo.User.TimesCalled;
  End;


Procedure DoorUser.SetUserTimesCalled(Calls: Word); {Set nbr of times called}
  Begin
  UserInfo^.ExitInfo.User.TimesCalled := Calls;
  End;


Function  DoorUser.GetUserCombRead: Word;     {Get combined last read}
  Begin
  GetUserCombRead := UserInfo^.ExitInfo.User.HighMsgRead;
  End;


Procedure DoorUser.SetUserCombRead(Comb: Word); {Set combined last read}
  Begin
  UserInfo^.ExitInfo.User.HighMsgRead := Comb;
  End;


Function  DoorUser.GetUserTodayK: Integer;    {Get net "k" transfered today}
  Begin
  GetUserTodayK := UserInfo^.ExitInfo.User.TodayK;
  End;


Procedure DoorUser.SetUserTodayK (TK: Integer); {Set net "k" transfered today}
  Begin
  UserInfo^.ExitInfo.User.TodayK := TK;
  End;


Function DoorUser.GetUserULK: Word;    {Get "k" uploaded}
  Begin
  GetUserULK := UserInfo^.ExitInfo.User.ULK;
  End;


Procedure DoorUser.SetUserULK (TK: Word); {Set "k" uploaded today}
  Begin
  UserInfo^.ExitInfo.User.ULK := TK;
  End;


Function DoorUser.GetUserDLK: Word;    {Get "k" downloaded today}
  Begin
  GetUserDLK := UserInfo^.ExitInfo.User.DLK;
  End;


Procedure DoorUser.SetUserDLK (TK: Word); {Set "k" downloaded today}
  Begin
  UserInfo^.ExitInfo.User.DLK := TK;
  End;


Function  DoorUser.GetUserULFiles: Word;    {Get Num Files uploaded}
  Begin
  GetUserULFiles := UserInfo^.ExitInfo.User.ULFiles;
  End;


Procedure DoorUser.SetUserULFiles (TK: Word); {Set Num Files uploaded today}
  Begin
  UserInfo^.ExitInfo.User.ULFiles := TK;
  End;


Function DoorUser.GetUserDLFiles: Word;    {Get Num Files downloaded today}
  Begin
  GetUserDLFiles:= UserInfo^.ExitInfo.User.DLFiles;
  End;


Procedure DoorUser.SetUserDLFiles (TK: Word); {Set Num Files downloaded today}
  Begin
  UserInfo^.ExitInfo.User.DLFiles := TK;
  End;


Function DoorUser.GetUserElapsed: Integer;    {Get Elapsed time prior calls today}
  Begin
  GetUserElapsed:= UserInfo^.ExitInfo.User.ElapsedTime;
  End;


Procedure DoorUser.SetUserElapsed (TK: Integer); {Set Elapsed time}
  Begin
  UserInfo^.ExitInfo.User.ElapsedTime := TK;
  End;


Function DoorUser.GetUserLastDate: String; {Get user last called date}
  Begin
  GetUserLastDate := UserInfo^.ExitInfo.User.LastDateOn;
  End;


Procedure DoorUser.SetUserLastDate (LD: String); {Set last called date}
  Begin
  UserInfo^.ExitInfo.User.LastDateOn := Copy(LD,1,8);
  End;


Function DoorUser.GetUserLastTime: String; {Get user last called time}
  Begin
  GetUserLastTime := UserInfo^.ExitInfo.User.LastTimeOn;
  End;


Procedure DoorUser.SetUserLastTime (LT: String); {Set last called time}
  Begin
  UserInfo^.ExitInfo.User.LastTimeOn := Copy(LT,1,5);
  End;


Function DoorUser.GetUserBbsType: Byte;      {Get Bbs type}
  Begin
  GetUserBbsType := UserInfo^.BbsType;
  End;


Procedure DoorUser.SetUserBbsType(BT: Byte);  {Set Bbs type}
  Begin
  UserInfo^.BbsType := BT;
  End;


Function DoorUser.GetUserLanguage: Byte;     {Get user lang number}
  Begin
  Case UserInfo^.BbsType Of
    1: GetUserLanguage := UserInfo^.ExitInfo.Language;
    Else
      GetUserLanguage := 1;
    End;
  End;


Procedure DoorUser.SetUserLanguage(Ln: Byte); {Set user lang number}
  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.Language := Ln;
    End;
  End;


Function DoorUser.GetUserBaud: Word;         {Get user baud rate}
  Begin
  GetUserBaud := UserInfo^.ExitInfo.Baud;
  End;


Procedure DoorUser.SetUserBaud(Bd: Word);     {Set user baud rate}
  Begin
  UserInfo^.ExitInfo.Baud := Bd;
  End;


Function DoorUser.GetUserMsgTemplate: Word; {Get user msg template area}

  Begin
  Case UserInfo^.BbsType of
    1: GetUserMsgTemplate := UserInfo^.ExitInfo.ExtUser.CurrMsgArea;
    2: GetUserMsgTemplate := RaExitInfoPtr(@UserInfo^.ExitInfo)^.UserXIInfo.MsgArea;
    Else
      GetUserMsgTemplate := UserInfo^.TemplateMsg;
    End;
  End;


Procedure DoorUser.SetUserMsgTemplate(Tm: Word); {Set user msg template area}
  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.ExtUser.CurrMsgArea := Tm;
    2: RaExitInfoPtr(@UserInfo^.ExitInfo)^.UserXIInfo.MsgArea := Tm;
    Else
      UserInfo^.TemplateMsg := Tm;
    End;
  End;


Function DoorUser.GetUserFileTemplate: Word; {Get user file template area}
  Begin
  Case UserInfo^.BbsType Of
    1: GetUserFileTemplate := UserInfo^.ExitInfo.ExtUser.CurrFileArea;
    2: GetUserFileTemplate := RaExitInfoPtr(@UserInfo^.ExitInfo)^.UserXIInfo.FileArea;
    Else
      GetUserFileTemplate := UserInfo^.TemplateFile;
    End;
  End;


Procedure DoorUser.SetUserDoorTemplate(Tm: Word); {Set user door template area}
  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.ExtUser.CurrDoorArea := Tm;
    Else
      UserInfo^.TemplateDoor := Tm;
    End;
  End;


Function DoorUser.GetUserDoorTemplate: Word; {Get user door template area}
  Begin
  Case UserInfo^.BbsType Of
    1: GetUserDoorTemplate := UserInfo^.ExitInfo.ExtUser.CurrDoorArea;
    Else
      GetUserDoorTemplate := UserInfo^.TemplateDoor;
    End;
  End;


Procedure DoorUser.SetUserFileTemplate(Tm: Word); {Set user file template area}
  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.ExtUser.CurrFileArea := Tm;
    2: RaExitInfoPtr(@UserInfo^.ExitInfo)^.UserXIInfo.FileArea := Tm;
    Else
      UserInfo^.TemplateFile := Tm;
    End;
  End;




Function  DoorUser.GetUserPageTimes: Word;    {Get number of times has paged}
  Begin
  GetUserPageTimes := UserInfo^.ExitInfo.PagedTimes;
  End;


Procedure DoorUser.SetUserPageTimes(Pg: Word);{Set number of times has paged}
  Begin
  UserInfo^.ExitInfo.PagedTimes := Pg;
  End;


Function  DoorUser.GetUserTimeLimit: Integer; {Get user time limit}
  Begin
  GetUserTimeLimit := UserInfo^.ExitInfo.TimeLimit;
  End;


Procedure DoorUser.SetUserTimeLimit(TL: Word);{Set user time limit}
  Begin
  UserInfo^.ExitInfo.TimeLimit := TL;
  End;


Function  DoorUser.GetUserDLLimit: Word;      {Get user DL limit}
  Begin
  GetUserDLLimit := UserInfo^.ExitInfo.DLLimit;
  End;


Procedure DoorUser.SetUserDLLimit(DL: Word);  {Set user DL limit}
   Begin
   UserInfo^.ExitInfo.DLLimit := DL;
   End;


Function DoorUser.GetSystemCalls: LongInt;      {Get system number of calls}
  Begin
  GetSystemCalls := UserInfo^.ExitInfo.SysInfo.CallCount;
  End;


Procedure DoorUser.SetSystemCalls(CL: LongInt);  {Set system number of calls}
  Begin
  UserInfo^.ExitInfo.SysInfo.CallCount := CL;
  End;


Function DoorUser.GetSystemLastCaller: String;  {Get system last caller name}
  Begin
  GetSystemLastCaller := UserInfo^.ExitInfo.SysInfo.LastCaller;
  End;


Procedure DoorUser.SetSystemLastCaller(LC: String); {Set system last caller name}
  Begin
  UserInfo^.ExitInfo.SysInfo.LastCaller := Copy(LC,1,35);
  End;


Function DoorUser.GetNextEventStr: String;   {Get next event time string}
  Begin
  GetNextEventStr := UserInfo^.ExitInfo.Event.Time;
  End;


Function DoorUser.GetUserCombined(Area: Word): Boolean;
  Var
    ConfIdx: Word;
    ConfMask: Byte;
    RaPtr: ^RaExitInfoRecord;

  Begin
  ConfIdx := ((Area - 1) shr 3) + 1;
  ConfMask := 1;
  ConfMask := ConfMask Shl ((Area - 1) and 7);
  Case UserInfo^.BbsType of
    1: If (Area > 0) and (Area < 501) Then
         GetUserCombined := (UserInfo^.ExitInfo.ExtUser.Combined[ConfIdx] and
         ConfMask) <> 0
       Else
         GetUserCombined := False;
    2: Begin
       RAPtr := @UserInfo^.ExitInfo;
       If (Area > 0) and (Area < 501) Then
         GetUserCombined := (RAPtr^.UserXIInfo.CombinedInfo[ConfIdx] and
         ConfMask) <> 0
       Else
         GetUserCombined := False;
       End;
    Else
      GetUserCombined := False;
    End;
  End;


Procedure DoorUser.SetUserCombined(Area: Word; St: Boolean);
  Var
    ConfIdx: Word;
    ConfMask: Byte;
    RaPtr: ^RaExitInfoRecord;

  Begin
  ConfIdx := ((Area - 1) shr 3) + 1;
  ConfMask := 1;
  ConfMask := ConfMask Shl ((Area - 1) and 7);
  Case UserInfo^.BbsType of
    1: If (Area > 0) and (Area < 501) Then
         Begin
         If St Then
           UserInfo^.ExitInfo.ExtUser.Combined[ConfIdx] :=
           UserInfo^.ExitInfo.ExtUser.Combined[ConfIdx] or ConfMask
         Else
           UserInfo^.ExitInfo.ExtUser.Combined[ConfIdx] :=
           UserInfo^.ExitInfo.ExtUser.Combined[ConfIdx] and (Not ConfMask);
         End;
    2: Begin
       RAPtr := @UserInfo^.ExitInfo;
       If (Area > 0) and (Area < 501) Then
         Begin
         If St Then
           RAPtr^.UserXIInfo.CombinedInfo[ConfIdx]  :=
           RAPtr^.UserXIInfo.CombinedInfo[ConfIdx] or ConfMask
         Else
           RAPtr^.UserXIInfo.CombinedInfo[ConfIdx]  :=
           RAPtr^.UserXIInfo.CombinedInfo[ConfIdx] and (Not ConfMask)
         End;
       End;
    End;
  End;


Function DoorUser.GetUserOffline(Area: Word): Boolean;
  Var
    ConfIdx: Word;
    ConfMask: Byte;

  Begin
  ConfIdx := ((Area - 1) shr 3) + 1;
  ConfMask := 1;
  ConfMask := ConfMask Shl ((Area - 1) and 7);
  Case UserInfo^.BbsType of
    1: If (Area > 0) and (Area < 501) Then
         GetUserOffline := (UserInfo^.ExitInfo.ExtUser.Offline[ConfIdx] and
         ConfMask) <> 0
       Else
         GetUserOffline := False;
    Else
      GetUserOffline := False;
    End;
  End;


Procedure DoorUser.SetUserOffline(Area: Word; St: Boolean);
  Var
    ConfIdx: Word;
    ConfMask: Byte;

  Begin
  ConfIdx := ((Area - 1) shr 3) + 1;
  ConfMask := 1;
  ConfMask := ConfMask Shl ((Area - 1) and 7);
  Case UserInfo^.BbsType of
    1: If (Area > 0) and (Area < 501) Then
         Begin
         If St Then
           UserInfo^.ExitInfo.ExtUser.Offline[ConfIdx] :=
           UserInfo^.ExitInfo.ExtUser.Offline[ConfIdx] or ConfMask
         Else
           UserInfo^.ExitInfo.ExtUser.Offline[ConfIdx] :=
           UserInfo^.ExitInfo.ExtUser.Offline[ConfIdx] and (Not ConfMask);
         End;
    End;
  End;


Function DoorUser.GetUserProt: Char;  {Get user default protocol}
  Begin
  Case UserInfo^.BbsType of
    1: GetUserProt := UpCase(UserInfo^.ExitInfo.ExtUser.Protocol);
    Else
      GetUserProt := ' ';
    End;
  End;


Procedure DoorUser.SetUserProt(PT: Char); {Set user default protocol}
  Begin
  Case UserInfo^.BBSType of
    1: UserInfo^.ExitInfo.ExtUser.Protocol := UpCase(PT);
    End;
  End;


Function DoorUser.GetUserPacker: Char;  {Get user default packer}
  Begin
  Case UserInfo^.BbsType of
    1: GetUserPacker := UpCase(UserInfo^.ExitInfo.ExtUser.Packer);
    Else
      GetUserPacker := ' ';
    End;
  End;


Procedure DoorUser.SetUserPacker(PT: Char); {Set user default packer}
  Begin
  Case UserInfo^.BBSType of
    1: UserInfo^.ExitInfo.ExtUser.Packer := UpCase(PT);
    End;
  End;


Function DoorUser.GetUserOffType: Char; {Get user offline pkt type}
  Begin
  Case UserInfo^.BbsType of
    1: GetUserOffType := UpCase(UserInfo^.ExitInfo.ExtUser.OffType);
    Else
      GetUserOffType := 'Q';
    End;
  End;


Procedure DoorUser.SetUserOffType(OT: Char); {Set user offline pkt type}
  Begin
  If UserInfo^.BbsType = 1 Then
    UserInfo^.ExitInfo.ExtUser.OffType := UpCase(OT);
  End;


Function DoorUser.GetUserOffMax: Word; {Get offline max msg per pkt}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffMax := UserInfo^.ExitInfo.ExtUser.OffMax
  Else
    GetUserOffMax := 1000;
  End;


Procedure DoorUser.SetUserOffMax(OM: Word); {set offline max}
  Begin
  If UserInfo^.BbsType = 1 Then
    UserInfo^.ExitInfo.ExtUser.OffMax := OM;
  End;


Function DoorUser.GetUserOffConfMax: Word; {Get offline max msgs per area}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetuserOffConfMax := Userinfo^.ExitInfo.ExtUser.OffConfMax
  Else
    GetUserOffConfMax := 500;
  End;


Procedure DoorUser.SetUserOffConfMax(OM: Word); {Set max msgs per area}
  Begin
  If UserInfo^.BbsType = 1 Then
    UserInfo^.ExitInfo.ExtUser.OffConfMax := OM;
  End;


Function DoorUser.GetUserOffNew: Boolean; {Get user offline new files list}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffNew := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaNew) <> 0
  Else
    GetUserOffNew := False;
  End;


Procedure DoorUser.SetUserOffNew(OA: Boolean); {Set new files list setting}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaNew
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaNew);
    End;
  End;


Function DoorUser.GetUserOffScrn: Boolean; {Get user offline screens}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffScrn := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaScrn) <> 0
  Else
    GetUserOffScrn := True;
  End;


Procedure DoorUser.SetUserOffScrn(OA: Boolean); {Set user wants screens}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaScrn
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaScrn);
    End;
  End;


Function DoorUser.GetUserOffBull: Boolean; {Get user wants bulletins}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffBull := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaBull) <> 0
  Else
    GetUserOffBull := True;
  End;


Procedure DoorUser.SetUserOffBull(OA: Boolean); {Set user wants bulletins}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaBull
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaBull);
    End;
  End;


Function DoorUser.GetUserOffVerify: Boolean; {Get user wants verify}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffVerify := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaVerify) <> 0
  Else
    GetUserOffVerify := False;
  End;


Procedure DoorUser.SetUserOffVerify(OA: Boolean); {Set user wants verify}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaVerify
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaVerify);
    End;
  End;


Function DoorUser.GetUserOffFlag: Boolean; {Flag as read}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffFlag := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaFlag) <> 0
  Else
    GetUserOffFlag := True;
  End;


Procedure DoorUser.SetUserOffFlag(OA: Boolean); {Flag as read}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaFlag
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaFlag);
    End;
  End;


Function DoorUser.GetUserOffOwn: Boolean; {Get own msgs}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffOwn := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaOwn) <> 0
  Else
    GetUserOffOwn := True;
  End;


Procedure DoorUser.SetUserOffOwn(OA: Boolean); {Get own msgs}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaOwn
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaOwn);
    End;
  End;


Function DoorUser.GetUserOffAllYour: Boolean; {All areas for your mail}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffAllYour := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaAllYour) <> 0
  Else
    GetUserOffAllYour := False;
  End;


Procedure DoorUser.SetUserOffAllYour(OA: Boolean); {All areas for your mail}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaAllYour
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaAllYour);
    End;
  End;


Function DoorUser.GetUserOffZero: Boolean; {Wants zero msg pkts}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffZero := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaZero) <> 0
  Else
    GetUserOffZero := False;
  End;


Procedure DoorUser.SetUserOffZero(OA: Boolean); {Wants zero msg pkts}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaZero
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaZero);
    End;
  End;


Function DoorUser.GetUserOffGate: Boolean; {User is gating msgs to another network}
  Begin
  If UserInfo^.BbsType = 1 Then
    GetUserOffGate := (UserInfo^.ExitInfo.ExtUser.OffAttr and uoaGateWay) <> 0
  Else
    GetUserOffGate := False;
  End;


Procedure DoorUser.SetUserOffGate(OA: Boolean); {User is gating msgs}
  Begin
  If UserInfo^.BbsType = 1 Then
    Begin
    If OA Then
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr or uoaGateWay
    Else
      UserInfo^.ExitInfo.ExtUser.OffAttr :=
      UserInfo^.ExitInfo.ExtUser.OffAttr and (Not uoaGateWay);
    End;
  End;


Function DoorUser.GetUserAvatar: Boolean;    {Get avatar setting}
  Var
    RaUserPtr: ^RaUsersRecord;

  Begin
  Case UserInfo^.BbsType of
    1: GetUserAvatar := ((UserInfo^.ExitInfo.ExtUser.ExtraInfo and eiAvatar) <> 0);
    2: Begin
       RaUserPtr := @UserInfo^.ExitInfo.User;
       GetUserAvatar := ((RaUserPtr^.Attribute2 and 2) <> 0);
       End;
    Else
      GetUserAvatar := False;
    End;
  End;


Procedure DoorUser.SetUserAvatar(AV: Boolean);{Set user avatar}
  Var
    RaUserPtr: ^RaUsersRecord;

  Begin
  Case UserInfo^.BbsType of
    1: Begin
       If AV Then
         UserInfo^.ExitInfo.ExtUser.ExtraInfo :=
         UserInfo^.ExitInfo.ExtUser.ExtraInfo or eiAvatar
       Else
         UserInfo^.ExitInfo.ExtUser.ExtraInfo :=
         UserInfo^.ExitInfo.ExtUser.ExtraInfo and Not(Word(eiAvatar));
       End;
    2: Begin
       RaUserPtr := @UserInfo^.ExitInfo.User;
       If AV Then
         RaUserPtr^.Attribute2 := RaUserPtr^.Attribute2 or 2
       Else
         RaUserPtr^.Attribute2 := RaUserPtr^.Attribute2 and Not(2);
       End;
    End;
  End;


Function DoorUser.GetUserHandle: String;
  Var
    RAPtr: ^RAExitInfoRecord;

  Begin
  Case UserInfo^.BbsType of
    1: GetUserHandle := UserInfo^.ExitInfo.ExtUser.Handle;
    2: Begin
       RaPtr := @UserInfo^.ExitInfo;
       GetUserHandle := Copy(RaPtr^.UserXIInfo.Handle,1,35);
       End;
    Else
      GetUserHandle := '';
    End;
  End;


Procedure DoorUser.SetUserHandle(Hd: String);
  Var
    RAPtr: ^RAExitInfoRecord;

  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.ExtUser.Handle := Proper(Copy(Hd,1,35));
    2: Begin
       RAPtr := @UserInfo^.ExitInfo;
       RaPtr^.UserXIInfo.Handle := Proper(Copy(Hd,1,35));
       End;
    End;
  End;


Function DoorUser.GetUserBirthDate: String; {Get user birthdate MM-DD-YY}
  Var
    RAPtr: ^RAExitInfoRecord;

  Begin
  Case UserInfo^.BbsType of
    1: GetUserBirthDate := MKDateToStr(UserInfo^.ExitInfo.ExtUser.BirthDate);
    2: Begin
       RaPtr := @UserInfo^.ExitInfo;
       GetUserBirthDate := RaPtr^.UserXIInfo.BirthDate;
       End;
    Else
      GetUserBirthDate := '';
    End;
  End;


Procedure DoorUser.SetUserBirthDate(BD: String); {Set user birthdate MM-DD-YY}
  Var
    RAPtr: ^RAExitInfoRecord;

  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.ExtUser.BirthDate := StrToMKDate(BD);
    2: Begin
       RAPtr := @UserInfo^.ExitInfo;
       RaPtr^.UserXIInfo.BirthDate := BD;
       End;
    End;
  End;


Function DoorUser.GetUserFirstDate: String; {Get user first call MM-DD-YY}
  Var
    RAPtr: ^RAExitInfoRecord;

  Begin
  Case UserInfo^.BbsType of
    1: GetUserFirstDate := MKDateToStr(UserInfo^.ExitInfo.ExtUser.FirstCall);
    2: Begin
       RaPtr := @UserInfo^.ExitInfo;
       GetUserFirstDate := RaPtr^.UserXIInfo.FirstDate;
       End;
    Else
      GetUserFirstDate := '';
    End;
  End;


Procedure DoorUser.SetUserFirstDate(BD: String); {Set user first call MM-DD-YY}
  Var
    RAPtr: ^RAExitInfoRecord;

  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.ExtUser.FirstCall := StrToMKDate(BD);
    2: Begin
       RAPtr := @UserInfo^.ExitInfo;
       RaPtr^.UserXIInfo.FirstDate := BD;
       End;
    End;
  End;


Function DoorUser.GetUserPageTune: Byte;
  Begin
  Case UserInfo^.BbsType Of
    1: GetUserPageTune := UserInfo^.ExitInfo.ExtUser.PageTune;
    Else
      GetUserPageTune := Lo(UserInfo^.ExitInfo.User.Security);
    End;
  End;


Procedure DoorUser.SetUserPageTune(Tune: Byte);
  Begin
  Case UserInfo^.BbsType Of
    1: UserInfo^.ExitInfo.ExtUser.PageTune := Tune;
    End;
  End;


Function DoorUser.GetUserAnsi: Boolean;      {Get ansi setting}
  Begin
  GetUserAnsi := ((UserInfo^.ExitInfo.User.Attr and uaAnsi) <> 0);
  End;


Procedure DoorUser.SetUserAnsi(UA: Boolean);  {Set user ansi}
  Begin
  If UA Then
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr or uaAnsi
  Else
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr and Not(uaAnsi);
  End;

Function DoorUser.GetUserFullEd: Boolean;    {Get full-screen editor setting}
  Begin
  GetUserFullEd := ((UserInfo^.ExitInfo.User.Attr and uaFullScrEd) <> 0);
  End;


Procedure DoorUser.SetUserFullEd(FE: Boolean);{Set full-screen editor setting}
  Begin
  If FE Then
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr or uaFullScrEd
  Else
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr and Not(uaFullScrEd);
  End;


Function DoorUser.GetUserMore: Boolean;      {Get ask more setting}
  Begin
  GetUserMore := ((UserInfo^.ExitInfo.User.Attr and uaMore) <> 0);
  End;


Procedure DoorUser.SetUserMore(Mo: Boolean);  {Set ask more setting}
  Begin
  If Mo Then
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr or uaMore
  Else
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr and Not(uaMore);
  End;


Function  DoorUser.GetUserScrnClr: Boolean;       {Get screen clear setting}
  Begin
  GetUserScrnClr := ((UserInfo^.ExitInfo.User.Attr and uaScrnClr) <> 0);
  End;


Procedure DoorUser.SetUserScrnClr(Cl: Boolean);   {Set screen clear setting}
  Begin
  If cl Then
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr or uaScrnClr
  Else
    UserInfo^.ExitInfo.User.Attr :=
    UserInfo^.ExitInfo.User.Attr and Not(uaScrnClr);
  End;


Function DoorUser.AskDate(Var DT: DateTime): Boolean;   {Ask user date}
  Var
    DateMask: String[25];
    TmpStr: String[25];
    CurrPos: Word;
    Ch: Char;
    ExtYear: Boolean;
    Code: Word;
    DateValid: Boolean;

  Begin
  DateValid := False;
  ResetLines(1);
  SetTimeOut;
  DateMask := Upper(Prompts.GetString(58));
  ExtYear := (Pos('YYYY', DateMask) > 0);
  If ((Pos('MM',DateMask) > 0) And (Pos('YY',DateMask) > 0)
  And (Pos('DD',DateMask) > 0)) Then
    Begin
    AskDate := True;
    While ((Not DateValid) and (UserInfo^.Ok)) Do
      Begin
      TmpStr := '';
      TmpStr[0] := Char(Length(DateMask));
      CurrPos := 1;
      While ((CurrPos <= (Length(DateMask) + 1)) and UserInfo^.Ok) Do
        Begin
        If ((CurrPos <= Length(DateMask))
        And (Not (DateMask[CurrPos] In ['D','M','Y']))) Then
          Begin
          TmpStr[CurrPos] := DateMask[CurrPos];
          DisplayChr(DateMask[CurrPos]);
          Inc(CurrPos);
          End
        Else
          Begin
          If InputChr(Ch) Then
            Begin
            Case Ch of
              #13:  Begin
                    If (CurrPos = 1) Then
                      CurrPos := 255;
                    If (CurrPos = Length(DateMask) + 1) Then
                      Inc(CurrPos);
                    End;
              #08, #$7f:  Begin
                    If CurrPos > 1 Then
                      Begin
                      DisplayBkSpc;
                      Dec(CurrPos);
                      While ((CurrPos > 1) and
                      (Not (DateMask[CurrPos] In ['D','M','Y']))) Do
                        Begin
                        DisplayBkSpc;
                        Dec(CurrPos);
                        End;
                      End;
                    End;
              '0'..'9': Begin
                    If (CurrPos <= Length(DateMask)) Then
                      Begin
                      TmpStr[CurrPos] := Ch;
                      Inc(CurrPos);
                      DisplayChr(Ch);
                      End;
                    End;
              End;
            End
          Else
             Begin
             CheckInput;
             CheckIdle;
             End;
          End;
        End;
      If CurrPos < 255 Then
        Begin
        Val(Copy(TmpStr,Pos('DD', DateMask), 2), DT.Day, Code);
        Val(Copy(TmpStr,Pos('MM', DateMask), 2), DT.Month, Code);
        If ExtYear Then
          Val(Copy(TmpStr,Pos('YYYY', DateMask), 4), DT.Year, Code)
        Else
          Val(Copy(TmpStr,Pos('YY', DateMask), 2), DT.Year, Code);
        End;
      DateValid := ValidDate(DT);
      If Not DateValid Then
        Begin
        DisplayNewLine;
        DisplayStr(Prompts.GetString(159) + ' ');
        End;
      End;
    End
  Else
    AskDate := False;
  UserInfo^.CurrLines := 1;
  End;


Function DoorUser.AskFormatted(FMStr: String): String;
  Var
    Ch: Char;
    TmpStr: String;
    CurrPos: Word;
    CurrMask: Char;
    CharValid: Boolean;

  Begin
  ResetLines(1);
  SetTimeOut;
  TmpStr := '';
  TmpStr[0] := Char(Length(FMStr));
  CurrPos := 1;
  While ((CurrPos <= (Length(FMStr) + 1)) and UserInfo^.Ok) Do
    Begin
    If (CurrPos <= Length(FMStr)) Then
      Begin
      CurrMask := UpCase(FMStr[CurrPos]);
      If (Not (CurrMask In ['X','9','A'])) Then
        Begin
        TmpStr[CurrPos] := FMStr[CurrPos];
        DisplayChr(FMStr[CurrPos]);
        Inc(CurrPos);
        End;
      End;
    If InputChr(Ch) Then
      Begin
      Case Ch of
        #13: Begin
             If (CurrPos = Length(FMStr) + 1) Then
               Inc(CurrPos);
             End;
        #08, #$7f: Begin
             If CurrPos > 1 Then
               Begin
               DisplayBkSpc;
               Dec(CurrPos);
               While ((CurrPos > 1) and
               (Not (UpCase(FMStr[CurrPos]) In ['A','X','9']))) Do
                  Begin
                  DisplayBkSpc;
                  Dec(CurrPos);
                  End;
                End;
              End;
        ' '..'~': Begin
              If (CurrPos <= Length(FMStr)) Then
                Begin
                CharValid := False;
                Case CurrMask Of
                  'A': Begin
                       If Ch In ['A'..'Z','a'..'z'] Then
                          CharValid := True;
                       End;
                  'X': Begin
                       CharValid := True;
                       End;
                  '9': Begin
                       If Ch In ['0'..'9'] Then
                         CharValid := True;
                       End;
                  End;
                If CharValid Then
                  Begin
                  TmpStr[CurrPos] := Ch;
                  Inc(CurrPos);
                  DisplayChr(Ch);
                  End;
                End; { If CurrPos <=}
              End; {' '..'~'}
        End; {End Case}
      End {If InputChr}
    Else
      Begin
      CheckInput;
      CheckIdle;
      End;
    End; {While}
  If Ok Then
    AskFormatted := TmpStr
  Else
    AskFormatted := '';
  UserInfo^.CurrLines := 1;
  End;


Function DoorUser.AskPhone: String;
  Var
    TmpStr: String[20];

  Begin
  TmpStr := Copy(Prompts.GetString(194),1, 12);
  If Length(TmpStr) > 0 Then
    AskPhone := AskFormatted(TmpStr)
  Else
    AskPhone := InputStr('',12);
  End;


Procedure DoorUser.GetUserNewFileDate(Var DT: DateTime);
  Var
    DStr: String[15];
    Code: Word;

  Begin
  Case UserInfo^.BbsType of
    1: Begin
       DStr := MKDateToStr(UserInfo^.ExitInfo.ExtUser.NewDate);
       If ((Length(DStr) = 0) or (Copy(DStr,1,2) = '--')) Then
          DStr := GetUserLastDate;
       End;
    Else
      Begin
      DStr := GetUserLastDate;
      End;
    End;
  If ((Length(DStr) = 0) or (Copy(DStr,1,2) = '--')) Then
    DStr := '01/01/80';
  Val(Copy(DStr,1,2), DT.Month, Code);
  Val(Copy(DStr,4,2), DT.Day, Code);
  Val(Copy(DStr,7,2), DT.Year, Code);
  If DT.Year < 100 Then
    Begin
    If DT.Year < 80 Then
      Inc(DT.Year, 2000)
    Else
      Inc(DT.Year, 1900);
    End;
  End;


Function  DoorUser.AskNumber(Num: LongInt; Min: LongInt; Max: LongInt): LongInt;
  Var
    TmpStr: String[10];
    Finished: Boolean;
    Valid: Boolean;
    Ch: Char;
    Tmp: LongInt;
    Code: Word;

  Begin
  Valid := False;
  SetTimeOut;
  While ((Not Valid) and (ok)) Do
    Begin
    Finished := False;
    TmpStr := '';
    While ((Not Finished) and (ok)) Do
      Begin
      If InputChr(Ch) Then
        Begin
        Case Length(TmpStr) of
          0: Begin
             Case Ch of
               #13: Begin
                    DisplayStr(Long2Str(Num));
                    Finished := True;
                    Valid := True;
                    End;
               '0'..'9': Begin
                    TmpStr := TmpStr + Ch;
                    DisplayChr(ch);
                    End;
               '-': If (Min < 0) Then
                      TmpStr := TmpStr + Ch;
               End;
             End;
          1..7: Begin
                Case ch of
                  #13: Begin
                       Finished := True;
                       End;
                  #08, #$7f: Begin
                       Dec(TmpStr[0]);
                       DisplayStr(#8#32#8);
                       End;
                  '0'..'9': Begin
                       TmpStr := TmpStr + Ch;
                       DisplayChr(ch);
                       End;
                  End;
                End;
          Else
             Begin
             Finished := True;
             End;
          End;
        End
      Else
        Begin
        CheckInput;
        CheckIdle;
        End;
      End;
    If Length(TmpStr) = 0 Then
      AskNumber := Num
    Else
      Begin
      Val(TmpStr, Tmp, Code);
      If ((Code = 0) and (Tmp <= Max) and (Tmp >= Min)) Then
        Begin
        Valid := True;
        AskNumber := Tmp;
        End
      Else
        Begin
        DisplayNewLine;
        If Tmp > Max Then
          Begin
          DisplayStrLn(Prompts.GetString(17) + ' ' + Long2Str(Max));
          End
        Else
          Begin
          DisplayStrLn(Prompts.GetString(16) + ' ' + Long2Str(Min));
          End;
        DisplayStr(Prompts.GetString(28) + ' ');
        End;
      End;
    End;
  ResetLines(1);
  End;


Function DoorUser.DefaultNumStr(Num: LongInt): String; {returns (enter = xx)}
  Begin
  DefaultNumStr := ' ' + Prompts.GetString(12) + Prompts.GetString(5) + ' ' +
    Long2Str(Num) + Prompts.GetString(13) + ' ';
  End;



Procedure DoorUser.SetUserNewFileDate(DT: DateTime);
  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.ExtUser.NewDate := FormattedDate(DT, 'YYMMDD');
    End;
  End;


Function DoorUser.AskChoice(ChStr: String): Char;
  Var
    Valid: Boolean;
    TempChr: Char;

  Begin
  Valid := False;
  SetTimeOut;
  While (Ok and (Not Valid)) Do
    Begin
    If InputChr(TempChr) Then
      Begin
      TempChr := UpCase(TempChr);
      If Pos(TempChr, ChStr) > 0 Then
        Valid := True;
      End
    Else
      Begin
      CheckInput;
      CheckIdle;
      TempChr := #0;
      End;
    End;
  AskChoice := TempChr;
  ResetLines(1);
  End;


Procedure DoorUser.AskYN(Quest: String; Var Option: Boolean);
  Var
    TmpChr: Char;
    YChr: Char;
    NChr: Char;

  Begin
  DisplayAttr(White);
  DisplayStr(Quest + ' ' + Prompts.GetString(3) + ', ' +
    Prompts.GetString(4) + ', ' + Prompts.GetString(5) + ' ');
  If Option Then
    DisplayStr(Prompts.GetString(3))
  Else
    DisplayStr(Prompts.GetString(4));
  DisplayStr(Prompts.GetString(14) + ' ');
  YChr := Prompts.GetChar(1);
  NChr := Prompts.GetChar(2);
  TmpChr := AskChoice(YChr + NChr + #13);
  If TmpChr = YChr Then
    Option := True;
  If TmpChr = NChr Then
    Option := False;
  If Option Then
    DisplayStr(Prompts.GetString(3))
  Else
    DisplayStr(Prompts.GetString(4));
  ResetLines(1);
  End;


Procedure DoorUser.ClearGoSub;
  {Max gosub level = 20, RA actually would allow 50}
  Var
    RaPtr: ^RAExitInfoRecord;
    QbPtr: ^QBExitRecord;
    SBPtr: ^SBExitRecord;

  Begin
  Case UserInfo^.BbsType of
    1: UserInfo^.ExitInfo.GoSubLevel := 0;
    2: Begin
       RaPtr := @UserInfo^.ExitInfo;
       RaPtr^.MenuStackPointer := 0;
       End;
    3: Begin
       QbPtr := @UserInfo^.ExitInfo;
       QbPtr^.GoSubLevel := 0;
       End;
    4: Begin
       SbPtr := @UserInfo^.ExitInfo;
       SbPtr^.GoSubLevel := 0;
       End;
    End;
  End;


Procedure DoorUser.GoSub(MN: String);
  {Max gosub level = 20, RA actually would allow 50}
  Var
    RaPtr: ^RAExitInfoRecord;
    QbPtr: ^QBExitRecord;
    SBPtr: ^SBExitRecord;

  Begin
  MN := Copy(MN,1,8);
  Case UserInfo^.BbsType of
    1: Begin
       If UserInfo^.ExitInfo.GoSubLevel < 20 Then
         Begin
         Inc(UserInfo^.ExitInfo.GoSubLevel);
         UserInfo^.ExitInfo.GoSub[UserInfo^.ExitInfo.GoSubLevel] := MN;
         End;
       End;
    2: Begin
       RaPtr := @UserInfo^.ExitInfo;
       If RaPtr^.MenuStackPointer < 50 Then
         Begin
         Inc(RaPtr^.MenuStackPointer);
         RAPtr^.MenuStack[RaPtr^.MenuStackPointer] := MN;
         End;
       End;
    3: Begin
       QbPtr := @UserInfo^.ExitInfo;
       If QbPtr^.GoSubLevel < 20 Then
         Begin
         Inc(QbPtr^.GoSubLevel);
         QbPtr^.GoSubData[QbPtr^.GoSubLevel] := MN;
         End;
       End;
    4: Begin
       SbPtr := @UserInfo^.ExitInfo;
       If SbPtr^.GoSubLevel < 20 Then
         Begin
         Inc(SbPtr^.GoSubLevel);
         SbPtr^.GoSubData[SbPtr^.GoSubLevel] := MN;
         End;
       End;
    End;
  End;


Function DoorUser.GoSubReturn: String;
  Var
    RaPtr: ^RAExitInfoRecord;
    QbPtr: ^QBExitRecord;
    SBPtr: ^SBExitRecord;
    MN: String[8];

  Begin
  MN := '';
  Case UserInfo^.BbsType of
    1: Begin
       If UserInfo^.ExitInfo.GoSubLevel > 0 Then
         Begin
         MN := UserInfo^.ExitInfo.GoSub[UserInfo^.ExitInfo.GoSubLevel];
         Dec(UserInfo^.ExitInfo.GoSubLevel);
         End;
       End;
    2: Begin
       RaPtr := @UserInfo^.ExitInfo;
       If RaPtr^.MenuStackPointer > 0 Then
         Begin
         MN := RAPtr^.MenuStack[RaPtr^.MenuStackPointer];
         Dec(RaPtr^.MenuStackPointer);
         End;
       End;
    3: Begin
       QbPtr := @UserInfo^.ExitInfo;
       If QbPtr^.GoSubLevel > 0 Then
         Begin
         MN := QbPtr^.GoSubData[QbPtr^.GoSubLevel];
         Dec(QbPtr^.GoSubLevel);
         End;
       End;
    4: Begin
       SbPtr := @UserInfo^.ExitInfo;
       If SbPtr^.GoSubLevel > 0 Then
         Begin
         MN := SbPtr^.GoSubData[SbPtr^.GoSubLevel];
         Dec(SbPtr^.GoSubLevel);
         End;
       End;
    End;
  GoSubReturn := MN;
  End;

Function DoorUser.GetUserRecNum: Word;
  Begin
  GetUserRecNum := UserInfo^.ExitInfo.UserRecNum;
  End;


Function DoorUser.GetSessionTimeLimit: LongInt; {Seconds this call allowed}
  Begin
  GetSessionTimeLimit := UserInfo^.TimeLimit;
  End;


Procedure DoorUser.SetSessionTimeLimit(TL: LongInt); {Seconds allowed this call}
  Begin
  UserInfo^.TimeLimit := TL;
  End;


Procedure DoorUser.SetStartTime; {Set start time}
  Begin
  UserInfo^.StartDay := GetCurrentDay;
  UserInfo^.StartTime := CurrentTime;
  End;

Function ShellProgram(Name: String): String;
  {The program of a command line as it is meant: menus and doors are written the DOS way (a backslash in the path), a name
   without a path is looked for in the current directory (the BBS directory) first and then in the path.  A name that is
   not found is returned as it is.}
  Var
    i: Word;
    P: String;

  Begin
  For i := 1 To Length(Name) Do
    If Name[i] = '\' Then
      Name[i] := '/';
  If (Name <> '') And (Pos('/', Name) = 0) Then
    Begin
    If FileExist('./' + Name) Then
      Name := './' + Name
    Else
      Begin
      P := FSearch(Name, GetEnv('PATH'));
      If P <> '' Then
        Name := P;
      End;
    End;
  ShellProgram := Name;
  End;


Function DoorPtyWanted: Boolean;
  Begin
  DoorPtyWanted := CommActive And (Not DoorRaw) And (GetEnv('MK_NOPTY') = '');
  End;


Procedure DoShell(Cmd: String; DoSwap: Boolean; DoWindow: Boolean);
  {Run a program (or a shell) and come back.  DoSwap / DoWindow were for the
   DOS memory swapper and are ignored.  ShellError says whether it could be run.
   With a caller connected the program runs on a pseudo terminal (MKPty): echo, line ends, a terminal for curses; the
   caller's connection stays in use, MKComAbs does the telnet part.  With TypeSeven's *S, without a caller (the console)
   or when no terminal can be made, the program is started with the caller's connection as its standard input and output.}
  Var
    CDirStr: String;
    EName: String;
    CStr: String;
    Code: LongInt;
    R: Word;
    Done: Boolean;

  Begin
  EName := ShellProgram(ExtractWord(Cmd, 1));
  CStr := Copy(Cmd, Length(ExtractWord(Cmd, 1)) + 1, 255);
  CDirStr := GetCurrentPath;
  ShellError := 0;
  If Not FileExist(EName) Then
    ShellError := 2
  Else
    Begin
    Done := False;
    If DoorPtyWanted Then
      Begin
      R := PtyRun(EName, CStr, ComSession^.GetTermType, Code);
      If R = 0 Then
        Done := True
      Else If R = ptyNoExec Then
        Begin
        Done := True;
        ShellError := 8;
        End;
      End;
    If Not Done Then
      Begin
      Exec(EName, CStr);
      ShellError := DosError;
      End;
    End;
  ChDir(StripTrail(CDirStr, DirectorySeparator));
  If IoResult <> 0 Then;
  User.SetTimeOut;
  End;


Procedure DoorUser.SetSysInfo(Var SysInfo: SysInfoType);
  Begin
  UserInfo^.ExitInfo.SysInfo := SysInfo;
  End;


Procedure DoorUser.UpdateForMsg; {Increment msgs posted count}
  Begin
  Inc(UserInfo^.MsgsToday);
  Inc(UserInfo^.ExitInfo.User.MsgsEntered);
  End;


Procedure DoorUser.UpdateForDL(FSize: LongInt); {Increment DL count and update K}
  Begin
  Inc(UserInfo^.DLToday);
  Inc(UserInfo^.ExitInfo.User.DLFiles);
  Inc(UserInfo^.ExitInfo.User.DLk, FSize Div 1024);
  Inc(UserInfo^.ExitInfo.User.TodayK, FSize Div 1024);
  End;


Procedure DoorUser.UpdateForUL(FSize: LongInt); {Increment UL count and update K}
  Begin
  Inc(UserInfo^.ULToday);
  Inc(UserInfo^.ExitInfo.User.ULFiles);
  Inc(UserInfo^.ExitInfo.User.ULk, FSize Div 1024);
  Dec(UserInfo^.ExitInfo.User.TodayK, FSize Div 1024);
  End;


Function DoorUser.UserIsLoaded: Boolean;
  Begin
  UserIsLoaded :=  UserInfo^.UserLoaded;
  End;


Procedure DoorUser.PostStatus(Status: Byte);
  Var
    UserOn: UserOnType;
    Tmp: LongInt;

  Begin
  If Status <> UserInfo^.LastStatus Then
    Begin
    FillChar(UserOn, SizeOf(UserOn), 0);
    UserOn.Status := Status;
    UserOn.Name := GetUserName;
    UserOn.Handle := GetUserHandle;
    UserOn.Node := GetUserLineNum;
    UserOn.City := GetUserCity;
    UserOn.Baud := GetUserBaud;
    Tmp := UserOn.Node;
    Tmp := Tmp * SizeOf(UserOnType);
    ExtendFile(Config^.GetBbsPath + 'useron.bbs', Tmp);
    If SaveFilePos(Config^.GetBBSPath + 'useron.bbs', UserOn,
      SizeOf(UserOn), Tmp - SizeOf(UserOnType)) = 0 Then
    UserInfo^.LastStatus := Status;
    End;
  End;


Function DoorUser.GetMsgNetwork(Net: Byte): Boolean;
  Var
    ConfMask: LongInt;

  Begin
  ConfMask := 1;
  If ((Net > 0) and (Net < 33)) Then
    Begin
    ConfMask := ConfMask shl (Net - 1);
    Case UserInfo^.BBSType of
      1: GetMsgNetwork := (UserInfo^.ExitInfo.ExtUser.NetStat and ConfMask) <> 0;
      Else
        GetMsgNetwork := False;
      End;
    End
  Else
    GetMsgNetwork := False;
  End;


Procedure DoorUser.SetMsgNetwork(Net: Byte; MN: Boolean);
  Var
    ConfMask: LongInt;

  Begin
  ConfMask := 1;
  If ((Net > 0) and (Net < 33) and (UserInfo^.BBSType = 1)) Then
    Begin
    ConfMask := ConfMask shl (Net - 1);
    If MN Then
      UserInfo^.ExitInfo.ExtUser.NetStat :=
      UserInfo^.ExitInfo.ExtUser.NetStat or ConfMask
    Else
      UserInfo^.ExitInfo.ExtUser.NetStat :=
      UserInfo^.ExitInfo.ExtUser.NetStat and (Not ConfMask);
    End;
  End;


Function DoorUser.GetUserNetStatus: LongInt;
  Begin
  Case UserInfo^.BBSType Of
    1: GetUserNetStatus := UserInfo^.ExitInfo.ExtUser.NetStat;
    Else
      GetUserNetStatus := 0;
    End;
  End;


Procedure DoorUser.SetUserNetStatus(NS: LongInt);
  Begin
  Case UserInfo^.BBSType of
    1: UserInfo^.ExitInfo.ExtUser.NetStat := NS;
    End;
  End;


Function DoorUser.GetNotOkReason: Word;
  Begin
  GetNotOkReason := UserInfo^.NotOkReason;
  End;


End.
