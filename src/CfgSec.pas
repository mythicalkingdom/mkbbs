Unit CfgSec;   {Converted from CFGSEC for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgSec;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;



Type UserRecord = Record
  PassTries: Byte;
  PwdExpire: Word;
  CheckBD: Byte;
  CheckPhone: Byte;
  MinPwd: Byte;
  MinPhone: Byte;
  StrictPwd: Boolean;
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
  UR^.CheckBD := Config^.GetBDCheck;
  UR^.CheckPhone := Config^.GetPhoneCheck;
  UR^.MinPwd := Config^.GetMinPwd;
  UR^.MinPhone := Config^.GetMinPhone;
  UR^.StrictPwd := Config^.GetStrictPwd;
  UR^.SysopRemote := Config^.GetRemoteSysop;
  UR^.FastLogIn := Config^.GetFastLocal;
  F.Init('Security');
  F.Window(9, 6, 71, 16);
  F.At(2, 3, 2, 19);
  F.AddNumber('Password Tries:', UR^.PassTries, 1, 0, 255, 'Password Tries');
  F.At(2, 33, 2, 54);
  F.AddNumber('Password Expiration:', UR^.PwdExpire, 2, 0, 999, 'Password Expiration');
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
  If F.Execute Then
    Begin
    Config^.SetPwdTries(UR^.PassTries);
    Config^.SetPwdExpire(UR^.PwdExpire);
    Config^.SetBDCheck(UR^.CheckBD);
    Config^.SetPhoneCheck(UR^.CheckPhone);
    Config^.SetMinPwd(UR^.MinPwd);
    Config^.SetMinPhone(UR^.MinPhone);
    Config^.SetStrictPwd(UR^.StrictPwd);
    Config^.SetRemoteSysop(UR^.SysopRemote);
    Config^.SetFastLocal(UR^.FastLogIn);
    End;
    Dispose(UR);
  End;


End.
