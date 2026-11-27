{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgEl;   {Converted from CFGEL for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgEL;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;


type
  UserRecord =
    record
      LocEL                : Byte;
      b300                 : Byte;
      b1200                : Byte;
      b2400                : Byte;
      b4800                : Byte;
      b7200                : Byte;
      b9600                : Byte;
      b12000               : Byte;
      b14400               : Byte;
      b19200               : Byte;
      b38400               : Byte;
    end;

Var
  UR: ^UserRecord;

Procedure DoCfgEL;
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.LocEL := Config^.GetErrorLevel(1);
  UR^.B300 := Config^.GetErrorLevel(2);
  UR^.B1200 := Config^.GetErrorLevel(3);
  UR^.B2400 := Config^.GetErrorLevel(4);
  UR^.B4800 := Config^.GetErrorLevel(5);
  UR^.B7200 := Config^.GetErrorLevel(6);
  UR^.B9600 := Config^.GetErrorLevel(7);
  UR^.B12000 := Config^.GetErrorLevel(8);
  UR^.B14400 := Config^.GetErrorLevel(9);
  UR^.B19200 := Config^.GetErrorLevel(10);
  UR^.B38400 := Config^.GetErrorLevel(11);
  F.Init('ErrorLevels');
  F.Window(22, 8, 45, 20);
  F.At(2, 7, 2, 14);
  F.AddNumber('Local:', UR^.LocEL, 1, 0, 255, 'Local');
  F.At(3, 7, 3, 14);
  F.AddNumber('  300:', UR^.b300, 1, 0, 255, '  300');
  F.At(4, 7, 4, 14);
  F.AddNumber(' 1200:', UR^.b1200, 1, 0, 255, ' 1200');
  F.At(5, 7, 5, 14);
  F.AddNumber(' 2400:', UR^.b2400, 1, 0, 255, ' 2400');
  F.At(6, 7, 6, 14);
  F.AddNumber(' 4800:', UR^.b4800, 1, 0, 255, ' 4800');
  F.At(7, 7, 7, 14);
  F.AddNumber(' 7200:', UR^.b7200, 1, 0, 255, ' 7200');
  F.At(8, 7, 8, 14);
  F.AddNumber(' 9600:', UR^.b9600, 1, 0, 255, ' 9600');
  F.At(9, 7, 9, 14);
  F.AddNumber('12000:', UR^.b12000, 1, 0, 255, '12000');
  F.At(10, 7, 10, 14);
  F.AddNumber('14400:', UR^.b14400, 1, 0, 255, '14400');
  F.At(11, 7, 11, 14);
  F.AddNumber('19200:', UR^.b19200, 1, 0, 255, '19200');
  F.At(12, 7, 12, 14);
  F.AddNumber('38400:', UR^.b38400, 1, 0, 255, '38400');
  If F.Execute Then
    Begin
    Config^.SetErrorLevel(1, UR^.LocEL);
    Config^.SetErrorLevel(2, UR^.B300);
    Config^.SetErrorLevel(3, UR^.B1200);
    Config^.SetErrorLevel(4, UR^.B2400);
    Config^.SetErrorLevel(5, UR^.B4800);
    Config^.SetErrorLevel(6, UR^.B7200);
    Config^.SetErrorLevel(7, UR^.B9600);
    Config^.SetErrorLevel(8, UR^.B12000);
    Config^.SetErrorLevel(9, UR^.B14400);
    Config^.SetErrorLevel(10, UR^.B19200);
    Config^.SetErrorLevel(11, UR^.B38400);
    End;
    Dispose(UR);
  End;


End.
