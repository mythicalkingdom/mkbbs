Unit MKOffTxt;       {Text Offline mail Object}

{$I MKB.Def}

{
     MKOffTxt - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses MKGlobT, MKMsgAbs, MKOffAbs,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}


Type OffTxtInfoType = Record
  MsgPath: String;
  TF: Text;
  BBSID: String[8];
  End;


Type TxtOffObj = Object (AbsOffObj)
  TI: ^OffTxtInfoType;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetPath(MP: String); Virtual; {Set msg path/other info}
  Procedure SetBBSId(ID: String); Virtual; {Set BBS id/filename}
  Function  StartPacket: Word; Virtual; {Do Packet startup tasks}
  Function  ClosePacket: Word; Virtual; {Do Packet finish tasks}
  Function  AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean; Virtual;
  Function  GetArchiveName(Packer: Word): String; Virtual;
  End;


Type TxtOffPtr = ^TxtOffObj;


Implementation

Uses MKFile, MKString, MKCfgAbs;

Constructor TxtOffObj.Init;
  Begin
  New(TI);
  End;


Destructor TxtOffObj.Done;
  Begin
  Dispose(TI);
  End;


Procedure TxtOffObj.SetPath(MP: String);
  Begin
  TI^.MsgPath := WithBackSlash(MP);
  End;


Function TxtOffObj.StartPacket: Word;
  Begin
  Assign(TI^.TF, TI^.MsgPath + 'Message.Txt');
  ReWrite(TI^.TF);
  StartPacket := IoResult;
  End;


Function TxtOffObj.ClosePacket: Word;
  Begin
  Close(TI^.TF);
  ClosePacket := IoResult;
  End;


Function TxtOffObj.AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean;
  Var
    TmpStr: String;

  Const
    StLen = 72;

  Begin
  WriteLn(TI^.TF, '--------------------------------------------------------------------------');
  Write(TI^.TF, 'Message Number: ' + Long2Str(Msg.GetMsgNum));
  If Msg.IsPriv Then
    Write(TI^.TF,'  (Priv)');
  If Msg.IsRcvd Then
    Write(TI^.TF, ' (Rcvd)');
  WriteLn(TI^.TF);
  Write(TI^.TF, 'From: ' + PadRight(Msg.GetFrom,' ',45));
  Write(TI^.TF, 'Date: ');
  WriteLn(TI^.TF, ReformatDate(Msg.GetDate, 'MM/DD/YY')
    + ' ' + Msg.GetTime);
  WriteLn(TI^.TF, 'To: ' + Msg.GetTo);
  Write(TI^.TF, 'Subj: ');
  WriteLn(TI^.TF, Msg.GetSubj);
  WriteLn(TI^.TF);
  Msg.MsgTxtStartUp;
  TmpStr := Msg.GetString(StLen);
  While (Not Msg.EOM) Do
    Begin
    WriteLn(TI^.TF, TmpStr);
    TmpStr := Msg.GetString(StLen);
    End;
  AddMsg := IoResult = 0;
  End;


Function TxtOffObj.GetArchiveName(Packer: Word): String;
  Var
    TmpStr: String[15];

  Begin
  TmpStr := TI^.BbsId + '.';
  Case Packer Of
    1: TmpStr := TmpStr + 'LZH';
    2: TmpStr := TmpStr + 'ZIP';
    3: TmpStr := TmpStr + 'ARC';
    4: TmpStr := TmpStr + 'ZOO';
    5: TmpStr := TmpStr + 'DWC';
    6: TmpStr := TmpStr + 'ARJ';
    7: TmpStr := TmpStr + 'HYP';
    End;
  GetArchiveName := TmpStr;
  End;


Procedure TxtOffObj.SetBBSId(Id: String);
  Begin
  TI^.BBSId := Id;
  End;


End.
