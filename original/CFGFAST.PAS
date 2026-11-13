{$V-}

Unit CFGFAST;

{$I OPDEFINE.INC}

Interface


Procedure DoFastPick(FastType: Word);


Implementation


uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,  OpMouse,
  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,
  OpEntry, CfgGlob, MKGlobT, OpPick, MKCfgAbs;


{$F+}
Procedure AreaSStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := Pad(Long2Str(Item),4) + Copy(Config^.GetMsgName(Item), 1, 19);
  End;
{$F-}



Procedure DoFastPick(FastType: Word);
  Var
    AreaSPick: PickList;
    i: Word;
    Title: String;

  Begin
  Case FastType of
    1: Title := '[ Allow Combined ]';
    2: Title := '[ Allow Ansi ]';
    3: Title := '[ Allow Hi-Bit Chars ]';
    4: Title := '[ Allow Reader Taglines ]';
    5: Title := '[ Add Fido Info ]';
    6: Title := '[ Reader Tearlines ]';
    7: Title := '[ Allow Offline ]';
    8: Title := '[ Force Offline ]';
    9: Title := '[ Default Combined ]';
    10: Title := '[ Reader Origin Lines ]';
    11: Title := '[ Import Path ]';
    12: Title := '[ Hide Imported Path ]';
    13: Title := '[ Import Seen-By ]';
    14: Title := '[ Hide Imported Seen-By ]';
    Else
      Title := '[ * ]';
    End;
  If Not AreaSPick.InitCustom(3,8,76,22,ESColors,
    wBordered+wClear+wUserContents,
    24, 500, AreaSStr,PickVertical, MultipleChoice) Then
    Halt;
  AreaSPick.wFrame.SetFrameType(Frame1);
  AreaSPick.wFrame.AddShadow(shBR, shSeeThru);
  AreaSPick.wFrame.AddHeaderColor(Title, heTC, WhiteOnBlue, BlackOnLtGray);
  AreaSPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  AreaSPick.SetSelectMarker(' * ','');
  AreaSPick.AllocateSelectSet(501);
  For i := 1 to 500 Do
    Begin
    Case FastType of
      1: If Config^.GetMsgAllowCombined(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      2: If Config^.MsgAllowAnsi(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      3: If Config^.MsgAllowHiBit(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      4: If Config^.MsgAllowTag(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      5: If Config^.MsgAddFido(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      6: If Config^.GetMsgReaderTear(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      7: If Config^.GetMsgAllowOffline(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      8: If Config^.GetMsgForceOffline(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      9: If Config^.GetMsgDefCombined(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
     10: If Config^.GetMsgReaderOrig(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
     11: If Config^.GetEchoAreaImportPath(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
     12: If Config^.GetEchoAreaHidePath(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
     13: If Config^.GetEchoAreaImportSeen(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
     14: If Config^.GetEchoAreaHideSeen(i) Then
           AreaSPick.SelectItem(i)
         Else
           AreaSPick.DeSelectItem(i);
      Else
        AreaSPick.DeSelectItem(i);
      End;
    End;
  AreaSPick.Process;
  For i := 1 to 500 Do
    Begin
    Case FastType Of
      1: Config^.SetMsgAllowCombined(i, AreaSPick.ItemIsSelected(i));
      2: Config^.SetMsgAllowAnsi(i, AreaSPick.ItemIsSelected(i));
      3: Config^.SetMsgAllowHiBit(i, AreaSPick.ItemIsSelected(i));
      4: Config^.SetMsgAllowTag(i, AreaSPick.ItemIsSelected(i));
      5: Config^.SetMsgAddFido(i, AreaSPick.ItemIsSelected(i));
      6: Config^.SetMsgReaderTear(i, AreaSPick.ItemIsSelected(i));
      7: Config^.SetMsgAllowOffline(i, AreaSPick.ItemIsSelected(i));
      8: Config^.SetMsgForceOffline(i, AreaSPick.ItemIsSelected(i));
      9: Config^.SetMsgDefCombined(i, AreaSPick.ItemIsSelected(i));
      10: Config^.SetMsgReaderOrig(i, AreaSPick.ItemIsSelected(i));
      11: Config^.SetEchoAreaImportPath(i, AreaSPick.ItemIsSelected(i));
      12: Config^.SetEchoAreaHidePath(i, AreaSPick.ItemIsSelected(i));
      13: Config^.SetEchoAreaImportSeen(i, AreaSPick.ItemIsSelected(i));
      14: Config^.SetEchoAreaHideSeen(i, AreaSPick.ItemIsSelected(i));
      End;
    End;
  AreaSPick.Erase;
  AreaSPick.Done;
  End;


End.
