Unit MKLogEnt;
{$I MKB.Def}

Interface


Type LogRecType = Record
  LogName: String[80];
  LogStyle: Byte;
  PrnName: String[20];
  End;


Type LogObj = Object
  LI: ^LogRecType;
  Procedure Init; {initialize}
  Procedure Done; {done}
  Procedure WriteEntry(Entry: String); {Write entry to log file}
  Procedure BlankLine;
  Procedure SetPrnName(PN: String);
  End;


Var
  LogEntry: LogObj;
  LogNode: Word;

Implementation


Uses MKFile, MKString, MKCfgAbs, MKGlobT, MKDos,
  {$IFDEF WINDOWS}
  WinDos;
  {$ELSE}
  Dos;
  {$ENDIF}


Procedure LogObj.Init;
  Var
    TmpPath: String;
    Tmp: Word;

  Begin
  New(LI);
  TmpPath := GetCurrentPath;
  ChDir(StripTrail(StartUpPath, '\'));
  If IoResult <> 0 Then;
  LI^.LogName := FExpand(Config^.GetLogFileName);
  Tmp := Pos('*N', Upper(LI^.LogName));
  If Tmp > 0 Then
    Begin
    LI^.LogName := Copy(LI^.LogName, 1, Tmp - 1) + Long2Str(LogNode) +
      Copy(LI^.LogName, Tmp + 2, 255);
    End;
  LI^.PrnName := '';
  ChDir(StripTrail(TmpPath, '\'));
  If IoResult <> 0 Then;
  End;


Procedure LogObj.Done;
  Begin
  Dispose(LI);
  LI := Nil;
  End;


Procedure LogObj.WriteEntry(Entry: String);
  Var
    LogFile: File;
    LogStr: String;
    StrCnt: Word;
    PFile: Text;

  Begin
    FileMode := fmReadWrite + fmDenyNone;
    Assign(LogFile, LI^.LogName);
    If IoResult <> 0 Then;
    If FileExist(LI^.LogName) Then
      Begin
      If Not shReset(LogFile,1) Then;
      End
    Else
      Begin
      ReWrite(LogFile,1);
      If IoResult <> 0 Then;
      End;
    Seek(LogFile,FileSize(LogFile));
    If IoResult <> 0 Then;
    Case Config^.GetLogStyle of
      0: LogStr := FormattedDosDate(GetDosDate, '> dd-nnn ') +
          TimeStr(GetDosDate) + ' MKMK ';
      1: LogStr := '> ' + TimeStr(GetDosDate) + ' ';
      2: LogStr := FormattedDosDate(GetDosDate,'dd-nnn-yy ')+
         Copy(TimeStr(GetDosDate),1,5) + ' ';
      3: LogStr := 'Future MK use ';
      Else LogStr := 'Undefined Style ';
      End;
    LogStr := LogStr + Entry +#13 + #10;
    BlockWrite(LogFile, LogStr[1], Length(LogStr));
    If IoResult <> 0 Then;
    Close(LogFile);
    If IoResult <> 0 Then;
    If Length(LI^.PrnName) > 0 Then
      Begin
      Assign(PFile, LI^.PrnName);
      Append(PFile);
      If IoResult <> 0 Then;
      Write(PFile, LogStr);
      If IoResult <> 0 Then;
      Close(PFile);
      If IoResult <> 0 Then;
      End;
  End;


Procedure LogObj.SetPrnName(PN: String);
  Begin
  LI^.PrnName := PN;
  End;


Procedure LogObj.BlankLine;
  Var
    LogFile: File;
    LogStr: String;

  Begin
    FileMode := fmReadWrite + fmDenyNone;
    Assign(LogFile, LI^.LogName);
    If IoResult <> 0 Then;
    If FileExist(LI^.LogName) Then
      Begin
      If Not shReset(LogFile,1) Then;
      End
    Else
      Begin
      ReWrite(LogFile,1);
      If IoResult <> 0 Then;
      End;
    Seek(LogFile,FileSize(LogFile));
    If IoResult <> 0 Then;
    LogStr := #13 + #10;
    BlockWrite(LogFile, LogStr[1], Length(LogStr));
    If IoResult <> 0 Then;
    Close(LogFile);
    If IoResult <> 0 Then;
  End;


Begin
LogNode := 1;
End.
