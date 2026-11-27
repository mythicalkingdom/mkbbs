{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgOffp;   {Offline mail parameters, converted from CFGOFFP}

{$I MKB.Def}

Interface

Procedure EditOffCfgP;

Implementation

Uses MKString, MKCfgAbs, CfgForm;

Type
  UserRecord = Record
    MaxMsg, MaxConf, CompRate, Safety, BadArea: Word;
    ReDate, Qwke, AllowNew, ForceNew, AllowScrn, ForceScrn, AllowBull, ForceBull,
      AllowFreq: Boolean;
    Bull1, Welcome, Bull2, News, Bull3, GoodBye, Bull4, Bull5, Bull6, Bull7,
      Bull8, Bull9, Bull10, NewHead: String[8];
    End;


Procedure EditOffCfgP;
  Var
    UR: ^UserRecord;
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.MaxMsg := Config^.GetOffMax;
  UR^.MaxConf := Config^.GetOffConfMax;
  UR^.CompRate := Config^.GetOffCompRate;
  UR^.Safety := Config^.GetOffSafetyMin;
  UR^.BadArea := Config^.GetBadMsgArea;
  UR^.ReDate := Config^.GetOffReDate;
  UR^.Qwke := Config^.GetOffQwke;
  UR^.AllowNew := Config^.GetOffAllowNew;
  UR^.ForceNew := Config^.GetOffForceNew;
  UR^.AllowScrn := Config^.GetOffAllowScrn;
  UR^.ForceScrn := Config^.GetOffForceScrn;
  UR^.AllowBull := Config^.GetOffAllowBull;
  UR^.ForceBull := Config^.GetOffForceBull;
  UR^.AllowFreq := Config^.GetOffAllowFreq;
  UR^.Bull1 := Config^.GetOffBulls(1);
  UR^.Welcome := Config^.GetOffScrns(1);
  UR^.Bull2 := Config^.GetOffBulls(2);
  UR^.News := Config^.GetOffScrns(2);
  UR^.Bull3 := Config^.GetOffBulls(3);
  UR^.GoodBye := Config^.GetOffScrns(3);
  UR^.Bull4 := Config^.GetOffBulls(4);
  UR^.Bull5 := Config^.GetOffBulls(5);
  UR^.Bull6 := Config^.GetOffBulls(6);
  UR^.Bull7 := Config^.GetOffBulls(7);
  UR^.Bull8 := Config^.GetOffBulls(8);
  UR^.Bull9 := Config^.GetOffBulls(9);
  UR^.Bull10 := Config^.GetOffBulls(10);
  UR^.NewHead := Config^.GetOffScrns(4);
  F.Init('Offline Mail Parameters');
  F.Window(3, 3, 75, 21);
  F.At(8, 24, 0, 0);
  F.AddText('-----   Screens  ------');
  F.At(2, 3, 2, 28);
  F.AddNumber('Maximum Msgs Per Packet:', UR^.MaxMsg, 2, 1, 4000, 'Maximum Msgs Per Packet');
  F.At(2, 38, 2, 61);
  F.AddNumber('Maximum Msgs Per Area:', UR^.MaxConf, 2, 1, 4000, 'Maximum Msgs Per Area');
  F.At(3, 3, 3, 29);
  F.AddNumber('Assumed Compression Rate:', UR^.CompRate, 2, 0, 100, 'Assumed Compression Rate');
  F.At(3, 38, 3, 68);
  F.AddNumber('Safety Time Buffer (Minutes):', UR^.Safety, 2, 0, 10, 'Safety Time Buffer (Minutes)');
  F.At(4, 3, 4, 25);
  F.AddYesNo('Allow New Files List:', UR^.AllowNew, 'Allow New Files List');
  F.At(4, 38, 4, 60);
  F.AddYesNo('Force New Files List:', UR^.ForceNew, 'Force New Files List');
  F.At(5, 3, 5, 22);
  F.AddYesNo('Allow BBS Screens:', UR^.AllowScrn, 'Allow BBS Screens');
  F.At(5, 38, 5, 57);
  F.AddYesNo('Force BBS Screens:', UR^.ForceScrn, 'Force BBS Screens');
  F.At(6, 3, 6, 20);
  F.AddYesNo('Allow Bulletins:', UR^.AllowBull, 'Allow Bulletins');
  F.At(6, 38, 6, 55);
  F.AddYesNo('Force Bulletins:', UR^.ForceBull, 'Force Bulletins');
  F.At(7, 3, 7, 24);
  F.AddYesNo('Allow File Requests:', UR^.AllowFreq, 'Allow File Requests');
  F.At(7, 38, 7, 67);
  F.AddYesNo('Redate Replies When Imported:', UR^.ReDate, 'Redate Replies When Imported');
  F.At(18, 38, 18, 63);
  F.AddYesNo('QWKE Long Names:', UR^.Qwke, 'Long names and subjects (QWKE) in QWK packets');
  F.At(19, 3, 19, 36);
  F.AddNumber('Area For Replies That Cannot Go:', UR^.BadArea, 3, 0, 500, 'Message area for uploaded replies to an unknown conference or one that may not be written (0 = refuse them)');
  F.At(9, 3, 9, 16);
  F.AddString('Bulletin  1:', UR^.Bull1, 8, 'Bulletin  1');
  F.At(9, 38, 9, 47);
  F.AddString('Welcome:', UR^.Welcome, 8, 'Welcome');
  F.At(12, 38, 12, 54);
  F.AddString('New Files Head:', UR^.NewHead, 8, 'Screen shown above the new files list in a packet (blank = none)');
  F.At(10, 3, 10, 16);
  F.AddString('Bulletin  2:', UR^.Bull2, 8, 'Bulletin  2');
  F.At(10, 38, 10, 44);
  F.AddString('News:', UR^.News, 8, 'News');
  F.At(11, 3, 11, 16);
  F.AddString('Bulletin  3:', UR^.Bull3, 8, 'Bulletin  3');
  F.At(11, 38, 11, 47);
  F.AddString('GoodBye:', UR^.GoodBye, 8, 'GoodBye');
  F.At(12, 3, 12, 16);
  F.AddString('Bulletin  4:', UR^.Bull4, 8, 'Bulletin  4');
  F.At(13, 3, 13, 16);
  F.AddString('Bulletin  5:', UR^.Bull5, 8, 'Bulletin  5');
  F.At(14, 3, 14, 16);
  F.AddString('Bulletin  6:', UR^.Bull6, 8, 'Bulletin  6');
  F.At(15, 3, 15, 16);
  F.AddString('Bulletin  7:', UR^.Bull7, 8, 'Bulletin  7');
  F.At(16, 3, 16, 16);
  F.AddString('Bulletin  8:', UR^.Bull8, 8, 'Bulletin  8');
  F.At(17, 3, 17, 16);
  F.AddString('Bulletin  9:', UR^.Bull9, 8, 'Bulletin  9');
  F.At(18, 3, 18, 16);
  F.AddString('Bulletin 10:', UR^.Bull10, 8, 'Bulletin 10');
  If F.Execute Then
    Begin
    Config^.SetOffMax(UR^.MaxMsg);
    Config^.SetOffConfMax(UR^.MaxConf);
    Config^.SetOffCompRate(UR^.CompRate);
    Config^.SetOffSafetyMin(UR^.Safety);
    Config^.SetBadMsgArea(UR^.BadArea);
    Config^.SetOffReDate(UR^.ReDate);
    Config^.SetOffQwke(UR^.Qwke);
    Config^.SetOffAllowNew(UR^.AllowNew);
    Config^.SetOffForceNew(UR^.ForceNew);
    Config^.SetOffAllowScrn(UR^.AllowScrn);
    Config^.SetOffForceScrn(UR^.ForceScrn);
    Config^.SetOffAllowBull(UR^.AllowBull);
    Config^.SetOffForceBull(UR^.ForceBull);
    Config^.SetOffAllowFreq(UR^.AllowFreq);
    Config^.SetOffBulls(1, UR^.Bull1);
    Config^.SetOffScrns(1, UR^.Welcome);
    Config^.SetOffBulls(2, UR^.Bull2);
    Config^.SetOffScrns(2, UR^.News);
    Config^.SetOffBulls(3, UR^.Bull3);
    Config^.SetOffScrns(3, UR^.GoodBye);
    Config^.SetOffBulls(4, UR^.Bull4);
    Config^.SetOffBulls(5, UR^.Bull5);
    Config^.SetOffBulls(6, UR^.Bull6);
    Config^.SetOffBulls(7, UR^.Bull7);
    Config^.SetOffBulls(8, UR^.Bull8);
    Config^.SetOffBulls(9, UR^.Bull9);
    Config^.SetOffBulls(10, UR^.Bull10);
    Config^.SetOffScrns(4, UR^.NewHead);
    End;
  Dispose(UR);
  End;


End.
