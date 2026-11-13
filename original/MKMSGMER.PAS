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
     The Merlin message base was designed to be flexible, fast,
     and reliable.

     1.  To minimize access time on DOS FAT systems, all information
         for a message base is kept in one file.
     2.  To eliminate the need for taking a message base down for
         packing, freed space in the message base is recycled.
     3.  To allow for future expansion a system of subfields are
         included.
     4.  For reliability each "frame" starts with a frame-id.

}


Interface


Uses MKGlobT, MKMsgAbs,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}


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
  LastMsgScanned: LongInt;             { highest msgid scanned for export }
  MaxMsgs: LongInt;                    { maximum desired msgs in msg base }
  NumMsgs: LongInt;                    { number of active and deleted msgs }
  BaseMsgId: LongInt;                  { msgid of first idx record }
  DateCreated: LongInt;                { unix-style time stamp }
  DisplayMsgOffset: LongInt;           { subtract for display msg number }
  Extra: Array[1..78] of Char;         { for future expansion }
  End;


Type MerlinMsgHdrType = Record         { header for each message }
  FrameHdr: MerlinFrameHdrType;        { normal frame header }
  MsgNum: LongInt;                     { msgid-ie message number }
  TotMsgSize: LongInt;                 { total size of msg }
  ReplyTo: LongInt;                    { orig msgid generating this reply }
  ReplyFirst: LongInt;                 { first reply msgid to this msg }
  ReplyNext: LongInt;                  { link chain of reply msg ids }
  DateWritten: LongInt;                { unix time stamp }
  DateProcessed: LongInt;              { unix time stamp }
  Attr1: LongInt;                      { message attribute flags }
  Attr2: LongInt;                      { additional message attribute flags }
  Cost: LongInt;                       { cost }
  End;


Type MerlinIdxType = Record            { msg index record for one msg }
  NameHash: LongInt;                   { hash of to name }
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


Const MerlinIdxBufSize = 500;          { internal memory buffer size }


Type MerlinIdxBuf = Record
  Frame: MerlinFrameHdrType;           { Normal frame header }
  Idx: Array[1..MerlinIdxBufSize] of MerlinIdxType; { Buffer for index }
  End;


Const MerlinFreeBufSize = 500;         { internal memory buffer size }


Type MerlinFreeBuf = Record
  Frame: MerlinFrameHdrType;           { Normal frame header }
  FreeIdx: Array[1..MerlinFreeBufSize] of MerlinFreeListType; { buffer }
  End;


Type MerlinInfoType = Record           { Temp storage to access base }
  FN: String[128];                     { Path and file name }
  Error: Word;                         { Access error code }
  MsgFile: File;                       { File handle for msg base }
  BaseOpened: Boolean;                 { Has msg base been opened }
  Locked: Boolean;                     { Has msg base been locked }
  LockCount: Integer;                  { Count of locks for unlocking }
  MsgDone: Boolean;                    { End of message flag }
  TxtPos: LongInt;                     { Text position counter }
  TxtLen: LongInt;                     { Length of text }
  MsgBaseHdr: MerlinMsgBaseHdrType;    { Msg base header }
  MsgHdr: MerlinMsgHdrType;            { Msg header for current message }
  MsgFrom: String[128];                { Current msg is from }
  MsgTo: String[128];                  { Current msg is to }
  MsgSubj: String[128];                { Current msg subject }
  {$IFDEF WINDOWS}
    MsgDT: TDateTime;                  { Current msg date/time written }
  {$ELSE}
    MsgDT: DateTime;                   { Current msg date/time written }
  {$ENDIF}
  Orig: AddrType;                      { FTN from address }
  Dest: AddrType;                      { FTN to address }
  IdxBuf: MerlinIdxBuf;                { Index buffer }
  FreeBuf: MerlinFreeBuf;              { Free list buffer }
  IdxStart: LongInt;                   { Idx start msg number }
  IdxRead: Word;                       { Nbr of index records read }
  FreeStart: Word;                     { Free buffer start offset }
  FreeRead: Word;                      { Nbr of free list records read }
  End;


Type MerlinMsgObj = Object(AbsMsgObj)
  MInfo: ^MerlinInfoType;
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
  Procedure SetAttr1(tf: Boolean; Mask: LongInt);
  Procedure SetAttr2(tf: Boolean; Mask: LongInt);
  Procedure ReadIdx(StartNum: LongInt);
  Procedure ReadFree(FreeOffset: Word);
  End;


Type MerlinMsgPtr = ^MerlinMsgObj;


Implementation


Uses MKFile, MKString, MKMisc, MKDos;

Const
  mFrameId = $424d4b4d;                {FrameHdr.FrameId}


Const                                  {FrameHdr.FrameType}
  mftMsgBaseHdr  =   1;                {Message base header}
  mftFreeList    =   2;                {Free frame list index}
  mftMsg         =   3;                {Message}
  mftMsgIdx      =   4;                {Message index}
  mftLastRead    =   5;                {Lastread records}


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


Const                                  { sub field type values }
  sfNone           = 0000;             { none - ignore }
  sfFrom           = 0002;             { msg from name }
  sfTo             = 0003;             { msg to name }
  sfMsgId          = 0004;             { msgid }
  sfReplyId        = 0005;             { reply }
  sfSubj           = 0006;             { subject }
  sfPID            = 0007;             { space wasting PID line }
  sfVia            = 0008;             { via }
  sfKludge         = 2000;             { FTN space wasting unknown kludge line }
  sfSeenby         = 2001;             { FTN seenby }
  sfPath           = 2002;             { FTN Path }
  sfFlags          = 2003;             { FTN Flags }
  sfText           = 9000;             { Normal message text }


Constructor MerlinMsgObj.Init;         { allocate memory and initialize }
  Begin
  New(MInfo);
  If MInfo = Nil Then
    Begin
    Fail;
    Exit;
    End;
  FillChar(MInfo^, SizeOf(MInfo^), #0);
  End;


Destructor MerlinMsgObj.Done;          { deallocate memory and clean up }
  Begin
  If MInfo^.BaseOpened Then
    MInfo^.Error := CloseMsgBase;
  Dispose(MInfo);
  End;


Procedure MerlinMsgObj.SetMsgPath(MP: String); { set file path and name }
  Begin
  MInfo^.FN := MP;
  End;


Function MerlinMsgObj.OpenMsgBase: Word; { open message base }
  Var
    NumRead: Word;

  Begin
  MInfo^.Error := 0;
  If Length(MInfo^.FN) = 0 Then
    MInfo^.Error := 140;
  If MInfo^.Error = 0 Then
    Begin
    Assign(MInfo^.MsgFile, MInfo^.FN);
    Reset(MInfo^.MsgFile, 1);
    MInfo^.Error := IoResult;
    End;
  If MInfo^.Error = 0 Then
    Begin
    If Not shRead(MINfo^.MsgFile, MInfo^.MsgBaseHdr,
      SizeOf(MInfo^.MsgBaseHdr), NumRead) Then
      MInfo^.Error := 120;
    End;
  If MInfo^.Error = 0 Then
    Begin
    If ((MInfo^.MsgBaseHdr.FrameHdr.FrameId <> mFrameId) or
    (MInfo^.MsgBaseHdr.FrameHdr.FrameType <> mftMsgBaseHdr)) Then
      MInfo^.Error := 1000;
    End;
  OpenMsgBase := MInfo^.Error;
  End;


Function MerlinMsgObj.CloseMsgBase: Word; { Close message base }
  Begin
  If MInfo^.Locked Then
    Begin
    If Not UnLockMsgBase Then;
    End;
  Close(MInfo^.MsgFile);
  CloseMsgBase := IoResult;
  End;


Function MerlinMsgObj.LockMsgBase: Boolean; { Lock message base }
  Var
    NumRead: Word;

  Begin
  If MInfo^.LockCount = 0 Then
    Begin
    MInfo^.Error := 0;
    If Not MInfo^.BaseOpened Then
      MInfo^.Error := 110;
    If MInfo^.Error = 0 Then
      MInfo^.Error := shLock(MInfo^.MsgFile, $ffffffff, 1);
    If MInfo^.Error = 0 Then
      Begin
      Seek(MInfo^.MsgFile, 0);
      MInfo^.Error := IoResult;
      End;
    If MInfo^.Error = 0 Then
      Begin
      If Not shRead(MINfo^.MsgFile, MInfo^.MsgBaseHdr,
        SizeOf(MInfo^.MsgBaseHdr), NumRead) Then
        MInfo^.Error := 120;
      End;
    If MInfo^.Error = 0 Then
      Begin
      If ((MInfo^.MsgBaseHdr.FrameHdr.FrameId <> mFrameId) or
      (MInfo^.MsgBaseHdr.FrameHdr.FrameType <> mftMsgBaseHdr)) Then
        MInfo^.Error := 1000;
      End;
    If MInfo^.Error = 0 Then
      Inc(MInfo^.LockCount);
    LockMsgBase := MInfo^.Error = 0;
    End
  Else
    Begin
    Inc(MInfo^.LockCount);
    LockMsgBase := True;
    End;
  End;


Function MerlinMsgObj.UnLockMsgBase: Boolean; { Unlock message base }
  Begin
  If MInfo^.LockCount > 1 Then
    Begin
    Dec(MInfo^.LockCount);
    UnLockMsgBase := True;
    End
  Else
    Begin
    If MInfo^.Locked Then
      MInfo^.Error := 0
    Else
      MInfo^.Error := 5;
    If MInfo^.Error = 0 Then
      Begin
      Seek(MInfo^.MsgFile, 0);
      MInfo^.Error := IoResult;
      End;
    If MInfo^.Error = 0 Then
      Begin
      If Not shWrite(MInfo^.MsgFile, MInfo^.MsgBaseHdr,
        SizeOf(MInfo^.MsgBaseHdr)) Then
        MInfo^.Error := 130;
      End;
    If MInfo^.Error = 0 Then
      MInfo^.Error := UnLockFile(MInfo^.MsgFile, $ffffffff, 1);
    If MInfo^.Error = 0 Then
      MInfo^.LockCount := 0;
    UnLockMsgBase := MInfo^.Error = 0;
    End;
  End;


Procedure MerlinMsgObj.SetDest(Var Addr: AddrType); { Set FTN destination }
  Begin
  MInfo^.Dest := Addr;
  End;


Procedure MerlinMsgObj.SetOrig(Var Addr: AddrType); { Set FTN orig addr }
  Begin
  MInfo^.Orig := Addr;
  End;


Procedure MerlinMsgObj.SetFrom(Name: String);       { Set from name }
  Begin
  MInfo^.MsgFrom := Proper(Name);
  End;


Procedure MerlinMsgObj.SetTo(Name: String);         { Set to name }
  Begin
  MInfo^.MsgTo := Name;
  End;


Procedure MerlinMsgObj.SetSubj(Str: String);        { set subject }
  Begin
  MInfo^.MsgSubj := Str;
  End;


Procedure MerlinMsgObj.SetCost(SCost: Word);        { set cost }
  Begin
  MInfo^.MsgHdr.Cost := SCost;
  End;


Procedure MerlinMsgObj.SetAttr1(tf: Boolean; Mask: LongInt);
  { internal use for setting message attributes }
  Begin
  If tf Then
    MInfo^.MsgHdr.Attr1 := MInfo^.MsgHdr.Attr1 or Mask
  Else
    MInfo^.MsgHdr.Attr1 := MInfo^.MsgHdr.Attr1 and (Not Mask);
  End;


Procedure MerlinMsgObj.SetAttr2(tf: Boolean; Mask: LongInt);
  { internal use for setting message attributes }
  Begin
  If tf Then
    MInfo^.MsgHdr.Attr2 := MInfo^.MsgHdr.Attr2 or Mask
  Else
    MInfo^.MsgHdr.Attr2 := MInfo^.MsgHdr.Attr2 and (Not Mask);
  End;


Procedure MerlinMsgObj.SetRefer(SRefer: LongInt);
  Begin
  MInfo^.MsgHdr.ReplyTo := SRefer;
  End;


Procedure MerlinMsgObj.SetSeeAlso(SAlso: LongInt);
  Begin
  MInfo^.MsgHdr.ReplyFirst := SAlso;
  End;


Procedure MerlinMsgObj.SetDate(SDate: String);
  Begin
  MInfo^.MsgDT.Month := Str2Long(Copy(SDate,1,2));
  MInfo^.MsgDT.Day := Str2Long(Copy(SDate,4,2));
  MInfo^.MsgDT.Year := Str2Long(Copy(SDate,7,2));
  End;


Procedure MerlinMsgObj.SetTime(STime: String);
  Begin
  MInfo^.MsgDT.Hour := Str2Long(Copy(STime, 1, 2));
  MInfo^.MsgDT.Min := Str2Long(Copy(STime, 4, 2));
  If Length(STime) >= 8 Then
    MInfo^.MsgDT.Sec := Str2Long(Copy(STime, 7, 2))
  Else
    MInfo^.MsgDT.Sec := 0;
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


Procedure MerlinMsgObj.DoChar(Ch: Char);
  Begin
  { ** }
  End;


Function MerlinMsgObj.WriteMsg: Word;
  Begin
  { ** }
  End;


Function MerlinMsgObj.GetChar: Char;
  Begin
  { ** }
  End;


Function MerlinMsgObj.EOM: Boolean;
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.SeekFirst(MsgNum: LongInt);
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.SeekNext;
  Begin
  { ** }
  End;


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
  GetCost := MInfo^.MsgHdr.Cost;
  End;


Function MerlinMsgObj.GetDate: String;
  Begin
  GetDate := FormattedDate(MInfo^.MsgDT, 'MM/DD/YY');
  End;


Function MerlinMsgObj.GetTime: String;
  Begin
  GetTime := FormattedDate(MInfo^.MsgDT, 'HH:II:SS');
  End;


Function MerlinMsgObj.GetRefer: LongInt;
  Begin
  GetRefer := MInfo^.MsgHdr.ReplyTo;
  End;


Function MerlinMsgObj.GetSeeAlso: LongInt;
  Begin
  GetSeeAlso := MInfo^.MsgHdr.ReplyFirst;
  End;


Function MerlinMsgObj.GetMsgNum: LongInt;
  Begin
  { ** }
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
  IsLocal := (MInfo^.MsgHdr.Attr1 and ma1Local) <> 0;
  End;


Function MerlinMsgObj.IsCrash: Boolean;
  Begin
  IsCrash := (MInfo^.MsgHdr.Attr1 and ma1Crash) <> 0;
  End;


Function MerlinMsgObj.IsKillSent: Boolean;
  Begin
  IsKillSent := (MInfo^.MsgHdr.Attr1 and ma1KillSent) <> 0;
  End;


Function MerlinMsgObj.IsSent: Boolean;
  Begin
  IsSent := (MInfo^.MsgHdr.Attr1 and ma1Sent) <> 0;
  End;


Function MerlinMsgObj.IsFAttach: Boolean;
  Begin
  IsFAttach := (MInfo^.MsgHdr.Attr1 and ma1FAttach) <> 0;
  End;


Function MerlinMsgObj.IsReqRct: Boolean;
  Begin
  IsReqRct := (MInfo^.MsgHdr.Attr1 and ma1ReqRcpt) <> 0;
  End;


Function MerlinMsgObj.IsReqAud: Boolean;
  Begin
  IsReqAud := (MInfo^.MsgHdr.Attr1 and ma1ReqAud) <> 0;
  End;


Function MerlinMsgObj.IsRetRct: Boolean;
  Begin
  IsRetRct := (MInfo^.MsgHdr.Attr1 and ma1RetRcpt) <> 0;
  End;


Function MerlinMsgObj.IsFileReq: Boolean;
  Begin
  IsFileReq := (MInfo^.MsgHdr.Attr1 and ma1Freq) <> 0;
  End;


Function MerlinMsgObj.IsRcvd: Boolean;
  Begin
  IsRcvd := (MInfo^.MsgHdr.Attr1 and ma1Rcvd) <> 0;
  End;


Function MerlinMsgObj.IsPriv: Boolean;
  Begin
  IsPriv := (MInfo^.MsgHdr.Attr1 and ma1Priv) <> 0;
  End;


Function MerlinMsgObj.IsDeleted: Boolean;
  Begin
  IsDeleted := (MInfo^.MsgHdr.Attr1 and ma1Deleted) <> 0;
  End;


Function MerlinMsgObj.IsEchoed: Boolean;
  Begin
  IsEchoed := (MInfo^.MsgHdr.Attr1 and ma1ToBeExported) <> 0;
  End;


Function MerlinMsgObj.GetMsgLoc: LongInt;
  Begin
  GetMsgLoc := GetMsgNum;
  End;


Procedure MerlinMsgObj.SetMsgLoc(ML: LongInt);
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.MsgStartUp;
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.MsgTxtStartUp;
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.YoursFirst(Name: String; Handle: String);
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.YoursNext;
  Begin
  { ** }
  End;


Function MerlinMsgObj.YoursFound: Boolean;
  Begin
  { ** }
  End;


Function MerlinMsgObj.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word;
  Var
    Error: Word;
    MsgsLeft: LongInt;
    MsgsNow: LongInt;


  Begin
  Error := 0;
  If Length(MInfo^.FN) > 0 Then
    Begin
    FillChar(MInfo^.MsgBaseHdr, SizeOf(MInfo^.MsgBaseHdr), #0);
    MInfo^.MsgBaseHdr.FrameHdr.FrameId := mFrameId;
    MInfo^.MsgBaseHdr.FrameHdr.FrameType := mftMsgBaseHdr;
    MInfo^.MsgBaseHdr.FrameHdr.FrameDataSize := SizeOf(MerlinMsgBaseHdrType);
    MInfo^.MsgBaseHdr.FrameHdr.FrameUsedSize := SizeOf(MerlinMsgBaseHdrType);
    MInfo^.MsgBaseHdr.MaxMsgs := MaxMsg;
    MInfo^.MsgBaseHdr.DateCreated := ToUnixDate(GetDosDate);
    MInfo^.MsgBaseHdr.IdxPtr := SizeOf(MerlinMsgBaseHdrType);
    Assign(MInfo^.MsgFile, MInfo^.FN);
    ReWrite(MInfo^.MsgFile, 1);
    Error := IoResult;
    If Error = 0 Then
      Begin
      BlockWrite(MInfo^.MsgFile, MInfo^.MsgBaseHdr, SizeOf(MINfo^.MsgBaseHdr));
      Error := IoResult;
      End;
    If Error = 0 Then
      Begin
      MInfo^.IdxBuf.Frame.FrameId := mFrameId;
      MInfo^.IdxBuf.Frame.FrameType := mftMsgIdx;
      MInfo^.IdxBuf.Frame.FrameDataSize := LongInt(MaxMsg) *
        SizeOf(MerlinIdxType);
      MInfo^.IdxBuf.Frame.FrameUsedSize := MInfo^.IdxBuf.Frame.FrameDataSize;
      FillChar(MInfo^.IdxBuf.Idx, SizeOf(MInfo^.IdxBuf.Idx), #0);
      MsgsLeft := MaxMsg;
      BlockWrite(MInfo^.MsgFile, MInfo^.IdxBuf.Frame, SizeOf(
        MInfo^.IdxBuf.Frame));
      Error := IoResult;
      While ((MsgsLeft >= 0) and (Error = 0)) Do
        Begin
        MsgsNow := MsgsLeft;
        If MsgsNow > MerlinIdxBufSize Then
          MsgsNow := MerlinIdxBufSize;
        BlockWrite(MInfo^.MsgFile, MInfo^.IdxBuf.Idx, MsgsNow *
          SizeOf(MerlinIdxType));
        Error := IoResult;
        MsgsLeft := MsgsLeft - MsgsNow;
        End;
      End;
    End
  Else
    Error := 100;
  CreateMsgBase := Error;
  End;


Function MerlinMsgObj.MsgBaseExists: Boolean;
  Begin
  MsgBaseExists := FileExist(MInfo^.FN);
  End;


Procedure MerlinMsgObj.StartNewMsg;
  Begin
  { ** }
  End;


Function MerlinMsgObj.GetHighMsgNum: LongInt;
  Begin
  GetHighMsgNum := MInfo^.MsgBaseHdr.LastMsgId;
  End;


Function MerlinMsgObj.SeekFound: Boolean;
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.SetMailType(MT: MsgMailType);
  Begin
  End;


Procedure MerlinMsgObj.ReWriteHdr;
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.DeleteMsg;
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.SetEcho(ES: Boolean);
  Begin
  SetAttr1(ES, ma1ToBeExported);
  End;


Procedure MerlinMsgObj.SeekPrior;
  Begin
  { ** }
  End;


Function MerlinMsgObj.NumberOfMsgs: LongInt;
  Begin
  NumberOfMsgs := MInfo^.MsgBaseHdr.NumMsgs;
  End;


Function MerlinMsgObj.GetLastRead(UNum: LongInt): LongInt;
  Begin
  { ** }
  End;


Procedure MerlinMsgObj.SetLastRead(UNum: LongInt; LR: LongInt);
  Begin
  { ** }
  End;


Function MerlinMsgObj.GetTxtPos: LongInt;
  Begin
  GetTxtPos := MInfo^.TxtPos;
  End;


Procedure MerlinMsgObj.SetTxtPos(TP: LongInt);
  Begin
  MInfo^.TxtPos := TP;
  End;


Procedure MerlinMsgObj.ReadIdx(StartNum: LongInt);
  Var
    Temp: LongInt;
    ToRead: Word;

  Begin
  MInfo^.Error := 0;
  MInfo^.IdxStart := StartNum;
  If LockMsgBase Then
    Begin
    Temp := StartNum - MInfo^.MsgBaseHdr.BaseMsgId;
    ToRead := MInfo^.MsgBaseHdr.LastMsgId + 1 - StartNum;
    If ToRead > MerlinIdxBufSize Then
      ToRead := MerlinIdxBufSize;
    Temp := Temp * SizeOf(MerlinIdxType);
    Temp := Temp + MInfo^.MsgBaseHdr.IdxPtr + SizeOf(MerlinFrameHdrType);
    ToRead := ToRead * SizeOf(MerlinIdxType);
    If Not shSeekFile(MInfo^.MsgFile, Temp) Then
      MInfo^.Error := 2001 { idx seek failed }
    Else
      Begin
      If Not shRead(MInfo^.MsgFile, MInfo^.IdxBuf.Idx, ToRead, MInfo^.IdxRead) Then
        MInfo^.Error := 2002; { idx read failed }
      MInfo^.IdxRead := MInfo^.IdxRead Div SizeOf(MerlinIdxType);
      End;
    If UnLockMsgBase Then;
    End
  Else
    MInfo^.Error := 2000; { failed to lock }
  End;


Procedure MerlinMsgObj.ReadFree(FreeOffset: Word);
  Begin
  MInfo^.FreeStart := FreeOffset;
  { ** }
  End;


End.
