program setlr;
{$mode tp}
{$H+}
{ setlr <user> <area> <message number>: the last read pointer of a user in a message area (MK=<config dir>), for example 0 to have
  everything of the area sent again to a QWK network system (a hub test setup). }
uses MKString, MKCfgAbs, MKRCfgMK, MKCfgNew, MKGlobT, MKDoor, MKOffDL, Dos;
begin
  Config := NewMKConfig(True);
  if Config = nil then begin writeln('no config'); halt(1); end;
  Config^.Load;
  User.Init; User.SetUserBbsType(1);
  User.GetUserPos(ParamStr(1));
  if not User.UserFound then begin writeln('no such user'); halt(2); end;
  User.ReadUser;
  writeln('was ', OffUserLR(Str2Long(ParamStr(2))));
  OffSetUserLR(Str2Long(ParamStr(2)), Str2Long(ParamStr(3)));
  writeln('now ', OffUserLR(Str2Long(ParamStr(2))));
end.
