{ SPDX-License-Identifier: GPL-3.0-or-later }
program useradd;
{$mode tp}
{$H+}
{ useradd <name> <password>: adds a user record to the BBS (MK=<config dir>) the way mk does for a new caller (new user security,
  dates).  Prints "added <number>" or "exists".  Used by tests and by the setup of a hub test (tests/hubsetup.py). }
uses MKString, MKCfgAbs, MKRCfgMK, MKCfgNew, MKGlobT, MKDoor, MKDos, Dos;

var Sec: SecType; i: Word;
begin
  Config := NewMKConfig(True);
  if Config = nil then begin writeln('no config'); halt(1); end;
  Config^.Load;
  User.Init;
  User.SetUserBbsType(1);
  User.GetUserPos(ParamStr(1));
  if User.UserFound then begin writeln('exists'); halt(0); end;
  Config^.GetNewUserSec(Sec);
  User.SetUserName(ParamStr(1));
  User.SetUserPwd(ParamStr(2));
  User.SetUserSec(Sec);
  User.SetUserLastDate('00-00-00');
  User.SetUserFirstDate(DateStr(GetDosDate));
  User.AddUser;
  writeln('added ', User.GetUserRecNum);
end.
