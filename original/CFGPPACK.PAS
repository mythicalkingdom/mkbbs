{$V-}
Unit CfgPPack;  {Cfg Pick Packer}

InterFace

uses
  Dos,  CfgGlob, MKGlobT, MKString,
  OpInline,  OpString,  OpRoot,  OpPick,  OpCrt,  OpColor,  OpAbsFld,
  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,  OpEntry, CfgPack,
  MKCfgAbs;



Procedure DoCfgPPack;


Implementation


var
  PackPick: PickList;
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
Procedure PackStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item of
    1: IString := 'LZH';
    2: IString := 'ZIP';
    3: IString := 'ARC';
    4: IString := 'ZOO';
    5: IString := 'DWC';
    6: IString := 'ARJ';
    7: IString := 'HYP';
    Else
      IString := '';
    End;
  End;
{$F-}



Procedure DoCfgPPack;
  Var
    EdMore: Boolean;
    LNum: Word;

  Begin
  EdMore := True;
  If Not PackPick.InitCustom(3,8,12,22,ESColors,
    wBordered+wClear+wUserContents,
    8, 7, PackStr,PickVertical, SingleChoice) Then
    Halt;
  PackPick.wFrame.SetFrameType(Frame1);
  PackPick.wFrame.AddShadow(shBR, shSeeThru);
  PackPick.wFrame.AddHeaderColor('[ Packers ]', heTC, WhiteOnBlue, BlackOnLtGray);
  PackPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  While EdMore Do
    Begin
    PackPick.Process;
    PackPick.Erase;
    If PackPick.GetLastCommand = ccSelect Then
      Begin
      LNum := PackPick.GetLastChoice;
      DoCfgPack(LNum);
      End
    Else
      EdMore := False;
    End;
  PackPick.Done;
  End;


End.
