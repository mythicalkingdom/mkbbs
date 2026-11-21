Unit MKQwkNet;       {QWK network: one pass with a remote QWK system (mk -G<RemoteId>)}

{$I MKB.Def}

{
     strip-ctrla yes     take the Ctrl-A codes (colours and attributes of a Synchronet hub) out of the text of the messages that
                         are posted; a line that began with one stays (default no)

     The messages the pass posts from the hub's packet are written down (RemoteId.imp next to the map file: area and message
     number) and are not put in a reply packet, whatever the last read pointer says: they do not go back to where they came from.
     An entry is kept 60 days (a last read pointer put back by hand within that time is safe; message numbers of a base that is
     packed can change, so old entries are not trusted for longer).

     mk -G<RemoteId> -D   a dry run: says what the reply packet would hold (messages per area, from which number on), whether a
                          reply packet or a packet of the hub is waiting, and changes nothing: no packet, no pointer, no call.
                          Do this before a pass when the pointers were moved by hand.
     mk -G<RemoteId>      exchanges mail with the QWK system RemoteId (its QWK id, as given) without a caller: the
                          messages that are new to it go into the reply packet (REP) for it, the packet that came
                          from it is posted.  The files are moved by something else (a script, a transfer
                          program); mk reads and writes them in two directories.

     The system is a user of this BBS: an ordinary user record named RemoteId (or the name given with "user" in the
     map file) with the QWK Node flag (the user editor).  What this user has chosen for offline mail is what the
     system is subscribed to: its message areas, its packer (ZIP ...), and the limits of messages per packet and per
     area.  The last read pointers of this user say what has been sent; the other side of a gate (Fido mail) keeps
     its own mark, so each side exports what is new to it.

     The map file RemoteId.map (looked for in the directories of the BBS, the name as given) says what the system calls
     its conferences.  Lines of words; ; or # begins a comment:

         inbound  /var/spool/qwk/in      where RemoteId.QWK arrives (default: the directory mk was started in)
         outbound /var/spool/qwk/out     where RemoteId.REP is made (default: the same)
         user     MYKINGDOM              the user record (default: RemoteId)
         conf 12 6                       conference 12 of the system is message area 6 here
         conf 0 1

         hub      bbs.example.com:23     call this hub (Telnet): the reply packet goes up, the packet comes down (without it
                                         the files are moved by something else)
         profile  synchronet             what the hub says and wants: synchronet or mk (MKHubScr), or
         script   MYHUB.scr              a script of your own (MKHubScr syntax; relative to the map file)
         login    LION                   user name at the hub          password  secret
         protocol Z                      Z Zmodem, Y Ymodem, G Ymodem-G, X Xmodem (the key at the hub, too)
         transcript  MYHUB.log           what was said at the hub (default RemoteId.hub.log next to the map file; the
                                         password is not written)

     Directories are written without blanks.  An area without a "conf" line is not in the packet, a conference
     of the packet without one is not posted.

     The pass:
       1. the reply packet: the new messages of the subscribed areas, as RemoteId.REP (a ZIP, with RemoteId.msg: the number
          field of a message is its conference, byte 126 'E' says echomail).  It is not made when there are no
          new messages, nor when the last one is still in the outbound directory (nothing is lost: the last read
          pointers go on only when the packet was made)
       1b. with a "hub": the call.  The script of the profile logs in, sends the reply packet (when there is one: the file
          is deleted when the hub has it), asks for the packet and receives it as RemoteId.QWK in the inbound directory.
          A packet that is still waiting there (it could not be read) stops the call: nothing new is taken
          before it is posted
       2. the packet of the system, RemoteId.QWK in the inbound directory (any case): unpacked, its messages are
          posted (duplicates are skipped: RemoteId.dup next to the map file); the packet is kept as RemoteId.QWK.old
       3. the messages that were just posted must not go back: where the area was all sent before and the new messages
          follow the old ones directly, the last read pointer is moved past them
     Long names and subjects (QWKE) are used in the reply packet and read from the packet.

     The exit code: 0 done, 1 no map file, 2 the user is not there (or is not a QWK node), 3 the reply packet could not be made,
     4 the packet of the system could not be read, 5 the hub could not be reached, 6 the script (login, transfer) failed,
     7 the hub did not accept the reply packet (see reply-error and reply-ok below; the packet stays and goes again next time).

     What the hub says after it got the reply packet can tell that it refused it (Synchronet says so for a sub-board that
     is not there ...): the transcript has the text, and these lines of the map file name what to look for (blank
     separated words are one text, upper or lower case, up to 8 of each):

         reply-error  not found           any of these in the text = refused
         reply-ok     unpacked            when there are any, one of them has to be in the text

     Retrying and failing is the business of whoever starts the pass: mklisten, when an event of the BBS has the action
     "Hub pass" (the id of the hub as its command).  It reads these lines of the map file:

         retries  3                      tries after the first one when the result is 5, 6 or 7 (default 3, 0 = none)
         retry    300                    seconds before the first new try, doubled each time (default 300)
         retry-max 3600                  ... at most this many seconds (default 3600)
         onfail   notify.sh              run when the pass has failed for good (a name without a slash: in the BBS directory);
                                         arguments: the id, the result, the number of tries

     mk itself ignores these lines.

     Nothing is checked when there are none, except with "profile synchronet": it says "Invalid Conference <n>" for a message
     to a conference it does not have (seen on Synchronet 3.19), so that is the default reply-error there.  A refused reply packet is not deleted and the pointers are
     not moved back: nothing new is made until it has gone, so nothing is lost or sent twice.
}


Interface


Var
  QwkNetDry: Boolean;                    {mk -G<id> -D: only say what a pass would send, change nothing}

Function QwkNetPass(RemoteId: String): Integer;


Implementation


Uses MKString, MKFile, MKGlobT, MKCfgAbs, MKDoor, MKOpen, MKMsgAbs,
  MKOffAbs, MKOffQwk, MKQwkImp, MKOffDL, MKOffXfer, MKOfflin,
  MKComAbs, MKComClient, MKHubScr, MKProt, MKVideo, MKPlat,
  Dos;


Var
  Ledger: Array[1..30000] Of Int64;     {the messages that came from the hub: Area * 2^32 + number, sorted}
  NumLedger: LongInt;
  LedgerSkipped: LongInt;
  DryArea: Word;
  ConfArea: Array[0..65535] Of Word;     {conference of the system -> area here (0 = none)}
  AreaConf: Array[1..OffAreas] Of LongInt; {area -> conference (-1 = none)}
  Inbound, Outbound, UserName, MapDir: String;
  HubHost, HubProfile, HubScript, HubLogin, HubPass, HubProto, HubLog: String;
  StripA: Boolean;                       {strip-ctrla: the Ctrl-A codes of the hub's messages are taken out}
  ReplyErr, ReplyOk: Array[1..8] Of String[80];   {what the hub says after the reply packet: refused / accepted}
  NumErr, NumOk: Word;
  HubPort: Word;
  SelIdx: Word;


Function NetConfOf(Area: LongInt): LongInt;
  Begin
  If (Area >= 1) And (Area <= OffAreas) Then
    NetConfOf := AreaConf[Area]
  Else
    NetConfOf := -1;
  End;


Function NetAreaOf(Conf: LongInt): LongInt;
  Begin
  If (Conf >= 0) And (Conf <= 65535) And (ConfArea[Conf] > 0) Then
    NetAreaOf := ConfArea[Conf]
  Else
    NetAreaOf := -1;
  End;


Function Absolute(Dir: String): String;
  {relative to where mk was started}
  Begin
  Dir := StripTrail(Dir, '/');
  If (Dir = '') Then
    Absolute := WithBackSlash(StartUpPath)
  Else If Dir[1] = '/' Then
    Absolute := WithBackSlash(Dir)
  Else
    Absolute := WithBackSlash(WithBackSlash(StartUpPath) + Dir);
  End;


Function LoadMap(Id: String): Boolean;
  Var
    F: Text;
    Line, Key, Rest: String;
    P: Word;
    Conf, Area: LongInt;
    FileName: String;

  Begin
  LoadMap := False;
  FillChar(ConfArea, SizeOf(ConfArea), 0);
  For Area := 1 To OffAreas Do
    AreaConf[Area] := -1;
  Inbound := Absolute('');
  Outbound := Inbound;
  UserName := Id;
  HubHost := '';
  HubPort := 23;
  HubProfile := '';
  HubScript := '';
  HubLogin := '';
  HubPass := '';
  HubProto := 'Z';
  HubLog := '';
  NumErr := 0;
  NumOk := 0;
  StripA := False;
  MapDir := Config^.FindBbsFile(Id + '.map');
  FileName := MapDir + Id + '.map';
  If Not FileExist(FileName) Then
    Exit;
  Assign(F, FileName);
  Reset(F);
  If IoResult <> 0 Then
    Exit;
  While Not Eof(F) Do
    Begin
    ReadLn(F, Line);
    P := Pos(';', Line);
    If P > 0 Then
      Line := Copy(Line, 1, P - 1);
    P := Pos('#', Line);
    If P > 0 Then
      Line := Copy(Line, 1, P - 1);
    Line := StripBoth(Line, ' ');
    If Line <> '' Then
      Begin
      Key := Lower(ExtractWord(Line, 1));
      Rest := StripBoth(Copy(Line, Length(ExtractWord(Line, 1)) + 1, 250), ' ');
      If Key = 'inbound' Then
        Inbound := Absolute(Rest)
      Else If Key = 'outbound' Then
        Outbound := Absolute(Rest)
      Else If Key = 'user' Then
        UserName := Rest
      Else If Key = 'hub' Then
        Begin
        P := Pos(':', Rest);
        If P > 0 Then
          Begin
          HubPort := Str2Long(Copy(Rest, P + 1, 6));
          HubHost := Copy(Rest, 1, P - 1);
          End
        Else
          HubHost := Rest;
        End
      Else If Key = 'profile' Then
        HubProfile := Rest
      Else If Key = 'script' Then
        HubScript := Rest
      Else If Key = 'login' Then
        HubLogin := Rest
      Else If Key = 'password' Then
        HubPass := Rest
      Else If Key = 'protocol' Then
        HubProto := UpCase(Rest[1])
      Else If Key = 'transcript' Then
        HubLog := Rest
      Else If Key = 'strip-ctrla' Then
        StripA := Lower(ExtractWord(Rest, 1)) = 'yes'
      Else If (Key = 'reply-error') And (NumErr < 8) And (Rest <> '') Then
        Begin
        Inc(NumErr);
        ReplyErr[NumErr] := Lower(Rest);
        End
      Else If (Key = 'reply-ok') And (NumOk < 8) And (Rest <> '') Then
        Begin
        Inc(NumOk);
        ReplyOk[NumOk] := Lower(Rest);
        End
      Else If Key = 'conf' Then
        Begin
        Conf := Str2Long(ExtractWord(Rest, 1));
        Area := Str2Long(ExtractWord(Rest, 2));
        If (Conf >= 0) And (Conf <= 65535) And (Area >= 1) And (Area <= OffAreas) Then
          Begin
          If ConfArea[Conf] = 0 Then
            ConfArea[Conf] := Area;
          If AreaConf[Area] < 0 Then
            AreaConf[Area] := Conf;
          End;
        End;
      End;
    End;
  Close(F);
  If IoResult <> 0 Then;
  If (Lower(HubProfile) = 'synchronet') And (NumErr = 0) And (NumOk = 0) Then
    Begin                              {what a Synchronet hub says to a message for a conference it does not have: "Invalid Conference 9999"}
    NumErr := 1;
    ReplyErr[1] := 'invalid conference';
    End;
  LoadMap := True;
  End;


Function NetSel(N: Word; Var Area: Word; Var Mode: Byte): Boolean;
  {the areas the system has chosen (and the sysop forces), those it has a conference number for}
  Begin
  NetSel := False;
  If N = 1 Then
    SelIdx := 0;
  While SelIdx < Config^.GetMaxMsgAreas Do
    Begin
    Inc(SelIdx);
    If (SelIdx <= OffAreas) And (AreaConf[SelIdx] >= 0) And
       ((User.GetUserOffline(SelIdx) And Config^.GetMsgAllowOffline(SelIdx)) Or
        Config^.GetMsgForceOffline(SelIdx)) Then
      Begin
      Area := SelIdx;
      Mode := omAll;
      NetSel := True;
      Exit;
      End;
    End;
  End;


Procedure NetEv(What: Word; Area: Word; N: LongInt);
  Begin
  If What = oeAreaEnd Then
    If N > 0 Then
      User.DisplayStrLn(Config^.GetMsgName(Area) + ': ' + Long2Str(N));
  End;


Function PackerNum: Word;
  {the packer of the system, else the first one there is}
  Var
    i: Word;

  Begin
  PackerNum := GetUserPackerNum;
  If GetUserPackerNum = 0 Then
    Begin
    For i := 10 Downto 1 Do
      If Config^.GetPackAvail(i) And (Length(StripBoth(Config^.GetPackCmdLine(i), ' ')) > 0) Then
        PackerNum := i;
    End;
  End;


{ ---- the messages that came from the hub are not sent back }

Procedure LedgerSort(Lo, Hi: LongInt);
  Var
    I, J: LongInt;
    Pv, T: Int64;

  Begin
  I := Lo;
  J := Hi;
  Pv := Ledger[(Lo + Hi) Div 2];
  Repeat
    While Ledger[I] < Pv Do Inc(I);
    While Ledger[J] > Pv Do Dec(J);
    If I <= J Then
      Begin
      T := Ledger[I];
      Ledger[I] := Ledger[J];
      Ledger[J] := T;
      Inc(I);
      Dec(J);
      End;
  Until I > J;
  If Lo < J Then LedgerSort(Lo, J);
  If I < Hi Then LedgerSort(I, Hi);
  End;


Function LedgerKey(Area: Word; Num: LongInt): Int64;
  Begin
  LedgerKey := Int64(Area) * 4294967296 + Num;
  End;


Function DayCount(Ymd: LongInt): LongInt;
  {days since 0000-03-01 of a date as YYYYMMDD (enough to subtract two of them)}
  Var
    Y, M, D: LongInt;

  Begin
  Y := Ymd Div 10000;
  M := (Ymd Div 100) Mod 100;
  D := Ymd Mod 100;
  If M <= 2 Then
    Begin
    Dec(Y);
    Inc(M, 12);
    End;
  DayCount := 365 * Y + Y Div 4 - Y Div 100 + Y Div 400 + (153 * (M - 3) + 2) Div 5 + D;
  End;


Procedure LoadLedger(Id: String);
  {Id.imp next to the map file: a line "area number day" for every message posted from the packets of the hub (written by the
   import, MKOffQwk).  Entries older than 60 days are dropped from the file; the newest 30000 are used.}
  Var
    F, T: Text;
    Line, Name: String;
    A, N, Day, Today: LongInt;
    P, Q: Word;
    Y, M, D, W: Word;
    Dropped: Boolean;

  Begin
  NumLedger := 0;
  LedgerSkipped := 0;
  Name := MapDir + Id + '.imp';
  Assign(F, Name);
  Reset(F);
  If IoResult <> 0 Then
    Exit;
  Assign(T, Name + '.new');
  Rewrite(T);
  Dropped := False;
  Dos.GetDate(Y, M, D, W);
  Today := DayCount(Y * 10000 + M * 100 + D);
  While Not Eof(F) Do
    Begin
    ReadLn(F, Line);
    P := Pos(' ', Line);
    If P > 0 Then
      Begin
      A := Str2Long(Copy(Line, 1, P - 1));
      Q := Pos(' ', Copy(Line, P + 1, 40));
      If Q > 0 Then
        Begin
        N := Str2Long(Copy(Line, P + 1, Q - 1));
        Day := DayCount(Str2Long(Copy(Line, P + Q + 1, 12)));
        End
      Else
        Begin
        N := Str2Long(Copy(Line, P + 1, 12));
        Day := Today;
        End;
      If (A >= 1) And (A <= OffAreas) And (N > 0) And (Today - Day <= 60) Then
        Begin
        WriteLn(T, Line);
        If NumLedger >= 30000 Then
          Begin
          Move(Ledger[2], Ledger[1], (NumLedger - 1) * SizeOf(Int64));     {the oldest goes}
          Dec(NumLedger);
          End;
        Inc(NumLedger);
        Ledger[NumLedger] := LedgerKey(A, N);
        End
      Else
        Dropped := True;
      End;
    End;
  Close(F);
  Close(T);
  If IoResult <> 0 Then;
  If Dropped Then
    Begin
    Erase(F);
    Rename(T, Name);
    End
  Else
    Erase(T);
  If IoResult <> 0 Then;
  If NumLedger > 1 Then
    LedgerSort(1, NumLedger);
  End;


Function LedgerSkip(Area: Word; MsgNum: LongInt): Boolean;
  Var
    Lo, Hi, Mid: LongInt;
    K: Int64;

  Begin
  LedgerSkip := False;
  K := LedgerKey(Area, MsgNum);
  Lo := 1;
  Hi := NumLedger;
  While Lo <= Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If Ledger[Mid] = K Then
      Begin
      LedgerSkip := True;
      Inc(LedgerSkipped);
      Exit;
      End
    Else If Ledger[Mid] < K Then
      Lo := Mid + 1
    Else
      Hi := Mid - 1;
    End;
  End;


Function DoReply(Id: String): Boolean;
  {the reply packet; False when it could not be made}
  Var
    Offline: QwkOffPtr;
    WorkPath, ArcName: String;
    P: OffDLParams;
    R: OffDLResult;
    Cont: Boolean;
    PackNum: Word;

  Begin
  DoReply := True;
  Offline := New(QwkOffPtr, Init);
  Offline^.SetLink(Id, NetConfOf, NetAreaOf);
  Offline^.SetQwke(True);
  ArcName := Offline^.GetArchiveName(0);
  If OffFindNoCase(Outbound, ArcName) <> '' Then
    Begin
    User.DisplayStrLn(ArcName + ' is still in the outbound directory: no new reply packet');
    Dispose(Offline, Done);
    Exit;
    End;
  WorkPath := CreateTempDir(Config^.GetTempPath);
  Cont := Length(WorkPath) > 0;
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Cont := Offline^.StartPacket = 0;
    End;
  If Cont Then
    Begin
    P.Sel := NetSel;
    P.Ev := NetEv;
    P.MaxMsgs := User.GetUserOffMax;
    If (P.MaxMsgs = 0) Or (Config^.GetOffMax < P.MaxMsgs) Then
      P.MaxMsgs := Config^.GetOffMax;
    P.AreaMax := User.GetUserOffConfMax;
    If (P.AreaMax = 0) Or (Config^.GetOffConfMax < P.AreaMax) Then
      P.AreaMax := Config^.GetOffConfMax;
    P.OwnMsgs := True;
    P.CheckUser := False;
    LoadLedger(Id);
    OffSkip := LedgerSkip;
    Cont := OffExport(Offline, P, R);
    OffSkip := Nil;
    If LedgerSkipped > 0 Then
      User.DisplayStrLn(Long2Str(LedgerSkipped) + ' message(s) that came from the hub are not sent back');
    If Offline^.ClosePacket <> 0 Then
      Cont := False;
    End;
  If Cont Then
    Begin
    If R.NumMsgs = 0 Then
      User.DisplayStrLn('No new messages for ' + Id)
    Else
      Begin
      PackNum := PackerNum;
      Cont := PackNum > 0;
      If Cont Then
        Cont := OffRun(Config^.GetPackCmdLine(PackNum), StartUpPath, WorkPath,
          Outbound + ArcName + ' *.*');
      If Cont Then
        Begin
        User.DisplayStrLn(Long2Str(R.NumMsgs) + ' message(s) in ' + ArcName);
        OffCommitLR(R);                {sent: the last read goes on}
        End;
      End;
    End;
  If Not Cont Then
    Begin
    User.DisplayStrLn('The reply packet could not be made');
    DoReply := False;
    End;
  Dispose(Offline, Done);
  ChDir(StripTrail(StartUpPath, '/'));
  If IoResult <> 0 Then;
  If Length(WorkPath) > 0 Then
    Begin
    CleanDir(WithBackSlash(WorkPath));
    RmDir(StripTrail(WorkPath, '/'));
    If IoResult <> 0 Then;
    End;
  End;


{ ---- a dry run: what would the reply packet hold (it is written to StdErr: the standard output of mk is the screen of the caller) }

Procedure DryEv(What: Word; Area: Word; N: LongInt);
  Begin
  If What = oeArea Then
    DryArea := Area
  Else If What = oeAreaEnd Then
    If N > 0 Then
      WriteLn(StdErr, '  area ', Area, ' ', Config^.GetMsgName(Area), ' (conference ', AreaConf[Area], '): ', N,
        ' message(s) after number ', OffUserLR(Area));
  End;


Function DryRun(Id: String): Integer;
  {Does what DoReply does up to the packet (the messages are looked at, nothing is written but a work directory that is
   removed again) and does not move any last read pointer, call the hub or touch a file of the BBS.  mk -G<id> -D}
  Var
    Offline: QwkOffPtr;
    WorkPath, ArcName, Found: String;
    P: OffDLParams;
    R: OffDLResult;
    Cont: Boolean;
    i, Subscribed: Word;

  Begin
  DryRun := 0;
  WriteLn(StdErr, 'Dry run of the pass with ', Id, ': nothing is sent, called, moved or written.');
  WriteLn(StdErr, 'User ', UserName, '; reply packets would go to ', Outbound, ', packets from the hub come to ', Inbound);
  If HubHost <> '' Then
    WriteLn(StdErr, 'Hub ', HubHost, ':', HubPort, ', profile ', HubProfile, ' ', HubScript)
  Else
    WriteLn(StdErr, 'No hub: the files are moved by something else');
  Offline := New(QwkOffPtr, Init);
  Offline^.SetLink(Id, NetConfOf, NetAreaOf);
  Offline^.SetQwke(True);
  ArcName := Offline^.GetArchiveName(0);
  Found := OffFindNoCase(Outbound, ArcName);
  If Found <> '' Then
    Begin
    WriteLn(StdErr, ArcName, ' is waiting in the outbound directory (', Found, '): it goes first, no new reply packet is made until it has gone.');
    Dispose(Offline, Done);
    Exit;
    End;
  Found := OffFindNoCase(Inbound, Id + '.qwk');
  If Found <> '' Then
    WriteLn(StdErr, 'A packet from the hub is waiting in the inbound directory (', Found, '): the pass would post it before any call.');
  Subscribed := 0;
  For i := 1 To OffAreas Do
    If (AreaConf[i] >= 0) And ((User.GetUserOffline(i) And Config^.GetMsgAllowOffline(i)) Or Config^.GetMsgForceOffline(i)) Then
      Inc(Subscribed);
  WriteLn(StdErr, Subscribed, ' area(s) with a conference number are chosen by the user (and so looked at):');
  WorkPath := CreateTempDir(Config^.GetTempPath);
  Cont := Length(WorkPath) > 0;
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Cont := Offline^.StartPacket = 0;
    End;
  If Cont Then
    Begin
    P.Sel := NetSel;
    P.Ev := DryEv;
    P.MaxMsgs := User.GetUserOffMax;
    If (P.MaxMsgs = 0) Or (Config^.GetOffMax < P.MaxMsgs) Then
      P.MaxMsgs := Config^.GetOffMax;
    P.AreaMax := User.GetUserOffConfMax;
    If (P.AreaMax = 0) Or (Config^.GetOffConfMax < P.AreaMax) Then
      P.AreaMax := Config^.GetOffConfMax;
    P.OwnMsgs := True;
    P.CheckUser := False;
    LoadLedger(Id);
    OffSkip := LedgerSkip;
    Cont := OffExport(Offline, P, R);
    OffSkip := Nil;
    Offline^.ClosePacket;
    End;
  If Not Cont Then
    Begin
    WriteLn(StdErr, 'The messages could not be looked at.');
    DryRun := 3;
    End
  Else If R.NumMsgs = 0 Then
    Begin
    If LedgerSkipped > 0 Then
      WriteLn(StdErr, LedgerSkipped, ' message(s) that came from the hub are not sent back.');
    WriteLn(StdErr, 'Nothing new: no reply packet would be made.');
    End
  Else
    Begin
    If LedgerSkipped > 0 Then
      WriteLn(StdErr, LedgerSkipped, ' message(s) that came from the hub are not sent back.');
    WriteLn(StdErr, R.NumMsgs, ' message(s) would go up in ', ArcName, '.  Last read pointers are NOT moved by this run.');
    End;
  Dispose(Offline, Done);
  ChDir(StripTrail(StartUpPath, '/'));
  If IoResult <> 0 Then;
  If Length(WorkPath) > 0 Then
    Begin
    CleanDir(WithBackSlash(WorkPath));
    RmDir(StripTrail(WorkPath, '/'));
    If IoResult <> 0 Then;
    End;
  End;


{ ---- the call to the hub }

Var
  HubRcvDir: String;
  HubSent: Boolean;                      {the reply packet went up}


Procedure SetHubProt(Var P: ProtObj);
  Begin
  Case HubProto[1] Of
    'Y': P.SetYmodem;
    'G': P.SetYModemG;
    'X': P.SetXmodem;
    Else P.SetZmodem;
    End;
  End;


Function HubXfer(Upload: Boolean; Arg: ShortString): Boolean;
  Var
    P: ProtObj;
    Cur: String;
    Slash: Word;

  Begin
  P.Init;
  SetHubProt(P);
  If Upload Then
    Begin
    {the transfer routines keep short file names: go to the directory of the file}
    GetDir(0, Cur);
    Slash := PosLastChar('/', Arg);
    If Slash > 0 Then
      ChDir(Copy(Arg, 1, Slash - 1));
    P.AddSendFile(Copy(Arg, Slash + 1, 255));
    P.Send;
    ChDir(Cur);
    If IoResult <> 0 Then;
    HubXfer := (P.PI^.Error = 0) And (P.GetFileStatus(1) = 1);
    If P.GetFileStatus(1) = 1 Then
      HubSent := True;
    End
  Else
    Begin
    P.SetRecvName('download.dat');
    HubXfer := P.Recv(HubRcvDir) And (P.PI^.NumFiles > 0);
    End;
  P.Done;
  End;


Function LoadHubScript(Var Text: AnsiString): Boolean;
  {the script of the map file, or the profile}
  Var
    F: Text;
    Line: String;

  Begin
  LoadHubScript := False;
  Text := '';
  If HubScript <> '' Then
    Begin
    Line := HubScript;
    If (Line[1] <> '/') Then
      Line := MapDir + Line;
    Assign(F, Line);
    Reset(F);
    If IoResult <> 0 Then
      Exit;
    While Not Eof(F) Do
      Begin
      ReadLn(F, Line);
      Text := Text + Line + #10;
      End;
    Close(F);
    LoadHubScript := True;
    End
  Else
    Begin
    Text := MKHubScr.HubProfile(HubProfile);
    LoadHubScript := Text <> '';
    End;
  End;


Function ReplyRefused(Heard: String; Var Why: String): Boolean;
  {The hub said something after it got the reply packet: did it refuse it?  "reply-error" texts of the map file (any one seen
   in what the hub said means it did) and "reply-ok" texts (when there are any, one of them has to be seen)}
  Var
    L: String;
    i: Word;
    Seen: Boolean;

  Begin
  ReplyRefused := False;
  L := Lower(Heard);
  For i := 1 To NumErr Do
    If Pos(ReplyErr[i], L) > 0 Then
      Begin
      Why := 'it said "' + ReplyErr[i] + '"';
      ReplyRefused := True;
      Exit;
      End;
  If NumOk > 0 Then
    Begin
    Seen := False;
    For i := 1 To NumOk Do
      If Pos(ReplyOk[i], L) > 0 Then
        Seen := True;
    If Not Seen Then
      Begin
      Why := 'it did not say "' + ReplyOk[1] + '"' + Copy(' (or another text of reply-ok)', 1, 30 * Ord(NumOk > 1));
      ReplyRefused := True;
      End;
    End;
  End;


Function DoHub(Id: String): Integer;
  {0 done, 5 not reached, 6 the script failed, 7 the hub did not accept the reply packet}
  Var
    S, OldSess: AbsComPtr;
    Err: ShortString;
    H: HubScriptObj;
    Text: AnsiString;
    Rep, Got, Dest: String;
    FI: FindObj;
    Ok: Boolean;
    OldPort: Word;
    OldRate: LongInt;
    F: File;
    Refused: Boolean;
    Why: String;

  Begin
  DoHub := 0;
  Refused := False;
  If OffFindNoCase(Inbound, Id + '.qwk') <> '' Then
    Begin
    User.DisplayStrLn(Id + '.qwk is still in the inbound directory: no call before it is posted');
    Exit;
    End;
  If Not LoadHubScript(Text) Then
    Begin
    User.DisplayStrLn('No script for the hub: "profile" or "script" in ' + Id + '.map');
    DoHub := 6;
    Exit;
  End;
  HubRcvDir := CreateTempDir(Config^.GetTempPath);
  If HubRcvDir = '' Then
    Begin
    DoHub := 6;
    Exit;
    End;
  Rep := OffFindNoCase(Outbound, Id + '.rep');
  S := ConnectTcp(HubHost, HubPort, 20000, True, Err);
  If S = Nil Then
    Begin
    User.DisplayStrLn('Hub ' + HubHost + ': ' + Err);
    DoHub := 5;
    End
  Else
    Begin
    User.DisplayStrLn('Connected to ' + HubHost + ':' + Long2Str(HubPort));
    OldSess := ComSession;
    OldPort := CurrentPort;
    OldRate := CurrentRate;
    ComSession := S;
    CurrentPort := 1;
    CurrentRate := 38400;
    ProtQuiet := True;
    ProtKeepInput := True;                {we are the caller: what follows a transfer is the hub's prompt}
    HubSent := False;
    H.Init(S);
    H.SetVar('login', HubLogin);
    H.SetVar('password', HubPass);
    H.SetVar('protocol', HubProto);
    H.SetVar('id', Id);
    If Rep <> '' Then
      Begin
      {the hub names the file it wants: <QWK id>.REP (a QWK system on Linux compares the case)}
      If CopyFile(Rep, WithBackSlash(HubRcvDir) + Id + '.REP') Then
        Begin
        H.SetVar('rep', WithBackSlash(HubRcvDir) + Id + '.REP');
        H.SetVar('have_rep', '1');
        End;
      End;
    If HubLog = '' Then
      HubLog := MapDir + Id + '.hub.log'
    Else If HubLog[1] <> '/' Then
      HubLog := MapDir + HubLog;
    H.SetTranscript(HubLog);
    H.SetXfer(HubXfer);
    Ok := H.Load(Text) And H.Run;
    If Not Ok Then
      User.DisplayStrLn('The call to the hub failed: ' + H.ErrText);
    If HubSent And (Rep <> '') And ((NumErr > 0) Or (NumOk > 0)) Then
      If ReplyRefused(H.Heard, Why) Then
        Begin
        Refused := True;
        HubSent := False;                     {the reply packet stays: the next pass sends it again}
        User.DisplayStrLn('The hub did not accept the reply packet: ' + Why + '; it stays in the outbound directory');
        End;
    H.Done;
    S^.Hangup;
    Dispose(S, Done);
    ProtKeepInput := False;
    ComSession := OldSess;
    CurrentPort := OldPort;
    CurrentRate := OldRate;
    If HubSent And (Rep <> '') Then
      Begin
      Assign(F, Rep);
      Erase(F);
      If IoResult <> 0 Then;
      User.DisplayStrLn('The reply packet was sent');
      End;
    { the packet that came: RemoteId.qwk in the inbound directory }
    Got := '';
    FI.Init;
    FI.FFirst(WithBackSlash(HubRcvDir) + '*');
    While FI.Found And (Got = '') Do
      Begin
      If Lower(Copy(FI.GetName, Length(FI.GetName) - 3, 4)) = '.qwk' Then
        Got := FI.GetFullPath;
      FI.FNext;
      End;
    FI.Done;
    If Got <> '' Then
      Begin
      Dest := Inbound + Id + '.qwk';
      If CopyFile(Got, Dest) Then
        User.DisplayStrLn('Packet received: ' + Id + '.qwk')
      Else
        Ok := False;
      End;
    If Not Ok Then
      DoHub := 6
    Else If Refused Then
      DoHub := 7;
    End;
  CleanDir(WithBackSlash(HubRcvDir));
  RmDir(StripTrail(HubRcvDir, '/'));
  If IoResult <> 0 Then;
  End;


Function DoPacket(Id: String): Boolean;
  {the packet of the system; False when it is there and could not be read}
  Var
    Offline: QwkOffPtr;
    WorkPath, Src: String;
    Cmds: OffCmdList;
    NumCmds, k, i, N: Word;
    ImpO: OffImportOpts;
    Cont: Boolean;
    A: Word;
    Pending, First, Last: LongInt;
    Old: File;

  Begin
  DoPacket := True;
  Src := OffFindNoCase(Inbound, Id + '.qwk');
  If Src = '' Then
    Begin
    User.DisplayStrLn('No packet from ' + Id);
    Exit;
    End;
  WorkPath := CreateTempDir(Config^.GetTempPath);
  Cont := (Length(WorkPath) > 0) And CopyFile(Src, WithBackSlash(WorkPath) + 'upload.1');
  Offline := New(QwkOffPtr, Init);
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Offline^.SetLink(Id, NetConfOf, NetAreaOf);
    NumCmds := 0;
    k := PackerNum;
    If k > 0 Then
      Begin
      Inc(NumCmds);
      Cmds[NumCmds] := Config^.GetUnPackCmdLine(k);
      End;
    For i := 1 To 10 Do
      If (i <> k) And Config^.GetPackAvail(i) And (NumCmds < 11) Then
        Begin
        Inc(NumCmds);
        Cmds[NumCmds] := Config^.GetUnPackCmdLine(i);
        End;
    Cont := OffUnpackReply(Offline, WorkPath, StartUpPath, Cmds, NumCmds);
    End;
  If Cont Then
    Begin
    ImpO.BadArea := 0;
    ImpO.ForceName := False;
    ImpO.ReDate := False;
    ImpO.DupeFile := MapDir + Id + '.dup';
    Offline^.SetImportOpts(ImpO);
    QwkImportLedger := MapDir + Id + '.imp';
    QwkStripCtrlA := StripA;
    Offline^.ImportPacket;
    QwkImportLedger := '';
    QwkStripCtrlA := False;
    User.DisplayStrLn(Long2Str(Offline^.GetImported) + ' message(s) posted from ' + Id);
    {the messages just posted are not for the system: its last read goes past them where it can (nothing of
     the area was waiting to be sent, and the new messages follow each other)}
    For A := 1 To Config^.GetMaxMsgAreas Do
      If A <= OffAreas Then
        Begin
        N := Offline^.LinkImported(A, Pending, First, Last);
        If N > 0 Then
          Begin
          If (Pending = 0) And (Last - First + 1 = N) Then
            OffSetUserLR(A, Last)
          Else
            User.DisplayStrLn(Config^.GetMsgName(A) + ': other messages were waiting or came in meanwhile, the ones from the system may go back');
          End;
        End;
    {kept for once}
    Assign(Old, Src + '.old');
    Erase(Old);
    If IoResult <> 0 Then;
    Assign(Old, Src);
    Rename(Old, Src + '.old');
    If IoResult <> 0 Then;
    End
  Else
    Begin
    User.DisplayStrLn('The packet from ' + Id + ' could not be read');
    DoPacket := False;
    End;
  Dispose(Offline, Done);
  ChDir(StripTrail(StartUpPath, '/'));
  If IoResult <> 0 Then;
  If Length(WorkPath) > 0 Then
    Begin
    CleanDir(WithBackSlash(WorkPath));
    RmDir(StripTrail(WorkPath, '/'));
    If IoResult <> 0 Then;
    End;
  End;


Function QwkNetPass(RemoteId: String): Integer;
  Var
    Res, N: Integer;

  Begin
  Res := 0;
  If Not LoadMap(RemoteId) Then
    Begin
    User.DisplayStrLn('No map file ' + RemoteId + '.map');
    QwkNetPass := 1;
    Exit;
    End;
  User.GetUserPos(UserName);
  If User.UserFound Then
    User.ReadUser;
  If (Not User.UserFound) Or (Not User.GetUserQwkNode) Then
    Begin
    User.DisplayStrLn('No user ' + UserName + ' with the QWK Node flag');
    QwkNetPass := 2;
    Exit;
    End;
  If QwkNetDry Then
    Begin
    QwkNetPass := DryRun(RemoteId);          {nothing else: no WriteUser either}
    Exit;
    End;
  If Not DoReply(RemoteId) Then
    Res := 3;
  If HubHost <> '' Then
    Begin
    N := DoHub(RemoteId);
    If N <> 0 Then
      Res := N;
    End;
  If Not DoPacket(RemoteId) Then
    Res := 4;
  User.WriteUser;
  QwkNetPass := Res;
  End;


End.
