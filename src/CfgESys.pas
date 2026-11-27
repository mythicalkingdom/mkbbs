{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgESys;   {One echomail system, converted from CFGESYS}

{$I MKB.Def}

Interface

Procedure DoCfgESys(SysNum: Word);

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgList, CfgNet;

Type
  UserRecord = Record
    Addr: AddrType;
    Archiver: Byte;
    MailType: Byte;
    Pwd: String[15];
    PktPwd: String[8];
    End;

Var
  SysNo: Word;


Function AreaStr(Item: Word): String;
  Begin
  AreaStr := PadRight(Long2Str(Item), ' ', 4) + Copy(Config^.GetMsgName(Item), 1, 19);
  End;


Procedure EchoPick(Data: Pointer; Title: String);
  {The message areas that are sent to this system}
  Var
    Marks: CfgBigMarks;
    i: Word;

  Begin
  For i := 1 To 500 Do
    Marks[i] := Config^.GetEchoToArea(i, SysNo);
  If RunMarkList('Message Areas sent to system ' + Long2Str(SysNo), 500, 28, AreaStr, Marks) Then
    For i := 1 To 500 Do
      Config^.SetEchoToArea(i, SysNo, Marks[i]);
  End;


Procedure NetPick(Data: Pointer; Title: String);
  Begin
  DoCfgNet(SysNo);
  End;


Procedure DoCfgESys(SysNum: Word);
  Var
    UR: ^UserRecord;
    F: CfgFormObj;
    M: ^MailerCfgType;

  Begin
  New(UR);
  SysNo := SysNum;
  Config^.GetEchoToAddr(SysNum, UR^.Addr);
  UR^.Archiver := Config^.GetEchoToPacker(SysNum);
  UR^.Pwd := Config^.GetEchoToPwd(SysNum);
  UR^.MailType := Config^.GetEchoToMailType(SysNum);
  UR^.PktPwd := '';
  If Config^.HasMailer Then
    Begin
    New(M);
    Config^.GetMailer(M^);
    UR^.PktPwd := M^.PktPwd[SysNum];
    End;
  F.Init('System ' + Long2Str(SysNum));
  F.Window(11, 7, 65, 15);
  F.At(2, 3, 2, 9);
  F.AddNumber('Zone:', UR^.Addr.Zone, 2, 0, 65535, 'Zone of the system');
  F.At(2, 16, 2, 21);
  F.AddNumber('Net:', UR^.Addr.Net, 2, 0, 65535, 'Net of the system');
  F.At(2, 28, 2, 34);
  F.AddNumber('Node:', UR^.Addr.Node, 2, 0, 65535, 'Node of the system');
  F.At(2, 41, 2, 48);
  F.AddNumber('Point:', UR^.Addr.Point, 2, 0, 65535, 'Point of the system');
  F.At(4, 3, 4, 16);
  F.AddString('Areafix pwd:', UR^.Pwd, 15, 'Password for Areafix requests');
  F.At(4, 34, 4, 42);
  F.AddChoice('Packer:', UR^.Archiver, 1, 0, 'None|LZH|ZIP|ARC|ZOO|DWC|ARJ|HYP',
    'Archiver used for the mail (Space or arrows change it)');
  F.At(6, 3, 6, 3);
  F.AddAction('Echos...', EchoPick, Nil, '', 'Message areas sent to this system');
  F.At(6, 21, 6, 21);
  F.AddAction('Network Security...', NetPick, Nil, '', 'Networks this system may use');
  F.At(6, 47, 6, 58);
  F.AddChoice('Mail Type:', UR^.MailType, 1, 0, 'IMMED|CRASH|NORMAL|HOLD',
    'How the mail is sent (Space or arrows change it)');
  If Config^.HasMailer Then
    Begin
    F.At(8, 3, 8, 16);
    F.AddString('Packet pwd:', UR^.PktPwd, 8, 'Packet password, 8 characters at most');
    End;
  If F.Execute Then
    Begin
    If Config^.HasMailer Then
      Begin
      M^.PktPwd[SysNum] := UR^.PktPwd;
      Config^.SetMailer(M^);
      End;
    Config^.SetEchoToAddr(SysNum, UR^.Addr);
    Config^.SetEchoToPacker(SysNum, UR^.Archiver);
    Config^.SetEchoToPwd(SysNum, UR^.Pwd);
    Config^.SetEchoToMailType(SysNum, UR^.MailType);
    End;
  If Config^.HasMailer Then
    Dispose(M);
  Dispose(UR);
  End;


End.
