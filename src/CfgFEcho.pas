Unit CfgFEcho;   {File echoes (TIC): the echoes, their options and the systems' passwords (FileEcho.Mk); see TIC-PLAN.md}

{$I MKB.Def}

Interface

Procedure DoCfgFileEchoes;             {EchoMail > File Echoes: the list of echoes}
Procedure DoCfgFileEchoOpts;           {EchoMail > File Echo Options: the check command, the pass-through spool}
Procedure DoCfgFileEchoSys;            {EchoMail > File Echo Systems: TIC and FileFix passwords, groups}

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgList, CfgBox;

Var
  FE: ^FileEchoCfgType;


Function SystemStr(Item: Word): String;
  Var
    A: AddrType;

  Begin
  Config^.GetEchoToAddr(Item, A);
  SystemStr := PadLeft(Long2Str(Item), ' ', 3) + '  ' + AddrStr(A);
  End;


Function GroupStr(Item: Word): String;
  Begin
  GroupStr := 'Group - ' + Char(Item + Ord('A') - 1);
  End;


Procedure GroupMarks(Var Mask: LongInt; Title: String);
  {the 26 groups of a mask (A = bit 0)}
  Var
    Marks: CfgBigMarks;
    i: Word;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  For i := 1 To 26 Do
    Marks[i] := (Mask And (LongInt(1) Shl (i - 1))) <> 0;
  If RunMarkList(Title, 26, 24, GroupStr, Marks) Then
    Begin
    Mask := Mask And Not LongInt($03FFFFFF);
    For i := 1 To 26 Do
      If Marks[i] Then
        Mask := Mask Or (LongInt(1) Shl (i - 1));
    End;
  End;


Function GroupLetters(Mask: LongInt): String;
  Var
    i: Word;
    S: String;

  Begin
  S := '';
  For i := 1 To 26 Do
    If (Mask And (LongInt(1) Shl (i - 1))) <> 0 Then
      S := S + Char(i + Ord('A') - 1);
  GroupLetters := S;
  End;


{------------------------------------------------------------ the echoes}

Var
  Cur: ^FileEchoAreaType;              {the echo being edited}


Function EchoStr(Item: Word): String;
  Var
    S: String;

  Begin
  With FE^.Area[Item] Do
    If Tag = '' Then
      S := '(unused)'
    Else If FileArea = 0 Then
      S := PadRight(Tag, ' ', 26) + 'pass-through'
    Else
      S := PadRight(Tag, ' ', 26) + 'area ' + Long2Str(FileArea);
  EchoStr := PadLeft(Long2Str(Item), ' ', 4) + '  ' + S;
  End;


Procedure PickEchoTo(Data: Pointer; Title: String);
  {The echo systems that get the files of this echo}
  Var
    Marks: CfgBigMarks;
    i: Word;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  For i := 1 To 32 Do
    Marks[i] := (Cur^.EchoTo And (LongInt(1) Shl (i - 1))) <> 0;
  If RunMarkList('Echo To (systems)', 32, 34, SystemStr, Marks) Then
    Begin
    Cur^.EchoTo := 0;
    For i := 1 To 32 Do
      If Marks[i] Then
        Cur^.EchoTo := Cur^.EchoTo Or (LongInt(1) Shl (i - 1));
    End;
  End;


Procedure PickGroups(Data: Pointer; Title: String);
  Begin
  GroupMarks(Cur^.Groups, 'Groups of the echo (none = any system may link)');
  End;


Procedure EditEcho(Item: Word);
  Var
    F: CfgFormObj;
    Replaces, NoCheck: Boolean;
    Hub, FArea: Word;

  Begin
  New(Cur);
  Cur^ := FE^.Area[Item];
  Replaces := (Cur^.Attr And feReplaces) <> 0;
  NoCheck := (Cur^.Attr And feNoCheck) <> 0;
  Hub := Cur^.Hub;
  FArea := Cur^.FileArea;
  F.Init('File Echo ' + Long2Str(Item));
  F.Window(3, 4, 76, 15);
  F.At(2, 3, 2, 10);
  F.AddString('Tag:', Cur^.Tag, 40, 'The name of the file echo as the network knows it (blank = the echo is not used)');
  F.At(3, 3, 3, 10);
  F.AddString('About:', Cur^.Desc, 40, 'What the echo is (the Areadesc line of the TIC)');
  F.At(5, 3, 5, 14);
  F.AddNumber('File area:', FArea, 3, 0, 300, 'The file area (Files > Areas) the files go to; 0 = pass-through: no copy is kept, the files are only passed on');
  F.At(6, 3, 6, 14);
  F.AddNumber('Hub:', Hub, 2, 0, 32, 'The echo system this echo comes from (1 to 32 as in EchoMail > Systems), 0 = none');
  F.At(8, 3, 8, 22);
  F.AddYesNo('Replaces allowed:', Replaces, 'A TIC may name files it replaces: they are deleted when the new one comes');
  F.At(9, 3, 9, 22);
  F.AddYesNo('No check command:', NoCheck, 'Do not run the check command of File Echo Options for the files of this echo');
  F.At(10, 3, 10, 22);
  F.AddAction('Echo To...', PickEchoTo, Nil, '', 'The systems that get the files');
  F.At(10, 30, 10, 46);
  F.AddAction('Groups...', PickGroups, Nil, '', 'The groups of the echo: a system may list and link to it when it has one of them');
  If F.Execute Then
    Begin
    Cur^.Hub := Hub;
    Cur^.FileArea := FArea;
    Cur^.Attr := Cur^.Attr And Not (feReplaces Or feNoCheck);
    If Replaces Then Cur^.Attr := Cur^.Attr Or feReplaces;
    If NoCheck Then Cur^.Attr := Cur^.Attr Or feNoCheck;
    FE^.Area[Item] := Cur^;
    End;
  Dispose(Cur);
  Cur := Nil;
  End;


Procedure DoCfgFileEchoes;
  Begin
  If Not Config^.HasFileEcho Then
    Begin
    MsgBox('The file echoes are kept by the MK configuration only');
    Exit;
    End;
  New(FE);
  Config^.GetFileEcho(FE^);
  RunList('File Echoes', MaxFileEchoes, 50, EchoStr, EditEcho);
  Config^.SetFileEcho(FE^);
  Dispose(FE);
  FE := Nil;
  End;


{------------------------------------------------------------ the options}

Procedure DoCfgFileEchoOpts;
  Var
    F: CfgFormObj;
    O: ^FileEchoCfgType;

  Begin
  If Not Config^.HasFileEcho Then
    Begin
    MsgBox('The file echoes are kept by the MK configuration only');
    Exit;
    End;
  New(O);
  Config^.GetFileEcho(O^);
  F.Init('File Echo Options');
  F.Window(3, 4, 76, 15);
  F.At(2, 3, 2, 18);
  F.AddString('Check command:', O^.CheckCmd, 100, 'Run for each file before it is accepted (%F = the file, %T = the TIC); an exit status other than 0 refuses it. Blank = no check');
  F.At(3, 3, 3, 18);
  F.AddNumber('Check time (s):', O^.CheckTimeout, 3, 0, 65535, 'Seconds before the check is stopped and the file refused, 0 = 60');
  F.At(5, 3, 5, 18);
  F.AddDir('Pass-thru spool:', O^.SpoolPath, 60, 'Where the files of pass-through echoes wait for the systems that fetch them; blank = <outbound>/mktoss/tic');
  F.At(6, 3, 6, 18);
  F.AddNumber('Pass-thru days:', O^.PassDays, 3, 0, 65535, 'Days a pass-through file waits for a system that has not fetched it, then it is dropped; 0 = 14');
  F.At(7, 3, 7, 18);
  F.AddNumber('Pass-thru MB:', O^.PassMaxMB, 5, 0, 65535, 'The most the pass-through spool may hold in megabytes, the oldest files go first; 0 = no limit');
  If F.Execute Then
    Config^.SetFileEcho(O^);
  Dispose(O);
  End;


{------------------------------------------------------------ the systems}

Var
  SysNo: Word;


Function SysLine(Item: Word): String;
  Var
    S: String;

  Begin
  With FE^.Sys[Item] Do
    S := PadRight('TIC pwd ' + Copy('*********', 1, Length(TicPwd)), ' ', 16) +
         PadRight('FileFix ' + Copy('*********', 1, Length(FixPwd)), ' ', 18) + 'groups ' + GroupLetters(Groups);
  SysLine := PadRight(SystemStr(Item), ' ', 24) + S;
  End;


Procedure PickSysGroups(Data: Pointer; Title: String);
  Begin
  GroupMarks(FE^.Sys[SysNo].Groups, 'Groups of the system');
  End;


Procedure EditSys(Item: Word);
  Var
    F: CfgFormObj;
    S: FileEchoSysType;

  Begin
  SysNo := Item;
  S := FE^.Sys[Item];
  F.Init('File Echo System ' + Long2Str(Item));
  F.Window(3, 4, 76, 14);
  F.At(2, 3, 2, 22);
  F.AddString('TIC password:', S.TicPwd, 8, 'The password in the TIC files of this system (8 characters at most), blank = none');
  F.At(3, 3, 3, 22);
  F.AddString('FileFix password:', S.FixPwd, 15, 'The password for netmail to FileFix; blank = the Areafix password of the system');
  F.At(5, 3, 5, 22);
  F.AddAction('Groups...', PickSysGroups, Nil, '', 'The groups of echoes the system may list and link to');
  If F.Execute Then
    Begin
    FE^.Sys[Item].TicPwd := S.TicPwd;
    FE^.Sys[Item].FixPwd := S.FixPwd;
    End;
  End;


Procedure DoCfgFileEchoSys;
  Begin
  If Not Config^.HasFileEcho Then
    Begin
    MsgBox('The file echoes are kept by the MK configuration only');
    Exit;
    End;
  New(FE);
  Config^.GetFileEcho(FE^);
  RunList('File Echo Systems', 32, 70, SysLine, EditSys);
  Config^.SetFileEcho(FE^);
  Dispose(FE);
  FE := Nil;
  End;


End.
