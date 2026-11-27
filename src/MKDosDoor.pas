{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKDosDoor;   {Menu command 172: run a door of doors.cfg for the caller (DOORS-PLAN.md A)}

{$MODE OBJFPC}
{$H+}

{
     The menu item's data is the name of a door in doors.cfg (MKDoorCfg.pas says what it holds).  A native door is run as menu command 7 runs a
     program.  A DOS door is run in dosemu2 the way tools/mkdosdoor did: a work directory for this call (made new, deleted at the end) that has the
     files of the door's directory as links and the drop files with the COM port the door is told; dosemu2 gets that directory as its C: drive and
     its COM port connected to the pseudo terminal that DoShell makes for the caller.
}

Interface

Procedure RunDoor(DoorName: ShortString);


Implementation

Uses SysUtils, Classes, BaseUnix, Unix,
  MKDoor, MKGlobT, MKCfgAbs, MKComAbs, MKLogEnt, MKShell, MKDoorCfg, MKSandbox, MKFile, MKString, MKVCrt;


Procedure RemoveTree(Const Dir: String);
  {a directory of links and what the door made: the links are removed, not followed}
  Var
    SR: TSearchRec;
    P: String;
    St: Stat;

  Begin
  If FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If (SR.Name <> '.') And (SR.Name <> '..') Then
        Begin
        P := IncludeTrailingPathDelimiter(Dir) + SR.Name;
        If (fpLStat(P, St) = 0) And fpS_ISDIR(St.st_mode) Then
          RemoveTree(P)
        Else
          fpUnlink(P);
        End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  fpRmDir(Dir);
  End;


Procedure LinkTree(Const FromDir, ToDir: String);
  {the door's files as links, its directories as directories (what the door writes is new, what it changes and that was there is the shared file)}
  Var
    SR: TSearchRec;
    A, B: String;

  Begin
  ForceDirectories(ToDir);
  If FindFirst(IncludeTrailingPathDelimiter(FromDir) + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If (SR.Name <> '.') And (SR.Name <> '..') Then
        Begin
        A := IncludeTrailingPathDelimiter(FromDir) + SR.Name;
        B := IncludeTrailingPathDelimiter(ToDir) + SR.Name;
        If DirectoryExists(A) Then
          LinkTree(A, B)
        Else
          fpSymlink(PChar(A), PChar(B));
        End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Procedure RemoveOldWork(Const Base: String);
  {work directories of calls that ended badly (the BBS was stopped): older than a day}
  Var
    SR: TSearchRec;

  Begin
  If FindFirst(IncludeTrailingPathDelimiter(Base) + 'node*', faDirectory, SR) = 0 Then
    Begin
    Repeat
      If (SR.Attr And faDirectory) <> 0 Then
        If Now - FileDateToDateTime(SR.Time) > 1 Then
          RemoveTree(IncludeTrailingPathDelimiter(Base) + SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Procedure CopyFile(Const A, B: String);
  Var
    Src, Dst: TFileStream;

  Begin
  Try
    Src := TFileStream.Create(A, fmOpenRead Or fmShareDenyNone);
    Try
      Dst := TFileStream.Create(B, fmCreate);
      Try
        Dst.CopyFrom(Src, 0);
      Finally
        Dst.Free;
      End;
    Finally
      Src.Free;
    End;
  Except
  End;
  End;


Function NodeCommand(Const Cmd: String; Node: Integer): String;
  {*N is the node, ** a star}
  Var
    i: Integer;

  Begin
  NodeCommand := '';
  i := 1;
  While i <= Length(Cmd) Do
    Begin
    If (Cmd[i] = '*') And (i < Length(Cmd)) And (UpCase(Cmd[i + 1]) = 'N') Then
      Begin
      NodeCommand := NodeCommand + IntToStr(Node);
      Inc(i, 2);
      End
    Else If (Cmd[i] = '*') And (i < Length(Cmd)) And (Cmd[i + 1] = '*') Then
      Begin
      NodeCommand := NodeCommand + '*';
      Inc(i, 2);
      End
    Else
      Begin
      NodeCommand := NodeCommand + Cmd[i];
      Inc(i);
      End;
    End;
  End;


Var
  WrapActive: Boolean = False;         {a native door of doors.cfg is being started: its settings are used}
  WrapDoor: TDoorDef;
  WrapCfg: TDoorCfg = Nil;


Procedure AddList(L: TStrings; Const Items: TStrings);
  Var
    i: Integer;

  Begin
  If Items <> Nil Then
    For i := 0 To Items.Count - 1 Do
      L.Add(Items[i]);
  End;


Function SandboxReady(Const Mode: String; Cfg: TDoorCfg; Out Bwrap, Why: String): Boolean;
  {the sandbox is wanted (not off) and bwrap works}
  Begin
  Bwrap := FindBwrap(Cfg.SbProgram);
  SandboxReady := SandboxWorks(Bwrap, Why);
  End;


Function WorkBase(Cfg: TDoorCfg): String;
  {where the work directories and the sandbox scripts are made (private: mode 700)}
  Begin
  WorkBase := Cfg.Tmp;
  If WorkBase = '' Then
    WorkBase := GetEnvironmentVariable('MKDOS_TMP');
  If WorkBase = '' Then
    WorkBase := '/tmp/mkdosdoor-' + IntToStr(fpGetUid);
  If ForceDirectories(WorkBase) Then
    fpChmod(WorkBase, &700);
  End;


Function SandboxScript(Cfg: TDoorCfg; Node: Integer): String;
  Begin
  SandboxScript := IncludeTrailingPathDelimiter(WorkBase(Cfg)) + 'sandbox-node' + IntToStr(Node) + '.sh';
  End;


Function WrapHook(Var Cmd: ShortString; Const NodeDir: ShortString): Boolean;
  {menu command 7 / a native door of doors.cfg: the program runs in the sandbox when its settings say so}
  Var
    Cfg: TDoorCfg;
    Mode, Bwrap, Why, W: String;
    RW, RO: TStringList;

  Begin
  WrapHook := True;
  Cfg := WrapCfg;
  If Not WrapActive Then
    Begin
    Cfg := TDoorCfg.Create;
    Cfg.Load(IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'doors.cfg');
    End;
  Try
    If WrapActive Then
      Mode := WrapDoor.Sandbox
    Else
      Mode := Cfg.SbCommand7;
    If Mode = 'off' Then
      Exit;
    If Not SandboxReady(Mode, Cfg, Bwrap, Why) Then
      Begin
      LogEntry.WriteEntry('Not run (sandbox): ' + Cmd + ': ' + Why);
      WrapHook := False;
      Exit;
      End;
    RW := TStringList.Create;
    RO := TStringList.Create;
    Try
      RW.Add(NodeDir);
      AddList(RW, Cfg.SbBinds);
      AddList(RO, Cfg.SbROBinds);
      If WrapActive Then
        Begin
        If WrapDoor.Dir <> '' Then
          RW.Add(WrapDoor.Dir);
        AddList(RW, WrapDoor.Binds);
        AddList(RO, WrapDoor.ROBinds);
        End
      Else
        Begin
        W := Copy(Cmd, 1, Pos(' ', Cmd + ' ') - 1);
        If Pos('/', W) > 0 Then
          RW.Add(ExtractFilePath(W));
        End;
      W := SandboxScript(Cfg, User.GetUserLineNum);
      If SandboxWrapper(W, Bwrap, Mode, NodeDir, RW, RO) Then
        Cmd := W + ' ' + Cmd
      Else
        Begin
        LogEntry.WriteEntry('Not run (sandbox): ' + Cmd + ': cannot write ' + W);
        WrapHook := False;
        End;
    Finally
      RW.Free;
      RO.Free;
    End;
  Finally
    If Not WrapActive Then
      Cfg.Free;
  End;
  End;


Procedure Unavailable(Const Name, Why: String);
  Begin
  User.DisplayNewLine;
  User.DisplayStrLn('This door is not available.');
  LogEntry.WriteEntry('Door ' + Name + ' not run: ' + Why);
  User.PressEnter;
  End;


Procedure RunNative(Const D: TDoorDef; Cfg: TDoorCfg);
  Var
    Cmd, W, Bwrap, Why: String;

  Begin
  If D.Sandbox <> 'off' Then
    If Not SandboxReady(D.Sandbox, Cfg, Bwrap, Why) Then
      Begin
      Unavailable(D.Name, 'the sandbox: ' + Why);
      Exit;
      End;
  Cmd := Trim(D.Command);
  If (D.Dir <> '') And (Cmd <> '') Then
    Begin
    W := Copy(Cmd, 1, Pos(' ', Cmd + ' ') - 1);
    If (Pos('/', W) = 0) And (Pos('\', W) = 0) And FileExists(IncludeTrailingPathDelimiter(D.Dir) + W) Then
      Cmd := IncludeTrailingPathDelimiter(D.Dir) + Cmd;
    End;
  If DropFilesWanted(D, 'door.sys') Then
    Cmd := Cmd + ' *D';
  If DropFilesWanted(D, 'callinfo.bbs') Then
    Cmd := Cmd + ' *W';
  If DropFilesWanted(D, 'door32.sys') Then
    Cmd := Cmd + ' *3';
  If D.Freeze Then
    Cmd := Cmd + ' *!';
  If D.Raw Then
    Cmd := Cmd + ' *S';
  WrapDoor := D;
  WrapCfg := Cfg;
  WrapActive := True;
  Try
    TypeSeven(Cmd);
  Finally
    WrapActive := False;
  End;
  End;


Procedure RunDos(Const D: TDoorDef; Cfg: TDoorCfg);
  Var
    HomeDir, NodeDir, Base, Work, Dosemu, Bat, S, Cmd, Bwrap, Why: String;
    RW, RO: TStringList;
    Node: Integer;
    Error: Word;
    InNode, UsePty: Boolean;
    DoorStart: LongInt;
    Tx, Ty: Byte;
    F: Text;
    Failed: Word;

  Begin
  Node := User.GetUserLineNum;
  Dosemu := Cfg.Dosemu;
  If Dosemu = '' Then
    Dosemu := GetEnvironmentVariable('MKDOS_DOSEMU');
  If Dosemu = '' Then
    Dosemu := 'dosemu';
  If Pos('/', Dosemu) = 0 Then
    Dosemu := FSearch(Dosemu, GetEnvironmentVariable('PATH'));
  If (Dosemu = '') Or Not FileExists(Dosemu) Then
    Begin
    Unavailable(D.Name, 'dosemu2 is not installed');
    Exit;
    End;
  If (D.Dir = '') Or Not DirectoryExists(D.Dir) Then
    Begin
    Unavailable(D.Name, 'the door directory is not there: ' + D.Dir);
    Exit;
    End;
  If Trim(D.Command) = '' Then
    Begin
    Unavailable(D.Name, 'no command');
    Exit;
    End;
  If D.Sandbox <> 'off' Then
    If Not SandboxReady(D.Sandbox, Cfg, Bwrap, Why) Then
      Begin
      Unavailable(D.Name, 'the sandbox: ' + Why);
      Exit;
      End;
  Base := Cfg.Tmp;
  If Base = '' Then
    Base := GetEnvironmentVariable('MKDOS_TMP');
  If Base = '' Then
    Base := '/tmp/mkdosdoor-' + IntToStr(fpGetUid);
  If Not ForceDirectories(Base) Then
    Begin
    Unavailable(D.Name, 'cannot make ' + Base);
    Exit;
    End;
  fpChmod(Base, &700);
  RemoveOldWork(Base);
  Work := IncludeTrailingPathDelimiter(Base) + 'node' + IntToStr(Node);
  If DirectoryExists(Work) Then
    RemoveTree(Work);
  LinkTree(D.Dir, Work);
  If Not DirectoryExists(Work) Then
    Begin
    Unavailable(D.Name, 'cannot make ' + Work);
    Exit;
    End;
  User.PostStatus(uoDoor);
  {the node's directory: the drop files are written there, as for command 7}
  HomeDir := GetCurrentPath;
  NodeDir := HomeDir + 'node' + IntToStr(Node);
  InNode := False;
  If Not DirectoryExists(NodeDir) Then
    ForceDirectories(NodeDir);
  If DirectoryExists(NodeDir) Then
    Begin
    ChDir(NodeDir);
    InNode := IoResult = 0;
    End;
  Error := WriteDorInfo;
  If (Error = 0) And DropFilesWanted(D, 'door.sys') Then
    Error := WriteDoorSys;
  If (Error = 0) And DropFilesWanted(D, 'callinfo.bbs') Then
    Error := WriteCallInfo;
  If Error = 0 Then
    User.WriteExit('');
  {the drop files in the work directory, with the COM port of the door}
  If Error = 0 Then
    Begin
    If FileExists('dorinfo1.def') Then
      Begin
      fpUnlink(IncludeTrailingPathDelimiter(Work) + 'dorinfo1.def');
      CopyFile('dorinfo1.def', IncludeTrailingPathDelimiter(Work) + 'dorinfo1.def');
      SetLine(IncludeTrailingPathDelimiter(Work) + 'dorinfo1.def', 4, 'COM' + IntToStr(D.Com));
      End;
    If DropFilesWanted(D, 'door.sys') And FileExists('door.sys') Then
      Begin
      fpUnlink(IncludeTrailingPathDelimiter(Work) + 'door.sys');
      CopyFile('door.sys', IncludeTrailingPathDelimiter(Work) + 'door.sys');
      SetLine(IncludeTrailingPathDelimiter(Work) + 'door.sys', 1, 'COM' + IntToStr(D.Com) + ':');
      End;
    If DropFilesWanted(D, 'callinfo.bbs') And FileExists('callinfo.bbs') Then
      Begin
      fpUnlink(IncludeTrailingPathDelimiter(Work) + 'callinfo.bbs');
      CopyFile('callinfo.bbs', IncludeTrailingPathDelimiter(Work) + 'callinfo.bbs');
      End;
    {the batch file: DOS's command line as the sysop wrote it}
    Bat := IncludeTrailingPathDelimiter(Work) + 'mkdoor.bat';
    fpUnlink(Bat);
    AssignFile(F, Bat);
    ReWrite(F);
    Write(F, '@echo off'#13#10);
    If D.SubDir <> '' Then
      Begin
      S := D.SubDir;
      While Pos('/', S) > 0 Do
        S[Pos('/', S)] := '\';
      Write(F, 'cd ' + S + #13#10);
      End;
    Write(F, NodeCommand(D.Command, Node) + #13#10);
    CloseFile(F);
    End;
  Failed := 0;
  If Error = 0 Then
    Begin
    DoorRaw := False;
    UsePty := DoorPtyWanted;
    If Not UsePty Then
      CommRelease;
    DoorStart := User.CurrentTime;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(085));
    LogEntry.WriteEntry('Door : ' + D.Name);
    Tx := WhereX;
    Ty := WhereY;
    Cmd := Dosemu + ' -dumb -quiet -K "' + Work + '" -I "serial { virtual com ' + IntToStr(D.Com) + ' }" -E mkdoor.bat';
    If D.Sandbox <> 'off' Then
      Begin
      RW := TStringList.Create;
      RO := TStringList.Create;
      Try
        RW.Add(Work);
        RW.Add(NodeDir);
        RW.Add(D.Dir);
        AddList(RW, Cfg.SbBinds);
        AddList(RW, D.Binds);
        AddList(RO, Cfg.SbROBinds);
        AddList(RO, D.ROBinds);
        If Copy(Dosemu, 1, 5) <> '/usr/' Then
          RO.Add(ExtractFilePath(Dosemu));
        If SandboxWrapper(SandboxScript(Cfg, Node), Bwrap, D.Sandbox, NodeDir, RW, RO) Then
          Cmd := SandboxScript(Cfg, Node) + ' ' + Cmd
        Else
          Failed := 8;
      Finally
        RW.Free;
        RO.Free;
      End;
      End;
    If Failed = 0 Then
      Begin
      DoShell(Cmd, False, False);
      Failed := ShellError;
      End;
    If D.Freeze Then
      User.AdjustTime(User.CurrentTime - DoorStart);
    GoToXY(1, 1);
    If (CurrentPort <> 0) And Not UsePty Then
      Begin
      CommInit;
      CommFlow(fcBoth);
      End;
    GoToXY(Tx, Ty);
    User.ReadExit('');
    End;
  If InNode Then
    Begin
    ChDir(ExcludeTrailingPathDelimiter(HomeDir));
    If IoResult <> 0 Then;
    End;
  RemoveTree(Work);
  If (Failed <> 0) Or (Error <> 0) Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn('Error: the door ' + D.Name + ' could not be run');
    LogEntry.WriteEntry('Door failed (' + IntToStr(Failed) + '/' + IntToStr(Error) + ') : ' + D.Name);
    User.PressEnter;
    End;
  End;


Procedure RunDoor(DoorName: ShortString);
  Var
    Cfg: TDoorCfg;
    i: Integer;
    Name: String;

  Begin
  Name := Trim(DoorName);
  If Pos(' ', Name) > 0 Then
    Name := Copy(Name, 1, Pos(' ', Name) - 1);
  Cfg := TDoorCfg.Create;
  Try
    Cfg.Load(IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'doors.cfg');
    i := Cfg.Find(Name);
    If i < 0 Then
      Unavailable(Name, 'not in doors.cfg')
    Else If Cfg.Doors[i].Kind = 'native' Then
      RunNative(Cfg.Doors[i], Cfg)
    Else
      RunDos(Cfg.Doors[i], Cfg);
  Finally
    Cfg.Free;
  End;
  End;


Initialization
  ShellWrapHook := @WrapHook;

End.
