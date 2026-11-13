Unit CfgForm;   {Data driven entry forms for the configuration editor (Free Vision)}

{$I MKB.Def}

{
     The Object Professional version built every screen from entry screen
     code (AddStringField ... Process).  Here a screen is a list of fields
     bound to variables; Execute puts them in a Free Vision dialog, lets the
     sysop edit them and, when OK is chosen, writes the values back:

         F.Init('System Paths');
         F.AddDir('Temp Files', UR^.TempPath, 60, 'Directory for temporary files');
         F.AddNumber('Event Slack', UR^.Slack, 1, 0, 255, 'Minutes before an event');
         F.AddYesNo('Direct Write', UR^.Direct, 'Write to video memory');
         If F.Execute Then ... values are in the variables

     Field kinds
         AddString   text (MaxLen = size of the variable)
         AddDir      a directory: backslashes become slashes, a trailing slash
                     is added
         AddFile     a file or command: backslashes become slashes
         AddNumber   Byte (Size 1), Word (2) or LongInt (4); with Min < 0 the
                     signed types Shortint, Integer and LongInt
         AddHex      a Byte (2), Word (4) or LongInt (8) typed in hexadecimal
         AddChar     one character
         AddYesNo    Boolean (a check box)
         AddText     fixed text, no variable
         AddChoice   one of a few names ('LZH|ZIP|ARC'): the variable (Size 1
                     or 2 bytes) holds First + the position; Space, + / - or
                     the arrow keys change it
         AddAction   a button that calls a procedure (for a sub screen)

     Layout.  By default the fields are listed in one column (two or three if
     the dialog would be taller than the desktop).  The screens converted from
     Object Professional keep their layout: Window gives the size of the old
     window and At the row and column of the prompt and of the field (the next
     field added is put there).  Show sets the visible width of the next field.
     Filter limits the characters of the next string field.  OnF2 attaches a
     procedure to the last field, called when F2 is pressed (colour and
     security pickers).

     The hint of the field that has the focus is shown at the bottom left.
     Execute must be called while the application is running (from an event
     handler).  Escape or Cancel leaves the variables alone.
}

Interface

Uses Objects, Drivers, Views, Dialogs, App;

Const
  MaxCfgFields = 64;
  cmCfgAction = 9000;                  {+ field number: a button of AddAction}

Type
  CfgFieldKind = (fkString, fkDir, fkFile, fkNumber, fkHex, fkChar, fkYesNo,
    fkText, fkChoice, fkAction);

  CfgProc = Procedure(Data: Pointer; Title: String);

  CfgFieldRec = Record
    Kind: CfgFieldKind;
    Lab: String[60];
    Hint: String[78];
    P: Pointer;                        {The variable}
    Size: Byte;                        {String: capacity; number: bytes}
    Min, Max: LongInt;
    Row, Col, FRow, FCol: Integer;     {0 = not placed}
    Vis: Byte;                         {Visible width, 0 = automatic}
    Filter: String[40];                {Allowed characters, '' = any}
    Proc: CfgProc;                     {F2}
    ProcData: Pointer;
    ProcTitle: String[40];
    Names: String[100];                {fkChoice: the choices, separated by |}
    View: PView;                       {Filled in by Execute}
    End;

  CfgFormObj = Object
    Title: String[80];
    Count: Word;
    WinW, WinH: Integer;
    NRow, NCol, NFRow, NFCol: Integer; {Pending placement for the next field}
    NVis: Byte;
    NFilter: String[40];
    F: Array[1..MaxCfgFields] Of CfgFieldRec;
    Constructor Init(ATitle: String);
    Procedure Window(X1, Y1, X2, Y2: Integer);
    Procedure At(Row, Col, FRow, FCol: Integer);
    Procedure Show(Width: Byte);
    Procedure Filter(Chars: String);
    Procedure OnF2(Proc: CfgProc; Data: Pointer; ProcTitle: String);
    Procedure AddString(Lab: String; Var V; MaxLen: Byte; Hint: String);
    Procedure AddDir(Lab: String; Var V; MaxLen: Byte; Hint: String);
    Procedure AddFile(Lab: String; Var V; MaxLen: Byte; Hint: String);
    Procedure AddNumber(Lab: String; Var V; Size: Byte; Min, Max: LongInt;
      Hint: String);
    Procedure AddHex(Lab: String; Var V; Size: Byte; Hint: String);
    Procedure AddChar(Lab: String; Var V; Hint: String);
    Procedure AddYesNo(Lab: String; Var V: Boolean; Hint: String);
    Procedure AddText(Text: String);
    Procedure AddChoice(Lab: String; Var V; Size: Byte; First: LongInt;
      Names: String; Hint: String);
    Procedure AddAction(Caption: String; Proc: CfgProc; Data: Pointer;
      ProcTitle: String; Hint: String);
    Function  Execute: Boolean;
    Procedure Add(K: CfgFieldKind; ALab: String; Var V; ASize: Byte;
      AMin, AMax: LongInt; AHint: String);     {Internal}
    End;

Function FixPath(S: String; IsDir: Boolean): String;
  {Backslashes to slashes, trailing slash for a directory}

Implementation

Uses MsgBox, Validate, MKString;

Type
  PCfgDialog = ^CfgDialog;
  CfgDialog = Object(TDialog)
    Form: ^CfgFormObj;
    Hint: PStaticText;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Procedure SetHint(S: String);
    Procedure Reload;                  {Variables -> input lines}
    Procedure Commit;                  {Input lines -> variables}
    End;

  PCfgInput = ^CfgInput;
  CfgInput = Object(TInputLine)
    Idx: Word;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    End;


Function FixPath(S: String; IsDir: Boolean): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    If S[i] = '\' Then
      S[i] := '/';
  If IsDir And (S <> '') Then
    AddBackSlash(S);
  FixPath := S;
  End;


Function HexDigits(L: LongInt; N: Byte): String;
  Const
    D: String[16] = '0123456789ABCDEF';
  Var
    S: String;
    i: Byte;

  Begin
  S := '';
  For i := N Downto 1 Do
    S := S + D[((L Shr ((i - 1) * 4)) And 15) + 1];
  HexDigits := S;
  End;


Function NameAt(Const Names: String; Idx: LongInt): String;
  Var
    S: String;
    p: Integer;

  Begin
  S := Names;
  While Idx > 0 Do
    Begin
    p := Pos('|', S);
    If p = 0 Then
      Begin
      NameAt := '';
      Exit;
      End;
    S := Copy(S, p + 1, 255);
    Dec(Idx);
    End;
  p := Pos('|', S);
  If p > 0 Then
    S := Copy(S, 1, p - 1);
  NameAt := S;
  End;


Function NameCount(Const Names: String): Integer;
  Var
    i, N: Integer;

  Begin
  N := 1;
  For i := 1 To Length(Names) Do
    If Names[i] = '|' Then
      Inc(N);
  NameCount := N;
  End;


Function NameLongest(Const Names: String): Integer;
  Var
    i, L: Integer;

  Begin
  L := 0;
  For i := 0 To NameCount(Names) - 1 Do
    If Length(NameAt(Names, i)) > L Then
      L := Length(NameAt(Names, i));
  NameLongest := L;
  End;


Function ChoiceValue(Const R: CfgFieldRec): LongInt;
  Begin
  If R.Size = 1 Then
    ChoiceValue := Byte(R.P^)
  Else
    ChoiceValue := Word(R.P^);
  End;


Function FieldText(Const R: CfgFieldRec): String;
  {The text of a variable as shown in its input line}
  Var
    L: LongInt;
    S: String;

  Begin
  Case R.Kind Of
    fkChoice: FieldText := NameAt(R.Names, ChoiceValue(R) - R.Min);
    fkNumber, fkHex:
      Begin
      Case R.Size Of
        1: If R.Min < 0 Then L := ShortInt(R.P^) Else L := Byte(R.P^);
        2: If R.Min < 0 Then L := Integer(R.P^) Else L := Word(R.P^);
        Else L := LongInt(R.P^);
        End;
      If R.Kind = fkHex Then
        S := HexDigits(L, R.Size * 2)
      Else
        Str(L, S);
      FieldText := S;
      End;
    fkChar: FieldText := Char(R.P^);
    Else FieldText := PString(R.P)^;
    End;
  End;


Procedure StoreText(Const R: CfgFieldRec; S: String);
  {Put the text of an input line back into the variable}
  Var
    L: LongInt;
    Code: Integer;

  Begin
  Case R.Kind Of
    fkChoice:
      Begin
      For Code := 0 To NameCount(R.Names) - 1 Do
        If NameAt(R.Names, Code) = S Then
          Begin
          L := R.Min + Code;
          If R.Size = 1 Then Byte(R.P^) := L Else Word(R.P^) := L;
          End;
      End;
    fkNumber, fkHex:
      Begin
      If R.Kind = fkHex Then
        Val('$' + S, L, Code)
      Else
        Val(S, L, Code);
      If Code <> 0 Then
        Exit;
      Case R.Size Of
        1: If R.Min < 0 Then ShortInt(R.P^) := L Else Byte(R.P^) := L;
        2: If R.Min < 0 Then Integer(R.P^) := L Else Word(R.P^) := L;
        Else LongInt(R.P^) := L;
        End;
      End;
    fkChar:
      If S = '' Then Char(R.P^) := ' ' Else Char(R.P^) := S[1];
    Else
      Begin
      S := Copy(S, 1, R.Size);
      If R.Kind <> fkString Then
        S := FixPath(S, R.Kind = fkDir);
      S := Copy(S, 1, R.Size);
      PString(R.P)^ := S;
      End;
    End;
  End;


Procedure CfgDialog.SetHint(S: String);
  Begin
  If Hint^.Text <> Nil Then
    DisposeStr(Hint^.Text);
  Hint^.Text := NewStr(S);
  Hint^.DrawView;
  End;


Procedure CfgDialog.Reload;
  Var
    i: Word;
    Want: Boolean;

  Begin
  For i := 1 To Form^.Count Do
    Case Form^.F[i].Kind Of
      fkYesNo:
        Begin
        Want := Boolean(Form^.F[i].P^);
        If PCheckBoxes(Form^.F[i].View)^.Mark(0) <> Want Then
          PCheckBoxes(Form^.F[i].View)^.Press(0);
        Form^.F[i].View^.DrawView;
        End;
      fkText, fkAction: ;
      Else
        Begin
        PInputLine(Form^.F[i].View)^.Data^ := FieldText(Form^.F[i]);
        Form^.F[i].View^.DrawView;
        End;
      End;
  End;


Procedure CfgDialog.Commit;
  Var
    i: Word;

  Begin
  For i := 1 To Form^.Count Do
    Case Form^.F[i].Kind Of
      fkYesNo: Boolean(Form^.F[i].P^) := PCheckBoxes(Form^.F[i].View)^.Mark(0);
      fkText, fkAction: ;
      Else StoreText(Form^.F[i], PInputLine(Form^.F[i].View)^.Data^);
      End;
  End;


Procedure CfgDialog.HandleEvent(Var Event: TEvent);
  Var
    i: Word;

  Begin
  Inherited HandleEvent(Event);
  If (Event.What = evCommand) And (Event.Command > cmCfgAction) And
     (Event.Command <= cmCfgAction + Form^.Count) Then
    Begin
    i := Event.Command - cmCfgAction;
    If @Form^.F[i].Proc <> Nil Then
      Begin
      Commit;
      Form^.F[i].Proc(Form^.F[i].ProcData, Form^.F[i].ProcTitle);
      Reload;
      End;
    ClearEvent(Event);
    Exit;
    End;
  If (Event.What = evBroadcast) And (Event.Command = cmReceivedFocus) Then
    Begin
    For i := 1 To Form^.Count Do
      If Form^.F[i].View = PView(Event.InfoPtr) Then
        Begin
        If @Form^.F[i].Proc <> Nil Then
          SetHint(Form^.F[i].Hint + '  (F2 = choose)')
        Else
          SetHint(Form^.F[i].Hint);
        Exit;
        End;
    SetHint('');
    End;
  End;


Procedure CfgInput.HandleEvent(Var Event: TEvent);
  Var
    D: PCfgDialog;
    N: Integer;
    V: LongInt;

  Begin
  If (Event.What = evKeyDown) And (PCfgDialog(Owner)^.Form^.F[Idx].Kind = fkChoice) Then
    Begin
    D := PCfgDialog(Owner);
    N := NameCount(D^.Form^.F[Idx].Names);
    V := ChoiceValue(D^.Form^.F[Idx]) - D^.Form^.F[Idx].Min;
    Case Event.KeyCode Of
      kbRight, kbDown: Inc(V);
      kbLeft, kbUp: Dec(V);
      Else
        Case Event.CharCode Of
          ' ', '+': Inc(V);
          '-': Dec(V);
          Else
            Begin
            If Event.CharCode >= ' ' Then
              ClearEvent(Event);              {typing is not allowed}
            Inherited HandleEvent(Event);
            Exit;
            End;
          End;
      End;
    V := (V + N) Mod N;
    V := V + D^.Form^.F[Idx].Min;
    If D^.Form^.F[Idx].Size = 1 Then
      Byte(D^.Form^.F[Idx].P^) := V
    Else
      Word(D^.Form^.F[Idx].P^) := V;
    Data^ := FieldText(D^.Form^.F[Idx]);
    SelectAll(False);
    DrawView;
    ClearEvent(Event);
    Exit;
    End;
  If (Event.What = evKeyDown) And (Event.KeyCode = kbF2) Then
    Begin
    D := PCfgDialog(Owner);
    If @D^.Form^.F[Idx].Proc <> Nil Then
      Begin
      D^.Commit;
      D^.Form^.F[Idx].Proc(D^.Form^.F[Idx].ProcData, D^.Form^.F[Idx].ProcTitle);
      D^.Reload;
      ClearEvent(Event);
      Exit;
      End;
    End;
  Inherited HandleEvent(Event);
  End;


Constructor CfgFormObj.Init(ATitle: String);
  Begin
  If (Length(ATitle) > 2) And (ATitle[1] = '[') And (ATitle[Length(ATitle)] = ']') Then
    ATitle := Copy(ATitle, 2, Length(ATitle) - 2);     {old style "[ Title ]"}
  While (ATitle <> '') And (ATitle[1] = ' ') Do
    Delete(ATitle, 1, 1);
  While (ATitle <> '') And (ATitle[Length(ATitle)] = ' ') Do
    Dec(ATitle[0]);
  Title := ATitle;
  Count := 0;
  WinW := 0;
  WinH := 0;
  NRow := 0;
  NVis := 0;
  NFilter := '';
  End;


Procedure CfgFormObj.Window(X1, Y1, X2, Y2: Integer);
  Begin
  WinW := X2 - X1 + 1;
  WinH := Y2 - Y1 + 1;
  End;


Procedure CfgFormObj.At(Row, Col, FRow, FCol: Integer);
  Begin
  NRow := Row;
  NCol := Col;
  NFRow := FRow;
  NFCol := FCol;
  End;


Procedure CfgFormObj.Show(Width: Byte);
  Begin
  NVis := Width;
  End;


Procedure CfgFormObj.Filter(Chars: String);
  Begin
  NFilter := Chars;
  End;


Procedure CfgFormObj.OnF2(Proc: CfgProc; Data: Pointer; ProcTitle: String);
  Begin
  If Count = 0 Then
    Exit;
  F[Count].Proc := Proc;
  F[Count].ProcData := Data;
  F[Count].ProcTitle := ProcTitle;
  End;


Procedure CfgFormObj.Add(K: CfgFieldKind; ALab: String; Var V; ASize: Byte;
  AMin, AMax: LongInt; AHint: String);
  Begin
  If Count >= MaxCfgFields Then
    Exit;
  Inc(Count);
  F[Count].Kind := K;
  F[Count].Lab := ALab;
  F[Count].Hint := AHint;
  F[Count].P := @V;
  F[Count].Size := ASize;
  F[Count].Min := AMin;
  F[Count].Max := AMax;
  F[Count].Row := NRow;
  F[Count].Col := NCol;
  F[Count].FRow := NFRow;
  F[Count].FCol := NFCol;
  F[Count].Vis := NVis;
  F[Count].Filter := NFilter;
  F[Count].Proc := Nil;
  F[Count].ProcData := Nil;
  F[Count].View := Nil;
  NRow := 0;
  NVis := 0;
  NFilter := '';
  End;


Procedure CfgFormObj.AddString(Lab: String; Var V; MaxLen: Byte; Hint: String);
  Begin
  Add(fkString, Lab, V, MaxLen, 0, 0, Hint);
  End;


Procedure CfgFormObj.AddDir(Lab: String; Var V; MaxLen: Byte; Hint: String);
  Begin
  Add(fkDir, Lab, V, MaxLen, 0, 0, Hint);
  End;


Procedure CfgFormObj.AddFile(Lab: String; Var V; MaxLen: Byte; Hint: String);
  Begin
  Add(fkFile, Lab, V, MaxLen, 0, 0, Hint);
  End;


Procedure CfgFormObj.AddNumber(Lab: String; Var V; Size: Byte; Min, Max: LongInt;
  Hint: String);
  Begin
  Add(fkNumber, Lab, V, Size, Min, Max, Hint);
  End;


Procedure CfgFormObj.AddHex(Lab: String; Var V; Size: Byte; Hint: String);
  Begin
  Add(fkHex, Lab, V, Size, 0, 0, Hint);
  End;


Procedure CfgFormObj.AddChar(Lab: String; Var V; Hint: String);
  Begin
  Add(fkChar, Lab, V, 1, 0, 0, Hint);
  End;


Procedure CfgFormObj.AddYesNo(Lab: String; Var V: Boolean; Hint: String);
  Begin
  Add(fkYesNo, Lab, V, 1, 0, 1, Hint);
  End;


Procedure CfgFormObj.AddText(Text: String);
  Var
    Dummy: Byte;

  Begin
  Add(fkText, Text, Dummy, 0, 0, 0, '');
  End;


Procedure CfgFormObj.AddChoice(Lab: String; Var V; Size: Byte; First: LongInt;
  Names: String; Hint: String);
  Begin
  Add(fkChoice, Lab, V, Size, First, First + NameCount(Names) - 1, Hint);
  F[Count].Names := Names;
  End;


Procedure CfgFormObj.AddAction(Caption: String; Proc: CfgProc; Data: Pointer;
  ProcTitle: String; Hint: String);
  Var
    Dummy: Byte;

  Begin
  Add(fkAction, Caption, Dummy, 0, 0, 0, Hint);
  F[Count].Proc := Proc;
  F[Count].ProcData := Data;
  F[Count].ProcTitle := ProcTitle;
  End;


Function NumWidth(Const R: CfgFieldRec): Byte;
  Var
    A, B: String;

  Begin
  If R.Kind = fkHex Then
    Begin
    NumWidth := R.Size * 2 + 1;
    Exit;
    End;
  Str(R.Max, A);
  Str(R.Min, B);
  If Length(B) > Length(A) Then
    A := B;
  NumWidth := Length(A) + 1;
  End;


Function VisWidth(Const R: CfgFieldRec; Limit: Integer): Integer;
  {Width of the input line of a field}
  Var
    W: Integer;

  Begin
  Case R.Kind Of
    fkNumber, fkHex: W := NumWidth(R) + 1;
    fkChar: W := 3;
    fkYesNo: W := 4;
    fkChoice: W := NameLongest(R.Names) + 2;
    fkAction: W := Length(R.Lab) + 4;
    Else W := R.Size + 2;               {an input line keeps a column at each end for the scroll arrows}
    End;
  If R.Vis > 0 Then
    W := R.Vis + 2;
  If (R.Kind In [fkString, fkDir, fkFile]) And (R.Vis = 0) And (W > Limit) Then
    W := Limit;
  VisWidth := W;
  End;


Function CfgFormObj.Execute: Boolean;
  Var
    D: PCfgDialog;
    R: TRect;
    DeskW, DeskH: Integer;
    i, Rows, Cols, ColW, LW, FW, W, H, Col, Row, X, Y, FX, FY, VW: Integer;
    Inp: PCfgInput;
    Chk: PCheckBoxes;
    Txt: PStaticText;
    Btn: PButton;
    Res: Word;
    Widest: Integer;
    Absolute: Boolean;
    CF: TCharSet;
    j: Word;

  Begin
  Execute := False;
  If Count = 0 Then
    Exit;
  DeskTop^.GetExtent(R);
  DeskW := R.B.X - R.A.X;
  DeskH := R.B.Y - R.A.Y;
  Absolute := (WinW > 0) And (F[1].Row > 0);
  LW := 0;
  FW := 46;
  ColW := 0;
  If Absolute Then
    Begin
    W := WinW;
    H := WinH + 3;
    For i := 1 To Count Do        {buttons are two lines high: keep the hint line free}
      If F[i].Kind = fkAction Then
        H := WinH + 4;
    Rows := H - 5;
    Cols := 1;
    FW := 46;
    For i := 1 To Count Do        {an input line is wider than the old field: make room}
      Begin
      If F[i].Kind = fkText Then
        j := F[i].Col + Length(F[i].Lab) + 2
      Else If F[i].Kind = fkAction Then
        j := F[i].Col + Length(F[i].Lab) + 6
      Else If F[i].FCol > 0 Then
        j := F[i].FCol + VisWidth(F[i], FW) + 1
      Else
        j := 0;
      If j > W Then
        W := j;
      End;
    End
  Else
    Begin
    For i := 1 To Count Do
      If Length(F[i].Lab) > LW Then
        LW := Length(F[i].Lab);
    Inc(LW);
    Widest := 8;
    For i := 1 To Count Do
      If Not (F[i].Kind In [fkText, fkAction]) Then
        If VisWidth(F[i], 48) - 2 > Widest Then
          Widest := VisWidth(F[i], 48) - 2;
    Cols := 1;
    While ((Count + Cols - 1) Div Cols + 5 > DeskH) And (Cols < 3) Do
      Inc(Cols);
    Rows := (Count + Cols - 1) Div Cols;
    FW := Widest + 2;
    If FW > 48 Then
      FW := 48;
    ColW := LW + FW + 3;
    If (Cols * ColW + 3 > DeskW) Then
      Begin
      FW := (DeskW - 3) Div Cols - LW - 3;
      If FW < 6 Then
        FW := 6;
      ColW := LW + FW + 3;
      End;
    W := Cols * ColW + 3;
    H := Rows + 5;
    End;
  If W < 46 Then
    W := 46;
  If W > DeskW Then
    W := DeskW;
  If H > DeskH Then
    H := DeskH;
  R.Assign(0, 0, W, H);
  New(D, Init(R, Title));
  D^.Options := D^.Options Or ofCentered;
  D^.Form := @Self;
  For i := 1 To Count Do
    Begin
    If Absolute Then
      Begin
      X := F[i].Col;
      Y := F[i].Row;
      FX := F[i].FCol;
      FY := F[i].FRow;
      If FY = 0 Then
        FY := Y;
      End
    Else
      Begin
      Col := (i - 1) Div Rows;
      Row := (i - 1) Mod Rows;
      X := 2 + Col * ColW;
      Y := 1 + Row;
      FX := X + LW + 1;
      FY := Y;
      End;
    VW := VisWidth(F[i], FW);
    Case F[i].Kind Of
      fkText:
        Begin
        R.Assign(X, Y, X + Length(F[i].Lab) + 1, Y + 1);
        Txt := New(PStaticText, Init(R, F[i].Lab));
        D^.Insert(Txt);
        F[i].View := Txt;
        End;
      fkAction:
        Begin
        R.Assign(X, Y, X + Length(F[i].Lab) + 4, Y + 2);
        Btn := New(PButton, Init(R, F[i].Lab, cmCfgAction + i, bfNormal));
        D^.Insert(Btn);
        F[i].View := Btn;
        End;
      fkYesNo:
        Begin
        R.Assign(FX, FY, FX + 4, FY + 1);
        Chk := New(PCheckBoxes, Init(R, NewSItem(' ', Nil)));
        If Boolean(F[i].P^) Then
          Chk^.Press(0);
        D^.Insert(Chk);
        F[i].View := Chk;
        R.Assign(X, Y, X + Length(F[i].Lab) + 1, Y + 1);
        D^.Insert(New(PLabel, Init(R, F[i].Lab, Chk)));
        End;
      Else
        Begin
        R.Assign(FX, FY, FX + VW, FY + 1);
        Case F[i].Kind Of
          fkNumber: j := NumWidth(F[i]);
          fkHex: j := F[i].Size * 2;
          fkChar: j := 1;
          fkChoice: j := NameLongest(F[i].Names);
          Else j := F[i].Size;
          End;
        Inp := New(PCfgInput, Init(R, j + 1));   {size of Data: fixed at Init}
        Inp^.Idx := i;
        If F[i].Kind = fkNumber Then
          Begin
          Inp^.SetValidator(New(PRangeValidator, Init(F[i].Min, F[i].Max)));
          End
        Else If F[i].Kind = fkHex Then
          Begin
          CF := ['0'..'9', 'A'..'F', 'a'..'f'];
          Inp^.SetValidator(New(PFilterValidator, Init(CF)));
          End
        Else If F[i].Filter <> '' Then
          Begin
          CF := [];
          For j := 1 To Length(F[i].Filter) Do
            CF := CF + [F[i].Filter[j]];
          Inp^.SetValidator(New(PFilterValidator, Init(CF)));
          End;
        Inp^.Data^ := FieldText(F[i]);
        D^.Insert(Inp);
        F[i].View := Inp;
        R.Assign(X, Y, X + Length(F[i].Lab) + 1, Y + 1);
        D^.Insert(New(PLabel, Init(R, F[i].Lab, Inp)));
        End;
      End;
    End;
  R.Assign(2, H - 3, W - 28, H - 2);
  D^.Hint := New(PStaticText, Init(R, ''));
  D^.Insert(D^.Hint);
  R.Assign(W - 26, H - 3, W - 16, H - 1);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  R.Assign(W - 14, H - 3, W - 2, H - 1);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  D^.SelectNext(False);
  Res := Application^.ExecView(D);
  If Res = cmOK Then
    Begin
    D^.Commit;
    Execute := True;
    End;
  Dispose(D, Done);
  End;


End.
