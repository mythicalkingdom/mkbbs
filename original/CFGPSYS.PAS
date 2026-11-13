{$V-}
Unit CfgPSys;  {Cfg Echoing Systems Pick Addresses}

InterFace

uses
  Dos,  CfgGlob, MKGlobT, MKString,
  OpInline,  OpString,  OpRoot,  OpPick,  OpCrt,  OpColor,  OpAbsFld,
  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,  OpEntry, CfgESys,
  MKCfgAbs;



Procedure DoCfgPSys;


Implementation


var
  PESysPick: PickList;
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
Procedure PEchoSStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Var
    Addr: AddrType;

  Begin
  Config^.GetEchoToAddr(Item, Addr);
  IString := Pad(Long2Str(Item),3) + AddrStr(Addr);
  End;
{$F-}



Procedure DoCfgPSys;
  Var
    EdMore: Boolean;
    ANum: Word;

  Begin
  EdMore := True;
  If Not PESysPick.InitCustom(8,8,72,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 32, PEchoSStr,PickVertical, SingleChoice) Then
    Halt;
  PESysPick.wFrame.SetFrameType(Frame1);
  PESysPick.wFrame.AddShadow(shBR, shSeeThru);
  PESysPick.wFrame.AddHeaderColor('[ Addresses ]', heTC, WhiteOnBlue, BlackOnLtGray);
  PESysPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  While EdMore Do
    Begin
    PESysPick.Process;
    PESysPick.Erase;
    If PESysPick.GetLastCommand = ccSelect Then
      Begin
      ANum := PESysPick.GetLastChoice;
      DoCfgESys(ANum);
      End
    Else
      EdMore := False;
    End;
  PESysPick.Done;
  End;


End.
