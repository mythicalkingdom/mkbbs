Unit CfgNet;


{$I Opdefine.Inc}

Interface

Uses OpEntry, MKCfgAbs;

Procedure DoCfgNet(SysNo: Word);
Procedure GetNet(SysNo: Word; Var ESP: EntryScreenPtr; ScreenNo: Word);



Implementation

Uses OpCrt, OpPick, OpColor, OpFrame, OpWindow, OpField, OpMouse,
  CfgGlob, MKGlobT;

Var
  NetPick: PickList;

{$F+}
Procedure NetStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := 'Network - ' + Char(Item + Ord('A') - 1);
  End;
{$F-}


Procedure GetNet(SysNo: Word; Var ESP: EntryScreenPtr; ScreenNo: Word);

  Var
    Temp: Word;

  Const
    Wait = 100;

  Begin
  Delay(Wait);
  ESP^.PositionCursorAt(ESP^.FindField(ScreenNo));
  HideMouse;
  Temp := ReadKeyWord;
    Case Temp of
    7181: Begin
          DoCfgNet(SysNo);
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;





Procedure DoCfgNet(SysNo: Word);
  Var
    i: Word;
    ConfMask: LongInt;

  Const
    One: LongInt=1;

  Begin
  If Not NetPick.InitCustom(3,8,76,22,ESColors,
    wBordered+wClear+wUserContents,
    24, 26, NetStr,PickVertical, MultipleChoice) Then
    Halt;
  NetPick.wFrame.SetFrameType(Frame1);
  NetPick.wFrame.AddShadow(shBR, shSeeThru);
  NetPick.wFrame.AddHeaderColor('[ Networks ]', heTC, WhiteOnBlue, BlackOnLtGray);
  NetPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  NetPick.SetSelectMarker(' * ','');
  NetPick.AllocateSelectSet(26);
  For i := 1 to 26 Do
    Begin
    If Config^.GetEchoToNetwork(SysNo, i) Then
      NetPick.SelectItem(i)
    Else
      NetPick.DeSelectItem(i);
    End;
  NetPick.Process;
  For i := 1 to 26 Do
    Config^.SetEchoToNetwork(SysNo, i, NetPick.ItemIsSelected(i));
  NetPick.Erase;
  NetPick.Done;
  End;



End.
