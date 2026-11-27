{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKConnect;

{$MODE OBJFPC}
{$H+}

{
     mkconnect - a terminal program for BBSs with a dialing directory (MKCONNECT-PLAN.md)

        mkconnect                      the dialing directory (the phone book asks for its start password)
        mkconnect host[:port]          a call to a system that is not in the phone book (no password needed)
        mkconnect -e name              a call to a system of the phone book

          -t telnet|telnets|raw|ssh    the kind of connection (default telnet)
          -u                           the terminal wants UTF-8 (the CP437 of the system is converted)   -c   it does not (the bytes are passed as they are)
          -b file                      another phone book (default ~/.config/mkconnect/phonebook)
          -s script                    run this script after the connect (a file, one in ~/.config/mkconnect/scripts, or a built in one: synchronet, mk)
          -r rounds, -w seconds        multi-dial: how many times the marked systems are tried (3) and the wait between two tries (5)
          -d folder                    where downloaded files come (default ~/Downloads when it is there, else the current folder)
          -h                           this text

     In a call: Ctrl-] is the attention key (a menu), Alt-P sends the password of the system, Alt-N its login name, Alt-H hangs up, Alt-X hangs up and leaves, Alt-D goes to the dialer, Alt-C is capture.
}

Uses SysUtils, BaseUnix, Termio, MKCp437, MKConnBook, MKConnCall, MKConnUi;

Var
  i: Integer;
  A, Host, Kind, BookFile: String;
  E: TConnEntry;
  Opts: TCallOpts;
  Msg: String;
  P: Integer;
  K: TConnKind;
  ForceU, ForceC: Boolean;
  R: Integer;
  EntryName, DownDir, ScriptArg: String;
  Rounds, PauseSecs: Integer;
  Book: TConnBook;
  St: TDialerState;
  Pw, Pw2, Why: String;
  Tries, Rc: Integer;

Procedure Usage;
  Begin
  WriteLn(StdErr, 'Usage: mkconnect [-t telnet|telnets|raw|ssh] [-u | -c] [-b phonebook] [-d folder] [-s script] [-r rounds] [-w seconds] [-e name | host[:port]]');
  Halt(3);
  End;

Begin
Host := '';
DownDir := '';
ScriptArg := '';
Rounds := 3;
PauseSecs := 5;
EntryName := '';
Kind := '';
BookFile := '';
ForceU := False;
ForceC := False;
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-t' Then
    Begin
    Inc(i);
    If i > ParamCount Then Usage;
    Kind := ParamStr(i);
    End
  Else If A = '-b' Then
    Begin
    Inc(i);
    If i > ParamCount Then Usage;
    BookFile := ParamStr(i);
    End
  Else If A = '-e' Then
    Begin
    Inc(i);
    If i > ParamCount Then Usage;
    EntryName := ParamStr(i);
    End
  Else If A = '-d' Then
    Begin
    Inc(i);
    If i > ParamCount Then Usage;
    DownDir := ParamStr(i);
    End
  Else If (A = '-r') Or (A = '-w') Then
    Begin
    Inc(i);
    If i > ParamCount Then Usage;
    If A = '-r' Then Rounds := StrToIntDef(ParamStr(i), 3) Else PauseSecs := StrToIntDef(ParamStr(i), 5);
    End
  Else If A = '-s' Then
    Begin
    Inc(i);
    If i > ParamCount Then Usage;
    ScriptArg := ParamStr(i);
    End
  Else If A = '-u' Then ForceU := True
  Else If A = '-c' Then ForceC := True
  Else If (A = '-h') Or (A = '--help') Then Usage
  Else If (Host = '') And ((Length(A) = 0) Or (A[1] <> '-')) Then Host := A
  Else Usage;
  Inc(i);
  End;
If (IsATTY(0) = 0) Or (IsATTY(1) = 0) Then
  Begin
  WriteLn(StdErr, 'mkconnect needs a terminal');
  Halt(1);
  End;
Opts.TermUtf8 := TermWantsUtf8(GetEnvironmentVariable('TERM'));
If ForceU Then Opts.TermUtf8 := True;
If ForceC Then Opts.TermUtf8 := False;
Opts.CapDir := GetCurrentDir;
Opts.LogFile := IncludeTrailingPathDelimiter(ConnConfigDir) + 'calls.log';
If DownDir = '' Then
  Begin
  DownDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + 'Downloads';
  If (GetEnvironmentVariable('HOME') = '') Or Not DirectoryExists(DownDir) Then
    DownDir := GetCurrentDir;
  End;
Opts.DownDir := ExpandFileName(DownDir);
Opts.ConnectMs := 15000;
Opts.ScriptName := ScriptArg;
Opts.ScriptDir := IncludeTrailingPathDelimiter(ConnConfigDir) + 'scripts';
If (Host <> '') And (EntryName <> '') Then
  Usage;
If Host = '' Then
  Begin
  { the phone book: sealed with the start password }
  If BookFile = '' Then
    BookFile := IncludeTrailingPathDelimiter(ConnConfigDir) + 'phonebook';
  Book := TConnBook.Create(BookFile);
  Pw := '';
  St.Sealed := False;
  If Book.Exists Then
    Begin
    Tries := 0;
    Rc := Book.Load('', Why);
    While Rc = 1 Do
      Begin
      If Not AskPasswordTty('Start password: ', Pw) Then
        Halt(1);
      Rc := Book.Load(Pw, Why);
      If Rc = 2 Then
        Begin
        Inc(Tries);
        If Tries >= 3 Then
          Begin
          WriteLn(StdErr, 'mkconnect: ', Why);
          Halt(1);
          End;
        WriteLn('Wrong password.');
        Rc := 1;
        End;
      End;
    If Rc <> 0 Then
      Begin
      WriteLn(StdErr, 'mkconnect: ', Why);
      Halt(1);
      End;
    St.Sealed := Book.Sealed;
    If Not St.Sealed Then
      Pw := '';
    End
  Else
    Begin
    WriteLn('There is no phone book yet (', BookFile, ').');
    WriteLn('It is sealed with a start password, which is asked each time the program starts. An empty password leaves the phone book as plain text (mode 600).');
    If Not AskPasswordTty('New start password: ', Pw) Then
      Halt(1);
    If Pw <> '' Then
      Begin
      If Not AskPasswordTty('Once more: ', Pw2) Then
        Halt(1);
      If Pw <> Pw2 Then
        Begin
        WriteLn(StdErr, 'mkconnect: the two are not the same.');
        Halt(1);
        End;
      St.Sealed := True;
      End;
    End;
  If EntryName <> '' Then
    Begin
    R := Book.Find(EntryName);
    If R < 0 Then
      Begin
      WriteLn(StdErr, 'mkconnect: there is no system called ', EntryName, ' in the phone book');
      Halt(1);
      End;
    E := Book.Items[R];
    Rc := RunCall(E, Opts, Msg);
    If Msg <> '' Then
      WriteLn(StdErr, 'mkconnect: ', Msg);
    Book.Items[R].Calls := E.Calls;
    Book.Items[R].Last := E.Last;
    If Not Book.Save(Pw, St.Sealed, Why) Then
      WriteLn(StdErr, 'mkconnect: the phone book was not saved: ', Why);
    If Rc = crFailed Then
      Halt(1);
    Halt(0);
    End;
  St.Book := Book;
  St.Password := Pw;
  St.Opts := Opts;
  St.Rounds := Rounds;
  St.PauseSecs := PauseSecs;
  RunDialer(St);
  Halt(0);
  End;
ConnNewEntry(E);
E.Name := Host;
P := LastDelimiter(':', Host);
If (P > 0) And (Pos(':', Copy(Host, 1, P - 1)) = 0) And (StrToIntDef(Copy(Host, P + 1, 9), 0) > 0) Then
  Begin
  E.Port := StrToInt(Copy(Host, P + 1, 9));
  E.Host := Copy(Host, 1, P - 1);
  End
Else
  Begin
  E.Host := Host;
  E.Port := 23;
  End;
If (Length(E.Host) > 2) And (E.Host[1] = '[') And (E.Host[Length(E.Host)] = ']') Then
  E.Host := Copy(E.Host, 2, Length(E.Host) - 2);
If Kind <> '' Then
  Begin
  If Not ConnKindFrom(Kind, K) Then Usage;
  E.Kind := K;
  If E.Port = 23 Then E.Port := ConnDefaultPort(K);
  End;
P := Pos('@', E.Host);
If (E.Kind = ckSsh) And (P > 1) Then
  Begin
  E.SshUser := Copy(E.Host, 1, P - 1);
  E.Host := Copy(E.Host, P + 1, 255);
  End;
ForceDirectories(ConnConfigDir);
R := RunCall(E, Opts, Msg);
If Msg <> '' Then
  WriteLn(StdErr, 'mkconnect: ', Msg);
If R = crFailed Then
  Halt(1);
End.
