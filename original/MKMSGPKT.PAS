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

     A Message object to handle Fidonet-style message packets.
     Because a PKT is not really a message base, some methods
     (like deletemsg) are not implemented.
}


Interface

Uses MKGlobT, MKMsgAbs, MKFFile,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}


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


Type MKPktInfoType = Record
  PktHdr: MKPktHdrType;
  Error: Word;
  BaseOpened: Boolean;
  FN: String[128];
  PF: FFileObj; {Buffered file object for pkt}
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
  Procedure ScanPkt; Virtual; {Pre-scan pkt for message positions}
  End;


Type PktMsgPtr = ^PktMsgObj;


Implementation


Uses MKFile, MKString;


Constructor PktMsgObj.Init;
  Begin
  New(PI);
  If PI = Nil Then
    Begin
    Fail;
    Exit;
    End;
  FillChar(PI^, SizeOf(PI^), #0);
  End;


Destructor PktMsgObj.Done;
  Begin
  If PI^.BaseOpened Then
    PI^.Error := CloseMsgBase;
  Dispose(PI);
  End;


Procedure PktMsgObj.SetMsgPath(MP: String);
  Begin
  PI^.FN := MP;
  End;


Function PktMsgObj.OpenMsgBase: Word;
  Begin
  If FileExist(PI^.FN) Then
    PI^.Error := 0
  Else
    PI^.Error := 1001;
  If PI^.Error = 0 Then
    Begin
    PI^.PF.Init(4096);
    If Not PI^.PF.OpenFile(PI^.FN, fmReadWrite + fmDenyNone) Then
      PI^.Error := 1000;
    End;
  PI^.BaseOpened := (PI^.Error = 0);
  OpenMsgBase := PI^.Error;
  End;


Function PktMsgObj.CloseMsgBase: Word;
  Begin
  If PI^.BaseOpened Then
    Begin
    If PI^.PF.CloseFile Then;
    PI^.PF.Done;
    PI^.BaseOpened := False;
    End;
  End;


Function PktMsgObj.LockMsgBase: Boolean;
  Begin
  LockMsgBase := True;
  End;


Function PktMsgObj.UnLockMsgBase: Boolean;
  Begin
  UnLockMsgBase := True;
  End;


Procedure PktMsgObj.SetDest(Var Addr: AddrType);
  Begin
  End;


Procedure PktMsgObj.SetOrig(Var Addr: AddrType);
  Begin
  End;


Procedure PktMsgObj.SetFrom(Name: String);
  Begin
  End;


Procedure PktMsgObj.SetTo(Name: String);
  Begin
  End;


Procedure PktMsgObj.SetSubj(Str: String);
  Begin
  End;


Procedure PktMsgObj.SetCost(SCost: Word);
  Begin
  End;


Procedure PktMsgObj.SetRefer(SRefer: LongInt);
  Begin
  End;


Procedure PktMsgObj.SetSeeAlso(SAlso: LongInt);
  Begin
  End;


Procedure PktMsgObj.SetDate(SDate: String);
  Begin
  End;


Procedure PktMsgObj.SetTime(STime: String);
  Begin
  End;


Procedure PktMsgObj.SetLocal(LS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetRcvd(RS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetPriv(PS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetCrash(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetKillSent(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetSent(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetFAttach(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetReqRct(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetReqAud(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetRetRct(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.SetFileReq(SS: Boolean);
  Begin
  End;


Procedure PktMsgObj.DoChar(Ch: Char);
  Begin
  End;


Function PktMsgObj.WriteMsg: Word;
  Begin
  End;


Function PktMsgObj.GetChar: Char;
  Begin
  End;


Function PktMsgObj.EOM: Boolean;
  Begin
  End;


Procedure PktMsgObj.SeekFirst(MsgNum: LongInt);
  Begin
  End;


Procedure PktMsgObj.SeekNext;
  Begin
  End;


Function PktMsgObj.GetFrom: String;
  Begin
  End;


Function PktMsgObj.GetTo: String;
  Begin
  End;


Function PktMsgObj.GetSubj: String;
  Begin
  End;


Function PktMsgObj.GetCost: Word;
  Begin
  End;


Function PktMsgObj.GetDate: String;
  Begin
  End;


Function PktMsgObj.GetTime: String;
  Begin
  End;


Function PktMsgObj.GetRefer: LongInt;
  Begin
  End;


Function PktMsgObj.GetSeeAlso: LongInt;
  Begin
  End;


Function PktMsgObj.GetMsgNum: LongInt;
  Begin
  End;


Procedure PktMsgObj.GetOrig(Var Addr: AddrType);
  Begin
  End;


Procedure PktMsgObj.GetDest(Var Addr: AddrType);
  Begin
  End;


Function PktMsgObj.IsLocal: Boolean;
  Begin
  End;


Function PktMsgObj.IsCrash: Boolean;
  Begin
  End;


Function PktMsgObj.IsKillSent: Boolean;
  Begin
  End;


Function PktMsgObj.IsSent: Boolean;
  Begin
  End;


Function PktMsgObj.IsFAttach: Boolean;
  Begin
  End;


Function PktMsgObj.IsReqRct: Boolean;
  Begin
  End;


Function PktMsgObj.IsReqAud: Boolean;
  Begin
  End;


Function PktMsgObj.IsRetRct: Boolean;
  Begin
  End;


Function PktMsgObj.IsFileReq: Boolean;
  Begin
  End;


Function PktMsgObj.IsRcvd: Boolean;
  Begin
  End;


Function PktMsgObj.IsPriv: Boolean;
  Begin
  End;


Function PktMsgObj.IsDeleted: Boolean;
  Begin
  End;


Function PktMsgObj.IsEchoed: Boolean;
  Begin
  End;


Function PktMsgObj.GetMsgLoc: LongInt;
  Begin
  End;


Procedure PktMsgObj.SetMsgLoc(ML: LongInt);
  Begin
  End;


Procedure PktMsgObj.MsgStartUp;
  Begin
  End;


Procedure PktMsgObj.MsgTxtStartUp;
  Begin
  End;


Procedure PktMsgObj.YoursFirst(Name: String; Handle: String);
  Begin
  End;


Procedure PktMsgObj.YoursNext;
  Begin
  End;


Function PktMsgObj.YoursFound: Boolean;
  Begin
  End;


Function PktMsgObj.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word;
  Begin
  End;


Function PktMsgObj.MsgBaseExists: Boolean;
  Begin
  MsgBaseExists := FileExist(PI^.FN);
  End;


Procedure PktMsgObj.StartNewMsg;
  Begin
  End;


Function PktMsgObj.GetHighMsgNum: LongInt;
  Begin
  End;


Function PktMsgObj.SeekFound: Boolean;
  Begin
  End;


Procedure PktMsgObj.SetMailType(MT: MsgMailType);
  Begin
  End;


Procedure PktMsgObj.ReWriteHdr;
  Begin
  End;


Procedure PktMsgObj.DeleteMsg;
  Begin
  End;


Procedure PktMsgObj.SetEcho(ES: Boolean);
  Begin
  End;


Procedure PktMsgObj.SeekPrior;
  Begin
  End;


Function PktMsgObj.NumberOfMsgs: LongInt;
  Begin
  End;


Function PktMsgObj.GetLastRead(UNum: LongInt): LongInt;
  Begin
  End;


Procedure PktMsgObj.SetLastRead(UNum: LongInt; LR: LongInt);
  Begin
  End;


Function PktMsgObj.GetTxtPos: LongInt;
  Begin
  End;


Procedure PktMsgObj.SetTxtPos(TP: LongInt);
  Begin
  End;


Procedure PktMsgObj.ScanPkt; {Pre-scan pkt for message positions}

  Const BufMax = 15*4096;

  Type BufType = Array[1..BufMax] of Char;

  Var
    Buf: ^BufType;
    NumRead: Word;
    NumMsgs: LongInt;
    FF: ^File;
    BufStart: LongInt;
    i: Word;

  Begin
  New(Buf);
  NumMsgs := 0;
  FF := PI^.PF.GetFilePtr;
  Seek(FF^, 0);
  BufStart := 0;
  If IoResult <> 0 Then;
  BlockRead(FF^, Buf^, Sizeof(Buf^), NumRead);
  If IoResult <> 0 Then
    NumRead := 0;
  While NumRead > 0 Do
    Begin
    If NumRead > 1 Then
      Begin
      For i := 1 to NumRead - 1 Do
        Begin
        If (Buf^[i] = #0) and (Buf^[i + 1] = #2) Then
          Begin
          Inc(NumMsgs);
          Write(#13);
          Write(NumMsgs,' ', BufStart + i - 1,'   ');
          End;
        End;
      End;
    If Buf^[NumRead] = #0 Then
      Begin
      Buf^[1] := #0;
      BufStart := FilePos(FF^) - 1;
      BlockRead(FF^, Buf^[1], BufMax - 1, NumRead);
      If NumRead > 0 Then
        Inc(NumRead);
      End
    Else
      Begin
      BufStart := FilePos(FF^);
      BlockRead(FF^, Buf^, BufMax, NumRead);
      End;
    If IoResult <> 0 Then
      NumRead := 0;
    End;
  Dispose(Buf);
  End;


End.
