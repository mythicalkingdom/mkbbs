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

     Directories are written without blanks.  An area without a "conf" line is not in the packet, a conference
     of the packet without one is not posted.

     The pass:
       1. the reply packet: the new messages of the subscribed areas, as RemoteId.REP (a ZIP, with RemoteId.msg: the number
          field of a message is its conference, byte 126 'E' says echomail).  It is not made when there are no
          new messages, nor when the last one is still in the outbound directory (nothing is lost: the last read
          pointers go on only when the packet was made)
       2. the packet of the system, RemoteId.QWK in the inbound directory (any case): unpacked, its messages are
          posted (duplicates are skipped: RemoteId.dup next to the map file); the packet is kept as RemoteId.QWK.old
       3. the messages that were just posted must not go back: where the area was all sent before and the new messages
          follow the old ones directly, the last read pointer is moved past them
     Long names and subjects (QWKE) are used in the reply packet and read from the packet.

     The exit code: 0 done, 1 no map file, 2 the user is not there (or is not a QWK node), 3 the reply packet could not be made,
     4 the packet of the system could not be read.
}


Interface


Function QwkNetPass(RemoteId: String): Integer;


Implementation


Uses MKString, MKFile, MKGlobT, MKCfgAbs, MKDoor, MKOpen, MKMsgAbs,
  MKOffAbs, MKOffQwk, MKOffDL, MKOffXfer, MKOfflin,
  Dos;


Var
  ConfArea: Array[0..65535] Of Word;     {conference of the system -> area here (0 = none)}
  AreaConf: Array[1..OffAreas] Of LongInt; {area -> conference (-1 = none)}
  Inbound, Outbound, UserName, MapDir: String;
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
    Res: Integer;

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
  If Not DoPacket(RemoteId) Then
    Res := 4;
  User.WriteUser;
  QwkNetPass := Res;
  End;


End.
