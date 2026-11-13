Unit MKUsrAbs;

{$I MKB.Def}

{$i-}

{$X+}


{
     MKUsrAbs - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses MKGlobT, MKComAbs, MKStr, MKRemote,
  {$IFDEF WINDOWS}
  WinDos, WinProcs, WinTypes;
  {$ELSE}
  Dos;
  {$ENDIF}


Type UserInfoType = Record
  UserFileName: String[130];
  Ok: Boolean;
  NotOkReason: Word;
  Tagging: Boolean;
  StartDay: Word;
  StartTime: LongInt;
  TimeLimit: Word;
  CurrLines: Word;
  ScrnLen: Word;
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
  StatType: Byte;
  LineNum: Word;
  UserLoaded: Boolean;
  MsgsToday: Word;
  DLToday: Word;
  ULToday: Word;
  AnsiDet: Boolean;
  CurrentPort: Word;
  LastStatus: Word;
  End;


Type AbsUsrObj = Object
  UserInfo: ^UserInfoType;
  Comm: ^AbsComObj;
  Prompts: ^StrObj;
  Sem: ^RemoteCheck;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetComPtr(cm: AbsComPtr); Virtual;
  Procedure SetCurrentPort(CP: Word); Virtual;
  Procedure SetStrPtr(sp: StrObjPtr); Virtual;
  Procedure SetSemPtr(sp: RemoteCheckPtr); Virtual;
  Procedure ClrEOL; Virtual; {Clear to eol if ansi on}
  Procedure ClearScreen; Virtual; {Clear screen if ansi on}
  Function  UserFound: Boolean; Virtual; {Returns user found?}
  Procedure SetMore(More: Boolean); Virtual; {This session ask more?}
  Function  GetMore: Boolean; Virtual; {Will more prompts be done?}
  Function  StopMore: Boolean; Virtual; {More? answer of NO}
  Procedure SetStopMore(St: Boolean); Virtual; {Set more? answer}
  Procedure ResetLines(Ct: Word); Virtual; {Reset more line count}
  Function  CurrentTime: LongInt; Virtual; {Seconds since midnight of log-on day}
  Function  GetCurrentDay: Word; Virtual; {Get Day of Month}
  Procedure SetIdleTimeLimit(ITL: Word); Virtual; {Set idle timer limit
                                          in seconds}
  Procedure SetTimeOut; Virtual; {Set Idle timer for IdleTime seconds from now}
  Function  TimeRemain: LongInt; Virtual; {Seconds remaining}
  Procedure TimeWarn; Virtual; {Check time remaining and give warning if needed}
  Function  OkTime: Boolean; Virtual; {False if Time Limit exceeded}
  Function  OK: Boolean; Virtual; {After CheckInput is all ok?}
  Function  GetNotOkReason: Word; Virtual; {Get reason ok is false}
  Procedure SetOk(St: Boolean); Virtual; {Set ok to false}
  Procedure StatusDisplay(StatusType: Byte); Virtual; {Display status info at
                                          bottom of screen}
  Function  GetStatusType: Byte; Virtual; {Get current status display type}
  Procedure SetStatusType(ST:Byte); Virtual; {Set current status display type}
  Function  GetChatReason: String; Virtual; {Get chat reason}
  Procedure SetChatReason(Reason: String); Virtual; {Set chat reason}
  Procedure CheckInput; Virtual; {Check time remain, carrier, etc}
  Procedure CheckIdle; Virtual; {Check for idle timeout}
  Function  CheckHot(HotStr: String): Char; Virtual; {Check for hot key - #0 = none}
  Procedure DisplayChr (OutChr:Char); Virtual; {Display character remote & local}
  Procedure DisplayStr (OutStr:String); Virtual; {Display string remote & local}
  Procedure DisplayStrLn (OutStr:String); Virtual; {Display string with new line}
  Procedure DisplayCenterStrLn(OutStr: String); Virtual; {Display string centered}
  Procedure DisplayNewLine; Virtual; {Display CR/LF}
  Procedure DisplayColor (Fr:Byte;Br:Byte); Virtual; {Set ansi fore/back colors}
  Function  GetAttrStr(Attr:Byte): String; Virtual; {Get attribute setting string}
  Procedure DisplayAttr (Attr:Byte); Virtual; {Set ansi color attribute}
  Procedure DisplayXY(XL: Byte; YL: Byte); Virtual; {GoToXY position}
  Procedure DisplayBkSpc; Virtual; {Display backspace}
  Procedure TimeOver; Virtual; {Tell user time is over}
  Procedure CheckMore; Virtual; {Inc line count and check for more}
  Procedure AnsiChat; Virtual; {Internal use}
  Procedure AvatarChat; Virtual; {Internal use}
  Procedure DoChat; Virtual; {Start chat}
  Procedure LocalCommand(CommandChar:Char); Virtual; {Process local command}
  Procedure WaitEnter; Virtual; {Wait for enter to be pressed}
  Procedure PressEnter; Virtual; {Ask user to Press Enter}
  Function  InputChr(Var Ch:Char): Boolean; Virtual; {True if char read and returned
                                          in CH}
  Procedure DisplayFile(FileName: String); Virtual;
  Function  DisplayHotFile(FileName: String; HotStr: String):Char; Virtual;
  Procedure AskMore; Virtual;
  Function  AskDate(Var DT: MKDateTime): Boolean; Virtual; {Ask user date}
  Function  AskFormatted(FMStr: String): String; Virtual;
    {Ask string using FMStr for formatting 9=num a=alpha x=anything}
  Function  AskPhone: String; Virtual;
    {Ask for phone number using language format string}
  Function  AskChoice(ChStr: String): Char;  Virtual; {Get char limited to ChStr}
  Procedure AskYN(Quest: String; Var Option: Boolean); Virtual; {Ask Y/N Question}
  Function  AskNumber(Num: LongInt; Min: LongInt; Max: LongInt): LongInt; Virtual;
  Function  DefaultNumStr(Num: LongInt): String; Virtual; {returns (enter = xx)}
  Function  InputStr (InStr:String; MaxLen:Byte): String; Virtual;
  Function  InputProper(MaxLen: Byte): String; Virtual;
  Procedure WWInputStr (Var Str:String; Var Extra: String; MaxLen:Byte;
    Ansi: Boolean; HiBit: Boolean); Virtual;
    {Input a word wrapped string, excess in extra}
  Function  InputPwd (MaxLen:Byte): String; Virtual; {Input password}
  Procedure DetectAnsi; Virtual; {Detect ansi}
  Function  WasAnsiDetected: Boolean; Virtual;
  Procedure ReadUser; Virtual; {Read user based on UserRecNum in ExitInfo}
  Procedure WriteUser; Virtual;
  Procedure AddUser; Virtual;
  Procedure AdjustTime(Adj: LongInt); Virtual;
  Function  FindUser(Name: String): LongInt; Virtual;
  Procedure GetUserPos(Name: String); Virtual;
  Procedure ReadExit(EPath: String); Virtual; {Read ExitInfo from given path}
  Procedure WriteExit(EPath: String); Virtual; {Write ExitInfo to given path}
  Procedure DoShell(Cmd: String; DoSwap: Boolean); Virtual;
  Procedure AdjustUserTime(TA: LongInt); Virtual; {adjust user time remain by ta}
  Function  GetUserLineNum: Word; Virtual; {Get caller line number}
  Procedure SetUserLineNum(Ln: Word); Virtual; {Set caller line number}
  Function  GetUserSecondsOn: Word; Virtual; {Get seconds user has beeen connected}
  Procedure GetUserSec(Sec: Pointer); Virtual; {Get user security level/flags}
  Procedure SetUserSec(Sec: Pointer); Virtual; {Set user security level/flags}
  Function  GetUserSecLevel: LongInt; Virtual; {Get user security level}
  Function  GetUserSecStr: String; Virtual; {Get user security as string}
  Function  GetUserName: String; Virtual; {Get users name}
  Procedure SetUserName(NStr: String); Virtual; {Set users name}
  Function  GetUserCity: String; Virtual; {Get users city}
  Procedure SetUserCity(CStr: String); Virtual; {Set users city}
  Function  GetUserPwd: String; Virtual; {Get users password}
  Procedure SetUserPwd(PwdStr: String); Virtual; {Set users password}
  Function  GetUserDataPhone: String; Virtual; {Get users data phone}
  Procedure SetUserDataPhone(Phone: String); Virtual; {Set users data phone}
  Function  GetUserVoicePhone: String; Virtual; {Get users voice phone}
  Procedure SetUserVoicePhone(Voice: String); Virtual; {Set users voice phone}
  Function  GetUserCredit: LongInt; Virtual; {Get users netmail credit}
  Procedure SetUserCredit(Credit: LongInt); Virtual; {Set users netmail credit}
  Function  GetUserPending: LongInt; Virtual; {Get users pending netmail cost}
  Procedure SetUserPending(Pending: LongInt); Virtual; {Set users pending cost}
  Function  GetUserScrLength: Word; Virtual; {Get users screen length}
  Procedure SetUserScrLength(Scr: Word); Virtual; {Set users screen length}
  Function  GetUserMsgsEntered: LongInt; Virtual; {Get number of msgs entered}
  Procedure SetUserMsgsEntered(MsgE: LongInt); Virtual; {Set nbr of msgs entered}
  Function  GetUserTimesCalled: Word; Virtual; {Get number of times called}
  Procedure SetUserTimesCalled(Calls: Word); Virtual; {Set nbr of times called}
  Function  GetUserTodayBytes: LongInt; Virtual; {Get net transfers today}
  Procedure SetUserTodayBytes(TK: LongInt); Virtual; {Set net transfers today}
  Function  GetUserULBytes: LongInt; Virtual; {Get uploaded}
  Procedure SetUserULBytes(TK: LongInt); Virtual; {Set uploaded}
  Function  GetUserDLBytes: LongInt; Virtual; {Get downloaded}
  Procedure SetUserDLBytes(TK: LongInt); Virtual; {Set downloaded}
  Function  GetUserULFiles: LongInt; Virtual; {Get Num Files uploaded}
  Procedure SetUserULFiles (TK: LongInt); Virtual; {Set Num Files uploaded}
  Function  GetUserDLFiles: LongInt; Virtual; {Get Num Files downloaded}
  Procedure SetUserDLFiles (TK: LongInt); Virtual; {Set Num Files downloaded}
  Function  GetUserElapsed: Integer; Virtual; {Get Elapsed time prior calls today}
  Procedure SetUserElapsed (TK: Integer); Virtual; {Set Elapsed time}
  Procedure GetUserLastCall(Var LD: MKDateTime); Virtual; {Get user last called date}
  Procedure SetUserLastCall(Var LD: MKDateTime); Virtual; {Set last called date}
  Procedure GetUserNewFileDate(Var DT: MKDateTime); Virtual; {Get user new file search date}
  Procedure SetUserNewFileDate(DT: MKDateTime); Virtual; {Set user new file search date}
  Function  GetUserGraphics: LongInt; Virtual; {Get user graphics capability}
  Procedure SetUserGraphics(UG: LongInt); Virtual; {Set user graphics}
  Function  GetUserAvatar: Boolean; Virtual; {Get avatar setting}
  Procedure SetUserAvatar(AV: Boolean); Virtual; {Set user avatar}
  Function  GetUserFullEd: Boolean; Virtual; {Get full-screen editor setting}
  Procedure SetUserFullEd(FE: Boolean); Virtual; {Set full-screen editor setting}
  Function  GetUserMore: Boolean; Virtual; {Get ask more setting}
  Procedure SetUserMore(Mo: Boolean); Virtual; {Set ask more setting}
  Function  GetUserScrnClr: Boolean; Virtual; {Get screen clear setting}
  Procedure SetUserScrnClr(Cl: Boolean); Virtual; {Set screen clear setting}
  Function  GetUserAnsi: Boolean; Virtual; {Get ansi setting}
  Procedure SetUserAnsi(UA: Boolean); Virtual; {Set user ansi}
  Function  GetUserLanguage: Byte; Virtual; {Get user lang number}
  Procedure SetUserLanguage(Ln: Byte); Virtual; {Set user lang number}
  Function  GetUserBaud: LongInt; Virtual; {Get user baud rate}
  Procedure SetUserBaud(Bd: LongInt); Virtual; {Set user baud rate}
  Function  GetUserMsgTemplate: Word; Virtual; {Get user msg template area}
  Procedure SetUserMsgTemplate(Tm: Word); Virtual; {Set user msg template area}
  Function  GetUserFileTemplate: Word; Virtual; {Get user file template area}
  Procedure SetUserFileTemplate(Tm: Word); Virtual; {Set user file template area}
  Function  GetUserDoorTemplate: Word; Virtual; {Get user door template area}
  Procedure SetUserDoorTemplate(Tm: Word); Virtual; {Set user door template area}
  Function  GetUserPageTimes: Word; Virtual; {Get number of times has paged}
  Procedure SetUserPageTimes(Pg: Word); Virtual; {Set number of times has paged}
  Function  GetUserTimeLimit: Integer; Virtual; {Get user time limit}
  Procedure SetUserTimeLimit(TL: Word); Virtual; {Set user time limit}
  Function  GetUserDLLimit: LongInt; Virtual; {Get user DL limit}
  Procedure SetUserDLLimit(DL: LongInt); Virtual; {Set user DL limit}
  Function  GetUserHandle: String; Virtual; {Get users handle}
  Procedure SetUserHandle(Hd: String); Virtual; {Set users handle}
  Function  GetUserPageTune: Byte; Virtual; {Get user page tune}
  Procedure SetUserPageTune(Tune: Byte); Virtual; {Set user page tune}
  Procedure GetUserBirthDate(Var BD: MKDateType); Virtual; {Get user birthdate MM-DD-YY}
  Procedure SetUserBirthDate(Var BD: MKDateType); Virtual; {Set user birthdate MM-DD-YY}
  Procedure GetUserFirstDate(Var FD: MKDateType); Virtual; {Get user first call MM-DD-YY}
  Procedure SetUserFirstDate(Var FD: MKDateType); {Set user first call MM-DD-YY}
  Function  GetUserCombined(Area: Word): Boolean; Virtual; {Get user combined setting}
  Procedure SetUserCombined(Area: Word; St: Boolean); Virtual; {Set user combined}
  Procedure ClearGoSub; Virtual; {Clear gosub menu stack}
  Procedure GoSub(MN: String); Virtual; {Add MenuName MN to gosub stack}
  Function  GoSubReturn: String; Virtual; {Return MenuName from gosub stack}
  Function  GetUserRecNum: Word; Virtual; {Get user record number}
  Function  GetSessionTimeLimit: LongInt; Virtual; {Seconds this call allowed}
  Procedure SetSessionTimeLimit(TL: LongInt); Virtual; {Seconds allowed this call}
  Procedure SetStartTime; Virtual; {Set start time}
  Procedure UpdateForMsg; Virtual; {Increment msgs posted count}
  Procedure UpdateForDL(FSize: LongInt); Virtual; {Increment DL count and update K}
  Procedure UpdateForUL(FSize: LongInt); Virtual; {Increment UL count and update K}
  Function  UserIsLoaded: Boolean; Virtual;
  Procedure PostStatus(Status: Byte; SM: String); Virtual;
  Function  GetUserNumber: LongInt; Virtual;
  Function  GetUserProt: Char;  Virtual; {Get user default protocol}
  Procedure SetUserProt(PT: Char); Virtual; {Set user default protocol}
  Function  GetUserPacker: Char; Virtual; {Get user default packer}
  Procedure SetUserPacker(PT: Char); Virtual; {Set user default packer}
  Function  LocalKeyPressed: Boolean; Virtual;
  Function  LocalReadKey: Char; Virtual;
  Procedure SetUserFileName(UFN: String); Virtual;
  Function  GetPrompt(PN: Word): String; Virtual;
  Procedure SendPrompt(PN: Word); Virtual;
  Procedure SendPromptLN(PN: Word); Virtual;
  End;


Type AbsUsrObjPtr = ^AbsUsrObj;

Implementation

Uses
  {$IFDEF WINDOWS}
  MKWCrt,
  {$ELSE}
    {$IFDEF OPRO}
    OpCrt,
    {$ELSE}
    Crt,
    {$ENDIF}
    MKScrn,
  {$ENDIF}
  MKString, MKFile, MKAvatar, MKMisc, MKDos, MKCfgAbs,
  {$IFDEF WINDOWS}
  Strings;
  {$ELSE}
  ExecAcc;
  {$ENDIF}


Const
  ExtraKey: Char = #0;
  ExtraWaiting: Boolean = False;


Function AbsUsrObj.LocalKeyPressed: Boolean;
  Begin
  If Sem <> Nil Then
    LocalKeyPressed := KeyPressed or Sem^.KeyPressed or ExtraWaiting
  Else
    LocalKeyPressed := KeyPressed or ExtraWaiting;
  End;


Function AbsUsrObj.LocalReadKey: Char;
  Var
    KeyFound: Boolean;

  Begin
  If Not ExtraWaiting Then
    Begin
    KeyFound := False;
    While Not KeyFound Do
      Begin
      If KeyPressed Then
        Begin
        ExtraKey := ReadKey;
        LocalReadKey := ExtraKey;
        If ExtraKey = #0 Then
          Begin
          ExtraWaiting := True;
          ExtraKey := ReadKey;
          End;
        KeyFound := True;
        End
      Else
        If Sem <> Nil Then
          Begin
          If Sem^.KeyPressed Then
            Begin
            LocalReadKey := Sem^.ReadKey;
            KeyFound := True;
            End;
          End;
      End;
    End
  Else
    Begin
    LocalReadKey := ExtraKey;
    ExtraWaiting := False;
    End;
  End;


Function AbsUsrObj.GetUserNumber: LongInt;
  Begin
  End;


Procedure AbsUsrObj.SetMore(More: Boolean);
  Begin
  UserInfo^.DoMore := More;
  End;


Function AbsUsrObj.GetMore: Boolean;    {Will more prompts be done?}
  Begin
  GetMore := UserInfo^.DoMore;
  End;


Function AbsUsrObj.StopMore: Boolean;   {More? answer of NO}
  Begin
  StopMore := UserInfo^.StopMore;
  End;


Procedure AbsUsrObj.ResetLines(Ct: Word); {Reset more line count}
  Begin
  UserInfo^.CurrLines := Ct;
  End;


Procedure AbsUsrObj.SetStopMore(St: Boolean);
  Begin
  UserInfo^.StopMore := St;
  End;


Procedure AbsUsrObj.ClearScreen;
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


Procedure AbsUsrObj.ClrEOL;
  Begin
  If GetUserAvatar Then
    DisplayStr('')
  Else
    If GetUserAnsi Then
      DisplayStr('[K');
  End;


Procedure AbsUsrObj.SetComPtr(cm: AbsComPtr);
  Begin
  Comm := cm;
  End;


Procedure AbsUsrObj.SetStrPtr(sp: StrObjPtr);
  Begin
  Prompts := Sp;
  End;


Procedure AbsUsrObj.SetSemPtr(sp: RemoteCheckPtr);
  Begin
  Sem := sp;
  End;


Function AbsUsrObj.CurrentTime: LongInt; {Seconds since midnight of Log-On date}
  Var
    P: ^LongInt;
    Temp: LongInt;
    Year: Word;
    Month: Word;
    Day: Word;
    TempDay: Word;
    DOW: Word;

  Begin
  GetDate(Year,Month,Day,DOW);
  P := Ptr ($40,$6C);
  Temp := (10 * (P^) Div 182);       {Temp is ticks since midnight / 18.2}
  GetDate(Year,Month,TempDay,DOW);
  If TempDay <> Day Then             {If Day changed get time again}
    Temp := (10 * (P^) Div 182);
  If UserInfo^.StartDay <>  Day Then {If Date doesn't match logon date}
    Inc(Temp,86400);                 {increase by 24hrs * 60min * 60sec}
  CurrentTime := Temp;
  End;


Procedure AbsUsrObj.AdjustTime(Adj: LongInt);
  Begin
  UserInfo^.TimeLimit := UserInfo^.TimeLimit + Adj;
  End;


Function AbsUsrObj.GetCurrentDay: Word;
  Var
    Year: Word;
    Month: Word;
    DOW: Word;
    Day: Word;

  Begin
  GetDate(Year, Month, Day, DOW);
  GetCurrentDay := Day;
  End;


Procedure AbsUsrObj.SetTimeOut;
  Begin
  UserInfo^.IdleWarn := False;
  UserInfo^.IdleLimit := CurrentTime + UserInfo^.IdleTime;
  End;


Procedure AbsUsrObj.SetIdleTimeLimit(ITL: Word);
  Begin
  UserInfo^.IdleTime := ITL;
  End;


Function AbsUsrObj.TimeRemain: LongInt;          {Seconds remaining}
  Var
    TempTime: LongInt;

  Begin
  TempTime := UserInfo^.TimeLimit + UserInfo^.StartTime - CurrentTime;
  If UserInfo^.Chat Then
    TimeRemain := TempTime + (CurrentTime - UserInfo^.ChatStart)
  Else
    TimeRemain := TempTime;
  End;



Function AbsUsrObj.GetUserSecondsOn: Word;    {Get seconds user has beeen connected}
  Begin
  GetUserSecondsOn := CurrentTime - UserInfo^.StartTime;
  End;


Procedure AbsUsrObj.TimeWarn;
  Var
    TempTime: LongInt;

  Begin
  TempTime := TimeRemain;
  If TempTime < 60 Then
    Begin
    If Not UserInfo^.OneMinWarn Then
      Begin
      UserInfo^.OneMinWarn := True;
      DisplayStrLn(Prompts^.GetString(97));
      End;
    End
  Else
    If TempTime < 120 Then
      If Not UserInfo^.TwoMinWarn Then
        Begin
        UserInfo^.TwoMinWarn := True;
        DisplayStrLn(Prompts^.GetString(98));
        End;
  End;


Function AbsUsrObj.OkTime: Boolean;              {False if Time Limit exceeded}
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


Function  AbsUsrObj.OK: Boolean;        {After CheckInput is all ok?}
  Begin
  Ok := UserInfo^.Ok;
  End;


Procedure AbsUsrObj.SetOk(St: Boolean); {Set ok to false}
  Begin
  UserInfo^.Ok := St;
  UserInfo^.NotOkReason := 1;
  End;

Function AbsUsrObj.GetStatusType: Byte;
  Begin
  GetStatusType := UserInfo^.StatType;
  End;


Procedure AbsUsrObj.SetStatusType(ST:Byte); {Set current status display type}
  Begin
  UserInfo^.StatType := ST;
  StatusDisplay(ST);
  End;


Function AbsUsrObj.GetChatReason: String;
  Begin
  GetChatReason := UserInfo^.ChatReason;
  End;


Procedure AbsUsrObj.SetChatReason(Reason: String);
  Begin
  UserInfo^.ChatReason := Copy(Reason, 1, 50);
  End;


Procedure AbsUsrObj.StatusDisplay(StatusType: Byte);
  Type  ByteArray = Array[1..4] of Byte;
  Var
    TempX: Byte;
    TempY: Byte;
    TempAttr: Byte;
    Sec: Pointer;

  Begin
    TempX := WhereX;
    TempY := WhereY;
    TempAttr := TextAttr;
    Window(1, ScrnHeight - 1, ScrnWidth, ScrnHeight);
    TextAttr := LightGray Shl 4;
    ClrScr;
    Case StatusType Of
      1:Begin
        GoToXy(1,1);
        Write(' ', GetUserName,' from ', GetUserCity,
          ' at ',  GetUserBaud, ' Baud');
        GoToXy(1,2);
        Write('  Time: ', TimeRemain div 60, ' Minutes                               (F9)= Help');
        If GetUserAnsi Then
          Begin
          GoToXy(38,2);
          Write('(Ansi)');
          End;
        If GetUserAvatar Then
          Begin
          GoToXy(48,2);
          Write('(Avatar)');
          End;
        End;
      2:Begin
        GoToXy(1,1);
        Write(' Voice# ',PadRight(GetUserVoicePhone,' ',15));
        GoToXy(1,2);
        Write(' Data # ' + PadRight(GetUserDataPhone, ' ', 15));
        Write('Times Called ', GetUserTimesCalled);
        End;
      3:Begin
        GoToXy(1,1);
        Write(' Uploads ', GetUserULBytes, ', ');
        Write(GetUserULFiles, ' Files');
        GoToXy(40,1);
        Write('Downloads ', GetUserDLBytes,', ');
        Write(GetUserDLFiles, ' Files');
        GoToXy(1,2);
        End;
      4:;
      5: Begin
         GoToXy(1,1);
         Write(' Msgs Posted: ', GetUserMsgsEntered);
         GoToXy(1,2);
         Write(' NetMail Credit: ', GetUserCredit);
         Write('    Pending: ', GetUserPending);
         End;
      6: Begin
         GoToXy(1,1);
         Write(' Choose (C)hat or (A)bort Page  /  (ALT-C) Chat without Page  BD=');
         GoToXy(1,2);
         Write(' Chat Reason: ', GetChatReason);
         End;
      7: Begin
         GoToXy(1,1);
         Write(BBSVersion);
         GoToXy(1,2);
         Write(Comm^.GetCommInfo);
         End;
      9:Begin
        GoToXy(1,1);
        Write(' Alt-H=HangUp   Alt-C=Chat  Alt-J=Jump To Dos   =Adjust Time ');
        GoToXy(1,2);
        Write(' F1=Normal F2=Call Data F3=Xfer Data F5=Msg Data F6=Chat Info F9=Help');
        End;
      End;
    Window (1, 1, ScrnWidth, ScrnHeight - 2);
    TextAttr := TempAttr;
    GoToXY(TempX, TempY);
  End;


Procedure AbsUsrObj.SetCurrentPort(CP: Word);
  Begin
  UserInfo^.CurrentPort := CP;
  End;


Procedure AbsUsrObj.CheckInput;
  Begin
  If Not OkTime Then
    Begin
    UserInfo^.Ok := False;
    UserInfo^.NotOkReason := 2;
    End;
  If (UserInfo^.CurrentPort <> 0) Then
    If (Not Comm^.GetCarrier) Then
      Begin
      UserInfo^.Ok := False;
      UserInfo^.NotOkReason := 3;
      End;
  End;


Procedure AbsUsrObj.CheckIdle;
  Begin
  If UserInfo^.IdleTime <> 0 Then
    Begin
    If ((Not UserInfo^.IdleWarn) and
    ((UserInfo^.IdleLimit - CurrentTime) < 30)) Then
      Begin
      UserInfo^.IdleWarn := True;
      DisplayAttr(White);
      DisplayNewLine;
      DisplayStrLn(Prompts^.GetString(99));
      DisplayNewLine;
      End;
    If UserInfo^.IdleLimit <= CurrentTime Then
      Begin
      UserInfo^.Ok := False;
      UserInfo^.NotOkReason := 4;
      End;
    End;
  End;


Function AbsUsrObj.CheckHot(HotStr: String): Char;
  Var
    TChar: Char;

  Begin
  CheckHot := #0;
  If InputChr(TChar) Then
    Begin
    TChar := UpCase(TChar);
    If (Pos(TChar, HotStr) > 0) Then
      CheckHot := TChar;
    End;
  End;


Procedure AbsUsrObj.DisplayChr (OutChr:Char);
  Var
    CharWait: LongInt;

  Begin
  If UserInfo^.CurrentPort > 0 Then
    Begin
    If Not Comm^.SendCharNw(OutChr) Then
      Begin
      CharWait := CurrentTime + UserInfo^.IdleTime;
      While ((Not Comm^.SendCharNw(OutChr)) and UserInfo^.OK And
      (CurrentTime <= CharWait)) Do
        CheckInput;
      If ((UserInfo^.CurrentPort > 0) and (CurrentTime > CharWait)) Then
        Begin
        UserInfo^.Ok := False;
        UserInfo^.NotOkReason := 5;
        End;
      End;
    End;
  AvatarChar(OutChr);
  If Sem <> Nil Then
    Sem^.SendChar(OutChr);
  End;


Procedure AbsUsrObj.DisplayStr (OutStr:String);
  Var
    i: Integer;

  Begin
  i := 1;
  While ((i <= Length(OutStr)) and UserInfo^.Ok) Do
    Begin
    If UserInfo^.CurrentPort > 0 Then
      While ((Not Comm^.SendCharNw(OutStr[i])) and UserInfo^.OK) Do
        CheckInput;
    AvatarChar(OutStr[I]);
    Inc(I);
    End;
  If Sem <> Nil Then
    Sem^.SendStr(OutStr);
  End;


Procedure AbsUsrObj.TimeOver;
  Begin
  If Not UserInfo^.TimeOverWarn Then
    Begin
    UserInfo^.TimeOverWarn := True;
    DisplayStrLn(Prompts^.GetString(96));
    End;
  End;


Procedure AbsUsrObj.CheckMore;
  Begin
  Inc(UserInfo^.CurrLines);
  If UserInfo^.CurrLines >= UserInfo^.ScrnLen Then
    Begin
    If Not OkTime Then
      TimeOver;
    If GetUserMore Then
      AskMore;
    End;
  End;


Procedure AbsUsrObj.AnsiChat;
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
  DisplayStrLn(Prompts^.GetString(78));
  DisplayNewLine;
  ChatDone := False;
  ChatPos := 0;
  While ((Not ChatDone) and Comm^.GetCarrier) Do
    Begin
    If LocalKeyPressed Then
      Begin
      ChChar := LocalReadKey;
      Case ChChar of
        #000: Begin
              ChChar := LocalReadkey;
              If ChChar <> #46 Then
                LocalCommand(ChChar);
              End;
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
    If Not Comm^.InEmpty Then
      Begin
      ChChar := Comm^.GetChar;
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
  DisplayStrLn(Prompts^.GetString(79));
  DisplayNewLine;
  If GetUserAnsi Then
    ClearScreen
  Else
    Begin
    DisplayNewLine;
    DisplayNewLine;
    End;
  End;


Procedure AbsUsrObj.AvatarChat;
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
  DisplayStr(Prompts^.GetString(105));
  DisplayAttr(SysopAttr);
  DisplayStr('' + Chr(SysopBeg - 2) + Chr(35));
  DisplayStr(Prompts^.GetString(106));
  DisplayStr('' + Chr(SysopBeg) + Chr(1));
  ChatDone := False;
  SysopX := 1;
  SysopY := SysopBeg;
  CallerX := 1;
  CallerY := CallerBeg;
  While ((Not ChatDone) and Comm^.GetCarrier) Do
    Begin
    If LocalKeyPressed Then
      Begin
      DisplayStr('' + Chr(SysopY) + Chr(SysopX));
      DisplayAttr(SysopAttr);
      ChChar := LocalReadKey;
      Case ChChar of
        #000: Begin
              ChChar := LocalReadkey;
              If ChChar <> #46 Then
                LocalCommand(ChChar);
              End;
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
    If Not Comm^.InEmpty Then
      Begin
      DisplayStr('' + Chr(CallerY) + Chr(CallerX));
      DisplayAttr(CallerAttr);
      ChChar := Comm^.GetChar;
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
  DisplayStrLn(Prompts^.GetString(79));
  End;


Procedure AbsUsrObj.AdjustUserTime(TA: LongInt); {adjust user time remain by ta}
  Begin
  UserInfo^.TimeLimit := UserInfo^.TimeLimit + TA;
  End;


Procedure AbsUsrObj.DoChat;
  Begin
  If UserInfo^.CurrentPort <> 0 Then
    Begin
    UserInfo^.Chat := True;
    PostStatus(uoChat,'Chat');
    UserInfo^.ChatStart := CurrentTime;
    If GetUserAvatar Then
      AvatarChat
    Else
      AnsiChat;
    AdjustUserTime(CurrentTime - UserInfo^.ChatStart);
    UserInfo^.Chat := False;
    End
  Else
    Begin
    DisplayNewLine;
    DisplayNewLine;
    DisplayStrLn(Prompts^.GetString(100));
    DisplayNewLine;
    PressEnter;
    End;
  End;


Procedure AbsUsrObj.DisplayNewLine;
  Begin
  DisplayChr(#13);
  DisplayChr(#10);
  CheckMore;
  If OkTime Then;
  End;


Procedure AbsUsrObj.DisplayStrLn (OutStr:String);
  Begin
  DisplayStr(OutStr);
  DisplayNewLine;
  End;


Procedure AbsUsrObj.DisplayCenterStrLn(OutStr: String);
  Begin
  If Length(OutStr) < 79 Then
    DisplayStr(PadRight('',' ',(80 - Length(OutStr)) Div 2));
  DisplayStrLn(OutStr);
  End;


Procedure AbsUsrObj.LocalCommand(CommandChar:Char);
  Var
    i: Integer;
    CDirStr: String;
    SaveBuf: Pointer;
    Tx, Ty, Ta: Byte;
    SwapResult: Integer;

  Begin
  Case CommandChar of
    #035: Begin {Alt-H}
          UserInfo^.Ok := False;
          UserInfo^.NotOkReason := 6;
          Comm^.LowerDtr;
          Delay(500);
          Comm^.RaiseDtr;
          End;
    #036: Begin {Alt-J}
          Comm^.ClosePort;
          DoShell(GetEnv('COMSPEC'), True);
          Comm^.CommResume;
          Comm^.SetFlowCtl(fcHard);
          SetTimeOut;
          End;
    #046: Begin {Alt-C}
          DoChat;
          SetTimeOut;
          End;
    #059: Begin {F1}
          UserInfo^.StatType := 1;
          StatusDisplay(UserInfo^.StatType);
          End;
    #060: Begin {F2}
          UserInfo^.StatType := 2;
          StatusDisplay(UserInfo^.StatType);
          End;
    #061: Begin {F3}
          UserInfo^.StatType := 3;
          StatusDisplay(UserInfo^.StatType);
          End;
    #062: Begin {F4}
          UserInfo^.StatType := 4;
          StatusDisplay(UserInfo^.StatType);
          End;
    #063: Begin {F5}
          UserInfo^.StatType := 5;
          StatusDisplay(UserInfo^.StatType);
          End;
    #064: Begin {F6}
          UserInfo^.StatType := 6;
          StatusDisplay(UserInfo^.StatType);
          End;
    #065: Begin {F7}
          UserInfo^.StatType := 7;
          StatusDisplay(UserInfo^.StatType);
          End;
    #065: Begin {F8}
          UserInfo^.StatType := 8;
          StatusDisplay(UserInfo^.StatType);
          End;
    #067: Begin {F9}
          UserInfo^.StatType := 9;
          StatusDisplay(UserInfo^.StatType);
          End;
    #072: Begin
          AdjustUserTime(60);
          StatusDisplay(UserInfo^.StatType);
          End;
    #080: Begin
          AdjustUserTime(-60);
          StatusDisplay(UserInfo^.StatType);
          End;
    End;
  End;


Procedure AbsUsrObj.DetectAnsi; {Detect ansi}
  Var
    STime: LongInt;
    Finished: Boolean;
    Ch: Char;

  Begin
  If UserInfo^.CurrentPort = 0 Then
    UserInfo^.AnsiDet := True
  Else
    Begin
    UserInfo^.AnsiDet := False;
    DisplayStr(#27 + '[6n');
    Comm^.FlushIn;
    STime := CurrentTime;
    Inc(STime, 1);
    Finished := False;
    While (CurrentTime <= STime) and (Not Finished) Do
      Begin
      If Not Comm^.InEmpty Then
        Begin
        Ch := Comm^.GetChar;
         If (Ch in [#27,'0'..'9','[','H']) then
           Begin
           UserInfo^.AnsiDet := True;
           Finished := True;
           End;
        End;
      End;
    Delay(250);
    Comm^.FlushIn;
    End;
  End;


Function AbsUsrObj.WasAnsiDetected: Boolean;
  Begin
  WasAnsiDetected := UserInfo^.AnsiDet;
  End;


Function AbsUsrObj.InputChr(Var Ch:Char): Boolean;
  Begin
  InputChr := False;
  If LocalKeyPressed Then
    Begin
    SetTimeOut;
    Ch := LocalReadKey;
    If Ch = #0 Then
      LocalCommand(LocalReadKey)
    Else
      Begin
      InputChr := True;
      End;
    End
  Else
    Begin
    If ((UserInfo^.CurrentPort <> 0) and (Not Comm^.InEmpty)) Then
      Begin
      InputChr := True;
      Ch := Comm^.GetChar;
      SetTimeOut;
      End
    Else
      Begin
      {$IFDEF WINDOWS}
      If PeekMessage(Message, HWindow, 0, 0, pm_NoRemove) Then
        Begin
        GetMessage(Message, HWindow, 0, 0);
        TranslateMessage(Message);
        DispatchMessage(Message);
        End;
      {$ENDIF}
      End;
    End;
  End;


Procedure AbsUsrObj.WaitEnter;
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


Procedure AbsUsrObj.PressEnter;
  Var
    TmpChr: Char;

  Begin
  If (UserInfo^.CurrentPort > 0) Then
    Begin
    While ((Not Comm^.OutEmpty) and UserInfo^.Ok) Do
      Begin
      CheckInput;
      If CheckHot(' ') = ' ' Then
        Comm^.FlushOut;
      End;
    End;
  UserInfo^.CurrLines := 1;
  DisplayAttr(Config^.GetSystemColor(1));
  DisplayStr(Prompts^.GetString(6));
  WaitEnter;
  DisplayNewLine;
  End;


Procedure AbsUsrObj.DisplayColor(Fr:Byte;Br:Byte);
  Begin
  If GetUserAvatar Then
    DisplayStr(''+Chr(Fr + (Br shl 4)))
  Else
    If GetUserAnsi Then
      DisplayStr(AnsiColor(Fr,Br));
  End;


Function AbsUsrObj.GetAttrStr(Attr:Byte): String;
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


Procedure AbsUsrObj.DisplayAttr(Attr:Byte);
  Begin
  If GetUserAvatar Then
    DisplayStr('' + Chr(Attr))
  Else
    If GetUserAnsi Then
      DisplayColor(Attr and 15, Attr Shr 4);
  End;



Procedure AbsUsrObj.DisplayBkSpc;       {Display backspace}
  Begin
  DisplayChr(#8);
  DisplayChr(' ');
  DisplayChr(#8);
  End;


Procedure AbsUsrObj.DisplayFile(FileName: String);

  Var
    AFile: File;
    TempChar: Char;
    Buffer: Array[1..256] of Char;
    I: Word;
    NumRead: Word;
    Found: Boolean;
    Ext: String[4];
    TmpStr: String;

  Begin
  StatusDisplay(UserInfo^.StatType);
  If Not shAssign (Afile,FileName) Then;
  FileMode := fmReadOnly + fmDenyNone;
  If shReset (Afile,1) Then
    Begin
    While ((Not Eof(Afile)) and UserInfo^.OK) Do
      Begin
      BlockRead(Afile,Buffer, 255, NumRead);
      If IoResult <> 0 Then
        WriteLn('Error reading TxtFile');
      i := 1;
      While i <= NumRead Do
        Begin
        If (UserInfo^.CurrentPort > 0) Then
          While ((Not Comm^.SendCharNw(Buffer[i])) and UserInfo^.Ok) Do
            Begin
            CheckInput;
            If CheckHot(' ') = ' ' Then
              Comm^.FlushOut;
            End;
        AvatarChar(Buffer[i]);
        Inc(i);
        End;
      Move(TmpStr[1], Buffer, NumRead);
      TmpStr[0] := Chr(NumRead);
      If Sem <> Nil Then
        Sem^.SendStr(TmpStr);
      End;
    Close(Afile);
    If IoResult <> 0 Then
      WriteLn('Error closing TxtFile');
    End
  Else
    WriteLn('Cannot Open TxtFile ' + FileName);
  End;


Function AbsUsrObj.DisplayHotFile(FileName: String; HotStr: String): Char;
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
    TmpStr: String;

  Begin
  HotStop := False;
  StatusDisplay(UserInfo^.StatType);
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
          WriteLn('Error reading TxtFile');
        i := 1;
        While i <= NumRead Do
          Begin
          If (UserInfo^.CurrentPort > 0) Then
            While ((Not Comm^.SendCharNw(Buffer[i])) and UserInfo^.Ok) Do
              Begin
              CheckInput;
              End;
          AvatarChar(Buffer[i]);
          Inc(i);
          End;
        Move(TmpStr[1], Buffer, NumRead);
        TmpStr[0] := Chr(NumRead);
        If Sem <> Nil Then
          Sem^.SendStr(TmpStr);
        End;
      End;
    Close(Afile);
    If IoResult <> 0 Then
      WriteLn('Error closing TxtFile');
    If HotStop Then
      DisplayHotFile := IChr
    Else
      DisplayHotFile := #0;
    End
  Else
    WriteLn('Cannot Open TxtFile ' + FileName);
  End;



Procedure AbsUsrObj.Askmore;
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
  If UserInfo^.CurrentPort > 0 Then
    While ((Not Comm^.OutEmpty) and UserInfo^.Ok) Do
      Begin
      CheckInput;
      If CheckHot(' ') = ' ' Then
        Comm^.FlushOut;
      End;
  ResetLines(1);
  If UserInfo^.DoMore Then
    Begin
    origfore := textattr and 15;
    origback := textattr shr 4;
    DisplayAttr (White);
    DisplayStr (Prompts^.GetString(7));
    Displaycolor (origfore,origback);
    valid := false;
    SetTimeOut;
    CmdStr := Copy(Prompts^.GetString(1),1,1) +
      Copy(Prompts^.GetString(2),1,1) +
      Copy(Prompts^.GetString(11),1,1) + #13;
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
    While i <= Length(Prompts^.GetString(7)) Do
      Begin
      Inc(i);
      DisplayBkSpc;
      End;
    End;
  End;


Function AbsUsrObj.InputStr (InStr:String;MaxLen:Byte): String;
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


Function AbsUsrObj.InputProper(MaxLen: Byte): String;
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




Procedure AbsUsrObj.WWInputStr (Var Str:String; Var Extra: String;
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


Function AbsUsrObj.InputPwd (MaxLen:Byte): String;
  Var
    ChrCnt: Byte;
    InDone: Boolean;
    TmpChr: Char;
    InStr: String;
    PwdChr: Char;

  Begin
  PwdChr := Prompts^.GetChar(20);
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


Constructor AbsUsrObj.Init;
  Begin
  New(UserInfo);
  UserInfo^.UserLoaded := False;
  UserInfo^.Ok := True;
  UserInfo^.NotOkReason := 0;
  UserInfo^.Tagging := False;
  UserInfo^.CurrLines := 0;
  UserInfo^.ScrnLen := 24;
  UserInfo^.StopMore := False;
  UserInfo^.DoMore := True;
  UserInfo^.TwoMinWarn := False;
  UserInfo^.OneMinWarn := False;
  UserInfo^.TimeOverWarn := False;
  UserInfo^.Chat := False;
  UserInfo^.IdleTime := 180;
  UserInfo^.StatType := 1;
  UserInfo^.TimeLimit := 3600;
  UserInfo^.StartDay := GetCurrentDay;
  UserInfo^.StartTime := CurrentTime;
  UserInfo^.LineNum := 1;
  UserInfo^.ChatReason := '';
  UserInfo^.MsgsToday := 0;
  UserInfo^.DLToday := 0;
  UserInfo^.ULToday := 0;
  UserInfo^.AnsiDet := False;
  Sem := Nil;
  Prompts := Nil;
  End;


Destructor AbsUsrObj.Done;
  Begin
  If UserInfo^.CurrentPort > 0 Then
  Dispose(UserInfo);
  End;


Procedure AbsUsrObj.ReadUser;
  Begin
  End;


Procedure AbsUsrObj.WriteUser;
  Begin
  End;


Procedure AbsUsrObj.AddUser;
  Begin
  End;


Procedure AbsUsrObj.GetUserPos(Name: String);
  Begin
  End;



Function AbsUsrObj.UserFound: Boolean;          {Returns user found?}
  Begin
  UserFound := False;
  End;


Procedure AbsUsrObj.ReadExit(EPath: String);
  Begin
  End;


Procedure AbsUsrObj.WriteExit(EPath: String);
  Begin
  End;


Procedure AbsUsrObj.GetUserSec(Sec: Pointer); {Get user security level/flags}
  Begin
  End;



Procedure AbsUsrObj.SetUserSec(Sec: Pointer);
  Begin
  End;


Function AbsUsrObj.GetUserSecLevel: LongInt;
  Begin
  GetUserSecLevel := 0;
  End;


Function AbsUsrObj.GetUserSecStr: String;
  Begin
  GetUserSecStr := '';
  End;


Function AbsUsrObj.GetUserLineNum: Word;
  Begin
  GetUserLineNum := UserInfo^.LineNum;
  End;


Procedure AbsUsrObj.SetUserLineNum(Ln: Word);
  Begin
  UserInfo^.LineNum := Ln;
  End;


Function AbsUsrObj.GetUserName: String;       {Get users name}
  Begin
  End;


Procedure AbsUsrObj.SetUserName(NStr: String); {Set users name}
  Begin
  End;


Function AbsUsrObj.GetUserCity: String;       {Get users city}
  Begin
  End;


Procedure AbsUsrObj.SetUserCity(CStr: String); {Set users city}
  Begin
  End;


Function AbsUsrObj.GetUserPwd: String;        {Get users password}
  Begin
  End;


Procedure AbsUsrObj.SetUserPwd(PwdStr: String);{Set users password}
  Begin
  End;


Function AbsUsrObj.GetUserDataPhone: String;  {Get users data phone}
  Begin
  End;


Procedure AbsUsrObj.SetUserDataPhone(Phone: String); {Set users data phone}
  Begin
  End;


Function AbsUsrObj.GetUserVoicePhone: String; {Get users voice phone}
  Begin
  End;


Procedure AbsUsrObj.SetUserVoicePhone(Voice: String); {Set users voice phone}
  Begin
  End;


Function AbsUsrObj.GetUserCredit: LongInt;    {Get users netmail credit}
  Begin
  End;


Procedure AbsUsrObj.SetUserCredit(Credit: LongInt); {Set users netmail credit}
  Begin
  End;


Function AbsUsrObj.GetUserPending: LongInt;   {Get users pending netmail cost}
  Begin
  End;


Procedure AbsUsrObj.SetUserPending(Pending: LongInt); {Set users pending cost}
  Begin
  End;


Function AbsUsrObj.GetUserScrLength: Word;    {Get users screen length}
  Begin
  End;


Procedure AbsUsrObj.SetUserScrLength(Scr: Word); {Set users screen length}
  Begin
  End;

Function AbsUsrObj.GetUserMsgsEntered: LongInt;  {Get number of msgs entered}
  Begin
  End;


Procedure AbsUsrObj.SetUserMsgsEntered(MsgE: LongInt); {Set nbr of msgs entered}
  Begin
  End;


Function AbsUsrObj.GetUserTimesCalled: Word;  {Get number of times called}
  Begin
  End;


Procedure AbsUsrObj.SetUserTimesCalled(Calls: Word); {Set nbr of times called}
  Begin
  End;


Function  AbsUsrObj.GetUserTodayBytes: LongInt;
  Begin
  End;


Procedure AbsUsrObj.SetUserTodayBytes (TK: LongInt);
  Begin
  End;


Function AbsUsrObj.GetUserULBytes: LongInt;
  Begin
  End;


Procedure AbsUsrObj.SetUserULBytes(TK: LongInt);
  Begin
  End;


Function AbsUsrObj.GetUserDLBytes: LongInt;
  Begin
  End;


Procedure AbsUsrObj.SetUserDLBytes(TK: LongInt);
  Begin
  End;


Function  AbsUsrObj.GetUserULFiles: LongInt;    {Get Num Files uploaded}
  Begin
  End;


Procedure AbsUsrObj.SetUserULFiles (TK: LongInt); {Set Num Files uploaded today}
  Begin
  End;


Function AbsUsrObj.GetUserDLFiles: LongInt;    {Get Num Files downloaded today}
  Begin
  End;


Procedure AbsUsrObj.SetUserDLFiles (TK: LongInt); {Set Num Files downloaded today}
  Begin
  End;


Function AbsUsrObj.GetUserElapsed: Integer;    {Get Elapsed time prior calls today}
  Begin
  End;


Procedure AbsUsrObj.SetUserElapsed (TK: Integer); {Set Elapsed time}
  Begin
  End;


Procedure AbsUsrObj.GetUserLastCall(Var LD: MKDateTime);
  Begin
  End;


Procedure AbsUsrObj.SetUserLastCall (Var LD: MKDateTime);
  Begin
  End;


Function AbsUsrObj.GetUserLanguage: Byte;     {Get user lang number}
  Begin
  End;


Procedure AbsUsrObj.SetUserLanguage(Ln: Byte); {Set user lang number}
  Begin
  End;


Function AbsUsrObj.GetUserBaud: LongInt;         {Get user baud rate}
  Begin
  End;


Procedure AbsUsrObj.SetUserBaud(Bd: LongInt);     {Set user baud rate}
  Begin
  End;


Function AbsUsrObj.GetUserMsgTemplate: Word; {Get user msg template area}

  Begin
  GetUserMsgTemplate := 1;
  End;


Procedure AbsUsrObj.SetUserMsgTemplate(Tm: Word); {Set user msg template area}
  Begin
  End;


Function AbsUsrObj.GetUserFileTemplate: Word; {Get user file template area}
  Begin
  GetUserFileTemplate := 1;
  End;


Procedure AbsUsrObj.SetUserDoorTemplate(Tm: Word); {Set user door template area}
  Begin
  End;


Function AbsUsrObj.GetUserDoorTemplate: Word; {Get user door template area}
  Begin
  GetUserDoorTemplate := 1;
  End;


Procedure AbsUsrObj.SetUserFileTemplate(Tm: Word); {Set user file template area}
  Begin
  End;




Function  AbsUsrObj.GetUserPageTimes: Word;    {Get number of times has paged}
  Begin
  End;


Procedure AbsUsrObj.SetUserPageTimes(Pg: Word);{Set number of times has paged}
  Begin
  End;


Function  AbsUsrObj.GetUserTimeLimit: Integer; {Get user time limit}
  Begin
  End;


Procedure AbsUsrObj.SetUserTimeLimit(TL: Word);{Set user time limit}
  Begin
  End;


Function  AbsUsrObj.GetUserDLLimit: LongInt;      {Get user DL limit}
  Begin
  End;


Procedure AbsUsrObj.SetUserDLLimit(DL: LongInt);  {Set user DL limit}
   Begin
   End;


Function AbsUsrObj.GetUserCombined(Area: Word): Boolean;
  Begin
  End;


Procedure AbsUsrObj.SetUserCombined(Area: Word; St: Boolean);
  Begin
  End;


Function AbsUsrObj.GetUserProt: Char;  {Get user default protocol}
  Begin
  End;


Procedure AbsUsrObj.SetUserProt(PT: Char); {Set user default protocol}
  Begin
  End;


Function AbsUsrObj.GetUserPacker: Char;  {Get user default packer}
  Begin
  End;


Procedure AbsUsrObj.SetUserPacker(PT: Char); {Set user default packer}
  Begin
  End;


Function AbsUsrObj.GetUserAvatar: Boolean;    {Get avatar setting}
  Begin
  End;


Procedure AbsUsrObj.SetUserAvatar(AV: Boolean);{Set user avatar}
  Begin
  End;


Function AbsUsrObj.GetUserHandle: String;
  Begin
  GetUserHandle := '';
  End;


Procedure AbsUsrObj.SetUserHandle(Hd: String);
  Begin
  End;


Procedure AbsUsrObj.GetUserBirthDate(Var BD: MKDateType);
  Begin
  End;


Procedure AbsUsrObj.SetUserBirthDate(Var BD: MKDateType); {Set user birthdate MM-DD-YY}
  Begin
  End;


Procedure AbsUsrObj.GetUserFirstDate(Var FD: MKDateType);
  Begin
  End;


Procedure AbsUsrObj.SetUserFirstDate(Var FD: MKDateType);
  Begin
  End;


Function AbsUsrObj.GetUserPageTune: Byte;
  Begin
  GetuserPageTune := 1;
  End;


Procedure AbsUsrObj.SetUserPageTune(Tune: Byte);
  Begin
  End;


Function AbsUsrObj.GetUserAnsi: Boolean;      {Get ansi setting}
  Begin
  GetUserAnsi := False;
  End;


Procedure AbsUsrObj.SetUserAnsi(UA: Boolean);  {Set user ansi}
  Begin
  End;

Function AbsUsrObj.GetUserFullEd: Boolean;    {Get full-screen editor setting}
  Begin
  End;


Procedure AbsUsrObj.SetUserFullEd(FE: Boolean);{Set full-screen editor setting}
  Begin
  End;


Function AbsUsrObj.GetUserMore: Boolean;      {Get ask more setting}
  Begin
  GetUserMore := True;
  End;


Procedure AbsUsrObj.SetUserMore(Mo: Boolean);  {Set ask more setting}
  Begin
  End;


Function  AbsUsrObj.GetUserScrnClr: Boolean;       {Get screen clear setting}
  Begin
  GetUserScrnClr := True;
  End;


Procedure AbsUsrObj.SetUserScrnClr(Cl: Boolean);   {Set screen clear setting}
  Begin
  End;


Function AbsUsrObj.AskDate(Var DT: MKDateTime): Boolean;  {Ask user date}
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
  DateMask := Upper(Prompts^.GetString(58));
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
      DateValid := ValidMKDate(DT);
      If Not DateValid Then
        Begin
        DisplayNewLine;
        DisplayStr(Prompts^.GetString(159) + ' ');
        End;
      End;
    End
  Else
    AskDate := False;
  UserInfo^.CurrLines := 1;
  End;


Function AbsUsrObj.AskFormatted(FMStr: String): String;
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


Function AbsUsrObj.AskPhone: String;
  Var
    TmpStr: String[20];

  Begin
  TmpStr := Copy(Prompts^.GetString(194),1, 12);
  If Length(TmpStr) > 0 Then
    AskPhone := AskFormatted(TmpStr)
  Else
    AskPhone := InputStr('',12);
  End;


Procedure AbsUsrObj.GetUserNewFileDate(Var DT: MKDateTime);
  Begin
  End;


Function  AbsUsrObj.AskNumber(Num: LongInt; Min: LongInt; Max: LongInt): LongInt;
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
          DisplayStrLn(Prompts^.GetString(17) + ' ' + Long2Str(Max));
          End
        Else
          Begin
          DisplayStrLn(Prompts^.GetString(16) + ' ' + Long2Str(Min));
          End;
        DisplayStr(Prompts^.GetString(28) + ' ');
        End;
      End;
    End;
  ResetLines(1);
  End;


Function AbsUsrObj.DefaultNumStr(Num: LongInt): String; {returns (enter = xx)}
  Begin
  DefaultNumStr := ' ' + Prompts^.GetString(12) + Prompts^.GetString(5) + ' ' +
    Long2Str(Num) + Prompts^.GetString(13) + ' ';
  End;



Procedure AbsUsrObj.SetUserNewFileDate(DT: MKDateTime);
  Begin
  End;


Function AbsUsrObj.AskChoice(ChStr: String): Char;
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


Procedure AbsUsrObj.AskYN(Quest: String; Var Option: Boolean);
  Var
    TmpChr: Char;
    YChr: Char;
    NChr: Char;

  Begin
  DisplayAttr(White);
  DisplayStr(Quest + ' ' + Prompts^.GetString(3) + ', ' +
    Prompts^.GetString(4) + ', ' + Prompts^.GetString(5) + ' ');
  If Option Then
    DisplayStr(Prompts^.GetString(3))
  Else
    DisplayStr(Prompts^.GetString(4));
  DisplayStr(Prompts^.GetString(14) + ' ');
  YChr := Prompts^.GetChar(1);
  NChr := Prompts^.GetChar(2);
  TmpChr := AskChoice(YChr + NChr + #13);
  If TmpChr = YChr Then
    Option := True;
  If TmpChr = NChr Then
    Option := False;
  If Option Then
    DisplayStr(Prompts^.GetString(3))
  Else
    DisplayStr(Prompts^.GetString(4));
  ResetLines(1);
  End;


Procedure AbsUsrObj.ClearGoSub;
  Begin
  End;


Procedure AbsUsrObj.GoSub(MN: String);
  Begin
  End;


Function AbsUsrObj.GoSubReturn: String;
  Begin
  GoSubReturn := '';
  End;

Function AbsUsrObj.GetUserRecNum: Word;
  Begin
  End;


Function AbsUsrObj.GetSessionTimeLimit: LongInt; {Seconds this call allowed}
  Begin
  GetSessionTimeLimit := UserInfo^.TimeLimit;
  End;


Procedure AbsUsrObj.SetSessionTimeLimit(TL: LongInt); {Seconds allowed this call}
  Begin
  UserInfo^.TimeLimit := TL;
  End;


Procedure AbsUsrObj.SetStartTime; {Set start time}
  Begin
  UserInfo^.StartDay := GetCurrentDay;
  UserInfo^.StartTime := CurrentTime;
  End;


Procedure AbsUsrObj.DoShell(Cmd: String; DoSwap: Boolean);
  Var
    CDirStr: String;
    Ta,Tx,Ty: Byte;
    SwapResult: Word;
    SaveBuf: Pointer;
    EName: String;
    CStr: String;
    ShellError: Word;
    {$IFDEF WINDOWS}
    CChar: Array[0..255] of Char;
    {$ENDIF}

  Begin
  EName := ExtractWord(Cmd, 1);
  CStr := Copy(Cmd, Length(EName) + 1, 127);
  CDirStr := WithBackSlash(FExpand('\'));
{$IFDEF WINDOWS}
  StrPCopy(CChar, Cmd);
  SwapResult := WinExec(CChar, sw_ShowNormal);
{$ELSE}
  If FileExist(CDirStr + 'MKBBS.SWP') Then
    ShellError := 9
  Else
    ShellError := 0;
  If SaveScrnRegion(1,1, ScrnWidth, ScrnHeight, SaveBuf) Then
    Begin
    Tx := WhereX;
    Ty := WhereY;
    Ta := TextAttr;
    ClrScr;
    End
  Else
    ShellError := 1;
  If ((DoSwap) And (ShellError = 0)) Then
    Begin
    SwapVectors;
    {$IFDEF DPMI}
    Exec(EName, CStr);
    {$ELSE}
    If NWInitExecSwap(HeapEnd, CDirStr + 'MKBBS.SWP') Then
      Begin
      SwapResult := ExecWithSwap(EName, CStr);
      NWShutDownExecSwap;
      End;
    {$ENDIF}
    SwapVectors;
    End;
  If ((Not DoSwap) and (ShellError = 0)) Then
    Begin
    SwapVectors;
    Exec(EName, CStr);
    SwapVectors;
    End;
  If ShellError = 0 Then
    Begin
    RestoreScrnRegion(1, 1, ScrnWidth, ScrnHeight, SaveBuf);
    GoToXY(Tx, Ty);
    TextAttr := Ta;
    End;
{$ENDIF}
  ChDir(StripTrail(CDirStr,'\'));
  If IoResult <> 0 Then;
  SetTimeOut;
  End;



Procedure AbsUsrObj.UpdateForMsg; {Increment msgs posted count}
  Begin
  Inc(UserInfo^.MsgsToday);
  End;


Procedure AbsUsrObj.UpdateForDL(FSize: LongInt); {Increment DL count and update K}
  Begin
  Inc(UserInfo^.DLToday);
  End;


Procedure AbsUsrObj.UpdateForUL(FSize: LongInt); {Increment UL count and update K}
  Begin
  Inc(UserInfo^.ULToday);
  End;


Function AbsUsrObj.UserIsLoaded: Boolean;
  Begin
  UserIsLoaded :=  UserInfo^.UserLoaded;
  End;


Procedure AbsUsrObj.PostStatus(Status: Byte; SM: String);
  Begin
  End;


Function AbsUsrObj.GetNotOkReason: Word;
  Begin
  GetNotOkReason := UserInfo^.NotOkReason;
  End;


Function AbsUsrObj.GetUserGraphics: LongInt;
  Begin
  End;


Procedure AbsUsrObj.SetUserGraphics(UG: LongInt);
  Begin
  End;


Function AbsUsrObj.FindUser(Name: String): LongInt;
  Begin
  End;

Procedure AbsUsrObj.SetUserFileName(UFN: String);
  Begin
  UserInfo^.UserFileName := UFN;
  End;

Function AbsUsrObj.GetPrompt(PN: Word): String;
  Begin
  GetPrompt := Prompts^.GetString(PN);
  End;

Procedure AbsUsrObj.SendPrompt(PN: Word);
  Begin
  DisplayStr(Prompts^.GetString(PN));
  End;

Procedure AbsUsrObj.SendPromptLn(PN: Word);
  Begin
  DisplayStrLn(Prompts^.GetString(PN));
  End;

Procedure AbsUsrObj.DisplayXY(XL: Byte; YL: Byte);
  Begin
  If GetUserAvatar Then
    Begin
    DisplayStr(#22#8 + Chr(YL) + Chr(XL));
    End
  Else
    Begin
    If GetUserAnsi Then
      DisplayStr(#27'[' + Long2Str(YL) + ';' + Long2Str(XL) + 'f'); {gotoyx}
    End;
  End;

End.
