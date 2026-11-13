Unit MKMsgMer;       {Merlin Msg Object}

{$I MKB.Def}

{
     MKMsgMer - Copyright 1995 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32/v34
     FidoNet: 1:110/290
     You may also reach me at maym@dmapub.dma.org
}

{
     The Merlin message base: ONE file made of frames, with recycled free
     space, subfields, reply links and crash recovery.  This unit is the
     Free Pascal implementation of the design in MessageMerlin.js (format
     version 1) - the two read and write the same files.

     All numbers are little endian, records are packed.

       frame header (14):  FrameId 'MKMB'  FrameType(2)  FrameDataSize(4)
                           FrameUsedSize(4)
         types 1 base header, 2 free list, 3 message, 4 message index,
               5 last read, 6 free frame.
         Frame sizes count the bytes AFTER the 14 byte frame header.
         Frames follow each other without gaps, starting at 132 (right after
         the base header): next frame = pos + 14 + FrameDataSize.
       base header (132 at 0): frame header, LastMsgId, IdxPtr, FreePtr,
         LastReadPtr, LastMsgScanned, MaxMsgs, NumMsgs, BaseMsgId,
         DateCreated, DisplayMsgOffset, then Extra[78]:
         FormatVersion(2, =1; 0 = first draft) Flags(2, bit 0 = DIRTY)
         Generation(4).
       index frame: 8 byte records [Hash, FramePos], record i is message
         BaseMsgId + i, FramePos 0 = deleted.  Hash = 30 bit hash of the "to"
         name | $40000000 ToBeExported | $80000000 Received.
         NumMsgs = number of ACTIVE messages.
       free list frame: 8 byte records [FrameSize, FramePos], 0 = empty slot.
       last read frame: FrameUsedSize / 8 records [UserId, LastRead].
       message frame: header (54 bytes), then subfields
         [SubFieldType(4) SubDataLength(4) data].

     Decisions (as in MessageMerlin.js):
       - Message numbers are never reused.  Display number = number minus
         DisplayMsgOffset.
       - Delete: flag the frame, zero the index record, unlink from the reply
         chain, turn the frame into free space.  New frames take the best
         fitting free frame; free neighbours merge; free space at the end of
         the file is given back.
       - Crash safety: a writer sets the DIRTY flag (and bumps Generation)
         before its first change and clears it when done.  A writer that
         finds DIRTY set repairs the base first (Repair).  Readers wait a
         moment for DIRTY to clear.  Check reports what Repair would change.
       - Locking: one byte at $FFFFFFFF, taken by every writer.  Readers do
         not lock; they read header, index, header again and retry if the
         header changed.
       - MaxMsgs > 0: the oldest messages are deleted before a new one is
         added so that at most MaxMsgs remain.

     Strings are raw bytes.  Nothing is converted; the charset of a message
     is recorded in subfield 12 (SetCharset, default 'UTF-8').  Case folding
     of names (for the index hash and "yours" matching) is ASCII only.

     Differences from the JS version: the message date/time are the sender's
     local wall clock (SetDate/SetTime, 'MM-DD-YY' and 'HH:MM'); they are
     stored as UTC using the message's UTC offset (SetUtcOffset, default
     this computer's current offset).  Dates are 32 bit signed unix times.
}


Interface


Uses MKGlobT, MKMsgAbs,
  Dos;


Type MerlinFrameHdrType = Record
  FrameId: LongInt;                    { indicates valid frame }
  FrameType: Word;                     { type of frame }
  FrameDataSize: LongInt;              { size of frame data avail }
  FrameUsedSize: LongInt;              { portion of frame data used }
  End;


Type MerlinMsgBaseHdrType = Record     { record at start of msg base }
  FrameHdr: MerlinFrameHdrType;        { normal frame header }
  LastMsgId: LongInt;                  { last msgid used-ie high msg num }
  IdxPtr: LongInt;                     { file position of index frame }
  FreePtr: LongInt;                    { file position of free list frame }
  LastReadPtr: LongInt;                { file position of lastread frame }
  LastMsgScanned: LongInt;             { lowest msgid to export, minus one }
  MaxMsgs: LongInt;                    { maximum desired msgs in msg base }
  NumMsgs: LongInt;                    { number of ACTIVE msgs }
  BaseMsgId: LongInt;                  { msgid of first idx record }
  DateCreated: LongInt;                { unix-style time stamp }
  DisplayMsgOffset: LongInt;           { subtract for display msg number }
  Extra: Array[1..78] of Char;         { version(2) flags(2) generation(4) ... }
  End;


Type MerlinMsgHdrType = Record         { header for each message }
  FrameHdr: MerlinFrameHdrType;        { normal frame header }
  MsgNum: LongInt;                     { msgid-ie message number }
  TotMsgSize: LongInt;                 { total size of msg }
  ReplyTo: LongInt;                    { orig msgid generating this reply }
  ReplyFirst: LongInt;                 { first reply msgid to this msg }
  ReplyNext: LongInt;                  { link chain of reply msg ids }
  DateWritten: LongInt;                { unix time stamp (UTC) }
  DateProcessed: LongInt;              { unix time stamp (UTC) }
  Attr1: LongInt;                      { message attribute flags }
  Attr2: LongInt;                      { additional message attribute flags }
  Cost: LongInt;                       { cost }
  End;


Type MerlinIdxType = Record            { msg index record for one msg }
  NameHash: LongInt;                   { hash of to name + flag bits }
  FramePos: LongInt;                   { file pos of msg header frame }
  End;


Type MerlinFreeListType = Record       { free list record for one frame }
  FrameSize: LongInt;                  { size of data frame avail }
  FramePos: LongInt;                   { file pos of free frame }
  End;


Type MerlinLastReadType = Record       { last read for one user }
  UserId: LongInt;                     { user id  - application defined }
  LastRead: LongInt;                   { last/highest msg id read }
  End;


Type SubFieldHdrType = Record          { Subfields start with these two longs }
  SubFieldType: LongInt;               { Type of subfield }
  SubDataLength: LongInt;              { Sub field length of data }
  End;                                 { followed immediately by sub data }


Const                                  { Error codes (MInfo^.Error) }
  merOk            = 0;
  merNoPath        = 100;              { message path not set }
  merNotOpen       = 110;              { message base is not open }
  merReadErr       = 120;              { read error }
  merWriteErr      = 130;              { write error / base opened read only }
  merNeedsRepair   = 150;              { interrupted write: run Repair }
  merNotMerlin     = 1000;             { not a Merlin message base }
  merNoFrom        = 1010;             { message has no from name }
  merNoText        = 1020;             { message has no text }
  merBadMsg        = 1030;             { message cannot be stored }
  merNotFound      = 1040;             { message not found }
  merFull          = 1050;             { message numbers exhausted }
  merLockTimeout   = 1060;             { could not get the write lock }
  merNewVersion    = 1070;             { base is newer than this code }
  merChanging      = 1080;             { base keeps changing }
  merDamaged       = 1090;             { base is damaged: Check / Repair }
  merExists        = 1100;             { CreateMsgBase: base already exists }


Type
  TMerBytes = Array[0..$7FFFFFF] of Byte;
  PMerBytes = ^TMerBytes;
  PMerLong = ^LongInt;
  PMerWord = ^Word;
  PMerFile = ^File;

  MerIdxEnt = Record                   { one ACTIVE message in memory }
    Id: LongInt;
    Pos: LongInt;
    Hash: LongInt;
    End;
  TMerIdxArr = Array[0..$FFFFFF] of MerIdxEnt;
  PMerIdxArr = ^TMerIdxArr;
  TMerFreeArr = Array[0..$FFFFFF] of MerlinFreeListType;
  PMerFreeArr = ^TMerFreeArr;


Type MerCtxType = Record               { context of one write operation }
  F: PMerFile;
  Err: Word;
  NeedRepair: Boolean;
  Base: MerlinMsgBaseHdrType;
  Idx: PMerBytes;                      { index records of the slots in use }
  IdxLen: LongInt;
  IdxAlloc: LongInt;
  Free: PMerFreeArr;
  FreeCnt: LongInt;
  FreeAlloc: LongInt;
  Active: LongInt;
  Size: LongInt;                       { logical end of file }
  IdxPos: LongInt;
  IdxData: LongInt;
  FreePos: LongInt;
  FreeData: LongInt;
  Changed: Boolean;
  IdxChanged: Boolean;
  ExportTouched: Boolean;
  Sync: Boolean;
  Begun: Boolean;                      { DIRTY set, generation bumped }
  Gen: LongInt;
  Phys: LongInt;                       { physical file size as far as we know }
  Size0: LongInt;                      { file size when the operation began }
  Undo: PMerBytes;                     { old bytes, restored on failure }
  UndoLen: LongInt;
  UndoAlloc: LongInt;
  Repaired: Boolean;
  OwnLock: Boolean;                    { this operation took the file lock }
  NewNum: LongInt;                     { number given to an added message }
  End;
  PMerCtx = ^MerCtxType;


Type MerlinInfoType = Record           { Temp storage to access base }
  FN: String[255];                     { Path and file name }
  Error: Word;                         { Access error code }
  MsgFile: File;                       { File handle for msg base }
  BaseOpened: Boolean;                 { Has msg base been opened }
  ReadOnly: Boolean;                   { File could only be opened read only }
  Locked: Boolean;                     { Has msg base been locked }
  LockCount: Integer;                  { Count of locks for unlocking }
  Charset: String[16];                 { charset written into new messages }
  MailType: MsgMailType;               { new msgs are ToBeExported unless normal }
  AutoRepair: Boolean;                 { writers repair an interrupted base }
  Sync: Boolean;                       { fsync around a write }
  LinkReplies: Boolean;                { link a reply into its parent's chain }
  UnlinkOnDelete: Boolean;             { unlink a deleted msg from its chain }
  DirtyWaitMs: Word;                   { readers wait this long for DIRTY }
  LockTimeoutMs: Word;                 { how long a writer waits for the lock }
  Base: MerlinMsgBaseHdrType;          { Msg base header as last loaded }
  Ids: PMerIdxArr;                     { active messages, ascending }
  IdCount: LongInt;
  IdCap: LongInt;
  StampOk: Boolean;                    { loaded view is known to be current }
  StampSize: LongInt;
  StampGen: LongInt;
  StampTime: LongInt;
  BaseDirty: Boolean;                  { base was dirty when loaded }
  Cur: LongInt;                        { current msg number; 0 = before first }
  Found: Boolean;                      { current msg is valid }
  YCount: Word;                        { names for YoursFirst }
  YNames: Array[1..2] of String[128];
  YHash: Array[1..2] of LongInt;
  YAscii: Boolean;
  YCur: LongInt;
  YFound: Boolean;
  ExpCur: LongInt;
  ExpFound: Boolean;
  Hdr: MerlinMsgHdrType;               { Msg header for current message }
  MsgFrom: String[255];                { Current msg is from }
  MsgTo: String[255];                  { Current msg is to }
  MsgSubj: String[255];                { Current msg subject }
  MsgDate: String[8];                  { MM-DD-YY, sender's local time }
  MsgTime: String[5];                  { HH:MM, sender's local time }
  Orig: AddrType;                      { FTN from address }
  Dest: AddrType;                      { FTN to address }
  HaveOrig: Boolean;
  HaveDest: Boolean;
  MsgCharset: String[16];              { charset of the current msg }
  UtcOff: LongInt;                     { minutes east of UTC, if UtcSet }
  UtcSet: Boolean;
  EchoSet: Boolean;                    { SetEcho was called on new msg }
  EchoVal: Boolean;
  TxtBuf: PMerBytes;                   { text being read }
  TxtLen: LongInt;
  TxtPos: LongInt;
  WBuf: PMerBytes;                     { text being written }
  WLen: LongInt;
  WCap: LongInt;
  Ctx: PMerCtx;
  ReportCnt: Word;                     { Check/Repair: problems found }
  ReportMore: LongInt;                 { ... and how many did not fit }
  Report: Array[1..40] of String[120];
  End;


Type MerlinMsgObj = Object(AbsMsgObj)
  MInfo: ^MerlinInfoType;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetMsgPath(MP: String); Virtual; {Set msg base file name}
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
  Procedure DoChar(Ch: Char); Virtual; {Add character to message text}
  Procedure DoKludgeLn(Str: String); Virtual; {Add ^A kludge line to msg}
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
  Function  GetNextSeeAlso: LongInt; Virtual; {Get next reply of current msg}
  Procedure SetNextSeeAlso(SAlso: LongInt); Virtual;
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
  Function  GetHighActiveMsgNum: LongInt; Virtual; {Get highest active msg num}
  Procedure SetMailType(MT: MsgMailType); Virtual; {Set message base type}
  Function  GetSubArea: Word; Virtual; {Get sub area number}
  Procedure ReWriteHdr; Virtual; {Rewrite msg header after changes}
  Procedure DeleteMsg; Virtual; {Delete current message}
  Procedure SetEcho(ES: Boolean); Virtual; {Set echo status}
  Function  NumberOfMsgs: LongInt; Virtual; {Number of messages}
  Function  GetLastRead(UNum: LongInt): LongInt; Virtual; {Get last read for user num}
  Procedure SetLastRead(UNum: LongInt; LR: LongInt); Virtual; {Set last read}
  Function  GetMsgDisplayNum: LongInt; Virtual; {Number to display}
  Function  GetTxtPos: LongInt; Virtual; {Get indicator of msg text position}
  Procedure SetTxtPos(TP: LongInt); Virtual; {Set text position}
  Procedure SetAttr1(tf: Boolean; Mask: LongInt);
  Procedure SetAttr2(tf: Boolean; Mask: LongInt);
  {Merlin extras}
  Procedure SetCharset(Name: String);    {Charset written into new msgs}
  Function  GetCharset: String;          {Charset of the current msg}
  Procedure SetUtcOffset(Minutes: LongInt); {Sender's offset, minutes east}
  Function  GetUtcOffset: LongInt;
  Procedure SetAutoRepair(On: Boolean);
  Procedure SetSync(On: Boolean);
  Procedure Refresh;                     {Force a re-read of the index}
  Function  ExportFirst(From: LongInt): Boolean; {Next msg to be exported}
  Function  ExportNext: Boolean;
  Function  ExportFound: Boolean;
  Function  MarkExported(MsgNum: LongInt; Exported: Boolean): Word;
  Function  GetLastScanned: LongInt;
  Function  SetLastScanned(MsgNum: LongInt): Word;
  Function  Check: Boolean;              {True = clean; problems in MInfo^.Report}
  Function  Repair: Boolean;             {True = repaired (or nothing to do)}
  Function  ReadAt(Pos, Len: LongInt; Var Buf): LongInt;
  Function  LoadOnce(IgnoreDirty: Boolean; Var Retry: Boolean): Word;
  Function  LoadAll(RepairOnDirty: Boolean): Word;
  Function  Fresh: Word;
  Function  LoadHeader(Id: LongInt): Boolean;
  Function  SeekIdx(I: LongInt; Dir: LongInt): Boolean;
  Function  LowerBound(V: LongInt): LongInt;
  Function  UpperBound(V: LongInt): LongInt;
  Procedure ClearMsg;
  Function  BeginWrite: Boolean;
  Function  EndWrite(Ok: Boolean): Word;
  Function  GetLock: Word;
  Procedure ReleaseLock;
  End;


Type MerlinMsgPtr = ^MerlinMsgObj;


Implementation


Uses MKFile, MKString, MKMisc, MKDos, MKPlat;

Const
  mFrameId = $424d4b4d;                {FrameHdr.FrameId}

Const                                  {FrameHdr.FrameType}
  mftMsgBaseHdr  =   1;                {Message base header}
  mftFreeList    =   2;                {Free frame list index}
  mftMsg         =   3;                {Message}
  mftMsgIdx      =   4;                {Message index}
  mftLastRead    =   5;                {Lastread records}
  mftFreeFrame   =   6;                {Free space}

Const                                  {MsgHdr.Attr1}
  ma1Deleted       = $00000001;        {Message is deleted}
  ma1Priv          = $00000002;        {Message is priviledged}
  ma1Rcvd          = $00000004;        {Message has been received}
  ma1ToBeExported  = $00000008;        {To be exported still}
  ma1Local         = $00000010;        {Locally generated}
  ma1KillSent      = $00000020;        {Kill after sending}
  ma1Sent          = $00000040;        {Has been sent}
  ma1FAttach       = $00000080;        {File attach}
  ma1Crash         = $00000100;        {Crash netmail}
  ma1ReqRcpt       = $00000200;        {Request receipt}
  ma1RetRcpt       = $00000400;        {Return receipt}
  ma1Freq          = $00000800;        {File Request}
  ma1Hold          = $00001000;        {Hold}
  ma1Immed         = $00002000;        {Immediate}
  ma1Direct        = $00004000;        {Direct}
  ma1Gate          = $00008000;        {Send through gateway}
  ma1TFS           = $00010000;        {Truncate File when Sent}
  ma1KFS           = $00020000;        {Kill File when Sent}
  ma1ReqAud        = $00040000;        {Request audit}
  ma1Mapped        = $0007FFFE;        {all the flags above except Deleted}

Const                                  { sub field type values }
  sfNone           = 0000;             { none - ignore }
  sfFrom           = 0002;             { msg from name }
  sfTo             = 0003;             { msg to name }
  sfMsgId          = 0004;             { msgid }
  sfReplyId        = 0005;             { reply }
  sfSubj           = 0006;             { subject }
  sfPID            = 0007;             { space wasting PID line }
  sfVia            = 0008;             { via }
  sfOrig           = 0010;             { origin address "zone:net/node.point" }
  sfDest           = 0011;             { destination address }
  sfCharset        = 0012;             { charset name }
  sfUtc            = 0013;             { UTC offset, int16 minutes east }
  sfKludge         = 2000;             { FTN space wasting unknown kludge line }
  sfSeenby         = 2001;             { FTN seenby }
  sfPath           = 2002;             { FTN Path }
  sfFlags          = 2003;             { FTN Flags }
  sfText           = 9000;             { Normal message text }

Const
  FH         = 14;                     { frame header size }
  BaseLen    = 132;                    { base header size }
  MH         = 54;                     { message header size }
  Rec        = 8;                      { index / free list / last read record }
  Peek       = 1280;                   { bytes read first for a message header }
  MaxName    = 128;                    { longest from / to / subject }
  MaxId      = $7FFFFFFF;
  SplitMin   = 48;                     { split a free frame if this much is left }
  BfDirty    = 1;                      { base flag: a write is in progress }
  FormatVer  = 1;
  moReplyTo    = 22;                   { offsets inside a message header }
  moReplyFirst = 26;
  moReplyNext  = 30;
  moWritten    = 34;
  moAttr1      = 42;
  XVersion   = 54;                     { offsets inside the base header }
  XFlags     = 56;
  XGen       = 58;
  HashMask   = $3FFFFFFF;
  IxExport   = $40000000;
  LockStart  = -1;                     { the lock byte is at $FFFFFFFF }
  LockLen    = 1;


Function IxRcvd: LongInt;
  Begin
  IxRcvd := LongInt($80000000);
  End;


{---------------------------------------------------------------- helpers}

Function MerMin(A, B: LongInt): LongInt;
  Begin
  If A < B Then MerMin := A Else MerMin := B;
  End;


Function MerMax(A, B: LongInt): LongInt;
  Begin
  If A > B Then MerMax := A Else MerMax := B;
  End;


Function MerGetL(P: PMerBytes; O: LongInt): LongInt;
  Begin
  MerGetL := PMerLong(@P^[O])^;
  End;


Procedure MerPutL(P: PMerBytes; O: LongInt; V: LongInt);
  Begin
  PMerLong(@P^[O])^ := V;
  End;


Function MerGetW(P: PMerBytes; O: LongInt): Word;
  Begin
  MerGetW := PMerWord(@P^[O])^;
  End;


Procedure MerPutW(P: PMerBytes; O: LongInt; V: Word);
  Begin
  PMerWord(@P^[O])^ := V;
  End;


Function BaseVersion(Var B: MerlinMsgBaseHdrType): Word;
  Begin
  BaseVersion := PMerWord(@B.Extra[1])^;
  End;


Function BaseFlags(Var B: MerlinMsgBaseHdrType): Word;
  Begin
  BaseFlags := PMerWord(@B.Extra[3])^;
  End;


Function BaseGen(Var B: MerlinMsgBaseHdrType): LongInt;
  Begin
  BaseGen := PMerLong(@B.Extra[5])^;
  End;


Procedure SetBaseExtra(Var B: MerlinMsgBaseHdrType; Ver, Flags: Word; Gen: LongInt);
  Begin
  PMerWord(@B.Extra[1])^ := Ver;
  PMerWord(@B.Extra[3])^ := Flags;
  PMerLong(@B.Extra[5])^ := Gen;
  End;


Procedure MakeFrameHdr(Var H: MerlinFrameHdrType; Typ: Word; Data, Used: LongInt);
  Begin
  H.FrameId := mFrameId;
  H.FrameType := Typ;
  H.FrameDataSize := Data;
  H.FrameUsedSize := Used;
  End;


Function MerGrow(Var P: PMerBytes; Var Alloc: LongInt; Need: LongInt): Boolean;
  { make the buffer at least Need bytes; keeps the contents }
  Var
    NewAlloc: LongInt;

  Begin
  MerGrow := True;
  If Need <= Alloc Then
    Exit;
  NewAlloc := MerMax(Need, Alloc * 2);
  NewAlloc := MerMax(NewAlloc, 256);
  ReAllocMem(P, NewAlloc);
  If P = Nil Then
    Begin
    Alloc := 0;
    MerGrow := False;
    End
  Else
    Alloc := NewAlloc;
  End;


Function MerUtcNow: LongInt;
  Var
    DT: DateTime;
    Dow: Word;
    S100: Word;

  Begin
  Dos.GetDate(DT.Year, DT.Month, DT.Day, Dow);
  Dos.GetTime(DT.Hour, DT.Min, DT.Sec, S100);
  MerUtcNow := DTToUnixDate(DT) - MKLocalUtcOffset * 60;
  End;


Function MerNameHash(S: String): LongInt;
  {ELF hash (as Squish) of the ASCII lower-cased name, & $3fffffff}
  Var
    H: DWord;
    G: DWord;
    i: Word;

  Begin
  H := 0;
  For i := 1 To Length(S) Do
    Begin
    H := (H Shl 4) + Ord(LoCase(S[i]));
    G := H And $F0000000;
    If G <> 0 Then
      H := (H Or (G Shr 24)) Or G;
    End;
  MerNameHash := LongInt(H And HashMask);
  End;


Function AttrBits(Attr: LongInt): LongInt;
  {the Received / ToBeExported flags as they are kept in the index hash}
  Var
    R: LongInt;

  Begin
  R := 0;
  If (Attr And ma1Rcvd) <> 0 Then
    R := R Or IxRcvd;
  If (Attr And ma1ToBeExported) <> 0 Then
    R := R Or IxExport;
  AttrBits := R;
  End;


Function SlotHash(Name: String; Attr: LongInt): LongInt;
  Begin
  SlotHash := MerNameHash(Name) Or AttrBits(Attr);
  End;


Function MerLower(S: String): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    S[i] := LoCase(S[i]);
  MerLower := S;
  End;


Function MerTrim(S: String): String;
  Begin
  While (Length(S) > 0) And (S[Length(S)] <= ' ') Do
    Dec(S[0]);
  While (Length(S) > 0) And (S[1] <= ' ') Do
    Delete(S, 1, 1);
  MerTrim := S;
  End;


Function MerRd(Var F: File; Pos, Len: LongInt; Var Buf): LongInt;
  {bytes read (may be short at the end of the file), -1 on error}
  Var
    N: LongInt;

  Begin
  If IoResult <> 0 Then;
  If Len <= 0 Then
    Begin
    MerRd := 0;
    Exit;
    End;
  Seek(F, Pos);
  If IoResult <> 0 Then
    Begin
    MerRd := -1;
    Exit;
    End;
  N := 0;
  BlockRead(F, Buf, Len, N);
  If IoResult <> 0 Then
    MerRd := -1
  Else
    MerRd := N;
  End;


Function MerWr(Var F: File; Pos, Len: LongInt; Var Buf): Boolean;
  Var
    N: LongInt;

  Begin
  MerWr := False;
  If IoResult <> 0 Then;
  If Len <= 0 Then
    Begin
    MerWr := True;
    Exit;
    End;
  Seek(F, Pos);
  If IoResult <> 0 Then
    Exit;
  N := 0;
  BlockWrite(F, Buf, Len, N);
  If (IoResult = 0) And (N = Len) Then
    MerWr := True;
  End;


Function MerTruncate(Var F: File; Size: LongInt): Boolean;
  Begin
  MerTruncate := False;
  If IoResult <> 0 Then;
  Seek(F, Size);
  If IoResult <> 0 Then
    Exit;
  Truncate(F);
  MerTruncate := (IoResult = 0);
  End;


{--------------------------------------------------- the write context}
{ A writer works on a context (C): the base header, the index and the free
  list in memory, plus an undo log.  Every change to the file goes through
  CPoke, which saves the old bytes first, so a failed operation can be rolled
  back.  C^.Err is sticky: once it is set every later call does nothing. }

Procedure CUndoAdd(C: PMerCtx; Pos, Len: LongInt);
  {save what is at Pos..Pos+Len (as far as it exists) in the undo log}
  Var
    Need: LongInt;
    Got: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  Need := C^.UndoLen + 12 + Len;
  If Not MerGrow(C^.Undo, C^.UndoAlloc, Need) Then
    Begin
    C^.Err := merWriteErr;
    Exit;
    End;
  Got := 0;
  If Len > 0 Then
    Begin
    Got := MerRd(C^.F^, Pos, Len, C^.Undo^[C^.UndoLen + 8]);
    If Got < 0 Then
      Begin
      C^.Err := merReadErr;
      Exit;
      End;
    End;
  MerPutL(C^.Undo, C^.UndoLen, Pos);
  MerPutL(C^.Undo, C^.UndoLen + 4, Got);
  MerPutL(C^.Undo, C^.UndoLen + 8 + Got, 12 + Got);      {entry size, for walking back}
  Inc(C^.UndoLen, 12 + Got);
  End;


Procedure CRollback(C: PMerCtx);
  {put the file back the way it was when the operation began}
  Var
    EntLen: LongInt;
    Pos: LongInt;
    Len: LongInt;

  Begin
  While C^.UndoLen > 0 Do
    Begin
    EntLen := MerGetL(C^.Undo, C^.UndoLen - 4);
    Pos := MerGetL(C^.Undo, C^.UndoLen - EntLen);
    Len := MerGetL(C^.Undo, C^.UndoLen - EntLen + 4);
    If Len > 0 Then
      If MerWr(C^.F^, Pos, Len, C^.Undo^[C^.UndoLen - EntLen + 8]) Then;
    Dec(C^.UndoLen, EntLen);
    End;
  If FileSize(C^.F^) > C^.Size0 Then
    If MerTruncate(C^.F^, C^.Size0) Then;
  If IoResult <> 0 Then;
  End;


Procedure CRebase(C: PMerCtx);
  {a new starting point (after a repair, say)}
  Begin
  C^.UndoLen := 0;
  C^.Phys := FileSize(C^.F^);
  C^.Size0 := C^.Phys;
  C^.Begun := False;
  End;


Procedure CPoke(C: PMerCtx; Pos, Len: LongInt; Var Buf; NoBegin: Boolean); Forward;


Procedure CBegin(C: PMerCtx);
  {DIRTY on, Generation + 1, before anything else changes}
  Var
    Old: Array[0..7] of Byte;
    NewB: Array[0..7] of Byte;
    Flags: Word;
    Gen: LongInt;
    N: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  N := MerRd(C^.F^, XVersion, 8, Old);
  If N <> 8 Then
    Begin
    C^.Err := merReadErr;
    Exit;
    End;
  Flags := PMerWord(@Old[2])^ Or BfDirty;
  Gen := PMerLong(@Old[4])^ + 1;
  PMerWord(@NewB[0])^ := FormatVer;
  PMerWord(@NewB[2])^ := Flags;
  PMerLong(@NewB[4])^ := Gen;
  CUndoAdd(C, XVersion, 8);
  If C^.Err <> 0 Then
    Exit;
  If Not MerWr(C^.F^, XVersion, 8, NewB) Then
    Begin
    C^.Err := merWriteErr;
    Exit;
    End;
  If C^.Sync Then
    MKFlushHandle(FileRec(C^.F^).Handle);
  C^.Begun := True;
  C^.Gen := Gen;
  End;


Procedure CPoke(C: PMerCtx; Pos, Len: LongInt; Var Buf; NoBegin: Boolean);
  Var
    Old: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  If (Not NoBegin) And (Not C^.Begun) Then
    CBegin(C);
  If C^.Err <> 0 Then
    Exit;
  Old := 0;
  If Pos < C^.Phys Then
    Old := MerMin(Len, C^.Phys - Pos);
  CUndoAdd(C, Pos, Old);
  If C^.Err <> 0 Then
    Exit;
  If Not MerWr(C^.F^, Pos, Len, Buf) Then
    Begin
    C^.Err := merWriteErr;
    Exit;
    End;
  If Pos + Len > C^.Phys Then
    C^.Phys := Pos + Len;
  End;


Procedure CPokeL(C: PMerCtx; Pos: LongInt; V: LongInt);
  Begin
  CPoke(C, Pos, 4, V, False);
  End;


Procedure CFinish(C: PMerCtx; NewSize: LongInt; Changed: Boolean);
  {end of a write: give back the tail, then the base header (DIRTY cleared,
   Generation + 1) last}
  Begin
  If C^.Err <> 0 Then
    Exit;
  If (Not C^.Begun) And (Not Changed) Then
    Exit;
  If NewSize < C^.Phys Then
    Begin
    CUndoAdd(C, NewSize, C^.Phys - NewSize);
    If C^.Err <> 0 Then
      Exit;
    If Not MerTruncate(C^.F^, NewSize) Then
      Begin
      C^.Err := merWriteErr;
      Exit;
      End;
    C^.Phys := NewSize;
    End;
  If C^.Begun And C^.Sync Then
    MKFlushHandle(FileRec(C^.F^).Handle);
  If C^.Begun Then
    SetBaseExtra(C^.Base, FormatVer, BaseFlags(C^.Base) And (Not BfDirty), C^.Gen + 1)
  Else
    SetBaseExtra(C^.Base, FormatVer, BaseFlags(C^.Base) And (Not BfDirty), BaseGen(C^.Base) + 1);
  CPoke(C, 0, BaseLen, C^.Base, True);
  If (C^.Err = 0) And C^.Sync Then
    MKFlushHandle(FileRec(C^.F^).Handle);
  End;


Procedure CWriteEntry(C: PMerCtx; I: LongInt; Size, Pos: LongInt);
  Var
    E: MerlinFreeListType;

  Begin
  If C^.Err <> 0 Then
    Exit;
  C^.Free^[I].FrameSize := Size;
  C^.Free^[I].FramePos := Pos;
  E.FrameSize := Size;
  E.FramePos := Pos;
  CPoke(C, C^.FreePos + FH + I * Rec, Rec, E, False);
  End;


Procedure CAlloc(C: PMerCtx; Need: LongInt; Var OutPos, OutData: LongInt);
  {a frame with at least Need data bytes: the best fitting free frame (split
   if much is left), else the end of the file}
  Var
    Best: LongInt;
    i: LongInt;
    D: LongInt;
    RemPos: LongInt;
    RemData: LongInt;
    HdrRec: MerlinFrameHdrType;
    E: MerlinFreeListType;

  Begin
  OutPos := 0;
  OutData := 0;
  If C^.Err <> 0 Then
    Exit;
  Best := -1;
  For i := 0 To C^.FreeCnt - 1 Do
    If (C^.Free^[i].FramePos <> 0) And (C^.Free^[i].FrameSize >= Need) Then
      If (Best < 0) Or (C^.Free^[i].FrameSize < C^.Free^[Best].FrameSize) Then
        Best := i;
  D := (Need + 15) And (Not 15);
  If Best >= 0 Then
    Begin
    E := C^.Free^[Best];
    If E.FrameSize >= D + FH + SplitMin Then
      Begin                              {keep the rest as a free frame}
      RemPos := E.FramePos + FH + D;
      RemData := E.FrameSize - D - FH;
      MakeFrameHdr(HdrRec, mftFreeFrame, RemData, 0);
      CPoke(C, RemPos, FH, HdrRec, False);
      CWriteEntry(C, Best, RemData, RemPos);
      OutPos := E.FramePos;
      OutData := D;
      End
    Else
      Begin
      CWriteEntry(C, Best, 0, 0);
      OutPos := E.FramePos;
      OutData := E.FrameSize;
      End;
    End
  Else
    Begin
    OutPos := C^.Size;
    OutData := D;
    Inc(C^.Size, FH + D);
    End;
  End;


Procedure CFreeFrame(C: PMerCtx; Pos, DataSize: LongInt);
  {A frame is not used any more: merge it with free neighbours; at the end of
   the file give the space back.}
  Var
    Start: LongInt;
    Size: LongInt;
    Fi: LongInt;
    Pi: LongInt;
    Slot: LongInt;
    i: LongInt;
    OldPos: LongInt;
    OldData: LongInt;
    NewCap: LongInt;
    Pos2: LongInt;
    Data2: LongInt;
    Buf: PMerBytes;
    HdrRec: MerlinFrameHdrType;
    NewFree: PMerFreeArr;

  Begin
  If C^.Err <> 0 Then
    Exit;
  Start := Pos;
  Size := DataSize;
  Fi := -1;
  Pi := -1;
  For i := 0 To C^.FreeCnt - 1 Do
    If C^.Free^[i].FramePos <> 0 Then
      Begin
      If (Fi < 0) And (C^.Free^[i].FramePos = Pos + FH + DataSize) Then
        Fi := i;
      If (Pi < 0) And (C^.Free^[i].FramePos + FH + C^.Free^[i].FrameSize = Pos) Then
        Pi := i;
      End;
  If Fi >= 0 Then
    Inc(Size, FH + C^.Free^[Fi].FrameSize);
  If Pi >= 0 Then
    Begin
    Inc(Size, FH + C^.Free^[Pi].FrameSize);
    Start := C^.Free^[Pi].FramePos;
    End;
  If Start + FH + Size = C^.Size Then
    Begin                                {the end of the file: cut when done}
    C^.Size := Start;
    If Fi >= 0 Then
      CWriteEntry(C, Fi, 0, 0);
    If Pi >= 0 Then
      CWriteEntry(C, Pi, 0, 0);
    C^.Changed := True;
    Exit;
    End;
  If Pi >= 0 Then
    Slot := Pi
  Else
    Slot := Fi;
  If (Pi >= 0) And (Fi >= 0) Then
    CWriteEntry(C, Fi, 0, 0);
  If Slot < 0 Then
    Begin
    For i := 0 To C^.FreeCnt - 1 Do
      If (Slot < 0) And (C^.Free^[i].FramePos = 0) Then
        Slot := i;
    If Slot < 0 Then
      Begin                              {list full: a bigger one at the end}
      OldPos := C^.FreePos;
      OldData := C^.FreeData;
      NewCap := MerMax(32, C^.FreeCnt * 2);
      Data2 := NewCap * Rec;
      Pos2 := C^.Size;
      GetMem(Buf, FH + Data2);
      If Buf = Nil Then
        Begin
        C^.Err := merWriteErr;
        Exit;
        End;
      FillChar(Buf^, FH + Data2, 0);
      MakeFrameHdr(HdrRec, mftFreeList, Data2, Data2);
      Move(HdrRec, Buf^, FH);
      For i := 0 To C^.FreeCnt - 1 Do
        Begin
        MerPutL(Buf, FH + i * Rec, C^.Free^[i].FrameSize);
        MerPutL(Buf, FH + i * Rec + 4, C^.Free^[i].FramePos);
        End;
      CPoke(C, Pos2, FH + Data2, Buf^, False);
      GetMem(NewFree, NewCap * Rec);
      If NewFree = Nil Then
        Begin
        FreeMem(Buf, FH + Data2);
        C^.Err := merWriteErr;
        Exit;
        End;
      For i := 0 To NewCap - 1 Do
        Begin
        NewFree^[i].FrameSize := MerGetL(Buf, FH + i * Rec);
        NewFree^[i].FramePos := MerGetL(Buf, FH + i * Rec + 4);
        End;
      FreeMem(Buf, FH + Data2);
      If C^.Free <> Nil Then
        FreeMem(C^.Free, C^.FreeAlloc * Rec);
      C^.Free := NewFree;
      C^.FreeCnt := NewCap;
      C^.FreeAlloc := NewCap;
      Inc(C^.Size, FH + Data2);
      C^.FreePos := Pos2;
      C^.FreeData := Data2;
      C^.Base.FreePtr := Pos2;
      C^.Changed := True;
      CFreeFrame(C, Pos, DataSize);
      If OldPos <> 0 Then
        CFreeFrame(C, OldPos, OldData);  {old list is free space now}
      Exit;
      End;
    End;
  MakeFrameHdr(HdrRec, mftFreeFrame, Size, 0);
  CPoke(C, Start, FH, HdrRec, False);
  CWriteEntry(C, Slot, Size, Start);
  C^.Changed := True;
  End;


Procedure CSetSlot(C: PMerCtx; I: LongInt; Hash, Pos: LongInt);
  Var
    E: MerlinIdxType;

  Begin
  If C^.Err <> 0 Then
    Exit;
  If C^.IdxLen < (I + 1) * Rec Then
    Begin
    If Not MerGrow(C^.Idx, C^.IdxAlloc, (I + 1) * Rec) Then
      Begin
      C^.Err := merWriteErr;
      Exit;
      End;
    FillChar(C^.Idx^[C^.IdxLen], (I + 1) * Rec - C^.IdxLen, 0);
    C^.IdxLen := (I + 1) * Rec;
    End;
  MerPutL(C^.Idx, I * Rec, Hash);
  MerPutL(C^.Idx, I * Rec + 4, Pos);
  E.NameHash := Hash;
  E.FramePos := Pos;
  CPoke(C, C^.IdxPos + FH + I * Rec, Rec, E, False);
  C^.IdxChanged := True;
  End;


Procedure CEnsureSlots(C: PMerCtx; N: LongInt);
  Var
    NewCap: LongInt;
    Pos: LongInt;
    Data: LongInt;
    OldPos: LongInt;
    OldData: LongInt;
    Buf: PMerBytes;
    HdrRec: MerlinFrameHdrType;

  Begin
  If C^.Err <> 0 Then
    Exit;
  If N * Rec <= C^.IdxData Then
    Exit;
  NewCap := MerMax(N, (C^.IdxData Div Rec) * 2);
  NewCap := MerMax(NewCap, 64);
  If C^.Base.MaxMsgs > 0 Then
    NewCap := MerMax(NewCap, C^.Base.MaxMsgs + 16);
  CAlloc(C, NewCap * Rec, Pos, Data);
  If C^.Err <> 0 Then
    Exit;
  GetMem(Buf, FH + Data);
  If Buf = Nil Then
    Begin
    C^.Err := merWriteErr;
    Exit;
    End;
  FillChar(Buf^, FH + Data, 0);
  MakeFrameHdr(HdrRec, mftMsgIdx, Data, C^.IdxLen);
  Move(HdrRec, Buf^, FH);
  If C^.IdxLen > 0 Then
    Move(C^.Idx^, Buf^[FH], C^.IdxLen);
  CPoke(C, Pos, FH + Data, Buf^, False);
  FreeMem(Buf, FH + Data);
  OldPos := C^.IdxPos;
  OldData := C^.IdxData;
  C^.IdxPos := Pos;
  C^.IdxData := Data;
  C^.Base.IdxPtr := Pos;
  C^.Changed := True;
  CFreeFrame(C, OldPos, OldData);
  End;


Procedure CTrimHead(C: PMerCtx);
  {drop deleted records at the front of the index}
  Var
    K: LongInt;
    OldLen: LongInt;
    Buf: PMerBytes;

  Begin
  If C^.Err <> 0 Then
    Exit;
  K := 0;
  While (K * Rec < C^.IdxLen) And (MerGetL(C^.Idx, K * Rec + 4) = 0) Do
    Inc(K);
  If K = 0 Then
    Exit;
  OldLen := C^.IdxLen;
  Move(C^.Idx^[K * Rec], C^.Idx^[0], OldLen - K * Rec);
  C^.IdxLen := OldLen - K * Rec;
  Inc(C^.Base.BaseMsgId, K);
  C^.Base.DisplayMsgOffset := MerMax(0, C^.Base.BaseMsgId - 1);
  GetMem(Buf, OldLen);
  If Buf = Nil Then
    Begin
    C^.Err := merWriteErr;
    Exit;
    End;
  FillChar(Buf^, OldLen, 0);
  Move(C^.Idx^, Buf^, C^.IdxLen);
  CPoke(C, C^.IdxPos + FH, OldLen, Buf^, False);
  FreeMem(Buf, OldLen);
  C^.IdxChanged := True;
  C^.Changed := True;
  End;


Function CFrameOf(C: PMerCtx; Id: LongInt): LongInt;
  Var
    I: LongInt;

  Begin
  I := Id - C^.Base.BaseMsgId;
  If (I < 0) Or ((I + 1) * Rec > C^.IdxLen) Then
    CFrameOf := 0
  Else
    CFrameOf := MerGetL(C^.Idx, I * Rec + 4);
  End;


Procedure CCheckedFrame(C: PMerCtx; Id, Pos: LongInt; Var B: MerlinMsgHdrType);
  {read the message header at Pos; the index and the frame must agree}
  Var
    N: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  N := MerRd(C^.F^, Pos, MH, B);
  If (N < MH) Or (B.FrameHdr.FrameId <> mFrameId) Or (B.FrameHdr.FrameType <> mftMsg)
     Or (B.MsgNum <> Id) Then
    C^.Err := merDamaged;
  End;


Procedure CUnlinkReplies(C: PMerCtx; Id: LongInt; Var B: MerlinMsgHdrType);
  {take message Id out of its reply chain; its replies go to its parent}
  Var
    Parent: LongInt;
    First: LongInt;
    Next: LongInt;
    Kids: Array[0..4999] of LongInt;
    NKids: LongInt;
    Cur: LongInt;
    Hd: MerlinMsgHdrType;
    PHd: MerlinMsgHdrType;
    PPos: LongInt;
    At: LongInt;
    Walked: LongInt;
    Nx: LongInt;
    Linked: Boolean;
    i: LongInt;
    Zero: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  Zero := 0;
  Parent := B.ReplyTo;
  First := B.ReplyFirst;
  Next := B.ReplyNext;
  NKids := 0;
  Cur := First;
  While (Cur <> 0) And (CFrameOf(C, Cur) <> 0) And (Cur <> Id) And (NKids < 5000) Do
    Begin
    Kids[NKids] := Cur;
    Inc(NKids);
    CCheckedFrame(C, Cur, CFrameOf(C, Cur), Hd);
    If C^.Err <> 0 Then
      Exit;
    Cur := Hd.ReplyNext;
    End;
  Linked := False;
  PPos := 0;
  If (Parent <> 0) And (Parent <> Id) Then
    PPos := CFrameOf(C, Parent);
  If PPos <> 0 Then
    Begin
    CCheckedFrame(C, Parent, PPos, PHd);
    If C^.Err <> 0 Then
      Exit;
    At := -1;                            {where Id is stored in the parent's chain}
    If PHd.ReplyFirst = Id Then
      At := PPos + moReplyFirst
    Else
      Begin
      Walked := 0;
      Cur := PHd.ReplyFirst;
      While (Cur <> 0) And (CFrameOf(C, Cur) <> 0) And (Walked < 5000) And (At < 0) Do
        Begin
        Inc(Walked);
        CCheckedFrame(C, Cur, CFrameOf(C, Cur), Hd);
        If C^.Err <> 0 Then
          Exit;
        Nx := Hd.ReplyNext;
        If Nx = Id Then
          At := CFrameOf(C, Cur) + moReplyNext
        Else
          Cur := Nx;
        End;
      End;
    If At >= 0 Then
      Begin
      If NKids > 0 Then
        CPokeL(C, At, Kids[0])
      Else
        CPokeL(C, At, Next);
      If NKids > 0 Then
        CPokeL(C, CFrameOf(C, Kids[NKids - 1]) + moReplyNext, Next);
      For i := 0 To NKids - 1 Do
        CPokeL(C, CFrameOf(C, Kids[i]) + moReplyTo, Parent);
      Linked := True;
      End;
    End;
  If Not Linked Then
    For i := 0 To NKids - 1 Do           {no parent: replies become top level}
      Begin
      CPokeL(C, CFrameOf(C, Kids[i]) + moReplyTo, Zero);
      CPokeL(C, CFrameOf(C, Kids[i]) + moReplyNext, Zero);
      End;
  End;


Procedure CKill(C: PMerCtx; Id: LongInt; Unlink: Boolean);
  Var
    Pos: LongInt;
    B: MerlinMsgHdrType;
    NewAttr: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  Pos := CFrameOf(C, Id);
  If Pos = 0 Then
    Begin
    C^.Err := merNotFound;
    Exit;
    End;
  CCheckedFrame(C, Id, Pos, B);
  If C^.Err <> 0 Then
    Exit;
  If Unlink Then
    CUnlinkReplies(C, Id, B);
  NewAttr := B.Attr1 Or ma1Deleted;
  CPokeL(C, Pos + moAttr1, NewAttr);
  CSetSlot(C, Id - C^.Base.BaseMsgId, 0, 0);
  Dec(C^.Active);
  C^.Changed := True;
  C^.ExportTouched := True;
  CFreeFrame(C, Pos, B.FrameHdr.FrameDataSize);
  End;


Procedure CSetAttr(C: PMerCtx; Id: LongInt; SetMask, ClearMask: LongInt);
  {change the Attr1 of a message (and the flags in its index record)}
  Var
    Pos: LongInt;
    B: MerlinMsgHdrType;
    NewAttr: LongInt;
    Slot: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  Pos := CFrameOf(C, Id);
  If Pos = 0 Then
    Begin
    C^.Err := merNotFound;
    Exit;
    End;
  CCheckedFrame(C, Id, Pos, B);
  If C^.Err <> 0 Then
    Exit;
  NewAttr := (B.Attr1 Or SetMask) And (Not ClearMask);
  If NewAttr = B.Attr1 Then
    Exit;
  CPokeL(C, Pos + moAttr1, NewAttr);
  Slot := Id - C^.Base.BaseMsgId;
  CSetSlot(C, Slot, (MerGetL(C^.Idx, Slot * Rec) And HashMask) Or AttrBits(NewAttr), Pos);
  C^.Changed := True;
  C^.ExportTouched := True;
  End;


Procedure CLinkReply(C: PMerCtx; Parent, NewId: LongInt);
  {Add NewId at the end of the reply chain of Parent: Parent.ReplyFirst, then
   each reply's ReplyNext.  Problems here never fail the write.}
  Var
    PPos: LongInt;
    B: MerlinMsgHdrType;
    Cur: LongInt;
    Pos: LongInt;
    Guard: LongInt;
    N: LongInt;
    Done: Boolean;

  Begin
  If C^.Err <> 0 Then
    Exit;
  PPos := CFrameOf(C, Parent);
  If PPos = 0 Then
    Exit;
  N := MerRd(C^.F^, PPos, MH, B);
  If N < MH Then
    Exit;
  If (B.ReplyFirst = 0) Or (CFrameOf(C, B.ReplyFirst) = 0) Then
    Begin
    CPokeL(C, PPos + moReplyFirst, NewId);
    Exit;
    End;
  Cur := B.ReplyFirst;
  Done := False;
  Guard := 0;
  While (Not Done) And (Guard < 5000) And (C^.Err = 0) Do
    Begin
    Inc(Guard);
    Pos := CFrameOf(C, Cur);
    N := MerRd(C^.F^, Pos, MH, B);
    If N < MH Then
      Exit;
    If (B.ReplyNext = 0) Or (CFrameOf(C, B.ReplyNext) = 0) Then
      Begin
      CPokeL(C, Pos + moReplyNext, NewId);
      Done := True;
      End
    Else
      Cur := B.ReplyNext;
    End;
  End;


Procedure CCommit(C: PMerCtx);
  Var
    Lo: LongInt;
    i: LongInt;
    Want: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  If C^.IdxChanged Then
    CPokeL(C, C^.IdxPos + FH - 4, C^.IdxLen);       {FrameUsedSize of the index}
  If C^.ExportTouched Then
    Begin                                {LastMsgScanned: lowest to export - 1}
    Lo := -1;
    i := 0;
    While (i * Rec < C^.IdxLen) And (Lo < 0) Do
      Begin
      If (MerGetL(C^.Idx, i * Rec + 4) <> 0) And ((MerGetL(C^.Idx, i * Rec) And IxExport) <> 0) Then
        Lo := C^.Base.BaseMsgId + i;
      Inc(i);
      End;
    If Lo < 0 Then
      Want := C^.Base.LastMsgId
    Else
      Want := Lo - 1;
    If Want <> C^.Base.LastMsgScanned Then
      Begin
      C^.Base.LastMsgScanned := Want;
      C^.Changed := True;
      End;
    End;
  C^.Base.NumMsgs := C^.Active;
  CFinish(C, C^.Size, C^.Changed Or C^.IdxChanged);
  End;


Type
  PMerInfo = ^MerlinInfoType;


Function CNew(Var F: File; Sync: Boolean): PMerCtx;
  Var
    C: PMerCtx;

  Begin
  New(C);
  If C <> Nil Then
    Begin
    FillChar(C^, SizeOf(C^), 0);
    C^.F := @F;
    C^.Sync := Sync;
    End;
  CNew := C;
  End;


Procedure CDispose(C: PMerCtx);
  Begin
  If C = Nil Then
    Exit;
  If C^.Idx <> Nil Then
    FreeMem(C^.Idx, C^.IdxAlloc);
  If C^.Free <> Nil Then
    FreeMem(C^.Free, C^.FreeAlloc * Rec);
  If C^.Undo <> Nil Then
    FreeMem(C^.Undo, C^.UndoAlloc);
  Dispose(C);
  End;


Procedure CMake(C: PMerCtx);
  {read the base header, index and free list of the file into the context}
  Var
    N: LongInt;
    Size0: LongInt;
    Ih: MerlinFrameHdrType;
    Fl: MerlinFrameHdrType;
    Slots: Int64;
    i: LongInt;
    FB: PMerBytes;
    FBLen: LongInt;

  Begin
  If C^.Err <> 0 Then
    Exit;
  C^.NeedRepair := False;
  Size0 := C^.Phys;
  N := MerRd(C^.F^, 0, BaseLen, C^.Base);
  If N < 0 Then
    Begin
    C^.Err := merReadErr;
    Exit;
    End;
  If (N < BaseLen) Or (C^.Base.FrameHdr.FrameId <> mFrameId) Or
     (C^.Base.FrameHdr.FrameType <> mftMsgBaseHdr) Then
    Begin
    C^.Err := merNotMerlin;
    Exit;
    End;
  If BaseVersion(C^.Base) > FormatVer Then
    Begin
    C^.Err := merNewVersion;
    Exit;
    End;
  If (BaseFlags(C^.Base) And BfDirty) <> 0 Then
    Begin
    C^.NeedRepair := True;               {a previous write was interrupted}
    Exit;
    End;
  If BaseVersion(C^.Base) < 1 Then
    Begin
    C^.NeedRepair := True;               {the version 0 layout}
    Exit;
    End;
  If (C^.Base.IdxPtr < BaseLen) Or (C^.Base.IdxPtr + FH > Size0) Then
    Begin
    C^.Err := merDamaged;
    Exit;
    End;
  N := MerRd(C^.F^, C^.Base.IdxPtr, FH, Ih);
  If (N < FH) Or (Ih.FrameId <> mFrameId) Or (Ih.FrameType <> mftMsgIdx) Or
     (Int64(C^.Base.IdxPtr) + FH + Ih.FrameDataSize > Size0) Then
    Begin
    C^.Err := merDamaged;
    Exit;
    End;
  Slots := Int64(C^.Base.LastMsgId) + 1 - C^.Base.BaseMsgId;
  If (Slots < 0) Or (Slots * Rec > Ih.FrameDataSize) Then
    Begin
    C^.Err := merDamaged;
    Exit;
    End;
  C^.IdxLen := Slots * Rec;
  If Not MerGrow(C^.Idx, C^.IdxAlloc, C^.IdxLen + 16) Then
    Begin
    C^.Err := merReadErr;
    Exit;
    End;
  If C^.IdxLen > 0 Then
    If MerRd(C^.F^, C^.Base.IdxPtr + FH, C^.IdxLen, C^.Idx^) <> C^.IdxLen Then
      Begin
      C^.Err := merReadErr;
      Exit;
      End;
  C^.IdxPos := C^.Base.IdxPtr;
  C^.IdxData := Ih.FrameDataSize;
  C^.FreePos := C^.Base.FreePtr;
  C^.FreeData := 0;
  C^.FreeCnt := 0;
  If C^.Base.FreePtr <> 0 Then
    Begin
    If (C^.Base.FreePtr < BaseLen) Or (C^.Base.FreePtr + FH > Size0) Then
      Begin
      C^.Err := merDamaged;
      Exit;
      End;
    N := MerRd(C^.F^, C^.Base.FreePtr, FH, Fl);
    If (N < FH) Or (Fl.FrameId <> mFrameId) Or (Fl.FrameType <> mftFreeList) Or
       (Int64(C^.Base.FreePtr) + FH + Fl.FrameDataSize > Size0) Then
      Begin
      C^.Err := merDamaged;
      Exit;
      End;
    C^.FreeData := Fl.FrameDataSize;
    C^.FreeCnt := Fl.FrameDataSize Div Rec;
    FBLen := C^.FreeCnt * Rec;
    C^.FreeAlloc := MerMax(C^.FreeCnt, 1);
    GetMem(C^.Free, C^.FreeAlloc * Rec);
    GetMem(FB, MerMax(FBLen, 1));
    If (C^.Free = Nil) Or (FB = Nil) Then
      Begin
      C^.Err := merReadErr;
      Exit;
      End;
    If FBLen > 0 Then
      If MerRd(C^.F^, C^.Base.FreePtr + FH, FBLen, FB^) <> FBLen Then
        C^.Err := merReadErr;
    If C^.Err = 0 Then
      For i := 0 To C^.FreeCnt - 1 Do
        Begin
        C^.Free^[i].FrameSize := MerGetL(FB, i * Rec);
        C^.Free^[i].FramePos := MerGetL(FB, i * Rec + 4);
        If (C^.Free^[i].FramePos <> 0) And ((C^.Free^[i].FramePos < BaseLen) Or
           (Int64(C^.Free^[i].FramePos) + FH + C^.Free^[i].FrameSize > Size0)) Then
          C^.Err := merDamaged;
        End;
    FreeMem(FB, MerMax(FBLen, 1));
    If C^.Err <> 0 Then
      Exit;
    End;
  C^.Gen := BaseGen(C^.Base);
  C^.Size := Size0;
  C^.Active := 0;
  For i := 0 To Slots - 1 Do
    If MerGetL(C^.Idx, i * Rec + 4) <> 0 Then
      Inc(C^.Active);
  End;


{---------------------------------------------------------- subfields}

Function PutSub(Var Buf: PMerBytes; Var Len, Alloc: LongInt; Typ: LongInt;
  Var Data; DLen: LongInt): Boolean;
  {append one subfield (type, length, data) to Buf}
  Begin
  PutSub := False;
  If Not MerGrow(Buf, Alloc, Len + 8 + DLen) Then
    Exit;
  MerPutL(Buf, Len, Typ);
  MerPutL(Buf, Len + 4, DLen);
  If DLen > 0 Then
    Move(Data, Buf^[Len + 8], DLen);
  Inc(Len, 8 + DLen);
  PutSub := True;
  End;


Function PutSubStr(Var Buf: PMerBytes; Var Len, Alloc: LongInt; Typ: LongInt;
  S: String): Boolean;
  Begin
  If Length(S) > 0 Then
    PutSubStr := PutSub(Buf, Len, Alloc, Typ, S[1], Length(S))
  Else
    PutSubStr := PutSub(Buf, Len, Alloc, Typ, Len, 0);
  End;


Function FitName(S: String; Utf8: Boolean): String;
  {control characters become blanks; at most MaxName bytes, a UTF-8
   character is not cut in half}
  Var
    i: Word;
    Cut: Word;

  Begin
  For i := 1 To Length(S) Do
    If S[i] < ' ' Then
      S[i] := ' ';
  If Length(S) > MaxName Then
    Begin
    Cut := MaxName;
    If Utf8 Then
      While (Cut > 0) And ((Ord(S[Cut + 1]) And $C0) = $80) Do
        Dec(Cut);
    S[0] := Chr(Cut);
    End;
  FitName := S;
  End;


Function AddrText(Var A: AddrType): String;
  Var
    S: String;
    T: String;

  Begin
  S := '';
  If A.Zone <> 0 Then
    Begin
    Str(A.Zone, T);
    S := T + ':';
    End;
  Str(A.Net, T);
  S := S + T + '/';
  Str(A.Node, T);
  S := S + T;
  If A.Point <> 0 Then
    Begin
    Str(A.Point, T);
    S := S + '.' + T;
    End;
  AddrText := S;
  End;


Function AddrUsed(Var A: AddrType): Boolean;
  Begin
  AddrUsed := (A.Zone Or A.Net Or A.Node Or A.Point) <> 0;
  End;


Procedure ParseAddr(S: String; Var A: AddrType);
  {"zone:net/node[.point][@domain]"}
  Var
    i: Word;
    N: LongInt;
    Part: Word;
    Nums: Array[1..4] of LongInt;
    HasZone: Boolean;
    HaveNum: Boolean;

  Begin
  FillChar(A, SizeOf(A), 0);
  FillChar(Nums, SizeOf(Nums), 0);
  N := 0;
  HaveNum := False;
  HasZone := Pos(':', S) > 0;
  Part := 1;
  i := 1;
  If Not HasZone Then
    Part := 2;
  While (i <= Length(S)) And (S[i] <> '@') Do
    Begin
    If (S[i] >= '0') And (S[i] <= '9') Then
      Begin
      N := N * 10 + Ord(S[i]) - 48;
      HaveNum := True;
      If N > $FFFF Then
        N := $FFFF;
      End
    Else
      Begin
      If HaveNum And (Part <= 4) Then
        Nums[Part] := N;
      N := 0;
      HaveNum := False;
      If S[i] = ':' Then
        Part := 2
      Else If S[i] = '/' Then
        Part := 3
      Else If S[i] = '.' Then
        Part := 4;
      End;
    Inc(i);
    End;
  If HaveNum And (Part <= 4) Then
    Nums[Part] := N;
  A.Zone := Nums[1];
  A.Net := Nums[2];
  A.Node := Nums[3];
  A.Point := Nums[4];
  End;


Function CharsetKnown(S: String): Boolean;
  Var
    U: String;
    T: String;
    i: Word;

  Begin
  T := '';
  For i := 1 To Length(S) Do
    If UpCase(S[i]) In ['A'..'Z', '0'..'9'] Then
      T := T + UpCase(S[i]);
  U := T;
  CharsetKnown := (U = 'UTF8') Or (U = 'CP437') Or (U = 'IBM437') Or (U = 'IBMPC') Or
    (U = '437') Or (U = 'LATIN1') Or (U = 'ISO88591') Or (U = 'CP819') Or (U = 'ASCII');
  End;


Function CharsetIsUtf8(S: String): Boolean;
  Var
    T: String;
    i: Word;

  Begin
  T := '';
  For i := 1 To Length(S) Do
    If UpCase(S[i]) In ['A'..'Z', '0'..'9'] Then
      T := T + UpCase(S[i]);
  CharsetIsUtf8 := (T = 'UTF8');
  End;


Function KludgePrefix(Typ: LongInt): String;
  {how a kludge subfield is shown in the message text (after the ^A)}
  Begin
  Case Typ Of
    sfMsgId:   KludgePrefix := 'MSGID: ';
    sfReplyId: KludgePrefix := 'REPLY: ';
    sfPID:     KludgePrefix := 'PID: ';
    sfVia:     KludgePrefix := 'Via ';
    sfSeenby:  KludgePrefix := 'SEEN-BY: ';
    sfPath:    KludgePrefix := 'PATH: ';
    sfFlags:   KludgePrefix := 'FLAGS ';
    Else       KludgePrefix := '';
    End;
  End;


Function IsKludgeSub(Typ: LongInt): Boolean;
  Begin
  IsKludgeSub := (Typ = sfMsgId) Or (Typ = sfReplyId) Or (Typ = sfPID) Or (Typ = sfVia) Or
    (Typ = sfSeenby) Or (Typ = sfPath) Or (Typ = sfFlags) Or (Typ = sfKludge);
  End;


Function BufHasPrefix(P: PMerBytes; Len: LongInt; Pre: String): Boolean;
  {case-insensitive prefix test}
  Var
    i: Word;

  Begin
  BufHasPrefix := False;
  If Len < Length(Pre) Then
    Exit;
  For i := 1 To Length(Pre) Do
    If LoCase(Chr(P^[i - 1])) <> LoCase(Pre[i]) Then
      Exit;
  BufHasPrefix := True;
  End;


Function KludgeType(P: PMerBytes; Len: LongInt; Var VOfs: LongInt): LongInt;
  {which subfield a kludge line (without the ^A) belongs in, and where its
   value starts}
  Var
    Typ: LongInt;
    PLen: LongInt;

  Procedure SkipBlanks;
    Begin
    While (VOfs < Len) And ((P^[VOfs] = 32) Or (P^[VOfs] = 9)) Do
      Inc(VOfs);
    End;

  Begin
  Typ := sfKludge;
  VOfs := 0;
  PLen := 0;
  If BufHasPrefix(P, Len, 'MSGID:') Then
    Begin Typ := sfMsgId; PLen := 6; End
  Else If BufHasPrefix(P, Len, 'REPLY:') Then
    Begin Typ := sfReplyId; PLen := 6; End
  Else If BufHasPrefix(P, Len, 'PID:') Then
    Begin Typ := sfPID; PLen := 4; End
  Else If BufHasPrefix(P, Len, 'SEEN-BY:') Then
    Begin Typ := sfSeenby; PLen := 8; End
  Else If BufHasPrefix(P, Len, 'PATH:') Then
    Begin Typ := sfPath; PLen := 5; End
  Else If BufHasPrefix(P, Len, 'VIA') And (Len > 3) And ((P^[3] = 32) Or (P^[3] = 9)) Then
    Begin Typ := sfVia; PLen := 3; End
  Else If BufHasPrefix(P, Len, 'FLAGS') And (Len > 5) And ((P^[5] = 32) Or (P^[5] = 9)) Then
    Begin Typ := sfFlags; PLen := 5; End;
  VOfs := PLen;
  If Typ <> sfKludge Then
    SkipBlanks;
  KludgeType := Typ;
  End;


Function TzFromKludge(P: PMerBytes; Len: LongInt; Var Minutes: LongInt): Boolean;
  {"TZUTC: -0500" -> minutes east of UTC}
  Var
    i: LongInt;
    Neg: Boolean;
    V: LongInt;
    j: Word;

  Begin
  TzFromKludge := False;
  If Not BufHasPrefix(P, Len, 'TZUTC') Then
    Exit;
  i := 5;
  If (i < Len) And (P^[i] = Ord(':')) Then
    Inc(i);
  While (i < Len) And ((P^[i] = 32) Or (P^[i] = 9)) Do
    Inc(i);
  Neg := False;
  If (i < Len) And ((P^[i] = Ord('+')) Or (P^[i] = Ord('-'))) Then
    Begin
    Neg := (P^[i] = Ord('-'));
    Inc(i);
    End;
  If i + 4 > Len Then
    Exit;
  For j := 0 To 3 Do
    If (P^[i + j] < 48) Or (P^[i + j] > 57) Then
      Exit;
  V := (P^[i] - 48) * 600 + (P^[i + 1] - 48) * 60 + (P^[i + 2] - 48) * 10 + (P^[i + 3] - 48);   {hh*60 + mm}
  If Neg Then
    V := -V;
  Minutes := V;
  TzFromKludge := True;
  End;


{-------------------------------------------- check / repair (forward)}

Function RepairIn(Inf: PMerInfo; C: PMerCtx; OnlyIfNeeded: Boolean;
  Var Fixed: Boolean): Boolean; Forward;
Function CheckIn(Inf: PMerInfo; C: PMerCtx): Boolean; Forward;


{----------------------------------------------------- the object itself}

Constructor MerlinMsgObj.Init;         { allocate memory and initialize }
  Begin
  New(MInfo);
  If MInfo = Nil Then
    Begin
    Fail;
    Exit;
    End;
  FillChar(MInfo^, SizeOf(MInfo^), #0);
  MInfo^.Charset := 'UTF-8';
  MInfo^.MailType := mmtNormal;
  MInfo^.AutoRepair := True;
  MInfo^.Sync := True;
  MInfo^.LinkReplies := True;
  MInfo^.UnlinkOnDelete := True;
  MInfo^.DirtyWaitMs := 400;
  MInfo^.LockTimeoutMs := 5000;
  MInfo^.Cur := 0;
  LastSoft := False;
  End;


Destructor MerlinMsgObj.Done;
  Begin
  If MInfo^.BaseOpened Then
    If CloseMsgBase = 0 Then;
  If MInfo^.Ids <> Nil Then
    FreeMem(MInfo^.Ids, MInfo^.IdCap * SizeOf(MerIdxEnt));
  If MInfo^.TxtBuf <> Nil Then
    FreeMem(MInfo^.TxtBuf, MInfo^.TxtLen + 1);
  If MInfo^.WBuf <> Nil Then
    FreeMem(MInfo^.WBuf, MInfo^.WCap);
  Dispose(MInfo);
  End;


Procedure MerlinMsgObj.SetMsgPath(MP: String); {the message base file, as given}
  Begin
  If MInfo^.BaseOpened Then
    If CloseMsgBase = 0 Then;
  MInfo^.FN := MP;
  End;


Function MerlinMsgObj.MsgBaseExists: Boolean;
  Begin
  MsgBaseExists := (Length(MInfo^.FN) > 0) And FileExist(MInfo^.FN);
  End;


Procedure MerlinMsgObj.SetCharset(Name: String);
  Begin
  MInfo^.Charset := Copy(Name, 1, 16);
  End;


Function MerlinMsgObj.GetCharset: String;
  Begin
  GetCharset := MInfo^.MsgCharset;
  End;


Procedure MerlinMsgObj.SetUtcOffset(Minutes: LongInt);
  Begin
  MInfo^.UtcOff := Minutes;
  MInfo^.UtcSet := True;
  End;


Function MerlinMsgObj.GetUtcOffset: LongInt;
  Begin
  If MInfo^.UtcSet Then
    GetUtcOffset := MInfo^.UtcOff
  Else
    GetUtcOffset := MKLocalUtcOffset;
  End;


Procedure MerlinMsgObj.SetAutoRepair(On: Boolean);
  Begin
  MInfo^.AutoRepair := On;
  End;


Procedure MerlinMsgObj.SetSync(On: Boolean);
  Begin
  MInfo^.Sync := On;
  End;


Procedure MerlinMsgObj.SetMailType(MT: MsgMailType);
  Begin
  MInfo^.MailType := MT;
  End;


Function MerlinMsgObj.GetSubArea: Word;
  Begin
  GetSubArea := 0;
  End;


{------------------------------------------------------------- locking}

Function MerlinMsgObj.GetLock: Word;
  {the byte lock at $FFFFFFFF; waits up to LockTimeoutMs}
  Var
    Waited: LongInt;
    Code: Word;

  Begin
  Waited := 0;
  GetLock := 0;
  Repeat
    Code := MKLockRegion(FileRec(MInfo^.MsgFile).Handle, LockStart, LockLen, True);
    If Code = mkLockOk Then
      Begin
      MInfo^.Locked := True;
      Exit;
      End;
    If Code <> mkLockViolation Then
      Begin
      GetLock := merWriteErr;
      Exit;
      End;
    If Waited >= MInfo^.LockTimeoutMs Then
      Begin
      GetLock := merLockTimeout;
      Exit;
      End;
    MKDelay(25);
    Inc(Waited, 25);
  Until False;
  End;


Procedure MerlinMsgObj.ReleaseLock;
  Begin
  If MInfo^.Locked Then
    Begin
    MKLockRegion(FileRec(MInfo^.MsgFile).Handle, LockStart, LockLen, False);
    MInfo^.Locked := False;
    End;
  End;


Function MerlinMsgObj.LockMsgBase: Boolean;
  {Hold the write lock across several operations.  Each writer takes the
   lock by itself when you have not; nesting is counted.}
  Var
    Code: Word;

  Begin
  LockMsgBase := False;
  MInfo^.Error := 0;
  If Not MInfo^.BaseOpened Then
    MInfo^.Error := merNotOpen
  Else If MInfo^.ReadOnly Then
    MInfo^.Error := merWriteErr
  Else If MInfo^.LockCount = 0 Then
    Begin
    Code := GetLock;
    MInfo^.Error := Code;
    End;
  If MInfo^.Error = 0 Then
    Begin
    Inc(MInfo^.LockCount);
    LockMsgBase := True;
    End;
  End;


Function MerlinMsgObj.UnLockMsgBase: Boolean;
  Begin
  UnLockMsgBase := False;
  MInfo^.Error := 0;
  If MInfo^.LockCount <= 0 Then
    MInfo^.Error := 5
  Else
    Begin
    Dec(MInfo^.LockCount);
    If MInfo^.LockCount = 0 Then
      ReleaseLock;
    UnLockMsgBase := True;
    End;
  End;


{-------------------------------------------------- create / open / close}

Function MerlinMsgObj.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word;
  {Create an empty base: base header, an index frame with room for
   max(MaxMsg, 64) messages and a free list for 32 free frames (both grow by
   themselves).  MaxMsg is MaxMsgs, 0 = no limit.  MaxDays has no place in
   the header and is ignored.}
  Var
    Cap: LongInt;
    Head: MerlinMsgBaseHdrType;
    FHdr: MerlinFrameHdrType;
    Zeros: Array[0..4095] of Byte;
    Left: LongInt;
    N: LongInt;
    F: File;
    Err: Word;
    D: DirStr;
    Nm: NameStr;
    Ex: ExtStr;

  Begin
  Err := 0;
  If Length(MInfo^.FN) = 0 Then
    Err := merNoPath
  Else If FileExist(MInfo^.FN) Then
    Err := merExists;
  If Err = 0 Then
    Begin
    FSplit(MInfo^.FN, D, Nm, Ex);
    If Length(D) > 0 Then
      If Not MakePath(D) Then
        Err := merWriteErr;
    End;
  If Err = 0 Then
    Begin
    Cap := MerMax(64, MaxMsg);
    FillChar(Zeros, SizeOf(Zeros), 0);
    FillChar(Head, SizeOf(Head), 0);
    MakeFrameHdr(Head.FrameHdr, mftMsgBaseHdr, BaseLen, BaseLen);
    Head.IdxPtr := BaseLen;
    Head.FreePtr := BaseLen + FH + Cap * Rec;
    Head.MaxMsgs := MaxMsg;
    Head.BaseMsgId := 1;
    Head.DateCreated := MerUtcNow;
    SetBaseExtra(Head, FormatVer, 0, 1);
    Assign(F, MInfo^.FN);
    FileMode := fmReadWrite + fmDenyNone;
    ReWrite(F, 1);
    Err := IoResult;
    End;
  If Err = 0 Then
    Begin
    BlockWrite(F, Head, BaseLen, N);
    Err := IoResult;
    MakeFrameHdr(FHdr, mftMsgIdx, Cap * Rec, 0);
    If Err = 0 Then
      Begin
      BlockWrite(F, FHdr, FH, N);
      Err := IoResult;
      End;
    Left := Cap * Rec;
    While (Err = 0) And (Left > 0) Do
      Begin
      BlockWrite(F, Zeros, MerMin(Left, SizeOf(Zeros)), N);
      Err := IoResult;
      Dec(Left, SizeOf(Zeros));
      End;
    MakeFrameHdr(FHdr, mftFreeList, 32 * Rec, 32 * Rec);
    If Err = 0 Then
      Begin
      BlockWrite(F, FHdr, FH, N);
      Err := IoResult;
      End;
    If Err = 0 Then
      Begin
      BlockWrite(F, Zeros, 32 * Rec, N);
      Err := IoResult;
      End;
    Close(F);
    If Err = 0 Then
      Err := IoResult
    Else If IoResult <> 0 Then;
    End;
  MInfo^.Error := Err;
  CreateMsgBase := Err;
  End;


Function MerlinMsgObj.OpenMsgBase: Word;
  Var
    Err: Word;

  Begin
  MInfo^.Error := 0;
  If Length(MInfo^.FN) = 0 Then
    MInfo^.Error := merNoPath
  Else If Not FileExist(MInfo^.FN) Then
    MInfo^.Error := merNotFound;
  If (MInfo^.Error = 0) And MInfo^.BaseOpened Then
    If CloseMsgBase <> 0 Then;
  If MInfo^.Error = 0 Then
    Begin
    MInfo^.ReadOnly := False;
    Assign(MInfo^.MsgFile, MInfo^.FN);
    FileMode := fmReadWrite + fmDenyNone;
    Reset(MInfo^.MsgFile, 1);
    Err := IoResult;
    If Err <> 0 Then
      Begin                              {not writable: readers can still go on}
      FileMode := fmReadOnly + fmDenyNone;
      Reset(MInfo^.MsgFile, 1);
      Err := IoResult;
      MInfo^.ReadOnly := (Err = 0);
      End;
    MInfo^.Error := Err;
    End;
  If MInfo^.Error = 0 Then
    Begin
    MInfo^.BaseOpened := True;
    MInfo^.StampOk := False;
    MInfo^.Found := False;
    MInfo^.Cur := 0;
    MInfo^.LockCount := 0;
    MInfo^.Locked := False;
    Err := LoadAll(MInfo^.AutoRepair And (Not MInfo^.ReadOnly));
    If Err <> 0 Then
      Begin
      MInfo^.BaseOpened := False;
      Close(MInfo^.MsgFile);
      If IoResult <> 0 Then;
      MInfo^.Error := Err;
      End;
    End;
  OpenMsgBase := MInfo^.Error;
  End;


Function MerlinMsgObj.CloseMsgBase: Word;
  Begin
  MInfo^.Error := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.LockCount := 0;
    ReleaseLock;
    Close(MInfo^.MsgFile);
    MInfo^.Error := IoResult;
    MInfo^.BaseOpened := False;
    End;
  MInfo^.StampOk := False;
  MInfo^.Found := False;
  MInfo^.IdCount := 0;
  If MInfo^.TxtBuf <> Nil Then
    Begin
    FreeMem(MInfo^.TxtBuf, MInfo^.TxtLen + 1);
    MInfo^.TxtBuf := Nil;
    MInfo^.TxtLen := 0;
    End;
  CloseMsgBase := MInfo^.Error;
  End;


{------------------------------------------------------ reading the file}

Function MerlinMsgObj.ReadAt(Pos, Len: LongInt; Var Buf): LongInt;
  Begin
  ReadAt := MerRd(MInfo^.MsgFile, Pos, Len, Buf);
  End;


Function MerlinMsgObj.LowerBound(V: LongInt): LongInt;
  {first active message numbered V or higher}
  Var
    Lo: LongInt;
    Hi: LongInt;
    Mid: LongInt;

  Begin
  Lo := 0;
  Hi := MInfo^.IdCount;
  While Lo < Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If MInfo^.Ids^[Mid].Id < V Then
      Lo := Mid + 1
    Else
      Hi := Mid;
    End;
  LowerBound := Lo;
  End;


Function MerlinMsgObj.UpperBound(V: LongInt): LongInt;
  {first active message numbered higher than V}
  Var
    Lo: LongInt;
    Hi: LongInt;
    Mid: LongInt;

  Begin
  Lo := 0;
  Hi := MInfo^.IdCount;
  While Lo < Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If MInfo^.Ids^[Mid].Id <= V Then
      Lo := Mid + 1
    Else
      Hi := Mid;
    End;
  UpperBound := Lo;
  End;


Function MerlinMsgObj.LoadOnce(IgnoreDirty: Boolean; Var Retry: Boolean): Word;
  {One attempt at reading the base header, the index and the header again.
   Retry is set if a writer was busy in between.}
  Var
    H1: MerlinMsgBaseHdrType;
    H2: MerlinMsgBaseHdrType;
    Ih: MerlinFrameHdrType;
    N: LongInt;
    Size: LongInt;
    Slots: Int64;
    IdxB: PMerBytes;
    IdxLen: LongInt;
    Active: LongInt;
    i: LongInt;
    K: LongInt;
    Pos: LongInt;
    Problem: Boolean;
    T: LongInt;

  Begin
  Retry := False;
  LoadOnce := 0;
  Size := FileSize(MInfo^.MsgFile);
  N := ReadAt(0, BaseLen, H1);
  If N < 0 Then
    Begin
    LoadOnce := merReadErr;
    Exit;
    End;
  If (N < BaseLen) Or (H1.FrameHdr.FrameId <> mFrameId) Or (H1.FrameHdr.FrameType <> mftMsgBaseHdr) Then
    Begin
    LoadOnce := merNotMerlin;
    Exit;
    End;
  If BaseVersion(H1) > FormatVer Then
    Begin
    LoadOnce := merNewVersion;
    Exit;
    End;
  If ((BaseFlags(H1) And BfDirty) <> 0) And (Not IgnoreDirty) Then
    Begin
    Retry := True;
    MInfo^.Base := H1;
    Exit;
    End;
  Problem := False;
  IdxB := Nil;
  IdxLen := 0;
  Slots := Int64(H1.LastMsgId) + 1 - H1.BaseMsgId;
  If H1.IdxPtr >= BaseLen Then
    N := ReadAt(H1.IdxPtr, FH, Ih)
  Else
    N := 0;
  If (N < FH) Or (Ih.FrameId <> mFrameId) Or (Ih.FrameType <> mftMsgIdx) Then
    Problem := True
  Else If (Slots < 0) Or (Slots * Rec > Ih.FrameDataSize) Then
    Problem := True
  Else
    Begin
    IdxLen := Slots * Rec;
    GetMem(IdxB, MerMax(IdxLen, 1));
    If IdxB = Nil Then
      Begin
      LoadOnce := merReadErr;
      Exit;
      End;
    If IdxLen > 0 Then
      If ReadAt(H1.IdxPtr + FH, IdxLen, IdxB^) <> IdxLen Then
        Problem := True;
    End;
  If Not Problem Then
    Begin
    N := ReadAt(0, BaseLen, H2);
    If (N <> BaseLen) Or ((Not IgnoreDirty) And (CompareByte(H1, H2, BaseLen) <> 0)) Then
      Begin
      If N <> BaseLen Then
        Problem := True
      Else
        Retry := True;
      End;
    End;
  If Problem Or Retry Then
    Begin
    If IdxB <> Nil Then
      FreeMem(IdxB, MerMax(IdxLen, 1));
    If Problem Then
      LoadOnce := merDamaged;
    Exit;
    End;
  { accept: build the in-memory list of active messages }
  Active := 0;
  For i := 0 To Slots - 1 Do
    If MerGetL(IdxB, i * Rec + 4) >= BaseLen Then
      Inc(Active);
  If MInfo^.Ids <> Nil Then
    FreeMem(MInfo^.Ids, MInfo^.IdCap * SizeOf(MerIdxEnt));
  MInfo^.IdCap := MerMax(Active, 1);
  GetMem(MInfo^.Ids, MInfo^.IdCap * SizeOf(MerIdxEnt));
  K := 0;
  For i := 0 To Slots - 1 Do
    Begin
    Pos := MerGetL(IdxB, i * Rec + 4);
    If Pos >= BaseLen Then
      Begin
      MInfo^.Ids^[K].Id := H1.BaseMsgId + i;
      MInfo^.Ids^[K].Pos := Pos;
      MInfo^.Ids^[K].Hash := MerGetL(IdxB, i * Rec);
      Inc(K);
      End;
    End;
  MInfo^.IdCount := K;
  If IdxB <> Nil Then
    FreeMem(IdxB, MerMax(IdxLen, 1));
  MInfo^.Base := H1;
  MInfo^.BaseDirty := ((BaseFlags(H1) And BfDirty) <> 0);
  MInfo^.StampOk := Not MInfo^.BaseDirty;
  MInfo^.StampSize := Size;
  MInfo^.StampGen := BaseGen(H1);
  T := 0;
  GetFTime(MInfo^.MsgFile, T);
  MInfo^.StampTime := T;
  End;


Function MerlinMsgObj.LoadAll(RepairOnDirty: Boolean): Word;
  Var
    Err: Word;
    Retry: Boolean;
    Waited: LongInt;
    Attempts: LongInt;
    Dirty: Boolean;
    Fixed: Boolean;

  Begin
  Waited := 0;
  Attempts := 0;
  Dirty := False;
  Repeat
    Err := LoadOnce(False, Retry);
    If Err <> 0 Then
      Begin
      LoadAll := Err;
      Exit;
      End;
    If Not Retry Then
      Break;
    If (BaseFlags(MInfo^.Base) And BfDirty) <> 0 Then
      Begin                              {a writer is working (or died)}
      If Waited >= MInfo^.DirtyWaitMs Then
        Begin
        Dirty := True;
        Break;
        End;
      MKDelay(10);
      Inc(Waited, 10);
      End
    Else
      Begin
      Inc(Attempts);
      If Attempts > 200 Then
        Begin
        LoadAll := merChanging;
        Exit;
        End;
      End;
  Until False;
  If Dirty And RepairOnDirty And (Not MInfo^.ReadOnly) Then
    Begin
    If Repair Then
      Begin
      LoadAll := LoadAll(False);
      Exit;
      End;
    End;
  If Dirty Then
    Begin                                {read what is there, leniently}
    Err := LoadOnce(True, Retry);
    If Err <> 0 Then
      Begin
      LoadAll := Err;
      Exit;
      End;
    MInfo^.BaseDirty := True;
    MInfo^.StampOk := False;
    End;
  LoadAll := 0;
  End;


Function MerlinMsgObj.Fresh: Word;
  {Reload the index only if the base changed since it was loaded: one 132 byte
   read tells.}
  Var
    H: MerlinMsgBaseHdrType;
    N: LongInt;
    Size: LongInt;
    T: LongInt;
    Same: Boolean;

  Begin
  Fresh := 0;
  If MInfo^.StampOk Then
    Begin
    Size := FileSize(MInfo^.MsgFile);
    N := ReadAt(0, BaseLen, H);
    If (N = BaseLen) And (H.FrameHdr.FrameId = mFrameId) And
       ((BaseFlags(H) And BfDirty) = 0) And (Size = MInfo^.StampSize) Then
      Begin
      If BaseVersion(H) >= 1 Then
        Same := (BaseGen(H) = MInfo^.StampGen)
      Else
        Begin
        T := 0;
        GetFTime(MInfo^.MsgFile, T);
        Same := (T = MInfo^.StampTime) And (CompareByte(H, MInfo^.Base, BaseLen) = 0);
        End;
      If Same Then
        Exit;
      End;
    End;
  Fresh := LoadAll(False);
  End;


Procedure MerlinMsgObj.Refresh;
  Begin
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.StampOk := False;
    MInfo^.Error := Fresh;
    End;
  End;


Procedure MerlinMsgObj.ClearMsg;
  {forget the current message}
  Begin
  FillChar(MInfo^.Hdr, SizeOf(MInfo^.Hdr), 0);
  MInfo^.MsgFrom := '';
  MInfo^.MsgTo := '';
  MInfo^.MsgSubj := '';
  MInfo^.MsgDate := '';
  MInfo^.MsgTime := '';
  MInfo^.MsgCharset := '';
  FillChar(MInfo^.Orig, SizeOf(MInfo^.Orig), 0);
  FillChar(MInfo^.Dest, SizeOf(MInfo^.Dest), 0);
  MInfo^.HaveOrig := False;
  MInfo^.HaveDest := False;
  MInfo^.UtcOff := 0;
  MInfo^.UtcSet := False;
  MInfo^.EchoSet := False;
  MInfo^.EchoVal := False;
  End;


Function MerlinMsgObj.LoadHeader(Id: LongInt): Boolean;
  {Load the header (and the subfields near the front) of message Id into the
   object.  False if it is gone or unusable.}
  Var
    I: LongInt;
    Pos: LongInt;
    Buf: Array[0..Peek - 1] Of Byte;
    N: LongInt;
    Total: LongInt;
    Avail: LongInt;
    Big: PMerBytes;
    HasTo: Boolean;
    DT: DateTime;
    Off: LongInt;

  Procedure ApplySubs(P: PMerBytes; Len: LongInt);
    Var
      Q: LongInt;
      Typ: LongInt;
      DLen: LongInt;
      S: String;
      Cnt: LongInt;

    Begin
    Q := 0;
    While Q + 8 <= Len Do
      Begin
      Typ := MerGetL(P, Q);
      DLen := MerGetL(P, Q + 4);
      If (DLen < 0) Or (Q + 8 + DLen > Len) Then
        Break;
      Cnt := MerMin(DLen, 255);
      S[0] := Chr(Cnt);
      If Cnt > 0 Then
        Move(P^[Q + 8], S[1], Cnt);
      Case Typ Of
        sfCharset: MInfo^.MsgCharset := Copy(S, 1, 16);
        sfFrom: MInfo^.MsgFrom := S;
        sfTo: Begin
              MInfo^.MsgTo := S;
              HasTo := True;
              End;
        sfSubj: MInfo^.MsgSubj := S;
        sfOrig: Begin
                ParseAddr(S, MInfo^.Orig);
                MInfo^.HaveOrig := True;
                End;
        sfDest: Begin
                ParseAddr(S, MInfo^.Dest);
                MInfo^.HaveDest := True;
                End;
        sfUtc: If DLen = 2 Then
                 Begin
                 MInfo^.UtcOff := Integer(MerGetW(P, Q + 8));
                 MInfo^.UtcSet := True;
                 End;
        End;
      Inc(Q, 8 + DLen);
      End;
    End;

  Begin
  LoadHeader := False;
  I := LowerBound(Id);
  If (I >= MInfo^.IdCount) Or (MInfo^.Ids^[I].Id <> Id) Then
    Exit;
  Pos := MInfo^.Ids^[I].Pos;
  N := ReadAt(Pos, Peek, Buf);
  If N < MH Then
    Begin
    MInfo^.StampOk := False;
    Exit;
    End;
  Move(Buf, MInfo^.Hdr, MH);
  With MInfo^.Hdr Do
    If (FrameHdr.FrameId <> mFrameId) Or (FrameHdr.FrameType <> mftMsg) Or (MsgNum <> Id) Or
       ((Attr1 And ma1Deleted) <> 0) Or (FrameHdr.FrameUsedSize < 40) Then
      Begin
      MInfo^.StampOk := False;           {the index is stale}
      Exit;
      End;
  Total := FH + MInfo^.Hdr.FrameHdr.FrameUsedSize;
  Avail := MerMin(N, Total);
  MInfo^.MsgFrom := '';
  MInfo^.MsgTo := '';
  MInfo^.MsgSubj := '';
  MInfo^.MsgCharset := '';
  FillChar(MInfo^.Orig, SizeOf(MInfo^.Orig), 0);
  FillChar(MInfo^.Dest, SizeOf(MInfo^.Dest), 0);
  MInfo^.HaveOrig := False;
  MInfo^.HaveDest := False;
  MInfo^.UtcOff := 0;
  MInfo^.UtcSet := False;
  HasTo := False;
  ApplySubs(@Buf[MH], Avail - MH);
  If (Not HasTo) And (N < Total) Then
    Begin                                {the names are further back: read it all}
    GetMem(Big, Total);
    If Big <> Nil Then
      Begin
      If ReadAt(Pos, Total, Big^) >= MH Then
        Begin
        MInfo^.MsgFrom := '';
        MInfo^.MsgSubj := '';
        MInfo^.MsgCharset := '';
        FillChar(MInfo^.Orig, SizeOf(MInfo^.Orig), 0);
        FillChar(MInfo^.Dest, SizeOf(MInfo^.Dest), 0);
        MInfo^.HaveOrig := False;
        MInfo^.HaveDest := False;
        MInfo^.UtcSet := False;
        ApplySubs(@Big^[MH], MerMin(Total, FileSize(MInfo^.MsgFile) - Pos) - MH);
        End;
      FreeMem(Big, Total);
      End;
    End;
  If MInfo^.Hdr.DateWritten <> 0 Then
    Begin
    If MInfo^.UtcSet Then
      Off := MInfo^.UtcOff
    Else
      Off := MKLocalUtcOffset;
    UnixToDt(MInfo^.Hdr.DateWritten + Off * 60, DT);
    MInfo^.MsgDate := FormattedDate(DT, 'MM-DD-YY');
    MInfo^.MsgTime := FormattedDate(DT, 'HH:II');
    End
  Else
    Begin
    MInfo^.MsgDate := '';
    MInfo^.MsgTime := '';
    End;
  MInfo^.EchoSet := False;
  LoadHeader := True;
  End;


{----------------------------------------------------------- navigation}

Function MerlinMsgObj.SeekIdx(I: LongInt; Dir: LongInt): Boolean;
  Begin
  SeekIdx := False;
  While (I >= 0) And (I < MInfo^.IdCount) Do
    Begin
    If LoadHeader(MInfo^.Ids^[I].Id) Then
      Begin
      MInfo^.Cur := MInfo^.Ids^[I].Id;
      MInfo^.Found := True;
      SeekIdx := True;
      Exit;
      End;
    Inc(I, Dir);
    End;
  End;


Procedure MerlinMsgObj.SeekFirst(MsgNum: LongInt);
  {First message, or the first one numbered MsgNum or higher}
  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  If MsgNum < 0 Then
    MsgNum := 0;
  If Not SeekIdx(LowerBound(MsgNum), 1) Then
    Begin
    MInfo^.Cur := MaxLongInt;
    MInfo^.Found := False;
    End;
  End;


Procedure MerlinMsgObj.SeekNext;
  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  If Not SeekIdx(UpperBound(MInfo^.Cur), 1) Then
    Begin
    MInfo^.Cur := MaxLongInt;
    MInfo^.Found := False;
    End;
  End;


Procedure MerlinMsgObj.SeekPrior;
  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  If Not SeekIdx(LowerBound(MInfo^.Cur) - 1, -1) Then
    Begin
    MInfo^.Cur := 0;
    MInfo^.Found := False;
    End;
  End;


Function MerlinMsgObj.SeekFound: Boolean;
  Begin
  SeekFound := MInfo^.Found;
  End;


Procedure MerlinMsgObj.SetMsgLoc(ML: LongInt);
  {go to message number ML}
  Var
    I: LongInt;

  Begin
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  I := LowerBound(ML);
  If (I >= MInfo^.IdCount) Or (MInfo^.Ids^[I].Id <> ML) Or (Not LoadHeader(ML)) Then
    MInfo^.Found := False
  Else
    Begin
    MInfo^.Cur := ML;
    MInfo^.Found := True;
    End;
  End;


Function MerlinMsgObj.GetMsgLoc: LongInt;
  Begin
  If MInfo^.Found Then
    GetMsgLoc := MInfo^.Hdr.MsgNum
  Else
    GetMsgLoc := 0;
  End;


Procedure MerlinMsgObj.MsgStartUp;
  {the header was loaded by the seek; refresh it in case the base changed}
  Begin
  If MInfo^.BaseOpened And MInfo^.Found Then
    If Not LoadHeader(MInfo^.Cur) Then
      MInfo^.Found := False;
  End;


{--------------------------------------------------------------- yours}

Procedure MerlinMsgObj.YoursFirst(Name: String; Handle: String);
  Var
    i: Word;
    K: Word;

  Begin
  MInfo^.YCount := 0;
  MInfo^.YAscii := True;
  Name := MerTrim(Name);
  Handle := MerTrim(Handle);
  If Length(Name) > 0 Then
    Begin
    Inc(MInfo^.YCount);
    MInfo^.YNames[MInfo^.YCount] := MerLower(Name);
    MInfo^.YHash[MInfo^.YCount] := MerNameHash(Name);
    End;
  If Length(Handle) > 0 Then
    Begin
    Inc(MInfo^.YCount);
    MInfo^.YNames[MInfo^.YCount] := MerLower(Handle);
    MInfo^.YHash[MInfo^.YCount] := MerNameHash(Handle);
    End;
  For i := 1 To MInfo^.YCount Do
    For K := 1 To Length(MInfo^.YNames[i]) Do
      If MInfo^.YNames[i][K] > #127 Then
        MInfo^.YAscii := False;
  MInfo^.YCur := 0;
  YoursNext;
  End;


Procedure MerlinMsgObj.YoursNext;
  Var
    i: LongInt;
    N: LongInt;
    j: Word;
    Match: Boolean;
    H: LongInt;
    T: String;

  Begin
  MInfo^.YFound := False;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  If MInfo^.YCount = 0 Then
    Exit;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  i := UpperBound(MInfo^.YCur);
  While i < MInfo^.IdCount Do
    Begin
    N := MInfo^.Ids^[i].Id;
    MInfo^.YCur := N;
    H := MInfo^.Ids^[i].Hash;
    Match := True;
    If (BaseVersion(MInfo^.Base) >= 1) And MInfo^.YAscii Then
      Begin                              {from the index alone}
      If (H And IxRcvd) <> 0 Then
        Match := False
      Else
        Begin
        Match := False;
        For j := 1 To MInfo^.YCount Do
          If (H And HashMask) = MInfo^.YHash[j] Then
            Match := True;
        End;
      End;
    If Match Then
      If LoadHeader(N) Then
        Begin
        T := MerLower(MerTrim(MInfo^.MsgTo));
        Match := False;
        For j := 1 To MInfo^.YCount Do
          If T = MInfo^.YNames[j] Then
            Match := True;
        If (MInfo^.Hdr.Attr1 And ma1Rcvd) <> 0 Then
          Match := False;
        If Match Then
          Begin
          MInfo^.Cur := N;
          MInfo^.Found := True;
          MInfo^.YFound := True;
          Exit;
          End;
        End;
    Inc(i);
    End;
  MInfo^.YCur := MaxLongInt;
  End;


Function MerlinMsgObj.YoursFound: Boolean;
  Begin
  YoursFound := MInfo^.YFound;
  End;


{------------------------------------------- messages still to be exported}

Function MerlinMsgObj.ExportNext: Boolean;
  Var
    i: LongInt;
    N: LongInt;

  Begin
  MInfo^.ExpFound := False;
  ExportNext := False;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  MInfo^.Error := Fresh;
  If MInfo^.Error <> 0 Then
    Exit;
  i := UpperBound(MInfo^.ExpCur);
  While i < MInfo^.IdCount Do
    Begin
    N := MInfo^.Ids^[i].Id;
    MInfo^.ExpCur := N;
    If (BaseVersion(MInfo^.Base) < 1) Or ((MInfo^.Ids^[i].Hash And IxExport) <> 0) Then
      If LoadHeader(N) Then
        If (MInfo^.Hdr.Attr1 And ma1ToBeExported) <> 0 Then   {the frame has the last word}
          Begin
          MInfo^.Cur := N;
          MInfo^.Found := True;
          MInfo^.ExpFound := True;
          ExportNext := True;
          Exit;
          End;
    Inc(i);
    End;
  MInfo^.ExpCur := MaxLongInt;
  End;


Function MerlinMsgObj.ExportFirst(From: LongInt): Boolean;
  Begin
  If From < 1 Then
    MInfo^.ExpCur := 0
  Else
    MInfo^.ExpCur := From - 1;
  ExportFirst := ExportNext;
  End;


Function MerlinMsgObj.ExportFound: Boolean;
  Begin
  ExportFound := MInfo^.ExpFound;
  End;


Function MerlinMsgObj.GetLastScanned: LongInt;
  Begin
  GetLastScanned := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := Fresh;
    GetLastScanned := MInfo^.Base.LastMsgScanned;
    End;
  End;


{------------------------------------------------------ message details}

Function MerlinMsgObj.GetFrom: String;
  Begin
  GetFrom := MInfo^.MsgFrom;
  End;


Function MerlinMsgObj.GetTo: String;
  Begin
  GetTo := MInfo^.MsgTo;
  End;


Function MerlinMsgObj.GetSubj: String;
  Begin
  GetSubj := MInfo^.MsgSubj;
  End;


Function MerlinMsgObj.GetCost: Word;
  Begin
  GetCost := MInfo^.Hdr.Cost And $FFFF;
  End;


Function MerlinMsgObj.GetDate: String;
  Begin
  GetDate := MInfo^.MsgDate;
  End;


Function MerlinMsgObj.GetTime: String;
  Begin
  GetTime := MInfo^.MsgTime;
  End;


Function MerlinMsgObj.GetRefer: LongInt;
  Begin
  GetRefer := MInfo^.Hdr.ReplyTo;
  End;


Function MerlinMsgObj.GetSeeAlso: LongInt;
  Begin
  GetSeeAlso := MInfo^.Hdr.ReplyFirst;
  End;


Function MerlinMsgObj.GetNextSeeAlso: LongInt;
  Begin
  GetNextSeeAlso := MInfo^.Hdr.ReplyNext;
  End;


Procedure MerlinMsgObj.SetNextSeeAlso(SAlso: LongInt);
  Begin
  MInfo^.Hdr.ReplyNext := SAlso;
  End;


Function MerlinMsgObj.GetMsgNum: LongInt;
  Begin
  GetMsgNum := MInfo^.Hdr.MsgNum;
  End;


Function MerlinMsgObj.GetMsgDisplayNum: LongInt;
  Begin
  If MInfo^.Found Then
    GetMsgDisplayNum := MInfo^.Hdr.MsgNum - MInfo^.Base.DisplayMsgOffset
  Else
    GetMsgDisplayNum := 0;
  End;


Function MerlinMsgObj.GetHighMsgNum: LongInt;
  {highest message number ever used}
  Begin
  GetHighMsgNum := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := Fresh;
    GetHighMsgNum := MInfo^.Base.LastMsgId;
    End;
  End;


Function MerlinMsgObj.GetHighActiveMsgNum: LongInt;
  Begin
  GetHighActiveMsgNum := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := Fresh;
    If MInfo^.IdCount > 0 Then
      GetHighActiveMsgNum := MInfo^.Ids^[MInfo^.IdCount - 1].Id;
    End;
  End;


Function MerlinMsgObj.NumberOfMsgs: LongInt;
  Begin
  NumberOfMsgs := 0;
  If MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := Fresh;
    NumberOfMsgs := MInfo^.IdCount;
    End;
  End;


Procedure MerlinMsgObj.GetOrig(Var Addr: AddrType);
  Begin
  Addr := MInfo^.Orig;
  End;


Procedure MerlinMsgObj.GetDest(Var Addr: AddrType);
  Begin
  Addr := MInfo^.Dest;
  End;


Function MerlinMsgObj.IsLocal: Boolean;
  Begin
  IsLocal := (MInfo^.Hdr.Attr1 And ma1Local) <> 0;
  End;


Function MerlinMsgObj.IsCrash: Boolean;
  Begin
  IsCrash := (MInfo^.Hdr.Attr1 And ma1Crash) <> 0;
  End;


Function MerlinMsgObj.IsKillSent: Boolean;
  Begin
  IsKillSent := (MInfo^.Hdr.Attr1 And ma1KillSent) <> 0;
  End;


Function MerlinMsgObj.IsSent: Boolean;
  Begin
  IsSent := (MInfo^.Hdr.Attr1 And ma1Sent) <> 0;
  End;


Function MerlinMsgObj.IsFAttach: Boolean;
  Begin
  IsFAttach := (MInfo^.Hdr.Attr1 And ma1FAttach) <> 0;
  End;


Function MerlinMsgObj.IsReqRct: Boolean;
  Begin
  IsReqRct := (MInfo^.Hdr.Attr1 And ma1ReqRcpt) <> 0;
  End;


Function MerlinMsgObj.IsReqAud: Boolean;
  Begin
  IsReqAud := (MInfo^.Hdr.Attr1 And ma1ReqAud) <> 0;
  End;


Function MerlinMsgObj.IsRetRct: Boolean;
  Begin
  IsRetRct := (MInfo^.Hdr.Attr1 And ma1RetRcpt) <> 0;
  End;


Function MerlinMsgObj.IsFileReq: Boolean;
  Begin
  IsFileReq := (MInfo^.Hdr.Attr1 And ma1Freq) <> 0;
  End;


Function MerlinMsgObj.IsRcvd: Boolean;
  Begin
  IsRcvd := (MInfo^.Hdr.Attr1 And ma1Rcvd) <> 0;
  End;


Function MerlinMsgObj.IsPriv: Boolean;
  Begin
  IsPriv := (MInfo^.Hdr.Attr1 And ma1Priv) <> 0;
  End;


Function MerlinMsgObj.IsDeleted: Boolean;
  Begin
  IsDeleted := (MInfo^.Hdr.Attr1 And ma1Deleted) <> 0;
  End;


Function MerlinMsgObj.IsEchoed: Boolean;
  Begin
  IsEchoed := (MInfo^.Hdr.Attr1 And ma1ToBeExported) <> 0;
  End;


{----------------------------------------------------- reading the text}

Procedure MerlinMsgObj.MsgTxtStartUp;
  {The text of the message as one block: the kludge subfields as ^A lines
   first, then the body.  It always ends with a CR.}
  Var
    Frm: PMerBytes;
    Total: LongInt;
    Got: LongInt;
    Avail: LongInt;
    Pos: LongInt;
    Q: LongInt;
    Typ: LongInt;
    DLen: LongInt;
    Need: LongInt;
    Pre: String;
    Pass: Word;
    Len: LongInt;
    P: PMerBytes;

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
  Q := LowerBound(MInfo^.Cur);
  If (Q >= MInfo^.IdCount) Or (MInfo^.Ids^[Q].Id <> MInfo^.Cur) Then
    Exit;
  Pos := MInfo^.Ids^[Q].Pos;
  Total := FH + MInfo^.Hdr.FrameHdr.FrameUsedSize;
  GetMem(Frm, Total);
  If Frm = Nil Then
    Exit;
  Got := ReadAt(Pos, Total, Frm^);
  If (Got < MH) Or (MerGetL(Frm, 0) <> mFrameId) Or (MerGetW(Frm, 4) <> mftMsg) Or
     (MerGetL(Frm, 14) <> MInfo^.Cur) Or ((MerGetL(Frm, moAttr1) And ma1Deleted) <> 0) Then
    Begin                                {the frame is not that message any more}
    FreeMem(Frm, Total);
    MInfo^.StampOk := False;
    Exit;
    End;
  Avail := MerMin(Got, Total);
  { pass 1: how big; pass 2: fill }
  Need := 1;
  Q := MH;
  While Q + 8 <= Avail Do
    Begin
    Typ := MerGetL(Frm, Q);
    DLen := MerGetL(Frm, Q + 4);
    If (DLen < 0) Or (Q + 8 + DLen > Avail) Then
      Break;
    If IsKludgeSub(Typ) Then
      Inc(Need, 2 + Length(KludgePrefix(Typ)) + DLen)
    Else If Typ = sfText Then
      Inc(Need, DLen);
    Inc(Q, 8 + DLen);
    End;
  GetMem(MInfo^.TxtBuf, Need + 1);
  If MInfo^.TxtBuf = Nil Then
    Begin
    FreeMem(Frm, Total);
    Exit;
    End;
  P := MInfo^.TxtBuf;
  Len := 0;
  For Pass := 1 To 2 Do
    Begin
    Q := MH;
    While Q + 8 <= Avail Do
      Begin
      Typ := MerGetL(Frm, Q);
      DLen := MerGetL(Frm, Q + 4);
      If (DLen < 0) Or (Q + 8 + DLen > Avail) Then
        Break;
      If (Pass = 1) And IsKludgeSub(Typ) Then
        Begin
        Pre := KludgePrefix(Typ);
        P^[Len] := 1;
        Inc(Len);
        If Length(Pre) > 0 Then
          Move(Pre[1], P^[Len], Length(Pre));
        Inc(Len, Length(Pre));
        If DLen > 0 Then
          Move(Frm^[Q + 8], P^[Len], DLen);
        Inc(Len, DLen);
        P^[Len] := 13;
        Inc(Len);
        End
      Else If (Pass = 2) And (Typ = sfText) Then
        Begin
        If DLen > 0 Then
          Move(Frm^[Q + 8], P^[Len], DLen);
        Inc(Len, DLen);
        End;
      Inc(Q, 8 + DLen);
      End;
    End;
  FreeMem(Frm, Total);
  While (Len > 0) And ((P^[Len - 1] = 13) Or (P^[Len - 1] = 10)) Do
    Dec(Len);
  If Len > 0 Then
    Begin
    P^[Len] := 13;
    Inc(Len);
    End;
  MInfo^.TxtLen := Len;
  End;


Function MerlinMsgObj.GetChar: Char;
  Begin
  If MInfo^.TxtPos < MInfo^.TxtLen Then
    Begin
    GetChar := Chr(MInfo^.TxtBuf^[MInfo^.TxtPos]);
    Inc(MInfo^.TxtPos);
    End
  Else
    GetChar := #0;
  End;


Function MerlinMsgObj.EOM: Boolean;
  Begin
  EOM := (MInfo^.TxtPos >= MInfo^.TxtLen);
  End;


Function MerlinMsgObj.GetTxtPos: LongInt;
  Begin
  GetTxtPos := MInfo^.TxtPos;
  End;


Procedure MerlinMsgObj.SetTxtPos(TP: LongInt);
  Begin
  MInfo^.TxtPos := TP;
  End;


{------------------------------------------------- setting message fields}

Procedure MerlinMsgObj.SetAttr1(tf: Boolean; Mask: LongInt);
  Begin
  If tf Then
    MInfo^.Hdr.Attr1 := MInfo^.Hdr.Attr1 Or Mask
  Else
    MInfo^.Hdr.Attr1 := MInfo^.Hdr.Attr1 And (Not Mask);
  End;


Procedure MerlinMsgObj.SetAttr2(tf: Boolean; Mask: LongInt);
  Begin
  If tf Then
    MInfo^.Hdr.Attr2 := MInfo^.Hdr.Attr2 Or Mask
  Else
    MInfo^.Hdr.Attr2 := MInfo^.Hdr.Attr2 And (Not Mask);
  End;


Procedure MerlinMsgObj.SetDest(Var Addr: AddrType);
  Begin
  MInfo^.Dest := Addr;
  MInfo^.HaveDest := AddrUsed(Addr);
  End;


Procedure MerlinMsgObj.SetOrig(Var Addr: AddrType);
  Begin
  MInfo^.Orig := Addr;
  MInfo^.HaveOrig := AddrUsed(Addr);
  End;


Procedure MerlinMsgObj.SetFrom(Name: String);
  Begin
  MInfo^.MsgFrom := Name;
  End;


Procedure MerlinMsgObj.SetTo(Name: String);
  Begin
  MInfo^.MsgTo := Name;
  End;


Procedure MerlinMsgObj.SetSubj(Str: String);
  Begin
  MInfo^.MsgSubj := Str;
  End;


Procedure MerlinMsgObj.SetCost(SCost: Word);
  Begin
  MInfo^.Hdr.Cost := SCost;
  End;


Procedure MerlinMsgObj.SetRefer(SRefer: LongInt);
  Begin
  MInfo^.Hdr.ReplyTo := SRefer;
  End;


Procedure MerlinMsgObj.SetSeeAlso(SAlso: LongInt);
  Begin
  MInfo^.Hdr.ReplyFirst := SAlso;
  End;


Procedure MerlinMsgObj.SetDate(SDate: String);
  Begin
  MInfo^.MsgDate := Copy(SDate, 1, 8);
  End;


Procedure MerlinMsgObj.SetTime(STime: String);
  Begin
  MInfo^.MsgTime := Copy(STime, 1, 5);
  End;


Procedure MerlinMsgObj.SetLocal(LS: Boolean);
  Begin
  SetAttr1(LS, ma1Local);
  End;


Procedure MerlinMsgObj.SetRcvd(RS: Boolean);
  Begin
  SetAttr1(RS, ma1Rcvd);
  End;


Procedure MerlinMsgObj.SetPriv(PS: Boolean);
  Begin
  SetAttr1(PS, ma1Priv);
  End;


Procedure MerlinMsgObj.SetCrash(SS: Boolean);
  Begin
  SetAttr1(SS, ma1Crash);
  End;


Procedure MerlinMsgObj.SetKillSent(SS: Boolean);
  Begin
  SetAttr1(SS, ma1KillSent);
  End;


Procedure MerlinMsgObj.SetSent(SS: Boolean);
  Begin
  SetAttr1(SS, ma1Sent);
  End;


Procedure MerlinMsgObj.SetFAttach(SS: Boolean);
  Begin
  SetAttr1(SS, ma1FAttach);
  End;


Procedure MerlinMsgObj.SetReqRct(SS: Boolean);
  Begin
  SetAttr1(SS, ma1ReqRcpt);
  End;


Procedure MerlinMsgObj.SetReqAud(SS: Boolean);
  Begin
  SetAttr1(SS, ma1ReqAud);
  End;


Procedure MerlinMsgObj.SetRetRct(SS: Boolean);
  Begin
  SetAttr1(SS, ma1RetRcpt);
  End;


Procedure MerlinMsgObj.SetFileReq(SS: Boolean);
  Begin
  SetAttr1(SS, ma1Freq);
  End;


Procedure MerlinMsgObj.SetEcho(ES: Boolean);
  {ToBeExported}
  Begin
  SetAttr1(ES, ma1ToBeExported);
  MInfo^.EchoSet := True;
  MInfo^.EchoVal := ES;
  End;


Procedure MerlinMsgObj.DoChar(Ch: Char);
  Begin
  If MerGrow(MInfo^.WBuf, MInfo^.WCap, MInfo^.WLen + 1) Then
    Begin
    MInfo^.WBuf^[MInfo^.WLen] := Ord(Ch);
    Inc(MInfo^.WLen);
    End;
  End;


Procedure MerlinMsgObj.DoKludgeLn(Str: String);
  Begin
  If (Length(Str) = 0) Or (Str[1] <> #1) Then
    Str := #1 + Str;
  DoStringLn(Str);
  End;


Procedure MerlinMsgObj.StartNewMsg;
  {Initialize for adding a message: nothing is stored until WriteMsg}
  Begin
  ClearMsg;
  MInfo^.Found := False;
  MInfo^.WLen := 0;
  MInfo^.MsgDate := DateStr(GetDosDate);
  MInfo^.MsgTime := Copy(TimeStr(GetDosDate), 1, 5);
  End;


{------------------------------------------------------------ writing}

Function MerlinMsgObj.BeginWrite: Boolean;
  {lock the base (unless the caller holds the lock) and read it into a write
   context; an interrupted base is repaired first}
  Var
    C: PMerCtx;
    Err: Word;
    Own: Boolean;
    Fixed: Boolean;

  Begin
  BeginWrite := False;
  MInfo^.Ctx := Nil;
  MInfo^.Error := 0;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  If MInfo^.ReadOnly Then
    Begin
    MInfo^.Error := merWriteErr;
    Exit;
    End;
  Own := Not MInfo^.Locked;
  If Own Then
    Begin
    Err := GetLock;
    If Err <> 0 Then
      Begin
      MInfo^.Error := Err;
      Exit;
      End;
    End;
  C := CNew(MInfo^.MsgFile, MInfo^.Sync);
  If C = Nil Then
    Begin
    If Own Then
      ReleaseLock;
    MInfo^.Error := merWriteErr;
    Exit;
    End;
  C^.OwnLock := Own;
  CRebase(C);
  CMake(C);
  If (C^.Err = 0) And C^.NeedRepair Then
    Begin
    If Not MInfo^.AutoRepair Then
      C^.Err := merNeedsRepair
    Else
      Begin
      Fixed := False;
      If RepairIn(MInfo, C, True, Fixed) And (C^.Err = 0) Then
        Begin
        C^.Repaired := True;
        CRebase(C);
        CMake(C);
        If C^.NeedRepair Then
          C^.Err := merNeedsRepair;
        End;
      End;
    End;
  If C^.Err <> 0 Then
    Begin
    Err := C^.Err;
    CRollback(C);
    CDispose(C);
    If Own Then
      ReleaseLock;
    MInfo^.Error := Err;
    Exit;
    End;
  MInfo^.Ctx := C;
  BeginWrite := True;
  End;


Function MerlinMsgObj.EndWrite(Ok: Boolean): Word;
  {commit (or roll back after an error), unlock, free the context}
  Var
    C: PMerCtx;
    Err: Word;

  Begin
  C := MInfo^.Ctx;
  If Ok And (C^.Err = 0) Then
    CCommit(C);
  If C^.Err <> 0 Then
    CRollback(C);
  Err := C^.Err;
  If C^.OwnLock Then
    ReleaseLock;
  CDispose(C);
  MInfo^.Ctx := Nil;
  MInfo^.StampOk := False;
  MInfo^.Error := Err;
  EndWrite := Err;
  End;


Function MerlinMsgObj.WriteMsg: Word;
  {Store the message built with the Set... and Do... calls as a new message.
   The new message becomes the current one.}
  Var
    Norm: PMerBytes;
    NormLen: LongInt;
    NormAlloc: LongInt;
    Subs: PMerBytes;
    SubsLen: LongInt;
    SubsAlloc: LongInt;
    Body: PMerBytes;
    BodyLen: LongInt;
    BodyAlloc: LongInt;
    i: LongInt;
    LS: LongInt;
    LE: LongInt;
    W: LongInt;
    Err: Word;
    Utf8: Boolean;
    FromS: String;
    ToS: String;
    SubjS: String;
    Utc: LongInt;
    Tz: LongInt;
    TzFound: Boolean;
    Written: LongInt;
    DT: DateTime;
    Attr: LongInt;
    Exp: Boolean;
    Hash: LongInt;
    Need: LongInt;
    VOfs: LongInt;
    Typ: LongInt;
    LastRep: Boolean;
    U: Array[0..1] Of Byte;
    P: PMerBytes;
    Ok: Boolean;
    Id: LongInt;
    Slot: LongInt;
    Pos: LongInt;
    Data: LongInt;
    FB: PMerBytes;
    Hd: MerlinMsgHdrType;
    At: LongInt;
    RefPar: LongInt;
    NewId: LongInt;

  Procedure CleanLine(Var S, E: LongInt);
    {a kludge line: drop the ^A, collapse runs of control bytes to one blank,
     trim; the result is Norm^[S..E)}
    Var
      R: LongInt;
      Wp: LongInt;
      InRun: Boolean;
      B: Byte;

    Begin
    If (E > S) And (Norm^[S] = 1) Then
      Inc(S);
    Wp := S;
    InRun := False;
    For R := S To E - 1 Do
      Begin
      B := Norm^[R];
      If (B = 0) Or (B = 1) Or (B = 10) Or (B = 13) Then
        Begin
        If Not InRun Then
          Begin
          Norm^[Wp] := 32;
          Inc(Wp);
          InRun := True;
          End;
        End
      Else
        Begin
        Norm^[Wp] := B;
        Inc(Wp);
        InRun := False;
        End;
      End;
    E := Wp;
    While (E > S) And (Norm^[E - 1] <= 32) Do
      Dec(E);
    While (E > S) And (Norm^[S] <= 32) Do
      Inc(S);
    End;

  Procedure Done_;
    Begin
    If Norm <> Nil Then FreeMem(Norm, NormAlloc);
    If Subs <> Nil Then FreeMem(Subs, SubsAlloc);
    If Body <> Nil Then FreeMem(Body, BodyAlloc);
    End;

  Begin
  Norm := Nil; Subs := Nil; Body := Nil;
  NormLen := 0; NormAlloc := 0; SubsLen := 0; SubsAlloc := 0; BodyLen := 0; BodyAlloc := 0;
  MInfo^.Error := 0;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    WriteMsg := MInfo^.Error;
    Exit;
    End;
  Utf8 := CharsetIsUtf8(MInfo^.Charset);
  FromS := FitName(MInfo^.MsgFrom, Utf8);
  If Length(FromS) = 0 Then
    Begin
    MInfo^.Error := merNoFrom;
    WriteMsg := MInfo^.Error;
    Exit;
    End;
  ToS := MerTrim(MInfo^.MsgTo);
  If Length(ToS) = 0 Then
    ToS := 'All';
  ToS := FitName(ToS, Utf8);
  SubjS := FitName(MInfo^.MsgSubj, Utf8);
  { normalise line breaks to CR, NUL to blank }
  If Not MerGrow(Norm, NormAlloc, MInfo^.WLen + 2) Then
    Begin
    MInfo^.Error := merWriteErr;
    WriteMsg := MInfo^.Error;
    Exit;
    End;
  i := 0;
  While i < MInfo^.WLen Do
    Begin
    Case MInfo^.WBuf^[i] Of
      13: Begin
          Norm^[NormLen] := 13;
          Inc(NormLen);
          If (i + 1 < MInfo^.WLen) And (MInfo^.WBuf^[i + 1] = 10) Then
            Inc(i);
          End;
      10: Begin
          Norm^[NormLen] := 13;
          Inc(NormLen);
          End;
      0:  Begin
          Norm^[NormLen] := 32;
          Inc(NormLen);
          End;
      Else
        Begin
        Norm^[NormLen] := MInfo^.WBuf^[i];
        Inc(NormLen);
        End;
      End;
    Inc(i);
    End;
  Norm^[NormLen] := 13;                  {a sentinel: every line ends in CR}
  Inc(NormLen);
  { pass 1: a TZUTC kludge names the sender's time zone }
  TzFound := False;
  Tz := 0;
  LS := 0;
  For i := 0 To NormLen - 1 Do
    If Norm^[i] = 13 Then
      Begin
      LE := i;
      If (LE > LS) And (Norm^[LS] = 1) And (Not TzFound) Then
        Begin
        W := LS;
        i := i;
        CleanLine(W, LE);
        If TzFromKludge(@Norm^[W], LE - W, Tz) Then
          If Abs(Tz) <= 1440 Then
            TzFound := True;
        End;
      LS := i + 1;
      End;
  { the UTC offset of the message }
  If MInfo^.UtcSet Then
    Begin
    If Abs(MInfo^.UtcOff) > 1440 Then
      Begin
      Done_;
      MInfo^.Error := merBadMsg;
      WriteMsg := MInfo^.Error;
      Exit;
      End;
    Utc := MInfo^.UtcOff;
    End
  Else If TzFound Then
    Utc := Tz
  Else
    Utc := MKLocalUtcOffset;
  { the date and time the sender wrote it (local clock) -> UTC }
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
    Written := MerUtcNow;
  { the subfields: charset, names, utc, addresses, kludges, text }
  Ok := PutSubStr(Subs, SubsLen, SubsAlloc, sfCharset, MInfo^.Charset);
  Ok := Ok And PutSubStr(Subs, SubsLen, SubsAlloc, sfFrom, FromS);
  Ok := Ok And PutSubStr(Subs, SubsLen, SubsAlloc, sfTo, ToS);
  Ok := Ok And PutSubStr(Subs, SubsLen, SubsAlloc, sfSubj, SubjS);
  PMerWord(@U[0])^ := Word(Integer(Utc));
  Ok := Ok And PutSub(Subs, SubsLen, SubsAlloc, sfUtc, U, 2);
  If MInfo^.HaveOrig Then
    Ok := Ok And PutSubStr(Subs, SubsLen, SubsAlloc, sfOrig, AddrText(MInfo^.Orig));
  If MInfo^.HaveDest Then
    Ok := Ok And PutSubStr(Subs, SubsLen, SubsAlloc, sfDest, AddrText(MInfo^.Dest));
  If Not MerGrow(Body, BodyAlloc, NormLen + 1) Then
    Ok := False;
  LS := 0;
  i := 0;
  While Ok And (i < NormLen) Do
    Begin
    If Norm^[i] = 13 Then
      Begin
      LE := i;
      If (LE > LS) And (Norm^[LS] = 1) Then
        Begin
        W := LS;
        CleanLine(W, LE);
        If LE > W Then
          Begin
          Typ := KludgeType(@Norm^[W], LE - W, VOfs);
          Ok := PutSub(Subs, SubsLen, SubsAlloc, Typ, Norm^[W + VOfs], LE - W - VOfs);
          End;
        End
      Else If i + 1 < NormLen Then       {not the sentinel: a body line}
        Begin
        If LE > LS Then
          Move(Norm^[LS], Body^[BodyLen], LE - LS);
        Inc(BodyLen, LE - LS);
        Body^[BodyLen] := 13;
        Inc(BodyLen);
        End;
      LS := i + 1;
      End;
    Inc(i);
    End;
  While (BodyLen > 0) And (Body^[BodyLen - 1] <= 32) Do
    Dec(BodyLen);
  If Not Ok Then
    Err := merWriteErr
  Else If BodyLen = 0 Then
    Err := merNoText
  Else If MInfo^.Hdr.ReplyTo < 0 Then
    Err := merBadMsg
  Else
    Begin
    Err := 0;
    Ok := PutSub(Subs, SubsLen, SubsAlloc, sfText, Body^, BodyLen);
    If Not Ok Then
      Err := merWriteErr;
    End;
  If Err <> 0 Then
    Begin
    Done_;
    MInfo^.Error := Err;
    WriteMsg := Err;
    Exit;
    End;
  { attributes and the index hash }
  If MInfo^.EchoSet Then
    Exp := MInfo^.EchoVal
  Else
    Exp := (MInfo^.MailType <> mmtNormal);
  Attr := MInfo^.Hdr.Attr1 And ma1Mapped And (Not ma1ToBeExported);
  If Exp Then
    Attr := Attr Or ma1ToBeExported;
  Hash := MerNameHash(ToS) Or AttrBits(Attr);
  Need := 40 + SubsLen;
  RefPar := MInfo^.Hdr.ReplyTo;
  { store it }
  NewId := 0;
  If BeginWrite Then
    Begin
    With MInfo^.Ctx^ Do
      Begin
      If Base.MaxMsgs > 0 Then
        Begin                            {make room: drop the oldest}
        At := 0;
        While (Active >= Base.MaxMsgs) And (Active > 0) And (Err = 0) Do
          Begin
          While (At * Rec < IdxLen) And (MerGetL(Idx, At * Rec + 4) = 0) Do
            Inc(At);
          If At * Rec >= IdxLen Then
            Break;
          CKill(MInfo^.Ctx, Base.BaseMsgId + At, MInfo^.UnlinkOnDelete);
          End;
        End;
      End;
    CTrimHead(MInfo^.Ctx);
    If (MInfo^.Ctx^.Err = 0) And (MInfo^.Ctx^.Base.LastMsgId >= MaxId) Then
      MInfo^.Ctx^.Err := merFull;
    If MInfo^.Ctx^.Err = 0 Then
      Begin
      Id := MInfo^.Ctx^.Base.LastMsgId + 1;
      Slot := Id - MInfo^.Ctx^.Base.BaseMsgId;
      CEnsureSlots(MInfo^.Ctx, Slot + 1);
      CAlloc(MInfo^.Ctx, Need, Pos, Data);
      End;
    If MInfo^.Ctx^.Err = 0 Then
      Begin
      GetMem(FB, FH + Data);
      If FB = Nil Then
        MInfo^.Ctx^.Err := merWriteErr
      Else
        Begin
        FillChar(FB^, FH + Data, 0);
        FillChar(Hd, SizeOf(Hd), 0);
        MakeFrameHdr(Hd.FrameHdr, mftMsg, Data, Need);
        Hd.MsgNum := Id;
        Hd.TotMsgSize := FH + Need;
        Hd.ReplyTo := RefPar;
        Hd.ReplyFirst := MInfo^.Hdr.ReplyFirst;
        Hd.DateWritten := Written;
        Hd.DateProcessed := MerUtcNow;
        Hd.Attr1 := Attr;
        Hd.Attr2 := MInfo^.Hdr.Attr2;
        Hd.Cost := MInfo^.Hdr.Cost;
        Move(Hd, FB^, MH);
        Move(Subs^, FB^[MH], SubsLen);
        CPoke(MInfo^.Ctx, Pos, FH + Data, FB^, False);
        FreeMem(FB, FH + Data);
        CSetSlot(MInfo^.Ctx, Slot, Hash, Pos);
        Inc(MInfo^.Ctx^.Active);
        MInfo^.Ctx^.Base.LastMsgId := Id;
        MInfo^.Ctx^.Changed := True;
        MInfo^.Ctx^.ExportTouched := True;
        If (RefPar <> 0) And MInfo^.LinkReplies Then
          CLinkReply(MInfo^.Ctx, RefPar, Id);
        NewId := Id;
        End;
      End;
    Err := EndWrite(True);
    End
  Else
    Err := MInfo^.Error;
  Done_;
  If (Err = 0) And (NewId <> 0) Then
    Begin                                {the new message is the current one}
    MInfo^.Error := Fresh;
    If MInfo^.Error = 0 Then
      Begin
      If LoadHeader(NewId) Then
        Begin
        MInfo^.Cur := NewId;
        MInfo^.Found := True;
        End;
      End;
    End;
  WriteMsg := Err;
  End;


Procedure MerlinMsgObj.DeleteMsg;
  {Delete the current message: unlinked from its replies, flagged Deleted,
   its frame is freed.}
  Var
    Id: LongInt;

  Begin
  If (Not MInfo^.BaseOpened) Or (Not MInfo^.Found) Then
    Begin
    If MInfo^.BaseOpened Then
      MInfo^.Error := merNotFound
    Else
      MInfo^.Error := merNotOpen;
    Exit;
    End;
  Id := MInfo^.Cur;
  If BeginWrite Then
    Begin
    CKill(MInfo^.Ctx, Id, MInfo^.UnlinkOnDelete);
    If EndWrite(True) = 0 Then
      MInfo^.Found := False;
    End;
  End;


Function MerlinMsgObj.MarkExported(MsgNum: LongInt; Exported: Boolean): Word;
  Begin
  If BeginWrite Then
    Begin
    If Exported Then
      CSetAttr(MInfo^.Ctx, MsgNum, ma1ToBeExported, 0)
    Else
      CSetAttr(MInfo^.Ctx, MsgNum, 0, ma1ToBeExported);
    MInfo^.Ctx^.ExportTouched := True;
    MarkExported := EndWrite(True);
    If (MInfo^.Error = 0) And MInfo^.Found And (MInfo^.Cur = MsgNum) Then
      Begin
      MInfo^.Error := Fresh;
      If MInfo^.Error = 0 Then
        If Not LoadHeader(MsgNum) Then
          MInfo^.Found := False;
      End;
    End
  Else
    MarkExported := MInfo^.Error;
  End;


Function MerlinMsgObj.SetLastScanned(MsgNum: LongInt): Word;
  Begin
  If BeginWrite Then
    Begin
    MInfo^.Ctx^.Base.LastMsgScanned := MsgNum;
    MInfo^.Ctx^.Changed := True;
    SetLastScanned := EndWrite(True);
    End
  Else
    SetLastScanned := MInfo^.Error;
  End;


Procedure MerlinMsgObj.ReWriteHdr;
  {Write the flags, from / to / subject, addresses, cost, reference
   (ReplyTo), see also (ReplyFirst) and ReplyNext of the current message back.
   Dates, text and kludges stay.  If the frame is too small for longer names
   the message moves to a new frame (same number).}
  Var
    Id: LongInt;
    Pos: LongInt;
    B: MerlinMsgHdrType;
    Frm: PMerBytes;
    FrmLen: LongInt;
    NewSubs: PMerBytes;
    NSLen: LongInt;
    NSAlloc: LongInt;
    Q: LongInt;
    Typ: LongInt;
    DLen: LongInt;
    HasCs: Boolean;
    CsOk: Boolean;
    Utf8: Boolean;
    CsName: String;
    FromS: String;
    ToS: String;
    SubjS: String;
    Own: Boolean;
    Ok: Boolean;
    Need: LongInt;
    Slot: LongInt;
    Hash: LongInt;
    Attr: LongInt;
    Pass: Word;
    U: Array[0..1] Of Byte;
    OutB: PMerBytes;
    Pos2: LongInt;
    Data2: LongInt;
    NewHd: MerlinMsgHdrType;
    Finished: Boolean;

  Function Own_(T: LongInt): Boolean;
    {a subfield type this routine writes itself}
    Begin
    Own_ := (T = sfOrig) Or (T = sfDest) Or (T = sfFrom) Or (T = sfTo) Or (T = sfSubj) Or
      ((T = sfUtc) And MInfo^.UtcSet);
    End;

  Begin
  If (Not MInfo^.BaseOpened) Or (Not MInfo^.Found) Then
    Begin
    If MInfo^.BaseOpened Then
      MInfo^.Error := merNotFound
    Else
      MInfo^.Error := merNotOpen;
    Exit;
    End;
  Id := MInfo^.Cur;
  If Not BeginWrite Then
    Exit;
  Frm := Nil;
  NewSubs := Nil;
  NSLen := 0;
  NSAlloc := 0;
  Finished := False;
  Pos := CFrameOf(MInfo^.Ctx, Id);
  If Pos = 0 Then
    MInfo^.Ctx^.Err := merNotFound
  Else
    CCheckedFrame(MInfo^.Ctx, Id, Pos, B);
  If MInfo^.Ctx^.Err = 0 Then
    Begin
    FrmLen := FH + B.FrameHdr.FrameUsedSize;
    If (B.FrameHdr.FrameUsedSize < 40) Or (Pos + FrmLen > MInfo^.Ctx^.Size) Then
      MInfo^.Ctx^.Err := merDamaged
    Else
      Begin
      GetMem(Frm, FrmLen);
      If (Frm = Nil) Or (MerRd(MInfo^.MsgFile, Pos, FrmLen, Frm^) <> FrmLen) Then
        MInfo^.Ctx^.Err := merReadErr;
      End;
    End;
  If MInfo^.Ctx^.Err = 0 Then
    Begin
    { names are written in the charset the message already has }
    HasCs := False;
    CsOk := False;
    CsName := '';
    Q := MH;
    While Q + 8 <= FrmLen Do
      Begin
      Typ := MerGetL(Frm, Q);
      DLen := MerGetL(Frm, Q + 4);
      If (DLen < 0) Or (Q + 8 + DLen > FrmLen) Then
        Break;
      If (Typ = sfCharset) And (Not HasCs) Then
        Begin
        HasCs := True;
        CsName[0] := Chr(MerMin(DLen, 16));
        If DLen > 0 Then
          Move(Frm^[Q + 8], CsName[1], Length(CsName));
        CsOk := CharsetKnown(CsName);
        End;
      Inc(Q, 8 + DLen);
      End;
    If HasCs And CsOk Then
      Utf8 := CharsetIsUtf8(CsName)
    Else
      Utf8 := True;                      {a message without a charset: as UTF-8}
    FromS := FitName(MInfo^.MsgFrom, Utf8);
    If Length(FromS) = 0 Then
      MInfo^.Ctx^.Err := merNoFrom;
    ToS := MerTrim(MInfo^.MsgTo);
    If Length(ToS) = 0 Then
      ToS := 'All';
    ToS := FitName(ToS, Utf8);
    SubjS := FitName(MInfo^.MsgSubj, Utf8);
    End;
  If MInfo^.Ctx^.Err = 0 Then
    Begin
    Ok := True;
    If HasCs And CsOk Then
      Ok := PutSubStr(NewSubs, NSLen, NSAlloc, sfCharset, CsName);
    Ok := Ok And PutSubStr(NewSubs, NSLen, NSAlloc, sfFrom, FromS);
    Ok := Ok And PutSubStr(NewSubs, NSLen, NSAlloc, sfTo, ToS);
    Ok := Ok And PutSubStr(NewSubs, NSLen, NSAlloc, sfSubj, SubjS);
    If MInfo^.UtcSet Then
      Begin
      If Abs(MInfo^.UtcOff) > 1440 Then
        MInfo^.Ctx^.Err := merBadMsg
      Else
        Begin
        PMerWord(@U[0])^ := Word(Integer(MInfo^.UtcOff));
        Ok := Ok And PutSub(NewSubs, NSLen, NSAlloc, sfUtc, U, 2);
        End;
      End;
    If MInfo^.HaveOrig Then
      Ok := Ok And PutSubStr(NewSubs, NSLen, NSAlloc, sfOrig, AddrText(MInfo^.Orig));
    If MInfo^.HaveDest Then
      Ok := Ok And PutSubStr(NewSubs, NSLen, NSAlloc, sfDest, AddrText(MInfo^.Dest));
    { everything else stays as it was, in its order }
    Q := MH;
    While Ok And (Q + 8 <= FrmLen) Do
      Begin
      Typ := MerGetL(Frm, Q);
      DLen := MerGetL(Frm, Q + 4);
      If (DLen < 0) Or (Q + 8 + DLen > FrmLen) Then
        Break;
      If (Typ <> sfCharset) And (Not Own_(Typ)) Then
        Ok := PutSub(NewSubs, NSLen, NSAlloc, Typ, Frm^[Q + 8], DLen);
      Inc(Q, 8 + DLen);
      End;
    If Not Ok Then
      MInfo^.Ctx^.Err := merWriteErr;
    End;
  If MInfo^.Ctx^.Err = 0 Then
    Begin
    Attr := (B.Attr1 And (Not ma1Mapped)) Or (MInfo^.Hdr.Attr1 And ma1Mapped);
    NewHd := B;
    NewHd.Attr1 := Attr;
    If MInfo^.Hdr.Cost >= 0 Then
      NewHd.Cost := MInfo^.Hdr.Cost;
    If MInfo^.Hdr.ReplyTo >= 0 Then
      NewHd.ReplyTo := MInfo^.Hdr.ReplyTo;
    If MInfo^.Hdr.ReplyFirst >= 0 Then
      NewHd.ReplyFirst := MInfo^.Hdr.ReplyFirst;
    If MInfo^.Hdr.ReplyNext >= 0 Then
      NewHd.ReplyNext := MInfo^.Hdr.ReplyNext;
    Hash := MerNameHash(ToS) Or AttrBits(Attr);
    Need := 40 + NSLen;
    Slot := Id - MInfo^.Ctx^.Base.BaseMsgId;
    If Need <= B.FrameHdr.FrameDataSize Then
      Begin                              {fits where it is}
      GetMem(OutB, MH + NSLen);
      If OutB = Nil Then
        MInfo^.Ctx^.Err := merWriteErr
      Else
        Begin
        NewHd.FrameHdr.FrameUsedSize := Need;
        NewHd.TotMsgSize := FH + Need;
        Move(NewHd, OutB^, MH);
        Move(NewSubs^, OutB^[MH], NSLen);
        CPoke(MInfo^.Ctx, Pos, MH + NSLen, OutB^, False);
        FreeMem(OutB, MH + NSLen);
        If Hash <> MerGetL(MInfo^.Ctx^.Idx, Slot * Rec) Then
          CSetSlot(MInfo^.Ctx, Slot, Hash, Pos);
        End;
      End
    Else
      Begin                              {moves: new frame, old one freed}
      CAlloc(MInfo^.Ctx, Need, Pos2, Data2);
      If MInfo^.Ctx^.Err = 0 Then
        Begin
        GetMem(OutB, FH + Data2);
        If OutB = Nil Then
          MInfo^.Ctx^.Err := merWriteErr
        Else
          Begin
          FillChar(OutB^, FH + Data2, 0);
          MakeFrameHdr(NewHd.FrameHdr, mftMsg, Data2, Need);
          NewHd.TotMsgSize := FH + Need;
          Move(NewHd, OutB^, MH);
          Move(NewSubs^, OutB^[MH], NSLen);
          CPoke(MInfo^.Ctx, Pos2, FH + Data2, OutB^, False);
          FreeMem(OutB, FH + Data2);
          CSetSlot(MInfo^.Ctx, Slot, Hash, Pos2);
          Attr := B.Attr1 Or ma1Deleted;
          CPokeL(MInfo^.Ctx, Pos + moAttr1, Attr);
          CFreeFrame(MInfo^.Ctx, Pos, B.FrameHdr.FrameDataSize);
          End;
        End;
      End;
    MInfo^.Ctx^.Changed := True;
    MInfo^.Ctx^.ExportTouched := True;
    End;
  If Frm <> Nil Then
    FreeMem(Frm, FrmLen);
  If NewSubs <> Nil Then
    FreeMem(NewSubs, NSAlloc);
  If EndWrite(True) = 0 Then
    Begin
    MInfo^.Error := Fresh;
    If MInfo^.Error = 0 Then
      If LoadHeader(Id) Then
        Begin
        MInfo^.Cur := Id;
        MInfo^.Found := True;
        End
      Else
        MInfo^.Found := False;
    End;
  End;


{------------------------------------------------------------ last read}

Function MerlinMsgObj.GetLastRead(UNum: LongInt): LongInt;
  {the last read message number of user UNum (application defined), 0 if the
   user has none}
  Var
    Attempt: Word;
    H1: MerlinMsgBaseHdrType;
    H2: MerlinMsgBaseHdrType;
    FrmHd: MerlinFrameHdrType;
    Body: PMerBytes;
    BLen: LongInt;
    N: LongInt;
    i: LongInt;
    Bad: Boolean;
    Res: LongInt;

  Begin
  GetLastRead := 0;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  MInfo^.Error := 0;
  For Attempt := 1 To 4 Do
    Begin
    N := ReadAt(0, BaseLen, H1);
    If (N <> BaseLen) Or (H1.FrameHdr.FrameId <> mFrameId) Then
      Begin
      MInfo^.Error := merNotMerlin;
      Exit;
      End;
    If H1.LastReadPtr = 0 Then
      Exit;
    Bad := True;
    Body := Nil;
    BLen := 0;
    N := ReadAt(H1.LastReadPtr, FH, FrmHd);
    If (N = FH) And (FrmHd.FrameId = mFrameId) And (FrmHd.FrameType = mftLastRead) Then
      Begin
      BLen := MerMin(FrmHd.FrameUsedSize, FrmHd.FrameDataSize);
      If BLen >= 0 Then
        Begin
        GetMem(Body, MerMax(BLen, 1));
        If (Body <> Nil) And ((BLen = 0) Or (ReadAt(H1.LastReadPtr + FH, BLen, Body^) = BLen)) Then
          Bad := False;
        End;
      End;
    N := ReadAt(0, BaseLen, H2);
    If (N = BaseLen) And (CompareByte(H1, H2, BaseLen) <> 0) Then
      Begin                              {a writer was busy: again}
      If Body <> Nil Then
        FreeMem(Body, MerMax(BLen, 1));
      Continue;
      End;
    If Bad Then
      Begin
      If Body <> Nil Then
        FreeMem(Body, MerMax(BLen, 1));
      MInfo^.Error := merDamaged;
      Exit;
      End;
    Res := 0;
    i := 0;
    While (i + 1) * Rec <= BLen Do
      Begin
      If MerGetL(Body, i * Rec) = UNum Then
        Begin
        Res := MerGetL(Body, i * Rec + 4);
        Break;
        End;
      Inc(i);
      End;
    FreeMem(Body, MerMax(BLen, 1));
    GetLastRead := Res;
    Exit;
    End;
  MInfo^.Error := merChanging;
  End;


Procedure MerlinMsgObj.SetLastRead(UNum: LongInt; LR: LongInt);
  Var
    C: PMerCtx;
    Pos: LongInt;
    FrmHd: MerlinFrameHdrType;
    Body: PMerBytes;
    BLen: LongInt;
    N: LongInt;
    i: LongInt;
    Rc: MerlinLastReadType;
    Finished: Boolean;
    Cap: LongInt;
    NewPos: LongInt;
    NewData: LongInt;
    FB: PMerBytes;
    HaveF: Boolean;
    OldData: LongInt;

  Begin
  If BeginWrite Then
    Begin
    C := MInfo^.Ctx;
    OldData := 0;
    Rc.UserId := UNum;
    Rc.LastRead := LR;
    Pos := C^.Base.LastReadPtr;
    Body := Nil;
    BLen := 0;
    Finished := False;
    HaveF := False;
    If Pos <> 0 Then
      Begin
      N := MerRd(C^.F^, Pos, FH, FrmHd);
      If (N < FH) Or (FrmHd.FrameId <> mFrameId) Or (FrmHd.FrameType <> mftLastRead) Or
         (Int64(Pos) + FH + FrmHd.FrameDataSize > C^.Size) Or (FrmHd.FrameUsedSize > FrmHd.FrameDataSize) Or
         (FrmHd.FrameUsedSize < 0) Then
        C^.Err := merDamaged
      Else
        Begin
        HaveF := True;
        OldData := FrmHd.FrameDataSize;
        BLen := FrmHd.FrameUsedSize;
        GetMem(Body, MerMax(BLen, 1));
        If (Body = Nil) Or ((BLen > 0) And (MerRd(C^.F^, Pos + FH, BLen, Body^) <> BLen)) Then
          C^.Err := merReadErr
        Else
          Begin
          For i := 0 To BLen Div Rec - 1 Do
            If (Not Finished) And (MerGetL(Body, i * Rec) = UNum) Then
              Begin
              CPokeL(C, Pos + FH + i * Rec + 4, LR);
              Finished := True;
              End;
          If (Not Finished) And (BLen + Rec <= FrmHd.FrameDataSize) Then
            Begin                        {room for one more}
            CPoke(C, Pos + FH + BLen, Rec, Rc, False);
            CPokeL(C, Pos + 10, BLen + Rec);
            Finished := True;
            End;
          End;
        End;
      End;
    If (C^.Err = 0) And (Not Finished) Then
      Begin                              {a new frame: twice the room}
      Cap := 32;
      If HaveF Then
        Cap := MerMax(32, (FrmHd.FrameDataSize Div Rec) * 2);
      CAlloc(C, Cap * Rec, NewPos, NewData);
      If C^.Err = 0 Then
        Begin
        GetMem(FB, FH + NewData);
        If FB = Nil Then
          C^.Err := merWriteErr
        Else
          Begin
          FillChar(FB^, FH + NewData, 0);
          MakeFrameHdr(FrmHd, mftLastRead, NewData, BLen + Rec);
          Move(FrmHd, FB^, FH);
          If BLen > 0 Then
            Move(Body^, FB^[FH], BLen);
          Move(Rc, FB^[FH + BLen], Rec);
          CPoke(C, NewPos, FH + NewData, FB^, False);
          FreeMem(FB, FH + NewData);
          C^.Base.LastReadPtr := NewPos;
          C^.Changed := True;
          If HaveF Then
            CFreeFrame(C, Pos, OldData);
          End;
        End;
      End;
    If Body <> Nil Then
      FreeMem(Body, MerMax(BLen, 1));
    If EndWrite(True) = 0 Then;
    End;
  End;


{------------------------------------------------------ check and repair}
{ Check walks the frames of the file and compares them with the base header,
  the index and the free list.  Repair rebuilds what the frames themselves can
  tell: the index (from the message frames), the free list (from the free and
  dead frames, merged, the free tail cut off), the base header (message
  numbers, counts, pointers) and converts a version 0 base.  Messages are
  never changed. }

Type
  MerFrame = Record
    Pos: LongInt;
    Typ: LongInt;
    Data: LongInt;
    Used: LongInt;
    End;
  TMerFrameArr = Array[0..$FFFFFF] Of MerFrame;
  PMerFrameArr = ^TMerFrameArr;

  MerGap = Record
    Pos: LongInt;
    Len: LongInt;
    Tail: Boolean;
    End;
  TMerGapArr = Array[0..$FFFFFF] Of MerGap;
  PMerGapArr = ^TMerGapArr;

  MerLive = Record
    Fr: LongInt;                         { frame index }
    Id: LongInt;
    Attr: LongInt;
    Tot: LongInt;
    Hash: LongInt;
    Pos: LongInt;
    Used: LongInt;
    End;
  TMerLiveArr = Array[0..$FFFFFF] Of MerLive;
  PMerLiveArr = ^TMerLiveArr;

  MerRegion = Record
    Pos: LongInt;
    Total: LongInt;
    Free: Boolean;
    Single: Boolean;
    Fr: LongInt;                         { frame index, -1 for none }
    Grew: LongInt;
    End;
  TMerRegArr = Array[0..$FFFFFF] Of MerRegion;
  PMerRegArr = ^TMerRegArr;

  MerPlan = Record
    Base: MerlinMsgBaseHdrType;
    Frames: PMerFrameArr;
    NFrames: LongInt;
    FrameCap: LongInt;
    Gaps: PMerGapArr;
    NGaps: LongInt;
    GapCap: LongInt;
    Msgs: PMerLiveArr;                   { usable, not deleted message frames }
    NMsgs: LongInt;
    Live: PMerLiveArr;                   { one per message number }
    NLive: LongInt;
    Keep: PMerBytes;                     { per frame: kept (1) or free space (0) }
    Regs: PMerRegArr;                    { the layout }
    Tmp: PMerRegArr;
    NRegs: LongInt;
    RegCap: LongInt;
    EndPos: LongInt;
    TailFree: Boolean;
    Merges: LongInt;
    CandIdx: LongInt;                    { chosen index / free list / last read frame }
    CandFree: LongInt;
    CandLr: LongInt;
    IdxF: LongInt;                       { ... as kept after the size check (-1 = new) }
    FreeF: LongInt;
    IdxF0: LongInt;
    FreeF0: LongInt;
    BaseId: LongInt;
    Last: LongInt;
    Slots: Int64;
    ExpIdx: PMerBytes;
    FixTot: LongInt;
    NotFree: LongInt;
    NFreeRegs: LongInt;
    Problems: LongInt;
    End;
  PMerPlan = ^MerPlan;


Procedure Prob(Inf: PMerInfo; S: String);
  Begin
  If Inf^.ReportCnt < 40 Then
    Begin
    Inc(Inf^.ReportCnt);
    Inf^.Report[Inf^.ReportCnt] := Copy(S, 1, 120);
    End
  Else
    Inc(Inf^.ReportMore);
  End;


Function NumS(N: LongInt): String;
  Var
    S: String;

  Begin
  Str(N, S);
  NumS := S;
  End;


Procedure PlanFree(P: PMerPlan);
  Begin
  If P^.Frames <> Nil Then FreeMem(P^.Frames, P^.FrameCap * SizeOf(MerFrame));
  If P^.Gaps <> Nil Then FreeMem(P^.Gaps, P^.GapCap * SizeOf(MerGap));
  If P^.Msgs <> Nil Then FreeMem(P^.Msgs, P^.FrameCap * SizeOf(MerLive));
  If P^.Live <> Nil Then FreeMem(P^.Live, P^.FrameCap * SizeOf(MerLive));
  If P^.Keep <> Nil Then FreeMem(P^.Keep, P^.FrameCap);
  If P^.Regs <> Nil Then FreeMem(P^.Regs, P^.RegCap * SizeOf(MerRegion));
  If P^.Tmp <> Nil Then FreeMem(P^.Tmp, P^.RegCap * SizeOf(MerRegion));
  If P^.ExpIdx <> Nil Then FreeMem(P^.ExpIdx, MerMax(P^.Slots * Rec, 1));
  End;


Function ScanFrames(Var F: File; Size: LongInt; P: PMerPlan): Boolean;
  {the frames of the file in order, and the gaps (bytes that are no frame)}
  Var
    Pos: LongInt;
    Fr: MerFrame;
    Next: LongInt;
    Chunk: PMerBytes;
    At: LongInt;
    N: LongInt;
    K: LongInt;
    Found: Boolean;

  Function ValidAt(Q: LongInt; Var Out: MerFrame): Boolean;
    Var
      H: MerlinFrameHdrType;
      R: LongInt;

    Begin
    ValidAt := False;
    If Int64(Q) + FH > Size Then
      Exit;
    R := MerRd(F, Q, FH, H);
    If R < FH Then
      Exit;
    If (H.FrameId <> mFrameId) Or (H.FrameType < mftFreeList) Or (H.FrameType > mftFreeFrame) Or
       (H.FrameDataSize < 0) Or (H.FrameUsedSize < 0) Or (H.FrameUsedSize > H.FrameDataSize) Or
       (Int64(Q) + FH + H.FrameDataSize > Size) Then
      Exit;
    Out.Pos := Q;
    Out.Typ := H.FrameType;
    Out.Data := H.FrameDataSize;
    Out.Used := H.FrameUsedSize;
    ValidAt := True;
    End;

  Procedure AddGap(GPos, GLen: LongInt; Tail: Boolean);
    Begin
    If P^.NGaps >= P^.GapCap Then
      Begin
      P^.GapCap := P^.GapCap * 2;
      ReAllocMem(P^.Gaps, P^.GapCap * SizeOf(MerGap));
      End;
    P^.Gaps^[P^.NGaps].Pos := GPos;
    P^.Gaps^[P^.NGaps].Len := GLen;
    P^.Gaps^[P^.NGaps].Tail := Tail;
    Inc(P^.NGaps);
    End;

  Begin
  ScanFrames := True;
  GetMem(Chunk, 32768);
  If Chunk = Nil Then
    Begin
    ScanFrames := False;
    Exit;
    End;
  Pos := BaseLen;
  While Pos < Size Do
    Begin
    If ValidAt(Pos, Fr) Then
      Begin
      If P^.NFrames >= P^.FrameCap Then
        Begin
        P^.FrameCap := P^.FrameCap * 2;
        ReAllocMem(P^.Frames, P^.FrameCap * SizeOf(MerFrame));
        End;
      P^.Frames^[P^.NFrames] := Fr;
      Inc(P^.NFrames);
      Pos := Pos + FH + Fr.Data;
      End
    Else
      Begin                              {damage: look for the next frame header}
      Next := -1;
      At := Pos + 1;
      While (At < Size) And (Next < 0) Do
        Begin
        N := MerRd(F, At, 32768, Chunk^);
        If N < 4 Then
          Break;
        K := 0;
        While (K <= N - 4) And (Next < 0) Do
          Begin
          If MerGetL(Chunk, K) = mFrameId Then
            If ValidAt(At + K, Fr) Then
              Next := At + K;
          Inc(K);
          End;
        Inc(At, MerMax(1, N - 3));
        End;
      If Next < 0 Then
        Begin
        AddGap(Pos, Size - Pos, True);
        Break;
        End;
      AddGap(Pos, Next - Pos, False);
      Pos := Next;
      End;
    End;
  FreeMem(Chunk, 32768);
  End;


Function InspectMsg(Var F: File; Var Fr: MerFrame; Var M: MerLive): Boolean;
  {read a message frame completely: false if it is not a usable message}
  Var
    Buf: PMerBytes;
    Len: LongInt;
    Q: LongInt;
    Typ: LongInt;
    DLen: LongInt;
    Id: LongInt;
    Attr: LongInt;
    ToOfs: LongInt;
    ToLen: LongInt;
    H: DWord;
    G: DWord;
    i: LongInt;
    Bad: Boolean;

  Begin
  InspectMsg := False;
  If Fr.Used < 40 Then
    Exit;
  Len := FH + Fr.Used;
  GetMem(Buf, Len);
  If Buf = Nil Then
    Exit;
  If MerRd(F, Fr.Pos, Len, Buf^) < Len Then
    Begin
    FreeMem(Buf, Len);
    Exit;
    End;
  Id := MerGetL(Buf, 14);
  Attr := MerGetL(Buf, moAttr1);
  Bad := False;
  ToOfs := -1;
  ToLen := 0;
  Q := MH;
  While Q + 8 <= Len Do
    Begin
    Typ := MerGetL(Buf, Q);
    DLen := MerGetL(Buf, Q + 4);
    If (DLen < 0) Or (Q + 8 + DLen > Len) Then
      Begin
      Bad := True;
      Break;
      End;
    If (Typ = sfTo) And (ToOfs < 0) Then
      Begin
      ToOfs := Q + 8;
      ToLen := DLen;
      End;
    Inc(Q, 8 + DLen);
    End;
  If Q < Len Then
    Bad := True;
  If (Id <= 0) Or Bad Then
    Begin
    FreeMem(Buf, Len);
    Exit;
    End;
  H := 0;
  If ToOfs >= 0 Then
    For i := 0 To ToLen - 1 Do
      Begin
      H := (H Shl 4) + Ord(LoCase(Chr(Buf^[ToOfs + i])));
      G := H And $F0000000;
      If G <> 0 Then
        H := (H Or (G Shr 24)) Or G;
      End;
  M.Id := Id;
  M.Attr := Attr;
  M.Tot := MerGetL(Buf, 18);
  M.Hash := LongInt(H And HashMask) Or AttrBits(Attr);
  M.Pos := Fr.Pos;
  M.Used := Fr.Used;
  FreeMem(Buf, Len);
  InspectMsg := True;
  End;


Procedure SortMsgs(A: PMerLiveArr; N: LongInt);
  {shell sort by message number, then position}
  Var
    Gap: LongInt;
    i: LongInt;
    j: LongInt;
    T: MerLive;

  Function Less(Var X, Y: MerLive): Boolean;
    Begin
    Less := (X.Id < Y.Id) Or ((X.Id = Y.Id) And (X.Pos < Y.Pos));
    End;

  Begin
  Gap := N Div 2;
  While Gap > 0 Do
    Begin
    For i := Gap To N - 1 Do
      Begin
      T := A^[i];
      j := i;
      While (j >= Gap) And Less(T, A^[j - Gap]) Do
        Begin
        A^[j] := A^[j - Gap];
        Dec(j, Gap);
        End;
      A^[j] := T;
      End;
    Gap := Gap Div 2;
    End;
  End;


Procedure Layout(P: PMerPlan);
  {What is kept, what is free space (merged), what the end of the file is.
   Needs P^.Keep.  Sets P^.Regs, NRegs, EndPos, TailFree, Merges.}
  Var
    NT: LongInt;
    a: LongInt;
    b: LongInt;
    Take: Boolean;
    R: MerRegion;
    Prev: LongInt;
    Out: LongInt;
    i: LongInt;
    TotalLen: LongInt;
    Pos: LongInt;

  Begin
  NT := 0;
  P^.Merges := 0;
  P^.TailFree := False;
  a := 0;
  b := 0;
  While (a < P^.NFrames) Or (b < P^.NGaps) Do
    Begin
    Take := (b >= P^.NGaps) Or ((a < P^.NFrames) And (P^.Frames^[a].Pos < P^.Gaps^[b].Pos));
    If Take Then
      Begin                              {a frame}
      R.Pos := P^.Frames^[a].Pos;
      R.Total := FH + P^.Frames^[a].Data;
      R.Free := (P^.Keep^[a] = 0);
      R.Single := True;
      R.Fr := a;
      R.Grew := 0;
      P^.Tmp^[NT] := R;
      Inc(NT);
      Inc(a);
      End
    Else
      Begin                              {a gap}
      If Not P^.Gaps^[b].Tail Then
        Begin
        If P^.Gaps^[b].Len >= FH Then
          Begin
          R.Pos := P^.Gaps^[b].Pos;
          R.Total := P^.Gaps^[b].Len;
          R.Free := True;
          R.Single := False;
          R.Fr := -1;
          R.Grew := 0;
          P^.Tmp^[NT] := R;
          Inc(NT);
          End
        Else If NT > 0 Then
          Begin                          {a few stray bytes: part of the frame before}
          Inc(P^.Tmp^[NT - 1].Total, P^.Gaps^[b].Len);
          Inc(P^.Tmp^[NT - 1].Grew, P^.Gaps^[b].Len);
          End;
        End;
      Inc(b);
      End;
    End;
  Out := 0;
  For i := 0 To NT - 1 Do
    Begin
    If P^.Tmp^[i].Free And (Out > 0) And P^.Regs^[Out - 1].Free Then
      Begin
      Inc(P^.Regs^[Out - 1].Total, P^.Tmp^[i].Total);
      P^.Regs^[Out - 1].Single := False;
      Inc(P^.Merges);
      End
    Else
      Begin
      P^.Regs^[Out] := P^.Tmp^[i];
      Inc(Out);
      End;
    End;
  While (Out > 0) And P^.Regs^[Out - 1].Free Do
    Begin
    Dec(Out);
    P^.TailFree := True;
    End;
  P^.NRegs := Out;
  If Out > 0 Then
    P^.EndPos := P^.Regs^[Out - 1].Pos + P^.Regs^[Out - 1].Total
  Else
    P^.EndPos := BaseLen;
  End;


Function Analyze(Inf: PMerInfo; Var F: File; Size: LongInt; P: PMerPlan): Boolean;
  {What is wrong, and the plan to fix it (read only).  False on an I/O error
   or if this is not a Merlin base.}
  Var
    H: MerlinMsgBaseHdrType;
    i: LongInt;
    j: LongInt;
    N: LongInt;
    M: MerLive;
    Fr: LongInt;
    NMsgs: LongInt;
    Cands: Array[1..3] Of LongInt;       { chosen frame index of free list, index, last read }
    NC: Array[1..3] Of LongInt;
    t: Word;
    Chosen: LongInt;
    PtrWant: LongInt;
    NumCand: LongInt;
    PointIdx: PMerBytes;
    PointLen: LongInt;
    N0: Int64;
    Cur: LongInt;
    Win: LongInt;
    Lose: LongInt;
    A1: Boolean;
    B1: Boolean;
    MinId: LongInt;
    MaxIdL: LongInt;
    BaseId: Int64;
    SaneLast: Boolean;
    Last: Int64;
    Slots: Int64;
    Round: Word;
    Changed: Boolean;
    NFree: LongInt;
    LoExp: LongInt;
    Have: PMerBytes;
    Diff: LongInt;
    FreeBuf: PMerBytes;
    Missing: LongInt;
    Stale: LongInt;
    Found: Boolean;
    FL: MerlinFrameHdrType;
    RunStart: LongInt;
    AnyTail: Boolean;

  Procedure Bad(S: String);
    Begin
    Inc(P^.Problems);
    Prob(Inf, S);
    End;

  Function PickFrame(Typ: LongInt; Ptr: LongInt; Var Count: LongInt): LongInt;
    {the frame of this type at Ptr, else the last one of this type}
    Var
      k: LongInt;
      Best: LongInt;

    Begin
    Best := -1;
    Count := 0;
    For k := 0 To P^.NFrames - 1 Do
      If P^.Frames^[k].Typ = Typ Then
        Begin
        Inc(Count);
        If (Best < 0) Or (P^.Frames^[k].Pos = Ptr) Or
           ((P^.Frames^[Best].Pos <> Ptr) And (P^.Frames^[k].Pos > P^.Frames^[Best].Pos)) Then
          Best := k;
        End;
    PickFrame := Best;
    End;

  Function Pointed(Pos: LongInt): Boolean;
    Var
      k: LongInt;

    Begin
    Pointed := False;
    For k := 0 To PointLen Div Rec - 1 Do
      If MerGetL(PointIdx, k * Rec + 4) = Pos Then
        Begin
        Pointed := True;
        Exit;
        End;
    End;

  Begin
  Analyze := False;
  FillChar(P^, SizeOf(P^), 0);
  P^.FrameCap := 64;
  P^.GapCap := 16;
  GetMem(P^.Frames, P^.FrameCap * SizeOf(MerFrame));
  GetMem(P^.Gaps, P^.GapCap * SizeOf(MerGap));
  If (P^.Frames = Nil) Or (P^.Gaps = Nil) Then
    Exit;
  Inf^.ReportCnt := 0;
  Inf^.ReportMore := 0;
  N := MerRd(F, 0, BaseLen, H);
  If (N < BaseLen) Or (H.FrameHdr.FrameId <> mFrameId) Or (H.FrameHdr.FrameType <> mftMsgBaseHdr) Then
    Begin
    Inf^.Error := merNotMerlin;
    Exit;
    End;
  If BaseVersion(H) > FormatVer Then
    Begin
    Inf^.Error := merNewVersion;
    Exit;
    End;
  P^.Base := H;
  If (BaseFlags(H) And BfDirty) <> 0 Then
    Bad('a write was interrupted (the DIRTY flag is set)');
  If BaseVersion(H) < 1 Then
    Bad('version 0 layout (Repair converts it)');
  If Not ScanFrames(F, Size, P) Then
    Exit;
  For i := 0 To P^.NGaps - 1 Do
    If P^.Gaps^[i].Tail Then
      Bad(NumS(P^.Gaps^[i].Len) + ' bytes at ' + NumS(P^.Gaps^[i].Pos) + ' are not a frame (end of file)')
    Else
      Bad(NumS(P^.Gaps^[i].Len) + ' bytes at ' + NumS(P^.Gaps^[i].Pos) + ' are not a frame');
  P^.RegCap := P^.NFrames + P^.NGaps + 2;
  GetMem(P^.Msgs, P^.FrameCap * SizeOf(MerLive));
  GetMem(P^.Live, P^.FrameCap * SizeOf(MerLive));
  GetMem(P^.Keep, P^.FrameCap);
  GetMem(P^.Regs, P^.RegCap * SizeOf(MerRegion));
  GetMem(P^.Tmp, P^.RegCap * SizeOf(MerRegion));
  If (P^.Msgs = Nil) Or (P^.Live = Nil) Or (P^.Keep = Nil) Or (P^.Regs = Nil) Or (P^.Tmp = Nil) Then
    Exit;
  FillChar(P^.Keep^, P^.FrameCap, 0);
  { classify the frames }
  NMsgs := 0;
  For i := 0 To P^.NFrames - 1 Do
    Begin
    t := P^.Frames^[i].Typ;
    If (t = mftFreeFrame) Or (t = mftFreeList) Or (t = mftMsgIdx) Or (t = mftLastRead) Then
      Begin
      End
    Else
      Begin
      If Not InspectMsg(F, P^.Frames^[i], M) Then
        Begin
        Inc(P^.NotFree);
        Bad('unusable message frame at ' + NumS(P^.Frames^[i].Pos));
        End
      Else If (M.Attr And ma1Deleted) <> 0 Then
        Inc(P^.NotFree)
      Else
        Begin
        M.Fr := i;
        P^.Msgs^[NMsgs] := M;
        Inc(NMsgs);
        End;
      End;
    End;
  P^.NMsgs := NMsgs;
  P^.IdxF0 := PickFrame(mftMsgIdx, H.IdxPtr, NumCand);
  Inc(P^.NotFree, MerMax(0, NumCand - 1));
  If NumCand > 1 Then
    Bad(NumS(NumCand - 1) + ' extra index frames');
  P^.FreeF0 := PickFrame(mftFreeList, H.FreePtr, NumCand);
  Inc(P^.NotFree, MerMax(0, NumCand - 1));
  If NumCand > 1 Then
    Bad(NumS(NumCand - 1) + ' extra free list frames');
  P^.CandLr := PickFrame(mftLastRead, H.LastReadPtr, NumCand);
  Inc(P^.NotFree, MerMax(0, NumCand - 1));
  If NumCand > 1 Then
    Bad(NumS(NumCand - 1) + ' extra last read frames');
  { which frames does the current index point at }
  PointIdx := Nil;
  PointLen := 0;
  If P^.IdxF0 >= 0 Then
    Begin
    N0 := Int64(H.LastMsgId) + 1 - H.BaseMsgId;
    If (N0 >= 0) And (N0 * Rec <= P^.Frames^[P^.IdxF0].Data) Then
      Begin
      PointLen := N0 * Rec;
      GetMem(PointIdx, MerMax(PointLen, 1));
      If (PointIdx = Nil) Or ((PointLen > 0) And
         (MerRd(F, P^.Frames^[P^.IdxF0].Pos + FH, PointLen, PointIdx^) <> PointLen)) Then
        PointLen := 0;
      End;
    End;
  { one frame per message number: duplicates resolved }
  SortMsgs(P^.Msgs, NMsgs);
  P^.NLive := 0;
  i := 0;
  While i < NMsgs Do
    Begin
    Cur := i;
    j := i + 1;
    While (j < NMsgs) And (P^.Msgs^[j].Id = P^.Msgs^[i].Id) Do
      Begin
      A1 := (PointIdx <> Nil) And Pointed(P^.Msgs^[Cur].Pos);
      B1 := (PointIdx <> Nil) And Pointed(P^.Msgs^[j].Pos);
      If (B1 And (Not A1)) Or ((A1 = B1) And (P^.Msgs^[j].Pos > P^.Msgs^[Cur].Pos)) Then
        Win := j
      Else
        Win := Cur;
      Bad('message ' + NumS(P^.Msgs^[i].Id) + ' is in two frames (' + NumS(P^.Msgs^[Cur].Pos) +
        ' and ' + NumS(P^.Msgs^[j].Pos) + ')');
      Inc(P^.NotFree);
      Cur := Win;
      Inc(j);
      End;
    P^.Live^[P^.NLive] := P^.Msgs^[Cur];
    Inc(P^.NLive);
    i := j;
    End;
  If PointIdx <> Nil Then
    FreeMem(PointIdx, MerMax(PointLen, 1));
  For i := 0 To P^.NLive - 1 Do
    If P^.Live^[i].Tot <> FH + P^.Live^[i].Used Then
      Inc(P^.FixTot);
  If P^.FixTot > 0 Then
    Bad(NumS(P^.FixTot) + ' messages have a wrong TotMsgSize');
  If P^.NotFree > 0 Then
    Bad(NumS(P^.NotFree) + ' unused frames are not marked as free frames');
  { numbers }
  If P^.NLive > 0 Then
    Begin
    MinId := P^.Live^[0].Id;
    MaxIdL := P^.Live^[P^.NLive - 1].Id;
    End
  Else
    Begin
    MinId := 0;
    MaxIdL := 0;
    End;
  BaseId := H.BaseMsgId;
  If (BaseId > MaxId) Or (BaseId < 1) Or ((P^.NLive > 0) And (BaseId > MinId)) Or
     ((P^.NLive = 0) And (BaseId > Int64(H.LastMsgId) + 1)) Then
    Begin
    If P^.NLive > 0 Then
      BaseId := MinId
    Else
      BaseId := 1;
    End;
  SaneLast := (H.LastMsgId >= 0) And (Int64(H.LastMsgId) + 1 >= BaseId) And
    (Int64(H.LastMsgId) + 1 - BaseId <= 50000000);
  If SaneLast Then
    Last := MerMax(H.LastMsgId, MaxIdL)
  Else
    Last := MerMax(MaxIdL, BaseId - 1);
  Slots := Last + 1 - BaseId;
  P^.BaseId := BaseId;
  P^.Last := Last;
  P^.Slots := Slots;
  GetMem(P^.ExpIdx, MerMax(Slots * Rec, 1));
  If P^.ExpIdx = Nil Then
    Exit;
  FillChar(P^.ExpIdx^, MerMax(Slots * Rec, 1), 0);
  For i := 0 To P^.NLive - 1 Do
    Begin
    MerPutL(P^.ExpIdx, (P^.Live^[i].Id - BaseId) * Rec, P^.Live^[i].Hash);
    MerPutL(P^.ExpIdx, (P^.Live^[i].Id - BaseId) * Rec + 4, P^.Live^[i].Pos);
    End;
  { the layout: what is kept, what is free space }
  For i := 0 To P^.NLive - 1 Do
    P^.Keep^[P^.Live^[i].Fr] := 1;
  If P^.CandLr >= 0 Then
    P^.Keep^[P^.CandLr] := 1;
  P^.IdxF := P^.IdxF0;
  P^.FreeF := P^.FreeF0;
  For Round := 1 To 4 Do
    Begin
    FillChar(P^.Keep^[0], 0, 0);
    For i := 0 To P^.NFrames - 1 Do
      If (i = P^.IdxF) Or (i = P^.FreeF) Or (i = P^.CandLr) Then
        P^.Keep^[i] := 1
      Else If P^.Keep^[i] = 1 Then
        Begin
        { live messages stay kept }
        End;
    Layout(P);
    Changed := False;
    If (P^.IdxF >= 0) And (P^.Frames^[P^.IdxF].Data Div Rec < Slots) Then
      Begin
      P^.Keep^[P^.IdxF] := 0;
      P^.IdxF := -1;
      Changed := True;
      End;
    NFree := 0;
    For i := 0 To P^.NRegs - 1 Do
      If P^.Regs^[i].Free Then
        Inc(NFree);
    If (P^.FreeF >= 0) And (P^.Frames^[P^.FreeF].Data Div Rec < NFree) Then
      Begin
      P^.Keep^[P^.FreeF] := 0;
      P^.FreeF := -1;
      Changed := True;
      End;
    If Not Changed Then
      Break;
    End;
  P^.NFreeRegs := 0;
  For i := 0 To P^.NRegs - 1 Do
    If P^.Regs^[i].Free Then
      Inc(P^.NFreeRegs);
  { compare }
  If P^.Merges > 0 Then
    Bad(NumS(P^.Merges) + ' free frames are next to each other');
  AnyTail := False;
  For i := 0 To P^.NGaps - 1 Do
    If P^.Gaps^[i].Tail Then
      AnyTail := True;
  If P^.TailFree And (Not AnyTail) Then
    Bad('free space at the end of the file');
  If P^.IdxF0 < 0 Then
    Bad('there is no index frame')
  Else
    Begin
    If P^.IdxF <> P^.IdxF0 Then
      Bad('the index frame has room for ' + NumS(P^.Frames^[P^.IdxF0].Data Div Rec) +
        ' records, ' + NumS(Slots) + ' are needed')
    Else
      Begin
      If H.IdxPtr <> P^.Frames^[P^.IdxF].Pos Then
        Bad('IdxPtr does not point at the index frame');
      If P^.Frames^[P^.IdxF].Used <> Slots * Rec Then
        Bad('the used size of the index frame is wrong');
      GetMem(Have, MerMax(Slots * Rec, 1));
      FillChar(Have^, MerMax(Slots * Rec, 1), 0);
      If Slots > 0 Then
        If MerRd(F, P^.Frames^[P^.IdxF].Pos + FH, Slots * Rec, Have^) < 0 Then;
      Diff := 0;
      For i := 0 To Slots - 1 Do
        If (MerGetL(Have, i * Rec) <> MerGetL(P^.ExpIdx, i * Rec)) Or
           (MerGetL(Have, i * Rec + 4) <> MerGetL(P^.ExpIdx, i * Rec + 4)) Then
          Inc(Diff);
      FreeMem(Have, MerMax(Slots * Rec, 1));
      If Diff > 0 Then
        Bad(NumS(Diff) + ' index records differ from the message frames');
      End;
    End;
  If H.BaseMsgId <> BaseId Then
    Bad('BaseMsgId ' + NumS(H.BaseMsgId) + ' should be ' + NumS(BaseId));
  If H.LastMsgId <> Last Then
    Bad('LastMsgId ' + NumS(H.LastMsgId) + ' should be ' + NumS(Last));
  If H.NumMsgs <> P^.NLive Then
    Bad('NumMsgs ' + NumS(H.NumMsgs) + ' should be ' + NumS(P^.NLive));
  If (H.FreePtr <> 0) <> (P^.FreeF0 >= 0) Then
    Bad('FreePtr does not point at the free list frame')
  Else If (P^.FreeF0 >= 0) And (H.FreePtr <> P^.Frames^[P^.FreeF0].Pos) Then
    Bad('FreePtr does not point at the free list frame');
  If (H.LastReadPtr <> 0) <> (P^.CandLr >= 0) Then
    Bad('LastReadPtr does not point at the last read frame')
  Else If (P^.CandLr >= 0) And (H.LastReadPtr <> P^.Frames^[P^.CandLr].Pos) Then
    Bad('LastReadPtr does not point at the last read frame');
  { the free list against the free space }
  Missing := 0;
  Stale := 0;
  FreeBuf := Nil;
  N := 0;
  If P^.FreeF0 >= 0 Then
    Begin
    N := P^.Frames^[P^.FreeF0].Data Div Rec;
    GetMem(FreeBuf, MerMax(N * Rec, 1));
    FillChar(FreeBuf^, MerMax(N * Rec, 1), 0);
    If N > 0 Then
      If MerRd(F, P^.Frames^[P^.FreeF0].Pos + FH, N * Rec, FreeBuf^) < 0 Then;
    End;
  For i := 0 To P^.NRegs - 1 Do
    If P^.Regs^[i].Free Then
      Begin
      Found := False;
      For j := 0 To N - 1 Do
        If (MerGetL(FreeBuf, j * Rec + 4) = P^.Regs^[i].Pos) And
           (MerGetL(FreeBuf, j * Rec) = P^.Regs^[i].Total - FH) Then
          Found := True;
      If Not Found Then
        Inc(Missing);
      End;
  For j := 0 To N - 1 Do
    If MerGetL(FreeBuf, j * Rec + 4) <> 0 Then
      Begin
      Found := False;
      For i := 0 To P^.NRegs - 1 Do
        If P^.Regs^[i].Free And (P^.Regs^[i].Pos = MerGetL(FreeBuf, j * Rec + 4)) And
           (P^.Regs^[i].Total - FH = MerGetL(FreeBuf, j * Rec)) Then
          Found := True;
      If Not Found Then
        Inc(Stale);
      End;
  If FreeBuf <> Nil Then
    FreeMem(FreeBuf, MerMax(N * Rec, 1));
  If (Missing > 0) Or (Stale > 0) Then
    Bad('the free list does not match the free space (' + NumS(Missing) + ' missing, ' +
      NumS(Stale) + ' wrong)');
  Analyze := True;
  End;


Procedure ApplyRepair(C: PMerCtx; P: PMerPlan);
  {carry out an Analyze plan inside the file lock}
  Var
    i: LongInt;
    EndP: LongInt;
    IdxPos: LongInt;
    IdxData: LongInt;
    FreePos: LongInt;
    FreeData: LongInt;
    Buf: PMerBytes;
    HdrRec: MerlinFrameHdrType;
    Lo: LongInt;
    k: LongInt;
    Nb: MerlinMsgBaseHdrType;
    Fr: MerFrame;
    N: LongInt;

  Begin
  { 1. frame headers: free space as free frames (merged), frames that
       swallowed stray bytes }
  For i := 0 To P^.NRegs - 1 Do
    Begin
    If P^.Regs^[i].Free Then
      Begin
      If P^.Regs^[i].Fr >= 0 Then
        Fr := P^.Frames^[P^.Regs^[i].Fr]
      Else
        Fr.Typ := 0;
      If Not (P^.Regs^[i].Single And (P^.Regs^[i].Fr >= 0) And (Fr.Typ = mftFreeFrame) And
         (Fr.Data = P^.Regs^[i].Total - FH) And (Fr.Used = 0)) Then
        Begin
        MakeFrameHdr(HdrRec, mftFreeFrame, P^.Regs^[i].Total - FH, 0);
        CPoke(C, P^.Regs^[i].Pos, FH, HdrRec, False);
        End;
      End
    Else If P^.Regs^[i].Grew > 0 Then
      Begin
      Fr := P^.Frames^[P^.Regs^[i].Fr];
      MakeFrameHdr(HdrRec, Fr.Typ, Fr.Data + P^.Regs^[i].Grew, Fr.Used);
      CPoke(C, P^.Regs^[i].Pos, FH, HdrRec, False);
      End;
    End;
  { 2. the index and the free list: in place if they have room, else new
       frames at the end }
  EndP := P^.EndPos;
  If P^.IdxF >= 0 Then
    Begin
    IdxPos := P^.Frames^[P^.IdxF].Pos;
    IdxData := P^.Frames^[P^.IdxF].Data;
    End
  Else
    Begin
    IdxData := MerMax(64, P^.Slots * 2);
    If P^.Base.MaxMsgs > 0 Then
      IdxData := MerMax(IdxData, P^.Base.MaxMsgs + 16);
    IdxData := IdxData * Rec;
    IdxPos := EndP;
    Inc(EndP, FH + IdxData);
    End;
  GetMem(Buf, FH + IdxData);
  FillChar(Buf^, FH + IdxData, 0);
  MakeFrameHdr(HdrRec, mftMsgIdx, IdxData, P^.Slots * Rec);
  Move(HdrRec, Buf^, FH);
  If P^.Slots > 0 Then
    Move(P^.ExpIdx^, Buf^[FH], P^.Slots * Rec);
  CPoke(C, IdxPos, FH + IdxData, Buf^, False);
  FreeMem(Buf, FH + IdxData);
  FreePos := 0;
  FreeData := 0;
  If P^.FreeF >= 0 Then
    Begin
    FreePos := P^.Frames^[P^.FreeF].Pos;
    FreeData := P^.Frames^[P^.FreeF].Data;
    End
  Else If P^.NFreeRegs > 0 Then
    Begin
    FreeData := MerMax(32, P^.NFreeRegs * 2) * Rec;
    FreePos := EndP;
    Inc(EndP, FH + FreeData);
    End;
  If FreePos <> 0 Then
    Begin
    GetMem(Buf, FH + FreeData);
    FillChar(Buf^, FH + FreeData, 0);
    MakeFrameHdr(HdrRec, mftFreeList, FreeData, FreeData);
    Move(HdrRec, Buf^, FH);
    k := 0;
    For i := 0 To P^.NRegs - 1 Do
      If P^.Regs^[i].Free Then
        Begin
        MerPutL(Buf, FH + k * Rec, P^.Regs^[i].Total - FH);
        MerPutL(Buf, FH + k * Rec + 4, P^.Regs^[i].Pos);
        Inc(k);
        End;
    CPoke(C, FreePos, FH + FreeData, Buf^, False);
    FreeMem(Buf, FH + FreeData);
    End;
  For i := 0 To P^.NLive - 1 Do
    If P^.Live^[i].Tot <> FH + P^.Live^[i].Used Then
      CPokeL(C, P^.Live^[i].Pos + 18, FH + P^.Live^[i].Used);
  { 3. the base header, last }
  Lo := -1;
  i := 0;
  While (i < P^.Slots) And (Lo < 0) Do
    Begin
    If (MerGetL(P^.ExpIdx, i * Rec + 4) <> 0) And ((MerGetL(P^.ExpIdx, i * Rec) And IxExport) <> 0) Then
      Lo := P^.BaseId + i;
    Inc(i);
    End;
  Nb := P^.Base;
  Nb.LastMsgId := P^.Last;
  Nb.IdxPtr := IdxPos;
  Nb.FreePtr := FreePos;
  If P^.CandLr >= 0 Then
    Nb.LastReadPtr := P^.Frames^[P^.CandLr].Pos
  Else
    Nb.LastReadPtr := 0;
  Nb.BaseMsgId := P^.BaseId;
  Nb.NumMsgs := P^.NLive;
  If Lo < 0 Then
    Nb.LastMsgScanned := P^.Last
  Else
    Nb.LastMsgScanned := Lo - 1;
  SetBaseExtra(Nb, BaseVersion(Nb), BaseFlags(Nb) And (Not BfDirty), BaseGen(Nb));
  C^.Base := Nb;
  CFinish(C, EndP, True);
  End;


Function RepairIn(Inf: PMerInfo; C: PMerCtx; OnlyIfNeeded: Boolean;
  Var Fixed: Boolean): Boolean;
  {inside the file lock: repair if Check finds anything}
  Var
    P: PMerPlan;
    Ok: Boolean;

  Begin
  Fixed := False;
  RepairIn := False;
  New(P);
  If P = Nil Then
    Begin
    C^.Err := merWriteErr;
    Exit;
    End;
  Ok := Analyze(Inf, C^.F^, C^.Phys, P);
  If Not Ok Then
    Begin
    If C^.Err = 0 Then
      If Inf^.Error <> 0 Then
        C^.Err := Inf^.Error
      Else
        C^.Err := merReadErr;
    PlanFree(P);
    Dispose(P);
    Exit;
    End;
  If P^.Problems = 0 Then
    RepairIn := True
  Else
    Begin
    ApplyRepair(C, P);
    Fixed := (C^.Err = 0);
    RepairIn := (C^.Err = 0);
    End;
  PlanFree(P);
  Dispose(P);
  End;


Function CheckIn(Inf: PMerInfo; C: PMerCtx): Boolean;
  Var
    P: PMerPlan;
    Ok: Boolean;

  Begin
  CheckIn := False;
  New(P);
  If P = Nil Then
    Exit;
  Ok := Analyze(Inf, C^.F^, C^.Phys, P);
  If Ok Then
    CheckIn := (P^.Problems = 0)
  Else If Inf^.Error = 0 Then
    Inf^.Error := merReadErr;
  PlanFree(P);
  Dispose(P);
  End;


Function MerlinMsgObj.Check: Boolean;
  {True if the base is clean.  The problems found are in MInfo^.Report.}
  Var
    Own: Boolean;
    Err: Word;
    C: PMerCtx;

  Begin
  Check := False;
  MInfo^.Error := 0;
  MInfo^.ReportCnt := 0;
  MInfo^.ReportMore := 0;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  Own := Not MInfo^.Locked;
  If Own And (Not MInfo^.ReadOnly) Then
    Begin
    Err := GetLock;
    If Err <> 0 Then
      Begin
      MInfo^.Error := Err;
      Exit;
      End;
    End
  Else
    Own := False;
  C := CNew(MInfo^.MsgFile, MInfo^.Sync);
  If C <> Nil Then
    Begin
    CRebase(C);
    Check := CheckIn(MInfo, C);
    CDispose(C);
    End;
  If Own Then
    ReleaseLock;
  End;


Function MerlinMsgObj.Repair: Boolean;
  {Rebuild the index, free list and base header from the frames.  True if the
   base is fine now (repaired, or nothing to repair).  What was wrong is in
   MInfo^.Report.}
  Var
    Err: Word;
    Fixed: Boolean;
    Ok: Boolean;
    C: PMerCtx;
    Own: Boolean;

  Begin
  Repair := False;
  MInfo^.Error := 0;
  MInfo^.ReportCnt := 0;
  MInfo^.ReportMore := 0;
  If Not MInfo^.BaseOpened Then
    Begin
    MInfo^.Error := merNotOpen;
    Exit;
    End;
  If MInfo^.ReadOnly Then
    Begin
    MInfo^.Error := merWriteErr;
    Exit;
    End;
  Own := Not MInfo^.Locked;
  If Own Then
    Begin
    Err := GetLock;
    If Err <> 0 Then
      Begin
      MInfo^.Error := Err;
      Exit;
      End;
    End;
  C := CNew(MInfo^.MsgFile, MInfo^.Sync);
  If C = Nil Then
    Begin
    If Own Then
      ReleaseLock;
    MInfo^.Error := merWriteErr;
    Exit;
    End;
  CRebase(C);
  Fixed := False;
  Ok := RepairIn(MInfo, C, False, Fixed);
  If C^.Err <> 0 Then
    Begin
    CRollback(C);
    MInfo^.Error := C^.Err;
    Ok := False;
    End;
  CDispose(C);
  If Own Then
    ReleaseLock;
  MInfo^.StampOk := False;
  MInfo^.Found := False;
  Repair := Ok;
  End;


End.
