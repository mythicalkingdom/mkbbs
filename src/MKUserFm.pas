Unit MKUserFm;   {MKUserEd: the user record, its edit form, validation templates (Free Vision)}

{$I MKB.Def}

{
     Converted from MKUSERED (Object Professional).  The record of the user at
     the current position of NameSearch is kept in UR; LoadUser fills it,
     SaveUser writes it back.  EditUser is the edit screen (one dialog with all
     the fields; F2 / Space on Security, Networks and Areas open their lists).

     Validation: nine templates (security level and flags, optionally a
     welcome message from a text file into a message area) are kept in
     MKUserEd.Cfg in the BBS directory (EditTemplates); ApplyTemplate gives
     the current user one.
}

Interface

Uses MKGlobT, CfgList;

Const
  MaxTemplates = 9;

Type
  UserRecord = Record
    Name: String[35];
    Password: String[15];
    Handle: String[35];
    HomePhone: String[12];
    Location: String[25];
    DataPhone: String[12];
    Security: SecType;
    NM: Integer;
    Pending: Integer;
    ScrnLen: Word;
    Entered: Word;
    Times: Word;
    Elapsed: Word;
    ULFiles: Word;
    ULK: Word;
    DLFiles: Word;
    DLK: Word;
    TodayK: Word;
    Deleted, ScrnClr, More, Ansi, Avatar, NoKill, IgnoreHrs, FullScr: Boolean;
    Birthdate: String[8];
    FirstCall: String[8];
    Expire: String[8];
    LastCall: String[8];
    LastTime: String[5];
    NewDate: String[8];
    PageTune: Byte;
    Address: String[40];
    ZipCode: String[10];
    Comment: String[60];
    Protocol: Char;
    Packer: Char;
    MaxMsg: Word;
    MaxArea: Word;
    RealNetStat: LongInt;
    NetStr: String[8];                 {Networks, for the screen}
    OffNew, OffScrn, OffBull, OffVerify, OffFlag, OffOwn, OffAll, OffZero, OffGate: Boolean;
    OffCount: String[4];               {Number of offline areas, for the screen}
    BankMin: Word;
    UserNum: LongInt;
    Offline: CfgBigMarks;
    End;

  ValidateType = Record
    Sec: SecType;
    MsgName: String[13];
    MsgArea: Word;
    Priv: Boolean;
    End;

  UserEdCfgType = Record
    VRec: Array[1..MaxTemplates] Of ValidateType;
    End;

Var
  UR: UserRecord;
  UserEdCfg: UserEdCfgType;

Procedure LoadCfg;                     {MKUserEd.Cfg}
Procedure SaveCfg;
Procedure LoadUser;                    {NameSearch -> UR}
Procedure SaveUser;                    {UR -> NameSearch, written to the file}
Procedure DefaultUser;                 {A new user: UR gets the default values}
Function  EditUser: Boolean;           {The edit screen; True = OK, UR changed}
Procedure EditTemplates;               {The nine validation templates}
Procedure ApplyTemplate(N: Word);      {Validate the current user with template N}
Var
  AnswerLines: Array[1..17] Of String[69];
  AnswerCount: Word;

Procedure LoadAnswers;                 {The questionnaire answers of this user: AnswerLines}
Function  TemplateLine(N: Word): String;
Function  YN(B: Boolean): String;
Function  ValidDate(S: String): Boolean;


Implementation

Uses Objects, Drivers, Views, Dialogs, App, MKString, MKFile, MKCfgAbs, MKName,
  MKMsgAbs, MKOpen, MKDos, CfgForm, CfgSec2, CfgBox;


Function YN(B: Boolean): String;
  Begin
  If B Then
    YN := 'Yes'
  Else
    YN := 'No';
  End;


{------------------------------------------------------------ the file of templates}

Procedure LoadCfg;
  Begin
  FillChar(UserEdCfg, SizeOf(UserEdCfg), 0);
  If FileExist(Config^.GetBbsPath + 'mkusered.cfg') Then
    If LoadFile(Config^.GetBbsPath + 'mkusered.cfg', UserEdCfg, SizeOf(UserEdCfg)) <> 0 Then
      FillChar(UserEdCfg, SizeOf(UserEdCfg), 0);
  End;


Procedure SaveCfg;
  Begin
  If SaveFile(Config^.GetBbsPath + 'mkusered.cfg', UserEdCfg, SizeOf(UserEdCfg)) = 0 Then;
  End;


{------------------------------------------------------------ NameSearch <-> UR}

Procedure Letters;
  {The text shown for the networks and the offline areas}
  Var
    i: Word;
    Mask: LongInt;
    N: Word;

  Begin
  UR.NetStr := '';
  Mask := 1;
  For i := 1 To 26 Do
    Begin
    If (UR.RealNetStat And Mask) <> 0 Then
      Begin
      If Length(UR.NetStr) < 4 Then
        UR.NetStr := UR.NetStr + Chr(Ord('A') + i - 1)
      Else If Length(UR.NetStr) = 4 Then
        UR.NetStr := UR.NetStr + '+';
      End;
    Mask := Mask Shl 1;
    End;
  If UR.NetStr = '' Then
    UR.NetStr := '-';
  N := 0;
  For i := 1 To 500 Do
    If UR.Offline[i] Then
      Inc(N);
  UR.OffCount := Long2Str(N);
  End;


Procedure LoadUser;
  Var
    i: Word;

  Begin
  UR.Name := NameSearch.GetName;
  UR.Password := NameSearch.GetPwd;
  UR.Handle := NameSearch.GetHandle;
  UR.HomePhone := NameSearch.GetVoicePhone;
  UR.Location := NameSearch.GetLocation;
  UR.DataPhone := NameSearch.GetDataPhone;
  NameSearch.GetSec(UR.Security);
  UR.NM := NameSearch.GetNMCredit;
  UR.Pending := NameSearch.GetNMPending;
  UR.ScrnLen := NameSearch.GetScrnLen;
  UR.Entered := NameSearch.GetMsgsEntered;
  UR.Times := NameSearch.GetTimesCalled;
  UR.Elapsed := NameSearch.GetElapsed;
  UR.ULFiles := NameSearch.GetULFiles;
  UR.ULK := NameSearch.GetULK;
  UR.DLFiles := NameSearch.GetDLFiles;
  UR.DLK := NameSearch.GetDLK;
  UR.TodayK := NameSearch.GetTodayK;
  UR.Deleted := NameSearch.IsDeleted;
  UR.ScrnClr := NameSearch.IsScrnClr;
  UR.More := NameSearch.IsMore;
  UR.Ansi := NameSearch.IsAnsi;
  UR.Avatar := NameSearch.IsAvatar;
  UR.NoKill := NameSearch.IsNoKill;
  UR.IgnoreHrs := NameSearch.IsIgnoreHrs;
  UR.FullScr := NameSearch.IsFullScrn;
  UR.UserNum := NameSearch.GetPos;
  UR.Birthdate := NameSearch.GetBirthDate;
  UR.FirstCall := NameSearch.GetFirstDate;
  UR.LastCall := NameSearch.GetLastDate;
  UR.LastTime := NameSearch.GetLastTime;
  UR.NewDate := NameSearch.GetNewDate;
  UR.Expire := NameSearch.GetExpire;
  UR.Comment := NameSearch.GetComment;
  UR.PageTune := NameSearch.GetPageTune;
  UR.Protocol := NameSearch.GetProt;
  UR.Packer := NameSearch.GetPacker;
  UR.BankMin := NameSearch.GetBankTime;
  UR.Address := NameSearch.GetAddr;
  UR.ZipCode := NameSearch.GetZip;
  UR.MaxMsg := NameSearch.GetOffMax;
  UR.MaxArea := NameSearch.GetOffConfMax;
  UR.OffNew := NameSearch.GetOffNew;
  UR.OffScrn := NameSearch.GetOffScrn;
  UR.OffBull := NameSearch.GetOffBull;
  UR.OffVerify := NameSearch.GetOffVerify;
  UR.OffFlag := NameSearch.GetOffFlag;
  UR.OffOwn := NameSearch.GetOffOwn;
  UR.OffAll := NameSearch.GetOffAll;
  UR.OffZero := NameSearch.GetOffZero;
  UR.OffGate := NameSearch.GetOffGate;
  UR.RealNetStat := NameSearch.GetNetStatus;
  For i := 1 To 500 Do
    UR.Offline[i] := NameSearch.GetUserOffline(i);
  { the screen has no spaces to keep the page and protocol letters apart }
  Letters;
  End;


Procedure SaveUser;
  Var
    i: Word;

  Begin
  NameSearch.SetName(UR.Name);
  NameSearch.SetHandle(UR.Handle);
  NameSearch.SetPwd(UR.Password);
  NameSearch.SetVoicePhone(UR.HomePhone);
  NameSearch.SetLocation(UR.Location);
  NameSearch.SetDataPhone(UR.DataPhone);
  NameSearch.SetSec(UR.Security);
  NameSearch.SetNMCredit(UR.NM);
  NameSearch.SetNMPending(UR.Pending);
  NameSearch.SetScrnLen(UR.ScrnLen);
  NameSearch.SetMsgsEntered(UR.Entered);
  NameSearch.SetTimesCalled(UR.Times);
  NameSearch.SetElapsed(UR.Elapsed);
  NameSearch.SetULFiles(UR.ULFiles);
  NameSearch.SetULK(UR.ULK);
  NameSearch.SetDLFiles(UR.DLFiles);
  NameSearch.SetDLK(UR.DLK);
  NameSearch.SetTodayK(UR.TodayK);
  NameSearch.SetDelete(UR.Deleted);
  NameSearch.SetScrnClr(UR.ScrnClr);
  NameSearch.SetMore(UR.More);
  NameSearch.SetAnsi(UR.Ansi);
  NameSearch.SetAvatar(UR.Avatar);
  NameSearch.SetNoKill(UR.NoKill);
  NameSearch.SetIgnoreHrs(UR.IgnoreHrs);
  NameSearch.SetFullScrn(UR.FullScr);
  NameSearch.SetBirthDate(UR.Birthdate);
  NameSearch.SetFirstDate(UR.FirstCall);
  NameSearch.SetLastDate(UR.LastCall);
  NameSearch.SetLastTime(UR.LastTime);
  NameSearch.SetNewDate(UR.NewDate);
  NameSearch.SetExpire(UR.Expire);
  NameSearch.SetComment(UR.Comment);
  NameSearch.SetPageTune(UR.PageTune);
  NameSearch.SetProt(UR.Protocol);
  NameSearch.SetPacker(UpCase(UR.Packer));
  NameSearch.SetBankTime(UR.BankMin);
  NameSearch.SetAddr(UR.Address);
  NameSearch.SetZip(UR.ZipCode);
  NameSearch.SetOffMax(UR.MaxMsg);
  NameSearch.SetOffConfMax(UR.MaxArea);
  NameSearch.SetOffNew(UR.OffNew);
  NameSearch.SetOffScrn(UR.OffScrn);
  NameSearch.SetOffBull(UR.OffBull);
  NameSearch.SetOffVerify(UR.OffVerify);
  NameSearch.SetOffFlag(UR.OffFlag);
  NameSearch.SetOffOwn(UR.OffOwn);
  NameSearch.SetOffAll(UR.OffAll);
  NameSearch.SetOffZero(UR.OffZero);
  NameSearch.SetOffGate(UR.OffGate);
  NameSearch.SetNetStatus(UR.RealNetStat);
  For i := 1 To 500 Do
    NameSearch.SetUserOffline(i, UR.Offline[i]);
  NameSearch.SaveChanges;
  End;


Procedure DefaultUser;
  Begin
  FillChar(UR, SizeOf(UR), 0);
  UR.ScrnLen := 23;
  UR.ScrnClr := True;
  UR.More := True;
  UR.LastTime := '00:00';
  UR.PageTune := 1;
  UR.Protocol := #0;
  UR.Packer := #0;
  UR.OffScrn := True;
  UR.OffBull := True;
  UR.OffFlag := True;
  UR.OffOwn := True;
  UR.OffAll := True;
  UR.UserNum := NameSearch.GetPos;
  Letters;
  End;


{------------------------------------------------------------ checks}

Function ValidDate(S: String): Boolean;
  {empty or mm-dd-yy}
  Var
    i, N: Word;
    M, D: Word;

  Begin
  ValidDate := False;
  N := 0;                              {an empty date is blank or "  -  -  "}
  For i := 1 To Length(S) Do
    If (S[i] <> ' ') And (S[i] <> '-') Then
      Inc(N);
  If N = 0 Then
    Begin
    ValidDate := True;
    Exit;
    End;
  If (Length(S) <> 8) Or (S[3] <> '-') Or (S[6] <> '-') Then
    Exit;
  For i := 1 To 8 Do
    If (i <> 3) And (i <> 6) And ((S[i] < '0') Or (S[i] > '9')) Then
      Exit;
  M := Str2Long(Copy(S, 1, 2));
  D := Str2Long(Copy(S, 4, 2));
  ValidDate := (M >= 1) And (M <= 12) And (D >= 1) And (D <= 31);
  End;


Function ValidTime(S: String): Boolean;
  Var
    H, M: Word;

  Begin
  ValidTime := False;
  If (Length(S) <> 5) Or (S[3] <> ':') Then
    Exit;
  If (S[1] < '0') Or (S[1] > '9') Or (S[2] < '0') Or (S[2] > '9') Or
     (S[4] < '0') Or (S[4] > '9') Or (S[5] < '0') Or (S[5] > '9') Then
    Exit;
  H := Str2Long(Copy(S, 1, 2));
  M := Str2Long(Copy(S, 4, 2));
  ValidTime := (H < 24) And (M < 60);
  End;


{------------------------------------------------------------ pick lists}

Function NetItem(Item: Word): String;
  Begin
  NetItem := ' Network - ' + Chr(Ord('A') + Item - 1);
  End;


Function AreaItem(Item: Word): String;
  Begin
  AreaItem := ' ' + PadRight(Long2Str(Item), ' ', 4) + Copy(Config^.GetMsgName(Item), 1, 30);
  End;


Procedure PickNetworks(Data: Pointer; Title: String);
  Var
    Marks: CfgBigMarks;
    i: Word;
    Mask: LongInt;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  Mask := 1;
  For i := 1 To 26 Do
    Begin
    Marks[i] := (UR.RealNetStat And Mask) <> 0;
    Mask := Mask Shl 1;
    End;
  If RunMarkList('Networks', 26, 30, NetItem, Marks) Then
    Begin
    UR.RealNetStat := 0;
    Mask := 1;
    For i := 1 To 26 Do
      Begin
      If Marks[i] Then
        UR.RealNetStat := UR.RealNetStat Or Mask;
      Mask := Mask Shl 1;
      End;
    Letters;
    End;
  End;


Procedure PickOfflineAreas(Data: Pointer; Title: String);
  Begin
  If RunMarkList('Offline Mail Areas', 500, 44, AreaItem, UR.Offline) Then
    Letters;
  End;


{------------------------------------------------------------ the edit screen}

Const
  BlankDate = '  -  -  ';

Procedure ToForm(Var S: String);
  {a blank date ("  -  -  " in the file) is empty in the form: the input line only allows digits and "-"}
  Var
    i: Word;
    N: Word;

  Begin
  N := 0;
  For i := 1 To Length(S) Do
    If (S[i] <> ' ') And (S[i] <> '-') Then
      Inc(N);
  If N = 0 Then
    S := '';
  End;


Procedure FromForm(Var S: String);
  Begin
  If S = '' Then
    S := BlankDate;
  End;


Function EditUser: Boolean;
  Var
    F: CfgFormObj;
    Done, Again: Boolean;

  Begin
  EditUser := False;
  Done := False;
  ToForm(UR.Birthdate);
  ToForm(UR.FirstCall);
  ToForm(UR.Expire);
  ToForm(UR.LastCall);
  ToForm(UR.NewDate);
  While Not Done Do
    Begin
    Letters;
    F.Init('User Editor');
    F.Window(1, 1, 78, 23);
    F.At(1, 3, 1, 9);
    F.AddString('Name:', UR.Name, 35, 'User name');
    F.At(1, 49, 1, 59);
    F.Hidden;
    F.AddString('Password:', UR.Password, 15, 'Password (shown as stars)');
    F.At(2, 3, 2, 11);
    F.AddString('Handle:', UR.Handle, 35, 'Handle');
    F.At(2, 49, 2, 61);
    F.AddString('Home Phone:', UR.HomePhone, 12, 'Home (voice) phone');
    F.At(3, 3, 3, 13);
    F.AddString('Location:', UR.Location, 25, 'City / location');
    F.At(3, 49, 3, 61);
    F.AddString('Data Phone:', UR.DataPhone, 12, 'Data phone');
    F.At(5, 3, 5, 13);
    F.AddNumber('Security:', UR.Security.Level, 2, 0, 65535, 'Security level');
    F.OnF2(EditSecurity, @UR.Security, '[ User Security ]');
    F.At(5, 20, 5, 28);
    F.AddNumber('Credit:', UR.NM, 2, -32768, 32767, 'Netmail credit');
    F.At(5, 35, 5, 44);
    F.AddNumber('Pending:', UR.Pending, 2, -32768, 32767, 'Netmail pending');
    F.At(5, 51, 5, 66);
    F.AddNumber('Screen Length:', UR.ScrnLen, 2, 0, 65535, 'Lines per screen');
    F.At(6, 3, 6, 17);
    F.AddNumber('Msgs Entered:', UR.Entered, 2, 0, 65535, 'Messages entered');
    F.At(6, 24, 6, 38);
    F.AddNumber('Times Called:', UR.Times, 2, 0, 65535, 'Number of calls');
    F.At(6, 45, 6, 59);
    F.AddNumber('Elapsed Time:', UR.Elapsed, 2, 0, 65535, 'Minutes used today');
    F.At(7, 3, 7, 9);
    F.AddNumber('UL #:', UR.ULFiles, 2, 0, 65535, 'Files uploaded');
    F.At(7, 16, 7, 23);
    F.AddNumber('UL Kb:', UR.ULK, 2, 0, 65535, 'Kb uploaded');
    F.At(7, 30, 7, 36);
    F.AddNumber('DL #:', UR.DLFiles, 2, 0, 65535, 'Files downloaded');
    F.At(7, 43, 7, 50);
    F.AddNumber('DL Kb:', UR.DLK, 2, 0, 65535, 'Kb downloaded');
    F.At(7, 57, 7, 67);
    F.AddNumber('Today Kb:', UR.TodayK, 2, 0, 65535, 'Kb downloaded today');
    F.At(8, 3, 8, 12);
    F.AddYesNo('Deleted:', UR.Deleted, 'The user is marked deleted');
    F.At(8, 16, 8, 30);
    F.AddYesNo('Screen Clear:', UR.ScrnClr, 'Clear the screen between menus');
    F.At(8, 34, 8, 40);
    F.AddYesNo('More:', UR.More, 'Pause after each screen');
    F.At(8, 44, 8, 50);
    F.AddYesNo('Ansi:', UR.Ansi, 'Ansi graphics');
    F.At(8, 54, 8, 62);
    F.AddYesNo('Avatar:', UR.Avatar, 'Avatar graphics');
    F.At(8, 66, 8, 75);
    F.AddYesNo('No Kill:', UR.NoKill, 'Never deleted by the pack');
    F.At(9, 3, 9, 15);
    F.AddYesNo('Ignore Hrs:', UR.IgnoreHrs, 'Ignore the time restrictions');
    F.At(9, 19, 9, 37);
    F.AddYesNo('Full Scrn Editor:', UR.FullScr, 'Full screen message editor');
    F.At(11, 3, 11, 14);
    F.Filter('0123456789-');
    F.AddString('Birthdate:', UR.Birthdate, 8, 'Birth date, mm-dd-yy');
    F.At(11, 24, 11, 38);
    F.Filter('0123456789-');
    F.AddString('First Called:', UR.FirstCall, 8, 'First call, mm-dd-yy');
    F.At(11, 48, 11, 60);
    F.Filter('0123456789-');
    F.AddString('Expiration:', UR.Expire, 8, 'Expiration date, mm-dd-yy');
    F.At(12, 3, 12, 16);
    F.Filter('0123456789-');
    F.AddString('Last Called:', UR.LastCall, 8, 'Last call, mm-dd-yy');
    F.At(12, 27, 12, 27);
    F.Filter('0123456789:');
    F.AddString('', UR.LastTime, 5, 'Time of the last call, hh:mm');
    F.At(12, 36, 12, 52);
    F.Filter('0123456789-');
    F.AddString('New Files Date:', UR.NewDate, 8, 'New files since, mm-dd-yy');
    F.At(13, 3, 13, 14);
    F.AddNumber('Page Tune:', UR.PageTune, 1, 0, 255, 'Page tune number');
    F.At(14, 3, 14, 12);
    F.Show(40);
    F.AddString('Address:', UR.Address, 40, 'Street address');
    F.At(14, 55, 14, 65);
    F.AddString('Zip Code:', UR.ZipCode, 10, 'Zip / postal code');
    F.At(15, 3, 15, 12);
    F.Show(60);
    F.AddString('Comment:', UR.Comment, 60, 'Comment');
    F.At(16, 3, 16, 13);
    F.AddChar('Protocol:', UR.Protocol, 'Default protocol letter');
    F.At(16, 16, 16, 24);
    F.AddChar('Packer:', UR.Packer, 'Default archive packer letter');
    F.At(16, 27, 16, 37);
    F.AddNumber('Max Msgs:', UR.MaxMsg, 2, 0, 65535, 'Most messages in an offline packet');
    F.At(16, 44, 16, 58);
    F.AddNumber('Max Per Area:', UR.MaxArea, 2, 0, 65535, 'Most messages per area in a packet');
    F.At(16, 65, 16, 71);
    F.ReadOnly;
    F.Show(5);
    F.AddString('Nets:', UR.NetStr, 8, 'Networks the user may use (F2 or Space chooses)');
    F.OnF2(PickNetworks, Nil, '');
    F.At(17, 3, 0, 0);
    F.AddText('Offline:');
    F.At(17, 12, 17, 23);
    F.AddYesNo('New Files:', UR.OffNew, 'Offline: new files list');
    F.At(17, 28, 17, 35);
    F.AddYesNo('Scrns:', UR.OffScrn, 'Offline: screens');
    F.At(17, 40, 17, 47);
    F.AddYesNo('Bulls:', UR.OffBull, 'Offline: bulletins');
    F.At(17, 52, 17, 60);
    F.AddYesNo('Verify:', UR.OffVerify, 'Offline: verify the packet');
    F.At(17, 65, 17, 71);
    F.AddYesNo('Flag:', UR.OffFlag, 'Offline: flag messages as received');
    F.At(18, 12, 18, 21);
    F.AddYesNo('Own Msg:', UR.OffOwn, 'Offline: send the user''s own messages');
    F.At(18, 28, 18, 38);
    F.AddYesNo('All Your:', UR.OffAll, 'Offline: search all areas for your mail');
    F.At(18, 44, 18, 54);
    F.AddYesNo('Zero Pkt:', UR.OffZero, 'Offline: send empty packets');
    F.At(18, 60, 18, 69);
    F.AddYesNo('GateWay:', UR.OffGate, 'Offline: mail gateway');
    F.At(19, 3, 19, 22);
    F.AddNumber('Time Bank Minutes:', UR.BankMin, 2, 0, 65535, 'Minutes in the time bank');
    F.At(19, 34, 19, 41);
    F.ReadOnly;
    F.Show(4);
    F.AddString('Areas:', UR.OffCount, 4, 'Offline mail areas (F2 or Space chooses)');
    F.OnF2(PickOfflineAreas, Nil, '');
    F.At(19, 58, 19, 71);
    F.ReadOnly;
    F.AddNumber('User Number:', UR.UserNum, 4, 0, 65535, 'Position in the user file');
    If Not F.Execute Then
      Begin
      FromForm(UR.Birthdate);
      FromForm(UR.FirstCall);
      FromForm(UR.Expire);
      FromForm(UR.LastCall);
      FromForm(UR.NewDate);
      Exit;
      End;
    Again := False;
    If Not ValidDate(UR.Birthdate) Then
      Again := True;
    If Not ValidDate(UR.FirstCall) Then
      Again := True;
    If Not ValidDate(UR.Expire) Then
      Again := True;
    If Not ValidDate(UR.LastCall) Then
      Again := True;
    If Not ValidDate(UR.NewDate) Then
      Again := True;
    If Not ValidTime(UR.LastTime) Then
      Again := True;
    If Again Then
      MsgBox('A date is not mm-dd-yy or the time is not hh:mm')
    Else
      Begin
      Done := True;
      EditUser := True;
      FromForm(UR.Birthdate);
      FromForm(UR.FirstCall);
      FromForm(UR.Expire);
      FromForm(UR.LastCall);
      FromForm(UR.NewDate);
      End;
    End;
  End;


{------------------------------------------------------------ templates}

Procedure EditTemplates;
  Var
    F: CfgFormObj;
    Ct: Word;
    Row: Word;

  Begin
  F.Init('Validation Templates');
  F.Window(12, 5, 59, 17);
  F.At(2, 7, 0, 0);
  F.AddText('Security');
  F.At(2, 18, 0, 0);
  F.AddText('FileName');
  F.At(2, 33, 0, 0);
  F.AddText('Area');
  F.At(2, 40, 0, 0);
  F.AddText('Priv');
  For Ct := 1 To MaxTemplates Do
    Begin
    Row := 3 + Ct;
    F.At(Row, 4, Row, 8);
    F.AddNumber('#' + Long2Str(Ct) + ':', UserEdCfg.VRec[Ct].Sec.Level, 2, 0, 65535,
      'Security level of template ' + Long2Str(Ct) + ' (F2: level and flags)');
    F.OnF2(EditSecurity, @UserEdCfg.VRec[Ct].Sec, '[ Template ' + Long2Str(Ct) + ' Sec ]');
    F.At(Row, 16, Row, 16);
    F.AddString('', UserEdCfg.VRec[Ct].MsgName, 13, 'Text file with the welcome message (first line from, second subject)');
    F.At(Row, 33, Row, 33);
    F.AddNumber('', UserEdCfg.VRec[Ct].MsgArea, 2, 0, 65535, 'Message area the welcome message goes to');
    F.At(Row, 42, Row, 42);
    F.AddYesNo('', UserEdCfg.VRec[Ct].Priv, 'Private message');
    End;
  If F.Execute Then
    SaveCfg;
  End;


Function TemplateLine(N: Word): String;
  Begin
  TemplateLine := Long2Str(N) + ': security ' + Long2Str(UserEdCfg.VRec[N].Sec.Level) +
    '  message ' + PadRight(UserEdCfg.VRec[N].MsgName, ' ', 13) + ' area ' +
    Long2Str(UserEdCfg.VRec[N].MsgArea);
  End;


{------------------------------------------------------------ validation}

Procedure SendMsg(ValNum: Word);
  Var
    NewArea: Word;
    TMsg: AbsMsgPtr;
    TempAddr: AddrType;
    TF: TFile;
    TmpStr: String;

  Begin
  If Not FileExist(Config^.GetBbsPath + UserEdCfg.VRec[ValNum].MsgName) Then
    Begin
    MsgBox('Message file ' + UserEdCfg.VRec[ValNum].MsgName + ' not found');
    Exit;
    End;
  NewArea := UserEdCfg.VRec[ValNum].MsgArea;
  TMsg := Nil;
  If Not OpenMsgArea(TMsg, Config^.GetMsgAreaId(NewArea)) Then
    Begin
    MsgBox('Unable to open message area ' + Long2Str(NewArea));
    Exit;
    End;
  TF.Init;
  If TF.OpenTextFile(Config^.GetBbsPath + UserEdCfg.VRec[ValNum].MsgName) Then
    Begin
    TMsg^.StartNewMsg;
    Case Config^.GetMsgType(NewArea) Of
      Normal: TMsg^.SetMailType(mmtNormal);
      EchoMail: TMsg^.SetMailType(mmtEchoMail);
      NetMail: TMsg^.SetMailType(mmtNetMail);
      End;
    If Config^.GetMsgType(NewArea) = NetMail Then
      Begin
      Config^.GetMsgAddr(NewArea, TempAddr);
      TMsg^.SetOrig(TempAddr);
      TMsg^.SetDest(TempAddr);
      End;
    TmpStr := Proper(TF.GetString);
    TMsg^.SetFrom(TmpStr);
    TMsg^.SetTo(UR.Name);
    TmpStr := Proper(TF.GetString);
    TMsg^.SetSubj(TmpStr);
    TMsg^.SetPriv(UserEdCfg.VRec[ValNum].Priv);
    TMsg^.SetDate(DateStr(GetDosDate));
    TMsg^.SetTime(TimeStr(GetDosDate));
    TMsg^.SetLocal(True);
    TMsg^.SetEcho(False);
    TmpStr := TF.GetString;
    If TF.StringFound Then
      Begin
      While TF.StringFound Do
        Begin
        TMsg^.DoStringLn(TmpStr);
        TmpStr := TF.GetString;
        End;
      If TMsg^.WriteMsg <> 0 Then
        MsgBox('The message could not be written');
      End;
    If TF.CloseTextFile Then;
    End
  Else
    MsgBox('Unable to read ' + UserEdCfg.VRec[ValNum].MsgName);
  TF.Done;
  If CloseMsgArea(TMsg) Then;
  End;


Procedure ApplyTemplate(N: Word);
  Begin
  If (N < 1) Or (N > MaxTemplates) Then
    Exit;
  UR.Security.Level := UserEdCfg.VRec[N].Sec.Level;
  UR.Security.Flags := UR.Security.Flags Or UserEdCfg.VRec[N].Sec.Flags;
  If DoYesNo('[ Send Message ]', True) = 1 Then
    SendMsg(N);
  SaveUser;
  End;


Procedure LoadAnswers;
  {The lines of NewUser.Asw after "*** <name> completed questionaire"}
  Var
    T: TFile;
    TmpStr, SearchStr: String;

  Procedure Add(S: String);
    Begin
    If AnswerCount < 17 Then
      Begin
      Inc(AnswerCount);
      AnswerLines[AnswerCount] := Copy(S, 1, 69);
      End;
    End;

  Begin
  AnswerCount := 0;
  T.Init;
  SearchStr := '*** ' + UR.Name + ' completed questionaire';
  If T.OpenTextFile(Config^.GetBbsPath + 'newuser.asw') Then
    Begin
    TmpStr := T.GetString;
    While ((T.StringFound) And (Pos(SearchStr, TmpStr) = 0)) Do
      TmpStr := T.GetString;
    If Pos(SearchStr, TmpStr) > 0 Then
      Begin
      Add(TmpStr);
      TmpStr := T.GetString;
      While ((AnswerCount < 16) And (Copy(TmpStr, 1, 3) <> '***') And (T.StringFound)) Do
        Begin
        Add(TmpStr);
        TmpStr := T.GetString;
        End;
      End
    Else
      Add('Users answers not found');
    If T.CloseTextFile Then;
    End
  Else
    Add('Unable to open NewUser.Asw File');
  T.Done;
  End;


End.
