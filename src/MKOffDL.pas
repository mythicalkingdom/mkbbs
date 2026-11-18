Unit MKOffDL;        {offline mail: the messages of a packet for a caller}

{$I MKB.Def}

{
     MKOffDL - which messages go into an offline mail packet, for mk (MKOfflin) and for the offline mail door (MKQwkO).
     OffExport goes through the message areas the caller has chosen (Sel), puts the messages that are new
     to him into the packet (Offline^.AddMsg) and notes how far he has read (R.NewLR).  The last read pointers are
     changed by OffCommitLR once the packet has been sent.

       Sel(N, Area, Mode)   the N-th area (N = 1, 2 ...): its number and what is wanted of it
                            omAll = every new message, omMy = those to the caller, omAllYour = those to the caller
                            and to All; False when there are no more
       Ev(What, Area, N)    progress (may be Nil): oeArea = an area is started (N = areas so far), oeAreaMsg =
                            a message of the area is in the packet (N = messages of the area), oePktMsg (N = messages
                            in the packet), oeAreaEnd = the area is done
       MaxMsgs, AreaMax     limits of the packet and of one area
       OwnMsgs              messages written by the caller are put in the packet, too
       CheckUser            interactive: stops when the caller is gone or has stopped it (User.Ok)

     A message is for the packet when the caller may read the area, the message is public or he is allowed to see
     private ones (sysop access, it is to or from him, the net status of the area is his), and it is new (after his last read).
     In the last read pointer every message that has been looked at counts, so those left out are not looked at again.
     The caller's last read is by the number of the user for most message bases and by a CRC of his name for JAM.
}


Interface


Uses MKGlobT, MKOffAbs;


Const
  omAll = 1;
  omMy = 2;
  omAllYour = 3;

  oeArea = 1;
  oeAreaMsg = 2;
  oePktMsg = 3;
  oeAreaEnd = 4;

  OffAreas = 2000;


Type OffSelProc = Function(N: Word; Var Area: Word; Var Mode: Byte): Boolean;
Type OffEvProc = Procedure(What: Word; Area: Word; N: LongInt);


Type OffDLParams = Record
  Sel: OffSelProc;
  Ev: OffEvProc;
  MaxMsgs: LongInt;
  AreaMax: LongInt;
  OwnMsgs: Boolean;
  CheckUser: Boolean;
  End;


Type OffDLResult = Record
  NumMsgs: LongInt;                    {messages in the packet}
  NumAreas: Word;                      {areas looked at}
  Failed: Boolean;                     {the packet could not be made}
  NewLR: Array[1..OffAreas] Of LongInt; {the last message looked at in each area, -1 = not looked at}
  End;


Function OffExport(Offline: AbsOffPtr; Var P: OffDLParams; Var R: OffDLResult): Boolean;
  {False when the packet could not be made}
Function OffUserLR(Area: Word): LongInt;
Procedure OffSetUserLR(Area: Word; N: LongInt);
Procedure OffCommitLR(Var R: OffDLResult);
  {the last read of the caller is what the packet had}


Implementation


Uses MKString, MKOpen, MKMsgAbs, MKMsgJam, MKCfgAbs, MKDoor;


Function IsJam(Area: Word): Boolean;
  Begin
  IsJam := Upper(Copy(Config^.GetMsgAreaId(Area), 1, 1)) = 'J';
  End;


Function LRNum(Area: Word): LongInt;
  Begin
  If IsJam(Area) Then
    LRNum := JamStrCrc(User.GetUserName)
  Else
    LRNum := User.GetUserRecNum;
  End;


Function OffUserLR(Area: Word): LongInt;
  Var
    CMsg: AbsMsgPtr;

  Begin
  OffUserLR := 0;
  If OpenMsgArea(CMsg, Config^.GetMsgAreaId(Area)) Then
    Begin
    OffUserLR := CMsg^.GetLastRead(LRNum(Area));
    If CloseMsgArea(CMsg) Then;
    End;
  End;


Procedure OffSetUserLR(Area: Word; N: LongInt);
  Var
    CMsg: AbsMsgPtr;

  Begin
  If OpenMsgArea(CMsg, Config^.GetMsgAreaId(Area)) Then
    Begin
    CMsg^.SetLastRead(LRNum(Area), N);
    If CloseMsgArea(CMsg) Then;
    End;
  End;


Procedure OffCommitLR(Var R: OffDLResult);
  Var
    i: Word;

  Begin
  For i := 1 To OffAreas Do
    If R.NewLR[i] >= 0 Then
      OffSetUserLR(i, R.NewLR[i]);
  End;


Function OffExport(Offline: AbsOffPtr; Var P: OffDLParams; Var R: OffDLResult): Boolean;
  Var
    CMsg: AbsMsgPtr;
    N: Word;
    Area: Word;
    Mode: Byte;
    Sec: SecType;
    CName, CHdl, ToName: String[35];
    SysopAccess, NetAccess, FromYou, ToYou, ToAll, MsgOk: Boolean;
    NumThisArea: LongInt;
    Done: Boolean;
    LastLooked: LongInt;
    Num: LongInt;

  Begin
  FillChar(R, SizeOf(R), 0);
  For N := 1 To OffAreas Do
    R.NewLR[N] := -1;
  CName := Upper(User.GetUserName);
  CHdl := Upper(User.GetUserHandle);
  If Length(CHdl) = 0 Then
    CHdl := #8#255#0#13#65;                {a name nobody has}
  User.GetUserSec(Sec);
  Done := False;
  N := 0;
  While (Not Done) And P.Sel(N + 1, Area, Mode) Do
    Begin
    Inc(N);
    If (Area >= 1) And (Area <= OffAreas) And (Area <= Config^.GetMaxMsgAreas) And
       Config^.MsgReadAccess(Area, Sec) Then
      Begin
      SysopAccess := Config^.MsgSysopAccess(Area, Sec);
      NetAccess := (Config^.GetMsgNetStatus(Area) And User.GetUserNetStatus) <> 0;
      If OpenMsgArea(CMsg, Config^.GetMsgAreaId(Area)) Then
        Begin
        Inc(R.NumAreas);
        NumThisArea := 0;
        LastLooked := -1;
        If Assigned(P.Ev) Then
          P.Ev(oeArea, Area, R.NumAreas);
        CMsg^.SeekFirst(CMsg^.GetLastRead(LRNum(Area)) + 1);
        While CMsg^.SeekFound And (Not Done) And (NumThisArea < P.AreaMax) Do
          Begin
          CMsg^.MsgStartUp;
          Num := CMsg^.GetMsgNum;
          ToName := Upper(CMsg^.GetTo);
          FromYou := (Upper(CMsg^.GetFrom) = CName) Or (Upper(CMsg^.GetFrom) = CHdl);
          ToYou := (ToName = CName) Or (ToName = CHdl);
          ToAll := ToName = 'ALL';
          LastLooked := Num;
          If (Not CMsg^.IsPriv) Or SysopAccess Or ToYou Or FromYou Or NetAccess Then
            Begin
            Case Mode Of
              omMy: MsgOk := ToYou;
              omAllYour: MsgOk := ToYou Or ToAll;
              Else MsgOk := True;
              End;
            If FromYou And (Not P.OwnMsgs) Then
              MsgOk := False;
            If MsgOk Then
              Begin
              If Not Offline^.AddMsg(CMsg^, Area, ToYou) Then
                Begin
                R.Failed := True;
                Done := True;
                End
              Else
                Begin
                Inc(NumThisArea);
                Inc(R.NumMsgs);
                If Assigned(P.Ev) Then
                  Begin
                  P.Ev(oeAreaMsg, Area, NumThisArea);
                  P.Ev(oePktMsg, Area, R.NumMsgs);
                  End;
                If R.NumMsgs >= P.MaxMsgs Then
                  Done := True;
                End;
              End;
            End;
          If P.CheckUser And (Not Done) Then
            Done := Not User.Ok;
          CMsg^.SeekNext;
          End;
        If LastLooked >= 0 Then
          R.NewLR[Area] := LastLooked;
        If Assigned(P.Ev) Then
          P.Ev(oeAreaEnd, Area, NumThisArea);
        If CloseMsgArea(CMsg) Then;
        End;
      End;
    End;
  OffExport := Not R.Failed;
  End;


End.
