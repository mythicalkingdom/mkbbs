Unit MKMonMail;   {The mailer (mkbink) screen of the sysop monitor, in the style of the old FrontDoor status screen}

{$I MKB.Def}
{$H+}                      {long strings: a frame line can be longer than 255 characters}

{
     The screen follows what mkbink tells over its control socket (<rundir>/mailer.sock, see
     mkbink src/lib/binkcontrol.pas and BuildState in binkmailer.pas):

        .- Session ----------------------.  .- Statistics -------.
        | the call that is going on      |  | calls, bytes        |
        '--------------------------------'  '---------------------'
        .- Transfer -------------------------------------------- .
        | Send  file   [#####-----] 50%  200K / 400K  12 K/s  ETA |
        '---------------------------------------------------------'
        .- Links ----------------------------------------------- .
        | address  name  state  next call  waiting  last result   |
        '---------------------------------------------------------'
        .- Events -------------------------------------------------.
        | the last log lines of the mailer                         |
        '----------------------------------------------------------'

     Keys:  Up / Down  choose a link        Tab  next session
            P  call the chosen link now     A  call every link that has mail waiting
            H  hold / release the link      R  look at the outbound again
            L  read the settings again      X  end the chosen session
            F  ask a system for files (names, host, call now)
            Q or Esc  back to the node list

     The screen is drawn from a table of cells and only what changed is sent.  Colours always give the
     background too (the terminal's own default may not be black).
}

Interface

Function MailerScreen(RunDir: String): String;
  {Shows the screen until the sysop leaves; the result is a message for the node list ('' = none)}


Implementation

Uses
  BaseUnix, Sockets, Dos, MKString, MKGlobT, MKComAbs, MKSess, MKCp437, MKNodeHost;


Const
  Esc = #27;
  MaxLinks = 64;
  MaxSess = 16;
  MaxLog = 40;
  Cols = 80;
  MaxRows = 60;

  { attributes: low nibble = foreground (0..15), high = background (0..7), as on a DOS screen }
  aNorm = $07;
  aBright = $0F;
  aTitle = $1F;
  aBox = $09;
  aBoxTitle = $0E;
  aLabel = $03;
  aGood = $0A;
  aBad = $0C;
  aWarn = $0E;
  aSel = $70;
  aKey = $70;
  aKeyHi = $74;
  aDim = $08;

  { CP437 box characters }
  bH = #$C4; bV = #$B3; bTL = #$DA; bTR = #$BF; bBL = #$C0; bBR = #$D9;
  bFull = #$DB; bLight = #$B0;


Type
  Str80 = String[80];

  LinkRec = Record
    Addr: String[24];
    Name: String[30];
    Host: String[64];
    Flags: String[4];
    PollMin: LongInt;
    State: String[12];
    Failures: LongInt;
    NextU: LongInt;
    Last: String[64];
    PendCount: LongInt;
    PendBytes: Int64;
    LastU: LongInt;
    End;

  SessRec = Record
    Id: LongInt;
    Dir: Char;
    Remote: String[40];
    Sys: String[40];
    Sysop: String[40];
    Loc: String[40];
    Start: LongInt;
    State: String[16];
    Opts: String[24];
    Sent, Rcvd: Int64;
    FSent, FRcvd: LongInt;
    TxName: String[40];
    TxPos, TxSize: Int64;
    RxName: String[40];
    RxPos, RxSize: Int64;
    { rates, worked out here from successive frames }
    LastMs: Int64;
    LastSent, LastRcvd: Int64;
    TxRate, RxRate: Int64;
    End;

  Cell = Record
    Ch: Char;
    At: Byte;
    End;


Var
  Sock: LongInt;
  InBuf: String;
  Links: Array[1..MaxLinks] Of LinkRec;
  NumLinks: Word;
  Sess: Array[1..MaxSess] Of SessRec;
  NumSess: Word;
  Logs: Array[1..MaxLog] Of String[160];
  NumLogs: Word;
  MeAddr, MeName, MeSysop, MeVersion: String[64];
  MeStarted: LongInt;
  MePort: LongInt;
  StCalls, StOk, StFailed, StAnswered: LongInt;
  StSent, StRcvd: Int64;
  StFSent, StFRcvd: LongInt;
  FrameU: LongInt;                     {server time of the last frame ...}
  FrameLocal: LongInt;                 {... and ours when it came}
  HaveFrame: Boolean;
  Frame: Array[1..400] Of String;      {lines of the frame being collected}
  NumFrame: Word;
  InFrame: Boolean;
  Scr, Prev: Array[1..MaxRows, 1..Cols] Of Cell;
  Rows: Word;
  Utf8: Boolean;
  ForceAll: Boolean;
  SelLink, TopLink, SelSess: Word;
  Msg: String;
  MsgUntil: LongInt;
  Gone: Boolean;
  Dirty: Boolean;
  SessIds: Array[1..MaxSess] Of LongInt;


{------------------------------------------------------------ small helpers}

Function NowMs: Int64;
  Var
    H, Mi, S, S100: Word;

  Begin
  GetTime(H, Mi, S, S100);                {only differences are used: a midnight gives one odd step}
  NowMs := ((Int64(H) * 60 + Mi) * 60 + S) * 1000 + S100 * 10;
  End;


Function CurU: LongInt;
  {The server's clock now: the last frame's time plus what has passed here since}
  Begin
  CurU := FrameU + (fpTime - FrameLocal);
  End;


Function Field(Const S: String; N: Word): String;
  {Field N (1 = first) of a tab separated line}
  Var
    i, k, Start: Word;

  Begin
  Field := '';
  k := 1;
  Start := 1;
  For i := 1 To Length(S) + 1 Do
    If (i > Length(S)) Or (S[i] = #9) Then
      Begin
      If k = N Then
        Begin
        Field := Copy(S, Start, i - Start);
        Exit;
        End;
      Inc(k);
      Start := i + 1;
      End;
  End;


Function I64(Const S: String): Int64;
  Var
    V: Int64;
    Code: Integer;

  Begin
  Val(S, V, Code);
  If Code <> 0 Then
    V := 0;
  I64 := V;
  End;


Function Num(N: Int64): String;
  Var
    S: String;

  Begin
  Str(N, S);
  Num := S;
  End;


Function Pad(S: String; N: Word): String;
  Begin
  If Length(S) > N Then
    SetLength(S, N);
  While Length(S) < N Do
    S := S + ' ';
  Pad := S;
  End;


Function PadL(S: String; N: Word): String;
  Begin
  If Length(S) > N Then
    SetLength(S, N);
  While Length(S) < N Do
    S := ' ' + S;
  PadL := S;
  End;


Function Two(N: LongInt): String;
  Begin
  If N < 10 Then
    Two := '0' + Num(N)
  Else
    Two := Num(N);
  End;


Function Dur(Secs: LongInt): String;
  Begin
  If Secs < 0 Then
    Secs := 0;
  Dur := Two(Secs Div 3600) + ':' + Two((Secs Div 60) Mod 60) + ':' + Two(Secs Mod 60);
  End;


Function ClockOf(U: LongInt): String;
  {Local time of day of a unix time (this machine has the same zone as the mailer)}
  Var
    Secs, Off: LongInt;
    H, Mi, S, S100: Word;

  Begin
  GetTime(H, Mi, S, S100);
  Off := (LongInt(H) * 3600 + Mi * 60 + S) - (CurU - U);
  Off := ((Off Mod 86400) + 86400) Mod 86400;
  Secs := Off;
  ClockOf := Two(Secs Div 3600) + ':' + Two((Secs Div 60) Mod 60);
  End;


Function Size(N: Int64): String;
  Begin
  If N < 10240 Then
    Size := Num(N) + ' B'
  Else If N < 10 * 1048576 Then
    Size := Num(N Div 1024) + ' K'
  Else If N < Int64(10) * 1073741824 Then
    Size := Num(N Div 1048576) + ' M'
  Else
    Size := Num(N Div 1073741824) + ' G';
  End;


Function Rate(N: Int64): String;
  Begin
  If N < 10240 Then
    Rate := Num(N) + ' B/s'
  Else If N < 10 * 1048576 Then
    Rate := Num(N Div 1024) + ' K/s'
  Else
    Rate := Num(N Div 1048576) + ' M/s';
  End;


{------------------------------------------------------------ the cell table}

Procedure Clear;
  Var
    r, c: Word;

  Begin
  For r := 1 To Rows Do
    For c := 1 To Cols Do
      Begin
      Scr[r, c].Ch := ' ';
      Scr[r, c].At := aNorm;
      End;
  End;


Procedure PutAt(R, C: Integer; At: Byte; S: String);
  Var
    i: Word;

  Begin
  If (R < 1) Or (R > Rows) Then
    Exit;
  For i := 1 To Length(S) Do
    If (C + i - 1 >= 1) And (C + i - 1 <= Cols) Then
      Begin
      Scr[R, C + i - 1].Ch := S[i];
      Scr[R, C + i - 1].At := At;
      End;
  End;


Procedure FillAt(R, C1, C2: Integer; At: Byte; Ch: Char);
  Var
    c: Integer;

  Begin
  If (R < 1) Or (R > Rows) Then
    Exit;
  For c := C1 To C2 Do
    If (c >= 1) And (c <= Cols) Then
      Begin
      Scr[R, c].Ch := Ch;
      Scr[R, c].At := At;
      End;
  End;


Procedure Box(R1, C1, R2, C2: Integer; Title: String);
  Var
    r: Integer;

  Begin
  FillAt(R1, C1 + 1, C2 - 1, aBox, bH);
  FillAt(R2, C1 + 1, C2 - 1, aBox, bH);
  PutAt(R1, C1, aBox, bTL);
  PutAt(R1, C2, aBox, bTR);
  PutAt(R2, C1, aBox, bBL);
  PutAt(R2, C2, aBox, bBR);
  For r := R1 + 1 To R2 - 1 Do
    Begin
    PutAt(r, C1, aBox, bV);
    PutAt(r, C2, aBox, bV);
    FillAt(r, C1 + 1, C2 - 1, aNorm, ' ');
    End;
  If Title <> '' Then
    PutAt(R1, C1 + 2, aBoxTitle, ' ' + Title + ' ');
  End;


Function Sgr(At: Byte): String;
  Var
    Fg, Bg: Byte;
    S: String;

  Begin
  Fg := At And 7;
  Bg := (At Shr 4) And 7;
  S := Esc + '[0;';
  If (At And 8) <> 0 Then
    S := S + '1;';
  S := S + Num(30 + (Fg And 1) * 4 + (Fg And 2) + (Fg And 4) Div 4) + ';' +
    Num(40 + (Bg And 1) * 4 + (Bg And 2) + (Bg And 4) Div 4) + 'm';
  Sgr := S;
  End;


Procedure Flush;
  {Sends the cells that differ from what the sysop's screen shows}
  Var
    Out: String;
    r, c, k: Word;
    CurAt: Integer;
    Ch: Char;

  Procedure Emit(S: String);
    Begin
    If Length(Out) + Length(S) > 240 Then
      Begin
      ComSession^.SendStr(Out);
      Out := '';
      End;
    Out := Out + S;
    End;

  Begin
  Out := '';
  CurAt := -1;
  If ForceAll Then
    Begin
    Emit(Esc + '[0;37;40m' + Esc + '[2J');
    CurAt := -1;
    End;
  For r := 1 To Rows Do
    Begin
    c := 1;
    While c <= Cols Do
      Begin
      If ForceAll Or (Scr[r, c].Ch <> Prev[r, c].Ch) Or (Scr[r, c].At <> Prev[r, c].At) Then
        Begin
        Emit(Esc + '[' + Num(r) + ';' + Num(c) + 'H');
        k := c;
        While (k <= Cols) And (ForceAll Or (Scr[r, k].Ch <> Prev[r, k].Ch) Or (Scr[r, k].At <> Prev[r, k].At)
            Or ((k + 1 <= Cols) And (Scr[r, k + 1].Ch <> Prev[r, k + 1].Ch) And (k - c < 4))) Do
          Begin
          If Scr[r, k].At <> CurAt Then
            Begin
            Emit(Sgr(Scr[r, k].At));
            CurAt := Scr[r, k].At;
            End;
          Ch := Scr[r, k].Ch;
          If Utf8 And (Ch >= #128) Then
            Emit(Cp437ToUtf8(Ord(Ch)))
          Else
            Emit(Ch);
          Prev[r, k] := Scr[r, k];
          Inc(k);
          End;
        c := k;
        End
      Else
        Inc(c);
      End;
    End;
  ForceAll := False;
  Emit(Esc + '[0;37;40m' + Esc + '[' + Num(Rows) + ';' + Num(Cols) + 'H');
  If Out <> '' Then
    ComSession^.SendStr(Out);
  CommFlushOut;
  End;


{------------------------------------------------------------ the socket}

Function OpenSock(RunDir: String): Boolean;
  Var
    A: TUnixSockAddr;
    Path: String;

  Begin
  OpenSock := False;
  Path := RunDir + '/mailer.sock';
  If Length(Path) > 100 Then
    Exit;
  Sock := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  If Sock < 0 Then
    Exit;
  FillChar(A, SizeOf(A), 0);
  A.family := AF_UNIX;
  Move(Path[1], A.path, Length(Path));
  If fpConnect(Sock, @A, SizeOf(A)) <> 0 Then
    Begin
    fpClose(Sock);
    Sock := -1;
    Exit;
    End;
  fpFcntl(Sock, F_SETFL, fpFcntl(Sock, F_GETFL) Or O_NONBLOCK);
  OpenSock := True;
  End;


Procedure SendCmd(S: String);
  Begin
  S := S + #10;
  If Sock >= 0 Then
    fpSend(Sock, @S[1], Length(S), MSG_NOSIGNAL);
  End;


Procedure ParseFrame;
  Var
    i, k: Word;
    L: String;
    S: SessRec;
    Old: Word;
    Dt: Int64;
    Ms: Int64;

  Begin
  NumLinks := 0;
  FrameLocal := fpTime;
  Ms := NowMs;
  For i := 1 To NumFrame Do
    Begin
    L := Frame[i];
    If Copy(L, 1, 6) = 'STATE ' Then
      Begin
      FrameU := Str2Long(Copy(L, 7, 20));
      FrameLocal := fpTime;
      End
    Else If Copy(L, 1, 3) = 'ME ' Then
      Begin
      L := Copy(L, 4, 2000);
      MeAddr := Field(L, 1);
      MeName := Field(L, 2);
      MeSysop := Field(L, 3);
      MeStarted := Str2Long(Field(L, 4));
      MePort := Str2Long(Field(L, 5));
      MeVersion := Field(L, 6);
      End
    Else If Copy(L, 1, 5) = 'STAT ' Then
      Begin
      L := Copy(L, 6, 2000);
      StCalls := Str2Long(Field(L, 1));
      StOk := Str2Long(Field(L, 2));
      StFailed := Str2Long(Field(L, 3));
      StAnswered := Str2Long(Field(L, 4));
      StSent := I64(Field(L, 5));
      StRcvd := I64(Field(L, 6));
      StFSent := Str2Long(Field(L, 7));
      StFRcvd := Str2Long(Field(L, 8));
      End
    Else If (Copy(L, 1, 5) = 'LINK ') And (NumLinks < MaxLinks) Then
      Begin
      L := Copy(L, 6, 2000);
      Inc(NumLinks);
      With Links[NumLinks] Do
        Begin
        Addr := Field(L, 1);
        Name := Field(L, 2);
        Host := Field(L, 3);
        Flags := Field(L, 4);
        PollMin := Str2Long(Field(L, 5));
        State := Field(L, 6);
        Failures := Str2Long(Field(L, 7));
        NextU := Str2Long(Field(L, 8));
        Last := Field(L, 9);
        PendCount := Str2Long(Field(L, 10));
        PendBytes := I64(Field(L, 11));
        LastU := Str2Long(Field(L, 12));
        End;
      End;
    End;
  { sessions: keep the rates of those that were there }
  Old := NumSess;
  Dt := 0;
  NumSess := 0;
  For i := 1 To NumFrame Do
    Begin
    L := Frame[i];
    If (Copy(L, 1, 5) = 'SESS ') And (NumSess < MaxSess) Then
      Begin
      L := Copy(L, 6, 2000);
      FillChar(S, SizeOf(S), 0);
      S.Id := Str2Long(Field(L, 1));
      S.Dir := Field(L, 2)[1];
      S.Remote := Field(L, 3);
      S.Sys := Field(L, 4);
      S.Sysop := Field(L, 5);
      S.Loc := Field(L, 6);
      S.Start := Str2Long(Field(L, 7));
      S.State := Field(L, 8);
      S.Opts := Field(L, 9);
      S.Sent := I64(Field(L, 10));
      S.Rcvd := I64(Field(L, 11));
      S.FSent := Str2Long(Field(L, 12));
      S.FRcvd := Str2Long(Field(L, 13));
      S.TxName := Field(L, 14);
      S.TxPos := I64(Field(L, 15));
      S.TxSize := I64(Field(L, 16));
      S.RxName := Field(L, 17);
      S.RxPos := I64(Field(L, 18));
      S.RxSize := I64(Field(L, 19));
      S.LastMs := Ms;
      S.LastSent := S.Sent;
      S.LastRcvd := S.Rcvd;
      For k := 1 To Old Do
        If SessIds[k] = S.Id Then
          Begin
          Dt := Ms - Sess[k].LastMs;
          If Dt >= 200 Then
            Begin
            S.TxRate := ((S.Sent - Sess[k].LastSent) * 1000) Div Dt;
            S.RxRate := ((S.Rcvd - Sess[k].LastRcvd) * 1000) Div Dt;
            If Sess[k].TxRate > 0 Then
              S.TxRate := (S.TxRate + Sess[k].TxRate) Div 2;      {a little smoothing}
            If Sess[k].RxRate > 0 Then
              S.RxRate := (S.RxRate + Sess[k].RxRate) Div 2;
            End
          Else
            Begin
            S.TxRate := Sess[k].TxRate;
            S.RxRate := Sess[k].RxRate;
            S.LastMs := Sess[k].LastMs;
            S.LastSent := Sess[k].LastSent;
            S.LastRcvd := Sess[k].LastRcvd;
            End;
          End;
      Inc(NumSess);
      Sess[NumSess] := S;
      End;
    End;
  For k := 1 To NumSess Do
    SessIds[k] := Sess[k].Id;
  If SelSess > NumSess Then
    SelSess := NumSess;
  If (SelSess < 1) And (NumSess > 0) Then
    SelSess := 1;
  HaveFrame := True;
  Dirty := True;
  End;


Procedure AddLog(L: String);
  Var
    i: Word;

  Begin
  If NumLogs >= MaxLog Then
    Begin
    For i := 1 To MaxLog - 1 Do
      Logs[i] := Logs[i + 1];
    NumLogs := MaxLog - 1;
    End;
  Inc(NumLogs);
  Logs[NumLogs] := L;
  Dirty := True;
  End;


Procedure ReadSock;
  Var
    Buf: Array[0..1023] Of Char;
    N: LongInt;
    P: Word;
    L: String;
    U: LongInt;

  Begin
  If Sock < 0 Then
    Exit;
  Repeat
    N := fpRecv(Sock, @Buf[0], SizeOf(Buf), MSG_NOSIGNAL);
    If N = 0 Then
      Begin
      Gone := True;
      Exit;
      End;
    If N < 0 Then
      Begin
      If fpGetErrno <> ESysEAGAIN Then
        Gone := True;
      Exit;
      End;
    If Length(InBuf) > 65536 Then
      InBuf := '';
    L := '';
    SetLength(L, N);
    Move(Buf[0], L[1], N);
    InBuf := InBuf + L;
    Repeat
      P := Pos(#10, InBuf);
      If P > 0 Then
        Begin
        L := Copy(InBuf, 1, P - 1);
        Delete(InBuf, 1, P);
        If Copy(L, 1, 6) = 'STATE ' Then
          Begin
          InFrame := True;
          NumFrame := 0;
          End;
        If InFrame Then
          Begin
          If NumFrame < 400 Then
            Begin
            Inc(NumFrame);
            Frame[NumFrame] := L;
            End;
          If L = 'END' Then
            Begin
            InFrame := False;
            ParseFrame;
            End;
          End
        Else If Copy(L, 1, 4) = 'LOG ' Then
          Begin
          L := Copy(L, 5, 200);
          U := Str2Long(Field(L, 1));
          AddLog(Field(L, 2));
          Logs[NumLogs] := Copy(Num(U), 1, 0) + Copy(Field(L, 2), 1, 150);
          Logs[NumLogs] := Field(L, 2);
          If U > 0 Then
            Logs[NumLogs] := ClockOf(U) + ' ' + Logs[NumLogs];
          End
        Else If (Copy(L, 1, 3) = 'ACK') Or (Copy(L, 1, 3) = 'ERR') Then
          Begin
          Msg := Copy(L, 5, 70);
          If Copy(L, 1, 3) = 'ERR' Then
            Msg := 'Not done: ' + Msg;
          MsgUntil := fpTime + 5;
          Dirty := True;
          End;
        End;
    Until P = 0;
  Until False;
  End;


{------------------------------------------------------------ drawing}

Function StateAttr(Const S: String): Byte;
  Begin
  If (S = 'calling') Then
    StateAttr := aGood
  Else If (S = 'retry') Then
    StateAttr := aBad
  Else If (S = 'waiting') Then
    StateAttr := aWarn
  Else If (S = 'held') Then
    StateAttr := aBad
  Else If (S = 'idle') Then
    StateAttr := aNorm
  Else
    StateAttr := aDim;
  End;


Function StateText(Const L: LinkRec): String;
  Begin
  If L.State = 'answer' Then
    StateText := 'answers'
  Else If L.State = 'nohost' Then
    StateText := 'no host'
  Else
    StateText := L.State;
  End;


Function L_Next(Const L: LinkRec; U: LongInt): String;
  {When the link is called next: 'now', in a while, or nothing}
  Var
    D: LongInt;

  Begin
  L_Next := '';
  If (L.State = 'calling') Or (L.State = 'answer') Or (L.State = 'nohost') Or (L.State = 'held') Then
    Exit;
  If L.NextU > 0 Then
    Begin
    D := L.NextU - U;
    If D <= 0 Then
      L_Next := 'now'
    Else If D < 3600 Then
      L_Next := 'in ' + Two(D Div 60) + ':' + Two(D Mod 60)
    Else
      L_Next := ClockOf(L.NextU);
    End
  Else If L.State = 'waiting' Then
    L_Next := 'now';
  End;


Procedure DrawBar(R, C: Integer; W: Integer; Pos, Total: Int64);
  Var
    Full, i: Integer;

  Begin
  If Total <= 0 Then
    Total := 1;
  If Pos > Total Then
    Pos := Total;
  Full := (Pos * W) Div Total;
  For i := 1 To W Do
    If i <= Full Then
      PutAt(R, C + i - 1, aGood, bFull)
    Else
      PutAt(R, C + i - 1, aDim, bLight);
  End;


Procedure Draw;
  Var
    i, r, k, First, LogRows: Integer;
    S: SessRec;
    Title, T, Stt: String;
    Pct: Integer;
    HaveS: Boolean;
    Eta: Int64;
    U: LongInt;

  Begin
  Clear;
  U := CurU;
  { title bar }
  FillAt(1, 1, Cols, aTitle, ' ');
  T := 'MkBink ' + Copy(MeVersion, Pos('/', MeVersion) + 1, 10) + '  ' + MeAddr + '  ' + MeName;
  If NumSess > 0 Then
    Stt := 'IN SESSION'
  Else
    Stt := 'Idle';
  If NumSess > 1 Then
    Stt := Num(NumSess) + ' SESSIONS';
  PutAt(1, 2, aTitle, Pad(T, Cols - Length(Stt) - 5));
  PutAt(1, Cols - Length(Stt) - 2, aTitle, Stt);
  { session }
  Box(2, 1, 8, 50, 'Session');
  HaveS := (SelSess >= 1) And (SelSess <= NumSess);
  If HaveS Then
    Begin
    S := Sess[SelSess];
    If S.Dir = 'O' Then
      T := 'We called'
    Else
      T := 'Called us';
    PutAt(3, 3, aLabel, 'Remote');
    PutAt(3, 11, aBright, Pad(S.Remote, 17) + ' ' + Pad(S.Sys, 20));
    PutAt(4, 3, aLabel, 'Sysop');
    PutAt(4, 11, aNorm, Pad(S.Sysop, 18) + ' ' + Pad(S.Loc, 18));
    PutAt(5, 3, aLabel, 'Call');
    PutAt(5, 11, aNorm, Pad(T, 12) + 'since ' + ClockOf(S.Start));
    PutAt(5, 36, aLabel, 'Time');
    PutAt(5, 41, aBright, Dur(U - S.Start));
    PutAt(6, 3, aLabel, 'State');
    PutAt(6, 11, aGood, Pad(S.State, 16));
    PutAt(6, 28, aNorm, S.Opts);
    PutAt(7, 3, aLabel, 'Sent');
    PutAt(7, 11, aNorm, PadL(Num(S.FSent), 3) + ' file(s) ' + PadL(Size(S.Sent), 7));
    PutAt(7, 31, aLabel, 'Rcvd');
    PutAt(7, 36, aNorm, PadL(Num(S.FRcvd), 3) + ' ' + PadL(Size(S.Rcvd), 7));
    If NumSess > 1 Then
      PutAt(2, 40, aBoxTitle, ' ' + Num(SelSess) + '/' + Num(NumSess) + ' Tab ');
    End
  Else
    Begin
    PutAt(4, 3, aDim, 'No session.');
    If NumLinks > 0 Then
      Begin
      k := 0;
      For i := 1 To NumLinks Do
        If (Links[i].LastU > 0) And ((k = 0) Or (Links[i].LastU > Links[k].LastU)) Then
          k := i;
      If k > 0 Then
        Begin
        PutAt(5, 3, aLabel, 'Last call');
        PutAt(5, 13, aNorm, Pad(Links[k].Addr, 16) + ' ' + ClockOf(Links[k].LastU));
        PutAt(6, 3, aLabel, 'Result');
        PutAt(6, 13, aNorm, Pad(Links[k].Last, 36));
        End;
      End;
    End;
  { statistics }
  Box(2, 51, 8, Cols, 'Statistics');
  PutAt(3, 53, aLabel, 'Up since');
  PutAt(3, 63, aNorm, ClockOf(MeStarted) + ' ' + Dur(U - MeStarted));
  PutAt(4, 53, aLabel, 'We called');
  PutAt(4, 63, aNorm, PadL(Num(StCalls), 3) + ' (' + Num(StOk) + ' ok, ' + Num(StFailed) + ' bad)');
  PutAt(5, 53, aLabel, 'Called us');
  PutAt(5, 63, aNorm, PadL(Num(StAnswered), 4));
  PutAt(6, 53, aLabel, 'Sent');
  PutAt(6, 63, aNorm, PadL(Num(StFSent), 4) + ' ' + PadL(Size(StSent), 7));
  PutAt(7, 53, aLabel, 'Received');
  PutAt(7, 63, aNorm, PadL(Num(StFRcvd), 4) + ' ' + PadL(Size(StRcvd), 7));
  { transfer }
  Box(9, 1, 12, Cols, 'Transfer');
  If HaveS Then
    Begin
    For k := 1 To 2 Do
      Begin
      r := 9 + k;
      If k = 1 Then
        Begin
        PutAt(r, 3, aLabel, 'Send');
        T := S.TxName;
        If T <> '' Then
          Begin
          PutAt(r, 8, aBright, Pad(T, 14));
          DrawBar(r, 23, 20, S.TxPos, S.TxSize);
          Pct := 0;
          If S.TxSize > 0 Then
            Pct := (S.TxPos * 100) Div S.TxSize;
          PutAt(r, 44, aNorm, PadL(Num(Pct), 3) + '% ' + PadL(Size(S.TxPos), 6) + '/' + Pad(Size(S.TxSize), 6));
          PutAt(r, 62, aNorm, PadL(Rate(S.TxRate), 8));
          If S.TxRate > 0 Then
            PutAt(r, 71, aDim, 'ETA ' + Copy(Dur((S.TxSize - S.TxPos) Div S.TxRate), 4, 5));
          End
        Else
          PutAt(r, 8, aDim, '-');
        End
      Else
        Begin
        PutAt(r, 3, aLabel, 'Recv');
        T := S.RxName;
        If T <> '' Then
          Begin
          PutAt(r, 8, aBright, Pad(T, 14));
          DrawBar(r, 23, 20, S.RxPos, S.RxSize);
          Pct := 0;
          If S.RxSize > 0 Then
            Pct := (S.RxPos * 100) Div S.RxSize;
          PutAt(r, 44, aNorm, PadL(Num(Pct), 3) + '% ' + PadL(Size(S.RxPos), 6) + '/' + Pad(Size(S.RxSize), 6));
          PutAt(r, 62, aNorm, PadL(Rate(S.RxRate), 8));
          If S.RxRate > 0 Then
            PutAt(r, 71, aDim, 'ETA ' + Copy(Dur((S.RxSize - S.RxPos) Div S.RxRate), 4, 5));
          End
        Else
          PutAt(r, 8, aDim, '-');
        End;
      End;
    End
  Else
    PutAt(10, 3, aDim, '-');
  { links }
  Box(13, 1, 19, Cols, 'Links');
  PutAt(14, 3, aBoxTitle, Pad('Address', 16) + Pad('Name', 17) + Pad('State', 9) + Pad('Next call', 10) +
    Pad('Waiting', 10) + 'Last result');
  If NumLinks = 0 Then
    PutAt(15, 3, aDim, '(no links)')
  Else
    Begin
    If SelLink < 1 Then
      SelLink := 1;
    If SelLink > NumLinks Then
      SelLink := NumLinks;
    If SelLink < TopLink Then
      TopLink := SelLink;
    If SelLink > TopLink + 3 Then
      TopLink := SelLink - 3;
    For i := TopLink To TopLink + 3 Do
      If i <= NumLinks Then
        Begin
        r := 15 + i - TopLink;
        With Links[i] Do
          Begin
          If i = SelLink Then
            Begin
            FillAt(r, 2, Cols - 1, aSel, ' ');
            k := aSel;
            End
          Else
            k := aNorm;
          T := '';
          If L_Next(Links[i], U) <> '' Then
            T := L_Next(Links[i], U);
          PutAt(r, 3, k, Pad(Addr, 16) + Pad(Name, 17));
          If i = SelLink Then
            PutAt(r, 36, aSel, Pad(StateText(Links[i]), 9))
          Else
            PutAt(r, 36, StateAttr(State), Pad(StateText(Links[i]), 9));
          PutAt(r, 45, k, Pad(T, 10));
          If PendCount > 0 Then
            PutAt(r, 55, k, Pad(Num(PendCount) + ' / ' + Size(PendBytes), 10))
          Else
            PutAt(r, 55, k, Pad('-', 10));
          PutAt(r, 65, k, Pad(Last, 14));
          If Flags <> '' Then
            PutAt(r, Cols - 4, k, Flags);
          End;
        End;
    End;
  { events }
  LogRows := Rows - 22;
  Box(20, 1, Rows - 1, Cols, 'Events');
  First := NumLogs - LogRows + 1;
  If First < 1 Then
    First := 1;
  r := 21;
  For i := First To NumLogs Do
    Begin
    PutAt(r, 3, aNorm, Copy(Logs[i], 1, 76));
    Inc(r);
    End;
  { keys }
  FillAt(Rows, 1, Cols, aKey, ' ');
  If (Msg <> '') And (fpTime < MsgUntil) Then
    PutAt(Rows, 2, aKey, Pad(Msg, 76))
  Else
    Begin
    Msg := '';
    PutAt(Rows, 2, aKeyHi, 'P');
    PutAt(Rows, 3, aKey, 'oll  ');
    PutAt(Rows, 8, aKeyHi, 'A');
    PutAt(Rows, 9, aKey, 'll mail  ');
    PutAt(Rows, 18, aKeyHi, 'H');
    PutAt(Rows, 19, aKey, 'old/free  ');
    PutAt(Rows, 29, aKeyHi, 'R');
    PutAt(Rows, 30, aKey, 'escan  ');
    PutAt(Rows, 37, aKeyHi, 'L');
    PutAt(Rows, 38, aKey, 'oad settings  ');
    PutAt(Rows, 52, aKeyHi, 'F');
    PutAt(Rows, 53, aKey, 'ile request  ');
    PutAt(Rows, 66, aKeyHi, 'X');
    PutAt(Rows, 67, aKey, ' end  ');
    PutAt(Rows, 73, aKeyHi, 'Q');
    PutAt(Rows, 74, aKey, 'uit');
    End;
  End;


{------------------------------------------------------------ the screen}

Function GetKey(Ms: Word): Char;
  {#0 = nothing; the arrow keys come as #1 (up) and #2 (down); a lost line is Ctrl-X}
  Var
    C: Char;

  Begin
  GetKey := #0;
  If Not ComSession^.GetCarrier Then
    Begin
    GetKey := #24;
    Exit;
    End;
  If Not ComSession^.WaitForChar(Ms) Then
    Exit;
  C := ComSession^.GetChar;
  If C = Esc Then
    Begin
    If ComSession^.WaitForChar(80) Then
      Begin
      C := ComSession^.GetChar;
      If (C = '[') Or (C = 'O') Then
        Begin
        If ComSession^.WaitForChar(80) Then
          Begin
          C := ComSession^.GetChar;
          Case C Of
            'A': GetKey := #1;
            'B': GetKey := #2;
            Else
              Begin
              While (C >= '0') And (C <= '9') Or (C = ';') Do
                If ComSession^.WaitForChar(30) Then
                  C := ComSession^.GetChar
                Else
                  Break;
              GetKey := #0;
              End;
            End;
          End;
        Exit;
        End;
      End;
    GetKey := #27;
    Exit;
    End;
  GetKey := C;
  End;


Function RequestLine(Const Files: String): String;
  {The names, "!password" and "+time" / "-time" typed on one line, as the mailer wants them: one request
   for each name, separated by |}
  Var
    i: Word;
    T, R: String;
    Up: Boolean;

  Begin
  R := '';
  i := 1;
  While i <= Length(Files) Do
    Begin
    While (i <= Length(Files)) And (Files[i] = ' ') Do
      Inc(i);
    T := '';
    While (i <= Length(Files)) And (Files[i] <> ' ') Do
      Begin
      T := T + Files[i];
      Inc(i);
      End;
    If T = '' Then
      Break;
    Up := (Length(T) >= 2) And (T[1] In ['+', '-']) And (T[2] In ['0'..'9']);
    If (T[1] = '!') Or Up Then
      R := R + ' ' + T
    Else If R = '' Then
      R := T
    Else
      R := R + '|' + T;
    End;
  RequestLine := R;
  End;


Function ResolveHost(Const AddrS: String; Var Host: String): Boolean;
  {The host to call when none was typed: '' stays '' (the mailer uses the link's host) for a link that has one; any
   other system is looked up in the nodelist (IBN / INA flags).  False, with a message, when there is none.}
  Var
    k: Word;
    A, Cur, Zero: AddrType;
    Why, H: ShortString;
    Port: Word;

  Begin
  ResolveHost := True;
  If Host <> '' Then
    Exit;
  For k := 1 To NumLinks Do
    If Links[k].Addr = AddrS Then
      If Links[k].Host <> '' Then
        Exit;
  FillChar(Zero, SizeOf(Zero), 0);
  If Not ParseAddr(MeAddr, Zero, Cur) Then
    Cur := Zero;
  If Not ParseAddr(AddrS, Cur, A) Then
    Begin
    Msg := AddrS + ' is not an address';
    MsgUntil := fpTime + 5;
    ResolveHost := False;
    Exit;
    End;
  If NodelistHost(A, H, Port, Why) Then
    Begin
    Host := H;
    If Port <> 0 Then
      Host := Host + ':' + Num(Port);
    Msg := 'Calling ' + Host + ' (from the nodelist)';
    MsgUntil := fpTime + 5;
    End
  Else
    Begin
    Msg := 'No host for ' + AddrS + ': ' + Why + '; type one';
    MsgUntil := fpTime + 6;
    ResolveHost := False;
    End;
  End;


Procedure RequestDialog;
  {F: ask a system for files (FTS-0006): the address (the chosen link at first), a host to call if it is not a link
   (or empty for the host of the link), the session password (empty for none), the names, and whether to call now}
  Const
    NF = 5;
    Lab: Array[1..NF] Of String[18] =
      ('System address', 'Host[:port]', 'Session password', 'Files', 'Call now (Y/N)');
  Var
    V: Array[1..NF] Of String;
    Cur, i, W: Word;
    C: Char;
    Done: Boolean;
    T, Show: String;
    Ack: Boolean;

  Begin
  For i := 1 To NF Do
    V[i] := '';
  If (NumLinks > 0) And (SelLink >= 1) And (SelLink <= NumLinks) Then
    V[1] := Links[SelLink].Addr;
  V[5] := 'Y';
  Cur := 1;
  Done := False;
  Ack := False;
  W := 70;
  Repeat
    Draw;
    Box(7, 4, 17, 4 + W + 1, 'Ask for files');
    PutAt(8, 6, aDim, 'Names, then !password and +time / -time for each, as in a .req (FTS-0006).');
    For i := 1 To NF Do
      Begin
      PutAt(9 + i, 6, aNorm, Pad(Lab[i], 18));
      Show := V[i];
      If i = 3 Then
        FillAt(9 + i, 25, 25 + Length(Show), aNorm, ' ');
      If i = 3 Then
        Begin
        T := '';
        While Length(T) < Length(Show) Do
          T := T + '*';
        Show := T;
        End;
      If Length(Show) > 48 Then
        Show := Copy(Show, Length(Show) - 47, 48);
      If i = Cur Then
        Begin
        FillAt(9 + i, 25, 25 + 49, aSel, ' ');
        PutAt(9 + i, 25, aSel, Show + '_');
        End
      Else
        Begin
        FillAt(9 + i, 25, 25 + 49, aNorm, ' ');
        PutAt(9 + i, 25, aNorm, Show);
        End;
      End;
    PutAt(15, 6, aDim, 'Host empty: the link''s, else the nodelist''s.  Password empty: none (unsecure).');
    PutAt(16, 6, aKeyHi, 'Enter');
    PutAt(16, 11, aNorm, ' next / send    ');
    PutAt(16, 27, aKeyHi, 'Up/Down');
    PutAt(16, 34, aNorm, ' field    ');
    PutAt(16, 44, aKeyHi, 'Esc');
    PutAt(16, 47, aNorm, ' cancel');
    Flush;
    C := GetKey(200);
    Case C Of
      #0: ;
      #27, #24, #3: Done := True;
      #1: If Cur > 1 Then Dec(Cur);
      #2, #9: If Cur < NF Then Inc(Cur);
      #8, #127:
        If Length(V[Cur]) > 0 Then
          Delete(V[Cur], Length(V[Cur]), 1);
      #13, #10:
        If Cur < NF Then
          Inc(Cur)
        Else
          Ack := True;
      Else
        If (C >= ' ') And (Length(V[Cur]) < 150) Then
          Begin
          If Cur = 5 Then
            V[5] := UpCase(C)
          Else
            V[Cur] := V[Cur] + C;
          End;
    End;
    If Ack Then
      Begin
      Ack := False;
      If (V[1] = '') Or (RequestLine(V[4]) = '') Then
        Begin
        Msg := 'The address and at least one file name are needed';
        MsgUntil := fpTime + 4;
        Cur := 1;
        If V[1] <> '' Then
          Cur := 4;
        End
      Else If Not ResolveHost(V[1], V[2]) Then
        Cur := 2
      Else
        Begin
        If V[2] = '' Then V[2] := '-';
        If V[3] = '' Then V[3] := '-';
        T := '0';
        If V[5] = 'Y' Then T := '1';
        SendCmd('REQ ' + V[1] + ' ' + V[2] + ' ' + V[3] + ' ' + T + ' ' + RequestLine(V[4]));
        Msg := 'Request sent';
        MsgUntil := fpTime + 6;
        Done := True;
        End;
      End;
    If Not Gone Then
      ReadSock;
  Until Done Or Gone;
  ForceAll := True;
  Dirty := True;
  End;


Function MailerScreen(RunDir: String): String;
  Var
    C: Char;
    Idle: Word;
    Cols_, Rows_: Word;
    LastDraw: Int64;
    Ask: Char;

  Begin
  MailerScreen := '';
  If Not OpenSock(RunDir) Then
    Begin
    MailerScreen := 'The mailer is not running (no ' + RunDir + '/mailer.sock).';
    Exit;
    End;
  InBuf := '';
  NumLinks := 0;
  NumSess := 0;
  NumLogs := 0;
  NumFrame := 0;
  InFrame := False;
  HaveFrame := False;
  Gone := False;
  SelLink := 1;
  TopLink := 1;
  SelSess := 0;
  Msg := '';
  MeAddr := '';
  MeName := '';
  MeVersion := '';
  MeStarted := 0;
  FrameU := fpTime;
  FrameLocal := fpTime;
  Rows := 25;
  If ComSession^.GetWindowSize(Cols_, Rows_) Then
    If (Rows_ > 25) And (Rows_ <= MaxRows) Then
      Rows := Rows_;
  Utf8 := TermWantsUtf8(ComSession^.GetTermType);
  ForceAll := True;
  Dirty := True;
  LastDraw := 0;
  Idle := 0;
  Repeat
    ReadSock;
    If Gone Then
      Begin
      MailerScreen := 'The connection to the mailer was lost.';
      Break;
      End;
    If Dirty And (NowMs - LastDraw >= 100) And HaveFrame Then
      Begin
      Draw;
      Flush;
      Dirty := False;
      LastDraw := NowMs;
      End
    Else If (Msg <> '') And (fpTime >= MsgUntil) Then
      Dirty := True;
    C := GetKey(100);
    If C = #0 Then
      Begin
      Inc(Idle);
      If Idle > 6000 Then               {10 minutes without a key}
        Break;
      If (Idle Mod 10) = 0 Then
        Dirty := True;                  {the clocks}
      End
    Else
      Begin
      Idle := 0;
      Dirty := True;
      Case UpCase(C) Of
        'Q', #27, #24, #3: Break;
        #1: If SelLink > 1 Then Dec(SelLink);
        #2: If SelLink < NumLinks Then Inc(SelLink);
        #9: If NumSess > 0 Then
              Begin
              If SelSess >= NumSess Then SelSess := 1 Else Inc(SelSess);
              End;
        'P': If NumLinks > 0 Then
               SendCmd('POLL ' + Links[SelLink].Addr);
        'A': SendCmd('POLL *');
        'H': If NumLinks > 0 Then
               Begin
               If Pos('H', Links[SelLink].Flags) > 0 Then
                 SendCmd('FREE ' + Links[SelLink].Addr)
               Else
                 SendCmd('HOLD ' + Links[SelLink].Addr);
               End;
        'F': RequestDialog;
        'R': SendCmd('RESCAN');
        'L': SendCmd('RELOAD');
        'X': If (SelSess >= 1) And (SelSess <= NumSess) Then
               Begin
               Msg := 'End the session with ' + Sess[SelSess].Remote + '?  Y / N';
               MsgUntil := fpTime + 30;
               Draw;
               Flush;
               Ask := UpCase(GetKey(30000));
               If Ask = 'Y' Then
                 SendCmd('ABORT ' + Num(Sess[SelSess].Id))
               Else
                 Msg := 'Not ended';
               MsgUntil := fpTime + 3;
               End;
        End;
      End;
  Until False;
  If Sock >= 0 Then
    fpClose(Sock);
  Sock := -1;
  ComSession^.SendStr(Esc + '[0;37;40m' + Esc + '[2J' + Esc + '[H');
  CommFlushOut;
  End;


Begin
Sock := -1;
End.
