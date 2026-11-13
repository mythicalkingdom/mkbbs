Unit CfgPal;   {Terminal palette tweak for the configuration editor}

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
}

Interface

Procedure MaroonOn;
Procedure MaroonOff;

Implementation

Uses Dos;

Const
  Active: Boolean = False;
  Console: Boolean = False;

Function Hex2(S: String; Start: Byte): String;
  Begin
  Hex2 := Copy(S, Start, 2);
  End;

Procedure MaroonOn;
  Var
    Term, Rgb: String;
    i: Byte;

  Begin
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
  If Not Active Then
    Exit;
  If Console Then
    Write(#27 + ']R')
  Else
    Write(#27 + ']104;1' + #7);
  Active := False;
  End;

End.
