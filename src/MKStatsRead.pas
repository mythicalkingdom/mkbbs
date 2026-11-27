{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKStatsRead;   {Statistics for the display codes ^T: the calls of the BBS (stats/YYYY-MM.tsv) added up for today, a week, a month, a year and all that is on record}

{$mode objfpc}{$H+}

{
     A screen or a menu prompt can show numbers from the statistics (STATS.md): ^T, a period letter and an item letter (in a prompt: \t and the same two letters).

        period   T today   W the last 7 days (today included)   M this month   Y this year   A everything on record
        item     C calls (log-ons)   M minutes on line   A average minutes of a call   D files downloaded   K K downloaded   P files uploaded   Q K uploaded
                 G messages posted   U different callers   H the busiest hour (system only: "14:00")
        upper case = the whole system, lower case = the caller himself (his calls only; U and H are for the system)

     Only calls that got in (a log-on) count; a call that was still going when the line is made is not in it.  The files are read once for the process, as much as the period needs.
}

Interface

Function StatCodeText(Period, Item: Char; Const CallerName, StatDir: String): String;
  {the text of ^T<Period><Item>; '' for a combination that is not one}
Procedure StatCodesReset;                  {forget what was read (a test aid)}

Implementation

Uses SysUtils, Classes, DateUtils;

Type
  TAgg = Record
    Calls: LongInt;
    SecsOk, Ul, Dl, Ulk, Dlk, Msgs: Int64;
    End;

Var
  Loaded: Integer = 0;                 {0 nothing, 1 this and the last month, 2 this year, 3 everything}
  Sys, Own: Array[0..3] Of TAgg;       {the periods T W M Y (index 0..3); A (everything) is SysAll and OwnAll}
  SysAll, OwnAll: TAgg;
  Hours: Array[0..4, 0..23] Of LongInt;
  Callers: Array[0..4] Of TStringList;
  LoadedName, LoadedDir: String;

Const
  PeriodChars = 'TWMYA';


Function PIndex(P: Char): Integer;
  Begin
  Result := Pos(UpCase(P), PeriodChars) - 1;
  End;


Procedure ClearAll;
  Var
    i, h: Integer;

  Begin
  For i := 0 To 3 Do
    Begin
    FillChar(Sys[i], SizeOf(TAgg), 0);
    FillChar(Own[i], SizeOf(TAgg), 0);
    End;
  FillChar(SysAll, SizeOf(TAgg), 0);
  FillChar(OwnAll, SizeOf(TAgg), 0);
  For i := 0 To 4 Do
    Begin
    For h := 0 To 23 Do
      Hours[i, h] := 0;
    If Callers[i] = Nil Then
      Begin
      Callers[i] := TStringList.Create;
      Callers[i].CaseSensitive := True;
      Callers[i].Sorted := True;
      Callers[i].Duplicates := dupIgnore;
      End
    Else
      Callers[i].Clear;
    End;
  End;


Procedure StatCodesReset;
  Begin
  Loaded := 0;
  LoadedName := '';
  End;


Function Fld(Const S: String; N: Integer): String;
  Var
    p, i: Integer;
    T: String;

  Begin
  T := S;
  For i := 1 To N Do
    Begin
    p := Pos(#9, T);
    If p = 0 Then
      Exit('');
    Delete(T, 1, p);
    End;
  p := Pos(#9, T);
  If p = 0 Then
    Result := T
  Else
    Result := Copy(T, 1, p - 1);
  End;


Function DayNum(Const D: String): Integer;
  {yyyy-mm-dd as days}
  Var
    Y, M, Dd: Integer;

  Begin
  Result := -1;
  If (Length(D) < 10) Or (D[5] <> '-') Or (D[8] <> '-') Then
    Exit;
  Y := StrToIntDef(Copy(D, 1, 4), 0);
  M := StrToIntDef(Copy(D, 6, 2), 0);
  Dd := StrToIntDef(Copy(D, 9, 2), 0);
  If (Y = 0) Or (M < 1) Or (M > 12) Or (Dd < 1) Or (Dd > 31) Then
    Exit;
  Try
    Result := Trunc(EncodeDate(Y, M, Dd));
  Except
    Result := -1;
  End;
  End;


Procedure Add(Var A: TAgg; Secs, Ul, Dl, Ulk, Dlk, Msgs: Int64);
  Begin
  Inc(A.Calls);
  Inc(A.SecsOk, Secs);
  Inc(A.Ul, Ul);
  Inc(A.Dl, Dl);
  Inc(A.Ulk, Ulk);
  Inc(A.Dlk, Dlk);
  Inc(A.Msgs, Msgs);
  End;


Procedure ReadFileInto(Const FN: String; Const CallerName: String; Today: Integer; Const ThisMonth, ThisYear: String);
  Var
    T: Text;
    L, Date_, U: String;
    D, Age, H: Integer;
    Secs, Ul, Dl, Ulk, Dlk, Msgs, Start: Int64;
    Mine: Boolean;
    In_: Array[0..4] Of Boolean;
    i: Integer;

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
    If (L = '') Or (L[1] = '#') Then
      Continue;
    If Fld(L, 9) <> 'ok' Then
      Continue;
    Date_ := Fld(L, 2);
    D := DayNum(Date_);
    If D < 0 Then
      Continue;
    Age := Today - D;
    Secs := StrToInt64Def(Fld(L, 10), 0);
    Ul := StrToInt64Def(Fld(L, 11), 0);
    Dl := StrToInt64Def(Fld(L, 12), 0);
    Ulk := StrToInt64Def(Fld(L, 13), 0);
    Dlk := StrToInt64Def(Fld(L, 14), 0);
    Msgs := StrToInt64Def(Fld(L, 15), 0);
    Start := StrToInt64Def(Fld(L, 0), 0);
    U := Fld(L, 8);
    Mine := (CallerName <> '') And (LowerCase(U) = LowerCase(CallerName));
    In_[0] := Age = 0;
    In_[1] := (Age >= 0) And (Age < 7);
    In_[2] := Copy(Date_, 1, 7) = ThisMonth;
    In_[3] := Copy(Date_, 1, 4) = ThisYear;
    In_[4] := True;
    H := HourOf(UniversalTimeToLocal(UnixToDateTime(Start)));
    For i := 0 To 4 Do
      If In_[i] Then
        Begin
        If i < 4 Then
          Add(Sys[i], Secs, Ul, Dl, Ulk, Dlk, Msgs)
        Else
          Add(SysAll, Secs, Ul, Dl, Ulk, Dlk, Msgs);
        If Mine Then
          If i < 4 Then
            Add(Own[i], Secs, Ul, Dl, Ulk, Dlk, Msgs)
          Else
            Add(OwnAll, Secs, Ul, Dl, Ulk, Dlk, Msgs);
        Inc(Hours[i, H]);
        If U <> '' Then
          Callers[i].Add(LowerCase(U));
        End;
    End;
  Close(T);
  End;


Procedure Load(Level: Integer; Const CallerName, StatDir: String);
  Var
    SR: TSearchRec;
    Names: TStringList;
    i: Integer;
    Today: Integer;
    ThisMonth, ThisYear, M: String;
    Prev: TDateTime;
    PrevMonth: String;
    Want: Boolean;

  Begin
  If (Loaded >= Level) And (LoadedName = CallerName) And (LoadedDir = StatDir) Then
    Exit;
  ClearAll;
  Loaded := Level;
  LoadedName := CallerName;
  LoadedDir := StatDir;
  Today := Trunc(Date);
  ThisMonth := FormatDateTime('yyyy-mm', Date);
  ThisYear := FormatDateTime('yyyy', Date);
  Prev := Date - 31;
  PrevMonth := FormatDateTime('yyyy-mm', Prev);
  Names := TStringList.Create;
  If FindFirst(IncludeTrailingPathDelimiter(StatDir) + '*.tsv', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If Length(SR.Name) = 11 Then
        Names.Add(SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Names.Sort;
  For i := 0 To Names.Count - 1 Do
    Begin
    M := Copy(Names[i], 1, 7);
    Case Level Of
      1: Want := (M = ThisMonth) Or (M = PrevMonth);
      2: Want := Copy(M, 1, 4) = ThisYear;
      Else
        Want := True;
      End;
    If Want Then
      ReadFileInto(IncludeTrailingPathDelimiter(StatDir) + Names[i], CallerName, Today, ThisMonth, ThisYear);
    End;
  Names.Free;
  End;


Function Commas(N: Int64): String;
  Var
    S: String;
    i: Integer;

  Begin
  S := IntToStr(Abs(N));
  Result := '';
  For i := Length(S) DownTo 1 Do
    Begin
    Result := S[i] + Result;
    If ((Length(S) - i + 1) Mod 3 = 0) And (i > 1) Then
      Result := ',' + Result;
    End;
  If N < 0 Then
    Result := '-' + Result;
  End;


Function StatCodeText(Period, Item: Char; Const CallerName, StatDir: String): String;
  Var
    P: Integer;
    A: TAgg;
    Level, h, Best, BestN: Integer;
    Mine: Boolean;
    I: Char;

  Begin
  Result := '';
  P := PIndex(Period);
  If P < 0 Then
    Exit;
  I := UpCase(Item);
  If Pos(I, 'CMADKPQGUH') = 0 Then
    Exit;
  Mine := Item In ['a'..'z'];
  If Mine And (I In ['U', 'H']) Then
    Exit;
  Case UpCase(Period) Of
    'T', 'W', 'M': Level := 1;
    'Y': Level := 2;
    Else
      Level := 3;
  End;
  Load(Level, CallerName, StatDir);
  If P < 4 Then
    If Mine Then A := Own[P] Else A := Sys[P]
  Else
    If Mine Then A := OwnAll Else A := SysAll;
  Case I Of
    'C': Result := Commas(A.Calls);
    'M': Result := Commas(A.SecsOk Div 60);
    'A': If A.Calls > 0 Then Result := Commas(A.SecsOk Div 60 Div A.Calls) Else Result := '0';
    'D': Result := Commas(A.Dl);
    'K': Result := Commas(A.Dlk);
    'P': Result := Commas(A.Ul);
    'Q': Result := Commas(A.Ulk);
    'G': Result := Commas(A.Msgs);
    'U': Result := Commas(Callers[P].Count);
    'H': Begin
         Best := -1;
         BestN := 0;
         For h := 0 To 23 Do
           If Hours[P, h] > BestN Then
             Begin
             BestN := Hours[P, h];
             Best := h;
             End;
         If Best >= 0 Then
           Result := Format('%.2d:00', [Best])
         Else
           Result := '-';
         End;
    End;
  End;

End.
