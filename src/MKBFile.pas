{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKBFile;

{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKCfgAbs, MKString,
  Dos;

Const MaxFiles = 800;

Type NewRec = Record
    Name: String[12];
    Date: LongInt;
    Size: LongInt;
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
  FBbs: TFile;
  End;


Type FSearchInfoType = Record
  TmpStr: String;
  Mask: String[13];
  Sec: SecType;
  MaxAreas: Word;
  AreaNo: Word;
  Found: Boolean;
  ST: Byte;
  SR: SearchRec;
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
  NewFiles^.FBbs.Init;
  End;


Procedure NewFileObj.NewFileDone;
  Begin
  NewFiles^.FBbs.Done;
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
  Var
    FileList: String[128];

  Begin
  NewFiles^.CurrNew := 0;
  LoadNewArray(NewFiles^.AreaNo);
  If NewFiles^.NewThisArea > 0 Then
    Begin
    FileList := Config^.GetFileListPath(NewFiles^.AreaNo);
    If NewFiles^.FBbs.OpenTextFile(FileList) Then
      NewNextThisArea;
    End;
  End;


Procedure NewFileObj.NewNextThisArea;      {Find next new files in area}
  Var
    TempName: String[12];
    j: Word;
    Match: Boolean;

  Begin
  NewFiles^.TmpStr := NewFiles^.Fbbs.GetString;
  While ((NewFiles^.Fbbs.StringFound) and (NewFiles^.CurrNew = 0)) Do
    Begin
    TempName := Copy(Upper(ExtractWord(NewFiles^.TmpStr, 1)),1,12);
    J := 1;
    Match := False;
    While ((j <= NewFiles^.NewThisArea) and (Not Match)) Do
      Begin
      If (TempName = NewFiles^.NewArray[j].Name) Then
        Begin
        NewFiles^.CurrNew := j;
        NewFiles^.TmpStr := StripLead(Copy(NewFiles^.TmpStr, Length(TempName) + 1, 240), ' ');
        Match := True;
        End;
      Inc(j);
      End;
    If NewFiles^.CurrNew = 0 Then
      NewFiles^.TmpStr := NewFiles^.Fbbs.GetString;
    End;
  If NewFiles^.CurrNew = 0 Then
    If NewFiles^.Fbbs.CloseTextFile Then;
  End;


Procedure NewFileObj.LoadNewArray(AreaNo: Word);
  Var
    SR2: SearchRec;
  FilePath: String[128];
  FileList: String[128];

  Begin
  FilePath := Config^.GetFileAreaPath(NewFiles^.AreaNo);
  FileList := Config^.GetFileListPath(NewFiles^.AreaNo);
  NewFiles^.NewThisArea := 0;
  If FileExist(FileList) Then
    Begin
    FindFirst(FilePath + '*.*', Archive + ReadOnly, SR2);
    If IoResult <> 0 Then;
    While ((DosError = 0) and (NewFiles^.NewThisArea < MaxFiles)) Do
      Begin
      If SR2.Time >= NewFiles^.LastDate Then
        Begin
        Inc(NewFiles^.NewThisArea);
        NewFiles^.NewArray[NewFiles^.NewThisArea].Name := SR2.Name;
        NewFiles^.NewArray[NewFiles^.NewThisArea].Date := SR2.Time;
        NewFiles^.NewArray[NewFiles^.NewThisArea].Size := SR2.Size;
        End;
      FindNext(SR2);
      If IoResult <> 0 Then;
      End;
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


Procedure FileSearchObj.SearchThisArea;
  Var
    FilePath: String[128];

  Begin
  FilePath := Config^.GetFileAreaPath(FileSearch^.AreaNo);
  FindFirst(FilePath + FileSearch^.Mask, Archive + ReadOnly, FileSearch^.SR);
  If IoResult <> 0 Then;
  If DosError = 0 Then
    FileSearch^.Found := True;
  End;


Procedure FileSearchObj.FileNext;           {Find next}
  Begin
  FileSearch^.Found := False;
  FindNext(FileSearch^.SR);
  If DosError = 0 Then
    FileSearch^.Found := True
  Else
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
    GetName := FileSearch^.SR.Name
  Else
    GetName := '';
  End;


Function  FileSearchObj.GetSize: LongInt;   {Get size of found file}
  Begin
  If FileSearch^.Found Then
    GetSize := FileSearch^.SR.Size
  Else
    GetSize := 0;
  End;


Function  FileSearchObj.GetDate: LongInt;   {Get date of found file}
  Begin
  If FileSearch^.Found Then
    GetDate := FileSearch^.SR.Time
  Else
    GetDate := 0;
  End;


Function  FileSearchObj.GetArea: Word;      {Get area of found file}
  Begin
  GetArea := FileSearch^.AreaNo;
  End;


End.
