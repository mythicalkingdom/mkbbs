Unit MKOffXRS;       {XRS Offline mail Object}

{$I MKB.Def}

Interface

{
     MKOffXRS - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Uses MKGlobT, MKMsgAbs, MKCfgAbs, MKOffAbs,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}

Const
  MaxMsgs = 2000;

Type MailIdxType = Record
  MsgNum: Word;
  Area: Word;
  Flag: Word;
  ReferTo: Word;
  SeekPos: LongInt;
  End;


Type MailIdxArrayType = Array[1..MaxMsgs] of MailIdxType;

Type XRSInfoType = Record
  MsgPath: String[128];
  MsgFile: Text;
  BBSID: String[8];
  Error: Word;
  NumMsgs: Word;
  MailIdx: ^MailIdxArrayType;
  Name: String[35];
  Handle: String[35];
  End;


Type XRSOffObj = Object(AbsOffObj)
  XI: ^XRSInfoType;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetPath(MP: String); Virtual; {Set msg path/other info}
  Procedure SetBBSId(ID: String); Virtual;
  Function  StartPacket: Word; Virtual; {Do Packet startup tasks}
  Function  ClosePacket: Word; Virtual; {Do Packet finish tasks}
  Function  AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean; Virtual;
  Function  GetArchiveName(Packer: Word): String; Virtual;
  Procedure CreateAreasXRS;
  Procedure CreateAccessXrs;
  Procedure CreateUserXrs;
  End;


Type XRSOffPtr = ^XRSOffObj;


Implementation

Uses MKString, MKFile, MKUsrAbs;

Constructor XRSOffObj.Init;
  Begin
  New(XI);
  XI^.Error := 0;
  XI^.NumMsgs := 0;
  End;


Destructor XRSOffObj.Done;
  Begin
  Dispose(XI);
  End;


Procedure XRSOffObj.SetPath(MP: String);
  Begin
  XI^.MsgPath := WithBackSlash(MP);
  End;


Procedure XrsOffObj.CreateAreasXRS;
  Type CArrayType = Array[1..41000] of Char;
  Var
    CA:^CArrayType;
    Loc: Word;
    Area: Word;
    Sec: SecType;
    i: Word;
    TmpStr: String;

  Begin
  New(CA);
  Loc := 2;
  User^.GetUserSec(@Sec);
  CA^[1] := '|';
  CA^[2] := '|';
  For Area := 1 to 500 Do
    Begin
    If Config^.MsgReadAccess(Area,Sec) Then
      Begin
      TmpStr := Config^.GetMsgName(Area);
      If Length(TmpStr) > 0 Then
        For i := 1 to Length(TmpStr) Do
          Begin
          Inc(Loc);
          CA^[Loc] := TmpStr[i];
          End;
      End;
    Inc(Loc);
    CA^[Loc] := '|';
    If Config^.MsgReadAccess(Area,Sec) Then
      Begin
      TmpStr := Upper(Config^.GetEchoAreaTag(Area));
      If Length(TmpStr) = 0 Then
        TmpStr := Upper(Config^.GetMsgName(Area));
      If Length(TmpStr) > 0 Then
        For i := 1 to Length(TmpStr) Do
          Begin
          Inc(Loc);
          If TmpStr[i] = ' ' Then
            CA^[Loc] := '_'
          Else
            CA^[Loc] := TmpStr[i];
          End;
      End;
    Inc(Loc);
    CA^[Loc] := '|';
    End;
  If SaveFile(XI^.MsgPath + 'AREAS1.XRS', CA^, Loc) = 0 Then;
  Dispose(CA);
  End;


Procedure XRSOffObj.CreateAccessXrs;
  Type AccessType = Record
    Attr: Byte;
    Zone: Word;
    Net: Word;
    Node: Word;
    End;

  Type AccessArray = Array[0..500] of AccessType;

  Var
    xs: ^AccessArray;
    Area: Word;
    Sec: SecType;
    Addr: AddrType;
    Sec2: SecType;

  Begin
  New(xs);
  Config^.GetCrashNmSec(Sec2);
  User^.GetUserSec(@Sec);
  FillChar(xs^, SizeOf(xs^), 0);
  For Area := 1 to 500 Do
    Begin
    If Config^.GetMsgAddrNum(Area) <> 1 Then
      Begin
      Config^.GetMsgAddr(Area, Addr);
      xs^[Area].Zone := Addr.Zone;
      xs^[Area].Net := Addr.Net;
      xs^[Area].Node := Addr.Node;
      End;
    If Config^.MsgWriteAccess(Area, Sec) Then
      Begin
      If Config^.MsgAllowPriv(Area) Then
        Inc(xs^[Area].Attr,1);
      If Config^.MsgAllowPubl(Area) Then
        Inc(xs^[Area].Attr, 2);
      End;
    Case Config^.GetMsgType(Area) of
      NetMail: Inc(xs^[Area].Attr, 8);
      Normal: Inc(xs^[Area].Attr, 4);
      End;
    If Config^.GetMsgType(Area) = Normal Then
      Begin
      If Access(Sec, Sec2) Then
        Inc(xs^[Area].Attr, 16);
      End
    Else
      Begin
      If Config^.MsgAllowHdl(Area) or Config^.MsgAllowAnon(Area) Then
        Inc(xs^[Area].Attr, 16);
      End;
    If Config^.GetMsgReaderOrig(Area) Then
      Inc(xs^[Area].Attr, 32);
    End;
  If SaveFile(XI^.MsgPath + 'ACCESS1.XRS', xs^, SizeOf(xs^)) = 0 Then;
  Dispose(xs);
  End;


Procedure XrsOffObj.CreateUserXrs;
  Type UserXrsType = Record
    Name: Array[1..25] of Char;
    OriginCRC: Word;
    BbsName: Array[1..4] of Char;
    CrcCheck: Word;
    PointNet: Word;
    Addr: AddrType;
    Alias: Array[1..25] of Char;
    End;

  Var
    UserInfo: UserXrsType;
    TmpStr: String;
    i: Word;
    Addr: AddrType;

  Begin
  FillChar(UserInfo, SizeOf(UserInfo), #0);
  Config^.GetAddr(1, Addr);
  UserInfo.Addr := Addr;
  UserInfo.PointNet := 30027;
  UserInfo.BBSName[1] := 'M';
  UserInfo.BBSName[2] := 'K';
  UserInfo.BBSName[3] := ' ';
  UserInfo.BBSName[4] := ' ';
  TmpStr := Upper(User^.GetUserName);
  For i := 1 to 25 Do
    Begin
    If i <= Length(TmpStr) Then
      UserInfo.Name[i] := TmpStr[i]
    Else
      UserInfo.Name[i] := ' ';
    End;
  TmpStr := Upper(User^.GetUserHandle);
  For i := 1 to 25 Do
    Begin
    If i <= Length(TmpStr) Then
      UserInfo.Alias[i] := TmpStr[i]
    Else
      UserInfo.Alias[i] := ' ';
    End;
  UserInfo.CRCCheck := UserInfo.PointNet + Addr.Zone + Addr.Net + Addr.Node + Addr.Point;
  For i := 1 to 25 Do
    Inc(UserInfo.CrCCheck, Ord(UserInfo.Name[i]));
  UserInfo.CrcCheck := UserInfo.CrcCheck or 32768;
  If SaveFile(XI^.MsgPath + 'USER1.XRS', UserInfo, SizeOf(UserInfo)) = 0 Then;
  End;


Function XRSOffObj.StartPacket: Word;
  Var
    F: File;

  Begin
  New(XI^.MailIdx);
  XI^.NumMsgs := 0;
  XI^.Error := 0;
  Assign(XI^.MsgFile, XI^.MsgPath + 'BAT1MAIL.XRS');
  ReWrite(XI^.MsgFile);
  WriteLn(XI^.MsgFile, '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=');
  WriteLn(XI^.MsgFile, '= MK Offline Mail System - by Mark May - in XRS mode                          =');
  WriteLn(XI^.MsgFile, '= XRS format by Mike Ratledge                                                 =');
  WriteLn(XI^.MsgFile, '=-=-=-=-=-=-=');
  XI^.Error := IoResult;
  XI^.Name := Upper(User^.GetUserName);
  XI^.Handle := Upper(User^.GetUserHandle);
  StartPacket := IoResult;
  CreateAreasXRS;
  CreateAccessXRS;
  CreateUserXRS;
  End;


Function XRSOffObj.ClosePacket: Word;
  Var
    IdxSize: LongInt;

  Begin
  Close(XI^.MsgFile);
  ClosePacket := IoResult;
  IdxSize := XI^.NumMsgs;
  IdxSize := IdxSize * SizeOf(MailIdxType);
  If SaveFile(XI^.MsgPath + 'MAIL1IDX.XRS', XI^.MailIdx^, IdxSize) = 0 Then;
  Dispose(XI^.MailIdx);
  End;


Function XRSOffObj.AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean;
  Const
    StrLen = 78;

  Var
    TmpStr: String;
    Addr: AddrType;

  Begin
  If XI^.NumMsgs < MaxMsgs Then
    Begin
    Inc(XI^.NumMsgs);
    XI^.MailIdx^[XI^.NumMsgs].MsgNum := (Msg.GetMsgNum and $ffff);
    XI^.MailIdx^[XI^.NumMsgs].Area := Area;
    XI^.MailIdx^[XI^.NumMsgs].SeekPos := GetTextPos(XI^.MsgFile);
    XI^.MailIdx^[XI^.NumMsgs].ReferTo := Msg.GetRefer;
    If ToYou Then
      XI^.MailIdx^[XI^.NumMsgs].Flag := 1
    Else
      XI^.MailIdx^[XI^.NumMsgs].Flag := 0;
    Write(XI^.MsgFile, '      To:  ');
    Write(XI^.MsgFile, Copy(PadRight(Msg.GetTo,' ',26),1,26));
    Write(XI^.MsgFile, ' Message #:  ');
    WriteLn(XI^.MsgFile, Long2Str(Msg.GetMsgNum));
    Write(XI^.MsgFile, '    From:  ');
    Write(XI^.MsgFile, Copy(PadRight(Msg.GetFrom,' ',26),1,26));
    Write(XI^.MsgFile, ' Submitted:  ');
    Write(XI^.MsgFile, ReformatDate(Msg.GetDate, 'DD NNN YY') + ' ');
    WriteLn(XI^.MsgFile, Msg.GetTime + ':00');
    Write(XI^.MsgFile, ' Subject:  ');
    Write(XI^.MsgFile, Copy(PadRight(Msg.GetSubj,' ',26),1,26));
    Write(XI^.MsgFile, '    Status:  ');
    If Msg.IsPriv Then
      WriteLn(XI^.MsgFile, 'Private')
    Else
      WriteLn(XI^.MsgFile, 'Public');
    Write(XI^.MsgFile, 'Received:  ');
    If Msg.IsRcvd Then
      Write(XI^.MsgFile, 'Yes                            Group:  ')
    Else
      Begin
      If ToYou Then
        Write(XI^.MsgFile, '** New Message Read! **        Group:  ')
      Else
        Write(XI^.MsgFile, 'No                             Group:  ');
      End;
    Write(XI^.MsgFile, Copy(Config^.GetMsgName(Area),1,30));
    WriteLn(XI^.MsgFile, ' ('+Long2Str(Area) + ')');
    WriteLn(XI^.MsgFile, '');
    If Config^.GetMsgType(Area) = NetMail Then
      Begin
      Msg.GetOrig(Addr);
      WriteLn(XI^.MsgFile, 'From-Addr: ', AddrStr(Addr));
      End;
    Msg.MsgTxtStartUp;
    TmpStr := Msg.GetString(StrLen);
    While (Not Msg.EOM) Do
      Begin
      WriteLn(XI^.MsgFile, TmpStr);
      TmpStr := Msg.GetString(StrLen);
      End;
    WriteLn(XI^.MsgFile,'=-=-=-=-=-=-=');
    End;
  AddMsg := IoResult = 0;
  End;


Function XRSOffObj.GetArchiveName(Packer: Word): String;
  Var
    TmpStr: String[15];

  Begin
  TmpStr := Copy(XI^.BBSID, 1, 7) + '1.';
  Case Packer Of
    1: TmpStr := TmpStr + 'LXR';
    2: TmpStr := TmpStr + 'ZXR';
    3: TmpStr := TmpStr + 'AXR';
    4: TmpStr := TmpStr + 'OXR';
    5: TmpStr := TmpStr + 'DXR';
    6: TmpStr := TmpStr + 'JXR';
    7: TmpStr := TmpStr + 'HXR';
    Else
      TmpStr := TmpStr + 'XXR';
    End;
  GetArchiveName := TmpStr;
  End;


Procedure XRSOffObj.SetBBSId(ID: String);
  Begin
  XI^.BBSID := Id;
  End;


End.
