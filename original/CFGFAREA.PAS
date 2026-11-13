{$V-}
Unit CfgFArea;

InterFace

uses
  Dos,  CfgGlob, MKGlobT, MKString, CfgFile,
  OpInline,  OpString,  OpRoot,  OpPick,  OpCrt,  OpColor,  OpAbsFld,
  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,  OpEntry, MKCfgAbs;



Procedure DoCfgFArea;


Implementation


var
  AreaSPick: PickList;
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
Procedure AreaSStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := Pad(Long2Str(Item),4) + Copy(Config^.GetFileAreaName(Item), 1, 19);
  End;
{$F-}



Procedure DoCfgFArea;
  Var
    EdMore: Boolean;
    CfgFileNo: Word;

  Begin
  EdMore := True;
  If Not AreaSPick.InitCustom(3,8,76,22,ESColors,
    wBordered+wClear+wUserContents,
    24, 300, AreaSStr,PickVertical, SingleChoice) Then
    Halt;
  AreaSPick.wFrame.SetFrameType(Frame1);
  AreaSPick.wFrame.AddShadow(shBR, shSeeThru);
  AreaSPick.wFrame.AddHeaderColor('[ File Areas ]', heTC, WhiteOnBlue, BlackOnLtGray);
  AreaSPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  While EdMore Do
    Begin
    AreaSPick.Process;
    AreaSPick.Erase;
    If AreaSPick.GetLastCommand = ccSelect Then
      Begin
      CfgFileNo := AreaSPick.GetLastChoice;
      DoCfgFile(CfgFileNo);
      End
    Else
      EdMore := False;
    End;
  AreaSPick.Done;
  End;


End.
