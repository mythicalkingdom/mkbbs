{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKHubExec;      {the exec transport of a QWK hub: run a program of the sysop, without a shell, with a time limit}

{$I MKB.Def}

{
     For a hub that is not reached by a Telnet menu (FTP, SFTP, HTTP, rsync ...) the map file names programs that move the
     files (see QWK-HUB-PLAN.md, NETWORKING.md):

       transport  exec
       get        /usr/local/bin/qwk-get.sh %id% %qwk%
       put        /usr/local/bin/qwk-put.sh %id% %rep%

     HubExecRun takes the line, splits it into words (a word can be "in quotes"; \" and \\ are taken in a quoted word), replaces
     %name% in every word with the variable of that name (HubExecVar; %% is a percent sign) and runs the program with the
     words as its arguments: no shell, so a name with a space or a ; in it is just an argument.  The environment is the one of
     this program plus the ones set with HubExecEnv (the password of the hub goes there, not on the command line: ps shows
     command lines).  The standard output and error of the program are returned in Output (at most 60000 bytes).  A program
     that is still running after Secs seconds is killed (with the processes it started).

       Result  >= 0   the exit status of the program;  -1  it could not be started (Output says why);  -2  killed: too slow
}

Interface

Function HubExecRun(Line, Dir: String; Secs: LongInt; Var Output: AnsiString): LongInt;
Procedure HubExecVar(Name, Value: String);      {%name% in the words}
Procedure HubExecEnv(Name, Value: String);      {an environment variable of the program}
Procedure HubExecClear;                         {forget all of the above}
Function HubExecWords(Line: String; Var Words: Array Of String; Max: Word): Word; {the words of a line (no variables replaced)}


Implementation

Uses BaseUnix, Unix, SysUtils;

Const
  MaxVars = 30;
  MaxOut = 60000;

Var
  VarName, VarVal: Array[1..MaxVars] Of String[20];
  VarText: Array[1..MaxVars] Of String;
  NumVars: Word;
  EnvName: Array[1..MaxVars] Of String[40];
  EnvVal: Array[1..MaxVars] Of String;
  NumEnv: Word;


Procedure HubExecClear;
  Begin
  NumVars := 0;
  NumEnv := 0;
  End;


Procedure HubExecVar(Name, Value: String);
  Var
    i: Word;

  Begin
  Name := LowerCase(Name);
  For i := 1 To NumVars Do
    If VarName[i] = Name Then
      Begin
      VarText[i] := Value;
      Exit;
      End;
  If NumVars < MaxVars Then
    Begin
    Inc(NumVars);
    VarName[NumVars] := Name;
    VarText[NumVars] := Value;
    End;
  End;


Procedure HubExecEnv(Name, Value: String);
  Var
    i: Word;

  Begin
  For i := 1 To NumEnv Do
    If EnvName[i] = Name Then
      Begin
      EnvVal[i] := Value;
      Exit;
      End;
  If NumEnv < MaxVars Then
    Begin
    Inc(NumEnv);
    EnvName[NumEnv] := Name;
    EnvVal[NumEnv] := Value;
    End;
  End;


Function HubExecWords(Line: String; Var Words: Array Of String; Max: Word): Word;
  Var
    i, N: Word;
    W: String;
    InWord, Quoted: Boolean;
    C: Char;

  Begin
  N := 0;
  i := 1;
  While i <= Length(Line) Do
    Begin
    While (i <= Length(Line)) And (Line[i] In [' ', #9]) Do
      Inc(i);
    If i > Length(Line) Then
      Break;
    W := '';
    InWord := True;
    Quoted := False;
    While InWord And (i <= Length(Line)) Do
      Begin
      C := Line[i];
      If Quoted Then
        Begin
        If (C = '\') And (i < Length(Line)) And (Line[i + 1] In ['"', '\']) Then
          Begin
          Inc(i);
          W := W + Line[i];
          End
        Else If C = '"' Then
          Quoted := False
        Else
          W := W + C;
        End
      Else If C = '"' Then
        Quoted := True
      Else If C In [' ', #9] Then
        InWord := False
      Else
        W := W + C;
      Inc(i);
      End;
    If N < Max Then
      Begin
      Words[N] := W;
      Inc(N);
      End;
    End;
  HubExecWords := N;
  End;


Function Subst(S: String): String;
  Var
    R, Name: String;
    i, j, k: Word;
    Found: Boolean;

  Begin
  R := '';
  i := 1;
  While i <= Length(S) Do
    Begin
    If S[i] = '%' Then
      Begin
      If (i < Length(S)) And (S[i + 1] = '%') Then
        Begin
        R := R + '%';
        Inc(i, 2);
        Continue;
        End;
      j := i + 1;
      While (j <= Length(S)) And (S[j] <> '%') Do
        Inc(j);
      If j <= Length(S) Then
        Begin
        Name := LowerCase(Copy(S, i + 1, j - i - 1));
        Found := False;
        For k := 1 To NumVars Do
          If VarName[k] = Name Then
            Begin
            R := R + VarText[k];
            Found := True;
            End;
        If Found Then
          Begin
          i := j + 1;
          Continue;
          End;
        End;
      End;
    R := R + S[i];
    Inc(i);
    End;
  Subst := R;
  End;


Function FindProgram(Name, Dir: String): String;
  {a name with a / is used as it is (relative to Dir); a bare name is looked for in PATH}
  Var
    P, D: String;
    i: Word;

  Begin
  FindProgram := Name;
  If Pos('/', Name) > 0 Then
    Begin
    If (Name[1] <> '/') And (Dir <> '') Then
      FindProgram := IncludeTrailingPathDelimiter(Dir) + Name;
    Exit;
    End;
  P := GetEnvironmentVariable('PATH') + ':';
  While P <> '' Do
    Begin
    i := Pos(':', P);
    D := Copy(P, 1, i - 1);
    Delete(P, 1, i);
    If D = '' Then
      D := '.';
    If FileExists(IncludeTrailingPathDelimiter(D) + Name) Then
      Begin
      FindProgram := IncludeTrailingPathDelimiter(D) + Name;
      Exit;
      End;
    End;
  End;


Function HubExecRun(Line, Dir: String; Secs: LongInt; Var Output: AnsiString): LongInt;
  Var
    W: Array[0..39] Of String;
    N, i: Word;
    Prog: String;
    Argv, Envv: Array[0..79] Of PChar;
    ArgS: Array[0..39] Of AnsiString;
    EnvS: Array[0..79] Of AnsiString;
    NE, k: Word;
    Pipe: TFilDes;
    Pid: TPid;
    Buf: Array[0..4095] Of Char;
    Rd, Status, Waited: LongInt;
    P: TPollFd;
    Deadline: Int64;
    Done, TimedOut, Reaped: Boolean;

  Begin
  Output := '';
  HubExecRun := -1;
  N := HubExecWords(Line, W, 39);
  If N = 0 Then
    Begin
    Output := 'no command';
    Exit;
    End;
  For i := 0 To N - 1 Do
    ArgS[i] := Subst(W[i]);
  Prog := FindProgram(ArgS[0], Dir);
  If Not FileExists(Prog) Then
    Begin
    Output := 'cannot run ' + Prog + ': no such file';
    Exit;
    End;
  If fpAccess(Prog, X_OK) <> 0 Then
    Begin
    Output := 'cannot run ' + Prog + ': not executable';
    Exit;
    End;
  ArgS[0] := Prog;
  For i := 0 To N - 1 Do
    Argv[i] := PChar(ArgS[i]);
  Argv[N] := Nil;
  NE := 0;
  For k := 1 To GetEnvironmentVariableCount Do
    If NE < 60 Then
      Begin
      EnvS[NE] := GetEnvironmentString(k);
      Inc(NE);
      End;
  For k := 1 To NumEnv Do
    Begin
    EnvS[NE] := EnvName[k] + '=' + EnvVal[k];
    Inc(NE);
    End;
  For k := 0 To NE - 1 Do
    Envv[k] := PChar(EnvS[k]);
  Envv[NE] := Nil;
  If fpPipe(Pipe) <> 0 Then
    Begin
    Output := 'no pipe';
    Exit;
    End;
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    fpClose(Pipe[0]);
    fpClose(Pipe[1]);
    Output := 'cannot fork';
    Exit;
    End;
  If Pid = 0 Then
    Begin
    fpSetsid;                            {its own group: a time out kills what it started, too}
    fpClose(Pipe[0]);
    fpDup2(Pipe[1], 1);
    fpDup2(Pipe[1], 2);
    If Pipe[1] > 2 Then
      fpClose(Pipe[1]);
    k := fpOpen('/dev/null', O_RDONLY);
    If k <> 0 Then
      Begin
      fpDup2(k, 0);
      If k > 2 Then
        fpClose(k);
      End;
    If Dir <> '' Then
      If fpChdir(Dir) <> 0 Then;
    fpExecve(Prog, PPChar(@Argv[0]), PPChar(@Envv[0]));
    fpExit(127);
    End;
  fpClose(Pipe[1]);
  Deadline := Int64(GetTickCount64) + Int64(Secs) * 1000;
  TimedOut := False;
  Reaped := False;
  Done := False;
  While Not Done Do
    Begin
    P.fd := Pipe[0];
    P.events := POLLIN;
    P.revents := 0;
    Rd := fpPoll(@P, 1, 500);
    If Rd > 0 Then
      Begin
      Rd := fpRead(Pipe[0], Buf, SizeOf(Buf));
      If Rd <= 0 Then
        Done := True
      Else If Length(Output) < MaxOut Then
        Begin
        k := Length(Output);
        SetLength(Output, k + Rd);
        Move(Buf, Output[k + 1], Rd);
        End;
      End;
    If (Not Done) And (Rd = 0) And (Not Reaped) Then
      If fpWaitPid(Pid, Status, WNOHANG) = Pid Then
        Begin
        Reaped := True;                  {it has ended and said all it had: a child it left must not keep us}
        Done := True;
        End;
    If (Not Done) And (Int64(GetTickCount64) > Deadline) Then
      Begin
      TimedOut := True;
      fpKill(-Pid, SIGKILL);
      fpKill(Pid, SIGKILL);
      Done := True;
      End;
    End;
  fpClose(Pipe[0]);
  If Not Reaped Then
    Repeat
      Waited := fpWaitPid(Pid, Status, 0);
    Until (Waited = Pid) Or ((Waited < 0) And (fpGetErrno <> ESysEINTR));
  If TimedOut Then
    HubExecRun := -2
  Else If wifexited(Status) Then
    HubExecRun := wexitstatus(Status)
  Else
    HubExecRun := -1;
  End;


Begin
HubExecClear;
End.
