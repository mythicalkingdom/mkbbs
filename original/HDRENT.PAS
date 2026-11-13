{$I MKB.DEF}
{$V-}

Unit HDRENT;

{$I OPDEFINE.INC}

Interface

Type MsgHdrInfoType = Record
  MsgName: string[30];
  MsgPriv: Boolean;
  MsgFrom: string[35];
  MsgToAddr: string[18];
  MsgTo: string[35];
  MsgSubj: string[65];
  Crash: Boolean;
  Imm: Boolean;
  Direct: Boolean;
  FileReq: Boolean;
  FAttach: Boolean;
  KillSent: Boolean;
  NetTaglines: Boolean;
  NetFido: Boolean;
  SysName: String[30];
  Sysop: String[25];
  Location: String[35];
  Baud: String[6];
  RefNum: LongInt;
  End;


Var
  MsgHdrInfo: MsgHdrInfoType;
  NewMsgIsNet: Boolean;

Procedure GetNewMsgHdr;
Procedure AttachHelp;


Implementation


uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,
  OpSelect,  OpEntry, MKNSrch, MKGlobT, MKCfgAbs, MKEnter,
  MKString, MKFile;

const
  MouseChar  : Char = #04;

const
  EsColors : ColorSet = (
    TextColor       : YellowOnBlue;       TextMono        : WhiteOnBlack;
    CtrlColor       : YellowOnBlue;       CtrlMono        : WhiteOnBlack;
    FrameColor      : WhiteOnBlue;        FrameMono       : LtGrayOnBlack;
    HeaderColor     : WhiteOnCyan;        HeaderMono      : BlackOnLtGray;
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

{Entry field constants}
const
  idMsgFrom = 0;
  idRefNum = idMsgFrom + 1;
  idMsgTo = idRefNum + 1;
  idMsgToAddr = idMsgTo + 1;
  idMsgSubj = idMsgToAddr + 1;
  idSysName = idMsgSubj + 1;
  idSysop = idSysName + 1;
  idLocation = idSysop + 1;
  idBaud = idLocation + 1;

{Help index constants}
const
  hiMsgFrom = 1;
  hiRefNum = hiMsgFrom + 1;
  hiMsgTo = hiRefNum + 1;
  hiMsgToAddr = hiMsgTo + 1;
  hiMsgSubj = hiMsgToAddr + 1;
  hiSysName = hiMsgSubj + 1;
  hiSysop = hiSysName + 1;
  hiLocation = hiSysop + 1;
  hiBaud = hiLocation + 1;

var
  ES     : EntryScreen;
  Status : Word;

{$F+}
procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
begin
  with ESP^ do
    case GetCurrentID of
      idMsgFrom              : ;
      idMsgToAddr            : ;
      idMsgTo                : ;
      idMsgSubj              : ;
    end;
end;


Procedure UpdateNodeInfo(ESP: EntryScreenPtr);
  Var
  Nodes: NodeListObj;
  Addr: AddrType;
  DAddr: AddrType;
  TmpStr: String;

  Begin
  Config^.GetAddr(1,DAddr);
  If ParseAddr(MsgHdrInfo.MsgToAddr, DAddr, Addr) Then
    Begin
    If ((DAddr.Zone = Addr.Zone) And (DAddr.Net = Addr.Net)
    And (DAddr.Node = Addr.Node) And (DAddr.Point = Addr.Point)) Then
      Begin
      MsgHdrInfo.SysName := '';
      MsgHdrInfo.Sysop := '';
      MsgHdrInfo.Location := '';
      MsgHdrInfo.Baud := '';
      End
    Else
      Begin
      Nodes.Init;
      Nodes.Load;
      TmpStr := Nodes.NodeStr(Addr);
      Nodes.Done;
      MsgHdrInfo.SysName := GetNodeSection(TmpStr,2);
      MsgHdrInfo.Sysop := GetNodeSection(TmpSTr,4);
      MsgHdrInfo.Location := GetNodeSection(TmpStr, 3);
      MsgHdrInfo.Baud := GetNodeSection(TmpSTr, 6);
      If MsgHdrInfo.MsgTo = '' Then
        Begin
        MsgHdrInfo.MsgTo := MsgHdrInfo.Sysop;
        ESP^.DrawField(idMsgTo);
        End;
      End;
    ESP^.DrawField(idSysName);
    ESP^.DrawField(idSysop);
    ESP^.DrawField(idLocation);
    ESP^.DrawField(idBaud);
    End;
  End;


Procedure DoNode(ESP: EntryScreenPtr);
  Begin
  If ESP^.CurrentFieldModified Then
    UpdateNodeInfo(ESP);
  End;


procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idMsgFrom: ;
      idMsgTo:;
      idMsgToAddr: DoNode(ESP);
      idMsgSubj: ;
    end;
end;

procedure IncChoice(var Value; ID : Word; Factor : Integer; var St : string);
  {-Increment a multiple choice field value and convert it to a string}
begin
end;

procedure ErrorHandler(UnitCode : Byte; var ErrCode : Word; Msg : string);
  {-Report errors}
begin
  RingBell;
end;

procedure DisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
  {-Display context sensitive help}
begin
end;

function InitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
const
  Frame1 = '…»ªºÕÕ∫∫';
  WinOptions = wBordered+wClear+wUserContents;
begin
  with ES do
    begin
    If NewMsgIsNet Then
      Begin
      If not InitCustom(2, 2, 79, 8, EsColors, WinOptions) then
        begin
        InitEntryScreen := InitStatus;
        Exit;
        end;
      End
    Else
      Begin
      If not InitCustom(2, 2, 79, 4, EsColors, WinOptions) then
        begin
        InitEntryScreen := InitStatus;
        Exit;
        end;
      End;
    wFrame.SetFrameType(Frame1);
    SetWrapMode(ExitAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

  {idMsgFrom:}
    AddStringField(
      'From:', 1, 3,
      CharStr('X', 35), 1, 9, 35,
      hiMsgFrom, MsgHdrInfo.MsgFrom);


    AddLongField(
      'Refer Num:', 1, 55,
      '999999999', 1, 66,
      hiRefNum, 0, $7fffffff, MsgHdrInfo.RefNum);

  {idMsgTo:}
    AddStringField(
      'To:', 2, 3,
      CharStr('X', 35), 2, 7, 35,
      hiMsgTo, MsgHdrInfo.MsgTo);


  If NewMsgIsNet Then
    AddStringField(
      '', 2, 46,
      'XXXXXXXXXXXXXXXXXX', 2, 46, 18,
      hiMsgToAddr, MsgHdrInfo.MsgToAddr);


  {idMsgSubj:}
    AddStringField(
      'Subj:', 3, 3,
      CharStr('X', 65), 3, 9, 65,
      hiMsgSubj, MsgHdrInfo.MsgSubj);

  If NewMsgIsNet Then
    Begin
    esFieldOptionsOn(efProtected);
    AddStringField(
      'System:',5,3,
      CharStr('X',30), 5,11,30,
      hiSysName, MsgHdrInfo.SysName);
    AddStringField(
      'Sysop:',5, 45,
      CharStr('X',25), 5, 52, 25,
      hiSysop, MsgHdrInfo.Sysop);
    AddStringField(
      'Location:',6,3,
      CharStr('X',30), 6, 13, 30,
      hiLocation, MsgHdrInfo.Location);
    AddStringField(
      'Baud:', 6, 50,
      CharStr('X',6),6,56,6,
      hiBaud, MsgHdrInfo.Baud);
    esFieldOptionsOff(efProtected);
    End;

    InitEntryScreen := RawError;
  end;
end;


Procedure GetNewMsgHdr;
  begin
  Status := InitEntryScreen;
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  if MouseInstalled then
    with EsColors do begin
      {activate mouse cursor}
      SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
      ShowMouse;
      {enable mouse support}
      EntryCommands.cpOptionsOn(cpEnableMouse);
    end;
  ES.Draw;
  If NewMsgIsNet Then
    UpdateNodeInfo(@ES);
  ES.Process;
  ES.Erase;
  HideMouse;
  ES.Done;
  End;


Procedure AttachHelp;
  Var
    SR: FindObj;
    ND: Word;
    WC: Word;
    TW: Word;
    TmpStr: String;

  Begin
  SR.Init;
  WriteLn;
  WriteLn(' The following files are File-Attached to this message');
  WriteLn;
  TW := WordCount(MsgHdrInfo.MsgSubj);
  WC := 1;
  ND := 0;
  While ((WC <= TW) and (ND < 20)) Do
    Begin
    TmpStr := ExtractWord(MsgHdrInfo.MsgSubj, WC);
    SR.FFirst(TmpStr);
    While ((SR.Found) and (ND < 20)) Do
      Begin
      If ND < 20 Then
        Begin
        Inc(ND);
        Write(' ', PadRight(SR.GetName, ' ', 15));
        Write(PadLeft(CommaStr(SR.GetSize), ' ', 9));
        WriteLn(' ... ', Copy(SR.GetFullPath, 1, 48));
        End;
      SR.FNext;
      End;
    Inc(WC);
    End;
  SR.Done;
  End;


End.
