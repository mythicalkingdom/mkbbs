Unit CfgQwk;     {Configuration screens of the offline mail door (config.mko), converted from MKQMAIN, MKQDEF, MKQCONF, MKQPACK, MKQPROT, MKQSCRN, MKQUSER}

{$I MKB.Def}

{
     The settings are those of MKQwkG (QCfg, in config.mko); the conference settings are confs.mko and the user
     records users.mko in QCfg.UserPath.  The screens are CfgForm dialogs.  Not taken over from the DOS version:
     "Direct Write" (a PC video setting) and the DOS programs of the default packers and protocols (SetDefaults looks
     for zip, lha, arj ... and sz, rz ... in the PATH instead).
}

Interface

Procedure QwkSetDefaults;
Procedure QwkFixPaths;
Procedure EditQMain;
Procedure EditQDef;
Procedure PickBBSArea;
Procedure EditQUser;
Procedure PickProt;
Procedure PickPackers;
Procedure EditQScrns;


Implementation

Uses MKString, MKGlobT, MKCfgAbs, MKFile, MKMisc, MKQwkG, CfgForm, CfgList;


{ ---- the net status: bits for the letters A - Z }

Function NetStatStr(NetStat: LongInt): String;
  Var
    S: String;
    i: Word;

  Begin
  S := '';
  For i := 1 To 26 Do
    If (NetStat And (LongInt(1) Shl (i - 1))) <> 0 Then
      S := S + Chr(i + 64);
  NetStatStr := S;
  End;


Function NetStatVal(NetStat: String): LongInt;
  Var
    i: Word;
    NS: LongInt;

  Begin
  NS := 0;
  For i := 1 To Length(NetStat) Do
    If UpCase(NetStat[i]) In ['A'..'Z'] Then
      NS := NS Or (LongInt(1) Shl (Ord(UpCase(NetStat[i])) - 65));
  NetStatVal := NS;
  End;


Const
  NetChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  YNAsk = 'No|Yes|New|Ask Y|Ask N';
  ConfTypes = 'Off|Normal|Mine Only|Mine + All';


{ ---- defaults for a first config.mko: the programs of this machine }

Procedure SetPack(N: Word; Prog, PackArgs, UnProg, UnArgs: String);
  Var
    P, UP: String;

  Begin
  QCfg.Packers[N].PackActive := FindOnPath(Prog, P) And FindOnPath(UnProg, UP);
  If QCfg.Packers[N].PackActive Then
    Begin
    QCfg.Packers[N].PackCmd := Prog + ' ' + PackArgs;
    QCfg.Packers[N].UnPackCmd := UnProg + ' ' + UnArgs;
    End;
  End;


Procedure SetProt(N: Word; SendProg, SendArgs, RcvProg, RcvArgs: String);
  Var
    P, RP: String;

  Begin
  QCfg.Prots[N].ProtActive := FindOnPath(SendProg, P) And FindOnPath(RcvProg, RP);
  If QCfg.Prots[N].ProtActive Then
    Begin
    QCfg.Prots[N].SendCmd := SendProg + ' ' + SendArgs;
    QCfg.Prots[N].RcvCmd := RcvProg + ' ' + RcvArgs;
    End;
  End;


Procedure QwkSetDefaults;
  Begin
  FillChar(QCfg, SizeOf(QCfg), #0);
  SetPack(1, 'lha', 'aq', 'lha', 'xqf');
  SetPack(2, 'zip', '-q -j', 'unzip', '-o -q');
  SetPack(3, 'arc', 'a', 'arc', 'x');
  SetPack(4, 'zoo', 'a', 'zoo', 'x');
  SetPack(6, 'arj', 'a -e -y', 'arj', 'x -y');
  SetProt(1, 'sz', '-e %F', 'rz', '-e');
  SetProt(2, 'sb', '%F', 'rb', '');
  SetProt(3, 'sx', '-k %F', 'rx', '-k %F');
  SetProt(4, 'sx', '%F', 'rx', '%F');
  QCfg.BoardId := Upper(Copy(ExtractWord(Config^.GetBBSName, 1), 1, 8));
  If (QCfg.BoardId = 'THE') Or (QCfg.BoardId = 'A') Or (QCfg.BoardId = 'AN') Then
    QCfg.BoardId := Upper(Copy(ExtractWord(Config^.GetBBSName, 2), 1, 8));
  QCfg.BBSPhone := '999-999-9999';
  QCfg.Direct := True;
  QCfg.MaxMsgs := 2000;
  QCfg.MaxConfMsgs := 1000;
  QCfg.NewFiles := qatAskY;
  QCfg.Screens := qatAskY;
  QCfg.Bulletins := qatAskY;
  QCfg.SecCrash := 32000;
  QCfg.SecImd := 32000;
  QCfg.CostMyNet := 0;
  QCfg.CostNormal := 15;
  QCfg.CostZone := 100;
  QCfg.CostCrash := 50;
  QCfg.CostImd := 50;
  QCfg.UserPath := Config^.GetMsgPath(1);
  QCfg.ScreenPath := Config^.GetTxtPath(1);
  QCfg.ScrnHello := 'hello';
  QCfg.ScrnBye := 'goodbye';
  QCfg.ScrnNews := 'news';
  QCfg.NewScrn := 'newfiles';
  QCfg.DefMaxMsgs := 1000;
  QCfg.DefMaxConfMsgs := 400;
  QCfg.DefProtocol := 'Z';
  QCfg.DefPacker := 'Z';
  QCfg.DefAttr := quaAllYours + quaOwnMsgs + quaFlagRead + quaBulletin + quaScreens + quaNewFile + quaNewBull;
  QCfg.DefMailType := qmtQwk;
  End;


Procedure QwkFixPaths;
  {config.mko may have DOS paths (backslashes): they are slash paths with a slash at the end, as the door reads them}
  Begin
  If QCfg.TempPath <> '' Then
    QCfg.TempPath := FixPath(QCfg.TempPath, True);
  If QCfg.UserPath <> '' Then
    QCfg.UserPath := FixPath(QCfg.UserPath, True);
  If QCfg.ScreenPath <> '' Then
    QCfg.ScreenPath := FixPath(QCfg.ScreenPath, True);
  End;


{ ---- main configuration }

Procedure EditQMain;
  Type
    UserRecord = Record
      Redate, AllowTwit, AllowFreq: Boolean;
      End;

  Var
    UR: UserRecord;
    F: CfgFormObj;

  Begin
  UR.Redate := (QCfg.Attr And qaRedate) <> 0;
  UR.AllowTwit := (QCfg.Attr And qaAllowTwit) <> 0;
  UR.AllowFreq := (QCfg.Attr And qaAllowFreq) <> 0;
  F.Init('Main MKQwk Configuration');
  F.Window(5, 3, 74, 20);
  F.At(2, 2, 2, 10);
  F.AddString('BBS ID:', QCfg.BoardId, 8, 'The identifier of this BBS: the name of the packets (<id>.QWK and <id>.REP)');
  F.At(2, 20, 2, 31);
  F.AddString('BBS Phone:', QCfg.BBSPhone, 20, 'Phone number of the BBS (in the packet)');
  F.At(2, 53, 2, 64);
  F.AddNumber('Lock Baud:', QCfg.LockedBaud, 2, 0, 65535, 'Locked baud rate for %L in the protocol commands (0 = the speed of the caller)');
  F.At(4, 2, 4, 16);
  F.AddYesNo('Force Name:', QCfg.ForceName, 'Messages in a reply packet are From the name of the caller');
  F.At(4, 34, 4, 48);
  F.AddNumber('Bad Msg Area:', QCfg.BadMsgArea, 2, 0, 65535, 'Message area for replies that cannot go where they were meant (0 = refuse them)');
  F.At(4, 55, 4, 68);
  F.AddYesNo('ReDate Msgs:', UR.Redate, 'Messages of a reply packet get the date of the upload');
  F.At(6, 2, 6, 12);
  F.AddNumber('Max Msgs:', QCfg.MaxMsgs, 2, 0, 65535, 'Most messages in a packet');
  F.At(6, 19, 6, 34);
  F.AddNumber('Max Conf Msgs:', QCfg.MaxConfMsgs, 2, 0, 65535, 'Most messages of one conference in a packet');
  F.At(6, 41, 6, 53);
  F.AddYesNo('Allow Twit:', UR.AllowTwit, 'Callers may have a twit list (names whose messages are left out)');
  F.At(6, 56, 6, 68);
  F.AddYesNo('Allow Freq:', UR.AllowFreq, 'Callers may make file requests');
  F.At(8, 2, 8, 13);
  F.AddChoice('New Files:', QCfg.NewFiles, 1, 0, YNAsk, 'New file list in the packet');
  F.At(8, 20, 8, 29);
  F.AddChoice('Screens:', QCfg.Screens, 1, 0, YNAsk, 'Hello, news and goodbye screens in the packet');
  F.At(8, 36, 8, 47);
  F.AddChoice('Bulletins:', QCfg.Bulletins, 1, 0, YNAsk, 'Bulletins in the packet');
  F.At(10, 2, 10, 15);
  F.AddDir('Common Path:', QCfg.UserPath, 55, 'Directory of confs.mko and users.mko');
  F.At(11, 2, 11, 13);
  F.AddDir('Temp Path:', QCfg.TempPath, 55, 'Directory for the work directories of the callers (empty: the temp path of the BBS)');
  F.At(12, 2, 12, 15);
  F.AddDir('Screen Path:', QCfg.ScreenPath, 55, 'Directory of the hello, news, goodbye, new files and bulletin screens');
  F.At(13, 2, 13, 18);
  F.Show(55);
  F.AddString('Default Origin:', QCfg.OverrideOrig, 50, 'Origin line for messages of the callers (empty: the one of the area)');
  F.At(14, 2, 14, 18);
  F.AddNumber('Security Crash:', QCfg.SecCrash, 2, 0, 65535, 'Security level for crash netmail');
  F.At(14, 26, 14, 46);
  F.AddNumber('Security Immediate:', QCfg.SecImd, 2, 0, 65535, 'Security level for immediate netmail');
  F.At(16, 2, 16, 15);
  F.AddNumber('Cost My Net:', QCfg.CostMyNet, 2, 0, 65535, 'Cost of a netmail in my own net');
  F.At(16, 22, 16, 35);
  F.AddNumber('Cost Normal:', QCfg.CostNormal, 2, 0, 65535, 'Cost of a normal netmail');
  F.At(16, 42, 16, 53);
  F.AddNumber('Cost Zone:', QCfg.CostZone, 2, 0, 65535, 'Cost of a netmail to another zone');
  F.At(17, 2, 17, 14);
  F.AddNumber('Cost Crash:', QCfg.CostCrash, 2, 0, 65535, 'Cost of a crash netmail');
  F.At(17, 22, 17, 38);
  F.AddNumber('Cost Immediate:', QCfg.CostImd, 2, 0, 65535, 'Cost of an immediate netmail');
  If F.Execute Then
    Begin
    UpdateWordFlag(QCfg.Attr, qaRedate, UR.Redate);
    UpdateWordFlag(QCfg.Attr, qaAllowTwit, UR.AllowTwit);
    UpdateWordFlag(QCfg.Attr, qaAllowFreq, UR.AllowFreq);
    End;
  End;


{ ---- the conferences of a user (and the defaults): a number (message area) and what the caller wants of it }

Var
  ListConfs: ^UserConfArray;


Function ConfTypeStr(T: Byte): String;
  Begin
  Case T Of
    0: ConfTypeStr := 'Off';
    1: ConfTypeStr := 'Normal';
    2: ConfTypeStr := 'Mine Only';
    3: ConfTypeStr := 'Mine + All';
    Else ConfTypeStr := '?';
    End;
  End;


Function UConfStr(Item: Word): String;
  Begin
  UConfStr := PadLeft(Long2Str(Item), ' ', 3) + ' ConfNum: ' + PadLeft(Long2Str(ListConfs^[Item].Area), ' ', 5) +
    '  Type: ' + ConfTypeStr(ListConfs^[Item].Typ);
  End;


Procedure UConfEdit(Item: Word);
  Var
    F: CfgFormObj;

  Begin
  F.Init('Conference ' + Long2Str(Item));
  F.Window(10, 6, 62, 12);
  F.At(2, 3, 2, 15);
  F.AddNumber('ConfNum:', ListConfs^[Item].Area, 2, 0, 65535, 'The message area of this conference (0 = none)');
  F.At(3, 3, 3, 15);
  F.AddChoice('Type:', ListConfs^[Item].Typ, 1, 0, ConfTypes, 'Off, normal, only mail to the caller, or mail to the caller and to All');
  If F.Execute Then;
  End;


Procedure EditConfList(Var Confs: UserConfArray; Title: String);
  Begin
  ListConfs := @Confs;
  RunList(Title, QwkUserAreas, 30, UConfStr, UConfEdit);
  End;


Procedure ConfAction(Data: Pointer; Title: String);
  Begin
  EditConfList(UserConfArray(Data^), Title);
  End;


{ ---- default user settings }

Procedure EditQDef;
  Type
    UserRecord = Record
      NetStat: String[20];
      AllYours, NoMsg, AskPkt, NoUL, OwnMsg, FlagRead, Bull, BullNew, Screens, NewFile, NoFreq: Boolean;
      End;

  Var
    UR: UserRecord;
    F: CfgFormObj;

  Begin
  UR.NetStat := NetStatStr(QCfg.DefNetStat);
  UR.AllYours := (QCfg.DefAttr And quaAllYours) <> 0;
  UR.NoMsg := (QCfg.DefAttr And quaNoMsg) <> 0;
  UR.AskPkt := (QCfg.DefAttr And quaAskPkt) <> 0;
  UR.NoUL := (QCfg.DefAttr And quaNoUL) <> 0;
  UR.OwnMsg := (QCfg.DefAttr And quaOwnMsgs) <> 0;
  UR.FlagRead := (QCfg.DefAttr And quaFlagRead) <> 0;
  UR.Bull := (QCfg.DefAttr And quaBulletin) <> 0;
  UR.BullNew := (QCfg.DefAttr And quaNewBull) <> 0;
  UR.Screens := (QCfg.DefAttr And quaScreens) <> 0;
  UR.NewFile := (QCfg.DefAttr And quaNewFile) <> 0;
  UR.NoFreq := (QCfg.DefAttr And quaNoFreq) <> 0;
  F.Init('MKQwk User Defaults');
  F.Window(5, 3, 74, 16);
  F.At(2, 3, 2, 13);
  F.AddChar('Protocol:', QCfg.DefProtocol, 'Key of the default protocol');
  F.At(2, 15, 2, 23);
  F.AddChar('Packer:', QCfg.DefPacker, 'Key of the default packer');
  F.At(2, 25, 2, 36);
  F.AddChoice('Mail Type:', QCfg.DefMailType, 1, 0, 'ASK|TXT|QWK|XRS|BWV|PKT', 'Packet format (ASK = the caller chooses)');
  F.At(2, 40, 2, 50);
  F.Filter(NetChars);
  F.AddString('Networks:', UR.NetStat, 20, 'Net status letters A - Z: private messages of these nets are in the packet');
  F.At(4, 3, 4, 17);
  F.AddNumber('Max Msgs Pkt:', QCfg.DefMaxMsgs, 2, 0, 65535, 'Most messages in a packet');
  F.At(4, 23, 4, 37);
  F.AddNumber('Max Per Conf:', QCfg.DefMaxConfMsgs, 2, 0, 65535, 'Most messages of one conference');
  F.At(6, 3, 6, 24);
  F.AddYesNo('Your Mail All Areas:', UR.AllYours, 'Look in all areas for mail to the caller');
  F.At(6, 28, 6, 46);
  F.AddYesNo('Send No Msg Pkts:', UR.NoMsg, 'Make a packet even when it has no messages');
  F.At(6, 49, 6, 61);
  F.AddYesNo('Ask Packet:', UR.AskPkt, 'Ask before sending the packet');
  F.At(8, 3, 8, 10);
  F.AddYesNo('No UL:', UR.NoUL, 'The caller may not upload replies');
  F.At(8, 13, 8, 23);
  F.AddYesNo('Own Msgs:', UR.OwnMsg, 'The caller gets his own messages');
  F.At(8, 26, 8, 40);
  F.AddYesNo('Flag as Read:', UR.FlagRead, 'Messages in the packet are marked as read');
  F.At(8, 43, 8, 54);
  F.AddYesNo('Bulletins:', UR.Bull, 'Bulletins in the packet');
  F.At(8, 57, 8, 67);
  F.AddYesNo('New Only:', UR.BullNew, 'Only new bulletins');
  F.At(10, 3, 10, 12);
  F.AddYesNo('Screens:', UR.Screens, 'Screens in the packet');
  F.At(10, 15, 10, 30);
  F.AddYesNo('New File List:', UR.NewFile, 'New file list in the packet');
  F.At(10, 34, 10, 52);
  F.AddYesNo('No File Requests:', UR.NoFreq, 'No file requests');
  F.At(12, 3, 12, 3);
  F.AddAction('Conferences...', ConfAction, @QCfg.DefUserConfs, 'Default conferences', 'The conferences new callers start with');
  If F.Execute Then
    Begin
    QCfg.DefNetStat := NetStatVal(UR.NetStat);
    UpdateWordFlag(QCfg.DefAttr, quaAllYours, UR.AllYours);
    UpdateWordFlag(QCfg.DefAttr, quaNoMsg, UR.NoMsg);
    UpdateWordFlag(QCfg.DefAttr, quaAskPkt, UR.AskPkt);
    UpdateWordFlag(QCfg.DefAttr, quaNoUL, UR.NoUL);
    UpdateWordFlag(QCfg.DefAttr, quaOwnMsgs, UR.OwnMsg);
    UpdateWordFlag(QCfg.DefAttr, quaFlagRead, UR.FlagRead);
    UpdateWordFlag(QCfg.DefAttr, quaBulletin, UR.Bull);
    UpdateWordFlag(QCfg.DefAttr, quaScreens, UR.Screens);
    UpdateWordFlag(QCfg.DefAttr, quaNewFile, UR.NewFile);
    UpdateWordFlag(QCfg.DefAttr, quaNewBull, UR.BullNew);
    UpdateWordFlag(QCfg.DefAttr, quaNoFreq, UR.NoFreq);
    End;
  End;


{ ---- conference settings: confs.mko, one record per message area }

Var
  ConfFile: File Of ConfCfg;
  NumConfRecs: LongInt;


Function ConfStr(Item: Word): String;
  Begin
  ConfStr := PadRight(Long2Str(Item), ' ', 4) + Copy(Config^.GetMsgName(Item), 1, 40);
  End;


Function ConfNotDefault(Var C: ConfCfg): Boolean;
  Begin
  ConfNotDefault := (Length(C.ShortName) > 0) Or (Length(C.MsgAreaId) > 0) Or (C.Addr.Zone <> 0) Or (C.Addr.Net <> 0) Or
    (C.Addr.Node <> 0) Or (C.Addr.Point <> 0) Or (C.Avail <> 0) Or (C.NetType <> 0) Or (C.Attr <> 0) Or (C.MsgType <> 0);
  End;


Procedure ConfEdit(CN: Word);
  Type
    UserRecord = Record
      ShortName: String[12];
      MsgType: Byte;
      MsgAreaId: String[60];
      AddrZone, AddrNet, AddrNode, AddrPoint: Word;
      Avail: Byte;
      AllowHi, AllowAnsi, RemvTear, StripTag, NoReply, TagOrig: Boolean;
      NetStat: String[26];
      End;

  Var
    UR: UserRecord;
    CC, Blank: ConfCfg;
    F: CfgFormObj;
    i: LongInt;

  Begin
  FillChar(CC, SizeOf(CC), 0);
  FillChar(Blank, SizeOf(Blank), 0);
  If CN <= NumConfRecs Then
    Begin
    Seek(ConfFile, CN - 1);
    Read(ConfFile, CC);
    If IoResult <> 0 Then
      FillChar(CC, SizeOf(CC), 0);
    End;
  UR.ShortName := CC.ShortName;
  UR.MsgType := CC.MsgType;
  UR.MsgAreaId := CC.MsgAreaId;
  UR.AddrZone := CC.Addr.Zone;
  UR.AddrNet := CC.Addr.Net;
  UR.AddrNode := CC.Addr.Node;
  UR.AddrPoint := CC.Addr.Point;
  UR.Avail := CC.Avail;
  UR.AllowHi := (CC.Attr And qcaAllowHi) <> 0;
  UR.AllowAnsi := (CC.Attr And qcaAllowAnsi) <> 0;
  UR.RemvTear := (CC.Attr And qcaRemvTear) <> 0;
  UR.StripTag := (CC.Attr And qcaStripTag) <> 0;
  UR.NoReply := (CC.Attr And qcaNoReply) <> 0;
  UR.TagOrig := (CC.Attr And qcaTagOrig) <> 0;
  UR.NetStat := NetStatStr(CC.NetType);
  F.Init('MKQwk Conference Setting');
  F.Window(5, 3, 73, 17);
  F.At(2, 3, 2, 15);
  F.AddString('Short Name:', UR.ShortName, 12, 'Short name of the conference in the packet (optional)');
  F.At(2, 30, 2, 40);
  F.AddChoice('Msg Type:', UR.MsgType, 1, 0, 'Normal|Echo|NetMail', 'Overrides the type of the area');
  F.At(4, 3, 4, 16);
  F.Show(60);
  F.AddString('Msg Area Id:', UR.MsgAreaId, 50, 'Overrides the area id string (format letter and path)');
  F.At(6, 3, 6, 21);
  F.AddNumber('Address Override:', UR.AddrZone, 2, 0, 65535, 'Zone of the address of the area');
  F.At(6, 27, 6, 29);
  F.AddNumber(':', UR.AddrNet, 2, 0, 65535, 'Net');
  F.At(6, 35, 6, 37);
  F.AddNumber('/', UR.AddrNode, 2, 0, 65535, 'Node');
  F.At(6, 43, 6, 45);
  F.AddNumber('.', UR.AddrPoint, 2, 0, 65535, 'Point');
  F.At(8, 3, 8, 14);
  F.AddChoice('Available:', UR.Avail, 1, 0, 'Normal|Force|Not Avail', 'Normal = the caller chooses, Force = always in the packet, Not Avail = never');
  F.At(8, 25, 8, 45);
  F.AddYesNo('Allow Hi Bit Chars:', UR.AllowHi, 'Characters above 127 are left in');
  F.At(8, 48, 8, 60);
  F.AddYesNo('Allow Ansi:', UR.AllowAnsi, 'Escape characters are left in');
  F.At(9, 3, 9, 23);
  F.AddYesNo('Remv Tearline Text:', UR.RemvTear, 'Remove the text of the tear line');
  F.At(9, 25, 9, 40);
  F.AddYesNo('Strip Tagline:', UR.StripTag, 'Remove tag lines');
  F.At(9, 42, 9, 53);
  F.AddYesNo('Read Only:', UR.NoReply, 'No replies in this conference');
  F.At(9, 55, 9, 68);
  F.AddYesNo('Tag To Orig:', UR.TagOrig, 'The tag line becomes the origin line');
  F.At(11, 3, 11, 15);
  F.Filter(NetChars);
  F.AddString('Net Status:', UR.NetStat, 26, 'Net status letters A - Z that may read private messages in this conference');
  F.At(13, 3, 13, 3);
  F.AddText(Long2Str(CN) + ' - ' + Config^.GetMsgName(CN));
  If F.Execute Then
    Begin
    CC.ShortName := UR.ShortName;
    CC.MsgType := UR.MsgType;
    CC.MsgAreaId := UR.MsgAreaId;
    CC.Addr.Zone := UR.AddrZone;
    CC.Addr.Net := UR.AddrNet;
    CC.Addr.Node := UR.AddrNode;
    CC.Addr.Point := UR.AddrPoint;
    CC.Avail := UR.Avail;
    UpdateWordFlag(CC.Attr, qcaAllowHi, UR.AllowHi);
    UpdateWordFlag(CC.Attr, qcaAllowAnsi, UR.AllowAnsi);
    UpdateWordFlag(CC.Attr, qcaRemvTear, UR.RemvTear);
    UpdateWordFlag(CC.Attr, qcaStripTag, UR.StripTag);
    UpdateWordFlag(CC.Attr, qcaNoReply, UR.NoReply);
    UpdateWordFlag(CC.Attr, qcaTagOrig, UR.TagOrig);
    CC.NetType := NetStatVal(UR.NetStat);
    If (CN <= NumConfRecs) Or ConfNotDefault(CC) Then
      Begin
      If CN > NumConfRecs Then
        Begin
        For i := NumConfRecs + 1 To CN - 1 Do
          Begin
          Seek(ConfFile, i - 1);
          Write(ConfFile, Blank);
          End;
        NumConfRecs := CN;
        End;
      Seek(ConfFile, CN - 1);
      Write(ConfFile, CC);
      End;
    End;
  End;


Procedure PickBBSArea;
  Var
    Name: String;

  Begin
  Name := WithBackSlash(QCfg.UserPath) + 'confs.mko';
  Assign(ConfFile, Name);
  FileMode := 2;
  Reset(ConfFile);
  If IoResult <> 0 Then
    Begin
    ReWrite(ConfFile);
    If IoResult <> 0 Then
      Begin
      ShowText('Conference Settings', 'Unable to open ' + Name);
      Exit;
      End;
    End;
  NumConfRecs := FileSize(ConfFile);
  RunList('Message Areas', Config^.GetMaxMsgAreas, 44, ConfStr, ConfEdit);
  Close(ConfFile);
  If IoResult <> 0 Then;
  End;


{ ---- protocols and packers }

Function ProtName(N: Word): String;
  Begin
  Case N Of
    1: ProtName := 'Zmodem';
    2: ProtName := 'Ymodem';
    3: ProtName := '1k-Xmodem';
    4: ProtName := 'Xmodem';
    5: ProtName := 'YmodemG';
    6: ProtName := 'HS-Link';
    Else ProtName := 'Protocol ' + Long2Str(N);
    End;
  End;


Function ProtStr(Item: Word): String;
  Begin
  If QCfg.Prots[Item].ProtActive Then
    ProtStr := ' * ' + ProtName(Item)
  Else
    ProtStr := '   ' + ProtName(Item);
  End;


Procedure ProtEdit(PN: Word);
  Var
    F: CfgFormObj;

  Begin
  F.Init('Protocol Setup');
  F.Window(5, 5, 73, 18);
  F.At(2, 4, 2, 4);
  F.AddText('Protocol ' + Long2Str(PN) + ' - ' + ProtName(PN));
  F.At(2, 46, 2, 54);
  F.AddYesNo('Active:', QCfg.Prots[PN].ProtActive, 'The caller may choose this protocol');
  F.At(5, 4, 7, 4);
  F.Show(70);
  F.AddString('Protocol Send Command:', QCfg.Prots[PN].SendCmd, 70,
    'Program and arguments: %F file, %B baud, %L locked baud, %P port, %N user name. Not run by a shell');
  F.At(10, 4, 12, 4);
  F.Show(70);
  F.AddString('Protocol Receive Command:', QCfg.Prots[PN].RcvCmd, 70, 'The same for receiving');
  If F.Execute Then;
  End;


Procedure PickProt;
  Begin
  RunList('Protocols', 10, 20, ProtStr, ProtEdit);
  End;


Function PackName(N: Word): String;
  Begin
  Case N Of
    1: PackName := 'LZH';
    2: PackName := 'ZIP';
    3: PackName := 'ARC';
    4: PackName := 'ZOO';
    5: PackName := 'DWC';
    6: PackName := 'ARJ';
    7: PackName := 'HYP';
    Else PackName := 'Extra';
    End;
  End;


Function PackStr(Item: Word): String;
  Begin
  If QCfg.Packers[Item].PackActive Then
    PackStr := '   *  ' + PackName(Item)
  Else
    PackStr := '      ' + PackName(Item);
  End;


Procedure PackEdit(PN: Word);
  Var
    F: CfgFormObj;

  Begin
  F.Init('Archive Packer Setup');
  F.Window(5, 5, 73, 18);
  F.At(2, 4, 2, 4);
  F.AddText(PackName(PN) + ' Archive Packer');
  F.At(2, 46, 2, 54);
  F.AddYesNo('Active:', QCfg.Packers[PN].PackActive, 'The caller may choose this packer');
  F.At(5, 4, 7, 4);
  F.Show(70);
  F.AddString('Archive Pack Command:', QCfg.Packers[PN].PackCmd, 70, 'Program and arguments; the archive name and *.* follow. Not run by a shell');
  F.At(10, 4, 12, 4);
  F.Show(70);
  F.AddString('Archive Unpack Command:', QCfg.Packers[PN].UnPackCmd, 70, 'Program and arguments; the archive name follows');
  If F.Execute Then;
  End;


Procedure PickPackers;
  Begin
  RunList('Packers', 10, 20, PackStr, PackEdit);
  End;


{ ---- screens and bulletins }

Procedure EditQScrns;
  Var
    F: CfgFormObj;
    i: Word;

  Begin
  F.Init('MKQwk Screens and Bulletins');
  F.Window(5, 4, 74, 20);
  F.At(2, 3, 2, 15);
  F.AddString('Hello Scrn:', QCfg.ScrnHello, 8, 'Screen shown first (name without extension)');
  F.At(2, 25, 2, 38);
  F.AddString('News Screen:', QCfg.ScrnNews, 8, 'News screen');
  F.At(2, 48, 2, 60);
  F.AddString('Bye Screen:', QCfg.ScrnBye, 8, 'Goodbye screen');
  F.At(4, 3, 4, 25);
  F.AddString('New File List Screen:', QCfg.NewScrn, 8, 'Heading of the new file list');
  For i := 1 To 10 Do
    Begin
    F.At(5 + i, 3, 5 + i, 23);
    F.AddString('Bulletin ' + Long2Str(i) + ' Screen:', QCfg.BullNames[i], 8, 'Bulletin screen ' + Long2Str(i));
    End;
  If F.Execute Then;
  End;


{ ---- user records: users.mko }

Type
  QUserRecord = Record
    Name: String[35];
    Prot, Packer: Char;
    MailType: Byte;
    NetStat: String[20];
    MaxMsg, MaxConf: Word;
    LastDate: String[8];
    AllYours, NoMsg, AskPkt, NoUL, OwnMsg, FlagRead, Bull, BullNew, Screens, NewFile, NoFreq, Deleted: Boolean;
    Twit1, Twit2, Twit3, Twit4, Twit5: String[35];
    UserConfs: UserConfArray;
    End;

Var
  UserFile: File Of QwkUserRec;
  NumUserRecs: LongInt;


Function UserStr(Item: Word): String;
  Var
    QU: QwkUserRec;

  Begin
  If Item > NumUserRecs Then
    UserStr := '<add a user>'
  Else
    Begin
    Seek(UserFile, Item - 1);
    Read(UserFile, QU);
    If IoResult <> 0 Then
      QU.Name := '?';
    If QU.LastUsed = -1 Then
      UserStr := PadRight(Long2Str(Item), ' ', 5) + PadRight(QU.Name, ' ', 36) + 'deleted'
    Else
      UserStr := PadRight(Long2Str(Item), ' ', 5) + QU.Name;
    End;
  End;


Procedure UserEdit(Item: Word);
  Var
    QU: QwkUserRec;
    UR: ^QUserRecord;
    F: CfgFormObj;
    Add: Boolean;

  Begin
  Add := Item > NumUserRecs;
  New(UR);
  FillChar(UR^, SizeOf(UR^), 0);
  If Add Then
    Begin
    FillChar(QU, SizeOf(QU), 0);
    QU.UserConfs := QCfg.DefUserConfs;
    QU.NetStat := QCfg.DefNetStat;
    QU.MaxMsgs := QCfg.DefMaxMsgs;
    QU.MaxConfMsgs := QCfg.DefMaxConfMsgs;
    QU.Protocol := QCfg.DefProtocol;
    QU.Packer := QCfg.DefPacker;
    QU.Attr := QCfg.DefAttr;
    QU.MailType := QCfg.DefMailType;
    End
  Else
    Begin
    Seek(UserFile, Item - 1);
    Read(UserFile, QU);
    End;
  UR^.Name := QU.Name;
  UR^.NetStat := NetStatStr(QU.NetStat);
  UR^.UserConfs := QU.UserConfs;
  UR^.MaxMsg := QU.MaxMsgs;
  UR^.MaxConf := QU.MaxConfMsgs;
  UR^.Prot := QU.Protocol;
  UR^.Packer := QU.Packer;
  UR^.AllYours := (QU.Attr And quaAllYours) <> 0;
  UR^.NoMsg := (QU.Attr And quaNoMsg) <> 0;
  UR^.AskPkt := (QU.Attr And quaAskPkt) <> 0;
  UR^.NoUL := (QU.Attr And quaNoUL) <> 0;
  UR^.OwnMsg := (QU.Attr And quaOwnMsgs) <> 0;
  UR^.FlagRead := (QU.Attr And quaFlagRead) <> 0;
  UR^.Bull := (QU.Attr And quaBulletin) <> 0;
  UR^.Screens := (QU.Attr And quaScreens) <> 0;
  UR^.NewFile := (QU.Attr And quaNewFile) <> 0;
  UR^.BullNew := (QU.Attr And quaNewBull) <> 0;
  UR^.NoFreq := (QU.Attr And quaNoFreq) <> 0;
  UR^.MailType := QU.MailType;
  UR^.Twit1 := QU.Twits[1];
  UR^.Twit2 := QU.Twits[2];
  UR^.Twit3 := QU.Twits[3];
  UR^.Twit4 := QU.Twits[4];
  UR^.Twit5 := QU.Twits[5];
  UR^.Deleted := QU.LastUsed = -1;
  If QU.LastUsed <= 0 Then
    UR^.LastDate := 'Never'
  Else
    UR^.LastDate := DateStr(QU.LastUsed);
  F.Init('MKQwk User Editor');
  F.Window(5, 3, 74, 21);
  F.At(2, 3, 2, 9);
  F.AddString('Name:', UR^.Name, 35, 'Name of the user (Proper case)');
  F.At(4, 3, 4, 13);
  F.AddChar('Protocol:', UR^.Prot, 'Key of the protocol');
  F.At(4, 15, 4, 23);
  F.AddChar('Packer:', UR^.Packer, 'Key of the packer');
  F.At(4, 25, 4, 36);
  F.AddChoice('Mail Type:', UR^.MailType, 1, 1, 'TXT|QWK|XRS|BWV|PKT', 'Packet format');
  F.At(4, 40, 4, 50);
  F.Filter(NetChars);
  F.AddString('Networks:', UR^.NetStat, 20, 'Net status letters A - Z');
  F.At(6, 3, 6, 17);
  F.AddNumber('Max Msgs Pkt:', UR^.MaxMsg, 2, 0, 65535, 'Most messages in a packet');
  F.At(6, 23, 6, 37);
  F.AddNumber('Max Per Conf:', UR^.MaxConf, 2, 0, 65535, 'Most messages of one conference');
  F.At(6, 43, 6, 54);
  F.AddString('Last Used:', UR^.LastDate, 8, 'The last call');
  F.ReadOnly;
  F.At(8, 3, 8, 24);
  F.AddYesNo('Your Mail All Areas:', UR^.AllYours, 'Look in all areas for mail to the user');
  F.At(8, 28, 8, 46);
  F.AddYesNo('Send No Msg Pkts:', UR^.NoMsg, 'Make a packet even when it has no messages');
  F.At(8, 49, 8, 61);
  F.AddYesNo('Ask Packet:', UR^.AskPkt, 'Ask before sending the packet');
  F.At(10, 3, 10, 10);
  F.AddYesNo('No UL:', UR^.NoUL, 'The user may not upload replies');
  F.At(10, 13, 10, 23);
  F.AddYesNo('Own Msgs:', UR^.OwnMsg, 'The user gets his own messages');
  F.At(10, 26, 10, 40);
  F.AddYesNo('Flag as Read:', UR^.FlagRead, 'Messages in the packet are marked as read');
  F.At(10, 43, 10, 54);
  F.AddYesNo('Bulletins:', UR^.Bull, 'Bulletins in the packet');
  F.At(10, 57, 10, 67);
  F.AddYesNo('New Only:', UR^.BullNew, 'Only new bulletins');
  F.At(12, 3, 12, 12);
  F.AddYesNo('Screens:', UR^.Screens, 'Screens in the packet');
  F.At(12, 15, 12, 30);
  F.AddYesNo('New File List:', UR^.NewFile, 'New file list in the packet');
  F.At(12, 34, 12, 52);
  F.AddYesNo('No File Requests:', UR^.NoFreq, 'No file requests');
  F.At(12, 56, 12, 66);
  F.AddYesNo('Deleted:', UR^.Deleted, 'The record is deleted (it is kept in the file)');
  F.At(14, 3, 14, 11);
  F.AddString('Twit 1:', UR^.Twit1, 35, 'Messages from this name are left out');
  F.At(15, 3, 15, 11);
  F.AddString('Twit 2:', UR^.Twit2, 35, 'Messages from this name are left out');
  F.At(16, 3, 16, 11);
  F.AddString('Twit 3:', UR^.Twit3, 35, 'Messages from this name are left out');
  F.At(17, 3, 17, 11);
  F.AddString('Twit 4:', UR^.Twit4, 35, 'Messages from this name are left out');
  F.At(18, 3, 18, 11);
  F.AddString('Twit 5:', UR^.Twit5, 35, 'Messages from this name are left out');
  F.At(19, 3, 19, 3);
  F.AddAction('Conferences...', ConfAction, @UR^.UserConfs, 'Conferences of ' + QU.Name, 'The conferences of the user');
  If F.Execute And ((Not Add) Or (UR^.Name <> '')) Then
    Begin
    QU.Name := UR^.Name;
    QU.NetStat := NetStatVal(UR^.NetStat);
    QU.UserConfs := UR^.UserConfs;
    QU.MaxMsgs := UR^.MaxMsg;
    QU.MaxConfMsgs := UR^.MaxConf;
    QU.Protocol := UR^.Prot;
    QU.Packer := UR^.Packer;
    UpdateWordFlag(QU.Attr, quaAllYours, UR^.AllYours);
    UpdateWordFlag(QU.Attr, quaNoMsg, UR^.NoMsg);
    UpdateWordFlag(QU.Attr, quaAskPkt, UR^.AskPkt);
    UpdateWordFlag(QU.Attr, quaNoUL, UR^.NoUL);
    UpdateWordFlag(QU.Attr, quaOwnMsgs, UR^.OwnMsg);
    UpdateWordFlag(QU.Attr, quaFlagRead, UR^.FlagRead);
    UpdateWordFlag(QU.Attr, quaBulletin, UR^.Bull);
    UpdateWordFlag(QU.Attr, quaScreens, UR^.Screens);
    UpdateWordFlag(QU.Attr, quaNewFile, UR^.NewFile);
    UpdateWordFlag(QU.Attr, quaNewBull, UR^.BullNew);
    UpdateWordFlag(QU.Attr, quaNoFreq, UR^.NoFreq);
    QU.MailType := UR^.MailType;
    QU.Twits[1] := UR^.Twit1;
    QU.Twits[2] := UR^.Twit2;
    QU.Twits[3] := UR^.Twit3;
    QU.Twits[4] := UR^.Twit4;
    QU.Twits[5] := UR^.Twit5;
    If UR^.Deleted Then
      QU.LastUsed := -1
    Else If QU.LastUsed = -1 Then
      QU.LastUsed := 0;
    If Add Then
      NumUserRecs := NumUserRecs + 1;
    Seek(UserFile, Item - 1);
    Write(UserFile, QU);
    End;
  Dispose(UR);
  End;


Procedure EditQUser;
  Var
    Name: String;
    Chosen: Word;

  Begin
  Name := WithBackSlash(QCfg.UserPath) + 'users.mko';
  Assign(UserFile, Name);
  FileMode := 2;
  Reset(UserFile);
  If IoResult <> 0 Then
    Begin
    ReWrite(UserFile);
    If IoResult <> 0 Then
      Begin
      ShowText('User Editor', 'Unable to open ' + Name);
      Exit;
      End;
    End;
  NumUserRecs := FileSize(UserFile);
  Chosen := 1;
  While RunPick('MKQwk Users', NumUserRecs + 1, 44, UserStr, Chosen) Do
    UserEdit(Chosen);
  Close(UserFile);
  If IoResult <> 0 Then;
  End;


End.
