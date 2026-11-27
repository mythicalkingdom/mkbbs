{ SPDX-License-Identifier: GPL-3.0-or-later }
program pwstate;
{$mode tp}
{$H+}
{ pwstate <name> [<changed> <fails> <failtime> <lockuntil>]: shows the state of the password of a user (MK=<config dir>): when it was set,
  the wrong passwords in a row, when the last was typed, until when the account is locked (seconds since 1970); with the four numbers sets it }
uses MKString, MKCfgAbs, MKRCfgMK, MKCfgNew, MKGlobT, MKDoor, MKPwd;
var S: PwStateType; Code: Integer; V: LongInt;
begin
  Config := NewMKConfig(True);
  if Config = nil then begin writeln('no config'); halt(1); end;
  Config^.Load;
  PwdModeFromConfig;
  User.Init;
  User.SetUserBbsType(1);
  User.GetUserPos(ParamStr(1));
  if not User.UserFound then begin writeln('no such user'); halt(1); end;
  User.ReadUser;
  User.GetPwdState(S);
  if ParamCount >= 5 then begin
    Val(ParamStr(2), S.Changed, Code); Val(ParamStr(3), V, Code); S.Fails := V; Val(ParamStr(4), S.FailTime, Code); Val(ParamStr(5), S.LockUntil, Code);
    User.SetPwdState(S);
    User.WritePwdState;
    writeln('set');
  end else
    writeln('changed=', S.Changed, ' fails=', S.Fails, ' failtime=', S.FailTime, ' lockuntil=', S.LockUntil);
end.
