Unit MKReadO;

Interface

Var
  UseEMS: Boolean;
  CfgName: String;
  BBSType: Word;


Implementation

{$IFNDEF DPMI}
Uses Overlay, OvrXms;
{$ENDIF}


Procedure ProcCmdLine;
  Var
    Status: Word;
    TempStr: String;
    Cnt: Word;

  Begin
  Status := 1;
  While Status <= ParamCount Do
    Begin
    TempStr := ParamStr(Status);
    For Cnt := 1 to Length(TempStr) Do
      TempStr[Cnt] := UpCase(TempStr[Cnt]);
    If ((TempStr[1] = '-') or (TempStr[1] = '/')) Then
      Begin
      Case TempStr[2] of
        'C': CfgName := Copy(TempStr,3,128);
        'N': Begin
             If Copy(TempStr,2,5) = 'NOEMS' Then
               UseEms := False;
             End;
        'T': Begin
             Case UpCase(TempStr[3]) of
               'M': BbsType := 1;
               'R': BbsType := 2;
               'Q': BbsType := 3;
               'S': BbsType := 4;
               'E': BbsType := 5;
               End;
             End;
        End;
      End;
    Inc(Status);
    End;
  End;


Begin
BbsType := 0;
UseEms := True;
CfgName := '';
ProcCmdLine;
{$IFNDEF DPMI}
OvrFileMode := 64;
OvrInit('MKREAD.OVR');
If OvrResult <> 0 Then
  Begin
  WriteLn(OvrResult, ' Error loading MKREAD.OVR');
  Halt(1);
  End;
OvrSetBuf(65000);
OvrInitXms;
If OvrResult <> 0 Then
  Begin
  If UseEMS Then
    OvrInitEMS;
  If ((OvrResult < 0) and (OvrResult > -5)) Then
    Begin
    WriteLn(OvrResult, ' Error loading MKREAD.OVR' );
    Halt(1);
    End;
  End;
{$ENDIF}
End.
