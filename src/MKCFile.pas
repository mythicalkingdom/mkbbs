{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKCFile;

{$I MKB.Def}

Interface

Uses MKGlobT;


Type ListInfoRec = Record
  LName: String[15];
  LDate: LongInt;
  LSize: LongInt;
  LDesc: String;
  TempLine: String;
  End;


Type ListFileObj = Object
  ListInfo: ^ListInfoRec;
  Procedure Init;
  Procedure Done;
  Procedure ShowFile;
  Procedure SetName(Name: String);
  Procedure SetSize(Size: LongInt);
  Procedure SetDate(Date: LongInt);
  Procedure SetDesc(Desc: String);
  End;


Procedure DisplayStopMsg;
Procedure DoNewFiles(Var Sec: SecType);
Procedure DoPackView(Var Sec: SecType);
Procedure DoFileList(PathStr: String; ListName: String);   {ListName: the file with the list ('' = files.bbs in the path); files.bbs and PCBoard DIR lines are both read}
Procedure DoDirList(PathStr: String);
Function  GetProtocol(Special: Boolean): Word;
Function  GetPacker: Word;
Procedure DoTextSearch(Var Sec: SecType);
Procedure DisplayDirFile(DF: String);
Procedure ViewContents(FP: String; Name: String);

Var
  ListFile: ListFileObj;

Implementation

Uses
  MKDoor, MKCfgAbs, MKString, MKBFile, MKPack, MKFile, MKComAbs, MKDos, MKFileList,
  Dos;


Procedure DisplayStopMsg;
  Begin
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(111));
  End;


Procedure ListFileObj.Init;
  Begin
  New(ListInfo);
  End;


Procedure ListFileObj.SetName(Name: String);
  Begin
  ListInfo^.LName := Copy(Name,1,13);
  End;


Procedure ListFileObj.SetSize(Size: LongInt);
  Begin
  ListInfo^.LSize := Size;
  End;


Procedure ListFileObj.SetDate(Date: LongInt);
  Begin
  ListInfo^.LDate := Date;
  End;


Procedure ListFileObj.SetDesc(Desc: String);
  Begin
  ListInfo^.LDesc := Desc;
  End;


Procedure ListFileObj.Done;
  Begin
  Dispose(ListInfo);
  End;


Procedure ListFileObj.ShowFile;
  Const
    StLen = 78;

  Begin
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStr(PadRight(ListInfo^.LName, ' ',13));
  User.DisplayAttr(Config^.GetSystemColor(3));
  If (ListInfo^.LSize < 0) Then
    User.DisplayStr(Copy(PadRight(Prompts.GetString(107),' ',19),1,19))
  Else
    Begin
    User.DisplayStr(FormattedDosDate(ListInfo^.LDate, Prompts.GetString(058)));
    User.DisplayAttr(Config^.GetSystemColor(4));
    User.DisplayStr(PadLeft(CommaStr(ListInfo^.LSize),' ', 10) + ' ');
    End;
  User.DisplayAttr(Config^.GetSystemColor(5));
  ListInfo^.TempLine := WWrap(ListInfo^.LDesc, StLen - 32);
  User.DisplayStrLn(ListInfo^.TempLine);
  While ((Length(ExtraString) > 0) And (Not User.StopMore) And (User.Ok)) Do
    Begin
    ListInfo^.TempLine := WWrap('                                ' + ExtraString, 78);
    User.DisplayStrLn(ListInfo^.TempLine);
    User.CheckInput;
    End;
  End;


Procedure DoNewFiles(Var Sec: SecType);
  Var
    DT: DateTime;
    NewArea: Word;
    NumNew: LongInt;
    SizeNew: LongInt;
    LastDate: LongInt;
    TempLine: String;
    TC: Char;
    DOW: Word;


  Const
    StLen = 78;

  Begin
  ListFile.Init;
  NewArea := 0;
  NumNew := 0;
  SizeNew := 0;
  User.SetMore(True);
  User.GetUserNewFileDate(DT);
  If DT.Year < 100 Then
    Begin
    If DT.Year < 80 Then
      Inc(DT.Year, 2000)
    Else
      Inc(DT.Year, 1900);
    End;
  User.DisplayNewLine;
  User.ClearScreen;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(31));          { new since }
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayChr(' ');
  User.DisplayStr(Prompts.GetString(12));   { ( }
  User.DisplayStr(Prompts.GetString(005));         { enter = }
  User.DisplayChr(' ');
  User.DisplayStr(FormattedDate(DT, Prompts.GetString(58)));
  User.DisplayStr(Prompts.GetString(13));   { ) }
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayChr(' ');
  If User.AskDate(DT) Then;
  If DT.Year < 100 Then
    Begin
    If DT.Year < 80 Then
      Inc(DT.Year, 2000)
    Else
      Inc(DT.Year, 1900);
    End;
  DT.Hour := 0;
  DT.Min := 0;
  DT.Sec := 0;
  User.DisplayNewLine;
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(30));
  User.DisplayChr(' ');
  User.DisplayAttr(Config^.GetSystemColor(3));
  User.DisplayStrLn(FormattedDate(DT, Prompts.GetString(58)));
  PackTime(DT, LastDate);
  User.DisplayAttr(Config^.GetSystemColor(1));
  DisplayStopMsg;
  NewF.NewFileInit;
  NewF.NewFileFirst(Sec, LastDate);
  While ((NewF.NewFileFound) and (User.Ok) and (Not User.StopMore)) Do
    Begin
    If NewF.NewFileGetArea <> NewArea Then
      Begin
      NewArea := NewF.NewFileGetArea;
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStrLn(Config^.GetFileAreaName(NewArea));
      End;
    Inc(NumNew);
    Inc(SizeNew, NewF.NewFileGetSize);
    User.DisplayAttr(Config^.GetSystemColor(2));
    ListFile.SetName(NewF.NewFileGetName);
    ListFile.SetSize(NewF.NewFileGetSize);
    ListFile.SetDate(NewF.NewFileGetDate);
    ListFile.SetDesc(NewF.NewFileGetDesc);
    ListFile.ShowFile;
    If  User.CheckHot(' ') = ' ' Then
      Begin
      User.SetStopMore(True);
      CommFlushOut;
      End;
    If ((User.Ok) and (Not User.StopMore)) Then
      NewF.NewFileNext;
    User.CheckInput;
    End;
  NewF.NewFileDone;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  User.DisplayStrLn(CommaStr(NumNew) + ' New Files containing ' +
    CommaStr(SizeNew) + ' Bytes');
  User.ResetLines(1);
  User.DisplayNewLine;
  User.PressEnter;
  ListFile.Done;
  GetDate(DT.Year, DT.Month, DT.Day, DOW);
  DT.Hour := 0;
  DT.Min := 0;
  DT.Sec := 0;
  User.SetUserNewFileDate(DT);
  End;



Procedure ViewContents(FP: String; Name: String);
  Var
    Pack: PackFileObj;
    ContentFiles: Word;
    ContentSize: LongInt;
    ContentComp: LongInt;


  Const
    HdrStr = '-------------   ---------   ---------   --------   --------   --------';

  Begin
  ContentFiles := 0;
  ContentSize := 0;
  ContentComp := 0;
  Pack.Init;
  User.DisplayAttr(Config^.GetSystemColor(1));
  Pack.PackFirst(FP);
  If Pack.Found Then
    Begin
    Case Pack.GetPackType Of
      1: User.DisplayStr('LZH');
      2: User.DisplayStr('ZIP');
      3: User.DisplayStr('ARC');
      4: User.DisplayStr('ZOO');
      5: User.DisplayStr('DWC');
      6: User.DisplayStr('ARJ');
      7: User.DisplayStr('HYP');
      End;
    User.DisplayStrLn(' ' + Prompts.GetString(101) + ' ' + Name);
    User.DisplayNewLine;
    User.DisplayStr(Copy(PadRight(Prompts.GetString(140),' ',16),1,16));
    User.DisplayStr(Copy(PadRight(Prompts.GetString(141),' ',12),1,12));
    User.DisplayStr(Copy(PadRight(Prompts.GetString(142),' ',12),1,12));
    User.DisplayStr(Copy(PadRight(Prompts.GetString(143),' ',11),1,11));
    User.DisplayStr(Copy(PadRight(Prompts.GetString(102),' ',11),1,11));
    User.DisplayStrLn(Copy(Prompts.GetString(103),1,6));
    User.DisplayStrLn(HdrStr);
    End;
  While ((Pack.Found) and (User.Ok) and (Not User.StopMore)) Do
    Begin
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(PadRight(Pack.GetName,' ',13));
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStr(PadLeft(CommaStr(Pack.GetOSize),' ',12));
    User.DisplayStr(PadLeft(CommaStr(Pack.GetCSize),' ',12));
    User.DisplayAttr(Config^.GetSystemColor(4));
    User.DisplayStr('   ' + FormattedDosDate(Pack.GetDate, Prompts.GetString(058)));
    User.DisplayStr('   ' + TimeStr(Pack.GetDate));
    User.DisplayAttr(Config^.GetSystemColor(5));
    User.DisplayStrLn('   '  + HexLong(Pack.GetCrc));
    Inc(ContentFiles);
    Inc(ContentSize, Pack.GetOSize);
    Inc(ContentComp, Pack.GetCSize);
    Pack.PackNext;
    If User.CheckHot(' ') = ' ' Then
      Begin
      User.SetStopMore(True);
      CommFlushOut;
      End;
    User.CheckInput;
    End;
  Pack.Done;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(HdrStr);
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(PadRight(Long2Str(ContentFiles) + ' ' + Prompts.GetString(291), ' ', 15));
  User.DisplayStrLn(' ' + PadLeft(CommaStr(ContentSize),' ', 9) +
  '   ' + PadLeft(CommaStr(ContentComp), ' ', 9));
  User.DisplayNewLine;
  End;




Procedure DoPackView(Var Sec: SecType);
  Var
    FS: FileSearchObj;
    ViewDone: Boolean;
    Valid: Boolean;
    TmpStr: String;
    WordCnt: Word;
    CurrWord: Word;
    CurrStr: String;

  Begin
  User.SetMore(True);
  User.DisplayNewLine;
  User.ClearScreen;
  FS.Init;
  ViewDone := False;
  While ((Not ViewDone) and (User.Ok)) Do
    Begin
    Valid := False;
    While ((Not Valid) and (User.Ok)) Do
      Begin
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayNewLine;
      User.DisplayStr(Prompts.GetString(125));
      User.DisplayChr(' ');
      TmpStr := '';
      TmpStr := User.InputStr(TmpStr,50);
      User.DisplayNewLine;
      If TmpStr = '' Then
        Begin
        ViewDone := True;
        Valid := True;
        End
      Else
        Begin
        Valid := True;
        If Pos('..',TmpStr) > 0 Then
          Valid := False;
        If (Pos('\', TmpStr) > 0) Or (Pos('/', TmpStr) > 0) Then
          Valid := False;
        If IsDevice(TmpStr) Then
          Valid := False;
        End;
      If Not Valid Then
        User.DisplayStrLn(Prompts.GetString(259));
      End;
    WordCnt := WordCount(TmpStr);
    CurrWord := 1;
    User.SetMore(True);
    User.ResetLines(1);
    User.SetStopMore(False);
    While ((CurrWord <= WordCnt) and (User.Ok) And (Not User.StopMore)) Do
      Begin
      CurrStr := Copy(ExtractWord(TmpStr, CurrWord), 1, 13);
      If ((Pos('.',CurrStr) = 0) And (Length(CurrStr) < 9)) Then
        CurrStr := CurrStr + '.*';
      FS.FileFirst(Sec, CurrStr, 1);
      If Not FS.FileFound Then
        Begin
        User.DisplayNewLine;
        User.DisplayStrLn(CurrStr + ' ' + Prompts.GetString(114));
        End;
      While ((FS.FileFound) and (User.Ok) and (Not User.StopMore)) Do
        Begin
        User.DisplayNewLine;
        ViewContents(Config^.GetFileAreaPath(FS.GetArea) + FS.GetName, FS.GetName);
        FS.FileNext;
        End;
      Inc(CurrWord);
      End;
    User.CheckInput;
    End;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  User.ResetLines(1);
  FS.Done;
  End;


Function FixDirPath(P: String): String;
  {A directory from a menu item or the configuration: the slashes are those of this system, the letters are taken as written}
  Var
    i: Word;

  Begin
  For i := 1 To Length(P) Do
    If P[i] = '\' Then
      P[i] := '/';
  FixDirPath := P;
  End;


Procedure DoDirList(PathStr: String);
  Var
    SR2: SearchRec;
    FileSpec: String[13];
    SpecValid: Boolean;
    TC: Char;

  Begin
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  SpecValid := False;
  While ((Not SpecValid) and (User.OK)) Do
    Begin
    User.DisplayStr(Prompts.GetString(197) + ' ');
    FileSpec := User.InputStr('',12);
    User.DisplayNewLine;
    SpecValid := True;
    If Length(FileSpec) = 0 Then
      FileSpec := '*.*'
    Else
      Begin
      If Pos(':', FileSpec) > 0 Then
        SpecValid := False;
      If (Pos('\', FileSpec) > 0) Or (Pos('/', FileSpec) > 0) Then
        SpecValid := False;
      If Pos('..', FileSpec) > 0 Then
        SpecValid := False;
      If Not SpecValid Then
        User.DisplayStrLn(Prompts.GetString(198));
      End;
    User.CheckInput;
    End;
  User.SetMore(True);
  PathStr := FixDirPath(PathStr);
  AddBackSlash(PathStr);
  User.SetStopMore(False);
  FindFirst(PathStr + FileSpec, Archive + ReadOnly, SR2);
  While ((DosError = 0) And (User.Ok) And (Not User.StopMore)) Do
    Begin
    User.DisplayStr(PadRight(SR2.Name, ' ', 17));
    User.DisplayStr(PadLeft(CommaStr(SR2.Size), ' ', 11));
    User.DisplayStr('    ' + FormattedDosDate(SR2.Time, Prompts.GetString(058)) + '  ');
    User.DisplayStr(TimeStr(SR2.Time));
    User.DisplayNewLine;
    If  User.CheckHot(' ') = ' ' Then
      Begin
      User.SetStopMore(True);
      CommFlushOut;
      End;
    FindNext(SR2);
    User.CheckInput;
    End;
  User.PressEnter;
  End;



Procedure DoFileList(PathStr: String; ListName: String);
  Const MaxFiles = 800;

  Type DirRec = Record
    Name: String[12];
    Date: LongInt;
    Size: LongInt;
    End;

  Type DirRecArray = Array[1..MaxFiles] of DirRec;

  Var
    TF: TFile;
    TmpStr: String;
    FileName: String[13];
    FilesThisArea: LongInt;
    TC: Char;
    DR: ^DirRecArray;
    j: LongInt;
    Match: Boolean;
    SR2: SearchRec;
    ListPath, PName, PDesc, PText: String;
    PSize, PTime: LongInt;
    InF: Text;
    IncLine: String;
    LastFile, PcbMode: Boolean;

  Begin
  ListFile.Init;
  New(DR);
  LastFile := False;
  User.SetMore(True);
  User.ResetLines(1);
  User.DisplayNewLine;
  TF.Init;
  PathStr := FixDirPath(PathStr);
  AddBackSlash(PathStr);
  ListPath := PathStr + 'files.bbs';
  If ListName <> '' Then
    Begin
    If Pos('/', ListName) > 0 Then
      ListPath := ListName
    Else
      ListPath := PathStr + ListName;
    End
  Else If Not FileExist(ListPath) Then
    If FindDirFile(PathStr, '') <> '' Then          {no files.bbs: a PCBoard DIR file of the folder}
      ListPath := FindDirFile(PathStr, '');
  PcbMode := False;
  If FileExist(ListPath) Then
    Begin
    Assign(InF, ListPath);               {a PCBoard DIR file has primary lines: then the other lines are text}
    {$I-} Reset(InF); {$I+}
    If IoResult = 0 Then
      Begin
      While (Not Eof(InF)) And (Not PcbMode) Do
        Begin
        ReadLn(InF, IncLine);
        If PcbPrimary(IncLine, PName, PSize, PTime, PDesc) Then
          PcbMode := True;
        End;
      Close(InF);
      End;
    If TF.OpenTextFile(ListPath) Then
      Begin
      DisplayStopMsg;
      FilesThisArea := 0;
      FindFirst(PathStr + '*.*', Archive + ReadOnly, SR2);
      If IoResult <> 0 Then;
      While ((DosError = 0) and (FilesThisArea < MaxFiles)) Do
        Begin
        Inc(FilesThisArea);
        DR^[FilesThisArea].Name := SR2.Name;
        DR^[FilesThisArea].Date := SR2.Time;
        DR^[FilesThisArea].Size := SR2.Size;
        FindNext(SR2);
        If IoResult <> 0 Then;
        End;
      TmpStr := TF.GetString;
      While ((TF.StringFound) and (User.Ok) and (Not User.StopMore)) Do
        Begin
        If User.CheckHot(' ') = ' ' Then
          Begin
          User.SetStopMore(True);
          CommFlushOut;
          End;
        If (Length(TmpStr) > 0) And (TmpStr[1] = '%') Then
          Begin                                   {PCBoard: a file to show here}
          Assign(InF, FixDirPath(Copy(TmpStr, 2, 250)));
          {$I-} Reset(InF); {$I+}
          If IoResult = 0 Then
            Begin
            While (Not Eof(InF)) And (User.Ok) And (Not User.StopMore) Do
              Begin
              ReadLn(InF, IncLine);
              User.DisplayStrLn(PcbStripCodes(IncLine));
              End;
            Close(InF);
            End;
          LastFile := False;
          End
        Else If PcbPrimary(TmpStr, PName, PSize, PTime, PDesc) Then
          Begin                                   {PCBoard DIR line: name, size, date, description}
          ListFile.SetName(PName);
          ListFile.SetSize(PSize);
          ListFile.SetDate(PTime);
          ListFile.SetDesc(PcbStripCodes(PDesc));
          ListFile.ShowFile;
          LastFile := True;
          End
        Else If LastFile And PcbSecondary(TmpStr, PText) Then
          User.DisplayStrLn(PcbStripCodes(PText))
        Else If PcbMode Or ((TmpStr[1] <= '/') Or (TmpStr[1] = ';') Or (Length(TmpStr) = 0) Or
        (TmpStr[1] > #127) or (TmpStr[1] <= ' ')) Then
          Begin
          User.DisplayStrLn(PcbStripCodes(TmpStr));
          If Length(TmpStr) = 0 Then
            LastFile := False;
          End
        Else
          Begin
          FileName := Copy(ExtractWord(TmpStr,1),1,13);
          J := 0;
          Match := False;
          While ((j < FilesThisArea) and (Not Match)) Do
            Begin
            Inc(j);
            If (FileName = DR^[j].Name) Then
              Match := True;
            End;
          If Match Then
            Begin
            ListFile.SetName(DR^[j].Name);
            ListFile.SetSize(DR^[j].Size);
            ListFile.SetDate(DR^[j].Date);
            ListFile.SetDesc(StripLead(Copy(TmpStr, Length(FileName) + 2, 255), ' '));
            ListFile.ShowFile;
            End
          Else
            Begin
            ListFile.SetName(FileName);
            ListFile.SetSize(-1);
            ListFile.SetDate(-1);
            ListFile.SetDesc(Copy(TmpStr, Length(FileName) + 1, 255));
            ListFile.ShowFile;
            End;
          End;
        TmpStr := TF.GetString;
        User.CheckInput;
        End;
      If TF.CloseTextFile Then;
      End
    Else
      User.DisplayStrLn('Unable to open the list file');
    End
  Else
    Begin
    User.DisplayStrLn('Missing the list file');
    User.DisplayStrLn(ListPath);
    End;
  TF.Done;
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.PressEnter;
  Dispose(DR);
  ListFile.Done;
  End;


Procedure OneFileLine(TmpStr: String; FPath: String);
  Var
    FileName: String[15];
    FF: FindObj;
    LF: ListFileObj;

  Begin
  AddBackSlash(FPath);
  FF.Init;
  LF.Init;
  TmpStr := StripBoth(TmpStr, ' ');
  FileName := Copy(ExtractWord(TmpStr,1),1,13);
  FF.FFirst(FPath + FileName);
  While ((FF.Found) and (User.OK)) Do
    Begin
    LF.SetName(FF.GetName);
    LF.SetSize(FF.GetSize);
    LF.SetDate(FF.GetDate);
    LF.SetDesc(StripLead(Copy(TmpStr, Length(FileName) + 2, 255), ' '));
    LF.ShowFile;
    FF.FNext;
    User.CheckInput;
    End;
  LF.Done;
  FF.Done;
  End;


Procedure DoTextSearch(Var Sec: SecType);
  Var
  SearchDone: Boolean;
  SearchText: String;
  SearchArea: Word;
  TF: TFile;
  TextStr: String;
  HeaderArea: Word;

  Begin
  HeaderArea := 0;
  User.SetMore(True);
  User.SetStopMore(False);
  User.ClearScreen;
  SearchDone := False;
  SearchText := '';
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(145));
  User.DisplayStr(Prompts.GetString(14));
  User.DisplayChr(' ');
  SearchText := User.InputStr('', 20);
  SearchText := Upper(StripBoth(SearchText, ' '));
  User.DisplayNewLine;
  If SearchText = '' Then
    SearchDone := True;
  SearchArea := 0;
  While ((Not SearchDone) and (User.Ok) and (Not User.StopMore)) Do
    Begin
    While ((Not Config^.FileViewAccess(SearchArea, Sec) and
    (SearchArea < Config^.GetMaxFileAreas))) Do
      Inc(SearchArea);
    If SearchArea > Config^.GetMaxFileAreas Then
      SearchDone := True;
    If (Config^.FileViewAccess(SearchArea, Sec) And
    (Length(Config^.GetFileAreaName(SearchArea)) > 0)) Then
      Begin
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayChr(#13);
      User.DisplayStr((Long2Str(SearchArea) + ' '));
      TF.Init;
      If FileExist(Config^.GetFileListPath(SearchArea)) Then
        Begin
        If TF.OpenTextFile(Config^.GetFileListPath(SearchArea)) Then
          Begin
          TextStr := StripBoth(TF.GetString, ' ');
          While ((Not User.StopMore) and (TF.StringFound) and (User.Ok)) Do
            Begin
            If ((Pos(SearchText, Upper(TextStr)) > 0) And
            (TextStr[1] > ' ') and (TextStr[1] < #128)) Then
              Begin
              If HeaderArea <> SearchArea Then
                Begin
                HeaderArea := SearchArea;
                User.DisplayAttr(Config^.GetSystemColor(1));
                User.DisplayStrLn(Config^.GetFileAreaName(SearchArea));
                End;
              OneFileLine(TextStr, Config^.GetFileAreaPath(SearchArea));
              End;
            TextStr := StripBoth(TF.GetString, ' ');
            If  User.CheckHot(' ') = ' ' Then
              Begin
              User.SetStopMore(True);
              CommFlushOut;
              End;
            End;
          If Not TF.CloseTextFile Then;
          If HeaderArea = SearchArea Then
            User.DisplayNewLine;
          End;
        End;
      TF.Done;
      End;
    If  User.CheckHot(' ') = ' ' Then
      Begin
      User.SetStopMore(True);
      CommFlushOut;
      End;
    Inc(SearchArea);
    User.CheckInput;
    End;
  If HeaderArea = 0 Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(Prompts.GetString(263));
    End;
  User.DisplayNewLine;
  User.PressEnter;
  End;


Function  GetProtocol(Special: Boolean): Word;
  Var
    TmpChr: Char;
    HotStr: String;
    i: Word;
    Finished: Boolean;

  Begin
  GetProtocol := 0;
  HotStr := '';
  User.DisplayNewLine;
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(261));
  User.DisplayNewLine;
  For i := 1 to 20 Do
    Begin
    If ((Special and Config^.GetProtSpecAvail(i)) or
    (Not Special and Config^.GetProtNormAvail(i))) Then
      Begin
      User.DisplayAttr(Config^.GetSystemColor(2));
      User.DisplayStr(Prompts.GetString(12));
      User.DisplayAttr(Config^.GetSystemColor(3));
      User.DisplayChr(Config^.GetProtChar(i));
      User.DisplayAttr(Config^.GetSystemColor(2));
      User.DisplayStr(Prompts.GetString(13) + ' ');
      User.DisplayAttr(Config^.GetSystemColor(4));
      User.DisplayStr(Config^.GetProtName(i));
      User.DisplayNewLine;
      HotStr := HotStr + Config^.GetProtChar(i);
      End;
    End;
  HotStr := HotStr + #13;
  User.ResetLines(1);
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(122) + ' ' + Prompts.GetString(14) + ' ');
  TmpChr := User.AskChoice(HotStr);
  User.DisplayChr(TmpChr);
  If TmpChr = #13 Then
    GetProtocol := 0
  Else
    Begin
    i := 1;
    Finished := False;
    While Not Finished Do
      Begin
      If Special Then
        Begin
        If ((TmpChr = Config^.GetProtChar(i)) And (Config^.GetProtSpecAvail(i))) Then
          Begin
          Finished := True;
          GetProtocol := i;
          End;
        End
      Else
        Begin                                   {(the else of the line above was taken for the else of the inner if: an upload, which is not Special, never found its protocol)}
        If ((TmpChr = Config^.GetProtChar(i)) And (Config^.GetProtNormAvail(i))) Then
          Begin
          Finished := True;
          GetProtocol := i;
          End;
        End;
      Inc(i);
      If i > 20 Then
        Finished := True;
      End;
    End;
  User.DisplayNewLine;
  End;


Function  GetPacker: Word;
  Var
    TmpChr: Char;
    HotStr: String;
    i: Word;
    Finished: Boolean;

  Const MaxPackers = 6;

  Begin
  GetPacker := 0;
  HotStr := '';
  User.DisplayNewLine;
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(343));
  User.DisplayNewLine;
  For i := 1 to MaxPackers Do
    Begin
    If Config^.GetPackAvail(i) Then
      Begin
      User.DisplayAttr(Config^.GetSystemColor(2));
      User.DisplayStr(Prompts.GetString(12));
      User.DisplayAttr(Config^.GetSystemColor(3));
      User.DisplayChr(Config^.GetPackChar(i));
      User.DisplayAttr(Config^.GetSystemColor(2));
      User.DisplayStr(Prompts.GetString(13) + ' ');
      User.DisplayAttr(Config^.GetSystemColor(4));
      User.DisplayStr(Config^.GetPackName(i));
      User.DisplayNewLine;
      HotStr := HotStr + Config^.GetPackChar(i);
      End
    Else
      HotStr := HotStr + #255;
    End;
  HotStr := HotStr + #13;
  User.ResetLines(1);
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(160) + ' ' + Prompts.GetString(14) + ' ');
  TmpChr := UpCase(User.AskChoice(HotStr));
  User.DisplayChr(TmpChr);
  If ((TmpChr = #13) or (TmpChr = #255)) Then
    GetPacker := 0
  Else
    GetPacker := Pos(TmpChr, HotStr);
  User.DisplayNewLine;
  End;


Function DeComma(St: String): String;
  Var
    i: Word;
    o: Word;
    OStr: String;

  Begin
  o := 0;
  For i := 1 to Length(St) Do
    Begin
    If St[i] <> ',' Then
      Begin
      Inc(o);
      OStr[o] := St[i];
      End;
    End;
  OStr[0] := Chr(o);
  DeComma := OStr;
  End;


Procedure DisplayDirFile(DF: String);
  Var
    TF: TFile;
    TmpStr: String;
    TmpLong: LongInt;

  Begin
  User.SetMore(True);
  User.SetStopMore(False);
  If FileExist(DF) Then
    Begin
    TF.Init;
    If TF.OpenTextFile(DF) Then
      Begin
      DisplayStopMsg;
      TmpStr := StripTrail(TF.GetString, ' ');
      While ((Not User.StopMore) and (TF.StringFound) and (User.Ok)) Do
        Begin
        If User.CheckHot(' ') = ' ' Then
          Begin
          User.SetStopMore(True);
          CommFlushOut;
          End;
        If ((TmpStr[1] <= '/') Or (TmpStr[1] = ';') Or (Length(TmpStr) = 0) Or
        (TmpStr[1] > #127) or (TmpStr[1] <= ' ')) Then
          Begin
          User.DisplayAttr(Config^.GetSystemColor(5));
          User.DisplayStrLn(TmpStr);
          End
        Else
          Begin
          User.DisplayAttr(Config^.GetSystemColor(2));
          User.DisplayStr(PadRight(Copy(TmpStr,1,12), ' ',13));
          User.DisplayAttr(Config^.GetSystemColor(3));
          User.DisplayStr(ReformatDate(Copy(TmpStr,24,8),
            Prompts.GetString(58)));
          User.DisplayAttr(Config^.GetSystemColor(4));
          TmpLong := Str2Long(DeComma(StripBoth(Copy(TmpStr,13,9),' ')));
          User.DisplayStr(PadLeft(CommaStr(TmpLong),' ', 10) + ' ');
          User.DisplayAttr(Config^.GetSystemColor(5));
          User.DisplayStrLn(Copy(TmpStr,33,46));
          End;
        TmpStr := StripTrail(TF.GetString, ' ');
        End;
      If TF.CloseTextFile Then;
      End;
    TF.Done;
    User.DisplayNewLine;
    User.DisplayAttr(Config^.GetSystemColor(1));
    End;
  End;


End.
