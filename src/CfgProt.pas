{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgProt;    {Transfer protocols: the internal ones (1 - 10) and the external ones with their command lines (11 - 20)}

{$I MKB.Def}

Interface

Procedure DoCfgProt;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgList, CfgForm;


Type
  UserRecord = Record
    Name: String[15];
    Key: Char;
    Avail: Boolean;
    Special: Boolean;
    CmdLine: String[80];
    End;


Function ItemStr(Item: Word): String;
  Var
    N: String;

  Begin
  N := Config^.GetProtName(Item);
  If N = '' Then
    N := '-';
  If Item <= 10 Then
    ItemStr := PadRight(Long2Str(Item), ' ', 3) + PadRight(N, ' ', 17) + 'internal'
  Else
    ItemStr := PadRight(Long2Str(Item), ' ', 3) + PadRight(N, ' ', 17) + 'external';
  End;


Procedure EditProt(PN: Word);
  Var
    UR: ^UserRecord;
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.Name := Config^.GetProtName(PN);
  UR^.Key := Config^.GetProtChar(PN);
  UR^.Avail := Config^.GetProtNormAvail(PN);
  UR^.Special := Config^.GetProtSpecAvail(PN);
  UR^.CmdLine := Config^.GetProtCmdLine(PN);
  If PN <= 10 Then
    F.Init('Internal protocol ' + Long2Str(PN))
  Else
    F.Init('External protocol ' + Long2Str(PN));
  F.Window(5, 5, 76, 13);
  F.At(2, 3, 2, 9);
  F.AddString('Name:', UR^.Name, 15, 'Name');
  F.At(2, 32, 2, 37);
  F.AddChar('Key:', UR^.Key, 'Key');
  F.At(3, 3, 3, 14);
  F.AddYesNo('Available:', UR^.Avail, 'Available for normal file transfers');
  F.At(3, 32, 3, 49);
  F.AddYesNo('Special files:', UR^.Special, 'Available for special files (offline mail packets)');
  If PN > 10 Then
    Begin
    F.At(5, 3, 5, 20);
    F.Show(80);
    F.AddString('Send | Receive:', UR^.CmdLine, 50,
      'Send command | receive command; %F file, %B baud, %L locked baud, %P port, %N user. Not run by a shell');
    End
  Else
    Begin
    F.At(5, 3, 5, 3);
    F.AddText('Internal protocol: built into mk (offline mail and file transfers).');
    End;
  If F.Execute Then
    Begin
    Config^.SetProtName(PN, UR^.Name);
    Config^.SetProtChar(PN, UR^.Key);
    Config^.SetProtNormAvail(PN, UR^.Avail);
    Config^.SetProtSpecAvail(PN, UR^.Special);
    If PN > 10 Then
      Config^.SetProtCmdLine(PN, UR^.CmdLine);
    End;
  Dispose(UR);
  End;


Procedure DoCfgProt;
  Begin
  RunList('Transfer Protocols', 20, 30, ItemStr, EditProt);
  End;


End.
