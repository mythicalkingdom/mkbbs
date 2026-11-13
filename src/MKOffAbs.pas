Unit MKOffAbs;       {Abstract Offline mail Object}

{$I MKB.Def}

{
     MKOffAbs - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses MKGlobT, MKMsgAbs, MKUsrAbs,
  Dos;


Type AbsOffObj = Object
  User: AbsUsrObjPtr;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetUsrPtr(Var U: AbsUsrObjPtr);
  Procedure SetPath(MP: String); Virtual; {Set msg path/other info}
  Procedure SetBBSID(ID: String); Virtual; {Set BBS id/filename}
  Function  StartPacket: Word; Virtual; {Do Packet startup tasks}
  Function  ClosePacket: Word; Virtual; {Do Packet finish tasks}
  Function  AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean; Virtual;
  Function  GetArchiveName(Packer: Word): String; Virtual;
  Function  GetReplyName: String; Virtual;
  Function  GetExtractSpec: String; Virtual;
  Procedure ImportPacket; Virtual;
  End;


Type AbsOffPtr = ^AbsOffObj;


Implementation


Constructor AbsOffObj.Init;
  Begin
  End;


Destructor AbsOffObj.Done;
  Begin
  End;


Procedure AbsOffObj.SetPath(MP: String);
  Begin
  End;


Function AbsOffObj.StartPacket: Word;
  Begin
  End;


Function AbsOffObj.ClosePacket: Word;
  Begin
  End;


Function AbsOffObj.AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean;
  Begin
  End;


Function AbsOffObj.GetArchiveName(Packer: Word): String;
  Begin
  End;


Procedure AbsOffObj.SetUsrPtr(Var U: AbsUsrObjPtr);
  Begin
  User := U;
  End;


Function AbsOffObj.GetReplyName: String;
  Begin
  GetReplyName := '';
  End;


Function AbsOffObj.GetExtractSpec: String;
  Begin
  GetExtractSpec := '';
  End;


Procedure AbsOffObj.ImportPacket;
  Begin
  End;


Procedure AbsOffObj.SetBBSId(ID: String);
  Begin
  End;


End.
