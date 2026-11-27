{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKMsgSyn;       {Synchronet (SMB) Msg Object}

{$I MKB.Def}

{
     MKMsgSyn - Free Pascal port of the Synchronet message base backend

     Reads and writes the SMB files of a Synchronet message base directly:
       .shd  status header + message headers (256 byte blocks)
       .sdt  message text   (256 byte blocks)
       .sid  index, 20 bytes per message
       .sda  data allocation (2 bytes per .sdt block)   - absent: "hyper alloc"
       .sha  header allocation (1 byte per .shd block)  - absent: "hyper alloc"
     following the SMB specification (https://www.synchro.net/docs/smb.html)
     and the design of MessageSynchronet.js.  All numbers are little endian,
     records are packed.

     SetMsgPath takes the base path WITHOUT extension, e.g. '/sbbs/data/subs/general'.
     Synchronet's mail base ('mail') is read only here.

     Writing follows the SMB storage sequence (lock the status header, allocate
     data, write data, add header, update status, write index).  Like the JS
     version it has NOT been checked against smblib: try it on a COPY of a base
     and open the result with Synchronet (chksmb) before trusting it.  Writes
     are not rolled back; a crash in the middle can leave allocated but unused
     blocks (reclaimed by smbutil pack) but never a half linked message.

     Strings are raw bytes (Synchronet text is CP437); nothing is converted.
     Date and time are the sender's local wall clock ('MM-DD-YY', 'HH:MM') and
     are stored as UTC with the message's zone (SetUtcOffset, default this
     computer's offset).

     Not supported: writing the mail base, editing the text of an existing
     message (ReWriteHdr only rewrites the flags, as in the JS version), FTN
     kludge header fields (not shown in the text), text translation types other
     than LF -> CRLF.
}


Interface


Uses MKGlobT, MKMsgAbs,
  Dos;


Type SmbStatusType = Record            { status header: first 32 bytes of .shd }
  Id: Array[1..4] of Char;             { 'SMB' #26 }
  Version: Word;                       { $0121 }
  Length: Word;                        { size of this header }
  LastMsg: LongInt;                    { highest message number used }
  TotalMsgs: LongInt;
  HeaderOffset: LongInt;               { where message headers start }
  MaxCrcs: LongInt;
  MaxMsgs: LongInt;
  MaxAge: Word;
  Attr: Word;
  End;


Type SmbIdxType = Record               { .sid record }
  ToCrc: Word;                         { CRC-16 of the lowercased to name }
  FromCrc: Word;
  SubjCrc: Word;
  Attr: Word;                          { message attribute bits }
  Offset: LongInt;                     { offset of the header in .shd }
  Number: LongInt;
  Time: LongInt;                       { when imported }
  End;


Type SmbMsgHdrType = Record            { fixed part of a message header: 70 bytes }
  Id: Array[1..4] of Char;             { 'SHD' #26 }
  HType: Word;
  Version: Word;
  Length: Word;                        { size of the whole header record }
  Attr: Word;
  AuxAttr: LongInt;
  NetAttr: LongInt;
  WrittenTime: LongInt;                { unix time }
  WrittenZone: Integer;                { minutes east of UTC }
  ImportedTime: LongInt;
  ImportedZone: Integer;
  Number: LongInt;
  ThreadOrig: LongInt;                 { message this one replies to }
  ThreadNext: LongInt;                 { next reply to the same message }
  ThreadFirst: LongInt;                { first reply to this message }
  Reserved: Array[1..16] of Byte;
  DataOffset: LongInt;                 { where the text starts in .sdt }
  TotalDFields: Word;
  End;


Type SmbDFieldType = Record            { data field: where a piece of text is }
  DType: Word;
  Offset: LongInt;
  Length: LongInt;
  End;


Const                                  { Error codes (MInfo^.Error) }
  synOk           = 0;
  synNoPath       = 100;
  synNotOpen      = 110;
  synReadErr      = 120;
  synWriteErr     = 130;
  synNotSmb       = 1000;              { not an SMB base / damaged header }
  synNoFrom       = 1010;
  synNoText       = 1020;
  synMailBase     = 1030;              { the mail base is read only }
  synNotFound     = 1040;
  synFull         = 1050;              { numbers or files exhausted }
  synLockTimeout  = 1060;
  synInconsistent = 1070;              { .sda/.sha missing or wrong: refuse to write }
  synExists       = 1100;              { CreateMsgBase: base already exists }


Type
  TSynBytes = Array[0..$7FFFFFF] of Byte;
  PSynBytes = ^TSynBytes;
  PSynLong = ^LongInt;
  PSynWord = ^Word;
  TSynIdxArr = Array[0..$3FFFFFF] of SmbIdxType;
  PSynIdxArr = ^TSynIdxArr;


Type SynInfoType = Record
  BasePath: String[255];               { path without extension }
  Error: Word;
  ShdF: File;
  SdtF: File;
  SidF: File;
  SdaF: File;
  ShaF: File;
  BaseOpened: Boolean;
  ReadOnly: Boolean;                   { files could not be opened for writing }
  HasAlloc: Boolean;                   { .sda and .sha exist }
  AllocBad: Boolean;                   { only one of them exists }
  IsMail: Boolean;
  IncludeDeleted: Boolean;             { keep MSG_DELETE messages in seeks/counts }
  IncludeTail: Boolean;                { append the tail text (tear/origin lines) }
  HyperAlloc: Boolean;                 { CreateMsgBase: no .sda/.sha }
  Locked: Boolean;
  LockCount: Integer;
  LockTimeoutMs: Word;
  Status: SmbStatusType;
  Idx: PSynIdxArr;                     { the whole index in memory }
  IdxCount: LongInt;
  IdxAlloc: LongInt;
  StampSize: Int64;
  StampTime: Int64;
  StampOk: Boolean;
  Cur: LongInt;                        { index position of the current message }
  Found: Boolean;
  YCount: Word;
  YNames: Array[1..2] of String[255];
  YCrc: Array[1..2] of Word;
  YPos: LongInt;
  YFound: Boolean;
  Hdr: SmbMsgHdrType;                  { the current message }
  HdrOfs: LongInt;                     { ... where its header is in .shd }
  DFields: Array[1..32] of SmbDFieldType;
  NumDFields: Word;
  MsgFrom: String[255];
  MsgTo: String[255];
  MsgSubj: String[255];
  FromExt: String[255];
  MsgDate: String[8];
  MsgTime: String[5];
  Cost: LongInt;
  Orig: AddrType;
  Dest: AddrType;
  HaveOrig: Boolean;
  HaveDest: Boolean;
  UtcOff: LongInt;                     { zone of the message, minutes east }
  UtcSet: Boolean;
  Reference: LongInt;                  { new message: replies to }
  Attr: Word;                          { new message: bits kept in Hdr }
  AuxAttr: LongInt;
  NetAttr: LongInt;
  TxtBuf: PSynBytes;                   { text being read }
  TxtLen: LongInt;
  TxtPos: LongInt;
  WBuf: PSynBytes;                     { text being written }
  WLen: LongInt;
  WCap: LongInt;
  End;


Type SynMsgObj = Object(AbsMsgObj)
  MInfo: ^SynInfoType;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetMsgPath(MP: String); Virtual; {Set base path (no extension)}
  Function  OpenMsgBase: Word; Virtual; {Open the message base}
  Function  CloseMsgBase: Word; Virtual; {Close the message base}
  Function  CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word; Virtual;
  Function  MsgBaseExists: Boolean; Virtual; {Does msg base exist}
  Function  LockMsgBase: Boolean; Virtual; {Lock the status header}
  Function  UnLockMsgBase: Boolean; Virtual; {Unlock it}
  Procedure SetDest(Var Addr: AddrType); Virtual;
  Procedure SetOrig(Var Addr: AddrType); Virtual;
  Procedure SetFrom(Name: String); Virtual;
  Procedure SetTo(Name: String); Virtual;
  Procedure SetSubj(Str: String); Virtual;
  Procedure SetCost(SCost: Word); Virtual;
  Procedure SetRefer(SRefer: LongInt); Virtual;
  Procedure SetSeeAlso(SAlso: LongInt); Virtual;
  Procedure SetDate(SDate: String); Virtual;
  Procedure SetTime(STime: String); Virtual;
  Procedure SetLocal(LS: Boolean); Virtual;
  Procedure SetRcvd(RS: Boolean); Virtual;
  Procedure SetPriv(PS: Boolean); Virtual;
  Procedure SetCrash(SS: Boolean); Virtual;
  Procedure SetKillSent(SS: Boolean); Virtual;
  Procedure SetSent(SS: Boolean); Virtual;
  Procedure SetFAttach(SS: Boolean); Virtual;
  Procedure SetReqRct(SS: Boolean); Virtual;
  Procedure SetReqAud(SS: Boolean); Virtual;
  Procedure SetRetRct(SS: Boolean); Virtual;
  Procedure SetFileReq(SS: Boolean); Virtual;
  Procedure SetEcho(ES: Boolean); Virtual;
  Procedure DoChar(Ch: Char); Virtual;
  Procedure DoKludgeLn(Str: String); Virtual;  {kludge lines are not stored}
  Function  WriteMsg: Word; Virtual;
  Function  GetChar: Char; Virtual;
  Function  EOM: Boolean; Virtual;
  Function  GetFrom: String; Virtual;
  Function  GetTo: String; Virtual;
  Function  GetSubj: String; Virtual;
  Function  GetCost: Word; Virtual;
  Function  GetDate: String; Virtual;
  Function  GetTime: String; Virtual;
  Function  GetRefer: LongInt; Virtual;
  Function  GetSeeAlso: LongInt; Virtual;
  Function  GetNextSeeAlso: LongInt; Virtual;
  Function  GetMsgNum: LongInt; Virtual;
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
  Function  IsRcvd: Boolean; Virtual;
  Function  IsPriv: Boolean; Virtual;
  Function  IsDeleted: Boolean; Virtual;
  Function  IsEchoed: Boolean; Virtual;
  Function  GetMsgLoc: LongInt; Virtual;       {message number}
  Procedure SetMsgLoc(ML: LongInt); Virtual;
  Procedure MsgStartUp; Virtual;
  Procedure MsgTxtStartUp; Virtual;
  Procedure StartNewMsg; Virtual;
  Procedure SeekFirst(MsgNum: LongInt); Virtual;
  Procedure SeekNext; Virtual;
  Procedure SeekPrior; Virtual;
  Function  SeekFound: Boolean; Virtual;
  Procedure YoursFirst(Name: String; Handle: String); Virtual;
  Procedure YoursNext; Virtual;
  Function  YoursFound: Boolean; Virtual;
  Function  GetHighMsgNum: LongInt; Virtual;
  Function  GetHighActiveMsgNum: LongInt; Virtual;
  Procedure SetMailType(MT: MsgMailType); Virtual;
  Function  GetSubArea: Word; Virtual;
  Procedure ReWriteHdr; Virtual;               {rewrites the flags}
  Procedure DeleteMsg; Virtual;                {sets MSG_DELETE}
  Function  NumberOfMsgs: LongInt; Virtual;
  Function  GetMsgDisplayNum: LongInt; Virtual;
  Function  GetTxtPos: LongInt; Virtual;
  Procedure SetTxtPos(TP: LongInt); Virtual;
  {Synchronet extras}
  Procedure SetMailBase(IsMail: Boolean);      {read only mail base}
  Procedure SetIncludeDeleted(On: Boolean);
  Procedure SetIncludeTail(On: Boolean);
  Procedure SetHyperAlloc(On: Boolean);        {CreateMsgBase without .sda/.sha}
  Procedure SetUtcOffset(Minutes: LongInt);
  Function  GetUtcOffset: LongInt;
  Function  GetFromExt: String;                {user number in the mail base}
  Procedure Refresh;
  Function  ReadAt(Var F: File; Pos, Len: LongInt; Var Buf): LongInt;
  Function  Fresh: Word;
  Function  LoadAt(Pos: LongInt): Boolean;
  Function  Visible(I: LongInt): Boolean;
  Function  ScanFrom(Start, Dir: LongInt): LongInt;
  Function  MoveTo(Pos: LongInt): Boolean;
  Function  FindPos(Number: LongInt): LongInt;
  Function  GetLock(Start, Len: LongInt): Word;
  Procedure ReleaseLock(Start, Len: LongInt);
  Function  UpdateFlags(Number: LongInt; AttrSet, AttrClear, AuxSet, AuxClear,
    NetSet, NetClear: LongInt): Word;
  Procedure ClearMsg;
  End;


Type SynMsgPtr = ^SynMsgObj;


Function SynNameCrc(S: String): Word;  {index CRC of a name (to / from)}
Function SynSubjCrc(S: String): Word;  {index CRC of a subject}


Implementation


Uses MKFile, MKString, MKMisc, MKDos, MKPlat;

Const
  IdxLen       = 20;                   { .sid record }
  BlockLen     = 256;                  { .shd / .sdt block }
  FixedLen     = 70;                   { fixed part of a message header }
  DFieldLen    = 10;
  MaxOffset    = $7FFFFF00;            { stay under the 2 GB ceiling }

  hfSender        = $00;               { header field types }
  hfSenderNetType = $02;
  hfSenderNetAddr = $03;
  hfSenderExt     = $04;
  hfRecipient     = $30;
  hfRecipNetType  = $32;
  hfRecipNetAddr  = $33;
  hfRecipExt      = $34;
  hfSubject       = $60;
  hfCost          = $66;

  dfTextBody   = $00;                  { data field types }
  dfTextTail   = $02;

  msgPrivate   = $0001;                { attr }
  msgRead      = $0002;
  msgDelete    = $0010;
  allAttr      = msgPrivate Or msgRead Or msgDelete;

  auxFileReq   = $0001;                { auxattr }
  auxFileAtt   = $0002;
  auxReceipt   = $0010;
  auxConfirm   = $0020;
  allAux       = auxFileReq Or auxFileAtt Or auxReceipt Or auxConfirm;

  netLocal     = $0001;                { netattr }
  netSent      = $0004;
  netKillSent  = $0008;
  netCrash     = $0040;
  netTypeEcho  = $2000;
  allNet       = netLocal Or netSent Or netKillSent Or netCrash Or netTypeEcho;

  netTypeFido  = 2;
  xlatNone     = 0;
  xlatLf2Crlf  = 1;


{---------------------------------------------------------------- helpers}

Function SynMin(A, B: LongInt): LongInt;
  Begin
  If A < B Then SynMin := A Else SynMin := B;
  End;


Function SynMax(A, B: LongInt): LongInt;
  Begin
  If A > B Then SynMax := A Else SynMax := B;
  End;


Function SynGetL(P: PSynBytes; O: LongInt): LongInt;
  Begin
  SynGetL := PSynLong(@P^[O])^;
  End;


Procedure SynPutL(P: PSynBytes; O: LongInt; V: LongInt);
  Begin
  PSynLong(@P^[O])^ := V;
  End;


Function SynGetW(P: PSynBytes; O: LongInt): Word;
  Begin
  SynGetW := PSynWord(@P^[O])^;
  End;


Procedure SynPutW(P: PSynBytes; O: LongInt; V: Word);
  Begin
  PSynWord(@P^[O])^ := V;
  End;


Function SynGrow(Var P: PSynBytes; Var Alloc: LongInt; Need: LongInt): Boolean;
  Var
    NewAlloc: LongInt;

  Begin
  SynGrow := True;
  If Need <= Alloc Then
    Exit;
  NewAlloc := SynMax(Need, Alloc * 2);
  NewAlloc := SynMax(NewAlloc, 256);
  ReAllocMem(P, NewAlloc);
  If P = Nil Then
    Begin
    Alloc := 0;
    SynGrow := False;
    End
  Else
    Alloc := NewAlloc;
  End;


Function SynRd(Var F: File; Pos, Len: LongInt; Var Buf): LongInt;
  {bytes read (short at the end of the file), -1 on error}
  Var
    N: LongInt;

  Begin
  If IoResult <> 0 Then;
  If Len <= 0 Then
    Begin
    SynRd := 0;
    Exit;
    End;
  Seek(F, Pos);
  If IoResult <> 0 Then
    Begin
    SynRd := -1;
    Exit;
    End;
  N := 0;
  BlockRead(F, Buf, Len, N);
  If IoResult <> 0 Then
    SynRd := -1
  Else
    SynRd := N;
  End;


Function SynWr(Var F: File; Pos, Len: LongInt; Var Buf): Boolean;
  Var
    N: LongInt;

  Begin
  SynWr := False;
  If IoResult <> 0 Then;
  If Len <= 0 Then
    Begin
    SynWr := True;
    Exit;
    End;
  Seek(F, Pos);
  If IoResult <> 0 Then
    Exit;
  N := 0;
  BlockWrite(F, Buf, Len, N);
  If (IoResult = 0) And (N = Len) Then
    SynWr := True;
  End;


Function SynUtcNow: LongInt;
  Var
    DT: DateTime;
    Dow: Word;
    S100: Word;

  Begin
  Dos.GetDate(DT.Year, DT.Month, DT.Day, Dow);
  Dos.GetTime(DT.Hour, DT.Min, DT.Sec, S100);
  SynUtcNow := DTToUnixDate(DT) - MKLocalUtcOffset * 60;
  End;


Function Crc16Bytes(P: PSynBytes; Len: LongInt): Word;
  {CRC-16 "xmodem": polynomial $1021, seed 0 (what Synchronet's index uses)}
  Var
    Crc: Word;
    i: LongInt;
    b: Byte;
    j: Word;
    Bits: Longint;

  Begin
  Crc := 0;
  For i := 0 To Len - 1 Do
    Begin
    b := P^[i];
    Bits := Longint(Crc) Xor (Longint(b) Shl 8);
    For j := 1 To 8 Do
      If (Bits And $8000) <> 0 Then
        Bits := ((Bits Shl 1) Xor $1021) And $FFFF
      Else
        Bits := (Bits Shl 1) And $FFFF;
    Crc := Bits;
    End;
  Crc16Bytes := Crc;
  End;


Function StrCrc(S: String): Word;
  {CRC of the lower cased (A-Z only) bytes of S}
  Var
    B: Array[0..255] Of Byte;
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    Begin
    B[i - 1] := Ord(S[i]);
    If (B[i - 1] >= $41) And (B[i - 1] <= $5A) Then
      Inc(B[i - 1], $20);
    End;
  StrCrc := Crc16Bytes(@B, Length(S));
  End;


Function SubjCrcOf(S: String): Word;
  {the subject CRC strips leading "re:" prefixes (and blanks after them) and
   does not trim}
  Var
    Again: Boolean;

  Begin
  Repeat
    Again := False;
    If (Length(S) >= 3) And (LoCase(S[1]) = 'r') And (LoCase(S[2]) = 'e') And (S[3] = ':') Then
      Begin
      Delete(S, 1, 3);
      While (Length(S) > 0) And (S[1] <= ' ') Do
        Delete(S, 1, 1);
      Again := True;
      End;
  Until Not Again;
  SubjCrcOf := StrCrc(S);
  End;


Function SynNameCrc(S: String): Word;
  Begin
  SynNameCrc := StrCrc(S);
  End;


Function SynSubjCrc(S: String): Word;
  Begin
  SynSubjCrc := SubjCrcOf(S);
  End;


Function SynLower(S: String): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    S[i] := LoCase(S[i]);
  SynLower := S;
  End;


Function BaseName(P: String): String;
  {the file name part of a path, without an extension}
  Var
    D: DirStr;
    N: NameStr;
    E: ExtStr;

  Begin
  FSplit(P, D, N, E);
  BaseName := N;
  End;


Function SynTrim(S: String): String;
  Begin
  While (Length(S) > 0) And (S[Length(S)] <= ' ') Do
    Dec(S[0]);
  While (Length(S) > 0) And (S[1] <= ' ') Do
    Delete(S, 1, 1);
  SynTrim := S;
  End;


Function PutHField(Var Buf: PSynBytes; Var Len, Alloc: LongInt; Typ: Word;
  Var Data; DLen: LongInt): Boolean;
  {header field: type(2) length(2) data}
  Begin
  PutHField := False;
  If Not SynGrow(Buf, Alloc, Len + 4 + DLen) Then
    Exit;
  SynPutW(Buf, Len, Typ);
  SynPutW(Buf, Len + 2, DLen);
  If DLen > 0 Then
    Move(Data, Buf^[Len + 4], DLen);
  Inc(Len, 4 + DLen);
  PutHField := True;
  End;


Function PutHStr(Var Buf: PSynBytes; Var Len, Alloc: LongInt; Typ: Word; S: String): Boolean;
  Var
    Z: Byte;

  Begin
  Z := 0;
  If Length(S) > 0 Then
    PutHStr := PutHField(Buf, Len, Alloc, Typ, S[1], Length(S))
  Else
    PutHStr := PutHField(Buf, Len, Alloc, Typ, Z, 0);
  End;


Function SynAddr(Var A: AddrType; Var Buf: PSynBytes; Var Len, Alloc: LongInt;
  TypeField, AddrField: Word): Boolean;
  {a FidoNet address as the two header fields: net type, then zone/net/node/point}
  Var
    T: Word;
    B: Array[0..7] Of Byte;

  Begin
  T := netTypeFido;
  PSynWord(@B[0])^ := A.Zone;
  PSynWord(@B[2])^ := A.Net;
  PSynWord(@B[4])^ := A.Node;
  PSynWord(@B[6])^ := A.Point;
  SynAddr := PutHField(Buf, Len, Alloc, TypeField, T, 2) And
    PutHField(Buf, Len, Alloc, AddrField, B, 8);
  End;


Function AddrUsed(Var A: AddrType): Boolean;
  Begin
  AddrUsed := (A.Zone Or A.Net Or A.Node Or A.Point) <> 0;
  End;


{----------------------------------------------------- the object itself}

Constructor SynMsgObj.Init;
  Begin
  New(MInfo);
  If MInfo = Nil Then
    Begin
    Fail;
    Exit;
    End;
  FillChar(MInfo^, SizeOf(MInfo^), #0);
  MInfo^.LockTimeoutMs := 5000;
  MInfo^.Cur := -1;
  LastSoft := False;
  End;


Destructor SynMsgObj.Done;
  Begin
  If MInfo^.BaseOpened Then
    If CloseMsgBase = 0 Then;
  If MInfo^.Idx <> Nil Then
    FreeMem(MInfo^.Idx, MInfo^.IdxAlloc * IdxLen);
  If MInfo^.TxtBuf <> Nil Then
    FreeMem(MInfo^.TxtBuf, MInfo^.TxtLen + 1);
  If MInfo^.WBuf <> Nil Then
    FreeMem(MInfo^.WBuf, MInfo^.WCap);
  Dispose(MInfo);
  End;


Procedure SynMsgObj.SetMsgPath(MP: String);
  {the base path without extension; an extension is cut off}
  Var
    Ext: String;

  Begin
  If MInfo^.BaseOpened Then
    If CloseMsgBase = 0 Then;
  Ext := SynLower(Copy(MP, Length(MP) - 3, 4));
  If (Ext = '.shd') Or (Ext = '.sdt') Or (Ext = '.sid') Or (Ext = '.sda') Or
     (Ext = '.sha') Or (Ext = '.sch') Then
    MP := Copy(MP, 1, Length(MP) - 4);
  MInfo^.BasePath := MP;
  End;


Function SynMsgObj.MsgBaseExists: Boolean;
  Begin
  MsgBaseExists := (Length(MInfo^.BasePath) > 0) And FileExist(MInfo^.BasePath + '.shd') And
    FileExist(MInfo^.BasePath + '.sid');
  End;


Procedure SynMsgObj.SetMailBase(IsMail: Boolean);
  Begin
  MInfo^.IsMail := IsMail;
  End;


Procedure SynMsgObj.SetIncludeDeleted(On: Boolean);
  Begin
  MInfo^.IncludeDeleted := On;
  End;


Procedure SynMsgObj.SetIncludeTail(On: Boolean);
  Begin
  MInfo^.IncludeTail := On;
  End;


Procedure SynMsgObj.SetHyperAlloc(On: Boolean);
  Begin
  MInfo^.HyperAlloc := On;
  End;


Procedure SynMsgObj.SetUtcOffset(Minutes: LongInt);
  Begin
  MInfo^.UtcOff := Minutes;
  MInfo^.UtcSet := True;
  End;


Function SynMsgObj.GetUtcOffset: LongInt;
  Begin
  If MInfo^.UtcSet Then
    GetUtcOffset := MInfo^.UtcOff
  Else
    GetUtcOffset := MKLocalUtcOffset;
  End;


Function SynMsgObj.GetFromExt: String;
  Begin
  GetFromExt := MInfo^.FromExt;
  End;


Procedure SynMsgObj.SetMailType(MT: MsgMailType);
  Begin
  End;


Function SynMsgObj.GetSubArea: Word;
  Begin
  GetSubArea := 0;
  End;


{------------------------------------------------------------- locking}

Function SynMsgObj.GetLock(Start, Len: LongInt): Word;
  {a byte range lock on the .shd file; waits up to LockTimeoutMs}
  Var
    Waited: LongInt;
    Code: Word;

  Begin
  Waited := 0;
  GetLock := 0;
  Repeat
    Code := MKLockRegion(FileRec(MInfo^.ShdF).Handle, Start, Len, True);
    If Code = mkLockOk Then
      Exit;
    If Code <> mkLockViolation Then
      Begin
      GetLock := synWriteErr;
      Exit;
      End;
    If Waited >= MInfo^.LockTimeoutMs Then
      Begin
      GetLock := synLockTimeout;
      Exit;
      End;
    MKDelay(25);
    Inc(Waited, 25);
  Until False;
  End;


Procedure SynMsgObj.ReleaseLock(Start, Len: LongInt);
  Begin
  MKLockRegion(FileRec(MInfo^.ShdF).Handle, Start, Len, False);
  End;


Function SynMsgObj.LockMsgBase: Boolean;
  {Hold the status header lock across several operations; nesting is counted.
   Writers take it by themselves when you have not.}
  Begin
  LockMsgBase := False;
  MInfo^.Error := 0;
  If Not MInfo^.BaseOpened Then
    MInfo^.Error := synNotOpen
  Else If MInfo^.ReadOnly Then
    MInfo^.Error := synWriteErr
  Else If MInfo^.LockCount = 0 Then
    MInfo^.Error := GetLock(0, MInfo^.Status.Length);
  If MInfo^.Error = 0 Then
    Begin
    Inc(MInfo^.LockCount);
    MInfo^.Locked := True;
    LockMsgBase := True;
    End;
  End;


Function SynMsgObj.UnLockMsgBase: Boolean;
  Begin
  UnLockMsgBase := False;
  MInfo^.Error := 0;
  If MInfo^.LockCount <= 0 Then
    MInfo^.Error := 5
  Else
    Begin
    Dec(MInfo^.LockCount);
    If MInfo^.LockCount = 0 Then
      Begin
      ReleaseLock(0, MInfo^.Status.Length);
      MInfo^.Locked := False;
      End;
    UnLockMsgBase := True;
    End;
  End;


{-------------------------------------------------- create / open / close}

Function SynMsgObj.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word;
  {An empty base: .shd with a 32 byte status header, empty .sdt and .sid and,
   unless SetHyperAlloc(True), empty .sda and .sha.  MaxMsg and MaxDays go into
   the max_msgs / max_age fields.  The layout follows the SMB spec; like the
   writer it has not been checked against smblib.}
  Var
    St: SmbStatusType;
    F: File;
    Err: Word;
    D: DirStr;
    Nm: NameStr;
    Ex: ExtStr;
    Exts: Array[1..5] Of String[3];
    Made: Word;
    NExt: Word;
    i: Word;
    N: LongInt;

  Begin
  Err := 0;
  FSplit(MInfo^.BasePath, D, Nm, Ex);
  If Length(MInfo^.BasePath) = 0 Then
    Err := synNoPath
  Else If MInfo^.IsMail Or (SynLower(Nm) = 'mail') Then
    Err := synMailBase
  Else If MsgBaseExists Then
    Err := synExists;
  If Err = 0 Then
    Begin
    FSplit(MInfo^.BasePath, D, Nm, Ex);
    If Length(D) > 0 Then
      If Not MakePath(D) Then
        Err := synWriteErr;
    End;
  If Err = 0 Then
    Begin
    FillChar(St, SizeOf(St), 0);
    St.Id[1] := 'S'; St.Id[2] := 'M'; St.Id[3] := 'B'; St.Id[4] := #26;
    St.Version := $0121;
    St.Length := 32;
    St.HeaderOffset := 32;
    St.MaxMsgs := MaxMsg;
    St.MaxAge := MaxDays;
    Exts[1] := 'shd'; Exts[2] := 'sdt'; Exts[3] := 'sid'; Exts[4] := 'sda'; Exts[5] := 'sha';
    If MInfo^.HyperAlloc Then
      NExt := 3
    Else
      NExt := 5;
    Made := 0;
    For i := 1 To NExt Do
      If Err = 0 Then
        Begin
        Assign(F, MInfo^.BasePath + '.' + Exts[i]);
        FileMode := fmReadWrite + fmDenyNone;
        ReWrite(F, 1);
        If IoResult <> 0 Then
          Err := synWriteErr
        Else
          Begin
          Inc(Made);
          If i = 1 Then
            Begin
            BlockWrite(F, St, 32, N);
            If (IoResult <> 0) Or (N <> 32) Then
              Err := synWriteErr;
            End;
          Close(F);
          If IoResult <> 0 Then
            Err := synWriteErr;
          End;
        End;
    If Err <> 0 Then
      For i := 1 To Made Do
        Begin                            {take back what was made}
        Assign(F, MInfo^.BasePath + '.' + Exts[i]);
        Erase(F);
        If IoResult <> 0 Then;
        End;
    End;
  MInfo^.Error := Err;
  CreateMsgBase := Err;
  End;


Function SynMsgObj.OpenMsgBase: Word;
  Var
    Err: Word;
    HaveSda: Boolean;
    HaveSha: Boolean;

  Function OpenOne(Var F: File; Ext: String): Boolean;
    {read/write if possible, else read only}
    Var
      Name: String;

    Begin
    Name := MInfo^.BasePath + '.' + Ext;
    Assign(F, Name);
    FileMode := fmReadWrite + fmDenyNone;
    Reset(F, 1);
    If IoResult <> 0 Then
      Begin
      FileMode := fmReadOnly + fmDenyNone;
      Reset(F, 1);
      If IoResult <> 0 Then
        Begin
        OpenOne := False;
        Exit;
        End;
      MInfo^.ReadOnly := True;
      End;
    OpenOne := True;
    End;

  Begin
  MInfo^.Error := 0;
  If Length(MInfo^.BasePath) = 0 Then
    MInfo^.Error := synNoPath
  Else If Not MsgBaseExists Then
    MInfo^.Error := synNotFound;
  If (MInfo^.Error = 0) And MInfo^.BaseOpened Then
    If CloseMsgBase <> 0 Then;
  If MInfo^.Error = 0 Then
    Begin
    MInfo^.ReadOnly := False;
    If Not OpenOne(MInfo^.ShdF, 'shd') Then
      MInfo^.Error := synReadErr
    Else If Not OpenOne(MInfo^.SidF, 'sid') Then
      Begin
      Close(MInfo^.ShdF);
      MInfo^.Error := synReadErr;
      End
    Else If Not OpenOne(MInfo^.SdtF, 'sdt') Then
      Begin
      Close(MInfo^.ShdF);
      Close(MInfo^.SidF);
      MInfo^.Error := synReadErr;
      End;
    End;
  If MInfo^.Error = 0 Then
    Begin
    HaveSda := FileExist(MInfo^.BasePath + '.sda');
    HaveSha := FileExist(MInfo^.BasePath + '.sha');
    MInfo^.AllocBad := (HaveSda <> HaveSha);
    MInfo^.HasAlloc := HaveSda And HaveSha;
    If MInfo^.HasAlloc Then
      If (Not OpenOne(MInfo^.SdaF, 'sda')) Then
        MInfo^.AllocBad := True
      Else If Not OpenOne(MInfo^.ShaF, 'sha') Then
        Begin
        Close(MInfo^.SdaF);
        MInfo^.AllocBad := True;
        MInfo^.HasAlloc := False;
        End;
    If IoResult <> 0 Then;
    MInfo^.BaseOpened := True;
    MInfo^.StampOk := False;
    MInfo^.Found := False;
    MInfo^.Cur := -1;
    MInfo^.LockCount := 0;
    MInfo^.Locked := False;
    Err := Fresh;
    If Err <> 0 Then
      Begin
      If CloseMsgBase <> 0 Then;
      MInfo^.Error := Err;
      End;
    End;
  OpenMsgBase := MInfo^.Error;
  End;


Function SynMsgObj.CloseMsgBase: Word;
  Begin
  MInfo^.Error := 0;
  If MInfo^.BaseOpened Then
    Begin
    If MInfo^.Locked Then
      ReleaseLock(0, MInfo^.Status.Length);
    MInfo^.Locked := False;
    MInfo^.LockCount := 0;
    Close(MInfo^.ShdF);
    Close(MInfo^.SdtF);
    Close(MInfo^.SidF);
    If MInfo^.HasAlloc Then
      Begin
      Close(MInfo^.SdaF);
      Close(MInfo^.ShaF);
      End;
    If IoResult <> 0 Then
      MInfo^.Error := synWriteErr;
    MInfo^.BaseOpened := False;
    End;
  MInfo^.StampOk := False;
  MInfo^.Found := False;
  MInfo^.IdxCount := 0;
  MInfo^.Cur := -1;
  If MInfo^.TxtBuf <> Nil Then
    Begin
    FreeMem(MInfo^.TxtBuf, MInfo^.TxtLen + 1);
    MInfo^.TxtBuf := Nil;
    MInfo^.TxtLen := 0;
    End;
  CloseMsgBase := MInfo^.Error;
  End;


{------------------------------------------------------ reading the files}

Function SynMsgObj.ReadAt(Var F: File; Pos, Len: LongInt; Var Buf): LongInt;
  Begin
  ReadAt := SynRd(F, Pos, Len, Buf);
  End;


Procedure SynMsgObj.ClearMsg;
  Begin
  FillChar(MInfo^.Hdr, SizeOf(MInfo^.Hdr), 0);
  MInfo^.NumDFields := 0;
  MInfo^.MsgFrom := '';
  MInfo^.MsgTo := '';
  MInfo^.MsgSubj := '';
  MInfo^.FromExt := '';
  MInfo^.MsgDate := '';
  MInfo^.MsgTime := '';
  MInfo^.Cost := 0;
  FillChar(MInfo^.Orig, SizeOf(MInfo^.Orig), 0);
  FillChar(MInfo^.Dest, SizeOf(MInfo^.Dest), 0);
  MInfo^.HaveOrig := False;
  MInfo^.HaveDest := False;
  MInfo^.UtcOff := 0;
  MInfo^.UtcSet := False;
  End;


Function SynMsgObj.Fresh: Word;
  {Reload the status header and the index if the .sid changed on disk}
  Var
    Size: Int64;
    MTime: Int64;
    Buf: Array[0..31] Of Byte;
    N: LongInt;
    Count: LongInt;
    CurNum: LongInt;
    Num: LongInt;

  Begin
  Fresh := 0;
  If Not MKFileStamp(FileRec(MInfo^.SidF).Handle, Size, MTime) Then
    Begin
    Fresh := synReadErr;
    Exit;
    End;
  If MInfo^.StampOk And (Size = MInfo^.StampSize) And (MTime = MInfo^.StampTime) Then
    Exit;
  CurNum := 0;
  If MInfo^.Found And (MInfo^.Cur >= 0) And (MInfo^.Cur < MInfo^.IdxCount) Then
    CurNum := MInfo^.Idx^[MInfo^.Cur].Number;
  N := ReadAt(MInfo^.ShdF, 0, 32, Buf);
  If N < 28 Then
    Begin
    Fresh := synNotSmb;
    Exit;
    End;
  If (Buf[0] <> Ord('S')) Or (Buf[1] <> Ord('M')) Or (Buf[2] <> Ord('B')) Or (Buf[3] <> 26) Then
    Begin
    Fresh := synNotSmb;
    Exit;
    End;
  FillChar(MInfo^.Status, SizeOf(MInfo^.Status), 0);
  Move(Buf, MInfo^.Status, SynMin(N, 32));
  Count := Size Div IdxLen;
  If Count > MInfo^.IdxAlloc Then
    Begin
    If MInfo^.Idx <> Nil Then
      FreeMem(MInfo^.Idx, MInfo^.IdxAlloc * IdxLen);
    MInfo^.IdxAlloc := Count + 64;
    GetMem(MInfo^.Idx, MInfo^.IdxAlloc * IdxLen);
    If MInfo^.Idx = Nil Then
      Begin
      MInfo^.IdxAlloc := 0;
      Fresh := synReadErr;
      Exit;
      End;
    End;
  If Count > 0 Then
    If ReadAt(MInfo^.SidF, 0, Count * IdxLen, MInfo^.Idx^) <> Count * IdxLen Then
      Begin
      Fresh := synReadErr;
      Exit;
      End;
  MInfo^.IdxCount := Count;
  MInfo^.StampSize := Size;
  MInfo^.StampTime := MTime;
  MInfo^.StampOk := True;
  { keep the cursor on the same message if the index shifted }
  If CurNum <> 0 Then
    Begin
    Num := FindPos(CurNum);
    If Num >= 0 Then
      MInfo^.Cur := Num
    Else
      MInfo^.Found := False;
    End
  Else If MInfo^.Cur >= Count Then
    MInfo^.Cur := Count;
  End;


Procedure SynMsgObj.Refresh;
  Begin
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.StampOk := False;
    MInfo^.Error := Fresh;
    End;
  End;


Function SynMsgObj.FindPos(Number: LongInt): LongInt;
  {binary search of the (ascending) index; -1 if not there}
  Var
    Lo: LongInt;
    Hi: LongInt;
    Mid: LongInt;

  Begin
  FindPos := -1;
  Lo := 0;
  Hi := MInfo^.IdxCount - 1;
  While Lo <= Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If MInfo^.Idx^[Mid].Number = Number Then
      Begin
      FindPos := Mid;
      Exit;
      End;
    If MInfo^.Idx^[Mid].Number < Number Then
      Lo := Mid + 1
    Else
      Hi := Mid - 1;
    End;
  End;


Function SynMsgObj.Visible(I: LongInt): Boolean;
  Begin
  Visible := MInfo^.IncludeDeleted Or ((MInfo^.Idx^[I].Attr And msgDelete) = 0);
  End;


Function SynMsgObj.ScanFrom(Start, Dir: LongInt): LongInt;
  {first visible index position from Start going in direction Dir, or -1}
  Var
    i: LongInt;

  Begin
  ScanFrom := -1;
  i := Start;
  While (i >= 0) And (i < MInfo^.IdxCount) Do
    Begin
    If Visible(i) Then
      Begin
      ScanFrom := i;
      Exit;
      End;
    Inc(i, Dir);
    End;
  End;


Function SynMsgObj.LoadAt(Pos: LongInt): Boolean;
  {Read the message header at Pos in .shd into the object.  False if it is not
   a message header.}
  Var
    Buf: PSynBytes;
    Blk: Array[0..BlockLen - 1] Of Byte;
    N: LongInt;
    Len: LongInt;
    P: LongInt;
    i: Word;
    Typ: Word;
    DLen: LongInt;
    Own: Boolean;
    DT: DateTime;
    Off: LongInt;
    S: String;

  Function HStr(Q: LongInt; L: LongInt): String;
    {a header field as a string, trailing NULs cut}
    Var
      R: String;
      C: LongInt;

    Begin
    While (L > 0) And (Buf^[Q + L - 1] = 0) Do
      Dec(L);
    C := SynMin(L, 255);
    R[0] := Chr(C);
    If C > 0 Then
      Move(Buf^[Q], R[1], C);
    HStr := R;
    End;

  Begin
  LoadAt := False;
  Buf := Nil;
  Own := False;
  N := ReadAt(MInfo^.ShdF, Pos, BlockLen, Blk);
  If (N < 10) Or (Blk[0] <> Ord('S')) Or (Blk[1] <> Ord('H')) Or (Blk[2] <> Ord('D')) Or
     (Blk[3] <> 26) Then
    Exit;
  Len := SynGetW(@Blk, 8);
  If Len < FixedLen Then
    Exit;
  If Len > N Then
    Begin
    GetMem(Buf, Len);
    If Buf = Nil Then
      Exit;
    Own := True;
    If ReadAt(MInfo^.ShdF, Pos, Len, Buf^) < Len Then
      Begin
      FreeMem(Buf, Len);
      Exit;
      End;
    End
  Else
    Buf := @Blk;
  ClearMsg;
  Move(Buf^, MInfo^.Hdr, FixedLen);
  MInfo^.HdrOfs := Pos;
  P := FixedLen;
  MInfo^.NumDFields := 0;
  For i := 1 To MInfo^.Hdr.TotalDFields Do
    Begin
    If P + DFieldLen > Len Then
      Break;
    If i <= 32 Then
      Begin
      MInfo^.DFields[i].DType := SynGetW(Buf, P);
      MInfo^.DFields[i].Offset := SynGetL(Buf, P + 2);
      MInfo^.DFields[i].Length := SynGetL(Buf, P + 6);
      MInfo^.NumDFields := i;
      End;
    Inc(P, DFieldLen);
    End;
  While P + 4 <= Len Do
    Begin
    Typ := SynGetW(Buf, P);
    DLen := SynGetW(Buf, P + 2);
    If P + 4 + DLen > Len Then
      Break;
    Case Typ Of
      hfSender: MInfo^.MsgFrom := HStr(P + 4, DLen);
      hfRecipient: MInfo^.MsgTo := HStr(P + 4, DLen);
      hfSubject: MInfo^.MsgSubj := HStr(P + 4, DLen);
      hfSenderExt: MInfo^.FromExt := HStr(P + 4, DLen);
      hfCost: If DLen >= 4 Then MInfo^.Cost := SynGetL(Buf, P + 4);
      hfSenderNetAddr: If (DLen >= 8) And (MInfo^.Orig.Net = 0) Then
                         Begin
                         MInfo^.Orig.Zone := SynGetW(Buf, P + 4);
                         MInfo^.Orig.Net := SynGetW(Buf, P + 6);
                         MInfo^.Orig.Node := SynGetW(Buf, P + 8);
                         MInfo^.Orig.Point := SynGetW(Buf, P + 10);
                         MInfo^.HaveOrig := True;
                         End;
      hfRecipNetAddr: If (DLen >= 8) And (MInfo^.Dest.Net = 0) Then
                        Begin
                        MInfo^.Dest.Zone := SynGetW(Buf, P + 4);
                        MInfo^.Dest.Net := SynGetW(Buf, P + 6);
                        MInfo^.Dest.Node := SynGetW(Buf, P + 8);
                        MInfo^.Dest.Point := SynGetW(Buf, P + 10);
                        MInfo^.HaveDest := True;
                        End;
      End;
    Inc(P, 4 + DLen);
    End;
  If Own Then
    FreeMem(Buf, Len);
  { the date the sender wrote it, on the sender's clock }
  If (Abs(MInfo^.Hdr.WrittenZone) <= 840) Then
    Begin
    MInfo^.UtcOff := MInfo^.Hdr.WrittenZone;
    MInfo^.UtcSet := True;
    Off := MInfo^.UtcOff;
    End
  Else
    Off := MKLocalUtcOffset;
  If MInfo^.Hdr.WrittenTime <> 0 Then
    Begin
    UnixToDt(MInfo^.Hdr.WrittenTime + Off * 60, DT);
    MInfo^.MsgDate := FormattedDate(DT, 'MM-DD-YY');
    MInfo^.MsgTime := FormattedDate(DT, 'HH:II');
    End;
  LoadAt := True;
  End;


Function SynMsgObj.MoveTo(Pos: LongInt): Boolean;
  Begin
  MoveTo := False;
  If (Pos < 0) Or (Pos >= MInfo^.IdxCount) Then
    Begin
    MInfo^.Found := False;
    Exit;
    End;
  If LoadAt(MInfo^.Idx^[Pos].Offset) Then
    Begin
    MInfo^.Cur := Pos;
    MInfo^.Found := True;
    MoveTo := True;
    End
  Else
    Begin
    MInfo^.StampOk := False;           {the index points at garbage: stale}
    MInfo^.Found := False;
    End;
  End;


{----------------------------------------------------------- navigation}

Procedure SynMsgObj.SeekFirst(MsgNum: LongInt);
  {First visible message, or the first one numbered MsgNum or higher}
  Var
    Lo: LongInt;
    Hi: LongInt;
    Mid: LongInt;
    Pos: LongInt;

  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := synNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  Lo := 0;
  Hi := MInfo^.IdxCount;
  While Lo < Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If MInfo^.Idx^[Mid].Number < MsgNum Then
      Lo := Mid + 1
    Else
      Hi := Mid;
    End;
  Pos := ScanFrom(Lo, 1);
  While (Pos >= 0) And (Not MoveTo(Pos)) Do
    Pos := ScanFrom(Pos + 1, 1);
  If Pos < 0 Then
    Begin
    MInfo^.Cur := MInfo^.IdxCount;
    MInfo^.Found := False;
    End;
  End;


Procedure SynMsgObj.SeekNext;
  Var
    Pos: LongInt;

  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := synNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  Pos := ScanFrom(MInfo^.Cur + 1, 1);
  While (Pos >= 0) And (Not MoveTo(Pos)) Do
    Pos := ScanFrom(Pos + 1, 1);
  If Pos < 0 Then
    Begin
    MInfo^.Cur := MInfo^.IdxCount;
    MInfo^.Found := False;
    End;
  End;


Procedure SynMsgObj.SeekPrior;
  Var
    Pos: LongInt;

  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := synNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  Pos := ScanFrom(MInfo^.Cur - 1, -1);
  While (Pos >= 0) And (Not MoveTo(Pos)) Do
    Pos := ScanFrom(Pos - 1, -1);
  If Pos < 0 Then
    Begin
    MInfo^.Cur := -1;
    MInfo^.Found := False;
    End;
  End;


Function SynMsgObj.SeekFound: Boolean;
  Begin
  SeekFound := MInfo^.Found;
  End;


Procedure SynMsgObj.SetMsgLoc(ML: LongInt);
  {go to message number ML (deleted messages too)}
  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := synNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  If Not MoveTo(FindPos(ML)) Then
    MInfo^.Found := False;
  End;


Function SynMsgObj.GetMsgLoc: LongInt;
  Begin
  If MInfo^.Found Then
    GetMsgLoc := MInfo^.Hdr.Number
  Else
    GetMsgLoc := 0;
  End;


Procedure SynMsgObj.MsgStartUp;
  Begin
  If MInfo^.BaseOpened And MInfo^.Found Then
    If Not LoadAt(MInfo^.Idx^[MInfo^.Cur].Offset) Then
      MInfo^.Found := False;
  End;


{--------------------------------------------------------------- yours}

Procedure SynMsgObj.YoursFirst(Name: String; Handle: String);
  Begin
  MInfo^.YCount := 0;
  Name := SynTrim(Name);
  Handle := SynTrim(Handle);
  If Length(Name) > 0 Then
    Begin
    Inc(MInfo^.YCount);
    MInfo^.YNames[MInfo^.YCount] := SynLower(Name);
    MInfo^.YCrc[MInfo^.YCount] := StrCrc(Name);
    End;
  If Length(Handle) > 0 Then
    Begin
    Inc(MInfo^.YCount);
    MInfo^.YNames[MInfo^.YCount] := SynLower(Handle);
    MInfo^.YCrc[MInfo^.YCount] := StrCrc(Handle);
    End;
  MInfo^.YPos := -1;
  YoursNext;
  End;


Procedure SynMsgObj.YoursNext;
  {Messages to Name or Handle.  The index holds CRCs (user numbers in the mail
   base), so the recipient field of the header is what decides.}
  Var
    i: LongInt;
    j: Word;
    Try_: Boolean;
    T: String;
    Hit: Boolean;

  Begin
  MInfo^.YFound := False;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := synNotOpen;
    Exit;
    End;
  If MInfo^.YCount = 0 Then
    Exit;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  i := MInfo^.YPos + 1;
  While i < MInfo^.IdxCount Do
    Begin
    If Visible(i) Then
      Begin
      Try_ := MInfo^.IsMail;
      For j := 1 To MInfo^.YCount Do
        If MInfo^.Idx^[i].ToCrc = MInfo^.YCrc[j] Then
          Try_ := True;
      If Try_ And LoadAt(MInfo^.Idx^[i].Offset) Then
        Begin
        T := SynLower(SynTrim(MInfo^.MsgTo));
        Hit := False;
        For j := 1 To MInfo^.YCount Do
          If T = MInfo^.YNames[j] Then
            Hit := True;
        If Hit Then
          Begin
          MInfo^.YPos := i;
          MInfo^.Cur := i;
          MInfo^.Found := True;
          MInfo^.YFound := True;
          Exit;
          End;
        End;
      End;
    Inc(i);
    End;
  MInfo^.YPos := MInfo^.IdxCount;
  End;


Function SynMsgObj.YoursFound: Boolean;
  Begin
  YoursFound := MInfo^.YFound;
  End;


{------------------------------------------------------ message details}

Function SynMsgObj.GetFrom: String;
  Begin
  GetFrom := MInfo^.MsgFrom;
  End;


Function SynMsgObj.GetTo: String;
  Begin
  GetTo := MInfo^.MsgTo;
  End;


Function SynMsgObj.GetSubj: String;
  Begin
  GetSubj := MInfo^.MsgSubj;
  End;


Function SynMsgObj.GetCost: Word;
  Begin
  GetCost := MInfo^.Cost And $FFFF;
  End;


Function SynMsgObj.GetDate: String;
  Begin
  GetDate := MInfo^.MsgDate;
  End;


Function SynMsgObj.GetTime: String;
  Begin
  GetTime := MInfo^.MsgTime;
  End;


Function SynMsgObj.GetRefer: LongInt;
  Begin
  GetRefer := MInfo^.Hdr.ThreadOrig;
  End;


Function SynMsgObj.GetSeeAlso: LongInt;
  Begin
  GetSeeAlso := MInfo^.Hdr.ThreadFirst;
  End;


Function SynMsgObj.GetNextSeeAlso: LongInt;
  Begin
  GetNextSeeAlso := MInfo^.Hdr.ThreadNext;
  End;


Function SynMsgObj.GetMsgNum: LongInt;
  Begin
  GetMsgNum := MInfo^.Hdr.Number;
  End;


Function SynMsgObj.GetMsgDisplayNum: LongInt;
  {1 based rank of the current message among the visible ones}
  Var
    i: LongInt;
    Rank: LongInt;

  Begin
  GetMsgDisplayNum := 0;
  If (Not MInfo^.BaseOpened) Or (Not MInfo^.Found) Then
    Exit;
  Rank := 0;
  For i := 0 To MInfo^.Cur Do
    If Visible(i) Then
      Inc(Rank);
  GetMsgDisplayNum := Rank;
  End;


Function SynMsgObj.GetHighMsgNum: LongInt;
  Begin
  GetHighMsgNum := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := Fresh;
    GetHighMsgNum := MInfo^.Status.LastMsg;
    End;
  End;


Function SynMsgObj.GetHighActiveMsgNum: LongInt;
  Var
    i: LongInt;

  Begin
  GetHighActiveMsgNum := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := Fresh;
    i := ScanFrom(MInfo^.IdxCount - 1, -1);
    If i >= 0 Then
      GetHighActiveMsgNum := MInfo^.Idx^[i].Number;
    End;
  End;


Function SynMsgObj.NumberOfMsgs: LongInt;
  Var
    i: LongInt;
    N: LongInt;

  Begin
  NumberOfMsgs := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := Fresh;
    N := 0;
    For i := 0 To MInfo^.IdxCount - 1 Do
      If Visible(i) Then
        Inc(N);
    NumberOfMsgs := N;
    End;
  End;


Procedure SynMsgObj.GetOrig(Var Addr: AddrType);
  Begin
  Addr := MInfo^.Orig;
  End;


Procedure SynMsgObj.GetDest(Var Addr: AddrType);
  Begin
  Addr := MInfo^.Dest;
  End;


Function SynMsgObj.IsLocal: Boolean;
  Begin
  IsLocal := (MInfo^.Hdr.NetAttr And netLocal) <> 0;
  End;


Function SynMsgObj.IsCrash: Boolean;
  Begin
  IsCrash := (MInfo^.Hdr.NetAttr And netCrash) <> 0;
  End;


Function SynMsgObj.IsKillSent: Boolean;
  Begin
  IsKillSent := (MInfo^.Hdr.NetAttr And netKillSent) <> 0;
  End;


Function SynMsgObj.IsSent: Boolean;
  Begin
  IsSent := (MInfo^.Hdr.NetAttr And netSent) <> 0;
  End;


Function SynMsgObj.IsFAttach: Boolean;
  Begin
  IsFAttach := (MInfo^.Hdr.AuxAttr And auxFileAtt) <> 0;
  End;


Function SynMsgObj.IsReqRct: Boolean;
  Begin
  IsReqRct := (MInfo^.Hdr.AuxAttr And auxReceipt) <> 0;
  End;


Function SynMsgObj.IsReqAud: Boolean;
  Begin
  IsReqAud := (MInfo^.Hdr.AuxAttr And auxConfirm) <> 0;
  End;


Function SynMsgObj.IsRetRct: Boolean;
  Begin
  IsRetRct := False;                   {no SMB equivalent}
  End;


Function SynMsgObj.IsFileReq: Boolean;
  Begin
  IsFileReq := (MInfo^.Hdr.AuxAttr And auxFileReq) <> 0;
  End;


Function SynMsgObj.IsRcvd: Boolean;
  Begin
  IsRcvd := (MInfo^.Hdr.Attr And msgRead) <> 0;
  End;


Function SynMsgObj.IsPriv: Boolean;
  Begin
  IsPriv := (MInfo^.Hdr.Attr And msgPrivate) <> 0;
  End;


Function SynMsgObj.IsDeleted: Boolean;
  Begin
  IsDeleted := (MInfo^.Hdr.Attr And msgDelete) <> 0;
  End;


Function SynMsgObj.IsEchoed: Boolean;
  Begin
  IsEchoed := (MInfo^.Hdr.NetAttr And netTypeEcho) <> 0;
  End;


{----------------------------------------------------- reading the text}

Procedure SynMsgObj.MsgTxtStartUp;
  {The body text (and the tail, if asked for) as one block of bytes.  It
   always ends with a CR.}
  Var
    i: Word;
    Total: LongInt;
    Part: PSynBytes;
    Len: LongInt;
    Got: LongInt;
    Q: LongInt;
    X: Word;
    HasLf: Boolean;
    Pass: Word;
    Want: Word;
    P: LongInt;
    Skip: LongInt;

  Begin
  LastSoft := False;
  If MInfo^.TxtBuf <> Nil Then
    Begin
    FreeMem(MInfo^.TxtBuf, MInfo^.TxtLen + 1);
    MInfo^.TxtBuf := Nil;
    End;
  MInfo^.TxtLen := 0;
  MInfo^.TxtPos := 0;
  If (Not MInfo^.BaseOpened) Or (Not MInfo^.Found) Then
    Exit;
  Total := 0;
  For i := 1 To MInfo^.NumDFields Do
    If (MInfo^.DFields[i].DType = dfTextBody) Or
       (MInfo^.IncludeTail And (MInfo^.DFields[i].DType = dfTextTail)) Then
      If (MInfo^.DFields[i].Length > 0) And (MInfo^.DFields[i].Length < MaxOffset) Then
        Inc(Total, MInfo^.DFields[i].Length);
  GetMem(MInfo^.TxtBuf, Total + 2);
  If MInfo^.TxtBuf = Nil Then
    Exit;
  Len := 0;
  For Pass := 1 To 2 Do
    Begin
    If Pass = 1 Then
      Want := dfTextBody
    Else If MInfo^.IncludeTail Then
      Want := dfTextTail
    Else
      Break;
    For i := 1 To MInfo^.NumDFields Do
      If (MInfo^.DFields[i].DType = Want) And (MInfo^.DFields[i].Length > 0) And
         (MInfo^.DFields[i].Length < MaxOffset) Then
        Begin
        Got := ReadAt(MInfo^.SdtF, MInfo^.Hdr.DataOffset + MInfo^.DFields[i].Offset,
          MInfo^.DFields[i].Length, MInfo^.TxtBuf^[Len]);
        If Got > 0 Then
          Begin
          { a list of translation types (words, ended by 0) may come first }
          Skip := 0;
          HasLf := False;
          If (Got >= 2) And (SynGetW(MInfo^.TxtBuf, Len) <= 9) Then
            Begin
            Q := Len;
            While Q + 2 <= Len + Got Do
              Begin
              X := SynGetW(MInfo^.TxtBuf, Q);
              Inc(Q, 2);
              If X = xlatNone Then
                Break;
              If X = xlatLf2Crlf Then
                HasLf := True;
              End;
            Skip := Q - Len;
            Move(MInfo^.TxtBuf^[Len + Skip], MInfo^.TxtBuf^[Len], Got - Skip);
            Dec(Got, Skip);
            End;
          If HasLf Then
            For P := Len To Len + Got - 1 Do
              If MInfo^.TxtBuf^[P] = 10 Then
                MInfo^.TxtBuf^[P] := 13;
          Inc(Len, Got);
          End;
        End;
    End;
  While (Len > 0) And ((MInfo^.TxtBuf^[Len - 1] = 13) Or (MInfo^.TxtBuf^[Len - 1] = 10) Or
        (MInfo^.TxtBuf^[Len - 1] = 0)) Do
    Dec(Len);
  If Len > 0 Then
    Begin
    MInfo^.TxtBuf^[Len] := 13;
    Inc(Len);
    End;
  MInfo^.TxtLen := Len;
  End;


Function SynMsgObj.GetChar: Char;
  Begin
  If MInfo^.TxtPos < MInfo^.TxtLen Then
    Begin
    GetChar := Chr(MInfo^.TxtBuf^[MInfo^.TxtPos]);
    Inc(MInfo^.TxtPos);
    End
  Else
    GetChar := #0;
  End;


Function SynMsgObj.EOM: Boolean;
  Begin
  EOM := (MInfo^.TxtPos >= MInfo^.TxtLen);
  End;


Function SynMsgObj.GetTxtPos: LongInt;
  Begin
  GetTxtPos := MInfo^.TxtPos;
  End;


Procedure SynMsgObj.SetTxtPos(TP: LongInt);
  Begin
  MInfo^.TxtPos := TP;
  End;


{------------------------------------------------- setting message fields}

Procedure SynMsgObj.SetDest(Var Addr: AddrType);
  Begin
  MInfo^.Dest := Addr;
  MInfo^.HaveDest := AddrUsed(Addr);
  End;


Procedure SynMsgObj.SetOrig(Var Addr: AddrType);
  Begin
  MInfo^.Orig := Addr;
  MInfo^.HaveOrig := AddrUsed(Addr);
  End;


Procedure SynMsgObj.SetFrom(Name: String);
  Begin
  MInfo^.MsgFrom := Name;
  End;


Procedure SynMsgObj.SetTo(Name: String);
  Begin
  MInfo^.MsgTo := Name;
  End;


Procedure SynMsgObj.SetSubj(Str: String);
  Begin
  MInfo^.MsgSubj := Str;
  End;


Procedure SynMsgObj.SetCost(SCost: Word);
  Begin
  MInfo^.Cost := SCost;
  End;


Procedure SynMsgObj.SetRefer(SRefer: LongInt);
  Begin
  MInfo^.Hdr.ThreadOrig := SRefer;
  End;


Procedure SynMsgObj.SetSeeAlso(SAlso: LongInt);
  Begin
  MInfo^.Hdr.ThreadFirst := SAlso;
  End;


Procedure SynMsgObj.SetDate(SDate: String);
  Begin
  MInfo^.MsgDate := Copy(SDate, 1, 8);
  End;


Procedure SynMsgObj.SetTime(STime: String);
  Begin
  MInfo^.MsgTime := Copy(STime, 1, 5);
  End;


Procedure SynMsgObj.SetLocal(LS: Boolean);
  Begin
  If LS Then
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr Or netLocal
  Else
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr And (Not netLocal);
  End;


Procedure SynMsgObj.SetRcvd(RS: Boolean);
  Begin
  If RS Then
    MInfo^.Hdr.Attr := MInfo^.Hdr.Attr Or msgRead
  Else
    MInfo^.Hdr.Attr := MInfo^.Hdr.Attr And (Not msgRead);
  End;


Procedure SynMsgObj.SetPriv(PS: Boolean);
  Begin
  If PS Then
    MInfo^.Hdr.Attr := MInfo^.Hdr.Attr Or msgPrivate
  Else
    MInfo^.Hdr.Attr := MInfo^.Hdr.Attr And (Not msgPrivate);
  End;


Procedure SynMsgObj.SetCrash(SS: Boolean);
  Begin
  If SS Then
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr Or netCrash
  Else
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr And (Not netCrash);
  End;


Procedure SynMsgObj.SetKillSent(SS: Boolean);
  Begin
  If SS Then
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr Or netKillSent
  Else
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr And (Not netKillSent);
  End;


Procedure SynMsgObj.SetSent(SS: Boolean);
  Begin
  If SS Then
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr Or netSent
  Else
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr And (Not netSent);
  End;


Procedure SynMsgObj.SetEcho(ES: Boolean);
  Begin
  If ES Then
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr Or netTypeEcho
  Else
    MInfo^.Hdr.NetAttr := MInfo^.Hdr.NetAttr And (Not netTypeEcho);
  End;


Procedure SynMsgObj.SetFAttach(SS: Boolean);
  Begin
  If SS Then
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr Or auxFileAtt
  Else
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr And (Not auxFileAtt);
  End;


Procedure SynMsgObj.SetReqRct(SS: Boolean);
  Begin
  If SS Then
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr Or auxReceipt
  Else
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr And (Not auxReceipt);
  End;


Procedure SynMsgObj.SetReqAud(SS: Boolean);
  Begin
  If SS Then
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr Or auxConfirm
  Else
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr And (Not auxConfirm);
  End;


Procedure SynMsgObj.SetRetRct(SS: Boolean);
  Begin                                {no SMB equivalent}
  End;


Procedure SynMsgObj.SetFileReq(SS: Boolean);
  Begin
  If SS Then
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr Or auxFileReq
  Else
    MInfo^.Hdr.AuxAttr := MInfo^.Hdr.AuxAttr And (Not auxFileReq);
  End;


Procedure SynMsgObj.DoChar(Ch: Char);
  Begin
  If SynGrow(MInfo^.WBuf, MInfo^.WCap, MInfo^.WLen + 1) Then
    Begin
    MInfo^.WBuf^[MInfo^.WLen] := Ord(Ch);
    Inc(MInfo^.WLen);
    End;
  End;


Procedure SynMsgObj.DoKludgeLn(Str: String);
  {FTN kludges have header fields of their own in SMB; this unit does not
   write them, so a kludge line is marked (^A) and left out of the stored text}
  Begin
  If (Length(Str) = 0) Or (Str[1] <> #1) Then
    Str := #1 + Str;
  DoStringLn(Str);
  End;


Procedure SynMsgObj.StartNewMsg;
  Begin
  ClearMsg;
  MInfo^.Found := False;
  MInfo^.WLen := 0;
  MInfo^.MsgDate := DateStr(GetDosDate);
  MInfo^.MsgTime := Copy(TimeStr(GetDosDate), 1, 5);
  End;


{------------------------------------------------------------ writing}

Type
  PSynInfo = ^SynInfoType;


Function LockRange(Inf: PSynInfo; Start, Len: LongInt): Word;
  Var
    Waited: LongInt;
    Code: Word;

  Begin
  Waited := 0;
  LockRange := 0;
  Repeat
    Code := MKLockRegion(FileRec(Inf^.ShdF).Handle, Start, Len, True);
    If Code = mkLockOk Then
      Exit;
    If Code <> mkLockViolation Then
      Begin
      LockRange := synWriteErr;
      Exit;
      End;
    If Waited >= Inf^.LockTimeoutMs Then
      Begin
      LockRange := synLockTimeout;
      Exit;
      End;
    MKDelay(25);
    Inc(Waited, 25);
  Until False;
  End;


Function WithHeaderLock(Inf: PSynInfo; Offset: LongInt; Var Len: LongInt): Word;
  {lock the header record at Offset; Len returns the locked length}
  Var
    H: Array[0..9] Of Byte;
    N: LongInt;

  Begin
  N := SynRd(Inf^.ShdF, Offset, 10, H);
  If (N < 10) Or (H[0] <> Ord('S')) Or (H[1] <> Ord('H')) Or (H[2] <> Ord('D')) Or (H[3] <> 26) Then
    Begin
    WithHeaderLock := synNotSmb;
    Exit;
    End;
  Len := SynMax(PSynWord(@H[8])^, FixedLen);
  WithHeaderLock := LockRange(Inf, Offset, Len);
  End;


Function IdxFind(Inf: PSynInfo; Number: LongInt; Var Pos: LongInt): Boolean;
  Var
    Lo: LongInt;
    Hi: LongInt;
    Mid: LongInt;

  Begin
  IdxFind := False;
  Lo := 0;
  Hi := Inf^.IdxCount - 1;
  While Lo <= Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If Inf^.Idx^[Mid].Number = Number Then
      Begin
      Pos := Mid;
      IdxFind := True;
      Exit;
      End;
    If Inf^.Idx^[Mid].Number < Number Then
      Lo := Mid + 1
    Else
      Hi := Mid - 1;
    End;
  End;


Function LinkReply(Inf: PSynInfo; Parent, NewNum: LongInt): Boolean;
  {The chain walk smb_updatethread does: parent.thread_first, then the
   thread_next links.  Failing here never fails the write.}
  Var
    PPos: LongInt;
    Cur: LongInt;
    Pos: LongInt;
    Next: LongInt;
    Hops: LongInt;
    Len: LongInt;
    Chk: LongInt;
    Off: LongInt;

  Function SetLink(HdrOfs: LongInt; Field: LongInt): Boolean;
    {store NewNum at HdrOfs + Field if it is still 0}
    Begin
    SetLink := False;
    If WithHeaderLock(Inf, HdrOfs, Len) <> 0 Then
      Exit;
    If (SynRd(Inf^.ShdF, HdrOfs + Field, 4, Chk) = 4) And (Chk = 0) Then
      SetLink := SynWr(Inf^.ShdF, HdrOfs + Field, 4, NewNum);
    MKLockRegion(FileRec(Inf^.ShdF).Handle, HdrOfs, Len, False);
    End;

  Begin
  LinkReply := False;
  If Not IdxFind(Inf, Parent, PPos) Then
    Exit;
  Off := Inf^.Idx^[PPos].Offset;
  If SynRd(Inf^.ShdF, Off + 44, 4, Cur) <> 4 Then
    Exit;
  If Cur = 0 Then
    Begin
    LinkReply := SetLink(Off, 44);
    Exit;
    End;
  For Hops := 1 To 100000 Do
    Begin
    If Not IdxFind(Inf, Cur, Pos) Then
      Exit;
    Off := Inf^.Idx^[Pos].Offset;
    If SynRd(Inf^.ShdF, Off + 40, 4, Next) <> 4 Then
      Exit;
    If Next = 0 Then
      Begin
      LinkReply := SetLink(Off, 40);
      Exit;
      End;
    Cur := Next;
    End;
  End;


Function SynMsgObj.WriteMsg: Word;
  {Store the message built with the Set... and Do... calls as a new message,
   following smb_addmsg: lock the status header, allocate data, write data,
   add header, update status, write index.  The new message becomes current.}
  Var
    Norm: PSynBytes;
    NormLen: LongInt;
    NormAlloc: LongInt;
    Rec: PSynBytes;
    RecLen: LongInt;
    RecAlloc: LongInt;
    Pad: PSynBytes;
    i: LongInt;
    LS: LongInt;
    FromS: String;
    ToS: String;
    SubjS: String;
    Err: Word;
    Utc: LongInt;
    Written: LongInt;
    Imported: LongInt;
    DT: DateTime;
    St: Array[0..255] Of Byte;
    BaseLen: LongInt;
    LastMsg: LongInt;
    TotalMsgs: LongInt;
    HeaderOffset: LongInt;
    SidSize: LongInt;
    IdxCount: LongInt;
    LastIdxNum: LongInt;
    HdrVersion: Word;
    Number: LongInt;
    DataBlocks: LongInt;
    SdtSize: LongInt;
    SdaSize: LongInt;
    ShaSize: LongInt;
    ShdSize: LongInt;
    DataOff: LongInt;
    HdrOff: LongInt;
    HdrBlocks: LongInt;
    Hyper: Boolean;
    Locked: Boolean;
    OwnLock: Boolean;
    Fixed: Array[0..FixedLen - 1] Of Byte;
    DField: Array[0..9] Of Byte;
    Z: Byte;
    Idx: SmbIdxType;
    Peek: Array[0..7] Of Byte;
    First: SmbIdxType;
    Reference: LongInt;
    Cost: LongInt;
    Ok: Boolean;
    NewNum: LongInt;
    Pos: LongInt;

  Procedure Done_;
    Begin
    If Norm <> Nil Then FreeMem(Norm, NormAlloc);
    If Rec <> Nil Then FreeMem(Rec, RecAlloc);
    End;

  Begin
  Norm := Nil; Rec := Nil; Pad := Nil; NormLen := 0; NormAlloc := 0; RecLen := 0; RecAlloc := 0;
  NewNum := 0;
  Z := 0;
  MInfo^.Error := 0;
  If Not MInfo^.BaseOpened Then
    Err := synNotOpen
  Else If MInfo^.ReadOnly Then
    Err := synWriteErr
  Else If MInfo^.IsMail Or (SynLower(BaseName(MInfo^.BasePath)) = 'mail') Then
    Err := synMailBase
  Else If MInfo^.AllocBad Then
    Err := synInconsistent
  Else
    Err := 0;
  FromS := MInfo^.MsgFrom;
  If (Err = 0) And (Length(FromS) = 0) Then
    Err := synNoFrom;
  If Err <> 0 Then
    Begin
    MInfo^.Error := Err;
    WriteMsg := Err;
    Exit;
    End;
  ToS := SynTrim(MInfo^.MsgTo);
  If Length(ToS) = 0 Then
    ToS := 'All';
  SubjS := MInfo^.MsgSubj;
  { body: lines end in CRLF, kludge (^A) lines are dropped, NUL becomes blank,
    no trailing white space }
  If Not SynGrow(Norm, NormAlloc, MInfo^.WLen * 2 + 8) Then
    Begin
    MInfo^.Error := synWriteErr;
    WriteMsg := synWriteErr;
    Exit;
    End;
  i := 0;
  LS := 0;                             {where the current line starts in Norm}
  While i <= MInfo^.WLen Do
    Begin
    If (i = MInfo^.WLen) Or (MInfo^.WBuf^[i] = 13) Or (MInfo^.WBuf^[i] = 10) Then
      Begin
      If (i < MInfo^.WLen) And (MInfo^.WBuf^[i] = 13) And (i + 1 < MInfo^.WLen) And
         (MInfo^.WBuf^[i + 1] = 10) Then
        Inc(i);
      If (NormLen > LS) And (Norm^[LS] = 1) Then
        NormLen := LS                  {a kludge line: take it back}
      Else If (i < MInfo^.WLen) Or (NormLen > LS) Then
        Begin
        Norm^[NormLen] := 13;
        Norm^[NormLen + 1] := 10;
        Inc(NormLen, 2);
        End;
      LS := NormLen;
      End
    Else If MInfo^.WBuf^[i] = 0 Then
      Begin
      Norm^[NormLen] := 32;
      Inc(NormLen);
      End
    Else
      Begin
      Norm^[NormLen] := MInfo^.WBuf^[i];
      Inc(NormLen);
      End;
    Inc(i);
    End;
  While (NormLen > 0) And (Norm^[NormLen - 1] <= $20) Do
    Dec(NormLen);
  If NormLen = 0 Then
    Begin
    Done_;
    MInfo^.Error := synNoText;
    WriteMsg := synNoText;
    Exit;
    End;
  { times: the sender's local clock -> UTC + zone }
  If MInfo^.UtcSet Then
    Utc := MInfo^.UtcOff
  Else
    Utc := MKLocalUtcOffset;
  Written := 0;
  FillChar(DT, SizeOf(DT), 0);
  If (Length(MInfo^.MsgDate) = 8) And (Length(MInfo^.MsgTime) >= 5) Then
    Begin
    DT.Year := Str2Long(Copy(MInfo^.MsgDate, 7, 2));
    If DT.Year < 80 Then
      Inc(DT.Year, 2000)
    Else
      Inc(DT.Year, 1900);
    DT.Month := Str2Long(Copy(MInfo^.MsgDate, 1, 2));
    DT.Day := Str2Long(Copy(MInfo^.MsgDate, 4, 2));
    DT.Hour := Str2Long(Copy(MInfo^.MsgTime, 1, 2));
    DT.Min := Str2Long(Copy(MInfo^.MsgTime, 4, 2));
    DT.Sec := 0;
    If ValidDate(DT) And (DT.Hour < 24) And (DT.Min < 60) Then
      Written := DTToUnixDate(DT) - Utc * 60;
    End;
  If Written = 0 Then
    Written := SynUtcNow;
  Imported := SynUtcNow;
  Reference := MInfo^.Hdr.ThreadOrig;
  If Reference < 0 Then
    Reference := 0;
  Cost := MInfo^.Cost;
  { the header record }
  Ok := True;
  RecLen := FixedLen + DFieldLen;
  If Not SynGrow(Rec, RecAlloc, 512) Then
    Ok := False
  Else
    FillChar(Rec^, 512, 0);
  { header fields follow the fixed part and the one data field }
  Ok := Ok And PutHStr(Rec, RecLen, RecAlloc, hfSender, FromS);
  If Length(MInfo^.FromExt) > 0 Then
    Ok := Ok And PutHStr(Rec, RecLen, RecAlloc, hfSenderExt, MInfo^.FromExt);
  Ok := Ok And PutHStr(Rec, RecLen, RecAlloc, hfRecipient, ToS);
  Ok := Ok And PutHStr(Rec, RecLen, RecAlloc, hfSubject, SubjS);
  If Cost <> 0 Then
    Ok := Ok And PutHField(Rec, RecLen, RecAlloc, hfCost, Cost, 4);
  If MInfo^.HaveOrig Then
    Ok := Ok And SynAddr(MInfo^.Orig, Rec, RecLen, RecAlloc, hfSenderNetType, hfSenderNetAddr);
  If MInfo^.HaveDest Then
    Ok := Ok And SynAddr(MInfo^.Dest, Rec, RecLen, RecAlloc, hfRecipNetType, hfRecipNetAddr);
  If (Not Ok) Or (RecLen > $FFFF) Then
    Begin
    Done_;
    MInfo^.Error := synFull;
    WriteMsg := synFull;
    Exit;
    End;
  HdrBlocks := (RecLen + BlockLen - 1) Div BlockLen;
  DataBlocks := (NormLen + BlockLen - 1) Div BlockLen;
  Hyper := Not MInfo^.HasAlloc;
  { ---- everything below runs under the status header lock ---- }
  OwnLock := Not MInfo^.Locked;
  Err := 0;
  BaseLen := MInfo^.Status.Length;
  If (BaseLen < 28) Or (BaseLen > 256) Then
    Err := synNotSmb;
  Locked := False;
  If Err = 0 Then
    Begin
    If OwnLock Then
      Err := LockRange(PSynInfo(MInfo), 0, BaseLen);
    Locked := (Err = 0) And OwnLock;
    End;
  If Err = 0 Then
    Begin
    If SynRd(MInfo^.ShdF, 0, BaseLen, St) < BaseLen Then
      Err := synReadErr
    Else
      Begin
      LastMsg := SynGetL(@St, 8);
      TotalMsgs := SynGetL(@St, 12);
      HeaderOffset := SynGetL(@St, 16);
      If HeaderOffset < BaseLen Then
        Err := synNotSmb;
      End;
    End;
  If Err = 0 Then
    Begin
    SidSize := FileSize(MInfo^.SidF);
    IdxCount := SidSize Div IdxLen;
    LastIdxNum := 0;
    HdrVersion := $0121;
    If IdxCount > 0 Then
      Begin
      If SynRd(MInfo^.SidF, (IdxCount - 1) * IdxLen, IdxLen, Idx) = IdxLen Then
        LastIdxNum := Idx.Number;
      If SynRd(MInfo^.SidF, 0, IdxLen, First) = IdxLen Then
        If SynRd(MInfo^.ShdF, First.Offset, 8, Peek) = 8 Then
          If (Peek[0] = Ord('S')) And (Peek[1] = Ord('H')) And (Peek[2] = Ord('D')) And
             (Peek[3] = 26) Then
            HdrVersion := PSynWord(@Peek[6])^;
      End;
    If SynMax(LastMsg, LastIdxNum) >= $7FFFFFFE Then
      Err := synFull
    Else
      Number := SynMax(LastMsg, LastIdxNum) + 1;
    End;
  If Err = 0 Then
    Begin                              {data allocation}
    SdtSize := FileSize(MInfo^.SdtF);
    If Hyper Then
      Begin
      If SdtSize Mod BlockLen <> 0 Then
        Err := synInconsistent
      Else
        DataOff := SdtSize;
      End
    Else
      Begin
      SdaSize := FileSize(MInfo^.SdaF);
      If SdaSize Mod 2 <> 0 Then
        Err := synInconsistent
      Else
        Begin
        DataOff := (SdaSize Div 2) * BlockLen;
        If DataOff < SdtSize Then
          Err := synInconsistent;
        End;
      End;
    If (Err = 0) And (Int64(DataOff) + Int64(DataBlocks) * BlockLen > MaxOffset) Then
      Err := synFull;
    End;
  If Err = 0 Then
    Begin                              {header allocation}
    ShdSize := FileSize(MInfo^.ShdF);
    If Hyper Then
      HdrOff := ShdSize
    Else
      Begin
      ShaSize := FileSize(MInfo^.ShaF);
      HdrOff := ShaSize * BlockLen + HeaderOffset;
      If HdrOff < ShdSize Then
        Err := synInconsistent;
      End;
    If (Err = 0) And (HdrOff > MaxOffset) Then
      Err := synFull;
    End;
  If Err = 0 Then
    Begin
    { fixed part of the header and its one data field }
    FillChar(Fixed, SizeOf(Fixed), 0);
    Fixed[0] := Ord('S'); Fixed[1] := Ord('H'); Fixed[2] := Ord('D'); Fixed[3] := 26;
    PSynWord(@Fixed[6])^ := HdrVersion;
    PSynWord(@Fixed[10])^ := MInfo^.Hdr.Attr And allAttr And (Not msgDelete);
    PSynLong(@Fixed[12])^ := MInfo^.Hdr.AuxAttr And allAux;
    PSynLong(@Fixed[16])^ := MInfo^.Hdr.NetAttr And allNet;
    PSynLong(@Fixed[20])^ := Written;
    PSynWord(@Fixed[24])^ := Word(Integer(Utc));
    PSynLong(@Fixed[26])^ := Imported;
    PSynWord(@Fixed[30])^ := Word(Integer(Utc));
    PSynLong(@Fixed[32])^ := Number;
    PSynLong(@Fixed[36])^ := Reference;
    PSynLong(@Fixed[64])^ := DataOff;
    PSynWord(@Fixed[68])^ := 1;
    FillChar(DField, SizeOf(DField), 0);          {type 0 = body, offset 0}
    PSynLong(@DField[6])^ := NormLen;
    Move(Fixed, Rec^, FixedLen);
    Move(DField, Rec^[FixedLen], DFieldLen);
    PSynWord(@Rec^[8])^ := RecLen;
    { writes, in the order the SMB storage pseudo code uses }
    GetMem(Pad, SynMax(DataBlocks, HdrBlocks) * BlockLen);
    If Pad = Nil Then
      Err := synWriteErr;
    End;
  If Err = 0 Then
    Begin
    If Not Hyper Then
      Begin
      FillChar(Pad^, DataBlocks * 2, 0);
      For i := 0 To DataBlocks - 1 Do
        PSynWord(@Pad^[i * 2])^ := 1;
      If Not SynWr(MInfo^.SdaF, (DataOff Div BlockLen) * 2, DataBlocks * 2, Pad^) Then
        Err := synWriteErr;
      End;
    End;
  If Err = 0 Then
    Begin
    FillChar(Pad^, DataBlocks * BlockLen, 0);
    Move(Norm^, Pad^, NormLen);
    If Not SynWr(MInfo^.SdtF, DataOff, DataBlocks * BlockLen, Pad^) Then
      Err := synWriteErr;
    End;
  If (Err = 0) And (Not Hyper) Then
    Begin
    FillChar(Pad^, HdrBlocks, 1);
    If Not SynWr(MInfo^.ShaF, (HdrOff - HeaderOffset) Div BlockLen, HdrBlocks, Pad^) Then
      Err := synWriteErr;
    End;
  If Err = 0 Then
    Begin
    FillChar(Pad^, HdrBlocks * BlockLen, 0);
    Move(Rec^, Pad^, RecLen);
    If Not SynWr(MInfo^.ShdF, HdrOff, HdrBlocks * BlockLen, Pad^) Then
      Err := synWriteErr;
    End;
  If Err = 0 Then
    Begin
    SynPutL(@St, 0, Number);                      {last_msg, total_msgs}
    SynPutL(@St, 4, TotalMsgs + 1);
    If Not SynWr(MInfo^.ShdF, 8, 8, St) Then
      Err := synWriteErr;
    End;
  If Err = 0 Then
    Begin
    FillChar(Idx, SizeOf(Idx), 0);
    Idx.ToCrc := StrCrc(ToS);
    Idx.FromCrc := StrCrc(FromS);
    Idx.SubjCrc := SubjCrcOf(SubjS);
    Idx.Attr := MInfo^.Hdr.Attr And allAttr And (Not msgDelete);
    Idx.Offset := HdrOff;
    Idx.Number := Number;
    Idx.Time := Imported;
    If Not SynWr(MInfo^.SidF, IdxCount * IdxLen, IdxLen, Idx) Then
      Err := synWriteErr;
    End;
  If Locked Then
    ReleaseLock(0, BaseLen);
  Done_;
  If Pad <> Nil Then
    FreeMem(Pad, SynMax(DataBlocks, HdrBlocks) * BlockLen);
  MInfo^.StampOk := False;
  If Err = 0 Then
    Begin
    NewNum := Number;
    MInfo^.Error := Fresh;
    If (MInfo^.Error = 0) And (Reference <> 0) Then
      If LinkReply(PSynInfo(MInfo), Reference, Number) Then;
    MInfo^.StampOk := False;
    MInfo^.Error := Fresh;
    If MInfo^.Error = 0 Then
      Begin
      Pos := FindPos(NewNum);
      If Pos >= 0 Then
        If MoveTo(Pos) Then;
      End;
    End
  Else
    MInfo^.Error := Err;
  WriteMsg := Err;
  End;


Function SynMsgObj.UpdateFlags(Number: LongInt; AttrSet, AttrClear, AuxSet, AuxClear,
  NetSet, NetClear: LongInt): Word;
  {Set / clear flag bits in the header and in the index.  The header record is
   locked while it is changed.}
  Var
    Pos: LongInt;
    Off: LongInt;
    Len: LongInt;
    Cur: Array[0..9] Of Byte;
    Attr: Word;
    Aux: LongInt;
    Net: LongInt;
    Err: Word;
    W: Word;

  Begin
  Err := 0;
  If Not MInfo^.BaseOpened Then
    Err := synNotOpen
  Else If MInfo^.ReadOnly Then
    Err := synWriteErr
  Else If MInfo^.IsMail Then
    Err := synMailBase;
  If Err = 0 Then
    Begin
    MInfo^.StampOk := False;
    Err := Fresh;
    End;
  If Err = 0 Then
    Begin
    Pos := FindPos(Number);
    If Pos < 0 Then
      Err := synNotFound
    Else
      Off := MInfo^.Idx^[Pos].Offset;
    End;
  If Err = 0 Then
    Err := WithHeaderLock(PSynInfo(MInfo), Off, Len);
  If Err = 0 Then
    Begin
    If SynRd(MInfo^.ShdF, Off + 10, 10, Cur) < 10 Then
      Err := synReadErr
    Else
      Begin
      Attr := PSynWord(@Cur[0])^;
      Aux := PSynLong(@Cur[2])^;
      Net := PSynLong(@Cur[6])^;
      Attr := (Attr Or AttrSet) And (Not AttrClear);
      Aux := (Aux Or AuxSet) And (Not AuxClear);
      Net := (Net Or NetSet) And (Not NetClear);
      PSynWord(@Cur[0])^ := Attr;
      PSynLong(@Cur[2])^ := Aux;
      PSynLong(@Cur[6])^ := Net;
      If Not SynWr(MInfo^.ShdF, Off + 10, 10, Cur) Then
        Err := synWriteErr
      Else
        Begin
        W := Attr;
        If Not SynWr(MInfo^.SidF, Pos * IdxLen + 6, 2, W) Then
          Err := synWriteErr;
        End;
      End;
    MKLockRegion(FileRec(MInfo^.ShdF).Handle, Off, Len, False);
    End;
  MInfo^.StampOk := False;
  MInfo^.Error := Err;
  UpdateFlags := Err;
  End;


Procedure SynMsgObj.ReWriteHdr;
  {Write the flags of the current message (private, received, local, sent,
   kill/sent, crash, echo, file attach / request, receipt and audit requests)
   back to its header and index.  Names, text and dates stay.}
  Var
    Id: LongInt;
    A: LongInt;
    X: LongInt;
    N: LongInt;

  Begin
  If (Not MInfo^.BaseOpened) Or (Not MInfo^.Found) Then
    Begin
    If MInfo^.BaseOpened Then
      MInfo^.Error := synNotFound
    Else
      MInfo^.Error := synNotOpen;
    Exit;
    End;
  Id := MInfo^.Hdr.Number;
  A := MInfo^.Hdr.Attr And allAttr;
  X := MInfo^.Hdr.AuxAttr And allAux;
  N := MInfo^.Hdr.NetAttr And allNet;
  If UpdateFlags(Id, A, allAttr And (Not A), X, allAux And (Not X), N, allNet And (Not N)) = 0 Then
    SetMsgLoc(Id);
  End;


Procedure SynMsgObj.DeleteMsg;
  {Marks the message deleted (MSG_DELETE); smbutil / sbbs maintenance removes
   it later.  It disappears from seeks and counts unless SetIncludeDeleted.}
  Var
    Id: LongInt;

  Begin
  If (Not MInfo^.BaseOpened) Or (Not MInfo^.Found) Then
    Begin
    If MInfo^.BaseOpened Then
      MInfo^.Error := synNotFound
    Else
      MInfo^.Error := synNotOpen;
    Exit;
    End;
  Id := MInfo^.Hdr.Number;
  If UpdateFlags(Id, msgDelete, 0, 0, 0, 0, 0) = 0 Then
    MInfo^.Found := False;
  End;


End.
