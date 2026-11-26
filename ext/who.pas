program who;
{ Who is on line, from a Pascal script:  mk -x ext/who.pas   (mkbbs.pas is next to it) }
uses mkbbs;
var n, i: integer;
begin
  n := Query('node.list');
  writeln('Nodes in use: ', n);
  for i := 1 to n do
    writeln(Field(i, 'node'), ' ', Field(i, 'user'), ' (', Field(i, 'activity'), ')');
end.
