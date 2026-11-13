Unit MKRCfgMK;
{ Read-Only config object for MK }

{$I MKB.Def}

Interface


Uses MKGlobT, MKFile, MKCfgAbs,
  Dos;

{$I Struct.MK}

Const
  MASize = 50;
  FASize = 50;


Type
  MsgCfgArray = Array[1..MASize] of MsgAreaType;
  FileCfgArray = Array[1..FASize] of FileAreaType;


Type MKRCfgObj = Object(CfgObj)
  MKCfg:    ^BbsCfg;
  MsgLoaded: Word;
  FileLoaded: Word;
  MKMsg: ^MsgCfgArray;
  MKFile: ^FileCfgArray;
  MKEcho:   ^EchoCfgType;
  MKMsgFile: File;
  MKFileFile: File;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure MKLoad; Virtual;{Normally internal to load MK config}
  Function  ValidMsgArea(Area: Word): Word;
  Function  ValidFileArea(Area: Word): Word;
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Function  GetBbsType: Word; Virtual;               {Get type of Bbs}
  Function  GetMsgBaseType(Area: Word): Char; Virtual;
  Function  GetMsgPath(BaseNo: Word): String; Virtual; {Get directory for msg base}
  Function  GetTxtPath(Num: Word): String; Virtual;  {Get path to asc/ans/avt files}
  Function  GetMnuPath(Num: Word): String; Virtual;  {Get path to menu *.mnu files}
  Function  GetNetPath: String; Virtual; {Get netmail path}
  Function  GetTempPath: String; Virtual; {Get temp file path}
  Function  GetLogFileName: String; Virtual; {Get log file path and name}
  Function  GetEditCmdPath: String; Virtual; {Get edit command path}
  Function  GetNodeListPath: String; Virtual; {Get nodelist path}
  Function  GetAttachPath: String; Virtual; {Get file attach path}
  Function  GetSemaphorePath: String; Virtual; {Get Semaphore file path}
  Function  GetBbsPath: String; Virtual; {Get main bbs directory path}
  Function  GetQuoteStr: String; Virtual; {Get quote string}
  Procedure GetAddr(Aka: Word; Var Addr: AddrType); Virtual; {Get Bbs Addr or AKA}
  Function  GetMaxMsgAreas: Word; Virtual; {Get maximum number of msg areas}
  Function  GetMsgName(Area: Word): String; Virtual; {Get message area name}
  Function  GetMsgShortName(Area: Word): String; Virtual; {Get message area short name}
  Function  GetMsgType(Area: Word): MailType; Virtual; {Get type of mail area}
  Function  GetMsgNetwork(Area: Word; Net: Byte): Boolean; Virtual; {Get msg network}
  Function  GetMsgNetStatus(Area: Word): LongInt; Virtual; {Net status setting}
  Function  MsgWriteAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Has write access?}
  Function  MsgReadAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Has read access?}
  Function  MsgSysopAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Has sysop access?}
  Function  MsgDeleteAccess(Sec: SecType): Boolean; Virtual;  {Has access to delete messages}
  Function  MsgUnRecvAccess(Sec: SecType): Boolean; Virtual;  {Has access to unrcv messages}
  Procedure GetMsgReadSecurity(Area: Word; Var Sec: SecType); Virtual; {Read security level}
  Procedure GetMsgWriteSecurity(Area: Word; Var Sec: SecType); Virtual; {Write security level}
  Procedure GetMsgSysopSecurity(Area: Word; Var Sec: SecType); Virtual; {Sysop security level}
  Function  GetMsgDays(Area: Word): Word; Virtual;  {Number of days to keep messages}
  Function  GetMsgRcvdDays(Area: Word): Word; Virtual; {Number of days to keep received msgs}
  Function  GetMsgsKept(Area: Word): Word; Virtual; {Number of msgs to keep in area}
  Function  MsgAllowPriv(Area: Word): Boolean; Virtual; {Area allows priv msgs}
  Function  MsgAllowPubl(Area: Word): Boolean; Virtual; {Area allows publ msgs}
  Function  MsgAllowReal(Area: Word): Boolean; Virtual; {Area allows real names}
  Function  MsgAllowHdl(Area: Word): Boolean; Virtual; {Area allows handles}
  Function  MsgAllowAnon(Area: Word): Boolean; Virtual; {Area allows aliases}
  Function  MsgAddFido(Area: Word): Boolean; Virtual; {Add Fido style tear/origin}
  Function  MsgAllowAnsi(Area: Word): Boolean; Virtual; {Area allows ansi}
  Function  MsgAllowHiBit(Area: Word): Boolean; Virtual; {Area allows hi-bit chars}
  Function  MsgAllowTag(Area: Word): Boolean; Virtual; {Area allows taglines}
  Function  GetMsgReaderTear(Area: Word): Boolean; Virtual; {Get keep reader tear text}
  Function  GetMsgReaderOrig(Area: Word): Boolean; Virtual; {Get keep reader tear origin}
  Function  GetMsgFAttach(Area: Word): Boolean; Virtual; {Get allow file attach}
  Function  GetMsgSelect(Area: Word): String; Virtual; {Get msg select string}
  Function  GetMsgOrigStr(Area: Word): String; Virtual; {Get origin string for msg area}
  Procedure GetMsgAddr(Area: Word; Var MA: AddrType); Virtual; {Get message area address}
  Function  GetMsgAddrStr(Area: Word): String; Virtual; {Get message address string}
  Function  GetMsgAddrNum(Area: Word): Word; Virtual; {Get message aka number}
  Function  GetMsgOrigNum(Area: Word): Word; Virtual; {Get message orig number}
  Function  GetMsgAllowOffline(Area: Word): Boolean; Virtual; {Allow in offline}
  Function  GetMsgForceOffline(Area: Word): Boolean; Virtual; {Force in offline}
  Function  GetMsgAllowCombined(Area: Word): Boolean; Virtual; {Allow in combined read}
  Function  GetMsgDefCombined(Area: Word): Boolean; Virtual; {Default combined area}
  Function  GetDefaultOrigStr(Area: Word): String; Virtual; {Get full origin string w/addr}
    {includes the * Origin and default text and address}
  Function  GetMaxFileAreas: Word; Virtual; {Get maximum number of file areas}
  Function  GetFileAreaName(Area: Word): String; Virtual; {Get file area name}
  Function  GetFileShortName(Area: Word): String; Virtual; {Get short name for area}
  Function  GetFileSelect(Area: Word): String; Virtual; {Get file area select name}
  Function  GetFileAreaPath(Area: Word): String; Virtual; {Get file area path}
  Function  GetFileListPath(Area: Word): String; Virtual; {Get file area path}
  Procedure GetFileViewSecurity(Area: Word; Var Sec: SecType); Virtual; {File Listing security level}
  Procedure GetFileULSecurity(Area: Word; Var Sec: SecType); Virtual; {File UL security level}
  Procedure GetFileDLSecurity(Area: Word; Var Sec: SecType); Virtual; {File Listing security level}
  Procedure GetFilePvtSecurity(Area: Word; Var Sec: SecType); Virtual; {Private files security}
  Function  GetFileNoUl(Area: Word): Boolean; Virtual; {Area disallows ULs}
  Function  GetFileNoNew(Area: Word): Boolean; Virtual; {Exclude area from new files}
  Function  GetFileFree(Area: Word): Boolean; Virtual; {Area contains free files}
  Function  GetFileNoTime(Area: Word): Boolean; Virtual; {Ignore time remaining}
  Function  GetFileNoBaud(Area: Word): Boolean; Virtual; {Ignore min baud limits}
  Function  GetSysopName: String; Virtual; {Get config name of sysop}
  Function  GetSystemColor(Num: Byte): Byte; Virtual; {Get system color attribute}
  Function  GetBbsName: String; Virtual; {Get Bbs system name}
  Function  GetBbsLoc: String; Virtual; {Get Bbs location}
  Function  GetBbsPhone: String; Virtual; {Get Bbs main phone number}
  Function  GetBbsId: String; Virtual; {Get Bbs Id}
  Function  GetDirectWrite: Boolean; Virtual; {Get direct video write status}
  Function  GetSnowCheck: Boolean; Virtual; {Get snow checking status}
  Function  GetMonoMode: Boolean; Virtual; {Get mono screen mode}
  Function  GetForceKillYes: Boolean; Virtual; {Force kill/sent to yes}
  Function  GetForceKillAsk: Boolean; Virtual; {Force kill/sent Ask}
  Function  GetPageStart(DayNo: Byte): Word; Virtual; {Get page start time hi=hr lo=minutes}
  Function  GetPageStop(DayNo: Byte): Word; Virtual; {Get page stop time}
  Function  GetMaxPageTimes: Word; Virtual; {Get maximum number of page attempts}
  Function  GetPageMsgArea: Word; Virtual; {Get msg area to use for page messages}
  Function  GetPageLength: Byte; Virtual; {Get seconds of page length}
  Function  GetDefaultPage: Byte; Virtual; {Get new user page tune}
  Function  GetAskPageReason: Boolean; Virtual; {Ask reason for paging}
  Function  GetMailCheckDetail: Boolean; Virtual; {Show detail during mail scan}
  Function  GetMailCheckTotal: Boolean; Virtual; {Show totals after your mail scan}
  Function  FileViewAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Can view files}
  Function  FileDLAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Can download files}
  Function  FileULAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Can upload files}
  Function  FilePvtAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Private files}
  Function  GetLangName(LNum: Word): String;  Virtual; {Get language name}
  Function  GetLangFile(LNum: Word): String;  Virtual; {Get language file name}
  Function  GetLangQuesPath(LNum: Word): String; Virtual; {Get language q-a path}
  Function  GetAskVoicePhone: Boolean; Virtual; {Ask new user voice phone}
  Function  GetAskDataPhone: Boolean; Virtual; {Ask new user data phone}
  Function  GetNewUserNMCredit: Word; Virtual; {Get new user netmail credit}
  Function  GetAskBirthdate: Boolean; Virtual; {Ask new user birthdate}
  Function  GetAskGender: Boolean; Virtual; {Ask new user gender}
  Function  GetAskAddr: Boolean; Virtual; {Ask new user address}
  Function  GetSevenBitNames: Boolean; Virtual; {Force name to 7 bit chars}
  Function  GetOneWordName: Boolean; Virtual; {Allow one word names}
  Function  GetReAsk: Boolean; Virtual; {Re-ask blank answers}
  Function  GetAskHandle: Boolean; Virtual; {Ask user for handle}
  Procedure GetEchoToAddr(ES: Word; Var Addr: AddrType); Virtual;
    {Get addr of systems to send echomail to}
  Function  GetEchoToPwd(ES: Word): String; Virtual; {Get echo to system password}
  Function  GetEchoToPacker(ES: Word): Byte; Virtual; {Get echo to archiver type}
  Function  GetEchoToNetwork(ES: Word; Nt: Word): Boolean; Virtual; {Get echo network status}
  Function  GetEchoToMailType(ES: Word): Byte; Virtual; {Get echo mail type}
  Function  GetEchoToArea(ES: Word; Area: Word): Boolean; Virtual; {Get echo to area on}
  Function  GetEchoAreaPassThru(Area: Word): Boolean; Virtual; {Get area is pass-thru}
  Function  GetEchoAreaImportPath(Area: Word): Boolean; Virtual; {Get import path}
  Function  GetEchoAreaHidePath(Area: Word): Boolean; Virtual; {Get hide import path}
  Function  GetEchoAreaImportSeen(Area: Word): Boolean; Virtual; {Get import seen-by}
  Function  GetEchoAreaHideSeen(Area: Word): Boolean; Virtual; {Get hide imported seen}
  Function  GetEchoToHub(Area: Word): Byte; Virtual; {Get hub number}
  Function  GetEchoAreaTag(Area: Word): String; Virtual; {Get area tag name}
  Function  GetEchoMaxPkt: LongInt; Virtual; {Get maximum pkt size}
  Function  GetEchoInPath: String; Virtual; {Get inbound files path}
  Function  GetEchoOutPath: String; Virtual; {Get outbound files path}
  Function  GetPwdTries: Byte; Virtual; {Get max password attempts}
  Function  GetPwdExpire: Word; Virtual; {Get password expiration days}
  Function  GetBDCheck: Byte; Virtual; {Get calls between birthdate confirms}
  Function  GetPhoneCheck: Byte; Virtual; {Get calls between phone num confirms}
  Function  GetMinPwd: Byte; Virtual; {Get min password length}
  Function  GetMinPhone: Byte; Virtual; {Get min phone num length}
  Function  GetStrictPwd: Boolean; Virtual; {Get strict password checking}
  Function  GetRemoteSysop: Boolean; Virtual; {Get allow remote sysop}
  Function  GetFastLocal: Boolean; Virtual; {Get fast local log on}
  Procedure GetNewUserSec(Var Sec: SecType); Virtual; {Get new user security}
  Procedure GetAttachSec(Var Sec: SecType); Virtual; {Get file attach security}
  Procedure GetRequestSec(Var Sec: SecType); Virtual; {Get file request security}
  Procedure GetCrashNmSec(Var Sec: SecType); Virtual; {Get crash netmail security}
  Procedure GetForceCrashNmSec(Var Sec: SecType); Virtual; {Get force crash netmail security}
  Procedure GetDeleteSec(Var Sec: SecType); Virtual; {Get msg delete security}
  Procedure GetUnRcvSec(Var Sec: SecType); Virtual; {Get msg unreceive security}
  Function  GetModemResp(MR: Byte): String; Virtual; {Get modem response string}
  Function  GetErrorLevel(MR: Byte): Byte; Virtual; {Get errorlevel}
  {1=local 2=300 3=1200 4=2400 5=4800 6=7200 7=9600 8=12000
   9=14400 10=19200 11=38400}
  Function  GetDLStart: Word; Virtual; {Get DL Start time}
  Function  GetDLStop: Word; Virtual; {Get DL Stop time}
  Function  GetLoBaudStart: Word; Virtual; {Get Low Baud DL Start time}
  Function  GetLoBaudStop: Word; Virtual; {Get Low Baud DL Stop time}
  Function  GetMinXferBaud: Word; Virtual; {Get min transfer baud rate}
  Function  GetULCredit: Integer; Virtual; {Get ul credit}
  Function  GetMinDesc: Byte; Virtual; {Get min descr length}
  Function  GetMaxDesc: Byte; Virtual; {Get max descr length}
  Function  GetMinFree: LongInt; Virtual; {Get min free ul space}
  Function  GetAskNewFiles: Boolean; Virtual; {Get ask new file search}
  Function  GetForceNewFiles: Boolean; Virtual; {Get force new file search}
  Function  GetOrigStr(OrigNum: Word): String; Virtual; {Get origin string}
  Function  GetMaxEvents: Word; Virtual; {Get maximum number of events}
  Function  GetEventStatus(EN: Word): Byte; Virtual; {Get event status}
  Function  GetEventTime(EN: Word): Word; Virtual; {Get event time Hi=HH Lo=MM}
  Function  GetEventEL(EN: Word): Byte; Virtual; {Get event errorlevel}
  Function  GetEventDays(EN: Word): Byte; Virtual; {Get event days}
  Function  GetEventOnDay(EN: Word; OD: Byte): Boolean; Virtual; {Is event active on day}
  Function  GetEventForced(EN: Word): Byte; Virtual; {Get event forced}
  Function  GetDoorData(DN: Word): String; Virtual; {Get door data line}
  Procedure GetDoorSec(DN: Word; Var Sec: SecType); Virtual; {Get door security}
  Function  DoorAccess(DN: Word; Sec: SecType): Boolean; Virtual; {Has door access}
  Function  GetProtNormAvail(PN: Word): Boolean; Virtual; {Is protocol avail norm files}
  Function  GetProtSpecAvail(PN: Word): Boolean; Virtual; {Is protocol avail special files}
  Function  GetProtChar(PN: Word): Char; Virtual; {Get protocol character}
  Function  GetProtName(PN: Word): String; Virtual; {Get protocol name}
  Function  GetPackAvail(PN: Word): Boolean; Virtual; {Is packer avail}
  Function  GetPackChar(PN: Word): Char; Virtual; {Get packer character}
  Function  GetPackName(PN: Word): String; Virtual; {Get packer name}
  Function  GetPackCmdLine(PN: Word): String; Virtual; {Get packer cmd line}
  Function  GetUnPackCmdLine(PN: Word): String; Virtual; {Get packer cmd line}
  Function  GetLogLevel: Byte; Virtual; {Get level of logging}
  Function  GetLogStyle: Byte; Virtual; {Get style of log file}
  Function  GetDefaultPort: Word; Virtual; {Get default comm port}
  Function  GetMsgPathNum(Area: Word): Word; Virtual; {Get message path number}
  Function  GetMsgAreaId(Area: Word): String; Virtual; {Get message area id string}
  Function  GetNodeIdxName: String; Virtual; {Get nodelist index name}
  Function  GetNodeIncName: String; Virtual; {Get nodelist include name}
  Function  GetMsgFileId(Area: Word): String; Virtual; {Get msg filename id}
  Function  GetPrnName: String; Virtual; {Get printer name}
  Function  GetOffTypeAvail(OT: Word): Boolean; Virtual; {Offline Pkt Type avail}
  Function  GetOffAllowNew: Boolean; Virtual; {Get offline allow newfiles list}
  Function  GetOffForceNew: Boolean; Virtual; {Get Force new files list}
  Function  GetOffAllowScrn: Boolean; Virtual; {Get offline allow screens}
  Function  GetOffForceScrn: Boolean; Virtual; {Get Force screens}
  Function  GetOffAllowBull: Boolean; Virtual; {Get offline allow bulletins}
  Function  GetOffForceBull: Boolean; Virtual; {Get Force Bulletins}
  Function  GetOffAllowFreq: Boolean; Virtual; {Get offline allow file req}
  Function  GetOffMax: Word; Virtual; {Get offline max msgs per pkt}
  Function  GetOffConfMax: Word; Virtual; {Get max msgs per area}
  Function  GetOffCompRate: Word; Virtual; {Get estimate compress %}
  Function  GetOffSafetyMin: Word; Virtual; {Get offline safety minutes}
  Function  GetOffScrns(SN: Word): String; Virtual; {Get offline screen names}
  Function  GetOffBulls(BN: Word): String; Virtual; {Get offline bulletins}
  End;

Type MKRCfgObjPtr = ^MKRCfgObj;


Implementation


Uses MKString;

Function MKRCfgObj.GetMsgPath(BaseNo: Word): String;
  Begin
  If ((BaseNo > 0) and (BaseNo < 11)) Then
    GetMsgPath := MKCfg^.MsgPath[BaseNo]
  Else
    GetMsgPath := '';
  End;


Function MKRCfgObj.GetTxtPath(Num:Word): String; {Get path to asc/ans/avt files}
  Begin
  GetTxtPath := MKCfg^.TxtPath[Num];
  End;


Function MKRCfgObj.GetMnuPath(Num: Word): String; {Get path to menu *.mnu files}
  Begin
  GetMnuPath := MKCfg^.MenuPath[Num];
  End;


Function MKRCfgObj.GetNetPath: String;
  Begin
  GetNetPath := MKCfg^.NetMailPath;
  End;


Function MKRCfgObj.GetTempPath: String;
  Begin
  GetTempPath := MKCfg^.TempPath;
  End;


Function MKRCfgObj.GetLogFileName: String;
  Begin
  GetLogFileName := MKCfg^.LogFileName;
  End;



Function MKRCfgObj.GetEditCmdPath: String;
  Begin
  GetEditCmdPath := MKCfg^.EditCmdPath;
  End;



Function MKRCfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := MKCfg^.NodeListPath;
  End;



Function MKRCfgObj.GetAttachPath: String;
  Begin
  GetAttachPath := MKCfg^.AttachPath;
  End;



Function MKRCfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  GetSemaphorePath := MKCfg^.SemaphorePath;
  End;



Function MKRCfgObj.GetBbsType: Word;
  Begin
  GetBbsType := CfgInfo^.BbsType;
  End;



Function MKRCfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := CfgInfo^.BbsPath;
  End;



Procedure MKRCfgObj.MKLoad;
  Begin
  New(MKCfg);
  New(MKMsg);
  New(MKFile);
  New(MKEcho);
  Error := LoadFile(FindBbsFile('Config.Mk') + 'Config.Mk', MkCfg^, SizeOf(MkCfg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Messages.Mk') + 'Messages.Mk', MKMsg^, SizeOf(MKMsg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Files.Mk') + 'Files.Mk', MKFile^, SizeOf(MkFile^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('EchoCfg.Mk') + 'EchoCfg.Mk', MKEcho^, SizeOf(MKEcho^));
  Assign(MKMsgFile, ResolveCase(FindBbsFile('Messages.MK') + 'Messages.MK'));
  Assign(MKFileFile, ResolveCase(FindBbsFile('Files.MK') + 'Files.MK'));
  FileMode := fmReadOnly + fmDenyNone;
  MsgLoaded := 1;
  FileLoaded := 1;
  Reset(MKMsgFile, 1);
  Reset(MKFileFile, 1);
  If IoResult <> 0 Then
    Error := 10;
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(MkCfg);
    Dispose(MkMsg);
    Dispose(MkFile);
    Dispose(MKEcho);
    End;
  End;


Procedure MKRCfgObj.Allocate;
  Begin
  If Not CfgInfo^.Loaded Then
    Begin
    New(MkCfg);
    New(MKMsg);
    New(MKFile);
    New(MKEcho);
    FillChar(MKCfg^, SizeOf(MKCfg^), 0);
    FillChar(MKMsg^, SizeOf(MKMsg^), 0);
    FillChar(MKFile^, SizeOf(MKFile^), 0);
    FillChar(MKEcho^, SizeOf(MKEcho^), 0);
    CfgInfo^.BbsPath := GetEnv('MK');
    AddBackSlash(CfgInfo^.BbsPath);
    CfgInfo^.Loaded := True;
    End;
  End;


Procedure MKRCfgObj.Unload;
  Begin
  If CfgInfo^.Loaded Then
    Begin
    Dispose(MkCfg);
    Dispose(MKMsg);
    Dispose(MKFile);
    Dispose(MKEcho);
    Close(MKMsgFile);
    Close(MKFileFile);
    If IoResult <> 0 Then;
    CfgInfo^.Loaded := False;
    End;
  End;


Procedure MKRCfgObj.Load;
  Var
    CPath: String;
    i: Word;

  Begin
  CPath := GetCurrentPath;
  CfgInfo^.BbsPath := GetEnv('MK');
  AddBackSlash(CfgInfo^.BbsPath);
  MKLoad;
  If CfgInfo^.BbsPath = '' Then
    Error := 2000;
  If Error = 0 Then
    Begin
    ChDir(StripTrail(CfgInfo^.BbsPath, DirectorySeparator));
    CfgInfo^.BbsPath := WithBackSlash(FExpand(CfgInfo^.BbsPath));
    MKCfg^.TempPath := WithBackSlash(FExpand(MKCfg^.TempPath));
    For i := 1 to 10 Do
      Begin
      MKCfg^.TxtPath[i] := WithBackSlash(FExpand(MKCfg^.TxtPath[i]));
      MKCfg^.MenuPath[i] := WithBackSlash(FExpand(MKCfg^.MenuPath[i]));
      End;
    For i := 1 to 4 Do
      MKCfg^.MsgPath[i] := WithBackSlash(FExpand(MKCfg^.MsgPath[i]));
    MKCfg^.NetMailPath := WithBackSlash(FExpand(MKCfg^.NetMailPath));
    MKCfg^.NodeListPath := WithBackSlash(FExpand(MKCfg^.NodeListPath));
    MKCfg^.AttachPath := WithBackSlash(FExpand(MKCfg^.AttachPath));
    ChDir(StripTrail(CPath, DirectorySeparator));
    End;
  End;


Function MKRCfgObj.GetQuoteStr: String;
  Begin
  GetQuoteStr := MKCfg^.QuoteStr;
  End;



Function MKRCfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  GetMaxMsgAreas := 500;
  End;


Function MKRCfgObj.ValidMsgArea(Area: Word): Word;
  Var
    FP: LongInt;
    NumRead: Word;

  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If ((Area < MsgLoaded) or (Area >= (MsgLoaded + MASize))) Then
      Begin
      If Area > 10 Then
        MsgLoaded := Area - 10
      Else
        MsgLoaded := 1;
      FP := MsgLoaded - 1;
      FP := FP * SizeOf(MsgAreaType);
      Seek(MKMsgFile, FP);
      BlockRead(MKMsgFile, MKMsg^, SizeOf(MKMsg^), NumRead);
      If IoResult <> 0 Then;
      End;
    ValidMsgArea := Area  + 1 - MsgLoaded;
    End
  Else
    ValidMsgArea := 0;
  End;


Function MKRCfgObj.ValidFileArea(Area: Word): Word;
  Var
    FP: LongInt;
    NumRead: Word;

  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    If ((Area < FileLoaded) or (Area >= (FileLoaded + FASize))) Then
      Begin
      If Area > 10 Then
        FileLoaded := Area - 10
      Else
        FileLoaded := 1;
      FP := FileLoaded - 1;
      FP := FP * SizeOf(FileAreaType);
      Seek(MKFileFile, FP);
      BlockRead(MKFileFile, MKFile^, SizeOf(MKFile^), NumRead);
      If IoResult <> 0 Then;
      End;
    ValidFileArea := Area  + 1 - FileLoaded;
    End
  Else
    ValidFileArea := 0;
  End;


Function MKRCfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgName := MKMsg^[MA].Name
  Else
    GetMsgName := '';
  End;


Function MKRCfgObj.GetMsgOrigStr(Area: Word): String;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgOrigStr := MKCfg^.Origin[MKMsg^[MA].Origin]
  Else
    GetMsgOrigStr := '';
  End;


Function MKRCfgObj.GetOrigStr(OrigNum: Word): String;
  Begin
  If ((OrigNum > 0) and (OrigNum < 21)) Then
    GetOrigStr := MKCfg^.Origin[OrigNum]
  Else
    GetOrigStr := '';
  End;


Procedure MKRCfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
  Begin
  If ((Aka > 0) and (Aka < 11)) Then
    Addr := MKCfg^.Addr[Aka]
  Else
    Begin
    Addr.Zone := 0;
    Addr.Net := 0;
    Addr.Node := 0;
    Addr.Point := 0;
    End;
  End;



Procedure MKRCfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Var
    MAI: Word;

  Begin
  MAI := ValidMsgArea(Area);
  If MAI > 0 Then
    MA := MKCfg^.Addr[MKMsg^[MAI].Addr]
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function MKRCfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Var
    Addr: AddrType;

  Begin
  GetMsgAddr(Area, Addr);
  GetMsgAddrStr := AddrStr(Addr);
  End;


Function MKRCfgObj.GetMsgAddrNum(Area: Word): Word;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgAddrNum := MKMsg^[MA].Addr
  Else
    GetMsgAddrNum := 1;
  End;



Function MKRCfgObj.GetMsgOrigNum(Area: Word): Word;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgOrigNum := MKMsg^[MA].Origin
  Else
    GetMsgOrigNum := 1;
  End;


Function MKRCfgObj.GetMsgAllowOffline(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgAllowOffline := (MKMsg^[MA].Permit and mpOffline) <> 0
  Else
    GetMsgAllowOffline := True
  End;



Function MKRCfgObj.GetMsgForceOffline(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgForceOffline := (MKMsg^[MA].Permit and mpForce) <> 0
  Else
    GetMsgForceOffline := False
  End;



Function MKRCfgObj.GetMsgAllowCombined(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgAllowCombined := (MKMsg^[MA].Permit and mpCombine) <> 0
  Else
    GetMsgAllowCombined := False;
  End;


Function MKRCfgObj.GetMsgDefCombined(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgDefCombined := (MKMsg^[MA].Permit and mpDefCombine) <> 0
  Else
    GetMsgDefCombined := False;
  End;


Function MKRCfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;


Function MKRCfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    If Length(MKMsg^[MA].ShortName) > 0 Then
      GetMsgShortName := MkMsg^[MA].ShortName
    Else
      GetMsgShortName := Copy(MKMsg^[MA].Name,1,12)
  Else
    GetMsgShortName := '';
  End;


Function MKRCfgObj.GetMsgNetwork(Area: Word; Net: Byte): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If ((MA > 0) and (Net > 0) and (Net < 33)) Then
    GetMsgNetwork := (MKMsg^[MA].NetStat and (LongInt(1) shl (Net - 1))) <> 0
  Else
    GetMsgNetwork := False;
  End;


Function MKRCfgObj.GetMsgNetStatus(Area: Word): LongInt;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If (MA > 0) Then
    GetMsgNetStatus := MKMsg^[MA].NetStat
  Else
    GetMsgNetStatus := 0;
  End;


Function MKRCfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Case MKMsg^[MA].MsgType Of
      mtNormal: GetMsgType := Normal;
      mtNet: GetMsgType := NetMail;
      mtEcho: GetMsgType := EchoMail;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Function MKRCfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgWriteSecurity(Area, AreaSec);
  MsgWriteAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgWriteAccess := False;
  End;


Function MKRCfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgReadSecurity(Area, AreaSec);
  MsgReadAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgReadAccess := False;
  End;


Function MKRCfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgSysopSecurity(Area, AreaSec);
  MsgSysopAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgSysopAccess := False;
  End;


Function MKRCfgObj.MsgDeleteAccess(Sec: SecType): Boolean;
  Begin
  MsgDeleteAccess := Access(Sec, MKCfg^.MsgDelSec);
  End;


Function MKRCfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;
  Begin
  MsgUnRecvAccess := Access(Sec, MKCfg^.MsgNoRcv);
  End;


Function MKRCfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgDays := MKMsg^[MA].DaysKept
  Else
    GetMsgDays := 7;
  End;


Function MKRCfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgRcvdDays := MKMsg^[MA].RcvdDays
  Else
    GetMsgRcvdDays := 2;
  End;


Function MKRCfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgsKept := MKMsg^[MA].MsgsKept
  Else
    GetMsgsKept := 200;
  End;


Function MKRCfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  GetSysopName := MKCfg^.SysopName;
  End;


Function MKRCfgObj.GetSystemColor(Num: Byte): Byte; {Get system color attribute}
  Begin
  If ((Num < 1) or (Num > 5)) Then
    Num := 1;
  GetSystemColor := MKCfg^.Color[Num];
  End;


Function MKRCfgObj.GetBbsName: String;
  Begin
  GetBbsName := MKCfg^.SystemName;
  End;


Function MKRCfgObj.GetBbsLoc: String;
  Begin
  GetBbsLoc := MKCfg^.BbsLocation;
  End;


Function MKRCfgObj.GetBbsPhone: String;
  Begin
  GetBbsPhone := MKCfg^.BbsPhone;
  End;


Function MKRCfgObj.GetBbsId: String;
  Begin
  GetBbsId := MKCfg^.BoardId;
  End;


Function MKRCfgObj.GetDirectWrite: Boolean;
  Begin
  GetDirectWrite := ((MKCfg^.COption And coDirect) <> 0);
  End;


Function MKRCfgObj.GetSnowCheck: Boolean;
  Begin
  GetSnowCheck := ((MKCfg^.COption and coSnowCheck) <> 0);
  End;


Function MKRCfgObj.GetMonoMode: Boolean;
  Begin
  GetMonoMode := ((MKCfg^.COption and coMono) <> 0);
  End;


Function MKRCfgObj.GetForceKillYes: Boolean;
  Begin
  GetForceKillYes := ((MKCfg^.COption and coKillSentYes) <> 0);
  End;


Function MKRCfgObj.GetForceKillAsk: Boolean;
  Begin
  GetForceKillAsk := ((MKCfg^.COption and coKillSentAsk) <> 0);
  End;


Function MKRCfgObj.GetPageStart(DayNo: Byte): Word;
  Begin
  GetPageStart := MKCfg^.PageStart[DayNo];
  End;


Function MKRCfgObj.GetPageStop(DayNo: Byte): Word;
  Begin
  GetPageStop := MKCfg^.PageStop[DayNo];
  End;


Function MKRCfgObj.GetMaxPageTimes: Word;
  Begin
  GetMaxPageTimes := MKCfg^.MaxPages;
  End;


Function MKRCfgObj.GetPageMsgArea: Word;
  Begin
  GetPageMsgArea:= MKCfg^.PageMsgArea;
  End;


Function MKRCfgObj.GetPageLength: Byte;
  Begin
  GetPageLength := MKCfg^.PageLength;
  End;


Function MKRCfgObj.GetDefaultPage: Byte;
  Begin
  GetDefaultPage := MKCfg^.DefPage;
  End;


Function MKRCfgObj.GetAskPageReason: Boolean;
  Begin
  GetAskPageReason := (MKCfg^.COption2 And csPageReason) <> 0;
  End;


Function MKRCfgObj.GetMailCheckDetail: Boolean;
  Begin
  GetMailCheckDetail := (MKCfg^.COption2 And csMailCheckDetail) <> 0;
  End;


Function MKRCfgObj.GetMailCheckTotal: Boolean;
  Begin
  GetMailCheckTotal := (MKCfg^.COption2 And csMailCheckTotal) <> 0;
  End;


Procedure MKRCfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := MKMsg^[MA].ReadSec.Level;
    Sec.Flags := MKMsg^[MA].ReadSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKRCfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := MKMsg^[MA].WriteSec.Level;
    Sec.Flags := MKMsg^[MA].WriteSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKRCfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := MKMsg^[MA].SysopSec.Level;
    Sec.Flags := MKMsg^[MA].SysopSec.Flags;
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function MKRCfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowPriv := (MKMsg^[MA].Permit and mpPriv) <> 0
  Else
    MsgAllowPriv := True;
  End;



Function MKRCfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowPubl := (MKMsg^[MA].Permit and mpPubl) <> 0
  Else
    MsgAllowPubl := True;
  End;


Function MKRCfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowReal := (MKMsg^[MA].Permit and mpRealName) <> 0
  Else
    MsgAllowReal := True;
  End;


Function MKRCfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowHdl := (MKMsg^[MA].Permit and mpAlias) <> 0
  Else
    MsgAllowHdl := False;
  End;


Function MKRCfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows anonymous}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowAnon := (MKMsg^[MA].Permit and mpAnon) <> 0
  Else
    MsgAllowAnon := False;
  End;


Function MKRCfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAddFido := (MKMsg^[MA].Permit and mpFido) <> 0
  Else
    MsgAddFido := True;
  End;



Function MKRCfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowAnsi := (MKMsg^[MA].Permit and mpAnsi) <> 0
  Else
    MsgAllowAnsi := False;
  End;


Function MKRCfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowHiBit := (MKMsg^[MA].Permit and mpHiBit) <> 0
  Else
    MsgAllowHiBit := False;
  End;


Function MKRCfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowTag := (MKMsg^[MA].Permit and mpTagLines) <> 0
  Else
    MsgAllowTag := False;
  End;


Function MKRCfgObj.GetMsgReaderTear(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgReaderTear := (MKMsg^[MA].Permit and mpTear) <> 0
  Else
    GetMsgReaderTear := False;
  End;


Function MKRCfgObj.GetMsgReaderOrig(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgReaderOrig := (MKMsg^[MA].Permit and mpOrg) <> 0
  Else
    GetMsgReaderOrig := False;
  End;


Function MKRCfgObj.GetMsgFAttach(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgFAttach := (MKMsg^[MA].Permit and mpFileAttach) <> 0
  Else
    GetMsgFAttach := False;
  End;


Function MKRCfgObj.GetMsgSelect(Area: Word): String;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgSelect := MKMsg^[MA].Select
  Else
    GetMsgSelect := '';
  End;


Function MKRCfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  GetMaxFileAreas := 300;
  End;


Function MKRCfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileAreaName := MKFile^[FA].Name
  Else
    GetFileAreaName := '';
  End;


Function MKRCfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    If Length(MKFile^[FA].ShortName) > 0 Then
      GetFileShortName := MKFile^[FA].ShortName
    Else
      GetFileShortName := Copy(GetFileAreaName(Area),1 , 12);
    End
  Else
    GetFileShortName := '';
  End;


Function MKRCfgObj.GetFileSelect(Area: Word): String;
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileSelect := MKFile^[FA].Select
  Else
    GetFileSelect := '';
  End;


Function MKRCfgObj.GetFileAreaPath(Area: Word): String; {Get file area path}
  Var
    FA: Word;
    TmpStr: String;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    TmpStr := MKFile^[FA].FilePath;
    AddBackSlash(TmpStr);
    GetFileAreaPath := TmpStr;
    End
  Else
    GetFileAreaPath := '';
  End;


Function MKRCfgObj.GetFileListPath(Area: Word): String; {Get file area path}
  Var
    FA: Word;
    TmpStr: String;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    TmpStr := MKFile^[FA].FilePath;
    AddBackSlash(TmpStr);
    TmpStr := TmpStr + 'FILES.BBS';
    GetFileListPath := TmpStr;
    End
  Else
    GetFileListPath := '';
  End;


Procedure MKRCfgObj.GetFileViewSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := MKFile^[FA].ViewSec.Level;
    Sec.Flags := MKFile^[FA].ViewSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKRCfgObj.GetFileDLSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := MKFile^[FA].DLSec.Level;
    Sec.Flags := MKFile^[FA].DLSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKRCfgObj.GetFileULSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := MKFile^[FA].ULSec.Level;
    Sec.Flags := MKFile^[FA].ULSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKRCfgObj.GetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private files security}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := MKFile^[FA].PFileSec.Level;
    Sec.Flags := MKFile^[FA].PFileSec.Flags;
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function MKRCfgObj.GetFileNoUl(Area: Word): Boolean; {Area disallows ULs}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileNoUl := (MKFile^[FA].Attr And faNoUl) <> 0
  Else
    GetFileNoUl := True;
  End;


Function MKRCfgObj.GetFileNoNew(Area: Word): Boolean; {Exclude area from new files}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileNoNew := (MKFile^[FA].Attr And faNoNew) <> 0
  Else
    GetFileNoNew := True;
  End;


Function MKRCfgObj.GetFileFree(Area: Word): Boolean; {Area contains free files}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileFree := (MKFile^[FA].Attr And faFree) <> 0
  Else
    GetFileFree := False;
  End;


Function MKRCfgObj.GetFileNoTime(Area: Word): Boolean; {Ignore time remaining}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileNoTime := (MKFile^[FA].Attr And faNoTime) <> 0
  Else
    GetFileNoTime := False;
  End;


Function MKRCfgObj.GetFileNoBaud(Area: Word): Boolean; {Ignore min baud limits}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileNoBaud := (MKFile^[FA].Attr And faNoBaud) <> 0
  Else
    GetFileNoBaud := False;
  End;


Function MKRCfgObj.FileViewAccess(Area: Word; Sec: SecType): Boolean; {Can view files}
  Var
    AreaSec: SecType;

  Begin
  GetFileViewSecurity(Area, AreaSec);
  FileViewAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileViewAccess := False;
  If (Length(GetFileAreaName(Area)) = 0) Then
    FileViewAccess := False;
  End;


Function MKRCfgObj.FileDLAccess(Area: Word; Sec: SecType): Boolean; {Can download files}
  Var
    AreaSec: SecType;

  Begin
  GetFileDLSecurity(Area, AreaSec);
  FileDLAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileDLAccess := False;
  End;


Function MKRCfgObj.FileULAccess(Area: Word; Sec: SecType): Boolean; {Can upload files}
  Var
    AreaSec: SecType;

  Begin
  GetFileULSecurity(Area, AreaSec);
  FileULAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileULAccess := False;
  End;


Function MKRCfgObj.FilePvtAccess(Area: Word; Sec: SecType): Boolean; {Private files}
  Var
    AreaSec: SecType;

  Begin
  GetFilePvtSecurity(Area, AreaSec);
  FilePvtAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FilePvtAccess := False;
  End;


Function MKRCfgObj.GetLangName(LNum: Word): String;
  Begin
  If ((LNum > 0) and (LNum < 11)) Then
    GetLangName := MKCfg^.LangName[LNum]
  Else
    GetLangName := 'PROMPTS';
  End;


Function MKRCfgObj.GetLangFile(LNum: Word): String;
  Begin
  If ((LNum > 0) and (LNum < 11)) Then
    GetLangFile := MKCfg^.LangFile[LNum]
  Else
    GetLangFile := 'PROMPTS';
  End;


Function MKRCfgObj.GetLangQuesPath(LNum: Word): String;
  Begin
  If ((LNum > 0) and (LNum < 11)) Then
    GetLangQuesPath := MKCfg^.QuesPath[LNum]
  Else
    GetLangQuesPath := GetBbsPath;
  End;


Function MKRCfgObj.GetAskVoicePhone: Boolean;
  Begin
  GetAskVoicePhone := (MKCfg^.NewOpt and noAskHome) <> 0;
  End;


Function MKRCfgObj.GetAskDataPhone: Boolean;
  Begin
  GetAskDataPhone := (MKCfg^.NewOpt and noAskData) <> 0;
  End;


Function MKRCfgObj.GetNewUserNMCredit: Word;
  Begin
  GetNewUserNMCredit := MKCfg^.NewCredit;
  End;


Function MKRCfgObj.GetAskBirthdate: Boolean;
  Begin
  GetAskBirthdate := (MKCfg^.NewOpt and noAskBirth) <> 0;
  End;


Function MKRCfgObj.GetAskGender: Boolean;
  Begin
  GetAskGender := (MKCfg^.NewOpt and noAskGender) <> 0;
  End;


Function MKRCfgObj.GetAskAddr: Boolean;
  Begin
  GetAskAddr := (MKCfg^.NewOpt and noAskAddr) <> 0;
  End;


Function MKRCfgObj.GetSevenBitNames: Boolean;
  Begin
  GetSevenBitNames := (MKCfg^.NewOpt and no7BitName) <> 0;
  End;


Function MKRCfgObj.GetOneWordName: Boolean;
  Begin
  GetOneWordName := (MKCfg^.NewOpt and noOneWord) <> 0;
  End;


Function MKRCfgObj.GetReAsk: Boolean;
  Begin
  GetReAsk := (MKCfg^.NewOpt and noReAsk) <> 0;
  End;


Function MKRCfgObj.GetAskHandle: Boolean; {Ask user for handle}
  Begin
  GetAskHandle := (MKCfg^.NewOpt and noAskHandle) <> 0;
  End;


Procedure MKRCfgObj.GetEchoToAddr(ES: Word; Var Addr: AddrType);
  Begin
  If ((ES > 0) and (ES < 33)) Then
    Addr := MKEcho^.EchoSys[ES].Addr
  Else
    Begin
    Addr.Zone := 0;
    Addr.Net := 0;
    Addr.Node := 0;
    Addr.Point := 0;
    End;
  End;


Function MKRCfgObj.GetEchoToPwd(ES: Word): String;
  Begin
  If ((ES > 0) and (ES < 33)) Then
    GetEchoToPwd := MKEcho^.EchoSys[ES].Pwd
  Else
    GetEchoToPwd := '';
  End;


Function MKRCfgObj.GetEchoToPacker(ES: Word): Byte;
  Begin
  If ((ES > 0) and (ES < 33)) Then
    GetEchoToPacker := MKEcho^.EchoSys[ES].Archiver
  Else
    GetEchoToPacker := 1;
  End;


Function MKRCfgObj.GetEchoToNetwork(ES: Word; Nt: Word): Boolean;
  Var
    Mask: LongInt;

  Begin
  If ((ES > 0) and (ES < 33) And (NT > 0) And (Nt < 33)) Then
    Begin
    Mask := 1;
    Mask := Mask shl (Nt - 1);
    GetEchoToNetwork := (MKEcho^.EchoSys[ES].Networks and Mask) <> 0;
    End
  Else
    GetEchoToNetwork := False;
  End;


Function MKRCfgObj.GetEchoToMailType(ES: Word): Byte;
  Begin
  If ((ES > 0) and (ES < 33)) Then
    GetEchoToMailType := MKEcho^.EchoSys[ES].Attr and 7
  Else
    GetEchoToMailType := 2;
  End;


Function MKRCfgObj.GetEchoToArea(ES: Word; Area: Word): Boolean;
  Begin
  If ((ES > 0) And (ES < 33) And (Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoToArea := (MKEcho^.EchoArea[Area].EchoTo and (LongInt(1) shl (ES - 1))) <> 0
  Else
    GetEchoToArea := False;
  End;


Function MKRCfgObj.GetEchoAreaPassThru(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaPassThru := (MKEcho^.EchoArea[Area].Attr and eaPassThru) <> 0
  Else
    GetEchoAreaPassThru := False;
  End;


Function MKRCfgObj.GetEchoAreaImportPath(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaImportPath := (MKEcho^.EchoArea[Area].Attr and eaKeepPath) <> 0
  Else
    GetEchoAreaImportPath := True;
  End;


Function MKRCfgObj.GetEchoAreaHidePath(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaHidePath := (MKEcho^.EchoArea[Area].Attr and eaHidePath) <> 0
  Else
    GetEchoAreaHidePath := True;
  End;


Function MKRCfgObj.GetEchoAreaImportSeen(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaImportSeen := (MKEcho^.EchoArea[Area].Attr and eaKeepSeen) <> 0
  Else
    GetEchoAreaImportSeen := False;
  End;


Function MKRCfgObj.GetEchoAreaHideSeen(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaHideSeen := (MKEcho^.EchoArea[Area].Attr and eaHideSeen) <> 0
  Else
    GetEchoAreaHideSeen := True;
  End;


Function MKRCfgObj.GetEchoToHub(Area: Word): Byte;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoToHub := MKEcho^.EchoArea[Area].Hub
  Else
    GetEchoToHub := 1;
  End;


Function MKRCfgObj.GetEchoMaxPkt: LongInt;
  Begin
  GetEchoMaxPkt := MKEcho^.MaxPktSize;
  End;


Function MKRCfgObj.GetEchoInPath: String;
  Begin
  GetEchoInPath := MKEcho^.InBoundFiles;
  End;


Function MKRCfgObj.GetEchoOutPath: String;
  Begin
  GetEchoOutPath := MKEcho^.OutBoundFiles;
  End;


Function MKRCfgObj.GetEchoAreaTag(Area: Word): String;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaTag := MKEcho^.EchoArea[Area].AreaTag
  Else
    GetEchoAreaTag := '';
  End;


Function MKRCfgObj.GetPwdTries: Byte;
  Begin
  GetPwdTries := MKCfg^.PassTries;
  End;


Function MKRCfgObj.GetPwdExpire: Word;
  Begin
  GetPwdExpire := MKCfg^.PwdExpire;
  End;


Function MKRCfgObj.GetBDCheck: Byte;
  Begin
  GetBDCheck := MKCfg^.CheckBD;
  End;


Function MKRCfgObj.GetPhoneCheck: Byte;
  Begin
  GetPhoneCheck := MKCfg^.CheckPhone;
  End;


Function MKRCfgObj.GetMinPwd: Byte;
  Begin
  GetMinPwd := MKCfg^.MinPwd;
  End;


Function MKRCfgObj.GetMinPhone: Byte;
  Begin
  GetMinPhone := MKCfg^.MinPhone;
  End;


Function MKRCfgObj.GetStrictPwd: Boolean;
  Begin
  GetStrictPwd := (MKCfg^.COption and coStrictPwd) <> 0;
  End;


Function MKRCfgObj.GetRemoteSysop: Boolean;
  Begin
  GetRemoteSysop := (MKCfg^.COption and coAllowSysRemote) <> 0;
  End;


Function MKRCfgObj.GetFastLocal: Boolean;
  Begin
  GetFastLocal := (MKCfg^.COption and coFastLogIn) <> 0;
  End;


Procedure MKRCfgObj.GetNewUserSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.NewSec;
  End;


Procedure MKRCfgObj.GetAttachSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.FAttachSec;
  End;


Procedure MKRCfgObj.GetRequestSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.FReqSec;
  End;


Procedure MKRCfgObj.GetCrashNmSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.CrashSec;
  End;


Procedure MKRCfgObj.GetForceCrashNmSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.CrashForce;
  End;


Procedure MKRCfgObj.GetDeleteSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.MsgDelSec;
  End;


Procedure MKRCfgObj.GetUnRcvSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.MsgNoRcv;
  End;


Function MKRCfgObj.GetModemResp(MR: Byte): String;
  Begin
  If ((MR > 0) And (MR < 12)) Then
    GetModemResp := MKCfg^.ConnectStr[MR]
  Else
    GetModemResp := '';
  End;


Function MKRCfgObj.GetErrorLevel(MR: Byte): Byte;
  Begin
  If ((MR > 0) And (MR < 12)) Then
    GetErrorLevel := MKCfg^.ExitEL[MR]
  Else
    GetErrorLevel := 0;
  End;


Function MKRCfgObj.GetDLStart: Word;
  Begin
  GetDLStart := MKCfg^.DLStart;
  End;


Function MKRCfgObj.GetDLStop: Word;
  Begin
  GetDLStop := MKCfg^.DLStop;
  End;


Function MKRCfgObj.GetLoBaudStart: Word;
  Begin
  GetLoBaudStart := MKCfg^.LoBaudStart;
  End;


Function MKRCfgObj.GetLoBaudStop: Word;
  Begin
  GetLoBaudStop := MKCfg^.LoBaudStop;
  End;


Function MKRCfgObj.GetMinXferBaud: Word;
  Begin
  GetMinXferBaud := MKCfg^.XferBaud;
  End;


Function MKRCfgObj.GetULCredit: Integer;
  Begin
  GetULCredit := MKCfg^.ULCredit;
  End;


Function MKRCfgObj.GetMinDesc: Byte;
  Begin
  GetMinDesc := MKCfg^.MinDesc;
  End;


Function MKRCfgObj.GetMaxDesc: Byte;
  Begin
  GetMaxDesc := MKCfg^.MaxDesc;
  End;


Function MKRCfgObj.GetMinFree: LongInt;
  Begin
  GetMinFree := MKCfg^.MinULSpace;
  End;


Function MKRCfgObj.GetAskNewFiles: Boolean;
  Begin
  GetAskNewFiles := (MKCfg^.COption and coCheckFiles) <> 0;
  End;


Function MKRCfgObj.GetForceNewFiles: Boolean;
  Begin
  GetForceNewFiles := (MKCfg^.COption and coForceFiles) <> 0;
  End;


Function MKRCfgObj.GetMaxEvents: Word;
  Begin
  GetMaxEvents := 30;
  End;


Function MKRCfgObj.GetEventStatus(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventStatus := Byte(MKCfg^.Events[EN].Status)
  Else
    GetEventStatus := 0;
  End;



Function MKRCfgObj.GetEventTime(EN: Word): Word;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventTime := TimeStr2Word(MkCfg^.Events[EN].Time)
  Else
    GetEventTime := 0;
  End;


Function MKRCfgObj.GetEventEL(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventEL := MKCfg^.Events[EN].ErrorLvl
  Else
    GetEventEL := 0;
  End;


Function MKRCfgObj.GetEventDays(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventDays := MKCfg^.Events[EN].Days
  Else
    GetEventDays := 0;
  End;


Function MKRCfgObj.GetEventOnDay(EN: Word; OD: Byte): Boolean;
  Begin
  GetEventOnDay := (GetEventDays(EN) and (1 shl (OD -1))) <> 0;
  End;


Function MKRCfgObj.GetEventForced(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventForced := MKCfg^.Events[EN].Forced
  Else
    GetEventForced := 0;
  End;


Function MKRCfgObj.GetDoorData(DN: Word): String;
  Begin
  If ((DN > 0) and (DN < 11)) Then
    GetDoorData := MKCfg^.Doors[DN].Data
  Else
    GetDoorData := '';
  End;


Procedure MKRCfgObj.GetDoorSec(DN: Word; Var Sec: SecType);
  Begin
  If ((DN > 0) and (DN < 11)) Then
    Sec := MKCfg^.Doors[DN].Sec
  Else
    Begin
    Sec.Level := $ffff;
    Sec.Flags := -1;     {all flags set}
    End;
  End;


Function MKRCfgObj.DoorAccess(DN: Word; Sec: SecType): Boolean;
  Var
    RSec: SecType;

  Begin
  If ((DN > 0) and (DN < 11)) Then
    Begin
    GetDoorSec(DN, RSec);
    DoorAccess := Access(Sec, RSec);
    End
  Else
    DoorAccess := False;
  End;


Function MKRCfgObj.GetProtNormAvail(PN: Word): Boolean;
  Begin
  Case PN Of
    1..7: GetProtNormAvail := ((MKCfg^.InProt[PN].Attr and paAvail) <> 0);
    11..20: GetProtNormAvail := ((MKCfg^.ExtProt[PN].Attr and paAvail) <> 0);
    Else
      GetProtNormAvail := False;
    End;
  End;


Function MKRCfgObj.GetProtSpecAvail(PN: Word): Boolean;
  Begin
  Case PN Of
    1..7: GetProtSpecAvail := ((MKCfg^.InProt[PN].Attr and paSpecial) <> 0);
    11..20: GetProtSpecAvail := ((MKCfg^.ExtProt[PN].Attr and paSpecial) <> 0);
    Else
      GetProtSpecAvail := False;
    End;
  End;


Function MKRCfgObj.GetProtChar(PN: Word): Char;
  Begin
  Case PN of
    1..10: GetProtChar := MKCfg^.InProt[PN].Key;
    11..20: GetProtChar := MKCfg^.ExtProt[PN].Key;
    Else
      GetProtChar := #255;
    End;
  End;


Function MKRCfgObj.GetProtName(PN: Word): String;
  Begin
  Case PN of
    1..10: GetProtName := MKCfg^.InProt[PN].Name;
    11..20: GetProtName := MKCfg^.ExtProt[PN].Name;
    Else
      GetProtName := '';
    End;
  End;


Function MKRCfgObj.GetPackAvail(PN: Word): Boolean;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackAvail := (Length(MKCfg^.ExtPack[PN].Name) > 0) and ((MKCfg^.ExtPack[PN].Attr and paAvail) <> 0)
  Else
    GetPackAvail := False;
  End;

Function MKRCfgObj.GetPackChar(PN: Word): Char;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackChar := MKCfg^.ExtPack[PN].Key
  Else
    GetPackChar := ' ';
  End;


Function MKRCfgObj.GetPackName(PN: Word): String;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackName := MKCfg^.ExtPack[pn].Name
  Else
    GetPackName := '';
  End;


Function MKRCfgObj.GetPackCmdLine(PN: Word): String;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackCmdLine := MKCfg^.ExtPack[pn].PCmdLine
  Else
    GetPackCmdLine := '';
  End;


Function MKRCfgObj.GetUnPackCmdLine(PN: Word): String;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetUnPackCmdLine := MKCfg^.ExtPack[pn].UCmdLine
  Else
    GetUnPackCmdLine := '';
  End;


Function MKRCfgObj.GetLogLevel: Byte; {Get level of logging}
  Begin
  GetLogLevel := ((MKCfg^.LogAttr shr 2) and 3);
  End;


Function MKRCfgObj.GetLogStyle: Byte; {Get style of log file}
  Begin
  GetLogStyle := MKCfg^.LogAttr and 3;
  End;


Function MKRCfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  GetDefaultPort := MKCfg^.CommPort;
  End;


Function MKRCfgObj.GetMsgPathNum(Area: Word): Word;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    GetMsgPathNum := MKMsg^[MA].MsgBaseDir;
    End
  Else
    GetMsgPathNum := 0;
  End;


Function MKRCfgObj.GetMsgBaseType(Area: Word): Char;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    GetMsgBaseType := MKMsg^[MA].MsgBaseType;
    End
  Else
    GetMsgBaseType := ' ';
  End;


Function MKRCfgObj.GetMsgAreaId(Area: Word): String;
  Var
    MA: Word;
    TmpStr: String;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Case GetMsgBaseType(Area) of
      'H': Begin
           If Area < 201 Then
             GetMsgAreaId := 'H' + PadLeft(Long2Str(Area),'0',3) + GetMsgPath(1)
           Else
             GetMsgAreaId := '';
           End;
      'S': Begin
           TmpStr := 'S' + GetMsgPath(GetMsgPathNum(Area));
           AddBackSlash(TmpStr);
           GetMsgAreaId := TmpStr + MKMsg^[MA].FileId;
           End;
      'F': Begin
           TmpStr := 'F' + GetMsgPath(GetMsgPathNum(Area));
           AddBackSlash(TmpStr);
           TmpStr := TmpStr + MKMsg^[MA].FileId;
           AddBackSlash(TmpStr);
           GetMsgAreaId := TmpStr;
           End;
      'J': Begin
           TmpStr := 'J' + GetMsgPath(GetMsgPathNum(Area));
           AddBackSlash(TmpStr);
           GetMsgAreaId := TmpStr + MKMsg^[MA].FileId;
           End;
      Else
        GetMsgAreaId := '';
      End;
    End
  Else
    GetMsgAreaId := '';
  End;


Function MKRCfgObj.GetNodeIdxName: String;
  Begin
  GetNodeIdxName := 'NodeIdx.Mk';
  End;


Function MKRCfgObj.GetNodeIncName: String;
  Begin
  GetNodeIncName := 'NodeInc.Mk';
  End;


Function MKRCfgObj.GetMsgFileId(Area: Word): String;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgFileId := MKMsg^[MA].FileId
  Else
    GetMsgFileId := '';
  End;


Function MKRCfgObj.GetPrnName: String;
  Begin
  GetPrnName := MKCfg^.PrinterName;
  End;


Function MKRCfgObj.GetOffTypeAvail(OT: Word): Boolean;
  Begin
  If (OT > 0) and (OT < 11) Then
    GetOffTypeAvail := MKCfg^.OffAvail[ot]
  Else
    GetOffTypeAvail := False;
  End;


Function MKRCfgObj.GetOffAllowNew: Boolean;
  Begin
  GetOffAllowNew := (MKCfg^.OffAttr and oaAllowNew) <> 0;
  End;

Function MKRCfgObj.GetOffForceNew: Boolean;
  Begin
  GetOffForceNew := (MKCfg^.OffAttr and oaForceNew) <> 0;
  End;

Function MKRCfgObj.GetOffAllowScrn: Boolean;
  Begin
  GetOffAllowScrn := (MKCfg^.OffAttr and oaAllowScrn) <> 0;
  End;

Function MKRCfgObj.GetOffForceScrn: Boolean;
  Begin
  GetOffForceScrn := (MKCfg^.OffAttr and oaForceScrn) <> 0;
  End;

Function MKRCfgObj.GetOffAllowBull: Boolean;
  Begin
  GetOffAllowBull := (MKCfg^.OffAttr and oaAllowBull) <> 0;
  End;

Function MKRCfgObj.GetOffForceBull: Boolean;
  Begin
  GetOffForceBull := (MKCfg^.OffAttr and oaForceBull) <> 0;
  End;

Function MKRCfgObj.GetOffAllowFreq: Boolean;
  Begin
  GetOffAllowFreq := (MKCfg^.OffAttr and oaAllowFreq) <> 0;
  End;

Function MKRCfgObj.GetOffMax: Word;
  Begin
  GetOffMax := MKCfg^.OffMax;
  End;

Function MKRCfgObj.GetOffConfMax: Word;
  Begin
  GetOffConfMax := MKCfg^.OffConfMax;
  End;

Function MKRCfgObj.GetOffCompRate: Word;
  Begin
  GetOffCompRate := MKCfg^.OffComp;
  End;

Function MKRCfgObj.GetOffSafetyMin: Word;
  Begin
  GetOffSafetyMin := MKCfg^.OffSafety;
  End;

Function MKRCfgObj.GetOffScrns(SN: Word): String;
  Begin
  If (sn > 0) and (sn < 6) Then
    GetOffScrns := MKCfg^.OffScrns[Sn]
  Else
    GetOffScrns := '';
  End;

Function MKRCfgObj.GetOffBulls(BN: Word): String;
  Begin
  If (bn > 0) and (bn < 11) Then
    GetOffBulls := MKCfg^.OffBulls[bn]
  Else
    GetOffBulls := '';
  End;


End.
