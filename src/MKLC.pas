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

{
     mklc Source[.txt]

     Compiles a language text file into the *.LC file the BBS programs load
     (MKStr.StrObj).  Every line of the text is "number text"; lines that begin
     with ; are comments, blank lines are ignored.  The result is named like the
     source with the extension LC (lower case when the source's extension is).

     File layout:  word HighLine, then a word per line number 1..HighLine (the
     position of its text, 1 based, 0 = none), then the texts: a length byte,
     the characters and a zero.
}

Uses Dos, MKFile, MKString;


Const
  MaxSize = 62000;

Var
  InputName: String;
  OutputName: String;
  TF: TFile;
  OutFile: File;
  HighLine: Word;
  Work: Array[1..MaxSize] Of Char;
  NumLines: Word;
  TmpStr: String;
  LineNo: LongInt;
  Code: Integer;
  CurrPos: Word;
  i: Word;
  WordPtr: ^Word;
  Errors: Word;


Procedure Fail(Msg: String; Level: Byte);
  Begin
  WriteLn;
  WriteLn('Error: ' + Msg);
  WriteLn;
  Halt(Level);
  End;


Function LineNumber(Var S: String): LongInt;
  {The number at the start of the line (after leading blanks); 0 = none or wrong}
  Var
    N: LongInt;

  Begin
  Val(ExtractWord(S, 1), N, Code);
  If (Code <> 0) Or (N < 1) Or (N > (MaxSize - 3) Div 2) Then
    N := 0;
  LineNumber := N;
  End;


Procedure BadLine;
  Begin
  Inc(Errors);
  WriteLn;
  WriteLn('Error: Invalid line number in line ', NumLines);
  WriteLn(TmpStr);
  WriteLn;
  End;


Procedure Pass1;
  Begin
  NumLines := 0;
  HighLine := 0;
  Errors := 0;
  TF.Init;
  If Not TF.OpenTextFile(InputName) Then
    Fail('Error reading input file', 11);
  TmpStr := TF.GetString;
  While TF.StringFound Do
    Begin
    Inc(NumLines);
    Write(#13, NumLines);
    TmpStr := StripLead(TmpStr, ' ');
    If (Length(TmpStr) > 0) And (TmpStr[1] <> ';') Then
      Begin
      LineNo := LineNumber(TmpStr);
      If LineNo = 0 Then
        BadLine
      Else If LineNo > HighLine Then
        HighLine := LineNo;
      End;
    TmpStr := TF.GetString;
    End;
  If Not TF.CloseTextFile Then
    Fail('Closing input file', 11);
  TF.Done;
  WriteLn(#13, NumLines, ' Lines - Pass 1 complete');
  End;


Procedure Pass2;
  Begin
  NumLines := 0;
  CurrPos := (HighLine * 2) + 3;
  If CurrPos > MaxSize Then
    Fail('Too many line numbers', 12);
  FillChar(Work, CurrPos, 0);
  WordPtr := @Work;
  WordPtr^ := HighLine;
  TF.Init;
  If Not TF.OpenTextFile(InputName) Then
    Fail('Error reading input file', 11);
  TmpStr := TF.GetString;
  While TF.StringFound Do
    Begin
    Inc(NumLines);
    Write(#13, NumLines);
    TmpStr := StripLead(TmpStr, ' ');
    If (Length(TmpStr) > 0) And (TmpStr[1] <> ';') Then
      Begin
      LineNo := LineNumber(TmpStr);
      If LineNo <> 0 Then
        Begin
        If Pos(' ', TmpStr) > 0 Then
          TmpStr := Copy(TmpStr, Pos(' ', TmpStr) + 1, 255)
        Else
          TmpStr := '';
        WordPtr := @Work[((LineNo * 2) + 1)];
        WordPtr^ := CurrPos;
        i := 0;
        While i <= Length(TmpStr) Do         {the length byte first, then the text}
          Begin
          Work[CurrPos] := TmpStr[i];
          Inc(i);
          Inc(CurrPos);
          If CurrPos >= MaxSize Then
            Fail('Maximum text size exceeded', 12);
          End;
        Work[CurrPos] := #0;
        Inc(CurrPos);
        End;
      End;
    TmpStr := TF.GetString;
    End;
  If Not TF.CloseTextFile Then
    Fail('Closing input file', 11);
  TF.Done;
  Work[CurrPos] := #0;
  WriteLn(#13, NumLines, ' Lines - Pass 2 complete');
  End;


Var
  D: DirStr;
  N: NameStr;
  E: ExtStr;

Begin
If ParamCount <> 1 Then
  Fail('Proper syntax is MKLC Source.Txt', 10);
InputName := ParamStr(1);
FSplit(InputName, D, N, E);
If E = '' Then
  InputName := InputName + '.txt';
If Not FileExist(InputName) Then
  Fail('Input File: ' + InputName + ' Does not exist', 10);
FSplit(InputName, D, N, E);
If E = Upper(E) Then
  OutputName := D + N + '.LC'
Else
  OutputName := D + N + '.lc';
If Upper(InputName) = Upper(OutputName) Then
  Fail('Input file and output name cannot be the same', 10);
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
ReWrite(OutFile, 1);
If IoResult <> 0 Then
  Fail('Error creating ' + OutputName, 13);
BlockWrite(OutFile, Work, CurrPos);
If IoResult <> 0 Then
  Fail('Error writing ' + OutputName, 13);
Close(OutFile);
If IoResult <> 0 Then
  Fail('Error closing ' + OutputName, 13);
If Errors > 0 Then
  Begin
  WriteLn(Errors, ' line(s) with a wrong line number were left out');
  Halt(14);
  End;
End.
