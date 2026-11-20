Unit MKCfgMK;


{$I MKB.Def}

Interface


Uses MKGlobT, MKFile, MKCfgAbs,
  Dos;

{$I Struct.MK}



Type MKCfgObj = Object(CfgObj)
  MKCfg:    ^BbsCfg;
  MKMsg:    ^MsgCfgType;
  MKFile: ^FileCfgType;
  MKEcho:   ^EchoCfgType;
  MKMail:   ^MailerCfgType;
  MKEvents: ^EventsCfgType;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure MKLoad; Virtual;{Normally internal to load MK config}
  Procedure MKMailLoad;
  Procedure MKEventsLoad;
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Procedure Save; Virtual;{Save Bbs config info}
  Function  SaveFileName(FN: String): String; Virtual;
  Function  SaveFileNames: String; Virtual;
  Procedure MKSave; Virtual; {Normally internal to save MK config}
  Function  EnvBbsPath: String; Virtual; {The main directory before the config is read (the MK environment variable)}
  Function  SaveEchoCfg: Word; Virtual; {Save only echocfg.mk (what the tosser changes: which system gets which area)}
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
  Function  GetMsgNetStatus(Area: Word): LongInt; Virtual; {Net status setting}
  Procedure SetMsgNetStatus(Area: Word; NS: LongInt); Virtual;
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
  Function  GetFileFreq(Area: Word): Boolean; Virtual;
  Procedure SetFileFreq(Area: Word; St: Boolean); Virtual;
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
  Function  GetLangName(LNum: Word): String;  Virtual; {Get language name}
  Procedure SetLangName(LNum: Word; Name: String); Virtual; {Set language name}
  Function  GetLangFile(LNum: Word): String;  Virtual; {Get language file name}
  Procedure SetLangFile(LNum: Word; FName: String); Virtual; {Set language file name}
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
  Function  HasMailer: Boolean; Virtual;
  Function  HasEventExt: Boolean; Virtual;
  Procedure GetEventExt(Var E: EventsCfgType); Virtual;
  Procedure SetEventExt(Var E: EventsCfgType); Virtual;
  Procedure GetMailer(Var M: MailerCfgType); Virtual;
  Procedure SetMailer(Var M: MailerCfgType); Virtual;
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
  Function  GetPwdMode: Byte; Virtual;
  Procedure SetPwdMode(PM: Byte); Virtual;
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
  Function  GetProtCmdLine(PN: Word): String; Virtual; {Get external protocol command line: send | receive}
  Procedure SetProtCmdLine(PN: Word; Cmd: String); Virtual; {Set it}
  Procedure SetProtNormAvail(PN: Word; PA: Boolean); Virtual; {Is protocol avail norm files}
  Procedure SetProtSpecAvail(PN: Word; PA: Boolean); Virtual; {Is protocol avail special files}
  Procedure SetProtChar(PN: Word; PC: Char); Virtual; {Set protocol character}
  Procedure SetProtName(PN: Word; Name: String); Virtual; {Set protocol name}
  Function  GetPackAvail(PN: Word): Boolean; Virtual; {Is packer avail}
  Function  GetPackChar(PN: Word): Char; Virtual; {Get packer character}
  Function  GetPackName(PN: Word): String; Virtual; {Get packer name}
  Procedure SetPackAvail(PN: Word; PA: Boolean); Virtual; {Is packer avail}
  Procedure SetPackChar(PN: Word; PC: Char); Virtual; {Set packer character}
  Procedure SetPackName(PN: Word; Name: String); Virtual; {Set packer name}
  Function  GetPackCmdLine(PN: Word): String; Virtual; {Get packer cmd line}
  Procedure SetPackCmdLine(PN: Word; Cmd: String); Virtual; {Set cmd line}
  Function  GetUnPackCmdLine(PN: Word): String; Virtual; {Get packer cmd line}
  Procedure SetUnPackCmdLine(PN: Word; Cmd: String); Virtual; {Set cmd line}
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
  Function  GetMsgFileId(Area: Word): String; Virtual; {Get msg filename id}
  Procedure SetMsgFileId(Area: Word; Fid: String); Virtual; {Set msg filename id}
  Function  GetPrnName: String; Virtual; {Get printer name}
  Procedure SetPrnName(PN: String); Virtual; {Set printer name}
  Function  GetOffTypeAvail(OT: Word): Boolean; Virtual; {Offline Pkt Type avail}
  Procedure SetOffTypeAvail(OT: Word; Avail: Boolean); Virtual; {Set avail}
  Function  GetOffAllowNew: Boolean; Virtual; {Get offline allow newfiles list}
  Procedure SetOffAllowNew(OA: Boolean); Virtual; {Set allow new}
  Function  GetOffForceNew: Boolean; Virtual; {Get Force new files list}
  Procedure SetOffForceNew(OA: Boolean); Virtual; {Set force new}
  Function  GetOffAllowScrn: Boolean; Virtual; {Get offline allow screens}
  Procedure SetOffAllowScrn(OA: Boolean); Virtual; {Set allow screens}
  Function  GetOffForceScrn: Boolean; Virtual; {Get Force screens}
  Procedure SetOffForceScrn(OA: Boolean); Virtual; {Set force screens}
  Function  GetOffAllowBull: Boolean; Virtual; {Get offline allow bulletins}
  Procedure SetOffAllowBull(OA: Boolean); Virtual; {Set allow Bulletins}
  Function  GetOffForceBull: Boolean; Virtual; {Get Force Bulletins}
  Procedure SetOffForceBull(OA: Boolean); Virtual; {Set force Bulletins}
  Function  GetOffAllowFreq: Boolean; Virtual; {Get offline allow file req}
  Function  GetOffQwke: Boolean; Virtual; {QWKE long names and subjects in QWK packets}
  Procedure SetOffQwke(OQ: Boolean); Virtual; {Set QWKE}
  Procedure SetOffAllowFreq(OA: Boolean); Virtual; {Set allow file req}
  Function  GetOffMax: Word; Virtual; {Get offline max msgs per pkt}
  Procedure SetOffMax(OM: Word); Virtual; {Set max msgs per pkt}
  Function  GetOffConfMax: Word; Virtual; {Get max msgs per area}
  Procedure SetOffConfMax(CM: Word); Virtual; {Set max msgs per area}
  Function  GetBadMsgArea: Word; Virtual; {Get msg area for offline replies that cannot go where meant (0 = none)}
  Procedure SetBadMsgArea(BA: Word); Virtual; {Set that area}
  Function  GetOffReDate: Boolean; Virtual; {Redate offline replies to the import date}
  Procedure SetOffReDate(RD: Boolean); Virtual; {Set redate}
  Function  GetOffCompRate: Word; Virtual; {Get estimate compress %}
  Procedure SetOffCompRate(CM: Word); Virtual; {Set est compr %}
  Function  GetOffSafetyMin: Word; Virtual; {Get offline safety minutes}
  Procedure SetOffSafetyMin(SM: Word); Virtual; {Set safety minutes}
  Function  GetOffScrns(SN: Word): String; Virtual; {Get offline screen names}
  Procedure SetOffScrns(SN: Word; Scrn: String); Virtual; {Set offline scrn names}
  Function  GetOffBulls(BN: Word): String; Virtual; {Get offline bulletins}
  Procedure SetOffBulls(BN: Word; Bull: String); Virtual; {Set bulletin names}
  End;

Type MKCfgObjPtr = ^MKCfgObj;


Implementation


Uses MKString;

Function MKCfgObj.GetMsgPath(BaseNo: Word): String;
  Begin
  If ((BaseNo > 0) and (BaseNo < 11)) Then
    GetMsgPath := MKCfg^.MsgPath[BaseNo]
  Else
    GetMsgPath := '';
  End;


Procedure MKCfgObj.SetMsgPath(BaseNo: Word; MPath: String);
  Begin
  If ((BaseNo > 0) and (BaseNo < 11)) Then
    MKCfg^.MsgPath[BaseNo] := MPath;
  End;


Function MKCfgObj.GetTxtPath(Num:Word): String; {Get path to asc/ans/avt files}
  Begin
  GetTxtPath := MKCfg^.TxtPath[Num];
  End;


Procedure MKCfgObj.SetTxtPath(Num: Word; TPath: String);
  Begin
  MKCfg^.TxtPath[Num] := TPath;
  End;


Function MKCfgObj.GetMnuPath(Num: Word): String; {Get path to menu *.mnu files}
  Begin
  GetMnuPath := MKCfg^.MenuPath[Num];
  End;


Procedure MKCfgObj.SetMnuPath(Num: Word; MPath: String);
  Begin
  MKCfg^.MenuPath[Num] := MPath;
  End;


Function MKCfgObj.GetNetPath: String;
  Begin
  GetNetPath := MKCfg^.NetMailPath;
  End;


Procedure MKCfgObj.SetNetPath(NP: String);
  Begin
  MkCfg^.NetMailPath := Copy(NP, 1, 60);
  End;


Function MKCfgObj.GetTempPath: String;
  Begin
  GetTempPath := MKCfg^.TempPath;
  End;


Procedure MKCfgObj.SetTempPath(TP: String);
  Begin
  MkCfg^.TempPath := Copy(TP, 1, 60);
  End;


Function MKCfgObj.GetLogFileName: String;
  Begin
  GetLogFileName := MKCfg^.LogFileName;
  End;


Procedure MKCfgObj.SetLogFileName(LN: String);
  Begin
  MkCfg^.LogFileName := Copy(LN, 1, 60);
  End;


Function MKCfgObj.GetEditCmdPath: String;
  Begin
  GetEditCmdPath := MKCfg^.EditCmdPath;
  End;


Procedure MKCfgObj.SetEditCmdPath(EC: String);
  Begin
  MkCfg^.EditCmdPath := Copy(EC, 1, 60);
  End;


Function MKCfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := MKCfg^.NodeListPath;
  End;


Procedure MKCfgObj.SetNodeListPath(NP: String);
  Begin
  MkCfg^.NodeListPath := Copy(NP, 1, 60);
  End;


Function MKCfgObj.GetAttachPath: String;
  Begin
  GetAttachPath := MKCfg^.AttachPath;
  End;


Procedure MKCfgObj.SetAttachPath(AP: String);
  Begin
  MkCfg^.AttachPath := Copy(AP, 1, 60);
  End;


Function MKCfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  GetSemaphorePath := MKCfg^.SemaphorePath;
  End;


Procedure MKCfgObj.SetSemaphorePath(SP: String); {Set Semaphore file path}
  Begin
  MKCfg^.SemaphorePath := Copy(SP, 1, 60);
  End;


Function MKCfgObj.GetBbsType: Word;
  Begin
  GetBbsType := CfgInfo^.BbsType;
  End;


Procedure MKCfgObj.SetBbsType(BT: Word);           {Set type of Bbs}
  Begin
  CfgInfo^.BbsType := BT;
  End;



Function MKCfgObj.EnvBbsPath: String;
  Begin
  EnvBbsPath := GetEnv('MK');
  End;


Function MKCfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := CfgInfo^.BbsPath;
  End;


Procedure MKCfgObj.SetBbsPath(BPath: String);      {Set main Bbs Directory}
  Begin
  CfgInfo^.BbsPath := BPath;
  AddBackSlash(CfgInfo^.BbsPath);
  End;


Procedure MKCfgObj.MKMailLoad;
  {Mailer.Mk may be missing or shorter than the record (made by an older version): what is not in the file keeps
   its default.  A file with a version we do not know is not used.}
  Var
    FN: String;
    Tmp: ^MailerCfgType;

  Begin
  FN := FindBbsFile('mailer.mk') + 'mailer.mk';
  If Not FileExist(FN) Then
    Exit;
  New(Tmp);
  MailerDefaults(Tmp^);
  If LoadFile(FN, Tmp^, SizeOf(Tmp^)) = 0 Then
    Begin
    If (Tmp^.Version >= 1) And (Tmp^.Version <= MailerCfgVersion) Then
      MKMail^ := Tmp^;
    End
  Else
    Error := 8889;
  Dispose(Tmp);
  End;


Procedure MKCfgObj.MKEventsLoad;
  {Events.Mk is optional too: missing or shorter, what is not in the file keeps the defaults (no action, 10 minutes grace)}
  Var
    FN: String;
    Tmp: ^EventsCfgType;

  Begin
  FN := FindBbsFile('events.mk') + 'events.mk';
  If Not FileExist(FN) Then
    Exit;
  New(Tmp);
  EventsDefaults(Tmp^);
  If LoadFile(FN, Tmp^, SizeOf(Tmp^)) = 0 Then
    Begin
    If (Tmp^.Version >= 1) And (Tmp^.Version <= EventsCfgVersion) Then
      MKEvents^ := Tmp^;
    End
  Else
    Error := 8890;
  Dispose(Tmp);
  End;


Procedure MKCfgObj.MKLoad;
  Begin
  New(MKCfg);
  New(MKMsg);
  New(MKFile);
  New(MKEcho);
  New(MKMail);
  MailerDefaults(MKMail^);
  New(MKEvents);
  EventsDefaults(MKEvents^);
  FileMode := fmReadWrite + fmDenyNone;
  Error := LoadFile(FindBbsFile('config.mk') + 'config.mk', MkCfg^, SizeOf(MkCfg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('messages.mk') + 'messages.mk', MKMsg^, SizeOf(MKMsg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('files.mk') + 'files.mk', MKFile^, SizeOf(MkFile^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('echocfg.mk') + 'echocfg.mk', MKEcho^, SizeOf(MKEcho^));
  If Error = 0 Then
    Begin                              {Mailer.Mk is optional (a shorter file keeps the defaults for the rest)}
    MKMailLoad;
    If Error = 0 Then
      MKEventsLoad;
    End;
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(MkCfg);
    Dispose(MkMsg);
    Dispose(MkFile);
    Dispose(MKEcho);
    Dispose(MKMail);
    Dispose(MKEvents);
    End;
  End;


Procedure MKCfgObj.Allocate;
  Begin
  If Not CfgInfo^.Loaded Then
    Begin
    New(MkCfg);
    New(MKMsg);
    New(MKFile);
    New(MKEcho);
    New(MKMail);
    MailerDefaults(MKMail^);
    New(MKEvents);
    EventsDefaults(MKEvents^);
    FillChar(MKCfg^, SizeOf(MKCfg^), 0);
    FillChar(MKMsg^, SizeOf(MKMsg^), 0);
    FillChar(MKFile^, SizeOf(MKFile^), 0);
    FillChar(MKEcho^, SizeOf(MKEcho^), 0);
    CfgInfo^.BbsPath := EnvBbsPath;
    AddBackSlash(CfgInfo^.BbsPath);
    CfgInfo^.Loaded := True;
    End;
  End;


Procedure MKCfgObj.Unload;
  Begin
  If CfgInfo^.Loaded Then
    Begin
    Dispose(MkCfg);
    Dispose(MKMsg);
    Dispose(MKFile);
    Dispose(MKEcho);
    Dispose(MKMail);
    Dispose(MKEvents);
    CfgInfo^.Loaded := False;
    End;
  End;


Procedure MKCfgObj.Load;
  Var
    CPath: String;
    i: Word;

  Begin
  CPath := GetCurrentPath;
  CfgInfo^.BbsPath := EnvBbsPath;
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


Procedure MKCfgObj.Save;
  Var
    i: Word;

  Begin
  MKSave;
  End;


Function MKCfgObj.SaveFileNames: String;
  Begin
  SaveFileNames := 'config.mk|messages.mk|files.mk|echocfg.mk|mailer.mk|events.mk';
  End;


Function MKCfgObj.SaveFileName(FN: String): String;
  Var
    TmpStr: String;

  Begin
  If CfgInfo^.SaveDir <> '' Then
    Begin
    SaveFileName := CfgInfo^.SaveDir + FN;
    Exit;
    End;
  TmpStr := FindBbsFile(FN);
  If Length(TmpStr) > 0 Then
    SaveFileName := TmpStr + FN
  Else
    SaveFileName := GetBbsPath + FN;
  End;


Function MKCfgObj.SaveEchoCfg: Word;
  Begin
  SaveEchoCfg := SaveFile(SaveFileName('echocfg.mk'), MKEcho^, SizeOf(MKEcho^));
  End;


Procedure MKCfgObj.MKSave;
  Begin
  Error := SaveFile(SaveFileName('config.mk'), MKCfg^, SizeOf(MKCfg^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('messages.mk'), MKMsg^, SizeOf(MKMsg^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('files.mk'), MKFile^, SizeOf(MKFile^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('echocfg.mk'), MKEcho^, SizeOf(MKEcho^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('mailer.mk'), MKMail^, SizeOf(MKMail^));
  If Error = 0 Then
    Error := SaveFile(SaveFileName('events.mk'), MKEvents^, SizeOf(MKEvents^));
  End;


Function MKCfgObj.GetQuoteStr: String;
  Begin
  GetQuoteStr := MKCfg^.QuoteStr;
  End;


Procedure MKCfgObj.SetQuoteStr(Qt: String);
  Begin
  MKCfg^.QuoteStr := Qt;
  End;


Function MKCfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  GetMaxMsgAreas := 500;
  End;


Function MKCfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgName := MKMsg^[Area].Name
  Else
    GetMsgName := '';
  End;


Function MKCfgObj.GetMsgOrigStr(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgOrigStr := MKCfg^.Origin[MKMsg^[Area].Origin]
  Else
    GetMsgOrigStr := '';
  End;


Function MKCfgObj.GetOrigStr(OrigNum: Word): String;
  Begin
  If ((OrigNum > 0) and (OrigNum < 21)) Then
    GetOrigStr := MKCfg^.Origin[OrigNum]
  Else
    GetOrigStr := '';
  End;


Procedure MKCfgObj.SetOrigStr(OrigNum: Word; OrigStr: String);
  Begin
  If ((OrigNum > 0) and (OrigNum < 21)) Then
    MKCfg^.Origin[OrigNum] := OrigStr;
  End;


Procedure MKCfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
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


Procedure MKCfgObj.SetAddr(Aka: Word; Addr: AddrType);
  Begin
  If ((Aka > 0) and (Aka < 11)) Then
    MKCfg^.Addr[Aka] := Addr;
  End;





Procedure MKCfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    {an area that has no AKA chosen (0) uses the main address}
    If MKMsg^[Area].Addr = 0 Then
      MA := MKCfg^.Addr[1]
    Else
      MA := MKCfg^.Addr[MKMsg^[Area].Addr];
    End
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function MKCfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Var
    Addr: AddrType;

  Begin
  GetMsgAddr(Area, Addr);
  GetMsgAddrStr := AddrStr(Addr);
  End;


Function MKCfgObj.GetMsgAddrNum(Area: Word): Word;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAddrNum := MKMsg^[Area].Addr
  Else
    GetMsgAddrNum := 1;
  End;


Procedure MKCfgObj.SetMsgAddrNum(Area: Word; AKA: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If ((AKA > 0) and (Aka < 11)) Then
      MKMsg^[Area].Addr := Aka;
  End;


Function MKCfgObj.GetMsgOrigNum(Area: Word): Word;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgOrigNum := MKMsg^[Area].Origin
  Else
    GetMsgOrigNum := 1;
  End;


Procedure MKCfgObj.SetMsgOrigNum(Area: Word; Orig: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If ((Orig > 0) and (Orig < 21)) Then
      MKMsg^[Area].Origin := Orig;
  End;


Function MKCfgObj.GetMsgAllowOffline(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAllowOffline := (MKMsg^[Area].Permit and mpOffline) <> 0
  Else
    GetMsgAllowOffline := True
  End;



Procedure MKCfgObj.SetMsgAllowOffline(Area: Word; AO: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Ao Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpOffline
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (not mpOffline);
  End;


Function MKCfgObj.GetMsgForceOffline(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgForceOffline := (MKMsg^[Area].Permit and mpForce) <> 0
  Else
    GetMsgForceOffline := False
  End;



Procedure MKCfgObj.SetMsgForceOffline(Area: Word; FO: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Fo Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpForce
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (not mpForce);
  End;


Function MKCfgObj.GetMsgAllowCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgAllowCombined := (MKMsg^[Area].Permit and mpCombine) <> 0
  Else
    GetMsgAllowCombined := False;
  End;


Procedure MKCfgObj.SetMsgAllowCombined(Area: Word; AC: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Ac Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpCombine
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (not mpCombine);
  End;


Function MKCfgObj.GetMsgDefCombined(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetMsgDefCombined := (MKMsg^[Area].Permit and mpDefCombine) <> 0
  Else
    GetMsgDefCombined := False;
  End;


Procedure MKCfgObj.SetMsgDefCombined(Area: Word; DC: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    If DC Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpDefCombine
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (Not mpDefCombine);
  End;


Function MKCfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;


Procedure MKCfgObj.SetMsgName(Area: Word; Name: String); {Set message area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].Name := Name;
  End;


Function MKCfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Length(MKMsg^[Area].ShortName) > 0 Then
      GetMsgShortName := MkMsg^[Area].ShortName
    Else
      GetMsgShortName := Copy(MKMsg^[Area].Name,1,12)
  Else
    GetMsgShortName := '';
  End;


Procedure MKCfgObj.SetMsgShortName(Area: Word; Name: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].ShortName := Name;
  End;


Function MKCfgObj.GetMsgNetwork(Area: Word; Net: Byte): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas) And (Net > 0) and (Net < 33)) Then
    GetMsgNetwork := (MKMsg^[Area].NetStat and (LongInt(1) shl (Net - 1))) <> 0
  Else
    GetMsgNetwork := False;
  End;


Procedure MKCfgObj.SetMsgNetwork(Area: Word; Net: Byte; MN: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas) And (Net > 0) and (Net < 33)) Then
    Begin
    If MN Then
      MKMsg^[Area].NetStat := MKMsg^[Area].NetStat or (LongInt(1) shl (Net - 1))
    Else
      MKMsg^[Area].NetStat := MKMsg^[Area].NetStat And (Not (LongInt(1) shl (Net - 1)));
    End;
  End;


Function MKCfgObj.GetMsgNetStatus(Area: Word): LongInt;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgNetStatus := MKMsg^[Area].NetStat
  Else
    GetMsgNetStatus := 0;
  End;

Procedure MKCfgObj.SetMsgNetStatus(Area: Word; NS: LongInt);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].NetStat := NS;
  End;

Function MKCfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case MKMsg^[Area].MsgType Of
      mtNormal: GetMsgType := Normal;
      mtNet: GetMsgType := NetMail;
      mtEcho: GetMsgType := EchoMail;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Procedure MKCfgObj.SetMsgType(Area: Word; MT: MailType); {Set type of mail area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Case MT of
      Normal: MKMsg^[Area].MsgType := mtNormal;
      NetMail: MKMsg^[Area].MsgType := mtNet;
      EchoMail: MKMsg^[Area].MsgType := mtEcho;
      End;
    End;
  End;


Function MKCfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgWriteSecurity(Area, AreaSec);
  MsgWriteAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgWriteAccess := False;
  End;


Function MKCfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgReadSecurity(Area, AreaSec);
  MsgReadAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgReadAccess := False;
  End;


Function MKCfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgSysopSecurity(Area, AreaSec);
  MsgSysopAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgSysopAccess := False;
  End;


Function MKCfgObj.MsgDeleteAccess(Sec: SecType): Boolean;
  Begin
  MsgDeleteAccess := Access(Sec, MKCfg^.MsgDelSec);
  End;


Function MKCfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;
  Begin
  MsgUnRecvAccess := Access(Sec, MKCfg^.MsgNoRcv);
  End;


Function MKCfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetMsgDays := MKMsg^[Area].DaysKept
  Else
    GetMsgDays := 7;
  End;


Function MKCfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgRcvdDays := MKMsg^[Area].RcvdDays
  Else
    GetMsgRcvdDays := 2;
  End;


Function MKCfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgsKept := MKMsg^[Area].MsgsKept
  Else
    GetMsgsKept := 200;
  End;


Procedure MKCfgObj.SetMsgDays(Area: Word; Days: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].DaysKept := Days;
  End;


Procedure MKCfgObj.SetMsgRcvdDays(Area: Word; Days: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].RcvdDays := Days;
  End;


Procedure MKCfgObj.SetMsgsKept(Area: Word; Msgs: Word);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].MsgsKept := Msgs;
  End;


Function MKCfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  GetSysopName := MKCfg^.SysopName;
  End;


Procedure MKCfgObj.SetSysopName(Sysop: String);
  Begin
  MKCfg^.SysopName := Proper(Copy(Sysop, 1, 35));
  End;


Function MKCfgObj.GetSystemColor(Num: Byte): Byte; {Get system color attribute}
  Begin
  If ((Num < 1) or (Num > 5)) Then
    Num := 1;
  GetSystemColor := MKCfg^.Color[Num];
  End;


Procedure MKCfgObj.SetSystemColor(Num: Byte; Color: Byte);
  Begin
  If ((Num < 6) And (Num > 0)) Then
    MKCfg^.Color[Num] := Color;
  End;



Function MKCfgObj.GetBbsName: String;
  Begin
  GetBbsName := MKCfg^.SystemName;
  End;


Procedure MKCfgObj.SetBbsName(BN: String);
  Begin
  MKCfg^.SystemName := Copy(BN, 1, 40);
  End;


Function MKCfgObj.GetBbsLoc: String;
  Begin
  GetBbsLoc := MKCfg^.BbsLocation;
  End;


Procedure MKCfgObj.SetBbsLoc(BL: String);
  Begin
  MKCfg^.BbsLocation := Copy(BL, 1, 40);
  End;


Function MKCfgObj.GetBbsPhone: String;
  Begin
  GetBbsPhone := MKCfg^.BbsPhone;
  End;


Procedure MKCfgObj.SetBbsPhone(BPhone: String);
  Begin
  MKCfg^.BbsPhone := Copy(BPhone, 1, 15);
  End;


Function MKCfgObj.GetBbsId: String;
  Begin
  GetBbsId := MKCfg^.BoardId;
  End;


Procedure MKCfgObj.SetBbsId(BId: String);
  Begin
  MKCfg^.BoardId := Copy(BId, 1, 08);
  End;


Function MKCfgObj.GetDirectWrite: Boolean;
  Begin
  GetDirectWrite := ((MKCfg^.COption And coDirect) <> 0);
  End;


Procedure MKCfgObj.SetDirectWrite(DW: Boolean);
  Begin
  If DW Then
    MKCfg^.COption := MKCfg^.COption Or coDirect
  Else
    MKCfg^.COption := MKCfg^.COption And (Not coDirect);
  End;


Function MKCfgObj.GetSnowCheck: Boolean;
  Begin
  GetSnowCheck := ((MKCfg^.COption and coSnowCheck) <> 0);
  End;


Procedure MKCfgObj.SetSnowCheck(SC: Boolean);
  Begin
  If SC Then
    MKCfg^.COption := MKCfg^.COption Or coSnowCheck
  Else
    MKCfg^.COption := MKCfg^.COption And (Not coSnowCheck);
  End;


Function MKCfgObj.GetMonoMode: Boolean;
  Begin
  GetMonoMode := ((MKCfg^.COption and coMono) <> 0);
  End;


Procedure MKCfgObj.SetMonoMode(MM: Boolean);
  Begin
  If MM Then
    MKCfg^.COption := MKCfg^.COption Or coMono
  Else
    MKCfg^.COption := MKCfg^.COption And (Not coMono);
  End;


Function MKCfgObj.GetForceKillYes: Boolean;
  Begin
  GetForceKillYes := ((MKCfg^.COption and coKillSentYes) <> 0);
  End;


Procedure MKCfgObj.SetForceKillYes(FK: Boolean);
  Begin
  If FK Then
    MKCfg^.COption := MKCfg^.COption or coKillSentYes
  Else
    MKCfg^.COPtion := MKCfg^.COption and (Not coKillSentYes);
  End;


Function MKCfgObj.GetForceKillAsk: Boolean;
  Begin
  GetForceKillAsk := ((MKCfg^.COption and coKillSentAsk) <> 0);
  End;


Procedure MKCfgObj.SetForceKillAsk(FK: Boolean);
  Begin
  If FK Then
    MKCfg^.COption := MKCfg^.COption or coKillSentAsk
  Else
    MKCfg^.COPtion := MKCfg^.COption and (Not coKillSentAsk);
  End;


Function MKCfgObj.GetPageStart(DayNo: Byte): Word;
  Begin
  GetPageStart := MKCfg^.PageStart[DayNo];
  End;


Procedure MKCfgObj.SetPageStart(DayNo: Byte; St: Word);
  Begin
  MKCfg^.PageStart[DayNo] := St;
  End;


Function MKCfgObj.GetPageStop(DayNo: Byte): Word;
  Begin
  GetPageStop := MKCfg^.PageStop[DayNo];
  End;


Procedure MKCfgObj.SetPageStop(DayNo: Byte; St: Word);
  Begin
  MKCfg^.PageStop[DayNo] := St;
  End;


Function MKCfgObj.GetMaxPageTimes: Word;
  Begin
  GetMaxPageTimes := MKCfg^.MaxPages;
  End;


Procedure MKCfgObj.SetMaxPageTimes(Pg: Word);
  Begin
  If Pg > 255 Then
    Pg := 255;
  MKCfg^.MaxPages := Pg;
  End;


Function MKCfgObj.GetPageMsgArea: Word;
  Begin
  GetPageMsgArea:= MKCfg^.PageMsgArea;
  End;


Procedure MKCfgObj.SetPageMsgArea(Pg: Word);
  Begin
  MKCfg^.PageMsgArea := Pg;
  End;


Function MKCfgObj.GetPageLength: Byte;
  Begin
  GetPageLength := MKCfg^.PageLength;
  End;


Procedure MKCfgObj.SetPageLength(PL: Byte);
  Begin
  MKCfg^.PageLength := PL;
  End;


Function MKCfgObj.GetDefaultPage: Byte;
  Begin
  GetDefaultPage := MKCfg^.DefPage;
  End;


Procedure MKCfgObj.SetDefaultPage(DP: Byte);
  Begin
  MKCfg^.DefPage := DP;
  End;


Function MKCfgObj.GetAskPageReason: Boolean;
  Begin
  GetAskPageReason := (MKCfg^.COption2 And csPageReason) <> 0;
  End;


Procedure MKCfgObj.SetAskPageReason(AP: Boolean);
  Begin
  If AP Then
    MKCfg^.COPtion2 := MKCfg^.COption2 Or csPageReason
  Else
    MKCfg^.COption2 := MKCfg^.COption2 And (not csPageReason);
  End;


Function MKCfgObj.GetMailCheckDetail: Boolean;
  Begin
  GetMailCheckDetail := (MKCfg^.COption2 And csMailCheckDetail) <> 0;
  End;


Procedure MKCfgObj.SetMailCheckDetail(MC: Boolean);
  Begin
  If MC Then
    MKCfg^.COPtion2 := MKCfg^.COption2 Or csMailCheckDetail
  Else
    MKCfg^.COption2 := MKCfg^.COption2 And (not csMailCheckDetail);
  End;


Function MKCfgObj.GetMailCheckTotal: Boolean;
  Begin
  GetMailCheckTotal := (MKCfg^.COption2 And csMailCheckTotal) <> 0;
  End;


Procedure MKCfgObj.SetMailCheckTotal(MC: Boolean);
  Begin
  If MC Then
    MKCfg^.COPtion2 := MKCfg^.COption2 Or csMailCheckTotal
  Else
    MKCfg^.COption2 := MKCfg^.COption2 And (not csMailCheckTotal);
  End;


Procedure MKCfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := MKMsg^[Area].ReadSec.Level;
    Sec.Flags := MKMsg^[Area].ReadSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKCfgObj.SetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].ReadSec.Level := Sec.Level;
    MKMsg^[Area].ReadSec.Flags := Sec.Flags;
    End;
  End;


Procedure MKCfgObj.SetMsgWriteSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].WriteSec.Level := Sec.Level;
    MKMsg^[Area].WriteSec.Flags := Sec.Flags;
    End;
  End;


Procedure MKCfgObj.SetMsgSysopSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].SysopSec.Level := Sec.Level;
    MKMsg^[Area].SysopSec.Flags := Sec.Flags;
    End;
  End;


Procedure MKCfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := MKMsg^[Area].WriteSec.Level;
    Sec.Flags := MKMsg^[Area].WriteSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKCfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    Sec.Level := MKMsg^[Area].SysopSec.Level;
    Sec.Flags := MKMsg^[Area].SysopSec.Flags;
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function MKCfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPriv := (MKMsg^[Area].Permit and mpPriv) <> 0
  Else
    MsgAllowPriv := True;
  End;



Procedure MKCfgObj.SetMsgAllowPriv(Area: Word; Priv: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].Permit := (MKMsg^[Area].Permit and (Not mpPriv));
    If Priv Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpPriv;
    End;
  End;


Procedure MKCfgObj.SetMsgAllowPubl(Area: Word; Publ: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].Permit := (MKMsg^[Area].Permit and (Not mpPubl));
    If Publ Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpPubl;
    End;
  End;


Function MKCfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowPubl := (MKMsg^[Area].Permit and mpPubl) <> 0
  Else
    MsgAllowPubl := True;
  End;


Function MKCfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowReal := (MKMsg^[Area].Permit and mpRealName) <> 0
  Else
    MsgAllowReal := True;
  End;


Procedure MKCfgObj.SetMsgAllowReal(Area: Word; RName: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].Permit := (MKMsg^[Area].Permit and (Not mpRealName));
    If RName Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpRealName;
    End;
  End;


Procedure MKCfgObj.SetMsgAllowHdl(Area: Word; Hdl: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].Permit := (MKMsg^[Area].Permit and (Not mpAlias));
    If Hdl Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpAlias;
    End;
  End;


Procedure MKCfgObj.SetMsgAllowAnon(Area: Word; Anon: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    Begin
    If Anon Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit Or mpAnon
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit And (Not mpAnon);
    End;
  End;



Function MKCfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowHdl := (MKMsg^[Area].Permit and mpAlias) <> 0
  Else
    MsgAllowHdl := False;
  End;


Function MKCfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows anonymous}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowAnon := (MKMsg^[Area].Permit and mpAnon) <> 0
  Else
    MsgAllowAnon := False;
  End;


Function MKCfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAddFido := (MKMsg^[Area].Permit and mpFido) <> 0
  Else
    MsgAddFido := True;
  End;



Procedure MKCfgObj.SetMsgAddFido(Area: Word; Fido: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Fido Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit Or mpFido
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit And (Not mpFido);
  End;


Function MKCfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowAnsi := (MKMsg^[Area].Permit and mpAnsi) <> 0
  Else
    MsgAllowAnsi := False;
  End;


Procedure MKCfgObj.SetMsgAllowAnsi(Area: Word; Ansi: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Ansi Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpAnsi
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (Not mpAnsi);
  End;


Function MKCfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MsgAllowHiBit := (MKMsg^[Area].Permit and mpHiBit) <> 0
  Else
    MsgAllowHiBit := False;
  End;


Procedure MKCfgObj.SetMsgAllowHiBit(Area: Word; HiBit: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMSgAreas)) Then
    If HiBit Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpHiBit
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (Not mpHiBit);
  End;


Function MKCfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Begin
  If ((Area > 0) and (Area <= GetMaxMSgAreas)) Then
    MsgAllowTag := (MKMsg^[Area].Permit and mpTagLines) <> 0
  Else
    MsgAllowTag := False;
  End;


Procedure MKCfgObj.SetMsgAllowTag(Area: Word; Tag: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If Tag Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpTaglines
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (Not mpTagLines);
  End;


Function MKCfgObj.GetMsgReaderTear(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgReaderTear := (MKMsg^[Area].Permit and mpTear) <> 0
  Else
    GetMsgReaderTear := False;
  End;


Procedure MKCfgObj.SetMsgReaderTear(Area: Word; RT: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If RT Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpTear
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (Not mpTear);
  End;


Function MKCfgObj.GetMsgReaderOrig(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgReaderOrig := (MKMsg^[Area].Permit and mpOrg) <> 0
  Else
    GetMsgReaderOrig := False;
  End;


Procedure MKCfgObj.SetMsgReaderOrig(Area: Word; RT: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If RT Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpOrg
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (Not mpOrg);
  End;


Function MKCfgObj.GetMsgFAttach(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgFAttach := (MKMsg^[Area].Permit and mpFileAttach) <> 0
  Else
    GetMsgFAttach := False;
  End;


Procedure MKCfgObj.SetMsgFAttach(Area: Word; FA: Boolean);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    If FA Then
      MKMsg^[Area].Permit := MKMsg^[Area].Permit or mpFileAttach
    Else
      MKMsg^[Area].Permit := MKMsg^[Area].Permit and (Not mpFileAttach);
  End;


Function MKCfgObj.GetMsgSelect(Area: Word): String;
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    GetMsgSelect := MKMsg^[Area].Select
  Else
    GetMsgSelect := '';
  End;


Procedure MKCfgObj.SetMsgSelect(Area: Word; Sel: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].Select := Sel;
  End;



Function MKCfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  GetMaxFileAreas := 300;
  End;


Function MKCfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    GetFileAreaName := MKFile^[Area].Name
  Else
    GetFileAreaName := '';
  End;


Procedure MKCfgObj.SetFileAreaName(Area: Word; Name: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    MKFile^[Area].Name := Name;
  End;


Function MKCfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    Begin
    If Length(MKFile^[Area].ShortName) > 0 Then
      GetFileShortName := MKFile^[Area].ShortName
    Else
      GetFileShortName := Copy(GetFileAreaName(Area),1 , 12);
    End
  Else
    GetFileShortName := '';
  End;


Procedure MKCfgObj.SetFileShortName(Area: Word; Nm: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    MKFile^[Area].ShortName := Copy(Nm, 1, 12);
  End;


Function MKCfgObj.GetFileSelect(Area: Word): String;
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileSelect := MKFile^[Area].Select
  Else
    GetFileSelect := '';
  End;


Procedure MKCfgObj.SetFileSelect(Area: Word; SN: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Case CfgInfo^.BbsType of
      1: MKFile^[Area].Select := Copy(SN, 1, 4);
      End;
    End;
  End;


Function MKCfgObj.GetFileAreaPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <=GetMaxFileAreas)) Then
    Begin
    TmpStr := MKFile^[Area].FilePath;
    AddBackSlash(TmpStr);
    GetFileAreaPath := TmpStr;
    End
  Else
    GetFileAreaPath := '';
  End;


Procedure MKCfgObj.SetFileAreaPath(Area: Word; FPath: String);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    MKFile^[Area].FilePath := FPath;
  End;


Function MKCfgObj.GetFileListPath(Area: Word): String; {Get file area path}
  Var
    TmpStr: String;

  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    TmpStr := MKFile^[Area].FilePath;
    AddBackSlash(TmpStr);
    TmpStr := TmpStr + 'files.bbs';
    GetFileListPath := TmpStr;
    End
  Else
    GetFileListPath := '';
  End;


Procedure MKCfgObj.GetFileViewSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := MKFile^[Area].ViewSec.Level;
    Sec.Flags := MKFile^[Area].ViewSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKCfgObj.SetFileViewSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    MKFile^[Area].ViewSec.Level := Sec.Level;
    MKFile^[Area].ViewSec.Flags := Sec.Flags;
    End;
  End;


Procedure MKCfgObj.GetFileDLSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := MKFile^[Area].DLSec.Level;
    Sec.Flags := MKFile^[Area].DLSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKCfgObj.SetFileDLSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    MKFile^[Area].DLSec.Level := Sec.Level;
    MKFile^[Area].DLSec.Flags := Sec.Flags;
    End;
  End;


Procedure MKCfgObj.GetFileULSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := MKFile^[Area].ULSec.Level;
    Sec.Flags := MKFile^[Area].ULSec.Flags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure MKCfgObj.SetFileULSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    MKFile^[Area].ULSec.Level := Sec.Level;
    MKFile^[Area].ULSec.Flags := Sec.Flags;
    End;
  End;


Procedure MKCfgObj.GetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private files security}
  Begin
  If ((Area > 0) and (Area <= GetMaxFileAreas)) Then
    Begin
    Sec.Level := MKFile^[Area].PFileSec.Level;
    Sec.Flags := MKFile^[Area].PFileSec.Flags;
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Procedure MKCfgObj.SetFilePvtSecurity(Area: Word; Var Sec: SecType);
  Begin
  If ((Area > 0) and (area <= GetMaxFileAreas)) Then
    Begin
    MKFile^[Area].PFileSec.Level := Sec.Level;
    MKFile^[Area].PFileSec.Flags := Sec.Flags;
    End;
  End;


Function MKCfgObj.GetFileNoUl(Area: Word): Boolean; {Area disallows ULs}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoUl := (MKFile^[Area].Attr And faNoUl) <> 0
  Else
    GetFileNoUl := True;
  End;


Function MKCfgObj.GetFileFreq(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileFreq := (MKFile^[Area].Attr And faFreq) <> 0
  Else
    GetFileFreq := False;
  End;


Procedure MKCfgObj.SetFileFreq(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    If St Then
      MKFile^[Area].Attr := MKFile^[Area].Attr or faFreq
    Else
      MKFile^[Area].Attr := MKFile^[Area].Attr and (Not faFreq);
  End;


Function MKCfgObj.GetFileNoNew(Area: Word): Boolean; {Exclude area from new files}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoNew := (MKFile^[Area].Attr And faNoNew) <> 0
  Else
    GetFileNoNew := True;
  End;


Function MKCfgObj.GetFileFree(Area: Word): Boolean; {Area contains free files}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileFree := (MKFile^[Area].Attr And faFree) <> 0
  Else
    GetFileFree := False;
  End;


Function MKCfgObj.GetFileNoTime(Area: Word): Boolean; {Ignore time remaining}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoTime := (MKFile^[Area].Attr And faNoTime) <> 0
  Else
    GetFileNoTime := False;
  End;


Function MKCfgObj.GetFileNoBaud(Area: Word): Boolean; {Ignore min baud limits}
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    GetFileNoBaud := (MKFile^[Area].Attr And faNoBaud) <> 0
  Else
    GetFileNoBaud := False;
  End;


Procedure MKCfgObj.SetFileNoUl(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    If St Then
      MKFile^[Area].Attr := MKFile^[Area].Attr or faNoUL
    Else
      MKFile^[Area].Attr := MKFile^[Area].Attr and (Not faNoUL);
  End;


Procedure MKCfgObj.SetFileNoNew(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    If St Then
      MKFile^[Area].Attr := MKFile^[Area].Attr or faNoNew
    Else
      MKFile^[Area].Attr := MKFile^[Area].Attr and (Not faNoNew);
  End;


Procedure MKCfgObj.SetFileFree(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    If St Then
      MKFile^[Area].Attr := MKFile^[Area].Attr or faFree
    Else
      MKFile^[Area].Attr := MKFile^[Area].Attr and (Not faFree);
  End;


Procedure MKCfgObj.SetFileNoTime(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    If St Then
      MKFile^[Area].Attr := MKFile^[Area].Attr or faNoTime
    Else
      MKFile^[Area].Attr := MKFile^[Area].Attr and (Not faNoTime);
  End;


Procedure MKCfgObj.SetFileNoBaud(Area: Word; St: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxFileAreas)) Then
    If St Then
      MKFile^[Area].Attr := MKFile^[Area].Attr or faNoBaud
    Else
      MKFile^[Area].Attr := MKFile^[Area].Attr and (Not faNoBaud);
  End;



Function MKCfgObj.FileViewAccess(Area: Word; Sec: SecType): Boolean; {Can view files}
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


Function MKCfgObj.FileDLAccess(Area: Word; Sec: SecType): Boolean; {Can download files}
  Var
    AreaSec: SecType;

  Begin
  GetFileDLSecurity(Area, AreaSec);
  FileDLAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileDLAccess := False;
  End;


Function MKCfgObj.FileULAccess(Area: Word; Sec: SecType): Boolean; {Can upload files}
  Var
    AreaSec: SecType;

  Begin
  GetFileULSecurity(Area, AreaSec);
  FileULAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FileULAccess := False;
  End;


Function MKCfgObj.FilePvtAccess(Area: Word; Sec: SecType): Boolean; {Private files}
  Var
    AreaSec: SecType;

  Begin
  GetFilePvtSecurity(Area, AreaSec);
  FilePvtAccess := Access(Sec, AreaSec);
  If (Length(GetFileAreaPath(Area)) = 0) Then
    FilePvtAccess := False;
  End;


Function MKCfgObj.GetLangName(LNum: Word): String;
  Begin
  If ((LNum > 0) and (LNum < 11)) Then
    GetLangName := MKCfg^.LangName[LNum]
  Else
    GetLangName := 'PROMPTS';
  End;


Procedure MKCfgObj.SetLangName(LNum: Word; Name: String);
  Begin
  If ((LNum > 0) And (LNum < 11)) Then
    MKCfg^.LangName[LNum] := Copy(Name, 1, 10);
  End;


Function MKCfgObj.GetLangFile(LNum: Word): String;
  Begin
  If ((LNum > 0) and (LNum < 11)) Then
    GetLangFile := MKCfg^.LangFile[LNum]
  Else
    GetLangFile := 'prompts';
  End;


Procedure MKCfgObj.SetLangFile(LNum: Word; FName: String);
  Begin
  If ((LNum > 0) And (LNum < 11)) Then
    MKCfg^.LangFile[LNum] := Copy(FName, 1, 8);
  End;


Function MKCfgObj.GetLangQuesPath(LNum: Word): String;
  Begin
  If ((LNum > 0) and (LNum < 11)) Then
    GetLangQuesPath := MKCfg^.QuesPath[LNum]
  Else
    GetLangQuesPath := GetBbsPath;
  End;


Procedure MKCfgObj.SetLangQuesPath(LNum: Word; QPath: String);
  Begin
  If ((LNum > 0) And (LNum < 11)) Then
    MKCfg^.QuesPath[LNum] := Copy(QPath, 1, 60);
  End;


Function MKCfgObj.GetAskVoicePhone: Boolean;
  Begin
  GetAskVoicePhone := (MKCfg^.NewOpt and noAskHome) <> 0;
  End;


Procedure MKCfgObj.SetAskVoicePhone(VP: Boolean);
  Begin
  If VP Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noAskHome
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noAskHome);
  End;


Function MKCfgObj.GetAskDataPhone: Boolean;
  Begin
  GetAskDataPhone := (MKCfg^.NewOpt and noAskData) <> 0;
  End;


Procedure MKCfgObj.SetAskDataPhone(DP: Boolean);
  Begin
  If DP Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noAskData
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noAskData);
  End;


Function MKCfgObj.GetNewUserNMCredit: Word;
  Begin
  GetNewUserNMCredit := MKCfg^.NewCredit;
  End;


Procedure MKCfgObj.SetNewUserNMCredit(NM: Word);
  Begin
  MKCfg^.NewCredit := NM;
  End;


Function MKCfgObj.GetAskBirthdate: Boolean;
  Begin
  GetAskBirthdate := (MKCfg^.NewOpt and noAskBirth) <> 0;
  End;


Procedure MKCfgObj.SetAskBirthdate(AB: Boolean);
  Begin
  If AB Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noAskBirth
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noAskBirth);
  End;


Function MKCfgObj.GetAskGender: Boolean;
  Begin
  GetAskGender := (MKCfg^.NewOpt and noAskGender) <> 0;
  End;


Procedure MKCfgObj.SetAskGender(AG: Boolean);
  Begin
  If AG Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noAskGender
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noAskGender);
  End;


Function MKCfgObj.GetAskAddr: Boolean;
  Begin
  GetAskAddr := (MKCfg^.NewOpt and noAskAddr) <> 0;
  End;


Procedure MKCfgObj.SetAskAddr(AA: Boolean);
  Begin
  If AA Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noAskAddr
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noAskAddr);
  End;


Function MKCfgObj.GetSevenBitNames: Boolean;
  Begin
  GetSevenBitNames := (MKCfg^.NewOpt and no7BitName) <> 0;
  End;


Procedure MKCfgObj.SetSevenBitNames (SB: Boolean);
  Begin
  If SB Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or no7BitName
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not no7BitName);
  End;


Function MKCfgObj.GetOneWordName: Boolean;
  Begin
  GetOneWordName := (MKCfg^.NewOpt and noOneWord) <> 0;
  End;


Procedure MKCfgObj.SetOneWordName(OW: Boolean);
  Begin
  If OW Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noOneWord
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noOneWord);
  End;


Function MKCfgObj.GetReAsk: Boolean;
  Begin
  GetReAsk := (MKCfg^.NewOpt and noReAsk) <> 0;
  End;


Procedure MKCfgObj.SetReAsk(RA: Boolean);
  Begin
  If RA Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noReAsk
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noReAsk);
  End;


Function MKCfgObj.GetAskHandle: Boolean; {Ask user for handle}
  Begin
  GetAskHandle := (MKCfg^.NewOpt and noAskHandle) <> 0;
  End;


Procedure MKCfgObj.SetAskHandle(AH: Boolean); {Set ask user for handle}
  Begin
  If AH Then
    MKCfg^.NewOpt := MKCfg^.NewOpt or noAskHandle
  Else
    MKCfg^.NewOpt := MKCfg^.NewOpt and (Not noAskHandle);
  End;


Procedure MKCfgObj.GetEchoToAddr(ES: Word; Var Addr: AddrType);
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


Procedure MKCfgObj.SetEchoToAddr(ES: Word; Addr: AddrType);
  Begin
  If ((ES > 0) and (ES < 33)) Then
    MKEcho^.EchoSys[ES].Addr := Addr;
  End;


Function MKCfgObj.GetEchoToPwd(ES: Word): String;
  Begin
  If ((ES > 0) and (ES < 33)) Then
    GetEchoToPwd := MKEcho^.EchoSys[ES].Pwd
  Else
    GetEchoToPwd := '';
  End;


Procedure MKCfgObj.SetEchoToPwd(ES: Word; Pwd: String);
  Begin
  If ((ES > 0) and (ES < 33)) Then
    MKEcho^.EchoSys[ES].Pwd := Pwd;
  End;


Function MKCfgObj.GetEchoToPacker(ES: Word): Byte;
  Begin
  If ((ES > 0) and (ES < 33)) Then
    GetEchoToPacker := MKEcho^.EchoSys[ES].Archiver
  Else
    GetEchoToPacker := 1;
  End;


Procedure MKCfgObj.SetEchoToPacker(ES: Word; Pk: Byte);
  Begin
  If ((ES > 0) and (ES < 33)) Then
    MKEcho^.EchoSys[ES].Archiver := Pk;
  End;


Function MKCfgObj.GetEchoToNetwork(ES: Word; Nt: Word): Boolean;
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


Procedure MKCfgObj.SetEchoToNetwork(ES: Word; Nt: Word; St: Boolean);
  Var
    Mask: LongInt;

  Begin
  If ((ES > 0) and (ES < 33) And (NT > 0) And (Nt < 33)) Then
    Begin
    Mask := 1;
    Mask := Mask shl (Nt - 1);
    If St Then
      MKEcho^.EchoSys[ES].Networks := (MKEcho^.EchoSys[ES].Networks Or Mask)
    Else
      MKEcho^.EchoSys[ES].Networks := (MKEcho^.EchoSys[ES].Networks And (Not Mask));
    End;
  End;


Function MKCfgObj.GetEchoToMailType(ES: Word): Byte;
  Begin
  If ((ES > 0) and (ES < 33)) Then
    GetEchoToMailType := MKEcho^.EchoSys[ES].Attr and 7
  Else
    GetEchoToMailType := 2;
  End;


Procedure MKCfgObj.SetEchoToMailType(ES: Word; MT: Byte);
  Begin
  If ((ES > 0) and (ES < 33)) Then
    MKEcho^.EchoSys[ES].Attr := (MKEcho^.EchoSys[ES].Attr and Not 7) or (Mt and 7);
  End;


Function MKCfgObj.GetEchoToArea(ES: Word; Area: Word): Boolean;
  Begin
  If ((ES > 0) And (ES < 33) And (Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoToArea := (MKEcho^.EchoArea[Area].EchoTo and (LongInt(1) shl (ES - 1))) <> 0
  Else
    GetEchoToArea := False;
  End;


Procedure MKCfgObj.SetEchoToArea(ES: Word; Area: Word; SA: Boolean);
  Begin
  If ((ES > 0) And (ES < 33) And (Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    If SA Then
      MKEcho^.EchoArea[Area].EchoTo := (MKEcho^.EchoArea[Area].EchoTo Or
      (LongInt(1) shl (ES - 1)))
    Else
      MKEcho^.EchoArea[Area].EchoTo := (MKEcho^.EchoArea[Area].EchoTo And
      (Not(1 shl (ES - 1))));
    End;
  End;


Function MKCfgObj.GetEchoAreaPassThru(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaPassThru := (MKEcho^.EchoArea[Area].Attr and eaPassThru) <> 0
  Else
    GetEchoAreaPassThru := False;
  End;


Procedure MKCfgObj.SetEchoAreaPassThru(Area: Word; PT: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    If PT Then
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr or eaPassThru
    Else
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr and (Not eaPassThru);
    End;
  End;


Function MKCfgObj.GetEchoAreaImportPath(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaImportPath := (MKEcho^.EchoArea[Area].Attr and eaKeepPath) <> 0
  Else
    GetEchoAreaImportPath := True;
  End;


Procedure MKCfgObj.SetEchoAreaImportPath(Area: Word; IP: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    If IP Then
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr or eaKeepPath
    Else
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr and (Not eaKeepPath);
    End;
  End;


Function MKCfgObj.GetEchoAreaHidePath(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaHidePath := (MKEcho^.EchoArea[Area].Attr and eaHidePath) <> 0
  Else
    GetEchoAreaHidePath := True;
  End;


Procedure MKCfgObj.SetEchoAreaHidePath(Area: Word; HP: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    If HP Then
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr or eaHidePath
    Else
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr and (Not eaHidePath);
    End;
  End;


Function MKCfgObj.GetEchoAreaImportSeen(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaImportSeen := (MKEcho^.EchoArea[Area].Attr and eaKeepSeen) <> 0
  Else
    GetEchoAreaImportSeen := False;
  End;


Procedure MKCfgObj.SetEchoAreaImportSeen(Area: Word; ISB: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    If ISB Then
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr or eaKeepSeen
    Else
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr and (Not eaKeepSeen);
    End;
  End;


Function MKCfgObj.GetEchoAreaHideSeen(Area: Word): Boolean;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaHideSeen := (MKEcho^.EchoArea[Area].Attr and eaHideSeen) <> 0
  Else
    GetEchoAreaHideSeen := True;
  End;


Procedure MKCfgObj.SetEchoAreaHideSeen(Area: Word; HS: Boolean);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    If HS Then
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr or eaHideSeen
    Else
      MKEcho^.EchoArea[Area].Attr := MKEcho^.EchoArea[Area].Attr and (Not eaHideSeen);
    End;
  End;


Function MKCfgObj.GetEchoToHub(Area: Word): Byte;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoToHub := MKEcho^.EchoArea[Area].Hub
  Else
    GetEchoToHub := 1;
  End;


Procedure MKCfgObj.SetEchoToHub(Area: Word; Hub: Byte);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    MKEcho^.EchoArea[Area].Hub := Hub;
  End;


Function MKCfgObj.GetEchoMaxPkt: LongInt;
  Begin
  GetEchoMaxPkt := MKEcho^.MaxPktSize;
  End;


Procedure MKCfgObj.SetEchoMaxPkt(MP: LongInt);
  Begin
  MKEcho^.MaxPktSize := MP;
  End;


Function MKCfgObj.HasMailer: Boolean;
  Begin
  HasMailer := True;
  End;


Procedure MKCfgObj.GetMailer(Var M: MailerCfgType);
  Begin
  M := MKMail^;
  End;


Procedure MKCfgObj.SetMailer(Var M: MailerCfgType);
  Begin
  MKMail^ := M;
  MKMail^.Version := MailerCfgVersion;
  End;


Function MKCfgObj.HasEventExt: Boolean;
  Begin
  HasEventExt := True;
  End;


Procedure MKCfgObj.GetEventExt(Var E: EventsCfgType);
  Begin
  E := MKEvents^;
  End;


Procedure MKCfgObj.SetEventExt(Var E: EventsCfgType);
  Begin
  MKEvents^ := E;
  MKEvents^.Version := EventsCfgVersion;
  End;


Function MKCfgObj.GetEchoInPath: String;
  Begin
  GetEchoInPath := MKEcho^.InBoundFiles;
  End;


Procedure MKCfgObj.SetEchoInPath(EP: String);
  Begin
  MKEcho^.InBoundFiles := EP;
  End;


Function MKCfgObj.GetEchoOutPath: String;
  Begin
  GetEchoOutPath := MKEcho^.OutBoundFiles;
  End;


Procedure MKCfgObj.SetEchoOutPath(EP: String);
  Begin
  MKEcho^.OutBoundFiles := EP;
  End;


Function MKCfgObj.GetEchoAreaTag(Area: Word): String;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetEchoAreaTag := MKEcho^.EchoArea[Area].AreaTag
  Else
    GetEchoAreaTag := '';
  End;


Procedure MKCfgObj.SetEchoAreaTag(Area: Word; Tag: String);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    MKEcho^.EchoArea[Area].AreaTag := Tag;
  End;


Function MKCfgObj.GetPwdTries: Byte;
  Begin
  GetPwdTries := MKCfg^.PassTries;
  End;


Procedure MKCfgObj.SetPwdTries(PT: Byte);
  Begin
  MKCfg^.PassTries := PT;
  End;


Function MKCfgObj.GetPwdExpire: Word;
  Begin
  GetPwdExpire := MKCfg^.PwdExpire;
  End;


Procedure MKCfgObj.SetPwdExpire(PE: Word);
  Begin
  MKCfg^.PwdExpire := PE;
  End;


Function MKCfgObj.GetBDCheck: Byte;
  Begin
  GetBDCheck := MKCfg^.CheckBD;
  End;


Procedure MKCfgObj.SetBDCheck(BD: Byte);
  Begin
  MKCfg^.CheckBD := BD;
  End;


Function MKCfgObj.GetPhoneCheck: Byte;
  Begin
  GetPhoneCheck := MKCfg^.CheckPhone;
  End;


Procedure MKCfgObj.SetPhoneCheck(PC: Byte);
  Begin
  MKCfg^.CheckPhone := PC;
  End;


Function MKCfgObj.GetMinPwd: Byte;
  Begin
  GetMinPwd := MKCfg^.MinPwd;
  End;


Procedure MKCfgObj.SetMinPwd(MP: Byte);
  Begin
  MKCfg^.MinPwd := MP;
  End;


Function MKCfgObj.GetMinPhone: Byte;
  Begin
  GetMinPhone := MKCfg^.MinPhone;
  End;


Procedure MKCfgObj.SetMinPhone(MP: Byte);
  Begin
  MKCfg^.MinPhone := MP;
  End;


Function MKCfgObj.GetStrictPwd: Boolean;
  Begin
  GetStrictPwd := (MKCfg^.COption and coStrictPwd) <> 0;
  End;


Procedure MKCfgObj.SetStrictPwd(SP: Boolean);
  Begin
  If SP Then
    MKCfg^.COption := MKCfg^.COption or coStrictPwd
  Else
    MKCfg^.COption := MKCfg^.COption and (Not coStrictPwd);
  End;


Function MKCfgObj.GetPwdMode: Byte;
  Begin
  If (MKCfg^.COption2 And csPwdConvert) <> 0 Then
    GetPwdMode := 2
  Else If (MKCfg^.COption2 And csPwdHash) <> 0 Then
    GetPwdMode := 1
  Else
    GetPwdMode := 0;
  End;


Procedure MKCfgObj.SetPwdMode(PM: Byte);
  Begin
  MKCfg^.COption2 := MKCfg^.COption2 And (Not (csPwdHash Or csPwdConvert));
  If PM = 1 Then
    MKCfg^.COption2 := MKCfg^.COption2 Or csPwdHash
  Else If PM >= 2 Then
    MKCfg^.COption2 := MKCfg^.COption2 Or csPwdConvert;
  End;


Function MKCfgObj.GetRemoteSysop: Boolean;
  Begin
  GetRemoteSysop := (MKCfg^.COption and coAllowSysRemote) <> 0;
  End;


Procedure MKCfgObj.SetRemoteSysop(RS: Boolean);
  Begin
  If RS Then
    MKCfg^.COption := MKCfg^.COption or coAllowSysRemote
  Else
    MKCfg^.COption := MKCfg^.COption and (Not coAllowSysRemote);
  End;


Function MKCfgObj.GetFastLocal: Boolean;
  Begin
  GetFastLocal := (MKCfg^.COption and coFastLogIn) <> 0;
  End;


Procedure MKCfgObj.SetFastLocal(FL: Boolean);
  Begin
  If FL Then
    MKCfg^.COption := MKCfg^.COption or coFastLogIn
  Else
    MKCfg^.COption := MKCfg^.COption and (Not coFastLogIn);
  End;


Procedure MKCfgObj.GetNewUserSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.NewSec;
  End;


Procedure MKCfgObj.SetNewUserSec(Sec: SecType);
  Begin
  MKCfg^.NewSec := Sec;
  End;


Procedure MKCfgObj.GetAttachSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.FAttachSec;
  End;


Procedure MKCfgObj.SetAttachSec(Sec: SecType);
  Begin
  MKCfg^.FAttachSec := Sec;
  End;


Procedure MKCfgObj.GetRequestSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.FReqSec;
  End;


Procedure MKCfgObj.SetRequestSec(Sec: SecType);
  Begin
  MKCfg^.FReqSec := Sec;
  End;


Procedure MKCfgObj.GetCrashNmSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.CrashSec;
  End;


Procedure MKCfgObj.SetCrashNmSec(Sec: SecType);
  Begin
  MKCfg^.CrashForce := Sec;
  End;


Procedure MKCfgObj.GetForceCrashNmSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.CrashForce;
  End;


Procedure MKCfgObj.SetForceCrashNmSec(Sec: SecType);
  Begin
  MKCfg^.CrashForce := Sec;
  End;


Procedure MKCfgObj.GetDeleteSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.MsgDelSec;
  End;


Procedure MKCfgObj.SetDeleteSec(Sec: SecType);
  Begin
  MKCfg^.MsgDelSec := Sec;
  End;


Procedure MKCfgObj.GetUnRcvSec(Var Sec: SecType);
  Begin
  Sec := MKCfg^.MsgNoRcv;
  End;


Procedure MKCfgObj.SetUnRcvSec(Sec: SecType);
  Begin
  MKCfg^.MsgNoRcv := Sec;
  End;


Function MKCfgObj.GetModemResp(MR: Byte): String;
  Begin
  If ((MR > 0) And (MR < 12)) Then
    GetModemResp := MKCfg^.ConnectStr[MR]
  Else
    GetModemResp := '';
  End;


Procedure MKCfgObj.SetModemResp(MR: Byte; Resp: String);
  Begin
  If ((MR > 0) And (MR < 12)) Then
    MKCfg^.ConnectStr[MR] := Resp;
  End;


Function MKCfgObj.GetErrorLevel(MR: Byte): Byte;
  Begin
  If ((MR > 0) And (MR < 12)) Then
    GetErrorLevel := MKCfg^.ExitEL[MR]
  Else
    GetErrorLevel := 0;
  End;


Procedure MKCfgObj.SetErrorLevel(MR: Byte; EL: Byte);
  Begin
  If ((MR > 0) And (MR < 12)) Then
    MKCfg^.ExitEL[MR] := EL;
  End;


Function MKCfgObj.GetDLStart: Word;
  Begin
  GetDLStart := MKCfg^.DLStart;
  End;


Procedure MKCfgObj.SetDLStart(ST: Word);
  Begin
  MKCfg^.DLStart := St;
  End;


Function MKCfgObj.GetDLStop: Word;
  Begin
  GetDLStop := MKCfg^.DLStop;
  End;


Procedure MKCfgObj.SetDLStop(ST: Word);
  Begin
  MKCfg^.DLStop := St;
  End;


Function MKCfgObj.GetLoBaudStart: Word;
  Begin
  GetLoBaudStart := MKCfg^.LoBaudStart;
  End;


Procedure MKCfgObj.SetLoBaudStart(ST: Word);
  Begin
  MKCfg^.LoBaudStart := St;
  End;


Function MKCfgObj.GetLoBaudStop: Word;
  Begin
  GetLoBaudStop := MKCfg^.LoBaudStop;
  End;


Procedure MKCfgObj.SetLoBaudStop(ST: Word);
  Begin
  MKCfg^.LoBaudStop := St;
  End;


Function MKCfgObj.GetMinXferBaud: Word;
  Begin
  GetMinXferBaud := MKCfg^.XferBaud;
  End;


Procedure MKCfgObj.SEtMinXferBaud(MB: Word);
  Begin
  MKCfg^.XferBaud := MB;
  End;


Function MKCfgObj.GetULCredit: Integer;
  Begin
  GetULCredit := MKCfg^.ULCredit;
  End;


Procedure MKCfgObj.SetULCredit(UC: Integer);
  Begin
  MKCfg^.ULCredit := UC;
  End;


Function MKCfgObj.GetMinDesc: Byte;
  Begin
  GetMinDesc := MKCfg^.MinDesc;
  End;


Procedure MKCfgObj.SetMinDesc(MD: Byte);
  Begin
  MKCfg^.MinDesc := MD;
  End;


Function MKCfgObj.GetMaxDesc: Byte;
  Begin
  GetMaxDesc := MKCfg^.MaxDesc;
  End;


Procedure MKCfgObj.SetMaxDesc(MD: Byte);
  Begin
  MKCfg^.MaxDesc := MD;
  End;


Function MKCfgObj.GetMinFree: LongInt;
  Begin
  GetMinFree := MKCfg^.MinULSpace;
  End;


Procedure MKCfgObj.SetMinFree(MF: LongInt);
  Begin
  MKCfg^.MinULSpace := MF;
  End;


Function MKCfgObj.GetAskNewFiles: Boolean;
  Begin
  GetAskNewFiles := (MKCfg^.COption and coCheckFiles) <> 0;
  End;


Procedure MKCfgObj.SetAskNewFiles(AN: Boolean);
  Begin
  If AN Then
    MKCfg^.Coption := MKCfg^.COption or (coCheckFiles)
  Else
    MKCfg^.COption := MKCfg^.COption and (Not coCheckFiles);
  End;


Function MKCfgObj.GetForceNewFiles: Boolean;
  Begin
  GetForceNewFiles := (MKCfg^.COption and coForceFiles) <> 0;
  End;


Procedure MKCfgObj.SetForceNewFiles(AN: Boolean);
  Begin
  If AN Then
    MKCfg^.Coption := MKCfg^.COption or (coForceFiles)
  Else
    MKCfg^.COption := MKCfg^.COption and (Not coForceFiles);
  End;


Function MKCfgObj.GetMaxEvents: Word;
  Begin
  GetMaxEvents := 30;
  End;


Function MKCfgObj.GetEventStatus(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventStatus := Byte(MKCfg^.Events[EN].Status)
  Else
    GetEventStatus := 0;
  End;



Procedure MKCfgObj.SetEventStatus(EN: Word; ES: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    MKCfg^.Events[EN].Status := ES;
  End;



Function MKCfgObj.GetEventTime(EN: Word): Word;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventTime := TimeStr2Word(MkCfg^.Events[EN].Time)
  Else
    GetEventTime := 0;
  End;


Procedure MKCfgObj.SetEventTime(EN: Word; ET: Word);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    MkCfg^.Events[EN].Time := Word2TimeStr(ET);
  End;


Function MKCfgObj.GetEventEL(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventEL := MKCfg^.Events[EN].ErrorLvl
  Else
    GetEventEL := 0;
  End;


Procedure MKCfgObj.SetEventEL(EN: Word; EL: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    MKCfg^.Events[EN].ErrorLvl := EL;
  End;


Function MKCfgObj.GetEventDays(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventDays := MKCfg^.Events[EN].Days
  Else
    GetEventDays := 0;
  End;


Procedure MKCfgObj.SetEventDays(EN: Word; ED: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    MKCfg^.Events[EN].Days := ED;
  End;


Function MKCfgObj.GetEventOnDay(EN: Word; OD: Byte): Boolean;
  Begin
  GetEventOnDay := (GetEventDays(EN) and (1 shl (OD -1))) <> 0;
  End;


Procedure MKCfgObj.SetEventOnDay(EN: Word; OD: Byte; ST: Boolean);
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



Function MKCfgObj.GetEventForced(EN: Word): Byte;
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    GetEventForced := MKCfg^.Events[EN].Forced
  Else
    GetEventForced := 0;
  End;


Procedure MKCfgObj.SetEventForced(EN: Word; EF: Byte);
  Begin
  If ((EN > 0) and (EN < GetMaxEvents)) Then
    MKCfg^.Events[EN].Forced := EF;
  End;


Function MKCfgObj.GetDoorData(DN: Word): String;
  Begin
  If ((DN > 0) and (DN < 11)) Then
    GetDoorData := MKCfg^.Doors[DN].Data
  Else
    GetDoorData := '';
  End;


Procedure MKCfgObj.SetDoorData(DN: Word; DD: String);
  Begin
  If ((DN > 0) and (DN < 11)) Then
    MKCfg^.Doors[DN].Data := DD;
  End;


Procedure MKCfgObj.GetDoorSec(DN: Word; Var Sec: SecType);
  Begin
  If ((DN > 0) and (DN < 11)) Then
    Sec := MKCfg^.Doors[DN].Sec
  Else
    Begin
    Sec.Level := $ffff;
    Sec.Flags := -1;     {all flags set}
    End;
  End;


Procedure MKCfgObj.SetDoorSec(DN: Word; Sec: SecType);
  Begin
  If ((DN > 0) and (DN < 11)) Then
    MKCfg^.Doors[DN].Sec := Sec;
  End;


Function MKCfgObj.DoorAccess(DN: Word; Sec: SecType): Boolean;
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


Function MKCfgObj.GetProtNormAvail(PN: Word): Boolean;
  Begin
  Case PN Of
    1..7: GetProtNormAvail := ((MKCfg^.InProt[PN].Attr and paAvail) <> 0);
    11..20: GetProtNormAvail := ((MKCfg^.ExtProt[PN].Attr and paAvail) <> 0);
    Else
      GetProtNormAvail := False;
    End;
  End;


Function MKCfgObj.GetProtSpecAvail(PN: Word): Boolean;
  Begin
  Case PN Of
    1..7: GetProtSpecAvail := ((MKCfg^.InProt[PN].Attr and paSpecial) <> 0);
    11..20: GetProtSpecAvail := ((MKCfg^.ExtProt[PN].Attr and paSpecial) <> 0);
    Else
      GetProtSpecAvail := False;
    End;
  End;


Function MKCfgObj.GetProtChar(PN: Word): Char;
  Begin
  Case PN of
    1..10: GetProtChar := MKCfg^.InProt[PN].Key;
    11..20: GetProtChar := MKCfg^.ExtProt[PN].Key;
    Else
      GetProtChar := #255;
    End;
  End;


Function MKCfgObj.GetProtCmdLine(PN: Word): String;
  Begin
  If (PN >= 11) And (PN <= 20) Then
    GetProtCmdLine := MKCfg^.ExtProt[PN].CmdLine
  Else
    GetProtCmdLine := '';
  End;

Procedure MKCfgObj.SetProtCmdLine(PN: Word; Cmd: String);
  Begin
  If (PN >= 11) And (PN <= 20) Then
    MKCfg^.ExtProt[PN].CmdLine := Copy(Cmd, 1, 80);
  End;

Function MKCfgObj.GetProtName(PN: Word): String;
  Begin
  Case PN of
    1..10: GetProtName := MKCfg^.InProt[PN].Name;
    11..20: GetProtName := MKCfg^.ExtProt[PN].Name;
    Else
      GetProtName := '';
    End;
  End;


Procedure MKCfgObj.SetProtNormAvail(PN: Word; PA: Boolean);
  Begin
  Case PN Of
    1..7: If PA Then
            MKCfg^.InProt[PN].Attr := MKCfg^.InProt[PN].Attr or paAvail
          Else
            MKCfg^.InProt[PN].Attr := MKCfg^.InProt[Pn].Attr and (not paAvail);
    11..20: If PA Then
              MKCfg^.ExtProt[PN].Attr := MKCfg^.ExtProt[PN].Attr or paAvail
            Else
              MKCfg^.ExtProt[PN].Attr := MKCfg^.ExtProt[Pn].Attr and (not paAvail);
    End;
  End;


Procedure MKCfgObj.SetProtSpecAvail(PN: Word; PA: Boolean);
  Begin
  Case PN Of
    1..7: If PA Then
            MKCfg^.InProt[PN].Attr := MKCfg^.InProt[PN].Attr or paSpecial
          Else
            MKCfg^.InProt[PN].Attr := MKCfg^.InProt[Pn].Attr and (not paSpecial);
    11..20: If PA Then
              MKCfg^.ExtProt[PN].Attr := MKCfg^.ExtProt[PN].Attr or paSpecial
            Else
              MKCfg^.ExtProt[PN].Attr := MKCfg^.ExtProt[Pn].Attr and (not paSpecial);
    End;
  End;


Procedure MKCfgObj.SetProtChar(PN: Word; PC: Char);
  Begin
  Case PN of
    1..10: MKCfg^.InProt[PN].Key := PC;
    11..20: MKCfg^.ExtProt[PN].Key := PC;
    End;
  End;


Procedure MKCfgObj.SetProtName(PN: Word; Name: String);
  Begin
  Case PN of
    1..10: MKCfg^.InProt[PN].Name := Name;
    11..20: MKCfg^.ExtProt[PN].Name := Name;
    End;
  End;

Function MKCfgObj.GetPackAvail(PN: Word): Boolean;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackAvail := (Length(MKCfg^.ExtPack[PN].Name) > 0) and ((MKCfg^.ExtPack[PN].Attr and paAvail) <> 0)
  Else
    GetPackAvail := False;
  End;

Function MKCfgObj.GetPackChar(PN: Word): Char;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackChar := MKCfg^.ExtPack[PN].Key
  Else
    GetPackChar := ' ';
  End;


Function MKCfgObj.GetPackName(PN: Word): String;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackName := MKCfg^.ExtPack[pn].Name
  Else
    GetPackName := '';
  End;


Function MKCfgObj.GetPackCmdLine(PN: Word): String;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetPackCmdLine := MKCfg^.ExtPack[pn].PCmdLine
  Else
    GetPackCmdLine := '';
  End;


Procedure MKCfgObj.SetPackCmdLine(PN: Word; Cmd: String);
  Begin
  If ((PN > 0) and (PN < 11)) Then
    MKCfg^.ExtPack[pn].PCmdLine := Cmd;
  End;


Function MKCfgObj.GetUnPackCmdLine(PN: Word): String;
  Begin
  If ((PN > 0) and (PN < 11)) Then
    GetUnPackCmdLine := MKCfg^.ExtPack[pn].UCmdLine
  Else
    GetUnPackCmdLine := '';
  End;


Procedure MKCfgObj.SetUnPackCmdLine(PN: Word; Cmd: String);
  Begin
  If ((PN > 0) and (PN < 11)) Then
    MKCfg^.ExtPack[pn].UCmdLine := Cmd;
  End;


Procedure MKCfgObj.SetPackAvail(PN: Word; PA: Boolean);
  Begin
  If ((PN > 0) and (PN < 11)) Then
    Begin
    If PA Then
      MKCfg^.ExtPack[pn].Attr := MKCfg^.ExtPack[pn].attr or paAvail
    Else
      MKCfg^.ExtPack[pn].attr := Mkcfg^.ExtPack[pn].attr and (not paAvail);
    End;
  End;


Procedure MKCfgObj.SetPackChar(PN: Word; PC: Char);
  Begin
  If ((PN > 0) and (PN < 11)) Then
    MKCfg^.ExtPack[pn].key := PC;
  End;


Procedure MKCfgObj.SetPackName(PN: Word; Name: String);
  Begin
  If ((PN > 0) and (PN < 11)) Then
    MKCfg^.ExtPack[pn].name := Name;
  End;


Function MKCfgObj.GetLogLevel: Byte; {Get level of logging}
  Begin
  GetLogLevel := ((MKCfg^.LogAttr shr 2) and 3);
  End;

Procedure MKCfgObj.SetLogLevel(LL: Byte); {Set level of logging}
  Begin
  LL := LL and 3;
  MKCfg^.LogAttr := (MKCfg^.LogAttr and (Not 12)) or (LL shl 2);
  End;


Function MKCfgObj.GetLogStyle: Byte; {Get style of log file}
  Begin
  GetLogStyle := MKCfg^.LogAttr and 3;
  End;


Procedure MKCfgObj.SetLogStyle(LS: Byte); {Set style of log file}
  Begin
  MKCfg^.LogAttr := (MKCfg^.LogAttr and (Not 3)) or (LS and 3);
  End;


Function MKCfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  GetDefaultPort := MKCfg^.CommPort;
  End;


Procedure MKCfgObj.SetDefaultPort(DP: Word); {Set default comm port}
  Begin
  MKCfg^.CommPort := DP;
  End;


Function MKCfgObj.GetMsgPathNum(Area: Word): Word;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    GetMsgPathNum := MKMsg^[Area].MsgBaseDir;
    End
  Else
    GetMsgPathNum := 0;
  End;


Procedure MKCfgObj.SetMsgPathNum(Area: Word; PN: Word);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].MsgBaseDir := PN;
    End;
  End;


Function MKCfgObj.GetMsgBaseType(Area: Word): Char;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    GetMsgBaseType := MKMsg^[Area].MsgBaseType;
    End
  Else
    GetMsgBaseType := ' ';
  End;


Procedure MKCfgObj.SetMsgBaseType(Area: Word; BT: Char);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    Begin
    MKMsg^[Area].MsgBaseType := BT;
    End;
  End;


Function MKCfgObj.GetMsgAreaId(Area: Word): String;
  Var
    TmpStr: String;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
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
           GetMsgAreaId := TmpStr + MKMsg^[Area].FileId;
           End;
      'F': Begin
           TmpStr := 'F' + GetMsgPath(GetMsgPathNum(Area));
           AddBackSlash(TmpStr);
           TmpStr := TmpStr + MKMsg^[Area].FileId;
           AddBackSlash(TmpStr);
           GetMsgAreaId := TmpStr;
           End;
      'J': Begin
           TmpStr := 'J' + GetMsgPath(GetMsgPathNum(Area));
           AddBackSlash(TmpStr);
           GetMsgAreaId := TmpStr + MKMsg^[Area].FileId;
           End;
      'M': Begin                                {Merlin: path + file name as given}
           TmpStr := 'M' + GetMsgPath(GetMsgPathNum(Area));
           AddBackSlash(TmpStr);
           GetMsgAreaId := TmpStr + MKMsg^[Area].FileId;
           End;
      'Y': Begin                                {Synchronet: path + base name, no extension}
           TmpStr := 'Y' + GetMsgPath(GetMsgPathNum(Area));
           AddBackSlash(TmpStr);
           GetMsgAreaId := TmpStr + MKMsg^[Area].FileId;
           End;
      Else
        GetMsgAreaId := '';
      End;
    End
  Else
    GetMsgAreaId := '';
  End;


Function MKCfgObj.GetNodeIdxName: String;
  Begin
  GetNodeIdxName := 'nodeidx.mk';
  End;


Function MKCfgObj.GetNodeIncName: String;
  Begin
  GetNodeIncName := 'nodeinc.mk';
  End;


Function MKCfgObj.GetMsgFileId(Area: Word): String;
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    GetMsgFileId := MKMsg^[Area].FileId
  Else
    GetMsgFileId := '';
  End;


Procedure MKCfgObj.SetMsgFileId(Area: Word; Fid: String);
  Begin
  If ((Area > 0) And (Area <= GetMaxMsgAreas)) Then
    MKMsg^[Area].FileId := Fid;
  End;


Function MKCfgObj.GetPrnName: String;
  Begin
  GetPrnName := MKCfg^.PrinterName;
  End;


Procedure MKCfgObj.SetPrnName(PN: String);
  Begin
  MKCfg^.PrinterName := PN;
  End;

Function MKCfgObj.GetOffTypeAvail(OT: Word): Boolean;
  Begin
  If (OT > 0) and (OT < 11) Then
    GetOffTypeAvail := MKCfg^.OffAvail[OT]
  Else
    GetOffTypeAvail := False;
  End;


Procedure MKCfgObj.SetOffTypeAvail(OT: Word; Avail: Boolean);
  Begin
  If (OT > 0) and (OT < 11) Then
    MKCfg^.OffAvail[OT] := Avail;
  End;

Function MKCfgObj.GetOffAllowNew: Boolean;
  Begin
  GetOffAllowNew := (MKCfg^.OffAttr and oaAllowNew) <> 0;
  End;


Procedure MKCfgObj.SetOffAllowNew(OA: Boolean);
  Begin
  If OA Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaAllowNew
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaAllowNew);
  End;

Function MKCfgObj.GetOffForceNew: Boolean;
  Begin
  GetOffForceNew := (MKCfg^.OffAttr and oaForceNew) <> 0;
  End;

Procedure MKCfgObj.SetOffForceNew(OA: Boolean);
  Begin
  If OA Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaForceNew
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaForceNew);
  End;

Function MKCfgObj.GetOffAllowScrn: Boolean;
  Begin
  GetOffAllowScrn := (MKCfg^.OffAttr and oaAllowScrn) <> 0;
  End;

Procedure MKCfgObj.SetOffAllowScrn(OA: Boolean);
  Begin
  If OA Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaAllowScrn
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaAllowScrn);
  End;

Function MKCfgObj.GetOffForceScrn: Boolean;
  Begin
  GetOffForceScrn := (MKCfg^.OffAttr and oaForceScrn) <> 0;
  End;

Procedure MKCfgObj.SetOffForceScrn(OA: Boolean);
  Begin
  If OA Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaForceScrn
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaForceScrn);
  End;

Function MKCfgObj.GetOffAllowBull: Boolean;
  Begin
  GetOffAllowBull := (MKCfg^.OffAttr and oaAllowBull) <> 0;
  End;

Procedure MKCfgObj.SetOffAllowBull(OA: Boolean);
  Begin
  If OA Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaAllowBull
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaAllowBull);
  End;

Function MKCfgObj.GetOffForceBull: Boolean;
  Begin
  GetOffForceBull := (MKCfg^.OffAttr and oaForceBull) <> 0;
  End;

Procedure MKCfgObj.SetOffForceBull(OA: Boolean);
  Begin
  If OA Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaForceBull
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaForceBull);
  End;

Function MKCfgObj.GetOffQwke: Boolean;
  Begin
  GetOffQwke := (MKCfg^.OffAttr and oaQwke) <> 0;
  End;

Procedure MKCfgObj.SetOffQwke(OQ: Boolean);
  Begin
  If OQ Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaQwke
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaQwke);
  End;

Function MKCfgObj.GetOffAllowFreq: Boolean;
  Begin
  GetOffAllowFreq := (MKCfg^.OffAttr and oaAllowFreq) <> 0;
  End;

Procedure MKCfgObj.SetOffAllowFreq(OA: Boolean);
  Begin
  If OA Then
    MKCfg^.OffAttr := MKCfg^.OffAttr or oaAllowFreq
  Else
    MKCfg^.OffAttr := MKCfg^.OffAttr And (Not oaAllowFreq);
  End;

Function MKCfgObj.GetOffMax: Word;
  Begin
  GetOffMax := MKCfg^.OffMax;
  End;

Procedure MKCfgObj.SetOffMax(OM: Word);
  Begin
  MKCfg^.OffMax := OM;
  End;

Function MKCfgObj.GetOffConfMax: Word;
  Begin
  GetOffConfMax := MKCfg^.OffConfMax;
  End;

Procedure MKCfgObj.SetOffConfMax(CM: Word);
  Begin
  MKCfg^.OffConfMax := Cm;
  End;

Function MKCfgObj.GetBadMsgArea: Word;
  Begin
  GetBadMsgArea := MKCfg^.BadMsgArea;
  End;

Procedure MKCfgObj.SetBadMsgArea(BA: Word);
  Begin
  MKCfg^.BadMsgArea := BA;
  End;

Function MKCfgObj.GetOffReDate: Boolean;
  Begin
  GetOffReDate := (MKCfg^.Attr And mcRedate) <> 0;
  End;

Procedure MKCfgObj.SetOffReDate(RD: Boolean);
  Begin
  If RD Then
    MKCfg^.Attr := MKCfg^.Attr Or mcRedate
  Else
    MKCfg^.Attr := MKCfg^.Attr And (Not mcRedate);
  End;

Function MKCfgObj.GetOffCompRate: Word;
  Begin
  GetOffCompRate := MKCfg^.OffComp;
  End;

Procedure MKCfgObj.SetOffCompRate(CM: Word);
  Begin
  MKCfg^.OffComp := Cm;
  End;

Function MKCfgObj.GetOffSafetyMin: Word;
  Begin
  GetOffSafetyMin := MKCfg^.OffSafety;
  End;

Procedure MKCfgObj.SetOffSafetyMin(SM: Word);
  Begin
  MKCfg^.OffSafety := SM;
  End;


Function MKCfgObj.GetOffScrns(SN: Word): String;
  Begin
  If (sn > 0) and (sn < 6) Then
    GetOffScrns := MKCfg^.OffScrns[Sn]
  Else
    GetOffScrns := '';
  End;

Procedure MKCfgObj.SetOffScrns(SN: Word; Scrn: String);
  Begin
  If (sn > 0) and (sn < 6) Then
    MKCfg^.OffScrns[sn] := Scrn;
  End;


Function MKCfgObj.GetOffBulls(BN: Word): String;
  Begin
  If (bn > 0) and (bn < 11) Then
    GetOffBulls := MKCfg^.OffBulls[bn]
  Else
    GetOffBulls := '';
  End;


Procedure MKCfgObj.SetOffBulls(BN: Word; Bull: String);
  Begin
  If (bn > 0) and (bn < 11) Then
    MKCfg^.OffBulls[bn] := Bull;
  End;


End.
