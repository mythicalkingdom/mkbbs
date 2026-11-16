Unit CfgMsg;   {One message area, converted from CFGMSG}

{$I MKB.Def}

Interface

Procedure DoCfgMsg(MsgNum: Word);

Implementation

Uses Objects, Drivers, Views, App, MsgBox, MKString, MKGlobT, MKCfgAbs, MKMsgAbs,
  MKMsgSqu, MKMsgMer, MKMsgSyn, CfgForm, CfgList, CfgSec2, CfgNet;

Type
  UserRecord = Record
    AreaNum: Word;
    Name: String[40];
    ShortName: String[12];
    FileId: String[13];
    MsgPath: String[70];
    DaysKept: Word;
    MsgsKept: Word;
    RcvdDays: Word;
    Addr: String[25];
    ReadSec: SecType;
    WriteSec: SecType;
    SysopSec: SecType;
    Origin: String[55];
    AreaTag: String[40];
    Hub: String[25];
    Select: String[4];
    TypeIdx: Byte;                       {0 Normal, 1 NetMail, 2 EchoMail}
    FormatIdx: Byte;                     {0 H, 1 S, 2 F, 3 J, 4 M, 5 Y, 6 other (unchanged)}
    End;

Const
  FormatChars = 'HSFJMY';              {Hudson, Squish, *.Msg, JAM, Merlin, Synchronet}

Var
  UR: ^UserRecord;


{------------------------------------------------------------ the pickers}

Function AddrItem(Item: Word): String;
  Var
    A: AddrType;

  Begin
  Config^.GetAddr(Item, A);
  AddrItem := PadLeft(Long2Str(Item), ' ', 3) + '  ' + AddrStr(A);
  End;


Procedure PickAddr(Data: Pointer; Title: String);
  Var
    N: Word;

  Begin
  N := Config^.GetMsgAddrNum(UR^.AreaNum);
  If RunPick('Address', 10, 34, AddrItem, N) Then
    Begin
    Config^.SetMsgAddrNum(UR^.AreaNum, N);
    UR^.Addr := Config^.GetMsgAddrStr(UR^.AreaNum);
    End;
  End;


Function OrigItem(Item: Word): String;
  Begin
  OrigItem := PadLeft(Long2Str(Item), '0', 2) + ' ' + Config^.GetOrigStr(Item);
  End;


Procedure PickOrig(Data: Pointer; Title: String);
  Var
    N: Word;

  Begin
  N := Config^.GetMsgOrigNum(UR^.AreaNum);
  If RunPick('Origin Line', 20, 60, OrigItem, N) Then
    Begin
    Config^.SetMsgOrigNum(UR^.AreaNum, N);
    UR^.Origin := Config^.GetOrigStr(Config^.GetMsgOrigNum(UR^.AreaNum));
    End;
  End;


Function PathItem(Item: Word): String;
  Begin
  PathItem := Config^.GetMsgPath(Item);
  End;


Procedure PickPath(Data: Pointer; Title: String);
  Var
    N: Word;

  Begin
  N := Config^.GetMsgPathNum(UR^.AreaNum);
  If RunPick('Msg Base Path', 10, 66, PathItem, N) Then
    Begin
    Config^.SetMsgPathNum(UR^.AreaNum, N);
    UR^.MsgPath := Config^.GetMsgPath(N);
    End;
  End;


Function EchoSysItem(Item: Word): String;
  Var
    A: AddrType;

  Begin
  Config^.GetEchoToAddr(Item, A);
  EchoSysItem := PadLeft(Long2Str(Item), ' ', 3) + '  ' + AddrStr(A);
  End;


Procedure PickHub(Data: Pointer; Title: String);
  Var
    N: Word;
    A: AddrType;

  Begin
  N := Config^.GetEchoToHub(UR^.AreaNum);
  If RunPick('Hub', 32, 34, EchoSysItem, N) Then
    Begin
    Config^.SetEchoToHub(UR^.AreaNum, N);
    Config^.GetEchoToAddr(N, A);
    UR^.Hub := AddrStr(A);
    End;
  End;


Function NetItem(Item: Word): String;
  Begin
  NetItem := 'Network - ' + Char(Item + Ord('A') - 1);
  End;


Procedure PickNetStatus(Data: Pointer; Title: String);
  Var
    Marks: CfgBigMarks;
    i: Word;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  For i := 1 To 26 Do
    Marks[i] := Config^.GetMsgNetwork(UR^.AreaNum, i);
  If RunMarkList('Networks', 26, 24, NetItem, Marks) Then
    For i := 1 To 26 Do
      Config^.SetMsgNetwork(UR^.AreaNum, i, Marks[i]);
  End;


Procedure PickOptions(Data: Pointer; Title: String);
  Var
    M: CfgMarks;
    A: Word;

  Begin
  A := UR^.AreaNum;
  FillChar(M, SizeOf(M), 0);
  M[1] := Config^.MsgAllowAnsi(A);
  M[2] := Config^.MsgAllowHiBit(A);
  M[3] := Config^.MsgAllowTag(A);
  M[4] := Config^.GetMsgAllowOffline(A);
  M[5] := Config^.GetMsgForceOffline(A);
  M[6] := Config^.GetMsgAllowCombined(A);
  M[7] := Config^.MsgAddFido(A);
  M[8] := Config^.GetMsgReaderTear(A);
  M[9] := Config^.GetMsgFAttach(A);
  M[10] := Config^.GetMsgDefCombined(A);
  M[11] := Config^.MsgAllowPriv(A);
  M[12] := Config^.MsgAllowPubl(A);
  M[13] := Config^.MsgAllowReal(A);
  M[14] := Config^.MsgAllowHdl(A);
  M[15] := Config^.MsgAllowAnon(A);
  M[16] := Config^.GetMsgReaderOrig(A);
  If RunChecks('Message Options',
    'Allow Ansi|Allow HiBit|Allow Taglines|Allow Offline|Force Offline|' +
    'Allow Combined|Add Fido Info|Reader Tearline|Allow File Attach|' +
    'Default Combined|Allow Private|Allow Public|Allow Real Name|' +
    'Allow Handle|Allow Alias|Reader Origin Line', M) Then
    Begin
    Config^.SetMsgAllowAnsi(A, M[1]);
    Config^.SetMsgAllowHiBit(A, M[2]);
    Config^.SetMsgAllowTag(A, M[3]);
    Config^.SetMsgAllowOffline(A, M[4]);
    Config^.SetMsgForceOffline(A, M[5]);
    Config^.SetMsgAllowCombined(A, M[6]);
    Config^.SetMsgAddFido(A, M[7]);
    Config^.SetMsgReaderTear(A, M[8]);
    Config^.SetMsgFAttach(A, M[9]);
    Config^.SetMsgDefCombined(A, M[10]);
    Config^.SetMsgAllowPriv(A, M[11]);
    Config^.SetMsgAllowPubl(A, M[12]);
    Config^.SetMsgAllowReal(A, M[13]);
    Config^.SetMsgAllowHdl(A, M[14]);
    Config^.SetMsgAllowAnon(A, M[15]);
    Config^.SetMsgReaderOrig(A, M[16]);
    End;
  End;


Procedure PickFidoOptions(Data: Pointer; Title: String);
  Var
    M: CfgMarks;
    A: Word;

  Begin
  A := UR^.AreaNum;
  FillChar(M, SizeOf(M), 0);
  M[1] := Config^.GetEchoAreaPassThru(A);
  M[2] := Config^.GetEchoAreaImportPath(A);
  M[3] := Config^.GetEchoAreaHidePath(A);
  M[4] := Config^.GetEchoAreaImportSeen(A);
  M[5] := Config^.GetEchoAreaHideSeen(A);
  If RunChecks('Fido Options',
    'Pass-Thru Area|Import Path|Hide Imported Path|Import Seen-By|Hide Imported Seen-By', M) Then
    Begin
    Config^.SetEchoAreaPassThru(A, M[1]);
    Config^.SetEchoAreaImportPath(A, M[2]);
    Config^.SetEchoAreaHidePath(A, M[3]);
    Config^.SetEchoAreaImportSeen(A, M[4]);
    Config^.SetEchoAreaHideSeen(A, M[5]);
    End;
  End;


Function AreaItem(Item: Word): String;
  Begin
  AreaItem := PadRight(Long2Str(Item), ' ', 4) + Copy(Config^.GetMsgName(Item), 1, 19);
  End;


Procedure PickEchoTo(Data: Pointer; Title: String);
  {The echomail systems this area is sent to}
  Var
    Marks: CfgBigMarks;
    i: Word;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  For i := 1 To 32 Do
    Marks[i] := Config^.GetEchoToArea(UR^.AreaNum, i);
  If RunMarkList('Echo To (systems)', 32, 34, EchoSysItem, Marks) Then
    For i := 1 To 32 Do
      Config^.SetEchoToArea(UR^.AreaNum, i, Marks[i]);
  End;


{------------------------------------------------------------ the area}

Procedure DoCfgMsg(MsgNum: Word);
  Var
    F: CfgFormObj;
    Msg: AbsMsgPtr;
    A: AddrType;
    BT: Char;
    P: Word;

  Begin
  New(UR);
  UR^.AreaNum := MsgNum;
  UR^.Name := Config^.GetMsgName(MsgNum);
  UR^.ShortName := Config^.GetMsgShortName(MsgNum);
  UR^.AreaTag := Config^.GetEchoAreaTag(MsgNum);
  UR^.Select := Config^.GetMsgSelect(MsgNum);
  UR^.FileId := Config^.GetMsgFileId(MsgNum);
  UR^.MsgPath := Config^.GetMsgPath(Config^.GetMsgPathNum(MsgNum));
  Config^.GetMsgReadSecurity(MsgNum, UR^.ReadSec);
  Config^.GetMsgWriteSecurity(MsgNum, UR^.WriteSec);
  Config^.GetMsgSysopSecurity(MsgNum, UR^.SysopSec);
  Config^.GetEchoToAddr(Config^.GetEchoToHub(MsgNum), A);
  UR^.Hub := AddrStr(A);
  UR^.Addr := Config^.GetMsgAddrStr(MsgNum);
  UR^.Origin := Config^.GetMsgOrigStr(MsgNum);
  UR^.DaysKept := Config^.GetMsgDays(MsgNum);
  UR^.MsgsKept := Config^.GetMsgsKept(MsgNum);
  UR^.RcvdDays := Config^.GetMsgRcvdDays(MsgNum);
  BT := Config^.GetMsgBaseType(MsgNum);
  P := Pos(BT, FormatChars);
  If P > 0 Then
    UR^.FormatIdx := P - 1
  Else
    UR^.FormatIdx := 6;
  Case Config^.GetMsgType(MsgNum) Of
    NetMail: UR^.TypeIdx := 1;
    EchoMail: UR^.TypeIdx := 2;
    Else UR^.TypeIdx := 0;
    End;
  F.Init('Message Area ' + Long2Str(MsgNum));
  F.Window(1, 1, 78, 12);
  F.At(2, 3, 2, 9);
  F.AddString('Name:', UR^.Name, 40, 'Name of the message area');
  F.At(2, 52, 2, 64);
  F.AddString('Short Name:', UR^.ShortName, 12, 'Short name of the area');
  F.At(3, 3, 3, 12);
  F.ReadOnly;
  F.AddString('Address:', UR^.Addr, 25, 'System address used in this area');
  F.OnF2(PickAddr, Nil, '');
  F.At(3, 36, 3, 42);
  F.AddChoice('Type:', UR^.TypeIdx, 1, 0, 'Normal|NetMail|EchoMail',
    'Kind of mail (Space or the arrow keys change it)');
  F.At(3, 53, 3, 61);
  F.AddChoice('Format:', UR^.FormatIdx, 1, 0, 'hudson|squish|*.msg|jam|merlin|synchronet|other',
    'Message base format (Other leaves the current one)');
  F.At(4, 3, 4, 14);
  F.AddNumber('Days Kept:', UR^.DaysKept, 2, 0, 65535, 'Days messages are kept');
  F.At(4, 24, 4, 35);
  F.AddNumber('Msgs Kept:', UR^.MsgsKept, 2, 0, 65535, 'Messages kept in the area');
  F.At(4, 45, 4, 60);
  F.AddNumber('Received Days:', UR^.RcvdDays, 2, 0, 65535, 'Days received messages are kept');
  F.At(5, 3, 5, 13);
  F.AddNumber('Read Sec:', UR^.ReadSec.Level, 2, 0, 65535, 'Security level to read');
  F.OnF2(EditSecurity, @UR^.ReadSec, 'Read Security');
  F.At(5, 24, 5, 35);
  F.AddNumber('Write Sec:', UR^.WriteSec.Level, 2, 0, 65535, 'Security level to write');
  F.OnF2(EditSecurity, @UR^.WriteSec, 'Write Security');
  F.At(5, 45, 5, 56);
  F.AddNumber('Sysop Sec:', UR^.SysopSec.Level, 2, 0, 65535, 'Security level of a sysop in the area');
  F.OnF2(EditSecurity, @UR^.SysopSec, 'Sysop Security');
  F.At(6, 3, 6, 11);
  F.ReadOnly;
  F.Show(55);
  F.AddString('Origin:', UR^.Origin, 55, 'Origin line used in this area');
  F.OnF2(PickOrig, Nil, '');
  F.At(7, 3, 7, 9);
  F.AddString('Area:', UR^.AreaTag, 40, 'Echomail area tag');
  F.At(7, 52, 7, 63);
  F.AddString('File Id:', UR^.FileId, 13, 'Base file name (no extension for Squish, JAM, Synchronet) or directory (*.Msg)');
  F.At(8, 3, 8, 9);
  F.ReadOnly;
  F.Show(60);
  F.AddString('Path:', UR^.MsgPath, 70, 'Directory of the message base');
  F.OnF2(PickPath, Nil, '');
  F.At(9, 3, 9, 8);
  F.ReadOnly;
  F.AddString('Hub:', UR^.Hub, 25, 'Echomail hub system');
  F.OnF2(PickHub, Nil, '');
  F.At(9, 50, 9, 58);
  F.AddString('Select:', UR^.Select, 4, 'Key that selects the area');
  F.At(11, 3, 0, 0);
  F.AddAction('Net Status...', PickNetStatus, Nil, '', 'Networks the area belongs to');
  F.At(11, 20, 0, 0);
  F.AddAction('Options...', PickOptions, Nil, '', 'Area options');
  F.At(11, 35, 0, 0);
  F.AddAction('Echo To...', PickEchoTo, Nil, '', 'Systems the area is sent to');
  F.At(11, 50, 0, 0);
  F.AddAction('Fido Options...', PickFidoOptions, Nil, '', 'Fido options');
  If F.Execute Then
    Begin
    Config^.SetMsgName(MsgNum, UR^.Name);
    Config^.SetMsgShortName(MsgNum, UR^.ShortName);
    Config^.SetMsgSelect(MsgNum, UR^.Select);
    Config^.SetEchoAreaTag(MsgNum, UR^.AreaTag);
    Config^.SetMsgReadSecurity(MsgNum, UR^.ReadSec);
    Config^.SetMsgWriteSecurity(MsgNum, UR^.WriteSec);
    Config^.SetMsgSysopSecurity(MsgNum, UR^.SysopSec);
    Config^.SetMsgDays(MsgNum, UR^.DaysKept);
    Config^.SetMsgsKept(MsgNum, UR^.MsgsKept);
    Config^.SetMsgRcvdDays(MsgNum, UR^.RcvdDays);
    Config^.SetMsgFileId(MsgNum, UR^.FileId);
    Case UR^.TypeIdx Of
      0: Config^.SetMsgType(MsgNum, Normal);
      1: Config^.SetMsgType(MsgNum, NetMail);
      2: Config^.SetMsgType(MsgNum, EchoMail);
      End;
    If UR^.FormatIdx < 6 Then
      Config^.SetMsgBaseType(MsgNum, FormatChars[UR^.FormatIdx + 1]);
    BT := Config^.GetMsgBaseType(MsgNum);
    Msg := Nil;
    Case BT Of
      'S': Msg := New(SqMsgPtr, Init);
      'M': Msg := New(MerlinMsgPtr, Init);
      'Y': Msg := New(SynMsgPtr, Init);
      End;
    If Msg <> Nil Then
      Begin
      Msg^.SetMsgPath(Copy(Config^.GetMsgAreaId(MsgNum), 2, 128));
      If Not Msg^.MsgBaseExists Then
        If MessageBox('The message base does not exist yet. Create it?',
             Nil, mfConfirmation + mfYesButton + mfNoButton) = cmYes Then
          If Msg^.CreateMsgBase(UR^.MsgsKept, UR^.DaysKept) <> 0 Then
            MessageBox('Unable to create the message base', Nil, mfError + mfOKButton);
      Dispose(Msg, Done);
      End;
    End;
  Dispose(UR);
  End;


End.
