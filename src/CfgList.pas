Unit CfgList;   {Numbered lists of things to edit (languages, areas, addresses ...)}

{$I MKB.Def}

{
     RunList shows items 1..Count, one line each (the text comes from GetStr),
     in a scrolling Free Vision list.  Enter, Space or a double click calls Edit
     for the item under the bar and the list is drawn again afterwards; Escape or
     Close leaves.  Replaces the Object Professional PickList screens.

     RunChecks shows a few fixed choices as check boxes (the "available offline
     types" screen); the marks are taken from and given back in Marked.
}

Interface

Type
  CfgItemStr = Function(Item: Word): String;
  CfgItemEdit = Procedure(Item: Word);
  CfgMarks = Array[1..32] Of Boolean;

Procedure RunList(Title: String; Count: Word; Width: Byte; GetStr: CfgItemStr;
  Edit: CfgItemEdit);

Function RunChecks(Title: String; Names: String; Var Marked: CfgMarks): Boolean;
  {Names: the choices separated by '|'.  True when OK was chosen.}

Type
  CfgBigMarks = Array[1..500] Of Boolean;

Function RunMarkList(Title: String; Count: Word; Width: Byte; GetStr: CfgItemStr;
  Var Marked: CfgBigMarks): Boolean;
  {Items 1..Count (at most 500) with a mark each; Enter, Space or a click toggle
   the mark.  True when OK was chosen (Marked then holds the result).}

Implementation

Uses Objects, Drivers, Views, Dialogs, App;

Type
  PItemList = ^ItemList;
  ItemList = Object(TListViewer)
    Get: CfgItemStr;
    Constructor Init(Var R: TRect; ACount: Word; AScroll: PScrollBar; AGet: CfgItemStr);
    Function  GetText(Item: LongInt; MaxLen: LongInt): String; Virtual;
    Procedure SelectItem(Item: LongInt); Virtual;
    End;


Constructor ItemList.Init(Var R: TRect; ACount: Word; AScroll: PScrollBar;
  AGet: CfgItemStr);
  Begin
  Inherited Init(R, 1, Nil, AScroll);
  Get := AGet;
  SetRange(ACount);
  End;


Function ItemList.GetText(Item: LongInt; MaxLen: LongInt): String;
  Begin
  GetText := Copy(Get(Item + 1), 1, MaxLen);
  End;


Procedure ItemList.SelectItem(Item: LongInt);
  Begin
  Inherited SelectItem(Item);
  Message(Owner, evCommand, cmOK, @Self);     {same as the Edit button}
  End;


Type
  PMarkList = ^MarkList;
  MarkList = Object(ItemList)
    Marks: ^CfgBigMarks;
    Function  GetText(Item: LongInt; MaxLen: LongInt): String; Virtual;
    Procedure SelectItem(Item: LongInt); Virtual;
    End;

Function MarkList.GetText(Item: LongInt; MaxLen: LongInt): String;
  Begin
  If Marks^[Item + 1] Then
    GetText := Copy('[*] ' + Get(Item + 1), 1, MaxLen)
  Else
    GetText := Copy('[ ] ' + Get(Item + 1), 1, MaxLen);
  End;

Procedure MarkList.SelectItem(Item: LongInt);
  Begin
  Marks^[Item + 1] := Not Marks^[Item + 1];
  DrawView;
  End;


Function RunMarkList(Title: String; Count: Word; Width: Byte; GetStr: CfgItemStr;
  Var Marked: CfgBigMarks): Boolean;
  Var
    D: PDialog;
    L: PMarkList;
    SB: PScrollBar;
    R: TRect;
    W, H, Rows: Integer;
    DR: TRect;
    Work: CfgBigMarks;

  Begin
  RunMarkList := False;
  If (Count = 0) Or (Count > 500) Then
    Exit;
  Work := Marked;
  DeskTop^.GetExtent(DR);
  Rows := Count;
  If Rows > 14 Then
    Rows := 14;
  If Rows > DR.B.Y - 7 Then
    Rows := DR.B.Y - 7;
  W := Width + 10;
  If W < 52 Then
    W := 52;
  H := Rows + 6;
  R.Assign(0, 0, W, H);
  New(D, Init(R, Title));
  D^.Options := D^.Options Or ofCentered;
  R.Assign(W - 3, 1, W - 2, 1 + Rows);
  SB := New(PScrollBar, Init(R));
  D^.Insert(SB);
  R.Assign(2, 1, W - 3, 1 + Rows);
  L := New(PMarkList, Init(R, Count, SB, GetStr));
  L^.Marks := @Work;
  D^.Insert(L);
  R.Assign(2, H - 3, 12, H - 1);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  R.Assign(14, H - 3, 26, H - 1);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  R.Assign(28, H - 3, W - 2, H - 2);
  D^.Insert(New(PStaticText, Init(R, 'Space = mark / unmark')));
  D^.SelectNext(False);
  If Application^.ExecView(D) = cmOK Then
    Begin
    Marked := Work;
    RunMarkList := True;
    End;
  Dispose(D, Done);
  End;


Procedure RunList(Title: String; Count: Word; Width: Byte; GetStr: CfgItemStr;
  Edit: CfgItemEdit);
  Var
    D: PDialog;
    L: PItemList;
    SB: PScrollBar;
    R: TRect;
    W, H, Rows: Integer;
    DR: TRect;

  Begin
  If Count = 0 Then
    Exit;
  DeskTop^.GetExtent(DR);
  Rows := Count;
  If Rows > 14 Then
    Rows := 14;
  If Rows > DR.B.Y - 7 Then
    Rows := DR.B.Y - 7;
  W := Width + 6;
  If W < 34 Then
    W := 34;
  H := Rows + 6;
  R.Assign(0, 0, W, H);
  New(D, Init(R, Title));
  D^.Options := D^.Options Or ofCentered;
  R.Assign(W - 3, 1, W - 2, 1 + Rows);
  SB := New(PScrollBar, Init(R));
  D^.Insert(SB);
  R.Assign(2, 1, W - 3, 1 + Rows);
  L := New(PItemList, Init(R, Count, SB, GetStr));
  D^.Insert(L);
  R.Assign(2, H - 3, 14, H - 1);
  D^.Insert(New(PButton, Init(R, '~E~dit', cmOK, bfDefault)));
  R.Assign(16, H - 3, 28, H - 1);
  D^.Insert(New(PButton, Init(R, 'Close', cmCancel, bfNormal)));
  D^.SelectNext(False);
  While Application^.ExecView(D) = cmOK Do
    Begin
    Edit(L^.Focused + 1);
    L^.DrawView;
    End;
  Dispose(D, Done);
  End;


Function RunChecks(Title: String; Names: String; Var Marked: CfgMarks): Boolean;
  Var
    D: PDialog;
    C: PCheckBoxes;
    R: TRect;
    Items: PSItem;
    Part: Array[1..32] Of String[40];
    N, i, p, Longest: Integer;
    S: String;
    Value: LongInt;

  Begin
  RunChecks := False;
  S := Names;
  N := 0;
  Longest := 0;
  While (S <> '') And (N < 32) Do
    Begin
    p := Pos('|', S);
    Inc(N);
    If p = 0 Then
      Begin
      Part[N] := S;
      S := '';
      End
    Else
      Begin
      Part[N] := Copy(S, 1, p - 1);
      S := Copy(S, p + 1, 255);
      End;
    If Length(Part[N]) > Longest Then
      Longest := Length(Part[N]);
    End;
  If N = 0 Then
    Exit;
  Items := Nil;
  For i := N DownTo 1 Do
    Items := NewSItem(Part[i], Items);
  R.Assign(0, 0, Longest + 14, N + 7);
  New(D, Init(R, Title));
  D^.Options := D^.Options Or ofCentered;
  R.Assign(3, 2, Longest + 12, 2 + N);
  C := New(PCheckBoxes, Init(R, Items));
  Value := 0;
  For i := 1 To N Do
    If Marked[i] Then
      Value := Value Or (LongInt(1) Shl (i - 1));
  C^.SetData(Value);
  D^.Insert(C);
  R.Assign(2, N + 3, 12, N + 5);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  R.Assign(14, N + 3, 26, N + 5);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  D^.SelectNext(False);
  If Application^.ExecView(D) = cmOK Then
    Begin
    C^.GetData(Value);
    For i := 1 To N Do
      Marked[i] := (Value And (LongInt(1) Shl (i - 1))) <> 0;
    RunChecks := True;
    End;
  Dispose(D, Done);
  End;


End.
