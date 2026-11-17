Program MKCat;

{$I MKB.Def}

{
     mkcat [-u | -c] FileName

     Shows a text file (a BBS screen, a message, a log in the DOS character set) on the terminal.  The file is CP437;
     what is written depends on the terminal, with the same rules as the BBS uses for its callers (MKCp437):

        -u        UTF-8: the characters 128..255 are converted (box drawing, shading, accented letters)
        -c        CP437: the bytes as they are (for a BBS terminal such as SyncTERM)
        (none)    guarded by where the output goes: a terminal gets what its type (TERM) wants (TermWantsUtf8:
                  xterm, linux, screen ... UTF-8; ansi, syncterm, unknown ... CP437 as it is);
                  a file or a pipe gets UTF-8

     Only the codes 128..255 are converted; control characters and ESC sequences (ANSI colours) go through unchanged.
     Where the text is UTF-8 the colour guard of the BBS is on (MKSgr): the text starts with light gray on black, and a
     colour reset (ESC[0m) that sets no foreground or no background is followed by the missing DOS colour, so a themed
     terminal's own default colours (a reset background) do not show through the art.
     A ^Z (the DOS end of file mark) ends the text.  The file name is used exactly as given.
     Exit code: 0 done, 1 file could not be read, 3 wrong command line.
}

Uses
  TermIO, Dos, MKString, MKCp437, MKSgr;


Var
  FN: String;
  Mode: Byte;                          {0 = guarded, 1 = CP437, 2 = UTF-8}
  Utf8: Boolean;
  F: File;
  Buf: Array[1..4096] Of Byte;
  N: LongInt;
  Done: Boolean;
  i, k: Word;
  Opt: String;
  Out: String;
  Guard: SgrGuardObj;

Begin
Mode := 0;
FN := '';
For i := 1 To ParamCount Do
  Begin
  Opt := ParamStr(i);
  If (Opt = '-u') Or (Opt = '-U') Then
    Mode := 2
  Else If (Opt = '-c') Or (Opt = '-C') Then
    Mode := 1
  Else If (FN = '') And ((Length(Opt) = 0) Or (Opt[1] <> '-')) Then
    FN := Opt
  Else
    Begin
    FN := '';
    Break;
    End;
  End;
If FN = '' Then
  Begin
  WriteLn(StdErr, 'Usage: mkcat [-u | -c] FileName');
  WriteLn(StdErr, '  -u UTF-8   -c CP437 as it is   (none) by the terminal type (TERM) when the output is a terminal, else UTF-8');
  Halt(3);
  End;
Case Mode Of
  1: Utf8 := False;
  2: Utf8 := True;
  Else
    If IsATTY(1) <> 0 Then
      Utf8 := TermWantsUtf8(GetEnv('TERM'))
    Else
      Utf8 := True;
  End;
Guard.Init;
Assign(F, FN);
FileMode := 0;
Reset(F, 1);
If IOResult <> 0 Then
  Begin
  WriteLn(StdErr, 'mkcat: cannot read ' + FN);
  Halt(1);
  End;
Done := False;
While Not Done Do
  Begin
  BlockRead(F, Buf, SizeOf(Buf), N);
  If N <= 0 Then
    Break;
  k := 1;
  While k <= N Do
    Begin
    Out := '';
    While (k <= N) And (Length(Out) < 190) Do
      Begin
      If Buf[k] = 26 Then
        Begin
        Done := True;
        Break;
        End;
      If Utf8 Then
        Out := Out + Guard.First;               {once, before the first character}
      If Utf8 And (Buf[k] >= 128) Then
        Out := Out + Cp437ToUtf8(Buf[k])
      Else
        Begin
        Out := Out + Chr(Buf[k]);
        If Utf8 Then
          Out := Out + Guard.Feed(Chr(Buf[k]));   {a reset in the art keeps the DOS colours}
        End;
      Inc(k);
      End;
    Write(Out);
    If Done Then
      Break;
    End;
  End;
Close(F);
End.
