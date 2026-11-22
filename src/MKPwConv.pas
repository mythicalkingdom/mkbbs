Program MKPwConv;

{$I MKB.Def}

{
     mkpwconv -x [directory]
     mkpwconv -h [-n] [-f] [-v] [-i iterations] [-u "user name"] [directory]

     directory   the BBS configuration directory (default: the environment variable MK)

     -x   Expands extusers.bbs to the record of this version.  The extended user record has a block at its end for a
          hashed password (and 128 bytes kept for later); the file of the DOS version, or of an earlier build, has the
          shorter record, and the programs refuse to run on it (they say so).  One run on each BBS makes the file right:
          every record gets the empty hash block (the password stays in Users.Bbs as it was).  The old file is kept as
          extusers.bbs.old (nothing is done when that exists already, so a backup is never replaced); a file of the new
          size is left alone.

     -h   Converts the plain passwords of the user base to hashes: the Pwd field of users.bbs becomes "*" and the hash is
          written to the user's extusers.bbs record.  A plain password was compared in upper case, so the hash is of the
          upper case form and the owner can type it in any case, as before (a password they set later is as typed).
          Users that have a hash already, and users without a password, are left alone.
            -n   only count and report (nothing is written, no backup is made)
            -u   only this user (not case sensitive)
            -v   list the users that were converted
            -i   iterations of the hash (default 20000; a higher number is slower at every log-on)
            -f   go on although the BBS has callers on line (see below)
          Before anything is written users.bbs and extusers.bbs are copied to users.bbs.pwbak and extusers.bbs.pwbak; when
          one of these exists nothing is done (move it away first).  There is no way back from a hash: the backup is the
          way back.  Callers on line (useron.bbs) stop the conversion: mk writes the user record back when the caller
          leaves and would put the old password back.  Stop mklisten, or wait until the nodes are free.
          Only for an MK configuration (config.mk or bbsconfig.json in the directory).  Other BBS programs that read the same
          users.bbs (Remote Access ...) cannot check a hash: do not convert a user base they share.

     Exit status: 0 done or nothing to do, 1 the file could not be read or written, 2 the size fits neither record,
     3 a backup of an earlier run is in the way, 4 not an MK configuration, or extusers.bbs must be expanded first (-x),
     5 callers are on line.
}

Uses Dos, MKString, MKFile, MKPwd, MKRCfgMK, MKGlobT;


Var
  Dir: String;
  DoExpand, DoHash, DryRun, Force, Verbose: Boolean;
  OnlyUser: String;
  Iter: LongInt;
  i: Integer;
  P: String;


Procedure Expand;
  Var
    FN, Bak: String;
    Old, New: Word;
    Fi, Fo: File;
    Buf: Array[1..4096] Of Byte;
    Zero: Array[1..4096] Of Byte;
    Rd, Wr: Word;
    Recs, k: LongInt;

  Begin
  FN := Dir + 'extusers.bbs';
  Bak := FN + '.old';
  Old := ExtUsersOldSize;
  New := ExtUsersNewSize;
  Case ExtUsersFormat(FN) Of
    0: Begin
       WriteLn(FN, ': nothing to do');
       Halt(0);
       End;
    2: Begin
       WriteLn(FN, ': the size ', SizeFile(FN), ' fits neither the old record (', Old, ') nor the new one (', New, ')');
       Halt(2);
       End;
    End;
  If FileExist(Bak) Then
    Begin
    WriteLn(Bak, ' exists: move it away first');
    Halt(3);
    End;
  Recs := SizeFile(FN) Div Old;
  {the old file is kept: renamed, then the new one is written next to it}
  Assign(Fi, FN);
  Rename(Fi, Bak);
  If IoResult <> 0 Then
    Begin
    WriteLn('Cannot rename ', FN);
    Halt(1);
    End;
  Assign(Fi, Bak);
  FileMode := 0;
  Reset(Fi, 1);
  Assign(Fo, FN);
  Rewrite(Fo, 1);
  If IoResult <> 0 Then
    Begin
    WriteLn('Cannot write ', FN);
    Halt(1);
    End;
  FillChar(Zero, SizeOf(Zero), 0);
  For k := 1 To Recs Do
    Begin
    Rd := 0;
    While Rd < Old Do
      Begin
      Wr := Old - Rd;
      If Wr > SizeOf(Buf) Then Wr := SizeOf(Buf);
      BlockRead(Fi, Buf, Wr, Wr);
      If Wr = 0 Then
        Begin
        WriteLn('Cannot read ', Bak);
        Halt(1);
        End;
      BlockWrite(Fo, Buf, Wr);
      Rd := Rd + Wr;
      End;
    BlockWrite(Fo, Zero, New - Old);
    End;
  Close(Fi);
  Close(Fo);
  If IoResult <> 0 Then;
  WriteLn(FN, ': ', Recs, ' records expanded from ', Old, ' to ', New, ' bytes (the old file: ', Bak, ')');
  End;


Function CopyFile(Src, Dst: String): Boolean;
  Var
    Fi, Fo: File;
    Buf: Array[1..8192] Of Byte;
    Rd: Word;

  Begin
  CopyFile := False;
  Assign(Fi, Src);
  FileMode := 0;
  Reset(Fi, 1);
  If IoResult <> 0 Then
    Exit;
  Assign(Fo, Dst);
  Rewrite(Fo, 1);
  If IoResult <> 0 Then
    Begin
    Close(Fi);
    Exit;
    End;
  Repeat
    BlockRead(Fi, Buf, SizeOf(Buf), Rd);
    If Rd > 0 Then
      BlockWrite(Fo, Buf, Rd);
  Until (Rd = 0) Or (IoResult <> 0);
  Close(Fi);
  Close(Fo);
  CopyFile := (IoResult = 0) And (SizeFile(Src) = SizeFile(Dst));
  End;


Function InUse(Const Name: String): Boolean;
  {a caller is on line: a node whose status is more than "waiting" or "logging in", with a user name; with a name given, that user}
  Var
    UO: UserOnType;
    k, N: LongInt;
    Fn: String;
    Any: Boolean;

  Begin
  Any := False;
  Fn := Dir + 'useron.bbs';
  If FileExist(Fn) Then
    Begin
    N := SizeFile(Fn) Div SizeOf(UserOnType);
    For k := 0 To N - 1 Do
      If LoadFilePos(Fn, UO, SizeOf(UO), k * SizeOf(UO)) = 0 Then
        If (UO.Name <> '') And (UO.Status <> uoNotAvail) And (UO.Status <> uoWait) Then
          If (Name = '') Or (Upper(UO.Name) = Upper(Name)) Then
            Begin
            WriteLn('On line: ', UO.Name, ' (node ', UO.Node, ')');
            Any := True;
            End;
    End;
  InUse := Any;
  End;


Procedure HashUsers;
  Var
    UFile, XFile: String;
    UR: UsersType;
    H: PwHashType;
    Recs, Xrecs, k: LongInt;
    NPlain, NDone, NHash, NEmpty, NBroken, NSkip, NFail: LongInt;
    Pass: Integer;
    XSize: Word;

  Begin
  UFile := Dir + 'users.bbs';
  XFile := Dir + 'extusers.bbs';
  If Not (FileExist(Dir + 'config.mk') Or FileExist(Dir + 'bbsconfig.json')) Then
    Begin
    WriteLn(Dir, ': not an MK configuration (no config.mk or bbsconfig.json): hashed passwords are for MK only');
    Halt(4);
    End;
  If Not FileExist(UFile) Then
    Begin
    WriteLn('No ', UFile);
    Halt(1);
    End;
  If Not FileExist(XFile) Then
    Begin
    WriteLn('No ', XFile);
    Halt(1);
    End;
  Case ExtUsersFormat(XFile) Of
    1: Begin
       WriteLn(XFile, ' has the record of the older version: run  mkpwconv -x  first');
       Halt(4);
       End;
    2: Begin
       WriteLn(XFile, ': the size fits no record');
       Halt(2);
       End;
    End;
  If (SizeFile(UFile) Mod SizeOf(UsersType)) <> 0 Then
    Begin
    WriteLn(UFile, ': the size fits no user record');
    Halt(2);
    End;
  XSize := ExtUsersNewSize;
  Recs := SizeFile(UFile) Div SizeOf(UsersType);
  Xrecs := SizeFile(XFile) Div XSize;
  If Iter > 0 Then
    PwdIterations := Iter;
  If (Not DryRun) And (Not Force) Then
    If InUse(OnlyUser) Then
      Begin
      WriteLn('Callers are on line: stop mklisten or wait (-f goes on anyway)');
      Halt(5);
      End;
  If (Not DryRun) Then
    Begin
    If FileExist(UFile + '.pwbak') Or FileExist(XFile + '.pwbak') Then
      Begin
      WriteLn('users.bbs.pwbak or extusers.bbs.pwbak exists: move them away first');
      Halt(3);
      End;
    End;
  NPlain := 0; NDone := 0; NHash := 0; NEmpty := 0; NBroken := 0; NSkip := 0; NFail := 0;
  {pass 1 counts (and, for a dry run, is all there is); pass 2 converts}
  For Pass := 1 To 2 Do
    Begin
    If (Pass = 2) And (DryRun Or (NPlain = 0)) Then
      Break;
    If Pass = 2 Then
      Begin
      If (Not CopyFile(UFile, UFile + '.pwbak')) Or (Not CopyFile(XFile, XFile + '.pwbak')) Then
        Begin
        WriteLn('Cannot make the backup (users.bbs.pwbak, extusers.bbs.pwbak): nothing was changed');
        Halt(1);
        End;
      WriteLn('Backup: users.bbs.pwbak and extusers.bbs.pwbak');
      End;
    For k := 0 To Recs - 1 Do
      Begin
      If LoadFilePos(UFile, UR, SizeOf(UR), k * SizeOf(UsersType)) <> 0 Then
        Begin
        If Pass = 1 Then Inc(NFail);
        Continue;
        End;
      If (OnlyUser <> '') And (Upper(UR.Name) <> Upper(OnlyUser)) Then
        Continue;
      If k >= Xrecs Then
        Begin
        If Pass = 1 Then Inc(NSkip);          {no extended record: nothing to keep a hash in}
        Continue;
        End;
      If LoadFilePos(XFile, H, SizeOf(H), k * XSize + SizeOf(ExtUserBaseType)) <> 0 Then
        PwdHashClear(H);
      If UR.Pwd = '' Then
        Begin
        If Pass = 1 Then Inc(NEmpty);
        End
      Else If UR.Pwd = '*' Then
        Begin
        If Pass = 1 Then
          If PwdHashIsSet(H) Then Inc(NHash) Else Inc(NBroken);
        End
      Else
        Begin
        If Pass = 1 Then
          Inc(NPlain)
        Else
          Begin
          {the hash first, then the field: a stop in between leaves the plain password working}
          If Not PwdHashSetKeep(H, UR.Pwd, True) Then       {a conversion is not a new password: the state stays}
            Begin
            WriteLn('No random numbers: stopped');
            Halt(1);
            End;
          If SaveFilePos(XFile, H, SizeOf(H), k * XSize + SizeOf(ExtUserBaseType)) <> 0 Then
            Begin
            WriteLn('Cannot write ', XFile);
            Halt(1);
            End;
          UR.Pwd := '*';
          If SaveFilePos(UFile, UR, SizeOf(UR), k * SizeOf(UsersType)) <> 0 Then
            Begin
            WriteLn('Cannot write ', UFile);
            Halt(1);
            End;
          Inc(NDone);
          If Verbose Then
            WriteLn('  ', UR.Name);
          End;
        End;
      End;
    End;
  If OnlyUser <> '' Then
    WriteLn('Only ', OnlyUser, ':');
  WriteLn(Recs, ' user records: ', NPlain, ' with a plain password, ', NHash, ' with a hash already, ', NEmpty,
    ' without a password');
  If NBroken > 0 Then
    WriteLn(NBroken, ' have * but no hash (nobody gets in as them: set a new password in mkusered)');
  If NSkip > 0 Then
    WriteLn(NSkip, ' have no extended record (left alone)');
  If NFail > 0 Then
    WriteLn(NFail, ' could not be read');
  If DryRun Then
    WriteLn('Dry run: nothing was changed')
  Else If NDone > 0 Then
    WriteLn(NDone, ' passwords converted to hashes (', PwdIterations, ' iterations); the backup is users.bbs.pwbak / extusers.bbs.pwbak')
  Else
    WriteLn('Nothing to convert');
  If (Not DryRun) And (NDone > 0) Then
    WriteLn('Programs that read users.bbs and are not MK cannot check these passwords.');
  End;


Begin
DoExpand := False; DoHash := False; DryRun := False; Force := False; Verbose := False;
OnlyUser := '';
Dir := '';
Iter := 0;
i := 1;
While i <= ParamCount Do
  Begin
  P := ParamStr(i);
  If (P <> '') And (P[1] = '-') And (Length(P) > 1) Then
    Begin
    Case UpCase(P[2]) Of
      'X': DoExpand := True;
      'H': DoHash := True;
      'N': DryRun := True;
      'F': Force := True;
      'V': Verbose := True;
      'U': Begin
           Inc(i);
           If i <= ParamCount Then OnlyUser := ParamStr(i);
           End;
      'I': Begin
           Inc(i);
           If i <= ParamCount Then Iter := Str2Long(ParamStr(i));
           End;
      Else
        Begin
        WriteLn('Unknown option ', P);
        Halt(1);
        End;
      End;
    End
  Else
    Dir := P;
  Inc(i);
  End;
If DoExpand = DoHash Then
  Begin
  WriteLn('mkpwconv -x [directory]                 expand extusers.bbs to the record with the password hash block');
  WriteLn('mkpwconv -h [-n] [-f] [-v] [-i n] [-u "name"] [directory]   convert the plain passwords to hashes');
  Halt(1);
  End;
If Dir = '' Then
  Dir := GetEnv('MK');
If Dir = '' Then
  Begin
  WriteLn('No BBS directory: give it or set MK');
  Halt(1);
  End;
If Dir[Length(Dir)] <> '/' Then
  Dir := Dir + '/';
If DoExpand Then
  Expand
Else
  HashUsers;
End.
