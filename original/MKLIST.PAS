Program MKList;
{$IFDEF WINDOWS}
{$M 16384, 8196}
{$ELSE}
{.$M 16384, 0, 655360}
{$M 20000, 120000, 320000}
{$ENDIF}

{$I MKB.Def}
{$X+}

{$IFDEF WINDOWS}
Uses MKWCrt, WinDos,
{$ELSE}
  Uses Extend,
  {$IFDEF OPRO}
  OpCrt, OpColor,
  {$ELSE}
  Crt,
  {$ENDIF}
{$ENDIF}
MKGlobT, MKFile, MKCfgAbs, MKCfgMK, MKCfgRA, MKCfgQb, MKCfgSb, MKString;


Var
  BbsType: Word;
  i: Word;
  OutFile: Text;
  OutPath: String;
  TmpStr: String;
  TA, TempX, TempY: Byte;


Procedure UtiWrite(Str: String);
  Begin
  WriteLn(OutFile, Str);
  If IoResult <> 0 Then
    Begin
    WriteLn('Error writing to output file');
    Halt(2);
    End;
  End;


Begin
If ParamCount < 1 Then
  Begin
  WriteLn('Correct syntax is: UTILIST OutPut.Txt');
  Halt(1);
  End;
TempX := WhereX;
TempY := WhereY;
TA := TextAttr;
TextAttr := YellowOnBlue;
GoToXy(1,25);
TmpStr := 'UTILIST';
For i := 1 to ParamCount Do
  TmpStr := TmpStr + ' ' + ParamStr(i);
ClrEol;
Write(Copy(TmpStr,1,79));
Delay(300);
OutPath := ParamStr(1);
Assign(OutFile, OutPath);
ReWrite(OutFile);
If IoResult <> 0 Then
  Begin
  WriteLn('Unable to create output file');
  Halt(2);
  End;
BbsType := DetectBbsType;
Case BbsType Of
  1: Config := New(MKCfgObjPtr, Init);
  2: Config := New(RACfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
Config^.Load;
For i := 1 to 500 Do
  Begin
  If (Length(Config^.GetMsgName(i)) > 0) Then
    Begin
    UtiWrite(Config^.GetMsgAreaId(i));
    UtiWrite(Config^.GetMsgShortName(i));
    UtiWrite(Copy(Config^.GetMsgName(i),1, 70));
    End;
  End;
Config^.Done;
Dispose(Config);
Close(OutFile);
If IoResult <> 0 Then;
GoToXY(TempX, TempY);
TextAttr := TA;
End.
