Unit MKVCrt;   {Virtual console: the Crt calls on an in-memory screen}

{$I MKB.Def}

{
     MKVCrt replaces the Crt unit and the PC video hardware (video memory,
     BIOS INT 10h) for the MK units.  The screen is a character/attribute
     buffer in memory, so it works the same with no terminal at all: in a
     Telnet or SSH session server, under inetd, or in a test.  Nothing is
     drawn anywhere; whoever wants to show or snoop the screen reads the
     buffer (VScreen) - one Word per cell, low byte = character, high byte =
     attribute, like PC text mode.

     The calls behave like Turbo Pascal's Crt: window relative coordinates,
     TextAttr, WindMin/WindMax, scrolling inside the window, a Write device
     (VOut) that interprets #7 #8 #10 #13.  The "local keyboard" is a key
     queue: whoever has local input pushes it with PushKey, KeyPressed and
     ReadKey take it out (a function key is #0 followed by its scan code).
     There is no speaker: Sound and NoSound only remember the pitch and call
     OnSound if one is set.
}


Interface


Const
  Black = 0;  Blue = 1;  Green = 2;  Cyan = 3;  Red = 4;  Magenta = 5;
  Brown = 6;  LightGray = 7;  DarkGray = 8;  LightBlue = 9;  LightGreen = 10;
  LightCyan = 11;  LightRed = 12;  LightMagenta = 13;  Yellow = 14;
  White = 15;  Blink = 128;

  MaxCells = 8192;                     {Most cells a screen can have}


Type
  TVScreen = Array[0..MaxCells - 1] Of Word;
  PVScreen = ^TVScreen;
  TSoundHook = Procedure(Hz: Word);
  TScreenHook = Procedure;


Var
  VScreen: PVScreen;                   {The screen: char + attr shl 8}
  VCols: Byte;                         {Columns}
  VRows: Byte;                         {Rows}
  TextAttr: Byte;                      {Current attribute}
  WindMin: Word;                       {Window upper left, 0 based: x + y shl 8}
  WindMax: Word;                       {Window lower right}
  CheckBreak: Boolean;
  CheckEOF: Boolean;
  CheckSnow: Boolean;
  DirectVideo: Boolean;
  VOut: Text;                          {Write(VOut, ...) draws on the screen}
  SoundHz: Word;                       {Pitch last asked for, 0 = silent}
  OnSound: TSoundHook;                 {Called by Sound / NoSound if set}
  OnScreenSize: TScreenHook;           {Called when the size changes}


Procedure SetScreenSize(Cols, Rows: Byte);
Procedure ClrScr;
Procedure ClrEol;
Procedure GotoXY(X, Y: Byte);
Function  WhereX: Byte;
Function  WhereY: Byte;
Procedure Window(X1, Y1, X2, Y2: Byte);
Procedure TextColor(Color: Byte);
Procedure TextBackground(Color: Byte);
Procedure NormVideo;
Procedure HighVideo;
Procedure LowVideo;
Procedure InsLine;
Procedure DelLine;
Procedure AssignVCrt(Var F: Text);

Function  VGetCell(X, Y: Byte): Word;           {Absolute 1 based}
Procedure VPutCell(X, Y: Byte; Cell: Word);
Procedure VGotoAbs(X, Y: Byte);                 {Cursor, absolute 1 based}
Procedure VWhereAbs(Var X, Y: Byte);
Procedure VScroll(XL, YL, XH, YH, Count: Byte; Up: Boolean);
  {Scroll an absolute region, Count 0 clears it}

Function  KeyPressed: Boolean;
Function  ReadKey: Char;
Procedure PushKey(Ch: Char);
Procedure PushKeyStr(S: String);
Procedure Delay(Ms: Word);
Procedure Sound(Hz: Word);
Procedure NoSound;


Implementation


Uses MKPlat;


Const
  KeyQueueSize = 256;

Var
  CurX: Byte;                          {Cursor, absolute 1 based}
  CurY: Byte;
  KeyQueue: Array[0..KeyQueueSize - 1] Of Char;
  KeyHead: Word;
  KeyCount: Word;


Function Blank: Word;
  Begin
  Blank := 32 + (Word(TextAttr) Shl 8);
  End;


Function WinX1: Byte;
  Begin
  WinX1 := Lo(WindMin) + 1;
  End;


Function WinY1: Byte;
  Begin
  WinY1 := Hi(WindMin) + 1;
  End;


Function WinX2: Byte;
  Begin
  WinX2 := Lo(WindMax) + 1;
  End;


Function WinY2: Byte;
  Begin
  WinY2 := Hi(WindMax) + 1;
  End;


Function VGetCell(X, Y: Byte): Word;
  Begin
  If (X >= 1) And (X <= VCols) And (Y >= 1) And (Y <= VRows) Then
    VGetCell := VScreen^[(Y - 1) * VCols + (X - 1)]
  Else
    VGetCell := $0720;
  End;


Procedure VPutCell(X, Y: Byte; Cell: Word);
  Begin
  If (X >= 1) And (X <= VCols) And (Y >= 1) And (Y <= VRows) Then
    VScreen^[(Y - 1) * VCols + (X - 1)] := Cell;
  End;


Procedure VGotoAbs(X, Y: Byte);
  Begin
  If X < 1 Then X := 1;
  If Y < 1 Then Y := 1;
  If X > VCols Then X := VCols;
  If Y > VRows Then Y := VRows;
  CurX := X;
  CurY := Y;
  End;


Procedure VWhereAbs(Var X, Y: Byte);
  Begin
  X := CurX;
  Y := CurY;
  End;


Procedure VScroll(XL, YL, XH, YH, Count: Byte; Up: Boolean);
  Var
    X: Byte;
    Y: Byte;
    N: Byte;

  Begin
  If XH > VCols Then XH := VCols;
  If YH > VRows Then YH := VRows;
  If (XL < 1) Or (YL < 1) Or (XL > XH) Or (YL > YH) Then
    Exit;
  N := YH - YL + 1;
  If (Count = 0) Or (Count >= N) Then
    Begin                                {clear the region}
    For Y := YL To YH Do
      For X := XL To XH Do
        VPutCell(X, Y, Blank);
    Exit;
    End;
  If Up Then
    Begin
    For Y := YL To YH - Count Do
      For X := XL To XH Do
        VPutCell(X, Y, VGetCell(X, Y + Count));
    For Y := YH - Count + 1 To YH Do
      For X := XL To XH Do
        VPutCell(X, Y, Blank);
    End
  Else
    Begin
    For Y := YH DownTo YL + Count Do
      For X := XL To XH Do
        VPutCell(X, Y, VGetCell(X, Y - Count));
    For Y := YL To YL + Count - 1 Do
      For X := XL To XH Do
        VPutCell(X, Y, Blank);
    End;
  End;


Procedure SetScreenSize(Cols, Rows: Byte);
  Begin
  If Cols < 40 Then Cols := 40;
  If Cols > 132 Then Cols := 132;
  If Rows < 8 Then Rows := 8;
  If Rows > 66 Then Rows := 66;
  While Cols * Rows > MaxCells Do
    Dec(Rows);
  VCols := Cols;
  VRows := Rows;
  WindMin := 0;
  WindMax := (VCols - 1) + ((VRows - 1) Shl 8);
  CurX := 1;
  CurY := 1;
  FillChar(VScreen^, SizeOf(VScreen^), 0);
  VScroll(1, 1, VCols, VRows, 0, True);
  If Assigned(OnScreenSize) Then
    OnScreenSize;
  End;


Procedure ClrScr;
  Begin
  VScroll(WinX1, WinY1, WinX2, WinY2, 0, True);
  CurX := WinX1;
  CurY := WinY1;
  End;


Procedure ClrEol;
  Var
    X: Byte;

  Begin
  For X := CurX To WinX2 Do
    VPutCell(X, CurY, Blank);
  End;


Procedure GotoXY(X, Y: Byte);
  Begin
  If (X >= 1) And (Y >= 1) And (X <= WinX2 - WinX1 + 1) And (Y <= WinY2 - WinY1 + 1) Then
    Begin
    CurX := X + WinX1 - 1;
    CurY := Y + WinY1 - 1;
    End;
  End;


Function WhereX: Byte;
  Begin
  WhereX := CurX - WinX1 + 1;
  End;


Function WhereY: Byte;
  Begin
  WhereY := CurY - WinY1 + 1;
  End;


Procedure Window(X1, Y1, X2, Y2: Byte);
  Begin
  If (X1 >= 1) And (Y1 >= 1) And (X1 <= X2) And (Y1 <= Y2) And (X2 <= VCols) And (Y2 <= VRows) Then
    Begin
    WindMin := (X1 - 1) + ((Y1 - 1) Shl 8);
    WindMax := (X2 - 1) + ((Y2 - 1) Shl 8);
    CurX := X1;
    CurY := Y1;
    End;
  End;


Procedure TextColor(Color: Byte);
  Begin
  TextAttr := (TextAttr And $70) Or (Color And $8F);
  End;


Procedure TextBackground(Color: Byte);
  Begin
  TextAttr := (TextAttr And $8F) Or ((Color And $07) Shl 4);
  End;


Procedure NormVideo;
  Begin
  TextAttr := $07;
  End;


Procedure HighVideo;
  Begin
  TextAttr := TextAttr Or $08;
  End;


Procedure LowVideo;
  Begin
  TextAttr := TextAttr And $F7;
  End;


Procedure InsLine;
  Begin
  VScroll(WinX1, CurY, WinX2, WinY2, 1, False);
  End;


Procedure DelLine;
  Begin
  VScroll(WinX1, CurY, WinX2, WinY2, 1, True);
  End;


{------------------------------------------------------------ the device}

Procedure LineFeed;
  Begin
  If CurY < WinY2 Then
    Inc(CurY)
  Else
    VScroll(WinX1, WinY1, WinX2, WinY2, 1, True);
  End;


Procedure PutChar(Ch: Char);
  Begin
  Case Ch Of
    #7: ;                                {bell}
    #8: If CurX > WinX1 Then Dec(CurX);
    #10: LineFeed;
    #13: CurX := WinX1;
    Else
      Begin
      VPutCell(CurX, CurY, Ord(Ch) + (Word(TextAttr) Shl 8));
      If CurX < WinX2 Then
        Inc(CurX)
      Else
        Begin
        CurX := WinX1;
        LineFeed;
        End;
      End;
    End;
  End;


Procedure VWrite(Var F: TextRec);
  Var
    i: SizeInt;

  Begin
  For i := 0 To F.BufPos - 1 Do
    PutChar(F.BufPtr^[i]);
  F.BufPos := 0;
  End;


Procedure VRead(Var F: TextRec);
  {Reading from the screen device is not possible: end of file}
  Begin
  F.BufPos := 0;
  F.BufEnd := 0;
  End;


Procedure VNothing(Var F: TextRec);
  Begin
  End;


Procedure VClose(Var F: TextRec);
  Begin
  F.Mode := fmClosed;
  End;


Procedure VOpen(Var F: TextRec);
  Begin
  If F.Mode = fmOutput Then
    Begin
    F.InOutFunc := @VWrite;
    F.FlushFunc := @VWrite;
    End
  Else
    Begin
    F.Mode := fmInput;
    F.InOutFunc := @VRead;
    F.FlushFunc := @VNothing;
    End;
  F.CloseFunc := @VClose;
  End;


Procedure AssignVCrt(Var F: Text);
  Begin
  Assign(F, '');
  TextRec(F).OpenFunc := @VOpen;
  TextRec(F).LineEnd := #13#10;          {WriteLn is CR LF, as in the PC Crt}
  End;


{----------------------------------------------------- keyboard, sound}

Procedure PushKey(Ch: Char);
  Begin
  If KeyCount < KeyQueueSize Then
    Begin
    KeyQueue[(KeyHead + KeyCount) Mod KeyQueueSize] := Ch;
    Inc(KeyCount);
    End;
  End;


Procedure PushKeyStr(S: String);
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    PushKey(S[i]);
  End;


Function KeyPressed: Boolean;
  Begin
  KeyPressed := (KeyCount > 0);
  End;


Function ReadKey: Char;
  {Waits for a key, like Crt.ReadKey.  Nothing fills the queue by itself: only
   call it after KeyPressed unless another thread pushes keys.}
  Begin
  While KeyCount = 0 Do
    MKDelay(10);
  ReadKey := KeyQueue[KeyHead];
  KeyHead := (KeyHead + 1) Mod KeyQueueSize;
  Dec(KeyCount);
  End;


Procedure Delay(Ms: Word);
  Begin
  MKDelay(Ms);
  End;


Procedure Sound(Hz: Word);
  Begin
  SoundHz := Hz;
  If Assigned(OnSound) Then
    OnSound(Hz);
  End;


Procedure NoSound;
  Begin
  SoundHz := 0;
  If Assigned(OnSound) Then
    OnSound(0);
  End;


Begin
  GetMem(VScreen, SizeOf(TVScreen));
  FillChar(VScreen^, SizeOf(TVScreen), 0);
  VCols := 80;
  VRows := 25;
  TextAttr := $07;
  CheckBreak := False;
  CheckEOF := False;
  CheckSnow := False;
  DirectVideo := True;
  SoundHz := 0;
  OnSound := Nil;
  OnScreenSize := Nil;
  KeyHead := 0;
  KeyCount := 0;
  SetScreenSize(80, 25);
  AssignVCrt(VOut);
  Rewrite(VOut);
End.
