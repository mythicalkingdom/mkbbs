{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKReadO;   {MKRead command line (-C<config file>, -T<M|R|Q|S|E> BBS type)}

{$I MKB.Def}

Interface

Var
  UseEMS: Boolean;                     {Not used any more}
  CfgName: String;
  BBSType: Word;
  StartArea: Word;                     {-A<n>: open this area at once instead of asking}

Implementation

Uses SysUtils;

Procedure ProcCmdLine;
  Var
    Status: Word;
    TempStr: String;

  Begin
  Status := 1;
  While Status <= ParamCount Do
    Begin
    TempStr := ParamStr(Status);
    If (Length(TempStr) > 1) And ((TempStr[1] = '-') or (TempStr[1] = '/')) Then
      Begin
      Case UpCase(TempStr[2]) of
        'C': CfgName := Copy(TempStr, 3, 128);
        'A': StartArea := Word(StrToIntDef(Copy(TempStr, 3, 5), 0));
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
StartArea := 0;
UseEms := True;
CfgName := '';
ProcCmdLine;
End.
