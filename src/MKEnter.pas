Unit MKEnter;
{$I MKB.Def}

Interface

Uses MKGlobT;

Const
  MaxMsgLength = 120;


Type MsgLinePtrArray = Array[1..MaxMsgLength] of ^String;


Type MsgEnterType = Record
  ML: MsgLinePtrArray;
  ContMsg: Word;
  CurrLine: Word;
  Area: Word;
  Reference: Word;
  MsgSubj: String[72];
  MsgFrom: String[35];
  MsgTo: String[35];
  Priv: Boolean;
  DestAddr: AddrType;
  NewMsgNum: Word;
  End;


Type MsgEntObj = Object
  ME: ^ MsgEnterType;
  Constructor Init;                         {Initialize}
  Destructor Done;                          {Done}
  Procedure GetText;                        {Get message text}
  Procedure MsgTest(Sec: SecType);          {Testing}
  Procedure SetTo(Str: String);             {Set msg to}
  Function  GetTo: String;                  {Get msg to}
  Procedure SetSubj(Str: String);           {Set msg subj}
  Function  GetSubj: String;                {Get msg subject}
  Procedure SetFrom(Str: String);           {Set msg from}
  Function  GetFrom: String;                {Get msg from}
  Procedure SetArea(Area: Word);            {Set msg area number}
  Procedure SetDest(Addr: AddrType);        {Set netmail destination address}
  Procedure GetDest(Var Addr: AddrType);    {Get dest addr}
  Function  GetPriv: Boolean;               {Get msg priv status}
  Procedure SetPriv(Pr: Boolean);           {Set private}
  Procedure SetRefer(RF: Word);             {Set orig reference msg}
  Procedure AddStr(Str: String); {Internal - add string}
  Function  GetMsgNum: Word;                {Get new msg number}
  Procedure InsertStr(Str: String; InsertLine: Word); {Internal - insert
    string prior to insertline line}
  Procedure DelStr(Start: Word; Stop: Word); {Internal - Delete range of
    text strings}
  Procedure ReplStr(Str: String; LineNo: Word); {Internal - replace
    string at LineNo with Str}
  Procedure AskTo;                          {Ask who msg is to}
  Procedure AskPriv(Def: Boolean);          {Ask if msg is priviledged}
  End;

Type
  MsgEntObjPtr = ^MsgEntObj;



Var
  MsgEnter: MsgEntObj;

Implementation


Uses MKFile, MKString, MKDoor, MKCfgAbs, MKName, MKDos, MKLogEnt,
  MKMsgAbs, {MKMsgFid, MKMsgSqu, MKMsgHud,} MKMsgOpn,
  Dos;



Procedure MsgEntObj.SetDest(Addr: AddrType);
  Begin
  ME^.DestAddr := Addr;
  End;

Procedure MsgEntObj.GetDest(Var Addr: AddrType);    {Get dest addr}
  Begin
  Addr := ME^.DestAddr;
  End;


Function MsgEntObj.GetPriv: Boolean;               {Get msg priv status}
  Begin
  GetPriv := ME^.Priv;
  End;


Procedure MsgEntObj.AskPriv(Def: Boolean);
  Begin
  If Config^.MsgAllowPriv(ME^.Area) Then
    Begin
    If Config^.MsgAllowPubl(ME^.Area) Then
      Begin
      ME^.Priv := Def;
      User.AskYN(Prompts.GetString(064), ME^.Priv);
      User.DisplayNewLine;
      End
    Else
      ME^.Priv := True;
    End
  Else
    Begin
    If Config^.MsgAllowPubl(ME^.Area) Then
      ME^.Priv := False
    Else
      Begin
      ME^.ContMsg := 2;
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(073));
      User.DisplayNewLine;
      User.PressEnter;
      End;
    End;
  End;



Procedure MsgEntObj.AskTo;
  Var
    Finished: Boolean;
    Search: Boolean;
    NameS: NameObj;
    SName: String[35];
    SFin: Boolean;
    AreaAddr: AddrType;

  Begin
  Finished := (Length(ME^.MsgTo) > 0);
  While ((Not Finished) And (User.Ok)) Do
    Begin
    Finished := True;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(207) + ' ');
    ME^.MsgTo := User.InputProper(35);
    If Length(ME^.MsgTo) = 0 Then
      ME^.MsgTo := 'All';
    If Upper(ME^.MsgTo) = 'SYSOP' Then
      ME^.MsgTo := Proper(Config^.GetSysopName);
    If ((ME^.MsgTo = 'All') And (Not Config^.MsgAllowPubl(ME^.Area))) Then
      Begin
      Finished := True;
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(093));
      User.DisplayNewLine;
      User.PressEnter;
      ME^.ContMsg := 3;
      End;
    If ((Config^.GetMsgType(ME^.Area) = Normal) And
    (ME^.MsgTo <> 'All') And
    (ME^.MsgTo <> Proper(Config^.GetSysopName))) Then
      Begin
      User.DisplayStrLn(Prompts.GetString(208));
      NameS.Init;
      If Not NameS.CheckName(ME^.MsgTo) Then
        Begin
        Finished := False;
        User.DisplayStrLn(Prompts.GetString(071));
        Search := True;
        User.AskYN(Prompts.GetString(209), Search);
        User.DisplayNewLine;
        If Search Then
          Begin
          User.DisplayStr(Prompts.GetString(139) + ' ');
          SName := User.InputStr('',35);
          User.DisplayNewLine;
          User.ResetLines(1);
          User.SetStopMore(False);
          User.SetMore(True);
          SFin := NameS.SearchFirst(SName);
          While(User.Ok And Not User.StopMore and SFin) Do
            Begin
            User.DisplayStrLn(Proper(NameS.GetName));
            SFin := NameS.SearchNext;
            End;
          End
        Else
          Begin
          Search := True;
          User.AskYn(Prompts.GetString(193), Search);
          User.DisplayNewLine;
          If Search Then
            Begin
            ME^.ContMsg := 1;
            ME^.MsgTo := '';
            Finished := True;
            End;
          End
        End;
      NameS.Done;
      End;
    End;
  If ((Config^.GetMsgType(ME^.Area) = NetMail) and (ME^.ContMsg = 0)) Then
    Begin
    Finished := False;
    Config^.GetMsgAddr(ME^.Area, AreaAddr);
    While ((Not Finished) and (User.Ok)) Do
      Begin
      User.DisplayNewLine;
      User.DisplayStr(Prompts.GetString(063) + ' ');
      SName := User.InputStr('',35);
      User.DisplayNewLine;
      User.DisplayNewLine;
      Finished := ParseAddr(SName, AreaAddr, ME^.DestAddr);
      If Not Finished Then
        Begin
        SFin := True;
        User.AskYN(Prompts.GetString(157), SFin);
        If Not SFin Then
          Begin
          ME^.ContMsg := 1;
          Finished := True;
          End;
        End;
      End;
    End;
  End;


Procedure MsgEntObj.MsgTest(Sec: SecType);
  Begin
  ME^.ContMsg := 0;
  User.ClearScreen;
  User.DisplayAttr(Config^.GetSystemColor(1));
  If Config^.MsgWriteAccess(ME^.Area, Sec) Then
    Begin
    User.DisplayStr(Prompts.GetString(047) + ' ');
    User.DisplayStr(Long2Str(ME^.Area) + ' - ');
    User.DisplayStrLn(Config^.GetMsgName(ME^.Area));
    End
  Else
    Begin
    ME^.ContMsg := 10;
    User.DisplayStrLn(Prompts.GetString(073));
    User.DisplayNewLine;
    User.PressEnter;
    End;
  If ME^.ContMsg = 0 Then
    AskTo;
  If ME^.ContMsg = 0 Then
    Begin
    If ME^.MsgTo = 'All' Then
      ME^.Priv := False
    Else
      AskPriv(False);
    End;
  If ME^.ContMsg = 0 Then
    Begin
    If (Length(ME^.MsgSubj) = 0) Then
      Begin
      User.DisplayStr(Prompts.GetString(68) + ' ');
      ME^.MsgSubj := User.InputStr('',72);
      User.DisplayNewLine;
      End;
    End;
  If Length(ME^.MsgSubj) = 0 Then
    ME^.ContMsg := 1;
  If ME^.ContMsg = 0 Then
    Begin
    User.ClearScreen;
    GetText;
    End;
  User.DisplayNewLine;
  End;


Constructor MsgEntObj.Init;                      {Initialize}
  Begin
  New(ME);
  If ME <> nil Then
    Begin
    ME^.CurrLine := 0;
    ME^.MsgFrom := User.GetUserName;
    ME^.MsgTo := '';
    ME^.MsgSubj := '';
    ME^.Area := 1;
    ME^.ContMsg := 0;
    ME^.Reference := 0;
    ME^.NewMsgNum := 0;
    End
  Else
    Fail;
  End;



Procedure MsgEntObj.SetTo(Str: String);             {Set msg to}
  Begin
  ME^.MsgTo := Copy(Str,1,35);
  End;


Function MsgEntObj.GetTo: String;
  Begin
  GetTo := ME^.MsgTo;
  End;


Function MsgEntObj.GetMsgNum: Word;                {Get new msg number}
  Begin
  GetMsgNum := ME^.NewMsgNum;
  End;


Procedure MsgEntObj.SetRefer(RF: Word);             {Set orig reference msg}
  Begin
  ME^.Reference := RF;
  End;


Procedure MsgEntObj.SetSubj(Str: String);           {Set msg subj}
  Begin
  ME^.MsgSubj := Copy(Str,1,72);
  End;


Function MsgEntObj.GetSubj: String;                {Get msg subject}
  Begin
  GetSubj := ME^.MsgSubj;
  End;


Function MsgEntObj.GetFrom: String;                {Get msg from}
  Begin
  GetFrom := ME^.MsgFrom;
  End;


Procedure MsgEntObj.SetFrom(Str: String);           {Set msg from}
  Begin
  ME^.MsgFrom := Copy(Str,1,35);
  End;


Procedure MsgEntObj.SetArea(Area: Word);            {Set msg area number}
  Begin
  ME^.Area := Area;
  End;


Procedure MsgEntObj.SetPriv(Pr: Boolean);           {Set private}
  Begin
  ME^.Priv := Pr;
  End;


Destructor MsgEntObj.Done;                      {Done}
  Var
    i: Word;
  Begin
  i := 0;
  While i < ME^.CurrLine Do
    Begin
    Inc(i);
    FreeMem(ME^.ML[i], Length(ME^.ML[i]^) + 1);
    End;
  Dispose(ME);
  End;


Procedure MsgEntObj.AddStr(Str: String);
  Begin
  If (ME^.CurrLine < MaxMsgLength) Then
    Begin
    Inc(ME^.CurrLine);
    GetMem(ME^.ML[ME^.CurrLine], Length(Str) + 1);
    If ME^.ML[ME^.CurrLine] = Nil Then
      Dec(ME^.CurrLine)
    Else
      Begin
      ME^.ML[ME^.CurrLine]^:= Str;
      End;
    End;
  End;


Procedure MsgEntObj.ReplStr(Str: String; LineNo: Word);
  Begin
  FreeMem(ME^.ML[LineNo], Length(ME^.ML[LineNo]^) + 1);
  GetMem(ME^.ML[LineNo], Length(Str) + 1);
  ME^.ML[LineNo]^:= Str;
  End;



Procedure MsgEntObj.DelStr(Start: Word; Stop: Word);
  Var
    DelLines: Word;

  Begin
  If Stop > ME^.CurrLine Then
    Stop := ME^.CurrLine;
  If Start < 1 Then
    Start := 1;
  If Start <= Stop Then
    Begin
    DelLines := (Stop - Start) + 1;
    While Start <= Stop Do
      Begin
      FreeMem(ME^.ML[Start], Length(ME^.ML[Start]^) + 1);
      ME^.ML[Start] := ME^.ML[Start + DelLines];
      Inc(Start);
      End;
    Dec(ME^.CurrLine, DelLines);
    While Start <= ME^.CurrLine Do
      Begin
      ME^.ML[Start] := ME^.ML[Start + DelLines];
      Inc(Start);
      End;
    End;
  End;


Procedure MsgEntObj.InsertStr(Str: String; InsertLine: Word);
  Var
    Tmp: Word;
  Begin
  If (ME^.CurrLine < MaxMsgLength) Then
    Begin
    Inc(ME^.CurrLine);
    Tmp := ME^.CurrLine;
    While (Tmp > InsertLine) Do
      Begin
      ME^.ML[Tmp] := ME^.ML[Tmp - 1];
      Dec(Tmp);
      End;
    GetMem(ME^.ML[InsertLine], Length(Str) + 1);
    ME^.ML[InsertLine]^:= Str;
    End;
  End;


Procedure MsgEntObj.GetText;
  Var
    Finished:  Boolean;
    InsertMode: Boolean;
    InsertLine: Word;
    Over: Boolean;
    TmpStr: String;
    TmpWord: Word;
    TmpWord2: Word;
    ExtraStr: String;
    Ansi: Boolean;
    HiBit: Boolean;
    ChoiceDone: Boolean;
    HotStr: String[20];
    Ch: Char;
    TMsg: AbsMsgPtr;
    MsgWriteError : Word;
    OrigAddr: AddrType;
    TempResult: Word;

  Begin
  ExtraStr := '';
  InsertMode := False;
  HotStr := Prompts.GetString(239);
  Ansi := Config^.MsgAllowAnsi(ME^.Area);
  HiBit := Config^.MsgAllowHiBit(ME^.Area);
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayCenterStrLn(Prompts.GetString(155));
  User.DisplayCenterStrLn(Prompts.GetString(156));
  User.DisplayNewLine;
  TmpStr := '';
  Over := False;
  While ((Not Over) and (User.Ok)) Do
    Begin
    Finished := False;
    While ((Not Finished) and (User.Ok)) Do
      Begin
      User.DisplayAttr(Config^.GetSystemColor(3));
      If InsertMode Then
        User.DisplayStr(PadLeft(Long2Str(InsertLine), ' ', 3) + ': ')
      Else
        User.DisplayStr(PadLeft(Long2Str(ME^.CurrLine + 1), ' ' , 3) + ': ');
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStr(ExtraStr);
      TmpStr := ExtraStr;
      ExtraStr := '';
      User.WWInputStr(TmpStr, ExtraStr, 67, Ansi, HiBit);
      If TmpStr[1] = #13 Then
        Finished := True
      Else
        Begin
        If InsertMode Then
          Begin
          InsertStr(TmpStr, InsertLine);
          Inc(InsertLine);
          End
        Else
          AddStr(TmpStr);
        If ME^.CurrLine >= MaxMsgLength Then
          Finished := True;
        End;
      End;
    InsertMode := False;
    ChoiceDone := False;
    While ((Not ChoiceDone) and (User.Ok)) Do
      Begin
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStr(PadRight(Prompts.GetString(230), ' ', 15));
      User.DisplayStr(PadRight(Prompts.GetString(231), ' ', 15));
      User.DisplayStr(PadRight(Prompts.GetString(232), ' ', 15));
      User.DisplayStr(PadRight(Prompts.GetString(233), ' ', 15));
      User.DisplayStrLn(Prompts.GetString(234) + ' ');
      User.DisplayStr(PadRight(Prompts.GetString(235), ' ', 15));
      User.DisplayStr(PadRight(Prompts.GetString(236), ' ', 15));
      User.DisplayStr(PadRight(Prompts.GetString(237), ' ', 15));
      User.DisplayStr(PadRight(Prompts.GetString(238), ' ', 15));
      Ch := User.AskChoice(HotStr);
      Over := True;
      Case Pos(Ch, HotStr) of
        1: Begin                    {Delete}
           If ME^.CurrLine > 0 Then
             Begin
             User.DisplayChr(HotStr[1]);
             User.DisplayNewLine;
             User.DisplayStr(Prompts.GetString(089) + ' ' +
             Prompts.GetString(12) + Long2Str(1) +'-' + Long2Str(ME^.CurrLine) +
             Prompts.GetString(13) + User.DefaultNumStr(0));
             TmpWord := User.AskNumber(0, 0, ME^.CurrLine);
             User.DisplayNewLine;
             If TmpWord > 0 Then
               Begin
               User.DisplayStr(Prompts.GetString(090) + ' ' +
               Prompts.GetString(12) + Long2Str(TmpWord) +'-' + Long2Str(ME^.CurrLine) +
               Prompts.GetString(13) + User.DefaultNumStr(TmpWord));
               TmpWord2 := User.AskNumber(TmpWord, TmpWord, ME^.CurrLine);
               DelStr(TmpWord, TmpWord2);
               End
             End;
           End;
        2: Begin                    {Edit}
           If ME^.CurrLine > 0 Then
             Begin
             User.DisplayChr(HotStr[2]);
             User.DisplayNewLine;
             User.DisplayStr(Prompts.GetString(082) +
             Prompts.GetString(12) + Long2Str(1) +'-' + Long2Str(ME^.CurrLine) +
             Prompts.GetString(13) + User.DefaultNumStr(ME^.CurrLine));
             TmpWord := User.AskNumber(ME^.CurrLine, 1, ME^.CurrLine);
             User.DisplayNewLine;
             User.DisplayAttr(Config^.GetSystemColor(3));
             User.DisplayStr(PadLeft(Long2Str(TmpWord),' ', 3) + ': ');
             TmpStr := ME^.ML[TmpWord]^;
             If (TmpStr[Length(TmpStr)] = #13) Then
               TmpStr[0] := Chr(Length(TmpStr) - 1);
             User.DisplayAttr(Config^.GetSystemColor(1));
             User.DisplayStr(TmpStr);
             TmpStr := User.InputStr(TmpStr, 67);
             User.DisplayNewLine;
             ReplStr(TmpStr, TmpWord);
             End;
           End;
        3: Begin                    {Replace}
           User.DisplayChr(HotStr[3]);
           End;
        4: Begin                    {Insert}
           InsertMode := True;
           Over := False;
           User.DisplayChr(HotStr[4]);
           User.DisplayNewLine;
           User.DisplayStr(Prompts.GetString(081) +
           Prompts.GetString(12) + Long2Str(1) +'-' + Long2Str(ME^.CurrLine) +
           Prompts.GetString(13) + User.DefaultNumStr(1));
           InsertLine := User.AskNumber(1, 1, ME^.CurrLine);
           User.DisplayNewLine;
           User.DisplayNewLine;
           ChoiceDone := True;
           End;
        5: Begin                    {Help}
           User.DisplayChr(HotStr[5]);
           End;
        6: Begin                    {Continue}
           User.DisplayChr(HotStr[6]);
           ChoiceDone := True;
           Over := False;
           User.DisplayNewLine;
           User.DisplayNewLine;
           End;
        7: Begin                    {List}
           User.DisplayChr(HotStr[7]);
           TmpWord := 1;
           User.DisplayNewLine;
           User.DisplayNewLine;
           User.SetStopMore(False);
           User.SetMore(True);
           User.ResetLines(1);
           While ((TmpWord <= ME^.CurrLine) And (User.Ok) And
           (Not User.StopMore)) Do
             Begin
             User.DisplayAttr(Config^.GetSystemColor(3));
             User.DisplayStr(PadLeft(Long2Str(TmpWord), ' ', 3) + ': ');
             User.DisplayAttr(Config^.GetSystemColor(1));
             User.DisplayStrLn(ME^.ML[TmpWord]^);
             Inc(TmpWord);
             End;
           User.DisplayNewLine;
           End;
        8: Begin                    {Save}
           MsgWriteError := 0;
           User.DisplayChr(HotStr[8]);
           If ME^.CurrLine > 0 Then
             Begin
             If Not OpenMsgArea(TMsg, ME^.Area) Then
               MsgWriteError := 42;
             If MsgWriteError = 0 Then
               Begin
               Case Config^.GetMsgType(ME^.Area) of
                 Normal: TMsg^.SetMailType(mmtNormal);
                 EchoMail: TMsg^.SetMailType(mmtEchoMail);
                 NetMail: TMsg^.SetMailType(mmtNetMail);
                 End;
               TMsg^.StartNewMsg;
               End;
             If MsgWriteError = 0 Then
               Begin
               If Config^.GetMsgType(ME^.Area) = Netmail Then
                 Begin
                 Config^.GetMsgAddr(ME^.Area, OrigAddr);
                 TMsg^.SetDest(ME^.DestAddr);
                 TMsg^.SetOrig(OrigAddr);
                 End;
               TMsg^.SetFrom(ME^.MsgFrom);
               TMsg^.SetTo(ME^.MsgTo);
               TMsg^.SetSubj(ME^.MsgSubj);
               TMsg^.SetPriv(ME^.Priv);
               TMsg^.SetDate(DateStr(GetDosDate));
               TMsg^.SetTime(TimeStr(GetDosDate));
               TMsg^.SetLocal(True);
               TMsg^.SetEcho(True);
               TMsg^.SetRefer(ME^.Reference);
               TmpWord := 1;
               While TmpWord <= ME^.CurrLine Do
                 Begin
                 If ME^.ML[TmpWord] <> Nil Then
                   TMsg^.DoString(ME^.ML[TmpWord]^);
                 Inc(TmpWord)
                 End;
               If (ME^.ML[ME^.CurrLine]^[Length(ME^.ML[ME^.CurrLine]^)] <> #13) Then
                 TMsg^.DoChar(#13);
               If ((Config^.GetMsgType(ME^.Area) <> Normal) And
               (Config^.MsgAddFido(ME^.Area))) Then
                 Begin
                 TMsg^.DoStringLn('--- MK Bbs v0.01');
                 TMsg^.DoStringLn(Config^.GetDefaultOrigStr(ME^.Area));
                 End;
               MsgWriteError := TMsg^.WriteMsg;
               End;
             If MsgWriteError <> 0 Then
               Begin
               User.DisplayNewLine;
               User.DisplayStrLn(Prompts.GetString(260) + ' ' + Long2Str(MsgWriteError));
               User.PressEnter;
               End
             Else
               Begin
               LogEntry.WriteEntry('Message #' + Long2Str(TMsg^.GetMsgNum) +
                 ' posted in area #' + Long2Str(ME^.Area) + ' : ' +
                 Config^.GetMsgName(ME^.Area));
               ME^.NewMsgNum := TMsg^.GetMsgNum;
               User.UpdateForMsg;
               End;
             If Not CloseMsgArea(TMsg) Then;
             End;
           ChoiceDone := True;
           Over := True;
           End;
        9: Begin                    {Quit}
           User.DisplayChr(HotStr[9]);
           User.DisplayNewLine;
           Over := False;
           User.AskYN(Prompts.GetString(193), Over);
           ChoiceDone := Over;
           User.DisplayNewLine;
           End;
        End;
      End;
    End;
  End;

End.
