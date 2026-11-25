Unit MKSandbox;   {the door sandbox: bubblewrap (DOORS-PLAN.md C)}

{$MODE OBJFPC}
{$H+}

{
     A door is somebody else's program that runs with the rights of the BBS user.  This unit builds the command line that runs it in bubblewrap (bwrap) instead:

       no network (mode default; mode net leaves the network, with the name resolution files), its own process numbers, IPC and host name, a /tmp of its own
       (empty, gone with the call), /usr read only with the usual links (/bin /lib /lib64), /proc and /dev of its own, no capabilities,
       and of the rest of the system only what is named: the directories that are bound with write access (the node directory, the door's directory, the work
       directory of a DOS door, more with bind = in doors.cfg) and those that are read only (robind =).  The program ends when mk ends (--die-with-parent).

     The terminal is not changed: no --new-session, the pseudo terminal that DoShell makes is the terminal of the program as before.
     Without a working bwrap there is no sandbox (SandboxWorks says why); what the caller then gets is decided by the one who asks (a door that wants one is not run).
}

Interface

Uses Classes;

Function FindBwrap(Const Configured: String): String;
  {the program: the configured path, or bwrap on the PATH; '' when there is none}

Function SandboxWorks(Const Bwrap: String; Out Why: String): Boolean;
  {bwrap can make its namespaces here (a short test run, once for each process and program)}

Function SandboxWrapper(Const ScriptPath, Bwrap, Mode, ChDir: String; RW, RO: TStrings): Boolean;
  {writes a shell script that runs its arguments in the sandbox:  <ScriptPath> program arguments...  (a command line given to DoShell is limited to 255
   characters, the options of bwrap are longer).  Only directories that exist are bound (bwrap refuses a missing one).  Mode: default (no network) or net.}

Function QuoteArg(Const S: String): String;


Implementation

Uses SysUtils, Process, BaseUnix;

Var
  TestedFor: String = '-';
  TestOk: Boolean = False;
  TestWhy: String = '';


Function QuoteArg(Const S: String): String;
  Begin
  If (S <> '') And (Pos(' ', S) = 0) And (Pos('"', S) = 0) And (Pos(#9, S) = 0) Then
    QuoteArg := S
  Else
    QuoteArg := '"' + S + '"';
  End;


Function FindBwrap(Const Configured: String): String;
  Begin
  FindBwrap := '';
  If Configured <> '' Then
    Begin
    If FileExists(Configured) Then
      FindBwrap := Configured;
    Exit;
    End;
  FindBwrap := FileSearch('bwrap', GetEnvironmentVariable('PATH'));
  End;


Function SandboxWorks(Const Bwrap: String; Out Why: String): Boolean;
  Var
    S: String;

  Begin
  If TestedFor <> Bwrap Then
    Begin
    TestedFor := Bwrap;
    TestOk := False;
    If Bwrap = '' Then
      TestWhy := 'bwrap (bubblewrap) is not installed'
    Else
      Begin
      Try
        If RunCommand(Bwrap, ['--ro-bind', '/usr', '/usr', '--symlink', 'usr/bin', '/bin', '--symlink', 'usr/lib', '/lib', '--symlink', 'usr/lib64', '/lib64',
             '--unshare-net', '--unshare-pid', '--', '/usr/bin/true'], S) Then
          TestOk := True
        Else
          TestWhy := 'bwrap cannot make a sandbox here: ' + Trim(S);
      Except
        TestWhy := 'bwrap could not be run';
      End;
      End;
    End;
  Why := TestWhy;
  SandboxWorks := TestOk;
  End;


Function ShQuote(Const S: String): String;
  Begin
  ShQuote := '''' + StringReplace(S, '''', '''\''''', [rfReplaceAll]) + '''';
  End;


Procedure AddBind(Var S: String; Const Opt, Path: String);
  Var
    P: String;

  Begin
  P := ExpandFileName(Path);
  If (Length(P) > 1) And (P[Length(P)] = '/') Then
    SetLength(P, Length(P) - 1);
  If (P <> '') And (DirectoryExists(P) Or FileExists(P)) Then
    S := S + ' ' + Opt + ' ' + ShQuote(P) + ' ' + ShQuote(P);
  End;


Function SandboxWrapper(Const ScriptPath, Bwrap, Mode, ChDir: String; RW, RO: TStrings): Boolean;
  Var
    S: String;
    i: Integer;
    Net: Boolean;
    F: TextFile;

  Begin
  Net := LowerCase(Mode) = 'net';
  S := 'exec ' + ShQuote(Bwrap) + ' --die-with-parent --unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup-try --cap-drop ALL';
  If Not Net Then
    S := S + ' --unshare-net';
  S := S + ' --ro-bind /usr /usr --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64 --symlink usr/sbin /sbin';
  S := S + ' --proc /proc --dev /dev --tmpfs /tmp';
  AddBind(S, '--ro-bind', '/etc/localtime');
  AddBind(S, '--ro-bind', '/etc/terminfo');
  AddBind(S, '--ro-bind', '/etc/ld.so.cache');
  AddBind(S, '--ro-bind', '/etc/alternatives');
  If Net Then
    Begin
    AddBind(S, '--ro-bind', '/etc/resolv.conf');
    AddBind(S, '--ro-bind', '/etc/hosts');
    AddBind(S, '--ro-bind', '/etc/nsswitch.conf');
    AddBind(S, '--ro-bind', '/etc/ssl');
    AddBind(S, '--ro-bind', '/etc/ca-certificates');
    End;
  If RO <> Nil Then
    For i := 0 To RO.Count - 1 Do
      AddBind(S, '--ro-bind', RO[i]);
  If RW <> Nil Then
    For i := 0 To RW.Count - 1 Do
      AddBind(S, '--bind', RW[i]);
  S := S + ' --unsetenv MK_HUB_PASSWORD';
  If ChDir <> '' Then
    S := S + ' --chdir ' + ShQuote(ChDir);
  S := S + ' -- "$@"';
  SandboxWrapper := False;
  Try
    AssignFile(F, ScriptPath);
    ReWrite(F);
    WriteLn(F, '#!/bin/sh');
    WriteLn(F, S);
    CloseFile(F);
    FpChmod(ScriptPath, &700);
    SandboxWrapper := True;
  Except
  End;
  End;


End.
