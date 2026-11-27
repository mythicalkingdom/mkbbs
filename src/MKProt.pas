Unit MKProt;

{$I-}
{$I MKB.Def}

INTERFACE

Const
  MaxFiles = 100;
  ZBufSize = 1024;
  MaxCErrors = 15;


Type ProtCancelProc = Function: Boolean;

Var
  ProtCancelHook: ProtCancelProc;      {a program that reads its own keyboard (mkconnect): True cancels the transfer}
  ProtKeepInput: Boolean;              {a transfer with a BBS (this program is the caller): what follows the end of the transfer (the BBS prompt) is not thrown away}
  ProtTrace: Boolean;                  {every byte received (r) and sent (s) goes to StdErr (tests)}


Type BufType = Array[0..zBufSize] of Byte;

Type ZHdrType = Array[0..3] of Byte;

Type DataBlkType = Array[1..8096] of Byte;

Type ProtInfo = Record
  Ch: Char;
  CRCType: Word;
  BlkSize: Word;
  GProt: Boolean;
  SendHdr: Boolean;
  Prot: Char;             {X=XmodemCrc C=XmodemChksum O=1kXmodem
                           Y=Ymodem    G=YmodemG      Z=Zmodem
                           8=ZedZap    Q=1kXmodemG}
  DataBlk: DataBlkType;
  FN: Array[1..MaxFiles] of String[128];
  Status: Array[1..MaxFiles] of Byte;  {1=success 0=not sent}
  NumFiles: Word;
  CrcValue: Word;
  BlockNum: LongInt;
  PFile: File;
  CurrFile: Word;
  StartTime: LongInt;
  FPos: LongInt;
  Error: Word;
  SendState: Word;
  TxHdr: ZHdrType;
  RxHdr: ZHdrType;
  Abort: Boolean;
  RxName: String[100];    {Xmodem receive: the name of the file (Xmodem sends none)}
  RxBlkNum: Integer;     {receive: the block that RX_GetBlock read}
  RxBlkLen: Word;
  End;


Type ProtObj = Object
  PI: ^ProtInfo;
  Procedure Init;
  Procedure Done;
  Function  CancelKey: Boolean;
  Procedure AddSendFile(FN: String);
  Function  GetFileStatus(FN: Word): Byte;
  Function  StripPath(FN: String): String;
  Procedure SetYModem;
  Procedure SetYModemG;
  Procedure SetXmodem;
  Procedure SetXmodemC;
  Procedure SetX1K;
  Procedure SetXmodemG;
  Procedure SetZmodem;
  Procedure SetSealink;
  Procedure Send;
  Procedure WaitSend;
  Procedure GetNextSendFile;
  Procedure SendHeader;
  Procedure SendEOT;
  Procedure SendBatchEnd;
  Procedure SendData(BSize: Word);
  Procedure SendBlock;
  Function  Recv(Path: String): Boolean;
  Procedure SetRecvName(Name: String);
  Function  RX_GetBlock: Integer;
  Function  RX_Receive(Path: String; Batch: Boolean): Boolean;
  Procedure ShowLoc(ZPos: LongInt);
  Procedure Z_PutLongIntoHeader(l: LongInt);
  Procedure RZ_AckBibi;
  Function  RZ_InitReceiver: Integer;
  Function  Z_GetHeader(Var Hdr: ZHdrType): Integer;
  Function  RZ_GetHeader: Integer;
  Function  RZ_SaveToDisk(Var rxBytes: LongInt): Integer;
  Function  RZ_ReceiveFile: Integer;
  Function  RZ_ReceiveBatch: Integer;
  Function  Zmodem_Receive(path: String): Boolean;
  Function  SZ_GetReceiverInfo: Integer;
  Procedure SZ_EndSend;
  Function  SZ_SyncWithReceiver: Integer;
  Function  SZ_SendFileData: Integer;
  Function  SZ_SendFile: Integer;
  Procedure ZStartSend;
  Procedure ZOneFile;
  End;


Implementation

Uses Dos,
  MKVCrt,
MKVideo, MKMisc, Crc16, Crc32, MKComAbs, MKString, MKFile, MKDos, MKPlat;


Const
  Crc32Good = -558161693;                {$DEBB20E3: what the CRC 32 of a block is with its own CRC added (a signed LongInt in FPC)}


Const
  MKVer = 'MK Transfer Protocols';

Const
  AllowResume: Boolean = True;
  MakeCRC32: Boolean = True;


Const
  ZPAD = 42;     { '*' }
  ZDLE = 24;     { ^X  }
  ZDLEE = 88;
  ZBIN = 65;     { 'A' }
  ZHEX = 66;     { 'B' }
  ZBIN32 = 67;   { 'C' }
  ZRQINIT = 0;
  ZRINIT = 1;
  ZSINIT = 2;
  ZACK = 3;
  ZFILE = 4;
  ZSKIP = 5;
  ZNAK = 6;
  ZABORT = 7;
  ZFIN = 8;
  ZRPOS = 9;
  ZDATA = 10;
  ZEOF = 11;
  ZFERR = 12;
  ZCRC = 13;
  ZCHALLENGE = 14;
  ZCOMPL = 15;
  ZCAN = 16;
  ZFREECNT = 17;
  ZCOMMAnd = 18;
  ZCRCE = 104; { 'h' }
  ZCRCG = 105; { 'i' }
  ZCRCQ = 106; { 'j' }
  ZCRCW = 107; { 'k' }
  ZRUB0 = 108; { 'l' }
  ZRUB1 = 109; { 'm' }
  ZOK = 0;
  ZERROR = -1;
  ZTIMEOUT = -2;             {Timeout}
  RCDO = -3;                 {Lost carrier}
  GOTOR = 256;
  GOTCRCE = 360; { 'h' OR 256 }
  GOTCRCG = 361; { 'i' "   "  }
  GOTCRCQ = 362; { 'j' "   "  }
  GOTCRCW = 363; { 'k' "   "  }
  GOTCAN = 272;  { CAN OR  "  }



{ xmodem paramaters }
Const
  CAN = 24;
  XOFF = 19;
  XON = 17;


{ Byte positions }
Const
  ZF0 = 3;
  ZF1 = 2;
  ZF2 = 1;
  ZF3 = 0;
  ZP0 = 0;
  ZP1 = 1;
  ZP2 = 2;
  ZP3 = 3;


{ bit masks for ZRINIT }
Const
  CANFDX =   1;    { can hAndle full-duplex          (yes for PC's)}
  CANOVIO =  2;    { can overlay disk And serial I/O (ditto)       }
  CANBRK =   4;    { can Send a break - True but superfluous       }
  CANCRY =   8;    { can encrypt/decrypt - not defined yet         }
  CANLZW =  16;    { can LZ compress - not defined yet             }
  CANFC32 = 32;    { can use 32 bit crc frame checks - True        }
  ESCALL =  64;    { escapes all control chars. NOT implemented    }
  ESC8 =   128;    { escapes the 8th bit. NOT implemented          }


{ bit masks for ZSINIT }
Const
  TESCCTL = 64;
  TESC8 = 128;


{ paramaters for ZFILE }
Const
  { ZF0 }
  ZCRESUM = 3;

Var
  RxPos: LongInt; {file position received from Z_GetHeader}
  rxtimeout,
  rxtype,
  rxframeind: Integer;
  attn: buftype;
  secbuf: buftype;
  fname: String;
  fmode: Integer;
  ftime,
  fsize: LongInt;
  usecrc32: Boolean;
  zcps, zerrors: Word;
  txpos: LongInt;
  PWdw: ProtocolWindowObj;


Const
  LastSent: Byte = 0;
  TxTimeOut = 10 * 18;



Procedure Z_FlushOutbound;
  Begin
  CommFlushOut;
  End;


Procedure Z_SendBreak;
(* Send a break signal *)
  Begin
  CommStartBreak;                        {no-op on a session}
  Delay(100);
  CommStopBreak;
  End;


Var
  TraceLast: Int64;

Procedure TraceTime;
  {the debug trace: the time (ms) when there has been a pause}
  Var
    T: Int64;

  Begin
  T := MKTicks;
  If T - TraceLast > 150 Then
    Begin
    Write(StdErr, ' @', T Mod 1000000);
    TraceLast := T;
    End
  Else
    TraceLast := T;
  End;


Procedure Z_SendByte(b: Byte);
(* Output one Byte *)            {check for timeout}
  Var
    Time: LongInt;

  Begin
  Time := TimeCounter + TxTimeOut;
  While ((Not CommSendNw(Chr(b))) And (Not TimeOut(Time))) Do;
  If ProtTrace Then
    Begin
    TraceTime;
    Write(StdErr, ' s', b);
    Flush(StdErr);
    End;
  End;



Function Z_AsyncOn(ZPort: Word; ZBaud: LongInt): Boolean;
  {the session of the caller is open already; there has to be one}
  Begin
  Z_AsyncOn := CommActive;
  End;



Function ProtObj.CancelKey: Boolean;
  {the local keyboard is not read: on a session it is the caller's own line.  A caller who is gone ends the
   transfer through the carrier.}
  Begin
  CancelKey := False;
  If @ProtCancelHook <> Nil Then
    CancelKey := ProtCancelHook();
  End;


Procedure ProtObj.ShowLoc(ZPos: LongInt);
  Var
    ETime: LongInt;

  Begin
  PWdw.ShowLoc(ZPos);
  ETime := ((TimeCounter - PI^.StartTime) * 10) Div 182;
  If ETime < 0 Then
    Inc(ETime, 86400);
  PWdw.ShowElapsed(ETime);
  If ETime > 0 Then
    PWdw.ShowCps(ZPos Div ETime);
  End;


Function Z_FileCRC32(Var f: File): LongInt;
  Var
    FBuf: Array[0..ZBufSize] of Byte;
    crc: LongInt;
    BRead: Integer;
    n: Integer;

  Begin
  crc := -1;
  Seek(f,0);
  If (IOresult <> 0) Then;
  Repeat
    BlockRead(f, fbuf, ZBufSize, bread);
    For n := 0 TO (bread - 1) Do
      crc := UpdC32(fbuf[n],crc)
  Until ((BRead < ZBufSize) Or (IOresult <> 0));
  Seek(f,0);
  IF (IOresult <> 0) Then;
  Z_FileCRC32 := Crc;
  End;


Function Z_GetByte(tenths: Integer): Integer;
(* Reads a Byte from the modem - Returns RCDO if *)
(* no carrier, or ZTIMEOUT if nothing received   *)
(* within 'tenths' clockticks.                   *)
  Var
    Done: Boolean;
    Time: LongInt;
    Bv: Integer;


  Begin
  Done := False;
  Time := TimeCounter + Tenths;
  While Not Done Do
    Begin
    If Not CommInEmpty Then
      Begin
      Bv := Ord(CommRecv);
      z_GetByte := Bv;
      If ProtTrace Then
        Begin
        TraceTime;
        Write(StdErr, ' r', Bv);
        Flush(StdErr);
        End;
      Done := True;
      End
    Else If Not CommCarrier Then
      Begin
      Z_GetByte := RCDO; { nobody to talk to }
      Done := True;
      End
    Else If TimeOut(Time) Then
      Begin
      Z_GetByte := ZTimeOut;
      If ProtTrace Then
        Begin
        Write(StdErr, ' T');
        Flush(StdErr);
        End;
      Done := True;
      End
    Else
      Begin
      If CommWaitChar(50) Then;          {waits, not a busy loop}
      If @ProtCancelHook <> Nil Then
        If ProtCancelHook() Then
          Begin
          Z_GetByte := ZTimeOut;         {the operator cancels: the waiting ends at once, the caller of the transfer sees the cancel}
          Done := True;
          End;
      End;
    End;
  End;


Function Z_qk_read: Integer;
(* Just like Z_GetByte, but timeout value is in *)
(* global Var rxtimeout.                        *)
  Begin
  Z_qk_read := Z_GetByte(RxTimeOut)
  End;


Function Z_TimedRead: Integer;
(* ignores XON/XOFF characters.        *)
  Var
    done: Boolean;
    c: Integer;
    time: LongInt;

  Begin
  Time := TimeCounter + RxTimeOut;
  Done := False;
  While Not Done Do
    Begin
    C := Z_qk_read;
    If ((C <> Xon) And (C <> Xoff)) Then
      Begin
      Done := True;
      Z_TimedRead := c;
      End;
    If TimeOut(time) Then
      Begin
      Z_TimedRead := ZTimeOut;
      Done := True;
      End;
    If Not CommCarrier Then
      Begin
      Z_TimedRead := RCDO;
      Done := True;
      End;
    End;
  End;


Procedure Z_SendCan;
(* Send a zmodem CANcel sequence to the other guy *)
(* 8 CANs And 8 backspaces                        *)
  Var
    n: Byte;

  Begin
  CommFlushOut;
  FOR n := 1 To 8 DO
    Begin
    Z_SendByte(CAN);
    Delay(100)     { the pause seems to make reception of the sequence }
    End;              { more reliable                                     }
  FOR n := 1 TO 10 DO
    Z_SendByte(8)
  End;


Procedure Z_PutString(Var P: BufType);
(* Outputs an ASCII-Z type String (null terminated) *)
(* Processes meta characters 221 (Send break) And   *)
(* 222 (2 second delay).                            *)
  Var
    n: Word;

  Begin
  n := 0;
  While (n < ZBufSize) And (p[n] <> 0) Do
    Begin
    Case p[n] Of
      221 : Z_SendBreak;
      222 : Delay(2000)
      ELSE
        Z_SendByte(p[n])
      End;
    Inc(n)
    End
  End;


Procedure Z_PutHex(b: Byte);
(* Output a Byte as two hex digits (in ASCII) *)
(* Uses lower case to avoid confusion with    *)
(* escaped control characters.                *)
  CONST
     hex: ARRAY[0..15] OF CHAR = '0123456789abcdef';

  Begin
  Z_SendByte(Ord(hex[b shr 4]));  { high nybble }
  Z_SendByte(Ord(hex[b and $0F])) { low nybble  }
  End;


Procedure Z_SendHexHeader(HType: Byte; Var Hdr: ZHdrType);
(* Sends a zmodem hex type header *)
  Var
    crc: Word;
    n, i: Integer;

  Begin
  Z_SendByte(ZPAD);                  { '*' }
  Z_SendByte(ZPAD);                  { '*' }
  Z_SendByte(ZDLE);                  { 24  }
  Z_SendByte(ZHEX);                  { 'B' }
  Z_PutHex(htype);
  crc := UpdCrc(htype,0);
  For n := 0 To 3 Do
    Begin
    Z_PutHex(hdr[n]);
    crc := UpdCrc(hdr[n],crc)
    End;
  crc := UpdCrc(0,crc);
  crc := UpdCrc(0,crc);
  Z_PutHex(Lo(crc shr 8));
  Z_PutHex(Lo(crc));
  Z_SendByte(13);                    { make it readable to the other End }
  Z_SendByte(10);                    { just in case                      }
  If (htype <> ZFIN) And (htype <> ZACK) Then
     Z_SendByte(17);                 { Prophylactic XON to assure flow   }
  If (NOT CommCarrier) Then
    CommFlushOut;
  End;


Function Z_PullLongFromHeader(Var Hdr: ZHdrType): LongInt;
(* Stuffs a LongInt into a header Variable - N.B. - Bytes are REVERSED! *)

  Type
    LongArray = Array[0..3] of Byte;

  Var
    L: LongInt;
    LongPtr : LongArray Absolute L;

  Begin
  LongPtr[0] := Hdr[ZP0];
  LongPtr[1] := Hdr[ZP1];
  LongPtr[2] := Hdr[ZP2];
  LongPtr[3] := Hdr[ZP3];
  Z_PullLongFromHeader := L;
  End;


Procedure ProtObj.Z_PutLongIntoHeader(l: LongInt);
  Type
    LongArray = Array[0..3] of Byte;

  Var
    LongPtr: LongArray Absolute L;

  Begin
  PI^.TxHdr[ZP0] := LongPtr[0];
  PI^.TxHdr[ZP1] := LongPtr[1];
  PI^.TxHdr[ZP2] := LongPtr[2];
  PI^.TxHdr[ZP3] := LongPtr[3];
  End;



Function Z_GetZDL: Integer;
(* Gets a Byte And processes for ZMODEM escaping or CANcel sequence *)
  Var
    c: Integer;
    d: Integer;
    CancelCount: Word;

  Begin
  If (Not CommCarrier) Then
    Z_GetZDL := RCDO
  Else
    Begin
    c := Z_qk_read;
    If (c <> ZDLE) Then
      Z_GetZDL := c
    Else
      Begin
      CancelCount := 1;
      While ((CancelCount < 5) and (c = CAN)) Do
        Begin
        c := Z_qk_read;
        Inc(CancelCount);
        End;
      { Flags set in high Byte }
      Case c Of
        CAN: Z_GetZDL := GOTCAN; {got 5th CAN}
        ZCRCE, ZCRCG, ZCRCQ, ZCRCW: Z_GetZDL := (c or GOTOR); {Frame end}
        ZRUB0: Z_GetZDL := $007F;                   {got an ASCII DELete}
        ZRUB1: Z_GetZDL := $00FF;                            {any parity}
        -32000..-1: Z_GetZdl := c;
        Else
          If ((c And $60) = $40) Then  {make sure it was a valid escape}
            Z_GetZDL := c XOR $40
          Else
            Z_GetZDL := ZERROR;
        End;
      End;
    End;
  End;


Function Z_GetHex: Integer;
(* Get a Byte that has been received as two ASCII hex digits *)
  Var
    c: Array[1..2] Of Integer;
    n: Integer;
    Finished: Boolean;         {Finished early for problem}

  Begin
  N := 1;
  Finished := False;
  While ((N < 3) and (Not Finished)) Do
    Begin
    c[n] := Z_TimedRead;
    If (c[n] < 0) Then
      Begin
      Z_GetHex := c[n];
      Finished := True;
      End
    Else
      Begin
      c[n] := c[n] - $30;
      If (c[n] > 9) Then
        c[n] := c[n] - 39;
      If (c[n] And $FFF0 <> 0) Then
        Begin
        Z_GetHex := ZERROR;
        Finished := True;
        End;
      End;
    Inc(n);
    End;
  If Not Finished Then
    Z_GetHex := ( C[1] shl 4) or C[2];
  End;


Function Z_GetHexHeader(Var Hdr: ZHdrType): Integer;
(* Receives a zmodem hex type header *)
  Var
    crc: Word;
    c: Integer;
    State: Integer;
    ExitEarly: Boolean;

  Begin
  ExitEarly := False;
  State := 1;
  While (Not ExitEarly) and (State < 8) Do
    Begin
    c := Z_GetHex;
    If (c < 0) Then
      Begin
      Z_GetHexHeader := c;
      ExitEarly := True;
      End;
    If Not ExitEarly Then
      Begin
      Case State of
        1: Begin                      {get type}
           RxType := c;
           Crc := UpdCrc(RxType, 0);
           End;
        2..5: Begin                   {get 4 data values}
           Hdr[State - 2] := Lo(c);
           Crc := UpdCrc(Lo(c), Crc);
           End;
        6..7: Begin                   {get 2 crc values}
           Crc := UpdCrc(Lo(c), Crc);
           End;
        End;
      End;
    Inc(State);
    End;
  If ((Not ExitEarly) and (crc <> 0)) Then   {check CRC}
    Begin
    Inc(zerrors);
    PWdw.Errors(zerrors);
    PWdw.Message('Crc Error H');
    Z_GetHexHeader := ZERROR;
    ExitEarly := True;
    End;
  If ((Not ExitEarly) and (Z_GetByte(1) = 13)) Then  {throw away CR/LF}
    Begin
    c := Z_GetByte(1);
    Z_GetHexHeader := rxtype;
    End;
  End;


Function Z_GetBinaryHeader(Var Hdr: ZHdrType): Integer;
(* Same as above, but binary with 16 bit CRC *)
  Var
    crc: Word;
    c: Integer;
    State: Word;
    ExitEarly: Boolean;

  Begin
  State := 1;
  ExitEarly := False;
  While (Not ExitEarly) and (State < 8) Do
    Begin
    c := Z_GetZDL;
    If (c < 0) Then
      Begin
      Z_GetBinaryHeader := c;
      ExitEarly := True;
      End;
    If Not ExitEarly Then
      Begin
      Case State of
        1: Begin                      {get type}
           RxType := c;
           Crc := UpdCrc(RxType, 0);
           End;
        2..5: Begin                   {get 4 data values}
           Hdr[State - 2] := Lo(c);
           Crc := UpdCrc(Lo(c), Crc);
           End;
        6..7: Begin                   {get 2 crc values}
           Crc := UpdCrc(Lo(c), Crc);
           End;
        End;
      End;
    Inc(State);
    End;
  If ((Not ExitEarly) and (crc <> 0)) Then   {check CRC}
    Begin
    Inc(zerrors);
    PWdw.Errors(zerrors);
    PWdw.Message('Crc Error B');
    Z_GetBinaryHeader := ZERROR;
    ExitEarly := True;
    End;
  If Not ExitEarly Then                    {a binary header has nothing after its CRC (the CR LF is for hex headers)}
    Z_GetBinaryHeader := RxType;
  End;


Function Z_GetBinaryHead32(Var Hdr: ZHdrType): Integer;
  Var
    crc: LongInt;
    c: Integer;
    State: Word;
    ExitEarly: Boolean;

  Begin
  State := 1;
  ExitEarly := False;
  While (Not ExitEarly) and (State < 10) Do
    Begin
    c := Z_GetZDL;
    If (c < 0) Then
      Begin
      Z_GetBinaryHead32 := c;
      ExitEarly := True;
      End;
    If Not ExitEarly Then
      Begin
      Case State of
        1: Begin                      {get type}
           RxType := c;
           Crc := UpdC32(RxType, -1);
           End;
        2..5: Begin                   {get 4 data values}
           Hdr[State - 2] := Lo(c);
           Crc := UpdC32(Lo(c), Crc);
           End;
        6..9: Begin                   {get 2 crc values}
           Crc := UpdC32(Lo(c), Crc);
           End;
        End;
      End;
    Inc(State);
    End;
  If ((Not ExitEarly) and (crc <> Crc32Good)) Then   {check CRC}
    Begin
    Inc(zerrors);
    PWdw.Errors(zerrors);
    PWdw.Message('Crc Error B32');
    Z_GetBinaryHead32 := ZERROR;
    ExitEarly := True;
    End;
  If Not ExitEarly Then                    {a binary header has nothing after its CRC (the CR LF is for hex headers)}
    Z_GetBinaryHead32 := RxType;
  End;



Function ProtObj.Z_GetHeader(Var Hdr: ZHdrType): Integer;
(* Use this routine to get a header - it will figure out  *)
(* what type it is getting (hex, bin16 or bin32) And call *)
(* the appropriate routine.                               *)

  Var
    c: Integer;
    n: Integer;
    CanCount: Integer;
    ADone: Boolean;
    HavePad: Boolean;
    CErrors: Word;

  Begin
  CErrors := 0;
  HavePad := False;
  ADone := False;
  n := CurrentRate * 2;              {A guess at the # of garbage characters}
  CanCount := 5;                     {to expect.                            }
  UseCrc32 := False;                 {assume 16 bit until proven otherwise  }
  While Not ADone Do
    Begin
   rxframeind := 0;
   rxtype := 0;
   c := Z_TimedRead;
   Case c Of
      ZPAD: Begin
        HavePad := True;                    {the next byte is read at the top of the loop (a binary header has one ZPAD)}
        End;
      ZDLE: Begin
        If HavePad Then
          Begin
          c := Z_TimedRead;
          Case c Of
             ZBIN32: Begin
               rxframeind := ZBIN32;        {using 32 bit CRC}
               Z_GetHeader := Z_GetBinaryHead32(hdr);
               ADone := True;
               End;
             ZBIN: Begin
               rxframeind := ZBIN;            {bin with 16 bit CRC}
               Z_GetHeader := Z_GetBinaryHeader(hdr);
               ADone := True;
               End;
             ZHEX: Begin
               rxframeind := ZHEX;            {hex}
               Z_GetHeader := Z_GetHexHeader(hdr);
               ADone := True;
               End;
             Else
               Begin
               HavePad := False;
               Inc(CErrors);
               Pwdw.Message('ZDLE - Bad Header ' + Long2Str(CErrors));
               End;
             End;
          End;
        End;
      RCDO: Begin
        ADone := True;
        Pwdw.Message('Lost Carrier');
        Z_GetHeader := RCDO;
        End;
      ZTIMEOUT: Begin
        Z_GetHeader := ZTimeOut;
        Dec(n);
        If n < 0 Then
          Begin
          ADone := True;
          Pwdw.Message('TimeOut waiting for header');
          End;
        End;
      (* CAN = ZDLE = 24, so Turbo Pascal always took the ZDLE arm above and this
         one never ran; FPC refuses duplicate case labels.
      CAN: Begin
        Dec(cancount);
        If (cancount < 0) Then
          Begin
          Z_GetHeader := ZCAN;
          Pwdw.Message('Cancelled');
          ADone := True;
          End;
        End;
      *)
      ZCRCW: Begin
        Pwdw.Message('ZCRCW');
        Z_GetHeader := ZError;
        ADone := True;
        End;
      Else
        Begin
        CanCount := 5;
        Dec(n);
        IF (n < 0) Then
        Begin
          Inc(zerrors);
          PWdw.Errors(zerrors);
          PWdw.Message('Header is corrupted');
          Z_GetHeader := ZERROR;
          ADone := True;
          End;
        End;
      End; {Case}
    If CancelKey Then
      Begin
      Z_SendCan;                                {tell the other End,   }
      PWdw.Message('Cancelled from keyboard');  {the operator,         }
      Z_GetHeader := ZCAN;                      {And the rest of the   }
      ADone := True;                            {routines to forget it.}
      End;
    If CErrors > MaxCErrors Then
      Begin
      ADone := True;
      Z_GetHeader := ZError;
      End;
    End; {While}
  RxPos := Z_PullLongFromHeader(PI^.RxHdr);
  End;


(***************************************************)
(* RECEIVE FILE ROUTINES                           *)
(***************************************************)

Const
   ZATTNLEN = 32;  {max length of attention String}
   lastwritten: Byte = 0;

Var
  t: LongInt;
  rzbatch: Boolean;
  outfile: FILE;     {this is the file}
  tryzhdrtype: Byte;
  rxcount: Integer;
  filestart: LongInt;
  isbinary, eofseen: Boolean;
  zconv: Byte;
  zrxpath: String;

Function RZ_ReceiveDa32(Var buf: buftype; blength: Integer): Integer;
(* Get a 32 bit CRC data block *)
  LABEL
    crcfoo;
  Var
    c, d, n: Integer;
    crc: LongInt;
    done: Boolean;

  Begin
  usecrc32 := True;
  crc := -1;
  rxcount := 0;
  done := False;
  REPEAT
    c := Z_GetZDL;
    IF (Hi(c) <> 0) Then
      Begin
      crcfoo:  CASE c OF
               GOTCRCE,
               GOTCRCG,
               GOTCRCQ,
               GOTCRCW: Begin
                        d := c;
                        crc := UpdC32(Lo(c),crc);
                        FOR n := 0 TO 3 DO
                          Begin
                          c := Z_GetZDL;
                          IF (Hi(c) <> 0) Then
                            GOTO crcfoo;
                          crc := UpdC32(Lo(c),crc)
                          End;
                        IF (crc <> Crc32Good) Then
                          Begin
                          Inc(zerrors);
                          PWdw.Errors(zerrors);
                          RZ_ReceiveDa32 := ZERROR
                          End
                        ELSE
                          RZ_ReceiveDa32 := d;
                        DONE := True
                      End;
              GOTCAN: Begin
                      RZ_ReceiveDa32 := ZCAN;
                      DONE := True
                      End;
            ZTIMEOUT: Begin
                      RZ_ReceiveDa32 := c;
                      DONE := True
                      End;
                RCDO: Begin
                      RZ_ReceiveDa32 := c;
                      done := True
                      End
            ELSE
              Begin
              PWdw.Message('Debris');
              CommFlushIn;
              RZ_ReceiveDa32 := c;
              DONE := True
              End
            End
      End;
    IF (NOT done) Then
      Begin
      Dec(blength);
      IF (blength < 0) Then
        Begin
        PWdw.Message('Long packet');
        RZ_ReceiveDa32 := ZERROR;
        done := True
        End;
      buf[Integer(rxcount)] := Lo(c);
      Inc(rxcount);
      crc := UpdC32(Lo(c),crc)
    End
  UNTIL done
  End;


Function RZ_ReceiveData(Var buf: buftype; blength: Integer): Integer;
(* get a 16 bit CRC data block *)
LABEL
   crcfoo;
Var
   c, d: Integer;
   crc: Word;
   done: Boolean;
Begin
   IF (rxframeind = ZBIN32) Then
   Begin
      PWdw.ShowCheck(True);
      RZ_ReceiveData := RZ_ReceiveDa32(buf,blength);
      Exit
   End;
   PWdw.ShowCheck(False);
   crc := 0;
   rxcount := 0;
   done := False;
   REPEAT
      c := Z_GetZDL;
      IF (Hi(c) <> 0) Then
      Begin
crcfoo:  CASE c OF
            GOTCRCE,
            GOTCRCG,
            GOTCRCQ,
            GOTCRCW: Begin
                        d := c;
                        crc := UpdCrc(Lo(c),crc);
                        c := Z_GetZDL;
                        IF (Hi(c) <> 0) Then
                           GOTO crcfoo;
                        crc := UpdCrc(Lo(c),crc);
                        c := Z_GetZDL;
                        IF (Hi(c) <> 0) Then
                           GOTO crcfoo;
                        crc := UpdCrc(Lo(c),crc);
                        IF (crc <> 0) Then
                        Begin
                           Inc(zerrors);
                           PWdw.Errors(zerrors);
                           RZ_ReceiveData := ZERROR;
                           done := True
                        End;
                        RZ_ReceiveData := d;
                        DONE := True
                     End;
            GOTCAN: Begin
                       PWdw.Message('Got Cancelled');
                       RZ_ReceiveData := ZCAN;
                       DONE := True
                    End;
            ZTIMEOUT: Begin
                         RZ_ReceiveData := c;
                         DONE := True
                      End;
            RCDO: Begin
                     PWdw.Message('Lost carrier');
                     RZ_ReceiveData := c;
                     done := True
                  End
            ELSE
            Begin
               PWdw.Message('Debris');
               CommFlushIn;
               RZ_ReceiveData := c;
               DONE := True
            End
         End
      End;
      IF (NOT done) Then
      Begin
         Dec(blength);
         IF (blength < 0) Then
         Begin
            PWdw.Message('Long packet');
            RZ_ReceiveData := ZERROR;
            done := True
         End;
         buf[Integer(rxcount)] := Lo(c);
         Inc(rxcount);
         crc := UpdCrc(Lo(c),crc)
      End
   UNTIL done
End;


Procedure ProtObj.RZ_AckBibi;
(* ACKnowledge the other Ends request to terminate cleanly *)
  Var
    n: Integer;

  Begin
  Z_PutLongIntoHeader(rxpos);
  n := 4;
  CommFlushIn;
  REPEAT
    Z_SendHexHeader(ZFIN, PI^.Txhdr);
    CASE Z_GetByte(20) OF
      ZTIMEOUT,
      RCDO: Exit;
      79: Begin
          IF (Z_GetByte(10) = 79) Then
            {null};
          If Not ProtKeepInput Then
            CommFlushIn;
          Exit
          End
      ELSE
        CommFlushIn;
      Dec(n)
      End
    UNTIL (n <= 0)
  End;


Function ProtObj.RZ_InitReceiver: Integer;
LABEL
   again;
Var
   c, n, errors: Integer;
Begin
   FillChar(attn,SizeOf(attn),0);
   zerrors := 0;
   FOR n := 10 DOWNTO 0 DO
   Begin
      IF (NOT CommCarrier) Then
      Begin
         PWdw.Message('Lost carrier');
         RZ_InitReceiver := ZERROR;
         Exit
      End;
      Z_PutLongIntoHeader(LongInt(0));
      PI^.txhdr[ZF0] := CANFDX OR CANOVIO OR CANFC32 OR CANBRK; {Full dplx, overlay I/O And CRC32}
      Z_SendHexHeader(tryzhdrtype, PI^.txhdr);
      IF (tryzhdrtype = ZSKIP) Then
         tryzhdrtype := ZRINIT;
again:
         c := Z_GetHeader(PI^.rxhdr);
         CASE c OF
         ZFILE: Begin
                   zconv := PI^.rxhdr[ZF0];
                   tryzhdrtype := ZRINIT;
                   c := RZ_ReceiveData(secbuf,ZBUFSIZE);
                   IF (c = GOTCRCW) Then
                   Begin
                      RZ_InitReceiver := ZFILE;
                      Exit
                   End;
                   Z_SendHexHeader(ZNAK, PI^.txhdr);
                   GOTO again
                End;
         ZSINIT: Begin
                   c := RZ_ReceiveData(attn,ZBUFSIZE);
                   IF (c = GOTCRCW) Then
                       Z_SendHexHeader(ZACK, PI^.txhdr)
                    ELSE
                       Z_SendHexHeader(ZNAK, PI^.txhdr);
                    GOTO again
                 End;
         ZFREECNT: Begin
                      Z_PutLongIntoHeader(DiskFree(0));
                      Z_SendHexHeader(ZACK, PI^.txhdr);
                      GOTO again
                   End;
         ZCOMMAnd: Begin
                      c := RZ_ReceiveData(secbuf,ZBUFSIZE);
                      IF (c = GOTCRCW) Then
                      Begin
                         Z_PutLongIntoHeader(LongInt(0));
                         REPEAT
                            Z_SendHexHeader(ZCOMPL, PI^.txhdr);
                            Inc(errors)
                         UNTIL (errors > 10) OR (Z_GetHeader(PI^.rxhdr) = ZFIN);
                         RZ_AckBibi;
                         RZ_InitReceiver := ZCOMPL;
                         Exit
                      End;
                      Z_SendHexHeader(ZNAK, PI^.txhdr);
                      GOTO again
                   End;
         ZCOMPL,
         ZFIN: Begin
                  RZ_InitReceiver := ZCOMPL;
                  Exit
               End;
         ZCAN,
         RCDO: Begin
                  RZ_InitReceiver := c;
                  Exit
               End
      End
   End;
   PWdw.Message('Timeout');
   RZ_InitReceiver := ZERROR
End;


Function SafeName(S: String): String;
  {a name the sender gave: no directory, nothing that is not a plain character, not only dots, not hidden}
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    If (S[i] < ' ') Or (S[i] = '/') Or (S[i] = '\') Or (S[i] = ':') Or (S[i] = #127) Then
      S[i] := '_';
  While (Length(S) > 0) And (S[1] = '.') Do
    Delete(S, 1, 1);
  If S = '' Then
    S := 'upload.dat';
  If Length(S) > 100 Then
    S := Copy(S, 1, 100);
  SafeName := S;
  End;


Function ProtObj.RZ_GetHeader: Integer;
  Var
    e, p, n, i: Integer;
    multiplier: LongInt;
    s: String;
    ttime, tsize: LongInt;
    tname: String;
    MakeFile: Boolean;
    ReturnCode: Integer;

  Begin
  IsBinary := True;    {Force the issue!}
  FSize := 0;
  p := 0;
  s := '';
  While (p < 255) And (secbuf[p] <> 0) Do
    Begin
    s := s + Chr(secbuf[p]);
    Inc(p)
    End;
  Inc(p);
  S := SafeName(StripPath(S));
  FName := s;

  (**** done with name ****)

  FSize := 0;
  WHILE (p < ZBUFSIZE) And (secbuf[p] <> $20) And (secbuf[p] <> 0) DO
    Begin
    fsize := (fsize *10) + Ord(secbuf[p]) - $30;
    Inc(p)
    End;
  Inc(p);

  (**** done with size ****)

  s := '';
  While (p < ZBUFSIZE) And (secbuf[p] IN [$30..$37]) Do
    Begin
    s := s + Chr(secbuf[p]);
    Inc(p)
    End;
  Inc(p);
  ftime := FromUnixDateStr(s);

  (**** done with time ****)

  ReturnCode := ZOk;
  MakeFile := False;

  If (AllowResume And (shFindFile(ZrxPath + FName, TName, TSize, TTime))) Then
    Begin
    If (TTime = FTime) Then
      Begin
      If ((ZConv = zcResum) and (FSize = TSize)) Then
        Begin
        ReturnCode := ZSkip;
        PWdw.Message('Skipping - File Complete');
        End
      Else
        If (FSize > TSize) Then
          Begin
          FileStart := TSize;
          If (Not shOpenFile(outfile,zrxpath + fname)) Then
            Begin
            PWdw.Message('Error opening '+ FName);
            ReturnCode := ZERROR;
            End
          Else
            Begin
            If (Not shSeekFile(outfile,tsize)) Then
              Begin
              PWdw.Message('Error positioning file');
              ReturnCode := ZERROR;
              End;
            End;                     { FileAdditon}
          End
        Else
          Begin
          MakeFile := True;
{          FileAddition := ReplaceFile; }
          End;
        End
      Else
        Begin
        MakeFile := True;
{        FileAdditon := ReplaceFile;   }
        End;
      End
    Else
      Begin
      MakeFile := True;
{      FileAddition := NewFile; }
      End;
  If MakeFile Then
    Begin
    filestart := 0;
    If (NOT shMakeFile(outfile,zrxpath + fname)) Then
      Begin
      PWdw.Message('Unable to create '+fname);
      ReturnCode := ZERROR;
      End;
    End;
  PWdw.ShowName(fname);
  PWdw.ShowSize(fsize);
  RZ_GetHeader := ReturnCode;
  End;


Function ProtObj.RZ_SaveToDisk(Var rxBytes: LongInt): Integer;
  Begin
  If CancelKey Then
    Begin
    PWdw.Message('Aborted from keyboard');
    Z_SendCan;
    RZ_SaveToDisk := ZERROR;
    Exit
    End;
   IF (NOT shWrite(outfile,secbuf,rxcount)) Then
   Begin
      PWdw.Message('Disk write error');
      RZ_SaveToDisk := ZERROR
   End
   ELSE
      RZ_SaveToDisk := ZOK;
   rxBytes := rxBytes + rxcount
End;

Function ProtObj.RZ_ReceiveFile: Integer;
LABEL
   err, nxthdr, moredata;
Var
   c, n: Integer;
   rxBytes: LongInt;
   sptr: String;
   adone: Boolean;
Begin
   zerrors := 0;
   adone := True;                        {the loop goes on (UNTIL NOT adone): it is left by Exit and GOTO err; it was False, so a
                                          NAK, a time out or a repeated ZFILE ended the file instead of asking for the position again}
   eofseen := False;
   c := RZ_GetHeader;
   IF (c <> ZOK) Then
   Begin
      IF (c = ZSKIP) Then
         tryzhdrtype := ZSKIP;
      RZ_ReceiveFile := c;
      Exit
   End;
   c := ZOK;
   n := 10;
   rxBytes := filestart;
   rxpos := filestart;
   PI^.StartTime := TimeCounter;
   zcps := 0;
   REPEAT
      Z_PutLongIntoHeader(rxBytes);
      Z_SendHexHeader(ZRPOS, PI^.Txhdr);
nxthdr:
      c := Z_GetHeader(PI^.Rxhdr);
      CASE c OF
         ZDATA: Begin
                   IF (rxpos <> rxBytes) Then
                   Begin
                      Dec(n);
                      Inc(zerrors);
                      PWdw.Errors(zerrors);
                      IF (n < 0) Then
                         GOTO err;
                      PWdw.Message('Bad position');
                      Z_PutString(attn)
                   End
                   ELSE
                   Begin
moredata:
                      c := RZ_ReceiveData(secbuf,ZBUFSIZE);
                      CASE c OF
                         ZCAN,
                         RCDO: GOTO err;
                         ZERROR: Begin
                                    Dec(n);
                                    Inc(zerrors);
                                    PWdw.Errors(zerrors);
                                    IF (n < 0) Then
                                        GOTO err;
                                    Z_PutString(attn)
                                 End;
                         ZTIMEOUT: Begin
                                      Dec(n);
                                      IF (n < 0) Then
                                         GOTO err
                                   End;
                         GOTCRCW: Begin
                                     n := 10;
                                     c := RZ_SaveToDisk(rxBytes);
                                     IF (c <> ZOK) Then
                                     Begin
                                        RZ_ReceiveFile := c;
                                        Exit
                                     End;
                                     ShowLoc(rxBytes);
                                     Z_PutLongIntoHeader(rxBytes);
                                     Z_SendHexHeader(ZACK, PI^.txhdr);
                                     GOTO nxthdr
                                  End;
                         GOTCRCQ: Begin
                                     n := 10;
                                     c := RZ_SaveToDisk(rxBytes);
                                     IF (c <> ZOK) Then
                                     Begin
                                        RZ_ReceiveFile := c;
                                        Exit
                                     End;
                                     ShowLoc(rxBytes);
                                     Z_PutLongIntoHeader(rxBytes);
                                     Z_SendHexHeader(ZACK, PI^.txhdr);
                                     GOTO moredata
                                  End;
                         GOTCRCG: Begin
                                     n := 10;
                                     c := RZ_SaveToDisk(rxBytes);
                                     IF (c <> ZOK) Then
                                     Begin
                                        RZ_ReceiveFile := c;
                                        Exit
                                     End;
                                     ShowLoc(rxBytes);
                                     GOTO moredata
                                  End;
                         GOTCRCE: Begin
                                     n := 10;
                                     c := RZ_SaveToDisk(rxBytes);
                                     IF (c <> ZOK) Then
                                     Begin
                                        RZ_ReceiveFile := c;
                                        Exit
                                     End;
                                     ShowLoc(rxBytes);
                                     GOTO nxthdr
                                  End
                      End {case}
                   End
                End; {case of ZDATA}
         ZNAK,
         ZTIMEOUT: Begin
                      Dec(n);
                      IF (n < 0) Then
                         GOTO err;
                      ShowLoc(rxBytes)
                   End;
         ZFILE: Begin                    {the sender says it again (it had two requests for it): ask for the position again}
                   Dec(n);
                   IF (n < 0) Then
                      GOTO err;
                   c := RZ_ReceiveData(secbuf,ZBUFSIZE);
                End;
         ZEOF: IF (rxpos = rxBytes) Then
               Begin
                  RZ_ReceiveFile := c;
                  Exit
               End
               ELSE
                  GOTO nxthdr;
         ZERROR: Begin
                    Dec(n);
                    IF (n < 0) Then
                       GOTO err;
                    ShowLoc(rxBytes);
                    Z_PutString(attn)
                 End
         ELSE
         Begin
            c := ZERROR;
            GOTO err
         End
      End {case}
   UNTIL (NOT adone);
err:
   RZ_ReceiveFile := ZERROR
End;


Function ProtObj.RZ_ReceiveBatch: Integer;
Var
   s: String;
   c: Integer;
   adone: Boolean;
   ETime: LongInt;
Begin
   PWdw.Message('Receiving...');
   adone := False;
   WHILE (NOT adone) DO
   Begin
      IF NOT (CommCarrier) Then
      Begin
         RZ_ReceiveBatch := ZERROR;
         Exit
      End;
      c := RZ_ReceiveFile;
      ETime := ((TimeCounter - PI^.StartTime) * 10) Div 182;
      If ETime < 0 Then
        Inc(ETime, 86400);
      If ETime > 0 Then
        zcps := fsize Div ETime;
      shSetFTime(outfile,ftime);
      shCloseFile(outfile);
      If (c = ZEOF) And (PI^.NumFiles < MaxFiles) Then
        Begin
        Inc(PI^.NumFiles);                    {received: its name, as it is on the disk}
        PI^.FN[PI^.NumFiles] := zrxpath + fname;
        PI^.Status[PI^.NumFiles] := 1;
        End;
      Str(zcps:4,s);
      PWdw.Message(s+' cps');
      CASE c OF
         ZEOF,
         ZSKIP: Begin
                   c := RZ_InitReceiver;
                   CASE c OF
                      ZFILE: {null};
                      ZCOMPL: Begin
                                 RZ_AckBibi;
                                 RZ_ReceiveBatch := ZOK;
                                 Exit
                              End;
                      ELSE
                      Begin
                         RZ_ReceiveBatch := ZERROR;
                         Exit
                      End
                   End
                End
         ELSE
         Begin
            RZ_ReceiveBatch := c;
            Exit
         End
      End {case}
   End {while}
End;


Function ProtObj.Zmodem_Receive(path: String): Boolean;
  {the files of a Zmodem sender are put in the directory path; PI^.NumFiles, FN[] and Status[] say what came}
  Var
    i: Integer;
    RcvOk: Boolean;

  Begin
  If Not Z_AsyncOn(CurrentPort, CurrentRate) Then
    Begin
    Zmodem_Receive := False;
    Exit;
    End;
  PWdw.Init;
  PWdw.OpenWindow;
  PWdw.ShowProt('Zmodem Receive');
  PI^.NumFiles := 0;
  PI^.StartTime := TimeCounter;
  CommFlushIn;
  CommSetBinary(True);
  zrxpath := path;
  IF (zrxpath <> '') And (zrxpath[Length(zrxpath)] <> '\') And (zrxpath[Length(zrxpath)] <> '/') Then
     zrxpath := zrxpath + DirectorySeparator;
  rxtimeout := 100;
  tryzhdrtype := ZRINIT;
  i := RZ_InitReceiver;
  RcvOk := (i = ZCOMPL) OR ((i = ZFILE) And ((RZ_ReceiveBatch) = ZOK));
  Zmodem_Receive := RcvOk;
  IF Not RcvOk Then
    Begin
    CommFlushOut;
    PWdw.Message('Sending CAN');
    Z_SendCan;
    End;
  CommFlushOut;
  If (Not RcvOk) Or (Not ProtKeepInput) Then
    Begin
    If CommWaitChar(300) Then;             {what the sender still says (OO ...)}
    CommFlushIn;
    End;                                   {as the caller of a BBS what follows is wanted: its prompt}
  CommSetBinary(False);
  PWdw.CloseWindow;
  PWdw.Done;
  End;


(*######### Xmodem / Ymodem RECEIVE ROUTINES ##################*)

Procedure ProtObj.SetRecvName(Name: String);
  Begin
  PI^.RxName := SafeName(StripPath(Name));
  End;


Function ProtObj.RX_GetBlock: Integer;
  {One block of Xmodem / Ymodem.  0 = a good block (PI^.DataBlk, PI^.RxBlkNum, PI^.RxBlkLen), 1 = EOT, 2 = a damaged
   block (the line has been left quiet), 3 = cancelled by the sender, 4 = no carrier, 5 = nothing came}
  Var
    c, i, Comp, Hi8, Lo8: Integer;
    Len: Word;
    Sum: Word;
    Bad: Boolean;

  Begin
  c := Z_GetByte(182);
  Case c Of
    RCDO: Begin RX_GetBlock := 4; Exit; End;
    ZTimeOut: Begin RX_GetBlock := 5; Exit; End;
    4: Begin RX_GetBlock := 1; Exit; End;
    24: Begin
        c := Z_GetByte(20);
        If c = 24 Then
          RX_GetBlock := 3
        Else
          RX_GetBlock := 2;
        Exit;
        End;
    1: Len := 128;
    2: Len := 1024;
    Else
      Begin
      While CommWaitChar(500) Do                {garbage: wait until the line is quiet}
        If CommRecv = #0 Then;
      RX_GetBlock := 2;
      Exit;
      End;
    End;
  Bad := False;
  PI^.RxBlkNum := Z_GetByte(100);
  Comp := Z_GetByte(100);
  If (PI^.RxBlkNum < 0) Or (Comp < 0) Then
    Bad := True
  Else If (PI^.RxBlkNum + Comp) <> 255 Then
    Bad := True;
  i := 1;
  While (i <= Len) And (Not Bad) Do
    Begin
    c := Z_GetByte(100);
    If c < 0 Then
      Bad := True
    Else
      PI^.DataBlk[i] := c;
    Inc(i);
    End;
  If Not Bad Then
    Begin
    If PI^.CrcType = 0 Then
      Begin
      Sum := 0;
      For i := 1 To Len Do
        Sum := (Sum + PI^.DataBlk[i]) And $ff;
      c := Z_GetByte(100);
      If (c < 0) Or (c <> Sum) Then
        Bad := True;
      End
    Else
      Begin
      Sum := 0;
      For i := 1 To Len Do
        Sum := UpdCrc(PI^.DataBlk[i], Sum);
      Hi8 := Z_GetByte(100);
      Lo8 := Z_GetByte(100);
      If (Hi8 < 0) Or (Lo8 < 0) Then
        Bad := True
      Else
        Begin
        Sum := UpdCrc(Hi8, Sum);              {with the CRC that came, the CRC of the block is 0}
        Sum := UpdCrc(Lo8, Sum);
        If Sum <> 0 Then
          Bad := True;
        End;
      End;
    End;
  If Bad Then
    Begin
    While CommWaitChar(500) Do
      If CommRecv = #0 Then;
    RX_GetBlock := 2;
    End
  Else
    Begin
    PI^.RxBlkLen := Len;
    RX_GetBlock := 0;
    End;
  End;


Function ProtObj.RX_Receive(Path: String; Batch: Boolean): Boolean;
  {Xmodem (one file, named by SetRecvName) or Ymodem (a batch: names and sizes come in block 0) into the directory
   Path.  Ymodem-G (GProt) has no ACKs for the data blocks.  CRC 16 is asked for first, the checksum only after three
   tries (or when CrcType is 0).}
  Var
    FilePath: String;
    InitCh: Char;
    r, Expect, Errors, Tries, k, j: Integer;
    Stop, FileOpen, GotEot, Started, UseCrc: Boolean;
    Size, Got, Take: LongInt;
    Name, Num: String;
    FTm: LongInt;
    Ok: Boolean;

  Procedure Ask;
    Begin
    If PI^.GProt Then
      CommSend('G')
    Else If PI^.CrcType <> 0 Then
      CommSend('C')
    Else
      CommSend(Chr(21));
    CommFlushOut;
    End;

  Procedure Ack;
    Begin
    CommSend(Chr(6));
    CommFlushOut;
    End;

  Procedure Nak;
    Begin
    CommSend(Chr(21));
    CommFlushOut;
    End;

  Procedure Cancel;
    Var
      n: Integer;
    Begin
    For n := 1 To 8 Do
      CommSend(Chr(24));
    For n := 1 To 8 Do
      CommSend(Chr(8));
    CommFlushOut;
    End;

  Procedure CloseOne(WithTime: Boolean);
    Begin
    If FileOpen Then
      Begin
      If WithTime And (FTm > 0) Then
        shSetFTime(outfile, FTm);
      shCloseFile(outfile);
      FileOpen := False;
      End;
    End;

  Begin
  Ok := False;
  RX_Receive := False;
  If Not CommActive Then
    Exit;
  If (Path <> '') And (Path[Length(Path)] <> '/') Then
    Path := Path + '/';
  PI^.NumFiles := 0;
  PI^.StartTime := TimeCounter;
  CommFlushIn;
  CommSetBinary(True);
  Stop := False;
  FileOpen := False;
  Expect := 0;
  Errors := 0;
  Tries := 0;
  Started := False;
  GotEot := False;
  UseCrc := PI^.CrcType <> 0;
  Size := 0;
  Got := 0;
  FTm := 0;
  If Batch Then
    Expect := 0
  Else
    Begin
    If PI^.RxName = '' Then
      PI^.RxName := 'upload.dat';
    FilePath := Path + PI^.RxName;
    If Not shMakeFile(outfile, FilePath) Then
      Begin
      CommSetBinary(False);
      Exit;
      End;
    FileOpen := True;
    Expect := 1;
    End;
  Ask;
  While Not Stop Do
    Begin
    r := RX_GetBlock;
    Case r Of
      0: Begin
         If Batch And (Expect = 0) Then
           Begin
           {block 0: the name, a NUL, the size and the time, or nothing: the end of the batch}
           If (PI^.RxBlkNum = 0) Then
             Begin
             If PI^.DataBlk[1] = 0 Then
               Begin
               Ack;
               PI^.Abort := False;
               Ok := PI^.NumFiles > 0;
               Stop := True;
               End
             Else
               Begin
               Name := '';
               k := 1;
               While (k <= 128) And (PI^.DataBlk[k] <> 0) Do
                 Begin
                 Name := Name + Chr(PI^.DataBlk[k]);
                 Inc(k);
                 End;
               Inc(k);
               Num := '';
               While (k <= 128) And (PI^.DataBlk[k] In [48..57]) Do
                 Begin
                 Num := Num + Chr(PI^.DataBlk[k]);
                 Inc(k);
                 End;
               Size := Str2Long(Num);
               Inc(k);
               Num := '';
               While (k <= 128) And (PI^.DataBlk[k] In [48..55]) Do
                 Begin
                 Num := Num + Chr(PI^.DataBlk[k]);
                 Inc(k);
                 End;
               If Num <> '' Then
                 FTm := FromUnixDateStr(Num)
               Else
                 FTm := 0;
               PI^.RxName := SafeName(StripPath(Name));
               FilePath := Path + PI^.RxName;
               If shMakeFile(outfile, FilePath) Then
                 Begin
                 FileOpen := True;
                 Got := 0;
                 Expect := 1;
                 GotEot := False;
                 Errors := 0;
                 Ack;
                 Ask;                         {now the data}
                 End
               Else
                 Begin
                 Cancel;
                 Stop := True;
                 End;
               End;
             End
           Else
             Nak;
           End
         Else If PI^.RxBlkNum = (Expect And $ff) Then
           Begin
           Started := True;
           GotEot := False;
           Take := PI^.RxBlkLen;
           If Batch And (Size > 0) And (Got + Take > Size) Then
             Take := Size - Got;
           If Take > 0 Then
             If Not shWrite(outfile, PI^.DataBlk, Take) Then
               Begin
               Cancel;
               Stop := True;
               End;
           Inc(Got, Take);
           Inc(Expect);
           Errors := 0;
           If Not PI^.GProt Then
             Ack;
           End
         Else If PI^.RxBlkNum = ((Expect - 1) And $ff) Then
           Begin
           If Not PI^.GProt Then
             Ack;                            {the sender did not get our ACK: the block again}
           End
         Else
           Begin
           Cancel;                            {a block from somewhere else: out of step}
           Stop := True;
           End;
         End;
      1: Begin
         If (Not GotEot) And (Not PI^.GProt) Then
           Begin
           GotEot := True;
           Nak;                              {the first EOT is answered with a NAK, the second with the ACK}
           End
         Else
           Begin
           Ack;
           CloseOne(True);
           Inc(PI^.NumFiles);
           PI^.FN[PI^.NumFiles] := FilePath;
           PI^.Status[PI^.NumFiles] := 1;
           If Batch Then
             Begin
             Expect := 0;
             Size := 0;
             Ask;                            {the next name, or the end}
             End
           Else
             Begin
             Ok := True;
             Stop := True;
             End;
           End;
         End;
      2: Begin
         Inc(Errors);
         If PI^.GProt Or (Errors > 10) Then
           Begin
           Cancel;
           Stop := True;
           End
         Else
           Nak;
         End;
      3, 4: Stop := True;
      5: Begin
         Inc(Errors);
         If Errors > 10 Then
           Stop := True
         Else If (Not Started) And ((Batch And (Expect = 0)) Or ((Not Batch) And (Got = 0))) Then
           Begin
           {nothing has come yet: ask again; Xmodem falls back to the checksum after three C}
           Inc(Tries);
           If (Not Batch) And (Tries >= 3) And UseCrc And (Not PI^.GProt) Then
             Begin
             UseCrc := False;
             PI^.CrcType := 0;
             End;
           Ask;
           End
         Else If PI^.GProt Then
           Begin
           Cancel;
           Stop := True;
           End
         Else
           Nak;
         End;
      End;
    End;
  CloseOne(False);
  CommFlushOut;
  If CommWaitChar(300) Then;
  CommFlushIn;
  CommSetBinary(False);
  RX_Receive := Ok;
  End;


(*######### Send ROUTINES #####################################*)



Var
   strtpos: LongInt;
   rxbuflen: Integer;
   blkred: Integer;


Procedure SZ_Z_SendByte(b: Byte);
  Begin
  If ((b And $7F) IN [16,17,19,24]) Or (((b And $7F) = 13) And ((lastsent And $7F) = 64)) Then
    Begin
    Z_SendByte(ZDLE);
    LastSent := (b XOR 64)
    End
  Else
    LastSent := b;
  Z_SendByte(lastsent)
  End;


Procedure SZ_SendBinaryHead32(htype: Byte; Var hdr: Zhdrtype);
  Var
    crc: LongInt;
    n: Integer;

  Begin
  Z_SendByte(ZPAD);
  Z_SendByte(ZDLE);
  Z_SendByte(ZBIN32);
  SZ_Z_SendByte(htype);
  crc := UpdC32(htype,-1);
  For n := 0 To 3 Do
    Begin
    SZ_Z_SendByte(hdr[n]);
    crc := UpdC32(hdr[n],crc)
    End;
  crc := (NOT crc);
  For n := 0 To 3 Do
    Begin
    SZ_Z_SendByte(Byte(crc));
    crc := (crc SHR 8)
    End;
  IF (HType <> ZDATA) Then
    Delay(100)
  End;


Procedure SZ_SendBinaryHeader(htype: Byte; Var hdr: Zhdrtype);
  Var
    crc: Word;
    n: Integer;

  Begin
  If (UseCrc32) Then
    SZ_SendBinaryHead32(htype,hdr)
  Else
    Begin
    Z_SendByte(ZPAD);
    Z_SendByte(ZDLE);
    Z_SendByte(ZBIN);
    SZ_Z_SendByte(htype);
    crc := UpdCrc(htype,0);
    For n := 0 To 3 Do
      Begin
      SZ_Z_SendByte(hdr[n]);
      crc := UpdCrc(hdr[n],crc)
      End;
    crc := UpdCrc(0,crc);
    crc := UpdCrc(0,crc);
    SZ_Z_SendByte(Lo(crc Shr 8));
    SZ_Z_SendByte(Lo(crc));
    If (htype <> ZDATA) Then
      Delay(100)
    End;
  End;


Procedure SZ_SendData(Var buf: DataBlkType; blength: Integer; frameEnd: Byte);
  Var
    crc: Word;
    Crc32: LongInt;
    t: Integer;

  Begin
  If (UseCrc32) Then
    Begin
    Crc32 := -1;
    For t := 1 to (BLength) Do
      Begin
      SZ_Z_SendByte(Buf[t]);
      Crc32 := UpdC32(Buf[t], Crc32);
      End;
    Crc32 := UpdC32(FrameEnd, Crc32);
    Crc32 := Not Crc32;
    Z_SendByte (ZDLE);
    Z_SendByte (FrameEnd);
    For t := 0 to 3 Do
      Begin
      SZ_Z_SendByte(Byte(Crc32));
      Crc32 := Crc32 shr 8;
      End;
    End
  Else
    Begin
    Crc := 0;
    For t := 1 To (blength) Do
      Begin
      SZ_Z_SendByte(buf[t]);
      crc := UpdCrc(buf[t],crc)
      End;
    crc := UpdCrc(frameEnd,crc);
    Z_SendByte(ZDLE);
    Z_SendByte(frameEnd);
    crc := UpdCrc(0,crc);
    crc := UpdCrc(0,crc);
    SZ_Z_SendByte(Lo(crc SHR 8));
    SZ_Z_SendByte(Lo(crc));
    End;
  If (frameEnd = ZCRCW) Then
    Begin
    Z_SendByte(17); {Xon to be sure}
    End;
  End;


Procedure ProtObj.SZ_EndSend;
  Var
    adone: Boolean;
    CErrors: Word;

  Begin
  CErrors := 0;
  Pwdw.Message('Transfer completed');
  adone := False;
  While ((Not ADone) and (Not PI^.Abort)) Do
    Begin
    Z_PutLongIntoHeader(TxPos);
    SZ_SendBinaryHeader(ZFIN, PI^.Txhdr);
    CASE Z_GetHeader(PI^.rxhdr) OF
      ZFIN: Begin
            Z_SendByte(Ord('O'));
            Z_SendByte(Ord('O'));
            Delay(500);
            CommFlushOut;
            ADone := True;
            End;
      ZCAN,
      RCDO,
      ZFERR,
      ZTIMEOUT: ADone := True;
      Else
        Begin
        Inc(CErrors);
        If CErrors > MaxCErrors Then
          ADone := True;
        End;
      End {case}
    End;
  PI^.SendState := 0;
  End;


Function ProtObj.SZ_GetReceiverInfo: Integer;
  Var
    rxflags, n, c: Integer;
  Begin
  PWdw.Message('Getting info.');
  FOR n := 1 TO 20 Do
    Begin
    c := Z_GetHeader(PI^.rxhdr);
    CASE c OF
      ZCHALLENGE: Begin
            PI^.TxHdr := PI^.RxHdr;
            Z_SendHexHeader(ZACK, PI^.txhdr)
            End;
      ZCOMMAnd: Begin
            Z_PutLongIntoHeader(LongInt(0));
            Z_SendHexHeader(ZRQINIT, PI^.txhdr)
            End;
      ZRINIT: Begin
            RxBufLen := (Word(PI^.RxHdr[ZP1]) SHL 8) OR PI^.RxHdr[ZP0];
            usecrc32 := ((PI^.rxhdr[ZF0] And CANFC32) <> 0);
            PWdw.ShowCheck(usecrc32);
            SZ_GetReceiverInfo := ZOK;
            Exit
            End;
      ZCAN,
      RCDO: Begin
            SZ_GetReceiverInfo := ZError;
            Exit;
            End;
      ZTIMEOUT: Begin
            Z_SendByte(17); {Xon}
            Z_PutLongIntoHeader(0);
            Z_SendHexHeader(ZrqInit, PI^.TxHdr);
            End;
      ELSE
        IF (c <> ZRQINIT) OR (PI^.rxhdr[ZF0] <> ZCOMMAnd) Then
          Z_SendHexHeader(ZNAK, PI^.txhdr)
      End {case}
    End; {for}
  SZ_GetReceiverInfo := ZError;
  End;


Function ProtObj.SZ_SyncWithReceiver: Integer;
  Var
    c: Integer;
    num_errs: Integer;
    ADone: Boolean;

  Begin
  num_errs := 7;
  adone := False;
  While ((Not ADone) and (Not PI^.Abort)) Do
    Begin
    c := Z_GetHeader(PI^.Rxhdr);
    CommFlushIn;
    Case c Of
       ZTIMEOUT: Begin
         Dec(num_errs);
         If (num_errs < 0) Then
           Begin
           SZ_SyncWithReceiver := ZERROR;
           ADone := True;
           End;
         End;
       ZCAN,
       ZABORT,
       ZFIN,
       RCDO: Begin
         SZ_SyncWithReceiver := ZERROR;
         ADone := True;
         End;
       ZRPOS: Begin
         If (NOT shSeekFile(PI^.PFile, rxpos)) Then
           Begin
           PWdw.Message('File seek error');
           SZ_SyncWithReceiver := ZERROR;
           ADone := True;
           End;
         PWdw.Message('Repositioning...');
         ShowLoc(rxpos);
         txpos := rxpos;
         SZ_SyncWithReceiver := c;
         ADone := True;
         End;
       ZSKIP,
       ZRINIT,
       ZACK: Begin
         SZ_SyncWithReceiver := c;
         ADone := True;
         End;
       ELSE
         Begin
         PWdw.Message(Long2Str(C) + ' Error syncing with receiver');
         SZ_SendBinaryHeader(ZNAK, PI^.Txhdr);
         Dec(Num_Errs);
         If Num_Errs < 0 Then
           Begin
           SZ_SyncWithReceiver := ZERROR;
           ADone := True;
           End;
         End
       End; {case}
    End; {While}
  End;



Function ProtObj.SZ_SendFileData: Integer;
  Var
     C: Integer;
     E: Integer;
     newcnt: Word;
     blklen: Word;
     blkred: Word;
     maxblklen: Word;
     goodblks: Word;
     goodneeded: Word;
     ADone: Boolean;
     DataState: Word;
     ch: Char;
     CErrors: Word;
     TwoDone: Boolean;

  Begin
  DataState := 1;
  CErrors := 0;
  ADone := False;
  PWdw.Message('Sending file...');
  GoodNeeded := 1;
  If (CurrentRate < 300) Then
    maxblklen := 128
  Else
    MaxBlkLen := (CurrentRate Div 300) * 256;
  If (MaxBlkLen > PI^.BlkSize) Then
    MaxBlkLen := PI^.BlkSize;
  If (rxbuflen > 0) And (rxbuflen < maxblklen) Then
    maxblklen := rxbuflen;
  BlkLen := maxblklen;
  PI^.StartTime := TimeCounter;
  DataState := 0;
  While ((Not ADone) and (Not PI^.Abort)) Do
    Begin
    Case DataState of
      0: Begin
         While ((Not CommInEmpty) and ((CommPeek = Char(XON))
         Or (CommPeek = Char(Xoff)))) Do
           ch := CommRecv;
         If Not CommInEmpty Then
           DataState := 1  {Wait Ack}
         Else
           DataState := 3; {Send header}
         End;
      1: Begin {WaitAck}
         c := SZ_SyncWithReceiver;
         Case c Of
           ZSKIP: Begin
             PWdw.Message('ZSKip - skipping file');
             SZ_SendFileData := ZSKIP;
             ADone := True;
             DataState := 10;
             End;
           ZACK: DataState := 3;
           ZRPOS: Begin
             Inc(zerrors);
             PWdw.Errors(zerrors);
             PWdw.Message('ZRPOS - change file position');
             If ((BlkLen SHR 2) > 32) Then
               BlkLen := (blklen SHR 2)
             Else
               BlkLen := 32;
             If ((BlkLen = 32) and (ZErrors > 50)) Then
               Begin
               ADone := True;
               DataState := 10;
               SZ_SendFileData := ZError;
               End;
             goodblks := 0;
             goodneeded := (goodneeded SHL 1) OR 1;
             DataState := 3; {Send more}
             End;
           ZRINIT: Begin
             PWdw.Message('ZRINIT - ok');
             SZ_SendFileData := ZOK;
             ADone := True;
             DataState := 10;
             End;
           RCDO: Begin
             PWdw.Message('Lost carrier');
             SZ_SendFileData := ZError;
             ADone := True;
             DataState := 10;
             End;
           ZCan: Begin
             PWdw.Message('Cancelled');
             SZ_SendFileData := ZError;
             ADone := True;
             DataState := 10;
             End;
           ELSE
             Begin
             SZ_SendFileData := ZERROR;
             Pwdw.Message('Unknown error');
             Inc(ZErrors);
             If ZErrors > 30 Then
               Begin
               DataState := 10;
               Adone := True;
               End;
             PWdw.Errors(ZErrors);
             End;
           End; {case};
         End; {DataState 1}
      2: Begin
         TwoDone := False;
         DataState := 3;
         If Not ((CommPeek = Chr(Lo(ZPad))) or (CommPeek = Chr(Lo(Can)))) Then
           Begin
           TwoDone := True;
           DataState := 1;
           End
         Else
           Begin
           While ((Not CommInEmpty) And (Not TwoDone)) Do
             Begin
             Case Z_GetByte(2) of
               Can, ZPad: Begin
                 DataState := 1;
                 TwoDone := True;
                 End;
               RCDO: Begin
                 SZ_SendFileData := ZError;
                 PWdw.Message('Lost carrier');
                 Adone := True;
                 TwoDone := True;
                 DataState := 10;
                 End;
               End;
             End;
           End;
         End; {DataState 2}
      3: Begin
         DataState := 4;
         newcnt := rxbuflen;
         Z_PutLongIntoHeader(txpos);
         SZ_SendBinaryHeader(ZDATA, PI^.TxHdr);
         PWdw.Message('Sending file...');
         End; {DateState 3}
      4: Begin
         DataState := 5;
         If CancelKey Then
           Begin
           PWdw.Message('Aborted from keyboard');
           Z_SendCan;
           ADone := True;
           PI^.SendState := 0;
           DataState := 10;
           SZ_SendFileData := ZError;
           End;
         If (Not CommCarrier) Then
           Begin
           PWdw.Message('Lost Carrier');
           ADone := True;
           SZ_SendFileData := ZError;
           DataState := 10;
           End;
         If (Not shRead(PI^.PFile, PI^.DataBlk, BlkLen, BlkRed)) Then
           Begin
           PWdw.Message('Error reading disk');
           Z_SendCan;
           ADone := True;
           DataState := 10;
           SZ_SendFileData := ZError;
           End;
         If (blkred < blklen) Then
           Begin
           e := ZCRCE      {last block}
           End
         Else
           Begin
           If (rxbuflen <> 0) And ((newcnt - blkred) <= 0) Then
             Begin
             newcnt := (newcnt - blkred);
             e := ZCRCW
             End
           Else
             Begin
             e := ZCRCG;
             End;
           End;
         SZ_SendData(PI^.DataBlk, BlkRed, E);
         txpos := txpos + BlkRed;
         ShowLoc(txpos);
         Inc(goodblks);
         If (blklen < maxblklen) And (goodblks > goodneeded) Then
           Begin
           If ((blklen SHL 1) < maxblklen) Then
             blklen := (blklen SHL 1)
           Else
             blklen := maxblklen;
           goodblks := 0;
           End;
         End; {DataState 5}
      5: Begin
         If e = ZCRCW Then
           DataState := 1
         Else
           Begin
           If e = ZCRCG Then
             DataState := 6
           Else
             DataState := 8;
           End;
         End; {DataState 6}
      6: Begin
         DataState := 7;
         TwoDone := False;
         While ((Not CommInEmpty) And (Not TwoDone)) Do
           Begin
           CASE Z_GetByte(1) OF
             CAN, ZPad: Begin
               PWdw.Message('Got Can or ZPad');
               CommFlushOut;
               SZ_SendData(PI^.DataBlk,0,ZNak);
               Inc(CErrors);
               DataState := 1;
               TwoDone := True;
               End;
             RCDO: Begin
               SZ_SendFileData := ZERROR;
               ADone := True;
               TwoDone := True;
               DataState := 10;
               PI^.SendState := 0;
               End;
             End; {case}
           End; {while CommIn Not Empty}
         End; {DataState 8}
      7: Begin
         If e <> ZCRCG Then
           DataState := 8
         Else
           DataState := 4;
         End; {DataState 7}
      8: Begin
         Z_PutLongIntoHeader(txpos);
         PWdw.Message('Sending EOF');
         SZ_SendBinaryHeader(ZEOF, PI^.Txhdr);
         c := SZ_SyncWithReceiver;
           Case c Of
             ZACK: DataState := 10;
             ZRPOS: DataState := 0;
             ZRINIT: Begin
               SZ_SendFileData := ZOK;
               PWdw.Message('File completed');
               PI^.Status[PI^.CurrFile] := 1;
               DataState := 10;
               ADone := True;
               End;
             ZSKIP: Begin
               SZ_SendFileData := c;
               PWdw.Message('Skipping file');
               DataState := 10;
               ADone := True;
               End;
             Else
               Begin
               SZ_SendFileData := ZERROR;
               ADone := True;
               DataState := 10;
               End;
             End; {case}
         End; {DataState 8}
      10: ADone := True;
      End; {Case of DataState}
    If CErrors > MaxCErrors Then
      Begin
      SZ_SendFileData := ZError;
      DataState := 10;
      ADone := True;
      End;
    End; {While not ADone}
  End;


Function ProtObj.SZ_SendFile: Integer;
  Var
    c: Integer;
    adone: Boolean;
    CErrors: Word;

  Begin
  CErrors := 0;
  PI^.SendState := 3;
  ZErrors := 0;
  aDone := False;
  While ((Not aDone) and (Not PI^.Abort)) Do
    Begin
    If (Not CommCarrier) Then
      Begin
      PWdw.Message('Lost carrier');
      SZ_SendFile := ZERROR;
      aDone := True;
      End;
    If Not aDone Then
      Begin
      FillChar(PI^.TxHdr,4,0);
      PI^.TxHdr[ZF0] := ZcResum; {recover}
      SZ_SendBinaryHeader(ZFILE, PI^.Txhdr);
      SZ_SendData(PI^.DataBlk, 150, ZCRCW);
      Repeat
        Begin
        c := Z_GetHeader(PI^.RxHdr);
        Case c Of
          ZTimeOut:  Begin
            PWdw.Message('TimeOut');
            PWdw.Errors(ZErrors);
            Inc(CErrors);
            If CErrors > MaxCErrors Then
              Begin
              ADone := True;
              SZ_SendFile := ZError;
              End;
            End;
          ZCan: Begin
            PWdw.Message('Cancelled');
            Inc(ZErrors);
            aDone := True;
            SZ_SendFile := ZError;
            End;
          RCDO: Begin
            PWdw.Message('Lost Carrier');
            Inc(ZErrors);
            SZ_SendFile := ZError;
            PI^.SendState := 0;
            PI^.Error := 1;
            aDone := True;
            End;
          ZABort: Begin
            Inc(ZErrors);
            PWdw.Message('Abort');
            aDone := True;
            SZ_SendFile := ZError;
            End;
          ZFin: Begin
             SZ_SendFile := ZERROR;
             aDone := True;
             End;
          ZRINIT: {null - this will cause a loopback};
          ZCRC: Begin
                Z_PutLongIntoHeader(Z_FileCRC32(PI^.PFile));
                Z_SendHexHeader(ZCRC, PI^.TxHdr)
                End;
          ZSKIP: Begin
                 SZ_SendFile := c;
                 aDone := True;
                 End;
          ZRPOS: Begin
                 PWdw.Message('ZRPOS' + Long2Str(RxPos));
                 If (Not shSeekFile(PI^.PFile,rxpos)) Then
                   Begin
                   PWdw.Message('File positioning error');
                   Z_SendHexHeader(ZFERR, PI^.TxHdr);
                   SZ_SendFile := ZERROR;
                   End;
                 PWdw.Message('Setting start position');
                 ShowLoc(rxpos);
                 StrtPos := RxPos;
                 TxPos := RxPos;
                 SZ_SendFile := SZ_SendFileData;
                 ADone := True;
                 PI^.SendState := 3;
                 End
          End {case}
        End; {Repeat}
      Until ((c <> ZRInit) or (PI^.Abort));
      End; {if not done}
    If CancelKey Then
      Begin
      Z_SendCan;
      SZ_SendFile := ZERROR;
      aDone := True;
      End;
    End; {While not done}
  End;


Procedure ProtObj.Init;
  Var
    i: Word;

  Begin
  New(PI);
  PI^.NumFiles := 0;
  For i := 1 to MaxFiles Do
    PI^.FN[i] := '';
  SetXmodem;
  End;


Procedure ProtObj.Done;
  Begin
  Close(PI^.PFile);
  If IOResult <> 0 Then;
  Dispose(PI);
  End;


Procedure ProtObj.AddSendFile(FN: String);
  Begin
  If PI^.NumFiles < MaxFiles Then
    Begin
    Inc(PI^.NumFiles);
    PI^.FN[PI^.NumFiles] := Copy(FN,1,128);
    End;
  End;


Procedure ProtObj.SetYModem;
  Begin
  PI^.SendHdr := True;
  PI^.BlkSize := 1024;
  PI^.CrcType := 1;
  PI^.GProt := False;
  PI^.Prot := 'Y';
  End;


Procedure ProtObj.SetYModemG;
  Begin
  PI^.SendHdr := True;
  PI^.BlkSize := 1024;
  PI^.CrcType := 1;
  PI^.GProt := True;
  PI^.Prot := 'G';
  End;


Procedure ProtObj.SetXmodemG;
  Begin
  PI^.SendHdr := False;
  PI^.BlkSize := 1024;
  PI^.CrcType := 1;
  PI^.GProt := True;
  PI^.Prot := 'Q';
  End;


Procedure ProtObj.SetXmodem;
  Begin
  PI^.SendHdr := False;
  PI^.BlkSize := 128;
  PI^.CrcType := 1;
  PI^.GProt := False;
  PI^.Prot := 'X';
  End;


Procedure ProtObj.SetSealink;
  Begin
  PI^.SendHdr := False;
  PI^.BlkSize := 128;
  PI^.CrcType := 1;
  PI^.GProt := False;
  PI^.Prot := 'S';
  End;


Procedure ProtObj.SetXmodemC;
  Begin
  PI^.SendHdr := False;
  PI^.BlkSize := 128;
  PI^.CrcType := 0;
  PI^.GProt := False;
  PI^.Prot := 'C';
  End;


Procedure ProtObj.SetX1K;
  Begin
  PI^.SendHdr := False;
  PI^.BlkSize := 1024;
  PI^.CrcType := 1;
  PI^.GProt := False;
  PI^.Prot := 'O';
  End;


Procedure ProtObj.SetZmodem;
  Begin
  PI^.SendHdr := True;
  PI^.BlkSize := 1024;
  PI^.CrcType := 2;
  PI^.GProt := False;
  PI^.Prot := 'Z';
  End;


Procedure ProtObj.WaitSend;
  Var
    Tmp: Integer;
    WaitTime: LongInt;
    Finished: Boolean;
    CanCount: Word;

  Begin
  Case PI^.Prot of
    'X': Pwdw.ShowProt('Xmodem Send');
    'Y': Pwdw.ShowProt('Ymodem Send');
    'S': Pwdw.ShowProt('Sealink Send');
    'O': Pwdw.ShowProt('1k-Xmodem Send');
    'G': Pwdw.ShowProt('Ymodem-G Send');
    'Q': Pwdw.ShowProt('1k-Xmodem-G Send');
    End;
  CanCount := 0;
  Finished := False;
  WaitTime := TimeCounter + 1092;
  While ((Not Finished) and (Not PI^.Abort)) Do
    Begin
    Tmp := Z_GetByte(182);
    Case Tmp Of
      RCDO: Begin
            PI^.Error := 1;
            Finished := True;
            PI^.Abort := True;
            End;
      ZTimeOut: Begin
            If TimeOut(WaitTime) Then
              Begin
              PI^.Error := 2;
              PI^.Abort := True;
              Finished := True;
              End;
            End;
      021: Begin       {NAK Xmodem}
           PI^.CrcType := 0;
           PI^.SendState := 2;
           Finished := True;
           End;
      067: Begin       {C Ymodem}
           PI^.CrcType := 1;
           PI^.SendState := 2;
           Finished := True;
           End;
      071: Begin       {G Ymodem G}
           PI^.CrcType := 1;
           PI^.SendState := 2;
           Finished := True;
           End;
      024: Begin                        {Get 2 cancels then abort}
           Inc(CanCount);
           If CanCount > 1 Then
             Begin
             PI^.Error := 3;
             PI^.Abort := True;
             Finished := True;
             End;
           End;
      Else
        Begin
        Pwdw.Message('Unexpected' +  Long2Str(Tmp));
        If TimeOut(WaitTime) Then
          Begin
          PI^.Error := 2;
          PI^.Abort := True;
          Finished := True;
          End;
        End;
      End;
    If CancelKey Then
      Begin
      PWdw.Message('Aborted from keyboard');
      Finished := True;
      PI^.SendState := 0;
      End;
    End;
  If PI^.Error <> 0 Then
    PI^.SendState := 0
  Else
    PI^.SendState := 2;
  End;


Function ProtObj.StripPath(FN: String): String;
  Var
    TmpStr: String;

  Begin
  TmpStr := FN;
  While Pos(':',TmpStr) > 0 Do
    Delete(TmpStr, 1, Pos(':', TmpStr));
  While (Pos('\', TmpStr) > 0) Or (Pos('/', TmpStr) > 0) Do
    Begin
    If Pos('\', TmpStr) > 0 Then
      Delete(TmpStr, 1, Pos('\', TmpStr))
    Else
      Delete(TmpStr, 1, Pos('/', TmpStr));
    End;
  While Pos('/', TmpStr) > 0 Do
    Delete(TmpStr, 1, Pos('/', TmpStr));
  StripPath := TmpStr;
  End;


Procedure ProtObj.SendHeader;
  {Ymodem block 0: the name (as it is), a NUL, the size and the time of the file (octal seconds since 1970)}
  Var
    TempStr: String;

  Begin
  TempStr := StripPath(PI^.FN[PI^.CurrFile]) + #0
    + Long2Str(FileSize(PI^.PFile)) + ' '
    + ToUnixDateStr(FTime);
  FillChar(PI^.DataBlk, 128, 0);
  If Length(TempStr) > 120 Then
    TempStr := Copy(TempStr, 1, 120);
  Move(TempStr[1], PI^.DataBlk, Length(TempStr));
  SendData(128);
  End;


Procedure ProtObj.SendEOT;
  {end of a file (Xmodem, Ymodem): EOT until the receiver ACKs it; a strict Xmodem receiver NAKs the first one}
  Var
    Tries, CanCount: Word;
    Acked: Boolean;
    Ch: Integer;

  Begin
  Acked := False;
  Tries := 0;
  CanCount := 0;
  While (Not Acked) And (Tries < 10) And (Not PI^.Abort) Do
    Begin
    Inc(Tries);
    Z_SendByte(4);
    Ch := Z_GetByte(182);
    Case Ch Of
      6: Acked := True;
      RCDO: Begin
            PI^.Error := 1;
            PI^.Abort := True;
            End;
      24: Begin
          Inc(CanCount);
          If CanCount > 1 Then
            Begin
            PI^.Error := 3;
            PI^.Abort := True;
            End;
          End;
      End;
    End;
  If Acked Then
    PI^.Status[PI^.CurrFile] := 1
  Else If PI^.Error = 0 Then
    PI^.Error := 2;
  End;


Procedure ProtObj.SendBatchEnd;
  {Ymodem: after the last file an empty block 0 ends the batch}
  Var
    Ch: Integer;
    WaitTime: LongInt;
    Got: Boolean;

  Begin
  Got := False;
  WaitTime := TimeCounter + 1092;
  While (Not Got) And (Not TimeOut(WaitTime)) And (Not PI^.Abort) Do
    Begin
    Ch := Z_GetByte(182);
    If (Ch = 67) Or (Ch = 71) Or (Ch = 21) Then
      Got := True
    Else If Ch = RCDO Then
      Begin
      PI^.Error := 1;
      PI^.Abort := True;
      End;
    End;
  If Got Then
    Begin
    FillChar(PI^.DataBlk, 128, 0);
    PI^.BlockNum := 0;
    SendData(128);
    End;
  PI^.SendState := 0;
  End;


Procedure ProtObj.SendData(BSize: Word);
  Var
    Finished : Boolean;
    ByteBlock: Byte;
    i: Word;
    CheckValue: Word;
    BlockErrors: Word;
    FinishedChar: Boolean;
    IntCh: Integer;
    WaitTime: LongInt;
    CanCount: Word;

  Begin
  WaitTime := TimeCounter + 1092;
  CanCount := 0;
  BlockErrors := 0;
  Finished := False;
  While ((Not Finished) and (Not PI^.Abort)) Do
    Begin
    CheckValue := 0;                        {every try of a block starts again}
    ByteBlock := PI^.BlockNum And $ff;
    Case BSize Of
      0128: Z_SendByte(01);
      1024: Z_SendByte(02);
      End;
    Z_SendByte(ByteBlock);
    Z_SendByte(Not ByteBlock);
    For i := 1 to BSize Do
      Begin
      Z_SendByte(PI^.DataBlk[i]);
      Case PI^.CrcType of
        0: Begin
           Inc(CheckValue, PI^.DataBlk[i]);
           CheckValue := CheckValue And $ff;
           End;
        1: CheckValue := UpdCrc(PI^.DataBlk[i], CheckValue);
        End;
      End;
    Case PI^.CrcType Of
      0: Z_SendByte(Lo(CheckValue));
      1: Begin
         CheckValue := UpdCrc(0, UpdCrc(0, CheckValue));     {the CRC of a block is sent with 16 more zero bits}
         Z_SendByte(Hi(CheckValue));
         Z_SendByte(Lo(CheckValue));
         End;
      End;
    FinishedChar := (PI^.GProt and (PI^.BlockNum <> 0));
    If (PI^.GProt and (PI^.BlockNum <> 0))Then
      Begin
      Inc(PI^.BlockNum);
      Finished := True;
      If CancelKey Then
        Begin
        PWdw.Message('Aborted from keyboard');
        Finished := True;
        End;
      If Not CommCarrier Then
        Begin
        PWdw.Message('Lost Carrier');
        Finished := True;
        PI^.Abort := True;
        PI^.Error := 1;
        End;
      While ((Not CommInEmpty) And (CommCarrier)) Do
        Begin
        Case Z_GetByte(1) Of
          CAN: Begin
               PWdw.Message('Got Cancel from remote');
               Finished := True;
               PI^.Error := 1;
               PI^.Abort := True;
               End;
          End;
        End;
      End
    Else
      Begin
      While ((Not FinishedChar) and (Not PI^.Abort)) Do
        Begin
        IntCh := Z_GetByte(182);
        Case IntCh of
          RCDO:
            Begin
            PI^.Error := 1;
            Finished := True;
            FinishedChar := True;
            PI^.Abort := True;
            End;
          ZTimeOut:
            Begin
            If TimeOut(WaitTime) Then
              Begin
              PI^.Error := 2;
              Finished := True;
              FinishedChar := True;
              PI^.Abort := True;
              Pwdw.Message('Timeout');
              End;
            End;
          006: Begin
            Finished := True;
            FinishedChar := True;
            Inc(PI^.BlockNum);
            Pwdw.Message('Ack');
            End;
          071: Begin { G }
            If PI^.GProt Then
              Begin
              Finished := True;
              FinishedChar := True;
              Inc(PI^.BlockNum);
              Pwdw.Message('G Ack on Header');
              End;
            End;
          021: Begin
            FinishedChar := True;
            Inc(BlockErrors);
            Pwdw.Errors(BlockErrors);
            If BlockErrors > 9 Then
              Begin
              Finished := True;
              PI^.SendState := 0;
              PI^.Error := 4;
              PI^.Abort := True;
              End;
            End;
          024: Begin
            Inc(CanCount);
            If CanCount > 1 Then
              Begin
              Finished := True;
              FinishedChar := True;
              PI^.Error := 3;
              PI^.Abort := True;
              Pwdw.Message('Cancelled');
              End
            End;
          End;  {End Case of ch}
       If CancelKey Then
         Begin
         FinishedChar := True;
         Finished := True;
         End;
       End;  {FinishedChar}
      End; {If Not GProt}
    End;  {Finished}
  End;


Procedure ProtObj.SendBlock;
  Var
    NumRead: Word;

  Begin
  If ((PI^.BlockNum = 0) And (Not PI^.SendHdr)) Then
    Inc(PI^.BlockNum);
  If PI^.BlockNum = 0 Then
    SendHeader
  Else
    Begin
    FillChar(PI^.DataBlk, PI^.BlkSize, 026);
    Pwdw.ShowLoc(FilePos(PI^.PFile));
    If Not shRead(PI^.PFile, PI^.DataBlk, PI^.BlkSize, NumRead) Then
      Begin
      PI^.SendState := 0;
      PI^.Error := 5;
      End
    Else
      Begin
      If NumRead = 0 Then
        Begin
        SendEOT;
        If PI^.Error = 0 Then
          PI^.SendState := 3
        Else
          PI^.SendState := 0;
        End
      Else
        Begin
        SendData(PI^.BlkSize);
        End;  {Else num read > 0}
      End;  {Else read ok}
    End;  {Else send data}
  End;


Procedure ProtObj.GetNextSendFile;
  Begin
  Close(PI^.PFile);
  If IoResult <> 0 Then;
  If ((PI^.Prot = 'Z') Or (PI^.Prot = '8')) Then
    PI^.SendState := 11
  Else
    PI^.SendState := 1;
  PI^.BlockNum := 0;
  Inc(PI^.CurrFile);
  If PI^.CurrFile <= PI^.NumFiles Then
    Begin
    While ((Not FileExist(PI^.FN[PI^.CurrFile])) and (PI^.CurrFile < PI^.NumFiles)) Do
      Begin
      Pwdw.Message(PI^.FN[PI^.CurrFile] + ' Not Found');
      PI^.Status[PI^.CurrFile] := 0;
      Delay(3000);
      Inc(PI^.CurrFile);
      End;
    If Not FileExist(PI^.FN[PI^.CurrFile]) Then
      Inc(PI^.CurrFile);
    End;
  If PI^.CurrFile <= PI^.NumFiles Then
    Begin
    Pwdw.ShowName(PI^.FN[PI^.CurrFile]);
    Pwdw.ShowSize(SizeFile(PI^.FN[PI^.CurrFile]));
    Assign(PI^.PFile, PI^.FN[PI^.CurrFile]);
    FileMode := fmReadOnly + fmDenyNone;
    If Not shReset(PI^.PFile,1) Then
      Begin
      PI^.Error := 5;
      PI^.SendState := 0;
      Pwdw.Message('Unable to Open file' + PI^.FN[PI^.CurrFile]);
      End
    Else
      GetFTime(PI^.PFile, FTime);
    PI^.FPos := 0;
    End
  Else
    Begin                                   {All files completed}
    If ((PI^.Prot = 'Z') Or (PI^.Prot = '8')) Then
      Begin
      PI^.SendState := 13                   {Send Zmodem end of transfer}
      End
    Else If (PI^.Prot = 'Y') Or (PI^.Prot = 'G') Then
      Begin
      PI^.SendState := 5;                   {Ymodem: the empty block 0 that ends a batch}
      End
    Else
      Begin
      PI^.SendState := 0;                   {Transfer is done}
      End;
    End;
  End;


Procedure ProtObj.ZStartSend;
  Begin
  ZErrors := 0;
  PI^.SendState := 3;
  PWdw.ShowProt('Zmodem Send');
  Z_SendByte(Ord('r'));
  Z_SendByte(Ord('z'));
  Z_SendByte(13);
  Z_PutLongIntoHeader(0);
  Z_SendHexHeader(ZRqInit, PI^.TxHdr);
  If (CurrentRate > 0) Then
    RxTimeout := Integer(614400 DIV CurrentRate)
  Else
    RxTimeout := 180;
  If (RxTimeout < 180) Then
    RxTimeout := 180;
  If (SZ_GetReceiverInfo = ZERROR) Then
    Begin
    PI^.Error := 6;
    PI^.SendState := 0;
    End;
  End;



Procedure ProtObj.ZOneFile; {SendState = 11}
  Var
    S: String;
    FTime: LongInt;

  Begin
  GetFTime(PI^.PFile, FTime);
  S := Lower(StripPath(PI^.FN[PI^.CurrFile]) + #0
    + Long2Str(FileSize(PI^.PFile)) + ' '
    + ToUnixDateStr(FTime));
  FillChar(PI^.DataBlk, SizeOf(PI^.DataBlk), 0);
  Move(s[1], PI^.DataBlk, Length(s));
  PI^.SendState := 12;
  End;



Procedure ProtObj.Send;
  Var
    i: Word;

  Begin
  PI^.Abort := False;
  Pwdw.Init;
  PWdw.OpenWindow;
  For i := 1 to MaxFiles Do
    PI^.Status[i] := 0;
  PI^.CurrFile := 0;
  PI^.StartTime := TimeCounter;
  If CurrentPort = 0 Then
    Begin
    PI^.SendState := 0;
    PI^.Error := 1;
    End
  Else
    Begin
    CommFlushIn;
    CommSetBinary(True);
    PI^.SendState := 3;
    PI^.Error := 0;
    End;
  If (((PI^.Prot = 'Z') Or (PI^.Prot = '8')) And (PI^.Error = 0)) Then
    ZStartSend;
  PI^.BlockNum := 0;
  While PI^.SendState <> 0 Do
    Begin
    If PI^.Abort then
      PI^.SendState := 0;
    Case PI^.SendState Of
      01: WaitSend;                         {Wait}
      02: SendBlock;                        {Send data block}
      03: GetNextSendFile;                  {Get next file to send}
      11: ZOneFile;                         {Zmodem Setup of file send}
      12: i := SZ_SendFile;                 {Zmodem Send current file}
      13: SZ_EndSend;                       {Zmodem End of transfer}
      05: SendBatchEnd;                     {Ymodem end of batch}
      End;
    End;
  If PI^.Error <> 0 Then
    Begin
    Case PI^.Error Of
      1: Pwdw.Message('No Carrier');
      2: Pwdw.Message('Time Out');
      3: Pwdw.Message('Cancelled by remote');
      4: Pwdw.Message('Too many errors');
      5: Pwdw.Message('Error reading file');
      6: Pwdw.Message('Error');
      7: Pwdw.Message('Cancelled Local');
      End;
    End;
  Close(PI^.PFile);
  If IoResult <> 0 Then;
  CommFlushOut;
  If (PI^.Error <> 0) Or (Not ProtKeepInput) Then
    Begin
    If CommWaitChar(300) Then;             {what the receiver still says}
    CommFlushIn;
    End;                                   {as the caller of a BBS what follows is wanted: its prompt}
  CommSetBinary(False);
  Pwdw.CloseWindow;
  Pwdw.Done;
  End;


Function ProtObj.GetFileStatus(FN: Word): Byte;
  Begin
  GetFileStatus := PI^.Status[FN];
  End;


Function ProtObj.Recv(Path: String): Boolean;
  {files from the other end into the directory Path: Zmodem, Ymodem (batch), Xmodem (one file: SetRecvName)}
  Begin
  Recv := False;
  Case PI^.Prot Of
    'Z', '8': Recv := Zmodem_Receive(Path);
    'Y', 'G': Recv := RX_Receive(Path, True);
    'X', 'O', 'C', 'Q', 'S': Recv := RX_Receive(Path, False);
    End;
  End;


End.
