Unit MKVideo;

{$I MKB.Def}

INTERFACE
    Uses MKVCrt, MKString, MKScrn;

{
     MKVideo - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Var
  WX: Byte;
  WY: Byte;

Const
  WXSize = 40;
  WYSize = 10;




Type WindowInfoRec = Record
  xl: Byte;
  xh: Byte;
  yl: Byte;
  yh: Byte;
  Pt: Pointer;
  End;


Type WindowObj = Object
  WindowInfo: ^WindowInfoRec;
  Opened: Boolean;
  Procedure Init;
  Procedure Done;
  Function OpenWindow(xl, yl, xh, yh, attr: Byte): Boolean;
  Procedure CloseWindow;
  End;


Var
  ProtQuiet: Boolean;                  {file transfer: no progress window (the caller's line is the transfer; the screen is not his)}
  ProtLastMsg: String;                 {the last message of a transfer, for the log}


Type ProtocolWindowObj = Object(WindowObj)
  Procedure OpenWindow;
  Procedure CloseWindow;
  Procedure ShowProt(Prot: String);
  Procedure ShowName(filename: String);
  Procedure ShowSize(l: LongInt);
  Procedure ShowCheck(is32: BOOLEAN);
  Procedure Message(s: String);
  Procedure ShowLoc(l: LongInt);
  Procedure Errors(w: WORD);
  Procedure ShowElapsed(ET: LongInt);
  Procedure ShowCPS(CPS: LongInt);
  End;


Implementation



Procedure DoFrame(xl, yl, xh, yh: Byte);
  Var
    Tx, Ty: Byte;

  Const
    Frame: String = '…Õª∫»º';

  Begin
  If xl < 2 Then
    xl := 2;
  If yl < 2 Then
    yl := 2;
  If xh > (ScrnWidth - 1) Then
    xh := (ScrnWidth - 1);
  If yh > (ScrnHeight - 1) Then
    yh := (ScrnHeight - 1);
  GoToXy(xl, yl);
  Write(Frame[1]);
  GoToXy(xl, yh);
  Write(Frame[5]);
  GoToXy(xh, yl);
  Write(Frame[3]);
  GoToXy(xh, yh);
  Write(Frame[6]);
  Tx := xl + 1;
  While (Tx < xh) Do
    Begin
    GoToXy(Tx, yl);
    Write(Frame[2]);
    GoToXy(Tx, yh);
    Write(Frame[2]);
    Inc(Tx);
    End;
  Ty := yl + 1;
  While (Ty < yh) Do
    Begin
    GoToXy(xl, Ty);
    Write(Frame[4]);
    GoToXy(xh, Ty);
    Write(Frame[4]);
    Inc(Ty);
    End;
  End;

Procedure WindowObj.Init;
  Begin
  New(WindowInfo);
  Opened := False;
  End;


Procedure WindowObj.Done;
  Begin
  If Opened Then
    CloseWindow;
  Dispose(WindowInfo);
  End;


Function WindowObj.OpenWindow(xl, yl, xh, yh, attr: Byte): Boolean;
  Begin
  If Opened Then
    CloseWindow;
  If xl < 2 Then
    xl := 2;
  If yl < 2 Then
    yl := 2;
  If xh > (ScrnWidth - 1) Then
    xh := (ScrnWidth - 1);
  If yh > (ScrnHeight - 1) Then
    yh := (ScrnHeight - 1);
  Window(1, 1, ScrnWidth, ScrnHeight);
  WindowInfo^.xl := xl;
  WindowInfo^.xh := xh;
  WindowInfo^.yl := yl;
  WindowInfo^.yh := yh;
  If SaveScrnRegion(xl - 1, yl - 1, xh + 1, yh + 1, WindowInfo^.Pt) Then
    Begin
    Opened := True;
    TextAttr := Attr;
    Window(xl - 1, yl - 1, xh + 1, yh + 1);
    ClrScr;
    Window(1, 1, ScrnWidth, ScrnHeight);
    DoFrame(xl - 1, yl - 1, xh + 1, yh + 1);
    Window(xl, yl, xh, yh);
    End
  Else
    OpenWindow := False;
  End;


Procedure WindowObj.CloseWindow;
  Begin
  If Opened Then
    Begin
    RestoreScrnRegion(WindowInfo^.xl - 1, WindowInfo^.yl - 1,
    WindowInfo^.xh + 1, WindowInfo^.yh + 1, WindowInfo^.Pt);
    Opened := False;
    End;
  End;


Procedure ProtocolWindowObj.CloseWindow;
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  Delay(300);
  WindowObj.CloseWindow;
  End;


Procedure ProtocolWindowObj.OpenWindow;
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  If WindowObj.OpenWindow(10, 5, 10 + 60, 5 + 9, White + Blue shl 4) Then;
  GoToXy(1,2);
  WriteLn(' File Name:');
  WriteLn(' File Size:');
  WriteLn(' Bytes Done:');
  WriteLn(' Elapsed Time:');
  WriteLn(' CPS:');
  WriteLn(' Checking:');
  WriteLn(' Errors:');
  WriteLn(' Message:');
  End;


Procedure ProtocolWindowObj.ShowProt(Prot: String);
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  GoToXy(30 - (Length(Prot) Div 2), 1);
  Write(Prot);
  End;


Procedure ProtocolWindowObj.ShowName(filename: String);
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  IF (Length(filename) > 45) Then
    filename[0] := #45;
  GotoXY(18,2);
  ClrEol;
  Write(filename);
  End;


Procedure ProtocolWindowObj.ShowSize(l: LongInt);
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  GotoXY(18,3);
  ClrEol;
  Write(CommaStr(l));
  End;


Procedure ProtocolWindowObj.ShowElapsed(ET: LongInt);
  Var
    Minutes: Word;
    Seconds: Word;

  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  GoToXy(18, 5);
  ClrEol;
  Minutes := ET Div 60;
  Seconds := ET - (Minutes * 60);
  Write(Long2Str(Minutes) + ':' + PadLeft(Long2Str(Seconds),'0',2));
  End;


Procedure ProtocolWindowObj.ShowCPS(CPS: LongInt);
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  GoToXy(18, 6);
  ClrEol;
  Write(Long2Str(CPS));
  End;


Procedure ProtocolWindowObj.ShowCheck(is32: Boolean);
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  GotoXY(18,7);
  ClrEol;
  If (is32) Then
    WRITE('CRC32')
  Else
    Write('CRC16');
  End;


Procedure ProtocolWindowObj.Message(s: String);
  Begin
  If ProtQuiet Then
    Begin
    ProtLastMsg := s;
    Exit;
    End;
  If (Length(s) > 45) Then
    s[0] := #45;
  GotoXY(18,9);
  ClrEol;
  Write(s)
  End;


Procedure ProtocolWindowObj.ShowLoc(l: LongInt);
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  GoToXy(18,4);
  ClrEol;
  Write(CommaStr(l));
  End;


Procedure ProtocolWindowObj.Errors(w: Word);
  Begin
  If ProtQuiet Then
    Begin
    Exit;
    End;
  GotoXY(18,8);
  ClrEol;
  Write(CommaStr(w));
  End;



Begin
ProtQuiet := True;
End.
