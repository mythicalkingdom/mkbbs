Unit MKStr;
{$I MKB.Def}

Interface

{
     MKStr - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Const
  MaxSize = 32000;


Type WorkArray = Array[1..MaxSize] of Char;
Type WordPtr = ^Word;
Type StrPtr = ^String;

Type StrInfoType = Record
  Loaded: Boolean;
  HighNum: Word;
  Error: Word;
  SSize: Word;
  End;

Type StrObj = Object
  Work: ^WorkArray;
  StrInfo: ^StrInfoType;
  Procedure Init;                           {Initialize}
  Procedure Load(FN: String);               {Load file name}
  Procedure Done;                           {Done}
  Function GetString(Num: Word):String;     {Get string}
  Function GetChar(Num: Word): Char;      {Get character}
  End;

Type StrObjPtr = ^StrObj;

Implementation


Uses MKFile, MKString,
  {$IFDEF WINDOWS}
  WinDos;
  {$ELSE}
  Dos;
  {$ENDIF}


Procedure StrObj.Init;                      {Initialize}
  Begin
  New(StrInfo);
  StrInfo^.Loaded := False;
  StrInfo^.Error := 0;
  End;


Procedure StrObj.Load(FN: String);          {Load file name}
  Var
    StrF: File;
    NumRead: Word;

  Begin
  StrInfo^.Error := 0;
  If StrInfo^.Loaded Then
    Begin
    FreeMem(Work,StrInfo^.SSize);
    StrInfo^.Loaded := False;
    End;
  If Not FileExist(FN) Then
    StrInfo^.Error := 1000;
  If StrInfo^.Error = 0 Then
    Begin
    Assign(StrF, FN);
    FileMode := fmReadOnly + fmDenyNone;
    If Not shReset(StrF, 1) Then
      StrInfo^.Error := 1010;
    End;
  If StrInfo^.Error = 0 Then
    Begin
    StrInfo^.SSize := SizeFile(FN);
    GetMem(Work, StrInfo^.SSize);
    If Not shRead(StrF, Work^, StrInfo^.SSize, NumRead) Then
      Begin
      FreeMem(Work, StrInfo^.SSize);
      StrInfo^.Loaded := False;
      StrInfo^.Error := 1020;
      End;
    Close(StrF);
    If IoResult <> 0 Then;
    End;
  StrInfo^.HighNum := WordPtr(Work)^;
  End;


Procedure StrObj.Done;                      {Done}
  Begin
  If StrInfo^.Loaded Then
    Begin
    FreeMem(Work,StrInfo^.SSize);
    StrInfo^.Loaded := False;
    End;
  Dispose(StrInfo);
  End;


Function StrObj.GetString(Num: Word):String; {Get string}
  Var
    StrStrt: Word;

  Begin
  If ((Num <= StrInfo^.HighNum) and (Num > 0)) Then
    Begin
    StrStrt := WordPtr(@Work^[((Num * 2) + 1)])^;
    If ((StrStrt > 0) and (StrStrt <= StrInfo^.SSize)) Then
      Begin
      GetString := StrPtr(@Work^[StrStrt])^;
      End
    Else
      GetString := '';
    End
  Else
    GetString := '';
  End;


Function StrObj.GetChar(Num: Word): Char;  {Get character}
  Var
    StrStrt: Word;

  Begin
  If Num <= StrInfo^.HighNum Then
    Begin
    StrStrt := WordPtr(@Work^[((Num * 2) + 1)])^;
    If ((StrStrt >= 0) and (StrStrt <= StrInfo^.SSize)) Then
      Begin
      GetChar := StrPtr(@Work^[StrStrt])^[1];
      End
    Else
      GetChar := #0;
    End
  Else
    GetChar := #0;
  End;


End.
