Unit MKReadCf;   {MKRead settings, tag line editor, help texts, twit list (Free Vision)}

{$I MKB.Def}

Interface

Type ReadCfgType = Record
  Name: String[35];
  UserNum: LongInt;
  UseText: Boolean;
  TextEd: String[70];
  QuoteStr: String[8];
  LastExport: String[70];
  SpellCheck: String[70];
  QuoteHdr: String[70];
  Taglines: Boolean;
  NextTag: Word;
  YourBeep: Boolean;
  NewOnly: Boolean;
  MsgOrder: Byte;
  Colors: Array[1..10] of Byte;
  Crash: Boolean;
  Direct: Boolean;
  Imm: Boolean;
  FileReq: Boolean;
  FAttach: Boolean;
  KillSent: Boolean;
  NetPath: String[70];
  NetTaglines: Boolean;
  NetFido: Boolean;
  AnsiBaud: Word;
  PrnName: String[13];
  End;

Var
  CfgRec: ReadCfgType;

Procedure EditCfg;
Procedure DoTagEdit(Var TagLineStr: String; TagNum: Word);
Procedure EditHelp;
Procedure NoHelp;
Procedure MenuHelp;
Procedure LoadTwits;
Function  Twit(Name: String): Boolean;

Implementation

Uses Objects, Drivers, Views, Dialogs, App, MKString, MKFile, MKCfgAbs, CfgForm,
  CfgColor, CfgList;

Const
  MaxTwits = 20;

Var
  TagToEdit: String;
  TwitList: Array[1..MaxTwits] of String[35];
  NumTwits: Word;


Function Twit(Name: String): Boolean;
  Var
    i: Word;

  Begin
  Twit := False;
  Name := Upper(Name);
  i := 1;
  While i <= NumTwits Do
    Begin
    If TwitList[i] = Name Then
      Twit := True;
    Inc(i);
    End;
  End;


Procedure LoadTwits;
  Var
    TF: TFile;
    TmpStr: String;

  Begin
  NumTwits := 0;
  TmpStr := Config^.FindBbsFile('Twit.Ctl') + 'Twit.Ctl';
  If FileExist(TmpStr) Then
    Begin
    TF.Init;
    If TF.OpenTextFile(TmpStr) Then
      Begin
      TmpStr := TF.GetString;
      While (TF.StringFound and (NumTwits < MaxTwits)) Do
        Begin
        Inc(NumTwits);
        TwitList[NumTwits] := Upper(TmpStr);
        TmpStr := TF.GetString;
        End;
      If TF.CloseTextFile Then;
      End;
    TF.Done;
    End;
  End;


Function GreekStr(InStr: String): String;
  Var
    TmpStr: String;
    Cnt: Word;
    FoundPos: Word;

  Const
    OrigChars: String = 'ABCDEFGIJLNOQTUYZ';
    CvtChars: String  = 'àá›ëîŸ‡‹õœ¤¢€çæ˜ä';

  Begin
  TmpStr := InStr;
  Cnt := 1;
  While Cnt <= Length(InStr) Do
    Begin
    FoundPos := Pos(UpCase(InStr[Cnt]), OrigChars);
    If FoundPos > 0 Then
      TmpStr[Cnt] := CvtChars[FoundPos];
    Inc(Cnt);
    End;
  GreekStr := TmpStr;
  End;


{------------------------------------------------------------ help texts}

Procedure MenuHelp;
  Const
    CR = #13;
  Begin
  ShowText('MKRead Commands',
    'Area       Select new area for reading messages' + CR +
    'Prior      Go to previous message in the current area' + CR +
    'Next       Go to next message in the current area' + CR +
    'Export     Export the current message to a text file' + CR +
    'Reply      Reply to the current message' + CR +
    'Enter      Enter a new message' + CR +
    '+Pg / -Pg  Next / previous page of the message text' + CR +
    'Config     Set the MKRead parameters' + CR +
    'Jump       List of messages: pick one to jump to' + CR +
    'Del        Delete the current message' + CR +
    'View       View the current message in Ansi/Avatar format' + CR +
    'Quit       Exit MKRead' + CR + CR +
    'Alt-F  Forward message      Alt-R  Resort messages' + CR +
    'Alt-G  Grab tagline         Alt-T  Edit taglines' + CR +
    'Alt-S  Select tagline       Alt-P  Print message');
  End;


Procedure EditHelp;
  Const
    CR = #13;
  Begin
  ShowText('Message Editor Keys',
    'Arrows, Home, End, PgUp, PgDn   Move the cursor' + CR +
    'Ctrl-Left / Ctrl-Right          Word left / right' + CR +
    'Ctrl-PgUp / Ctrl-PgDn           Top / end of the text' + CR +
    'Del / Backspace                 Delete a character' + CR +
    'Ctrl-Y                          Delete the line' + CR +
    'Ctrl-T                          Delete a word' + CR +
    'Ins                             Insert / overwrite' + CR +
    'Shift + arrows                  Select text' + CR +
    'Ctrl-Ins / Shift-Del / Shift-Ins  Copy / cut / paste' + CR +
    'Ctrl-U                          Undo' + CR +
    'Ctrl-Q F / Ctrl-Q A / Ctrl-L    Find / replace / find again' + CR +
    'Esc / F10                       Leave the editor (it asks to save)' + CR + CR +
    'Text wraps at column 72 as you type.' + CR +
    'Alt-Q / Alt-U                   Quote / unquote the selection or the line' + CR +
    'Alt-S                           Select the next tagline' + CR +
    'Alt-T                           Edit the taglines' + CR +
    'F1                              This help');
  End;


Procedure NoHelp;
  Begin
  ShowText('MKRead', 'No help is available for this.');
  End;


{------------------------------------------------------------ settings}

Procedure NetOptions(Data: Pointer; Title: String);
  Var
    M: CfgMarks;

  Begin
  FillChar(M, SizeOf(M), 0);
  M[1] := CfgRec.Crash;
  M[2] := CfgRec.Direct;
  M[3] := CfgRec.Imm;
  M[4] := CfgRec.FileReq;
  M[5] := CfgRec.FAttach;
  M[6] := CfgRec.KillSent;
  M[7] := CfgRec.NetTaglines;
  M[8] := CfgRec.NetFido;
  If RunChecks('NetMail Options', 'Crash|Direct|Immediate|File Request|File Attach|' +
       'Kill after sending|Add tagline|Add Fido Info', M) Then
    Begin
    CfgRec.Crash := M[1];
    CfgRec.Direct := M[2];
    CfgRec.Imm := M[3];
    CfgRec.FileReq := M[4];
    CfgRec.FAttach := M[5];
    CfgRec.KillSent := M[6];
    CfgRec.NetTaglines := M[7];
    CfgRec.NetFido := M[8];
    End;
  End;


Procedure EditCfg;
  Var
    F: CfgFormObj;

  Begin
  F.Init('MKRead Configuration');
  F.Window(1, 1, 76, 14);
  F.At(1, 3, 1, 9);
  F.AddString('Name:', CfgRec.Name, 35, 'Your name, as used for replies and for finding your mail');
  F.At(1, 47, 1, 57);
  F.AddNumber('User Num:', CfgRec.UserNum, 4, -2147483647, 2147483647, 'Your user number');
  F.At(2, 3, 2, 11);
  F.Show(60);
  F.AddFile('Editor:', CfgRec.TextEd, 70, 'External text editor (blank: the built in one)');
  F.At(3, 3, 3, 26);
  F.AddYesNo('Use Text Control File:', CfgRec.UseText, 'Use the text control file');
  F.At(3, 30, 3, 41);
  F.AddString('Quote Str:', CfgRec.QuoteStr, 8, 'Characters put in front of quoted lines');
  F.At(3, 52, 3, 68);
  F.AddYesNo('Beep Your Mail:', CfgRec.YourBeep, 'Beep when a message to you is found');
  F.At(4, 3, 4, 17);
  F.Show(55);
  F.AddFile('Spell Checker', CfgRec.SpellCheck, 70, 'Spell checker program');
  F.At(5, 3, 5, 17);
  F.Show(55);
  F.AddString('Quote Header:', CfgRec.QuoteHdr, 70, 'Line put above a quoted message');
  F.At(6, 3, 6, 18);
  F.AddYesNo('New Mail Only:', CfgRec.NewOnly, 'Show only new messages');
  F.At(6, 24, 6, 34);
  F.AddYesNo('Taglines:', CfgRec.Taglines, 'Add a tagline to replies');
  F.At(6, 38, 6, 49);
  F.AddChoice('Msg Order:', CfgRec.MsgOrder, 1, 1, 'Subject|Msg Number|Date/Time|From',
    'Order of the messages (Space or the arrow keys change it)');
  F.At(6, 63, 0, 0);
  F.AddAction('NetMail...', NetOptions, Nil, '', 'NetMail options');
  F.At(8, 3, 8, 17);
  F.Show(55);
  F.AddDir('NetMail Path:', CfgRec.NetPath, 70, 'Directory for outgoing netmail');
  F.At(9, 3, 9, 14);
  F.AddNumber('Ansi Baud:', CfgRec.AnsiBaud, 2, 0, 65535, 'Speed for viewing Ansi messages (0 = fastest)');
  F.At(9, 23, 9, 37);
  F.AddString('Printer Name:', CfgRec.PrnName, 13, 'Printer device or file');
  F.At(11, 27, 0, 0);
  F.AddText('---- Colors -----');
  F.At(12, 3, 12, 9);
  F.AddHex('Text:', CfgRec.Colors[1], 1, 'Message text color');
  F.OnF2(PickColor, @CfgRec.Colors[1], 'Text Color');
  F.At(12, 14, 12, 21);
  F.AddHex('Quote:', CfgRec.Colors[7], 1, 'Quoted text color');
  F.OnF2(PickColor, @CfgRec.Colors[7], 'Quote Color');
  F.At(12, 26, 12, 38);
  F.AddHex('Hdr Titles:', CfgRec.Colors[2], 1, 'Message header titles');
  F.OnF2(PickColor, @CfgRec.Colors[2], 'Header Title');
  F.At(12, 43, 12, 53);
  F.AddHex('Hdr Info:', CfgRec.Colors[3], 1, 'Message header data');
  F.OnF2(PickColor, @CfgRec.Colors[3], 'Header Data');
  F.At(13, 3, 13, 9);
  F.AddHex('Menu:', CfgRec.Colors[4], 1, 'Menu color');
  F.OnF2(PickColor, @CfgRec.Colors[4], 'Menu Color');
  F.At(13, 24, 13, 39);
  F.AddHex('Menu Key Char:', CfgRec.Colors[5], 1, 'Menu key letter color');
  F.OnF2(PickColor, @CfgRec.Colors[5], 'Menu Key');
  F.At(13, 50, 13, 65);
  F.AddHex('Menu Selector:', CfgRec.Colors[6], 1, 'Menu selection bar color');
  F.OnF2(PickColor, @CfgRec.Colors[6], 'Menu Select');
  If F.Execute Then;
  End;


{------------------------------------------------------------ tag lines}

Procedure TagBackward(Data: Pointer; Title: String);
  Var
    TmpStr: String;
    Cnt: Word;

  Begin
  TmpStr := '';
  For Cnt := Length(TagToEdit) Downto 1 Do
    TmpStr := TmpStr + TagToEdit[Cnt];
  TagToEdit := TmpStr;
  End;


Procedure TagGreek(Data: Pointer; Title: String);
  Begin
  TagToEdit := GreekStr(TagToEdit);
  End;


Procedure TagUpper(Data: Pointer; Title: String);
  Begin
  TagToEdit := Upper(TagToEdit);
  End;


Procedure TagLower(Data: Pointer; Title: String);
  Begin
  TagToEdit := Lower(TagToEdit);
  End;


Procedure TagMixed(Data: Pointer; Title: String);
  Begin
  TagToEdit := Proper(TagToEdit);
  End;


Procedure TagClean(Data: Pointer; Title: String);
  Var
    Cnt: Word;

  Begin
  For Cnt := 1 To Length(TagToEdit) Do
    TagToEdit[Cnt] := CleanChar(TagToEdit[Cnt]);
  End;


Procedure DoTagEdit(Var TagLineStr: String; TagNum: Word);
  Var
    F: CfgFormObj;

  Begin
  TagToEdit := TagLineStr;
  F.Init('Edit TagLine ' + Long2Str(TagNum));
  F.Window(1, 1, 76, 5);
  F.At(2, 3, 2, 8);
  F.Show(60);
  F.AddString(Long2Str(TagNum) + ':', TagToEdit, 60, 'The tagline text');
  F.At(4, 3, 0, 0);
  F.AddAction('Backward', TagBackward, Nil, '', 'Reverse the text');
  F.At(4, 15, 0, 0);
  F.AddAction('Greek', TagGreek, Nil, '', 'Replace letters by look-alike graphic characters');
  F.At(4, 25, 0, 0);
  F.AddAction('Upper', TagUpper, Nil, '', 'UPPER CASE');
  F.At(4, 35, 0, 0);
  F.AddAction('Lower', TagLower, Nil, '', 'lower case');
  F.At(4, 45, 0, 0);
  F.AddAction('Mixed', TagMixed, Nil, '', 'Mixed Case');
  F.At(4, 55, 0, 0);
  F.AddAction('Clean', TagClean, Nil, '', 'Replace graphic characters by plain ones');
  If F.Execute Then
    TagLineStr := TagToEdit;
  End;


End.
