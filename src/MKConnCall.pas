{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKConnCall;   {one call of mkconnect: the connection, the screen of the terminal passed through, the keys, the status bar (MKCONNECT-PLAN.md phase 1)}

{$MODE OBJFPC}
{$H+}

{
  Pass-through: what the system sends is converted (CP437 to UTF-8, with the colour guard of the BBS) and written to the user's own terminal, which does the emulation.  The bottom row of the terminal is the status
  bar, kept apart with a scroll region.  What is typed goes to the system as the system expects it: a letter that is not in ASCII becomes its CP437 code, the escape sequences of the terminal (arrow keys, the answers
  to the questions a BBS asks the terminal) go through as they are.

  Keys of the call:  Ctrl-]  the attention key: a one line menu     Alt-P  send the password of this system     Alt-N  send the login name
                     Alt-H  hang up     Alt-X  hang up and leave     Alt-D  hang up and go to the dialer     Alt-C  capture on / off     Alt-T  the character set of the display
                     Alt-U  upload files to the system     Alt-L  download (receive) from the system
  (an Alt key is an Esc and a letter that come together).  In the menu:  H hang up  X leave  D dialer  C capture  P password  N name  U upload  L download  ] send Ctrl-]  T character set  ? help  Esc cancel.

  Transfers (MKProt: Zmodem, Ymodem, Ymodem-G, Xmodem, Xmodem-1K) run on the session while the screen shows only the bottom row with the progress; Esc or Ctrl-X cancels.  A Zmodem start that the system
  sends (the "**^XB00" of a Zmodem sender) is taken up at once: the files come into the download folder.
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
    DownDir: String;                   {where the files of a download come}
    ScriptName: String;                {a script given on the command line (it wins over the one of the entry)}
    ScriptDir: String;                 {where the scripts are kept}
    ConnectMs: LongInt;
  End;

Function RunCall(Var EIn: TConnEntry; Const OIn: TCallOpts; Out MsgOut: String): Integer;

Implementation

Uses SysUtils, BaseUnix, Termio, Classes, MKComAbs, MKComClient, MKComFd, MKComTelnet, MKCp437, MKSgr, MKTuiCp, MKProt, MKVideo, MKHubScr, ctypes;

{ the pseudo terminal functions of the C library }
Function posix_openpt(Flags: LongInt): LongInt; cdecl; external 'c' name 'posix_openpt';
Function grantpt(Fd: LongInt): LongInt; cdecl; external 'c' name 'grantpt';
Function unlockpt(Fd: LongInt): LongInt; cdecl; external 'c' name 'unlockpt';
Function ptsname(Fd: LongInt): PChar; cdecl; external 'c' name 'ptsname';
Function execvp(Prog: PChar; Argv: PPChar): LongInt; cdecl; external 'c' name 'execvp';

Const
  CtrlRB = #29;                        {Ctrl-]}

Var
  Winch, TermSig: Boolean;
  Cols, Rows: Word;
  { the transfer in progress, for the progress hook of MKProt (a plain procedure: it cannot be one of RunCall) }
  XTitle, XName, XMsg: String;
  XSize, XDone, XErr, XCps, XSecs: LongInt;
  XDrawAt: Int64;
  XCancelled: Boolean;
  XferOk: Boolean;
  SshPid: LongInt;                     {the ssh child (0: none)}
  SshFd: LongInt;                      {the master side of its pseudo terminal}
  WsB: Array[0..3] Of Word;


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


Function Ticks: Int64;
  Begin
  Result := GetTickCount64;
  End;


Function Commas(N: LongInt): String;
  Var
    S: String;
    i: Integer;

  Begin
  S := IntToStr(N);
  Result := '';
  For i := 1 To Length(S) Do
    Begin
    If (i > 1) And ((Length(S) - i + 1) Mod 3 = 0) Then
      Result := Result + ',';
    Result := Result + S[i];
    End;
  End;


Procedure XDraw(Force: Boolean);
  Var
    T: String;

  Begin
  If (Not Force) And (Ticks - XDrawAt < 120) Then
    Exit;
  XDrawAt := Ticks;
  T := ' ' + XTitle + ' ' + XName;
  If XSize > 0 Then
    T := T + '  ' + Commas(XDone) + ' of ' + Commas(XSize)
  Else If XDone > 0 Then
    T := T + '  ' + Commas(XDone);
  If XCps > 0 Then
    T := T + '  ' + Commas(XCps) + ' cps';
  If XErr > 0 Then
    T := T + '  errors ' + IntToStr(XErr);
  If XMsg <> '' Then
    T := T + '  ' + XMsg;
  T := T + '  (Esc cancels)';
  DrawBar(T);
  End;


Procedure XHook(What: Char; Const S: ShortString; N: LongInt);
  Begin
  Case What Of
    'N': XName := S;
    'S': XSize := N;
    'L': XDone := N;
    'E': XErr := N;
    'T': XSecs := N;
    'C': XCps := N;
    'M': XMsg := Copy(S, 1, 40);
    End;
  XDraw(What = 'M');
  End;


Function SshOpen(Const Host: String; Port: Word; Const User: String; Out Err: ShortString): AbsComPtr;
  {the system ssh on a pseudo terminal: what it writes is the session; its questions (a password, a host key) are answered on the terminal}
  Var
    M, Sl: LongInt;
    Name: String;
    Args: Array[0..9] Of PChar;
    NA: Integer;
    Ws: Array[0..3] Of Word;
    PortS, Target: String;
    Raw: FdComPtr;

  Begin
  Result := Nil;
  Err := '';
  M := posix_openpt(2 Or $100);          {O_RDWR, O_NOCTTY}
  If (M < 0) Or (grantpt(M) <> 0) Or (unlockpt(M) <> 0) Then
    Begin
    Err := 'no pseudo terminal';
    Exit;
    End;
  Name := StrPas(ptsname(M));
  Ws[0] := ClientRows; Ws[1] := ClientCols; Ws[2] := 0; Ws[3] := 0;
  fpIoctl(M, TIOCSWINSZ, @Ws);
  PortS := IntToStr(Port);
  Target := Host;
  If User <> '' Then
    Target := User + '@' + Host;
  SshPid := fpFork;
  If SshPid < 0 Then
    Begin
    Err := 'fork failed';
    fpClose(M);
    Exit;
    End;
  If SshPid = 0 Then
    Begin
    fpSetSid;
    Sl := fpOpen(PChar(Name), O_RDWR);
    fpIoctl(Sl, TIOCSCTTY, Nil);
    fpDup2(Sl, 0); fpDup2(Sl, 1); fpDup2(Sl, 2);
    If Sl > 2 Then fpClose(Sl);
    fpClose(M);
    NA := 0;
    Args[NA] := 'ssh'; Inc(NA);
    Args[NA] := '-p'; Inc(NA);
    Args[NA] := PChar(PortS); Inc(NA);
    Args[NA] := '-o'; Inc(NA);
    Args[NA] := 'ServerAliveInterval=30'; Inc(NA);
    Args[NA] := PChar(Target); Inc(NA);
    Args[NA] := Nil;
    execvp('ssh', @Args[0]);
    fpExit(127);
    End;
  SshFd := M;
  New(Raw, InitFd(M, M));
  Raw^.SetRemoteAddr(Host + ':' + PortS);
  If Not Raw^.OpenSession Then
    Begin
    Dispose(Raw, Done);
    Err := 'the session did not open';
    Exit;
    End;
  Result := Raw;
  End;


Procedure SshEnd;
  Var
    St: cint;

  Begin
  If SshPid > 0 Then
    Begin
    fpKill(SshPid, SIGHUP);
    fpWaitPid(SshPid, St, 0);
    SshPid := 0;
  SshFd := -1;
    End;
  End;


Function CancelIn(Const B: Array Of Byte; N: LongInt): Boolean;
  {Ctrl-X and Ctrl-C cancel; so does an Esc that does not start a key of the terminal (Esc [ or Esc O)}
  Var
    i: LongInt;

  Begin
  Result := False;
  For i := 0 To N - 1 Do
    Case B[i] Of
      24, 3: Result := True;
      27: If (i = N - 1) Or ((B[i + 1] <> 91) And (B[i + 1] <> 79)) Then
            Result := True;
      End;
  End;


Function XCancel: Boolean;
  {the keyboard during a transfer: Esc, Ctrl-X or Ctrl-C cancels, whatever else was typed is thrown away}
  Var
    P: TPollFd;
    B: Array[0..63] Of Byte;
    N, i: LongInt;

  Begin
  Result := XCancelled;                {once cancelled it stays so for the rest of the transfer}
  If Result Then
    Exit;
  P.fd := 0;
  P.events := POLLIN;
  P.revents := 0;
  While fpPoll(@P, 1, 0) > 0 Do
    Begin
    N := fpRead(0, B, SizeOf(B));
    If N <= 0 Then
      Break;
    If CancelIn(B, N) Then
      Result := True;
    P.revents := 0;
    End;
  If Result Then
    XCancelled := True;
  End;


Var
  E: TConnEntry;                       {the call: the entry, the options, what is to be said, how it ends (the procedures below are not nested: a script calls some of them)}
  Opts: TCallOpts;
  Msg: String;
  CallResult: Integer;
  S: AbsComPtr;
  Err: ShortString;
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
  AutoZ: Boolean;                    {a Zmodem sender announced itself in what came}
  ZState: Integer;
  DefProto: Char;


  Function Now_: Int64;
    Begin
    Result := fpTime;
    End;

  Procedure SetNote(Const T: String);
    Begin
    Note := T;
    NoteUntil := Now_ + 4;
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

  Procedure Display(Count: LongInt); Forward;

  Procedure Pump;
    {what the system sent while a question is asked: shown at once}
    Var
      N: LongInt;

    Begin
    N := 0;
    While (Not S^.InEmpty) And (N < SizeOf(Buf)) Do
      Begin
      Buf[N] := Ord(S^.GetChar);
      Inc(N);
      End;
    If N > 0 Then
      Display(N);
    End;

  Function AskBar(Const Prompt: String; Var Value: String): Boolean;
    {a line typed on the bottom row (the system's text goes on being shown above it); Enter takes it, Esc gives up}
    Var
      P: Array[0..1] Of TPollFd;
      B: Array[0..63] Of Byte;
      N, i, k: LongInt;
      Fin: Boolean;

    Begin
    Result := False;
    Fin := False;
    DrawBar(' ' + Prompt + ' ' + Value + '_');
    While (Not Fin) And (Not TermSig) Do
      Begin
      P[0].fd := 0; P[0].events := POLLIN; P[0].revents := 0;
      k := 1;
      If NetF >= 0 Then
        Begin
        P[1].fd := NetF; P[1].events := POLLIN; P[1].revents := 0;
        k := 2;
        End;
      If fpPoll(@P[0], k, 200) > 0 Then
        Begin
        If (k = 2) And ((P[1].revents And POLLIN) <> 0) Then
          Begin
          Pump;
          DrawBar(' ' + Prompt + ' ' + Value + '_');
          End;
        If (P[0].revents And POLLIN) <> 0 Then
          Begin
          N := fpRead(0, B, SizeOf(B));
          If N <= 0 Then
            Exit;
          For i := 0 To N - 1 Do
            Case B[i] Of
              13, 10: Begin Result := True; Fin := True; End;
              27: Fin := True;
              127, 8: Begin
                      While (Value <> '') And ((Ord(Value[Length(Value)]) And $C0) = $80) Do
                        Delete(Value, Length(Value), 1);
                      Delete(Value, Length(Value), 1);
                      End;
              21: Value := '';
              Else
                If B[i] >= 32 Then
                  Value := Value + Chr(B[i]);
              End;
          DrawBar(' ' + Prompt + ' ' + Value + '_');
          End;
        End;
      End;
    End;

  Function ChooseProto(Def: Char): Char;
    {a key: Z Zmodem, Y Ymodem, G Ymodem-G, X Xmodem, 1 Xmodem-1K; Enter takes the first offered; Esc: none}
    Var
      P: Array[0..1] Of TPollFd;
      B: Array[0..15] Of Byte;
      N, k: LongInt;
      C: Char;

    Begin
    Result := #0;
    DrawBar(' Protocol: Z)modem  Y)modem  G) Ymodem-G  X)modem  1) Xmodem-1K    Enter = ' + ConnProtoName(Def) + '    Esc cancels');
    While Not TermSig Do
      Begin
      P[0].fd := 0; P[0].events := POLLIN; P[0].revents := 0;
      k := 1;
      If NetF >= 0 Then
        Begin
        P[1].fd := NetF; P[1].events := POLLIN; P[1].revents := 0;
        k := 2;
        End;
      If fpPoll(@P[0], k, 200) > 0 Then
        Begin
        If (k = 2) And ((P[1].revents And POLLIN) <> 0) Then
          Begin
          Pump;
          DrawBar(' Protocol: Z)modem  Y)modem  G) Ymodem-G  X)modem  1) Xmodem-1K    Enter = ' + ConnProtoName(Def) + '    Esc cancels');
          End;
        If (P[0].revents And POLLIN) <> 0 Then
          Begin
          N := fpRead(0, B, SizeOf(B));
          If N <= 0 Then
            Exit;
          C := UpCase(Chr(B[0]));
          If (B[0] = 13) Or (B[0] = 10) Then
            Exit(Def);
          If B[0] = 27 Then
            Exit;
          If C In ['Z', 'Y', 'G', 'X', '1'] Then
            Exit(C);
          End;
        End;
      End;
    End;

  Function Plain(Const T: String): String;
    {only printable ASCII: text of a system must not break the log or the bar}
    Var
      i: Integer;

    Begin
    Result := T;
    For i := 1 To Length(Result) Do
      If (Result[i] < ' ') Or (Result[i] > '~') Then
        Result[i] := ' ';
    End;

  Procedure LogXfer(Const What, Names, Res: String);
    Var
      T: TextFile;

    Begin
    If Opts.LogFile = '' Then
      Exit;
    Try
      AssignFile(T, Opts.LogFile);
      If FileExists(Opts.LogFile) Then Append(T) Else Rewrite(T);
      WriteLn(T, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), '  ', E.Name, '  ', What, '  ', Names, '  ', Plain(Res));
      CloseFile(T);
    Except
      ;
    End;
    End;

  Procedure Xfer(Upload: Boolean; Proto: Char; Const Names, SaveAs: String);
    {a transfer on the session: the files of Names (an upload) or the files the system sends, into the download folder}
    Var
      P: ProtObj;
      OldSess: AbsComPtr;
      OldPort: Word;
      OldRate: LongInt;
      Files: TStringList;
      Tok, W, Dir, Cur, Res, Listed: String;
      i, k: Integer;
      Sr: TSearchRec;
      Quote, Ok: Boolean;
      Bad: Boolean;
      Pb: Array[0..255] Of Byte;
      Pl: TPollFd;

    Begin
    XferOk := False;
    Files := TStringList.Create;
    Try
      If Upload Then
        Begin
        W := '';
        Quote := False;
        For i := 1 To Length(Names) + 1 Do
          If (i > Length(Names)) Or ((Names[i] = ' ') And Not Quote) Then
            Begin
            If W <> '' Then
              Begin
              If (Pos('*', W) > 0) Or (Pos('?', W) > 0) Then
                Begin
                If FindFirst(W, faAnyFile And Not faDirectory, Sr) = 0 Then
                  Begin
                  Repeat
                    Files.Add(ExpandFileName(ExtractFilePath(W) + Sr.Name));
                  Until FindNext(Sr) <> 0;
                  FindClose(Sr);
                  End;
                End
              Else If FileExists(W) Then
                Files.Add(ExpandFileName(W))
              Else
                Begin
                SetNote(W + ' is not there');
                Exit;
                End;
              End;
            W := '';
            End
          Else If Names[i] = '"' Then
            Quote := Not Quote
          Else
            W := W + Names[i];
        If Files.Count = 0 Then
          Begin
          SetNote('no file to send');
          Exit;
          End;
        Dir := ExtractFilePath(Files[0]);
        Bad := False;
        For i := 1 To Files.Count - 1 Do
          If ExtractFilePath(Files[i]) <> Dir Then
            Bad := True;
        If Bad Then
          Begin
          SetNote('the files must be in one folder');
          Exit;
          End;
        If (Files.Count > 1) And (Proto In ['X', '1']) Then
          Begin
          SetNote('Xmodem sends one file at a time');
          Exit;
          End;
        End
      Else If Not DirectoryExists(Opts.DownDir) Then
        Begin
        SetNote('the download folder is not there: ' + Opts.DownDir);
        Exit;
        End;
      XTitle := Copy('Sending', 1, 7 * Ord(Upload)) + Copy('Receiving', 1, 9 * Ord(Not Upload)) + ' (' + ConnProtoName(Proto) + ')';
      XName := '';
      XMsg := '';
      XSize := 0;
      XDone := 0;
      XErr := 0;
      XCps := 0;
      XSecs := 0;
      XCancelled := False;
      XDrawAt := 0;
      XDraw(True);
      OldSess := ComSession;
      OldPort := CurrentPort;
      OldRate := CurrentRate;
      ComSession := S;
      CurrentPort := 1;
      CurrentRate := 38400;
      ProtQuiet := True;
      ProtKeepInput := True;
      ProtLastMsg := '';
      ProtHook := @XHook;
      ProtCancelHook := @XCancel;
      GetDir(0, Cur);
      P.Init;
      Case Proto Of
        'Y': P.SetYModem;
        'G': P.SetYModemG;
        'X': P.SetXmodem;
        '1': P.SetX1K;
        Else P.SetZmodem;
        End;
      Ok := False;
      Listed := '';
      Try
        If Upload Then
          Begin
          SetCurrentDir(Dir);
          For i := 0 To Files.Count - 1 Do
            Begin
            P.AddSendFile(ExtractFileName(Files[i]));
            Listed := Listed + Copy(' ', 1, Ord(Listed <> '')) + ExtractFileName(Files[i]);
            End;
          P.Send;
          Ok := P.PI^.Error = 0;
          For i := 1 To Files.Count Do
            If P.GetFileStatus(i) <> 1 Then
              Ok := False;
          End
        Else
          Begin
          If SaveAs <> '' Then
            P.SetRecvName(SaveAs)
          Else
            P.SetRecvName('download.dat');
          Ok := P.Recv(IncludeTrailingPathDelimiter(Opts.DownDir)) And (P.PI^.NumFiles > 0);
          For i := 1 To P.PI^.NumFiles Do
            Listed := Listed + Copy(' ', 1, Ord(Listed <> '')) + ExtractFileName(P.PI^.FN[i]);
          End;
      Finally
        P.Done;
        SetCurrentDir(Cur);
        ComSession := OldSess;
        CurrentPort := OldPort;
        CurrentRate := OldRate;
        ProtHook := Nil;
        ProtCancelHook := Nil;
        ProtKeepInput := False;
      End;
      { what the user typed during the transfer is thrown away }
      Pl.fd := 0; Pl.events := POLLIN; Pl.revents := 0;
      While fpPoll(@Pl, 1, 0) > 0 Do
        Begin
        If fpRead(0, Pb, SizeOf(Pb)) <= 0 Then Break;
        Pl.revents := 0;
        End;
      If Ok Then
        Res := Copy('sent ', 1, 5 * Ord(Upload)) + Copy('received ', 1, 9 * Ord(Not Upload)) + Listed
      Else If XCancelled Then
        Res := 'cancelled'
      Else
        Res := 'failed: ' + ProtLastMsg;
      LogXfer(Copy('upload', 1, 6 * Ord(Upload)) + Copy('download', 1, 8 * Ord(Not Upload)) + ' ' + ConnProtoName(Proto), Listed, Res);
      Note := Res;
      NoteUntil := Now_ + 8;
      XferOk := Ok;
      If Ok And Upload Then
        Inc(Sent, XSize)
      Else If Ok Then
        Inc(Got, XSize);
    Finally
      Files.Free;
    End;
    End;

  Procedure TransferKey(Upload: Boolean);
    Var
      Pr: Char;
      Names, SaveAs: String;

    Begin
    Pr := ChooseProto(DefProto);
    If Pr = #0 Then
      Begin
      Status;
      Exit;
      End;
    DefProto := Pr;
    Names := '';
    SaveAs := '';
    If Upload Then
      Begin
      If (Not AskBar('Send which file(s)? (names or wildcards, in one folder):', Names)) Or (Trim(Names) = '') Then
        Begin
        Status;
        Exit;
        End;
      End
    Else If Pr In ['X', '1'] Then
      Begin
      SaveAs := 'download.dat';
      If (Not AskBar('Save as (in ' + Opts.DownDir + '):', SaveAs)) Or (Trim(SaveAs) = '') Then
        Begin
        Status;
        Exit;
        End;
      End;
    Xfer(Upload, Pr, Trim(Names), Trim(SaveAs));
    Status;
    End;


  Var
    H: HubScriptObj;

  Procedure ScriptChar(C: Char);
    Begin
    Buf[0] := Ord(C);
    Display(1);
    End;

  Function ScriptCancel: Boolean;
    Var
      P: TPollFd;
      B: Array[0..63] Of Byte;
      N: LongInt;

    Begin
    Result := False;
    P.fd := 0; P.events := POLLIN; P.revents := 0;
    While fpPoll(@P, 1, 0) > 0 Do
      Begin
      N := fpRead(0, B, SizeOf(B));
      If N <= 0 Then
        Break;
      If CancelIn(B, N) Then
        Result := True;
      P.revents := 0;
      End;
    If TermSig Then
      Result := True;
    End;

  Function ScriptXfer(Upload: Boolean; Arg: ShortString): Boolean;
    Var
      Pr: Char;
      V: String;

    Begin
    V := H.GetVar('protocol');
    Pr := DefProto;
    If V <> '' Then
      Pr := UpCase(V[1]);
    If Not (Pr In ['Z', 'Y', 'G', 'X', '1']) Then
      Pr := 'Z';
    If Upload Then
      Xfer(True, Pr, Arg, '')
    Else If Pr In ['X', '1'] Then
      Xfer(False, Pr, '', Arg)
    Else
      Xfer(False, Pr, '', '');
    Result := XferOk;
    End;

  Function FindScript(Const Name: String; Out Text: AnsiString): Boolean;
    {a file (a name with a folder, or one in the scripts folder), else a script built in (HubProfile)}
    Var
      F: TStringList;
      Path: String;

    Begin
    Result := False;
    Text := '';
    Path := Name;
    If (Pos('/', Name) = 0) And (Pos('~', Name) = 0) And (Opts.ScriptDir <> '') Then
      If FileExists(IncludeTrailingPathDelimiter(Opts.ScriptDir) + Name) Then
        Path := IncludeTrailingPathDelimiter(Opts.ScriptDir) + Name;
    If FileExists(Path) Then
      Begin
      F := TStringList.Create;
      Try
        F.LoadFromFile(Path);
        Text := F.Text;
        Result := True;
      Finally
        F.Free;
      End;
      Exit;
      End;
    Text := HubProfile(Name);
    Result := Text <> '';
    End;

  Function RunScript(Const Name: String): Boolean;
    {the script, on the open session, while the user watches the screen: any key of the user (Esc, Ctrl-X) stops it}
    Var
      Text: AnsiString;
      Ok: Boolean;
      Why: String;

    Begin
    Result := True;
    If Name = '' Then
      Exit;
    If Not FindScript(Name, Text) Then
      Begin
      SetNote('script ' + Name + ' not found');
      LogXfer('script', Name, 'not found');
      Exit(False);
      End;
    H.Init(S);
    Try
      H.OnChar := @ScriptChar;
      H.CancelFn := @ScriptCancel;
      H.SetXfer(@ScriptXfer);
      H.SetVar('login', E.Login);
      H.SetVar('password', E.Password);
      H.SetVar('name', E.Name);
      H.SetVar('host', E.Host);
      H.SetVar('protocol', ConnProtoName(DefProto)[1]);
      SetNote('script ' + Name + ' (Esc stops it)');
      Status;
      If Not H.Load(Text) Then
        Begin
        SetNote('script ' + Name + ' is too long');
        Exit(False);
        End;
      Ok := H.Run;
      Why := Plain(H.ErrText);
    Finally
      H.Done;
    End;
    AutoZ := False;
    ZState := 0;
    If Ok Then
      Begin
      SetNote('script ' + Name + ' done');
      LogXfer('script', Name, 'done');
      End
    Else
      Begin
      SetNote('script ' + Name + ' stopped: ' + Why);
      LogXfer('script', Name, 'stopped: ' + Why);
      End;
    Result := Ok;
    NoteUntil := Now_ + 8;
    End;


  Procedure Menu;
    Begin
    InMenu := True;
    DrawBar(' H)angup X) leave D)ialer C)apture U)pload L) download P)assword N)ame ]) Ctrl-] T) charset ?) Esc)');
    End;

  Procedure Command(C: Char);
    {an Alt key or a letter of the menu}
    Begin
    Case LowerCase(C) Of
      'h', 'd': Begin CallResult := crDone; Done := True; End;
      'x': Begin CallResult := crQuit; Done := True; End;
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
      'u': TransferKey(True);
      'l': TransferKey(False);
      't': Begin
           E.Utf8 := Not E.Utf8;
           Convert := (Not E.Utf8) And Opts.TermUtf8;
           SetNote('the system is taken to send ' + Copy('CP437', 1, 5 * Ord(Not E.Utf8)) + Copy('UTF-8', 1, 5 * Ord(E.Utf8)));
           End;
      ']': Sys(CtrlRB);
      '?': SetNote('Ctrl-] menu  Alt-P password  Alt-N name  Alt-U upload  Alt-L download  Alt-C capture  Alt-H hang up  Alt-X leave');
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
      Case ZState Of                   {the start of a Zmodem sender: ** ZDLE B 0 0}
        0: If B = 42 Then ZState := 1;
        1: If B = 42 Then ZState := 2 Else ZState := 0;
        2: If B = 24 Then ZState := 3 Else If B <> 42 Then ZState := 0;
        3: If B = 66 Then ZState := 4 Else ZState := 0;
        4: If B = 48 Then ZState := 5 Else ZState := 0;
        5: Begin
           If B = 48 Then AutoZ := True;
           ZState := 0;
           End;
        End;
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

Function DoCall: Integer;
  Begin
  CallResult := crDone;
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
  AutoZ := False;
  ZState := 0;
  DefProto := E.Proto;
  If DefProto = #0 Then
    DefProto := 'Z';
  Telnet_ := E.Kind In [ckTelnet, ckTelnets];
  SshPid := 0;
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
  If E.Kind = ckSsh Then
    Begin
    TtyWrite('Starting ssh ...'#13#10);
    S := SshOpen(E.Host, E.Port, E.SshUser, Err);
    If S = Nil Then
      Begin
      Msg := 'cannot start ssh: ' + Err;
      Exit(crFailed);
      End;
    End
  Else
    Begin
    ClientTls := E.Kind = ckTelnets;
    S := ConnectTcp(E.Host, E.Port, Opts.ConnectMs, Telnet_, Err);
    ClientTls := False;
    End;
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
    If Opts.ScriptName <> '' Then
      RunScript(Opts.ScriptName)
    Else If E.Script <> '' Then
      RunScript(E.Script);
    Status;
    While (Not Done) And (Not TermSig) Do
      Begin
      If Winch Then
        Begin
        Winch := False;
        TtySize(Cols, Rows);
        SetRegion;
        Status;
        If SshFd >= 0 Then
          Begin
          WsB[0] := Rows - 1; WsB[1] := Cols; WsB[2] := 0; WsB[3] := 0;
          fpIoctl(SshFd, TIOCSWINSZ, @WsB);
          End;
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
        If AutoZ Then
          Begin
          AutoZ := False;
          SetNote('Zmodem start: receiving');
          Xfer(False, 'Z', '', '');
          Status;
          End;
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
      CallResult := crDone;
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
      CallResult := crQuit;
      LogCall('the terminal ended the program');
      End
    Else
      LogCall(Copy('hung up', 1, 7 * Ord(CallResult = crDone)) + Copy('left the program', 1, 16 * Ord(CallResult = crQuit)));
  Finally
    CapOff;
    S^.Hangup;
    Dispose(S, Done);
    SshEnd;
    TtyWrite(#27'[0m'#27'[r'#27'[' + IntToStr(Rows) + ';1H'#27'[2K'#13#10);
    If HaveSaved Then
      TCSetAttr(0, TCSANOW, Saved);
    fpSignal(SIGWINCH, SignalHandler(SIG_DFL));
  End;
  Result := CallResult;
  End;


Function RunCall(Var EIn: TConnEntry; Const OIn: TCallOpts; Out MsgOut: String): Integer;
  Begin
  E := EIn;
  Opts := OIn;
  Msg := '';
  Result := DoCall;
  EIn := E;
  MsgOut := Msg;
  End;


End.
