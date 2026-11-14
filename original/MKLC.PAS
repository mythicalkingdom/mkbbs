Program MKLC;                   {Language compiler}

{$I MKB.Def}

{
     MKLC - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}

Uses MKFile, MKString,
{$IFDEF WINDOWS}
  MKWCrt, WinDos;
{$ELSE}
  Dos,
  {$IFDEF OPRO}
  OPCrt;
  {$ELSE}
  Crt;
  {$ENDIF}
{$ENDIF}


Const
  MaxSize = 62000;

Var
  InputName: String[128];
  OutputName: String[128];
  TF: TFile;
  OutFile: File;
  HighLine: Word;
  Work: Array[1..MaxSize] of Char;
  NumLines: Word;
  TmpStr: String;
  LineNo: Word;
  Code: Word;
  CurrPos: Word;
  i: Word;
  WordPtr: ^Word;


Procedure Pass1;
  Begin
  NumLines := 0;
  HighLine := 0;
  TF.Init;
  If Not TF.OpenTextFile(InputName) Then
    Begin
    WriteLn;
    WriteLn('Error: Error reading input file');
    WriteLn;
    Halt(11);
    End;
  TmpStr := TF.GetString;
  While TF.StringFound Do
    Begin
    Inc(NumLines);
    Write(#13);
    Write(NumLines);
    TmpStr := StripLead(TmpStr,' ');
    If TmpStr[1] <> ';' Then
      Begin
      Val(ExtractWord(TmpStr,1),LineNo,Code);
      If ((Code <> 0) or (LineNo = 0)) Then
        Begin
        WriteLn;
        WriteLn('Error: Invalid line number');
        WriteLn(TmpStr);
        WriteLn;
        End;
      If LineNo > HighLine Then
        HighLine := LineNo;
      End;
    TmpStr := TF.GetString;
    End;
  If Not TF.CloseTextFile Then
    Begin
    WriteLn;
    WriteLn('Error: Closing input file');
    WriteLn;
    Halt(11);
    End;
  TF.Done;
  Write(#13);
  WriteLn(NumLines, ' Lines - Pass 1 complete');
  End;


Procedure Pass2;
  Begin
  NumLines := 0;
  CurrPos := (HighLine * 2) + 3;
  i := 1;
  While i <= CurrPos Do
    Begin
    Work[i] := #0;
    Inc(i);
    End;
  WordPtr := @Work;
  WordPtr^ := HighLine;
  TF.Init;
  If Not TF.OpenTextFile(InputName) Then
    Begin
    WriteLn;
    WriteLn('Error: Error reading input file');
    WriteLn;
    Halt(11);
    End;
  TmpStr := TF.GetString;
  While TF.StringFound Do
    Begin
    Inc(NumLines);
    Write(#13);
    Write(NumLines);
    TmpStr := StripLead(TmpStr,' ');
    If TmpStr[1] <> ';' Then
      Begin
      Val(ExtractWord(TmpStr,1),LineNo,Code);
      If ((Code <> 0) or (LineNo = 0)) Then
        Begin
        WriteLn;
        WriteLn('Error: Invalid line number');
        WriteLn(TmpStr);
        WriteLn;
        End;
      If Pos(' ', TmpStr) > 0 Then
        TmpStr := Copy(TmpStr,Pos(' ',TmpStr) + 1, 255)
      Else
        TmpStr := '';
      WordPtr := @Work[((LineNo * 2) + 1)];
      WordPtr^ := CurrPos;
      i := 0;
      While i <= Length(TmpStr) Do
        Begin
        Work[CurrPos] := TmpStr[i];
        Inc(i);
        Inc(CurrPos);
        If CurrPos > MaxSize Then
          Begin
          WriteLn;
          WriteLn('Error: Maximum text size exceeded');
          WriteLn;
          Halt(12);
          End;
        End;
      Work[CurrPos] := #0;
      Inc(CurrPos);
      End;
    TmpStr := TF.GetString;
    End;
  If Not TF.CloseTextFile Then
    Begin
    WriteLn;
    WriteLn('Error: Closing input file');
    WriteLn;
    Halt(11);
    End;
  TF.Done;
  Work[CurrPos] := #0;
  Write(#13);
  WriteLn(NumLines, ' Lines - Pass 2 complete');
  End;



Begin
If ParamCount <> 1 Then
  Begin
  WriteLn;
  WriteLn('Error: Proper syntax is MKLC Source.Txt');
  WriteLn;
  Halt(10);
  End;
InputName := ParamStr(1);
InputName := Upper(InputName);
If Pos('.',InputName) = 0 Then
  InputName := InputName + '.TXT';
If Not FileExist(InputName) Then
  Begin
  WriteLn;
  WriteLn('Error: Input File: ' + InputName + ' Does not exist');
  WriteLn;
  Halt(10);
  End;
OutputName := Copy(InputName,1,Pos('.',InputName)) + 'LC';
If InputName = OutPutName Then
  Begin
  WriteLn;
  WriteLn('Error: Input file and output name cannot be the same');
  WriteLn;
  Halt(10);
  End;
WriteLn;
WriteLn('MKLC - Language compiler - Copyright 1992 by Mark May');
WriteLn;
WriteLn;
WriteLn('Reading: ', InputName);
WriteLn('Writing: ', OutputName);
WriteLn;
Pass1;
Pass2;
Assign(OutFile, OutputName);
ReWrite(OutFile,1);
If IoResult <> 0 Then
  Begin
  WriteLn;
  WriteLn('Error: Error creating ', OutputName);
  WriteLn;
  Halt(13);
  End;
BlockWrite(OutFile, Work, CurrPos);
If IoResult <> 0 Then
  Begin
  WriteLn;
  WriteLn('Error: Error writing ', OutputName);
  WriteLn;
  Halt(13);
  End;
Close(OutFile);
If IoResult <> 0 Then
  Begin
  WriteLn;
  WriteLn('Error: Error closing ', OutputName);
  WriteLn;
  Halt(13);
  End;
End.
