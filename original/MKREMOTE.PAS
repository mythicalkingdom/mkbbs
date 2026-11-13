Unit MKRemote;
{$I MKB.Def}

Interface

Uses MKNetB;

Type CheckInfo = Record
  NodeStr: String[3];
  CurrentState: Word;
  CheckDelay: LongInt;
  NextCheck: LongInt;
  CheckPath: String;
  LSN: Byte;
  NCB: NCBType;
  SendNCB: NCBType;
  SendNum: Byte;
  NetXferStr: String;
  CharCtr: Word;
  ShowOut: Boolean;
  CheckIn: Boolean;
  OutBuffer: String;
  SendingStr: String;
  End;


Type RemoteCheck = Object
  CI: ^CheckInfo;
  Procedure Init; {Initialize}
  Procedure Done; {Clean up/Deallocate}
  Procedure SetNode(Num: Word); {Set file extension for node number}
  Procedure SetCheckPath(Str: String); {Set semaphore check path wildcards}
  Procedure ResetNextCheck;
  Procedure SetCheckDelay(DTime: LongInt); {Set delay in timer ticks!}
  Procedure CheckFiles;
  Procedure GetNetXferStr;
  Function  CheckKey: Boolean; {Internal}
  Function  KeyPressed: Boolean; {Is remote key available}
  Function  ReadKey: Char; {Return key if avail otherwise #255}
  Function  SendChar(Ch:Char): Boolean;
  Procedure SendStr(Str:String);
  End;


Type RemoteCheckPtr = ^RemoteCheck;

Const
  NetDetected: Boolean = False;

Implementation

Uses MKFile, MKString, MKDos,
  {$IFDEF WINDOWS}
  MKWCrt, WinDos;
  {$ELSE}
  {$IFDEF OPRO}
    OpCrt,
  {$ELSE}
    Crt,
  {$ENDIF}
  Dos;
  {$ENDIF}


Const
  rsWait = 0;
  rsInUse = 1;


Procedure RemoteCheck.Init;
  Begin
  New(CI);
  CI^.CheckDelay := 80;
  CI^.CurrentState := rsWait;
  CI^.CheckPath := '';
  CI^.ShowOut := False;
  CI^.CheckIn := False;
  CI^.OutBuffer := '';
  CI^.SendingStr := '';
  InitializeNCB(CI^.SendNCB);
  InitializeNCB(CI^.NCB);
  ResetNextCheck;
  End;


Procedure RemoteCheck.SetNode(Num: Word); {Set file extension for node number}
  Begin
  CI^.NodeStr := PadLeft(Long2Str(Num),'0',3);
  End;


Procedure RemoteCheck.SetCheckPath(Str: String);
  Begin
  CI^.CheckPath := Str;
  AddBackSlash(CI^.CheckPath);
  End;


Procedure RemoteCheck.SetCheckDelay(DTime: LongInt); {Set delay in timer ticks!}
  Begin
  CI^.CheckDelay := DTime;
  End;


Procedure RemoteCheck.Done;
  Begin
  Dispose(CI);
  End;


Procedure RemoteCheck.ResetNextCheck;
  Begin
  CI^.NextCheck := TimeCounter + CI^.CheckDelay;
  End;


Procedure RemoteCheck.CheckFiles;
  Var
    Error: Word;
    Tmp: Word;
    Counter: Word;

  Begin
  If FileExist(CI^.CheckPath + 'MKSnoop.' + CI^.NodeStr) Then
    Begin
    If ((CI^.CurrentState <> rsInUse) and (NetDetected)) Then
      Begin
      Error := NBAddName('MKSNOOP.' + CI^.NodeStr, CI^.SendNum);
      If Error = $0d Then
        Error := 0;
      If Error = 0 Then
        Begin
        Tmp := 1;
        Counter := 0;
        While ((Tmp <> 0) And (Counter < 2)) Do
          Begin
          Tmp := NBCall('MKNETMGR', 'MKSNOOP.' + CI^.NodeStr, CI^.NCB);
          Inc(Counter);
          End;
        CI^.LSN := CI^.NCB.Lsn;
        Error := Tmp;
        End;
      CI^.NetXferStr := '';
      If Error = 0 Then
        CI^.CurrentState := rsInUse
      Else
        Begin
        Error := NBDeleteName('MKSNOOP.' + CI^.NodeStr);
        CI^.CurrentState := rsWait;
        End;
      End;
    End
  Else
    Begin
    If CI^.CurrentState = rsInUse Then
      Begin
      If NBHangUp(CI^.LSN) <> 0 Then;
      If NBDeleteName('MKNSNOOP.' + CI^.NodeStr) <> 0 Then;
      CI^.CurrentState := rsWait;
      End;
    End;
  ResetNextCheck;
  End;


Procedure RemoteCheck.GetNetXferStr;
  Var
    Tmp: Word;

  Begin
  If CI^.NCB.CompleteCode <> $ff Then
    Begin
    CI^.NetXferStr := '';
    CI^.CharCtr := 1;
    Tmp := NBRecvStringNW(CI^.NCB, CI^.LSN, CI^.NetXferStr);
    If ((CI^.NetXferStr = #255) or (Tmp = 8)) Then
      Begin
      If NBHangUp(CI^.LSN) <> 0 Then;
      If NBDeleteName('MKSNOOP.' + CI^.NodeStr) <> 0 Then;
      CI^.CurrentState := rsWait;
      End;
    End;
  End;


Function RemoteCheck.CheckKey: Boolean;
  Var
    Str: String;

  Begin
  If ((CI^.CurrentState = rsInUse) And (CI^.CheckIn)) Then
    Begin
    If CI^.CharCtr <= Length(CI^.NetXferStr) Then
      CheckKey := True
    Else
      Begin
      GetNetXferStr;
      CheckKey := CI^.CharCtr <= Length(CI^.NetXferStr);
      End;
    If ((CI^.SendNCB.CompleteCode <> $ff) and (Length(CI^.OutBuffer) > 0)) Then
      Begin
      CI^.SendingStr := CI^.OutBuffer;
      CI^.OutBuffer := '';
      If (NBSendStringNW(CI^.SendNCB, CI^.LSN, CI^.SendingStr) = 8) Then
        Begin
        If NBHangUp(CI^.LSN) <> 0 Then;
        If NBDeleteName('MKSNOOP.' + CI^.NodeStr) <> 0 Then;
        CI^.CurrentState := rsWait;
        End;
      End;
    End
  Else
    CheckKey := False;
  End;


Function RemoteCheck.SendChar(Ch:Char):Boolean;
  Begin
  SendChar := False;
  If ((CI^.ShowOut) and (CI^.CurrentState = rsInUse)) Then
    Begin
    If Length(CI^.OutBuffer) < 255 Then
      Begin
      SendChar := True;
      Inc(CI^.OutBuffer[0]);
      CI^.OutBuffer[Length(CI^.OutBuffer)] := Ch;
{      CI^.OutBuffer := CI^.OutBuffer + Ch;   }
      If CI^.SendNCB.CompleteCode <> $ff Then
        Begin
        CI^.SendingStr := CI^.OutBuffer;
        CI^.OutBuffer := '';
        If(NBSendStringNW(CI^.SendNCB, CI^.LSN, CI^.SendingStr) = 0) Then;
        End;
      End
    Else
      Begin
      While CI^.SendNCB.CompleteCode = $ff Do;
      CI^.SendingStr := CI^.OutBuffer;
      CI^.OutBuffer := ch;
      If(NBSendStringNW(CI^.SendNCB, CI^.LSN, CI^.SendingStr) = 0) Then;
      End;
    End;
  End;


Procedure RemoteCheck.SendStr(Str:String);
  Begin
  If ((CI^.ShowOut) and (CI^.CurrentState = rsInUse)) Then
    Begin
    If ((Length(CI^.OutBuffer) + Length(Str)) < 255) Then
      Begin
      CI^.OutBuffer := CI^.OutBuffer + Str;
      If CI^.SendNCB.CompleteCode <> $ff Then
        Begin
        CI^.SendingStr := CI^.OutBuffer;
        CI^.OutBuffer := '';
        If (NBSendStringNW(CI^.SendNCB, CI^.LSN, CI^.SendingStr) = 0) Then;
        End;
      End
    Else
      Begin
      While CI^.SendNCB.CompleteCode = $ff Do;
      CI^.SendingStr := CI^.OutBuffer;
      CI^.OutBuffer := Str;
      If(NBSendStringNW(CI^.SendNCB, CI^.LSN, CI^.SendingStr) = 0) Then;
      End;
    End;
  End;


Function RemoteCheck.ReadKey: Char;
  Begin
  If CheckKey Then
    Begin
    ReadKey := CI^.NetXferStr[CI^.CharCtr];
    Inc(CI^.CharCtr);
    End
  Else
    ReadKey := #254;
  End;


Function RemoteCheck.KeyPressed: Boolean;
  Begin
  If TimeOut(CI^.NextCheck) Then
    Begin
    CheckFiles;
    ResetNextCheck;
    End;
  Case CI^.CurrentState of
    rsWait:
      Begin
      KeyPressed := False;
      End;
    rsInUse:
      Begin
      If CI^.CheckIn Then
        KeyPressed := CheckKey
      Else
        KeyPressed := False;
      End;
    End;
  End;


Begin
NetDetected := LanInstalled;
End.
