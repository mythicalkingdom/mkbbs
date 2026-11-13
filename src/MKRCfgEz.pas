Unit MKRCfgEz;
{ Read-Only config object for Ezy }

{$I MKB.Def}

Interface


Uses MKGlobT, MKFile, MKCfgAbs,
  Dos;

{$I Struct.Ezy}

Const
  MASize = 50;
  FASize = 50;


Type
  MsgCfgArray = Array[1..MASize] of MsgAreaType;
  FileCfgArray = Array[1..FASize] of FileAreaType;


Type EzRCfgObj = Object(CfgObj)
  EzCfg:    ^BbsCfg;
  EzConst: ^ConstType;
  MsgLoaded: Word;
  FileLoaded: Word;
  EzMsg: ^MsgCfgArray;
  EzFile: ^FileCfgArray;
  EzMsgFile: File;
  EzFileFile: File;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure EzLoad; Virtual;{Normally internal to load MK config}
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
  Function  GetDefaultOrigStr(Area: Word): String; Virtual; {Get full origin string w/addr}
    {includes the * Origin and default text and address}
  Function  GetSysopName: String; Virtual; {Get config name of sysop}
  Function  GetMaxFileAreas: Word; Virtual; {Get maximum number of file areas}
  Function  GetFileAreaName(Area: Word): String; Virtual; {Get file area name}
  Function  GetFileShortName(Area: Word): String; Virtual; {Get short name for area}
  Function  GetFileSelect(Area: Word): String; Virtual; {Get file area select name}
  Function  GetMinDesc: Byte; Virtual; {Get min descr length}
  Function  GetMaxDesc: Byte; Virtual; {Get max descr length}
  Function  GetOrigStr(OrigNum: Word): String; Virtual; {Get origin string}
  Function  GetDefaultPort: Word; Virtual; {Get default comm port}
  Function  GetMsgPathNum(Area: Word): Word; Virtual; {Get message path number}
  Function  GetMsgAreaId(Area: Word): String; Virtual; {Get message area id string}
  Function  GetEzyLastSize: Word; Virtual; {Get size of EZ LastRead record}
  Function  GetUserPath: String; Virtual; {Get user base path}
  End;

Type EzRCfgObjPtr = ^EzRCfgObj;


Implementation


Uses MKString;

Function EzRCfgObj.GetEzyLastSize: Word;
  Begin
  GetEzyLastSize := ((EzConst^.UsableMsg + 15) Div 16) * 34;
  End;


Function EzRCfgObj.GetUserPath: String;
  Begin
  GetUserPath := WithBackSlash(EzCfg^.UserBasePath);
  End;


Function EzRCfgObj.GetMsgPath(BaseNo: Word): String;
  Begin
  GetMsgPath := EzCfg^.MsgPath;
  End;


Function EzRCfgObj.GetTxtPath(Num:Word): String; {Get path to asc/ans/avt files}
  Begin
  GetTxtPath := EzCfg^.TxtPath;
  End;


Function EzRCfgObj.GetMnuPath(Num: Word): String; {Get path to menu *.mnu files}
  Begin
  GetMnuPath := EzCfg^.MenuPath;
  End;


Function EzRCfgObj.GetNetPath: String;
  Begin
  GetNetPath := EzCfg^.NetMailPath;
  End;


Function EzRCfgObj.GetTempPath: String;
  Begin
  GetTempPath := EzCfg^.TempPath;
  End;


Function EzRCfgObj.GetLogFileName: String;
  Begin
  GetLogFileName := EzCfg^.LogFileName;
  End;



Function EzRCfgObj.GetEditCmdPath: String;
  Begin
  GetEditCmdPath := EzCfg^.EditCmdPath;
  End;



Function EzRCfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := EzCfg^.NodeListPath;
  End;



Function EzRCfgObj.GetAttachPath: String;
  Begin
  GetAttachPath := EzCfg^.AttachPath;
  End;



Function EzRCfgObj.GetSemaphorePath: String; {Get Semaphore file path}
  Begin
  GetSemaphorePath := EzCfg^.TempPath;
  End;



Function EzRCfgObj.GetBbsType: Word;
  Begin
  GetBbsType := CfgInfo^.BbsType;
  End;



Function EzRCfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := CfgInfo^.BbsPath;
  End;



Procedure EzRCfgObj.EzLoad;
  Begin
  New(EzCfg);
  New(EzConst);
  New(EzMsg);
  New(EzFile);
  Error := LoadFile(FindBbsFile('Config.Ezy') + 'Config.Ezy', EzCfg^, SizeOf(EzCfg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Messages.Ezy') + 'Messages.Ezy', EzMsg^, SizeOf(EzMsg^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Constant.Ezy') + 'Constant.Ezy', EzConst^, SizeOf(EzConst^));
  If Error = 0 Then
    Error := LoadFile(FindBbsFile('Files.Ezy') + 'Files.Ezy', EzFile^, SizeOf(EzFile^));
  Assign(EzMsgFile, ResolveCase(FindBbsFile('Messages.Ezy') + 'Messages.Ezy'));
  Assign(EzFileFile, ResolveCase(FindBbsFile('Files.Ezy') + 'Files.Ezy'));
  FileMode := fmReadOnly + fmDenyNone;
  MsgLoaded := 1;
  FileLoaded := 1;
  Reset(EzMsgFile, 1);
  Reset(EzFileFile, 1);
  If IoResult <> 0 Then
    Error := 10;
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(EzCfg);
    Dispose(EzConst);
    Dispose(EzMsg);
    Dispose(EzFile);
    End;
  End;


Procedure EzRCfgObj.Allocate;
  Begin
  If Not CfgInfo^.Loaded Then
    Begin
    New(EzCfg);
    New(EzConst);
    New(EzMsg);
    New(EzFile);
    FillChar(EzCfg^, SizeOf(EzCfg^), 0);
    FillChar(EzConst^, SizeOf(EzConst^), 0);
    FillChar(EzMsg^, SizeOf(EzMsg^), 0);
    FillChar(EzFile^, SizeOf(EzFile^), 0);
    CfgInfo^.BbsPath := GetEnv('EZY');
    AddBackSlash(CfgInfo^.BbsPath);
    CfgInfo^.Loaded := True;
    End;
  End;


Procedure EzRCfgObj.Unload;
  Begin
  If CfgInfo^.Loaded Then
    Begin
    Dispose(EzCfg);
    Dispose(EzConst);
    Dispose(EzMsg);
    Dispose(EzFile);
    Close(EzMsgFile);
    Close(EzFileFile);
    If IoResult <> 0 Then;
    CfgInfo^.Loaded := False;
    End;
  End;


Procedure EzRCfgObj.Load;
  Var
    CPath: String;
    i: Word;

  Begin
  CPath := GetCurrentPath;
  CfgInfo^.BbsPath := GetEnv('EZY');
  AddBackSlash(CfgInfo^.BbsPath);
  EzLoad;
  If CfgInfo^.BbsPath = '' Then
    Error := 2000;
  If Error = 0 Then
    Begin
    ChDir(StripTrail(CfgInfo^.BbsPath, DirectorySeparator));
    CfgInfo^.BbsPath := WithBackSlash(FExpand(CfgInfo^.BbsPath));
    EzCfg^.TempPath := WithBackSlash(FExpand(EzCfg^.TempPath));
    EzCfg^.TxtPath := WithBackSlash(FExpand(EzCfg^.TxtPath));
    EzCfg^.MenuPath := WithBackSlash(FExpand(EzCfg^.MenuPath));
    EzCfg^.MsgPath := WithBackSlash(FExpand(EzCfg^.MsgPath));
    EzCfg^.NetMailPath := WithBackSlash(FExpand(EzCfg^.NetMailPath));
    EzCfg^.NodeListPath := WithBackSlash(FExpand(EzCfg^.NodeListPath));
    EzCfg^.AttachPath := WithBackSlash(FExpand(EzCfg^.AttachPath));
    ChDir(StripTrail(CPath, DirectorySeparator));
    End;
  End;


Function EzRCfgObj.GetQuoteStr: String;
  Begin
  GetQuoteStr := EzCfg^.QuoteStr;
  End;



Function EzRCfgObj.GetMaxMsgAreas: Word; {Get maximum number of msg areas}
  Begin
  GetMaxMsgAreas := MaxMsgAreas;
  End;


Function EzRCfgObj.ValidMsgArea(Area: Word): Word;
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
      Seek(EzMsgFile, FP);
      BlockRead(EzMsgFile, EzMsg^, SizeOf(EzMsg^), NumRead);
      If IoResult <> 0 Then;
{      If LoadFilePos(FindBbsFile('Messages.Mk') + 'Messages.Mk', EzMsg^, SizeOf(EzMsg^),
      FP) = 0 Then;}
      End;
    ValidMsgArea := Area  + 1 - MsgLoaded;
    End
  Else
    ValidMsgArea := 0;
  End;


Function EzRCfgObj.ValidFileArea(Area: Word): Word;
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
      Seek(EzFileFile, FP);
      BlockRead(EzFileFile, EzFile^, SizeOf(EzFile^), NumRead);
      If IoResult <> 0 Then;
{      If LoadFilePos(FindBbsFile('Files.Mk') + 'Files.Mk', EzFile^, SizeOf(EzFile^),
      FP) = 0 Then;}
      End;
    ValidFileArea := Area  + 1 - FileLoaded;
    End
  Else
    ValidFileArea := 0;
  End;


Function EzRCfgObj.GetMsgName(Area: Word): String; {Get message area name}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgName := EzMsg^[MA].Name
  Else
    GetMsgName := '';
  End;


Function EzRCfgObj.GetMsgOrigStr(Area: Word): String;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    If Length(EZMsg^[MA].Origin) > 0 Then
      GetMsgOrigStr := EzMsg^[MA].Origin
    Else
      GetMsgOrigStr := EzCfg^.Origin;
    End
  Else
    GetMsgOrigStr := '';
  End;


Function EzRCfgObj.GetOrigStr(OrigNum: Word): String;
  Begin
  GetOrigStr := EzCfg^.Origin;
  End;


Procedure EzRCfgObj.GetAddr(Aka: Word; Var Addr: AddrType); {Get Bbs Addr or AKA}
  Begin
  If ((Aka > 0) and (Aka < 17)) Then
    Begin
    Addr := EzConst^.Addr[Aka];
    End
  Else
    Begin
    Addr.Zone := 0;
    Addr.Net := 0;
    Addr.Node := 0;
    Addr.Point := 0;
    End;
  End;



Procedure EzRCfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Var
    MAI: Word;

  Begin
  MAI := ValidMsgArea(Area);
  If MAI > 0 Then
    GetAddr(EzMsg^[MAI].Addr, MA)
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function EzRCfgObj.GetMsgAddrStr(Area: Word): String; {Get message address string}
  Var
    Addr: AddrType;

  Begin
  GetMsgAddr(Area, Addr);
  GetMsgAddrStr := AddrStr(Addr);
  End;


Function EzRCfgObj.GetMsgAddrNum(Area: Word): Word;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgAddrNum := EzMsg^[MA].Addr
  Else
    GetMsgAddrNum := 1;
  End;



Function EzRCfgObj.GetMsgOrigNum(Area: Word): Word;
  Var
    MA: Word;

  Begin
  GetMsgOrigNum := 1;
  End;


Function EzRCfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;


Function EzRCfgObj.GetMsgShortName(Area: Word): String; {Get message area short name}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    If Length(EzMsg^[MA].ShortName) > 0 Then
      GetMsgShortName := EzMsg^[MA].ShortName
    Else
      GetMsgShortName := Copy(EzMsg^[MA].Name,1,12)
  Else
    GetMsgShortName := '';
  End;


Function EzRCfgObj.GetMsgType(Area: Word): MailType; {Get type of mail area}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Case EzMsg^[MA].Typ Of
      0: GetMsgType := Normal;
      1: GetMsgType := NetMail;
      2..5: GetMsgType := EchoMail;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Function EzRCfgObj.MsgWriteAccess(Area: Word; Sec: SecType): Boolean; {Has write access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgWriteSecurity(Area, AreaSec);
  MsgWriteAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgWriteAccess := False;
  End;


Function EzRCfgObj.MsgReadAccess(Area: Word; Sec: SecType): Boolean; {Has read access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgReadSecurity(Area, AreaSec);
  MsgReadAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgReadAccess := False;
  End;


Function EzRCfgObj.MsgSysopAccess(Area: Word; Sec: SecType): Boolean; {Has sysop access?}
  Var
    AreaSec: SecType;

  Begin
  GetMsgSysopSecurity(Area, AreaSec);
  MsgSysopAccess := Access(Sec, AreaSec);
  If (Length(GetMsgName(Area)) = 0) Then
    MsgSysopAccess := False;
  End;


Function EzRCfgObj.MsgDeleteAccess(Sec: SecType): Boolean;
  Begin
  MsgDeleteAccess := False;
  End;


Function EzRCfgObj.MsgUnRecvAccess(Sec: SecType): Boolean;
  Begin
  MsgUnRecvAccess := False;
  End;


Function EzRCfgObj.GetMsgDays(Area: Word): Word;  {Number of days to keep messages}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgDays := EzMsg^[MA].DaysKept
  Else
    GetMsgDays := 7;
  End;


Function EzRCfgObj.GetMsgRcvdDays(Area: Word): Word; {Number of days to keep received msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgRcvdDays := EzMsg^[MA].RcvdDays
  Else
    GetMsgRcvdDays := 2;
  End;


Function EzRCfgObj.GetMsgsKept(Area: Word): Word; {Number of msgs to keep in area}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgsKept := EzMsg^[MA].MsgsKept
  Else
    GetMsgsKept := 200;
  End;


Function EzRCfgObj.GetSysopName: String; {Get config name of sysop}
  Begin
  GetSysopName := '';
  End;


Procedure EzRCfgObj.GetMsgReadSecurity(Area: Word; Var Sec: SecType);
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := EzMsg^[MA].ReadSec;
    Sec.Flags := EzMsg^[MA].ReadFlags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure EzRCfgObj.GetMsgWriteSecurity(Area: Word; Var Sec: SecType); {Write security level}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := EzMsg^[MA].WriteSec;
    Sec.Flags := EzMsg^[MA].WriteFlags;
    End
  Else
    Begin
    Sec.Level := 5;
    Sec.Flags := 0;
    End;
  End;


Procedure EzRCfgObj.GetMsgSysopSecurity(Area: Word; Var Sec: SecType); {Sysop security level}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    Sec.Level := EzMsg^[MA].SysopSec;
    Sec.Flags := EzMsg^[MA].SysopFlags;
    End
  Else
    Begin
    Sec.Level := 100;
    Sec.Flags := 0;
    End;
  End;


Function EzRCfgObj.MsgAllowPriv(Area: Word): Boolean; {Area allows priv msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowPriv := (EzMsg^[MA].MsgKinds <> 0)
  Else
    MsgAllowPriv := True;
  End;



Function EzRCfgObj.MsgAllowPubl(Area: Word): Boolean; {Area allows publ msgs}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowPubl := (EzMsg^[MA].MsgKinds <> 1)
  Else
    MsgAllowPubl := True;
  End;


Function EzRCfgObj.MsgAllowReal(Area: Word): Boolean; {Area allows real names}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowReal := (EzMsg^[MA].Attr and 2) = 0
  Else
    MsgAllowReal := True;
  End;


Function EzRCfgObj.MsgAllowHdl(Area: Word): Boolean; {Area allows handles}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowHdl := (EzMsg^[MA].Attr and 6) <> 0
  Else
    MsgAllowHdl := False;
  End;


Function EzRCfgObj.MsgAllowAnon(Area: Word): Boolean; {Area allows anonymous}
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    MsgAllowAnon := (EzMsg^[MA].Attr and 4) <> 0
  Else
    MsgAllowAnon := False;
  End;


Function EzRCfgObj.MsgAddFido(Area: Word): Boolean; {Add Fido style tear/origin}
  Begin
  MsgAddFido := True;
  End;



Function EzRCfgObj.MsgAllowAnsi(Area: Word): Boolean; {Area allows ansi}
  Var
    MA: Word;

  Begin
  MsgAllowAnsi := False;
  End;


Function EzRCfgObj.MsgAllowHiBit(Area: Word): Boolean; {Area allows hi-bit chars}
  Var
    MA: Word;

  Begin
  MsgAllowHiBit := False;
  End;


Function EzRCfgObj.MsgAllowTag(Area: Word): Boolean; {Area allows taglines}
  Var
    MA: Word;

  Begin
  MsgAllowTag := False;
  End;


Function EzRCfgObj.GetMsgReaderTear(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  GetMsgReaderTear := False;
  End;


Function EzRCfgObj.GetMsgReaderOrig(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  GetMsgReaderOrig := False;
  End;


Function EzRCfgObj.GetMsgFAttach(Area: Word): Boolean;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    GetMsgFAttach := (EzMsg^[MA].Attr and 32) <> 0
  Else
    GetMsgFAttach := False;
  End;


Function EzRCfgObj.GetMsgSelect(Area: Word): String;
  Var
    MA: Word;

  Begin
  GetMsgSelect := '';
  End;


Function EzRCfgObj.GetMaxFileAreas: Word; {Get maximum number of file areas}
  Begin
  GetMaxFileAreas := 400;
  End;


Function EzRCfgObj.GetFileAreaName(Area: Word): String; {Get file area name}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    GetFileAreaName := EzFile^[FA].Name
  Else
    GetFileAreaName := '';
  End;


Function EzRCfgObj.GetFileShortName(Area: Word): String; {Get short name for area}
  Var
    FA: Word;

  Begin
  FA := ValidFileArea(Area);
  If FA > 0 Then
    Begin
    GetFileShortName := Copy(GetFileAreaName(Area),1 , 12);
    End
  Else
    GetFileShortName := '';
  End;


Function EzRCfgObj.GetFileSelect(Area: Word): String;
  Var
    FA: Word;

  Begin
  GetFileSelect := '';
  End;



Function EzRCfgObj.GetMinDesc: Byte;
  Begin
  GetMinDesc := EzCfg^.MinDesc;
  End;


Function EzRCfgObj.GetMaxDesc: Byte;
  Begin
  GetMaxDesc := EzCfg^.MaxDesc;
  End;






Function EzRCfgObj.GetDefaultPort: Word; {Get default comm port}
  Begin
  GetDefaultPort := EzCfg^.CommPort;
  End;


Function EzRCfgObj.GetMsgPathNum(Area: Word): Word;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    GetMsgPathNum := 1;
    End
  Else
    GetMsgPathNum := 0;
  End;


Function EzRCfgObj.GetMsgBaseType(Area: Word): Char;
  Var
    MA: Word;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    GetMsgBaseType := 'E';
    End
  Else
    GetMsgBaseType := ' ';
  End;


Function EzRCfgObj.GetMsgAreaId(Area: Word): String;
  Var
    MA: Word;
    TmpStr: String;

  Begin
  MA := ValidMsgArea(Area);
  If MA > 0 Then
    Begin
    GetMsgAreaId := 'E'+ PadLeft(Long2Str(Area),'0',4) + EzCfg^.MsgPath;
    End
  Else
    GetMsgAreaId := '';
  End;


End.
