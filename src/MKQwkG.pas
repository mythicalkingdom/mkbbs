Unit MKQwkG;                           {Global routines used by MKQwk}

{$I MKB.Def}

Interface

Uses MKGlobT, MKUsrAbs;

{$I MKQwk.Inc}

Var
  Ta: Byte;                            {Orig textattr}
  OrigDir: String[128];                {Startup directory}
  QCfg: QwkCfg;                        {Configuration record}
  QwkUser: QwkUserRec;                 {Current user record}
  QwkNumber: LongInt;                  {Current user record position}
  BBSUser: AbsUsrObjPtr;               {BBS user object pointer}


Function  LoadQwkCfg: Boolean;          {Load config information}
Function  SaveQwkCfg: Boolean;         {Save config information}
Procedure LoadBbsCfg;                  {Load Bbs config info}
Procedure LoadUser(Name: String);      {Loads or adds user}
Procedure SaveUser;


Implementation

Uses MKFFile, MKMisc, MKCfgAbs, MKRCfgR2, MKRCfgRA, MKRCfgMK,
  MKOffAbs, MKOffTxt, MKDos,
  MKFile, MKString, Dos,  MKCfgQB, MKCfgSB, MKRCfgEz;

Var
  CfgPath: String[128];

Function LoadQwkCfg: Boolean;
  Var
    TmpStr: String;

  Begin
  CfgPath := FindPath('config.mko');
  If FileExist(CfgPath) Then
    LoadQwkCfg := (LoadFile(CfgPath, QCfg, SizeOf(QCfg)) = 0)
  Else
    Begin
    LoadQwkCfg := False;
    CfgPath := 'config.mko';
    End;
  End;


Function SaveQwkCfg: Boolean;
  Begin
  SaveQwkCfg := (SaveFile(CfgPath, QCfg, SizeOf(QCfg)) = 0);
  End;


Procedure SetQwkUserDefaults;
  Begin
  QwkUser.UserConfs := QCfg.DefUserConfs;
  QwkUser.NetStat := QCfg.DefNetStat;
  QwkUser.MaxMsgs := QCfg.DefMaxMsgs;
  QwkUser.MaxConfMsgs := QCfg.DefMaxConfMsgs;
  QwkUser.Protocol := QCfg.DefProtocol;
  QwkUser.Packer := QCfg.DefPacker;
  QwkUser.Attr := QCfg.DefAttr;
  QwkUser.MailType := QCfg.DefMailType;
  QwkUser.Twits[1] := '';
  QwkUser.Twits[2] := '';
  QwkUser.Twits[3] := '';
  QwkUser.Twits[4] := '';
  QwkUser.Twits[5] := '';
  End;


Procedure LoadUser(Name: String);
  Var
    TUF: File;
    UFF: FFileObj;
    NumRead: Word;
    SName: String[35];
    UserFound: Boolean;
    NumUsers: LongInt;

  Begin
  If Not FileExist(WithBackSlash(QCfg.UserPath) + 'users.mko') Then
    Begin
    If IoResult <> 0 Then;
    Assign(TUF, WithBackSlash(QCfg.UserPath) + 'users.mko');
    ReWrite(TUF);
    Close(TUF);
    If IoResult <> 0 Then;
    End;
  UserFound := False;
  UFF.Init(15000);
  If UFF.OpenFile(WithBackSlash(QCfg.UserPath) + 'users.mko',
    fmReadWrite + fmDenyNone) Then
    Begin
    SName := Upper(Name);
    QwkNumber := 0;
    NumUsers := UFF.RawSize Div Sizeof(QwkUserRec);
    While ((QwkNumber < NumUsers) and (Not UserFound)) Do
      Begin
      If UFF.SeekFile(QwkNumber * SizeOf(QwkUserRec)) Then
        If UFF.BlkRead(QwkUser, SizeOf(QwkUserRec), NumRead) Then
          UserFound := (SName = Upper(QwkUser.Name));
      If Not UserFound Then
        Inc(QwkNumber);
      End;
    If Not UserFound Then
      Begin
      SetQwkUserDefaults;
      QwkUser.Name := Name;
      QwkUser.LastUsed := GetDosDate;
      QwkUser.MsgsDL := 0;
      QwkUser.MsgsUL := 0;
      QwkNumber := UFF.RawSize Div SizeOf(QwkUserRec);
      If UFF.SeekFile(QwkNumber * SizeOf(QwkUserRec)) Then
        If UFF.BlkWrite(QwkUser, SizeOf(QwkUser)) Then;
      End;
    End;
  If UFF.CloseFile Then;
  UFF.Done;
  End;


Procedure SaveUser;
  Begin
  Filemode := fmReadWrite + fmDenyNone;
  If QwkNumber >= 0 Then
    If SaveFilePos(WithBackSlash(QCfg.UserPath) + 'users.mko', QwkUser,
      SizeOf(QwkUser), QwkNumber * SizeOf(QwkUser)) =0 Then;
  End;


Procedure LoadBbsCfg;
  Var
    Tmp: LongInt;
    BBSType: Word;

  Begin
  Config := Nil;
  BbsType := DetectBbsType;
  Case BbsType Of
    1: Config := New(MKRCfgObjPtr, Init);
    2: Begin
       If FileExist('config.ra') Then
         Begin
         Tmp := SizeFile('config.ra');
         End
       Else
         Begin
         Tmp := SizeFile(WithBackSlash(GetEnv('RA')) + 'config.ra');
         End;
       If Tmp < 6300 Then
         Config := New(RARCfgObjPtr, Init)
       Else
         Config := New(R2RCfgObjPtr, Init);
       End;
    3: Config := New(QBCfgObjPtr, Init);
    4: Config := New(SBCfgObjPtr, Init);
    5: Config := New(EzRCfgObjPtr, Init);
    Else
      Config := nil;
    End;
  If Config <> Nil Then
    Begin
    Config^.Load;
    If Config^.GetError <> 0 Then
      Begin
      Dispose(Config, Done);
      Config := Nil;
      End;
    End;
  End;


End.
