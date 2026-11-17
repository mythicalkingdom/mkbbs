Unit MKCfgAbs;


{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKString,
  Dos;


Type MailType = (Normal, EchoMail, NetMail);


Type CfgInfoType = Record
  BbsPath: String[128];
  CurrentPath: String[128];
  BbsType: Byte;              {1=MK100, 2=RA101, 3=Quick275, 4=Super112}
                              {5=EZY, 6=PROBOARD }
  Loaded: Boolean;            {Config has been loaded}
  FileAreas: Word;            {Number of SBBS file areas}
  SaveDir: String[128];       {Not empty: Save writes the config here and nowhere else (mkcfgcvt)}
  End;


Type CfgObj = Object
  Error:    Word;
  CfgInfo:  ^CfgInfoType;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Function  GetError: Word; Virtual;
  Procedure SetError(ES: Word); Virtual;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Procedure Save; Virtual;{Save Bbs config info}
  Function  SaveFileName(FN: String): String; Virtual;
  Function  SaveFileNames: String; Virtual;   {Names of the files Save writes, separated by |}
  Function  FindBbsFile(FileName: String):String; Virtual; {Return path to bbs file}
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
  Function  GetMsgPathNum(Area: Word): Word; Virtual; {Get message path number}
  Procedure SetMsgPathNum(Area: Word; PN: Word); Virtual; {Set message path number}
  Function  GetMsgBaseType(Area: Word): Char; Virtual; {Get message area base type}
  Procedure SetMsgBaseType(Area: Word; BT: Char); Virtual; {Set msg area base type}
  Function  GetMsgAreaId(Area: Word): String; Virtual; {Get message area id string}
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
  Function  InPageHours: Boolean; Virtual; {Is current date/time within paging hours}
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
  Function  HasMailer: Boolean; Virtual; {The format keeps mailer (mkbink) settings}
  Procedure GetMailer(Var M: MailerCfgType); Virtual; {Mailer settings, defaults if none}
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
  {0=Opus, 1=FD, 2=Quick, 3=MK}
  Function  GetDefaultPort: Word; Virtual; {Get default comm port}
  Procedure SetDefaultPort(DP: Word); Virtual; {Set default comm port}
  Function  GetNodeIdxName: String; Virtual; {Get nodelist index name}
  Function  GetNodeIncName: String; Virtual; {Get nodelist include name}
  Function  GetMsgFileId(Area: Word): String; Virtual; {Get msg filename id}
  Procedure SetMsgFileId(Area: Word; Fid: String); Virtual; {Set msg filename id}
  Function  GetEchoLog: String; Virtual; {Get echo tosser logfile}
  Procedure SetEchoLog(EL: String); Virtual; {set echo tosser logfile}
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
  Procedure SetOffAllowFreq(OA: Boolean); Virtual; {Set allow file req}
  Function  GetOffMax: Word; Virtual; {Get offline max msgs per pkt}
  Procedure SetOffMax(OM: Word); Virtual; {Set max msgs per pkt}
  Function  GetOffConfMax: Word; Virtual; {Get max msgs per area}
  Procedure SetOffConfMax(CM: Word); Virtual; {Set max msgs per area}
  Function  GetOffCompRate: Word; Virtual; {Get estimate compress %}
  Procedure SetOffCompRate(CM: Word); Virtual; {Set est compr %}
  Function  GetOffSafetyMin: Word; Virtual; {Get offline safety minutes}
  Procedure SetOffSafetyMin(SM: Word); Virtual; {Set safety minutes}
  Function  GetOffScrns(SN: Word): String; Virtual; {Get offline screen names}
  Procedure SetOffScrns(SN: Word; Scrn: String); Virtual; {Set offline scrn names}
  Function  GetOffBulls(BN: Word): String; Virtual; {Get offline bulletins}
  Procedure SetOffBulls(BN: Word; Bull: String); Virtual; {Set bulletin names}
  Function  GetUserFileName: String; Virtual; {Get user file path\name.ext}
  End;


Function DetectBbsType: Word;


Var
  Config: ^CfgObj;

Implementation


Function DetectBbsType: Word;
  Var
    TmpStr: String;

  Begin
  TmpStr := GetEnv('MK') + GetEnv('MKJSON');      {MKJSON: the MK configuration in one JSON file (MKCfgJs)}
  If Length(TmpStr) > 0 Then
    DetectBbsType := 1
  Else
    Begin
    TmpStr := GetEnv('RA');
    If Length(TmpStr) > 0 Then
      DetectBbsType := 2
    Else
      Begin
      TmpStr := GetEnv('QUICK');
      If Length(TmpStr) > 0 Then
        DetectBbsType := 3
      Else
        Begin
        TmpStr := GetEnv('SBBS');
        If Length(TmpStr) > 0 Then
          DetectBbsType := 4
        Else
          Begin
          TmpStr := GetEnv('EZY');
          If Length(TmpStr) > 0 Then
            DetectBbsType := 5
          Else
            Begin
            TmpStr := GetEnv('PROBOARD');
            If Length(TmpStr) > 0 Then
              DetectBBSType := 6;
            DetectBbsType := 0;
            End;
          End;
        End;
      End;
    End;
  End;


Constructor CfgObj.Init;
  Begin
  New(CfgInfo);
  Error := 0;
  CfgInfo^.Loaded := False;
  CfgInfo^.BbsType := 0;
  CfgInfo^.SaveDir := '';
  End;


Function CfgObj.GetError: Word;
  Begin
  GetError := Error;
  End;


Procedure CfgObj.SetError(ES: Word);
  Begin
  Error := ES;
  End;


Destructor CfgObj.Done;
  Begin
  If CfgInfo^.Loaded Then
    Unload;
  Dispose(CfgInfo);
  End;


Function CfgObj.FindBbsFile(FileName: String):String;
  Var
    TempStr: String;

  Begin
  If FileExist(CfgInfo^.CurrentPath + FileName) Then
    TempStr := CfgInfo^.CurrentPath
  Else
    Begin
    If FileExist(CfgInfo^.BbsPath + FileName) Then
      TempStr := CfgInfo^.BbsPath
    Else
      Begin
      If FileExist(GetMsgPath(1) + FileName) Then
        TempStr := GetMsgPath(1)
      Else
        TempStr := '';
      End;
    End;
  AddBackSlash(TempStr);
  FindBbsFile := TempStr;
  End;


Procedure CfgObj.Load;
  Begin
  End;


Procedure CfgObj.Unload;
  Begin
  End;

Procedure CfgObj.Allocate;
  Begin
  End;

Procedure CfgObj.Save;
  Begin
  End;

Function CfgObj.SaveFileNames: String;
  Begin
  SaveFileNames := '';
  End;


Function CfgObj.SaveFileName(FN: String): String;
  Begin
  End;

Function CfgObj.GetBbsType: Word;               {Get type of Bbs}
  Begin
  End;

Procedure CfgObj.SetBbsType(BT: Word);           {Set type of Bbs}
  Begin
  End;

Function CfgObj.GetMsgPath(BaseNo: Word): String; {Get directory for msg base}
  Begin
  End;

Procedure CfgObj.SetMsgPath(BaseNo: Word; MPath: String); {Set msg base directory}
  Begin
  End;

Function CfgObj.GetTxtPath(Num: Word): String;  {Get path to asc/ans/avt files}
  Begin
  End;

Procedure CfgObj.SetTxtPath(Num: Word; TPath: String); {Set path to txt files}
  Begin
  End;

Function CfgObj.GetMnuPath(Num: Word): String;  {Get path to menu *.mnu files}
  Begin
  End;

Procedure CfgObj.SetMnuPath(Num: Word; MPath: String); {Set path to menus}
  Begin
  End;

Function CfgObj.GetNetPath: String; {Get netmail path}
  Begin
  End;

Procedure CfgObj.SetNetPath(NP: String); {Set netmail path}
  Begin
  End;

Function CfgObj.GetTempPath: String; {Get temp file path}
  Begin
  End;

Procedure CfgObj.SetTempPath(TP: String); {Set temp file path}
  Begin
  End;

Function CfgObj.GetLogFileName: String; {Get log file path and name}
  Begin
  End;

Procedure CfgObj.SetLogFileName(LN: String); {Set log file path and name}
  Begin
  End;

Function CfgObj.GetEditCmdPath: String; {Get edit command path}
  Begin
  End;

Procedure CfgObj.SetEditCmdPath(EC: String); {Set edit command path}
  Begin
  End;

Function CfgObj.GetNodeListPath: String; {Get nodelist path}
  Begin
  End;

Procedure CfgObj.SetNodeListPath(NP: String); {Set nodelist path}
  Begin
  End;

Function CfgObj.GetAttachPath: String; {Get file attach path}
  Begin
  End;

Procedure CfgObj.SetAttachPath(AP: String); {Set file attach path}
  Begin
  End;

Function CfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  End;

Procedure CfgObj.SetSemaphorePath(SP: String); {Set Semaphore file path}
  Begin
  End;

Function CfgObj.GetBbsPath: String; {Get main bbs directory path}
  Begin
  End;

Procedure CfgObj.SetBbsPath(BPath: String); {Set main Bbs Directory}
  Begin
  End;

Function CfgObj.GetQuoteStr: String; {Get quote string}
  Begin
  End;

Procedure CfgObj.SetQuoteStr(Qt: String); {Set quote string}
  Begin
  End;

Procedure CfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
  Begin
  End;

Procedure CfgObj.SetAddr(Aka: Word; Addr: AddrType); {Set addr or AKA}
  Begin
  End;

Function CfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  End;

Function CfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Begin
  End;

Procedure CfgObj.SetMsgName(Area: Word; Name: String); {Set message area name}
  Begin
  End;

Function CfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Begin
  End;

Procedure CfgObj.SetMsgShortName(Area: Word; Name: String); {Set msg short name}
  Begin
  End;

Function CfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Begin
  End;

Procedure CfgObj.SetMsgType(Area: Word; MT: MailType); {Set type of mail area}
  Begin
  End;

Function CfgObj.GetMsgNetwork(Area: Word; Net: Byte): Boolean; {Get msg network}
  Begin
  End;

Procedure CfgObj.SetMsgNetwork(Area: Word; Net: Byte; MN: Boolean); {Set msg network}
  Begin
  End;

Function CfgObj.GetMsgNetStatus(Area: Word): LongInt;
  Begin
  GetMsgNetStatus := 0;
  End;

Procedure CfgObj.SetMsgNetStatus(Area: Word; NS: LongInt);
  Begin
  End;

Function CfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Begin
  End;

Function CfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Begin
  End;

Function CfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Begin
  End;

Function CfgObj.MsgDeleteAccess(Sec: SecType): Boolean;  {Has access to delete messages}
  Begin
  End;

Function CfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;  {Has access to unrcv messages}
  Begin
  End;

Procedure CfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType); {Read security level}
  Begin
  End;

Procedure CfgObj.SetMsgReadSecurity(Area: Word; Var Sec: SecType); {Set read sec}
  Begin
  End;

Procedure CfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Begin
  End;

Procedure CfgObj.SetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Set write sec}
  Begin
  End;

Procedure CfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Begin
  End;

Procedure CfgObj.SetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Set sysop sec}
  Begin
  End;

Function CfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Begin
  End;

Procedure CfgObj.SetMsgDays(Area: Word; Days: Word); {Set days kept}
  Begin
  End;

Function CfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Begin
  End;

Procedure CfgObj.SetMsgRcvdDays(Area: Word; Days: Word); {Set days recvd kept}
  Begin
  End;

Function CfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Begin
  End;

Procedure CfgObj.SetMsgsKept(Area: Word; Msgs: Word); {Set # msgs kept}
  Begin
  End;

Function CfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Begin
  End;

Procedure CfgObj.SetMsgAllowPriv(Area: Word; Priv: Boolean); {set allow priv}
  Begin
  End;

Function CfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Begin
  End;

Procedure CfgObj.SetMsgAllowPubl(Area: Word; Publ: Boolean); {set allow publ}
  Begin
  End;

Function CfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Begin
  End;

Procedure CfgObj.SetMsgAllowReal(Area: Word; RName: Boolean); {set allow real name}
  Begin
  End;

Function CfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Begin
  End;

Procedure CfgObj.SetMsgAllowHdl(Area: Word; Hdl: Boolean); {Set allow handles}
  Begin
  End;

Function CfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows aliases}
  Begin
  End;

Procedure CfgObj.SetMsgAllowAnon(Area: Word; Anon: Boolean); {Set area allow anon}
  Begin
  End;

Function CfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Begin
  End;

Procedure CfgObj.SetMsgAddFido(Area: Word; Fido: Boolean); {Set adding tear/origin}
  Begin
  End;

Function CfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Begin
  End;

Procedure CfgObj.SetMsgAllowAnsi(Area: Word; Ansi: Boolean); {Set area allows ansi}
  Begin
  End;

Function CfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Begin
  End;

Procedure CfgObj.SetMsgAllowHiBit(Area: Word; HiBit: Boolean); {Set area hi-bit}
  Begin
  End;

Function CfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Begin
  End;

Procedure CfgObj.SetMsgAllowTag(Area: Word; Tag: Boolean); {Set allow taglines}
  Begin
  End;

Function CfgObj.GetMsgReaderTear(Area: Word): Boolean; {Get keep reader tear text}
  Begin
  End;

Procedure CfgObj.SetMsgReaderTear(Area: Word; RT: Boolean); {Set keep reader tear}
  Begin
  End;

Function CfgObj.GetMsgReaderOrig(Area: Word): Boolean; {Get keep reader tear origin}
  Begin
  End;

Procedure CfgObj.SetMsgReaderOrig(Area: Word; RT: Boolean); {Set keep reader origin}
  Begin
  End;

Function CfgObj.GetMsgFAttach(Area: Word): Boolean; {Get allow file attach}
  Begin
  End;

Procedure CfgObj.SetMsgFAttach(Area: Word; FA: Boolean); {Set allow file attach}
  Begin
  End;

Function CfgObj.GetMsgSelect(Area: Word): String; {Get msg select string}
  Begin
  End;

Procedure CfgObj.SetMsgSelect(Area: Word; Sel: String); {Set msg select string}
  Begin
  End;

Function CfgObj.GetMsgOrigStr(Area: Word): String; {Get origin string for msg area}
  Begin
  End;

Procedure CfgObj.GetMsgAddr(Area: Word; Var MA: AddrType); {Get message area address}
  Begin
  End;

Function CfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Begin
  End;

Function CfgObj.GetMsgAddrNum(Area: Word): Word; {Get message aka number}
  Begin
  End;

Procedure CfgObj.SetMsgAddrNum(Area: Word; AKA: Word); {Set msg aka number}
  Begin
  End;

Function CfgObj.GetMsgOrigNum(Area: Word): Word; {Get message orig number}
  Begin
  End;

Procedure CfgObj.SetMsgOrigNum(Area: Word; Orig: Word); {Set msg orig number}
  Begin
  End;

Function CfgObj.GetMsgAllowOffline(Area: Word): Boolean; {Allow in offline}
  Begin
  End;

Procedure CfgObj.SetMsgAllowOffline(Area: Word; AO: Boolean); {Allow in offline}
  Begin
  End;

Function CfgObj.GetMsgForceOffline(Area: Word): Boolean; {Force in offline}
  Begin
  End;

Procedure CfgObj.SetMsgForceOffline(Area: Word; FO: Boolean); {Force in offline}
  Begin
  End;

Function CfgObj.GetMsgAllowCombined(Area: Word): Boolean; {Allow in combined read}
  Begin
  End;

Procedure CfgObj.SetMsgAllowCombined(Area: Word; AC: Boolean); {Allow in combined}
  Begin
  End;

Function CfgObj.GetMsgDefCombined(Area: Word): Boolean; {Default combined area}
  Begin
  End;

Procedure CfgObj.SetMsgDefCombined(Area: Word; DC: Boolean); {Default combined area}
  Begin
  End;

Function CfgObj.GetDefaultOrigStr(Area: Word): String; {Get full origin string w/addr}
  Begin
  End;

Function CfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  End;

Function CfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Begin
  End;

Procedure CfgObj.SetFileAreaName(Area: Word; Name: String); {Set file area name}
  Begin
  End;

Function CfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Begin
  End;

Procedure CfgObj.SetFileShortName(Area: Word; Nm: String); {Set short name for area}
  Begin
  End;

Function CfgObj.GetFileSelect(Area: Word): String; {Get file area select name}
  Begin
  End;

Procedure CfgObj.SetFileSelect(Area: Word; SN: String); {Set file area select name}
  Begin
  End;

Function CfgObj.GetFileAreaPath(Area: Word): String; {Get file area path}
  Begin
  End;

Procedure CfgObj.SetFileAreaPath(Area: Word; FPath: String); {Set file area path}
  Begin
  End;

Function CfgObj.GetFileListPath(Area: Word): String; {Get file area path}
  Begin
  End;

Procedure CfgObj.GetFileViewSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  End;

Procedure CfgObj.SetFileViewSecurity(Area: Word; Var Sec: SecType); {set list sec}
  Begin
  End;

Procedure CfgObj.GetFileULSecurity(Area: Word; Var Sec: SecType); {File UL security level}
  Begin
  End;

Procedure CfgObj.SetFileULSecurity(Area: Word; Var Sec: SecType); {File ul sec}
  Begin
  End;

Procedure CfgObj.GetFileDLSecurity(Area: Word; Var Sec: SecType); {File Listing security level}
  Begin
  End;

Procedure CfgObj.SetFileDLSecurity(Area: Word; Var Sec: SecType); {DL Sec}
  Begin
  End;

Procedure CfgObj.GetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private files security}
  Begin
  End;

Procedure CfgObj.SetFilePvtSecurity(Area: Word; Var Sec: SecType); {Private sec}
  Begin
  End;

Function CfgObj.GetFileNoUl(Area: Word): Boolean; {Area disallows ULs}
  Begin
  End;

Function CfgObj.GetFileNoNew(Area: Word): Boolean; {Exclude area from new files}
  Begin
  End;

Function CfgObj.GetFileFree(Area: Word): Boolean; {Area contains free files}
  Begin
  End;

Function CfgObj.GetFileNoTime(Area: Word): Boolean; {Ignore time remaining}
  Begin
  End;

Function CfgObj.GetFileNoBaud(Area: Word): Boolean; {Ignore min baud limits}
  Begin
  End;

Procedure CfgObj.SetFileNoUl(Area: Word; St: Boolean); {Area disallows ULs}
  Begin
  End;

Procedure CfgObj.SetFileNoNew(Area: Word; St: Boolean); {Exclude area from new files}
  Begin
  End;

Procedure CfgObj.SetFileFree(Area: Word; St: Boolean); {Area contains free files}
  Begin
  End;

Procedure CfgObj.SetFileNoTime(Area: Word; St: Boolean); {Ignore time remaining}
  Begin
  End;

Procedure CfgObj.SetFileNoBaud(Area: Word; St: Boolean); {Ignore min baud limits}
  Begin
  End;

Function CfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  End;

Procedure CfgObj.SetSysopName(Sysop: String); {Set name of sysop}
  Begin
  End;

Function CfgObj.GetSystemColor(Num: Byte): Byte; {Get system color attribute}
  Begin
  End;

Procedure CfgObj.SetSystemColor(Num: Byte; Color: Byte); {Set system color attr}
  Begin
  End;

Function CfgObj.GetBbsName: String; {Get Bbs system name}
  Begin
  End;

Procedure CfgObj.SetBbsName(BN: String); {Set Bbs system name}
  Begin
  End;

Function CfgObj.GetBbsLoc: String; {Get Bbs location}
  Begin
  End;

Procedure CfgObj.SetBbsLoc(BL: String); {Set Bbs location}
  Begin
  End;

Function CfgObj.GetBbsPhone: String; {Get Bbs main phone number}
  Begin
  End;

Procedure CfgObj.SetBbsPhone(BPhone: String); {Set Bbs main phone number}
  Begin
  End;

Function CfgObj.GetBbsId: String; {Get Bbs Id}
  Begin
  End;

Procedure CfgObj.SetBbsId(BId: String); {Set BbsId}
  Begin
  End;

Function CfgObj.GetDirectWrite: Boolean; {Get direct video write status}
  Begin
  End;

Procedure CfgObj.SetDirectWrite(DW: Boolean); {Set Direct video write status}
  Begin
  End;

Function CfgObj.GetSnowCheck: Boolean; {Get snow checking status}
  Begin
  End;

Procedure CfgObj.SetSnowCheck(SC: Boolean); {Set snow checking status}
  Begin
  End;

Function CfgObj.GetMonoMode: Boolean; {Get mono screen mode}
  Begin
  End;

Procedure CfgObj.SetMonoMode(MM: Boolean); {Set mono screen mode}
  Begin
  End;

Function CfgObj.GetForceKillYes: Boolean; {Force kill/sent to yes}
  Begin
  End;

Procedure CfgObj.SetForceKillYes(FK: Boolean); {Set force kill/sent to yes}
  Begin
  End;

Function CfgObj.GetForceKillAsk: Boolean; {Force kill/sent Ask}
  Begin
  End;

Procedure CfgObj.SetForceKillAsk(FK: Boolean); {Set force kill/sent Ask}
  Begin
  End;

Function CfgObj.GetPageStart(DayNo: Byte): Word; {Get page start time hi=hr lo=minutes}
  Begin
  End;

Procedure CfgObj.SetPageStart(DayNo: Byte; St: Word); {Set page start time}
  Begin
  End;

Function CfgObj.GetPageStop(DayNo: Byte): Word; {Get page stop time}
  Begin
  End;

Procedure CfgObj.SetPageStop(DayNo: Byte; St: Word); {Set page stop time}
  Begin
  End;


Function CfgObj.InPageHours: Boolean;
  Var
    TimeOk: Boolean;
    Hour: Word;
    Min: Word;
    Seconds: Word;
    Sec100: Word;
    Dow: Word;
    PgStart: Word;
    PgStop: Word;

  Begin
  GetDate(Hour, Min, Seconds, DOW);
  GetTime(Hour, Min, Seconds, Sec100);
  PgStart := GetPageStart(DOW);
  PgStop := GetPageStop(DOW);
  If Hour < (Hi(PgStart)) Then
    TimeOk := False
  Else
    If Hour = (Hi(PgStart)) Then
      TimeOk := (Min >= Lo(PgStart))
    Else
      TimeOk := True;
  If TimeOk Then
    Begin
    If Hour > (Hi(PgStop)) Then
      TimeOk := False
    Else
      If Hour = (Hi(PgStop)) Then
        TimeOk := (Min <= Lo(PgStop))
      Else
        TimeOk := True;
    End;
  InPageHours := TimeOk;
  End;


Function CfgObj.GetMaxPageTimes: Word; {Get maximum number of page attempts}
  Begin
  End;

Procedure CfgObj.SetMaxPageTimes(Pg: Word); {Set maximum number of page attempts}
  Begin
  End;

Function CfgObj.GetPageMsgArea: Word; {Get msg area to use for page messages}
  Begin
  End;

Procedure CfgObj.SetPageMsgArea(Pg: Word); {Set msg area to use for page messages}
  Begin
  End;

Function CfgObj.GetPageLength: Byte; {Get seconds of page length}
  Begin
  End;

Procedure CfgObj.SetPageLength(PL: Byte); {Set seconds of page length}
  Begin
  End;

Function CfgObj.GetDefaultPage: Byte; {Get new user page tune}
  Begin
  End;

Procedure CfgObj.SetDefaultPage(DP: Byte); {Set new user page tune}
  Begin
  End;

Function CfgObj.GetAskPageReason: Boolean; {Ask reason for paging}
  Begin
  End;

Procedure CfgObj.SetAskPageReason(AP: Boolean); {Set ask reason for paging}
  Begin
  End;

Function CfgObj.GetMailCheckDetail: Boolean; {Show detail during mail scan}
  Begin
  End;

Procedure CfgObj.SetMailCheckDetail(MC: Boolean); {Show detail during your scan}
  Begin
  End;

Function CfgObj.GetMailCheckTotal: Boolean; {Show totals after your mail scan}
  Begin
  End;

Procedure CfgObj.SetMailCheckTotal(MC: Boolean); {Show totals after your mail scan}
  Begin
  End;

Function CfgObj.FileViewAccess(Area: Word; Sec: SecType): Boolean; {Can view files}
  Begin
  End;

Function CfgObj.FileDLAccess(Area: Word; Sec: SecType): Boolean; {Can download files}
  Begin
  End;

Function CfgObj.FileULAccess(Area: Word; Sec: SecType): Boolean; {Can upload files}
  Begin
  End;

Function CfgObj.FilePvtAccess(Area: Word; Sec: SecType): Boolean; {Private files}
  Begin
  End;

Function CfgObj.GetLangName(LNum: Word): String;  {Get language name}
  Begin
  If LNum = 1 Then
    GetLangName := 'ENGLISH'
  Else
    GetLangName := '';
  End;

Procedure CfgObj.SetLangName(LNum: Word; Name: String); {Set language name}
  Begin
  End;

Function CfgObj.GetLangFile(LNum: Word): String;  {Get language file name}
  Begin
  If LNum = 1 Then
    GetLangFile := 'english'
  Else
    GetLangFile := '';
  End;

Procedure CfgObj.SetLangFile(LNum: Word; FName: String); {Set language file name}
  Begin
  End;

Function CfgObj.GetLangQuesPath(LNum: Word): String; {Get language q-a path}
  Begin
  End;

Procedure CfgObj.SetLangQuesPath(LNum: Word; QPath: String); {Set lang q-a path}
  Begin
  End;

Function CfgObj.GetAskVoicePhone: Boolean; {Ask new user voice phone}
  Begin
  End;

Procedure CfgObj.SetAskVoicePhone(VP: Boolean); {Set ask new user voice phone}
  Begin
  End;

Function CfgObj.GetAskDataPhone: Boolean; {Ask new user data phone}
  Begin
  End;

Procedure CfgObj.SetAskDataPhone(DP: Boolean); {Set ask new user data phone}
  Begin
  End;

Function CfgObj.GetNewUserNMCredit: Word; {Get new user netmail credit}
  Begin
  End;

Procedure CfgObj.SetNewUserNMCredit(NM: Word); {Set new user netmail credit}
  Begin
  End;

Function CfgObj.GetAskBirthdate: Boolean; {Ask new user birthdate}
  Begin
  End;

Procedure CfgObj.SetAskBirthdate(AB: Boolean); {Set ask new user birthdate}
  Begin
  End;

Function CfgObj.GetAskGender: Boolean; {Ask new user gender}
  Begin
  End;

Procedure CfgObj.SetAskGender(AG: Boolean); {Set ask new user gender}
  Begin
  End;

Function CfgObj.GetAskAddr: Boolean; {Ask new user address}
  Begin
  End;

Procedure CfgObj.SetAskAddr(AA: Boolean); {Set ask new user address}
  Begin
  End;

Function CfgObj.GetSevenBitNames: Boolean; {Force name to 7 bit chars}
  Begin
  End;

Procedure CfgObj.SetSevenBitNames (SB: Boolean); {Set force 7 bit names}
  Begin
  End;

Function CfgObj.GetOneWordName: Boolean; {Allow one word names}
  Begin
  End;

Procedure CfgObj.SetOneWordName(OW: Boolean); {Set allow one word names}
  Begin
  End;

Function CfgObj.GetReAsk: Boolean; {Re-ask blank answers}
  Begin
  End;

Procedure CfgObj.SetReAsk(RA: Boolean); {Set re-ask blank answers}
  Begin
  End;

Function CfgObj.GetAskHandle: Boolean; {Ask user for handle}
  Begin
  End;

Procedure CfgObj.SetAskHandle(AH: Boolean); {Set ask user for handle}
  Begin
  End;

Procedure CfgObj.GetEchoToAddr(ES: Word; Var Addr: AddrType);
  Begin
  End;

Procedure CfgObj.SetEchoToAddr(ES: Word; Addr: AddrType);
  Begin
  End;

Function CfgObj.GetEchoToPwd(ES: Word): String; {Get echo to system password}
  Begin
  End;

Procedure CfgObj.SetEchoToPwd(ES: Word; Pwd: String); {Set echo to system password}
  Begin
  End;

Function CfgObj.GetEchoToPacker(ES: Word): Byte; {Get echo to archiver type}
  Begin
  End;

Procedure CfgObj.SetEchoToPacker(ES: Word; Pk: Byte); {Set echo to archiver type}
  Begin
  End;

Function CfgObj.GetEchoToNetwork(ES: Word; Nt: Word): Boolean; {Get echo network status}
  Begin
  End;

Procedure CfgObj.SetEchoToNetwork(ES: Word; Nt: Word; St: Boolean); {Set echo network}
  Begin
  End;

Function CfgObj.GetEchoToMailType(ES: Word): Byte; {Get echo mail type}
  Begin
  End;

Procedure CfgObj.SetEchoToMailType(ES: Word; MT: Byte); {Set echo mail type}
  Begin
  End;

Function CfgObj.GetEchoToArea(ES: Word; Area: Word): Boolean; {Get echo to area on}
  Begin
  End;

Procedure CfgObj.SetEchoToArea(ES: Word; Area: Word; SA: Boolean); {Set echo to area on}
  Begin
  End;

Function CfgObj.GetEchoAreaPassThru(Area: Word): Boolean; {Get area is pass-thru}
  Begin
  End;

Procedure CfgObj.SetEchoAreaPassThru(Area: Word; PT: Boolean); {Set area is pass-thru}
  Begin
  End;

Function CfgObj.GetEchoAreaImportPath(Area: Word): Boolean; {Get import path}
  Begin
  End;

Procedure CfgObj.SetEchoAreaImportPath(Area: Word; IP: Boolean); {Set import path}
  Begin
  End;

Function CfgObj.GetEchoAreaHidePath(Area: Word): Boolean; {Get hide import path}
  Begin
  End;

Procedure CfgObj.SetEchoAreaHidePath(Area: Word; HP: Boolean); {Set hide import path}
  Begin
  End;

Function CfgObj.GetEchoAreaImportSeen(Area: Word): Boolean; {Get import seen-by}
  Begin
  End;

Procedure CfgObj.SetEchoAreaImportSeen(Area: Word; ISB: Boolean); {Set import seen-by}
  Begin
  End;

Function CfgObj.GetEchoAreaHideSeen(Area: Word): Boolean; {Get hide imported seen}
  Begin
  End;

Procedure CfgObj.SetEchoAreaHideSeen(Area: Word; HS: Boolean); {Set hide seen}
  Begin
  End;

Function CfgObj.GetEchoToHub(Area: Word): Byte; {Get hub number}
  Begin
  End;

Procedure CfgObj.SetEchoToHub(Area: Word; Hub: Byte); {Set hub number}
  Begin
  End;

Function CfgObj.GetEchoAreaTag(Area: Word): String; {Get area tag name}
  Begin
  End;

Procedure CfgObj.SetEchoAreaTag(Area: Word; Tag: String); {Set area tag name}
  Begin
  End;

Function CfgObj.GetEchoMaxPkt: LongInt; {Get maximum pkt size}
  Begin
  End;

Procedure CfgObj.SetEchoMaxPkt(MP: LongInt); {Set maximum pkt size}
  Begin
  End;

Function CfgObj.HasMailer: Boolean;
  Begin
  HasMailer := False;
  End;

Procedure CfgObj.GetMailer(Var M: MailerCfgType);
  Begin
  MailerDefaults(M);
  End;

Procedure CfgObj.SetMailer(Var M: MailerCfgType);
  Begin
  End;

Function CfgObj.GetEchoInPath: String; {Get inbound files path}
  Begin
  End;

Procedure CfgObj.SetEchoInPath(EP: String); {Set inbound files path}
  Begin
  End;

Function CfgObj.GetEchoOutPath: String; {Get outbound files path}
  Begin
  End;

Procedure CfgObj.SetEchoOutPath(EP: String); {Set outbound files path}
  Begin
  End;

Function CfgObj.GetPwdTries: Byte; {Get max password attempts}
  Begin
  End;

Procedure CfgObj.SetPwdTries(PT: Byte); {Set max password attempts}
  Begin
  End;

Function CfgObj.GetPwdExpire: Word; {Get password expiration days}
  Begin
  End;

Procedure CfgObj.SetPwdExpire(PE: Word); {Set password expiration days}
  Begin
  End;

Function CfgObj.GetBDCheck: Byte; {Get calls between birthdate confirms}
  Begin
  End;

Procedure CfgObj.SetBDCheck(BD: Byte); {Set calls between birthdate confirms}
  Begin
  End;

Function CfgObj.GetPhoneCheck: Byte; {Get calls between phone num confirms}
  Begin
  End;

Procedure CfgObj.SetPhoneCheck(PC: Byte); {Set calls between phone num confirms}
  Begin
  End;

Function CfgObj.GetMinPwd: Byte; {Get min password length}
  Begin
  End;

Procedure CfgObj.SetMinPwd(MP: Byte); {Set min password length}
  Begin
  End;

Function CfgObj.GetMinPhone: Byte; {Get min phone num length}
  Begin
  End;

Procedure CfgObj.SetMinPhone(MP: Byte); {Set min phone num length}
  Begin
  End;

Function CfgObj.GetStrictPwd: Boolean; {Get strict password checking}
  Begin
  End;

Procedure CfgObj.SetStrictPwd(SP: Boolean); {Set strict password checking}
  Begin
  End;

Function CfgObj.GetRemoteSysop: Boolean; {Get allow remote sysop}
  Begin
  End;

Procedure CfgObj.SetRemoteSysop(RS: Boolean); {Set allow remote sysop}
  Begin
  End;

Function CfgObj.GetFastLocal: Boolean; {Get fast local log on}
  Begin
  End;

Procedure CfgObj.SetFastLocal(FL: Boolean); {Set fast local log on}
  Begin
  End;

Procedure CfgObj.GetNewUserSec(Var Sec: SecType); {Get new user security}
  Begin
  End;

Procedure CfgObj.SetNewUserSec(Sec: SecType); {Set new user security}
  Begin
  End;

Procedure CfgObj.GetAttachSec(Var Sec: SecType); {Get file attach security}
  Begin
  End;

Procedure CfgObj.SetAttachSec(Sec: SecType); {Set file attach security}
  Begin
  End;

Procedure CfgObj.GetRequestSec(Var Sec: SecType); {Get file request security}
  Begin
  End;

Procedure CfgObj.SetRequestSec(Sec: SecType); {Set file request security}
  Begin
  End;

Procedure CfgObj.GetCrashNmSec(Var Sec: SecType); {Get crash netmail security}
  Begin
  End;

Procedure CfgObj.SetCrashNmSec(Sec: SecType); {Set crash netmail security}
  Begin
  End;

Procedure CfgObj.GetForceCrashNmSec(Var Sec: SecType); {Get force crash netmail security}
  Begin
  End;

Procedure CfgObj.SetForceCrashNmSec(Sec: SecType); {Set force crash netmail security}
  Begin
  End;

Procedure CfgObj.GetDeleteSec(Var Sec: SecType); {Get msg delete security}
  Begin
  End;

Procedure CfgObj.SetDeleteSec(Sec: SecType); {Set msg delete security}
  Begin
  End;

Procedure CfgObj.GetUnRcvSec(Var Sec: SecType); {Get msg unreceive security}
  Begin
  End;

Procedure CfgObj.SetUnRcvSec(Sec: SecType); {Set msg unreceive security}
  Begin
  End;

Function CfgObj.GetModemResp(MR: Byte): String; {Get modem response string}
  Begin
  End;

Procedure CfgObj.SetModemResp(MR: Byte; Resp: String); {Set modem response string}
  Begin
  End;

Function CfgObj.GetErrorLevel(MR: Byte): Byte; {Get errorlevel}
  Begin
  End;

Procedure CfgObj.SetErrorLevel(MR: Byte; EL: Byte); {Set errorlevel}
  Begin
  End;

Function CfgObj.GetDLStart: Word; {Get DL Start time}
  Begin
  End;

Procedure CfgObj.SetDLStart(ST: Word); {Set DL Start time}
  Begin
  End;

Function CfgObj.GetDLStop: Word; {Get DL Stop time}
  Begin
  End;

Procedure CfgObj.SetDLStop(ST: Word); {Set DL Stop time}
  Begin
  End;

Function CfgObj.GetLoBaudStart: Word; {Get Low Baud DL Start time}
  Begin
  End;

Procedure CfgObj.SetLoBaudStart(ST: Word); {Set Low Baud DL Start time}
  Begin
  End;

Function CfgObj.GetLoBaudStop: Word; {Get Low Baud DL Stop time}
  Begin
  End;

Procedure CfgObj.SetLoBaudStop(ST: Word); {Set Low Baud DL Stop time}
  Begin
  End;

Function CfgObj.GetMinXferBaud: Word; {Get min transfer baud rate}
  Begin
  End;

Procedure CfgObj.SEtMinXferBaud(MB: Word); {Set min transfer baud rate}
  Begin
  End;

Function CfgObj.GetULCredit: Integer; {Get ul credit}
  Begin
  End;

Procedure CfgObj.SetULCredit(UC: Integer); {Set UL Credit}
  Begin
  End;

Function CfgObj.GetMinDesc: Byte; {Get min descr length}
  Begin
  End;

Procedure CfgObj.SetMinDesc(MD: Byte); {Set min descr length}
  Begin
  End;

Function CfgObj.GetMaxDesc: Byte; {Get max descr length}
  Begin
  End;

Procedure CfgObj.SetMaxDesc(MD: Byte); {Set max descr length}
  Begin
  End;

Function CfgObj.GetMinFree: LongInt; {Get min free ul space}
  Begin
  End;

Procedure CfgObj.SetMinFree(MF: LongInt); {Set min free ul space}
  Begin
  End;

Function CfgObj.GetAskNewFiles: Boolean; {Get ask new file search}
  Begin
  End;

Procedure CfgObj.SetAskNewFiles(AN: Boolean); {Set ask new file search}
  Begin
  End;

Function CfgObj.GetForceNewFiles: Boolean; {Get force new file search}
  Begin
  End;

Procedure CfgObj.SetForceNewFiles(AN: Boolean); {Set force new file search}
  Begin
  End;

Function CfgObj.GetOrigStr(OrigNum: Word): String; {Get origin string}
  Begin
  End;

Procedure CfgObj.SetOrigStr(OrigNum: Word; OrigStr: String); {Set origin string}
  Begin
  End;

Function CfgObj.GetMaxEvents: Word; {Get maximum number of events}
  Begin
  End;

Function CfgObj.GetEventStatus(EN: Word): Byte; {Get event status}
  Begin
  End;

Procedure CfgObj.SetEventStatus(EN: Word; ES: Byte); {Set event status}
  Begin
  End;

Function CfgObj.GetEventTime(EN: Word): Word; {Get event time Hi=HH Lo=MM}
  Begin
  End;

Procedure CfgObj.SetEventTime(EN: Word; ET: Word); {Set event time}
  Begin
  End;

Function CfgObj.GetEventEL(EN: Word): Byte; {Get event errorlevel}
  Begin
  End;

Procedure CfgObj.SetEventEL(EN: Word; EL: Byte); {Set event errorlevel}
  Begin
  End;

Function CfgObj.GetEventDays(EN: Word): Byte; {Get event days}
  Begin
  End;

Procedure CfgObj.SetEventDays(EN: Word; ED: Byte); {Set event days}
  Begin
  End;

Function CfgObj.GetEventOnDay(EN: Word; OD: Byte): Boolean; {Is event active on day}
  Begin
  End;

Procedure CfgObj.SetEventOnDay(EN: Word; OD: Byte; ST: Boolean); {Set event active day}
  Begin
  End;

Function CfgObj.GetEventForced(EN: Word): Byte; {Get event forced}
  Begin
  End;

Procedure CfgObj.SetEventForced(EN: Word; EF: Byte); {Set event forced}
  Begin
  End;

Function CfgObj.GetDoorData(DN: Word): String; {Get door data line}
  Begin
  End;

Procedure CfgObj.SetDoorData(DN: Word; DD: String); {Set door data line}
  Begin
  End;

Procedure CfgObj.GetDoorSec(DN: Word; Var Sec: SecType); {Get door security}
  Begin
  End;

Procedure CfgObj.SetDoorSec(DN: Word; Sec: SecType); {Set door security}
  Begin
  End;

Function CfgObj.DoorAccess(DN: Word; Sec: SecType): Boolean; {Has door access}
  Begin
  End;

Function CfgObj.GetProtNormAvail(PN: Word): Boolean; {Is protocol avail norm files}
  Begin
  End;

Function CfgObj.GetProtSpecAvail(PN: Word): Boolean; {Is protocol avail special files}
  Begin
  End;

Function CfgObj.GetProtChar(PN: Word): Char; {Get protocol character}
  Begin
  End;

Function CfgObj.GetProtName(PN: Word): String; {Get protocol name}
  Begin
  End;

Procedure CfgObj.SetProtNormAvail(PN: Word; PA: Boolean); {Is protocol avail norm files}
  Begin
  End;

Procedure CfgObj.SetProtSpecAvail(PN: Word; PA: Boolean); {Is protocol avail special files}
  Begin
  End;

Procedure CfgObj.SetProtChar(PN: Word; PC: Char); {Set protocol character}
  Begin
  End;

Procedure CfgObj.SetProtName(PN: Word; Name: String); {Set protocol name}
  Begin
  End;

Function CfgObj.GetPackAvail(PN: Word): Boolean;
  Begin
  GetPackAvail := ((PN > 0) and (PN < 4));
  End;

Function CfgObj.GetPackChar(PN: Word): Char;
  Begin
  Case PN of
    1: GetPackChar := 'L';
    2: GetPackChar := 'Z';
    3: GetPackChar := 'A';
    Else
      GetPackChar := ' ';
    End;
  End;

Function CfgObj.GetPackName(PN: Word): String;
  Begin
  Case PN of
    1: GetPackName := 'LHA/LZH';
    2: GetPackName := 'ZIP';
    3: GetPackName := 'ARC';
    Else
      GetPackName := '';
    End;
  End;

Function CfgObj.GetPackCmdLine(PN: Word): String;
  Begin
  Case PN of
    1: GetPackCmdLine := 'LHA.EXE a -m';
    2: GetPackCmdLine := 'PKZIP.EXE -a';
    3: GetPackCmdLine := 'PKUNPAK.EXE -a';
    Else
      GetPackCmdLine := '';
    End;
  End;

Procedure CfgObj.SetPackCmdLine(PN: Word; Cmd: String);
  Begin
  End;

Function CfgObj.GetUnPackCmdLine(PN: Word): String;
  Begin
  Case PN of
    1: GetUnPackCmdLine := 'LHA.EXE e -m';
    2: GetUnPackCmdLine := 'PKUNZIP.EXE -ed -o';
    3: GetUnPackCmdLine := 'PKPAK.EXE -r';
    Else
      GetUnPackCmdLine := '';
    End;
  End;

Procedure CfgObj.SetUnPackCmdLine(PN: Word; Cmd: String);
  Begin
  End;

Procedure CfgObj.SetPackAvail(PN: Word; PA: Boolean);
  Begin
  End;

Procedure CfgObj.SetPackChar(PN: Word; PC: Char);
  Begin
  End;

Procedure CfgObj.SetPackName(PN: Word; Name: String);
  Begin
  End;

Function CfgObj.GetLogLevel: Byte; {Get level of logging}
  Begin
  End;

Procedure CfgObj.SetLogLevel(LL: Byte); {Set level of logging}
  Begin
  End;

Function CfgObj.GetLogStyle: Byte; {Get style of log file}
  Begin
  End;

Procedure CfgObj.SetLogStyle(LS: Byte); {Set style of log file}
  Begin
  End;

Function CfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  End;

Procedure CfgObj.SetDefaultPort(DP: Word); {Set default comm port}
  Begin
  End;

Function CfgObj.GetMsgPathNum(Area: Word): Word;
  Begin
  End;

Procedure CfgObj.SetMsgPathNum(Area: Word; PN: Word);
  Begin
  End;

Function CfgObj.GetMsgBaseType(Area: Word): Char;
  Begin
  End;

Procedure CfgObj.SetMsgBaseType(Area: Word; BT: Char);
  Begin
  End;

Function CfgObj.GetMsgAreaId(Area: Word): String;
 Begin
 End;

Function CfgObj.GetNodeIdxName: String;
  Begin
  End;

Function CfgObj.GetNodeIncName: String;
  Begin
  End;

Function CfgObj.GetMsgFileId(Area: Word): String;
  Begin
  GetMsgFileId := '';
  End;

Procedure CfgObj.SetMsgFileId(Area: Word; Fid: String);
  Begin
  End;

Function CfgObj.GetEchoLog: String;
  Begin
  GetEchoLog := '';
  End;


Procedure CfgObj.SetEchoLog(EL: String);
  Begin
  End;

Function CfgObj.GetPrnName: String;
  Begin
  GetPrnName := 'PRN';
  End;


Procedure CfgObj.SetPrnName(PN: String);
  Begin
  End;

Function CfgObj.GetOffTypeAvail(OT: Word): Boolean;
  Begin
  GetOffTypeAvail := False;
  End;

Procedure CfgObj.SetOffTypeAvail(OT: Word; Avail: Boolean);
  Begin
  End;

Function CfgObj.GetOffAllowNew: Boolean;
  Begin
  GetOffAllowNew := True;
  End;

Procedure CfgObj.SetOffAllowNew(OA: Boolean);
  Begin
  End;

Function CfgObj.GetOffForceNew: Boolean;
  Begin
  GetOffForceNew := False;
  End;

Procedure CfgObj.SetOffForceNew(OA: Boolean);
  Begin
  End;

Function CfgObj.GetOffAllowScrn: Boolean;
  Begin
  GetOffAllowScrn := True;
  End;

Procedure CfgObj.SetOffAllowScrn(OA: Boolean);
  Begin
  End;

Function CfgObj.GetOffForceScrn: Boolean;
  Begin
  GetOffForceScrn := False;
  End;

Procedure CfgObj.SetOffForceScrn(OA: Boolean);
  Begin
  End;

Function CfgObj.GetOffAllowBull: Boolean;
  Begin
  GetOffAllowBull := True;
  End;

Procedure CfgObj.SetOffAllowBull(OA: Boolean);
  Begin
  End;

Function CfgObj.GetOffForceBull: Boolean;
  Begin
  GetOffForceBull := False;
  End;

Procedure CfgObj.SetOffForceBull(OA: Boolean);
  Begin
  End;

Function CfgObj.GetOffAllowFreq: Boolean;
  Begin
  GetOffAllowFreq := False;
  End;

Procedure CfgObj.SetOffAllowFreq(OA: Boolean);
  Begin
  End;

Function  CfgObj.GetOffMax: Word;
  Begin
  GetOffMax := 2000;
  End;

Procedure CfgObj.SetOffMax(OM: Word);
  Begin
  End;

Function  CfgObj.GetOffConfMax: Word;
  Begin
  GetOffConfMax := 1000;
  End;

Procedure CfgObj.SetOffConfMax(CM: Word);
  Begin
  End;

Function  CfgObj.GetOffCompRate: Word;
  Begin
  GetOffCompRate := 50;
  End;

Procedure CfgObj.SetOffCompRate(CM: Word);
  Begin
  End;

Function  CfgObj.GetOffSafetyMin: Word;
  Begin
  GetOffSafetyMin := 5;
  End;

Procedure CfgObj.SetOffSafetyMin(SM: Word);
  Begin
  End;

Function CfgObj.GetOffScrns(SN: Word): String;
  Begin
  GetOffScrns := '';
  End;

Procedure CfgObj.SetOffScrns(SN: Word; Scrn: String);
  Begin
  End;

Function CfgObj.GetOffBulls(BN: Word): String;
  Begin
  GetOffBulls := '';
  End;

Procedure CfgObj.SetOffBulls(BN: Word; Bull: String);
  Begin
  End;

Function CfgObj.GetUserFileName: String;
  Begin
  GetUserFileName := WithBackSlash(GetMsgPath(1)) + 'users.bbs';
  End;

End.
