Unit MKFile;
{$I MKB.Def}

{
     MKFile - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses Dos;

Const
  fmReadOnly = 0;          {FileMode constants}
  fmWriteOnly = 1;
  fmReadWrite = 2;
  fmDenyAll = 16;
  fmDenyWrite = 32;
  fmDenyRead = 48;
  fmDenyNone = 64;
  fmNoInherit = 128;


Const
  Tries: Word = 150;
  TryDelay: Word = 100;




Type FindRec = Record
  SR: SearchRec;
  Dir: DirStr;
  Name: NameStr;
  Ext: ExtStr;
  DError: Word;
  Active: Boolean;     {A search is open and needs FindClose}
  End;


Type FindObj = Object
  FI: ^FindRec;
  Procedure Init; {Initialize}
  Procedure Done; {Done}
  Procedure FFirst(FN: String); {Find first}
  Procedure FNext;
  Function  Found: Boolean; {File was found}
  Function  GetName: String; {Get Filename}
  Function  GetFullPath: String; {Get filename with path}
  Function  GetDate: LongInt; {Get file date}
  Function  GetSize: LongInt; {Get file size}
  End;


Type TFileArray = Array[1..$fff0] of Char;

Type TFileRec = Record
  MsgBuffer: ^TFileArray;
  BufferPtr: Word;
  BufferChars: Word;
  BufferStart: LongInt;
  BufferFile: File;
  CurrentStr: String;
  StringFound: Boolean;
  Error: Word;
  BufferSize: Word;
  PrevCR: Boolean;     {Last character read was a CR (GetString)}
  End;


Type TFile = Object
  TF: ^TFileRec;
  Procedure Init;
  Procedure Done;
  Function  GetString:String;          {Get string from file}
  Function  GetUString: String; {Get LF delimited string}
  Function  OpenTextFile(FilePath: String): Boolean;  {Open file}
  Function  CloseTextFile: Boolean;    {Close file}
  Function  GetChar: Char;             {Internal use}
  Procedure BufferRead;                {Internal use}
  Function  StringFound: Boolean;      {Was a string found}
  Function  SeekTextFile(SeekPos: LongInt): Boolean; {Seek to position}
  Function  GetTextPos: LongInt;       {Get text file position}
  Function  Restart: Boolean;          {Reset to start of file}
  Procedure SetBufferSize(BSize: Word); {Set buffer size}
  End;



Var
  MKFileError: Word;


Function  FileExist(FName: String): Boolean;
Function  DirExist(FName: String): Boolean;
Function  SizeFile(FName: String): LongInt;
Function  DateFile(FName: String): LongInt;
Function  FindPath(FileName: String): String;
Function  LongLo(InNum: LongInt): Word;
Function  LongHi(InNum: LongInt): Word;
Function  LockFile(Var F; LockStart: LongInt; LockLength: LongInt): Word;
Function  UnLockFile(Var F; LockStart: LongInt; LockLength: LongInt): Word;
Function  shAssign(Var F: File; FName: String): Boolean;
Function  shLock(Var F; LockStart,LockLength: LongInt): Word;
Procedure FlushFile(Var F); {Dupe file handle, close dupe handle}
Function  shReset(Var F: File; RecSize: Word): Boolean;
Function  shRead(Var F: File; Var Rec; ReadSize: Word; Var NumRead: Word): Boolean;
Function  shWrite(Var F: File; Var Rec; ReadSize: Word): Boolean;
Function  ResolveCase(FName: String): String;
  {The DOS files were named in either case; Unix cares.  Returns FName if it
   exists, else the same path with the file name in lower case, else in upper
   case, if one of those exists, else FName unchanged.}
Function  shOpenFile(Var F: File; PathName: String): Boolean;
Function  shMakeFile(Var F: File; PathName: String): Boolean;
Procedure shCloseFile(Var F: File);
Function  shSeekFile(Var F: File; FPos: LongInt): Boolean;
Function  shFindFile(Pathname: String; Var Name: String; Var Size, Time: LongInt): Boolean;
Procedure shSetFTime(Var F: File; Time: LongInt);
Function  GetCurrentPath: String;
Procedure CleanDir(FileDir: String);
Function  IsDevice(FilePath: String): Boolean;
Function  LoadFilePos(FN: String; Var Rec; FS: Word; FPos: LongInt): Word;
Function  LoadFile(FN: String; Var Rec; FS: Word): Word;
Function  SaveFilePos(FN: String; Var Rec; FS: Word; FPos: LongInt): Word;
Function  SaveFile(FN: String; Var Rec; FS: Word): Word;
Function  ExtendFile(FN: String; ToSize: LongInt): Word;
Function  CreateTempDir(FN: String): String;
Function  GetTempName(FN: String): String;
Function  GetTextPos(Var F: Text): LongInt;
Function  FindOnPath(FN: String; Var OutName: String): Boolean;
Function  CopyFile(FN1: String; FN2: String): Boolean;
Function  EraseFile(FN: String): Boolean;
Function  MakePath(FP: String): Boolean;


Implementation

Uses
  MKString, MKPlat;

Const
  AllFilesMask = {$IFDEF UNIX}'*'{$ELSE}'*.*'{$ENDIF};  {FPC's Dos unit on Unix needs '*', not '*.*'}

Function IsPathSep(Ch: Char): Boolean;
  Begin
  IsPathSep := (Ch = DirectorySeparator) Or (Ch = '/');
  End;






Procedure FindObj.Init;
  Begin
  New(FI);
  FI^.DError := 1;
  FI^.Active := False;
  End;


Procedure FindObj.Done;
  Begin
  If FI^.Active Then
    FindClose(FI^.SR);
  Dispose(FI);
  End;


Procedure FindObj.FFirst(FN: String);
  Begin
  FN := FExpand(FN);
  FSplit(FN, FI^.Dir, FI^.Name, FI^.Ext);
  If FI^.Active Then
    FindClose(FI^.SR);
  FindFirst(FN, Archive + ReadOnly, FI^.SR);
  FI^.Active := True;
  FI^.DError := DosError;
  End;


Function  FindObj.GetName: String;
  Begin
  If Found Then
    Begin
    GetName := FI^.SR.Name
    End
  Else
    GetName := '';
  End;


Function FindObj.GetFullPath: String;
  Begin
  GetFullPath := FI^.Dir + GetName;
  End;


Function  FindObj.GetSize: LongInt;
  Begin
  If Found Then
    GetSize := FI^.SR.Size
  Else
    GetSize := 0;
  End;


Function  FindObj.GetDate: LongInt;
  Begin
  If Found Then
    GetDate := FI^.SR.Time
  Else
    GetDate := 0;
  End;


Procedure FindObj.FNext;
  Begin
  FindNext(FI^.SR);
  FI^.DError := DosError;
  If DosError <> 0 Then
    Begin
    FindClose(FI^.SR);
    FI^.Active := False;
    End;
  End;


Function FindObj.Found: Boolean;
  Begin
  Found := (FI^.DError = 0);
  End;


Function shAssign(Var F: File; FName: String): Boolean;
  Begin
  Assign(F, ResolveCase(FName));
  MKFileError := IoResult;
  shAssign := (MKFileError = 0);
  End;



Function shRead(Var F: File; Var Rec; ReadSize: Word; Var NumRead: Word): Boolean;
  Var
    Count: Word;
    Code: Word;

  Begin
  Count := Tries;
  Code := 5;
  While ((Count > 0) and (Code = 5)) Do
    Begin
    BlockRead(F,Rec,ReadSize,NumRead);
    Code := IoResult;
    Dec(Count);
    End;
  MKFileError := Code;
  ShRead := (Code = 0);
  End;


Function shWrite(Var F: File; Var Rec; ReadSize: Word): Boolean;
  Var
    Count: Word;
    Code: Word;

  Begin
  Count := Tries;
  Code := 5;
  While ((Count > 0) and (Code = 5)) Do
    Begin
    BlockWrite(F,Rec,ReadSize);
    Code := IoResult;
    Dec(Count);
    End;
  MKFileError := Code;
  shWrite := (Code = 0);
  End;


Procedure CleanDir(FileDir: String);
  Var
      SR: SearchRec;
    F: File;

  Begin
  FindFirst(FileDir + AllFilesMask, ReadOnly + Archive, SR);
  While DosError = 0 Do
    Begin
    If Not shAssign(F, FileDir + SR.Name) Then;
    Erase(F);
    If IoResult <> 0 Then;
    FindNext(SR);
    End;
  FindClose(SR);
  End;



Function GetCurrentPath: String;
  Var
    Path: String;

  Begin
  GetDir(0, Path);
  If (Length(Path) > 0) And Not IsPathSep(Path[Length(Path)]) Then
    Path := Path + DirectorySeparator;
  GetCurrentPath := Path;
  End;


Function shLock(Var F; LockStart,LockLength: LongInt): Word;
  Var
    Count: Word;
    Code: Word;

  Begin
  Count := Tries;
  Code := $21;
  While ((Count > 0) and (Code = $21)) Do
    Begin
    Code := LockFile(F,LockStart,LockLength);
    Dec(Count);
    If Code = $21 Then
      MKDelay(TryDelay);
    End;
  If Code = 1 Then
    Code := 0;
  shLock := Code;
  End;



Function shReset(Var F: File; RecSize: Word): Boolean;
  Var
    Count: Word;
    Code: Word;

  Begin
  Count := Tries;
  Code := 5;
  While ((Count > 0) and (Code = 5)) Do
    Begin
    Reset(F,RecSize);
    Code := IoResult;
    Dec(Count);
    End;
  MKFileError := Code;
  ShReset := (Code = 0);
  End;


Procedure FlushFile(Var F); {Force buffered data of the file out to disk}
  Begin
  MKFlushHandle(FileRec(F).Handle);
  End;


Function LockFile(Var F; LockStart: LongInt; LockLength: LongInt): Word;
  {0 = success, $21 = lock violation, 6 = invalid handle, other = failure}
  Begin
  LockFile := MKLockRegion(FileRec(F).Handle, LockStart, LockLength, True);
  End;


Function UnLockFile(Var F; LockStart: LongInt; LockLength: LongInt): Word;
  Begin
  UnLockFile := MKLockRegion(FileRec(F).Handle, LockStart, LockLength, False);
  End;


Function LongLo(InNum: LongInt): Word;
  Begin
  LongLo := InNum and $FFFF;
  End;


Function LongHi(InNum: LongInt): Word;
  Begin
  LongHi := InNum Shr 16;
  End;


Function SizeFile(FName: String): LongInt;
  Var
    SR: SearchRec;

  Begin
  FindFirst(ResolveCase(FName), AnyFile, SR);
  If DosError = 0 Then
    SizeFile := SR.Size
  Else
    SizeFile := -1;
  FindClose(SR);
  End;


Function  DateFile(FName: String): LongInt;
  Var
    SR: SearchRec;

  Begin
  FindFirst(ResolveCase(FName), AnyFile, SR);
  If DosError = 0 Then
    DateFile := SR.Time
  Else
    DateFile := 0;
  FindClose(SR);
  End;


Function DirExist(FName: String): Boolean;
{ DirExist was contributed by Vadim Rumyantsev @ Fidonet 2:5030/301 }
  Var
    SR: SearchRec;

  Begin
  if (length (FName) > 1) and IsPathSep(FName [length (FName)]) then
    dec (FName [0]);
  If IoResult <> 0 Then;
  FindFirst(FName, ReadOnly + Hidden + Archive + Directory, SR);
  DirExist := (DosError = 0);
  FindClose(SR);
  If IoResult <> 0 Then;
  End;


Function RawExists(FName: String): Boolean;
  Var
    SR: SearchRec;

  Begin
  If IoResult <> 0 Then;
  FindFirst(FName, ReadOnly + Hidden + Archive, SR);
  RawExists := (DosError = 0);
  FindClose(SR);
  If IoResult <> 0 Then;
  End;


Function ResolveCase(FName: String): String;
  Var
    D: DirStr;
    N: NameStr;
    E: ExtStr;
    i: Word;
    Alt: String;

  Begin
  ResolveCase := FName;
  If (Length(FName) = 0) Or RawExists(FName) Then
    Exit;
  FSplit(FName, D, N, E);
  Alt := N + E;
  For i := 1 To Length(Alt) Do
    Alt[i] := LoCase(Alt[i]);
  If RawExists(D + Alt) Then
    Begin
    ResolveCase := D + Alt;
    Exit;
    End;
  For i := 1 To Length(Alt) Do
    Alt[i] := UpCase(Alt[i]);
  If RawExists(D + Alt) Then
    ResolveCase := D + Alt;
  End;


Function FileExist(FName: String): Boolean;
  Begin
  FileExist := RawExists(ResolveCase(FName));
  End;


Function FindPath(FileName: String):String;
  Begin
  FindPath := FileName;
  If FileExist(FileName) Then
    FindPath := FExpand(FileName)
  Else
    FindPath := FExpand(FSearch(FileName,GetEnv('PATH')));
  End;


Procedure TFile.BufferRead;
  Begin
  TF^.BufferStart := FilePos(TF^.BufferFile);
  if Not shRead (TF^.BufferFile,TF^.MsgBuffer^ , TF^.BufferSize, TF^.BufferChars) Then
    TF^.BufferChars := 0;
  TF^.BufferPtr := 1;
  End;


Function TFile.GetChar: Char;
  Begin
  If TF^.BufferPtr > TF^.BufferChars Then
    BufferRead;
  If TF^.BufferChars > 0 Then
    GetChar := TF^.MsgBuffer^[TF^.BufferPtr]
  Else
    GetChar := #0;
  Inc(TF^.BufferPtr);
  If TF^.BufferPtr > TF^.BufferChars Then
    BufferRead;
  End;


Function TFile.GetString: String;

  Var
    TempStr: String;
    GDone: Boolean;
    Ch: Char;

  Begin
    TempStr := '';
    GDone := False;
    TF^.StringFound := False;
    While Not GDone Do
      Begin
      Ch := GetChar;
      Case Ch Of
        #0:  If TF^.BufferChars = 0 Then
               GDone := True
             Else
               Begin
               Inc(TempStr[0]);
               TempStr[Ord(TempStr[0])] := Ch;
               TF^.StringFound := True;
               If Length(TempStr) = 255 Then
                 GDone := True;
               End;
        #10: If Not TF^.PrevCR Then   {a lone LF ends the line too}
               Begin
               GDone := True;
               TF^.StringFound := True;
               End;
        #26:;
        #13: Begin
             GDone := True;
             TF^.StringFound := True;
             End;
        Else
          Begin
            Inc(TempStr[0]);
            TempStr[Ord(TempStr[0])] := Ch;
            TF^.StringFound := True;
            If Length(TempStr) = 255 Then
              GDone := True;
          End;
        End;
      TF^.PrevCR := (Ch = #13);
      End;
    GetString := TempStr;
  End;


Function TFile.GetUString: String;

  Var
    TempStr: String;
    GDone: Boolean;
    Ch: Char;

  Begin
  TempStr := '';
  GDone := False;
  TF^.StringFound := False;
  While Not GDone Do
    Begin
    Ch := GetChar;
    Case Ch Of
      #0:  If TF^.BufferChars = 0 Then
             GDone := True
           Else
             Begin
             Inc(TempStr[0]);
             TempStr[Ord(TempStr[0])] := Ch;
             TF^.StringFound := True;
             If Length(TempStr) = 255 Then
               GDone := True;
             End;
      #13:;
      #26:;
      #10: Begin
           GDone := True;
           TF^.StringFound := True;
           End;
      Else
        Begin
        Inc(TempStr[0]);
        TempStr[Ord(TempStr[0])] := Ch;
        TF^.StringFound := True;
        If Length(TempStr) = 255 Then
          GDone := True;
        End;
      End;
    End;
  GetUString := TempStr;
  End;


Function TFile.OpenTextFile(FilePath: String): Boolean;
  Begin
  If Not shAssign(TF^.BufferFile, FilePath) Then;
  FileMode := fmReadOnly + fmDenyNone;
  If Not shReset(TF^.BufferFile,1) Then
    OpenTextFile := False
  Else
    Begin
    BufferRead;
    If TF^.BufferChars > 0 Then
      TF^.StringFound := True
    Else
      TF^.StringFound := False;
    OpenTextFile := True;
    End;
  End;


Function TFile.SeekTextFile(SeekPos: LongInt): Boolean;
  Begin
  TF^.Error := 0;
  TF^.PrevCR := False;
  If ((SeekPos < TF^.BufferStart) Or (SeekPos > TF^.BufferStart + TF^.BufferChars)) Then
    Begin
    Seek(TF^.BufferFile, SeekPos);
    TF^.Error := IoResult;
    BufferRead;
    End
  Else
    Begin
    TF^.BufferPtr := SeekPos + 1 - TF^.BufferStart;
    End;
  SeekTextFile := (TF^.Error = 0);
  End;


Function TFile.GetTextPos: LongInt;       {Get text file position}
  Begin
  GetTextPos := TF^.BufferStart + TF^.BufferPtr - 1;
  End;


Function TFile.Restart: Boolean;
  Begin
  Restart := SeekTextFile(0);
  End;


Function TFile.CloseTextFile: Boolean;
  Begin
  Close(TF^.BufferFile);
  CloseTextFile := (IoResult = 0);
  End;


Procedure TFile.SetBufferSize(BSize: Word);
  Begin
  FreeMem(TF^.MsgBuffer, TF^.BufferSize);
  TF^.BufferSize := BSize;
  GetMem(TF^.MsgBuffer, TF^.BufferSize);
  TF^.BufferChars := 0;
  TF^.BufferStart := 0;
  If SeekTextFile(GetTextPos) Then;
  End;


Procedure TFile.Init;
  Begin
  New(TF);
  TF^.BufferSize := 2048;
  TF^.PrevCR := False;
  GetMem(TF^.MsgBuffer, TF^.BufferSize);
  End;


Procedure TFile.Done;
  Begin
  Close(TF^.BufferFile);
  If IoResult <> 0 Then;
  FreeMem(TF^.MsgBuffer, TF^.BufferSize);
  Dispose(TF);
  End;


Function TFile.StringFound: Boolean;
  Begin
  StringFound := TF^.StringFound;
  End;


Function  shOpenFile(Var F: File; PathName: String): Boolean;
  Begin
  Assign(f, ResolveCase(pathname));
  FileMode := fmReadWrite + fmDenyNone;
  shOpenFile := shReset(f,1);
  End;


Function  shMakeFile(Var F: File; PathName: String): Boolean;
  Begin
  Assign(f,pathname);
  ReWrite(f,1);
  shMakeFile := (IOresult = 0);
  END;


Procedure shCloseFile(Var F: File);
  Begin
  Close(F);
  If (IOresult <> 0) Then;
  End;


Function  shSeekFile(Var F: File; FPos: LongInt): Boolean;
  Begin
  Seek(F,FPos);
  shSeekFile := (IOresult = 0);
  End;


Function  shFindFile(Pathname: String; Var Name: String; Var Size, Time: LongInt): Boolean;
  Var
      SR: SearchRec;

  Begin
  FindFirst(PathName, Archive, SR);
  If (DosError = 0) Then
    Begin
    shFindFile := True;
    Name := Sr.Name;
    Size := Sr.Size;
    Time := Sr.Time;
    End
  Else
    Begin
    shFindFile := False;
    End;
  FindClose(SR);
  End;


Procedure shSetFTime(Var F: File; Time: LongInt);
  Begin
  SetFTime(F, Time);
  If (IOresult <> 0) Then;
  End;



Function IsDevice(FilePath: String): Boolean;
  Var
    F: File;

  Begin
  Assign(F, ResolveCase(FilePath));
  Reset(F);
  If IoResult <> 0 Then
    IsDevice := False
  Else
    Begin
    IsDevice := MKHandleIsDevice(FileRec(F).Handle);
    Close(F);
    End;
  If IoResult <> 0 Then;
  End;


Function LoadFile(FN: String; Var Rec; FS: Word): Word;
  Begin
  LoadFile := LoadFilePos(FN, Rec, FS, 0);
  End;


Function LoadFilePos(FN: String; Var Rec; FS: Word; FPos: LongInt): Word;
  Var
    F: File;
    Error: Word;
    NumRead: Word;

  Begin
  Error := 0;
  If Not FileExist(FN) Then
    Error := 8888;
  If Error = 0 Then
    Begin
    If Not shAssign(F, FN) Then
      Error := MKFileError;
    End;
  FileMode := fmReadOnly + fmDenyNone;
  If Not shReset(F,1) Then
    Error := MKFileError;
  If Error = 0 Then
    Begin
    Seek(F, FPos);
    Error := IoResult;
    End;
  If Error = 0 Then
    If Not shRead(F, Rec, FS, NumRead) Then
      Error := MKFileError;
  If Error = 0 Then
    Begin
    Close(F);
    Error := IoResult;
    End;
  LoadFilePos := Error;
  End;


Function SaveFile(FN: String; Var Rec; FS: Word): Word;
   Begin
   SaveFile := SaveFilePos(FN, Rec, FS, 0);
   End;



Function SaveFilePos(FN: String; Var Rec; FS: Word; FPos: LongInt): Word;
  Var
    F: File;
    Error: Word;

  Begin
  Error := 0;
  If Not shAssign(F, FN) Then
    Error := MKFileError;
  FileMode := fmReadWrite + fmDenyNone;
  If FileExist(FN) Then
    Begin
    If Not shReset(F,1) Then
      Error := MKFileError;
    End
  Else
    Begin
    ReWrite(F,1);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    Seek(F, FPos);
    Error := IoResult;
    End;
  If Error = 0 Then
    If FS > 0 Then
      Begin
      If Not shWrite(F, Rec, FS) Then
        Error := MKFileError;
      End;
  If Error = 0 Then
    Begin
    Close(F);
    Error := IoResult;
    End;
  SaveFilePos := Error;
  End;


Function ExtendFile(FN: String; ToSize: LongInt): Word;
{Pads file with nulls to specified size}
  Type
    FillType = Array[1..8000] of Byte;

  Var
    F: File;
    Error: Word;
    FillRec: ^FillType;

  Begin
  Error := 0;
  New(FillRec);
  If FillRec = Nil Then
    Error := 10;
  If Error = 0 Then
    Begin
    FillChar(FillRec^, SizeOf(FillRec^), 0);
    If Not shAssign(F, FN) Then
    Error := MKFileError;
    FileMode := fmReadWrite + fmDenyNone;
    If FileExist(FN) Then
      Begin
      If Not shReset(F,1) Then
        Error := MKFileError;
      End
    Else
      Begin
      ReWrite(F,1);
      Error := IoResult;
      End;
    End;
  If Error = 0 Then
    Begin
    Seek(F, FileSize(F));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    While ((FileSize(F) < (ToSize - SizeOf(FillRec^))) and (Error = 0)) Do
      Begin
      If Not shWrite(F, FillRec^, SizeOf(FillRec^)) Then
        Error := MKFileError;
      End;
    End;
  If ((Error = 0) and (FileSize(F) < ToSize)) Then
    Begin
    If Not shWrite(F, FillRec^, ToSize - FileSize(F)) Then
      Error := MKFileError;
    End;
  If Error = 0 Then
    Begin
    Close(F);
    Error := IoResult;
    End;
  Dispose(FillRec);
  ExtendFile := Error;
  End;



{Build a candidate temp name in directory FN: FN + separator + 8 hex digits.
 FN may be empty (current directory).  The sequence is seeded from the process
 id and clock so concurrent processes rarely collide; callers still check.}
Const
  TempSeed: LongInt = 0;

Function NextTempName(FN: String): String;
  Var
    H, M, S, S100: Word;
    Base: String;

  Begin
  If TempSeed = 0 Then
    Begin
    GetTime(H, M, S, S100);
    TempSeed := (MKProcessID Shl 12) Xor (LongInt(H) * 3600000 + LongInt(M) * 60000 +
      LongInt(S) * 1000 + LongInt(S100) * 10) Xor $5A5A5A5A;
    End;
  TempSeed := TempSeed * 1103515245 + 12345;
  Base := FN;
  If (Length(Base) > 0) And Not IsPathSep(Base[Length(Base)]) Then
    Base := Base + DirectorySeparator;
  NextTempName := Base + System.HexStr((TempSeed Shr 4) And $FFFFFFF, 7) + System.HexStr(TempSeed And $F, 1);
  End;


Function  CreateTempDir(FN: String): String;
  {Creates a new, uniquely named directory under FN and returns its path
   (no trailing separator).  Returns '' on failure.}
  Var
    Attempt: Word;
    TmpStr: String;

  Begin
  CreateTempDir := '';
  If IoResult <> 0 Then;
  For Attempt := 1 To 100 Do
    Begin
    TmpStr := NextTempName(FN);
    If Not (FileExist(TmpStr) Or DirExist(TmpStr)) Then
      Begin
      MkDir(TmpStr);
      If IoResult = 0 Then
        Begin
        CreateTempDir := TmpStr;
        Exit;
        End;
      End;
    End;
  End;


Function  GetTempName(FN: String): String;
  {Returns an unused file name under FN.  The file is created and removed
   again to prove the name is usable, like the DOS temp-name call did.}
  Var
    Attempt: Word;
    TmpStr: String;
    F: File;

  Begin
  GetTempName := '';
  If IoResult <> 0 Then;
  For Attempt := 1 To 100 Do
    Begin
    TmpStr := NextTempName(FN);
    If Not (FileExist(TmpStr) Or DirExist(TmpStr)) Then
      Begin
      Assign(F, TmpStr);
      ReWrite(F, 1);
      If IoResult = 0 Then
        Begin
        Close(F);
        If IoResult <> 0 Then;
        Erase(F);
        If IoResult = 0 Then
          Begin
          GetTempName := TmpStr;
          Exit;
          End;
        End;
      End;
    End;
  End;


Function  GetTextPos(Var F: Text): LongInt;
  {OS file position plus the characters pending in the text buffer}
  Var
    Tmp: Int64;

  Begin
  Tmp := MKHandlePos(TextRec(F).Handle);
  If Tmp >= 0 Then
    Inc(Tmp, TextRec(F).BufPos);
  GetTextPos := LongInt(Tmp);
  End;


Function FindOnPath(FN: String; Var OutName: String): Boolean;
  Var
    TmpStr: String;

  Begin
  If FileExist(FN) Then
    Begin
    OutName := FExpand(FN);
    FindOnPath := True;
    End
  Else
    Begin
    TmpStr := FSearch(FN, GetEnv('PATH'));
    If FileExist(TmpStr) Then
      Begin
      OutName := TmpStr;
      FindOnPath := True;
      End
    Else
      Begin
      OutName := FN;
      FindOnPath := False;
      End;
    End;
  End;


Function  CopyFile(FN1: String; FN2: String): Boolean;
  Type
    TmpBufType = Array[1..8192] of Byte;

  Var
    F1: File;
    F2: File;
    NumRead: Word;
    Buf: ^TmpBufType;
    Error: Word;

  Begin
  New(Buf);
  Error := 0;
  Assign(F1, FN1);
  FileMode := fmReadOnly + fmDenyNone;
  Reset(F1, 1);
  Error := IoResult;
  If Error = 0 Then
    Begin
    Assign(F2, FN2);
    FileMode := fmReadWrite + fmDenyNone;
    ReWrite(F2, 1);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    BlockRead(F1, Buf^, SizeOf(Buf^), NumRead);
    Error := IoResult;
    While ((NumRead <> 0) and (Error = 0)) Do
      Begin
      BlockWrite(F2, Buf^, NumRead);
      Error := IoResult;
      If Error = 0 Then
        Begin
        BlockRead(F1, Buf^, SizeOf(Buf^), NumRead);
        Error := IoResult;
        End;
      End;
    End;
  If Error = 0 Then
    Begin
    Close(F1);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    Close(F2);
    Error := IoResult;
    End;
  Dispose(Buf);
  CopyFile := (Error = 0);
  End;


Function  EraseFile(FN: String): Boolean;
  Var
    F: File;

  Begin
  Assign(F, FN);
  Erase(F);
  EraseFile := (IoResult = 0);
  End;


Function  MakePath(FP: String): Boolean;
  Var
    i: Word;

  Begin
  If (Length(FP) > 0) And Not IsPathSep(FP[Length(FP)]) Then
    FP := FP + DirectorySeparator;
  If Not DirExist(FP) Then
    Begin
    i := 2;
    While (i <= Length(FP)) Do
      Begin
      If IsPathSep(FP[i]) Then
        Begin
        If FP[i-1] <> DriveSeparator Then
          Begin
          MkDir(Copy(FP, 1, i - 1));
          If IoResult <> 0 Then;
          End;
        End;
      Inc(i);
      End;
    End;
  MakePath := DirExist(FP);
  End;


End.
