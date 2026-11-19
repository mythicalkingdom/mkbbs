Unit MKDrawCf;   {MKDraw: the character sets, the BBS screen codes and the pick lists}

{$I MKB.Def}

{
     Converted from MKDRAWCF (Object Professional pick lists) to Free Vision dialogs (CfgList).

       ExtChars / CurrSet   15 sets of 10 special characters (box drawing, shading, accents ...), the characters
                            are CP437 codes; F1..F10 enter the ones of the current set
       GetBbsStr            pick a BBS screen code (^A, ^F A ... the control codes the BBS expands) to put in the
                            screen; the list is the built-in one or the prompt/code pairs of the file codes.mkd
                            (two lines for each code: the prompt, the code) in the current directory or the
                            MK directory
       GetMenuCmd           the fast menu (Esc): one command of the editor
       GetActionCmd         what a saved screen starts with: nothing, home, clear screen
       GetPickChar          choose the current character set
       GetDrawSet           choose the drawing mode (a line set or normal)
       PickScreenFile       choose one of the files of a mask (not case sensitive)
}

Interface

Const
  {the commands of the editor (also the result of GetMenuCmd)}
  cmNone = 0;
  cmAttrPick = 4101;       {colour / attribute}
  cmBlink = 4102;
  cmIntens = 4103;
  cmUnder = 4104;          {colour under the cursor}
  cmReverse = 4105;
  cmFill = 4106;
  cmCopy = 4107;
  cmMove = 4108;
  cmInsLine = 4109;
  cmDelLine = 4110;
  cmClear = 4111;
  cmBbsCode = 4112;
  cmGetSet = 4113;
  cmEnclose = 4114;
  cmLoad = 4115;
  cmSave = 4116;
  cmHelp = 4117;
  cmExitDraw = 4118;
  cmDrawMode = 4119;
  cmDouble = 4120;
  cmSaveAll = 4121;        {save the whole screen: no area is asked}

  CharsInSet = 10;

Var
  ExtChars: Array[1..15] Of String[12];  {CP437 codes}
  CurrSet: Word;

Procedure LoadExtChars;
Procedure InitCustCodes;
Procedure DoneCustCodes;
Function  GetBbsStr: String;
Function  GetMenuCmd: Word;
Function  GetActionCmd: Word;
Procedure GetPickChar;
Procedure GetDrawSet(Var DSet: Word);
Function  PickScreenFile(Mask: String; Var Chosen: String): Boolean;
Function  MatchMask(N, P: String): Boolean;
Function  CharSetStr(i: Word): String; {The characters of a set for a list, shown as the terminal shows CP437}


Implementation

Uses Dos, MKString, MKFile, CfgBox, CfgList, Objects;


Procedure LoadExtChars;
  {the codes of the original strings (CP437)}
  Const
    Codes: Array[1..15, 1..10] Of Byte = (
      (218, 191, 192, 217, 196, 179, 195, 180, 193, 194),
      (201, 187, 200, 188, 205, 186, 204, 185, 202, 203),
      (213, 184, 212, 190, 205, 179, 198, 181, 207, 209),
      (214, 183, 211, 189, 196, 186, 199, 182, 208, 210),
      (197, 206, 216, 215, 232, 233, 155, 156, 153, 239),
      (176, 177, 178, 219, 223, 220, 221, 222, 254, 250),
      (1, 2, 3, 4, 5, 6, 240, 127, 14, 15),
      (24, 25, 30, 31, 16, 17, 18, 29, 20, 21),
      (174, 175, 242, 243, 169, 170, 253, 246, 171, 172),
      (227, 241, 244, 245, 234, 157, 228, 248, 251, 252),
      (224, 225, 226, 229, 230, 231, 235, 236, 237, 238),
      (128, 135, 165, 164, 152, 159, 247, 249, 173, 168),
      (131, 132, 133, 160, 166, 134, 142, 143, 145, 146),
      (136, 137, 138, 130, 144, 140, 139, 141, 161, 158),
      (147, 148, 149, 162, 167, 150, 129, 151, 163, 154));
  Var
    i, j: Word;

  Begin
  For i := 1 To 15 Do
    Begin
    ExtChars[i] := '';
    For j := 1 To CharsInSet Do
      ExtChars[i] := ExtChars[i] + Chr(Codes[i, j]);
    End;
  CurrSet := 1;
  End;


{------------------------------------------------------------ the BBS codes}

Const
  MaxCust = 100;
  MaxBbsCodes = 64;

Type
  BCodeRec = Record
    Prompt: String[30];
    Code: String[25];
    End;
  CustArray = Array[1..MaxCust] Of BCodeRec;

Var
  CustCodes: ^CustArray;
  NumCust: Word;


Procedure DoneCustCodes;
  Begin
  If CustCodes <> Nil Then
    Dispose(CustCodes);
  CustCodes := Nil;
  End;


Procedure InitCustCodes;
  Var
    TF: TFile;
    TmpStr1, TmpStr2: String;
    FN: String;

  Begin
  If CustCodes = Nil Then
    New(CustCodes);
  NumCust := 0;
  FillChar(CustCodes^, SizeOf(CustCodes^), 0);
  FN := 'codes.mkd';
  If (Not FileExist(FN)) And (GetEnv('MK') <> '') Then
    FN := WithBackSlash(GetEnv('MK')) + 'codes.mkd';
  If FileExist(FN) Then
    Begin
    TF.Init;
    If TF.OpenTextFile(FN) Then
      Begin
      TmpStr1 := TF.GetString;
      TmpStr2 := TF.GetString;
      While (TF.StringFound And (NumCust < MaxCust)) Do
        Begin
        Inc(NumCust);
        CustCodes^[NumCust].Prompt := TmpStr1;
        CustCodes^[NumCust].Code := TmpStr2;
        TmpStr1 := TF.GetString;
        TmpStr2 := TF.GetString;
        End;
      If TF.CloseTextFile Then;
      End;
    TF.Done;
    End;
  End;


Function BbsPrompt(Item: Word): String;
  Var
    S: String;

  Begin
  If NumCust > 0 Then
    Begin
    If Item <= NumCust Then
      BbsPrompt := ' ' + CustCodes^[Item].Prompt
    Else
      BbsPrompt := '';
    Exit;
    End;
  S := '';
  Case Item Of
    01: S := 'Wait on Enter    [^A]';
    02: S := 'Disable Stopping [^B]';
    03: S := 'Enable Stopping  [^C]';
    04: S := 'Enable More?     [^D]';
    05: S := 'Disable More?    [^E]';
    06: S := 'Beep             [^G]';
    07: S := 'Clear Screen     [^L]';
    08: S := 'Pause one second [^W]';
    09: S := 'Full Name        [^FA]';
    10: S := 'Location         [^FB]';
    11: S := 'Password         [^FC]';
    12: S := 'Bus/Data phone   [^FD]';
    13: S := 'Voice/Home phone [^FE]';
    14: S := 'Last call date   [^FF]';
    15: S := 'Last call time   [^FG]';
    16: S := 'A security flags [^FH]';
    17: S := 'B security flags [^FI]';
    18: S := 'C security flags [^FJ]';
    19: S := 'D security flags [^FK]';
    20: S := 'Netmail credit   [^FL]';
    21: S := 'Messages Posted  [^FM]';
    22: S := 'Last msg read    [^FN]';
    23: S := 'Security level   [^FO]';
    24: S := 'Total calls      [^FP]';
    25: S := 'Num Uploads      [^FQ]';
    26: S := 'Kb Uploads       [^FR]';
    27: S := 'Num Downloads    [^FS]';
    28: S := 'Kb Downloads     [^FT]';
    29: S := 'Mins used today  [^FU]';
    30: S := 'Screen length    [^FV]';
    31: S := 'First name       [^FW]';
    32: S := 'Ansi setting     [^FX]';
    33: S := 'More? setting    [^FY]';
    34: S := 'Screen clearing  [^FZ]';
    35: S := 'Full scrn editor [^F0]';
    36: S := 'Avatar setting   [^F8]';
    37: S := 'System calls     [^KA]';
    38: S := 'Last caller      [^KB]';
    39: S := 'Active msgs      [^KC]';
    40: S := 'Low msg number   [^KD]';
    41: S := 'High msg number  [^KE]';
    42: S := 'Times paged      [^KF]';
    43: S := 'Day of week      [^KG]';
    44: S := 'Number of users  [^KH]';
    45: S := 'Time (24hr)      [^KI]';
    46: S := 'Todays date      [^KJ]';
    47: S := 'Mins this call   [^KK]';
    48: S := 'Secs this call   [^KL]';
    49: S := 'Mins today       [^KM]';
    50: S := 'Secs today       [^KN]';
    51: S := 'Mins remain      [^KO]';
    52: S := 'Secs remain      [^KP]';
    53: S := 'Daily time limit [^KQ]';
    54: S := 'Baud rate        [^KR]';
    55: S := 'Short Day of week[^KS]';
    56: S := 'Daily kb limit   [^KT]';
    57: S := 'Mins until event [^KU]';
    58: S := 'Next event time  [^KV]';
    59: S := 'Line number      [^KW]';
    60: S := 'Terminate call   [^KX]';
    61: S := 'Curr msg area    [^KY]';
    62: S := 'Curr file area   [^KZ]';
    63: S := 'Num msg area     [^K1]';
    64: S := 'Num file area    [^K2]';
    Else
      S := '';
    End;
  If S <> '' Then
    S := ' ' + S;
  BbsPrompt := S;
  End;


Function BbsCode(Item: Word): String;
  {the built-in codes: ^A ^B ^C ^D ^E ^G ^L ^W, then ^F x (user), ^K x (system) with the letters of the prompt list}
  Begin
  BbsCode := '';
  If NumCust > 0 Then
    Begin
    If Item <= NumCust Then
      BbsCode := CustCodes^[Item].Code;
    Exit;
    End;
  Case Item Of
    01: BbsCode := #1;
    02: BbsCode := #2;
    03: BbsCode := #3;
    04: BbsCode := #4;
    05: BbsCode := #5;
    06: BbsCode := #7;
    07: BbsCode := #12;
    08: BbsCode := #23;
    09..34: BbsCode := #6 + Chr(65 + Item - 9);          {^F A .. ^F Z}
    35: BbsCode := #6#48;                                 {^F 0}
    36: BbsCode := #6#56;                                 {^F 8}
    37..62: BbsCode := #11 + Chr(65 + Item - 37);        {^K A .. ^K Z}
    63: BbsCode := #11#49;                                {^K 1}
    64: BbsCode := #11#50;                                {^K 2}
    End;
  End;


Function GetBbsStr: String;
  Var
    N, Choice: Word;

  Begin
  GetBbsStr := '';
  N := MaxBbsCodes;
  If NumCust > 0 Then
    N := NumCust;
  Choice := 1;
  If RunPick('Bbs Screen Code', N, 26, BbsPrompt, Choice) Then
    GetBbsStr := BbsCode(Choice);
  End;


{------------------------------------------------------------ the other lists}

Function CharSetStr(i: Word): String;
  Begin
  If (i >= 1) And (i <= 15) Then
    CharSetStr := '  ' + ExtChars[i]
  Else
    CharSetStr := '';
  End;


Function DrawStr(Item: Word): String;
  Begin
  Case Item Of
    1..4: DrawStr := '  ' + Copy(ExtChars[Item], 1, 6);
    Else DrawStr := '  Normal';
    End;
  End;


Procedure GetPickChar;
  Var
    C: Word;

  Begin
  C := CurrSet;
  If RunPick('Ext Char Set', 15, 16, CharSetStr, C) Then
    CurrSet := C;
  End;


Procedure GetDrawSet(Var DSet: Word);
  Var
    C: Word;

  Begin
  C := DSet;
  If RunPick('Drawing Mode', 5, 16, DrawStr, C) Then
    DSet := C;
  End;


Function ActionStr(Item: Word): String;
  Begin
  Case Item Of
    1: ActionStr := ' None';
    2: ActionStr := ' Home';
    3: ActionStr := ' Clear Screen';
    Else ActionStr := '';
    End;
  End;


Function GetActionCmd: Word;
  {1 = none, 2 = home, 3 = clear screen, 0 = cancelled}
  Var
    C: Word;

  Begin
  C := 1;
  If RunPick('Action', 3, 15, ActionStr, C) Then
    GetActionCmd := C
  Else
    GetActionCmd := 0;
  End;


Const
  MenuItems = 20;
  MenuText: Array[1..MenuItems] Of String[28] = (
    ' Attribute Selection',
    ' Toggle Blinking',
    ' Toggle Intensity',
    ' Pick color under cursor',
    ' Reverse color attribute',
    ' Fill area with attribute',
    ' Copy area of the screen',
    ' Move area of the screen',
    ' Insert a blank line',
    ' Delete current line',
    ' Clear area of the screen',
    ' Pick BBS Screen Code',
    ' Get extended char set',
    ' Enclose area in box frame',
    ' Load a screen file',
    ' Save a screen file',
    ' Save the whole screen',
    ' Help',
    ' Drawing mode',
    ' Exit from MKDraw');
  MenuCode: Array[1..MenuItems] Of Word = (
    cmAttrPick, cmBlink, cmIntens, cmUnder, cmReverse, cmFill, cmCopy, cmMove, cmInsLine, cmDelLine,
    cmClear, cmBbsCode, cmGetSet, cmEnclose, cmLoad, cmSave, cmSaveAll, cmHelp, cmDrawMode, cmExitDraw);


Function MenuStr(Item: Word): String;
  Begin
  If (Item >= 1) And (Item <= MenuItems) Then
    MenuStr := MenuText[Item]
  Else
    MenuStr := '';
  End;


Function GetMenuCmd: Word;
  Var
    C: Word;

  Begin
  C := 1;
  If RunPick('MKDraw Fast Menu', MenuItems, 28, MenuStr, C) Then
    GetMenuCmd := MenuCode[C]
  Else
    GetMenuCmd := cmNone;
  End;


{------------------------------------------------------------ the files}

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


Function PickScreenFile(Mask: String; Var Chosen: String): Boolean;
  Var
    D: DirStr;
    N: NameStr;
    E: ExtStr;
    SR: SearchRec;
    i, j: Word;
    T: String[60];
    Idx: Word;

  Begin
  PickScreenFile := False;
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
    MsgBox('No screen files found: ' + D + N + E);
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
  If RunPick('Screen Files', NFiles, 36, FileStr, Idx) Then
    Begin
    Chosen := D + Files[Idx];
    PickScreenFile := True;
    End;
  End;


Begin
CustCodes := Nil;
NumCust := 0;
End.
