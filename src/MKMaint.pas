Program MKMaint;

{$mode objfpc}{$H+}

{
     mkmaint: message base maintenance, by the settings of each message area (mkconfig: Messages, "Days kept", "Messages kept", "Received days").

       mkmaint [-c config dir] [-n] [-p] [-x] [-a area] [-v] [-q]

         -c    the configuration directory (instead of MK in the environment)
         -p    pack the Hudson bases afterwards: the room of deleted messages is given back (see below)
         -x    with -p: the copies of the old files (name.prepack) are removed at the end
         -n    a dry run: says what would be purged, changes nothing
         -a    only this area (its number)
         -v    each message that goes (or would go)
         -q    only the summary line

     For each area that has a limit, a message goes when
       * it is older than Days kept, or
       * it has been read (received) and is older than Received days, or
       * the area holds more than Messages kept: the oldest go first.
     A limit of 0 is not used.  What never goes, whatever its age:
       * unread private mail,
       * a message waiting to be sent: a local echomail message that the tosser has not scanned yet, a local netmail that has not been sent.
     The age is that of the date in the message (mm-dd-yy); a message whose date cannot be read is not purged for its age.  MKMAINT_TODAY=yyyy-mm-dd takes another day for today (a test aid).
     Packing (-p) is done for every Hudson message base (a directory with msghdr.bbs, msgtxt.bbs, msgidx.bbs, msgtoidx.bbs, msginfo.bbs) that holds deleted messages, whether or not the purge
     deleted them: the deleted messages leave the five files and the text records of the others move up, so the files get smaller (and a base that is near its limit of 65280 text records
     can take messages again).  Message numbers do not change (last-read pointers, reply links stay valid); the positions in echomail.bbs and netmail.bbs are moved with the messages.  The base is
     locked while it is packed (the callers and the tosser wait), the old files are kept as name.prepack until the next pack (-x removes them at once).
     The messages are deleted through the message object of the kind of base (Hudson, Squish, JAM, Fido *.msg, Synchronet ...), so every kind works the same way; the space is given back by
     packing (a later switch).

     The exit code: 0 done, 1 not usable (options, no configuration), 2 an area could not be opened.
}

Uses SysUtils, Classes, DateUtils, BaseUnix, Unix,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKMsgAbs, MKOpen;

Type
  TMsg = Record
    Num: LongInt;
    Day: LongInt;                      {days since 1970, -1 = unknown}
    Rcvd, Hold: Boolean;               {read; must stay (unread private, waiting to be sent)}
    Go: Boolean;
    Why: Char;                         {A age, R received, C count}
    End;

Var
  Verb: String;
  Dry, Verbose, Quiet: Boolean;
  OnlyArea: Integer = 0;
  Today: LongInt;
  Msgs: Array Of TMsg;
  TotalPurged, TotalKept, TotalAreas: LongInt;
  Failed: Boolean = False;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkmaint: ', S);
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
  Result := Trunc(DT) - 25569;                     {25569: 1970-01-01 in the days of TDateTime}
  End;


Function WhyText(C: Char): String;
  Begin
  Case C Of
    'A': Result := 'by age';
    'R': Result := 'read, and older than Received days';
    Else Result := 'over the limit of messages kept';
    End;
  End;



Const
  HdrSize = 187;
  IdxSize = 3;
  ToIdxSize = 36;
  TxtSize = 256;
  InfoSize = 406;
  AttrOfs = 24;
  AreaOfs = 26;
  StartOfs = 8;
  NumOfs = 10;
  maDeleted = 1;

Var
  NumPacked, PackBytes: LongInt;
  KeepOld: Boolean = True;
  DoPack: Boolean = False;


Function ReadAll(const FN: String; var D: TBytes): Boolean;
  Var
    F: TFileStream;

  Begin
  Result := False;
  SetLength(D, 0);
  Try
    F := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
  Except
    Exit;
  End;
  SetLength(D, F.Size);
  If F.Size > 0 Then
    F.ReadBuffer(D[0], F.Size);
  F.Free;
  Result := True;
  End;


Function WriteAll(const FN: String; const D: TBytes; N: LongInt): Boolean;
  {the file keeps its identity (the same file, the same inode): it is cut to the new size and written again}
  Var
    F: TFileStream;

  Begin
  Result := False;
  Try
    If FileExists(FN) Then
      F := TFileStream.Create(FN, fmOpenReadWrite Or fmShareDenyNone)
    Else
      F := TFileStream.Create(FN, fmCreate);
  Except
    Exit;
  End;
  F.Size := 0;
  If N > 0 Then
    F.WriteBuffer(D[0], N);
  F.Free;
  Result := True;
  End;


Function W16(const D: TBytes; At: LongInt): Word;
  Begin
  Result := D[At] Or (D[At + 1] Shl 8);
  End;


Procedure P16(var D: TBytes; At: LongInt; V: Word);
  Begin
  D[At] := V And 255;
  D[At + 1] := V Shr 8;
  End;


Procedure CopyFileTo(const Src, Dst: String);
  Var
    D: TBytes;

  Begin
  If ReadAll(Src, D) Then
    WriteAll(Dst, D, Length(D));
  End;


Function RemapList(const FN: String; const Remap: Array Of LongInt; N: LongInt): TBytes;
  {echomail.bbs / netmail.bbs: a list of header positions (words); the ones of deleted messages go, the others become the new positions}
  Var
    Old: TBytes;
    e, k, ne: LongInt;

  Begin
  Result := Nil;
  If Not ReadAll(FN, Old) Then
    Exit;
  SetLength(Result, Length(Old));
  ne := 0;
  For e := 0 To (Length(Old) Div 2) - 1 Do
    Begin
    k := W16(Old, e * 2);
    If (k < N) And (Remap[k] >= 0) Then
      Begin
      P16(Result, ne * 2, Remap[k]);
      Inc(ne);
      End;
    End;
  SetLength(Result, ne * 2);
  End;


Procedure PackHudson(Dir, AreaId: String);
  {Dir: the directory of the base (with the slash at the end); AreaId: an area of the base, for its lock}
  Var
    Hdr, Idx, ToIdx, Txt, Info, NHdr, NIdx, NToIdx, NTxt, NInfo, NEch, NNet: TBytes;
    n, i, kept, gone, tpos, S, C: LongInt;
    Remap: Array Of LongInt;               {the old position of a header -> the new one, -1 for a deleted message}
    Names: Array[0..4] Of String;
    Active: Array[0..255] Of LongInt;
    Low: LongInt;
    M: AbsMsgPtr;
    Locked: Boolean;
    Before, After: Int64;
    j: LongInt;
    Good: Boolean;

  Begin
  Names[0] := 'msghdr.bbs'; Names[1] := 'msgidx.bbs'; Names[2] := 'msgtoidx.bbs'; Names[3] := 'msgtxt.bbs'; Names[4] := 'msginfo.bbs';
  If Not (ReadAll(Dir + Names[0], Hdr) And ReadAll(Dir + Names[1], Idx) And ReadAll(Dir + Names[2], ToIdx) And ReadAll(Dir + Names[3], Txt) And ReadAll(Dir + Names[4], Info)) Then
    Exit;
  n := Length(Hdr) Div HdrSize;
  gone := 0;
  For i := 0 To n - 1 Do
    If (Hdr[i * HdrSize + AttrOfs] And maDeleted) <> 0 Then
      Inc(gone);
  If gone = 0 Then
    Exit;
  Before := Length(Hdr) + Length(Idx) + Length(ToIdx) + Length(Txt);
  If Dry Then
    Begin
    WriteLn('pack ', Dir, ': ', gone, ' deleted message(s) of ', n, ' would be removed');
    Inc(NumPacked);
    Exit;
    End;
  M := Nil;
  Locked := False;
  If OpenMsgArea(M, AreaId) Then
    Locked := M^.LockMsgBase;
  If Not Locked Then
    Begin
    WriteLn(StdErr, 'pack ', Dir, ': the base could not be locked: not packed');
    If M <> Nil Then
      DoneMsgPtr(M);
    Failed := True;
    Exit;
    End;
  {the files again, now that nobody can write: what was read before the lock may be old}
  Good := ReadAll(Dir + Names[0], Hdr) And ReadAll(Dir + Names[1], Idx) And ReadAll(Dir + Names[2], ToIdx) And ReadAll(Dir + Names[3], Txt) And ReadAll(Dir + Names[4], Info);
  If Good Then
    Begin
    n := Length(Hdr) Div HdrSize;
    Good := (Length(Idx) Div IdxSize = n) And (Length(ToIdx) Div ToIdxSize = n) And (Length(Info) >= InfoSize);
    End;
  If Not Good Then
    Begin
    WriteLn(StdErr, 'pack ', Dir, ': the five files do not belong together (different numbers of records): not packed');
    M^.UnLockMsgBase;
    DoneMsgPtr(M);
    Failed := True;
    Exit;
    End;
  SetLength(Remap, n);
  SetLength(NHdr, Length(Hdr));
  SetLength(NIdx, Length(Idx));
  SetLength(NToIdx, Length(ToIdx));
  SetLength(NTxt, Length(Txt));
  FillChar(Active, SizeOf(Active), 0);
  kept := 0;
  tpos := 0;
  Low := 65535;
  For i := 0 To n - 1 Do
    Begin
    If (Hdr[i * HdrSize + AttrOfs] And maDeleted) <> 0 Then
      Remap[i] := -1
    Else
      Begin
      Remap[i] := kept;
      Move(Hdr[i * HdrSize], NHdr[kept * HdrSize], HdrSize);
      Move(Idx[i * IdxSize], NIdx[kept * IdxSize], IdxSize);
      Move(ToIdx[i * ToIdxSize], NToIdx[kept * ToIdxSize], ToIdxSize);
      S := W16(Hdr, i * HdrSize + StartOfs);
      C := W16(Hdr, i * HdrSize + NumOfs);
      If (S + C) * TxtSize > Length(Txt) Then
        C := (Length(Txt) Div TxtSize) - S;                {a header that points past the end of the text: what is there}
      If C < 0 Then
        C := 0;
      If C > 0 Then
        Move(Txt[S * TxtSize], NTxt[tpos * TxtSize], C * TxtSize);
      P16(NHdr, kept * HdrSize + StartOfs, tpos);
      P16(NHdr, kept * HdrSize + NumOfs, C);
      Inc(tpos, C);
      Inc(Active[Hdr[i * HdrSize + AreaOfs]]);
      If W16(Hdr, i * HdrSize) < Low Then
        Low := W16(Hdr, i * HdrSize);
      Inc(kept);
      End;
    End;
  NInfo := Copy(Info, 0, Length(Info));
  If kept = 0 Then
    P16(NInfo, 0, W16(Info, 2) + 1)                         {nothing left: the low number is above the high one}
  Else
    P16(NInfo, 0, Low);
  P16(NInfo, 4, kept);
  For i := 1 To 200 Do
    P16(NInfo, 4 + i * 2, Active[i]);
  { echomail.bbs and netmail.bbs: positions of the headers of the messages that wait to be exported }
  NEch := Nil;
  NNet := Nil;
  If FileExists(Dir + 'echomail.bbs') Then
    NEch := RemapList(Dir + 'echomail.bbs', Remap, n);
  If FileExists(Dir + 'netmail.bbs') Then
    NNet := RemapList(Dir + 'netmail.bbs', Remap, n);
  { the old files are kept (name.prepack), then the files are written again, cut to the new size }
  For i := 0 To 4 Do
    CopyFileTo(Dir + Names[i], Dir + Names[i] + '.prepack');
  Good := WriteAll(Dir + Names[3], NTxt, tpos * TxtSize) And WriteAll(Dir + Names[0], NHdr, kept * HdrSize) And WriteAll(Dir + Names[2], NToIdx, kept * ToIdxSize) And
    WriteAll(Dir + Names[1], NIdx, kept * IdxSize) And WriteAll(Dir + Names[4], NInfo, Length(NInfo));
  If FileExists(Dir + 'echomail.bbs') Then
    Begin
    CopyFileTo(Dir + 'echomail.bbs', Dir + 'echomail.bbs.prepack');
    WriteAll(Dir + 'echomail.bbs', NEch, Length(NEch));
    End;
  If FileExists(Dir + 'netmail.bbs') Then
    Begin
    CopyFileTo(Dir + 'netmail.bbs', Dir + 'netmail.bbs.prepack');
    WriteAll(Dir + 'netmail.bbs', NNet, Length(NNet));
    End;
  M^.UnLockMsgBase;
  DoneMsgPtr(M);
  If Not Good Then
    Begin
    WriteLn(StdErr, 'pack ', Dir, ': writing failed: the old files are in ', Dir, '*.prepack');
    Failed := True;
    Exit;
    End;
  After := kept * HdrSize + kept * IdxSize + kept * ToIdxSize + tpos * TxtSize;
  WriteLn('pack ', Dir, ': ', gone, ' deleted message(s) removed, ', kept, ' stay, ', Before - After, ' bytes given back (', Before, ' -> ', After, ')');
  Inc(NumPacked);
  Inc(PackBytes, Before - After);
  If Not KeepOld Then
    Begin
    For i := 0 To 4 Do
      DeleteFile(Dir + Names[i] + '.prepack');
    DeleteFile(Dir + 'echomail.bbs.prepack');
    DeleteFile(Dir + 'netmail.bbs.prepack');
    End;
  End;


Procedure PackAll;
  Var
    Dirs, Ids: TStringList;
    i: Integer;
    Id, Dir: String;

  Begin
  Dirs := TStringList.Create;
  Ids := TStringList.Create;
  Dirs.CaseSensitive := True;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If Config^.GetMsgName(i) <> '' Then
      Begin
      Id := Config^.GetMsgAreaId(i);
      If (Id <> '') And (UpCase(Id[1]) = 'H') Then
        Begin
        Dir := Copy(Id, 5, 200);
        If (Dir <> '') And (Dir[Length(Dir)] <> '/') Then
          Dir := Dir + '/';
        If Dirs.IndexOf(Dir) < 0 Then
          Begin
          Dirs.Add(Dir);
          Ids.Add(Id);
          End;
        End;
      End;
  For i := 0 To Dirs.Count - 1 Do
    If FileExists(Dirs[i] + 'msghdr.bbs') Then
      PackHudson(Dirs[i], Ids[i]);
  Dirs.Free;
  Ids.Free;
  End;


Procedure Area(A: Word);
  Var
    M: AbsMsgPtr;
    Id, Name: String;
    D, R, K, n, i, j, Active, Gone, Held, ByAge, ByRcvd, ByCount: LongInt;
    Net, Echo: Boolean;
    Oldest, Age: LongInt;
    T: TMsg;
    Pending: Boolean;

  Begin
  D := Config^.GetMsgDays(A);
  R := Config^.GetMsgRcvdDays(A);
  K := Config^.GetMsgsKept(A);
  If (D = 0) And (R = 0) And (K = 0) Then
    Exit;
  Id := Config^.GetMsgAreaId(A);
  Name := Config^.GetMsgName(A);
  If Not OpenMsgArea(M, Id) Then
    Begin
    WriteLn(StdErr, 'area ', A, ' (', Name, '): the message base cannot be opened');
    Failed := True;
    Exit;
    End;
  Inc(TotalAreas);
  Net := Config^.GetMsgType(A) = NetMail;
  Echo := Config^.GetMsgType(A) = EchoMail;
  n := 0;
  SetLength(Msgs, 0);
  M^.SeekFirst(1);
  While M^.SeekFound Do
    Begin
    M^.MsgStartUp;
    If Not M^.IsDeleted Then
      Begin
      If n >= Length(Msgs) Then
        SetLength(Msgs, Length(Msgs) + 1024);
      Msgs[n].Num := M^.GetMsgNum;
      Msgs[n].Day := DayOfDate(M^.GetDate);
      Msgs[n].Rcvd := M^.IsRcvd;
      Pending := M^.IsLocal And (Not M^.IsSent) And ((Echo And M^.IsEchoed) Or Net);
      Msgs[n].Hold := (M^.IsPriv And (Not M^.IsRcvd)) Or Pending;
      Msgs[n].Go := False;
      Msgs[n].Why := ' ';
      Inc(n);
      End;
    M^.SeekNext;
    End;
  Active := n;
  ByAge := 0;
  ByRcvd := 0;
  ByCount := 0;
  Held := 0;
  For i := 0 To n - 1 Do
    Begin
    If Msgs[i].Hold Then
      Inc(Held);
    If (Not Msgs[i].Hold) And (Msgs[i].Day >= 0) Then
      Begin
      Age := Today - Msgs[i].Day;
      If (D > 0) And (Age > D) Then
        Begin
        Msgs[i].Go := True;
        Msgs[i].Why := 'A';
        Inc(ByAge);
        End
      Else If (R > 0) And Msgs[i].Rcvd And (Age > R) Then
        Begin
        Msgs[i].Go := True;
        Msgs[i].Why := 'R';
        Inc(ByRcvd);
        End;
      End;
    End;
  If K > 0 Then
    Begin
    j := 0;
    For i := 0 To n - 1 Do
      If Not Msgs[i].Go Then
        Inc(j);
    {the oldest of what is left go while there are too many: by the number (the order they came in)}
    For i := 0 To n - 1 Do
      If (j > K) And (Not Msgs[i].Go) And (Not Msgs[i].Hold) Then
        Begin
        Msgs[i].Go := True;
        Msgs[i].Why := 'C';
        Inc(ByCount);
        Dec(j);
        End;
    End;
  Gone := ByAge + ByRcvd + ByCount;
  If Verbose Then
    For i := 0 To n - 1 Do
      If Msgs[i].Go Then
        WriteLn('  #', Msgs[i].Num, ' ', WhyText(Msgs[i].Why));
  If Not Dry Then
    Begin
    For i := 0 To n - 1 Do
      If Msgs[i].Go Then
        Begin
        M^.SeekFirst(Msgs[i].Num);
        If M^.SeekFound Then
          Begin
          M^.MsgStartUp;
          If M^.GetMsgNum = Msgs[i].Num Then
            M^.DeleteMsg;
          End;
        End;
    End;
  If Not (Quiet And (Gone = 0)) Then
    WriteLn('area ', A, ' ', Name, ': ', n, ' message(s), ', Verb, Gone, ' (', ByAge, ' by age, ', ByRcvd, ' read, ', ByCount, ' over the limit)',
      Copy(', ' + IntToStr(Held) + ' kept for sending or unread', 1, 60 * Ord(Held > 0)));
  Inc(TotalPurged, Gone);
  Inc(TotalKept, n - Gone);
  If CloseMsgArea(M) Then;
  End;


Var
  i, k: Integer;
  A, S, ConfDir: String;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;

Begin
ConfDir := '';
Dry := False;
Verbose := False;
Quiet := False;
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-n' Then Dry := True
  Else If A = '-v' Then Verbose := True
  Else If A = '-q' Then Quiet := True
  Else If A = '-p' Then DoPack := True
  Else If A = '-x' Then KeepOld := False
  Else If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else If A = '-a' Then
    Begin
    Inc(i);
    OnlyArea := StrToIntDef(ParamStr(i), 0);
    If OnlyArea <= 0 Then
      Die(1, '-a needs an area number');
    End
  Else
    Begin
    WriteLn('usage: mkmaint [-c config dir] [-n] [-p] [-x] [-a area] [-v] [-q]     -n dry run  -p pack the Hudson bases  -x remove the .prepack files  -a one area  -v each message  -q the summary only');
    Halt(1);
    End;
  Inc(i);
  End;
If Dry Then
  Verb := 'would purge '
Else
  Verb := 'purged ';
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
S := GetEnvironmentVariable('MKMAINT_TODAY');
If S <> '' Then
  Begin
  Today := DayOfDate(Copy(S, 6, 2) + '-' + Copy(S, 9, 2) + '-' + Copy(S, 1, 4));
  If Today < 0 Then
    Die(1, 'MKMAINT_TODAY must be yyyy-mm-dd');
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
If OnlyArea > 0 Then
  Begin
  If Config^.GetMsgName(OnlyArea) = '' Then
    Die(1, 'no message area ' + IntToStr(OnlyArea));
  Area(OnlyArea);
  End
Else
  For i := 1 To Config^.GetMaxMsgAreas Do
    If Config^.GetMsgName(i) <> '' Then
      Area(i);
If DoPack Then
  PackAll;
WriteLn(Verb, TotalPurged, ' message(s) in ', TotalAreas, ' area(s) with a limit, ', TotalKept, ' stay', Copy(' (a dry run: nothing was changed)', 1, 34 * Ord(Dry)));
If DoPack Then
  WriteLn(NumPacked, ' Hudson base(s) ', Copy('would be ', 1, 9 * Ord(Dry)), 'packed', Copy(', ' + IntToStr(PackBytes) + ' bytes given back', 1, 40 * Ord(Not Dry)));
If Failed Then
  Halt(2);
End.
