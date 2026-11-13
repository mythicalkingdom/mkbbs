{$I-}
Unit MKPack;

{$I MKB.Def}

Interface

  Uses Dos,
  MKFile;

{
                 MKPack - Packed file content viewer
                        Copyright 1991, 1993
               By Mark May - Mythical Kingdom Software
          at  1:110/290      513-237-7737     9600 HST/V32

    You are free to use these routines for any use, but should not
    remove these comment lines
}


Const
  NumPackers = 7;


Type PackBuffType = Array[1..1024] of Byte;


Type PackRecType = record
  PackType: Byte;                     {1=Lzh 2=Zip 3=Arc/Pak 4=Zoo 5=DWC}
                                      {6=ARJ 7=HYP}
  PackFile: File;                     {File being viewed}
  PackOffset: LongInt;                {Offset to read next header}
  PackName: String[13];               {File name with extension file.ext}
  PackDate: LongInt;                  {Dos style file date/time}
  PackOrig: LongInt;                  {Original size}
  PackSize: LongInt;                  {Compressed size}
  PackCRC:  LongInt;                  {CRC}
  Buffer: ^PackBuffType;
  NumRead: Word;
  PackError: Word;
  End;


Type
  PackInfoType = Record
    PackPath: Array[1..NumPackers] of String[64];
    UnPackPath: Array[1..NumPackers] of String[64];
    PackLine: Array[1..NumPackers] of String[25];
    UnPackLine: Array[1..NumPackers] of String[25];
    End;



Type PackFileObj = Object
  PackRec: ^PackRecType;
  Procedure Init;
  Procedure PackFirst(PPath: String);
  Procedure PackNext;
  Function Found: Boolean;
  Function GetPackType: Byte;
  Function GetName: String;
  Function GetOSize: LongInt;
  Function GetCSize: LongInt;
  Function GetDate: LongInt;
  Function GetCRC: LongInt;
  Procedure Done;
  Procedure LzhView;         {Internal use only}
  Procedure ZipView;         {Internal use only}
  Procedure ArcView;         {Internal use only}
  Procedure ZooView;         {Internal use only}
  Procedure DWCView;         {Internal use only}
  Procedure ArjView;         {Internal use only}
  Procedure HypView;         {Internal use only}
  Function BufferToInt(BufferOffset:Integer):Integer;
  Function BufferToWord(BufferOffset:Integer):Word;
  Function BufferToLong(BufferOffset:Integer):LongInt;
  Function BufferToStr(BufferOffset:Integer; Len:Integer):String;
  End;


  {PackError Values}                 {0=Ok, 2=Dos IoError,3= Unsupported Type,
                                      4=Corrupted File, 18=No more files}


Procedure GetPackPaths(Var Packers: PackInfoType);

Implementation


Type
  WordRec = Record
    Lo: Word;
    Hi: Word;
    End;




Function Unix2Dos(UTime: LongInt): LongInt;
{Portions of this routine were from a conversion placed in the public domain}
{by Carley Phillips (76630,3312)}

  Var
    DT: DateTime;
    Tmp: LongInt;
    TmpTime: LongInt;
    Tmp1 : LongInt;
    Tmp2 : LongInt;

  Begin
  Tmp := UTime - (8*60*60);
  Tmp := (Tmp Mod 86400);
  DT.Hour := Tmp Div 3600;
  Tmp := Tmp Mod 3600;
  DT.Min := Tmp Div 60;
  DT.Sec := Tmp Mod 60;
  Tmp1 := ((UTime - (8*60*60)) Div 86400) + 2440588 - 1721119;
  Dt.Year := ((Tmp1-1) Div 1460969) * 4000;
  Tmp1 := ((Tmp1-1) Mod 1460969) + 1;
  Tmp1 := (4 * Tmp1) - 1;
  Tmp2 := (4 * ((Tmp1 Mod 146097) Div 4)) + 3;
  Dt.Year := (100 * (Tmp1 Div 146097)) + (Tmp2 Div 1461) + Dt.Year;
  Tmp1 := (5 * (((Tmp2 Mod 1461) + 4) Div 4)) - 3;
  Dt.Month := Tmp1 Div 153;
  Dt.Day := ((Tmp1 Mod 153) + 5) Div 5;
  If (Dt.Month < 10) Then
    Dt.Month  := Dt.Month + 3
  Else
    Begin
    Dt.Month  := Dt.Month - 9;
    Inc(Dt.Year);
    End;
  If ((Dt.Month > 3) and (Dt.Month < 11)) Then
    Inc(Dt.Hour);
  PackTime(DT,Tmp);
  Unix2Dos := Tmp;
  End;


Procedure PackFileObj.Init;
  Begin
  New(PackRec);
  New(PackRec^.Buffer);
  PackRec^.PackError := 18;
  End;


Procedure PackFileObj.Done;
  Begin
  Dispose(PackRec^.Buffer);
  Dispose(PackRec);
  End;



Function PackFileObj.GetName: String;
  Begin
  GetName := PackRec^.PackName;
  End;


Function PackFileObj.GetOSize: LongInt;
  Begin
  GetOSize := PackRec^.PackOrig;
  End;


Function PackFileObj.GetCSize: LongInt;
  Begin
  GetCSize := PackRec^.PackSize;
  End;


Function PackFileObj.GetDate: LongInt;
  Begin
  GetDate := PackRec^.PackDate;
  End;


Function PackFileObj.GetCRC: LongInt;
  Begin
  GetCRC := PackRec^.PackCRC;
  End;


Function PackFileObj.BufferToInt(BufferOffset:Integer):Integer;
  Var
    IntPtr: ^Integer;

  Begin
  IntPtr:= @PackRec^.Buffer^[BufferOffset];
  BufferToInt := IntPtr^;
  End;


Function PackFileObj.BufferToWord(BufferOffset:Integer):Word;
  Var
    WordPtr: ^Word;

  Begin
  WordPtr:= @PackRec^.Buffer^[BufferOffset];
  BufferToWord := WordPtr^;
  End;


Function PackFileObj.BufferToLong(BufferOffset:Integer):LongInt;
  Var
    LongPtr: ^LongInt;

  Begin
  LongPtr := @PackRec^.Buffer^[BufferOffset];
  BufferToLong := LongPtr^;
  End;


Function PackFileObj.BufferToStr(BufferOffset:Integer; Len:Integer):String;
  Var
    I:    Integer;
    S:    String;

  Begin
  For I := 1 to Len do
    S[I] := chr(PackRec^.Buffer^[I + BufferOffset - 1]);
  S[0] := chr(Len);
  BufferToStr := S;
  End;


Procedure PackFileObj.LzhView;
  Begin
  If PackRec^.PackError = 0 Then
    Begin
    Seek(PackRec^.PackFile,PackRec^.PackOffset);
    If IoResult <> 0 Then
      PackRec^.PackError := 2;
    End;
  If PackRec^.PackError = 0 Then
    If Not shRead(PackRec^.PackFile,PackRec^.Buffer^,128,PackRec^.NumRead) Then
      PackRec^.PackError := 2;
  If PackRec^.NumRead < 24 Then
    PackRec^.PackError := 18;
  If PackRec^.PackError = 0 Then
    If PackRec^.Buffer^[1] > 0 Then
      Begin
      PackRec^.PackDate := BufferToLong(16);
      PackRec^.PackCRC := BufferToWord(23 + PackRec^.Buffer^[22]);
      PackRec^.PackOrig := BufferToLong(12);
      PackRec^.PackSize := BufferToLong(8);
      PackRec^.PackName := BufferToStr(23,PackRec^.Buffer^[22]);
{     PackRec^.PackOffset := PackRec^.PackOffset + 24 + PackRec^.Buffer^[22] + PackRec^.PackSize;}
      PackRec^.PackOffset := PackRec^.PackOffset + PackRec^.Buffer^[1] + PackRec^.PackSize + 2;
      End;
  End;


Procedure PackFileObj.ZipView;
  Var
    HdrId: Integer;           {HdrId = 1027 on valid zip headers}

  Begin
  If PackRec^.PackError = 0 Then
    Begin
    Seek (PackRec^.PackFile,PackRec^.PackOffset);
    If IoResult <> 0 Then
      PackRec^.PackError := 2;
    End;
  If PackRec^.PackError = 0 Then
    If Not shRead(PackRec^.PackFile,PackRec^.Buffer^,128,PackRec^.NumRead) Then
      PackRec^.PackError := 2;
  If PackRec^.NumRead < 30 Then
    PackRec^.PackError := 4;
  If ((BufferToInt(3) = 1027) and (PackRec^.PackError = 0)) Then
    Begin
    PackRec^.PackDate := BufferToLong(11);
    PackRec^.PackCRC := BufferToLong(15);
    PackRec^.PackOrig := BufferToLong(23);
    PackRec^.PackSize := BufferToLong(19);
    PackRec^.PackName := BufferToStr(31,BufferToInt(27));
    PackRec^.PackOffset := PackRec^.PackOffset + 30 + PackRec^.PackSize;
    PackRec^.PackOffset := PackRec^.PackOffset + BufferToInt(29) + BufferToInt(27);
    End
  Else
    PackRec^.PackError := 18;
  End;


Procedure PackFileObj.ArcView;
  Var
    I: Word;
    WR: WordRec;

  Begin
  If PackRec^.NumRead < 29 Then
    PackRec^.PackError := 4;
  If ((PackRec^.Buffer^[1] = 26) and (PackRec^.Buffer^[2] <> 0)) then
    Begin
    Wr.Hi := BufferToWord(20);
    Wr.Lo := BufferToWord(22);
    PackRec^.PackDate := LongInt(Wr);
    PackRec^.PackCRC := BufferToWord(24);
    PackRec^.PackOrig := BufferToLong(26);
    PackRec^.PackSize := BufferToLong(16);
    i := 3;
    While ((i < 15) And (PackRec^.Buffer^[i] <> 0)) Do
      Inc(i);
    PackRec^.PackName := BufferToStr(3,i - 2);
    PackRec^.PackOffset := PackRec^.PackOffset + 29 + PackRec^.PackSize;
    End
  Else
    PackRec^.PackError := 18;
  End;


Procedure PackFileObj.HypView;
  Var
    I: Word;
    WR: WordRec;

  begin
  If PackRec^.NumRead < 23 Then
    PackRec^.PackError := 18;
  If ((PackRec^.Buffer^[1] = 26) and
      ((BufferToWord(2) = $5453) or (BufferToWord(2) = $5048)) ) Then
    Begin
{    Wr.Hi := BufferToWord(20);
    Wr.Lo := BufferToWord(22); }
    PackRec^.PackDate := BufferToLong(13);
    PackRec^.PackCRC := BufferToLong(17);
    PackRec^.PackOrig := BufferToLong(9);
    PackRec^.PackSize := BufferToLong(5);
    i := PackRec^.Buffer^[22];
    For i := 1 to PackRec^.Buffer^[22] Do
      PackRec^.PackName[i] := Chr(PackRec^.Buffer^[i+22]);
    PackRec^.PackName[0] := Chr(PackRec^.Buffer^[22]);
    PackRec^.PackOffset := PackRec^.PackOffset + 22 + PackRec^.PackSize;
    Inc(PackRec^.PackOffset,PackRec^.Buffer^[22]);
    End
  Else
    PackRec^.PackError := 18;
  End;


Procedure PackFileObj.ZooView;
  Var
    I: Word;
    Wr: WordRec;

  Begin
  If PackRec^.NumRead < 39 Then
    PackRec^.PackError := 4;
  If ((BufferToLong(1) = $FDC4A7DC) and (BufferToLong(11) > 0)) then
    Begin
    Wr.Hi := BufferToWord(15);
    Wr.Lo := BufferToWord(17);
    PackRec^.PackDate := LongInt(Wr);
    PackRec^.PackCRC := BufferToWord(19);
    PackRec^.PackOrig := BufferToLong(21);
    PackRec^.PackSize := BufferToLong(25);
    i := 39;
    While ((i < 52) And (PackRec^.Buffer^[i] <> 0)) Do
      Inc(i);
    PackRec^.PackName := BufferToStr(39,i - 39);
    For i := 1 to Length(PackRec^.PackName) Do
      PackRec^.PackName[i] := UpCase(PackRec^.PackName[i]);
    PackRec^.PackOffset := BufferToLong(7);
    End
  Else
    PackRec^.PackError := 18;
  End;


Procedure PackFileObj.DwcView;
  Var
    i: Word;

  Begin
  If PackRec^.NumRead < 34 Then
    PackRec^.PackError := 18
  Else
    Begin
    PackRec^.PackDate := Unix2Dos(BufferToLong(18));
    PackRec^.PackCRC := BufferToWord(33);
    PackRec^.PackOrig := BufferToLong(14);
    PackRec^.PackSize := BufferToLong(22);
    i := 1;
    While ((i < 14) And (PackRec^.Buffer^[i] <> 0)) Do
      Inc(i);
    PackRec^.PackName := BufferToStr(1,i - 1);
    PackRec^.PackOffset := PackRec^.PackOffset + 34;
    End;
  End;


Procedure PackFileObj.Arjview;
  Var
    BasicSize: Word;
    ExtSize: Word;
    i: Word;

  Begin
  If PackRec^.NumRead < 45 Then
    PackRec^.PackError := 18;
  If BufferToWord(1) = 60000 then
    Begin
    PackRec^.PackDate := BufferToLong(13);
    PackRec^.PackCRC := BufferToLong(25);
    PackRec^.PackOrig := BufferToLong(21);
    PackRec^.PackSize := BufferToLong(17);
    i := 35;
    While ((i < 48) And (PackRec^.Buffer^[i] <> 0)) Do
      Inc(i);
    PackRec^.PackName := BufferToStr(35,i - 35);
    BasicSize := BufferToWord(3) + 8;
    ExtSize := BufferToWord(BasicSize + 1);
    PackRec^.PackOffset := PackRec^.PackOffset + BasicSize + ExtSize + 2;
    If ExtSize > 0 Then
      Inc(PackRec^.PackOffset,4);
    Inc(PackRec^.PackOffset,PackRec^.PackSize);
    End
  Else
    PackRec^.PackError := 18;
  End;


Procedure PackFileObj.PackNext;
  Begin
  FileMode := fmReadOnly + fmDenyNone;
  If PackRec^.PackError = 0 Then
    If Not shReset(PackRec^.PackFile,1) Then
      PackRec^.PackError := 2;
  If PackRec^.PackError = 0 Then
    Begin
    Seek(PackRec^.PackFile,PackRec^.PackOffset);
    If IoResult <> 0 Then
      PackRec^.PackError := 2;
    End;
  If PackRec^.PackError = 0 Then
    If Not shRead(PackRec^.PackFile,PackRec^.Buffer^,SizeOf(PackRec^.Buffer^), PackRec^.NumRead) Then
      PackRec^.PackError := 2;
  If PackRec^.PackError = 0 Then
    Begin
    Case PackRec^.PackType of
      1: LzhView;
      2: ZipView;
      3: ArcView;
      4: ZooView;
      5: DWCView;
      6: ArjView;
      7: HypView;
      Else
        PackRec^.PackError := 3;
      End;
    End;
  If PackRec^.PackError = 0 Then
    Begin
    Close(PackRec^.PackFile);
    If IoResult <> 0 Then
      PackRec^.PackError := 2;
    End;
  End;


Procedure PackFileObj.PackFirst(PPath:String);
  Var
    BasicSize: Word;
    ExtSize: Word;

  Begin
  PackRec^.PackError := 0;
  If (Not shAssign(PackRec^.PackFile, PPath)) Then
    PackRec^.PackError := 2;
  FileMode := fmReadOnly + fmDenyNone;
  If PackRec^.PackError = 0 Then
    If Not shReset(PackRec^.PackFile,1) Then
      PackRec^.PackError := 2;
  If PackRec^.PackError = 0 Then
    If Not shRead(PackRec^.PackFile,PackRec^.Buffer^,SizeOf(PackBuffType), PackRec^.NumRead) Then
      PackRec^.PackError := 2;
  If PackRec^.PackError = 0 Then
    Begin
    If BufferToInt(3) = 27693 then
      Begin
      PackRec^.PackOffset := 0;     {LZH}
      PackRec^.PackType := 1;
      End
    Else
      case BufferToWord(1) of
        19280: Begin
               PackRec^.PackOffset:= 0;
               PackRec^.PackType:= 2;  {ZIP}
               End;
        20314: Begin
               PackRec^.PackOffset := BufferToLong(25); {ZOO}
               PackRec^.PackType := 4;
               End;
        60000: Begin
               BasicSize := BufferToWord(3) + 8;  {ARJ}
               ExtSize := BufferToWord(BasicSize + 1);
               PackRec^.PackOffset := BasicSize + ExtSize + 2;
               If ExtSize > 0 Then
                 Inc(PackRec^.PackOffset,4);
               PackRec^.PackType := 6;
               End;
      else
        if (PackRec^.Buffer^[1] = 26) then
          Begin
          If ((BufferToWord(2) = $5453) or (BufferToWord(2) = $5048)) Then
            Begin
            PackRec^.PackOffset := 0;  {HYP}
            PackRec^.PackType := 7;
            End
          Else
            Begin
            PackRec^.PackOffset := 0;   {ARC}
            PackRec^.PackType := 3;
            End;
          End
        else
          Begin
          Seek(PackRec^.PackFile,FileSize(PackRec^.PackFile) - 27);
          If IoResult <> 0 Then
            PackRec^.PackError := 2;
          If PackRec^.PackError = 0 Then
            If Not shRead(PackRec^.PackFile,PackRec^.Buffer^,27,PackRec^.NumRead) Then
              PackRec^.PackError := 2;
          If BufferToWord(25) =  $5744 Then
            Begin
            PackRec^.PackOffset := FileSize(PackRec^.PackFile) - 27 - (BufferToLong(21) * 34);
            PackRec^.PackType := 5;  {DWC}
            End
          Else
            Begin
            PackRec^.PackType := 0;  {Invalid type}
            PackRec^.PackError := 3;
            End;
          End;
        End;
    Close(PackRec^.PackFile);
    If IoResult <> 0 Then
      PackRec^.PackError := 2;
    End;
  If PackRec^.PackError = 0 then
    PackNext;
  End;


Function PackFileObj.Found: Boolean;
  Begin
  Found := (PackRec^.PackError = 0);
  End;


Function PackFileObj.GetPackType: Byte;
  Begin
  GetPackType := PackRec^.PackType;
  End;


Procedure GetPackPaths(Var Packers: PackInfoType);
  Begin
  Packers.UnPackLine[1] := ' e  -m ';
  Packers.UnPackLine[2] := ' -ed -o ';
  Packers.UnPackLine[3] := ' -r ';
  Packers.UnPackLine[4] := ' eoo ';
  Packers.UnPackLine[5] := ' e ';
  Packers.UnPackLine[6] := ' e -y ';
  Packers.UnPackLine[7] := ' -xo ';
  Packers.PackLine[1] := ' -m ';
  Packers.PackLine[2] := ' ';
  Packers.PackLine[3] := ' -a ';
  Packers.PackLine[4] := ' a ';
  Packers.PackLine[5] := ' a ';
  Packers.PackLine[6] := ' a -y ';
  Packers.PackLine[7] := ' -a ';
  Packers.UnPackPath[2] := FindPath('UNZIP.EXE');
  If Not FileExist(Packers.UnPackPath[2]) Then
    Packers.UnPackPath[2] := FindPath('PKUNZIP.EXE')
  Else
    Packers.UnPackLine[2] := ' -xjn ';
  Packers.PackPath[2] := FindPath('ZIP.EXE');
  If Not FileExist(Packers.PackPath[2]) Then
    Packers.PackPath[2] := FindPath('PKZIP.EXE')
  Else
    Packers.PackLine[2] := ' -j ';
  Packers.UnPackPath[3] := FindPath('PKUNPAK.EXE');
  If Not FileExist(Packers.UnPackPath[3]) Then
    Packers.UnPackPath[3] := FindPath('PKXARC.EXE');
  If Not FileExist(Packers.UnPackPath[3]) Then
    Packers.UnPackPath[3] := FindPath('ARC.EXE');
  Packers.PackPath[3] := FindPath('PKPAK.EXE');
  If Not FileExist(Packers.PackPath[3]) Then
    Packers.PackPath[3] := FindPath('PKARC.EXE');
  If Not FileExist(Packers.PackPath[3]) Then
    Packers.PackPath[3] := FindPath('ARCE.EXE');
  Packers.UnPackPath[1] := FindPath('LHA.EXE');
  If Not FileExist(Packers.UnPackPath[1]) Then
    Packers.UnPackPath[1] := FindPath('LHARC.EXE');
  Packers.PackPath[1] := Packers.UnPackPath[1];
  Packers.UnPackPath[5] := FindPath('DWC.EXE');
  Packers.PackPath[5] := Packers.UnPackPath[5];
  Packers.UnPackPath[6] := FindPath('ARJ.EXE');
  Packers.PackPath[6] := Packers.UnPackPath[6];
  Packers.UnPackPath[4] := FindPath('ZOO.EXE');
  Packers.PackPath[4] := Packers.UnPackPath[4];
  Packers.UnPackPath[7] := FindPath('HYPER.EXE');
  Packers.PackPath[7] := Packers.UnPackPath[7];
  End;


End.
