{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKSetup;

{$mode objfpc}{$H+}

{
     mksetup: makes a new BBS that mk can run: the folder, a default configuration, the language file, two message areas, a file area with an example file, a sample door, the menu and the text screens
     mk looks for.  The sysop then changes what he wants with mkconfig, mkmenu, mkdraw and mkusered.  It only makes: a folder that has a configuration is never touched.

       mksetup [-d dir] [-n "BBS name"] [-s "Sysop name"] [-l american|english] [-L language dir] [-u] [-p password] [-N] [-y]

         -d DIR    the BBS folder (default /opt/bbs); made when it is not there
         -n NAME   the name of the BBS (default "My BBS")
         -s NAME   the name of the sysop (default "Sysop")
         -l LANG   the language: american (default) or english
         -L DIR    where the compiled language files (AMERICAN.lc ...) and games/ are looked for (default: next to the programs, /usr/local/share/mkbbs, /usr/share/mkbbs)
         -u        also make the account of the sysop (the sysop name, security level 110, no need to be the first to register); -p gives its password, else one is made up and shown once
         -p PW     the password of that account (4 to 15 characters; implies -u)
         -N        do not make mklisten.json (the listener configuration: a telnet port 2323 and the sysop monitor on 127.0.0.1:2330 with a made-up password, shown once)
         -y        no questions: what is not given by an option is the default (no account, mklisten.json made)

     Without -y a question is asked for each of the first four that was not given, and whether to make the sysop account and mklisten.json.  The exit code: 0 done, 1 not usable (a bad option, no language file, a folder that cannot be made), 2 the folder
     has a configuration already.
}

Uses SysUtils, Classes, BaseUnix,
  MKGlobT, MKCfgAbs, MKCfgMK, MKCfgNew, Default, MKOpen, MKMsgAbs, MKMsgMer, MKDoor, MKPwd, sha1;

Var
  Dir, BbsName, SysopName, Lang, ShareDir, SysopPwd, MonPwd: String;
  Yes, MakeUser, MakeListen, GivenUser: Boolean;
  ExeDir: String;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mksetup: ', S);
  Halt(Code);
  End;


Function Slash(S: String): String;
  Begin
  If (S <> '') And (S[Length(S)] <> '/') Then
    Result := S + '/'
  Else
    Result := S;
  End;


Function Ask(Question, Default: String): String;
  Begin
  Write(Question, ' [', Default, ']: ');
  Result := '';
  If Not Eof(Input) Then
    ReadLn(Result);
  Result := Trim(Result);
  If Result = '' Then
    Result := Default;
  End;


Procedure Say(S: String);
  Begin
  WriteLn(S);
  End;


Procedure MakeDir(P: String);
  Begin
  If Not ForceDirectories(P) Then
    Die(1, 'cannot make the folder ' + P);
  End;


Procedure PutText(FN, Text: String);
  Var
    T: TStringList;

  Begin
  T := TStringList.Create;
  Try
    T.Text := Text;
    T.SaveToFile(FN);
  Finally
    T.Free;
  End;
  End;


Procedure CopyFile_(From, To_: String);
  Var
    S, D: TFileStream;

  Begin
  S := TFileStream.Create(From, fmOpenRead Or fmShareDenyNone);
  Try
    D := TFileStream.Create(To_, fmCreate);
    Try
      D.CopyFrom(S, 0);
    Finally
      D.Free;
    End;
  Finally
    S.Free;
  End;
  End;


Function FindShare(Const Sub, Name: String): String;
  {a file of the program's resources: -L dir, next to the programs (the source tree), then the installed places}
  Var
    C: Array[0..5] Of String;
    i: Integer;

  Begin
  If ShareDir <> '' Then
    C[0] := Slash(ShareDir) + Sub
  Else
    C[0] := '';
  C[1] := ExeDir + '../' + Sub;
  C[2] := ExeDir + '../share/mkbbs/' + Sub;
  C[3] := '/usr/local/share/mkbbs/' + Sub;
  C[4] := '/usr/share/mkbbs/' + Sub;
  C[5] := ExeDir + Sub;
  Result := '';
  For i := 0 To 5 Do
    If (C[i] <> '') And FileExists(Slash(C[i]) + Name) Then
      Begin
      Result := Slash(C[i]) + Name;
      Exit;
      End;
  End;


Function BbsId_(S: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If UpCase(S[i]) In ['A'..'Z', '0'..'9'] Then
      If Length(Result) < 8 Then
        Result := Result + UpCase(S[i]);
  If Result = '' Then
    Result := 'MKBBS';
  End;


{------------------------------------------------------------ the menus}

Procedure MenuItem(Var F: File; Typ: Byte; Key: Char; Prompt, Data: String; Fg: Byte);
  Var
    R: MenuType;

  Begin
  FillChar(R, SizeOf(R), 0);
  R.Typ := Typ;
  R.Prompt := Prompt;
  R.Key := Key;
  R.Data := Data;
  R.FgColor := Fg;
  R.BgColor := 0;
  BlockWrite(F, R, 1);
  End;


Procedure Pair(Var F: File; T1: Byte; K1: Char; P1, D1: String; T2: Byte; K2: Char; P2, D2: String);
  Var
    Vis, i: Integer;
    L: String;

  Begin
  Vis := 0;
  For i := 1 To Length(P1) Do
    If P1[i] <> '^' Then
      Inc(Vis);
  L := P1;
  While Vis < 32 Do
    Begin
    L := L + ' ';
    Inc(Vis);
    End;
  MenuItem(F, T1, K1, L + ';', D1, 7);
  MenuItem(F, T2, K2, P2, D2, 7);
  End;


Procedure WriteTopMenu(MenuDir: String);
  {top.mnu: the menu mk starts with.  Record 0 is the header: the prompt, its colour (Fg, Bg) and the highlight colour (Typ, Security).}
  Var
    F: File;
    H: MenuType;

  Begin
  Assign(F, MenuDir + 'top.mnu');
  Rewrite(F, SizeOf(MenuType));
  FillChar(H, SizeOf(H), 0);
  H.Typ := 15;                         {highlight: bright white}
  H.Security := 0;
  H.Prompt := 'Command > ';
  H.Key := #0;
  H.FgColor := 11;
  H.BgColor := 0;
  BlockWrite(F, H, 1);
  MenuItem(F, 0, ' ', '', '', 7);
  MenuItem(F, 0, ' ', '^Main menu^', '', 7);
  MenuItem(F, 0, ' ', 'Messages: \kY   Files: \kZ', '', 7);
  MenuItem(F, 0, ' ', '', '', 7);
  { two columns: the left item keeps the line (a ; at the end of its prompt), padded to the width of the column }
  Pair(F, 23, 'R', '(^R^)ead messages', '/M', 27, 'P', '(^P^)ost a message', '/M');
  Pair(F, 49, 'J', '(^J^)ump to a message area', '', 22, 'C', '(^C^)heck for your mail', '');
  Pair(F, 31, 'F', '(^F^)ile list', '/F', 32, 'D', '(^D^)ownload a file', '/F');
  Pair(F, 33, 'U', '(^U^)pload a file', '/F', 50, 'A', 'Select a file (^A^)rea', '');
  Pair(F, 13, 'L', '(^L^)ist of users', '', 52, 'W', '(^W^)ho is on', '');
  Pair(F, 14, 'T', 'Your (^T^)ime statistics', '', 11, 'S', 'Page the (^S^)ysop', '');
  Pair(F, 170, 'B', 'Cows and (^B^)ulls, a game', 'games/cowsandbulls.pas', 8, 'V', '(^V^)ersion of the BBS', '');
  MenuItem(F, 9, 'G', '(^G^)oodbye, log off', '', 7);
  Close(F);
  End;


{------------------------------------------------------------ passwords, the account, the listener}

Function MadeUpPassword(N: Integer): String;
  {letters and digits without the ones that look alike}
  Const
    Chars = 'abcdefghjkmnpqrstuvwxyz23456789';

  Var
    Fs: TFileStream;
    B: Array[0..31] Of Byte;
    i: Integer;

  Begin
  Fs := TFileStream.Create('/dev/urandom', fmOpenRead);
  Try
    Fs.ReadBuffer(B, SizeOf(B));
  Finally
    Fs.Free;
  End;
  Result := '';
  For i := 0 To N - 1 Do
    Result := Result + Chars[(B[i] Mod Length(Chars)) + 1];
  End;


Procedure MakeSysopUser(Cfg: MKCfgObjPtr);
  {the account of the sysop, written the way mk writes a new caller (users.bbs, extusers.bbs, usersidx.bbs; the password hashed when the configuration says so)}
  Var
    Sec: SecType;
    D: String;

  Begin
  Config := Cfg;
  PwdModeFromConfig;
  User.Init;
  User.SetUserBbsType(1);
  User.SetUserName(SysopName);
  User.SetUserCity('');
  User.SetUserPwd(SysopPwd);
  Sec.Level := 110;
  Sec.Flags := -1;
  User.SetUserSec(Sec);
  User.SetUserLastDate('00-00-00');
  User.SetUserCredit(0);
  User.SetUserScrLength(23);
  User.SetUserPageTune(1);
  D := FormatDateTime('mm-dd-yy', Now);
  User.SetUserFirstDate(D);
  User.SetUserMore(True);
  User.SetUserScrnClr(True);
  User.SetUserMsgTemplate(1);
  User.SetUserFileTemplate(1);
  User.AddUser;
  User.Done;
  End;


Function JsonStr(S: String): String;
  Begin
  Result := StringReplace(StringReplace(S, '\', '\\', [rfReplaceAll]), '"', '\"', [rfReplaceAll]);
  End;


Procedure MakeListenFile(Dir: String);
  Var
    MkPath, P: String;
    T: TStringList;

  Begin
  MkPath := ExeDir + 'mk';
  If Not FileExists(MkPath) Then
    Begin
    MkPath := ExeSearch('mk', GetEnvironmentVariable('PATH'));
    If MkPath = '' Then
      MkPath := '/usr/bin/mk';
    End;
  MakeDir(Dir + 'logs/');
  MakeDir(Dir + 'run/');
  MonPwd := MadeUpPassword(12);
  T := TStringList.Create;
  Try
    T.Add('{');
    T.Add('  "_note": "made by mksetup: check it with   mklisten -c ' + Dir + 'mklisten.json -t   start it with   mklisten -c ' + Dir + 'mklisten.json   (MKLISTEN.md)",');
    T.Add('  "mk": "' + JsonStr(MkPath) + '",');
    T.Add('  "logfile": "' + JsonStr(Dir + 'logs/mklisten.log') + '",');
    T.Add('  "rundir": "' + JsonStr(Dir + 'run') + '",');
    T.Add('  "workdir": "' + JsonStr(ExcludeTrailingPathDelimiter(Dir)) + '",');
    T.Add('  "nodes": "1-4",');
    T.Add('  "localnode": 9,');
    T.Add('  "ports": [');
    T.Add('    { "port": 2323, "type": "telnet", "baud": 38400, "charset": "auto", "config": "' + JsonStr(ExcludeTrailingPathDelimiter(Dir)) + '" },');
    T.Add('    { "_note": "the sysop monitor: telnet to 127.0.0.1:2330 (from elsewhere through ssh -L 2330:127.0.0.1:2330); the password is kept as a sha1 hash",');
    T.Add('      "port": 2330, "type": "sysop", "bind": "127.0.0.1", "password": "sha1:' + LowerCase(SHA1Print(SHA1String(MonPwd))) + '", "config": "' + JsonStr(ExcludeTrailingPathDelimiter(Dir)) + '" }');
    T.Add('  ]');
    T.Add('}');
    P := Dir + 'mklisten.json';
    T.SaveToFile(P);
  Finally
    T.Free;
  End;
  fpChmod(PChar(P), &600);
  End;


{------------------------------------------------------------ the main work}

Const
  CfgFiles: Array[0..3] Of String = ('config.mk', 'messages.mk', 'files.mk', 'bbsconfig.json');
  SubDirs: Array[0..4] Of String = ('node1/', 'mail/', 'attach/', 'sem/', 'nodelist/');
  DataFiles: Array[0..6] Of String = ('users.bbs', 'extusers.bbs', 'usersidx.bbs', 'useron.bbs', 'timelog.bbs', 'exitinfo.bbs', 'lastread.bbs');

Var
  i: Integer;
  A: String;
  Cfg: MKCfgObjPtr;
  Sec: SecType;
  Msg: AbsMsgPtr;
  Id, Found, LangSrc, MenuLc, GameSrc, MsgDir, MenuDir, TxtDir, FileDir, GamesDir: String;
  Names: Array[1..2] Of String;
  SR: TSearchRec;

Begin
Dir := '';
BbsName := '';
SysopName := '';
Lang := '';
ShareDir := '';
Yes := False;
MakeUser := False;
GivenUser := False;
MakeListen := True;
SysopPwd := '';
MonPwd := '';
ExeDir := ExtractFilePath(ExpandFileName(ParamStr(0)));
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-y' Then
    Yes := True
  Else If A = '-u' Then
    Begin
    MakeUser := True;
    GivenUser := True;
    End
  Else If A = '-N' Then
    MakeListen := False
  Else If (A = '-d') Or (A = '-n') Or (A = '-s') Or (A = '-l') Or (A = '-L') Or (A = '-p') Then
    Begin
    Inc(i);
    If i > ParamCount Then
      Die(1, A + ' needs a value');
    If A = '-d' Then Dir := ParamStr(i)
    Else If A = '-n' Then BbsName := ParamStr(i)
    Else If A = '-s' Then SysopName := ParamStr(i)
    Else If A = '-l' Then Lang := LowerCase(ParamStr(i))
    Else If A = '-p' Then
      Begin
      SysopPwd := ParamStr(i);
      MakeUser := True;
      GivenUser := True;
      End
    Else ShareDir := ParamStr(i);
    End
  Else
    Begin
    WriteLn('usage: mksetup [-d dir] [-n "BBS name"] [-s "Sysop name"] [-l american|english] [-L language dir] [-u] [-p password] [-N] [-y]');
    Halt(1);
    End;
  Inc(i);
  End;
If Not Yes Then
  Begin
  WriteLn('mksetup makes a new BBS: a folder, a configuration, a menu and a few screens that mk can run with.');
  WriteLn;
  If Dir = '' Then Dir := Ask('BBS folder', '/opt/bbs');
  If BbsName = '' Then BbsName := Ask('Name of the BBS', 'My BBS');
  If SysopName = '' Then SysopName := Ask('Name of the sysop', 'Sysop');
  If Lang = '' Then Lang := Ask('Language (american or english)', 'american');
  If Not GivenUser Then
    MakeUser := UpperCase(Copy(Ask('Make the account of the sysop now (y/n)', 'n'), 1, 1)) = 'Y';
  If MakeUser And (SysopPwd = '') Then
    SysopPwd := Ask('Password of the sysop (Enter = make one up)', '');
  If MakeListen Then
    MakeListen := UpperCase(Copy(Ask('Make mklisten.json, the listener configuration (y/n)', 'y'), 1, 1)) = 'Y';
  End;
If MakeUser And (SysopPwd = '') Then
  Begin
  SysopPwd := MadeUpPassword(10);
  Say('(no password given: one is made up)');
  End;
If MakeUser And ((Length(SysopPwd) < 4) Or (Length(SysopPwd) > 15)) Then
  Die(1, 'the password of the sysop is 4 to 15 characters');
If Dir = '' Then Dir := '/opt/bbs';
If BbsName = '' Then BbsName := 'My BBS';
If SysopName = '' Then SysopName := 'Sysop';
If Lang = '' Then Lang := 'american';
If (Lang <> 'american') And (Lang <> 'english') Then
  Die(1, 'the language is american or english');
Dir := Slash(ExpandFileName(Dir));
If Length(Dir) + Length('files/area01/') > 50 Then
  Die(1, 'the folder name is too long: the configuration holds the path of a file area in 50 characters (' + Dir + 'files/area01/ is ' + IntToStr(Length(Dir) + 13) + ')');
If Length(Dir) + Length('nodelist/') > 60 Then
  Die(1, 'the folder name is too long: the configuration holds the other paths in 60 characters');
{ a folder that has a configuration is never touched }
For i := 0 To 3 Do
  If FileExists(Dir + CfgFiles[i]) Then
    Die(2, Dir + CfgFiles[i] + ' is there: ' + Dir + ' has a configuration already (mksetup only makes a new BBS)');
{ the language file and the sample game: found before anything is made }
LangSrc := FindShare('lang', UpperCase(Lang) + '.lc');
If LangSrc = '' Then
  LangSrc := FindShare('lang', UpperCase(Lang) + '.LC');
If LangSrc = '' Then
  Die(1, 'the language file ' + UpperCase(Lang) + '.lc was not found (use -L, or make lang)');
MenuLc := FindShare('lang', 'MKMENU.lc');
If MenuLc = '' Then
  MenuLc := FindShare('lang', 'MKMENU.LC');
GameSrc := FindShare('games', 'cowsandbulls.pas');
MsgDir := Dir + 'msgs/';
MenuDir := Dir + 'menus/';
TxtDir := Dir + 'txtfiles/';
FileDir := Dir + 'files/area01/';
GamesDir := Dir + 'games/';
Say('Making the BBS in ' + Dir);
MakeDir(Dir);
MakeDir(MsgDir);
MakeDir(MenuDir);
MakeDir(TxtDir);
MakeDir(FileDir);
MakeDir(GamesDir);
For i := 0 To 4 Do
  MakeDir(Dir + SubDirs[i]);
{ the language files: the prompts of mk, the texts of mkmenu }
CopyFile_(LangSrc, Dir + Lang + '.lc');
If MenuLc <> '' Then
  CopyFile_(MenuLc, Dir + 'mkmenu.lc')
Else
  Say('  (no MKMENU.lc found: mkmenu will say so; make lang)');
{ the configuration }
Cfg := New(MKCfgObjPtr, Init);
Cfg^.SetBbsType(1);
Cfg^.Allocate;
Cfg^.SetBbsPath(Dir);
Cfg^.CfgInfo^.SaveDir := Dir;
SetCfgDefaults(Cfg^);
SetMsgDefaults(Cfg^);
SetEchoDefaults(Cfg^);
SetFileDefaults(Cfg^);
Cfg^.SetBbsName(BbsName);
Cfg^.SetBbsLoc('');
Cfg^.SetBbsPhone('');
Cfg^.SetBbsId(BbsId_(BbsName));
Cfg^.SetSysopName(SysopName);
Cfg^.SetOrigStr(1, BbsName);
Cfg^.SetMsgPath(1, MsgDir);
Cfg^.SetTxtPath(1, TxtDir);
Cfg^.SetMnuPath(1, MenuDir);
Cfg^.SetNetPath(Dir + 'mail/');
Cfg^.SetTempPath(Dir + 'tmp/');
MakeDir(Dir + 'tmp/');
Cfg^.SetNodeListPath(Dir + 'nodelist/');
Cfg^.SetAttachPath(Dir + 'attach/');
Cfg^.SetSemaphorePath(Dir + 'sem/');
Cfg^.SetLogFileName(Dir + 'mk.log');
Cfg^.SetEchoLog(Dir + 'echotoss.log');
If Lang = 'american' Then
  Cfg^.SetLangName(1, 'American')
Else
  Cfg^.SetLangName(1, 'English');
Cfg^.SetLangFile(1, Lang);
Sec.Level := 10;
Sec.Flags := 0;
Cfg^.SetNewUserSec(Sec);
Cfg^.SetPageMsgArea(2);
{ no DOS packers: zip and unzip }
For i := 1 To 10 Do
  Cfg^.SetPackAvail(i, False);
Cfg^.SetPackAvail(2, True);
Cfg^.SetPackCmdLine(2, 'zip -q -j');
Cfg^.SetUnPackCmdLine(2, 'unzip -o -q');
{ the two message areas: Merlin bases, local only; nothing is purged by age }
Names[1] := 'General Messages';
Names[2] := 'Comments to the Sysop';
For i := 1 To 2 Do
  Begin
  Cfg^.SetMsgName(i, Names[i]);
  If i = 1 Then
    Begin
    Cfg^.SetMsgShortName(i, 'General');
    Cfg^.SetMsgFileId(i, 'gen.mer');
    End
  Else
    Begin
    Cfg^.SetMsgShortName(i, 'Sysop');
    Cfg^.SetMsgFileId(i, 'sys.mer');
    End;
  Cfg^.SetMsgBaseType(i, 'M');
  Cfg^.SetMsgPathNum(i, 1);
  Cfg^.SetMsgType(i, Normal);
  Cfg^.SetMsgDays(i, 0);
  Cfg^.SetMsgRcvdDays(i, 0);
  Cfg^.SetMsgsKept(i, 0);
  End;
{ the file area }
Cfg^.SetFileAreaName(1, 'Example Files');
Cfg^.SetFileShortName(1, 'Example');
Cfg^.SetFileAreaPath(1, FileDir);
Cfg^.Save;
If Cfg^.GetError <> 0 Then
  Die(1, IntToStr(Cfg^.GetError) + ': the configuration could not be written');
Say('  configuration: ' + Dir + 'config.mk, messages.mk, files.mk ...');
{ the message bases }
For i := 1 To 2 Do
  Begin
  Id := Cfg^.GetMsgAreaId(i);
  Msg := Nil;
  If Not OpenOrCreateMsgArea(Msg, Id) Then
    Die(1, 'the message base ' + Id + ' could not be made');
  If CloseMsgArea(Msg) Then;
  End;
Say('  message areas: General Messages, Comments to the Sysop (Merlin bases in ' + MsgDir + ')');
{ the file area: one file and its list }
PutText(FileDir + 'readme.txt', 'This is an example file in an example file area.' + LineEnding + 'Delete it, or keep it as a first download to try.');
PutText(FileDir + 'files.bbs', 'readme.txt    An example file: a few lines of text, to try a download.');
Say('  file area: ' + FileDir + ' (readme.txt and files.bbs)');
{ the sample door }
If GameSrc <> '' Then
  Begin
  CopyFile_(GameSrc, GamesDir + 'cowsandbulls.pas');
  Say('  sample door: ' + GamesDir + 'cowsandbulls.pas (menu key B)');
  End
Else
  Say('  (cowsandbulls.pas was not found: the B item of the menu will say so)');
{ the menu and the screens }
WriteTopMenu(MenuDir);
Say('  menu: ' + MenuDir + 'top.mnu');
PutText(TxtDir + 'welcome.asc', LineEnding + 'Welcome to ' + BbsName);
PutText(TxtDir + 'goodbye.asc', LineEnding + 'Thank you for visiting ' + BbsName);
PutText(TxtDir + 'newuser1.asc', LineEnding + 'Welcome, new caller.');
Say('  screens: welcome, goodbye, newuser1 in ' + TxtDir);
{ the data files of the callers, empty: mk looks for them in the BBS folder first and makes a missing one in the folder it was started in }
For i := 0 To 6 Do
  PutText(Dir + DataFiles[i], '');
{ the questionnaire every new caller goes through (a script; it only has to be there) and the time and download limits of each security level }
PutText(Dir + 'newuser.q-a', 'Display "|Thank you for registering.||"');
PutText(Dir + 'limits.ctl', '; security level, minutes a day, download limit in K (for every speed)' + LineEnding + '5 30 0' + LineEnding + '10 60 5000' + LineEnding + '50 120 20000' + LineEnding + '100 240 99999');
Say('  newuser.q-a (the questionnaire of a new caller) and limits.ctl (time and download limits for the levels)');
If MakeUser Then
  Begin
  MakeSysopUser(Cfg);
  Say('  account of the sysop: ' + SysopName + ' (security level 110)');
  End;
If MakeListen Then
  Begin
  MakeListenFile(Dir);
  Say('  listener configuration: ' + Dir + 'mklisten.json (telnet 2323, sysop monitor 127.0.0.1:2330)');
  End;
Cfg^.Done;
WriteLn;
If MakeUser Then
  Say('Sysop account:  ' + SysopName + '  password  ' + SysopPwd + '   (shown only now)');
If MakeListen Then
  Say('Sysop monitor:  telnet 127.0.0.1 2330   password  ' + MonPwd + '   (shown only now; mklisten.json holds a hash)');
If MakeUser Or MakeListen Then
  WriteLn;
Say('Done.  Try it:   MK=' + ExcludeTrailingPathDelimiter(Dir) + ' mk -L');
Say('Change it:       MK=' + ExcludeTrailingPathDelimiter(Dir) + ' mkconfig | mkmenu | mkdraw | mkusered');
If MakeListen Then
  Say('Let callers in:  mklisten -c ' + Dir + 'mklisten.json -t   then without -t');
End.
