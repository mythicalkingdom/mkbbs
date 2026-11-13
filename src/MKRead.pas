Program MKRead;

{$I MKB.Def}
{$R-}

{
     MKRead - local mode message reader for the sysop (Free Vision version).

     The reader draws its old 80 x 25 screen into the virtual screen (MKVCrt)
     as before; the screen view below shows that on the Free Vision desktop,
     and the menu bar and dialogs of Free Vision replace the Object Professional
     menu, pick lists and windows.
}

Uses
  Dos, Objects, Drivers, Views, Dialogs, Menus, App, Editors, StdDlg,
  MKVCrt, MKString, MKFile, MKCfgAbs, MKRCfgRA, MKCfgSB, MKCfgQB, MKRCfgMK,
  MKCfgTxt, MKGlobT, MKMsgAbs, MKOpen, MKRCfgEz, MKMsgHud, MKMsgEzy, MKMsgJam,
  MKRCfgR2, MKReadCf, MKMisc, MKDos, HdrEnt, MKEnter, QuoteCvt, MkTagLn,
  MKAvatar, MKRBan, MKReadO, CfgBox, CfgList;

Const
  TempName = 'MsgTmp.MK';
  BackName = 'MsgTmp.Bak';
  NumTxtLines = 16;


{------------------------------------------------ the screen on the desktop}

Type
  PScreenView = ^ScreenView;
  ScreenView = Object(TView)
    FirstRow: Integer;                 {Row of the virtual screen shown first (0 based)}
    Constructor Init(Var R: TRect; AFirstRow: Integer);
    Procedure Draw; Virtual;
    End;

Var
  Scr: PScreenView;                    {The message screen}
  AnsiV: PScreenView;                  {The full screen Ansi / splash view}

Constructor ScreenView.Init(Var R: TRect; AFirstRow: Integer);
  Begin
  Inherited Init(R);
  FirstRow := AFirstRow;
  End;


Procedure ScreenView.Draw;
  Var
    B: TDrawBuffer;
    X, Y: Integer;

  Begin
  For Y := 0 To Size.Y - 1 Do
    Begin
    For X := 0 To Size.X - 1 Do
      B[X] := VScreen^[(Y + FirstRow) * VCols + X];
    WriteLine(0, Y, Size.X, 1, B);
    End;
  End;


Function DeTab(S: String; TabSize: Byte): String;
  {Tabs to spaces (next multiple of TabSize)}
  Var
    R: String;
    i: Word;

  Begin
  R := '';
  For i := 1 To Length(S) Do
    If S[i] = #9 Then
      Begin
      Repeat
        R := R + ' ';
      Until (Length(R) Mod TabSize = 0) Or (Length(R) >= 250);
      End
    Else If Length(R) < 255 Then
      R := R + S[i];
  DeTab := R;
  End;


Procedure Refresh;
  {Show what has been drawn on the virtual screen}
  Begin
  If Scr <> Nil Then
    Scr^.DrawView;
  If AnsiV <> Nil Then
    AnsiV^.DrawView;
  End;

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

  TopLine: Word;
  Status : Word;

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


  Window(1,1,80,6);
  TextAttr := CfgRec.Colors[2];
  ClrScr;
  Window(1,1,80,23);
  GoToXy(2,1);
  Write(VOut, 'Area:');
  GoToXy(2,2);
  Write(VOut, 'From:');
  GoToXy(2,3);
  Write(VOut, 'To:');
  GoToXy(2,4);
  Write(VOut, 'Subj:');
  GoToXy(2,6);
  Write(VOut, PadRight('','ƒ',78));
  GoToXy(2,23);
  Write(VOut, PadRight('','ƒ',78));
  GoToXy(57,2);
  Write(VOut, 'Msg:');
  GoToXy(57,3);
  Write(VOut, 'Date:');
  Window(1,7,80,22);
  TextAttr := CfgRec.Colors[1];
  ClrScr;
  Window(1,1,80,23);
  Refresh;
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

    RefreshTitles;

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
{------------------------------------------------ list texts}

Function AreaSStr(Item: Word): String;
  Begin
  If LastMsg[Item] > LRead[Item] Then
    AreaSStr := PadRight(Long2Str(Item), ' ', 3) + ' * ' + GetAreaName(Item)
  Else
    AreaSStr := PadRight(Long2Str(Item), ' ', 3) + '   ' + GetAreaName(Item);
  End;


Function AreaNStr(Item: Word): String;
  Begin
  AreaNStr := PadRight(Long2Str(Item), ' ', 3) + ' ' + GetAreaName(Item);
  End;


Function JumpStr(Item: Word): String;
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
  JumpStr := TmpStr + PadLeft(Long2Str(MsgList[SortList[Item]]^.MsgNum), ' ', 6) + '  ' +
    DateStr(MsgList[SortList[Item]]^.MsgDate) + ' ' +
    Copy(TimeStr(MsgList[SortList[Item]]^.MsgDate), 1, 5) + '  ' +
    PadRight(Copy(Proper(MsgList[SortList[Item]]^.MsgFrom), 1, 20), ' ', 20) + '  ' +
    PadRight(Copy(Proper(MsgList[SortList[Item]]^.Subj), 1, 22), ' ', 22);
  End;


Function PickTagStr(Item: Word): String;
  Begin
  PickTagStr := PadLeft(Long2Str(Item), ' ', 4) + '  ' + Copy(GetTag(Item), 1, 60);
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
  TextAttr := LightGreen;
  For Item := 1 to DirectArea Do
    LRead[Item] := 0;
  For Item := 1 to DirectArea Do
    Begin
    DStr := PadRight(Long2Str(Item), ' ', 4);
    GoToXy(66, 20);
    Write(VOut, DStr);
    Refresh;
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
    Write(VOut, DStr);
    Refresh;
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
    Write(VOut, TmpStr);
    End;
  Refresh;
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

  TextAttr := CfgRec.Colors[3];
  GoToXY(8,1);
  Write(VOut, PadRight(Long2Str(CurrArea),' ',4));
  Write(VOut, PadRight(Copy(MsgName(CurrArea),1,25),' ',25));
  GoToXY(8,2);
  MsgOut^.GetOrig(TAddr);
  If MsgIsNet Then
    Write(VOut, PadRight(MsgOut^.GetFrom + ' @ ' + AddrStr(TAddr),' ', 45))
  Else
    Write(VOut, PadRight(MsgOut^.GetFrom,' ', 45));
  GoToXY(8,3);
  MsgOut^.GetDest(TAddr);
  If MsgIsNet Then
    Write(VOut, PadRight(MsgOut^.GetTo + ' @ ' + AddrStr(TAddr),' ', 45))
  Else
    Write(VOut, PadRight(MsgOut^.GetTo,' ', 45));
  GoToXY(8,4);
  Write(VOut, Copy(PadRight(MsgOut^.GetSubj,' ',69),1,69));
  GoToXy(63,2);
  Write(VOut, PadLeft(Long2Str(MsgOut^.GetMsgNum),' ',8));
  GoToXy(74,2);
  If MsgOut^.GetRefer <> 0 Then
    Write(VOut, '<')
  Else
    Write(VOut, ' ');
  GoToXy(76, 2);
  If MsgOut^.GetSeeAlso <> 0 Then
    Write(VOut, '>')
  Else
    Write(VOut, ' ');
  GoToXy(63,3);
  Write(VOut, MsgOut^.GetDate + ' ' + Copy(MsgOut^.GetTime,1,5));
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
  Write(VOut, TmpStr);
  TmpStr := '(' + Long2Str(CurrMsg) + ' of ' + Long2Str(NumInList) + ')';
  TmpStr := TmpStr + '  (' + Long2Str(NumInList - CurrMsg) + ')';
  GoToXy(60,1);
  Write(VOut, TmpStr);
  If MsgType(CurrArea) = NetMail Then
    Begin
    GoToXy(8, 5);
    If MsgOut^.IsCrash Then
      Write(VOut, 'Crash')
    Else
      Write(VOut, '     ');
    GoToXy(15, 5);
    If MsgOut^.IsLocal Then
      Write(VOut, 'Local')
    Else
      Write(VOut, '     ');
    GoToXY(22,5);
    If MsgOut^.IsKillSent Then
      Write(VOut, 'Kill')
    Else
      Write(VOut, '    ');
    GoToXY(29, 5);
    If MsgOut^.IsSent Then
      Write(VOut, 'Sent')
    Else
      Write(VOut, '    ');
    GoToXY(36, 5);
    If MsgOut^.IsFAttach Then
      Write(VOut, 'Attach')
    Else
      Write(VOut, '      ');
    GoToXY(44, 5);
    If MsgOut^.IsFileReq Then
      Write(VOut, 'Freq')
    Else
      Write(VOut, '    ');
    End
  Else
    Begin
    GoToXy(8, 5);
    Write ('     ');
    GoToXy(15, 5);
    Write(VOut, '     ');
    GoToXy(22, 5);
    Write(VOut, '    ');
    GoToXY(29, 5);
    Write(VOut, '    ');
    GoToXY(36, 5);
    Write(VOut, '      ');
    GoToXY(44, 5);
    Write(VOut, '    ');
    End;
  GoToXY(60, 5);
  If MsgOut^.IsDeleted Then
    Write(VOut, 'Deleted')
  Else
    Write(VOut, '       ');
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
  Refresh;
  End;
{------------------------------------------------ sorting the message list}

Function MsgLess(XI, YI: Word): Boolean; Forward;

Procedure SortMessages;
  {Sorts SortList[1..NumInList] (message numbers in MsgList) by MsgLess; stable}
  Var
    Tmp: Array[1..MsgListSize + 1] Of Word;
    i: Word;

  Procedure MSort(Lo, Hi: Word);
    Var
      Mid, a, b, k: Word;

    Begin
    If Lo >= Hi Then
      Exit;
    Mid := (Lo + Hi) Div 2;
    MSort(Lo, Mid);
    MSort(Mid + 1, Hi);
    a := Lo;
    b := Mid + 1;
    k := Lo;
    While (a <= Mid) And (b <= Hi) Do
      Begin
      If MsgLess(SortList[b], SortList[a]) Then
        Begin
        Tmp[k] := SortList[b];
        Inc(b);
        End
      Else
        Begin
        Tmp[k] := SortList[a];
        Inc(a);
        End;
      Inc(k);
      End;
    While a <= Mid Do
      Begin
      Tmp[k] := SortList[a];
      Inc(a);
      Inc(k);
      End;
    While b <= Hi Do
      Begin
      Tmp[k] := SortList[b];
      Inc(b);
      Inc(k);
      End;
    For k := Lo To Hi Do
      SortList[k] := Tmp[k];
    End;

  Begin
  For i := 1 To NumInList Do
    SortList[i] := i;
  MSort(1, NumInList);
  End;


Function MsgLess(XI, YI: Word): Boolean;
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
      SortMessages;
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
    SortMessages;
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
    SortMessages;
    End;
  CurrMsg := 1;
  While ((CurrMsg < NumInList) And (MsgList[SortList[CurrMsg]]^.WasRead)) Do
    Inc(CurrMsg);
  DisplayCurrentMsg;
  End;


Procedure DoJumpPick;
  Var
    Chosen: Word;

  Begin
  If NumInList = 0 Then
    Exit;
  Chosen := CurrMsg;
  If RunPick('Jump to Message',
       NumInList, 73, JumpStr, Chosen) Then
    CurrMsg := Chosen;
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
    Chosen: Word;

  Begin
  Chosen := CfgRec.NextTag;
  If (Chosen < 1) Or (Chosen > MaxTags) Then
    Chosen := 1;
  If RunPick('TagLines', MaxTags, 66, PickTagStr, Chosen) Then
    Case TagMode Of
      1: EditTag(Chosen);
      2: CfgRec.NextTag := Chosen;
      End;
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


{------------------------------------------------ area lists}

Function NavArea(Cur: Word; Forward: Boolean): Word;
  {Tab / Shift-Tab in the area list: the next / previous area with new mail}
  Var
    T: Word;

  Begin
  T := Cur;
  If Forward Then
    Begin
    Inc(T);
    If Not GetNextNewMsgArea(T) Then
      If Not GetNextValidArea(T) Then
        T := 1;
    End
  Else
    Begin
    Dec(T);
    If Not GetPriorNewMsgArea(T) Then
      If Not GetPriorValidArea(T) Then
        T := 1;
    End;
  NavArea := T;
  End;


Procedure DoPickArea;
  Var
    Chosen: Word;

  Begin
  LoadAreaNames;
  Chosen := CurrArea + 1;
  If Not GetNextNewMsgArea(Chosen) Then
    If Not GetNextValidArea(Chosen) Then
      Chosen := 1;
  If RunPickNav('Message Areas  (Tab: next area with new mail)',
       DirectArea, 40, AreaSStr, Chosen, NavArea) Then
    Begin
    FirstArea := False;
    CurrArea := Chosen;
    DoMsg;
    End
  Else
    If BadArea Then
      MsgBox('Invalid Message Area Selected');
  UnloadAreaNames;
  End;


Procedure DoNewPickArea(Var NewArea: Word);
  Var
    Chosen: Word;

  Begin
  LoadAreaNames;
  Chosen := NewArea;
  If RunPick('Message Areas', DirectArea, 40, AreaNStr, Chosen) Then
    NewArea := Chosen;
  UnloadAreaNames;
  End;


{------------------------------------------------ the Ansi view and splash screen}

Procedure InitAnsiWindow;
  {Full screen view of the virtual screen; the message screen is kept}
  Var
    R: TRect;

  Begin
  If AnsiV = Nil Then
    Begin
    Application^.GetExtent(R);
    AnsiV := New(PScreenView, Init(R, 0));
    Application^.Insert(AnsiV);
    End;
  TextAttr := Cyan;
  ClrScr;
  Refresh;
  End;


Procedure FinishAnsiWindow;
  Begin
  If AnsiV <> Nil Then
    Begin
    Application^.Delete(AnsiV);
    Dispose(AnsiV, Done);
    AnsiV := Nil;
    End;
  End;


Procedure DisplayAnsiWindow;
  Var
    i: Word;
    ccnt: Word;
    TmpStr: String;
    AnsiDelay: LongInt;

  Begin
  If AnsiV <> Nil Then
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
        Begin
        Refresh;
        Exit;
        End;
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
      If AnsiDelay <> 0 Then
        Refresh;
      End;
    Refresh;
    End;
  End;


Procedure WaitAnsiKey;
  {Wait for a key or a click on the Ansi view}
  Var
    E: TEvent;

  Begin
  Repeat
    Application^.GetEvent(E);
    If E.What = evNothing Then
      Application^.Idle;
  Until (E.What = evKeyDown) Or (E.What = evMouseDown);
  End;


Procedure InitMsgWindow;
  Begin
  RefreshTitles;
  End;


{------------------------------------------------ prompts}

Function DefaultExtension(Name, Ext: String): String;
  Begin
  If (Pos('.', Name) = 0) And (Ext <> '') And (Name <> '') Then
    Name := Name + '.' + Ext;
  DefaultExtension := Name;
  End;


Function MKGetFileProc(MsgCode: Word; Prompt: String; ForceUp,
  TrimBlanks, Writing, MustExist: Boolean;
  MaxLen: Byte; DefExt: String; Var S: String): Boolean;
  Var
    Tmp: String;

  Begin
  MKGetFileProc := False;
  Tmp := S;
  If Not InputLine('Export Message', Prompt, MaxLen, Tmp) Then
    Exit;
  If TrimBlanks Then
    Tmp := StripBoth(Tmp, ' ');
  S := DefaultExtension(Tmp, Lower(DefExt));
  If Writing Then
    MKGetFileProc := True
  Else
    If FileExist(S) or Not MustExist Then
      MKGetFileProc := True
    Else
      Write(#7);
  End;


{------------------------------------------------ the message editor}

Type
  PMsgEditWin = ^MsgEditWin;
  MsgEditWin = Object(TEditWindow)
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    End;


Procedure MsgEditWin.HandleEvent(Var Event: TEvent);
  Begin
  If ((Event.What = evKeyDown) And ((Event.KeyCode = kbEsc) Or (Event.KeyCode = kbF10) Or
      (Event.KeyCode = kbCtrlW))) Or
     ((Event.What = evCommand) And (Event.Command = cmClose)) Then
    Begin
    If Valid(cmClose) Then              {asks whether to save a changed text}
      EndModal(cmOK);
    ClearEvent(Event);
    End
  Else
    Inherited HandleEvent(Event);
  End;


Procedure EditMessageText(FN: String);
  {First version: the plain Free Vision text editor on the message file.  Esc
   closes it (it asks whether to save).  Word wrap, quoting help and tag line keys
   come in later versions.}
  Var
    R: TRect;
    W: PMsgEditWin;

  Begin
  DeskTop^.GetExtent(R);
  W := New(PMsgEditWin, Init(R, FN, wnNoNumber));
  If W <> Nil Then
    Begin
    DeskTop^.ExecView(W);
    Dispose(W, Done);
    End;
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
    M: CfgMarks;

  Begin
  FillChar(M, SizeOf(M), 0);
  M[1] := MsgHdrInfo.Crash;
  M[2] := MsgHdrInfo.Direct;
  M[3] := MsgHdrInfo.Imm;
  M[4] := MsgHdrInfo.FileReq;
  M[5] := MsgHdrInfo.FAttach;
  M[6] := MsgHdrInfo.KillSent;
  M[7] := MsgHdrInfo.NetTaglines;
  M[8] := MsgHdrInfo.NetFido;
  GetNetOptions := RunChecks('NetMail Options', 'Crash|Direct|Immediate|File Request|' +
    'File Attach|Kill after sending|Add Netmail Taglines|Add Netmail Origin', M);
  MsgHdrInfo.Crash := M[1];
  MsgHdrInfo.Direct := M[2];
  MsgHdrInfo.Imm := M[3];
  MsgHdrInfo.FileReq := M[4];
  MsgHdrInfo.FAttach := M[5];
  MsgHdrInfo.KillSent := M[6];
  MsgHdrInfo.NetTaglines := M[7];
  MsgHdrInfo.NetFido := M[8];
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
      AttachHelp;
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
    EditMessageText(TempName);
    PrivWord := DoYesNo('[ Save Message ]', True);
    If PrivWord = 1 Then
      Begin
      If OpenMsgArea(NewMsg, MsgAreaId(NewArea)) Then
        NewBad := False
      Else
        Begin
        If IoResult <> 0 Then;
        MsgBox('Error opening msg base');
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


{------------------------------------------------ settings file}

Procedure LoadCfg;
  Begin
  If Length(CfgName) = 0 Then
    CfgName := Config^.GetBbsPath + 'MKRead.Cfg';
  FillChar(CfgRec, SizeOf(CfgRec), 0);
  CfgRec.Colors[1] := $1E;             {yellow on blue, as the old window colours}
  CfgRec.Colors[2] := $1F;
  CfgRec.Colors[3] := $1E;
  CfgRec.Colors[4] := $1E;
  CfgRec.Colors[5] := $1F;
  CfgRec.Colors[6] := $3E;
  CfgRec.Colors[7] := $1E;
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
  If Length(CfgRec.PrnName) = 0 Then
    CfgRec.PrnName := 'PRN';
  End;


{------------------------------------------------ commands}

Const
  cmArea = 3000;
  cmPrior = 3001;
  cmNext = 3002;
  cmExport = 3003;
  cmReply = 3004;
  cmEnterMsg = 3005;
  cmPgDn = 3006;
  cmPgUp = 3007;
  cmConfig = 3008;
  cmJump = 3009;
  cmDelete = 3010;
  cmView = 3011;
  cmLineUp = 3012;
  cmLineDn = 3013;
  cmYours = 3014;
  cmQuitMk = 3015;
  cmRcvdToggle = 3016;
  cmForwardMsg = 3017;
  cmResortMsgs = 3018;
  cmGrabTagline = 3019;
  cmEditTags = 3020;
  cmSelectTag = 3021;
  cmKludge = 3022;
  cmReEdit = 3023;
  cmOrigMsg = 3024;
  cmReplyMsg = 3025;
  cmPrintMsg = 3026;
  cmFirstMsg = 3027;
  cmLastMsg = 3028;
  cmMkHelp = 3029;

Type
  MkrApp = Object(TApplication)
    Constructor Init;
    Procedure InitMenuBar; Virtual;
    Procedure InitStatusLine; Virtual;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Procedure DoCommand(Cmd: Word);
    Procedure Startup;
    End;

  PMkrStatus = ^MkrStatus;
  MkrStatus = Object(TStatusLine)
    Function Hint(AHelpCtx: Word): String; Virtual;
    End;


Function MkrStatus.Hint(AHelpCtx: Word): String;
  Begin
  Case AHelpCtx Of
    cmArea: Hint := 'Select message area';
    cmPrior: Hint := 'Previous message';
    cmNext: Hint := 'Next message';
    cmExport: Hint := 'Export message to a text file';
    cmReply: Hint := 'Reply to message';
    cmEnterMsg: Hint := 'Enter a new message';
    cmPgDn: Hint := 'Page down in the message text';
    cmPgUp: Hint := 'Page up in the message text';
    cmConfig: Hint := 'Configure MKRead';
    cmJump: Hint := 'Jump to a specific message';
    cmDelete: Hint := 'Delete the current message';
    cmView: Hint := 'View Ansi/Avatar message';
    cmYours: Hint := 'Find messages to you';
    cmQuitMk: Hint := 'Quit';
    Else Hint := '';
    End;
  End;


Constructor MkrApp.Init;
  Var
    R: TRect;

  Begin
  Inherited Init;
  DeskTop^.GetExtent(R);
  Scr := New(PScreenView, Init(R, 0));
  DeskTop^.Insert(Scr);
  End;


Procedure MkrApp.InitMenuBar;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewItem('~A~rea', '', kbNoKey, cmArea, cmArea,
    NewItem('~P~rev', '', kbNoKey, cmPrior, cmPrior,
    NewItem('~N~ext', '', kbNoKey, cmNext, cmNext,
    NewItem('E~x~port', '', kbNoKey, cmExport, cmExport,
    NewItem('~R~eply', '', kbNoKey, cmReply, cmReply,
    NewItem('~E~nter', '', kbNoKey, cmEnterMsg, cmEnterMsg,
    NewItem('+P~g~', '', kbNoKey, cmPgDn, cmPgDn,
    NewItem('-Pg', '', kbNoKey, cmPgUp, cmPgUp,
    NewItem('~C~fg', '', kbNoKey, cmConfig, cmConfig,
    NewItem('~J~ump', '', kbNoKey, cmJump, cmJump,
    NewItem('~D~el', '', kbNoKey, cmDelete, cmDelete,
    NewItem('~V~iew', '', kbNoKey, cmView, cmView,
    NewItem('~Y~our', '', kbNoKey, cmYours, cmYours,
    NewItem('~Q~uit', '', kbNoKey, cmQuitMk, cmQuitMk,
    Nil)))))))))))))))));
  End;


Procedure MkrApp.InitStatusLine;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New(PMkrStatus, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F1~ Help', kbF1, cmMkHelp,
      NewStatusKey('~Enter~ Next', kbNoKey, cmNext,
      NewStatusKey('~Alt-X~ Quit', kbAltX, cmQuitMk, Nil))),
    Nil)));
  End;


Procedure MkrApp.DoCommand(Cmd: Word);
  Var
    i: Word;
    TmpStr: String;

  Begin
  Case Cmd Of
    cmArea: DoPickArea;
    cmPrior:
      Begin
      If (CurrMsg > 1) And (Not BadArea) Then
        Begin
        Dec(CurrMsg);
        DisplayCurrentMsg;
        End
      Else
        Write(#7);
      End;
    cmNext:
      Begin
      If (CurrMsg < NumInList) And (Not BadArea) Then
        Begin
        Inc(CurrMsg);
        DisplayCurrentMsg;
        End
      Else
        DoPickArea;
      End;
    cmExport: If Not BadArea Then CheckExport;
    cmReply: If (Not BadArea) And (NumInList > 0) Then DoReply;
    cmEnterMsg: DoEnterNew;
    cmPgDn:
      If TopLine < (TotalLines - 1) Then
        Begin
        If TotalLines - TopLine > NumTxtLines Then
          Inc(TopLine, NumTxtLines)
        Else
          TopLine := TotalLines;
        DisplayMsgTxt;
        End;
    cmPgUp:
      If TopLine > 1 Then
        Begin
        If TopLine > NumTxtLines Then
          Dec(TopLine, NumTxtLines)
        Else
          TopLine := 1;
        DisplayMsgTxt;
        End;
    cmLineUp:
      If TopLine > 1 Then
        Begin
        Dec(TopLine);
        DisplayMsgTxt;
        End;
    cmLineDn:
      If TopLine < (TotalLines - 1) Then
        Begin
        Inc(TopLine);
        DisplayMsgTxt;
        End;
    cmConfig:
      Begin
      EditCfg;
      DisplayCurrentMsg;
      End;
    cmJump:
      Begin
      DoJumpPick;
      DisplayCurrentMsg;
      End;
    cmDelete:
      If (Not BadArea) And (NumInList > 0) Then
        If DoYesNo('[ Delete Message ]', False) = 1 Then
          MsgOut^.DeleteMsg;
    cmView:
      If (Not BadArea) And (NumInList > 0) Then
        Begin
        InitAnsiWindow;
        DisplayAnsiWindow;
        WaitAnsiKey;
        FinishAnsiWindow;
        DisplayCurrentMsg;
        End;
    cmYours: DoYours;
    cmQuitMk:
      If DoYesNo('[ Exit Program ]', True) = 1 Then
        EndModal(cmQuit);
    cmRcvdToggle:
      If (Not BadArea) And (NumInList > 0) Then
        Begin
        MsgOut^.SetRcvd(Not MsgOut^.IsRcvd);
        MsgOut^.ReWriteHdr;
        TextAttr := CfgRec.Colors[3];
        If MsgOut^.IsRcvd Then
          TmpStr := 'RCVD '
        Else
          TmpStr := '     ';
        GoToXy(52, 1);
        Write(VOut, TmpStr);
        Refresh;
        End;
    cmForwardMsg: If (Not BadArea) And (NumInList > 0) Then ForwardMsg;
    cmResortMsgs: ReSort;
    cmGrabTagline:
      If Length(LastTag) > 0 Then
        GrabTag
      Else
        Write(#7);
    cmEditTags: DoTagPick(1);
    cmSelectTag: DoTagPick(2);
    cmKludge:
      Begin
      DoHidden := Not DoHidden;
      DisplayCurrentMsg;
      End;
    cmReEdit: If (Not BadArea) And (NumInList > 0) Then ReEditMsg;
    cmOrigMsg:
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
    cmReplyMsg:
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
    cmPrintMsg: If (Not BadArea) And (NumInList > 0) Then PrintMsg;
    cmFirstMsg:
      If NumInList > 0 Then
        Begin
        CurrMsg := 1;
        DisplayCurrentMsg;
        End;
    cmLastMsg:
      If NumInList > 0 Then
        Begin
        CurrMsg := NumInList;
        DisplayCurrentMsg;
        End;
    cmMkHelp: MenuHelp;
    End;
  Refresh;
  End;


Procedure MkrApp.HandleEvent(Var Event: TEvent);
  Var
    Cmd: Word;

  Begin
  Cmd := 0;
  If Event.What = evKeyDown Then
    Begin
    Case Event.KeyCode Of
      kbUp: Cmd := cmLineUp;
      kbDown: Cmd := cmLineDn;
      kbPgUp: Cmd := cmPgUp;
      kbPgDn: Cmd := cmPgDn;
      kbHome: Cmd := cmFirstMsg;
      kbEnd: Cmd := cmLastMsg;
      kbIns: Cmd := cmEnterMsg;
      kbDel: Cmd := cmDelete;
      kbEnter: Cmd := cmNext;
      kbBack: Cmd := cmPrior;
      kbAltT: Cmd := cmEditTags;
      kbAltS: Cmd := cmSelectTag;
      kbAltR: Cmd := cmResortMsgs;
      kbAltG: Cmd := cmGrabTagline;
      kbAltF: Cmd := cmForwardMsg;
      kbAltK: Cmd := cmKludge;
      kbAltC: Cmd := cmConfig;
      kbAltP: Cmd := cmPrintMsg;
      kbAltE: Cmd := cmReEdit;
      kbF1: Cmd := cmMkHelp;
      Else
        Case UpCase(Event.CharCode) Of
          '=': Cmd := cmRcvdToggle;
          '<': Cmd := cmOrigMsg;
          '>': Cmd := cmReplyMsg;
          '+': Cmd := cmPgDn;
          '-': Cmd := cmPgUp;
          'A': Cmd := cmArea;
          'P': Cmd := cmPrior;
          'N': Cmd := cmNext;
          'X': Cmd := cmExport;
          'R': Cmd := cmReply;
          'E': Cmd := cmEnterMsg;
          'C': Cmd := cmConfig;
          'J': Cmd := cmJump;
          'D': Cmd := cmDelete;
          'V': Cmd := cmView;
          'Y': Cmd := cmYours;
          'Q': Cmd := cmQuitMk;
          End;
      End;
    If Cmd <> 0 Then
      Begin
      ClearEvent(Event);
      DoCommand(Cmd);
      Exit;
      End;
    End;
  Inherited HandleEvent(Event);
  If Event.What = evCommand Then
    Begin
    If (Event.Command >= cmArea) And (Event.Command <= cmMkHelp) Then
      Begin
      Cmd := Event.Command;
      ClearEvent(Event);
      DoCommand(Cmd);
      End;
    End;
  End;


Procedure MkrApp.Startup;
  Var
    BBSName: String;

  Begin
  LoadCfg;
  InitAnsiWindow;
  DoMKRBanner;
  TextAttr := LightCyan;
  GoToXY(40, 10);
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
  GoToXy(54 - (Length(DStr) Div 2), 10);
  Write(VOut, DStr);
  If FileExist('Taglines.MK') Then
    LoadTags('Taglines.MK')
  Else
    LoadTags(Config^.GetBbsPath + 'Taglines.MK');
  TextAttr := LightGreen;
  DStr := Long2Str(NumTags);
  GoToXy(11 - (Length(Dstr) Div 2), 20);
  Write(VOut, DStr);
  Refresh;
  GetLRead;
  GetLastMsgs;
  LoadTwits;
  EnterNet := False;
  EnterDirect := False;
  EnterEcho := False;
  FinishAnsiWindow;
  TextAttr := LightGray;
  ClrScr;
  CurrArea := 0;
  DoHidden := False;
  LastTag := '';
  New(MsgBuffer);
  TopLine := 1;
  InitMsgWindow;
  BadArea := True;
  FirstArea := True;
  Refresh;
  DoPickArea;
  End;


{------------------------------------------------ the program}

Var
  Reader: MkrApp;

Begin
DoingYours := False;
SwapPath := FExpand('MKRead.Tmp');
InitNamePtr;
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
       Status := SizeFile('Config.Ra')
     Else
       Status := SizeFile(WithBackSlash(GetEnv('RA')) + 'Config.Ra');
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
  WriteLn(StdErr, 'Fatal Error: Environment variable not found (MK, RA, QUICK, SBBS, EZY or MKR)');
  Halt(42);
  End;
For i := 1 to MsgListSize Do
  New(MsgList[i]);
InitTags;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, 'Error loading BBS/Text Config file for type ', BBSType);
  WriteLn(StdErr, 'Error #', Config^.GetError);
  Halt(10);
  End;
Scr := Nil;
AnsiV := Nil;
EditorDialog := StdEditorDialog;     {the editor's own "save changes?" and error boxes}
Reader.Init;
Reader.Startup;
Reader.Run;
Reader.Done;
Dispose(MsgBuffer);
CloseArea;
If SaveFile(CfgName, CfgRec, SizeOf(CfgRec)) = 0 Then;
If FileExist('Taglines.MK') Then
  SaveTags('Taglines.MK')
Else
  SaveTags(Config^.GetBbsPath + 'Taglines.MK');
FreeTags;
Dispose(Config, Done);
For i := 1 To MsgListSize Do
  Dispose(MsgList[i]);
ExitLevel := 0;
If EnterNet Then
  Inc(ExitLevel, 1);
If EnterEcho Then
  Inc(ExitLevel, 2);
If EnterDirect Then
  Inc(ExitLevel, 4);
Halt(ExitLevel);
End.
