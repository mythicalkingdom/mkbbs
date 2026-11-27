{ SPDX-License-Identifier: GPL-3.0-or-later }
program basictest;
{$mode tp}
{ Menu command 169: BASIC programs run for the caller (MKBasicRun) on a scripted loopback session.
  Build with -dMKBASIC -Fu<mkbasic-fpc/src>, run with MK=<work dir>: basictest <work dir> <PROMPTS.LC>. }
uses Dos, MKString, MKFile, MKComAbs, MKDoor, MKCfgAbs, MKRCfgMK, MKBasicRun;

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
  RunBasicProgram(Work + FN);
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

  Prog('hello.bas', '10 PRINT 2+2');
  Run('hello.bas', '', '', '', False);
  Check('PRINT 2+2 reaches the caller', Has(' 4'));
  Check('a normal end: no Press Enter, the caller is still there', (Not Has('Press')) and L.Up);

  Prog('in.bas', '10 INPUT "Name";N$|20 PRINT "Hi ";N$');
  Run('in.bas', 'Bob'#13, '', '', False);
  Check('INPUT: prompt, echo of the typing and the answer', Has('Name? Bob') and Has('Hi Bob'));

  Run('in.bas', 'Bobx'#8#8'by'#13, '', '', False);
  Check('INPUT: backspace edits the line', Has('Hi Boby') or Has('Hi Bob') and Has('by'));

  Run('in.bas', 'Al'#21'Ed'#13, '', '', False);
  Check('INPUT: Ctrl-U erases the line', Has('Hi Ed'));

  Prog('num.bas', '10 INPUT A|20 PRINT "got";A');
  Run('num.bas', 'x'#13'42'#13, '', '', False);
  Check('numeric INPUT: a bad answer asks again (Redo from start)', Has('Redo from start') and Has('got 42'));

  Prog('key.bas', '10 K$=INKEY$:IF K$="" THEN 10|20 PRINT ASC(K$);LEN(K$)');
  Run('key.bas', 'A', '', '', False);
  Check('INKEY$ gets a key (65, 1 character)', Has(' 65  1'));
  Run('key.bas', #27'[A', '', '', False);
  Check('an arrow key is CHR$(0)+72 like on a PC', Has(' 0  2'));

  Prog('brk.bas', '10 INPUT A:PRINT "after"');
  Run('brk.bas', 'ab'#3, 'Break', #13, False);
  Check('Ctrl-C in INPUT ends the program', Has('Break') and (Not Has('after')) and (Not Has('Internal error')));
  Check('... the caller is told, then Press Enter, the line stays up', Has('Press') and L.Up);

  Prog('loop.bas', '10 GOTO 10');
  Run('loop.bas', #3, 'Break', #13, False);
  Check('Ctrl-C stops a program that never waits (Break in 10)', Has('Break in 10'));

  Prog('err.bas', '10 PRINT "a"|20 FOR|30 PRINT "b"');
  Run('err.bas', '', 'in 20', #13, False);
  Check('an error is shown with its line and ends the program', Has('Missing = in for loop assign statement in 20') and (Not Has('b'#13#10)) and Has('Press'));

  Prog('err2.bas', '10 PRINT "a"|20 ON ERROR GOTO 100|30 X$="x"+1|40 PRINT "after"|50 END|100 PRINT "trapped ";ERR:RESUME NEXT');
  Run('err2.bas', '', '', '', False);
  Check('ON ERROR in the program still works', Has('trapped') and Has('after') and (Not Has('Press')));

  Prog('rt.bas', '10 PRINT "x"|20 GOTO 999|30 PRINT "y"');
  Run('rt.bas', '', 'Undefined line', #13, False);
  Check('a run time error ends the program: Press Enter, the line stays up', Has('Undefined line number in 20') and (Not Has('y'#13#10)) and Has('Press') and L.Up);

  Prog('lock.bas', '10 LOAD "other.bas"|20 PRINT "next"');
  Run('lock.bas', '', 'Permission denied', #13, False);
  Check('locked: LOAD gives Permission denied and stops', Has('Permission denied') and (Not Has('next')));

  Prog('sys.bas', '10 PRINT "bye";|20 SYSTEM|30 PRINT "no"');
  Run('sys.bas', '', '', '', False);
  Check('SYSTEM ends the program, not the caller''s session', Has('bye') and (Not Has('no')) and L.Up and (Not Has('Press')));
  Check('a program that stops in the middle of a line: the line is ended', Has('bye'#13#10));

  Prog('file.bas', '10 OPEN "O",#1,"out.txt":PRINT #1,"hello":CLOSE #1|20 PRINT "done"');
  Assign(T, Work + 'out.txt'); {$I-} Erase(T); {$I+} if IoResult <> 0 then;
  Run('file.bas', '', '', '', False);
  Check('the program can write a file in its own directory', Has('done') and FileExist(Work + 'out.txt'));
  Prog('out.bas', '10 OPEN "O",#1,"../escape.txt":PRINT #1,"x":CLOSE #1|20 PRINT "done"');
  Run('out.bas', '', 'Press', #13, False);
  Check('... but not outside it', (Not FileExist(Work + '../escape.txt')));

  Prog('rnd.bas', '10 RANDOMIZE|20 PRINT "ok"');
  Run('rnd.bas', '', '', '', False);
  Check('RANDOMIZE does not ask for a seed', Has('ok') and (Not Has('seed')));

  Prog('scr.bas', '10 COLOR 14,1:CLS:LOCATE 5,10:PRINT "x":COLOR 7,0');
  Run('scr.bas', '', '', '', False);
  Check('COLOR / CLS / LOCATE do no harm without ANSI', Has('x'));

  Prog('gone.bas', '10 INPUT A$:PRINT "after"');
  Run('gone.bas', '', '?', '', True);
  Check('carrier lost while waiting: the program stops quietly', (Not Has('after')) and (Not Has('Internal')) and (Not Has('Break')) and (Not L.Up));

  Run('/nonexistent/dir/none.bas', '', 'Not Found', #13, False);
  Check('a program that does not exist: Not Found, Press Enter', Has('Not Found') and Has('Press'));

  Assign(T, Work + 'big.bas'); Rewrite(T);
  WriteLn(T, '10 PRINT "big"');
  Close(T);
  Run('big.bas', '', '', '', False);
  Check('a second run in the same session works (state is not kept)', Has('big'));

  writeln('failures: ', Fails);
  Halt(Fails);
end.
