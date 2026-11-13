Unit MKMRead;
{$I MKB.Def}

Interface

Uses MKGlobT, MKMsgAbs;

Procedure CheckYourMail;
Procedure MsgRead(Area: Word; Var Sec: SecType; ReadType: Word);
Procedure MsgQScanF(Start: Word; BoardNo: Word; Var Sec: SecType;
  ReadType: Byte); {1=forward 2=reverse 3=specific}
Procedure MsgScanF(Start: Word; BoardNo: Word; Var Sec: SecType;
  ReadType: Byte); {1=forward 2=reverse 3=specific}
Procedure MsgReadF(Start: Word; BoardNo: Word; Var Sec: SecType;
  ReadType: Byte); {1=forward 2=reverse 3=specific}
Function OneMsg(Var MsgOut: AbsMsgPtr; Var DisplayHidden: Boolean;
  DefAction: Word; UpdateLast: Boolean): Word;
Procedure ReplyMsg(Var MsgOut: AbsMsgPtr);
Procedure DeleteMsg(Area: Word; Var Sec: SecType);
Procedure ReadMsg(CmdStr: String; RType: Word); {1=read 2=Quick-scan 3=scan}
Procedure DoDeleteMsg(CmdStr: String);
Procedure SelectCombined;
Procedure ResetCombined;
Procedure SelectOffline;
Procedure ResetOffline;
Procedure SelectMessageArea;

Implementation


Uses MKFile, MKString, MKCfgAbs, MKDoor, MKSys, MKEnter, MKFossil,
  MKName, MKMsgSel, MKDos, MKLogEnt, MKCodes, MKRCfgMk, MKMsgOpn,
  {$IFDEF WINDOWS}
  WinDos;
  {$ELSE}
  Dos;
  {$ENDIF}


Var
  Threading: Boolean;
  OrigMsg: LongInt;
  CurrArea: Word;
  TmpLastRead: LongInt;


Procedure ResetCombined;
  Var
    Sec: SecType;
    i: Word;
    Tmp: Boolean;

  Begin
  User.GetUserSec(Sec);
  User.SetMore(True);
  User.SetStopMore(False);
  User.ResetLines(1);
  If User.GetUserScrnClr Then
    User.ClearScreen;
  User.DisplayNewLine;
  Tmp := False;
  User.AskYN(Prompts.GetString(316), Tmp);
  User.DisplayNewLine;
  If Tmp Then
    Begin
    For i := 1 to Config^.GetMaxMsgAreas Do
      User.SetUserCombined(i, False);
    End
  Else
    Begin
    User.AskYN(Prompts.GetString(317), Tmp);
    User.DisplayNewLine;
    If Tmp Then
      Begin
      For i := 1 to Config^.GetMaxMsgAreas Do
        User.SetUserCombined(i, Config^.MsgReadAccess(i, Sec) and
        Config^.GetMsgAllowCombined(i));
      End;
    End;
  End;



Procedure SelectCombined;
  Var
    SC: ConfSelectObj;
    i: Word;
    Sec: SecType;

  Begin
  User.GetUserSec(Sec);
  SC.Init;
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    SC.SetAvailable(i, (Config^.MsgReadAccess(i, Sec) and
    Config^.GetMsgAllowCombined(i)));
    SC.SetChosen(i, User.GetUserCombined(i));
    End;
  SC.SelectConfs(True, False, False);
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    User.SetUserCombined(i, SC.IsChosen(i));
    End;
  SC.Done;
  End;


Procedure SelectOffline;
  Var
    SC: ConfSelectObj;
    i: Word;
    Sec: SecType;

  Begin
  User.GetUserSec(Sec);
  SC.Init;
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    SC.SetAvailable(i, (Config^.MsgReadAccess(i, Sec) and
    Config^.GetMsgAllowOffline(i) and Not Config^.GetMsgForceOffline(i)));
    SC.SetChosen(i, User.GetUserOffline(i));
    End;
  SC.SelectConfs(True, False, False);
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    If Config^.GetMsgForceOffline(i) Then
      User.SetUserOffline(i, True)
    Else
      User.SetUserOffline(i, SC.IsChosen(i));
    End;
  SC.Done;
  End;


Procedure ResetOffline;
  Var
    Sec: SecType;
    i: Word;
    Tmp: Boolean;

  Begin
  User.GetUserSec(Sec);
  User.SetMore(True);
  User.SetStopMore(False);
  User.ResetLines(1);
  If User.GetUserScrnClr Then
    User.ClearScreen;
  User.DisplayNewLine;
  Tmp := False;
  User.AskYN(Prompts.GetString(341), Tmp);
  User.DisplayNewLine;
  If Tmp Then
    Begin
    For i := 1 to Config^.GetMaxMsgAreas Do
      Begin
      If Not Config^.GetMsgForceOffline(i) Then
        User.SetUserOffline(i, False);
      End;
    End
  Else
    Begin
    User.AskYN(Prompts.GetString(342), Tmp);
    User.DisplayNewLine;
    If Tmp Then
      Begin
      For i := 1 to Config^.GetMaxMsgAreas Do
        User.SetUserCombined(i, Config^.MsgReadAccess(i, Sec) and
        Config^.GetMsgAllowOffline(i));
      End;
    End;
  End;



Procedure SelectMessageArea;
  Var
    SC: ConfSelectObj;
    i: Word;
    Sec: SecType;

  Begin
  User.GetUserSec(Sec);
  SC.Init;
  For i := 1 to Config^.GetMaxMsgAreas Do
    SC.SetAvailable(i, Config^.MsgReadAccess(i, Sec));
  SC.SelectConfs(False, False, False);
  i := SC.GetSelectedArea;
  If i <> 0 Then
    Begin
    User.SetUserMsgTemplate(i);
    User.DisplayNewLine;
    If BbsDisplay.DisplayBbsFile('MSG' + Long2Str(i), ' ') = ' ' Then;
    If (BbsDisplay.GetError = 0) Then
      User.PressEnter
    Else
      Begin
      User.DisplayStrLn(Long2Str(SC.GetSelectedArea) + ' '
        + Config^.GetMsgName(SC.GetSelectedArea));
      User.DisplayNewLine;
      End;
    End;
  SC.Done;
  End;


Procedure ReadMsg(CmdStr: String; RType: Word);
  Var
    TmpStr: String[80];
    Tmp: Word;
    Code: Word;
    Sec: SecType;

  Begin
  User.PostStatus(uoMsg);
  User.GetUserSec(Sec);
  If (WordCount(CmdStr) > 0) Then
    Begin
    TmpStr := Upper(StripBoth(ExtractWord(CmdStr,1),' '));
    If Copy(TmpStr,1,2) = '/M' Then
      Begin
      Tmp := User.GetUserMsgTemplate;
      Code := 0;
      End
    Else
      Begin
      Val(TmpStr, Tmp, Code);
      End;
    If ((Tmp < 1) or (Tmp > Config^.GetMaxMsgAreas)) Then
      Code := 100;
    If ((Code = 0) and (Config^.MsgReadAccess(Tmp, Sec))) Then
      Begin
      If User.GetUserScrnClr Then
        User.ClearScreen;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStrLn(Prompts.GetString(151) + ' ' + Long2Str(Tmp) +
        ' - ' + Config^.GetMsgName(Tmp));
      Case RType of
        1: MsgRead(Tmp, Sec, 1);
        2: MsgRead(Tmp, Sec, 2);
        3: MsgRead(Tmp, Sec, 3);
        End;
      End
    Else
      Begin
      User.DisplayStrLn(Prompts.GetString(074));
      User.PressEnter;
      End;
    End;
  End;


Procedure DoDeleteMsg(CmdStr: String);
  Var
    TmpStr: String[80];
    Tmp: Word;
    Code: Word;
    Sec: SecType;

  Begin
  User.GetUserSec(Sec);
  If (WordCount(CmdStr) > 0) Then
    Begin
    TmpStr := Upper(StripBoth(ExtractWord(CmdStr,1),' '));
    If TmpStr = '/M' Then
      Begin
      Tmp := User.GetUserMsgTemplate;
      Code := 0;
      End
    Else
      Begin
      Val(TmpStr, Tmp, Code);
      End;
    If ((Tmp < 1) or (Tmp > Config^.GetMaxMsgAreas)) Then
      Code := 100;
    If ((Code = 0) and (Config^.MsgReadAccess(Tmp, Sec))) Then
      DeleteMsg(Tmp, Sec)
    Else
      Begin
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(272));
      User.PressEnter;
      End;
    End;
  End;


Function YNStr(St: Boolean): String;
  Begin
  If St Then
    YNStr := Prompts.GetString(3)
  Else
    YNStr := Prompts.GetString(4);
  End;


Function GetWriteArea(Prompt: String; Sec: SecType): Word;
  Var
    NewArea: Word;
    SC: ConfSelectObj;
    i: Word;

  Begin
  NewArea := 0;
  User.DisplayStr(Prompt + ' ');
  NewArea := User.AskNumber(NewArea, 0, Config^.GetMaxMsgAreas);
  User.DisplayNewLine;
  If NewArea = 0 Then
    Begin
    SC.Init;
    For i := 1 to Config^.GetMaxMsgAreas Do
      SC.SetAvailable(i, Config^.MsgWriteAccess(i, Sec));
    SC.SelectConfs(False, False, False);
    NewArea := SC.GetSelectedArea;
    SC.Done;
    End;
  GetWriteArea := NewArea;
  End;


Procedure MsgShow(Var MsgOut: AbsMsgPtr; Var DisplayHidden: Boolean;
  UpdateLast: Boolean);
  Var
    TmpStr: String;
    Addr: AddrType;

  Const
    StLen = 78;

  Begin
  MsgOut^.MsgStartUp;
  User.SetStopMore(False);
  If User.GetUserScrnClr Then
    User.ClearScreen;
  If (UpdateLast and (Not MsgOut^.IsDeleted)) Then
    If MsgOut^.GetMsgNum > TmpLastRead Then
      TmpLastRead := MsgOut^.GetMsgNum;
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(108) + ' ');
  User.DisplayStr(Long2Str(MsgOut^.GetMsgNum) + ' - ' + Prompts.GetString(109) +
    ' ' + Long2Str(CurrArea) +  ' - ' + Config^.GetMsgName(CurrArea));
  If MsgOut^.IsPriv Then
    User.DisplayStr('  ' + Prompts.GetString(12) + Prompts.GetString(69) +
      Prompts.GetString(13));
  If MsgOut^.IsRcvd Then
    User.DisplayStr('  ' + Prompts.GetString(12) + Prompts.GetString(70) +
      Prompts.GetString(13));
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(67) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  If Config^.GetMsgType(CurrArea) = NetMail Then
    Begin
    MsgOut^.GetOrig(Addr);
    User.DisplayStr(PadRight(MsgOut^.GetFrom + ' @ ' + AddrStr(Addr), ' ', 45));
    End
  Else
    User.DisplayStr(PadRight(MsgOut^.GetFrom,' ',45));
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(29) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  User.DisplayStrLn(ReformatDate(MsgOut^.GetDate, Prompts.GetString(58))
    + ' ' + MsgOut^.GetTime);
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(66) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  If Config^.GetMsgType(CurrArea) = NetMail Then
    Begin
    MsgOut^.GetDest(Addr);
    User.DisplayStrLn(MsgOut^.GetTo + ' @ ' + AddrStr(Addr));
    End
  Else
    User.DisplayStrLn(MsgOut^.GetTo);
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(68) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  User.DisplayStrLn(MsgOut^.GetSubj);
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(5));
  MsgOut^.MsgTxtStartUp;
  TmpStr := MsgOut^.GetString(StLen);
  While ((Not MsgOut^.EOM) and (Not User.StopMore) And (User.OK)) Do
    Begin
    If ((TmpStr[1] <> #1) or (DisplayHidden)) Then
      User.DisplayStrLn(TmpStr);
    TmpStr := MsgOut^.GetString(StLen);
    User.CheckInput;
    End;
  End;


Procedure DoMsgExport(Var MsgOut: AbsMsgPtr; Var OutFile: Text);
  Var
    TAddr: AddrType;
    TmpStr: String;

  Const
    StLen = 78;

  Begin
  Write(OutFile, Long2Str(MsgOut^.GetMsgNum) + ' - ' + Prompts.GetString(109) +
    ' ' + Long2Str(CurrArea) +  ' - ' + Config^.GetMsgName(CurrArea));
  If MsgOut^.IsPriv Then
    Write(OutFile,'  ' + Prompts.GetString(12) + Prompts.GetString(69) +
      Prompts.GetString(13));
  If MsgOut^.IsRcvd Then
    Write(OutFile, '  ' + Prompts.GetString(12) + Prompts.GetString(70) +
      Prompts.GetString(13));
  WriteLn(OutFile);
  Write(OutFile, Prompts.GetString(67) + ' ');
  If Config^.GetMsgType(CurrArea) = NetMail Then
    Begin
    MsgOut^.GetOrig(TAddr);
    Write(OutFile, PadRight(MsgOut^.GetFrom + ' @ ' + AddrStr(TAddr), ' ', 45));
    End
  Else
    Write(OutFile, PadRight(MsgOut^.GetFrom,' ',45));
  Write(OutFile, Prompts.GetString(29) + ' ');
  WriteLn(OutFile, ReformatDate(MsgOut^.GetDate, Prompts.GetString(58))
    + ' ' + MsgOut^.GetTime);
  Write(OutFile, Prompts.GetString(66) + ' ');
  If Config^.GetMsgType(CurrArea) = NetMail Then
    Begin
    MsgOut^.GetDest(TAddr);
    WriteLn(OutFile, MsgOut^.GetTo + ' @ ' + AddrStr(TAddr));
    End
  Else
    WriteLn(OutFile, MsgOut^.GetTo);
  Write(OutFile, Prompts.GetString(68) + ' ');
  WriteLn(OutFile,MsgOut^.GetSubj);
  WriteLn(OutFile);
  MsgOut^.MsgTxtStartUp;
  TmpStr := MsgOut^.GetString(StLen);
  While ((Not MsgOut^.EOM) and (Not User.StopMore) And (User.OK)) Do
    Begin
    WriteLn(OutFile, TmpStr);
    TmpStr := MsgOut^.GetString(StLen);
    User.CheckInput;
    End;
  If IoResult <> 0 Then;
  End;


Procedure AdjustAttribs(Var MsgOut: AbsMsgPtr);
  Var
    AdjustDone: Boolean;
    i: Word;
    SubHStr: String[20];
    TmpKey: Char;
    TmpStr: String;

  Begin
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  AdjustDone := False;
  SubHStr := Upper(Copy(Prompts.GetString(289),1, 4)) + #13;
  While ((User.Ok) and (Not AdjustDone)) Do
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(Prompts.GetString(286) + ' ');
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStrLn(YNStr(MsgOut^.IsPriv));
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(Prompts.GetString(287) +' ');
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStrLn(YNStr(MsgOut^.IsRcvd));
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(Prompts.GetString(288) +' ');
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStrLn(YNStr(MsgOut^.IsLocal));
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(Prompts.GetString(277) + ' ');
    TmpKey := User.AskChoice(SubHStr);
    User.DisplayNewLine;
    User.DisplayNewLine;
    Case Pos(TmpKey, SubHStr) of
      1: MsgOut^.SetPriv(Not MsgOut^.IsPriv);
      2: MsgOut^.SetRcvd(Not MsgOut^.IsRcvd);
      3: MsgOut^.SetLocal(Not MsgOut^.IsLocal);
      4: AdjustDone := True;
      End;
    User.CheckInput;
    End;
  End;


Procedure AdjustMsg(Var MsgOut: AbsMsgPtr; Sec: SecType);
  Var
    AdjustDone: Boolean;
    i: Word;
    MainStr: String[20];
    TmpKey: Char;
    TmpStr: String;

  Begin
  MsgOut^.MsgStartUp;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  AdjustDone := False;
  MainStr := Upper(Copy(Prompts.GetString(284),1, 6)) + #13;
  While ((User.Ok) and (Not AdjustDone)) Do
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(Prompts.GetString(279) + ' ');
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStrLn(MsgOut^.GetFrom);
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(Prompts.GetString(280) + ' ');
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStrLn(MsgOut^.GetTo);
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(Prompts.GetString(281) + ' ');
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStrLn(MsgOut^.GetSubj);
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStrLn(Prompts.GetString(282));
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStrLn(Prompts.GetString(283));
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(Prompts.GetString(277) + ' ');
    TmpKey := User.AskChoice(MainStr);
    User.DisplayNewLine;
    User.DisplayNewLine;
    Case Pos(TmpKey, MainStr) of
      1: Begin
         User.DisplayStr(Prompts.GetString(67) + ' ');
         TmpStr := User.InputProper(35);
         If Length(TmpStr) > 0 Then
           MsgOut^.SetFrom(TmpStr);
         End;
      2: Begin
         User.DisplayStr(Prompts.GetString(66) + ' ');
         TmpStr := User.InputProper(35);
         If Length(TmpStr) > 0 Then
           MsgOut^.SetTo(TmpStr);
         End;
      3: Begin
         User.DisplayStr(Prompts.GetString(68) + ' ');
         TmpStr := '';
         TmpStr := User.InputStr(TmpStr, 35);
         If Length(TmpStr) > 0 Then
           MsgOut^.SetSubj(TmpStr);
         End;
      4: AdjustAttribs(MsgOut);
      5..6: AdjustDone := True;
      End;
    User.CheckInput;
    End;
  MsgOut^.ReWriteHdr;
  End;


Procedure CheckExport(Var MsgOut: AbsMsgPtr; Sec: SecType);
  Var
    OutFile: Text;
    OutName: String;

  Begin
  User.DisplayNewLine;
  If ((Config^.MsgSysopAccess(CurrArea, Sec)) and (CurrentPort = 0)) Then
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(Prompts.GetString(266) + ' ');
    OutName := User.InputStr('',40);
    User.DisplayNewLine;
    If Length(OutName) > 0 Then
      Begin
      If ((Not FileExist(OutName)) and (Not IsDevice(OutName))) Then
        Begin
        Assign(OutFile, OutName);
        ReWrite(OutFile);
        If IoResult <> 0 Then;
        DoMsgExport(MsgOut, OutFile);
        Close(OutFile);
        End
      Else
        Begin
        User.DisplayNewLine;
        User.DisplayStrLn(Prompts.GetString(259));
        User.DisplayNewLine;
        User.PressEnter;
        End;
      End;
    End
  Else
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(265));
    User.DisplayNewLine;
    User.PressEnter;
    End;
  End;


Procedure MsgSecurityAdjust(Var MsgOut: AbsMsgPtr; Sec: SecType);
  Var
    NameS: NameObj;
    Found: Boolean;
    SearchOver: Boolean;
    USec: SecType;
    NewLevel: Word;

  Begin
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  If (Config^.MsgSysopAccess(CurrArea, Sec)) Then
    Begin
    NameS.Init;
    Found := NameS.SearchFirst(MsgOut^.GetFrom);
    SearchOver := NameS.Exact;
    While Not SearchOver Do
      Begin
      Found := NameS.SearchNext;
      If ((Not Found) or (NameS.Exact)) Then
        SearchOver := True;
      End;
    If NameS.Exact Then
      Begin
      NameS.GetSec(USec);
      If USec.Level > Sec.Level Then
        Begin
        User.DisplayStrLn(Prompts.GetString(267));
        User.DisplayNewLine;
        User.PressEnter;
        End
      Else
        Begin
        User.DisplayStr(Prompts.GetString(268) + ' ' + MsgOut^.GetFrom +
          User.DefaultNumStr(USec.Level));
        NewLevel := User.AskNumber(USec.Level, 0, Sec.Level);
        If User.Ok Then
          Begin {Set security level}
          USec.Level := NewLevel;
          NameS.SetSec(USec);
          NameS.SaveChanges;
          End;
        End;
      End
    Else
      Begin
      User.DisplayStr(Prompts.GetString(269));
      User.DisplayNewLine;
      User.PressEnter;
      End;
    NameS.Done;
    End
  Else
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(267));
    User.DisplayNewLine;
    User.PressEnter;
    End;
  End;


Procedure MsgQScanF(Start: Word; BoardNo: Word; Var Sec: SecType;
  ReadType: Byte); {1=forward 2=reverse 3=specific}
Var
  MsgOut: AbsMsgPtr;
  CH: Char;
  i: Word;
  Finished: Boolean;
  SeekMsgNo: Word;
  ChoiceDone: Boolean;
  DisplayHidden: Boolean;
  TmpStr: String;
  TmpName: String[35];
  Addr: AddrType;
  FromYou: Boolean;
  ToYou: Boolean;
  SeekOver: Boolean;

Begin
If User.GetUserScrnClr Then
  User.ClearScreen;
CurrArea := BoardNo;
DisplayHidden := False;
Finished := False;
User.SetMore(True);
User.SetStopMore(False);
User.ResetLines(1);
User.DisplayNewLine;
User.DisplayAttr(Config^.GetSystemColor(1));
User.DisplayStrLn(Prompts.GetString(295));
User.DisplayStrLn(Prompts.GetString(296));
If OpenMsgArea(MsgOut, BoardNo) Then;
If MsgOut^.OpenMsgBase <> 0 Then;
MsgOut^.SeekFirst(Start);
If (Not MsgOut^.SeekFound and (ReadType = 2)) Then
  MsgOut^.SeekPrior;
If ((MsgOut^.SeekFound) and (ReadType = 2) and
  (MsgOut^.GetMsgNum > Start)) Then
  MsgOut^.SeekPrior;
SeekOver := Not MsgOut^.SeekFound;
If ((MsgOut^.SeekFound) and (ReadType = 3) And
  (MsgOut^.GetMsgNum <> Start)) Then
  SeekOver := True;
If SeekOver Then
  Begin
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(178));
  User.DisplayNewLine;
  User.PressEnter;
  End;
While ((Not SeekOver) and (User.Ok) and (Not Finished) and (Not User.StopMore)) Do
  Begin
  MsgOut^.MsgStartUp;
  FromYou := (Upper(MsgOut^.GetFrom) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetFrom) = Upper(User.GetUserHandle));
  ToYou := (Upper(MsgOut^.GetTo) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetTo) = Upper(User.GetUserHandle));
  If ((Not MsgOut^.IsPriv) Or (ToYou) Or (FromYou)
    Or (Config^.MsgSysopAccess(CurrArea, Sec))) Then
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(PadLeft(Long2Str(MsgOut^.GetMsgNum), ' ', 6) + ' ');
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(PadRight(Copy(MsgOut^.GetFrom, 1, 20),' ', 20) + ' ');
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStr(PadRight(Copy(MsgOut^.GetTo, 1, 20), ' ', 20) + ' ');
    User.DisplayAttr(Config^.GetSystemColor(4));
    User.DisplayStrLn(Copy(MsgOut^.GetSubj,1,30));
    End;
  Case ReadType of
    1: MsgOut^.SeekNext;
    2: MsgOut^.SeekPrior;
    3: Finished := True;
    End;
  User.CheckInput;
  If  User.CheckHot(' ') = ' ' Then
    Begin
    User.SetStopMore(True);
    CommFlushOut;
    End;
  SeekOver := Not MsgOut^.SeekFound;
  End;
If Not CloseMsgArea(MsgOut) Then;
User.PressEnter;
End;




Procedure MsgReadF(Start: Word; BoardNo: Word; Var Sec: SecType;
  ReadType: Byte);
Var
  MsgOut: AbsMsgPtr;
  CH: Char;
  i: Word;
  Finished: Boolean;
  Action: Word;       {1=next msg 2=again 3=seek msg 4=prior msg}
  SeekMsgNo: Word;
  ChoiceDone: Boolean;
  DisplayHidden: Boolean;
  TmpStr: String;
  TmpName: String[35];
  Addr: AddrType;
  FromYou: Boolean;
  ToYou: Boolean;
  TempAction: Word;
  SeekOver: Boolean;

Begin
CurrArea := BoardNo;
Case ReadType of
  1: Action := 1;
  2: Action := 4;
  3: Action := 5;
  End;
TempAction := Action;
DisplayHidden := False;
Finished := False;
User.SetMore(True);
User.SetStopMore(False);
User.ResetLines(1);
If User.GetUserScrnClr Then
  User.ClearScreen;
If OpenMsgArea(MsgOut, BoardNo) Then;
MsgOut^.SeekFirst(Start);
If (Not MsgOut^.SeekFound and (ReadType = 2)) Then
  MsgOut^.SeekPrior;
If ((MsgOut^.SeekFound) and (ReadType = 2) and
  (MsgOut^.GetMsgNum > Start)) Then
  MsgOut^.SeekPrior;
SeekOver := Not MsgOut^.SeekFound;
If ((MsgOut^.SeekFound) and (ReadType = 3) And
  (MsgOut^.GetMsgNum <> Start)) Then
  SeekOver := True;
If SeekOver Then
  Begin
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(178));
  User.DisplayNewLine;
  User.PressEnter;
  End;
While ((Not SeekOver) and (User.Ok) and (Not Finished)) Do
  Begin
  MsgOut^.MsgStartUp;
  FromYou := (Upper(MsgOut^.GetFrom) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetFrom) = Upper(User.GetUserHandle));
  ToYou := (Upper(MsgOut^.GetTo) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetTo) = Upper(User.GetUserHandle));
  If ((Not MsgOut^.IsPriv) Or (ToYou) Or (FromYou)
    Or (Config^.MsgSysopAccess(CurrArea, Sec))) Then
    Begin
    TempAction := OneMsg(MsgOut, DisplayHidden, Action, True);
    End;
  Case TempAction of
    1: MsgOut^.SeekNext;
    4: MsgOut^.SeekPrior;
    5: Finished := True;
    End;
  User.CheckInput;
  SeekOver := Not MsgOut^.SeekFound;
  End;
If CloseMsgArea(MsgOut) Then;
End;


Procedure MsgHdrDisplay(Var MsgOut: AbsMsgPtr);
  Var
    Addr: AddrType;

  Begin
  User.DisplayNewLine;
  User.DisplayNewLine;
  User.DisplayStr(Long2Str(MsgOut^.GetMsgNum) + ' - ' + Prompts.GetString(109) +
    ' ' + Long2Str(CurrArea) +  ' - ' + Config^.GetMsgName(CurrArea));
  If MsgOut^.IsPriv Then
    User.DisplayStr('  ' + Prompts.GetString(12) + Prompts.GetString(69) +
      Prompts.GetString(13));
  If MsgOut^.IsRcvd Then
    User.DisplayStr('  ' + Prompts.GetString(12) + Prompts.GetString(70) +
      Prompts.GetString(13));
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(67) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  If Config^.GetMsgType(CurrArea) = NetMail Then
    Begin
    MsgOut^.GetOrig(Addr);
    User.DisplayStr(PadRight(MsgOut^.GetFrom + ' @ ' + AddrStr(Addr), ' ', 45));
    End
  Else
    User.DisplayStr(PadRight(MsgOut^.GetFrom,' ',45));
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(29) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  User.DisplayStrLn(ReformatDate(MsgOut^.GetDate, Prompts.GetString(58))
    + ' ' + MsgOut^.GetTime);
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(66) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  If Config^.GetMsgType(CurrArea) = NetMail Then
    Begin
    MsgOut^.GetDest(Addr);
    User.DisplayStrLn(MsgOut^.GetTo + ' @ ' + AddrStr(Addr));
    End
  Else
    User.DisplayStrLn(MsgOut^.GetTo);
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(Prompts.GetString(68) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(4));
  User.DisplayStrLn(MsgOut^.GetSubj);
  End;


Procedure MsgScanF(Start: Word; BoardNo: Word; Var Sec: SecType;
  ReadType: Byte);
Var
  MsgOut: AbsMsgPtr;
  CH: Char;
  i: Word;
  Finished: Boolean;
  Action: Word;       {1=next msg 2=again 3=seek msg 4=prior msg}
  SeekMsgNo: Word;
  ChoiceDone: Boolean;
  DisplayHidden: Boolean;
  TmpStr: String;
  TmpName: String[35];
  Addr: AddrType;
  FromYou: Boolean;
  ToYou: Boolean;
  TempAction: Word;
  SeekOver: Boolean;
  HotStr: String[30];
  TC: Char;

Begin
CurrArea := BoardNo;
Case ReadType of
  1: Action := 1;
  2: Action := 4;
  3: Action := 5;
  End;
TempAction := Action;
DisplayHidden := False;
Finished := False;
User.SetMore(True);
User.SetStopMore(False);
User.ResetLines(1);
If User.GetUserScrnClr Then
  User.ClearScreen;
If OpenMsgArea(MsgOut, BoardNo) Then;
MsgOut^.SeekFirst(Start);
If (Not MsgOut^.SeekFound and (ReadType = 2)) Then
  MsgOut^.SeekPrior;
If ((MsgOut^.SeekFound) and (ReadType = 2) and
  (MsgOut^.GetMsgNum > Start)) Then
  MsgOut^.SeekPrior;
SeekOver := Not MsgOut^.SeekFound;
If ((MsgOut^.SeekFound) and (ReadType = 3) And
  (MsgOut^.GetMsgNum <> Start)) Then
  SeekOver := True;
If SeekOver Then
  Begin
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(178));
  User.DisplayNewLine;
  User.PressEnter;
  End;
While ((Not SeekOver) and (User.Ok) and (Not Finished)) Do
  Begin
  MsgOut^.MsgStartUp;
  FromYou := (Upper(MsgOut^.GetFrom) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetFrom) = Upper(User.GetUserHandle));
  ToYou := (Upper(MsgOut^.GetTo) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetTo) = Upper(User.GetUserHandle));
  If ((Not MsgOut^.IsPriv) Or (ToYou) Or (FromYou)
    Or (Config^.MsgSysopAccess(CurrArea, Sec))) Then
    Begin
    MsgHdrDisplay(MsgOut);
    HotStr := Upper(Prompts.GetString(315) + #13);
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(PadRight(Prompts.GetString(211), ' ', 15));
    User.DisplayStr(PadRight(Prompts.GetString(212), ' ', 15));
    User.DisplayStr(PadRight(Prompts.GetString(216), ' ', 15));
    User.DisplayStr(PadRight(Prompts.GetString(314), ' ', 15) + ' ');
    Tc := UpCase(User.AskChoice(HotStr));
    User.DisplayChr(Tc);
    Case Pos(Tc, HotStr) Of
      1: Begin
         TempAction := 1;
         End;
      2: Begin
         TempAction := 4;
         End;
      3: Begin
         TempAction := 5;
         End;
      4: Begin
         TempAction := OneMsg(MsgOut, DisplayHidden, Action, True);
         End;
      End;
    End;
  Case TempAction of
    1: MsgOut^.SeekNext;
    4: MsgOut^.SeekPrior;
    5: Finished := True;
    End;
  User.CheckInput;
  SeekOver := Not MsgOut^.SeekFound;
  End;
If CloseMsgArea(MsgOut) Then;
End;



Procedure MsgRead(Area: Word; Var Sec: SecType; ReadType: Word);
  Var
    HelpAgain: Boolean;
    HotStr: String[30];
    TC: Char;
    TmpWord: LongInt;
    TMsg: AbsMsgPtr;
    HighMsg: LongInt;

  Begin
  If OpenMsgArea(TMsg, Area) Then;
  If True Then
    HighMsg := TMsg^.GetHighMsgNum
  Else
    HighMsg := 0;
  TmpLastRead := TMsg^.GetLastRead(User.GetUserNumber);
  If CloseMsgArea(TMsg) Then;
  Threading := False;
  HelpAgain := True;
  HotStr := Upper(Prompts.GetString(229));
  While (HelpAgain and User.Ok) Do
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(PadRight(Prompts.GetString(221), ' ', 15));
    User.DisplayStr(PadRight(Prompts.GetString(222), ' ', 15));
    User.DisplayStrLn(PadRight(Prompts.GetString(223), ' ', 15));
    {User.DisplayStrLn(Prompts.GetString(224) + ' ');}
    User.DisplayStr(PadRight(Prompts.GetString(225), ' ', 15));
    User.DisplayStr(PadRight(Prompts.GetString(226), ' ', 15));
    User.DisplayStr(PadRight(Prompts.GetString(227), ' ', 15));
    User.DisplayStr(PadRight(Prompts.GetString(228), ' ', 15));
    Tc := UpCase(User.AskChoice(HotStr));
    User.DisplayChr(Tc);
    HelpAgain := False;
    Case Pos(Tc, HotStr) Of
      1: Begin                              {Read forward}
         User.DisplayNewLine;
         User.DisplayNewLine;
         TmpWord := TmpLastRead + 1;
         User.DisplayStr(Prompts.GetString(086) + ' ');
         User.DisplayStr(User.DefaultNumStr(TmpWord));
         TmpWord := User.AskNumber(TmpWord, 1, HighMsg);
         User.DisplayNewLine;
         Case ReadType of
           1: MsgReadF(TmpWord, Area, Sec, 1);
           2: MsgQScanF(TmpWord, Area, Sec, 1);
           3: MsgScanF(TmpWord, Area, Sec, 1);
           End;
         End;
      2: Begin                              {Read reverse}
         User.DisplayNewLine;
         User.DisplayNewLine;
         TmpWord := HighMsg;
         User.DisplayStr(Prompts.GetString(086) + ' ');
         User.DisplayStr(User.DefaultNumStr(TmpWord));
         TmpWord := User.AskNumber(TmpWord, 1, HighMsg);
         User.DisplayNewLine;
         Case ReadType of
           1: MsgReadF(TmpWord, Area, Sec, 2);
           2: MsgQScanF(TmpWord, Area, Sec, 2);
           3: MsgScanF(TmpWord, Area, Sec, 2);
           End;
         End;
      3: Begin                              {Individual}
         User.DisplayNewLine;
         User.DisplayNewLine;
         User.DisplayStr(Prompts.GetString(086) + ' ');
         User.DisplayStr(User.DefaultNumStr(TmpLastRead));
         TmpWord := User.AskNumber(TmpLastRead, 1, HighMsg);
         User.DisplayNewLine;
         Case ReadType of
           1: MsgReadF(TmpWord, Area, Sec, 3);
           2: MsgQScanF(TmpWord, Area, Sec, 3);
           3: MsgScanF(TmpWord, Area, Sec, 3);
           End;
         End;
      4: Begin                              {New}
         Case ReadType of
           1: MsgReadF(TmpLastRead + 1, Area, Sec, 1);
           2: MsgQScanF(TmpLastRead + 1, Area, Sec, 1);
           3: MsgScanF(TmpLastRead + 1, Area, Sec, 1);
           End;
         End;
      5:; {Selected}
      6:Begin                               {Help}
        HelpAgain := True;
        End;
      7:;                                   {Quit}
      End;
    User.CheckInput;
    End;
  If OpenMsgArea(TMsg, Area) Then;
  TMsg^.SetLastRead(User.GetUserNumber, TmpLastRead);
  If CloseMsgArea(TMsg) Then;
  End;


Procedure StripPrior(Var TmpStr: String; PriorQuote: String);
  Var
    PriorPos: Word;
    TmpStr2: String;

  Begin
  If Length(PriorQuote) > 0 Then
    Begin
    PriorPos := Pos(PriorQuote, TmpStr);
    While (PriorPos > 0) Do
      Begin
      If PriorPos = 1 Then
        TmpStr2 := ''
      Else
        TmpStr2 := Copy(TmpStr,1, PriorPos - 1);
      If ((PriorPos = 1) or ((TmpStr[PriorPos - 1] = ' ') or
      (TmpStr[PriorPos + Length(PriorQuote)] = ' '))) Then
        TmpStr := TmpStr2 + Copy(TmpStr, PriorPos + Length(PriorQuote), 255)
      Else
        TmpStr := TmpStr2 + ' ' + Copy(TmpStr, PriorPos + Length(PriorQuote), 255);
      PriorPos := Pos(PriorQuote, TmpStr);
      End;
    End;
  End;


Procedure FixUp(Var Str: String);
  Var
    i: Word;

  Begin
  i := 1;
  While i <= Length(Str) Do
    Begin
    Case Str[i] of
      #0, #26: Str[i] := ' ';
      End;
    Inc(i);
    End;
  End;


Procedure ReplyMsg(Var MsgOut: AbsMsgPtr);
  Var
    TAddr: AddrType;
    Sec: SecType;
    Quote: Boolean;
    QuoteStr: String[30];
    QuoteHdr: String[80];
    PriorQuote: String[30];
    TmpStr: String;
    i: Word;
    OutFile: Text;
    CurrPos: LongInt;
    MsgEnt: MsgEntObjPtr;
    TF: TFile;

  Const
    TempName = 'MsgTmp.Bbs';

  Begin
  CurrPos := MsgOut^.GetMsgLoc;
  User.GetUserSec(Sec);
  If Config^.MsgWriteAccess(CurrArea, Sec) Then
    Begin
    Assign(OutFile, TempName);
    Erase(OutFile);
    If IoResult <> 0 Then;
    New(MsgEnt, Init);
    If MsgEnt = Nil Then
      Begin
      LogEntry.WriteEntry('Unable to msg reply');
      Halt(0);
      End;
    MsgEnt^.SetArea(CurrArea);
    MsgEnt^.SetTo(MsgOut^.GetFrom);
    MsgEnt^.SetSubj(MsgOut^.GetSubj);
    MsgOut^.GetOrig(TAddr);
    MsgEnt^.SetDest(TAddr);
    MsgEnt^.SetRefer(MsgOut^.GetMsgNum);
    MsgEnt^.AskPriv(MsgOut^.IsPriv);
    User.AskYN(Prompts.GetString(056), Quote);
    User.DisplayNewLine;
    If Quote Then
      Begin
      QuoteStr := '';
      TmpStr := Config^.GetQuoteStr;
      i := 1;
      While i <= Length(TmpStr) Do
        Begin
        If TmpStr[i] <> '@' Then
          QuoteStr := QuoteStr + TmpStr[i]
        Else
          Begin
          If WordCount (MsgOut^.GetFrom) > 0 Then
            QuoteStr := QuoteStr + Copy(ExtractWord(MsgOut^.GetFrom,1),1,1);
          If WordCount (MsgOut^.GetFrom) > 1 Then
            QuoteStr := QuoteStr + Copy(ExtractWord(MsgOut^.GetFrom,2),1,1);
          If WordCount (MsgOut^.GetFrom) > 2 Then
            QuoteStr := QuoteStr + Copy(ExtractWord(MsgOut^.GetFrom,3),1,1);
          End;
        Inc(i);
        End;
      i := 0;
      MsgOut^.MsgTxtStartUp;
      Assign(OutFile, TempName);
      ReWrite(OutFile);
      If IoResult <> 0 Then;
      QuoteStr := StripTrail(QuoteStr, ' ');
      PriorQuote := QuoteStr;
      ExtraString := '';
      TmpStr := MsgOut^.GetString(150);
      While ((Length(TmpStr) > 0) Or (Not MsgOut^.EOM)) Do
        Begin
        If TmpStr[1] <> #1 Then
          Begin
          If Length(StripBoth(TmpStr, ' ')) > 0 Then
            Begin
            If Pos('>', Copy(TmpStr, 1, 8)) > 0 Then
              PriorQuote := Copy(TmpStr,1, Pos('>', Copy(TmpStr,1,8)))
            Else
              PriorQuote := QuoteStr;
            StripPrior(TmpStr, PriorQuote);
            While (((Length(TmpStr) > 67)) Or
            ((Length(TmpStr) > 0) and (MsgOut^.EOM))) Do
              Begin
              If ((TmpStr[1] = ' ') or (Length(PriorQuote) = 0)) Then
                TmpStr := PriorQuote + TmpStr
              Else
                TmpStr := PriorQuote + ' ' + TmpStr;
              TmpStr := WWrap(TmpStr, 67);
              FixUp(TmpStr);
              WriteLn(OutFile, TmpStr);
              If IoResult <> 0 Then;
              TmpStr := ExtraString;
              End;
            If ((TmpStr[1] = ' ') or (Length(PriorQuote) = 0)) Then
              ExtraString := PriorQuote + TmpStr
            Else
              ExtraString := PriorQuote + ' '+ TmpStr;
            End
          Else
            Begin
            WriteLn(OutFile, '');
            If IoResult <> 0 Then;
            TmpStr := '';
            ExtraString := '';
            End;
          End
        Else
          Begin
          While ((MsgOut^.WasWrap) and (Not MsgOut^.EOM)) Do
            TmpStr := MsgOut^.GetString(150);
          ExtraString := '';
          End;
        TmpStr := MsgOut^.GetString(150);
        While ((TmpStr[1] = #1) and (Not MsgOut^.EOM)) Do
          Begin
          TmpStr := MsgOut^.GetString(150);
          End;
        If TmpStr[1] = #1 Then
          TmpStr := '';
        If ((Copy(TmpStr,1,Length(PriorQuote)) <> PriorQuote) and (Pos('>', Copy(TmpStr,1,8)) > 0)) or
        (TmpStr[1] = ' ') or (Length(TmpStr) = 0) or (TmpStr[1] = '-') Then
          Begin
          If Length(ExtraString) > 0 Then
            Begin
            FixUp(ExtraString);
            WriteLn(OutFile, ExtraString);
            End;
          If IoResult <> 0 Then;
          ExtraString := '';
          End;
        If MsgOut^.EOM Then
          TmpStr := ExtraString
        Else
          Begin
          ExtraString := StripTrail(ExtraString,' ');
          If TmpStr[1] = ' ' Then
            TmpStr := ExtraString + TmpStr
          Else
            TmpStr := ExtraString + ' ' + TmpStr;
          End;
        ExtraString := '';
        End;
      Close(OutFile);
      End;
    If CloseMsgArea(MsgOut) Then;
    TF.Init;
    i := 1;
    If TF.OpenTextFile(TempName) Then
      Begin
      TmpStr := TF.GetString;
      While TF.StringFound Do
        Begin
        MsgEnt^.AddStr(TmpStr + #13);
        User.DisplayAttr(Config^.GetSystemColor(3));
        User.DisplayStr(PadLeft(Long2Str(i), ' ', 3) + ': ');
        User.DisplayAttr(Config^.GetSystemColor(1));
        User.ResetLines(1);
        User.DisplayStrLn(TmpStr);
        Inc(i);
        TmpStr := TF.GetString;
        End;
      If TF.CloseTextFile Then;
      End;
    TF.Done;
    Assign(OutFile, TempName);
    Erase(OutFile);
    If IoResult <> 0 Then;
    MsgEnt^.GetText;
    If OpenMsgArea(MsgOut, CurrArea) Then
      Begin
      MsgOut^.SetMsgLoc(CurrPos);
      MsgOut^.MsgStartUp;
      If ((MsgEnt^.GetMsgNum <> 0) and (MsgOut^.GetSeeAlso = 0)) Then
        Begin
        MsgOut^.SetSeeAlso(MsgEnt^.GetMsgNum);
        MsgOut^.ReWriteHdr;
        End;
      End
    Else
      Begin
      LogEntry.WriteEntry('Fatal Error reopening msg base');
      End;
    Dispose(MsgEnt, Done);
    End
  Else
    Begin
    User.DisplayStrLn(Prompts.GetString(073));
    User.DisplayNewLine;
    User.PressEnter;
    End;
  End;


Procedure ForwardMsg(Var MsgOut: AbsMsgPtr);
  Var
    Sec: SecType;
    i: Word;
    NewArea: Word;
    TMsg: AbsMsgPtr;
    TempAddr: AddrType;
    TempResult: Word;
    TmpChar: Char;

  Begin
  User.GetUserSec(Sec);
  NewArea := 0;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  User.DisplayNewLine;
  NewArea := GetWriteArea(Prompts.GetString(274), Sec);
  If NewArea > 0 Then
    Begin
    If Config^.MsgWriteAccess(NewArea, Sec) Then
      Begin
      MsgEnter.Init;
      MsgEnter.SetArea(NewArea);
      MsgEnter.SetSubj(MsgOut^.GetSubj);
      MsgEnter.AskTo;
      If MsgEnter.GetTo <> 'All' Then
        MsgEnter.AskPriv(MsgOut^.IsPriv)
      Else
        MsgEnter.SetPriv(False);
      If OpenMsgArea(TMsg, NewArea) Then;
      TMsg^.StartNewMsg;
      Case Config^.GetMsgType(NewArea) of
        Normal: TMsg^.SetMailType(mmtNormal);
        EchoMail: TMsg^.SetMailType(mmtEchoMail);
        NetMail: TMsg^.SetMailType(mmtNetMail);
        End;
      MsgOut^.MsgTxtStartUp;
      If Config^.GetMsgType(NewArea) = Netmail Then
        Begin
        Config^.GetMsgAddr(NewArea, TempAddr);
        TMsg^.SetOrig(TempAddr);
        MsgEnter.GetDest(TempAddr);
        TMsg^.SetDest(TempAddr);
        End;
      TMsg^.SetFrom(MsgEnter.GetFrom);
      TMsg^.SetTo(MsgEnter.GetTo);
      TMsg^.SetSubj(MsgOut^.GetSubj);
      TMsg^.SetPriv(MsgEnter.GetPriv);
      TMsg^.SetDate(DateStr(GetDosDate));
      TMsg^.SetTime(TimeStr(GetDosDate));
      TMsg^.SetLocal(True);
      TMsg^.SetEcho(True);
      TMsg^.DoStringLn(Prompts.GetString(273) + ' ' + Long2Str(CurrArea) +
        ' - ' + Config^.GetMsgName(CurrArea));
      TMsg^.DoStringLn(Prompts.GetString(275) + ' ' + MsgOut^.GetFrom);
      TMsg^.DoStringLn(Prompts.GetString(276) + ' ' + MsgOut^.GetTo);
      TMsg^.DoStringLn('');
      TmpChar := MsgOut^.GetChar;
      While Not MsgOut^.EOM Do
        Begin
        TMsg^.DoChar(TmpChar);
        TmpChar := MsgOut^.GetChar;
        End;
      If ((Config^.GetMsgType(NewArea) <> Normal) And
        (Config^.MsgAddFido(NewArea))) Then
        Begin
        If ((Config^.GetMsgType(NewArea) = Normal) or
          (Not Config^.MsgAddFido(NewArea))) Then
          Begin
          TMsg^.DoStringLn('--- MK Bbs v0.0');
          TMsg^.DoStringLn(Config^.GetDefaultOrigStr(NewArea));
          End;
        End;
      TempResult := TMsg^.WriteMsg;
      If TempResult <> 0 Then
        Begin
        User.DisplayNewLine;
        User.DisplayStrLn(Prompts.GetString(260) + ' ' + Long2Str(TempResult));
        User.PressEnter;
        End
      Else
        Begin
        LogEntry.WriteEntry('Message #' + Long2Str(TMsg^.GetMsgNum) +
               ' forwarded in area #' + Long2Str(NewArea) + ' : ' +
                 Config^.GetMsgName(NewArea));
        End;
      If CloseMsgArea(TMsg) Then;
      MsgEnter.Done;
      End
    Else
      Begin
      User.DisplayStrLn(Prompts.GetString(073));
      User.DisplayNewLine;
      User.PressEnter;
      End;
    End;
  End;


Procedure DeleteMsg(Area: Word; Var Sec: SecType);
  Var
    FromYou: Boolean;
    ToYou: Boolean;
    TmpNum: Word;
    MsgOut: AbsMsgPtr;
    Sure: Boolean;
    i: Word;

  Begin
  TmpNum := 0;
  If OpenMsgArea(MsgOut, Area) Then;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(271) + ' ');
  TmpNum := User.AskNumber(TmpNum, 0, MsgOut^.GetHighMsgNum);
  User.DisplayNewLine;
  If ((User.Ok) and (TmpNum > 0)) Then
    Begin
    MsgOut^.SeekFirst(TmpNum);
    If (MsgOut^.GetMsgNum <> TmpNum) Then
      Begin
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(080));
      User.DisplayNewLine;
      User.PressEnter;
      End
    Else
      Begin
      MsgOut^.MsgStartUp;
      FromYou := (Upper(MsgOut^.GetFrom) = Upper(User.GetUserName))
      Or (Upper(MsgOut^.GetFrom) = Upper(User.GetUserHandle));
      ToYou := (Upper(MsgOut^.GetTo) = Upper(User.GetUserName))
      Or (Upper(MsgOut^.GetTo) = Upper(User.GetUserHandle));
      If ((((ToYou) or (FromYou)) And (Config^.MsgDeleteAccess(Sec)))
      Or (Config^.MsgSysopAccess(CurrArea, Sec))) Then
        Begin
        Sure := False;
        User.DisplayNewLine;
        User.AskYN(Prompts.GetString(009), Sure);
        If Sure Then
          MsgOut^.DeleteMsg;
        End
      Else
        Begin
        User.DisplayNewLine;
        User.DisplayStrLn(Prompts.GetString(272));
        User.DisplayNewLine;
        User.PressEnter;
        End;
      End;
    End;
  If CloseMsgArea(MsgOut) Then;
  End;



Procedure DoThreading(Var MsgOut: AbsMsgPtr; ThreadNo: Word; Var Sec: SecType);
  Var
    TmpState: LongInt;
    FromYou: Boolean;
    ToYou: Boolean;
    TempAction: Word;

  Begin
  User.DisplayNewLine;
  TmpState := MsgOut^.GetMsgLoc;
  MsgOut^.SeekFirst(ThreadNo);
  If (MsgOut^.GetMsgNum <> ThreadNo) Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(080));
    User.DisplayNewLine;
    User.PressEnter;
    MsgOut^.SetMsgLoc(TmpState);
    End
  Else
    Begin
    MsgOut^.MsgStartUp;
    FromYou := (Upper(MsgOut^.GetFrom) = Upper(User.GetUserName))
      Or (Upper(MsgOut^.GetFrom) = Upper(User.GetUserHandle));
    ToYou := (Upper(MsgOut^.GetTo) = Upper(User.GetUserName))
      Or (Upper(MsgOut^.GetTo) = Upper(User.GetUserHandle));
    If ((Not MsgOut^.IsPriv) Or (ToYou) Or (FromYou)
      Or (Config^.MsgSysopAccess(CurrArea, Sec))) Then
      Begin
      End
    Else
      Begin
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStrLn(Prompts.GetString(270));
      User.DisplayNewLine;
      User.PressEnter;
      MsgOut^.SetMsgLoc(TmpState);
      End;
    End;
  User.CheckInput;
  End;


Function OneMsg(Var MsgOut: AbsMsgPtr; Var DisplayHidden: Boolean;
  DefAction: Word; UpdateLast: Boolean): Word;

  Var
    ToYou: Boolean;
    FromYou: Boolean;
    Sec: SecType;
    ChoiceDone: Boolean;
    Action: Word; {1=next 2=again 3= 4=last 5=stop}
    Ch: Char;
    HotStr: String[25];
    TmpStr: String;
    i: Word;

  Begin
  User.SetMore(True);
  User.SetStopMore(False);
  User.ResetLines(1);
  If User.GetUserScrnClr Then
    User.ClearScreen;
  User.GetUserSec(Sec);
  HotStr := Upper(Prompts.GetString(220)) + #13;
  ToYou := (Upper(MsgOut^.GetTo) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetTo) = Upper(User.GetUserHandle));
  FromYou := (Upper(MsgOut^.GetFrom) = Upper(User.GetUserName))
    Or (Upper(MsgOut^.GetFrom) = Upper(User.GetUserHandle));
  MsgShow(MsgOut, DisplayHidden, UpdateLast);
  User.ResetLines(1);
  User.DisplayAttr(Config^.GetSystemColor(1));
  If (MsgOut^.GetRefer <> 0) Then
    User.DisplayStr(Prompts.GetString(217) + ' ');
  If (MsgOut^.GetSeeAlso <> 0) Then
    User.DisplayStr(Prompts.GetString(218)+ ' ');
  If (Config^.MsgSysopAccess(CurrArea, Sec)) Then
    Begin
    User.DisplayStr(Prompts.GetString(215) + ' ');
    User.DisplayStr(Prompts.GetString(219) + ' ');
    End;
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(210) + ' ');
  User.DisplayStr(Prompts.GetString(211) + ' ');
  User.DisplayStr(Prompts.GetString(212) + ' ');
  User.DisplayStr(Prompts.GetString(213) + ' ');
  User.DisplayStr(Prompts.GetString(214) + ' ');
  User.DisplayStr(Prompts.GetString(216) + ' ');
  If ToYou Then
    Begin
    MsgOut^.SetRcvd(True);
    MsgOut^.ReWriteHdr;
    End;
  ChoiceDone := False;
  While ((Not ChoiceDone) and (User.Ok)) Do
    Begin
    Ch := User.AskChoice(HotStr);
    Case Pos(Ch, HotStr) of
      1: Begin                    {again}
         ChoiceDone := True;
         Action := 2;
         User.DisplayChr(HotStr[1]);
         End;
      2: Begin                    {next}
         ChoiceDone := True;
         Action := 1;
         User.DisplayChr(HotStr[2]);
         End;
      3: Begin                    {last}
         ChoiceDone := True;
         Action := 4;
         User.DisplayChr(HotStr[3]);
         End;
      4: Begin                    {reply}
         ChoiceDone := True;
         Action := 2;
         User.DisplayChr(HotStr[4]);
         User.DisplayNewLine;
         ReplyMsg(MsgOut);
         End;
      5: Begin                    {Enter}
         ChoiceDone := True;
         Action := 2;
         User.DisplayChr(HotStr[06]);
         MsgEnter.Init;
         MsgEnter.SetArea(CurrArea);
         MsgEnter.MsgTest(Sec);
         MsgEnter.Done;
         End;
      6: Begin                            {delete}
         If ((((ToYou) or (FromYou)) And (Config^.MsgDeleteAccess(Sec)))
         Or (Config^.MsgSysopAccess(CurrArea, Sec))) Then
           Begin
           ChoiceDone := True;
           MsgOut^.DeleteMsg;
           User.DisplayChr(HotStr[06]);
           Action := DefAction;
           End;
         End;
      7: Begin                         {stop}
         ChoiceDone := True;
         User.DisplayChr(HotStr[7]);
         Action := 5;
         End;
      8: Begin                         {Orig msg}
         If MsgOut^.GetRefer <> 0 Then
           Begin
           User.DisplayChr(HotStr[8]);
           DoThreading(MsgOut, MsgOut^.GetRefer, Sec);
           ChoiceDone := True;
           Action := 2;
           End;
         End;
      9: Begin                         {Next reply msg}
         If MsgOut^.GetSeeAlso <> 0 Then
           Begin
           User.DisplayChr(HotStr[9]);
           DoThreading(MsgOut, MsgOut^.GetSeeAlso, Sec);
           ChoiceDone := True;
           Action := 2;
           End;
         End;
      10:Begin                         {! hidden toggle}
         DisplayHidden := Not DisplayHidden;
         User.DisplayChr(HotStr[10]);
         ChoiceDone := True;
         Action := 2;
         End;
      11:Begin                         {* adjust msg}
         If Config^.MsgSysopAccess(CurrArea, Sec) Then
           Begin
           ChoiceDone := True;
           Action := 2;
           User.DisplayChr(HotStr[11]);
           AdjustMsg(MsgOut, Sec);
           End;
         End;
      12:Begin                         {X export msg}
         ChoiceDone := True;
         Action := 2;
         User.DisplayChr(HotStr[12]);
         CheckExport(MsgOut, Sec);
         End;
      13:Begin                         {/ Forward a msg}
         If Config^.MsgSysopAccess(CurrArea, Sec) Then
           Begin
           ChoiceDone := True;
           Action := 2;
           User.DisplayChr(HotStr[13]);
           ForwardMsg(MsgOut);
           End;
         End;
      14:Begin                         {Adjust user security level}
         If Config^.MsgSysopAccess(CurrArea, Sec) Then
           Begin
           ChoiceDone := True;
           Action := 2;
           User.DisplayChr(HotStr[14]);
           MsgSecurityAdjust(MsgOut, Sec);
           End;
         End;
      15:Begin                         {= unreceive message}
         If (((ToYou) And (Config^.MsgUnRecvAccess(Sec)))
         Or (Config^.MsgSysopAccess(CurrArea, Sec))) Then
           Begin
           ChoiceDone := True;
           MsgOut^.SetRcvd(False);
           MsgOut^.ReWriteHdr;
           User.DisplayChr(HotStr[15]);
           Action := DefAction;
           End;
         End;
      16:Begin                            {hit enter}
         ChoiceDone := True;
         Action := DefAction;
         End;
      End;                        {Case}
    User.CheckInput;
    End;
  OneMsg := Action;
  End;


Procedure CheckYourMail;
  Const MaxYours = 500;

  Type MailArray = Array[1..MaxYours] of LongInt;
  Type MailArea = Array[1..MaxYours] of Word;
  Type PerArea = Array[1..500] of Word;

  Var
    MsgOut: AbsMsgPtr;
    MsgsPerArea: ^PerArea;
    YourMail: ^MailArray;
    YourArea: ^MailArea;
    YourCounter: Word;
    i: Word;
    Sec: SecType;
    ReadNow: Boolean;
    Action: Word;
    DisplayHidden: Boolean;
    YoursDone: Boolean;
    Name: String[35];
    Handle: String[35];
    DetailHdr: Boolean;
    DoSearch: Boolean;
    HudsonDone: Boolean;

  Begin
  User.SetMore(False);
  New(MsgsPerArea);
  New(YourArea);
  New(YourMail);
  If (YourMail <> Nil) and (YourArea <> Nil) and (MsgsPerArea <> Nil) Then
    Begin
    Threading := False;
    DetailHdr := False;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.GetUserSec(Sec);
    User.DisplayNewLine;
    User.DisplayStrLn(Prompts.GetString(258));
    User.DisplayNewLine;
    YourCounter := 0;
    Name := User.GetUserName;
    Handle := User.GetUserHandle;
    If Length(Handle) = 0 Then
      Handle := '»»»';
    If Length(Name) = 0 Then
      Name := '»»»';
    For i := 1 to 500 Do
      MsgsPerArea^[i] := 0;
    HudsonDone := False;
    For i := 1 to 500 Do
      Begin
      DoSearch := True;
      Case Config^.GetMsgBaseType(i) of
        'H': Begin
             If HudsonDone Then
               DoSearch := False
             Else
               HudsonDone := True;
             End;
        Else
          Begin
          DoSearch := Config^.MsgReadAccess(i, Sec);
          End;
        End;
      If DoSearch Then
        Begin
        If Not OpenMsgArea(MsgOut, i) Then
          DoSearch := False;
        End;
      If DoSearch Then
        Begin
        MsgOut^.YoursFirst(Name, Handle);
        While ((MsgOut^.YoursFound) and (YourCounter < MaxYours)) Do
          Begin
          If ((Config^.GetMsgBaseType(i) <> 'H') or
          (Config^.MsgReadAccess(MsgOut^.GetSubArea, Sec))) Then
            Begin
            Inc(YourCounter);
            MsgOut^.MsgStartUp;
            YourMail^[YourCounter] := MsgOut^.GetMsgLoc;
            If Config^.GetMsgBaseType(i) = 'H' Then
              Begin
              YourArea^[YourCounter] := MsgOut^.GetSubArea;
              Inc(MsgsPerArea^[MsgOut^.GetSubArea]);
              End
            Else
              Begin
              YourArea^[YourCounter] := i;
              Inc(MsgsPerArea^[i]);
              End;
            If Config^.GetMailCheckDetail Then
              Begin
              If Not DetailHdr Then
                Begin
                DetailHdr := True;
                User.DisplayAttr(Config^.GetSystemColor(1));
                User.DisplayStrLn(Prompts.GetString(256));
                User.DisplayStrLn(Prompts.GetString(257));
                End;
              User.DisplayAttr(Config^.GetSystemColor(1));
              User.DisplayStr(PadLeft(Long2Str(MsgOut^.GetMsgNum), ' ', 5) + ' ');
              User.DisplayAttr(Config^.GetSystemColor(2));
              User.DisplayStr(PadRight(Copy(MsgOut^.GetFrom,1,25),' ',26));
              User.DisplayAttr(Config^.GetSystemColor(3));
              User.DisplayStrLn(Copy(MsgOut^.GetSubj,1,40));
              End
            Else
              User.DisplayStr('.');
            End;
          MsgOut^.YoursNext;
          End;
        If Not CloseMsgArea(MsgOut) Then;
        End;
      End;
    User.DisplayNewLine;
    If Config^.GetMailCheckTotal Then
      Begin
      If YourCounter > 0 Then
        Begin
        For i := 1 to 500 Do
          Begin
          If MsgsPerArea^[i] > 0 Then
            Begin
            User.DisplayAttr(Config^.GetSystemColor(1));
            User.DisplayStr(PadLeft(Long2Str(MsgsPerArea^[i]),' ',3) + ' ');
            User.DisplayAttr(Config^.GetSystemColor(2));
            User.DisplayStr(Prompts.GetString(255) + ' ');
            User.DisplayAttr(Config^.GetSystemColor(3));
            User.DisplayStr(PadLeft(Long2Str(i), ' ', 3) + ' ');
            User.DisplayAttr(Config^.GetSystemColor(4));
            User.DisplayStr(Config^.GetMsgName(i));
            User.DisplayNewLine;
            End;
          End;
        End;
      End;
    If YourCounter > 0 Then
      Begin
      ReadNow := True;
      User.DisplayNewLine;
      User.AskYN(Prompts.GetString(052), ReadNow);
      DisplayHidden := False;
      i := 1;
      If ReadNow Then
        Begin
        CurrArea := YourArea^[1];
        If Not OpenMsgArea(MsgOut, CurrArea) Then;
        YoursDone := False;
        While ((Not YoursDone) and (User.OK)) Do
          Begin
          If YourArea^[i] <> CurrArea Then
            Begin
            CurrArea := YourArea^[i];
            If Not CloseMsgArea(MsgOut) Then;
            If Not OpenMsgArea(MsgOut, CurrArea) Then;
            End;
          MsgOut^.SetMsgLoc(YourMail^[i]);
          MsgOut^.MsgStartUp;
          Action := OneMsg(MsgOut, DisplayHidden, 1, False);
          Case Action of
            1: Begin    { Next }
               Inc(i);
               If i > YourCounter Then
                 YoursDone := True;
               End;
            2: ; { Again }
            3: ;
            4: If i > 1 Then
                 Dec(i);
            5: YoursDone := True;
            End;
          User.CheckInput;
          End;
        If Not CloseMsgArea(MsgOut) Then;
        End;
      End
    Else
      Begin
      User.DisplayStrLn(Prompts.GetString(051));
      End;
    Dispose(MsgsPerArea);
    Dispose(YourMail);
    Dispose(YourArea);
    End;
  End;


End.
