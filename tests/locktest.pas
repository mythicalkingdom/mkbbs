{ SPDX-License-Identifier: GPL-3.0-or-later }
program locktest;
{$mode tp}
uses MKFile, MKPlat;
var F: File; r: Word; i: Longint;
begin
  if not shOpenFile(F, ParamStr(2)) then begin writeln('open failed'); Halt(99); end;
  if ParamStr(1) = 'hold' then
  begin
    r := LockFile(F, 0, 5); writeln('hold lock -> ', r);
    MKDelay(2000);
    Halt(0);
  end
  else begin
    Tries := 3; TryDelay := 10;
    r := shLock(F, 0, 5); writeln('try lock -> ', r); Halt(r);
  end;
end.
