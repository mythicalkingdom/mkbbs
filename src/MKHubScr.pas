Unit MKHubScr;       {a script for the call to a QWK hub: expect / send over a session, with forgiving matching}

{$I MKB.Def}

{
     MKHubScr runs a small script over a session (MKComAbs: normally the Telnet client of MKComClient).  The text from the
     other end is cleaned before it is matched: ANSI / escape sequences are taken out (a prompt that is cut up by colour
     codes still matches), backspaces delete, NUL and bell are dropped.  Matching is not case sensitive and looks for a
     piece of text, not a whole line.  Terminal queries of the other end (ESC[c, ESC[5n, ESC[6n) are answered by the engine
     itself (AutoReply, default on), so a BBS that probes the terminal does not make the script wait.

     The script is lines of text; blank lines and lines that start with # or ; are comments.  A text is "in quotes" (or a
     single word); in it %name% is the variable name, %% a percent sign, and \r \n \t \e \\ \" \xNN are the characters.

       timeout N                 seconds an expect / try waits (default 30)
       expect "a|b" [N]          wait for any of the pieces (| separates them); not seen in N seconds: the script fails
       try "a|b" [N]             the same, but it goes on when nothing comes; sets found (1 or empty)
       send "text"               send the text as it is;   sendln "text" adds a carriage return
       when "text" send "reply"  from now on, whenever the text arrives while the script waits, the reply is sent
                                 (optional prompts such as "Press any key"); when "text" alone drops that rule; clear when
       pause N                   wait N seconds (the other end's text is still taken in)
       upload [name]             a file transfer: the program that runs the script (SetXfer) sends the file
       download [name]           ... and receives the files the other end sends
       set name "value"          a variable;   if name / ifnot name / else / endif   (name is set and not empty)
                                 ifeq "a" "b" / ifne "a" "b": the two texts are the same (case does not matter) or not,
                                 for example   ifeq "%matched%" "no new messages"
       autoreply on|off          the answers to terminal queries
       log "text"                a line in the transcript
       fail "text"               stop with an error
       end                       stop, all is well (the same at the end of the script)
       hangup                    drop the connection and stop

     After expect and try the variable matched holds the piece that was seen.  Variables the program sets: login, password,
     id, protocol, rep (name of the reply packet when there is one to send), have_rep (1 when there is one).

     The transcript (SetTranscript) has what was received (cleaned, in <<), what was sent (>>, the password as stars) and each
     step.  Profiles (HubProfile) are scripts for the usual hubs: synchronet, mk.
}

Interface

Uses MKComAbs;


Const
  MaxHubLines = 400;
  MaxHubVars = 40;


Type HubXferProc = Function(Upload: Boolean; Arg: String): Boolean;


Type HubScriptObj = Object
  Sess: AbsComPtr;
  Lines: Array[1..MaxHubLines] Of String[200];
  NumLines: Word;
  VarName: Array[1..MaxHubVars] Of String[20];
  VarVal: Array[1..MaxHubVars] Of String[100];
  NumVars: Word;
  WhenText: Array[1..20] Of String[60];
  WhenSend: Array[1..20] Of String[80];
  NumWhen: Word;
  Txt: String;                         {cleaned text not matched yet}
  EscState: Byte;
  EscParams: String[20];
  AutoReply: Boolean;
  DefTimeout: Word;
  Xfer: HubXferProc;
  LogName: String;
  LogOpen: Boolean;
  LogF: Text;
  LogLine: String;                     {received text not yet in the transcript}
  Capturing: Boolean;                  {a transfer up went well: what the hub says afterwards is kept in Heard}
  Heard: AnsiString;                   {... for the reply of the hub to the reply packet (at most 8000 characters)}
  ErrText: String;
  ErrLine: Word;
  Constructor Init(S: AbsComPtr);
  Destructor Done;
  Procedure SetVar(Name, Value: String);
  Function  GetVar(Name: String): String;
  Procedure SetTranscript(FileName: String);
  Procedure SetXfer(P: HubXferProc);
  Function  Load(Text: AnsiString): Boolean;   {lines separated by CR LF or LF; False when there are too many}
  Function  Run: Boolean;
  { internal }
  Procedure Note(Text: String);
  Function  EnsureLog: Boolean;
  Procedure FlushLog;
  Procedure Feed(C: Char);
  Procedure Pump(Ms: Word);
  Procedure SendText(Text: String);
  Function  Wait(Alts: String; Secs: Word; Var Matched: String): Boolean;
  Function  CheckWhen: Boolean;
  Function  Subst(S: String): String;
  End;


Function HubProfile(Name: String): AnsiString;
  {the script of a profile ('' when there is none)}


Implementation


Uses MKString, MKPlat;


Const
  MaxTxt = 240;


Constructor HubScriptObj.Init(S: AbsComPtr);
  Begin
  Sess := S;
  NumLines := 0;
  NumVars := 0;
  NumWhen := 0;
  Txt := '';
  EscState := 0;
  EscParams := '';
  AutoReply := True;
  DefTimeout := 30;
  Xfer := Nil;
  LogName := '';
  LogOpen := False;
  LogLine := '';
  Capturing := False;
  Heard := '';
  ErrText := '';
  ErrLine := 0;
  End;


Destructor HubScriptObj.Done;
  Begin
  If LogOpen Then
    Begin
    FlushLog;
    Close(LogF);
    If IoResult <> 0 Then;
    LogOpen := False;
    End;
  End;


Procedure HubScriptObj.SetVar(Name, Value: String);
  Var
    i: Word;

  Begin
  Name := Lower(Name);
  i := 1;
  While (i <= NumVars) And (VarName[i] <> Name) Do
    Inc(i);
  If i > NumVars Then
    Begin
    If NumVars >= MaxHubVars Then
      Exit;
    Inc(NumVars);
    VarName[NumVars] := Name;
    End;
  VarVal[i] := Value;
  End;


Function HubScriptObj.GetVar(Name: String): String;
  Var
    i: Word;

  Begin
  GetVar := '';
  Name := Lower(Name);
  For i := 1 To NumVars Do
    If VarName[i] = Name Then
      GetVar := VarVal[i];
  End;


Procedure HubScriptObj.SetTranscript(FileName: String);
  Begin
  LogName := FileName;
  End;


Procedure HubScriptObj.SetXfer(P: HubXferProc);
  Begin
  Xfer := P;
  End;


Function HubScriptObj.EnsureLog: Boolean;
  Begin
  If (Not LogOpen) And (LogName <> '') Then
    Begin
    Assign(LogF, LogName);
    Rewrite(LogF);
    If IoResult <> 0 Then
      LogName := ''
    Else
      LogOpen := True;
    End;
  EnsureLog := LogOpen;
  End;


Procedure HubScriptObj.FlushLog;
  Begin
  If (LogLine <> '') And EnsureLog Then
    Begin
    WriteLn(LogF, '<< ', LogLine);
    LogLine := '';
    End;
  LogLine := '';
  End;


Procedure HubScriptObj.Note(Text: String);
  Var
    PW: String;
    P: Word;

  Begin
  If Not EnsureLog Then
    Exit;
  FlushLog;
  PW := GetVar('password');
  If PW <> '' Then
    Begin
    P := Pos(PW, Text);
    While P > 0 Do
      Begin
      Delete(Text, P, Length(PW));
      Insert('********', Text, P);
      P := Pos(PW, Text);
      End;
    End;
  WriteLn(LogF, Text);
  End;


Procedure HubScriptObj.Feed(C: Char);
  {one character from the other end: cleaned into Txt; terminal queries are answered}
  Var
    Reply: String;
    i: Word;

  Begin
  Case EscState Of
    0: Case C Of
         #27: EscState := 1;
         #0, #7: ;
         #8: If Length(Txt) > 0 Then
               Dec(Txt[0]);
         Else
           Begin
           If Length(Txt) >= MaxTxt Then
             Delete(Txt, 1, 100);
           Txt := Txt + C;
           If Capturing And (Length(Heard) < 8000) And (C <> #13) Then
             Heard := Heard + C;
           If LogName <> '' Then
             Begin
             If C = #10 Then
               FlushLog
             Else If C <> #13 Then
               If Length(LogLine) < 200 Then
                 LogLine := LogLine + C;
             End;
           End;
         End;
    1: Case C Of
         '[': Begin
              EscState := 2;
              EscParams := '';
              End;
         ']': EscState := 4;                 {OSC: up to BEL or ESC \}
         '(', ')', '*', '+', '#': EscState := 3;   {one more character}
         Else
           EscState := 0;
         End;
    2: If (C >= #64) And (C <= #126) Then
         Begin
         EscState := 0;
         Reply := '';
         If AutoReply Then
           Begin
           If (C = 'c') And ((EscParams = '') Or (EscParams = '0')) Then
             Reply := #27 + '[?1;0c'                  {device attributes: a VT100}
           Else If (C = 'n') And (EscParams = '5') Then
             Reply := #27 + '[0n'                     {status: ok}
           Else If (C = 'n') And (EscParams = '6') Then
             Reply := #27 + '[24;1R';                 {cursor position}
           End;
         For i := 1 To Length(Reply) Do
           Sess^.SendChar(Reply[i]);
         If Reply <> '' Then
           Sess^.FlushOut;
         End
       Else If Length(EscParams) < 20 Then
         EscParams := EscParams + C;
    3: EscState := 0;
    4: If (C = #7) Or (C = '\') Then
         EscState := 0;
    End;
  End;


Procedure HubScriptObj.Pump(Ms: Word);
  {take in what arrives; wait up to Ms for the first character}
  Begin
  If Not Sess^.WaitForChar(Ms) Then
    Exit;
  While Sess^.WaitForChar(0) Do
    Feed(Sess^.GetChar);
  End;


Procedure HubScriptObj.SendText(Text: String);
  Var
    i: Word;

  Begin
  If Text = '' Then
    Exit;
  For i := 1 To Length(Text) Do
    Sess^.SendChar(Text[i]);
  Sess^.FlushOut;
  Note('>> ' + Text);
  End;


Function Unesc(S: String): String;
  Var
    R: String;
    i, V: Word;
    C: Char;

  Function Hex(Ch: Char): Integer;
    Begin
    Case UpCase(Ch) Of
      '0'..'9': Hex := Ord(Ch) - 48;
      'A'..'F': Hex := Ord(UpCase(Ch)) - 55;
      Else Hex := -1;
      End;
    End;

  Begin
  R := '';
  i := 1;
  While i <= Length(S) Do
    Begin
    C := S[i];
    If (C = '\') And (i < Length(S)) Then
      Begin
      Inc(i);
      Case S[i] Of
        'r': R := R + #13;
        'n': R := R + #10;
        't': R := R + #9;
        'e': R := R + #27;
        '0': R := R + #0;
        '\': R := R + '\';
        '"': R := R + '"';
        'x': If (i + 2 <= Length(S)) And (Hex(S[i + 1]) >= 0) And (Hex(S[i + 2]) >= 0) Then
               Begin
               V := Hex(S[i + 1]) * 16 + Hex(S[i + 2]);
               R := R + Chr(V);
               Inc(i, 2);
               End
             Else
               R := R + 'x';
        Else R := R + S[i];
        End;
      End
    Else
      R := R + C;
    Inc(i);
    End;
  Unesc := R;
  End;


Function HubScriptObj.Subst(S: String): String;
  Var
    R, Name: String;
    i, j: Word;

  Begin
  R := '';
  i := 1;
  While i <= Length(S) Do
    Begin
    If S[i] = '%' Then
      Begin
      If (i < Length(S)) And (S[i + 1] = '%') Then
        Begin
        R := R + '%';
        Inc(i, 2);
        End
      Else
        Begin
        j := i + 1;
        While (j <= Length(S)) And (S[j] <> '%') Do
          Inc(j);
        If j <= Length(S) Then
          Begin
          Name := Copy(S, i + 1, j - i - 1);
          R := R + GetVar(Name);
          i := j + 1;
          End
        Else
          Begin
          R := R + S[i];
          Inc(i);
          End;
        End;
      End
    Else
      Begin
      R := R + S[i];
      Inc(i);
      End;
    End;
  Subst := R;
  End;


Function HubScriptObj.CheckWhen: Boolean;
  {a rule of "when" matches: its reply is sent and the text is used up}
  Var
    i, P: Word;
    L: String;

  Begin
  CheckWhen := False;
  L := Lower(Txt);
  For i := 1 To NumWhen Do
    Begin
    P := Pos(Lower(WhenText[i]), L);
    If P > 0 Then
      Begin
      Note('-- when "' + WhenText[i] + '"');
      Delete(Txt, 1, P + Length(WhenText[i]) - 1);
      SendText(WhenSend[i]);
      CheckWhen := True;
      Exit;
      End;
    End;
  End;


Function HubScriptObj.Wait(Alts: String; Secs: Word; Var Matched: String): Boolean;
  Var
    Deadline: Int64;
    L, A: String;
    P, Q, Best: Word;
    Found, Gone: Boolean;

  Begin
  Matched := '';
  Wait := False;
  Gone := False;
  Deadline := MKTicks + Int64(Secs) * 1000;
  Repeat
    Pump(0);
    L := Lower(Txt);
    Best := 0;
    A := Alts;
    Repeat
      Q := Pos('|', A);
      If Q = 0 Then
        Begin
        Matched := A;
        A := '';
        End
      Else
        Begin
        Matched := Copy(A, 1, Q - 1);
        A := Copy(A, Q + 1, 255);
        End;
      If Matched <> '' Then
        Begin
        P := Pos(Lower(Matched), L);
        If P > 0 Then
          Begin
          Delete(Txt, 1, P + Length(Matched) - 1);
          Wait := True;
          Exit;
          End;
        End;
    Until A = '';
    Matched := '';
    If CheckWhen Then
      Continue;
    If MKTicks >= Deadline Then
      Exit;
    If Gone Then
      Exit;                            {the connection ended and what came with it did not match}
    Pump(100);
    If Not Sess^.GetCarrier Then
      Gone := True;                    {one more look at what arrived with the end}
  Until False;
  End;


Function HubScriptObj.Load(Text: AnsiString): Boolean;
  Var
    P: LongInt;
    S: String;

  Begin
  Load := True;
  NumLines := 0;
  While Text <> '' Do
    Begin
    P := Pos(#10, Text);
    If P = 0 Then
      Begin
      S := Text;
      Text := '';
      End
    Else
      Begin
      S := Copy(Text, 1, P - 1);
      Text := Copy(Text, P + 1, Length(Text));
      End;
    While (S <> '') And (S[Length(S)] In [#13, ' ', #9]) Do
      Dec(S[0]);
    While (S <> '') And (S[1] In [' ', #9]) Do
      Delete(S, 1, 1);
    If NumLines >= MaxHubLines Then
      Begin
      Load := False;
      Exit;
      End;
    Inc(NumLines);
    Lines[NumLines] := S;
    End;
  End;


Function NextToken(Var S: String; Var Tok: String): Boolean;
  {the next word or "quoted text" of S (the quotes are taken off, escapes stay)}
  Var
    i: Word;

  Begin
  NextToken := False;
  Tok := '';
  While (S <> '') And (S[1] In [' ', #9]) Do
    Delete(S, 1, 1);
  If S = '' Then
    Exit;
  NextToken := True;
  If S[1] = '"' Then
    Begin
    i := 2;
    While (i <= Length(S)) And (S[i] <> '"') Do
      Begin
      If (S[i] = '\') And (i < Length(S)) Then
        Inc(i);
      Inc(i);
      End;
    Tok := Copy(S, 2, i - 2);
    Delete(S, 1, i);
    End
  Else
    Begin
    i := 1;
    While (i <= Length(S)) And Not (S[i] In [' ', #9]) Do
      Inc(i);
    Tok := Copy(S, 1, i - 1);
    Delete(S, 1, i - 1);
    End;
  End;


Function HubScriptObj.Run: Boolean;
  Var
    PC: Word;
    S, Cmd, A1, A2, A3: String;
    Depth: Word;
    Active: Array[0..10] Of Boolean;      {the branch of the if in force}
    Taken: Array[0..10] Of Boolean;       {a branch of this if was taken}
    Matched: String;
    N: Word;
    Ok, Stop: Boolean;
    i: Word;

  Procedure Fail(Text: String);
    Begin
    ErrLine := PC;
    ErrText := 'line ' + Long2Str(PC) + ': ' + Text;
    Note('-- FAILED ' + ErrText);
    Stop := True;
    Ok := False;
    End;

  Function Arg(S: String): String;
    Begin
    Arg := Unesc(Subst(S));
    End;

  Function Truth(Name: String): Boolean;
    Begin
    Truth := GetVar(Name) <> '';
    End;

  Begin
  ErrText := '';
  ErrLine := 0;
  Ok := True;
  Stop := False;
  Depth := 0;
  Active[0] := True;
  Taken[0] := True;
  PC := 0;
  While (Not Stop) And (PC < NumLines) Do
    Begin
    Inc(PC);
    S := Lines[PC];
    If (S = '') Or (S[1] = '#') Or (S[1] = ';') Then
      Continue;
    If Not NextToken(S, Cmd) Then
      Continue;
    Cmd := Lower(Cmd);
    { if / else / endif }
    If (Cmd = 'if') Or (Cmd = 'ifnot') Or (Cmd = 'ifeq') Or (Cmd = 'ifne') Then
      Begin
      NextToken(S, A1);
      If (Cmd = 'ifeq') Or (Cmd = 'ifne') Then
        NextToken(S, A2);
      If Depth >= 10 Then
        Begin
        Fail('if is nested too deep');
        Continue;
        End;
      Inc(Depth);
      If Active[Depth - 1] Then
        Begin
        If Cmd = 'if' Then
          Active[Depth] := Truth(A1)
        Else If Cmd = 'ifnot' Then
          Active[Depth] := Not Truth(A1)
        Else If Cmd = 'ifeq' Then
          Active[Depth] := Lower(Arg(A1)) = Lower(Arg(A2))
        Else
          Active[Depth] := Lower(Arg(A1)) <> Lower(Arg(A2));
        Taken[Depth] := Active[Depth];
        End
      Else
        Begin
        Active[Depth] := False;
        Taken[Depth] := True;
        End;
      Continue;
      End;
    If Cmd = 'else' Then
      Begin
      If Depth = 0 Then
        Fail('else without if')
      Else
        Begin
        Active[Depth] := Active[Depth - 1] And (Not Taken[Depth]);
        Taken[Depth] := True;
        End;
      Continue;
      End;
    If Cmd = 'endif' Then
      Begin
      If Depth = 0 Then
        Fail('endif without if')
      Else
        Dec(Depth);
      Continue;
      End;
    If Not Active[Depth] Then
      Continue;
    NextToken(S, A1);
    NextToken(S, A2);
    NextToken(S, A3);
    If Cmd = 'timeout' Then
      DefTimeout := Str2Long(Arg(A1))
    Else If (Cmd = 'expect') Or (Cmd = 'try') Then
      Begin
      N := DefTimeout;
      If A2 <> '' Then
        N := Str2Long(Arg(A2));
      Note('-- ' + Cmd + ' "' + Arg(A1) + '" (' + Long2Str(N) + ' s)');
      If Wait(Arg(A1), N, Matched) Then
        Begin
        SetVar('matched', Matched);
        SetVar('found', '1');
        Note('-- seen "' + Matched + '"');
        End
      Else
        Begin
        SetVar('matched', '');
        SetVar('found', '');
        If Cmd = 'expect' Then
          Begin
          If Not Sess^.GetCarrier Then
            Fail('the connection was closed while waiting for "' + Arg(A1) + '"')
          Else
            Fail('"' + Arg(A1) + '" did not come in ' + Long2Str(N) + ' seconds; last text: "' +
              Copy(Txt, Length(Txt) - 60, 61) + '"');
          End
        Else
          Note('-- not seen');
        End;
      End
    Else If Cmd = 'send' Then
      SendText(Arg(A1))
    Else If Cmd = 'sendln' Then
      SendText(Arg(A1) + #13)
    Else If Cmd = 'when' Then
      Begin
      If A2 = '' Then
        Begin                          {drop the rule}
        i := 1;
        While i <= NumWhen Do
          If Lower(WhenText[i]) = Lower(Arg(A1)) Then
            Begin
            WhenText[i] := WhenText[NumWhen];
            WhenSend[i] := WhenSend[NumWhen];
            Dec(NumWhen);
            End
          Else
            Inc(i);
        End
      Else If (Lower(A2) = 'send') And (NumWhen < 20) Then
        Begin
        Inc(NumWhen);
        WhenText[NumWhen] := Arg(A1);
        WhenSend[NumWhen] := Arg(A3);
        End
      Else
        Fail('when "text" send "reply"');
      End
    Else If Cmd = 'clear' Then
      NumWhen := 0
    Else If Cmd = 'pause' Then
      Begin
      N := Str2Long(Arg(A1));
      Note('-- pause ' + Long2Str(N));
      i := 0;
      While i < N * 10 Do
        Begin
        Pump(100);
        If CheckWhen Then;              {optional prompts are answered while it waits, too}
        Inc(i);
        End;
      End
    Else If (Cmd = 'upload') Or (Cmd = 'download') Then
      Begin
      FlushLog;
      Note('-- ' + Cmd + ' ' + Arg(A1));
      Pump(0);
      If Not Assigned(Xfer) Then
        Fail('no file transfer is set up')
      Else If Not Xfer(Cmd = 'upload', Arg(A1)) Then
        Fail('the ' + Cmd + ' did not work')
      Else
        Begin
        Note('-- ' + Cmd + ' done');
        If Cmd = 'upload' Then
          Begin
          Capturing := True;
          Heard := '';
          End;
        End;
      End
    Else If Cmd = 'set' Then
      SetVar(Arg(A1), Arg(A2))
    Else If Cmd = 'autoreply' Then
      AutoReply := Lower(A1) = 'on'
    Else If Cmd = 'log' Then
      Note('-- ' + Arg(A1))
    Else If Cmd = 'fail' Then
      Fail(Arg(A1))
    Else If Cmd = 'end' Then
      Stop := True
    Else If Cmd = 'hangup' Then
      Begin
      Note('-- hangup');
      Pump(0);
      Sess^.Hangup;
      Stop := True;
      End
    Else
      Fail('unknown command "' + Cmd + '"');
    End;
  If Ok And (Depth > 0) Then
    Begin
    ErrText := 'if without endif';
    Ok := False;
    End;
  If Ok Then
    Note('-- script done');
  FlushLog;
  Run := Ok;
  End;


{ ---- profiles }

Function HubProfile(Name: String): AnsiString;
  Var
    R: AnsiString;

  Procedure Add(S: String);
    Begin
    R := R + S + #13#10;
    End;

  Begin
  Name := Lower(Name);
  R := '';
  If Name = 'mk' Then
    Begin
    Add('# mk -Q of another MK system');
    Add('timeout 30');
    Add('when "press any key" send " "');
    Add('expect "login:|user name|your name"');
    Add('sendln "%login%"');
    Add('expect "password:"');
    Add('sendln "%password%"');
    Add('expect "QWK:" 60');
    Add('if have_rep');
    Add('  send "U"');
    Add('  expect "begin transfer"');
    Add('  upload "%rep%"');
    Add('  expect "QWK:" 120');
    Add('endif');
    Add('send "D"');
    Add('# a packet ("Begin transfer now") or nothing for the caller (the QWK: prompt comes again)');
    Add('expect "begin transfer|QWK:" 120');
    Add('ifeq "%matched%" "begin transfer"');
    Add('  download');
    Add('  expect "QWK:" 120');
    Add('endif');
    Add('send "Q"');
    Add('hangup');
    End
  Else If Name = 'synchronet' Then
    Begin
    Add('# a Synchronet hub: the QWK: menu of a user (checked with Synchronet 3.19: login, D, U, the hang up prompt)');
    Add('# The packet comes first (D, and N to "Hang up after transfer?"), then the reply packet (U, the same question).');
    Add('timeout 30');
    Add('when "press any key" send " "');
    Add('when "hit a key" send " "');
    Add('expect "login:|user name|your name"');
    Add('sendln "%login%"');
    Add('expect "password:|pw:"');
    Add('sendln "%password%"');
    Add('expect "QWK:" 120');
    Add('send "D"');
    Add('# the packet is made (it can take a while), then: protocol (the user has one: it shows "Protocol or Quit: Z"),');
    Add('# "Hang up after transfer?" (answered N), the transfer; or "No new messages."');
    Add('expect "after transfer|no new messages|protocol or quit" 240');
    Add('ifeq "%matched%" "protocol or quit"');
    Add('  send "%protocol%"');
    Add('  expect "after transfer" 30');
    Add('endif');
    Add('ifeq "%matched%" "no new messages"');
    Add('  expect "QWK:" 30');
    Add('else');
    Add('  send "N"');
    Add('  download');
    Add('  expect "QWK:" 60');
    Add('endif');
    Add('if have_rep');
    Add('  send "U"');
    Add('  expect "protocol or quit|zmodem" 30');
    Add('  send "%protocol%"');
    Add('  # the same "Hang up after transfer?" question as for D: it must be answered before the transfer starts');
    Add('  expect "after transfer" 30');
    Add('  send "N"');
    Add('  upload "%rep%"');
    Add('  # the hub unpacks the reply packet and shows the prompt again (or logs off: "Good-bye!")');
    Add('  try "good-bye|QWK:" 120');
    Add('  ifeq "%matched%" "qwk:"');
    Add('    send "Q"');
    Add('  endif');
    Add('else');
    Add('  send "Q"');
    Add('endif');
    Add('hangup');
    End;
  HubProfile := R;
  End;


End.
