program pwusertest;
{$mode tp}
{$H+}
{ The password of a user (DoorUser): plain and hashed, saved and read back from the user files.
  pwusertest <dir>   MK=<a private copy of the BBS (extusers.bbs of the new size)>; the users it makes are called PWT-... }
uses Dos, MKString, MKFile, MKCfgAbs, MKRCfgMK, MKCfgNew, MKGlobT, MKDoor, MKDos, MKPwd, MKShell;

var Fails: Integer;

procedure Check(Ok: Boolean; const What: String);
begin
  if Ok then writeln('ok   password: ', What) else begin writeln('FAIL password: ', What); Inc(Fails); end;
end;

procedure NewUser(const Name: String);
var Sec: SecType;
begin
  Config^.GetNewUserSec(Sec);
  User.SetUserName(Name);
  User.SetUserSec(Sec);
  User.SetUserLastDate('00-00-00');
  User.SetUserFirstDate(DateStr(GetDosDate));
end;

{ the user from the files again }
procedure Reload(const Name: String);
begin
  User.Init;
  User.SetUserBbsType(1);
  User.GetUserPos(Name);
  User.ReadUser;
end;

var Sec: SecType; H: PwHashType; n: LongInt; T: Text; L, Doors: String; k: Word;
begin
  Fails := 0;
  Config := NewMKConfig(True);
  if Config = nil then begin writeln('no config'); halt(1); end;
  Config^.Load;
  PwdIterations := 300;

  { plain, mode off: the DOS behaviour }
  PwdMode := pmPlain;
  User.Init; User.SetUserBbsType(1);
  NewUser('PWT-Plain');
  Check(User.UserPwdMaxLen = 15, 'plain: 15 characters');
  Check(User.ChangeUserPwd('Secret1'), 'plain: set');
  Check(User.GetUserPwd = 'SECRET1', 'plain: kept in upper case');
  Check(not User.UserPwdIsHashed, 'plain: not hashed');
  Check(User.CheckUserPwd('secret1') and User.CheckUserPwd('SECRET1'), 'plain: any case');
  Check(not User.CheckUserPwd('secret2') and not User.CheckUserPwd(''), 'plain: wrong');
  Check(not User.ChangeUserPwd('1234567890123456'), 'plain: 16 characters refused');
  Check(not User.ChangeUserPwd('*'), 'plain: * refused (it is the marker)');
  Check(User.GetUserPwdShown = 'SECRET1', 'plain: shown as it is');
  User.AddUser;

  { hashing on for new and changed passwords }
  PwdMode := pmHashNew;
  Reload('PWT-Plain');
  Check(User.CheckUserPwd('secret1') and not User.UserPwdIsHashed, 'a plain user stays plain when only checked');
  User.Init; User.SetUserBbsType(1);
  NewUser('PWT-Hash');
  Check(User.UserPwdMaxLen = 50, 'hash mode: 50 characters');
  Check(User.ChangeUserPwd('My Long pass/phrase!'), 'hash: set (blanks and a slash)');
  Check(User.UserPwdIsHashed and (User.GetUserPwd = '*'), 'hash: the Pwd field is *');
  Check(User.GetUserPwdShown = 'unavailable', 'hash: DOOR.SYS shows unavailable');
  Check(User.CheckUserPwd('My Long pass/phrase!'), 'hash: right');
  Check(not User.CheckUserPwd('my long pass/phrase!'), 'hash: case counts');
  Check(not User.CheckUserPwd('*') and not User.CheckUserPwd('unavailable') and not User.CheckUserPwd(''), 'hash: the marker and the shown word are no passwords');
  Check(not User.ChangeUserPwd('*'), 'hash: * refused');
  Check(not User.ChangeUserPwd(''), 'hash: nothing refused');
  User.AddUser;
  Reload('PWT-Hash');
  Check(User.UserPwdIsHashed and User.CheckUserPwd('My Long pass/phrase!'), 'hash: saved and read back');
  Check(not User.CheckUserPwd('My Long pass/phrase'), 'hash: a prefix is wrong after reading back');

  { mode off again: a hash is not turned back into plain text }
  PwdMode := pmPlain;
  Check(User.UserPwdMaxLen = 50, 'mode off: a hashed user still takes 50');
  Check(User.ChangeUserPwd('Another One'), 'hash: changed with the mode off');
  Check(User.UserPwdIsHashed and User.CheckUserPwd('Another One') and not User.CheckUserPwd('My Long pass/phrase!'), 'hash: stays a hash, the new one counts');
  User.WriteUser;
  Reload('PWT-Hash');
  Check(User.CheckUserPwd('Another One'), 'hash: the change is saved');

  { DOOR.SYS: the 11th line is the password: the word unavailable for a hash, the password for a plain account }
  ChDir(GetEnv('MK'));
  Doors := '';
  Check(WriteDoorSys = 0, 'DOOR.SYS is written');
  Assign(T, 'door.sys'); Reset(T);
  k := 0;
  While Not Eof(T) Do begin ReadLn(T, L); Inc(k); Doors := Doors + '|' + L; end;
  Close(T);
  Check(Pos('|unavailable|', Doors) > 0, 'DOOR.SYS (hashed): the password line says unavailable');
  Check((Pos('Another One', Doors) = 0) and (Pos('ANOTHER ONE', Doors) = 0) and (Pos('|*|', Doors) = 0), 'DOOR.SYS (hashed): neither the password nor the marker');
  Reload('PWT-Plain');
  User.SetUserPwd('PLAINDOOR');
  Check(WriteDoorSys = 0, 'DOOR.SYS is written for a plain account');
  Assign(T, 'door.sys'); Reset(T);
  Doors := '';
  While Not Eof(T) Do begin ReadLn(T, L); Doors := Doors + '|' + L; end;
  Close(T);
  Check(Pos('|PLAINDOOR|', Doors) > 0, 'DOOR.SYS (plain): the password as before');
  Reload('PWT-Hash');

  { a hash missing: nobody gets in }
  User.SetUserPwd('*');
  Reload('PWT-Plain');
  User.SetUserPwd('*');
  Check(not User.CheckUserPwd('*') and not User.CheckUserPwd('SECRET1'), 'a * without a hash: nobody gets in');

  { the conversion when the owner logs in }
  PwdMode := pmConvert;
  Reload('PWT-Plain');
  Check(not User.CheckUserPwd('wrong') and not User.UserPwdIsHashed, 'convert: a wrong password converts nothing');
  User.SetUserPwd('SECRET1');
  Check(User.CheckUserPwd('secret1') and User.UserPwdIsHashed, 'convert: the right password converts');
  User.WriteUser;
  Reload('PWT-Plain');
  Check(User.UserPwdIsHashed and (User.GetUserPwd = '*'), 'convert: saved');
  Check(User.CheckUserPwd('SECRET1') and User.CheckUserPwd('secret1') and User.CheckUserPwd('Secret1'), 'convert: any case still goes in (it was compared in upper case before)');
  Check(not User.CheckUserPwd('SECRET') and not User.CheckUserPwd('SECRET11'), 'convert: wrong');

  { fewer iterations than now: rehashed at a login }
  PwdIterations := 600;
  Check(User.CheckUserPwd('secret1'), 'rehash: still right');
  User.WriteUser;
  Reload('PWT-Plain');
  Check(User.CheckUserPwd('secret1'), 'rehash: saved and right');

  { other BBS formats: no hashes, whatever the mode }
  PwdMode := pmConvert;
  User.Init; User.SetUserBbsType(3);
  User.SetUserName('PWT-QB');
  Check(User.UserPwdMaxLen = 15, 'QuickBBS: 15 characters');
  Check(User.ChangeUserPwd('abc'), 'QuickBBS: set');
  Check(not User.UserPwdIsHashed and (User.GetUserPwd = 'ABC'), 'QuickBBS: plain');
  Check(User.CheckUserPwd('abc') and not User.UserPwdIsHashed, 'QuickBBS: checked, not converted');
  User.Init; User.SetUserBbsType(2);
  User.SetUserPwd('*');
  Check(not User.UserPwdIsHashed, 'Remote Access: a * is just a password');

  writeln('failures: ', Fails);
  if Fails > 0 then halt(1);
end.
