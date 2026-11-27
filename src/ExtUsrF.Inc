{ SPDX-License-Identifier: GPL-3.0-or-later }
{ The fields of the ExtUsers.Bbs record that come before the password hash (included twice by Struct.MK) }
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
