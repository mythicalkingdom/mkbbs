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
  Link: Boolean;                       {SetLink: the packet is a REP for another system}
  LinkId: String[40];
  ConfOf: QwkConfFunc;                 {area -> conference of the other end}
  AreaOf: QwkConfFunc;                 {conference of the other end -> area}
  ImpPosted: Array[1..QwkConfs] Of Word; {link: messages the import posted in each area}
  ImpPending: Array[1..QwkConfs] Of LongInt; {link: messages of the area still to be sent before the import}
  ImpFirst: Array[1..QwkConfs] Of LongInt; {link: numbers of the first and the last message the import posted}
  ImpLast: Array[1..QwkConfs] Of LongInt;
  ImpTouched: Array[1..QwkConfs] Of Boolean;
  End;


Type QwkOffObj = Object(AbsOffObj)
  QI: ^QwkInfo;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetPath(MP: String); Virtual; {Set msg path/other info}
  Procedure SetBBSID(ID: String); Virtual; {Set bbs id/filename}
  Procedure SetKeepKludges(KK: Boolean);
  Procedure SetQwke(QK: Boolean); Virtual;
  Procedure SetLink(RemoteId: String; ConfOf: QwkConfFunc; AreaOf: QwkConfFunc);
  Function  LinkImported(Area: Word; Var Pending, First, Last: LongInt): Word;
    {link: messages the import posted in the area, the numbers of the first and last, and how many messages of the
     area were still to be sent before it (the last read of the user is before them)}
  Function  StartPacket: Word; Virtual; {Do Packet startup tasks}
  Function  ClosePacket: Word; Virtual; {Do Packet finish tasks}
  Function  AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean; Virtual;
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
  WriteLn(CFile, 'CONTROLNAME = MKQWK');
  WriteLn(CFile, 'CONTROLTYPE = ADD');
  WriteLn(CFile, 'CONTROLTYPE = DROP');
  WriteLn(CFile, 'CONTROLTYPE = RESET');
  WriteLn(CFile, 'CONTROLTYPE = BLTS');
  WriteLn(CFile, 'CONTROLTYPE = FILES');
  WriteLn(CFile, 'CONTROLTYPE = NEWS');
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
  WriteLn(CF, 'welcome.ans');
  WriteLn(CF, 'news.ans');
  WriteLn(CF, 'goodbye.ans');
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
    DoControl;
    WriteDoorId;
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
    T.TearLine := '--- MK Bbs v0.01';
    T.OriginLine := Config^.GetDefaultOrigStr(Area);
    End;
  ImpMap := True;
  End;


Procedure ImpNote(Code: Word; Conf: LongInt; Msg: AbsMsgPtr);
  Var
    A: LongInt;

  Begin
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
                  End;
                End;
              End;
    qiDupe: ImpUser^.DisplayStrLn(Prompts.GetString(181));
    qiGrunged: ImpUser^.DisplayStrLn(Prompts.GetString(182));
    qiMoved: ImpUser^.DisplayStrLn(Prompts.GetString(180));
    qiRefused: ImpUser^.DisplayStrLn(Prompts.GetString(136) + ' ' + Long2Str(Conf));
    qiFailed: ImpUser^.DisplayStrLn(Prompts.GetString(260) + ' ' + Long2Str(Conf));
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
  E := QwkImportFile(FN, ImpO.DupeFile, ImpMap, ImpNote, R);
  If E <> 0 Then
    ImpUser^.DisplayStrLn(Prompts.GetString(182))
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
