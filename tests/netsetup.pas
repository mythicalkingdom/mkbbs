program netsetup;
{$mode tp}
{$H+}
{ netsetup <user name> <area> [area ...]   makes the user a QWK node (flag), ZIP packer, the areas in its offline mail,
  limits as the BBS has them; environment NETSEC=<level> sets the security level (all flags), NETPWD / NETPROT the password and protocol (tests/qwknettest.py).  MK=<config dir> }
uses Dos, MKString, MKCfgAbs, MKRCfgMK, MKCfgNew, MKName, MKGlobT;

var N: NameObj; i: Integer; Ok: Boolean; Sec: SecType;
begin
  Config := NewMKConfig(True);
  if Config = nil then begin writeln('no config'); halt(1); end;
  Config^.Load;
  N.Init; N.SetBbsType(1);
  Ok := N.SearchFirst(ParamStr(1));
  if not Ok then begin writeln('no such user'); halt(2); end;
  N.SetQwkNode(True);
  N.SetPacker('Z');
  if GetEnv('NETPWD') <> '' then N.SetOffOwn(True);
  N.SetOffMax(2000); N.SetOffConfMax(900);
  for i := 2 to ParamCount do N.SetUserOffline(Str2Long(ParamStr(i)), True);
  if GetEnv('NETPWD') <> '' then N.SetPwd(GetEnv('NETPWD'));
  if GetEnv('NETPROT') <> '' then N.SetProt(GetEnv('NETPROT')[1]);
  if GetEnv('NETSEC') <> '' then begin Sec.Level := Str2Long(GetEnv('NETSEC')); Sec.Flags := 255; N.SetSec(Sec); end;
  N.SaveChanges;
  writeln('ok');
end.
