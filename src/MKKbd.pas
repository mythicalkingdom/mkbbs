Unit MKKbd;   {Keyboard driver for Free Vision on Unix terminals}

{$MODE OBJFPC}
{$H-}

{
     The keyboard unit that comes with Free Pascal reports a lone Esc only
     together with the next key (it treats Esc as the start of a key sequence for
     ever) and uses Ctrl-A, Ctrl-W and Ctrl-Z as modifier prefixes, so Esc does
     not close a dialog and the WordStar keys of the text editor do not work.
     This driver reads the terminal itself:

       - a lone Esc is delivered after 40 ms with no further byte,
       - the usual xterm / VT100 / Linux console / rxvt key sequences give the
         same key codes Free Vision knows (arrows, Home, End, Ins, Del, PgUp,
         PgDn, F1..F12, Ctrl-arrows, Shift-Tab, Alt-letter as Esc letter),
       - every Ctrl-letter is a Ctrl-letter,
       - UTF-8 letters are turned into the IBM PC (CP437) character the BBS uses.

     Call InstallKeyboard once, before the Free Vision application is created.
     On anything that is not a terminal nothing is changed.
}

Interface

Procedure InstallKeyboard;

Implementation

Uses Keyboard, BaseUnix, Termio;

Var
  Buf: Array[0..255] Of Byte;
  BufLen: Integer = 0;
  Have: Boolean = False;
  Ready: TKeyEvent = 0;
  Shift: Byte = 0;
  SaveTio: Termios;
  RawOn: Boolean = False;
  Orig: TKeyboardDriver;

Const
  Scan: Array[0..25] Of Byte =          { a .. z }
    ($1E, $30, $2E, $20, $12, $21, $22, $23, $17, $24, $25, $26, $32,
     $31, $18, $19, $10, $13, $1F, $14, $16, $2F, $11, $2D, $15, $2C);
  DigitScan: Array[0..9] Of Byte = ($0B, $02, $03, $04, $05, $06, $07, $08, $09, $0A);


Function Make(Sh, Sc, Ch: Byte): TKeyEvent;
  Begin
  Make := TKeyEvent((3 Shl 24) Or (Sh Shl 16) Or (Sc Shl 8) Or Ch);
  End;


Function PunctScan(C: Char): Byte;
  Begin
  Case C Of
    ' ': PunctScan := $39;
    '-', '_': PunctScan := $0C;
    '=', '+': PunctScan := $0D;
    '[', '{': PunctScan := $1A;
    ']', '}': PunctScan := $1B;
    ';', ':': PunctScan := $27;
    '''', '"': PunctScan := $28;
    '`', '~': PunctScan := $29;
    '\', '|': PunctScan := $2B;
    ',', '<': PunctScan := $33;
    '.', '>': PunctScan := $34;
    '/', '?': PunctScan := $35;
    '!': PunctScan := $02;
    '@': PunctScan := $03;
    '#': PunctScan := $04;
    '$': PunctScan := $05;
    '%': PunctScan := $06;
    '^': PunctScan := $07;
    '&': PunctScan := $08;
    '*': PunctScan := $09;
    '(': PunctScan := $0A;
    ')': PunctScan := $0B;
    Else PunctScan := 0;
    End;
  End;


Function CharEvent(C: Char): TKeyEvent;
  Begin
  If C In ['a'..'z'] Then
    CharEvent := Make(0, Scan[Ord(C) - 97], Ord(C))
  Else If C In ['A'..'Z'] Then
    CharEvent := Make(0, Scan[Ord(C) - 65], Ord(C))
  Else If C In ['0'..'9'] Then
    CharEvent := Make(0, DigitScan[Ord(C) - 48], Ord(C))
  Else
    CharEvent := Make(0, PunctScan(C), Ord(C));
  End;


Function Cp437(U: LongInt): Integer;
  {IBM PC character for a Unicode letter, -1 when there is none}
  Begin
  Case U Of
    $E9: Cp437 := $82; $E2: Cp437 := $83; $E4: Cp437 := $84; $E0: Cp437 := $85;
    $E5: Cp437 := $86; $E7: Cp437 := $87; $EA: Cp437 := $88; $EB: Cp437 := $89;
    $E8: Cp437 := $8A; $EF: Cp437 := $8B; $EE: Cp437 := $8C; $EC: Cp437 := $8D;
    $C4: Cp437 := $8E; $C5: Cp437 := $8F; $C9: Cp437 := $90; $E6: Cp437 := $91;
    $C6: Cp437 := $92; $F4: Cp437 := $93; $F6: Cp437 := $94; $F2: Cp437 := $95;
    $FB: Cp437 := $96; $F9: Cp437 := $97; $FF: Cp437 := $98; $D6: Cp437 := $99;
    $DC: Cp437 := $9A; $A2: Cp437 := $9B; $A3: Cp437 := $9C; $A5: Cp437 := $9D;
    $E1: Cp437 := $A0; $ED: Cp437 := $A1; $F3: Cp437 := $A2; $FA: Cp437 := $A3;
    $F1: Cp437 := $A4; $D1: Cp437 := $A5; $BF: Cp437 := $A8; $DF: Cp437 := $E1;
    $B0: Cp437 := $F8; $B1: Cp437 := $F1; $B7: Cp437 := $FA; $BD: Cp437 := $AB;
    $BC: Cp437 := $AC; $A1: Cp437 := $AD; $AB: Cp437 := $AE; $BB: Cp437 := $AF;
    Else Cp437 := -1;
    End;
  End;


Procedure Fill(WaitMs: LongInt);
  {Read whatever the terminal has sent, waiting up to WaitMs for the first byte}
  Var
    P: TPollFd;
    N: LongInt;

  Begin
  If BufLen > 200 Then
    Exit;
  P.fd := 0;
  P.events := POLLIN;
  P.revents := 0;
  If fpPoll(@P, 1, WaitMs) > 0 Then
    Begin
    N := fpRead(0, Buf[BufLen], 40);
    If N > 0 Then
      Inc(BufLen, N);
    End;
  End;


Procedure Drop(N: Integer);
  Var
    i: Integer;

  Begin
  For i := 0 To BufLen - N - 1 Do
    Buf[i] := Buf[i + N];
  Dec(BufLen, N);
  End;


Function ModShift(M: Integer): Byte;
  {xterm modifier parameter: 2 shift, 3 alt, 4 shift+alt, 5 ctrl ...}
  Begin
  Dec(M);
  ModShift := 0;
  If (M And 1) <> 0 Then ModShift := ModShift Or 3;
  If (M And 2) <> 0 Then ModShift := ModShift Or 8;
  If (M And 4) <> 0 Then ModShift := ModShift Or 4;
  End;


Function CodeScan(Code: Integer; Var Sc: Byte): Boolean;
  {The number in ESC [ <number> ~ : the scan code of the key}
  Begin
  CodeScan := True;
  Case Code Of
    1, 7: Sc := $47;
    2: Sc := $52;
    3: Sc := $53;
    4, 8: Sc := $4F;
    5: Sc := $49;
    6: Sc := $51;
    11..15: Sc := $3B + (Code - 11);
    17..21: Sc := $40 + (Code - 17);
    23: Sc := $85;
    24: Sc := $86;
    Else CodeScan := False;
    End;
  End;


Function Parse(Var Ev: TKeyEvent): Boolean;
  {One event from Buf; False when the bytes there are not complete yet}
  Var
    C: Byte;
    i: Integer;
    U: LongInt;
    Len: Integer;
    Sh, Sc: Byte;
    Fin: Byte;
    Num: Array[0..2] Of Integer;
    NumCnt: Integer;

  Begin
  Parse := False;
  If BufLen = 0 Then
    Exit;
  C := Buf[0];
  Shift := 0;
  If C = 27 Then
    Begin
    If BufLen = 1 Then
      Begin
      Fill(40);                           {a lone Esc: nothing follows}
      If BufLen = 1 Then
        Begin
        Drop(1);
        Ev := Make(0, $01, 27);
        Parse := True;
        Exit;
        End;
      End;
    If Buf[1] = 27 Then
      Begin                               {Esc Esc: an Esc, the second starts a new key}
      Drop(1);
      Ev := Make(0, $01, 27);
      Parse := True;
      Exit;
      End;
    If (Buf[1] = Ord('[')) Or (Buf[1] = Ord('O')) Then
      Begin
      { ESC [ or ESC O, numbers separated by ;, one final byte }
      Num[0] := 0;
      Num[1] := 0;
      Num[2] := 0;
      NumCnt := 0;
      i := 2;
      While (i < BufLen) And ((Buf[i] In [Ord('0')..Ord('9')]) Or (Buf[i] = Ord(';'))) Do
        Begin
        If Buf[i] = Ord(';') Then
          Begin
          If NumCnt < 2 Then
            Inc(NumCnt);
          End
        Else
          Num[NumCnt] := Num[NumCnt] * 10 + (Buf[i] - 48);
        Inc(i);
        End;
      If i >= BufLen Then
        Begin
        Fill(40);                          {the rest of the sequence is on its way}
        If i >= BufLen Then
          Begin
          Drop(BufLen);                    {cut off: forget it}
          Exit;
          End;
        End;
      Fin := Buf[i];
      Drop(i + 1);
      Sh := 0;
      If NumCnt >= 1 Then
        Sh := ModShift(Num[1]);
      Ev := 0;
      Sc := 0;
      Case Fin Of
        Ord('A'): Sc := $48;
        Ord('B'): Sc := $50;
        Ord('C'): Sc := $4D;
        Ord('D'): Sc := $4B;
        Ord('H'): Sc := $47;
        Ord('F'): Sc := $4F;
        Ord('P'): Sc := $3B;
        Ord('Q'): Sc := $3C;
        Ord('R'): Sc := $3D;
        Ord('S'): Sc := $3E;
        Ord('Z'): Begin Sc := $0F; Sh := 3; End;
        Ord('~'): If Not CodeScan(Num[0], Sc) Then Sc := 0;
        End;
      If Sc <> 0 Then
        Begin
        If (Sh And 4) <> 0 Then            {Ctrl with an arrow, Home, End, PgUp, PgDn}
          Case Sc Of
            $4B: Sc := $73;
            $4D: Sc := $74;
            $4F: Sc := $75;
            $51: Sc := $76;
            $47: Sc := $77;
            $49: Sc := $84;
            End;
        Ev := Make(Sh, Sc, 0);
        Shift := Sh;
        Parse := True;
        End;
      Exit;                                {an unknown sequence is dropped}
      End;
    { Esc and a letter: Alt-letter }
    C := Buf[1];
    Drop(2);
    Shift := 8;
    If (C >= 97) And (C <= 122) Then
      Ev := Make(8, Scan[C - 97], 0)
    Else If (C >= 65) And (C <= 90) Then
      Ev := Make(8, Scan[C - 65], 0)
    Else If (C >= 48) And (C <= 57) Then
      Ev := Make(8, $78 + (C - 49) , 0)
    Else
      Ev := Make(8, PunctScan(Chr(C)), 0);
    Parse := True;
    Exit;
    End;
  { a plain byte }
  If C >= $C2 Then
    Begin                                  {UTF-8}
    If C >= $F0 Then Len := 4 Else If C >= $E0 Then Len := 3 Else Len := 2;
    If BufLen < Len Then
      Begin
      Fill(20);
      If BufLen < Len Then
        Begin
        Drop(BufLen);
        Exit;
        End;
      End;
    If Len = 2 Then
      U := ((C And $1F) Shl 6) Or (Buf[1] And $3F)
    Else
      U := 0;
    Drop(Len);
    i := Cp437(U);
    If i >= 0 Then
      Begin
      Ev := Make(0, 0, i);
      Parse := True;
      End
    Else
      Parse := Parse(Ev);
    Exit;
    End;
  Drop(1);
  Case C Of
    13: Ev := Make(0, $1C, 13);
    10: Ev := Make(0, $1C, 13);
    9: Ev := Make(0, $0F, 9);
    8, 127: Ev := Make(0, $0E, 8);
    1..7, 11, 12, 14..26:
      Begin
      Ev := Make(4, Scan[C - 1], C);       {Ctrl-letter}
      Shift := 4;
      End;
    28..31: Ev := Make(4, 0, C);
    0: Ev := Make(4, $39, 0);
    32..126: Ev := CharEvent(Chr(C));
    Else
      Ev := Make(0, 0, C);                 {8 bit characters from an 8 bit terminal}
    End;
  Parse := True;
  End;


Function GetEv(Wait: Boolean): TKeyEvent;
  Var
    Ev: TKeyEvent;

  Begin
  GetEv := 0;
  If Have Then
    Begin
    GetEv := Ready;
    If Wait Then
      Have := False;
    Exit;
    End;
  Repeat
    If BufLen = 0 Then
      Begin
      If Wait Then
        Fill(100)
      Else
        Fill(0);
      End;
    While BufLen > 0 Do
      If Parse(Ev) Then
        Begin
        If Wait Then
          Begin
          GetEv := Ev;
          Exit;
          End;
        Ready := Ev;
        Have := True;
        GetEv := Ev;
        Exit;
        End;
  Until Not Wait;
  End;


Procedure DrvInit;
  Var
    Tio: Termios;

  Begin
  BufLen := 0;
  Have := False;
  If TCGetAttr(0, SaveTio) = 0 Then
    Begin
    Tio := SaveTio;
    CFMakeRaw(Tio);
    Tio.c_cc[VMIN] := 0;
    Tio.c_cc[VTIME] := 0;
    If TCSetAttr(0, TCSANOW, Tio) = 0 Then
      RawOn := True;
    End;
  End;


Procedure DrvDone;
  Begin
  If RawOn Then
    TCSetAttr(0, TCSANOW, SaveTio);
  RawOn := False;
  End;


Function DrvGet: TKeyEvent;
  Begin
  DrvGet := GetEv(True);
  End;


Function DrvPoll: TKeyEvent;
  Begin
  DrvPoll := GetEv(False);
  End;


Function DrvShift: Byte;
  Begin
  DrvShift := Shift;
  End;


Procedure InstallKeyboard;
  Var
    D: TKeyboardDriver;

  Begin
  If TCGetAttr(0, SaveTio) <> 0 Then
    Exit;                                  {not a terminal}
  GetKeyboardDriver(Orig);
  D := Orig;
  D.InitDriver := @DrvInit;
  D.DoneDriver := @DrvDone;
  D.GetKeyEvent := @DrvGet;
  D.PollKeyEvent := @DrvPoll;
  D.GetShiftState := @DrvShift;
  SetKeyboardDriver(D);
  End;


End.
