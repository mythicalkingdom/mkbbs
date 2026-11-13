Unit MKWild;
{$I MKB.DEF}

Interface


Function DosMatch (MatchStr: String; InStr: String): Boolean;


Implementation

Uses
  {$IFDEF WINDOWS}
  WinDos,
  {$ELSE}
  Dos,
  {$ENDIF}
  MKString, MKFile;


{$IFDEF WINDOWS}
  Type
    DirStr = String[128];
    NameStr = String[12];
    ExtStr = String[4];
{$ENDIF}

Function dos_cmp (match_str, in_str : String) : Boolean;
  Var
    Match : Boolean;
    i: Byte;

  Begin
    i := 1;
    Match := True;
    While (i <= length (match_str)) And match Do
      Begin
      Case match_str [i] Of
        '?' :
        Else
          If match_str [i] <> in_str [i] Then
            Match := False;
        End;
      Inc(i);
    End;
    Dos_Cmp := Match;
  End;


Function DosMatch (MatchStr: String; InStr: String): Boolean;
  VAR
    i: BYTE;
    in_pathname,
    match_pathname: dirstr;
    in_filename,
    match_filename: namestr;
    in_ext,
    match_ext: extstr;

  Begin
  DosMatch := False;
  If (matchstr = '') OR (instr = '') Then
    Exit;
  FSplit (matchstr, match_pathname, match_filename,match_ext);
  FSplit (instr,in_pathname,in_filename,in_ext);
  If Pos('*',Match_FileName) > 0 Then
    Begin
    Match_FileName := Copy(Match_FileName,1, Pos('*', Match_FileName) - 1);
    Match_FileName := PadRight(Match_FileName,'?',8);
    End;
  If Pos('*',Match_Ext) > 0 Then
    Begin
    Match_Ext := Copy(Match_Ext,1,Pos('*', Match_Ext) - 1);
    Match_Ext := PadRight(Match_Ext,'?',4);
    End;
  If ((Length(Match_FileName) < Length(In_FileName)) Or
    (Length(Match_Ext) < Length(In_Ext)) Or (In_PathName <> Match_PathName)) Then
    DosMatch := False
  Else
    DosMatch := dos_cmp (match_filename,in_filename)
      And Dos_Cmp (match_ext,in_ext);
  End;

End.
