Unit MkFossil;

{$I-}

{$I MKB.Def}

Interface

Procedure CommFlushOut;
Procedure CommFlushIn;
Function  CommCarrier: Boolean;
Function  CommRecv: Char;
Function  CommPeek: Char;
Function  CommOutReady: Boolean;
Function  CommOutEmpty: Boolean;
Function  CommInEmpty: Boolean;
Procedure CommSend (Ch: Char);
Function  CommSendNW(Ch: Char): Boolean;
Procedure CommSetBaud(Baud:Word);
Procedure LowerDTR;
Procedure RaiseDTR;
Procedure CommInit;
Procedure CommRelease;
Procedure CommFlow(Flow:Byte);
Procedure CommStartBreak;
Procedure CommStopBreak;
Function  GetCommInfo: String;

Const
  fcSoft = 1;
  fcHard = 2;
  fcBoth = fcSoft + fcHard;
  fcFossil = 8;

Var
  CurrentPort: Byte;
  CurrentRate: Word;


Const ComType: Byte = 0; {0=none, 1=fossil, 2=direct}
Const CommForce: Byte = 0; {Force comm type 0=autodetect}

Implementation

Uses IbmCom, MKString,
{$IFDEF WINDOWS}
  WinDos;
{$ELSE}
  Dos;
{$ENDIF}

Var
  {$IFDEF WINDOWS}
  Regs: TRegisters;
  {$ELSE}
  Regs: Registers;
  {$ENDIF}


Procedure CommFlow(Flow:Byte);
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $0f;
       Regs.Dx := CurrentPort - 1;
       Regs.AL := Flow;
       Intr($14,Regs);
       End;
    End;
  End;


Procedure CommStartBreak;
  Begin
  Regs.Ah := $1a;
  Regs.Dx := CurrentPort - 1;
  Regs.AL := 1;
  Intr($14,Regs);
  End;


Procedure CommStopBreak;
  Begin
  Regs.Ah := $1a;
  Regs.Dx := CurrentPort - 1;
  Regs.AL := 0;
  Intr($14,Regs);
  End;


Procedure CommFlushOut;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $09;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       End;
    2: Com_Flush_Tx;
    End;
  End;


Procedure CommFlushIn;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $0A;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       End;
    2: Com_Flush_Rx;
    End;
  End;


Function  CommCarrier: Boolean;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $03;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       If ((Regs.Al and 128) > 0) Then
         CommCarrier := True
       Else
         CommCarrier := False;
       End;
    2: CommCarrier := Com_Carrier;
    End;
  End;


Function  CommRecv: Char;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $02;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       CommRecv := Chr(Regs.Al);
       End;
    2: CommRecv := Com_Rx;
    End;
  End;


Function  CommPeek: Char;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $0c;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       CommPeek := Chr(Regs.Al);
       End;
    2: CommPeek := Com_Peek;
    End;
  End;


Function  CommOutReady: Boolean;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $03;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       If ((Regs.Ah and 32) > 0) Then
         CommOutReady := True
       Else
         CommOutReady := False;
       End;
    2: CommOutReady := Com_Tx_Ready;
    End;
  End;


Function  CommOutEmpty: Boolean;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $03;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       If ((Regs.Ah And 64) > 0) Then
         CommOutEmpty := True
       Else
         CommOutEmpty := False;
       End;
    2: CommOutEmpty := Com_Tx_Empty;
    End;
  End;


Function  CommInEmpty: Boolean;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $03;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       If ((Regs.Ah And 1) > 0) Then
         CommInEmpty := False
       Else
         CommInEmpty := True;
       End;
    2: CommInEmpty := Com_Rx_Empty;
    End;
  End;


Procedure CommSend (Ch: Char);
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $0B;
       Regs.Dx := CurrentPort - 1;
       Regs.Al := Ord(Ch);
       Intr($14,Regs);
       End;
    2: Com_Tx(Ch);
    End;
  End;


Function CommSendNW(Ch: Char): Boolean;   {Comm send char - no wait}
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $0B;
       Regs.Dx := CurrentPort - 1;
       Regs.Al := Ord(Ch);
       Intr($14, Regs);
       If Regs.Ax = 0 Then
         CommSendNw := False
       Else
         CommSendNw := True;
       End;
    2: Begin
       If Com_Tx_Ready Then
         Begin
         Com_Tx(Ch);
         CommSendNw := True;
         End
       Else
         CommSendNw := False;
       End;
    End;
  End;


Procedure LowerDTR;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $06;
       Regs.Dx := CurrentPort - 1;
       Regs.Al := 0;
       Intr($14,Regs);
       End;
    2: Com_Lower_DTR;
    End;
  End;


Procedure RaiseDTR;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $06;
       Regs.Dx := CurrentPort-1;
       Regs.Al := 1;
       Intr($14,Regs);
       End;
    2: Com_Raise_DTR;
    End;
  End;


Procedure FossilInit;
  Begin
  Regs.Ah := $04;
  Regs.Dx := CurrentPort - 1;
  Regs.Bx := 0;
  Intr($14,Regs);
  If Regs.Ax = $1954 Then
    ComType := 1;
  End;


Procedure CommInit;
  Var
    Error: Word;

  Begin
  If ComType = 0 Then
    Begin
    Case CommForce of
      0: Begin
         FossilInit;
         If ComType <> 1 Then
           Begin
           Com_Install(CurrentPort, Error);
           ComType := 2;
           End;
         End;
      1: FossilInit;
      2: Begin
         Com_Install(CurrentPort, Error);
         ComType := 2;
         End;
      End;
    End;
  End;


Procedure CommSetBaud(Baud:Word);
  Begin
  CurrentRate := Baud;
  Case ComType of
    1: Begin
       Regs.Ah := $00;
       Regs.Dx := CurrentPort-1;
       Case Baud Of
         300: Regs.Al := 64;
         600: Regs.Al := 96;
         1200: Regs.Al := 128;
         2400: Regs.Al := 160;
         4800: Regs.Al := 192;
         9600: Regs.Al := 224;
         19200: Regs.Al := 0;
         38400: Regs.Al := 32;
         End;
       Regs.Al := Regs.Al + 3;
       Intr($14,Regs);
       End;
    2: Com_Set_Speed(Baud);
    End;
  End;


Procedure CommRelease;
  Begin
  Case ComType of
    1: Begin
       Regs.Ah := $05;
       Regs.Dx := CurrentPort - 1;
       Intr($14,Regs);
       ComType := 0;
       End;
    2: Begin
       Com_DeInstall;
       ComType := 0;
       End;
    End;
  End;


Type FossilInfo = Record
  fiSize: Word;
  fiSpec: Byte;
  fiRev: Byte;
  fiID: Pointer;
  fiInSize: Word;
  fiInFree: Word;
  fiOutSize: Word;
  fiOutFree: Word;
  fiSWidth: Word;
  fiSHeight: Word;
  fiBaudMask: Word;
  End;


Function GetCommInfo: String;
  Var
  {$IFDEF WINDOWS}
    Regs: TRegisters;
  {$ELSE}
    Regs : Registers;
  {$ENDIF}
    Info: FossilInfo;
    TmpStr: String;

  Begin
  Case ComType of
    1: Begin
       Regs.AH := $1B;
       Regs.CX := SizeOf(Info);
       Regs.ES := Seg(Info);
       Regs.DI := Ofs(Info);
       Regs.DX := CurrentPort - 1;
       Intr($14, Regs);
       Move(Info.fiId^, TmpStr[0], 255);
       GetCommInfo := Az2Str(TmpStr, 80);
       End;
    2: Begin
       GetCommInfo := 'Direct Comm Support';
       End;
    Else
      GetCommInfo := 'Unknown';
    End;
  End;


End.
