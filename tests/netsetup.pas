program netsetup;
{$mode tp}
{$H+}
{ netsetup <user name> <area> [area ...]   makes the user a QWK node (flag), ZIP packer, the areas in its offline mail,
  limits as the BBS has them (tests/qwknettest.py).  MK=<config dir> }
uses MKString, MKCfgAbs, MKRCfgMK, MKCfgNew, MKName, MKGlobT;

var N: NameObj; i: Integer; Ok: Boolean;
begin
  Config := NewMKConfig(True);
  if Config = nil then begin writeln('no config'); halt(1); end;
  Config^.Load;
  N.Init; N.SetBbsType(1);
  Ok := N.SearchFirst(ParamStr(1));
  if not Ok then begin writeln('no such user'); halt(2); end;
  N.SetQwkNode(True);
  N.SetPacker('Z');
  N.SetOffMax(2000); N.SetOffConfMax(900);
  for i := 2 to ParamCount do N.SetUserOffline(Str2Long(ParamStr(i)), True);
  N.SaveChanges;
  writeln('ok');
end.
