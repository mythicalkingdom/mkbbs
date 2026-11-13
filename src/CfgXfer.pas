Unit CfgXfer;   {Converted from CFGXFER for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgXfer;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;



Type UserRecord = Record
  DLStartH: Byte;
  DLStartM: Byte;
  DownloadStopH: Byte;
  DownloadStopM: Byte;
  LowBaudH: Byte;
  LowBaudM: Byte;
  LowBaudStopH: Byte;
  LowBaudStopM: Byte;
  XferBaud: Word;
  ULCredit: Word;
  MinDesc: Byte;
  MaxDesc: Byte;
  MinULSpace: LongInt;
  AskFiles: Boolean;
  ForceFiles: Boolean;
  End;

Var
  UR: ^UserRecord;
  Tmp: Word;

Procedure DoCfgXfer;
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.DLStartH := Hi(Config^.GetDLStart);
  UR^.DLStartM := Lo(Config^.GetDLStart);
  UR^.DownloadStopH := Hi(Config^.GetDLStop);
  UR^.DownloadStopM := Lo(Config^.GetDLStop);
  UR^.LowBaudH := Hi(Config^.GetLoBaudStart);
  UR^.LowBaudM := Lo(Config^.GetLoBaudStart);
  UR^.LowBaudStopH := Hi(Config^.GetLoBaudStop);
  UR^.LowBaudStopM := Lo(Config^.GetLoBaudStop);
  UR^.XferBaud := Config^.GetMinXferBaud;
  UR^.ULCredit := Config^.GetULCredit;
  UR^.MinDesc := Config^.GetMinDesc;
  UR^.MaxDesc := Config^.GetMaxDesc;
  UR^.MinULSpace := Config^.GetMinFree;
  UR^.AskFiles := Config^.GetAskNewFiles;
  UR^.ForceFiles := Config^.GetForceNewFiles;
  F.Init('File Transfer Configuration');
  F.Window(7, 6, 71, 20);
  F.At(2, 3, 2, 24);
  F.ZeroPad(2);
  F.AddNumber('Download Start Time:', UR^.DLStartH, 1, 0, 24, 'Download Start Time');
  F.At(2, 26, 2, 27);
  F.ZeroPad(2);
  F.AddNumber(':', UR^.DLStartM, 1, 0, 59, '');
  F.At(2, 35, 2, 55);
  F.ZeroPad(2);
  F.AddNumber('Download Stop Time:', UR^.DownLoadStopH, 1, 0, 24, 'Download Stop Time');
  F.At(2, 57, 2, 58);
  F.ZeroPad(2);
  F.AddNumber(':', UR^.DownloadStopM, 1, 0, 59, '');
  F.At(4, 3, 4, 19);
  F.ZeroPad(2);
  F.AddNumber('Low Baud Start:', UR^.LowBaudH, 1, 0, 24, 'Low Baud Start');
  F.At(4, 21, 4, 22);
  F.ZeroPad(2);
  F.AddNumber(':', UR^.LowBaudM, 1, 0, 59, '');
  F.At(4, 35, 4, 50);
  F.ZeroPad(2);
  F.AddNumber('Low Baud Stop:', UR^.LowBaudStopH, 1, 0, 24, 'Low Baud Stop');
  F.At(4, 52, 4, 53);
  F.ZeroPad(2);
  F.AddNumber(':', UR^.LowBaudStopM, 1, 0, 59, '');
  F.At(6, 3, 6, 31);
  F.AddNumber('Minimum Transfer Baud Rate:', UR^.XferBaud, 2, 0, 65535, 'Minimum Transfer Baud Rate');
  F.At(6, 40, 6, 55);
  F.AddNumber('Upload Credit:', UR^.ULCredit, 2, 0, 65535, 'Upload Credit');
  F.At(8, 3, 8, 27);
  F.AddNumber('Min Description Length:', UR^.MinDesc, 1, 0, 255, 'Min Description Length');
  F.At(8, 35, 8, 59);
  F.AddNumber('Max Description Length:', UR^.MaxDesc, 1, 1, 240, 'Max Description Length');
  F.At(10, 3, 10, 26);
  F.AddNumber('Minumum free UL Space:', UR^.MinULSpace, 4, 0, $7FFFFFFF, 'Minumum free UL Space');
  F.At(12, 3, 12, 33);
  F.AddYesNo('Ask New File Seach at Log-in:', UR^.AskFiles, 'Ask New File Seach at Log-in');
  F.At(14, 3, 14, 37);
  F.AddYesNo('Force New Files Search at Log-in:', UR^.ForceFiles, 'Force New Files Search at Log-in');
  If F.Execute Then
    Begin
    Tmp := UR^.DLStartH;
    Tmp := (Tmp shl 8) + UR^.DLStartM;
    Config^.SetDLStart(Tmp);
    Tmp := UR^.DownloadStopH;
    Tmp := (Tmp shl 8) + UR^.DownloadStopM;
    Config^.SetDLStop(Tmp);
    Tmp := UR^.LowBaudH;
    Tmp := (Tmp shl 8) + UR^.LowBaudM;
    Config^.SetLoBaudStart(Tmp);
    Tmp := UR^.LowbaudStopH;
    Tmp := (Tmp shl 8) + UR^.LowBaudStopM;
    Config^.SetLoBaudStop(Tmp);
    Config^.SetMinXferBaud(UR^.XferBaud);
    Config^.SetULCredit(UR^.ULCredit);
    Config^.SetMinDesc(UR^.MinDesc);
    Config^.SetMaxDesc(UR^.MaxDesc);
    Config^.SetMinFree(UR^.MinULSpace);
    Config^.SetAskNewFiles(UR^.AskFiles);
    Config^.SetForceNewFiles(UR^.ForceFiles);
    End;
    Dispose(UR);
  End;


End.
