Unit MKExtRun;   {Menu command 175: run an extension of the sysop for the caller (MHOST-PLAN.md phase 2)}

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
}

Interface

Procedure DoExtension(Data: ShortString);

Implementation

Uses SysUtils, Classes, HostReg, MKHost, MKExtCfg, MKDoor, MKGlobT, MKCfgAbs, MKLogEnt, MKString, MKCodes, MKCp437,
  MKBasicRun, MKPascalRun, MKComAbs;


Type
  TSession = Class
    Host: THost;
    Function Handle(Const Verb: String; Args: TStrings; Res: THostResult; Out Err: String): Boolean;
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
    Name: String;

  Begin
  Err := '';
  Result := False;
  If (Verb = 'bbs.user') Or (Verb = 'bbs.node') Then
    Cap := 'session:read'
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
    Caps: TStringList;
    Host: THost;
    Sess: TSession;

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
  Caps := HostCaps(Cfg.Entries[E].Caps);
  Host := THost.Create(Name, Caps);
  Host.Cp437 := True;
  Caps.Free;
  Sess := TSession.Create;
  Sess.Host := Host;
  Host.Registry.Add('bbs', 'the caller''s session', 'user node file pause hangup', @Sess.Handle);
  Host.SetScriptArgs(Words);
  LogEntry.WriteEntry('Ext ' + Name + ': run for ' + User.GetUserName + ' (' + Copy(Cfg.Entries[E].Caps, 1, 120) + ')');
  Try
    If Ext = '.bas' Then
      RunBasicExtension(Full, Host.Registry, Cfg.Entries[E].Timeout)
    Else
      RunPascalExtension(Full, Host.Registry, Cfg.Entries[E].Timeout, Words);
  Finally
    LogEntry.WriteEntry('Ext ' + Name + ': ended');
    Sess.Free;
    Host.Free;
    Cfg.Free;
    Words.Free;
  End;
  End;


End.
