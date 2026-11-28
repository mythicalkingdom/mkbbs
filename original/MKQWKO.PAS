Unit MKQwkO;
{$I MKB.Def}

Interface

{
     MKQwkO - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}



Procedure ProcessCmdLine;
Procedure MainQwk;


Implementation


Uses MKFile, MKString, MKQwkG, MKCfgAbs, MKGlobT, Dos, MKDos, MKStr,
  MKUsrAbs, MKUsrMK, MKUsrRA2, MKAvatar, MKMisc, MKSelect, MKMsgJam,
  MKOffAbs, MKOffTxt, MKOffQwk, MKOffBwv, {MKOffXrs,}
  {$IFDEF OPRO}
  OpCrt,
  {$ELSE}
  Crt,
  {$ENDIF}
  MKOpen, MKMsgAbs, MKComAbs, MKComFos;


Var
  QwkMode: Byte;                       {0=local   1=local reply UL   2=normal}
                                       {3=bbs auto   4=bbs dl   5=bbs ul}
  LocalName: String[35];
  Prmpts: ^StrObj;
  ComP: ^AbsComObj;
  PortNum: Byte;
  PortBaud: LongInt;
  DorGraph: Byte;
  DorTime: LongInt;
  LangName: String[8];
  InclHelp: Boolean;
  WorkPath: String[128];


Function CvtProtStr(PStr:String; FileName:String): String;
  Var
    i: Word;
    v: Word;
    TStr: String;
    CvtState: Word; {0=normal, 1=have percent}

  Begin
  i := 1;
  CvtState := 0;
  TStr := '';
  While i <= Length(PStr) Do
    Begin
    If CvtState = 0 Then
      Begin
      If PStr[i] = '%' Then
        Begin
        CvtState := 1;
        End
      Else
        Begin
        TStr[0] := Chr(Length(TStr) + 1);
        TStr[Length(TStr)] := PStr[i];
        End;
      End
    Else
      Begin
      Case UpCase(PStr[i]) of
        '%': Begin
             TStr := TStr + '%';
             End;
        'P': Begin
             CvtState := 0;
             TStr := TStr + Long2Str(PortNum);
             End;
        'B': Begin
             CvtState := 0;
             TStr := TStr + Long2Str(BBSUser^.GetUserBaud);
             End;
        'F': Begin
             CvtState := 0;
             TStr := TStr + FileName;
             End;
        'L': Begin
             If QCfg.LockedBaud = 0 Then
               TStr := TStr + Long2Str(BBSUser^.GetUserBaud)
             Else
               TStr := TStr + Long2Str(QCfg.LockedBaud);
             CvtState := 0;
             End;
        'N': Begin
             MKStrCat(TStr, BBSUser^.GetUserName);
             End;
        Else
             Begin
             TStr := TStr + '%' + PStr[i];
             CvtState := 0;
             End;
        End;
      End;
    Inc(i);
    End;
  If CvtState = 1 Then
    Begin
    TStr[0] := Chr(Length(TStr) + 1);
    TStr[Length(TStr)] := '%';
    End;
  CvtProtStr := TStr;
  End;


Procedure UToSpace(Var ST: String);
  Var
    i: Word;

  Begin
  For i := 1 to Length(ST) Do
    Begin
    If St[i] = '_' Then
      St[i] := ' ';
    End;
  End;


Procedure ProcessCmdLine;
  Var
    i: Word;
    TmpStr: String;

  Begin
  QwkMode := 2;
  LocalName := '';
  InclHelp := False;
  LangName := 'PROMPTS';
  i := 1;
  While i <= ParamCount Do
    Begin
    TmpStr := Upper(ParamStr(i));
    If ((TmpStr[1] = '-') or (TmpStr[1] = '/')) Then
      Begin
      Case TmpStr[2] of
        'L': Begin
             QwkMode := 0;
             LocalName := Copy(TmpStr, 3, 35);
             UToSpace(LocalName);
             End;
        'R': Begin
             QwkMode := 1;
             LocalName := Copy(TmpStr, 3, 35);
             UToSpace(LocalName);
             End;
        'A': QwkMode := 3;
        'D': QwkMode := 4;
        'U': QwkMode := 5;
        'P': LangName := Copy(TmpStr, 3, 8);
        End;
      End;
    Inc(i);
    End;
  End;


Function InitBBSUser: Boolean;
  Begin
  InitBBSUser := True;
  Case Config^.GetBBSType of
    1: BBSUser := New(MKUsrObjPtr, Init);
    2: BBSUser := New(RA2UsrObjPtr, Init);
    Else
      BBSUser := New(MKUsrObjPtr, Init);
    End;
  If BBSUser = nil Then
    InitBBSUser := False
  Else
    Begin
    BBSUser^.SetUserFileName(Config^.GetUserFileName);
    End;
  End;


Procedure SetLastRead(CurrArea: Word; LR: LongInt);
  Var
    CMsg: AbsMsgPtr;

  Begin
  If InitMsgPtr(CMsg, Config^.GetMsgAreaId(CurrArea)) Then
    Begin
    If Upper(Copy(Config^.GetMsgAreaId(CurrArea),1,1)) = 'J' Then
      CMsg^.SetLastRead(JamStrCrc(BBSUser^.GetUserName), LR)
    Else
      CMsg^.SetLastRead(BBSUser^.GetUserRecNum, LR);
    If DoneMsgPtr(CMsg) Then;
    End;
  End;


Function GetLastRead(CurrArea: Word): LongInt;
  Var
    CMsg: AbsMsgPtr;

  Begin
  GetLastRead := 0;
  If InitMsgPtr(CMsg, Config^.GetMsgAreaId(CurrArea)) Then
    Begin
    If Upper(Copy(Config^.GetMsgAreaId(CurrArea),1,1)) = 'J' Then
      GetLastRead := CMsg^.GetLastRead(JamStrCrc(BBSUser^.GetUserName))
    Else
      GetLastRead := CMsg^.GetLastRead(BBSUser^.GetUserRecNum);
    If DoneMsgPtr(CMsg) Then;
    End;
  End;


Procedure ClearAndDisp(St: String);
  Begin
  BBSUser^.DisplayChr(#13);
  BBSUser^.DisplayStr(PadRight('',' ',78));
  BBSUser^.DisplayChr(#13);
  BBSUser^.DisplayStr(St);
  BBSUser^.DisplayChr(' ');
  End;


{$F+}
Procedure HandleSelect(CurrNum: Word; Var Finished: Boolean; Var
  IsSel: Byte);
  Var
    TmpChr: Char;
    CStr: String[128];
    SType: Word;
    LR: LongInt;

  Begin
  CStr := BBSUser^.GetPrompt(513);
  ClearAndDisp(BBSUser^.GetPrompt(514));
  TmpChr := BBSUser^.AskChoice(CStr);
  SType := Pos(TmpChr, CStr);
  Case SType of
    1: IsSel := qctOn;
    2: IsSel := qctNone;
    3: IsSel := qctMy;
    4: IsSel := qctAll;
    End;
  If ((IsSel = qctOn) or (IsSel = qctAll)) Then
    Begin
    LR := GetLastRead(CurrNum);
    CStr := BBSUser^.GetPrompt(199);
    MKStrCat(CStr, ' ');
    MKStrCat(CStr, BBSUser^.DefaultNumStr(LR));
    ClearAndDisp(CStr);
    LR := BBSUser^.AskNumber(LR, 1, $fffffff);
    SetLastRead(CurrNum, LR);
    End;
  End;


{$F+}
Function GetAreaStr(CurrNum: Word; IsSel: Byte): String;
  Var
    Tmp: String[2];

  Begin
  Case IsSel Of
    qctNone: Tmp := '  ';
    qctOn: Tmp := '* ';
    qctMy: Tmp := Copy(BBSUser^.GetPrompt(513), 3, 1) + ' ';
    qctAll: Tmp := Copy(BBSUser^.GetPrompt(513), 4, 1) + ' ';
    Else
      Tmp := '  ';
    End;
  GetAreaStr := Tmp + PadLeft(Long2Str(CurrNum),' ', 5) + ' ' +
    Config^.GetMsgName(CurrNum);
  End;


Procedure SelectConfs;
  Var
    Select: SelectObj;
    i: Word;
    NumAct: Word;
    Sec: SecType;

  Begin
  BBSUser^.ClearScreen;
  BBSUser^.GetUserSec(@Sec);
  Select.Init;
  Select.SetColumnTextWidth(22);
  Select.SetPromptStr(BBSUser^.GetPrompt(246), BBSUser^.GetPrompt(247));
  Select.SetUserPtr(BBSUser);
  Select.SetSelectProc(HandleSelect);
  Select.SetTextProc(GetAreaStr);
  Select.SetColAttr(1, 15, 2);
  Select.SetColAttr(2, 11 , 7);
  Select.SetColAttr(3, 10 , 0);
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    If Config^.MsgReadAccess(i, Sec) and (Length(Config^.GetMsgName(i)) > 0) Then
      Select.SetAvailable(i, True)
    Else
      Select.SetAvailable(i, False);
    End;
  For i := 1 to QwkUserAreas Do
    Begin
    Case QwkUser.UserConfs[i].Typ of
      qctOn: Select.SetChosen(QwkUser.UserConfs[i].Area, qctOn);
      qctMy: Select.SetChosen(QwkUser.UserConfs[i].Area, qctMy);
      qctAll: Select.SetChosen(QwkUser.UserConfs[i].Area, qctAll);
      End;
    End;
  Select.Process;
  NumAct := 0;
  For i := 1 to QwkUserAreas Do
    Begin
    QwkUser.UserConfs[i].Typ := qctNone;
    QwkUser.UserConfs[i].Area := 0;
    End;
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    If Select.IsChosen(i) <> qctNone Then
      Begin
      If NumAct < QwkUserAreas Then
        Begin
        Inc(NumAct);
        QwkUser.UserConfs[NumAct].Area := i;
        QwkUser.UserConfs[NumAct].Typ := Select.IsChosen(i);
        End;
      End;
    End;
  Select.Done;
  End;


Procedure DoYN(QuesStr: String; Var Awsr: Boolean; Lim: Byte);
  Begin
  Case Lim Of
    0: Begin
       Awsr := False;
       BBSUser^.SendPromptLn(172);
       BBSUser^.PressEnter;
       End;
    1: Begin
       Awsr := True;
       BBSUser^.SendPromptLn(172);
       End;
    2..4: Begin
       BBSUser^.AskYN(QuesStr, Awsr);
       End;
    End;
  End;


Function DisplayFile(FileName: String; HotStr: String): Char;

  Var
    AFile: File;
    Buffer: Array[1..256] of Char;
    I: Word;
    NumRead: Word;
    Ext: String[4];
    KeyChar: Char;

  Begin
  KeyChar := #0;
  HotStr := Upper(HotStr);
  If ((DorGraph > 1) and FileExist(QCfg.ScreenPath + FileName + '.AVT')) Then
    Ext := '.AVT'
  Else If ((DorGraph > 0) and FileExist(QCfg.ScreenPath + FileName + '.ANS')) Then
    Ext := '.ANS'
  Else
    Ext := '.ASC';
  If Not shAssign (Afile, QCfg.ScreenPath + FileName + Ext) Then;
  FileMode := fmReadOnly + fmDenyNone;
  If shReset (Afile,1) Then
    Begin
    While ((Not Eof(Afile)) and (KeyChar = #0)) Do
      Begin
      BlockRead(Afile,Buffer, 255, NumRead);
      If IoResult <> 0 Then;
      i := 1;
      While i <= NumRead Do
        Begin
        ComP^.SendChar(Buffer[i]);
        AvatarChar(Buffer[i]);
        Inc(i);
        End;
      If Not ComP^.InEmpty Then
        Begin
        KeyChar := UpCase(ComP^.GetChar);
        If Pos(KeyChar, HotStr) = 0 Then
          KeyChar := #0;
        End;
      End;
    Close(Afile);
    If IoResult <> 0 Then;
    End;
  DisplayFile := KeyChar;
  End;


Procedure AskProtocol;
  Var
    i: Word;
    TStr: String;
    CStr: String[20];
    PNum: Array[1..20] of Byte;
    TmpChr: Char;

  Begin
  CStr := '';
  TStr := Upper(BBSUser^.GetPrompt(499));
  BBSUser^.DisplayNewLine;
  For i := 1 to 10 Do
    Begin
    If QCfg.Prots[i].ProtActive Then
      Begin
      Inc(CStr[0]);
      CStr[Length(CStr)] := TStr[i];
      PNum[Length(CStr)] := i;
      BBSUser^.DisplayAttr(1);
      BBSUser^.SendPrompt(12);
      BBSUser^.DisplayAttr(11);
      BBSUser^.DisplayChr(TStr[i]);
      BBSUser^.DisplayAttr(1);
      BBSUser^.SendPrompt(13);
      BBSUser^.DisplayAttr(3);
      BBSUser^.DisplayChr(' ');
      BBSUser^.SendPromptLn(i + 499);
      End;
    End;
  BBSUser^.DisplayNewLine;
  BBSUser^.DisplayAttr(15);
  BBSUser^.SendPrompt(165);
  BBSUser^.DisplayChr(' ');
  If Pos(QwkUser.Protocol, CStr) > 0 Then
    CStr := CStr + #13;
  TmpChr := UpCase(BBSUser^.AskChoice(CStr));
  If ((TmpChr <> #13) and (Pos(TmpChr, CStr) > 0)) Then
    QwkUser.Protocol := TmpChr;
  i := Pos(QwkUser.Protocol, CStr);
  BBSUser^.SendPromptLn(PNum[i] + 499);
  BBSUser^.DisplayNewLine;
  End;



Function GetProtNum: Word;
  Var
    CStr: String[20];
    TStr: String[20];
    PNum: Array[1..20] of Byte;
    i: Word;

  Begin
  CStr := '';
  TStr := Upper(BBSUser^.GetPrompt(499));
  For i := 1 to 10 Do
    Begin
    If QCfg.Prots[i].ProtActive Then
      Begin
      Inc(CStr[0]);
      CStr[Length(CStr)] := TStr[i];
      PNum[Length(CStr)] := i;
      End;
    End;
  If Pos(UpCase(QwkUser.Protocol), CStr) = 0 Then
    AskProtocol;
  GetProtNum := PNum[Pos(UpCase(QwkUser.Protocol), CStr)];
  End;


Function GetProtStr(ProtNum: Word; DoSend: Boolean; JustName: String): String;
  Var
    TmpStr: String[128];
    ProtCmd: String[128];

  Begin
  If DoSend Then
    TmpStr := QCfg.Prots[ProtNum].SendCmd
  Else
    TmpStr := QCfg.Prots[ProtNum].RcvCmd;
  TmpStr := StripBoth(TmpStr,' ');
  ProtCmd := ExtractWord(TmpStr, 1);
  TmpStr := Copy(TmpStr, Length(ProtCmd) + 1, 128);
  ChDir(StripTrail(OrigDir,'\'));
  If ((Pos(':', ProtCmd) = 0) and (Pos('\', ProtCmd) = 0)) Then
    Begin
    If FindOnPath(ProtCmd, ProtCmd) Then
      ProtCmd := FExpand(ProtCmd);
    End;
  ChDir(StripTrail(WorkPath, '\'));
  GetProtStr := ProtCmd + ' ' + CvtProtStr(TmpStr, JustName);
  End;


Function SendMail(FN: String; JustName: String): Boolean;
  Var
    XFerOK : Boolean;
    ProtNum: Word;
    TryAgain: Boolean;
    TmpStr: String;

  Begin
  TryAgain := True;
  While TryAgain Do
    Begin
    ProtNum := GetProtNum;
    XferOk := (ProtNum > 0) and (ProtNum < 11);
    If XferOk Then
      XferOk := EstimateXferTime(SizeFile(FN), BBSUser^.GetUserBaud, 90) <
      BBSUser^.TimeRemain;
    If Not XferOk Then
      Begin
      BBSUser^.DisplayNewLine;
      BBSUser^.DisplayAttr(Config^.GetSystemColor(1));
      BBSUser^.SendPromptLn(126);
      BBSUser^.DisplayNewLine;
      BBSUser^.PressEnter;
      End;
    If XferOk Then
      Begin
      BBSUser^.DisplayNewLine;
      BBSUser^.DisplayAttr(Config^.GetSystemColor(1));
      BBSUser^.SendPromptLn(130);
      BBSUser^.SendPrompt(129);
      BBSUser^.DisplayStrLn(' ' + JustName);
      TmpStr := GetProtStr(ProtNum, True, JustName);
      ComP^.ClosePort;
      BBSUser^.DoShell(TmpStr, True);
      ComP^.CommResume;
      XFerOk := (GetResultCode = 0);
      End;
    TryAgain := False;
    If Not XferOk Then
      Begin
      {** Ask try again **}
      If TryAgain Then
        AskProtocol;
      End;
    End;
  SendMail := XferOk;
  End;


Function ValidateOffline: Boolean;
  Begin
  ValidateOffline := True;
  End;



Procedure UpdateStatus(FullScrn: Boolean; SMsg: String);
  Begin
  If FullScrn Then
    BBSUser^.DisplayXY(33, 3)
  Else
    BBSUser^.DisplayNewLine;
  BBSUser^.DisplayAttr(15);
  BBSUser^.DisplayStr(PadRight(Copy(SMsg, 1 ,25),' ', 25));
  End;


Procedure UpdateNumPkt(FullScrn: Boolean; NP: LongInt);
  Begin
  If FullScrn Then
    Begin
    BBSUser^.DisplayXY(68, 3);
    BBSUser^.DisplayAttr(15);
    BBSUser^.DisplayStr(PadLeft(Long2Str(NP),' ', 5));
    End;
  End;


Procedure UpdateNumArea(FullScrn: Boolean; NA: LongInt);
  Var
    i: Word;

  Begin
  If FullScrn Then
    Begin
    BBSUser^.DisplayXY(68, 9);
    BBSUser^.DisplayAttr(15);
    BBSUser^.DisplayStr(PadLeft(Long2Str(NA),' ', 5));
    End
  Else
    Begin
    For i := 1 to 4 Do
      BBSUser^.DisplayBkSpc;
    BBSUser^.DisplayStr(PadLeft(Long2Str(NA),' ', 4));
    End;
  End;


Procedure UpdateArea(FullScrn: Boolean; NA: LongInt; CA: Word);
  Begin
  If FullScrn Then
    BBSUser^.DisplayXY(33, 9)
  Else
    BBSUser^.DisplayNewLine;
  BBSUser^.DisplayAttr(15);
  BBSUser^.DisplayStr(PadRight(Copy(Config^.GetMsgName(CA),1,25),' ', 25));
  UpdateNumArea(FullScrn, 0);
  End;


Procedure AskPacker;
  Var
    i: Word;
    TStr: String;
    CStr: String[20];
    PNum: Array[1..20] of Byte;
    TmpChr: Char;

  Begin
  CStr := '';
  TStr := Upper(BBSUser^.GetPrompt(488));
  BBSUser^.DisplayNewLine;
  For i := 1 to 10 Do
    Begin
    If QCfg.Packers[i].PackActive Then
      Begin
      Inc(CStr[0]);
      CStr[Length(CStr)] := TStr[i];
      PNum[Length(CStr)] := i;
      BBSUser^.DisplayAttr(1);
      BBSUser^.SendPrompt(12);
      BBSUser^.DisplayAttr(11);
      BBSUser^.DisplayChr(TStr[i]);
      BBSUser^.DisplayAttr(1);
      BBSUser^.SendPrompt(13);
      BBSUser^.DisplayAttr(3);
      BBSUser^.DisplayChr(' ');
      BBSUser^.SendPromptLn(i + 488);
      End;
    End;
  BBSUser^.DisplayNewLine;
  BBSUser^.DisplayAttr(15);
  BBSUser^.SendPrompt(160);
  BBSUser^.DisplayChr(' ');
  If Pos(QwkUser.Packer, CStr) > 0 Then
    CStr := CStr + #13;
  TmpChr := UpCase(BBSUser^.AskChoice(CStr));
  If ((TmpChr <> #13) and (Pos(TmpChr, CStr) > 0)) Then
    QwkUser.Packer := TmpChr;
  i := Pos(QwkUser.Packer, CStr);
  BBSUser^.SendPromptLn(PNum[i] + 488);
  BBSUser^.DisplayNewLine;
  End;


Function GetPackNum: Word;
  Var
    CStr: String[20];
    TStr: String[20];
    PNum: Array[1..20] of Byte;
    i: Word;

  Begin
  CStr := '';
  TStr := Upper(BBSUser^.GetPrompt(488));
  For i := 1 to 10 Do
    Begin
    If QCfg.Packers[i].PackActive Then
      Begin
      Inc(CStr[0]);
      CStr[Length(CStr)] := TStr[i];
      PNum[Length(CStr)] := i;
      End;
    End;
  If Pos(QwkUser.Packer, CStr) = 0 Then
    AskPacker;
  GetPackNum := PNum[Pos(UpCase(QwkUser.Packer), CStr)];
  End;


Procedure OfflineUL(BatchMode: Boolean);
  Begin
  { ** ** }
  { ** non batch do upload}
  { ** unpack archives}
  { ** process packet}
  { ** clean up}
  End;


Procedure OfflineDL(BatchMode: Boolean);
  Var
    Offline: AbsOffPtr;
    CurrArea: Word;
    AreaCount: Word;
    CMsg: AbsMsgPtr;
    NewLastRead: Array[1..200] of LongInt;
    i: Word;
    Cont: Boolean;
    SysopAccess: Boolean;
    NetAccess: Boolean;
    ToYou: Boolean;
    FromYou: Boolean;
    ToAll: Boolean;
    MsgOk: Boolean;
    Sec: SecType;
    CName: String[35];
    CHdl: String[35];
    NumThisArea: Word;
    NumThisPkt: Word;
    NumAreas: Word;
    Done: Boolean;
    PackCmd: String;
    TmpStr: String;
    PackNum: Word;
    MaxMsgs: Word;
    AreaMax: Word;
    FullScrn: Boolean;

  Begin
  NumThisPkt := 0;
  NumAreas := 0;
  FullScrn := BBSUser^.GetUserAnsi or BBSUser^.GetUserAvatar;
  If FullScrn Then
    Begin
    If DisplayFile('MKO-PROC','') = ' ' Then;
    End
  Else
    BBSUser^.ClearScreen;
  UpdateStatus(FullScrn, BBSUser^.GetPrompt(366));
  CName := Upper(BBSUser^.GetUserName);
  CHdl := Upper(BBSUser^.GetUserHandle);
  If Length(CHdl) = 0 Then
    CHdl := #8#255#0#13#65;
  MaxMsgs := QwkUser.MaxMsgs;
  If QCfg.MaxMsgs < MaxMsgs Then
    MaxMsgs := QCfg.MaxMsgs;
  AreaMax := QwkUser.MaxConfMsgs;
  If QCfg.MaxConfMsgs < AreaMax Then
    AreaMax := QCfg.MaxConfMsgs;
  Offline := nil;
  For i := 1 to 200 Do
    NewLastRead[i] := -1;
  Cont := ValidateOffline;
  If Cont Then
    Begin
    Case QwkUser.MailType of
      {qmtXRS: Offline := New(XRSOffPtr, Init);}
      qmtQwk: Offline := New(QwkOffPtr, Init);
      qmtText: Offline := New(TxtOffPtr, Init);
      qmtBwv: Offline := New(BwvOffPtr, Init);
      Else
        Cont := False;
      End;
    End;
  If Offline = nil Then
    Cont := False;
  If Cont Then
    Begin
    Offline^.SetBBSId(QCfg.BoardId);
    Offline^.SetUsrPtr(BBSUser);
    WorkPath := CreateTempDir(QCfg.TempPath);
    Cont := Length(WorkPath) > 0;
    End;
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Cont := (Offline^.StartPacket = 0);
    End;
  If Cont Then
    Begin
    BBSUser^.GetUserSec(@Sec);
    AreaCount := 1;
    Done := False;
    While ((AreaCount <= 200) and (Not Done)) Do
      Begin
      If ((QwkUser.UserConfs[AreaCount].Area > 0) and
      (QwkUser.UserConfs[AreaCount].Typ <> qctNone)) Then
        Begin
        CurrArea := QwkUser.UserConfs[AreaCount].Area;
        If Config^.MsgReadAccess(CurrArea, Sec) Then
          Begin
          Inc(NumAreas);
          NumThisArea := 0;
          If OpenMsgArea(CMsg, Config^.GetMsgAreaId(CurrArea)) Then
            Begin
            UpdateArea(FullScrn, NumAreas, CurrArea);
            CMsg^.SeekFirst(GetLastRead(CurrArea) + 1);
            While (CMsg^.SeekFound and (Not Done) and (NumThisArea < AreaMax)) Do
              Begin
              CMsg^.MsgStartUp;
              FromYou := (Upper(CMsg^.GetFrom) = CName)
                Or (Upper(CMsg^.GetFrom) = CHdl);
              ToYou := (Upper(CMsg^.GetTo) = CName)
                Or (Upper(CMsg^.GetTo) = CHdl);
              ToAll := (Upper(CMsg^.GetTo) = 'ALL');
              If (Not CMsg^.IsPriv) or SysopAccess Or ToYou Or FromYou
              Or NetAccess Then
                Begin
                Case QwkUser.UserConfs[AreaCount].Typ Of
                  qctNone: MsgOk := False;
                  qctOn: MsgOk := True;
                  qctMy: MsgOk := ToYou;
                  qctAll: MsgOk := ToYou or ToAll;
                  End;
                If MsgOk Then
                  Begin
                  NewLastRead[AreaCount] := CMsg^.GetMsgNum;
                  If Not Offline^.AddMsg(CMsg^, CurrArea, False) Then
                    Begin
                    BBSUser^.DisplayNewLine;
                    BBSUser^.DisplayStrLn(BBSUser^.GetPrompt(364));
                    BBSUser^.PressEnter;
                    Done := True;
                    End;
                  Inc(NumThisArea);
                  Inc(NumThisPkt);
                  If NumThisPkt > MaxMsgs Then
                    Done := True;
                  If (NumThisArea Mod 5) = 0 Then
                    UpdateNumArea(FullScrn, NumThisArea);
                  If (NumThisPkt Mod 5) = 0 Then
                    UpdateNumPkt(FullScrn, NumThisPkt);
                  End;
                If (Not Batchmode) and (Not Done) Then
                  Done := Not BBSUser^.Ok;
                End;
              CMsg^.SeekNext;
              End;
            UpdateNumArea(FullScrn, NumThisArea);
            If CloseMsgArea(CMsg) Then;
            If Not FullScrn Then
              BBSUser^.DisplayNewLine;
            End;
          End;
        End;
      Inc(AreaCount);
      End;
    UpdateNumPkt(FullScrn, NumThisPkt);
    If Offline^.ClosePacket <> 0 Then
      Cont := False;
    End;
  PackNum := GetPackNum;
  If Cont Then
    Begin
    If ((PackNum > 0) and (Qcfg.Packers[PackNum].PackActive)) Then
      Begin
      TmpStr := QCfg.Packers[PackNum].PackCmd;
      TmpStr := StripBoth(TmpStr,' ');
      PackCmd := ExtractWord(TmpStr, 1);
      TmpStr := Copy(TmpStr, Length(PackCmd) + 1, 128);
      ChDir(StripTrail(OrigDir,'\'));
      If ((Pos(':', PackCmd) = 0) and (Pos('\', PackCmd) = 0)) Then
        Begin
        If FindOnPath(PackCmd, PackCmd) Then
          PackCmd := FExpand(PackCmd)
        Else
         Cont := False;;
        End;
      End
    Else
      Cont := False;
    End;
  If Cont Then
    Cont := FileExist(PackCmd);
  If Cont Then
    Begin
    ChDir(StripTrail(WorkPath, '\'));
    Cont := IoResult = 0;
    End;
  If Cont Then
    Begin
    If BatchMode Then
      TmpStr := PackCmd + ' ' + TmpStr + ' ' + WithBackSlash(OrigDir) +
      Offline^.GetArchiveName(PackNum) + ' ' + '*.*'
    Else
      TmpStr := PackCmd + ' ' + TmpStr + ' ' + Offline^.GetArchiveName(PackNum) +
      ' ' + '*.*';
    End;
  If Cont Then
    Begin
    UpdateStatus(FullScrn, BBSUser^.GetPrompt(189));
    BBSUser^.DoShell(TmpStr, True);
    Cont := (GetResultCode = 0);
    End;
  If (Cont and FullScrn) Then
    BBSUser^.DisplayXY(1, 13);
  If (Cont and (Not BatchMode)) Then
    Begin
    Cont := SendMail(WorkPath + Offline^.GetArchiveName(PackNum),
      Offline^.GetArchiveName(PackNum));
    End;
  If Cont Then
    Begin
    For AreaCount := 1 to 200 Do
      Begin
      If NewLastRead[AreaCount] >= 0 Then
        Begin
        CurrArea := QwkUser.UserConfs[AreaCount].Area;
        SetLastRead(CurrArea, NewLastRead[AreaCount]);
        End;
      End;
    End;
  If Not Cont Then
    Begin
    BBSUser^.DisplayNewLine;
    BBSUser^.DisplayAttr(Config^.GetSystemColor(1));
    BBSUser^.DisplayStrLn(BBSUser^.GetPrompt(364));
    BBSUser^.PressEnter;
    End;
  If Offline <> nil Then
    Dispose(Offline, Done);
  ChDir('\');
  If IoResult <> 0 Then;
  ChDir(StripTrail(Config^.GetTempPath,'\'));
  If IoResult <> 0 Then;
  ChDir(StripTrail(OrigDir,'\'));
  If IoResult <> 0 Then;
  If Length(WorkPath) > 0 Then
    Begin
    CleanDir(WithBackSlash(WorkPath));
    RmDir(StripTrail(WorkPath,'\'));
    If IoResult <> 0 Then;
    End;
  End;


Procedure ReadDorInfo;
  Var
    I: Word;
    TmpStr: String;
    Code: Word;
    DFile: TFile;


  Begin
  DFile.Init;
  If Not FileExist('DORINFO1.DEF') Then
    WriteLn('Unable to find '+  'DorInfo1.Def');
  If Not DFile.OpenTextFile('DORINFO1.DEF') Then
    WriteLn('Unable to open DorInfo1.Def');
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString;
  PortNum := Ord(TmpStr[4]) - Ord('0');
  TmpStr := DFile.GetString;
  I := Pos(' ',TmpStr);
  Val(Copy(TmpStr, 1, i-1), PortBaud, Code);
  TmpStr := DFile.GetString;
  TmpStr := DFile.GetString; {name}
  TmpStr := DFile.GetString; {name}
  TmpStr := DFile.GetString; {city}
  TmpStr := DFile.GetString; {graphics}
  DorGraph := Str2Long(StripBoth(TmpStr, ' '));
  TmpStr := DFile.GetString; {sec level}
  TmpStr := DFile.GetString; {time limit in minutes}
  DorTime := Str2Long(StripBoth(TmpStr,' '));
  If Not DFile.CloseTextFile Then
    WriteLn('Unable to close DorInfo1.Def');
  DFile.Done;
  End;


Procedure ProcessLocalReplies;
  Begin
  OfflineUL(True);
  End;


Procedure ProcessLocalMail;
  Begin
  OfflineDL(True);
  End;


Procedure AskOffMailType;
  Var
    i: Word;
    CStr: String;
    TmpChr: Char;

  Begin
  CStr := Upper(Copy(BBSUser^.GetPrompt(345), 1, 5));
  BBSUser^.DisplayNewLine;
  For i := 1 to 5 Do
    Begin
    BBSUser^.DisplayAttr(1);
    BBSUser^.SendPrompt(12);
    BBSUser^.DisplayAttr(11);
    BBSUser^.DisplayChr(CStr[i]);
    BBSUser^.DisplayAttr(1);
    BBSUser^.SendPrompt(13);
    BBSUser^.DisplayAttr(3);
    BBSUser^.DisplayChr(' ');
    BBSUser^.SendPromptLn(i + 345);
    End;
  BBSUser^.DisplayNewLine;
  BBSUser^.DisplayAttr(15);
  BBSUser^.SendPrompt(356);
  BBSUser^.DisplayChr(' ');
  If ((QwkUser.MailType > 0) and (QwkUser.MailType < 6)) Then
    CStr := CStr + #13;
  TmpChr := BBSUser^.AskChoice(CStr);
  Case Pos(UpCase(TmpChr), CStr) of
    1: QwkUser.MailType := qmtQwk;
    2: QwkUser.MailType := qmtXrs;
    3: QwkUser.MailType := qmtBwv;
    4: QwkUser.MailType := qmtText;
    5: QwkUser.MailType := qmtPkt;
    End;
  Case  QwkUser.MailType of
    qmtQwk: BBSUser^.SendPromptLn(346);
    qmtXrs: BBSUser^.SendPromptLn(347);
    qmtBwv: BBSUser^.SendPromptLn(348);
    qmtText: BBSUser^.SendPromptLn(349);
    qmtPkt: BBSUser^.SendPromptLn(350);
    End;
  BBSUser^.DisplayNewLine;
  End;


Procedure StrDisplay(St: String; Info: String);
  Begin
  BBSUser^.DisplayAttr(11);
  BBSUser^.DisplayStr(St);
  BBSUser^.DisplayChr(' ');
  BBSUser^.DisplayAttr(10);
  BBSUser^.DisplayStrLn(Info);
  End;


Procedure InfoDisplay(St: String; Info: Boolean);
  Begin
  BBSUser^.DisplayAttr(11);
  BBSUser^.DisplayStr(St);
  BBSUser^.DisplayChr(' ');
  BBSUser^.DisplayAttr(10);
  If Info Then
    BBSUser^.SendPromptLn(3)
  Else
    BBSUser^.SendPromptLn(4);
  End;

Procedure DisplayCfg;
  Begin
  BBSUser^.ClearScreen;
  BBSUser^.DisplayNewLine;
  StrDisplay(BBSUser^.GetPrompt(520), BBSUser^.GetUserName);
  InfoDisplay(BBSUser^.GetPrompt(521), (QwkUser.Attr and quaNewFile <> 0));
  InfoDisplay(BBSUser^.GetPrompt(522), (QwkUser.Attr and quaScreens <> 0));
  InfoDisplay(BBSUser^.GetPrompt(523), (QwkUser.Attr and quaBulletin <> 0));
  StrDisplay(BBSUser^.GetPrompt(524), Long2Str(QwkUser.MaxMsgs));
  StrDisplay(BBSUser^.GetPrompt(525), Long2Str(QwkUser.MaxConfMsgs));
  {prot 526}
  {packer 527}
  InfoDisplay(BBSUser^.GetPrompt(528), (QwkUser.Attr and quaFlagRead <> 0));
  InfoDisplay(BBSUser^.GetPrompt(529), (QwkUser.Attr and quaOwnMsgs <> 0));
  InfoDisplay(BBSUser^.GetPrompt(530), (QwkUser.Attr and quaAllYours <> 0));
  InfoDisplay(BBSUser^.GetPrompt(531), (QwkUser.Attr and quaNoMsg <> 0));
  InfoDisplay(BBSUser^.GetPrompt(532), (QwkUser.Attr and quaAskPkt <> 0));
  Case QwkUser.MailType of
    qmtQwk: StrDisplay(BBSUser^.GetPrompt(533), BBSUser^.GetPrompt(346));
    qmtXrs: StrDisplay(BBSUser^.GetPrompt(533), BBSUser^.GetPrompt(347));
    qmtBwv: StrDisplay(BBSUser^.GetPrompt(533), BBSUser^.GetPrompt(348));
    qmtText: StrDisplay(BBSUser^.GetPrompt(533), BBSUser^.GetPrompt(349));
    qmtPkt: StrDisplay(BBSUser^.GetPrompt(533), BBSUser^.GetPrompt(350));
    End;
  BBSUser^.DisplayNewLine;
  BBSUser^.PressEnter;
  End;


Procedure CfgMenu;
  Var
    TmpChr: Char;
    MenuDone: Boolean;
    ChoiceStr: String;
    TmpBool: Boolean;

  Begin
  ChoiceStr := Upper(BBSUser^.GetPrompt(511)) + #13;
  MenuDone := False;
  While ((Not MenuDone) and (BBSUser^.Ok)) Do
    Begin
    TmpChr := DisplayFile('MKO-CFG', ChoiceStr);
    If TmpChr = #0 Then
      Begin
      BBSUser^.DisplayAttr(15);
      BBSUser^.SendPrompt(512);
      BBSUser^.DisplayChr(' ');
      TmpChr := BBSUser^.AskChoice(ChoiceStr);
      End;
    BBSUser^.DisplayChr(TmpChr);
    BBSUser^.DisplayNewLine;
    Case Pos(UpCase(TmpChr), ChoiceStr) of
      01: Begin {New file list}
          TmpBool := (QwkUser.Attr and quaNewFile) <> 0;
          DoYN(BBSUser^.GetPrompt(169), TmpBool, QCfg.NewFiles);
          UpdateWordFlag(QwkUser.Attr, quaNewFile, TmpBool);
          End;
      02: Begin {Screens}
          TmpBool := (QwkUser.Attr and quaScreens) <> 0;
          DoYN(BBSUser^.GetPrompt(171), TmpBool, QCfg.Screens);
          UpdateWordFlag(QwkUser.Attr, quaScreens, TmpBool);
          End;
      03: Begin {Bulletins}
          TmpBool := (QwkUser.Attr and quaBulletin) <> 0;
          DoYN(BBSUser^.GetPrompt(170), TmpBool, QCfg.Bulletins);
          UpdateWordFlag(QwkUser.Attr, quaBulletin, TmpBool);
          End;
      04: Begin {pkt size limit}
          If QwkUser.MaxMsgs < 1 Then
            QwkUser.MaxMsgs := 1;
          If QwkUser.MaxMsgs > QCfg.MaxMsgs Then
            QwkUser.MaxMsgs := QCfg.MaxMsgs;
          BBSUser^.SendPrompt(357);
          BBSUser^.DisplayStr(BBSUser^.DefaultNumStr(QwkUser.MaxMsgs));
          QwkUser.MaxMsgs := BBSUser^.AskNumber(QwkUser.MaxMsgs, 1,
            QCfg.MaxMsgs);
          BBSUser^.DisplayNewLine;
          End;
      05: Begin {area size limit}
          If QwkUser.MaxConfMsgs < 1 Then
            QwkUser.MaxConfMsgs := 1;
          If QwkUser.MaxConfMsgs > QCfg.MaxConfMsgs Then
            QwkUser.MaxConfMsgs := QCfg.MaxConfMsgs;
          BBSUser^.SendPrompt(358);
          BBSUser^.DisplayStr(BBSUser^.DefaultNumStr(QwkUser.MaxConfMsgs));
          QwkUser.MaxConfMsgs := BBSUser^.AskNumber(QwkUser.MaxConfMsgs, 1,
            QCfg.MaxConfMsgs);
          BBSUser^.DisplayNewLine;
          End;
      06: Begin {display config settings}
          DisplayCfg;
          End;
      07: Begin {ask offline mail type}
          AskOffMailType;
          End;
      08: Begin {ask pkts}
          TmpBool := (QwkUser.Attr and quaAskPkt) <> 0;
          DoYN(BBSUser^.GetPrompt(359), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaAskPkt, TmpBool);
          End;
      09: Begin {Ask protocol}
          AskProtocol;
          End;
      10: Begin {Ask packer}
          AskPacker;
          End;
      11: Begin {Flag as read}
          TmpBool := (QwkUser.Attr and quaFlagRead) <> 0;
          DoYN(BBSUser^.GetPrompt(164), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaFlagRead, TmpBool);
          End;
      12: Begin {Own msgs}
          TmpBool := (QwkUser.Attr and quaOwnMsgs) <> 0;
          DoYN(BBSUser^.GetPrompt(360), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaOwnMsgs, TmpBool);
          End;
      13: Begin {Your all areas}
          TmpBool := (QwkUser.Attr and quaAllYours) <> 0;
          DoYN(BBSUser^.GetPrompt(361), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaAllYours, TmpBool);
          End;
      14: Begin {zero msg pkts}
          TmpBool := (QwkUser.Attr and quaNoMsg) <> 0;
          DoYN(BBSUser^.GetPrompt(362), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaNoMsg, TmpBool);
          End;
      15: MenuDone := True; {Quit}
      Else
        Begin
        { Invalid key }
        End;
      End;
    End;
  End;


Procedure MainMenu;
  Var
    TmpChr: Char;
    MenuDone: Boolean;
    ChoiceStr: String[40];
    ByeCh: Boolean;

  Begin
  ChoiceStr := Upper(BBSUser^.GetPrompt(510)) + #13;
  MenuDone := False;
  While ((Not MenuDone) and (BBSUser^.Ok)) Do
    Begin
    TmpChr := DisplayFile('MKO-MENU', ChoiceStr);
    If TmpChr = #0 Then
      Begin
      BBSUser^.DisplayAttr(15);
      BBSUser^.SendPrompt(512);
      BBSUser^.DisplayChr(' ');
      TmpChr := BBSUser^.AskChoice(ChoiceStr);
      End;
    BBSUser^.DisplayChr(TmpChr);
    BBSUser^.DisplayNewLine;
    Case Pos(UpCase(TmpChr), ChoiceStr) of
      01: OfflineUL(False);
      02: OfflineDL(False);
      03: CfgMenu;
      04: MenuDone := True;
      05: SelectConfs;
      06: Begin {goodbye}
          BBSUser^.ClearScreen;
          BBSUser^.DisplayNewLine;
          BBSUser^.DisplayNewLine;
          ByeCh := True;
          BBSUser^.AskYn(BBSUser^.GetPrompt(515), ByeCh);
          If ByeCh Then
            Begin
            MenuDone := True;
            {Lower DTR, etc}
            End;
          End;
      08: Begin {include help}
          BBSUser^.DisplayNewLine;
          BBSUser^.DisplayNewLine;
          InclHelp := True;
          BBSUser^.AskYn(BBSUser^.GetPrompt(516), InclHelp);
          End;
      Else
        Begin
        { Invalid key }
        End;
      End;
    End;
  End;



Procedure MainQwk;
  Begin
  Case QwkMode of
    2..5: Begin
          ReadDorInfo;
          If PortNum = 0 Then
            ComP := New(AbsComPtr, Init)
          Else
            ComP := New(FosComPtr, Init);
          If QCfg.LockedBaud <> 0 Then
            PortBaud := QCfg.LockedBaud;
          If ComP^.OpenPort(PortNum, PortBaud, fcHard, 8, 1, 0) Then;
          If DisplayFile('MKO-OPEN', '') = ' ' Then;
          End;
    0..1: Begin
          ComP := New(AbsComPtr, Init);
          DorGraph := 1;
          PortNum := 0;
          End;
    End;
  LoadBbsCfg;
  New(Prmpts);
  Prmpts^.Init;
  Prmpts^.Load(Config^.FindBBSFile(LangName + '.LC') + LangName + '.lc');
  If InitBBSUser Then {after load config}
    Begin
    BBSUser^.SetCurrentPort(PortNum);
    BBSUser^.SetStrPtr(Prmpts);
    BBSUser^.SetComPtr(ComP);
    Case QwkMode of
      0: Begin                           {Local mode}
         LoadUser(LocalName);
         BBSUser^.GetUserPos(LocalName);
         If BBSUser^.UserFound Then
           Begin
           BBSUser^.ReadUser;
           ProcessLocalReplies;
           ProcessLocalMail;
           End
         Else
           WriteLn('Unable to find BBS user record');
         SaveUser;
         End;
      1: Begin                           {Local reply only mode}
         WriteLn('Reply Only for ', LocalName);
         LoadUser(LocalName);
         WriteLn('Packer ', QwkUser.Packer);
         BBSUser^.GetUserPos(LocalName);
         If BBSUser^.UserFound Then
           Begin
           BBSUser^.ReadUser;
           ProcessLocalReplies;
           End
         Else
           WriteLn('Unable to find BBS user record');
         SaveUser;
         End;
      2: Begin                           {Normal BBS mode}
         BBSUser^.ReadExit(OrigDir);
         BBSUser^.ResetLines(0);
         BBSUser^.SetSessionTimeLimit(DorTime * 60);
         BBSUser^.SetStartTime;
         BBSUser^.SetIdleTimeLimit(480);
         LoadUser(BBSUser^.GetUserName);
         BBSUser^.StatusDisplay(1);
         MainMenu;
         SaveUser;
         End;
      3: Begin                           {BBS Auto mode}
         BBSUser^.ReadExit(OrigDir);
         BBSUser^.ResetLines(0);
         BBSUser^.SetSessionTimeLimit(DorTime * 60);
         BBSUser^.SetStartTime;
         BBSUser^.SetIdleTimeLimit(480);
         LoadUser(BBSUser^.GetUserName);
         BBSUser^.StatusDisplay(1);
         { ** automode ** }
         OfflineUL(False);
         OfflineDL(False);
         SaveUser;
         End;
      4: Begin                           {BBS DL Only mode}
         BBSUser^.ReadExit(OrigDir);
         BBSUser^.ResetLines(0);
         BBSUser^.SetSessionTimeLimit(DorTime * 60);
         BBSUser^.SetStartTime;
         BBSUser^.SetIdleTimeLimit(480);
         LoadUser(BBSUser^.GetUserName);
         BBSUser^.StatusDisplay(1);
         OfflineDL(False);
         SaveUser;
         End;
      5: Begin                           {BBS UL Only mode}
         BBSUser^.ReadExit(OrigDir);
         BBSUser^.ResetLines(0);
         BBSUser^.SetSessionTimeLimit(DorTime * 60);
         BBSUser^.SetStartTime;
         BBSUser^.SetIdleTimeLimit(480);
         LoadUser(BBSUser^.GetUserName);
         BBSUser^.StatusDisplay(1);
         OfflineUL(False);
         SaveUser;
         End;
      End;
    End
  Else
    WriteLn('Unable to access BBS user');
  Prmpts^.Done;
  Dispose(Prmpts);
  Dispose(ComP, Done);
  End;

End.
