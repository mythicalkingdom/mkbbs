Program MKUserPurge;

{$mode objfpc}{$H+}

{
     mkuserpurge: marks the users deleted who have not called for a long time (or who registered and never came back).  The user records stay in the file (MKUserEd shows them as deleted and can
     take the mark off; a deleted user cannot log on); nothing is renumbered.

       mkuserpurge [-c config dir] -d DAYS [-u DAYS] [-s LEVEL] [-k file] [-w DAYS] [-n] [-v] [-q]

         -d DAYS   a user whose last call is more than DAYS days ago is purged (needed)
         -u DAYS   a user who never called again after registering (no call is recorded) is purged when he registered more than DAYS days ago (default: the same as -d)
         -s LEVEL  a user with this security level or more is never purged (default: no limit)
         -k FILE   names that are never purged, one on each line (; begins a comment); default keepusers.txt in the BBS directory when it is there
         -w DAYS   only a list: the users who would be purged in the next DAYS days (what to warn them about); nothing is changed
         -n        a dry run: says who would be purged, changes nothing
         -v        each user, with the days since the last call
         -q        the summary only

     Never purged, whatever the days: a user who is already deleted, a user with "Do not purge" set (uaNoKill), a QWK network node, a user in the keep file, one with a security level of -s or more.
     A user whose dates cannot be read is not purged.  MKPURGE_TODAY=yyyy-mm-dd takes another day for today (a test aid).
     The exit code: 0 done, 1 not usable (options, no configuration, no user file).
}

Uses SysUtils, Classes, BaseUnix, Unix,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKName;

Var
  Days, NewDays, Level, Warn: LongInt;
  Dry, Verbose, Quiet: Boolean;
  Keep: TStringList;
  Today: LongInt;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkuserpurge: ', S);
  Halt(Code);
  End;


Function DayOfDate(S: String): LongInt;
  {mm-dd-yy (or mm-dd-yyyy) as days since 1970; -1 when it is not a date}
  Var
    M, D, Y: Integer;
    DT: TDateTime;

  Begin
  Result := -1;
  If Length(S) < 8 Then
    Exit;
  M := StrToIntDef(Copy(S, 1, 2), 0);
  D := StrToIntDef(Copy(S, 4, 2), 0);
  Y := StrToIntDef(Copy(S, 7, 4), -1);
  If (M < 1) Or (M > 12) Or (D < 1) Or (D > 31) Or (Y < 0) Then
    Exit;
  If Y < 100 Then
    Begin
    If Y < 70 Then
      Y := Y + 2000
    Else
      Y := Y + 1900;
    End;
  If Not TryEncodeDate(Y, M, D, DT) Then
    Exit;
  Result := Trunc(DT) - 25569;
  End;


Procedure LoadKeep(FN: String);
  Var
    T: Text;
    L: String;

  Begin
  Assign(T, FN);
  {$I-}
  Reset(T);
  {$I+}
  If IOResult <> 0 Then
    Exit;
  While Not Eof(T) Do
    Begin
    ReadLn(T, L);
    L := Trim(L);
    If (L <> '') And (L[1] <> ';') Then
      Keep.Add(UpperCase(L));
    End;
  Close(T);
  End;


Var
  i, k: Integer;
  A, S, ConfDir, KeepFile, Name: String;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;
  N, Gone, Safe, Seen, Last, First, Age, Sec: LongInt;
  Su: SecType;
  Reason: String;
  Calls: Word;
  Cfg, Verb: String;

Begin
Days := 0;
NewDays := -1;
Level := 0;
Warn := 0;
Dry := False;
Verbose := False;
Quiet := False;
ConfDir := '';
KeepFile := '';
Keep := TStringList.Create;
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-d' Then
    Begin
    Inc(i);
    Days := StrToIntDef(ParamStr(i), 0);
    End
  Else If A = '-u' Then
    Begin
    Inc(i);
    NewDays := StrToIntDef(ParamStr(i), -1);
    End
  Else If A = '-s' Then
    Begin
    Inc(i);
    Level := StrToIntDef(ParamStr(i), 0);
    End
  Else If A = '-k' Then
    Begin
    Inc(i);
    KeepFile := ParamStr(i);
    End
  Else If A = '-w' Then
    Begin
    Inc(i);
    Warn := StrToIntDef(ParamStr(i), 0);
    End
  Else If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else If A = '-n' Then Dry := True
  Else If A = '-v' Then Verbose := True
  Else If A = '-q' Then Quiet := True
  Else
    Begin
    WriteLn('usage: mkuserpurge [-c config dir] -d DAYS [-u DAYS] [-s LEVEL] [-k file] [-w DAYS] [-n] [-v] [-q]');
    Halt(1);
    End;
  Inc(i);
  End;
If Dry Then
  Verb := 'would purge '
Else
  Verb := 'purged ';
If Days <= 0 Then
  Begin
  WriteLn('usage: mkuserpurge [-c config dir] -d DAYS [-u DAYS] [-s LEVEL] [-k file] [-w DAYS] [-n] [-v] [-q]     (-d: the days since the last call; nothing is purged without it)');
  Halt(1);
  End;
If NewDays < 0 Then
  NewDays := Days;
If (ConfDir <> '') And (GetEnvironmentVariable('MK') <> ConfDir) Then
  Begin                                                    {-c names the configuration directory: this program starts again with MK set to it}
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
Today := Trunc(Date) - 25569;
S := GetEnvironmentVariable('MKPURGE_TODAY');
If S <> '' Then
  Begin
  Today := DayOfDate(Copy(S, 6, 2) + '-' + Copy(S, 9, 2) + '-' + Copy(S, 1, 4));
  If Today < 0 Then
    Die(1, 'MKPURGE_TODAY must be yyyy-mm-dd');
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
Config^.Load;
If Config^.GetError <> 0 Then
  Die(1, IntToStr(Config^.GetError) + ': Error loading config files');
If KeepFile = '' Then
  Begin
  Cfg := Config^.GetBbsPath;
  If (Cfg <> '') And (Cfg[Length(Cfg)] <> '/') Then
    Cfg := Cfg + '/';
  If FileExists(Cfg + 'keepusers.txt') Then
    KeepFile := Cfg + 'keepusers.txt';
  End;
If KeepFile <> '' Then
  LoadKeep(KeepFile);
NameSearch.Init;
NameSearch.SetBbsType(BbsType);
NameSearch.SetCreate(False);
NameSearch.GoToPosition(0);
N := NameSearch.GetNumUsers;
If N = 0 Then
  Die(1, 'no users (no user file)');
If Warn > 0 Then
  WriteLn('Users who would be purged within the next ', Warn, ' days (the last call more than ', Days, ' days before):');
Gone := 0;
Safe := 0;
Seen := 0;
For i := 0 To N - 1 Do
  Begin
  NameSearch.GoToPosition(i);
  If NameSearch.IsDeleted Then
    Continue;
  Inc(Seen);
  Name := NameSearch.GetName;
  If (Name = '') Then
    Continue;
  If NameSearch.IsNoKill Or NameSearch.IsQwkNode Or (Keep.IndexOf(UpperCase(Name)) >= 0) Then
    Begin
    Inc(Safe);
    Continue;
    End;
  NameSearch.GetSec(Su);
  If (Level > 0) And (Su.Level >= Level) Then
    Begin
    Inc(Safe);
    Continue;
    End;
  Last := DayOfDate(NameSearch.GetLastDate);
  Calls := NameSearch.GetTimesCalled;
  Reason := '';
  If (Last >= 0) And (Calls > 0) Then
    Age := Today - Last
  Else
    Begin                                     {no call is recorded: counted from the day of the registration}
    First := DayOfDate(NameSearch.GetFirstDate);
    If First < 0 Then
      First := Last;
    If First < 0 Then
      Continue;
    Age := Today - First;
    If (Last >= 0) And (Today - Last < Age) Then
      Age := Today - Last;
    End;
  If (Last >= 0) And (Calls > 0) Then
    Begin
    If Age > Days Then
      Reason := 'no call for ' + IntToStr(Age) + ' days';
    If (Warn > 0) And (Age + Warn > Days) And (Age <= Days) Then
      Begin
      WriteLn('  ', Name, '  (last call ', NameSearch.GetLastDate, ', ', Days - Age + 1, ' day(s) to go)');
      Continue;
      End;
    End
  Else
    Begin
    If Age > NewDays Then
      Reason := 'registered ' + IntToStr(Age) + ' days ago and never called again';
    If (Warn > 0) And (Age + Warn > NewDays) And (Age <= NewDays) Then
      Begin
      WriteLn('  ', Name, '  (registered, never called again; ', NewDays - Age + 1, ' day(s) to go)');
      Continue;
      End;
    End;
  If (Reason <> '') And (Warn = 0) Then
    Begin
    Inc(Gone);
    If Verbose Or Not Quiet Then
      WriteLn(Verb, Name, ': ', Reason);
    If Not Dry Then
      Begin
      NameSearch.SetDelete(True);
      NameSearch.SaveChanges;
      End;
    End;
  End;
If Warn = 0 Then
  WriteLn(Verb, Gone, ' user(s) of ', Seen, ' (', Safe, ' protected)', Copy(' (a dry run: nothing was changed)', 1, 34 * Ord(Dry)));
NameSearch.Done;
Dispose(Config, Done);
End.
