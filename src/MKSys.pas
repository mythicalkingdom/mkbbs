Unit MKSys;
{$I MKB.Def}

Interface

Uses MKGlobT, MKRCfgMK;

Type SysStatObj = Object
  NumMsgs: LongInt;
  Procedure Load;                           {Load msg info records}
  Function  GetNumberOfMsgs: LongInt;       {Get number of msgs on system}
  Function  GetNumUsers: Word;              {Get number of users}
  End;


Var
  SysStats: SysStatObj;

Implementation


Uses MKFile, MKString, MKCfgAbs, MKMsgAbs, MKMsgFid, MKMsgHud, MKMsgSqu,
  Dos;


Procedure SysStatObj.Load;          {Load}
  Var
    Count: LongInt;
    HudsonDone: Boolean;
    TmpStr: String;
    CMsg: AbsMsgPtr;

  Begin
  NumMsgs := 0;
  HudsonDone := False;
  For Count := 1 to 500 Do
    Begin
    If (Length(Config^.GetMsgName(Count)) > 0) Then
      Begin
      TmpStr := Config^.GetMsgAreaId(Count);
      Case TmpStr[1] Of
        'S': Begin
             CMsg := New(SqMsgPtr, Init);
             CMsg^.SetMsgPath(Copy(TmpStr,2,128));
             Inc(NumMsgs, CMsg^.NumberOfMsgs);
             Dispose(CMsg, Done);
             End;
        'H': Begin
             If Not HudsonDone Then
               Begin
               CMsg := New(HudsonMsgPtr, Init);
               CMsg^.SetMsgPath(Copy(TmpStr,2,128));
               Inc(NumMsgs, CMsg^.NumberOfMsgs);
               Dispose(CMsg, Done);
               HudsonDone := True;
               End;
             End;
        'F': Begin
             CMsg := New(FidoMsgPtr, Init);
             CMsg^.SetMsgPath(Copy(TmpStr,2,128));
             Inc(NumMsgs, CMsg^.NumberOfMsgs);
             Dispose(CMsg, Done);
             End;
        End;
      End;
    End;
  End;


Function SysStatObj.GetNumberOfMsgs: LongInt; {Get number of msgs on system}
  Begin
  GetNumberOfMsgs :=  NumMsgs;
  End;


Function SysStatObj.GetNumUsers: Word;              {Get number of users}
  Begin
  GetNumUsers := (SizeFile(Config^.FindBbsFile('users.bbs') + 'users.bbs') Div
    SizeOf(UsersType));
  End;


End.
