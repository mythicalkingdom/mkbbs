
Program MKCfgCvt;

Uses Default, CCvt, MKCfgAbs, MKCfgMK, MKCfgRA, MKCfgQb, MKCfgSb, MKGlobT, MKString;


Var
  InRec: ^CfgObj;
  OutRec: ^CfgObj;
  ParamError: Word;
  Code: Word;
  InType: Word;
  OutType: Word;

Begin
If ParamCount <> 2 Then
  ParamError := 1
Else
  ParamError := 0;
If ParamError = 0 Then
  Begin
  Val(ParamStr(1), InType, Code);
  If Code <> 0 Then
    ParamError := 4;
  Val(ParamStr(2), OutType, Code);
  If Code <> 0 Then
    ParamError := 4;
  If ((OutType < 1) or (OutType > 4) or (InType < 1) or (InType > 4)) Then
    ParamError := 5;
  End;
If ParamError <> 0 Then
  Begin
  WriteLn;
  WriteLn('ERROR: Invalid Command Line');
  WriteLn;
  WriteLn('Proper Syntax is:');
  WriteLn('MKCfgCvt InputType OutputType');
  WriteLn;
  WriteLn('Where InputType and OutputType are');
  WriteLn;
  WriteLn('      1 = Mythical Kingdom');
  WriteLn('      2 = Remote Access');
  WriteLn('      3 = QuickBbs');
  WriteLn('      4 = SuperBbs');
  WriteLn;
  Halt(3);
  End;
Case InType Of
  1: InRec := New(MKCfgObjPtr, Init);
  2: InRec := New(RACfgObjPtr, Init);
  3: InRec := New(QBCfgObjPtr, Init);
  4: InRec := New(SBCfgObjPtr, Init);
  End;
Case OutType Of
  1: OutRec := New(MKCfgObjPtr, Init);
  2: OutRec := New(RACfgObjPtr, Init);
  3: OutRec := New(QBCfgObjPtr, Init);
  4: OutRec := New(SBCfgObjPtr, Init);
  End;
InRec^.SetBbsType(InType);
OutRec^.SetBbsType(OutType);
WriteLn;
WriteLn('Loading original config');
InRec^.Load;
If InRec^.GetError <> 0 Then
  Begin
  WriteLn('Error: ' + Long2Str(InRec^.GetError) + ' loading config');
  Halt(1);
  End;
OutRec^.Allocate;
WriteLn('Setting Defaults');
SetCfgDefaults(OutRec^);
SetMsgDefaults(OutRec^);
SetEchoDefaults(OutRec^);
SetFileDefaults(OutRec^);
WriteLn('Converting');
CvtCfg(InRec^, OutRec^);
CvtMsg(InRec^, OutRec^);
CvtFile(InRec^, OutRec^);
CvtEcho(InRec^, OutRec^);
WriteLn('Writing new config');
OutRec^.Save;
If OutRec^.GetError <> 0 Then
  Begin
  WriteLn('Error: ' + Long2Str(OutRec^.GetError) + ' saving config');
  Halt(2);
  End;
InRec^.Done;
OutRec^.Done;
WriteLn('Conversion completed');
WriteLn;
End.
