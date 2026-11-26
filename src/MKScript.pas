Unit MKScript;   {mk -x script: a BASIC or Pascal program of the sysop that uses the BBS, with no caller (MHOST-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
     mk -x <script> [arguments]            mk -x -C "users:read nodes:read" script.bas      mk -x -T 30 script.pas
     (the BBS directory is MK as for every program; MKRUN is the run directory)

  The script is a .bas (BASIC) or .pas (Pascal) file.  What it may ask the BBS is the list of capabilities of its entry in extensions.cfg; a script that is in no entry gets every read
  capability, and -C gives another list.  It runs on a node of its own (a "script node": numbers from MKSCRIPTNODES, default 101-108, so it never takes a caller's node): a node file in the
  run directory and a line in useron.bbs make it show on the node list and in mkmon.  Its output goes to standard output, INPUT / ReadLn read standard input.
  The exit code: 0 the program ended, 1 it ended with an error or a limit, 2 it could not be started (not found, a kind that is not built in, refused: no free script node).
  The commands of the BBS are in MKHost.pas.
}

Interface

Uses Classes;

Function ScriptPickNode: Integer;
  {a free script node (the node file of the run directory is made); 0: no run directory, -1: all script nodes are in use}

Function ScriptRun(Const Script: String; ScriptArgs: TStringList; Const CapsOpt: String; TimeoutOpt: LongInt): Integer;

Procedure ScriptFinish;
  {remove the node file}

Function ScriptShortName(Const Script: String): String;
  {the name of a script without its folder and its extension: what the node list says}

Implementation

Uses SysUtils, Math, BaseUnix, MKHost, MKExtCfg, MKCfgAbs, MKLogEnt, MKDoor, MKGlobT
{$IFDEF MKBASIC}, BasicNum, BasicFiles, BasicTerm, BasicConsole, Basic{$ENDIF}
{$IFDEF MKPASCAL}, mkp_harness, mkpascal{$ENDIF};

Var
  NodeFile: String;


Function Alive(Pid: LongInt): Boolean;
  Begin
  Result := (Pid > 0) And ((fpKill(Pid, 0) = 0) Or (fpGetErrno = ESysEPERM));
  End;


Function ScriptPickNode: Integer;
  Var
    RunDir, R: String;
    First, Last, N, Pid, p: Integer;
    L: TStringList;
    Fd: LongInt;
    Info: String;

  Begin
  Result := 0;
  RunDir := GetEnvironmentVariable('MKRUN');
  If RunDir = '' Then
    Exit;
  R := GetEnvironmentVariable('MKSCRIPTNODES');
  If R = '' Then
    R := '101-108';
  p := Pos('-', R);
  If p = 0 Then
    Begin
    First := StrToIntDef(R, 101);
    Last := First;
    End
  Else
    Begin
    First := StrToIntDef(Copy(R, 1, p - 1), 101);
    Last := StrToIntDef(Copy(R, p + 1, 9), First);
    End;
  Result := -1;
  For N := First To Last Do
    Begin
    NodeFile := RunDir + '/node' + IntToStr(N) + '.info';
    If FileExists(NodeFile) Then
      Begin
      L := TStringList.Create;
      Pid := 0;
      Try
        L.LoadFromFile(NodeFile);
        Pid := StrToIntDef(L.Values['pid'], 0);
      Except
        Pid := 0;
      End;
      L.Free;
      If Alive(Pid) Then
        Continue;
      DeleteFile(NodeFile);               {left by a script that is gone}
      End;
    Info := 'node=' + IntToStr(N) + #10 + 'pid=' + IntToStr(fpGetPid) + #10 + 'port=0' + #10 + 'type=script' + #10 + 'baud=0' + #10 + 'addr=script' + #10 +
      'start=' + IntToStr(fpTime) + #10;
    Fd := fpOpen(NodeFile, O_WRONLY Or O_CREAT Or O_EXCL, &644);
    If Fd < 0 Then
      Continue;                           {another script took it in the meantime}
    fpWrite(Fd, Info[1], Length(Info));
    fpClose(Fd);
    Exit(N);
    End;
  NodeFile := '';
  End;


Function ScriptShortName(Const Script: String): String;
  Begin
  Result := Copy(ChangeFileExt(ExtractFileName(Script), ''), 1, 22);
  End;


Procedure ScriptFinish;
  Begin
  If NodeFile <> '' Then
    DeleteFile(NodeFile);
  NodeFile := '';
  End;


Procedure Say(Const S: String);
  Begin
  WriteLn(StdErr, S);
  End;


Function ReadAll(Const FN: String; Out S: String): Boolean;
  Var
    L: TStringList;

  Begin
  Result := False;
  S := '';
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(FN);
      S := L.Text;
      Result := True;
    Except
    End;
  Finally
    L.Free;
  End;
  End;


{$IFDEF MKBASIC}
Type
  TBasicScriptTerm = Class(BasicConsole.TConsoleTerm)
  Public
    Host: THost;
    Function HostCall(Const cmd: AnsiString; Out err: AnsiString): AnsiString; Override;
  End;


Function TBasicScriptTerm.HostCall(Const cmd: AnsiString; Out err: AnsiString): AnsiString;
  Begin
  Result := Host.Call(cmd, err);
  End;
{$ENDIF}

{$IFDEF MKPASCAL}
Type
  TPasScriptTerm = Class(mkp_harness.TConsoleTerm)
  Public
    Host: THost;
    Function HostCall(Const Cmd: RawByteString; Out Err: String): RawByteString; Override;
  End;


Function TPasScriptTerm.HostCall(Const Cmd: RawByteString; Out Err: String): RawByteString;
  Var
    E: String;

  Begin
  Result := Host.Call(Cmd, E);
  Err := E;
  End;
{$ENDIF}


Function ScriptRun(Const Script: String; ScriptArgs: TStringList; Const CapsOpt: String; TimeoutOpt: LongInt): Integer;
  Var
    Full, Text, Ext, Caps, Name: String;
    Cfg: TExtCfg;
    E: Integer;
    Timeout: LongInt;
    Host: THost;
    CapList: TStringList;
    i: Integer;
{$IFDEF MKBASIC}
    BTerm: TBasicScriptTerm;
    B: TBasic;
    BStatus: AnsiString;
    Lim: TBasicLimits;
    OldMask: TFPUExceptionMask;
{$ENDIF}
{$IFDEF MKPASCAL}
    PTerm: TPasScriptTerm;
    PFiles: TDiskFiles;
    PSession: TMKSession;
    PStatus: TMKRunStatus;
{$ENDIF}

  Begin
  Result := 2;
  Full := ExpandFileName(Script);
  If Not FileExists(Full) Then
    Full := Config^.GetBbsPath + Script;
  If Not FileExists(Full) Then
    Begin
    Say('mk -x: ' + Script + ' is not there');
    Exit;
    End;
  Full := ExpandFileName(Full);
  Ext := LowerCase(ExtractFileExt(Full));
  If (Ext <> '.bas') And (Ext <> '.pas') Then
    Begin
    Say('mk -x: ' + Script + ': a script is a .bas (BASIC) or a .pas (Pascal) file');
    Exit;
    End;
  If Not ReadAll(Full, Text) Then
    Begin
    Say('mk -x: ' + Script + ' cannot be read');
    Exit;
    End;
  Cfg := TExtCfg.Create(Config^.GetBbsPath);
  Cfg.Load;
  E := Cfg.FindFile(Full);
  Timeout := 60;
  If E >= 0 Then
    Begin
    Name := Cfg.Entries[E].Name;
    Caps := Cfg.Entries[E].Caps;
    Timeout := Cfg.Entries[E].Timeout;
    End
  Else
    Begin
    Name := ChangeFileExt(ExtractFileName(Full), '');
    Caps := HostAllReads;
    End;
  If CapsOpt <> '' Then
    Caps := CapsOpt;
  If TimeoutOpt >= 0 Then
    Timeout := TimeoutOpt;
  Cfg.Free;
  CapList := HostCaps(Caps);
  Host := THost.Create(Name, CapList);
  Host.SetScriptArgs(ScriptArgs);
  CapList.Free;
  LogEntry.WriteEntry('Ext ' + Name + ': run ' + Full + ' (' + Copy(Caps, 1, 120) + ')');
  Result := 1;
  Try
    If Ext = '.bas' Then
      Begin
{$IFDEF MKBASIC}
      BTerm := TBasicScriptTerm.Create;
      BTerm.Host := Host;
      BTerm.Echo := False;
      B := TBasic.Create(BTerm, TDirFiles.Create(ExtractFileDir(Full)), True);
      Try
        B.Locked := True;
        B.SystemMode := smEnd;
        B.RandomizeMode := rmClock;
        Lim := B.Limits;
        Lim.MaxRuntimeMs := Timeout * 1000;
        B.Limits := Lim;
        OldMask := GetExceptionMask;
        MaskFloatExceptions;
        Try
          If B.LoadProgramText(Text, False) Then
            BStatus := B.RunLocked(-1)
          Else
            BStatus := 'load';
        Finally
          SetExceptionMask(OldMask);
        End;
        If (BStatus = 'end') Or (BStatus = 'stop') Or (BStatus = 'system') Then
          Result := 0;
        LogEntry.WriteEntry('Ext ' + Name + ': ended (' + BStatus + ')');
      Finally
        B.Free;
        BTerm.Free;
      End;
{$ELSE}
      Say('mk -x: BASIC is not built into this mk');
      Result := 2;
{$ENDIF}
      End
    Else
      Begin
{$IFDEF MKPASCAL}
      PTerm := TPasScriptTerm.Create;
      PTerm.Host := Host;
      PFiles := TDiskFiles.Create(ExtractFileDir(Full));
      PSession := TMKSession.Create(PTerm, PFiles);
      Try
        PSession.MaxRuntimeMs := Timeout * 1000;
        For i := 1 To ScriptArgs.Count - 1 Do
          PSession.Params.Add(ScriptArgs[i]);
        If PSession.LoadSource(Text) Then
          Begin
          PStatus := PSession.Run;
          If PStatus In [rsEnd, rsHalt] Then
            Result := 0;
          LogEntry.WriteEntry('Ext ' + Name + ': ended (' + IntToStr(Ord(PStatus)) + ')');
          End
        Else
          Begin
          Say(PSession.LastError);
          LogEntry.WriteEntry('Ext ' + Name + ': compile error: ' + PSession.LastError);
          End;
      Finally
        PSession.Free;
        PFiles.Free;
        PTerm.Free;
      End;
{$ELSE}
      Say('mk -x: Pascal is not built into this mk');
      Result := 2;
{$ENDIF}
      End;
  Finally
    Host.Free;
  End;
  End;


End.
