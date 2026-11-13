Unit CfgColor;   {Colour (text attribute) picker}

{$I MKB.Def}

{
     PickColor shows the 16 foreground by 8 background combinations as a grid
     of "*"s drawn in their own colours; arrow keys, Home/End or the mouse
     move the cursor, Enter / OK takes the attribute, Escape leaves it.  It has
     the signature the forms use for F2 on a field (CfgForm.OnF2); Data points
     to the attribute byte.
}

Interface

Procedure PickColor(Data: Pointer; Title: String);

Implementation

Uses Objects, Drivers, Views, Dialogs, App, CfgForm;

Type
  PAttrGrid = ^AttrGrid;
  AttrGrid = Object(TView)
    FgNo, BgNo: Byte;                    {Selected cell}
    Constructor Init(Var R: TRect; Attr: Byte);
    Procedure Draw; Virtual;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Function  Attr: Byte;
    End;


Constructor AttrGrid.Init(Var R: TRect; Attr: Byte);
  Begin
  Inherited Init(R);
  Options := Options Or ofSelectable Or ofFirstClick;
  FgNo := Attr And 15;
  BgNo := (Attr Shr 4) And 7;
  End;


Function AttrGrid.Attr: Byte;
  Begin
  Attr := (BgNo Shl 4) Or FgNo;
  End;


Procedure AttrGrid.Draw;
  Var
    B: TDrawBuffer;
    Row, Col: Byte;
    A: Byte;
    S: String;

  Begin
  For Row := 0 To 15 Do
    Begin
    For Col := 0 To 7 Do
      Begin
      A := (Col Shl 4) Or Row;
      If (Row = FgNo) And (Col = BgNo) Then
        S := '[*]'
      Else
        S := ' * ';
      MoveStr(B[Col * 4], S + ' ', A);
      End;
    WriteLine(0, Row, 32, 1, B);
    End;
  End;


Procedure AttrGrid.HandleEvent(Var Event: TEvent);
  Var
    P: TPoint;

  Begin
  Inherited HandleEvent(Event);
  Case Event.What Of
    evKeyDown:
      Begin
      Case Event.KeyCode Of
        kbUp: FgNo := (FgNo - 1) And 15;
        kbDown: FgNo := (FgNo + 1) And 15;
        kbLeft: BgNo := (BgNo - 1) And 7;
        kbRight: BgNo := (BgNo + 1) And 7;
        kbHome: Begin FgNo := 0; BgNo := 0; End;
        kbEnd: Begin FgNo := 15; BgNo := 7; End;
        Else Exit;
        End;
      DrawView;
      ClearEvent(Event);
      End;
    evMouseDown:
      Begin
      MakeLocal(Event.Where, P);
      If (P.X >= 0) And (P.X < 32) And (P.Y >= 0) And (P.Y < 16) Then
        Begin
        BgNo := P.X Div 4;
        FgNo := P.Y;
        DrawView;
        End;
      ClearEvent(Event);
      End;
    End;
  End;


Procedure PickColor(Data: Pointer; Title: String);
  Var
    D: PDialog;
    G: PAttrGrid;
    R: TRect;

  Begin
  R.Assign(0, 0, 36, 22);
  New(D, Init(R, 'Select Color'));
  D^.Options := D^.Options Or ofCentered;
  R.Assign(2, 1, 34, 17);
  G := New(PAttrGrid, Init(R, Byte(Data^)));
  D^.Insert(G);
  R.Assign(2, 18, 12, 20);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  R.Assign(14, 18, 26, 20);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  D^.SelectNext(False);
  If Application^.ExecView(D) = cmOK Then
    Byte(Data^) := G^.Attr;
  Dispose(D, Done);
  End;


End.
