{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKHostW;   {What a script may change in the BBS: a message, a file in a file area, a user's record, a node (MHOST-PLAN.md phase 4)}

{$MODE OBJFPC}
{$H+}

{
  Everything goes through the code the BBS itself uses (the message base objects with their locks, the user file object, the node's own snoop socket), never through the files.  The
  commands that call these are in MKHost.pas; a capability (msgs:post, files:add, users:write, node:send, node:kick, node:time) decides who may.
}

Interface

Uses Classes;

Function HwPostMsg(Area: Integer; Const From_, To_, Subj: String; Priv: Boolean; Body: TStrings; Out Num: LongInt; Out Err: String): Boolean;
  {a message in a local or an echo area (netmail needs an address: not yet); the base says the number it gave}

Function HwAddFile(Area: Integer; Const SrcDir, SrcName, Desc: String; Out Name, Err: String): Boolean;
  {copies the file SrcName of the script's own folder into the folder of the file area under a safe name and lists it (files.bbs) with the description}

Function HwUserSet(Const Who, Field, Value: String; OnLine: TStrings; Out UserName, Err: String): Boolean;
  {OnLine: the names (lower case) of the users on a node: one of them is refused, the change would be lost when the call ends.  Who: the number (from 0) or the name.  Fields: level (0..65535), flags (the 32 bit number), flagon / flagoff (a flag 1..32), city, elapsed (minutes used today), credit (netmail credit).  Never the password.}

Function HwNodeCommand(Const RunDir: String; Node: Integer; Tag: Char; Arg: Byte; Out Reply: String): Boolean;
  {one command to the snoop socket of a node: '+' / '-' Arg minutes, 'K' hang up; Reply is what the node says}

Implementation

Uses SysUtils, BaseUnix, Sockets, MKGlobT, MKCfgAbs, MKMsgAbs, MKMsgOpn, MKString, MKDos, MKName, MKFileList;


Function HwPostMsg(Area: Integer; Const From_, To_, Subj: String; Priv: Boolean; Body: TStrings; Out Num: LongInt; Out Err: String): Boolean;
  Var
    M: AbsMsgPtr;
    i: Integer;
    Fido: Boolean;

  Begin
  Result := False;
  Num := 0;
  Err := '';
  If (Area < 1) Or (Area > Config^.GetMaxMsgAreas) Or (Config^.GetMsgName(Area) = '') Then
    Begin
    Err := 'no such message area';
    Exit;
    End;
  If Config^.GetMsgType(Area) = NetMail Then
    Begin
    Err := 'netmail areas need an address: not supported yet';
    Exit;
    End;
  If (Trim(From_) = '') Or (Trim(To_) = '') Or (Trim(Subj) = '') Then
    Begin
    Err := 'a message needs a from, a to and a subject';
    Exit;
    End;
  If Not OpenMsgArea(M, Area) Then
    Begin
    Err := 'the message base cannot be opened';
    Exit;
    End;
  Try
    Fido := False;
    Case Config^.GetMsgType(Area) Of
      Normal: M^.SetMailType(mmtNormal);
      EchoMail:
        Begin
        M^.SetMailType(mmtEchoMail);
        Fido := Config^.MsgAddFido(Area);
        End;
      End;
    M^.StartNewMsg;
    M^.SetFrom(Copy(Trim(From_), 1, 35));
    M^.SetTo(Copy(Trim(To_), 1, 35));
    M^.SetSubj(Copy(Trim(Subj), 1, 72));
    M^.SetPriv(Priv);
    M^.SetDate(DateStr(GetDosDate));
    M^.SetTime(TimeStr(GetDosDate));
    M^.SetLocal(True);
    M^.SetEcho(True);
    For i := 0 To Body.Count - 1 Do
      Begin
      M^.DoString(Copy(Body[i], 1, 250));
      M^.DoChar(#13);
      End;
    If Body.Count = 0 Then
      M^.DoChar(#13);
    If Fido Then
      Begin
      M^.DoStringLn('--- MK Bbs v0.2');
      M^.DoStringLn(Config^.GetDefaultOrigStr(Area));
      End;
    If M^.WriteMsg <> 0 Then
      Begin
      Err := 'the message could not be written';
      Exit;
      End;
    Num := M^.GetMsgNum;
    Result := True;
  Finally
    If CloseMsgArea(M) Then;
  End;
  End;


Function HwAddFile(Area: Integer; Const SrcDir, SrcName, Desc: String; Out Name, Err: String): Boolean;
  Var
    Dir, Src, Dest: String;
    D: TStringList;
    FI, FO: TFileStream;

  Begin
  Result := False;
  Name := '';
  Err := '';
  If (Area < 1) Or (Area > Config^.GetMaxFileAreas) Or (Config^.GetFileAreaName(Area) = '') Then
    Begin
    Err := 'no such file area';
    Exit;
    End;
  Dir := Config^.GetFileAreaPath(Area);
  If (Dir = '') Or Not DirectoryExists(Dir) Then
    Begin
    Err := 'the folder of the file area is not there';
    Exit;
    End;
  If Dir[Length(Dir)] <> '/' Then
    Dir := Dir + '/';
  If (SrcName = '') Or (Pos('/', SrcName) > 0) Or (Pos('\', SrcName) > 0) Or (SrcName[1] = '.') Then
    Begin
    Err := 'the file is a name in the script''s own folder';
    Exit;
    End;
  Src := IncludeTrailingPathDelimiter(SrcDir) + SrcName;
  If Not FileExists(Src) Then
    Begin
    Err := 'the script has no file ' + SrcName;
    Exit;
    End;
  Name := UploadName(SrcName);
  If Name = '' Then
    Begin
    Err := 'the file name has nothing usable in it';
    Exit;
    End;
  If InArea(Dir, Name) Then
    Begin
    Err := 'there is a file of that name in the area already';
    Exit;
    End;
  Dest := Dir + Name;
  Try
    FI := TFileStream.Create(Src, fmOpenRead Or fmShareDenyNone);
    Try
      FO := TFileStream.Create(Dest, fmCreate);
      Try
        FO.CopyFrom(FI, 0);
      Finally
        FO.Free;
      End;
    Finally
      FI.Free;
    End;
  Except
    DeleteFile(Dest);
    Err := 'the file could not be copied into the area';
    Exit;
  End;
  D := TStringList.Create;
  Try
    If Trim(Desc) <> '' Then
      D.Add(Trim(Desc));
    Try
      AddListing(Dir, Config^.GetFileListPath(Area), Name, D);
    Except
      Err := 'the file list of the area cannot be written';
      Exit;
    End;
  Finally
    D.Free;
  End;
  Result := True;
  End;


Function FindUser(Const Who: String; Out Pos_: Integer): Boolean;
  Var
    N, i: Integer;
    Want: String;

  Begin
  Result := False;
  Pos_ := -1;
  NameSearch.GoToPosition(0);
  N := NameSearch.GetNumUsers;
  If StrToIntDef(Who, -1) >= 0 Then
    Begin
    Pos_ := StrToInt(Who);
    If Pos_ < N Then
      Begin
      NameSearch.GoToPosition(Pos_);
      Result := True;
      End;
    Exit;
    End;
  Want := LowerCase(Who);
  For i := 0 To N - 1 Do
    Begin
    NameSearch.GoToPosition(i);
    If LowerCase(NameSearch.GetName) = Want Then
      Begin
      Pos_ := i;
      Result := True;
      Exit;
      End;
    End;
  End;


Function HwUserSet(Const Who, Field, Value: String; OnLine: TStrings; Out UserName, Err: String): Boolean;
  Var
    P: Integer;
    Sec: SecType;
    V: LongInt;
    F: String;
    Bit: Integer;

  Begin
  Result := False;
  UserName := '';
  Err := '';
  NameSearch.Init;
  NameSearch.SetBbsType(DetectBbsType);
  NameSearch.SetCreate(False);
  If Not FindUser(Who, P) Then
    Begin
    Err := 'no such user';
    Exit;
    End;
  If NameSearch.IsDeleted Then
    Begin
    Err := 'that user is deleted';
    Exit;
    End;
  UserName := NameSearch.GetName;
  If (OnLine <> Nil) And (OnLine.IndexOf(LowerCase(UserName)) >= 0) Then
    Begin
    Err := 'that user is on line now: the change would be lost when the call ends';
    Exit;
    End;
  F := LowerCase(Field);
  V := StrToIntDef(Value, MaxLongInt);
  If F = 'city' Then
    NameSearch.SetLocation(Copy(Value, 1, 25))
  Else If (F = 'level') And (V >= 0) And (V <= 65535) Then
    Begin
    NameSearch.GetSec(Sec);
    Sec.Level := V;
    NameSearch.SetSec(Sec);
    End
  Else If (F = 'flags') And (V <> MaxLongInt) Then
    Begin
    NameSearch.GetSec(Sec);
    Sec.Flags := V;
    NameSearch.SetSec(Sec);
    End
  Else If ((F = 'flagon') Or (F = 'flagoff')) And (V >= 1) And (V <= 32) Then
    Begin
    NameSearch.GetSec(Sec);
    Bit := V - 1;
    If F = 'flagon' Then
      Sec.Flags := Sec.Flags Or LongInt(1 Shl Bit)
    Else
      Sec.Flags := Sec.Flags And Not LongInt(1 Shl Bit);
    NameSearch.SetSec(Sec);
    End
  Else If (F = 'elapsed') And (V >= 0) And (V <= 65535) Then
    NameSearch.SetElapsed(V)
  Else If (F = 'credit') And (V >= -32768) And (V <= 32767) Then
    NameSearch.SetNMCredit(V)
  Else
    Begin
    Err := 'the fields to set are level, flags, flagon, flagoff, city, elapsed and credit, with a value that fits';
    Exit;
    End;
  NameSearch.SaveChanges;
  If Not NameSearch.SaveOk Then
    Begin
    Err := 'the user file could not be written';
    Exit;
    End;
  Result := True;
  End;


Function HwNodeCommand(Const RunDir: String; Node: Integer; Tag: Char; Arg: Byte; Out Reply: String): Boolean;
  Var
    S: LongInt;
    A: TUnixSockAddr;
    Path, Buf, Hd: String;
    Raw: Array[0..4095] Of Char;
    N, p, q: LongInt;
    P_: TPollFd;
    T: Integer;

  Begin
  Result := False;
  Reply := '';
  Path := RunDir + '/node' + IntToStr(Node) + '.snoop';
  If (RunDir = '') Or (Length(Path) > 100) Then
    Begin
    Reply := 'the run directory is not known';
    Exit;
    End;
  S := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  If S < 0 Then
    Exit;
  FillChar(A, SizeOf(A), 0);
  A.family := AF_UNIX;
  Move(Path[1], A.path, Length(Path));
  If fpConnect(S, @A, SizeOf(A)) <> 0 Then
    Begin
    fpClose(S);
    Reply := 'node ' + IntToStr(Node) + ' cannot be reached';
    Exit;
    End;
  Hd := Tag;
  If (Tag = '+') Or (Tag = '-') Then
    Hd := Hd + Chr(Arg);
  fpSend(S, @Hd[1], Length(Hd), MSG_NOSIGNAL);
  Buf := '';
  T := 0;
  While T < 40 Do                                   {up to 2 seconds for the answer: ESC _ text ESC \ }
    Begin
    P_.fd := S;
    P_.events := POLLIN;
    P_.revents := 0;
    If fpPoll(@P_, 1, 50) > 0 Then
      Begin
      N := fpRecv(S, @Raw[0], SizeOf(Raw), MSG_NOSIGNAL);
      If N <= 0 Then
        Break;
      SetLength(Hd, N);
      Move(Raw[0], Hd[1], N);
      Buf := Buf + Hd;
      End;
    p := Pos(#27'_', Buf);
    If p > 0 Then
      Begin
      q := Pos(#27'\', Copy(Buf, p + 2, Length(Buf)));
      If q > 0 Then
        Begin
        Reply := Copy(Buf, p + 2, q - 1);
        Result := True;
        Break;
        End;
      End;
    Inc(T);
    End;
  fpClose(S);
  If (Not Result) And (Reply = '') Then
    Reply := 'node ' + IntToStr(Node) + ' did not answer';
  End;


End.
