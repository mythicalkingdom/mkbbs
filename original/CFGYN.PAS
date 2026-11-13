{$V-}

Unit CfgYN;

{$I OPDEFINE.INC}
{$I MKB.Def}

Interface

Function DoYesNo(Hdr: String; DefChoice: Boolean): Word;  {0=escape 1=yes 2=no}
Procedure ProcessBox(DStr: String; HdrMsg: String);
Procedure EndProcessBox;
Procedure MsgBox(DStr: String);

Implementation

Uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,  OpMouse,
  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,
  OpEntry, OpPick, MKString, CfgGlob;


Var
  YNPick: PickList;
  Status: Word;
  MsgWin: StackWindowPtr;
  SaveCursor: CursorType;

{$F+}
Procedure YNStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item of
    1: IString := '        Yes';
    2: IString := '        No';
    Else
      IString := '';
    End;
  End;



Function DoYesNo(Hdr: String; DefChoice: Boolean): Word;
  Var
    Tmp: Word;

  Begin
  If Not YNPick.InitCustom(30,10,49,14,ESColors,
    wBordered+wClear+wUserContents,
    20, 2, YNStr,PickVertical, SingleChoice) Then
    Halt;
  YNPick.wFrame.SetFrameType(Frame1);
  YNPick.wFrame.AddShadow(shBR, shSeeThru);
  YNPick.wFrame.AddHeaderColor(Hdr, heTC, WhiteOnBlue, BlackOnLtGray);
  YNPick.GetCommandProcessor^.AddCommand(ccUser0, 1, Ord('Y'),0);
  YNPick.GetCommandProcessor^.AddCommand(ccUser1, 1, Ord('y'), 0);
  YNPick.GetCommandProcessor^.AddCommand(ccUser2, 1, Ord('N'), 0);
  YNPick.GetCommandProcessor^.AddCommand(ccUser3, 1, Ord('n'), 0);
  If DefChoice Then
    YNPick.SetInitialChoice(1)
  Else
    YNPick.SetInitialChoice(2);
  YNPick.Process;
  YNPick.Erase;
  Case YNPick.GetLastCommand of
    ccSelect: DoYesNo := YNPick.GetLastChoice;
    ccUser0, ccUser1: DoYesNo := 1;
    ccUser2, ccUser3: DoYesNo := 2;
    Else
      DoYesNo := 0;
    End;
  YNPick.Done;
  End;


Procedure ProcessBox(DStr: String; HdrMsg: String);
  Var
    Ch: Char;
    NPad: Word;

  Begin
  New(MsgWin, InitCustom(10,12,70,12, ESColors, wClear + wSaveContents +
    wBordered));
  If MsgWin <> nil Then
    Begin
    MsgWin^.wFrame.SetFrameType(Frame1);
    MsgWin^.wFrame.AddShadow(shBR, shSeeThru);
    MsgWin^.wFrame.AddHeaderColor(HdrMsg, heTC, WhiteOnBlue, BlackOnLtGray);
    MsgWin^.Draw;
    DStr := Copy(DStr,1,60);
    NPad := ((62 - Length(DStr)) Div 2) + Length(DStr);
    DStr := PadLeft(DStr,' ',NPad);
    Write(DStr);
    End;
  SaveCursor := ClassifyCursorType;
  SetCursorType(cuHidden);
  End;


Procedure EndProcessBox;
  Begin
  If MsgWin <> nil Then
    Begin
    MsgWin^.Erase;
    Dispose(MsgWin, Done);
    End;
  SetCursorType(SaveCursor);
  End;



Procedure MsgBox(DStr: String);
  Var
    MsgWin: StackWindowPtr;
    Ch: Char;
    NPad: Word;

  Begin
  ProcessBox(DStr, '[ Press Any Key to Continue ]');
  If MsgWin <> nil Then
    Begin
    Ch := ReadKey;
    If ch = #0 Then
      Ch := ReadKey;
    End;
  EndProcessBox;
  End;



End.
