Unit MKQCfgG;


Interface

Uses MKStr;

Var
  Prompts: StrObj;

Procedure YNAskProc(Var Value; id: Word; Factor: Integer; Var S: String);
Procedure CfgInit;
Procedure CfgDone;
Function NetStatVal(NetStat: String): LongInt;
Function NetStatStr(NetStat: LongInt): String;


Implementation

Uses MKFile;

Procedure CfgInit;
  Begin
  Prompts.Init;
  Prompts.Load(FindPath('Prompts.lc'));
  End;

Procedure CfgDone;
  Begin
  Prompts.Done;
  End;


{$F+}
Procedure YNAskProc(Var Value; id: Word; Factor: Integer; Var S: String);
  Begin
  Case Factor of
    +1: Inc (Byte(Value));
    -1: Dec (Byte(Value));
    End;
  If (Byte(Value) < 0) Then
    Byte(Value) := 4;
  If (Byte(Value) > 250) Then
    Byte(Value) := 4;
  If (Byte(Value) > 4) Then
    Byte(Value) := 0;
  Case Byte(Value) of
    0: s := 'No ';
    1: s := 'Yes';
    2: s := 'New';
    3: s := 'Ask Y';
    4: s := 'Ask N';
    Else
      s := 'NA ';
    End;
  End;


Function NetStatStr(NetStat: LongInt): String;
  Var
    TmpStr: String;
    Tmp: LongInt;
    i: Word;

  Begin
  TmpStr := '';
  Tmp := 1;
  i := 1;
  For i := 1 to 26 Do
    Begin
    If (NetStat and Tmp) <> 0 Then
      Begin
      TmpStr[0] := Chr(Length(TmpStr) + 1);
      TmpStr[Length(TmpStr)] := Chr(i + 64);
      End;
    Tmp := Tmp shl 1;
    End;
  NetStatStr := TmpStr;
  End;


Function NetStatVal(NetStat: String): LongInt;
  Var
    i: Word;
    Tmp: LongInt;
    NS: LongInt;

  Begin
  NS := 0;
  For i := 1 to Length(NetStat) Do
    Begin
    If UpCase(NetStat[i]) in ['A'..'Z'] Then
      Begin
      Tmp := LongInt(1) shl (Ord(UpCase(NetStat[i])) - 65);
      NS := NS or Tmp;
      End;
    End;
  NetStatVal := NS;
  End;


End.
