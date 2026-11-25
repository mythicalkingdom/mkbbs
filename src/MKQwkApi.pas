Unit MKQwkApi;   {QWK packets for a node through the JSON API: the packet, its acknowledgement (QWK-API-PLAN.md)}

{$mode objfpc}{$H+}

{
     A QWK node is a user record with the QWK Node flag; what it gets is the offline mail of that record (MKOfflin: the areas it chose, its packet type and packer, its last read pointers).
     Step 1 (QwkPacket) makes the packet and keeps it as the WAITING packet of the node (qwkapi/<user>/waiting.qwk and waiting.state) without moving anything; the same packet is sent again until step 2
     (QwkAck) is done: the last read pointers move, but only when they are still where they were when the packet was made (compare and set: a node that also fetched by Telnet in the meantime, or a
     reset by the sysop, makes the acknowledgement a conflict and nothing goes back).  A packet that is not acknowledged within keep_days is dropped (and its acknowledgement is "gone").
     The requests of one node run one at a time (a lock file): a second one while the first is on is "locked".  qwkapi/<user>/acked.log remembers the ids that were acknowledged, so a repeated
     acknowledgement of a lost answer is harmless.
}

Interface

Uses SysUtils, Classes, fpjson;

Type
  TQwkRes = Record
    Code: Integer;                    {the HTTP status: 200, 204, 404, 409, 410, 423 ...}
    Err: String;                      {the reason of an error}
    Id, FilePath, Sha: String;        {the packet: its id, the file, its SHA-256 (hex)}
    Messages: LongInt;
    Bytes: Int64;
    Already: Boolean;                 {an acknowledgement that was done before}
    End;

Function QwkNodeLoad(Const UserName: String; Var Code: Integer; Var Err: String): Boolean;
Function QwkInfo(Const UserName: String; MaxPacket, MaxReply, KeepDays: Int64): TJSONObject;
Procedure QwkPacket(Const UserName: String; Rebuild: Boolean; MaxPacket, KeepDays: Int64; Var Res: TQwkRes);
Procedure QwkAck(Const UserName, Id: String; KeepDays: Int64; Var Res: TQwkRes);
Function QwkReply(Const UserName, BodyFile: String; KeepDays: Int64; CrashTest: Boolean; Var Res: TQwkRes; Var Answer: TJSONObject): Boolean;
  {the reply packet in BodyFile: posted as the node.  Res.Code 200 (Answer says what happened), 400, 409, 415, 423 ...}

Implementation

Uses BaseUnix, Unix, DateUtils, sha1, MKGlobT, MKString, MKCfgAbs, MKDoor, MKFile, MKStr, MKMsgAbs, MKOffAbs, MKOffQwk, MKOffXfer, MKQwkImp, MKOffDL, MKOfflin, MKApiTok, MKApiData;

Var
  LockFd: LongInt = -1;


Function NodeKey(Const Name: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(Name) Do
    If LowerCase(Name[i]) In ['a'..'z', '0'..'9'] Then
      Result := Result + LowerCase(Name[i])
    Else
      Result := Result + '_';
  End;


Function NodeDir(Const Name: String): String;
  Var
    B: String;

  Begin
  B := Config^.GetBbsPath;
  If (B <> '') And (B[Length(B)] <> '/') Then
    B := B + '/';
  Result := B + 'qwkapi/' + NodeKey(Name) + '/';
  End;


Function NowUnix: Int64;
  Begin
  Result := DateTimeToUnix(LocalTimeToUniversal(Now));
  End;


Function QwkNodeLoad(Const UserName: String; Var Code: Integer; Var Err: String): Boolean;
  {the user record is loaded in User (MKDoor) when it is a QWK node and not deleted}
  Begin
  Result := False;
  Code := 403;
  Err := 'the token is not the token of a QWK node';
  If UserName = '' Then
    Exit;
  User.Init;
  User.SetUserBbsType(1);
  User.GetUserPos(UserName);
  If Not User.UserFound Then
    Exit;
  User.ReadUser;
  If (User.UserInfo^.ExitInfo.User.Attr And 1) <> 0 Then            {1 = uaDeleted}
    Exit;
  If Not User.GetUserQwkNode Then
    Exit;
  Prompts.Init;                       {the library calls ask for prompt texts (a screen of the caller would show them): the language file, so that a missing string is empty}
  Prompts.Load(Config^.FindBbsFile(Config^.GetLangFile(1) + '.lc') + Config^.GetLangFile(1) + '.lc');
  StartUpPath := GetCurrentDir;
  Code := 200;
  Err := '';
  Result := True;
  End;


Function TakeLock(Const Dir: String): Boolean;
  Begin
  ForceDirectories(Dir);
  LockFd := fpOpen(PChar(Dir + '.lock'), O_RDWR Or O_CREAT, &600);
  Result := (LockFd >= 0) And (fpFlock(LockFd, LOCK_EX Or LOCK_NB) = 0);
  End;


Procedure DropLock;
  Begin
  If LockFd >= 0 Then
    Begin
    fpFlock(LockFd, LOCK_UN);
    fpClose(LockFd);
    LockFd := -1;
    End;
  End;


Function ReadStateFile(Const FN: String; L: TStringList): Boolean;
  Begin
  Result := FileExists(FN);
  If Result Then
    L.LoadFromFile(FN);
  End;


Function StateValue(L: TStringList; Const Key: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 0 To L.Count - 1 Do
    If Copy(L[i], 1, Length(Key) + 1) = Key + ' ' Then
      Result := Copy(L[i], Length(Key) + 2, 500);
  End;


Procedure Ledger(Const Dir, Id, What: String; Msgs: LongInt; KeepDays: Int64);
  {acked.log: id, what (acked, expired, conflict), time, messages; lines older than keep_days go}
  Var
    L: TStringList;
    i: Integer;
    T: Int64;

  Begin
  L := TStringList.Create;
  Try
    If FileExists(Dir + 'acked.log') Then
      L.LoadFromFile(Dir + 'acked.log');
    For i := L.Count - 1 DownTo 0 Do
      Begin
      T := StrToInt64Def(Copy(L[i], Pos(' ', Copy(L[i], Pos(' ', L[i]) + 1, 200)) + Pos(' ', L[i]) + 1, 20), 0);
      If (T > 0) And (NowUnix - T > (KeepDays + 1) * 86400) Then
        L.Delete(i);
      End;
    If Id <> '' Then
      L.Add(Id + ' ' + What + ' ' + IntToStr(NowUnix) + ' ' + IntToStr(Msgs));
    L.SaveToFile(Dir + 'acked.log');
  Finally
    L.Free;
  End;
  End;


Function LedgerStatus(Const Dir, Id: String; Var Msgs: LongInt): String;
  Var
    L: TStringList;
    i: Integer;
    P: TStringList;

  Begin
  Result := '';
  Msgs := 0;
  If Not FileExists(Dir + 'acked.log') Then
    Exit;
  L := TStringList.Create;
  P := TStringList.Create;
  Try
    L.LoadFromFile(Dir + 'acked.log');
    P.Delimiter := ' ';
    P.StrictDelimiter := True;
    For i := 0 To L.Count - 1 Do
      Begin
      P.DelimitedText := L[i];
      If (P.Count >= 4) And (P[0] = Id) Then
        Begin
        Result := P[1];
        Msgs := StrToIntDef(P[3], 0);
        End;
      End;
  Finally
    P.Free;
    L.Free;
  End;
  End;


Procedure DropWaiting(Const Dir: String);
  Begin
  DeleteFile(Dir + 'waiting.qwk');
  DeleteFile(Dir + 'waiting.state');
  End;


Procedure ExpireWaiting(Const Dir: String; KeepDays: Int64);
  Var
    L: TStringList;
    T: Int64;

  Begin
  L := TStringList.Create;
  Try
    If ReadStateFile(Dir + 'waiting.state', L) Then
      Begin
      T := StrToInt64Def(StateValue(L, 'created'), 0);
      If (T = 0) Or (NowUnix - T > KeepDays * 86400) Or Not FileExists(Dir + 'waiting.qwk') Then
        Begin
        Ledger(Dir, StateValue(L, 'id'), 'expired', StrToIntDef(StateValue(L, 'messages'), 0), KeepDays);
        DropWaiting(Dir);
        End;
      End;
  Finally
    L.Free;
  End;
  End;


Function FileHash(Const FN: String; Var Size: Int64): String;
  Var
    Fs: TFileStream;
    S: String;

  Begin
  Fs := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
  Try
    Size := Fs.Size;
    SetLength(S, Fs.Size);
    If Fs.Size > 0 Then
      Fs.ReadBuffer(S[1], Fs.Size);
  Finally
    Fs.Free;
  End;
  Result := Copy(HashToken(S), 8, 64);
  End;


Function NewId: String;
  Var
    Fs: TFileStream;
    B: Array[0..5] Of Byte;
    i: Integer;

  Begin
  Fs := TFileStream.Create('/dev/urandom', fmOpenRead);
  Try
    Fs.ReadBuffer(B, SizeOf(B));
  Finally
    Fs.Free;
  End;
  Result := '';
  For i := 0 To 5 Do
    Result := Result + LowerCase(IntToHex(B[i], 2));
  End;


Procedure CopyFileTo(Const From, To_: String);
  Var
    S, D: TFileStream;

  Begin
  S := TFileStream.Create(From, fmOpenRead Or fmShareDenyNone);
  Try
    D := TFileStream.Create(To_, fmCreate);
    Try
      D.CopyFrom(S, 0);
    Finally
      D.Free;
    End;
  Finally
    S.Free;
  End;
  End;


Function QwkInfo(Const UserName: String; MaxPacket, MaxReply, KeepDays: Int64): TJSONObject;
  Var
    O, W, Lim: TJSONObject;
    Arr: TJSONArray;
    C: TJSONObject;
    i: Integer;
    L: TStringList;
    Dir: String;

  Begin
  Result := TJSONObject.Create;
  Result.Add('node', UserName);
  Result.Add('bbs_id', Config^.GetBBSID);
  Result.Add('packet_type', UpCase(User.GetUserOffType));
  Arr := TJSONArray.Create;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If (Config^.GetMsgName(i) <> '') And ((User.GetUserOffline(i) And Config^.GetMsgAllowOffline(i)) Or Config^.GetMsgForceOffline(i)) Then
      Begin
      C := TJSONObject.Create;
      C.Add('conference', i);
      C.Add('name', Cp437Str(Config^.GetMsgName(i)));
      Arr.Add(C);
      End;
  Result.Add('conferences', Arr);
  Lim := TJSONObject.Create;
  Lim.Add('max_packet', MaxPacket);
  Lim.Add('max_reply', MaxReply);
  Lim.Add('keep_days', KeepDays);
  Lim.Add('messages_per_packet', User.GetUserOffMax);
  Result.Add('limits', Lim);
  Dir := NodeDir(UserName);
  O := Nil;
  If TakeLock(Dir) Then
    Begin
    ExpireWaiting(Dir, KeepDays);
    L := TStringList.Create;
    Try
      If ReadStateFile(Dir + 'waiting.state', L) Then
        Begin
        W := TJSONObject.Create;
        W.Add('id', StateValue(L, 'id'));
        W.Add('messages', StrToIntDef(StateValue(L, 'messages'), 0));
        W.Add('bytes', StrToInt64Def(StateValue(L, 'bytes'), 0));
        W.Add('since', IsoFromUnix(StrToInt64Def(StateValue(L, 'created'), 0)));
        O := W;
        End;
    Finally
      L.Free;
    End;
    DropLock;
    End;
  If O <> Nil Then
    Result.Add('waiting', O)
  Else
    Result.Add('waiting', TJSONNull.Create);
  End;


Procedure QwkPacket(Const UserName: String; Rebuild: Boolean; MaxPacket, KeepDays: Int64; Var Res: TQwkRes);
  Var
    Dir, Work: String;
    L: TStringList;
    B: OffBuild;
    rc, Tries, i: Integer;
    Limit: LongInt;
    Size: Int64;
    Sha: String;

  Begin
  FillChar(Res, SizeOf(Res), 0);
  Res.Code := 500;
  Dir := NodeDir(UserName);
  If Not TakeLock(Dir) Then
    Begin
    Res.Code := 423;
    Res.Err := 'another request of this node is running';
    Exit;
    End;
  L := TStringList.Create;
  Try
    ExpireWaiting(Dir, KeepDays);
    If Rebuild Then
      DropWaiting(Dir);
    If ReadStateFile(Dir + 'waiting.state', L) And FileExists(Dir + 'waiting.qwk') Then
      Begin                              {the same packet again}
      Res.Code := 200;
      Res.Id := StateValue(L, 'id');
      Res.Messages := StrToIntDef(StateValue(L, 'messages'), 0);
      Res.Bytes := StrToInt64Def(StateValue(L, 'bytes'), 0);
      Res.Sha := StateValue(L, 'sha256');
      Res.FilePath := Dir + 'waiting.qwk';
      Exit;
    End;
    Work := CreateTempDir(Config^.GetTempPath);
    If Work = '' Then
      Begin
      Res.Err := 'no temporary folder';
      Exit;
      End;
    Limit := 0;
    Tries := 0;
    Repeat
      Inc(Tries);
      rc := OfflineBuildPacket(Work, Limit, B);
      If rc = 0 Then
        Begin
        Size := 0;
        FileHash(B.ArcPath, Size);
        If (Size > MaxPacket) Then
          Begin
          If B.Messages <= 1 Then
            Begin
            rc := 2;
            B.Why := 'a single message does not fit in a packet of ' + IntToStr(MaxPacket) + ' bytes';
            Res.Code := 413;
            End
          Else
            Begin                        {what does not fit stays for the next packet}
            Limit := B.Messages Div 2;
            CleanDir(WithBackSlash(Work));
            rc := -1;
            End;
          End;
        End;
    Until (rc >= 0) Or (Tries > 8);
    If rc = 1 Then
      Res.Code := 204
    Else If rc = 0 Then
      Begin
      Sha := FileHash(B.ArcPath, Size);
      CopyFileTo(B.ArcPath, Dir + 'waiting.qwk');
      Res.Id := NewId;
      L.Clear;
      L.Add('id ' + Res.Id);
      L.Add('created ' + IntToStr(NowUnix));
      L.Add('messages ' + IntToStr(B.Messages));
      L.Add('bytes ' + IntToStr(Size));
      L.Add('sha256 ' + Sha);
      L.Add('user ' + UserName);
      For i := 1 To OffAreas Do
        If B.R.NewLR[i] >= 0 Then
          L.Add('lr ' + IntToStr(i) + ' ' + IntToStr(OffUserLR(i)) + ' ' + IntToStr(B.R.NewLR[i]));
      L.SaveToFile(Dir + 'waiting.state');
      Res.Code := 200;
      Res.Messages := B.Messages;
      Res.Bytes := Size;
      Res.Sha := Sha;
      Res.FilePath := Dir + 'waiting.qwk';
      End
    Else If Res.Code <> 413 Then
      Begin
      Res.Code := 500;
      Res.Err := B.Why;
      End
    Else
      Res.Err := B.Why;
    CleanDir(WithBackSlash(Work));
    RmDir(ExcludeTrailingPathDelimiter(Work));
    If IOResult <> 0 Then;
  Finally
    L.Free;
    DropLock;
  End;
  End;


Procedure QwkAck(Const UserName, Id: String; KeepDays: Int64; Var Res: TQwkRes);
  Var
    Dir, St: String;
    L, P: TStringList;
    i, Area: Integer;
    Before, New_: LongInt;
    Conflict: Boolean;
    Msgs: LongInt;

  Begin
  FillChar(Res, SizeOf(Res), 0);
  Dir := NodeDir(UserName);
  If Not TakeLock(Dir) Then
    Begin
    Res.Code := 423;
    Res.Err := 'another request of this node is running';
    Exit;
    End;
  L := TStringList.Create;
  P := TStringList.Create;
  P.Delimiter := ' ';
  P.StrictDelimiter := True;
  Try
    ExpireWaiting(Dir, KeepDays);
    Res.Id := Id;
    If ReadStateFile(Dir + 'waiting.state', L) And (StateValue(L, 'id') = Id) Then
      Begin
      Conflict := False;
      For i := 0 To L.Count - 1 Do
        If Copy(L[i], 1, 3) = 'lr ' Then
          Begin
          P.DelimitedText := L[i];
          Area := StrToIntDef(P[1], 0);
          Before := StrToIntDef(P[2], 0);
          If (Area > 0) And (OffUserLR(Area) <> Before) Then
            Conflict := True;
          End;
      Msgs := StrToIntDef(StateValue(L, 'messages'), 0);
      If Conflict Then
        Begin
        DropWaiting(Dir);
        Ledger(Dir, Id, 'conflict', Msgs, KeepDays);
        Res.Code := 409;
        Res.Err := 'the pointers of the node changed since the packet was made: nothing was moved and the packet is dropped; ask for a new one';
        Exit;
        End;
      For i := 0 To L.Count - 1 Do
        If Copy(L[i], 1, 3) = 'lr ' Then
          Begin
          P.DelimitedText := L[i];
          Area := StrToIntDef(P[1], 0);
          New_ := StrToIntDef(P[3], 0);
          If Area > 0 Then
            OffSetUserLR(Area, New_);
          End;
      DropWaiting(Dir);
      Ledger(Dir, Id, 'acked', Msgs, KeepDays);
      Res.Code := 200;
      Res.Messages := Msgs;
      Exit;
      End;
    St := LedgerStatus(Dir, Id, Msgs);
    If St = 'acked' Then
      Begin
      Res.Code := 200;
      Res.Already := True;
      Res.Messages := Msgs;
      End
    Else If St = 'expired' Then
      Begin
      Res.Code := 410;
      Res.Err := 'the packet expired before it was acknowledged';
      End
    Else If St = 'conflict' Then
      Begin
      Res.Code := 409;
      Res.Err := 'that packet was dropped because the pointers of the node had changed';
      End
    Else
      Begin
      Res.Code := 404;
      Res.Err := 'no such packet is waiting';
      End;
  Finally
    P.Free;
    L.Free;
    DropLock;
  End;
  End;

{------------------------------------------------------------ the reply packet}

Const
  MaxConf = 2000;

Type
  TConfCount = Record
    Posted, Dupes, Grunged, Moved, Refused, Failed: LongInt;
    Seen: Boolean;
    End;

Var
  ConfStats: Array[0..MaxConf] Of TConfCount;
  CmdLines: TStringList;


Procedure ReplyNote(Code: Word; Conf: LongInt; Msg: AbsMsgPtr);
  Begin
  If (Conf < 0) Or (Conf > MaxConf) Then
    Exit;
  ConfStats[Conf].Seen := True;
  Case Code Of
    qiPosted: Inc(ConfStats[Conf].Posted);
    qiDupe: Inc(ConfStats[Conf].Dupes);
    qiGrunged: Inc(ConfStats[Conf].Grunged);
    qiMoved: Inc(ConfStats[Conf].Moved);
    qiRefused: Inc(ConfStats[Conf].Refused);
    qiFailed: Inc(ConfStats[Conf].Failed);
    End;
  End;


Procedure ReplySink(S: ShortString);
  {the text the import would show the caller: the control messages say what they did ("ADD 12: done")}
  Begin
  S := Trim(S);
  If (S <> '') And ((Pos(': done', S) > 0) Or (Pos(': not done', S) > 0) Or (Pos(': ignored', S) > 0)) Then
    CmdLines.Add(S);
  End;


Function ReplyHash(Const FN: String): String;
  Begin
  Result := LowerCase(SHA1Print(SHA1File(FN)));
  End;


Function ReplyLedgerStatus(Const Dir, Hash: String; Var Posted: LongInt): String;
  Var
    L, P: TStringList;
    i: Integer;

  Begin
  Result := '';
  Posted := 0;
  If Not FileExists(Dir + 'reply.ledger') Then
    Exit;
  L := TStringList.Create;
  P := TStringList.Create;
  Try
    L.LoadFromFile(Dir + 'reply.ledger');
    P.Delimiter := ' ';
    P.StrictDelimiter := True;
    For i := 0 To L.Count - 1 Do
      Begin
      P.DelimitedText := L[i];
      If (P.Count >= 4) And (P[0] = Hash) Then
        Begin
        Result := P[1];
        Posted := StrToIntDef(P[3], 0);
        End;
      End;
  Finally
    P.Free;
    L.Free;
  End;
  End;


Procedure ReplyLedgerSet(Const Dir, Hash, Status: String; Posted: LongInt; KeepDays: Int64);
  {one line for each packet: hash, started or done, time, messages posted; the lines of the last max(30, 4 * keep_days) days stay}
  Var
    L, P: TStringList;
    i: Integer;
    T, Keep: Int64;

  Begin
  L := TStringList.Create;
  P := TStringList.Create;
  P.Delimiter := ' ';
  P.StrictDelimiter := True;
  Try
    If FileExists(Dir + 'reply.ledger') Then
      L.LoadFromFile(Dir + 'reply.ledger');
    Keep := KeepDays * 4;
    If Keep < 30 Then
      Keep := 30;
    For i := L.Count - 1 DownTo 0 Do
      Begin
      P.DelimitedText := L[i];
      T := 0;
      If P.Count >= 3 Then
        T := StrToInt64Def(P[2], 0);
      If (P.Count >= 1) And ((P[0] = Hash) Or ((T > 0) And (NowUnix - T > Keep * 86400))) Then
        L.Delete(i);
      End;
    L.Add(Hash + ' ' + Status + ' ' + IntToStr(NowUnix) + ' ' + IntToStr(Posted));
    L.SaveToFile(Dir + 'reply.ledger');
  Finally
    P.Free;
    L.Free;
  End;
  End;


Function QwkReply(Const UserName, BodyFile: String; KeepDays: Int64; CrashTest: Boolean; Var Res: TQwkRes; Var Answer: TJSONObject): Boolean;
  Var
    Dir, Work, Hash, St: String;
    Posted: LongInt;
    Offline: QwkOffPtr;
    Cmds: OffCmdList;
    NumCmds, k, i: Word;
    ci: Integer;
    ImpO: OffImportOpts;
    Magic: Array[0..1] Of Char;
    Fs: TFileStream;
    Areas, Cmd: TJSONArray;
    A: TJSONObject;
    Total: LongInt;

  Begin
  Result := False;
  FillChar(Res, SizeOf(Res), 0);
  Answer := Nil;
  Res.Code := 500;
  Dir := NodeDir(UserName);
  If Not TakeLock(Dir) Then
    Begin
    Res.Code := 423;
    Res.Err := 'another request of this node is running';
    Exit;
    End;
  Try
    { a ZIP, and the same packet only once }
    Magic[0] := #0;
    Magic[1] := #0;
    Fs := TFileStream.Create(BodyFile, fmOpenRead);
    Try
      If Fs.Size >= 2 Then
        Fs.ReadBuffer(Magic, 2);
    Finally
      Fs.Free;
    End;
    If (Magic[0] <> 'P') Or (Magic[1] <> 'K') Then
      Begin
      Res.Code := 415;
      Res.Err := 'the body is not a ZIP file (a reply packet is <BBSID>.REP, a ZIP)';
      Exit;
      End;
    Hash := ReplyHash(BodyFile);
    St := ReplyLedgerStatus(Dir, Hash, Posted);
    If St = 'done' Then
      Begin
      Answer := TJSONObject.Create;
      Answer.Add('status', 'duplicate');
      Answer.Add('posted', Posted);
      Answer.Add('note', 'this reply packet was imported before: nothing was posted again');
      Res.Code := 200;
      Result := True;
      Exit;
      End;
    If St = 'started' Then
      Begin
      Res.Code := 409;
      Res.Err := 'an earlier upload of this packet did not finish: nothing is posted again; the sysop must look at the log and at ' + Dir + 'reply.ledger';
      Exit;
      End;
    { unpack it in a work folder of its own }
    Work := CreateTempDir(Config^.GetTempPath);
    If Work = '' Then
      Begin
      Res.Err := 'no temporary folder';
      Exit;
      End;
    Try
      Offline := New(QwkOffPtr, Init);
      Offline^.SetBBSId(Config^.GetBBSID);
      Offline^.SetPath(Work);
      CopyFileTo(BodyFile, WithBackSlash(Work) + 'upload.1');
      OffRenameUploads(Work);
      NumCmds := 0;
      k := GetUserPackerNum;
      FillChar(Cmds, SizeOf(Cmds), 0);
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
      If Not OffUnpackReply(Offline, Work, StartUpPath, Cmds, NumCmds) Then
        Begin
        Dispose(Offline, Done);
        Res.Code := 400;
        Res.Err := 'this is not a reply packet for ' + Config^.GetBBSID + ' (no ' + Config^.GetBBSID + '.MSG in it, or it cannot be unpacked)';
        Exit;
        End;
      { the import: the ledger says it was started before anything is posted }
      ReplyLedgerSet(Dir, Hash, 'started', 0, KeepDays);
      If CrashTest Then
        Halt(3);
      FillChar(ConfStats, SizeOf(ConfStats), 0);
      CmdLines := TStringList.Create;
      OffImpHook := @ReplyNote;
      OffImpSink := @ReplySink;
      ImpO.BadArea := Config^.GetBadMsgArea;
      ImpO.ForceName := Not User.GetUserQwkNode;
      ImpO.ReDate := Config^.GetOffReDate;
      ImpO.DupeFile := WithBackSlash(Config^.GetMsgPath(1)) + 'qwkdupe.dat';
      Offline^.SetImportOpts(ImpO);
      Offline^.ImportPacket;
      User.WriteUser;                    {the control messages changed the user's offline areas and the counts: the record is saved as mk does when a call ends}
      OffImpHook := Nil;
      OffImpSink := Nil;
      Posted := Offline^.GetImported;
      Dispose(Offline, Done);
      ReplyLedgerSet(Dir, Hash, 'done', Posted, KeepDays);
      Answer := TJSONObject.Create;
      Answer.Add('status', 'imported');
      Answer.Add('posted', Posted);
      Areas := TJSONArray.Create;
      Total := 0;
      For i := 0 To MaxConf Do
        If ConfStats[i].Seen And (ConfStats[i].Posted + ConfStats[i].Dupes + ConfStats[i].Grunged + ConfStats[i].Moved + ConfStats[i].Refused + ConfStats[i].Failed > 0) Then
          Begin
          A := TJSONObject.Create;
          A.Add('conference', i);
          If (i >= 1) And (i <= Config^.GetMaxMsgAreas) And (Config^.GetMsgName(i) <> '') Then
            A.Add('area', Cp437Str(Config^.GetMsgName(i)))
          Else
            A.Add('area', TJSONNull.Create);
          A.Add('posted', ConfStats[i].Posted);
          A.Add('duplicates', ConfStats[i].Dupes);
          A.Add('moved_to_bad_area', ConfStats[i].Moved);
          A.Add('skipped', ConfStats[i].Grunged);
          A.Add('refused', ConfStats[i].Refused);
          A.Add('failed', ConfStats[i].Failed);
          If ConfStats[i].Refused > 0 Then
            A.Add('reason', 'the node may not post in this conference (no such area, or no write access)')
          Else
            A.Add('reason', '');
          Inc(Total, ConfStats[i].Refused);
          Areas.Add(A);
          End;
      Answer.Add('areas', Areas);
      Answer.Add('refused', Total);
      Cmd := TJSONArray.Create;
      For ci := 0 To CmdLines.Count - 1 Do
        Cmd.Add(CmdLines[ci]);
      Answer.Add('commands', Cmd);
      CmdLines.Free;
      Res.Code := 200;
      Result := True;
    Finally
      CleanDir(WithBackSlash(Work));
      RmDir(ExcludeTrailingPathDelimiter(Work));
      If IOResult <> 0 Then;
    End;
  Finally
    DropLock;
  End;
  End;

End.
