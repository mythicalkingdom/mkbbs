Unit MKChatCore;   {The room of the multi-node chat: spool files in the run directory, presence, flood limit, word filter, log (MCHAT-PLAN.md); no screen in here}

{$MODE OBJFPC}
{$H+}

{
  The room is a directory <rundir>/chat:
    room.log   append-only: one line per event, fields separated by a TAB:  time  kind  node  target  name  text
                 kind  S say   M /me   J join   L leave   P private (target = the node it is for)   X the sysop   N a notice of the system
               A line is written with one write call on a file opened for appending, so lines of different nodes never mix.
    in<N>      who is in the room from node N: name, the time, the process id (a file whose process is gone is stale and is ignored)
  Each node remembers the offset it has read to (Offset) and takes what is new (Poll).  Nothing is ever pushed into a screen: the caller's program asks.
  The log file of the BBS (chat.log, next to the log of the BBS) gets every line when the sysop wants it, private ones too.
}

Interface

Uses Classes, SysUtils, MKGlobT;

Const
  MuteForever = 2000000000;

Type
  TChatRoom = Class
    Cfg: ChatCfgType;
    Dir: String;                       {<rundir>/chat/}
    LogName: String;                   {chat.log ('' = no log)}
    BanFile: String;                   {chatban.lst}
    Node: Integer;
    Name: String;                      {what the others see}
    Offset: Int64;                     {room.log is read up to here}
    MutedUntil: Int64;                 {a unix time: the caller cannot speak before it}
    Words: TStringList;
    Ignored: TStringList;              {names (lower case) and node numbers the caller does not want to read}
    Sent: Array[0..63] Of Int64;       {the times of the last lines, for the flood limit}
    SentN: Integer;
    Joined: Boolean;
    Kicked: Boolean;                   {the sysop removed the caller: the screen leaves}
    SeeAll: Boolean;                   {the sysop's view: private lines are shown too}
    RealName: String;
    CtlOffset: Int64;                  {ctl is read up to here}
    Constructor Create(Const RunDir, ALogName, ABanFile: String; Const C: ChatCfgType; ANode: Integer);
    Destructor Destroy; Override;
    Function Banned(Const N: String): Boolean;
    Procedure Join(Const AName, ARealName: String);
    Procedure Leave;
    Function Say(Const Text: String; Out Why: String): Boolean;      {False: the line was not sent (Why says it)}
    Function Me(Const Text: String; Out Why: String): Boolean;
    Function Tell(ToNode: Integer; Const Text: String; Out Why: String): Boolean;
    Function Poll(Lines: TStrings): Integer;                        {the new lines to show (and the sysop's commands for this node done); the number of lines}
    Procedure Tail(Lines: TStrings; N: Integer);                    {the last N lines of the room as the sysop sees them (private ones too)}
    Procedure History(Lines: TStrings);
    Procedure Who(Lines: TStrings);                                 {one line for each caller in the room}
    Function NodeOf(Const Who_: String): Integer;                   {a node number, or the node of a name; 0 = nobody}
    Function NameOfNode(N: Integer): String;
    Procedure Ignore(Const What: String);
    Function Clean(Const S: String): String;                        {printable characters only, cut to the line length}
    Function Filter(Var S: String): Boolean;                        {the word file: masked, or False when the line is refused}
    Private
    Function Flooding: Boolean;
    Procedure Put(Kind: Char; Target: Integer; Const Text: String);
    Procedure LogLine(Const S: String);
    Function Format_(Const L: String; ForPoll: Boolean; Out Shown: Boolean): String;
    End;

Function ChatDir(Const RunDir: String): String;
Function Now_: Int64;

{ what the sysop does (mkmon, mkchatctl): all through files in <rundir>/chat, so the nodes take it up when they next look }
Procedure ChatCtl(Const RunDir, Cmd: String; Node, Arg: Integer);          {mute (Arg minutes, 0 = unmute), kick: for a node, 0 = every node}
Procedure ChatSysopLine(Const RunDir: String; Kind: Char; Const Text: String);   {X a line of the sysop, N a notice, shown in the room}
Function ChatPresence(Const RunDir: String; Node: Integer; Out Shown, Real: String): Boolean;   {who is in the room from that node}
Procedure ChatBan(Const BanFile, Name: String);
Function ChatUnban(Const BanFile, Name: String): Boolean;

{ a message of the sysop to every node, in or out of the room (the callers see it at their next key wait) }
Procedure SysMsgSend(Const RunDir, Text: String);
Function SysMsgPoll(Const RunDir: String; Var Offset: Int64; Lines: TStrings): Integer;   {Offset -1: from now on}
Function SysMsgNext(Const RunDir: ShortString; Var Offset: Int64; Var Line: ShortString): Boolean;   {the same, one message at a time (for the units that are in Turbo Pascal mode)}

Implementation

Uses BaseUnix, DateUtils;


Function Now_: Int64;
  Begin
  Result := fpTime;
  End;


Function ChatDir(Const RunDir: String): String;
  Begin
  Result := RunDir;
  If (Result <> '') And (Result[Length(Result)] <> '/') Then
    Result := Result + '/';
  Result := Result + 'chat/';
  End;


Function Field(Const S: String; N: Integer): String;
  {the N-th field (from 0) of a line with TABs; the last field is the rest}
  Var
    i, Start, k: Integer;

  Begin
  Result := '';
  Start := 1;
  k := 0;
  For i := 1 To Length(S) Do
    If (S[i] = #9) And (k < N) Then
      Begin
      Inc(k);
      Start := i + 1;
      End
    Else If (S[i] = #9) And (k = N) Then
      Begin
      Result := Copy(S, Start, i - Start);
      Exit;
      End;
  If k = N Then
    Result := Copy(S, Start, Length(S));
  End;


Function PidAlive(Pid: LongInt): Boolean;
  Begin
  Result := (Pid > 0) And ((fpKill(Pid, 0) = 0) Or (fpGetErrno = ESysEPERM));
  End;


Function ReadAll(Const FN: String; Var S: String; From: Int64): Boolean;
  {the bytes of a file from an offset (the whole of what is there: the room log is small)}
  Var
    Fd: LongInt;
    Size: Int64;
    N: LongInt;

  Begin
  Result := False;
  S := '';
  Fd := fpOpen(FN, O_RDONLY);
  If Fd < 0 Then
    Exit;
  Size := fpLSeek(Fd, 0, SEEK_END);
  If (Size > From) And (Size - From < 4000000) Then
    Begin
    SetLength(S, Size - From);
    fpLSeek(Fd, From, SEEK_SET);
    N := fpRead(Fd, S[1], Size - From);
    If N < 0 Then
      N := 0;
    SetLength(S, N);
    End;
  fpClose(Fd);
  Result := True;
  End;


Constructor TChatRoom.Create(Const RunDir, ALogName, ABanFile: String; Const C: ChatCfgType; ANode: Integer);
  Begin
  Cfg := C;
  If Cfg.MaxLine = 0 Then
    Cfg.MaxLine := 160;
  If Cfg.MaxLine > 250 Then
    Cfg.MaxLine := 250;
  Dir := ChatDir(RunDir);
  LogName := ALogName;
  BanFile := ABanFile;
  Node := ANode;
  Words := TStringList.Create;
  Ignored := TStringList.Create;
  Ignored.CaseSensitive := False;
  End;


Destructor TChatRoom.Destroy;
  Begin
  If Joined Then
    Leave;
  Words.Free;
  Ignored.Free;
  Inherited Destroy;
  End;


Function TChatRoom.Banned(Const N: String): Boolean;
  Var
    L: TStringList;
    i: Integer;

  Begin
  Result := False;
  If (BanFile = '') Or Not FileExists(BanFile) Then
    Exit;
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(BanFile);
    Except
      Exit;
    End;
    For i := 0 To L.Count - 1 Do
      If (Trim(L[i]) <> '') And (Copy(Trim(L[i]), 1, 1) <> '#') And (CompareText(Trim(L[i]), Trim(N)) = 0) Then
        Begin
        Result := True;
        Break;
        End;
  Finally
    L.Free;
  End;
  End;


Procedure TChatRoom.LogLine(Const S: String);
  Var
    Fd: LongInt;
    L: String;

  Begin
  If (Not Cfg.LogChat) Or (LogName = '') Then
    Exit;
  L := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + S + #10;
  Fd := fpOpen(LogName, O_WRONLY Or O_CREAT Or O_APPEND, &640);
  If Fd >= 0 Then
    Begin
    fpWrite(Fd, L[1], Length(L));
    fpClose(Fd);
    End;
  End;


Procedure TChatRoom.Put(Kind: Char; Target: Integer; Const Text: String);
  Var
    Fd: LongInt;
    L: String;

  Begin
  L := IntToStr(Now_) + #9 + Kind + #9 + IntToStr(Node) + #9 + IntToStr(Target) + #9 + Name + #9 + Text + #10;
  Fd := fpOpen(Dir + 'room.log', O_WRONLY Or O_CREAT Or O_APPEND, &660);
  If Fd >= 0 Then
    Begin
    fpWrite(Fd, L[1], Length(L));
    fpClose(Fd);
    End;
  Case Kind Of
    'S': LogLine('n' + IntToStr(Node) + ' ' + Name + ': ' + Text);
    'M': LogLine('n' + IntToStr(Node) + ' * ' + Name + ' ' + Text);
    'P': LogLine('n' + IntToStr(Node) + ' ' + Name + ' -> n' + IntToStr(Target) + ' (private): ' + Text);
    'J': LogLine('n' + IntToStr(Node) + ' ' + Name + ' joined');
    'L': LogLine('n' + IntToStr(Node) + ' ' + Name + ' left');
    End;
  End;


Procedure TChatRoom.Join(Const AName, ARealName: String);
  Var
    SR: TSearchRec;
    Others: Boolean;
    L: TStringList;
    Fd: LongInt;
    FN: String;
    Sz: Int64;
    St: Stat;

  Begin
  Name := AName;
  RealName := ARealName;
  Kicked := False;
  ForceDirectories(Dir);
  fpChmod(Dir, &770);
  Others := False;
  If FindFirst(Dir + 'in*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      FN := Dir + SR.Name;
      L := TStringList.Create;
      Try
        Try
          L.LoadFromFile(FN);
        Except
          L.Clear;
        End;
        If (L.Count >= 3) And PidAlive(StrToIntDef(L[2], 0)) And (SR.Name <> 'in' + IntToStr(Node)) Then
          Others := True
        Else If SR.Name <> 'in' + IntToStr(Node) Then
          DeleteFile(FN);                {stale}
      Finally
        L.Free;
      End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  If (Not Others) And (fpStat(Dir + 'room.log', St) = 0) And (St.st_size > 65536) Then
    Begin                                {nobody is here: the old lines are not needed (chat.log has them), a new room starts}
    Fd := fpOpen(Dir + 'room.log', O_WRONLY Or O_TRUNC);
    If Fd >= 0 Then
      fpClose(Fd);
    End;
  L := TStringList.Create;
  L.Add(Name);
  L.Add(IntToStr(Now_));
  L.Add(IntToStr(fpGetPid));
  L.Add(RealName);
  Try
    L.SaveToFile(Dir + 'in' + IntToStr(Node));
  Except
  End;
  L.Free;
  Sz := 0;
  If fpStat(Dir + 'room.log', St) = 0 Then
    Sz := St.st_size;
  Offset := Sz;                          {what comes now; History gives what went before}
  CtlOffset := 0;
  If fpStat(Dir + 'ctl', St) = 0 Then
    CtlOffset := St.st_size;               {commands of before this join are not for this join}
  Joined := True;
  Words.Clear;
  If Trim(Cfg.WordFile) <> '' Then
    Begin
    L := TStringList.Create;
    Try
      Try
        L.LoadFromFile(Trim(Cfg.WordFile));
        For Sz := 0 To L.Count - 1 Do
          If (Trim(L[Sz]) <> '') And (Copy(Trim(L[Sz]), 1, 1) <> '#') Then
            Words.Add(LowerCase(Trim(L[Sz])));
      Except
      End;
    Finally
      L.Free;
    End;
    End;
  Put('J', 0, '');
  End;


Procedure TChatRoom.Leave;
  Begin
  If Not Joined Then
    Exit;
  Joined := False;
  Put('L', 0, '');
  DeleteFile(Dir + 'in' + IntToStr(Node));
  End;


Function TChatRoom.Clean(Const S: String): String;
  Var
    i: Integer;
    R: String;

  Begin
  R := '';
  For i := 1 To Length(S) Do
    If (S[i] >= ' ') And (S[i] <> #127) Then
      R := R + S[i]
    Else If S[i] = #9 Then
      R := R + ' ';
  R := Trim(R);
  If Length(R) > Cfg.MaxLine Then
    SetLength(R, Cfg.MaxLine);
  Result := R;
  End;


Function TChatRoom.Filter(Var S: String): Boolean;
  Var
    i, p: Integer;
    Low: String;

  Begin
  Result := True;
  For i := 0 To Words.Count - 1 Do
    Begin
    Low := LowerCase(S);
    p := Pos(Words[i], Low);
    While p > 0 Do
      Begin
      If Cfg.WordAction = cwRefuse Then
        Begin
        Result := False;
        Exit;
        End;
      FillChar(S[p], Length(Words[i]), '*');
      Low := LowerCase(S);
      p := Pos(Words[i], Low);
      End;
    End;
  End;


Function TChatRoom.Flooding: Boolean;
  {the line about to be sent counts; True when it is over the limit (the caller is muted from now on)}
  Var
    T: Int64;
    i, k: Integer;

  Begin
  Result := False;
  If (Cfg.FloodLines = 0) Or (Cfg.FloodSecs = 0) Then
    Exit;
  T := Now_;
  k := 0;
  For i := 0 To SentN - 1 Do
    If T - Sent[i] < Cfg.FloodSecs Then
      Begin
      Sent[k] := Sent[i];
      Inc(k);
      End;
  SentN := k;
  If SentN >= Cfg.FloodLines Then
    Begin
    If Cfg.MuteMinutes > 0 Then
      MutedUntil := T + Cfg.MuteMinutes * 60;
    SentN := 0;
    Result := True;
    Exit;
    End;
  If SentN < High(Sent) Then
    Begin
    Sent[SentN] := T;
    Inc(SentN);
    End;
  End;


Function Check(R: TChatRoom; Var Text: String; Out Why: String): Boolean;
  Begin
  Result := False;
  Why := '';
  If Not R.Joined Then
    Exit;
  If R.MutedUntil > Now_ Then
    Begin
    If R.MutedUntil >= MuteForever Then
      Why := 'muted'
    Else
      Why := 'muted:' + IntToStr(R.MutedUntil - Now_);
    Exit;
    End;
  Text := R.Clean(Text);
  If Text = '' Then
    Exit;
  If Not R.Filter(Text) Then
    Begin
    Why := 'filtered';
    Exit;
    End;
  If R.Flooding Then
    Begin
    Why := 'flood:' + IntToStr(R.Cfg.MuteMinutes);
    Exit;
    End;
  Result := True;
  End;


Function TChatRoom.Say(Const Text: String; Out Why: String): Boolean;
  Var
    T: String;

  Begin
  T := Text;
  Result := Check(Self, T, Why);
  If Result Then
    Put('S', 0, T);
  End;


Function TChatRoom.Me(Const Text: String; Out Why: String): Boolean;
  Var
    T: String;

  Begin
  T := Text;
  Result := Check(Self, T, Why);
  If Result Then
    Put('M', 0, T);
  End;


Function TChatRoom.Tell(ToNode: Integer; Const Text: String; Out Why: String): Boolean;
  Var
    T: String;

  Begin
  T := Text;
  Why := '';
  If Not Cfg.PrivateMsg Then
    Begin
    Why := 'noprivate';
    Result := False;
    Exit;
    End;
  If NameOfNode(ToNode) = '' Then
    Begin
    Why := 'nobody';
    Result := False;
    Exit;
    End;
  Result := Check(Self, T, Why);
  If Result Then
    Put('P', ToNode, T);
  End;


Function TChatRoom.Format_(Const L: String; ForPoll: Boolean; Out Shown: Boolean): String;
  {a line of room.log as the caller sees it; Shown False: it is not for this caller (ignored, a private line of others, the caller's own join)}
  Var
    Kind: Char;
    N, Tg: Integer;
    Nm, Tx: String;

  Begin
  Result := '';
  Shown := False;
  If Length(Field(L, 1)) <> 1 Then
    Exit;
  Kind := Field(L, 1)[1];
  N := StrToIntDef(Field(L, 2), 0);
  Tg := StrToIntDef(Field(L, 3), 0);
  Nm := Field(L, 4);
  Tx := Field(L, 5);
  If (Kind In ['S', 'M', 'P', 'J', 'L']) And ForPoll And ((Ignored.IndexOf(Nm) >= 0) Or (Ignored.IndexOf(IntToStr(N)) >= 0)) And (N <> Node) Then
    Exit;
  Case Kind Of
    'S': Result := '<' + Nm + '> ' + Tx;
    'M': Result := '* ' + Nm + ' ' + Tx;
    'X': Result := '[sysop] ' + Tx;
    'N': Result := '*** ' + Tx;
    'J': If N = Node Then Exit Else Result := '*** ' + Nm + ' (node ' + IntToStr(N) + ') joined';
    'L': If N = Node Then Exit Else Result := '*** ' + Nm + ' left';
    'P': If Tg = Node Then Result := '[private from ' + Nm + ' (node ' + IntToStr(N) + ')] ' + Tx
         Else If SeeAll Then Result := '[private ' + Nm + ' (node ' + IntToStr(N) + ') to node ' + IntToStr(Tg) + '] ' + Tx
         Else Exit;
    Else
      Exit;
    End;
  Shown := True;
  End;


Function TChatRoom.Poll(Lines: TStrings): Integer;
  Var
    S, One: String;
    p, Used: Integer;
    Shown: Boolean;
    T: String;

  Begin
  Result := 0;
  If Joined And ReadAll(Dir + 'ctl', S, CtlOffset) And (S <> '') Then
    Begin                                {what the sysop told this node}
    Used := 0;
    While True Do
      Begin
      p := Pos(#10, Copy(S, Used + 1, Length(S)));
      If p = 0 Then
        Break;
      One := Copy(S, Used + 1, p - 1);
      Inc(Used, p);
      If (StrToIntDef(Field(One, 2), -1) = Node) Or (StrToIntDef(Field(One, 2), -1) = 0) Then
        Begin
        If Field(One, 1) = 'mute' Then
          Begin
          If StrToIntDef(Field(One, 3), 0) > 0 Then
            Begin
            MutedUntil := Now_ + StrToIntDef(Field(One, 3), 0) * 60;
            Lines.Add('*** You have been muted by the sysop for ' + Field(One, 3) + ' minute(s).');
            LogLine('n' + IntToStr(Node) + ' ' + Name + ' muted by the sysop for ' + Field(One, 3) + ' minute(s)');
            End
          Else
            Begin
            MutedUntil := 0;
            Lines.Add('*** The sysop lets you speak again.');
            LogLine('n' + IntToStr(Node) + ' ' + Name + ' unmuted by the sysop');
            End;
          Inc(Result);
          End
        Else If Field(One, 1) = 'kick' Then
          Begin
          Kicked := True;
          Lines.Add('*** You have been removed from the room by the sysop.');
          LogLine('n' + IntToStr(Node) + ' ' + Name + ' removed by the sysop');
          Inc(Result);
          End;
        End;
      End;
    Inc(CtlOffset, Used);
    End;
  If Not ReadAll(Dir + 'room.log', S, Offset) Then
    Exit;
  Used := 0;
  While True Do
    Begin
    p := Pos(#10, Copy(S, Used + 1, Length(S)));
    If p = 0 Then
      Break;
    One := Copy(S, Used + 1, p - 1);
    Inc(Used, p);
    T := Format_(One, True, Shown);
    If Shown Then
      Begin
      Lines.Add(T);
      Inc(Result);
      End;
    End;
  Inc(Offset, Used);
  End;


Procedure TChatRoom.History(Lines: TStrings);
  Var
    S, One: String;
    All: TStringList;
    i, p, Used: Integer;
    Shown: Boolean;
    T: String;

  Begin
  If Cfg.History = 0 Then
    Exit;
  If Not ReadAll(Dir + 'room.log', S, 0) Then
    Exit;
  All := TStringList.Create;
  Try
    Used := 0;
    While Used < Offset Do
      Begin
      p := Pos(#10, Copy(S, Used + 1, Length(S)));
      If p = 0 Then
        Break;
      One := Copy(S, Used + 1, p - 1);
      Inc(Used, p);
      If (Field(One, 1) = 'S') Or (Field(One, 1) = 'M') Or (Field(One, 1) = 'X') Then
        Begin
        T := Format_(One, False, Shown);
        If Shown Then
          All.Add(T);
        End;
      End;
    p := All.Count - Cfg.History;
    If p < 0 Then
      p := 0;
    For i := p To All.Count - 1 Do
      Lines.Add(All[i]);
  Finally
    All.Free;
  End;
  End;


Procedure TChatRoom.Tail(Lines: TStrings; N: Integer);
  Var
    S, One: String;
    All: TStringList;
    i, p, Used: Integer;
    Shown: Boolean;
    T: String;

  Begin
  SeeAll := True;
  If Not ReadAll(Dir + 'room.log', S, 0) Then
    Exit;
  All := TStringList.Create;
  Try
    Used := 0;
    While True Do
      Begin
      p := Pos(#10, Copy(S, Used + 1, Length(S)));
      If p = 0 Then
        Break;
      One := Copy(S, Used + 1, p - 1);
      Inc(Used, p);
      T := Format_(One, False, Shown);
      If Shown Then
        All.Add(FormatDateTime('hh:nn', UnixToDateTime(StrToInt64Def(Field(One, 0), 0), False) + 0) + ' ' + T);
      End;
    p := All.Count - N;
    If p < 0 Then
      p := 0;
    For i := p To All.Count - 1 Do
      Lines.Add(All[i]);
  Finally
    All.Free;
  End;
  End;


Procedure TChatRoom.Who(Lines: TStrings);
  Var
    SR: TSearchRec;
    L: TStringList;
    Items: TStringList;
    i: Integer;

  Begin
  Items := TStringList.Create;
  If FindFirst(Dir + 'in*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      L := TStringList.Create;
      Try
        Try
          L.LoadFromFile(Dir + SR.Name);
        Except
          L.Clear;
        End;
        If (L.Count >= 3) And PidAlive(StrToIntDef(L[2], 0)) Then
          Items.Add(Format('%.4d', [StrToIntDef(Copy(SR.Name, 3, 9), 0)]) + ' ' + L[0]);
      Finally
        L.Free;
      End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Items.Sort;
  For i := 0 To Items.Count - 1 Do
    Lines.Add('node ' + IntToStr(StrToIntDef(Copy(Items[i], 1, 4), 0)) + ': ' + Copy(Items[i], 6, 200));
  Items.Free;
  End;


Function TChatRoom.NameOfNode(N: Integer): String;
  Var
    L: TStringList;

  Begin
  Result := '';
  If (N <= 0) Or Not FileExists(Dir + 'in' + IntToStr(N)) Then
    Exit;
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(Dir + 'in' + IntToStr(N));
      If (L.Count >= 3) And PidAlive(StrToIntDef(L[2], 0)) Then
        Result := L[0];
    Except
    End;
  Finally
    L.Free;
  End;
  End;


Function TChatRoom.NodeOf(Const Who_: String): Integer;
  Var
    SR: TSearchRec;
    N: Integer;
    Found: Integer;

  Begin
  Result := 0;
  N := StrToIntDef(Trim(Who_), 0);
  If N > 0 Then
    Begin
    If NameOfNode(N) <> '' Then
      Result := N;
    Exit;
    End;
  Found := 0;
  If FindFirst(Dir + 'in*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      N := StrToIntDef(Copy(SR.Name, 3, 9), 0);
      If (N > 0) And (CompareText(NameOfNode(N), Trim(Who_)) = 0) And (N <> Node) Then
        Found := N;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Result := Found;
  End;


Procedure TChatRoom.Ignore(Const What: String);
  Var
    N: Integer;
    Nm: String;

  Begin
  If Trim(What) = '' Then
    Exit;
  N := StrToIntDef(Trim(What), 0);
  If N > 0 Then
    Begin
    Nm := NameOfNode(N);
    Ignored.Add(IntToStr(N));
    End
  Else
    Ignored.Add(Trim(What));
  End;


Procedure AppendLine(Const FN, L: String);
  Var
    Fd: LongInt;

  Begin
  Fd := fpOpen(FN, O_WRONLY Or O_CREAT Or O_APPEND, &660);
  If Fd >= 0 Then
    Begin
    fpWrite(Fd, L[1], Length(L));
    fpClose(Fd);
    End;
  End;


Procedure ChatCtl(Const RunDir, Cmd: String; Node, Arg: Integer);
  Begin
  ForceDirectories(ChatDir(RunDir));
  AppendLine(ChatDir(RunDir) + 'ctl', IntToStr(Now_) + #9 + Cmd + #9 + IntToStr(Node) + #9 + IntToStr(Arg) + #10);
  End;


Procedure ChatSysopLine(Const RunDir: String; Kind: Char; Const Text: String);
  Var
    T: String;
    i: Integer;

  Begin
  T := '';
  For i := 1 To Length(Text) Do
    If (Text[i] >= ' ') And (Text[i] <> #127) Then
      T := T + Text[i];
  ForceDirectories(ChatDir(RunDir));
  AppendLine(ChatDir(RunDir) + 'room.log', IntToStr(Now_) + #9 + Kind + #9 + '0' + #9 + '0' + #9 + 'Sysop' + #9 + Copy(T, 1, 250) + #10);
  End;


Function ChatPresence(Const RunDir: String; Node: Integer; Out Shown, Real: String): Boolean;
  Var
    L: TStringList;

  Begin
  Result := False;
  Shown := '';
  Real := '';
  If Not FileExists(ChatDir(RunDir) + 'in' + IntToStr(Node)) Then
    Exit;
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(ChatDir(RunDir) + 'in' + IntToStr(Node));
      If (L.Count >= 3) And PidAlive(StrToIntDef(L[2], 0)) Then
        Begin
        Shown := L[0];
        Real := L[0];
        If L.Count >= 4 Then
          Real := L[3];
        Result := True;
        End;
    Except
    End;
  Finally
    L.Free;
  End;
  End;


Procedure ChatBan(Const BanFile, Name: String);
  Var
    L: TStringList;
    i: Integer;

  Begin
  L := TStringList.Create;
  Try
    If FileExists(BanFile) Then
      L.LoadFromFile(BanFile);
    For i := 0 To L.Count - 1 Do
      If CompareText(Trim(L[i]), Trim(Name)) = 0 Then
        Exit;
    L.Add(Trim(Name));
    L.SaveToFile(BanFile);
  Finally
    L.Free;
  End;
  End;


Function ChatUnban(Const BanFile, Name: String): Boolean;
  Var
    L: TStringList;
    i: Integer;

  Begin
  Result := False;
  If Not FileExists(BanFile) Then
    Exit;
  L := TStringList.Create;
  Try
    L.LoadFromFile(BanFile);
    For i := L.Count - 1 Downto 0 Do
      If CompareText(Trim(L[i]), Trim(Name)) = 0 Then
        Begin
        L.Delete(i);
        Result := True;
        End;
    If Result Then
      L.SaveToFile(BanFile);
  Finally
    L.Free;
  End;
  End;


Procedure SysMsgSend(Const RunDir, Text: String);
  Var
    T: String;
    i: Integer;
    St: Stat;
    Fd: LongInt;

  Begin
  T := '';
  For i := 1 To Length(Text) Do
    If (Text[i] >= ' ') And (Text[i] <> #127) Then
      T := T + Text[i];
  If T = '' Then
    Exit;
  If (fpStat(RunDir + '/sysopmsg.log', St) = 0) And (St.st_size > 65536) Then
    Begin
    Fd := fpOpen(RunDir + '/sysopmsg.log', O_WRONLY Or O_TRUNC);
    If Fd >= 0 Then
      fpClose(Fd);
    End;
  AppendLine(RunDir + '/sysopmsg.log', IntToStr(Now_) + #9 + Copy(T, 1, 250) + #10);
  End;


Function SysMsgNext(Const RunDir: ShortString; Var Offset: Int64; Var Line: ShortString): Boolean;
  Var
    St: Stat;
    S: String;
    p: Integer;

  Begin
  Result := False;
  If RunDir = '' Then
    Exit;
  If fpStat(RunDir + '/sysopmsg.log', St) <> 0 Then
    Begin
    If Offset < 0 Then
      Offset := 0;
    Exit;
    End;
  If Offset < 0 Then
    Begin
    Offset := St.st_size;               {what was said before this caller came is not for them}
    Exit;
    End;
  If St.st_size < Offset Then
    Offset := 0;                        {the file was started again}
  If St.st_size = Offset Then
    Exit;
  If Not ReadAll(RunDir + '/sysopmsg.log', S, Offset) Then
    Exit;
  p := Pos(#10, S);
  If p = 0 Then
    Exit;
  Line := Copy(Field(Copy(S, 1, p - 1), 1), 1, 250);
  Inc(Offset, p);
  Result := True;
  End;


Function SysMsgPoll(Const RunDir: String; Var Offset: Int64; Lines: TStrings): Integer;
  Var
    L: ShortString;

  Begin
  Result := 0;
  While SysMsgNext(RunDir, Offset, L) Do
    Begin
    Lines.Add(L);
    Inc(Result);
    End;
  End;


End.
