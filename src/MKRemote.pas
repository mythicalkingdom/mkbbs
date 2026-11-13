Unit MKRemote;   {Sysop snoop over a network - disabled in the FPC version}

{$I MKB.Def}

{
     The DOS version watched a node's screen and typed into it over NetBIOS
     (INT 5Ch), triggered by a "MKSnoop.nnn" semaphore file.  NetBIOS does not
     exist on the new platforms, so for now the snoop never connects:
     NetDetected is False, KeyPressed is always False and nothing is sent.

     The RemoteCheck object keeps its old interface so MKDoor and the other
     units do not change.  A TCP based snoop can be built later by filling in
     CheckFiles / GetNetXferStr / SendChar / SendStr (the screen to send is
     the MKVCrt buffer).
}

Interface


Type CheckInfo = Record
  NodeStr: String[3];
  CurrentState: Word;
  CheckDelay: LongInt;
  NextCheck: LongInt;
  CheckPath: String;
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
  Function  ReadKey: Char; {Return key if avail otherwise #254}
  Function  SendChar(Ch:Char): Boolean;
  Procedure SendStr(Str:String);
  End;


Type RemoteCheckPtr = ^RemoteCheck;

Const
  NetDetected: Boolean = False;

Implementation

Uses MKString, MKDos;


Const
  rsWait = 0;
  rsInUse = 1;


Procedure RemoteCheck.Init;
  Begin
  New(CI);
  FillChar(CI^, SizeOf(CI^), 0);
  CI^.CheckDelay := 80;
  CI^.CurrentState := rsWait;
  ResetNextCheck;
  End;


Procedure RemoteCheck.Done;
  Begin
  Dispose(CI);
  End;


Procedure RemoteCheck.SetNode(Num: Word);
  Begin
  CI^.NodeStr := PadLeft(Long2Str(Num),'0',3);
  End;


Procedure RemoteCheck.SetCheckPath(Str: String);
  Begin
  CI^.CheckPath := Str;
  AddBackSlash(CI^.CheckPath);
  End;


Procedure RemoteCheck.SetCheckDelay(DTime: LongInt);
  Begin
  CI^.CheckDelay := DTime;
  End;


Procedure RemoteCheck.ResetNextCheck;
  Begin
  CI^.NextCheck := TimeCounter + CI^.CheckDelay;
  End;


Procedure RemoteCheck.CheckFiles;
  Begin
  ResetNextCheck;
  End;


Procedure RemoteCheck.GetNetXferStr;
  Begin
  CI^.NetXferStr := '';
  CI^.CharCtr := 1;
  End;


Function RemoteCheck.CheckKey: Boolean;
  Begin
  CheckKey := False;
  End;


Function RemoteCheck.KeyPressed: Boolean;
  Begin
  If TimeOut(CI^.NextCheck) Then
    CheckFiles;
  KeyPressed := False;
  End;


Function RemoteCheck.ReadKey: Char;
  Begin
  ReadKey := #254;
  End;


Function RemoteCheck.SendChar(Ch:Char): Boolean;
  Begin
  SendChar := False;
  End;


Procedure RemoteCheck.SendStr(Str:String);
  Begin
  End;


End.
