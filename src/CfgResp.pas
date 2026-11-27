{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgResp;   {Converted from CFGRESP for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgResp;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;


type UserRecord = record
      b300                 : string[40];
      b1200                : string[40];
      b2400                : string[40];
      b4800                : string[40];
      b7200                : string[40];
      b9600                : string[40];
      b12000               : string[40];
      b14400               : string[40];
      b19200               : string[40];
      b38400               : string[40];
      Response             : string[40];
      RingStr              : string[40];
    end;

Var
  UR: ^UserRecord;

Procedure DoCfgResp;
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.b300 := Config^.GetModemResp(2);
  UR^.b1200 := Config^.GetModemResp(3);
  UR^.b2400 := Config^.GetModemResp(4);
  UR^.b4800 := Config^.GetModemResp(5);
  UR^.b7200 := Config^.GetModemResp(6);
  UR^.b9600 := Config^.GetModemResp(7);
  UR^.b12000 := Config^.GetModemResp(8);
  UR^.b14400 := Config^.GetModemResp(9);
  UR^.b19200 := Config^.GetModemResp(10);
  UR^.b38400 := Config^.GetModemResp(11);
  UR^.Response := '';
  UR^.RingStr := '';
  F.Init('Modem Response Strings');
  F.Window(10, 6, 67, 20);
  F.At(2, 7, 2, 14);
  F.AddString('  300:', UR^.b300, 40, '  300');
  F.At(3, 7, 3, 14);
  F.AddString(' 1200:', UR^.b1200, 40, ' 1200');
  F.At(4, 7, 4, 14);
  F.AddString(' 2400:', UR^.b2400, 40, ' 2400');
  F.At(5, 7, 5, 14);
  F.AddString(' 4800:', UR^.b4800, 40, ' 4800');
  F.At(6, 7, 6, 14);
  F.AddString(' 7200:', UR^.b7200, 40, ' 7200');
  F.At(7, 7, 7, 14);
  F.AddString(' 9600:', UR^.b9600, 40, ' 9600');
  F.At(8, 7, 8, 14);
  F.AddString('12000:', UR^.b12000, 40, '12000');
  F.At(9, 7, 9, 14);
  F.AddString('14400:', UR^.b14400, 40, '14400');
  F.At(10, 7, 10, 14);
  F.AddString('19200:', UR^.b19200, 40, '19200');
  F.At(11, 7, 11, 14);
  F.AddString('38400:', UR^.b38400, 40, '38400');
  F.At(13, 7, 13, 17);
  F.AddString('Response:', UR^.Response, 40, 'Response');
  F.At(14, 7, 14, 13);
  F.AddString('Ring:', UR^.RingStr, 40, 'Ring');
  If F.Execute Then
    Begin
    Config^.SetModemResp(2, UR^.b300);
    Config^.SetModemResp(3, UR^.b1200);
    Config^.SetModemResp(4, UR^.b2400);
    Config^.SetModemResp(5, UR^.b4800);
    Config^.SetModemResp(6, UR^.b7200);
    Config^.SetModemResp(7, UR^.b9600);
    Config^.SetModemResp(8, UR^.b12000);
    Config^.SetModemResp(9, UR^.b14400);
    Config^.SetModemResp(10, UR^.b19200);
    Config^.SetModemResp(11, UR^.b38400);
    UR^.Response := '';
    UR^.RingStr := '';
    End;
    Dispose(UR);
  End;


End.
