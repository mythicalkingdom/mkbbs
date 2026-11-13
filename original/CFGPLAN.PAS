{$V-}
Unit CfgPLan;  {Cfg Pick Langauge}

InterFace

uses
  Dos,  CfgGlob, MKGlobT, MKString,
  OpInline,  OpString,  OpRoot,  OpPick,  OpCrt,  OpColor,  OpAbsFld,
  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,  OpEntry, CfgLang,
  MKCfgAbs;



Procedure DoCfgPLan;


Implementation


var
  PLanPick: PickList;
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
Procedure PLanStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := Pad(Long2Str(Item),2) + Config^.GetLangName(Item);
  End;
{$F-}



Procedure DoCfgPLan;
  Var
    EdMore: Boolean;
    LNum: Word;

  Begin
  EdMore := True;
  If Not PLanPick.InitCustom(3,8,76,22,ESColors,
    wBordered+wClear+wUserContents,
    24, 10, PLanStr,PickVertical, SingleChoice) Then
    Halt;
  PLanPick.wFrame.SetFrameType(Frame1);
  PLanPick.wFrame.AddShadow(shBR, shSeeThru);
  PLanPick.wFrame.AddHeaderColor('[ Langauges ]', heTC, WhiteOnBlue, BlackOnLtGray);
  PLanPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  While EdMore Do
    Begin
    PLanPick.Process;
    PLanPick.Erase;
    If PLanPick.GetLastCommand = ccSelect Then
      Begin
      LNum := PLanPick.GetLastChoice;
      DoCfgLang(LNum);
      End
    Else
      EdMore := False;
    End;
  PLanPick.Done;
  End;


End.
