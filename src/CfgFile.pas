{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgFile;   {Converted from CFGFILE for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgFile(Area: Word);

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob, CfgSec2;


Type UserRecord = Record
  AreaNum: Word;
  Name: String[40];
  Select: String[10];
  FilePath: String[60];
  ULSec: SecType;
  DLSec: SecType;
  ViewSec: SecType;
  PFileSec: SecType;
  NewFiles: Boolean;
  AllowUL: Boolean;
  FreeArea: Boolean;
  IgnoreTime: Boolean;
  IgnoreBaud: Boolean;
  Freq: Boolean;
  ShortName: String[12];
  End;

Var
  UR: ^UserRecord;

Procedure DoCfgFile(Area: Word);
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.AreaNum := Area;
  UR^.Name := Config^.GetFileAreaName(Area);
  UR^.ShortName := Config^.GetFileShortName(Area);
  UR^.Select := Config^.GetFileSelect(Area);
  UR^.FilePath := Config^.GetFileAreaPath(Area);
  Config^.GetFileViewSecurity(Area, UR^.ViewSec);
  Config^.GetFileULSecurity(Area, UR^.ULSec);
  Config^.GetFileDLSecurity(Area, UR^.DLSec);
  Config^.GetFilePvtSecurity(Area, UR^.PFileSec);
  UR^.AllowUL := Not Config^.GetFileNoUL(Area);
  UR^.NewFiles := Not Config^.GetFileNoNew(Area);
  UR^.FreeArea := Config^.GetFileFree(Area);
  UR^.IgnoreTime := Config^.GetFileNoTime(Area);
  UR^.IgnoreBaud := Config^.GetFileNoBaud(Area);
  UR^.Freq := Config^.GetFileFreq(Area);
  F.Init('File Area ' + Long2Str(UR^.AreaNum) + ' Configuration');
  F.Window(5, 6, 74, 20);
  F.At(2, 4, 2, 10);
  F.AddString('Name:', UR^.Name, 30, 'Name');
  F.At(2, 45, 2, 53);
  F.AddString('Select:', UR^.Select, 4, 'Select');
  F.At(4, 4, 4, 15);
  F.AddString('File Path:', UR^.FilePath, 50, 'File Path');
  F.At(6, 4, 6, 19);
  F.AddNumber('View Security:', UR^.ViewSec.Level, 2, 0, 65535, 'View Security');
  F.OnF2(EditSecurity, @UR^.ViewSec, '[ View Security ]');
  F.At(6, 28, 6, 41);
  F.AddNumber('DL Security:', UR^.DLSec.Level, 2, 0, 65535, 'DL Security');
  F.OnF2(EditSecurity, @UR^.DLSec, '[ DL Security ]');
  F.At(6, 50, 6, 63);
  F.AddNumber('UL Security:', UR^.ULSec.Level, 2, 0, 65535, 'UL Security');
  F.OnF2(EditSecurity, @UR^.ULSec, '[ UL Security ]');
  F.At(8, 4, 8, 19);
  F.AddNumber('PFileSecurity:', UR^.PFileSec.Level, 2, 0, 65535, 'PFileSecurity');
  F.OnF2(EditSecurity, @UR^.PFileSec, '[ PFile Security ]');
  F.At(8, 28, 8, 43);
  F.AddYesNo('Allow Uploads:', UR^.AllowUL, 'Allow Uploads');
  F.At(8, 50, 8, 66);
  F.AddYesNo('Free File Area:', UR^.FreeArea, 'Free File Area');
  F.At(10, 4, 10, 24);
  F.AddYesNo('Ignore Time Limits:', UR^.IgnoreTime, 'Ignore Time Limits');
  F.At(10, 42, 10, 62);
  F.AddYesNo('Ignore Baud Limits:', UR^.IgnoreBaud, 'Ignore Baud Limits');
  F.At(12, 4, 12, 26);
  F.AddYesNo('Include in New Files:', UR^.NewFiles, 'Include in New Files');
  F.At(12, 30, 12, 42);
  F.AddString('Short Name:', UR^.ShortName, 12, 'Short Name');
  If DetectBbsType = 1 Then
    Begin
    F.At(14, 4, 14, 26);
    F.AddYesNo('Allow file requests:', UR^.Freq, 'Other systems may request the files of this area (FTN file requests; see EchoMail > File Requests)');
    End;
  If F.Execute Then
    Begin
    Config^.SetFileAreaName(Area, UR^.Name);
    Config^.SetFileShortName(Area, UR^.ShortName);
    Config^.SetFileSelect(Area, UR^.Select);
    Config^.SetFileAreaPath(Area, UR^.FilePath);
    Config^.SetFileViewSecurity(Area, UR^.ViewSec);
    Config^.SetFileULSecurity(Area, UR^.ULSec);
    Config^.SetFileDLSecurity(Area, UR^.DLSec);
    Config^.SetFilePvtSecurity(Area, UR^.PFileSec);
    Config^.SetFileNoUL(Area, Not UR^.AllowUL);
    Config^.SetFileNoNew(Area, Not UR^.NewFiles);
    Config^.SetFileFree(Area, UR^.FreeArea);
    Config^.SetFileNoTime(Area, UR^.IgnoreTime);
    Config^.SetFileNoBaud(Area, UR^.IgnoreBaud);
    Config^.SetFileFreq(Area, UR^.Freq);
    End;
    Dispose(UR);
  End;


End.
