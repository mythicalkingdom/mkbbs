Unit MKCp437;   {CP437 (the DOS character set) <-> UTF-8, and which terminals want which}

{$I MKB.Def}

{
     BBS screens and text are written for the IBM PC character set, code page 437:
     box drawing, shading blocks, accented letters.  A terminal that shows UTF-8
     (xterm, PuTTY, a Linux console, a web terminal ...) needs those bytes as UTF-8
     sequences; a BBS terminal (SyncTERM, Windows telnet "ANSI") wants them raw.

       Cp437ToUtf8(Ch)        the UTF-8 bytes of the character CP437 code Ch stands for
       Utf8ToCp437(U)         the CP437 code of Unicode character U (0 = none)
       TermWantsUtf8(Term)    the terminal type a telnet client reported (TTYPE), or the
                              TERM of a local terminal: True = UTF-8, False = CP437
                              as it is (BBS terminals and unknown terminals)

     Only the codes 128..255 are translated.  The control characters and ESC
     sequences are not touched (they are ASCII in both).
}

Interface

Function Cp437ToUtf8(Ch: Byte): String;
Function Utf8ToCp437(U: Word): Byte;
Function TermWantsUtf8(Term: String): Boolean;


Implementation

Uses MKString;


Const
  Cp437Uni: Array[128..255] Of Word = (
  $00C7, $00FC, $00E9, $00E2, $00E4, $00E0, $00E5, $00E7,
  $00EA, $00EB, $00E8, $00EF, $00EE, $00EC, $00C4, $00C5,
  $00C9, $00E6, $00C6, $00F4, $00F6, $00F2, $00FB, $00F9,
  $00FF, $00D6, $00DC, $00A2, $00A3, $00A5, $20A7, $0192,
  $00E1, $00ED, $00F3, $00FA, $00F1, $00D1, $00AA, $00BA,
  $00BF, $2310, $00AC, $00BD, $00BC, $00A1, $00AB, $00BB,
  $2591, $2592, $2593, $2502, $2524, $2561, $2562, $2556,
  $2555, $2563, $2551, $2557, $255D, $255C, $255B, $2510,
  $2514, $2534, $252C, $251C, $2500, $253C, $255E, $255F,
  $255A, $2554, $2569, $2566, $2560, $2550, $256C, $2567,
  $2568, $2564, $2565, $2559, $2558, $2552, $2553, $256B,
  $256A, $2518, $250C, $2588, $2584, $258C, $2590, $2580,
  $03B1, $00DF, $0393, $03C0, $03A3, $03C3, $00B5, $03C4,
  $03A6, $0398, $03A9, $03B4, $221E, $03C6, $03B5, $2229,
  $2261, $00B1, $2265, $2264, $2320, $2321, $00F7, $2248,
  $00B0, $2219, $00B7, $221A, $207F, $00B2, $25A0, $00A0
  );


Function Cp437ToUtf8(Ch: Byte): String;
  Var
    U: Word;

  Begin
  If Ch < 128 Then
    Begin
    Cp437ToUtf8 := Chr(Ch);
    Exit;
    End;
  U := Cp437Uni[Ch];
  If U < $800 Then
    Cp437ToUtf8 := Chr($C0 Or (U Shr 6)) + Chr($80 Or (U And $3F))
  Else
    Cp437ToUtf8 := Chr($E0 Or (U Shr 12)) + Chr($80 Or ((U Shr 6) And $3F)) + Chr($80 Or (U And $3F));
  End;


Function Utf8ToCp437(U: Word): Byte;
  Var
    i: Word;

  Begin
  If U < 128 Then
    Begin
    Utf8ToCp437 := U;
    Exit;
    End;
  Utf8ToCp437 := 0;
  For i := 128 To 255 Do
    If Cp437Uni[i] = U Then
      Begin
      Utf8ToCp437 := i;
      Exit;
      End;
  End;


Function Starts(Const S, Prefix: String): Boolean;
  Begin
  Starts := Copy(S, 1, Length(Prefix)) = Prefix;
  End;


Function TermWantsUtf8(Term: String): Boolean;
  {BBS terminals and PC "ANSI" terminals show CP437 themselves.  The terminal emulators of
   today are UTF-8.  What nobody knows is left alone (CP437 as the BBS sends it).}
  Var
    T: String;

  Begin
  T := Upper(Term);
  TermWantsUtf8 := False;
  If T = '' Then
    Exit;
  If Starts(T, 'ANSI') Or Starts(T, 'SYNCTERM') Or Starts(T, 'PCANSI') Or Starts(T, 'IBM') Or
     Starts(T, 'CP437') Or Starts(T, 'DOS') Or Starts(T, 'NETRUNNER') Then
    Exit;
  If Starts(T, 'XTERM') Or Starts(T, 'VT') Or Starts(T, 'SCREEN') Or Starts(T, 'TMUX') Or
     Starts(T, 'RXVT') Or Starts(T, 'PUTTY') Or Starts(T, 'KONSOLE') Or Starts(T, 'GNOME') Or
     Starts(T, 'VTE') Or Starts(T, 'KITTY') Or Starts(T, 'ALACRITTY') Or Starts(T, 'FOOT') Or
     Starts(T, 'WEZTERM') Or Starts(T, 'ST-') Or (T = 'ST') Or Starts(T, 'LINUX') Or
     Starts(T, 'CYGWIN') Or Starts(T, 'MINTTY') Or Starts(T, 'TERMINATOR') Or
     Starts(T, 'WEBSOCKET') Or Starts(T, 'XTERM.JS') Or Starts(T, 'EMACS') Or Starts(T, 'TERMUX') Then
    TermWantsUtf8 := True;
  End;


End.
