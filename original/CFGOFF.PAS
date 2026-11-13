{$V-}
Unit CfgOff;

InterFace

uses
  Dos,  CfgGlob, MKGlobT, MKString,
  OpInline,  OpString,  OpRoot,  OpPick,  OpCrt,  OpColor,  OpAbsFld,
  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,  OpEntry,
  MKCfgAbs;



Procedure DoCfgOffType;


Implementation




{$F+}
procedure PreEdit(ESP : EntryScreenPtr);
  begin
  end;


procedure PostEdit(ESP : EntryScreenPtr);
  begin
  end;


procedure IncChoice(var Value; ID : Word; Factor : Integer; var St : string);
  begin
  end;


procedure ErrorHandler(UnitCode : Byte; var ErrCode : Word; Msg : string);
  begin
  RingBell;
  end;


procedure DisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
begin
end;
{$F-}




{$F+}
Procedure OffTypeStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item of
    1: IString := 'QWK';
    2: IString := 'XRS';
    3: IString := 'BlueWave';
    4: IString := 'Text';
    5: IString := 'PKT';
    Else
      IString := '';
    End;
  End;
{$F-}



Procedure DoCfgOffType;
  Var
    OffTypePick: PickList;
    TempStr: String;
    i: Word;


  Begin
  If Not OffTypePick.InitCustom(3,8,23,22,ESColors,
    wBordered+wClear+wUserContents,
    15, 5, OffTypeStr,PickVertical, MultipleChoice) Then
    Halt;
  OffTypePick.wFrame.SetFrameType(Frame1);
  OffTypePick.wFrame.AddShadow(shBR, shSeeThru);
  OffTypePick.wFrame.AddHeaderColor('[ Available Offline ]', heTC, WhiteOnBlue, BlackOnLtGray);
  OffTypePick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  OffTypePick.SetSelectMarker(' * ','');
  OffTypePick.AllocateSelectSet(11);
  For i := 1 to 10 Do
    Begin
    If Config^.GetOffTypeAvail(i) Then
      OffTypePick.SelectItem(i)
    Else
      OffTypePick.DeSelectItem(i);
    End;
  OffTypePick.Process;
  For i := 1 To 10 Do
    Config^.SetOffTypeAvail(i, OffTypePick.ItemIsSelected(i));
  OffTypePick.Erase;
  OffTypePick.Done;
  End;


End.
