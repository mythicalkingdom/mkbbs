Unit MKCmd;
{$I MKB.Def}

{$X+}

Interface

Uses MKGlobT;

Procedure ProcessCmd(Item: Word);
Procedure Process;
Procedure PostMsg(Cmd: String);

Var
  MenuState: Word;
  {0=Done 1=AutoFirst 2=AutoNext 3=ProcessKey}
  Key: Char;
  TmpItem: Word;
  Sec: SecType;
  DoorLevel: Byte;
  DoorExit: Boolean;

Implementation


Uses MKFile, MKString, MKCodes, MKDoor, MKMenus, MKCfgAbs, MKComAbs,
  MKCFile, MKMRead, MKEnter, MKName, MKMisc, MKDos, MKShell, MKPage,
  MKQuest, MKMsgSel, MKProt, MKLogEnt, MKMiscB, MKCD, MKRCfgMK, MKLogOn,
  MKOfflin, MKBasicRun, MKPascalRun,
    MKVCrt,
  Dos;


Function GetResponse: Char;
  Var
    Finished: Boolean;
    Tmp: Char;

  Begin
  User.SetTimeOut;
  Tmp := #0;
  Finished := False;
  While (User.Ok) and (Not Finished) Do
    Begin
    If User.InputChr(Tmp) Then
      Begin
      Tmp := UpCase(Tmp);
      If Tmp = #1 Then
        Tmp := #0;
      If (Pos(Tmp, Menu.GetHotKeys) > 0) Then
        Begin
        User.DisplayChr(UpCase(Tmp));
        User.DisplayNewLine;
        Finished := True;
        GetResponse := Tmp;
        CommFlushOut;
        End
      Else
        Begin
        GetResponse := Tmp;
        Finished := True;
{
        LogEntry.WriteEntry('On Menu ' + Menu.GetName +
          ' User tried key ' + Tmp);
        User.DisplayNewLine;
        User.DisplayStrLn('Invalid Command Key ' + Tmp);
        User.PressEnter;
}
        End;
      End
    Else
      Begin
      User.CheckInput;
      User.CheckIdle;
      End;
    End;
  End;



Function CvtMenuStr(MStr:String; MenuItem: Byte; IsPrompt: Boolean): String;
  Var
    i: Word;
    v: Word;
    TStr: String;
    HiColor: Boolean;
    DoCr: Boolean;

  Begin
  HiColor := False;
  If IsPrompt Then
    DoCr := False
  Else
    Begin
    If MStr[Length(MStr)] = ';' Then
      Begin
      DoCR := False;
      MStr := Copy(MStr,1,Length(MStr) - 1);
      End
    Else
      DoCR := True;
    End;
  i := 1;
  If Length(MStr) > 0 Then
    TStr := User.GetAttrStr(Menu.GetNormal(MenuItem))
  Else
    TStr := '';
  While i <= Length(MStr) Do
    Begin
    Case MStr[i] of
      '~': TStr := TStr + #11'O';
      '^': Begin
           HiColor := Not HiColor;
           If HiColor Then
             TStr := TStr + User.GetAttrStr(Menu.GetHi)
           Else
             TStr := TStr + User.GetAttrStr(Menu.GetNormal(MenuItem));
           End;
      '@': TStr := TStr + Config^.GetFileAreaName(User.GetUserFileTemplate);
      '`': TStr := TStr + Config^.GetMsgName(User.GetUserMsgTemplate);
      Else
        TStr := TStr + MStr[i];
      End;
    Inc(i);
    End;
  If DoCR Then
    TStr := TStr + #13 + #10;
  CvtMenuStr := TStr;
  End;


Procedure Process;
  Var
    TmpStr: String;

  Begin
  DoorExit := False;
  Key := #0;
  While ((MenuState <> 0) and (User.Ok)) Do
    Begin
    User.PostStatus(uoBrowse);
    User.GetUserSec(Sec);
    Menu.SetSecurity(Sec);
    Case MenuState Of
    {0=Done 1=AutoFirst 2=AutoNext 3=ProcessKey}
      1: Begin
         MenuState := 3;
         For TmpItem := 1 To Menu.NumItems Do
           Begin
           If Menu.HasAccess(TmpItem) Then
             Begin
             TmpStr := CvtMenuStr(Menu.GetPrompt(TmpItem), TmpItem, False);
             If Key = #0 Then
               Begin
               BbsDisplay.ResetState;
               BbsDisplay.DisplayStr(TmpStr);
               End;
             If Menu.GetKey(TmpItem) = #1 Then
               ProcessCmd(TmpItem);
             End;
           End;
         End;
      3: Begin
         TmpStr := CvtMenuStr(Menu.GetPrompt(0), 0, True);
         If Key = #0 Then
           Begin
           BbsDisplay.ResetState;
           BbsDisplay.DisplayStr(TmpStr);
           End;
         If Key = #0 Then
           Key := GetResponse;
         If Key <> #0 Then
           Begin
           TmpItem := Menu.ItemFirst(Key);
           If TmpItem > 0 Then
             Begin
             Key := #0;
             ProcessCmd(TmpItem);
             If MenuState = 3 Then
               MenuState := 1;
             End
           Else
             Begin
             If Key = #13 Then
               MenuState := 1
             Else
               Begin
               User.DisplayNewLine;
               If Key > #31 Then
                 Begin
                 LogEntry.WriteEntry('On Menu ' + Menu.GetName +
                 ' User tried key ' + Key );
                 User.DisplayStrLn('Invalid Command Key ' + Key);
                 End
               Else
                 Begin
                 LogEntry.WriteEntry('On Menu ' + Menu.GetName +
                 ' User tried key ^' + Chr(Ord(Key) or $40));
                 User.DisplayStrLn('Invalid Command Key ^' + Chr(Ord(Key) or $40));
                 End;
               User.PressEnter;
               MenuState := 1;
               End;
             Key := #0;
             End;
           End;
         End;
      End;
    End;
  End;





Procedure DownLoadSpecial(FN: String);
  Var
    Prot: ProtObj;
    i: Word;
    FF: FindObj;
    ProtNum: Word;
    TotalSize: LongInt;
    FirstFile: String[15];
    XferOk: Boolean;
    Sizes: Array[1..50] of LongInt;


  Begin
  TotalSize := 0;
  FF.Init;
  CommFlow(fcHard);
  Prot.Init;
  FF.FFirst(FN);
  For i := 1 to 50 Do
    Sizes[i] := 0;
  i := 0;
  While FF.Found Do
    Begin
    Prot.AddSendFile(FF.GetFullPath);
    If i = 0 Then
      FirstFile := FF.GetName;
    Inc(TotalSize, FF.GetSize);
    Inc(i);
    Sizes[i] := FF.GetSize;
    FF.FNext;
    End;
  FF.Done;
  XferOk := EstimateXferTime(TotalSize, User.GetUserBaud, 90) <
    User.TimeRemain;
  If Not XferOk Then
    Begin
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(126));
    User.DisplayNewLine;
    User.PressEnter;
    End
  Else
    Begin
    If ((TotalSize Div 1024) > (User.GetUserDLLimit - User.GetUserTodayK)) Then
      Begin
      XferOk := False;
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStrLn(Prompts.GetString(262));
      User.DisplayNewLine;
      User.PressEnter;
      End
    End;
  If XferOk Then
    Begin
    If i > 0 Then
      Begin
      ProtNum := GetProtocol(True);
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStrLn(Prompts.GetString(130));
      User.DisplayStrLn(Prompts.GetString(129) + ' ' + FirstFile);
      Case ProtNum of
        1: Prot.SetXmodem;
        2: Prot.SetX1k;
        3: Prot.SetYmodem;
        4: Prot.SetZmodem;
        5: Prot.SetYModemG;
        6: Prot.SetXmodemG;
        7: Prot.SetSealink;
        End;
      If ((ProtNum < 08) and (ProtNum > 0)) Then
        Begin
        User.PostStatus(uoXfer);
        Prot.Send;
        While i > 0 Do
          Begin
          If Prot.GetFileStatus(i) = 1 Then
            Begin
            User.UpdateForDL(Sizes[i]);
            End;
          Dec(i);
          End;
        End
      Else;
      End;
    End;
  Prot.Done;
  CommFlow(fcBoth);
  End;


Procedure SelectFileArea;
  Var
    SC: ConfSelectObj;
    i: Word;

  Begin
  SC.Init;
  For i := 1 to Config^.GetMaxFileAreas Do
    SC.SetAvailable(i, Config^.FileViewAccess(i, Sec));
  SC.SelectConfs(False, False, True);
  i := SC.GetSelectedArea;
  If i <> 0 Then
    User.SetUserFileTemplate(i);
  SC.Done;
  End;



Function ParseMenuData(Item: Word): Boolean;
  Var
    CurrWord: Word;
    TmpStr: String;
    TmpArea: Word;
    Code: Word;
    PwdStr: String[30];

  Begin
  ParseMenuData := True;
  CurrWord := 2;
  While (CurrWord <= WordCount(Menu.GetData(Item))) Do
    Begin
    TmpStr := Upper(ExtractWord(Menu.GetData(Item), CurrWord));
    If Copy(TmpStr,1,2) = '/M' Then
      Begin
      Case TmpStr[3] of
        '+': Begin
             TmpArea := User.GetUserMsgTemplate + 1;
             While ((TmpArea < Config^.GetMaxMsgAreas) And
             (Not Config^.MsgReadAccess(TmpArea, Sec))) Do
               Inc(TmpArea);
             If Config^.MsgReadAccess(TmpArea, Sec) Then
               User.SetUserMsgTemplate(TmpArea);
             End;
        '-': Begin
             TmpArea := User.GetUserMsgTemplate - 1;
             While ((TmpArea > 1) And
             (Not Config^.MsgReadAccess(TmpArea, Sec))) Do
               Dec(TmpArea);
             If Config^.MsgReadAccess(TmpArea, Sec) Then
               User.SetUserMsgTemplate(TmpArea);
             End;
        '=': Begin
             Val(Copy(TmpStr,4,4), TmpArea, Code);
             If ((Code = 0) and (Length(Config^.GetMsgName(TmpArea)) > 0)) Then
             User.SetUserMsgTemplate(TmpArea);
             End;
        End;
      End
    Else If Copy(TmpStr,1,2) ='/F' Then
      Begin
      Case TmpStr[3] of
        '+': Begin
             TmpArea := User.GetUserFileTemplate + 1;
             While ((TmpArea < Config^.GetMaxFileAreas) And
             (Not Config^.FileViewAccess(TmpArea, Sec))) Do
               Inc(TmpArea);
             If Config^.FileViewAccess(TmpArea, Sec) Then
               User.SetUserFileTemplate(TmpArea);
             End;
        '-': Begin
             TmpArea := User.GetUserFileTemplate - 1;
             While ((TmpArea > 1) And
             (Not Config^.FileViewAccess(TmpArea, Sec))) Do
               Dec(TmpArea);
             If Config^.FileViewAccess(TmpArea, Sec) Then
               User.SetUserFileTemplate(TmpArea);
             End;
        '=': Begin
             Val(Copy(TmpStr,4,4), TmpArea, Code);
             If ((Code = 0) and (Length(Config^.GetFileAreaName(TmpArea)) > 0)) Then
             User.SetUserFileTemplate(TmpArea);
             End;
        End;
      End
    Else
      Begin
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayNewLine;
      User.DisplayStr(Prompts.GetString(021));
      User.DisplayChr(' ');
      PwdStr := User.InputPwd(20);
      User.DisplayNewLine;
      PwdStr := Upper(StripBoth(PwdStr,' '));
      If PwdStr <> TmpStr Then
        Begin
        User.DisplayStrLn(Prompts.GetString(039));
        User.PressEnter;
        CurrWord := 1000;
        ParseMenuData := False;
        End;
      End;
    Inc(CurrWord);
    End;
  End;


Procedure NormalLogOff;
  Begin
  User.PostStatus(uoWait);
  BbsDisplay.DisplayBbsFile('GOODBYE',' ');
  MenuState := 0;
  LogEntry.WriteEntry('User requested to terminate the call');
  LowerDTR;
  Delay(500);
  RaiseDTR;
  End;


Procedure Type15Exit(CmdLine: String);
  Var
    DoDoorSys: Boolean;
    DoCallInfo: Boolean;
    CmdCount: Word;
    Tmp: Word;
    TmpStr: String;
    Code: Word;
    TmpVal: Word;

  Begin
  MenuState := 0;
  DoDoorSys := False;
  DoCallInfo := False;
  DoorLevel := 0;
  If WriteDorInfo <> 0 Then;
  CmdCount := WordCount(CmdLine);
  Tmp := 1;
  While Tmp <= CmdCount Do
    Begin
    TmpStr := ExtractWord(CmdLine, Tmp);
    If TmpStr[1] = '*' Then
      Begin
      If Upper(TmpStr) = '*D' Then
        DoDoorSys := True;
      If Upper(TmpStr) = '*W' Then
        DoCallInfo := True;
      End
    Else
      Begin
      Val(TmpStr, TmpVal, Code);
      If ((Code = 0) and (TmpVal > 5) and (TmpVal < 256)) Then
        DoorLevel := TmpVal;
      End;
    End;
  If DoCallInfo Then
    If WriteCallInfo <> 0 Then;
  If DoDoorSys Then
    If WriteDoorSys <> 0 Then;
  User.PostStatus(uoDoor);
  End;


Procedure PostMsg(Cmd: String);
  Var
    Tmp: Word;
    TmpStr: String;
    Code: Word;
    ParseCnt: Word;
    Area: Word;
    OffAfter: Boolean;
    ForceTo: Boolean;
    ForceName: String[35];
    j: Word;

  Begin
  User.PostStatus(uoMsg);
  OffAfter := False;
  ForceTo := False;
  ForceName := '';
  Area := 32000;
  ParseCnt := WordCount(Cmd);
  While ParseCnt > 0 Do
    Begin
    TmpStr := Upper(StripBoth(ExtractWord(Cmd, ParseCnt),' '));
    If TmpStr[1] = '/' Then
      Begin
      Case UpCase(TmpStr[2]) Of
        'M': Begin
             Area := User.GetUserMsgTemplate;
             Code := 0;
             End;
        'L': OffAfter := True;
        'T': Begin
             ForceTo := True;
             ForceName := Proper(Copy(TmpStr,4,35));
             j := 1;
             While j <= Length(ForceName) Do
               Begin
               If ForceName[j] = '_' Then
                 ForceName[j] := ' ';
               Inc(j);
               End;
             If ForceName = 'Sysop' Then
               ForceName := Config^.GetSysopName;
             End;
        End;
      End
    Else
      Begin
      Val(TmpStr, Tmp, Code);
      If Code = 0 Then
        Area := Tmp;
      End;
    Dec(ParseCnt);
    End;
  If ((Area < 1) or (Area > Config^.GetMaxMsgAreas)) Then
    Code := 100;
  If ((Code = 0) and (Config^.MsgWriteAccess(Area, Sec))) Then
    Begin
    MsgEnter.Init;
    MsgEnter.SetArea(Area);
    If ForceTo Then
      MsgEnter.SetTo(ForceName);
    MsgEnter.MsgTest(Sec);
    MsgEnter.Done;
    End
  Else
    Begin
    BbsDisplay.DisplayBbsFile('WriteSec', ' ');
    If (BbsDisplay.GetError <> 0) Then
      User.DisplayStrLn(Prompts.GetString(073));
    User.PressEnter;
    End;
  If OffAfter Then
    NormalLogOff;
  End;


Procedure ToggleCharset;                {Type 171: UTF-8 or CP437 text}
  Begin
  User.DisplayNewLine;
  If CallerUtf8 Then
    CharsetMode := 1
  Else
    CharsetMode := 2;
  If CharsetMode = 2 Then
    User.DisplayStrLn('Character set: UTF-8 (the DOS box characters are translated)')
  Else
    User.DisplayStrLn('Character set: CP437 (sent as the DOS programs wrote it)');
  User.DisplayNewLine;
  User.PressEnter;
  End;


Procedure GoToMenu(Item: Word);        {Process type 1 or 4}
  Begin
  If ParseMenuData(Item) Then
    Begin
    Key := #0;
    Menu.Load(ExtractWord(Menu.GetData(Item), 1));
    If Menu.GetError <> 0 Then
      Menu.Load('TOP');
    If Menu.GetError <> 0 Then
      MenuState := 0
    Else
      MenuState := 1;
    End;
  End;


Procedure ReturnMenu(Var MN: String);
  Begin
  Menu.Load(MN);
  Key := #0;
  If Menu.GetError <> 0 Then
    Menu.Load('TOP');
  If Menu.GetError <> 0 Then
    MenuState := 0
  Else
    MenuState := 1;
  End;


Procedure ProcessCmd(Item: Word);
  Var
    TmpStr: String;
    Tmp: LongInt;
    Code: Word;

  Begin
  Case Menu.GetType(Item) Of
    001: GoToMenu(Item);                    {Go To Menu}
    002: Begin                              {Go Sub to another Menu}
         User.GoSub(Menu.GetName);
         GoToMenu(Item);
         End;
    003: Begin                              {Return from GoSub Menu}
         TmpStr := User.GoSubReturn;
         If Length(TmpStr) > 0 Then
           ReturnMenu(TmpStr);
         End;
    004: Begin                              {Clear gosub stack and goto menu}
         User.ClearGoSub;
         GoToMenu(Item);
         End;
    005: Begin                              {Screen display}
         BbsDisplay.DisplayBbsFile(ExtractWord(Menu.GetData(Item),1), ' ');
         If (BbsDisplay.GetError <> 0) Then
           User.DisplayStr('Error: ' + Menu.GetData(Item) + ' Not Found');
         End;
    006: DisplayBulletin(Menu.GetData(Item));             {Bulletin display}
    007: TypeSeven(Menu.GetData(Item));     {Execute external program}
    008: DisplayVersion;                    {Display BBS software info}
    009: NormalLogOff;                      {Log off caller}
    010: UsageStats;                        {Display BBS % busy stats}
    011: DoPage;                            {Page sysop}
    012: DoQuest(Menu.GetData(Item));       {Process Questionaire}
    013: UserSearch;                        {Display user search}
    014: TimeInfo;                          {User time info display}
    015: Type15Exit(Menu.GetData(Item));    {Exit with errorlevel}
    016: Begin                              {Change location}
         If User.GetUserScrnClr Then
           User.ClearScreen;
         User.DisplayNewLine;
         User.DisplayStr(Prompts.GetString(41) + ' ');
         TmpStr := User.InputStr('',25);
         User.DisplayNewLine;
         If Length(TmpStr) > 0 Then
           User.SetUserCity(TmpStr);
         End;
    017: ChangePwd;                         {Password change}
    018: Begin                              {Screen length}
         User.DisplayNewLine;
         User.DisplayStr(Prompts.GetString(55) +
           User.DefaultNumStr(User.GetUserScrLength));
         Tmp := User.AskNumber(User.GetUserScrLength, 16, 66);
         User.SetUserScrLength(Tmp);
         End;
    019: Begin                              {Screen clearing}
         User.DisplayNewLine;
         User.SetUserScrnClr(Not User.GetUserScrnClr);
         User.DisplayStr(Prompts.GetString(25) + ' ');
         If User.GetUserScrnClr Then
           User.DisplayStrLn(Prompts.GetString(23))
         Else
           User.DisplayStrLn(Prompts.GetString(24));
         User.DisplayNewLine;
         User.PressEnter;
         End;
    020: Begin                              {More? page pausing}
         User.DisplayNewLine;
         User.SetUserMore(Not User.GetUserMore);
         User.DisplayStr(Prompts.GetString(27) + ' ');
         If User.GetUserMore Then
           User.DisplayStrLn(Prompts.GetString(23))
         Else
           User.DisplayStrLn(Prompts.GetString(24));
         User.DisplayNewLine;
         User.PressEnter;
         End;
    021: Begin                              {Toggle Ansi}
         User.DisplayNewLine;
         User.SetUserAnsi(Not User.GetUserAnsi);
         User.DisplayStr(Prompts.GetString(149) + ' ');
         If User.GetUserAnsi Then
           User.DisplayStrLn(Prompts.GetString(23))
         Else
           User.DisplayStrLn(Prompts.GetString(24));
         User.DisplayNewLine;
         User.PressEnter;
         End;
    022: DoYourMail;                        {Check for mail to you}
    023: ReadMsg(Menu.GetData(Item), 1);    {Read messages}
    024: ReadMsg(Menu.GetData(Item), 3);    {Scan msgs}
    025: ReadMsg(Menu.GetData(Item), 2);    {Quick-scan msgs}
    026: DoDeleteMsg(Menu.GetData(Item));   {Delete message}
    027: PostMsg(Menu.GetData(Item));       {Enter a message}
    028: SelectCombined;                    {Select combined areas}
    030: Begin                              {Directory List}
         TmpStr := Upper(ExtractWord(Menu.GetData(Item),1));
         If TmpStr = '/F' Then
           Begin
           If Config^.FileViewAccess(User.GetUserFileTemplate, Sec) Then
             DoDirList(Config^.GetFileAreaPath(User.GetUserFileTemplate));
           End
         Else
           If Length(TmpStr) > 0 Then
             DoDirList(TmpStr);
         End;
    031: Begin                              {List files}
         TmpStr := Upper(ExtractWord(Menu.GetData(Item),1));
         If TmpStr = '/F' Then
           Begin
           If Config^.FileViewAccess(User.GetUserFileTemplate, Sec) Then
             DoFileList(Config^.GetFileAreaPath(User.GetUserFileTemplate));
           End
         Else
           If Length(TmpStr) > 0 Then
             DoFileList(TmpStr);
         End;
    034: DoPackView(Sec);                   {Global archive viewing}
    035: DoTextSearch(Sec);                 {Global text search}
    037: DoNewFiles(Sec);                   {Global new file search}
    040: Begin                              {Display screen with hot-keys}
         If Key = #0 Then
           Begin
           Key := BbsDisplay.DisplayBbsFile(ExtractWord(Menu.GetData(Item),1),
             Menu.GetHotKeys);
           If (BbsDisplay.GetError <> 0) Then
             User.DisplayStr('Error: ' + Menu.GetData(Item) + ' Not Found');
           End;
         End;
    041: Begin                              {Toggle full screen editor}
         User.DisplayNewLine;
         User.SetUserFullEd(Not User.GetUserFullEd);
         User.DisplayStr(Prompts.GetString(26) + ' ');
         If User.GetUserFullEd Then
           User.DisplayStrLn(Prompts.GetString(23))
         Else
           User.DisplayStrLn(Prompts.GetString(24));
         User.DisplayNewLine;
         User.PressEnter;
         End;
    044: ResetCombined;                     {Set/Reset all combined areas}
    045: Begin                              {Screen display with press enter}
         BbsDisplay.DisplayBbsFile(ExtractWord(Menu.GetData(Item),1), ' ');
         If (BbsDisplay.GetError <> 0) Then
           User.DisplayStr('Error: ' + Menu.GetData(Item) + ' Not Found');
         User.PressEnter;
         End;
    047: LogEntry.WriteEntry(Menu.GetData(Item)); {Write log entry}
    048: DownLoadSpecial(Menu.GetData(Item)); {Download specific file}
    049: SelectMessageArea;                 {Select msg template area}
    050: SelectFileArea;                    {Select file template area}
    052: ListNodes;                         {List online callers/nodes}
    054: DisplayDirFile(Menu.GetData(Item));{Temporary only}
    057: ChangeVoicePhone;                  {Change callers voice phone #}
    058: ChangeDataPhone;                   {Change callers data phone #}
    061: Begin                              {Toggle avatar}
         User.DisplayNewLine;
         User.SetUserAvatar(Not User.GetUserAvatar);
         User.DisplayStr(Prompts.GetString(150) + ' ');
         If User.GetUserAvatar Then
           User.DisplayStrLn(Prompts.GetString(23))
         Else
           User.DisplayStrLn(Prompts.GetString(24));
         User.DisplayNewLine;
         User.PressEnter;
         End;
    065: Begin
         DoFlags(Menu.GetData(Item));       {Change flag settings}
         User.GetUserSec(Sec);
         Menu.SetSecurity(Sec);
         End;
    149: DoLanguage;                        {Select language to use}
    150: If WordCount(Menu.GetData(Item)) > 1 Then   {CD Rom access}
           DoCDRom(ExtractWord(Menu.GetData(Item), 1),
             ExtractWord(Menu.GetData(Item), 2));
    151: SelectOffline;                     {Select offline mail areas}
    152: ResetOffline;                      {Reset offline mail areas}
    153: SetProtocol;                       {Select transfer protocol}
    154: SetPacker;                         {Select compression packer}
    155: OfflineAuto;                       {Auto-script offline mail}
    156: OfflineUL;                         {Upload offline mail pkt}
    157: OfflineDL;                         {Download offline mail pkt}
    158: SetOffType;                        {Set offline mail pkt type}
    159: AskOffNewFiles;                    {Ask include new files list}
    160: AskOffScrn;                        {Ask include screens}
    161: AskOffBull;                        {Ask include bulletins}
    162: AskOffMax;                         {Ask max pkt size}
    163: AskOffConfMax;                     {Ask max msgs per area}
    164: AskOffVerify;                      {Ask verify want packet}
    165: AskOffFlag;                        {Ask flag mail as read}
    166: AskOffOwn;                         {Ask rcv own messages}
    167: AskOffAllYour;                     {Ask search all areas for yours}
    168: AskOffZero;                        {Ask send zero msg packets}
    169: RunBasicProgram(Menu.GetData(Item)); {Run a BASIC program (mkbasic)}
    170: RunPascalProgram(Menu.GetData(Item)); {Run a Pascal program (mkpascal)}
    171: ToggleCharset;                     {Toggle UTF-8 / CP437 text}
    End;
  End;


End.
