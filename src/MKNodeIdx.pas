Program MKNodeIdx;

{$I MKB.Def}

{
     mknodeidx [nodelist ...]

     Builds the nodelist index that MKNSrch (mknodelist, the BBS programs that
     look nodes up) reads: the index file (NodeIdx.Mk / NodeIdx.Ra) and the file
     with the names of the nodelists it covers (NodeInc.Mk / NodeInc.Ra), in the
     nodelist directory of the BBS (MK, RA, QUICK or SBBS names the config
     directory, as for mk).

     Nodelists are given by name: a full path, or a name that is looked for in
     the nodelist directory.  A name with * or ? (NODELIST.*) takes the newest
     file that matches.  Without names the nodelists the existing index covers
     are indexed again (after one of them was replaced by a new week).

     The format (10 byte index entries, 17 byte include entries) was worked out
     from the index files of the sample BBS and is rebuilt byte for byte:

        index entry: type (0 = Zone, 1 = Region, 2 = Host/Net) 1 byte,
                     number 2 bytes, cost 2 bytes (always 0), nodelist number
                     1 byte (1 = the first in the include file),
                     file position 4 bytes (start of the Zone / Region / Host line)
        include entry: file name String[12] (upper case), date and time of the
                     file (DOS packed) 4 bytes

     The entries are in the order of the lists: the first list's zones,
     regions and nets, then the second list's and so on.
}

Uses
  Dos, MKGlobT, MKFile, MKString, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKNSrch;


Const
  BlockSize = 8192;

Type
  IdxArray = Array[1..NodeIdxSize] Of NodeIdxType;
  IncArray = Array[1..NodeIncSize] Of NodeIncType;

Var
  Idx: ^IdxArray;
  Inc_: ^IncArray;
  NumIdx: Word;
  NumInc: Word;
  ListDir: String;
  BbsType: Word;
  i: Word;
  Lists: Array[1..NodeIncSize] Of String;
  NumLists: Word;
  Zones, Regions, Nets: Word;


Procedure Fail(Msg: String; Level: Byte);
  Begin
  WriteLn(StdErr, 'mknodeidx: ' + Msg);
  Halt(Level);
  End;


Function MatchName(N, P: String): Boolean;
  {* and ? like DOS, not case sensitive}
  Begin
  If P = '' Then
    MatchName := (N = '')
  Else If P[1] = '*' Then
    Begin
    If MatchName(N, Copy(P, 2, 255)) Then
      MatchName := True
    Else If N = '' Then
      MatchName := False
    Else
      MatchName := MatchName(Copy(N, 2, 255), P);
    End
  Else If N = '' Then
    MatchName := False
  Else If (P[1] = '?') Or (UpCase(P[1]) = UpCase(N[1])) Then
    MatchName := MatchName(Copy(N, 2, 255), Copy(P, 2, 255))
  Else
    MatchName := False;
  End;


Function Newest(Mask: String): String;
  {The newest file that matches the mask (a path with * or ?), '' = none}
  Var
    SR: SearchRec;
    Best: LongInt;
    D: DirStr;
    N: NameStr;
    E: ExtStr;
    Res: String;

  Begin
  Res := '';
  Best := -1;
  FSplit(Mask, D, N, E);
  FindFirst(D + '*', AnyFile, SR);
  While DosError = 0 Do
    Begin
    If ((SR.Attr And Directory) = 0) And (SR.Time > Best) Then
      Begin
      { * and ? like DOS, not case sensitive }
      If MatchName(SR.Name, N + E) Then
        Begin
        Best := SR.Time;
        Res := D + SR.Name;
        End;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  Newest := Res;
  End;


Function ListPath(Name: String): String;
  {Where the nodelist named on the command line is}
  Var
    Full: String;

  Begin
  If (Pos('*', Name) > 0) Or (Pos('?', Name) > 0) Then
    Begin
    If Pos('/', Name) = 0 Then
      Full := ListDir + Name
    Else
      Full := Name;
    ListPath := Newest(Full);
    Exit;
    End;
  If FileExist(Name) Then
    ListPath := Name
  Else
    ListPath := ListDir + Name;
  End;


Procedure AddEntry(T: Byte; Number: Word; FileNum: Byte; FPos: LongInt);
  Begin
  If NumIdx >= NodeIdxSize Then
    Fail('too many zones, regions and nets for the index (at most ' + Long2Str(NodeIdxSize) + ')', 3);
  Inc(NumIdx);
  Idx^[NumIdx].NodeType := T;
  Idx^[NumIdx].Number := Number;
  Idx^[NumIdx].Cost := 0;
  Idx^[NumIdx].FileNum := FileNum;
  Idx^[NumIdx].FilePos := FPos;
  End;


Procedure ProcessLine(Var Line: String; FileNum: Byte; FPos: LongInt);
  Var
    T: Byte;
    P: Word;
    N: LongInt;
    Code: Integer;
    Num: String;
    Up: String;

  Begin
  T := 255;
  Up := Upper(Copy(Line, 1, 7));
  If Copy(Up, 1, 5) = 'ZONE,' Then
    T := 0
  Else If Copy(Up, 1, 7) = 'REGION,' Then
    T := 1
  Else If Copy(Up, 1, 5) = 'HOST,' Then
    T := 2;
  If T = 255 Then
    Exit;
  P := Pos(',', Line);
  Num := Copy(Line, P + 1, 10);
  P := Pos(',', Num);
  If P > 0 Then
    Num := Copy(Num, 1, P - 1);
  Val(Num, N, Code);
  If (Code <> 0) Or (N < 0) Or (N > 65535) Then
    Exit;
  AddEntry(T, N, FileNum, FPos);
  Case T Of
    0: Inc(Zones);
    1: Inc(Regions);
    2: Inc(Nets);
    End;
  End;


Procedure IndexList(N: Word; Path: String);
  Var
    F: File;
    Buf: Array[1..BlockSize] Of Char;
    Got: Word;
    k: Word;
    Line: String;
    LineStart, Offset: LongInt;
    Time: LongInt;
    D: DirStr;
    Nm: NameStr;
    E: ExtStr;
    Z0, R0, N0: Word;

  Begin
  Z0 := Zones;
  R0 := Regions;
  N0 := Nets;
  Assign(F, Path);
  FileMode := fmReadOnly + fmDenyNone;
  {$I-}
  Reset(F, 1);
  {$I+}
  If IoResult <> 0 Then
    Fail('cannot read ' + Path, 2);
  GetFTime(F, Time);
  FSplit(Path, D, Nm, E);
  If Length(Nm + E) > 12 Then
    Fail('the name ' + Nm + E + ' is longer than 12 characters', 2);
  Inc_^[N].FileName := Upper(Nm + E);
  Inc_^[N].FileTime := Time;
  Line := '';
  LineStart := 0;
  Offset := 0;
  Repeat
    BlockRead(F, Buf, BlockSize, Got);
    For k := 1 To Got Do
      Begin
      If Buf[k] = #10 Then
        Begin
        ProcessLine(Line, N, LineStart);
        Line := '';
        LineStart := Offset + 1;
        End
      Else If (Buf[k] <> #13) And (Buf[k] <> #26) And (Length(Line) < 255) Then
        Line := Line + Buf[k];
      Inc(Offset);
      End;
  Until Got < BlockSize;
  If Length(Line) > 0 Then
    ProcessLine(Line, N, LineStart);
  Close(F);
  WriteLn('  ', Upper(Nm + E), ': ', Zones - Z0, ' zones, ', Regions - R0, ' regions, ', Nets - N0, ' nets');
  End;


Procedure ReadInclude;
  {The lists the existing index covers}
  Var
    F: File;
    Rec: NodeIncType;
    Got: Word;
    FN: String;

  Begin
  FN := ListDir + Config^.GetNodeIncName;
  If Not FileExist(FN) Then
    Exit;
  Assign(F, FN);
  FileMode := fmReadOnly + fmDenyNone;
  {$I-}
  Reset(F, SizeOf(Rec));
  {$I+}
  If IoResult <> 0 Then
    Exit;
  While (Not Eof(F)) And (NumLists < NodeIncSize) Do
    Begin
    BlockRead(F, Rec, 1, Got);
    If Got = 1 Then
      Begin
      Inc(NumLists);
      Lists[NumLists] := Lower(Rec.FileName);      {stored in upper case, the files are lower case}
      End;
    End;
  Close(F);
  End;


Begin
BbsType := DetectBbsType;
Config := Nil;
Case BbsType Of
  1: Config := NewMKConfig(True);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Fail('No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory', 1);
Config^.Load;
If Config^.GetError <> 0 Then
  Fail(Long2Str(Config^.GetError) + ': Error loading config files', 1);
ListDir := Config^.GetNodeListPath;
If ListDir = '' Then
  Fail('the configuration has no nodelist directory', 1);
If (ListDir[Length(ListDir)] <> '/') Then
  ListDir := ListDir + '/';
New(Idx);
New(Inc_);
NumIdx := 0;
NumLists := 0;
If ParamCount > NodeIncSize Then
  Fail('too many nodelists (at most ' + Long2Str(NodeIncSize) + ')', 3);
If ParamCount = 0 Then
  Begin
  ReadInclude;
  If NumLists = 0 Then
    Begin
    WriteLn('Correct syntax is: MKNodeIdx NodeList [NodeList ...]');
    WriteLn('(a name with * or ? takes the newest file, e.g. NODELIST.*)');
    Halt(1);
    End;
  End
Else
  Begin
  For i := 1 To ParamCount Do
    Begin
    Inc(NumLists);
    Lists[NumLists] := ParamStr(i);
    End;
  End;
WriteLn('Indexing in ', ListDir);
NumInc := 0;
Zones := 0;
Regions := 0;
Nets := 0;
For i := 1 To NumLists Do
  Begin
  If ListPath(Lists[i]) = '' Then
    Fail('no nodelist ' + Lists[i] + ' found', 2);
  Inc(NumInc);
  IndexList(NumInc, ListPath(Lists[i]));
  End;
If NumIdx = 0 Then
  Fail('no Zone, Region or Host lines found: these are not nodelists', 3);
If SaveFile(ListDir + Config^.GetNodeIdxName, Idx^, NumIdx * SizeOf(NodeIdxType)) <> 0 Then
  Fail('cannot write ' + ListDir + Config^.GetNodeIdxName, 4);
If SaveFile(ListDir + Config^.GetNodeIncName, Inc_^, NumInc * SizeOf(NodeIncType)) <> 0 Then
  Fail('cannot write ' + ListDir + Config^.GetNodeIncName, 4);
WriteLn('Wrote ', Config^.GetNodeIdxName, ' (', NumIdx, ' entries) and ', Config^.GetNodeIncName, ' (',
  NumInc, ' lists)');
Dispose(Config, Done);
End.
