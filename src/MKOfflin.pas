{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKOfflin; {Offline mail functions}
{$I MKB.Def}

Interface

Uses MKOffDL;

Type OffBuild = Record                 {a packet made without a caller on the line (the JSON API): see OfflineBuildPacket}
  ArcPath: String;                     {the packed packet (<BBSID>.QWK ...) in the work directory}
  Messages: LongInt;                   {messages in it}
  R: OffDLResult;                      {how far the user was taken in each area: OffCommitLR(R) when he has the packet}
  Why: String;                         {what went wrong}
  End;

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
Var OfflineQuiet: Boolean;   {a scripted caller (mk -Q): nothing is asked, nothing waits for Enter}
Procedure OfflineAuto;
Procedure OfflineUL;
Procedure OfflineDL;
Function  GetUserPackerNum: Word;
Function  GetUserProtNum: Word;
Function  GetUserOffTypeNum: Word;
Function  OfflineBuildPacket(WorkPath: String; MaxMsgs: LongInt; Var B: OffBuild): Integer;
  {Makes the offline mail packet of the user that is loaded (User) in WorkPath, packs it with his packer: no display, no transfer, and the last read pointers are NOT moved (the caller commits them
   when the user has the packet).  MaxMsgs > 0 is a limit of the packet below the user's and the system's.  0 = made, 1 = nothing new for him, 2 = failed (B.Why)}

Implementation


Uses MKFile, MKString, MKDoor, MKCfgAbs, MKGlobT, MKCFile,
  MKOffAbs, MKOffQwk, MKOffTxt, MKOffXrs, MKOffBwv,
  MKMsgOpn, MKMsgAbs, MKDos, MKRCfgMK, MKComAbs, MKProt, MKOffXfer, MKOffExt,
  Dos;


Procedure OffPause;
  Begin
  If Not OfflineQuiet Then
    User.PressEnter;
  End;


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


Procedure QuietDefaults;
  {a caller who cannot be asked gets the first protocol and packer of the system, QWK, and the largest packet}
  Var
    i: Word;

  Begin
  If GetUserProtNum = 0 Then
    Begin
    i := 1;
    While (i <= 20) And Not (Config^.GetProtNormAvail(i) And (i <> 7)) Do
      Inc(i);
    If i <= 20 Then
      User.SetUserProt(Config^.GetProtChar(i));
    End;
  If GetUserPackerNum = 0 Then
    Begin
    i := 1;
    While (i <= 10) And Not Config^.GetPackAvail(i) Do
      Inc(i);
    If i <= 10 Then
      User.SetUserPacker(UpCase(Config^.GetPackChar(i)));
    End;
  If User.GetUserOffMax = 0 Then
    User.SetUserOffMax(Config^.GetOffMax);
  If User.GetUserOffConfMax = 0 Then
    User.SetUserOffConfMax(Config^.GetOffConfMax);
  End;


Function ValidateOffline: Boolean;
  Var
    AskAll: Boolean;
    Cont: Boolean;

  Begin
  AskAll := False;
  If OfflineQuiet Then
    Begin
    QuietDefaults;
    ValidateOffline := True;
    Exit;
    End;
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


{ ---- the packet for the caller, and the replies of the caller.  The settings are those of config.mk (packers, protocols with
  their command lines, BoardId ...) and of the record of the caller; the programs of MKQwk (config.mko) are not needed. }

Var
  SelIdx: Word;


Function ProtCmd(Send: Boolean; Var ProtNum: Word): String;
  {the protocol of the caller; the command line of the external ones (11 - 20), '' for the internal ones}
  Begin
  ProtNum := GetUserProtNum;
  If ProtNum >= 11 Then
    ProtCmd := OffSplitProt(Config^.GetProtCmdLine(ProtNum), Send)
  Else
    ProtCmd := '';
  End;


Function ProtUsable(ProtNum: Word; Cmd: String): Boolean;
  {the internal protocols 1 - 6 are built in (MKProt: Xmodem, 1k-Xmodem, Ymodem, Zmodem, Ymodem-G, Xmodem-G; Sealink, 7, is
   not used); an external one (11 - 20) needs its command}
  Begin
  ProtUsable := ((ProtNum >= 1) And (ProtNum <= 6)) Or ((ProtNum >= 11) And (Cmd <> ''));
  End;


Procedure SetInternal(Var Prot: ProtObj; ProtNum: Word);
  Begin
  Case ProtNum Of
    1: Prot.SetXmodem;
    2: Prot.SetX1K;
    3: Prot.SetYmodem;
    5: Prot.SetYModemG;
    6: Prot.SetXmodemG;
    Else Prot.SetZmodem;
    End;
  End;


Function InternalSend(FN: String; ProtNum: Word): Boolean;
  Var
    Prot: ProtObj;

  Begin
  Prot.Init;
  SetInternal(Prot, ProtNum);
  Prot.AddSendFile(FN);
  Prot.Send;
  InternalSend := (Prot.PI^.Error = 0) And (Prot.GetFileStatus(1) = 1);
  Prot.Done;
  End;


Function InternalRecv(WorkPath: String; ProtNum: Word): Boolean;
  Var
    Prot: ProtObj;

  Begin
  Prot.Init;
  SetInternal(Prot, ProtNum);
  Prot.SetRecvName('upload.dat');          {Xmodem sends no name; it is renamed afterwards}
  InternalRecv := Prot.Recv(WorkPath) And (Prot.PI^.NumFiles > 0);
  Prot.Done;
  End;


Function SendMail(FN: String; JustName: String; WorkPath: String): Boolean;
  Var
    XferOk: Boolean;
    ProtNum: Word;
    Cmd: String;

  Begin
  Cmd := ProtCmd(True, ProtNum);
  XferOk := ProtUsable(ProtNum, Cmd);
  If XferOk Then
    XferOk := EstimateXferTime(SizeFile(FN), User.GetUserBaud, 90) <
      User.TimeRemain;
  If Not XferOk Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(126));
    User.DisplayNewLine;
    OffPause;
    End
  Else
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(130));
    User.DisplayStrLn(Prompts.GetString(129) + ' ' + JustName);
    User.PostStatus(uoXfer);
    If ProtNum <= 10 Then
      XferOk := InternalSend(FN, ProtNum)
    Else
      XferOk := OffTransfer(OffExpand(Cmd, JustName, 0, 0), StartUpPath, WorkPath);
    User.DisplayNewLine;
    If Not XferOk Then
      Begin
      User.DisplayStrLn(Prompts.GetString(168));
      OffPause;
      End;
    End;
  SendMail := XferOk;
  End;


Function PktSel(N: Word; Var Area: Word; Var Mode: Byte): Boolean;
  {the message areas the caller has chosen for offline mail (and the others for his own mail with "your mail in all areas")}
  Var
    Chosen: Boolean;

  Begin
  PktSel := False;
  If N = 1 Then
    SelIdx := 0;
  While SelIdx < Config^.GetMaxMsgAreas Do
    Begin
    Inc(SelIdx);
    Chosen := (User.GetUserOffline(SelIdx) And Config^.GetMsgAllowOffline(SelIdx)) Or
      Config^.GetMsgForceOffline(SelIdx);
    If Chosen Or (User.GetUserOffAllYour And Config^.GetMsgAllowOffline(SelIdx)) Then
      Begin
      Area := SelIdx;
      If Chosen Then
        Mode := omAll
      Else
        Mode := omMy;
      PktSel := True;
      Exit;
      End;
    End;
  End;


Procedure PktEv(What: Word; Area: Word; N: LongInt);
  Var
    i: Word;

  Begin
  Case What Of
    oeArea: User.DisplayStr(Config^.GetMsgName(Area) + '      ');
    oeAreaMsg: Begin
               For i := 1 To 4 Do
                 User.DisplayBkSpc;
               User.DisplayStr(PadLeft(Long2Str(N), ' ', 4));
               End;
    oeAreaEnd: User.DisplayNewLine;
    End;
  End;


Procedure OfflineDL;
  Var
    Offline: AbsOffPtr;
    OffType: Word;
    WorkPath: String;
    Cont: Boolean;
    Quiet: Boolean;                    {nothing to send or not wanted: not an error}
    Local: Boolean;                    {the sysop at the console: the packet is left in the BBS directory}
    P: OffDLParams;
    R: OffDLResult;
    PackNum: Word;
    ArcName: String;
    ExSpec: OffExtraSpec;
    ExRes: OffExtraRes;
    i: Word;

  Begin
  WorkPath := '';
  Quiet := False;
  FillChar(ExRes, SizeOf(ExRes), 0);
  Local := Not CommActive;
  User.PostStatus(uoMail);
  Offline := nil;
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
    Offline^.SetQwke(Config^.GetOffQwke Or User.GetUserQwkNode);
    Offline^.SetControlFiles((Not User.GetUserQwkNode) Or User.GetUserQwkControl);  {a node asks for them: CONTROL ON}
    If Offline^.StartPacket <> 0 Then
      Cont := False;
    End;
  If Cont Then
    Begin
    P.Sel := PktSel;
    P.Ev := PktEv;
    P.MaxMsgs := User.GetUserOffMax;
    If Config^.GetOffMax < P.MaxMsgs Then
      P.MaxMsgs := Config^.GetOffMax;
    P.AreaMax := User.GetUserOffConfMax;
    If Config^.GetOffConfMax < P.AreaMax Then
      P.AreaMax := Config^.GetOffConfMax;
    P.OwnMsgs := User.GetUserOffOwn;
    P.CheckUser := True;
    Cont := OffExport(Offline, P, R);
    If Cont And (Not User.GetUserQwkNode) Then
      Begin                            {the screens, bulletins and new files list of Offline Mail Parameters: what the caller wants and the sysop allows (or forces)}
      FillChar(ExSpec, SizeOf(ExSpec), 0);
      ExSpec.Screens := Config^.GetOffForceScrn Or (Config^.GetOffAllowScrn And User.GetUserOffScrn);
      ExSpec.Bulletins := Config^.GetOffForceBull Or (Config^.GetOffAllowBull And User.GetUserOffBull);
      ExSpec.NewFiles := Config^.GetOffForceNew Or (Config^.GetOffAllowNew And User.GetUserOffNew);
      For i := 1 To 3 Do
        ExSpec.Scr[i] := Config^.GetOffScrns(i);
      For i := 1 To 10 Do
        ExSpec.Bull[i] := Config^.GetOffBulls(i);
      ExSpec.Head := Config^.GetOffScrns(4);          {the screen above the new files list: Messages > Offline > New Files Head}
      ExSpec.ToReader := Config^.GetOffQwke And (UpCase(User.GetUserOffType) = 'Q');
      ExSpec.Alias := User.GetUserHandle;
      ExSpec.OwnMsgs := User.GetUserOffOwn;
      OffAddExtras(Offline, WorkPath, ExSpec, R, ExRes);
      End;
    If Offline^.ClosePacket <> 0 Then
      Cont := False;
    If Cont And (R.NumMsgs = 0) And (Not User.GetUserOffZero) Then
      Begin
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(178));
      OffPause;
      Quiet := True;
      Cont := False;
      End;
    End;
  If Cont Then
    Begin
    PackNum := GetUserPackerNum;
    ArcName := Offline^.GetArchiveName(PackNum);
    Cont := PackNum > 0;
    If Cont Then
      Begin
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStrLn(Prompts.GetString(189));
      If Local Then
        Cont := OffRun(Config^.GetPackCmdLine(PackNum), StartUpPath, WorkPath,
          WithBackSlash(StartUpPath) + ArcName + ' *.*')
      Else
        Cont := OffRun(Config^.GetPackCmdLine(PackNum), StartUpPath, WorkPath, ArcName + ' *.*');
      End;
    End;
  If Cont And (Not Local) Then
    Begin
    If User.GetUserOffVerify And Not OfflineQuiet Then
      Begin
      Cont := OffVerify(WithBackSlash(WorkPath) + ArcName);
      Quiet := Not Cont;
      End;
    If Cont Then
      Cont := SendMail(WithBackSlash(WorkPath) + ArcName, ArcName, WorkPath);
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
    OffPause;
    End;
  If Offline <> nil Then
    Dispose(Offline, Done);
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


Function OfflineBuildPacket(WorkPath: String; MaxMsgs: LongInt; Var B: OffBuild): Integer;
  Var
    Offline: AbsOffPtr;
    OffType: Word;
    P: OffDLParams;
    PackNum: Word;
    ArcName, Found: String;
    Quiet0: Boolean;
    Cont: Boolean;

  Begin
  OfflineBuildPacket := 2;
  B.ArcPath := '';
  B.Messages := 0;
  B.Why := '';
  FillChar(B.R, SizeOf(B.R), 0);
  Quiet0 := OfflineQuiet;
  OfflineQuiet := True;
  Offline := Nil;
  Cont := ValidateOffline;
  If Not Cont Then
    B.Why := 'the offline mail settings of the user are not complete';
  If Cont Then
    Begin
    Case UpCase(User.GetUserOffType) Of
      'X': OffType := 2;
      'Q': OffType := 1;
      'B': OffType := 3;
      'T': OffType := 4;
      'P': OffType := 5;
      Else
        OffType := 0;
      End;
    If (OffType = 0) And User.GetUserQwkNode Then
      OffType := 1;                    {a QWK node gets QWK packets, whatever types the system offers to callers}
    If (OffType > 0) And (User.GetUserQwkNode Or Config^.GetOffTypeAvail(OffType)) Then
      Case OffType Of
        2: Offline := New(XRSOffPtr, Init);
        1: Offline := New(QwkOffPtr, Init);
        4: Offline := New(TxtOffPtr, Init);
        3: Offline := New(BwvOffPtr, Init);
        End;
    If Offline = Nil Then
      Begin
      Cont := False;
      B.Why := 'the packet type of the user is not available';
      End;
    End;
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Offline^.SetBBSID(Config^.GetBBSID);
    Offline^.SetQwke(Config^.GetOffQwke Or User.GetUserQwkNode);
    Offline^.SetControlFiles((Not User.GetUserQwkNode) Or User.GetUserQwkControl);
    If Offline^.StartPacket <> 0 Then
      Begin
      Cont := False;
      B.Why := 'the packet could not be started';
      End;
    End;
  If Cont Then
    Begin
    P.Sel := PktSel;
    P.Ev := Nil;
    P.MaxMsgs := User.GetUserOffMax;
    If Config^.GetOffMax < P.MaxMsgs Then
      P.MaxMsgs := Config^.GetOffMax;
    If (MaxMsgs > 0) And (MaxMsgs < P.MaxMsgs) Then
      P.MaxMsgs := MaxMsgs;
    P.AreaMax := User.GetUserOffConfMax;
    If Config^.GetOffConfMax < P.AreaMax Then
      P.AreaMax := Config^.GetOffConfMax;
    P.OwnMsgs := User.GetUserOffOwn;
    P.CheckUser := False;
    Cont := OffExport(Offline, P, B.R);
    If Not Cont Then
      B.Why := 'the messages could not be collected';
    End;
  If Cont Then
    Begin
    If Offline^.ClosePacket <> 0 Then
      Begin
      Cont := False;
      B.Why := 'the packet could not be closed';
      End;
    End;
  If Cont And (B.R.NumMsgs = 0) And (Not User.GetUserOffZero) Then
    Begin
    OfflineBuildPacket := 1;
    Cont := False;
    End;
  If Cont Then
    Begin
    PackNum := GetUserPackerNum;
    If PackNum = 0 Then
      Begin
      Cont := False;
      B.Why := 'the user has no packer';
      End
    Else
      Begin
      ArcName := Offline^.GetArchiveName(PackNum);
      Cont := OffRun(Config^.GetPackCmdLine(PackNum), StartUpPath, WorkPath, ArcName + ' *.*');
      ChDir(StripTrail(StartUpPath, DirectorySeparator));
      If IoResult <> 0 Then;
      Found := OffFindNoCase(WorkPath, ArcName);
      If (Not Cont) Or (Found = '') Then
        Begin
        Cont := False;
        B.Why := 'the packer did not make ' + ArcName;
        End
      Else
        Begin
        B.ArcPath := Found;                {OffFindNoCase gives the whole path}
        B.Messages := B.R.NumMsgs;
        OfflineBuildPacket := 0;
        End;
      End;
    End;
  If Offline <> Nil Then
    Dispose(Offline, Done);
  OfflineQuiet := Quiet0;
  End;


Procedure OfflineUL;
  {The reply packet of the caller (QWK): it is received with the protocol of the caller (the sysop at the console:
   <BBSID>.REP in the BBS directory), unpacked in a work directory of its own and its messages are posted.}
  Var
    Offline: AbsOffPtr;
    WorkPath: String;
    Cont, Have: Boolean;
    ProtNum, i, k: Word;
    Cmd, Src: String;
    Cmds: OffCmdList;
    NumCmds: Word;
    Imported: LongInt;
    ImpO: OffImportOpts;
    Local: Boolean;

  Begin
  Local := Not CommActive;
  WorkPath := '';
  Offline := nil;
  If Not ValidateOffline Then
    Exit;
  If UpCase(User.GetUserOffType) <> 'Q' Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(Prompts.GetString(176));
    OffPause;
    Exit;
    End;
  Offline := New(QwkOffPtr, Init);
  Offline^.SetBBSId(Config^.GetBBSID);
  WorkPath := CreateTempDir(Config^.GetTempPath);
  Cont := Length(WorkPath) > 0;
  Have := True;
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    If Local Then
      Begin
      Src := OffFindNoCase(StartUpPath, Offline^.GetReplyName);
      Have := (Src <> '') And CopyFile(Src, WithBackSlash(WorkPath) + 'upload.1');
      End
    Else
      Begin
      User.DisplayNewLine;
      If Not OfflineQuiet Then
        User.AskYN(Prompts.GetString(177), Have);
      If Have Then
        Begin
        Cmd := ProtCmd(False, ProtNum);
        Cont := ProtUsable(ProtNum, Cmd);
        If Cont Then
          Begin
          User.DisplayNewLine;
          User.DisplayAttr(Config^.GetSystemColor(1));
          User.DisplayStrLn(Prompts.GetString(130));
          User.PostStatus(uoXfer);
          If ProtNum <= 10 Then
            Cont := InternalRecv(WorkPath, ProtNum)
          Else
            Cont := OffTransfer(OffExpand(Cmd, '', 0, 0), StartUpPath, WorkPath);
          End;
        If Not Cont Then
          Begin
          User.DisplayNewLine;
          User.DisplayStrLn(Prompts.GetString(168));
          OffPause;
          End;
        End;
      End;
    End;
  If Cont And Have Then
    Begin
    OffRenameUploads(WorkPath);
    NumCmds := 0;
    k := GetUserPackerNum;
    If k > 0 Then
      Begin
      Inc(NumCmds);
      Cmds[NumCmds] := Config^.GetUnPackCmdLine(k);
      End;
    For i := 1 To 10 Do
      If (i <> k) And Config^.GetPackAvail(i) And (NumCmds < 11) Then
        Begin
        Inc(NumCmds);
        Cmds[NumCmds] := Config^.GetUnPackCmdLine(i);
        End;
    If Not OffUnpackReply(Offline, WorkPath, StartUpPath, Cmds, NumCmds) Then
      Begin
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(178));
      If Not Local Then
        OffPause;
      End
    Else
      Begin
      ImpO.BadArea := Config^.GetBadMsgArea;
      ImpO.ForceName := Not User.GetUserQwkNode;
      ImpO.ReDate := Config^.GetOffReDate;
      ImpO.DupeFile := WithBackSlash(Config^.GetMsgPath(1)) + 'qwkdupe.dat';
      Offline^.SetImportOpts(ImpO);
      User.PostStatus(uoMail);
      Offline^.ImportPacket;
      Imported := Offline^.GetImported;
      User.DisplayNewLine;
      User.DisplayStrLn(Long2Str(Imported) + ' message(s) posted');
      If Not Local Then
        OffPause;
      End;
    End
  Else If Cont And Local Then
    Begin
    User.DisplayStrLn(Prompts.GetString(178));
    End;
  If Offline <> nil Then
    Dispose(Offline, Done);
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
