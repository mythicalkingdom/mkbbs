Unit MKMsgPkt;       {Fidonet style packet msg object}

{$I MKB.Def}

{
     MKMsgPkt - Copyright 1995 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org

     A Message object to handle Fidonet-style message packets (FTS-0001
     type 2, FSC-0039 type 2+).  Follows javascript/MessagePacket.js.

     A packet is a 58 byte header, packed messages and a 00 00 terminator.
     Each packed message is

        Word 2, OrigNode, DestNode, OrigNet, DestNet, Attr, Cost
        date (20 bytes, "DD Mon YY  HH:MM:SS" and a null)
        To (max 35), From (max 35), Subject (max 71), Text  - null terminated

     READING
       The whole packet is read into memory when it is opened and the messages
       are found by walking that structure (not by searching for 00 02: the pair
       also occurs inside headers and ends a text).  Message numbers are the
       positions in the packet, 1 up.  SeekFirst(n) finds the first message
       numbered n or higher, SeekNext / SeekPrior step, SeekFound says whether
       there is one; after that the Get functions read it as for any other
       message base.  Texts come out in CP437 (the BBS character set):
       the packet's ^ACHRS: kludge (UTF-8, LATIN-1, CP437) is honoured, else the
       setting of SetReadCharset (default: find out, UTF-8 or CP437).  The text
       is returned as it is, ^A kludge lines included (GetNoKludgeStr skips them),
       except that the AREA: line is taken out (see GetArea) and SEEN-BY lines are
       given a ^A so that they count as kludges.  GetOrig / GetDest use the INTL,
       FMPT and TOPT kludges, the packet header when there are none.

     WRITING
       StartNewMsg, the Set... functions, DoString... for the text, WriteMsg
       appends the message to the packet at the path (SetMsgPath), creating
       it when it does not exist (SetPacketInfo says who it is from and to).
         netmail:  needs SetDest, SetOrig with zones; INTL / FMPT / TOPT / MSGID are written
         echomail: SetMailType(mmtEchoMail) and SetArea; AREA:, MSGID, tear and
                   origin lines, SEEN-BY and PATH are written (SetEchoTail(False) = not)
       Lines of the text that start with ^A are kludge lines; MSGID: and REPLY:
       among them are used as the message's ids, INTL, FMPT, TOPT and CHRS are
       made by this unit.  ReWriteHdr writes the attribute word of the current
       message back.  DeleteMsg removes the message (the packet is written again).

     A packet has no record locking: calls in other programs that read or write
     the same file at the same moment are not noticed.  Write to packets nobody
     else processes (a new, uniquely named .pkt) and move them to the outbound
     when done.

     Hold for pickup (attribute $0200): SetHold(True) before WriteMsg, or on the
     current message and ReWriteHdr; IsHold reads it.  The unit only keeps the
     bit; a mailer or tosser that makes the packet's mail ready to send acts on it.

     Errors (the result of OpenMsgBase, CreateMsgBase, WriteMsg; DOS errors
     are the usual numbers):
       1000 cannot open   1001 no such packet   1002 no packet name set
       1003 creating a packet needs SetPacketInfo   1004 bad address
       1005 echomail needs SetArea   1006 netmail needs destination and
       origin with zones   1007 the packet is damaged, not changed
       1008 the packet changed since it was opened   1009 a packet exists already
       1010 too short for a packet   1011 not a type 2 packet
       1012 a name is too long (35 bytes)   1013 from or to is missing
       1014 echomail cannot be private   1015 password longer than 8
       1016 no memory
}


Interface

Uses MKGlobT, MKMsgAbs,
  Dos;


Type MKPktHdrType = Record
  OrigNode: Word;
  DestNode: Word;
  Year: Word;
  Month: Word;
  Day: Word;
  Hour: Word;
  Minute: Word;
  Sec: Word;
  Baud: Word;
  PktType: Word;
  OrigNet: Word;
  DestNet: Word;
  ProdCode: Byte;
  Filler: Array[0..32] of Char;
  End;


Type PktDateArray = Array[1..20] of Char;


Type MKPktMsgHdrType = Record
  MsgType: Word;      {always 02}
  OrigNode: Word;
  DestNode: Word;
  OrigNet: Word;
  DestNet: Word;
  Attr: Word;
  Cost: Word;
  DateTime: PktDateArray;
  End;

  {PktMsgHdr is followed by null terminated strings for
  ToName(Max 36), FromName(Max 36), Subject(Max 72),
  and Text(Unbounded)}


Const
  pcAuto = 0;       {SetReadCharset: find out (UTF-8 or CP437)}
  pcCp437 = 1;
  pcUtf8 = 2;
  pcLatin1 = 3;

Type PktByteArr = Array[0..$7FFFFFF0] of Byte;
Type PktBytePtr = ^PktByteArr;
Type PktLongArr = Array[0..$1FFFFFF0] of LongInt;
Type PktLongPtr = ^PktLongArr;


Type MKPktInfoType = Record
  PktHdr: MKPktHdrType;           {header of the packet}
  Error: Word;
  BaseOpened: Boolean;
  FN: String[255];
  {the packet in memory}
  Data: PktBytePtr;
  DataLen: LongInt;
  MsgS: PktLongPtr;               {1..NumMsgs: start of each message}
  MsgE: PktLongPtr;               {end of the text (the null)}
  NumMsgs: LongInt;
  EndPos: LongInt;                {where a new message belongs}
  Clean: Boolean;                 {the structure is whole, may be changed}
  Terminated: Boolean;
  PktOrigAddr: AddrType;          {from the header}
  PktDestAddr: AddrType;
  PktPwdStr: String[8];
  {the current message: read, or being written}
  Cur: LongInt;
  Parsed: LongInt;
  Writing: Boolean;
  LastNum: LongInt;
  Attr: Word;
  Cost: Word;
  PDay, PMon, PYear, PHour, PMin: Word;
  DateOk: Boolean;
  FromStr: String[80];
  ToStr: String[80];
  SubjStr: String[150];
  AreaStr: String[80];
  MsgIdStr: String[200];
  ReplyStr: String[200];
  OrigAddr: AddrType;
  DestAddr: AddrType;
  HaveOrig: Boolean;
  HaveDest: Boolean;
  MailType: MsgMailType;
  NewDate: String[10];            {mm-dd-yy}
  NewTime: String[8];             {hh:mm}
  {the text}
  Txt: PktBytePtr;                {reading: converted text}
  TxtLen: LongInt;
  TxtCap: LongInt;                {size of Txt}
  TxtCtr: LongInt;
  MsgDone: Boolean;
  WBuf: PktBytePtr;               {writing: text so far}
  WLen: LongInt;
  WCap: LongInt;
  {yours}
  YName: String[40];
  YHandle: String[40];
  YFound: Boolean;
  {settings}
  ReadCs: Byte;
  WriteUtf8: Boolean;
  SetOrigAddr: AddrType;          {packet info for a new packet}
  SetDestAddr: AddrType;
  SetPwd: String[8];
  HavePktInfo: Boolean;
  ProdCode: Word;
  Tearline: String[60];
  OriginText: String[60];
  EchoTail: Boolean;
  End;


Type PktMsgObj = Object(AbsMsgObj)
  PI: ^MKPktInfoType;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetMsgPath(MP: String); Virtual; {Set msg path/other info}
  Function  OpenMsgBase: Word; Virtual; {Open the message base}
  Function  CloseMsgBase: Word; Virtual; {Close the message base}
  Function  CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word; Virtual;
  Function  MsgBaseExists: Boolean; Virtual; {Does msg base exist}
  Function  LockMsgBase: Boolean; Virtual; {Lock the message base}
  Function  UnLockMsgBase: Boolean; Virtual; {Unlock the message base}
  Procedure SetDest(Var Addr: AddrType); Virtual; {Set Zone/Net/Node/Point for Dest}
  Procedure SetOrig(Var Addr: AddrType); Virtual; {Set Zone/Net/Node/Point for Orig}
  Procedure SetFrom(Name: String); Virtual; {Set message from}
  Procedure SetTo(Name: String); Virtual; {Set message to}
  Procedure SetSubj(Str: String); Virtual; {Set message subject}
  Procedure SetCost(SCost: Word); Virtual; {Set message cost}
  Procedure SetRefer(SRefer: LongInt); Virtual; {Set message reference}
  Procedure SetSeeAlso(SAlso: LongInt); Virtual; {Set message see also}
  Procedure SetDate(SDate: String); Virtual; {Set message date}
  Procedure SetTime(STime: String); Virtual; {Set message time}
  Procedure SetLocal(LS: Boolean); Virtual; {Set local status}
  Procedure SetRcvd(RS: Boolean); Virtual; {Set received status}
  Procedure SetPriv(PS: Boolean); Virtual; {Set priveledge vs public status}
  Procedure SetCrash(SS: Boolean); Virtual; {Set crash netmail status}
  Procedure SetKillSent(SS: Boolean); Virtual; {Set kill/sent netmail status}
  Procedure SetSent(SS: Boolean); Virtual; {Set sent netmail status}
  Procedure SetFAttach(SS: Boolean); Virtual; {Set file attach status}
  Procedure SetReqRct(SS: Boolean); Virtual; {Set request receipt status}
  Procedure SetReqAud(SS: Boolean); Virtual; {Set request audit status}
  Procedure SetRetRct(SS: Boolean); Virtual; {Set return receipt status}
  Procedure SetFileReq(SS: Boolean); Virtual; {Set file request status}
  Procedure SetHold(HS: Boolean); Virtual;   {hold for pickup (the mailer keeps it until the system calls)}
  Function  IsHold: Boolean; Virtual;        {is current msg held for pickup}
  Procedure DoKludgeLn(Str: String); Virtual; {Add ^A kludge line to msg}
  Procedure DoChar(Ch: Char); Virtual; {Add character to message text}
  Function  WriteMsg: Word; Virtual; {Write msg to msg base}
  Function  GetChar: Char; Virtual; {Get msg text character}
  Function  EOM: Boolean; Virtual; {No more msg text}
  Function  GetFrom: String; Virtual; {Get from name on current msg}
  Function  GetTo: String; Virtual; {Get to name on current msg}
  Function  GetSubj: String; Virtual; {Get subject on current msg}
  Function  GetCost: Word; Virtual; {Get cost of current msg}
  Function  GetDate: String; Virtual; {Get date of current msg}
  Function  GetTime: String; Virtual; {Get time of current msg}
  Function  GetRefer: LongInt; Virtual; {Get reply to of current msg}
  Function  GetSeeAlso: LongInt; Virtual; {Get see also of current msg}
  Function  GetMsgNum: LongInt; Virtual; {Get message number}
  Procedure GetOrig(Var Addr: AddrType); Virtual; {Get origin address}
  Procedure GetDest(Var Addr: AddrType); Virtual; {Get destination address}
  Function  IsLocal: Boolean; Virtual; {Is current msg local}
  Function  IsCrash: Boolean; Virtual; {Is current msg crash}
  Function  IsKillSent: Boolean; Virtual; {Is current msg kill sent}
  Function  IsSent: Boolean; Virtual; {Is current msg sent}
  Function  IsFAttach: Boolean; Virtual; {Is current msg file attach}
  Function  IsReqRct: Boolean; Virtual; {Is current msg request receipt}
  Function  IsReqAud: Boolean; Virtual; {Is current msg request audit}
  Function  IsRetRct: Boolean; Virtual; {Is current msg a return receipt}
  Function  IsFileReq: Boolean; Virtual; {Is current msg a file request}
  Function  IsRcvd: Boolean; Virtual; {Is current msg received}
  Function  IsPriv: Boolean; Virtual; {Is current msg priviledged/private}
  Function  IsDeleted: Boolean; Virtual; {Is current msg deleted}
  Function  IsEchoed: Boolean; Virtual; {Is current msg unmoved echomail msg}
  Function  GetMsgLoc: LongInt; Virtual; {To allow reseeking to message}
  Procedure SetMsgLoc(ML: LongInt); Virtual; {Reseek to message}
  Procedure MsgStartUp; Virtual; {Do message set-up tasks}
  Procedure MsgTxtStartUp; Virtual; {Do message text start up tasks}
  Procedure StartNewMsg; Virtual; {Initialize for adding message}
  Procedure SeekFirst(MsgNum: LongInt); Virtual; {Start msg seek}
  Procedure SeekNext; Virtual; {Find next matching msg}
  Procedure SeekPrior; Virtual; {Prior msg}
  Function  SeekFound: Boolean; Virtual; {Msg was found}
  Procedure YoursFirst(Name: String; Handle: String); Virtual; {Seek your mail}
  Procedure YoursNext; Virtual; {Seek next your mail}
  Function  YoursFound: Boolean; Virtual; {Message found}
  Function  GetHighMsgNum: LongInt; Virtual; {Get highest msg number}
  Procedure SetMailType(MT: MsgMailType); Virtual; {Set message base type}
  Procedure ReWriteHdr; Virtual; {Rewrite msg header after changes}
  Procedure DeleteMsg; Virtual; {Delete current message}
  Procedure SetEcho(ES: Boolean); Virtual; {Set echo status}
  Function  NumberOfMsgs: LongInt; Virtual; {Number of messages}
  Function  GetLastRead(UNum: LongInt): LongInt; Virtual; {Get last read for user num}
  Procedure SetLastRead(UNum: LongInt; LR: LongInt); Virtual; {Set last read}
  Function  GetTxtPos: LongInt; Virtual; {Get indicator of msg text position}
  Procedure SetTxtPos(TP: LongInt); Virtual; {Set text position}
  Procedure ScanPkt; Virtual; {Find the messages of the packet}
  {packets only}
  Procedure SetPacketInfo(Var POrig, PDest: AddrType; Pwd: String); {header of a new packet}
  Procedure SetProductCode(PC: Word);
  Procedure SetReadCharset(Cs: Byte);        {pcAuto, pcCp437, pcUtf8, pcLatin1}
  Procedure SetWriteUtf8(U: Boolean);        {write texts as UTF-8 (adds ^ACHRS: UTF-8 4), default CP437}
  Procedure SetArea(Area: String);           {echomail area of the message being written}
  Procedure SetMsgId(Id: String);
  Procedure SetReplyId(Id: String);
  Procedure SetTearline(S: String);
  Procedure SetOriginText(S: String);
  Procedure SetEchoTail(B: Boolean);
  Function  GetArea: String;                 {AREA: of the current message}
  Function  GetMsgId: String;
  Function  GetReplyId: String;
  Function  GetAttr: Word;                   {attribute word of the current message}
  Procedure GetPktOrig(Var Addr: AddrType);  {header of the packet}
  Procedure GetPktDest(Var Addr: AddrType);
  Function  GetPktPassword: String;
  Function  PktClean: Boolean;               {the structure of the packet is whole}
  End;


Type PktMsgPtr = ^PktMsgObj;


Implementation


Uses MKFile, MKString, MKCp437, BaseUnix;


Const
  PktHeaderLen = 58;
  MaxName = 35;
  MaxSubject = 71;
  MonNames: Array[1..12] of String[3] = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

  atPrivate = $0001;
  atCrash = $0002;
  atRcvd = $0004;
  atSent = $0008;
  atFAttach = $0010;
  atKillSent = $0080;
  atHold = $0200;                  {hold for pickup}
  atLocal = $0100;
  atFileReq = $0800;
  atReqRct = $1000;
  atRetRct = $2000;
  atReqAud = $4000;

Var
  LastSerial: LongInt;


{---------------------------------------------------------------- small helpers}

Function Z2(N: LongInt): String;
  Var
    S: String[12];

  Begin
  Str(N, S);
  If Length(S) < 2 Then
    S := '0' + S;
  Z2 := S;
  End;


Function GetU16(D: PktBytePtr; Pos: LongInt): Word;
  Begin
  GetU16 := D^[Pos] + (D^[Pos + 1] Shl 8);
  End;


Procedure PutU16(D: PktBytePtr; Pos: LongInt; W: Word);
  Begin
  D^[Pos] := W And $FF;
  D^[Pos + 1] := W Shr 8;
  End;


Function IndexZero(D: PktBytePtr; From, Len: LongInt): LongInt;
  {position of the next null at or after From, -1 = none}
  Begin
  While From < Len Do
    Begin
    If D^[From] = 0 Then
      Begin
      IndexZero := From;
      Exit;
      End;
    Inc(From);
    End;
  IndexZero := -1;
  End;


Function AddrToStr(Var A: AddrType): String;
  {zone:net/node.point, no zone when 0, no point when 0}
  Var
    S: String;

  Begin
  S := '';
  If A.Zone <> 0 Then
    S := Long2Str(A.Zone) + ':';
  S := S + Long2Str(A.Net) + '/' + Long2Str(A.Node);
  If A.Point <> 0 Then
    S := S + '.' + Long2Str(A.Point);
  AddrToStr := S;
  End;


Function NextSerial: String;
  {message id serials do not repeat in this process}
  Var
    T: TTime;
    L: LongInt;
    S: String;
    i: Word;
    N: LongInt;

  Begin
  T := fpTime;
  L := T;
  If L <= LastSerial Then
    L := LastSerial + 1;
  LastSerial := L;
  S := '';
  N := L;
  For i := 1 To 8 Do
    Begin
    S := Copy('0123456789abcdef', (N And 15) + 1, 1) + S;
    N := (N Shr 4) And $0FFFFFFF;
    End;
  NextSerial := S;
  End;


Function FlagSet(W: Word; Mask: Word; On: Boolean): Word;
  Begin
  If On Then
    FlagSet := W Or Mask
  Else
    FlagSet := W And Not Mask;
  End;


Function BytesStart(P: PktBytePtr; Pos, Len: LongInt; Const Pat: String): Boolean;
  {the bytes at Pos begin with Pat, not case sensitive}
  Var
    i: Word;
    A, B: Char;

  Begin
  BytesStart := False;
  If Pos + Length(Pat) > Len Then
    Exit;
  For i := 1 To Length(Pat) Do
    Begin
    A := UpCase(Chr(P^[Pos + i - 1]));
    B := UpCase(Pat[i]);
    If A <> B Then
      Exit;
    End;
  BytesStart := True;
  End;


Function BytesToStr(P: PktBytePtr; Pos, Len: LongInt; Max: Word): String;
  {the bytes Pos..Len - 1 (at most Max) as a string}
  Var
    n: LongInt;
    S: String;

  Begin
  n := Len - Pos;
  If n > Max Then
    n := Max;
  If n < 0 Then
    n := 0;
  If n > 0 Then
    Move(P^[Pos], S[1], n);
  S[0] := Chr(n);
  BytesToStr := S;
  End;


{---------------------------------------------------------------- character sets}

Const
  csAuto = 0;
  csCp437 = 1;
  csUtf8 = 2;
  csLatin1 = 3;


Function CsFromChrs(Value: String): Byte;
  {the ^ACHRS: kludge (FTS-5003); 255 = not known}
  Var
    W: String;

  Begin
  W := Upper(ExtractWord(Value, 1));
  CsFromChrs := 255;
  If (W = 'UTF-8') Or (W = 'UTF8') Then
    CsFromChrs := csUtf8
  Else If (W = 'LATIN-1') Or (W = 'CP819') Or (W = 'ISO-8859-1') Or (W = 'ASCII') Then
    CsFromChrs := csLatin1
  Else If (W = 'CP437') Or (W = 'IBMPC') Then
    CsFromChrs := csCp437;
  End;


Function ValidUtf8(P: PktBytePtr; Len: LongInt): Boolean;
  Var
    i: LongInt;
    n, k: Word;
    c: Byte;
    U: LongInt;

  Begin
  ValidUtf8 := False;
  i := 0;
  While i < Len Do
    Begin
    c := P^[i];
    If c < $80 Then
      Begin
      Inc(i);
      Continue;
      End;
    If (c >= $C2) And (c <= $DF) Then
      n := 1
    Else If (c >= $E0) And (c <= $EF) Then
      n := 2
    Else If (c >= $F0) And (c <= $F4) Then
      n := 3
    Else
      Exit;
    If i + n >= Len Then
      Exit;
    U := c And (($3F) Shr n);
    For k := 1 To n Do
      Begin
      If (P^[i + k] And $C0) <> $80 Then
        Exit;
      U := (U Shl 6) Or (P^[i + k] And $3F);
      End;
    If (n = 2) And ((U < $800) Or ((U >= $D800) And (U <= $DFFF))) Then
      Exit;
    If (n = 3) And ((U < $10000) Or (U > $10FFFF)) Then
      Exit;
    Inc(i, n + 1);
    End;
  ValidUtf8 := True;
  End;


Procedure DecodeBuf(Src: PktBytePtr; SLen: LongInt; Enc: Byte; IsText: Boolean;
  Dst: PktBytePtr; Var DLen: LongInt);
  {Src in the character set Enc, Dst in CP437 (at most as long as Src).  Text: the soft
   carriage return $8D of FTN texts is dropped (not when the text is UTF-8, where it is a
   continuation byte).  What CP437 has no character for becomes ?}
  Var
    i: LongInt;
    c: Byte;
    n, k: Word;
    U: LongInt;
    Ascii: Boolean;
    Cp: Byte;

  Begin
  DLen := 0;
  If Enc = csAuto Then
    Begin
    Ascii := True;
    For i := 0 To SLen - 1 Do
      If Src^[i] > $7F Then
        Begin
        Ascii := False;
        Break;
        End;
    If Ascii Then
      Enc := csCp437
    Else If ValidUtf8(Src, SLen) Then
      Enc := csUtf8
    Else
      Enc := csCp437;
    End;
  i := 0;
  While i < SLen Do
    Begin
    c := Src^[i];
    If (Enc <> csUtf8) And IsText And (c = $8D) Then
      Begin
      Inc(i);
      Continue;
      End;
    If c < $80 Then
      Begin
      Dst^[DLen] := c;
      Inc(DLen);
      Inc(i);
      Continue;
      End;
    Case Enc Of
      csCp437:
        Begin
        Dst^[DLen] := c;
        Inc(DLen);
        Inc(i);
        End;
      csLatin1:
        Begin
        Cp := Utf8ToCp437(c);
        If Cp = 0 Then
          Cp := Ord('?');
        Dst^[DLen] := Cp;
        Inc(DLen);
        Inc(i);
        End;
      Else
        Begin
        {UTF-8}
        If (c >= $C2) And (c <= $DF) Then
          n := 1
        Else If (c >= $E0) And (c <= $EF) Then
          n := 2
        Else If (c >= $F0) And (c <= $F4) Then
          n := 3
        Else
          n := 0;
        U := -1;
        If (n > 0) And (i + n < SLen) Then
          Begin
          U := c And (($3F) Shr n);
          For k := 1 To n Do
            If (Src^[i + k] And $C0) <> $80 Then
              U := -1
            Else If U >= 0 Then
              U := (U Shl 6) Or (Src^[i + k] And $3F);
          End;
        If (U >= 0) And (U < $10000) Then
          Begin
          Cp := Utf8ToCp437(U);
          If Cp = 0 Then
            Cp := Ord('?');
          Dst^[DLen] := Cp;
          Inc(DLen);
          Inc(i, n + 1);
          End
        Else If U >= $10000 Then
          Begin
          Dst^[DLen] := Ord('?');
          Inc(DLen);
          Inc(i, n + 1);
          End
        Else
          Begin
          Dst^[DLen] := Ord('?');
          Inc(DLen);
          Inc(i);
          End;
        End;
      End;
    End;
  End;


Function DecodeStr(S: String; Enc: Byte): String;
  Var
    A, B: Array[0..255] Of Byte;
    n: LongInt;
    R: String;

  Begin
  If Length(S) = 0 Then
    Begin
    DecodeStr := '';
    Exit;
    End;
  Move(S[1], A[0], Length(S));
  DecodeBuf(@A, Length(S), Enc, False, @B, n);
  If n > 0 Then
    Move(B[0], R[1], n);
  R[0] := Chr(n);
  DecodeStr := R;
  End;


Function EncodeStr(S: String; Utf8: Boolean; Max: Word; Var Cut: Boolean): String;
  {a name or subject for the packet: control characters become blanks, in UTF-8 when asked,
   at most Max bytes (a UTF-8 character is not cut in half)}
  Var
    i: Word;
    R: String;
    T: String;

  Begin
  R := '';
  For i := 1 To Length(S) Do
    Begin
    If S[i] < ' ' Then
      S[i] := ' ';
    If Utf8 And (S[i] >= #128) Then
      T := Cp437ToUtf8(Ord(S[i]))
    Else
      T := S[i];
    If Length(R) + Length(T) > 250 Then
      Begin
      Cut := True;
      Break;
      End;
    R := R + T;
    End;
  Cut := Cut Or False;
  If Length(R) > Max Then
    Begin
    Cut := True;
    i := Max;
    If Utf8 Then
      While (i > 0) And ((Ord(R[i + 1]) And $C0) = $80) Do
        Dec(i);
    R[0] := Chr(i);
    End;
  EncodeStr := R;
  End;


{---------------------------------------------------------------- the packet structure}

Procedure WalkPkt(D: PktBytePtr; Len: LongInt; S, E: PktLongPtr; Var Count, EndPos: LongInt;
  Var Clean, Term: Boolean);
  {The messages of a packet by walking the structure.  S, E (1..) are filled when not Nil.
   Clean is False when the structure is not whole: nothing is appended to such a packet.}
  Var
    Pos, p, z, e2: LongInt;
    Typ: Word;
    k: Word;
    Ok: Boolean;

  Begin
  Pos := PktHeaderLen;
  Count := 0;
  Clean := True;
  Term := False;
  While Pos + 2 <= Len Do
    Begin
    Typ := GetU16(D, Pos);
    If Typ = 0 Then
      Begin
      Term := True;
      Break;
      End;
    If Typ <> 2 Then
      Begin
      Clean := False;
      Break;
      End;
    p := Pos + 14;
    Ok := p <= Len;
    For k := 1 To 4 Do
      If Ok Then
        Begin
        z := IndexZero(D, p, Len);
        If z < 0 Then
          Ok := False
        Else
          p := z + 1;
        End;
    If Not Ok Then
      Begin
      Clean := False;
      Break;
      End;
    z := IndexZero(D, p, Len);
    If z < 0 Then
      Begin
      Clean := False;
      e2 := Len;
      End
    Else
      e2 := z;
    Inc(Count);
    If S <> Nil Then
      Begin
      S^[Count] := Pos;
      E^[Count] := e2;
      End;
    If z < 0 Then
      Pos := Len
    Else
      Pos := z + 1;
    End;
  If (Not Term) And Clean And (Pos < Len) Then
    Clean := False;
  EndPos := Pos;
  End;


{---------------------------------------------------------------- object: set up}

Constructor PktMsgObj.Init;
  Begin
  New(PI);
  If PI = Nil Then
    Begin
    Fail;
    Exit;
    End;
  FillChar(PI^, SizeOf(PI^), #0);
  PI^.ReadCs := csAuto;
  PI^.Tearline := 'mkbbs';
  PI^.OriginText := 'mkbbs';
  PI^.EchoTail := True;
  PI^.MailType := mmtNormal;
  End;


Destructor PktMsgObj.Done;
  Begin
  If PI^.BaseOpened Then
    PI^.Error := CloseMsgBase;
  If PI^.WBuf <> Nil Then
    FreeMem(PI^.WBuf, PI^.WCap);
  Dispose(PI);
  End;


Procedure PktMsgObj.SetMsgPath(MP: String);
  Begin
  PI^.FN := MP;
  End;


Procedure FreeMsg(Var PI: MKPktInfoType);
  {the text of the current message}
  Begin
  If PI.Txt <> Nil Then
    FreeMem(PI.Txt, PI.TxtCap);
  PI.Txt := Nil;
  PI.TxtLen := 0;
  PI.TxtCap := 0;
  End;


Procedure FreeData(Var PI: MKPktInfoType);
  Begin
  FreeMsg(PI);
  If PI.Data <> Nil Then
    FreeMem(PI.Data, PI.DataLen);
  PI.Data := Nil;
  If PI.MsgS <> Nil Then
    FreeMem(PI.MsgS, (PI.NumMsgs + 1) * 4);
  If PI.MsgE <> Nil Then
    FreeMem(PI.MsgE, (PI.NumMsgs + 1) * 4);
  PI.MsgS := Nil;
  PI.MsgE := Nil;
  PI.DataLen := 0;
  PI.NumMsgs := 0;
  PI.Parsed := 0;
  End;


Function ReadWhole(Const FN: String; Var P: PktBytePtr; Var Len: LongInt): Word;
  {the file in memory; 0 or an error number}
  Var
    F: File;
    SaveMode: Byte;
    Got, Chunk, Off: LongInt;

  Begin
  P := Nil;
  Len := 0;
  SaveMode := FileMode;
  FileMode := fmReadOnly + fmDenyNone;
  Assign(F, FN);
  Reset(F, 1);
  FileMode := SaveMode;
  If IoResult <> 0 Then
    Begin
    ReadWhole := 1000;
    Exit;
    End;
  Len := FileSize(F);
  If IoResult <> 0 Then
    Len := 0;
  If Len > 0 Then
    Begin
    GetMem(P, Len);
    If P = Nil Then
      Begin
      Close(F);
      Len := 0;
      ReadWhole := 1016;
      Exit;
      End;
    End;
  Off := 0;
  While Off < Len Do
    Begin
    Chunk := Len - Off;
    If Chunk > 32768 Then
      Chunk := 32768;
    BlockRead(F, P^[Off], Chunk, Got);
    If (IoResult <> 0) Or (Got <= 0) Then
      Begin
      Len := Off;
      Break;
      End;
    Inc(Off, Got);
    End;
  Close(F);
  If IoResult <> 0 Then;
  ReadWhole := 0;
  End;


Procedure PktMsgObj.ScanPkt;
  {Find the messages of the packet in memory}
  Begin
  With PI^ Do
    Begin
    If MsgS <> Nil Then
      FreeMem(MsgS, (NumMsgs + 1) * 4);
    If MsgE <> Nil Then
      FreeMem(MsgE, (NumMsgs + 1) * 4);
    MsgS := Nil;
    MsgE := Nil;
    WalkPkt(Data, DataLen, Nil, Nil, NumMsgs, EndPos, Clean, Terminated);
    GetMem(MsgS, (NumMsgs + 1) * 4);
    GetMem(MsgE, (NumMsgs + 1) * 4);
    WalkPkt(Data, DataLen, MsgS, MsgE, NumMsgs, EndPos, Clean, Terminated);
    End;
  End;


Procedure ParseHeader(Var PI: MKPktInfoType);
  Var
    OrigNet, AuxNet: Word;
    i: Word;

  Begin
  With PI Do
    Begin
    Move(Data^[0], PktHdr, SizeOf(PktHdr));
    OrigNet := GetU16(Data, 20);
    AuxNet := GetU16(Data, 38);
    If (OrigNet = $FFFF) And (AuxNet <> 0) Then
      OrigNet := AuxNet;
    PktOrigAddr.Zone := GetU16(Data, 34);
    If PktOrigAddr.Zone = 0 Then
      PktOrigAddr.Zone := GetU16(Data, 46);
    PktDestAddr.Zone := GetU16(Data, 36);
    If PktDestAddr.Zone = 0 Then
      PktDestAddr.Zone := GetU16(Data, 48);
    PktOrigAddr.Net := OrigNet;
    PktOrigAddr.Node := GetU16(Data, 0);
    PktOrigAddr.Point := GetU16(Data, 50);
    PktDestAddr.Net := GetU16(Data, 22);
    PktDestAddr.Node := GetU16(Data, 2);
    PktDestAddr.Point := GetU16(Data, 52);
    PktPwdStr := '';
    For i := 26 To 33 Do
      Begin
      If Data^[i] = 0 Then
        Break;
      PktPwdStr := PktPwdStr + Chr(Data^[i]);
      End;
    End;
  End;


Function LoadPacket(Var PI: MKPktInfoType): Word;
  {read the packet at FN and index it}
  Var
    Res: Word;

  Begin
  FreeData(PI);
  Res := ReadWhole(PI.FN, PI.Data, PI.DataLen);
  If Res <> 0 Then
    Begin
    LoadPacket := Res;
    Exit;
    End;
  If PI.DataLen < PktHeaderLen Then
    Begin
    FreeData(PI);
    LoadPacket := 1010;
    Exit;
    End;
  If GetU16(PI.Data, 18) <> 2 Then
    Begin
    FreeData(PI);
    LoadPacket := 1011;
    Exit;
    End;
  ParseHeader(PI);
  GetMem(PI.MsgS, 4);
  GetMem(PI.MsgE, 4);
  LoadPacket := 0;
  End;


Function PktMsgObj.OpenMsgBase: Word;
  Begin
  PI^.Error := 0;
  If PI^.FN = '' Then
    PI^.Error := 1002
  Else If Not FileExist(PI^.FN) Then
    PI^.Error := 1001;
  If PI^.Error = 0 Then
    PI^.Error := LoadPacket(PI^);
  If PI^.Error = 0 Then
    Begin
    FreeMem(PI^.MsgS, 4);
    FreeMem(PI^.MsgE, 4);
    PI^.MsgS := Nil;
    PI^.MsgE := Nil;
    ScanPkt;
    PI^.Cur := 0;
    PI^.Parsed := 0;
    PI^.Writing := False;
    End;
  PI^.BaseOpened := (PI^.Error = 0);
  OpenMsgBase := PI^.Error;
  End;


Function PktMsgObj.CloseMsgBase: Word;
  Begin
  If PI^.BaseOpened Then
    Begin
    FreeData(PI^);
    PI^.BaseOpened := False;
    End;
  PI^.Cur := 0;
  PI^.Parsed := 0;
  CloseMsgBase := 0;
  End;


Function PktMsgObj.LockMsgBase: Boolean;
  Begin
  LockMsgBase := True;
  End;


Function PktMsgObj.UnLockMsgBase: Boolean;
  Begin
  UnLockMsgBase := True;
  End;


Function PktMsgObj.MsgBaseExists: Boolean;
  Begin
  MsgBaseExists := FileExist(PI^.FN);
  End;


{---------------------------------------------------------------- setting message fields}

Procedure PktMsgObj.SetDest(Var Addr: AddrType);
  Begin
  PI^.DestAddr := Addr;
  PI^.HaveDest := True;
  End;


Procedure PktMsgObj.SetOrig(Var Addr: AddrType);
  Begin
  PI^.OrigAddr := Addr;
  PI^.HaveOrig := True;
  End;


Procedure PktMsgObj.SetFrom(Name: String);
  Begin
  PI^.FromStr := Copy(Name, 1, 80);
  End;


Procedure PktMsgObj.SetTo(Name: String);
  Begin
  PI^.ToStr := Copy(Name, 1, 80);
  End;


Procedure PktMsgObj.SetSubj(Str: String);
  Begin
  PI^.SubjStr := Copy(Str, 1, 150);
  End;


Procedure PktMsgObj.SetCost(SCost: Word);
  Begin
  PI^.Cost := SCost;
  End;


Procedure PktMsgObj.SetRefer(SRefer: LongInt);
  Begin
  End;


Procedure PktMsgObj.SetSeeAlso(SAlso: LongInt);
  Begin
  End;


Procedure PktMsgObj.SetDate(SDate: String);
  {mm-dd-yy}
  Begin
  PI^.NewDate := Copy(SDate, 1, 10);
  End;


Procedure PktMsgObj.SetTime(STime: String);
  {hh:mm}
  Begin
  PI^.NewTime := Copy(STime, 1, 8);
  End;


Procedure PktMsgObj.SetLocal(LS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atLocal, LS);
  End;


Procedure PktMsgObj.SetRcvd(RS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atRcvd, RS);
  End;


Procedure PktMsgObj.SetPriv(PS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atPrivate, PS);
  End;


Procedure PktMsgObj.SetCrash(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atCrash, SS);
  End;


Procedure PktMsgObj.SetKillSent(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atKillSent, SS);
  End;


Procedure PktMsgObj.SetSent(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atSent, SS);
  End;


Procedure PktMsgObj.SetFAttach(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atFAttach, SS);
  End;


Procedure PktMsgObj.SetReqRct(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atReqRct, SS);
  End;


Procedure PktMsgObj.SetReqAud(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atReqAud, SS);
  End;


Procedure PktMsgObj.SetRetRct(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atRetRct, SS);
  End;


Procedure PktMsgObj.SetFileReq(SS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atFileReq, SS);
  End;


Procedure PktMsgObj.SetHold(HS: Boolean);
  Begin
  PI^.Attr := FlagSet(PI^.Attr, atHold, HS);
  End;


Procedure PktMsgObj.SetEcho(ES: Boolean);
  Begin
  If ES Then
    PI^.MailType := mmtEchoMail
  Else If PI^.MailType = mmtEchoMail Then
    PI^.MailType := mmtNormal;
  End;


Procedure PktMsgObj.SetMailType(MT: MsgMailType);
  Begin
  PI^.MailType := MT;
  End;


Procedure PktMsgObj.SetArea(Area: String);
  Begin
  PI^.AreaStr := Copy(Area, 1, 80);
  End;


Procedure PktMsgObj.SetMsgId(Id: String);
  Begin
  PI^.MsgIdStr := Copy(Id, 1, 200);
  End;


Procedure PktMsgObj.SetReplyId(Id: String);
  Begin
  PI^.ReplyStr := Copy(Id, 1, 200);
  End;


Procedure PktMsgObj.SetPacketInfo(Var POrig, PDest: AddrType; Pwd: String);
  Begin
  PI^.SetOrigAddr := POrig;
  PI^.SetDestAddr := PDest;
  PI^.SetPwd := Copy(Pwd, 1, 8);
  PI^.HavePktInfo := True;
  End;


Procedure PktMsgObj.SetProductCode(PC: Word);
  Begin
  PI^.ProdCode := PC;
  End;


Procedure PktMsgObj.SetReadCharset(Cs: Byte);
  Begin
  PI^.ReadCs := Cs;
  End;


Procedure PktMsgObj.SetWriteUtf8(U: Boolean);
  Begin
  PI^.WriteUtf8 := U;
  End;


Procedure PktMsgObj.SetTearline(S: String);
  Begin
  PI^.Tearline := Copy(S, 1, 60);
  End;


Procedure PktMsgObj.SetOriginText(S: String);
  Begin
  PI^.OriginText := Copy(S, 1, 60);
  End;


Procedure PktMsgObj.SetEchoTail(B: Boolean);
  Begin
  PI^.EchoTail := B;
  End;


Procedure PktMsgObj.DoKludgeLn(Str: String);
  Begin
  If (Length(Str) = 0) Or (Str[1] <> #1) Then
    Str := #1 + Str;
  DoStringLn(Str);
  End;


Procedure PktMsgObj.DoChar(Ch: Char);
  Var
    NewCap: LongInt;
    NewBuf: PktBytePtr;

  Begin
  If Ch = #0 Then
    Exit;
  With PI^ Do
    Begin
    If WLen >= WCap Then
      Begin
      NewCap := WCap + WCap Div 2 + 4096;
      GetMem(NewBuf, NewCap);
      If WBuf <> Nil Then
        Begin
        Move(WBuf^, NewBuf^, WLen);
        FreeMem(WBuf, WCap);
        End;
      WBuf := NewBuf;
      WCap := NewCap;
      End;
    WBuf^[WLen] := Ord(Ch);
    Inc(WLen);
    End;
  End;


Procedure PktMsgObj.StartNewMsg;
  Begin
  With PI^ Do
    Begin
    Writing := True;
    Attr := 0;
    Cost := 0;
    FromStr := '';
    ToStr := '';
    SubjStr := '';
    AreaStr := '';
    MsgIdStr := '';
    ReplyStr := '';
    NewDate := '';
    NewTime := '';
    HaveOrig := False;
    HaveDest := False;
    FillChar(OrigAddr, SizeOf(OrigAddr), 0);
    FillChar(DestAddr, SizeOf(DestAddr), 0);
    MailType := mmtNormal;
    WLen := 0;
    End;
  End;


{---------------------------------------------------------------- writing}

Type
  OutBuf = Record
    P: PktBytePtr;
    Len: LongInt;
    Cap: LongInt;
    End;


Procedure OutAdd(Var O: OutBuf; Const Src; N: LongInt);
  Var
    NewCap: LongInt;
    NewBuf: PktBytePtr;

  Begin
  If N <= 0 Then
    Exit;
  If O.Len + N > O.Cap Then
    Begin
    NewCap := O.Cap * 2 + N + 4096;
    GetMem(NewBuf, NewCap);
    If O.P <> Nil Then
      Begin
      Move(O.P^, NewBuf^, O.Len);
      FreeMem(O.P, O.Cap);
      End;
    O.P := NewBuf;
    O.Cap := NewCap;
    End;
  Move(Src, O.P^[O.Len], N);
  Inc(O.Len, N);
  End;


Procedure OutStr(Var O: OutBuf; S: String);
  Begin
  If Length(S) > 0 Then
    OutAdd(O, S[1], Length(S));
  End;


Procedure OutByte(Var O: OutBuf; B: Byte);
  Begin
  OutAdd(O, B, 1);
  End;


Procedure OutWord(Var O: OutBuf; W: Word);
  Var
    B: Array[0..1] Of Byte;

  Begin
  B[0] := W And $FF;
  B[1] := W Shr 8;
  OutAdd(O, B, 2);
  End;


Procedure OutText(Var O: OutBuf; P: PktBytePtr; Pos, Len: LongInt; Utf8: Boolean);
  {text bytes (CP437), as UTF-8 when asked}
  Var
    i, StartRun: LongInt;
    U: String;

  Begin
  If Not Utf8 Then
    Begin
    If Len > Pos Then
      OutAdd(O, P^[Pos], Len - Pos);
    Exit;
    End;
  StartRun := Pos;
  i := Pos;
  While i < Len Do
    Begin
    If P^[i] >= $80 Then
      Begin
      If i > StartRun Then
        OutAdd(O, P^[StartRun], i - StartRun);
      U := Cp437ToUtf8(P^[i]);
      OutStr(O, U);
      StartRun := i + 1;
      End;
    Inc(i);
    End;
  If Len > StartRun Then
    OutAdd(O, P^[StartRun], Len - StartRun);
  End;


Type SbNodeType = Record
  Net: Word;
  Node: Word;
  End;


Function SeenByLine(Var A, B: AddrType; HasB: Boolean): String;
  {FTS-0004 two dimensional SEEN-BY: sorted, the net only when it changes}
  Var
    N: Array[1..2] Of SbNodeType;
    Cnt: Word;
    S: String;
    T: SbNodeType;

  Begin
  N[1].Net := A.Net;
  N[1].Node := A.Node;
  Cnt := 1;
  If HasB And ((B.Net <> A.Net) Or (B.Node <> A.Node)) Then
    Begin
    N[2].Net := B.Net;
    N[2].Node := B.Node;
    Cnt := 2;
    End;
  If Cnt = 2 Then
    If (N[2].Net < N[1].Net) Or ((N[2].Net = N[1].Net) And (N[2].Node < N[1].Node)) Then
      Begin
      T := N[1];
      N[1] := N[2];
      N[2] := T;
      End;
  S := 'SEEN-BY: ' + Long2Str(N[1].Net) + '/' + Long2Str(N[1].Node);
  If Cnt = 2 Then
    Begin
    If N[2].Net = N[1].Net Then
      S := S + ' ' + Long2Str(N[2].Node)
    Else
      S := S + ' ' + Long2Str(N[2].Net) + '/' + Long2Str(N[2].Node);
    End;
  SeenByLine := S;
  End;


Function BuildHeader(Var PI: MKPktInfoType; Var H: Array Of Byte): Word;
  {the 58 byte header of a new packet from the packet info}
  Var
    Y, Mo, D, Dow, Hr, Mi, Se, Hs: Word;
    i: Word;
    Code: Word;

  Begin
  BuildHeader := 0;
  If Not PI.HavePktInfo Then
    Begin
    BuildHeader := 1003;
    Exit;
    End;
  If Length(PI.SetPwd) > 8 Then
    Begin
    BuildHeader := 1015;
    Exit;
    End;
  FillChar(H, PktHeaderLen, 0);
  GetDate(Y, Mo, D, Dow);
  GetTime(Hr, Mi, Se, Hs);
  Code := PI.ProdCode;
  PutU16(@H, 0, PI.SetOrigAddr.Node);
  PutU16(@H, 2, PI.SetDestAddr.Node);
  PutU16(@H, 4, Y);
  PutU16(@H, 6, Mo - 1);                      {0 - 11}
  PutU16(@H, 8, D);
  PutU16(@H, 10, Hr);
  PutU16(@H, 12, Mi);
  PutU16(@H, 14, Se);
  PutU16(@H, 16, 0);                          {baud}
  PutU16(@H, 18, 2);                          {packet type}
  PutU16(@H, 20, PI.SetOrigAddr.Net);
  PutU16(@H, 22, PI.SetDestAddr.Net);
  H[24] := Code And $FF;                      {product code (low)}
  H[25] := 0;
  For i := 1 To Length(PI.SetPwd) Do
    H[25 + i] := Ord(PI.SetPwd[i]);
  {FSC-0039 type 2+}
  PutU16(@H, 34, PI.SetOrigAddr.Zone);
  PutU16(@H, 36, PI.SetDestAddr.Zone);
  PutU16(@H, 38, 0);
  PutU16(@H, 40, $0100);                      {capability word, byte swapped}
  H[42] := Code Shr 8;
  H[43] := 0;
  PutU16(@H, 44, $0001);                      {capability word: type 2+}
  PutU16(@H, 46, PI.SetOrigAddr.Zone);
  PutU16(@H, 48, PI.SetDestAddr.Zone);
  PutU16(@H, 50, PI.SetOrigAddr.Point);
  PutU16(@H, 52, PI.SetDestAddr.Point);
  End;


Function BuildDate(Var PI: MKPktInfoType): String;
  {"DD Mon YY  HH:MM:SS"}
  Var
    Y, Mo, D, Dow, Hr, Mi, Se, Hs: Word;
    MM, DD, YY, H2, M2: LongInt;

  Begin
  GetDate(Y, Mo, D, Dow);
  GetTime(Hr, Mi, Se, Hs);
  MM := Mo;
  DD := D;
  YY := Y Mod 100;
  H2 := Hr;
  M2 := Mi;
  If Length(PI.NewDate) >= 8 Then
    Begin
    MM := Str2Long(Copy(PI.NewDate, 1, 2));
    DD := Str2Long(Copy(PI.NewDate, 4, 2));
    YY := Str2Long(Copy(PI.NewDate, 7, 2));
    If (MM < 1) Or (MM > 12) Then
      MM := Mo;
    If (DD < 1) Or (DD > 31) Then
      DD := D;
    Se := 0;
    End;
  If Length(PI.NewTime) >= 5 Then
    Begin
    H2 := Str2Long(Copy(PI.NewTime, 1, 2));
    M2 := Str2Long(Copy(PI.NewTime, 4, 2));
    If (H2 < 0) Or (H2 > 23) Then
      H2 := Hr;
    If (M2 < 0) Or (M2 > 59) Then
      M2 := Mi;
    If Length(PI.NewDate) >= 8 Then
      Se := 0;
    End;
  BuildDate := Z2(DD) + ' ' + MonNames[MM] + ' ' + Z2(YY) + '  ' + Z2(H2) + ':' + Z2(M2) + ':' + Z2(Se);
  End;


Function IsKludgeName(P: PktBytePtr; Pos, Len: LongInt; Const Name: String): Boolean;
  {^A line at Pos starts with Name followed by a word boundary}
  Var
    c: Char;

  Begin
  IsKludgeName := False;
  If Not BytesStart(P, Pos + 1, Len, Name) Then
    Exit;
  If Pos + 1 + Length(Name) >= Len Then
    Begin
    IsKludgeName := True;
    Exit;
    End;
  c := Chr(P^[Pos + 1 + Length(Name)]);
  If Not (UpCase(c) In ['A'..'Z', '0'..'9', '_']) Then
    IsKludgeName := True;
  End;


Function PktMsgObj.WriteMsg: Word;
  Var
    O: OutBuf;
    Head, Body, Tail: OutBuf;
    Echo: Boolean;
    Org, Dst: AddrType;
    HasDst: Boolean;
    FromS, ToS, SubjS: String;
    Cut: Boolean;
    MsgId: String;
    Reply: String;
    UserOther, SeenBy, PathL: OutBuf;
    HasSeen, HasPath: Boolean;
    i, LineStart, LineEnd, n: LongInt;
    W: PktBytePtr;
    WL: LongInt;
    Ch: Byte;
    Res: Word;
    HasTear, HasOrigin: Boolean;
    S: String;
    Room: Integer;
    Number: LongInt;
    F: File;
    HdrBuf: Array[0..PktHeaderLen - 1] Of Byte;
    D2: PktBytePtr;
    L2: LongInt;
    C2, E2: LongInt;
    Cl, Tm: Boolean;
    SaveMode: Byte;
    Utf8: Boolean;
    OrgS: String;

  Begin
  WriteMsg := 0;
  With PI^ Do
    Begin
    If FN = '' Then
      Begin
      WriteMsg := 1002;
      Exit;
      End;
    Utf8 := WriteUtf8;
    FillChar(O, SizeOf(O), 0);
    FillChar(Head, SizeOf(Head), 0);
    FillChar(Body, SizeOf(Body), 0);
    FillChar(Tail, SizeOf(Tail), 0);
    FillChar(UserOther, SizeOf(UserOther), 0);
    FillChar(SeenBy, SizeOf(SeenBy), 0);
    FillChar(PathL, SizeOf(PathL), 0);
    Res := 0;
    Echo := (AreaStr <> '') Or (MailType = mmtEchoMail);
    If Echo And (AreaStr = '') Then
      Res := 1005;
    If (Res = 0) And Echo And ((Attr And atPrivate) <> 0) Then
      Res := 1014;
    If Res = 0 Then
      Begin
      FillChar(Org, SizeOf(Org), 0);
      FillChar(Dst, SizeOf(Dst), 0);
      HasDst := False;
      If HaveOrig Then
        Org := OrigAddr
      Else If HavePktInfo Then
        Org := SetOrigAddr
      Else
        Res := 1004;
      If HaveDest Then
        Begin
        Dst := DestAddr;
        HasDst := True;
        End
      Else If Echo And HavePktInfo Then
        Begin
        Dst := SetDestAddr;
        HasDst := True;
        End;
      If (Res = 0) And (Not Echo) Then
        If (Not HasDst) Or (Org.Zone = 0) Or (Dst.Zone = 0) Then
          Res := 1006;
      End;
    If Res = 0 Then
      Begin
      Cut := False;
      FromS := EncodeStr(FromStr, Utf8, 250, Cut);
      If Echo And (ToStr = '') Then
        ToS := 'All'
      Else
        ToS := EncodeStr(ToStr, Utf8, 250, Cut);
      If (Length(FromS) = 0) Or (Length(ToS) = 0) Then
        Res := 1013
      Else If (Length(FromS) > MaxName) Or (Length(ToS) > MaxName) Or Cut Then
        Res := 1012;
      Cut := False;
      SubjS := EncodeStr(SubjStr, Utf8, MaxSubject, Cut);
      End;
    If Res <> 0 Then
      Begin
      WriteMsg := Res;
      Exit;
      End;

    {the text: kludge lines, SEEN-BY, PATH, the body}
    W := WBuf;
    WL := WLen;
    MsgId := MsgIdStr;
    Reply := ReplyStr;
    HasSeen := False;
    HasPath := False;
    i := 0;
    While i < WL Do
      Begin
      LineStart := i;
      While (i < WL) And (W^[i] <> 13) And (W^[i] <> 10) Do
        Inc(i);
      LineEnd := i;
      {line ends: CR, LF, CRLF, LFCR all count once}
      If i < WL Then
        Begin
        Ch := W^[i];
        Inc(i);
        If (i < WL) And ((W^[i] = 13) Or (W^[i] = 10)) And (W^[i] <> Ch) Then
          Inc(i);
        End;
      n := LineEnd - LineStart;
      If (n > 0) And (W^[LineStart] = 1) Then
        Begin
        {kludge}
        If IsKludgeName(W, LineStart, LineEnd, 'MSGID') Then
          Begin
          If MsgId = '' Then
            Begin
            S := BytesToStr(W, LineStart + 1, LineEnd, 250);
            MsgId := StripBoth(Copy(S, Pos(':', S) + 1, 250), ' ');
            End;
          End
        Else If IsKludgeName(W, LineStart, LineEnd, 'REPLY') Then
          Begin
          If Reply = '' Then
            Begin
            S := BytesToStr(W, LineStart + 1, LineEnd, 250);
            Reply := StripBoth(Copy(S, Pos(':', S) + 1, 250), ' ');
            End;
          End
        Else If IsKludgeName(W, LineStart, LineEnd, 'INTL') Or IsKludgeName(W, LineStart, LineEnd, 'FMPT') Or
          IsKludgeName(W, LineStart, LineEnd, 'TOPT') Or IsKludgeName(W, LineStart, LineEnd, 'CHRS') Then
          {made by this unit}
        Else If BytesStart(W, LineStart + 1, LineEnd, 'SEEN-BY:') Then
          Begin
          OutText(SeenBy, W, LineStart + 1, LineEnd, Utf8);
          OutByte(SeenBy, 13);
          HasSeen := True;
          End
        Else If BytesStart(W, LineStart + 1, LineEnd, 'PATH:') Then
          Begin
          OutByte(PathL, 1);
          OutText(PathL, W, LineStart + 1, LineEnd, Utf8);
          OutByte(PathL, 13);
          HasPath := True;
          End
        Else
          Begin
          OutText(UserOther, W, LineStart, LineEnd, Utf8);
          OutByte(UserOther, 13);
          End;
        End
      Else If BytesStart(W, LineStart, LineEnd, 'SEEN-BY:') Then
        Begin
        OutText(SeenBy, W, LineStart, LineEnd, Utf8);
        OutByte(SeenBy, 13);
        HasSeen := True;
        End
      Else
        Begin
        OutText(Body, W, LineStart, LineEnd, Utf8);
        OutByte(Body, 13);
        End;
      End;
    If (Body.Len > 0) And (Body.P^[Body.Len - 1] <> 13) Then
      OutByte(Body, 13);

    OrgS := AddrToStr(Org);
    If MsgId = '' Then
      MsgId := OrgS + ' ' + NextSerial;
    MsgId := Copy(MsgId, 1, 200);
    {head}
    If Echo Then
      OutStr(Head, 'AREA:' + AreaStr + #13)
    Else
      Begin
      OutStr(Head, #1 + 'INTL ' + Long2Str(Dst.Zone) + ':' + Long2Str(Dst.Net) + '/' + Long2Str(Dst.Node) + ' ' +
        Long2Str(Org.Zone) + ':' + Long2Str(Org.Net) + '/' + Long2Str(Org.Node) + #13);
      If Org.Point <> 0 Then
        OutStr(Head, #1 + 'FMPT ' + Long2Str(Org.Point) + #13);
      If Dst.Point <> 0 Then
        OutStr(Head, #1 + 'TOPT ' + Long2Str(Dst.Point) + #13);
      End;
    OutStr(Head, #1 + 'MSGID: ' + MsgId + #13);
    If Reply <> '' Then
      OutStr(Head, #1 + 'REPLY: ' + Reply + #13);
    If Utf8 Then
      OutStr(Head, #1 + 'CHRS: UTF-8 4' + #13);
    If UserOther.Len > 0 Then
      OutAdd(Head, UserOther.P^, UserOther.Len);
    {tail}
    If Echo And EchoTail Then
      Begin
      HasTear := False;
      HasOrigin := False;
      i := 0;
      While i < Body.Len Do
        Begin
        LineStart := i;
        While (i < Body.Len) And (Body.P^[i] <> 13) Do
          Inc(i);
        LineEnd := i;
        If i < Body.Len Then
          Inc(i);
        If BytesStart(Body.P, LineStart, LineEnd, '---') Then
          If (LineEnd = LineStart + 3) Or (Body.P^[LineStart + 3] <= 32) Then
            HasTear := True;
        If BytesStart(Body.P, LineStart, LineEnd, ' * Origin:') Then
          HasOrigin := True;
        End;
      If Not HasTear Then
        OutStr(Tail, '--- ' + Tearline + #13);
      If Not HasOrigin Then
        Begin
        Room := 79 - Length(' * Origin:  (' + OrgS + ')');
        If Room < 0 Then
          Room := 0;
        OutStr(Tail, ' * Origin: ' + Copy(OriginText, 1, Room) + ' (' + OrgS + ')' + #13);
        End;
      If HasSeen Then
        OutAdd(Tail, SeenBy.P^, SeenBy.Len)
      Else
        OutStr(Tail, SeenByLine(Org, Dst, HasDst) + #13);
      If HasPath Then
        OutAdd(Tail, PathL.P^, PathL.Len)
      Else
        OutStr(Tail, #1 + 'PATH: ' + Long2Str(Org.Net) + '/' + Long2Str(Org.Node) + #13);
      End;

    {the packed message}
    OutWord(O, 2);
    OutWord(O, Org.Node);
    If HasDst Then
      OutWord(O, Dst.Node)
    Else
      OutWord(O, 0);
    OutWord(O, Org.Net);
    If HasDst Then
      OutWord(O, Dst.Net)
    Else
      OutWord(O, 0);
    OutWord(O, Attr);
    OutWord(O, Cost);
    OutStr(O, BuildDate(PI^));
    OutByte(O, 0);
    OutStr(O, ToS);
    OutByte(O, 0);
    OutStr(O, FromS);
    OutByte(O, 0);
    OutStr(O, SubjS);
    OutByte(O, 0);
    If Head.Len > 0 Then
      OutAdd(O, Head.P^, Head.Len);
    If Body.Len > 0 Then
      OutAdd(O, Body.P^, Body.Len);
    If Tail.Len > 0 Then
      OutAdd(O, Tail.P^, Tail.Len);
    OutByte(O, 0);
    OutWord(O, 0);                                {the packet terminator}

    {append: a new packet, or after the last message of the one there}
    Number := 0;
    Res := 0;
    SaveMode := FileMode;
    If Not FileExist(FN) Then
      Begin
      Res := BuildHeader(PI^, HdrBuf);
      If Res = 0 Then
        Begin
        Assign(F, FN);
        FileMode := fmReadWrite + fmDenyWrite;
        ReWrite(F, 1);
        FileMode := SaveMode;
        If IoResult <> 0 Then
          Res := 1000
        Else
          Begin
          BlockWrite(F, HdrBuf, PktHeaderLen);
          BlockWrite(F, O.P^, O.Len);
          If IoResult <> 0 Then
            Res := 1000;
          Close(F);
          If IoResult <> 0 Then;
          Number := 1;
          End;
        End;
      End
    Else
      Begin
      Res := ReadWhole(FN, D2, L2);
      If Res = 0 Then
        Begin
        If (L2 < PktHeaderLen) Or (GetU16(D2, 18) <> 2) Then
          Res := 1011
        Else
          Begin
          WalkPkt(D2, L2, Nil, Nil, C2, E2, Cl, Tm);
          If Not Cl Then
            Res := 1007
          Else
            Begin
            Assign(F, FN);
            FileMode := fmReadWrite + fmDenyWrite;
            Reset(F, 1);
            FileMode := SaveMode;
            If IoResult <> 0 Then
              Res := 1000
            Else
              Begin
              Seek(F, E2);
              BlockWrite(F, O.P^, O.Len);
              If IoResult <> 0 Then
                Res := 1000;
              Truncate(F);
              Close(F);
              If IoResult <> 0 Then;
              Number := C2 + 1;
              End;
            End;
          End;
        End;
      If D2 <> Nil Then
        FreeMem(D2, L2);
      End;
    FileMode := SaveMode;
    FreeMem(O.P, O.Cap);
    If Head.P <> Nil Then FreeMem(Head.P, Head.Cap);
    If Body.P <> Nil Then FreeMem(Body.P, Body.Cap);
    If Tail.P <> Nil Then FreeMem(Tail.P, Tail.Cap);
    If UserOther.P <> Nil Then FreeMem(UserOther.P, UserOther.Cap);
    If SeenBy.P <> Nil Then FreeMem(SeenBy.P, SeenBy.Cap);
    If PathL.P <> Nil Then FreeMem(PathL.P, PathL.Cap);
    If Res = 0 Then
      Begin
      MsgIdStr := MsgId;
      LastNum := Number;
      WLen := 0;
      If BaseOpened Then
        Begin
        Res := LoadPacket(PI^);
        If Res = 0 Then
          Begin
          FreeMem(MsgS, 4);
          FreeMem(MsgE, 4);
          MsgS := Nil;
          MsgE := Nil;
          ScanPkt;
          End
        Else
          BaseOpened := False;
        End;
      Writing := False;
      Cur := Number;
      Parsed := 0;
      End;
    WriteMsg := Res;
    End;
  End;


Function PktMsgObj.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word;
  {an empty packet: the header and the terminator}
  Var
    F: File;
    H: Array[0..PktHeaderLen - 1] Of Byte;
    Z: Array[0..1] Of Byte;
    Res: Word;
    SaveMode: Byte;

  Begin
  If PI^.FN = '' Then
    Begin
    CreateMsgBase := 1002;
    Exit;
    End;
  If PI^.BaseOpened Then
    Begin
    CreateMsgBase := 1009;
    Exit;
    End;
  If FileExist(PI^.FN) Then
    Begin
    CreateMsgBase := 1009;
    Exit;
    End;
  Res := BuildHeader(PI^, H);
  If Res <> 0 Then
    Begin
    CreateMsgBase := Res;
    Exit;
    End;
  Z[0] := 0;
  Z[1] := 0;
  SaveMode := FileMode;
  FileMode := fmReadWrite + fmDenyWrite;
  Assign(F, PI^.FN);
  ReWrite(F, 1);
  FileMode := SaveMode;
  If IoResult <> 0 Then
    Begin
    CreateMsgBase := 1000;
    Exit;
    End;
  BlockWrite(F, H, PktHeaderLen);
  BlockWrite(F, Z, 2);
  Res := IoResult;
  Close(F);
  If IoResult <> 0 Then;
  If Res <> 0 Then
    Begin
    Erase(F);
    If IoResult <> 0 Then;
    CreateMsgBase := 1000;
    End
  Else
    CreateMsgBase := 0;
  End;


{---------------------------------------------------------------- reading a message}

Procedure ParseDate(Var PI: MKPktInfoType; S: String);
  {"01 Jan 86  02:34:56" (also with a four digit year and without seconds)}
  Var
    p, k: Word;
    N: LongInt;
    M: String[3];

  Function Num(Var Value: LongInt): Boolean;
    Var
      Start: Word;

    Begin
    While (p <= Length(S)) And (S[p] = ' ') Do
      Inc(p);
    Start := p;
    Value := 0;
    While (p <= Length(S)) And (S[p] In ['0'..'9']) And (p - Start < 4) Do
      Begin
      Value := Value * 10 + Ord(S[p]) - 48;
      Inc(p);
      End;
    Num := p > Start;
    End;

  Begin
  With PI Do
    Begin
    DateOk := False;
    PDay := 0;
    PMon := 0;
    PYear := 0;
    PHour := 0;
    PMin := 0;
    p := 1;
    If Not Num(N) Then
      Exit;
    PDay := N;
    While (p <= Length(S)) And (S[p] = ' ') Do
      Inc(p);
    M := Upper(Copy(S, p, 3));
    PMon := 0;
    For k := 1 To 12 Do
      If Upper(MonNames[k]) = M Then
        PMon := k;
    If PMon = 0 Then
      Exit;
    Inc(p, 3);
    While (p <= Length(S)) And (UpCase(S[p]) In ['A'..'Z']) Do
      Inc(p);
    If Not Num(N) Then
      Exit;
    PYear := N Mod 100;
    If Not Num(N) Then
      Exit;
    PHour := N;
    If (p <= Length(S)) And (S[p] = ':') Then
      Begin
      Inc(p);
      If Num(N) Then
        PMin := N;
      End;
    DateOk := True;
    End;
  End;


Procedure ScanKludge(Var PI: MKPktInfoType; Line: String);
  {^A line (the ^A is not in Line): INTL, FMPT, TOPT, MSGID, REPLY}
  Var
    U: String;
    A: AddrType;
    Def: AddrType;
    S1, S2: String;

  Begin
  U := Upper(Copy(Line, 1, 6));
  If Copy(U, 1, 5) = 'INTL ' Then
    Begin
    S1 := ExtractWord(Line, 2);
    S2 := ExtractWord(Line, 3);
    Def := PI.DestAddr;
    If ParseAddr(S1, Def, A) Then
      Begin
      A.Point := 0;
      PI.DestAddr := A;
      End;
    Def := PI.OrigAddr;
    If ParseAddr(S2, Def, A) Then
      Begin
      A.Point := 0;
      PI.OrigAddr := A;
      End;
    End
  Else If Copy(U, 1, 5) = 'FMPT ' Then
    PI.OrigAddr.Point := Str2Long(StripBoth(Copy(Line, 6, 20), ' '))
  Else If Copy(U, 1, 5) = 'TOPT ' Then
    PI.DestAddr.Point := Str2Long(StripBoth(Copy(Line, 6, 20), ' '))
  Else If Copy(U, 1, 6) = 'MSGID:' Then
    PI.MsgIdStr := StripBoth(Copy(Line, 7, 200), ' ')
  Else If Copy(U, 1, 6) = 'REPLY:' Then
    PI.ReplyStr := StripBoth(Copy(Line, 7, 200), ' ');
  End;


Procedure ParseCur(Var PI: MKPktInfoType);
  {The current message from the packet in memory: header fields, the text converted to CP437
   (AREA: line out, SEEN-BY lines given a ^A), the kludges that say who it is from and to.}
  Var
    s, e, p, z, ts: LongInt;
    k: Word;
    RawStart: Array[1..4] Of LongInt;
    RawEnd: Array[1..4] Of LongInt;
    Enc: Byte;
    Tmp: PktBytePtr;
    TmpLen: LongInt;
    OutLen, i, LS, LE: LongInt;
    Cap: LongInt;
    BodyCount: LongInt;
    AreaDone: Boolean;
    Line: String;
    CS: Byte;
    RawText: LongInt;

  Procedure PutB(B: Byte);
    Begin
    PI.Txt^[OutLen] := B;
    Inc(OutLen);
    End;

  Begin
  With PI Do
    Begin
    FreeMsg(PI);
    s := MsgS^[Cur];
    e := MsgE^[Cur];
    OrigAddr.Net := GetU16(Data, s + 6);
    OrigAddr.Node := GetU16(Data, s + 2);
    DestAddr.Net := GetU16(Data, s + 8);
    DestAddr.Node := GetU16(Data, s + 4);
    OrigAddr.Zone := PktOrigAddr.Zone;
    DestAddr.Zone := PktDestAddr.Zone;
    OrigAddr.Point := 0;
    DestAddr.Point := 0;
    Attr := GetU16(Data, s + 10);
    Cost := GetU16(Data, s + 12);
    p := s + 14;
    For k := 1 To 4 Do
      Begin
      z := IndexZero(Data, p, DataLen);
      RawStart[k] := p;
      RawEnd[k] := z;
      p := z + 1;
      End;
    ts := p;
    {character set: ^ACHRS: if there is one, else the setting}
    Enc := ReadCs;
    i := ts;
    While i < e Do
      Begin
      If (Data^[i] = 1) And BytesStart(Data, i + 1, e, 'CHRS:') Then
        Begin
        CS := CsFromChrs(BytesToStr(Data, i + 6, e, 60));
        If CS <> 255 Then
          Enc := CS;
        Break;
        End;
      While (i < e) And (Data^[i] <> 13) And (Data^[i] <> 10) Do
        Inc(i);
      While (i < e) And ((Data^[i] = 13) Or (Data^[i] = 10)) Do
        Inc(i);
      End;
    ParseDate(PI, BytesToStr(Data, RawStart[1], RawEnd[1], 40));
    ToStr := DecodeStr(BytesToStr(Data, RawStart[2], RawEnd[2], 80), Enc);
    FromStr := DecodeStr(BytesToStr(Data, RawStart[3], RawEnd[3], 80), Enc);
    SubjStr := DecodeStr(BytesToStr(Data, RawStart[4], RawEnd[4], 150), Enc);
    AreaStr := '';
    MsgIdStr := '';
    ReplyStr := '';
    {the text}
    RawText := e - ts;
    If RawText < 0 Then
      RawText := 0;
    TmpLen := 0;
    GetMem(Tmp, RawText + 1);
    If RawText > 0 Then
      DecodeBuf(@Data^[ts], RawText, Enc, True, Tmp, TmpLen);
    Cap := TmpLen + TmpLen Div 8 + 32;
    GetMem(Txt, Cap + 1);
    TxtCap := Cap + 1;
    OutLen := 0;
    BodyCount := 0;
    AreaDone := False;
    i := 0;
    While i < TmpLen Do
      Begin
      LS := i;
      While (i < TmpLen) And (Tmp^[i] <> 13) Do
        Inc(i);
      LE := i;
      If i < TmpLen Then
        Inc(i);
      {a line without its LFs}
      If (LE > LS) And (Tmp^[LS] = 1) Then
        Begin
        Line := BytesToStr(Tmp, LS + 1, LE, 250);
        ScanKludge(PI, Line);
        For k := LS To LE - 1 Do
          If Tmp^[k] <> 10 Then
            PutB(Tmp^[k]);
        If LE < TmpLen Then
          PutB(13);
        End
      Else If BytesStart(Tmp, LS, LE, 'SEEN-BY:') Or
        ((LE - LS > 1) And (Tmp^[LS] = 10) And BytesStart(Tmp, LS + 1, LE, 'SEEN-BY:')) Then
        Begin
        PutB(1);
        For k := LS To LE - 1 Do
          If Tmp^[k] <> 10 Then
            PutB(Tmp^[k]);
        If LE < TmpLen Then
          PutB(13);
        End
      Else If (Not AreaDone) And (BodyCount = 0) And (AreaStr = '') And
        (BytesStart(Tmp, LS, LE, 'AREA:') Or
         ((LE - LS > 1) And (Tmp^[LS] = 10) And BytesStart(Tmp, LS + 1, LE, 'AREA:'))) Then
        Begin
        Line := BytesToStr(Tmp, LS, LE, 250);
        While (Length(Line) > 0) And (Line[1] = #10) Do
          Delete(Line, 1, 1);
        AreaStr := StripBoth(Copy(Line, 6, 80), ' ');
        AreaDone := True;
        End
      Else
        Begin
        Inc(BodyCount);
        For k := LS To LE - 1 Do
          If Tmp^[k] <> 10 Then
            PutB(Tmp^[k]);
        If LE < TmpLen Then
          PutB(13);
        End;
      End;
    FreeMem(Tmp, RawText + 1);
    TxtLen := OutLen;
    TxtCtr := 0;
    MsgDone := False;
    Parsed := Cur;
    End;
  End;


Procedure Need(Var PI: MKPktInfoType);
  Begin
  If PI.Writing Then
    Exit;
  If (PI.Cur < 1) Or (PI.Cur > PI.NumMsgs) Then
    Exit;
  If PI.Parsed <> PI.Cur Then
    ParseCur(PI);
  End;


{---------------------------------------------------------------- reading}

Function PktMsgObj.GetFrom: String;
  Begin
  Need(PI^);
  GetFrom := PI^.FromStr;
  End;


Function PktMsgObj.GetTo: String;
  Begin
  Need(PI^);
  GetTo := PI^.ToStr;
  End;


Function PktMsgObj.GetSubj: String;
  Begin
  Need(PI^);
  GetSubj := PI^.SubjStr;
  End;


Function PktMsgObj.GetCost: Word;
  Begin
  Need(PI^);
  GetCost := PI^.Cost;
  End;


Function PktMsgObj.GetDate: String;
  {mm-dd-yy}
  Begin
  Need(PI^);
  If PI^.DateOk Then
    GetDate := Z2(PI^.PMon) + '-' + Z2(PI^.PDay) + '-' + Z2(PI^.PYear)
  Else
    GetDate := '00-00-00';
  End;


Function PktMsgObj.GetTime: String;
  {hh:mm}
  Begin
  Need(PI^);
  If PI^.DateOk Then
    GetTime := Z2(PI^.PHour) + ':' + Z2(PI^.PMin)
  Else
    GetTime := '00:00';
  End;


Function PktMsgObj.GetRefer: LongInt;
  Begin
  GetRefer := 0;
  End;


Function PktMsgObj.GetSeeAlso: LongInt;
  Begin
  GetSeeAlso := 0;
  End;


Function PktMsgObj.GetMsgNum: LongInt;
  Begin
  If PI^.Writing Then
    GetMsgNum := PI^.LastNum
  Else If (PI^.Cur >= 1) And (PI^.Cur <= PI^.NumMsgs) Then
    GetMsgNum := PI^.Cur
  Else If (Not PI^.BaseOpened) And (PI^.Cur > 0) Then
    GetMsgNum := PI^.Cur
  Else
    GetMsgNum := -1;
  End;


Procedure PktMsgObj.GetOrig(Var Addr: AddrType);
  Begin
  Need(PI^);
  Addr := PI^.OrigAddr;
  End;


Procedure PktMsgObj.GetDest(Var Addr: AddrType);
  Begin
  Need(PI^);
  Addr := PI^.DestAddr;
  End;


Function PktMsgObj.IsLocal: Boolean;
  Begin
  Need(PI^);
  IsLocal := (PI^.Attr And atLocal) <> 0;
  End;


Function PktMsgObj.IsCrash: Boolean;
  Begin
  Need(PI^);
  IsCrash := (PI^.Attr And atCrash) <> 0;
  End;


Function PktMsgObj.IsKillSent: Boolean;
  Begin
  Need(PI^);
  IsKillSent := (PI^.Attr And atKillSent) <> 0;
  End;


Function PktMsgObj.IsSent: Boolean;
  Begin
  Need(PI^);
  IsSent := (PI^.Attr And atSent) <> 0;
  End;


Function PktMsgObj.IsFAttach: Boolean;
  Begin
  Need(PI^);
  IsFAttach := (PI^.Attr And atFAttach) <> 0;
  End;


Function PktMsgObj.IsReqRct: Boolean;
  Begin
  Need(PI^);
  IsReqRct := (PI^.Attr And atReqRct) <> 0;
  End;


Function PktMsgObj.IsReqAud: Boolean;
  Begin
  Need(PI^);
  IsReqAud := (PI^.Attr And atReqAud) <> 0;
  End;


Function PktMsgObj.IsRetRct: Boolean;
  Begin
  Need(PI^);
  IsRetRct := (PI^.Attr And atRetRct) <> 0;
  End;


Function PktMsgObj.IsFileReq: Boolean;
  Begin
  Need(PI^);
  IsFileReq := (PI^.Attr And atFileReq) <> 0;
  End;


Function PktMsgObj.IsRcvd: Boolean;
  Begin
  Need(PI^);
  IsRcvd := (PI^.Attr And atRcvd) <> 0;
  End;


Function PktMsgObj.IsPriv: Boolean;
  Begin
  Need(PI^);
  IsPriv := (PI^.Attr And atPrivate) <> 0;
  End;


Function PktMsgObj.IsHold: Boolean;
  Begin
  Need(PI^);
  IsHold := (PI^.Attr And atHold) <> 0;
  End;


Function PktMsgObj.IsDeleted: Boolean;
  Begin
  IsDeleted := False;
  End;


Function PktMsgObj.IsEchoed: Boolean;
  Begin
  Need(PI^);
  IsEchoed := PI^.AreaStr <> '';
  End;


Function PktMsgObj.GetArea: String;
  Begin
  Need(PI^);
  GetArea := PI^.AreaStr;
  End;


Function PktMsgObj.GetMsgId: String;
  Begin
  Need(PI^);
  GetMsgId := PI^.MsgIdStr;
  End;


Function PktMsgObj.GetReplyId: String;
  Begin
  Need(PI^);
  GetReplyId := PI^.ReplyStr;
  End;


Function PktMsgObj.GetAttr: Word;
  Begin
  Need(PI^);
  GetAttr := PI^.Attr;
  End;


Procedure PktMsgObj.GetPktOrig(Var Addr: AddrType);
  Begin
  Addr := PI^.PktOrigAddr;
  End;


Procedure PktMsgObj.GetPktDest(Var Addr: AddrType);
  Begin
  Addr := PI^.PktDestAddr;
  End;


Function PktMsgObj.GetPktPassword: String;
  Begin
  GetPktPassword := PI^.PktPwdStr;
  End;


Function PktMsgObj.PktClean: Boolean;
  Begin
  PktClean := PI^.Clean;
  End;


Function PktMsgObj.GetChar: Char;
  Begin
  Need(PI^);
  With PI^ Do
    Begin
    If (Txt = Nil) Or (TxtCtr >= TxtLen) Then
      Begin
      GetChar := #0;
      MsgDone := True;
      End
    Else
      Begin
      GetChar := Chr(Txt^[TxtCtr]);
      Inc(TxtCtr);
      End;
    End;
  End;


Function PktMsgObj.EOM: Boolean;
  Begin
  EOM := PI^.MsgDone;
  End;


Function PktMsgObj.GetTxtPos: LongInt;
  Begin
  GetTxtPos := PI^.TxtCtr;
  End;


Procedure PktMsgObj.SetTxtPos(TP: LongInt);
  Begin
  PI^.TxtCtr := TP;
  PI^.MsgDone := False;
  End;


{---------------------------------------------------------------- finding messages}

Procedure PktMsgObj.SeekFirst(MsgNum: LongInt);
  Begin
  With PI^ Do
    Begin
    Writing := False;
    Parsed := 0;
    If MsgNum < 1 Then
      MsgNum := 1;
    Cur := MsgNum;
    TxtCtr := 0;
    MsgDone := False;
    End;
  End;


Procedure PktMsgObj.SeekNext;
  Begin
  With PI^ Do
    Begin
    Writing := False;
    Parsed := 0;
    If Cur < 1 Then
      Cur := 0;
    If Cur <= NumMsgs Then
      Inc(Cur);
    TxtCtr := 0;
    MsgDone := False;
    End;
  End;


Procedure PktMsgObj.SeekPrior;
  Begin
  With PI^ Do
    Begin
    Writing := False;
    Parsed := 0;
    If Cur > NumMsgs + 1 Then
      Cur := NumMsgs + 1;
    If Cur > 1 Then
      Dec(Cur)
    Else
      Cur := 0;
    TxtCtr := 0;
    MsgDone := False;
    End;
  End;


Function PktMsgObj.SeekFound: Boolean;
  Begin
  SeekFound := (Not PI^.Writing) And (PI^.Cur >= 1) And (PI^.Cur <= PI^.NumMsgs);
  End;


Procedure PktMsgObj.MsgStartUp;
  Begin
  With PI^ Do
    Begin
    If Writing Then
      Exit;
    Parsed := 0;
    Need(PI^);
    End;
  End;


Procedure PktMsgObj.MsgTxtStartUp;
  Begin
  Need(PI^);
  PI^.TxtCtr := 0;
  PI^.MsgDone := False;
  End;


Function PktMsgObj.GetHighMsgNum: LongInt;
  Begin
  GetHighMsgNum := PI^.NumMsgs;
  End;


Function PktMsgObj.NumberOfMsgs: LongInt;
  Begin
  NumberOfMsgs := PI^.NumMsgs;
  End;


Function PktMsgObj.GetMsgLoc: LongInt;
  Begin
  GetMsgLoc := GetMsgNum;
  End;


Procedure PktMsgObj.SetMsgLoc(ML: LongInt);
  Begin
  SeekFirst(ML);
  End;


Procedure PktMsgObj.YoursFirst(Name: String; Handle: String);
  Begin
  With PI^ Do
    Begin
    Writing := False;
    Parsed := 0;
    YName := Upper(StripBoth(Name, ' '));
    YHandle := Upper(StripBoth(Handle, ' '));
    Cur := 0;
    YFound := False;
    End;
  YoursNext;
  End;


Procedure PktMsgObj.YoursNext;
  Begin
  With PI^ Do
    Begin
    YFound := False;
    Writing := False;
    If (YName = '') And (YHandle = '') Then
      Begin
      Cur := NumMsgs + 1;
      Exit;
      End;
    Inc(Cur);
    While (Cur <= NumMsgs) And Not YFound Do
      Begin
      Parsed := 0;
      Need(PI^);
      If ((YName <> '') And (Upper(StripBoth(ToStr, ' ')) = YName)) Or
         ((YHandle <> '') And (Upper(StripBoth(ToStr, ' ')) = YHandle)) Then
        YFound := True
      Else
        Inc(Cur);
      End;
    If Not YFound Then
      Cur := NumMsgs + 1;
    End;
  End;


Function PktMsgObj.YoursFound: Boolean;
  Begin
  YoursFound := PI^.YFound;
  End;


Function PktMsgObj.GetLastRead(UNum: LongInt): LongInt;
  Begin
  GetLastRead := 0;
  End;


Procedure PktMsgObj.SetLastRead(UNum: LongInt; LR: LongInt);
  Begin
  End;


{---------------------------------------------------------------- changing the packet}

Procedure PktMsgObj.ReWriteHdr;
  {the attribute word of the current message goes back into the packet}
  Var
    F: File;
    SaveMode: Byte;
    Sz: LongInt;
    B: Array[0..1] Of Byte;

  Begin
  With PI^ Do
    Begin
    If (Not BaseOpened) Or Writing Or (Cur < 1) Or (Cur > NumMsgs) Then
      Begin
      Error := 1000;
      Exit;
      End;
    SaveMode := FileMode;
    FileMode := fmReadWrite + fmDenyNone;
    Assign(F, FN);
    Reset(F, 1);
    FileMode := SaveMode;
    If IoResult <> 0 Then
      Begin
      Error := 1000;
      Exit;
      End;
    Sz := FileSize(F);
    If Sz <> DataLen Then
      Begin
      Close(F);
      If IoResult <> 0 Then;
      Error := 1008;
      Exit;
      End;
    B[0] := Attr And $FF;
    B[1] := Attr Shr 8;
    Seek(F, MsgS^[Cur] + 10);
    BlockWrite(F, B, 2);
    If IoResult <> 0 Then
      Error := 1000
    Else
      Error := 0;
    Close(F);
    If IoResult <> 0 Then;
    If Error = 0 Then
      PutU16(Data, MsgS^[Cur] + 10, Attr);
    End;
  End;


Procedure PktMsgObj.DeleteMsg;
  {The message is taken out by writing the packet again through a temporary file; the
   numbers after it go down by one.  The cursor is left on the one before it, so a
   SeekNext loop goes on with the next message.}
  Var
    F: File;
    TmpName: String;
    s, e, After: LongInt;
    SaveMode: Byte;
    Sz: LongInt;
    Res: Word;
    Old: LongInt;
    Ok: Boolean;

  Begin
  With PI^ Do
    Begin
    If (Not BaseOpened) Or Writing Or (Cur < 1) Or (Cur > NumMsgs) Then
      Begin
      Error := 1000;
      Exit;
      End;
    If Not Clean Then
      Begin
      Error := 1007;
      Exit;
      End;
    SaveMode := FileMode;
    FileMode := fmReadOnly + fmDenyNone;
    Assign(F, FN);
    Reset(F, 1);
    FileMode := SaveMode;
    If IoResult <> 0 Then
      Begin
      Error := 1000;
      Exit;
      End;
    Sz := FileSize(F);
    Close(F);
    If IoResult <> 0 Then;
    If Sz <> DataLen Then
      Begin
      Error := 1008;
      Exit;
      End;
    s := MsgS^[Cur];
    e := MsgE^[Cur];
    If e < DataLen Then
      After := e + 1
    Else
      After := e;
    TmpName := FN + '.tmp';
    Assign(F, TmpName);
    FileMode := fmReadWrite + fmDenyWrite;
    ReWrite(F, 1);
    FileMode := SaveMode;
    If IoResult <> 0 Then
      Begin
      Error := 1000;
      Exit;
      End;
    BlockWrite(F, Data^[0], s);
    If DataLen > After Then
      BlockWrite(F, Data^[After], DataLen - After);
    Ok := IoResult = 0;
    Close(F);
    If IoResult <> 0 Then;
    If Ok Then
      Begin
      Assign(F, TmpName);
      {the old name must go first (Rename does not replace on every system)}
      Rename(F, FN);
      If IoResult <> 0 Then
        Ok := False;
      End;
    If Not Ok Then
      Begin
      Assign(F, TmpName);
      Erase(F);
      If IoResult <> 0 Then;
      Error := 1000;
      Exit;
      End;
    Old := Cur;
    Res := LoadPacket(PI^);
    If Res = 0 Then
      Begin
      FreeMem(MsgS, 4);
      FreeMem(MsgE, 4);
      MsgS := Nil;
      MsgE := Nil;
      ScanPkt;
      Error := 0;
      End
    Else
      Begin
      BaseOpened := False;
      Error := Res;
      End;
    Cur := Old - 1;
    If Cur > NumMsgs Then
      Cur := NumMsgs;
    Parsed := 0;
    TxtCtr := 0;
    MsgDone := False;
    End;
  End;


Begin
LastSerial := 0;
End.
