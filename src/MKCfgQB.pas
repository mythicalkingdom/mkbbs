Unit MKCfgQB;


{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKCfgAbs,
  Dos;

{$I Struct.QB}

Type QBFileCfgType = Array[1..200] of QBFileAreaRecord;
Type QBMsgCfgType = Array[1..200] of QBBoardRecord;



Type QBCfgObj = Object(CfgObj)
  QbCfg:    ^QbConfigRecord;
  QbMsg:    ^QbMsgCfgType;
  QbFile:   ^QbFileCfgType;
  QbEvent:  ^QBEventRecordArray;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure QBLoad; Virtual;{Normally internal to load Quickbbs config}
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Procedure Save; Virtual;{Save Bbs config info}
  Function  SaveFileName(FN: String): String; Virtual;
  Function  SaveFileNames: String; Virtual;
  Procedure QBSave; Virtual; {Normally internal to save Quickbbs config}
  Function  GetBbsType: Word; Virtual;               {Get type of Bbs}
  Procedure SetBbsType(BT: Word); Virtual;           {Set type of Bbs}
  Function  GetMsgPath(BaseNo: Word): String; Virtual; {Get directory for msg base}
  Procedure SetMsgPath(BaseNo: Word; MPath: String); Virtual; {Set msg base directory}
  Function  GetTxtPath(Num: Word): String; Virtual;  {Get path to asc/ans/avt files}
  Procedure SetTxtPath(Num: Word; TPath: String); Virtual; {Set path to txt files}
  Function  GetMnuPath(Num: Word): String; Virtual;  {Get path to menu *.mnu files}
  Procedure SetMnuPath(Num: Word; MPath: String); Virtual; {Set path to menus}
  Function  GetNetPath: String; Virtual; {Get netmail path}
  Procedure SetNetPath(NP: String); Virtual; {Set netmail path}
  Function  GetTempPath: String; Virtual; {Get temp file path}
  Procedure SetTempPath(TP: String); Virtual; {Set temp file path}
  Function  GetLogFileName: String; Virtual; {Get log file path and name}
  Procedure SetLogFileName(LN: String); Virtual; {Set log file path and name}
  Function  GetEditCmdPath: String; Virtual; {Get edit command path}
  Procedure SetEditCmdPath(EC: String); Virtual; {Set edit command path}
  Function  GetNodeListPath: String; Virtual; {Get nodelist path}
  Procedure SetNodeListPath(NP: String); Virtual; {Set nodelist path}
  Function  GetAttachPath: String; Virtual; {Get file attach path}
  Procedure SetAttachPath(AP: String); Virtual; {Set file attach path}
  Function  GetSemaphorePath: String; Virtual; {Get Semaphore file path}
  Procedure SetSemaphorePath(SP: String); Virtual; {Set Semaphore file path}
  Function  GetBbsPath: String; Virtual; {Get main bbs directory path}
  Procedure SetBbsPath(BPath: String); Virtual; {Set main Bbs Directory}
  Function  GetQuoteStr: String; Virtual; {Get quote string}
  Procedure SetQuoteStr(Qt: String); Virtual; {Set quote string}
  Procedure GetAddr(Aka: Word; Var Addr: AddrType); Virtual; {Get Bbs Addr or AKA}
  Procedure SetAddr(Aka: Word; Addr: AddrType); Virtual; {Set addr or AKA}
  Function  GetMaxMsgAreas: Word; Virtual; {Get maximum number of msg areas}
  Function  GetMsgName(Area: Word): String; Virtual; {Get message area name}
  Procedure SetMsgName(Area: Word; Name: String); Virtual; {Set message area name}
  Function  GetMsgShortName(Area: Word): String; Virtual; {Get message area short name}
  Procedure SetMsgShortName(Area: Word; Name: String); Virtual; {Set msg short name}
  Function  GetMsgType(Area: Word): MailType; Virtual; {Get type of mail area}
  Procedure SetMsgType(Area: Word; MT: MailType); Virtual; {Set type of mail area}
  Function  GetMsgNetwork(Area: Word; Net: Byte): Boolean; Virtual; {Get msg network}
  Procedure SetMsgNetwork(Area: Word; Net: Byte; MN: Boolean); Virtual; {Set msg network}
  Function  MsgWriteAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Has write access?}
  Function  MsgReadAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Has read access?}
  Function  MsgSysopAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Has sysop access?}
  Function  MsgDeleteAccess(Sec: SecType): Boolean; Virtual;  {Has access to delete messages}
  Function  MsgUnRecvAccess(Sec: SecType): Boolean; Virtual;  {Has access to unrcv messages}
  Procedure GetMsgReadSecurity(Area: Word; Var Sec: SecType); Virtual; {Read security level}
  Procedure SetMsgReadSecurity(Area: Word; Var Sec: SecType); Virtual; {Set read sec}
  Procedure GetMsgWriteSecurity(Area: Word; Var Sec: SecType); Virtual; {Write security level}
  Procedure SetMsgWriteSecurity(Area: Word; Var Sec: SecType); Virtual; {Set write sec}
  Procedure GetMsgSysopSecurity(Area: Word; Var Sec: SecType); Virtual; {Sysop security level}
  Procedure SetMsgSysopSecurity(Area: Word; Var Sec: SecType); Virtual; {Set sysop sec}
  Function  GetMsgDays(Area: Word): Word; Virtual;  {Number of days to keep messages}
  Procedure SetMsgDays(Area: Word; Days: Word); Virtual; {Set days kept}
  Function  GetMsgRcvdDays(Area: Word): Word; Virtual; {Number of days to keep received msgs}
  Procedure SetMsgRcvdDays(Area: Word; Days: Word); Virtual; {Set days recvd kept}
  Function  GetMsgsKept(Area: Word): Word; Virtual; {Number of msgs to keep in area}
  Procedure SetMsgsKept(Area: Word; Msgs: Word); Virtual; {Set # msgs kept}
  Function  MsgAllowPriv(Area: Word): Boolean; Virtual; {Area allows priv msgs}
  Procedure SetMsgAllowPriv(Area: Word; Priv: Boolean); Virtual; {set allow priv}
  Function  MsgAllowPubl(Area: Word): Boolean; Virtual; {Area allows publ msgs}
  Procedure SetMsgAllowPubl(Area: Word; Publ: Boolean); Virtual; {set allow publ}
  Function  MsgAllowReal(Area: Word): Boolean; Virtual; {Area allows real names}
  Procedure SetMsgAllowReal(Area: Word; RName: Boolean); Virtual; {set allow real name}
  Function  MsgAllowHdl(Area: Word): Boolean; Virtual; {Area allows handles}
  Procedure SetMsgAllowHdl(Area: Word; Hdl: Boolean); Virtual; {Set allow handles}
  Function  MsgAllowAnon(Area: Word): Boolean; Virtual; {Area allows aliases}
  Procedure SetMsgAllowAnon(Area: Word; Anon: Boolean); Virtual; {Set area allow anon}
  Function  MsgAddFido(Area: Word): Boolean; Virtual; {Add Fido style tear/origin}
  Procedure SetMsgAddFido(Area: Word; Fido: Boolean); Virtual; {Set adding tear/origin}
  Function  MsgAllowAnsi(Area: Word): Boolean; Virtual; {Area allows ansi}
  Procedure SetMsgAllowAnsi(Area: Word; Ansi: Boolean); Virtual; {Set area allows ansi}
  Function  MsgAllowHiBit(Area: Word): Boolean; Virtual; {Area allows hi-bit chars}
  Procedure SetMsgAllowHiBit(Area: Word; HiBit: Boolean); Virtual; {Set area hi-bit}
  Function  MsgAllowTag(Area: Word): Boolean; Virtual; {Area allows taglines}
  Procedure SetMsgAllowTag(Area: Word; Tag: Boolean); Virtual; {Set allow taglines}
  Function  GetMsgReaderTear(Area: Word): Boolean; Virtual; {Get keep reader tear text}
  Procedure SetMsgReaderTear(Area: Word; RT: Boolean); Virtual; {Set keep reader tear}
  Function  GetMsgReaderOrig(Area: Word): Boolean; Virtual; {Get keep reader tear origin}
  Procedure SetMsgReaderOrig(Area: Word; RT: Boolean); Virtual; {Set keep reader origin}
  Function  GetMsgFAttach(Area: Word): Boolean; Virtual; {Get allow file attach}
  Procedure SetMsgFAttach(Area: Word; FA: Boolean); Virtual; {Set allow file attach}
  Function  GetMsgSelect(Area: Word): String; Virtual; {Get msg select string}
  Procedure SetMsgSelect(Area: Word; Sel: String); Virtual; {Set msg select string}
  Function  GetMsgOrigStr(Area: Word): String; Virtual; {Get origin string for msg area}
  Procedure GetMsgAddr(Area: Word; Var MA: AddrType); Virtual; {Get message area address}
  Function  GetMsgAddrStr(Area: Word): String; Virtual; {Get message address string}
  Function  GetMsgAddrNum(Area: Word): Word; Virtual; {Get message aka number}
  Procedure SetMsgAddrNum(Area: Word; AKA: Word); Virtual; {Set msg aka number}
  Function  GetMsgOrigNum(Area: Word): Word; Virtual; {Get message orig number}
  Procedure SetMsgOrigNum(Area: Word; Orig: Word); Virtual; {Set msg orig number}
  Function  GetMsgAllowOffline(Area: Word): Boolean; Virtual; {Allow in offline}
  Procedure SetMsgAllowOffline(Area: Word; AO: Boolean); Virtual; {Allow in offline}
  Function  GetMsgForceOffline(Area: Word): Boolean; Virtual; {Force in offline}
  Procedure SetMsgForceOffline(Area: Word; FO: Boolean); Virtual; {Force in offline}
  Function  GetMsgAllowCombined(Area: Word): Boolean; Virtual; {Allow in combined read}
  Procedure SetMsgAllowCombined(Area: Word; AC: Boolean); Virtual; {Allow in combined}
  Function  GetMsgDefCombined(Area: Word): Boolean; Virtual; {Default combined area}
  Procedure SetMsgDefCombined(Area: Word; DC: Boolean); Virtual; {Default combined area}
  Function  GetDefaultOrigStr(Area: Word): String; Virtual; {Get full origin string w/addr}
    {includes the * Origin and default text and address}
  Function  GetMaxFileAreas: Word; Virtual; {Get maximum number of file areas}
  Function  GetFileAreaName(Area: Word): String; Virtual; {Get file area name}
  Procedure SetFileAreaName(Area: Word; Name: String); Virtual; {Set file area name}
  Function  GetFileShortName(Area: Word): String; Virtual; {Get short name for area}
  Procedure SetFileShortName(Area: Word; Nm: String); Virtual; {Set short name for area}
  Function  GetFileSelect(Area: Word): String; Virtual; {Get file area select name}
  Procedure SetFileSelect(Area: Word; SN: String); Virtual; {Set file area select name}
  Function  GetFileAreaPath(Area: Word): String; Virtual; {Get file area path}
  Procedure SetFileAreaPath(Area: Word; FPath: String); Virtual; {Set file area path}
  Function  GetFileListPath(Area: Word): String; Virtual; {Get file area path}
  Procedure GetFileViewSecurity(Area: Word; Var Sec: SecType); Virtual; {File Listing security level}
  Procedure SetFileViewSecurity(Area: Word; Var Sec: SecType); Virtual; {set list sec}
  Procedure GetFileULSecurity(Area: Word; Var Sec: SecType); Virtual; {File UL security level}
  Procedure SetFileULSecurity(Area: Word; Var Sec: SecType); Virtual; {File ul sec}
  Procedure GetFileDLSecurity(Area: Word; Var Sec: SecType); Virtual; {File Listing security level}
  Procedure SetFileDLSecurity(Area: Word; Var Sec: SecType); Virtual; {DL Sec}
  Procedure GetFilePvtSecurity(Area: Word; Var Sec: SecType); Virtual; {Private files security}
  Procedure SetFilePvtSecurity(Area: Word; Var Sec: SecType); Virtual; {Private sec}
  Function  GetFileNoUl(Area: Word): Boolean; Virtual; {Area disallows ULs}
  Function  GetFileNoNew(Area: Word): Boolean; Virtual; {Exclude area from new files}
  Function  GetFileFree(Area: Word): Boolean; Virtual; {Area contains free files}
  Function  GetFileNoTime(Area: Word): Boolean; Virtual; {Ignore time remaining}
  Function  GetFileNoBaud(Area: Word): Boolean; Virtual; {Ignore min baud limits}
  Procedure SetFileNoUl(Area: Word; St: Boolean); Virtual; {Area disallows ULs}
  Procedure SetFileNoNew(Area: Word; St: Boolean); Virtual; {Exclude area from new files}
  Procedure SetFileFree(Area: Word; St: Boolean); Virtual; {Area contains free files}
  Procedure SetFileNoTime(Area: Word; St: Boolean); Virtual; {Ignore time remaining}
  Procedure SetFileNoBaud(Area: Word; St: Boolean); Virtual; {Ignore min baud limits}
  Function  GetSysopName: String; Virtual; {Get config name of sysop}
  Procedure SetSysopName(Sysop: String); Virtual; {Set name of sysop}
  Function  GetSystemColor(Num: Byte): Byte; Virtual; {Get system color attribute}
  Procedure SetSystemColor(Num: Byte; Color: Byte); Virtual; {Set system color attr}
  Function  GetBbsName: String; Virtual; {Get Bbs system name}
  Procedure SetBbsName(BN: String); Virtual; {Set Bbs system name}
  Function  GetBbsLoc: String; Virtual; {Get Bbs location}
  Procedure SetBbsLoc(BL: String); Virtual; {Set Bbs location}
  Function  GetBbsPhone: String; Virtual; {Get Bbs main phone number}
  Procedure SetBbsPhone(BPhone: String); Virtual; {Set Bbs main phone number}
  Function  GetBbsId: String; Virtual; {Get Bbs Id}
  Procedure SetBbsId(BId: String); Virtual; {Set BbsId}
  Function  GetDirectWrite: Boolean; Virtual; {Get direct video write status}
  Procedure SetDirectWrite(DW: Boolean); Virtual; {Set Direct video write status}
  Function  GetSnowCheck: Boolean; Virtual; {Get snow checking status}
  Procedure SetSnowCheck(SC: Boolean); Virtual; {Set snow checking status}
  Function  GetMonoMode: Boolean; Virtual; {Get mono screen mode}
  Procedure SetMonoMode(MM: Boolean); Virtual; {Set mono screen mode}
  Function  GetForceKillYes: Boolean; Virtual; {Force kill/sent to yes}
  Procedure SetForceKillYes(FK: Boolean); Virtual; {Set force kill/sent to yes}
  Function  GetForceKillAsk: Boolean; Virtual; {Force kill/sent Ask}
  Procedure SetForceKillAsk(FK: Boolean); Virtual; {Set force kill/sent Ask}
  Function  GetPageStart(DayNo: Byte): Word; Virtual; {Get page start time hi=hr lo=minutes}
  Procedure SetPageStart(DayNo: Byte; St: Word); Virtual; {Set page start time}
  Function  GetPageStop(DayNo: Byte): Word; Virtual; {Get page stop time}
  Procedure SetPageStop(DayNo: Byte; St: Word); Virtual; {Set page stop time}
  Function  GetMaxPageTimes: Word; Virtual; {Get maximum number of page attempts}
  Procedure SetMaxPageTimes(Pg: Word); Virtual; {Set maximum number of page attempts}
  Function  GetPageMsgArea: Word; Virtual; {Get msg area to use for page messages}
  Procedure SetPageMsgArea(Pg: Word); Virtual; {Set msg area to use for page messages}
  Function  GetPageLength: Byte; Virtual; {Get seconds of page length}
  Procedure SetPageLength(PL: Byte); Virtual; {Set seconds of page length}
  Function  GetDefaultPage: Byte; Virtual; {Get new user page tune}
  Procedure SetDefaultPage(DP: Byte); Virtual; {Set new user page tune}
  Function  GetAskPageReason: Boolean; Virtual; {Ask reason for paging}
  Procedure SetAskPageReason(AP: Boolean); Virtual; {Set ask reason for paging}
  Function  GetMailCheckDetail: Boolean; Virtual; {Show detail during mail scan}
  Procedure SetMailCheckDetail(MC: Boolean); Virtual; {Show detail during your scan}
  Function  GetMailCheckTotal: Boolean; Virtual; {Show totals after your mail scan}
  Procedure SetMailCheckTotal(MC: Boolean); Virtual; {Show totals after your mail scan}
  Function  FileViewAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Can view files}
  Function  FileDLAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Can download files}
  Function  FileULAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Can upload files}
  Function  FilePvtAccess(Area: Word; Sec: SecType): Boolean; Virtual; {Private files}
  Function  GetLangQuesPath(LNum: Word): String; Virtual; {Get language q-a path}
  Procedure SetLangQuesPath(LNum: Word; QPath: String); Virtual; {Set lang q-a path}
  Function  GetAskVoicePhone: Boolean; Virtual; {Ask new user voice phone}
  Procedure SetAskVoicePhone(VP: Boolean); Virtual; {Set ask new user voice phone}
  Function  GetAskDataPhone: Boolean; Virtual; {Ask new user data phone}
  Procedure SetAskDataPhone(DP: Boolean); Virtual; {Set ask new user data phone}
  Function  GetNewUserNMCredit: Word; Virtual; {Get new user netmail credit}
  Procedure SetNewUserNMCredit(NM: Word); Virtual; {Set new user netmail credit}
  Function  GetAskBirthdate: Boolean; Virtual; {Ask new user birthdate}
  Procedure SetAskBirthdate(AB: Boolean); Virtual; {Set ask new user birthdate}
  Function  GetAskGender: Boolean; Virtual; {Ask new user gender}
  Procedure SetAskGender(AG: Boolean); Virtual; {Set ask new user gender}
  Function  GetAskAddr: Boolean; Virtual; {Ask new user address}
  Procedure SetAskAddr(AA: Boolean); Virtual; {Set ask new user address}
  Function  GetSevenBitNames: Boolean; Virtual; {Force name to 7 bit chars}
  Procedure SetSevenBitNames (SB: Boolean); Virtual; {Set force 7 bit names}
  Function  GetOneWordName: Boolean; Virtual; {Allow one word names}
  Procedure SetOneWordName(OW: Boolean); Virtual; {Set allow one word names}
  Function  GetReAsk: Boolean; Virtual; {Re-ask blank answers}
  Procedure SetReAsk(RA: Boolean); Virtual; {Set re-ask blank answers}
  Function  GetAskHandle: Boolean; Virtual; {Ask user for handle}
  Procedure SetAskHandle(AH: Boolean); Virtual; {Set ask user for handle}
  Procedure GetEchoToAddr(ES: Word; Var Addr: AddrType); Virtual;
    {Get addr of systems to send echomail to}
  Procedure SetEchoToAddr(ES: Word; Addr: AddrType); Virtual;
  Function  GetEchoToPwd(ES: Word): String; Virtual; {Get echo to system password}
  Procedure SetEchoToPwd(ES: Word; Pwd: String); Virtual; {Set echo to system password}
  Function  GetEchoToPacker(ES: Word): Byte; Virtual; {Get echo to archiver type}
  Procedure SetEchoToPacker(ES: Word; Pk: Byte); Virtual; {Set echo to archiver type}
  Function  GetEchoToNetwork(ES: Word; Nt: Word): Boolean; Virtual; {Get echo network status}
  Procedure SetEchoToNetwork(ES: Word; Nt: Word; St: Boolean); Virtual; {Set echo network}
  Function  GetEchoToMailType(ES: Word): Byte; Virtual; {Get echo mail type}
  Procedure SetEchoToMailType(ES: Word; MT: Byte); Virtual; {Set echo mail type}
  Function  GetEchoToArea(ES: Word; Area: Word): Boolean; Virtual; {Get echo to area on}
  Procedure SetEchoToArea(ES: Word; Area: Word; SA: Boolean); Virtual; {Set echo to area on}
  Function  GetEchoAreaPassThru(Area: Word): Boolean; Virtual; {Get area is pass-thru}
  Procedure SetEchoAreaPassThru(Area: Word; PT: Boolean); Virtual; {Set area is pass-thru}
  Function  GetEchoAreaImportPath(Area: Word): Boolean; Virtual; {Get import path}
  Procedure SetEchoAreaImportPath(Area: Word; IP: Boolean); Virtual; {Set import path}
  Function  GetEchoAreaHidePath(Area: Word): Boolean; Virtual; {Get hide import path}
  Procedure SetEchoAreaHidePath(Area: Word; HP: Boolean); Virtual; {Set hide import path}
  Function  GetEchoAreaImportSeen(Area: Word): Boolean; Virtual; {Get import seen-by}
  Procedure SetEchoAreaImportSeen(Area: Word; ISB: Boolean); Virtual; {Set import seen-by}
  Function  GetEchoAreaHideSeen(Area: Word): Boolean; Virtual; {Get hide imported seen}
  Procedure SetEchoAreaHideSeen(Area: Word; HS: Boolean); Virtual; {Set hide seen}
  Function  GetEchoToHub(Area: Word): Byte; Virtual; {Get hub number}
  Procedure SetEchoToHub(Area: Word; Hub: Byte); Virtual; {Set hub number}
  Function  GetEchoAreaTag(Area: Word): String; Virtual; {Get area tag name}
  Procedure SetEchoAreaTag(Area: Word; Tag: String); Virtual; {Set area tag name}
  Function  GetEchoMaxPkt: LongInt; Virtual; {Get maximum pkt size}
  Procedure SetEchoMaxPkt(MP: LongInt); Virtual; {Set maximum pkt size}
  Function  GetEchoInPath: String; Virtual; {Get inbound files path}
  Procedure SetEchoInPath(EP: String); Virtual; {Set inbound files path}
  Function  GetEchoOutPath: String; Virtual; {Get outbound files path}
  Procedure SetEchoOutPath(EP: String); Virtual; {Set outbound files path}
  Function  GetPwdTries: Byte; Virtual; {Get max password attempts}
  Procedure SetPwdTries(PT: Byte); Virtual; {Set max password attempts}
  Function  GetPwdExpire: Word; Virtual; {Get password expiration days}
  Procedure SetPwdExpire(PE: Word); Virtual; {Set password expiration days}
  Function  GetBDCheck: Byte; Virtual; {Get calls between birthdate confirms}
  Procedure SetBDCheck(BD: Byte); Virtual; {Set calls between birthdate confirms}
  Function  GetPhoneCheck: Byte; Virtual; {Get calls between phone num confirms}
  Procedure SetPhoneCheck(PC: Byte); Virtual; {Set calls between phone num confirms}
  Function  GetMinPwd: Byte; Virtual; {Get min password length}
  Procedure SetMinPwd(MP: Byte); Virtual; {Set min password length}
  Function  GetMinPhone: Byte; Virtual; {Get min phone num length}
  Procedure SetMinPhone(MP: Byte); Virtual; {Set min phone num length}
  Function  GetStrictPwd: Boolean; Virtual; {Get strict password checking}
  Procedure SetStrictPwd(SP: Boolean); Virtual; {Set strict password checking}
  Function  GetRemoteSysop: Boolean; Virtual; {Get allow remote sysop}
  Procedure SetRemoteSysop(RS: Boolean); Virtual; {Set allow remote sysop}
  Function  GetFastLocal: Boolean; Virtual; {Get fast local log on}
  Procedure SetFastLocal(FL: Boolean); Virtual; {Set fast local log on}
  Procedure GetNewUserSec(Var Sec: SecType); Virtual; {Get new user security}
  Procedure SetNewUserSec(Sec: SecType); Virtual; {Set new user security}
  Procedure GetAttachSec(Var Sec: SecType); Virtual; {Get file attach security}
  Procedure SetAttachSec(Sec: SecType); Virtual; {Set file attach security}
  Procedure GetRequestSec(Var Sec: SecType); Virtual; {Get file request security}
  Procedure SetRequestSec(Sec: SecType); Virtual; {Set file request security}
  Procedure GetCrashNmSec(Var Sec: SecType); Virtual; {Get crash netmail security}
  Procedure SetCrashNmSec(Sec: SecType); Virtual; {Set crash netmail security}
  Procedure GetForceCrashNmSec(Var Sec: SecType); Virtual; {Get force crash netmail security}
  Procedure SetForceCrashNmSec(Sec: SecType); Virtual; {Set force crash netmail security}
  Procedure GetDeleteSec(Var Sec: SecType); Virtual; {Get msg delete security}
  Procedure SetDeleteSec(Sec: SecType); Virtual; {Set msg delete security}
  Procedure GetUnRcvSec(Var Sec: SecType); Virtual; {Get msg unreceive security}
  Procedure SetUnRcvSec(Sec: SecType); Virtual; {Set msg unreceive security}
  Function  GetModemResp(MR: Byte): String; Virtual; {Get modem response string}
  Procedure SetModemResp(MR: Byte; Resp: String); Virtual; {Set modem response string}
  Function  GetErrorLevel(MR: Byte): Byte; Virtual; {Get errorlevel}
  Procedure SetErrorLevel(MR: Byte; EL: Byte); Virtual; {Set errorlevel}
  {1=local 2=300 3=1200 4=2400 5=4800 6=7200 7=9600 8=12000
   9=14400 10=19200 11=38400}
  Function  GetDLStart: Word; Virtual; {Get DL Start time}
  Procedure SetDLStart(ST: Word); Virtual; {Set DL Start time}
  Function  GetDLStop: Word; Virtual; {Get DL Stop time}
  Procedure SetDLStop(ST: Word); Virtual; {Set DL Stop time}
  Function  GetLoBaudStart: Word; Virtual; {Get Low Baud DL Start time}
  Procedure SetLoBaudStart(ST: Word); Virtual; {Set Low Baud DL Start time}
  Function  GetLoBaudStop: Word; Virtual; {Get Low Baud DL Stop time}
  Procedure SetLoBaudStop(ST: Word); Virtual; {Set Low Baud DL Stop time}
  Function  GetMinXferBaud: Word; Virtual; {Get min transfer baud rate}
  Procedure SEtMinXferBaud(MB: Word); Virtual; {Set min transfer baud rate}
  Function  GetULCredit: Integer; Virtual; {Get ul credit}
  Procedure SetULCredit(UC: Integer); Virtual; {Set UL Credit}
  Function  GetMinDesc: Byte; Virtual; {Get min descr length}
  Procedure SetMinDesc(MD: Byte); Virtual; {Set min descr length}
  Function  GetMaxDesc: Byte; Virtual; {Get max descr length}
  Procedure SetMaxDesc(MD: Byte); Virtual; {Set max descr length}
  Function  GetMinFree: LongInt; Virtual; {Get min free ul space}
  Procedure SetMinFree(MF: LongInt); Virtual; {Set min free ul space}
  Function  GetAskNewFiles: Boolean; Virtual; {Get ask new file search}
  Procedure SetAskNewFiles(AN: Boolean); Virtual; {Set ask new file search}
  Function  GetForceNewFiles: Boolean; Virtual; {Get force new file search}
  Procedure SetForceNewFiles(AN: Boolean); Virtual; {Set force new file search}
  Function  GetOrigStr(OrigNum: Word): String; Virtual; {Get origin string}
  Procedure SetOrigStr(OrigNum: Word; OrigStr: String); Virtual; {Set origin string}
  Function  GetMaxEvents: Word; Virtual; {Get maximum number of events}
  Function  GetEventStatus(EN: Word): Byte; Virtual; {Get event status}
  Procedure SetEventStatus(EN: Word; ES: Byte); Virtual; {Set event status}
  Function  GetEventTime(EN: Word): Word; Virtual; {Get event time Hi=HH Lo=MM}
  Procedure SetEventTime(EN: Word; ET: Word); Virtual; {Set event time}
  Function  GetEventEL(EN: Word): Byte; Virtual; {Get event errorlevel}
  Procedure SetEventEL(EN: Word; EL: Byte); Virtual; {Set event errorlevel}
  Function  GetEventDays(EN: Word): Byte; Virtual; {Get event days}
  Procedure SetEventDays(EN: Word; ED: Byte); Virtual; {Set event days}
  Function  GetEventOnDay(EN: Word; OD: Byte): Boolean; Virtual; {Is event active on day}
  Procedure SetEventOnDay(EN: Word; OD: Byte; ST: Boolean); Virtual; {Set event active day}
  Function  GetEventForced(EN: Word): Byte; Virtual; {Get event forced}
  Procedure SetEventForced(EN: Word; EF: Byte); Virtual; {Set event forced}
  Function  GetDoorData(DN: Word): String; Virtual; {Get door data line}
  Procedure SetDoorData(DN: Word; DD: String); Virtual; {Set door data line}
  Procedure GetDoorSec(DN: Word; Var Sec: SecType); Virtual; {Get door security}
  Procedure SetDoorSec(DN: Word; Sec: SecType); Virtual; {Set door security}
  Function  DoorAccess(DN: Word; Sec: SecType): Boolean; Virtual; {Has door access}
  Function  GetProtNormAvail(PN: Word): Boolean; Virtual; {Is protocol avail norm files}
  Function  GetProtSpecAvail(PN: Word): Boolean; Virtual; {Is protocol avail special files}
  Function  GetProtChar(PN: Word): Char; Virtual; {Get protocol character}
  Function  GetProtName(PN: Word): String; Virtual; {Get protocol name}
  Procedure SetProtNormAvail(PN: Word; PA: Boolean); Virtual; {Is protocol avail norm files}
  Procedure SetProtSpecAvail(PN: Word; PA: Boolean); Virtual; {Is protocol avail special files}
  Procedure SetProtChar(PN: Word; PC: Char); Virtual; {Set protocol character}
  Procedure SetProtName(PN: Word; Name: String); Virtual; {Set protocol name}
  Function  GetLogLevel: Byte; Virtual; {Get level of logging}
  Procedure SetLogLevel(LL: Byte); Virtual; {Set level of logging}
  Function  GetLogStyle: Byte; Virtual; {Get style of log file}
  Procedure SetLogStyle(LS: Byte); Virtual; {Set style of log file}
  Function  GetDefaultPort: Word; Virtual; {Get default comm port}
  Procedure SetDefaultPort(DP: Word); Virtual; {Set default comm port}
  Function  GetMsgPathNum(Area: Word): Word; Virtual; {Get message path number}
  Procedure SetMsgPathNum(Area: Word; PN: Word); Virtual; {Set message path number}
  Function  GetMsgBaseType(Area: Word): Char; Virtual; {Get message area base type}
  Procedure SetMsgBaseType(Area: Word; BT: Char); Virtual; {Set msg area base type}
  Function  GetMsgAreaId(Area: Word): String; Virtual; {Get message area id string}
  Function  GetNodeIdxName: String; Virtual; {Get nodelist index name}
  Function  GetNodeIncName: String; Virtual; {Get nodelist include name}
  End;

Type QBCfgObjPtr = ^QBCfgObj;


Implementation


Uses MKString;

Function QBCfgObj.GetBbsType: Word;
  Begin
  GetBbsType := CfgInfo^.BbsType;
  End;


Procedure QBCfgObj.SetBbsType(BT: Word);           {Set type of Bbs}
  Begin
  CfgInfo^.BbsType := BT;
  End;



Function QBCfgObj.GetMsgPath(BaseNo: Word): String;
  Begin
  If BaseNo = 1 Then
    GetMsgPath := QBCfg^.MsgPath
  Else
    GetMsgPath := '';
  End;


Procedure QBCfgObj.SetMsgPath(BaseNo: Word; MPath: String);
  Begin
  If BaseNo = 1 Then
    QBCfg^.MsgPath := MPath;
  End;


Function QBCfgObj.GetTxtPath(Num:Word): String; {Get path to asc/ans/avt files}
  Begin
  GetTxtPath := QBCfg^.TextPath;
  End;


Procedure QBCfgObj.SetTxtPath(Num: Word; TPath: String);
  Begin
  If Num = 1 Then
    QBCfg^.TextPath := TPath;
  End;


Function QBCfgObj.GetMnuPath(Num: Word): String; {Get path to menu *.mnu files}
  Begin
  GetMnuPath := QBCfg^.MenuPath;
  End;


Procedure QBCfgObj.SetMnuPath(Num: Word; MPath: String);
  Begin
  If Num = 1 Then
    QBCfg^.MenuPath := MPath;
  End;


Function QBCfgObj.GetNetPath: String;
  Begin
  GetNetPath := QbCfg^.NetPath;
  End;


Procedure QBCfgObj.SetNetPath(NP: String);
  Begin
  QbCfg^.NetPath := Copy(NP, 1, 60);
  End;


Function QBCfgObj.GetTempPath: String;
  Begin
  GetTempPath := '';
  End;


Procedure QBCfgObj.SetTempPath(TP: String);
  Begin
  End;


Function QBCfgObj.GetLogFileName: String;
  Begin
  GetLogFileName := 'SYSTEM.LOG';
  End;


Procedure QBCfgObj.SetLogFileName(LN: String);
  Begin
  End;


Function QBCfgObj.GetEditCmdPath: String;
  Begin
  GetEditCmdPath := QbCfg^.EditorCmdStr;
  End;


Procedure QBCfgObj.SetEditCmdPath(EC: String);
  Begin
  QbCfg^.EditorCmdStr := Copy(EC, 1, 60);
  End;


Function QBCfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := QbCfg^.NodeListPath;
  End;


Procedure QBCfgObj.SetNodeListPath(NP: String);
  Begin
  QbCfg^.NodeListPath := Copy(NP, 1, 60);
  End;


Function QBCfgObj.GetAttachPath: String;
  Begin
  GetAttachPath := '';
  End;


Procedure QBCfgObj.SetAttachPath(AP: String);
  Begin
  End;


Function QBCfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  GetSemaphorePath := GetBbsPath;
  End;


Procedure QBCfgObj.SetSemaphorePath(SP: String); {Set Semaphore file path}
  Begin
  End;


Function QBCfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := CfgInfo^.BbsPath;
  End;


Procedure QBCfgObj.SetBbsPath(BPath: String);      {Set main Bbs Directory}
  Begin
  CfgInfo^.BbsPath := BPath;
  AddBackSlash(CfgInfo^.BbsPath);
  End;


Procedure QBCfgObj.QBLoad;
  Begin
  New(QbCfg);
  New(QbMsg);
  New(QbFile);
  New(QbEvent);
  Error := LoadFile(FindBbsFile('QuickCfg.Dat') + 'QuickCfg.Dat', QbCfg^, SizeOf(QbCfg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('MsgCfg.Dat') + 'MsgCfg.Dat', QbMsg^, SizeOf(QbMsg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('FileCfg.Dat') + 'FileCfg.Dat', QbFile^, SizeOf(QbFile^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('EventCfg.Dat') + 'EventCfg.Dat', QbEvent^, SizeOf(QbEvent^));
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(QbCfg);
    Dispose(QbMsg);
    Dispose(QbFile);
    Dispose(QbEvent);
    End;
  End;


Procedure QBCfgObj.Allocate;
  Begin
  If Not CfgInfo^.Loaded Then
    Begin
    New(QbCfg);
    New(QbMsg);
    New(QbFile);
    New(QbEvent);
    FillChar(QBCfg^, SizeOf(QBCfg^), 0);
    FillChar(QBMsg^, SizeOf(QBMsg^), 0);
    FillChar(QBFile^, SizeOf(QBFile^), 0);
    FillChar(QBEvent^, SizeOf(QBEvent^), 0);
    CfgInfo^.BbsPath := GetEnv('QUICK');
    AddBackSlash(CfgInfo^.BbsPath);
    CfgInfo^.Loaded := True;
    End;
  End;


Procedure QBCfgObj.Unload;
  Begin
  Dispose(QbCfg);
  Dispose(QbMsg);
  Dispose(QbFile);
  Dispose(QbEvent);
  CfgInfo^.Loaded := False;
  End;


Procedure QBCfgObj.Load;
  Var
    CPath: String;
    i: Word;

  Begin
  CPath := GetCurrentPath;
  CfgInfo^.BbsPath := GetEnv('QUICK');
  AddBackSlash(CfgInfo^.BbsPath);
  QBLoad;
  If CfgInfo^.BbsPath = '' Then
    Error := 2000;
  If Error = 0 Then
    Begin
    ChDir(StripTrail(CfgInfo^.BbsPath, DirectorySeparator));
    CfgInfo^.BbsPath := WithBackSlash(FExpand(CfgInfo^.BbsPath));
    QBCfg^.MenuPath := WithBackSlash(FExpand(QBCfg^.MenuPath));
    QBCfg^.TextPath := WithBackSlash(FExpand(QBCfg^.TextPath));
    QBCfg^.NetPath := WithBackSlash(FExpand(QBCfg^.NetPath));
    QBCfg^.NodeListPath := WithBackSlash(FExpand(QBCfg^.NodeListPath));
    QBCfg^.MsgPath := WithBackSlash(FExpand(QBCfg^.MsgPath));
    QBCfg^.SwapPath := WithBackSlash(FExpand(QBCfg^.SwapPath));
    QBCfg^.OverlayPath := WithBackSlash(FExpand(QBCfg^.OverlayPath));
    ChDir(StripTrail(CPath, DirectorySeparator));
    End;
  End;


Procedure QBCfgObj.Save;
  Begin
  QBSave;
  End;


Function QBCfgObj.SaveFileNames: String;
  Begin
  SaveFileNames := 'QuickCfg.Dat|MsgCfg.Dat|FileCfg.Dat|EventCfg.Dat';
  End;


Function QBCfgObj.SaveFileName(FN: String): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := FindBbsFile(FN);
  If Length(TmpStr) > 0 Then
    SaveFileName := TmpStr + FN
  Else
    SaveFileName := GetBbsPath + FN;
  End;


Procedure QBCfgObj.QBSave;
  Begin
  Error := SaveFile(SaveFileName('QuickCfg.Dat'), QbCfg^, SizeOf(QbCfg^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('MsgCfg.Dat'), QbMsg^, SizeOf(QbMsg^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('FileCfg.Dat'), QbFile^, SizeOf(QbFile^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('EventCfg.Dat'), QbEvent^, SizeOf(QbEvent^));
  End;


Function QBCfgObj.GetQuoteStr: String;
  Begin
  GetQuoteStr := QBCfg^.QuoteStr;
  End;


Procedure QBCfgObj.SetQuoteStr(Qt: String);
  Begin
  QBCfg^.QuoteStr := Qt;
  End;


Function QBCfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  GetMaxMsgAreas := 200;
  End;


Function QBCfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgName := QBMsg^[Area].Name
  Else
    GetMsgName := '';
  End;



Function QBCfgObj.GetMsgOrigStr(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Length(QBMsg^[Area].OriginLine) > 0 Then
      GetMsgOrigStr := QBMsg^[Area].OriginLine
    Else
      GetMsgOrigStr := QBCfg^.OriginLine
  Else
    GetMsgOrigStr := '';
  End;


Function QBCfgObj.GetOrigStr(OrigNum: Word): String;
  Begin
  If OrigNum = 1 Then
    GetOrigStr := QBCfg^.OriginLine
  Else
    GetOrigStr := '';
  End;


Procedure QBCfgObj.SetOrigStr(OrigNum: Word; OrigStr: String);
  Begin
  If OrigNum = 1 Then
    QBCfg^.OriginLine := OrigStr;
  End;


Procedure QBCfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
  Begin
  If ((Aka > 0) and (Aka < 12)) Then
    Begin
    Addr.Zone := QBCfg^.MatrixZone[Aka - 1];
    Addr.Net := QBCfg^.MatrixNet[Aka - 1];
    Addr.Node := QBCfg^.MatrixNode[Aka - 1];
    Addr.Point := QBCfg^.MatrixPoint[Aka - 1];
    End
  Else
    Begin
    Addr.Zone := 0;
    Addr.Net := 0;
    Addr.Node := 0;
    Addr.Point := 0;
    End;
  End;


Procedure QBCfgObj.SetAddr(Aka: Word; Addr: AddrType);
  Begin
  If ((Aka > 0) And (Aka < 12)) Then
    Begin
    QBCfg^.MatrixZone[Aka - 1] := Addr.Zone;
    QBCfg^.MatrixNet[Aka - 1] := Addr.Net;
    QBCfg^.MatrixNode[Aka - 1] := Addr.Node;
    QBCfg^.MatrixPoint[Aka - 1] := Addr.Point;
    End;
  End;



Procedure QBCfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MA.Zone := QBCfg^.MatrixZone[QBMsg^[Area].Aka];
    MA.Net := QBCfg^.MatrixNet[QBMsg^[Area].Aka];
    MA.Node := QBCfg^.MatrixNode[QBMsg^[Area].Aka];
    MA.Point := QBCfg^.MatrixPoint[QBMsg^[Area].Aka];
    End
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function QBCfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Var
    Addr: AddrType;

  Begin
  GetMsgAddr(Area, Addr);
  GetMsgAddrStr := AddrStr(Addr);
  End;


Function QBCfgObj.GetMsgAddrNum(Area: Word): Word;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAddrNum := QBMsg^[Area].Aka + 1
  Else
    GetMsgAddrNum := 1;
  End;


Procedure QBCfgObj.SetMsgAddrNum(Area: Word; AKA: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If ((Aka > 0) and (Aka < 12)) Then
      QBMsg^[Area].Aka := Aka - 1;
  End;


Function QBCfgObj.GetMsgOrigNum(Area: Word): Word;
  Begin
  GetMsgOrigNum := 1;
  End;


Procedure QBCfgObj.SetMsgOrigNum(Area: Word; Orig: Word);
  Begin
  End;


Function QBCfgObj.GetMsgAllowOffline(Area: Word): Boolean;
  Begin
  GetMsgAllowOffline := True;
  End;



Procedure QBCfgObj.SetMsgAllowOffline(Area: Word; AO: Boolean);
  Begin
  End;


Function QBCfgObj.GetMsgForceOffline(Area: Word): Boolean;
  Begin
  GetMsgForceOffline := False;
  End;



Procedure QBCfgObj.SetMsgForceOffline(Area: Word; FO: Boolean);
  Begin
  End;


Function QBCfgObj.GetMsgAllowCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAllowCombined := QBMsg^[Area].Combined
  Else
    GetMsgAllowCombined := False;
  End;


Procedure QBCfgObj.SetMsgAllowCombined(Area: Word; AC: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    QBMsg^[Area].Combined := Ac;
  End;


Function QBCfgObj.GetMsgDefCombined(Area: Word): Boolean;
  Begin
  GetMsgDefCombined := False;
  End;


Procedure QBCfgObj.SetMsgDefCombined(Area: Word; DC: Boolean);
  Begin
  End;


Function QBCfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;


Procedure QBCfgObj.SetMsgName(Area: Word; Name: String); {Set message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    QBMsg^[Area].Name := Name;
  End;


Function QBCfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgShortName := Copy(QBMsg^[Area].Name,1,12)
  Else
    GetMsgShortName := '';
  End;


Procedure QBCfgObj.SetMsgShortName(Area: Word; Name: String);
  Begin
  End;


Function QBCfgObj.GetMsgNetwork(Area: Word; Net: Byte): Boolean;
  Begin
  GetMsgNetwork := False;
  End;


Procedure QBCfgObj.SetMsgNetwork(Area: Word; Net: Byte; MN: Boolean);
  Begin
  End;


Function QBCfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case QBMsg^[Area].Typ of
      QBStandard: GetMsgType := Normal;
      QBNetMail: GetMsgType := NetMail;
      QBEMail: GetMsgType := Normal;
      QBEchoMail: GetMsgType := EchoMail;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Procedure QBCfgObj.SetMsgType(Area: Word; MT: MailType); {Set type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case MT of
      Normal: QBMsg^[Area].Typ := QBStandard;
      NetMail: QBMsg^[Area].Typ := QBNetMail;
      EchoMail: QBMsg^[Area].Typ := QBEchoMail;
      End;
    End;
  End;


Function QBCfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgWriteSecurity(Area, AreaSec);
  MsgWriteAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgWriteAccess := False;
  End;


Function QBCfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgReadSecurity(Area, AreaSec);
  MsgReadAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgReadAccess := False;
  End;


Function QBCfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgSysopSecurity(Area, AreaSec);
  MsgSysopAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgSysopAccess := False;
  End;


Function QBCfgObj.MsgDeleteAccess(Sec: SecType): Boolean;
  Begin
  MsgDeleteAccess := False;
  End;


Function QBCfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;
  Begin
  MsgUnRecvAccess := False;
  End;


Function QBCfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetMsgDays := QBMsg^[Area].KillOld
  Else
    GetMsgDays := 7;
  End;


Function QBCfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgRcvdDays := QBMsg^[Area].KillRcvd
  Else
    GetMsgRcvdDays := 2;
  End;


Function QBCfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgsKept := QBMsg^[Area].KeepCnt
  Else
    GetMsgsKept := 200;
  End;


Procedure QBCfgObj.SetMsgDays(Area: Word; Days: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    QBMsg^[Area].KillOld := Days;
  End;


Procedure QBCfgObj.SetMsgRcvdDays(Area: Word; Days: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    QBMsg^[Area].KillRcvd := Days;
  End;


Procedure QBCfgObj.SetMsgsKept(Area: Word; Msgs: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    QBMsg^[Area].KeepCnt := Msgs;
  End;


Function QBCfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  GetSysopName := QBCfg^.SysopName;
  End;


Procedure QBCfgObj.SetSysopName(Sysop: String);
  Begin
  QBCfg^.SysopName := Proper(Copy(Sysop, 1, 35));
  End;


Function QBCfgObj.GetSystemColor(Num: Byte): Byte; {Get system color attribute}
  Begin
  If ((Num < 1) or (Num > 5)) Then
    Num := 1;
  Case Num Of
    1: GetSystemColor := 15;
    2: GetSystemColor := 14;
    3: GetSystemColor := 13;
    4: GetSystemColor := 10;
    5: GetSystemColor := 11;
    End;
  End;


Procedure QBCfgObj.SetSystemColor(Num: Byte; Color: Byte);
  Begin
  End;



Function QBCfgObj.GetBbsName: String;
  Begin
  GetBbsName := QBCfg^.SystemName;
  End;


Procedure QBCfgObj.SetBbsName(BN: String);
  Begin
  QBCfg^.SystemName := Copy(BN, 1, 40);
  End;


Function QBCfgObj.GetBbsLoc: String;
  Begin
  GetBbsLoc := '';
  End;


Procedure QBCfgObj.SetBbsLoc(BL: String);
  Begin
  End;


Function QBCfgObj.GetBbsPhone: String;
  Begin
  GetBbsPhone := '';
  End;


Procedure QBCfgObj.SetBbsPhone(BPhone: String);
  Begin
  End;


Function QBCfgObj.GetBbsId: String;
  Begin
  GetBbsId := '';
  End;


Procedure QBCfgObj.SetBbsId(BId: String);
  Begin
  End;


Function QBCfgObj.GetDirectWrite: Boolean;
  Begin
  GetDirectWrite := QBCfg^.DirectWrite;
  End;


Procedure QBCfgObj.SetDirectWrite(DW: Boolean);
  Begin
  QBCfg^.DirectWrite := DW;
  End;


Function QBCfgObj.GetSnowCheck: Boolean;
  Begin
  GetSnowCheck := QBCfg^.SnowCheck;
  End;


Procedure QBCfgObj.SetSnowCheck(SC: Boolean);
  Begin
  QBCfg^.SnowCheck := SC;
  End;


Function QBCfgObj.GetMonoMode: Boolean;
  Begin
  GetMonoMode := QBCfg^.MonoMode;
  End;


Procedure QBCfgObj.SetMonoMode(MM: Boolean);
  Begin
  QBCfg^.MonoMode := MM;
  End;


Function QBCfgObj.GetForceKillYes: Boolean;
  Begin
  GetForceKillYes := False;
  End;


Procedure QBCfgObj.SetForceKillYes(FK: Boolean);
  Begin
  End;


Function QBCfgObj.GetForceKillAsk: Boolean;
  Begin
  GetForceKillAsk := False;
  End;


Procedure QBCfgObj.SetForceKillAsk(FK: Boolean);
  Begin
  End;


Function QBCfgObj.GetPageStart(DayNo: Byte): Word;
  Begin
  GetPageStart:= (QBCfg^.PagingStart shr 16) +
         ((QBCfg^.PagingStart and $FFFF) Div 1092);
  End;


Procedure QBCfgObj.SetPageStart(DayNo: Byte; St: Word);
  Begin
  QBCfg^.PagingStart := Hi(St);
  QBCfg^.PagingStart := (QbCfg^.PagingStart shl 16) + (Lo(St) * 1092);
  End;


Function QBCfgObj.GetPageStop(DayNo: Byte): Word;
  Begin
  GetPageStop:= (QBCfg^.PagingEnd shr 16) +
         ((QBCfg^.PagingEnd and $FFFF) Div 1092);
  End;


Procedure QBCfgObj.SetPageStop(DayNo: Byte; St: Word);
  Begin
  QBCfg^.PagingEnd := Hi(St);
  QBCfg^.PagingEnd := (QbCfg^.PagingEnd shl 16) +  (Lo(St) * 1092);
  End;


Function QBCfgObj.GetMaxPageTimes: Word;
  Begin
  GetMaxPageTimes := QBCfg^.MaxPageTimes;
  End;


Procedure QBCfgObj.SetMaxPageTimes(Pg: Word);
  Begin
  If Pg > 255 Then
    Pg := 255;
  QBCfg^.MaxPageTimes := Pg;
  End;


Function QBCfgObj.GetPageMsgArea: Word;
  Begin
  GetPageMsgArea := 0;
  End;


Procedure QBCfgObj.SetPageMsgArea(Pg: Word);
  Begin
  End;


Function QBCfgObj.GetPageLength: Byte;
  Begin
  GetPageLength := QBCfg^.PageBellLen and $ff;
  End;


Procedure QBCfgObj.SetPageLength(PL: Byte);
  Begin
  QBCfg^.PageBellLen := PL;
  End;


Function QBCfgObj.GetDefaultPage: Byte;
  Begin
  GetDefaultPage := 1;
  End;


Procedure QBCfgObj.SetDefaultPage(DP: Byte);
  Begin
  End;


Function QBCfgObj.GetAskPageReason: Boolean;
  Begin
  GetAskPageReason := True;
  End;


Procedure QBCfgObj.SetAskPageReason(AP: Boolean);
  Begin
  End;


Function QBCfgObj.GetMailCheckDetail: Boolean;
  Begin
  GetMailCheckDetail := True;
  End;


Procedure QBCfgObj.SetMailCheckDetail(MC: Boolean);
  Begin
  End;


Function QBCfgObj.GetMailCheckTotal: Boolean;
  Begin
  GetMailCheckTotal := True;
  End;


Procedure QBCfgObj.SetMailCheckTotal(MC: Boolean);
  Begin
  End;


Procedure QBCfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := QBMsg^[Area].ReadSec.Security;
    Sec.Flags := LongInt(QBMsg^[Area].ReadSec.Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure QBCfgObj.SetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    QBMsg^[Area].ReadSec.Security := Sec.Level;
    QBMsg^[Area].ReadSec.Flags := QBFlagType(Sec.Flags);
    End;
  End;


Procedure QBCfgObj.SetMsgWriteSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    QBMsg^[Area].WriteSec.Security := Sec.Level;
    QBMsg^[Area].WriteSec.Flags := QBFlagType(Sec.Flags);
    End;
  End;


Procedure QBCfgObj.SetMsgSysopSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    QBMsg^[Area].SysopSec.Security := Sec.Level;
    QBMsg^[Area].SysopSec.Flags := QBFlagType(Sec.Flags);
    End;
  End;


Procedure QBCfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := QBMsg^[Area].WriteSec.Security;
    Sec.Flags := LongInt(QBMsg^[Area].WriteSec.Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure QBCfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := QBMsg^[Area].SysopSec.Security;
    Sec.Flags := LongInt(QBMsg^[Area].SysopSec.Flags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function QBCfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPriv := ((QBMsg^[Area].Kinds = QBBoth) or
         (QBMsg^[Area].Kinds = QBPrivate))
  Else
    MsgAllowPriv := True;
  End;



Procedure QBCfgObj.SetMsgAllowPriv(Area: Word; Priv: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Priv Then
      Case QBMsg^[Area].Kinds of
        QBROnly: QBMsg^[Area].Kinds := QBPrivate;
        QBPublic: QBMsg^[Area].Kinds := QBBoth;
        QBBoth : QBMsg^[Area].Kinds := QBBoth;
        Else
          QBMsg^[Area].Kinds := QBPrivate;
        End
      Else
        Case QBMsg^[Area].Kinds of
          QBBoth: QBMsg^[Area].Kinds := QBPublic;
          QBPrivate: QBMsg^[Area].Kinds := QBROnly;
          QBROnly: QBMsg^[Area].Kinds := QBROnly;
          Else
            QBMsg^[Area].Kinds := QBPublic;
          End;
     End;
  End;


Procedure QBCfgObj.SetMsgAllowPubl(Area: Word; Publ: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Publ Then
      Case QBMsg^[Area].Kinds of
        QBROnly: QBMsg^[Area].Kinds := QBPublic;
        QBPrivate: QBMsg^[Area].Kinds := QBBoth;
        QBBoth: QBMsg^[Area].Kinds := QBBoth;
        Else
          QBMsg^[Area].Kinds := QBPublic;
        End
    Else
      Case QBMsg^[Area].Kinds of
        QBBoth: QBMsg^[Area].Kinds := QBPrivate;
        QBPublic: QBMsg^[Area].Kinds := QBROnly;
        QBROnly: QBMsg^[Area].Kinds := QBROnly;
        Else
          QBMsg^[Area].Kinds := QBPrivate;
        End;
    End;
  End;



Function QBCfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPubl := ((QBMsg^[Area].Kinds = QBBoth) or
      (QBMsg^[Area].Kinds = QBPublic))
  Else
    MsgAllowPubl := True;
  End;


Function QBCfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowReal := (QBMsg^[Area].Aliases <> QBYes)
  Else
    MsgAllowReal := True;
  End;


Procedure QBCfgObj.SetMsgAllowReal(Area: Word; RName: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Case QBMsg^[Area].Aliases of
      QBYes: If RName Then
               QBMsg^[Area].Aliases := QBNo;
      QBNo: If Not RName Then
              QBMsg^[Area].Aliases := QBYes;
      QBMaybe: If Not RName Then
                 QBMsg^[Area].Aliases := QBYes;
      End;
  End;


Procedure QBCfgObj.SetMsgAllowHdl(Area: Word; Hdl: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Case QBMsg^[Area].Aliases of
           QBYes: If Not Hdl Then
             QBMsg^[Area].Aliases := QBNo;
           QBNo: If Not Hdl Then
             QBMsg^[Area].Aliases := QBYes;
           QBMaybe: If Not Hdl Then
             QBMsg^[Area].Aliases := QBNo;
           Else
             If Hdl Then
               QBMsg^[Area].Aliases := QBYes
             Else
               QBMsg^[Area].Aliases := QBNo;
           End;
  End;


Procedure QBCfgObj.SetMsgAllowAnon(Area: Word; Anon: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Anon Then
      QBMsg^[Area].Aliases := QBMaybe
    Else
      If QBMsg^[Area].Aliases = QBMaybe Then
        QBMsg^[Area].Aliases := QBNo;
  End;



Function QBCfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowHdl := (QBMsg^[Area].Aliases <> QBNo)
  Else
    MsgAllowHdl := False;
  End;


Function QBCfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows anonymous}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowAnon := (QBMsg^[Area].Aliases = QBMaybe)
  Else
    MsgAllowAnon := False;
  End;


Function QBCfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Begin
  MsgAddFido := True;
  End;



Procedure QBCfgObj.SetMsgAddFido(Area: Word; Fido: Boolean);
  Begin
  End;


Function QBCfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Begin
  MsgAllowAnsi := False;
  End;


Procedure QBCfgObj.SetMsgAllowAnsi(Area: Word; Ansi: Boolean);
  Begin
  End;


Function QBCfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Begin
  MsgAllowHiBit := False;
  End;


Procedure QBCfgObj.SetMsgAllowHiBit(Area: Word; HiBit: Boolean);
  Begin
  End;


Function QBCfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Begin
  MsgAllowTag := False;
  End;


Procedure QBCfgObj.SetMsgAllowTag(Area: Word; Tag: Boolean);
  Begin
  End;


Function QBCfgObj.GetMsgReaderTear(Area: Word): Boolean;
  Begin
  GetMsgReaderTear := False;
  End;


Procedure QBCfgObj.SetMsgReaderTear(Area: Word; RT: Boolean);
  Begin
  End;


Function QBCfgObj.GetMsgReaderOrig(Area: Word): Boolean;
  Begin
  GetMsgReaderOrig := False;
  End;


Procedure QBCfgObj.SetMsgReaderOrig(Area: Word; RT: Boolean);
  Begin
  End;


Function QBCfgObj.GetMsgFAttach(Area: Word): Boolean;
  Begin
  GetMsgFAttach := False;
  End;


Procedure QBCfgObj.SetMsgFAttach(Area: Word; FA: Boolean);
  Begin
  End;


Function QBCfgObj.GetMsgSelect(Area: Word): String;
  Begin
  GetMsgSelect := '';
  End;


Procedure QBCfgObj.SetMsgSelect(Area: Word; Sel: String);
  Begin
  End;



Function QBCfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  GetMaxFileAreas := 200;
  End;


Function QBCfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    GetFileAreaName := QBFile^[Area].AreaName
  Else
    GetFileAreaName := '';
  End;


Procedure QBCfgObj.SetFileAreaName(Area: Word; Name: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    QBFile^[Area].AreaName := Name;
  End;


Function QBCfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileShortName := Copy(GetFileAreaName(Area),1,12)
  Else
    GetFileShortName := '';
  End;


Procedure QBCfgObj.SetFileShortName(Area: Word; Nm: String);
  Begin
  End;


Function QBCfgObj.GetFileSelect(Area: Word): String;
  Begin
  GetFileSelect := '';
  End;


Procedure QBCfgObj.SetFileSelect(Area: Word; SN: String);
  Begin
  End;


Function QBCfgObj.GetFileAreaPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <=GetMaxFileAreas)) Then
    Begin
    TmpStr := QBFile^[Area].FilePath;
    AddBackSlash(TmpStr);
    GetFileAreaPath := TmpStr;
    End
  Else
    GetFileAreaPath := '';
  End;


Procedure QBCfgObj.SetFileAreaPath(Area: Word; FPath: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    QBFile^[Area].FilePath := FPath;
  End;


Function QBCfgObj.GetFileListPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    If (Length(QBFile^[Area].ListPath) > 0) Then
      TmpStr := QBFile^[Area].ListPath
    Else
      Begin
      TmpStr := QBFile^[Area].FilePath;
      AddBackSlash(TmpStr);
      TmpStr := TmpStr + 'FILES.BBS';
      End;
    GetFileListPath := TmpStr;
    End
  Else
    GetFileListPath := '';
  End;


Procedure QBCfgObj.GetFileViewSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := QBFile^[Area].SearchSec.Security;
    Sec.Flags := LongInt(QBFile^[Area].SearchSec.Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure QBCfgObj.SetFileViewSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    QBFile^[Area].SearchSec.Security := Sec.Level;
    QBFile^[Area].SearchSec.Flags := QBFlagType(Sec.Flags);
    End;
  End;


Procedure QBCfgObj.GetFileDLSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := QBFile^[Area].DLSec.Security;
    Sec.Flags := LongInt(QBFile^[Area].DLSec.Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure QBCfgObj.SetFileDLSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    QBFile^[Area].DLSec.Security := Sec.Level;
    QBFile^[Area].DLSec.Flags := QBFlagType(Sec.Flags);
    End;
  End;


Procedure QBCfgObj.GetFileULSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := QBFile^[Area].DLSec.Security;
    Sec.Flags := LongInt(QBFile^[Area].DLSec.Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure QBCfgObj.SetFileULSecurity(Area: Word; Var Sec: SecType);
  Begin
  End;


Procedure QBCfgObj.GetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private files security}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := QBFile^[Area].DLSec.Security;
    Sec.Flags := LongInt(QBFile^[Area].DLSec.Flags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Procedure QBCfgObj.SetFilePvtSecurity(Area: Word; Var Sec: SecType);
  Begin
  End;


Function QBCfgObj.GetFileNoUl(Area: Word): Boolean; {Area disallows ULs}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoUl := (Not QBFile^[Area].AllowUploads)
  Else
    GetFileNoUl := True;
  End;


Function QBCfgObj.GetFileNoNew(Area: Word): Boolean; {Exclude area from new files}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoNew := False
  Else
    GetFileNoNew := True;
  End;


Function QBCfgObj.GetFileFree(Area: Word): Boolean; {Area contains free files}
  Begin
  GetFileFree := False;
  End;


Function QBCfgObj.GetFileNoTime(Area: Word): Boolean; {Ignore time remaining}
  Begin
  GetFileNoTime := False;
  End;


Function QBCfgObj.GetFileNoBaud(Area: Word): Boolean; {Ignore min baud limits}
  Begin
  GetFileNoBaud := False;
  End;


Procedure QBCfgObj.SetFileNoUl(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    QBFile^[Area].AllowUploads := Not St;
  End;


Procedure QBCfgObj.SetFileNoNew(Area: Word; St: Boolean);
  Begin
  End;


Procedure QBCfgObj.SetFileFree(Area: Word; St: Boolean);
  Begin
  End;


Procedure QBCfgObj.SetFileNoTime(Area: Word; St: Boolean);
  Begin
  End;


Procedure QBCfgObj.SetFileNoBaud(Area: Word; St: Boolean);
  Begin
  End;



Function QBCfgObj.FileViewAccess(Area: Word; Sec: SecType): Boolean; {Can view files}
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


Function QBCfgObj.FileDLAccess(Area: Word; Sec: SecType): Boolean; {Can download files}
  Var
    AreaSec: SecType;

  Begin
  GetFileDLSecurity(Area, AreaSec);
  FileDLAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileDLAccess := False;
  End;


Function QBCfgObj.FileULAccess(Area: Word; Sec: SecType): Boolean; {Can upload files}
  Var
    AreaSec: SecType;

  Begin
  GetFileULSecurity(Area, AreaSec);
  FileULAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileULAccess := False;
  End;


Function QBCfgObj.FilePvtAccess(Area: Word; Sec: SecType): Boolean; {Private files}
  Var
    AreaSec: SecType;

  Begin
  GetFilePvtSecurity(Area, AreaSec);
  FilePvtAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FilePvtAccess := False;
  End;


Function QBCfgObj.GetLangQuesPath(LNum: Word): String;
  Begin
  GetLangQuesPath := GetBbsPath;
  End;


Procedure QBCfgObj.SetLangQuesPath(LNum: Word; QPath: String);
  Begin
  End;


Function QBCfgObj.GetAskVoicePhone: Boolean;
  Begin
  GetAskVoicePhone := QBCfg^.AskHomePhone;
  End;


Procedure QBCfgObj.SetAskVoicePhone(VP: Boolean);
  Begin
  QBCfg^.AskHomePhone := VP;
  End;


Function QBCfgObj.GetAskDataPhone: Boolean;
  Begin
  GetAskDataPhone := QBCfg^.AskDataPhone;
  End;


Procedure QBCfgObj.SetAskDataPhone(DP: Boolean);
  Begin
  QBCfg^.AskDataPhone := DP;
  End;


Function QBCfgObj.GetNewUserNMCredit: Word;
  Begin
  GetNewUserNMCredit := QBCfg^.DefaultCredit;
  End;


Procedure QBCfgObj.SetNewUserNMCredit(NM: Word);
  Begin
  QBCfg^.DefaultCredit := NM;
  End;


Function QBCfgObj.GetAskBirthdate: Boolean;
  Begin
  GetAskBirthdate := QBCfg^.AskBirthday;
  End;


Procedure QBCfgObj.SetAskBirthdate(AB: Boolean);
  Begin
  QBCfg^.AskBirthday := AB;
  End;


Function QBCfgObj.GetAskGender: Boolean;
  Begin
  GetAskGender := QBCfg^.AskSex;
  End;


Procedure QBCfgObj.SetAskGender(AG: Boolean);
  Begin
  QBCfg^.AskSex := AG;
  End;


Function QBCfgObj.GetAskAddr: Boolean;
  Begin
  GetAskAddr := False;
  End;


Procedure QBCfgObj.SetAskAddr(AA: Boolean);
  Begin
  End;


Function QBCfgObj.GetSevenBitNames: Boolean;
  Begin
  GetSevenBitNames := False;
  End;


Procedure QBCfgObj.SetSevenBitNames (SB: Boolean);
  Begin
  End;


Function QBCfgObj.GetOneWordName: Boolean;
  Begin
  GetOneWordName := QBCfg^.OneWordNames;
  End;


Procedure QBCfgObj.SetOneWordName(OW: Boolean);
  Begin
  QBCfg^.OneWordNames := OW;
  End;


Function QBCfgObj.GetReAsk: Boolean;
  Begin
  GetReAsk := False;
  End;


Procedure QBCfgObj.SetReAsk(RA: Boolean);
  Begin
  End;


Function QBCfgObj.GetAskHandle: Boolean; {Ask user for handle}
  Begin
  GetAskHandle := False;
  End;


Procedure QBCfgObj.SetAskHandle(AH: Boolean); {Set ask user for handle}
  Begin
  End;


Procedure QBCfgObj.GetEchoToAddr(ES: Word; Var Addr: AddrType);
  Begin
  Addr.Zone := 0;
  Addr.Net := 0;
  Addr.Node := 0;
  Addr.Point := 0;
  End;


Procedure QBCfgObj.SetEchoToAddr(ES: Word; Addr: AddrType);
  Begin
  End;


Function QBCfgObj.GetEchoToPwd(ES: Word): String;
  Begin
  GetEchoToPwd := '';
  End;


Procedure QBCfgObj.SetEchoToPwd(ES: Word; Pwd: String);
  Begin
  End;


Function QBCfgObj.GetEchoToPacker(ES: Word): Byte;
  Begin
  GetEchoToPacker := 1;
  End;


Procedure QBCfgObj.SetEchoToPacker(ES: Word; Pk: Byte);
  Begin
  End;


Function QBCfgObj.GetEchoToNetwork(ES: Word; Nt: Word): Boolean;
  Begin
  GetEchoToNetwork := False;
  End;


Procedure QBCfgObj.SetEchoToNetwork(ES: Word; Nt: Word; St: Boolean);
  Begin
  End;


Function QBCfgObj.GetEchoToMailType(ES: Word): Byte;
  Begin
  GetEchoToMailType := 2;
  End;


Procedure QBCfgObj.SetEchoToMailType(ES: Word; MT: Byte);
  Begin
  End;


Function QBCfgObj.GetEchoToArea(ES: Word; Area: Word): Boolean;
  Begin
  GetEchoToArea := False;
  End;


Procedure QBCfgObj.SetEchoToArea(ES: Word; Area: Word; SA: Boolean);
  Begin
  End;


Function QBCfgObj.GetEchoAreaPassThru(Area: Word): Boolean;
  Begin
  GetEchoAreaPassThru := False;
  End;


Procedure QBCfgObj.SetEchoAreaPassThru(Area: Word; PT: Boolean);
  Begin
  End;


Function QBCfgObj.GetEchoAreaImportPath(Area: Word): Boolean;
  Begin
  GetEchoAreaImportPath := True;
  End;


Procedure QBCfgObj.SetEchoAreaImportPath(Area: Word; IP: Boolean);
  Begin
  End;


Function QBCfgObj.GetEchoAreaHidePath(Area: Word): Boolean;
  Begin
  GetEchoAreaHidePath := True;
  End;


Procedure QBCfgObj.SetEchoAreaHidePath(Area: Word; HP: Boolean);
  Begin
  End;


Function QBCfgObj.GetEchoAreaImportSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaImportSeen := False;
  End;


Procedure QBCfgObj.SetEchoAreaImportSeen(Area: Word; ISB: Boolean);
  Begin
  End;


Function QBCfgObj.GetEchoAreaHideSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaHideSeen := True;
  End;


Procedure QBCfgObj.SetEchoAreaHideSeen(Area: Word; HS: Boolean);
  Begin
  End;


Function QBCfgObj.GetEchoToHub(Area: Word): Byte;
  Begin
  GetEchoToHub := 1;
  End;


Procedure QBCfgObj.SetEchoToHub(Area: Word; Hub: Byte);
  Begin
  End;


Function QBCfgObj.GetEchoMaxPkt: LongInt;
  Begin
  GetEchoMaxPkt := 100000;
  End;


Procedure QBCfgObj.SetEchoMaxPkt(MP: LongInt);
  Begin
  End;


Function QBCfgObj.GetEchoInPath: String;
  Begin
  GetEchoInPath := '';
  End;


Procedure QBCfgObj.SetEchoInPath(EP: String);
  Begin
  End;


Function QBCfgObj.GetEchoOutPath: String;
  Begin
  GetEchoOutPath := '';
  End;


Procedure QBCfgObj.SetEchoOutPath(EP: String);
  Begin
  End;


Function QBCfgObj.GetEchoAreaTag(Area: Word): String;
  Begin
  GetEchoAreaTag := '';
  End;


Procedure QBCfgObj.SetEchoAreaTag(Area: Word; Tag: String);
  Begin
  End;


Function QBCfgObj.GetPwdTries: Byte;
  Begin
  GetPwdTries := QBCfg^.PasswordTries;
  End;


Procedure QBCfgObj.SetPwdTries(PT: Byte);
  Begin
  QBCfg^.PasswordTries := PT;
  End;


Function QBCfgObj.GetPwdExpire: Word;
  Begin
  GetPwdExpire := 0;
  End;


Procedure QBCfgObj.SetPwdExpire(PE: Word);
  Begin
  End;


Function QBCfgObj.GetBDCheck: Byte;
  Begin
  GetBDCheck := 0;
  End;


Procedure QBCfgObj.SetBDCheck(BD: Byte);
  Begin
  End;


Function QBCfgObj.GetPhoneCheck: Byte;
  Begin
  GetPhoneCheck := 0;
  End;


Procedure QBCfgObj.SetPhoneCheck(PC: Byte);
  Begin
  End;


Function QBCfgObj.GetMinPwd: Byte;
  Begin
  GetMinPwd := 3;
  End;


Procedure QBCfgObj.SetMinPwd(MP: Byte);
  Begin
  End;


Function QBCfgObj.GetMinPhone: Byte;
  Begin
  GetMinPhone := 7;
  End;


Procedure QBCfgObj.SetMinPhone(MP: Byte);
  Begin
  End;


Function QBCfgObj.GetStrictPwd: Boolean;
  Begin
  GetStrictPwd := False;
  End;


Procedure QBCfgObj.SetStrictPwd(SP: Boolean);
  Begin
  End;


Function QBCfgObj.GetRemoteSysop: Boolean;
  Begin
  GetRemoteSysop := True;
  End;


Procedure QBCfgObj.SetRemoteSysop(RS: Boolean);
  Begin
  End;


Function QBCfgObj.GetFastLocal: Boolean;
  Begin
  GetFastLocal := QBCfg^.FastLogOn;
  End;


Procedure QBCfgObj.SetFastLocal(FL: Boolean);
  Begin
  QBCfg^.FastLogOn := FL;
  End;


Procedure QBCfgObj.GetNewUserSec(Var Sec: SecType);
  Begin
  Sec.Level := QBCfg^.DefaultSec.Security;
  Sec.Flags := LongInt(QBCfg^.DefaultSec.Flags);
  End;


Procedure QBCfgObj.SetNewUserSec(Sec: SecType);
  Begin
  QBCfg^.DefaultSec.Security := Sec.Level;
  QBCfg^.DefaultSec.Flags := QBFlagType(Sec.Flags);
  End;


Procedure QBCfgObj.GetAttachSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := -1;     {all flags set}
  End;


Procedure QBCfgObj.SetAttachSec(Sec: SecType);
  Begin
  End;


Procedure QBCfgObj.GetRequestSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := -1;     {all flags set}
  End;


Procedure QBCfgObj.SetRequestSec(Sec: SecType);
  Begin
  End;


Procedure QBCfgObj.GetCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := -1;     {all flags set}
  End;


Procedure QBCfgObj.SetCrashNmSec(Sec: SecType);
  Begin
  End;


Procedure QBCfgObj.GetForceCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := -1;     {all flags set}
  End;


Procedure QBCfgObj.SetForceCrashNmSec(Sec: SecType);
  Begin
  End;


Procedure QBCfgObj.GetDeleteSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := -1;     {all flags set}
  End;


Procedure QBCfgObj.SetDeleteSec(Sec: SecType);
  Begin
  End;


Procedure QBCfgObj.GetUnRcvSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := -1;     {all flags set}
  End;


Procedure QBCfgObj.SetUnRcvSec(Sec: SecType);
  Begin
  End;


Function QBCfgObj.GetModemResp(MR: Byte): String;
  Begin
  Case MR of
         2: GetModemResp := QBCfg^.Resp300;
         3: GetModemResp := QBCfg^.Resp1200;
         4: GetModemResp := QBCfg^.Resp2400;
         7: GetModemResp := QBCfg^.Resp9600;
         10: GetModemResp := QBCfg^.Resp19200;
         11: GetModemResp := QBCfg^.Resp38400;
         Else
           GetModemResp := '';
         End;
  End;


Procedure QBCfgObj.SetModemResp(MR: Byte; Resp: String);
  Begin
  Case MR of
         2: QBCfg^.Resp300 := Resp;
         3: QBCfg^.Resp1200 := Resp;
         4: QBCfg^.Resp2400 := Resp;
         7: QBCfg^.Resp9600 := Resp;
         10: QBCfg^.Resp19200 := Resp;
         11: QBCfg^.Resp38400 := Resp;
         End;
  End;


Function QBCfgObj.GetErrorLevel(MR: Byte): Byte;
  Begin
  GetErrorLevel := 0;
  End;


Procedure QBCfgObj.SetErrorLevel(MR: Byte; EL: Byte);
  Begin
  End;


Function QBCfgObj.GetDLStart: Word;
  Begin
  GetDLStart := (QBCfg^.DownloadStart shr 16) +
         ((QBCfg^.DownloadStart and $ffff) Div 1092);
  End;


Procedure QBCfgObj.SetDLStart(ST: Word);
  Begin
  QBCfg^.DownloadStart := Hi(St);
  QBCfg^.DownloadStart := (QbCfg^.DownloadStart shl 16) + (Lo(St) * 1092);
  End;


Function QBCfgObj.GetDLStop: Word;
  Begin
  GetDLStop := (QBCfg^.DownloadEnd shr 16) +
         ((QBCfg^.DownloadEnd and $ffff) Div 1092);
  End;


Procedure QBCfgObj.SetDLStop(ST: Word);
  Begin
  QBCfg^.DownloadEnd := Hi(St);
  QBCfg^.DownloadEnd := (QbCfg^.DownloadEnd shl 16) + (Lo(St) * 1092);
  End;


Function QBCfgObj.GetLoBaudStart: Word;
  Begin
  GetLoBaudStart := (QBCfg^.LowBaudStart shr 16) +
         ((QBCfg^.LowBaudStart and $ffff) Div 1092);
  End;


Procedure QBCfgObj.SetLoBaudStart(ST: Word);
  Begin
  QBCfg^.LowBaudStart := Hi(St);
  QBCfg^.LowBaudStart := (QbCfg^.LowBaudStart shl 16) + (Lo(St) * 1092);
  End;


Function QBCfgObj.GetLoBaudStop: Word;
  Begin
  GetLoBaudStop := (QBCfg^.LowBaudEnd shr 16) +
         ((QBCfg^.LowBaudEnd and $ffff) Div 1092);
  End;


Procedure QBCfgObj.SetLoBaudStop(ST: Word);
  Begin
  QBCfg^.LowBaudEnd := Hi(St);
  QBCfg^.LowBaudEnd := (QbCfg^.LowBaudEnd shl 16) + (Lo(St) * 1092);
  End;


Function QBCfgObj.GetMinXferBaud: Word;
  Begin
  GetMinXferBaud := QBCfg^.XferBaud;
  End;


Procedure QBCfgObj.SEtMinXferBaud(MB: Word);
  Begin
  QBCfg^.XferBaud := MB;
  End;


Function QBCfgObj.GetULCredit: Integer;
  Begin
  GetULCredit := QBCfg^.UploadCredit;
  End;


Procedure QBCfgObj.SetULCredit(UC: Integer);
  Begin
  QBCfg^.UploadCredit := UC;
  End;


Function QBCfgObj.GetMinDesc: Byte;
  Begin
  GetMinDesc := 10;
  End;


Procedure QBCfgObj.SetMinDesc(MD: Byte);
  Begin
  End;


Function QBCfgObj.GetMaxDesc: Byte;
  Begin
  GetMaxDesc := 240;
  End;


Procedure QBCfgObj.SetMaxDesc(MD: Byte);
  Begin
  End;


Function QBCfgObj.GetMinFree: LongInt;
  Begin
  GetMinFree := 200000;
  End;


Procedure QBCfgObj.SetMinFree(MF: LongInt);
  Begin
  End;


Function QBCfgObj.GetAskNewFiles: Boolean;
  Begin
  GetAskNewFiles := False;
  End;


Procedure QBCfgObj.SetAskNewFiles(AN: Boolean);
  Begin
  End;


Function QBCfgObj.GetForceNewFiles: Boolean;
  Begin
  GetForceNewFiles := False;
  End;


Procedure QBCfgObj.SetForceNewFiles(AN: Boolean);
  Begin
  End;


Function QBCfgObj.GetMaxEvents: Word;
  Begin
  GetMaxEvents := 30;
  End;


Function QBCfgObj.GetEventStatus(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventStatus := Byte(QBEvent^[EN].Status)
  Else
    GetEventStatus := 0;
  End;



Procedure QBCfgObj.SetEventStatus(EN: Word; ES: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    QBEvent^[EN].Status := ES;
  End;



Function QBCfgObj.GetEventTime(EN: Word): Word;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventTime := (QBEvent^[EN].RunTime shr 16) +
           ((QBEvent^[EN].RunTime and $ffff) Div 1092)
  Else
    GetEventTime := 0;
  End;


Procedure QBCfgObj.SetEventTime(EN: Word; ET: Word);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    Begin
    QBEvent^[EN].RunTime := Hi(ET);
    QBEvent^[EN].RunTime := (QBevent^[EN].RunTime shl 16) +  (Lo(ET) * 1092);
    End;
  End;


Function QBCfgObj.GetEventEL(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventEL := QBEvent^[EN].ErrorLevel
  Else
    GetEventEL := 0;
  End;


Procedure QBCfgObj.SetEventEL(EN: Word; EL: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    QBEvent^[EN].ErrorLevel := EL;
  End;


Function QBCfgObj.GetEventDays(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventDays := QBEvent^[EN].Days
  Else
    GetEventDays := 0;
  End;


Procedure QBCfgObj.SetEventDays(EN: Word; ED: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    QBEvent^[EN].Days := ED;
  End;


Function QBCfgObj.GetEventOnDay(EN: Word; OD: Byte): Boolean;
  Begin
  GetEventOnDay := (GetEventDays(EN) and (1 shl (OD -1))) <> 0;
  End;


Procedure QBCfgObj.SetEventOnDay(EN: Word; OD: Byte; ST: Boolean);
  Var
    Temp: Byte;

  Begin
  Temp := GetEventDays(EN);
  If ST Then
    Temp := Temp or (1 shl (OD - 1))
  Else
    Temp := Temp and (Not (1 shl (od - 1)));
  SetEventDays(EN, Temp);
  End;



Function QBCfgObj.GetEventForced(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventForced := QBEvent^[EN].Forced
  Else
    GetEventForced := 0;
  End;


Procedure QBCfgObj.SetEventForced(EN: Word; EF: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    QBEvent^[EN].Forced := EF;
  End;


Function QBCfgObj.GetDoorData(DN: Word): String;
  Begin
  GetDoorData := '';
  End;


Procedure QBCfgObj.SetDoorData(DN: Word; DD: String);
  Begin
  End;


Procedure QBCfgObj.GetDoorSec(DN: Word; Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := -1;     {all flags set}
  End;


Procedure QBCfgObj.SetDoorSec(DN: Word; Sec: SecType);
  Begin
  End;


Function QBCfgObj.DoorAccess(DN: Word; Sec: SecType): Boolean;
  Var
    RSec: SecType;

  Begin
  DoorAccess := False;
  End;


Function QBCfgObj.GetProtNormAvail(PN: Word): Boolean;
  Begin
  Case PN Of
         1: GetProtNormAvail := QBCfg^.Use_Xmodem;
         2: GetProtNormAvail := QBCfg^.Use_Xmodem1k;
         3: GetProtNormAvail := QBCfg^.Use_Ymodem;
         4: GetProtNormAvail := QBCfg^.Use_Zmodem;
         5: GetProtNormAvail := QBCfg^.Use_YmodemG;
         7: GetProtNormAvail := QBCfg^.Use_Sealink;
         Else
           GetProtNormAvail := False;
         End;
  End;


Function QBCfgObj.GetProtSpecAvail(PN: Word): Boolean;
  Begin
  GetProtSpecAvail := GetProtNormAvail(PN);
  End;


Function QBCfgObj.GetProtChar(PN: Word): Char;
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


Function QBCfgObj.GetProtName(PN: Word): String;
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


Procedure QBCfgObj.SetProtNormAvail(PN: Word; PA: Boolean);
  Begin
  Case PN Of
         1: QBCfg^.Use_Xmodem := Pa;
         2: QBCfg^.Use_Xmodem1k := Pa;
         3: QBCfg^.Use_Ymodem := Pa;
         4: QBCfg^.Use_Zmodem := Pa;
         5: QBCfg^.Use_YmodemG := Pa;
         7: QBCfg^.Use_Sealink := Pa;
         End;
  End;


Procedure QBCfgObj.SetProtSpecAvail(PN: Word; PA: Boolean);
  Begin
  End;


Procedure QBCfgObj.SetProtChar(PN: Word; PC: Char);
  Begin
  End;


Procedure QBCfgObj.SetProtName(PN: Word; Name: String);
  Begin
  End;


Function QBCfgObj.GetLogLevel: Byte; {Get level of logging}
  Begin
  GetLogLevel := 1;
  End;


Procedure QBCfgObj.SetLogLevel(LL: Byte); {Set level of logging}
  Begin
  End;


Function QBCfgObj.GetLogStyle: Byte; {Get style of log file}
  Begin
  GetLogStyle := 2;
  End;


Procedure QBCfgObj.SetLogStyle(LS: Byte); {Set style of log file}
  Begin
  End;


Function QbCfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  GetDefaultPort := QBCfg^.CommPort;
  End;


Procedure QbCfgObj.SetDefaultPort(DP: Word); {Set default comm port}
  Begin
  QBCfg^.CommPort := DP;
  End;


Function QbCfgObj.GetMsgPathNum(Area: Word): Word;
  Begin
  GetMsgPathNum := 1;
  End;


Procedure QbCfgObj.SetMsgPathNum(Area: Word; PN: Word);
  Begin
  End;


Function QbCfgObj.GetMsgBaseType(Area: Word): Char;
 Begin
 GetMsgBaseType := 'H';
 End;


Procedure QbCfgObj.SetMsgBaseType(Area: Word; BT: Char);
  Begin
  End;


Function QbCfgObj.GetMsgAreaId(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas) and
  (Length(GetMsgName(Area)) > 0)) Then
    GetMsgAreaId := 'H' + PadLeft(Long2Str(Area),'0',3) + GetMsgPath(1)
  Else
    GetMsgAreaId := '';
  End;


Function QbCfgObj.GetNodeIdxName: String;
  Begin
  GetNodeIdxName := 'NodeIdx.Dat';
  End;


Function QbCfgObj.GetNodeIncName: String;
  Begin
  GetNodeIncName := 'NodeInc.Dat';
  End;


End.
