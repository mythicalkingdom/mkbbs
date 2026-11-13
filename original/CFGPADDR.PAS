{$V-}
Unit CfgPAddr;  {Cfg Pick Addresses}

InterFace

uses
  Dos,  CfgGlob, MKGlobT, MKString,
  OpInline,  OpString,  OpRoot,  OpPick,  OpCrt,  OpColor,  OpAbsFld,
  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,  OpEntry, CfgAddr,
  MKCfgAbs;



Procedure DoCfgPAddr;


Implementation


var
  PAddrPick: PickList;
  TempStr: String;



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
Procedure PAddrStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Var
    TmpAddr: AddrType;

  Begin
  Config^.GetAddr(Item, TmpAddr);
  IString := Pad(Long2Str(Item),3) + AddrStr(TmpAddr);
  End;
{$F-}



Procedure DoCfgPAddr;
  Var
    EdMore: Boolean;
    ANum: Word;

  Begin
  EdMore := True;
  If Not PAddrPick.InitCustom(8,8,72,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 10, PAddrStr,PickVertical, SingleChoice) Then
    Halt;
  PAddrPick.wFrame.SetFrameType(Frame1);
  PAddrPick.wFrame.AddShadow(shBR, shSeeThru);
  PAddrPick.wFrame.AddHeaderColor('[ Addresses ]', heTC, WhiteOnBlue, BlackOnLtGray);
  PAddrPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  While EdMore Do
    Begin
    PAddrPick.Process;
    PAddrPick.Erase;
    If PAddrPick.GetLastCommand = ccSelect Then
      Begin
      ANum := PAddrPick.GetLastChoice;
      DoCfgAddr(ANum);
      End
    Else
      EdMore := False;
    End;
  PAddrPick.Done;
  End;


End.
