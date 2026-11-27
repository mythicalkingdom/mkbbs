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

Function ListLines(Const Name: String; Desc: TStrings): String;
  {the text to append to files.bbs for a file and its description lines}

Function InArea(Const Dir, Name: String): Boolean;
  {a file of this name (whatever the case) is in Dir}

Procedure AppendList(Const ListFile, Text: String);

Implementation

Uses SysUtils;


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
