{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKUserPack;

{$mode objfpc}{$H+}

{
     mkuserpack: takes the users marked deleted out of the user files, so that the numbers of the others move up.  Run it as an exclusive event (nobody on, nobody coming): it refuses while a mk or
     mklisten of this BBS is running (-f: anyway).

       mkuserpack [-c config dir] [-n] [-f] [-q] [-a | -L]

         -n   a dry run: says how many records go and what the map would be; changes nothing
         -f   pack although a mk or mklisten seems to be running
         -q   the summary only
         -a   the pack, then the last-read step
         -L   only the last-read step (the pack was made earlier; see below)

     users.bbs and extusers.bbs lose the same records (the others keep their order), usersidx.bbs is made again from the names and handles.  Each file that is changed is first copied to name.prepack.
     The MAP is written to usermap.txt in the BBS directory (the one of the last pack) and to usermap.YYYYMMDD-HHMMSS.txt (kept): lines "old<TAB>new<TAB>name", new is - for a user who went;
     numbers start at 0, a comment line starts with #.  Doors that keep files by user number can convert them with it; the last-read pointers of the message bases are a separate step.
     Only the MK user files are handled (a user file of another BBS type is refused).

     THE LAST-READ STEP (-L, or -a after the pack) applies the newest map to the last-read pointers of the message bases: lastread.bbs of a Hudson base has a block for each user number, so the
     blocks are moved to the new numbers (the blocks of users who went are dropped).  Many areas share one lastread.bbs (the board numbers are inside a block): each file is done ONCE.  The
     file is written whole as a new one that replaces it, the old one stays as lastread.bbs.prepack, and usermap.state in the BBS directory remembers which files are done for which map, so
     that a second run (or one after a stop) does not move anything twice.  It refuses when users.bbs does not have as many records as the map says the pack left (users came after the pack:
     their numbers would be mistaken for old ones), unless -f.  Areas of other kinds of message bases are listed and NOT touched (exit 2).
     The exit code: 0 done (or nothing to do), 1 not usable, 3 refused (something is running).
}

Uses SysUtils, Classes, BaseUnix, Unix,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKPwd, MKMsgAbs, MKOpen;

Var
  Dry, Force, Quiet: Boolean;
  MapId: String;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkuserpack: ', S);
  Halt(Code);
  End;


Function Running(Dir: String): Boolean;
  {a mklisten or mk of this user is running in the directory (or has it as MK): a restore into the directory should not happen under it.  Only the processes that can be looked at
   count: the ones of other users are not visible (run it as root, or as the user of the BBS, to see them all)}
  Var
    SR: TSearchRec;
    F: Text;
    L, Cwd, Env: String;
    Fs: TFileStream;
    Buf: Array[0..32767] Of Char;
    N: LongInt;

  Begin
  Result := False;
  If Dir = '' Then
    Exit;
  If FindFirst('/proc/*', faDirectory, SR) = 0 Then
    Begin
    Repeat
      If (SR.Name[1] In ['0'..'9']) And (StrToIntDef(SR.Name, 0) <> fpGetPid) Then
        Begin
        Assign(F, '/proc/' + SR.Name + '/comm');
        {$I-}
        Reset(F);
        {$I+}
        If IOResult = 0 Then
          Begin
          ReadLn(F, L);
          Close(F);
          If (L = 'mklisten') Or (L = 'mk') Then
            Begin
            Cwd := fpReadLink('/proc/' + SR.Name + '/cwd');
            Env := '';
            Try
              Fs := TFileStream.Create('/proc/' + SR.Name + '/environ', fmOpenRead Or fmShareDenyNone);
              N := Fs.Read(Buf, SizeOf(Buf));
              If N > 0 Then
                SetString(Env, PChar(@Buf[0]), N);
              Fs.Free;
            Except
              Env := '';
            End;
            If ((Cwd <> '') And ((Cwd = Dir) Or (Copy(Cwd, 1, Length(Dir) + 1) = Dir + '/'))) Or (Pos('MK=' + Dir + #0, #0 + Env) > 0) Or (Pos(#0 + 'MK=' + Dir + #0, Env) > 0) Then
              Result := True;
            End;
          End;
        End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;



Function ReadAll(FN: String; Var Buf: String): Boolean;
  Var
    Fs: TFileStream;

  Begin
  Result := False;
  Buf := '';
  If Not FileExists(FN) Then
    Exit;
  Fs := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
  SetLength(Buf, Fs.Size);
  If Fs.Size > 0 Then
    Fs.ReadBuffer(Buf[1], Fs.Size);
  Fs.Free;
  Result := True;
  End;


Procedure WriteNew(FN, Data: String);
  {the whole file is written next to it and replaces the old one; the old one stays as FN.prepack}
  Var
    Fs: TFileStream;
    Old: String;

  Begin
  If ReadAll(FN, Old) Then
    Begin
    Fs := TFileStream.Create(FN + '.prepack', fmCreate);
    If Old <> '' Then
      Fs.WriteBuffer(Old[1], Length(Old));
    Fs.Free;
    End;
  Fs := TFileStream.Create(FN + '.new', fmCreate);
  If Data <> '' Then
    Fs.WriteBuffer(Data[1], Length(Data));
  Fs.Free;
  If fpRename(FN + '.new', FN) <> 0 Then
    Die(1, 'cannot replace ' + FN);
  End;


Function Absolute(P: String): String;
  Begin
  If P = '' Then
    Exit('');
  Result := ExpandFileName(P);
  While (Length(Result) > 1) And (Result[Length(Result)] = '/') Do
    Delete(Result, Length(Result), 1);
  End;


Function MerlinStep(Path: String; Var Map: Array Of LongInt; OldN, NewN: LongInt): Boolean;
  {a Merlin base keeps its last-read pointers inside the message file, by user number: they are read and written through the base's own calls}
  Var
    M: AbsMsgPtr;
    Vals: Array Of LongInt;
    i, j, Want, Changed: LongInt;

  Begin
  Result := True;
  If Not FileExists(Path) Then
    Begin
    If Not Quiet Then
      WriteLn(Path, ': not there (no pointers to move)');
    Exit;
    End;
  Result := False;
  If Not OpenMsgArea(M, 'M' + Path) Then
    Begin
    WriteLn(StdErr, Path, ': the Merlin base cannot be opened');
    Exit;
    End;
  SetLength(Vals, OldN);
  For i := 0 To OldN - 1 Do
    Vals[i] := M^.GetLastRead(i);
  Changed := 0;
  If Not Dry Then
    For j := 0 To OldN - 1 Do
      Begin
      Want := 0;
      For i := 0 To OldN - 1 Do
        If Map[i] = j Then
          Want := Vals[i];
      If Want <> Vals[j] Then
        Begin
        M^.SetLastRead(j, Want);
        Inc(Changed);
        End;
      End;
  M^.CloseMsgBase;
  Dispose(M, Done);
  If Dry Then
    WriteLn(Path, ': the Merlin base would be moved')
  Else
    WriteLn(Path, ': ', Changed, ' pointer(s) of the Merlin base changed');
  Result := True;
  End;


Function LastReadStep(Dir, MK: String): Integer;
  {the pointers of the message bases follow the newest map; 0 done, 2 something was not handled}
  Var
    L, St, Files, Other: TStringList;
    Map: Array Of LongInt;                  {old number -> new number or -1}
    Rows, Parts: TStringList;
    i, j, OldN, NewN, A, UsersN, Done, Moved, Dropped, MaxNew, BlockSize, Num: LongInt;
    Rec16: String;
    Kind: Char;
    Id, F, Old, New_, Kinds, StateId: String;
    T: Char;
    Fs: TFileStream;

  Begin
  Result := 0;
  If Not FileExists(Dir + 'usermap.txt') Then
    Die(1, 'no ' + Dir + 'usermap.txt: no pack was made');
  L := TStringList.Create;
  L.LoadFromFile(Dir + 'usermap.txt');
  MapId := '';
  OldN := 0;
  NewN := 0;
  For i := 0 To L.Count - 1 Do
    Begin
    If (MapId = '') And (Copy(L[i], 1, 10) = '# usermap:') Then
      MapId := L[i];
    If Copy(L[i], 1, 17) = '# records before:' Then
      Begin
      Parts := TStringList.Create;
      Parts.Delimiter := ' ';
      Parts.StrictDelimiter := True;
      Parts.DelimitedText := Copy(L[i], 19, 100);
      OldN := StrToIntDef(Trim(Parts[0]), 0);
      NewN := StrToIntDef(Trim(Parts[Parts.Count - 1]), 0);
      Parts.Free;
      End;
    End;
  If (MapId = '') Or (OldN = 0) Then
    Die(1, 'usermap.txt is not a map of this version');
  SetLength(Map, OldN);
  For i := 0 To OldN - 1 Do
    Map[i] := -1;
  For i := 0 To L.Count - 1 Do
    If (L[i] <> '') And (L[i][1] <> '#') Then
      Begin
      j := Pos(#9, L[i]);
      A := StrToIntDef(Copy(L[i], 1, j - 1), -1);
      F := Copy(L[i], j + 1, 20);
      F := Copy(F, 1, Pos(#9, F) - 1);
      If (A >= 0) And (A < OldN) Then
        If F <> '-' Then
          Map[A] := StrToIntDef(F, -1);
      End;
  L.Free;
  ReadAll(Config^.FindBbsFile('users.bbs') + 'users.bbs', Old);
  UsersN := Length(Old) Div SizeOf(UsersType);
  If (UsersN <> NewN) And (Not Force) Then
    Die(3, 'users.bbs has ' + IntToStr(UsersN) + ' records, the map left ' + IntToStr(NewN) + ': users came after the pack, their numbers would be taken for old ones (-f: anyway)');
  If (Not Force) And (Not Dry) And (Running(MK) Or Running(ExcludeTrailingPathDelimiter(Dir))) Then
    Begin
    WriteLn(StdErr, 'mkuserpack: a mk or mklisten of this BBS is running: do the last-read step in the exclusive event (-f: anyway)');
    Halt(3);
    End;
  St := TStringList.Create;
  If FileExists(Dir + 'usermap.state') Then
    St.LoadFromFile(Dir + 'usermap.state');
  If (St.Count = 0) Or (St[0] <> 'map ' + MapId) Then
    Begin
    St.Clear;                               {the state of an older map: not valid for this one}
    St.Add('map ' + MapId);
    End;
  Files := TStringList.Create;
  Other := TStringList.Create;
  Other.CaseSensitive := True;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If Config^.GetMsgName(i) <> '' Then
      Begin
      Id := Config^.GetMsgAreaId(i);
      If Id = '' Then
        Continue;
      T := UpCase(Id[1]);
      Case T Of
        'H': F := 'H' + Absolute(Copy(Id, 5, 200)) + '/lastread.bbs';      {all boards of a directory share it}
        'S': F := 'S' + Absolute(Copy(Id, 2, 200)) + '.sql';
        'F': F := 'F' + Absolute(Copy(Id, 2, 200)) + '/LastRead';          {the name as the message base code writes it}
        'J': F := 'J' + Absolute(Copy(Id, 2, 200)) + '.jlr';
        'M': F := 'M' + Absolute(Copy(Id, 2, 200));
        'Y': F := '';                                                       {Synchronet: the base keeps no last-read pointers}
        Else
          F := '?';
        End;
      If F = '?' Then
        Begin
        If Other.IndexOf(T) < 0 Then
          Other.AddObject(T, TObject(PtrInt(1)))
        Else
          Other.Objects[Other.IndexOf(T)] := TObject(PtrInt(PtrInt(Other.Objects[Other.IndexOf(T)]) + 1));
        End
      Else If (F <> '') And (Files.IndexOf(F) < 0) Then
        Files.Add(F);
      End;
  Done := 0;
  For i := 0 To Files.Count - 1 Do
    Begin
    Kind := Files[i][1];
    F := Copy(Files[i], 2, 1000);
    If St.IndexOf('done ' + Files[i]) >= 0 Then
      Begin
      If Not Quiet Then
        WriteLn(F, ': already done for this map');
      Continue;
      End;
    If Kind = 'M' Then
      Begin
      If MerlinStep(F, Map, OldN, NewN) Then
        Begin
        If Not Dry Then
          Begin
          St.Add('done ' + Files[i]);
          St.SaveToFile(Dir + 'usermap.state');
          End;
        Inc(Done);
        End
      Else
        Result := 2;
      Continue;
      End;
    BlockSize := 400;
    If Kind = 'S' Then BlockSize := 4;
    If Kind = 'F' Then BlockSize := 2;
    If Kind = 'J' Then BlockSize := 16;
    If Not ReadAll(F, Old) Then
      Begin
      If Not Quiet Then
        WriteLn(F, ': not there (no pointers to move)');
      Continue;
      End;
    If (Length(Old) Mod BlockSize) <> 0 Then
      Die(1, F + ' has a size that is no number of blocks');
    Moved := 0;
    Dropped := 0;
    If Kind = 'J' Then
      Begin                                  {records [NameCrc, UserNum, LastRead, HighRead]: the user number is changed, the records of users who went are dropped}
      New_ := '';
      For j := 0 To (Length(Old) Div BlockSize) - 1 Do
        Begin
        Move(Old[j * BlockSize + 5], Num, 4);
        If (Num >= 0) And (Num < OldN) And (Map[Num] >= 0) Then
          Begin
          Rec16 := Copy(Old, j * BlockSize + 1, BlockSize);
          Move(Map[Num], Rec16[5], 4);
          New_ := New_ + Rec16;
          Inc(Moved);
          End
        Else
          Inc(Dropped);
        End;
      End
    Else
      Begin                                  {a block for each user number: moved to the new number}
      New_ := '';
      SetLength(New_, NewN * BlockSize);
      FillChar(New_[1], Length(New_), 0);
      MaxNew := -1;
      For j := 0 To (Length(Old) Div BlockSize) - 1 Do
        Begin
        If (j >= OldN) Or (Map[j] < 0) Then
          Inc(Dropped)                       {a user who went, or a number the map does not know}
        Else
          Begin
          Move(Old[j * BlockSize + 1], New_[Map[j] * BlockSize + 1], BlockSize);
          Inc(Moved);
          If Map[j] > MaxNew Then
            MaxNew := Map[j];
          End;
        End;
      SetLength(New_, (MaxNew + 1) * BlockSize);
      End;
    If Dry Then
      WriteLn(F, ': would move ', Moved, ' block(s), drop ', Dropped, ' (', Length(Old) Div BlockSize, ' before, ', Length(New_) Div BlockSize, ' after)')
    Else
      Begin
      WriteNew(F, New_);
      St.Add('done ' + Files[i]);
      St.SaveToFile(Dir + 'usermap.state');
      WriteLn(F, ': ', Moved, ' block(s) moved, ', Dropped, ' dropped (', Length(Old) Div BlockSize, ' before, ', Length(New_) Div BlockSize, ' after)');
      End;
    Inc(Done);
    End;
  If Other.Count > 0 Then
    Begin
    Kinds := '';
    For i := 0 To Other.Count - 1 Do
      Kinds := Kinds + ' ' + Other[i] + ' (' + IntToStr(PtrInt(Other.Objects[i])) + ' area(s))';
    WriteLn('NOT handled yet, left alone:', Kinds, ': the last-read pointers of these bases still follow the OLD numbers');
    Result := 2;
    End;
  If (Not Quiet) And (Done = 0) And (Result = 0) Then
    WriteLn('nothing to do');
  St.Free;
  Files.Free;
  Other.Free;
  End;


Var
  WithLast, OnlyLast: Boolean;
  i, k, N, Gone, NewN, Rn: LongInt;
  A, S, ConfDir, Dir, UF, XF, IF_, MK, Users, Ext, NewUsers, NewExt, NewIdx, MapText, Stamp: String;
  U: UsersType;
  X: ExtUserType;
  Ix: UsersIdxType;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;
  Map: TStringList;
  Drop: Array Of Boolean;
  NewNum: Array Of LongInt;
  Fs: TFileStream;

Begin
Dry := False;
WithLast := False;
OnlyLast := False;
Force := False;
Quiet := False;
ConfDir := '';
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-n' Then Dry := True
  Else If A = '-f' Then Force := True
  Else If A = '-q' Then Quiet := True
  Else If A = '-a' Then WithLast := True
  Else If A = '-L' Then OnlyLast := True
  Else If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else
    Begin
    WriteLn('usage: mkuserpack [-c config dir] [-n] [-f] [-q] [-a | -L]     -a pack and last-read step  -L the last-read step only  -n dry run  -f although something is running  -q summary only');
    Halt(1);
    End;
  Inc(i);
  End;
If (ConfDir <> '') And (GetEnvironmentVariable('MK') <> ConfDir) Then
  Begin
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
  Die(1, 'cannot start again with MK set');
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
  Die(1, 'No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory');
If BbsType <> 1 Then
  Die(1, 'only the MK user files are handled');
Config^.Load;
If Config^.GetError <> 0 Then
  Die(1, IntToStr(Config^.GetError) + ': Error loading config files');
Dir := Config^.GetBbsPath;
If (Dir <> '') And (Dir[Length(Dir)] <> '/') Then
  Dir := Dir + '/';
If OnlyLast And WithLast Then
  Die(1, '-a and -L do not go together');
If OnlyLast Then
  Begin
  k := LastReadStep(Dir, GetEnvironmentVariable('MK'));
  Dispose(Config, Done);
  Halt(k);
  End;
UF := Config^.FindBbsFile('users.bbs') + 'users.bbs';
XF := Config^.FindBbsFile('extusers.bbs') + 'extusers.bbs';
IF_ := Config^.FindBbsFile('usersidx.bbs') + 'usersidx.bbs';
If Not ReadAll(UF, Users) Then
  Die(1, 'no user file ' + UF);
If (Length(Users) Mod SizeOf(UsersType)) <> 0 Then
  Die(1, UF + ' has a size that is no number of records');
N := Length(Users) Div SizeOf(UsersType);
Ext := '';
If ReadAll(XF, Ext) Then
  Begin
  If ExtUsersFormat(XF) <> 0 Then
    Die(1, XF + ' is not of the size of the extended user record (mkpwconv -x)');
  If Length(Ext) <> N * SizeOf(ExtUserType) Then
    Die(1, XF + ' has ' + IntToStr(Length(Ext) Div SizeOf(ExtUserType)) + ' records and ' + UF + ' ' + IntToStr(N) + ': not packed (they must match)');
  End;
SetLength(Drop, N);
SetLength(NewNum, N);
Gone := 0;
NewN := 0;
For i := 0 To N - 1 Do
  Begin
  Move(Users[i * SizeOf(UsersType) + 1], U, SizeOf(U));
  Drop[i] := (U.Attr And uaDeleted) <> 0;
  If Drop[i] Then
    Begin
    NewNum[i] := -1;
    Inc(Gone);
    End
  Else
    Begin
    NewNum[i] := NewN;
    Inc(NewN);
    End;
  End;
If Gone = 0 Then
  Begin
  WriteLn('no user is marked deleted: nothing to pack (', N, ' records)');
  Halt(0);
  End;
MK := GetEnvironmentVariable('MK');
If (Not Force) And (Not Dry) Then
  Begin
  If Running(MK) Or Running(ExcludeTrailingPathDelimiter(Dir)) Then
    Begin
    WriteLn(StdErr, 'mkuserpack: a mk or mklisten of this BBS is running: pack it in an exclusive event (-f: anyway)');
    Halt(3);
    End;
  End;
Map := TStringList.Create;
Stamp := FormatDateTime('yyyymmdd-hhnnss', Now);
Map.Add('# usermap: user numbers before and after the pack of ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
Map.Add('# format 1: old<TAB>new<TAB>name; "-" is a user who went; numbers start at 0');
Map.Add('# records before: ' + IntToStr(N) + '  after: ' + IntToStr(NewN));
For i := 0 To N - 1 Do
  Begin
  Move(Users[i * SizeOf(UsersType) + 1], U, SizeOf(U));
  If NewNum[i] < 0 Then
    Map.Add(IntToStr(i) + #9'-'#9 + U.Name)
  Else
    Map.Add(IntToStr(i) + #9 + IntToStr(NewNum[i]) + #9 + U.Name);
  End;
If Dry Then
  WriteLn('a dry run: ', Gone, ' of ', N, ' record(s) would go, ', NewN, ' would stay (the map would be ', Dir, 'usermap.txt)')
Else
  Begin
  NewUsers := '';
  NewExt := '';
  NewIdx := '';
  For i := 0 To N - 1 Do
    If Not Drop[i] Then
      Begin
      NewUsers := NewUsers + Copy(Users, i * SizeOf(UsersType) + 1, SizeOf(UsersType));
      If Ext <> '' Then
        NewExt := NewExt + Copy(Ext, i * SizeOf(ExtUserType) + 1, SizeOf(ExtUserType));
      Move(Users[i * SizeOf(UsersType) + 1], U, SizeOf(U));
      Ix.NameCrc := NameCrcCode(U.Name);
      If Ext <> '' Then
        Move(Ext[i * SizeOf(ExtUserType) + 1], X, SizeOf(X))
      Else
        FillChar(X, SizeOf(X), 0);
      Ix.HandleCrc := NameCrcCode(X.Handle);
      SetLength(S, SizeOf(Ix));
      Move(Ix, S[1], SizeOf(Ix));
      NewIdx := NewIdx + S;
      End;
  { the map first: if the packing stops, the map of the intended pack is there }
  Map.SaveToFile(Dir + 'usermap.' + Stamp + '.txt');
  Map.SaveToFile(Dir + 'usermap.txt');
  WriteNew(UF, NewUsers);
  If Ext <> '' Then
    WriteNew(XF, NewExt);
  WriteNew(IF_, NewIdx);
  WriteLn('packed: ', Gone, ' record(s) removed, ', NewN, ' users now; the map is ', Dir, 'usermap.txt (and usermap.', Stamp, '.txt)');
  If (Not Quiet) And (Not WithLast) Then
    WriteLn('next: mkuserpack -L moves the last-read pointers of the message bases to the new numbers (until then they are wrong); doors that keep files by user number need the map too');
  End;
Map.Free;
k := 0;
If WithLast And (Not Dry) Then
  k := LastReadStep(Dir, MK);
Dispose(Config, Done);
Halt(k);
End.
