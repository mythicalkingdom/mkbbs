Unit MKHubReplay;    {a fake hub made from a transcript: a session that answers a script with what a hub said when it was recorded}

{$I MKB.Def}

{
     The transcript of a call to a hub (the file of "transcript" in the map file: RemoteId.hub.log) has what the hub said (lines that begin
     with "<< ", cleaned), what the script sent (">> ", the characters as they were sent, the password as ********) and the steps ("-- ").
     ReplayComObj reads such a file and is a session (MKComAbs) for MKHubScr: it gives the script the text of the "<<" lines up to the next
     thing the script sent in the recording, waits until the script sends the same thing (the password stars match any text), and goes on.
     A file transfer ("-- upload", "-- download") is a step the script has to take at that place (ReplayXfer is its transfer procedure).
     When the script does something else, Fault says what was expected and what came, and the session ends (so the script fails at once).
     This tests a profile without calling anybody, and a transcript that a sysop sent in becomes a test.
}

Interface

Uses MKComAbs;

Const
  MaxEvents = 6000;

Type ReplayComObj = Object(AbsComObj)
  EvKind: Array[1..MaxEvents] Of Char;       {R the hub said a line, S the script sent, U upload, D download}
  EvText: Array[1..MaxEvents] Of AnsiString;
  NumEv, Idx: LongInt;
  Avail: AnsiString;                         {what the script has not read yet}
  AvPos: LongInt;
  Sent: AnsiString;                          {what the script sent that is not matched yet}
  Fault: String;
  Hung: Boolean;
  Starved: LongInt;
  Constructor InitFile(FileName: String; Var Ok: Boolean);
  Function  HasEvent(Kind: Char): Boolean;
  Function  Left: LongInt;                   {the events of the script that were not used (S, U, D)}
  Function  Xfer(Upload: Boolean): Boolean;
  Function  OpenSession: Boolean; Virtual;
  Procedure Hangup; Virtual;
  Function  GetCarrier: Boolean; Virtual;
  Function  InEmpty: Boolean; Virtual;
  Function  GetChar: Char; Virtual;
  Function  PeekChar: Char; Virtual;
  Procedure SendChar(Ch: Char); Virtual;
  Function  WaitForChar(Ms: Word): Boolean; Virtual;
  Procedure FlushOut; Virtual;
  Procedure Advance;                         {Internal}
  Procedure Check;                           {Internal}
  End;

Type ReplayPtr = ^ReplayComObj;


Var
  ReplayCur: ReplayPtr;                      {the replay that ReplayXfer works for}


Function ReplayXfer(Upload: Boolean; Arg: String): Boolean;  {a HubXferProc}
Function ReplayMatch(Pattern, Text: AnsiString; Var Partial: Boolean): Boolean;
  {Pattern is what was recorded (the ******** is any text); Partial: Text is the start of something that would match}


Implementation

Uses MKString, MKPlat;

Const
  Stars = '********';


Function ReplayMatch(Pattern, Text: AnsiString; Var Partial: Boolean): Boolean;
  Var
    P, Q: LongInt;
    Seg: AnsiString;

  Begin
  Partial := False;
  ReplayMatch := False;
  If Pos(Stars, Pattern) = 0 Then
    Begin
    If Text = Pattern Then
      ReplayMatch := True
    Else If (Length(Text) < Length(Pattern)) And (Copy(Pattern, 1, Length(Text)) = Text) Then
      Partial := True;
    Exit;
    End;
  {segments between the stars: the first at the start, the last at the end, the others in order}
  Seg := Copy(Pattern, 1, Pos(Stars, Pattern) - 1);
  If Copy(Text, 1, Length(Seg)) <> Seg Then
    Begin
    If (Length(Text) < Length(Seg)) And (Copy(Seg, 1, Length(Text)) = Text) Then
      Partial := True;
    Exit;
    End;
  {the rest after the first stars: the text has to end with the last segment and hold the middle ones in order}
  Delete(Pattern, 1, Length(Seg) + Length(Stars));
  P := Length(Seg) + 1;
  While Pos(Stars, Pattern) > 0 Do
    Begin
    Seg := Copy(Pattern, 1, Pos(Stars, Pattern) - 1);
    Delete(Pattern, 1, Length(Seg) + Length(Stars));
    If Seg <> '' Then
      Begin
      Q := Pos(Seg, Copy(Text, P, Length(Text)));
      If Q = 0 Then
        Begin
        Partial := True;                   {may still come}
        Exit;
        End;
      P := P + Q - 1 + Length(Seg);
      End;
    End;
  {Pattern is now the last segment}
  If Pattern = '' Then
    Begin
    ReplayMatch := True;
    Exit;
    End;
  If (Length(Text) - P + 1 >= Length(Pattern)) And (Copy(Text, Length(Text) - Length(Pattern) + 1, Length(Pattern)) = Pattern) Then
    ReplayMatch := True
  Else
    Partial := True;
  End;


Constructor ReplayComObj.InitFile(FileName: String; Var Ok: Boolean);
  Var
    F: File;
    Buf: AnsiString;
    N, P, E: LongInt;
    L: AnsiString;

  Begin
  Inherited Init;
  NumEv := 0;
  Idx := 1;
  Avail := '';
  AvPos := 1;
  Sent := '';
  Fault := '';
  Hung := False;
  Starved := 0;
  Ok := False;
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  If IoResult <> 0 Then
    Exit;
  N := FileSize(F);
  SetLength(Buf, N);
  If N > 0 Then
    BlockRead(F, Buf[1], N);
  Close(F);
  P := 1;
  While P <= Length(Buf) Do
    Begin
    E := P;
    While (E <= Length(Buf)) And (Buf[E] <> #10) Do
      Inc(E);
    L := Copy(Buf, P, E - P);
    P := E + 1;
    If NumEv >= MaxEvents Then
      Break;
    If Copy(L, 1, 3) = '<< ' Then
      Begin
      Inc(NumEv);
      EvKind[NumEv] := 'R';
      EvText[NumEv] := Copy(L, 4, Length(L));
      End
    Else If Copy(L, 1, 3) = '>> ' Then
      Begin
      Inc(NumEv);
      EvKind[NumEv] := 'S';
      EvText[NumEv] := Copy(L, 4, Length(L));
      End
    Else If (Copy(L, 1, 10) = '-- upload ') And (Copy(L, Length(L) - 4, 5) <> ' done') Then
      Begin
      Inc(NumEv);
      EvKind[NumEv] := 'U';
      EvText[NumEv] := '';
      End
    Else If (Copy(L, 1, 12) = '-- download ') And (Copy(L, Length(L) - 4, 5) <> ' done') Then
      Begin
      Inc(NumEv);
      EvKind[NumEv] := 'D';
      EvText[NumEv] := '';
      End;
    End;
  Ok := NumEv > 0;
  Advance;
  End;


Function ReplayComObj.HasEvent(Kind: Char): Boolean;
  Var
    i: LongInt;

  Begin
  HasEvent := False;
  For i := 1 To NumEv Do
    If EvKind[i] = Kind Then
      HasEvent := True;
  End;


Function ReplayComObj.Left: LongInt;
  Var
    i, N: LongInt;

  Begin
  N := 0;
  For i := Idx To NumEv Do
    If EvKind[i] <> 'R' Then
      Inc(N);
  Left := N;
  End;


Procedure ReplayComObj.Advance;
  {what the hub said before the next thing the script has to do is there to be read}
  Begin
  While (Idx <= NumEv) And (EvKind[Idx] = 'R') Do
    Begin
    Avail := Avail + EvText[Idx] + #13#10;
    Inc(Idx);
    Starved := 0;
    End;
  End;


Procedure ReplayComObj.Check;
  {what the script sent is compared with the next ">>" of the recording}
  Var
    Partial: Boolean;
    T: AnsiString;

  Begin
  While (Sent <> '') And (Fault = '') Do
    Begin
    If (Idx > NumEv) Or (EvKind[Idx] <> 'S') Then
      Begin
      If Idx > NumEv Then
        Fault := 'the script sent "' + Sent + '" but the recording has nothing more'
      Else If EvKind[Idx] = 'U' Then
        Fault := 'the script sent "' + Sent + '" but the recording has an upload here'
      Else If EvKind[Idx] = 'D' Then
        Fault := 'the script sent "' + Sent + '" but the recording has a download here'
      Else
        Fault := 'the script sent "' + Sent + '"';
      Exit;
      End;
    T := EvText[Idx];
    If ReplayMatch(T, Sent, Partial) Then
      Begin
      Sent := '';
      Inc(Idx);
      Starved := 0;
      Advance;
      End
    Else If Partial Then
      Exit
    Else
      Begin
      Fault := 'the script sent "' + Sent + '" where the recording has "' + T + '"';
      Exit;
      End;
    End;
  End;


Function ReplayComObj.Xfer(Upload: Boolean): Boolean;
  Begin
  Xfer := False;
  If Fault <> '' Then
    Exit;
  If (Idx <= NumEv) And (((EvKind[Idx] = 'U') And Upload) Or ((EvKind[Idx] = 'D') And Not Upload)) Then
    Begin
    Inc(Idx);
    Starved := 0;
    Advance;
    Xfer := True;
    End
  Else If Upload Then
    Fault := 'the script uploads a file where the recording does not'
  Else
    Fault := 'the script downloads a file where the recording does not';
  End;


Function ReplayXfer(Upload: Boolean; Arg: String): Boolean;
  Begin
  ReplayXfer := (ReplayCur <> Nil) And ReplayCur^.Xfer(Upload);
  End;


Function ReplayComObj.OpenSession: Boolean;
  Begin
  OpenSession := True;
  End;


Procedure ReplayComObj.Hangup;
  Begin
  Hung := True;
  End;


Function ReplayComObj.GetCarrier: Boolean;
  Begin
  GetCarrier := (Not Hung) And (Fault = '') And (Starved < 300) And ((AvPos <= Length(Avail)) Or (Idx <= NumEv));
  End;


Function ReplayComObj.InEmpty: Boolean;
  Begin
  InEmpty := AvPos > Length(Avail);
  End;


Function ReplayComObj.GetChar: Char;
  Begin
  If AvPos <= Length(Avail) Then
    Begin
    GetChar := Avail[AvPos];
    Inc(AvPos);
    If AvPos > Length(Avail) Then
      Begin
      Avail := '';
      AvPos := 1;
      End;
    End
  Else
    GetChar := #0;
  End;


Function ReplayComObj.PeekChar: Char;
  Begin
  If AvPos <= Length(Avail) Then
    PeekChar := Avail[AvPos]
  Else
    PeekChar := #0;
  End;


Procedure ReplayComObj.SendChar(Ch: Char);
  Begin
  Sent := Sent + Ch;
  End;


Procedure ReplayComObj.FlushOut;
  Begin
  Check;
  End;


Function ReplayComObj.WaitForChar(Ms: Word): Boolean;
  Begin
  Check;
  If AvPos <= Length(Avail) Then
    Begin
    WaitForChar := True;
    Exit;
    End;
  If Ms > 0 Then
    Begin
    MKDelay(5);
    Inc(Starved);                      {nothing to give: a script that keeps waiting is waiting for text that is not here}
    End;
  WaitForChar := False;
  End;


End.
