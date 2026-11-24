Unit MKStats;        {one line for each call, written when it ends: what mkstats makes its reports from}

{$I MKB.Def}

{
     mk calls StatsBegin when the call starts, StatsLoggedOn when the caller is in (the counters of the user are looked at), and StatsEnd when the call is over.  StatsEnd appends a
     line to <BBS directory>/stats/YYYY-MM.tsv (one file for each month, tab separated; the first line of a file names the fields):

        start  end  date  node  type  label  port  addr  user  result  secs  ulfiles  dlfiles  ulk  dlk  msgs  reason

       start, end    seconds since 1970 (UTC);  date  the local day of the start (YYYY-MM-DD)
       type          the kind of session: telnet, raw, ws, std (a terminal or inetd), local
       label         what the port is for (the "label" of the port in mklisten.json, default its type: telnet, ws, raw, qwk, ssh ...); port: its number
       user          the name of the user ('' when nobody logged on);  result: ok (logged on and off), nologin (the caller went before the name was accepted), failed (the log-on failed:
                     too many wrong tries, errorlevel 88)
       secs          how long the call lasted;  ulfiles, dlfiles, ulk, dlk, msgs: the files and kilobytes sent and taken and the messages posted during the call
       reason        why the call ended (the code of the user object: 0 = the caller ended it ...)

     The line is written with one write on a file opened for appending, so calls that end together do not mix their lines.  Nothing is written by the tools, only by mk.  A statistics file that
     cannot be written is no reason to disturb the call: it is skipped.
}

Interface

Procedure StatsBegin(SessType, Addr: String; Node: Word; LocalCall: Boolean);
Procedure StatsLoggedOn;
Procedure StatsEnd(Failed: Boolean);


Implementation

Uses BaseUnix, MKGlobT, MKCfgAbs, MKDoor, MKString, MKFile,
  Dos;

Var
  StartAt: LongInt;
  SType, SAddr, SLabel, SPort: String;
  SNode: Word;
  Local: Boolean;
  Have: Boolean;
  UL0, DL0, ULk0, DLk0, Msgs0: LongInt;


Procedure StatsBegin(SessType, Addr: String; Node: Word; LocalCall: Boolean);
  Begin
  StartAt := fpTime;
  SType := Lower(SessType);
  If SType = '' Then
    SType := 'std';
  If LocalCall Then
    SType := 'local';
  SAddr := Addr;
  SNode := Node;
  Local := LocalCall;
  SPort := GetEnv('MKPORT');
  SLabel := GetEnv('MKLABEL');
  If SLabel = '' Then
    SLabel := SType;
  Have := False;
  End;


Procedure StatsLoggedOn;
  Begin
  If Have Or Not User.UserIsLoaded Then
    Exit;
  UL0 := User.GetUserULFiles;
  DL0 := User.GetUserDLFiles;
  ULk0 := User.UserInfo^.ExitInfo.User.ULk;
  DLk0 := User.UserInfo^.ExitInfo.User.DLk;
  Msgs0 := User.GetUserMsgsEntered;
  Have := True;
  End;


Function Clean(S: String): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    If S[i] < ' ' Then
      S[i] := ' ';
  Clean := S;
  End;


Function Pad2(N: LongInt): String;
  Begin
  Pad2 := Chr(48 + (N Div 10) Mod 10) + Chr(48 + N Mod 10);
  End;


Procedure StatsEnd(Failed: Boolean);
  Var
    Dir, FN, Line, Result_, Date_, UserName: String;
    Y, Mo, D, Dw: Word;
    Fd: LongInt;
    Now_: LongInt;
    Fresh: Boolean;
    Head: String;
    Ul, Dl, Ulk, Dlk, Msgs, Reason: LongInt;

  Begin
  Now_ := fpTime;
  Reason := 0;
  If User.UserIsLoaded And Not User.Ok Then
    Reason := User.GetNotOkReason;                {0 while the user is ok: the reason is only set when the call is ended by something}
  GetDate(Y, Mo, D, Dw);
  If Failed Then
    Result_ := 'failed'
  Else If User.UserIsLoaded Then
    Result_ := 'ok'
  Else
    Result_ := 'nologin';
  UserName := '';
  Ul := 0;
  Dl := 0;
  Ulk := 0;
  Dlk := 0;
  Msgs := 0;
  If User.UserIsLoaded Then
    Begin
    UserName := User.GetUserName;
    If Have Then
      Begin
      Ul := User.GetUserULFiles - UL0;
      Dl := User.GetUserDLFiles - DL0;
      Ulk := User.UserInfo^.ExitInfo.User.ULk - ULk0;
      Dlk := User.UserInfo^.ExitInfo.User.DLk - DLk0;
      Msgs := User.GetUserMsgsEntered - Msgs0;
      End;
    End;
  If Ul < 0 Then Ul := 0;
  If Dl < 0 Then Dl := 0;
  If Ulk < 0 Then Ulk := 0;
  If Dlk < 0 Then Dlk := 0;
  If Msgs < 0 Then Msgs := 0;
  Date_ := Long2Str(Y) + '-' + Pad2(Mo) + '-' + Pad2(D);
  Dir := Config^.GetBbsPath;
  If (Dir <> '') And (Dir[Length(Dir)] <> '/') Then
    Dir := Dir + '/';
  Dir := Dir + 'stats';
  fpMkDir(Dir, 509);
  FN := Dir + '/' + Long2Str(Y) + '-' + Pad2(Mo) + '.tsv';
  Fresh := Not FileExist(FN);
  Head := '#mkstats 1' + #10 + '#start' + #9 + 'end' + #9 + 'date' + #9 + 'node' + #9 + 'type' + #9 + 'label' + #9 + 'port' + #9 + 'addr' + #9 + 'user' + #9 + 'result' + #9 + 'secs' + #9 +
    'ulfiles' + #9 + 'dlfiles' + #9 + 'ulk' + #9 + 'dlk' + #9 + 'msgs' + #9 + 'reason' + #10;
  Line := Long2Str(StartAt) + #9 + Long2Str(Now_) + #9 + Date_ + #9 + Long2Str(SNode) + #9 + SType + #9 + Clean(SLabel) + #9 + Clean(SPort) + #9 + Clean(SAddr) + #9 + Clean(UserName) + #9 +
    Result_ + #9 + Long2Str(Now_ - StartAt) + #9 + Long2Str(Ul) + #9 + Long2Str(Dl) + #9 + Long2Str(Ulk) + #9 + Long2Str(Dlk) + #9 + Long2Str(Msgs) + #9 + Long2Str(Reason) + #10;
  Fd := fpOpen(FN, O_WRONLY Or O_CREAT Or O_APPEND, 436);
  If Fd < 0 Then
    Exit;
  If Fresh Then
    Line := Head + Line;
  fpWrite(Fd, Line[1], Length(Line));
  fpClose(Fd);
  End;


Begin
Have := False;
StartAt := 0;
End.
