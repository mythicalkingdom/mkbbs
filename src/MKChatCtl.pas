{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKChatCtl;

{$mode objfpc}{$H+}

{
     mkchatctl: the sysop's hand on the multi-node chat from the command line (and from scripts); mkmon has the same on a screen (H).

        mkchatctl [-r run dir] [-c config dir] <command>

          who                    who is in the room (node, name, real name)
          log [N]                the last N lines of the room (default 20), private ones too
          say <text>             a line of the sysop in the room
          notice <text>          a notice in the room (*** text)
          announce <text>        a message to every node, in the room or not (the callers see it at their next key wait)
          mute <node> [minutes]  the caller cannot speak for that long (default 5);  unmute <node>
          kick <node>            remove the caller from the room (they may come back)
          ban <node>             remove the caller and put the name on chatban.lst (they cannot join again);  unban <name>
          bans                   the names on chatban.lst

     The run directory is the environment MKRUN (or -r), the BBS directory MK (or -c): chatban.lst is in it.  What is done goes to <run dir>/chat and is
     picked up by the nodes within a second; the log of the BBS (chat.log) records what the nodes do about it.
}

Uses SysUtils, Classes, MKChatCore, MKGlobT;

Var
  RunDir, BbsDir, Cmd, Arg, Shown, Real: String;
  i, N, Mins: Integer;
  L: TStringList;
  Room: TChatRoom;
  C: ChatCfgType;

Procedure Die(S: String);
  Begin
  WriteLn(StdErr, 'mkchatctl: ', S);
  Halt(1);
  End;

Function Rest(From: Integer): String;
  Var
    k: Integer;

  Begin
  Result := '';
  For k := From To ParamCount Do
    Result := Result + Copy(' ', 1, Ord(Result <> '')) + ParamStr(k);
  End;

Function NodeArg(Const S: String): Integer;
  Begin
  Result := StrToIntDef(S, 0);
  If Result <= 0 Then
    Die('a node number is needed');
  End;

Begin
  RunDir := GetEnvironmentVariable('MKRUN');
  BbsDir := GetEnvironmentVariable('MK');
  i := 1;
  While (i <= ParamCount) And (Copy(ParamStr(i), 1, 1) = '-') Do
    Begin
    If (ParamStr(i) = '-r') And (i < ParamCount) Then
      Begin
      RunDir := ParamStr(i + 1);
      Inc(i, 2);
      End
    Else If (ParamStr(i) = '-c') And (i < ParamCount) Then
      Begin
      BbsDir := ParamStr(i + 1);
      Inc(i, 2);
      End
    Else
      Die('usage: mkchatctl [-r run dir] [-c config dir] who | log [N] | say text | notice text | announce text | mute node [minutes] | unmute node | kick node | ban node | unban name | bans');
    End;
  If RunDir = '' Then
    Die('the run directory is not known (MKRUN, or -r)');
  If (BbsDir <> '') And (BbsDir[Length(BbsDir)] <> '/') Then
    BbsDir := BbsDir + '/';
  If i > ParamCount Then
    Die('a command is needed (who, log, say, notice, announce, mute, unmute, kick, ban, unban, bans)');
  Cmd := LowerCase(ParamStr(i));
  Arg := Rest(i + 1);
  ChatDefaults(C);
  If Cmd = 'who' Then
    Begin
    Room := TChatRoom.Create(RunDir, '', '', C, 0);
    L := TStringList.Create;
    Room.Who(L);
    For N := 0 To L.Count - 1 Do
      Begin
      Write(L[N]);
      If ChatPresence(RunDir, StrToIntDef(Copy(L[N], 6, Pos(':', L[N]) - 6), 0), Shown, Real) And (Real <> Shown) Then
        Write('   (', Real, ')');
      WriteLn;
      End;
    If L.Count = 0 Then
      WriteLn('nobody is in the room');
    End
  Else If Cmd = 'log' Then
    Begin
    Room := TChatRoom.Create(RunDir, '', '', C, 0);
    L := TStringList.Create;
    Room.Tail(L, StrToIntDef(Arg, 20));
    For N := 0 To L.Count - 1 Do
      WriteLn(L[N]);
    End
  Else If Cmd = 'say' Then
    Begin
    If Arg = '' Then Die('say what?');
    ChatSysopLine(RunDir, 'X', Arg);
    End
  Else If Cmd = 'notice' Then
    Begin
    If Arg = '' Then Die('what notice?');
    ChatSysopLine(RunDir, 'N', Arg);
    End
  Else If Cmd = 'announce' Then
    Begin
    If Arg = '' Then Die('announce what?');
    SysMsgSend(RunDir, Arg);
    End
  Else If (Cmd = 'mute') Or (Cmd = 'unmute') Then
    Begin
    N := NodeArg(ParamStr(i + 1));
    Mins := 5;
    If (Cmd = 'mute') And (ParamCount >= i + 2) Then
      Mins := StrToIntDef(ParamStr(i + 2), 5);
    If Cmd = 'unmute' Then
      Mins := 0;
    If Not ChatPresence(RunDir, N, Shown, Real) Then
      Die('node ' + IntToStr(N) + ' is not in the room');
    ChatCtl(RunDir, 'mute', N, Mins);
    If Mins > 0 Then
      ChatSysopLine(RunDir, 'N', Shown + ' was muted by the sysop for ' + IntToStr(Mins) + ' minute(s)')
    Else
      ChatSysopLine(RunDir, 'N', Shown + ' may speak again');
    End
  Else If (Cmd = 'kick') Or (Cmd = 'ban') Then
    Begin
    N := NodeArg(ParamStr(i + 1));
    If Not ChatPresence(RunDir, N, Shown, Real) Then
      Die('node ' + IntToStr(N) + ' is not in the room');
    If Cmd = 'ban' Then
      Begin
      If BbsDir = '' Then
        Die('the BBS directory is not known (MK, or -c): chatban.lst is in it');
      ChatBan(BbsDir + 'chatban.lst', Real);
      If Shown <> Real Then
        ChatBan(BbsDir + 'chatban.lst', Shown);
      End;
    ChatCtl(RunDir, 'kick', N, 0);
    ChatSysopLine(RunDir, 'N', Shown + ' was removed from the room by the sysop' + Copy(' and may not come back', 1, 22 * Ord(Cmd = 'ban')));
    End
  Else If Cmd = 'unban' Then
    Begin
    If (BbsDir = '') Or (Arg = '') Then
      Die('unban <name>, with the BBS directory (MK or -c)');
    If ChatUnban(BbsDir + 'chatban.lst', Arg) Then
      WriteLn(Arg, ' may use chat again')
    Else
      Die(Arg + ' is not on chatban.lst');
    End
  Else If Cmd = 'bans' Then
    Begin
    If (BbsDir <> '') And FileExists(BbsDir + 'chatban.lst') Then
      Begin
      L := TStringList.Create;
      L.LoadFromFile(BbsDir + 'chatban.lst');
      For N := 0 To L.Count - 1 Do
        If (Trim(L[N]) <> '') And (Copy(Trim(L[N]), 1, 1) <> '#') Then
          WriteLn(L[N]);
      End;
    End
  Else
    Die('unknown command ' + Cmd);
End.
