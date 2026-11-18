Unit MKOffXfer;      {offline mail: running the packers and the file transfer programs}

{$I MKB.Def}

{
     MKOffXfer - the external programs of the offline mail of a caller, for mk (MKOfflin) and for the offline mail
     door (MKQwkO).  They take the command lines as they are given (the settings are not read here):

       OffExpand    %F the file name, %B the baud rate of the caller, %L the locked baud rate (given), %P the port,
                    %N the name of the caller, %% a percent sign
       OffVerify    the size of the packet and "do you want it"
       OffRun       a packer: runs the program of CmdLine in WorkDir with Tail after the arguments of the command line
       OffTransfer  a file transfer program: it gets the connection of the caller as it is (no pseudo terminal)
       OffSplitProt a protocol is "send command | receive command" (the first part when there is no |)

     The first word of a command line is the program.  A name with a directory (a backslash is taken for a slash) is
     used as it is, relative to Base, a name without one is looked for in the PATH.  Programs are not run
     through a shell.  The result is True when the program ran and ended with 0.
}


Interface

Uses MKOffAbs;


Function OffExpand(PStr: String; FileName: String; Port: Word; LockedBaud: LongInt): String;
Function OffSplitProt(Cmd: String; Send: Boolean): String;
Function OffProgram(CmdLine: String; Base: String; Var Prog: String; Var Args: String): Boolean;
  {Prog is the full name of the program of CmdLine, Args the rest; False when there is no such program}
Function OffRun(CmdLine: String; Base: String; WorkDir: String; Tail: String): Boolean;
Function OffTransfer(CmdLine: String; Base: String; WorkDir: String): Boolean;
Type OffCmdList = Array[1..11] Of String[143];
Procedure OffRenameUploads(WorkPath: String);
  {what a protocol received in WorkPath is renamed upload.1, upload.2 ...: a name of the caller must not look like an option}
Function OffUnpackReply(Offline: AbsOffPtr; WorkPath: String; Base: String; Var Cmds: OffCmdList; Num: Word): Boolean;
  {True when <BBSID>.MSG (Offline^.GetExtractSpec) is in WorkPath: it was received as it is, or it comes out of one of the
   files (upload.N) when the unpack commands Cmds[1..Num] are tried in turn}
Function OffVerify(Archive: String): Boolean;
  {tells the caller how big the packet is and asks whether he wants it}
Function OffFindNoCase(Dir: String; Name: String): String;
  {the full path of a file in Dir whatever case its name is in ('' = none): names in packets are the sender's}


Implementation


Uses MKString, MKFile, MKDos, MKDoor, MKComAbs,
  Dos;


Function UnixPath(S: String): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    If S[i] = '\' Then
      S[i] := '/';
  UnixPath := S;
  End;


Function OffExpand(PStr: String; FileName: String; Port: Word; LockedBaud: LongInt): String;
  Var
    i: Word;
    TStr: String;
    HavePercent: Boolean;

  Begin
  TStr := '';
  HavePercent := False;
  For i := 1 To Length(PStr) Do
    Begin
    If Not HavePercent Then
      Begin
      If PStr[i] = '%' Then
        HavePercent := True
      Else
        TStr := TStr + PStr[i];
      End
    Else
      Begin
      HavePercent := False;
      Case UpCase(PStr[i]) Of
        '%': TStr := TStr + '%';
        'P': TStr := TStr + Long2Str(Port);
        'B': TStr := TStr + Long2Str(User.GetUserBaud);
        'F': TStr := TStr + FileName;
        'L': If LockedBaud = 0 Then
               TStr := TStr + Long2Str(User.GetUserBaud)
             Else
               TStr := TStr + Long2Str(LockedBaud);
        'N': TStr := TStr + User.GetUserName;
        Else TStr := TStr + '%' + PStr[i];
        End;
      End;
    End;
  If HavePercent Then
    TStr := TStr + '%';
  OffExpand := TStr;
  End;


Function OffSplitProt(Cmd: String; Send: Boolean): String;
  Var
    P: Word;

  Begin
  P := Pos('|', Cmd);
  If P = 0 Then
    Begin
    If Send Then
      OffSplitProt := StripBoth(Cmd, ' ')
    Else
      OffSplitProt := '';
    End
  Else If Send Then
    OffSplitProt := StripBoth(Copy(Cmd, 1, P - 1), ' ')
  Else
    OffSplitProt := StripBoth(Copy(Cmd, P + 1, 255), ' ');
  End;


Function OffProgram(CmdLine: String; Base: String; Var Prog: String; Var Args: String): Boolean;
  Var
    TmpStr, First: String;
    Cur: String;

  Begin
  OffProgram := False;
  Prog := '';
  Args := '';
  TmpStr := StripBoth(CmdLine, ' ');
  If TmpStr = '' Then
    Exit;
  First := ExtractWord(TmpStr, 1);
  Args := StripBoth(Copy(TmpStr, Length(First) + 1, 255), ' ');
  First := UnixPath(First);
  If (Pos('/', First) = 0) And (Pos(':', First) = 0) Then
    Begin
    If Not FindOnPath(First, Prog) Then
      Exit;
    Prog := FExpand(Prog);
    End
  Else
    Begin
    Prog := First;
    If (Base <> '') And (First[1] <> '/') Then
      Prog := WithBackSlash(Base) + First;
    End;
  OffProgram := FileExist(Prog);
  End;


Function Ran: Boolean;
  Begin
  Ran := (GetResultCode = 0) And (ShellError = 0);
  End;


Function OffRun(CmdLine: String; Base: String; WorkDir: String; Tail: String): Boolean;
  Var
    Prog, Args, Cur: String;

  Begin
  OffRun := False;
  If Not OffProgram(CmdLine, Base, Prog, Args) Then
    Exit;
  GetDir(0, Cur);
  ChDir(StripTrail(WorkDir, '/'));
  If IoResult = 0 Then
    Begin
    DoShell(Prog + ' ' + Args + ' ' + Tail, True, False);
    OffRun := Ran;
    End;
  ChDir(Cur);
  If IoResult <> 0 Then;
  End;


Function OffTransfer(CmdLine: String; Base: String; WorkDir: String): Boolean;
  Var
    Prog, Args, Cur: String;

  Begin
  OffTransfer := False;
  If Not OffProgram(CmdLine, Base, Prog, Args) Then
    Exit;
  GetDir(0, Cur);
  ChDir(StripTrail(WorkDir, '/'));
  If IoResult = 0 Then
    Begin
    {a file transfer program needs the caller's connection as it is: no pseudo terminal}
    CommRelease;
    DoorRaw := True;
    DoShell(Prog + ' ' + Args, True, False);
    DoorRaw := False;
    CommInit;
    OffTransfer := Ran;
    End;
  ChDir(Cur);
  If IoResult <> 0 Then;
  End;


Procedure OffRenameUploads(WorkPath: String);
  Var
    Names: Array[1..60] Of String[128];
    NumNames, i, Next: Word;
    FI: FindObj;
    UpFile: File;

  Begin
  NumNames := 0;
  Next := 1;
  FI.Init;
  FI.FFirst(WithBackSlash(WorkPath) + '*');
  While FI.Found And (NumNames < 60) Do
    Begin
    If Copy(FI.GetName, 1, 7) <> 'upload.' Then
      Begin
      Inc(NumNames);
      Names[NumNames] := FI.GetName;
      End
    Else
      Inc(Next);
    FI.FNext;
    End;
  FI.Done;
  For i := 1 To NumNames Do
    Begin
    Assign(UpFile, WithBackSlash(WorkPath) + Names[i]);
    Rename(UpFile, WithBackSlash(WorkPath) + 'upload.' + Long2Str(Next));
    If IoResult <> 0 Then;
    Inc(Next);
    End;
  End;


Function OffUnpackReply(Offline: AbsOffPtr; WorkPath: String; Base: String; Var Cmds: OffCmdList; Num: Word): Boolean;
  Var
    Archives: Array[1..60] Of String[128];
    NumArc, i, k: Word;
    FI: FindObj;

  Begin
  OffUnpackReply := True;
  If OffFindNoCase(WorkPath, Offline^.GetExtractSpec) <> '' Then
    Exit;
  NumArc := 0;
  FI.Init;
  FI.FFirst(WithBackSlash(WorkPath) + 'upload.*');
  While FI.Found And (NumArc < 60) Do
    Begin
    Inc(NumArc);
    Archives[NumArc] := FI.GetName;
    FI.FNext;
    End;
  FI.Done;
  For i := 1 To NumArc Do
    For k := 1 To Num Do
      If (OffFindNoCase(WorkPath, Offline^.GetExtractSpec) = '') And
         (Length(StripBoth(Cmds[k], ' ')) > 0) Then
        Begin
        User.DisplayStrLn(Prompts.GetString(188));
        If OffRun(Cmds[k], Base, WorkPath, Archives[i]) Then;
        End;
  OffUnpackReply := OffFindNoCase(WorkPath, Offline^.GetExtractSpec) <> '';
  End;


Function OffVerify(Archive: String): Boolean;
  Var
    Yes: Boolean;

  Begin
  User.DisplayNewLine;
  User.DisplayStrLn(Prompts.GetString(179) + ' ' + Long2Str(SizeFile(Archive)));
  Yes := True;
  User.AskYN(Prompts.GetString(166), Yes);
  OffVerify := Yes;
  End;


Function OffFindNoCase(Dir: String; Name: String): String;
  Var
    FI: FindObj;
    Res: String;

  Begin
  Res := '';
  FI.Init;
  FI.FFirst(WithBackSlash(Dir) + '*');
  While FI.Found And (Res = '') Do
    Begin
    If Lower(FI.GetName) = Lower(Name) Then
      Res := FI.GetFullPath;
    FI.FNext;
    End;
  FI.Done;
  OffFindNoCase := Res;
  End;


End.
