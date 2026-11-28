{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKAllFiles;

{$mode objfpc}{$H+}

{
     mkfilelist: a list of all the files of the file areas that a security profile may see and download.  It is for a file that callers fetch (ALLFILES.ZIP, NEWFILES.TXT in a file area, made by cron
     or an event), for a file request, and for the sysop.

       mkfilelist [-c config dir] -l level [-f flags] [-a areas] [-n days] [-t text|dir|json] [-u] [-o file] [-N]
       mkfilelist [-c config dir] -I          make the index again (every area), and say what it holds
       mkfilelist [-c config dir] -S          say what the index holds

         -l LEVEL   the security level of the list: an area is listed when its view and download security are met by this level and these flags
         -f FLAGS   the flags, numbers 1 to 32 with commas: -f 1,5,12
         -a AREAS   only these file areas: 1,3,5-7
         -n DAYS    only files that are newer than this many days (the date of the file)
         -t FORMAT  text (the default: an area, its files with size, date and description), dir (a PCBoard DIR file for each area, the area as a header line), json
         -u         text and dir in UTF-8 (the lists are in the DOS character set; json is always UTF-8)
         -o FILE    the list goes to this file (a new file that replaces it), not to the screen
         -N         without the index: the lists and the folders are read (the default reads the index and makes again what is out of date)

     The index (filelist.idx in the BBS directory, or MKFILEIDX) is a flat binary file; it is a cache of the lists (see MKFileIdx.pas).  The list is in the order of the areas, the files by name.
     An area whose folder is not there is left out.  The exit code: 0 done, 1 not usable.
}

Uses SysUtils, Classes, BaseUnix, Unix, DateUtils, fpjson,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKCp437, MKFileList, MKFileIdx;

Var
  Level: LongInt;
  Flags: LongInt;
  OnlyAreas: Array Of Integer;
  Days: Integer;
  Fmt, OutName: String;
  Utf8, NoIdx, MkIndex, ShowIndex: Boolean;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkfilelist: ', S);
  Halt(Code);
  End;


Function Utf(Const S: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If S[i] = #0 Then
      {not text}
    Else If Ord(S[i]) < 128 Then
      Result := Result + S[i]
    Else
      Result := Result + Cp437ToUtf8(Ord(S[i]));
  End;


Function Txt(Const S: String): String;
  Begin
  If Utf8 Then
    Result := Utf(S)
  Else
    Result := S;
  End;


Procedure ParseAreas(S: String);
  Var
    P: TStringList;
    i, a, b, k, n: Integer;
    T: String;

  Begin
  P := TStringList.Create;
  P.Delimiter := ',';
  P.StrictDelimiter := True;
  P.DelimitedText := S;
  For i := 0 To P.Count - 1 Do
    Begin
    T := Trim(P[i]);
    If T = '' Then
      Continue;
    k := Pos('-', T);
    If k > 0 Then
      Begin
      a := StrToIntDef(Copy(T, 1, k - 1), 0);
      b := StrToIntDef(Copy(T, k + 1, 10), 0);
      End
    Else
      Begin
      a := StrToIntDef(T, 0);
      b := a;
      End;
    If (a < 1) Or (b < a) Then
      Die(1, 'the areas are numbers, like 1,3,5-7');
    For n := a To b Do
      Begin
      SetLength(OnlyAreas, Length(OnlyAreas) + 1);
      OnlyAreas[High(OnlyAreas)] := n;
      End;
    End;
  P.Free;
  End;


Function Wanted(A: Integer): Boolean;
  Var
    i: Integer;

  Begin
  If Length(OnlyAreas) = 0 Then
    Exit(True);
  Result := False;
  For i := 0 To High(OnlyAreas) Do
    If OnlyAreas[i] = A Then
      Result := True;
  End;


Function Allowed(A: Integer): Boolean;
  Var
    V, D: SecType;
    P: SecType;

  Begin
  P.Level := Level;
  P.Flags := Flags;
  Config^.GetFileViewSecurity(A, V);
  Config^.GetFileDLSecurity(A, D);
  Result := Access(P, V) And Access(P, D);
  End;


Function PadR(S: String; N: Integer): String;
  Begin
  Result := S;
  While Length(Result) < N Do
    Result := Result + ' ';
  End;


Function DateOf(T: LongInt): String;
  Begin
  Result := FormatDateTime('yyyy-mm-dd', FileDateToDateTime(T));
  End;


Procedure MakeList(Out_: TStream);
  Var
    A, i, k, NA, NF: Integer;
    Ents: TFileEnts;
    Total: Int64;
    Newer: LongInt;
    S, First: String;
    Root, AreaObj: TJSONObject;
    Arr, FArr: TJSONArray;
    O: TJSONObject;
    Desc: TStringList;

  Procedure Put(Const T: String);
    Begin
    If T <> '' Then
      Out_.WriteBuffer(T[1], Length(T));
    End;

  Begin
  NA := 0;
  NF := 0;
  Total := 0;
  Newer := 0;
  If Days > 0 Then
    Newer := DateTimeToFileDate(Now - Days);
  Root := Nil;
  Arr := Nil;
  If Fmt = 'json' Then
    Begin
    Root := TJSONObject.Create;
    Root.Add('bbs', Utf(Config^.GetBbsName));
    Root.Add('level', Level);
    Root.Add('flags', Flags);
    Root.Add('generated', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
    If Days > 0 Then
      Root.Add('days', Days);
    Arr := TJSONArray.Create;
    Root.Add('areas', Arr);
    End
  Else If Fmt = 'text' Then
    Begin
    If Days > 0 Then
      Put(Txt('New files on ' + Config^.GetBbsName + ' (the last ' + IntToStr(Days) + ' days)') + LineEnding)
    Else
      Put(Txt('All files on ' + Config^.GetBbsName) + LineEnding);
    Put('List for level ' + IntToStr(Level) + ', made ' + FormatDateTime('yyyy-mm-dd hh:nn', Now) + LineEnding + LineEnding);
    End;
  For A := 1 To Config^.GetMaxFileAreas Do
    Begin
    If (Config^.GetFileAreaName(A) = '') Or (Config^.GetFileAreaPath(A) = '') Or Not Wanted(A) Or Not Allowed(A) Then
      Continue;
    If Not DirectoryExists(Config^.GetFileAreaPath(A)) Then
      Continue;
    AreaFiles(A, Ents, Not NoIdx);
    If Days > 0 Then
      Begin
      k := 0;
      For i := 0 To High(Ents) Do
        If Ents[i].Time >= Newer Then
          Begin
          Ents[k] := Ents[i];
          Inc(k);
          End;
      SetLength(Ents, k);
      If k = 0 Then
        Continue;
      End;
    Inc(NA);
    NF := NF + Length(Ents);
    FArr := Nil;
    If Fmt = 'json' Then
      Begin
      AreaObj := TJSONObject.Create;
      AreaObj.Add('area', A);
      AreaObj.Add('name', Utf(Config^.GetFileAreaName(A)));
      FArr := TJSONArray.Create;
      AreaObj.Add('files', FArr);
      Arr.Add(AreaObj);
      End
    Else If Fmt = 'text' Then
      Put('Area ' + IntToStr(A) + ': ' + Txt(Config^.GetFileAreaName(A)) + LineEnding + LineEnding)
    Else
      Put('; Area ' + IntToStr(A) + ': ' + Txt(Config^.GetFileAreaName(A)) + #10);
    For i := 0 To High(Ents) Do
      Begin
      Total := Total + Ents[i].Size;
      Desc := TStringList.Create;
      Desc.Text := StringReplace(Ents[i].Desc, #10, LineEnding, [rfReplaceAll]);
      If Fmt = 'json' Then
        Begin
        O := TJSONObject.Create;
        O.Add('name', Ents[i].Name);
        O.Add('size', Ents[i].Size);
        O.Add('date', DateOf(Ents[i].Time));
        If Ents[i].Desc <> '' Then
          O.Add('description', Utf(Ents[i].Desc))
        Else
          O.Add('description', TJSONNull.Create);
        FArr.Add(O);
        End
      Else If Fmt = 'text' Then
        Begin
        If Desc.Count > 0 Then
          First := Desc[0]
        Else
          First := '';
        Put('  ' + PadR(Ents[i].Name, 14) + Format('%10d', [Ents[i].Size]) + '  ' + DateOf(Ents[i].Time) + '  ' + Txt(First) + LineEnding);
        For k := 1 To Desc.Count - 1 Do
          Put(StringOfChar(' ', 38) + Txt(Desc[k]) + LineEnding);
        End
      Else
        Begin
        S := PcbListLines(Ents[i].Name, Ents[i].Size, FileDateToDateTime(Ents[i].Time), Desc);
        Put(Txt(S));
        End;
      Desc.Free;
      End;
    If Fmt = 'text' Then
      Put(LineEnding);
    End;
  If Fmt = 'json' Then
    Begin
    Root.Add('files', NF);
    Root.Add('bytes', Total);
    S := Root.FormatJSON + LineEnding;
    Put(S);
    Root.Free;
    End
  Else If Fmt = 'text' Then
    Put(IntToStr(NF) + ' files in ' + IntToStr(NA) + ' areas, ' + IntToStr(Total) + ' bytes' + LineEnding);
  End;


Procedure IndexReport;
  Var
    Areas, Files: Integer;
    Bytes, Made: Int64;

  Begin
  If IndexSummary(Areas, Files, Bytes, Made) Then
    WriteLn('index ', IndexPath, ': ', Areas, ' areas, ', Files, ' files, ', Bytes, ' bytes, made ', FormatDateTime('yyyy-mm-dd hh:nn:ss', UnixToDateTime(Made, False)))
  Else
    WriteLn('no index (', IndexPath, ')');
  End;


Var
  i, k, a2: Integer;
  A, S, ConfDir, FlagText, AreaText: String;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;
  F: TStream;
  Tmp: String;
  Areas, Files: Integer;
  P: TStringList;

Begin
Level := -1;
Flags := 0;
Days := 0;
Fmt := 'text';
OutName := '';
Utf8 := False;
NoIdx := False;
MkIndex := False;
ShowIndex := False;
ConfDir := '';
FlagText := '';
AreaText := '';
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-u' Then Utf8 := True
  Else If A = '-N' Then NoIdx := True
  Else If A = '-I' Then MkIndex := True
  Else If A = '-S' Then ShowIndex := True
  Else If (A = '-l') Or (A = '-f') Or (A = '-a') Or (A = '-n') Or (A = '-t') Or (A = '-o') Or (A = '-c') Then
    Begin
    Inc(i);
    If i > ParamCount Then
      Die(1, A + ' needs a value');
    S := ParamStr(i);
    If A = '-l' Then
      Begin
      Level := StrToIntDef(S, -1);
      If (Level < 0) Or (Level > 65535) Then
        Die(1, '-l needs a level, 0 to 65535');
      End
    Else If A = '-f' Then FlagText := S
    Else If A = '-a' Then AreaText := S
    Else If A = '-n' Then
      Begin
      Days := StrToIntDef(S, 0);
      If Days <= 0 Then
        Die(1, '-n needs a number of days');
      End
    Else If A = '-t' Then
      Begin
      Fmt := LowerCase(S);
      If (Fmt <> 'text') And (Fmt <> 'dir') And (Fmt <> 'json') Then
        Die(1, '-t is text, dir or json');
      End
    Else If A = '-o' Then OutName := S
    Else
      ConfDir := ExpandFileName(S);
    End
  Else
    Begin
    WriteLn('usage: mkfilelist [-c config dir] -l level [-f flags] [-a areas] [-n days] [-t text|dir|json] [-u] [-o file] [-N]    or  -I (make the index again)  or  -S (what the index holds)');
    Halt(1);
    End;
  Inc(i);
  End;
If Not (MkIndex Or ShowIndex) And (Level < 0) Then
  Die(1, '-l LEVEL is needed (the security level of the list)');
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
Config^.Load;
If Config^.GetError <> 0 Then
  Die(1, IntToStr(Config^.GetError) + ': Error loading config files');
If FlagText <> '' Then
  Begin
  P := TStringList.Create;
  P.Delimiter := ',';
  P.StrictDelimiter := True;
  P.DelimitedText := FlagText;
  For i := 0 To P.Count - 1 Do
    Begin
    a2 := StrToIntDef(Trim(P[i]), 0);
    If (a2 < 1) Or (a2 > 32) Then
      Die(1, '-f is flag numbers from 1 to 32, like 1,5,12');
    Flags := Flags Or LongInt(1 Shl (a2 - 1));
    End;
  P.Free;
  End;
If AreaText <> '' Then
  ParseAreas(AreaText);
If MkIndex Then
  Begin
  IndexRebuild(Areas, Files);
  IndexReport;
  Dispose(Config, Done);
  Halt(0);
  End;
If ShowIndex Then
  Begin
  IndexReport;
  Dispose(Config, Done);
  Halt(0);
  End;
If OutName <> '' Then
  Begin
  Tmp := OutName + '.' + IntToStr(fpGetPid) + '.new';
  Try
    F := TFileStream.Create(Tmp, fmCreate);
  Except
    Die(1, 'cannot write ' + OutName);
  End;
  End
Else
  F := THandleStream.Create(StdOutputHandle);
MakeList(F);
F.Free;
If OutName <> '' Then
  If Not RenameFile(Tmp, OutName) Then
    Begin
    DeleteFile(Tmp);
    Die(1, 'cannot write ' + OutName);
    End;
If Not NoIdx Then
  IndexFlush;
Dispose(Config, Done);
End.
