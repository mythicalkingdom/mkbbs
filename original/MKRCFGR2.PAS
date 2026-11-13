Unit MKRCfgR2;


{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKCfgAbs,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}

{$I StructRA.250}

Const
  MASize = 50;
  FASize = 50;

Type RaMsgCfgType = Array[1..MASize] of RAMessageRecord;
Type RaFileCfgType = Array[1..FASize] of RaFilesRecord;

Type R2RCfgObj = Object(CfgObj)
  RaCfg:    ^RaConfigRecord;
  RaMsg:    ^RaMsgCfgType;
  RaFile:   ^RaFileCfgType;
  RaEvent:  ^RAEventRecordArray;
  RaModem:  ^RAModemRecord;
  MsgLoaded: Word;
  FileLoaded: Word;
  NumMsgAreas: LongInt;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure RALoad; Virtual;{Normally internal to load RA config}
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Function  GetBbsType: Word; Virtual;               {Get type of Bbs}
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
  Function  GetLogLevel: Byte; Virtual; {Get level of logging}
  Function  GetLogStyle: Byte; Virtual; {Get style of log file}
  Function  GetDefaultPort: Word; Virtual; {Get default comm port}
  Function  GetMsgPathNum(Area: Word): Word; Virtual; {Get message path number}
  Function  GetMsgBaseType(Area: Word): Char; Virtual; {Get message area base type}
  Function  GetMsgAreaId(Area: Word): String; Virtual; {Get message area id string}
  Function  GetNodeIdxName: String; Virtual; {Get nodelist index name}
  Function  GetNodeIncName: String; Virtual; {Get nodelist include name}
  Function  GetPrnName: String; Virtual; {Get printer name}
  Function  ValidMsgArea(Area: Word): Word;
  Function  ValidFileArea(Area: Word): Word;
  End;

Type R2RCfgObjPtr = ^R2RCfgObj;


Implementation


Uses MKString;


Function R2RCfgObj.ValidMsgArea(Area: Word): Word;
  Var
    FP: LongInt;

  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If ((Area < MsgLoaded) or (Area >= (MsgLoaded + MASize - 1))) Then
      Begin
      If Area > 10 Then
        MsgLoaded := Area - 10
      Else
        MsgLoaded := 1;
      FP := MsgLoaded - 1;
      FP := FP * SizeOf(RaMessageRecord);
      If LoadFilePos(FindBbsFile('Messages.RA') + 'Messages.RA', RAMsg^, SizeOf(RAMsg^),
      FP) = 0 Then;
      End;
    ValidMsgArea := Area  + 1 - MsgLoaded;
    End
  Else
    ValidMsgArea := 0;
  End;


Function R2RCfgObj.ValidFileArea(Area: Word): Word;
  Var
    FP: LongInt;

  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    If ((Area < FileLoaded) or (Area >= (FileLoaded + FASize - 1))) Then
      Begin
      If Area > 10 Then
        FileLoaded := Area - 10
      Else
        FileLoaded := 1;
      FP := FileLoaded - 1;
      FP := FP * SizeOf(RAFilesRecord);
      If LoadFilePos(FindBbsFile('Files.RA') + 'Files.RA', RAFile^, SizeOf(RAFile^),
      FP) = 0 Then;
      End;
    ValidFileArea := Area  + 1 - FileLoaded;
    End
  Else
    ValidFileArea := 0;
  End;




Function R2RCfgObj.GetMsgPath(BaseNo: Word): String;
  Begin
  If BaseNo = 1 Then
    GetMsgPath := RaCfg^.MsgBasePath
  Else
   GetMsgPath := '';
  End;


Function R2RCfgObj.GetTxtPath(Num:Word): String; {Get path to asc/ans/avt files}
  Begin
  GetTxtPath := RaCfg^.TextPath;
  End;


Function R2RCfgObj.GetMnuPath(Num: Word): String; {Get path to menu *.mnu files}
  Begin
  GetMnuPath := RaCfg^.MenuPath;
  End;


Function R2RCfgObj.GetNetPath: String;
  Begin
  GetNetPath := '';
  End;


Function R2RCfgObj.GetTempPath: String;
  Begin
  GetTempPath := '';
  End;


Function R2RCfgObj.GetLogFileName: String;
  Begin
  GetLogFileName := RaCfg^.LogFileName;
  End;


Function R2RCfgObj.GetEditCmdPath: String;
  Begin
  GetEditCmdPath := RaCfg^.ExternalEdCmd;
  End;


Function R2RCfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := RaCfg^.NodeListPath;
  End;


Function R2RCfgObj.GetAttachPath: String;
  Begin
  GetAttachPath := RaCfg^.AttachPath;
  End;


Function R2RCfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  GetSemaphorePath := RACfg^.SemPath;
  End;


Function R2RCfgObj.GetBbsType: Word;
  Begin
  GetBbsType := CfgInfo^.BbsType;
  End;



Function R2RCfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := CfgInfo^.BbsPath;
  End;


Procedure R2RCfgObj.RALoad;
  Begin
  New(RaCfg);
  New(RaMsg);
  New(RaFile);
  New(RaEvent);
  New(RaModem);
  Error := LoadFile(FindBbsFile('Config.Ra') + 'Config.Ra', RaCfg^, SizeOf(RaCfg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Messages.Ra') + 'Messages.Ra', RaMsg^, SizeOf(RaMsg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Files.Ra') + 'Files.Ra', RaFile^, SizeOf(RaFile^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Events.Ra') + 'Events.Ra', RaEvent^, SizeOf(RaEvent^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Modem.Ra') + 'Modem.Ra', RaModem^, SizeOf(RaModem^));
  NumMsgAreas := SizeFile(FindBbsFile('Messages.Ra') + 'Messages.RA');
  NumMsgAreas := NumMsgAreas Div SizeOf(RaMessageRecord);
  FileLoaded := 1;
  MsgLoaded := 1;
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(RaCfg);
    Dispose(RaMsg);
    Dispose(RaFile);
    Dispose(RaEvent);
    Dispose(RaModem);
    End;
  End;


Procedure R2RCfgObj.Allocate;
  Begin
  New(RaCfg);
  New(RaMsg);
  New(RaFile);
  New(RaEvent);
  New(RaModem);
  FillChar(RACfg^, SizeOf(RACfg^), 0);
  FillChar(RAMsg^, SizeOf(RAMsg^), 0);
  FillChar(RAFile^, SizeOf(RAFile^), 0);
  FillChar(RAEvent^, SizeOf(RAEvent^), 0);
  FillChar(RAModem^, SizeOf(RAModem^), 0);
  CfgInfo^.BbsPath := GetEnv('RA');
  AddBackSlash(CfgInfo^.BbsPath);
  CfgInfo^.Loaded := True;
  End;


Procedure R2RCfgObj.Unload;
  Begin
  Dispose(RaCfg);
  Dispose(RaMsg);
  Dispose(RaFile);
  Dispose(RaEvent);
  Dispose(RAModem);
  CfgInfo^.Loaded := False;
  End;


Procedure R2RCfgObj.Load;
  Var
    CPath: String;
    i: Word;

  Begin
  CPath := GetCurrentPath;
  CfgInfo^.BbsPath := GetEnv('RA');
  AddBackSlash(CfgInfo^.BbsPath);
  RaLoad;
  If CfgInfo^.BbsPath = '' Then
    Error := 2000;
  If Error = 0 Then
    Begin
    ChDir(StripTrail(CfgInfo^.BbsPath,'\'));
    CfgInfo^.BbsPath := WithBackSlash(FExpand(CfgInfo^.BbsPath));
    RACfg^.MenuPath := WithBackSlash(FExpand(RACfg^.MenuPath));
    RACfg^.TextPath := WithBackSlash(FExpand(RACfg^.TextPath));
    RACfg^.AttachPath := WithBackSlash(FExpand(RACfg^.AttachPath));
    RACfg^.NodeListPath := WithBackSlash(FExpand(RACfg^.NodeListPath));
    RaCfg^.MsgBasePath := WithBackSlash(FExpand(RACfg^.MsgBasePath));
    RACfg^.SysPath := WithBackSlash(FExpand(RACfg^.SysPath));
    ChDir(StripTrail(CPath,'\'));
    End;
  End;


Function R2RCfgObj.GetQuoteStr: String;
  Begin
  GetQuoteStr := RaCfg^.QuoteString;
  End;


Function R2RCfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  GetMaxMsgAreas := NumMsgAreas;
  End;


Function R2RCfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgName := RAMsg^[MA].Name
  Else
    GetMsgName := '';
  End;



Function R2RCfgObj.GetMsgOrigStr(Area: Word): String;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    If Length(RAMsg^[MA].OriginLine) > 0 Then
      GetMsgOrigStr := RAMsg^[MA].OriginLine
    Else
      GetMsgOrigStr := RACfg^.OriginLine;
    End
  Else
    GetMsgOrigStr := '';
  End;


Function R2RCfgObj.GetOrigStr(OrigNum: Word): String;
  Begin
  If OrigNum = 1 Then
    GetOrigStr := RACfg^.OriginLine
  Else
    GetOrigStr := '';
  End;


Procedure R2RCfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
  Begin
  If ((Aka > 0) and (Aka < 11)) Then
    Begin
    Addr.Zone := RaCfg^.Address[Aka - 1].Zone;
    Addr.Net := RaCfg^.Address[Aka - 1].Net;
    Addr.Node := RaCfg^.Address[Aka - 1].Node;
    Addr.Point := RaCfg^.Address[Aka - 1].Point;
    End
  Else
    Begin
    Addr.Zone := 0;
    Addr.Net := 0;
    Addr.Node := 0;
    Addr.Point := 0;
    End;
  End;


Procedure R2RCfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Var
    MAI: Word;

  Begin
  MAI := ValidMsgArea(Area);
  If MAI > 0 Then
    Begin
    MA.Zone := RACfg^.Address[RAMsg^[MAI].AkaAddress].Zone;
    MA.Net := RACfg^.Address[RAMsg^[MAI].AkaAddress].Net;
    MA.Node := RACfg^.Address[RAMsg^[MAI].AkaAddress].Node;
    MA.Point := RACfg^.Address[RAMsg^[MAI].AkaAddress].Point;
    End
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function R2RCfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Var
    Addr: AddrType;

  Begin
  GetMsgAddr(Area, Addr);
  GetMsgAddrStr := AddrStr(Addr);
  End;


Function R2RCfgObj.GetMsgAddrNum(Area: Word): Word;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgAddrNum := RAMsg^[MA].AkaAddress + 1
  Else
    GetMsgAddrNum := 1;
  End;


Function R2RCfgObj.GetMsgOrigNum(Area: Word): Word;
  Begin
  GetMsgOrigNum := 1;
  End;


Function R2RCfgObj.GetMsgPathNum(Area: Word): Word;
  Begin
  GetMsgPathNum := 1;
  End;


Function R2RCfgObj.GetMsgBaseType(Area: Word): Char;
  Var
    MAI: Word;

  Begin
  MAI := ValidMsgArea(Area);
  If MAI > 0 Then
    Begin
    If (RAMsg^[MAI].Attribute and 128) <> 0 Then
      GetMsgBaseType := 'J'
    Else
      GetMsgBaseType := 'H';
    End
  Else
    GetMsgBaseType := ' ';
  End;


Function R2RCfgObj.GetMsgAreaId(Area: Word): String;
  Var
    MAI: Word;

  Begin
  MAI := ValidMsgArea(Area);
  If ((MAI > 0) and (Length(GetMsgName(Area)) > 0)) Then
    Begin
    If (RAMsg^[MAI].Attribute and 128) <> 0 Then
      GetMsgAreaId := 'J' + RAMsg^[MAI].JamBase
    Else
      Begin
      If ((RAMsg^[MAI].AreaNum < 1) or (RAMsg^[MAI].AreaNum > 200)) Then
        GetMsgAreaId := 'H' + PadLeft(Long2Str(Area),'0',3) + GetMsgPath(1)
      Else
        GetMsgAreaId := 'H' + PadLeft(Long2Str(RAMsg^[MAI].AreaNum),'0',3) + GetMsgPath(1);
      End;
    End
  Else
    GetMsgAreaId := '';
  End;


Function R2RCfgObj.GetMsgAllowOffline(Area: Word): Boolean;
  Begin
  GetMsgAllowOffline := True;
  End;



Function R2RCfgObj.GetMsgForceOffline(Area: Word): Boolean;
  Begin
  GetMsgForceOffline := False;
  End;



Function R2RCfgObj.GetMsgAllowCombined(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgAllowCombined := (RAMsg^[MA].Attribute and 2) <> 0
  Else
    GetMsgAllowCombined := False;
  End;


Function R2RCfgObj.GetMsgDefCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    GetMsgDefCombined := (RACfg^.DefaultCombined[(Area + 7) Div 8] and
      (1 shl ((Area + 7) Mod 8))) <> 0;
    End
  Else
    GetMsgDefCombined := False;
  End;


Function R2RCfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;


Function R2RCfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgShortName := Copy(RAMsg^[MA].Name,1,12)
  Else
    GetMsgShortName := '';
  End;


Function R2RCfgObj.GetMsgNetwork(Area: Word; Net: Byte): Boolean;
  Begin
  GetMsgNetwork := False;
  End;


Function R2RCfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Case RAMsg^[MA].Typ Of
      RALocalMail: GetMsgType := Normal;
      RANetMail: GetMsgType := NetMail;
      RAEchoMail: GetMsgType := EchoMail;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Function R2RCfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgWriteSecurity(Area, AreaSec);
  MsgWriteAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgWriteAccess := False;
  End;


Function R2RCfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgReadSecurity(Area, AreaSec);
  MsgReadAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgReadAccess := False;
  End;


Function R2RCfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgSysopSecurity(Area, AreaSec);
  MsgSysopAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgSysopAccess := False;
  End;


Function R2RCfgObj.MsgDeleteAccess(Sec: SecType): Boolean;
  Begin
  MsgDeleteAccess := False;
  End;


Function R2RCfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;
  Begin
  MsgUnRecvAccess := False;
  End;


Function R2RCfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgDays := RAMsg^[MA].DaysKill
  Else
    GetMsgDays := 7;
  End;


Function R2RCfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgRcvdDays := RAMsg^[MA].RecvKill
  Else
    GetMsgRcvdDays := 2;
  End;


Function R2RCfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgsKept := RAMsg^[MA].CountKill
  Else
    GetMsgsKept := 200;
  End;


Function R2RCfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  GetSysopName := RACfg^.Sysop;
  End;


Function R2RCfgObj.GetSystemColor(Num: Byte): Byte; {Get system color attribute}
  Begin
  Case Num Of
    1: GetSystemColor := 15;
    2: GetSystemColor := 14;
    3: GetSystemColor := 13;
    4: GetSystemColor := 10;
    5: GetSystemColor := 11;
    Else
      GetSystemColor := 15;
    End;
  End;


Function R2RCfgObj.GetBbsName: String;
  Begin
  GetBbsName := RACfg^.SystemName;
  End;


Function R2RCfgObj.GetBbsLoc: String;
  Begin
  GetBbsLoc := RACfg^.Location;
  End;


Function R2RCfgObj.GetBbsPhone: String;
  Begin
  GetBbsPhone := '';
  End;


Function R2RCfgObj.GetBbsId: String;
  Begin
  GetBbsId := '';
  End;


Function R2RCfgObj.GetDirectWrite: Boolean;
  Begin
  GetDirectWrite := RACfg^.DirectWrite;
  End;


Function R2RCfgObj.GetSnowCheck: Boolean;
  Begin
  GetSnowCheck := RACfg^.SnowCheck;
  End;


Function R2RCfgObj.GetMonoMode: Boolean;
  Begin
  GetMonoMode := RACfg^.MonoMode;
  End;


Function R2RCfgObj.GetForceKillYes: Boolean;
  Begin
  GetForceKillYes := (RACfg^.KillSent = RaYes);
  End;


Function R2RCfgObj.GetForceKillAsk: Boolean;
  Begin
  GetForceKillAsk := (RACfg^.KillSent = RaAsk);
  End;


Function R2RCfgObj.GetPageStart(DayNo: Byte): Word;
  Begin
  GetPageStart := TimeStr2Word(RACfg^.PageStart[DayNo]);
  End;


Function R2RCfgObj.GetPageStop(DayNo: Byte): Word;
  Begin
  GetPageStop:= TimeStr2Word(RACfg^.PageEnd[DayNo]);
  End;


Function R2RCfgObj.GetMaxPageTimes: Word;
  Begin
  GetMaxPageTimes := RACfg^.MaxPage;
  End;


Function R2RCfgObj.GetPageMsgArea: Word;
  Begin
  GetPageMsgArea := RACfg^.LeaveMsg;
  End;


Function R2RCfgObj.GetPageLength: Byte;
  Begin
  GetPageLength := RACfg^.PageLength and $ff;
  End;


Function R2RCfgObj.GetDefaultPage: Byte;
  Begin
  GetDefaultPage := 1;
  End;


Function R2RCfgObj.GetAskPageReason: Boolean;
  Begin
  GetAskPageReason := RACfg^.WhyPage;
  End;


Function R2RCfgObj.GetMailCheckDetail: Boolean;
  Begin
  GetMailCheckDetail := True;
  End;


Function R2RCfgObj.GetMailCheckTotal: Boolean;
  Begin
  GetMailCheckTotal := True;
  End;


Procedure R2RCfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := RAMsg^[MA].ReadSecurity;
    Sec.Flags := LongInt(RAMsg^[MA].ReadFlags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure R2RCfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := RAMsg^[MA].WriteSecurity;
    Sec.Flags := LongInt(RAMsg^[MA].WriteFlags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure R2RCfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := RAMsg^[MA].SysopSecurity;
    Sec.Flags := LongInt(RAMsg^[MA].SysopFlags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function R2RCfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowPriv := ((RaMsg^[MA].MsgKinds = RABoth) or
      (RaMsg^[MA].MsgKinds = RAPrivate))
  Else
    MsgAllowPriv := True;
  End;



Function R2RCfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowPubl := ((RaMsg^[MA].MsgKinds = RABoth) or
    (RaMsg^[MA].MsgKinds = RAPublic))
  Else
    MsgAllowPubl := True;
  End;


Function R2RCfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowReal := ((RAMsg^[MA].Attribute and 32) = 0)
  Else
    MsgAllowReal := True;
  End;


Function R2RCfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowHdl := ((RaMsg^[MA].Attribute and 32) <> 0)
  Else
    MsgAllowHdl := False;
  End;


Function R2RCfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows anonymous}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowAnon := ((RaMsg^[MA].Attribute and 8) <> 0)
  Else
    MsgAllowAnon := False;
  End;


Function R2RCfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAddFido := ((RaMsg^[MA].Attribute and 1) <> 0)
  Else
    MsgAddFido := True;
  End;



Function R2RCfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Begin
  MsgAllowAnsi := False;
  End;


Function R2RCfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Begin
  MsgAllowHiBit := False;
  End;


Function R2RCfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Begin
  MsgAllowTag := False;
  End;


Function R2RCfgObj.GetMsgReaderTear(Area: Word): Boolean;
  Begin
  GetMsgReaderTear := False;
  End;


Function R2RCfgObj.GetMsgReaderOrig(Area: Word): Boolean;
  Begin
  GetMsgReaderOrig := False;
  End;


Function R2RCfgObj.GetMsgFAttach(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgFAttach := (RAMsg^[MA].Attribute and 4) <> 0
  Else
    GetMsgFAttach := False;
  End;


Function R2RCfgObj.GetMsgSelect(Area: Word): String;
  Begin
  GetMsgSelect := '';
  End;


Function R2RCfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  GetMaxFileAreas := 200;
  End;


Function R2RCfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileAreaName := RAFile^[FA].Name
  Else
    GetFileAreaName := '';
  End;


Function R2RCfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Begin
  GetFileShortName := Copy(GetFileAreaName(Area),1,12);
  End;


Function R2RCfgObj.GetFileSelect(Area: Word): String;
  Begin
  GetFileSelect := '';
  End;


Function R2RCfgObj.GetFileAreaPath(Area: Word): String; {Get file area path}
  Var
    FA: Word;
    TmpStr: String;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    TmpStr := RAFile^[FA].FilePath;
    AddBackSlash(TmpStr);
    GetFileAreaPath := TmpStr;
    End
  Else
    GetFileAreaPath := '';
  End;


Function R2RCfgObj.GetFileListPath(Area: Word): String; {Get file area path}
  Var
    FA: Word;
    TmpStr: String;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    AddBackSlash(RACfg^.ListPath);
    TmpStr := RaCfg^.ListPath + Long2Str(Area);
    If Not FileExist(TmpStr) Then
      Begin
      TmpStr := RAFile^[FA].FilePath;
      AddBackSlash(TmpStr);
      TmpStr := TmpStr + 'FILES.BBS';
      End;
    GetFileListPath := TmpStr;
    End
  Else
    GetFileListPath := '';
  End;


Procedure R2RCfgObj.GetFileViewSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := RAFile^[FA].Security;
    Sec.Flags := LongInt(RAFile^[FA].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure R2RCfgObj.GetFileDLSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := RAFile^[FA].Security;
    Sec.Flags := LongInt(RAFile^[FA].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure R2RCfgObj.GetFileULSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := RAFile^[FA].Security;
    Sec.Flags := LongInt(RAFile^[FA].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure R2RCfgObj.GetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private files security}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    Sec.Level := RAFile^[FA].Security;
    Sec.Flags := LongInt(RAFile^[FA].Flags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function R2RCfgObj.GetFileNoUl(Area: Word): Boolean; {Area disallows ULs}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoUl := False
  Else
    GetFileNoUl := True;
  End;


Function R2RCfgObj.GetFileNoNew(Area: Word): Boolean; {Exclude area from new files}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileNoNew := (RAFile^[FA].Attrib and 1) = 0
  Else
    GetFileNoNew := True;
  End;


Function R2RCfgObj.GetFileFree(Area: Word): Boolean; {Area contains free files}
  Begin
  GetFileFree := False;
  End;


Function R2RCfgObj.GetFileNoTime(Area: Word): Boolean; {Ignore time remaining}
  Begin
  GetFileNoTime := False;
  End;


Function R2RCfgObj.GetFileNoBaud(Area: Word): Boolean; {Ignore min baud limits}
  Begin
  GetFileNoBaud := False;
  End;


Function R2RCfgObj.FileViewAccess(Area: Word; Sec: SecType): Boolean; {Can view files}
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


Function R2RCfgObj.FileDLAccess(Area: Word; Sec: SecType): Boolean; {Can download files}
  Var
    AreaSec: SecType;

  Begin
  GetFileDLSecurity(Area, AreaSec);
  FileDLAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileDLAccess := False;
  End;


Function R2RCfgObj.FileULAccess(Area: Word; Sec: SecType): Boolean; {Can upload files}
  Var
    AreaSec: SecType;

  Begin
  GetFileULSecurity(Area, AreaSec);
  FileULAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileULAccess := False;
  End;


Function R2RCfgObj.FilePvtAccess(Area: Word; Sec: SecType): Boolean; {Private files}
  Var
    AreaSec: SecType;

  Begin
  GetFilePvtSecurity(Area, AreaSec);
  FilePvtAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FilePvtAccess := False;
  End;


Function R2RCfgObj.GetLangName(LNum: Word): String;
  Begin
  If LNum = 1 Then
    GetLangName := 'PROMPTS'
  Else
    GetLangName := '';
  End;


Function R2RCfgObj.GetLangFile(LNum: Word): String;
  Begin
  GetLangFile := 'PROMPTS';
  End;


Function R2RCfgObj.GetLangQuesPath(LNum: Word): String;
  Begin
  GetLangQuesPath := GetBbsPath;
  End;


Function R2RCfgObj.GetAskVoicePhone: Boolean;
  Begin
  GetAskVoicePhone := RACfg^.AskVoicePhone;
  End;


Function R2RCfgObj.GetAskDataPhone: Boolean;
  Begin
  GetAskDataPhone := RACfg^.AskDataPhone;
  End;


Function R2RCfgObj.GetNewUserNMCredit: Word;
  Begin
  GetNewUserNMCredit := RACfg^.NewCredit;
  End;


Function R2RCfgObj.GetAskBirthdate: Boolean;
  Begin
  GetAskBirthdate := RACfg^.AskForBirthDate;
  End;


Function R2RCfgObj.GetAskGender: Boolean;
  Begin
  GetAskGender := False;
  End;


Function R2RCfgObj.GetAskAddr: Boolean;
  Begin
  GetAskAddr := False;
  End;


Function R2RCfgObj.GetSevenBitNames: Boolean;
  Begin
  GetSevenBitNames := False;
  End;


Function R2RCfgObj.GetOneWordName: Boolean;
  Begin
  GetOneWordName := RACfg^.OneWordNames;
  End;


Function R2RCfgObj.GetReAsk: Boolean;
  Begin
  GetReAsk := False;
  End;


Function R2RCfgObj.GetAskHandle: Boolean; {Ask user for handle}
  Begin
  GetAskHandle := RACfg^.AskForHandle;
  End;


Procedure R2RCfgObj.GetEchoToAddr(ES: Word; Var Addr: AddrType);
  Begin
  Addr.Zone := 0;
  Addr.Net := 0;
  Addr.Node := 0;
  Addr.Point := 0;
  End;


Function R2RCfgObj.GetEchoToPwd(ES: Word): String;
  Begin
  GetEchoToPwd := '';
  End;


Function R2RCfgObj.GetEchoToPacker(ES: Word): Byte;
  Begin
  GetEchoToPacker := 1;
  End;


Function R2RCfgObj.GetEchoToNetwork(ES: Word; Nt: Word): Boolean;
  Var
    Mask: LongInt;

  Begin
  GetEchoToNetwork := False;
  End;


Function R2RCfgObj.GetEchoToMailType(ES: Word): Byte;
  Begin
  GetEchoToMailType := 2;
  End;


Function R2RCfgObj.GetEchoToArea(ES: Word; Area: Word): Boolean;
  Begin
  GetEchoToArea := False;
  End;


Function R2RCfgObj.GetEchoAreaPassThru(Area: Word): Boolean;
  Begin
  GetEchoAreaPassThru := False;
  End;


Function R2RCfgObj.GetEchoAreaImportPath(Area: Word): Boolean;
  Begin
  GetEchoAreaImportPath := True;
  End;


Function R2RCfgObj.GetEchoAreaHidePath(Area: Word): Boolean;
  Begin
  GetEchoAreaHidePath := True;
  End;


Function R2RCfgObj.GetEchoAreaImportSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaImportSeen := False;
  End;


Function R2RCfgObj.GetEchoAreaHideSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaHideSeen := True;
  End;


Function R2RCfgObj.GetEchoToHub(Area: Word): Byte;
  Begin
  GetEchoToHub := 1;
  End;


Function R2RCfgObj.GetEchoMaxPkt: LongInt;
  Begin
  GetEchoMaxPkt := 100000;
  End;


Function R2RCfgObj.GetEchoInPath: String;
  Begin
  GetEchoInPath := '';
  End;


Function R2RCfgObj.GetEchoOutPath: String;
  Begin
  GetEchoOutPath := '';
  End;


Function R2RCfgObj.GetEchoAreaTag(Area: Word): String;
  Begin
  GetEchoAreaTag := '';
  End;


Function R2RCfgObj.GetPwdTries: Byte;
  Begin
  GetPwdTries := RACfg^.PasswordTries;
  End;


Function R2RCfgObj.GetPwdExpire: Word;
  Begin
  GetPwdExpire := RACfg^.PwdExpiry;
  End;


Function R2RCfgObj.GetBDCheck: Byte;
  Begin
  GetBDCheck := 0;
  End;


Function R2RCfgObj.GetPhoneCheck: Byte;
  Begin
  GetPhoneCheck := 0;
  End;


Function R2RCfgObj.GetMinPwd: Byte;
  Begin
  GetMinPwd := RaCfg^.MinPwdLen;
  End;


Function R2RCfgObj.GetMinPhone: Byte;
  Begin
  GetMinPhone := 7;
  End;


Function R2RCfgObj.GetStrictPwd: Boolean;
  Begin
  GetStrictPwd := RaCfg^.StrictPwdChecking;
  End;


Function R2RCfgObj.GetRemoteSysop: Boolean;
  Begin
  GetRemoteSysop := RaCfg^.AllowSysRem;
  End;


Function R2RCfgObj.GetFastLocal: Boolean;
  Begin
  GetFastLocal := RaCfg^.FastLogOn;
  End;


Procedure R2RCfgObj.GetNewUserSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.NewSecurity;
  Sec.Flags := LongInt(RACfg^.NewFlags);
  End;


Procedure R2RCfgObj.GetAttachSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.FAttachSec;
  Sec.Flags := LongInt(RACfg^.FAttachFlags);
  End;


Procedure R2RCfgObj.GetRequestSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure R2RCfgObj.GetCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.CrashAskSec;
  Sec.Flags := LongInt(RACfg^.CrashAskFlags);
  End;


Procedure R2RCfgObj.GetForceCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.CrashSec;
  Sec.Flags := LongInt(RACfg^.CrashFlags);
  End;


Procedure R2RCfgObj.GetDeleteSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure R2RCfgObj.GetUnRcvSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Function R2RCfgObj.GetModemResp(MR: Byte): String;
  Begin
  Case MR of
    2: GetModemResp := RAModem^.Connect300;
    3: GetModemResp := RAModem^.Connect1200;
    4: GetModemResp := RAModem^.Connect2400;
    5: GetModemResp := RAModem^.Connect4800;
    6: GetModemResp := RAModem^.Connect7200;
    7: GetModemResp := RAModem^.Connect9600;
    8: GetModemResp := RAModem^.Connect12k;
    9: GetModemResp := RAModem^.Connect14k;
    10: GetModemResp := RAModem^.Connect19k;
    11: GetModemResp := RAModem^.Connect38k;
    Else
      GetModemResp := '';
    End;
  End;


Function R2RCfgObj.GetErrorLevel(MR: Byte): Byte;
  Begin
  Case MR Of
    1: GetErrorLevel := RACfg^.ExitLocal;
    2: GetErrorLevel := RACfg^.Exit300;
    3: GetErrorLevel := RACfg^.Exit1200;
    4: GetErrorLevel := RACfg^.Exit2400;
    5: GetErrorLevel := RACfg^.Exit4800;
    6: GetErrorLevel := RACfg^.Exit7200;
    7: GetErrorLevel := RACfg^.Exit9600;
    8: GetErrorLevel := RACfg^.Exit12000;
    9: GetErrorLevel := RACfg^.Exit14400;
    10: GetErrorLevel := RACfg^.Exit19k;
    11: GetErrorLevel := RACfg^.Exit38k;
    Else
      GetErrorLevel := 0;
    End;
  End;


Function R2RCfgObj.GetDLStart: Word;
  Begin
  GetDLStart := TimeStr2Word(RACfg^.DownloadTimeStart);
  End;


Function R2RCfgObj.GetDLStop: Word;
  Begin
  GetDLStop := TimeStr2Word(RACfg^.DownloadTimeEnd);
  End;


Function R2RCfgObj.GetLoBaudStart: Word;
  Begin
  GetLoBaudStart := TimeStr2Word(RACfg^.SlowBaudTimeStart);
  End;


Function R2RCfgObj.GetLoBaudStop: Word;
  Begin
  GetLoBaudStop := TimeStr2Word(RACfg^.SlowBaudTimeEnd);
  End;


Function R2RCfgObj.GetMinXferBaud: Word;
  Begin
  GetMinXferBaud := RACfg^.TransferBaud;
  End;


Function R2RCfgObj.GetULCredit: Integer;
  Begin
  GetULCredit := RACfg^.CreditFactor;
  End;


Function R2RCfgObj.GetMinDesc: Byte;
  Begin
  GetMinDesc := 10;
  End;


Function R2RCfgObj.GetMaxDesc: Byte;
  Begin
  GetMaxDesc := 240;
  End;


Function R2RCfgObj.GetMinFree: LongInt;
  Begin
  GetMinFree := LongInt(RACfg^.MinUpSpace) * 1024;
  End;


Function R2RCfgObj.GetAskNewFiles: Boolean;
  Begin
  GetAskNewFiles := ((RACfg^.CheckNewFiles = RaAsk) Or
    (RACfg^.CheckNewFiles = RAYes));
  End;


Function R2RCfgObj.GetForceNewFiles: Boolean;
  Begin
  GetForceNewFiles := RACfg^.CheckNewFiles = RaYes;
  End;


Function R2RCfgObj.GetMaxEvents: Word;
  Begin
  GetMaxEvents := 20;
  End;


Function R2RCfgObj.GetEventStatus(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventStatus := Byte(RAEvent^[EN].Status)
  Else
    GetEventStatus := 0;
  End;



Function R2RCfgObj.GetEventTime(EN: Word): Word;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventTime := TimeStr2Word(RAEvent^[EN].StartTime)
  Else
    GetEventTime := 0;
  End;


Function R2RCfgObj.GetEventEL(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventEL := RAEvent^[EN].ErrorLevel
  Else
    GetEventEL := 0;
  End;


Function R2RCfgObj.GetEventDays(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventDays := RAEvent^[EN].Days
  Else
    GetEventDays := 0;
  End;


Function R2RCfgObj.GetEventOnDay(EN: Word; OD: Byte): Boolean;
  Begin
  GetEventOnDay := (GetEventDays(EN) and (1 shl (OD -1))) <> 0;
  End;


Function R2RCfgObj.GetEventForced(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventForced := RAEvent^[EN].Forced
  Else
    GetEventForced := 0;
  End;


Function R2RCfgObj.GetDoorData(DN: Word): String;
  Begin
  GetDoorData := '';
  End;


Procedure R2RCfgObj.GetDoorSec(DN: Word; Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Function R2RCfgObj.DoorAccess(DN: Word; Sec: SecType): Boolean;
  Var
    RSec: SecType;

  Begin
  DoorAccess := False;
  End;


Function R2RCfgObj.GetProtNormAvail(PN: Word): Boolean;
  Begin
  Case PN of
    1: GetProtNormAvail := RACfg^.ProtocolAttrib[1] <> 0;
    2: GetProtNormAvail := RACfg^.ProtocolAttrib[2] <> 0;
    3: GetProtNormAvail := RACfg^.ProtocolAttrib[6] <> 0;
    4: GetProtNormAvail := RACfg^.ProtocolAttrib[3] <> 0;
    5: GetProtNormAvail := RACfg^.ProtocolAttrib[5] <> 0;
    6: GetProtNormAvail := RACfg^.ProtocolAttrib[4] <> 0;
    Else
      GetProtNormAvail := False;
    End;
  End;


Function R2RCfgObj.GetProtSpecAvail(PN: Word): Boolean;
  Begin
  Case PN of
    1: GetProtSpecAvail := RACfg^.ProtocolAttrib[1] <> 0;
    2: GetProtSpecAvail := RACfg^.ProtocolAttrib[2] <> 0;
    3: GetProtSpecAvail := RACfg^.ProtocolAttrib[6] <> 0;
    4: GetProtSpecAvail := RACfg^.ProtocolAttrib[3] <> 0;
    5: GetProtSpecAvail := RACfg^.ProtocolAttrib[5] <> 0;
    6: GetProtSpecAvail := RACfg^.ProtocolAttrib[4] <> 0;
    Else
      GetProtSpecAvail := False;
    End;
  End;


Function R2RCfgObj.GetProtChar(PN: Word): Char;
  Begin
  Case PN of
    1: GetProtChar := 'X';
    2: GetProtChar := 'O';
    3: GetProtChar := 'Y';
    4: GetProtChar := 'Z';
    5: GetProtChar := 'G';
    6: GetProtChar := 'Q';
    7: GetProtChar := 'S';
    Else
      GetProtChar := #255;
    End;
  End;


Function R2RCfgObj.GetProtName(PN: Word): String;
  Begin
  Case PN of
    1: GetProtName := 'Xmodem';
    2: GetProtName := '1k-Xmodem';
    3: GetProtName := 'Ymodem';
    4: GetProtName := 'Zmodem';
    5: GetProtName := 'Ymodem-G';
    6: GetProtName := 'Xmodem-G';
    7: GetProtName := 'Sealink';
    Else
      GetProtName := '';
    End;
  End;


Function R2RCfgObj.GetLogLevel: Byte; {Get level of logging}
  Begin
  GetLogLevel := 1;
  End;


Function R2RCfgObj.GetLogStyle: Byte; {Get style of log file}
  Begin
  GetLogStyle := (RACfg^.LogStyle And 1);
  End;


Function R2RCfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  GetDefaultPort := RaModem^.CommPort;
  End;


Function R2RCfgObj.GetNodeIdxName: String;
  Begin
  GetNodeIdxName := 'NodeIdx.Ra';
  End;


Function R2RCfgObj.GetNodeIncName: String;
  Begin
  GetNodeIncName := 'NodeInc.Ra';
  End;


Function R2RCfgObj.GetPrnName: String;
  Begin
  GetPrnName := RaCfg^.PrinterName;
  End;


End.
