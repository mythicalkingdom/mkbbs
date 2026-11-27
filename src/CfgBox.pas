{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgBox;   {Small message boxes (replaces the CfgYN unit of the Object Professional programs)}

{$I MKB.Def}

Interface

Function DoYesNo(Hdr: String; DefChoice: Boolean): Word;  {0 = Escape, 1 = yes, 2 = no}
Const
  MsgBoxTitle: String = 'MKRead';        {the title of MsgBox: the program that shows it}

Procedure MsgBox(Msg: String);
Procedure ProcessBox(Msg: String; Hdr: String);
  {A "please wait" box; drawn at once, no event loop}
Procedure EndProcessBox;
Function InputLine(Title, Prompt: String; MaxLen: Byte; Var S: String): Boolean;
  {One line of text; False when cancelled}

Implementation

Uses Objects, Drivers, Views, Dialogs, App;

Var
  Wait: PDialog;

Function DoYesNo(Hdr: String; DefChoice: Boolean): Word;
  Var
    R: TRect;
    D: PDialog;
    Res: Word;
    W: Integer;

  Begin
  While (Hdr <> '') And (Hdr[1] In ['[', ' ']) Do
    Delete(Hdr, 1, 1);
  While (Hdr <> '') And (Hdr[Length(Hdr)] In [']', ' ']) Do
    Dec(Hdr[0]);
  W := Length(Hdr) + 8;
  If W < 36 Then
    W := 36;
  R.Assign(0, 0, W, 7);
  New(D, Init(R, Hdr));
  D^.Options := D^.Options Or ofCentered;
  R.Assign(W Div 2 - 14, 3, W Div 2 - 4, 5);
  If DefChoice Then
    D^.Insert(New(PButton, Init(R, '~Y~es', cmYes, bfDefault)))
  Else
    D^.Insert(New(PButton, Init(R, '~Y~es', cmYes, bfNormal)));
  R.Assign(W Div 2 - 3, 3, W Div 2 + 7, 5);
  If DefChoice Then
    D^.Insert(New(PButton, Init(R, '~N~o', cmNo, bfNormal)))
  Else
    D^.Insert(New(PButton, Init(R, '~N~o', cmNo, bfDefault)));
  D^.SelectNext(False);
  Res := Application^.ExecView(D);
  Dispose(D, Done);
  Case Res Of
    cmYes: DoYesNo := 1;
    cmNo: DoYesNo := 2;
    Else DoYesNo := 0;
    End;
  End;


Procedure MsgBox(Msg: String);
  Var
    R: TRect;
    D: PDialog;
    W: Integer;

  Begin
  W := Length(Msg) + 10;
  If W < 30 Then
    W := 30;
  If W > 76 Then
    W := 76;
  R.Assign(0, 0, W, 8);
  New(D, Init(R, MsgBoxTitle));
  D^.Options := D^.Options Or ofCentered;
  R.Assign(3, 2, W - 3, 4);
  D^.Insert(New(PStaticText, Init(R, Msg)));
  R.Assign(W Div 2 - 5, 5, W Div 2 + 5, 7);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  D^.SelectNext(False);
  Application^.ExecView(D);
  Dispose(D, Done);
  End;


Procedure ProcessBox(Msg: String; Hdr: String);
  Var
    R: TRect;

  Begin
  If Wait <> Nil Then
    EndProcessBox;
  While (Hdr <> '') And (Hdr[1] In ['[', ' ']) Do
    Delete(Hdr, 1, 1);
  While (Hdr <> '') And (Hdr[Length(Hdr)] In [']', ' ']) Do
    Dec(Hdr[0]);
  R.Assign(0, 0, Length(Msg) + 10, 5);
  New(Wait, Init(R, Hdr));
  Wait^.Options := Wait^.Options Or ofCentered;
  R.Assign(3, 2, Length(Msg) + 7, 3);
  Wait^.Insert(New(PStaticText, Init(R, Msg)));
  DeskTop^.Insert(Wait);
  Wait^.DrawView;
  End;


Procedure EndProcessBox;
  Begin
  If Wait <> Nil Then
    Begin
    DeskTop^.Delete(Wait);
    Dispose(Wait, Done);
    Wait := Nil;
    End;
  End;


Function InputLine(Title, Prompt: String; MaxLen: Byte; Var S: String): Boolean;
  Var
    R: TRect;
    D: PDialog;
    I: PInputLine;
    W: Integer;

  Begin
  W := Length(Prompt) + MaxLen + 8;
  If W < 40 Then
    W := 40;
  If W > 78 Then
    W := 78;
  R.Assign(0, 0, W, 7);
  New(D, Init(R, Title));
  D^.Options := D^.Options Or ofCentered;
  R.Assign(3, 2, 3 + Length(Prompt) + 1, 3);
  D^.Insert(New(PStaticText, Init(R, Prompt)));
  R.Assign(4 + Length(Prompt), 2, W - 3, 3);
  I := New(PInputLine, Init(R, MaxLen));
  I^.Data^ := S;
  D^.Insert(I);
  R.Assign(W Div 2 - 14, 4, W Div 2 - 4, 6);
  D^.Insert(New(PButton, Init(R, 'O~K~', cmOK, bfDefault)));
  R.Assign(W Div 2 - 2, 4, W Div 2 + 10, 6);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  I^.Select;
  InputLine := False;
  If Application^.ExecView(D) = cmOK Then
    Begin
    S := I^.Data^;
    InputLine := True;
    End;
  Dispose(D, Done);
  End;


Begin
  Wait := Nil;
End.
