Unit CfgPal;   {Terminal palette tweak and a clean screen for the Free Vision programs}

{$I MKB.Def}

{
     Free Vision draws the hot keys (the highlighted letters of menus and
     labels) in ANSI colour 1, "red".  Many terminal themes make that a bright,
     harsh red.  While the editor runs, colour 1 is redefined to a dark red
     (maroon, #800000) and the terminal's own definition is restored when it
     ends.

         xterm, VTE, Konsole, kitty, alacritty ...:  OSC 4 ; 1 ; rgb:RR/GG/BB
                                                     restored with OSC 104 ; 1
         Linux console:                              ESC ] P 1 RRGGBB
                                                     restored with ESC ] R
     Terminals that do not know the sequence ignore it.

     MKCONFIG_RED=rrggbb picks another colour; MKCONFIG_RED=none leaves the
     palette alone.

     The screen.  On some terminals (no alternate screen, or it is switched off: tmux,
     xterm with titeInhibit ...) a Free Vision program leaves its last screenful behind
     when it ends, with the cursor at the top.  So MaroonOff, which the programs call
     after Free Vision has closed the video, resets the colours, shows the cursor and
     clears the screen (the cursor goes to the top left).  Only on a terminal (not when
     the output goes to a file) and not for TERM=dumb.
     MKCONFIG_SCREEN=none leaves the screen alone; MKCONFIG_SCREEN=alt also switches to the
     alternate screen while the program runs and back at the end (the shell screen is
     there again as it was, but the screen is not cleared by us).
}

Interface

Procedure MaroonOn;
Procedure MaroonOff;

Implementation

Uses Dos, Termio;

Const
  Active: Boolean = False;
  Console: Boolean = False;
  ScreenMode: Char = #0;               {a = alternate screen is on, c = clear at the end, #0 = nothing}
  OldExit: Pointer = Nil;

Function Hex2(S: String; Start: Byte): String;
  Begin
  Hex2 := Copy(S, Start, 2);
  End;

Procedure ScreenOn;
  Var
    Term, Mode: String;

  Begin
  ScreenMode := #0;
  Term := GetEnv('TERM');
  Mode := GetEnv('MKCONFIG_SCREEN');
  If (Mode = 'none') Or (Term = '') Or (Term = 'dumb') Or (IsATTY(1) = 0) Then
    Exit;
  If Mode <> 'alt' Then
    ScreenMode := 'c'
  Else
    Begin
    Write(#27 + '[?1049h');
    ScreenMode := 'a';
    End;
  End;

Procedure ScreenOff;
  Begin
  If ScreenMode = 'a' Then
    Write(#27 + '[0m' + #27 + '[?25h' + #27 + '[?1049l' + #27 + '[H')
  Else If ScreenMode = 'c' Then
    Write(#27 + '[0m' + #27 + '[?25h' + #27 + '[2J' + #27 + '[H');
  ScreenMode := #0;
  End;

Procedure MaroonOn;
  Var
    Term, Rgb: String;
    i: Byte;

  Begin
  ScreenOn;
  Term := GetEnv('TERM');
  Rgb := GetEnv('MKCONFIG_RED');
  If Rgb = '' Then
    Rgb := '800000';
  If (Term = '') Or (Term = 'dumb') Or (Rgb = 'none') Or (Length(Rgb) <> 6) Then
    Exit;
  For i := 1 To 6 Do
    If Not (Rgb[i] In ['0'..'9', 'a'..'f', 'A'..'F']) Then
      Exit;
  Console := Copy(Term, 1, 5) = 'linux';
  If Console Then
    Write(#27 + ']P1' + Rgb)
  Else
    Write(#27 + ']4;1;rgb:' + Hex2(Rgb, 1) + '/' + Hex2(Rgb, 3) + '/' +
      Hex2(Rgb, 5) + #7);
  Active := True;
  End;

Procedure MaroonOff;
  Begin
  If Active Then
    Begin
    If Console Then
      Write(#27 + ']R')
    Else
      Write(#27 + ']104;1' + #7);
    Active := False;
    End;
  ScreenOff;
  End;

End.
