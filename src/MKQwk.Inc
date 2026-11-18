
{               MKQwk Copyright 1991, 1993 by Mark May                }
{      Mythical Kingdom Software 1:110/290 513-237-7737 V32/HST       }

Const
  Version   = 'MKQwk Version 1.10';
  Copyright = 'MKQwk Copyright 1991, 1993 by Mark May - All rights reserved';


Const                                  {Yes/No/Ask constants}
  qatNo =    0;                        {no/false}
  qatYes =   1;                        {yes/true}
  qatNew =   2;                        {new only}
  qatAskY =  3;                        {ask default yes}
  qatAskN =  4;                        {ask default no}


Type ConfCfg = Record                  {CONFS.MKO file in BBS directory}
  ShortName: String[12];               {Optional short conf name}
  MsgAreaId: String[60];               {Override msg area id}
  MsgType: Byte;                       {Override area type}
  Addr: AddrType;                      {Override address}
  Avail: Byte;                         {Force, not avail, normal ask}
  NetType: LongInt;                    {Bit map netstatus types}
  Attr: Word;                          {see qca attributes}
  End;


Const                                  {Conference attributes}
  qcaAllowHi =    1;                   {Allow hi-bit characters}
  qcaRemvTear =   2;                   {Remove tearline text}
  qcaTagOrig =    4;                   {Convert tagline to origin line}
  qcaStripTag =   8;                   {Strip taglines}
  qcaAllowAnsi = 16;                   {allow [Esc] character}
  qcaNoReply =   32;                   {read only area}


Type ProtCfg = Record
  ProtActive: Boolean;                 {Active / Inactive flag}
  SendCmd: String[70];                 {Send program cmd line}
  RcvCmd: String[70];                  {Rcv program cmd line}
  End;


Type PackCfg = Record
  PackActive: Boolean;                 {Active flag}
  PackCmd: String[70];                 {Pack program cmd line}
  UnPackCmd: String[70];               {Unpack program cmd line}
  End;


Type UserConfType = Record
  Area: Word;
  Typ: Byte;
  End;


Const QwkUserAreas = 200;

Type UserConfArray = Array[1..QwkUserAreas] of UserConfType;

Type QwkCfg = Record                   {CONFIG.MKO file}
  BoardId: String[8];                  {BBS identifier}
  BbsPhone: String[40];                {BBS phone number}
  LockedBaud: Word;                    {Locked baud rate 0=unlocked}
  Direct: Boolean;                     {Direct screen writes}
  ForceName: Boolean;                  {Force msgs to log-in name}
  BadMsgArea: Word;                    {Default msg area for bad msgs}
  MaxMsgs: Word;                       {Max msgs per packet}
  MaxConfMsgs: Word;                   {Max msgs per conference}
  NewFiles: Byte;                      {New file include}
  Screens: Byte;                       {Send welcome/bye screens}
  Bulletins: Byte;                     {Send bulletins}
  SecCrash: Word;                      {Min security for Fido Crash}
  SecImd: Word;                        {Min security for Fido Immed}
  CostMyNet: Word;                     {NetMail cost in MyNet}
  CostNormal: Word;                    {Normal netmail cost}
  CostZone: Word;                      {InterZone NetMail cost}
  CostCrash: Word;                     {CrashMail NetMail cost}
  CostImd: Word;                       {Immediate NetMail cost}
  ScrnHello: String[8];                {Hello screen name no .ext}
  ScrnNews: String[8];                 {News screen name no .ext}
  ScrnBye: String[8];                  {Goodbye screen name no .ext}
  BullNames: Array [1..10] of String[8]; {Bulletin file names}
  NewScrn: String[8];                  {New files screen no .ext}
  Packers: Array[1..10] of PackCfg;    {Pack/unpack configuration}
  Prots: Array[1..10] of ProtCfg;      {Protocol configuration}
  TempPath: String[80];                {Path for temporary files}
  UserPath: String[80];                {Path for Qwk user file}
  Attr: Word;                          {See qa constants}
  DefUserConfs: UserConfArray;         {Default active confs}
  DefNetStat: LongInt;                 {Default net status}
  DefMaxMsgs: Word;                    {Default Max messages per packet}
  DefMaxConfMsgs: Word;                {Default Max messages per conference}
  DefProtocol: Char;                   {Default 'A' thru 'Z' space = undefined}
  DefPacker: Char;                     {Default 'A' thru 'Z' space = undefined}
  DefAttr: Word;                       {Default Various Option Flags}
  DefMailType: Byte;                   {Default Mail packet format}
  OverrideOrig: String[55];            {Override area origin}
  ScreenPath: String[80];              {MKQwk screens path}
  End;


Const
  qaReDate =     1;                    {Redate msgs to upload date}
  qaAllowTwit =  2;                    {Allow twitting}
  qaAllowFreq =  4;                    {Allow file requests}
  qaQwke =       8;                    {QWKE long names and subjects in packets}



Type QwkUserRec = Record               {USERS.MKO file in BBS dir}
  Name: String[35];                    {Proper case user name}
  LastUsed: LongInt;                   {Dos style date/time}
                                       {0=not used, 1=Deleted}
  UserConfs: UserConfArray;            {active confs}
  NetStat: LongInt;                    {Bit array of netstatus confs}
  MaxMsgs: Word;                       {Max messages per packet}
  MaxConfMsgs: Word;                   {Max messages per conference}
  Protocol: Char;                      {'A' thru 'Z' space = undefined}
  Packer: Char;                        {'A' thru 'Z' space = undefined}
  Attr: Word;                          {Various Option Flags}
  MailType: Byte;                      {Mail packet format}
  Twits: Array[1..5] of String[35];    {Twit list}
  MsgsDL: LongInt;                     {messages downloaded}
  MsgsUL: LongInt;                     {messages uploaded}
  PointNum: Word;                      {point number}
  End;


Const                                  {user attributes}
  quaAllYours =  1;                    {check all areas for your mail}
  quaNoMsg =     2;                    {send pkts with no messages}
  quaAskPkt =    4;                    {ask before sending packet}
  quaNoUL =      8;                    {don't allow replies to be UL'd}
  quaOwnMsgs =  16;                    {Receive own msgs}
  quaFlagRead = 32;                    {Flag msgs as read}
  quaBulletin = 64;                    {Get bulletins}
  quaScreens = 128;                    {Get screens}
  quaNewFile = 256;                    {Get new files}
  quaNewBull = 512;                    {New bulletins only}
  quaNoFreq = 1024;                    {Don't allow file requests}


Const                                  {Offline mail packet types}
  qmtText =     1;                     {Text packets}
  qmtQwk  =     2;                     {QWK packets}
  qmtXrs  =     3;                     {XRS packets}
  qmtBwv  =     4;                     {Bluewave packets}
  qmtPkt  =     5;                     {PKT packets}

Const                                  {User conf area types}
  qctNone =     0;                     {none/inactive area}
  qctOn   =     1;                     {area selected}
  qctMy   =     2;                     {area my mail only}
  qctAll  =     3;                     {my mail and mail to All}
