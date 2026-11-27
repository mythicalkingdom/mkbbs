{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKFileList;   {The pieces of a file area listing (files.bbs) that uploads and scripts share}

{$MODE OBJFPC}
{$H+}

{
     A line of files.bbs is the file name, blanks up to column 14 and the description (45 columns at most for the first line); more lines of the description follow with 13 blanks in front.
}

Interface

Uses Classes;

Function UploadName(Const S: String): String;
  {the name as the BBS keeps it: only A-Z a-z 0-9 . _ - + (other characters become _), at most 64 characters, no leading dot; '' when nothing is left}

{ PCBoard DIR files (the layout of PCBFiler's documentation).  A primary line: the name, the size flush right in column 20 (no commas), the date from column
  24 as MM-DD-YY (DD-MMM-YY is read too, with a time after it), the description from column 34.  A secondary line starts with a space and has a vertical bar (the
  bar is not shown); a line that starts with % names a file to show; the rest is text (headers, footers).  The reading is by words, not by columns, so a
  file that is a little off is still taken. }
Function PcbPrimary(Const S: String; Out Name: ShortString; Out Size, DosTime: LongInt; Out Desc: ShortString): Boolean;
  {True: S is a primary line of a DIR file (DosTime is the packed DOS date and time)}

Function PcbSecondary(Const S: String; Out Text: ShortString): Boolean;
  {True: S is a secondary line; Text is it without the bar}

Function PcbStripCodes(Const S: String): String;
  {the @X colour codes (@Xhh) of PCBoard out of a text}

Function ListLines(Const Name: String; Desc: TStrings): String;
  {the text to append to files.bbs for a file and its description lines}

Function InArea(Const Dir, Name: String): Boolean;
  {a file of this name (whatever the case) is in Dir}

Procedure AppendList(Const ListFile, Text: String);

Implementation

Uses SysUtils;


Function PackDos(Y, Mo, D: Integer): LongInt;
  Begin
  If Y < 80 Then
    Y := Y + 2000
  Else If Y < 100 Then
    Y := Y + 1900;
  If (Y < 1980) Or (Y > 2107) Or (Mo < 1) Or (Mo > 12) Or (D < 1) Or (D > 31) Then
    Exit(-1);
  Result := ((Y - 1980) Shl 25) Or (Mo Shl 21) Or (D Shl 16);
  End;


Function PcbDate(Const T: String): LongInt;
  {MM-DD-YY, MM/DD/YY or DD-MMM-YY: the packed DOS date (-1: not a date)}
  Const
    Months = 'JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC';

  Var
    P1, P2: Integer;
    A, B, C: String;
    M: Integer;

  Begin
  Result := -1;
  If Length(T) < 8 Then
    Exit;
  P1 := Pos('-', T);
  If P1 = 0 Then
    P1 := Pos('/', T);
  If P1 = 0 Then
    Exit;
  P2 := P1 + Pos(T[P1], Copy(T, P1 + 1, 20));
  If P2 = P1 Then
    Exit;
  A := Copy(T, 1, P1 - 1);
  B := Copy(T, P1 + 1, P2 - P1 - 1);
  C := Copy(T, P2 + 1, 4);
  If (StrToIntDef(A, -1) >= 0) And (StrToIntDef(B, -1) >= 0) And (StrToIntDef(C, -1) >= 0) Then
    Result := PackDos(StrToInt(C), StrToInt(A), StrToInt(B))
  Else If (StrToIntDef(A, -1) >= 0) And (StrToIntDef(C, -1) >= 0) And (Length(B) = 3) Then
    Begin
    M := (Pos(UpperCase(B), Months) + 2) Div 3;
    If (M >= 1) And (Pos(UpperCase(B), Months) Mod 3 = 1) Then
      Result := PackDos(StrToInt(C), M, StrToInt(A));
    End;
  End;


Function NextWord(Var S: String): String;
  Var
    p: Integer;

  Begin
  S := TrimLeft(S);
  p := 1;
  While (p <= Length(S)) And (S[p] > ' ') Do
    Inc(p);
  Result := Copy(S, 1, p - 1);
  Delete(S, 1, p - 1);
  End;


Function PcbPrimary(Const S: String; Out Name: ShortString; Out Size, DosTime: LongInt; Out Desc: ShortString): Boolean;
  Var
    R, W1, W2, W3: String;
    i: Integer;
    Digits: Boolean;

  Begin
  Result := False;
  Name := '';
  Size := -1;
  DosTime := -1;
  Desc := '';
  If (S = '') Or (S[1] <= ' ') Or (S[1] = '%') Then
    Exit;
  R := S;
  Name := NextWord(R);
  W1 := NextWord(R);
  W2 := NextWord(R);
  If W1 = '' Then
    Exit;
  Digits := True;
  For i := 1 To Length(W1) Do
    If Not (W1[i] In ['0'..'9']) Then
      Digits := False;
  If (Not Digits) Or (StrToInt64Def(W1, -1) < 0) Or (StrToInt64Def(W1, -1) > 2147483647) Then
    Exit;
  DosTime := PcbDate(W2);
  If DosTime < 0 Then
    Exit;
  Size := StrToInt(W1);
  { a time after the date (00:00:00) is not part of the description }
  W3 := NextWord(R);
  If (Length(W3) >= 5) And (W3[3] = ':') And (StrToIntDef(Copy(W3, 1, 2), -1) >= 0) And (StrToIntDef(Copy(W3, 4, 2), -1) >= 0) Then
    Begin
    DosTime := DosTime Or (StrToInt(Copy(W3, 1, 2)) Shl 11) Or (StrToInt(Copy(W3, 4, 2)) Shl 5);
    Desc := Trim(R);
    End
  Else
    Desc := Trim(W3 + R);
  Result := True;
  End;


Function PcbSecondary(Const S: String; Out Text: ShortString): Boolean;
  Var
    p: Integer;

  Begin
  Text := '';
  Result := False;
  If (S = '') Or (S[1] <> ' ') Then
    Exit;
  p := Pos('|', S);
  If p = 0 Then
    Exit;
  Text := Copy(S, 1, p - 1) + ' ' + Copy(S, p + 1, 500);
  Result := True;
  End;


Function PcbStripCodes(Const S: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  i := 1;
  While i <= Length(S) Do
    If (S[i] = '@') And (i + 3 <= Length(S)) And (UpCase(S[i + 1]) = 'X') And (S[i + 2] In ['0'..'9', 'A'..'F', 'a'..'f']) And (S[i + 3] In ['0'..'9', 'A'..'F', 'a'..'f']) Then
      Inc(i, 4)
    Else
      Begin
      Result := Result + S[i];
      Inc(i);
      End;
  End;


Function UploadName(Const S: String): String;
  Var
    i: Integer;
    R: String;

  Begin
  R := '';
  For i := 1 To Length(S) Do
    If S[i] In ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-', '+'] Then
      R := R + S[i]
    Else
      R := R + '_';
  While (R <> '') And (R[1] = '.') Do
    Delete(R, 1, 1);
  If Length(R) > 64 Then
    R := Copy(R, 1, 64);
  UploadName := R;
  End;


Function ListLines(Const Name: String; Desc: TStrings): String;
  Var
    i: Integer;
    First, Pad: String;

  Begin
  If Length(Name) < 13 Then
    Pad := StringOfChar(' ', 13 - Length(Name))
  Else
    Pad := ' ';
  If Desc.Count > 0 Then
    First := Copy(Desc[0], 1, 45)
  Else
    First := '(no description)';
  ListLines := Name + Pad + First + #10;
  For i := 1 To Desc.Count - 1 Do
    ListLines := ListLines + StringOfChar(' ', 13) + Copy(Desc[i], 1, 60) + #10;
  End;


Function InArea(Const Dir, Name: String): Boolean;
  {a file of this name (whatever the case) is in Dir}
  Var
    SR: TSearchRec;

  Begin
  InArea := False;
  If FindFirst(Dir + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If SameText(SR.Name, Name) Then
        InArea := True;
    Until (FindNext(SR) <> 0) Or (InArea);
    FindClose(SR);
    End;
  End;


Procedure AppendList(Const ListFile, Text: String);
  Var
    F: TFileStream;

  Begin
  If FileExists(ListFile) Then
    F := TFileStream.Create(ListFile, fmOpenReadWrite Or fmShareDenyNone)
  Else
    F := TFileStream.Create(ListFile, fmCreate);
  Try
    F.Seek(0, soEnd);
    F.WriteBuffer(Text[1], Length(Text));
  Finally
    F.Free;
  End;
  End;


End.
