Unit MKCfgTxt;


{$I MKB.Def}

Interface

Uses MKGlobT, MKFile, MKCfgAbs,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}


Type TxtConfigRecord = Record
  SysopName: String[35];
  BbsPath: String[128];
  NodeListPath: String[128];
  Addr: Array[1..10] of AddrType;
  Origin: Array[1..10] of String[60];
  NodeIdxName: String[13];
  NodeIncName: String[13];
  EchoLog: String[60];
  End;


Type TxtMsgRecord = Record
  Name: String[30];
  AreaId: String[80];
  AddrNum: Byte;
  OrigNum: Byte;
  MailType: Char;
  Allow: Char;
  NoFido: Boolean;
  AreaTag: String[40];
  End;


Const MaxMsgAreas = 400;
Const DTime = 4000;

Type TxtMsgCfgType = Array[1..MaxMsgAreas] of TxtMsgRecord;

Type TxtCfgObj = Object(CfgObj)
  TxtCfg:    ^TxtConfigRecord;
  TxtMsg:    ^TxtMsgCfgType;
  Loaded: Boolean;
  Procedure Load; Virtual; {Loads Bbs config info}
  Procedure Unload; Virtual; {Not normally called direct - unloads config}
  Procedure Allocate; Virtual;{Allocate space for non-loaded config}
  Function  GetNodeListPath: String; Virtual; {Get nodelist path}
  Function  GetBbsPath: String; Virtual; {Get main bbs directory path}
  Procedure GetAddr(Aka: Word; Var Addr: AddrType); Virtual; {Get Bbs Addr or AKA}
  Function  GetMaxMsgAreas: Word; Virtual; {Get maximum number of msg areas}
  Function  GetMsgName(Area: Word): String; Virtual; {Get message area name}
  Function  GetMsgShortName(Area: Word): String; Virtual; {Get message area short name}
  Function  GetMsgType(Area: Word): MailType; Virtual; {Get type of mail area}
  Function  MsgAllowPriv(Area: Word): Boolean; Virtual; {Area allows priv msgs}
  Function  MsgAllowPubl(Area: Word): Boolean; Virtual; {Area allows publ msgs}
  Function  MsgAddFido(Area: Word): Boolean; Virtual; {Add Fido style tear/origin}
  Function  GetMsgOrigStr(Area: Word): String; Virtual; {Get origin string for msg area}
  Procedure GetMsgAddr(Area: Word; Var MA: AddrType); Virtual; {Get message area address}
  Function  GetMsgAddrStr(Area: Word): String; Virtual; {Get message address string}
  Function  GetMsgAddrNum(Area: Word): Word; Virtual; {Get message aka number}
  Function  GetMsgOrigNum(Area: Word): Word; Virtual; {Get message orig number}
  Function  GetDefaultOrigStr(Area: Word): String; Virtual; {Get full origin string w/addr}
    {includes the * Origin and default text and address}
  Function  GetSysopName: String; Virtual; {Get config name of sysop}
  Function  GetMsgBaseType(Area: Word): Char; Virtual; {Get message area base type}
  Function  GetMsgAreaId(Area: Word): String; Virtual; {Get message area id string}
  Procedure ParseStr(Var InStr: String; Var PState: Word; Var MArea: Word); Virtual; {Internal}
  Function  ValidMsgArea(Area: Word): Boolean; Virtual;
  Function  GetNodeIdxName: String; Virtual; {Get nodelist index name}
  Function  GetNodeIncName: String; Virtual; {Get nodelist include name}
  Function  GetEchoLog: String; Virtual;
  Function  GetEchoAreaTag(Area: Word): String; Virtual; {Get area tag name}
  Procedure BadCommand(Var InStr: String);
  Procedure BadMsgCmd(Var InStr: String; MArea: Word);
  End;

Type TxtCfgObjPtr = ^TxtCfgObj;


Implementation


Uses MKString,
{$IFDEF WINDOWS}
  MKWCrt;
{$ELSE}
  {$IFDEF OPRO}
  OpCrt;
  {$ELSE}
  Crt;
  {$ENDIF}
{$ENDIF}


Function ParseAddr(AStr: String; CurrAddr: AddrType; Var DestAddr: AddrType): Boolean;
  Var
    SPos: Word;
    EPos: Word;
    TempStr: String;
    Code: Word;
    BadAddr: Boolean;

  Begin
  BadAddr := False;
  AStr := StripBoth(Upper(AStr), ' ');
  EPos := Length(AStr);
  SPos := Pos(':',AStr) + 1;
  If SPos > 1 Then
    Begin
    TempStr := StripBoth(Copy(AStr,1,Spos - 2), ' ');
    Val(TempStr,DestAddr.Zone,Code);
    If Code <> 0 Then
      BadAddr := True;
    AStr := Copy(AStr,Spos,Length(AStr));
    End
  Else
    DestAddr.Zone := CurrAddr.Zone;
  SPos := Pos('/',AStr) + 1;
  If SPos > 1 Then
    Begin
    TempStr := StripBoth(Copy(AStr,1,Spos - 2), ' ');
    Val(TempStr,DestAddr.Net,Code);
    If Code <> 0 Then
      BadAddr := True;
    AStr := Copy(AStr,Spos,Length(AStr));
    End
  Else
    DestAddr.Net := CurrAddr.Net;
  EPos := Pos('.', AStr) + 1;
  If EPos > 1 Then
    Begin
    TempStr := StripBoth(Copy(AStr,EPos,Length(AStr)), ' ');
    Val(TempStr,DestAddr.Point,Code);
    If Code <> 0 Then
      DestAddr.Point := 0;
    AStr := Copy(AStr,1,EPos -2);
    End
  Else
    DestAddr.Point := 0;
  TempStr := StripBoth(AStr,' ');
  If Length(TempStr) > 0 Then
    Begin
    Val(TempStr,DestAddr.Node,Code);
    If Code <> 0 Then
      BadAddr := True;
    End
  Else
    DestAddr.Node := CurrAddr.Node;
  ParseAddr := Not BadAddr;
  End;


Procedure TxtCfgObj.BadCommand(Var InStr: String);
  Begin
  Write(#7);
  WriteLn('Error in Text Config File');
  WriteLn(InStr);
  WriteLn;
  Delay(DTime);
  Error := 25;
  End;


Procedure TxtCfgObj.BadMsgCmd(Var InStr: String; MArea: Word);
  Begin
  Write(#7);
  WriteLn('Error in Text Config File in Msg Area ' + Long2Str(MArea));
  WriteLn(InStr);
  WriteLn;
  Delay(DTime);
  Error := 35;
  End;


Procedure TxtCfgObj.ParseStr(Var InStr: String; Var PState: Word; Var MArea: Word);
  Var
    WCount: Word;
    Cmd: String[40];
    TmpStr: String;
    TWord: Word;
    TAddr: AddrType;

  Begin
  WCount := WordCount(InStr);
  If WordCount(InStr) > 0 Then
    Begin
    Cmd := Upper(ExtractWord(InStr, 1));
    Case PState Of
      0: Begin {Normal}
         Case Cmd[1] of
           'A': Begin
                If Cmd = 'ADDR' Then
                  Begin
                  If WCount > 2 Then
                    Begin
                    TWord := Str2Long(ExtractWord(InStr, 2));
                    If ((TWord > 0) and (TWord < 11)) Then
                      Begin
                      TAddr.Zone := 1;
                      TAddr.Net := 0;
                      TAddr.Node := 0;
                      TAddr.Point := 0;
                      If ParseAddr(ExtractWord(InStr, 3), TAddr, TAddr) Then
                        TxtCfg^.Addr[TWord] := TAddr;
                      End
                    End;
                  End
                Else
                  BadCommand(InStr);
                End;
           'B': Begin
                If Cmd = 'BBSPATH' Then
                  Begin
                  TxtCfg^.BbsPath := StripBoth(Copy(InStr,9,150), ' ');
                  End
                Else
                  BadCommand(InStr);
                End;
           'E': Begin
                If Cmd = 'ECHOLOG' Then
                  Begin
                  TxtCfg^.EchoLog := StripBoth(Copy(InStr,9,60), ' ');
                  End
                Else
                  BadCommand(InStr);
                End;
           'O': Begin
                If Cmd = 'ORIGIN' Then
                  Begin
                  If WCount > 2 Then
                    Begin
                    TWord := Str2Long(ExtractWord(InStr, 2));
                    If ((TWord > 0) and (TWord < 11)) Then
                      Begin
                      TmpStr := StripBoth(Copy(InStr,8,128), ' ');
                      TmpStr := Copy(TmpStr, Pos(' ', TmpStr) + 1, 128);
                      TmpStr := StripBoth(TmpStr, ' ');
                      TxtCfg^.Origin[TWord] := TmpStr;
                      End;
                    End;
                  End
                Else
                  BadCommand(InStr);
                End;
           'M': Begin
                If Cmd = 'MSGAREA' Then
                  Begin
                  If WCount > 1 Then
                    Begin
                    TWord := Str2Long(ExtractWord(InStr, 2));
                    If ((TWord > 0) and (TWord < MaxMsgAreas)) Then
                      Begin
                      MArea := TWord;
                      TxtMsg^[MArea].AddrNum := 1;
                      TxtMsg^[MArea].OrigNum := 1;
                      TxtMsg^[MArea].NoFido := False;
                      PState := 1;
                      End;
                    End;
                  End
                Else
                  BadCommand(InStr);
                End;
           'N': Begin
                If Cmd = 'NODELISTPATH' Then
                  Begin
                  TxtCfg^.NodeListPath := WithBackSlash(StripBoth(Copy(InStr,14, 150),' '));
                  End
                Else If Cmd = 'NODEIDX' Then
                  TxtCfg^.NodeIdxName := ExtractWord(InStr,2)
                Else If Cmd = 'NODEINC' Then
                  TxtCfg^.NodeIncName := ExtractWord(InStr,2)
                Else
                  BadCommand(InStr);
                End;
           'S': Begin
                If Cmd = 'SYSOP' Then
                  Begin
                  TxtCfg^.SysopName := StripBoth(Copy(InStr,7,80), ' ');
                  End;
                End;
           Else
             BadCommand(InStr);
           End;
         End;
      1: Begin {Msg Area}
         Case Cmd[1] of
           'A': Begin
                If Cmd = 'AREAID' Then
                  Begin
                  TxtMsg^[MArea].AreaId := StripBoth(Copy(InStr, 8, 150), ' ');
                  End
                Else If Cmd = 'ALLOW' Then
                  Begin
                  If WCount > 1 Then
                    Begin
                    TmpStr := Copy(Upper(ExtractWord(InStr, 2)),1,4);
                    If TmpStr = 'BOTH' Then
                      TxtMsg^[MArea].Allow := 'B'
                    Else If TmpSTr = 'PUBL' Then
                      TxtMsg^[MArea].Allow := 'U'
                    Else If TmpStr = 'PRIV' Then
                      TxtMsg^[MArea].Allow := 'V';
                    End;
                  End
                Else If Cmd = 'AREATAG' Then
                  Begin
                  TxtMsg^[MArea].AreaTag := StripBoth(Copy(InStr,9,40),' ');
                  End
                Else
                  BadMsgCmd(InStr, MArea);
                End;
           'U': Begin
                If Cmd = 'USEORIG' Then
                  Begin
                  TWord := Str2Long(ExtractWord(InStr, 2));
                  If ((TWord > 0) and (TWord < 11)) Then
                    TxtMsg^[MArea].OrigNum := TWord;
                  End
                Else If Cmd = 'USEADDR' Then
                  Begin
                  TWord := Str2Long(ExtractWord(InStr, 2));
                  If ((TWord > 0) and (TWord < 11)) Then
                    TxtMsg^[MArea].AddrNum := TWord;
                  End
                Else
                  BadMsgCmd(InStr, MArea);
                End;
           'M': Begin
                If Cmd = 'MAILTYPE' Then
                  Begin
                  If WCount > 1 Then
                    Begin
                    TmpStr := Copy(Upper(ExtractWord(InStr, 2)),1,3);
                    TxtMsg^[MArea].MailType := TmpStr[1];
                    End;
                  End
                Else
                  BadMsgCmd(InStr, MArea);

                End;
           'N': Begin
                If Cmd = 'NAME' Then
                  Begin
                  TxtMsg^[MArea].Name := StripBoth(Copy(InStr, 6, 80), ' ');
                  End
                Else If Cmd = 'NOFIDO' Then
                  Begin
                  TxtMsg^[MArea].NoFido := True;
                  End
                Else
                  BadMsgCmd(InStr, MArea);
                End;
           'E': Begin
                If Cmd = 'ENDAREA' Then
                  Begin
                  PState := 0;
                  End
                Else
                  BadMsgCmd(InStr, MArea);
                End;
           Else
             BadMsgCmd(InStr, MArea);
           End;
         End;
      End;
    End;
  End;


Procedure TxtCfgObj.Load;
  Var
    TF: TFile;
    TmpStr: String;
    PState: Word;  {0=normal, 1=msg area}
    CMsgArea: Word;
    FName: String;

  Begin
  Error := 0;
  New(TxtCfg);
  New(TxtMsg);
  If (TxtCfg=Nil) or (TxtMsg=Nil) Then
    Begin
    Error := 100;
    If TxtCfg <> Nil Then
      Dispose(TxtCfg);
    If TxtMsg <> Nil Then
      Dispose(TxtMsg);
    Exit;
    End;
  FillChar(TxtCfg^, SizeOf(TxtCfg^), 0);
  FillChar(TxtMsg^, SizeOf(TxtMsg^), 0);
  TmpStr := '';
  PState := 0;
  CMsgArea := 0;
  FName := GetEnv('MKR');
  If Length(FName) = 0 Then
    Error := 10
  Else
    Begin
    If Not FileExist(FName) Then
      Error := 20;
    End;
  If Error = 0 Then
    Begin
    TF.Init;
    If Not TF.OpenTextFile(FName) Then
      Error := 30;
    TmpStr := StripBoth(TF.GetString, ' ');
    While TF.StringFound Do
      Begin
      If ((TmpStr[1] <> ';') and (Length(TmpStr) > 0)) Then
        ParseStr(TmpStr, PState, CMsgArea);
      TmpStr := StripBoth(TF.GetString, ' ');
      End;
    If Not TF.CloseTextFile Then;
    TF.Done;
    End;
  If Error = 0 Then
    Loaded := True
  Else
    Begin
    Dispose(TxtCfg);
    Dispose(TxtMsg);
    End;
  End;


Procedure TxtCfgObj.Allocate;
  Begin
  New(TxtCfg);
  New(TxtMsg);
  FillChar(TxtCfg^, SizeOf(TxtCfg^), 0);
  FillChar(TxtMsg^, SizeOf(TxtMsg^), 0);
  Loaded := True;
  End;


Procedure TxtCfgObj.Unload;
  Begin
  If Loaded Then
    Begin
    Dispose(TxtCfg);
    Dispose(TxtMsg);
    Loaded := False;
    End;
  End;


Function  TxtCfgObj.GetNodeListPath: String;
  Begin
  GetNodeListPath := WithBackSlash(TxtCfg^.NodeListPath);
  End;


Function  TxtCfgObj.GetBbsPath: String;
  Begin
  GetBbsPath := WithBackSlash(TxtCfg^.BbsPath);
  End;


Procedure TxtCfgObj.GetAddr(Aka: Word; Var Addr: AddrType);
  Begin
  If ((Aka > 0) and (Aka < 11)) Then
    Addr := TxtCfg^.Addr[Aka];
  End;


Function  TxtCfgObj.GetMaxMsgAreas: Word;
  Begin
  GetMaxMsgAreas := MaxMsgAreas;
  End;


Function  TxtCfgObj.ValidMsgArea(Area: Word): Boolean;
  Begin
  If ((Area > 0) and (Area <= MaxMsgAreas)) Then
    ValidMsgArea := (Length(TxtMsg^[Area].Name) > 0)
  Else
    ValidMsgArea := False;
  End;


Function  TxtCfgObj.GetMsgName(Area: Word): String;
  Begin
  If ValidMsgArea(Area) Then
    GetMsgName := TxtMsg^[Area].Name
  Else
    GetMsgName := '';
  End;


Function  TxtCfgObj.GetMsgShortName(Area: Word): String;
  Begin
  If ValidMsgArea(Area) Then
    GetMsgShortName := Copy(GetMsgName(Area),1,12)
  Else
    GetMsgShortName := '';
  End;


Function  TxtCfgObj.GetMsgType(Area: Word): MailType;
  Begin
  If ValidMsgArea(Area) Then
    Begin
    Case TxtMsg^[Area].MailType of
      'L': GetMsgType := Normal;
      'N': GetMsgType := NetMail;
      'E': GetMsgType := EchoMail;
      Else
        GetMsgType := Normal;
      End;
    End
  Else
    GetMsgType := Normal;
  End;


Function  TxtCfgObj.MsgAllowPriv(Area: Word): Boolean;
  Begin
  If ValidMsgArea(Area) Then
    Begin
    MsgAllowPriv := ((TxtMsg^[Area].Allow = 'B') Or (TxtMsg^[Area].Allow = 'V'));
    End
  Else
    MsgAllowPriv := False;
  End;


Function  TxtCfgObj.MsgAllowPubl(Area: Word): Boolean;
  Begin
  If ValidMsgArea(Area) Then
    Begin
    MsgAllowPubl := ((TxtMsg^[Area].Allow = 'B') Or (TxtMsg^[Area].Allow = 'U'));
    End
  Else
    MsgAllowPubl := False;
  End;


Function  TxtCfgObj.MsgAddFido(Area: Word): Boolean;
  Begin
  If ValidMsgArea(Area) Then
    MsgAddFido := Not TxtMsg^[Area].NoFido
  Else
    MsgAddFido := True;
  End;


Function  TxtCfgObj.GetMsgOrigStr(Area: Word): String;
  Begin
  If ValidMsgArea(Area) Then
    GetMsgOrigStr := TxtCfg^.Origin[TxtMsg^[Area].OrigNum]
  Else
    GetMsgOrigStr := '';
  End;


Procedure TxtCfgObj.GetMsgAddr(Area: Word; Var MA: AddrType);
  Begin
  If ValidMsgArea(Area) Then
    MA := TxtCfg^.Addr[TxtMsg^[Area].AddrNum]
  Else
    Begin
    MA.Zone := 0;
    MA.Net := 0;
    MA.Node := 0;
    MA.Point := 0;
    End;
  End;


Function  TxtCfgObj.GetMsgAddrStr(Area: Word): String;
  Var
    TAddr: AddrType;

  Begin
  GetMsgAddr(Area, TAddr);
  GetMsgAddrStr := AddrStr(TAddr);
  End;


Function  TxtCfgObj.GetMsgAddrNum(Area: Word): Word;
  Begin
  If ValidMsgArea(Area) Then
    GetMsgAddrNum := TxtMsg^[Area].AddrNum
  Else
    GetMsgAddrNum := 1;
  End;


Function  TxtCfgObj.GetMsgOrigNum(Area: Word): Word;
  Begin
  If ValidMsgArea(Area) Then
    GetMsgOrigNum := TxtMsg^[Area].OrigNum
  Else
    GetMsgOrigNum := 1;
  End;



Function  TxtCfgObj.GetDefaultOrigStr(Area: Word): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := ' (' + GetMsgAddrStr(Area) + ')';
  TmpStr := ' * Origin: ' + Copy(GetMsgOrigStr(Area), 1, (67 - Length(TmpStr)))
    + TmpStr;
  GetDefaultOrigStr := TmpStr;
  End;




Function  TxtCfgObj.GetSysopName: String;
  Begin
  GetSysopName := TxtCfg^.SysopName;
  End;


Function  TxtCfgObj.GetMsgBaseType(Area: Word): Char;
  Begin
  If ValidMsgArea(Area) Then
    GetMsgBaseType := TxtMsg^[Area].AreaId[1]
  Else
    GetMsgBaseType := ' ';
  End;


Function  TxtCfgObj.GetMsgAreaId(Area: Word): String;
  Begin
  If ValidMsgArea(Area) Then
    GetMsgAreaId := TxtMsg^[Area].AreaId
  Else
    GetMsgAreaId := '';
  End;


Function TxtCfgObj.GetNodeIdxName: String;
  Begin
  GetNodeIdxName := TxtCfg^.NodeIdxName;
  End;


Function TxtCfgObj.GetNodeIncName: String;
  Begin
  GetNodeIncName := TxtCfg^.NodeIncName;
  End;


Function TxtCfgObj.GetEchoLog: String;
  Begin
  GetEchoLog := TxtCfg^.EchoLog;
  End;


Function TxtCfgObj.GetEchoAreaTag(Area: Word): String;
  Begin
  If ValidMsgArea(Area) Then
    GetEchoAreaTag := TxtMsg^[Area].AreaTag
  Else
    GetEchoAreaTag := '';
  End;


End.
