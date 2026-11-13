Unit MKCfgSB;


{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKCfgAbs,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}

{$I Struct.SB}

Type SBFileCfgType = Array[1..200] of SBFLSearchRec;

Type SBCfgObj = Object(CfgObj)
  SBCfg:    ^SBConfigRecord;
  SBExtra:  ^SBExtraConfig;
  SBFile:   ^SBFileCfgType;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure SBLoad; Virtual;{Normally internal to load SuperBbs config}
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Procedure Save; Virtual;{Save Bbs config info}
  Function  SaveFileName(FN: String): String; Virtual;
  Procedure SBSave; Virtual; {Normally internal to save SuperBbs config}
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

Type SBCfgObjPtr = ^SBCfgObj;


Implementation


Uses MKString;

Function SBCfgObj.GetMsgPath(BaseNo: Word): String;
  Begin
  If BaseNo = 1 Then
    GetMsgPath := SBExtra^.MsgBasePath
  Else
    GetMsgPath := '';
  End;


Procedure SBCfgObj.SetMsgPath(BaseNo: Word; MPath: String);
  Begin
  If BaseNo = 1 Then
    SBExtra^.MsgBasePath := MPath;
  End;


Function SBCfgObj.GetTxtPath(Num:Word): String; {Get path to asc/ans/avt files}
  Begin
  GetTxtPath := SBCfg^.TextPath;
  End;


Procedure SBCfgObj.SetTxtPath(Num: Word; TPath: String);
  Begin
  If Num = 1 Then
    SBCfg^.TextPath := TPath;
  End;


Function SBCfgObj.GetMnuPath(Num: Word): String; {Get path to menu *.mnu files}
  Begin
  GetMnuPath := SBCfg^.MenuPath;
  End;


Procedure SBCfgObj.SetMnuPath(Num: Word; MPath: String);
  Begin
  If Num = 1 Then
    SBCfg^.MenuPath := MPath;
  End;


Function SBCfgObj.GetNetPath: String;
  Begin
  GetNetPath := SbCfg^.NetPath;
  End;


Procedure SBCfgObj.SetNetPath(NP: String);
  Begin
  SBCfg^.NetPath := Copy(NP, 1, 60);
  End;


Function SBCfgObj.GetTempPath: String;
  Begin
  GetTempPath := SbExtra^.TempPath;
  End;


Procedure SBCfgObj.SetTempPath(TP: String);
  Begin
  SbExtra^.TempPath := Copy(TP, 1, 60);
  End;


Function SBCfgObj.GetLogFileName: String;
  Begin
  GetLogFileName := 'SYSTEM.LOG';
  End;


Procedure SBCfgObj.SetLogFileName(LN: String);
  Begin
  End;


Function SBCfgObj.GetEditCmdPath: String;
  Begin
  GetEditCmdPath := SbCfg^.EditorCmdStr;
  End;


Procedure SBCfgObj.SetEditCmdPath(EC: String);
  Begin
  SbCfg^.EditorCmdStr := Copy(EC, 1, 60);
  End;


Function SBCfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := SBExtra^.NodeListPath;
  End;


Procedure SBCfgObj.SetNodeListPath(NP: String);
  Begin
  SBExtra^.NodeListPath := NP;
  End;


Function SBCfgObj.GetAttachPath: String;
  Begin
  GetAttachPath := SBExtra^.LocalAttachPath;
  End;


Procedure SBCfgObj.SetAttachPath(AP: String);
  Begin
  SBExtra^.LocalAttachPath := AP;
  End;


Function SBCfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  GetSemaphorePath := GetBbsPath;
  End;


Procedure SBCfgObj.SetSemaphorePath(SP: String); {Set Semaphore file path}
  Begin
  End;


Function SBCfgObj.GetBbsType: Word;
  Begin
  GetBbsType := CfgInfo^.BbsType;
  End;


Procedure SBCfgObj.SetBbsType(BT: Word);           {Set type of Bbs}
  Begin
  CfgInfo^.BbsType := BT;
  End;



Function SBCfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := CfgInfo^.BbsPath;
  End;


Procedure SBCfgObj.SetBbsPath(BPath: String);      {Set main Bbs Directory}
  Begin
  CfgInfo^.BbsPath := BPath;
  AddBackSlash(CfgInfo^.BbsPath);
  End;


Procedure SBCfgObj.SBLoad;
  Var
    i: Word;

  Begin
  New(SbCfg);
  New(SbExtra);
  New(SbFile);
  For i := 1 to 300 Do
    SBFile^[i].Name := '';
  Error := LoadFile(FindBbsFile('Config.Bbs') + 'Config.Bbs', SbCfg^, SizeOf(SbCfg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('SConfig.Bbs') + 'SConfig.Bbs', SbExtra^, SizeOf(SbExtra^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('FlSearch.Bbs') + 'FlSearch.Bbs', SbFile^, SizeOf(SbFile^));
  i := 300;
  While ((i > 0) and (SBFile^[i].Name = '')) Do
    Dec(i);
  CfgInfo^.FileAreas := i;
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(SbCfg);
    Dispose(SbExtra);
    Dispose(SbFile);
    End;
  End;


Procedure SBCfgObj.Allocate;
  Begin
  If Not CfgInfo^.Loaded Then
    Begin
    New(SBCfg);
    New(SBFile);
    New(SBExtra);
    FillChar(SBCfg^, SizeOf(SBCfg^), 0);
    FillChar(SBExtra^, SizeOf(SBExtra^), 0);
    FillChar(SBFile^, SizeOf(SBFile^), 0);
    CfgInfo^.BbsPath := GetEnv('SBBS');
    AddBackSlash(CfgInfo^.BbsPath);
    CfgInfo^.Loaded := True;
    End;
  End;


Procedure SBCfgObj.Unload;
  Begin
  If CfgInfo^.Loaded Then
    Begin
    Dispose(SBCfg);
    Dispose(SBFile);
    Dispose(SBExtra);
    CfgInfo^.Loaded := False;
    End;
  End;


Procedure SBCfgObj.Load;
  Var
    CPath: String;
    i: Word;

  Begin
  CPath := GetCurrentPath;
  CfgInfo^.BbsPath := GetEnv('SBBS');
  AddBackSlash(CfgInfo^.BbsPath);
  SBLoad;
  If CfgInfo^.BbsPath = '' Then
    Error := 2000;
  If Error = 0 Then
    Begin
    ChDir(StripTrail(CfgInfo^.BbsPath,'\'));
    CfgInfo^.BbsPath := WithBackSlash(FExpand(CfgInfo^.BbsPath));
    SBCfg^.MenuPath := WithBackSlash(FExpand(SBCfg^.MenuPath));
    SBCfg^.TextPath := WithBackSlash(FExpand(SBCfg^.TextPath));
    SBCfg^.NetPath := WithBackSlash(FExpand(SBCfg^.NetPath));
    SBExtra^.SystemPath := WithBackSlash(FExpand(SBExtra^.SystemPath));
    SBExtra^.MsgBasePath := WithBackSlash(FExpand(SBExtra^.MsgBasePath));
    SBExtra^.TempPath := WithBackSlash(FExpand(SBExtra^.TempPath));
    SBExtra^.CommonDir := WithBackSlash(FExpand(SBExtra^.CommonDir));
    SBExtra^.WorkPath := WithBackSlash(FExpand(SBExtra^.WorkPath));
    ChDir(StripTrail(CPath,'\'));
    End;
  End;


Procedure SBCfgObj.Save;
  Begin
  SBSave;
  End;


Function SBCfgObj.SaveFileName(FN: String): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := FindBbsFile(FN);
  If Length(TmpStr) > 0 Then
    SaveFileName := TmpStr + FN
  Else
    SaveFileName := GetBbsPath + FN;
  End;


Procedure SBCfgObj.SBSave;
  Begin
  Error := SaveFile(SaveFileName('Config.Bbs'), SbCfg^, SizeOf(SbCfg^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('SConfig.Bbs'), SbExtra^, SizeOf(SbExtra^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('FlSearch.Bbs'), SbFile^, SizeOf(SbFile^));
  End;


Function SBCfgObj.GetQuoteStr: String;
  Begin
  GetQuoteStr := SBCfg^.QuoteStr;
  End;


Procedure SBCfgObj.SetQuoteStr(Qt: String);
  Begin
  SbCfg^.QuoteStr := Qt;
  End;


Function SBCfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  GetMaxMsgAreas := 200;
  End;


Function SBCfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgName := SBCfg^.BoardRec[Area].Name
  Else
    GetMsgName := '';
  End;



Function SBCfgObj.GetMsgOrigStr(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgOrigStr := SBCfg^.OriginLine
  Else
    GetMsgOrigStr := '';
  End;


Function SBCfgObj.GetOrigStr(OrigNum: Word): String;
  Begin
  If OrigNum = 1 Then
    GetOrigStr := SBCfg^.OriginLine
  Else
    GetOrigStr := '';
  End;


Procedure SBCfgObj.SetOrigStr(OrigNum: Word; OrigStr: String);
  Begin
  If OrigNum = 1 Then
    SBCfg^.OriginLine := OrigStr;
  End;


Procedure SBCfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
  Begin
  If ((Aka > 0) and (Aka < 7)) Then
    Begin
    If Aka > 1 Then
      Begin
      Addr.Zone := SBCfg^.AkaZone[Aka - 1];
      Addr.Net := SBCfg^.AkaNet[Aka - 1];
      Addr.Node := SBCfg^.AkaNode[Aka - 1];
      Addr.Point := SBCfg^.AkaPoint[Aka - 1];
      End
    Else
      Begin
      Addr.Zone := SBCfg^.MatrixZone;
      Addr.Net := SBCfg^.MatrixNet;
      Addr.Node := SBCfg^.MatrixNode;
      Addr.Point := SBCfg^.MatrixPoint;
      End;
    End
  Else
    Begin
    Addr.Zone := 0;
    Addr.Net := 0;
    Addr.Node := 0;
    Addr.Point := 0;
    End;
  End;


Procedure SBCfgObj.SetAddr(Aka: Word; Addr: AddrType);
  Begin
  If ((Aka > 0) and (Aka < 7)) Then
    Begin
    If Aka > 1 Then
      Begin
      SBCfg^.AkaZone[Aka - 1] := Addr.Zone;
      SBCfg^.AkaNet[Aka - 1] := Addr.Net;
      SBCfg^.AkaNode[Aka - 1] := Addr.Node;
      SBCfg^.AkaPoint[Aka - 1] := Addr.Point;
      End
    Else
      Begin
      SBCfg^.MatrixZone := Addr.Zone;
      SBCfg^.MatrixNet := Addr.Net;
      SBCfg^.MatrixNode := Addr.Node;
      SBCfg^.MatrixPoint := Addr.Point;
      End;
    End;
  End;





Procedure SBCfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If SBCfg^.UseAka[Area] > 0 Then
      Begin
      MA.Zone := SBCfg^.AkaZone[SBCfg^.UseAka[Area]];
      MA.Net := SBCfg^.AkaNet[SBCfg^.UseAka[Area]];
      MA.Node := SBCfg^.AkaNode[SBCfg^.UseAka[Area]];
      MA.Point := SBCfg^.AkaPoint[SBCfg^.UseAka[Area]];
      End
    Else
      Begin
      MA.Zone := SBCfg^.MatrixZone;
      MA.Net := SBCfg^.MatrixNet;
      MA.Node := SBCfg^.MatrixNode;
      MA.Point := SBCfg^.MatrixPoint;
      End;
    End
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function SBCfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Var
    Addr: AddrType;

  Begin
  GetMsgAddr(Area, Addr);
  GetMsgAddrStr := AddrStr(Addr);
  End;


Function SBCfgObj.GetMsgAddrNum(Area: Word): Word;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAddrNum := SBCfg^.UseAka[Area] + 1
  Else
    GetMsgAddrNum := 1;
  End;


Procedure SBCfgObj.SetMsgAddrNum(Area: Word; AKA: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If ((Aka > 0) and (Aka < 7)) Then
      SBCfg^.UseAka[Area] := Aka - 1;
  End;


Function SBCfgObj.GetMsgOrigNum(Area: Word): Word;
  Begin
  GetMsgOrigNum := 1;
  End;


Procedure SBCfgObj.SetMsgOrigNum(Area: Word; Orig: Word);
  Begin
  End;


Function SBCfgObj.GetMsgAllowOffline(Area: Word): Boolean;
  Begin
  GetMsgAllowOffline := True;
  End;



Procedure SBCfgObj.SetMsgAllowOffline(Area: Word; AO: Boolean);
  Begin
  End;


Function SBCfgObj.GetMsgForceOffline(Area: Word): Boolean;
  Begin
  GetMsgForceOffline := False;
  End;



Procedure SBCfgObj.SetMsgForceOffline(Area: Word; FO: Boolean);
  Begin
  End;


Function SBCfgObj.GetMsgAllowCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAllowCombined := SBCfg^.BoardRec[Area].Combined
  Else
    GetMsgAllowCombined := False;
  End;


Procedure SBCfgObj.SetMsgAllowCombined(Area: Word; AC: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    SBCfg^.BoardRec[Area].Combined := Ac;
  End;


Function SBCfgObj.GetMsgDefCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetMsgDefCombined := SBExtra^.DefaultBoard[Area]
  Else
    GetMsgDefCombined := False;
  End;


Procedure SBCfgObj.SetMsgDefCombined(Area: Word; DC: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    SBExtra^.DefaultBoard[Area] := DC;
  End;


Function SBCfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;


Procedure SBCfgObj.SetMsgName(Area: Word; Name: String); {Set message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    SBCfg^.BoardRec[Area].Name := Name;
  End;


Function SBCfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgShortName := Copy(SBCfg^.BoardRec[Area].Name,1,12)
  Else
    GetMsgShortName := '';
  End;


Procedure SBCfgObj.SetMsgShortName(Area: Word; Name: String);
  Begin
  End;


Function SBCfgObj.GetMsgNetwork(Area: Word; Net: Byte): Boolean;
  Begin
  GetMsgNetwork := False;
  End;


Procedure SBCfgObj.SetMsgNetwork(Area: Word; Net: Byte; MN: Boolean);
  Begin
  End;




Function SBCfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case SBCfg^.BoardRec[Area].Typ Of
      0: GetMsgType := Normal;
      1: GetMsgType := NetMail;
      2: GetMsgType := Normal;
      3: GetMsgType := EchoMail;
      Else
        GetMsgType := Normal;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Procedure SBCfgObj.SetMsgType(Area: Word; MT: MailType); {Set type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case MT of
      Normal: SBCfg^.BoardRec[Area].Typ := 0;
      NetMail: SBCfg^.BoardRec[Area].Typ := 1;
      EchoMail: SBCfg^.BoardRec[Area].Typ := 3;
      End;
    End;
  End;


Function SBCfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgWriteSecurity(Area, AreaSec);
  MsgWriteAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgWriteAccess := False;
  End;


Function SBCfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgReadSecurity(Area, AreaSec);
  MsgReadAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgReadAccess := False;
  End;


Function SBCfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgSysopSecurity(Area, AreaSec);
  MsgSysopAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgSysopAccess := False;
  End;


Function SBCfgObj.MsgDeleteAccess(Sec: SecType): Boolean;
  Begin
  MsgDeleteAccess := False;
  End;


Function SBCfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;
  Begin
  MsgUnRecvAccess := False;
  End;


Function SBCfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Begin
  GetMsgDays := 7;
  End;


Function SBCfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Begin
  GetMsgRcvdDays := 2;
  End;


Function SBCfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Begin
  GetMsgsKept := 200;
  End;


Procedure SBCfgObj.SetMsgDays(Area: Word; Days: Word);
  Begin
  End;


Procedure SBCfgObj.SetMsgRcvdDays(Area: Word; Days: Word);
  Begin
  End;


Procedure SBCfgObj.SetMsgsKept(Area: Word; Msgs: Word);
  Begin
  End;


Function SBCfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  GetSysopName := SBCfg^.SysopName;
  End;


Procedure SBCfgObj.SetSysopName(Sysop: String);
  Begin
  SBCfg^.SysopName := Proper(Copy(Sysop, 1, 35));
  End;


Function SBCfgObj.GetSystemColor(Num: Byte): Byte; {Get system color attribute}
  Begin
  If ((Num < 1) or (Num > 5)) Then
    Num := 1;
  If Num = 1 Then
    GetSystemColor := SBExtra^.PressEnterColor
  Else
    GetSystemColor := SBExtra^.DefaultColors[Num + 5];
  End;


Procedure SBCfgObj.SetSystemColor(Num: Byte; Color: Byte);
  Begin
  If ((Num < 6) And (Num > 0)) Then
    Begin
    If Num = 1 Then
      SBExtra^.PressEnterColor := Color
    Else
      SBExtra^.DefaultColors[Num + 5] := Color;
    End;
  End;



Function SBCfgObj.GetBbsName: String;
  Begin
  GetBbsName := SBCfg^.SystemName;
  End;


Procedure SBCfgObj.SetBbsName(BN: String);
  Begin
  SBCfg^.SystemName := Copy(BN, 1, 40);
  End;


Function SBCfgObj.GetBbsLoc: String;
  Begin
  GetBbsLoc := SBExtra^.Location;
  End;


Procedure SBCfgObj.SetBbsLoc(BL: String);
  Begin
  SBExtra^.Location := BL;
  End;


Function SBCfgObj.GetBbsPhone: String;
  Begin
  GetBbsPhone := '';
  End;


Procedure SBCfgObj.SetBbsPhone(BPhone: String);
  Begin
  End;


Function SBCfgObj.GetBbsId: String;
  Begin
  GetBbsId := SBExtra^.QWKBbsId;
  End;


Procedure SBCfgObj.SetBbsId(BId: String);
  Begin
  SBExtra^.QwkBbsId := BId;
  End;


Function SBCfgObj.GetDirectWrite: Boolean;
  Begin
  GetDirectWrite := SBCfg^.DirectWrite;
  End;


Procedure SBCfgObj.SetDirectWrite(DW: Boolean);
  Begin
  SBCfg^.DirectWrite := DW;
  End;


Function SBCfgObj.GetSnowCheck: Boolean;
  Begin
  GetSnowCheck := SBCfg^.SnowCheck;
  End;


Procedure SBCfgObj.SetSnowCheck(SC: Boolean);
  Begin
  SBCfg^.SnowCheck := SC;
  End;


Function SBCfgObj.GetMonoMode: Boolean;
  Begin
  GetMonoMode := SBCfg^.MonoMode;
  End;


Procedure SBCfgObj.SetMonoMode(MM: Boolean);
  Begin
  SBCfg^.MonoMode := MM;
  End;


Function SBCfgObj.GetForceKillYes: Boolean;
  Begin
  GetForceKillYes := False;
  End;


Procedure SBCfgObj.SetForceKillYes(FK: Boolean);
  Begin
  End;


Function SBCfgObj.GetForceKillAsk: Boolean;
  Begin
  GetForceKillAsk := False;
  End;


Procedure SBCfgObj.SetForceKillAsk(FK: Boolean);
  Begin
  End;


Function SBCfgObj.GetPageStart(DayNo: Byte): Word;
  Begin
  GetPageStart := TimeStr2Word(SBExtra^.PageStart[DayNo]);
  End;


Procedure SBCfgObj.SetPageStart(DayNo: Byte; St: Word);
  Begin
  SBExtra^.PageStart[DayNo] := Word2TimeStr(ST);
  End;


Function SBCfgObj.GetPageStop(DayNo: Byte): Word;
  Begin
  GetPageStop := TimeStr2Word(SBExtra^.PageEnd[DayNo]);
  End;


Procedure SBCfgObj.SetPageStop(DayNo: Byte; St: Word);
  Begin
  SBExtra^.PageEnd[DayNo]:= Word2TimeStr(ST);
  End;


Function SBCfgObj.GetMaxPageTimes: Word;
  Begin
  GetMaxPageTimes := SBCfg^.MaxPageTimes;
  End;


Procedure SBCfgObj.SetMaxPageTimes(Pg: Word);
  Begin
  If Pg > 255 Then
    Pg := 255;
  SBCfg^.MaxPageTimes := Pg;
  End;


Function SBCfgObj.GetPageMsgArea: Word;
  Begin
  GetPageMsgArea := SBExtra^.MsgAfterPageBoard;
  End;


Procedure SBCfgObj.SetPageMsgArea(Pg: Word);
  Begin
  SBExtra^.MsgAfterPageBoard := Pg;
  End;


Function SBCfgObj.GetPageLength: Byte;
  Begin
  GetPageLength := SBCfg^.PageBellLen and $ff;
  End;


Procedure SBCfgObj.SetPageLength(PL: Byte);
  Begin
  SBCfg^.PageBellLen := PL;
  End;


Function SBCfgObj.GetDefaultPage: Byte;
  Begin
  GetDefaultPage := 1;
  End;


Procedure SBCfgObj.SetDefaultPage(DP: Byte);
  Begin
  End;


Function SBCfgObj.GetAskPageReason: Boolean;
  Begin
  GetAskPageReason := True;
  End;


Procedure SBCfgObj.SetAskPageReason(AP: Boolean);
  Begin
  End;


Function SBCfgObj.GetMailCheckDetail: Boolean;
  Begin
  GetMailCheckDetail := True;
  End;


Procedure SBCfgObj.SetMailCheckDetail(MC: Boolean);
  Begin
  End;


Function SBCfgObj.GetMailCheckTotal: Boolean;
  Begin
  GetMailCheckTotal := True;
  End;


Procedure SBCfgObj.SetMailCheckTotal(MC: Boolean);
  Begin
  End;


Procedure SBCfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := SBCfg^.BoardRec[Area].ReadSecLvl;
    Sec.Flags := LongInt(SBCfg^.BoardRec[Area].ReadFlags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure SBCfgObj.SetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    SBCfg^.BoardRec[Area].ReadSecLvl := Sec.Level;
    SBCfg^.BoardRec[Area].ReadFlags := SBFlagType(Sec.Flags);
    End;
  End;


Procedure SBCfgObj.SetMsgWriteSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    SBCfg^.BoardRec[Area].WriteSecLvl := Sec.Level;
    SBCfg^.BoardRec[Area].WriteFlags := SBFlagType(Sec.Flags);
    End;
  End;


Procedure SBCfgObj.SetMsgSysopSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    SBCfg^.BoardRec[Area].SysopSecLvl := Sec.Level;
    SBCfg^.BoardRec[Area].SysopFlags := SBFlagType(Sec.Flags);
    End;
  End;


Procedure SBCfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := SBCfg^.BoardRec[Area].WriteSecLvl;
    Sec.Flags := LongInt(SBCfg^.BoardRec[Area].WriteFlags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure SBCfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := SBCfg^.BoardRec[Area].SysopSecLvl;
    Sec.Flags := LongInt(SBCfg^.BoardRec[Area].SysopFlags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function SBCfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPriv := ((SBCfg^.BoardRec[Area].Kinds = 0) or
    (SBCfg^.BoardRec[Area].Kinds = 1))
  Else
    MsgAllowPriv := True;
  End;



Procedure SBCfgObj.SetMsgAllowPriv(Area: Word; Priv: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Priv Then
      Case SBCfg^.BoardRec[Area].Kinds of
        3: SBCfg^.BoardRec[Area].Kinds := 1;
        2: SBCfg^.BoardRec[Area].Kinds := 0;
        0: SBCfg^.BoardRec[Area].Kinds := 0;
        Else
          SBCfg^.BoardRec[Area].Kinds := 1;
        End
    Else
      Case SBCfg^.BoardRec[Area].Kinds of
        0: SBCfg^.BoardRec[Area].Kinds := 2;
        1: SBCfg^.BoardRec[Area].Kinds := 3;
        3: SBCfg^.BoardRec[Area].Kinds := 3;
        Else
          SBCfg^.BoardRec[Area].Kinds := 2;
        End;
    End;
  End;


Procedure SBCfgObj.SetMsgAllowPubl(Area: Word; Publ: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Publ Then
      Case SBCfg^.BoardRec[Area].Kinds of
        3: SBCfg^.BoardRec[Area].Kinds := 2;
        1: SBCfg^.BoardRec[Area].Kinds := 0;
        0: SBCfg^.BoardRec[Area].Kinds := 0;
        Else
          SBCfg^.BoardRec[Area].Kinds := 2;
        End
    Else
      Case SBCfg^.BoardRec[Area].Kinds of
        0: SBCfg^.BoardRec[Area].Kinds := 1;
        2: SBCfg^.BoardRec[Area].Kinds := 3;
        3: SBCfg^.BoardRec[Area].Kinds := 3;
        Else
          SBCfg^.BoardRec[Area].Kinds := 1;
        End;
    End;
  End;



Function SBCfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPubl := ((SBCfg^.BoardRec[Area].Kinds = 0) or (
    SBCfg^.BoardRec[Area].Kinds = 2))
  Else
    MsgAllowPubl := True;
  End;


Function SBCfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowReal := (SBCfg^.BoardRec[Area].Aliases <> 1)
  Else
    MsgAllowReal := True;
  End;


Procedure SBCfgObj.SetMsgAllowReal(Area: Word; RName: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case SBCfg^.BoardRec[Area].Aliases Of
      0: ;
      1: If RName Then
           SBCfg^.BoardRec[Area].Aliases := 3;
      2: ;
      3: If Not RName Then
           SBCfg^.BoardRec[Area].Aliases := 1;
      End;
    End;
  End;


Procedure SBCfgObj.SetMsgAllowHdl(Area: Word; Hdl: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case SBCfg^.BoardRec[Area].Aliases Of
      0: If Hdl Then
                SBCfg^.BoardRec[Area].Aliases := 3;
      1: If Not Hdl Then
                SBCfg^.BoardRec[Area].Aliases := 1;
      2: ;
      3: If Not Hdl Then
                SBCfg^.BoardRec[Area].Aliases := 0;
      Else
             If Hdl Then
               SBCfg^.BoardRec[Area].Aliases := 3
             Else
               SBCfg^.BoardRec[Area].Aliases := 1;
      End;
    End;
  End;


Procedure SBCfgObj.SetMsgAllowAnon(Area: Word; Anon: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Anon Then
      SBCfg^.BoardRec[Area].Aliases := 2
    Else
      If SBCfg^.BoardRec[Area].Aliases = 2 Then
        SBCfg^.BoardRec[Area].Aliases := 0;
    End;
  End;



Function SBCfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowHdl := (SBCfg^.BoardRec[Area].Aliases <> 0)
  Else
    MsgAllowHdl := False;
  End;


Function SBCfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows anonymous}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowAnon := (SBCfg^.BoardRec[Area].Aliases = 2)
  Else
    MsgAllowAnon := False;
  End;


Function SBCfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Begin
  MsgAddFido := True;
  End;



Procedure SBCfgObj.SetMsgAddFido(Area: Word; Fido: Boolean);
  Begin
  End;


Function SBCfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Begin
  MsgAllowAnsi := False;
  End;


Procedure SBCfgObj.SetMsgAllowAnsi(Area: Word; Ansi: Boolean);
  Begin
  End;


Function SBCfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Begin
  MsgAllowHiBit := False;
  End;


Procedure SBCfgObj.SetMsgAllowHiBit(Area: Word; HiBit: Boolean);
  Begin
  End;


Function SBCfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Begin
  Case SBExtra^.QwkAllowTagLines of
    0: MsgAllowTag := False;
    1: MsgAllowTag := True;
    2: MsgAllowTag := GetMsgType(Area) = Normal;
    End;
  End;


Procedure SBCfgObj.SetMsgAllowTag(Area: Word; Tag: Boolean);
  Begin
  End;


Function SBCfgObj.GetMsgReaderTear(Area: Word): Boolean;
  Begin
  GetMsgReaderTear := False;
  End;


Procedure SBCfgObj.SetMsgReaderTear(Area: Word; RT: Boolean);
  Begin
  End;


Function SBCfgObj.GetMsgReaderOrig(Area: Word): Boolean;
  Begin
  GetMsgReaderOrig := False;
  End;


Procedure SBCfgObj.SetMsgReaderOrig(Area: Word; RT: Boolean);
  Begin
  End;


Function SBCfgObj.GetMsgFAttach(Area: Word): Boolean;
  Begin
  GetMsgFAttach := False;
  End;


Procedure SBCfgObj.SetMsgFAttach(Area: Word; FA: Boolean);
  Begin
  End;


Function SBCfgObj.GetMsgSelect(Area: Word): String;
  Begin
  GetMsgSelect := '';
  End;


Procedure SBCfgObj.SetMsgSelect(Area: Word; Sel: String);
  Begin
  End;



Function SBCfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  GetMaxFileAreas := CfgInfo^.FileAreas;
  End;


Function SBCfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    GetFileAreaName := SBFile^[Area].Name
  Else
    GetFileAreaName := '';
  End;


Procedure SBCfgObj.SetFileAreaName(Area: Word; Name: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    SBFile^[Area].Name := Name;
  End;


Function SBCfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileShortName := Copy(GetFileAreaName(Area),1,12)
  Else
    GetFileShortName := '';
  End;


Procedure SBCfgObj.SetFileShortName(Area: Word; Nm: String);
  Begin
  End;


Function SBCfgObj.GetFileSelect(Area: Word): String;
  Begin
  GetFileSelect := '';
  End;


Procedure SBCfgObj.SetFileSelect(Area: Word; SN: String);
  Begin
  End;


Function SBCfgObj.GetFileAreaPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <=GetMaxFileAreas)) Then
    Begin
    TmpStr := SBFile^[Area].Directory;
    AddBackSlash(TmpStr);
    GetFileAreaPath := TmpStr;
    End
  Else
    GetFileAreaPath := '';
  End;


Procedure SBCfgObj.SetFileAreaPath(Area: Word; FPath: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    SBFile^[Area].Directory := FPath;
  End;


Function SBCfgObj.GetFileListPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    If (Length(SBFile^[Area].ListName) > 0) Then
      TmpStr := SBFile^[Area].ListName
    Else
      Begin
      TmpStr := SBFile^[Area].Directory;
      AddBackSlash(TmpStr);
      TmpStr := TmpStr + 'FILES.BBS';
      End;
    GetFileListPath := TmpStr;
    End
  Else
    GetFileListPath := '';
  End;


Procedure SBCfgObj.GetFileViewSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := SBFile^[Area].Security;
    Sec.Flags := LongInt(SBFile^[Area].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure SBCfgObj.SetFileViewSecurity(Area: Word; Var Sec: SecType);
  Begin
  End;


Procedure SBCfgObj.GetFileDLSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := SBFile^[Area].Security;
    Sec.Flags := LongInt(SBFile^[Area].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure SBCfgObj.SetFileDLSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    SBFile^[Area].Security := Sec.Level;
    SBFile^[Area].Flags := SBFlagType(Sec.Flags);
    End;
  End;


Procedure SBCfgObj.GetFileULSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := SBFile^[Area].Security;
    Sec.Flags := LongInt(SBFile^[Area].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure SBCfgObj.SetFileULSecurity(Area: Word; Var Sec: SecType);
  Begin
  End;


Procedure SBCfgObj.GetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private files security}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := SBFile^[Area].PFilesSec;
    Sec.Flags := LongInt(SBFile^[Area].PFlags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Procedure SBCfgObj.SetFilePvtSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (area <= GetMaxFileAreas)) Then
    Begin
    SBFile^[Area].PFilesSec := Sec.Level;
    SBFile^[Area].PFlags := SBFlagType(Sec.Flags);
    End;
  End;


Function SBCfgObj.GetFileNoUl(Area: Word): Boolean; {Area disallows ULs}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoUl := (SBFile^[Area].Attrib and 2) <> 0
  Else
    GetFileNoUl := True;
  End;


Function SBCfgObj.GetFileNoNew(Area: Word): Boolean; {Exclude area from new files}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    Begin
    GetFileNoNew := (SBFile^[Area].Attrib and 32) <> 0;
    End
  Else
    GetFileNoNew := True;
  End;


Function SBCfgObj.GetFileFree(Area: Word): Boolean; {Area contains free files}
  Begin
  GetFileFree := False;
  End;


Function SBCfgObj.GetFileNoTime(Area: Word): Boolean; {Ignore time remaining}
  Begin
  GetFileNoTime := False;
  End;


Function SBCfgObj.GetFileNoBaud(Area: Word): Boolean; {Ignore min baud limits}
  Begin
  GetFileNoBaud := False;
  End;


Procedure SBCfgObj.SetFileNoUl(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    Begin
    If St Then
      SBFile^[Area].Attrib := SBFile^[Area].Attrib or 1
    Else
      SBFile^[Area].Attrib := SBFile^[Area].Attrib and (Not 1);
    End
  End;


Procedure SBCfgObj.SetFileNoNew(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    Begin
    If St Then
      SBFile^[Area].Attrib := SBFile^[Area].Attrib or 32
    Else
      SBFile^[Area].Attrib := SBFile^[Area].Attrib and (Not 32);
    End
  End;




Procedure SBCfgObj.SetFileFree(Area: Word; St: Boolean);
  Begin
  End;


Procedure SBCfgObj.SetFileNoTime(Area: Word; St: Boolean);
  Begin
  End;


Procedure SBCfgObj.SetFileNoBaud(Area: Word; St: Boolean);
  Begin
  End;



Function SBCfgObj.FileViewAccess(Area: Word; Sec: SecType): Boolean; {Can view files}
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


Function SBCfgObj.FileDLAccess(Area: Word; Sec: SecType): Boolean; {Can download files}
  Var
    AreaSec: SecType;

  Begin
  GetFileDLSecurity(Area, AreaSec);
  FileDLAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileDLAccess := False;
  End;


Function SBCfgObj.FileULAccess(Area: Word; Sec: SecType): Boolean; {Can upload files}
  Var
    AreaSec: SecType;

  Begin
  GetFileULSecurity(Area, AreaSec);
  FileULAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileULAccess := False;
  End;


Function SBCfgObj.FilePvtAccess(Area: Word; Sec: SecType): Boolean; {Private files}
  Var
    AreaSec: SecType;

  Begin
  GetFilePvtSecurity(Area, AreaSec);
  FilePvtAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FilePvtAccess := False;
  End;


Function SBCfgObj.GetLangQuesPath(LNum: Word): String;
  Begin
  GetLangQuesPath := GetBbsPath;
  End;


Procedure SBCfgObj.SetLangQuesPath(LNum: Word; QPath: String);
  Begin
  End;


Function SBCfgObj.GetAskVoicePhone: Boolean;
  Begin
  GetAskVoicePhone := SBCfg^.AskHomePhone;
  End;


Procedure SBCfgObj.SetAskVoicePhone(VP: Boolean);
  Begin
  SBCfg^.AskHomePhone := VP;
  End;


Function SBCfgObj.GetAskDataPhone: Boolean;
  Begin
  GetAskDataPhone := SBCfg^.AskDataPhone;
  End;


Procedure SBCfgObj.SetAskDataPhone(DP: Boolean);
  Begin
  SBCfg^.AskDataPhone := DP;
  End;


Function SBCfgObj.GetNewUserNMCredit: Word;
  Begin
  GetNewUserNMCredit := SBCfg^.DefaultCredit;
  End;


Procedure SBCfgObj.SetNewUserNMCredit(NM: Word);
  Begin
  SBCfg^.DefaultCredit := NM;
  End;


Function SBCfgObj.GetAskBirthdate: Boolean;
  Begin
  GetAskBirthdate := Not SBExtra^.NoBirthdayAsk;
  End;


Procedure SBCfgObj.SetAskBirthdate(AB: Boolean);
  Begin
  SBExtra^.NoBirthdayAsk := Not AB;
  End;


Function SBCfgObj.GetAskGender: Boolean;
  Begin
  GetAskGender := SBExtra^.AskSex;
  End;


Procedure SBCfgObj.SetAskGender(AG: Boolean);
  Begin
  SBExtra^.AskSex := AG;
  End;


Function SBCfgObj.GetAskAddr: Boolean;
  Begin
  GetAskAddr := False;
  End;


Procedure SBCfgObj.SetAskAddr(AA: Boolean);
  Begin
  End;


Function SBCfgObj.GetSevenBitNames: Boolean;
  Begin
  GetSevenBitNames := False;
  End;


Procedure SBCfgObj.SetSevenBitNames (SB: Boolean);
  Begin
  End;


Function SBCfgObj.GetOneWordName: Boolean;
  Begin
  GetOneWordName := SBCfg^.OneWordNames;
  End;


Procedure SBCfgObj.SetOneWordName(OW: Boolean);
  Begin
  SBCfg^.OneWordNames := OW;
  End;


Function SBCfgObj.GetReAsk: Boolean;
  Begin
  GetReAsk := False;
  End;


Procedure SBCfgObj.SetReAsk(RA: Boolean);
  Begin
  End;


Function SBCfgObj.GetAskHandle: Boolean; {Ask user for handle}
  Begin
  GetAskHandle := False;
  End;


Procedure SBCfgObj.SetAskHandle(AH: Boolean); {Set ask user for handle}
  Begin
  End;


Procedure SBCfgObj.GetEchoToAddr(ES: Word; Var Addr: AddrType);
  Begin
  Addr.Zone := 0;
  Addr.Net := 0;
  Addr.Node := 0;
  Addr.Point := 0;
  End;


Procedure SBCfgObj.SetEchoToAddr(ES: Word; Addr: AddrType);
  Begin
  End;


Function SBCfgObj.GetEchoToPwd(ES: Word): String;
  Begin
  GetEchoToPwd := '';
  End;


Procedure SBCfgObj.SetEchoToPwd(ES: Word; Pwd: String);
  Begin
  End;


Function SBCfgObj.GetEchoToPacker(ES: Word): Byte;
  Begin
  GetEchoToPacker := 1;
  End;


Procedure SBCfgObj.SetEchoToPacker(ES: Word; Pk: Byte);
  Begin
  End;


Function SBCfgObj.GetEchoToNetwork(ES: Word; Nt: Word): Boolean;
  Begin
  GetEchoToNetwork := False;
  End;


Procedure SBCfgObj.SetEchoToNetwork(ES: Word; Nt: Word; St: Boolean);
  Begin
  End;


Function SBCfgObj.GetEchoToMailType(ES: Word): Byte;
  Begin
  GetEchoToMailType := 2;
  End;


Procedure SBCfgObj.SetEchoToMailType(ES: Word; MT: Byte);
  Begin
  End;


Function SBCfgObj.GetEchoToArea(ES: Word; Area: Word): Boolean;
  Begin
  GetEchoToArea := False;
  End;


Procedure SBCfgObj.SetEchoToArea(ES: Word; Area: Word; SA: Boolean);
  Begin
  End;


Function SBCfgObj.GetEchoAreaPassThru(Area: Word): Boolean;
  Begin
  GetEchoAreaPassThru := False;
  End;


Procedure SBCfgObj.SetEchoAreaPassThru(Area: Word; PT: Boolean);
  Begin
  End;


Function SBCfgObj.GetEchoAreaImportPath(Area: Word): Boolean;
  Begin
  GetEchoAreaImportPath := True;
  End;


Procedure SBCfgObj.SetEchoAreaImportPath(Area: Word; IP: Boolean);
  Begin
  End;


Function SBCfgObj.GetEchoAreaHidePath(Area: Word): Boolean;
  Begin
  GetEchoAreaHidePath := True;
  End;


Procedure SBCfgObj.SetEchoAreaHidePath(Area: Word; HP: Boolean);
  Begin
  End;


Function SBCfgObj.GetEchoAreaImportSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaImportSeen := False;
  End;


Procedure SBCfgObj.SetEchoAreaImportSeen(Area: Word; ISB: Boolean);
  Begin
  End;


Function SBCfgObj.GetEchoAreaHideSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaHideSeen := True;
  End;


Procedure SBCfgObj.SetEchoAreaHideSeen(Area: Word; HS: Boolean);
  Begin
  End;


Function SBCfgObj.GetEchoToHub(Area: Word): Byte;
  Begin
  GetEchoToHub := 1;
  End;


Procedure SBCfgObj.SetEchoToHub(Area: Word; Hub: Byte);
  Begin
  End;


Function SBCfgObj.GetEchoMaxPkt: LongInt;
  Begin
  GetEchoMaxPkt := 100000;
  End;


Procedure SBCfgObj.SetEchoMaxPkt(MP: LongInt);
  Begin
  End;


Function SBCfgObj.GetEchoInPath: String;
  Begin
  GetEchoInPath := '';
  End;


Procedure SBCfgObj.SetEchoInPath(EP: String);
  Begin
  End;


Function SBCfgObj.GetEchoOutPath: String;
  Begin
  GetEchoOutPath := '';
  End;


Procedure SBCfgObj.SetEchoOutPath(EP: String);
  Begin
  End;


Function SBCfgObj.GetEchoAreaTag(Area: Word): String;
  Begin
  GetEchoAreaTag := '';
  End;


Procedure SBCfgObj.SetEchoAreaTag(Area: Word; Tag: String);
  Begin
  End;


Function SBCfgObj.GetPwdTries: Byte;
  Begin
  GetPwdTries := SBCfg^.PasswordTries;
  End;


Procedure SBCfgObj.SetPwdTries(PT: Byte);
  Begin
  SBCfg^.PasswordTries := PT;
  End;


Function SBCfgObj.GetPwdExpire: Word;
  Begin
  GetPwdExpire := 0;
  End;


Procedure SBCfgObj.SetPwdExpire(PE: Word);
  Begin
  End;


Function SBCfgObj.GetBDCheck: Byte;
  Begin
  GetBDCheck := 0;
  End;


Procedure SBCfgObj.SetBDCheck(BD: Byte);
  Begin
  End;


Function SBCfgObj.GetPhoneCheck: Byte;
  Begin
  GetPhoneCheck := 0;
  End;


Procedure SBCfgObj.SetPhoneCheck(PC: Byte);
  Begin
  End;


Function SBCfgObj.GetMinPwd: Byte;
  Begin
  GetMinPwd := 3;
  End;


Procedure SBCfgObj.SetMinPwd(MP: Byte);
  Begin
  End;


Function SBCfgObj.GetMinPhone: Byte;
  Begin
  GetMinPhone := 7;
  End;


Procedure SBCfgObj.SetMinPhone(MP: Byte);
  Begin
  End;


Function SBCfgObj.GetStrictPwd: Boolean;
  Begin
  GetStrictPwd := False;
  End;


Procedure SBCfgObj.SetStrictPwd(SP: Boolean);
  Begin
  End;


Function SBCfgObj.GetRemoteSysop: Boolean;
  Begin
  GetRemoteSysop := True;
  End;


Procedure SBCfgObj.SetRemoteSysop(RS: Boolean);
  Begin
  End;


Function SBCfgObj.GetFastLocal: Boolean;
  Begin
  GetFastLocal := SBCfg^.FastLogOn;
  End;


Procedure SBCfgObj.SetFastLocal(FL: Boolean);
  Begin
  SBCfg^.FastLogOn := FL;
  End;


Procedure SBCfgObj.GetNewUserSec(Var Sec: SecType);
  Begin
  Sec.Level := SBCfg^.DefaultSec;
  Sec.Flags := LongInt(SBCfg^.DefaultFlags);
  End;


Procedure SBCfgObj.SetNewUserSec(Sec: SecType);
  Begin
  SBCfg^.DefaultSec := Sec.Level;
  SBCfg^.DefaultFlags := SBFlagType(Sec.Flags);
  End;


Procedure SBCfgObj.GetAttachSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure SBCfgObj.SetAttachSec(Sec: SecType);
  Begin
  End;


Procedure SBCfgObj.GetRequestSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure SBCfgObj.SetRequestSec(Sec: SecType);
  Begin
  End;


Procedure SBCfgObj.GetCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure SBCfgObj.SetCrashNmSec(Sec: SecType);
  Begin
  End;


Procedure SBCfgObj.GetForceCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure SBCfgObj.SetForceCrashNmSec(Sec: SecType);
  Begin
  End;


Procedure SBCfgObj.GetDeleteSec(Var Sec: SecType);
  Begin
  If SBCfg^.AllowDelMsgs Then
    Begin
    Sec.Level := 1;
    Sec.Flags := 0;
    End
  Else
    Begin
    Sec.Level := $ffff;
    Sec.Flags := $ffffffff;
    End;
  End;


Procedure SBCfgObj.SetDeleteSec(Sec: SecType);
  Begin
  End;


Procedure SBCfgObj.GetUnRcvSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure SBCfgObj.SetUnRcvSec(Sec: SecType);
  Begin
  End;


Function SBCfgObj.GetModemResp(MR: Byte): String;
  Begin
  Case MR of
         2: GetModemResp := SBCfg^.Resp300;
         3: GetModemResp := SBCfg^.Resp1200;
         4: GetModemResp := SBCfg^.Resp2400;
         5: GetModemResp := SBCfg^.Resp4800;
         7: GetModemResp := SBCfg^.Resp9600;
         10: GetModemResp := SBExtra^.Resp19200;
         11: GetModemResp := SBExtra^.Resp38400;
         Else
           GetModemResp := '';
         End;
  End;


Procedure SBCfgObj.SetModemResp(MR: Byte; Resp: String);
  Begin
  Case MR of
         2: SBCfg^.Resp300 := Resp;
         3: SBCfg^.Resp1200 := Resp;
         4: SBCfg^.Resp2400 := Resp;
         5: SBCfg^.Resp4800 := Resp;
         7: SBCfg^.Resp9600 := Resp;
         10: SBExtra^.Resp19200 := Resp;
         11: SBExtra^.Resp38400 := Resp;
         End;
  End;


Function SBCfgObj.GetErrorLevel(MR: Byte): Byte;
  Begin
  GetErrorLevel := 0;
  End;


Procedure SBCfgObj.SetErrorLevel(MR: Byte; EL: Byte);
  Begin
  End;


Function SBCfgObj.GetDLStart: Word;
  Begin
  GetDLStart := TimeStr2Word(SBCfg^.DownloadStart);
  End;


Procedure SBCfgObj.SetDLStart(ST: Word);
  Begin
  SBCfg^.DownLoadStart := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
         PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function SBCfgObj.GetDLStop: Word;
  Begin
  GetDLStop := TimeStr2Word(SBCfg^.DownloadEnd);
  End;


Procedure SBCfgObj.SetDLStop(ST: Word);
  Begin
  SBCfg^.DownLoadEnd := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
         PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function SBCfgObj.GetLoBaudStart: Word;
  Begin
  GetLoBaudStart := TimeStr2Word(SBCfg^.LowBaudStart);
  End;


Procedure SBCfgObj.SetLoBaudStart(ST: Word);
  Begin
  SBCfg^.LowBaudStart := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
         PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function SBCfgObj.GetLoBaudStop: Word;
  Begin
  GetLoBaudStop := TimeStr2Word(SBCfg^.LowBaudEnd);
  End;


Procedure SBCfgObj.SetLoBaudStop(ST: Word);
  Begin
  SBCfg^.LowBaudEnd := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
         PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function SBCfgObj.GetMinXferBaud: Word;
  Begin
  GetMinXferBaud := SBCfg^.XferBaud;
  End;


Procedure SBCfgObj.SEtMinXferBaud(MB: Word);
  Begin
  SBCfg^.XferBaud := MB;
  End;


Function SBCfgObj.GetULCredit: Integer;
  Begin
  GetULCredit := SBCfg^.UploadCredit;
  End;


Procedure SBCfgObj.SetULCredit(UC: Integer);
  Begin
  SBCfg^.UploadCredit := UC;
  End;


Function SBCfgObj.GetMinDesc: Byte;
  Begin
  GetMinDesc := 10;
  End;


Procedure SBCfgObj.SetMinDesc(MD: Byte);
  Begin
  End;


Function SBCfgObj.GetMaxDesc: Byte;
  Begin
  GetMaxDesc := 240;
  End;


Procedure SBCfgObj.SetMaxDesc(MD: Byte);
  Begin
  End;


Function SBCfgObj.GetMinFree: LongInt;
  Begin
  GetMinFree := LongInt(SBExtra^.MinSpace) * 1024;
  End;


Procedure SBCfgObj.SetMinFree(MF: LongInt);
  Begin
  SBExtra^.MinSpace := MF Div 1024;
  End;


Function SBCfgObj.GetAskNewFiles: Boolean;
  Begin
  GetAskNewFiles := False;
  End;


Procedure SBCfgObj.SetAskNewFiles(AN: Boolean);
  Begin
  End;


Function SBCfgObj.GetForceNewFiles: Boolean;
  Begin
  GetForceNewFiles := False;
  End;


Procedure SBCfgObj.SetForceNewFiles(AN: Boolean);
  Begin
  End;


Function SBCfgObj.GetMaxEvents: Word;
  Begin
  GetMaxEvents := 30;
  End;


Function SBCfgObj.GetEventStatus(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventStatus := Byte(SBCfg^.EventRec[EN].Status)
  Else
    GetEventStatus := 0;
  End;



Procedure SBCfgObj.SetEventStatus(EN: Word; ES: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    SBCfg^.EventRec[EN].Status := ES;
  End;



Function SBCfgObj.GetEventTime(EN: Word): Word;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventTime := TimeStr2Word(SBCfg^.EventRec[EN].RunTime)
  Else
    GetEventTime := 0;
  End;


Procedure SBCfgObj.SetEventTime(EN: Word; ET: Word);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    SBCfg^.EventRec[EN].RunTime := Word2TimeStr(ET);
  End;


Function SBCfgObj.GetEventEL(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventEL := SBCfg^.EventRec[EN].ErrorLevel
  Else
    GetEventEL := 0;
  End;


Procedure SBCfgObj.SetEventEL(EN: Word; EL: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    SBCfg^.EventRec[EN].ErrorLevel := EL;
  End;


Function SBCfgObj.GetEventDays(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventDays := SBCfg^.EventRec[EN].Days
  Else
    GetEventDays := 0;
  End;


Procedure SBCfgObj.SetEventDays(EN: Word; ED: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    SBCfg^.EventRec[EN].Days := ED;
  End;


Function SBCfgObj.GetEventOnDay(EN: Word; OD: Byte): Boolean;
  Begin
  GetEventOnDay := (GetEventDays(EN) and (1 shl (OD -1))) <> 0;
  End;


Procedure SBCfgObj.SetEventOnDay(EN: Word; OD: Byte; ST: Boolean);
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



Function SBCfgObj.GetEventForced(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventForced := SBCfg^.EventRec[EN].Forced
  Else
    GetEventForced := 0;
  End;


Procedure SBCfgObj.SetEventForced(EN: Word; EF: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    SBCfg^.EventRec[EN].Forced := EF;
  End;


Function SBCfgObj.GetDoorData(DN: Word): String;
  Begin
  GetDoorData := '';
  End;


Procedure SBCfgObj.SetDoorData(DN: Word; DD: String);
  Begin
  End;


Procedure SBCfgObj.GetDoorSec(DN: Word; Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure SBCfgObj.SetDoorSec(DN: Word; Sec: SecType);
  Begin
  End;


Function SBCfgObj.DoorAccess(DN: Word; Sec: SecType): Boolean;
  Begin
  DoorAccess := False;
  End;


Function SBCfgObj.GetProtNormAvail(PN: Word): Boolean;
  Begin
  Case PN Of
         1: GetProtNormAvail := SBCfg^.Use_Xmodem;
         2: GetProtNormAvail := SBCfg^.Use_Xmodem1k;
         3: GetProtNormAvail := SBCfg^.Use_Ymodem;
         4: GetProtNormAvail := SBCfg^.Use_Zmodem;
         5: GetProtNormAvail := SBCfg^.Use_YmodemG;
         7: GetProtNormAvail := SBCfg^.Use_Sealink;
         Else
           GetProtNormAvail := False;
         End;
  End;


Function SBCfgObj.GetProtSpecAvail(PN: Word): Boolean;
  Begin
  Case PN Of
         1: GetProtSpecAvail := SBCfg^.Use_Xmodem;
         2: GetProtSpecAvail := SBCfg^.Use_Xmodem1k;
         3: GetProtSpecAvail := SBCfg^.Use_Ymodem;
         4: GetProtSpecAvail := SBCfg^.Use_Zmodem;
         5: GetProtSpecAvail := SBCfg^.Use_YmodemG;
         7: GetProtSpecAvail := SBCfg^.Use_Sealink;
         Else
           GetProtSpecAvail := False;
         End;
  End;


Function SBCfgObj.GetProtChar(PN: Word): Char;
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


Function SBCfgObj.GetProtName(PN: Word): String;
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


Procedure SBCfgObj.SetProtNormAvail(PN: Word; PA: Boolean);
  Begin
    Case PN Of
         1: SBCfg^.Use_Xmodem := Pa;
         2: SBCfg^.Use_Xmodem1k := Pa;
         3: SBCfg^.Use_Ymodem := Pa;
         4: SBCfg^.Use_Zmodem := Pa;
         5: SBCfg^.Use_YmodemG := Pa;
         7: SBCfg^.Use_Sealink := Pa;
         End;
  End;


Procedure SBCfgObj.SetProtSpecAvail(PN: Word; PA: Boolean);
  Begin
  End;


Procedure SBCfgObj.SetProtChar(PN: Word; PC: Char);
  Begin
  End;


Procedure SBCfgObj.SetProtName(PN: Word; Name: String);
  Begin
  End;


Function SBCfgObj.GetLogLevel: Byte; {Get level of logging}
  Begin
  GetLogLevel := 1;
  End;


Procedure SBCfgObj.SetLogLevel(LL: Byte); {Set level of logging}
  Begin
  End;


Function SBCfgObj.GetLogStyle: Byte; {Get style of log file}
  Begin
  GetLogStyle := 2;
  End;


Procedure SBCfgObj.SetLogStyle(LS: Byte); {Set style of log file}
  Begin
  End;


Function SbCfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  GetDefaultPort := SBCfg^.CommPort;
  End;


Procedure SbCfgObj.SetDefaultPort(DP: Word); {Set default comm port}
  Begin
  SBCfg^.CommPort := DP;
  End;


Function SbCfgObj.GetMsgPathNum(Area: Word): Word;
  Begin
  GetMsgPathNum := 1;
  End;


Procedure SbCfgObj.SetMsgPathNum(Area: Word; PN: Word);
  Begin
  End;


Function SbCfgObj.GetMsgBaseType(Area: Word): Char;
  Begin
  GetMsgBaseType := 'H';
  End;


Procedure SbCfgObj.SetMsgBaseType(Area: Word; BT: Char);
  Begin
  End;


Function SbCfgObj.GetMsgAreaId(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas) and
  (Length(GetMsgName(Area)) > 0)) Then
    GetMsgAreaId := 'H' + PadLeft(Long2Str(Area),'0',3) + GetMsgPath(1)
  Else
    GetMsgAreaId := '';
  End;


Function SbCfgObj.GetNodeIdxName: String;
  Begin
  GetNodeIdxName := 'NodeIdx.Sbs';
  End;


Function SbCfgObj.GetNodeIncName: String;
  Begin
  GetNodeIncName := 'NodeInc.Sbs';
  End;


End.
