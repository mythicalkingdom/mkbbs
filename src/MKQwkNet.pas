Unit MKQwkNet;       {QWK network: one pass with a remote QWK system (mk -G<RemoteId>)}

{$I MKB.Def}

{
     strip-ctrla yes     take the Ctrl-A codes (colours and attributes of a Synchronet hub) out of the text of the messages that
                         are posted; a line that began with one stays (default no)

     Control commands for the hub (the node side of the control messages ADD, DROP ... of Synchronet's QWK networking, which the MK
     hub takes as well):  one command a line in RemoteId.ctl next to the map file, or  mk -G<id> -X"ADD 4029 -50"  (up to 10 -X, queued
     and sent by that pass).  Lines beginning with ; or # are comments.  The commands are put in the reply packet as messages to SBBS
     (the name both Synchronet and MK answer to; "control-to NAME" in the map file changes it), the command as the subject, in the conference
     that the command is about:
         ADD <conf> [YOURS] [ptr | -msgs | mm/dd/yy]     subscribe to a conference (optionally from a message, the last N, or a date)
         DROP <conf>                                      unsubscribe
         YOURS <conf> [ptr | -msgs | mm/dd/yy]            only the mail addressed to us
         RESET <conf> [..]   SUBPTR <conf> [..]           set the pointer of a conference
         RESETALL [..]   ALLPTR [..]                      set the pointers of all conferences
         CTRL-A KEEP|EXPAND|STRIP   CONTROL ON|OFF   TZ ON|OFF   VIA ON|OFF   MSGID ON|OFF   NDX ON|OFF   OWN ON|OFF
         MAIL [ALL|ON|OFF]   DELMAIL ON|OFF   FILES [ON|OFF|mm/dd/yy]   ATTACH ON|OFF   FREQ <filename>
     The commands that are not about one conference are sent in the first conference of the map file.  They go up with the next reply
     packet (one is made even when no message is new) and are taken out of the file when the hub has the packet; a refused packet
     (exit 7) keeps them.  Exit code 8: a command was not valid (it is not sent; the others are).

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
     7 the hub did not accept the reply packet (see reply-error and reply-ok below; the packet stays and goes again next time),
     8 a control command was not valid (see the control commands below; the others went).

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
  QwkNetCmds: Array[1..10] Of String[100];   {mk -G<id> -X"ADD 4029 -50": control commands to queue for the hub (up to 10)}
  QwkNetNumCmds: Word;
  QwkNetCtlBad: Boolean;                 {a control command was not valid (exit code 8)}
  QwkNetDry: Boolean;                    {mk -G<id> -D: only say what a pass would send, change nothing}
  QwkNetConfList: Boolean;               {mk -G<id> -I: list the conferences of the packet of the hub and what they are here}
  QwkNetConfMatch: Boolean;              {mk -G<id> -J: suggest conf lines by the names (with -W: add them to the map file)}
  QwkNetConfWrite: Boolean;
  QwkNetTalk: Boolean;                   {mk -G<id> -K: talk to the hub by hand and record the call as a transcript}
  QwkNetReplay: String;                  {mk -G<id> -F<transcript>: run the profile against a recording, no call}

Function QwkNetPass(RemoteId: String): Integer;
Procedure QwkNetProfiles(RemoteId, Name: String);   {mk -G -P: list the profiles found; mk -G -P<name>: show one}


Implementation


Uses BaseUnix, termio, MKString, MKFile, MKGlobT, MKCfgAbs, MKDoor, MKOpen, MKMsgAbs,
  MKOffAbs, MKOffQwk, MKQwkImp, MKOffDL, MKOffXfer, MKOfflin,
  MKComAbs, MKComClient, MKFtp, MKHubScr, MKHubExec, MKHubReplay, MKHubTalk, MKProt, MKVideo, MKPlat,
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
  CtlTo: String[20];                     {control-to: whom the control messages are for (default SBBS)}
  StripA: Boolean;                       {strip-ctrla: the Ctrl-A codes of the hub's messages are taken out}
  ReplyErr, ReplyOk: Array[1..8] Of String[80];   {what the hub says after the reply packet: refused / accepted}
  NumErr, NumOk: Word;
  HubPort: Word;
  HubExec: Boolean;                      {transport exec: programs move the files (get / put) instead of a Telnet call}
  HubGet, HubPut: String;
  HubFtp: Byte;                          {transport ftp (1) or ftps (2): the files move by FTP}
  HubFtpDel, HubTlsVerify, HubPortGiven: Boolean;
  HubTlsCa: String;
  HubFtpSecs: LongInt;
  HubNothing: LongInt;                   {the exit status of get that means "nothing new" (default 3)}
  HubExecSecs: LongInt;                  {exec-timeout}
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
  HubExec := False;
  HubFtp := 0;
  HubFtpDel := False;
  HubTlsVerify := True;
  HubTlsCa := '';
  HubFtpSecs := 60;
  HubPortGiven := False;
  HubGet := '';
  HubPut := '';
  HubNothing := 3;
  HubExecSecs := 600;
  NumErr := 0;
  NumOk := 0;
  StripA := False;
  CtlTo := 'SBBS';
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
          HubPortGiven := True;
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
      Else If Key = 'transport' Then
        Begin
        HubExec := Lower(ExtractWord(Rest, 1)) = 'exec';
        HubFtp := Ord(Lower(ExtractWord(Rest, 1)) = 'ftp') + 2 * Ord(Lower(ExtractWord(Rest, 1)) = 'ftps');
        End
      Else If Key = 'ftp-delete' Then
        HubFtpDel := Lower(ExtractWord(Rest, 1)) = 'yes'
      Else If Key = 'tls-verify' Then
        HubTlsVerify := Lower(ExtractWord(Rest, 1)) <> 'no'
      Else If Key = 'tls-ca' Then
        HubTlsCa := Rest
      Else If Key = 'ftp-timeout' Then
        Begin
        HubFtpSecs := Str2Long(ExtractWord(Rest, 1));
        If HubFtpSecs < 5 Then
          HubFtpSecs := 60;
        End
      Else If Key = 'get' Then
        HubGet := Rest
      Else If Key = 'put' Then
        HubPut := Rest
      Else If Key = 'nothing' Then
        HubNothing := Str2Long(ExtractWord(Rest, 1))
      Else If Key = 'exec-timeout' Then
        Begin
        HubExecSecs := Str2Long(ExtractWord(Rest, 1));
        If HubExecSecs < 1 Then
          HubExecSecs := 600;
        End
      Else If (Key = 'control-to') And (Rest <> '') Then
        CtlTo := Copy(Rest, 1, 20)
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
  If (HubFtp > 0) And Not HubPortGiven Then
    HubPort := 21;
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


{ ---- control messages for the hub (RemoteId.ctl) }

Function CtlFile(Id: String): String;
  Begin
  CtlFile := MapDir + Id + '.ctl';
  End;


Function FirstConf: LongInt;
  {the conference a command that is not about one is sent in: the first one of the map file (a hub wants a conference it sends)}
  Var
    C: LongInt;

  Begin
  FirstConf := 0;
  For C := 0 To 65535 Do
    If ConfArea[C] <> 0 Then
      Begin
      FirstConf := C;
      Exit;
      End;
  End;


Function AllDigits(Const S: String): Boolean;
  Var
    i: Word;

  Begin
  AllDigits := Length(S) > 0;
  For i := 1 To Length(S) Do
    If (S[i] < '0') Or (S[i] > '9') Then
      AllDigits := False;
  End;


Function CtlParse(Line: String; Var Conf: LongInt; Var Subj, Err: String): Boolean;
  {One command: the conference of the message and the subject.  False with Err = '' for a blank line or a comment, with a text
   for a command that is not valid}
  Const
    ConfCmds = ' ADD DROP YOURS RESET SUBPTR ';
    GlobCmds = ' RESETALL ALLPTR FREQ FILES ATTACH OWN MAIL DELMAIL CTRL-A NDX CONTROL VIA TZ MSGID ';

  Var
    Cmd, Rest, First: String;

  Begin
  CtlParse := False;
  Err := '';
  Line := StripBoth(Line, ' ');
  If (Line = '') Or (Line[1] = ';') Or (Line[1] = '#') Then
    Exit;
  Cmd := Upper(ExtractWord(Line, 1));
  Rest := StripBoth(Copy(Line, Length(ExtractWord(Line, 1)) + 1, 200), ' ');
  If Pos(' ' + Cmd + ' ', ConfCmds) > 0 Then
    Begin
    First := ExtractWord(Rest, 1);
    If (Not AllDigits(First)) Or (Length(First) > 5) Or (Str2Long(First) > 65535) Then
      Begin
      Err := Cmd + ' needs the number of the conference (as the hub numbers it) first';
      Exit;
      End;
    Conf := Str2Long(First);
    Rest := StripBoth(Copy(Rest, Length(First) + 1, 200), ' ');
    If Cmd = 'DROP' Then
      Rest := First;                   {DROP <conf>: the number is the argument, as the hub reads it}
    End
  Else If Pos(' ' + Cmd + ' ', GlobCmds) > 0 Then
    Conf := FirstConf
  Else
    Begin
    Err := Cmd + ' is not a control command (ADD DROP YOURS RESET SUBPTR RESETALL ALLPTR FREQ FILES ATTACH OWN MAIL DELMAIL CTRL-A NDX CONTROL VIA TZ MSGID)';
    Exit;
    End;
  Subj := Cmd;
  If Rest <> '' Then
    Subj := Subj + ' ' + Rest;
  CtlParse := True;
  End;


Function QueueCtl(Id, Line: String; Var Err: String): Boolean;
  {mk -G<id> -X"...": checked and added to RemoteId.ctl}
  Var
    Conf: LongInt;
    Subj: String;
    F: Text;

  Begin
  QueueCtl := False;
  If Not CtlParse(Line, Conf, Subj, Err) Then
    Begin
    If Err = '' Then
      Err := 'nothing to send';
    Exit;
    End;
  Assign(F, CtlFile(Id));
  If FileExist(CtlFile(Id)) Then
    Append(F)
  Else
    Rewrite(F);
  If IoResult <> 0 Then
    Begin
    Err := 'cannot write ' + CtlFile(Id);
    Exit;
    End;
  WriteLn(F, StripBoth(Line, ' '));
  Close(F);
  If IoResult <> 0 Then;
  QueueCtl := True;
  End;


Function AddControls(Offline: QwkOffPtr; Id: String; Var Bad: Word): Word;
  {the commands of RemoteId.ctl go in the reply packet as messages (to SBBS, the command as the subject); how many}
  Var
    F: Text;
    Line, Subj, Err: String;
    Conf: LongInt;
    N: Word;

  Begin
  AddControls := 0;
  Bad := 0;
  N := 0;
  If Not FileExist(CtlFile(Id)) Then
    Exit;
  Assign(F, CtlFile(Id));
  Reset(F);
  If IoResult <> 0 Then
    Exit;
  While Not Eof(F) Do
    Begin
    ReadLn(F, Line);
    If CtlParse(Line, Conf, Subj, Err) Then
      Begin
      If Offline^.AddControl(Conf, CtlTo, UserName, Subj) Then
        Inc(N)
      Else
        Inc(Bad);
      End
    Else If Err <> '' Then
      Begin
      User.DisplayStrLn('control command not sent: ' + Err);
      Inc(Bad);
      End;
    End;
  Close(F);
  If IoResult <> 0 Then;
  AddControls := N;
  End;


Procedure CtlInPacket(Id: String);
  {the commands are in the reply packet that was made: RemoteId.ctl becomes RemoteId.ctl.out until the hub has the packet}
  Var
    F: File;

  Begin
  If FileExist(CtlFile(Id) + '.out') Then
    Begin
    Assign(F, CtlFile(Id) + '.out');
    Erase(F);
    If IoResult <> 0 Then;
    End;
  Assign(F, CtlFile(Id));
  Rename(F, CtlFile(Id) + '.out');
  If IoResult <> 0 Then;
  End;


Procedure CtlSent(Id: String);
  Var
    F: File;

  Begin
  If FileExist(CtlFile(Id) + '.out') Then
    Begin
    Assign(F, CtlFile(Id) + '.out');
    Erase(F);
    If IoResult <> 0 Then;
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
    NumCtl, BadCtl: Word;

  Begin
  DoReply := True;
  NumCtl := 0;
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
  CtlSent(Id);                           {commands of a packet that is gone: it was sent}
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
    If Cont Then
      Begin
      NumCtl := AddControls(Offline, Id, BadCtl);
      If BadCtl > 0 Then
        QwkNetCtlBad := True;
      End;
    If Offline^.ClosePacket <> 0 Then
      Cont := False;
    End;
  If Cont Then
    Begin
    If (R.NumMsgs = 0) And (NumCtl = 0) Then
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
        User.DisplayStrLn(Long2Str(R.NumMsgs) + ' message(s) and ' + Long2Str(NumCtl) + ' control message(s) in ' + ArcName);
        OffCommitLR(R);                {sent: the last read goes on}
        If NumCtl > 0 Then
          CtlInPacket(Id);
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


Function ListControls(Id: String): Word;
  {the dry run: what RemoteId.ctl (and the -X commands) would send; how many control messages}
  Var
    F: Text;
    Line, Subj, Err: String;
    Conf: LongInt;
    N: Word;
    i: Word;

  Begin
  N := 0;
  If FileExist(CtlFile(Id)) Then
    Begin
    Assign(F, CtlFile(Id));
    Reset(F);
    If IoResult = 0 Then
      Begin
      While Not Eof(F) Do
        Begin
        ReadLn(F, Line);
        If CtlParse(Line, Conf, Subj, Err) Then
          Begin
          Inc(N);
          WriteLn(StdErr, '  control message to ', CtlTo, ' in conference ', Conf, ': ', Subj);
          End
        Else If Err <> '' Then
          WriteLn(StdErr, '  control command NOT sent: ', Err);
        End;
      Close(F);
      If IoResult <> 0 Then;
      End;
    End;
  For i := 1 To QwkNetNumCmds Do
    If CtlParse(QwkNetCmds[i], Conf, Subj, Err) Then
      Begin
      Inc(N);
      WriteLn(StdErr, '  control message to ', CtlTo, ' in conference ', Conf, ': ', Subj, '   (from -X, not queued by a dry run)');
      End
    Else
      WriteLn(StdErr, '  -X command NOT sent: ', Err);
  ListControls := N;
  End;


Function FtpName(Pat, Default, Id: String): String;
  {the remote name: the setting (or its default) with %id% replaced}
  Var
    P: Word;

  Begin
  If Pat = '' Then
    Pat := Default;
  P := Pos('%id%', Lower(Pat));
  While P > 0 Do
    Begin
    Pat := Copy(Pat, 1, P - 1) + Id + Copy(Pat, P + 4, 250);
    P := Pos('%id%', Lower(Pat));
    End;
  FtpName := Pat;
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
    i, Subscribed, CtlCount: Word;

  Begin
  DryRun := 0;
  CtlCount := 0;
  WriteLn(StdErr, 'Dry run of the pass with ', Id, ': nothing is sent, called, moved or written.');
  WriteLn(StdErr, 'User ', UserName, '; reply packets would go to ', Outbound, ', packets from the hub come to ', Inbound);
  If HubExec Then
    Begin
    WriteLn(StdErr, 'Hub by programs (transport exec), host ', HubHost, ':', HubPort);
    WriteLn(StdErr, '  get: ', HubGet);
    WriteLn(StdErr, '  put: ', HubPut);
    End
  Else If HubFtp > 0 Then
    Begin
    WriteLn(StdErr, 'Hub by ', Copy('FTPS', 1, 3 + Ord(HubFtp = 2)), ' at ', HubHost, ':', HubPort);
    WriteLn(StdErr, '  get: ', FtpName(HubGet, '%id%.qwk', Id), '   put: ', FtpName(HubPut, '%id%.rep', Id));
    End
  Else If HubHost <> '' Then
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
  If Cont Then
    CtlCount := ListControls(Id);
  If Not Cont Then
    Begin
    WriteLn(StdErr, 'The messages could not be looked at.');
    DryRun := 3;
    End
  Else If (R.NumMsgs = 0) And (CtlCount = 0) Then
    Begin
    If LedgerSkipped > 0 Then
      WriteLn(StdErr, LedgerSkipped, ' message(s) that came from the hub are not sent back.');
    WriteLn(StdErr, 'Nothing new: no reply packet would be made.');
    End
  Else
    Begin
    If LedgerSkipped > 0 Then
      WriteLn(StdErr, LedgerSkipped, ' message(s) that came from the hub are not sent back.');
    WriteLn(StdErr, R.NumMsgs + CtlCount, ' message(s) would go up in ', ArcName, '.  Last read pointers are NOT moved by this run.');
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


Procedure Say(Text: String);
  {what the pass tells: to the (absent) caller and to the error output, where whoever started mk -G (an event, cron, a script) sees it}
  Begin
  User.DisplayStrLn(Text);
  WriteLn(StdErr, Text);
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


Function ProfileDir(N: Word): String;
  {where a profile file "<name>.scr" is looked for, in this order: next to the map file, the hubs directory of the BBS, the system directory}
  Begin
  Case N Of
    1: If MapDir = '' Then
         ProfileDir := './'                      {the map file is in the current directory}
       Else
         ProfileDir := MapDir;
    2: ProfileDir := WithBackSlash(Config^.GetBbsPath) + 'hubs/';
    3: ProfileDir := '/usr/local/share/mkbbs/hubs/';
    4: ProfileDir := '/usr/share/mkbbs/hubs/';
    Else ProfileDir := '';
    End;
  End;


Function ProfileFile(Name: String): String;
  {the file of the profile, '' when there is none}
  Var
    N: Word;
    D: String;

  Begin
  ProfileFile := '';
  If (Name = '') Or (Pos('/', Name) > 0) Or (Pos('..', Name) > 0) Then
    Exit;
  For N := 1 To 4 Do
    Begin
    D := ProfileDir(N);
    If (D <> '') And FileExist(D + Name + '.scr') Then
      Begin
      ProfileFile := D + Name + '.scr';
      Exit;
      End;
    End;
  End;


Function ReadTextFile(FileName: String; Var Text: AnsiString): Boolean;
  Var
    F: Text;
    Line: String;

  Begin
  ReadTextFile := False;
  Text := '';
  Assign(F, FileName);
  Reset(F);
  If IoResult <> 0 Then
    Exit;
  While Not Eof(F) Do
    Begin
    ReadLn(F, Line);
    Text := Text + Line + #10;
    End;
  Close(F);
  ReadTextFile := True;
  End;


Function HeaderValue(Text: AnsiString; Key: String; N: Word): String;
  {the Nth "# key: value" line in the header of a script (the comment lines before its first command); '' when there is none}
  Var
    P, E: LongInt;
    L, K: String;
    C: Word;

  Begin
  HeaderValue := '';
  C := 0;
  Key := Lower(Key);
  P := 1;
  While P <= Length(Text) Do
    Begin
    E := P;
    While (E <= Length(Text)) And (Text[E] <> #10) Do
      Inc(E);
    L := StripBoth(Copy(Text, P, E - P), ' ');
    If (L <> '') And (L[Length(L)] = #13) Then
      L := StripBoth(Copy(L, 1, Length(L) - 1), ' ');
    P := E + 1;
    If L = '' Then
      Continue;
    If (L[1] <> '#') And (L[1] <> ';') Then
      Exit;                            {the header ends at the first command}
    L := StripBoth(Copy(L, 2, 250), ' ');
    E := Pos(':', L);
    If E > 1 Then
      Begin
      K := Lower(Copy(L, 1, E - 1));
      If K = Key Then
        Begin
        Inc(C);
        If C = N Then
          Begin
          HeaderValue := StripBoth(Copy(L, E + 1, 250), ' ');
          Exit;
          End;
        End;
      End;
    End;
  End;


Procedure ApplyHeader(Text: AnsiString);
  {reply-error and reply-ok of the header of the profile are the ones to use when the map file has none}
  Var
    N: Word;
    V: String;

  Begin
  If (NumErr = 0) And (NumOk = 0) Then
    Begin
    For N := 1 To 8 Do
      Begin
      V := HeaderValue(Text, 'reply-error', N);
      If V = '' Then
        Break;
      Inc(NumErr);
      ReplyErr[NumErr] := Lower(V);
      End;
    For N := 1 To 8 Do
      Begin
      V := HeaderValue(Text, 'reply-ok', N);
      If V = '' Then
        Break;
      Inc(NumOk);
      ReplyOk[NumOk] := Lower(V);
      End;
    End;
  End;


Function LoadHubScript(Var Text: AnsiString): Boolean;
  {the script of the map file, or the profile (a file <name>.scr, else the one built into the program)}
  Var
    Line, Path: String;
    N: Word;

  Begin
  LoadHubScript := False;
  Text := '';
  If HubScript <> '' Then
    Begin
    Line := HubScript;
    If (Line[1] <> '/') Then
      Line := MapDir + Line;
    If Not ReadTextFile(Line, Text) Then
      Begin
      Say('The script ' + Line + ' cannot be read');
      Exit;
      End;
    End
  Else
    Begin
    Path := ProfileFile(HubProfile);
    If Path <> '' Then
      Begin
      If Not ReadTextFile(Path, Text) Then
        Begin
        Say('The profile ' + Path + ' cannot be read');
        Exit;
        End;
      End
    Else
      Text := MKHubScr.HubProfile(HubProfile);
    If Text = '' Then
      Begin
      Say('No profile ' + HubProfile + ' (looked for ' + HubProfile + '.scr in:');
      For N := 1 To 4 Do
        If ProfileDir(N) <> '' Then
          Say('  ' + ProfileDir(N));
      Say('  and the profiles built in: ' + MKHubScr.HubProfileNames + ')');
      Exit;
      End;
    End;
  ApplyHeader(Text);
  LoadHubScript := True;
  End;


Function ReplyRefused(Heard: AnsiString; Var Why: String): Boolean;
  {The hub said something after it got the reply packet: did it refuse it?  "reply-error" texts of the map file (any one seen
   in what the hub said means it did) and "reply-ok" texts (when there are any, one of them has to be seen)}
  Var
    L: AnsiString;
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


Procedure HubFinish(Id, Rep, RcvDir: String; Var Ok: Boolean);
  {the reply packet has gone (it is deleted, the control commands are done with) and the packet that came is put in the inbound directory}
  Var
    F: File;
    FI: FindObj;
    Got, Dest: String;

  Begin
  If HubSent And (Rep <> '') Then
    Begin
    Assign(F, Rep);
    Erase(F);
    If IoResult <> 0 Then;
    CtlSent(Id);                         {the hub has the commands}
    Say('The reply packet was sent');
    End;
  { the packet that came: RemoteId.qwk in the inbound directory }
  Got := '';
  FI.Init;
  FI.FFirst(WithBackSlash(RcvDir) + '*');
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
      Say('Packet received: ' + Id + '.qwk')
    Else
      Ok := False;
    End;
  End;


Function HubConfigured: Boolean;
  {the map file says how to reach a hub: a host to call, or programs (transport exec) that move the files}
  Begin
  HubConfigured := (HubHost <> '') Or (HubExec And ((HubGet <> '') Or (HubPut <> '')));
  End;


Function HubLogPath(Id: String): String;
  Begin
  If HubLog = '' Then
    HubLog := MapDir + Id + '.hub.log'
  Else If HubLog[1] <> '/' Then
    HubLog := MapDir + HubLog;
  HubLogPath := HubLog;
  End;


Function Redact(S: AnsiString): AnsiString;
  {the password of the hub is not written in the transcript}
  Var
    P: LongInt;

  Begin
  If HubPass <> '' Then
    Begin
    P := Pos(HubPass, S);
    While P > 0 Do
      Begin
      S := Copy(S, 1, P - 1) + '********' + Copy(S, P + Length(HubPass), Length(S));
      P := Pos(HubPass, S);
      End;
    End;
  Redact := S;
  End;


Function ExecWhy(R: LongInt; Out: AnsiString): String;
  Var
    L: String;

  Begin
  If R = -2 Then
    ExecWhy := 'it did not end in ' + Long2Str(HubExecSecs) + ' seconds and was stopped'
  Else If R = -1 Then
    ExecWhy := Copy(Redact(Out), 1, 200)
  Else
    Begin
    L := Copy(Redact(Out), Length(Redact(Out)) - 150, 160);
    While (L <> '') And (L[Length(L)] In [#10, #13]) Do
      Dec(L[0]);
    ExecWhy := 'exit status ' + Long2Str(R) + Copy(': ' + L, 1, 170 * Ord(L <> ''));
    End;
  End;


Function ExecPass(Id, Rep: String): Integer;
  {transport exec: "get" fetches the packet of the hub, "put" sends the reply packet; 0 done, 5 a program failed, 6 the packet could not be kept, 7 refused}
  Var
    Out: AnsiString;
    R: LongInt;
    Qwk, RepCopy, Why: String;
    LogF: Text;
    LogOk, Failed, Refused, Ok, HaveRep: Boolean;

  Procedure Note(Text: String);
    Begin
    If LogOk Then
      WriteLn(LogF, Text);
    End;

  Procedure NoteRun(What, Cmd: String; Status: LongInt; Output: AnsiString);
    Begin
    Note('== ' + What + ': ' + Cmd);
    If Output <> '' Then
      Write(LogF, Redact(Output));
    If (Output <> '') And (Output[Length(Output)] <> #10) Then
      Note('');
    Note('== ' + What + ' ended: ' + Long2Str(Status));
    End;

  Begin
  ExecPass := 0;
  Failed := False;
  Refused := False;
  Ok := True;
  HubSent := False;
  Qwk := WithBackSlash(HubRcvDir) + Id + '.QWK';
  Assign(LogF, HubLogPath(Id));
  Rewrite(LogF);
  LogOk := IoResult = 0;
  HubExecClear;
  HubExecVar('id', Id);
  HubExecVar('qwk', Qwk);
  HubExecVar('login', HubLogin);
  HubExecVar('host', HubHost);
  HubExecVar('port', Long2Str(HubPort));
  HubExecEnv('MK_HUB_ID', Id);
  HubExecEnv('MK_HUB_LOGIN', HubLogin);
  HubExecEnv('MK_HUB_PASSWORD', HubPass);      {not on the command line: ps would show it}
  HubExecEnv('MK_HUB_HOST', HubHost);
  HubExecEnv('MK_HUB_PORT', Long2Str(HubPort));
  HubExecEnv('MK_HUB_QWK', Qwk);
  HaveRep := False;
  If (Rep <> '') And (HubPut <> '') Then
    Begin
    RepCopy := WithBackSlash(HubRcvDir) + Id + '.REP';        {the name the hub wants: <QWK id>.REP}
    If CopyFile(Rep, RepCopy) Then
      Begin
      HaveRep := True;
      HubExecVar('rep', RepCopy);
      HubExecEnv('MK_HUB_REP', RepCopy);
      End;
    End;
  If HubGet <> '' Then
    Begin
    R := HubExecRun(HubGet, MapDir, HubExecSecs, Out);
    NoteRun('get', HubGet, R, Out);
    If R = 0 Then
      Begin
      If FileExist(Qwk) Then
        Say('Packet fetched from the hub')
      Else
        Say('The get program ended well and left no packet: nothing new');
      End
    Else If R = HubNothing Then
      Say('Nothing new at the hub')
    Else
      Begin
      Failed := True;
      Say('The get program failed: ' + ExecWhy(R, Out));
      End;
    End;
  If HaveRep Then
    Begin
    R := HubExecRun(HubPut, MapDir, HubExecSecs, Out);
    NoteRun('put', HubPut, R, Out);
    If R = 0 Then
      Begin
      HubSent := True;
      If (NumErr > 0) Or (NumOk > 0) Then
        If ReplyRefused(Out, Why) Then
          Begin
          Refused := True;
          HubSent := False;                   {the reply packet stays: the next pass sends it again}
          Say('The hub did not accept the reply packet: ' + Why + '; it stays in the outbound directory');
          End;
      End
    Else
      Begin
      Failed := True;
      Say('The put program failed: ' + ExecWhy(R, Out) + '; the reply packet stays in the outbound directory');
      End;
    End;
  If LogOk Then
    Close(LogF);
  If IoResult <> 0 Then;
  HubFinish(Id, Rep, HubRcvDir, Ok);
  HubExecClear;                          {the password is not kept}
  If Failed Then
    ExecPass := 5
  Else If Not Ok Then
    ExecPass := 6
  Else If Refused Then
    ExecPass := 7;
  End;


Function FtpPass(Id, Rep: String): Integer;
  {transport ftp / ftps: "get" is the remote name of the packet, "put" the remote name of the reply packet; 0 done, 5 the FTP failed, 6 the packet could not be kept, 7 refused}
  Var
    F: TFtp;
    Err: ShortString;
    Why, Qwk, Remote: String;
    LogF: Text;
    R: Integer;
    LogOk, Failed, Refused, Ok: Boolean;

  Begin
  FtpPass := 0;
  Failed := False;
  Refused := False;
  Ok := True;
  HubSent := False;
  Qwk := WithBackSlash(HubRcvDir) + Id + '.QWK';
  Assign(LogF, HubLogPath(Id));
  Rewrite(LogF);
  LogOk := IoResult = 0;
  Err := '';
  F := FtpOpen(HubHost, HubPort, HubFtp = 2, HubTlsCa, HubTlsVerify, HubFtpSecs, Err);
  If F = Nil Then
    Failed := True
  Else If Not F.Login(HubLogin, HubPass) Then
    Begin
    Err := F.Err;
    Failed := True;
    End;
  If Failed Then
    Say('FTP with ' + HubHost + ' failed: ' + Err)
  Else
    Begin
    Say('Connected by ' + Copy('FTPS', 1, 3 + Ord(HubFtp = 2)) + ' to ' + HubHost + ':' + Long2Str(HubPort));
    Remote := FtpName(HubGet, '%id%.qwk', Id);
    R := F.Retr(Remote, Qwk);
    If R = 0 Then
      Begin
      Say('Packet fetched from the hub (' + Remote + ')');
      If HubFtpDel Then
        If Not F.Dele(Remote) Then
          Say('The packet could not be deleted at the hub: ' + Copy(F.Reply, 1, 80));
      End
    Else If R = 1 Then
      Say('Nothing new at the hub (' + Remote + ' is not there)')
    Else
      Begin
      Failed := True;
      Say('The fetch failed: ' + F.Err);
      End;
    If Rep <> '' Then
      Begin
      Remote := FtpName(HubPut, '%id%.rep', Id);
      If F.Stor(Rep, Remote) Then
        Begin
        HubSent := True;
        If (NumErr > 0) Or (NumOk > 0) Then
          If ReplyRefused(F.Reply, Why) Then
            Begin
            Refused := True;
            HubSent := False;
            Say('The hub did not accept the reply packet: ' + Why + '; it stays in the outbound directory');
            End;
        End
      Else
        Begin
        Failed := True;
        Say('Sending the reply packet failed: ' + F.Err + '; it stays in the outbound directory');
        End;
      End;
    F.Quit;
    End;
  If LogOk Then
    Begin
    If F <> Nil Then
      Write(LogF, F.Trace);
    Close(LogF);
    End;
  If IoResult <> 0 Then;
  If F <> Nil Then
    F.Free;
  HubFinish(Id, Rep, HubRcvDir, Ok);
  If Failed Then
    FtpPass := 5
  Else If Not Ok Then
    FtpPass := 6
  Else If Refused Then
    FtpPass := 7;
  End;


Function DoHub(Id: String): Integer;
  {0 done, 5 not reached, 6 the script failed, 7 the hub did not accept the reply packet}
  Var
    S, OldSess: AbsComPtr;
    Err: ShortString;
    H: HubScriptObj;
    Text: AnsiString;
    Rep: String;
    Ok: Boolean;
    OldPort: Word;
    OldRate: LongInt;
    Refused: Boolean;
    Why: String;

  Begin
  DoHub := 0;
  Refused := False;
  If OffFindNoCase(Inbound, Id + '.qwk') <> '' Then
    Begin
    Say(Id + '.qwk is still in the inbound directory: no call before it is posted');
    Exit;
    End;
  If HubExec Or (HubFtp > 0) Then
    Text := ''
  Else If Not LoadHubScript(Text) Then
    Begin
    Say('No script for the hub: "profile" or "script" in ' + Id + '.map');
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
  If HubExec Or (HubFtp > 0) Then
    S := Nil
  Else
    S := ConnectTcp(HubHost, HubPort, 20000, True, Err);
  If S = Nil Then
    Begin
    If HubExec Then
      DoHub := ExecPass(Id, Rep)
    Else If HubFtp > 0 Then
      DoHub := FtpPass(Id, Rep)
    Else
      Begin
      Say('Hub ' + HubHost + ': ' + Err);
      DoHub := 5;
      End;
    End
  Else
    Begin
    Say('Connected to ' + HubHost + ':' + Long2Str(HubPort));
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
    H.SetTranscript(HubLogPath(Id));
    H.SetXfer(HubXfer);
    Ok := H.Load(Text) And H.Run;
    If Not Ok Then
      Say('The call to the hub failed: ' + H.ErrText);
    If HubSent And (Rep <> '') And ((NumErr > 0) Or (NumOk > 0)) Then
      If ReplyRefused(H.Heard, Why) Then
        Begin
        Refused := True;
        HubSent := False;                     {the reply packet stays: the next pass sends it again}
        Say('The hub did not accept the reply packet: ' + Why + '; it stays in the outbound directory');
        End;
    H.Done;
    S^.Hangup;
    Dispose(S, Done);
    ProtKeepInput := False;
    ComSession := OldSess;
    CurrentPort := OldPort;
    CurrentRate := OldRate;
    HubFinish(Id, Rep, HubRcvDir, Ok);
    If Not Ok Then
      DoHub := 6
    Else If Refused Then
      DoHub := 7;
    End;
  CleanDir(WithBackSlash(HubRcvDir));
  RmDir(StripTrail(HubRcvDir, '/'));
  If IoResult <> 0 Then;
  End;


Function UnpackCmds(Offline: QwkOffPtr; WorkPath: String): Boolean;
  {the packet is WorkPath/upload.1: unpacked with the packer of the system (the one it uses, then any other that is set up)}
  Var
    Cmds: OffCmdList;
    NumCmds, k, i: Word;

  Begin
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
  UnpackCmds := OffUnpackReply(Offline, WorkPath, StartUpPath, Cmds, NumCmds);
  End;


Function DoPacket(Id: String): Boolean;
  {the packet of the system; False when it is there and could not be read}
  Var
    Offline: QwkOffPtr;
    WorkPath, Src: String;
    N: Word;
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
    Say('No packet from ' + Id);
    Exit;
    End;
  WorkPath := CreateTempDir(Config^.GetTempPath);
  Cont := (Length(WorkPath) > 0) And CopyFile(Src, WithBackSlash(WorkPath) + 'upload.1');
  Offline := New(QwkOffPtr, Init);
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Offline^.SetLink(Id, NetConfOf, NetAreaOf);
    Cont := UnpackCmds(Offline, WorkPath);
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
    Say(Long2Str(Offline^.GetImported) + ' message(s) posted from ' + Id);
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
            Say(Config^.GetMsgName(A) + ': other messages were waiting or came in meanwhile, the ones from the system may go back');
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
    Say('The packet from ' + Id + ' could not be read');
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


Function Norm(S: String): String;
  {a name for comparing: letters and digits, upper case}
  Var
    R: String;
    i: Word;

  Begin
  R := '';
  For i := 1 To Length(S) Do
    If UpCase(S[i]) In ['A'..'Z', '0'..'9'] Then
      R := R + UpCase(S[i]);
  Norm := R;
  End;


Function ConfReport(Id: String): Integer;
  {mk -G<id> -I / -J: the conferences in CONTROL.DAT of the packet that is in the inbound directory (or that the last pass kept as .old), what each is here,
   and with -J suggestions for the ones that have no conf line, from the names of the message areas.  The hub is not called: asking it for a packet
   makes it move its pointers.  0 done, 4 the packet could not be read, 9 there is no packet}
  Const
    MaxC = 400;

  Var
    Src, WorkPath, Ctl, Line: String;
    Offline: QwkOffPtr;
    Cont: Boolean;
    T: Text;
    O: Text;
    BbsName: String;
    CNum: Array[1..MaxC] Of LongInt;
    CName: Array[1..MaxC] Of String[40];
    N, i, j, A, Best, Sure: Word;
    Total, V: LongInt;
    Seen, Found: Boolean;
    Used: Array[1..OffAreas] Of Boolean;
    Lines: String;
    MapF: Text;
    Wrote: Word;

  Begin
  ConfReport := 0;
  Assign(O, '');
  Rewrite(O);
  Src := OffFindNoCase(Inbound, Id + '.qwk');
  If Src = '' Then
    Src := OffFindNoCase(Inbound, Id + '.qwk.old');
  If Src = '' Then
    Begin
    WriteLn(StdErr, 'No packet from ', Id, ' in ', Inbound, ' (nor ', Id, '.qwk.old, kept by the last pass).  The hub is not called for this: asking it for a packet makes it move its pointers.');
    ConfReport := 9;
    Close(O);
    Exit;
    End;
  WorkPath := CreateTempDir(Config^.GetTempPath);
  Cont := (Length(WorkPath) > 0) And CopyFile(Src, WithBackSlash(WorkPath) + 'upload.1');
  Offline := New(QwkOffPtr, Init);
  N := 0;
  BbsName := '';
  If Cont Then
    Begin
    Offline^.SetPath(WorkPath);
    Offline^.SetLink(Id, NetConfOf, NetAreaOf);
    Cont := UnpackCmds(Offline, WorkPath);
    End;
  Ctl := '';
  If Cont Then
    Ctl := OffFindNoCase(WithBackSlash(WorkPath), 'control.dat');
  If Ctl = '' Then
    Cont := False;
  If Cont Then
    Begin
    Assign(T, Ctl);
    Reset(T);
    If IoResult <> 0 Then
      Cont := False
    Else
      Begin
      i := 0;
      Total := -1;
      While (Not Eof(T)) And Cont Do
        Begin
        ReadLn(T, Line);
        Line := StripBoth(Line, ' ');
        Inc(i);
        If i = 1 Then
          BbsName := Line
        Else If i = 11 Then
          Total := Str2Long(Line) + 1                   {the line holds the number of conferences less one}
        Else If (i > 11) And (Total > 0) Then
          Begin
          If Not Odd(i) Then
            Begin                                       {12: number, 13: name, 14: number ...}
            V := Str2Long(Line);
            If N < MaxC Then
              Begin
              Inc(N);
              CNum[N] := V;
              CName[N] := '';
              End;
            End
          Else If N > 0 Then
            CName[N] := Copy(Line, 1, 40);
          End;
        End;
      Close(T);
      If Total < 0 Then
        Cont := False;
      End;
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
  If Not Cont Then
    Begin
    WriteLn(StdErr, 'The packet ', Src, ' could not be read (no CONTROL.DAT, or it cannot be unpacked)');
    ConfReport := 4;
    Close(O);
    Exit;
    End;
  If QwkNetConfList Then
    Begin
    WriteLn(O, 'Packet ', Src, ' (', BbsName, '): ', N, ' conference(s)');
    WriteLn(O, '  conf  name                              here');
    For i := 1 To N Do
      Begin
      Write(O, CNum[i]:6, '  ', CName[i], '':36 - Length(CName[i]));
      If (CNum[i] >= 0) And (CNum[i] <= 65535) And (ConfArea[CNum[i]] <> 0) Then
        WriteLn(O, 'area ', ConfArea[CNum[i]], ' ', Config^.GetMsgName(ConfArea[CNum[i]]))
      Else
        WriteLn(O, '-  (no conf line)');
      End;
    Seen := False;
    For A := 0 To 65535 Do
      If ConfArea[A] <> 0 Then
        Begin
        Found := False;
        For i := 1 To N Do
          If CNum[i] = A Then
            Found := True;
        If Not Found Then
          Begin
          If Not Seen Then
            WriteLn(O, 'Lines of the map file for conferences that are not in the packet:');
          Seen := True;
          WriteLn(O, '  conf ', A, ' ', ConfArea[A]);
          End;
        End;
    End;
  If QwkNetConfMatch Then
    Begin
    FillChar(Used, SizeOf(Used), 0);
    For A := 1 To OffAreas Do
      If AreaConf[A] >= 0 Then
        Used[A] := True;                                {has a conf line already}
    Lines := '';
    Wrote := 0;
    WriteLn(O, 'Suggestions for the map file (by the names of the message areas; ; = not sure, look at it first):');
    For i := 1 To N Do
      If (CNum[i] >= 0) And (CNum[i] <= 65535) And (ConfArea[CNum[i]] = 0) Then
        Begin
        Best := 0;
        Sure := 0;
        For A := 1 To OffAreas Do
          If (Not Used[A]) And (A <= Config^.GetMaxMsgAreas) And (Config^.GetMsgName(A) <> '') Then
            Begin
            If (Norm(CName[i]) <> '') And ((Norm(CName[i]) = Norm(Config^.GetMsgName(A))) Or (Norm(CName[i]) = Norm(Config^.GetMsgShortName(A)))) Then
              Begin
              If Sure = 0 Then
                Sure := A;
              End
            Else If (Best = 0) And (Length(Norm(CName[i])) >= 4) And (Length(Norm(Config^.GetMsgName(A))) >= 4) And
              ((Pos(Norm(CName[i]), Norm(Config^.GetMsgName(A))) > 0) Or (Pos(Norm(Config^.GetMsgName(A)), Norm(CName[i])) > 0)) Then
              Best := A;
            End;
        If Sure > 0 Then
          Begin
          Line := 'conf ' + Long2Str(CNum[i]) + ' ' + Long2Str(Sure) + '          ; ' + CName[i] + ' = ' + Config^.GetMsgName(Sure);
          Used[Sure] := True;
          Inc(Wrote);
          End
        Else If Best > 0 Then
          Line := '; conf ' + Long2Str(CNum[i]) + ' ' + Long2Str(Best) + '          ; ' + CName[i] + ' ? ' + Config^.GetMsgName(Best)
        Else
          Line := '';
        If Line <> '' Then
          Begin
          WriteLn(O, Line);
          Lines := Lines + Line + #10;
          End;
        End;
    If Lines = '' Then
      WriteLn(O, '  (nothing: no conference without a conf line matches the name of a free message area)');
    If QwkNetConfWrite And (Lines <> '') Then
      Begin
      Assign(MapF, MapDir + Id + '.map');
      Append(MapF);
      If IoResult = 0 Then
        Begin
        WriteLn(MapF);
        WriteLn(MapF, '; added by mk -G', Id, ' -J -W: the sure ones are conf lines, the ones with ; in front are to be looked at');
        While Lines <> '' Do
          Begin
          j := Pos(#10, Lines);
          WriteLn(MapF, Copy(Lines, 1, j - 1));
          Delete(Lines, 1, j);
          End;
        Close(MapF);
        WriteLn(O, 'Added to ', MapDir + Id + '.map', ' (', Wrote, ' conf line(s)).');
        End
      Else
        Begin
        WriteLn(StdErr, 'The map file could not be written');
        ConfReport := 1;
        End;
      End
    Else If Lines <> '' Then
      WriteLn(O, 'Nothing is written: -W adds these lines to ', Id, '.map.');
    End;
  Close(O);
  End;


Function TalkPass(Id: String): Integer;
  {mk -G<id> -K: a call to the hub with the keyboard of whoever started it; the transcript (<id>.hub.log) is what a profile is written from.  0 done, 5 the hub was not reached}
  Var
    S, OldSess: AbsComPtr;
    Err: ShortString;
    H: HubScriptObj;
    OldPort: Word;
    OldRate: LongInt;
    W: TWinSize;

  Begin
  TalkPass := 0;
  If HubHost = '' Then
    Begin
    Say('No "hub" in ' + Id + '.map: nobody to talk to');
    TalkPass := 5;
    Exit;
    End;
  HubRcvDir := MapDir + Id + '.talk/';          {what is received by hand stays here}
  MkDir(StripTrail(HubRcvDir, '/'));
  If IoResult <> 0 Then;
  ClientTerm := GetEnv('TERM');
  If ClientTerm = '' Then
    ClientTerm := 'ansi';
  ClientCols := 80;
  ClientRows := 24;
  If fpIoctl(0, TIOCGWINSZ, @W) = 0 Then
    If (W.ws_col > 0) And (W.ws_row > 0) Then
      Begin
      ClientCols := W.ws_col;
      ClientRows := W.ws_row;
      End;
  S := ConnectTcp(HubHost, HubPort, 20000, True, Err);
  If S = Nil Then
    Begin
    Say('Hub ' + HubHost + ': ' + Err);
    TalkPass := 5;
    Exit;
    End;
  OldSess := ComSession;
  OldPort := CurrentPort;
  OldRate := CurrentRate;
  ComSession := S;
  CurrentPort := 1;
  CurrentRate := 38400;
  ProtQuiet := True;
  ProtKeepInput := True;
  HubSent := False;
  H.Init(S);
  H.SetVar('login', HubLogin);
  H.SetVar('password', HubPass);              {typed or not: the stars in the transcript}
  H.SetTranscript(HubLogPath(Id));
  H.Note('-- talk: ' + HubHost + ':' + Long2Str(HubPort));
  HubTalk(H, S, HubXfer, ClientCols, ClientRows);
  H.Done;
  S^.Hangup;
  Dispose(S, Done);
  ProtKeepInput := False;
  ComSession := OldSess;
  CurrentPort := OldPort;
  CurrentRate := OldRate;
  Say('The transcript is ' + HubLog + '; files that were received are in ' + HubRcvDir);
  End;


Function ReplayPass(Id, TFile: String): Integer;
  {mk -G<id> -F<transcript>: the script of the profile against a recording; 0 it went the same way, 6 it did not, 1 the recording is not there}
  Var
    R: ReplayPtr;
    H: HubScriptObj;
    Script: AnsiString;
    Ok, Good: Boolean;
    Why: String;
    O: Text;
    LogF: String;

  Begin
  ReplayPass := 0;
  If Not LoadHubScript(Script) Then
    Begin
    ReplayPass := 6;
    Exit;
    End;
  New(R, InitFile(TFile, Good));
  If Not Good Then
    Begin
    Say('No recording in ' + TFile + ' (a transcript has lines beginning with <<, >> and --)');
    Dispose(R, Done);
    ReplayPass := 1;
    Exit;
  End;
  ReplayCur := R;
  H.Init(R);
  H.SetVar('login', HubLogin);
  H.SetVar('password', HubPass);
  H.SetVar('protocol', HubProto);
  H.SetVar('id', Id);
  If R^.HasEvent('U') Then
    Begin
    H.SetVar('rep', '/tmp/' + Id + '.REP');
    H.SetVar('have_rep', '1');
    End;
  LogF := MapDir + Id + '.replay.log';
  H.SetTranscript(LogF);
  H.SetXfer(ReplayXfer);
  Ok := H.Load(Script) And H.Run;
  Assign(O, '');
  Rewrite(O);
  If R^.Fault <> '' Then
    Ok := False;
  If Ok And (R^.Left > 0) Then
    Begin
    Ok := False;
    R^.Fault := 'the script ended but the recording goes on (' + Long2Str(R^.Left) + ' more step(s) of the script in it)';
    End;
  If Ok Then
    WriteLn(O, 'Replay of ', TFile, ': the script went the same way (', R^.NumEv, ' events). Heard after the upload: ', Length(H.Heard), ' characters.')
  Else
    Begin
    WriteLn(O, 'Replay of ', TFile, ': it did not go the same way.');
    If R^.Fault <> '' Then
      WriteLn(O, '  ', R^.Fault);
    If H.ErrText <> '' Then
      WriteLn(O, '  script: ', H.ErrText);
    WriteLn(O, '  the replay is written in ', LogF);
    ReplayPass := 6;
    End;
  If Ok And (NumErr + NumOk > 0) And R^.HasEvent('U') Then
    If ReplyRefused(H.Heard, Why) Then
      WriteLn(O, '  the hub would have refused the reply packet: ', Why)
    Else
      WriteLn(O, '  the hub accepted the reply packet (reply-error / reply-ok)');
  Close(O);
  H.Done;
  ReplayCur := Nil;
  Dispose(R, Done);
  End;


Function QwkNetPass(RemoteId: String): Integer;
  Var
    Res, N: Integer;
    i: Word;
    CtlErr: String;

  Begin
  Res := 0;
  If Not LoadMap(RemoteId) Then
    Begin
    Say('No map file ' + RemoteId + '.map');
    QwkNetPass := 1;
    Exit;
    End;
  If QwkNetTalk Then
    Begin
    QwkNetPass := TalkPass(RemoteId);
    Exit;
    End;
  If QwkNetReplay <> '' Then
    Begin
    QwkNetPass := ReplayPass(RemoteId, QwkNetReplay);
    Exit;
    End;
  If QwkNetConfList Or QwkNetConfMatch Then
    Begin                                {a report on the packet: nothing is sent, called or changed}
    QwkNetPass := ConfReport(RemoteId);
    Exit;
    End;
  User.GetUserPos(UserName);
  If User.UserFound Then
    User.ReadUser;
  If (Not User.UserFound) Or (Not User.GetUserQwkNode) Then
    Begin
    Say('No user ' + UserName + ' with the QWK Node flag');
    QwkNetPass := 2;
    Exit;
    End;
  If Not QwkNetDry Then
    For i := 1 To QwkNetNumCmds Do
      If Not QueueCtl(RemoteId, QwkNetCmds[i], CtlErr) Then
        Begin
        User.DisplayStrLn('control command not queued: ' + CtlErr);
        WriteLn(StdErr, 'mk: control command "', QwkNetCmds[i], '" not queued: ', CtlErr);
        QwkNetCtlBad := True;
        End;
  If QwkNetDry Then
    Begin
    QwkNetPass := DryRun(RemoteId);          {nothing else: no WriteUser either}
    Exit;
    End;
  If Not DoReply(RemoteId) Then
    Res := 3;
  If HubConfigured Then
    Begin
    N := DoHub(RemoteId);
    If N <> 0 Then
      Res := N;
    End;
  If Not DoPacket(RemoteId) Then
    Res := 4;
  If QwkNetCtlBad And (Res = 0) Then
    Res := 8;
  User.WriteUser;
  QwkNetPass := Res;
  End;



Procedure ProfilesTo(Var O: Text; RemoteId, Name: String);
  {mk -G -P: the profiles that are found (a file <name>.scr in the directories, else built into the program) with what their headers say;
   mk -G -P<name>: the text of one}
  Var
    N, i: Word;
    D, Text, Names, W: AnsiString;
    FI: FindObj;
    Seen: String;
    Path: String;

  Begin
  MapDir := '';
  If RemoteId <> '' Then
    If LoadMap(RemoteId) Then;
  If Name <> '' Then
    Begin
    Path := ProfileFile(Name);
    If Path <> '' Then
      Begin
      If ReadTextFile(Path, Text) Then
        Begin
        WriteLn(O, '# profile ', Name, ': ', Path);
        Write(O, Text);
        End;
      End
    Else
      Begin
      Text := MKHubScr.HubProfile(Name);
      If Text = '' Then
        Begin
        WriteLn(StdErr, 'No profile ', Name, ' (no file ', Name, '.scr in the directories below, and not one of the built in: ', MKHubScr.HubProfileNames, ')');
        For N := 1 To 4 Do
          If ProfileDir(N) <> '' Then
            WriteLn(StdErr, '  ', ProfileDir(N));
        Exit;
        End;
      WriteLn(O, '# profile ', Name, ': built into the program');
      Write(O, Text);
      End;
    Exit;
    End;
  Seen := ',';
  WriteLn(O, 'Hub profiles (a hub in a map file: "profile <name>"; the first file found wins):');
  For N := 1 To 4 Do
    Begin
    D := ProfileDir(N);
    If (D = '') Or Not DirExist(D) Then
      Continue;
    FI.Init;
    FI.FFirst(D + '*.scr');
    While FI.Found Do
      Begin
      W := FI.GetName;
      W := Copy(W, 1, Length(W) - 4);
      If Pos(',' + Lower(W) + ',', Seen) = 0 Then
        Begin
        Seen := Seen + Lower(W) + ',';
        If ReadTextFile(D + FI.GetName, Text) Then
          Begin
          WriteLn(O, '  ', W, '   ', D, FI.GetName);
          If HeaderValue(Text, 'software', 1) <> '' Then
            WriteLn(O, '      software: ', HeaderValue(Text, 'software', 1));
          If HeaderValue(Text, 'checked', 1) <> '' Then
            WriteLn(O, '      checked:  ', HeaderValue(Text, 'checked', 1));
          If HeaderValue(Text, 'reply-error', 1) <> '' Then
            WriteLn(O, '      reply-error: ', HeaderValue(Text, 'reply-error', 1));
          End;
        End;
      FI.FNext;
      End;
    FI.Done;
    End;
  Names := MKHubScr.HubProfileNames + ',';
  While Names <> '' Do
    Begin
    i := Pos(',', Names);
    W := StripBoth(Copy(Names, 1, i - 1), ' ');
    Delete(Names, 1, i);
    If (W <> '') And (Pos(',' + Lower(W) + ',', Seen) = 0) Then
      Begin
      Text := MKHubScr.HubProfile(W);
      WriteLn(O, '  ', W, '   built into the program');
      If HeaderValue(Text, 'software', 1) <> '' Then
        WriteLn(O, '      software: ', HeaderValue(Text, 'software', 1));
      If HeaderValue(Text, 'checked', 1) <> '' Then
        WriteLn(O, '      checked:  ', HeaderValue(Text, 'checked', 1));
      End;
    End;
  WriteLn(O, 'Looked in: ', ProfileDir(1), ' ', ProfileDir(2), ' ', ProfileDir(3), ' ', ProfileDir(4));
  End;


Procedure QwkNetProfiles(RemoteId, Name: String);
  Var
    O: Text;

  Begin
  Assign(O, '');                         {standard output: Output is the virtual screen in mk}
  Rewrite(O);
  ProfilesTo(O, RemoteId, Name);
  Close(O);
  End;


End.
