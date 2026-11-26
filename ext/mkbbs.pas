unit mkbbs;
{ The BBS for a Pascal script (mk -x, or an extension): thin names over HostCall.  Copy this file next to the script (units are read from the folder of the program).
  Every Query returns the number of records (lines); then Field(n, 'name') is the value of a field of record n (n from 1), Line(n) a whole line.
  A call the script may not make, or that fails, is a run-time error 300 with the text of the BBS. }

interface

function Query(cmd: string): integer;                   { run a command, the number of lines of the answer }
function Field(n: integer; name: string): string;      { a field of record n of the last answer }
function Line(n: integer): string;                      { line n (0 = the names of the fields of a table) }
function Meta(name: string): string;                    { a value of the whole answer, for example 'next' }
function Value(cmd: string): string;                    { the first record of a command, or its one value }
function Num(n: integer): string;                       { a number as text, for building commands }
function ArgCount: integer;                             { the arguments after the script's name }
function Arg(n: integer): string;                       { argument n (0 is the script) }
procedure LogLine(text: string);                        { a line in the BBS log (log:write) }

implementation

function Num(n: integer): string;
var s: string;
begin
  Str(n, s);
  Num := s;
end;

function Query(cmd: string): integer;
var n, code: integer;
begin
  Val(HostCall(cmd), n, code);
  if code <> 0 then n := 0;
  Query := n;
end;

function Field(n: integer; name: string): string;
begin
  Field := HostCall('field ' + Num(n) + ' ' + name);
end;

function Line(n: integer): string;
begin
  Line := HostCall('line ' + Num(n));
end;

function Meta(name: string): string;
begin
  Meta := HostCall('meta ' + name);
end;

function Value(cmd: string): string;
begin
  Value := HostCall('=' + cmd);
end;

function ArgCount: integer;
var n, code: integer;
begin
  Val(HostCall('argc'), n, code);
  ArgCount := n;
end;

function Arg(n: integer): string;
begin
  Arg := HostCall('arg ' + Num(n));
end;

procedure LogLine(text: string);
var n: integer;
begin
  n := Query('log.write ' + text);
end;

end.
