Unit MKConnCall;   {one call of mkconnect: the connection, the screen of the terminal passed through, the keys, the status bar (MKCONNECT-PLAN.md phase 1)}

{$MODE OBJFPC}
{$H+}

{
  Pass-through: what the system sends is converted (CP437 to UTF-8, with the colour guard of the BBS) and written to the user's own terminal, which does the emulation.  The bottom row of the terminal is the status
  bar, kept apart with a scroll region.  What is typed goes to the system as the system expects it: a letter that is not in ASCII becomes its CP437 code, the escape sequences of the terminal (arrow keys, the answers
  to the questions a BBS asks the terminal) go through as they are.

  Keys of the call:  Ctrl-]  the attention key: a one line menu     Alt-P  send the password of this system     Alt-N  send the login name
                     Alt-H  hang up     Alt-X  hang up and leave     Alt-D  hang up and go to the dialer     Alt-C  capture on / off     Alt-T  the character set of the display
  (an Alt key is an Esc and a letter that come together).  In the menu:  H hang up  X leave  D dialer  C capture  P password  N name  ] send Ctrl-]  T character set  ? help  Esc cancel.
}

Interface

Uses MKConnBook;

Const
  crDone = 0;                          {the call ended: back to the dialer}
  crFailed = 1;                        {it did not connect (Msg says why)}
  crQuit = 2;                          {leave the program}

Type
  TCallOpts = Record
    TermUtf8: Boolean;                 {the terminal wants UTF-8 (the CP437 of a system is converted)}
    CapDir: String;                    {where a capture file is made}
    LogFile: String;                   {a line for each call ('' = none)}
    ConnectMs: LongInt;
  End;

Function RunCall(Var E: TConnEntry; Const Opts: TCallOpts; Out Msg: String): Integer;

Implementation

Uses SysUtils, BaseUnix, Termio, Classes, MKComAbs, MKComClient, MKComFd, MKComTelnet, MKCp437, MKSgr, MKTuiCp;

Const
  CtrlRB = #29;                        {Ctrl-]}

Var
  Winch, TermSig: Boolean;


Procedure OnWinch(Sig: cInt); cdecl;
  Begin
  Winch := True;
  End;


Procedure OnTerm(Sig: cInt); cdecl;
  Begin
  TermSig := True;
  End;


Procedure TtyWrite(Const S: String);
  Var
    Done, N: LongInt;

  Begin
  Done := 0;
  While Done < Length(S) Do
    Begin
    N := fpWrite(1, S[Done + 1], Length(S) - Done);
    If N <= 0 Then
      Begin
      If fpGetErrno = ESysEINTR Then Continue;
      Exit;
      End;
    Inc(Done, N);
    End;
  End;


Function TtySize(Out Cols, Rows: Word): Boolean;
  Var
    W: TWinSize;

  Begin
  Result := False;
  Cols := 80;
  Rows := 24;
  If fpIoctl(1, TIOCGWINSZ, @W) = 0 Then
    If (W.ws_col > 0) And (W.ws_row > 1) Then
      Begin
      Cols := W.ws_col;
      Rows := W.ws_row;
      Result := True;
      End;
  End;


Function NetFd(S: AbsComPtr): LongInt;
  {the descriptor the session reads from (to wait for the network and the keys together)}
  Begin
  Result := -1;
  If TypeOf(S^) = TypeOf(TelnetComObj) Then
    Begin
    If TypeOf(TelnetComPtr(S)^.Inner^) = TypeOf(FdComObj) Then
      Result := FdComPtr(TelnetComPtr(S)^.Inner)^.InFd;
    End
  Else If TypeOf(S^) = TypeOf(FdComObj) Then
    Result := FdComPtr(S)^.InFd;
  End;


Function Elapsed(Secs: LongInt): String;
  Begin
  Result := Format('%.2d:%.2d:%.2d', [Secs Div 3600, (Secs Div 60) Mod 60, Secs Mod 60]);
  End;


Function RunCall(Var E: TConnEntry; Const Opts: TCallOpts; Out Msg: String): Integer;
  Var
    S: AbsComPtr;
    Err: ShortString;
    Cols, Rows: Word;
    Saved, Raw: Termios;
    HaveSaved: Boolean;
    Started, LastDraw: Int64;
    Guard: SgrGuardObj;
    Convert: Boolean;                  {the system sends CP437 and the terminal wants UTF-8}
    Cap: TFileStream;
    CapName, Note: String;
    NoteUntil: Int64;
    InMenu, EscPending, Done: Boolean;
    EscAt: Int64;
    U8: String;
    U8Need: Integer;
    Sent, Got: Int64;
    Why: String;
    ConnOk: Boolean;
    Buf: Array[0..4095] Of Byte;
    Fds: Array[0..1] Of TPollFd;
    i, N, NetF, NFds: LongInt;
    Telnet_: Boolean;

  Function Now_: Int64;
    Begin
    Result := fpTime;
    End;

  Function Ticks: Int64;
    Begin
    Result := GetTickCount64;
    End;

  Procedure SetNote(Const T: String);
    Begin
    Note := T;
    NoteUntil := Now_ + 4;
    End;

  Function Guarded(Const T: String; W: Integer): String;
    {the text cut or padded to the width, as UTF-8 for the terminal}
    Var
      L: String;

    Begin
    L := T;
    If Utf8Len(L) > W Then
      L := Copy(L, 1, W);
    While Utf8Len(L) < W Do
      L := L + ' ';
    Result := L;
    End;

  Procedure DrawBar(Const Text: String);
    {the bottom row: reverse video, then the colours and the cursor back where they were}
    Begin
    TtyWrite(#27'7'#27'[' + IntToStr(Rows) + ';1H'#27'[0;7m' + Guarded(Text, Cols) + #27'[0m'#27'8');
    End;

  Procedure Status;
    Var
      T: String;

    Begin
    If Guard.State <> 0 Then
      Exit;                            {in the middle of an escape sequence of the system: not now}
    If (Note <> '') And (Now_ < NoteUntil) Then
      T := ' ' + Note
    Else
      Begin
      Note := '';
      T := ' ' + E.Name + ' | ' + E.Host + ':' + IntToStr(E.Port) + ' | ' + Elapsed(Now_ - Started) + ' | ' + Copy('CP437', 1, 5 * Ord(Not E.Utf8)) + Copy('UTF-8', 1, 5 * Ord(E.Utf8));
      If Cap <> Nil Then
        T := T + ' | CAPTURE';
      T := T + ' | Ctrl-] menu';
      End;
    DrawBar(T);
    LastDraw := Now_;
    End;

  Procedure SetRegion;
    Begin
    TtyWrite(#27'[1;' + IntToStr(Rows - 1) + 'r');
    End;

  Procedure Clear_;
    Begin
    TtyWrite(#27'[0m'#27'[2J'#27'[1;1H');
    End;

  Procedure Sys(Const T: String);
    {to the system}
    Begin
    S^.SendStr(T);
    S^.FlushOut;
    Inc(Sent, Length(T));
    End;

  Procedure CapOff;
    Begin
    If Cap <> Nil Then
      Begin
      Cap.Free;
      Cap := Nil;
      SetNote('capture off: ' + CapName);
      End;
    End;

  Procedure CapToggle;
    Var
      FN: String;

    Begin
    If Cap <> Nil Then
      Begin
      CapOff;
      Exit;
      End;
    FN := IncludeTrailingPathDelimiter(Opts.CapDir) + StringReplace(E.Name, '/', '_', [rfReplaceAll]) + '-' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.cap';
    Try
      Cap := TFileStream.Create(FN, fmCreate);
      CapName := FN;
      SetNote('capture on: ' + FN);
    Except
      Cap := Nil;
      SetNote('the capture file cannot be made: ' + FN);
    End;
    End;

  Procedure ToSystem(B: Byte);
    {one byte the terminal sent: a UTF-8 letter becomes CP437 for a system that speaks it}
    Var
      Cp: Cardinal;
      K: Integer;
      T: String;

    Begin
    If (Not Opts.TermUtf8) Or E.Utf8 Then
      Begin
      Sys(Chr(B));
      Exit;
      End;
    If U8Need > 0 Then
      Begin
      U8 := U8 + Chr(B);
      Dec(U8Need);
      If U8Need = 0 Then
        Begin
        K := Utf8Decode(@U8[1], Length(U8), Cp);
        If K = 0 Then
          Sys('?')
        Else
          Begin
          K := UniToCp437(Cp);
          If K < 0 Then Sys('?') Else Sys(Chr(K));
          End;
        U8 := '';
        End;
      Exit;
      End;
    If B >= $F0 Then
      Begin
      U8 := Chr(B);
      U8Need := 3;
      End
    Else If B >= $E0 Then
      Begin
      U8 := Chr(B);
      U8Need := 2;
      End
    Else If B >= $C0 Then
      Begin
      U8 := Chr(B);
      U8Need := 1;
      End
    Else
      Sys(Chr(B));
    End;

  Procedure Menu;
    Begin
    InMenu := True;
    DrawBar(' H)angup  X) leave  D)ialer  C)apture  P)assword  N)ame  ]) send Ctrl-]  T) character set  ?) help  Esc) cancel');
    End;

  Procedure Command(C: Char);
    {an Alt key or a letter of the menu}
    Begin
    Case LowerCase(C) Of
      'h', 'd': Begin Result := crDone; Done := True; End;
      'x': Begin Result := crQuit; Done := True; End;
      'p': Begin
           If E.Password = '' Then
             SetNote('this system has no password in the phone book')
           Else
             Sys(E.Password + #13);
           End;
      'n': Begin
           If E.Login = '' Then
             SetNote('this system has no login name in the phone book')
           Else
             Sys(E.Login + #13);
           End;
      'c': CapToggle;
      't': Begin
           E.Utf8 := Not E.Utf8;
           Convert := (Not E.Utf8) And Opts.TermUtf8;
           SetNote('the system is taken to send ' + Copy('CP437', 1, 5 * Ord(Not E.Utf8)) + Copy('UTF-8', 1, 5 * Ord(E.Utf8)));
           End;
      ']': Sys(CtrlRB);
      '?': SetNote('Ctrl-] menu  Alt-P password  Alt-N name  Alt-C capture  Alt-H hang up  Alt-X leave  Alt-D dialer');
      Else
        Begin
        If Not InMenu Then
          Sys(#27 + C);                {an Alt letter that is no command: the system may have a use for it}
        End;
      End;
    Status;
    End;

  Procedure Keys(Const B: Array Of Byte; Count: LongInt);
    Var
      k: LongInt;
      C: Byte;

    Begin
    For k := 0 To Count - 1 Do
      Begin
      C := B[k];
      If InMenu Then
        Begin
        InMenu := False;
        If C = 27 Then
          Status
        Else
          Command(Chr(C));
        Continue;
        End;
      If EscPending Then
        Begin
        EscPending := False;
        If Chr(C) In ['a'..'z', 'A'..'Z'] Then
          Begin
          Command(Chr(C));
          Continue;
          End;
        Sys(#27);
        ToSystem(C);
        Continue;
        End;
      If C = 29 Then
        Menu
      Else If C = 27 Then
        Begin
        EscPending := True;
        EscAt := Ticks;
        End
      Else
        ToSystem(C);
      End;
    End;

  Procedure Display(Count: LongInt);
    Var
      k: LongInt;
      O: String;
      B: Byte;

    Begin
    O := '';
    Inc(Got, Count);
    For k := 0 To Count - 1 Do
      Begin
      B := Buf[k];
      If Cap <> Nil Then
        Cap.WriteBuffer(B, 1);
      If Convert Then
        Begin
        O := O + Guard.First;
        If B >= 128 Then
          O := O + Cp437ToUtf8(B)
        Else
          O := O + Chr(B) + Guard.Feed(Chr(B));
        End
      Else
        O := O + Chr(B);
      End;
    TtyWrite(O);
    End;

  Procedure LogCall(Const Ended: String);
    Var
      T: TextFile;

    Begin
    If Opts.LogFile = '' Then
      Exit;
    Try
      AssignFile(T, Opts.LogFile);
      If FileExists(Opts.LogFile) Then Append(T) Else Rewrite(T);
      WriteLn(T, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), '  ', E.Name, '  ', E.Host, ':', E.Port, '  ', ConnKindName(E.Kind), '  on line ', Elapsed(Now_ - Started), '  sent ', Sent, '  received ', Got, '  ', Ended);
      CloseFile(T);
      fpChmod(Opts.LogFile, &600);
    Except
      ;
    End;
    End;

  Begin
  Result := crDone;
  Msg := '';
  Sent := 0;
  Got := 0;
  Cap := Nil;
  Note := '';
  InMenu := False;
  EscPending := False;
  Done := False;
  U8 := '';
  U8Need := 0;
  Telnet_ := E.Kind = ckTelnet;
  If E.Kind In [ckTelnets, ckSsh] Then
    Begin
    Msg := ConnKindName(E.Kind) + ' is not in this version of mkconnect yet';
    Exit(crFailed);
    End;
  If E.Host = '' Then
    Begin
    Msg := 'the entry has no host';
    Exit(crFailed);
    End;
  TtySize(Cols, Rows);
  ClientTerm := 'ansi';
  ClientCols := Cols;
  ClientRows := Rows - 1;
  TtyWrite('Connecting to ' + E.Host + ':' + IntToStr(E.Port) + ' ...'#13#10);
  S := ConnectTcp(E.Host, E.Port, Opts.ConnectMs, Telnet_, Err);
  If S = Nil Then
    Begin
    Msg := 'cannot connect to ' + E.Host + ':' + IntToStr(E.Port) + ': ' + Err;
    Exit(crFailed);
    End;
  Inc(E.Calls);
  E.Last := Now_;
  Started := Now_;
  Guard.Init;
  Convert := (Not E.Utf8) And Opts.TermUtf8;
  NetF := NetFd(S);
  Winch := False;
  TermSig := False;
  fpSignal(SIGWINCH, @OnWinch);
  fpSignal(SIGTERM, @OnTerm);
  fpSignal(SIGHUP, @OnTerm);
  HaveSaved := TCGetAttr(0, Saved) = 0;
  If HaveSaved Then
    Begin
    Raw := Saved;
    CFMakeRaw(Raw);
    Raw.c_cc[VMIN] := 0;
    Raw.c_cc[VTIME] := 0;
    TCSetAttr(0, TCSANOW, Raw);
    End;
  Try
    Clear_;
    SetRegion;
    Status;
    TtyWrite(#27'[1;1H');
    ConnOk := True;
    While (Not Done) And (Not TermSig) Do
      Begin
      If Winch Then
        Begin
        Winch := False;
        TtySize(Cols, Rows);
        SetRegion;
        Status;
        End;
      If Not S^.GetCarrier Then
        Begin
        If S^.InEmpty Then
          Begin
          ConnOk := False;
          Break;
          End;
        End;
      { what the system sent }
      N := 0;
      While (Not S^.InEmpty) And (N < SizeOf(Buf)) Do
        Begin
        Buf[N] := Ord(S^.GetChar);
        Inc(N);
        End;
      If N > 0 Then
        Begin
        Display(N);
        Continue;
        End;
      { wait for the network and the keys together }
      NFds := 1;
      Fds[0].fd := 0;
      Fds[0].events := POLLIN;
      Fds[0].revents := 0;
      If NetF >= 0 Then
        Begin
        Fds[1].fd := NetF;
        Fds[1].events := POLLIN;
        Fds[1].revents := 0;
        NFds := 2;
        End;
      i := 250;
      If EscPending Then
        i := 30;
      If fpPoll(@Fds[0], NFds, i) > 0 Then
        Begin
        If (Fds[0].revents And POLLIN) <> 0 Then
          Begin
          N := fpRead(0, Buf, SizeOf(Buf));
          If N > 0 Then
            Keys(Buf, N)
          Else If (N = 0) Then
            Done := True;                  {the terminal is gone}
          End
        Else If (Fds[0].revents And (POLLHUP Or POLLERR)) <> 0 Then
          Done := True;
        End;
      If EscPending And (Ticks - EscAt >= 30) Then
        Begin
        EscPending := False;
        Sys(#27);                          {a lone Esc}
        End;
      If (Now_ <> LastDraw) And (Not InMenu) Then
        Status;
      End;
    If Not ConnOk Then
      Begin
      Result := crDone;
      TtyWrite(#27'[' + IntToStr(Rows - 1) + ';1H'#13#10'[the system closed the connection: press a key]');
      LogCall('closed by the system');
      Msg := 'the system closed the connection';
      Why := '';
      N := 0;
      Repeat
        If fpPoll(@Fds[0], 1, 100) > 0 Then
          N := fpRead(0, Buf, SizeOf(Buf));
      Until (N > 0) Or TermSig;
      End
    Else If TermSig Then
      Begin
      Result := crQuit;
      LogCall('the terminal ended the program');
      End
    Else
      LogCall(Copy('hung up', 1, 7 * Ord(Result = crDone)) + Copy('left the program', 1, 16 * Ord(Result = crQuit)));
  Finally
    CapOff;
    S^.Hangup;
    Dispose(S, Done);
    TtyWrite(#27'[0m'#27'[r'#27'[' + IntToStr(Rows) + ';1H'#27'[2K'#13#10);
    If HaveSaved Then
      TCSetAttr(0, TCSANOW, Saved);
    fpSignal(SIGWINCH, SignalHandler(SIG_DFL));
  End;
  End;


End.
