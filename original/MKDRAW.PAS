Program MKDraw;
{$I MKB.Def}

Uses MKFile, MKString, Dos, OpCRT, MKAvatar, CfgYN, OPWindow, OPColor,
  OpCmd, MKColor, MKDrawCf, OpExec, OpMouse;

const
  MouseChar: Char = #04;

const
  EsColors : ColorSet = (
    TextColor       : YellowOnBlue;       TextMono        : WhiteOnBlack;
    CtrlColor       : YellowOnBlue;       CtrlMono        : WhiteOnBlack;
    FrameColor      : WhiteOnBlue;        FrameMono       : LtGrayOnBlack;
    HeaderColor     : WhiteOnCyan;        HeaderMono      : BlackOnLtGray;
    ShadowColor     : DkGrayOnBlack;      ShadowMono      : WhiteOnBlack;
    HighlightColor  : WhiteOnRed;         HighlightMono   : BlackOnLtGray;
    PromptColor     : LtGrayOnBlue;       PromptMono      : LtGrayOnBlack;
    SelPromptColor  : LtGrayOnBlue;       SelPromptMono   : LtGrayOnBlack;
    ProPromptColor  : LtGrayOnBlue;       ProPromptMono   : LtGrayOnBlack;
    FieldColor      : YellowOnBlue;       FieldMono       : LtGrayOnBlack;
    SelFieldColor   : BlueOnCyan;         SelFieldMono    : WhiteOnBlack;
    ProFieldColor   : LtGrayOnBlue;       ProFieldMono    : LtGrayOnBlack;
    ScrollBarColor  : CyanOnBlue;         ScrollBarMono   : LtGrayOnBlack;
    SliderColor     : CyanOnBlue;         SliderMono      : WhiteOnBlack;
    HotSpotColor    : BlackOnCyan;        HotSpotMono     : BlackOnLtGray;
    BlockColor      : YellowOnCyan;       BlockMono       : WhiteOnBlack;
    MarkerColor     : WhiteOnCyan;        MarkerMono      : BlackOnLtGray;
    DelimColor      : YellowOnBlue;       DelimMono       : WhiteOnBlack;
    SelDelimColor   : BlueOnCyan;         SelDelimMono    : WhiteOnBlack;
    ProDelimColor   : YellowOnBlue;       ProDelimMono    : WhiteOnBlack;
    SelItemColor    : YellowOnCyan;       SelItemMono     : BlackOnLtGray;
    ProItemColor    : LtGrayOnBlue;       ProItemMono     : LtGrayOnBlack;
    HighItemColor   : WhiteOnBlue;        HighItemMono    : WhiteOnBlack;
    AltItemColor    : WhiteOnBlue;        AltItemMono     : WhiteOnBlack;
    AltSelItemColor : WhiteOnCyan;        AltSelItemMono  : BlackOnLtGray;
    FlexAHelpColor  : WhiteOnBlue;        FlexAHelpMono   : WhiteOnBlack;
    FlexBHelpColor  : WhiteOnBlue;        FlexBHelpMono   : WhiteOnBlack;
    FlexCHelpColor  : LtCyanOnBlue;       FlexCHelpMono   : BlackOnLtGray;
    UnselXrefColor  : YellowOnBlue;       UnselXrefMono   : LtBlueOnBlack;
    SelXrefColor    : WhiteOnCyan;        SelXrefMono     : BlackOnLtGray;
    MouseColor      : WhiteOnRed;         MouseMono       : BlackOnLtGray
  );


Type SSaveRec = Record
  SChar: Array[1..23] of String[150];
  SAttr: Array[1..23] of String[150];
  End;

Const
  KeyMax = 520;

Const
  WColor = WhiteOnBlue;
  DrawChars: Array[1..4] of String[16] = (('   Ä ¿ÚÂ ÙÀÁ³´ÃÅ'),
                                          ('   Í »ÉË ¼ÈÊº¹ÌÎ'),
                                          ('   Í ¸ÕÑ ¾ÔÏ³µÆØ'),
                                          ('   Ä ·ÖÒ ½ÓÐº¶Ç×'));

Const BannerName =
 '  MKDraw v1.01 Copyright 1992,1995 by Mark May         Press Alt-H for Help';


Var
  KeySet : Array[0..KeyMax] of Byte;
  CT: CursorType;
  Ch: Char;
  Commands: CommandProcessor;
  CurrFile: String;
  InsertMode: Boolean;
  StatusWin: StackWindow;
  AnsiWin: StackWindow;
  TmpStr: String;
  TmpStr2: String;
  Key: Word;
  TmpCmd: Word;
  LXL, LXH, LYL, LYH: Byte;
  DrawSet: Word;
  TA: Byte;


Function GetCharValue(x,y: Word): Byte;
  Var
    ch: Char;
    CharStr: String[5];
    p: Word;

  Begin
  p := 0;
  If ((X > 0) and (X <= 80) and (Y > 0) and (Y <= 23)) Then
    Begin
    AnsiWin.wFastRead(1, y, x, CharStr);
    ch := CharStr[1];
    End
  Else
    ch := ' ';
  p := Pos(ch, DrawChars[1]);
  If p = 0 Then
    p := Pos(ch, DrawChars[2]);
  If p = 0 Then
    p := Pos(ch, DrawChars[3]);
  If p = 0 Then
    p := Pos(ch, DrawChars[4]);
  If p = 0 Then
    GetCharValue := 0
  Else
    GetCharValue := p - 1;
  End;


Function GetDrawChar(X,Y: Word; Going: Word): Char;
  {Going 1=left 2=right 3=down 4=up}

  Var
    Tmp: Word;

  Begin
  Tmp := 0;
  If Going = 1 Then
    Inc(Tmp,1)
  Else
    If (GetCharValue(X - 1, y) and 2) <> 0 Then
      Inc(Tmp, 1);
  If Going = 2 Then
    Inc(Tmp, 2)
  Else
    If (GetCharValue(X + 1, y) and 1) <> 0 Then
      Inc(Tmp, 2);
  If Going = 3 Then
    Inc(Tmp, 4)
  Else
    If (GetCharValue(x, y + 1) and 8) <> 0 Then
      Inc(Tmp, 4);
  If Going = 4 Then
    Inc(Tmp, 8)
  Else
    If (GetCharValue(x, y - 1) and 4) <> 0 Then
      Inc(Tmp, 8);
  If ((Tmp = 1) or (Tmp = 2)) Then
    Tmp := 3;
  If ((Tmp = 4) or (Tmp = 8)) Then
    Tmp := 12;
  GetDrawChar := DrawChars[DrawSet][Tmp + 1];
  End;


Procedure PutDrawChar(X, Y: Word; Going: Word);
  Var
    TmpStr: String[5];
    Ta: Byte;

  Begin
  If DrawSet <> 5 Then
    Begin
    HideMouse;
    AnsiWin.Select;
    Ta := TextAttr;
    TmpStr := GetDrawChar(X, Y, Going);
    AnsiWin.wFastWrite(TmpStr, Y, X, ta);
    If MouseInstalled Then
      ShowMouse;
    End;
  End;


Procedure NoHelp;
  Begin
  WriteLn(#13#13#13);
  WriteLn('No Help Available');
  End;


Procedure GeneralHelp;
  Begin
  WriteLn;
  WriteLn('                           Command Keys for MKDraw');
  WriteLn(' Alt-A   Color/attribute select         Alt F1-F5   Select character sets');
  WriteLn(' Alt-B   Blinking toggle                Ctl F1-F10  Select character sets');
  WriteLn(' Alt-C   Copy area                      F1-F10      Enter special character');
  WriteLn(' Alt-D   Drawing mode');
  WriteLn(' Alt-E   Enclose in frame');
  WriteLn(' Alt-F   Attribute Fill area');
  WriteLn(' Alt-G   Get extened character set');
  WriteLn(' Alt-H   Help');
  WriteLn(' Alt-I   Intensity toggle               Home        Beginning of line');
  WriteLn(' Alt-J   Jump to Dos                    End         End of line');
  WriteLn(' Alt-L   Load screen                    PgUp        Top of screen');
  WriteLn(' Alt-M   Move area                      PgDn        Bottom of screen');
  WriteLn(' Alt-P   Pick Bbs Code                  Arrow keys  Move cursor');
  WriteLn(' Alt-R   Reverse attribute');
  WriteLn(' Alt-S   Save screen area               Del         Delete character');
  WriteLn(' Alt-U   Color Under cursor             Ins         Toggle insert mode');
  WriteLn(' Alt-V   Insert line');
  WriteLn(' Alt-W   Double image');
  WriteLn(' Alt-X   Exit');
  WriteLn(' Alt-Y   Delete line');
  Write  (' Alt-Z   Zap/clear area');
  End;


Procedure DisplayHelp(HelpIndex : Word);
  Var
    HelpWin: StackWindowPtr;
    Ch: Char;

  Begin
  HideMouse;
  New(HelpWin, InitCustom(2,2,79,24, ESColors,
  wBordered + wClear + wSaveContents));
  If HelpWin <> nil Then
    Begin
    HelpWin^.wFrame.SetFrameType(Frame1);
    HelpWin^.Draw;
    SetCursorType(cuHidden);
    Case HelpIndex of
      1: GeneralHelp;
      Else
        NoHelp;
      End;
    Ch := Readkey;
    HelpWin^.Erase;
    Dispose(HelpWin, Done);
    SetCursorType(cuBlock);
    End;
  AnsiWin.Select;
  If MouseInstalled Then
    ShowMouse;
  End;




Procedure LoadExtChars;
  Begin
  ExtChars[01] := 'Ú¿ÀÙÄ³Ã´ÁÂ';
  ExtChars[02] := 'É»È¼ÍºÌ¹ÊË';
  ExtChars[03] := 'Õ¸Ô¾Í³ÆµÏÑ';
  ExtChars[04] := 'Ö·Ó½ÄºÇ¶ÐÒ';
  ExtChars[05] := 'ÅÎØ×èé›œ™ï';
  ExtChars[06] := '°±²ÛßÜÝÞþú';
  ExtChars[07] := 'ð';
  ExtChars[08] := '';
  ExtChars[09] := '®¯òó©ªýö«¬';
  ExtChars[10] := 'ãñôõêäøûü';
  ExtChars[11] := 'àáâåæçëìíî';
  ExtChars[12] := '€‡¥¤˜Ÿ÷ù­¨';
  ExtChars[13] := 'ƒ„… ¦†Ž‘’';
  ExtChars[14] := 'ˆ‰Š‚Œ‹¡ž';
  ExtChars[15] := '“”•¢§–—£š';
  End;


Procedure FillInChars;
  Var
    i: Word;

  Begin
  HideMouse;
  StatusWin.Select;
  TextAttr := WColor;
  For i := 1 to 10 Do
    Begin
    If i = 10 Then
      GoToXy(75,2)
    Else
      GoToXy(34 + i * 4, 2);
    Write(ExtChars[CurrSet][i]);
    End;
  GoToXy(30,2);
  Write(PadLeft(Long2Str(CurrSet),' ',2));
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure UpdateColor;
  Var
    TA: Byte;

  Begin
  HideMouse;
  AnsiWin.Select;
  TA := TextAttr;
  StatusWin.Select;
  TextAttr := TA;
  GoToXy(14, 2);
  Write('Color');
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure UpdateIns;
  Begin
  HideMouse;
  AnsiWin.Select;
  StatusWin.Select;
  TextAttr := WColor;
  GoToXY(21, 2);
  If InsertMode Then
    Write('Ins')
  Else
    Write('Ovr');
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure UpdateDraw;
  Begin
  HideMouse;
  AnsiWin.Select;
  StatusWin.Select;
  TextAttr := WColor;
  GoToXY(46, 1);
  Case DrawSet of
    1..4: Write(Copy(ExtChars[DrawSet],1,6));
    Else
      Write('      ');
    End;
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure UpdateXY;
  Var
    TX: String[3];
    TY: String[3];

  Begin
  HideMouse;
  AnsiWin.Select;
  TX := PadLeft(Long2Str(WhereX),' ',3);
  TY := PadLeft(Long2Str(WhereY),' ',3);
  StatusWin.Select;
  TextAttr := WColor;
  GoToXY(4, 2);
  Write(Tx,',',Ty);
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure DisplayAnsiWindow(FileName: String);

  Var
    AFile: File;
    Buffer: Array[1..512] of Char;
    I: Word;
    NumRead: Word;

  Begin
  HideMouse;
  If (Length(FileName) > 0) And (FileExist(FileName)) And
  (Not IsDevice(FileName)) Then
    Begin
    AnsiWin.Select;
    TextAttr := Cyan;
    ClrScr;
    SetCursorType(cuBlock);
    If Not shAssign (Afile,FileName) Then;
    FileMode := fmReadOnly + fmDenyNone;
    If shReset (Afile,1) Then
      Begin
      GoToXY(1,1);
      While ((Not Eof(Afile))) Do
        Begin
        BlockRead(Afile,Buffer, SizeOf(Buffer), NumRead);
        If IoResult <> 0 Then
          WriteLn('Error reading File');
        i := 1;
        While i <= NumRead Do
          Begin
          If ((Buffer[i] <> #10) or (WhereY <> 23)) Then
            Begin
            Case Buffer[i] of
              '`': Buffer[i] := #27;
              End;
            AvatarChar(Buffer[i]);
            End;
          Inc(i);
          End;
        End;
      Close(Afile);
      If IoResult <> 0 Then
        WriteLn('Error closing TxtFile');
      End
    Else
      WriteLn('Cannot Open TxtFile ' + FileName);
    AnsiWin.SetTextAttr(TextAttr, TextAttr);
    UpdateColor;
    GoToXY(1,1);
    UpdateXY;
    AnsiWin.Select;
    End
  Else
    Begin
    Write(#7, #7, #7);
    End;
  If MouseInstalled Then
    ShowMouse;
  End;



Procedure SaveAnsi(FN: String; XL, YL, XH, YH: Byte; Action: Word);
  Var
    CY: Byte;
    CharStr: String;
    AttrStr: String;
    TmpStr: String;
    LastAttr: Char;
    TF: Text;
    i: Word;
    Finished: Boolean;

  Begin
  AnsiWin.Select;
  Assign(TF, FN);
  ReWrite(TF);
  If IoResult <> 0 Then
    Write(#7, #7);
  Case Action of
    2: Write(TF, #27'[H');
    3: Write(TF, AnsiColor(Cyan, Black) + #27'[2J');
    End;
  LastAttr := Chr(Cyan);
  For CY := YL TO YH Do
    Begin
    AnsiWin.wFastRead(XH + 1 - XL, CY, XL, CharStr);
    AnsiWin.wReadAttribute(XH + 1 - XL, CY, XL, AttrStr);
{    CharStr := StripTrail(CharStr,' '); }
    If ((Length(CharStr) = 80) and (CharStr[80] = ' ')) Then
      CharStr := Copy(CharStr,1,79);
    TmpStr := '';
{    CharStr := StripTrail(CharStr,' '); }

    {remove trailing non-attr spaces}
    i := Length(CharStr);
    Finished := False;
    While (Not Finished) and (i > 0) Do
      Begin
      If (CharStr[i] = ' ') and ((Ord(AttrStr[i]) and $70) = 0) Then
        Begin
        CharStr[0] := Pred(CharStr[0]);
        End
      Else
        Finished := True;
      Dec(i);
      End;

    For i := 1 to length(CharStr) Do
      Begin
      If AttrStr[i] <> LastAttr Then
        Begin
        If ((CharStr[i] <> ' ') Or
        ((Ord(AttrStr[i]) and $70) <> (Ord(LastAttr) and $70))) Then
          Begin
          TmpStr := TmpStr + AnsiAttrDiff(Ord(LastAttr),Ord(AttrStr[i]));
          LastAttr := AttrStr[i];
          End;
        End;
      TmpStr := TmpStr + CharStr[i];
      If Length(TmpStr) > 230 Then
        Begin
        Write(TF, TmpStr);
        TmpStr := '';
        End;
      End;
    WriteLn(TF, TmpStr);
{    WriteLn(TF, StripTrail(TmpStr, ' ')); }
    If IoResult <> 0 Then;
    End;
  Close(TF);
  If IoResult <> 0 Then
    Write (#7);
  End;


Procedure SavePascal(FN: String; XL, YL, XH, YH: Byte; Action: Word);
  Var
    CY: Byte;
    CharStr: String;
    AttrStr: String;
    TmpStr: String;
    LastAttr: Char;
    TF: Text;
    i: Word;
    Finished: Boolean;

  Begin
  AnsiWin.Select;
  Assign(TF, FN);
  ReWrite(TF);
  If IoResult <> 0 Then
    Write(#7, #7);
  WriteLn(TF, 'Procedure DoBanner;');
  WriteLn(TF, '  Begin');
  Case Action of
    2: WriteLn(TF, '  AvStr(''' + #27'[H' + ''');');
    3: WriteLn(TF, '  AvStr(''' + AnsiColor(Cyan, Black) + #27'[2J' + ''');');
    End;
  LastAttr := Chr(Cyan);
  For CY := YL TO YH Do
    Begin
    AnsiWin.wFastRead(XH + 1 - XL, CY, XL, CharStr);
    AnsiWin.wReadAttribute(XH + 1 - XL, CY, XL, AttrStr);
{    CharStr := StripTrail(CharStr,' '); }
{    If ((Length(CharStr) = 80) and (CharStr[80] = ' ')) Then
      CharStr := Copy(CharStr,1,79);}
    TmpStr := '';
{    CharStr := StripTrail(CharStr,' '); }

    {remove trailing non-attr spaces}
    i := Length(CharStr);
    Finished := False;
    While (Not Finished) and (i > 0) Do
      Begin
      If (CharStr[i] = ' ') and ((Ord(AttrStr[i]) and $70) = 0) Then
        Begin
        CharStr[0] := Pred(CharStr[0]);
        End
      Else
        Finished := True;
      Dec(i);
      End;

    For i := 1 to length(CharStr) Do
      Begin
      If AttrStr[i] <> LastAttr Then
        Begin
        If ((CharStr[i] <> ' ') Or
        ((Ord(AttrStr[i]) and $70) <> (Ord(LastAttr) and $70))) Then
          Begin
          TmpStr := TmpStr + AnsiAttrDiff(Ord(LastAttr),Ord(AttrStr[i]));
          LastAttr := AttrStr[i];
          End;
        End;
      If CharStr[i] = '''' Then
        TmpStr := TmpStr + CharStr[i] + CharStr[i]
      Else
        TmpStr := TmpStr + CharStr[i];
      If Length(TmpStr) > 100 Then
        Begin
        WriteLn(TF, '  AvStr(''' + TmpStr + ''');');
        TmpStr := '';
        End;
      End;
    WriteLn(TF, '  AvStrLn(''' + TmpStr + ''');');
{    WriteLn(TF, StripTrail(TmpStr, ' ')); }
    If IoResult <> 0 Then;
    End;
  WriteLn(TF, '  End;');
  Close(TF);
  If IoResult <> 0 Then
    Write (#7);
  End;


Procedure SaveAvatar(FN: String; XL, YL, XH, YH: Byte; Action: Word);
  Var
    CY: Byte;
    CharStr: String;
    AttrStr: String;
    TmpStr: String;
    LastAttr: Char;
    LastChar: Char;
    CharCnt: Word;
    TF: Text;
    i: Word;
    Finished: Boolean;

  Begin
  AnsiWin.Select;
  Assign(TF, FN);
  ReWrite(TF);
  If IoResult <> 0 Then
    Write(#7, #7);
  LastAttr := #00;
  LastChar := #00;
  CharCnt := 0;
  Case Action of
    2: Write(TF, '');
    3: Write(TF,#12);
    End;
  For CY := YL TO YH Do
    Begin
    AnsiWin.wFastRead(XH + 1 - XL, CY, XL, CharStr);
    AnsiWin.wReadAttribute(XH + 1 - XL, CY, XL, AttrStr);
{    If ((Length(CharStr) = 80) and (CharStr[80] = ' ')) Then
      CharStr := Copy(CharStr,1,79); }
{    CharStr := StripTrail(CharStr,' '); }
    TmpStr := '';

    {remove trailing non-attr spaces}
    i := Length(CharStr);
    Finished := False;
    While (Not Finished) and (i > 0) Do
      Begin
      If (CharStr[i] = ' ') and ((Ord(AttrStr[i]) and $70) = 0) Then
        Begin
        CharStr[0] := Pred(CharStr[0]);
        End
      Else
        Finished := True;
      Dec(i);
      End;

    For i := 1 to length(CharStr) Do
      Begin
      If AttrStr[i] <> LastAttr Then
        Begin
        If ((CharStr[i] <> ' ') Or
        ((Ord(AttrStr[i]) and $70) <> (Ord(LastAttr) and $70))) Then
          Begin
          TmpStr := TmpStr + '' + AttrStr[i];
          LastAttr := AttrStr[i];
          End;
        End;
      If CharCnt = 0 Then
        Begin
        If (((i + 1) < Length(CharStr)) and (CharStr[i] = CharStr[i + 1]) and
        (CharStr[i] = CharStr[i + 2]) and (AttrStr[i] = AttrStr[i + 1]) and
        (AttrStr[i] = AttrStr[i + 2])) Then
          Begin
          CharCnt := 1;
          LastChar := CharStr[i];
          End
        Else
          TmpStr := TmpStr + CharStr[i];
        End
      Else
        Begin
        If ((CharStr[i] <> CharStr[i + 1]) or (AttrStr[i] <> AttrStr[i + 1])) Then
          Begin
          TmpStr := TmpStr + #$19 + LastChar + Chr(CharCnt + 1);
          CharCnt := 0;
          End
        Else
          Begin
          Inc(CharCnt);
          End;
        End;
      End;
    If CharCnt > 0 Then
      Begin
      TmpStr := TmpStr + #$19 + LastChar + Chr(CharCnt);
      CharCnt := 0;
      End;
    WriteLn(TF, TmpStr);
{    WriteLn(TF, StripTrail(TmpStr, ' ')); }
    If IoResult <> 0 Then;
    End;
  Close(TF);
  If IoResult <> 0 Then
    Write (#7);
  End;


Procedure SaveAscii(FN: String; XL, YL, XH, YH: Byte; Action: Word);
  Var
    CY: Byte;
    TmpStr: String;
    TF: Text;

  Begin
  AnsiWin.Select;
  Assign(TF, FN);
  ReWrite(TF);
  If IoResult <> 0 Then
    Write(#7, #7);
  Case Action of
    2,3: Write(TF, #12);
    End;
  For CY := YL TO YH Do
    Begin
    AnsiWin.wFastRead(XH + 1 - XL, CY, XL, TmpStr);
    WriteLn(TF, StripTrail(TmpStr, ' '));
    If IoResult <> 0 Then;
    End;
  Close(TF);
  If IoResult <> 0 Then
    Write (#7);
  End;


Procedure ReverseRect(XL, YL, XH, YH: Byte);
  Var
    RWidth: Word;
    i: Word;
    j: Word;
    TmpStr: String;

  Begin
  HideMouse;
  AnsiWin.Select;
  RWidth := XH + 1 - XL;
  For i := YL To YH Do
    Begin
    AnsiWin.wReadAttribute(RWidth, i, XL, TmpStr);
    For j := 1 to Length(TmpStr) Do
      TmpStr[j] := Chr((Ord(TmpStr[j]) shr 4) + ((Ord(TmpStr[j]) shl 4) and 255));
    AnsiWin.wWriteAttribute(TmpStr, i, XL);
    End;
  If MouseInstalled Then
    ShowMouse;
  End;


Function GetRect(Var XL: Byte; Var YL: Byte; Var XH: Byte; Var YH: Byte): Boolean;
  Var
    Finished: Boolean;
    Continue: Boolean;


  Begin
  Commands.AddCommand(ccSelect, 1, $0020, 0);   {Space}
  Commands.AddCommand(ccUser50, 1, Ord('l'), 0);
  Commands.AddCommand(ccUser50, 1, Ord('L'), 0);
  Continue := True;
  StatusWin.Select;
  GoToXy(1,1);
  Write('Move to upper left corner and press enter                                     ');
  AnsiWin.Select;
  Finished := False;
  While Not Finished Do
    Begin
    UpdateXY;
    AnsiWin.Select;
    Case Commands.GetCommand(Key) of
      ccQuit:
        Begin
        Finished := True;
        Continue := False;
        End;
      ccLeft: If WhereX > 1 Then
                GoToXy(WhereX - 1, WhereY)
              Else
                GoToXY(80, WhereY);
      ccUp: If WhereY > 1 Then
              GoToXy(WhereX, WhereY - 1);
      ccDown: If WhereY < 23 Then
              GoToXy(WhereX, WhereY + 1);
      ccRight: If WhereX < 80 Then
                 GoToXy(WhereX + 1, WhereY)
               Else
                 GoToXy(1, WhereY);
      ccHome: GoToXY(1, WhereY);
      ccEnd: GoToXY(80, WhereY);
      ccPageUp: GoToXY(WhereX, 1);
      ccPageDn: GoToXY(WhereX, 23);
      ccTab:
        Begin
        If WhereX < 72 Then
          GoToXY((WhereX + 8) and $f8, WhereY)
        Else
          GoToXY(79, WhereY);
        End;
      ccBackTab:
        Begin
        If WhereX > 8 Then
          GoToXY((WhereX - 1) and $f8, WhereY)
        Else
          GoToXY(1, WhereY);
        End;
      ccUser50:
        Begin
        Finished := True;
        XL := LXL;
        XH := LXH;
        YL := LYL;
        YH := LYH;
        StatusWin.Select;
        GoToXy(1,1);
        TextAttr := wColor;
        Write(BannerName);
        AnsiWin.Select;
        GetRect := True;
        Commands.AddCommand(ccChar, 1, $0020, 0);   {Space}
        Commands.AddCommand(ccChar, 1, Ord('l'), 0);
        Commands.AddCommand(ccChar, 1, Ord('L'), 0);
        Exit;
        End;
      ccMouseSel:
        Begin
        If ((MouseWhereXAbs = WhereX) and (MouseWhereYAbs - 2 = WhereY)) Then
          Begin
          Finished := True;
          XL := WhereX;
          YL := WhereY;
          End
        Else
          GoToXy(MouseWhereXAbs, MouseWhereYAbs - 2);
        End;
      ccSelect:
        Begin
        Finished := True;
        XL := WhereX;
        YL := WhereY;
        End;
      End;
    End;
  Commands.AddCommand(ccChar, 1, Ord('l'), 0);
  Commands.AddCommand(ccChar, 1, Ord('L'), 0);
  If Continue Then
    Begin
    StatusWin.Select;
    GoToXy(1,1);
    Write('Move to lower right corner and press enter                                   ');
    AnsiWin.Select;
    ReverseRect(XL, YL, XL, YL);
    Finished := False;
    While Not Finished Do
      Begin
      UpdateXY;
      AnsiWin.Select;
      TmpCmd := Commands.GetCommand(Key);
      ReverseRect(XL, YL, WhereX, WhereY);
      Case TmpCmd of
        ccQuit:
          Begin
          Finished := True;
          Continue := False;
          End;
        ccLeft: If WhereX > XL Then
                  GoToXy(WhereX - 1, WhereY);
        ccUp: If WhereY > YL Then
                GoToXy(WhereX, WhereY - 1);
        ccDown: If WhereY < 23 Then
                GoToXy(WhereX, WhereY + 1);
        ccRight: If WhereX < 80 Then
                   GoToXy(WhereX + 1, WhereY);
        ccEnd: GoToXY(80, WhereY);
        ccTab:
          Begin
          If WhereX < 72 Then
            GoToXY((WhereX + 8) and $f8, WhereY)
          Else
            GoToXY(79, WhereY);
          End;
        ccBackTab:
          Begin
          If ((WhereX - 1) and $f8) >= XL Then
            GoToXY((WhereX - 1) and $f8, WhereY)
          Else
            GoToXY(XL, WhereY);
          End;
        ccPageDn: GoToXY(WhereX, 23);
        ccMouseSel:
          Begin
          If ((MouseWhereXAbs = WhereX) and (MouseWhereYAbs - 2 = WhereY)) Then
            Begin
            Finished := True;
            XH := WhereX;
            YH := WhereY;
            LXL := XL;
            LXH := XH;
            LYL := YL;
            LYH := YH;
            End
          Else
            GoToXy(MouseWhereXAbs, MouseWhereYAbs - 2);
          End;
        ccSelect:
          Begin
          Finished := True;
          XH := WhereX;
          YH := WhereY;
          LXL := XL;
          LXH := XH;
          LYL := YL;
          LYH := YH;
          End;
        End;
      ReverseRect(XL, YL, WhereX, WhereY);
      End;
    End;
  ReverseRect(XL, YL, WhereX, WhereY);
  StatusWin.Select;
  GoToXY(1,1);
  TextAttr := wColor;
  Write(BannerName);
  AnsiWin.Select;
  GetRect := Continue;
  Commands.AddCommand(ccChar, 1, $0020, 0);   {Space}
  End;


Procedure SaveFile;
  Var
    FStr: NameStr;
    EStr: ExtStr;
    DoAll: Boolean;
    DoSave: Boolean;
    XL, YL, XH, YH: Byte;
    Action: Word;

  Begin
  FSplit(CurrFile, TmpStr, FStr, EStr);
  TmpStr := TmpStr + FStr;
  If MKEditProc('FileName: ', True, True, 55, TmpStr) Then
    Begin
    FSplit(TmpStr, TmpStr2, FStr, EStr);
    DoAll := Pos('.', TmpStr) = 0;
    If DoAll Then
      Begin
      If ((FileExist(TmpStr + '.AVT')) or (FileExist(TmpStr + '.ANS'))
      or (FileExist(TmpStr + '.ASC'))) Then
        DoSave := DoYesNo('[ Overwrite File ]', False) = 1
      Else
        DoSave := True;
      End
    Else
      Begin
      If FileExist(TmpStr) Then
        DoSave := DoYesNo('[ Overwrite File ]', False) = 1
      Else
        DoSave := True;
      End;
    If DoSave Then
      DoSave := GetRect(XL, YL, XH, YH);
    If DoSave Then
      Begin
      Action := GetActionCmd;
      If Action = 0 Then
        DoSave := False;
      End;
    If DoSave Then
      Begin
      HideMouse;
      If DoAll Then
        Begin
        SaveAscii(TmpStr + '.ASC', XL, YL, XH, YH, Action);
        SaveAnsi(TmpStr + '.ANS', XL, YL, XH, YH, Action);
        SaveAvatar(TmpStr + '.AVT', XL, YL, XH, YH, Action);
        End
      Else
        Begin
        If EStr = '.AVT' Then
          SaveAvatar(TmpStr, XL, YL, XH, YH, Action)
        Else If EStr = '.ANS' Then
          SaveAnsi(TmpStr, XL, YL, XH, YH, Action)
        Else If ((EStr = '.PAS') or (EStr = '.INC')) Then
          SavePascal(TmpStr, XL, YL, XH, YH, Action)
        Else
          SaveAscii(TmpStr, XL, YL, XH, YH, Action);
        End;
      If MouseInstalled Then
        ShowMouse;
      End;
    End;
  End;


Procedure DoDouble;
  Var
    xx: Integer;
    yy: Integer;
    AStr: String[5];
    CStr: String[5];

  Begin
  xx := 39;
  AnsiWin.Select;
  While xx >= 0 Do
    Begin
    yy := 11;
    While yy >= 0 Do
      Begin
      AnsiWin.wReadAttribute(1, yy + 1, xx + 1, AStr);
      AnsiWin.WFastRead(1, yy + 1, xx + 1, CStr);
      AnsiWin.wWriteAttribute(AStr, yy * 2 + 2, xx * 2 + 2);
      AnsiWin.wWriteAttribute(AStr, yy * 2 + 1, xx * 2 + 2);
      AnsiWin.wWriteAttribute(AStr, yy * 2 + 2, xx * 2 + 1);
      AnsiWin.wWriteAttribute(AStr, yy * 2 + 1, xx * 2 + 1);
      AnsiWin.wFastText(CStr, yy * 2 + 2, xx * 2 + 2);
      AnsiWin.wFastText(CStr, yy * 2 + 1, xx * 2 + 2);
      AnsiWin.wFastText(CStr, yy * 2 + 2, xx * 2 + 1);
      AnsiWin.wFastText(CStr, yy * 2 + 1, xx * 2 + 1);
      Dec(yy);
      End;
    Dec(xx);
    End;
  End;

Procedure DoClear;
  Var
    XL, YL, XH, YH: Byte;
    TmpStr: String;
    i: Word;
    TA: Byte;

  Begin
  If GetRect(XL, YL, XH, YH) Then
    Begin
    If (DoYesNo('[ Clear Area ]', True) = 1) Then
      Begin
      HideMouse;
      AnsiWin.Select;
      TA := TextAttr;
      TmpStr := PadRight('', ' ', XH + 1 - xl);
      For i := yl to yh Do
        AnsiWin.wFastWrite(TmpStr, i, XL, ta);
      If MouseInstalled Then
        ShowMouse;
      End;
    End;
  End;


Procedure DoAttr;
  Var
    XL, YL, XH, YH: Byte;
    i: Word;
    TA: Byte;

  Begin
  If GetRect(XL, YL, XH, YH) Then
    Begin
    HideMouse;
    AnsiWin.Select;
    TA := ColorPick(25, 6, TextAttr, '[ Attribute Fill ]');
    AnsiWin.Select;
    For i := yl to yh Do
      AnsiWin.wChangeAttribute(xh + 1 - xl, i, XL, ta);
    If MouseInstalled Then
      ShowMouse;
    End;
  End;


Procedure DoEnclose;
  Var
    XL, XH, YL, YH: Byte;
    FType: Word;
    TA: Byte;
    TmpStr: String;
    i: Word;

  Begin
  HideMouse;
  If GetRect(XL, YL, XH, YH) Then
    Begin
    AnsiWin.Select;
    TA := TextAttr;
    Case CurrSet of
      1..4: FType := CurrSet;
      Else
        FType := 1;
      End;
    TmpStr := ExtChars[FType][1];
    AnsiWin.wFastWrite(TmpStr, YL, XL, ta);
    TmpStr := ExtChars[FType][2];
    AnsiWin.wFastWrite(TmpStr, YL, XH, ta);
    TmpStr := ExtChars[FType][3];
    AnsiWin.wFastWrite(TmpStr, YH, XL, ta);
    TmpStr := ExtChars[FType][4];
    AnsiWin.wFastWrite(TmpStr, YH, XH, ta);
    TmpStr := PadRight('',ExtChars[FType][5], (XH - 1) - XL);
    AnsiWin.wFastWrite(TmpStr, YL, XL + 1, ta);
    AnsiWin.wFastWrite(TmpStr, YH, XL + 1, ta);
    TmpStr := ExtChars[FType][6];
    i := YL + 1;
    While i < YH Do
      Begin
      AnsiWin.wFastWrite(TmpStr, i, XL, ta);
      AnsiWin.wFastWrite(TmpSTr, i, XH, ta);
      Inc(i);
      End;
    End;
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure RestoreScrn(XL, YL, XH, YH, CX, CY: Byte; Moving: Boolean; Var OScrn: SSaveRec);
  Var
    i, j: Word;

  Begin
  HideMouse;
  AnsiWin.Select;
  For j := CY To (CY + YH - YL) Do
    Begin
    For i := CX To (CX + XH - XL) Do
      Begin
      If i <= 80 Then
        Begin
        If ((Moving) and (i >= XL) and (i <= XH) and (j >= YL) and (j <= YH)) Then
          AnsiWin.wFastWrite(' ',j,i,TextAttr)
        Else
          AnsiWin.wFastWrite(OScrn.SChar[j][i],j,i, Ord(OScrn.SAttr[j][i]))
        End;
      End
    End;
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure ShowBlock(XL, YL, XH, YH, CX, CY: Byte; Var MRect: SSaveRec);
  Var
    i, j: Word;
    TA: Byte;

  Begin
  HideMouse;
  AnsiWin.Select;
  For j := CY To (CY + YH - YL) Do
    Begin
    For i := CX To (CX + XH - XL) Do
      Begin
      If i <= 80 Then
        Begin
        TA := Ord(MRect.SAttr[j + 1 - CY][i + 1 - CX]);
        TA := ((TA shr 4) Or (TA shl 4)) and $ff;
        AnsiWin.wFastWrite(MRect.SChar[j + 1 - CY][i + 1 - CX],j,i, TA);
        End;
      End
    End;
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure DoMoveCopy(Moving: Boolean);
  Var
    XL, YL, XH, YH: Byte;
    i: Word;
    TA: Byte;
    OScrn: ^SSaveRec;
    MRect: ^SSaveRec;
    MWidth, MHeight: Word;
    Finished: Boolean;

  Begin
  New(OScrn);
  New(MRect);
  If ((OScrn <> Nil) and (MRect <> Nil)) Then
    Begin
    If GetRect(XL, YL, XH, YH) Then
      Begin
      HideMouse;
      AnsiWin.Select;
      MWidth := XH + 1 - XL;
      MHeight := YH + 1 - YL;
      For i := 1 to 23 Do
        Begin
        AnsiWin.wFastRead(80, i, 1, OScrn^.SChar[i]);
        AnsiWin.wReadAttribute(80,i,1, OScrn^.SAttr[i]);
        End;
      For i := YL to YH Do
        Begin
        AnsiWin.wFastRead(MWidth, i, XL, MRect^.SChar[i + 1 - YL]);
        AnsiWin.wReadAttribute(MWidth, i, XL, MRect^.SAttr[i + 1 - YL]);
        End;
      GoToXy(XL, YL);
      If MouseInstalled Then
        ShowMouse;
      Finished := False;
      While Not Finished Do
        Begin
        ShowBlock(XL, YL, XH, YH, WhereX, WhereY, MRect^);
        UpdateXY;
        AnsiWin.Select;
        TmpCmd := Commands.GetCommand(Key);
        RestoreScrn(XL, YL, XH, YH, WhereX, WhereY, Moving, OScrn^);
        Case TmpCmd of
          ccQuit:
            Begin
            RestoreScrn(XL, YL, XH, YH, WhereX, WhereY, False, OScrn^);
            RestoreScrn(XL, YL, XH, YH, XL, YL, False, OScrn^);
            Finished := True;
            End;
          ccLeft:
            Begin
            If WhereX > 1 Then
              GoToXy(WhereX - 1, WhereY)
            Else
              GoToXY(80, WhereY);
            End;
          ccUp:
            Begin
            If WhereY > 1 Then
              GoToXy(WhereX, WhereY - 1);
            End;
          ccDown:
            Begin
            If WhereY < 23 Then
              GoToXy(WhereX, WhereY + 1);
            End;
          ccTab:
            Begin
            If WhereX < 72 Then
              GoToXY((WhereX + 8) and $f8, WhereY)
            Else
              GoToXY(79, WhereY);
            End;
          ccBackTab:
            Begin
            If WhereX > 8 Then
              GoToXY((WhereX - 1) and $f8, WhereY)
            Else
              GoToXY(1, WhereY);
            End;
          ccRight:
            Begin
            If WhereX < 80 Then
              GoToXy(WhereX + 1, WhereY)
            Else
              GoToXy(1, WhereY);
            End;
          ccHome: GoToXY(1, WhereY);
          ccEnd: GoToXY(80, WhereY);
          ccPageUp: GoToXY(WhereX, 1);
          ccPageDn: GoToXY(WhereX, 23);
          ccMouseSel:
            Begin
            If ((MouseWhereXAbs = WhereX) and (MouseWhereYAbs - 2 = WhereY)) Then
              Begin
              Finished := True;
              ShowBlock(XL, YL, XH, YH, WhereX, WhereY, MRect^);
              ReverseRect(WhereX, WhereY, MWidth + WhereX - 1,
              MHeight + WhereY - 1);
              LXL := WhereX;
              LYL := WhereY;
              LXH := LXL + MWidth - 1;
              LYH := LYL + MHeight - 1;
              End
            Else
             GoToXy(MouseWhereXAbs, MouseWhereYAbs - 2);
            End;
          ccSelect:
            Begin
            Finished := True;
            ShowBlock(XL, YL, XH, YH, WhereX, WhereY, MRect^);
            ReverseRect(WhereX, WhereY, MWidth + WhereX - 1,
            MHeight + WhereY - 1);
            LXL := WhereX;
            LYL := WhereY;
            LXH := LXL + MWidth - 1;
            LYH := LYL + MHeight - 1;
            End;
          End;
        End;
      End;
    Dispose(MRect);
    Dispose(OScrn);
    End
  Else
    Begin
    If OScrn <> Nil Then
      Dispose(OScrn);
    If MRect <> Nil Then
      Dispose(MRect);
    End;
  End;


Function IsWild(St: String): Boolean;
  Begin
  IsWild := ((Pos('?',St) > 0) or (Pos('*',St) > 0));
  End;


Procedure GetLoadFile;
  Var
    TmpName: String;
    FStr: NameStr;
    EStr: ExtStr;

  Begin
  TmpName := CurrFile;
  FSplit(CurrFile, TmpName, FStr, EStr);
  TmpName := WithBackSlash(TmpName) + '*.A??';
  If MKEditProc('FileName: ', True, True, 55, TmpName) Then
    Begin
    If IsWild(TmpName) Then
      TmpName := GetPickFileName(TmpName);
    If Length(TmpName) > 0 Then
      Begin
      If FileExist(TmpName) Then
        Begin
        CurrFile := TmpName;
        DisplayAnsiWindow(CurrFile)
        End;
      End;
    End;
  End;


Procedure InsertLine;
  Var
    i: Word;
    CStr: String;
    AStr: String;
    ta: Byte;

  Begin
  AnsiWin.Select;
  ta := TextAttr;
  HideMouse;
  i := 25 - 2;
  While i > WhereY Do
    Begin
    AnsiWin.wReadAttribute(80, i - 1, 1, AStr);
    AnsiWin.wFastRead(80, i - 1, 1, CStr);
    AnsiWin.wFastText(CStr, i, 1);
    AnsiWin.wWriteAttribute(AStr, i, 1);
    Dec(i);
    End;
  CStr := PadRight('', ' ', 80);
  AnsiWin.wFastWrite(CStr, WhereY, 1, ta);
  If MouseInstalled Then
    HideMouse;
  End;


Procedure DeleteLine;
  Var
    i: Word;
    CStr: String;
    AStr: String;

  Begin
  AnsiWin.Select;
  HideMouse;
  i := WhereY;
  While i < 25 Do
    Begin
    AnsiWin.wReadAttribute(80, i + 1, 1, AStr);
    AnsiWin.wFastRead(80, i + 1, 1, CStr);
    AnsiWin.wFastText(CStr, i, 1);
    AnsiWin.wWriteAttribute(AStr, i, 1);
    Inc(i);
    End;
  CStr := PadRight('', ' ', 80);
  AnsiWin.wFastText(CStr, 25 - 2, 1);
  If MouseInstalled Then
    HideMouse;
  End;


Procedure DeleteChar;
  Var
    AStr: String;
    CStr: String;

  Begin
  AnsiWin.Select;
  HideMouse;
  AnsiWin.wReadAttribute(80 - WhereX, WhereY, WhereX + 1, AStr);
  AnsiWin.wFastRead(80 - WhereX, WhereY, WhereX + 1, CStr);
  CStr := CStr + ' ';
  AStr := AStr + Chr(TextAttr);
  AnsiWin.wFastText(CStr, WhereY, WhereX);
  AnsiWin.wWriteAttribute(AStr, WhereY, WhereX);
  If MouseInstalled Then
    HideMouse;
  End;


Procedure InsertStr(Str: String);
  Var
    AStr: String;
    CStr: String;
    L: Word;

  Begin
  l := 81 - WhereX;
  If Length(Str) < l Then
    l := Length(Str);
  AnsiWin.Select;
  HideMouse;
  AnsiWin.wReadAttribute(81 - (WhereX + l), WhereY, WhereX, AStr);
  AnsiWin.wFastRead(81 - (WhereX + l), WhereY, WhereX, CStr);
  AnsiWin.wFastText(CStr, WhereY, WhereX + l);
  AnsiWin.wWriteAttribute(AStr, WhereY, WhereX + l);
  Write(Copy(Str,1,l));
  If MouseInstalled Then
    HideMouse;
  End;


Procedure WriteStr(Str: String);
  Begin
  HideMouse;
  If InsertMode Then
    InsertStr(Str)
  Else
    Write(Str);
  If MouseInstalled Then
    ShowMouse;
  End;


Procedure CmdProcess(Cmd: Word; Var Finished: Boolean; Var Key: Word);
  Var
    Tmp: Word;
    TmpName: String;
    P: Pointer;

  Begin
  Case Cmd of
    ccLeft:
      Begin
      PutDrawChar(WhereX, WhereY, 1);
      If WhereX > 1 Then
        GoToXy(WhereX - 1, WhereY)
      Else
        GoToXY(80, WhereY);
      End;
    ccUp:
      Begin
      PutDrawChar(WhereX, WhereY, 4);
      If WhereY > 1 Then
        GoToXy(WhereX, WhereY - 1);
      End;
    ccDown:
      Begin
      PutDrawChar(WhereX, WhereY, 3);
      If WhereY < 23 Then
        GoToXy(WhereX, WhereY + 1);
      End;
    ccRight:
      Begin
      PutDrawChar(WhereX, WhereY, 2);
      If WhereX < 80 Then
        GoToXy(WhereX + 1, WhereY)
      Else
        GoToXy(1, WhereY);
      End;
    ccHome: GoToXY(1, WhereY);
    ccEnd: GoToXY(80, WhereY);
    ccDel: DeleteChar;
    ccIns:
      Begin
      InsertMode := Not InsertMode;
      UpdateIns;
      End;
    ccTab:
      Begin
      If WhereX < 72 Then
        GoToXY((WhereX + 8) and $f8, WhereY)
      Else
        GoToXY(79, WhereY);
      End;
    ccBackTab:
      Begin
      If WhereX > 8 Then
        GoToXY((WhereX - 1) and $f8, WhereY)
      Else
        GoToXY(1, WhereY);
      End;
    ccSelect:
      Begin
      If WhereY < 23 Then
        GoToXY(1, WhereY + 1)
      Else
        GoToXY(1, WhereY);
      End;
    ccPageUp: GoToXY(WhereX, 1);
    ccPageDn: GoToXY(WhereX, 23);
    ccBack:
      Begin
      If InsertMode Then
        Begin
        Write(#8);
        DeleteChar;
        End
      Else
        Write(#8' '#8);
      End;
    ccSaveFile: SaveFile;
    ccHelp: DisplayHelp(1);
    ccMouseSel:
      Begin
      GoToXy(MouseWhereXAbs, MouseWhereYAbs - 2);
      End;
    ccUser1:
      Begin
      TextAttr := ColorPick(25, 6, TextAttr, '[ Pick Color ]');
      AnsiWin.SetTextAttr(TextAttr, TextAttr);
      UpDateColor;
      End;
    ccUser2:
      Begin
      HideMouse;
      TextAttr := ReadAttrAtCursor;
      AnsiWin.SetTextAttr(TextAttr, TextAttr);
      UpdateColor;
      If MouseInstalled Then
        ShowMouse;
      End;
    ccUser3:
      Begin
      TextAttr := TextAttr Xor $80;
      AnsiWin.SetTextAttr(TextAttr, TextAttr);
      UpdateColor;
      End;
    ccUser4: GetLoadFile;
    ccUser5: DoClear;
    ccUser6: DoAttr;
    ccUser7: DoMoveCopy(True);
    ccUser8: DoMoveCopy(False);
    ccUser9:
      Begin
      TextAttr := ((TextAttr shl 4) Or (TextAttr shr 4)) and $ff;
      AnsiWin.SetTextAttr(TextAttr, TextAttr);
      UpdateColor;
      End;
    ccUser10:
      Begin
      If SaveWindow(1,1, ScreenWidth, ScreenHeight, True, P) Then
        Begin
        HideMouse;
        Window(1,1,ScreenWidth, ScreenHeight);
        ClrScr;
        SetCursorType(CT);
        DisableEventHandling;
        If ExecDosSwap('', True, nil, 'MKDraw.$$$') <> 0 Then
          Write(#7);
        SetCursorType(cuBlock);
        EnableEventHandling;
        RestoreWindow(1,1, ScreenWidth, ScreenHeight, True, P);
        If MouseInstalled Then
          ShowMouse;
        End;
      End;
    ccUser11: WriteStr(ExtChars[CurrSet][1]);
    ccUser12: WriteStr(ExtChars[CurrSet][2]);
    ccUser13: WriteStr(ExtChars[CurrSet][3]);
    ccUser14: WriteStr(ExtChars[CurrSet][4]);
    ccUser15: WriteStr(ExtChars[CurrSet][5]);
    ccUser16: WriteStr(ExtChars[CurrSet][6]);
    ccUser17: WriteStr(ExtChars[CurrSet][7]);
    ccUser18: WriteStr(ExtChars[CurrSet][8]);
    ccUser19: WriteStr(ExtChars[CurrSet][9]);
    ccUser20: WriteStr(ExtChars[CurrSet][10]);
    ccUser21:
      Begin
      CurrSet := 1;
      FillInChars;
      End;
    ccUser22:
      Begin
      CurrSet := 2;
      FillInChars;
      End;
    ccUser23:
      Begin
      CurrSet := 3;
      FillInChars;
      End;
    ccUser24:
      Begin
      CurrSet := 4;
      FillInChars;
      End;
    ccUser25:
      Begin
      CurrSet := 5;
      FillInChars;
      End;
    ccUser26:
      Begin
      CurrSet := 6;
      FillInChars;
      End;
    ccUser27:
      Begin
      CurrSet := 7;
      FillInChars;
      End;
    ccUser28:
      Begin
      CurrSet := 8;
      FillInChars;
      End;
    ccUser29:
      Begin
      CurrSet := 9;
      FillInChars;
      End;
    ccUser30:
      Begin
      CurrSet := 10;
      FillInChars;
      End;
    ccUser31:
      Begin
      CurrSet := 11;
      FillInChars;
      End;
    ccUser32:
      Begin
      CurrSet := 12;
      FillInChars;
      End;
    ccUser33:
      Begin
      CurrSet := 13;
      FillInChars;
      End;
    ccUser34:
      Begin
      CurrSet := 14;
      FillInChars;
      End;
    ccUser35:
      Begin
      CurrSet := 15;
      FillInChars;
      End;
    ccQuit:
      Begin
      Tmp := GetMenuCmd;
      If Tmp <> ccNone Then
        CmdProcess(Tmp, Finished, Key);
      End;
    ccDone: Finished := DoYesNo('[ Exit MKDraw ]', True) = 1;
    ccError: Finished := True;
    ccUser40:
      Begin
      TmpStr := GetBbsStr;
      If Length(TmpStr) > 0 Then
        Begin
        HideMouse;
        WriteStr(TmpStr);
        If MouseInstalled Then
          ShowMouse;
        End;
      End;
    ccUser41:
      Begin
      TextAttr := TextAttr Xor $08;
      AnsiWin.SetTextAttr(TextAttr, TextAttr);
      UpdateColor;
      End;
    ccUser42:
      Begin
      GetPickChar;
      FillInChars;
      End;
    ccUser43: InsertLine;
    ccUser44: DeleteLine;
    ccUser45:
      Begin
      GetDrawSet(Drawset);
      UpdateDraw;
      End;
    ccUser46: DoEnclose;
    ccUser47: DoDouble;
    ccChar: WriteStr(Char(Lo(Key)));
    End;
  End;


Procedure AnsiWindowProcess;
Var
  Finished: Boolean;
  Cmd: Word;

  Begin
  Finished := False;
  Repeat
    UpDateXY;
    AnsiWin.Select;
    Cmd := Commands.GetCommand(Key);
    CmdProcess(Cmd, Finished, Key);
    AnsiWin.Select;
    Until Finished;
  End;


Procedure InitStatusWin;
  Begin
  If StatusWin.InitCustom(1,1,80,2, ESColors, wClear + wSaveContents) Then
    Begin
    StatusWin.Draw;
    TextAttr := WColor;
    ClrScr;
    TextAttr := wColor;
    WriteLn(BannerName);
    Write  ('  (  1,  1)  Color  Ovr  Set  1    1=  2=  3=  4=  5=  6=  7=  8=  9=  10=  ');
    FillInChars;
    End
  Else
    Begin
    Write(#7, #7, #7, #7);
    Halt(16);
    End;
  End;


Procedure FinishStatusWin;
  Begin
  StatusWin.Select;
  StatusWin.Erase;
  StatusWin.Done;
  End;


Procedure InitAnsiWindow;
  Begin
  If AnsiWin.InitCustom(1,3,80,25, ESColors, wClear + wSaveContents) Then
    Begin
    AnsiWin.Draw;
    TextAttr := Cyan;
    ClrScr;
    End
  Else
    Begin
    Write(#7, #7, #7, #7);
    Halt(15);
    End;
  FillChar(KeySet, SizeOf(KeySet), 0);
  Commands.Init(@KeySet, KeyMax);
  Commands.cpOptionsOn(cpCtrlsAreChars);
  If MouseInstalled Then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    Commands.cpOptionsOn(cpEnableMouse);
    Commands.AddCommand(ccQuit, 1, MouseRt, 0);
    Commands.AddCommand(ccMouseSel, 1, MouseLft, 0);
    End;
  Commands.AddCommand(ccSelect, 1, $000d, 0);   {Enter}
  Commands.AddCommand(ccQuit,   1, $001b, 0);   {Esc}
  Commands.AddCommand(ccUp,     1, $4800, 0);   {Up}
  Commands.AddCommand(ccDown,   1, $5000, 0);   {Down}
  Commands.AddCommand(ccLeft,   1, $4b00, 0);   {Left}
  Commands.AddCommand(ccRight,  1, $4d00, 0);   {Right}
  Commands.AddCommand(ccHome,   1, $4700, 0);   {Home}
  Commands.AddCommand(ccEnd,    1, $4f00, 0);   {End}
  Commands.AddCommand(ccDel,    1, $5300, 0);   {Del}
  Commands.AddCommand(ccIns,    1, $5200, 0);   {Ins}
  Commands.AddCommand(ccPageUp, 1, $4900, 0);   {PgDn}
  Commands.AddCommand(ccPageDn, 1, $5100, 0);   {PgUp}
  Commands.AddCommand(ccBack,   1, $0008, 0);   {BkSpc}
  Commands.AddCommand(ccDel,    1, $5300, 0);   {Del}
  Commands.AddCommand(ccIns,    1, $5200, 0);   {Ins}
  Commands.AddCommand(ccUser11, 1, $3b00, 0);   {F1}
  Commands.AddCommand(ccUser12, 1, $3c00, 0);   {F2}
  Commands.AddCommand(ccUser13, 1, $3d00, 0);   {F3}
  Commands.AddCommand(ccUser14, 1, $3e00, 0);   {F4}
  Commands.AddCommand(ccUser15, 1, $3f00, 0);   {F5}
  Commands.AddCommand(ccUser16, 1, $4000, 0);   {F6}
  Commands.AddCommand(ccUser17, 1, $4100, 0);   {F7}
  Commands.AddCommand(ccUser18, 1, $4200, 0);   {F8}
  Commands.AddCommand(ccUser19, 1, $4300, 0);   {F9}
  Commands.AddCommand(ccUser20, 1, $4400, 0);   {F10}
  Commands.AddCommand(ccUser21, 1, $6800, 0);   {Alt-F1}
  Commands.AddCommand(ccUser22, 1, $6900, 0);   {Alt-F2}
  Commands.AddCommand(ccUser23, 1, $6a00, 0);   {Alt-F3}
  Commands.AddCommand(ccUser24, 1, $6b00, 0);   {Alt-F4}
  Commands.AddCommand(ccUser25, 1, $6c00, 0);   {Alt-F5}
  Commands.AddCommand(ccUser26, 1, $6d00, 0);   {Alt-F6}
  Commands.AddCommand(ccUser27, 1, $6e00, 0);   {Alt-F7}
  Commands.AddCommand(ccUser28, 1, $6f00, 0);   {Alt-F8}
  Commands.AddCommand(ccUser29, 1, $7000, 0);   {Alt-F9}
  Commands.AddCommand(ccUser30, 1, $7100, 0);   {Alt-F10}
  Commands.AddCommand(ccUser31, 1, $5e00, 0);   {Ctl-F1}
  Commands.AddCommand(ccUser32, 1, $5f00, 0);   {Ctl-F2}
  Commands.AddCommand(ccUser33, 1, $6000, 0);   {Ctl-F3}
  Commands.AddCommand(ccUser34, 1, $6100, 0);   {Ctl-F4}
  Commands.AddCommand(ccUser35, 1, $6200, 0);   {Ctl-F5}
  Commands.AddCommand(ccSaveFile, 1, $1f00, 0); {Alt-S Save}
  Commands.AddCommand(ccDone,   1, $2d00, 0);   {Alt-X Exit}
  Commands.AddCommand(ccUser1,  1, $1e00, 0);   {Alt-A Color Attribute}
  Commands.AddCommand(ccUser2,  1, $1600, 0);   {Alt-U pick up color}
  Commands.AddCommand(ccUser3,  1, $3000, 0);   {Alt-B toggle blinking}
  Commands.AddCommand(ccUser4,  1, $2600, 0);   {Alt-L Load file}
  Commands.AddCommand(ccUser5,  1, $2c00, 0);   {Alt-Z Zap/Clear area}
  Commands.AddCommand(ccUser6,  1, $2100, 0);   {Alt-F Attribute Fill}
  Commands.AddCommand(ccUser7,  1, $3200, 0);   {Alt-M Move block}
  Commands.AddCommand(ccUser8,  1, $2e00, 0);   {Alt-C Copy block}
  Commands.AddCommand(ccUser9,  1, $1300, 0);   {Alt-R Reverse attribute}
  Commands.AddCommand(ccUser10, 1, $2400, 0);   {Alt-J Jump to Dos}
  Commands.AddCommand(ccUser40, 1, $1900, 0);   {Alt-P Pick Bbs Code}
  Commands.AddCommand(ccUser41, 1, $1700, 0);   {Alt-I Intensity}
  Commands.AddCommand(ccUser42, 1, $2200, 0);   {Alt-G Get char set}
  Commands.AddCommand(ccUser43, 1, $2f00, 0);   {Alt-V insert line}
  Commands.AddCommand(ccUser44, 1, $1500, 0);   {Alt-Y delete line}
  Commands.AddCommand(ccUser45, 1, $2000, 0);   {Alt-D draw mode}
  Commands.AddCommand(ccUser46, 1, $1200, 0);   {Alt-E enclose}
  Commands.AddCommand(ccUser47, 1, $1100, 0);   {Alt-W double}
  Commands.AddCommand(ccTab,    1, $0009, 0);   {Tab}
  Commands.AddCommand(ccBackTab,1, $0f00, 0);   {BackTab}
  Commands.AddCommand(ccHelp,   1, $2300, 0);   {Alt-H Help}
  End;


Procedure FinishAnsiWindow;
  Begin
  Commands.Done;
  AnsiWin.Erase;
  AnsiWin.Done;
  End;


Begin
TA := TextAttr;
DetectMultitasking := True;
ReInitCrt;
CT := ClassifyCursorType;
If Not ((CT = cuNormal) or (CT = cuFat) or (CT = cuBlock)) Then
  CT := cuNormal;
InitCustCodes;
LoadExtChars;
CurrSet := 1;
InsertMode := False;
DrawSet := 5;
LXL := 1;
LYL := 1;
LXH := 1;
LYH := 1;
InitAnsiWindow;
InitStatusWin;
SetCursorType(cuBlock);
If ParamCount > 0 Then
  CurrFile := FExpand(ParamStr(1))
Else
  Begin
  GetDir(0, CurrFile);
  AddBackSlash(CurrFile);
  CurrFile := CurrFile + '*.A*';
  End;
If IsWild(CurrFile) Then
  CurrFile := GetPickFileName(CurrFile);
If FileExist(CurrFile) Then
  DisplayAnsiWindow(CurrFile);
UpdateColor;
AnsiWindowProcess;
FinishStatusWin;
FinishAnsiWindow;
DoneCustCodes;
SetCursorType(CT);
TextAttr := TA;
End.
