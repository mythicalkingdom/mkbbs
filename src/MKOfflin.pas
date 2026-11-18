Unit MKOfflin; {Offline mail functions}
{$I MKB.Def}

Interface

Procedure SetPacker;
Procedure SetProtocol;
Procedure SetOffType;
Procedure AskOffNewFiles;
Procedure AskOffScrn;
Procedure AskOffBull;
Procedure AskOffVerify;
Procedure AskOffFlag;
Procedure AskOffOwn;
Procedure AskOffAllYour;
Procedure AskOffZero;
Procedure AskOffMax;
Procedure AskOffConfMax;
Procedure OfflineAuto;
Procedure OfflineUL;
Procedure OfflineDL;
Function  GetUserPackerNum: Word;
Function  GetUserProtNum: Word;
Function  GetUserOffTypeNum: Word;

Implementation


Uses MKFile, MKString, MKDoor, MKCfgAbs, MKGlobT, MKCFile,
  MKOffAbs, MKOffQwk, MKOffTxt, MKOffXrs, MKOffBwv,
  MKMsgOpn, MKMsgAbs, MKDos, MKRCfgMK, MKComAbs, MKProt, MKQwkO,
  Dos;


Procedure SetPacker;
  Var
    Tmp: Word;

  Begin
  User.ResetLines(1);
  Tmp := GetPacker;
  If Tmp <> 0 Then
    Begin
    User.SetUserPacker(UpCase(Config^.GetPackChar(Tmp)));
    End;
  End;


Procedure SetProtocol;
  Var
    Tmp: Word;

  Begin
  User.ResetLines(1);
  Tmp := GetProtocol(True);
  If Tmp <> 0 Then
    User.SetUserProt(Config^.GetProtChar(Tmp));
  End;


Procedure SetOffType;
  Var
    i: Word;
    OldType: Byte;
    HotStr: String;
    CmdStr: String;
    TmpChr: Char;
    OffTypeStr: String[12];

  Begin
  User.ResetLines(1);
  OffTypeStr := 'QXBTP12345';
  OldType := Pos(User.GetUserOffType, OffTypeStr);
  User.DisplayNewLine;
  CmdStr := Prompts.GetString(345);
  HotStr := '';
  For i := 1 to 10 Do
    Begin
    If Config^.GetOffTypeAvail(i) Then
      Begin
      HotStr := HotStr + CmdStr[i];
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStr(Prompts.GetString(12) + CmdStr[i] + Prompts.GetString(13));
      User.DisplayAttr(Config^.GetSystemColor(2));
      User.DisplayStrLn(' ' + Prompts.GetString(i + 345));
      End
    Else
      HotStr := HotStr + #255;
    End;
  If OldType <> 0 Then
    HotStr := HotStr + #13;
  User.DisplayStr(Prompts.GetString(356) + ' ' + Prompts.GetString(14) + ' ');
  TmpChr := User.AskChoice(HotStr);
  User.DisplayChr(TmpChr);
  If (TmpChr <> #13) and (TmpChr <> #255) Then
    Begin
    OldType := Pos(TmpChr, HotStr);
    If (OldType > 0) and (OldType < 11) Then
      User.SetUserOffType(OffTypeStr[OldType]);
    End;
  End;


Procedure AskOffNewFiles;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffNew;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(169), Tmp);
  User.SetUserOffNew(Tmp);
  End;


Procedure AskOffScrn;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffScrn;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(171), Tmp);
  User.SetUserOffScrn(Tmp);
  End;


Procedure AskOffBull;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffBull;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(170), Tmp);
  User.SetUserOffBull(Tmp);
  End;


Procedure AskOffVerify;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffVerify;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(359), Tmp);
  User.SetUserOffVerify(Tmp);
  End;


Procedure AskOffFlag;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffFlag;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(164), Tmp);
  User.SetUserOffFlag(Tmp);
  End;


Procedure AskOffOwn;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffOwn;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(360), Tmp);
  User.SetUserOffOwn(Tmp);
  End;


Procedure AskOffAllYour;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffAllYour;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(361), Tmp);
  User.SetUserOffAllYour(Tmp);
  End;


Procedure AskOffZero;
  Var
    Tmp: Boolean;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  Tmp := User.GetUserOffZero;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.AskYN(Prompts.GetString(362), Tmp);
  User.SetUserOffZero(Tmp);
  End;



Procedure AskOffMax;
  Var
    Tmp: LongInt;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  Tmp := User.GetUserOffMax;
  If Tmp = 0 Then
    Tmp := 1000;
  If Tmp > Config^.GetOffMax Then
    Tmp := Config^.GetOffMax;
  User.DisplayStr(Prompts.GetString(357) + ' ');
  Tmp := User.AskNumber(Tmp, 1, Config^.GetOffMax);
  If User.Ok Then
    User.SetUserOffMax(Tmp);
  End;


Procedure AskOffConfMax;
  Var
    Tmp: LongInt;

  Begin
  User.ResetLines(1);
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  Tmp := User.GetUserOffConfMax;
  If Tmp = 0 Then
    Tmp := 1000;
  If Tmp > Config^.GetOffConfMax Then
    Tmp := Config^.GetOffConfMax;
  User.DisplayStr(Prompts.GetString(358) + ' ');
  Tmp := User.AskNumber(Tmp, 1, Config^.GetOffConfMax);
  If User.Ok Then
    User.SetUserOffConfMax(Tmp);
  End;


Function ValidateOffline: Boolean;
  Var
    AskAll: Boolean;
    Cont: Boolean;

  Begin
  AskAll := False;
  If GetUserProtNum = 0 Then
    Begin
    SetProtocol;
    AskAll := True;
    End;
  Cont := GetUserProtNum <> 0;
  If ((GetUserPackerNum = 0) and Cont) Then
    Begin
    SetPacker;
    AskAll := True;
    End;
  Cont := GetUserPackerNum <> 0;
  If ((GetUserOffTypeNum = 0) and Cont) Then
    Begin
    SetOffType;
    AskAll := True;
    End;
  Cont := GetUserOffTypeNum <> 0;
  If ((User.GetUserOffMax = 0) and Cont) Then
    Begin
    AskOffMax;
    AskAll := True;
    End;
  Cont := User.GetUserOffMax > 0;
  If ((User.GetUserOffConfMax = 0) and Cont) Then
    Begin
    AskOffConfMax;
    AskAll := True;
    End;
  Cont := User.GetUserOffConfMax > 0;
  If (Cont and AskAll) Then
    Begin
    AskOffNewFiles;
    User.DisplayNewLine;
    AskOffScrn;
    User.DisplayNewLine;
    AskOffBull;
    User.DisplayNewLine;
    AskOffVerify;
    User.DisplayNewLine;
    AskOffFlag;
    User.DisplayNewLine;
    AskOffOwn;
    User.DisplayNewLine;
    AskOffAllYour;
    User.DisplayNewLine;
    AskOffZero;
    User.DisplayNewLine;
    End;
  ValidateOffline := Cont;
  End;


Function GetUserProtNum: Word;
  Var
    i: Word;

  Begin
  i := 1;
  While (i <= 20) and ((User.GetUserProt <> Config^.GetProtChar(i)) Or
  (Not Config^.GetProtNormAvail(i)))Do
    Inc(i);
  If (i <= 20) and ((User.GetUserProt = Config^.GetProtChar(i)) and
  (Config^.GetProtNormAvail(i))) Then
    GetUserProtNum := i
  Else
    GetUserProtNum := 0;
  End;


Function GetUserPackerNum: Word;
  Var
    i: Word;

  Begin
  i := 1;
  While (i <= 6) and ((User.GetUserPacker <> Config^.GetPackChar(i)) Or
  (Not Config^.GetPackAvail(i)))Do
    Inc(i);
  If (i <= 6) and ((User.GetUserPacker = Config^.GetPackChar(i)) and
  (Config^.GetPackAvail(i))) Then
    GetUserPackerNum := i
  Else
    GetUserPackerNum := 0;
  End;

Function  GetUserOffTypeNum: Word;
  Begin
  GetUserOffTypeNum := Pos(UpCase(User.GetUserOffType), 'QXBTP');
  End;


Procedure OfflineAuto;
  Begin
  OfflineUL;
  OfflineDL;
  End;


Procedure OfflineUL;
  {the reply packet of the caller: the code of the offline mail door (MKQwkO), run inside mk}
  Begin
  UploadFromBbs;
  End;


Function SendMail(FN: String; JustName: String): Boolean;
  Var
    XFerOk : Boolean;
    ProtNum: Word;
    Prot: ProtObj;


  Begin
  Prot.Init;
  Prot.AddSendFile(FN);
  XferOk := EstimateXferTime(SizeFile(FN), User.GetUserBaud, 90) <
    User.TimeRemain;
  If Not XferOk Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(126));
    User.DisplayNewLine;
    User.PressEnter;
    End;
  If XferOk Then
    Begin
    ProtNum := GetUserProtNum;
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(130));
    User.DisplayStrLn(Prompts.GetString(129));
    Case ProtNum of
      1: Prot.SetXmodem;
      2: Prot.SetX1k;
      3: Prot.SetYmodem;
      4: Prot.SetZmodem;
      5: Prot.SetYModemG;
      6: Prot.SetXmodemG;
      7: Prot.SetSealink;
      End;
    If ((ProtNum < 08) and (ProtNum > 0)) Then
      Begin
      CommFlow(fcHard);
      User.PostStatus(uoXfer);
      User.DisplayStrLn(Prompts.GetString(129) + ' ' + JustName);
      Prot.Send;
      CommFlow(fcBoth);
      User.DisplayNewLine;
      User.DisplayNewLine;
      XferOk := Prot.GetFileStatus(1) = 1;
      End
    End;
  Prot.Done;
  SendMail:= XferOk;
  End;


Procedure OfflineDL;
  Var
    Offline: AbsOffPtr;
    CurrArea: Word;
    OffType: Word;
    CMsg: AbsMsgPtr;
    NewLastRead: Array[1..500] of LongInt;
    i: Word;
    WorkPath: String[128];
    Cont: Boolean;
    SysopAccess: Boolean;
    NetAccess: Boolean;
    ToYou: Boolean;
    FromYou: Boolean;
    Sec: SecType;
    CName: String[35];
    CHdl: String[35];
    NumThisArea: Word;
    NumThisPkt: Word;
    Done: Boolean;
    PackCmd: String[128];
    TmpStr: String[128];
    PackNum: Word;
    MaxMsgs: Word;
    AreaMax: Word;

  Begin
  WorkPath := '';
  CName := Upper(User.GetUserName);
  CHdl := Upper(User.GetUserHandle);
  If Length(CHdl) = 0 Then
    CHdl := #8 + #255 + #0 + #13;
  MaxMsgs := User.GetUserOffMax;
  If Config^.GetOffMax < MaxMsgs Then
    MaxMsgs := Config^.GetOffMax;
  AreaMax := User.GetUserOffConfMax;
  If Config^.GetOffConfMax < AreaMax Then
    AreaMax := Config^.GetOffConfMax;
  User.PostStatus(uoMail);
  Offline := nil;
  For i := 1 to 500 Do
    NewLastRead[i] := -1;
  Cont := ValidateOffline;
  If Cont Then
    Begin
    Case UpCase(User.GetUserOffType) of
      'X': OffType := 2;
      'Q': OffType := 1;
      'B': OffType := 3;
      'T': OffType := 4;
      'P': OffType := 5;
      Else
        OffType := 0;
      End;
    If Config^.GetOffTypeAvail(OffType) Then
      Begin
      Case OffType of
        2: Offline := New(XRSOffPtr, Init);
        1: Offline := New(QwkOffPtr, Init);
        4: Offline := New(TxtOffPtr, Init);
        3: Offline := New(BwvOffPtr, Init);
        Else
          Cont := False;
        End;
      End
    Else
      Cont := False;
    End;
  If Offline = nil Then
    Cont := False;
  If Cont Then
    Begin
    WorkPath := CreateTempDir(Config^.GetTempPath);
    Cont := Length(WorkPath) > 0;
    End;
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Offline^.SetBBSID(Config^.GetBBSID);
    If Offline^.StartPacket <> 0 Then
      Cont := False;
    End;
  If Cont Then
    Begin
    NumThisPkt := 0;
    User.GetUserSec(Sec);
    CurrArea := 1;
    Done := False;
    While ((CurrArea <= Config^.GetMaxMsgAreas) and User.Ok and (Not Done)) Do
      Begin
      If Config^.MsgReadAccess(CurrArea, Sec) Then
        Begin
        If ((User.GetUserOffline(CurrArea) and
        Config^.GetMsgAllowOffline(CurrArea)) or
        Config^.GetMsgForceOffline(CurrArea)) Then
          Begin
          SysopAccess := Config^.MsgSysopAccess(CurrArea, Sec);
          NetAccess := (Config^.GetMsgNetStatus(CurrArea) and
            User.GetUserNetStatus) <> 0;
          NumThisArea := 0;
          If OpenMsgArea(CMsg, CurrArea) Then
            Begin
            User.DisplayStr(Config^.GetMsgName(CurrArea) + '      ');
            CMsg^.SeekFirst(CMsg^.GetLastRead(User.GetUserRecNum) + 1);
            While (CMsg^.SeekFound and (Not Done) and User.OK and
            (NumThisArea < AreaMax)) Do
              Begin
              CMsg^.MsgStartUp;
              FromYou := (Upper(CMsg^.GetFrom) = CName)
                Or (Upper(CMsg^.GetFrom) = CHdl);
              ToYou := (Upper(CMsg^.GetTo) = CName)
                Or (Upper(CMsg^.GetTo) = CHdl);
              If (Not CMsg^.IsPriv) or SysopAccess Or ToYou Or FromYou
              Or NetAccess Then
                Begin
                NewLastRead[CurrArea] := CMsg^.GetMsgNum;
                If Not Offline^.AddMsg(CMsg^, CurrArea, False) Then
                  Begin
                  User.DisplayNewLine;
                  User.DisplayStrLn(Prompts.GetString(364));
                  User.PressEnter;
                  Done := True;
                  End;
                Inc(NumThisArea);
                Inc(NumThisPkt);
                If NumThisPkt > MaxMsgs Then
                  Done := True;
                For i := 1 to 4 Do
                  User.DisplayBkSpc;
                User.DisplayStr(PadLeft(Long2Str(NumThisArea),' ', 4));
                End;
              CMsg^.SeekNext;
              End;
            If CloseMsgArea(CMsg) Then;
            End;
          User.DisplayNewLine;
          End;
        End;
      Inc(CurrArea);
      End;
    If Offline^.ClosePacket <> 0 Then
      Cont := False;
    End;
  PackNum := GetUserPackerNum;
  If Cont Then
    Begin
    If (PackNum > 0) Then
      Begin
      TmpStr := Config^.GetPackCmdLine(PackNum);
      TmpStr := StripBoth(TmpStr,' ');
      PackCmd := ExtractWord(TmpStr, 1);
      TmpStr := Copy(TmpStr, Length(PackCmd) + 1, 128);
      ChDir(StripTrail(StartUpPath, DirectorySeparator));
      Cont := IoResult = 0;
      End
    Else
      Cont := False;
    End;
  If Cont Then
    Begin
    If FindOnPath(PackCmd, PackCmd) Then
      Begin
      PackCmd := FExpand(PackCmd);
      End
    Else
      Cont := False;;
    End;
  If Cont Then
    Begin
    ChDir(StripTrail(WorkPath, DirectorySeparator));
    Cont := IoResult = 0;
    End;
  If Cont Then
    Begin
    If FileExist(PackCmd) Then
      Begin
      If CurrentPort = 0 Then
        TmpStr := PackCmd + ' ' + TmpStr + ' ' + WithBackSlash(StartUpPath) +
        Offline^.GetArchiveName(PackNum) + ' ' + '*.*'
      Else
        TmpStr := PackCmd + ' ' + TmpStr + ' ' + Offline^.GetArchiveName(PackNum) +
        ' ' + '*.*';
      End
    Else
      Cont := False;
    End;
  User.DisplayNewLine;
  User.DisplayStrLn(TmpStr);
  If Cont Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(189));
    DoShell(TmpStr, True, False);
    Cont := (GetResultCode = 0);
    End;
  If (Cont and (CurrentPort <> 0)) Then
    Begin
    Cont := SendMail(WorkPath + Offline^.GetArchiveName(PackNum),
      Offline^.GetArchiveName(PackNum));
    End;
  If Cont Then
    Begin
    { *** update last read *** }
    End;
  If Not Cont Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(364));
    User.PressEnter;
    End;
  If Offline <> nil Then
    Dispose(Offline, Done);
  ChDir(StripTrail(Config^.GetTempPath, DirectorySeparator));
  If IoResult <> 0 Then;
  ChDir(StripTrail(StartUpPath, DirectorySeparator));
  If IoResult <> 0 Then;
  If Length(WorkPath) > 0 Then
    Begin
    CleanDir(WithBackSlash(WorkPath));
    RmDir(StripTrail(WorkPath, DirectorySeparator));
    If IoResult <> 0 Then;
    End;
  User.PostStatus(uoBrowse);
  End;

End.
