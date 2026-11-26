Program MKCheck;

{$mode objfpc}{$H+}

{
     mkcheck: looks at a BBS and says what would stop mk from running it, or from running it well.  It changes nothing.

       mkcheck [-c config dir] [-l mklisten.json] [-q] [-v]

         -c DIR    the BBS configuration directory (default: the environment MK)
         -l FILE   the listener configuration to check with mklisten -t (default: mklisten.json in the BBS folder when it is there)
         -q        only what is not right
         -v        also the small things that were fine

     Each line starts with  ok  (fine),  info  (to know),  WARN  (works, but probably not what you want) or  FAIL  (mk will not work, or not for a new caller).  What is looked at:
       the configuration and the folders it names; the language file; the menus (every item: the menus it goes to, the screens, the programs and games it runs, the questionnaires; a way to log off);
       the files a new caller needs (newuser.q-a, limits.ctl) and the screens mk shows; the message areas (each base is opened), the file areas; the user files (sizes in step, the account of the sysop);
       and the security of a new caller against the areas; the listener configuration.
     The exit code: 0 nothing FAIL (WARN is possible), 1 not usable (no configuration), 2 something FAIL.
}

Uses SysUtils, Classes, BaseUnix, Unix, Process,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKOpen, MKMsgAbs, MKPwd, MKDoorCfg, MKSandbox, MKUpCfg, MKExtCfg;

Var
  Quiet, Verbose: Boolean;
  NFail, NWarn, NInfo: Integer;
  BbsDir, ConfDir, ListenFile: String;
  DoorCfg: TDoorCfg;                 {doors.cfg, loaded when the first menu item that runs a door is seen}
  DoorCfgOk: Boolean;


Procedure Out_(Tag, S: String);
  Begin
  If (Tag = 'ok  ') And (Not Verbose) Then
    Exit;
  If (Quiet And ((Tag = 'ok  ') Or (Tag = 'info'))) Then
    Exit;
  WriteLn(Tag, ' ', S);
  End;


Procedure Ok(S: String);
  Begin
  Out_('ok  ', S);
  End;

Procedure Info(S: String);
  Begin
  Inc(NInfo);
  Out_('info', S);
  End;

Procedure Warn(S: String);
  Begin
  Inc(NWarn);
  Out_('WARN', S);
  End;

Procedure Fail(S: String);
  Begin
  Inc(NFail);
  Out_('FAIL', S);
  End;


Function Slash(S: String): String;
  Begin
  If (S <> '') And (S[Length(S)] <> '/') Then
    Result := S + '/'
  Else
    Result := S;
  End;


Function Rel(P: String): String;
  {a path from the configuration or a menu: DOS slashes become /, a relative one is relative to the BBS folder}
  Begin
  Result := StringReplace(P, '\', '/', [rfReplaceAll]);
  If (Result <> '') And (Result[1] <> '/') Then
    Result := BbsDir + Result;
  End;


Function FirstWord(S: String): String;
  Var
    p: Integer;

  Begin
  S := Trim(S);
  p := Pos(' ', S);
  If p = 0 Then
    Result := S
  Else
    Result := Copy(S, 1, p - 1);
  End;


Function FileSz(FN: String): Int64;
  Var
    SR: TSearchRec;

  Begin
  Result := -1;
  If FindFirst(FN, faAnyFile, SR) = 0 Then
    Begin
    Result := SR.Size;
    FindClose(SR);
    End;
  End;


Function OnPath(Prog: String): Boolean;
  Begin
  Result := ExeSearch(Prog, GetEnvironmentVariable('PATH')) <> '';
  End;


{------------------------------------------------------------ the pieces}

Procedure CheckFolders;
  Var
    i: Integer;
    D: String;
    Names: Array[0..6] Of String;
    Paths: Array[0..6] Of String;

  Begin
  If fpAccess(PChar(BbsDir), W_OK) <> 0 Then
    Warn('the BBS folder ' + BbsDir + ' cannot be written by this user: mk, run as this user, cannot make or change its data files')
  Else
    Ok('the BBS folder ' + BbsDir + ' is there and can be written');
  Names[0] := 'message base folder'; Paths[0] := Config^.GetMsgPath(1);
  Names[1] := 'menu folder'; Paths[1] := Config^.GetMnuPath(1);
  Names[2] := 'screen folder'; Paths[2] := Config^.GetTxtPath(1);
  Names[3] := 'netmail folder'; Paths[3] := Config^.GetNetPath;
  Names[4] := 'temporary files folder'; Paths[4] := Config^.GetTempPath;
  Names[5] := 'node list folder'; Paths[5] := Config^.GetNodeListPath;
  Names[6] := 'attach folder'; Paths[6] := Config^.GetAttachPath;
  For i := 0 To 6 Do
    Begin
    D := Paths[i];
    If D = '' Then
      Begin
      If i <= 2 Then
        Fail('the ' + Names[i] + ' is not set (mkconfig: System Paths)')
      Else
        Info('the ' + Names[i] + ' is not set');
      End
    Else If Not DirectoryExists(Rel(D)) Then
      Begin
      If i <= 2 Then
        Fail('the ' + Names[i] + ' ' + D + ' is not there')
      Else
        Warn('the ' + Names[i] + ' ' + D + ' is not there')
      End
    Else
      Ok('the ' + Names[i] + ' ' + D);
    End;
  D := Config^.GetLogFileName;
  If (D <> '') And Not DirectoryExists(ExtractFilePath(Rel(D))) Then
    Warn('the folder of the log file ' + D + ' is not there: the BBS cannot write its log');
  End;


Procedure CheckLanguage;
  Var
    i: Integer;
    F: String;

  Begin
  For i := 1 To 10 Do
    If Config^.GetLangFile(i) <> '' Then
      Begin
      F := Config^.FindBbsFile(Config^.GetLangFile(i) + '.lc') + Config^.GetLangFile(i) + '.lc';
      If FileSz(F) < 0 Then
        Begin
        If i = 1 Then
          Fail('the language file ' + Config^.GetLangFile(i) + '.lc is not in the BBS folder: mk shows no prompts (mklc makes it from the .TXT file; mksetup copies it)')
        Else
          Warn('the language file ' + Config^.GetLangFile(i) + '.lc of language ' + IntToStr(i) + ' is not there')
        End
      Else If FileSz(F) < 2000 Then
        Warn('the language file ' + F + ' is very small (' + IntToStr(FileSz(F)) + ' bytes)')
      Else
        Ok('language ' + IntToStr(i) + ' (' + Config^.GetLangName(i) + '): ' + F);
      End;
  If FileSz(Config^.FindBbsFile('mkmenu.lc') + 'mkmenu.lc') < 0 Then
    Info('mkmenu.lc is not in the BBS folder: the menu editor (mkmenu) will say so');
  End;


Var
  KnownMenus: TStringList;


Function FindNoCase(Dir, Name: String): String;
  {a file of Dir whose name is Name in upper or lower case (DOS names): its real name, '' when there is none}
  Var
    SR: TSearchRec;

  Begin
  FindNoCase := '';
  If FindFirst(Dir + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If LowerCase(SR.Name) = LowerCase(Name) Then
        FindNoCase := SR.Name;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Function WordCountOf(S: String): Integer;
  Var
    L: TStringList;

  Begin
  L := TStringList.Create;
  Try
    L.Delimiter := ' ';
    L.StrictDelimiter := True;
    L.DelimitedText := Trim(S);
    WordCountOf := L.Count;
    If Trim(S) = '' Then
      WordCountOf := 0;
  Finally
    L.Free;
  End;
  End;


Function NthWord(S: String; n: Integer): String;
  Var
    L: TStringList;

  Begin
  L := TStringList.Create;
  Try
    L.Delimiter := ' ';
    L.StrictDelimiter := True;
    L.DelimitedText := Trim(S);
    NthWord := L[n - 1];
  Finally
    L.Free;
  End;
  End;


Procedure CheckDoorItem(MenuName: String; Item: Integer; Key, Data: String);
  {menu command 172: the door is in doors.cfg, and what it needs is there}
  Var
    Name, Prefix, W, Dos: String;
    i, j: Integer;

  Begin
  Name := Trim(Data);
  If Pos(' ', Name) > 0 Then
    Name := Copy(Name, 1, Pos(' ', Name) - 1);
  Prefix := 'menu ' + MenuName + ' item ' + IntToStr(Item) + ' (' + Key + '): ';
  If DoorCfg = Nil Then
    Begin
    DoorCfg := TDoorCfg.Create;
    DoorCfg.Load(BbsDir + 'doors.cfg');
    DoorCfgOk := FileExists(BbsDir + 'doors.cfg');
    For i := 0 To DoorCfg.Problems.Count - 1 Do
      Warn('doors.cfg ' + DoorCfg.Problems[i]);
    End;
  If Name = '' Then
    Begin
    Warn(Prefix + 'runs a door but names none (the data is the name of a door in doors.cfg)');
    Exit;
    End;
  If Not DoorCfgOk Then
    Begin
    Warn(Prefix + 'runs the door ' + Name + ', and there is no doors.cfg in ' + BbsDir);
    Exit;
    End;
  i := DoorCfg.Find(Name);
  If i < 0 Then
    Begin
    Warn(Prefix + 'runs the door ' + Name + ', which is not in doors.cfg');
    Exit;
    End;
  With DoorCfg.Doors[i] Do
    Begin
    If Command = '' Then
      Warn(Prefix + 'the door ' + Name + ' has no command in doors.cfg');
    For j := 1 To WordCountOf(DropFiles) Do
      If Pos(' ' + NthWord(DropFiles, j) + ' ', ' dorinfo1.def door.sys callinfo.bbs door32.sys ') = 0 Then
        Warn(Prefix + 'the door ' + Name + ' names the drop file ' + NthWord(DropFiles, j) + ', which MK does not write (dorinfo1.def door.sys callinfo.bbs door32.sys)');
    If (Kind = 'dos') And DropFilesWanted(DoorCfg.Doors[i], 'door32.sys') Then
      Warn(Prefix + 'door32.sys is for native doors: a DOS door in dosemu2 does not get it');
    If (Dir = '') Or Not DirectoryExists(Dir) Then
      Begin
      Warn(Prefix + 'the directory of the door ' + Name + ' is not there: ' + Dir);
      Exit;
      End;
    W := Trim(Command);
    If Pos(' ', W) > 0 Then
      W := Copy(W, 1, Pos(' ', W) - 1);
    If (W <> '') And (Pos('/', W) = 0) And (Pos('\', W) = 0) And (FindNoCase(IncludeTrailingPathDelimiter(Dir), W) = '') And
       ((Kind = 'dos') Or Not OnPath(W)) Then
      Warn(Prefix + 'the command ' + W + ' of the door ' + Name + ' is not in ' + Dir);
    If Sandbox <> 'off' Then
      Begin
      If FindBwrap(DoorCfg.SbProgram) = '' Then
        Warn(Prefix + 'the door ' + Name + ' runs in the sandbox (sandbox = ' + Sandbox + ') and bwrap (bubblewrap) is not installed: the door will not be run')
      Else If Not SandboxWorks(FindBwrap(DoorCfg.SbProgram), Dos) Then
        Warn(Prefix + 'the door ' + Name + ' runs in the sandbox and ' + Dos);
      For j := 0 To Binds.Count - 1 Do
        If Not (DirectoryExists(Binds[j]) Or FileExists(Binds[j])) Then
          Warn(Prefix + 'the door ' + Name + ': bind = ' + Binds[j] + ' is not there');
      For j := 0 To ROBinds.Count - 1 Do
        If Not (DirectoryExists(ROBinds[j]) Or FileExists(ROBinds[j])) Then
          Warn(Prefix + 'the door ' + Name + ': robind = ' + ROBinds[j] + ' is not there');
      End;
    If Kind = 'dos' Then
      Begin
      Dos := DoorCfg.Dosemu;
      If Dos = '' Then
        Dos := GetEnvironmentVariable('MKDOS_DOSEMU');
      If Dos = '' Then
        Dos := 'dosemu';
      If (Pos('/', Dos) = 0) And Not OnPath(Dos) Then
        Warn(Prefix + 'the door ' + Name + ' needs dosemu2, which is not on the PATH (doors.cfg: dosemu = ...)')
      Else If (Pos('/', Dos) > 0) And Not FileExists(Dos) Then
        Warn(Prefix + 'the door ' + Name + ' needs dosemu2, but ' + Dos + ' is not there');
      End;
    End;
  End;


Var
  UploadsChecked: Boolean = False;


Procedure CheckUploads;
  {uploads.cfg (menu command 173): what it says can be done here}
  Var
    C: TUpCfg;
    i, j: Integer;
    W, Why, Q: String;
    Bw: String;
    Fn: String;

  Procedure Prog(Const Cmd, What: String);
    Var
      A: TStringList;

    Begin
    If Trim(Cmd) = '' Then
      Exit;
    A := TStringList.Create;
    Try
      If SplitCommand(Cmd, 'file', BbsDir, A) Then
        Begin
        W := A[0];
        If (Pos('/', W) > 0) And Not FileExists(W) Then
          Warn('uploads.cfg: ' + What + ': ' + W + ' is not there (uploads of that kind are accepted without it)')
        Else If (Pos('/', W) = 0) And Not OnPath(W) Then
          Warn('uploads.cfg: ' + What + ': ' + W + ' is not installed (a test is skipped; a missing scanner refuses the file unless scanfail = accept)');
        End;
    Finally
      A.Free;
    End;
    End;

  Begin
  If UploadsChecked Then
    Exit;
  UploadsChecked := True;
  Fn := BbsDir + 'uploads.cfg';
  If Not FileExists(Fn) Then
    Begin
    Info('there is no uploads.cfg: uploaded files are accepted without a test, a scanner or a FILE_ID.DIZ');
    Exit;
    End;
  C := TUpCfg.Create;
  Try
    C.Load(Fn);
    For i := 0 To C.Problems.Count - 1 Do
      Warn('uploads.cfg ' + C.Problems[i]);
    Prog(C.Scan, 'the scanner');
    For i := 0 To High(C.Types) Do
      Begin
      Prog(C.Types[i].Test, 'the test of ' + Trim(C.Types[i].Exts));
      Prog(C.Types[i].Diz, 'the DIZ command of ' + Trim(C.Types[i].Exts));
      End;
    For i := 0 To High(C.Areas) Do
      Begin
      Prog(C.Areas[i].Scan, 'the scanner of area ' + IntToStr(C.Areas[i].Num));
      If Config^.GetFileAreaName(C.Areas[i].Num) = '' Then
        Warn('uploads.cfg: [area ' + IntToStr(C.Areas[i].Num) + '] is not a file area');
      End;
    If C.Sandbox Then
      Begin
      Bw := FindBwrap('');
      If Bw = '' Then
        Warn('uploads.cfg: the tests run in the sandbox and bwrap (bubblewrap) is not installed: they run unwrapped')
      Else If Not SandboxWorks(Bw, Why) Then
        Warn('uploads.cfg: the tests run in the sandbox and ' + Why + ': they run unwrapped');
      End
    Else
      Info('uploads.cfg: sandbox = off: the tests and the scanner run with the rights of the BBS user');
    For j := 0 To C.ROBinds.Count - 1 Do
      If Not (DirectoryExists(C.ROBinds[j]) Or FileExists(C.ROBinds[j])) Then
        Warn('uploads.cfg: robind = ' + C.ROBinds[j] + ' is not there');
    For j := 0 To C.Binds.Count - 1 Do
      If Not (DirectoryExists(C.Binds[j]) Or FileExists(C.Binds[j])) Then
        Warn('uploads.cfg: bind = ' + C.Binds[j] + ' is not there');
    If C.QuarSet Then
      Q := C.Quarantine
    Else
      Q := BbsDir + 'quarantine';
    If (Q <> '') And (Not DirectoryExists(Q)) And (Not ForceDirectories(Q)) Then
      Warn('uploads.cfg: the quarantine directory ' + Q + ' cannot be made')
    Else If (Q <> '') And (fpAccess(PChar(Q), W_OK) <> 0) Then
      Warn('uploads.cfg: the quarantine directory ' + Q + ' cannot be written');
    If C.Scan = '' Then
      Info('uploads.cfg: no scanner is set (scan = ...): uploaded files are not scanned');
  Finally
    C.Free;
  End;
  End;


Procedure CheckExtensions;
  {extensions.cfg: the scripts of the sysop (mk -x, menu command, hooks)}
  Var
    C: TExtCfg;
    i: Integer;
    P, Ext: String;
    N: Integer;

  Begin
  C := TExtCfg.Create(Config^.GetBbsPath);
  Try
    C.Load;
    If Not FileExists(C.BbsDir + 'extensions.cfg') Then
      Begin
      Info('there is no extensions.cfg: no script has a name or capabilities of its own (mk -x gives a script every read capability)');
      Exit;
      End;
    For i := 0 To C.Problems.Count - 1 Do
      Warn('extensions.cfg ' + C.Problems[i]);
    N := 0;
    For i := 0 To High(C.Entries) Do
      Begin
      P := C.FullPath(C.Entries[i]);
      Ext := LowerCase(ExtractFileExt(P));
      If C.Entries[i].FileName = '' Then
        Continue;
      Inc(N);
      If Not FileExists(P) Then
        Warn('extensions.cfg: ' + C.Entries[i].Name + ': ' + P + ' is not there')
      Else If (Ext <> '.bas') And (Ext <> '.pas') Then
        Warn('extensions.cfg: ' + C.Entries[i].Name + ': ' + P + ' is not a .bas or a .pas file')
      Else If C.Entries[i].Caps = '' Then
        Info('extensions.cfg: ' + C.Entries[i].Name + ' has no capabilities: every call to the BBS is refused');
      End;
    Info(IntToStr(N) + ' extension(s) in extensions.cfg');
  Finally
    C.Free;
  End;
  End;


Procedure CheckChat;
  {Chat.Mk (menu command 174): off, or on with what it needs}
  Var
    C: ChatCfgType;
    D, W: String;

  Begin
  If Not Config^.HasChat Then
    Exit;
  Config^.GetChat(C);
  If Not C.Enabled Then
    Begin
    Info('multi-node chat is off (mkconfig: Chat)');
    Exit;
    End;
  Info('multi-node chat is ON: room "' + C.RoomName + '", level ' + IntToStr(C.MinLevel) + ' and up, flood limit ' + IntToStr(C.FloodLines) + ' lines in ' + IntToStr(C.FloodSecs) + ' s' +
    Copy(', no flood limit', 1, 16 * Ord(C.FloodLines = 0)) + Copy(', every line logged', 1, 19 * Ord(C.LogChat)) + Copy(', NOT logged', 1, 12 * Ord(Not C.LogChat)));
  If C.LogChat Then
    Begin
    D := ExtractFilePath(ExpandFileName(Config^.GetLogFileName));
    If (D = '') Or (Not DirectoryExists(D)) Or (fpAccess(D, W_OK) <> 0) Then
      Warn('chat: the log folder ' + D + ' cannot be written, so chat.log cannot be kept');
    End
  Else
    Warn('chat: lines are not logged: nothing shows later who said what (mkconfig: Chat > Log every line)');
  W := Trim(C.WordFile);
  If (W <> '') And Not FileExists(W) Then
    Warn('chat: the word file ' + W + ' is not there (no words are filtered)');
  If C.MinLevel = 0 Then
    Warn('chat: the lowest level is 0, so every caller, new users too, may join; raise it to keep them out until you have looked at them');
  End;


Procedure CheckExtItem(MenuName: String; Item: Integer; Key, Data: String);
  {menu command 175: the first word of the data is an extension of extensions.cfg whose program is there}
  Var
    C: TExtCfg;
    Name, Prefix, P, Ext: String;
    E: Integer;

  Begin
  Prefix := 'menu ' + MenuName + ' item ' + IntToStr(Item) + ' (' + Key + '): ';
  Name := Trim(Data);
  If Pos(' ', Name) > 0 Then
    Name := Copy(Name, 1, Pos(' ', Name) - 1);
  If Name = '' Then
    Begin
    Warn(Prefix + 'the extension command has no name of an extension in its data (extensions.cfg)');
    Exit;
    End;
  C := TExtCfg.Create(Config^.GetBbsPath);
  Try
    C.Load;
    E := C.Find(Name);
    If E < 0 Then
      Begin
      Warn(Prefix + 'the extension "' + Name + '" is not in extensions.cfg: callers are told it is not available');
      Exit;
      End;
    P := C.FullPath(C.Entries[E]);
    Ext := LowerCase(ExtractFileExt(P));
    If Not FileExists(P) Then
      Warn(Prefix + 'the program of the extension ' + Name + ' is not there: ' + P)
    Else If (Ext <> '.bas') And (Ext <> '.pas') Then
      Warn(Prefix + 'the program of the extension ' + Name + ' is not a .bas or a .pas file');
  Finally
    C.Free;
  End;
  End;


Procedure CheckChatItem(MenuName: String; Item: Integer; Key: String);
  {menu command 174: chat is on, or the callers are told it is not there}
  Var
    C: ChatCfgType;

  Begin
  If Config^.HasChat Then
    Config^.GetChat(C)
  Else
    ChatDefaults(C);
  If Not C.Enabled Then
    Warn('menu ' + MenuName + ' item ' + IntToStr(Item) + ' (' + Key + '): the multi-node chat command, and chat is off: callers are told it is not available (mkconfig: Chat, or take the item out)');
  End;


Procedure CheckUploadItem(MenuName: String; Item: Integer; Key, Data: String);
  {menu command 173: the area (when named) allows uploads}
  Var
    Prefix: String;
    A: Integer;

  Begin
  CheckUploads;
  Prefix := 'menu ' + MenuName + ' item ' + IntToStr(Item) + ' (' + Key + '): ';
  If Trim(Data) = '' Then
    Exit;
  A := StrToIntDef(Trim(Data), 0);
  If (A <= 0) Or (Config^.GetFileAreaName(A) = '') Then
    Warn(Prefix + 'uploads into the file area "' + Trim(Data) + '", which is not a file area (the data is an area number, or nothing for the caller''s area)')
  Else If Config^.GetFileNoUl(A) Or (Config^.GetFileAreaPath(A) = '') Then
    Warn(Prefix + 'uploads into the file area ' + IntToStr(A) + ', which does not allow uploads (mkconfig: Allow Uploads, the path)')
  Else If Not DirectoryExists(Config^.GetFileAreaPath(A)) Then
    Warn(Prefix + 'the folder of file area ' + IntToStr(A) + ' is not there: ' + Config^.GetFileAreaPath(A));
  End;


Procedure CheckMenuFile(Name: String; Var HasLogoff: Boolean);
  Var
    FN: String;
    Fs: TFileStream;
    N, i, Typ, p: Integer;
    R: MenuType;
    Data, W, Ext: String;
    Found: Boolean;
    Keys: String;

  Begin
  FN := Config^.GetMnuPath(1) + Name + '.mnu';
  If Not FileExists(FN) Then
    Begin
    Fail('menu ' + Name + ': ' + FN + ' is not there (an item goes to it)');
    Exit;
    End;
  If (FileSz(FN) Mod SizeOf(MenuType)) <> 0 Then
    Begin
    Fail('menu ' + Name + ': ' + FN + ' is not a menu file (its size is not a number of ' + IntToStr(SizeOf(MenuType)) + ' byte records)');
    Exit;
    End;
  N := FileSz(FN) Div SizeOf(MenuType);
  Fs := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
  Keys := '';
  Try
    Fs.ReadBuffer(R, SizeOf(R));            {the header}
    For i := 1 To N - 1 Do
      Begin
      Fs.ReadBuffer(R, SizeOf(R));
      Typ := R.Typ;
      Data := Trim(R.Data);
      If (Typ = 0) And (R.Prompt = '') And (R.Key = #0) Then
        Continue;
      If Typ = 9 Then
        HasLogoff := True;
      If (R.Key > ' ') And (R.Key <> #1) Then
        Begin
        If Pos(UpCase(R.Key), Keys) > 0 Then
          Warn('menu ' + Name + ': the key ' + UpCase(R.Key) + ' is used by more than one item (the first one wins)')
        Else
          Keys := Keys + UpCase(R.Key);
        End;
      Case Typ Of
        1, 2, 4:
          Begin
          W := FirstWord(Data);
          If W = '' Then
            Fail('menu ' + Name + ' item ' + IntToStr(i) + ' (' + R.Key + '): goes to a menu but the data names none')
          Else If Not FileExists(Config^.GetMnuPath(1) + W + '.mnu') Then
            Fail('menu ' + Name + ' item ' + IntToStr(i) + ' (' + R.Key + '): goes to the menu ' + W + ', which is not there (' + Config^.GetMnuPath(1) + W + '.mnu)')
          Else If KnownMenus.IndexOf(W) < 0 Then
            Begin
            KnownMenus.Add(W);
            CheckMenuFile(W, HasLogoff);
            End;
          End;
        5, 40, 45:
          Begin
          W := FirstWord(Data);
          Found := False;
          For Ext In TStringArray.Create('.asc', '.ans', '.avt') Do
            If FileExists(Config^.GetTxtPath(1) + W + Ext) Then
              Found := True;
          If (W <> '') And (Not Found) Then
            Warn('menu ' + Name + ' item ' + IntToStr(i) + ' (' + R.Key + '): shows the screen ' + W + ', which is not in ' + Config^.GetTxtPath(1) + ' (.asc, .ans or .avt)');
          End;
        12:
          Begin
          W := FirstWord(Data);
          If (W <> '') And (Not FileExists(Config^.FindBbsFile(W + '.q-a') + W + '.q-a')) Then
            Warn('menu ' + Name + ' item ' + IntToStr(i) + ' (' + R.Key + '): runs the questionnaire ' + W + ', which is not there (' + W + '.q-a)');
          End;
        7:
          Begin
          W := FirstWord(Data);
          If (W <> '') And (W[1] <> '*') And (W[1] <> '#') Then
            If Not (FileExists(Rel(W)) Or OnPath(W) Or FileExists(BbsDir + W)) Then
              Warn('menu ' + Name + ' item ' + IntToStr(i) + ' (' + R.Key + '): runs ' + W + ', which is not in the BBS folder or on the PATH');
          End;
        172: CheckDoorItem(Name, i, R.Key, Data);
        173: CheckUploadItem(Name, i, R.Key, Data);
        174: CheckChatItem(Name, i, R.Key);
        175: CheckExtItem(Name, i, R.Key, Data);
        169, 170:
          Begin
          W := FirstWord(Data);
          If (W <> '') And Not FileExists(Rel(W)) Then
            Warn('menu ' + Name + ' item ' + IntToStr(i) + ' (' + R.Key + '): runs the program ' + W + ', which is not there (' + Rel(W) + ')');
          End;
        End;
      End;
  Finally
    Fs.Free;
  End;
  End;


Procedure CheckMenus;
  Var
    Logoff: Boolean;
    Fs: TFileStream;
    R: MenuType;
    SR: TSearchRec;
    n: Integer;

  Begin
  CheckChat;
  CheckExtensions;
  KnownMenus := TStringList.Create;
  Logoff := False;
  If Not FileExists(Config^.GetMnuPath(1) + 'top.mnu') Then
    Begin
    Fail('the menu top.mnu is not in ' + Config^.GetMnuPath(1) + ': mk starts with it, and a caller has no menu at all');
    Exit;
    End;
  KnownMenus.Add('top');
  CheckMenuFile('top', Logoff);
  If Not Logoff Then
    Warn('no menu reachable from top has the command End the call (type 9): a caller has no way to log off but to hang up');
  n := 0;
  If FindFirst(Config^.GetMnuPath(1) + '*.mnu', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      Inc(n);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Ok(IntToStr(KnownMenus.Count) + ' menu(s) reachable from top, ' + IntToStr(n) + ' menu file(s) in the folder');
  KnownMenus.Free;
  End;


Procedure CheckNewCaller;
  Var
    Sec: SecType;
    F: String;
    L: TStringList;
    i: Integer;
    Best: Integer;
    Lv: Integer;
    SR: TSearchRec;
    Names: Array[0..3] Of String;

  Begin
  Config^.GetNewUserSec(Sec);
  If FileExists(Config^.FindBbsFile('newuser.q-a') + 'newuser.q-a') Then
    Ok('newuser.q-a (the questionnaire of a new caller) is there')
  Else
    Fail('newuser.q-a is not there: a new caller ends registration with "Error in Questionaire newuser"');
  F := Config^.FindBbsFile('limits.ctl') + 'limits.ctl';
  If FileSz(F) < 0 Then
    Fail('limits.ctl is not there: every caller gets no time ("Time Limit Exceeded")')
  Else
    Begin
    L := TStringList.Create;
    L.LoadFromFile(F);
    Best := -1;
    For i := 0 To L.Count - 1 Do
      If (Trim(L[i]) <> '') And (Trim(L[i])[1] <> ';') Then
        Begin
        Lv := StrToIntDef(FirstWord(L[i]), -1);
        If (Lv >= 0) And (Lv <= Sec.Level) And (Lv > Best) Then
          Best := Lv;
        End;
    L.Free;
    If Best < 0 Then
      Fail('limits.ctl has no line for the level of a new caller (' + IntToStr(Sec.Level) + '): a new caller gets no time')
    Else
      Ok('limits.ctl gives a new caller (level ' + IntToStr(Sec.Level) + ') the limits of level ' + IntToStr(Best));
    End;
  Names[0] := 'welcome'; Names[1] := 'goodbye'; Names[2] := 'newuser1'; Names[3] := 'news';
  For i := 0 To 3 Do
    If Not (FileExists(Config^.GetTxtPath(1) + Names[i] + '.asc') Or FileExists(Config^.GetTxtPath(1) + Names[i] + '.ans') Or FileExists(Config^.GetTxtPath(1) + Names[i] + '.avt')) Then
      Info('the screen ' + Names[i] + ' is not in ' + Config^.GetTxtPath(1) + ': mk skips it (it is optional)');
  End;


Procedure CheckAreas;
  Var
    i, j, Named, Readable, Open_: Integer;
    Id: String;
    M: AbsMsgPtr;
    Sec, NewSec: SecType;
    Ids: TStringList;
    FNames, FPaths: TStringList;

  Begin
  Config^.GetNewUserSec(NewSec);
  Ids := TStringList.Create;
  Named := 0;
  Readable := 0;
  Open_ := 0;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If Config^.GetMsgName(i) <> '' Then
      Begin
      Inc(Named);
      Id := Config^.GetMsgAreaId(i);
      If Id = '' Then
        Begin
        Fail('message area ' + IntToStr(i) + ' (' + Config^.GetMsgName(i) + '): no base (the kind of base or its path is not set)');
        Continue;
        End;
      If Ids.IndexOf(Id) >= 0 Then
        Begin
        If Id[1] <> 'H' Then
          Warn('message area ' + IntToStr(i) + ' (' + Config^.GetMsgName(i) + '): the same base as area ' + Ids[Ids.IndexOf(Id)] + ' (' + Id + ')');
        End
      Else
        Ids.Add(Id);
      Config^.GetMsgReadSecurity(i, Sec);
      If Sec.Level <= NewSec.Level Then
        Inc(Readable);
      M := Nil;
      If OpenMsgArea(M, Id) Then
        Begin
        Inc(Open_);
        If CloseMsgArea(M) Then;
        End
      Else
        Fail('message area ' + IntToStr(i) + ' (' + Config^.GetMsgName(i) + '): the base ' + Id + ' cannot be opened (not there, or not a base of that kind)');
      End;
  Ids.Free;
  If Named = 0 Then
    Fail('there is no message area (mkconfig: Message Areas)')
  Else
    Ok(IntToStr(Named) + ' message area(s), ' + IntToStr(Open_) + ' base(s) opened');
  If (Named > 0) And (Readable = 0) Then
    Warn('a new caller (level ' + IntToStr(NewSec.Level) + ') may read none of the message areas');
  Named := 0;
  Readable := 0;
  FNames := TStringList.Create;
  FPaths := TStringList.Create;
  For i := 1 To Config^.GetMaxFileAreas Do
    If Config^.GetFileAreaName(i) <> '' Then
      Begin
      Inc(Named);
      If Not DirectoryExists(Rel(Config^.GetFileAreaPath(i))) Then
        Warn('file area ' + IntToStr(i) + ' (' + Config^.GetFileAreaName(i) + '): the folder ' + Config^.GetFileAreaPath(i) + ' is not there')
      Else
        Inc(Readable);
      End;
  FNames.Free;
  FPaths.Free;
  If Named = 0 Then
    Info('there is no file area')
  Else
    Ok(IntToStr(Named) + ' file area(s), ' + IntToStr(Readable) + ' with a folder');
  End;


Procedure CheckUsers;
  Var
    F, X, Ix: String;
    N, i: Integer;
    Fs: TFileStream;
    U: UsersType;
    Sysop, SysopFound, Anyone: Boolean;
    SecMax: Integer;

  Begin
  F := Config^.FindBbsFile('users.bbs') + 'users.bbs';
  If FileSz(F) < 0 Then
    Begin
    Info('there is no user file yet (it is made when the first caller registers; mksetup -u makes the account of the sysop)');
    Exit;
    End;
  If (FileSz(F) Mod SizeOf(UsersType)) <> 0 Then
    Begin
    Fail('users.bbs has a size that is not a number of ' + IntToStr(SizeOf(UsersType)) + ' byte records: it is damaged or of another BBS');
    Exit;
    End;
  N := FileSz(F) Div SizeOf(UsersType);
  X := Config^.FindBbsFile('extusers.bbs') + 'extusers.bbs';
  Ix := Config^.FindBbsFile('usersidx.bbs') + 'usersidx.bbs';
  If FileSz(X) >= 0 Then
    Begin
    If ExtUsersFormat(X) <> 0 Then
      Fail('extusers.bbs is of the record of the older version or of no known size: run mkpwconv -x (mk will not start)')
    Else If FileSz(X) Div SizeOf(ExtUserType) <> N Then
      Fail('extusers.bbs has ' + IntToStr(FileSz(X) Div SizeOf(ExtUserType)) + ' records and users.bbs ' + IntToStr(N) + ': the two are out of step')
    Else
      Ok('users.bbs and extusers.bbs have ' + IntToStr(N) + ' record(s)');
    End
  Else If N > 0 Then
    Fail('extusers.bbs is not there but users.bbs has ' + IntToStr(N) + ' user(s)');
  If (FileSz(Ix) >= 0) And (FileSz(Ix) Div SizeOf(UsersIdxType) <> N) Then
    Warn('usersidx.bbs has ' + IntToStr(FileSz(Ix) Div SizeOf(UsersIdxType)) + ' entries and users.bbs ' + IntToStr(N) + ' records: names are not found by the index');
  SysopFound := False;
  Sysop := False;
  If N > 0 Then
    Begin
    Fs := TFileStream.Create(F, fmOpenRead Or fmShareDenyNone);
    Try
      For i := 1 To N Do
        Begin
        Fs.ReadBuffer(U, SizeOf(U));
        If (U.Attr And uaDeleted) = 0 Then
          Begin
          If UpperCase(U.Name) = UpperCase(Config^.GetSysopName) Then
            SysopFound := True;
          If U.Security >= 100 Then
            Sysop := True;
          End;
        End;
    Finally
      Fs.Free;
    End;
    End;
  If SysopFound Then
    Ok('the sysop ' + Config^.GetSysopName + ' has an account')
  Else If Sysop Then
    Info('no account has the sysop name ' + Config^.GetSysopName + ', but there is one of level 100 or more')
  Else
    Info('nobody has an account of the sysop yet: register at the console (mk -L) and raise yourself with mkusered');
  End;


Function RunCapture(Prog: String; Args: Array Of String; Var Output: String): Integer;
  Var
    P: TProcess;
    Buf: Array[0..4095] Of Char;
    N: LongInt;
    i: Integer;

  Begin
  Output := '';
  P := TProcess.Create(Nil);
  Try
    P.Executable := Prog;
    For i := 0 To High(Args) Do
      P.Parameters.Add(Args[i]);
    P.Options := [poUsePipes, poStderrToOutPut];
    P.Execute;
    Repeat
      N := P.Output.Read(Buf, SizeOf(Buf));
      If N > 0 Then
        Output := Output + Copy(Buf, 0, N);
    Until N <= 0;
    P.WaitOnExit;
    Result := P.ExitStatus;
  Finally
    P.Free;
  End;
  End;


Procedure CheckListener;
  Var
    Prog, Out: String;
    Rc: Integer;
    L: TStringList;
    i: Integer;

  Begin
  If ListenFile = '' Then
    Begin
    If FileExists(BbsDir + 'mklisten.json') Then
      ListenFile := BbsDir + 'mklisten.json'
    Else
      Begin
      Info('no mklisten.json in the BBS folder (-l names another): the listener was not checked');
      Exit;
      End;
    End;
  Prog := ExtractFilePath(ParamStr(0)) + 'mklisten';
  If Not FileExists(Prog) Then
    Prog := ExeSearch('mklisten', GetEnvironmentVariable('PATH'));
  If Prog = '' Then
    Begin
    Info('mklisten was not found: the listener configuration ' + ListenFile + ' was not checked');
    Exit;
    End;
  Rc := RunCapture(Prog, ['-c', ListenFile, '-t'], Out);
  If Rc = 0 Then
    Begin
    Ok('mklisten accepts ' + ListenFile);
    L := TStringList.Create;
    L.Text := Out;
    For i := 0 To L.Count - 1 Do
      Begin
      If Copy(Trim(L[i]), 1, 5) = 'port ' Then
        Ok('listener ' + Trim(L[i]));
      If Copy(Trim(L[i]), 1, 8) = 'WARNING:' Then
        Warn('listener: ' + Trim(Copy(Trim(L[i]), 9, 250)));
      End;
    L.Free;
    End
  Else
    Begin
    L := TStringList.Create;
    L.Text := Out;
    For i := 0 To L.Count - 1 Do
      If Trim(L[i]) <> '' Then
        Begin
        Fail('mklisten -t does not accept ' + ListenFile + ': ' + Trim(L[i]));
        Break;
        End;
    L.Free;
    End;
  End;


Var
  i, k: Integer;
  A: String;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;

Begin
Quiet := False;
Verbose := False;
ConfDir := '';
ListenFile := '';
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-q' Then Quiet := True
  Else If A = '-v' Then Verbose := True
  Else If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else If A = '-l' Then
    Begin
    Inc(i);
    ListenFile := ExpandFileName(ParamStr(i));
    End
  Else
    Begin
    WriteLn('usage: mkcheck [-c config dir] [-l mklisten.json] [-q] [-v]');
    Halt(1);
    End;
  Inc(i);
  End;
If (ConfDir <> '') And (GetEnvironmentVariable('MK') <> ConfDir) Then
  Begin                                    {again with MK set: the environment of this process is read once}
  Argv := TStringList.Create;
  Argv.Add(ParamStr(0));
  i := 1;
  While i <= ParamCount Do
    Begin
    If ParamStr(i) = '-c' Then
      Inc(i)
    Else
      Argv.Add(ParamStr(i));
    Inc(i);
    End;
  SetLength(PArgv, Argv.Count + 1);
  For i := 0 To Argv.Count - 1 Do
    PArgv[i] := PChar(Argv[i]);
  PArgv[Argv.Count] := Nil;
  SetLength(EnvP, GetEnvironmentVariableCount + 2);
  SetLength(EnvS, GetEnvironmentVariableCount + 2);
  k := 0;
  For i := 1 To GetEnvironmentVariableCount Do
    If Copy(GetEnvironmentString(i), 1, 3) <> 'MK=' Then
      Begin
      EnvS[k] := GetEnvironmentString(i);
      Inc(k);
      End;
  EnvS[k] := 'MK=' + ConfDir;
  Inc(k);
  For i := 0 To k - 1 Do
    EnvP[i] := PChar(EnvS[i]);
  EnvP[k] := Nil;
  fpExecve(ParamStr(0), PPChar(@PArgv[0]), PPChar(@EnvP[0]));
  WriteLn(StdErr, 'mkcheck: cannot start again with MK set');
  Halt(1);
  End;
BbsType := DetectBbsType;
Config := Nil;
Case BbsType Of
  1: Config := NewMKConfig(True);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'mkcheck: No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory, or use -c');
  Halt(1);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn('FAIL the configuration cannot be loaded (error ', Config^.GetError, '): config.mk, messages.mk and files.mk must be in the folder');
  Halt(2);
  End;
BbsDir := Slash(Config^.GetBbsPath);
Ok('the configuration of ' + Config^.GetBbsName + ' (sysop ' + Config^.GetSysopName + ') loads from ' + BbsDir);
CheckFolders;
CheckLanguage;
CheckMenus;
CheckNewCaller;
CheckAreas;
CheckUsers;
CheckListener;
WriteLn;
If NFail = 0 Then
  WriteLn('mkcheck: nothing FAIL', Copy(', ' + IntToStr(NWarn) + ' warning(s)', 1, 30 * Ord(NWarn > 0)), ', ', NInfo, ' thing(s) to know.  mk can run this BBS.')
Else
  WriteLn('mkcheck: ', NFail, ' FAIL, ', NWarn, ' warning(s), ', NInfo, ' thing(s) to know.  Fix the FAIL lines first.');
If NFail > 0 Then
  Halt(2);
End.
