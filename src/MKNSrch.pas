Unit MKNSrch; {Search nodelist index}
{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKRCfgMK;

Const
  NodeIdxSize = 3000;
  NodeIncSize = 50;


Type NodeIdxArray = Array[1..NodeIdxSize] of NodeIdxType;
Type NodeIncArray = Array[1..NodeIncSize] of NodeIncType;


Type NodeInfoType = Record
  NodeIdx: NodeIdxArray;
  NodeInc: NodeIncArray;
  Loaded: Boolean;
  Error: Word;
  NumInc: Byte;
  IdxFile: File;
  IncFile: File;
  ListFile: TFile;
  NumLists: Word;
  NumIdx: Word;
  CurrIdx: Word;
  CurrZone: Word;
  SearchPos: Word;
  End;


Type NodeListObj = Object
  NI: ^NodeInfoType;
  Procedure Init;                           {Initialize}
  Procedure Load;                           {Load NodeIdx file.nam}
  Procedure Done;                           {Done}
  Function  GetError: Word;                 {Get error result}
  Function  ZoneNext: Word;
  Function  ZoneFirst: Word;
  Function  NetFirst(Zone: Word): Word;
  Function  NetNext: Word;
  Function  GetOffset(Addr: AddrType): LongInt; {Get nodelist file position}
  Function  GetNLFileName: String;
  Function  NodeStr(Addr: AddrType): String; {Get nodelist string}
  End;


Function GetNodeSection(InStr: String; Section: Word): String;


Implementation


Uses MKString, MKCfgAbs,
  Dos;



Function GetNodeSection(InStr: String; Section: Word): String;
  Var
    i: Word;
    Cnt: Word;
    TStr: String;

  Begin
  i := 1;
  Cnt := 0;
  While (Cnt < Section) and (i < Length(InStr)) Do
    Begin
    If InStr[i] = ',' Then
      Inc(Cnt);
    Inc(i);
    End;
  TStr := '';
  If Cnt = Section Then
    Begin
    While ((i <= Length(InStr)) and (InStr[i] <> ',')) Do
      Begin
      Inc(TStr[0]);
      TStr[Length(TStr)] := InStr[i];
      Inc(i);
      End;
    End;
  For i := 1 To Length(TStr) Do
    If TStr[i] = '_' Then
      TStr[i] := ' ';
  GetNodeSection := TStr;
  End;


Function NodeListObj.NodeStr(Addr: AddrType): String;
  Var
    TF: TFile;
    NOff: LongInt;
    TmpStr: String;
    Finished: Boolean;
    Found: Boolean;
    NType: String;

  Begin
  NOff := GetOffset(Addr);
  TF.Init;
  If Not TF.OpenTextFile(Config^.GetNodeListPath + GetNLFileName) Then
     Begin
     NodeStr := ',,Unable to Open Nodelist';
     Exit;
     End;
  If NOff >= 0 Then
    Begin
    If TF.SeekTextFile(NOff) Then;
      TmpStr := TF.GetString;
    If Addr.Node <> 0 Then
      Begin
      Finished := False;
      Found := False;
      If Tf.StringFound Then
        TmpStr := TF.GetString;
      While ((Tf.StringFound) And (Not Finished)) Do
        Begin
        NType := Upper(GetNodeSection(TmpStr, 0));
        If (NType = 'ZONE') or (NType = 'HOST') or (NType = 'REGION') Then
          Finished := True;
        If Str2Long(GetNodeSection(TmpStr,1)) = Addr.Node Then
          Begin
          Found := True;
          Finished := True;
          End;
        If Not Found Then
          TmpStr := TF.GetString;
        End;
      End
    Else
      Found := True;
    End;
  If TF.CloseTextFile Then;
  TF.Done;
  If ((Found) and (Noff >= 0)) Then
    NodeStr := TmpStr
  Else
    NodeStr := ',,Address Not Found';
  End;


Procedure NodeListObj.Init;                 {Initialize}
  Begin
  New(NI);
  NI^.Loaded := False;
  NI^.Error := 0;
  End;


Procedure NodeListObj.Load;
  Var
    FN: String;

  Begin
  FN := Config^.GetNodeListPath;
  NI^.Error := 0;
  If Not NI^.Loaded Then
    Begin
    If Not FileExist(FN + Config^.GetNodeIdxName) Then
      NI^.Error := 1000;
    If NI^.Error = 0 Then
      Begin
      If Not shAssign(NI^.IdxFile, FN + Config^.GetNodeIdxName) Then NI^.Error := 1010;
      FileMode := fmReadOnly + fmDenyNone;
      If Not shReset(NI^.IdxFile, SizeOf(NodeIdxType)) Then
        NI^.Error := 1010;
      End;
    If NI^.Error = 0 Then
      Begin
      If Not shRead(NI^.IdxFile, NI^.NodeIdx, NodeIdxSize, NI^.NumIdx) Then
        Begin
        NI^.Loaded := False;
        NI^.Error := 1020;
        End;
      End;
    If Not FileExist(FN + Config^.GetNodeIncName) Then
      NI^.Error := 1000;
    If NI^.Error = 0 Then
      Begin
      If Not shAssign(NI^.IncFile, FN + Config^.GetNodeIncName) Then NI^.Error := 1010;
      FileMode := fmReadOnly + fmDenyNone;
      If Not shReset(NI^.IncFile, SizeOf(NodeIncType)) Then
        NI^.Error := 1010;
      End;
    If NI^.Error = 0 Then
      If Not shRead(NI^.IncFile, NI^.NodeInc, NodeIncSize, NI^.NumLists) Then
        NI^.Error := 1020;
    Close(NI^.IncFile);
    If IoResult <> 0 Then;
    End;
  End;


Function NodeListObj.ZoneFirst: Word;
  Begin
  NI^.CurrIdx := 0;
  ZoneFirst := ZoneNext;
  End;


Function NodeListObj.ZoneNext: Word;
  Var
    Finished: Boolean;

  Begin
  Finished := False;
  Inc(NI^.CurrIdx);
  While ((NI^.CurrIdx <= NI^.NumIdx) And (Not Finished)) Do
    Begin
    If NI^.NodeIdx[NI^.CurrIdx].NodeType = 0 Then
      Begin
      Finished := True
      End;
    If Not Finished Then
      Inc(NI^.CurrIdx);
    End;
  If Finished Then
    ZoneNext := NI^.NodeIdx[NI^.CurrIdx].Number
  Else
    ZoneNext := 0;
  End;


Function NodeListObj.NetFirst(Zone: Word): Word;
  Var
    Tmp: Word;

  Begin
  NI^.CurrZone := Zone;
  Tmp := ZoneFirst;
  While ((Tmp <> 0) And (Tmp <> NI^.CurrZone)) Do
    Tmp := ZoneNext;
  NetFirst := NetNext;
  End;


Function NodeListObj.NetNext: Word;
  Var
    Finished: Boolean;

  Begin
  Inc(NI^.CurrIdx);
  Finished := False;
  Inc(NI^.CurrIdx);
  While ((NI^.CurrIdx <= NI^.NumIdx) And (Not Finished)) Do
    Begin
    If NI^.NodeIdx[NI^.CurrIdx].NodeType = 2 Then
      Finished := True;
    If NI^.NodeIdx[NI^.CurrIdx].NodeType = 0 Then
      NI^.CurrIdx := NI^.NumIdx + 1;
    If Not Finished Then
      Inc(NI^.CurrIdx);
    End;
  If Finished Then
    NetNext := NI^.NodeIdx[NI^.CurrIdx].Number
  Else
    NetNext := 0;
  End;


Function NodeListObj.GetOffset(Addr: AddrType): LongInt;
  Var
    i :Word;
    State: Word;
    CZone: Word;
    CRegion: Word;
    CNet: Word;
    Finished: Boolean;

  Begin
  i := 1;
  CZone := 0;
  CRegion := 0;
  CNet := 0;
  Finished := False;
  GetOffset := -1;
  While Not Finished Do
    Begin
    If i > NI^.NumIdx Then
      Begin
      Finished := True;                       {not in the index (it used to run on past the end)}
      End
    Else
    Case NI^.NodeIdx[i].NodeType of
      0: Begin                              {Zone}
         CZone := NI^.NodeIdx[i].Number;
         If CZone > Addr.Zone Then
           Begin
           Finished := True;
           GetOffset := -1;
           End;
         End;
      1: Begin                              {Region}
         CRegion := NI^.NodeIdx[i].Number;
         End;
      2: Begin                              {Net}
         CNet := NI^.NodeIdx[i].Number;
         If CZone = Addr.Zone Then
           Begin
           If CNet = Addr.Net Then
             Begin
             Finished := True;
             NI^.SearchPos := i;
             GetOffset := NI^.NodeIdx[i].FilePos;
             End;
           End;
         End;  {2 = Net}
       End; {Case}
    Inc(i);
    End;  {While}
  End;  {Function GetOffset}


Function NodeListObj.GetNLFileName: String;
  Begin
  GetNLFileName := NI^.NodeInc[NI^.NodeIdx[NI^.SearchPos].FileNum].FileName;
  End;


Function NodeListObj.GetError: Word;
  Begin
  GetError := NI^.Error;
  End;


Procedure NodeListObj.Done;                 {Done}
  Begin
  Close(NI^.IdxFile);
  If IoResult <> 0 Then;
  Close(NI^.IncFile);
  If IoResult <> 0 Then;
  Dispose(NI);
  End;


End.
