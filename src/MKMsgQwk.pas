Unit MKMsgQwk;       {QWK message file (MESSAGES.DAT, REP) message object}

{$I MKB.Def}

{
     MKMsgQwk - a QWK message file as a message base.  Follows javascript/MessageQWK.js.

     This works on the message file itself (MESSAGES.DAT of a downloaded .QWK, or the
     <BBSID>.MSG that is packed into a .REP).  Unpack a packet first and pack a
     finished REP yourself (MKPack).

     The file is 128 byte blocks: block 0 is the packet id, then per message a 128 byte
     header and its text blocks (lines end in $E3, the last block is padded with blanks).

     READING
       Messages are numbered by their position in what is shown (1 up, deleted ones
       are not counted), as for the other message bases.  The message number written
       in the file is GetQwkNum (GetMsgDisplayNum gives it too): numbers of different
       conferences overlap in one file, so SetConference(n) shows only conference n and
       the position numbers then run through that conference alone.  Without it every
       conference is shown, in file order.  To go through a packet conference by conference:

          n := -1;
          Repeat
            n := Q.NextConf(n);                   (-1 after the last one)
            If n >= 0 Then
              Begin
              Q.SetConference(n);  Q.SeekFirst(1);
              While Q.SeekFound Do ... Q.SeekNext;
              End;
          Until n < 0;

       Texts come out in CP437 (the BBS character set); SetReadCharset says what the
       packet holds (qcCp437 is the QWK default, qcAuto finds out: UTF-8 or CP437).
       Lines are ended by #13.  Leading @VIA:, @MSGID:, @REPLY: and @TZ: lines (the
       Synchronet/QWK convention) come out as ^A kludge lines (^AVia ..., ^AMSGID: ...,
       ^AREPLY: ..., ^ATZ: ...), GetMsgId / GetReplyId give the first two.  Names
       and subject are the 25 byte fields (QWKE long names are not handled).
       The status byte gives IsPriv and IsRcvd (SetStatusStyle: the QWK spec, or
       PCBoard's way, which has '+' and '*' the other way round); GetStatusChar,
       GetHasTag (byte 127, a tag line is present), GetEchoFlag (byte 126 'E' of a
       REP) and GetPassword give the rest.  A damaged file is read as far as it
       can be made out (GetClean is False then) and is not written.

     WRITING
       StartNewMsg, SetFrom, SetTo, SetSubj, SetDate (mm-dd-yy), SetTime (hh:mm),
       SetRefer, SetPriv, SetRcvd, DoString... for the text, DoKludgeLn for kludge
       lines, SetMsgConf for the conference (else the SetConference one, else 0),
       WriteMsg appends the message.  Names are upper cased and cut to 25 bytes
       (GetCut says that something was cut), a message needs a From and a text.
       Of the kludge lines only MSGID, REPLY, Via and TZ are kept, as @ lines
       (GetDropped counts the others).  SetHasTag(True) marks a tag line.
       CreateMsgBase makes a new file with SetPacketId as its first block.
       SetRepMode(True) writes REP style headers: the number field holds the conference
       number and byte 126 'E' says echomail (SetMailType(mmtEchoMail) once for the base, or SetEcho per message);
       the status style is PCBoard's then, as for MKNet's REP files.
       WriteMsg appends under a lock (LockMsgBase takes it for longer) and takes
       the file back to its old size when writing fails.
       ReWriteHdr writes the status and the reference number of the current message
       back; DeleteMsg marks it as killed (the numbers after it go down by one and the
       cursor is left on the one before it, so a SeekNext loop goes on).

     Errors (the result of OpenMsgBase, CreateMsgBase, WriteMsg, ...):
       1000 cannot open   1001 no such file   1002 no file name set
       1003 too short for a QWK file   1004 the file is damaged, not changed
       1005 from is missing   1006 the text is empty   1007 the message is too long
       1008 conference above 65535   1009 the file exists already   1010 no memory
       1011 the file is read only   1012 the file changed (size) while it was open
       1013 write failed   1014 no current message   1015 cannot lock
}


Interface

Uses MKGlobT, MKMsgAbs,
  Dos;


Const
  qcAuto = 0;       {SetReadCharset: find out (UTF-8 or CP437)}
  qcCp437 = 1;
  qcUtf8 = 2;
  qcLatin1 = 3;

  qsQwk = 0;        {SetStatusStyle: '+' private unread, '*' private read}
  qsPcBoard = 1;    {'*' private unread, '+' private read}


Type QwkByteArr = Array[0..$7FFFFFF0] Of Byte;
Type QwkBytePtr = ^QwkByteArr;
Type QwkLongArr = Array[0..$1FFFFFF0] Of LongInt;
Type QwkLongPtr = ^QwkLongArr;
Type QwkHdr = Array[0..127] Of Byte;

Type QwkEntry = Record
  Blk: LongInt;                   {block number of the header}
  NB: LongInt;                    {blocks, the header included}
  Num: LongInt;                   {message number in the file}
  Conf: Word;
  Active: Boolean;
  End;
Type QwkEntArr = Array[0..$7FFFFF] Of QwkEntry;
Type QwkEntPtr = ^QwkEntArr;


Type MKQwkInfoType = Record
  Error: Word;
  FN: String[255];
  Opened: Boolean;
  ReadOnly: Boolean;
  Locked: Boolean;
  F: File;
  Size: LongInt;                  {size of the file in bytes when last looked at}
  Clean: Boolean;                 {the chain of messages is whole}
  PacketId: String[128];
  {the messages in the file}
  Ent: QwkEntPtr;
  NumEnt: LongInt;
  EntCap: LongInt;
  {the ones shown: not killed, in the conference when there is a filter}
  View: QwkLongPtr;
  NumView: LongInt;
  ViewCap: LongInt;
  ConfBits: Array[0..8191] Of Byte;  {conferences with messages in the file}
  Filter: LongInt;                {conference shown, -1 = all}
  {the current message: read, or being written}
  Cur: LongInt;
  Parsed: LongInt;
  Writing: Boolean;
  LastNum: LongInt;
  FromStr: String[80];
  ToStr: String[80];
  SubjStr: String[80];
  PwdStr: String[16];
  DateStr: String[8];
  TimeStr: String[5];
  Ref: LongInt;
  RefChanged: Boolean;
  Priv, Rcvd: Boolean;
  LPriv, LRcvd: Boolean;          {as read}
  StatusCh: Char;
  HasTag: Boolean;
  EchoFlag: Boolean;
  QNum: LongInt;
  QConf: LongInt;
  Logical: LongInt;
  Deleted: Boolean;
  MsgIdStr: String[200];
  ReplyStr: String[200];
  {the text}
  Txt: QwkBytePtr;
  TxtLen: LongInt;
  TxtCap: LongInt;
  TxtCtr: LongInt;
  MsgDone: Boolean;
  WBuf: QwkBytePtr;               {writing: text so far}
  WLen: LongInt;
  WCap: LongInt;
  WConf: LongInt;                 {conference of the message being written, -1 = not set}
  WEcho: Boolean;
  MailType: MsgMailType;
  NewDate: String[10];
  NewTime: String[8];
  {yours}
  YName: String[40];
  YHandle: String[40];
  YFound: Boolean;
  {settings}
  ReadCs: Byte;
  Style: Byte;
  StyleSet: Boolean;
  RepMode: Boolean;
  UpperNames: Boolean;
  Dropped: Word;
  Cut: Boolean;
  End;


Type QwkMsgObj = Object(AbsMsgObj)
  PI: ^MKQwkInfoType;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetMsgPath(MP: String); Virtual; {Set msg path/other info}
  Function  OpenMsgBase: Word; Virtual; {Open the message base}
  Function  CloseMsgBase: Word; Virtual; {Close the message base}
  Function  CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word; Virtual;
  Function  MsgBaseExists: Boolean; Virtual; {Does msg base exist}
  Function  LockMsgBase: Boolean; Virtual; {Lock the message base}
  Function  UnLockMsgBase: Boolean; Virtual; {Unlock the message base}
  Procedure SetDest(Var Addr: AddrType); Virtual;
  Procedure SetOrig(Var Addr: AddrType); Virtual;
  Procedure SetFrom(Name: String); Virtual; {Set message from}
  Procedure SetTo(Name: String); Virtual; {Set message to}
  Procedure SetSubj(Str: String); Virtual; {Set message subject}
  Procedure SetCost(SCost: Word); Virtual;
  Procedure SetRefer(SRefer: LongInt); Virtual; {Set message reference}
  Procedure SetSeeAlso(SAlso: LongInt); Virtual;
  Procedure SetDate(SDate: String); Virtual; {Set message date: mm-dd-yy}
  Procedure SetTime(STime: String); Virtual; {Set message time: hh:mm}
  Procedure SetLocal(LS: Boolean); Virtual;
  Procedure SetRcvd(RS: Boolean); Virtual; {Set received status}
  Procedure SetPriv(PS: Boolean); Virtual; {Set priveledge vs public status}
  Procedure SetCrash(SS: Boolean); Virtual;
  Procedure SetKillSent(SS: Boolean); Virtual;
  Procedure SetSent(SS: Boolean); Virtual;
  Procedure SetFAttach(SS: Boolean); Virtual;
  Procedure SetReqRct(SS: Boolean); Virtual;
  Procedure SetReqAud(SS: Boolean); Virtual;
  Procedure SetRetRct(SS: Boolean); Virtual;
  Procedure SetFileReq(SS: Boolean); Virtual;
  Procedure SetHold(HS: Boolean); Virtual;
  Function  IsHold: Boolean; Virtual;
  Procedure DoKludgeLn(Str: String); Virtual; {Add ^A kludge line to msg}
  Procedure DoChar(Ch: Char); Virtual; {Add character to message text}
  Function  WriteMsg: Word; Virtual; {Write msg to msg base}
  Function  GetChar: Char; Virtual; {Get msg text character}
  Function  EOM: Boolean; Virtual; {No more msg text}
  Function  GetFrom: String; Virtual; {Get from name on current msg}
  Function  GetTo: String; Virtual; {Get to name on current msg}
  Function  GetSubj: String; Virtual; {Get subject on current msg}
  Function  GetCost: Word; Virtual;
  Function  GetDate: String; Virtual; {mm-dd-yy}
  Function  GetTime: String; Virtual; {hh:mm}
  Function  GetRefer: LongInt; Virtual; {Get reply to of current msg}
  Function  GetSeeAlso: LongInt; Virtual;
  Function  GetNextSeeAlso: LongInt; Virtual;
  Function  GetMsgNum: LongInt; Virtual; {Get message number (position)}
  Function  GetMsgDisplayNum: LongInt; Virtual; {the number in the file}
  Procedure GetOrig(Var Addr: AddrType); Virtual;
  Procedure GetDest(Var Addr: AddrType); Virtual;
  Function  IsLocal: Boolean; Virtual;
  Function  IsCrash: Boolean; Virtual;
  Function  IsKillSent: Boolean; Virtual;
  Function  IsSent: Boolean; Virtual;
  Function  IsFAttach: Boolean; Virtual;
  Function  IsReqRct: Boolean; Virtual;
  Function  IsReqAud: Boolean; Virtual;
  Function  IsRetRct: Boolean; Virtual;
  Function  IsFileReq: Boolean; Virtual;
  Function  IsRcvd: Boolean; Virtual; {Is current msg received}
  Function  IsPriv: Boolean; Virtual; {Is current msg priviledged/private}
  Function  IsDeleted: Boolean; Virtual;
  Function  IsEchoed: Boolean; Virtual;
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
  Function  GetSubArea: Word; Virtual; {the conference}
  Procedure ReWriteHdr; Virtual; {Rewrite msg header after changes}
  Procedure DeleteMsg; Virtual; {Delete current message}
  Procedure SetEcho(ES: Boolean); Virtual; {Set echo status}
  Function  NumberOfMsgs: LongInt; Virtual; {Number of messages}
  Function  GetLastRead(UNum: LongInt): LongInt; Virtual;
  Procedure SetLastRead(UNum: LongInt; LR: LongInt); Virtual;
  Function  GetTxtPos: LongInt; Virtual; {Get indicator of msg text position}
  Procedure SetTxtPos(TP: LongInt); Virtual; {Set text position}
  {QWK files only}
  Procedure SetConference(C: LongInt);       {show this conference only (-1 = all); default for writing}
  Function  GetConference: LongInt;          {the filter, -1 = all}
  Function  GetMsgConf: LongInt;             {conference of the current message}
  Procedure SetMsgConf(C: LongInt);          {conference of the message being written}
  Function  NextConf(After: LongInt): LongInt; {next conference above After that has messages, -1 = none}
  Function  ConfPresent(C: LongInt): Boolean;
  Function  GetQwkNum: LongInt;              {message number written in the file}
  Function  GetLogicalNum: LongInt;
  Function  GetStatusChar: Char;
  Function  GetPassword: String;
  Function  GetHasTag: Boolean;
  Procedure SetHasTag(B: Boolean);
  Function  GetEchoFlag: Boolean;
  Function  GetMsgId: String;
  Function  GetReplyId: String;
  Procedure SetMsgId(Id: String);
  Procedure SetReplyId(Id: String);
  Function  GetPacketId: String;             {block 0, trimmed}
  Procedure SetPacketId(Id: String);         {for CreateMsgBase}
  Procedure SetReadCharset(Cs: Byte);        {qcAuto, qcCp437, qcUtf8, qcLatin1}
  Procedure SetStatusStyle(St: Byte);        {qsQwk, qsPcBoard}
  Procedure SetRepMode(B: Boolean);
  Procedure SetUpperNames(B: Boolean);       {default True}
  Function  GetClean: Boolean;               {the file is whole}
  Function  GetCut: Boolean;                 {the last WriteMsg cut a name or the subject}
  Function  GetDropped: Word;                {kludge lines the last WriteMsg could not keep}
  Function  GetError: Word;
  Function  NumberInFile: LongInt;           {messages in the whole file, killed ones not counted}
  End;


Type QwkMsgPtr = ^QwkMsgObj;


Implementation


Uses MKFile, MKString, MKCp437, BaseUnix, Unix;


Const
  BlkSize = 128;
  EolCh = $E3;
  Killed = 226;
  Active = 225;
  MaxNumber = 9999999;


{---------------------------------------------------------------- small helpers}

Function Z2(N: LongInt): String;
  Begin
  Z2 := Chr(48 + (N Div 10) Mod 10) + Chr(48 + N Mod 10);
  End;


Function AsciiInt(Var H: QwkHdr; Off, Len: Word): LongInt;
  {the number in a blank padded field, -1 when it is not one}
  Var
    i: Word;
    N: LongInt;
    Digits: Boolean;

  Begin
  N := 0;
  Digits := False;
  For i := Off To Off + Len - 1 Do
    Begin
    If (H[i] >= 48) And (H[i] <= 57) Then
      Begin
      N := N * 10 + (H[i] - 48);
      Digits := True;
      End
    Else If H[i] <> 32 Then
      Begin
      AsciiInt := -1;
      Exit;
      End;
    End;
  If Digits Then
    AsciiInt := N
  Else
    AsciiInt := -1;
  End;


Procedure PutAscii(Var H: QwkHdr; Off, Len: Word; N: LongInt);
  {blank padded, left justified; N < 0 = blanks}
  Var
    S: String;
    i: Word;

  Begin
  If N >= 0 Then
    S := Long2Str(N)
  Else
    S := '';
  For i := 0 To Len - 1 Do
    If i < Length(S) Then
      H[Off + i] := Ord(S[i + 1])
    Else
      H[Off + i] := 32;
  End;


Function ValidHdr(Var H: QwkHdr; Var NB: LongInt): Boolean;
  {the header of a message: block count, date and time shaped}
  Const
    Seps = [45, 47, 196];

  Begin
  NB := AsciiInt(H, 116, 6);
  ValidHdr := (NB >= 1) And (H[10] In Seps) And (H[13] In Seps) And (H[18] = 58);
  End;


{ Is the data valid UTF-8 (High: there are bytes above 127) }
Function Utf8Check(P: QwkBytePtr; Len: LongInt; Var High: Boolean; Body: Boolean): Boolean;
  Var
    i: LongInt;
    n, k: Integer;

  Begin
  Utf8Check := False;
  i := 0;
  While i < Len Do
    Begin
    If (P^[i] < $80) Or (Body And (P^[i] = EolCh)) Then    {in a text $E3 ends a line}
      Inc(i)
    Else
      Begin
      High := True;
      If (P^[i] And $E0) = $C0 Then n := 1
      Else If (P^[i] And $F0) = $E0 Then n := 2
      Else If (P^[i] And $F8) = $F0 Then n := 3
      Else
        Exit;
      If i + n > Len - 1 Then
        Exit;
      For k := 1 To n Do
        If (P^[i + k] And $C0) <> $80 Then
          Exit;
      Inc(i, n + 1);
      End;
    End;
  Utf8Check := True;
  End;


{ the CP437 code of the bytes at P[i..] in encoding Enc; N = bytes used }
Function CodeAt(P: QwkBytePtr; i, Len: LongInt; Enc: Byte; Var N: Integer): Byte;
  Var
    U: Word;
    Cp: Byte;

  Begin
  N := 1;
  If P^[i] < $80 Then
    Begin
    CodeAt := P^[i];
    Exit;
    End;
  Case Enc Of
    qcLatin1:
      Cp := Utf8ToCp437(P^[i]);
    qcUtf8:
      Begin
      U := 0;
      If ((P^[i] And $E0) = $C0) And (i + 1 < Len) Then
        Begin
        U := ((P^[i] And $1F) Shl 6) Or (P^[i + 1] And $3F);
        N := 2;
        End
      Else If ((P^[i] And $F0) = $E0) And (i + 2 < Len) Then
        Begin
        U := ((P^[i] And $0F) Shl 12) Or ((Word(P^[i + 1]) And $3F) Shl 6) Or (P^[i + 2] And $3F);
        N := 3;
        End
      Else If ((P^[i] And $F8) = $F0) And (i + 3 < Len) Then
        Begin
        N := 4;
        End;
      If U = 0 Then
        Cp := 0
      Else
        Cp := Utf8ToCp437(U);
      End;
    Else
      Begin
      CodeAt := P^[i];
      Exit;
      End;
    End;
  If Cp = 0 Then
    Cp := Ord('?');
  CodeAt := Cp;
  End;


Function ConvStr(P: QwkBytePtr; Len: LongInt; Enc: Byte): String;
  {a field of the header: the characters in CP437, trailing blanks and nulls off}
  Var
    S: String;
    i: LongInt;
    N: Integer;

  Begin
  S := '';
  i := 0;
  While (i < Len) And (Length(S) < 250) Do
    Begin
    S := S + Chr(CodeAt(P, i, Len, Enc, N));
    Inc(i, N);
    End;
  While (Length(S) > 0) And (S[Length(S)] In [' ', #0]) Do
    Dec(S[0]);
  ConvStr := S;
  End;


{---------------------------------------------------------------- the entry and view tables}

Procedure FreeText(Var PI: MKQwkInfoType);
  Begin
  With PI Do
    Begin
    If Txt <> Nil Then
      FreeMem(Txt, TxtCap);
    Txt := Nil;
    TxtCap := 0;
    TxtLen := 0;
    TxtCtr := 0;
    End;
  End;


Procedure FreeTables(Var PI: MKQwkInfoType);
  Begin
  With PI Do
    Begin
    If Ent <> Nil Then
      FreeMem(Ent, EntCap * SizeOf(QwkEntry));
    Ent := Nil;
    EntCap := 0;
    NumEnt := 0;
    If View <> Nil Then
      FreeMem(View, ViewCap * SizeOf(LongInt));
    View := Nil;
    ViewCap := 0;
    NumView := 0;
    End;
  End;


Function AddEntry(Var PI: MKQwkInfoType; Blk, NB, Num: LongInt; Conf: Word; Act: Boolean): Boolean;
  Var
    NewCap: LongInt;
    NewEnt: QwkEntPtr;

  Begin
  AddEntry := False;
  With PI Do
    Begin
    If NumEnt >= EntCap Then
      Begin
      NewCap := EntCap + EntCap Div 2 + 256;
      GetMem(NewEnt, NewCap * SizeOf(QwkEntry));
      If NewEnt = Nil Then
        Exit;
      If Ent <> Nil Then
        Begin
        Move(Ent^, NewEnt^, NumEnt * SizeOf(QwkEntry));
        FreeMem(Ent, EntCap * SizeOf(QwkEntry));
        End;
      Ent := NewEnt;
      EntCap := NewCap;
      End;
    Ent^[NumEnt].Blk := Blk;
    Ent^[NumEnt].NB := NB;
    Ent^[NumEnt].Num := Num;
    Ent^[NumEnt].Conf := Conf;
    Ent^[NumEnt].Active := Act;
    Inc(NumEnt);
    End;
  AddEntry := True;
  End;


Function InView(Var PI: MKQwkInfoType; Var E: QwkEntry): Boolean;
  Begin
  InView := E.Active And ((PI.Filter < 0) Or (PI.Filter = E.Conf));
  End;


Function AddView(Var PI: MKQwkInfoType; EntIdx: LongInt): Boolean;
  Var
    NewCap: LongInt;
    NewV: QwkLongPtr;

  Begin
  AddView := False;
  With PI Do
    Begin
    If NumView >= ViewCap Then
      Begin
      NewCap := ViewCap + ViewCap Div 2 + 256;
      GetMem(NewV, NewCap * SizeOf(LongInt));
      If NewV = Nil Then
        Exit;
      If View <> Nil Then
        Begin
        Move(View^, NewV^, NumView * SizeOf(LongInt));
        FreeMem(View, ViewCap * SizeOf(LongInt));
        End;
      View := NewV;
      ViewCap := NewCap;
      End;
    View^[NumView] := EntIdx;
    Inc(NumView);
    End;
  AddView := True;
  End;


Procedure BuildView(Var PI: MKQwkInfoType);
  Var
    i: LongInt;

  Begin
  With PI Do
    Begin
    NumView := 0;
    FillChar(ConfBits, SizeOf(ConfBits), 0);
    For i := 0 To NumEnt - 1 Do
      If Ent^[i].Active Then
        Begin
        ConfBits[Ent^[i].Conf Shr 3] := ConfBits[Ent^[i].Conf Shr 3] Or (1 Shl (Ent^[i].Conf And 7));
        If InView(PI, Ent^[i]) Then
          If Not AddView(PI, i) Then
            Error := 1010;
        End;
    End;
  End;


Procedure ScanFile(Var PI: MKQwkInfoType);
  {the chain of messages: header to header; what does not look like a header is skipped}
  Var
    Pos, Sz: LongInt;
    H: QwkHdr;
    NB, N: LongInt;
    Got: Word;
    Conf: Word;

  Begin
  With PI Do
    Begin
    NumEnt := 0;
    NumView := 0;
    Clean := True;
    Sz := FileSize(F);
    Size := Sz;
    If Sz Mod BlkSize <> 0 Then
      Clean := False;
    Pos := BlkSize;
    While Pos + BlkSize <= Sz Do
      Begin
      Seek(F, Pos);
      BlockRead(F, H, BlkSize, Got);
      If (IoResult <> 0) Or (Got <> BlkSize) Then
        Begin
        Clean := False;
        Break;
        End;
      If ValidHdr(H, NB) Then
        Begin
        If Pos + NB * BlkSize > Sz Then
          Begin
          NB := (Sz - Pos) Div BlkSize;           {runs past the end: what is there}
          Clean := False;
          End;
        N := AsciiInt(H, 1, 7);
        If N < 0 Then
          N := 0;
        Conf := H[123] Or (Word(H[124]) Shl 8);
        If Not AddEntry(PI, Pos Div BlkSize, NB, N, Conf, H[122] <> Killed) Then
          Begin
          Error := 1010;
          Break;
          End;
        Inc(Pos, NB * BlkSize);
        End
      Else
        Begin
        Clean := False;
        Inc(Pos, BlkSize);
        End;
      End;
    End;
  BuildView(PI);
  End;


{---------------------------------------------------------------- reading a message}

Function FindKludge(Body: QwkBytePtr; S, E: LongInt; Var ValStart: LongInt): Integer;
  {a leading @VIA: / @MSGID: / @REPLY: / @TZ: line: 1 Via, 2 MSGID, 3 REPLY, 4 TZ, 0 not one}
  Const
    Names: Array[1..4] Of String[5] = ('VIA', 'MSGID', 'REPLY', 'TZ');
  Var
    k, j: Integer;
    Ok: Boolean;
    C: Byte;

  Begin
  FindKludge := 0;
  If (E - S < 4) Or (Body^[S] <> Ord('@')) Then
    Exit;
  For k := 1 To 4 Do
    Begin
    If S + Length(Names[k]) + 1 >= E Then
      Ok := False
    Else
      Begin
      Ok := True;
      For j := 1 To Length(Names[k]) Do
        Begin
        C := Body^[S + j];
        If (C >= 97) And (C <= 122) Then
          Dec(C, 32);
        If C <> Ord(Names[k][j]) Then
          Ok := False;
        End;
      If Ok And (Body^[S + Length(Names[k]) + 1] <> Ord(':')) Then
        Ok := False;
      End;
    If Ok Then
      Begin
      ValStart := S + Length(Names[k]) + 2;
      If (ValStart < E) And (Body^[ValStart] In [32, 9]) Then
        Inc(ValStart);
      FindKludge := k;
      Exit;
      End;
    End;
  End;


Procedure PutTxt(Var PI: MKQwkInfoType; B: Byte);
  Begin
  With PI Do
    If TxtLen < TxtCap Then
      Begin
      Txt^[TxtLen] := B;
      Inc(TxtLen);
      End;
  End;


Procedure PutTxtStr(Var PI: MKQwkInfoType; Const S: String);
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    PutTxt(PI, Ord(S[i]));
  End;


Function EffStyle(Var PI: MKQwkInfoType): Byte;
  {the status style: as set, else PCBoard's in a REP file (SetRepMode), else the QWK one}
  Begin
  If PI.StyleSet Then
    EffStyle := PI.Style
  Else If PI.RepMode Then
    EffStyle := qsPcBoard
  Else
    EffStyle := qsQwk;
  End;


Procedure LoadMsg(Var PI: MKQwkInfoType; Var E: QwkEntry);
  Var
    H: QwkHdr;
    Got: Word;
    Body: QwkBytePtr;
    BodyLen, i, LineStart, VS, j: LongInt;
    Enc: Byte;
    High, Ok: Boolean;
    St: Char;
    N: Integer;
    Leading: Boolean;
    Kind: Integer;
    Val: String;

  Begin
  With PI Do
    Begin
    FreeText(PI);
    Seek(F, E.Blk * BlkSize);
    BlockRead(F, H, BlkSize, Got);
    If (IoResult <> 0) Or (Got <> BlkSize) Then
      Begin
      Error := 1000;
      Exit;
      End;
    BodyLen := (E.NB - 1) * BlkSize;
    Body := Nil;
    If BodyLen > 0 Then
      Begin
      GetMem(Body, BodyLen);
      If Body = Nil Then
        Begin
        Error := 1010;
        Exit;
        End;
      Seek(F, (E.Blk + 1) * BlkSize);
      BlockRead(F, Body^, BodyLen, Got);
      If (IoResult <> 0) Or (Got <> BodyLen) Then
        Begin
        FillChar(Body^[Got], BodyLen - Got, 32);
        End;
      While (BodyLen > 0) And ((Body^[BodyLen - 1] = 32) Or (Body^[BodyLen - 1] = 0)) Do
        Dec(BodyLen);
      End;
    {which character set}
    Enc := ReadCs;
    If Enc = qcAuto Then
      Begin
      High := False;
      Ok := True;
      If BodyLen > 0 Then
        If Not Utf8Check(Body, BodyLen, High, True) Then
          Ok := False;
      If Ok Then
        For i := 0 To 2 Do
          If Not Utf8Check(@H[21 + i * 25], 25, High, False) Then
            Ok := False;
      If Ok And High Then
        Enc := qcUtf8
      Else
        Enc := qcCp437;
      End;
    {the header}
    QNum := AsciiInt(H, 1, 7);
    If QNum < 0 Then
      QNum := 0;
    QConf := H[123] Or (Word(H[124]) Shl 8);
    Logical := H[125] Or (Word(H[126]) Shl 8);
    ToStr := ConvStr(@H[21], 25, Enc);
    FromStr := ConvStr(@H[46], 25, Enc);
    SubjStr := ConvStr(@H[71], 25, Enc);
    PwdStr := ConvStr(@H[96], 12, qcCp437);
    DateStr := '';
    For i := 8 To 15 Do
      DateStr := DateStr + Chr(H[i]);
    If DateStr[3] = '/' Then DateStr[3] := '-';
    If DateStr[6] = '/' Then DateStr[6] := '-';
    TimeStr := '';
    For i := 16 To 20 Do
      TimeStr := TimeStr + Chr(H[i]);
    Ref := AsciiInt(H, 108, 8);
    If Ref < 0 Then
      Ref := 0;
    RefChanged := False;
    St := Chr(H[0]);
    StatusCh := St;
    If EffStyle(PI) = qsPcBoard Then
      Begin
      Priv := St In ['*', '+', '~', '`', '%', '^', '!', '#'];
      Rcvd := St In ['+', '-', '`', '^', '#'];
      End
    Else
      Begin
      Priv := St In ['+', '*', '~', '`', '%', '^'];
      Rcvd := St In ['-', '*', '`', '^', '#'];
      End;
    LPriv := Priv;
    LRcvd := Rcvd;
    Deleted := H[122] = Killed;
    HasTag := H[127] = Ord('*');
    EchoFlag := H[126] = Ord('E');
    MsgIdStr := '';
    ReplyStr := '';
    {the text: lines end in $E3 (or $0D); leading @ lines become kludge lines}
    TxtCap := BodyLen * 2 + 64;
    GetMem(Txt, TxtCap);
    TxtLen := 0;
    TxtCtr := 0;
    MsgDone := False;
    Leading := True;
    LineStart := 0;
    i := 0;
    While i <= BodyLen Do
      Begin
      If (i = BodyLen) Or (Body^[i] = EolCh) Or (Body^[i] = 13) Then
        Begin
        If (i > LineStart) Or (i < BodyLen) Then
          Begin
          Kind := 0;
          If Leading Then
            Kind := FindKludge(Body, LineStart, i, VS);
          If Kind > 0 Then
            Begin
            Val := ConvStr(@Body^[VS], i - VS, Enc);
            While (Length(Val) > 0) And (Val[1] = ' ') Do
              Delete(Val, 1, 1);
            Case Kind Of
              1: PutTxtStr(PI, #1 + 'Via ' + Val);
              2: Begin
                 PutTxtStr(PI, #1 + 'MSGID: ' + Val);
                 If MsgIdStr = '' Then
                   MsgIdStr := Val;
                 End;
              3: Begin
                 PutTxtStr(PI, #1 + 'REPLY: ' + Val);
                 If ReplyStr = '' Then
                   ReplyStr := Val;
                 End;
              4: PutTxtStr(PI, #1 + 'TZ: ' + Val);
              End;
            PutTxt(PI, 13);
            End
          Else
            Begin
            Leading := False;
            j := LineStart;
            While j < i Do
              Begin
              If Body^[j] <> 10 Then
                PutTxt(PI, CodeAt(Body, j, i, Enc, N))
              Else
                N := 1;
              Inc(j, N);
              End;
            PutTxt(PI, 13);
            End;
          End;
        LineStart := i + 1;
        End;
      Inc(i);
      End;
    If Body <> Nil Then
      FreeMem(Body, (E.NB - 1) * BlkSize);
    {no empty lines at the end}
    While (TxtLen >= 2) And (Txt^[TxtLen - 1] = 13) And (Txt^[TxtLen - 2] = 13) Do
      Dec(TxtLen);
    If (TxtLen = 1) And (Txt^[0] = 13) Then
      TxtLen := 0;
    End;
  End;


Procedure ClearMsg(Var PI: MKQwkInfoType);
  Begin
  With PI Do
    Begin
    FreeText(PI);
    FromStr := '';
    ToStr := '';
    SubjStr := '';
    PwdStr := '';
    DateStr := '';
    TimeStr := '';
    Ref := 0;
    RefChanged := False;
    Priv := False;
    Rcvd := False;
    LPriv := False;
    LRcvd := False;
    StatusCh := ' ';
    HasTag := False;
    EchoFlag := False;
    QNum := 0;
    QConf := 0;
    Logical := 0;
    Deleted := False;
    MsgIdStr := '';
    ReplyStr := '';
    MsgDone := False;
    End;
  End;


Procedure Need(Var PI: MKQwkInfoType);
  Begin
  With PI Do
    Begin
    If Writing Or (Parsed = Cur) Then
      Exit;
    Parsed := Cur;
    ClearMsg(PI);
    If Opened And (Cur >= 1) And (Cur <= NumView) Then
      LoadMsg(PI, Ent^[View^[Cur - 1]]);
    End;
  End;


{---------------------------------------------------------------- create, destroy, open, close}

Constructor QwkMsgObj.Init;
  Begin
  Inherited Init;
  New(PI);
  FillChar(PI^, SizeOf(PI^), 0);
  With PI^ Do
    Begin
    Filter := -1;
    WConf := -1;
    ReadCs := qcCp437;
    UpperNames := True;
    PacketId := 'QWK';
    MailType := mmtNormal;
    End;
  End;


Destructor QwkMsgObj.Done;
  Begin
  If PI^.Opened Then
    CloseMsgBase;
  FreeText(PI^);
  FreeTables(PI^);
  If PI^.WBuf <> Nil Then
    FreeMem(PI^.WBuf, PI^.WCap);
  Dispose(PI);
  Inherited Done;
  End;


Procedure QwkMsgObj.SetMsgPath(MP: String);
  Begin
  If PI^.Opened Then
    CloseMsgBase;
  PI^.FN := MP;
  End;


Function QwkMsgObj.MsgBaseExists: Boolean;
  Begin
  MsgBaseExists := (PI^.FN <> '') And FileExist(PI^.FN);
  End;


Function QwkMsgObj.OpenMsgBase: Word;
  Var
    Sz: LongInt;
    Blk0: QwkHdr;
    Got: Word;
    i: Word;

  Begin
  OpenMsgBase := 0;
  With PI^ Do
    Begin
    Error := 0;
    If Opened Then
      Exit;
    If FN = '' Then
      Begin
      Error := 1002;
      OpenMsgBase := Error;
      Exit;
      End;
    If Not FileExist(FN) Then
      Begin
      Error := 1001;
      OpenMsgBase := Error;
      Exit;
      End;
    Assign(F, FN);
    FileMode := 2;
    Reset(F, 1);
    ReadOnly := False;
    If IoResult <> 0 Then
      Begin
      FileMode := 0;
      Reset(F, 1);
      ReadOnly := True;
      End;
    FileMode := 2;
    If IoResult <> 0 Then
      Begin
      Error := 1000;
      OpenMsgBase := Error;
      Exit;
      End;
    Sz := FileSize(F);
    If Sz < BlkSize Then
      Begin
      Close(F);
      If IoResult <> 0 Then;
      Error := 1003;
      OpenMsgBase := Error;
      Exit;
      End;
    Opened := True;
    Locked := False;
    {block 0: the packet id}
    PacketId := '';
    Seek(F, 0);
    BlockRead(F, Blk0, BlkSize, Got);
    If (IoResult = 0) And (Got = BlkSize) Then
      Begin
      i := 0;
      While (i < BlkSize) And (Blk0[i] >= 32) And (Length(PacketId) < 128) Do
        Begin
        PacketId := PacketId + Chr(Blk0[i]);
        Inc(i);
        End;
      While (Length(PacketId) > 0) And (PacketId[Length(PacketId)] = ' ') Do
        Dec(PacketId[0]);
      End;
    ScanFile(PI^);
    Cur := 0;
    Parsed := 0;
    Writing := False;
    OpenMsgBase := Error;
    End;
  End;


Function QwkMsgObj.CloseMsgBase: Word;
  Begin
  CloseMsgBase := 0;
  With PI^ Do
    Begin
    If Not Opened Then
      Exit;
    If Locked Then
      UnLockMsgBase;
    Close(F);
    If IoResult <> 0 Then;
    Opened := False;
    FreeText(PI^);
    FreeTables(PI^);
    Cur := 0;
    Parsed := 0;
    End;
  End;


Function QwkMsgObj.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word;
  Var
    H: QwkHdr;
    i: Word;
    Fl: File;

  Begin
  CreateMsgBase := 0;
  With PI^ Do
    Begin
    Error := 0;
    If FN = '' Then
      Begin
      Error := 1002;
      CreateMsgBase := Error;
      Exit;
      End;
    If FileExist(FN) Then
      Begin
      Error := 1009;
      CreateMsgBase := Error;
      Exit;
      End;
    Assign(Fl, FN);
    FileMode := 2;
    ReWrite(Fl, 1);
    If IoResult <> 0 Then
      Begin
      Error := 1000;
      CreateMsgBase := Error;
      Exit;
      End;
    FillChar(H, SizeOf(H), 32);
    For i := 1 To Length(PacketId) Do
      If i <= BlkSize Then
        H[i - 1] := Ord(PacketId[i]);
    BlockWrite(Fl, H, BlkSize);
    If IoResult <> 0 Then
      Error := 1013;
    Close(Fl);
    If IoResult <> 0 Then;
    If Error <> 0 Then
      Begin
      CreateMsgBase := Error;
      Exit;
      End;
    End;
  CreateMsgBase := OpenMsgBase;
  End;


Function QwkMsgObj.LockMsgBase: Boolean;
  Var
    Tries: Integer;

  Begin
  LockMsgBase := False;
  With PI^ Do
    Begin
    If Not Opened Then
      Exit;
    If Locked Then
      Begin
      LockMsgBase := True;
      Exit;
      End;
    For Tries := 1 To 100 Do
      Begin
      If fpFlock(FileRec(F).Handle, LOCK_EX Or LOCK_NB) = 0 Then
        Begin
        Locked := True;
        LockMsgBase := True;
        Exit;
        End;
      fpSelect(0, Nil, Nil, Nil, 50);
      End;
    Error := 1015;
    End;
  End;


Function QwkMsgObj.UnLockMsgBase: Boolean;
  Begin
  UnLockMsgBase := False;
  With PI^ Do
    If Opened And Locked Then
      Begin
      fpFlock(FileRec(F).Handle, LOCK_UN);
      Locked := False;
      UnLockMsgBase := True;
      End;
  End;


{---------------------------------------------------------------- setting what is written}

Procedure QwkMsgObj.SetDest(Var Addr: AddrType);
  Begin
  End;


Procedure QwkMsgObj.SetOrig(Var Addr: AddrType);
  Begin
  End;


Procedure QwkMsgObj.SetFrom(Name: String);
  Begin
  PI^.FromStr := Copy(Name, 1, 80);
  End;


Procedure QwkMsgObj.SetTo(Name: String);
  Begin
  PI^.ToStr := Copy(Name, 1, 80);
  End;


Procedure QwkMsgObj.SetSubj(Str: String);
  Begin
  PI^.SubjStr := Copy(Str, 1, 80);
  End;


Procedure QwkMsgObj.SetCost(SCost: Word);
  Begin
  End;


Procedure QwkMsgObj.SetRefer(SRefer: LongInt);
  Begin
  PI^.Ref := SRefer;
  PI^.RefChanged := True;
  End;


Procedure QwkMsgObj.SetSeeAlso(SAlso: LongInt);
  Begin
  End;


Procedure QwkMsgObj.SetDate(SDate: String);
  {mm-dd-yy}
  Begin
  PI^.NewDate := Copy(SDate, 1, 10);
  End;


Procedure QwkMsgObj.SetTime(STime: String);
  {hh:mm}
  Begin
  PI^.NewTime := Copy(STime, 1, 8);
  End;


Procedure QwkMsgObj.SetLocal(LS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetRcvd(RS: Boolean);
  Begin
  PI^.Rcvd := RS;
  End;


Procedure QwkMsgObj.SetPriv(PS: Boolean);
  Begin
  PI^.Priv := PS;
  End;


Procedure QwkMsgObj.SetCrash(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetKillSent(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetSent(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetFAttach(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetReqRct(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetReqAud(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetRetRct(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetFileReq(SS: Boolean);
  Begin
  End;


Procedure QwkMsgObj.SetHold(HS: Boolean);
  Begin
  End;


Function QwkMsgObj.IsHold: Boolean;
  Begin
  IsHold := False;
  End;


Procedure QwkMsgObj.SetEcho(ES: Boolean);
  Begin
  PI^.WEcho := ES;
  End;


Procedure QwkMsgObj.SetMailType(MT: MsgMailType);
  Begin
  PI^.MailType := MT;
  End;


Procedure QwkMsgObj.SetConference(C: LongInt);
  Begin
  With PI^ Do
    Begin
    If C > 65535 Then
      C := 65535;
    If C < -1 Then
      C := -1;
    Filter := C;
    Writing := False;
    Cur := 0;
    Parsed := 0;
    If Opened Then
      BuildView(PI^);
    End;
  End;


Function QwkMsgObj.GetConference: LongInt;
  Begin
  GetConference := PI^.Filter;
  End;


Procedure QwkMsgObj.SetMsgConf(C: LongInt);
  Begin
  PI^.WConf := C;
  End;


Function QwkMsgObj.GetMsgConf: LongInt;
  Begin
  Need(PI^);
  If PI^.Writing Then
    Begin
    If PI^.WConf >= 0 Then
      GetMsgConf := PI^.WConf
    Else If PI^.Filter >= 0 Then
      GetMsgConf := PI^.Filter
    Else
      GetMsgConf := 0;
    End
  Else
    GetMsgConf := PI^.QConf;
  End;


Function QwkMsgObj.ConfPresent(C: LongInt): Boolean;
  Begin
  ConfPresent := (C >= 0) And (C <= 65535) And
    ((PI^.ConfBits[C Shr 3] And (1 Shl (C And 7))) <> 0);
  End;


Function QwkMsgObj.NextConf(After: LongInt): LongInt;
  Var
    C: LongInt;

  Begin
  NextConf := -1;
  C := After + 1;
  If C < 0 Then
    C := 0;
  While C <= 65535 Do
    Begin
    If ConfPresent(C) Then
      Begin
      NextConf := C;
      Exit;
      End;
    Inc(C);
    End;
  End;


Procedure QwkMsgObj.SetHasTag(B: Boolean);
  Begin
  PI^.HasTag := B;
  End;


Procedure QwkMsgObj.SetMsgId(Id: String);
  Begin
  PI^.MsgIdStr := Copy(Id, 1, 200);
  End;


Procedure QwkMsgObj.SetReplyId(Id: String);
  Begin
  PI^.ReplyStr := Copy(Id, 1, 200);
  End;


Procedure QwkMsgObj.SetPacketId(Id: String);
  Begin
  PI^.PacketId := Copy(Id, 1, 128);
  End;


Procedure QwkMsgObj.SetReadCharset(Cs: Byte);
  Begin
  PI^.ReadCs := Cs;
  End;


Procedure QwkMsgObj.SetStatusStyle(St: Byte);
  Begin
  PI^.Style := St;
  PI^.StyleSet := True;
  End;


Procedure QwkMsgObj.SetRepMode(B: Boolean);
  Begin
  PI^.RepMode := B;
  End;


Procedure QwkMsgObj.SetUpperNames(B: Boolean);
  Begin
  PI^.UpperNames := B;
  End;


{---------------------------------------------------------------- the text being written}

Procedure QwkMsgObj.DoKludgeLn(Str: String);
  Begin
  If (Length(Str) = 0) Or (Str[1] <> #1) Then
    Str := #1 + Str;
  DoStringLn(Str);
  End;


Procedure QwkMsgObj.DoChar(Ch: Char);
  Var
    NewCap: LongInt;
    NewBuf: QwkBytePtr;

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


Procedure QwkMsgObj.StartNewMsg;
  Begin
  With PI^ Do
    Begin
    Writing := True;
    FromStr := '';
    ToStr := '';
    SubjStr := '';
    PwdStr := '';
    NewDate := '';
    NewTime := '';
    Ref := 0;
    RefChanged := False;
    Priv := False;
    Rcvd := False;
    HasTag := False;
    EchoFlag := False;
    MsgIdStr := '';
    ReplyStr := '';
    WConf := -1;
    WEcho := False;
    WLen := 0;
    End;
  End;


{---------------------------------------------------------------- writing}

Function StatusByte(Var PI: MKQwkInfoType; Pv, Rc: Boolean): Byte;
  {the status character for private / received}
  Var
    St: Byte;

  Begin
  St := EffStyle(PI);
  If Pv Then
    Begin
    If St = qsPcBoard Then
      Begin
      If Rc Then StatusByte := Ord('+') Else StatusByte := Ord('*');
      End
    Else
      Begin
      If Rc Then StatusByte := Ord('*') Else StatusByte := Ord('+');
      End;
    End
  Else
    Begin
    If Rc Then StatusByte := Ord('-') Else StatusByte := 32;
    End;
  End;


Procedure PutField(Var H: QwkHdr; Off: Word; Const S: String; Var Cut: Boolean);
  {25 bytes, upper case is the caller's business}
  Var
    i: Word;

  Begin
  For i := 0 To 24 Do
    If i < Length(S) Then
      H[Off + i] := Ord(S[i + 1])
    Else
      H[Off + i] := 32;
  If Length(S) > 25 Then
    Cut := True;
  End;


Function QwkMsgObj.WriteMsg: Word;
  Var
    H: QwkHdr;
    Body: QwkBytePtr;
    BodyLen, BodyCap: LongInt;
    Lead: Array[1..4] Of String[200];     {MSGID, REPLY, Via, TZ}
    Have: Array[1..4] Of Boolean;
    i, LineStart, LineEnd, k, Number, MaxNum, Conf, OldSize, NB: LongInt;
    S, T: String;
    Ch: Byte;
    LockedHere: Boolean;
    Res: Word;
    Yy, Mo, Dd, Dw, Hh, Mi, Ss, Cs: Word;
    NowDate, NowTime: String;
    Pad: LongInt;
    Echo: Boolean;

  Procedure PutB(B: Byte);
    Begin
    If BodyLen < BodyCap Then
      Begin
      Body^[BodyLen] := B;
      Inc(BodyLen);
      End;
    End;

  Function MapCh(B: Byte): Byte;
    {the line terminator and control characters of a line cannot be in it}
    Begin
    If (B = EolCh) Or (B = 13) Or (B = 10) Then
      MapCh := Ord('?')
    Else If B = 0 Then
      MapCh := 32
    Else
      MapCh := B;
    End;

  Procedure PutLine(Const L: String);
    Var
      j: Word;
    Begin
    For j := 1 To Length(L) Do
      PutB(MapCh(Ord(L[j])));
    PutB(EolCh);
    End;

  Function KludgeVal(Const L, Name: String; Var V: String): Boolean;
    {L (without the ^A) starts with Name and ':' or ' '}
    Begin
    KludgeVal := False;
    If (Length(L) > Length(Name)) And (Upper(Copy(L, 1, Length(Name))) = Name) And
       (L[Length(Name) + 1] In [':', ' ']) Then
      Begin
      V := StripBoth(Copy(L, Length(Name) + 2, 250), ' ');
      KludgeVal := True;
      End;
    End;

  Begin
  WriteMsg := 0;
  With PI^ Do
    Begin
    Error := 0;
    Cut := False;
    Dropped := 0;
    If Not Opened Then
      Begin
      Error := 1001;
      WriteMsg := Error;
      Exit;
      End;
    If ReadOnly Then
      Begin
      Error := 1011;
      WriteMsg := Error;
      Exit;
      End;
    If Not Clean Then
      Begin
      Error := 1004;
      WriteMsg := Error;
      Exit;
      End;
    S := FromStr;
    For i := 1 To Length(S) Do
      If S[i] < ' ' Then S[i] := ' ';
    S := StripBoth(S, ' ');
    If S = '' Then
      Begin
      Error := 1005;
      WriteMsg := Error;
      Exit;
      End;
    {the text: lines end in #13; ^A lines are kludges}
    BodyCap := WLen * 2 + 1024;
    GetMem(Body, BodyCap);
    If Body = Nil Then
      Begin
      Error := 1010;
      WriteMsg := Error;
      Exit;
      End;
    BodyLen := 0;
    For i := 1 To 4 Do
      Begin
      Lead[i] := '';
      Have[i] := False;
      End;
    If MsgIdStr <> '' Then
      Begin
      Lead[1] := MsgIdStr;
      Have[1] := True;
      End;
    If ReplyStr <> '' Then
      Begin
      Lead[2] := ReplyStr;
      Have[2] := True;
      End;
    {first pass: kludges}
    LineStart := 0;
    For i := 0 To WLen Do
      If (i = WLen) Or (WBuf^[i] = 13) Then
        Begin
        If (i > LineStart) And (WBuf^[LineStart] = 1) Then
          Begin
          T := '';
          For k := LineStart + 1 To i - 1 Do
            If Length(T) < 250 Then
              T := T + Chr(WBuf^[k]);
          If KludgeVal(T, 'MSGID', S) Then
            Begin
            If Not Have[1] Then Begin Lead[1] := S; Have[1] := True; End;
            End
          Else If KludgeVal(T, 'REPLY', S) Then
            Begin
            If Not Have[2] Then Begin Lead[2] := S; Have[2] := True; End;
            End
          Else If KludgeVal(T, 'VIA', S) Then
            Begin
            If Not Have[3] Then Begin Lead[3] := S; Have[3] := True; End;
            End
          Else If KludgeVal(T, 'TZ', S) Then
            Begin
            If Not Have[4] Then Begin Lead[4] := S; Have[4] := True; End;
            End
          Else
            Inc(Dropped);
          End;
        LineStart := i + 1;
        End;
    If Have[1] Then PutLine('@MSGID: ' + Lead[1]);
    If Have[2] Then PutLine('@REPLY: ' + Lead[2]);
    If Have[3] Then PutLine('@VIA: ' + Lead[3]);
    If Have[4] Then PutLine('@TZ: ' + Lead[4]);
    {second pass: the text lines (no empty ones at the end)}
    LineEnd := WLen;
    While (LineEnd > 0) And (WBuf^[LineEnd - 1] In [13, 10, 32]) Do
      Dec(LineEnd);
    If LineEnd = 0 Then
      Begin
      FreeMem(Body, BodyCap);
      Error := 1006;
      WriteMsg := Error;
      Exit;
      End;
    LineStart := 0;
    For i := 0 To LineEnd Do
      If (i = LineEnd) Or (WBuf^[i] = 13) Then
        Begin
        If Not ((i > LineStart) And (WBuf^[LineStart] = 1)) Then
          Begin
          For k := LineStart To i - 1 Do
            If WBuf^[k] <> 10 Then
              PutB(MapCh(WBuf^[k]));
          PutB(EolCh);
          End;
        LineStart := i + 1;
        End;
    Pad := (BlkSize - (BodyLen Mod BlkSize)) Mod BlkSize;
    While Pad > 0 Do
      Begin
      PutB(32);
      Dec(Pad);
      End;
    NB := 1 + BodyLen Div BlkSize;
    If NB > 999999 Then
      Begin
      FreeMem(Body, BodyCap);
      Error := 1007;
      WriteMsg := Error;
      Exit;
      End;
    {the conference}
    If WConf >= 0 Then
      Conf := WConf
    Else If Filter >= 0 Then
      Conf := Filter
    Else
      Conf := 0;
    If Conf > 65535 Then
      Begin
      FreeMem(Body, BodyCap);
      Error := 1008;
      WriteMsg := Error;
      Exit;
      End;
    {lock, and see that the file is as we know it}
    LockedHere := False;
    If Not Locked Then
      Begin
      If Not LockMsgBase Then
        Begin
        FreeMem(Body, BodyCap);
        WriteMsg := Error;
        Exit;
        End;
      LockedHere := True;
      End;
    Res := 0;
    If FileSize(F) <> Size Then
      Begin
      FreeTables(PI^);
      ScanFile(PI^);
      If (Size Mod BlkSize <> 0) Or Not Clean Then
        Res := 1004;
      End;
    If Res = 0 Then
      Begin
      OldSize := Size;
      {number: in a REP the conference, else the next one in the conference}
      If RepMode Then
        Number := Conf
      Else
        Begin
        MaxNum := 0;
        For i := 0 To NumEnt - 1 Do
          If (Ent^[i].Conf = Conf) And (Ent^[i].Num > MaxNum) Then
            MaxNum := Ent^[i].Num;
        Number := MaxNum + 1;
        If Number > MaxNumber Then
          Res := 1007;
        End;
      End;
    If Res = 0 Then
      Begin
      FillChar(H, SizeOf(H), 32);
      Ch := StatusByte(PI^, Priv, Rcvd);
      H[0] := Ch;
      PutAscii(H, 1, 7, Number);
      Dos.GetDate(Yy, Mo, Dd, Dw);
      Dos.GetTime(Hh, Mi, Ss, Cs);
      NowDate := Z2(Mo) + '-' + Z2(Dd) + '-' + Z2(Yy Mod 100);
      NowTime := Z2(Hh) + ':' + Z2(Mi);
      S := NewDate;
      If Length(S) < 8 Then
        S := NowDate;
      For i := 1 To 8 Do
        H[7 + i] := Ord(S[i]);
      S := NewTime;
      If Length(S) < 5 Then
        S := NowTime;
      For i := 1 To 5 Do
        H[15 + i] := Ord(S[i]);
      S := ToStr;
      For i := 1 To Length(S) Do
        If S[i] < ' ' Then S[i] := ' ';
      S := StripBoth(S, ' ');
      If S = '' Then
        S := 'ALL';
      If UpperNames Then
        S := Upper(S);
      PutField(H, 21, S, Cut);
      S := FromStr;
      For i := 1 To Length(S) Do
        If S[i] < ' ' Then S[i] := ' ';
      S := StripBoth(S, ' ');
      If UpperNames Then
        S := Upper(S);
      PutField(H, 46, S, Cut);
      S := SubjStr;
      For i := 1 To Length(S) Do
        If S[i] < ' ' Then S[i] := ' ';
      S := StripBoth(S, ' ');
      PutField(H, 71, S, Cut);
      If (Ref > 0) And (Ref <= 99999999) Then
        PutAscii(H, 108, 8, Ref)
      Else
        PutAscii(H, 108, 8, -1);
      PutAscii(H, 116, 6, NB);
      H[122] := Active;
      H[123] := Conf And 255;
      H[124] := Conf Shr 8;
      Echo := WEcho Or (MailType = mmtEchoMail);
      If RepMode Then
        Begin
        H[125] := 32;
        If Echo Then H[126] := Ord('E') Else H[126] := 32;
        End
      Else
        Begin
        H[125] := (NumEnt + 1) And 255;
        H[126] := ((NumEnt + 1) Shr 8) And 255;
        End;
      If HasTag Then
        H[127] := Ord('*')
      Else
        H[127] := 32;
      {append; on failure the file goes back}
      Seek(F, OldSize);
      BlockWrite(F, H, BlkSize);
      If IoResult <> 0 Then
        Res := 1013
      Else
        Begin
        BlockWrite(F, Body^, BodyLen);
        If IoResult <> 0 Then
          Res := 1013;
        End;
      If Res <> 0 Then
        Begin
        Seek(F, OldSize);
        Truncate(F);
        If IoResult <> 0 Then;
        End
      Else
        Begin
        If AddEntry(PI^, OldSize Div BlkSize, NB, Number, Conf, True) Then
          Begin
          Size := OldSize + BlkSize + BodyLen;
          ConfBits[Conf Shr 3] := ConfBits[Conf Shr 3] Or (1 Shl (Conf And 7));
          If InView(PI^, Ent^[NumEnt - 1]) Then
            AddView(PI^, NumEnt - 1);
          LastNum := Number;
          End
        Else
          Res := 1010;
        End;
      End;
    If LockedHere Then
      UnLockMsgBase;
    FreeMem(Body, BodyCap);
    Error := Res;
    WriteMsg := Res;
    End;
  End;


{---------------------------------------------------------------- reading the current message}

Function QwkMsgObj.GetChar: Char;
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


Function QwkMsgObj.EOM: Boolean;
  Begin
  EOM := PI^.MsgDone;
  End;


Function QwkMsgObj.GetTxtPos: LongInt;
  Begin
  GetTxtPos := PI^.TxtCtr;
  End;


Procedure QwkMsgObj.SetTxtPos(TP: LongInt);
  Begin
  PI^.TxtCtr := TP;
  PI^.MsgDone := False;
  End;


Function QwkMsgObj.GetFrom: String;
  Begin
  Need(PI^);
  GetFrom := PI^.FromStr;
  End;


Function QwkMsgObj.GetTo: String;
  Begin
  Need(PI^);
  GetTo := PI^.ToStr;
  End;


Function QwkMsgObj.GetSubj: String;
  Begin
  Need(PI^);
  GetSubj := PI^.SubjStr;
  End;


Function QwkMsgObj.GetCost: Word;
  Begin
  GetCost := 0;
  End;


Function QwkMsgObj.GetDate: String;
  {mm-dd-yy}
  Begin
  Need(PI^);
  If PI^.DateStr = '' Then
    GetDate := '00-00-00'
  Else
    GetDate := PI^.DateStr;
  End;


Function QwkMsgObj.GetTime: String;
  {hh:mm}
  Begin
  Need(PI^);
  If PI^.TimeStr = '' Then
    GetTime := '00:00'
  Else
    GetTime := PI^.TimeStr;
  End;


Function QwkMsgObj.GetRefer: LongInt;
  Begin
  Need(PI^);
  GetRefer := PI^.Ref;
  End;


Function QwkMsgObj.GetSeeAlso: LongInt;
  Begin
  GetSeeAlso := 0;
  End;


Function QwkMsgObj.GetNextSeeAlso: LongInt;
  Begin
  GetNextSeeAlso := 0;
  End;


Function QwkMsgObj.GetMsgNum: LongInt;
  Begin
  If PI^.Writing Then
    GetMsgNum := PI^.LastNum
  Else If (PI^.Cur >= 1) And (PI^.Cur <= PI^.NumView) Then
    GetMsgNum := PI^.Cur
  Else
    GetMsgNum := -1;
  End;


Function QwkMsgObj.GetMsgDisplayNum: LongInt;
  Begin
  If PI^.Writing Then
    GetMsgDisplayNum := PI^.LastNum
  Else
    Begin
    Need(PI^);
    If PI^.QNum > 0 Then
      GetMsgDisplayNum := PI^.QNum
    Else
      GetMsgDisplayNum := GetMsgNum;
    End;
  End;


Function QwkMsgObj.GetQwkNum: LongInt;
  Begin
  Need(PI^);
  GetQwkNum := PI^.QNum;
  End;


Function QwkMsgObj.GetLogicalNum: LongInt;
  Begin
  Need(PI^);
  GetLogicalNum := PI^.Logical;
  End;


Function QwkMsgObj.GetStatusChar: Char;
  Begin
  Need(PI^);
  GetStatusChar := PI^.StatusCh;
  End;


Function QwkMsgObj.GetPassword: String;
  Begin
  Need(PI^);
  GetPassword := PI^.PwdStr;
  End;


Function QwkMsgObj.GetHasTag: Boolean;
  Begin
  Need(PI^);
  GetHasTag := PI^.HasTag;
  End;


Function QwkMsgObj.GetEchoFlag: Boolean;
  Begin
  Need(PI^);
  GetEchoFlag := PI^.EchoFlag;
  End;


Function QwkMsgObj.GetMsgId: String;
  Begin
  Need(PI^);
  GetMsgId := PI^.MsgIdStr;
  End;


Function QwkMsgObj.GetReplyId: String;
  Begin
  Need(PI^);
  GetReplyId := PI^.ReplyStr;
  End;


Function QwkMsgObj.GetPacketId: String;
  Begin
  GetPacketId := PI^.PacketId;
  End;


Function QwkMsgObj.GetClean: Boolean;
  Begin
  GetClean := PI^.Clean;
  End;


Function QwkMsgObj.GetCut: Boolean;
  Begin
  GetCut := PI^.Cut;
  End;


Function QwkMsgObj.GetDropped: Word;
  Begin
  GetDropped := PI^.Dropped;
  End;


Function QwkMsgObj.GetError: Word;
  Begin
  GetError := PI^.Error;
  End;


Function QwkMsgObj.NumberInFile: LongInt;
  Var
    i, N: LongInt;

  Begin
  N := 0;
  With PI^ Do
    For i := 0 To NumEnt - 1 Do
      If Ent^[i].Active Then
        Inc(N);
  NumberInFile := N;
  End;


Procedure QwkMsgObj.GetOrig(Var Addr: AddrType);
  Begin
  FillChar(Addr, SizeOf(Addr), 0);
  End;


Procedure QwkMsgObj.GetDest(Var Addr: AddrType);
  Begin
  FillChar(Addr, SizeOf(Addr), 0);
  End;


Function QwkMsgObj.IsLocal: Boolean;
  Begin
  IsLocal := False;
  End;


Function QwkMsgObj.IsCrash: Boolean;
  Begin
  IsCrash := False;
  End;


Function QwkMsgObj.IsKillSent: Boolean;
  Begin
  IsKillSent := False;
  End;


Function QwkMsgObj.IsSent: Boolean;
  Begin
  IsSent := False;
  End;


Function QwkMsgObj.IsFAttach: Boolean;
  Begin
  IsFAttach := False;
  End;


Function QwkMsgObj.IsReqRct: Boolean;
  Begin
  IsReqRct := False;
  End;


Function QwkMsgObj.IsReqAud: Boolean;
  Begin
  IsReqAud := False;
  End;


Function QwkMsgObj.IsRetRct: Boolean;
  Begin
  IsRetRct := False;
  End;


Function QwkMsgObj.IsFileReq: Boolean;
  Begin
  IsFileReq := False;
  End;


Function QwkMsgObj.IsRcvd: Boolean;
  Begin
  Need(PI^);
  IsRcvd := PI^.Rcvd;
  End;


Function QwkMsgObj.IsPriv: Boolean;
  Begin
  Need(PI^);
  IsPriv := PI^.Priv;
  End;


Function QwkMsgObj.IsDeleted: Boolean;
  Begin
  IsDeleted := False;              {killed messages are not shown}
  End;


Function QwkMsgObj.IsEchoed: Boolean;
  Begin
  IsEchoed := False;
  End;


{---------------------------------------------------------------- finding messages}

Procedure QwkMsgObj.SeekFirst(MsgNum: LongInt);
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


Procedure QwkMsgObj.SeekNext;
  Begin
  With PI^ Do
    Begin
    Writing := False;
    Parsed := 0;
    If Cur < 1 Then
      Cur := 0;
    If Cur <= NumView Then
      Inc(Cur);
    TxtCtr := 0;
    MsgDone := False;
    End;
  End;


Procedure QwkMsgObj.SeekPrior;
  Begin
  With PI^ Do
    Begin
    Writing := False;
    Parsed := 0;
    If Cur > NumView + 1 Then
      Cur := NumView + 1;
    If Cur > 1 Then
      Dec(Cur)
    Else
      Cur := 0;
    TxtCtr := 0;
    MsgDone := False;
    End;
  End;


Function QwkMsgObj.SeekFound: Boolean;
  Begin
  SeekFound := (Not PI^.Writing) And (PI^.Cur >= 1) And (PI^.Cur <= PI^.NumView);
  End;


Procedure QwkMsgObj.MsgStartUp;
  Begin
  With PI^ Do
    Begin
    If Writing Then
      Exit;
    Parsed := 0;
    Need(PI^);
    End;
  End;


Procedure QwkMsgObj.MsgTxtStartUp;
  Begin
  Need(PI^);
  PI^.TxtCtr := 0;
  PI^.MsgDone := False;
  End;


Function QwkMsgObj.GetHighMsgNum: LongInt;
  Begin
  GetHighMsgNum := PI^.NumView;
  End;


Function QwkMsgObj.NumberOfMsgs: LongInt;
  Begin
  NumberOfMsgs := PI^.NumView;
  End;


Function QwkMsgObj.GetSubArea: Word;
  Begin
  If PI^.Filter >= 0 Then
    GetSubArea := PI^.Filter
  Else
    GetSubArea := GetMsgConf;
  End;


Function QwkMsgObj.GetMsgLoc: LongInt;
  Begin
  GetMsgLoc := GetMsgNum;
  End;


Procedure QwkMsgObj.SetMsgLoc(ML: LongInt);
  Begin
  SeekFirst(ML);
  End;


Procedure QwkMsgObj.YoursFirst(Name: String; Handle: String);
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


Procedure QwkMsgObj.YoursNext;
  Begin
  With PI^ Do
    Begin
    YFound := False;
    Writing := False;
    If (YName = '') And (YHandle = '') Then
      Begin
      Cur := NumView + 1;
      Exit;
      End;
    Inc(Cur);
    While (Cur <= NumView) And Not YFound Do
      Begin
      Parsed := 0;
      Need(PI^);
      If (Not Rcvd) And
         (((YName <> '') And (Upper(StripBoth(ToStr, ' ')) = YName)) Or
          ((YHandle <> '') And (Upper(StripBoth(ToStr, ' ')) = YHandle))) Then
        YFound := True
      Else
        Inc(Cur);
      End;
    If Not YFound Then
      Cur := NumView + 1;
    End;
  End;


Function QwkMsgObj.YoursFound: Boolean;
  Begin
  YoursFound := PI^.YFound;
  End;


Function QwkMsgObj.GetLastRead(UNum: LongInt): LongInt;
  Begin
  GetLastRead := 0;
  End;


Procedure QwkMsgObj.SetLastRead(UNum: LongInt; LR: LongInt);
  Begin
  End;


{---------------------------------------------------------------- changing the file}

Procedure QwkMsgObj.ReWriteHdr;
  {the status and the reference number of the current message go back into the file}
  Var
    H: QwkHdr;
    E: QwkEntry;
    Got: Word;
    LockedHere: Boolean;

  Begin
  With PI^ Do
    Begin
    Error := 0;
    If (Not Opened) Or Writing Or (Cur < 1) Or (Cur > NumView) Then
      Begin
      Error := 1014;
      Exit;
      End;
    If ReadOnly Then
      Begin
      Error := 1011;
      Exit;
      End;
    If Not Clean Then
      Begin
      Error := 1004;
      Exit;
      End;
    Need(PI^);
    E := Ent^[View^[Cur - 1]];
    LockedHere := False;
    If Not Locked Then
      Begin
      If Not LockMsgBase Then
        Exit;
      LockedHere := True;
      End;
    Seek(F, E.Blk * BlkSize);
    BlockRead(F, H, BlkSize, Got);
    If (IoResult = 0) And (Got = BlkSize) Then
      Begin
      If (Priv <> LPriv) Or (Rcvd <> LRcvd) Then
        Begin
        H[0] := StatusByte(PI^, Priv, Rcvd);
        StatusCh := Chr(H[0]);
        LPriv := Priv;
        LRcvd := Rcvd;
        End;
      If RefChanged Then
        Begin
        If (Ref > 0) And (Ref <= 99999999) Then
          PutAscii(H, 108, 8, Ref)
        Else
          PutAscii(H, 108, 8, -1);
        RefChanged := False;
        End;
      Seek(F, E.Blk * BlkSize);
      BlockWrite(F, H, BlkSize);
      If IoResult <> 0 Then
        Error := 1013;
      End
    Else
      Error := 1000;
    If LockedHere Then
      UnLockMsgBase;
    End;
  End;


Procedure QwkMsgObj.DeleteMsg;
  {marks the message as killed; the cursor is left on the one before it}
  Var
    H: QwkHdr;
    EI: LongInt;
    Got: Word;
    LockedHere: Boolean;
    NewCur: LongInt;

  Begin
  With PI^ Do
    Begin
    Error := 0;
    If (Not Opened) Or Writing Or (Cur < 1) Or (Cur > NumView) Then
      Begin
      Error := 1014;
      Exit;
      End;
    If ReadOnly Then
      Begin
      Error := 1011;
      Exit;
      End;
    If Not Clean Then
      Begin
      Error := 1004;
      Exit;
      End;
    EI := View^[Cur - 1];
    LockedHere := False;
    If Not Locked Then
      Begin
      If Not LockMsgBase Then
        Exit;
      LockedHere := True;
      End;
    Seek(F, Ent^[EI].Blk * BlkSize);
    BlockRead(F, H, BlkSize, Got);
    If (IoResult = 0) And (Got = BlkSize) Then
      Begin
      H[122] := Killed;
      Seek(F, Ent^[EI].Blk * BlkSize);
      BlockWrite(F, H, BlkSize);
      If IoResult <> 0 Then
        Error := 1013
      Else
        Begin
        Ent^[EI].Active := False;
        NewCur := Cur - 1;
        BuildView(PI^);
        Cur := NewCur;
        Parsed := 0;
        End;
      End
    Else
      Error := 1000;
    If LockedHere Then
      UnLockMsgBase;
    End;
  End;


End.
