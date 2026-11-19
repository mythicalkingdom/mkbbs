Unit MKQwkNet;       {QWK network: one pass with a remote QWK system (mk -G<RemoteId>)}

{$I MKB.Def}

{
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
     4 the packet of the system could not be read, 5 the hub could not be reached, 6 the script (login, transfer) failed.
}


Interface


Function QwkNetPass(RemoteId: String): Integer;


Implementation


Uses MKString, MKFile, MKGlobT, MKCfgAbs, MKDoor, MKOpen, MKMsgAbs,
  MKOffAbs, MKOffQwk, MKOffDL, MKOffXfer, MKOfflin,
  MKComAbs, MKComClient, MKHubScr, MKProt, MKVideo, MKPlat,
  Dos;


Var
  ConfArea: Array[0..65535] Of Word;     {conference of the system -> area here (0 = none)}
  AreaConf: Array[1..OffAreas] Of LongInt; {area -> conference (-1 = none)}
  Inbound, Outbound, UserName, MapDir: String;
  HubHost, HubProfile, HubScript, HubLogin, HubPass, HubProto, HubLog: String;
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
    Cont := OffExport(Offline, P, R);
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


Function DoHub(Id: String): Integer;
  {0 done, 5 not reached, 6 the script failed}
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

  Begin
  DoHub := 0;
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
      DoHub := 6;
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
    Offline^.ImportPacket;
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
