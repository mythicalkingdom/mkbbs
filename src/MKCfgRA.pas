{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKCfgRA;


{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKCfgAbs,
  Dos;

{$I Struct.RA}

Type RaMsgCfgType = Array[1..200] of RAMessageRecord;
Type RaFileCfgType = Array[1..200] of RaFilesRecord;

Type RACfgObj = Object(CfgObj)
  RaCfg:    ^RaConfigRecord;
  RaMsg:    ^RaMsgCfgType;
  RaFile:   ^RaFileCfgType;
  RaEvent:  ^RAEventRecordArray;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure RALoad; Virtual;{Normally internal to load RA config}
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Procedure Save; Virtual;{Save Bbs config info}
  Function  SaveFileName(FN: String): String; Virtual;
  Function  SaveFileNames: String; Virtual;
  Procedure RASave; Virtual; {Normally internal to save RA config}
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
  Function  GetPrnName: String; Virtual; {Get printer name}
  Procedure SetPrnName(PN: String); Virtual; {Set printer name}
  End;

Type RACfgObjPtr = ^RACfgObj;


Implementation


Uses MKString;


Function RACfgObj.GetMsgPath(BaseNo: Word): String;
  Begin
  If BaseNo = 1 Then
    GetMsgPath := RaCfg^.MsgBasePath
  Else
   GetMsgPath := '';
  End;


Procedure RACfgObj.SetMsgPath(BaseNo: Word; MPath: String);
  Begin
  If BaseNo = 1 Then
    RaCfg^.MsgBasePath := MPath;
  End;


Function RACfgObj.GetTxtPath(Num:Word): String; {Get path to asc/ans/avt files}
  Begin
  GetTxtPath := RaCfg^.TextPath;
  End;


Procedure RACfgObj.SetTxtPath(Num: Word; TPath: String);
  Begin
  If Num = 1 Then
    RaCfg^.TextPath := TPath;
  End;


Function RACfgObj.GetMnuPath(Num: Word): String; {Get path to menu *.mnu files}
  Begin
  GetMnuPath := RaCfg^.MenuPath;
  End;


Procedure RACfgObj.SetMnuPath(Num: Word; MPath: String);
  Begin
  If Num = 1 Then
    RaCfg^.MenuPath := MPath;
  End;


Function RACfgObj.GetNetPath: String;
  Begin
  GetNetPath := '';
  End;


Procedure RACfgObj.SetNetPath(NP: String);
  Begin
  End;


Function RACfgObj.GetTempPath: String;
  Begin
  GetTempPath := '';
  End;


Procedure RACfgObj.SetTempPath(TP: String);
  Begin
  End;


Function RACfgObj.GetLogFileName: String;
  Begin
  GetLogFileName := RaCfg^.LogFileName;
  End;


Procedure RACfgObj.SetLogFileName(LN: String);
  Begin
  RaCfg^.LogFileName := Copy(LN, 1, 60);
  End;


Function RACfgObj.GetEditCmdPath: String;
  Begin
  GetEditCmdPath := RaCfg^.ExternalEdCmd;
  End;


Procedure RACfgObj.SetEditCmdPath(EC: String);
  Begin
  RaCfg^.ExternalEdCmd := Copy(EC, 1, 60);
  End;


Function RACfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := RaCfg^.NodeListPath;
  End;


Procedure RACfgObj.SetNodeListPath(NP: String);
  Begin
  RaCfg^.NodeListPath := Copy(NP, 1, 60);
  End;


Function RACfgObj.GetAttachPath: String;
  Begin
  GetAttachPath := RaCfg^.AttachPath;
  End;


Procedure RACfgObj.SetAttachPath(AP: String);
  Begin
  RaCfg^.AttachPath := Copy(AP, 1, 60);
  End;


Function RACfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  GetSemaphorePath := RACfg^.SemPath;
  End;


Procedure RACfgObj.SetSemaphorePath(SP: String); {Set Semaphore file path}
  Begin
  RaCfg^.SemPath := Copy(SP, 1, 60);
  End;


Function RACfgObj.GetBbsType: Word;
  Begin
  GetBbsType := CfgInfo^.BbsType;
  End;


Procedure RACfgObj.SetBbsType(BT: Word);           {Set type of Bbs}
  Begin
  CfgInfo^.BbsType := BT;
  End;



Function RACfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := CfgInfo^.BbsPath;
  End;


Procedure RACfgObj.SetBbsPath(BPath: String);      {Set main Bbs Directory}
  Begin
  CfgInfo^.BbsPath := BPath;
  AddBackSlash(CfgInfo^.BbsPath);
  End;


Procedure RACfgObj.RALoad;
  Begin
  New(RaCfg);
  New(RaMsg);
  New(RaFile);
  New(RaEvent);
  Error := LoadFile(FindBbsFile('config.ra') + 'config.ra', RaCfg^, SizeOf(RaCfg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('messages.ra') + 'messages.ra', RaMsg^, SizeOf(RaMsg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('files.ra') + 'files.ra', RaFile^, SizeOf(RaFile^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('events.ra') + 'events.ra', RaEvent^, SizeOf(RaEvent^));
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(RaCfg);
    Dispose(RaMsg);
    Dispose(RaFile);
    Dispose(RaEvent);
    End;
  End;


Procedure RACfgObj.Allocate;
  Begin
  New(RaCfg);
  New(RaMsg);
  New(RaFile);
  New(RaEvent);
  FillChar(RACfg^, SizeOf(RACfg^), 0);
  FillChar(RAMsg^, SizeOf(RAMsg^), 0);
  FillChar(RAFile^, SizeOf(RAFile^), 0);
  FillChar(RAEvent^, SizeOf(RAEvent^), 0);
  CfgInfo^.BbsPath := GetEnv('RA');
  AddBackSlash(CfgInfo^.BbsPath);
  CfgInfo^.Loaded := True;
  End;


Procedure RACfgObj.Unload;
  Begin
  Dispose(RaCfg);
  Dispose(RaMsg);
  Dispose(RaFile);
  Dispose(RaEvent);
  CfgInfo^.Loaded := False;
  End;


Procedure RACfgObj.Load;
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


Procedure RACfgObj.Save;
  Begin
  RASave;
  End;


Function RACfgObj.SaveFileNames: String;
  Begin
  SaveFileNames := 'config.ra|messages.ra|files.ra|events.ra';
  End;


Function RACfgObj.SaveFileName(FN: String): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := FindBbsFile(FN);
  If Length(TmpStr) > 0 Then
    SaveFileName := TmpStr + FN
  Else
    SaveFileName := GetBbsPath + FN;
  End;


Procedure RACfgObj.RASave;
  Begin
  Error := SaveFile(SaveFileName('config.ra'), RACfg^, SizeOf(RACfg^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('messages.ra'), RaMsg^, SizeOf(RaMsg^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('files.ra'), RaFile^, SizeOf(RaFile^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('events.ra'), RaEvent^, SizeOf(RaEvent^));
  End;


Function RACfgObj.GetQuoteStr: String;
  Begin
  GetQuoteStr := RaCfg^.QuoteString;
  End;


Procedure RACfgObj.SetQuoteStr(Qt: String);
  Begin
  RaCfg^.QuoteString := Qt;
  End;


Function RACfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  GetMaxMsgAreas := 200;
  End;


Function RACfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgName := RAMsg^[Area].Name
  Else
    GetMsgName := '';
  End;



Function RACfgObj.GetMsgOrigStr(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Length(RAMsg^[Area].OriginLine) > 0 Then
      GetMsgOrigStr := RAMsg^[Area].OriginLine
    Else
      GetMsgOrigStr := RACfg^.OriginLine;
    End
  Else
    GetMsgOrigStr := '';
  End;


Function RACfgObj.GetOrigStr(OrigNum: Word): String;
  Begin
  If OrigNum = 1 Then
    GetOrigStr := RACfg^.OriginLine
  Else
    GetOrigStr := '';
  End;


Procedure RACfgObj.SetOrigStr(OrigNum: Word; OrigStr: String);
  Begin
  If OrigNum = 1 Then
    RACfg^.OriginLine := OrigStr;
  End;


Procedure RACfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
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


Procedure RACfgObj.SetAddr(Aka: Word; Addr: AddrType);
  Begin
  If ((Aka > 0) And (Aka < 11)) Then
    Begin
    RaCfg^.Address[Aka - 1].Zone := Addr.Zone;
    RaCfg^.Address[Aka - 1].Net := Addr.Net;
    RaCfg^.Address[Aka - 1].Node := Addr.Node;
    RaCfg^.Address[Aka - 1].Point := Addr.Point;
    End
  End;





Procedure RACfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MA.Zone := RACfg^.Address[RAMsg^[Area].AkaAddress].Zone;
    MA.Net := RACfg^.Address[RAMsg^[Area].AkaAddress].Net;
    MA.Node := RACfg^.Address[RAMsg^[Area].AkaAddress].Node;
    MA.Point := RACfg^.Address[RAMsg^[Area].AkaAddress].Point;
    End
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function RACfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Var
    Addr: AddrType;

  Begin
  GetMsgAddr(Area, Addr);
  GetMsgAddrStr := AddrStr(Addr);
  End;


Function RACfgObj.GetMsgAddrNum(Area: Word): Word;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAddrNum := RAMsg^[Area].AkaAddress + 1
  Else
    GetMsgAddrNum := 1;
  End;


Procedure RACfgObj.SetMsgAddrNum(Area: Word; AKA: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If ((Aka > 0) and (Aka < 11)) Then
      RAMsg^[Area].AkaAddress:= Aka - 1;
    End;
  End;


Function RACfgObj.GetMsgOrigNum(Area: Word): Word;
  Begin
  GetMsgOrigNum := 1;
  End;


Procedure RACfgObj.SetMsgOrigNum(Area: Word; Orig: Word);
  Begin
  End;


Function RaCfgObj.GetMsgPathNum(Area: Word): Word;
  Begin
  GetMsgPathNum := 1;
  End;


Procedure RaCfgObj.SetMsgPathNum(Area: Word; PN: Word);
  Begin
  End;


Function RaCfgObj.GetMsgBaseType(Area: Word): Char;
  Begin
  GetMsgBaseType := 'H';
  End;


Procedure RaCfgObj.SetMsgBaseType(Area: Word; BT: Char);
  Begin
  End;


Function RaCfgObj.GetMsgAreaId(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas) and
  (Length(GetMsgName(Area)) > 0)) Then
    GetMsgAreaId := 'H' + PadLeft(Long2Str(Area),'0',3) + GetMsgPath(1)
  Else
    GetMsgAreaId := '';
  End;


Function RACfgObj.GetMsgAllowOffline(Area: Word): Boolean;
  Begin
  GetMsgAllowOffline := True;
  End;



Procedure RACfgObj.SetMsgAllowOffline(Area: Word; AO: Boolean);
  Begin
  End;


Function RACfgObj.GetMsgForceOffline(Area: Word): Boolean;
  Begin
  GetMsgForceOffline := False;
  End;



Procedure RACfgObj.SetMsgForceOffline(Area: Word; FO: Boolean);
  Begin
  End;


Function RACfgObj.GetMsgAllowCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAllowCombined := (RAMsg^[Area].Attribute and 2) <> 0
  Else
    GetMsgAllowCombined := False;
  End;


Procedure RACfgObj.SetMsgAllowCombined(Area: Word; AC: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Ac Then
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute or 2
    Else
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute and (not 2);
    End;
  End;


Function RACfgObj.GetMsgDefCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    GetMsgDefCombined := (RACfg^.DefaultCombined[(Area + 7) Div 8] and
      (1 shl ((Area + 7) Mod 8))) <> 0;
    End
  Else
    GetMsgDefCombined := False;
  End;


Procedure RACfgObj.SetMsgDefCombined(Area: Word; DC: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    If DC Then
      RaCfg^.DefaultCombined[(Area + 7) Div 8] :=
      (RACfg^.DefaultCombined[(Area + 7) Div 8] or
      (1 shl ((Area + 7) Mod 8)))
    Else
      RaCfg^.DefaultCombined[(Area + 7) Div 8] :=
      (RACfg^.DefaultCombined[(Area + 7) Div 8] and
      (Not (1 shl ((Area + 7) Mod 8))));
    End;
  End;


Function RACfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;


Procedure RACfgObj.SetMsgName(Area: Word; Name: String); {Set message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    RAMsg^[Area].Name := Name;
  End;


Function RACfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgShortName := Copy(RAMsg^[Area].Name,1,12)
  Else
    GetMsgShortName := '';
  End;


Procedure RACfgObj.SetMsgShortName(Area: Word; Name: String);
  Begin
  End;


Function RACfgObj.GetMsgNetwork(Area: Word; Net: Byte): Boolean;
  Begin
  GetMsgNetwork := False;
  End;


Procedure RACfgObj.SetMsgNetwork(Area: Word; Net: Byte; MN: Boolean);
  Begin
  End;




Function RACfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case RAMsg^[Area].Typ Of
      RALocalMail: GetMsgType := Normal;
      RANetMail: GetMsgType := NetMail;
      RAEchoMail: GetMsgType := EchoMail;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Procedure RACfgObj.SetMsgType(Area: Word; MT: MailType); {Set type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case MT of
      Normal: RAMsg^[Area].Typ := RALocalMail;
      NetMail: RAMsg^[Area].Typ := RANetMail;
      EchoMail: RAMsg^[Area].Typ := RAEchoMail;
      End;
    End;
  End;


Function RACfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgWriteSecurity(Area, AreaSec);
  MsgWriteAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgWriteAccess := False;
  End;


Function RACfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgReadSecurity(Area, AreaSec);
  MsgReadAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgReadAccess := False;
  End;


Function RACfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgSysopSecurity(Area, AreaSec);
  MsgSysopAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgSysopAccess := False;
  End;


Function RACfgObj.MsgDeleteAccess(Sec: SecType): Boolean;
  Begin
  MsgDeleteAccess := False;
  End;


Function RACfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;
  Begin
  MsgUnRecvAccess := False;
  End;


Function RACfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetMsgDays := RAMsg^[Area].DaysKill
  Else
    GetMsgDays := 7;
  End;


Function RACfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgRcvdDays := RAMsg^[Area].RecvKill
  Else
    GetMsgRcvdDays := 2;
  End;


Function RACfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgsKept := RAMsg^[Area].CountKill
  Else
    GetMsgsKept := 200;
  End;


Procedure RACfgObj.SetMsgDays(Area: Word; Days: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    RAMsg^[Area].DaysKill := Days;
  End;


Procedure RACfgObj.SetMsgRcvdDays(Area: Word; Days: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    RAMsg^[Area].RecvKill := Days;
  End;


Procedure RACfgObj.SetMsgsKept(Area: Word; Msgs: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    RAMsg^[Area].CountKill := Msgs;
  End;


Function RACfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  GetSysopName := RACfg^.Sysop;
  End;


Procedure RACfgObj.SetSysopName(Sysop: String);
  Begin
  RACfg^.Sysop := Proper(Copy(Sysop, 1, 35));
  End;


Function RACfgObj.GetSystemColor(Num: Byte): Byte; {Get system color attribute}
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


Procedure RACfgObj.SetSystemColor(Num: Byte; Color: Byte);
  Begin
  End;



Function RACfgObj.GetBbsName: String;
  Begin
  GetBbsName := RACfg^.SystemName;
  End;


Procedure RACfgObj.SetBbsName(BN: String);
  Begin
  RACfg^.SystemName := Copy(BN, 1, 30);
  End;


Function RACfgObj.GetBbsLoc: String;
  Begin
  GetBbsLoc := RACfg^.Location;
  End;


Procedure RACfgObj.SetBbsLoc(BL: String);
  Begin
  RACfg^.Location := Copy(BL, 1, 40);
  End;


Function RACfgObj.GetBbsPhone: String;
  Begin
  GetBbsPhone := '';
  End;


Procedure RACfgObj.SetBbsPhone(BPhone: String);
  Begin
  End;


Function RACfgObj.GetBbsId: String;
  Begin
  GetBbsId := '';
  End;


Procedure RACfgObj.SetBbsId(BId: String);
  Begin
  End;


Function RACfgObj.GetDirectWrite: Boolean;
  Begin
  GetDirectWrite := RACfg^.DirectWrite;
  End;


Procedure RACfgObj.SetDirectWrite(DW: Boolean);
  Begin
  RACfg^.DirectWrite := DW;
  End;


Function RACfgObj.GetSnowCheck: Boolean;
  Begin
  GetSnowCheck := RACfg^.SnowCheck;
  End;


Procedure RACfgObj.SetSnowCheck(SC: Boolean);
  Begin
  RACfg^.SnowCheck := SC;
  End;


Function RACfgObj.GetMonoMode: Boolean;
  Begin
  GetMonoMode := RACfg^.MonoMode;
  End;


Procedure RACfgObj.SetMonoMode(MM: Boolean);
  Begin
  RACfg^.MonoMode := MM;
  End;


Function RACfgObj.GetForceKillYes: Boolean;
  Begin
  GetForceKillYes := (RACfg^.KillSent = RaYes);
  End;


Procedure RACfgObj.SetForceKillYes(FK: Boolean);
  Begin
  Case RACfg^.KillSent of
    RaNo: If FK Then
      RACfg^.KillSent := RAYes;
    RaYes: If Not FK Then
      RACfg^.KillSent := RaAsk;
    End;
  End;


Function RACfgObj.GetForceKillAsk: Boolean;
  Begin
  GetForceKillAsk := (RACfg^.KillSent = RaAsk);
  End;


Procedure RACfgObj.SetForceKillAsk(FK: Boolean);
  Begin
  Case RACfg^.KillSent of
    RaYes: If FK Then
      RACfg^.KillSent := RAAsk;
    RaNo: If FK Then
      RACfg^.KillSent := RaAsk;
    RaAsk: If Not FK Then
      RaCfg^.KillSent := RaNo;
    End;
  End;


Function RACfgObj.GetPageStart(DayNo: Byte): Word;
  Begin
  GetPageStart := TimeStr2Word(RACfg^.PageStart[DayNo]);
  End;


Procedure RACfgObj.SetPageStart(DayNo: Byte; St: Word);
  Begin
  RACfg^.PageStart[DayNo] := Word2TimeStr(ST);
  End;


Function RACfgObj.GetPageStop(DayNo: Byte): Word;
  Begin
  GetPageStop:= TimeStr2Word(RACfg^.PageEnd[DayNo]);
  End;


Procedure RACfgObj.SetPageStop(DayNo: Byte; St: Word);
  Begin
  RACfg^.PageEnd[DayNo] := Word2TimeStr(ST);
  End;


Function RACfgObj.GetMaxPageTimes: Word;
  Begin
  GetMaxPageTimes := RACfg^.MaxPage;
  End;


Procedure RACfgObj.SetMaxPageTimes(Pg: Word);
  Begin
  If Pg > 255 Then
    Pg := 255;
  RACfg^.MaxPage := Pg;
  End;


Function RACfgObj.GetPageMsgArea: Word;
  Begin
  GetPageMsgArea := RACfg^.LeaveMsg;
  End;


Procedure RACfgObj.SetPageMsgArea(Pg: Word);
  Begin
  RACfg^.LeaveMsg := Pg;
  End;


Function RACfgObj.GetPageLength: Byte;
  Begin
  GetPageLength := RACfg^.PageLength and $ff;
  End;


Procedure RACfgObj.SetPageLength(PL: Byte);
  Begin
  RACfg^.PageLength := PL;
  End;


Function RACfgObj.GetDefaultPage: Byte;
  Begin
  GetDefaultPage := 1;
  End;


Procedure RACfgObj.SetDefaultPage(DP: Byte);
  Begin
  End;


Function RACfgObj.GetAskPageReason: Boolean;
  Begin
  GetAskPageReason := RACfg^.WhyPage;
  End;


Procedure RACfgObj.SetAskPageReason(AP: Boolean);
  Begin
  RaCfg^.WhyPage := AP;
  End;


Function RACfgObj.GetMailCheckDetail: Boolean;
  Begin
  GetMailCheckDetail := True;
  End;


Procedure RACfgObj.SetMailCheckDetail(MC: Boolean);
  Begin
  End;


Function RACfgObj.GetMailCheckTotal: Boolean;
  Begin
  GetMailCheckTotal := True;
  End;


Procedure RACfgObj.SetMailCheckTotal(MC: Boolean);
  Begin
  End;


Procedure RACfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := RAMsg^[Area].ReadSecurity;
    Sec.Flags := LongInt(RAMsg^[Area].ReadFlags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure RACfgObj.SetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    RAMsg^[Area].ReadSecurity := Sec.Level;
    RAMsg^[Area].ReadFlags := RAFlagType(Sec.Flags);
    End;
  End;


Procedure RACfgObj.SetMsgWriteSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    RAMsg^[Area].WriteSecurity := Sec.Level;
    RAMsg^[Area].WriteFlags := RAFlagType(Sec.Flags);
    End;
  End;


Procedure RACfgObj.SetMsgSysopSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    RAMsg^[Area].SysopSecurity := Sec.Level;
    RAMsg^[Area].SysopFlags := RAFlagType(Sec.Flags);
    End;
  End;


Procedure RACfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := RAMsg^[Area].WriteSecurity;
    Sec.Flags := LongInt(RAMsg^[Area].WriteFlags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure RACfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := RAMsg^[Area].SysopSecurity;
    Sec.Flags := LongInt(RAMsg^[Area].SysopFlags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function RACfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPriv := ((RaMsg^[Area].MsgKinds = RABoth) or
      (RaMsg^[Area].MsgKinds = RAPrivate))
  Else
    MsgAllowPriv := True;
  End;



Procedure RACfgObj.SetMsgAllowPriv(Area: Word; Priv: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Priv Then
      Case RAMsg^[Area].MsgKinds of
        RAROnly: RAMsg^[Area].MsgKinds := RAPrivate;
        RAPublic: RAMsg^[Area].MsgKinds := RABoth;
        RABoth: RAMsg^[Area].MsgKinds := RABoth;
        Else
          RAMsg^[Area].MsgKinds := RAPrivate;
        End
    Else
      Case RAMsg^[Area].MsgKinds of
        RABoth: RAMsg^[Area].MsgKinds := RAPublic;
        RAPrivate: RAMsg^[Area].MsgKinds := RAROnly;
        RAROnly: RAMsg^[Area].MsgKinds := RAROnly;
        Else
          RAMsg^[Area].MsgKinds := RAPublic;
        End;
    End;
  End;


Procedure RACfgObj.SetMsgAllowPubl(Area: Word; Publ: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Publ Then
      Case RAMsg^[Area].MsgKinds of
        RAROnly: RAMsg^[Area].MsgKinds := RAPublic;
        RAPrivate: RAMsg^[Area].MsgKinds := RABoth;
        RABoth: RAMsg^[Area].MsgKinds := RABoth;
        Else
          RAMsg^[Area].MsgKinds := RAPublic;
        End
    Else
      Case RAMsg^[Area].MsgKinds of
        RABoth: RAMsg^[Area].MsgKinds := RAPrivate;
        RAPublic: RAMsg^[Area].MsgKinds := RAROnly;
        RAROnly : RAMsg^[Area].MsgKinds := RAROnly;
        Else
          RAMsg^[Area].MsgKinds := RAPrivate;
        End;
  End;



Function RACfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPubl := ((RaMsg^[Area].MsgKinds = RABoth) or
    (RaMsg^[Area].MsgKinds = RAPublic))
  Else
    MsgAllowPubl := True;
  End;


Function RACfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowReal := ((RAMsg^[Area].Attribute and 32) = 0)
  Else
    MsgAllowReal := True;
  End;


Procedure RACfgObj.SetMsgAllowReal(Area: Word; RName: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If RName Then
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute and Not 32
    Else
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute or 32;
  End;


Procedure RACfgObj.SetMsgAllowHdl(Area: Word; Hdl: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Not Hdl Then
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute and Not 32
    Else
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute or 32;
  End;


Procedure RACfgObj.SetMsgAllowAnon(Area: Word; Anon: Boolean);
  Begin
  End;



Function RACfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowHdl := ((RaMsg^[Area].Attribute and 32) <> 0)
  Else
    MsgAllowHdl := False;
  End;


Function RACfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows anonymous}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowAnon := ((RaMsg^[Area].Attribute and 8) <> 0)
  Else
    MsgAllowAnon := False;
  End;


Function RACfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAddFido := ((RaMsg^[Area].Attribute and 1) <> 0)
  Else
    MsgAddFido := True;
  End;



Procedure RACfgObj.SetMsgAddFido(Area: Word; Fido: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Fido Then
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute or 1
    Else
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute and (not 1);
    End;
  End;


Function RACfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Begin
  MsgAllowAnsi := False;
  End;


Procedure RACfgObj.SetMsgAllowAnsi(Area: Word; Ansi: Boolean);
  Begin
  End;


Function RACfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Begin
  MsgAllowHiBit := False;
  End;


Procedure RACfgObj.SetMsgAllowHiBit(Area: Word; HiBit: Boolean);
  Begin
  End;


Function RACfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Begin
  MsgAllowTag := False;
  End;


Procedure RACfgObj.SetMsgAllowTag(Area: Word; Tag: Boolean);
  Begin
  End;


Function RACfgObj.GetMsgReaderTear(Area: Word): Boolean;
  Begin
  GetMsgReaderTear := False;
  End;


Procedure RACfgObj.SetMsgReaderTear(Area: Word; RT: Boolean);
  Begin
  End;


Function RACfgObj.GetMsgReaderOrig(Area: Word): Boolean;
  Begin
  GetMsgReaderOrig := False;
  End;


Procedure RACfgObj.SetMsgReaderOrig(Area: Word; RT: Boolean);
  Begin
  End;


Function RACfgObj.GetMsgFAttach(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgFAttach := (RAMsg^[Area].Attribute and 4) <> 0
  Else
    GetMsgFAttach := False;
  End;


Procedure RACfgObj.SetMsgFAttach(Area: Word; FA: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If FA Then
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute or 4
    Else
      RAMsg^[Area].Attribute := RAMsg^[Area].Attribute and (not 4);
    End;
  End;


Function RACfgObj.GetMsgSelect(Area: Word): String;
  Begin
  GetMsgSelect := '';
  End;


Procedure RACfgObj.SetMsgSelect(Area: Word; Sel: String);
  Begin
  End;



Function RACfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  GetMaxFileAreas := 200;
  End;


Function RACfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    GetFileAreaName := RAFile^[Area].Name
  Else
    GetFileAreaName := '';
  End;


Procedure RACfgObj.SetFileAreaName(Area: Word; Name: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    RAFile^[Area].Name := Name;
  End;


Function RACfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Begin
  GetFileShortName := Copy(GetFileAreaName(Area),1,12);
  End;


Procedure RACfgObj.SetFileShortName(Area: Word; Nm: String);
  Begin
  End;


Function RACfgObj.GetFileSelect(Area: Word): String;
  Begin
  GetFileSelect := '';
  End;


Procedure RACfgObj.SetFileSelect(Area: Word; SN: String);
  Begin
  End;


Function RACfgObj.GetFileAreaPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <=GetMaxFileAreas)) Then
    Begin
    TmpStr := RAFile^[Area].FilePath;
    AddBackSlash(TmpStr);
    GetFileAreaPath := TmpStr;
    End
  Else
    GetFileAreaPath := '';
  End;


Procedure RACfgObj.SetFileAreaPath(Area: Word; FPath: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    RAFile^[Area].FilePath := FPath;
  End;


Function RACfgObj.GetFileListPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    AddBackSlash(RACfg^.ListPath);
    TmpStr := RaCfg^.ListPath + Long2Str(Area);
    If Not FileExist(TmpStr) Then
      Begin
      TmpStr := RAFile^[Area].FilePath;
      AddBackSlash(TmpStr);
      TmpStr := TmpStr + 'files.bbs';
      End;
    GetFileListPath := TmpStr;
    End
  Else
    GetFileListPath := '';
  End;


Procedure RACfgObj.GetFileViewSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := RAFile^[Area].Security;
    Sec.Flags := LongInt(RAFile^[Area].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure RACfgObj.SetFileViewSecurity(Area: Word; Var Sec: SecType);
  Begin
  End;


Procedure RACfgObj.GetFileDLSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := RAFile^[Area].Security;
    Sec.Flags := LongInt(RAFile^[Area].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure RACfgObj.SetFileDLSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    RAFile^[Area].Security := Sec.Level;
    RAFile^[Area].Flags := RaFlagType(Sec.Flags);
    End;
  End;


Procedure RACfgObj.GetFileULSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := RAFile^[Area].Security;
    Sec.Flags := LongInt(RAFile^[Area].Flags);
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure RACfgObj.SetFileULSecurity(Area: Word; Var Sec: SecType);
  Begin
  End;


Procedure RACfgObj.GetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private files security}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := RAFile^[Area].PrivateSecurity;
    Sec.Flags := LongInt(RAFile^[Area].PrivateFlags);
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Procedure RACfgObj.SetFilePvtSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (area <= GetMaxFileAreas)) Then
    Begin
    RAFile^[Area].PrivateSecurity := Sec.Level;
    RAFile^[Area].PrivateFlags := RaFlagType(Sec.Flags);
    End;
  End;


Function RACfgObj.GetFileNoUl(Area: Word): Boolean; {Area disallows ULs}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoUl := False
  Else
    GetFileNoUl := True;
  End;


Function RACfgObj.GetFileNoNew(Area: Word): Boolean; {Exclude area from new files}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoNew := (RAFile^[Area].Attrib and 1) = 0
  Else
    GetFileNoNew := True;
  End;


Function RACfgObj.GetFileFree(Area: Word): Boolean; {Area contains free files}
  Begin
  GetFileFree := False;
  End;


Function RACfgObj.GetFileNoTime(Area: Word): Boolean; {Ignore time remaining}
  Begin
  GetFileNoTime := False;
  End;


Function RACfgObj.GetFileNoBaud(Area: Word): Boolean; {Ignore min baud limits}
  Begin
  GetFileNoBaud := False;
  End;


Procedure RACfgObj.SetFileNoUl(Area: Word; St: Boolean);
  Begin
  End;


Procedure RACfgObj.SetFileNoNew(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    Begin
    If St Then
      RAFile^[Area].Attrib := RAFile^[Area].Attrib and (Not 1)
    Else
      RAFile^[Area].Attrib := RAFile^[Area].Attrib or 1;
    End
  End;


Procedure RACfgObj.SetFileFree(Area: Word; St: Boolean);
  Begin
  End;


Procedure RACfgObj.SetFileNoTime(Area: Word; St: Boolean);
  Begin
  End;


Procedure RACfgObj.SetFileNoBaud(Area: Word; St: Boolean);
  Begin
  End;



Function RACfgObj.FileViewAccess(Area: Word; Sec: SecType): Boolean; {Can view files}
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


Function RACfgObj.FileDLAccess(Area: Word; Sec: SecType): Boolean; {Can download files}
  Var
    AreaSec: SecType;

  Begin
  GetFileDLSecurity(Area, AreaSec);
  FileDLAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileDLAccess := False;
  End;


Function RACfgObj.FileULAccess(Area: Word; Sec: SecType): Boolean; {Can upload files}
  Var
    AreaSec: SecType;

  Begin
  GetFileULSecurity(Area, AreaSec);
  FileULAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileULAccess := False;
  End;


Function RACfgObj.FilePvtAccess(Area: Word; Sec: SecType): Boolean; {Private files}
  Var
    AreaSec: SecType;

  Begin
  GetFilePvtSecurity(Area, AreaSec);
  FilePvtAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FilePvtAccess := False;
  End;


Function RACfgObj.GetLangQuesPath(LNum: Word): String;
  Begin
  GetLangQuesPath := GetBbsPath;
  End;


Procedure RACfgObj.SetLangQuesPath(LNum: Word; QPath: String);
  Begin
  End;


Function RACfgObj.GetAskVoicePhone: Boolean;
  Begin
  GetAskVoicePhone := RACfg^.AskVoicePhone;
  End;


Procedure RACfgObj.SetAskVoicePhone(VP: Boolean);
  Begin
  RACfg^.AskVoicePhone := VP;
  End;


Function RACfgObj.GetAskDataPhone: Boolean;
  Begin
  GetAskDataPhone := RACfg^.AskDataPhone;
  End;


Procedure RACfgObj.SetAskDataPhone(DP: Boolean);
  Begin
  RACfg^.AskDataPhone := DP;
  End;


Function RACfgObj.GetNewUserNMCredit: Word;
  Begin
  GetNewUserNMCredit := RACfg^.NewCredit;
  End;


Procedure RACfgObj.SetNewUserNMCredit(NM: Word);
  Begin
  RACfg^.NewCredit := NM;
  End;


Function RACfgObj.GetAskBirthdate: Boolean;
  Begin
  GetAskBirthdate := RACfg^.AskForBirthDate;
  End;


Procedure RACfgObj.SetAskBirthdate(AB: Boolean);
  Begin
  RACfg^.AskForBirthDate := AB;
  End;


Function RACfgObj.GetAskGender: Boolean;
  Begin
  GetAskGender := False;
  End;


Procedure RACfgObj.SetAskGender(AG: Boolean);
  Begin
  End;


Function RACfgObj.GetAskAddr: Boolean;
  Begin
  GetAskAddr := False;
  End;


Procedure RACfgObj.SetAskAddr(AA: Boolean);
  Begin
  End;


Function RACfgObj.GetSevenBitNames: Boolean;
  Begin
  GetSevenBitNames := False;
  End;


Procedure RACfgObj.SetSevenBitNames (SB: Boolean);
  Begin
  End;


Function RACfgObj.GetOneWordName: Boolean;
  Begin
  GetOneWordName := RACfg^.OneWordNames;
  End;


Procedure RACfgObj.SetOneWordName(OW: Boolean);
  Begin
  RACfg^.OneWordNames := OW;
  End;


Function RACfgObj.GetReAsk: Boolean;
  Begin
  GetReAsk := False;
  End;


Procedure RACfgObj.SetReAsk(RA: Boolean);
  Begin
  End;


Function RACfgObj.GetAskHandle: Boolean; {Ask user for handle}
  Begin
  GetAskHandle := RACfg^.AskForHandle;
  End;


Procedure RACfgObj.SetAskHandle(AH: Boolean); {Set ask user for handle}
  Begin
  RACfg^.AskForHandle := AH;
  End;


Procedure RACfgObj.GetEchoToAddr(ES: Word; Var Addr: AddrType);
  Begin
  Addr.Zone := 0;
  Addr.Net := 0;
  Addr.Node := 0;
  Addr.Point := 0;
  End;


Procedure RACfgObj.SetEchoToAddr(ES: Word; Addr: AddrType);
  Begin
  End;


Function RACfgObj.GetEchoToPwd(ES: Word): String;
  Begin
  GetEchoToPwd := '';
  End;


Procedure RACfgObj.SetEchoToPwd(ES: Word; Pwd: String);
  Begin
  End;


Function RACfgObj.GetEchoToPacker(ES: Word): Byte;
  Begin
  GetEchoToPacker := 1;
  End;


Procedure RACfgObj.SetEchoToPacker(ES: Word; Pk: Byte);
  Begin
  End;


Function RACfgObj.GetEchoToNetwork(ES: Word; Nt: Word): Boolean;
  Var
    Mask: LongInt;

  Begin
  GetEchoToNetwork := False;
  End;


Procedure RACfgObj.SetEchoToNetwork(ES: Word; Nt: Word; St: Boolean);
  Var
    Mask: LongInt;

  Begin
  End;


Function RACfgObj.GetEchoToMailType(ES: Word): Byte;
  Begin
  GetEchoToMailType := 2;
  End;


Procedure RACfgObj.SetEchoToMailType(ES: Word; MT: Byte);
  Begin
  End;


Function RACfgObj.GetEchoToArea(ES: Word; Area: Word): Boolean;
  Begin
  GetEchoToArea := False;
  End;


Procedure RACfgObj.SetEchoToArea(ES: Word; Area: Word; SA: Boolean);
  Begin
  End;


Function RACfgObj.GetEchoAreaPassThru(Area: Word): Boolean;
  Begin
  GetEchoAreaPassThru := False;
  End;


Procedure RACfgObj.SetEchoAreaPassThru(Area: Word; PT: Boolean);
  Begin
  End;


Function RACfgObj.GetEchoAreaImportPath(Area: Word): Boolean;
  Begin
  GetEchoAreaImportPath := True;
  End;


Procedure RACfgObj.SetEchoAreaImportPath(Area: Word; IP: Boolean);
  Begin
  End;


Function RACfgObj.GetEchoAreaHidePath(Area: Word): Boolean;
  Begin
  GetEchoAreaHidePath := True;
  End;


Procedure RACfgObj.SetEchoAreaHidePath(Area: Word; HP: Boolean);
  Begin
  End;


Function RACfgObj.GetEchoAreaImportSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaImportSeen := False;
  End;


Procedure RACfgObj.SetEchoAreaImportSeen(Area: Word; ISB: Boolean);
  Begin
  End;


Function RACfgObj.GetEchoAreaHideSeen(Area: Word): Boolean;
  Begin
  GetEchoAreaHideSeen := True;
  End;


Procedure RACfgObj.SetEchoAreaHideSeen(Area: Word; HS: Boolean);
  Begin
  End;


Function RACfgObj.GetEchoToHub(Area: Word): Byte;
  Begin
  GetEchoToHub := 1;
  End;


Procedure RACfgObj.SetEchoToHub(Area: Word; Hub: Byte);
  Begin
  End;


Function RACfgObj.GetEchoMaxPkt: LongInt;
  Begin
  GetEchoMaxPkt := 100000;
  End;


Procedure RACfgObj.SetEchoMaxPkt(MP: LongInt);
  Begin
  End;


Function RACfgObj.GetEchoInPath: String;
  Begin
  GetEchoInPath := '';
  End;


Procedure RACfgObj.SetEchoInPath(EP: String);
  Begin
  End;


Function RACfgObj.GetEchoOutPath: String;
  Begin
  GetEchoOutPath := '';
  End;


Procedure RACfgObj.SetEchoOutPath(EP: String);
  Begin
  End;


Function RACfgObj.GetEchoAreaTag(Area: Word): String;
  Begin
  GetEchoAreaTag := '';
  End;


Procedure RACfgObj.SetEchoAreaTag(Area: Word; Tag: String);
  Begin
  End;


Function RACfgObj.GetPwdTries: Byte;
  Begin
  GetPwdTries := RACfg^.PasswordTries;
  End;


Procedure RACfgObj.SetPwdTries(PT: Byte);
  Begin
  RACfg^.PasswordTries := PT;
  End;


Function RACfgObj.GetPwdExpire: Word;
  Begin
  GetPwdExpire := RACfg^.PwdExpiry;
  End;


Procedure RACfgObj.SetPwdExpire(PE: Word);
  Begin
  RACfg^.PwdExpiry := PE;
  End;


Function RACfgObj.GetBDCheck: Byte;
  Begin
  GetBDCheck := 0;
  End;


Procedure RACfgObj.SetBDCheck(BD: Byte);
  Begin
  End;


Function RACfgObj.GetPhoneCheck: Byte;
  Begin
  GetPhoneCheck := 0;
  End;


Procedure RACfgObj.SetPhoneCheck(PC: Byte);
  Begin
  End;


Function RACfgObj.GetMinPwd: Byte;
  Begin
  GetMinPwd := RaCfg^.MinPwdLen;
  End;


Procedure RACfgObj.SetMinPwd(MP: Byte);
  Begin
  RACfg^.MinPwdLen := MP;
  End;


Function RACfgObj.GetMinPhone: Byte;
  Begin
  GetMinPhone := 7;
  End;


Procedure RACfgObj.SetMinPhone(MP: Byte);
  Begin
  End;


Function RACfgObj.GetStrictPwd: Boolean;
  Begin
  GetStrictPwd := RaCfg^.StrictPwdChecking;
  End;


Procedure RACfgObj.SetStrictPwd(SP: Boolean);
  Begin
  RACfg^.StrictPwdChecking := SP;
  End;


Function RACfgObj.GetRemoteSysop: Boolean;
  Begin
  GetRemoteSysop := RaCfg^.AllowSysRem;
  End;


Procedure RACfgObj.SetRemoteSysop(RS: Boolean);
  Begin
  RACfg^.AllowSysRem := RS;
  End;


Function RACfgObj.GetFastLocal: Boolean;
  Begin
  GetFastLocal := RaCfg^.FastLogOn;
  End;


Procedure RACfgObj.SetFastLocal(FL: Boolean);
  Begin
  RACfg^.FastLogOn := FL;
  End;


Procedure RACfgObj.GetNewUserSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.NewSecurity;
  Sec.Flags := LongInt(RACfg^.NewFlags);
  End;


Procedure RACfgObj.SetNewUserSec(Sec: SecType);
  Begin
  RACfg^.NewSecurity := Sec.Level;
  RACfg^.NewFlags := RaFlagType(Sec.Flags);
  End;


Procedure RACfgObj.GetAttachSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.FAttachSec;
  Sec.Flags := LongInt(RACfg^.FAttachFlags);
  End;


Procedure RACfgObj.SetAttachSec(Sec: SecType);
  Begin
  RACfg^.FAttachSec := Sec.Level;
  RACfg^.FAttachFlags := RaFlagType(Sec.Flags);
  End;


Procedure RACfgObj.GetRequestSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure RACfgObj.SetRequestSec(Sec: SecType);
  Begin
  End;


Procedure RACfgObj.GetCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.CrashAskSec;
  Sec.Flags := LongInt(RACfg^.CrashAskFlags);
  End;


Procedure RACfgObj.SetCrashNmSec(Sec: SecType);
  Begin
  RACfg^.CrashSec := Sec.Level;
  RACfg^.CrashFlags := RaFlagType(Sec.Flags);
  End;


Procedure RACfgObj.GetForceCrashNmSec(Var Sec: SecType);
  Begin
  Sec.Level := RACfg^.CrashSec;
  Sec.Flags := LongInt(RACfg^.CrashFlags);
  End;


Procedure RACfgObj.SetForceCrashNmSec(Sec: SecType);
  Begin
  RACfg^.CrashSec := Sec.Level;
  RACfg^.CrashFlags := RaFlagType(Sec.Flags);
  End;


Procedure RACfgObj.GetDeleteSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure RACfgObj.SetDeleteSec(Sec: SecType);
  Begin
  End;


Procedure RACfgObj.GetUnRcvSec(Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure RACfgObj.SetUnRcvSec(Sec: SecType);
  Begin
  End;


Function RACfgObj.GetModemResp(MR: Byte): String;
  Begin
  Case MR of
    2: GetModemResp := RACfg^.Connect300;
    3: GetModemResp := RACfg^.Connect1200;
    4: GetModemResp := RACfg^.Connect2400;
    5: GetModemResp := RACfg^.Connect4800;
    6: GetModemResp := RACfg^.Connect7200;
    7: GetModemResp := RACfg^.Connect9600;
    8: GetModemResp := RACfg^.Connect12000;
    9: GetModemResp := RACfg^.Connect14400;
    10: GetModemResp := RACfg^.Connect19k;
    11: GetModemResp := RACfg^.Connect38k;
    Else
      GetModemResp := '';
    End;
  End;


Procedure RACfgObj.SetModemResp(MR: Byte; Resp: String);
  Begin
  Case MR of
    2: RACfg^.Connect300 := Resp;
    3: RACfg^.Connect1200 := Resp;
    4: RACfg^.Connect2400 := Resp;
    5: RACfg^.Connect4800 := Resp;
    6: RACfg^.Connect7200 := Resp;
    7: RACfg^.Connect9600 := Resp;
    8: RACfg^.Connect12000 := Resp;
    9: RACfg^.Connect14400 := Resp;
    10: RACfg^.Connect19k := Resp;
    11: RACfg^.Connect38k := Resp;
    End;
  End;


Function RACfgObj.GetErrorLevel(MR: Byte): Byte;
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


Procedure RACfgObj.SetErrorLevel(MR: Byte; EL: Byte);
  Begin
  Case MR Of
    1: RACfg^.ExitLocal := EL;
    2: RACfg^.Exit300 := EL;
    3: RACfg^.Exit1200 := EL;
    4: RACfg^.Exit2400 := EL;
    5: RACfg^.Exit4800 := EL;
    6: RACfg^.Exit7200 := EL;
    7: RACfg^.Exit9600 := EL;
    8: RACfg^.Exit12000 := EL;
    9: RACfg^.Exit14400 := EL;
    10: RACfg^.Exit19k := EL;
    11: RACfg^.Exit38k := EL;
    End;
  End;


Function RACfgObj.GetDLStart: Word;
  Begin
  GetDLStart := TimeStr2Word(RACfg^.DownloadTimeStart);
  End;


Procedure RACfgObj.SetDLStart(ST: Word);
  Begin
  RACfg^.DownloadTimeStart := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
    PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function RACfgObj.GetDLStop: Word;
  Begin
  GetDLStop := TimeStr2Word(RACfg^.DownloadTimeEnd);
  End;


Procedure RACfgObj.SetDLStop(ST: Word);
  Begin
  RACfg^.DownloadTimeEnd := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
    PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function RACfgObj.GetLoBaudStart: Word;
  Begin
  GetLoBaudStart := TimeStr2Word(RACfg^.SlowBaudTimeStart);
  End;


Procedure RACfgObj.SetLoBaudStart(ST: Word);
  Begin
  RACfg^.SlowBaudTimeStart := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
    PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function RACfgObj.GetLoBaudStop: Word;
  Begin
  GetLoBaudStop := TimeStr2Word(RACfg^.SlowBaudTimeEnd);
  End;


Procedure RACfgObj.SetLoBaudStop(ST: Word);
  Begin
  RACfg^.SlowBaudTimeEnd := PadLeft(Long2Str(Hi(St)),'0',2) + ':' +
    PadLeft(Long2Str(Lo(St)),'0',2);
  End;


Function RACfgObj.GetMinXferBaud: Word;
  Begin
  GetMinXferBaud := RACfg^.TransferBaud;
  End;


Procedure RACfgObj.SEtMinXferBaud(MB: Word);
  Begin
  RACfg^.TransferBaud := MB;
  End;


Function RACfgObj.GetULCredit: Integer;
  Begin
  GetULCredit := RACfg^.CreditFactor;
  End;


Procedure RACfgObj.SetULCredit(UC: Integer);
  Begin
  RACfg^.CreditFactor := UC;
  End;


Function RACfgObj.GetMinDesc: Byte;
  Begin
  GetMinDesc := 10;
  End;


Procedure RACfgObj.SetMinDesc(MD: Byte);
  Begin
  End;


Function RACfgObj.GetMaxDesc: Byte;
  Begin
  GetMaxDesc := 240;
  End;


Procedure RACfgObj.SetMaxDesc(MD: Byte);
  Begin
  End;


Function RACfgObj.GetMinFree: LongInt;
  Begin
  GetMinFree := LongInt(RACfg^.MinUpSpace) * 1024;
  End;


Procedure RACfgObj.SetMinFree(MF: LongInt);
  Begin
  RACfg^.MinUpSpace := MF Div 1024;
  End;


Function RACfgObj.GetAskNewFiles: Boolean;
  Begin
  GetAskNewFiles := ((RACfg^.CheckNewFiles = RaAsk) Or
    (RACfg^.CheckNewFiles = RAYes));
  End;


Procedure RACfgObj.SetAskNewFiles(AN: Boolean);
  Begin
  Case RACfg^.CheckNewFiles of
    RANo: If AN Then
            RACfg^.CheckNewFiles := RAAsk;
    RAAsk: If Not AN THen
            RACfg^.CheckNewFiles := RANo;
    End;
  End;


Function RACfgObj.GetForceNewFiles: Boolean;
  Begin
  GetForceNewFiles := RACfg^.CheckNewFiles = RaYes;
  End;


Procedure RACfgObj.SetForceNewFiles(AN: Boolean);
  Begin
  Case RACfg^.CheckNewFiles of
    RANo: If AN Then
            RACfg^.CheckNewFiles := RAYes;
    RAYes: If Not AN Then
            RACfg^.CheckNewFiles := RAAsk;
    RAAsk: If AN THen
            RACfg^.CheckNewFiles := RAYes;
    End;
  End;


Function RACfgObj.GetMaxEvents: Word;
  Begin
  GetMaxEvents := 20;
  End;


Function RACfgObj.GetEventStatus(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventStatus := Byte(RAEvent^[EN].Status)
  Else
    GetEventStatus := 0;
  End;



Procedure RACfgObj.SetEventStatus(EN: Word; ES: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    RAEvent^[EN].Status := ES;
  End;



Function RACfgObj.GetEventTime(EN: Word): Word;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventTime := TimeStr2Word(RAEvent^[EN].StartTime)
  Else
    GetEventTime := 0;
  End;


Procedure RACfgObj.SetEventTime(EN: Word; ET: Word);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    RAEvent^[EN].StartTime := Word2TimeStr(ET);
  End;


Function RACfgObj.GetEventEL(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventEL := RAEvent^[EN].ErrorLevel
  Else
    GetEventEL := 0;
  End;


Procedure RACfgObj.SetEventEL(EN: Word; EL: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    RAEvent^[EN].ErrorLevel := EL;
  End;


Function RACfgObj.GetEventDays(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventDays := RAEvent^[EN].Days
  Else
    GetEventDays := 0;
  End;


Procedure RACfgObj.SetEventDays(EN: Word; ED: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    RAEvent^[EN].Days := ED;
  End;


Function RACfgObj.GetEventOnDay(EN: Word; OD: Byte): Boolean;
  Begin
  GetEventOnDay := (GetEventDays(EN) and (1 shl (OD -1))) <> 0;
  End;


Procedure RACfgObj.SetEventOnDay(EN: Word; OD: Byte; ST: Boolean);
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



Function RACfgObj.GetEventForced(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventForced := RAEvent^[EN].Forced
  Else
    GetEventForced := 0;
  End;


Procedure RACfgObj.SetEventForced(EN: Word; EF: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    RAEvent^[EN].Forced := EF;
  End;


Function RACfgObj.GetDoorData(DN: Word): String;
  Begin
  GetDoorData := '';
  End;


Procedure RACfgObj.SetDoorData(DN: Word; DD: String);
  Begin
  End;


Procedure RACfgObj.GetDoorSec(DN: Word; Var Sec: SecType);
  Begin
  Sec.Level := $ffff;
  Sec.Flags := $ffffffff;
  End;


Procedure RACfgObj.SetDoorSec(DN: Word; Sec: SecType);
  Begin
  End;


Function RACfgObj.DoorAccess(DN: Word; Sec: SecType): Boolean;
  Var
    RSec: SecType;

  Begin
  DoorAccess := False;
  End;


Function RACfgObj.GetProtNormAvail(PN: Word): Boolean;
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


Function RACfgObj.GetProtSpecAvail(PN: Word): Boolean;
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


Function RACfgObj.GetProtChar(PN: Word): Char;
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


Function RACfgObj.GetProtName(PN: Word): String;
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


Procedure RACfgObj.SetProtNormAvail(PN: Word; PA: Boolean);
  Var
    RaAvail: Byte;

  Begin
  If Pa Then
    RaAvail := 1
  Else
    RaAvail := 0;
  Case PN of
    1: RACfg^.ProtocolAttrib[1] := RaAvail;
    2: RACfg^.ProtocolAttrib[2] := RaAvail;
    3: RACfg^.ProtocolAttrib[6] := RaAvail;
    4: RACfg^.ProtocolAttrib[3] := RaAvail;
    5: RACfg^.ProtocolAttrib[5] := RaAvail;
    6: RACfg^.ProtocolAttrib[4] := RaAvail;
    End;
  End;


Procedure RACfgObj.SetProtSpecAvail(PN: Word; PA: Boolean);
  Begin
  End;


Procedure RACfgObj.SetProtChar(PN: Word; PC: Char);
  Begin
  End;


Procedure RACfgObj.SetProtName(PN: Word; Name: String);
  Begin
  End;


Function RaCfgObj.GetLogLevel: Byte; {Get level of logging}
  Begin
  GetLogLevel := 1;
  End;


Procedure RaCfgObj.SetLogLevel(LL: Byte); {Set level of logging}
  Begin
  End;


Function RaCfgObj.GetLogStyle: Byte; {Get style of log file}
  Begin
  GetLogStyle := (RACfg^.LogStyle And 1);
  End;


Procedure RaCfgObj.SetLogStyle(LS: Byte); {Set style of log file}
  Begin
  RACfg^.LogStyle := (LS and 1);
  End;


Function RaCfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  GetDefaultPort := RaCfg^.CommPort;
  End;


Procedure RaCfgObj.SetDefaultPort(DP: Word); {Set default comm port}
  Begin
  RaCfg^.CommPort := Dp;
  End;


Function RaCfgObj.GetNodeIdxName: String;
  Begin
  GetNodeIdxName := 'nodeidx.ra';
  End;


Function RaCfgObj.GetNodeIncName: String;
  Begin
  GetNodeIncName := 'nodeinc.ra';
  End;


Function RaCfgObj.GetPrnName: String;
  Begin
  GetPrnName := RaCfg^.PrinterName;
  End;


Procedure RaCfgObj.SetPrnName(PN: String);
  Begin
  RACfg^.PrinterName := PN;
  End;


End.
