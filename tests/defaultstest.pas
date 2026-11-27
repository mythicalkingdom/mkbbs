{ SPDX-License-Identifier: GPL-3.0-or-later }
program defaultstest;
{$mode tp}
{ the defaults of a new configuration: an echo system is sent to as Normal mail (Hold is only sent when the system calls us) }
uses MKString, MKGlobT, MKCfgAbs, MKCfgMK, Default;
var i: Word; Ok: Boolean;
begin
  Config := New(MKCfgObjPtr, Init);
  Config^.Allocate;
  SetEchoDefaults(Config^);
  Ok := True;
  for i := 1 to 32 do if Config^.GetEchoToMailType(i) <> esNormal then Ok := False;
  if Ok then writeln('ok   defaults: every echo system starts as Normal mail') else begin writeln('FAIL defaults: the mail type of a new echo system is not Normal'); Halt(1); end;
end.
