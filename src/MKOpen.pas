{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKOpen; {Open a message area using an MsgAreaId}

{$I MKB.Def}

{
     MKOpen - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses MKMsgAbs;

Function OpenMsgArea(Var Msg: AbsMsgPtr; MsgAreaId: String): Boolean;
Function OpenOrCreateMsgArea(Var Msg: AbsMsgPtr; MsgAreaId: String): Boolean;
Function CloseMsgArea(Var Msg: AbsMsgPtr): Boolean;
Function InitMsgPtr(Var Msg: AbsMsgPtr; MsgAreaId: String): Boolean;
Function DoneMsgPtr(Var Msg: AbsMsgPtr): Boolean;

Implementation


Uses MKMsgHud, MKMsgFid, MKMsgSqu, MKMsgEzy, MKMsgJam, MKMsgMer, MKMsgSyn,
  MKMsgPCB;

{ Area ids begin with identifier for msg base type }
{ The following characters are already reserved    }
{   B = PC-Board          + }
{   E = Ezycomm           * }
{   F = Fido *.Msg        * }
{   H = Hudson            * }
{   I = ISR - msg fossil    }
{   J = JAM               * }
{   M = MK-Merlin         + }
{   P = *.PKT               }
{   Q = QWK/REP             }
{   R = Renegade          3 }
{   S = Squish            * }
{   W = Wildcat             }
{   Y = Synchronet (SMB)  + path without extension }


Function OpenMsgArea(Var Msg: AbsMsgPtr; MsgAreaId: String): Boolean;
  Begin
  If InitMsgPtr(Msg, MsgAreaId) Then
    Begin
    OpenMsgArea := True;
    If Msg^.OpenMsgBase <> 0 Then
      Begin
      OpenMsgArea := False;
      If DoneMsgPtr(Msg) Then;
      End;
    End
  Else
    OpenMsgArea := False;
  End;


Function OpenOrCreateMsgArea(Var Msg: AbsMsgPtr; MsgAreaId: String): Boolean;
  {The original tested "Not CreateMsgBase(...) = 0", which is never true, so a
   failed create went unnoticed.  Now a failed create or open gives False and
   the message object is released.}
  Var
    Ok: Boolean;

  Begin
  Ok := InitMsgPtr(Msg, MsgAreaId);
  If Ok Then
    Begin
    If Not Msg^.MsgBaseExists Then
      If Msg^.CreateMsgBase(200, 10) <> 0 Then
        Ok := False;
    If Ok Then
      If Msg^.OpenMsgBase <> 0 Then
        Ok := False;
    If Not Ok Then
      If DoneMsgPtr(Msg) Then;
    End;
  OpenOrCreateMsgArea := Ok;
  End;


Function CloseMsgArea(Var Msg: AbsMsgPtr): Boolean;
  Begin
  If Msg <> Nil Then
    Begin
    CloseMsgArea := (Msg^.CloseMsgBase = 0);
    If DoneMsgPtr(Msg) Then;
    End
  Else
    CloseMsgArea := False;
  End;


Function InitMsgPtr(Var Msg: AbsMsgPtr; MsgAreaId: String): Boolean;
  Begin
  Msg := Nil;
  InitMsgPtr := True;
  Case UpCase(MsgAreaId[1]) of
    'H': Msg := New(HudsonMsgPtr, Init);
    'S': Msg := New(SqMsgPtr, Init);
    'F': Msg := New(FidoMsgPtr, Init);
    'E': Msg := New(EzyMsgPtr, Init);
    'J': Msg := New(JamMsgPtr, Init);
    'M': Msg := New(MerlinMsgPtr, Init);
    'Y': Msg := New(SynMsgPtr, Init);
    'B': Msg := New(PCBMsgPtr, Init);
    Else
      InitMsgPtr := False;
    End;
  If Msg <> Nil Then
    Msg^.SetMsgPath(Copy(MsgAreaId, 2, 128));
  End;


Function DoneMsgPtr(Var Msg: AbsMsgPtr): Boolean;
  Begin
  DoneMsgPtr := (Msg <> Nil);
  If Msg <> Nil Then
    Dispose(Msg, Done);
  Msg := Nil;
  End;

End.
