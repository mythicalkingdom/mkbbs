Program MKToss;

{$I MKB.Def}

{
     mktoss [-q] [-t | -s] [-b mkbink]

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
       packet) goes to bad.pkt in the inbound directory, a bad packet is renamed .bad
     - what was tossed is deleted
     - echomail that other systems are linked to is passed on (SEEN-BY and PATH brought up to date), and what the
       BBS wrote itself (local, unexported messages of the echo areas) is scanned and sent; netmail that is not
       sent and not for us is sent on (direct to a system in the list, else through the first system)
     - the outgoing packets are packed with the archiver of the system and given to the mailer: mkbink queue puts
       them in the BSO outbound with the flavour of the system (crash, hold ... for netmail as the message says)

       -t   only toss (and pass on), no scan       -s   only scan (and pack), no toss
       -b   the mkbink program (default: next to mktoss, else in the path)

     Mail in the unsecure inbound (callers without a password) is not tossed, only counted.

     Exit status: 0 = done, 1 = could not start (no configuration), 2 = some mail could not be tossed or sent.
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
    {$I+}
    If IoResult <> 0 Then;
    End;
  End;


{---------------------------------------------------------------- addresses and areas}

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
  {the message is kept in bad.pkt in the inbound directory}
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

Function StoreMessage(Var Src: PktMsgObj; Area: Word; Echo: Boolean): Word;
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
  Dst^.SetSubj(Src.GetSubj);
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
  P.SetPacketInfo(Us, SA, '');
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
  Res := StoreMessage(Pkt, Area, True);
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

  Begin
  Pkt.GetDest(Dst);
  ForUs := IsOurs(Dst);
  Area := FindNetmailArea;
  If Area = 0 Then
    Begin
    BadMessage(Pkt, 'there is no netmail area');
    Exit;
    End;
  Res := StoreMessage(Pkt, Area, False);
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


Function RouteFor(Var D: AddrType): Word;
  {the system a netmail for the address is sent to: the system itself, the boss of a point, else the first system}
  Var
    B: AddrType;
    S: Word;
    R: Word;

  Begin
  R := FindSystem(D);
  If R = 0 Then
    Begin
    B := D;
    B.Point := 0;
    R := FindSystem(B);
    End;
  If R = 0 Then
    For S := 32 DownTo 1 Do
      Begin
      Config^.GetEchoToAddr(S, B);
      If B.Zone <> 0 Then
        R := S;
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
    Us: AddrType;
    Y, Mo, Dy, Dow, H, Mi, Se, Hs: Word;
    Via: String;

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
      If M^.IsFAttach Then
        Log('netmail #' + Long2Str(M^.GetMsgNum) + ' to ' + AddrStr(D) + ' has a file attached: not sent (file attach is not handled yet)')
      Else
        Begin
        Sys := RouteFor(D);
        If Sys = 0 Then
          Log('netmail #' + Long2Str(M^.GetMsgNum) + ' to ' + AddrStr(D) + ': no system to send it to')
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
          If C.Crash Then
            Flav := 'C'
          Else If C.Hold Then
            Flav := 'H'
          Else
            Flav := FlavourOf(Sys);
          Via := '';
          If Not M^.IsLocal Then
            Begin
            {mail passing through: a Via line}
            GetDate(Y, Mo, Dy, Dow);
            GetTime(H, Mi, Se, Hs);
            Via := 'Via ' + AddrStr(Us) + ' @' + Long2Str(Y) + Z2(Mo) + Z2(Dy) + '.' + Z2(H) + Z2(Mi) + Z2(Se) + '.UTC mktoss';
            End;
          If WriteOut(Sys, Flav, C, Area, False, False, Via) Then
            Begin
            Inc(NetSent);
            Log('netmail #' + Long2Str(M^.GetMsgNum) + ' to ' + AddrStr(D) + ' goes to system ' + Long2Str(Sys) + ' (' + Flav + '): ' + C.Subj);
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
    BundleName := SpoolDir + 'p' + HexStr(NextSerial, 7) + '.pkt';
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


{---------------------------------------------------------------- main}

Var
  i: Word;
  A: AddrType;

Begin
Quiet := False;
DoToss := True;
DoScan := True;
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
  Else If ParamStr(i) = '-b' Then
    Begin
    Inc(i);
    BinkProg := ParamStr(i);
    End
  Else
    Begin
    WriteLn(StdErr, 'Usage: mktoss [-q] [-t | -s] [-b mkbink]');
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
BadName := InDir + 'bad.pkt';
{$I-}
MkDir(Copy(WorkDir, 1, Length(WorkDir) - 1));
If IoResult <> 0 Then;
MkDir(Copy(OutDir, 1, Length(OutDir) - 1));
If IoResult <> 0 Then;
MkDir(Copy(SpoolDir, 1, Length(SpoolDir) - 1));
If IoResult <> 0 Then;
{$I+}
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
Tossed := 0; Dups := 0; Bad := 0; Netmails := 0; Passed := 0; Forwarded := 0; Scanned := 0; NetSent := 0;
LastSerial := 0;
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
Dupes.CloseFile;
Dupes.Done;
Log('mktoss done: ' + Long2Str(Tossed) + ' tossed, ' + Long2Str(Netmails) + ' netmail, ' + Long2Str(Passed) +
  ' passed through, ' + Long2Str(Dups) + ' duplicates, ' + Long2Str(Bad) + ' bad; ' + Long2Str(Forwarded) +
  ' passed on, ' + Long2Str(Scanned) + ' scanned, ' + Long2Str(NetSent) + ' netmail sent');
If Problems Then
  Halt(2);
End.
