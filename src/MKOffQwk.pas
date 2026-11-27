{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKOffQwk;       {QWK Offline mail Object}

{$I MKB.Def}

{
     MKOffQwk - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses MKGlobT, MKMsgAbs, MKOffAbs, MKMsgQwk,
  Dos;


{
     A QWK packet for a caller (MESSAGES.DAT, the .NDX files, CONTROL.DAT, DOOR.ID) and the messages of his reply packet.
     The message file is written with MKMsgQwk (conference = number of the message area, message number = the number
     of the message in its area), the rest is made here.  The BBS id is SetBBSId, the work directory SetPath;
     the settings of the BBS are Config (MKCfgAbs) and the caller is User (MKDoor).  Needs nothing of the MKQwk
     door (config.mko).

       SetKeepKludges(True)  keeps the MSGID, REPLY, Via and TZ kludge lines of the messages as @ lines (QWK networks);
                             the other kludge lines are always left out
       SetImportOpts         what ImportPacket does with the messages of a reply packet
       SetLink(Id, ConfOf, AreaOf)  the packet is the reply packet (REP) for the QWK system Id, as a node makes it for its hub: the
                             file is Id.msg (packed into Id.rep), the conference of a message is ConfOf(area) and not
                             the area number (AreaOf is the way back, for the packet of the hub), no CONTROL.DAT and no index files; the packet that comes from the hub
                             (messages.dat) is what ImportPacket then reads
}


Const QwkConfs = 2000;                 {highest conference (area) number in a packet}
Const MaxQwkMsgs = 200000;             {messages in a packet}


Type QwkIdxType = Record               {a record of an .NDX file}
  QwkPtr: LongInt;
  MsgConf: Byte;
  End;


Type QwkExpType = Record               {a message of the packet: its header block and its area}
  Blk: LongInt;
  Area: Word;
  End;
Type QwkExpArray = Array[1..MaxQwkMsgs] Of QwkExpType;
Type QwkExpPtr = ^QwkExpArray;
Type QwkIdxArray = Array[1..MaxQwkMsgs] Of QwkIdxType;
Type QwkIdxPtr = ^QwkIdxArray;


Const
  QwkImportLedger: String = '';        {when set: the area and number of every message posted from a packet is added to this file
                                        (a QWK network pass keeps it so that these messages are not sent back)}

Type OffImpNoteProc = Procedure(Code: Word; Conf: LongInt; Msg: AbsMsgPtr);   {as QwkImpNoteProc (MKQwkImp)}
Type OffImpSinkProc = Procedure(S: String);

Const
  OffImpHook: OffImpNoteProc = Nil;    {ImportPacket tells what happened to each message (the qi... codes of MKQwkImp), conference by conference (the JSON API)}
  OffImpSink: OffImpSinkProc = Nil;    {when set: the text ImportPacket and the control messages would show the caller (ADD 12: done ...) goes here and not to the caller's screen}

Type QwkConfFunc = Function(N: LongInt): LongInt;   {the conference of a message area at the other end (-1 = none)}


Type QwkInfo = Record
  MsgPath: String;
  Q: QwkMsgPtr;                        {MESSAGES.DAT}
  Exp: QwkExpPtr;
  NumExp: LongInt;
  ExpCap: LongInt;
  Pers: QwkExpPtr;                     {the messages to the caller (personal.ndx)}
  NumPers: LongInt;
  PersCap: LongInt;
  ConfCount: Array[0..QwkConfs] Of Word;
  ReplyMsgs: Word;                     {messages in the reply packet}
  BBSId: String[8];
  Imported: LongInt;                   {messages the last ImportPacket posted}
  KeepKludges: Boolean;
  Qwke: Boolean;
  ControlFiles: Boolean;               {CONTROL.DAT and DOOR.ID are in the packet}
  Link: Boolean;                       {SetLink: the packet is a REP for another system}
  LinkId: String[40];
  ConfOf: QwkConfFunc;                 {area -> conference of the other end}
  AreaOf: QwkConfFunc;                 {conference of the other end -> area}
  ImpPosted: Array[1..QwkConfs] Of Word; {link: messages the import posted in each area}
  ImpPending: Array[1..QwkConfs] Of LongInt; {link: messages of the area still to be sent before the import}
  ImpFirst: Array[1..QwkConfs] Of LongInt; {link: numbers of the first and the last message the import posted}
  ImpLast: Array[1..QwkConfs] Of LongInt;
  ImpTouched: Array[1..QwkConfs] Of Boolean;
  ScrFile: Array[1..3] Of String[12];  {the welcome, news and goodbye files that are in the packet ('' = the standard names)}
  End;


Type QwkOffObj = Object(AbsOffObj)
  QI: ^QwkInfo;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetPath(MP: String); Virtual; {Set msg path/other info}
  Procedure SetBBSID(ID: String); Virtual; {Set bbs id/filename}
  Procedure SetKeepKludges(KK: Boolean);
  Procedure SetQwke(QK: Boolean); Virtual;
  Procedure SetControlFiles(CF: Boolean); Virtual;
  Procedure SetScreenFile(N: Word; Name: String); Virtual;
  Function  AreaInPacket(Area: Word): Boolean; Virtual;
  Procedure SetLink(RemoteId: String; ConfOf: QwkConfFunc; AreaOf: QwkConfFunc);
  Function  LinkImported(Area: Word; Var Pending, First, Last: LongInt): Word;
    {link: messages the import posted in the area, the numbers of the first and last, and how many messages of the
     area were still to be sent before it (the last read of the user is before them)}
  Function  StartPacket: Word; Virtual; {Do Packet startup tasks}
  Function  ClosePacket: Word; Virtual; {Do Packet finish tasks}
  Function  AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean; Virtual;
  Function  AddControl(Conf: LongInt; ToName, FromName, Subj: String): Boolean;
    {link (a reply packet to a hub): a control message (ADD, DROP ...): to ToName, in conference Conf, the command as the subject}
  Function  GetArchiveName(Packer: Word): String; Virtual;
  Function  GetReplyName: String; Virtual;
  Function  GetExtractSpec: String; Virtual;
  Procedure PersIdx;
  Procedure DoIdx;
  Procedure DoControl;
  Procedure WriteDoorId;
  Procedure ImportPacket; Virtual;
  Function  GetImported: LongInt; Virtual;
  End;


Type QwkOffPtr = ^QwkOffObj;


Type QwkAreaProc = Procedure(Area: Word; Typ: Byte);
Var QwkAreaHook: QwkAreaProc;          {TODOOR.EXT AREA lines: how the caller's subscription is kept (door: users.mko); Nil = the offline flags of the user (mk).
                                        Typ: 0 = dropped, 1 = on, 2 = personal mail only, 3 = personal and to All}


Function FindNoCase(Dir: String; Name: String): String;
  {the full path of a file in Dir whatever case its name is in ('' = none)}


Implementation


Uses MKString, MKFile, MKCfgAbs, MKDos, MKDoor, MKQwkImp, MKOffXfer, MKOpen, MKOffDL;


Function Bas2Lng(InValue: LongInt): LongInt;
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
      Bas2Lng := -Temp
    Else
      Bas2Lng := Temp;
    If Expon = 0 Then
      Bas2Lng := 0;
  End;


Function Lng2Bas(InValue: LongInt): LongInt;
  Var
    Negative: Boolean;
    Expon: LongInt;

  Begin
  If InValue = 0 Then
    Lng2Bas := 0
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
    Lng2Bas := InValue + (Expon shl 24);
    End;
  End;


Constructor QwkOffObj.Init;
  Begin
  Inherited Init;
  New(QI);
  FillChar(QI^, SizeOf(QI^), 0);
  QI^.ControlFiles := True;
  End;


Destructor QwkOffObj.Done;
  Begin
  If QI^.Q <> Nil Then
    Begin
    Dispose(QI^.Q, Done);
    QI^.Q := Nil;
    End;
  If QI^.Exp <> Nil Then
    FreeMem(QI^.Exp, QI^.ExpCap * SizeOf(QwkExpType));
  If QI^.Pers <> Nil Then
    FreeMem(QI^.Pers, QI^.PersCap * SizeOf(QwkExpType));
  Dispose(QI);
  End;


Function QwkOffObj.AreaInPacket(Area: Word): Boolean;
  Begin
  AreaInPacket := (Area <= QwkConfs) And (QI^.ConfCount[Area] > 0);
  End;


Procedure QwkOffObj.SetScreenFile(N: Word; Name: String);
  Begin
  If (N >= 1) And (N <= 3) Then
    QI^.ScrFile[N] := Name;
  End;


Procedure QwkOffObj.SetPath(MP: String);
  Begin
  QI^.MsgPath := WithBackSlash(MP);
  End;


Procedure QwkOffObj.SetKeepKludges(KK: Boolean);
  Begin
  QI^.KeepKludges := KK;
  End;


Procedure QwkOffObj.SetLink(RemoteId: String; ConfOf: QwkConfFunc; AreaOf: QwkConfFunc);
  Begin
  QI^.AreaOf := AreaOf;
  QI^.Link := True;
  QI^.LinkId := Copy(RemoteId, 1, 40);
  QI^.ConfOf := ConfOf;
  End;


Procedure QwkOffObj.SetQwke(QK: Boolean);
  Begin
  QI^.Qwke := QK;
  End;


Function Grow(Var P: QwkExpPtr; Var Cap: LongInt; Need: LongInt): Boolean;
  {room for Need records}
  Var
    NewP: QwkExpPtr;
    NewCap: LongInt;

  Begin
  Grow := True;
  If Need <= Cap Then
    Exit;
  Grow := False;
  If Need > MaxQwkMsgs Then
    Exit;
  NewCap := Cap + Cap Div 2 + 256;
  If NewCap > MaxQwkMsgs Then
    NewCap := MaxQwkMsgs;
  GetMem(NewP, NewCap * SizeOf(QwkExpType));
  If NewP = Nil Then
    Exit;
  If P <> Nil Then
    Begin
    Move(P^, NewP^, Cap * SizeOf(QwkExpType));
    FreeMem(P, Cap * SizeOf(QwkExpType));
    End;
  P := NewP;
  Cap := NewCap;
  Grow := True;
  End;


Function QwkOffObj.AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean;
  {the message goes into MESSAGES.DAT (MKMsgQwk): the conference is the area, the number the number of the message.
   A message that cannot be written (no text ...) is left out and is not an error; False is a packet that cannot go on.}
  Const
    StrLen = 72;

  Var
    Q: QwkMsgPtr;
    Line: String;
    S: String;
    Net: Boolean;
    TAddr: AddrType;
    Lines: Word;
    Res: Word;
    Conf: LongInt;

  Begin
  AddMsg := False;
  Q := QI^.Q;
  If (Q = Nil) Or (Area > QwkConfs) Then
    Exit;
  Conf := Area;
  If QI^.Link Then
    Begin
    Conf := QI^.ConfOf(Area);
    If Conf < 0 Then
      Begin
      AddMsg := True;                  {an area the other end does not know: not in its packet}
      Exit;
      End;
    End;
  Net := Config^.GetMsgType(Area) = NetMail;
  Q^.StartNewMsg;
  Q^.SetMsgConf(Conf);
  If QI^.Link Then
    Q^.SetEcho(Config^.GetMsgType(Area) = EchoMail);
  Q^.SetQwkNum(Msg.GetMsgNum);
  Q^.SetPriv(Msg.IsPriv);
  Q^.SetRcvd(Msg.IsRcvd);
  S := Msg.GetFrom;
  If StripBoth(S, ' ') = '' Then
    S := 'Unknown';
  Q^.SetFrom(S);
  Q^.SetTo(Msg.GetTo);
  If Net Then
    Begin
    If QI^.Link Then
      Msg.GetDest(TAddr)               {a reply packet says where the message is going}
    Else
      Msg.GetOrig(TAddr);
    Q^.SetSubj('@' + AddrStr(TAddr));
    End
  Else
    Q^.SetSubj(Msg.GetSubj);
  Q^.SetDate(Msg.GetDate);
  Q^.SetTime(Copy(Msg.GetTime, 1, 5));
  Q^.SetRefer(Msg.GetRefer);
  Lines := 0;
  If Net Then
    Begin
    Q^.DoStringLn('Subj: ' + Msg.GetSubj);
    Inc(Lines);
    End;
  Msg.MsgTxtStartUp;
  While Not Msg.EOM Do
    Begin
    Line := Msg.GetString(StrLen);
    If (Length(Line) > 0) And (Line[1] = #1) Then
      Begin
      {a kludge line: the pieces of one that was wrapped belong to it}
      While Msg.WasWrap And (Not Msg.EOM) And (Length(Line) < 180) Do
        Line := Line + Msg.GetString(StrLen);
      If QI^.KeepKludges Then
        Q^.DoKludgeLn(Line);
      End
    Else
      Begin
      Q^.DoStringLn(Line);
      Inc(Lines);
      End;
    End;
  If Lines = 0 Then
    Q^.DoStringLn('(no text)');            {QWK has no message without text}
  Res := Q^.WriteMsg;
  If Res = 0 Then
    Begin
    If (Not Grow(QI^.Exp, QI^.ExpCap, QI^.NumExp + 1)) Or
       (ToYou And (Not Grow(QI^.Pers, QI^.PersCap, QI^.NumPers + 1))) Then
      Exit;
    Inc(QI^.NumExp);
    QI^.Exp^[QI^.NumExp].Blk := Q^.GetLastBlock;
    QI^.Exp^[QI^.NumExp].Area := Area;
    Inc(QI^.ConfCount[Area]);
    If ToYou Then
      Begin
      Inc(QI^.NumPers);
      QI^.Pers^[QI^.NumPers].Blk := Q^.GetLastBlock;
      QI^.Pers^[QI^.NumPers].Area := Area;
      End;
    AddMsg := True;
    End
  Else
    AddMsg := (Res >= 1005) And (Res <= 1008);   {this message only}
  End;


Function QwkOffObj.AddControl(Conf: LongInt; ToName, FromName, Subj: String): Boolean;
  Var
    Q: QwkMsgPtr;
    Y, M, D, W, H, Mi, S, S100: Word;

  Function Z2(N: Word): String;
    Begin
    Z2 := Chr(48 + (N Div 10) Mod 10) + Chr(48 + N Mod 10);
    End;

  Begin
  AddControl := False;
  Q := QI^.Q;
  If Q = Nil Then
    Exit;
  Dos.GetDate(Y, M, D, W);
  Dos.GetTime(H, Mi, S, S100);
  Q^.StartNewMsg;
  Q^.SetMsgConf(Conf);
  Q^.SetQwkNum(0);
  Q^.SetPriv(False);
  Q^.SetFrom(FromName);
  Q^.SetTo(ToName);
  Q^.SetSubj(Subj);
  Q^.SetDate(Z2(M) + '-' + Z2(D) + '-' + Z2(Y Mod 100));
  Q^.SetTime(Z2(H) + ':' + Z2(Mi));
  Q^.DoStringLn(Subj);                   {QWK has no message without text}
  AddControl := Q^.WriteMsg = 0;
  End;


Function QwkOffObj.GetArchiveName(Packer: Word): String;
  Begin
  If QI^.Link Then
    GetArchiveName := QI^.LinkId + '.rep'
  Else
    GetArchiveName := QI^.BBSID + '.qwk';
  End;


Procedure QwkOffObj.PersIdx;
  Var
    i: LongInt;
    PersFile: File;
    Rec: QwkIdxType;

  Begin
  If QI^.NumPers > 0 Then
    Begin
    Assign(PersFile, QI^.MsgPath + 'personal.ndx');
    ReWrite(PersFile, SizeOf(QwkIdxType));
    For i := 1 To QI^.NumPers Do
      Begin
      Rec.QwkPtr := Lng2Bas(QI^.Pers^[i].Blk + 1);
      Rec.MsgConf := QI^.Pers^[i].Area And $ff;
      BlockWrite(PersFile, Rec, 1);
      End;
    Close(PersFile);
    If IoResult <> 0 Then;
    End;
  End;


Procedure QwkOffObj.WriteDoorId;
  Var
    CFile: Text;
    i: Word;
    Ext: String[4];
    TempStr: String;

  Begin
  If IoResult <> 0 Then;
  Assign (CFile, QI^.MsgPath + 'door.id');
  ReWrite(CFile);
  WriteLn(CFile, 'DOOR = MKQwk');
  WriteLn(CFile, 'VERSION = 1.1');
  WriteLn(CFile, 'SYSTEM = Mythical Kingdom');
  WriteLn(CFile, 'CONTROLNAME = MK');
  WriteLn(CFile, 'CONTROLTYPE = ADD');
  WriteLn(CFile, 'CONTROLTYPE = DROP');
  WriteLn(CFile, 'CONTROLTYPE = RESET');
  WriteLn(CFile, 'CONTROLTYPE = RESETALL');
  WriteLn(CFile, 'CONTROLTYPE = CONTROL');
  WriteLn(CFile, 'MIXEDCASE = YES');
  Close(CFile);
  If IoResult <> 0 Then;
  End;


Procedure QwkOffObj.DoControl;
  Var
    CF: Text;
    NumAvail: Word;
    Sec: SecType;
    i: Word;

  Begin
  If IoResult <> 0 Then;
  FileMode := fmReadWrite + fmDenyNone;
  Assign(CF, QI^.MsgPath + 'control.dat');
  ReWrite(CF);
  If IoResult <> 0 Then;
  WriteLn(CF, Config^.GetBBSName);
  WriteLn(CF, Config^.GetBBSLoc);
  WriteLn(CF, Config^.GetBBSPhone);
  WriteLn(CF, Upper(Config^.GetSysopName) + ',Sysop');
  WriteLn(CF, '0 ,' + QI^.BBSId);
  WriteLn(CF, FormattedDosDate(GetDosDate,'MM-DD-YYYY,') + TimeStr(GetDosDate));
  WriteLn(CF, Upper(User^.GetUserName));
  WriteLn(CF);
  WriteLn(CF,'0');
  WriteLn(CF,'0');
  User^.GetUserSec(Sec);
  NumAvail := 0;
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    If Config^.MsgReadAccess(i, Sec) Then
      Inc(NumAvail);
    End;
  WriteLn(CF,NumAvail);
  WriteLn(CF, '0');
  WriteLn(CF, 'Area 0');
  For i := 1 to Config^.GetMaxMsgAreas Do
    Begin
    If Config^.MsgReadAccess(i, Sec) Then
      Begin
      WriteLn(CF, i);
      WriteLn(CF, Config^.GetMsgShortName(i));
      End;
    End;
  If QI^.ScrFile[1] <> '' Then WriteLn(CF, QI^.ScrFile[1]) Else WriteLn(CF, 'welcome.ans');
  If QI^.ScrFile[2] <> '' Then WriteLn(CF, QI^.ScrFile[2]) Else WriteLn(CF, 'news.ans');
  If QI^.ScrFile[3] <> '' Then WriteLn(CF, QI^.ScrFile[3]) Else WriteLn(CF, 'goodbye.ans');
  WriteLn(CF, '0');
  WriteLn(CF, User^.GetUserScrLength);
  WriteLn(CF, Upper(User^.GetUserName));
  WriteLn(CF, ExtractWord(User^.GetUserName, 1));
  WriteLn(CF, User^.GetUserCity);
  WriteLn(CF, User^.GetUserDataPhone);
  WriteLn(CF, User^.GetUserVoicePhone);
  WriteLn(CF, User^.GetUserSecLevel);
  WriteLn(CF, '00-00-00'); {expire date}
  WriteLn(CF, DateStr(GetDosDate));
  WriteLn(CF, TimeStr(GetDosDate));
  WriteLn(CF, User^.GetUserTimesCalled);
  If IoResult <> 0 Then;
  Close(CF);
  If IoResult <> 0 Then;
  End;


Procedure QwkOffObj.DoIdx;
  Var
    i: Word;
    j: LongInt;
    IdxFile: File;
    Rec: QwkIdxType;

  Begin
  If QI^.NumPers > 0 Then
    PersIdx;
  For i := 0 to QwkConfs do
    Begin
    If QI^.ConfCount[i] > 0 Then
      Begin
      Assign(IdxFile, ConCat(QI^.MsgPath, PadLeft(Long2Str(i),'0',3),'.ndx'));
      ReWrite(IdxFile, SizeOf(QwkIdxType));
      For j := 1 to QI^.NumExp Do
        If QI^.Exp^[j].Area = i Then
          Begin
          Rec.MsgConf := i and $ff;
          Rec.QwkPtr := Lng2Bas(QI^.Exp^[j].Blk + 1);
          BlockWrite(IdxFile, Rec, 1);
          End;
      Close(IdxFile);
      If Ioresult <> 0 Then;
      End;
    End;
  End;


Function QwkOffObj.StartPacket: Word;
  Var
    Q: QwkMsgPtr;
    E: Word;

  Begin
  New(Q, Init);
  If QI^.Link Then
    Begin
    Q^.SetMsgPath(QI^.MsgPath + QI^.LinkId + '.msg');
    Q^.SetPacketId(QI^.LinkId);
    Q^.SetRepMode(True);
    End
  Else
    Begin
    Q^.SetMsgPath(QI^.MsgPath + 'messages.dat');
    Q^.SetPacketId('Produced by Mythical Kingdom Software - Copyright Mark May');
    End;
  Q^.SetUpperNames(True);
  If QI^.Qwke Then
    Q^.SetQwke(qkAuto);
  E := Q^.CreateMsgBase(0, 0);
  If E <> 0 Then
    Begin
    Dispose(Q, Done);
    Q := Nil;
    End;
  QI^.Q := Q;
  QI^.NumExp := 0;
  QI^.NumPers := 0;
  FillChar(QI^.ConfCount, SizeOf(QI^.ConfCount), 0);
  StartPacket := E;
  End;


Procedure QwkOffObj.SetControlFiles(CF: Boolean);
  Begin
  QI^.ControlFiles := CF;
  End;


Function QwkOffObj.ClosePacket: Word;
  Var
    E: Word;

  Begin
  E := 0;
  If QI^.Q <> Nil Then
    Begin
    E := QI^.Q^.CloseMsgBase;
    Dispose(QI^.Q, Done);
    QI^.Q := Nil;
    End;
  If Not QI^.Link Then
    Begin
    DoIdx;
    If QI^.ControlFiles Then
      Begin
      DoControl;
      WriteDoorId;
      End;
    End;
  ClosePacket := E;
  End;


Function QwkOffObj.GetReplyName: String;
  Begin
  GetReplyName := QI^.BBSID + '.rep';
  End;


Function QwkOffObj.GetExtractSpec: String;
  Begin
  If QI^.Link Then
    GetExtractSpec := 'messages.dat'   {what comes from the hub is a QWK packet}
  Else
    GetExtractSpec := QI^.BBSID + '.msg';
  End;


{ ---- the reply packet: the callbacks of MKQwkImp (conference = number of the message area, as in CONTROL.DAT) }

Var
  ImpQI: ^QwkInfo;
  ImpUser: DoorUserPtr;
  ImpSec: SecType;
  ImpName: String[35];
  ImpO: OffImportOpts;


Function ImpWriteOk(Area: LongInt): Boolean;
  {the caller can write in this area: it exists, write access, and private or public mail is allowed}
  Begin
  ImpWriteOk := False;
  If (Area < 1) Or (Area > Config^.GetMaxMsgAreas) Then
    Exit;
  If Length(Config^.GetMsgName(Area)) = 0 Then
    Exit;
  If Not Config^.MsgWriteAccess(Area, ImpSec) Then
    Exit;
  If (Not Config^.MsgAllowPriv(Area)) And (Not Config^.MsgAllowPubl(Area)) Then
    Exit;
  ImpWriteOk := True;
  End;


Function ImpMapLink(Conf: LongInt; Var T: QwkImpTarget; Var Moved: Boolean): Boolean;
  {the packet of a hub: the conference is one of the other end, the system itself posts (names as they are, no tear
   and origin lines: the messages bring their own)}
  Var
    Area: LongInt;
    M: AbsMsgPtr;
    LR, Cnt: LongInt;

  Begin
  ImpMapLink := False;
  Moved := False;
  Area := ImpQI^.AreaOf(Conf);
  If (Area < 1) Or (Area > QwkConfs) Or (Area > Config^.GetMaxMsgAreas) Then
    Exit;
  If Length(Config^.GetMsgName(Area)) = 0 Then
    Exit;
  T.AreaId := Config^.GetMsgAreaId(Area);
  T.Area := Area;
  T.Create := True;                 {an area of a network may not have a message base yet}
  Case Config^.GetMsgType(Area) Of
    EchoMail: T.Kind := mmtEchoMail;
    NetMail: T.Kind := mmtNetMail;
    Else T.Kind := mmtNormal;
    End;
  If T.Kind = mmtNetMail Then
    Config^.GetMsgAddr(Area, T.OrigAddr);
  T.PrivMode := 0;
  If Not ImpQI^.ImpTouched[Area] Then
    Begin
    ImpQI^.ImpTouched[Area] := True;
    ImpQI^.ImpPending[Area] := 0;
    ImpQI^.ImpFirst[Area] := 0;
    ImpQI^.ImpLast[Area] := 0;
    LR := OffUserLR(Area);
    If OpenMsgArea(M, T.AreaId) Then
      Begin
      Cnt := 0;
      M^.SeekFirst(LR + 1);
      While M^.SeekFound Do
        Begin
        Inc(Cnt);
        M^.SeekNext;
        End;
      ImpQI^.ImpPending[Area] := Cnt;
      If CloseMsgArea(M) Then;
      End;
    End;
  ImpMapLink := True;
  End;


Function ImpMap(Conf: LongInt; Var T: QwkImpTarget; Var Moved: Boolean): Boolean;
  Var
    Area: LongInt;

  Begin
  If ImpQI^.Link Then
    Begin
    ImpMap := ImpMapLink(Conf, T, Moved);
    Exit;
    End;
  ImpMap := False;
  Area := Conf;
  Moved := False;
  If Not ImpWriteOk(Area) Then
    Begin
    Area := ImpO.BadArea;           {the area for messages that cannot go where they were meant for}
    Moved := True;
    If Not ImpWriteOk(Area) Then
      Exit;
    End;
  T.AreaId := Config^.GetMsgAreaId(Area);
  T.Area := Area;
  Case Config^.GetMsgType(Area) Of
    EchoMail: T.Kind := mmtEchoMail;
    NetMail: T.Kind := mmtNetMail;
    Else T.Kind := mmtNormal;
    End;
  If T.Kind = mmtNetMail Then
    Config^.GetMsgAddr(Area, T.OrigAddr);
  If ImpO.ForceName Then
    T.ForceFrom := ImpName;
  If Config^.MsgAllowPriv(Area) Then
    Begin
    If Config^.MsgAllowPubl(Area) Then
      T.PrivMode := 0
    Else
      T.PrivMode := 1;
    End
  Else
    T.PrivMode := 2;
  T.ReDate := ImpO.ReDate;
  If (T.Kind <> mmtNormal) And Config^.MsgAddFido(Area) Then
    Begin
    T.TearLine := '--- MK Bbs v0.2';
    T.OriginLine := Config^.GetDefaultOrigStr(Area);
    End;
  ImpMap := True;
  End;


{ ---- control messages of a QWK network node (to SBBS or MK, as Synchronet networks send them): the areas of its offline
  mail are its subscriptions and its last read pointers tell what it has had.
    ADD [ptr | -msgs | mm/dd/yy]       the conference joins the packets, the pointer is set when one is given
    DROP [conf#]                       the conference (or conf#) leaves the packets
    RESET [ptr | -msgs | mm/dd/yy]     the pointer of the conference (no value = from the first message)
    RESETALL [ptr | -msgs | mm/dd/yy]  the pointers of all the conferences of the node
  ptr = messages after this number are new, -msgs = only the last messages are new, a date = the messages from that day.
    CONTROL [ON | OFF]                 CONTROL.DAT and DOOR.ID are in the packets of the node (or not)
  FREQ, FILES, ATTACH, CTRL-A, TZ, VIA, MSGID and NDX are taken and ignored (nothing there to change). }

Function DateKey(S: String): LongInt;
  {mm/dd/yy, mm-dd-yy or mm/dd/yyyy as yyyymmdd, 0 = not a date}
  Var
    P: Array[1..3] Of LongInt;
    N, i: Word;
    InNum: Boolean;

  Begin
  DateKey := 0;
  N := 0;
  InNum := False;
  For i := 1 To Length(S) Do
    If S[i] In ['0'..'9'] Then
      Begin
      If Not InNum Then
        Begin
        Inc(N);
        If N > 3 Then
          Exit;
        P[N] := 0;
        InNum := True;
        End;
      P[N] := P[N] * 10 + Ord(S[i]) - 48;
      End
    Else
      InNum := False;
  If N <> 3 Then
    Exit;
  If P[3] < 100 Then
    Begin
    If P[3] < 80 Then
      Inc(P[3], 2000)
    Else
      Inc(P[3], 1900);
    End;
  DateKey := P[3] * 10000 + P[1] * 100 + P[2];
  End;


Function ResolvePtr(Area: Word; Arg: String; Var Ptr: LongInt): Boolean;
  {the last read pointer an argument of ADD / RESET means in this area}
  Type
    NumArr = Array[1..1000000] Of LongInt;
  Var
    M: AbsMsgPtr;
    Nums: ^NumArr;
    Cnt, N, Key: LongInt;
    Prev, Last: LongInt;
    Found: Boolean;

  Begin
  ResolvePtr := True;
  Ptr := 0;
  If Arg = '' Then
    Exit;
  If Arg[1] In ['0'..'9'] Then
    Begin
    If (Pos('/', Arg) = 0) And (Pos('-', Arg) = 0) And (Pos('.', Arg) = 0) Then
      Begin
      Ptr := Str2Long(Arg);
      Exit;
      End;
    End
  Else If Arg[1] <> '-' Then
    Begin
    ResolvePtr := False;
    Exit;
    End;
  Key := 0;
  If Arg[1] <> '-' Then
    Begin
    Key := DateKey(Arg);
    If Key = 0 Then
      Begin
      ResolvePtr := False;
      Exit;
      End;
    End;
  If Not OpenMsgArea(M, Config^.GetMsgAreaId(Area)) Then
    Begin
    ResolvePtr := False;
    Exit;
    End;
  New(Nums);
  Cnt := 0;
  Prev := 0;
  Last := 0;
  Found := False;
  M^.SeekFirst(1);
  While M^.SeekFound Do
    Begin
    M^.MsgStartUp;
    N := M^.GetMsgNum;
    If (Key > 0) And (Not Found) Then
      Begin
      If DateKey(M^.GetDate) >= Key Then
        Found := True
      Else
        Prev := N;
      End;
    If Cnt < 1000000 Then
      Begin
      Inc(Cnt);
      Nums^[Cnt] := N;
      End;
    Last := N;
    M^.SeekNext;
    End;
  If CloseMsgArea(M) Then;
  If Key > 0 Then
    Begin
    If Found Then
      Ptr := Prev
    Else
      Ptr := Last;                       {nothing from that day on: nothing is new}
    End
  Else
    Begin
    N := Str2Long(Copy(Arg, 2, 20));
    If (N >= Cnt) Or (N < 0) Then
      Ptr := 0
    Else If N = 0 Then
      Ptr := Last
    Else
      Ptr := Nums^[Cnt - N];
    End;
  Dispose(Nums);
  End;


Function CtlArea(Area: LongInt): Boolean;
  {the node can have this conference}
  Begin
  CtlArea := (Area >= 1) And (Area <= Config^.GetMaxMsgAreas) And (Area <= QwkConfs) And
    (Length(Config^.GetMsgName(Area)) > 0) And Config^.MsgReadAccess(Area, ImpSec);
  End;


Procedure ImpSay(S: String);
  Begin
  If @OffImpSink <> Nil Then
    OffImpSink(S)
  Else
    ImpUser^.DisplayStrLn(S);
  End;


Function ImpControl(Conf: LongInt; Subj: String): Boolean;
  Var
    Cmd, Arg: String;
    Area: LongInt;
    Ptr: LongInt;
    A: Word;
    Ok: Boolean;
    Msg: String;

  Begin
  ImpControl := True;
  Subj := StripBoth(Subj, ' ');
  Cmd := Upper(ExtractWord(Subj, 1));
  Arg := ExtractWord(Subj, 2);
  Ok := False;
  If Cmd = 'ADD' Then
    Begin
    If CtlArea(Conf) And Config^.GetMsgAllowOffline(Conf) And ResolvePtr(Conf, Arg, Ptr) Then
      Begin
      ImpUser^.SetUserOffline(Conf, True);
      If Arg <> '' Then
        OffSetUserLR(Conf, Ptr);
      Ok := True;
      End;
    End
  Else If Cmd = 'DROP' Then
    Begin
    Area := Conf;
    If Arg <> '' Then
      Area := Str2Long(Arg);
    If CtlArea(Area) And (Not Config^.GetMsgForceOffline(Area)) Then
      Begin
      ImpUser^.SetUserOffline(Area, False);
      Ok := True;
      End;
    Conf := Area;
    End
  Else If Cmd = 'RESET' Then
    Begin
    If CtlArea(Conf) And ResolvePtr(Conf, Arg, Ptr) Then
      Begin
      OffSetUserLR(Conf, Ptr);
      Ok := True;
      End;
    End
  Else If Cmd = 'RESETALL' Then
    Begin
    Ok := True;
    For A := 1 To Config^.GetMaxMsgAreas Do
      If (A <= QwkConfs) And CtlArea(A) And (ImpUser^.GetUserOffline(A) Or Config^.GetMsgForceOffline(A)) Then
        If ResolvePtr(A, Arg, Ptr) Then
          OffSetUserLR(A, Ptr)
        Else
          Ok := False;
    Conf := 0;
    End
  Else If Cmd = 'CONTROL' Then
    Begin
    Arg := Upper(Arg);
    Ok := (Arg = '') Or (Arg = 'ON') Or (Arg = 'OFF');
    If Ok Then
      ImpUser^.SetUserQwkControl(Arg <> 'OFF');
    Conf := 0;
    End
  Else If (Cmd = 'FREQ') Or (Cmd = 'FILES') Or (Cmd = 'ATTACH') Or (Cmd = 'CTRL-A') Or (Cmd = 'TZ') Or
          (Cmd = 'VIA') Or (Cmd = 'MSGID') Or (Cmd = 'NDX') Then
    Begin
    ImpSay(Cmd + ': ignored');
    Exit;
    End;
  If Conf > 0 Then
    Msg := ' ' + Long2Str(Conf)
  Else
    Msg := '';
  If Ok Then
    ImpSay(Cmd + Msg + ': done')
  Else
    ImpSay(Cmd + Msg + ': not done');
  ImpControl := Ok;
  End;


Function DoneStr(Ok: Boolean): String;
  Begin
  If Ok Then
    DoneStr := 'done'
  Else
    DoneStr := 'not done';
  End;


Procedure ImpTodoor(FN: String);
  {TODOOR.EXT of the reply packet (QWKE): the caller's changes.  AREA <conf> <flags> (D drops it; a, p, g take it all / personal / personal and to All;
   w, k, f are not kept per area in MK: ignored) and RESET <conf> [n] (no number: the start of the message base, else n messages back from the end).
   KEYWORD, FILTER, TWIT, ATTACH, FILE and REQUEST are for things MK does not have: they are said to be ignored.}
  Var
    T: Text;
    L, Cmd, Flags, Arg: String;
    Area: LongInt;
    Ptr: LongInt;
    Typ: Byte;
    Ok: Boolean;
    i: Word;

  Begin
  Assign(T, FN);
  Reset(T);
  If IoResult <> 0 Then
    Exit;
  While Not Eof(T) Do
    Begin
    ReadLn(T, L);
    L := StripBoth(StripBoth(L, #13), ' ');
    If L = '' Then
      Continue;
    Cmd := Upper(ExtractWord(L, 1));
    Ok := False;
    If Cmd = 'AREA' Then
      Begin
      Area := Str2Long(ExtractWord(L, 2));
      Flags := ExtractWord(L, 3);
      If CtlArea(Area) Then
        Begin
        If Pos('D', Flags) > 0 Then
          Begin
          If Not Config^.GetMsgForceOffline(Area) Then
            Begin
            If Assigned(QwkAreaHook) Then
              QwkAreaHook(Area, 0)
            Else
              ImpUser^.SetUserOffline(Area, False);
            Ok := True;
            End;
          End
        Else If (Pos('a', Flags) > 0) Or (Pos('p', Flags) > 0) Or (Pos('g', Flags) > 0) Then
          Begin
          If Pos('a', Flags) > 0 Then
            Typ := 1
          Else If Pos('g', Flags) > 0 Then
            Typ := 3
          Else
            Typ := 2;
          If Config^.GetMsgAllowOffline(Area) Or Config^.GetMsgForceOffline(Area) Then
            Begin
            If Assigned(QwkAreaHook) Then
              QwkAreaHook(Area, Typ)
            Else
              ImpUser^.SetUserOffline(Area, True);
            Ok := True;
            End;
          End
        Else
          Ok := True;                      {only w, k, f: nothing to keep}
        End;
      ImpSay('AREA ' + Long2Str(Area) + ': ' + DoneStr(Ok));
      End
    Else If Cmd = 'RESET' Then
      Begin
      Area := Str2Long(ExtractWord(L, 2));
      Arg := ExtractWord(L, 3);
      If Arg <> '' Then
        Arg := '-' + Long2Str(Str2Long(Arg));
      If CtlArea(Area) And ResolvePtr(Area, Arg, Ptr) Then
        Begin
        OffSetUserLR(Area, Ptr);
        Ok := True;
        End;
      ImpSay('RESET ' + Long2Str(Area) + ': ' + DoneStr(Ok));
      End
    Else If (Cmd = 'KEYWORD') Or (Cmd = 'FILTER') Or (Cmd = 'TWIT') Or (Cmd = 'ATTACH') Or (Cmd = 'FILE') Or (Cmd = 'REQUEST') Then
      ImpSay(Cmd + ': ignored');
    End;
  Close(T);
  If IoResult <> 0 Then;
  End;


Procedure LedgerAdd(Area: LongInt; Num: LongInt);
  Var
    F: Text;
    Y, M, D, W: Word;

  Begin
  Assign(F, QwkImportLedger);
  If FileExist(QwkImportLedger) Then
    Append(F)
  Else
    Rewrite(F);
  If IoResult = 0 Then
    Begin
    Dos.GetDate(Y, M, D, W);
    WriteLn(F, Area, ' ', Num, ' ', Long2Str(Y * 10000 + M * 100 + D));      {the day: entries are kept 60 days}
    Close(F);
    End;
  If IoResult <> 0 Then;
  End;


Procedure ImpNote(Code: Word; Conf: LongInt; Msg: AbsMsgPtr);
  Var
    A: LongInt;

  Begin
  If @OffImpHook <> Nil Then
    OffImpHook(Code, Conf, Msg);
  Case Code Of
    qiPosted: Begin
              ImpUser^.UpdateForMsg;
              If ImpQI^.Link Then
                Begin
                A := ImpQI^.AreaOf(Conf);
                If (A >= 1) And (A <= QwkConfs) And (Msg <> Nil) Then
                  Begin
                  Inc(ImpQI^.ImpPosted[A]);
                  If (ImpQI^.ImpFirst[A] = 0) Or (Msg^.GetMsgNum < ImpQI^.ImpFirst[A]) Then
                    ImpQI^.ImpFirst[A] := Msg^.GetMsgNum;
                  If Msg^.GetMsgNum > ImpQI^.ImpLast[A] Then
                    ImpQI^.ImpLast[A] := Msg^.GetMsgNum;
                  If QwkImportLedger <> '' Then
                    LedgerAdd(A, Msg^.GetMsgNum);
                  End;
                End;
              End;
    qiDupe: ImpSay(Prompts.GetString(181));
    qiGrunged: ImpSay(Prompts.GetString(182));
    qiMoved: ImpSay(Prompts.GetString(180));
    qiRefused: ImpSay(Prompts.GetString(136) + ' ' + Long2Str(Conf));
    qiFailed: ImpSay(Prompts.GetString(260) + ' ' + Long2Str(Conf));
    End;
  End;


Function FindNoCase(Dir: String; Name: String): String;
  Begin
  FindNoCase := OffFindNoCase(Dir, Name);
  End;


Procedure QwkOffObj.ImportPacket;
  {<BBSID>.MSG in the work path: the messages of the caller's reply packet go into the message areas
   (the settings are SetImportOpts)}
  Var
    FN: String;
    R: QwkImpResult;
    E: Word;
    Sec: SecType;

  Begin
  QI^.Imported := 0;
  ImpQI := QI;
  FillChar(QI^.ImpPosted, SizeOf(QI^.ImpPosted), 0);
  FillChar(QI^.ImpTouched, SizeOf(QI^.ImpTouched), 0);
  FN := FindNoCase(QI^.MsgPath, GetExtractSpec);
  If FN = '' Then
    Exit;
  ImpUser := User;
  ImpUser^.GetUserSec(Sec);
  ImpSec := Sec;
  ImpName := ImpUser^.GetUserName;
  ImpO := ImpOpts;
  If (Not QI^.Link) And ImpUser^.GetUserQwkNode Then
    QwkControl := ImpControl                {a node's control messages: ADD, DROP, RESET ...}
  Else
    QwkControl := Nil;
  E := QwkImportFile(FN, ImpO.DupeFile, ImpMap, ImpNote, R);
  QwkControl := Nil;
  FN := FindNoCase(QI^.MsgPath, 'todoor.ext');
  If FN <> '' Then
    ImpTodoor(FN);                          {QWKE: the caller's changes of areas and pointers}
  If E <> 0 Then
    ImpSay(Prompts.GetString(182))
  Else
    Begin
    QI^.Imported := R.Posted;
    QI^.ReplyMsgs := R.Msgs;
    End;
  End;


Function QwkOffObj.LinkImported(Area: Word; Var Pending, First, Last: LongInt): Word;
  Begin
  LinkImported := 0;
  Pending := 0;
  First := 0;
  Last := 0;
  If (Area >= 1) And (Area <= QwkConfs) And QI^.ImpTouched[Area] Then
    Begin
    Pending := QI^.ImpPending[Area];
    First := QI^.ImpFirst[Area];
    Last := QI^.ImpLast[Area];
    LinkImported := QI^.ImpPosted[Area];
    End;
  End;


Function QwkOffObj.GetImported: LongInt;
  Begin
  GetImported := QI^.Imported;
  End;


Procedure QwkOffObj.SetBBSId(ID: String);
  Begin
  QI^.BBSId := Id;
  End;


End.
