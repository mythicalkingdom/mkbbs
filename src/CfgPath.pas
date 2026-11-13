Unit CfgPath;   {System paths screen}

{$I MKB.Def}

Interface

Procedure DoCfgPath;

Implementation

Uses MKString, MKCfgAbs, CfgForm;

Type
  UserRecord = Record
    MsgPath: Array[1..10] Of String[60];
    NetPath: String[60];
    TempPath: String[60];
    LogFileName: String[60];
    EditCmdPath: String[60];
    NodeListPath: String[60];
    AttachPath: String[60];
    SemPath: String[60];
    EchoLog: String[60];
    End;


Procedure DoCfgPath;
  Var
    UR: ^UserRecord;
    F: CfgFormObj;
    i: Word;

  Begin
  New(UR);
  For i := 1 to 10 Do
    UR^.MsgPath[i] := Config^.GetMsgPath(i);
  UR^.NetPath := Config^.GetNetPath;
  UR^.TempPath := Config^.GetTempPath;
  UR^.LogFileName := Config^.GetLogFileName;
  UR^.EditCmdPath := Config^.GetEditCmdPath;
  UR^.NodeListPath := Config^.GetNodeListPath;
  UR^.AttachPath := Config^.GetAttachPath;
  UR^.SemPath := Config^.GetSemaphorePath;
  UR^.EchoLog := Config^.GetEchoLog;
  F.Init('System Paths');
  For i := 1 to 10 Do
    F.AddDir('Msg Base ' + Long2Str(i), UR^.MsgPath[i], 60,
      'Directory of message base ' + Long2Str(i));
  F.AddDir('NetMail', UR^.NetPath, 60, 'Directory for netmail messages');
  F.AddDir('Temp Files', UR^.TempPath, 60, 'Directory for temporary files');
  F.AddFile('Log File', UR^.LogFileName, 60, 'Name of the system log file');
  F.AddFile('Editor', UR^.EditCmdPath, 60, 'Message editor program and options');
  F.AddDir('Node List Dir', UR^.NodeListPath, 60, 'Directory with the nodelist files');
  F.AddDir('File Attach', UR^.AttachPath, 60, 'Directory for local file attaches');
  F.AddDir('Semaphore Path', UR^.SemPath, 60, 'Directory for semaphore files');
  F.AddFile('EchoToss Log', UR^.EchoLog, 60, 'Name of the echomail toss log');
  If F.Execute Then
    Begin
    For i := 1 to 10 Do
      Config^.SetMsgPath(i, UR^.MsgPath[i]);
    Config^.SetNetPath(UR^.NetPath);
    Config^.SetTempPath(UR^.TempPath);
    Config^.SetLogFileName(UR^.LogFileName);
    Config^.SetEditCmdPath(UR^.EditCmdPath);
    Config^.SetNodeListPath(UR^.NodeListPath);
    Config^.SetAttachPath(UR^.AttachPath);
    Config^.SetSemaphorePath(UR^.SemPath);
    Config^.SetEchoLog(UR^.EchoLog);
    End;
  Dispose(UR);
  End;


End.
