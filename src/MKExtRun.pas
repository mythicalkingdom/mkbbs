{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKExtRun;   {Menu command 175: run an extension of the sysop for the caller (MHOST-PLAN.md phase 2), and the hooks of phase 3}

{$MODE OBJFPC}
{$H+}

{
     The menu item's data is the NAME of an entry in extensions.cfg (never a path), then arguments for the program:

          who
          scores top 10

     The program of the entry (.bas = BASIC, .pas = Pascal) runs for the caller as menu commands 169 and 170 do (the caller's terminal, Ctrl-C, locked, the interpreter's limits), with
     these differences: it can ask the BBS (HOST$ / HostCall: MKHost.pas, EXTENSIONS.md) with the capabilities of its entry, it has the commands of the session (below), it stops after the
     timeout of the entry, and it is refused to a caller whose level is under the entry's level.

     The commands of the session (prefix bbs.; the caller's side, no other user):
         bbs.user        the caller: name handle city level time_left calls ansi screen_length          (session:read)
         bbs.node        the node: node baud address                                                    (session:read)
         bbs.file <name> shows a text file of the BBS (txtfiles: name.asc / .ans, as a menu item does)   (session:control)
         bbs.pause       "Press Enter"                                                                  (session:control)
         bbs.hangup      ends the call                                                                  (session:control)
     Text the program gives the BBS and gets back is CP437, as for the caller's terminal.

     Hooks (phase 3): the [hooks] block of extensions.cfg names extensions that RunHooks runs at an event of the call: logon, logoff, newuser, upload, newmsg, menu.  The caller's terminal is
     theirs too (a greeting at the logon is the usual use); what they get is the event as arguments (arg 1 is the event, arg 2 the user, then what the event says).
}

Interface

Procedure DoExtension(Data: ShortString);

Procedure RunHooks(Const Event, A1, A2, A3, A4: String);
  {the extensions of [hooks] in extensions.cfg for an event, in order: arg 1 is the event, arg 2 the user, then A1..A4 (empty ones left out).  A hook never stops the caller:
   it is skipped (a line in the log) when the caller's level is too low, its program is not there or it fails; an error is not shown with "Press Enter".  menu: A1 is the menu}

Implementation

Uses SysUtils, Classes, HostReg, MKHost, MKExtCfg, MKDoor, MKGlobT, MKCfgAbs, MKLogEnt, MKString, MKCodes, MKCp437,
  MKBasicRun, MKPascalRun, MKComAbs;


Type
  TSession = Class
    Host: THost;
    Function Handle(Const Verb: String; Args: TStrings; Res: THostResult; Out Err: String): Boolean;
  End;


Function Arg0(Args: TStrings): String;
  Begin
  If Args.Count > 0 Then
    Result := Args[0]
  Else
    Result := '';
  End;


Function U8(Const S: String): String;
  {a CP437 string of the BBS as the registry keeps text (UTF-8); THost.Call turns it back}
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If S[i] < #128 Then
      Result := Result + S[i]
    Else
      Result := Result + Cp437ToUtf8(Ord(S[i]));
  End;


Function TSession.Handle(Const Verb: String; Args: TStrings; Res: THostResult; Out Err: String): Boolean;
  Var
    Cap: String;
    Name, F: String;
    V: LongInt;
    Sec: SecType;

  Begin
  Err := '';
  Result := False;
  If (Verb = 'bbs.user') Or (Verb = 'bbs.node') Then
    Cap := 'session:read'
  Else If Verb = 'bbs.set' Then
    Cap := 'users:write'
  Else If Verb = 'bbs.addtime' Then
    Cap := 'node:time'
  Else
    Cap := 'session:control';
  If Not Host.Allowed(Cap) Then
    Begin
    Err := 'not allowed: ' + Verb + ' needs ' + Cap;
    LogEntry.WriteEntry('Ext ' + Host.Who + ': refused: ' + Err);
    Exit;
    End;
  If Verb = 'bbs.user' Then
    Begin
    Res.Table(['name', 'handle', 'city', 'level', 'time_left', 'calls', 'ansi', 'screen_length']);
    Res.Row([U8(User.GetUserName), U8(User.GetUserHandle), U8(User.GetUserCity), IntToStr(User.GetUserSecLevel), IntToStr(User.TimeRemain),
      IntToStr(User.GetUserTimesCalled), IntToStr(Ord(User.GetUserAnsi)), IntToStr(User.GetUserScrLength)]);
    End
  Else If Verb = 'bbs.node' Then
    Begin
    Res.Table(['node', 'baud', 'address']);
    Res.Row([IntToStr(NodeNumber), IntToStr(UserBaud), ComSession^.GetRemoteAddr]);
    End
  Else If Verb = 'bbs.file' Then
    Begin
    If (Args.Count < 1) Or (Pos('/', Args[0]) > 0) Or (Pos('\', Args[0]) > 0) Or (Pos('..', Args[0]) > 0) Then
      Begin
      Err := 'bbs.file needs the name of a text file of the BBS (no folder)';
      Exit;
      End;
    Name := Args[0];
    BbsDisplay.DisplayBbsFile(Name, '');
    End
  Else If Verb = 'bbs.set' Then
    Begin
    If Args.Count < 2 Then
      Begin
      Err := 'bbs.set <level|flags|flagon|flagoff|city|elapsed|credit> <value>';
      Exit;
      End;
    F := LowerCase(Args[0]);
    V := StrToIntDef(Args[1], MaxLongInt);
    Host.WriteLog('set ' + F + ' of the caller ' + User.GetUserName + ' to ' + Args[1]);
    If Not Host.DryRun Then
      Begin
      If F = 'city' Then
        User.SetUserCity(Copy(Args[1], 1, 25))
      Else If ((F = 'level') And (V >= 0) And (V <= 65535)) Or (F = 'flags') And (V <> MaxLongInt) Or ((F = 'flagon') Or (F = 'flagoff')) And (V >= 1) And (V <= 32) Then
        Begin
        User.GetUserSec(Sec);
        If F = 'level' Then Sec.Level := V
        Else If F = 'flags' Then Sec.Flags := V
        Else If F = 'flagon' Then Sec.Flags := Sec.Flags Or LongInt(1 Shl (V - 1))
        Else Sec.Flags := Sec.Flags And Not LongInt(1 Shl (V - 1));
        User.SetUserSec(Sec);
        End
      Else If (F = 'elapsed') And (V >= 0) And (V <= 32767) Then
        User.SetUserElapsed(V)
      Else If (F = 'credit') And (V >= -32768) And (V <= 32767) Then
        User.SetUserCredit(V)
      Else
        Begin
        Err := 'the fields to set are level, flags, flagon, flagoff, city, elapsed and credit, with a value that fits';
        Exit;
        End;
      End;
    Res.Clear;
    End
  Else If Verb = 'bbs.addtime' Then
    Begin
    V := StrToIntDef(Arg0(Args), 0);
    If (V = 0) Or (Abs(V) > 255) Then
      Begin
      Err := 'bbs.addtime <minutes, -255..255 and not 0>';
      Exit;
      End;
    Host.WriteLog('gave the caller ' + User.GetUserName + ' ' + IntToStr(V) + ' minutes');
    If Not Host.DryRun Then
      User.AdjustTime(V * 60);
    Res.Clear;
    End
  Else If Verb = 'bbs.pause' Then
    User.PressEnter
  Else If Verb = 'bbs.hangup' Then
    Begin
    LogEntry.WriteEntry('Ext ' + Host.Who + ': ended the call');
    User.UserInfo^.Ok := False;
    User.UserInfo^.NotOkReason := 6;
    End
  Else
    Begin
    Err := 'unknown command ' + Verb;
    Exit;
    End;
  Result := True;
  End;


Procedure Execute(Cfg: TExtCfg; E: Integer; Words: TStringList; Silent: Boolean);
  {run entry E for the caller; Words: the name, then the arguments}
  Var
    Name, Full, Ext: String;
    Caps: TStringList;
    Host: THost;
    Sess: TSession;

  Begin
  Name := Cfg.Entries[E].Name;
  Full := Cfg.FullPath(Cfg.Entries[E]);
  Ext := LowerCase(ExtractFileExt(Full));
  Caps := HostCaps(Cfg.Entries[E].Caps);
  Host := THost.Create(Name, Caps);
  Host.Cp437 := True;
  Host.DefaultFrom := User.GetUserName;
  Host.OwnNode := NodeNumber;
  Host.ScriptDir := ExtractFileDir(Full);
  Caps.Free;
  Sess := TSession.Create;
  Sess.Host := Host;
  Host.Registry.Add('bbs', 'the caller''s session', 'user node file pause hangup set addtime', @Sess.Handle);
  Host.SetScriptArgs(Words);
  LogEntry.WriteEntry('Ext ' + Name + ': run for ' + User.GetUserName + ' (' + Copy(Cfg.Entries[E].Caps, 1, 120) + ')');
  Try
    If Ext = '.bas' Then
      RunBasicExtension(Full, Host.Registry, Cfg.Entries[E].Timeout, Silent)
    Else
      RunPascalExtension(Full, Host.Registry, Cfg.Entries[E].Timeout, Words, Silent);
  Finally
    LogEntry.WriteEntry('Ext ' + Name + ': ended');
    Sess.Free;
    Host.Free;
  End;
  End;


Procedure Say(Const S: String);
  Begin
  User.DisplayNewLine;
  User.DisplayStrLn(S);
  User.PressEnter;
  End;


Procedure DoExtension(Data: ShortString);
  Var
    Cfg: TExtCfg;
    Words: TStringList;
    S, W, Name, Full, Ext: String;
    i, E: Integer;
    Q: Boolean;

  Begin
  Words := TStringList.Create;
  S := Trim(Data);
  W := '';
  Q := False;
  For i := 1 To Length(S) + 1 Do
    If (i > Length(S)) Or ((S[i] = ' ') And Not Q) Then
      Begin
      If W <> '' Then
        Words.Add(W);
      W := '';
      End
    Else If S[i] = '"' Then
      Q := Not Q
    Else
      W := W + S[i];
  If Words.Count = 0 Then
    Begin
    Words.Free;
    Say(PromptOr(585, 'That extension is not available.'));
    LogEntry.WriteEntry('Ext: the menu item names no extension');
    Exit;
    End;
  Name := Words[0];
  Cfg := TExtCfg.Create(Config^.GetBbsPath);
  Cfg.Load;
  E := Cfg.Find(Name);
  If E < 0 Then
    Begin
    LogEntry.WriteEntry('Ext ' + Name + ': not in extensions.cfg');
    Say(PromptOr(585, 'That extension is not available.'));
    Cfg.Free;
    Words.Free;
    Exit;
    End;
  If User.GetUserSecLevel < Cfg.Entries[E].Level Then
    Begin
    LogEntry.WriteEntry('Ext ' + Name + ': refused: level ' + IntToStr(User.GetUserSecLevel) + ' is under ' + IntToStr(Cfg.Entries[E].Level) + ' (' + User.GetUserName + ')');
    Say(PromptOr(586, 'Your security level is too low for that.'));
    Cfg.Free;
    Words.Free;
    Exit;
    End;
  Full := Cfg.FullPath(Cfg.Entries[E]);
  Ext := LowerCase(ExtractFileExt(Full));
  If (Not FileExists(Full)) Or ((Ext <> '.bas') And (Ext <> '.pas')) Then
    Begin
    LogEntry.WriteEntry('Ext ' + Name + ': the program ' + Full + ' is not there or not a .bas / .pas file');
    Say(PromptOr(585, 'That extension is not available.'));
    Cfg.Free;
    Words.Free;
    Exit;
    End;
  Try
    Execute(Cfg, E, Words, False);
  Finally
    Cfg.Free;
    Words.Free;
  End;
  End;


Var
  HookCfg: TExtCfg;
  HookLoaded, InHook: Boolean;


Procedure RunOneHook(Const Event, Name: String; Words: TStringList);
  Var
    E: Integer;
    Full, Ext: String;

  Begin
  E := HookCfg.Find(Name);
  If E < 0 Then
    Begin
    LogEntry.WriteEntry('Ext hook ' + Event + ': ' + Name + ' is not in extensions.cfg');
    Exit;
    End;
  If User.GetUserSecLevel < HookCfg.Entries[E].Level Then
    Exit;                                {not for this caller: not worth a line in every log}
  Full := HookCfg.FullPath(HookCfg.Entries[E]);
  Ext := LowerCase(ExtractFileExt(Full));
  If (Not FileExists(Full)) Or ((Ext <> '.bas') And (Ext <> '.pas')) Then
    Begin
    LogEntry.WriteEntry('Ext hook ' + Event + ': the program of ' + Name + ' is not there or not a .bas / .pas file');
    Exit;
    End;
  Words[0] := Name;
  Try
    Execute(HookCfg, E, Words, True);
  Except
    On Ex: Exception Do
      LogEntry.WriteEntry('Ext hook ' + Event + ': ' + Name + ' failed: ' + Ex.ClassName + ': ' + Ex.Message);
  End;
  End;


Procedure RunHooks(Const Event, A1, A2, A3, A4: String);
  Var
    Words: TStringList;
    Names, W: String;
    i, k: Integer;
    List: TStringList;
    WasOk: Boolean;

  Begin
  If InHook Then
    Exit;
  If Not HookLoaded Then
    Begin
    HookLoaded := True;
    HookCfg := TExtCfg.Create(Config^.GetBbsPath);
    HookCfg.Load;
    End;
  If HookCfg.Hooks.Count = 0 Then
    Exit;
  Names := HookCfg.HookNames(Event);
  If Event = 'menu' Then
    Names := Names + ' ' + HookCfg.HookNames('menu.' + LowerCase(A1));
  Names := Trim(Names);
  If Names = '' Then
    Exit;
  InHook := True;
  WasOk := User.UserInfo^.Ok;
  List := HostCaps(Names);
  Words := TStringList.Create;
  Try
    For i := 0 To List.Count - 1 Do
      Begin
      Words.Clear;
      Words.Add(List[i]);
      Words.Add(Event);
      Words.Add(User.GetUserName);
      If A1 <> '' Then Words.Add(A1);
      If A2 <> '' Then Words.Add(A2);
      If A3 <> '' Then Words.Add(A3);
      If A4 <> '' Then Words.Add(A4);
      RunOneHook(Event, List[i], Words);
      If WasOk And (Not User.UserInfo^.Ok) Then
        Break;                           {a hook ended the call (bbs.hangup)}
      End;
  Finally
    Words.Free;
    List.Free;
    InHook := False;
  End;
  k := 0;
  W := '';
  End;




End.
