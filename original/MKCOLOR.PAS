{$I MKB.DEF}
Unit MkColor;

Interface
uses
  OpCrt, OpFrame, OpWindow, OpEntry;

Var
  ColorEsc: Boolean;

Function ColorPick(Cx:byte; Cy:byte; CC:byte; Title: String):Byte;
Procedure GetColor(Var Color: Byte; Var ESP: EntryScreenPtr;
  ScreenNo: Word; Title: String);

Implementation

Uses OpMouse, OpString, OpRoot, OpCmd, OpColor;

var
  W1: RawWindow;
  W2: RawWindow;
  CurrX, CurrY: Byte;
  WinX, WinY: Byte;
  KW: Word;
  CCX, CCY: Byte;



Procedure GetColor(Var Color: Byte; Var ESP: EntryScreenPtr;
  ScreenNo: Word; Title: String);

  Var
    Temp: Word;

  Const
    Wait = 100;

  Begin
  Delay(Wait);
  ESP^.PositionCursorAt(ESP^.FindField(ScreenNo));
  HideMouse;
  Temp := ReadKeyWord;
    Case Temp of
    7181: Begin
          If WhereX < 35 Then
            Color := ColorPick(WhereX + 12, 5, Color, Title)
          Else
            Color := ColorPick(WhereX - 32, 5, Color, Title);
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure DrawColors;
Var
  TempX: Byte;
  TempY: Byte;

Begin
  For TempX := 0 to 7 Do
    Begin
    For TempY := 0 to 15 Do
      Begin
      TextAttr := (TempX Shl 4) + TempY;
      GoToXy( ((TempX) Shl 2) + 2, TempY + 2);
      Write( ' * ');
      End;
    End;
  End;


Procedure SetCoor;
  Begin
  WinX := CurrX Shl 2 + CCx;
  WinY := CurrY + CCy;
  End;


Procedure MoveColor;
  Const
    KeyMax = 150;
    MouseChar = #4;

  Var
    DoneColor: Boolean;
    Commands: CommandProcessor;
    KeySet: Array[0..KeyMax] of Byte;
    Key: Word;
    Cmd: Word;
    TmpX, TmpY: Integer;


  Begin
  FillChar(KeySet, SizeOf(KeySet), #0);
  Commands.Init(@KeySet, KeyMax);
  Commands.cpOptionsOn(cpCtrlsAreChars);
  If MouseInstalled Then
    begin
    SoftMouseCursor($0000, (ColorMono(WhiteOnRed,
      BlackOnLtGray) shl 8) + Byte(MouseChar));
    ShowMouse;
    Commands.cpOptionsOn(cpEnableMouse);
    Commands.AddCommand(ccQuit, 1, MouseRt, 0);
    Commands.AddCommand(ccMouseSel, 1, MouseLft, 0);
    End;
  Commands.AddCommand(ccSelect, 1, $000d, 0);   {Enter}
  Commands.AddCommand(ccQuit,   1, $001b, 0);   {Esc}
  Commands.AddCommand(ccUp,     1, $4800, 0);   {Up}
  Commands.AddCommand(ccDown,   1, $5000, 0);   {Down}
  Commands.AddCommand(ccLeft,   1, $4b00, 0);   {Left}
  Commands.AddCommand(ccRight,  1, $4d00, 0);   {Right}
  Commands.AddCommand(ccHome,   1, $4700, 0);   {Home}
  Commands.AddCommand(ccEnd,    1, $4f00, 0);   {End}
  DoneColor := False;
  While Not DoneColor Do
    Begin
    Cmd := Commands.GetCommand(Key);
    Case Cmd of
    ccQuit:   Begin
           DoneColor := True;
           ColorEsc := True;
           End;
    ccSelect:  DoneColor := True;
    ccMouseSel:
       Begin
       TmpX := ((MouseWhereXAbs - CCX) Div 4);
       TmpY := ((MouseWhereYAbs - CCY) - 1);
       If ((TmpX = CurrX) and (TmpY = CurrY)) Then
         DoneColor := True
       Else
         Begin
         If ((TmpX < 8) and (TmpX >= 0) and (TmpY < 16) and (TmpY >= 0)) Then
           Begin
           CurrX := TmpX;
           CurrY := TmpY;
           End;
         End;
       End;
    ccHome: Begin
           CurrX := 0;
           CurrY := 0;
           End;
    ccEnd: Begin
           CurrX := 7;
           CurrY := 15;
           End;
    ccUp: CurrY := (CurrY - 1) And 15;
    ccDown: CurrY := (CurrY + 1) And 15;
    ccLeft: CurrX := (CurrX - 1) And 7;
    ccRight: CurrX := (CurrX + 1) And 7;
    Else
      Writeln(#7);
    End;
    SetCoor;
    W2.AdjustWindow(WinX + 1, WinY + 1, WinX + 3,WinY + 1);
    End;
  Commands.Done;
  End;


Function ColorPick(Cx:byte;Cy:byte;CC:byte; Title: String):Byte;
  Begin
  ColorEsc := False;
  CCX := Cx;
  CCY := Cy;
  W1.InitCustom(Cx, Cy, Cx+32, Cy+17, DefaultColorSet,
  wClear + wBordered);
  W1.EnableExplosions(3);
  W1.wFrame.AddHeader(Title, heTC);
  CurrX := ((CC shr 4) and 7);
  CurrY := (CC and 15);
  SetCoor;
  W2.InitCustom( WinX + 1, WinY + 1, WinX + 3,
  WinY + 1, DefaultColorSet, wBordered);
  W1.SetCursor(cuHidden);
  W2.SetCursor(cuHidden);
  W2.wFrame.SetFrameType(SglWindowFrame);
  W1.Draw;
  DrawColors;
  W2.Draw;
  MoveColor;
  If ColorEsc Then
    ColorPick := CC
  else
    ColorPick := (CurrX Shl 4) + CurrY;
  W2.Erase;
  W1.Erase;
  W2.Done;
  W1.Done;
  End;

End.
