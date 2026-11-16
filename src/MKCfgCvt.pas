Program MKCfgCvt;

{$I MKB.Def}

{
     mkcfgcvt [-y] InputType OutputType

     Converts the BBS configuration from one program's format to another's.
     The types are

        1 = Mythical Kingdom    (directory in the environment variable MK)
        2 = Remote Access       (RA)
        3 = QuickBbs            (QUICK)
        4 = SuperBbs            (SBBS)

     The input configuration is read from the directory its variable names, the
     output is written to the directory of the output type's variable, so both
     have to be set (the output directory has to exist).  The output starts
     from the default settings, then everything the formats have in common is
     copied (CCvt).

     Files of the output type that are already there are overwritten, so
     the program lists them and asks first (answer y); -y answers yes for
     scripts.  Without an answer (end of input) nothing is written.
}

Uses
  Default, CCvt, MKCfgAbs, MKCfgMK, MKCfgRA, MKCfgQB, MKCfgSB, MKGlobT, MKString, MKFile;


Var
  InRec: ^CfgObj;
  OutRec: ^CfgObj;
  ParamError: Word;
  Code: Word;
  InType: Word;
  OutType: Word;
  AssumeYes: Boolean;
  Args: Array[1..2] Of String;
  NumArgs: Word;
  i: Word;
  Names, Existing, TmpStr: String;
  NumExisting: Word;
  Answer: String;

Begin
AssumeYes := False;
NumArgs := 0;
ParamError := 0;
For i := 1 To ParamCount Do
  Begin
  If (ParamStr(i) = '-y') Or (ParamStr(i) = '-Y') Then
    AssumeYes := True
  Else If NumArgs < 2 Then
    Begin
    Inc(NumArgs);
    Args[NumArgs] := ParamStr(i);
    End
  Else
    ParamError := 1;
  End;
If NumArgs <> 2 Then
  ParamError := 1;
If ParamError = 0 Then
  Begin
  Val(Args[1], InType, Code);
  If Code <> 0 Then
    ParamError := 4;
  Val(Args[2], OutType, Code);
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
  WriteLn('MKCfgCvt [-y] InputType OutputType');
  WriteLn;
  WriteLn('Where InputType and OutputType are');
  WriteLn;
  WriteLn('      1 = Mythical Kingdom   (MK)');
  WriteLn('      2 = Remote Access      (RA)');
  WriteLn('      3 = QuickBbs           (QUICK)');
  WriteLn('      4 = SuperBbs           (SBBS)');
  WriteLn;
  WriteLn('The environment variable of each type names its configuration directory.');
  WriteLn('Files of the output type that exist are only overwritten after a yes (-y: always).');
  WriteLn;
  Halt(3);
  End;
InRec := Nil;
OutRec := Nil;
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
{ the files that would be written, and which of them exist already }
Names := OutRec^.SaveFileNames;
Existing := '';
NumExisting := 0;
While Length(Names) > 0 Do
  Begin
  i := Pos('|', Names);
  If i = 0 Then
    i := Length(Names) + 1;
  TmpStr := OutRec^.SaveFileName(Copy(Names, 1, i - 1));
  If FileExist(TmpStr) Then
    Begin
    Existing := Existing + '   ' + TmpStr + #10;
    Inc(NumExisting);
    End;
  Names := Copy(Names, i + 1, 255);
  End;
If (NumExisting > 0) And (Not AssumeYes) Then
  Begin
  WriteLn;
  WriteLn('These files exist and would be overwritten:');
  Write(Existing);
  Write('Overwrite them (y/N)? ');
  Answer := '';
  If Not Eof(Input) Then
    ReadLn(Answer);
  Answer := Upper(StripBoth(Answer, ' '));
  If (Answer <> 'Y') And (Answer <> 'YES') Then
    Begin
    WriteLn;
    WriteLn('Nothing was written.');
    Halt(4);
    End;
  End;
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
