Unit MKMsgPCB;       {PC-Board Msg Object}

{$I MKB.Def}

{
     MKMsgPCB - Copyright 1994 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32/v34
     FidoNet: 1:110/290
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses MKGlobT, MKMsgAbs,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}


Type PCBMsgBlockType = Array[0..127] of Char;

Type PCBBaseHdrType = Record
  HighMsgNum: LongInt; {BSReal}
  LowMsgNum: LongInt;  {BSReal}
  ActiveMsgs: LongInt; {BSReal}
  SysCallers: LongInt; {BSReal}
  LockSpot: Array[1..6] of Char;
  Extra: Array[1..106] of Char;
  End;


Const PCBBufferSize = 32;


Type PCBInfoType = Record
  FN: String[80];
  MsgBuff: Array[1..PCBBufferSize] of PCBMsgBlockType;
  Error: Word;
  MsgFile: File;
  IdxFile: File;
  BaseOpened: Boolean;
  Locked: Boolean;
  MsgDone: Boolean;
  PCBDate: String[8];
  PCBTime: String[8];
  PCBFrom: String[60];
  PCBTo: String[60];
  PCBSubj: String[60];
  MsgBaseHdr: PCBBaseHdrType;
  TxtPos: LongInt;
  End;


Type PCBMsgObj = Object(AbsMsgObj)
  PCBInfo: ^PCBInfoType;
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
  End;


Type PCBMsgPtr = ^PCBMsgObj;


Implementation


Function BSRealToLong(InValue: LongInt): LongInt;
  Var
    Temp: LongInt;
    Negative: Boolean;
    Expon: Integer;

  Begin
    If InValue And $00800000 <> 0 Then
      Negative := True
    Else
      Negative := False;
    Expon := InValue shr 24;
    Expon := Expon and $ff;
    Temp := InValue and $007FFFFF;
    Temp := Temp or $00800000;
    Expon := Expon - 152;
    If Expon < 0 Then Temp := Temp shr Abs(Expon)
      Else Temp := Temp shl Expon;
    If Negative Then
      BSRealToLong := -Temp
    Else
      BSRealToLong := Temp;
    If Expon = 0 Then
      BSRealToLong := 0;
  End;


Function LongToBSReal(InValue: LongInt): LongInt;
  Var
    Negative: Boolean;
    Expon: LongInt;

  Begin
  If InValue = 0 Then
    LongToBSReal := 0
  Else
    Begin
    If InValue < 0 Then
      Begin
      Negative := True;
      InValue := Abs(InValue);
      End
    Else
      Negative := False;
    Expon := 152;
    If InValue < $007FFFFF Then
      While ((InValue and $00800000) = 0) Do
        Begin
        InValue := InValue shl 1;
        Dec(Expon);
        End
    Else
      While ((InValue And $FF000000) <> 0) Do
        Begin
        InValue := InValue shr 1;
        Inc(Expon);
        End;
    InValue := InValue And $007FFFFF;
    If Negative Then
      InValue := InValue Or $00800000;
    LongToBSReal := InValue + (Expon shl 24);
    End;
  End;




Constructor PCBMsgObj.Init;
  Begin
  New(PCBInfo);
  If PCBInfo = Nil Then
    Begin
    Fail;
    Exit;
    End;
  FillChar(PCBInfo^, SizeOf(PCBInfo^), #0);
  End;


Destructor PCBMsgObj.Done;
  Begin
  If PCBInfo^.BaseOpened Then
    PCBInfo^.Error := CloseMsgBase;
  Dispose(PCBInfo);
  End;


Procedure PCBMsgObj.SetMsgPath(MP: String);
  Begin
  PCBInfo^.FN := MP;
  End;


Function PCBMsgObj.OpenMsgBase: Word;
  Begin
  End;


Function PCBMsgObj.CloseMsgBase: Word;
  Begin
  End;


Function PCBMsgObj.LockMsgBase: Boolean;
  Begin
  End;


Function PCBMsgObj.UnLockMsgBase: Boolean;
  Begin
  End;


Procedure PCBMsgObj.SetDest(Var Addr: AddrType);
  Begin
  End;


Procedure PCBMsgObj.SetOrig(Var Addr: AddrType);
  Begin
  End;


Procedure PCBMsgObj.SetFrom(Name: String);
  Begin
  End;


Procedure PCBMsgObj.SetTo(Name: String);
  Begin
  End;


Procedure PCBMsgObj.SetSubj(Str: String);
  Begin
  End;


Procedure PCBMsgObj.SetCost(SCost: Word);
  Begin
  End;


Procedure PCBMsgObj.SetRefer(SRefer: LongInt);
  Begin
  End;


Procedure PCBMsgObj.SetSeeAlso(SAlso: LongInt);
  Begin
  End;


Procedure PCBMsgObj.SetDate(SDate: String);
  Begin
  End;


Procedure PCBMsgObj.SetTime(STime: String);
  Begin
  End;


Procedure PCBMsgObj.SetLocal(LS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetRcvd(RS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetPriv(PS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetCrash(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetKillSent(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetSent(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetFAttach(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetReqRct(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetReqAud(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetRetRct(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SetFileReq(SS: Boolean);
  Begin
  End;


Procedure PCBMsgObj.DoChar(Ch: Char);
  Begin
  End;


Function PCBMsgObj.WriteMsg: Word;
  Begin
  End;


Function PCBMsgObj.GetChar: Char;
  Begin
  End;


Function PCBMsgObj.EOM: Boolean;
  Begin
  End;


Procedure PCBMsgObj.SeekFirst(MsgNum: LongInt);
  Begin
  End;


Procedure PCBMsgObj.SeekNext;
  Begin
  End;


Function PCBMsgObj.GetFrom: String;
  Begin
  GetFrom := PCBInfo^.PCBFrom;
  End;


Function PCBMsgObj.GetTo: String;
  Begin
  GetTo := PCBInfo^.PCBTo;
  End;


Function PCBMsgObj.GetSubj: String;
  Begin
  GetSubj := PCBInfo^.PCBSubj;
  End;


Function PCBMsgObj.GetCost: Word;
  Begin
  End;


Function PCBMsgObj.GetDate: String;
  Begin
  End;


Function PCBMsgObj.GetTime: String;
  Begin
  End;


Function PCBMsgObj.GetRefer: LongInt;
  Begin
  End;


Function PCBMsgObj.GetSeeAlso: LongInt;
  Begin
  End;


Function PCBMsgObj.GetMsgNum: LongInt;
  Begin
  End;


Procedure PCBMsgObj.GetOrig(Var Addr: AddrType);
  Begin
  End;


Procedure PCBMsgObj.GetDest(Var Addr: AddrType);
  Begin
  End;


Function PCBMsgObj.IsLocal: Boolean;
  Begin
  End;


Function PCBMsgObj.IsCrash: Boolean;
  Begin
  End;


Function PCBMsgObj.IsKillSent: Boolean;
  Begin
  End;


Function PCBMsgObj.IsSent: Boolean;
  Begin
  End;


Function PCBMsgObj.IsFAttach: Boolean;
  Begin
  End;


Function PCBMsgObj.IsReqRct: Boolean;
  Begin
  End;


Function PCBMsgObj.IsReqAud: Boolean;
  Begin
  End;


Function PCBMsgObj.IsRetRct: Boolean;
  Begin
  End;


Function PCBMsgObj.IsFileReq: Boolean;
  Begin
  End;


Function PCBMsgObj.IsRcvd: Boolean;
  Begin
  End;


Function PCBMsgObj.IsPriv: Boolean;
  Begin
  End;


Function PCBMsgObj.IsDeleted: Boolean;
  Begin
  End;


Function PCBMsgObj.IsEchoed: Boolean;
  Begin
  End;


Function PCBMsgObj.GetMsgLoc: LongInt;
  Begin
  End;


Procedure PCBMsgObj.SetMsgLoc(ML: LongInt);
  Begin
  End;


Procedure PCBMsgObj.MsgStartUp;
  Begin
  End;


Procedure PCBMsgObj.MsgTxtStartUp;
  Begin
  End;


Procedure PCBMsgObj.YoursFirst(Name: String; Handle: String);
  Begin
  End;


Procedure PCBMsgObj.YoursNext;
  Begin
  End;


Function PCBMsgObj.YoursFound: Boolean;
  Begin
  End;


Function PCBMsgObj.CreateMsgBase(MaxMsg: Word; MaxDays: Word): Word;
  Begin
  End;


Function PCBMsgObj.MsgBaseExists: Boolean;
  Begin
  End;


Procedure PCBMsgObj.StartNewMsg;
  Begin
  End;


Function PCBMsgObj.GetHighMsgNum: LongInt;
  Begin
  End;


Function PCBMsgObj.SeekFound: Boolean;
  Begin
  End;


Procedure PCBMsgObj.SetMailType(MT: MsgMailType);
  Begin
  End;


Procedure PCBMsgObj.ReWriteHdr;
  Begin
  End;


Procedure PCBMsgObj.DeleteMsg;
  Begin
  End;


Procedure PCBMsgObj.SetEcho(ES: Boolean);
  Begin
  End;


Procedure PCBMsgObj.SeekPrior;
  Begin
  End;


Function PCBMsgObj.NumberOfMsgs: LongInt;
  Begin
  End;


Function PCBMsgObj.GetLastRead(UNum: LongInt): LongInt;
  Begin
  End;


Procedure PCBMsgObj.SetLastRead(UNum: LongInt; LR: LongInt);
  Begin
  End;


Function PCBMsgObj.GetTxtPos: LongInt;
  Begin
  GetTxtPos := PCBInfo^.TxtPos;
  End;


Procedure PCBMsgObj.SetTxtPos(TP: LongInt);
  Begin
  PCBInfo^.TxtPos := TP;
  End;


End.
