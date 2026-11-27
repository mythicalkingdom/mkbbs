{ SPDX-License-Identifier: GPL-3.0-or-later }
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
Function  LocalMode: Boolean;          {-L / -R: the sysop's own terminal, not a caller through the BBS}


Implementation


Uses MKFile, MKString, MKQwkG, MKCfgAbs, MKGlobT, Dos, MKDos, MKStr,
  MKSess, MKDoor, MKMisc, MKMsgSel, MKMsgJam,
  MKOffAbs, MKOffTxt, MKOffQwk, MKOffBwv, {MKOffXrs,}
  MKOpen, MKMsgAbs, MKComAbs, MKOffDL, MKOffXfer, MKOffExt;


Var
  QwkMode: Byte;                       {0=local   1=local reply UL   2=normal}
                                       {3=bbs auto   4=bbs dl   5=bbs ul}
  LocalName: String[35];
  PortNum: Byte;
  PortBaud: LongInt;
  DorGraph: Byte;
  DorTime: LongInt;
  LangName: String[8];
  InclHelp: Boolean;
  WorkPath: String[128];


Function LocalMode: Boolean;
  Begin
  LocalMode := QwkMode < 2;
  End;


Function UnixPath(S: String): String;
  {a path written the DOS way: backslashes become slashes}
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    If S[i] = '\' Then
      S[i] := '/';
  UnixPath := S;
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
  LangName := 'prompts';
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
        'P': LangName := Lower(Copy(TmpStr, 3, 8));
        End;
      End;
    Inc(i);
    End;
  End;


Procedure SetLastRead(CurrArea: Word; LR: LongInt);
  Var
    CMsg: AbsMsgPtr;

  Begin
  If InitMsgPtr(CMsg, Config^.GetMsgAreaId(CurrArea)) Then
    Begin
    If Upper(Copy(Config^.GetMsgAreaId(CurrArea),1,1)) = 'J' Then
      CMsg^.SetLastRead(JamStrCrc(User.GetUserName), LR)
    Else
      CMsg^.SetLastRead(User.GetUserRecNum, LR);
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
      GetLastRead := CMsg^.GetLastRead(JamStrCrc(User.GetUserName))
    Else
      GetLastRead := CMsg^.GetLastRead(User.GetUserRecNum);
    If DoneMsgPtr(CMsg) Then;
    End;
  End;


Procedure ClearAndDisp(St: String);
  Begin
  User.DisplayChr(#13);
  User.DisplayStr(PadRight('',' ',78));
  User.DisplayChr(#13);
  User.DisplayStr(St);
  User.DisplayChr(' ');
  End;


Procedure AskAreaType(Area: Word; Var Typ: Byte);
  {How much of a newly chosen area goes into the packet: On (all), None, My (mail to you), All (to you and to All)}
  Var
    TmpChr: Char;
    CStr: String[128];
    SType: Word;

  Begin
  CStr := Prompts.GetString(513);
  ClearAndDisp(Copy(Config^.GetMsgName(Area), 1, 30) + ' ' + Prompts.GetString(514));
  TmpChr := User.AskChoice(CStr);
  SType := Pos(TmpChr, CStr);
  Case SType of
    1: Typ := qctOn;
    2: Typ := qctNone;
    3: Typ := qctMy;
    4: Typ := qctAll;
    End;
  User.DisplayNewLine;
  End;


Procedure SelectConfs;
  {The message areas that go into the packet: the area selection screen of mk (MKMsgSel) with the last read question,
   then, for each area that was chosen now, how much of it}
  Var
    SC: ConfSelectObj;
    i: Word;
    NumAct: Word;
    Sec: SecType;
    Typ: Byte;
    OldTyp: Array[1..500] of Byte;
    MaxA: Word;

  Begin
  User.ClearScreen;
  User.GetUserSec(Sec);
  MaxA := Config^.GetMaxMsgAreas;
  If MaxA > 500 Then
    MaxA := 500;
  For i := 1 to 500 Do
    OldTyp[i] := qctNone;
  For i := 1 to QwkUserAreas Do
    If (QwkUser.UserConfs[i].Area > 0) And (QwkUser.UserConfs[i].Area <= 500) Then
      OldTyp[QwkUser.UserConfs[i].Area] := QwkUser.UserConfs[i].Typ;
  SC.Init;
  For i := 1 to MaxA Do
    Begin
    SC.SetAvailable(i, Config^.MsgReadAccess(i, Sec) and (Length(Config^.GetMsgName(i)) > 0));
    SC.SetChosen(i, OldTyp[i] <> qctNone);
    End;
  SC.SelectConfs(True, True, False);
  For i := 1 to QwkUserAreas Do
    Begin
    QwkUser.UserConfs[i].Typ := qctNone;
    QwkUser.UserConfs[i].Area := 0;
    End;
  NumAct := 0;
  For i := 1 to MaxA Do
    If SC.IsChosen(i) Then
      Begin
      Typ := OldTyp[i];
      If Typ = qctNone Then
        Begin
        Typ := qctOn;
        AskAreaType(i, Typ);
        End;
      If (Typ <> qctNone) And (NumAct < QwkUserAreas) Then
        Begin
        Inc(NumAct);
        QwkUser.UserConfs[NumAct].Area := i;
        QwkUser.UserConfs[NumAct].Typ := Typ;
        End;
      End;
  SC.Done;
  End;


Procedure DoYN(QuesStr: String; Var Awsr: Boolean; Lim: Byte);
  Begin
  Case Lim Of
    0: Begin
       Awsr := False;
       User.DisplayStrLn(Prompts.GetString(172));
       User.PressEnter;
       End;
    1: Begin
       Awsr := True;
       User.DisplayStrLn(Prompts.GetString(172));
       End;
    2..4: Begin
       User.AskYN(QuesStr, Awsr);
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
  If ((DorGraph > 1) and FileExist(QCfg.ScreenPath + FileName + '.avt')) Then
    Ext := '.avt'
  Else If ((DorGraph > 0) and FileExist(QCfg.ScreenPath + FileName + '.ans')) Then
    Ext := '.ans'
  Else
    Ext := '.asc';
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
        User.DisplayChr(Buffer[i]);
        Inc(i);
        End;
      If Not CommInEmpty Then
        Begin
        KeyChar := UpCase(CommRecv);
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
  TStr := Upper(Prompts.GetString(499));
  User.DisplayNewLine;
  For i := 1 to 10 Do
    Begin
    If QCfg.Prots[i].ProtActive Then
      Begin
      Inc(CStr[0]);
      CStr[Length(CStr)] := TStr[i];
      PNum[Length(CStr)] := i;
      User.DisplayAttr(1);
      User.DisplayStr(Prompts.GetString(12));
      User.DisplayAttr(11);
      User.DisplayChr(TStr[i]);
      User.DisplayAttr(1);
      User.DisplayStr(Prompts.GetString(13));
      User.DisplayAttr(3);
      User.DisplayChr(' ');
      User.DisplayStrLn(Prompts.GetString(i + 499));
      End;
    End;
  User.DisplayNewLine;
  User.DisplayAttr(15);
  User.DisplayStr(Prompts.GetString(165));
  User.DisplayChr(' ');
  If Pos(QwkUser.Protocol, CStr) > 0 Then
    CStr := CStr + #13;
  TmpChr := UpCase(User.AskChoice(CStr));
  If ((TmpChr <> #13) and (Pos(TmpChr, CStr) > 0)) Then
    QwkUser.Protocol := TmpChr;
  i := Pos(QwkUser.Protocol, CStr);
  User.DisplayStrLn(Prompts.GetString(PNum[i] + 499));
  User.DisplayNewLine;
  End;



Function GetProtNum: Word;
  Var
    CStr: String[20];
    TStr: String[20];
    PNum: Array[1..20] of Byte;
    i: Word;

  Begin
  CStr := '';
  TStr := Upper(Prompts.GetString(499));
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


Function ProtCmd(ProtNum: Word; DoSend: Boolean; JustName: String): String;
  {the command line of the protocol with %F ... filled in}
  Begin
  If DoSend Then
    ProtCmd := OffExpand(QCfg.Prots[ProtNum].SendCmd, JustName, PortNum, QCfg.LockedBaud)
  Else
    ProtCmd := OffExpand(QCfg.Prots[ProtNum].RcvCmd, JustName, PortNum, QCfg.LockedBaud);
  End;


Function SendMail(FN: String; JustName: String): Boolean;
  Var
    XFerOK : Boolean;
    ProtNum: Word;

  Begin
  ProtNum := GetProtNum;
  XferOk := (ProtNum > 0) and (ProtNum < 11);
  If XferOk Then
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
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(130));
    User.DisplayStr(Prompts.GetString(129));
    User.DisplayStrLn(' ' + JustName);
    XFerOk := OffTransfer(ProtCmd(ProtNum, True, JustName), OrigDir, WorkPath);
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
    User.DisplayXY(33, 3)
  Else
    User.DisplayNewLine;
  User.DisplayAttr(15);
  User.DisplayStr(PadRight(Copy(SMsg, 1 ,25),' ', 25));
  End;


Procedure UpdateNumPkt(FullScrn: Boolean; NP: LongInt);
  Begin
  If FullScrn Then
    Begin
    User.DisplayXY(68, 3);
    User.DisplayAttr(15);
    User.DisplayStr(PadLeft(Long2Str(NP),' ', 5));
    End;
  End;


Procedure UpdateNumArea(FullScrn: Boolean; NA: LongInt);
  Var
    i: Word;

  Begin
  If FullScrn Then
    Begin
    User.DisplayXY(68, 9);
    User.DisplayAttr(15);
    User.DisplayStr(PadLeft(Long2Str(NA),' ', 5));
    End
  Else
    Begin
    For i := 1 to 4 Do
      User.DisplayBkSpc;
    User.DisplayStr(PadLeft(Long2Str(NA),' ', 4));
    End;
  End;


Procedure UpdateArea(FullScrn: Boolean; NA: LongInt; CA: Word);
  Begin
  If FullScrn Then
    User.DisplayXY(33, 9)
  Else
    User.DisplayNewLine;
  User.DisplayAttr(15);
  User.DisplayStr(PadRight(Copy(Config^.GetMsgName(CA),1,25),' ', 25));
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
  TStr := Upper(Prompts.GetString(488));
  User.DisplayNewLine;
  For i := 1 to 10 Do
    Begin
    If QCfg.Packers[i].PackActive Then
      Begin
      Inc(CStr[0]);
      CStr[Length(CStr)] := TStr[i];
      PNum[Length(CStr)] := i;
      User.DisplayAttr(1);
      User.DisplayStr(Prompts.GetString(12));
      User.DisplayAttr(11);
      User.DisplayChr(TStr[i]);
      User.DisplayAttr(1);
      User.DisplayStr(Prompts.GetString(13));
      User.DisplayAttr(3);
      User.DisplayChr(' ');
      User.DisplayStrLn(Prompts.GetString(i + 488));
      End;
    End;
  User.DisplayNewLine;
  User.DisplayAttr(15);
  User.DisplayStr(Prompts.GetString(160));
  User.DisplayChr(' ');
  If Pos(QwkUser.Packer, CStr) > 0 Then
    CStr := CStr + #13;
  TmpChr := UpCase(User.AskChoice(CStr));
  If ((TmpChr <> #13) and (Pos(TmpChr, CStr) > 0)) Then
    QwkUser.Packer := TmpChr;
  i := Pos(QwkUser.Packer, CStr);
  User.DisplayStrLn(Prompts.GetString(PNum[i] + 488));
  User.DisplayNewLine;
  End;


Function GetPackNum: Word;
  Var
    CStr: String[20];
    TStr: String[20];
    PNum: Array[1..20] of Byte;
    i: Word;

  Begin
  CStr := '';
  TStr := Upper(Prompts.GetString(488));
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


Procedure UnpackCmds(Var Cmds: OffCmdList; Var Num: Word);
  {the unpack commands to try on a reply packet: the packer of the caller first, then the others}
  Var
    i, UserPk: Word;

  Begin
  Num := 0;
  UserPk := GetPackNum;
  If (UserPk > 0) And (UserPk < 11) And QCfg.Packers[UserPk].PackActive Then
    Begin
    Inc(Num);
    Cmds[Num] := QCfg.Packers[UserPk].UnPackCmd;
    End;
  For i := 1 To 10 Do
    If (i <> UserPk) And QCfg.Packers[i].PackActive Then
      Begin
      Inc(Num);
      Cmds[Num] := QCfg.Packers[i].UnPackCmd;
      End;
  End;


Procedure DoorAreaHook(Area: Word; Typ: Byte);
  {TODOOR.EXT of a reader: the conference is dropped or taken (the subscription of the caller is QwkUser.UserConfs)}
  Var
    i, Slot, Free: Word;

  Begin
  Slot := 0;
  Free := 0;
  For i := 1 To QwkUserAreas Do
    Begin
    If QwkUser.UserConfs[i].Area = Area Then
      Slot := i;
    If (Free = 0) And ((QwkUser.UserConfs[i].Area = 0) Or (QwkUser.UserConfs[i].Typ = qctNone)) Then
      Free := i;
    End;
  If Typ = 0 Then
    Begin
    If Slot > 0 Then
      Begin
      QwkUser.UserConfs[Slot].Area := 0;
      QwkUser.UserConfs[Slot].Typ := qctNone;
      End;
    Exit;
    End;
  If Slot = 0 Then
    Slot := Free;
  If Slot = 0 Then
    Exit;
  QwkUser.UserConfs[Slot].Area := Area;
  Case Typ Of
    2: QwkUser.UserConfs[Slot].Typ := qctMy;
    3: QwkUser.UserConfs[Slot].Typ := qctAll;
    Else QwkUser.UserConfs[Slot].Typ := qctOn;
    End;
  End;


Procedure OfflineUL(BatchMode: Boolean);
  {The reply packet of the caller: in a BBS session it is received with the caller's protocol, when run locally
   (-L / -R) it is <BBSID>.REP in the current directory.  It is unpacked in a work directory of its own and its
   messages are posted (QwkOffObj.ImportPacket).}
  Var
    Offline: AbsOffPtr;
    Cont, Have, XferOk: Boolean;
    ProtNum: Word;
    TmpStr, Src: String;
    Cmds: OffCmdList;
    NumCmds: Word;
    Imported: LongInt;
    ImpO: OffImportOpts;

  Begin
  If QwkUser.MailType <> qmtQwk Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(Prompts.GetString(176));
    User.PressEnter;
    Exit;
    End;
  If (QwkUser.Attr And quaNoUL) <> 0 Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(Prompts.GetString(172));
    User.PressEnter;
    Exit;
    End;
  Offline := New(QwkOffPtr, Init);
  Offline^.SetBBSId(QCfg.BoardId);
  WorkPath := CreateTempDir(QCfg.TempPath);
  Cont := Length(WorkPath) > 0;
  If Cont Then
    Offline^.SetPath(WorkPath);
  Have := True;
  If Cont Then
    Begin
    If BatchMode Then
      Begin
      Src := FindNoCase(OrigDir, Offline^.GetReplyName);
      Cont := (Src <> '') And CopyFile(Src, WithBackSlash(WorkPath) + 'upload.1');
      If Src = '' Then
        Begin
        User.DisplayStrLn(Prompts.GetString(178));
        Have := False;
        End;
      End
    Else
      Begin
      User.DisplayNewLine;
      User.AskYN(Prompts.GetString(177), Have);
      If Have Then
        Begin
        ProtNum := GetProtNum;
        XferOk := (ProtNum > 0) And (ProtNum < 11);
        If XferOk Then
          Begin
          User.DisplayNewLine;
          User.DisplayAttr(Config^.GetSystemColor(1));
          User.DisplayStrLn(Prompts.GetString(130));
          XferOk := OffTransfer(ProtCmd(ProtNum, False, ''), OrigDir, WorkPath);
          End;
        If Not XferOk Then
          Begin
          User.DisplayNewLine;
          User.DisplayStrLn(Prompts.GetString(168));
          User.PressEnter;
          Cont := False;
          End;
        End;
      End;
    End;
  If Cont And Have Then
    Begin
    {what was received: renamed, a file name of the caller must not look like an option to an unpacker}
    OffRenameUploads(WorkPath);
    UnpackCmds(Cmds, NumCmds);
    If Not OffUnpackReply(Offline, WorkPath, OrigDir, Cmds, NumCmds) Then;
    If FindNoCase(WorkPath, Offline^.GetExtractSpec) = '' Then
      Begin
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(178));
      If Not BatchMode Then
        User.PressEnter;
      End
    Else
      Begin
      UpdateStatus(False, Prompts.GetString(366));
      ImpO.BadArea := QCfg.BadMsgArea;
      ImpO.ForceName := QCfg.ForceName;
      ImpO.ReDate := (QCfg.Attr And qaReDate) <> 0;
      ImpO.DupeFile := WithBackSlash(QCfg.UserPath) + 'qwkdupe.dat';
      Offline^.SetImportOpts(ImpO);
      QwkAreaHook := DoorAreaHook;
      Offline^.ImportPacket;
      QwkAreaHook := Nil;
      Imported := Offline^.GetImported;
      Inc(QwkUser.MsgsUL, Imported);
      User.DisplayNewLine;
      User.DisplayStrLn(Long2Str(Imported) + ' message(s) posted');
      If Not BatchMode Then
        User.PressEnter;
      End;
    End;
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


Var
  DLFull: Boolean;                     {the full screen display}
  DLIdx: Word;
  DLPhase: Byte;
  DLSelected: Array[1..OffAreas] Of Boolean;


Function DLSel(N: Word; Var Area: Word; Var Mode: Byte): Boolean;
  {the conferences of the caller in turn; with "your mail in all areas" the others follow, for his mail only}
  Begin
  DLSel := False;
  If N = 1 Then
    Begin
    DLIdx := 0;
    DLPhase := 1;
    FillChar(DLSelected, SizeOf(DLSelected), 0);
    End;
  If DLPhase = 1 Then
    Begin
    Repeat
      Inc(DLIdx);
    Until (DLIdx > QwkUserAreas) Or ((QwkUser.UserConfs[DLIdx].Area > 0) And
      (QwkUser.UserConfs[DLIdx].Typ <> qctNone));
    If DLIdx <= QwkUserAreas Then
      Begin
      Area := QwkUser.UserConfs[DLIdx].Area;
      If Area <= OffAreas Then
        DLSelected[Area] := True;
      Case QwkUser.UserConfs[DLIdx].Typ Of
        qctMy: Mode := omMy;
        qctAll: Mode := omAllYour;
        Else Mode := omAll;
        End;
      DLSel := True;
      Exit;
      End;
    If (QwkUser.Attr And quaAllYours) = 0 Then
      Exit;
    DLPhase := 2;
    DLIdx := 0;
    End;
  Repeat
    Inc(DLIdx);
  Until (DLIdx > Config^.GetMaxMsgAreas) Or (DLIdx > OffAreas) Or (Not DLSelected[DLIdx]);
  If (DLIdx <= Config^.GetMaxMsgAreas) And (DLIdx <= OffAreas) Then
    Begin
    Area := DLIdx;
    Mode := omMy;
    DLSel := True;
    End;
  End;


Procedure DLEv(What: Word; Area: Word; N: LongInt);
  Begin
  Case What Of
    oeArea: UpdateArea(DLFull, N, Area);
    oeAreaMsg: If (N Mod 5) = 0 Then UpdateNumArea(DLFull, N);
    oePktMsg: If (N Mod 5) = 0 Then UpdateNumPkt(DLFull, N);
    oeAreaEnd: Begin
               UpdateNumArea(DLFull, N);
               If Not DLFull Then
                 User.DisplayNewLine;
               End;
    End;
  End;


Procedure OfflineDL(BatchMode: Boolean);
  Var
    Offline: AbsOffPtr;
    Cont: Boolean;
    Quiet: Boolean;                    {nothing to send, or the caller does not want it: not an error}
    P: OffDLParams;
    R: OffDLResult;
    PackNum: Word;
    ArcName: String;
    FullScrn: Boolean;
    ExSpec: OffExtraSpec;
    ExRes: OffExtraRes;
    i: Word;

  Begin
  FillChar(ExRes, SizeOf(ExRes), 0);
  FullScrn := User.GetUserAnsi or User.GetUserAvatar;
  DLFull := FullScrn;
  If FullScrn Then
    Begin
    If DisplayFile('mko-proc','') = ' ' Then;
    End
  Else
    User.ClearScreen;
  UpdateStatus(FullScrn, Prompts.GetString(366));
  Quiet := False;
  Offline := nil;
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
    Offline^.SetQwke((QCfg.Attr And qaQwke) <> 0);
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
    P.Sel := DLSel;
    P.Ev := DLEv;
    P.MaxMsgs := QwkUser.MaxMsgs;
    If QCfg.MaxMsgs < P.MaxMsgs Then
      P.MaxMsgs := QCfg.MaxMsgs;
    P.AreaMax := QwkUser.MaxConfMsgs;
    If QCfg.MaxConfMsgs < P.AreaMax Then
      P.AreaMax := QCfg.MaxConfMsgs;
    P.OwnMsgs := (QwkUser.Attr And quaOwnMsgs) <> 0;
    P.CheckUser := Not BatchMode;
    Cont := OffExport(Offline, P, R);
    UpdateNumPkt(FullScrn, R.NumMsgs);
    If Cont Then
      Begin                            {the screens, bulletins and new files list of the door's settings: Never, Always, or what the caller chose}
      FillChar(ExSpec, SizeOf(ExSpec), 0);
      ExSpec.Screens := (QCfg.Screens = qatYes) Or (QCfg.Screens = qatNew) Or ((QCfg.Screens >= qatAskY) And ((QwkUser.Attr And quaScreens) <> 0));
      ExSpec.Bulletins := (QCfg.Bulletins = qatYes) Or (QCfg.Bulletins = qatNew) Or ((QCfg.Bulletins >= qatAskY) And ((QwkUser.Attr And quaBulletin) <> 0));
      ExSpec.NewFiles := (QCfg.NewFiles = qatYes) Or (QCfg.NewFiles = qatNew) Or ((QCfg.NewFiles >= qatAskY) And ((QwkUser.Attr And quaNewFile) <> 0));
      ExSpec.Scr[1] := QCfg.ScrnHello;
      ExSpec.Scr[2] := QCfg.ScrnNews;
      ExSpec.Scr[3] := QCfg.ScrnBye;
      For i := 1 To 10 Do
        ExSpec.Bull[i] := QCfg.BullNames[i];
      ExSpec.Head := QCfg.NewScrn;
      ExSpec.ToReader := (QCfg.Attr And qaQwke) <> 0;
      ExSpec.Alias := User.GetUserHandle;
      ExSpec.OwnMsgs := (QwkUser.Attr And quaOwnMsgs) <> 0;
      OffAddExtras(Offline, WorkPath, ExSpec, R, ExRes);
      End;
    If Offline^.ClosePacket <> 0 Then
      Cont := False;
    If Cont And (R.NumMsgs = 0) And ((QwkUser.Attr And quaNoMsg) = 0) Then
      Begin
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(178));
      If Not BatchMode Then
        User.PressEnter;
      Quiet := True;
      Cont := False;
      End;
    End;
  If Cont Then
    Begin
    PackNum := GetPackNum;
    ArcName := Offline^.GetArchiveName(PackNum);
    Cont := (PackNum > 0) And (PackNum < 11) And QCfg.Packers[PackNum].PackActive;
    If Cont Then
      Begin
      UpdateStatus(FullScrn, Prompts.GetString(189));
      If BatchMode Then
        Cont := OffRun(QCfg.Packers[PackNum].PackCmd, OrigDir, WorkPath, WithBackSlash(OrigDir) + ArcName + ' *.*')
      Else
        Cont := OffRun(QCfg.Packers[PackNum].PackCmd, OrigDir, WorkPath, ArcName + ' *.*');
      End;
    End;
  If Cont And FullScrn Then
    User.DisplayXY(1, 13);
  If Cont And (Not BatchMode) Then
    Begin
    If (QwkUser.Attr And quaAskPkt) <> 0 Then
      Begin
      Cont := OffVerify(WithBackSlash(WorkPath) + ArcName);
      Quiet := Not Cont;
      End;
    If Cont Then
      Cont := SendMail(WithBackSlash(WorkPath) + ArcName, ArcName);
    End;
  If Cont Then
    Begin
    OffCommitLR(R);                    {the caller has what was in the packet}
    OffExtrasCommit(ExRes);            {... and the new files it listed}
    End;
  If (Not Cont) And (Not Quiet) Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(364));
    User.PressEnter;
    End;
  If Offline <> nil Then
    Dispose(Offline, Done);
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
  If Not FileExist('dorinfo1.def') Then
    WriteLn('Unable to find dorinfo1.def');
  If Not DFile.OpenTextFile('dorinfo1.def') Then
    WriteLn('Unable to open dorinfo1.def');
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
    WriteLn('Unable to close dorinfo1.def');
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
  CStr := Upper(Copy(Prompts.GetString(345), 1, 5));
  User.DisplayNewLine;
  For i := 1 to 5 Do
    Begin
    User.DisplayAttr(1);
    User.DisplayStr(Prompts.GetString(12));
    User.DisplayAttr(11);
    User.DisplayChr(CStr[i]);
    User.DisplayAttr(1);
    User.DisplayStr(Prompts.GetString(13));
    User.DisplayAttr(3);
    User.DisplayChr(' ');
    User.DisplayStrLn(Prompts.GetString(i + 345));
    End;
  User.DisplayNewLine;
  User.DisplayAttr(15);
  User.DisplayStr(Prompts.GetString(356));
  User.DisplayChr(' ');
  If ((QwkUser.MailType > 0) and (QwkUser.MailType < 6)) Then
    CStr := CStr + #13;
  TmpChr := User.AskChoice(CStr);
  Case Pos(UpCase(TmpChr), CStr) of
    1: QwkUser.MailType := qmtQwk;
    2: QwkUser.MailType := qmtXrs;
    3: QwkUser.MailType := qmtBwv;
    4: QwkUser.MailType := qmtText;
    5: QwkUser.MailType := qmtPkt;
    End;
  Case  QwkUser.MailType of
    qmtQwk: User.DisplayStrLn(Prompts.GetString(346));
    qmtXrs: User.DisplayStrLn(Prompts.GetString(347));
    qmtBwv: User.DisplayStrLn(Prompts.GetString(348));
    qmtText: User.DisplayStrLn(Prompts.GetString(349));
    qmtPkt: User.DisplayStrLn(Prompts.GetString(350));
    End;
  User.DisplayNewLine;
  End;


Procedure StrDisplay(St: String; Info: String);
  Begin
  User.DisplayAttr(11);
  User.DisplayStr(St);
  User.DisplayChr(' ');
  User.DisplayAttr(10);
  User.DisplayStrLn(Info);
  End;


Procedure InfoDisplay(St: String; Info: Boolean);
  Begin
  User.DisplayAttr(11);
  User.DisplayStr(St);
  User.DisplayChr(' ');
  User.DisplayAttr(10);
  If Info Then
    User.DisplayStrLn(Prompts.GetString(3))
  Else
    User.DisplayStrLn(Prompts.GetString(4));
  End;

Procedure DisplayCfg;
  Begin
  User.ClearScreen;
  User.DisplayNewLine;
  StrDisplay(Prompts.GetString(520), User.GetUserName);
  InfoDisplay(Prompts.GetString(521), (QwkUser.Attr and quaNewFile <> 0));
  InfoDisplay(Prompts.GetString(522), (QwkUser.Attr and quaScreens <> 0));
  InfoDisplay(Prompts.GetString(523), (QwkUser.Attr and quaBulletin <> 0));
  StrDisplay(Prompts.GetString(524), Long2Str(QwkUser.MaxMsgs));
  StrDisplay(Prompts.GetString(525), Long2Str(QwkUser.MaxConfMsgs));
  {prot 526}
  {packer 527}
  InfoDisplay(Prompts.GetString(528), (QwkUser.Attr and quaFlagRead <> 0));
  InfoDisplay(Prompts.GetString(529), (QwkUser.Attr and quaOwnMsgs <> 0));
  InfoDisplay(Prompts.GetString(530), (QwkUser.Attr and quaAllYours <> 0));
  InfoDisplay(Prompts.GetString(531), (QwkUser.Attr and quaNoMsg <> 0));
  InfoDisplay(Prompts.GetString(532), (QwkUser.Attr and quaAskPkt <> 0));
  Case QwkUser.MailType of
    qmtQwk: StrDisplay(Prompts.GetString(533), Prompts.GetString(346));
    qmtXrs: StrDisplay(Prompts.GetString(533), Prompts.GetString(347));
    qmtBwv: StrDisplay(Prompts.GetString(533), Prompts.GetString(348));
    qmtText: StrDisplay(Prompts.GetString(533), Prompts.GetString(349));
    qmtPkt: StrDisplay(Prompts.GetString(533), Prompts.GetString(350));
    End;
  User.DisplayNewLine;
  User.PressEnter;
  End;


Procedure CfgMenu;
  Var
    TmpChr: Char;
    MenuDone: Boolean;
    ChoiceStr: String;
    TmpBool: Boolean;

  Begin
  ChoiceStr := Upper(Prompts.GetString(511)) + #13;
  MenuDone := False;
  While ((Not MenuDone) and (User.Ok)) Do
    Begin
    TmpChr := DisplayFile('mko-cfg', ChoiceStr);
    If TmpChr = #0 Then
      Begin
      User.DisplayAttr(15);
      User.DisplayStr(Prompts.GetString(512));
      User.DisplayChr(' ');
      TmpChr := User.AskChoice(ChoiceStr);
      End;
    User.DisplayChr(TmpChr);
    User.DisplayNewLine;
    Case Pos(UpCase(TmpChr), ChoiceStr) of
      01: Begin {New file list}
          TmpBool := (QwkUser.Attr and quaNewFile) <> 0;
          DoYN(Prompts.GetString(169), TmpBool, QCfg.NewFiles);
          UpdateWordFlag(QwkUser.Attr, quaNewFile, TmpBool);
          End;
      02: Begin {Screens}
          TmpBool := (QwkUser.Attr and quaScreens) <> 0;
          DoYN(Prompts.GetString(171), TmpBool, QCfg.Screens);
          UpdateWordFlag(QwkUser.Attr, quaScreens, TmpBool);
          End;
      03: Begin {Bulletins}
          TmpBool := (QwkUser.Attr and quaBulletin) <> 0;
          DoYN(Prompts.GetString(170), TmpBool, QCfg.Bulletins);
          UpdateWordFlag(QwkUser.Attr, quaBulletin, TmpBool);
          End;
      04: Begin {pkt size limit}
          If QwkUser.MaxMsgs < 1 Then
            QwkUser.MaxMsgs := 1;
          If QwkUser.MaxMsgs > QCfg.MaxMsgs Then
            QwkUser.MaxMsgs := QCfg.MaxMsgs;
          User.DisplayStr(Prompts.GetString(357));
          User.DisplayStr(User.DefaultNumStr(QwkUser.MaxMsgs));
          QwkUser.MaxMsgs := User.AskNumber(QwkUser.MaxMsgs, 1,
            QCfg.MaxMsgs);
          User.DisplayNewLine;
          End;
      05: Begin {area size limit}
          If QwkUser.MaxConfMsgs < 1 Then
            QwkUser.MaxConfMsgs := 1;
          If QwkUser.MaxConfMsgs > QCfg.MaxConfMsgs Then
            QwkUser.MaxConfMsgs := QCfg.MaxConfMsgs;
          User.DisplayStr(Prompts.GetString(358));
          User.DisplayStr(User.DefaultNumStr(QwkUser.MaxConfMsgs));
          QwkUser.MaxConfMsgs := User.AskNumber(QwkUser.MaxConfMsgs, 1,
            QCfg.MaxConfMsgs);
          User.DisplayNewLine;
          End;
      06: Begin {display config settings}
          DisplayCfg;
          End;
      07: Begin {ask offline mail type}
          AskOffMailType;
          End;
      08: Begin {ask pkts}
          TmpBool := (QwkUser.Attr and quaAskPkt) <> 0;
          DoYN(Prompts.GetString(359), TmpBool, qatAskY);
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
          DoYN(Prompts.GetString(164), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaFlagRead, TmpBool);
          End;
      12: Begin {Own msgs}
          TmpBool := (QwkUser.Attr and quaOwnMsgs) <> 0;
          DoYN(Prompts.GetString(360), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaOwnMsgs, TmpBool);
          End;
      13: Begin {Your all areas}
          TmpBool := (QwkUser.Attr and quaAllYours) <> 0;
          DoYN(Prompts.GetString(361), TmpBool, qatAskY);
          UpdateWordFlag(QwkUser.Attr, quaAllYours, TmpBool);
          End;
      14: Begin {zero msg pkts}
          TmpBool := (QwkUser.Attr and quaNoMsg) <> 0;
          DoYN(Prompts.GetString(362), TmpBool, qatAskY);
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
  ChoiceStr := Upper(Prompts.GetString(510)) + #13;
  MenuDone := False;
  While ((Not MenuDone) and (User.Ok)) Do
    Begin
    TmpChr := DisplayFile('mko-menu', ChoiceStr);
    If TmpChr = #0 Then
      Begin
      User.DisplayAttr(15);
      User.DisplayStr(Prompts.GetString(512));
      User.DisplayChr(' ');
      TmpChr := User.AskChoice(ChoiceStr);
      End;
    User.DisplayChr(TmpChr);
    User.DisplayNewLine;
    Case Pos(UpCase(TmpChr), ChoiceStr) of
      01: OfflineUL(False);
      02: OfflineDL(False);
      03: CfgMenu;
      04: MenuDone := True;
      05: SelectConfs;
      06: Begin {goodbye}
          User.ClearScreen;
          User.DisplayNewLine;
          User.DisplayNewLine;
          ByeCh := True;
          User.AskYN(Prompts.GetString(515), ByeCh);
          If ByeCh Then
            Begin
            MenuDone := True;
            {Lower DTR, etc}
            End;
          End;
      08: Begin {include help}
          User.DisplayNewLine;
          User.DisplayNewLine;
          InclHelp := True;
          User.AskYN(Prompts.GetString(516), InclHelp);
          End;
      Else
        Begin
        { Invalid key }
        End;
      End;
    End;
  End;



Procedure MainQwk;
  Var
    BbsType: Word;

  Begin
  {the paths of config.mko may be written the DOS way}
  QCfg.TempPath := UnixPath(QCfg.TempPath);
  QCfg.UserPath := UnixPath(QCfg.UserPath);
  QCfg.ScreenPath := UnixPath(QCfg.ScreenPath);
  If (QCfg.ScreenPath <> '') And (QCfg.ScreenPath[Length(QCfg.ScreenPath)] <> '/') Then
    QCfg.ScreenPath := QCfg.ScreenPath + '/';
  {the caller: the standard input / output of this program (the pseudo terminal of mk's door, a socket, the sysop's terminal)}
  ComSession := CreateSession('', 0, '', False);
  If ComSession = Nil Then
    Begin
    WriteLn(SessionError);
    Exit;
    End;
  Case QwkMode of
    2..5: Begin
          ReadDorInfo;
          CurrentPort := 1;
          If QCfg.LockedBaud <> 0 Then
            PortBaud := QCfg.LockedBaud;
          If PortBaud <= 0 Then
            PortBaud := 38400;
          End;
    0..1: Begin
          CurrentPort := 0;
          DorGraph := 1;
          PortNum := 0;
          End;
    End;
  LoadBbsCfg;
  If Config = Nil Then
    Begin
    WriteLn('Unable to load the BBS configuration (set MK, RA, QUICK or SBBS to the BBS configuration directory)');
    Exit;
    End;
  Prompts.Init;
  Prompts.Load(Config^.FindBBSFile(LangName + '.lc') + LangName + '.lc');
  User.Init;
  BbsType := DetectBbsType;
  User.SetUserBbsType(BbsType);
  User.SetUserBaud(PortBaud);
  If CommActive Then
    Begin
    CommInit;
    CommFlow(fcHard);
    If DisplayFile('mko-open', '') = ' ' Then;
    End;
  Case QwkMode of
    0: Begin                           {Local mode}
       LoadUser(LocalName);
       User.GetUserPos(LocalName);
       If User.UserFound Then
         Begin
         User.ReadUser;
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
       User.GetUserPos(LocalName);
       If User.UserFound Then
         Begin
         User.ReadUser;
         ProcessLocalReplies;
         End
       Else
         WriteLn('Unable to find BBS user record');
       SaveUser;
       End;
    2..5: Begin                        {BBS door modes: the user is the one the BBS wrote to EXITINFO.BBS}
       User.ReadExit(OrigDir);
       User.ResetLines(0);
       User.SetSessionTimeLimit(DorTime * 60);
       User.SetStartTime;
       User.SetIdleTimeLimit(480);
       LoadUser(User.GetUserName);
       Case QwkMode of
         2: MainMenu;                  {Normal BBS mode}
         3: Begin                      {BBS Auto mode}
            OfflineUL(False);
            OfflineDL(False);
            End;
         4: OfflineDL(False);          {BBS DL Only mode}
         5: OfflineUL(False);          {BBS UL Only mode}
         End;
       SaveUser;
       End;
    End;
  Prompts.Done;
  End;


End.
