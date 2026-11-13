Unit CfgOrig;   {Origin lines, converted from CFGORIG}

{$I MKB.Def}

Interface

Procedure DoCfgOrig;

Implementation

Uses MKString, MKCfgAbs, CfgList, CfgForm;

Type
  UserRecord = Array[1..20] Of String[55];

Var
  UR: ^UserRecord;


Function ItemStr(Item: Word): String;
  Begin
  ItemStr := PadLeft(Long2Str(Item), ' ', 2) + ': ' + UR^[Item];
  End;


Procedure EditLine(Item: Word);
  Var
    F: CfgFormObj;

  Begin
  F.Init('Origin Line ' + Long2Str(Item));
  F.AddString('Text:', UR^[Item], 55, 'Origin line text (up to 55 characters)');
  If F.Execute Then;
  End;


Procedure DoCfgOrig;
  Var
    i: Word;

  Begin
  New(UR);
  For i := 1 To 20 Do
    UR^[i] := Config^.GetOrigStr(i);
  RunList('Origin Lines', 20, 62, ItemStr, EditLine);
  For i := 1 To 20 Do
    Config^.SetOrigStr(i, UR^[i]);
  Dispose(UR);
  End;


End.
