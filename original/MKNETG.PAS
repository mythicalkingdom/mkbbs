Unit MKNetG; {QWK/Rep work routines}

{$I MKB.DEF}

Interface

Uses MKPack, MKNetGl;

Var
  TempDir: String[128];                {Temporary work directory}
  OrigDir: String[128];                {Startup directory}
  Packers: PackInfoType;
  PackObj: PackFileObj;
  Result: Integer;
  NumExported: LongInt;
  NumImported: LongInt;


Procedure DoBanner;                    {Display ansi banner}
Procedure StatusLine(Str: String);     {Display status message}
Procedure DisplayNumExported;          {Update number exported display}
Procedure DisplayNumImported;          {Update number imported display}
Procedure DisplayConfLine(Str: String); {Update conference display}
Function  UnPack(FilePath: String; Contents: String): Integer;
Function  PackFile(FilePath: String; Contents: String; PType: Word): Integer;
Procedure ExportRep;
Procedure PackRep;
Procedure UnPackQwks;
Procedure SetCQwkRec(QN: LongInt);
Procedure FlushQwkBuf;
Procedure HaltNil(Pt: Pointer);        {Halt on nil pointer - out of memory!}

Implementation

Uses MKString, MKFile, MKAvatar, MKScrn, ExecAcc, Dos, MKOpen,
  MKMsgAbs, MKDupe, Crc32,
{$IFDEF OPRO}
  OpCrt;
{$ELSE}
  Crt;
{$ENDIF}

{$I MKNBAN.INC}

Type QIdxRec = Record
  Area: Word;
  SPos: LongInt;
  End;

Const
  QIdxSize = 6000;
  QwkBufSize = 150;
  RawAreas = 15000;
  DupeChkSize = 4000;
  DupeDays = 15;

Type QIdxArray = Array[1..QIdxSize] of QIdxRec;
Type NStatArray = Array[1..MaxNetAreas] of Boolean;
Type QwkRecType = Array[1..128] of Char;
Type QwkBufType = Array[0..QwkBufSize] of QwkRecType;
Type RawAreaType = Array[0..RawAreas] of Boolean;

Var
  QI: ^QIdxArray;        {Index of QWK messages}
  NS: ^NStatArray;       {Areas with net status}
  MsgsInQwk: Word;       {Number of messages in this QWK packet}
  MsgsInArea: ^RawAreaType; {Packet contains msgs in area}
  QwkBuf: ^QwkBufType;   {Qwk record buffer}
  CQwkRec: ^QwkRecType;  {Active Qwk record pointer}
  QwkWorkNum: LongInt;   {Current working QWK record number}
  BufStart: LongInt;     {Record number of first record in buffer}
  QwkNumRead: Integer;   {Number of read records in the buffer}
  NeedWritten: Array[0..QwkBufSize] of Boolean; {buffer needs written}
  QwkFile: File;         {QWK/REP file}
  QwkError: Word;        {Status from QWK file activity}
  QwkCurrPos: Word;      {Current char within QwkRec}
  ChkDupe: DupeObj;      {Duplicate msg checking}


Procedure CrcString(Var Crc: LongInt; InStr: String);
  Var
    Counter: Word;

  Begin
  If Length(InStr) > 0 Then
    For Counter := 1 To Length(InStr) Do
      Crc := UpdC32(Ord(InStr[Counter]),Crc);
  End;


Procedure HaltNil(Pt: Pointer);
  Begin
  If Pt = Nil Then
    Begin
    ClrScr;
    WriteLn('Insufficient memory');
    Write (#7, #7);
    Delay(10);
    WriteLn;
    Halt(10);
    End;
  End;


Procedure StatusLine(Str: String);
  Begin
  Window(41, 19, 69, 20);
  GoToXY(1, 2);
  TextAttr := LightGreen;
  WriteLn;
  Write(Copy(Str, 1, 27));
  Window(1,1, ScreenWidth, ScreenHeight);
  End;


Procedure DisplayConfLine(Str: String);
  Begin
  Window(1,1, ScreenWidth, ScreenHeight);
  TextAttr := LightGreen;
  GoToXY(41,14);
  Write(PadRight(Copy(Str,1,27),' ', 27));
  End;


Procedure DisplayNumExported;
  Begin
  Window(1,1, ScreenWidth, ScreenHeight);
  TextAttr := LightGreen;
  GoToXY(50,4);
  Write(PadLeft(Long2Str(NumExported),' ', 6));
  End;


Procedure DisplayNumImported;
  Begin
  Window(1,1, ScreenWidth, ScreenHeight);
  TextAttr := LightGreen;
  GoToXY(50,9);
  Write(PadLeft(Long2Str(NumImported),' ', 6));
  End;


Procedure SetNeedWritten(QN: LongInt);
  Var
    BC: LongInt;

  Begin
  BC := Qn - BufStart;
  If ((BC >= 0) and (BC <= QwkBufSize)) Then
    NeedWritten[BC] := True;
  End;


Procedure FlushQwkBuf;
  Var
    i: Integer;

  Begin
  i := QwkBufSize;
  While ((Not NeedWritten[i]) and (i >= 0)) Do
    Dec(i);
  Inc(i);
  If i > 0 Then
    Begin
    Seek(QwkFile, BufStart);
    QwkError := IoResult;
    If QwkError = 0 Then
      Begin
      BlockWrite(QwkFile, QwkBuf^, i);
      QwkError := IoResult;
      If QwkError <> 0 Then
        Write(#7, #7, #7);
      End;
    BufStart := -3000;
    For i := 0 to QwkBufSize Do
      NeedWritten[i] := False;
    End;
  End;


Procedure SetCQwkRec(QN: LongInt);
  Var
    i: Word;

  Begin
  QwkError := 0;
  If ((QN >= BufStart) and (Qn < (BufStart + QwkBufSize))) Then
    CQwkRec := @QwkBuf^[QN - BufStart]
  Else
    Begin
    FlushQwkBuf;
    BufStart := Qn;
    Seek(QwkFile, BufStart);
    QwkError := IoResult;
    If QwkError = 0 Then
      Begin
      BlockRead(QwkFile, QwkBuf^, QwkBufSize, QwkNumRead);
      QwkError := IoResult;
      End;
    For i := 0 to QwkBufSize Do
      NeedWritten[i] := False;
    CQwkRec := @QwkBuf^[0];
    End;
  End;


Procedure PutHdrStr(St: String; Loc: Word);
  Var
    i: Word;

  Begin
  For i := 1 to Length(St) Do
    CQwkRec^[Loc + i - 1] := St[i];
  End;


Function GetHdrStr(Start:Integer; NumChar:Integer):String;
  Var
    TempStr: String;
    I: Integer;
    Count: Integer;

  Begin
  If ((Start + NumChar) > 129) Then
    NumChar := 129 - Start;
  TempStr := '';
  Count := 0;
  I := Start;
  While Count < NumChar Do
    Begin
    TempStr[Count + 1] := CQwkRec^[Start + Count];
    Inc(Count);
    End;
  TempStr[0] := Chr(NumChar);
  GetHdrStr := TempStr;
  End;



Procedure StartPacket(HdrStr: String);
  Begin
  QwkWorkNum := 0;
  SetCQwkRec(QwkWorkNum);
  FillChar(CQwkRec^, SizeOf(QwkRecType), ' ');
  PutHdrStr(HdrStr, 1);
  SetNeedWritten(0);
  End;


Procedure PutStr(Var St: String);
  Var
    i: Word;

  Begin
  For i := 1 to Length(St) Do
    Begin
    Inc(QwkCurrPos);
    If QwkCurrPos > 128 Then
      Begin
      Inc(QwkWorkNum);
      QwkCurrPos := 1;
      SetCQwkRec(QwkWorkNum);
      SetNeedWritten(QwkWorkNum);
      End;
    CQwkRec^[QwkCurrPos] := St[i];
    End;
  End;


Function GetAreaTag(Area: Word): String;
  Begin
  If HostCfg^.AreaTags[Area] = 0 Then
    GetAreaTag := HostCfg^.LocalTag
  Else
    GetAreaTag := HostCfg^.AltTags[HostCfg^.AreaTags[Area]];
  End;


Procedure ExportMsg(Var Msg: AbsMsgObj; Area: Word; MKNArea: Word);
  Const
    StrLen = 72;

  Var
    TmpStr: String;
    ShortStr: String;
    i: Word;
    MsgStartQwk: LongInt;
    Crc: LongInt;

  Begin
  Msg.MsgStartUp;
  Crc := $FFFFFFFF;        {initialise}
  CrcString(Crc, Msg.GetTo);
  CrcString(Crc, Msg.GetFrom);
  CrcString(Crc, Msg.GetSubj);
  CrcString(Crc, Msg.GetDate);
  CrcString(Crc, Msg.GetTime);
  Crc := UpdC32(Area, Crc);
  If ((Msg.IsPriv) and (HostCfg^.NoExpPriv)) Then
    Begin
    StatusLine('Skipping Priv message');
    End
  Else
    Begin
    If ((Not Msg.IsDeleted) and (Not ChkDupe.DupeCheck(Crc))) Then {Dupe checking}
      Begin
      Inc(NumExported);
      DisplayNumExported;
      Inc(QwkWorkNum);
      SetCQwkRec(QwkWorkNum);
      MsgStartQwk := QwkWorkNum;
      SetNeedWritten(QwkWorkNum);
      QwkCurrPos := 129;
      FillChar(CQwkRec^, SizeOf(QwkRecType), ' ');
      If Msg.IsRcvd Then
        Begin
        If Msg.IsPriv Then
          CQwkRec^[1] := '*'
        Else
          CQwkRec^[1] := '-'
        End
      Else
        Begin
        If Msg.IsPriv Then
          CQwkRec^[1] := '+'
        Else
          CQwkRec^[1] := ' '
        End;
      TmpStr := PadRight(Copy(Long2Str(Area),1,7),' ',7); {REP has area in msg num}
      PutHdrStr(TmpStr, 2);
      PutHdrStr(Msg.GetDate, 9);
      PutHdrStr(Copy(Msg.GetTime, 1, 5), 17);
      PutHdrStr(Upper(Copy(Msg.GetTo, 1, 25)), 22);
      PutHdrStr(Upper(Copy(Msg.GetFrom, 1, 25)), 47);
      PutHdrStr(Copy(Msg.GetSubj, 1, 25), 72);
      PutHdrStr(PadRight(Copy(Long2Str(Msg.GetRefer),1,8),' ',8), 109);
      CQwkRec^[123] := #225;
      CQwkRec^[124] := Chr(Lo(Area));
      CQwkRec^[125] := Chr(Area shr 8);
      CQwkRec^[128] := '*';
      Msg.MsgTxtStartUp;
      TmpStr := Msg.GetString(StrLen);
      TmpStr[0] := Chr(Length(TmpStr) + 1);
      TmpStr[Length(TmpStr)] := #227;
      ShortStr := Upper(Copy(TmpStr, 1, 7));
      While (Not Msg.EOM) or (Length(TmpStr) > 1) Do
        Begin
        If ((TmpStr[1] <> #1) and (ShortStr <> ' * ORIG')
        And (ShortStr <> 'SEEN-BY')) Then
          PutStr(TmpStr)
        Else
          Begin
          While (Not Msg.EOM and Msg.WasWrap) Do
            TmpStr := Msg.GetString(StrLen);
          End;
        TmpStr := Msg.GetString(StrLen);
        TmpStr[0] := Chr(Length(TmpStr) + 1);
        TmpStr[Length(TmpStr)] := #227;
        ShortStr := Upper(Copy(TmpStr, 1, 7));
        End;
      If Msg.IsLocal Then
        Begin
        TmpStr := ' þ MKNet þ ' + GetAreaTag(MKNArea) + #227;
        PutStr(TmpStr);
        End;
      If QwkCurrPos < 128 Then
        Begin
        For i := QwkCurrPos + 1 to 128 Do
          CQwkRec^[i] := ' ';
        End;
      SetCQwkRec(MsgStartQwk);
      PutHdrStr(PadRight(Long2Str(QwkWorkNum + 1 - MsgStartQwk),' ',6),117);
      SetNeedWritten(MsgStartQwk);
      SetCQwkRec(QwkWorkNum);
      End
    Else
      StatusLine('Ignoring exported dupe');
    End;
  End;


Procedure ExportRep;
  Var
    RError: Word;
    CArea: Word;
    CMsg: AbsMsgPtr;
    i: Word;

  Begin
  NumExported := 0;
  StatusLine('Initializing Dupe checking');
  ChkDupe.Init;                        {Initialize duplicate checker}
  ChkDupe.Open(HostCfg^.InQwkPath + HostName + '.Dup', DupeChkSize);
  ChkDupe.SetDays(DupeDays);           {Ignore dupes over dupedays days old}
  New(QwkBuf);
  HaltNil(QwkBuf);
  QwkNumRead := 0;
  BufStart := -1000;
  For i := 0 to QwkBufSize Do
    NeedWritten[i] := False;
  StatusLine('Exporting Messages');
  Assign(QwkFile, TempDir + HostName + '.MSG');
  If FileExist(TempDir + HostName + '.MSG') Then
    Begin
    StatusLine('Adding to existing msgs');
    Filemode := fmReadWrite + fmDenyNone;
    Reset(QwkFile, 128);
    RError := IoResult;
    If RError <> 0 Then
      Write(#7, #7, #7);
    If RError = 0 Then
      Begin
      QwkWorkNum := FileSize(QwkFile) - 1;
      End;
    End
  Else
    Begin
    StatusLine('Starting New Packet');
    ReWrite(QwkFile, 128);
    RError := IoResult;
    QwkWorkNum := 0;
    SetCQwkRec(QwkWorkNum);
    StartPacket(HostName);
    End;
  For CArea := 1 To MaxNetAreas Do
    Begin
    If ((HostCfg^.Areas[CArea].QwkNum >= 0) And
    (Length(HostCfg^.Areas[CArea].AreaId) > 0)) Then
      Begin
      If OpenMsgArea(CMsg, HostCfg^.Areas[CArea].AreaId) Then
        Begin
        DisplayConfLine(HostCfg^.Areas[CArea].AreaId);
        CMsg^.SeekFirst(HostCfg^.Areas[CArea].LastRead + 1);
        While CMsg^.SeekFound Do
          Begin
          ExportMsg(CMsg^, HostCfg^.Areas[CArea].QwkNum, CArea);
          CMsg^.SeekNext;
          End;
        HostCfg^.Areas[CArea].LastRead := CMsg^.GetHighMsgNum;
        If CloseMsgArea(CMsg) Then;
        End;
      End;
    End;
  FlushQwkBuf;
  Close(QwkFile);
  If IoResult <> 0 Then;
  Dispose(QwkBuf);
  ChkDupe.CloseFile;
  ChkDupe.Done;
  If SaveHost Then;
  End;


Function PackFile(FilePath: String; Contents: String; PType: Word): Integer;
  Var
   PRec: PackRecType;
   CLine: String;
   TX, TY: Byte;
   Pt: Pointer;
   UPError: Integer;
   Result: Integer;
   CDir: String;

  Begin
  GetDir(0, CDir);
  ChDir(StripTrail(TempDir, ' '));
  UPError := IoResult;
  TX := WhereX;
  TY := WhereY;
  UPError := 0;
  If Not SaveScrnRegion(1,1, ScrnWidth, ScrnHeight, Pt) Then
    UPError := -1000;
  Window(1,1,ScrnWidth, ScrnHeight);
  ClrScr;
  If UPError = 0 Then
    Begin
    Cline := Packers.PackLine[PType] + FilePath + ' ' + Contents;
    If Not NWInitExecSwap(HeapPtr, HostCfg^.WorkPath + 'MKNET.$$$') Then
      UPError := -900;
    End;
  If UPError = 0 Then
    Begin
    Result := ExecWithSwap(Packers.PackPath[PType], CLine);
    NWShutDownExecSwap;
    RestoreScrnRegion(1,1, ScrnWidth, ScrnHeight, Pt);
    If IoResult <> 0 Then;
    UPError := Result;
    End;
  ChDir('..');
  If IoResult <> 0 Then;
  ChDir(StripTrail(CDir, ' '));
  If IoResult <> 0 Then;
  PackFile := UPError;
  End;


Function UnPack(FilePath: String; Contents: String): Integer;
  Var
   PRec: PackRecType;
   CLine: String;
   TX, TY: Byte;
   Pt: Pointer;
   UPError: Integer;
   Result: Integer;
   CDir: String;

  Begin
  GetDir(0, CDir);
  ChDir(StripTrail(TempDir, ' '));
  UPError := IoResult;
  TX := WhereX;
  TY := WhereY;
  UPError := 0;
  If Not SaveScrnRegion(1,1, ScrnWidth, ScrnHeight, Pt) Then
    UPError := -1000;
  Window(1,1,ScrnWidth, ScrnHeight);
  ClrScr;
  If UPError = 0 Then
    Begin
    PackObj.PackFirst(FilePath);
    Cline := Packers.UnPackLine[PackObj.GetPackType] + FilePath + ' ' + Contents;
    If Not NWInitExecSwap(HeapPtr, HostCfg^.WorkPath + 'MKNET.$$$') Then
      UPError := -900;
    End;
  If UPError = 0 Then
    Begin
    Result := ExecWithSwap(Packers.UnPackPath[PackObj.GetPackType], CLine);
    NWShutDownExecSwap;
    RestoreScrnRegion(1,1, ScrnWidth, ScrnHeight, Pt);
    If IoResult <> 0 Then;
    UPError := Result;
    End;
  ChDir('..');
  If IoResult <> 0 Then;
  ChDir(StripTrail(CDir, ' '));
  If IoResult <> 0 Then;
  UnPack := UPError;
  End;


Procedure PackRep;
  Var
    PackType: Word;
    Result: Word;

  Begin
  Case UpCase(HostCfg^.ComprType) of
    'L': PackType := 1;
    'Z': PackType := 2;
    'A': PackType := 3;
    'O': PackType := 4;
    'D': PackType := 5;
    'J': PackType := 6;
    'H': PackType := 7;
    Else
      PackType := 0;
    End;
  If PackType > 0 Then
    Begin
    If SizeFile(TempDir + HostName + '.MSG') > 128 Then
      Begin
      Result := PackFile(HostCfg^.OutRepPath + HostName + '.REP',
        TempDir + HostName + '.MSG', PackType);
      If Result <> 0 Then
        StatusLine('Error ' + Long2Str(Result) + ' Packing Rep');
      End
    Else
      StatusLine('No messages exported');
    End
  Else
    StatusLine('Error: Invalid packer type');
  If EraseFile(TempDir + HostName + '.MSG') Then;
  End;


Procedure BuildIndex;
  Type CharSet = Set of Char;

  Var
    i: Word;
    MaxNum: LongInt;
    NumBlocks: LongInt;
    LastMsgEnd: LongInt;

  Const
    DateSep = ['-','/', #196];

  Begin
  StatusLine('Scanning packet');
  LastMsgEnd := 0;
  For i := 0 To RawAreas Do
    MsgsInArea^[i] := False;
  QwkWorkNum := 0;
  SetCQwkRec(QwkWorkNum);
  If Upper(GetHdrStr(0, 8)) <> 'PRODUCED' Then {Check for global net-status}
    Begin
    For i := 1 to MaxNetAreas Do
      NS^[i] := True;
    StatusLine('Global Net Status');
    End;
  MaxNum := FileSize(QwkFile);
  QwkWorkNum := 1;
  While (QwkWorkNum <= MaxNum) Do
    Begin
    SetCQwkRec(QwkWorkNum);
    If ((CQwkRec^[11] in DateSep) and (CQwkRec^[14] in DateSep) and
    (CQwkRec^[19] = ':')) Then
      Begin
      Inc(MsgsInQwk);
      QI^[MsgsInQwk].Area := Ord(CQwkRec^[124]);
      If CQwkRec^[125] <> ' ' Then
      Inc(QI^[MsgsInQwk].Area, (Word(Ord(CQwkRec^[125])) * 256));
      MsgsInArea^[QI^[MsgsInQwk].Area] := True;
      QI^[MsgsInQwk].SPos := QwkWorkNum;
      NumBlocks := Str2Long(StripBoth(GetHdrStr(117, 6),' '));
      If NumBlocks < 1 Then
        NumBlocks := 1;
      Inc(QwkWorkNum, NumBlocks);
      LastMsgEnd := QwkWorkNum - 1;
      End
    Else
      Begin
      NumBlocks := 1;
      Inc(QwkWorkNum, NumBlocks);
      End;
    End;
  StatusLine(Long2str(MsgsInQwk) + ' Messages in packet');
  End;


Procedure ProcessMessages;
  Type TmpMsgType = Record
    MsgFrom: String[25];
    MsgTo: String[25];
    MsgSubj: String[25];
    MsgDate: String[9];
    MsgTime: String[5];
    NumBlocks: LongInt;
    HasTag: Boolean;
    StatusChar: Char;
    EndBlock: LongInt;
    End;

  Var
    MsgCount: Word;
    Area: Word;
    Msg: AbsMsgPtr;
    i: Word;
    TmpMsg: ^TmpMsgType;
    Crc: LongInt;
    BlockEnd: Word;
    CharCnt: Word;
    Ch: Char;
    BBSArea: Word;

  Begin
  New(TmpMsg);
  HaltNil(TmpMsg);
  For Area := 0 to RawAreas Do
    Begin
    If MsgsInArea^[Area] Then
      Begin
      BBSArea := 1;
      While ((BbsArea < MaxNetAreas) And (HostCfg^.Areas[BBSArea].QwkNum <> Area)) Do
        Inc(BBSArea);
      If ((HostCfg^.Areas[BbsArea].QwkNum = Area) and
      (Length(HostCfg^.Areas[BbsArea].AreaId) > 0)) Then
        Begin
        If OpenOrCreateMsgArea(Msg, HostCfg^.Areas[BbsArea].AreaId) Then
          Begin
          If HostCfg^.LongLock Then
            If Msg^.LockMsgBase Then;
          Msg^.SetMailType(mmtEchoMail);
          For MsgCount := 1 to MsgsInQwk Do
            Begin
            If QI^[MsgCount].Area = Area Then
              Begin
              QwkWorkNum := QI^[MsgCount].SPos;
              SetCQwkRec(QwkWorkNum);
              TmpMsg^.MsgFrom := Proper(StripTrail(GetHdrStr(47, 25),' '));
              If TmpMsg^.MsgFrom = 'Sysop' Then
                TmpMsg^.MsgFrom := HostCfg^.HostSysop;
              TmpMsg^.MsgTo := Proper(StripTrail(GetHdrStr(22, 25), ' '));
              If TmpMsg^.MsgTo = 'Sysop' Then
                TmpMsg^.MsgTo := HostCfg^.HostSysop;
              TmpMsg^.MsgSubj := GetHdrStr(72, 25);
              TmpMsg^.MsgDate := GetHdrStr(9, 8);
              TmpMsg^.MsgTime := GetHdrStr(17, 5);
              TmpMsg^.StatusChar := CQwkRec^[1];
              TmpMsg^.HasTag := (CQwkRec^[128] = '*');
              TmpMsg^.NumBlocks := Str2Long(StripBoth(GetHdrStr(117, 6),' '));
              If TmpMsg^.NumBlocks < 1 Then
                TmpMsg^.NumBlocks := 1;
              TmpMsg^.EndBlock := QwkWorkNum + TmpMsg^.NumBlocks - 1;
              Crc := $FFFFFFFF;        {initialise}
              CrcString(Crc, TmpMsg^.MsgTo);
              CrcString(Crc, TmpMsg^.MsgFrom);
              CrcString(Crc, TmpMsg^.MsgSubj);
              CrcString(Crc, TmpMsg^.MsgDate);
              CrcString(Crc, TmpMsg^.MsgTime);
              Crc := UpdC32(Area, Crc);
              If (Not ChkDupe.DupeCheck(Crc)) Then {Dupe checking}
                Begin
                Inc(NumImported);
                DisplayNumImported;
                Msg^.StartNewMsg;
                Msg^.SetFrom(TmpMsg^.MsgFrom);
                Msg^.SetTo(TmpMsg^.MsgTo);
                Msg^.SetSubj(TmpMsg^.MsgSubj);
                Msg^.SetDate(TmpMsg^.MsgDate);
                Msg^.SetTime(TmpMsg^.MsgTime);
                Msg^.SetLocal(HostCfg^.GateWay);
                Msg^.SetEcho(HostCfg^.GateWay);
                Case TmpMsg^.StatusChar of
                  '`': Begin
                       Msg^.SetRcvd(True);
                       Msg^.SetPriv(True);
                       End;
                  '-': Msg^.SetRcvd(True);
                  '*': Begin
                       Msg^.SetRcvd(True);
                       Msg^.SetPriv(True);
                       End;
                  '^': Msg^.SetRcvd(True);
                  '#': Msg^.SetRcvd(True);
                  '+': Msg^.SetPriv(True);
                  '~': Msg^.SetPriv(True);
                  End;
                Inc(QwkWorkNum);
                While QwkWorkNum <= TmpMsg^.EndBlock Do
                  Begin
                  SetCQwkRec(QwkWorkNum);
                  BlockEnd := 128;
                  If QwkWorkNum = TmpMsg^.EndBlock Then
                    Begin
                    While ((CQwkRec^[BlockEnd] in [#0, ' ']) and (BlockEnd > 1)) Do
                      Dec(BlockEnd);
                    End;
                  CharCnt := 1;
                  While CharCnt <= BlockEnd Do
                    Begin
                    Ch := CQwkRec^[CharCnt];
                    Case Ch Of
                      #0:; {ignore nulls}
                      #10:; {ignore line feeds}
                      #$E3: Msg^.DoChar(#13);
                      #$14: Msg^.DoChar(#13);
                      Else
                        Msg^.DoChar(Ch);
                      End;
                    Inc(CharCnt);
                    End;
                  Inc(QwkWorkNum);
                  End;
                If Not TmpMsg^.HasTag Then
                  Msg^.DoStringLn(' þ MKNet þ ' + HostCfg^.HostTagLine);
                If ((HostCfg^.NoImpPriv) and (Msg^.IsPriv)) Then
                  Begin
                  StatusLine('Skipping Priv message');
                  End
                Else
                  Begin
                  If Not Msg^.WriteMsg = 0 Then
                    StatusLine('Error saving message');
                  End;
                End
              Else
                StatusLine('Duplicate in area ' + Long2Str(Area));
              End;
            End;
          HostCfg^.Areas[BBSArea].LastRead := Msg^.GetHighMsgNum;
          If HostCfg^.LongLock Then
            If Msg^.UnLockMsgBase Then;
          If CloseMsgArea(Msg) Then;
          End
        Else
          StatusLine(HostCfg^.Areas[i].AreaId + ' Error opening');
        End
      Else
        StatusLine(Long2Str(Area) + ' Area not defined');
      End;
    End;
  Dispose(TmpMsg);
  If SaveHost Then;
  End;


Procedure DoNetFlags;
  Const
    MaxTmpNet = 4000;

  Type
    NetFlags = Array[0..MaxTmpNet] of Boolean;

  Var
   TmpNet: ^NetFlags;
   i: Word;

  Begin
  New(TmpNet);
  HaltNil(TmpNet);
  FillChar(TmpNet^, SizeOf(TmpNet^), #0);
  If LoadFile('NetFlags.Dat', TmpNet^, SizeOf(TmpNet^)) = 0 Then
    Begin
    For i := 1 to MaxNetAreas Do
      NS^[i] := TmpNet^[HostCfg^.Areas[i].QwkNum];
    End;
  Dispose(TmpNet);
  End;


Procedure ProcessQwk(QN: String);
  Var
    i: Word;

  Begin
  Chdir(StripTrail(TempDir,'\'));
  StatusLine('Processing ' + Qn);
  If UnPack(Qn, 'Messages.Dat NetFlags.Dat') = 0 Then; {unpack messages.dat and netflags.dat}
  New(QI);                             {allocate Qwk index}
  HaltNil(QI);
  New(NS);                             {allocate netstatus flags}
  HaltNil(NS);
  New(MsgsInArea);
  HaltNil(MsgsInArea);
  For i := 1 to MaxNetAreas Do
    NS^[i] := False;                   {Set net-status to false}
  MsgsInQwk := 0;                      {Initialize msgs in qwk to zero}
  If FileExist('NetFlags.Dat') Then
    DoNetFlags;                        {Check for net-status in netflags.dat}
  Assign(QwkFile, TempDir + 'Messages.Dat');
  Filemode := fmReadWrite + fmDenyNone;
  Reset(QwkFile, 128);                 {Open Qwk file}
  QwkError := IoResult;
  New(QwkBuf);                         {Allocate Qwk buffer}
  HaltNil(QwkBuf);
  QwkNumRead := 0;
  BufStart := -5000;                   {Invalidate buffer}
  For i := 0 to QwkBufSize Do
    NeedWritten[i] := False;
  BuildIndex;                          {Build index of msgs in packet}
  ProcessMessages;                     {Process/Import messages}
  Close(QwkFile);
  QwkError := IoResult;
  Dispose(QwkBuf);
  Dispose(MsgsInArea);
  Dispose(NS);
  Dispose(QI);
  If EraseFile(TempDir + 'Messages.Dat') Then; {Clean up files extracted}
  If EraseFile(TempDir + 'NetFlags.Dat') Then;
  If EraseFile(Qn) Then; {erase qwk after processing}
  End;


Procedure UnPackQwks;
  Var
    FI: FindObj;

  Begin
  StatusLine('Initializing Dupe checking');
  ChkDupe.Init;                        {Initialize duplicate checker}
  ChkDupe.Open(HostCfg^.InQwkPath + HostName + '.Dup', DupeChkSize);
  ChkDupe.SetDays(DupeDays);           {Ignore dupes over DupeDays days old}
  StatusLine('Processing QWK files');
  Fi.Init;
  ChDir(StripTrail(TempDir,'\'));
  Fi.FFirst(HostCfg^.InQwkPath + HostName + '.QW?'); {search for QW? files}
  While Fi.Found Do
    Begin
    ProcessQwk(Fi.GetFullPath); {Process QW? files that are found}
    Fi.FNext;
    End;
  Fi.Done;
  ChkDupe.CloseFile;
  ChkDupe.Done;
  End;

End.
