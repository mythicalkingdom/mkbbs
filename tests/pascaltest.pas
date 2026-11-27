{ SPDX-License-Identifier: GPL-3.0-or-later }
program pascaltest;
{$mode tp}
{ Menu command 170: Pascal programs run for the caller (MKPascalRun) on a scripted loopback session.
  Build with -dMKPASCAL -Fubuild/pascal, run with MK=<work dir>: pascaltest <work dir> <PROMPTS.LC>. }
uses Dos, MKString, MKFile, MKComAbs, MKDoor, MKCfgAbs, MKRCfgMK, MKPascalRun;

Type
  ScriptCom = Object(AbsComObj)
    Inp: String;
    Outp: String;
    Up: Boolean;
    Trig: String;            { when this text has been sent ... }
    Feed: String;            { ... the caller types this }
    DropCarrier: Boolean;    { ... or the line drops }
    Fired: Boolean;
    Constructor Init;
    Function  GetCarrier: Boolean; Virtual;
    Procedure Hangup; Virtual;
    Function  InEmpty: Boolean; Virtual;
    Function  GetChar: Char; Virtual;
    Function  PeekChar: Char; Virtual;
    Procedure SendChar(Ch: Char); Virtual;
    Function  GetCommInfo: String; Virtual;
    End;

Constructor ScriptCom.Init;
  begin Inherited Init; Inp := ''; Outp := ''; Up := True; Trig := ''; Feed := ''; DropCarrier := False; Fired := False; end;
Function ScriptCom.GetCarrier: Boolean; begin GetCarrier := Up; end;
Procedure ScriptCom.Hangup; begin Up := False; end;
Function ScriptCom.InEmpty: Boolean; begin InEmpty := Length(Inp) = 0; end;
Function ScriptCom.GetChar: Char;
  begin if Length(Inp) > 0 then begin GetChar := Inp[1]; Delete(Inp, 1, 1); end else GetChar := #0; end;
Function ScriptCom.PeekChar: Char; begin if Length(Inp) > 0 then PeekChar := Inp[1] else PeekChar := #0; end;
Procedure ScriptCom.SendChar(Ch: Char);
  begin
  if Length(Outp) < 60000 then Outp := Outp + Ch;
  if (Not Fired) and (Trig <> '') and (Pos(Trig, Outp) > 0) then
    begin
    Fired := True;
    Inp := Inp + Feed;
    if DropCarrier then Up := False;
    end;
  end;
Function ScriptCom.GetCommInfo: String; begin GetCommInfo := 'Script'; end;

var
  Fails: Integer;
  L: ScriptCom;
  Work: String;

function Shown(S: String): String;       { control characters made visible }
var i: Integer; R: String;
begin
  R := '';
  for i := 1 to Length(S) do
    if S[i] = #13 then R := R + '\r' else if S[i] = #10 then R := R + '\n'
    else if S[i] < ' ' then R := R + '^' + Chr(Ord(S[i]) + 64) else R := R + S[i];
  Shown := R;
end;

var Out: String;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); writeln('     output: ', Copy(Shown(Out), 1, 300)); Inc(Fails); end;
  Flush(Output);
end;

procedure Prog(FN: String; Lines: String);      { program lines separated by | }
var T: Text; p: Integer;
begin
  Assign(T, Work + FN); Rewrite(T);
  while Lines <> '' do begin
    p := Pos('|', Lines);
    if p = 0 then p := Length(Lines) + 1;
    WriteLn(T, Copy(Lines, 1, p - 1));
    Lines := Copy(Lines, p + 1, 2000);
  end;
  Close(T);
end;

procedure Run(FN, Input, Trig, Feed: String; Drop: Boolean);
begin
  User.Done;
  User.Init;
  L.Init;
  L.Inp := Input; L.Trig := Trig; L.Feed := Feed; L.DropCarrier := Drop;
  ComSession := @L;
  RunPascalProgram(Work + FN);
  Out := L.Outp;
end;

function Has(S: String): Boolean; begin Has := Pos(S, Out) > 0; end;

var T: Text; S: String;
begin
  Work := WithBackSlash(ParamStr(1));
  Config := New(MKRCfgObjPtr, Init);
  Config^.Allocate;
  Prompts.Init;
  Prompts.Load(ParamStr(2));          { the language file: Press Enter ... }
  User.Init;

  Prog('hello.pas', 'program p;|begin|  writeln(''Hello '', 2 + 2)|end.');
  Run('hello.pas', '', '', '', False);
  Check('writeln reaches the caller', Has('Hello 4'));
  Check('a normal end: no Press Enter, the caller is still there', (Not Has('Press')) and L.Up);

  Prog('in.pas', 'var s: string;|begin|  write(''Name? ''); readln(s); writeln(''Hi '', s)|end.');
  Run('in.pas', 'Bob'#13, '', '', False);
  Check('readln: prompt, echo of the typing and the answer', Has('Name? Bob') and Has('Hi Bob'));
  Run('in.pas', 'Bobx'#8#8'by'#13, '', '', False);
  Check('readln: backspace edits the line', Has('Hi Boby') or (Has('Hi Bob') and Has('by')));
  Run('in.pas', 'Al'#21'Ed'#13, '', '', False);
  Check('readln: Ctrl-U erases the line', Has('Hi Ed'));

  Prog('num.pas', 'var i: integer;|begin|  readln(i); writeln(i * 2)|end.');
  Run('num.pas', '21'#13, '', '', False);
  Check('readln of a number', Has('42'));
  Run('num.pas', 'x'#13, 'Runtime error', #13, False);
  Check('a bad number is Turbo Pascal runtime error 106: message, Press Enter', Has('Runtime error 106') and Has('Press') and L.Up);

  Prog('key.pas', 'uses Crt;|var a, b: integer;|begin|  a := ord(ReadKey); b := ord(ReadKey); writeln(a, '' '', b)|end.');
  Run('key.pas', 'AB', '', '', False);
  Check('ReadKey gets keys (65 66)', Has('65 66'));
  Run('key.pas', #27'[A', '', '', False);
  Check('an arrow key is #0 then 72, as Turbo Pascal reports it', Has('0 72'));

  Prog('brk.pas', 'var s: string;|begin|  readln(s); writeln(''after'')|end.');
  Run('brk.pas', 'ab'#3, 'interrupted', #13, False);
  Check('Ctrl-C in readln ends the program (Program interrupted)', Has('Program interrupted') and (Not Has('after')));
  Check('... then Press Enter, the line stays up', Has('Press') and L.Up);

  Prog('loop.pas', 'begin|  while true do ;|end.');
  Run('loop.pas', #3, 'interrupted', #13, False);
  Check('Ctrl-C stops a program that never waits', Has('Program interrupted at line'));

  Prog('err.pas', 'begin|  x := 1|end.');
  Run('err.pas', '', 'Error', #13, False);
  Check('a compile error is shown with its place and the program does not run', Has('Error:') and Has('line 2') and Has('Press'));

  Prog('rt.pas', 'var i: integer;|begin|  writeln(''a''); i := 0; writeln(1 div i); writeln(''b'')|end.');
  Run('rt.pas', '', 'Runtime error', #13, False);
  Check('a run time error ends the program', Has('Runtime error 200') and (Not Has('b'#13#10)) and Has('Press') and L.Up);

  Prog('halt.pas', 'begin|  write(''bye''); halt|end.');
  Run('halt.pas', '', '', '', False);
  Check('Halt ends the program, not the session; the line is ended', Has('bye'#13#10) and L.Up and (Not Has('Press')));

  Prog('file.pas', 'var f: text;|begin|  assign(f, ''out.txt''); rewrite(f); writeln(f, ''hello''); close(f); writeln(''done'')|end.');
  Assign(T, Work + 'out.txt'); {$I-} Erase(T); {$I+} if IoResult <> 0 then;
  Run('file.pas', '', '', '', False);
  Check('the program can write a file in its own directory', Has('done') and FileExist(Work + 'out.txt'));
  Prog('out.pas', 'var f: text;|begin|  assign(f, ''../escape.txt''); {$I-} rewrite(f); {$I+} writeln(''io '', ioresult <> 0)|end.');
  Run('out.pas', '', '', '', False);
  Check('... but not outside it', Not FileExist(Work + '../escape.txt'));

  Prog('par.pas', 'begin|  writeln(ParamCount, '' '', ParamStr(1), '' '', ParamStr(2))|end.');
  User.Done; User.Init; L.Init; ComSession := @L;
  RunPascalProgram(Work + 'par.pas easy 10');
  Out := L.Outp;
  Check('words after the path are the program''s parameters', Has('2 easy 10'));

  Prog('myunit.pas', 'unit MyUnit;|interface|function Twice(n: integer): integer;|implementation|function Twice(n: integer): integer;|begin Twice := n * 2 end;|end.');
  Prog('useu.pas', 'uses MyUnit;|begin|  writeln(''twice '', Twice(21))|end.');
  Run('useu.pas', '', '', '', False);
  Check('a unit next to the program is found', Has('twice 42'));

  Prog('scr.pas', 'uses Crt;|begin|  ClrScr; GotoXY(3, 2); TextColor(14); TextBackground(1); write(''x''); TextColor(7)|end.');
  Run('scr.pas', '', '', '', False);
  Check('Crt: ClrScr / GotoXY / TextColor do no harm without ANSI', Has('x'));

  Prog('gone.pas', 'var s: string;|begin|  write(''?''); readln(s); writeln(''after'')|end.');
  Run('gone.pas', '', '?', '', True);
  Check('carrier lost while waiting: the program stops quietly', (Not Has('after')) and (Not Has('interrupted')) and (Not L.Up));

  Run('/nonexistent/dir/none.pas', '', 'Not Found', #13, False);
  Check('a program that does not exist: Not Found, Press Enter', Has('Not Found') and Has('Press'));

  Run('hello.pas', '', '', '', False);
  Check('a second run in the same session works', Has('Hello 4'));

  writeln('failures: ', Fails);
  Halt(Fails);
end.
