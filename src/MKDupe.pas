Unit MKDupe;
{$I MKB.Def}

Interface

{
     MKDupe - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}



Uses Dos, MKFile, MKString;


Const
  DupeCheckRange = 20;


Type DupeRec = Record
  Date: LongInt;
  Crc: LongInt;
  End;

Type DupeInfo = Record
  Name: String;
  DupeSize: LongInt;
  Error: Word;
  DateMin: LongInt;
  TodayLong: LongInt;
  DFile: File;
  DA: Array[1..DupeCheckRange] Of DupeRec;
  End;


Type DupeObj = Object
  DI: ^DupeInfo;
  Procedure Init;                                {Init}
  Procedure Open(Name: String; DupeSize: LongInt); {Open/Initialize}
  Procedure CloseFile;                           {Close dupe file}
  Procedure SetDays(Days: Word);                 {Set days to use}
  Function  DupeCheck(Value: LongInt): Boolean;  {Check value}
  Function  NumDays(Month: LongInt; Year: LongInt): LongInt; {Internal}
  Function  GetStartDate: LongInt;
  Procedure Done;                                {Done}
  End;


Implementation


Procedure DupeObj.Init;
  Begin
  New(DI);
  End;


Procedure DupeObj.Done;
  Begin
  Dispose(DI);
  End;


Function DupeObj.NumDays(Month: LongInt; Year: LongInt): LongInt;
  Begin
  Case Month of
     1: NumDays := 31;
     2: If ((Year and 3) = 0) Then
          NumDays := 29
        Else
          NumDays := 28;
     3: NumDays := 31;
     4: NumDays := 30;
     5: NumDays := 31;
     6: NumDays := 30;
     7: NumDays := 31;
     8: NumDays := 31;
     9: NumDays := 30;
    10: NumDays := 31;
    11: NumDays := 30;
    12: NumDays := 31;
    Else
      NumDays := 31;
    End;
  End;


Procedure DupeObj.SetDays(Days: Word);
  Var
    Year: LongInt;
    Month: LongInt;
    Day: LongInt;
    TmpDOW: Word;
    TmpMonth: Word;
    TmpDay: Word;
    TmpYear: Word;

  Begin
  GetDate(TmpYear,TmpMonth,TmpDay,TmpDOW);
  Year := TmpYear;
  Month := TmpMonth;
  Day := TmpDay;
  DI^.TodayLong := (Year shl 16) + (Month shl 8) + Day;
  Dec(Day, Days);
  While Day < 1 Do
    Begin
    Dec(Month);
    If (Month < 1) Then
      Begin
      Dec(Year);
      Inc(Month,12);
      End;
    Inc(Day,NumDays(Month, Year));
    End;
  DI^.DateMin := (Year shl 16) + (Month shl 8) + Day;
  End;


Function DupeObj.GetStartDate: LongInt;
  Begin
  GetStartDate := DI^.DateMin;
  End;


Function DupeObj.DupeCheck(Value: LongInt): Boolean;

   Var
     Dupe: Boolean;
     DupeRead: Word;
     Spos: LongInt;
     CheckCnt: Word;
     NonDupeStore: Word;

   Begin
   Spos := Abs(Value Mod (DI^.DupeSize));
   shLock(DI^.DFile, 1, 1);
   Seek(DI^.DFile, Spos * SizeOf(DupeRec));
   shRead(DI^.DFile, DI^.DA, SizeOf(DI^.DA), DupeRead);
   DupeRead := DupeRead Div SizeOf(DupeRec);
   CheckCnt := 1;
   Dupe := False;
   NonDupeStore := 1;
   While ( (CheckCnt <= DupeCheckRange) and (Not Dupe)
   And (CheckCnt <= DupeRead)) Do
     Begin
     If DI^.DA[CheckCnt].Date < DI^.DateMin Then
       NonDupeStore := CheckCnt;
     Dupe := ((DI^.DA[CheckCnt].Crc = Value) and (DI^.DA[CheckCnt].Date > DI^.DateMin));
     If Not Dupe Then
       Inc(CheckCnt);
     End;
   DI^.DA[NonDupeStore].Crc := Value;
   DI^.DA[NonDupeStore].Date := DI^.TodayLong;
   If IoResult <> 0 Then
     Write(#7, #7);
   Seek(DI^.DFile, Spos * SizeOf(DupeRec));
   If IoResult <> 0 Then
     Write(#7, #7);
   shWrite(DI^.DFile, DI^.DA, SizeOf(Di^.Da));
   UnLockFile(DI^.DFile, 1, 1);
   DupeCheck := Dupe;
   End;


Procedure DupeObj.Open(Name: String; DupeSize: LongInt); {Open/Initialize}
Type
  DupeInitArray = Array[1..2000] of DupeRec;

Var
  TempCnt: LongInt;
  DupeIPtr: ^DupeInitArray;

  Begin
  New(DupeIPtr);
  DI^.DupeSize := DupeSize;
  If FileExist(Name) Then
    Begin
    Assign(DI^.DFile, Name);
    FileMode := fmReadWrite or fmDenyNone;
    shReset(DI^.DFile, 1);
    End
  Else
    Begin
    For TempCnt := 1 to 2000 Do
      Begin
      DupeIPtr^[TempCnt].Date := 0;
      DupeIPtr^[TempCnt].Crc := 0;
      End;
    Assign(DI^.DFile, Name);
    ReWrite(DI^.DFile, 1);
    TempCnt := DI^.DupeSize;
    While TempCnt > 0 Do
      Begin
      If TempCnt > 2000 Then
        Begin
        shWrite(DI^.DFile, DupeIPtr^, SizeOf(DupeIPtr^));
        Dec(TempCnt, 2000);
        End
      Else
        Begin
        shWrite(DI^.DFile, DupeIPtr^, SizeOf(DupeRec) * TempCnt);
        TempCnt := 0;
        End;
      End;
    End;
  Dispose(DupeIPtr);
  End;


Procedure DupeObj.CloseFile;
  Begin
  If IoResult <> 0 Then;
  Close(DI^.DFile);
  If IoResult <> 0 Then;
  End;


End.
