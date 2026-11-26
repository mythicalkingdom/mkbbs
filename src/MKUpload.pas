Unit MKUpload;   {Menu command 173: a caller uploads files into a file area (UPLOAD-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
     The menu item's data is nothing (the caller's current file area) or the number of a file area.  The area must allow uploads for the caller's security
     (mkconfig: UL Security, Allow Uploads).  The files are received with the protocol the caller chooses into a directory made for this call, never into the
     area, and each one is then looked at in turn:

       the name   only A-Z a-z 0-9 . _ - + (other characters become _), no leading dot, at most 64 characters; a name that is in the area already is refused
       accepted   moved into the area, a line (or lines, the caller describes the file) added to files.bbs of the area, the caller credited (count, K),
                  the seconds of the transfer given back as time, a line in the log
       refused    deleted, the caller is told why

     With an uploads.cfg in the BBS directory (MKUpCfg.pas says what it holds) each file is also looked at by the commands of the sysop before it is accepted:
       the size     over the limit of the area -> refused;  the free disk space (minfree) is looked at before the transfer starts
       the test     the command of the file's type (unzip -t ...), exit 0 = good
       the scanner  every file (clamscan ...), exit 0 clean, 1 found, anything else = the scanner failed (scanfail: refuse | accept)
       the DIZ      FILE_ID.DIZ taken out of the archive is the description (ask = dizfirst | always | never)
     The commands run in bubblewrap (no network, the file read only) when the sandbox works; a file that fails goes to the quarantine directory with a .why note (or is deleted).

     A line of files.bbs is the file name, blanks up to column 14 and the description (45 columns at most for the first line); more lines of the description follow with 13 blanks
     in front.
}

Interface

Uses Classes;

Procedure DoUpload(Data: ShortString);

Function UploadName(Const S: String): String;
  {the name as the BBS keeps it: the characters of the rule above, at most 64 of them, no leading dot; '' when nothing is left}

Function ListLines(Const Name: String; Desc: TStrings): String;
  {the text to append to files.bbs for a file and its description lines}


Implementation

Uses SysUtils, BaseUnix, Unix, Process, MKUpCfg, MKDoorCfg, MKSandbox,
  MKGlobT, MKDoor, MKCfgAbs, MKComAbs, MKFile, MKString, MKProt, MKCFile, MKOffXfer, MKLogEnt;


Function UploadName(Const S: String): String;
  Var
    i: Integer;
    R: String;

  Begin
  R := '';
  For i := 1 To Length(S) Do
    If S[i] In ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-', '+'] Then
      R := R + S[i]
    Else
      R := R + '_';
  While (R <> '') And (R[1] = '.') Do
    Delete(R, 1, 1);
  If Length(R) > 64 Then
    R := Copy(R, 1, 64);
  UploadName := R;
  End;


Function ListLines(Const Name: String; Desc: TStrings): String;
  Var
    i: Integer;
    First, Pad: String;

  Begin
  If Length(Name) < 13 Then
    Pad := StringOfChar(' ', 13 - Length(Name))
  Else
    Pad := ' ';
  If Desc.Count > 0 Then
    First := Copy(Desc[0], 1, 45)
  Else
    First := '(no description)';
  ListLines := Name + Pad + First + #10;
  For i := 1 To Desc.Count - 1 Do
    ListLines := ListLines + StringOfChar(' ', 13) + Copy(Desc[i], 1, 60) + #10;
  End;


Function P(N: Word; Const Default: String): String;
  {a prompt of the language file; the text here when the language file is an older one without it}
  Var
    S: String;

  Begin
  S := Prompts.GetString(N);
  If S = '' Then
    S := Default;
  P := S;
  End;


Procedure Say(S: String);
  Begin
  User.DisplayStrLn(S);
  End;


Function TickSeconds: Int64;
  Begin
  TickSeconds := GetTickCount64 Div 1000;
  End;


Procedure SetInternal(Var Prot: ProtObj; ProtNum: Word);
  Begin
  Case ProtNum Of
    1: Prot.SetXmodem;
    2: Prot.SetX1K;
    3: Prot.SetYmodem;
    5: Prot.SetYModemG;
    6: Prot.SetXmodemG;
    Else Prot.SetZmodem;
    End;
  End;


Function Receive(Const WorkPath: String): Boolean;
  {the files of the caller into WorkPath with the protocol the caller picks; False when he picked none or the transfer failed}
  Var
    ProtNum: Word;
    Cmd: String;
    Prot: ProtObj;

  Begin
  Receive := False;
  ProtNum := GetProtocol(False);
  If ProtNum = 0 Then
    Exit;
  If ProtNum > 10 Then
    Begin
    Cmd := OffSplitProt(Config^.GetProtCmdLine(ProtNum), False);
    If Cmd = '' Then
      Exit;
    User.DisplayNewLine;
    Say(P(544, 'Start the upload with your terminal program now.'));
    User.PostStatus(uoXfer);
    Receive := OffTransfer(OffExpand(Cmd, '', 0, 0), StartUpPath, WorkPath);
    End
  Else If (ProtNum <= 6) Then
    Begin
    User.DisplayNewLine;
    Say(P(544, 'Start the upload with your terminal program now.'));
    User.PostStatus(uoXfer);
    Prot.Init;
    SetInternal(Prot, ProtNum);
    Prot.SetRecvName('upload.dat');
    Receive := Prot.Recv(WorkPath);
    Prot.Done;
    End;
  End;


Function InArea(Const Dir, Name: String): Boolean;
  {a file of this name (whatever the case) is in Dir}
  Var
    SR: TSearchRec;

  Begin
  InArea := False;
  If FindFirst(Dir + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If SameText(SR.Name, Name) Then
        InArea := True;
    Until (FindNext(SR) <> 0) Or (InArea);
    FindClose(SR);
    End;
  End;


Function MoveFile(Const From, To_: String): Boolean;
  Begin
  MoveFile := RenameFile(From, To_);
  If Not FileExists(To_) Then
    Begin
    If CopyFile(From, To_) Then
      Begin
      DeleteFile(From);
      MoveFile := True;
      End;
    End;
  End;


Var
  SandboxNoted: Boolean = False;
  MissingNoted: String = '|';


Function FindProgram(Const Prog: String): String;
  Begin
  If Pos('/', Prog) > 0 Then
    Begin
    If FileExists(Prog) Then
      FindProgram := Prog
    Else
      FindProgram := '';
    End
  Else
    FindProgram := FileSearch(Prog, GetEnvironmentVariable('PATH'));
  End;


Function RunTool(Cfg: TUpCfg; Const Cmd, Work, FileName: String; Out Output: String): Integer;
  {the command of uploads.cfg for the file (in Work): its exit code; -1 the program is not there (it is logged once), -2 the time limit (the program is killed), -3 it could not be started.
   In the sandbox when the settings say so and bubblewrap works: no network, the directory of the file read only}
  Var
    Args: TStringList;
    DC: TDoorCfg;
    Prog, Bw, Why, Script: String;
    PR: TProcess;
    RO, RW: TStringList;
    Buf: Array[0..4095] Of Byte;
    n: LongInt;
    T0: Int64;
    Sandboxed: Boolean;
    i: Integer;

  Begin
  Output := '';
  RunTool := -3;
  Args := TStringList.Create;
  Try
    If Not SplitCommand(Cmd, FileName, Work, Args) Then
      Exit;
    Prog := FindProgram(Args[0]);
    If Prog = '' Then
      Begin
      If Pos('|' + Args[0] + '|', MissingNoted) = 0 Then
        Begin
        MissingNoted := MissingNoted + Args[0] + '|';
        LogEntry.WriteEntry('Upload: the program ' + Args[0] + ' of uploads.cfg is not installed: its test is skipped');
        End;
      RunTool := -1;
      Exit;
      End;
    Args[0] := Prog;
    Sandboxed := False;
    Script := ExcludeTrailingPathDelimiter(Work) + '.sh';
    If Cfg.Sandbox Then
      Begin
      DC := TDoorCfg.Create;
      RO := TStringList.Create;
      RW := TStringList.Create;
      Try
        DC.Load(IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'doors.cfg');
        Bw := FindBwrap(DC.SbProgram);
        If SandboxWorks(Bw, Why) Then
          Begin
          RO.Add(ExcludeTrailingPathDelimiter(Work));
          RO.AddStrings(DC.SbROBinds);
          RO.AddStrings(Cfg.ROBinds);
          RW.AddStrings(DC.SbBinds);
          RW.AddStrings(Cfg.Binds);
          Sandboxed := SandboxWrapper(Script, Bw, 'default', ExcludeTrailingPathDelimiter(Work), RW, RO);
          End
        Else If Not SandboxNoted Then
          Begin
          SandboxNoted := True;
          LogEntry.WriteEntry('Upload: no sandbox for the tests (' + Why + '): they run unwrapped');
          End;
      Finally
        DC.Free;
        RO.Free;
        RW.Free;
      End;
      End;
    PR := TProcess.Create(Nil);
    Try
      If Sandboxed Then
        Begin
        PR.Executable := Script;
        For i := 0 To Args.Count - 1 Do
          PR.Parameters.Add(Args[i]);
        End
      Else
        Begin
        PR.Executable := Args[0];
        For i := 1 To Args.Count - 1 Do
          PR.Parameters.Add(Args[i]);
        End;
      PR.CurrentDirectory := ExcludeTrailingPathDelimiter(Work);
      PR.Options := [poUsePipes, poStderrToOutput];
      Try
        PR.Execute;
      Except
        RunTool := -3;
        Exit;
      End;
      T0 := GetTickCount64;
      While PR.Running Or (PR.Output.NumBytesAvailable > 0) Do
        Begin
        If PR.Output.NumBytesAvailable > 0 Then
          Begin
          n := PR.Output.Read(Buf, SizeOf(Buf));
          If (n > 0) And (Length(Output) < 8000) Then
            Begin
            SetLength(Output, Length(Output) + n);
            Move(Buf, Output[Length(Output) - n + 1], n);
            End;
          End
        Else
          Sleep(20);
        If (GetTickCount64 - T0) > Int64(Cfg.Timeout) * 1000 Then
          Begin
          PR.Terminate(9);
          RunTool := -2;
          Exit;
          End;
        End;
      RunTool := PR.ExitStatus;
      If PR.ExitStatus > 255 Then
        RunTool := (PR.ExitStatus Shr 8) And 255;          {the status as wait gives it: the exit code is in the second byte}
    Finally
      PR.Free;
      If Sandboxed Then
        DeleteFile(Script);
    End;
  Finally
    Args.Free;
  End;
  End;


Function FirstLine(Const S: String): String;
  {the first line that says something, without control characters, 70 characters at most}
  Var
    L: TStringList;
    i, j: Integer;
    T: String;

  Begin
  FirstLine := '';
  L := TStringList.Create;
  Try
    L.Text := S;
    For i := 0 To L.Count - 1 Do
      Begin
      T := '';
      For j := 1 To Length(L[i]) Do
        If L[i][j] >= ' ' Then
          T := T + L[i][j];
      T := Trim(T);
      If T <> '' Then
        Begin
        FirstLine := Copy(T, 1, 70);
        Exit;
        End;
      End;
  Finally
    L.Free;
  End;
  End;


Procedure CleanDiz(Const Raw: String; Desc: TStrings);
  {FILE_ID.DIZ as description lines: control characters and the high characters of the DOS days become blanks or are dropped, empty lines at the start and the end go, 10 lines at most}
  Var
    L: TStringList;
    i, j: Integer;
    T: String;

  Begin
  Desc.Clear;
  L := TStringList.Create;
  Try
    L.Text := Raw;
    For i := 0 To L.Count - 1 Do
      Begin
      T := '';
      For j := 1 To Length(L[i]) Do
        If (L[i][j] >= ' ') And (L[i][j] < #127) Then
          T := T + L[i][j]
        Else If L[i][j] = #9 Then
          T := T + ' ';
      T := TrimRight(T);
      If (T = '') And (Desc.Count = 0) Then
        Continue;
      Desc.Add(T);
      End;
    While (Desc.Count > 0) And (Trim(Desc[Desc.Count - 1]) = '') Do
      Desc.Delete(Desc.Count - 1);
    While Desc.Count > 10 Do
      Desc.Delete(Desc.Count - 1);
    For i := 0 To Desc.Count - 1 Do
      Desc[i] := Copy(Trim(Desc[i]), 1, 60);
  Finally
    L.Free;
  End;
  End;


Function FreeMB(Const Dir: String): Int64;
  {MB free on the disk of Dir for the BBS user; -1 when it cannot be told}
  Var
    B: TStatFS;

  Begin
  FreeMB := -1;
  If fpStatFS(PChar(ExcludeTrailingPathDelimiter(Dir)), @B) = 0 Then
    FreeMB := (Int64(B.bavail) * B.bsize) Div 1048576;
  End;


Procedure Quarantine(Const QDir, Path, Clean, Reason, Output: String; Area: Word);
  {the refused file moves to QDir under a name with the date, and the note says who, where, why, and what the command printed.  '' = deleted}
  Var
    Stamp, Dest: String;
    N: TStringList;

  Begin
  If QDir = '' Then
    Begin
    DeleteFile(Path);
    Exit;
    End;
  ForceDirectories(QDir);
  Stamp := FormatDateTime('yyyymmdd-hhnnss', Now);
  Dest := IncludeTrailingPathDelimiter(QDir) + Stamp + '-' + Clean;
  If Not MoveFile(Path, Dest) Then
    Begin
    DeleteFile(Path);
    Exit;
    End;
  N := TStringList.Create;
  Try
    N.Add('file:    ' + Clean);
    N.Add('area:    ' + IntToStr(Area));
    N.Add('caller:  ' + User.GetUserName);
    N.Add('when:    ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    N.Add('why:     ' + Reason);
    If Trim(Output) <> '' Then
      Begin
      N.Add('output:');
      N.Add(Copy(Output, 1, 2000));
      End;
    Try
      N.SaveToFile(Dest + '.why');
    Except
    End;
  Finally
    N.Free;
  End;
  End;


Procedure AskDescription(Const Name: String; Desc: TStrings);
  Var
    L: String;
    n: Integer;

  Begin
  Desc.Clear;
  User.DisplayNewLine;
  Say(P(548, 'Describe') + ' ' + Name + ' ' + P(549, '(an empty line ends the description):'));
  n := 0;
  While (n < 10) And User.OK Do
    Begin
    User.DisplayStr(': ');
    L := User.InputStr('', 60);
    User.DisplayNewLine;
    L := Trim(L);
    If L = '' Then
      Break;
    Desc.Add(L);
    Inc(n);
    End;
  End;


Procedure AppendList(Const ListFile, Text: String);
  Var
    F: TFileStream;

  Begin
  If FileExists(ListFile) Then
    F := TFileStream.Create(ListFile, fmOpenReadWrite Or fmShareDenyNone)
  Else
    F := TFileStream.Create(ListFile, fmCreate);
  Try
    F.Seek(0, soEnd);
    F.WriteBuffer(Text[1], Length(Text));
  Finally
    F.Free;
  End;
  End;


Procedure DoUpload(Data: ShortString);
  Var
    Area: Word;
    Sec: SecType;
    Dir, Work, Name, Clean, Dest: String;
    SR: TSearchRec;
    Names: TStringList;
    Desc: TStringList;
    i: Integer;
    Size: LongInt;
    Got, Refused: Integer;
    T0, Secs: Int64;
    Ok: Boolean;
    Cfg: TUpCfg;
    QDir, Out_, Reason, Cmd, Ask: String;
    Ty, Rc, Ai: Integer;
    Raw: String;
    Diz: TStringList;
    Min: LongInt;

  Begin
  If Trim(Data) <> '' Then
    Area := StrToIntDef(Trim(Data), 0)
  Else
    Area := User.GetUserFileTemplate;
  User.GetUserSec(Sec);
  If (Area = 0) Or (Not Config^.FileULAccess(Area, Sec)) Or Config^.GetFileNoUl(Area) Then
    Begin
    User.DisplayNewLine;
    Say(P(543, 'Uploads are not allowed in this area.'));
    User.DisplayNewLine;
    User.PressEnter;
    Exit;
    End;
  Dir := WithBackSlash(Config^.GetFileAreaPath(Area));
  If Not DirectoryExists(Dir) Then
    Begin
    Say(P(543, 'Uploads are not allowed in this area.'));
    User.PressEnter;
    Exit;
    End;
  Cfg := TUpCfg.Create;
  Cfg.Load(IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'uploads.cfg');
  QDir := Cfg.QuarantineOf(Area);
  Ai := Cfg.AreaIndex(Area);
  If (Not Cfg.QuarSet) And ((Ai < 0) Or (Not Cfg.Areas[Ai].QuarSet)) Then
    QDir := IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'quarantine';
  Min := Cfg.MinFreeOf(Area);
  If (Min > 0) And ((FreeMB(Dir) >= 0) And (FreeMB(Dir) < Min)) Then
    Begin
    User.DisplayNewLine;
    Say(P(557, 'There is not enough free disk space for an upload now.'));
    LogEntry.WriteEntry('Upload refused: only ' + IntToStr(FreeMB(Dir)) + ' MB free for area ' + IntToStr(Area));
    Cfg.Free;
    User.PressEnter;
    Exit;
    End;
  Work := CreateTempDir(Config^.GetTempPath);
  If Work = '' Then
    Begin
    Say(P(545, 'No file was received.'));
    Cfg.Free;
    Exit;
    End;
  Work := WithBackSlash(Work);
  CommFlow(fcHard);
  T0 := TickSeconds;
  Ok := Receive(Work);
  CommFlow(fcBoth);
  Secs := TickSeconds - T0;
  Names := TStringList.Create;
  Desc := TStringList.Create;
  Diz := TStringList.Create;
  If FindFirst(Work + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If (SR.Attr And faDirectory) = 0 Then
        Names.Add(SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Names.Sort;
  User.DisplayNewLine;
  Got := 0;
  Refused := 0;
  For i := 0 To Names.Count - 1 Do
    Begin
    Name := Names[i];
    Size := SizeFile(Work + Name);
    Clean := UploadName(Name);
    If (Name = 'upload.dat') And (Clean = 'upload.dat') Then
      Clean := UploadName(Name);               {Xmodem sends no name: the caller is asked below}
    If (Size <= 0) Or (Clean = '') Then
      Begin
      Say(P(547, 'The file was refused:') + ' ' + Name);
      LogEntry.WriteEntry('Upload refused (name or empty): ' + Name + ' by ' + User.GetUserName);
      DeleteFile(Work + Name);
      Inc(Refused);
      Continue;
      End;
    If Name = 'upload.dat' Then
      Begin
      User.DisplayStr('Name for this file: ');
      Clean := UploadName(Trim(User.InputStr('', 40)));
      User.DisplayNewLine;
      If Clean = '' Then
        Begin
        DeleteFile(Work + Name);
        Inc(Refused);
        Continue;
        End;
      End;
    If InArea(Dir, Clean) Then
      Begin
      Say(P(547, 'The file was refused:') + ' ' + Clean + ' (' + P(551, 'there is a file of that name already') + ')');
      LogEntry.WriteEntry('Upload refused (name in use): ' + Clean + ' by ' + User.GetUserName);
      DeleteFile(Work + Name);
      Inc(Refused);
      Continue;
      End;
    If Name <> Clean Then
      Begin
      If FileExists(Work + Clean) Then
        Begin
        Say(P(547, 'The file was refused:') + ' ' + Clean);
        DeleteFile(Work + Name);
        Inc(Refused);
        Continue;
        End;
      RenameFile(Work + Name, Work + Clean);
      Name := Clean;
      End;
    Reason := '';
    Out_ := '';
    If (Cfg.MaxSizeOf(Area) > 0) And (Size > Int64(Cfg.MaxSizeOf(Area)) * 1024) Then
      Reason := P(553, 'it is too large, the limit (KB):') + ' ' + IntToStr(Cfg.MaxSizeOf(Area));
    If Reason = '' Then
      Begin
      Ty := Cfg.TypeFor(Clean);
      If (Ty >= 0) And (Cfg.Types[Ty].Test <> '') Then
        Begin
        Rc := RunTool(Cfg, Cfg.Types[Ty].Test, Work, Clean, Out_);
        If Rc = -2 Then
          Reason := P(554, 'it failed its test:') + ' time limit'
        Else If (Rc > 0) Or (Rc = -3) Then
          Begin
          Reason := P(554, 'it failed its test:') + ' ' + FirstLine(Out_);
          If FirstLine(Out_) = '' Then
            Reason := Reason + 'exit ' + IntToStr(Rc);
          End;
        End;
      End;
    If Reason = '' Then
      Begin
      Cmd := Cfg.ScanOf(Area);
      If Cmd <> '' Then
        Begin
        Rc := RunTool(Cfg, Cmd, Work, Clean, Out_);
        If Rc = 1 Then
          Reason := P(555, 'the scanner found something:') + ' ' + FirstLine(Out_)
        Else If Rc <> 0 Then
          Begin
          If Rc <> -1 Then
            LogEntry.WriteEntry('Upload: the scanner failed for ' + Clean + ' (' + IntToStr(Rc) + ') ' + FirstLine(Out_));
          If Cfg.ScanFail <> 'accept' Then
            Reason := P(556, 'it could not be checked, try again later.');
          End;
        End;
      End;
    If Reason <> '' Then
      Begin
      Say(P(547, 'The file was refused:') + ' ' + Clean);
      Say('  ' + Reason);
      LogEntry.WriteEntry('Upload refused: ' + Clean + ' by ' + User.GetUserName + ' in area ' + IntToStr(Area) + ': ' + Reason);
      Quarantine(QDir, Work + Clean, Clean, Reason, Out_, Area);
      Inc(Refused);
      Continue;
      End;
    Diz.Clear;
    Ask := Cfg.AskOf(Area);
    Ty := Cfg.TypeFor(Clean);
    If (Ty >= 0) And (Cfg.Types[Ty].Diz <> '') Then
      Begin
      Rc := RunTool(Cfg, Cfg.Types[Ty].Diz, Work, Clean, Raw);
      If Rc = 0 Then
        CleanDiz(Raw, Diz);
      End;
    Desc.Clear;
    If Ask = 'never' Then
      Desc.AddStrings(Diz)
    Else If (Ask = 'dizfirst') And (Diz.Count > 0) Then
      Begin
      Desc.AddStrings(Diz);
      Say(P(552, 'Description taken from the archive:') + ' ' + Clean);
      End
    Else
      Begin
      AskDescription(Clean, Desc);
      If (Desc.Count = 0) And (Diz.Count > 0) Then
        Desc.AddStrings(Diz);
      End;
    Dest := Dir + Clean;
    If Not MoveFile(Work + Name, Dest) Then
      Begin
      Say(P(547, 'The file was refused:') + ' ' + Clean);
      LogEntry.WriteEntry('Upload failed (cannot be stored): ' + Dest);
      Inc(Refused);
      Continue;
      End;
    Try
      AppendList(Dir + 'files.bbs', ListLines(Clean, Desc));
    Except
      LogEntry.WriteEntry('Upload: files.bbs of area ' + IntToStr(Area) + ' cannot be written');
    End;
    User.UpdateForUL(Size);
    Inc(Got);
    Say(P(546, 'Received:') + ' ' + Clean + ' (' + IntToStr(Size) + ')');
    LogEntry.WriteEntry('Upload: ' + Clean + ' (' + IntToStr(Size) + ' bytes) in area ' + IntToStr(Area) + ' by ' + User.GetUserName);
    End;
  If (Names.Count = 0) Or (Not Ok) And (Got = 0) Then
    Begin
    User.DisplayNewLine;
    Say(P(545, 'No file was received.'));
    End;
  If (Got > 0) And (Secs > 0) Then
    Begin
    User.AdjustTime(Secs);
    Say(P(550, 'Upload time given back (seconds):') + ' ' + IntToStr(Secs));
    End;
  Names.Free;
  Desc.Free;
  Diz.Free;
  Cfg.Free;
  CleanDir(Work);
  RmDir(ExcludeTrailingPathDelimiter(Work));
  If IoResult <> 0 Then;
  User.DisplayNewLine;
  User.PressEnter;
  User.PostStatus(uoBrowse);
  End;


End.
