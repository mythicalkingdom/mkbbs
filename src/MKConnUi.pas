{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKConnUi;   {the dialing directory of mkconnect: a list of systems, forms, small dialogs (MKCONNECT-PLAN.md phase 1)}

{$MODE OBJFPC}
{$H+}

{
  The screen is the cell buffer of the Video unit (MKTuiScr), the keys come from MKTuiKeys: the same small text user interface as mkedit and mklist, no Free Vision.

     Enter dial        A add        E edit        D delete        F or /  find        S sort (name / last call)        P change the start password        F1 help        Esc menu        Q or Alt-X leave
}

Interface

Uses MKConnBook, MKConnCall;

Type
  TDialerState = Record
    Book: TConnBook;
    Password: String;                  {the start password the book is sealed with ('' = not sealed)}
    Sealed: Boolean;
    Opts: TCallOpts;
    Rounds: Integer;                   {multi-dial: how many times the list is gone through}
    PauseSecs: Integer;                {... and the wait between two tries}
  End;

Procedure RunDialer(Var St: TDialerState);

{ the start password, asked before the screen is up: a line with no echo (False: no terminal, or Ctrl-C) }
Function AskPasswordTty(Const Prompt: String; Out Pw: String): Boolean;

Implementation

Uses SysUtils, Classes, DateUtils, BaseUnix, Termio, Video, MKTuiCp, MKTuiScr, MKTuiKeys;

Const
  cBlack = 0; cBlue = 1; cGreen = 2; cCyan = 3; cRed = 4; cBrown = 6; cLGray = 7; cDGray = 8; cLBlue = 9; cLCyan = 11; cLRed = 12; cYellow = 14; cWhite = 15;

Var
  Msg: String;                         {shown under the list until the next key}
  Sorted: Boolean;


Function AskPasswordTty(Const Prompt: String; Out Pw: String): Boolean;
  Var
    Old, T: Termios;
    C: Char;
    N: LongInt;

  Begin
  Pw := '';
  Result := False;
  If TCGetAttr(0, Old) <> 0 Then
    Exit;
  T := Old;
  T.c_lflag := T.c_lflag And Not (ECHO);
  TCSetAttr(0, TCSANOW, T);
  fpWrite(1, Prompt[1], Length(Prompt));
  Result := True;
  While True Do
    Begin
    N := fpRead(0, C, 1);
    If N <= 0 Then
      Begin
      Result := False;
      Break;
      End;
    If (C = #10) Or (C = #13) Then
      Break;
    If C = #3 Then
      Begin
      Result := False;
      Break;
      End;
    If (C = #127) Or (C = #8) Then
      Begin
      If Pw <> '' Then
        Begin
        Pw := Copy(Pw, 1, Length(Pw) - 1);                   {a byte is enough for the password: a UTF-8 letter is removed by the next ones}
        While (Pw <> '') And ((Ord(Pw[Length(Pw)]) And $C0) = $80) Do
          Delete(Pw, Length(Pw), 1);
        End;
      End
    Else If C >= ' ' Then
      Pw := Pw + C;
    End;
  TCSetAttr(0, TCSANOW, Old);
  fpWrite(1, #13#10, 2);
  End;


{ ---------------------------------------------------------------- drawing helpers }

Function Pad(Const S: String; W: Integer): String;
  Var
    L: Integer;

  Begin
  L := Utf8Len(S);
  If L >= W Then
    Result := S
  Else
    Result := S + StringOfChar(' ', W - L);
  End;


Procedure DelLastChar(Var S: String);
  Begin
  If S = '' Then
    Exit;
  Delete(S, Length(S), 1);
  While (S <> '') And ((Ord(S[Length(S)]) And $C0) = $80) Do
    Delete(S, Length(S), 1);
  End;


Function Plain(Const K: TKey): Boolean;
  {a letter, digit or sign that was typed (no Ctrl, no Alt)}
  Begin
  Result := (K.code = kcChar) And (K.mods - [mShift] = []) And (K.ch <> '');
  End;


Function WaitKey(Out K: TKey): Boolean;
  {the next key; False when the terminal went away}
  Begin
  Result := False;
  While Not Hangup Do
    Begin
    If KeyRead(K) Then
      Exit(True);
    KeyWait(200);
    End;
  End;


Procedure Frame(Const Title: String; X, Y, W, H: Integer);
  Begin
  ScrBox(X, Y, W, H, cYellow, cBlue, True);
  If Title <> '' Then
    ScrPuts(X + 2, Y, ' ' + Title + ' ', cWhite, cBlue);
  End;


{ ---------------------------------------------------------------- small dialogs }

Function AskLine(Const Title, Prompt: String; Var Value: String; Hidden: Boolean; MaxLen: Integer): Boolean;
  {a line in a box in the middle of the screen: Enter takes it, Esc gives up}
  Var
    W, X, Y: Integer;
    K: TKey;
    Shown: String;
    i: Integer;

  Begin
  Result := False;
  W := ScrW - 10;
  If W > 70 Then W := 70;
  X := (ScrW - W) Div 2;
  Y := ScrH Div 2 - 2;
  While True Do
    Begin
    Frame(Title, X, Y, W, 5);
    ScrPuts(X + 2, Y + 1, Pad(Prompt, W - 4), cLGray, cBlue);
    If Hidden Then
      Shown := StringOfChar('*', Utf8Len(Value))
    Else
      Shown := Value;
    ScrFill(X + 2, Y + 2, W - 4, 32, cBlack, cLGray);
    i := Utf8Len(Shown);
    If i > W - 6 Then
      Begin
      Shown := Copy(Shown, Length(Shown) - (W - 6) + 1, W - 6);
      i := W - 6;
      End;
    ScrPuts(X + 2, Y + 2, Shown, cBlack, cLGray);
    ScrPuts(X + 2, Y + 3, Pad('Enter accepts, Esc gives up', W - 4), cDGray, cBlue);
    ScrCursor(X + 2 + i, Y + 2, False);
    ScrFlush;
    If Not WaitKey(K) Then
      Exit;
    Case K.code Of
      kcEnter: Begin Result := True; Break; End;
      kcEsc: Break;
      kcBack: DelLastChar(Value);
      Else
        If (K.code = kcChar) And (mCtrl In K.mods) And (K.ch = 'u') Then
          Value := ''
        Else If Plain(K) And (Utf8Len(Value) < MaxLen) Then
          Value := Value + K.ch;
      End;
    End;
  ScrHideCursor;
  End;


Function Confirm(Const Q: String): Boolean;
  Var
    W, X, Y: Integer;
    K: TKey;

  Begin
  Result := False;
  W := Utf8Len(Q) + 6;
  If W < 36 Then W := 36;
  If W > ScrW - 4 Then W := ScrW - 4;
  X := (ScrW - W) Div 2;
  Y := ScrH Div 2 - 2;
  Frame('', X, Y, W, 5);
  ScrPutsN(X + 2, Y + 1, Q, W - 4, cWhite, cBlue);
  ScrPuts(X + 2, Y + 3, 'Y yes   N no', cLGray, cBlue);
  ScrFlush;
  While WaitKey(K) Do
    Begin
    If K.code = kcEsc Then Break;
    If K.code = kcChar Then
      Begin
      If LowerCase(K.ch) = 'y' Then
        Exit(True);
      If LowerCase(K.ch) = 'n' Then
        Break;
      End;
    End;
  End;


Procedure ShowText(Const Title: String; Const Lines: Array Of String);
  Var
    W, H, X, Y, i: Integer;
    K: TKey;

  Begin
  H := Length(Lines) + 4;
  W := 70;
  If W > ScrW - 2 Then W := ScrW - 2;
  If H > ScrH - 1 Then H := ScrH - 1;
  X := (ScrW - W) Div 2;
  Y := (ScrH - H) Div 2;
  Frame(Title, X, Y, W, H);
  For i := 0 To H - 5 Do
    ScrPutsN(X + 2, Y + 1 + i, Lines[i], W - 4, cWhite, cBlue);
  ScrPuts(X + 2, Y + H - 2, 'any key', cLGray, cBlue);
  ScrFlush;
  WaitKey(K);
  End;


Procedure Help;
  Begin
  ShowText('mkconnect help', [
    'In the dialing directory:',
    '  Enter  dial the system          A add      E edit      D delete',
    '  F or /  find                    S sort by name / by last call',
    '  Space  mark (several)           M  multi-dial: the marked systems (or this one) in turn, a pause between,',
    '                                  round after round (-r rounds, -w seconds) until one answers; Esc stops',
    '  P  change the start password    Esc  the menu     Q or Alt-X  leave',
    '  Up Down PgUp PgDn Home End  move',
    '',
    'In a call:',
    '  Ctrl-]  the attention key: a menu on the bottom row',
    '  Alt-P  send the password of this system        Alt-N  send its login name',
    '  Alt-C  capture on / off                        Alt-T  the character set of the display',
    '  Alt-U  upload files to the system              Alt-L  download (Esc or Ctrl-X cancels a transfer)',
    '  Alt-H  hang up        Alt-D  hang up, dialer       Alt-X  hang up and leave',
    '  (an Alt key is the Esc key and a letter pressed together)',
    '',
    'The phone book is ~/.config/mkconnect/phonebook, sealed with the start password.']);
  End;


{ ---------------------------------------------------------------- the form of one system }

Type
  TFieldKind = (fText, fNumber, fKind, fCharset, fProto, fSecret);

Const
  NFields = 11;
  FLabel: Array[0..NFields - 1] Of String = ('Name', 'Host', 'Port', 'Kind', 'Character set', 'Protocol', 'Login name', 'Password', 'Script', 'SSH user', 'Note');
  FType: Array[0..NFields - 1] Of TFieldKind = (fText, fText, fNumber, fKind, fCharset, fProto, fText, fSecret, fText, fText, fText);


Function EditEntry(Var E: TConnEntry; Const Title: String): Boolean;
  Var
    V: Array[0..NFields - 1] Of String;
    Cur, i, W, X, Y, VX, VW: Integer;
    K: TKey;
    Show: Boolean;
    Kd: TConnKind;
    Old: TConnEntry;
    Shown: String;

  Procedure Load;
    Begin
    V[0] := E.Name; V[1] := E.Host; V[2] := IntToStr(E.Port); V[3] := ConnKindName(E.Kind);
    If E.Utf8 Then V[4] := 'UTF-8' Else V[4] := 'CP437';
    V[5] := ConnProtoName(E.Proto);
    V[6] := E.Login; V[7] := E.Password; V[8] := E.Script; V[9] := E.SshUser; V[10] := E.Note;
    End;

  Function Store: Boolean;
    Var
      P: LongInt;

    Begin
    Result := False;
    If Trim(V[0]) = '' Then
      Begin
      Msg := 'the system needs a name';
      Cur := 0;
      Exit;
      End;
    If Trim(V[1]) = '' Then
      Begin
      Msg := 'the system needs a host';
      Cur := 1;
      Exit;
      End;
    P := StrToIntDef(V[2], 0);
    If (P < 1) Or (P > 65535) Then
      Begin
      Msg := 'the port is a number from 1 to 65535';
      Cur := 2;
      Exit;
      End;
    E.Name := Trim(V[0]); E.Host := Trim(V[1]); E.Port := P;
    ConnKindFrom(V[3], Kd);
    E.Kind := Kd;
    E.Utf8 := V[4] = 'UTF-8';
    If ConnProtoFrom(V[5]) <> #0 Then E.Proto := ConnProtoFrom(V[5]);
    E.Login := V[6]; E.Password := V[7]; E.Script := V[8]; E.SshUser := V[9]; E.Note := V[10];
    Result := True;
    End;

  Procedure Cycle(Dir: Integer);
    Var
      n: Integer;

    Begin
    If FType[Cur] = fKind Then
      Begin
      ConnKindFrom(V[3], Kd);
      n := (Ord(Kd) + Dir + 4) Mod 4;
      V[3] := ConnKindName(TConnKind(n));
      If StrToIntDef(V[2], 0) = ConnDefaultPort(Kd) Then
        V[2] := IntToStr(ConnDefaultPort(TConnKind(n)));
      End
    Else If FType[Cur] = fCharset Then
      Begin
      If V[4] = 'CP437' Then V[4] := 'UTF-8' Else V[4] := 'CP437';
      End
    Else If FType[Cur] = fProto Then
      Begin
      n := Pos(ConnProtoFrom(V[5]), 'ZYGX1') - 1;
      V[5] := ConnProtoName(Copy('ZYGX1', ((n + Dir + 5) Mod 5) + 1, 1)[1]);
      End;
    End;

  Begin
  Result := False;
  Old := E;
  Load;
  Cur := 0;
  Show := False;
  W := ScrW - 6;
  If W > 72 Then W := 72;
  X := (ScrW - W) Div 2;
  Y := (ScrH - (NFields + 6)) Div 2;
  If Y < 0 Then Y := 0;
  VX := X + 18;
  VW := W - 20;
  While True Do
    Begin
    Frame(Title, X, Y, W, NFields + 6);
    For i := 0 To NFields - 1 Do
      Begin
      If i = Cur Then
        ScrPuts(X + 2, Y + 2 + i, Pad(FLabel[i] + ':', 16), cYellow, cBlue)
      Else
        ScrPuts(X + 2, Y + 2 + i, Pad(FLabel[i] + ':', 16), cLGray, cBlue);
      ScrFill(VX, Y + 2 + i, VW, 32, cBlack, cLGray);
      Shown := V[i];
      If (FType[i] = fSecret) And (Not Show) Then
        Shown := StringOfChar('*', Utf8Len(V[i]));
      If (FType[i] In [fKind, fCharset, fProto]) Then
        Shown := '< ' + Shown + ' >';
      If Utf8Len(Shown) > VW - 1 Then
        Shown := Copy(Shown, Length(Shown) - (VW - 1) + 1, VW - 1);
      If i = Cur Then
        ScrPuts(VX, Y + 2 + i, Shown, cBlack, cCyan)
      Else
        ScrPuts(VX, Y + 2 + i, Shown, cBlack, cLGray);
      End;
    ScrPutsN(X + 2, Y + NFields + 3, 'Up/Down choose  Enter next  Space or Left/Right changes a choice  F2 shows the password', W - 4, cDGray, cBlue);
    ScrPutsN(X + 2, Y + NFields + 4, 'F10 or Ctrl-S saves  Esc gives up' + Copy('   ' + Msg, 1, Ord(Msg <> '') * 80), W - 4, cLGray, cBlue);
    If FType[Cur] In [fText, fNumber, fSecret] Then
      Begin
      i := Utf8Len(V[Cur]);
      If (FType[Cur] = fSecret) And Not Show Then
        i := Utf8Len(V[Cur]);
      If i > VW - 2 Then i := VW - 2;
      ScrCursor(VX + i, Y + 2 + Cur, False);
      End
    Else
      ScrHideCursor;
    ScrFlush;
    If Not WaitKey(K) Then
      Exit;
    Msg := '';
    Case K.code Of
      kcEsc: Begin E := Old; Exit; End;
      kcUp: If Cur > 0 Then Dec(Cur);
      kcDown, kcTab: If Cur < NFields - 1 Then Inc(Cur);
      kcEnter: If Cur < NFields - 1 Then Inc(Cur) Else If Store Then Exit(True);
      kcLeft: If FType[Cur] In [fKind, fCharset, fProto] Then Cycle(-1);
      kcRight: If FType[Cur] In [fKind, fCharset, fProto] Then Cycle(1);
      kcBack: If FType[Cur] In [fText, fNumber, fSecret] Then DelLastChar(V[Cur]);
      kcF: Begin
           If K.n = 10 Then
             Begin
             If Store Then Exit(True);
             End
           Else If K.n = 2 Then
             Show := Not Show;
           End;
      Else
        Begin
        If (K.code = kcChar) And (mCtrl In K.mods) And (K.ch = 's') Then
          Begin
          If Store Then Exit(True);
          End
        Else If (K.code = kcChar) And (mCtrl In K.mods) And (K.ch = 'u') Then
          V[Cur] := ''
        Else If Plain(K) Then
          Begin
          If FType[Cur] In [fKind, fCharset, fProto] Then
            Begin
            If K.ch = ' ' Then Cycle(1);
            End
          Else If FType[Cur] = fNumber Then
            Begin
            If (K.ch >= '0') And (K.ch <= '9') And (Length(V[Cur]) < 5) Then
              V[Cur] := V[Cur] + K.ch;
            End
          Else If Utf8Len(V[Cur]) < 200 Then
            V[Cur] := V[Cur] + K.ch;
          End;
        End;
      End;
    End;
  End;


{ ---------------------------------------------------------------- the menu }

Function PopupMenu(Const Items: Array Of String; Const Hot: String): Integer;
  {the number of the item chosen (from 0), -1: none}
  Var
    W, X, Y, i, Cur: Integer;
    K: TKey;

  Begin
  Result := -1;
  W := 36;
  X := 4;
  Y := 2;
  Cur := 0;
  While True Do
    Begin
    Frame('', X, Y, W, Length(Items) + 2);
    For i := 0 To High(Items) Do
      If i = Cur Then
        ScrPuts(X + 1, Y + 1 + i, Pad(' ' + Items[i], W - 2), cBlack, cCyan)
      Else
        ScrPuts(X + 1, Y + 1 + i, Pad(' ' + Items[i], W - 2), cWhite, cBlue);
    ScrFlush;
    If Not WaitKey(K) Then
      Exit;
    Case K.code Of
      kcEsc: Exit;
      kcUp: If Cur > 0 Then Dec(Cur) Else Cur := High(Items);
      kcDown: If Cur < High(Items) Then Inc(Cur) Else Cur := 0;
      kcEnter: Exit(Cur);
      Else
        If Plain(K) Then
          For i := 1 To Length(Hot) Do
            If LowerCase(K.ch) = LowerCase(Hot[i]) Then
              Exit(i - 1);
      End;
    End;
  End;


{ ---------------------------------------------------------------- the dialer }

Procedure RunDialer(Var St: TDialerState);
  Var
    Top, Sel, Rows, i, M, Idx: Integer;
    K: TKey;
    Done: Boolean;
    E: TConnEntry;
    Why, Q: String;
    R: Integer;
    NeedFull: Boolean;
    Marks: TStringList;

  Function IsMarked(k: Integer): Boolean;
    Begin
    Result := Marks.IndexOf(LowerCase(St.Book.Items[k].Name)) >= 0;
    End;

  Procedure Save;
    Begin
    If Not St.Book.Save(St.Password, St.Sealed, Why) Then
      Msg := 'the phone book was not saved: ' + Why;
    End;

  Procedure Draw;
    Var
      y, k: Integer;
      Line, D: String;

    Begin
    ScrClear(cLGray, cBlack);
    ScrFill(0, 0, ScrW, 32, cWhite, cBlue);
    ScrPuts(1, 0, 'mkconnect  -  dialing directory', cWhite, cBlue);
    ScrPuts(ScrW - 14, 0, IntToStr(St.Book.Count) + ' system(s)', cLCyan, cBlue);
    ScrFill(0, 1, ScrW, 32, cYellow, cBlack);
    ScrPuts(1, 1, Pad('Name', 22) + Pad('Host', ScrW - 60) + Pad('Port', 6) + Pad('Kind', 8) + Pad('Set', 6) + Pad('Calls', 6) + 'Last call', cYellow, cBlack);
    Rows := ScrH - 5;
    If Sel < Top Then Top := Sel;
    If Sel >= Top + Rows Then Top := Sel - Rows + 1;
    If Top < 0 Then Top := 0;
    For y := 0 To Rows - 1 Do
      Begin
      k := Top + y;
      If k >= St.Book.Count Then
        Break;
      With St.Book.Items[k] Do
        Begin
        If Last > 0 Then
          D := FormatDateTime('yyyy-mm-dd', UnixToDateTime(Last))
        Else
          D := '-';
        Line := Pad(Name, 22) + Pad(Host, ScrW - 60) + Pad(IntToStr(Port), 6) + Pad(ConnKindName(Kind), 8) + Pad(Copy('CP437', 1, 5 * Ord(Not Utf8)) + Copy('UTF-8', 1, 5 * Ord(Utf8)), 6) + Pad(IntToStr(Calls), 6) + D;
        End;
      If k = Sel Then
        ScrPutsN(1, 2 + y, Pad(Line, ScrW - 1), ScrW - 1, cBlack, cCyan)
      Else
        ScrPutsN(1, 2 + y, Line, ScrW - 1, cLGray, cBlack);
      If IsMarked(k) Then
        ScrPuts(0, 2 + y, '*', cLRed, cBlack);
      End;
    If St.Book.Count = 0 Then
      ScrPuts(2, 3, 'No systems yet: press A to add one.', cLGray, cBlack);
    ScrFill(0, ScrH - 3, ScrW, 196, cDGray, cBlack);
    If Msg <> '' Then
      ScrPutsN(1, ScrH - 2, Msg, ScrW - 2, cLRed, cBlack)
    Else If (St.Book.Count > 0) And (Sel < St.Book.Count) Then
      Begin
      With St.Book.Items[Sel] Do
        Begin
        D := Note;
        If Login <> '' Then D := 'login: ' + Login + Copy('   ' + Note, 1, Ord(Note <> '') * 200);
        If Script <> '' Then D := D + '   script: ' + Script;
        End;
      ScrPutsN(1, ScrH - 2, D, ScrW - 2, cLCyan, cBlack);
      End;
    ScrFill(0, ScrH - 1, ScrW, 32, cBlack, cLGray);
    ScrPutsN(1, ScrH - 1, 'Enter Dial  Space Mark  M Multi-dial  A Add  E Edit  D Delete  F Find  S Sort  F1 Help  Esc Menu  Q Quit', ScrW - 2, cBlack, cLGray);
    ScrHideCursor;
    If NeedFull Then
      Begin
      ScrRedraw;                       {the terminal was used by a call: every cell again}
      NeedFull := False;
      End
    Else
      ScrFlush;
    End;

  Procedure DialIdx(Ix: Integer);
    Var
      Ent: TConnEntry;

    Begin
    Ent := St.Book.Items[Ix];
    KeysDone;
    DoneVideo;
    R := RunCall(Ent, St.Opts, Q);
    InitVideo;
    KeysInit;
    ClearScreen;
    NeedFull := True;
    Msg := Q;
    If Ent.Calls <> St.Book.Items[Ix].Calls Then
      Begin
      St.Book.Items[Ix].Calls := Ent.Calls;
      St.Book.Items[Ix].Last := Ent.Last;
      Save;
      End;
    If R = crQuit Then
      Done := True;
    End;

  Procedure Dial;
    Begin
    If St.Book.Count = 0 Then
      Exit;
    DialIdx(Sel);
    End;

  Procedure Mark;
    Var
      p: Integer;

    Begin
    If St.Book.Count = 0 Then
      Exit;
    p := Marks.IndexOf(LowerCase(St.Book.Items[Sel].Name));
    If p >= 0 Then
      Marks.Delete(p)
    Else
      Marks.Add(LowerCase(St.Book.Items[Sel].Name));
    If Sel < St.Book.Count - 1 Then
      Inc(Sel);
    End;

  Procedure Multi;
    {the marked systems (the selected one when none is marked) are tried in turn, with a pause, round after round, until a call is made}
    Var
      L: TStringList;
      Rd, n, j, Ix, w: Integer;
      Stop: Boolean;
      Why2: String;
      Until_: Int64;

    Begin
    L := TStringList.Create;
    Try
      For j := 0 To St.Book.Count - 1 Do
        If IsMarked(j) Then
          L.Add(St.Book.Items[j].Name);
      If (L.Count = 0) And (St.Book.Count > 0) Then
        L.Add(St.Book.Items[Sel].Name);
      If L.Count = 0 Then
        Exit;
      Stop := False;
      For Rd := 1 To St.Rounds Do
        Begin
        For n := 0 To L.Count - 1 Do
          Begin
          Ix := St.Book.Find(L[n]);
          If Ix < 0 Then
            Continue;
          Sel := Ix;
          DialIdx(Ix);
          If Done Or (R <> crFailed) Then
            Exit;
          Why2 := Q;
          { the pause: the reason is on the screen, Esc stops }
          Until_ := GetTickCount64 + Int64(St.PauseSecs) * 1000;
          While (GetTickCount64 < Until_) And (Not Stop) Do
            Begin
            w := (Until_ - GetTickCount64 + 999) Div 1000;
            Msg := 'Multi-dial, try ' + IntToStr((Rd - 1) * L.Count + n + 1) + ' of ' + IntToStr(St.Rounds * L.Count) + ', next in ' + IntToStr(w) + ' s, Esc stops: ' + Why2;
            Draw;
            KeyWait(100);
            While KeyRead(K) Do
              If K.code = kcEsc Then
                Stop := True;
            End;
          If Stop Then
            Begin
            Msg := 'multi-dial stopped';
            Exit;
            End;
          End;
        End;
      Msg := 'multi-dial: nobody answered (' + Why2 + ')';
    Finally
      L.Free;
    End;
    End;

  Procedure Add;
    Begin
    ConnNewEntry(E);
    If EditEntry(E, 'Add a system') Then
      Begin
      If St.Book.Find(E.Name) >= 0 Then
        Begin
        Msg := 'there is a system of that name already';
        Exit;
        End;
      Sel := St.Book.Add(E);
      If Sorted Then
        Begin
        Q := E.Name;
        St.Book.SortByName;
        Sel := St.Book.Find(Q);
        End;
      Save;
      End;
    End;

  Procedure Edit;
    Begin
    If St.Book.Count = 0 Then
      Exit;
    E := St.Book.Items[Sel];
    If EditEntry(E, 'Edit ' + E.Name) Then
      Begin
      Idx := St.Book.Find(E.Name);
      If (Idx >= 0) And (Idx <> Sel) Then
        Begin
        Msg := 'there is a system of that name already';
        Exit;
        End;
      St.Book.Items[Sel] := E;
      Save;
      End;
    End;

  Procedure Del;
    Begin
    If St.Book.Count = 0 Then
      Exit;
    If Confirm('Delete ' + St.Book.Items[Sel].Name + '?') Then
      Begin
      St.Book.Delete(Sel);
      If Sel >= St.Book.Count Then Sel := St.Book.Count - 1;
      If Sel < 0 Then Sel := 0;
      Save;
      End;
    End;

  Procedure Find;
    Var
      Text: String;
      n: Integer;

    Begin
    Text := '';
    If Not AskLine('Find', 'A part of the name or the host:', Text, False, 60) Then
      Exit;
    Text := LowerCase(Trim(Text));
    If Text = '' Then
      Exit;
    For n := 1 To St.Book.Count Do
      Begin
      i := (Sel + n) Mod St.Book.Count;
      If (Pos(Text, LowerCase(St.Book.Items[i].Name)) > 0) Or (Pos(Text, LowerCase(St.Book.Items[i].Host)) > 0) Then
        Begin
        Sel := i;
        Exit;
        End;
      End;
    Msg := 'nothing found';
    End;

  Procedure SortIt;
    Begin
    If St.Book.Count = 0 Then
      Exit;
    Q := St.Book.Items[Sel].Name;
    If Sorted Then
      Begin
      St.Book.SortByLast;
      Sorted := False;
      Msg := 'sorted by the last call';
      End
    Else
      Begin
      St.Book.SortByName;
      Sorted := True;
      Msg := 'sorted by name';
      End;
    Sel := St.Book.Find(Q);
    If Sel < 0 Then Sel := 0;
    End;

  Procedure ChangePassword;
    Var
      A, B: String;

    Begin
    A := '';
    B := '';
    If Not AskLine('Start password', 'New start password (empty: the phone book is not sealed):', A, True, 100) Then
      Exit;
    If Not AskLine('Start password', 'Once more:', B, True, 100) Then
      Exit;
    If A <> B Then
      Begin
      Msg := 'the two are not the same: the password is not changed';
      Exit;
      End;
    St.Password := A;
    St.Sealed := A <> '';
    Save;
    If Msg = '' Then
      If St.Sealed Then Msg := 'the phone book is sealed with the new password' Else Msg := 'the phone book is not sealed';
    End;

  Begin
  Marks := TStringList.Create;
  Done := False;
  NeedFull := False;
  Top := 0;
  Sel := 0;
  Sorted := True;
  Msg := '';
  InitVideo;
  KeysInit;
  ClearScreen;                          {the terminal may hold anything: the whole screen is sent, not only what differs from a blank one}
  NeedFull := True;
  Try
    If (ScrW < 60) Or (ScrH < 12) Then
      Begin
      Msg := 'the terminal is small: at least 60 x 12 is needed';
      End;
    While (Not Done) And (Not Hangup) Do
      Begin
      If St.Book.Count > 0 Then
        Begin
        If Sel >= St.Book.Count Then Sel := St.Book.Count - 1;
        End
      Else
        Sel := 0;
      Draw;
      If Not WaitKey(K) Then
        Break;
      Msg := '';
      Case K.code Of
        kcUp: If Sel > 0 Then Dec(Sel);
        kcDown: If Sel < St.Book.Count - 1 Then Inc(Sel);
        kcPgUp: Sel := Sel - (ScrH - 6);
        kcPgDn: Sel := Sel + (ScrH - 6);
        kcHome: Sel := 0;
        kcEnd: Sel := St.Book.Count - 1;
        kcEnter: Dial;
        kcF: If K.n = 1 Then Help Else If K.n = 10 Then Done := True;
        kcEsc: Begin
               M := PopupMenu(['Dial               Enter', 'Add                A', 'Edit               E', 'Delete             D', 'Find               F', 'Sort               S', 'Start password     P', 'Help               F1', 'Quit               Q'], 'daedfspHq');
               Case M Of
                 0: Dial;
                 1: Add;
                 2: Edit;
                 3: Del;
                 4: Find;
                 5: SortIt;
                 6: ChangePassword;
                 7: Help;
                 8: Done := True;
                 End;
               End;
        Else
          If (K.code = kcChar) And (mAlt In K.mods) And (LowerCase(K.ch) = 'x') Then
            Done := True
          Else If Plain(K) Then
            Case LowerCase(K.ch)[1] Of
              ' ': Mark;
              'm': Multi;
              'a': Add;
              'e': Edit;
              'd': Del;
              'f', '/': Find;
              's': SortIt;
              'p': ChangePassword;
              'q': Done := True;
              '?': Help;
              End;
        End;
      If Sel < 0 Then Sel := 0;
      If Sel >= St.Book.Count Then Sel := St.Book.Count - 1;
      If Sel < 0 Then Sel := 0;
      End;
  Finally
    KeysDone;
    DoneVideo;
    fpWrite(1, #27'[0m'#27'[2J'#27'[H', 11);          {leave a clean screen}
    Marks.Free;
  End;
  End;


End.
