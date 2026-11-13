Unit HdrEnt;   {Header of a new message (Free Vision), converted from HDRENT}

{$I MKB.Def}

Interface

Type MsgHdrInfoType = Record
  MsgName: string[30];
  MsgPriv: Boolean;
  MsgFrom: string[35];
  MsgToAddr: string[18];
  MsgTo: string[35];
  MsgSubj: string[65];
  Crash: Boolean;
  Imm: Boolean;
  Direct: Boolean;
  FileReq: Boolean;
  FAttach: Boolean;
  KillSent: Boolean;
  NetTaglines: Boolean;
  NetFido: Boolean;
  SysName: String[30];
  Sysop: String[25];
  Location: String[35];
  Baud: String[6];
  RefNum: LongInt;
  End;

Var
  MsgHdrInfo: MsgHdrInfoType;
  NewMsgIsNet: Boolean;

Procedure GetNewMsgHdr;
Procedure AttachHelp;

Implementation

Uses MKNSrch, MKGlobT, MKCfgAbs, MKEnter, MKString, MKFile, CfgForm, CfgList;


Procedure UpdateNodeInfo(Data: Pointer; Title: String);
  {Look the address in "To" up in the nodelist}
  Var
    Nodes: NodeListObj;
    Addr: AddrType;
    DAddr: AddrType;
    TmpStr: String;

  Begin
  Config^.GetAddr(1, DAddr);
  If ParseAddr(MsgHdrInfo.MsgToAddr, DAddr, Addr) Then
    Begin
    If ((DAddr.Zone = Addr.Zone) And (DAddr.Net = Addr.Net)
    And (DAddr.Node = Addr.Node) And (DAddr.Point = Addr.Point)) Then
      Begin
      MsgHdrInfo.SysName := '';
      MsgHdrInfo.Sysop := '';
      MsgHdrInfo.Location := '';
      MsgHdrInfo.Baud := '';
      End
    Else
      Begin
      Nodes.Init;
      Nodes.Load;
      TmpStr := Nodes.NodeStr(Addr);
      Nodes.Done;
      MsgHdrInfo.SysName := GetNodeSection(TmpStr, 2);
      MsgHdrInfo.Sysop := GetNodeSection(TmpStr, 4);
      MsgHdrInfo.Location := GetNodeSection(TmpStr, 3);
      MsgHdrInfo.Baud := GetNodeSection(TmpStr, 6);
      If MsgHdrInfo.MsgTo = '' Then
        MsgHdrInfo.MsgTo := MsgHdrInfo.Sysop;
      End;
    End;
  End;


Procedure GetNewMsgHdr;
  Var
    F: CfgFormObj;

  Begin
  If NewMsgIsNet Then
    UpdateNodeInfo(Nil, '');
  F.Init('New Message');
  If NewMsgIsNet Then
    F.Window(2, 2, 79, 8)
  Else
    F.Window(2, 2, 79, 4);
  F.At(1, 3, 1, 9);
  F.AddString('From:', MsgHdrInfo.MsgFrom, 35, 'Who the message is from');
  F.At(1, 55, 1, 66);
  F.AddNumber('Refer Num:', MsgHdrInfo.RefNum, 4, 0, 2147483647, 'Number of the message this answers');
  F.At(2, 3, 2, 7);
  F.AddString('To:', MsgHdrInfo.MsgTo, 35, 'Who the message is to');
  If NewMsgIsNet Then
    Begin
    F.At(2, 44, 2, 46);
    F.AddString('', MsgHdrInfo.MsgToAddr, 18, 'Network address, for example 1:110/290 (looked up when you leave the field)');
    F.OnLeave(UpdateNodeInfo, Nil);
    End;
  F.At(3, 3, 3, 9);
  F.AddString('Subj:', MsgHdrInfo.MsgSubj, 65, 'Subject of the message');
  If NewMsgIsNet Then
    Begin
    F.At(5, 3, 5, 11);
    F.AddString('System:', MsgHdrInfo.SysName, 30, 'Name of the system (from the nodelist)');
    F.At(5, 45, 5, 52);
    F.AddString('Sysop:', MsgHdrInfo.Sysop, 25, 'Sysop of the system');
    F.At(6, 3, 6, 13);
    F.AddString('Location:', MsgHdrInfo.Location, 30, 'Where the system is');
    F.At(6, 50, 6, 56);
    F.AddString('Baud:', MsgHdrInfo.Baud, 6, 'Speed of the system');
    End;
  If F.Execute Then;
  End;


Procedure AttachHelp;
  Var
    SR: FindObj;
    ND: Word;
    WC: Word;
    TW: Word;
    TmpStr: String;
    Text: String;

  Begin
  SR.Init;
  Text := 'The following files are File-Attached to this message' + #13#13;
  TW := WordCount(MsgHdrInfo.MsgSubj);
  WC := 1;
  ND := 0;
  While ((WC <= TW) and (ND < 20)) Do
    Begin
    TmpStr := ExtractWord(MsgHdrInfo.MsgSubj, WC);
    SR.FFirst(TmpStr);
    While ((SR.Found) and (ND < 20)) Do
      Begin
      Inc(ND);
      Text := Text + PadRight(SR.GetName, ' ', 15) +
        PadLeft(CommaStr(SR.GetSize), ' ', 9) + ' ... ' +
        Copy(SR.GetFullPath, 1, 48) + #13;
      SR.FNext;
      End;
    Inc(WC);
    End;
  SR.Done;
  ShowText('File Attach', Text);
  End;


End.
