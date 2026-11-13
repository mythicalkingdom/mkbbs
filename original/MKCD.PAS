Unit MKCD;

{$I MKB.DEF}

Interface

Procedure DoCDRom(CtlName: String; DirPath: String);

Implementation

Uses
  {$IFDEF WINDOWS}
  WinDos,
  {$ELSE}
  Dos,
  {$ENDIF}
  MKFile, MKString, MKWild, MKGlobT, MKCfgAbs, MKDoor,
  MKCFile, MKCodes, MKProt, MKFossil, MKRCfgMK;

Type NameRec = Record
  FileName: String[12];
  DirNum: Word;
  Size: LongInt;
  Date: LongInt;
  End;


Const
  MaxDirs = 200;
  MaxFiles = 500;

Type CtlRec = Record
  CPath: String[100];
  Sec: SecType;
  Extra: Array[1..50] of Byte;
  End;


Var
  OFile: File;
  CFile: File;


Const
  ASize = 500;

Type CDArrayType = Array[1..ASize] of NameRec;

Type CDInfo = Record
  NameArray: CDArrayType;
  CurrLoc: Word;
  NumRead: Word;
  End;


Function CDNext(Name: String; Var CDI: CDInfo): Boolean;
  Var
    Found: Boolean;

  Begin
  Found := False;
  Inc(CDI.CurrLoc);
  While ((CDI.NumRead > 0) and (Not Found)) Do
    Begin
    While ((CDI.CurrLoc <= CDI.NumRead) and (Not Found)) Do
      Begin
      If DosMatch(Name, CDI.NameArray[CDI.CurrLoc].FileName) Then
        Found := True
      Else
        Inc(CDI.CurrLoc);
      End;
    If Not Found Then
      Begin
      BlockRead(OFile, CDI.NameArray, ASize, CDI.NumRead);
      CDI.CurrLoc := 1;
      End;
    End;
  CDNext := Found;
  End;



Function CDFirst(Name: String; Var CDI: CDInfo): Boolean;
  Begin
  Seek(OFile, 0);
  BlockRead(OFile, CDI.NameArray, ASize, CDI.NumRead);
  CDI.CurrLoc := 0;
  CDFirst := CDNext(Name, CDI);
  End;


Function DirFileExpand(FileName: String): String;
  Begin
  If ((User.GetUserAvatar) And
  (FileExist(FileName + '.AVT'))) Then
    DirFileExpand := FileName + '.AVT'
  Else If ((User.GetUserAnsi) And
  (FileExist(FileName + '.ANS'))) Then
    DirFileExpand := FileName + '.ANS'
  Else If
  (FileExist(FileName + '.ASC')) Then
    DirFileExpand := FileName + '.ASC'
  Else
    DirFileExpand := FileName;
  End;


Procedure ProcessView(Var CDI: CDInfo);
  Var
    NumRead: Word;
    TmpDir: CtlRec;

  Begin
  Seek(CFile, CDI.NameArray[CDI.CurrLoc].DirNum - 1);
  BlockRead(CFile, TmpDir, 1, NumRead);
  ViewContents(TmpDir.CPath + CDI.NameArray[CDI.CurrLoc].FileName,
  CDI.NameArray[CDI.CurrLoc].FileName);
  End;


Procedure DoCDView(InStr: String);
  Var
    CDI: ^CDInfo;
    CurrStr: String;
    CurrWord: Word;
    NumWords: Word;

  Begin
  New(CDI);
  User.SetMore(True);
  User.SetStopMore(False);
  User.ResetLines(1);
  CurrWord := 1;
  NumWords := WordCount(InStr);
  While ((CurrWord <= NumWords) and (User.Ok) and (Not User.StopMore)) Do
    Begin
    CurrStr := Upper(ExtractWord(InStr, CurrWord));
    If CDFirst(CurrStr, CDI^) Then
      Begin
      ProcessView(CDI^);
      While ((CDNext(CurrStr, CDI^)) and (User.Ok) and (Not User.StopMore)) Do
        ProcessView(CDI^);
      End;
    Inc(CurrWord);
    End;
  Dispose(CDI);
  End;





Procedure ProcessDL(Var CDI: CDInfo; Var TotalSize: LongInt;
  Var Prot: ProtObj; Var NumFiles: Word);

  Var
    NumRead: Word;
    TmpDir: CtlRec;

  Begin
  Seek(CFile, CDI.NameArray[CDI.CurrLoc].DirNum - 1);
  BlockRead(CFile, TmpDir, 1, NumRead);
  Inc(TotalSize, CDI.NameArray[CDI.CurrLoc].Size);
  Inc(NumFiles);
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(PadRight(CDI.NameArray[CDI.CurrLoc].FileName,' ', 14));
  User.DisplayAttr(Config^.GetSystemColor(3));
  User.DisplayStr(PadLeft(CommaStr(CDI.NameArray[CDI.CurrLoc].Size), ' ', 9) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(323) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(PadLeft(CommaStr(EstimateXferTime(CDI.NameArray[CDI.CurrLoc].Size,
    User.GetUserBaud, 90) Div 60), ' ', 4) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(324));
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(PadLeft(CommaStr((User.TimeRemain - EstimateXferTime(TotalSize,
    User.GetUserBaud, 90)) Div 60), ' ', 4) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(325));
  User.DisplayNewLine;
  Prot.AddSendFile(TmpDir.CPath + CDI.NameArray[CDI.CurrLoc].FileName);
  End;


Procedure CDDLLine(Var CDI: CDInfo; InStr: String; Var TotalSize: LongInt;
  Var Prot: ProtObj; Var NumFiles: Word);

  Var
    CurrWord: Word;
    NumWords: Word;
    CurrStr: String;

  Begin
  CurrWord := 1;
  NumWords := WordCount(InStr);
  While ((CurrWord <= NumWords) and (User.Ok) and (Not User.StopMore)) Do
    Begin
    CurrStr := Upper(ExtractWord(InStr, CurrWord));
    If CDFirst(CurrStr, CDI) Then
      Begin
      ProcessDL(CDI, TotalSize, Prot, NumFiles);
      While ((CDNext(CurrStr, CDI)) and (User.Ok) and (Not User.StopMore)) Do
        ProcessDL(CDI, TotalSize, Prot, NumFiles);
      End;
    Inc(CurrWord);
    End;
  End;


Function GetFileStr(NumFiles: Word): String;
  Begin
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(322) + ' ');
  User.DisplayStr(Long2Str(NumFiles + 1) + ' ' + Prompts.GetString (014) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  GetFileStr := User.InputStr('', 50);
  User.DisplayNewLine;
  End;


Procedure DoCDDL(InStr: String);
  Var
    CDI: ^CDInfo;
    CurrStr: String;
    Prot: ProtObj;
    TotalSize: LongInt;
    XFerOK: Boolean;
    ProtNum: Word;
    NumFiles: Word;

  Const
    MaxFiles = 30;

  Begin
  TotalSize := 0;
  NumFiles := 0;
  Prot.Init;
  New(CDI);
  User.SetMore(True);
  User.SetStopMore(False);
  User.ResetLines(1);
  CDDLLine(CDI^, InStr, TotalSize, Prot, NumFiles);
  User.DisplayNewLine;
  CurrStr := GetFileStr(NumFiles);
  While ((User.Ok) and (Length(CurrStr) > 0) and (NumFiles < MaxFiles)) Do
    Begin
    CDDLLine(CDI^, CurrStr, TotalSize, Prot, NumFiles);
    CurrStr := GetFileStr(NumFiles);
    End;
  If TotalSize > 0 Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(Prompts.GetString(326) + ' ' + CommaStr(TotalSize) + ' ');
    User.DisplayStr(Prompts.GetString(327) + ' ' +
      CommaStr(EstimateXferTime(TotalSize, User.GetUserBaud, 90) Div 60) + ' ');
    User.DisplayStrLN(Prompts.GetString(328));
    XferOk := EstimateXferTime(TotalSize, User.GetUserBaud, 90) <
      User.TimeRemain;
    If Not XferOk Then
      Begin
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStrLn(Prompts.GetString(126));
      User.DisplayNewLine;
      User.PressEnter;
      End
    Else
      Begin
      If ((TotalSize Div 1024) > (User.GetUserDLLimit - User.GetUserTodayK)) Then
        Begin
        XferOk := False;
        User.DisplayNewLine;
        User.DisplayAttr(Config^.GetSystemColor(1));
        User.DisplayStrLn(Prompts.GetString(262));
        User.DisplayNewLine;
        User.PressEnter;
        End
      End;
    If XferOk Then
      Begin
      ProtNum := GetProtocol(True);
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
        Prot.Send;
        CommFlow(fcBoth);
        User.UpdateForDL(TotalSize);
        End
      End;
    End;
  Dispose(CDI);
  Prot.Done;
  End;


Procedure DoCDRom(CtlName: String; DirPath: String);
  Var
    Finished: Boolean;
    InStr: String;
    NumWords: Word;
    CurrWord: Word;
    CurrStr: String;
    i: Word;
    TmpStr: String;

  Begin
  Finished := False;
  AddBackSlash(DirPath);
  Assign(OFile, DirPath + CtlName + '.DAT');
  FileMode := fmReadOnly + fmDenyNone;
  If shReset(Ofile, SizeOf(NameRec)) Then;
  Assign(CFile, DirPath + CtlName + '.CTL');
  FileMode := fmReadOnly + fmDenyNone;
  If shReset(CFile, SizeOf(CtlRec)) Then;
  User.DisplayAttr(Config^.GetSystemColor(1));
  If BbsDisplay.DisplayBbsFile(DirFileExpand(DirPath + 'DIR'), ' ') = ' ' Then;
  While ((Not Finished) and (User.Ok)) Do
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(Prompts.GetString(318) + ' ');
    InStr := User.InputStr('', 79 - Length(Prompts.GetString(318)));
    InStr := StripBoth(InStr, ' ');
    User.StatusDisplay(User.GetStatusType);
    User.DisplayNewLine;
    If Length(InStr) > 0 Then
      Begin
      User.ResetLines(1);
      NumWords := WordCount(InStr);
      CurrWord := 1;
      While ((CurrWord <= NumWords) and (User.Ok)) Do
        Begin
        User.CheckInput;
        CurrStr := ExtractWord(InStr, CurrWord);
        If ((Length(CurrStr) = 1) and (Pos(Upper(CurrStr), Upper(Prompts.GetString(319))) > 0)) Then
          Begin
          Case Pos(Upper(CurrStr), Upper(Prompts.GetString(319))) of
            1: Begin
               TmpStr := '';
               For i := CurrWord + 1 To NumWords Do
                 TmpStr := TmpStr + ExtractWord(InStr, i) + ' ';
               TmpStr := StripBoth(TmpStr, ' ');
               DoCDDL(TmpStr);
               CurrWord := NumWords;
               End;
            2: Begin
               User.DisplayAttr(Config^.GetSystemColor(1));
               If BbsDisplay.DisplayBbsFile(DirFileExpand(DirPath + 'DIR'), ' ') = ' ' Then;
               End;
            3: Begin
               TmpStr := '';
               For i := CurrWord + 1 To NumWords Do
                 TmpStr := TmpStr + ExtractWord(InStr, i) + ' ';
               TmpStr := StripBoth(TmpStr, ' ');
               DoCDView(TmpStr);
               CurrWord := NumWords;
               User.DisplayNewLine;
               End;
            End;
          End
        Else
          Begin
          If Length(CurrStr) > 0 Then
            Begin
            If FileExist(DirPath + 'DIR' + CurrStr) Then
              Begin
              User.DisplayAttr(Config^.GetSystemColor(1));
              User.DisplayStrLn(Prompts.GetString(321) + ' ' + CurrStr);
              DisplayDirFile(DirPath + 'DIR' + CurrStr);
              End;
            End
          End;
        Inc(CurrWord);
        End;
      End
    Else
      Finished := True;
    End;
  Close(CFile);
  Close(OFile);
  End;


End.
