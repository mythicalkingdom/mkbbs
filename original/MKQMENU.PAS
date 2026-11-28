{$I MKB.DEF}
Unit MKQMenu;

interface

{$I OPDEFINE.INC}

uses
  Dos,  MKString, OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,
  OpMouse,  OpFrame,  OpCmd,  OpWindow,  OpMenu, MKQwkG, MKQConf,
  CfgYN, MKQUser, MKQDef, MKQPack, MKQProt, MKQScrn, MKQMain, MKAvatar,
  MKCfgAbs;

{Menu item constants}
const
  miMain0 = 0;
  miConference1 = 1;
  miUserDef2 = 2;
  miUser3 = 3;
  miProt4 = 4;
  miPack5 = 5;
  miScrn6 = 6;
  miQuit7 = 7;

Procedure DoBanner;
Procedure MainMenu;
Procedure SetDefaults;

Implementation


Uses MKPack, MKFile;

{Color set used by entry screen}
Const
  EsColors : ColorSet = (
    TextColor       : YellowOnBlue;       TextMono        : WhiteOnBlack;
    CtrlColor       : YellowOnBlue;       CtrlMono        : WhiteOnBlack;
    FrameColor      : WhiteOnBlue;        FrameMono       : LtGrayOnBlack;
    HeaderColor     : WhiteOnBlue;        HeaderMono      : BlackOnLtGray;
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

{$I MKQMain.Inc}

Function InitMenu(var M : Menu; var Colors : ColorSet) : Word;

  const
    Frame1 : FrameArray = 'ÕÔ¸¾ÍÍ³³';
  begin
  with M do begin
    if not InitCustom(8, 5, 32, 14, Colors,
                      wBordered+wClear+wUserContents+wCoversOnDemand,
                      Vertical) then begin
      InitMenu := InitStatus;
      Exit;
    end;
    mnOptionsOn(mnAlphaMatch+mnSelectOnMatch+mnArrowSelect+mnAllHotSpots);
    mnOptionsOff(mnAllowPending+mnPopOnSelect+mnUseItemForTopic+
                 mnSelectOnClick+mnAltMatch);
    wFrame.SetFrameType(Frame1);
    AddShadow(shBR, shSeeThru);
    AddHeader('[ MKQwkCfg Menu ]', heTC);
    AddItem('Main Configuration', 1, 1, miMain0);
    AddItem('Conference Settings', 2, 1, miConference1);
    AddItem('Default User Settings', 3, 1, miUserDef2);
    AddItem('User Editor', 4, 1, miUser3);
    AddItem('Protocols', 5, 1, miProt4);
    AddItem('Archive Packers', 6, 1, miPack5);
    AddItem('Screens', 7, 1, miScrn6);
    AddItem('Quit', 8, 1, miQuit7);
    ItemsDone;
    InitMenu := RawError;
  end;
end;


Procedure MainMenu;
  Var
    M: ^Menu;
    MenuDone: Boolean;
    OS: Word;

  Begin
  New(M);
  MenuDone := False;
  If InitMenu(M^, ESColors) = 0 Then
    Begin
    While Not MenuDone Do
      Begin
      M^.Select;
      M^.Process;
      Case M^.GetLastCommand Of
        ccSelect:
          Begin
          case M^.MenuChoice of
            miMain0:
              Begin
              M^.Erase;
              EditQMain;
              M^.Select;
              End;
            miConference1:
              Begin
              M^.Erase;
              PickBBSArea;
              M^.Select;
              End;
            miUserDef2:
              Begin
              M^.Erase;
              EditQDef;
              M^.Select;
              End;
            miUser3:
              Begin
              M^.Erase;
              EditQUser;
              M^.Select;
              End;
            miProt4:
              Begin
              PickProt;
              M^.Select;
              End;
            miPack5:
              Begin
              PickPackers;
              M^.Select;
              End;
            miScrn6:
              Begin
              M^.Erase;
              EditQScrns;
              M^.Select;
              End;
            miQuit7:
              Begin
              OS := DoYesNo('[ Exit Program ]', True);
              Case OS of
                1: MenuDone := True;
                2: ; {Not done}
                End;
              M^.Select;
              End;
            End;
          End;
        End;
      End;
    M^.Erase;
    M^.Done;
    End;
  Dispose(M);
  End;


Procedure SetProtDefaults;
  Var
    TmpStr: String;
    TmpBool: Boolean;

  Begin
  TmpStr := FindPath('CEXYZ.EXE');
  If FileExist(TmpStr) Then
    Begin
    TmpStr := TmpStr + ' /P%P /L%L /N%N /B%B ';
    QCfg.Prots[1].ProtActive := True;
    QCfg.Prots[1].SendCmd := TmpStr + '/sz %F';
    QCfg.Prots[1].RcvCmd  := TmpStr + '/rz';
    QCfg.Prots[2].ProtActive := True;
    QCfg.Prots[2].SendCmd := TmpStr + '/sy1k %F';
    QCfg.Prots[2].RcvCmd  := TmpStr + '/ry1k';
    QCfg.Prots[3].ProtActive := True;
    QCfg.Prots[3].SendCmd := TmpStr + '/sx1k %F';
    QCfg.Prots[3].RcvCmd  := TmpStr + '/rx1k';
    QCfg.Prots[4].ProtActive := True;
    QCfg.Prots[4].SendCmd := TmpStr + '/sx %F';
    QCfg.Prots[4].RcvCmd  := TmpStr + '/rx';
    QCfg.Prots[5].ProtActive := True;
    QCfg.Prots[5].SendCmd := TmpStr + '/syg %F';
    QCfg.Prots[5].RcvCmd  := TmpStr + '/ryg';
    End
  Else
    Begin
    TmpStr := FindPath('DSZ.EXE');
    If Not FileExist(TmpStr) Then
      TmpStr := FindPath('DSZ.COM');
    TmpBool := FileExist(TmpStr);
    TmpStr := TmpStr + ' port %p handshake on ';
    QCfg.Prots[1].ProtActive := TmpBool;
    QCfg.Prots[1].SendCmd := TmpStr + 'sz %F';
    QCfg.Prots[1].RcvCmd  := TmpStr + 'restrict rz';
    QCfg.Prots[2].ProtActive := TmpBool;
    QCfg.Prots[2].SendCmd := TmpStr + 'sb -k %F';
    QCfg.Prots[2].RcvCmd  := TmpStr + 'restrict rb -k';
    QCfg.Prots[3].ProtActive := TmpBool;
    QCfg.Prots[3].SendCmd := TmpStr + 'sx -k %F';
    QCfg.Prots[3].RcvCmd  := TmpStr + 'restrict rx -k %F';
    QCfg.Prots[4].ProtActive := TmpBool;
    QCfg.Prots[4].SendCmd := TmpStr + 'sx %F';
    QCfg.Prots[4].RcvCmd  := TmpStr + 'restrict rx %F';
    QCfg.Prots[5].ProtActive := TmpBool;
    QCfg.Prots[5].SendCmd := TmpStr + 'sb -g %F';
    QCfg.Prots[5].RcvCmd  := TmpStr + 'restrict rb -g';
    End;
  TmpStr := FindPath('FHSLINK.EXE');
  If Not FileExist(TmpStr) Then
    TmpStr := FindPath('HSLINK.EXE');
  QCfg.Prots[6].ProtActive := FileExist(TmpStr);
  QCfg.Prots[6].SendCmd := TmpStr + ' -P%P %F';
  QCfg.Prots[6].RcvCmd  := TmpStr + ' -P%P';
  End;


Procedure SetPackDefaults;
  Var
    Packers: ^PackInfoType;
    i: Word;

  Begin
  New(Packers);
  GetPackPaths(Packers^);
  For i := 1 to 7 Do
    Begin
    QCfg.Packers[i].PackActive := FileExist(Packers^.PackPath[i]);
    If QCfg.Packers[i].PackActive Then
      Begin
      QCfg.Packers[i].PackCmd := Packers^.PackPath[i] + Packers^.PackLine[i];
      QCfg.Packers[i].UnPackCmd := Packers^.UnPackPath[i] + Packers^.UnPackLine[i];
      End;
    End;
  Dispose(Packers);
  End;


Procedure SetDefaults;
  Begin
  FillChar(QCfg, SizeOf(QCfg), #0);
  SetPackDefaults;
  SetProtDefaults;
  QCfg.BoardId := MKString.Upper(Copy(MKString.ExtractWord(Config^.GetBBSName,
     1), 1,8));
  If ((QCfg.BoardId = 'THE') or (QCfg.BoardId = 'A') or (QCfg.BoardId = 'AN')) Then
    QCfg.BoardId := MKString.Upper(Copy(MKString.ExtractWord(Config^.GetBBSName,
       2), 1,8));
  QCfg.BBSPhone := '999-999-9999';
  QCfg.Direct := True;
  QCfg.MaxMsgs := 2000;
  QCfg.MaxConfMsgs := 1000;
  QCfg.NewFiles := qatAskY;
  QCfg.Screens := qatAskY;
  QCfg.Bulletins := qatAskY;
  QCfg.SecCrash := 32000;
  QCfg.SecImd := 32000;
  QCfg.CostMyNet := 0;
  QCfg.CostNormal := 15;
  QCfg.CostZone := 100;
  QCfg.CostCrash := 50;
  QCfg.CostImd := 50;
  QCfg.UserPath := Config^.GetMsgPath(1);
  QCfg.ScreenPath := Config^.GetTxtPath(1);
  QCfg.ScrnHello := 'HELLO';
  QCfg.ScrnBye := 'GOODBYE';
  QCfg.ScrnNews := 'NEWS';
  QCfg.NewScrn := 'NEWFILES';
  QCfg.DefMaxMsgs := 1000;
  QCfg.DefMaxConfMsgs := 400;
  QCfg.DefProtocol := 'Z';
  QCfg.DefPacker := 'Z';
  QCfg.DefAttr := quaAllYours + quaOwnMsgs + quaFlagRead + quaBulletin +
    quaScreens + quaNewFile + quaNewBull;
  QCfg.DefMailType := qmtQwk;
  End;

end.
