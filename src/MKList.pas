Program MKList;

{$I MKB.Def}

{
     mklist OutPut.Txt

     Writes the message areas of the BBS (MK, RA, QUICK or SBBS names the config
     directory, as for mk) to a text file, three lines per area: the area id,
     the short name and the name (first 70 characters).  Areas without a name
     are left out.
}

Uses
  MKGlobT, MKFile, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKString;


Var
  BbsType: Word;
  i: Word;
  OutFile: Text;


Procedure UtiWrite(Str: String);
  Begin
  WriteLn(OutFile, Str);
  If IoResult <> 0 Then
    Begin
    WriteLn(StdErr, 'Error writing to output file');
    Halt(2);
    End;
  End;


Begin
If ParamCount < 1 Then
  Begin
  WriteLn('Correct syntax is: MKList OutPut.Txt');
  Halt(1);
  End;
BbsType := DetectBbsType;
Config := Nil;
Case BbsType Of
  1: Config := NewMKConfig(True);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory');
  Halt(1);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, Long2Str(Config^.GetError) + ': Error loading config files');
  Halt(1);
  End;
Assign(OutFile, ParamStr(1));
{$I-}
ReWrite(OutFile);
{$I+}
If IoResult <> 0 Then
  Begin
  WriteLn(StdErr, 'Unable to create output file');
  Halt(2);
  End;
For i := 1 To 500 Do
  Begin
  If (Length(Config^.GetMsgName(i)) > 0) Then
    Begin
    UtiWrite(Config^.GetMsgAreaId(i));
    UtiWrite(Config^.GetMsgShortName(i));
    UtiWrite(Copy(Config^.GetMsgName(i), 1, 70));
    End;
  End;
Close(OutFile);
If IoResult <> 0 Then;
Dispose(Config, Done);
End.
