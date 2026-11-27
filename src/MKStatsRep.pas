{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKStatsRep;

{$mode objfpc}{$H+}

{
     mkstats: reports on the calls of the BBS, from the statistics files that mk writes (<BBS directory>/stats/YYYY-MM.tsv, see MKStats.pas).

       mkstats [-c config dir] [-m YYYY-MM | -d YYYY-MM-DD | -y YYYY | -a] [-by day|hour|node|label|port|user|result|type] [-top N] [-csv]

         the period   -m a month (default: this month), -d a day, -y a year, -a everything there is
         -by          a table with one line for each day, hour of the day, node, port label, port, user, result of the call or kind of session
                      (without it: the totals and the busiest hour and day)
         -top N       the N first lines of the table (for users and labels the busiest first; default all)
         -csv         the table (or the totals) as comma separated values, for a spreadsheet

     "Calls" are all the connections that mk answered; "log-ons" the ones where somebody got in; "failed" the ones that ended with a failed log-on; "no log-on" the ones that went before a name was
     accepted (a port scan, a caller who changed his mind).  Time is the length of the connection.  The kilobytes are those the user's counters say.
     The exit code: 0 done, 1 not usable (options, nothing to report on).
}

Uses SysUtils, Classes, DateUtils, BaseUnix, Unix;

Type
  TAgg = Class
    Calls, Ok, Failed, NoLogon: LongInt;
    Secs, SecsOk: Int64;
    Ul, Dl, Ulk, Dlk, Msgs: Int64;
    End;

Var
  Period: String = '';                 {a prefix of the date: 2026-11 ...; '' = all}
  By: String = '';
  Top: Integer = 0;
  Csv: Boolean = False;
  StatDir: String;
  Total: TAgg;
  Table: TStringList;
  Users: TStringList;
  Hours: Array[0..23] Of LongInt;
  Days: TStringList;
  Longest: LongInt = 0;
  Files: Integer = 0;
  All: Boolean = False;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkstats: ', S);
  Halt(Code);
  End;


Function Field(const S: String; N: Integer): String;
  {the N-th (from 0) tab separated field}
  Var
    P, i: Integer;
    T: String;

  Begin
  T := S;
  For i := 1 To N Do
    Begin
    P := Pos(#9, T);
    If P = 0 Then
      Exit('');
    Delete(T, 1, P);
    End;
  P := Pos(#9, T);
  If P = 0 Then
    Result := T
  Else
    Result := Copy(T, 1, P - 1);
  End;


Procedure Add(A: TAgg; Res: String; Secs: LongInt; ul, dl, ulk, dlk, msgs: LongInt);
  Begin
  Inc(A.Calls);
  If Res = 'ok' Then
    Begin
    Inc(A.Ok);
    Inc(A.SecsOk, Secs);
    End
  Else If Res = 'failed' Then
    Inc(A.Failed)
  Else
    Inc(A.NoLogon);
  Inc(A.Secs, Secs);
  Inc(A.Ul, ul);
  Inc(A.Dl, dl);
  Inc(A.Ulk, ulk);
  Inc(A.Dlk, dlk);
  Inc(A.Msgs, msgs);
  End;


Function Bucket(Key: String): TAgg;
  Var
    i: Integer;

  Begin
  i := Table.IndexOf(Key);
  If i < 0 Then
    Begin
    Result := TAgg.Create;
    Table.AddObject(Key, Result);
    End
  Else
    Result := TAgg(Table.Objects[i]);
  End;


Procedure ReadFile(FN: String);
  Var
    T: Text;
    L, Key, Date_, Res, U: String;
    Secs, ul, dl, ulk, dlk, msgs, Start: LongInt;
    D: TDateTime;
    H: Integer;
    k: Integer;

  Begin
  Assign(T, FN);
  {$I-}
  Reset(T);
  {$I+}
  If IOResult <> 0 Then
    Exit;
  Inc(Files);
  While Not Eof(T) Do
    Begin
    ReadLn(T, L);
    If (L = '') Or (L[1] = '#') Then
      Continue;
    Date_ := Field(L, 2);
    If (Period <> '') And (Copy(Date_, 1, Length(Period)) <> Period) Then
      Continue;
    Res := Field(L, 9);
    Secs := StrToIntDef(Field(L, 10), 0);
    ul := StrToIntDef(Field(L, 11), 0);
    dl := StrToIntDef(Field(L, 12), 0);
    ulk := StrToIntDef(Field(L, 13), 0);
    dlk := StrToIntDef(Field(L, 14), 0);
    msgs := StrToIntDef(Field(L, 15), 0);
    Start := StrToIntDef(Field(L, 0), 0);
    Add(Total, Res, Secs, ul, dl, ulk, dlk, msgs);
    If (Res = 'ok') And (Secs > Longest) Then
      Longest := Secs;
    D := UniversalTimeToLocal(UnixToDateTime(Start));
    H := HourOf(D);
    Inc(Hours[H]);
    k := Days.IndexOf(Date_);
    If k < 0 Then
      Days.AddObject(Date_, TObject(PtrInt(1)))
    Else
      Days.Objects[k] := TObject(PtrInt(PtrInt(Days.Objects[k]) + 1));
    U := Field(L, 8);
    If (Res = 'ok') And (U <> '') Then
      If Users.IndexOf(U) < 0 Then
        Users.Add(U);
    If By <> '' Then
      Begin
      Key := '';
      If By = 'day' Then Key := Date_
      Else If By = 'hour' Then Key := FormatFloat('00', H)
      Else If By = 'node' Then Key := FormatFloat('00', StrToIntDef(Field(L, 3), 0))
      Else If By = 'label' Then Key := Field(L, 5)
      Else If By = 'port' Then Key := Field(L, 6)
      Else If By = 'type' Then Key := Field(L, 4)
      Else If By = 'result' Then Key := Res
      Else If By = 'user' Then
        Begin
        Key := U;
        If Key = '' Then
          Key := '(nobody)';
        End;
      Add(Bucket(Key), Res, Secs, ul, dl, ulk, dlk, msgs);
      End;
    End;
  Close(T);
  End;


Function Mins(S: Int64): String;
  Begin
  Result := FormatFloat('0.0', S / 60);
  End;


Function Num(N: Int64): String;
  Begin
  Result := FormatFloat('#,##0', N);
  End;


Procedure Totals;
  Var
    i, Best, BestN: Integer;
    BestDay: String;
    Bn: LongInt;
    Avg: Double;

  Begin
  If Csv Then
    Begin
    WriteLn('period,calls,logons,failed,nologon,callers,minutes,ulfiles,ulk,dlfiles,dlk,msgs');
    WriteLn(Period, ',', Total.Calls, ',', Total.Ok, ',', Total.Failed, ',', Total.NoLogon, ',', Users.Count, ',', Mins(Total.Secs), ',', Total.Ul, ',', Total.Ulk, ',', Total.Dl, ',', Total.Dlk, ',', Total.Msgs);
    Exit;
    End;
  If Period = '' Then
    WriteLn('All the calls on record (', Files, ' file(s))')
  Else
    WriteLn('Calls in ', Period, ' (', Files, ' file(s))');
  WriteLn('  Calls            ', Num(Total.Calls), '   (', Total.Ok, ' log-ons, ', Total.Failed, ' failed log-ons, ', Total.NoLogon, ' without a log-on)');
  WriteLn('  Callers          ', Users.Count, ' different');
  If Total.Ok > 0 Then
    Avg := Total.SecsOk / Total.Ok / 60
  Else
    Avg := 0;
  WriteLn('  Time on-line     ', Mins(Total.SecsOk), ' minutes by callers who logged on (', FormatFloat('0.0', Avg), ' per call, the longest ', Mins(Longest), ')');
  WriteLn('  Uploads          ', Num(Total.Ul), ' file(s), ', Num(Total.Ulk), ' K');
  WriteLn('  Downloads        ', Num(Total.Dl), ' file(s), ', Num(Total.Dlk), ' K');
  WriteLn('  Messages posted  ', Num(Total.Msgs));
  Best := -1;
  BestN := 0;
  For i := 0 To 23 Do
    If Hours[i] > BestN Then
      Begin
      BestN := Hours[i];
      Best := i;
      End;
  If Best >= 0 Then
    WriteLn('  Busiest hour     ', FormatFloat('00', Best), ':00 (', BestN, ' calls)');
  BestDay := '';
  Bn := 0;
  For i := 0 To Days.Count - 1 Do
    If PtrInt(Days.Objects[i]) > Bn Then
      Begin
      Bn := PtrInt(Days.Objects[i]);
      BestDay := Days[i];
      End;
  If BestDay <> '' Then
    WriteLn('  Busiest day      ', BestDay, ' (', Bn, ' calls)');
  End;


Function CompareCalls(List: TStringList; I1, I2: Integer): Integer;
  Begin
  Result := TAgg(List.Objects[I2]).Calls - TAgg(List.Objects[I1]).Calls;
  If Result = 0 Then
    Result := CompareStr(List[I1], List[I2]);
  End;


Procedure ShowTable;
  Var
    i, n: Integer;
    A: TAgg;
    Sep: String;

  Begin
  If (By = 'user') Or (By = 'label') Or (By = 'result') Or (By = 'port') Or (By = 'type') Then
    Table.CustomSort(@CompareCalls)
  Else
    Table.Sort;
  n := Table.Count;
  If (Top > 0) And (Top < n) Then
    n := Top;
  If Csv Then
    Begin
    WriteLn(By, ',calls,logons,failed,nologon,minutes,ulfiles,ulk,dlfiles,dlk,msgs');
    For i := 0 To n - 1 Do
      Begin
      A := TAgg(Table.Objects[i]);
      WriteLn('"', Table[i], '",', A.Calls, ',', A.Ok, ',', A.Failed, ',', A.NoLogon, ',', Mins(A.Secs), ',', A.Ul, ',', A.Ulk, ',', A.Dl, ',', A.Dlk, ',', A.Msgs);
      End;
    Exit;
    End;
  WriteLn(Format('%-24s %6s %6s %6s %8s %12s %12s %5s', [By, 'calls', 'log-on', 'failed', 'minutes', 'up files/K', 'down files/K', 'msgs']));
  For i := 0 To n - 1 Do
    Begin
    A := TAgg(Table.Objects[i]);
    WriteLn(Format('%-24s %6d %6d %6d %8s %12s %12s %5d', [Copy(Table[i], 1, 24), A.Calls, A.Ok, A.Failed, Mins(A.Secs), IntToStr(A.Ul) + '/' + IntToStr(A.Ulk), IntToStr(A.Dl) + '/' + IntToStr(A.Dlk), A.Msgs]));
    End;
  If n < Table.Count Then
    WriteLn('(', Table.Count - n, ' more)');
  End;


Var
  i: Integer;
  A, Dir, ConfDir: String;
  SR: TSearchRec;
  Names: TStringList;

Begin
ConfDir := '';
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else If (A = '-m') Or (A = '-d') Or (A = '-y') Then
    Begin
    Inc(i);
    Period := ParamStr(i);
    If (Period = '') Or (Period[1] < '0') Or (Period[1] > '9') Then
      Die(1, A + ' needs a date: -m 2026-11, -d 2026-11-23, -y 2026');
    End
  Else If A = '-a' Then
    Begin
    All := True;
    Period := '';
    End
  Else If A = '-by' Then
    Begin
    Inc(i);
    By := LowerCase(ParamStr(i));
    If Pos(' ' + By + ' ', ' day hour node label port user result type ') = 0 Then
      Die(1, '-by takes day, hour, node, label, port, user, result or type');
    End
  Else If A = '-top' Then
    Begin
    Inc(i);
    Top := StrToIntDef(ParamStr(i), 0);
    End
  Else If A = '-csv' Then Csv := True
  Else
    Begin
    WriteLn('usage: mkstats [-c config dir] [-m YYYY-MM | -d YYYY-MM-DD | -y YYYY | -a] [-by day|hour|node|label|port|user|result|type] [-top N] [-csv]');
    Halt(1);
    End;
  Inc(i);
  End;
If (Period = '') And Not All Then
  Period := FormatDateTime('yyyy-mm', Now);          {this month, unless -a}
If ConfDir = '' Then
  ConfDir := GetEnvironmentVariable('MK');
If ConfDir = '' Then
  Die(1, 'No configuration: set MK to the BBS config directory (or use -c)');
StatDir := ExcludeTrailingPathDelimiter(ConfDir) + '/stats';
Total := TAgg.Create;
Table := TStringList.Create;
Table.CaseSensitive := True;
Users := TStringList.Create;
Users.CaseSensitive := True;
Days := TStringList.Create;
Names := TStringList.Create;
If FindFirst(StatDir + '/*.tsv', faAnyFile, SR) = 0 Then
  Begin
  Repeat
    Names.Add(SR.Name);
  Until FindNext(SR) <> 0;
  FindClose(SR);
  End;
Names.Sort;
For i := 0 To Names.Count - 1 Do
  If (Period = '') Or (Copy(Names[i], 1, Length(Copy(Period, 1, 7))) = Copy(Period, 1, 7)) Then
    ReadFile(StatDir + '/' + Names[i]);
If Files = 0 Then
  Die(1, 'no statistics ' + Copy('for ' + Period, 1, 4 + Length(Period)) + Copy('for any period', 1, 14 * Ord(Period = '')) + ' in ' + StatDir + ' (mk writes them when a call ends)');
If By = '' Then
  Totals
Else
  Begin
  If Not Csv Then
    Begin
    Totals;
    WriteLn;
    End;
  ShowTable;
  End;
End.
