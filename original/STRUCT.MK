
{       ********** MKBBS v1.00 Structures ************        }

Type EventStatus = (etDelected, etEnabled, etDisabled);


Type EventType = Record
  Status: Byte;
  Time: String[5];
  ErrorLvl: Byte;
  Days: Byte;
  Forced: Byte;
  LastRun: String[8];
  End;

Const
  esDeleted = 0;
  esEnabled = 1;
  esDisabled = 2;


Type DoorRecType = Record
  MenuType: Byte;
  Data: String[80];
  Sec: SecType;
  End;


Type NodeIdxType = Record
  NodeType: Byte;
  Number: Word;
  Cost: Word;
  FileNum: Byte;
  FilePos: LongInt;
  End;



Type NodeIncType = Record
  FileName: String[12];
  FileTime: LongInt;
  End;


Type UsersType = Record                {Users.Bbs file}
  Name: String[35];                    {Users Name - Proper Case}
  City: String[25];                    {Users City and State}
  Pwd: String[15];                     {Users Password}
  DPhone: String[12];                  {Users Date/Business Phone}
  HPhone: String[12];                  {Home/Voice Phone}
  LastTimeOn: String[5];               {Last Time logged on HH:MM}
  LastDateOn: String[8];               {Last Date logged on MM-DD-YY}
  Attr: Byte;                          {Attributes see constants below}
  Flags: LongInt;                      {Security flags 32 bitmapped}
  Credit: Integer;                     {NetMail credit}
  Pending: Integer;                    {NetMail credit reduction pending export}
  MsgsEntered: Word;                   {Number of messages posted}
  HighMsgRead: Word;                   {Combined reading highread pointer}
  Security: Word;                      {Security level}
  TimesCalled: Word;                   {Number of times logged on}
  ULFiles: Word;                       {Number of files uploaded}
  DLFiles: Word;                       {Number of files downloaded}
  ULk: Word;                           {Number of K uploaded}
  DLk: Word;                           {Number of K downloaded}
  TodayK: Integer;                     {Net K transfered today}
  ElapsedTime: Integer;                {Elapsed time in prior calls during day}
  ScrnLen: Word;                       {Screen length in range 10 thru 66}
  Extra: Array[1..8] of Byte;          {Unused}
  End;


Const                                  {Users.Attr values}
  uaDeleted =      1;                  {User is deleted}
  uaScrnClr =      2;                  {Clear screen between displays}
  uaMore =         4;                  {Ask more?}
  uaAnsi =         8;                  {Wants ansi screens}
  uaNoKill =      16;                  {Do not purge ever}
  uaIgnoreHrs =   32;                  {Ignore DL hours}
  uaFullScrEd =   64;                  {Use full screen editor}


Type ExtUserType = Record              {ExtUsers.Bbs file}
  Handle: String[35];                  {Users handle}
  Birthdate: String[6];                {BirthDate YYMMDD}
  Expire: String[6];                   {Subscription expiration date YYMMDD}
  FirstCall: String[6];                {Date first called YYMMDD}
  NewDate: String[6];                  {New files date YYMMDD}
  PageTune: Byte;                      {Page tune to use 0=silence}
  Address: String[40];                 {Street address}
  ZipCode: String[10];                 {Zip (Postal) Code}
  Comment: String[70];                 {Sysop defined comment}
  Offline: Array[1..64] of Byte;       {Bitmap areas for offline reading}
  Combined: Array[1..64] of Byte;      {Bitmap of areas used in combined read}
  NetStat: LongInt;                    {Bitmap netstatus}
  BankTime: LongInt;                   {Time bank minutes stored}
  BankBytes: LongInt;                  {Time bank bytes stored}
  ExtraInfo: Word;                     {See constants below}
  Protocol: Char;                      {Preferred transfer protocol}
  Packer: Char;                        {Preferred archive packer}
  QuoteCtr: Word;                      {Which quote last sent}
  CurrFileArea: Word;                  {Current file template area}
  CurrMsgArea: Word;                   {Current msg template area}
  CurrDoorArea: Word;                  {Current door template area}
  AddOn: Array[1..40] of Byte;         {For add-on program usage}
  TodayCalls: Byte;                    {Num calls today}
  OffType: Char;                       {Offline mail pkt type}
  OffAttr: Word;                       {Offline attribute settings}
  OffMax: Word;                        {Offline max msgs per pkt}
  OffConfMax: Word;                    {Offline max msgs per area}
  Expansion: Array[1..43] of Byte;     {Unused}
  End;


Const                                  {ExtUser.ExtraInfo}
  eiMale =         1;                  {Gender 1=male 0=female}
  eiVisitSys =     2;                  {Visiting sysop}
  eiPageBan =      4;                  {Banned from paging sysop}
  eiHidden =       8;                  {Do not include in displays}
  eiNoRatio =     16;                  {Ignore file transfer ratios}
  eiIgnorePgHrs = 32;                  {May page outside normal hours}
  eiAutoPage =    64;                  {Automatic page at log-on}
  eiHiddenPage = 128;                  {Auto page but hidden from caller}
  eiAvatar =     256;                  {Avatar graphics}

  uoaNew =         1;                  {New files list}
  uoaScrn =        2;                  {Screens}
  uoaBull =        4;                  {Bulletins}
  uoaVerify =      8;                  {Verify want pkt}
  uoaFlag =       16;                  {Flag as read}
  uoaOwn =        32;                  {Own messages}
  uoaAllYour =    64;                  {Your in all areas}
  uoaZero =      128;                  {Send zero msg pkts}
  uoaGateWay =   512;                  {Offline mail gateway}


Type UsersIdxType = Record             {UsersIdx.Bbs File}
  NameCrc: LongInt;                    {CRC32 of Users name}
  HandleCrc: LongInt;                  {CRC32 of Users handle}
  End;


Type InProtType = Record
  Key: Char;
  Attr: Word;
  Name: String[15];
  End;


Type ExtProtType = Record
  Key: Char;
  Attr: Word;
  Name: String[15];
  CmdLine: String[80];
  End;


Type ExtPackType = Record
  Key: Char;
  Attr: Word;
  Name: String[15];
  PCmdLine: String[80];
  UCmdLine: String[80];
  End;


Type BbsCfg = Record                   {Config.Mk file}
  CommPort: Byte;                      {Comm port to use}
  InitBaud: LongInt;                   {Baudrate to init modem}
  LockedBaud: LongInt;                 {Locked baud rate 0=unlocked}
  ModemDelay: Byte;
  InitTimes: Byte;
  AnswerWait: Byte;
  InitStr: String[40];
  BusyStr: String[40];
  Response: String[40];
  ConnectStr: Array[1..11] of String[40];
  ExitEL: Array[1..11] of Byte; {Exit ErrorLevels from front-end when
    returning to the Bbs -  Local 300 1200 2400 4800 7200 9600 12000
    14400 19200 38400}
  FunctionKeys: Array[1..10] of String[60];
  AnswerStr: String[40];
  RingStr: String[40];
  NodeAttr: Word;                      {See constants below}
  BoardId: String[8];                  {Bbs name for filenames}
  TempPath: String[60];                {Path for temporary files}
  LogFileName: String[60];             {Log File Path\Name.Extension}
  BbsPhone: String[15];                {Bbs Phone Number}
  SysopName: String[35];               {Sysop Name}
  BbsLocation: String[40];             {Bbs City and State}
  SystemName : String[40];             {Bbs Name}
  Color: Array[1..5] of Byte;          {Bbs color scheme}
  TimeOut: Word;                       {seconds for user timeout}
  COption: Word;                       {see constants below}
  COption2: Word;                      {second set of options}
  NewOpt: Word;                        {New user options}
  LogInTime: Byte;                     {Minutes to finish log-in}
  MaxPages: Byte;                      {Maximum number of pages per call}
  PageStart: Array[0..6] of Word;      {Start Page Time hi=hour lo=min}
  PageStop: Array[0..6] of Word;       {Stop Page Time}
  DefPage: Byte;                       {New user default page tune}
  PageLength: Byte;                    {Seconds to play page}
  PageMsgArea: Word;                   {Msg area for page messages}
  LoBaudStart: Word;                   {hi=hour lo=min low baud start time}
  LoBaudStop: Word;                    {hi=hour lo=min low baud stop time}
  MinBaud: Word;                       {Min baud rate to use system}
  XferBaud: Word;                      {Min baud to transfer files}
  AnsiBaud: Word;                      {Min baud for ansi graphics}
  NewSec: SecType;                     {New user security level}
  NewCredit: Integer;                  {New user netmail credit}
  IdleTime: Word;                      {Seconds before idle timeout}
  PassTries: Byte;                     {Maximum password tries}
  PwdExpire: Byte;                     {Calls before password expires}
  MinPWD: Byte;                        {Minimum password length}
  MinPhone: Byte;                      {Minimum phone number length}
  DLStart: Word;                       {Start DL time hi=hour lo=min}
  DLStop: Word;                        {Stop DL Time}
  WaitTime: Byte;                      {seconds to wait 0=press enter}
  LangName: Array[1..10] of String[10];{Language display names}
  LangFile: Array[1..10] of String[8]; {Language file names no extension}
  MenuPath: Array[1..10] of String[60];{Path to menus for each language}
  TxtPath: Array[1..10] of String[60]; {Path to asc/ans for each language}
  QuesPath: Array[1..10] of String[60]; {Path to .q-a for each language}
  MsgPath: Array[1..10] of String[60];  {Main msg base path is #1}
  QuoteStr: String[15];                {Message quoting prefix}
  EditCmdPath: String[60];             {Path/name message editor}
  NetMailPath: String[60];             {Path to netmail directory}
  NodeListPath: String[60];            {Path to nodelist directory}
  SemaphorePath: String[60];           {Path to user for semaphore files}
  AttachPath: String[60];              {Local file attach path}
  OfflineMax: Word;                    {Maximum messages in offline packet}
  OfflineConfMax: Word;                {Max msgs per area in offline packet}
  Origin: Array[1..20] of String[55];  {Origin Lines}
  Addr: Array[1..10] of AddrType;      {Fido-style addresses and AKA's}
  NetBoard: Array[1..10] of Word;      {NetMail areas for addresses/AKA's}
  Default: Word;                       {Default area for messages}
  Announce: Word;                      {Announcement message area}
  PwdMsgArea: Word;                    {Msg area for failed password msgs}
  Attr: Word;                          {Message config options see constants}
  CrashSec: SecType;                   {Minimum security for crash netmail}
  CrashForce: SecType;                 {Minimum security level forced crash nm}
  FAttachSec: SecType;                 {Minimum security for file attaches}
  FReqSec: SecType;                    {Minimum security to file request}
  MsgDelSec: SecType;                  {Minimum security to delete msgs}
  MsgNoRcv: SecType;                   {Minimum security to unreceive msgs}
  MinDesc: Byte;                       {Minimum file description length}
  MaxDesc: Byte;                       {Maximum file descritpion length}
  MinUlSpace: LongInt;                 {Minimum free space remaining}
  ULCredit: Word;                      {Credit for uploads}
  AddOn: Array[1..40] of Byte;         {For add-ons to claim space}
  LogAttr: Byte;                       {Type and level of logging}
  CheckBD: Byte;                       {Check birthdate at log-on}
  CheckPhone: Byte;                    {Check phone at log-on}
  PrinterName: String[20];             {Device for printer output}
  Events: Array[1..30] of EventType;   {Event info}
  Doors: Array[1..10] of DoorRecType;  {Doors available at log-on}
  InProt: Array[1..10] of InProtType;   {Internal protocols}
  ExtProt: Array[11..20] of ExtProtType; {External protocols}
  EchoLog: String[60];
  ExtPack: Array[1..10] of ExtPackType; {External compression programs}
  OffAvail: Array[1..10] of Boolean; {Offline pkt types avail}
  OffAttr: Word; {Offline mail settings = see oa constants}
  OffMax: Word; {Maximum offline msgs per packet}
  OffConfMax: Word; {Maximum per area offline msgs}
  OffComp: Byte; {Compression percentage assumed}
  OffSafety: Byte; {Minutes safety time assumed}
  OffScrns: Array[1..5] of String[8]; {Offline screen names}
  OffBulls: Array[1..10] of String[8]; {Offline bulletins}
  End;


Const                                  {Cfg protocol attr}
  paAvail = 01;                        {available for normal xfer}
  paSpecial = 02;                      {available for special xfer}


Const                                  {NodeCfg Attr}
  ncBreak = 01;                        {Send break to clear modem buffer}
  ncAnswer = 02;                       {Send answer string to modem}


Const                                  {Config.Mk COption}
  coDirect = 04;                       {Direct screen writes}
  coKillSentYes = 08;                  {NetMail always kill/sent}
  coKillSentAsk = 24;                  {Ask whether NetMail is kill/sent}
  coTimeOutLocal = 32;                 {TimeOut in local mode}
  coCheckMailAsk = 64;                 {Ask for mail check}
  coForceMailChk = 128;                {Force mail check}
  coCheckFiles = 256;                  {Ask new files check}
  coForceFiles = 512;                  {Force new files check}
  coFastLogIn = 1;                     {Fast local log-in}
  coAllowSysRemote = 2;                {Allow remote sysop access}
  coMono = 1024;                       {Local display is mono}
  coStrictPwd = 2048;                  {Strict password check}
  coSnowCheck = 4096;                  {CGA snow checking}
  coOneWordName = 8192;                {Allow one word names}
  coFullMail = 16384;                  {Full mail check}


Const                                  {ConfigMK.Bbs COption2}
  csShowQuote = 1;                     {Show quote at log-on}
  csPageReason = 2;                    {Ask reason for page}
  csPageMsg = 4;                       {Ask leave msg? after page}
  csEMSI = 8;                          {Allow EMSI logons}
  csNewEMSI = 16;                      {Allow new user EMSI logons}
  csChatCapture = 32;                  {Automatically log chats}
  csMailCheckDetail = 64;              {Show detail during scan}
  csMailCheckTotal = 128;              {Show totals after scan}


Const                                  {Config.MK LogAttr}
  laOpus = 00;                         {Opus style logging}
  laFD = 01;                           {FrontDoor style logging}
  laQuick = 02;                        {QuickBbs style logging}
  laMK = 03;                           {Extra logging style - unused}
  laMin  = 00;                         {Minimal logging}
  laNormal = 04;                       {Normal logging}
  laExtra = 08;                        {Extra logging}
  laVerbose = 12;                      {Very verbose logging}


Const                                  {Config.Mk NewOpt}
  noAskHome = 01;                      {Ask home voice phone number}
  noAskData = 02;                      {Ask business data phone}
  noAskBirth = 04;                     {Ask birthdate}
  noAskGender = 08;                    {Ask gender}
  noAskHandle = 16;                    {Ask for handle}
  noAskAddr = 32;                      {Ask for address}
  noAskAnsi = 64;                      {Ask user if they support ansi}
  no7BitName = 128;                    {Force 7 bit char in names only}
  noOneWord = 256;                     {Allow one word names}
  noReAsk = 512;                       {ReAsk Questions with Blank Answers}
  noAvatar = 1024;                     {Ask user if they support avatar}

Const                                  {OffAttr = offline mail settings}
 oaAllowNew = 1;                       {Allow new files list}
 oaForceNew = 2;                       {Force new files list}
 oaAllowScrn = 4;                      {Allow screens}
 oaForceScrn = 8;                      {Force screens}
 oaAllowBull = 16;                     {Allow bulletins}
 oaForceBull = 32;                     {Force bulletins}
 oaAllowFreq = 64;                     {Allow file requests}

Const                                  {MsgCfg.Attr}
  mcAltLocking = 001;                  {True = record locking False=file lock}
  mcRedate = 002;                      {Redate offline msgs to import date}


Type SysInfoType = Record              {SysInfo.Bbs file}
  CallCount: LongInt;                  {System calls to date}
  LastCaller: String[35];              {Last callers name}
  Extra: Array[1..128] of Byte;        {Unused}
  End;


Type TimeLogType = Record              {TimeLog.Bbs file}
  StartDate: String[8];                {Date started MM-DD-YY}
  BusyPerHour: Array[0..23] of Word;   {Minutes usage each hour}
  BusyPerDay: Array[0..6] of Word;     {Minutes usage each day}
  End;


Type MenuType = Record                 {*.Mnu files}
  Typ: Byte;                           {Menu command type}
  Security: Word;                      {Menu security level}
  Flags: LongInt;                      {Menu security flags}
  Prompt: String[75];                  {Prompt line}
  Key: Char;                           {Letter key ^A=autoexecute}
  Data: String[80];                    {Data/info line}
  FgColor: Byte;                       {Foreground color}
  BgColor: Byte;                       {Background color}
  End;


Type MsgAreaType = Record              {Messages.MK file contains 500 of these}
  Name: String[25];                    {Name of message area}
  ShortName: String[12];               {Short name of msg area}
  MsgBaseType: Char;                   {H=Hudson S=Squish F=Fido}
  MsgBaseDir: Byte;                    {Which msg base path 1..10}
  FileId: String[8];                   {Filename for Squish, Subdir for Fido}
  Addr: Byte;                          {Which address to use}
  Origin: Byte;                        {Which origin to use}
  NetStat: LongInt;                    {Bit map of net status networks}
  MsgType: Byte;                       {Type of messages - see constants}
  Permit: Word;                        {Permitted options - see constants}
  Permit2: Word;                       {Expansion room for options}
  DaysKept: Word;                      {Days messages are kept}
  MsgsKept: Word;                      {Number of messages kept}
  RcvdDays: Word;                      {Days recd messages are kept}
  ReadSec: SecType;                    {Security to read area}
  WriteSec: SecType;                   {Security to post in area}
  SysopSec: SecType;                   {Security for sysop access}
  Select: String[4];                   {For limitting selections}
  End;


Type MsgCfgType = Array[1..500] of MsgAreaType;


Const
  mtNormal = 00;                       {Normal message area}
  mtNet = 01;                          {NetMail message area}
  mtEcho = 03;                         {EchoMail message area}


Type EchoSystemType = Record           {Systems to exchange echomail with}
  Addr: AddrType;                      {Address of system}
  Archiver: Byte;                      {Archiver choice}
  Networks: LongInt;                   {Networks - for areafixes}
  Attr: Word;                          {Options - see below}
  PWD: String[15];                     {Areafix password}
  End;


Const                                  {EchoSystem.Attr values}
  esImm = $00;                         {Value 0 thru 3 indicates how}
  esCrash = $01;                       {the file attach msg will be coded}
  esNormal = $02;
  esHold = $03;


Type EchoAreaType = Record
  AreaTag: String[40];                 {EchoMail Area: tag}
  EchoTo: LongInt;                     {Systems to echo the area to}
  Attr: Word;                          {Options - see values below}
  Hub: Byte;                           {Hub for area}
  End;


Const                                  {EchoArea.Attr values}
  eaKeepPath = $01;                    {Keep path info}
  eaHidePath = $02;                    {Hide path in message base}
  eaKeepSeen = $04;                    {Keep seen-by info}
  eaHideSeen = $08;                    {Hide seen-by in msg base}
  eaPassThru = $16;                    {Pass-thru area}


Type EchoCfgType = Record
  InBoundFiles: String[50];            {InBound files directory}
  OutBoundFiles: String[50];           {OutBound files directory}
  MaxPktSize: LongInt;                 {Maximum Outgoing pkt size}
  EchoSys: Array[1..32] of EchoSystemType; {Systems to echo to}
  EchoArea: Array[1..500] of EchoAreaType; {Echo area info}
  End;


Type FileAreaType = Record             {Files.MK file}
  Name: String[30];                    {Name - blank = unused}
  ShortName: String[12];               {Short version of area name}
  FilePath: String[50];
  ViewSec: SecType;
  DLSec: SecType;
  ULSec: SecType;
  PFileSec: SecType;
  Attr: Word;
  Select: String[4];                   {For limitting selections}
  End;


Type FileCfgType = Array[1..300] of FileAreaType;


Const                                  {FileArea.Attr}
  faNoUL = 01;                         {Dissallow uploads}
  faNoNew = 02;                        {Ignore in new files search}
  faFree = 04;                         {Do not count in DL}
  faNoTime = 08;                       {Ignore time remain limit}
  faNoBaud = 16;                       {Ignore min baud limit}


Const                                  {MsgArea.Permit}
  mpAnsi =         1;                  {Allow (esc) character}
  mpHiBit =        2;                  {Allow hi-bit characters}
  mpTagLines =     4;                  {Allow taglines}
  mpAlias =        8;                  {Allow alias name}
  mpRealName =    16;                  {Allow real name}
  mpAnon =        32;                  {Allow anonymous names}
  mpPriv =        64;                  {Allow priviledged mail}
  mpPubl =       128;                  {Allow public mail}
  mpOrg =        256;                  {Reader Origin Lines}
  mpOffline =    512;                  {Allow in offline readers}
  mpForce =     1024;                  {Force in offline readers}
  mpCombine =   2048;                  {Allow in combined read}
  mpFido =      4096;                  {Add tear and origin lines}
  mpTear =      8192;                  {Keep reader tearline text}
  mpFileAttach=16384;                  {Allow file attaches}
  mpDefCombine=32768;                  {Default combined area}


Type GoSubType = Array[1..20] of String[8];


Const TagLimit = 40;


Type TagRecType = Record
  FilePath: String[70];
  Size: LongInt;
  End;


Type ExitInfoType = Record             {ExitInfo.Bbs}
  Baud: Word;
  SysInfo: SysInfoType;
  TimeLog: TimeLogType;
  User: UsersType;
  Event: EventType;
  NetMailEntered: Boolean;
  EchoMailEntered: Boolean;
  LogInTime: String[5];
  LogInDate: String[8];
  TimeLimit: Integer;
  LogInSec: LongInt;
  Credit: LongInt;
  UserRecNum: Word;
  ReadThru: Word;
  PagedTimes: Word;
  DLLimit: Word;
  WantChat: Boolean;
  GoSubLevel: Byte;
  GoSub: GoSubType;
  Menu: String[8];
  ExtUser: ExtUserType;
  Language: Byte;
  Tagged: Array[1..TagLimit] Of TagRecType;
  NumTagged: Word;
  End;

Type UserOnType = Record
  Name: String[35];
  Handle: String[35];
  Node: Byte;
  Baud: Word;
  City: String[25];
  Status: Byte;
  End;


