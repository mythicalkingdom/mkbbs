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
         AddString   text
         AddDir      a directory: backslashes become slashes, a trailing slash
                     is added
         AddFile     a file or command: backslashes become slashes
         AddNumber   Byte (Size 1), Word (2) or LongInt (4); with Min < 0 the
                     signed types Shortint, Integer and LongInt
         AddYesNo    Boolean

     The dialog is as wide as the fields need, one column; when it would be
     taller than the desktop it uses two or three columns.  The hint of the
     field that has the focus is shown at the bottom left.

     Execute must be called while the application is running (from an event
     handler).  Escape or Cancel leaves the variables alone.
}

Interface

Uses Objects, Drivers, Views, Dialogs, App;

Const
  MaxCfgFields = 64;

Type
  CfgFieldKind = (fkString, fkDir, fkFile, fkNumber, fkYesNo);

  CfgFieldRec = Record
    Kind: CfgFieldKind;
    Lab: String[40];
    Hint: String[78];
    P: Pointer;                        {The variable}
    Size: Byte;                        {String: capacity; number: bytes}
    Min, Max: LongInt;
    View: PView;                       {Filled in by Execute}
    End;

  CfgFormObj = Object
    Title: String[60];
    Count: Word;
    F: Array[1..MaxCfgFields] Of CfgFieldRec;
    Constructor Init(ATitle: String);
    Procedure AddString(Lab: String; Var V; MaxLen: Byte; Hint: String);
    Procedure AddDir(Lab: String; Var V; MaxLen: Byte; Hint: String);
    Procedure AddFile(Lab: String; Var V; MaxLen: Byte; Hint: String);
    Procedure AddNumber(Lab: String; Var V; Size: Byte; Min, Max: LongInt;
      Hint: String);
    Procedure AddYesNo(Lab: String; Var V: Boolean; Hint: String);
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
    End;


Procedure CfgDialog.SetHint(S: String);
  Begin
  If Hint^.Text <> Nil Then
    DisposeStr(Hint^.Text);
  Hint^.Text := NewStr(S);
  Hint^.DrawView;
  End;


Procedure CfgDialog.HandleEvent(Var Event: TEvent);
  Var
    i: Word;

  Begin
  Inherited HandleEvent(Event);
  If (Event.What = evBroadcast) And (Event.Command = cmReceivedFocus) Then
    Begin
    For i := 1 To Form^.Count Do
      If Form^.F[i].View = PView(Event.InfoPtr) Then
        Begin
        SetHint(Form^.F[i].Hint);
        Exit;
        End;
    SetHint('');
    End;
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


Constructor CfgFormObj.Init(ATitle: String);
  Begin
  Title := ATitle;
  Count := 0;
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
  F[Count].View := Nil;
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


Procedure CfgFormObj.AddYesNo(Lab: String; Var V: Boolean; Hint: String);
  Begin
  Add(fkYesNo, Lab, V, 1, 0, 1, Hint);
  End;


Function NumberToStr(Const R: CfgFieldRec): String;
  Var
    L: LongInt;
    S: String;

  Begin
  Case R.Size Of
    1: If R.Min < 0 Then L := ShortInt(R.P^) Else L := Byte(R.P^);
    2: If R.Min < 0 Then L := Integer(R.P^) Else L := Word(R.P^);
    Else L := LongInt(R.P^);
    End;
  Str(L, S);
  NumberToStr := S;
  End;


Procedure StrToNumber(Const R: CfgFieldRec; S: String);
  Var
    L: LongInt;
    Code: Integer;

  Begin
  Val(S, L, Code);
  If Code <> 0 Then
    Exit;
  Case R.Size Of
    1: If R.Min < 0 Then ShortInt(R.P^) := L Else Byte(R.P^) := L;
    2: If R.Min < 0 Then Integer(R.P^) := L Else Word(R.P^) := L;
    Else LongInt(R.P^) := L;
    End;
  End;


Function NumWidth(Const R: CfgFieldRec): Byte;
  Var
    A, B: String;

  Begin
  Str(R.Max, A);
  Str(R.Min, B);
  If Length(B) > Length(A) Then
    A := B;
  NumWidth := Length(A) + 1;
  End;


Function CfgFormObj.Execute: Boolean;
  Var
    D: PCfgDialog;
    R: TRect;
    DeskW, DeskH: Integer;
    i, Rows, Cols, ColW, LW, FW, W, H, Col, Row, X, Y: Integer;
    Inp: PInputLine;
    Chk: PCheckBoxes;
    S: String;
    Res: Word;
    Widest: Integer;

  Begin
  Execute := False;
  If Count = 0 Then
    Exit;
  DeskTop^.GetExtent(R);
  DeskW := R.B.X - R.A.X;
  DeskH := R.B.Y - R.A.Y;
  LW := 0;
  For i := 1 To Count Do
    If Length(F[i].Lab) > LW Then
      LW := Length(F[i].Lab);
  Inc(LW);
  { widest value column wanted by any field }
  Widest := 8;
  For i := 1 To Count Do
    Case F[i].Kind Of
      fkNumber: If NumWidth(F[i]) > Widest Then Widest := NumWidth(F[i]);
      fkYesNo: ;
      Else If F[i].Size > Widest Then Widest := F[i].Size;
    End;
  { number of columns: as few as fit the height }
  Cols := 1;
  While ((Count + Cols - 1) Div Cols + 5 > DeskH) And (Cols < 3) Do
    Inc(Cols);
  Rows := (Count + Cols - 1) Div Cols;
  FW := Widest;
  If FW > 46 Then
    FW := 46;
  ColW := LW + FW + 3;
  If (Cols * ColW + 3 > DeskW) Then
    Begin
    FW := (DeskW - 3) Div Cols - LW - 3;
    If FW < 6 Then
      FW := 6;
    ColW := LW + FW + 3;
    End;
  W := Cols * ColW + 3;
  If W < 46 Then
    W := 46;
  If W > DeskW Then
    W := DeskW;
  H := Rows + 5;
  R.Assign(0, 0, W, H);
  New(D, Init(R, Title));
  D^.Options := D^.Options Or ofCentered;
  D^.Form := @Self;
  For i := 1 To Count Do
    Begin
    Col := (i - 1) Div Rows;
    Row := (i - 1) Mod Rows;
    X := 2 + Col * ColW;
    Y := 1 + Row;
    Case F[i].Kind Of
      fkYesNo:
        Begin
        R.Assign(X + LW + 1, Y, X + LW + 1 + 7, Y + 1);
        Chk := New(PCheckBoxes, Init(R, NewSItem('Yes', Nil)));
        If Boolean(F[i].P^) Then
          Chk^.Press(0);
        D^.Insert(Chk);
        F[i].View := Chk;
        R.Assign(X, Y, X + LW, Y + 1);
        D^.Insert(New(PLabel, Init(R, F[i].Lab, Chk)));
        End;
      Else
        Begin
        If F[i].Kind = fkNumber Then
          Begin
          R.Assign(X + LW + 1, Y, X + LW + 1 + NumWidth(F[i]) + 2, Y + 1);
          Inp := New(PInputLine, Init(R, NumWidth(F[i]) + 1));
          Inp^.SetValidator(New(PRangeValidator, Init(F[i].Min, F[i].Max)));
          S := NumberToStr(F[i]);
          End
        Else
          Begin
          R.Assign(X + LW + 1, Y, X + LW + 1 + FW, Y + 1);
          If F[i].Size < FW Then
            R.B.X := R.A.X + F[i].Size;
          Inp := New(PInputLine, Init(R, F[i].Size + 1));
          S := PString(F[i].P)^;
          End;
        Inp^.Data^ := S;
        D^.Insert(Inp);
        F[i].View := Inp;
        R.Assign(X, Y, X + LW, Y + 1);
        D^.Insert(New(PLabel, Init(R, F[i].Lab, Inp)));
        End;
      End;
    End;
  R.Assign(2, Rows + 2, W - 28, Rows + 3);
  D^.Hint := New(PStaticText, Init(R, ''));
  D^.Insert(D^.Hint);
  R.Assign(W - 26, Rows + 2, W - 16, Rows + 4);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  R.Assign(W - 14, Rows + 2, W - 2, Rows + 4);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  D^.SelectNext(False);
  Res := Application^.ExecView(D);
  If Res = cmOK Then
    Begin
    For i := 1 To Count Do
      Case F[i].Kind Of
        fkYesNo: Boolean(F[i].P^) := (PCheckBoxes(F[i].View)^.Mark(0));
        fkNumber: StrToNumber(F[i], PInputLine(F[i].View)^.Data^);
        Else
          Begin
          S := Copy(PInputLine(F[i].View)^.Data^, 1, F[i].Size);
          If F[i].Kind <> fkString Then
            S := FixPath(S, F[i].Kind = fkDir);
          S := Copy(S, 1, F[i].Size);
          PString(F[i].P)^ := S;
          End;
        End;
    Execute := True;
    End;
  Dispose(D, Done);
  End;


End.
