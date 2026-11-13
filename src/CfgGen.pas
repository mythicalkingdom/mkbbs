Unit CfgGen;   {Converted from CFGGEN for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgGen;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob, CfgColor;



Type UserRecord = Record
  SystemName: String[40];
  BbsLocation: String[40];
  BbsPhone: String[15];
  SysopName: String[35];
  BoardId: String[8];
  Color: Array[1..5] of Byte;
  DirectWrite: Boolean;
  SnowCheck: Boolean;
  MonoMode: Boolean;
  PrnName: String[20];
  End;

Var
  UR: ^UserRecord;
  i: Word;

Procedure DoCfgGen;
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.DirectWrite := Config^.GetDirectWrite;
  UR^.MonoMode := Config^.GetMonoMode;
  UR^.SnowCheck := Config^.GetSnowCheck;
  For i := 1 to 5 Do
    UR^.Color[i] := Config^.GetSystemColor(i);
  UR^.SystemName := Config^.GetBbsName;
  UR^.BbsLocation := Config^.GetBbsLoc;
  UR^.BbsPhone := Config^.GetBbsPhone;
  UR^.SysopName := Config^.GetSysopName;
  UR^.BoardId := Config^.GetBbsId;
  UR^.PrnName := Config^.GetPrnName;
  F.Init('General System Info');
  F.Window(3, 6, 73, 20);
  F.At(2, 3, 2, 16);
  F.AddString('System Name:', UR^.SystemName, 40, 'System Name');
  F.At(4, 3, 4, 13);
  F.AddString('Location:', UR^.BbsLocation, 40, 'Location');
  F.At(6, 3, 6, 14);
  F.AddString('Bbs Phone:', UR^.BbsPhone, 15, 'Bbs Phone');
  F.At(6, 39, 6, 47);
  F.AddString('Bbs Id:', UR^.BoardId, 8, 'Bbs Id');
  F.At(8, 3, 8, 15);
  F.AddString('Sysop Name:', UR^.SysopName, 35, 'Sysop Name');
  F.At(10, 3, 10, 12);
  F.AddHex('Color 1:', UR^.Color[1], 1, 'Color 1');
  F.OnF2(PickColor, @UR^.Color[1], '[ Select Color 1 ]');
  F.At(10, 16, 10, 25);
  F.AddHex('Color 2:', UR^.Color[2], 1, 'Color 2');
  F.OnF2(PickColor, @UR^.Color[2], '[ Select Color 2 ]');
  F.At(10, 29, 10, 38);
  F.AddHex('Color 3:', UR^.Color[3], 1, 'Color 3');
  F.OnF2(PickColor, @UR^.Color[3], '[ Select Color 3 ]');
  F.At(10, 42, 10, 51);
  F.AddHex('Color 4:', UR^.Color[4], 1, 'Color 4');
  F.OnF2(PickColor, @UR^.Color[4], '[ Select Color 4 ]');
  F.At(10, 55, 10, 64);
  F.AddHex('Color 5:', UR^.Color[5], 1, 'Color 5');
  F.OnF2(PickColor, @UR^.Color[5], '[ Select Color 5 ]');
  F.At(12, 3, 12, 23);
  F.AddYesNo('Direct Scrn Writes:', UR^.DirectWrite, 'Direct Scrn Writes');
  F.At(12, 27, 12, 42);
  F.AddYesNo('Snow Checking:', UR^.SnowCheck, 'Snow Checking');
  F.At(12, 47, 12, 58);
  F.AddYesNo('Mono Mode:', UR^.MonoMode, 'Mono Mode');
  F.At(14, 3, 14, 17);
  F.AddString('Printer Name:', UR^.PrnName, 20, 'Printer Name');
  If F.Execute Then
    Begin
    Config^.SetDirectWrite(UR^.DirectWrite);
    Config^.SetMonoMode(UR^.MonoMode);
    Config^.SetPrnName(UR^.PrnName);
    Config^.SetSnowCheck(UR^.SnowCheck);
    For i := 1 to 5 Do
      Config^.SetSystemColor(i, UR^.Color[i]);
    Config^.SetBbsName(UR^.SystemName);
    Config^.SetBbsLoc(UR^.BbsLocation);
    Config^.SetBbsPhone(UR^.BbsPhone);
    Config^.SetSysopName(UR^.SysopName);
    Config^.SetBbsId(UR^.BoardId);
    End;
    Dispose(UR);
  End;


End.
