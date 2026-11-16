Program MKToss;

{$I MKB.Def}

{
     mktoss [-q] [-t | -s] [-f] [-b mkbink] [file ...]

     The mail tosser: takes the mail that came in (the inbound directory of EchoMail Options) into
     the message areas of the BBS.  Which BBS it works for comes from the environment variable MK, as
     for mk and mkconfig.

     - bundles (the files a mailer receives: *.mo?, *.tu?, *.we? ... *.su?) are unpacked with the
       unpacker of the matching archiver (EchoMail > Archivers) in a work directory
     - the packets (*.pkt) are read with MKMsgPkt, from systems of the echo systems list only
     - echomail (AREA:) goes to the area whose EchoMail tag is the area, if the system sending it is
       linked to that area; duplicates (the same MSGID) are dropped
     - netmail for one of our addresses goes to the first netmail area; netmail for another address is
       stored there too (not sent, not for us: the scanner sends it on)
     - what cannot be tossed (unknown system, unknown area, system not linked to the area, damaged
       packet) goes to bad/bad.pkt in the inbound directory, a bad packet is renamed .bad
     - what was tossed is deleted
     - echomail that other systems are linked to is passed on (SEEN-BY and PATH brought up to date), and what the
       BBS wrote itself (local, unexported messages of the echo areas) is scanned and sent; netmail that is not
       sent and not for us is sent on: direct to a system in the list, to the boss of a point, else by the first
       route (EchoMail > Routing) that fits; with no route it stays where it is (logged)
     - the outgoing packets are packed with the archiver of the system and given to the mailer: mkbink queue puts
       them in the BSO outbound with the flavour of the system (crash, hold ... for netmail as the message says)

       -t   only toss (and pass on), no scan       -s   only scan (and pack), no toss
       -b   the mkbink program (default: next to mktoss, else in the path)
       -f   run although the tosser is not switched on (EchoMail > Mailer > Tosser); without it mktoss does nothing then
            and says so (exit status 3), so a cron job or the mailer's hook can call it all the time

     File names given (as the mailer's on-inbound hook does) are ignored: the whole inbound is tossed.  Runs one at a
     time: a second mktoss waits until the first is done (lock file mktoss.lock in the inbound directory).

     - file attach: a netmail with the file attach flag names its files in the subject (^ in front: delete after sent,
       # : truncate; names without a path are in the file attach directory, General > Paths).  They are queued with
       the netmail (mkbink queue), the packet carries the plain names.  Files that arrive with a file attach netmail are
       moved from the inbound to the attach directory (the name in the subject, found without regard to case); for mail
       that only passes through, the stored subject gets a ^ so the file is deleted once it was sent on.
     - packet passwords: when an echo system has one (EchoMail > Systems > Packet pwd, kept in Mailer.Mk), its packets
       must carry it (else the packet is refused and renamed .bad) and ours carry it
     - areafix: netmail for us to Areafix / AreaMgr from an echo system, with the system's areafix password as the
       subject; commands %LIST %QUERY %UNLINKED %HELP, +AREA, -AREA (* and ? work, a bare AREA links it), nothing after
       a --- line; the links go into echocfg.mk and the answer is a netmail back.  An area that comes from our hub
       (the area's Hub) is asked for from the hub when the first system takes it, and given up when the last one goes
       (pass-through areas).  A wrong password gets an answer saying so; a request from a sender that is not a system
       of ours is left in the netmail area for the sysop.

     Mail in the unsecure inbound (callers without a password) is not tossed, only counted.

     Exit status: 0 = done, 1 = could not start (no configuration), 2 = some mail could not be tossed or sent,
     3 = the tosser is not switched on.
}

Uses
  BaseUnix, Unix, Dos, MKString, MKGlobT, MKFile, MKCfgAbs, MKCfgMK, MKMsgAbs, MKMsgPkt, MKOpen, MKDupe, Crc32;


Type
  NameList = Array[1..512] Of String[80];

Var
  Quiet: Boolean;
  InDir, WorkDir, BadName: String;
  Ours: Array[1..10] Of AddrType;
  NumOurs: Word;
  Dupes: DupeObj;
  DupesOpen: Boolean;
  Tossed, Dups, Bad, Netmails, Passed: LongInt;
  Problems: Boolean;
  LogName: String;
  OutDir, SpoolDir, BinkProg: String;
  Forwarded, Scanned, NetSent: LongInt;
  LastSerial: LongInt;
  DoToss, DoScan: Boolean;
  MailCfg: ^MailerCfgType;
  HaveMail: Boolean;
  Areafixes: LongInt;
  Force: Boolean;
  BbsPath, AttachDir: String;


{---------------------------------------------------------------- log}

Procedure Log(S: String);
  Var
    T: Text;
    Y, Mo, D, Dow, H, Mi, Se, Hs: Word;
    Stamp: String;

  Begin
  GetDate(Y, Mo, D, Dow);
  GetTime(H, Mi, Se, Hs);
  Stamp := Long2Str(Y) + '-' + PadLeft(Long2Str(Mo), '0', 2) + '-' + PadLeft(Long2Str(D), '0', 2) + ' ' +
    PadLeft(Long2Str(H), '0', 2) + ':' + PadLeft(Long2Str(Mi), '0', 2) + ':' + PadLeft(Long2Str(Se), '0', 2);
  If Not Quiet Then
    WriteLn(Stamp, '  ', S);
  If LogName <> '' Then
    Begin
    Assign(T, LogName);
    {$I-}
    Append(T);
    If IoResult <> 0 Then
      ReWrite(T);
    If IoResult = 0 Then
      Begin
      WriteLn(T, Stamp, '  ', S);
      Close(T);
      End;

    If IoResult <> 0 Then;
    End;
  End;


{---------------------------------------------------------------- addresses and areas}

Function PktPwdOf(Sys: Word): String;
  {the packet password of the echo system (Mailer.Mk), '' = none}
  Begin
  If HaveMail And (Sys >= 1) And (Sys <= 32) Then
    PktPwdOf := StripBoth(MailCfg^.PktPwd[Sys], ' ')
  Else
    PktPwdOf := '';
  End;


Function SameAddr(Var A, B: AddrType): Boolean;
  Begin
  SameAddr := (A.Zone = B.Zone) And (A.Net = B.Net) And (A.Node = B.Node) And (A.Point = B.Point);
  End;


Function IsOurs(Var A: AddrType): Boolean;
  Var
    i: Word;

  Begin
  IsOurs := False;
  For i := 1 To NumOurs Do
    If SameAddr(A, Ours[i]) Then
      IsOurs := True;
  End;


Function FindSystem(Var A: AddrType): Word;
  {the index in the echo systems list, 0 = none}
  Var
    i: Word;
    B: AddrType;

  Begin
  FindSystem := 0;
  For i := 1 To 32 Do
    Begin
    Config^.GetEchoToAddr(i, B);
    If (B.Zone <> 0) And SameAddr(A, B) Then
      Begin
      FindSystem := i;
      Exit;
      End;
    End;
  End;


Function FindEchoArea(Tag: String): Word;
  Var
    i: Word;
    U: String;

  Begin
  FindEchoArea := 0;
  U := Upper(StripBoth(Tag, ' '));
  If U = '' Then
    Exit;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If (Config^.GetMsgType(i) = EchoMail) And (Upper(StripBoth(Config^.GetEchoAreaTag(i), ' ')) = U) Then
      Begin
      FindEchoArea := i;
      Exit;
      End;
  End;


Function FindNetmailArea: Word;
  Var
    i: Word;

  Begin
  FindNetmailArea := 0;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If (Config^.GetMsgName(i) <> '') And (Config^.GetMsgType(i) = NetMail) Then
      Begin
      FindNetmailArea := i;
      Exit;
      End;
  End;


{---------------------------------------------------------------- duplicates}

Function IsDupe(Tag, MsgId, From, ToN, Subj, Date, Time: String): Boolean;
  Var
    S: String;
    C: LongInt;
    i: Word;

  Begin
  If MsgId <> '' Then
    S := Upper(Tag) + #0 + MsgId
  Else
    S := Upper(Tag) + #0 + From + #0 + ToN + #0 + Subj + #0 + Date + #0 + Time;
  C := -1;
  For i := 1 To Length(S) Do
    C := UpdC32(Ord(S[i]), C);
  IsDupe := Dupes.DupeCheck(C);
  End;


{---------------------------------------------------------------- bad mail}

Procedure BadMessage(Var Src: PktMsgObj; Why: String);
  {the message is kept in bad/bad.pkt in the inbound directory}
  Var
    B: PktMsgObj;
    PO, PD: AddrType;
    c: Char;
    Line: String;
    E: Word;

  Begin
  Inc(Bad);
  Problems := True;
  Log('bad message #' + Long2Str(Src.GetMsgNum) + ' from ' + Src.GetFrom + ' to ' + Src.GetTo + ': ' + Why);
  B.Init;
  B.SetMsgPath(BadName);
  Src.GetPktOrig(PO);
  Src.GetPktDest(PD);
  B.SetPacketInfo(PO, PD, '');
  B.StartNewMsg;
  B.SetFrom(Src.GetFrom);
  B.SetTo(Src.GetTo);
  B.SetSubj(Src.GetSubj);
  B.SetDate(Src.GetDate);
  B.SetTime(Src.GetTime);
  B.SetCost(Src.GetCost);
  B.SetEchoTail(False);
  If Src.GetArea <> '' Then
    Begin
    B.SetMailType(mmtEchoMail);
    B.SetArea(Src.GetArea);
    End
  Else
    Begin
    B.SetMailType(mmtNetMail);
    Src.GetOrig(PO);
    Src.GetDest(PD);
    B.SetOrig(PO);
    B.SetDest(PD);
    End;
  If Src.GetMsgId <> '' Then
    B.SetMsgId(Src.GetMsgId);
  B.SetPriv(Src.IsPriv);
  Src.MsgTxtStartUp;
  c := Src.GetChar;
  While Not Src.EOM Do
    Begin
    B.DoChar(c);
    c := Src.GetChar;
    End;
  E := B.WriteMsg;
  If E <> 0 Then
    Log('cannot write ' + BadName + ' (error ' + Long2Str(E) + ')');
  B.Done;
  End;


{---------------------------------------------------------------- storing a message}

Function StoreMessage(Var Src: PktMsgObj; Area: Word; Echo: Boolean; Subj: String): Word;
  {Copies the current message of the packet into the message area.  0 = stored.}
  Var
    Dst: AbsMsgPtr;
    c: Char;
    Line: String;
    A: AddrType;
    Res: Word;
    KeepSeen, KeepPath, HideSeen, HidePath: Boolean;
    TextOk: Boolean;

  Procedure PutLine(Ln: String; HasCr: Boolean);
    {kludge lines go to DoKludgeLn with their ^A (a base that has no kludge storage keeps the line as it is)}
    Var
      U: String;

    Begin
    If (Length(Ln) > 0) And (Ln[1] = #1) Then
      Begin
      U := Upper(Copy(Ln, 2, 8));
      If (Copy(U, 1, 5) = 'INTL ') Or (Copy(U, 1, 5) = 'FMPT ') Or (Copy(U, 1, 5) = 'TOPT ') Then
        Exit;                              {the base makes these from the addresses}
      If Echo And (Copy(U, 1, 8) = 'SEEN-BY:') Then
        Begin
        If KeepSeen Then
          Begin
          If HideSeen Then
            Dst^.DoKludgeLn(Ln)
          Else
            Dst^.DoStringLn(Copy(Ln, 2, 255));
          End;
        Exit;
        End;
      If Echo And (Copy(U, 1, 5) = 'PATH:') Then
        Begin
        If KeepPath Then
          Begin
          If HidePath Then
            Dst^.DoKludgeLn(Ln)
          Else
            Dst^.DoStringLn(Copy(Ln, 2, 255));
          End;
        Exit;
        End;
      Dst^.DoKludgeLn(Ln);
      Exit;
      End;
    Dst^.DoString(Ln);
    If HasCr Then
      Dst^.DoChar(#13);
    End;

  Begin
  StoreMessage := 1;
  Dst := Nil;
  If Not OpenMsgArea(Dst, Config^.GetMsgAreaId(Area)) Then
    Begin
    Log('cannot open message area ' + Long2Str(Area) + ' (' + Config^.GetMsgName(Area) + ')');
    Exit;
    End;
  KeepSeen := Config^.GetEchoAreaImportSeen(Area);
  KeepPath := Config^.GetEchoAreaImportPath(Area);
  HideSeen := Config^.GetEchoAreaHideSeen(Area);
  HidePath := Config^.GetEchoAreaHidePath(Area);
  If Echo Then
    Dst^.SetMailType(mmtEchoMail)
  Else
    Dst^.SetMailType(mmtNetMail);
  Dst^.StartNewMsg;
  If Not Echo Then
    Begin
    Src.GetDest(A);
    Dst^.SetDest(A);
    Src.GetOrig(A);
    Dst^.SetOrig(A);
    End;
  Dst^.SetFrom(Src.GetFrom);
  Dst^.SetTo(Src.GetTo);
  Dst^.SetSubj(Subj);
  Dst^.SetDate(Src.GetDate);
  Dst^.SetTime(Src.GetTime);
  Dst^.SetCost(Src.GetCost);
  Dst^.SetPriv(Src.IsPriv);
  Dst^.SetCrash(Src.IsCrash);
  Dst^.SetKillSent(Src.IsKillSent);
  Dst^.SetFAttach(Src.IsFAttach);
  Dst^.SetFileReq(Src.IsFileReq);
  Dst^.SetReqRct(Src.IsReqRct);
  Dst^.SetRetRct(Src.IsRetRct);
  Dst^.SetReqAud(Src.IsReqAud);
  Dst^.SetHold(Src.IsHold);
  Dst^.SetLocal(False);
  Dst^.SetRcvd(False);
  Dst^.SetSent(False);
  Dst^.SetEcho(False);                     {not to be exported: it came from outside; netmail for another system is
                                            exported by the scanner because it is not sent and not for us}
  {the text, line by line}
  Src.MsgTxtStartUp;
  Line := '';
  c := Src.GetChar;
  While Not Src.EOM Do
    Begin
    If c = #13 Then
      Begin
      PutLine(Line, True);
      Line := '';
      End
    Else
      Begin
      If Length(Line) >= 250 Then
        Begin
        PutLine(Line, False);
        Line := '';
        End;
      Line := Line + c;
      End;
    c := Src.GetChar;
    End;
  If Line <> '' Then
    PutLine(Line, True);
  Res := Dst^.WriteMsg;
  If Res <> 0 Then
    Log('cannot write to message area ' + Long2Str(Area) + ' (' + Config^.GetMsgName(Area) + '), error ' + Long2Str(Res));
  If Not CloseMsgArea(Dst) Then;
  StoreMessage := Res;
  End;




{---------------------------------------------------------------- a message kept in memory}

Const
  MaxSeen = 3000;
  MaxPath = 30;

Type
  SeenRec = Record
    Net: Word;
    Node: Word;
    End;
  SeenArr = Array[1..MaxSeen] Of SeenRec;
  MsgCopy = Record
    From, ToN: String[80];
    Subj: String[150];
    Date, Time: String[10];
    Cost: Word;
    Priv, Crash, KillSent, FAttach, FileReq, ReqRct, RetRct, ReqAud, Hold: Boolean;
    Orig, Dest: AddrType;
    Txt: PktBytePtr;
    TxtLen, TxtCap: LongInt;
    MsgId: String[200];
    NumSeen: Word;
    Seen: ^SeenArr;
    NumPath: Word;
    PathLn: Array[1..MaxPath] Of String[100];
    End;


Procedure CopyInit(Var C: MsgCopy);
  Begin
  FillChar(C, SizeOf(C), 0);
  New(C.Seen);
  End;


Procedure CopyFree(Var C: MsgCopy);
  Begin
  If C.Txt <> Nil Then
    FreeMem(C.Txt, C.TxtCap);
  C.Txt := Nil;
  If C.Seen <> Nil Then
    Dispose(C.Seen);
  C.Seen := Nil;
  End;


Procedure CopyAddByte(Var C: MsgCopy; B: Byte);
  Var
    NewBuf: PktBytePtr;
    NewCap: LongInt;

  Begin
  If C.TxtLen >= C.TxtCap Then
    Begin
    NewCap := C.TxtCap + C.TxtCap Div 2 + 4096;
    GetMem(NewBuf, NewCap);
    If C.Txt <> Nil Then
      Begin
      Move(C.Txt^, NewBuf^, C.TxtLen);
      FreeMem(C.Txt, C.TxtCap);
      End;
    C.Txt := NewBuf;
    C.TxtCap := NewCap;
    End;
  C.Txt^[C.TxtLen] := B;
  Inc(C.TxtLen);
  End;


Procedure CopyAddStr(Var C: MsgCopy; S: String);
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    CopyAddByte(C, Ord(S[i]));
  End;


Function SeenHas(Var C: MsgCopy; Net, Node: Word): Boolean;
  Var
    i: Word;

  Begin
  SeenHas := False;
  For i := 1 To C.NumSeen Do
    If (C.Seen^[i].Net = Net) And (C.Seen^[i].Node = Node) Then
      SeenHas := True;
  End;


Procedure SeenAdd(Var C: MsgCopy; Net, Node: Word);
  Begin
  If SeenHas(C, Net, Node) Or (C.NumSeen >= MaxSeen) Then
    Exit;
  Inc(C.NumSeen);
  C.Seen^[C.NumSeen].Net := Net;
  C.Seen^[C.NumSeen].Node := Node;
  End;


Procedure SeenParse(Var C: MsgCopy; Line: String);
  {"SEEN-BY: 110/100 290 301/5": the net is kept until the next one}
  Var
    p, q: Word;
    Tok: String;
    Net, Node: LongInt;
    Code: Integer;

  Begin
  p := Pos(':', Line);
  Line := StripBoth(Copy(Line, p + 1, 255), ' ') + ' ';
  Net := 0;
  While Length(Line) > 0 Do
    Begin
    q := Pos(' ', Line);
    Tok := Copy(Line, 1, q - 1);
    Line := StripBoth(Copy(Line, q + 1, 255), ' ');
    If Line <> '' Then
      Line := Line + ' ';
    If Tok = '' Then
      Continue;
    p := Pos('.', Tok);
    If p > 0 Then
      Tok := Copy(Tok, 1, p - 1);
    p := Pos('/', Tok);
    If p > 0 Then
      Begin
      Val(Copy(Tok, 1, p - 1), Net, Code);
      If Code <> 0 Then
        Continue;
      Tok := Copy(Tok, p + 1, 20);
      End;
    Val(Tok, Node, Code);
    If (Code = 0) And (Net > 0) Then
      SeenAdd(C, Net, Node);
    End;
  End;


Procedure PathAdd(Var C: MsgCopy; Net, Node: Word);
  Var
    S: String;

  Begin
  S := Long2Str(Net) + '/' + Long2Str(Node);
  If (C.NumPath > 0) And (Length(C.PathLn[C.NumPath]) + 1 + Length(S) <= 70) Then
    C.PathLn[C.NumPath] := C.PathLn[C.NumPath] + ' ' + S
  Else If C.NumPath < MaxPath Then
    Begin
    Inc(C.NumPath);
    C.PathLn[C.NumPath] := S;
    End;
  End;


Procedure CopyLoad(Var M: AbsMsgObj; Var C: MsgCopy);
  {The current message (MsgStartUp done): the header fields, and the text with the SEEN-BY and PATH lines taken out
   and kept apart; INTL / FMPT / TOPT are left out (they are made again from the addresses).}
  Var
    c1: Char;
    Line: String;

  Procedure Take(Ln: String);
    Var
      U: String;
      Kl: Boolean;

    Begin
    Kl := (Length(Ln) > 0) And (Ln[1] = #1);
    If Kl Then
      U := Upper(Copy(Ln, 2, 9))
    Else
      U := Upper(Copy(Ln, 1, 9));
    If Copy(U, 1, 8) = 'SEEN-BY:' Then
      Begin
      SeenParse(C, Ln);
      Exit;
      End;
    If Copy(U, 1, 5) = 'PATH:' Then
      Begin
      If C.NumPath < MaxPath Then
        Begin
        Inc(C.NumPath);
        C.PathLn[C.NumPath] := StripBoth(Copy(Ln, Pos(':', Ln) + 1, 100), ' ');
        End;
      Exit;
      End;
    If Kl And (Copy(U, 1, 5) = 'FMPT ') Then
      Begin
      If C.Orig.Point = 0 Then
        C.Orig.Point := Str2Long(StripBoth(Copy(Ln, 7, 20), ' '));
      Exit;
      End;
    If Kl And (Copy(U, 1, 5) = 'TOPT ') Then
      Begin
      If C.Dest.Point = 0 Then
        C.Dest.Point := Str2Long(StripBoth(Copy(Ln, 7, 20), ' '));
      Exit;
      End;
    If Kl And (Copy(U, 1, 5) = 'INTL ') Then
      Exit;
    If Kl And (Copy(U, 1, 6) = 'MSGID:') Then
      C.MsgId := StripBoth(Copy(Ln, 8, 200), ' ');
    CopyAddStr(C, Ln);
    CopyAddByte(C, 13);
    End;

  Begin
  C.From := M.GetFrom;
  C.ToN := M.GetTo;
  C.Subj := M.GetSubj;
  C.Date := M.GetDate;
  C.Time := M.GetTime;
  C.Cost := M.GetCost;
  C.Priv := M.IsPriv;
  C.Crash := M.IsCrash;
  C.KillSent := M.IsKillSent;
  C.FAttach := M.IsFAttach;
  C.FileReq := M.IsFileReq;
  C.ReqRct := M.IsReqRct;
  C.RetRct := M.IsRetRct;
  C.ReqAud := M.IsReqAud;
  C.Hold := M.IsHold;
  M.GetOrig(C.Orig);
  M.GetDest(C.Dest);
  M.MsgTxtStartUp;
  Line := '';
  c1 := M.GetChar;
  While Not M.EOM Do
    Begin
    If c1 = #13 Then
      Begin
      Take(Line);
      Line := '';
      End
    Else If c1 <> #10 Then
      Begin
      If Length(Line) >= 250 Then
        Begin
        Take(Line);
        Line := '';
        End;
      Line := Line + c1;
      End;
    c1 := M.GetChar;
    End;
  If Line <> '' Then
    Take(Line);
  End;


{---------------------------------------------------------------- outgoing packets}

Function Z2(N: LongInt): String;
  Begin
  Z2 := PadLeft(Long2Str(N), '0', 2);
  End;


Function HexStr(N: LongInt; Width: Word): String;
  Var
    S: String;
    i: Word;

  Begin
  S := '';
  For i := 1 To Width Do
    Begin
    S := Copy('0123456789abcdef', (N And 15) + 1, 1) + S;
    N := (N Shr 4) And $0FFFFFFF;
    End;
  HexStr := S;
  End;


Function NextSerial: LongInt;
  {message ids and packet names: the time, and always more than the last one, also over runs (mktoss.ser)}
  Var
    T: TTime;

  Begin
  T := fpTime;
  If T <= LastSerial Then
    LastSerial := LastSerial + 1
  Else
    LastSerial := T;
  NextSerial := LastSerial;
  End;


Procedure LoadSerial;
  Var
    F: File;
    L: LongInt;
    Got: Word;

  Begin
  Assign(F, InDir + 'mktoss.ser');
  FileMode := fmReadOnly + fmDenyNone;
  Reset(F, 4);
  If IoResult <> 0 Then
    Exit;
  BlockRead(F, L, 1, Got);
  If (IoResult = 0) And (Got = 1) And (L > LastSerial) Then
    LastSerial := L;
  Close(F);
  If IoResult <> 0 Then;
  End;


Procedure SaveSerial;
  Var
    F: File;

  Begin
  Assign(F, InDir + 'mktoss.ser');
  ReWrite(F, 4);
  If IoResult <> 0 Then
    Exit;
  BlockWrite(F, LastSerial, 1);
  Close(F);
  If IoResult <> 0 Then;
  End;


Function FlavourOf(Sys: Word): Char;
  {the flavour of the system for echomail: Immediate, Crash, Normal, Hold}
  Begin
  Case Config^.GetEchoToMailType(Sys) Of
    0: FlavourOf := 'I';
    1: FlavourOf := 'C';
    3: FlavourOf := 'H';
    Else FlavourOf := 'N';
    End;
  End;


Function CurrentSpool(Sys: Word; Flav: Char; Aka: Word): String;
  {the packet that is being filled for the system and flavour: the newest, or a new one when it is over the packet size}
  Var
    SR: SearchRec;
    Stem: String;
    Best: LongInt;
    N: LongInt;
    Code: Integer;
    Sz: LongInt;
    Max: LongInt;

  Begin
  Stem := 's' + Z2(Sys) + Lower(Flav) + Copy('0123456789a', Aka + 1, 1) + '_';
  Best := 0;
  Sz := 0;
  FindFirst(SpoolDir + Stem + '*.pkt', AnyFile, SR);
  While DosError = 0 Do
    Begin
    Val(Copy(SR.Name, Length(Stem) + 1, Length(SR.Name) - Length(Stem) - 4), N, Code);
    If (Code = 0) And (N > Best) Then
      Begin
      Best := N;
      Sz := SR.Size;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  Max := Config^.GetEchoMaxPkt;
  If (Best = 0) Or ((Max > 0) And (Sz >= Max)) Then
    Inc(Best);
  CurrentSpool := SpoolDir + Stem + Long2Str(Best) + '.pkt';
  End;


Function AkaNum(Area: Word): Word;
  Var
    N: Word;

  Begin
  N := Config^.GetMsgAddrNum(Area);
  If (N < 1) Or (N > 10) Then
    N := 1;
  AkaNum := N;
  End;


Procedure OurAka(Area: Word; Var A: AddrType);
  {the address of the area (its AKA), the main one when it has none}
  Var
    N: Word;

  Begin
  N := Config^.GetMsgAddrNum(Area);
  If (N >= 1) And (N <= 10) Then
    Config^.GetAddr(N, A)
  Else
    A := Ours[1];
  If A.Zone = 0 Then
    A := Ours[1];
  End;


Function WriteOut(Sys: Word; Flav: Char; Var C: MsgCopy; Area: Word; Echo: Boolean; Tail: Boolean;
  Via: String): Boolean;
  {the message (in C) into the outgoing packet for the system: an echomail message of the area, or netmail}
  Var
    P: PktMsgObj;
    SA, Us: AddrType;
    i: LongInt;
    E: Word;
    Lines: Array[1..60] Of String[90];
    NL, k, n: Word;
    S: String;

  Begin
  WriteOut := False;
  Config^.GetEchoToAddr(Sys, SA);
  OurAka(Area, Us);
  P.Init;
  P.SetMsgPath(CurrentSpool(Sys, Flav, AkaNum(Area)));
  P.SetPacketInfo(Us, SA, PktPwdOf(Sys));
  P.StartNewMsg;
  P.SetFrom(C.From);
  P.SetTo(C.ToN);
  P.SetSubj(C.Subj);
  P.SetDate(C.Date);
  P.SetTime(C.Time);
  P.SetCost(C.Cost);
  P.SetEchoTail(Tail);
  If Echo Then
    Begin
    P.SetMailType(mmtEchoMail);
    P.SetArea(Config^.GetEchoAreaTag(Area));
    P.SetOrig(Us);
    P.SetDest(SA);
    P.SetOriginText(Config^.GetMsgOrigStr(Area));
    End
  Else
    Begin
    P.SetMailType(mmtNetMail);
    P.SetOrig(C.Orig);
    P.SetDest(C.Dest);
    P.SetPriv(C.Priv);
    P.SetCrash(C.Crash);
    P.SetKillSent(C.KillSent);
    P.SetFAttach(C.FAttach);
    P.SetFileReq(C.FileReq);
    P.SetReqRct(C.ReqRct);
    P.SetRetRct(C.RetRct);
    P.SetReqAud(C.ReqAud);
    P.SetHold(C.Hold);
    End;
  If C.MsgId <> '' Then
    P.SetMsgId(C.MsgId);
  For i := 0 To C.TxtLen - 1 Do
    P.DoChar(Chr(C.Txt^[i]));
  If Via <> '' Then
    P.DoKludgeLn(#1 + Via);
  If Echo Then
    Begin
    {SEEN-BY: sorted, the net only when it changes, lines up to 76 characters}
    For k := 1 To C.NumSeen Do
      For n := k + 1 To C.NumSeen Do
        If (C.Seen^[n].Net < C.Seen^[k].Net) Or ((C.Seen^[n].Net = C.Seen^[k].Net) And (C.Seen^[n].Node < C.Seen^[k].Node)) Then
          Begin
          i := C.Seen^[k].Net; C.Seen^[k].Net := C.Seen^[n].Net; C.Seen^[n].Net := i;
          i := C.Seen^[k].Node; C.Seen^[k].Node := C.Seen^[n].Node; C.Seen^[n].Node := i;
          End;
    NL := 0;
    S := '';
    n := 0;
    For k := 1 To C.NumSeen Do
      Begin
      If (k = 1) Or (C.Seen^[k].Net <> C.Seen^[k - 1].Net) Then
        Begin
        If Length(S) + 3 + Length(Long2Str(C.Seen^[k].Net)) + Length(Long2Str(C.Seen^[k].Node)) > 76 Then
          Begin
          If NL < 60 Then
            Begin
            Inc(NL);
            Lines[NL] := S;
            End;
          S := '';
          End;
        If S = '' Then
          S := 'SEEN-BY: ' + Long2Str(C.Seen^[k].Net) + '/' + Long2Str(C.Seen^[k].Node)
        Else
          S := S + ' ' + Long2Str(C.Seen^[k].Net) + '/' + Long2Str(C.Seen^[k].Node);
        End
      Else
        Begin
        If Length(S) + 1 + Length(Long2Str(C.Seen^[k].Node)) > 76 Then
          Begin
          If NL < 60 Then
            Begin
            Inc(NL);
            Lines[NL] := S;
            End;
          S := 'SEEN-BY: ' + Long2Str(C.Seen^[k].Net) + '/' + Long2Str(C.Seen^[k].Node);
          End
        Else
          S := S + ' ' + Long2Str(C.Seen^[k].Node);
        End;
      End;
    If (S <> '') And (NL < 60) Then
      Begin
      Inc(NL);
      Lines[NL] := S;
      End;
    For k := 1 To NL Do
      P.DoKludgeLn(#1 + Lines[k]);
    For k := 1 To C.NumPath Do
      P.DoKludgeLn(#1 + 'PATH: ' + C.PathLn[k]);
    End;
  E := P.WriteMsg;
  If E <> 0 Then
    Log('cannot write the outgoing packet ' + CurrentSpool(Sys, Flav, AkaNum(Area)) + ' (error ' + Long2Str(E) + ')')
  Else
    WriteOut := True;
  P.Done;
  End;


Function SysNetNode(Sys: Word; Var Net, Node: Word): Boolean;
  Var
    A: AddrType;

  Begin
  Config^.GetEchoToAddr(Sys, A);
  Net := A.Net;
  Node := A.Node;
  SysNetNode := A.Zone <> 0;
  End;


Procedure ForwardEcho(Var Src: PktMsgObj; Area: Word; FromSys: Word);
  {an echomail message that was tossed (or passes through) goes on to the other systems linked to the area}
  Var
    C: MsgCopy;
    Us: AddrType;
    S: Word;
    Net, Node: Word;
    Dest: Array[1..32] Of Boolean;
    Any: Boolean;
    n: Word;

  Begin
  CopyInit(C);
  CopyLoad(Src, C);
  Any := False;
  For S := 1 To 32 Do
    Begin
    Dest[S] := False;
    If (S <> FromSys) And Config^.GetEchoToArea(S, Area) And SysNetNode(S, Net, Node) Then
      If Not SeenHas(C, Net, Node) Then
        Begin
        Dest[S] := True;
        Any := True;
        End;
    End;
  If Any Then
    Begin
    OurAka(Area, Us);
    SeenAdd(C, Us.Net, Us.Node);
    For S := 1 To 32 Do
      If Dest[S] Then
        Begin
        SysNetNode(S, Net, Node);
        SeenAdd(C, Net, Node);
        End;
    PathAdd(C, Us.Net, Us.Node);
    For S := 1 To 32 Do
      If Dest[S] Then
        If WriteOut(S, FlavourOf(S), C, Area, True, False, '') Then
          Begin
          Inc(Forwarded);
          If Not Quiet Then
            Log('passed ' + Config^.GetEchoAreaTag(Area) + ' on to system ' + Long2Str(S) + ': ' + C.Subj);
          End;
    End;
  CopyFree(C);
  End;



{---------------------------------------------------------------- areafix}

Const
  MaxRep = 1500;

Type
  RepArr = Array[1..MaxRep] Of String[100];
  HubBuf = Record
    N: Word;
    L: Array[1..60] Of String[60];
    End;

Var
  Rep: ^RepArr;
  NumRep: Word;
  HubReq: Array[1..32] Of ^HubBuf;
  EchoChanged: Boolean;


Procedure AddRep(S: String);
  Begin
  If NumRep < MaxRep Then
    Begin
    Inc(NumRep);
    Rep^[NumRep] := Copy(S, 1, 100);
    End
  Else If NumRep = MaxRep Then
    Begin
    Inc(NumRep);
    End;
  End;


Function BytesToString(P: PktBytePtr; From, Count: LongInt): String;
  Var
    S: String;
    i: LongInt;

  Begin
  S := '';
  For i := From To From + Count - 1 Do
    If Length(S) < 255 Then
      S := S + Chr(P^[i]);
  BytesToString := S;
  End;


Function IsAreafixName(Name: String): Boolean;
  Var
    U: String;
    i: Word;
    R: String;

  Begin
  U := Upper(Name);
  R := '';
  For i := 1 To Length(U) Do
    If U[i] <> ' ' Then
      R := R + U[i];
  IsAreafixName := (R = 'AREAFIX') Or (R = 'AREAMGR') Or (R = 'AREAMANAGER');
  End;


Function MatchPat(P, N: String): Boolean;
  {* and ?, not case sensitive}
  Begin
  If P = '' Then
    MatchPat := (N = '')
  Else If P[1] = '*' Then
    Begin
    If MatchPat(Copy(P, 2, 255), N) Then
      MatchPat := True
    Else If N = '' Then
      MatchPat := False
    Else
      MatchPat := MatchPat(P, Copy(N, 2, 255));
    End
  Else If N = '' Then
    MatchPat := False
  Else If (P[1] = '?') Or (UpCase(P[1]) = UpCase(N[1])) Then
    MatchPat := MatchPat(Copy(P, 2, 255), Copy(N, 2, 255))
  Else
    MatchPat := False;
  End;


Function AreaAvailable(Sys: Word; Area: Word): Boolean;
  {an echo area of ours that the system may link to: it has a tag, it does not come from that system, and, when the area
   is restricted to networks (Message Areas > Networks), the system has one of them (Network Security)}
  Var
    nt: Word;
    AreaNets, Share: Boolean;

  Begin
  AreaAvailable := False;
  If (Config^.GetMsgName(Area) = '') Or (Config^.GetMsgType(Area) <> EchoMail) Then
    Exit;
  If StripBoth(Config^.GetEchoAreaTag(Area), ' ') = '' Then
    Exit;
  If Config^.GetEchoToHub(Area) = Sys Then
    Exit;
  AreaNets := False;
  Share := False;
  For nt := 1 To 32 Do
    If Config^.GetMsgNetwork(Area, nt) Then
      Begin
      AreaNets := True;
      If Config^.GetEchoToNetwork(Sys, nt) Then
        Share := True;
      End;
  AreaAvailable := (Not AreaNets) Or Share;
  End;


Procedure AddHubReq(Hub: Word; Line: String);
  Begin
  If HubReq[Hub] = Nil Then
    Begin
    New(HubReq[Hub]);
    HubReq[Hub]^.N := 0;
    End;
  If HubReq[Hub]^.N < 60 Then
    Begin
    Inc(HubReq[Hub]^.N);
    HubReq[Hub]^.L[HubReq[Hub]^.N] := Line;
    End;
  End;


Procedure AfterChange(Area: Word);
  {an area that downlinks take from our hub: the hub is asked for it when the first downlink comes, and (for a
   pass-through area, which nobody reads here) told to stop when the last one goes}
  Var
    H, S, Downs: Word;
    A: AddrType;
    Tag: String;

  Begin
  H := Config^.GetEchoToHub(Area);
  If (H < 1) Or (H > 32) Then
    Exit;
  Config^.GetEchoToAddr(H, A);
  If A.Zone = 0 Then
    Exit;
  Tag := StripBoth(Config^.GetEchoAreaTag(Area), ' ');
  Downs := 0;
  For S := 1 To 32 Do
    If (S <> H) And Config^.GetEchoToArea(S, Area) Then
      Inc(Downs);
  If (Downs > 0) And (Not Config^.GetEchoToArea(H, Area)) Then
    Begin
    Config^.SetEchoToArea(H, Area, True);
    AddHubReq(H, '+' + Tag);
    Log('area ' + Tag + ' is asked for from the hub ' + AddrStr(A));
    End
  Else If (Downs = 0) And Config^.GetEchoToArea(H, Area) And Config^.GetEchoAreaPassThru(Area) Then
    Begin
    Config^.SetEchoToArea(H, Area, False);
    AddHubReq(H, '-' + Tag);
    Log('area ' + Tag + ' is no longer needed: the hub ' + AddrStr(A) + ' is told to stop it');
    End;
  End;


Procedure PostNetmail(FromName, ToName, Subj: String; Var Orig, Dest: AddrType; Lines: Word; Hub: Word);
  {a netmail from the tosser into the netmail area, for the scanner to send: the text is Rep (Lines of it) or, for
   a request to a hub, the lines of HubReq[Hub]}
  Var
    Area, i: Word;
    M: AbsMsgPtr;
    Y, Mo, D, Dow, H, Mi, Se, Hs: Word;
    Res: Word;

  Begin
  Area := FindNetmailArea;
  If Area = 0 Then
    Begin
    Log('there is no netmail area: the netmail "' + Subj + '" to ' + AddrStr(Dest) + ' cannot be written');
    Problems := True;
    Exit;
    End;
  If Not OpenMsgArea(M, Config^.GetMsgAreaId(Area)) Then
    Begin
    Log('cannot open the netmail area ' + Long2Str(Area));
    Problems := True;
    Exit;
    End;
  GetDate(Y, Mo, D, Dow);
  GetTime(H, Mi, Se, Hs);
  M^.SetMailType(mmtNetMail);
  M^.StartNewMsg;
  M^.SetOrig(Orig);
  M^.SetDest(Dest);
  M^.SetFrom(FromName);
  M^.SetTo(ToName);
  M^.SetSubj(Subj);
  M^.SetDate(Z2(Mo) + '-' + Z2(D) + '-' + Z2(Y Mod 100));
  M^.SetTime(Z2(H) + ':' + Z2(Mi));
  M^.SetPriv(True);
  M^.SetKillSent(True);
  M^.SetLocal(True);
  M^.SetSent(False);
  M^.SetRcvd(False);
  M^.SetEcho(False);
  If Hub = 0 Then
    Begin
    For i := 1 To Lines Do
      M^.DoStringLn(Rep^[i]);
    If NumRep > MaxRep Then
      M^.DoStringLn('(the answer was cut short)');
    End
  Else
    For i := 1 To HubReq[Hub]^.N Do
      M^.DoStringLn(HubReq[Hub]^.L[i]);
  Res := M^.WriteMsg;
  If Res <> 0 Then
    Begin
    Log('cannot write the netmail "' + Subj + '" (error ' + Long2Str(Res) + ')');
    Problems := True;
    End;
  If Not CloseMsgArea(M) Then;
  End;


Procedure RepList(Sys: Word; Mode: Char);
  {%LIST (all available), %QUERY (linked), %UNLINKED (available, not linked)}
  Var
    i, n: Word;
    Linked: Boolean;
    Tag: String;

  Begin
  n := 0;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If AreaAvailable(Sys, i) Or ((Mode = 'Q') And Config^.GetEchoToArea(Sys, i) And
      (StripBoth(Config^.GetEchoAreaTag(i), ' ') <> '')) Then
      Begin
      Linked := Config^.GetEchoToArea(Sys, i);
      If ((Mode = 'Q') And Not Linked) Or ((Mode = 'U') And Linked) Then
        Continue;
      Tag := StripBoth(Config^.GetEchoAreaTag(i), ' ');
      If Linked Then
        AddRep('* ' + PadRight(Tag, ' ', 28) + Copy(Config^.GetMsgName(i), 1, 60))
      Else
        AddRep('  ' + PadRight(Tag, ' ', 28) + Copy(Config^.GetMsgName(i), 1, 60));
      Inc(n);
      End;
  If n = 0 Then
    AddRep('(none)');
  If Mode = 'L' Then
    AddRep('(* = linked)');
  End;


Procedure DoSubscribe(Sys: Word; Pat: String; Link: Boolean);
  Var
    i, n: Word;
    Tag: String;
    Linked: Boolean;
    Seen: Boolean;

  Begin
  n := 0;
  Seen := False;
  For i := 1 To Config^.GetMaxMsgAreas Do
    Begin
    Tag := StripBoth(Config^.GetEchoAreaTag(i), ' ');
    If (Tag = '') Or (Config^.GetMsgType(i) <> EchoMail) Or (Config^.GetMsgName(i) = '') Then
      Continue;
    If Not MatchPat(Pat, Tag) Then
      Continue;
    Seen := True;
    Linked := Config^.GetEchoToArea(Sys, i);
    If Link Then
      Begin
      If Not AreaAvailable(Sys, i) Then
        Begin
        If Pos('*', Pat) + Pos('?', Pat) = 0 Then
          AddRep('+' + Tag + ': not available to you');
        Continue;
        End;
      If Linked Then
        Begin
        If Pos('*', Pat) + Pos('?', Pat) = 0 Then
          AddRep('+' + Tag + ': already linked');
        End
      Else
        Begin
        Config^.SetEchoToArea(Sys, i, True);
        EchoChanged := True;
        AfterChange(i);
        AddRep('+' + Tag + ': linked');
        Inc(n);
        End;
      End
    Else
      Begin
      If Linked Then
        Begin
        Config^.SetEchoToArea(Sys, i, False);
        EchoChanged := True;
        AfterChange(i);
        AddRep('-' + Tag + ': unlinked');
        Inc(n);
        End
      Else If Pos('*', Pat) + Pos('?', Pat) = 0 Then
        AddRep('-' + Tag + ': was not linked');
      End;
    End;
  If Not Seen Then
    Begin
    If Link Then
      AddRep('+' + Pat + ': no such area')
    Else
      AddRep('-' + Pat + ': no such area');
    End
  Else If (n = 0) And ((Pos('*', Pat) + Pos('?', Pat)) > 0) Then
    AddRep(Copy('+-', 2 - Ord(Link), 1) + Pat + ': nothing to change');
  End;


Function ProcessAreafix(Var Pkt: PktMsgObj; Var Dst: AddrType): Boolean;
  {A netmail for Areafix: True = it was dealt with (answered, not stored); False = not ours to answer (the sender is
   not a system of ours), the message is stored for the sysop.}
  Var
    C: MsgCopy;
    Sender, Boss: AddrType;
    Sys, i, Cmds: Word;
    Pwd, Line, Cmd, SenderName: String;
    p: LongInt;
    LStart: LongInt;
    Stop: Boolean;
    Subj: String;
    FromAddr: AddrType;

  Procedure DoLine(L: String);
    Begin
    L := StripBoth(L, ' ');
    If (L = '') Or (L[1] = #1) Then
      Exit;
    If Copy(L, 1, 3) = '---' Then
      Begin
      Stop := True;
      Exit;
      End;
    If Copy(L, 1, 3) = ' * ' Then
      Exit;
    Inc(Cmds);
    Cmd := Upper(ExtractWord(L, 1));
    If Cmd = '%LIST' Then
      Begin
      AddRep('Areas you can have:');
      RepList(Sys, 'L');
      End
    Else If Cmd = '%QUERY' Then
      Begin
      AddRep('Areas you have:');
      RepList(Sys, 'Q');
      End
    Else If Cmd = '%UNLINKED' Then
      Begin
      AddRep('Areas you can have and do not:');
      RepList(Sys, 'U');
      End
    Else If Cmd = '%HELP' Then
      Begin
      AddRep('Areafix: a netmail to Areafix, your password as the subject, one command to a line:');
      AddRep('  %LIST       the areas you can have          %QUERY     the areas you have');
      AddRep('  %UNLINKED   the areas you can have and do not   %HELP   this text');
      AddRep('  +AREA       link the area                   -AREA      unlink the area');
      AddRep('  (a bare AREA links it; * and ? stand for characters: +* all, -* none)');
      End
    Else If L[1] = '%' Then
      AddRep(Cmd + ': not a command that is known (%HELP)')
    Else If L[1] = '-' Then
      DoSubscribe(Sys, Upper(StripBoth(Copy(L, 2, 80), ' ')), False)
    Else If L[1] = '+' Then
      DoSubscribe(Sys, Upper(StripBoth(Copy(L, 2, 80), ' ')), True)
    Else If L[1] In ['A'..'Z', 'a'..'z', '0'..'9', '_'] Then
      DoSubscribe(Sys, Upper(ExtractWord(L, 1)), True)
    Else
      AddRep(L + ': not understood (%HELP)');
    End;

  Begin
  ProcessAreafix := False;
  Pkt.GetOrig(Sender);
  Sys := FindSystem(Sender);
  If Sys = 0 Then
    Begin
    Boss := Sender;
    Boss.Point := 0;
    Sys := FindSystem(Boss);
    End;
  If Sys = 0 Then
    Begin
    Log('areafix request from ' + AddrStr(Sender) + ', which is not a system of ours: stored for the sysop');
    Exit;
    End;
  ProcessAreafix := True;
  Pkt.GetOrig(FromAddr);
  SenderName := Pkt.GetFrom;
  New(Rep);
  NumRep := 0;
  EchoChanged := False;
  For i := 1 To 32 Do
    HubReq[i] := Nil;
  Subj := 'Areafix';
  Pwd := Upper(StripBoth(Pkt.GetSubj, ' '));
  If (Config^.GetEchoToPwd(Sys) = '') Or (Pwd <> Upper(StripBoth(Config^.GetEchoToPwd(Sys), ' '))) Then
    Begin
    Log('areafix request from ' + AddrStr(Sender) + ': wrong password');
    AddRep('Your request was not carried out: the password in the subject is not right.');
    AddRep('(%HELP tells what Areafix does)');
    Subj := 'Areafix: password error';
    End
  Else
    Begin
    CopyInit(C);
    CopyLoad(Pkt, C);
    Cmds := 0;
    Stop := False;
    p := 0;
    While (p < C.TxtLen) And Not Stop Do
      Begin
      LStart := p;
      While (p < C.TxtLen) And (C.Txt^[p] <> 13) Do
        Inc(p);
      Line := BytesToString(C.Txt, LStart, p - LStart);
      Inc(p);
      DoLine(Line);
      End;
    CopyFree(C);
    If Cmds = 0 Then
      AddRep('There was no command in your message (%HELP).');
    Subj := 'Areafix response';
    Log('areafix request from ' + AddrStr(Sender) + ': ' + Long2Str(Cmds) + ' command(s)');
    End;
  If EchoChanged Then
    Begin
    If MKCfgObjPtr(Config)^.SaveEchoCfg <> 0 Then
      Begin
      Log('cannot save echocfg.mk');
      Problems := True;
      End;
    End;
  PostNetmail('Areafix', SenderName, Subj, Dst, FromAddr, NumRep, 0);
  For i := 1 To 32 Do
    If HubReq[i] <> Nil Then
      Begin
      Config^.GetEchoToAddr(i, Boss);
      PostNetmail('Areafix', 'Areafix', StripBoth(Config^.GetEchoToPwd(i), ' '), Dst, Boss, 0, i);
      Dispose(HubReq[i]);
      HubReq[i] := Nil;
      End;
  Dispose(Rep);
  End;


Function MoveFile(From, ToName: String): Boolean;
  {a rename, or a copy and delete when the directories are on different disks}
  Var
    F, G: File;
    Buf: Array[1..8192] Of Byte;
    Got, Put: Word;
    Ok: Boolean;

  Begin
  Assign(F, From);
  Rename(F, ToName);
  If IoResult = 0 Then
    Begin
    MoveFile := True;
    Exit;
    End;
  MoveFile := False;
  Assign(F, From);
  Assign(G, ToName);
  FileMode := fmReadOnly + fmDenyNone;
  Reset(F, 1);
  If IoResult <> 0 Then
    Exit;
  ReWrite(G, 1);
  If IoResult <> 0 Then
    Begin
    Close(F);
    Exit;
    End;
  Ok := True;
  Repeat
    BlockRead(F, Buf, SizeOf(Buf), Got);
    If IoResult <> 0 Then
      Begin
      Ok := False;
      Break;
      End;
    If Got > 0 Then
      Begin
      BlockWrite(G, Buf, Got, Put);
      If (IoResult <> 0) Or (Put <> Got) Then
        Ok := False;
      End;
  Until (Got = 0) Or (Not Ok);
  Close(F);
  Close(G);
  If IoResult <> 0 Then;
  If Ok Then
    Begin
    Erase(F);
    If IoResult <> 0 Then;
    MoveFile := True;
    End
  Else
    Begin
    Erase(G);
    If IoResult <> 0 Then;
    End;
  End;


{---------------------------------------------------------------- file attach}

Type
  AttachList = Record
    N: Word;
    Name: Array[1..20] Of String[100];       {as written in the subject, without the ^ or #}
    Act: Array[1..20] Of Char;               {^ delete after sent, # truncate, blank keep}
    End;


Procedure ParseAttach(Subj: String; Var L: AttachList);
  {The subject of a file attach netmail names the files, blank or comma separated; ^ in front = delete the file after
   it was sent, # = truncate it.}
  Var
    Tok: String;
    p: Word;

  Begin
  L.N := 0;
  Subj := StripBoth(Subj, ' ') + ' ';
  While Length(Subj) > 0 Do
    Begin
    p := 1;
    While (p <= Length(Subj)) And (Subj[p] <> ' ') And (Subj[p] <> ',') Do
      Inc(p);
    Tok := Copy(Subj, 1, p - 1);
    Subj := StripBoth(Copy(Subj, p + 1, 255), ' ');
    If Subj <> '' Then
      Subj := Subj + ' ';
    If Tok = '' Then
      Continue;
    If L.N >= 20 Then
      Break;
    Inc(L.N);
    L.Act[L.N] := ' ';
    If (Tok[1] = '^') Or (Tok[1] = '#') Then
      Begin
      L.Act[L.N] := Tok[1];
      Tok := Copy(Tok, 2, 100);
      End;
    L.Name[L.N] := Tok;
    End;
  End;


Function AttachPath(Name: String): String;
  {where an attached file is: a full path as it is, else in the file attach directory (General > Paths)}
  Begin
  If (Name <> '') And (Name[1] = '/') Then
    AttachPath := Name
  Else
    AttachPath := AttachDir + Name;
  End;


Function BaseName(Name: String): String;
  Var
    p: Word;

  Begin
  p := Length(Name);
  While (p > 0) And (Name[p] <> '/') Do
    Dec(p);
  BaseName := Copy(Name, p + 1, 100);
  End;


Function FindInInbound(Name: String): String;
  {a file of the inbound by that name: as written, else not case sensitive (a file comes as the sender named it)}
  Var
    SR: SearchRec;
    U: String;

  Begin
  FindInInbound := '';
  If FileExist(InDir + Name) Then
    Begin
    FindInInbound := InDir + Name;
    Exit;
    End;
  U := Upper(Name);
  FindFirst(InDir + '*', AnyFile, SR);
  While DosError = 0 Do
    Begin
    If ((SR.Attr And Directory) = 0) And (Upper(SR.Name) = U) Then
      Begin
      FindInInbound := InDir + SR.Name;
      Break;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  End;


Procedure TakeAttached(Var Pkt: PktMsgObj; Var Subj: String; ForUs: Boolean);
  {The files that came with a file attach netmail are in the inbound (the mailer received them): they are moved to the
   file attach directory under the name in the subject.  For mail that is only passing through the subject gets a ^ so
   that the file is deleted once it was sent on.}
  Var
    L: AttachList;
    i: Word;
    Src, Dst, Name: String;
    n: Word;
    NewSubj: String;

  Begin
  ParseAttach(Pkt.GetSubj, L);
  NewSubj := '';
  For i := 1 To L.N Do
    Begin
    Name := BaseName(L.Name[i]);
    If Name = '' Then
      Continue;
    Src := FindInInbound(Name);
    If Src = '' Then
      Log('the file ' + Name + ' attached to a netmail is not in the inbound (it may still be on its way)')
    Else
      Begin
      MkDir(Copy(AttachDir, 1, Length(AttachDir) - 1));
      If IoResult <> 0 Then;
      Dst := AttachDir + Name;
      n := 0;
      While FileExist(Dst) And (n < 99) Do
        Begin
        Inc(n);
        Dst := AttachDir + Name + '.' + Long2Str(n);
        End;
      If MoveFile(Src, Dst) Then
        Log('attached file ' + Name + ' moved to ' + Dst)
      Else
        Begin
        Log('cannot move ' + Src + ' to ' + Dst);
        Problems := True;
        End;
      If Dst <> AttachDir + Name Then
        Name := BaseName(Dst);
      End;
    If NewSubj <> '' Then
      NewSubj := NewSubj + ' ';
    If ForUs Then
      NewSubj := NewSubj + Name
    Else
      NewSubj := NewSubj + '^' + Name;
    End;
  If NewSubj <> '' Then
    Subj := NewSubj;
  End;



{---------------------------------------------------------------- tossing a packet}

Procedure TossEcho(Var Pkt: PktMsgObj; Sys: Word);
  Var
    Tag: String;
    Area: Word;
    Res: Word;

  Begin
  Tag := Pkt.GetArea;
  Area := FindEchoArea(Tag);
  If Area = 0 Then
    Begin
    BadMessage(Pkt, 'no area with the tag ' + Tag);
    Exit;
    End;
  If Not Config^.GetEchoToArea(Sys, Area) Then
    Begin
    BadMessage(Pkt, 'the system is not linked to the area ' + Tag);
    Exit;
    End;
  If IsDupe(Tag, Pkt.GetMsgId, Pkt.GetFrom, Pkt.GetTo, Pkt.GetSubj, Pkt.GetDate, Pkt.GetTime) Then
    Begin
    Inc(Dups);
    Log('duplicate in ' + Tag + ': ' + Pkt.GetSubj);
    Exit;
    End;
  If Config^.GetEchoAreaPassThru(Area) Then
    Begin
    Inc(Passed);
    Log('pass-through ' + Tag + ': ' + Pkt.GetSubj);
    ForwardEcho(Pkt, Area, Sys);
    Exit;
    End;
  Res := StoreMessage(Pkt, Area, True, Pkt.GetSubj);
  If Res = 0 Then
    Begin
    Inc(Tossed);
    Log('tossed ' + Tag + ' #' + Long2Str(Pkt.GetMsgNum) + ': ' + Pkt.GetFrom + ' -> ' + Pkt.GetTo + ': ' + Pkt.GetSubj);
    ForwardEcho(Pkt, Area, Sys);
    End
  Else
    BadMessage(Pkt, 'could not be stored (error ' + Long2Str(Res) + ')');
  End;


Procedure TossNetmail(Var Pkt: PktMsgObj; Sys: Word);
  Var
    Dst: AddrType;
    Area: Word;
    Res: Word;
    ForUs: Boolean;
    Subj: String;

  Begin
  Pkt.GetDest(Dst);
  ForUs := IsOurs(Dst);
  Subj := Pkt.GetSubj;
  If ForUs And IsAreafixName(Pkt.GetTo) Then
    If ProcessAreafix(Pkt, Dst) Then
      Begin
      Inc(Areafixes);
      Exit;
      End;
  Area := FindNetmailArea;
  If Area = 0 Then
    Begin
    BadMessage(Pkt, 'there is no netmail area');
    Exit;
    End;
  If Pkt.IsFAttach Then
    TakeAttached(Pkt, Subj, ForUs);
  Res := StoreMessage(Pkt, Area, False, Subj);
  If Res = 0 Then
    Begin
    Inc(Netmails);
    If ForUs Then
      Log('netmail for us: ' + Pkt.GetFrom + ' -> ' + Pkt.GetTo + ': ' + Pkt.GetSubj)
    Else
      Log('netmail for ' + AddrStr(Dst) + ' stored, the scanner sends it on: ' + Pkt.GetFrom + ' -> ' + Pkt.GetTo + ': ' + Pkt.GetSubj);
    End
  Else
    BadMessage(Pkt, 'could not be stored (error ' + Long2Str(Res) + ')');
  End;


Function TossPacket(Path: String): Boolean;
  {True when everything in the packet was dealt with (tossed, duplicate or put in bad.pkt)}
  Var
    Pkt: PktMsgObj;
    PO: AddrType;
    Sys: Word;
    E: Word;

  Begin
  TossPacket := False;
  Pkt.Init;
  Pkt.SetMsgPath(Path);
  E := Pkt.OpenMsgBase;
  If E <> 0 Then
    Begin
    Log('cannot read ' + Path + ' as a packet (error ' + Long2Str(E) + ')');
    Problems := True;
    Pkt.Done;
    Exit;
    End;
  Pkt.GetPktOrig(PO);
  Sys := FindSystem(PO);
  If Sys = 0 Then
    Begin
    Log('packet ' + Path + ' is from ' + AddrStr(PO) + ', which is not in the echo systems list');
    Problems := True;
    Pkt.CloseMsgBase;
    Pkt.Done;
    Exit;
    End;
  If PktPwdOf(Sys) <> '' Then
    If Upper(StripBoth(Pkt.GetPktPassword, ' ')) <> Upper(PktPwdOf(Sys)) Then
      Begin
      Log('packet ' + Path + ' from ' + AddrStr(PO) + ' has the wrong packet password');
      Problems := True;
      Pkt.CloseMsgBase;
      Pkt.Done;
      Exit;
      End;
  If Not Pkt.PktClean Then
    Log('warning: ' + Path + ' is damaged, what can be read is tossed');
  Pkt.SeekFirst(1);
  While Pkt.SeekFound Do
    Begin
    Pkt.MsgStartUp;
    If Pkt.GetArea <> '' Then
      TossEcho(Pkt, Sys)
    Else
      TossNetmail(Pkt, Sys);
    Pkt.SeekNext;
    End;
  Pkt.CloseMsgBase;
  Pkt.Done;
  TossPacket := True;
  End;


{---------------------------------------------------------------- bundles}

Function ExtOf(Name: String): String;
  Var
    p: Word;

  Begin
  p := Length(Name);
  While (p > 0) And (Name[p] <> '.') Do
    Dec(p);
  If p = 0 Then
    ExtOf := ''
  Else
    ExtOf := Upper(Copy(Name, p + 1, 10));
  End;


Function IsBundleExt(E: String): Boolean;
  {SU0 .. SA9, MO0 .. : day of the week and a digit or letter}
  Var
    D: String;

  Begin
  IsBundleExt := False;
  If Length(E) <> 3 Then
    Exit;
  D := Copy(E, 1, 2);
  If (D = 'SU') Or (D = 'MO') Or (D = 'TU') Or (D = 'WE') Or (D = 'TH') Or (D = 'FR') Or (D = 'SA') Then
    If E[3] In ['0'..'9', 'A'..'Z'] Then
      IsBundleExt := True;
  End;


Function PackerOf(Path: String): Word;
  {which archiver made the file, by its first bytes; 0 = not known}
  Var
    F: File;
    B: Array[0..15] Of Byte;
    Got: Word;

  Begin
  PackerOf := 0;
  Assign(F, Path);
  FileMode := fmReadOnly + fmDenyNone;
  Reset(F, 1);
  If IoResult <> 0 Then
    Exit;
  FillChar(B, SizeOf(B), 0);
  BlockRead(F, B, SizeOf(B), Got);
  Close(F);
  If IoResult <> 0 Then;
  If (B[0] = Ord('P')) And (B[1] = Ord('K')) Then
    PackerOf := 2
  Else If (B[0] = $60) And (B[1] = $EA) Then
    PackerOf := 6
  Else If (B[2] = Ord('-')) And (B[3] = Ord('l')) And (B[4] = Ord('h')) Then
    PackerOf := 1
  Else If (B[0] = Ord('Z')) And (B[1] = Ord('O')) And (B[2] = Ord('O')) Then
    PackerOf := 4
  Else If B[0] = $1A Then
    PackerOf := 3;
  End;


Function ShellQuote(S: String): String;
  Var
    i: Word;
    R: String;

  Begin
  R := '''';
  For i := 1 To Length(S) Do
    If S[i] = '''' Then
      R := R + '''\'''''
    Else
      R := R + S[i];
  ShellQuote := R + '''';
  End;


Function Unpack(Path: String): Boolean;
  Var
    PN: Word;
    Cmd: String;
    Rc: LongInt;

  Begin
  Unpack := False;
  PN := PackerOf(Path);
  If PN = 0 Then
    Begin
    Log(Path + ' is not an archive of a kind that is known');
    Exit;
    End;
  If Not Config^.GetPackAvail(PN) Then
    Begin
    Log(Path + ' is a ' + Config^.GetPackName(PN) + ' archive, which is not available (EchoMail > Archivers)');
    Exit;
    End;
  Cmd := StripBoth(Config^.GetUnPackCmdLine(PN), ' ');
  If Cmd = '' Then
    Begin
    Log('no unpack command for ' + Config^.GetPackName(PN));
    Exit;
    End;
  Rc := fpSystem('cd ' + ShellQuote(WorkDir) + ' && ' + Cmd + ' ' + ShellQuote(Path) + ' >/dev/null 2>&1');
  If Rc <> 0 Then
    Log('unpacking ' + Path + ' failed (' + Cmd + ', status ' + Long2Str(Rc) + ')')
  Else
    Unpack := True;
  End;


{---------------------------------------------------------------- the directory}

Procedure EmptyDir(Dir: String);
  Var
    SR: SearchRec;
    F: File;

  Begin
  FindFirst(Dir + '*', AnyFile, SR);
  While DosError = 0 Do
    Begin
    If (SR.Attr And Directory) = 0 Then
      Begin
      Assign(F, Dir + SR.Name);
      Erase(F);
      If IoResult <> 0 Then;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  End;


Procedure Rename2(From, ToName: String);
  Var
    F: File;

  Begin
  Assign(F, From);
  Rename(F, ToName);
  If IoResult <> 0 Then;
  End;


Procedure Remove(Path: String);
  Var
    F: File;

  Begin
  Assign(F, Path);
  Erase(F);
  If IoResult <> 0 Then;
  End;


Procedure TossWork;
  {the packets that the bundle unpacked into the work directory}
  Var
    SR: SearchRec;
    Names: NameList;
    n, i: Word;
    Ok: Boolean;

  Begin
  n := 0;
  FindFirst(WorkDir + '*', AnyFile, SR);
  While (DosError = 0) And (n < 512) Do
    Begin
    If ((SR.Attr And Directory) = 0) And (ExtOf(SR.Name) = 'PKT') Then
      Begin
      Inc(n);
      Names[n] := SR.Name;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  For i := 1 To n Do
    Begin
    Ok := TossPacket(WorkDir + Names[i]);
    If Ok Then
      Remove(WorkDir + Names[i]);
    End;
  End;


Procedure TossInbound;
  Var
    SR: SearchRec;
    Names: NameList;
    Times: Array[1..512] Of LongInt;
    n, i, j: Word;
    T: LongInt;
    S: String[80];
    Path, E: String;
    Ok: Boolean;

  Begin
  n := 0;
  FindFirst(InDir + '*', AnyFile, SR);
  While (DosError = 0) And (n < 512) Do
    Begin
    E := ExtOf(SR.Name);
    If ((SR.Attr And Directory) = 0) And ((E = 'PKT') Or IsBundleExt(E)) Then
      Begin
      Inc(n);
      Names[n] := SR.Name;
      Times[n] := SR.Time;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  {oldest first, by name when the time is the same}
  For i := 1 To n Do
    For j := i + 1 To n Do
      If (Times[j] < Times[i]) Or ((Times[j] = Times[i]) And (Names[j] < Names[i])) Then
        Begin
        S := Names[i]; Names[i] := Names[j]; Names[j] := S;
        T := Times[i]; Times[i] := Times[j]; Times[j] := T;
        End;
  If n = 0 Then
    Log('nothing in ' + InDir);
  For i := 1 To n Do
    Begin
    Path := InDir + Names[i];
    E := ExtOf(Names[i]);
    If E = 'PKT' Then
      Begin
      Ok := TossPacket(Path);
      If Ok Then
        Remove(Path)
      Else
        Rename2(Path, Path + '.bad');
      End
    Else
      Begin
      EmptyDir(WorkDir);
      Ok := Unpack(Path);
      If Ok Then
        Begin
        TossWork;
        Remove(Path);
        End
      Else
        Begin
        Problems := True;
        Rename2(Path, Path + '.bad');
        End;
      EmptyDir(WorkDir);
      End;
    End;
  End;


Procedure CountUnsecure;
  Var
    M: ^MailerCfgType;
    Dir: String;
    SR: SearchRec;
    n: Word;
    E: String;

  Begin
  If Not Config^.HasMailer Then
    Exit;
  New(M);
  Config^.GetMailer(M^);
  Dir := StripBoth(M^.UnsecureIn, ' ');
  Dispose(M);
  If Dir = '' Then
    Exit;
  If Dir[Length(Dir)] <> '/' Then
    Dir := Dir + '/';
  n := 0;
  FindFirst(Dir + '*', AnyFile, SR);
  While DosError = 0 Do
    Begin
    E := ExtOf(SR.Name);
    If ((SR.Attr And Directory) = 0) And ((E = 'PKT') Or IsBundleExt(E)) Then
      Inc(n);
    FindNext(SR);
    End;
  FindClose(SR);
  If n > 0 Then
    Log('warning: ' + Long2Str(n) + ' mail file(s) in the unsecure inbound ' + Dir + ' are not tossed');
  End;



Function BinkPath: String;
  Var
    Me: String;
    p: Word;

  Begin
  If BinkProg <> '' Then
    Begin
    BinkPath := BinkProg;
    Exit;
    End;
  Me := ParamStr(0);
  p := Length(Me);
  While (p > 0) And (Me[p] <> '/') Do
    Dec(p);
  If (p > 0) And FileExist(Copy(Me, 1, p) + 'mkbink') Then
    BinkPath := Copy(Me, 1, p) + 'mkbink'
  Else
    BinkPath := 'mkbink';
  End;



Function QueueFile(Sys: Word; Flav: Char; Path: String; Act: Char): Boolean;
  {a file (not a packet) for the system: mkbink queue puts it in the BSO outbound; Act = ^ delete it after it was sent,
   # truncate it, else leave it}
  Var
    A: AddrType;
    Opt: String;
    Rc: LongInt;

  Begin
  Config^.GetEchoToAddr(Sys, A);
  Opt := '';
  If Act = '^' Then
    Opt := ' -x'
  Else If Act = '#' Then
    Opt := ' -T';
  Rc := fpSystem(ShellQuote(BinkPath) + ' queue -O ' + ShellQuote(Copy(OutDir, 1, Length(OutDir) - 1)) + ' -Z ' +
    Long2Str(Ours[1].Zone) + ' -t ' + AddrStr(A) + ' -F ' + Flav + Opt + ' ' + ShellQuote(Path) + ' >/dev/null 2>&1');
  QueueFile := Rc = 0;
  If Rc <> 0 Then
    Log('mkbink queue failed (status ' + Long2Str(Rc) + ') for ' + Path + ' to ' + AddrStr(A));
  End;


{---------------------------------------------------------------- scanning the message areas}

Procedure ScanEchoArea(Area: Word);
  {the messages the BBS wrote itself (local, not yet exported) go to the systems linked to the area}
  Var
    M: AbsMsgPtr;
    C: MsgCopy;
    Us: AddrType;
    S: Word;
    Net, Node: Word;
    Sent: Word;

  Begin
  If Not OpenMsgArea(M, Config^.GetMsgAreaId(Area)) Then
    Begin
    Log('cannot open message area ' + Long2Str(Area) + ' (' + Config^.GetMsgName(Area) + ')');
    Problems := True;
    Exit;
    End;
  M^.SeekFirst(1);
  While M^.SeekFound Do
    Begin
    M^.MsgStartUp;
    If M^.IsLocal And M^.IsEchoed And (Not M^.IsSent) And (Not M^.IsDeleted) Then
      Begin
      CopyInit(C);
      CopyLoad(M^, C);
      OurAka(Area, Us);
      Sent := 0;
      SeenAdd(C, Us.Net, Us.Node);
      For S := 1 To 32 Do
        If Config^.GetEchoToArea(S, Area) And SysNetNode(S, Net, Node) Then
          SeenAdd(C, Net, Node);
      PathAdd(C, Us.Net, Us.Node);
      If C.MsgId = '' Then
        C.MsgId := AddrStr(Us) + ' ' + HexStr(NextSerial, 8);
      For S := 1 To 32 Do
        If Config^.GetEchoToArea(S, Area) And SysNetNode(S, Net, Node) Then
          If WriteOut(S, FlavourOf(S), C, Area, True, True, '') Then
            Inc(Sent);
      If Sent = 0 Then
        Log('no system is linked to ' + Config^.GetEchoAreaTag(Area) + ': #' + Long2Str(M^.GetMsgNum) + ' was not sent anywhere')
      Else
        Begin
        Inc(Scanned);
        Log('scanned ' + Config^.GetEchoAreaTag(Area) + ' #' + Long2Str(M^.GetMsgNum) + ': ' + C.Subj + ' (to ' + Long2Str(Sent) + ' system(s))');
        If IsDupe(Config^.GetEchoAreaTag(Area), C.MsgId, C.From, C.ToN, C.Subj, C.Date, C.Time) Then;
        End;
      M^.SetSent(True);
      M^.SetEcho(False);
      M^.ReWriteHdr;
      CopyFree(C);
      End;
    M^.SeekNext;
    End;
  If Not CloseMsgArea(M) Then;
  End;


Function MatchPart(Pat: String; N: LongInt): Boolean;
  Var
    V: LongInt;
    Code: Integer;

  Begin
  If (Pat = '') Or (Pat = '*') Then
    MatchPart := True
  Else
    Begin
    Val(Pat, V, Code);
    MatchPart := (Code = 0) And (V = N);
    End;
  End;


Function MatchAddrPat(Pat: String; Var D: AddrType): Boolean;
  {zone:net/node.point, every part may be * or left out (a missing part is anything)}
  Var
    Z, Nt, Nd, Pt: String;
    p: Word;

  Begin
  Z := '*'; Nt := '*'; Nd := '*'; Pt := '*';
  p := Pos(':', Pat);
  If p > 0 Then
    Begin
    Z := Copy(Pat, 1, p - 1);
    Pat := Copy(Pat, p + 1, 40);
    End;
  p := Pos('/', Pat);
  If p > 0 Then
    Begin
    Nt := Copy(Pat, 1, p - 1);
    Pat := Copy(Pat, p + 1, 40);
    End
  Else If (Pat <> '') And (Pos(':', Pat) = 0) And (p = 0) And (Z = '*') Then
    Begin
    {a lone * or a number: anything / that zone}
    Z := Pat;
    Pat := '*';
    End;
  p := Pos('.', Pat);
  If p > 0 Then
    Begin
    Nd := Copy(Pat, 1, p - 1);
    Pt := Copy(Pat, p + 1, 10);
    End
  Else If Pat <> '' Then
    Nd := Pat;
  MatchAddrPat := MatchPart(Z, D.Zone) And MatchPart(Nt, D.Net) And MatchPart(Nd, D.Node) And MatchPart(Pt, D.Point);
  End;


Function RouteMatches(Pats: String; Var D: AddrType): Boolean;
  {blank separated patterns; ! in front = not.  Fits when one of the positive ones does and no ! one, or when there
   are only ! ones and none of them does.}
  Var
    Tok: String;
    p: Word;
    AnyPos, PosHit, NegHit: Boolean;

  Begin
  AnyPos := False;
  PosHit := False;
  NegHit := False;
  Pats := StripBoth(Pats, ' ') + ' ';
  While Length(Pats) > 0 Do
    Begin
    p := Pos(' ', Pats);
    Tok := Copy(Pats, 1, p - 1);
    Pats := StripBoth(Copy(Pats, p + 1, 255), ' ');
    If Pats <> '' Then
      Pats := Pats + ' ';
    If Tok = '' Then
      Continue;
    If Tok[1] = '!' Then
      Begin
      If MatchAddrPat(Copy(Tok, 2, 40), D) Then
        NegHit := True;
      End
    Else
      Begin
      AnyPos := True;
      If MatchAddrPat(Tok, D) Then
        PosHit := True;
      End;
    End;
  RouteMatches := (Not NegHit) And (PosHit Or Not AnyPos);
  End;


Function RouteFor(Var D: AddrType; Var FlavOv: Byte): Word;
  {The system a netmail for the address is sent to: the system itself (it is in the list), the boss of a point, else the
   first route (Netmail Routing) that fits.  0 = no way to send it.  FlavOv: the flavour that route asks for.}
  Var
    B: AddrType;
    R: Word;
    i: Word;

  Begin
  FlavOv := rfDefault;
  R := FindSystem(D);
  If R = 0 Then
    Begin
    B := D;
    B.Point := 0;
    R := FindSystem(B);
    End;
  If (R = 0) And HaveMail Then
    For i := 1 To MaxRoutes Do
      If (MailCfg^.Routes[i].Via >= 1) And (MailCfg^.Routes[i].Via <= 32) And (StripBoth(MailCfg^.Routes[i].Pat, ' ') <> '') Then
        If RouteMatches(MailCfg^.Routes[i].Pat, D) Then
          Begin
          Config^.GetEchoToAddr(MailCfg^.Routes[i].Via, B);
          If B.Zone <> 0 Then
            Begin
            R := MailCfg^.Routes[i].Via;
            FlavOv := MailCfg^.Routes[i].Flav;
            Break;
            End;
          End;
  RouteFor := R;
  End;


Procedure ScanNetArea(Area: Word);
  {netmail that is not sent and not for us}
  Var
    M: AbsMsgPtr;
    C: MsgCopy;
    D: AddrType;
    Sys: Word;
    Flav: Char;
    FlavOv: Byte;
    Us: AddrType;
    Y, Mo, Dy, Dow, H, Mi, Se, Hs: Word;
    Via: String;
    AL: AttachList;
    i: Word;
    FilesOk: Boolean;
    NewSubj: String;

  Begin
  If Not OpenMsgArea(M, Config^.GetMsgAreaId(Area)) Then
    Begin
    Log('cannot open message area ' + Long2Str(Area) + ' (' + Config^.GetMsgName(Area) + ')');
    Problems := True;
    Exit;
    End;
  OurAka(Area, Us);
  M^.SeekFirst(1);
  While M^.SeekFound Do
    Begin
    M^.MsgStartUp;
    M^.GetDest(D);
    If D.Zone = 0 Then
      D.Zone := Us.Zone;
    If (Not M^.IsSent) And (Not M^.IsDeleted) And (D.Net <> 0) And (Not IsOurs(D)) Then
      Begin
      Sys := RouteFor(D, FlavOv);
      If Sys = 0 Then
        Log('netmail #' + Long2Str(M^.GetMsgNum) + ' to ' + AddrStr(D) + ': no route (it is not for a system in the list and no route in Netmail Routing fits)')
      Else
        Begin
        CopyInit(C);
        CopyLoad(M^, C);
        If C.Dest.Zone = 0 Then
          C.Dest.Zone := D.Zone;
        If C.Dest.Net = 0 Then
          C.Dest := D;
        If C.Orig.Zone = 0 Then
          C.Orig := Us;
        Case FlavOv Of
          rfImmediate: Flav := 'I';
          rfCrash: Flav := 'C';
          rfNormal: Flav := 'N';
          rfHold: Flav := 'H';
          rfDirect: Flav := 'D';
          Else
            Begin
            If C.Crash Then
              Flav := 'C'
            Else If C.Hold Then
              Flav := 'H'
            Else
              Flav := FlavourOf(Sys);
            End;
          End;
        Via := '';
        If Not M^.IsLocal Then
          Begin
          {mail passing through: a Via line}
          GetDate(Y, Mo, Dy, Dow);
          GetTime(H, Mi, Se, Hs);
          Via := 'Via ' + AddrStr(Us) + ' @' + Long2Str(Y) + Z2(Mo) + Z2(Dy) + '.' + Z2(H) + Z2(Mi) + Z2(Se) + '.UTC mktoss';
          End;
        FilesOk := True;
        AL.N := 0;
        If C.FAttach Then
          Begin
          {the files: all there before anything is sent; the subject goes out as the plain names}
          ParseAttach(C.Subj, AL);
          NewSubj := '';
          For i := 1 To AL.N Do
            Begin
            If Not FileExist(AttachPath(AL.Name[i])) Then
              Begin
              Log('netmail #' + Long2Str(M^.GetMsgNum) + ' to ' + AddrStr(D) + ': the attached file ' + AttachPath(AL.Name[i]) +
                ' is not there, the netmail waits');
              FilesOk := False;
              End;
            If NewSubj <> '' Then
              NewSubj := NewSubj + ' ';
            NewSubj := NewSubj + BaseName(AL.Name[i]);
            End;
          If AL.N = 0 Then
            Begin
            Log('netmail #' + Long2Str(M^.GetMsgNum) + ' to ' + AddrStr(D) + ' is marked file attach but names no file in the subject: sent without a file');
            C.FAttach := False;
            End
          Else
            C.Subj := NewSubj;
          End;
        If FilesOk Then
          Begin
          For i := 1 To AL.N Do
            If FilesOk Then
              If Not QueueFile(Sys, Flav, AttachPath(AL.Name[i]), AL.Act[i]) Then
                FilesOk := False;
          End;
        If Not FilesOk Then
          Problems := True
        Else If WriteOut(Sys, Flav, C, Area, False, False, Via) Then
          Begin
          Inc(NetSent);
          Log('netmail #' + Long2Str(M^.GetMsgNum) + ' to ' + AddrStr(D) + ' goes to system ' + Long2Str(Sys) + ' (' + Flav + '): ' + C.Subj +
            Copy(' with ' + Long2Str(AL.N) + ' file(s)', 1, 40 * Ord(AL.N > 0)));
          M^.SetSent(True);
          M^.ReWriteHdr;
          If C.KillSent Then
            M^.DeleteMsg;
          End
        Else
          Problems := True;
        CopyFree(C);
        End;
      End;
    M^.SeekNext;
    End;
  If Not CloseMsgArea(M) Then;
  End;


Procedure ScanAreas;
  Var
    i: Word;

  Begin
  For i := 1 To Config^.GetMaxMsgAreas Do
    If Config^.GetMsgName(i) <> '' Then
      Case Config^.GetMsgType(i) Of
        EchoMail: If (StripBoth(Config^.GetEchoAreaTag(i), ' ') <> '') And (Not Config^.GetEchoAreaPassThru(i)) Then
                    ScanEchoArea(i);
        NetMail: ScanNetArea(i);
        End;
  End;


{---------------------------------------------------------------- packing and queueing}

Function DowExt: String;
  Const
    Days: Array[0..6] Of String[2] = ('su', 'mo', 'tu', 'we', 'th', 'fr', 'sa');

  Var
    Y, M, D, Dw: Word;

  Begin
  GetDate(Y, M, D, Dw);
  DowExt := Days[Dw];
  End;


Function BundleName(Sys: Word; Aka: Word; Raw: Boolean): String;
  {an unused name in the spool directory: 8 hex digits from the difference of the addresses (FTS-0005) and the day
   of the week and a digit or letter; a packet that is sent as it is gets a name made of the time}
  Var
    A, B: AddrType;
    Base: String;
    i: Word;
    N: String;

  Begin
  If Raw Then
    Begin
    Repeat
      N := SpoolDir + 'p' + HexStr(NextSerial, 7) + '.pkt';
    Until Not FileExist(N);
    BundleName := N;
    Exit;
    End;
  Config^.GetEchoToAddr(Sys, A);
  Config^.GetAddr(Aka, B);
  Base := HexStr(LongInt(B.Net - A.Net) And $FFFF, 4) + HexStr(LongInt(B.Node - A.Node) And $FFFF, 4);
  For i := 0 To 35 Do
    Begin
    N := SpoolDir + Base + '.' + DowExt + Copy('0123456789abcdefghijklmnopqrstuvwxyz', i + 1, 1);
    If Not FileExist(N) Then
      Begin
      BundleName := N;
      Exit;
      End;
    End;
  BundleName := SpoolDir + 'b' + HexStr(NextSerial, 7) + '.' + DowExt + '0';
  End;


Procedure PackAll;
  {every packet in the spool: into a bundle with the archiver of the system, then to the mailer}
  Var
    SR: SearchRec;
    Names: NameList;
    n, i: Word;
    Sys: Word;
    Flav: Char;
    Pn: Word;
    Cmd, Bundle, Pkt, Q: String;
    Code: Integer;
    SysV: LongInt;
    A: AddrType;
    Rc: LongInt;
    Aka: Word;

  Begin
  n := 0;
  FindFirst(SpoolDir + 's*.pkt', AnyFile, SR);
  While (DosError = 0) And (n < 512) Do
    Begin
    Inc(n);
    Names[n] := SR.Name;
    FindNext(SR);
    End;
  FindClose(SR);
  For i := 1 To n Do
    Begin
    Val(Copy(Names[i], 2, 2), SysV, Code);
    Sys := SysV;
    Flav := UpCase(Names[i][4]);
    Aka := Pos(Names[i][5], '0123456789a') - 1;
    If (Code <> 0) Or (Sys < 1) Or (Sys > 32) Or (Pos(Flav, 'ICNHD') = 0) Or (Aka < 1) Or (Aka > 10) Then
      Continue;
    Config^.GetEchoToAddr(Sys, A);
    If A.Zone = 0 Then
      Continue;
    Pkt := SpoolDir + Names[i];
    Pn := Config^.GetEchoToPacker(Sys);
    Cmd := '';
    If (Pn >= 1) And (Pn <= 7) And Config^.GetPackAvail(Pn) Then
      Cmd := StripBoth(Config^.GetPackCmdLine(Pn), ' ');
    If Cmd <> '' Then
      Begin
      Bundle := BundleName(Sys, Aka, False);
      Rc := fpSystem('cd ' + ShellQuote(Copy(SpoolDir, 1, Length(SpoolDir) - 1)) + ' && ' + Cmd + ' ' +
        ShellQuote(Bundle) + ' ' + ShellQuote(Pkt) + ' >/dev/null 2>&1');
      If (Rc <> 0) Or (Not FileExist(Bundle)) Then
        Begin
        Log('packing ' + Pkt + ' failed (' + Cmd + ', status ' + Long2Str(Rc) + '): the packet stays in the spool');
        Problems := True;
        Continue;
        End;
      Remove(Pkt);
      End
    Else
      Begin
      Bundle := BundleName(Sys, Aka, True);
      Rename2(Pkt, Bundle);
      If Not FileExist(Bundle) Then
        Begin
        Log('cannot rename ' + Pkt + ' to ' + Bundle);
        Problems := True;
        Continue;
        End;
      End;
    Q := ShellQuote(BinkPath) + ' queue -O ' + ShellQuote(Copy(OutDir, 1, Length(OutDir) - 1)) + ' -Z ' + Long2Str(Ours[1].Zone) +
      ' -t ' + AddrStr(A) + ' -F ' + Flav + ' -x ' + ShellQuote(Bundle) + ' >/dev/null 2>&1';
    Rc := fpSystem(Q);
    If Rc <> 0 Then
      Begin
      Log('mkbink queue failed (status ' + Long2Str(Rc) + ') for ' + Bundle + ' to ' + AddrStr(A) + ': the bundle stays in the spool');
      Problems := True;
      End
    Else
      Log('queued ' + Bundle + ' for ' + AddrStr(A) + ' (' + Flav + ')');
    End;
  End;


{---------------------------------------------------------------- one at a time}

Procedure LockInbound;
  {Waits for the lock of the inbound directory: a second mktoss (the mailer's hook, a scan, cron) does not work on the
   same mail at the same time.  The lock goes when the program ends.}
  Var
    Fd: LongInt;

  Begin
  Fd := fpOpen(InDir + 'mktoss.lock', O_WRONLY Or O_CREAT, $1B6);
  If Fd >= 0 Then
    fpFlock(Fd, LOCK_EX);
  End;


{---------------------------------------------------------------- main}

Var
  i: Word;
  A: AddrType;

Begin
Quiet := False;
DoToss := True;
DoScan := True;
Force := False;
BinkProg := '';
i := 1;
While i <= ParamCount Do
  Begin
  If ParamStr(i) = '-q' Then
    Quiet := True
  Else If ParamStr(i) = '-t' Then
    DoScan := False
  Else If ParamStr(i) = '-s' Then
    DoToss := False
  Else If ParamStr(i) = '-f' Then
    Force := True
  Else If ParamStr(i) = '-b' Then
    Begin
    Inc(i);
    BinkProg := ParamStr(i);
    End
  Else If (ParamStr(i) <> '') And (ParamStr(i)[1] <> '-') Then
    {a file name, as the mailer's hook passes them: the whole inbound is tossed}
  Else
    Begin
    WriteLn(StdErr, 'Usage: mktoss [-q] [-t | -s] [-f] [-b mkbink] [file ...]');
    Halt(1);
    End;
  Inc(i);
  End;
If DetectBbsType <> 1 Then
  Begin
  WriteLn(StdErr, 'mktoss: set MK to the BBS configuration directory');
  Halt(1);
  End;
Config := New(MKCfgObjPtr, Init);
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, 'mktoss: ', Config^.GetError, ': error loading the configuration files');
  Halt(1);
  End;
LogName := StripBoth(Config^.GetEchoLog, ' ');
InDir := StripBoth(Config^.GetEchoInPath, ' ');
If InDir = '' Then
  Begin
  WriteLn(StdErr, 'mktoss: no InBound path (EchoMail Options)');
  Halt(1);
  End;
If InDir[Length(InDir)] <> '/' Then
  InDir := InDir + '/';
WorkDir := InDir + 'toss.tmp/';
OutDir := StripBoth(Config^.GetEchoOutPath, ' ');
If OutDir = '' Then
  Begin
  WriteLn(StdErr, 'mktoss: no OutBound path (EchoMail Options)');
  Halt(1);
  End;
If OutDir[Length(OutDir)] <> '/' Then
  OutDir := OutDir + '/';
SpoolDir := OutDir + 'mktoss/';
BbsPath := StripBoth(Config^.GetBbsPath, ' ');
If (BbsPath <> '') And (BbsPath[Length(BbsPath)] <> '/') Then
  BbsPath := BbsPath + '/';
AttachDir := StripBoth(Config^.GetAttachPath, ' ');
If AttachDir = '' Then
  AttachDir := 'attach/';
If AttachDir[1] <> '/' Then
  AttachDir := BbsPath + AttachDir;
If AttachDir[Length(AttachDir)] <> '/' Then
  AttachDir := AttachDir + '/';
BadName := InDir + 'bad/bad.pkt';
{$I-}
MkDir(Copy(WorkDir, 1, Length(WorkDir) - 1));
If IoResult <> 0 Then;
MkDir(Copy(InDir, 1, Length(InDir)) + 'bad');
If IoResult <> 0 Then;
MkDir(Copy(OutDir, 1, Length(OutDir) - 1));
If IoResult <> 0 Then;
MkDir(Copy(SpoolDir, 1, Length(SpoolDir) - 1));
If IoResult <> 0 Then;

NumOurs := 0;
For i := 1 To 10 Do
  Begin
  Config^.GetAddr(i, A);
  If A.Zone <> 0 Then
    Begin
    Inc(NumOurs);
    Ours[NumOurs] := A;
    End;
  End;
HaveMail := Config^.HasMailer;
MailCfg := Nil;
If HaveMail Then
  Begin
  New(MailCfg);
  Config^.GetMailer(MailCfg^);
  End;
If (Not Force) And HaveMail And ((MailCfg^.Flags And mcTosser) = 0) Then
  Begin
  If Not Quiet Then
    WriteLn('The tosser is not switched on in the configuration (EchoMail > Mailer > Tosser); nothing done (-f runs it anyway)');
  Halt(3);
  End;
LockInbound;
LoadSerial;
Tossed := 0; Dups := 0; Bad := 0; Netmails := 0; Passed := 0; Forwarded := 0; Scanned := 0; NetSent := 0; Areafixes := 0;

Problems := False;
Dupes.Init;
Dupes.Open(InDir + 'dupe.mk', 20000);
Dupes.SetDays(14);
Log('mktoss: ' + InDir);
If DoToss Then
  Begin
  TossInbound;
  CountUnsecure;
  End;
If DoScan Then
  ScanAreas;
PackAll;
SaveSerial;
Dupes.CloseFile;
Dupes.Done;
Log('mktoss done: ' + Long2Str(Tossed) + ' tossed, ' + Long2Str(Netmails) + ' netmail, ' + Long2Str(Passed) +
  ' passed through, ' + Long2Str(Dups) + ' duplicates, ' + Long2Str(Bad) + ' bad; ' + Long2Str(Forwarded) +
  ' passed on, ' + Long2Str(Scanned) + ' scanned, ' + Long2Str(NetSent) + ' netmail sent, ' + Long2Str(Areafixes) +
  ' areafix');
If Problems Then
  Halt(2);
End.
