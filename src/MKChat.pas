Unit MKChat;   {Menu command 174: the multi-node chat room for a caller (MCHAT-PLAN.md); off unless the sysop turned it on (mkconfig: Chat)}

{$MODE OBJFPC}
{$H+}

{
  What the caller sees: the name of the room, the last lines of it, then lines as they come; what they type is a line of the room when they press Enter.  Commands:
     /who             who is in the room        /msg N text    a private line to node N (or a name)       /me text   an action
     /ignore N|name   do not show that node or name      /help      this list      /quit   leave (also /q, /exit)
  A line that is too long is cut, control characters are dropped, a word of the sysop's word file is masked or the line refused, more than the flood limit mutes the caller.
  Arrow keys and other escape sequences are swallowed (Esc does not leave the room).
}

Interface

Procedure DoMultiChat(Data: ShortString);

Implementation

Uses SysUtils, Classes, MKGlobT, MKVCrt, MKDoor, MKCfgAbs, MKString, MKLogEnt, MKChatCore;


Procedure Show(Const S: String; Attr: Byte);
  Begin
  User.DisplayAttr(Attr);
  User.DisplayStr(S);
  End;


Procedure Line(Const S: String; Attr: Byte);
  Begin
  Show(S, Attr);
  User.DisplayNewLine;
  End;


Function Why_(Const Why: String; C: ChatCfgType): String;
  Begin
  If Copy(Why, 1, 6) = 'muted:' Then
    Result := PromptOr(566, 'You are muted for') + ' ' + Copy(Why, 7, 9) + ' ' + PromptOr(567, 'more second(s).')
  Else If Why = 'muted' Then
    Result := PromptOr(568, 'You are muted.')
  Else If Copy(Why, 1, 6) = 'flood:' Then
    Result := PromptOr(569, 'Too many lines too fast: you are muted for') + ' ' + Copy(Why, 7, 9) + ' ' + PromptOr(570, 'minute(s).')
  Else If Why = 'filtered' Then
    Result := PromptOr(571, 'That line was not sent: it has a word that is not allowed here.')
  Else If Why = 'noprivate' Then
    Result := PromptOr(572, 'Private lines are not allowed here.')
  Else If Why = 'nobody' Then
    Result := PromptOr(573, 'Nobody by that node number or name is in the room.')
  Else
    Result := '';
  End;


Procedure Help;
  Begin
  Line(PromptOr(574, '/who  who is here    /msg N text  a private line to node N or a name    /me text  an action'), LightCyan);
  Line(PromptOr(575, '/ignore N|name  do not show that node or name    /help  this list    /quit  leave'), LightCyan);
  End;


Procedure DoMultiChat(Data: ShortString);
  Var
    C: ChatCfgType;
    Room: TChatRoom;
    RunDir, LogName, Why, Buf, Cmd, Arg, Nm: String;
    Lines: TStringList;
    Ch: Char;
    Sm: ShortString;
    i: Integer;
    Done, InEsc: Boolean;
    Start: Int64;

  Procedure Redraw;
    Begin
    User.DisplayChr(#13);
    Show('> ' + Buf, White);
    End;

  Procedure Erase;
    Begin
    User.DisplayChr(#13);
    User.DisplayStr(StringOfChar(' ', 2 + Length(Buf) + 1));
    User.DisplayChr(#13);
    End;

  Procedure Refuse(N: Word; Const Default: String);
    Begin
    User.DisplayNewLine;
    Line(PromptOr(N, Default), LightRed);
    User.DisplayNewLine;
    User.PressEnter;
    End;

  Procedure Say_(Const S: String; Attr: Byte);
    Begin
    Erase;
    Line(S, Attr);
    Redraw;
    End;

  Procedure Command(Const L: String);
    Var
      p: Integer;
      T: String;
      To_, k: Integer;

    Begin
    p := Pos(' ', L);
    If p = 0 Then
      Begin
      Cmd := LowerCase(L);
      Arg := '';
      End
    Else
      Begin
      Cmd := LowerCase(Copy(L, 1, p - 1));
      Arg := Trim(Copy(L, p + 1, 255));
      End;
    If (Cmd = '/quit') Or (Cmd = '/q') Or (Cmd = '/exit') Then
      Done := True
    Else If (Cmd = '/help') Or (Cmd = '/?') Or (Cmd = '/h') Then
      Help
    Else If (Cmd = '/who') Or (Cmd = '/w') Then
      Begin
      T := '';
      Lines.Clear;
      Room.Who(Lines);
      Say_(PromptOr(576, 'In the room:'), LightCyan);
      For k := 0 To Lines.Count - 1 Do
        Say_('  ' + Lines[k], Cyan);
      End
    Else If Cmd = '/me' Then
      Begin
      If Not Room.Me(Arg, Why) And (Why <> '') Then
        Say_(Why_(Why, C), LightRed);
      End
    Else If (Cmd = '/msg') Or (Cmd = '/m') Or (Cmd = '/tell') Or (Cmd = '/p') Then
      Begin
      p := Pos(' ', Arg);
      If p = 0 Then
        Say_(PromptOr(577, 'Use /msg N text'), LightRed)
      Else
        Begin
        To_ := Room.NodeOf(Copy(Arg, 1, p - 1));
        T := Trim(Copy(Arg, p + 1, 255));
        If To_ = 0 Then
          Say_(Why_('nobody', C), LightRed)
        Else If Room.Tell(To_, T, Why) Then
          Say_('[' + PromptOr(578, 'private to') + ' ' + Room.NameOfNode(To_) + ' (node ' + IntToStr(To_) + ')] ' + Room.Clean(T), LightMagenta)
        Else If Why <> '' Then
          Say_(Why_(Why, C), LightRed);
        End;
      End
    Else If Cmd = '/ignore' Then
      Begin
      If Arg = '' Then
        Say_(PromptOr(579, 'Use /ignore N or /ignore name'), LightRed)
      Else
        Begin
        Room.Ignore(Arg);
        Say_(PromptOr(580, 'Not showing lines from') + ' ' + Arg + '.', LightCyan);
        End;
      End
    Else
      Say_(PromptOr(581, 'Not a command: type /help'), LightRed);
    End;

  Begin
  RunDir := GetEnvironmentVariable('MKRUN');
  If (Not Config^.HasChat) Or (RunDir = '') Then
    Begin
    Refuse(558, 'Multi-node chat is not available.');
    Exit;
    End;
  Config^.GetChat(C);
  If Not C.Enabled Then
    Begin
    Refuse(558, 'Multi-node chat is not available.');
    Exit;
    End;
  If User.GetUserSecLevel < C.MinLevel Then
    Begin
    Refuse(559, 'Your security level is too low for chat.');
    Exit;
    End;
  Nm := User.GetUserName;
  If C.ShowHandle And (Trim(User.GetUserHandle) <> '') Then
    Nm := Trim(User.GetUserHandle);
  LogName := ExtractFilePath(ExpandFileName(Config^.GetLogFileName)) + 'chat.log';
  Room := TChatRoom.Create(RunDir, LogName, Config^.GetBbsPath + 'chatban.lst', C, NodeNumber);
  If Room.Banned(User.GetUserName) Or Room.Banned(Nm) Then
    Begin
    Room.Free;
    Refuse(560, 'You may not use chat.');
    Exit;
    End;
  Lines := TStringList.Create;
  Buf := '';
  Done := False;
  InEsc := False;
  Start := Now_;
  Try
    User.PostStatus(uoChat);
    LogEntry.WriteEntry('Chat: ' + User.GetUserName + ' joined the room');
    InMultiChat := True;
    If Not SysMsgInit Then
      Begin
      SysMsgInit := True;
      SysMsgOffset := -1;
      End;
    Room.Join(Nm, User.GetUserName);
    User.DisplayNewLine;
    Line(C.RoomName + ' - ' + PromptOr(582, 'type /help for the commands, /quit to leave'), LightGreen);
    Lines.Clear;
    Room.History(Lines);
    For i := 0 To Lines.Count - 1 Do
      Line(Lines[i], Cyan);
    Lines.Clear;
    Room.Who(Lines);
    Line(PromptOr(576, 'In the room:') + ' ' + IntToStr(Lines.Count), LightCyan);
    Redraw;
    While User.UserInfo^.Ok And (Not Done) Do
      Begin
      User.CheckInput;
      User.CheckIdle;
      Lines.Clear;
      If Room.Poll(Lines) > 0 Then
        Begin
        Erase;
        For i := 0 To Lines.Count - 1 Do
          Line(Lines[i], LightCyan);
        Redraw;
        End;
      While SysMsgNext(RunDir, SysMsgOffset, Sm) Do
        Say_(PromptOr(584, 'Message from the sysop:') + ' ' + Sm, LightRed);
      If Room.Kicked Then
        Done := True;
      If (C.MaxMinutes > 0) And (Now_ - Start > C.MaxMinutes * 60) Then
        Begin
        Say_(PromptOr(583, 'Your chat time for this call is used up.'), LightRed);
        Done := True;
        End
      Else If User.InputChr(Ch) Then
        Begin
        If InEsc Then
          Begin
          If Ch In ['A'..'Z', 'a'..'z', '~'] Then
            InEsc := False;
          End
        Else If Ch = #27 Then
          InEsc := True
        Else If (Ch = #8) Or (Ch = #127) Then
          Begin
          If Buf <> '' Then
            Begin
            Delete(Buf, Length(Buf), 1);
            User.DisplayStr(#8' '#8);
            End;
          End
        Else If Ch = #21 Then
          Begin
          Erase;
          Buf := '';
          Redraw;
          End
        Else If Ch = #13 Then
          Begin
          Cmd := Trim(Buf);
          Erase;
          Buf := '';
          If Cmd <> '' Then
            Begin
            If Cmd[1] = '/' Then
              Command(Cmd)
            Else If Not Room.Say(Cmd, Why) And (Why <> '') Then
              Line(Why_(Why, C), LightRed);
            End;
          If Not Done Then
            Redraw;
          End
        Else If (Ch >= ' ') And (Ch <> #127) Then
          Begin
          If Length(Buf) < C.MaxLine Then
            Begin
            Buf := Buf + Ch;
            User.DisplayChr(Ch);
            End;
          End;
        End
      Else
        Sleep(40);
      End;
  Finally
    InMultiChat := False;
    Room.Leave;
    Room.Free;
    Lines.Free;
    LogEntry.WriteEntry('Chat: ' + User.GetUserName + ' left the room');
  End;
  User.DisplayAttr(LightGray);
  User.DisplayNewLine;
  User.DisplayNewLine;
  End;


End.
