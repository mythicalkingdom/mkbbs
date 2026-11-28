{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKBFile;

{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKCfgAbs, MKString, MKFileIdx, MKWild,
  Dos;

Const MaxFiles = 800;

Type NewRec = Record
    Name: String;
    Date: LongInt;
    Size: LongInt;
    Desc: String;                      {the first line of the description in the list}
    End;

Type NewInfo = Record
  TmpStr: String;
  TempSize: LongInt;
  NewArray: Array[1..MaxFiles] of NewRec;
  NewThisArea: Word;
  CurrNew: Word;
  LastDate: LongInt;
  Sec: SecType;
  MaxAreas: Word;
  AreaNo: Word;
  Next: Word;                          {the entry of NewArray that the next search starts at}
  End;


Type FSearchInfoType = Record
  TmpStr: String;
  Mask: String[13];
  Sec: SecType;
  MaxAreas: Word;
  AreaNo: Word;
  Found: Boolean;
  ST: Byte;
  Ents: TFileEnts;                     {the files of the area (MKFileIdx)}
  Cur: LongInt;                        {the found file}
  End;



Type NewFileObj = Object
  NewFiles: ^NewInfo;
  Procedure NewFileInit;               {Initialize new file search}
  Procedure NewFileDone;               {Done new file search}
  Procedure NewFileFirst(Sec: SecType; LastDate: LongInt); {Find first}
  Procedure NewFileNext;               {Find next}
  Function  NewFileFound: Boolean;     {New file was found?}
  Function  NewFileGetName: String;    {Get name of found file}
  Function  NewFIleGetSize: LongInt;   {Get size of found file}
  Function  NewFileGetDate: LongInt;   {Get date of found file}
  Function  NewFileGetDesc: String;    {Get description of found file}
  Function  NewFileGetArea: Word;      {Get area of found file}
  Procedure NewFirstThisArea;          {Find first new files in area}
  Procedure NewNextThisArea;           {Find next new files in area}
  Procedure LoadNewArray(AreaNo: Word);{Internal use}
  End;


Type FileSearchObj = Object
  FileSearch: ^FSearchInfoType;
  Procedure Init;                           {Initialize new file search}
  Procedure Done;                           {Done new file search}
  Procedure FileFirst(Sec: SecType; Mask: String; ST: Byte); {Find first}
                  {ST=1 View, ST=2 DL}
  Procedure FileNext;                       {Find next}
  Procedure SearchThisArea;                 {Internal use only}
  Procedure NextMatch;                      {Internal use only}
  Function  FileFound: Boolean;             {Was found?}
  Function  GetName: String;                {Get name of found file}
  Function  GetSize: LongInt;               {Get size of found file}
  Function  GetDate: LongInt;               {Get date of found file}
  Function  GetArea: Word;                  {Get area of found file}
  End;


Var
  NewF: NewFileObj;
  FSearch: FileSearchObj;

Implementation

Procedure NewFileObj.NewFileInit;
  Begin
  New(NewFiles);
  NewFiles^.CurrNew := 0;
  NewFiles^.Next := 1;
  End;


Procedure NewFileObj.NewFileDone;
  Begin
  IndexFlush;
  Dispose(NewFiles);
  End;


Procedure NewFileObj.NewFileFirst(Sec: SecType; LastDate: LongInt);
  Begin
  NewFiles^.NewThisArea := 0;
  NewFiles^.LastDate := LastDate;
  NewFiles^.Sec := Sec;
  NewFiles^.AreaNo := 1;
  NewFiles^.MaxAreas := Config^.GetMaxFileAreas;
  NewFiles^.CurrNew := 0;
  While (NewFiles^.AreaNo <= NewFiles^.MaxAreas) And
  (NewFiles^.CurrNew = 0) Do
    Begin
    If ((Length(Config^.GetFileAreaName(NewFiles^.AreaNo)) > 0) and
    (Config^.FileViewAccess(NewFiles^.AreaNo, Sec)) And
    (Not Config^.GetFileNoNew(NewFiles^.AreaNo))) Then
      NewFirstThisArea;
    If NewFiles^.CurrNew = 0 Then
      Inc(NewFiles^.AreaNo);
    End;
  End;


Procedure NewFileObj.NewFirstThisArea;
  Begin
  NewFiles^.CurrNew := 0;
  LoadNewArray(NewFiles^.AreaNo);
  NewFiles^.Next := 1;
  NewNextThisArea;
  End;


Procedure NewFileObj.NewNextThisArea;      {Find next new files in area}
  Begin
  If NewFiles^.Next <= NewFiles^.NewThisArea Then
    Begin
    NewFiles^.CurrNew := NewFiles^.Next;
    Inc(NewFiles^.Next);
    NewFiles^.TmpStr := NewFiles^.NewArray[NewFiles^.CurrNew].Desc;
    End
  Else
    NewFiles^.CurrNew := 0;
  End;


Procedure NewFileObj.LoadNewArray(AreaNo: Word);
  {the files of the area that are listed (files.bbs or a PCBoard DIR file) and newer than LastDate, by name; from the index of MKFileIdx when it is up to date}
  Var
    Ents: TFileEnts;
    i, k: LongInt;

  Begin
  NewFiles^.NewThisArea := 0;
  If (Config^.GetFileAreaPath(AreaNo) = '') Then
    Exit;
  AreaFiles(AreaNo, Ents, True);
  For i := 0 To High(Ents) Do
    If (Ents[i].Listed) And (DosTimeOf(Ents[i].Time) >= NewFiles^.LastDate) And (NewFiles^.NewThisArea < MaxFiles) Then
      Begin
      Inc(NewFiles^.NewThisArea);
      NewFiles^.NewArray[NewFiles^.NewThisArea].Name := Ents[i].Name;
      NewFiles^.NewArray[NewFiles^.NewThisArea].Date := DosTimeOf(Ents[i].Time);
      NewFiles^.NewArray[NewFiles^.NewThisArea].Size := Ents[i].Size;
      k := Pos(#10, Ents[i].Desc);
      If k = 0 Then
        NewFiles^.NewArray[NewFiles^.NewThisArea].Desc := Ents[i].Desc
      Else
        NewFiles^.NewArray[NewFiles^.NewThisArea].Desc := Copy(Ents[i].Desc, 1, k - 1);
      End;
  End;


Procedure NewFileObj.NewFileNext;
  Begin
  NewFiles^.CurrNew := 0;
  NewNextThisArea;
  If (NewFiles^.CurrNew = 0) Then
    Inc(NewFiles^.AreaNo);
  While (NewFiles^.AreaNo <= NewFiles^.MaxAreas) And
  (NewFiles^.CurrNew = 0) Do
    Begin
    If ((Config^.FileViewAccess(NewFiles^.AreaNo, NewFiles^.Sec)) And
    (Length(Config^.GetFileAreaName(NewFiles^.AreaNo)) > 0) and
    (Not Config^.GetFileNoNew(NewFiles^.AreaNo))) Then
      NewFirstThisArea;
    If NewFiles^.CurrNew = 0 Then
      Inc(NewFiles^.AreaNo);
    End;
  End;


Function  NewFileObj.NewFileGetName: String;
  Begin
  NewFileGetName := NewFiles^.NewArray[NewFiles^.CurrNew].Name;
  End;


Function  NewFileObj.NewFileGetSize: LongInt;
  Begin
  NewFileGetSize := NewFiles^.NewArray[NewFiles^.CurrNew].Size;
  End;


Function  NewFileObj.NewFileGetDate: LongInt;
  Begin
  NewFileGetDate := NewFiles^.NewArray[NewFiles^.CurrNew].Date;
  End;


Function  NewFileObj.NewFileGetDesc: String;
  Begin
  NewFileGetDesc := NewFiles^.TmpStr;
  End;


Function  NewFileObj.NewFileGetArea: Word;
  Begin
  NewFileGetArea := NewFiles^.AreaNo;
  End;


Function NewFileObj.NewFileFound: Boolean;
  Begin
  NewFileFound := (NewFiles^.CurrNew <> 0);
  End;


Procedure FileSearchObj.Init;
  Begin
  New(FileSearch);
  FileSearch^.Found := False;
  End;


Procedure FileSearchObj.Done;
  Begin
  IndexFlush;
  Dispose(FileSearch);
  End;


Procedure FileSearchObj.FileFirst(Sec: SecType; Mask: String; ST: Byte);
  Begin
  FileSearch^.Sec := Sec;
  FileSearch^.Mask := Mask;
  FileSearch^.ST := ST;
  FileSearch^.AreaNo := 1;
  FileSearch^.MaxAreas := Config^.GetMaxFileAreas;
  FileSearch^.Found := False;
  While (FileSearch^.AreaNo <= FileSearch^.MaxAreas) And
  (FileSearch^.Found = False) Do
    Begin
    If ((Length(Config^.GetFileAreaName(FileSearch^.AreaNo)) > 0) and
    (Length(Config^.GetFileAreaPath(FileSearch^.AreaNo)) > 0) And
    (((St = 1) and (Config^.FileViewAccess(FileSearch^.AreaNo, Sec))) Or
    ((St = 2) and (Config^.FileDLAccess(FileSearch^.AreaNo, Sec))))) Then
      SearchThisArea;
    If Not FileSearch^.Found Then
      Inc(FileSearch^.AreaNo);
    End;
  End;


Procedure FileSearchObj.NextMatch;
  {the next file of the area (after Cur) that fits the mask: Found, Cur}
  Begin
  FileSearch^.Found := False;
  Inc(FileSearch^.Cur);
  While (FileSearch^.Cur <= High(FileSearch^.Ents)) And (Not FileSearch^.Found) Do
    Begin
    If DosMatch(Upper(FileSearch^.Mask), Upper(FileSearch^.Ents[FileSearch^.Cur].Name)) Then
      FileSearch^.Found := True
    Else
      Inc(FileSearch^.Cur);
    End;
  End;


Procedure FileSearchObj.SearchThisArea;
  Begin
  AreaFiles(FileSearch^.AreaNo, FileSearch^.Ents, True);
  FileSearch^.Cur := -1;
  NextMatch;
  End;


Procedure FileSearchObj.FileNext;           {Find next}
  Begin
  NextMatch;
  If Not FileSearch^.Found Then
    Inc(FileSearch^.AreaNo);
  While (FileSearch^.AreaNo <= FileSearch^.MaxAreas) And
  (FileSearch^.Found = False) Do
    Begin
    If ((Length(Config^.GetFileAreaName(FileSearch^.AreaNo)) > 0) and
    (Length(Config^.GetFileAreaPath(FileSearch^.AreaNo)) > 0) And
    (((FileSearch^.St = 1) and
      (Config^.FileViewAccess(FileSearch^.AreaNo, FileSearch^.Sec))) Or
    ((FileSearch^.St = 2) and
      (Config^.FileDLAccess(FileSearch^.AreaNo, FileSearch^.Sec))))) Then
      SearchThisArea;
    If Not FileSearch^.Found Then
      Inc(FileSearch^.AreaNo);
    End;
  End;


Function  FileSearchObj.FileFound: Boolean; {Was found?}
  Begin
  FileFound := FileSearch^.Found;
  End;


Function  FileSearchObj.GetName: String;    {Get name of found file}
  Begin
  If FileSearch^.Found Then
    GetName := FileSearch^.Ents[FileSearch^.Cur].Name
  Else
    GetName := '';
  End;


Function  FileSearchObj.GetSize: LongInt;   {Get size of found file}
  Begin
  If FileSearch^.Found Then
    GetSize := FileSearch^.Ents[FileSearch^.Cur].Size
  Else
    GetSize := 0;
  End;


Function  FileSearchObj.GetDate: LongInt;   {Get date of found file}
  Begin
  If FileSearch^.Found Then
    GetDate := DosTimeOf(FileSearch^.Ents[FileSearch^.Cur].Time)
  Else
    GetDate := 0;
  End;


Function  FileSearchObj.GetArea: Word;      {Get area of found file}
  Begin
  GetArea := FileSearch^.AreaNo;
  End;


End.
