{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgSec;   {Converted from CFGSEC for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgSec;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;



Type UserRecord = Record
  PassTries: Byte;
  PwdExpire: Word;
  LockFails: Byte;
  LockMinutes: Word;
  PwdWarn: Byte;
  CheckBD: Byte;
  CheckPhone: Byte;
  MinPwd: Byte;
  MinPhone: Byte;
  StrictPwd: Boolean;
  PwdHash: Byte;
  SysopRemote: Boolean;
  FastLogIn: Boolean;
  End;

Var
  UR: ^UserRecord;

Procedure DoCfgSec;
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.PassTries := Config^.GetPwdTries;
  UR^.PwdExpire := Config^.GetPwdExpire;
  UR^.LockFails := Config^.GetLockFails;
  UR^.LockMinutes := Config^.GetLockMinutes;
  UR^.PwdWarn := Config^.GetPwdWarn;
  UR^.CheckBD := Config^.GetBDCheck;
  UR^.CheckPhone := Config^.GetPhoneCheck;
  UR^.MinPwd := Config^.GetMinPwd;
  UR^.MinPhone := Config^.GetMinPhone;
  UR^.StrictPwd := Config^.GetStrictPwd;
  UR^.PwdHash := Config^.GetPwdMode;
  UR^.SysopRemote := Config^.GetRemoteSysop;
  UR^.FastLogIn := Config^.GetFastLocal;
  F.Init('Security');
  F.Window(9, 4, 71, 20);
  F.At(2, 3, 2, 19);
  F.AddNumber('Password Tries:', UR^.PassTries, 1, 0, 255, 'Password Tries');
  F.At(2, 33, 2, 58);
  F.AddNumber('Password Expires (days):', UR^.PwdExpire, 2, 0, 255, 'Days a password is good for before its owner must choose a new one at log-on; 0 = never (MK users only)');
  F.At(4, 3, 4, 19);
  F.AddNumber('Birthday Check:', UR^.CheckBD, 1, 0, 255, 'Birthday Check');
  F.At(4, 33, 4, 46);
  F.AddNumber('Phone Check:', UR^.CheckPhone, 1, 0, 255, 'Phone Check');
  F.At(6, 3, 6, 28);
  F.AddNumber('Minimum Password Length:', UR^.MinPWD, 1, 1, 30, 'Minimum Password Length');
  F.At(6, 33, 6, 57);
  F.AddNumber('Minimum Phone # Length:', UR^.MinPhone, 1, 1, 15, 'Minimum Phone # Length');
  F.At(8, 3, 8, 29);
  F.AddYesNo('Strict Password Checking:', UR^.StrictPWD, 'Strict Password Checking');
  F.At(8, 33, 8, 53);
  F.AddYesNo('Allow Remote Sysop:', UR^.SysopRemote, 'Allow Remote Sysop');
  F.At(10, 3, 10, 22);
  F.AddYesNo('Fast Local Log-in:', UR^.FastLogIn, 'Fast Local Log-in');
  If DetectBbsType = 1 Then
    Begin
    F.At(12, 3, 12, 22);
    F.AddChoice('Hashed Passwords:', UR^.PwdHash, 1, 0, 'No|New|All',
      'No: passwords stay as they are.  New: a new or changed password is stored as a hash.  All: and a plain password becomes a hash when its owner logs on.');
    F.At(14, 3, 14, 24);
    F.AddNumber('Lock After Failures:', UR^.LockFails, 1, 0, 255, 'Wrong passwords in a row (over all calls) after which the account is locked; 0 = never.  The sysop unlocks it in the user editor');
    F.At(14, 33, 14, 56);
    F.AddNumber('Locked For (minutes):', UR^.LockMinutes, 2, 1, 9999, 'Minutes a locked account stays locked (a good password does not open it meanwhile)');
    F.At(16, 3, 16, 30);
    F.AddNumber('Warn Before Expiry (days):', UR^.PwdWarn, 1, 0, 255, 'Days before a password expires that its owner is told at log-on; 0 = no warning');
    End;
  If F.Execute Then
    Begin
    Config^.SetPwdTries(UR^.PassTries);
    Config^.SetPwdExpire(UR^.PwdExpire);
    If DetectBbsType = 1 Then
      Begin
      Config^.SetLockFails(UR^.LockFails);
      Config^.SetLockMinutes(UR^.LockMinutes);
      Config^.SetPwdWarn(UR^.PwdWarn);
      End;
    Config^.SetBDCheck(UR^.CheckBD);
    Config^.SetPhoneCheck(UR^.CheckPhone);
    Config^.SetMinPwd(UR^.MinPwd);
    Config^.SetMinPhone(UR^.MinPhone);
    Config^.SetStrictPwd(UR^.StrictPwd);
    Config^.SetRemoteSysop(UR^.SysopRemote);
    Config^.SetFastLocal(UR^.FastLogIn);
    Config^.SetPwdMode(UR^.PwdHash);
    End;
    Dispose(UR);
  End;


End.
