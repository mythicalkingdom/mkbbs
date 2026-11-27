{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKHubTalk;      {talk to a hub by hand and record the call as a transcript: the way a new profile is written}

{$I MKB.Def}

{
     HubTalk connects the keyboard and the screen of the person who started it (mk -G<id> -K) to the session of a hub.  What the hub says goes to the screen as it
     is and into the transcript as MKHubScr writes it ("<< " lines, cleaned); what is typed goes to the hub and into the transcript as ">> " lines (one entry
     for each thing typed up to the Enter key, or for a key that the hub answers; the password of the map file is written as stars).  File transfers: when the
     hub starts a Zmodem send (the "**" ^X "B00" header) the program receives it by the protocol of the map file and notes "-- download" in the transcript; Ctrl-U asks for a
     file name and sends it ("-- upload").  Ctrl-] ends the call.  When the input is not a terminal (a pipe) its end ends the call.
}

Interface

Uses MKComAbs, MKHubScr;

Function HubTalk(Var H: HubScriptObj; S: AbsComPtr; Xfer: HubXferProc; Cols, Rows: Word): Boolean;
  {H has the transcript and the password variable set; False when the session could not be run}


Implementation

Uses BaseUnix, termio, SysUtils, MKString, MKPlat;


Procedure Out(Const T: AnsiString);
  Begin
  If T <> '' Then
    fpWrite(1, T[1], Length(T));
  End;


Function HubTalk(Var H: HubScriptObj; S: AbsComPtr; Xfer: HubXferProc; Cols, Rows: Word): Boolean;
  Var
    Saved, Raw: Termios;
    IsTty, Done: Boolean;
    Pending: AnsiString;
    PendAt: Int64;
    Buf: Array[0..1023] Of Byte;
    Tail: String;
    P: TPollFd;
    N, i: LongInt;
    C: Char;
    Line: String;
    Got: Boolean;

  Procedure FlushPending;
    Begin
    If Pending <> '' Then
      Begin
      H.Note('>> ' + Pending);
      Pending := '';
      End;
    End;

  Procedure Cooked;
    Begin
    If IsTty Then
      TCSetAttr(0, TCSANOW, Saved);
    End;

  Procedure RawMode;
    Begin
    If IsTty Then
      TCSetAttr(0, TCSANOW, Raw);
    End;

  Procedure DoXfer(Upload: Boolean);
    Var
      Name: String;
      Ok: Boolean;

    Begin
    FlushPending;
    H.FlushLog;
    Name := '';
    If Upload Then
      Begin
      Cooked;
      Out(#13#10'File to send: ');
      Line := '';
      Repeat
        N := fpRead(0, Buf, 1);
        If (N = 1) And (Buf[0] <> 10) And (Buf[0] <> 13) Then
          Line := Line + Chr(Buf[0]);
      Until (N <> 1) Or (Buf[0] = 10) Or (Buf[0] = 13);
      RawMode;
      Name := StripBoth(Line, ' ');
      If Name = '' Then
        Begin
        Out('(not sent)'#13#10);
        Exit;
        End;
      End;
    If Upload Then
      H.Note('-- upload ' + Name)
    Else
      H.Note('-- download');
    If Upload Then
      Out(#13#10'[transfer: upload]'#13#10)
    Else
      Out(#13#10'[transfer: download]'#13#10);
    Ok := Assigned(Xfer) And Xfer(Upload, Name);
    If Ok Then
      Begin
      If Upload Then
        H.Note('-- upload done')
      Else
        H.Note('-- download done');
      Out('[transfer done]'#13#10);
      End
    Else
      Begin
      H.Note('-- transfer failed');
      Out('[transfer failed]'#13#10);
      End;
    Tail := '';
    End;

  Begin
  HubTalk := True;
  IsTty := TCGetAttr(0, Saved) = 0;
  If IsTty Then
    Begin
    Raw := Saved;
    CFMakeRaw(Raw);
    TCSetAttr(0, TCSANOW, Raw);
    End;
  Out('[talking to the hub: Ctrl-] ends, Ctrl-U sends a file; a Zmodem send of the hub is received]'#13#10);
  H.AutoReply := False;                  {the terminal of the person answers its queries}
  Pending := '';
  PendAt := 0;
  Tail := '';
  Done := False;
  While (Not Done) And S^.GetCarrier Do
    Begin
    Got := False;
    While S^.WaitForChar(0) Do
      Begin
      If Not Got Then
        FlushPending;                    {what was typed comes before the answer in the transcript}
      Got := True;
      C := S^.GetChar;
      H.Feed(C);
      Out(C);
      Tail := Tail + C;
      If Length(Tail) > 12 Then
        Delete(Tail, 1, Length(Tail) - 12);
      If Pos('**' + #24 + 'B00', Tail) > 0 Then
        Begin
        DoXfer(False);
        Break;
        End;
      End;
    P.fd := 0;
    P.events := POLLIN;
    P.revents := 0;
    N := fpPoll(@P, 1, 100);
    If (N > 0) And ((P.revents And (POLLIN Or POLLHUP)) <> 0) Then
      Begin
      N := fpRead(0, Buf, SizeOf(Buf));
      If N <= 0 Then
        Begin
        Done := True;                    {the end of the input: what the hub says to the last thing is still wanted}
        i := 0;
        While (i < 15) And S^.GetCarrier Do
          Begin
          If S^.WaitForChar(200) Then
            Begin
            FlushPending;
            While S^.WaitForChar(0) Do
              Begin
              C := S^.GetChar;
              H.Feed(C);
              Out(C);
              End;
            i := 0;
            End
          Else
            Inc(i);
          End;
        End
      Else
        For i := 0 To N - 1 Do
          Begin
          If Buf[i] = 29 Then
            Done := True                 {Ctrl-]}
          Else If Buf[i] = 21 Then
            DoXfer(True)                 {Ctrl-U}
          Else
            Begin
            S^.SendChar(Chr(Buf[i]));
            Pending := Pending + Chr(Buf[i]);
            If Pending <> '' Then
              If (Buf[i] = 13) Or (Buf[i] = 10) Then
                FlushPending
              Else
                PendAt := Int64(MKTicks);
            End;
          End;
      S^.FlushOut;
      End;
    If (Pending <> '') And (Int64(MKTicks) - PendAt > 1500) Then
      FlushPending;
    End;
  FlushPending;
  H.FlushLog;
  H.Note('-- talk ended');
  Cooked;
  Out(#13#10'[the call has ended]'#13#10);
  End;


End.
