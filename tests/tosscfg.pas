{ SPDX-License-Identifier: GPL-3.0-or-later }
program tosscfg;
{$mode tp}
{ tosscfg: which echo systems are linked to which areas (areas 6 9 10 11 12 15), for tests/tosstest.py }
uses MKString, MKGlobT, MKCfgAbs, MKCfgMK;
const Areas: array[1..6] of Word = (6, 9, 10, 11, 12, 15);
var s, i: Word; line: String;
begin
  Config := New(MKCfgObjPtr, Init); Config^.Load;
  for s := 1 to 2 do begin
    line := 'sys' + Long2Str(s) + ':';
    for i := 1 to 6 do
      if Config^.GetEchoToArea(s, Areas[i]) then line := line + ' ' + Long2Str(Areas[i]) + '=Y' else line := line + ' ' + Long2Str(Areas[i]) + '=n';
    writeln(line);
  end;
end.
