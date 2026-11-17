Unit MKMenuCf;   {MKMenu: the menu file and its editing screens (Free Vision)}

{$I MKB.Def}

{
     Converted from MKMENUCF (Object Professional).  The menu file is the
     *.MNU file of mk: a header record (the prompt line and the two colours)
     followed by up to 50 items.  Here the screens are Free Vision dialogs:

       EditMenuItem     key, command type (F2 / Space picks it from the list of
                        commands), prompt, data, security, colour and flags
       EditMenuHeader   the menu prompt and its colours
       PickMenuFile     choose one of the *.MNU files
       MenuLoad / MenuSave

     The text of the command list and of the descriptions is in MKMENU.LC
     (strings 1..255 name the commands, 257..511 describe their data, 550 and
     up hold the groups of the command list).
}

Interface

Uses MKStr, MKGlobT, MKRCfgMK, MKCfgNew;

Const
  MaxMenuItems = 50;

Type
  MenuArray = Array[0..MaxMenuItems] Of MenuType;

Var
  BBSPath: String;
  MenuPath: String;
  CurrFile: String;
  Prompts: StrObj;
  MA: MenuArray;                       {0 = the header, 1..50 = the items}
  NumItems: Word;
  Modified: Boolean;

Procedure InitMenuEditor;              {BBS configuration and MKMENU.LC; halts when there is none}
Procedure DoneMenuEditor;
Function  MenuLoad(FN: String): Boolean;
Function  MenuSave(FN: String): Boolean;
Function  IsWild(St: String): Boolean;
Function  ItemStr(Item: Word): String; {One line of the list, Item 1..50}
Procedure EditMenuItem(Item: Word);
Procedure EditMenuHeader;
Function  PickMenuFile(Mask: String; Var Chosen: String): Boolean;
Function  AskFileName(Prompt: String; Var S: String): Boolean;
Function  MenuDir(S: String): String;  {Directory part with the closing slash}
Function  HasExt(S: String): Boolean;  {The file name has an extension}


Implementation

Uses Dos, Objects, MKString, MKFile, MKCfgAbs, MKRCfgRA, MKCfgQB, MKCfgSB,
  CfgForm, CfgColor, CfgBox, CfgList;


{------------------------------------------------------------ start up}

Procedure InitMenuEditor;
  Var
    BbsType: Word;
    TmpStr: String;

  Begin
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
    WriteLn(StdErr, 'Fatal Error: Environment variable not found (MK, RA, QUICK or SBBS)');
    Halt(42);
    End;
  Config^.Load;
  If Config^.GetError <> 0 Then
    Begin
    WriteLn(StdErr, 'Unable to Load BBS Config Info');
    Halt(41);
    End;
  BBSPath := Config^.GetBBSPath;
  MenuPath := Config^.GetMnuPath(1);
  TmpStr := Config^.FindBbsFile('mkmenu.lc') + 'mkmenu.lc';
  Dispose(Config, Done);
  Config := Nil;
  Prompts.Init;
  Prompts.Load(TmpStr);
  End;


Procedure DoneMenuEditor;
  Begin
  Prompts.Done;
  End;


{------------------------------------------------------------ the file}

Function IsWild(St: String): Boolean;
  Begin
  IsWild := ((Pos('?', St) > 0) Or (Pos('*', St) > 0));
  End;


Function MenuDir(S: String): String;
  Var
    D: DirStr;
    N: NameStr;
    E: ExtStr;

  Begin
  FSplit(S, D, N, E);
  MenuDir := D;
  End;


Function HasExt(S: String): Boolean;
  Var
    D: DirStr;
    N: NameStr;
    E: ExtStr;

  Begin
  FSplit(S, D, N, E);
  HasExt := (E <> '');
  End;


Function MenuLoad(FN: String): Boolean;
  {False when the file could not be read (the menu is then empty)}
  Var
    F: File;
    Error: Word;

  Begin
  Error := 0;
  FillChar(MA, SizeOf(MA), 0);
  NumItems := 0;
  If FileExist(FN) Then
    Begin
    If Not shAssign(F, FN) Then
      Error := 1011;
    If Error = 0 Then
      If Not shReset(F, SizeOf(MenuType)) Then
        Error := 1010;
    If Error = 0 Then
      Begin
      If Not shRead(F, MA, MaxMenuItems + 1, NumItems) Then
        Error := 1020;
      Close(F);
      End;
    End
  Else
    Error := 1;
  If IoResult <> 0 Then;
  If Error = 0 Then
    Begin
    If NumItems > 0 Then
      Dec(NumItems);
    End
  Else
    NumItems := 0;
  Modified := False;
  MenuLoad := (Error = 0);
  End;


Function MenuSave(FN: String): Boolean;
  Var
    LastItem: Word;

  Begin
  LastItem := MaxMenuItems;
  While ((LastItem > 0) And (MA[LastItem].Typ = 0)) Do
    Dec(LastItem);
  If EraseFile(FN) Then;
  If SaveFile(FN, MA, (LastItem + 1) * SizeOf(MenuType)) = 0 Then
    Begin
    Modified := False;
    MenuSave := True;
    End
  Else
    MenuSave := False;
  End;


Function AskFileName(Prompt: String; Var S: String): Boolean;
  Begin
  AskFileName := InputLine('MKMenu', Prompt, 79, S);
  End;


{------------------------------------------------------------ the list line}

Function ItemStr(Item: Word): String;
  Var
    S: String;

  Begin
  If (Item < 1) Or (Item > MaxMenuItems) Then
    Begin
    ItemStr := '';
    Exit;
    End;
  If MA[Item].Typ <> 0 Then
    Begin
    If MA[Item].Key = #1 Then
      S := ' ^A '
    Else If MA[Item].Key < ' ' Then
      S := '  ? '
    Else
      S := ' ' + MA[Item].Key + '  ';
    S := S + #179 + ' ' + Copy(PadRight(Prompts.GetString(MA[Item].Typ), ' ', 35), 1, 35) + ' ' + #179 + ' ';
    S := S + Copy(MA[Item].Data, 1, 20);
    End
  Else
    S := '    ' + #179 + ' ' + PadRight('', ' ', 35) + ' ' + #179;
  ItemStr := S;
  End;


{------------------------------------------------------------ the command list}

Var
  NumGroups: Word;
  GroupNo: Word;


Procedure CountGroups;
  Var
    j: Word;

  Begin
  j := 550;
  While Length(Prompts.GetString(j)) > 0 Do
    Inc(j);
  NumGroups := (j - 550) Div 2;
  End;


Function GroupStr(Item: Word): String;
  Begin
  GroupStr := ' ' + Copy(Prompts.GetString(550 + (Item - 1) * 2), 1, 30);
  End;


Function CmdStr(Item: Word): String;
  Var
    SubStr: String;
    Num: Word;

  Begin
  SubStr := Prompts.GetString(551 + (GroupNo - 1) * 2);
  Num := Str2Long(ExtractWord(SubStr, Item));
  CmdStr := ' ' + PadLeft(Long2Str(Num), ' ', 3) + '  ' + Copy(Prompts.GetString(Num), 1, 30);
  End;


Function PickCommand(Var Typ: Byte): Boolean;
  {Two lists as before: the group of commands, then the command}
  Var
    G, C, i, k, G0: Word;
    SubStr: String;
    Num: Word;
    Done: Boolean;

  Begin
  PickCommand := False;
  CountGroups;
  If NumGroups = 0 Then
    Begin
    MsgBox('MKMENU.LC has no list of commands');
    Exit;
    End;
  G := 1;
  C := 1;
  For i := 1 To NumGroups Do             {start on the group and command of the current type}
    Begin
    SubStr := Prompts.GetString(551 + (i - 1) * 2);
    For k := 1 To WordCount(SubStr) Do
      Begin
      Num := Str2Long(ExtractWord(SubStr, k));
      If (Num = Typ) And (Typ > 0) Then
        Begin
        G := i;
        C := k;
        End;
      End;
    End;
  G0 := G;
  Done := False;
  While Not Done Do
    Begin
    If Not RunPick('Command Groups', NumGroups, 34, GroupStr, G) Then
      Exit;
    If G <> G0 Then
      Begin
      C := 1;                          {another group: the list starts at the top}
      G0 := G;
      End;
    GroupNo := G;
    SubStr := Prompts.GetString(551 + (G - 1) * 2);
    k := WordCount(SubStr);
    If C > k Then
      C := 1;
    If RunPick(StripBoth(GroupStr(G), ' '), k, 40, CmdStr, C) Then
      Begin
      Typ := Str2Long(ExtractWord(SubStr, C));
      PickCommand := True;
      Done := True;
      End;
    End;
  End;


{------------------------------------------------------------ one item}

Type
  EntryRec = Record
    KeyCh: Char;
    Auto: Boolean;
    Typ: Byte;
    TypeDesc: String[40];
    Prompt: String[75];
    Data: String[80];
    DataDesc: String[60];
    Security: Word;
    Color: Byte;
    FlagsA, FlagsB, FlagsC, FlagsD: String[8];
    End;

  ByteArray = Array[1..4] Of Byte;

Var
  ER: EntryRec;


Procedure RefreshDesc;
  Begin
  If ER.Typ > 0 Then
    Begin
    ER.TypeDesc := Prompts.GetString(ER.Typ);
    ER.DataDesc := Prompts.GetString(ER.Typ + 256);
    End
  Else
    Begin
    ER.TypeDesc := '';
    ER.DataDesc := '';
    End;
  End;


Procedure TypLeave(Data: Pointer; Title: String);
  Begin
  RefreshDesc;
  End;


Procedure PickCmd(Data: Pointer; Title: String);
  Begin
  If PickCommand(ER.Typ) Then
    RefreshDesc;
  End;


Procedure EditMenuItem(Item: Word);
  Var
    F: CfgFormObj;
    Tmp: LongInt;
    NewKey: Char;
    OldColor: Byte;

  Begin
  If (Item < 1) Or (Item > MaxMenuItems) Then
    Exit;
  FillChar(ER, SizeOf(ER), 0);
  If MA[Item].Key = #1 Then
    Begin
    ER.Auto := True;
    ER.KeyCh := ' ';
    End
  Else
    ER.KeyCh := MA[Item].Key;
  ER.Typ := MA[Item].Typ;
  RefreshDesc;
  ER.Prompt := MA[Item].Prompt;
  ER.Data := MA[Item].Data;
  ER.Security := MA[Item].Security;
  ER.FlagsA := Flag2Str(ByteArray(MA[Item].Flags)[1]);
  ER.FlagsB := Flag2Str(ByteArray(MA[Item].Flags)[2]);
  ER.FlagsC := Flag2Str(ByteArray(MA[Item].Flags)[3]);
  ER.FlagsD := Flag2Str(ByteArray(MA[Item].Flags)[4]);
  OldColor := MA[Item].FgColor Or (MA[Item].BgColor Shl 4);
  ER.Color := OldColor;
  F.Init('Menu Item ' + Long2Str(Item));
  F.Window(3, 5, 76, 17);
  F.At(2, 4, 2, 9);
  F.AddChar('Key:', ER.KeyCh, 'Key letter for this item (blank = none)');
  F.At(2, 15, 2, 21);
  F.AddNumber('Type:', ER.Typ, 1, 0, 255, 'Command type');
  F.OnF2(PickCmd, @ER.Typ, '[ Command ]');
  F.OnLeave(TypLeave, Nil);
  F.At(2, 30, 2, 30);
  F.ReadOnly;
  F.Show(40);
  F.AddString('', ER.TypeDesc, 40, 'The command');
  F.At(4, 4, 4, 12);
  F.Show(60);
  F.AddString('Prompt:', ER.Prompt, 75, 'Text of this item in the menu');
  F.At(6, 4, 6, 10);
  F.Show(60);
  F.AddString('Data:', ER.Data, 80, 'Data for the command');
  F.At(7, 10, 7, 10);
  F.ReadOnly;
  F.Show(60);
  F.AddString('', ER.DataDesc, 60, 'What the data of this command is');
  F.At(9, 4, 9, 14);
  F.AddNumber('Security:', ER.Security, 2, 0, 65535, 'Security level for this item');
  F.At(9, 25, 9, 32);
  F.AddHex('Color:', ER.Color, 1, 'Color of the prompt (F2 picks it)');
  F.OnF2(PickColor, @ER.Color, '[ Prompt Color ]');
  F.At(9, 42, 9, 56);
  F.AddYesNo('Auto execute:', ER.Auto, 'Run this item when the menu is shown');
  F.At(11, 4, 11, 7);
  F.Filter('Xx-');
  F.AddString('A:', ER.FlagsA, 8, 'Flags A: X = needed, - = not');
  F.At(11, 20, 11, 23);
  F.Filter('Xx-');
  F.AddString('B:', ER.FlagsB, 8, 'Flags B: X = needed, - = not');
  F.At(11, 36, 11, 39);
  F.Filter('Xx-');
  F.AddString('C:', ER.FlagsC, 8, 'Flags C: X = needed, - = not');
  F.At(11, 53, 11, 56);
  F.Filter('Xx-');
  F.AddString('D:', ER.FlagsD, 8, 'Flags D: X = needed, - = not');
  If Not F.Execute Then
    Exit;
  If ER.Color <> OldColor Then
    Begin
    Modified := True;
    MA[Item].FgColor := ER.Color And $F;
    MA[Item].BgColor := (ER.Color Shr 4) And $F;
    End;
  If ER.Auto Then
    NewKey := #1
  Else If ER.KeyCh = #0 Then
    NewKey := ' '
  Else
    NewKey := UpCase(ER.KeyCh);
  If MA[Item].Key <> NewKey Then
    Begin
    Modified := True;
    MA[Item].Key := NewKey;
    End;
  If MA[Item].Typ <> ER.Typ Then
    Begin
    Modified := True;
    MA[Item].Typ := ER.Typ;
    End;
  If MA[Item].Prompt <> ER.Prompt Then
    Begin
    Modified := True;
    MA[Item].Prompt := ER.Prompt;
    End;
  If MA[Item].Data <> ER.Data Then
    Begin
    Modified := True;
    MA[Item].Data := ER.Data;
    End;
  If MA[Item].Security <> ER.Security Then
    Begin
    Modified := True;
    MA[Item].Security := ER.Security;
    End;
  ByteArray(Tmp)[1] := Str2Flag(ER.FlagsA);
  ByteArray(Tmp)[2] := Str2Flag(ER.FlagsB);
  ByteArray(Tmp)[3] := Str2Flag(ER.FlagsC);
  ByteArray(Tmp)[4] := Str2Flag(ER.FlagsD);
  If Tmp <> MA[Item].Flags Then
    Begin
    Modified := True;
    MA[Item].Flags := Tmp;
    End;
  End;


{------------------------------------------------------------ the menu prompt}

Type
  HeaderRec = Record
    Prompt: String[75];
    PColor: Byte;
    HColor: Byte;
    End;

Var
  HR: HeaderRec;


Procedure EditMenuHeader;
  {The header record keeps the prompt colour as foreground / background and
   the highlight colour split in the Typ and Security fields}
  Var
    F: CfgFormObj;
    OldP, OldH: Byte;

  Begin
  HR.Prompt := MA[0].Prompt;
  OldP := MA[0].FgColor Or (MA[0].BgColor Shl 4);
  OldH := (MA[0].Typ And $F) Or ((MA[0].Security And $F) Shl 4);
  HR.PColor := OldP;
  HR.HColor := OldH;
  F.Init('Menu Prompt Settings');
  F.Window(5, 5, 75, 9);
  F.At(2, 3, 2, 11);
  F.Show(55);
  F.AddString('Prompt:', HR.Prompt, 75, 'The prompt shown below the menu');
  F.At(4, 3, 4, 17);
  F.AddHex('Prompt Color:', HR.PColor, 1, 'Color of the prompt (F2 picks it)');
  F.OnF2(PickColor, @HR.PColor, '[ Prompt Color ]');
  F.At(4, 34, 4, 51);
  F.AddHex('Highlight Color:', HR.HColor, 1, 'Color of the key letters (F2 picks it)');
  F.OnF2(PickColor, @HR.HColor, '[ Highlight Color ]');
  If Not F.Execute Then
    Exit;
  If MA[0].Prompt <> HR.Prompt Then
    Begin
    Modified := True;
    MA[0].Prompt := HR.Prompt;
    End;
  If HR.PColor <> OldP Then
    Begin
    Modified := True;
    MA[0].FgColor := HR.PColor And $F;
    MA[0].BgColor := (HR.PColor Shr 4) And $F;
    End;
  If HR.HColor <> OldH Then
    Begin
    Modified := True;
    MA[0].Typ := HR.HColor And $F;
    MA[0].Security := (HR.HColor Shr 4) And $F;
    End;
  End;


{------------------------------------------------------------ the file list}

Var
  Files: Array[1..500] Of String[60];
  NFiles: Word;


Function FileStr(Item: Word): String;
  Begin
  FileStr := ' ' + Files[Item];
  End;


Function MatchMask(N, P: String): Boolean;
  {* and ? like DOS, not case sensitive}
  Begin
  If P = '' Then
    MatchMask := (N = '')
  Else If P[1] = '*' Then
    Begin
    If MatchMask(N, Copy(P, 2, 255)) Then
      MatchMask := True
    Else If N = '' Then
      MatchMask := False
    Else
      MatchMask := MatchMask(Copy(N, 2, 255), P);
    End
  Else If N = '' Then
    MatchMask := False
  Else If (P[1] = '?') Or (UpCase(P[1]) = UpCase(N[1])) Then
    MatchMask := MatchMask(Copy(N, 2, 255), Copy(P, 2, 255))
  Else
    MatchMask := False;
  End;


Function PickMenuFile(Mask: String; Var Chosen: String): Boolean;
  Var
    D: DirStr;
    N: NameStr;
    E: ExtStr;
    SR: SearchRec;
    i, j: Word;
    T: String[60];
    Idx: Word;

  Begin
  PickMenuFile := False;
  Chosen := '';
  FSplit(Mask, D, N, E);
  NFiles := 0;
  FindFirst(D + '*', AnyFile, SR);
  While DosError = 0 Do
    Begin
    If ((SR.Attr And Directory) = 0) And MatchMask(SR.Name, N + E) And (NFiles < 500) Then
      Begin
      Inc(NFiles);
      Files[NFiles] := SR.Name;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  If NFiles = 0 Then
    Begin
    MsgBox('No files found: ' + D + N + E);
    Exit;
    End;
  For i := 2 To NFiles Do                {sorted, not case sensitive}
    Begin
    T := Files[i];
    j := i;
    While (j > 1) And (Upper(Files[j - 1]) > Upper(T)) Do
      Begin
      Files[j] := Files[j - 1];
      Dec(j);
      End;
    Files[j] := T;
    End;
  Idx := 1;
  If RunPick('Menu Files', NFiles, 36, FileStr, Idx) Then
    Begin
    Chosen := D + Files[Idx];
    PickMenuFile := True;
    End;
  End;


End.
