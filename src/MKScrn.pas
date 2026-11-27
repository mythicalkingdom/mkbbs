{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKScrn;
{$I MKB.Def}

{ Free Pascal version: the screen is the in-memory console of MKVCrt (no video
  memory, no BIOS).  AdapterType reports a colour VGA, ScrnPtr points at the
  MKVCrt buffer. }

Interface

{
     MKScrn - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Type ScrnItemType = Record
  Ch: Char;
  Attr: Byte;
  End;


Type ScreenType = Record
  Case Boolean Of
    True:  (ScrnWord: Array[0..8191] of Word);
    False: (ScrnItem: Array[0..8191] of ScrnItemType);
  End;


Var
  AdapterType: Byte;    {0=none 1=mono 2=CGA 4=EGA-C 5=EGA-M}
                        {7=VGA-M 8=VGA-C 10=MCGA-C 11=MCGA-M}
  ScrnWidth: Byte;
  ScrnHeight: Byte;
  ScrnPtr: ^ScreenType;
  FontHeight: Byte;


Function  SaveScrnRegion(xl,yl,xh,yh: Byte; Var Pt: Pointer):Boolean;
Procedure RestoreScrnRegion(xl,yl,xh,yh: Byte; Var Pt: Pointer);
Procedure ScrollScrnRegionUp(xl,yl,xh,yh, count: Byte);
Procedure ScrollScrnRegionDown(xl,yl,xh,yh, count: Byte);
Procedure PutScrnWord (SX: Byte; SY: Byte; CA: Word);
Function  GetScrnWord(SX: Byte; SY: Byte): Word;
Procedure SetCursorPosition(Sx: Byte; Sy: Byte);
Procedure GetCursorPosition(Var Sx: Byte; Var Sy: Byte);
Procedure DelCharInLine(Sx: Byte; Sy: Byte);
Procedure InsCharInLine(Sx: Byte; Sy: Byte; Ch: Char);
Procedure InitializeScrnRegion(xl,yl,xh,yh: Byte; Ch: Char);


Implementation


Uses MKVCrt;


Type WordArray = Array[0..9999] of Word;

Type WordArrayPtr = ^WordArray;


Function SaveScrnRegion(xl,yl,xh,yh: Byte; Var Pt: Pointer):Boolean;
  Var
    Tx: Byte;
    Ty: Byte;
    Ctr: Word;

  Begin
  GetMem(Pt, ((xh + 1 - xl) * (yh +1 - yl) * 2));
  If Pt = nil Then
    SaveScrnRegion := False
  Else
    Begin
    SaveScrnRegion := True;
    Ctr := 0;
    For Tx := xl to xh Do
      Begin
      For Ty := yl to yh Do
        Begin
        WordArrayPtr(PT)^[Ctr] := GetScrnWord(Tx, Ty);
        Inc(Ctr);
        End;
      End;
    End;
  End;


Procedure RestoreScrnRegion(xl,yl,xh,yh: Byte; Var Pt: Pointer);
  Var
    Tx: Byte;
    Ty: Byte;
    Ctr: Word;

  Begin
  If Pt <> nil Then
    Begin
    Ctr := 0;
    For Tx := xl to xh Do
      Begin
      For Ty := yl to yh Do
        Begin
        PutScrnWord(Tx, Ty, WordArrayPtr(PT)^[Ctr]);
        Inc(Ctr);
        End;
      End;
    FreeMem(Pt, ((xh + 1 - xl) * (yh +1 - yl) * 2));
    End;
  End;


Procedure ScrollRegion(xl,yl,xh,yh, count: Byte; Up: Boolean);
  {xl..yh are relative to the window, as in the BIOS version}
  Begin
  xl := xl + (WindMin and $ff);
  yl := yl + (WindMin shr 8);
  xh := xh + (WindMin and $ff);
  yh := yh + (WindMin shr 8);
  If yh > ((WindMax shr 8) + 1) Then
    yh := ((WindMax shr 8) + 1);
  If xh > ((WindMax and $ff) + 1) Then
    xh := ((WindMax and $ff) + 1);
  VScroll(xl, yl, xh, yh, count, Up);
  End;


Procedure ScrollScrnRegionUp(xl,yl,xh,yh, count: Byte);
  Begin
  ScrollRegion(xl, yl, xh, yh, count, True);
  End;


Procedure ScrollScrnRegionDown(xl,yl,xh,yh, count: Byte);
  Begin
  ScrollRegion(xl, yl, xh, yh, count, False);
  End;


Procedure SetCursorPosition(Sx: Byte; Sy: Byte);
  Begin
  VGotoAbs(Sx, Sy);
  End;


Procedure GetCursorPosition(Var Sx: Byte; Var Sy: Byte);
  Begin
  VWhereAbs(Sx, Sy);
  End;


Function GetScrnWord(SX: Byte; SY: Byte): Word;
  Begin
  GetScrnWord := VGetCell(SX, SY);
  End;


Procedure PutScrnWord (SX: Byte; SY: Byte; CA: Word);
  Begin
  VPutCell(SX, SY, CA);
  End;


Procedure SetScreenParams;
  {Called at start up and whenever MKVCrt changes the screen size}
  Begin
  AdapterType := 8;                      {colour VGA}
  FontHeight := 16;
  ScrnWidth := VCols;
  ScrnHeight := VRows;
  ScrnPtr := Pointer(VScreen);
  End;


Procedure DelCharInLine(Sx: Byte; Sy: Byte);
  Var
    Ex: Byte;
    Cx: Byte;

  Begin
  Ex := Lo(WindMax) + 1;
  Cx := Sx;
  While (Cx < Ex) Do
    Begin
    PutScrnWord(Cx, Sy, GetScrnWord(Cx + 1, Sy));
    Inc(Cx);
    End;
  PutScrnWord(Ex, Sy, 32 + (TextAttr shl 8));
  End;


Procedure InsCharInLine(Sx: Byte; Sy: Byte; Ch: Char);
  Var
    Ex: Byte;
    Cx: Byte;

  Begin
  Ex := Lo(WindMax) + 1;
  Cx := Ex;
  While (Cx > Sx) Do
    Begin
    PutScrnWord(Cx, Sy, GetScrnWord(Cx - 1, Sy));
    Dec(Cx);
    End;
  PutScrnWord(Sx, Sy, Ord(Ch) + (TextAttr shl 8));
  End;


Procedure InitializeScrnRegion(xl,yl,xh,yh: Byte; Ch: Char);
  Var
    Cx, Cy: Byte;

  Begin
  xl := xl + (WindMin and $ff);
  yl := yl + (WindMin shr 8);
  xh := xh + (WindMin and $ff);
  yh := yh + (WindMin shr 8);
  If yh > ((WindMax shr 8) + 1) Then
    yh := ((WindMax shr 8) + 1);
  If xh > ((WindMax and $ff) + 1) Then
    xh := ((WindMax and $ff) + 1);
  Cy := yl;
  While (cy <= yh) Do
    Begin
    Cx := xl;
    While (Cx <= xh) Do
      Begin
      PutScrnWord(Cx, Cy, Ord(ch) + (TextAttr shl 8));
      Inc(Cx);
      End;
    Inc(Cy);
    End;
  End;


Begin
SetScreenParams;
OnScreenSize := SetScreenParams;
End.
