Unit MKName;
{$I MKB.Def}

Interface

Uses MKGlobT, MKRCfgMK, MKRCfgRA, MKCfgSB, MKCfgQB;


Const BufferSize = 50;

Type NameSearchType = Record
  UserBuffer: Array[1..BufferSize] of UsersType;
  UserExtra: ^ExtUserType;
  RAExtra: ^RAUsersXIRecord;
  MKExtra: ^ExtUserType;
  SBExtra: ^SBExtraUserRec;
  ExtraLoaded: Boolean;
  UsersFilePos: LongInt;
  CurrentPos: Word;
  NumRead: Word;
  Found: Boolean;
  ExactMatch: Boolean;
  UsersFile: File;
  Opened: Boolean;
  SearchName: String[35];
  BbsType: Word;
  End;


Type NameObj = Object
  User: ^NameSearchType;
  Procedure Init; {Initialize}
  Procedure Done; {Done}
  Procedure SetBbsType (BT: Word);
  Function  SearchFirst(Name: String): Boolean;
  Function  SearchNext: Boolean;
  Procedure GoToPosition(GP: Word);
  Function  Next: Boolean;
  Function  Prior: Boolean;
  Function  GetNumUsers: Word;
  Function  Exact: Boolean; {Name found was exact match}
  Function  CheckName(Name: String): Boolean;
  Function  GetName: String; {Get name at current position}
  Function  GetLocation: String; {Get city at current position}
  Function  GetPwd: String; {get password}
  Function  GetDataPhone: String;
  Function  GetVoicePhone: String;
  Function  GetLastDate: String; {Get last called Date}
  Function  GetLastTime: String; {Get last called time}
  Function  GetNMCredit: Integer;
  Function  GetNMPending: Integer;
  Function  GetMsgsEntered: Word;
  Function  GetHighMsgRead: Word;
  Function  GetTimesCalled: Word;
  Function  GetULFiles: Word;
  Function  GetDLFiles: Word;
  Function  GetULK: Word;
  Function  GetDLK: Word;
  Function  GetTodayK: Word;
  Function  GetElapsed: Word;
  Function  GetScrnLen: Word;
  Function  GetBirthDate: String;
  Function  GetFirstDate: String;
  Procedure SetName(Name: String); {set name}
  Procedure SetLocation(Loc: String); {set location}
  Procedure SetPwd(Pwd: String);
  Procedure SetDataPhone(DP: String);
  Procedure SetVoicePhone(VP: String);
  Procedure SetLastDate(LD: String); {set last called date}
  Procedure SetLastTime(LT: String); {set last called time}
  Procedure SetNMCredit(NM: Integer);
  Procedure SetNMPending(Pend: Integer);
  Procedure SetMsgsEntered(Entered: Word);
  Procedure SetHighMsgRead(HiMsgRead: Word);
  Procedure SetTimesCalled(Times: Word);
  Procedure SetULFiles(UL: Word);
  Procedure SetDLFiles(DL: Word);
  Procedure SetULK(ULK: Word);
  Procedure SetDLK(DLK: Word);
  Procedure SetTodayK(TK: Word);
  Procedure SetElapsed(EL: Word);
  Procedure SetScrnLen(SL: Word);
  Function  GetPos: Word; {Get current user position}
  Procedure GetSec(Var Sec: SecType); {Get security level}
  Procedure SetSec(Var Sec: SecType); {Set security level}
  Procedure SaveChanges; {Save changed user values}
  Procedure SetAttr(Mask: Byte; Setting: Boolean);
  Procedure SetDelete(SD: Boolean);
  Procedure SetScrnClr(ST: Boolean);
  Procedure SetMore(ST: Boolean);
  Procedure SetAnsi(ST: Boolean);
  Procedure SetNoKill(ST: Boolean);
  Procedure SetIgnoreHrs(ST: Boolean);
  Procedure SetFullScrn(ST: Boolean);
  Procedure SetAvatar(ST: Boolean);
  Procedure SetBirthDate(BD: String);
  Procedure SetFirstDate(BD: String);
  Function  IsDeleted: Boolean;
  Function  IsScrnClr: Boolean;
  Function  IsMore: Boolean;
  Function  IsAnsi: Boolean;
  Function  IsNoKill: Boolean;
  Function  IsIgnoreHrs: Boolean;
  Function  IsFullScrn: Boolean;
  Function  IsAvatar: Boolean;
  Function  GetComment: String;
  Procedure SetComment(CM: String);
  Function  GetHandle: String;
  Procedure SetHandle(HD: String);
  Function  GetPageTune: Word;
  Procedure SetPageTune(PT: Word);
  Procedure LoadExtra; {Load extended user info}
  Procedure SaveExtra; {save extended user info}
  Function  GetProt: Char;  {Get default protocol}
  Procedure SetProt(Prot: Char); {Set default protocol}
  Function  GetExpire: String; {Expiration date}
  Procedure SetExpire(Expire: String); {Set expiration date}
  Function  GetNewDate: String; {Last new files date}
  Procedure SetNewDate(ND: String); {Set new files date}
  Function  GetPacker: Char; {Get default archive packer}
  Procedure SetPacker(Pk: Char); {Set default packer}
  Function  GetFileArea: Word; {Get current file area}
  Procedure SetFileArea(AR: Word); {Set current file area}
  Function  GetMsgArea: Word; {Get current msg area}
  Procedure SetMsgArea(AR: Word); {Set current msg area}
  Function  GetDoorArea: Word; {Get current door area}
  Procedure SetDoorArea(AR: Word); {Set current door area}
  Function  GetBankTime: Word; {Get time bank time}
  Procedure SetBankTime(BT: Word); {Set time bank time}
  Function  GetTodayCalls: Word; {Get # calls today}
  Procedure SetTodayCalls(TC: Word); {Set # calls today}
  Function  GetAddr: String; {Get address}
  Procedure SetAddr(Ad: String); {Set address}
  Function  GetZip: String; {Get zip code}
  Procedure SetZip(Zp: String); {set zip code}
  Function  GetOffMax: Word; {Get max offline msgs}
  Procedure SetOffMax(OM: Word); {Set max offline msgs}
  Function  GetOffConfMax: Word; {Get max msgs per area}
  Procedure SetOffConfMax(OM: Word); {Set max msgs per area}
  Function  GetOffNew: Boolean; {Offline new files list}
  Procedure SetOffNew(OO: Boolean); {new files list}
  Function  GetOffScrn: Boolean; {offline screens}
  Procedure SetOffScrn(OO: Boolean); {offline screens}
  Function  GetOffBull: Boolean; {offline bulletins}
  Procedure SetOffBull(OO: Boolean); {offline bulletins}
  Function  GetOffVerify: Boolean; {offline verify want pkt}
  Procedure SetOffVerify(OO: Boolean); {offline verify}
  Function  GetOffFlag: Boolean; {offline flag as rcvd}
  Procedure SetOffFlag(OO: Boolean); {flag as rcvd}
  Function  GetOffOwn: Boolean; {Send own msgs}
  Procedure SetOffOwn(OO: Boolean); {send own msgs}
  Function  GetOffAll: Boolean; {Search all areas your mail}
  Procedure SetOffAll(OO: Boolean); {all areas your mail}
  Function  GetOffZero: Boolean; {Send zero msg pkts}
  Procedure SetOffZero(OO: Boolean); {send zero msg pkts}
  Function  GetOffGate: Boolean; {Offline mail gateway}
  Procedure SetOffGate(OO: Boolean); {offline mail gateway}
  Function  GetNetStatus: LongInt; {Get net status}
  Procedure SetNetStatus(NS: LongInt); {Set net status}
  Procedure SetUserOffline(Area: Word; St: Boolean);
  Function  GetUserOffline(Area: Word): Boolean;
  End;


Var
  NameSearch: NameObj;


Implementation


Uses MKFile, MKString, MKCfgAbs,
  Dos;


Procedure NameObj.Init;                      {Initialize}
  Begin
  New(User);
  User^.CurrentPos := 0;
  User^.ExactMatch := False;
  User^.Found := False;
  User^.Opened := False;
  User^.ExtraLoaded := False;
  User^.BbsType := 0;
  End;


Procedure NameObj.Done;                      {Done}
  Begin
  If User^.Opened Then
    Close(User^.UsersFile);
  Dispose(User);
  End;


Function NameObj.GetNumUsers: Word;
  Begin
  GetNumUsers := FileSize(User^.UsersFile);
  End;


Procedure NameObj.SetBbsType (BT: Word);
  Begin
  Case User^.BbsType of
    1: Dispose(User^.MKExtra);
    2: Dispose(User^.RAExtra);
    4: Dispose(User^.SBExtra);
    End;
  User^.BbsType := BT;
  Case User^.BbsType of
    1: New(User^.MKExtra);
    2: New(User^.RAExtra);
    4: New(User^.SBExtra);
    End;
  User^.ExtraLoaded := False;
  End;


Function NameObj.Exact: Boolean;
  Begin
  Exact := User^.ExactMatch;
  End;


Procedure NameObj.GoToPosition(GP: Word);
  Begin
  If Not User^.Opened Then
    Begin
    If Not shAssign(User^.UsersFile, Config^.FindBbsFile('users.bbs') + 'users.bbs') Then;
    FileMode := fmReadWrite + fmDenyNone;
    If Not shReset(User^.UsersFile, SizeOf(UsersType)) Then;
    End;
  Seek(User^.UsersFile, GP);
  User^.UsersFilePos := FilePos(User^.UsersFile);
  FillChar(User^.UserBuffer, SizeOf(User^.UserBuffer), 0);
  If shRead(User^.UsersFile, User^.UserBuffer, BufferSize, User^.NumRead) Then;
  User^.CurrentPos := 1;
  User^.ExtraLoaded := False;
  End;


Function NameObj.SearchFirst(Name: String): Boolean;
  Begin
  User^.SearchName := Upper(Name);
  If Not User^.Opened Then
    Begin
    If Not shAssign(User^.UsersFile, Config^.FindBbsFile('users.bbs') + 'users.bbs') Then;
    FileMode := fmReadWrite + fmDenyNone;
    If Not shReset(User^.UsersFile, SizeOf(UsersType)) Then;
    End
  Else
    Begin
    Seek(User^.UsersFile, 0);
    If IoResult <> 0 Then;
    End;
  User^.NumRead := 0;
  User^.CurrentPos := 10;
  SearchFirst := SearchNext;
  End;


Function NameObj.SearchNext: Boolean;
  Var
    Finished: Boolean;

  Begin
  Finished := False;
  User^.ExtraLoaded := False;
  User^.Found := False;
  User^.ExactMatch := False;
  While (Not Finished) And Not (User^.Found) Do
    Begin
    If (User^.CurrentPos >= User^.NumRead) Then
      If (Not Eof(User^.UsersFile)) Then
        Begin
        User^.UsersFilePos := FilePos(User^.UsersFile);
        If shRead(User^.UsersFile, User^.UserBuffer, BufferSize, User^.NumRead) Then;
          User^.CurrentPos := 0;
        End
      Else
        Finished := True;
    While ((User^.CurrentPos < User^.NumRead) and (Not User^.Found)) Do
      Begin
        Inc(User^.CurrentPos);
        If ((Length(User^.SearchName) = 0) Or (Pos(User^.SearchName,
        Upper(User^.UserBuffer[User^.CurrentPos].Name)) > 0)) Then
          Begin
          If Not IsDeleted Then
            Begin
            User^.Found := True;
            User^.ExactMatch :=
            (Upper(User^.UserBuffer[User^.CurrentPos].Name) = User^.SearchName);
            End;
          End;
      End;
    End;
  SearchNext := User^.Found;
  End;


Function NameObj.Next: Boolean;
  Begin
  Next := True;
  User^.ExtraLoaded := False;
  Inc(User^.CurrentPos);
  If User^.CurrentPos > User^.NumRead Then
    Begin
    User^.UsersFilePos := FilePos(User^.UsersFile);
    If shRead(User^.UsersFile, User^.UserBuffer, BufferSize, User^.NumRead) Then;
      User^.CurrentPos := 1;
    If User^.NumRead = 0 Then
      Next := False;
    End;
  End;


Function NameObj.Prior: Boolean;
  Begin
  Prior := True;
  User^.ExtraLoaded := False;
  Dec(User^.CurrentPos);
  If User^.CurrentPos < 1 Then
    Begin
    If User^.UsersFilePos > BufferSize Then
      Begin
      Dec(User^.UsersFilePos, BufferSize);
      Seek(User^.UsersFile, User^.UsersFilePos);
      If shRead(User^.UsersFile, User^.UserBuffer, BufferSize, User^.NumRead) Then;
        User^.CurrentPos := User^.NumRead;
      End
    Else
      Begin
      If User^.UsersFilePos > 0 Then
        Begin
        Seek(User^.UsersFile, 0);
        If shRead(User^.UsersFile, User^.UserBuffer, User^.UsersFilePos, User^.NumRead) Then;
          User^.CurrentPos := User^.NumRead;
        User^.UsersFilePos := 0;
        End
      Else
        Prior := False;
      End;
    End;
  End;


Procedure NameObj.SaveChanges; {Save changed user values}
  Var
    TmpPos: LongInt;
    Idx: UsersIdxType;

  Begin
  TmpPos := FilePos(User^.UsersFile);
  Seek(User^.UsersFile, User^.UsersFilePos + User^.CurrentPos - 1);
  If IoResult = 0 Then
{    If (User^.CurrentPos <= User^.NumRead + 1) Then }
  If shWrite(User^.UsersFile, User^.UserBuffer[User^.CurrentPos], 1) Then;
  Seek(User^.UsersFile, TmpPos);
  If IoResult <> 0 Then;
  Case User^.BBSType of
    1,2: Begin
       Idx.NameCrc := NameCrcCode(GetName);
       Idx.HandleCrc := NameCrcCode(GetHandle);
       If SaveFilePos(Config^.FindBBSFile('usersidx.bbs') + 'usersidx.bbs',
         Idx, SizeOf(Idx), LongInt(GetPos) * SizeOf(Idx)) = 0 Then;
       End;
    End;
  SaveExtra;
  End;


Function NameObj.GetName: String;
  Begin
  GetName := User^.UserBuffer[User^.CurrentPos].Name;
  End;


Procedure NameObj.SetLocation(Loc: String); {set location}
  Begin
  User^.UserBuffer[User^.CurrentPos].City := Loc;
  End;


Procedure NameObj.SetName(Name: String); {set name}
  Begin
  User^.UserBuffer[User^.CurrentPos].Name := Name;
  End;


Procedure NameObj.SetLastDate(LD: String); {set last called date}
  Begin
  User^.UserBuffer[User^.CurrentPos].LastDateOn := LD;
  End;


Procedure NameObj.SetLastTime(LT: String); {set last called time}
  Begin
  User^.UserBuffer[User^.CurrentPos].LastTimeOn := LT;
  End;


Procedure NameObj.SetNMCredit(NM: Integer);
  Begin
  User^.UserBuffer[User^.CurrentPos].Credit := NM;
  End;


Procedure NameObj.SetNMPending(Pend: Integer);
  Begin
  User^.UserBuffer[User^.CurrentPos].Pending := Pend;
  End;


Procedure NameObj.SetMsgsEntered(Entered: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].MsgsEntered := Entered;
  End;


Procedure NameObj.SetHighMsgRead(HiMsgRead: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].HighMsgRead := HiMsgRead;
  End;


Procedure NameObj.SetTimesCalled(Times: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].TimesCalled := Times;
  End;


Procedure NameObj.SetULFiles(UL: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].ULFiles := UL;
  End;


Procedure NameObj.SetDLFiles(DL: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].DLFiles := DL;
  End;


Procedure NameObj.SetULK(ULK: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].ULK := ULK;
  End;


Procedure NameObj.SetDLK(DLK: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].DLK := DLK;
  End;


Procedure NameObj.SetTodayK(TK: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].TodayK := TK;
  End;


Procedure NameObj.SetElapsed(EL: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].ElapsedTime := EL;
  End;


Procedure NameObj.SetScrnLen(SL: Word);
  Begin
  User^.UserBuffer[User^.CurrentPos].ScrnLen := SL;
  End;


Function NameObj.IsDeleted: Boolean;
  Begin
  IsDeleted := ((User^.UserBuffer[User^.CurrentPos].Attr and uaDeleted) <> 0);
  End;


Function NameObj.IsScrnClr: Boolean;
  Begin
  IsScrnClr := ((User^.UserBuffer[User^.CurrentPos].Attr and uaScrnClr) <> 0);
  End;


Function NameObj.IsMore: Boolean;
  Begin
  IsMore := ((User^.UserBuffer[User^.CurrentPos].Attr and uaMore) <> 0);
  End;


Function NameObj.IsAnsi: Boolean;
  Begin
  IsAnsi := ((User^.UserBuffer[User^.CurrentPos].Attr and uaAnsi) <> 0);
  End;


Function NameObj.IsNoKill: Boolean;
  Begin
  IsNoKill := ((User^.UserBuffer[User^.CurrentPos].Attr and uaNoKill) <> 0);
  End;


Function NameObj.IsIgnoreHrs: Boolean;
  Begin
  IsIgnoreHrs := ((User^.UserBuffer[User^.CurrentPos].Attr and uaIgnoreHrs) <> 0);
  End;


Function NameObj.IsFullScrn: Boolean;
  Begin
  IsFullScrn := ((User^.UserBuffer[User^.CurrentPos].Attr and uaFullScrEd) <> 0);
  End;


Procedure NameObj.SetAttr(Mask: Byte; Setting: Boolean);
  Begin
  If Setting Then
    User^.UserBuffer[User^.CurrentPos].Attr :=
    User^.UserBuffer[User^.CurrentPos].Attr or Mask
  Else
    User^.UserBuffer[User^.CurrentPos].Attr :=
    User^.UserBuffer[User^.CurrentPos].Attr and (not Mask);
  End;


Procedure NameObj.SetDelete(SD: Boolean);
  Begin
  SetAttr(uaDeleted, SD);
  End;


Procedure NameObj.SetScrnClr(ST: Boolean);
  Begin
  SetAttr(uaScrnClr, ST);
  End;


Procedure NameObj.SetMore(ST: Boolean);
  Begin
  SetAttr(uaMore, ST);
  End;


Procedure NameObj.SetAnsi(ST: Boolean);
  Begin
  SetAttr(uaAnsi, ST);
  End;


Procedure NameObj.SetNoKill(ST: Boolean);
  Begin
  SetAttr(uaNoKill, ST);
  End;


Procedure NameObj.SetIgnoreHrs(ST: Boolean);
  Begin
  SetAttr(uaIgnoreHrs, ST);
  End;


Procedure NameObj.SetFullScrn(ST: Boolean);
  Begin
  SetAttr(uaFullScrEd, ST);
  End;


Procedure NameObj.SetAvatar(ST: Boolean);
  Begin
  Case User^.BbsType of
    1: If St Then
         User^.MKExtra^.ExtraInfo := User^.MKExtra^.ExtraInfo or eiAvatar
       Else
         User^.MKExtra^.ExtraInfo := User^.MKExtra^.ExtraInfo and (Not eiAvatar);
    2: If St Then
         RAUsersRecord(User^.UserBuffer[User^.CurrentPos]).Attribute2 :=
         (RAUsersRecord(User^.UserBuffer[User^.CurrentPos]).Attribute2 or 2)
       Else
         RAUsersRecord(User^.UserBuffer[User^.CurrentPos]).Attribute2 :=
         (RAUsersRecord(User^.UserBuffer[User^.CurrentPos]).Attribute2 and (Not 2));
    End;
  End;


Function NameObj.IsAvatar: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: IsAvatar := (User^.MKExtra^.ExtraInfo and eiAvatar) <> 0;
    2: IsAvatar := (RaUsersRecord(User^.UserBuffer[User^.CurrentPos]).Attribute2
       and 2) <> 0;
    Else
      IsAvatar := False;
    End;
  End;


Function NameObj.GetComment: String;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetComment := User^.MKExtra^.Comment;
    2: GetComment := User^.RAExtra^.Comment;
    4: GetComment := User^.SBExtra^.Comment;
    Else
      GetComment := '';
    End;
  End;


Procedure NameObj.SetComment(CM: String);
  Begin
  Case User^.BbsType of
    1: User^.MKExtra^.Comment := CM;
    2: User^.RAExtra^.Comment := CM;
    4: User^.SBExtra^.Comment := CM;
    End;
  End;


Function NameObj.GetPageTune: Word;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetPageTune := User^.MKExtra^.PageTune;
    Else
      GetPageTune := 1;
    End;
  End;


Procedure NameObj.SetPageTune(PT: Word);
  Begin
  Case User^.BbsType of
    1: User^.MKExtra^.PageTune := PT;
    End;
  End;

Function NameObj.GetHandle: String;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetHandle := User^.MKExtra^.Handle;
    2: GetHandle := User^.RAExtra^.Handle;
    4: GetHandle := User^.SBExtra^.Alias;
    Else
      GetHandle := '';
    End;
  End;


Procedure NameObj.SetHandle(HD: String);
  Begin
  Case User^.BbsType of
    1: User^.MKExtra^.Handle := HD;
    2: User^.RAExtra^.Handle := HD;
    4: User^.SBExtra^.Alias := HD;
    End;
  End;


Procedure NameObj.GetSec(Var Sec: SecType); {Get security level}
  Begin
  Sec.Level := User^.UserBuffer[User^.CurrentPos].Security;
  Sec.Flags := User^.UserBuffer[User^.CurrentPos].Flags;
  End;


Procedure NameObj.SetSec(Var Sec: SecType); {Get security level}
  Begin
  User^.UserBuffer[User^.CurrentPos].Security := Sec.Level;
  User^.UserBuffer[User^.CurrentPos].Flags := Sec.Flags;
  End;


Function NameObj.GetLocation: String;
  Begin
  GetLocation := User^.UserBuffer[User^.CurrentPos].City;
  End;


Function NameObj.GetLastDate: String;
  Begin
  GetLastDate := User^.UserBuffer[User^.CurrentPos].LastDateOn;
  End;


Function NameObj.GetLastTime: String;
  Begin
  GetLastTime := User^.UserBuffer[User^.CurrentPos].LastTimeOn;
  End;


Function NameObj.GetPwd: String; {get password}
  Begin
  GetPwd := User^.UserBuffer[User^.CurrentPos].Pwd;
  End;


Function NameObj.GetDataPhone: String;
  Begin
  GetDataPhone := User^.UserBuffer[User^.CurrentPos].DPhone;
  End;


Function NameObj.GetVoicePhone: String;
  Begin
  GetVoicePhone := User^.UserBuffer[User^.CurrentPos].HPhone;
  End;


Function  NameObj.GetNMCredit: Integer;
  Begin
  GetNMCredit := User^.UserBuffer[User^.CurrentPos].Credit;
  End;


Function  NameObj.GetNMPending: Integer;
  Begin
  GetNMPending := User^.UserBuffer[User^.CurrentPos].Pending;
  End;


Function  NameObj.GetMsgsEntered: Word;
  Begin
  GetMsgsEntered := User^.UserBuffer[User^.CurrentPos].MsgsEntered;
  End;


Function  NameObj.GetHighMsgRead: Word;
  Begin
  GetHighMsgRead := User^.UserBuffer[User^.CurrentPos].HighMsgRead;
  End;


Function  NameObj.GetTimesCalled: Word;
  Begin
  GetTimesCalled := User^.UserBuffer[User^.CurrentPos].TimesCalled;
  End;


Function  NameObj.GetULFiles: Word;
  Begin
  GetULFiles := User^.UserBuffer[User^.CurrentPos].ULFiles;
  End;


Function  NameObj.GetDLFiles: Word;
  Begin
  GetDLFiles := User^.UserBuffer[User^.CurrentPos].DLFiles;
  End;


Function  NameObj.GetULK: Word;
  Begin
  GetULK := User^.UserBuffer[User^.CurrentPos].ULK;
  End;


Function  NameObj.GetDLK: Word;
  Begin
  GetDLK := User^.UserBuffer[User^.CurrentPos].DLK;
  End;


Function  NameObj.GetTodayK: Word;
  Begin
  GetTodayK := User^.UserBuffer[User^.CurrentPos].TodayK;
  End;


Function  NameObj.GetElapsed: Word;
  Begin
  GetElapsed := User^.UserBuffer[User^.CurrentPos].ElapsedTime;
  End;


Function  NameObj.GetScrnLen: Word;
  Begin
  GetScrnLen := User^.UserBuffer[User^.CurrentPos].ScrnLen;
  End;


Procedure NameObj.SetPwd(Pwd: String);
  Begin
  User^.UserBuffer[User^.CurrentPos].Pwd := Pwd;
  End;


Procedure NameObj.SetDataPhone(DP: String);
  Begin
  User^.UserBuffer[User^.CurrentPos].DPhone := DP;
  End;


Procedure NameObj.SetVoicePhone(VP: String);
  Begin
  User^.UserBuffer[User^.CurrentPos].HPhone:= VP;
  End;


Function NameObj.GetPos: Word;
  Begin
  GetPos := User^.CurrentPos + User^.UsersFilePos - 1;
  End;


Procedure NameObj.LoadExtra;
  Var
    i: LongInt;

  Begin
  Case User^.BbsType of
    1: Begin
       User^.ExtraLoaded := True;
       i := GetPos;
       i := i * SizeOf(ExtUserType);
       FillChar(User^.MKExtra^, SizeOf(ExtUserType),0);
       If LoadFilePos(Config^.FindBbsFile('extusers.bbs') + 'extusers.bbs',
         User^.MKExtra^, SizeOf(ExtUserType), i) = 0 Then;
       End;
    2: Begin
       i := RaUsersRecord(User^.UserBuffer[User^.CurrentPos]).XIRecord;
       i := i * SizeOf(RAUsersXIRecord);
       FillChar(User^.RAExtra^, SizeOf(RAUsersXIRecord), 0);
       If LoadFilePos(Config^.FindBbsFile('usersxi.bbs') + 'usersxi.bbs',
         User^.RaExtra^, SizeOf(RAUsersXIRecord), i) = 0 Then;
       User^.ExtraLoaded := True;
       End;
    4: Begin
       i := SbUserRecord(User^.UserBuffer[User^.CurrentPos]).ExtraUserRecPtr;
       i := i * SizeOf(SBExtraUserRec);
       FillChar(User^.SBExtra^, SizeOf(SBExtraUserRec), 0);
       If LoadFilePos(Config^.FindBbsFile('susers.bbs') + 'susers.bbs',
         User^.SBExtra^, SizeOf(SbExtraUserRec), i) = 0 Then;
       User^.ExtraLoaded := True;
       End;
    End;
  End;


Procedure NameObj.SaveExtra;
  Var
    i: LongInt;

  Begin
  If User^.ExtraLoaded Then
    Begin
    Case User^.BbsType of
      1: Begin
         i := GetPos;
         i := i * SizeOf(ExtUserType);
         If SaveFilePos(Config^.FindBbsFile('extusers.bbs') + 'extusers.bbs',
           User^.MKExtra^, SizeOf(ExtUserType), i) = 0 Then;
         End;
      2: Begin
         i := RaUsersRecord(User^.UserBuffer[User^.CurrentPos]).XIRecord;
         i := i * SizeOf(RAUsersXIRecord);
         If SaveFilePos(Config^.FindBbsFile('usersxi.bbs') + 'usersxi.bbs',
           User^.RaExtra^, SizeOf(RAUsersXIRecord), i) = 0 Then;
         End;
      4: Begin
         i := SbUserRecord(User^.UserBuffer[User^.CurrentPos]).ExtraUserRecPtr;
         i := i * SizeOf(SBExtraUserRec);
         If SaveFilePos(Config^.FindBbsFile('susers.bbs') + 'susers.bbs',
           User^.SBExtra^, SizeOf(SbExtraUserRec), i) = 0 Then;
         End;
      End;
    End;
  End;


Function NameObj.CheckName(Name: String): Boolean;
  Begin
  If SearchFirst(Name) Then
    Begin
    While ((User^.Found) and (Not Exact)) Do
      If SearchNext Then;
    CheckName := Exact;
    End
  Else
    CheckName := False;
  End;


Function NameObj.GetBirthDate: String;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: If Length(User^.MKExtra^.BirthDate) = 0 Then
         GetBirthDate := ''
       Else
         GetBirthDate := MKDateToStr(User^.MKExtra^.BirthDate);
    2: GetBirthDate := User^.RAExtra^.BirthDate;
    4: GetBirthDate := User^.SBExtra^.BirthDay;
    Else
      GetBirthDate := '';
    End;
  End;


Procedure NameObj.SetBirthDate(BD: String);
  Begin
  Case User^.BbsType of
    1: User^.MKExtra^.BirthDate := StrToMKDate(BD);
    2: User^.RAExtra^.BirthDate := BD;
    4: User^.SBExtra^.BirthDay := BD;
    End;
  End;


Function NameObj.GetFirstDate: String;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: If Length(User^.MKExtra^.FirstCall) = 0 Then
         GetFirstDate := ''
       Else
         GetFirstDate := MKDateToStr(User^.MKExtra^.FirstCall);
    2: GetFirstDate := User^.RAExtra^.FirstDate;
    4: GetFirstDate := User^.SBExtra^.FirstDate;
    Else
      GetFirstDate := '';
    End;
  End;


Procedure NameObj.SetFirstDate(BD: String);
  Begin
  Case User^.BbsType of
    1: User^.MKExtra^.FirstCall := StrToMKDate(BD);
    2: User^.RAExtra^.FirstDate := BD;
    4: User^.SBExtra^.FirstDate := BD;
    End;
  End;


Function NameObj.GetExpire: String; {Expiration date}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: If Length(User^.MKExtra^.Expire) = 0 Then
         GetExpire := ''
       Else
         GetExpire := MKDateToStr(User^.MKExtra^.Expire);
    2: GetExpire := User^.RAExtra^.SubDate;
    4: GetExpire := User^.SBExtra^.ExpireDate;
    Else
      GetExpire := '';
    End;
  End;


Procedure NameObj.SetExpire(Expire: String); {Set expiration date}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.Expire := StrToMKDate(Expire);
    2: User^.RAExtra^.SubDate := Expire;
    4: User^.SBExtra^.ExpireDate := Expire;
    End;
  End;


Function NameObj.GetNewDate: String; {Last new files date}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: If Length(User^.MKExtra^.NewDate) = 0 Then
         GetNewDate := GetLastDate
       Else
         GetNewDate := MKDateToStr(User^.MKExtra^.NewDate);
    4: GetNewDate := User^.SBExtra^.LastNewFiles;
    Else
      GetNewDate := GetLastDate;
    End;
  End;


Procedure NameObj.SetNewDate(ND: String); {Set new files date}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.NewDate := StrToMKDate(ND);
    4: User^.SBExtra^.LastNewFiles := ND;
    End;
  End;


Function NameObj.GetProt: Char;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetProt := UpCase(User^.MKExtra^.Protocol);
    4: GetProt := UpCase(User^.SBExtra^.DefProt);
    Else
      GetProt := ' ';
    End;
  End;


Procedure NameObj.SetProt(Prot: Char); {Set default protocol}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.Protocol := UpCase(Prot);
    4: User^.SBExtra^.DefProt := UpCase(Prot);
    End;
  End;


Function NameObj.GetPacker: Char;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetPacker := User^.MKExtra^.Packer;
    4: Begin
       Case User^.SBExtra^.DefPacker of
         1: GetPacker := 'Z';
         2: GetPacker := 'A';
         3: GetPacker := 'L';
         4: GetPacker := 'J';
         Else
           GetPacker := ' ';
         End;
       End;
    Else
      GetPacker := ' ';
    End;
  End;


Procedure NameObj.SetPacker(Pk: Char); {Set default packer}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.Packer := Pk;
    4: Begin
       Case PK of
         'Z': User^.SBExtra^.DefPacker := 1;
         'A': User^.SBExtra^.DefPacker := 2;
         'L': User^.SBExtra^.DefPacker := 3;
         'J': User^.SBExtra^.DefPacker := 4;
         End;
       End;
    End;
  End;


Function NameObj.GetFileArea: Word; {Get current file area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetFileArea := User^.MKExtra^.CurrFileArea;
    2: GetFileArea := User^.RAExtra^.FileArea;
    4: GetFileArea := User^.SBExtra^.CurrentFArea;
    Else
      GetFileArea := 1;
    End;
  End;


Procedure NameObj.SetFileArea(AR: Word); {Set current file area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.CurrFileArea := AR;
    2: User^.RAExtra^.FileArea := AR;
    4: User^.SBExtra^.CurrentFArea := AR;
    End;
  End;


Function NameObj.GetMsgArea: Word; {Get current msg area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetMsgArea := User^.MKExtra^.CurrMsgArea;
    2: GetMsgArea := User^.RAExtra^.MsgArea;
    4: GetMsgArea := User^.SBExtra^.CurrentMArea;
    Else
      GetMsgArea := 1;
    End;
  End;


Procedure NameObj.SetMsgArea(AR: Word); {Set current msg area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.CurrMsgArea := AR;
    2: User^.RAExtra^.MsgArea := AR;
    4: User^.SBExtra^.CurrentMArea := AR;
    End;
  End;


Function NameObj.GetDoorArea: Word; {Get current door area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetDoorArea := User^.MKExtra^.CurrDoorArea;
    4: GetDoorArea := User^.SBExtra^.CurrentDArea;
    Else
      GetDoorArea := 1;
    End;
  End;


Procedure NameObj.SetDoorArea(AR: Word); {Set current door area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.CurrDoorArea := AR;
    4: User^.SBExtra^.CurrentDArea := AR;
    End;
  End;

Function NameObj.GetBankTime: Word; {Get time bank time}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetBankTime := User^.MKExtra^.BankTime;
    4: GetBankTime := User^.SBExtra^.TimeInBank;
    Else
      GetBankTime := 0;
    End;
  End;


Procedure NameObj.SetBankTime(BT: Word); {Set time bank time}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.BankTime := BT;
    4: User^.SBExtra^.TimeInBank := BT;
    End;
  End;


Function NameObj.GetTodayCalls: Word; {Get # calls today}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetTodayCalls := User^.MKExtra^.TodayCalls;
    4: GetTodayCalls := User^.SBExtra^.TodayCalls;
    Else
      GetTodayCalls := 0;
    End;
  End;


Procedure NameObj.SetTodayCalls(TC: Word); {Set # calls today}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.TodayCalls := TC;
    4: User^.SBExtra^.TodayCalls := TC;
    End;
  End;

Function NameObj.GetAddr: String; {Get address}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetAddr := User^.MKExtra^.Address;
    Else
      GetAddr := '';
    End;
  End;


Procedure NameObj.SetAddr(Ad: String); {Set address}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.Address := Ad;
    End;
  End;


Function NameObj.GetZip: String; {Get zip code}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetZip := User^.MKExtra^.ZipCode;
    Else
      GetZip := '';
    End;
  End;


Procedure NameObj.SetZip(Zp: String); {set zip code}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: User^.MKExtra^.ZipCode := ZP;
    End;
  End;


Function NameObj.GetOffMax: Word; {Get max offline msgs}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffMax := User^.MKExtra^.OffMax;
    Else
      GetOffMax := 1000;
    End;
  End;

Procedure NameObj.SetOffMax(OM: Word); {Set max offline msgs}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: User^.MKExtra^.OffMax := Om;
    End;
  End;

Function NameObj.GetOffConfMax: Word; {Get max msgs per area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffConfMax := User^.MKExtra^.OffConfMax;
    Else
      GetOffConfMax := 1000;
    End;
  End;

Procedure NameObj.SetOffConfMax(OM: Word); {Set max msgs per area}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: User^.MKExtra^.OffConfMax := Om;
    End;
  End;

Function NameObj.GetOffNew: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffNew := (User^.MKExtra^.OffAttr and uoaNew) <> 0;
    Else
      GetOffNew := False;
    End;
  End;

Procedure NameObj.SetOffNew(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaNew
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaNew);
    End;
  End;

Function NameObj.GetOffScrn: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffScrn := (User^.MKExtra^.OffAttr and uoaScrn) <> 0;
    Else
      GetOffScrn := True;
    End;
  End;

Procedure NameObj.SetOffScrn(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaScrn
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaScrn);
    End;
  End;

Function NameObj.GetOffBull: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffBull := (User^.MKExtra^.OffAttr and uoaBull) <> 0;
    Else
      GetOffBull := True;
    End;
  End;

Procedure NameObj.SetOffBull(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaBull
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaBull);
    End;
  End;

Function NameObj.GetOffVerify: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffVerify := (User^.MKExtra^.OffAttr and uoaVerify) <> 0;
    Else
      GetOffVerify := False;
    End;
  End;

Procedure NameObj.SetOffVerify(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaVerify
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaVerify);
    End;
  End;

Function NameObj.GetOffFlag: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffFlag := (User^.MKExtra^.OffAttr and uoaFlag) <> 0;
    Else
      GetOffFlag := True;
    End;
  End;

Procedure NameObj.SetOffFlag(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaFlag
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaFlag);
    End;
  End;

Function NameObj.GetOffOwn: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffOwn := (User^.MKExtra^.OffAttr and uoaOwn) <> 0;
    Else
      GetOffOwn := True;
    End;
  End;

Procedure NameObj.SetOffOwn(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaOwn
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaOwn);
    End;
  End;

Function NameObj.GetOffAll: Boolean; {Search all areas your mail}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffAll := (User^.MKExtra^.OffAttr and uoaAllYour) <> 0;
    Else
      GetOffAll := True;
    End;
  End;

Procedure NameObj.SetOffAll(OO: Boolean); {all areas your mail}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaAllYour
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaAllYour);
    End;
  End;

Function NameObj.GetOffZero: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffZero := (User^.MKExtra^.OffAttr and uoaZero) <> 0;
    Else
      GetOffZero := True;
    End;
  End;

Procedure NameObj.SetOffZero(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaZero
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaZero);
    End;
  End;

Function NameObj.GetOffGate: Boolean;
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BbsType of
    1: GetOffGate := (User^.MKExtra^.OffAttr and uoaGateway) <> 0;
    Else
      GetOffGate := False;
    End;
  End;

Procedure NameObj.SetOffGate(OO: Boolean);
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: If OO Then
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr or uoaGateway
       Else
         User^.MKExtra^.OffAttr := User^.MKExtra^.OffAttr and (not uoaGateway);
    End;
  End;


Function NameObj.GetNetStatus: LongInt; {Get net status}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: GetNetStatus := User^.MKExtra^.NetStat;
    Else
      GetNetStatus := 0;
    End;
  End;


Procedure NameObj.SetNetStatus(NS: LongInt); {Set net status}
  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  Case User^.BBSType of
    1: User^.MKExtra^.NetStat := NS;
    End;
  End;


Function NameObj.GetUserOffline(Area: Word): Boolean;
  Var
    ConfIdx: Word;
    ConfMask: Byte;

  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  ConfIdx := ((Area - 1) shr 3) + 1;
  ConfMask := 1;
  ConfMask := ConfMask Shl ((Area - 1) and 7);
  Case User^.BbsType of
    1: If (Area > 0) and (Area < 501) Then
         GetUserOffline := (User^.MKExtra^.Offline[ConfIdx] and
         ConfMask) <> 0
       Else
         GetUserOffline := False;
    Else
      GetUserOffline := False;
    End;
  End;


Procedure NameObj.SetUserOffline(Area: Word; St: Boolean);
  Var
    ConfIdx: Word;
    ConfMask: Byte;

  Begin
  If Not User^.ExtraLoaded Then
    LoadExtra;
  ConfIdx := ((Area - 1) shr 3) + 1;
  ConfMask := 1;
  ConfMask := ConfMask Shl ((Area - 1) and 7);
  Case User^.BbsType of
    1: If (Area > 0) and (Area < 501) Then
         Begin
         If St Then
           User^.MKExtra^.Offline[ConfIdx] :=
           User^.MKExtra^.Offline[ConfIdx] or ConfMask
         Else
           User^.MKExtra^.Offline[ConfIdx] :=
           User^.MKExtra^.Offline[ConfIdx] and (Not ConfMask);
         End;
    End;
  End;


End.
