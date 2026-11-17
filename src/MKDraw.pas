Program MKDraw;

{$I MKB.Def}

{
     mkdraw [-n] [FileName]       screen editor for BBS screens (ANSI, AVATAR, ASCII), Free Vision, text mode

     Converted from the Object Professional MKDRAW.  The screen is the 80 x 23 text screen of a caller (MKVCrt): every
     cell is one IBM PC (CP437) character and one colour attribute (4 bit foreground, 3 bit background, blink).  What
     is shown on the terminal is converted by Free Vision (UTF-8 terminals get the Unicode of the CP437 characters);
     the keyboard driver (MKKbd) turns what is typed or pasted on a UTF-8 terminal back into CP437 codes.

     A file name starts with that file loaded; without one the screen files (*.a*) of the current directory are listed
     to choose from (Esc: start empty).  Files are read and written as the BBS has them: CP437 bytes, CR LF line ends.

        Alt-A  colour / attribute      Alt-B  blinking toggle          Alt-I  intensity toggle
        Alt-U  colour under cursor     Alt-R  reverse attribute        Alt-D  drawing mode (line sets)
        Alt-C  copy area               Alt-M  move area                Alt-F  attribute fill of an area
        Alt-Z  zap (clear) an area     Alt-E  enclose an area in a frame
        Alt-V  insert line             Alt-Y  delete line              Alt-W  double image (2 x 2)
        Alt-G  get a character set     Alt-P  pick a BBS screen code   Alt-L  load       Alt-S  save
        F1..F10  enter the special characters of the current set (Alt-F1..F10 = set 1..10, Ctrl-F1..F5 = set 11..15,
                 Alt-1..Alt-9 = set 1..9)       Ctrl-A..Ctrl-Z  enter that control code
        Esc    the fast menu with all commands     Alt-H  help      Alt-X  leave
        an area is chosen with the arrow keys and Enter (or Space) for each corner, L takes the last area again

     The colour guard: a saved ANSI file (and the Pascal source) is made so that every colour reset (ESC[0m, ESC[m)
     also sets the foreground and the background (light gray on black as the DOS default): a terminal with its own
     default colours then shows the art as it was drawn (MKSgr, the same guard the BBS uses for UTF-8 callers).
     -n leaves the files as the original program wrote them.

     Gone from the DOS version: the shell (Alt-J), the swap file, the mouse cursor drawing (the terminal's mouse
     reports are used for moving the cursor and as Esc).  Writing at the last position of the screen does not
     scroll it; ^Z ends a file that is loaded.
}

Uses
  Objects, Drivers, Views, Dialogs, App, Dos, BaseUnix,
  MKString, MKFile, MKVCrt, MKAvatar, MKSgr,
  MKDrawCf, CfgBox, CfgList, CfgColor, CfgPal, MKKbd;


Const
  ScrW = 80;
  ScrH = 23;
  WColor = $1F;                          {white on blue: the status lines}
  BannerName = '  MKDraw v1.01 Copyright 1992,1995 by Mark May         Press Alt-H for Help';

  {commands that are not in MKDrawCf}
  ccQuit = 5001;
  ccLeft = 5002;
  ccRight = 5003;
  ccUp = 5004;
  ccDown = 5005;
  ccHome = 5006;
  ccEnd = 5007;
  ccPgUp = 5008;
  ccPgDn = 5009;
  ccTab = 5010;
  ccBackTab = 5011;
  ccSelect = 5012;
  ccBack = 5013;
  ccDel = 5014;
  ccIns = 5015;
  ccChar = 5016;
  ccMouseSel = 5017;
  ccSlot = 5100;                         {+ 1..10: enter a special character}
  ccSet = 5200;                          {+ 1..15: select a character set}


Type
  CellRow = Array[1..ScrW] Of Word;
  PScreenCopy = ^ScreenCopy;
  ScreenCopy = Array[1..ScrH] Of CellRow;


Var
  CurrFile: String;
  InsertMode: Boolean;
  DrawSet: Word;                         {1..4 a line set, 5 normal}
  LXL, LYL, LXH, LYH: Byte;              {the last area}
  UseGuard: Boolean;
  StatusMsg: String;                     {what the top line says (the banner when empty)}
  SaveGuard: SgrGuardObj;
  Finished: Boolean;


{------------------------------------------------ the two views}

Type
  PStatusView = ^StatusView;
  StatusView = Object(TView)
    Constructor Init(Var R: TRect);
    Procedure Draw; Virtual;
    End;

  PCanvasView = ^CanvasView;
  CanvasView = Object(TView)
    Constructor Init(Var R: TRect);
    Procedure Draw; Virtual;
    End;

Var
  Stat: PStatusView;
  Cv: PCanvasView;


Function Pad3(N: Word): String;
  Var
    S: String;

  Begin
  Str(N, S);
  While Length(S) < 3 Do
    S := ' ' + S;
  Pad3 := S;
  End;


Constructor StatusView.Init(Var R: TRect);
  Begin
  Inherited Init(R);
  End;


Procedure StatusView.Draw;
  Var
    B: TDrawBuffer;
    S: String;
    i: Word;
    T: String;

  Begin
  {the top line: the banner or the question of the command that is running}
  MoveChar(B[0], ' ', WColor, Size.X);
  If StatusMsg = '' Then
    S := BannerName
  Else
    S := StatusMsg;
  MoveStr(B[0], Copy(S, 1, Size.X), WColor);
  If (StatusMsg = '') And (DrawSet >= 1) And (DrawSet <= 4) Then
    For i := 1 To 6 Do
      B[46 + i] := (WColor Shl 8) Or Ord(ExtChars[DrawSet][i]);
  WriteLine(0, 0, Size.X, 1, B);
  {the second line: position, colour, insert, set, the special characters}
  MoveChar(B[0], ' ', WColor, Size.X);
  MoveStr(B[2], '(', WColor);
  MoveStr(B[3], Pad3(WhereX) + ',' + Pad3(WhereY), WColor);
  MoveStr(B[10], ')', WColor);
  MoveStr(B[13], 'Color', TextAttr);
  If InsertMode Then
    MoveStr(B[20], 'Ins', WColor)
  Else
    MoveStr(B[20], 'Ovr', WColor);
  MoveStr(B[25], 'Set', WColor);
  Str(CurrSet: 2, T);
  MoveStr(B[29], T, WColor);
  For i := 1 To 10 Do
    Begin
    Str(i, T);
    MoveStr(B[35 + (i - 1) * 4], T + '=', WColor);
    If i = 10 Then
      B[74] := (WColor Shl 8) Or Ord(ExtChars[CurrSet][i])
    Else
      B[33 + i * 4] := (WColor Shl 8) Or Ord(ExtChars[CurrSet][i]);
    End;
  WriteLine(0, 1, Size.X, 1, B);
  End;


Constructor CanvasView.Init(Var R: TRect);
  Begin
  Inherited Init(R);
  Options := Options Or ofSelectable;
  End;


Procedure CanvasView.Draw;
  Var
    B: TDrawBuffer;
    X, Y: Integer;

  Begin
  For Y := 0 To Size.Y - 1 Do
    Begin
    For X := 0 To Size.X - 1 Do
      If (X < ScrW) And (Y < ScrH) Then
        B[X] := VScreen^[Y * VCols + X]
      Else
        B[X] := $0720;
    WriteLine(0, Y, Size.X, 1, B);
    End;
  End;


Procedure Refresh;
  {Show the screen, the position and the colour; the cursor where the screen's cursor is}
  Begin
  If Cv <> Nil Then
    Begin
    Cv^.DrawView;
    Cv^.SetCursor(WhereX - 1, WhereY - 1);
    End;
  If Stat <> Nil Then
    Stat^.DrawView;
  End;


Procedure SetMsg(S: String);
  Begin
  StatusMsg := S;
  If Stat <> Nil Then
    Stat^.DrawView;
  End;


{------------------------------------------------ the screen: cells}

Function CellChar(X, Y: Byte): Char;
  Begin
  CellChar := Chr(VGetCell(X, Y) And $FF);
  End;


Function CellAttr(X, Y: Byte): Byte;
  Begin
  CellAttr := VGetCell(X, Y) Shr 8;
  End;


Procedure PutCell(X, Y: Byte; Ch: Char; Attr: Byte);
  Begin
  If (X >= 1) And (X <= ScrW) And (Y >= 1) And (Y <= ScrH) Then
    VPutCell(X, Y, Ord(Ch) Or (Word(Attr) Shl 8));
  End;


Function RowChars(Y, X, Cnt: Byte): String;
  Var
    S: String;
    i: Word;

  Begin
  S := '';
  For i := X To X + Cnt - 1 Do
    If i <= ScrW Then
      S := S + CellChar(i, Y);
  RowChars := S;
  End;


Function RowAttrs(Y, X, Cnt: Byte): String;
  Var
    S: String;
    i: Word;

  Begin
  S := '';
  For i := X To X + Cnt - 1 Do
    If i <= ScrW Then
      S := S + Chr(CellAttr(i, Y));
  RowAttrs := S;
  End;


Procedure SetCursorTo(X, Y: Integer);
  Begin
  If X < 1 Then X := 1;
  If X > ScrW Then X := ScrW;
  If Y < 1 Then Y := 1;
  If Y > ScrH Then Y := ScrH;
  GotoXY(X, Y);
  End;


Procedure PutStr(S: String);
  {the characters at the cursor with the current attribute, the cursor moves on; the screen does not scroll}
  Var
    i: Word;
    X, Y: Byte;

  Begin
  X := WhereX;
  Y := WhereY;
  For i := 1 To Length(S) Do
    Begin
    PutCell(X, Y, S[i], TextAttr);
    If X < ScrW Then
      Inc(X)
    Else If Y < ScrH Then
      Begin
      X := 1;
      Inc(Y);
      End;
    End;
  GotoXY(X, Y);
  End;


{------------------------------------------------ drawing mode (the line sets)}

Const
  DrawChars: Array[1..4] Of String[16] = (
    #32#32#32#196#32#191#218#194#32#217#192#193#179#180#195#197,
    #32#32#32#205#32#187#201#203#32#188#200#202#186#185#204#206,
    #32#32#32#205#32#184#213#209#32#190#212#207#179#181#198#216,
    #32#32#32#196#32#183#214#210#32#189#211#208#186#182#199#215);


Function GetCharValue(X, Y: Integer): Byte;
  {Which lines the character at X,Y has (1 left, 2 right, 4 down, 8 up); 0 when it is none of the set's}
  Var
    Ch: Char;
    P, i: Word;

  Begin
  If (X > 0) And (X <= ScrW) And (Y > 0) And (Y <= ScrH) Then
    Ch := CellChar(X, Y)
  Else
    Ch := ' ';
  P := 0;
  i := 1;
  While (P = 0) And (i <= 4) Do
    Begin
    P := Pos(Ch, DrawChars[i]);
    Inc(i);
    End;
  If P = 0 Then
    GetCharValue := 0
  Else
    GetCharValue := P - 1;
  End;


Function GetDrawChar(X, Y: Integer; Going: Word): Char;
  {Going 1 = left 2 = right 3 = down 4 = up}
  Var
    Tmp: Word;

  Begin
  Tmp := 0;
  If Going = 1 Then
    Inc(Tmp, 1)
  Else If (GetCharValue(X - 1, Y) And 2) <> 0 Then
    Inc(Tmp, 1);
  If Going = 2 Then
    Inc(Tmp, 2)
  Else If (GetCharValue(X + 1, Y) And 1) <> 0 Then
    Inc(Tmp, 2);
  If Going = 3 Then
    Inc(Tmp, 4)
  Else If (GetCharValue(X, Y + 1) And 8) <> 0 Then
    Inc(Tmp, 4);
  If Going = 4 Then
    Inc(Tmp, 8)
  Else If (GetCharValue(X, Y - 1) And 4) <> 0 Then
    Inc(Tmp, 8);
  If (Tmp = 1) Or (Tmp = 2) Then
    Tmp := 3;
  If (Tmp = 4) Or (Tmp = 8) Then
    Tmp := 12;
  GetDrawChar := DrawChars[DrawSet][Tmp + 1];
  End;


Procedure PutDrawChar(X, Y: Integer; Going: Word);
  Begin
  If (DrawSet >= 1) And (DrawSet <= 4) Then
    PutCell(X, Y, GetDrawChar(X, Y, Going), TextAttr);
  End;


{------------------------------------------------ keys and mouse}

Function KeyCommand(K: Word): Word;
  {the command of a key (0 = none)}
  Begin
  KeyCommand := 0;
  Case K Of
    kbEsc: KeyCommand := ccQuit;
    kbUp: KeyCommand := ccUp;
    kbDown: KeyCommand := ccDown;
    kbLeft: KeyCommand := ccLeft;
    kbRight: KeyCommand := ccRight;
    kbHome: KeyCommand := ccHome;
    kbEnd: KeyCommand := ccEnd;
    kbPgUp: KeyCommand := ccPgUp;
    kbPgDn: KeyCommand := ccPgDn;
    kbTab: KeyCommand := ccTab;
    kbShiftTab: KeyCommand := ccBackTab;
    kbEnter: KeyCommand := ccSelect;
    kbBack: KeyCommand := ccBack;
    kbDel: KeyCommand := ccDel;
    kbIns: KeyCommand := ccIns;
    kbF1..kbF10: KeyCommand := ccSlot + 1 + ((K - kbF1) Shr 8);
    kbAltF1..kbAltF10: KeyCommand := ccSet + 1 + ((K - kbAltF1) Shr 8);
    kbCtrlF1..kbCtrlF5: KeyCommand := ccSet + 11 + ((K - kbCtrlF1) Shr 8);
    $7800..$8000: KeyCommand := ccSet + 1 + ((K - $7800) Shr 8);   {Alt-1 .. Alt-9}
    kbAltA: KeyCommand := cmAttrPick;
    kbAltB: KeyCommand := cmBlink;
    kbAltC: KeyCommand := cmCopy;
    kbAltD: KeyCommand := cmDrawMode;
    kbAltE: KeyCommand := cmEnclose;
    kbAltF: KeyCommand := cmFill;
    kbAltG: KeyCommand := cmGetSet;
    kbAltH: KeyCommand := cmHelp;
    kbAltI: KeyCommand := cmIntens;
    kbAltL: KeyCommand := cmLoad;
    kbAltM: KeyCommand := cmMove;
    kbAltP: KeyCommand := cmBbsCode;
    kbAltR: KeyCommand := cmReverse;
    kbAltS: KeyCommand := cmSave;
    kbAltU: KeyCommand := cmUnder;
    kbAltV: KeyCommand := cmInsLine;
    kbAltW: KeyCommand := cmDouble;
    kbAltX: KeyCommand := cmExitDraw;
    kbAltY: KeyCommand := cmDelLine;
    kbAltZ: KeyCommand := cmClear;
    End;
  End;


Function ReadCmd(Var Ch: Char; Var MX, MY: Integer): Word;
  {Waits for the next key or mouse click: the command (ccChar with Ch for a character or a control code)}
  Var
    E: TEvent;
    C: Word;
    P: TPoint;

  Begin
  ReadCmd := 0;
  Ch := #0;
  Repeat
    Application^.GetEvent(E);
    If E.What = evNothing Then
      Begin
      Application^.Idle;
      fpSelect(0, Nil, Nil, Nil, 5);   {not a busy loop}
      End
    Else If E.What = evKeyDown Then
      Begin
      C := KeyCommand(E.KeyCode);
      If C <> 0 Then
        Begin
        ReadCmd := C;
        Exit;
        End;
      If (E.CharCode <> #0) And Not (E.CharCode In [#8, #9, #13, #27]) Then
        Begin
        Ch := E.CharCode;
        ReadCmd := ccChar;
        Exit;
        End;
      End
    Else If E.What = evMouseDown Then
      Begin
      If (E.Buttons And mbRightButton) <> 0 Then
        Begin
        ReadCmd := ccQuit;
        Exit;
        End;
      Cv^.MakeLocal(E.Where, P);
      If (P.X >= 0) And (P.X < ScrW) And (P.Y >= 0) And (P.Y < ScrH) Then
        Begin
        MX := P.X + 1;
        MY := P.Y + 1;
        ReadCmd := ccMouseSel;
        Exit;
        End;
      End;
  Until False;
  End;


Function Upper1(Ch: Char): Char;
  Begin
  Upper1 := UpCase(Ch);
  End;


{------------------------------------------------ attribute helpers}

Function SwapNibbles(A: Byte): Byte;
  Begin
  SwapNibbles := ((A Shr 4) Or (A Shl 4)) And $FF;
  End;


Procedure ReverseRect(XL, YL, XH, YH: Byte);
  Var
    X, Y: Word;

  Begin
  For Y := YL To YH Do
    For X := XL To XH Do
      If (X <= ScrW) And (Y <= ScrH) Then
        PutCell(X, Y, CellChar(X, Y), SwapNibbles(CellAttr(X, Y)));
  End;


Procedure UpdateAll;
  Begin
  Refresh;
  End;


{------------------------------------------------ choosing an area}

Function GetRect(Var XL, YL, XH, YH: Byte): Boolean;
  Var
    Done, Go: Boolean;
    Cmd: Word;
    Ch: Char;
    MX, MY: Integer;
    X, Y: Integer;

  Begin
  GetRect := False;
  Go := True;
  SetMsg('Move to upper left corner and press enter  (L = the last area, Esc = cancel)');
  Done := False;
  While Not Done Do
    Begin
    Refresh;
    Cmd := ReadCmd(Ch, MX, MY);
    If (Cmd = ccChar) And (Ch = ' ') Then
      Cmd := ccSelect
    Else If (Cmd = ccChar) And (Upper1(Ch) = 'L') Then
      Begin                                {the last area again}
      XL := LXL;
      XH := LXH;
      YL := LYL;
      YH := LYH;
      SetMsg('');
      GetRect := True;
      Exit;
      End;
    X := WhereX;
    Y := WhereY;
    Case Cmd Of
      ccQuit:
        Begin
        Done := True;
        Go := False;
        End;
      ccLeft: If X > 1 Then SetCursorTo(X - 1, Y) Else SetCursorTo(ScrW, Y);
      ccUp: SetCursorTo(X, Y - 1);
      ccDown: SetCursorTo(X, Y + 1);
      ccRight: If X < ScrW Then SetCursorTo(X + 1, Y) Else SetCursorTo(1, Y);
      ccHome: SetCursorTo(1, Y);
      ccEnd: SetCursorTo(ScrW, Y);
      ccPgUp: SetCursorTo(X, 1);
      ccPgDn: SetCursorTo(X, ScrH);
      ccTab: If X < 72 Then SetCursorTo((X + 8) And $F8, Y) Else SetCursorTo(79, Y);
      ccBackTab: If X > 8 Then SetCursorTo((X - 1) And $F8, Y) Else SetCursorTo(1, Y);
      ccMouseSel:
        Begin
        If (MX = X) And (MY = Y) Then
          Begin
          Done := True;
          XL := X;
          YL := Y;
          End
        Else
          SetCursorTo(MX, MY);
        End;
      ccSelect:
        Begin
        Done := True;
        XL := X;
        YL := Y;
        End;
      End;
    End;
  If Go Then
    Begin
    SetMsg('Move to lower right corner and press enter  (Esc = cancel)');
    ReverseRect(XL, YL, XL, YL);
    Done := False;
    While Not Done Do
      Begin
      Refresh;
      Cmd := ReadCmd(Ch, MX, MY);
      If (Cmd = ccChar) And (Ch = ' ') Then
        Cmd := ccSelect;
      ReverseRect(XL, YL, WhereX, WhereY);          {take the old area back}
      X := WhereX;
      Y := WhereY;
      Case Cmd Of
        ccQuit:
          Begin
          Done := True;
          Go := False;
          End;
        ccLeft: If X > XL Then SetCursorTo(X - 1, Y);
        ccUp: If Y > YL Then SetCursorTo(X, Y - 1);
        ccDown: SetCursorTo(X, Y + 1);
        ccRight: SetCursorTo(X + 1, Y);
        ccEnd: SetCursorTo(ScrW, Y);
        ccPgDn: SetCursorTo(X, ScrH);
        ccTab: If X < 72 Then SetCursorTo((X + 8) And $F8, Y) Else SetCursorTo(79, Y);
        ccBackTab: If ((X - 1) And $F8) >= XL Then SetCursorTo((X - 1) And $F8, Y) Else SetCursorTo(XL, Y);
        ccMouseSel:
          Begin
          If (MX = X) And (MY = Y) Then
            Begin
            Done := True;
            XH := X;
            YH := Y;
            LXL := XL;
            LXH := XH;
            LYL := YL;
            LYH := YH;
            End
          Else If (MX >= XL) And (MY >= YL) Then
            SetCursorTo(MX, MY);
          End;
        ccSelect:
          Begin
          Done := True;
          XH := X;
          YH := Y;
          LXL := XL;
          LXH := XH;
          LYL := YL;
          LYH := YH;
          End;
        End;
      ReverseRect(XL, YL, WhereX, WhereY);          {the new area}
      End;
    ReverseRect(XL, YL, WhereX, WhereY);            {and back to normal}
    End;
  SetMsg('');
  GetRect := Go;
  End;


{------------------------------------------------ the files}

Procedure PutLine(Var TF: Text; S: String);
  {Screen files are DOS text: CR LF}
  Begin
  Write(TF, S, #13#10);
  End;


Function Guarded(S: String): String;
  {an ANSI string with the colour guard of the BBS (MKSgr) applied: a reset that sets no foreground or no
   background is followed by the missing DOS colour}
  Var
    R: String;
    i: Word;

  Begin
  If Not UseGuard Then
    Begin
    Guarded := S;
    Exit;
    End;
  R := '';
  For i := 1 To Length(S) Do
    R := R + S[i] + SaveGuard.Feed(S[i]);
  Guarded := R;
  End;


Function TrimmedLength(Var CharStr, AttrStr: String): Word;
  {the length without the spaces at the end that have no background colour}
  Var
    i: Word;

  Begin
  i := Length(CharStr);
  While (i > 0) And (CharStr[i] = ' ') And ((Ord(AttrStr[i]) And $70) = 0) Do
    Dec(i);
  TrimmedLength := i;
  End;


Function OpenOut(Var TF: Text; FN: String): Boolean;
  Begin
  Assign(TF, FN);
  ReWrite(TF);
  OpenOut := IOResult = 0;
  End;


Function CloseOut(Var TF: Text): Boolean;
  Begin
  Close(TF);
  CloseOut := IOResult = 0;
  End;


Function SaveAnsi(FN: String; XL, YL, XH, YH: Byte; Action: Word): Boolean;
  Var
    CY: Byte;
    CharStr, AttrStr, TmpStr: String;
    LastAttr: Char;
    TF: Text;
    i, L: Word;

  Begin
  SaveAnsi := False;
  If Not OpenOut(TF, FN) Then
    Exit;
  SaveGuard.Init;
  Case Action Of
    2: Write(TF, #27'[H');
    3: Write(TF, Guarded(AnsiColor(Cyan, Black) + #27'[2J'));
    End;
  LastAttr := Chr(Cyan);
  For CY := YL To YH Do
    Begin
    CharStr := RowChars(CY, XL, XH + 1 - XL);
    AttrStr := RowAttrs(CY, XL, XH + 1 - XL);
    L := TrimmedLength(CharStr, AttrStr);
    TmpStr := '';
    For i := 1 To L Do
      Begin
      If AttrStr[i] <> LastAttr Then
        Begin
        If (CharStr[i] <> ' ') Or ((Ord(AttrStr[i]) And $70) <> (Ord(LastAttr) And $70)) Then
          Begin
          TmpStr := TmpStr + Guarded(AnsiAttrDiff(Ord(LastAttr), Ord(AttrStr[i])));
          LastAttr := AttrStr[i];
          End;
        End;
      TmpStr := TmpStr + CharStr[i];
      If Length(TmpStr) > 200 Then
        Begin
        Write(TF, TmpStr);
        TmpStr := '';
        End;
      End;
    PutLine(TF, TmpStr);
    End;
  SaveAnsi := CloseOut(TF);
  End;


Function SavePascal(FN: String; XL, YL, XH, YH: Byte; Action: Word): Boolean;
  Var
    CY: Byte;
    CharStr, AttrStr, TmpStr: String;
    LastAttr: Char;
    TF: Text;
    i, L: Word;

  Begin
  SavePascal := False;
  If Not OpenOut(TF, FN) Then
    Exit;
  SaveGuard.Init;
  PutLine(TF, 'Procedure DoBanner;');
  PutLine(TF, '  Begin');
  Case Action Of
    2: PutLine(TF, '  AvStr(''' + #27'[H' + ''');');
    3: PutLine(TF, '  AvStr(''' + Guarded(AnsiColor(Cyan, Black) + #27'[2J') + ''');');
    End;
  LastAttr := Chr(Cyan);
  For CY := YL To YH Do
    Begin
    CharStr := RowChars(CY, XL, XH + 1 - XL);
    AttrStr := RowAttrs(CY, XL, XH + 1 - XL);
    L := TrimmedLength(CharStr, AttrStr);
    TmpStr := '';
    For i := 1 To L Do
      Begin
      If AttrStr[i] <> LastAttr Then
        Begin
        If (CharStr[i] <> ' ') Or ((Ord(AttrStr[i]) And $70) <> (Ord(LastAttr) And $70)) Then
          Begin
          TmpStr := TmpStr + Guarded(AnsiAttrDiff(Ord(LastAttr), Ord(AttrStr[i])));
          LastAttr := AttrStr[i];
          End;
        End;
      If CharStr[i] = '''' Then
        TmpStr := TmpStr + CharStr[i] + CharStr[i]
      Else
        TmpStr := TmpStr + CharStr[i];
      If Length(TmpStr) > 100 Then
        Begin
        PutLine(TF, '  AvStr(''' + TmpStr + ''');');
        TmpStr := '';
        End;
      End;
    PutLine(TF, '  AvStrLn(''' + TmpStr + ''');');
    End;
  PutLine(TF, '  End;');
  SavePascal := CloseOut(TF);
  End;


Function SaveAvatar(FN: String; XL, YL, XH, YH: Byte; Action: Word): Boolean;
  {AVATAR: ^V ^A attribute, ^Y char count (run of 3 or more equal characters and attributes), ^V ^H row col (home), ^L}
  Var
    CY: Byte;
    CharStr, AttrStr, TmpStr: String;
    LastAttr, LastChar: Char;
    CharCnt: Word;
    TF: Text;
    i, L: Word;

    Function Same(a, b: Word): Boolean;      {the characters and attributes at a and b are the same; no b = no}
      Begin
      If (a > L) Or (b > L) Then
        Same := False
      Else
        Same := (CharStr[a] = CharStr[b]) And (AttrStr[a] = AttrStr[b]);
      End;

  Begin
  SaveAvatar := False;
  If Not OpenOut(TF, FN) Then
    Exit;
  LastAttr := #0;
  LastChar := #0;
  CharCnt := 0;
  Case Action Of
    2: Write(TF, #22#8#1#1);
    3: Write(TF, #12);
    End;
  For CY := YL To YH Do
    Begin
    CharStr := RowChars(CY, XL, XH + 1 - XL);
    AttrStr := RowAttrs(CY, XL, XH + 1 - XL);
    L := TrimmedLength(CharStr, AttrStr);
    TmpStr := '';
    For i := 1 To L Do
      Begin
      If AttrStr[i] <> LastAttr Then
        Begin
        If (CharStr[i] <> ' ') Or ((Ord(AttrStr[i]) And $70) <> (Ord(LastAttr) And $70)) Then
          Begin
          TmpStr := TmpStr + #22#1 + AttrStr[i];
          LastAttr := AttrStr[i];
          End;
        End;
      If CharCnt = 0 Then
        Begin
        If Same(i, i + 1) And Same(i, i + 2) Then
          Begin
          CharCnt := 1;
          LastChar := CharStr[i];
          End
        Else
          TmpStr := TmpStr + CharStr[i];
        End
      Else If Not Same(i, i + 1) Then
        Begin
        TmpStr := TmpStr + #25 + LastChar + Chr(CharCnt + 1);
        CharCnt := 0;
        End
      Else
        Inc(CharCnt);
      End;
    If CharCnt > 0 Then
      Begin
      TmpStr := TmpStr + #25 + LastChar + Chr(CharCnt);
      CharCnt := 0;
      End;
    PutLine(TF, TmpStr);
    End;
  SaveAvatar := CloseOut(TF);
  End;


Function SaveAscii(FN: String; XL, YL, XH, YH: Byte; Action: Word): Boolean;
  Var
    CY: Byte;
    TF: Text;

  Begin
  SaveAscii := False;
  If Not OpenOut(TF, FN) Then
    Exit;
  Case Action Of
    2, 3: Write(TF, #12);
    End;
  For CY := YL To YH Do
    PutLine(TF, StripTrail(RowChars(CY, XL, XH + 1 - XL), ' '));
  SaveAscii := CloseOut(TF);
  End;


Procedure SaveFile;
  Var
    FStr: NameStr;
    EStr: ExtStr;
    DStr: DirStr;
    Name, Ext: String;
    DoAll, DoSave, Ok: Boolean;
    XL, YL, XH, YH: Byte;
    Action: Word;

  Begin
  FSplit(CurrFile, DStr, FStr, EStr);
  If Pos('*', FStr + EStr) > 0 Then
    Name := DStr
  Else
    Name := DStr + FStr;                {no extension: the screen is saved as .asc, .ans and .avt}
  If Not InputLine('MKDraw', 'FileName: ', 55, Name) Then
    Exit;
  If Name = '' Then
    Exit;
  FSplit(Name, DStr, FStr, EStr);
  DoAll := EStr = '';
  If DoAll Then
    DoSave := Not (FileExist(Name + '.avt') Or FileExist(Name + '.ans') Or FileExist(Name + '.asc'))
  Else
    DoSave := Not FileExist(Name);
  If Not DoSave Then
    DoSave := DoYesNo('[ Overwrite File ]', False) = 1;
  If DoSave Then
    DoSave := GetRect(XL, YL, XH, YH);
  If DoSave Then
    Begin
    Action := GetActionCmd;
    If Action = 0 Then
      DoSave := False;
    End;
  If Not DoSave Then
    Exit;
  Ok := True;
  If DoAll Then
    Begin
    Ok := SaveAscii(Name + '.asc', XL, YL, XH, YH, Action);
    If Ok Then
      Ok := SaveAnsi(Name + '.ans', XL, YL, XH, YH, Action);
    If Ok Then
      Ok := SaveAvatar(Name + '.avt', XL, YL, XH, YH, Action);
    End
  Else
    Begin
    Ext := Upper(EStr);
    If Ext = '.AVT' Then
      Ok := SaveAvatar(Name, XL, YL, XH, YH, Action)
    Else If Ext = '.ANS' Then
      Ok := SaveAnsi(Name, XL, YL, XH, YH, Action)
    Else If (Ext = '.PAS') Or (Ext = '.INC') Then
      Ok := SavePascal(Name, XL, YL, XH, YH, Action)
    Else
      Ok := SaveAscii(Name, XL, YL, XH, YH, Action);
    End;
  If Not Ok Then
    MsgBox('The file could not be written: ' + Name);
  End;


Procedure LoadScreen(FN: String);
  {draw a screen file on the screen: ANSI, AVATAR or text; ` stands for ESC (as in the original), ^Z ends the file}
  Var
    AFile: File;
    Buffer: Array[1..512] Of Char;
    i, NumRead: LongInt;
    Ch: Char;
    Stop: Boolean;

  Begin
  If (FN = '') Or (Not FileExist(FN)) Then
    Begin
    MsgBox('There is no file ' + FN);
    Exit;
    End;
  Assign(AFile, FN);
  FileMode := 0;
  Reset(AFile, 1);
  If IOResult <> 0 Then
    Begin
    MsgBox('Cannot open ' + FN);
    Exit;
    End;
  AVReset;                               {the screen is cleared, cyan on black}
  GotoXY(1, 1);
  Stop := False;
  While Not Stop Do
    Begin
    BlockRead(AFile, Buffer, SizeOf(Buffer), NumRead);
    If (IOResult <> 0) Or (NumRead <= 0) Then
      Break;
    For i := 1 To NumRead Do
      Begin
      Ch := Buffer[i];
      If Ch = #26 Then
        Begin
        Stop := True;
        Break;
        End;
      If Ch = '`' Then
        Ch := #27;
      If (Ch <> #10) Or (WhereY <> ScrH) Then
        AvatarChar(Ch);
      End;
    End;
  Close(AFile);
  If IOResult <> 0 Then;
  GotoXY(1, 1);
  End;


Function IsWild(St: String): Boolean;
  Begin
  IsWild := (Pos('?', St) > 0) Or (Pos('*', St) > 0);
  End;


Procedure GetLoadFile;
  Var
    TmpName, Chosen: String;
    D: DirStr;
    N: NameStr;
    E: ExtStr;

  Begin
  FSplit(CurrFile, D, N, E);
  TmpName := D + '*.a??';
  If InputLine('MKDraw', 'FileName: ', 55, TmpName) Then
    Begin
    If IsWild(TmpName) Then
      Begin
      If Not PickScreenFile(TmpName, Chosen) Then
        Exit;
      TmpName := Chosen;
      End;
    If (TmpName <> '') And FileExist(TmpName) Then
      Begin
      CurrFile := TmpName;
      LoadScreen(CurrFile);
      End
    Else If TmpName <> '' Then
      MsgBox('There is no file ' + TmpName);
    End;
  End;


{------------------------------------------------ the editing commands}

Procedure DoDouble;
  {the upper left quarter of the screen (40 x 11) in double size (2 x 2 cells)}
  Var
    xx, yy: Integer;
    Ch: Char;
    A: Byte;

  Begin
  For xx := ScrW Div 2 - 1 Downto 0 Do
    For yy := ScrH Div 2 - 1 Downto 0 Do
      Begin
      Ch := CellChar(xx + 1, yy + 1);
      A := CellAttr(xx + 1, yy + 1);
      PutCell(xx * 2 + 2, yy * 2 + 2, Ch, A);
      PutCell(xx * 2 + 2, yy * 2 + 1, Ch, A);
      PutCell(xx * 2 + 1, yy * 2 + 2, Ch, A);
      PutCell(xx * 2 + 1, yy * 2 + 1, Ch, A);
      End;
  End;


Procedure DoClear;
  Var
    XL, YL, XH, YH: Byte;
    X, Y: Word;

  Begin
  If GetRect(XL, YL, XH, YH) Then
    If DoYesNo('[ Clear Area ]', True) = 1 Then
      For Y := YL To YH Do
        For X := XL To XH Do
          PutCell(X, Y, ' ', TextAttr);
  End;


Function PickAttr(Title: String; Var A: Byte): Boolean;
  {the colours of the grid; the blink bit stays as it is}
  Var
    T: Byte;

  Begin
  T := A;
  PickColor(@T, Title);
  PickAttr := T <> A;
  A := (A And $80) Or (T And $7F);
  End;


Procedure DoAttr;
  Var
    XL, YL, XH, YH: Byte;
    X, Y: Word;
    TA: Byte;

  Begin
  If GetRect(XL, YL, XH, YH) Then
    Begin
    TA := TextAttr;
    If PickAttr('[ Attribute Fill ]', TA) Or True Then
      For Y := YL To YH Do
        For X := XL To XH Do
          PutCell(X, Y, CellChar(X, Y), TA);
    End;
  End;


Procedure DoEnclose;
  Var
    XL, YL, XH, YH: Byte;
    FType: Word;
    X, Y: Word;
    S: String;

  Begin
  If GetRect(XL, YL, XH, YH) Then
    Begin
    If (CurrSet >= 1) And (CurrSet <= 4) Then
      FType := CurrSet
    Else
      FType := 1;
    S := ExtChars[FType];
    PutCell(XL, YL, S[1], TextAttr);
    PutCell(XH, YL, S[2], TextAttr);
    PutCell(XL, YH, S[3], TextAttr);
    PutCell(XH, YH, S[4], TextAttr);
    For X := XL + 1 To XH - 1 Do
      Begin
      PutCell(X, YL, S[5], TextAttr);
      PutCell(X, YH, S[5], TextAttr);
      End;
    For Y := YL + 1 To YH - 1 Do
      Begin
      PutCell(XL, Y, S[6], TextAttr);
      PutCell(XH, Y, S[6], TextAttr);
      End;
    End;
  End;


Procedure RestoreScrn(XL, YL, XH, YH, CX, CY: Byte; Moving: Boolean; Var OScrn: ScreenCopy);
  {what was under the block at CX,CY comes back; when moving, the cells that are inside the source area stay blank}
  Var
    i, j: Word;

  Begin
  For j := CY To CY + YH - YL Do
    For i := CX To CX + XH - XL Do
      If (i <= ScrW) And (j <= ScrH) Then
        Begin
        If Moving And (i >= XL) And (i <= XH) And (j >= YL) And (j <= YH) Then
          PutCell(i, j, ' ', TextAttr)
        Else
          VPutCell(i, j, OScrn[j][i]);
        End;
  End;


Procedure ShowBlock(XL, YL, XH, YH, CX, CY: Byte; Var MRect: ScreenCopy);
  {the block, its colours reversed, at CX,CY}
  Var
    i, j: Word;
    W: Word;

  Begin
  For j := CY To CY + YH - YL Do
    For i := CX To CX + XH - XL Do
      If (i <= ScrW) And (j <= ScrH) Then
        Begin
        W := MRect[j + 1 - CY][i + 1 - CX];
        PutCell(i, j, Chr(W And $FF), SwapNibbles(W Shr 8));
        End;
  End;


Procedure DoMoveCopy(Moving: Boolean);
  Var
    XL, YL, XH, YH: Byte;
    i, j: Word;
    OScrn, MRect: PScreenCopy;
    MWidth, MHeight: Word;
    Done: Boolean;
    Cmd: Word;
    Ch: Char;
    MX, MY, X, Y: Integer;

  Begin
  New(OScrn);
  New(MRect);
  FillChar(OScrn^, SizeOf(OScrn^), 0);
  FillChar(MRect^, SizeOf(MRect^), 0);
  If GetRect(XL, YL, XH, YH) Then
    Begin
    MWidth := XH + 1 - XL;
    MHeight := YH + 1 - YL;
    For j := 1 To ScrH Do
      For i := 1 To ScrW Do
        OScrn^[j][i] := VGetCell(i, j);
    For j := YL To YH Do
      For i := XL To XH Do
        MRect^[j + 1 - YL][i + 1 - XL] := VGetCell(i, j);
    GotoXY(XL, YL);
    SetMsg('Move the block with the arrow keys, Enter puts it down, Esc = cancel');
    Done := False;
    While Not Done Do
      Begin
      ShowBlock(XL, YL, XH, YH, WhereX, WhereY, MRect^);
      Refresh;
      Cmd := ReadCmd(Ch, MX, MY);
      If (Cmd = ccChar) And (Ch = ' ') Then
        Cmd := ccSelect;
      RestoreScrn(XL, YL, XH, YH, WhereX, WhereY, Moving, OScrn^);
      X := WhereX;
      Y := WhereY;
      Case Cmd Of
        ccQuit:
          Begin
          RestoreScrn(XL, YL, XH, YH, WhereX, WhereY, False, OScrn^);
          RestoreScrn(XL, YL, XH, YH, XL, YL, False, OScrn^);
          Done := True;
          End;
        ccLeft: If X > 1 Then SetCursorTo(X - 1, Y) Else SetCursorTo(ScrW, Y);
        ccUp: SetCursorTo(X, Y - 1);
        ccDown: SetCursorTo(X, Y + 1);
        ccTab: If X < 72 Then SetCursorTo((X + 8) And $F8, Y) Else SetCursorTo(79, Y);
        ccBackTab: If X > 8 Then SetCursorTo((X - 1) And $F8, Y) Else SetCursorTo(1, Y);
        ccRight: If X < ScrW Then SetCursorTo(X + 1, Y) Else SetCursorTo(1, Y);
        ccHome: SetCursorTo(1, Y);
        ccEnd: SetCursorTo(ScrW, Y);
        ccPgUp: SetCursorTo(X, 1);
        ccPgDn: SetCursorTo(X, ScrH);
        ccMouseSel, ccSelect:
          Begin
          If Cmd = ccMouseSel Then
            Begin
            If (MX = X) And (MY = Y) Then
              Cmd := ccSelect
            Else
              SetCursorTo(MX, MY);
            End;
          If Cmd = ccSelect Then
            Begin
            Done := True;
            ShowBlock(XL, YL, XH, YH, WhereX, WhereY, MRect^);
            ReverseRect(WhereX, WhereY, MWidth + WhereX - 1, MHeight + WhereY - 1);
            LXL := WhereX;
            LYL := WhereY;
            LXH := LXL + MWidth - 1;
            LYH := LYL + MHeight - 1;
            End;
          End;
        End;
      End;
    SetMsg('');
    End;
  Dispose(MRect);
  Dispose(OScrn);
  End;


Procedure InsertLine;
  Var
    i, j: Word;
    Y: Word;

  Begin
  Y := WhereY;
  i := ScrH;
  While i > Y Do
    Begin
    For j := 1 To ScrW Do
      VPutCell(j, i, VGetCell(j, i - 1));
    Dec(i);
    End;
  For j := 1 To ScrW Do
    PutCell(j, Y, ' ', TextAttr);
  End;


Procedure DeleteLine;
  Var
    i, j: Word;

  Begin
  i := WhereY;
  While i < ScrH Do
    Begin
    For j := 1 To ScrW Do
      VPutCell(j, i, VGetCell(j, i + 1));
    Inc(i);
    End;
  For j := 1 To ScrW Do
    PutCell(j, ScrH, ' ', TextAttr);
  End;


Procedure DeleteChar;
  Var
    i: Word;
    X, Y: Word;

  Begin
  X := WhereX;
  Y := WhereY;
  For i := X To ScrW - 1 Do
    VPutCell(i, Y, VGetCell(i + 1, Y));
  PutCell(ScrW, Y, ' ', TextAttr);
  End;


Procedure InsertStr(S: String);
  Var
    L, i: Integer;
    X, Y: Integer;

  Begin
  X := WhereX;
  Y := WhereY;
  L := ScrW + 1 - X;
  If Length(S) < L Then
    L := Length(S);
  i := ScrW;
  While i >= X + L Do
    Begin
    VPutCell(i, Y, VGetCell(i - L, Y));
    Dec(i);
    End;
  PutStr(Copy(S, 1, L));
  End;


Procedure WriteStr(S: String);
  Begin
  If InsertMode Then
    InsertStr(S)
  Else
    PutStr(S);
  End;


Procedure ShowHelp;
  Begin
  ShowText('Command Keys for MKDraw',
    'Alt-A  Color/attribute select      Alt-F1..F10  Select character set 1-10' + #13 +
    'Alt-B  Blinking toggle             Ctrl-F1..F5  Select character set 11-15' + #13 +
    'Alt-C  Copy area                   Alt-1..Alt-9 Select character set 1-9' + #13 +
    'Alt-D  Drawing mode                F1..F10      Enter special character' + #13 +
    'Alt-E  Enclose in frame            Home / End   Beginning / end of line' + #13 +
    'Alt-F  Attribute fill area         PgUp / PgDn  Top / bottom of screen' + #13 +
    'Alt-G  Get extended character set  Arrow keys   Move the cursor (draws in drawing mode)' + #13 +
    'Alt-H  Help                        Tab          Next tab stop' + #13 +
    'Alt-I  Intensity toggle            Del          Delete character' + #13 +
    'Alt-L  Load screen                 Ins          Toggle insert mode' + #13 +
    'Alt-M  Move area                   Bksp         Delete the character to the left' + #13 +
    'Alt-P  Pick BBS code               Ctrl-A..Z    Enter that control code' + #13 +
    'Alt-R  Reverse attribute           Esc          Fast menu: every command' + #13 +
    'Alt-S  Save screen area            Right click  Esc' + #13 +
    'Alt-U  Color under cursor          Left click   Move the cursor' + #13 +
    'Alt-V  Insert line' + #13 +
    'Alt-W  Double image' + #13 +
    'Alt-X  Exit' + #13 +
    'Alt-Y  Delete line' + #13 +
    'Alt-Z  Zap/clear area');
  End;


Procedure CmdProcess(Cmd: Word; Ch: Char; MX, MY: Integer);
  Var
    Tmp: Word;
    TmpStr: String;
    X, Y: Integer;
    A: Byte;

  Begin
  X := WhereX;
  Y := WhereY;
  Case Cmd Of
    ccLeft:
      Begin
      PutDrawChar(X, Y, 1);
      If X > 1 Then SetCursorTo(X - 1, Y) Else SetCursorTo(ScrW, Y);
      End;
    ccUp:
      Begin
      PutDrawChar(X, Y, 4);
      SetCursorTo(X, Y - 1);
      End;
    ccDown:
      Begin
      PutDrawChar(X, Y, 3);
      SetCursorTo(X, Y + 1);
      End;
    ccRight:
      Begin
      PutDrawChar(X, Y, 2);
      If X < ScrW Then SetCursorTo(X + 1, Y) Else SetCursorTo(1, Y);
      End;
    ccHome: SetCursorTo(1, Y);
    ccEnd: SetCursorTo(ScrW, Y);
    ccDel: DeleteChar;
    ccIns: InsertMode := Not InsertMode;
    ccTab: If X < 72 Then SetCursorTo((X + 8) And $F8, Y) Else SetCursorTo(79, Y);
    ccBackTab: If X > 8 Then SetCursorTo((X - 1) And $F8, Y) Else SetCursorTo(1, Y);
    ccSelect: SetCursorTo(1, Y + 1);
    ccPgUp: SetCursorTo(X, 1);
    ccPgDn: SetCursorTo(X, ScrH);
    ccBack:
      Begin
      If InsertMode Then
        Begin
        If X > 1 Then
          Begin
          SetCursorTo(X - 1, Y);
          DeleteChar;
          End;
        End
      Else
        Begin
        If X > 1 Then
          SetCursorTo(X - 1, Y);
        PutCell(WhereX, WhereY, ' ', TextAttr);
        End;
      End;
    ccMouseSel: SetCursorTo(MX, MY);
    cmSave: SaveFile;
    cmHelp: ShowHelp;
    cmAttrPick: PickAttr('[ Pick Color ]', TextAttr);
    cmUnder: TextAttr := CellAttr(X, Y);
    cmBlink: TextAttr := TextAttr Xor $80;
    cmLoad: GetLoadFile;
    cmClear: DoClear;
    cmFill: DoAttr;
    cmMove: DoMoveCopy(True);
    cmCopy: DoMoveCopy(False);
    cmReverse: TextAttr := SwapNibbles(TextAttr);
    cmIntens: TextAttr := TextAttr Xor $08;
    cmBbsCode:
      Begin
      TmpStr := GetBbsStr;
      If TmpStr <> '' Then
        WriteStr(TmpStr);
      End;
    cmGetSet: GetPickChar;
    cmInsLine: InsertLine;
    cmDelLine: DeleteLine;
    cmDrawMode: GetDrawSet(DrawSet);
    cmEnclose: DoEnclose;
    cmDouble: DoDouble;
    ccQuit:
      Begin
      Tmp := GetMenuCmd;
      If Tmp <> cmNone Then
        CmdProcess(Tmp, #0, 0, 0);
      End;
    cmExitDraw: Finished := DoYesNo('[ Exit MKDraw ]', True) = 1;
    ccChar: WriteStr(Ch);
    Else
      Begin
      If (Cmd > ccSlot) And (Cmd <= ccSlot + CharsInSet) Then
        WriteStr(ExtChars[CurrSet][Cmd - ccSlot])
      Else If (Cmd > ccSet) And (Cmd <= ccSet + 15) Then
        CurrSet := Cmd - ccSet;
      End;
    End;
  End;


{------------------------------------------------ the application}

Type
  DrawApp = Object(TApplication)
    Procedure InitMenuBar; Virtual;
    Procedure InitStatusLine; Virtual;
    End;


Procedure DrawApp.InitMenuBar;
  Begin
  End;


Procedure DrawApp.InitStatusLine;
  Begin
  End;


Var
  A: DrawApp;
  R: TRect;
  Cmd: Word;
  Ch: Char;
  MX, MY: Integer;
  i: Word;
  Arg, Chosen: String;
  D: DirStr;
  N: NameStr;
  E: ExtStr;

Begin
UseGuard := True;
Arg := '';
For i := 1 To ParamCount Do
  Begin
  If ParamStr(i) = '-n' Then
    UseGuard := False
  Else If (Arg = '') And ((Length(ParamStr(i)) = 0) Or (ParamStr(i)[1] <> '-')) Then
    Arg := ParamStr(i)
  Else
    Begin
    WriteLn(StdErr, 'Usage: mkdraw [-n] [FileName]');
    Halt(3);
    End;
  End;
MsgBoxTitle := 'MKDraw';
LoadExtChars;
InitCustCodes;
InstallKeyboard;
MaroonOn;
A.Init;
If (ScreenWidth < ScrW) Or (ScreenHeight < ScrH + 2) Then
  Begin
  A.Done;
  MaroonOff;
  WriteLn(StdErr, 'MKDraw needs a terminal of at least 80 x 25 characters');
  Halt(2);
  End;
SetScreenSize(ScrW, ScrH);
TextAttr := Cyan;
ClrScr;
InsertMode := False;
DrawSet := 5;
LXL := 1;
LYL := 1;
LXH := 1;
LYH := 1;
StatusMsg := '';
R.Assign(0, 0, ScrW, 2);
Stat := New(PStatusView, Init(R));
DeskTop^.Insert(Stat);
R.Assign(0, 2, ScrW, 2 + ScrH);
Cv := New(PCanvasView, Init(R));
DeskTop^.Insert(Cv);
Cv^.Select;
Cv^.SetState(sfCursorVis, True);
Cv^.SetState(sfCursorIns, True);          {a block}
If Arg <> '' Then
  CurrFile := FExpand(Arg)
Else
  Begin
  GetDir(0, D);
  CurrFile := WithBackSlash(D) + '*.a*';
  End;
If IsWild(CurrFile) Then
  Begin
  If PickScreenFile(CurrFile, Chosen) Then
    CurrFile := Chosen
  Else
    Begin
    FSplit(CurrFile, D, N, E);
    CurrFile := D;
    End;
  End;
If (CurrFile <> '') And (CurrFile[Length(CurrFile)] <> '/') And FileExist(CurrFile) Then
  LoadScreen(CurrFile);
Finished := False;
Repeat
  Refresh;
  Cmd := ReadCmd(Ch, MX, MY);
  CmdProcess(Cmd, Ch, MX, MY);
Until Finished;
DeskTop^.Delete(Cv);
DeskTop^.Delete(Stat);
Dispose(Cv, Done);
Dispose(Stat, Done);
DoneCustCodes;
A.Done;
MaroonOff;
End.
