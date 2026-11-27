{ SPDX-License-Identifier: GPL-3.0-or-later }
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

Uses MKGlobT, MKMsgAbs, MKDoor,
  Dos;


Type OffImportOpts = Record            {how the reply packet of a caller is posted (ImportPacket)}
  BadArea: Word;                       {message area for replies that cannot go where they were meant (0 = refuse them)}
  ForceName: Boolean;                  {the messages are From the caller (a QWK network node posts in the names of its users)}
  ReDate: Boolean;                     {the messages get the date of the import}
  DupeFile: String[250];               {file of the duplicate check ('' = none)}
  End;


Type AbsOffObj = Object
  User: DoorUserPtr;                   {the caller (MKDoor.User unless SetUsrPtr says otherwise)}
  ImpOpts: OffImportOpts;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetUsrPtr(Var U: DoorUserPtr);
  Procedure SetImportOpts(Var O: OffImportOpts); {before ImportPacket}
  Procedure SetQwke(QK: Boolean); Virtual;     {QWKE long names and subjects in the packet (QWK only)}
  Procedure SetControlFiles(CF: Boolean); Virtual; {CONTROL.DAT and DOOR.ID in the packet (QWK only; default yes)}
  Procedure SetPath(MP: String); Virtual; {Set msg path/other info}
  Procedure SetBBSID(ID: String); Virtual; {Set BBS id/filename}
  Function  AreaInPacket(Area: Word): Boolean; Virtual; {The packet has messages of the area (QWK: the conference is the area)}
  Procedure SetScreenFile(N: Word; Name: String); Virtual; {The file of screen 1 (welcome), 2 (news) or 3 (goodbye) in the packet, as CONTROL.DAT names it (QWK only)}
  Function  StartPacket: Word; Virtual; {Do Packet startup tasks}
  Function  ClosePacket: Word; Virtual; {Do Packet finish tasks}
  Function  AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean; Virtual;
  Function  GetArchiveName(Packer: Word): String; Virtual;
  Function  GetReplyName: String; Virtual;
  Function  GetExtractSpec: String; Virtual;
  Procedure ImportPacket; Virtual;     {put the messages of the reply packet in the work path (SetPath) into the message areas}
  Function  GetImported: LongInt; Virtual; {messages the last ImportPacket posted}
  End;


Type AbsOffPtr = ^AbsOffObj;


Implementation


Constructor AbsOffObj.Init;
  Begin
  User := @MKDoor.User;
  FillChar(ImpOpts, SizeOf(ImpOpts), 0);
  ImpOpts.ForceName := True;
  End;


Procedure AbsOffObj.SetScreenFile(N: Word; Name: String);
  Begin
  End;


Function AbsOffObj.AreaInPacket(Area: Word): Boolean;
  Begin
  AreaInPacket := False;
  End;


Procedure AbsOffObj.SetQwke(QK: Boolean);
  Begin
  End;


Procedure AbsOffObj.SetControlFiles(CF: Boolean);
  Begin
  End;


Procedure AbsOffObj.SetImportOpts(Var O: OffImportOpts);
  Begin
  ImpOpts := O;
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


Procedure AbsOffObj.SetUsrPtr(Var U: DoorUserPtr);
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


Function AbsOffObj.GetImported: LongInt;
  Begin
  GetImported := 0;
  End;


Procedure AbsOffObj.SetBBSId(ID: String);
  Begin
  End;


End.
