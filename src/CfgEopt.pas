{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgEopt;   {Converted from CFGEOPT for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgEOpt;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;


Type UserRecord = Record
 InBound              : string[50];
 OutBound             : string[50];
 MaxPkt               : LongInt;
 End;

Var
  UR : ^UserRecord;

Procedure DoCfgEOpt;
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.InBound := Config^.GetEchoInPath;
  UR^.OutBound := Config^.GetEchoOutPath;
  UR^.MaxPkt := Config^.GetEchoMaxPkt;
  F.Init('EchoMail Options');
  F.Window(5, 9, 74, 15);
  F.At(2, 3, 2, 17);
  F.AddDir('InBound Path:', UR^.InBound, 50, 'InBound Path');
  F.At(4, 3, 4, 18);
  F.AddDir('OutBound Path:', UR^.OutBound, 50, 'OutBound Path');
  F.At(6, 3, 6, 28);
  F.AddNumber('Maximum *.PKT File Size:', UR^.MaxPkt, 4, 0, 999999, 'Maximum *.PKT File Size');
  If F.Execute Then
    Begin
    Config^.SetEchoInPath(UR^.InBound);
    Config^.SetEchoOutPath(UR^.OutBound);
    Config^.SetEchoMaxPkt(UR^.MaxPkt);
    End;
    Dispose(UR);
  End;


End.
