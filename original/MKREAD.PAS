{$I OPDEFINE.INC}
{$IFDEF DPMI}
{$M 16384}
{$ELSE}
{$M 16384, 240000, 650000}
{$ENDIF}
{$I MKB.Def}
{$R-}
Uses
  {$IFNDEF DPMI}
  Extend,
  Overlay,
  {$ENDIF}
  MKReadO, Dos,  OpInline,  OpString,  OpRoot,  OpCrt,
  OpColor, OpMouse,  OpFrame,  OpCmd,  OpWindow,  OpMenu, OPPick, CfgYN,
  MKString, MKFile, MKCfgAbs, MKRCfgRA, MKCfgSB, MKCfgQB, MKRCfgMK, MKCfgTxt,
  MKGlobT, OPMemo, MKMsgAbs, MKOpen, MKRCfgEz, MKMsgHud, MKMsgEzy, MKMsgJam,
  MKRCfgR2, MKReadCf, MKMisc, MKDos, HdrEnt, MKEnter, OpEditor, OpEdit, OpDos,
  OpSort, QuoteCvt, MkTagLn, OpExec, MKAvatar, MKRBan, OpConst;


{$IFNDEF DPMI}
{$O MKRBan}
{$O MKString}
{$O MKTagLn}
{$O HdrEnt}
{$O MKScrn}
{$O MKColor}
{$O MKAvatar}
{$O MKCfgAbs}
{$O MKRCfgMK}
{$O MKRCfgRA}
{$O MKRCfgR2}
{$O MKCfgQB}
{$O MKCfgSB}
{$O MKRCfgEz}
{$O MKCfgTxt}
{$O MKMsgHud}
{$O MKMsgSqu}
{$O MKMsgFid}
{$O MKMsgEzy}
{$O MKMsgJam}
{$O MKReadCf}
{$O MKMisc}
{$O MKDos}
{$O MKEnter}
{$O MKGlobT}
{$O OpDos}
{$O OpEdit}
{$O OpEditor}
{$O OpEntry}
{$O OpMemo}
{$O OpMenu}
{$O OpPick}
{$O OpSort}
{$O OpFrame}
{$O OpField}
{.$O OpFEdit}
{.$O OpWindow}
{$O OpSelect}
{$O MKFile}
{$O QuoteCvt}
{$O CfgYn}
{$O MKNSrch}
{$ENDIF}


const
  TempName = 'MsgTmp.MK';
  BackName = 'MsgTmp.Bak';
  NumTxtLines = 16;

Const
  Frame1 = '…»ªºÕÕ∫∫';



{Menu item constants}
const
  miArea0 = 0;
  miPrior1 = miArea0 + 1;
  miNext2 = miPrior1 + 1;
  miExport3 = miNext2 + 1;
  miReply4 = miExport3 + 1;
  miEnter5 = miReply4 + 1;
  miPg7 = miEnter5 + 1;
  miPg8 = miPg7 + 1;
  miConfig9 = miPg8 + 1;
  miQuit6 = miConfig9 + 1;
  miJump10 = miQuit6 + 1;
  miDelete11 = miJump10 + 1;
  miShell12 = miDelete11 + 1;
  miView13 = miShell12 + 1;
  miUp14 = miView13 + 1;
  miDn15 = miUp14 + 1;
  miYour16 = miDn15 + 1;

{$F+}
procedure ErrorHandler(UnitCode : Byte; var ErrCode : Word; Msg : string);
  {-Report errors}
begin
  RingBell;
end;

procedure DisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
  Var
    HelpWin: StackWindowPtr;
    Ch: Char;
    TmpWin: RawWindowPtr;

  Begin
  TmpWin := CurrentWindow;
  New(HelpWin, InitCustom(1,1,80,25, ESColors, wClear + wSaveContents));
  If HelpWin <> nil Then
    Begin
    HelpWin^.Draw;
    Case UnitCode of
        ucEditor: EditHelp;
        ucMenu: MenuHelp;
        250: AttachHelp;
      Else
        NoHelp;
      End;
    Ch := Readkey;
    HelpWin^.Erase;
    Dispose(HelpWin, Done);
    End;
  TmpWin^.Select;
  End;


procedure CustomizeItemString(var Name : String; Key : LongInt;
                              Selected, Highlighted : Boolean;
                              WPtr : RawWindowPtr);
  {-Customize menu item strings}
begin
end;

function InitMenu(var M : Menu) : Word;
begin
  with M do begin
    if not InitCustom(1, 24, 80, 24, MenuColors,
                      wClear+wUserContents+wCoversOnDemand,
                      Horizontal) then begin
      InitMenu := InitStatus;
      Exit;
    end;
    mnOptionsOn(mnAlphaMatch+mnSelectOnMatch+mnArrowSelect+mnAllHotSpots +
      mnSelectOnClick);

    mnOptionsOff(mnAllowPending+mnPopOnSelect+mnUseItemForTopic+
                 +mnAltMatch);

    AddItemHelp('Area', 02, 1, miArea0, ' Select Message Area');
    AddItemHelp('Prev', 07, 1, miPrior1, ' Previous Message');
    AddItemHelp('Next', 12, 1, miNext2, ' Next Message');
    AddItemHelp('Export', 17, 2, miExport3, ' Export message');
    AddItemHelp('Reply', 24, 1, miReply4, ' Reply to message');
    AddItemHelp('Enter', 30, 1, miEnter5, ' Enter new message');
    AddItemHelp('+P', 36, 1, miPg7, ' Page Down message text');
    AddItemHelp('-P', 39, 1, miPg8, ' Page Up message text');
    AddItemHelp('Cfg', 42, 1, miConfig9, ' Configure MKRead ');
    AddItemHelp('Jump', 46, 1, miJump10, ' Jump to specific message');
    AddItemHelp('Del', 51, 1, miDelete11, ' Delete current message');
    AddItemHelp('Shell', 55, 1, miShell12, ' Shell to Dos');
    AddItemHelp('View', 61, 1, miView13, ' View Ansi/Avatar message');
    AddItemHelp(#25, 66, 1, miDn15, 'Down one line in message text');
    AddItemHelp(#24, 68, 1, miUp14, 'Up one line in message text');
    AddItemHelp('Your', 70, 1, miYour16, 'Find messages to You');
    AddItemHelp('Quit', 75, 1, miQuit6, ' Quit');
    ItemsDone;

    SetErrorProc(ErrorHandler);
    MenuCommands.SetHelpProc(DisplayHelp);
    SetCustomStringProc(CustomizeItemString);

    InitMenu := RawError;
  end;
end;

function InitHelpLine(var H : RawWindow) : Word;
  {-Initialize window for the help line}
var
  Row : Byte;
begin
  Row := 25;
  if not H.InitCustom(1, Row, ScreenWidth, Row,
                      MenuColors, wClear) then begin
    InitHelpLine := InitStatus;
    Exit;
  end;
  H.SetTextAttr(CfgRec.Colors[5], CfgRec.Colors[5]);
  InitHelpLine := 0;
end;

Const
  MaxLines = 300;

Type
  MsgBuffType = Array[1..MaxLines] of String[80];

Type StrPtr = ^String;

Type MsgListRec = Record
  Subj: String[25];
  MsgNum: LongInt;
  MsgFrom: String[15];
  MsgDate: LongInt;
  MsgPos: LongInt;
  WasRead: Boolean;
  ToYou: Boolean;
  Area: Word;
  End;


Const  MsgListSize = 1200;

Type MsgListArray = Array[1..MsgListSize + 1] of ^MsgListRec;

Const
  DirectArea = 1026;

Var
  MsgBuffer: ^MsgBuffType;
  MsgWin: StackWindowPtr;
  AnsiWin: StackWindowPtr;
  TopLine: Word;
  Status : Word;
  M: Menu;      {menu system}
  H: RawWindow; {item help window}
  AreaSPick: PickList;
  TempStr: String;
  CurrArea: Word;
  MsgOut: AbsMsgPtr;
  BadArea: Boolean;
  FirstArea: Boolean;
  TotalLines: Word;
  DoHidden: Boolean;
  HighestRead: LongInt;
  LastMsg: Array[1..DirectArea] of LongInt;
  LRead: Array[1..DirectArea] of LongInt;
  MsgList: MsgListArray;
  SortList: Array[1..MsgListSize + 1] Of Word;
  NumInList: Word;
  HighMsgNum: LongInt;
  CurrMsg: Word;
  LastTag: String;
  DStr: String;
  CT: CursorType;
  EnterNet: Boolean;
  EnterDirect: Boolean;
  EnterEcho: Boolean;
  ExitLevel: Byte;
  MsgSaved: Boolean;
  AreaNames: Array[1..DirectArea] Of ^String;
  i: Word;
  SwapPath: String[128];
  DoingYours: Boolean;
  MsgOutArea: Word;


Function MsgName(Area: Word): String;
  Begin
  If Area = DirectArea Then
    MsgName := CfgRec.NetPath
  Else
    MsgName := Config^.GetMsgName(Area);
  End;

Function MsgAreaId(Area: Word): String;
  Begin
  If Area = DirectArea Then
    MsgAreaId := 'F' + WithBackSlash(CfgRec.NetPath)
  Else
    MsgAreaId := Config^.GetMsgAreaId(Area);
  End;


Function MsgType(Area: Word): MailType;
  Begin
  If Area = DirectArea Then
    MsgType := NetMail
  Else
    MsgType := Config^.GetMsgType(Area);
  End;

Function MsgBaseType(Area: Word): Char;
  Begin
  If Area = DirectArea Then
    MsgBaseType := 'F'
  Else
    MsgBaseType := Config^.GetMsgBaseType(Area);
  End;


Function GetUNum(Area: Word): LongInt;
  Begin
  Case MsgBaseType(Area) of
    'J': GetUNum := JamStrCrc(CfgRec.Name);
    Else
      GetUNum := CfgRec.UserNum;
    End;
  End;


Procedure InitNamePtr;
  Var
    i: Word;

  Begin
  For i := 1 to DirectArea Do
    AreaNames[i] := Nil;
  End;


Procedure UnloadAreaNames;
  Var
    i: Word;

  Begin
  For i := 1 to DirectArea Do
    Begin
    If AreaNames[i] <> nil Then
      Begin
      FreeMem(AreaNames[i], Length(AreaNames[i]^) + 1);
      AreaNames[i] := nil;
      End;
    End;
  End;


Procedure LoadAreaNames;
  Var
    i: Word;
    TmpStr: String[17];

  Begin
  For i := 1 to DirectArea Do
    Begin
    TmpStr := Copy(MsgName(i),1,17);
    If Length(TmpStr) > 0 Then
      Begin
      GetMem(AreaNames[i], Length(TmpStr) + 1);
      AreaNames[i]^ := TmpStr;
      End;
    End;
  End;


Function GetAreaName(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= DirectArea)) Then
    Begin
    If AreaNames[Area] = nil Then
      GetAreaName := ''
    Else
      GetAreaName := AreaNames[Area]^;
    End
  Else
    GetAreaName := '';
  End;


Procedure WriteLogEntry(Entry: String);
  Var
    LogFile: File;
    LogStr: String;
    StrCnt: Word;

  Begin
  If Length(Config^.GetEchoLog) > 0 Then
    Begin
    FileMode := fmReadWrite + fmDenyNone;
    Assign(LogFile, Config^.GetEchoLog);
    If IoResult <> 0 Then;
    If FileExist(Config^.GetEchoLog) Then
      Begin
      If Not shReset(LogFile,1) Then;
      End
    Else
      Begin
      ReWrite(LogFile,1);
      If IoResult <> 0 Then;
      End;
    Seek(LogFile,FileSize(LogFile));
    If IoResult <> 0 Then;
    LogStr := Upper(Entry) +#13 + #10;
    BlockWrite(LogFile, LogStr[1], Length(LogStr));
    If IoResult <> 0 Then;
    Close(LogFile);
    If IoResult <> 0 Then;
    End;
  End;



Procedure RefreshTitles;
  Begin
  MsgWin^.Select;
  MsgWin^.Draw;
  Window(1,1,80,6);
  TextAttr := CfgRec.Colors[2];
  ClrScr;
  Window(1,1,80,23);
  GoToXy(2,1);
  Write('Area:');
  GoToXy(2,2);
  Write('From:');
  GoToXy(2,3);
  Write('To:');
  GoToXy(2,4);
  Write('Subj:');
  GoToXy(2,6);
  Write(PadRight('','ƒ',78));
  GoToXy(2,23);
  Write(PadRight('','ƒ',78));
  GoToXy(57,2);
  Write('Msg:');
  GoToXy(57,3);
  Write('Date:');
  Window(1,7,80,22);
  TextAttr := CfgRec.Colors[1];
  ClrScr;
  Window(1,1,80,23);
  End;



Procedure CloseArea;
  Begin
  If Not BadArea Then
    Begin
    If Not DoingYours Then
      Begin
      MsgOut^.SetLastRead(GetUNum(MsgOutArea), HighestRead);
      End;
    If CloseMsgArea(MsgOut) Then;
    End;
  End;


Procedure OpenArea(DoReset: Boolean);
  Begin
  If DoReset Then
    Begin
    CurrMsg := 1;
    NumInList := 0;
    HideMouse;
    RefreshTitles;
    ShowMouse;
    End;
  BadArea := True;
  If Length(MsgName(CurrArea)) > 0 Then
    Begin
    If Not OpenMsgArea(MsgOut, MsgAreaId(CurrArea)) Then
      MsgBox('Unable to open msg area')
    Else
      Begin
      MsgOutArea := CurrArea;
      BadArea := False;
      End;
    End
  Else
    MsgBox('Invalid Msg Area');
  End;


{$F+}
procedure UpdateHelpLine(CurrentItem : MenuItemNodePtr; MPtr : MenuPtr);
  {-Update HelpLine for each menu item}
var
  S : String;
begin
  if CurrentItem = nil then
    S := ''
  else
    S := CurrentItem^.HelpString;
  H.SetTextAttr(CfgRec.Colors[5], CfgRec.Colors[5]);
  H.wFastText(Pad(S, H.Width), 1, 1);
end;


{$F+}
Procedure AreaSStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Var
    TmpStr: String;

  Begin
  If LastMsg[Item] > LRead[Item] Then
    IString := Pad(Long2Str(Item),3) + ' * ' + GetAreaName(Item)
  Else
    IString := Pad(Long2Str(Item),3) + '   ' + GetAreaName(Item);
  End;



{$F+}
Procedure AreaNStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  IString := Pad(Long2Str(Item),3) + ' ' + GetAreaName(Item);
  End;



{$F+}
Procedure PickNetStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    1: IString := 'Crash';
    2: IString := 'Direct';
    3: IString := 'Immediate';
    4: IString := 'File Request';
    5: IString := 'File Attach';
    6: IString := 'Kill after sending';
    7: IString := 'Add Netmail Taglines';
    8: IString := 'Add Netmail Origin';
    Else
      IString := '';
    End;
  End;



{$F+}
Procedure JumpStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Var
    TmpStr: String[7];

  Begin
  If MsgList[SortList[Item]]^.WasRead Then
    TmpStr := '  '
  Else
    TmpStr := ' *';
  If MsgList[SortList[Item]]^.ToYou Then
    TmpStr := TmpStr + ' + '
  Else
    TmpStr := TmpStr + '   ';
  IString := TmpStr + PadLeft(Long2Str(MsgList[SortList[Item]]^.MsgNum),' ', 6) + '  ' +
    DateStr(MsgList[SortList[Item]]^.MsgDate) + ' ' +
    Copy(TimeStr(MsgList[SortList[Item]]^.MsgDate), 1, 5) + '  ' +
    PadRight(Copy(Proper(MsgList[SortList[Item]]^.MsgFrom), 1, 25),' ', 25) + '  ' +
    PadRight(Copy(Proper(MsgList[SortList[Item]]^.Subj), 1, 25), ' ', 25);
  End;


{$F+}
Procedure PickTagStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  IString := PadLeft(Long2Str(Item),' ', 4) + '  ' + Copy(GetTag(Item),1,60);
  End;


Function FixSubj(Subj: String): String;
  Const
    junk = 12;
    trimjunk : array[1..junk] of string[5] =
      ('RE.:', '(R):', 'RE ',   'RE:', 'RE.', '(R)',
       'RE :', 'RE;',  'RE^2:', 'S:',  'SU:', 'WE:');

  Var
    TmpStr: String;
    i: Word;

  Begin
  TmpStr := Subj;
  For i := 1 to Junk Do
    If Upper(Copy(TmpStr,1, Length(TrimJunk[i]))) = TrimJunk[i] Then
      TmpStr := Copy(TmpStr, Length(TrimJunk[i]) + 1, 255);
  FixSubj := StripBoth(TmpStr,' ')
  End;


Procedure GetLRead;
  Var
    Item: Word;
    CMsg: AbsMsgPtr;
    i: Word;
    LR: LastReadType;
    HudsonDone: Boolean;

  Begin
  HudsonDone := False;
  TextAttr := LtGreenOnBlack;
  For Item := 1 to DirectArea Do
    LRead[Item] := 0;
  For Item := 1 to DirectArea Do
    Begin
    DStr := PadRight(Long2Str(Item), ' ', 4);
    GoToXy(66, 20);
    Write(DStr);
    If (Length(MsgName(Item)) > 0) Then
      Begin
      If ((MsgBaseType(Item) <> 'H') or (Not HudsonDone)) Then
        Begin
        If InitMsgPtr(CMsg, MsgAreaId(Item)) Then
          Begin
          If MsgBaseType(Item) = 'H' Then
            Begin
            HudsonMsgPtr(CMsg)^.GetAllLastRead(GetUNum(Item), LR);
            For i := 1 To 200 Do
              Begin
              If MsgBaseType(i) = 'H' Then
                LRead[i] := LR[i];
              End;
            HudsonDone := True;
            End
          Else
            LRead[Item] := CMsg^.GetLastRead(GetUNum(Item));
          If DoneMsgPtr(CMsg) Then;
          End;
        End;
      End;
    End;
  End;


Procedure GetLastMsgs;
  Var
    Count: LongInt;
    HudsonDone: Boolean;
    TmpStr: String;
    CMsg: AbsMsgPtr;
    LR: LastReadType;
    i: Word;

  Begin
  HudsonDone := False;
  For Count := 1 to DirectArea Do
    LastMsg[Count] := 0;
  For Count := 1 to DirectArea Do
    Begin
    DStr := PadRight(Long2Str(Count), ' ', 4);
    GoToXy(39, 20);
    Write(DStr);
    If (Length(MsgName(Count)) > 0) Then
      Begin
      If ((MsgBaseType(Count) <> 'H') or (Not HudsonDone)) Then
        Begin
        If OpenMsgArea(CMsg, MsgAreaId(Count)) Then
          Begin
          Case MsgBaseType(Count) Of
            'H': Begin
                 If Not HudsonDone Then
                   Begin
                   HudsonMsgPtr(CMsg)^.GetHighest(LR);
                   For i := 1 to 200 Do
                     Begin
                     If MsgBaseType(i) = 'H' Then
                       LastMsg[i] := LR[i];
                     End;
                   HudsonDone := True;
                   End;
                 End;
            Else
              LastMsg[Count] := CMsg^.GetHighMsgNum;
            End;
          If CloseMsgArea(CMsg) Then;
          End;
        End;
      End;
    End;
  End;



Procedure DisplayMsgTxt;
  Var
    CLine: Word;
    TmpStr: String;

  Begin
  HideMouse;
  MsgWin^.Select;
  TextAttr := CfgRec.Colors[1];
  For CLine := 0 to NumTxtLines - 1 Do
    Begin
    If CLine + TopLine <= TotalLines Then
      TmpStr := PadRight(MsgBuffer^[CLine + TopLine], ' ', 79)
    Else
      TmpStr := PadRight('',' ', 79);
    GoToXy(1, CLine + 7);
    If Pos('>', Copy(TmpStr,1,8)) > 0 Then
      TextAttr := CfgRec.Colors[7]
    Else
      TextAttr := CfgRec.Colors[1];
    Write(TmpStr);
    End;
  If MouseInstalled Then
      ShowMouse;
  End;



Function StripTag(TagStr: String): String;
  Var
    OutStr: String;
    SChar: Char;
    SPos: Word;

  Begin
  SChar := TagStr[2];
  OutStr := StripBoth(Copy(TagStr,4,255), ' ');
  If Upper(Copy(OutStr,1,8)) = 'MEGAMAIL' Then
    SChar := ':';
  SPos := Pos(SChar, OutStr);
  If ((SPos > 0) and (SChar <> '.')) Then
    StripTag := StripLead(Copy(OutStr, SPos + 1, 255), ' ')
  Else
    StripTag := OutStr;
  End;


Procedure DisplayMsgHdr;
  Var
    TmpStr: String;
    TmpStr2: String;
    MsgIsNet: Boolean;
    TAddr: AddrType;
    i: Word;
    HoldStr: String[10];
    TagFound: Boolean;

  Begin
  RefreshTitles;
  MsgList[SortList[CurrMsg]]^.WasRead := True;
  MsgIsNet := MsgType(CurrArea) = NetMail;
  TopLine := 1;
  MsgWin^.Select;
  TextAttr := CfgRec.Colors[3];
  GoToXY(8,1);
  Write(PadRight(Long2Str(CurrArea),' ',4));
  Write(PadRight(Copy(MsgName(CurrArea),1,25),' ',25));
  GoToXY(8,2);
  MsgOut^.GetOrig(TAddr);
  If MsgIsNet Then
    Write(PadRight(MsgOut^.GetFrom + ' @ ' + AddrStr(TAddr),' ', 45))
  Else
    Write(PadRight(MsgOut^.GetFrom,' ', 45));
  GoToXY(8,3);
  MsgOut^.GetDest(TAddr);
  If MsgIsNet Then
    Write(PadRight(MsgOut^.GetTo + ' @ ' + AddrStr(TAddr),' ', 45))
  Else
    Write(PadRight(MsgOut^.GetTo,' ', 45));
  GoToXY(8,4);
  Write(Copy(PadRight(MsgOut^.GetSubj,' ',69),1,69));
  GoToXy(63,2);
  Write(PadLeft(Long2Str(MsgOut^.GetMsgNum),' ',8));
  GoToXy(74,2);
  If MsgOut^.GetRefer <> 0 Then
    Write('<')
  Else
    Write(' ');
  GoToXy(76, 2);
  If MsgOut^.GetSeeAlso <> 0 Then
    Write('>')
  Else
    Write(' ');
  GoToXy(63,3);
  Write(MsgOut^.GetDate + ' ' + Copy(MsgOut^.GetTime,1,5));
  TmpStr := '';
  If MsgOut^.IsPriv Then
    TmpStr := 'PRIV '
  Else
    TmpStr := '     ';
  If MsgOut^.IsRcvd Then
    TmpStr := TmpStr + 'RCVD '
  Else
    TmpStr := TmpStr + '     ';
  GoToXy(47,1);
  Write(TmpStr);
  TmpStr := '(' + Long2Str(CurrMsg) + ' of ' + Long2Str(NumInList) + ')';
  TmpStr := TmpStr + '  (' + Long2Str(NumInList - CurrMsg) + ')';
  GoToXy(60,1);
  Write(TmpStr);
  If MsgType(CurrArea) = NetMail Then
    Begin
    GoToXy(8, 5);
    If MsgOut^.IsCrash Then
      Write('Crash')
    Else
      Write('     ');
    GoToXy(15, 5);
    If MsgOut^.IsLocal Then
      Write('Local')
    Else
      Write('     ');
    GoToXY(22,5);
    If MsgOut^.IsKillSent Then
      Write('Kill')
    Else
      Write('    ');
    GoToXY(29, 5);
    If MsgOut^.IsSent Then
      Write('Sent')
    Else
      Write('    ');
    GoToXY(36, 5);
    If MsgOut^.IsFAttach Then
      Write('Attach')
    Else
      Write('      ');
    GoToXY(44, 5);
    If MsgOut^.IsFileReq Then
      Write('Freq')
    Else
      Write('    ');
    End
  Else
    Begin
    GoToXy(8, 5);
    Write ('     ');
    GoToXy(15, 5);
    Write('     ');
    GoToXy(22, 5);
    Write('    ');
    GoToXY(29, 5);
    Write('    ');
    GoToXY(36, 5);
    Write('      ');
    GoToXY(44, 5);
    Write('    ');
    End;
  GoToXY(60, 5);
  If MsgOut^.IsDeleted Then
    Write('Deleted')
  Else
    Write('       ');
  TotalLines := 0;
  TagFound := False;
  TmpStr := MsgOut^.GetString(79);
  While (((Not MsgOut^.EOM) or (Length(TmpStr) > 0)) and (TotalLines < MaxLines)) Do
    Begin
    If ((TmpStr[1] <> #1) or (DoHidden)) Then
      Begin
      If TotalLines < MaxLines Then
        Begin
        Inc(TotalLines);
        i := 1;
        While i <= Length(TmpStr) Do
          Begin
          If TmpStr[i] = #7 Then
            TmpStr[i] := ' ';
          Inc(i);
          End;
        MsgBuffer^[TotalLines] := DeTab(TmpStr, 4);
        If Not TagFound Then
          Begin
          HoldStr := Copy(TmpStr,1,3);
          If ((HoldStr = ' ˛ ') or (HoldStr = ' * ') or (HoldStr = '...') or
          (HoldStr = ' X ')) Then
            Begin
            TmpStr2 := StripTag(TmpStr);
            If Length(TmpStr2) > 0 Then
              Begin
              LastTag := TmpStr2;
              TagFound := True;
              End;
            End;
          End;
        End;
      End;
    TmpStr := MsgOut^.GetString(79);
    End;
  If HighestRead < MsgOut^.GetMsgNum Then
    HighestRead := MsgOut^.GetMsgNum;
  If LRead[CurrArea] < MsgOut^.GetMsgNum Then
    LRead[CurrArea] := MsgOut^.GetMsgNum;
  DisplayMsgTxt;
  TextAttr := CfgRec.Colors[3];
  If ((Upper(CfgRec.Name) = Upper(MsgOut^.GetTo)) And (Not MsgOut^.IsRcvd)) Then
    Begin
    If CfgRec.YourBeep Then
      Write(#7);
    MsgOut^.SetRcvd(True);
    MsgOut^.ReWriteHdr;
    End;
  End;


Procedure DisplayCurrentMsg;
  Begin
  If (CurrMsg <= NumInList) Then
    Begin
    If MsgList[SortList[CurrMsg]]^.Area <> CurrArea Then
      Begin
      If Not BadArea Then
        Begin
        If CloseMsgArea(MsgOut) Then;
        End;
      CurrArea := MsgList[SortList[CurrMsg]]^.Area;
      OpenArea(False);
      End;
    If Not BadArea Then
      Begin
      MsgOut^.SetMsgLoc(MsgList[SortList[CurrMsg]]^.MsgPos);
      MsgOut^.MsgStartUp;
      MsgOut^.MsgTxtStartUp;
      DisplayMsgHdr;
      End;
    End;
  End;




{$F+}
Procedure PutSort;
  Var
    i: Word;

  Begin
  For i := 1 to NumInList Do
    If PutElement(i) Then;
  End;


{$F+}
Procedure GetSort;
  Var
    i: Word;

  Begin
  For i := 1 to NumInList Do
    If GetElement(SortList[i]) Then;
  End;


{$F+}
Function MsgLess(Var X, Y): Boolean;
  Var
    XI: Word Absolute X;
    YI: Word Absolute Y;

  Begin
  If ((CfgRec.MsgOrder < 1) or (CfgRec.MsgOrder > 4)) Then
    CfgRec.MsgOrder := 1;
  If ((MsgList[xi]^.WasRead and MsgList[yi]^.WasRead) Or
  ((Not MsgList[xi]^.WasRead) and (Not MsgList[yi]^.WasRead))) Then
    Begin
    Case CfgRec.MsgOrder of
      1: Begin
         If MsgList[xi]^.Subj < MsgList[yi]^.Subj Then
           MsgLess := True
         Else
           Begin
           If MsgList[XI]^.Subj = MsgList[YI]^.Subj Then
             MsgLess := (MsgList[XI]^.MsgPos < MsgList[YI]^.MsgPos)
           Else
             MsgLess := False;
           End;
         End;
      2: Begin
         MsgLess := MsgList[XI]^.MsgNum < MsgList[YI]^.MsgNum;
         End;
      3: Begin
         MsgLess := MsgList[XI]^.MsgDate < MsgList[Yi]^.MsgDate;
         End;
      4: Begin
         MsgLess := MsgList[XI]^.MsgFrom < MsgList[YI]^.MsgFrom;
         End;
      End;
    End
  Else
    MsgLess := MsgList[xi]^.WasRead;
  End;


Procedure DoMsg;
  Var
    I: Word;
    DT: DateTime;
    TmpStr: String;
    TmpHigh: LongInt;

  Begin
  TmpHigh := 0;
  CloseArea;
  OpenArea(True);
  NumInList := 0;
  DoingYours := False;
  HighMsgNum := 0;
  If Not BadArea Then
    Begin
    ProcessBox('Scanning Messages', '[ Please Wait ]');
    HighestRead := MsgOut^.GetLastRead(GetUNum(MsgOutArea));
    If CfgRec.NewOnly Then
      MsgOut^.SeekFirst(HighestRead + 1)
    Else
      MsgOut^.SeekFirst(1);
    If Not MsgOut^.SeekFound Then
      MsgOut^.SeekPrior;
    While ((NumInList < MsgListSize) and (MsgOut^.SeekFound)) Do
      Begin
      MsgOut^.MsgStartUp;
      If Not Twit(MsgOut^.GetFrom) Then
        Begin
        Inc(NumInList);
        If MsgOut^.GetMsgNum > TmpHigh Then
          TmpHigh := MsgOut^.GetMsgNum;
        MsgList[NumInList]^.Subj := Upper(FixSubj(MsgOut^.GetSubj));
        MsgList[NumInList]^.MsgPos := MsgOut^.GetMsgLoc;
        MsgList[NumInList]^.MsgNum := MsgOut^.GetMsgNum;
        MsgList[NumInList]^.MsgFrom := Upper(MsgOut^.GetFrom);
        MsgList[NumInList]^.WasRead := MsgOut^.GetMsgNum <= HighestRead;
        MsgList[NumInList]^.ToYou := ((Upper(CfgRec.Name) = Upper(MsgOut^.GetTo))
          And (Not MsgOut^.IsRcvd));
        MsgList[NumInList]^.Area := CurrArea;
        TmpStr := MsgOut^.GetDate;
        DT.Year := Str2Long(Copy(TmpStr,7,2));
        If DT.Year < 80 Then
          Inc(DT.Year, 1900)
        Else
          Inc(DT.Year, 2000);
        DT.Month := Str2Long(Copy(TmpStr,1,2));
        DT.Day := Str2Long(Copy(TmpStr,4,2));
        TmpStr := MsgOut^.GetTime;
        DT.Hour := Str2Long(Copy(TmpStr,1,2));
        DT.Min := Str2Long(Copy(TmpStr,4,2));
        DT.Sec := 0;
        PackTime(DT, MsgList[NumInList]^.MsgDate);
        If MsgOut^.GetMsgNum > HighMsgNum Then
          HighMsgNum := MsgOut^.GetMsgNum;
        End;
      MsgOut^.SeekNext;
      End;
    EndProcessBox;
    If NumInList < MsgListSize Then
      LastMsg[CurrArea] := TmpHigh;
    If NumInList > 0 Then
      Begin
      ProcessBox('Sorting Messages', '[ Please Wait]');
      Case Sort(NumInList, SizeOf(Word), PutSort, MsgLess, GetSort) of
        SortSuccess:;
        SortOutOfMemory: Begin
          WriteLn('Out of Memory');
          Halt(2);
          End;
        SortTooManyElements: Begin
          Halt(3);
          End;
        End;
      EndProcessBox;
      End
    Else
      Begin
      MsgBox('No Messages found in this message area');
      FirstArea := True;
      End;
    CurrMsg := 1;
    While ((CurrMsg < NumInList) And (MsgList[SortList[CurrMsg]]^.WasRead)) Do
      Inc(CurrMsg);
    DisplayCurrentMsg;
    End;
  End;


Procedure DoYours;
  Var
    i: Word;
    HudsonDone: Boolean;
    DoSearch: Boolean;
    TmpStr: String;
    DT: DateTime;
    OrigArea: Word;

  Begin
  OrigArea := CurrArea;
  CloseArea;
  ProcessBox('Searching for Your Mail', '[ Please Wait]');
  NumInList := 0;
  DoingYours := True;
  HudsonDone := False;
  For i := 1 to DirectArea Do
    Begin
    DoSearch := True;
    If Length(MsgName(i)) > 0 Then
      Begin
      Case MsgBaseType(i) of
        'H': Begin
             If HudsonDone Then
               DoSearch := False
             Else
               Begin
               HudsonDone := True;
               End;
             End;
        End;
      If DoSearch Then
        Begin
        CurrArea := i;
        OpenArea(false);
        MsgOut^.YoursFirst(CfgRec.Name, '»»»');
        While ((MsgOut^.YoursFound) and (NumInList < MsgListSize)) Do
          Begin
          MsgOut^.MsgStartUp;
          If Not Twit(MsgOut^.GetFrom) Then
            Begin
            Inc(NumInList);
            MsgList[NumInList]^.Subj := Upper(FixSubj(MsgOut^.GetSubj));
            MsgList[NumInList]^.MsgPos := MsgOut^.GetMsgLoc;
            MsgList[NumInList]^.MsgNum := MsgOut^.GetMsgNum;
            MsgList[NumInList]^.MsgFrom := Upper(MsgOut^.GetFrom);
            MsgList[NumInList]^.WasRead := False;
            MsgList[NumInList]^.ToYou := ((Upper(CfgRec.Name) = Upper(MsgOut^.GetTo))
              And (Not MsgOut^.IsRcvd));
            If MsgBaseType(i) = 'H' Then
              MsgList[NumInList]^.Area := MsgOut^.GetSubArea
            Else
              MsgList[NumInList]^.Area := i;
            TmpStr := MsgOut^.GetDate;
            DT.Year := Str2Long(Copy(TmpStr,7,2));
            If DT.Year < 80 Then
              Inc(DT.Year, 1900)
            Else
              Inc(DT.Year, 2000);
            DT.Month := Str2Long(Copy(TmpStr,1,2));
            DT.Day := Str2Long(Copy(TmpStr,4,2));
            TmpStr := MsgOut^.GetTime;
            DT.Hour := Str2Long(Copy(TmpStr,1,2));
            DT.Min := Str2Long(Copy(TmpStr,4,2));
            DT.Sec := 0;
            PackTime(DT, MsgList[NumInList]^.MsgDate);
            End;
          MsgOut^.YoursNext;
          End;
        CloseArea;
        End;
      End;
    End;
  EndProcessBox;
  CurrMsg := 1;
  If NumInList > 0 Then
    Begin
    ProcessBox('Sorting Messages', '[ Please Wait]');
    Case Sort(NumInList, SizeOf(Word), PutSort, MsgLess, GetSort) of
      SortSuccess:;
      SortOutOfMemory:
        Begin
        WriteLn('Out of Memory');
        Halt(2);
        End;
      SortTooManyElements:
        Begin
        WriteLn('Too many msgs');
        Halt(3);
        End;
      End;
    EndProcessBox;
    CurrArea := 0;
    CurrArea := MsgList[SortList[1]]^.Area;
    OpenArea(False);
    DisplayCurrentMsg;
    End
  Else
    Begin
    MsgBox('No Messages to You found');
    FirstArea := True;
    CurrArea := OrigArea;
    OpenArea(False);
    End;
  End;


Procedure ReSort;
  Begin
  If NumInList > 0 Then
    Begin
    Case Sort(NumInList, SizeOf(Word), PutSort, MsgLess, GetSort) of
      SortSuccess:;
      SortOutOfMemory: Begin
        WriteLn('Out of Memory');
        Halt(2);
        End;
      SortTooManyElements: Begin
        Halt(3);
        End;
      End;
    End;
  CurrMsg := 1;
  While ((CurrMsg < NumInList) And (MsgList[SortList[CurrMsg]]^.WasRead)) Do
    Inc(CurrMsg);
  DisplayCurrentMsg;
  End;


Procedure DoJumpPick;
  Var
    JumpPick: PickList;

  Begin
  If Not JumpPick.InitDeluxe(2,2,79,19,ESColors,
    wBordered+wClear+wUserContents,
    70, NumInList, JumpStr,PickVertical, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  JumpPick.pkOptionsOn(pkStick);
  JumpPick.wFrame.SetFrameType(Frame1);
  JumpPick.wFrame.AddHeaderColor(
  '[     Num     Date    Time        From                     Subject        ]',
  heTC, WhiteOnBlue, BlackOnLtGray);
  JumpPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  JumpPick.SetInitialChoice(CurrMsg);
  JumpPick.Process;
  JumpPick.Erase;
  If JumpPick.GetLastCommand = ccSelect Then
    CurrMsg := JumpPick.GetLastChoice;
  JumpPick.Done;
  End;


Procedure EditTag(TagNum: Word);
  Var
    TmpStr: String;

  Begin
  TmpStr := GetTag(TagNum);
  DoTagEdit(TmpStr, TagNum);
  AddTag(TagNum, TmpStr);
  End;


Procedure GrabTag;
  Var
    i: Word;

  Begin
  i := 1;
  While ((i < MaxTags) and (Length(GetTag(i)) > 0)) Do
    Inc(i);
  If Length(GetTag(i)) = 0 Then
    Begin
    AddTag(i, LastTag);
    EditTag(i);
    End
  Else
    Write(#7);
  End;


Procedure DoTagPick(TagMode: Word);
  Var
    TagPick: PickList;

  Begin
  If Not TagPick.InitDeluxe(2,2,79,19,ESColors,
    wBordered+wClear+wUserContents,
    70, MaxTags, PickTagStr,PickVertical, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  TagPick.pkOptionsOn(pkStick);
  TagPick.wFrame.SetFrameType(Frame1);
  TagPick.wFrame.AddHeaderColor('[ TagLines ]', heTC, WhiteOnBlue, BlackOnLtGray);
  TagPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  TagPick.SetInitialChoice(CfgRec.NextTag);
  TagPick.Process;
  TagPick.Erase;
  If TagPick.GetLastCommand = ccSelect Then
    Case TagMode Of
      1: EditTag(TagPick.GetLastChoice);
      2: CfgRec.NextTag := TagPick.GetLastChoice;
      End;
  TagPick.Done;
  End;


Function GetNextNewMsgArea(Var CurrArea: Word): Boolean;
  Var
    HasWrapped: Boolean;
    SearchOver: Boolean;
    i: Word;
    InitialArea: Word;

  Begin
  InitialArea := CurrArea;
  If ((InitialArea < 1) or (InitialArea > DirectArea)) Then
    InitialArea := 1;
  HasWrapped := False;
  SearchOver := False;
  i := InitialArea;
  While Not SearchOver Do
    Begin
    If LastMsg[i] > LRead[i] Then
      Begin
      SearchOver := True;
      CurrArea := i;
      GetNextNewMsgArea := True;
      End;
    If Not SearchOver Then
      Begin
      Inc(i);
      If ((i > DirectArea) and (Not HasWrapped)) Then
        Begin
        i := 1;
        HasWrapped := True;
        End;
      If ((HasWrapped) And (i >= InitialArea)) Then
        Begin
        SearchOver := True;
        GetNextNewMsgArea := False;
        End;
      End;
    End;
  End;


Function GetPriorValidArea(Var CurrArea: Word): Boolean;
  Var
    HasWrapped: Boolean;
    SearchOver: Boolean;
    i: Word;
    InitialArea: Word;

  Begin
  InitialArea := CurrArea;
  If ((InitialArea < 1) or (InitialArea > DirectArea)) Then
    InitialArea := 1;
  HasWrapped := False;
  SearchOver := False;
  i := InitialArea;
  While Not SearchOver Do
    Begin
    If Length(MsgName(i)) > 0 Then
      Begin
      SearchOver := True;
      GetPriorValidArea := True;
      CurrArea := i;
      End;
    If Not SearchOver Then
      Begin
      Dec(i);
      If ((i < 1) and (Not HasWrapped)) Then
        Begin
        i := DirectArea;
        HasWrapped := True;
        End;
      If ((HasWrapped) And (i <= InitialArea)) Then
        Begin
        SearchOver := True;
        GetPriorValidArea := False;
        End;
      End;
    End;
  End;


Function GetPriorNewMsgArea(Var CurrArea: Word): Boolean;
  Var
    HasWrapped: Boolean;
    SearchOver: Boolean;
    i: Word;
    InitialArea: Word;

  Begin
  InitialArea := CurrArea;
  If ((InitialArea < 1) or (InitialArea > DirectArea)) Then
    InitialArea := 1;
  HasWrapped := False;
  SearchOver := False;
  i := InitialArea;
  While Not SearchOver Do
    Begin
    If LastMsg[i] > LRead[i] Then
      Begin
      SearchOver := True;
      CurrArea := i;
      GetPriorNewMsgArea := True;
      End;
    If Not SearchOver Then
      Begin
      Dec(i);
      If ((i < 1) and (Not HasWrapped)) Then
        Begin
        i := DirectArea;
        HasWrapped := True;
        End;
      If ((HasWrapped) And (i <= InitialArea)) Then
        Begin
        SearchOver := True;
        GetPriorNewMsgArea := False;
        End;
      End;
    End;
  End;


Function GetNextValidArea(Var CurrArea: Word): Boolean;
  Var
    HasWrapped: Boolean;
    SearchOver: Boolean;
    i: Word;
    InitialArea: Word;

  Begin
  InitialArea := CurrArea;
  If ((InitialArea < 1) or (InitialArea > DirectArea)) Then
    InitialArea := 1;
  HasWrapped := False;
  SearchOver := False;
  i := InitialArea;
  While Not SearchOver Do
    Begin
    If Length(MsgName(i)) > 0 Then
      Begin
      SearchOver := True;
      GetNextValidArea := True;
      CurrArea := i;
      End;
    If Not SearchOver Then
      Begin
      Inc(i);
      If ((i > DirectArea) and (Not HasWrapped)) Then
        Begin
        i := 1;
        HasWrapped := True;
        End;
      If ((HasWrapped) And (i >= InitialArea)) Then
        Begin
        SearchOver := True;
        GetNextValidArea := False;
        End;
      End;
    End;
  End;


Procedure DoPickArea;
  Var
    PickDone: Boolean;
    TmpArea: Word;

  Begin
  LoadAreaNames;
  If Not AreaSPick.InitDeluxe(2,2,76,24,ESColors,
    wBordered+wClear+wUserContents,
    25, DirectArea, AreaSStr, PickHorizontal, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  AreaSPick.pkOptionsOn(pkStick);
  AreaSPick.wFrame.SetFrameType(Frame1);
  AreaSPick.wFrame.AddShadow(shBR, shSeeThru);
  AreaSPick.wFrame.AddHeaderColor('[ Message Areas ]', heTC, WhiteOnBlue, BlackOnLtGray);
  AreaSPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  TmpArea := CurrArea + 1;
  If Not GetNextNewMsgArea(TmpArea) Then
    Begin
    If Not GetNextValidArea(TmpArea) Then
      TmpArea := 1;
    End;
  AreaSPick.SetInitialChoice(TmpArea);
  AreaSPick.GetCommandProcessor^.AddCommand(ccUser1, 1, $0009, 0); {Tab}
  AreaSPick.GetCommandProcessor^.AddCommand(ccUser2, 1, $0f00, 0); {BackTab}
  PickDone := False;
  While Not PickDone Do
    Begin
    AreaSPick.Process;
    Case AreaSPick.GetLastCommand of
      ccUser1:
        Begin
        Inc(TmpArea);
        If Not GetNextNewMsgArea(TmpArea) Then
          Begin
          If Not GetNextValidArea(TmpArea) Then
            TmpArea := 1;
          End;
        AreaSPick.SetInitialChoice(TmpArea);
        End;
      ccUser2:
        Begin
        Dec(TmpArea);
        If Not GetPriorNewMsgArea(TmpArea) Then
          Begin
          If Not GetPriorValidArea(TmpArea) Then
            TmpArea := 1;
          End;
        AreaSPick.SetInitialChoice(TmpArea);
        End;
      Else
        PickDone := True;
      End;
    End;
  AreaSPick.Erase;
  Case AreaSPick.GetLastCommand of
    ccSelect:
      Begin
      FirstArea := False;
      CurrArea := AreaSPick.GetLastChoice;
      DoMsg;
      End;
    Else
      Begin
      If BadArea Then
        MsgBox('Invalid Message Area Selected');
      End;
    End;
  AreaSPick.Done;
  UnloadAreaNames;
  End;


Procedure DoNewPickArea(Var NewArea: Word);
  Begin
  LoadAreaNames;
  If Not AreaSPick.InitDeluxe(2,2,76,24,ESColors,
    wBordered+wClear+wUserContents,
    25, DirectArea, AreaNStr,PickHorizontal, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  AreaSPick.pkOptionsOn(pkStick);
  AreaSPick.wFrame.SetFrameType(Frame1);
  AreaSPick.wFrame.AddShadow(shBR, shSeeThru);
  AreaSPick.wFrame.AddHeaderColor('[ Message Areas ]', heTC, WhiteOnBlue, BlackOnLtGray);
  AreaSPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  If CurrArea <= DirectArea Then
    AreaSPick.SetInitialChoice(NewArea);
  AreaSPick.Process;
  AreaSPick.Erase;
  If AreaSPick.GetLastCommand = ccSelect Then
    Begin
    NewArea := AreaSPick.GetLastChoice;
    End;
  AreaSPick.Done;
  UnloadAreaNames;
  End;


Procedure InitMsgWindow;
  Begin
  New(MsgWin, InitCustom(1,1,80,23, ESColors, wClear + wSaveContents));
  RefreshTitles;
  End;

Procedure InitAnsiWindow;
  Begin
  New(AnsiWin, InitCustom(1,1,80,25, ESColors, wClear + wSaveContents));
  If AnsiWin <> nil Then
    Begin
    AnsiWin^.Draw;
    TextAttr := Cyan;
    ClrScr;
    End;
  End;


Procedure FinishAnsiWindow;
  Begin
  If AnsiWin <> Nil Then
    Begin
    AnsiWin^.Erase;
    Dispose(AnsiWin, Done);
    End;
  End;


Procedure DisplayAnsiWindow;
  Var
    i: Word;
    ccnt: Word;
    TmpStr: String;
    AnsiDelay: LongInt;

  Begin
  If AnsiWin <> Nil Then
    Begin
    If CfgRec.AnsiBaud <> 0 Then
      AnsiDelay := 10000 Div CfgRec.AnsiBaud
    Else
      AnsiDelay := 0;
    AvatarChar(#12);
    For i := 1 to TotalLines Do
      Begin
      TmpStr := MsgBuffer^[i];
      If ((Copy(TmpStr,1,4) = '--- ') or (Copy(TmpStr,1,4) = '---')) Then
        Exit;
      For Ccnt := 1 to Length(TmpStr) Do
        Begin
        Case TmpStr[Ccnt] of
          '`': TmpStr[Ccnt] := #27;
          #250: TmpStr[Ccnt] := #27;
          End;
        AvatarChar(TmpStr[Ccnt]);
        If AnsiDelay <> 0 Then
          Delay(AnsiDelay);
        End;
      AvatarChar(#13);
      AvatarChar(#10);
      End;
    End;
  End;

{$F+}
Function MKGetFileProc(MsgCode: Word; Prompt: String; ForceUp,
  TrimBlanks, Writing, MustExist: Boolean;
  MaxLen: Byte; DefExt: ExtStr; Var S: String): Boolean;

  Var
    LE: LineEditor;
    Cmd: Word;
    PromptWin: StackWindowPtr;


  Begin
  MKGetFileProc := False;
  New(PromptWin, InitCustom(1,1,80,1, ESColors, wClear));
  PromptWin^.Draw;
  TextAttr := ESColors.TextColor;
  LE.Init(ESColors);
  If ForceUp Then
    LE.leEditOptionsOn(leForceUpper);
  If Not TrimBlanks Then
    LE.leEditOptionsOff(leTrimBlanks);
  LE.ReadString(Prompt,1,1, MaxLen, 40, S);
  PromptWin^.Select;
  Cmd := LE.GetLastCommand;
  LE.Done;
  If Cmd = ccQuit Then
    Begin
    PromptWin^.Erase;
    Dispose(PromptWin, Done);
    Exit;
    End;
  S := DefaultExtension(s, DefExt);
  If Writing Then
    MKGetFileProc := True
  Else
    Begin
    If ExistFile(S) or Not MustExist Then
      MKGetFileProc := True
    Else
      Write(#7, #7);
    End;
  PromptWin^.Erase;
  Dispose(PromptWin, Done);
  End;


{$F+}
Function MKEditProc(MsgCode: Word; Prompt: String;
  ForceUp, TrimBlanks: Boolean;
  MaxLen: Byte; Var S: String): Boolean;

  Var
    LE: LineEditor;
    PromptWin: StackWindowPtr;


  Begin
  New(PromptWin, InitCustom(1,1,80,1, ESColors, wClear));
  PromptWin^.Draw;
  TextAttr := ESColors.TextColor;
  LE.Init(ESColors);
  If ForceUp Then
    LE.leEditOptionsOn(leForceUpper);
  If Not TrimBlanks Then
    LE.leEditOptionsOff(leTrimBlanks);
  LE.ReadString(Prompt,1,1, MaxLen, 40, S);
  MKEditProc := (LE.GetLastCommand <> ccQuit);
  LE.Done;
  PromptWin^.Erase;
  Dispose(PromptWin, Done);
  End;



Procedure DoMsgExport(Var MsgOut: AbsMsgPtr; Var OutFile: Text);
  Var
    TAddr: AddrType;
    TmpStr: String;

  Const
    StLen = 78;

  Begin
    Write(OutFile, Long2Str(MsgOut^.GetMsgNum) + ' - ' + 'In Msg Area' +
      ' ' + Long2Str(CurrArea) +  ' - ' + MsgName(CurrArea));
  If MsgOut^.IsPriv Then
    Write(OutFile,'  ' + '(PRIV)');
  If MsgOut^.IsRcvd Then
    Write(OutFile, '  ' + '(RCVD)');
  WriteLn(OutFile);
  Write(OutFile, 'From: ');
  If (MsgType(CurrArea) = NetMail) Then
    Begin
    MsgOut^.GetOrig(TAddr);
    Write(OutFile, PadRight(MsgOut^.GetFrom + ' @ ' + AddrStr(TAddr), ' ', 45));
    End
  Else
    Write(OutFile, PadRight(MsgOut^.GetFrom,' ',45));
  Write(OutFile, 'Date:' + ' ');
  WriteLn(OutFile, ReformatDate(MsgOut^.GetDate, 'MM-DD-YY')
    + ' ' + MsgOut^.GetTime);
  Write(OutFile, 'To: ');
  If MsgType(CurrArea) = NetMail Then
    Begin
    MsgOut^.GetDest(TAddr);
    WriteLn(OutFile, MsgOut^.GetTo + ' @ ' + AddrStr(TAddr));
    End
  Else
    WriteLn(OutFile, MsgOut^.GetTo);
  Write(OutFile, 'Subj: ');
  WriteLn(OutFile,MsgOut^.GetSubj);
  WriteLn(OutFile);
  MsgOut^.MsgTxtStartUp;
  TmpStr := MsgOut^.GetString(StLen);
  While (Not MsgOut^.EOM) Do
    Begin
    WriteLn(OutFile, TmpStr);
    TmpStr := MsgOut^.GetString(StLen);
    End;
  If IoResult <> 0 Then;
  End;



Procedure CheckExport;
  Var
    OutFile: Text;

  Begin
  If MKGetFileProc(1, 'FileName for Export: ', True, True, True,
  False, 50, 'TXT', CfgRec.LastExport) Then
    Begin
    M.Select;
    If Length(CfgRec.LastExport) > 0 Then
      Begin
      If ((Not FileExist(CfgRec.LastExport)) and (Not IsDevice(CfgRec.LastExport))) Then
        Begin
        Assign(OutFile, CfgRec.LastExport);
        ReWrite(OutFile);
        If IoResult <> 0 Then;
        DoMsgExport(MsgOut, OutFile);
        Close(OutFile);
        If IoResult <> 0 Then;
        End
      Else
        Begin
        If DoYesNo('[ Append Existing ]', True) = 1 Then
          Begin
          Assign(OutFile, CfgRec.LastExport);
          Append(OutFile);
          If IoResult <> 0 Then;
          DoMsgExport(MsgOut, OutFile);
          Close(OutFile);
          If IoResult <> 0 Then;
          End
        Else
          Begin
          If DoYesNo('[ Replace Existing ]', False) = 1 Then
            Begin
            Assign(OutFile, CfgRec.LastExport);
            ReWrite(OutFile);
            If IoResult <> 0 Then;
            DoMsgExport(MsgOut, OutFile);
            Close(OutFile);
            If IoResult <> 0 Then;
            End
          Else
            MsgBox('Message Export aborted');
          End;
        End;
      End;
    End;
  End;



Procedure PrintMsg;
  Var
    OutFile: Text;

  Begin
  Assign(OutFile, CfgRec.PrnName);
  ReWrite(OutFile);
  If IoResult <> 0 Then;
  DoMsgExport(MsgOut, OutFile);
  Close(OutFile);
  If IoResult <> 0 Then;
  End;


Function GetNetOptions: Boolean;
  Var
    NetPick: PickList;

  Begin
  If Not NetPick.InitDeluxe(25,10,55,18,ESColors,
    wBordered+wClear+wUserContents,
    25, 8, PickNetStr, PickVertical, MultipleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  NetPick.pkOptionsOn(pkStick);
  NetPick.wFrame.SetFrameType(Frame1);
  NetPick.wFrame.AddShadow(shBR, shSeeThru);
  NetPick.wFrame.AddHeaderColor('[ NetMail Options ]', heTC, WhiteOnBlue, BlackOnLtGray);
  NetPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  NetPick.SetSelectMarker(' * ','');
  NetPick.AllocateSelectSet(8);
  If MsgHdrInfo.Crash Then
    NetPick.SelectItem(1)
  Else
    NetPick.DeSelectItem(1);
  If MsgHdrInfo.Direct Then
    NetPick.SelectItem(2)
  Else
    NetPick.DeSelectItem(2);
  If MsgHdrInfo.Imm Then
    NetPick.SelectItem(3)
  Else
    NetPick.DeSelectItem(3);
  If MsgHdrInfo.FileReq Then
    NetPick.SelectItem(4)
  Else
    NetPick.DeSelectItem(4);
  If MsgHdrInfo.FAttach Then
    NetPick.SelectItem(5)
  Else
    NetPick.DeSelectItem(5);
  If MsgHdrInfo.KillSent Then
    NetPick.SelectItem(6)
  Else
    NetPick.DeSelectItem(6);
  If MsgHdrInfo.NetTaglines Then
    NetPick.SelectItem(7)
  Else
    NetPick.DeSelectItem(7);
  If MsgHdrInfo.NetFido Then
    NetPick.SelectItem(8)
  Else
    NetPick.DeSelectItem(8);
  NetPick.Process;
  MsgHdrInfo.Crash := NetPick.ItemIsSelected(1);
  MsgHdrInfo.Direct := NetPick.ItemIsSelected(2);
  MsgHdrInfo.Imm := NetPick.ItemIsSelected(3);
  MsgHdrInfo.FileReq := NetPick.ItemIsSelected(4);
  MsgHdrInfo.FAttach := NetPick.ItemIsSelected(5);
  MsgHdrInfo.KillSent := NetPick.ItemIsSelected(6);
  MsgHdrInfo.NetTaglines := NetPick.ItemIsSelected(7);
  MsgHdrInfo.NetFido := NetPick.ItemIsSelected(8);
  NetPick.Erase;
  GetNetOptions := NetPick.GetLastCommand <> ccQuit;
  NetPick.Done;
  End;



Procedure EditStat(OrigMsg: LongInt; NewArea: Word);
  Begin
  HideMouse;
  Window(1,24,80,25);
  TextAttr := CfgRec.Colors[4];
  ClrScr;
  Write(' (Esc) to End     ');
  If OrigMsg = 0 Then
    WriteLn(Copy(' Message to ' + MsgHdrInfo.MsgTo + ' In ' + MsgName(NewArea),1,59))
  Else
    WriteLn(Copy(' Replying to ' + MsgHdrInfo.MsgTo + ' In ' + MsgName(NewArea),1,59));
  Write(' (F1) for Help     ');
  If CfgRec.Taglines Then
    Write(Copy(GetNextTag(CfgRec.NextTag),1,58));
  ShowMouse;
  End;


Procedure FixUp(Var Str: String);
  Var
    i: Word;

  Begin
  i := 1;
  While i <= Length(Str) Do
    Begin
    Case Str[i] of
      #0, #26: Str[i] := ' ';
      End;
    Inc(i);
    End;
  End;


Procedure DoMsgFinish(NewArea: Word; DefPriv: Boolean;  Var NewNum: LongInt);
  Const MemoBuffSize = 20000;

  Var
    TAddr: AddrType;
    NAddr: AddrType;
    TF: TFile;
    NewMsg: AbsMsgPtr;
    MEdit: ^TextEditor;
    FSize: LongInt;
    PrivWord: Word;
    TmpStr: String;
    ExecPath: String;
    P: Pointer;
    P2: Pointer;
    LastHard: Boolean;
    LastSpace: Boolean;
    TmpChk: Boolean;
    TmpCnt: Word;
    IsPriv: Boolean;
    NewBad: Boolean;
    ContMsg: Boolean;
    DT: DateTime;
    EditStatWin: StackWindowPtr;
    EditDone: Boolean;
    OutFile: File;

  Begin
  MsgSaved := False;
  ContMsg := True;
  CloseArea;
  Dispose(MsgBuffer);
  MsgHdrInfo.Crash := CfgRec.Crash;
  MsgHdrInfo.Direct := CfgRec.Direct;
  MsgHdrInfo.Imm := CfgRec.Imm;
  MsgHdrInfo.FileReq := CfgRec.FileReq;
  MsgHdrInfo.FAttach := CfgRec.FAttach;
  MsgHdrInfo.KillSent := CfgRec.KillSent;
  MsgHdrInfo.NetTaglines := CfgRec.NetTaglines;
  MsgHdrInfo.NetFido := CfgRec.NetFido;
  GetNewMsgHdr;
  If MsgType(NewArea) = NetMail Then
    ContMsg := GetNetOptions;
  If (ContMsg and (MsgType(NewArea) = NetMail)) Then
    Begin
    If MsgHdrInfo.FAttach Then
      DisplayHelp(250, P, 0);
    End;
  If ContMsg Then
    Begin
    If NewArea = DirectArea Then
      IsPriv := (DoYesNo('[ Priviledged ]', DefPriv) = 1)
    Else
      Begin
      If Config^.MsgAllowPriv(NewArea) Then
        Begin
        If Config^.MsgAllowPubl(NewArea) Then
          IsPriv := (DoYesNo('[ Priviledged ]', DefPriv) = 1)
        Else
          IsPriv := (True);
        End
      Else
        IsPriv := (False);
      End;
    End;
  If ContMsg Then
    Begin
    If ((WordCount(CfgRec.TextEd) > 0) And
    (ExistOnPath(ExtractWord(CfgRec.TextEd, 1), ExecPath))) Then
      Begin
      If SaveWindow(1,1, ScreenWidth, ScreenHeight, True, P) Then
        Begin
        HideMouse;
        DisableEventHandling;
        SetCursorType(CT);
        If ExecDosSwap(ExecPath + ' ' + TempName, False, nil, SwapPath) <> 0 Then
          Write(#7);
        EnableEventHandling;
        ShowMouse;
        RestoreWindow(1,1, ScreenWidth, ScreenHeight, True, P);
        End;
      End
    Else
      Begin
      New(MEdit);
      If MEdit = Nil Then
        Begin
        Write(#7, #7, #7);
        MsgBox('Insufficient memory for internal editor');
        End;
      If MEdit^.InitCustom(2,2,79,22,ESColors,
      DefWindowOptions or WBordered, MemoBuffSize) Then
        Begin
        MEdit^.teOptionsOn(teNoCtrlZ);
        MEdit^.teOptionsOff(teIndent + teSmartTabs + teMakeBackups);
        MEdit^.SetTabSize(5);
        MEdit^.SetMaxLength(79);
        MEdit^.SetRightMargin(72);
        MEdit^.SetGetFileProc(MKGetFileProc);
        MEdit^.SetEditProc(MKEditProc);
        MEdit^.ReadFile(TempName, FSize);
        EditorCommands.AddCommand(ccSaveExit, 1, $001b, 0); {Esc}
        EditorCommands.SetHelpProc(DisplayHelp);
        If SaveWindow(1, 24, 80, 25, True, P) Then
          EditStat(MsgHdrInfo.RefNum, NewArea);
        EditDone := False;
        MEdit^.GetCommandProcessor^.AddCommand(ccUser12, 1, $1F00, 0); {Alt-S Select Tag}
        MEdit^.GetCommandProcessor^.AddCommand(ccUser11, 1, $1400, 0); {Alt-T Taglines}
        MEdit^.GetCommandProcessor^.AddCommand(ccUser13, 1, $2400, 0); {Alt-J Jump Dos}
        While Not EditDone Do
          Begin
          MEdit^.Process;
          Case MEdit^.GetLastCommand of
            ccUser11:
              Begin
              DoTagPick(1);
              EditStat(MsgHdrInfo.RefNum, NewArea);
              MEdit^.Select;
              End;
            ccUser12:
              Begin
              DoTagPick(2);
              EditStat(MsgHdrInfo.RefNum, NewArea);
              MEdit^.Select;
              End;
            ccUser13:
              Begin
              HideMouse;
              If SaveWindow(1,1, ScreenWidth, ScreenHeight, True, P2) Then
                Begin
                Window(1,1,ScreenWidth, ScreenHeight);
                ClrScr;
                DisableEventHandling;
                SetCursorType(CT);
                If ExecDosSwap('', True, nil, SwapPath) <> 0 Then
                   Write(#7);
                EnableEventHandling;
                RestoreWindow(1,1, ScreenWidth, ScreenHeight, True, P2);
                End;
              ShowMouse;
              MEdit^.Select;
              End
            Else
              Begin
              EditDone := True;
              End;
            End;
          End;
        HideMouse;
        If P <> nil Then
          RestoreWindow(1, 24, 80, 25, True, P);
        MEdit^.Erase;
        MEdit^.Done;
        ShowMouse;
        End
      Else
        Write(#7);
      Dispose(MEdit);
      End;
    If ((WordCount(CfgRec.SpellCheck) > 0) And
    (ExistOnPath(ExtractWord(CfgRec.SpellCheck, 1), ExecPath))) Then
      Begin
      PrivWord := DoYesNo('[ Spell Check Msg ]', False);
      If PrivWord = 1 Then
        Begin
        If SaveWindow(1,1, ScreenWidth, ScreenHeight, True, P) Then
          Begin
          HideMouse;
          DisableEventHandling;
          SetCursorType(CT);
          If ExecDosSwap(ExecPath + ' ' + TempName, False, nil, SwapPath) <> 0 Then
            Write(#7);
          EnableEventHandling;
          ShowMouse;
          RestoreWindow(1,1, ScreenWidth, ScreenHeight, True, P);
          End;
        End;
      End;
    PrivWord := DoYesNo('[ Save Message ]', True);
    If PrivWord = 1 Then
      Begin
      If OpenMsgArea(NewMsg, MsgAreaId(NewArea)) Then
        NewBad := False
      Else
        Begin
        If IoResult <> 0 Then;
        GoToXy(1,1);
        WriteLn('Error opening msg base');
        NewBad := True;
        Halt(1);
        End;
      If NewMsg = Nil Then
        Begin
        NewBad := True;
        Write(#7, #7, #7);
        End
      Else
        Begin
        Case MsgType(NewArea) of
          Normal: NewMsg^.SetMailType(mmtNormal);
          EchoMail: NewMsg^.SetMailType(mmtEchoMail);
          NetMail: NewMsg^.SetMailType(mmtNetMail);
          End;
        NewMsg^.StartNewMsg;
        NewMsg^.SetPriv(IsPriv);
        NewMsg^.SetFrom(MsgHdrInfo.MsgFrom);
        NewMsg^.SetTo(MsgHdrInfo.MsgTo);
        NewMsg^.SetSubj(MsgHdrInfo.MsgSubj);
        NewMsg^.SetRefer(MsgHdrInfo.RefNum);
        NewMsg^.SetDate(DateStr(GetDosDate));
        NewMsg^.SetTime(TimeStr(GetDosDate));
        NewMsg^.SetLocal(True);
        NewMsg^.SetEcho(True);
        If NewMsgIsNet Then
          Begin
          NewMsg^.SetCrash(MsgHdrInfo.Crash);
          NewMsg^.SetFileReq(MsgHdrInfo.FileReq);
          NewMsg^.SetFAttach(MsgHdrInfo.FAttach);
          NewMsg^.SetKillSent(MsgHdrInfo.KillSent);
          End;
        If NewArea = DirectArea Then
          Config^.GetAddr(1, TAddr)
        Else
          Config^.GetMsgAddr(NewArea, TAddr);
        If NewMsgIsNet Then
          Begin
          If ParseAddr(MsgHdrInfo.MsgToAddr, TAddr, NAddr) Then
            NewMsg^.SetDest(NAddr)
          Else
            Begin
            NewMsg^.SetDest(TAddr);
            MsgBox('Invalid address format');
            End;
          End;
        If NewArea = DirectArea Then
          Config^.GetAddr(1, TAddr)
        Else
          Config^.GetMsgAddr(NewArea, TAddr);
        NewMsg^.SetOrig(TAddr);
        TF.Init;
        LastHard := True;
        LastSpace := True;
        If TF.OpenTextFile(TempName) Then;
        If NewMsgIsNet Then
          Begin
          If MsgHdrInfo.Direct or MsgHdrInfo.Imm Then
            Begin
            If MsgHdrInfo.Imm Then
              Begin
              TmpStr := #1 + 'FLAGS IMM';
              If MsgHdrInfo.Direct Then
                TmpStr := TmpStr + ',DIR';
              End
            Else
              If MsgHdrInfo.Direct Then
               TmpStr := #1 + 'FLAGS DIR';
            NewMsg^.DoStringLn(TmpStr);
            End;
          End;
        TmpStr := TF.GetString;
        While TF.StringFound Do
          Begin
          If Not LastHard Then
            Begin
            If Length(TmpStr) = 0 Then
              NewMsg^.DoChar(#13)
            Else If ((TmpStr[1] =  ' ') or (TmpStr[1] = #9)) Then
              NewMsg^.DoChar(#13)
            Else
              Begin
              TmpChk := False;
              TmpCnt := 1;
              While ((TmpCnt < Length(TmpStr)) and (TmpCnt < 9)) Do
                Begin
                If ((TmpStr[TmpCnt] = '>') Or (TmpStr[TmpCnt] > #127)) Then
                  TmpChk := True;
                Inc(TmpCnt);
                End;
              If (TmpChk) Then
                NewMsg^.DoChar(#13)
              Else
                Begin
                If Not LastSpace Then
                  NewMsg^.DoChar(' ');
                End;
              End;
            End;
          If Length(TmpStr) = 0 Then
            Begin
            NewMsg^.DoStringLn(TmpStr);
            LastHard := True;
            End
          Else
            Begin
            If Length(TmpStr) < 50 Then
              Begin
              NewMsg^.DoStringLn(TmpStr);
              LastHard := True;
              End
            Else
              Begin
              NewMsg^.DoString(TmpStr);
              LastHard := False;
              End;
            End;
          LastSpace := TmpStr[Length(TmpStr)] = ' ';
          TmpStr := TF.GetString;
          End;
        If TF.CloseTextFile Then;
        TF.Done;
        If Not LastHard Then
          NewMsg^.DoChar(#13);
        NewMsg^.DoChar(#13);
        If ( (((MsgType(NewArea) = NetMail) And (MsgHdrInfo.NetTaglines)) Or
          ((MsgType(NewArea) <> NetMail) And CfgRec.TagLines ))
          And (NumTags > 0)) Then
          Begin
          TmpStr := GetNextTag(CfgRec.NextTag);
          Inc(CfgRec.NextTag);
          If Length(TmpStr) > 0 Then
            Begin
            NewMsg^.DoStringLn(' * MKRead v1.04 * ' + Copy(TmpStr, 1, 60));
            NewMsg^.DoStringLn('');
            End;
          End;
        Case MsgType(NewArea) of
          Normal:;
          EchoMail:
            Begin
            If (Config^.MsgAddFido(NewArea)) Then
              Begin
              NewMsg^.DoStringLn('---');
              NewMsg^.DoStringLn(Config^.GetDefaultOrigStr(NewArea));
              End;
            End;
          NetMail:
            Begin
            If MsgHdrInfo.NetFido Then
              Begin
              NewMsg^.DoStringLn('---');
              If NewArea < DirectArea Then
                NewMsg^.DoStringLn(Config^.GetDefaultOrigStr(NewArea))
              Else
                Begin
                Config^.GetAddr(1, TAddr);
                NewMsg^.DoStringLn(' * Origin: MKRead NetMail  (' +
                  AddrStr(TAddr) + ')');
                End;
              End;
            End;
          End;
        If NewMsg^.WriteMsg = 0 Then
          Begin
          MsgSaved := True;
          NewNum := NewMsg^.GetMsgNum;
          If ((MsgType(NewArea) = EchoMail)
          and (Length(Config^.GetEchoAreaTag(NewArea)) > 0)) Then
            WriteLogEntry(Config^.GetEchoAreaTag(NewArea));
          If NewArea = DirectArea Then
            EnterDirect := True
          Else
            Begin
            Case MsgType(NewArea) of
              EchoMail: EnterEcho := True;
              NetMail: EnterNet := True;
              End;
            End;
          End;
        If ((NewArea = CurrArea) and (NumInList < MsgListSize)) Then
          Begin
          Inc(NumInList);
          MsgList[NumInList]^.Subj := Upper(FixSubj(NewMsg^.GetSubj));
          MsgList[NumInList]^.MsgPos := NewMsg^.GetMsgLoc;
          MsgList[NumInList]^.MsgNum := NewMsg^.GetMsgNum;
          MsgList[NumInList]^.MsgFrom := Upper(NewMsg^.GetFrom);
          MsgList[NumInList]^.WasRead := False;
          MsgList[NumInList]^.ToYou := ((Upper(CfgRec.Name) = Upper(NewMsg^.GetTo))
            And (Not NewMsg^.IsRcvd));
          MsgList[NumInList]^.Area := NewArea;
          TmpStr := NewMsg^.GetDate;
          DT.Year := Str2Long(Copy(TmpStr,7,2));
          If DT.Year < 80 Then
            Inc(DT.Year, 1900)
          Else
           Inc(DT.Year, 2000);
          DT.Month := Str2Long(Copy(TmpStr,1,2));
          DT.Day := Str2Long(Copy(TmpStr,4,2));
          TmpStr := NewMsg^.GetTime;
          DT.Hour := Str2Long(Copy(TmpStr,1,2));
          DT.Min := Str2Long(Copy(TmpStr,4,2));
          DT.Sec := 0;
          PackTime(DT, MsgList[NumInList]^.MsgDate);
          SortList[NumInList] := NumInList;
          End;
        LastMsg[NewArea] := NewMsg^.GetMsgNum;
        If CloseMsgArea(NewMsg) Then;
        End;
      End;
    End;
  New(MsgBuffer);
  OpenArea(False);
  If MsgBuffer = Nil Then
    Begin
    Write(#7, #7, #7);
    Halt;
    End;
  Assign(OutFile, TempName);
  Erase(OutFile);
  If IoResult <> 0 Then;
  Assign(OutFile, BackName);
  Erase(OutFile);
  If IoResult <> 0 Then;
  DisplayCurrentMsg;
  End;


Function ParseOrig(TmpStr: String): String;
  Var
    SPos: Word;
    EPos: Word;

  Begin
  ParseOrig := '';
  EPos := Length(TmpStr);
  While ((TmpStr[EPos] <> ')') and (EPos > 0)) Do
    Dec(EPos);
  Dec(EPos);
  If EPos > 0 Then
    Begin
    SPos := EPos - 1;
    While ((TmpStr[Spos] <> '(') and (Spos > 0)) Do
      Dec(Spos);
    If Spos > 0 Then
      Begin
      Inc(Spos);
      While ((Not (TmpStr[Spos] in ['0'..'9'])) and (TmpStr[Spos] <> ')')) Do
        Inc(Spos);
      If Spos < EPos Then
        ParseOrig := Copy(TmpStr, Spos, (EPos + 1 - Spos));
      End;
    End;
  End;


Function EchoAddr(Var MsgOut: AbsMsgPtr): String;
  Var
    TmpStr: String;
    TmpOrg: String;

  Begin
  TmpOrg := '';
  MsgOut^.MsgTxtStartUp;
  TmpStr := MsgOut^.GetString(100);
  While Not MsgOut^.EOM Do
    Begin
    If Copy(TmpStr, 1, 10) = ' * Origin:' Then
      TmpOrg := ParseOrig(TmpStr);
    TmpStr := MsgOut^.GetString(100);
    End;
  EchoAddr := TmpOrg;
  End;


Procedure StripPrior(Var TmpStr: String; PriorQuote: String);
  Var
    PriorPos: Word;
    TmpStr2: String;

  Begin
  If Length(PriorQuote) > 0 Then
    Begin
    PriorPos := Pos(PriorQuote, TmpStr);
    While (PriorPos > 0) Do
      Begin
      If PriorPos = 1 Then
        TmpStr2 := ''
      Else
        TmpStr2 := Copy(TmpStr,1, PriorPos - 1);
      If ((PriorPos = 1) or ((TmpStr[PriorPos - 1] = ' ') or
      (TmpStr[PriorPos + Length(PriorQuote)] = ' '))) Then
        TmpStr := TmpStr2 + Copy(TmpStr, PriorPos + Length(PriorQuote), 255)
      Else
        TmpStr := TmpStr2 + ' ' + Copy(TmpStr, PriorPos + Length(PriorQuote), 255);
      PriorPos := Pos(PriorQuote, TmpStr);
      End;
    End;
  End;


Procedure DoReply;
  Var
    TxtCtr: Word;
    i: Word;
    TAddr: AddrType;
    QuoteStr: String[30];
    TmpStr: String;
    TmpStr2: String;
    PrivWord: Word;
    LastCR: Boolean;
    NewArea: Word;
    F: File;
    OutFile: Text;
    QuoteHdr: String;
    PriorQuote: String[8];
    NewNum: LongInt;

  Begin
  Assign(OutFile, TempName);
  Erase(OutFile);
  If IoResult <> 0 Then;
  NewArea := CurrArea;
  DoNewPickArea(NewArea);
  TxtCtr := 0;
  FillChar(MsgHdrInfo, SizeOf(MsgHdrInfo), #0);
  NewMsgIsNet := (MsgType(NewArea) = NetMail);
  MsgHdrInfo.MsgFrom := CfgRec.Name;
  MsgHdrInfo.MsgSubj := MsgOut^.GetSubj;
  MsgHdrInfo.MsgTo := MsgOut^.GetFrom;
  MsgHdrInfo.RefNum := MsgOut^.GetMsgNum;
  If NewMsgIsNet Then
    Begin
    Case MsgType(CurrArea) of
      NetMail:
        Begin
        MsgOut^.GetOrig(TAddr);
        MsgHdrInfo.MsgToAddr := AddrStr(TAddr);
        End;
      EchoMail: MsgHdrInfo.MsgToAddr := EchoAddr(MsgOut);
      End;
    End;
  QuoteStr := '';
  TmpStr := CfgRec.QuoteStr;
  i := 1;
  While i <= Length(TmpStr) Do
    Begin
    If TmpStr[i] <> '@' Then
      QuoteStr := QuoteStr + TmpStr[i]
    Else
      Begin
      If WordCount (MsgOut^.GetFrom) > 0 Then
        QuoteStr := QuoteStr + Copy(ExtractWord(MsgOut^.GetFrom,1),1,1);
      If WordCount (MsgOut^.GetFrom) > 1 Then
        QuoteStr := QuoteStr + Copy(ExtractWord(MsgOut^.GetFrom,2),1,1);
      If WordCount (MsgOut^.GetFrom) > 2 Then
        QuoteStr := QuoteStr + Copy(ExtractWord(MsgOut^.GetFrom,3),1,1);
      End;
    Inc(i);
    End;
  i := 0;
  MsgOut^.MsgTxtStartUp;
  Assign(OutFile, TempName);
  ReWrite(OutFile);
  If IoResult <> 0 Then;
  QuoteHdr := CvtQuoteStr(CfgRec.QuoteHdr, MsgOut);
  If Length(QuoteHdr) > 0 Then
    WriteLn(OutFile, QuoteHdr);
  QuoteStr := StripTrail(QuoteStr, ' ');
  PriorQuote := QuoteStr;
  ExtraString := '';
  TmpStr := MsgOut^.GetString(150);
  While ((Length(TmpStr) > 0) Or (Not MsgOut^.EOM)) Do
    Begin
    If TmpStr[1] <> #1 Then
      Begin
      If Length(StripBoth(TmpStr, ' ')) > 0 Then
        Begin
        If Pos('>', Copy(TmpStr, 1, 8)) > 0 Then
          PriorQuote := Copy(TmpStr,1, Pos('>', Copy(TmpStr,1,8)))
        Else
          PriorQuote := QuoteStr;
        StripPrior(TmpStr, PriorQuote);
        While (((Length(TmpStr) > 72)) Or
        ((Length(TmpStr) > 0) and (MsgOut^.EOM))) Do
          Begin
          If ((TmpStr[1] = ' ') or (Length(PriorQuote) = 0)) Then
            TmpStr := PriorQuote + TmpStr
          Else
            TmpStr := PriorQuote + ' ' + TmpStr;
          TmpStr := WWrap(TmpStr, 72);
          FixUp(TmpStr);
          WriteLn(OutFile, TmpStr);
          If IoResult <> 0 Then;
          TmpStr := ExtraString;
          End;
        If ((TmpStr[1] = ' ') or (Length(PriorQuote) = 0)) Then
          ExtraString := PriorQuote + TmpStr
        Else
          ExtraString := PriorQuote + ' '+ TmpStr;
        End
      Else
        Begin
        WriteLn(OutFile, '');
        If IoResult <> 0 Then;
        TmpStr := '';
        ExtraString := '';
        End;
      End
    Else
      Begin
      While ((MsgOut^.WasWrap) and (Not MsgOut^.EOM)) Do
        TmpStr := MsgOut^.GetString(150);
      ExtraString := '';
      End;
    TmpStr := MsgOut^.GetString(150);
    While ((TmpStr[1] = #1) and (Not MsgOut^.EOM)) Do
      Begin
      TmpStr := MsgOut^.GetString(150);
      End;
    If TmpStr[1] = #1 Then
      TmpStr := '';
    If ((Copy(TmpStr,1,Length(PriorQuote)) <> PriorQuote) and (Pos('>', Copy(TmpStr,1,8)) > 0)) or
    (TmpStr[1] = ' ') or (Length(TmpStr) = 0) or (TmpStr[1] = '-') Then
      Begin
      If Length(ExtraString) > 0 Then
        Begin
        FixUp(ExtraString);
        WriteLn(OutFile, ExtraString);
        End;
      If IoResult <> 0 Then;
      ExtraString := '';
      End;
    If MsgOut^.EOM Then
      TmpStr := ExtraString
    Else
      Begin
      ExtraString := StripTrail(ExtraString,' ');
      If TmpStr[1] = ' ' Then
        TmpStr := ExtraString + TmpStr
      Else
        TmpStr := ExtraString + ' ' + TmpStr;
      End;
    ExtraString := '';
    End;
  Close(OutFile);
  If IoResult <> 0 Then;
  NewNum := 0;
  DoMsgFinish(NewArea, MsgOut^.IsPriv, NewNum);
  If ((NewNum <> 0) and (MsgOut^.GetSeeAlso = 0)) Then
    Begin
    MsgOut^.SetSeeAlso(NewNum);
    MsgOut^.ReWriteHdr;
    End;
  End;


Procedure DoEnterNew;
  Var
    NewArea: Word;
    F: File;
    NewNum: LongInt;

  Begin
  NewArea := CurrArea;
  DoNewPickArea(NewArea);
  FillChar(MsgHdrInfo, SizeOf(MsgHdrInfo), #0);
  NewMsgIsNet := (MsgType(NewArea) = NetMail);
  MsgHdrInfo.MsgFrom := CfgRec.Name;
  MsgHdrInfo.MsgSubj := '';
  MsgHdrInfo.MsgTo := '';
  MsgHdrInfo.MsgToAddr := '';
  MsgHdrInfo.RefNum := 0;
  If FileExist(TempName) Then
    Begin
    Assign(F, TempName);
    Erase(F);
    If IoResult <> 0 Then;
    End;
  If SaveFile(TempName, CfgRec, 0) = 0 Then;
  DoMsgFinish(NewArea, False, NewNum);
  End;


Procedure ForwardMsg;
  Var
    OldHdr: String;
    OldPrfx: String;
    OldTag: Boolean;

  Begin
  OldHdr := CfgRec.QuoteHdr;
  OldPrfx := CfgRec.QuoteStr;
  OldTag := CfgRec.Taglines;
  CfgRec.QuoteHdr := 'Message forwarded via MKRead||';
  CfgRec.QuoteStr := '';
  CfgRec.Taglines := False;
  DoReply;
  CfgRec.QuoteHdr := OldHdr;
  CfgRec.QuoteStr := OldPrfx;
  CfgRec.Taglines := OldTag;
  End;


Procedure ReEditMsg;
  Var
    OldHdr: String;
    OldPrfx: String;
    OldTag: Boolean;

  Begin
  OldHdr := CfgRec.QuoteHdr;
  OldPrfx := CfgRec.QuoteStr;
  OldTag := CfgRec.Taglines;
  CfgRec.QuoteHdr := '';
  CfgRec.QuoteStr := '';
  CfgRec.Taglines := False;
  DoReply;
  CfgRec.QuoteHdr := OldHdr;
  CfgRec.QuoteStr := OldPrfx;
  CfgRec.Taglines := OldTag;
  If MsgSaved Then
    Begin
    MsgOut^.DeleteMsg;
    Inc(CurrMsg);
    DisplayCurrentMsg;
    End;
  End;



Procedure DoMenu;
  Var
  MenuDone: Boolean;
  OS: Word;
  TmpStr: String;
  ch: Char;
  P: Pointer;
  i: Word;
  NextChoice: Word;

  Begin
  MenuDone := False;
  NextChoice := miNext2;
  While Not MenuDone Do
    Begin
    If (((BadArea) Or (NumInList = 0)) And (Not FirstArea) and false) Then
      Begin
      DoPickArea;
      M.Select;
      End
    Else
      Begin
      M.DefaultPath(NextChoice);
      M.Select;
      M.Process;
      Case M.GetLastCommand Of
        ccSelect:
          Begin
          case M.MenuChoice of
            miArea0:
              Begin
              DoPickArea;
              M.Select;
              NextChoice := miNext2;
              End;
            miPrior1:
              Begin
              If (CurrMsg > 1) Then
                Begin
                Dec(CurrMsg);
                DisplayCurrentMsg;
                NextChoice := miPrior1;
                End
              Else
                Begin
                Write(#7);
                NextChoice := miArea0;
                End;
              M.Select;
              End;
            miNext2:
              Begin
              If (CurrMsg < NumInList) Then
                Begin
                Inc(CurrMsg);
                DisplayCurrentMsg;
                NextChoice := miNext2;
                End
              Else
                DoPickArea;
              M.Select;
              End;
            miExport3:
              Begin
              CheckExport;
              M.Select;
              End;
            miReply4:
              Begin
              DoReply;
              M.Select;
              End;
            miEnter5:
              Begin
              DoEnterNew;
              M.Select;
              End;
            miPg7:
              Begin
              If TopLine < (TotalLines - 1) Then
                Begin
                  If TotalLines - TopLine > NumTxtLines Then
                  Inc(TopLine, NumTxtLines)
                Else
                  TopLine := TotalLines;
                DisplayMsgTxt;
                End;
              M.Select;
              End;
            miPg8:
              Begin
              If TopLine > 1 Then
                Begin
                If TopLine > NumTxtLines Then
                  Dec(TopLine, NumTxtLines)
                Else
                  TopLine := 1;
                DisplayMsgTxt;
                End;
              M.Select;
              End;
            miConfig9:
              Begin
              EditCfg;
              DisplayCurrentMsg;
              M.Select;
              M.SetAllNormAttr(CfgRec.Colors[4], CfgRec.Colors[4]);
              M.SetAllHighAttr(CfgRec.Colors[5], CfgRec.Colors[5]);
              M.SetAllSelectAttr(CfgRec.Colors[6], CfgRec.Colors[6]);
              M.Redraw;
              H.SetTextAttr(CfgRec.Colors[5], CfgRec.Colors[5]);
              H.Erase;
              H.Draw;
              M.Select;
              End;
            miJump10:
              Begin
              DoJumpPick;
              DisplayCurrentMsg;
              M.Select;
              End;
            miDelete11:
              Begin
              If ((Not BadArea) and (NumInList > 0)) Then
                Begin
                If DoYesNo('[ Delete Message ]', False) = 1 Then
                  MsgOut^.DeleteMsg;
                End;
              M.Select;
              End;
            miShell12:
              Begin
              HideMouse;
              If SaveWindow(1,1, ScreenWidth, ScreenHeight, True, P) Then
                Begin
                Window(1,1,ScreenWidth, ScreenHeight);
                ClrScr;
                DisableEventHandling;
                SetCursorType(CT);
                If ExecDosSwap('', True, nil, SwapPath) <> 0 Then
                   Write(#7);
                EnableEventHandling;
                RestoreWindow(1,1, ScreenWidth, ScreenHeight, True, P);
                End;
              ShowMouse;
              M.Select;
              End;
            miView13:
              Begin
              InitAnsiWindow;
              DisplayAnsiWindow;
              ch := ReadKey;
              FinishAnsiWindow;
              M.Select;
              End;
            miUp14:
              Begin
              If TopLine > 1 Then
                Begin
                Dec(TopLine);
                DisplayMsgTxt;
                End;
              M.Select;
              End;
            miDn15:
              Begin
              If TopLine < (TotalLines - 1) Then
                Begin
                Inc(TopLine);
                DisplayMsgTxt;
                End;
              M.Select;
              End;
            miYour16:
              Begin
              DoYours;
              M.Select;
              End;
            miQuit6:
              Begin
              OS := DoYesNo('[ Exit Program ]', True);
              Case OS of
                1: MenuDone := True;
                2: ; {Not done}
                End;
              M.Select;
              End;
            End;
          End;
        ccUser1:
          Begin
          If TopLine > 1 Then
            Begin
            Dec(TopLine);
            DisplayMsgTxt;
            End;
          M.Select;
          End;
        ccUser2:
          Begin
          If TopLine < (TotalLines - 1) Then
            Begin
            Inc(TopLine);
            DisplayMsgTxt;
            End;
          M.Select;
          End;
        ccUser3:
          Begin
          If TopLine > 1 Then
            Begin
            If TopLine > NumTxtLines Then
              Dec(TopLine, NumTxtLines)
            Else
              TopLine := 1;
            DisplayMsgTxt;
            End;
          M.Select;
          End;
        ccUser4:
          Begin
          If TopLine < (TotalLines - 1) Then
            Begin
            If (TotalLines - TopLine) > NumTxtLines Then
              Inc(TopLine, NumTxtLines)
            Else
              TopLine := TotalLines;
            DisplayMsgTxt;
            End;
          M.Select;
          End;
        ccUser5:
          Begin
          EditCfg;
          DisplayCurrentMsg;
          M.Select;
          M.SetAllNormAttr(CfgRec.Colors[4], CfgRec.Colors[4]);
          M.SetAllHighAttr(CfgRec.Colors[5], CfgRec.Colors[5]);
          M.SetAllSelectAttr(CfgRec.Colors[6], CfgRec.Colors[6]);
          M.Redraw;
          H.SetTextAttr(CfgRec.Colors[5], CfgRec.Colors[5]);
          H.Erase;
          H.Draw;
          M.Select;
          End;
        ccUser6:
          Begin
          MsgOut^.SetRcvd(Not MsgOut^.IsRcvd);
          MsgOut^.ReWriteHdr;
          MsgWin^.Select;
          TextAttr := CfgRec.Colors[3];
          If MsgOut^.IsRcvd Then
            TmpStr := 'RCVD '
          Else
            TmpStr := '     ';
          GoToXy(52,1);
          Write(TmpStr);
          M.Select;
          End;
        ccUser7:
          Begin
          If ((Not BadArea) and (NumInList > 0)) Then
            Begin
            If DoYesNo('[ Delete Message ]', False) = 1 Then
              MsgOut^.DeleteMsg;
            End;
          M.Select;
          End;
        ccUser8:
          Begin
          DoEnterNew;
          M.Select;
          End;
        ccUser9:
          Begin
          CurrMsg := 1;
          DisplayCurrentMsg;
          M.Select;
          End;
        ccUser10:
          Begin
          CurrMsg := NumInList;
          DisplayCurrentMsg;
          M.Select;
          End;
        ccUser11:
          Begin
          DoTagPick(1);
          M.Select;
          End;
        ccUser12:
          Begin
          DoTagPick(2);
          M.Select;
          End;
        ccUser13:
          Begin
          ReSort;
          M.Select;
          End;
        ccUser14:
          Begin
          If Length(LastTag) > 0 Then
            GrabTag
          Else
            Write(#7);
          M.Select;
          End;
        ccUser15:
          Begin
          ForwardMsg;
          M.Select;
          End;
        ccUser16:
          Begin
          DoHidden := Not DoHidden;
          DisplayCurrentMsg;
          M.Select;
          End;
        ccUser17: {re-edit}
          Begin
          ReEditMsg;
          M.Select;
          End;
        ccUser18: {Orig msg}
          Begin
          If NumInList > 0 Then
            Begin
            i := 1;
            While ((i < NumInList) and
            (MsgList[SortList[i]]^.MsgNum <> MsgOut^.GetRefer)) Do
              Inc(i);
            If MsgList[SortList[i]]^.MsgNum = MsgOut^.GetRefer Then
              CurrMsg := i
            Else
              MsgBox('Orig Msg Not Found');
            DisplayCurrentMsg;
            End;
          M.Select;
          End;
        ccUser19: {Reply msg}
          Begin
          If NumInList > 0 Then
            Begin
            i := 1;
            While ((i < NumInList) and
            (MsgList[SortList[i]]^.MsgNum <> MsgOut^.GetSeeAlso)) Do
              Inc(i);
            If MsgList[SortList[i]]^.MsgNum = MsgOut^.GetSeeAlso Then
              CurrMsg := i
            Else
              MsgBox('Reply Msg Not Found');
            DisplayCurrentMsg;
            End;
          M.Select;
          End;
        ccUser20: {Print Msg}
          Begin
          PrintMsg;
          M.Select;
          End;
        ccQuit:
          Begin
          OS := DoYesNo('[ Exit Program ]', True);
          Case OS of
            1: MenuDone := True;
            2: ; {Not done}
            End;
          M.Select;
          End;
        End;
      End;
    End;
  End;


Procedure LoadCfg;
  Begin
  If Length(CfgName) = 0 Then
    CfgName := Config^.GetBbsPath + 'MKRead.Cfg';
  FillChar(CfgRec, SizeOf(CfgRec), 0);
  CfgRec.Colors[1] := ESColors.TextColor;
  CfgRec.Colors[2] := ESColors.HighItemColor;
  CfgRec.Colors[3] := ESColors.TextColor;
  CfgRec.Colors[4] := MenuColors.TextColor;
  CfgRec.Colors[5] := MenuColors.HighItemColor;
  CfgRec.Colors[6] := MenuColors.SelItemColor;
  CfgRec.Colors[7] := ESColors.TextColor;
  If FileExist(CfgName) Then
    Begin
    If LoadFile(CfgName, CfgRec, SizeOf(CfgRec)) = 0 Then;
    End
  Else
    Begin
    CfgRec.QuoteStr := ' @>';
    CfgRec.MsgOrder := 1;
    CfgRec.Taglines := True;
    EditCfg;
    End;
  If CfgRec.Colors[7] = 0 Then
    CfgRec.Colors[7] := CfgRec.Colors[1];
  ESColors.HighItemColor := CfgRec.Colors[2];
  ESColors.TextColor := CfgRec.Colors[3];
  MenuColors.TextColor := CfgRec.Colors[4];
  MenuColors.HighItemColor := CfgRec.Colors[5];
  MenuColors.SelItemColor := CfgRec.Colors[6];
  If Length(CfgRec.PrnName) = 0 Then
    CfgRec.PrnName := 'PRN';
  End;


Begin
DoingYours := False;
SwapPath := FExpand('MKRead.Tmp');
InitNamePtr;
DetectMultitasking := True;
ReInitCrt;
CT := ClassifyCursorType;
If Not ((CT = cuNormal) or (CT = cuFat) or (CT = cuBlock)) Then
  CT := cuNormal;
If BbsType = 0 Then
  Begin
  If Length(GetEnv('MKR')) > 0 Then
    BbsType := 99
  Else
    BbsType := DetectBbsType;
  End;
Case BbsType Of
  1: Config := New(MKRCfgObjPtr, Init);
  2: Begin
     If FileExist('Config.RA') Then
       Begin
       Status := SizeFile('Config.Ra');
       End
     Else
       Begin
       Status := SizeFile(WithBackSlash(GetEnv('RA')) + 'Config.Ra');
       End;
     If Status < 6300 Then
       Config := New(RARCfgObjPtr, Init)
     Else
       Config := New(R2RCfgObjPtr, Init);
     End;
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  5: Config := New(EzRCfgObjPtr, Init);
  99: Config := New(TxtCfgObjPtr, Init);
  End;
If BBSType = 0 Then
  Begin
  WriteLn('Fatal Error: Environment variable not found');
  Halt(42);
  End;
For i := 1 to MsgListSize Do
  New(MsgList[i]);
InitTags;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  ClrScr;
  WriteLn('Error loading BBS/Text Config file for type ', BBSType);
  WriteLn('Error #',Config^.GetError);
  WriteLn;
  Halt(10);
  End;
LoadCfg;
InitAnsiWindow;
DoMKRBanner;
TextAttr := LtCyanOnBlack;
GoToXY(40,10);
Case BBSType of
  1: DStr := 'Mythical Kingdom BBS';
  2: DStr := 'Remote Access BBS';
  3: Begin
     DStr := 'QuickBBS';
     HudsonEcho := Config^.GetBbsPath;
     End;
  4: Begin
     HudsonLast := Config^.GetBbsPath;
     DStr := 'SuperBbs';
     End;
  5: Begin
     DStr := 'EzyCom BBS';
     EzLastRecSize := EzRCfgObjPtr(Config)^.GetEzyLastSize;
     EzLastPath := EzRCfgObjPtr(Config)^.GetUserPath;
     End;
  99: DStr := 'MKRead Text Config';
  End;
GoToXy( 54 - (Length(DStr) Div 2), 10);
Write(DStr);
If FileExist('Taglines.MK') Then
  LoadTags('Taglines.MK')
Else
  LoadTags(Config^.GetBbsPath + 'Taglines.MK');
TextAttr := LtGreenOnBlack;
DStr := Long2Str(NumTags);
GoToXy(11 - (Length(Dstr) Div 2), 20);
Write(DStr);
GetLRead;
GetLastMsgs;
LoadTwits;
EnterNet := False;
EnterDirect := False;
EnterEcho := False;
FinishAnsiWindow;
TextAttr := LtGrayOnBlack;
TextChar := #176;
ClrScr;
CurrArea := 0;
DoHidden := False;
LastTag := '';
New(MsgBuffer);
TopLine := 1;
InitMsgWindow;
BadArea := True;
Status := InitMenu(M);
if Status <> 0 then
  begin
  WriteLn('Error initializing menu: ', Status);
  Halt(1);
  end;
Status := InitHelpLine(H);
if Status <> 0 then
  begin
  WriteLn('Error initializing help line: ', Status);
  Halt(1);
  end;
M.SetCurrentItemProc(UpdateHelpLine);
if MouseInstalled then
  with ESColors do
    begin
    {activate mouse cursor}
    SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
    ShowMouse;
    {enable mouse support}
    MenuCommands.cpOptionsOn(cpEnableMouse);
    End;
M.GetCommandProcessor^.AddCommand(ccUser1,  1, $4800, 0); {Up}
M.GetCommandProcessor^.AddCommand(ccUser2,  1, $5000, 0); {Down}
M.GetCommandProcessor^.AddCommand(ccUser3,  1, $4900, 0); {PgUp}
M.GetCommandProcessor^.AddCommand(ccUser4,  1, $5100, 0); {PgDn}
M.GetCommandProcessor^.AddCommand(ccUser6,  1, $003d, 0); {= recv toggle}
M.GetCommandProcessor^.AddCommand(ccUser8,  1, $5200, 0); {Ins enter}
M.GetCommandProcessor^.AddCommand(ccUser11, 1, $1400, 0); {Alt-T Taglines}
M.GetCommandProcessor^.AddCommand(ccUser12, 1, $1F00, 0); {Alt-S Select Tag}
M.GetCommandProcessor^.AddCommand(ccUser13, 1, $1300, 0); {Alt-R Re-Sort msgs}
M.GetCommandProcessor^.AddCommand(ccUser14, 1, $2200, 0); {Alt-G Grab tagline}
M.GetCommandProcessor^.AddCommand(ccUser15, 1, $2100, 0); {Alt-F forward msg}
M.GetCommandProcessor^.AddCommand(ccUser16, 1, $2500, 0); {Alt-K kludge toggle}
M.GetCommandProcessor^.AddCommand(ccUser5,  1, $2e00, 0); {Alt-C Config}
M.GetCommandProcessor^.AddCommand(ccUser20, 1, $1900, 0); {Alt-P Print Msg}
M.GetCommandProcessor^.AddCommand(ccUser7,  1, $5300, 0); {Del delete}
M.GetCommandProcessor^.AddCommand(ccUser9,  1, $4700, 0); {Home 1st msg}
M.GetCommandProcessor^.AddCommand(ccUser10, 1, $4f00, 0); {End last msg}
M.GetCommandProcessor^.AddCommand(ccUser17, 1, $1200, 0); {Alt-E Edit msg}
M.GetCommandProcessor^.AddCommand(ccUser18, 1, Ord('<'), 0); { < orig msg}
M.GetCommandProcessor^.AddCommand(ccUser19, 1, Ord('>'), 0); { > reply to msg}
H.Draw;
M.Draw;
FirstArea := True;
DoPickArea;
M.Select;
DoMenu;
M.Erase;
H.Erase;
HideMouse;
H.Done;
M.Done;
Dispose(MsgWin, Done);
Dispose(MsgBuffer);
CloseArea;
ClrScr;
If SaveFile(CfgName, CfgRec, SizeOf(CfgRec)) = 0 Then;
If FileExist('Taglines.MK') Then
  SaveTags('Taglines.MK')
Else
  SaveTags(Config^.GetBbsPath + 'Taglines.MK');
FreeTags;
Dispose(Config, Done);
For i := 1 To MsgListSize Do
  Dispose(MsgList[i]);
SetCursorType(CT);
ExitLevel := 0;
If EnterNet Then
  Inc(ExitLevel, 1);
If EnterEcho Then
  Inc(ExitLevel, 2);
If EnterDirect Then
  Inc(ExitLevel, 4);
Halt(ExitLevel);
End.
