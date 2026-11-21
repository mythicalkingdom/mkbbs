Unit MKOffExt;   {What goes into an offline mail packet besides the messages: BBS screens, bulletins, the new files list}

{$I MKB.Def}

{
     A packet of the QWK door (MKQwkO) or of the offline menu of mk (MKOfflin) can carry, besides the messages (see QWK-EXTRAS-PLAN.md):

       * the welcome, news and goodbye screens (three names), when the user wants screens: every packet
       * bulletins (up to ten names), when the user wants bulletins: every packet
       * the list of new files, when the user wants it: the files uploaded since the user's new files date in the areas
         the user may list, laid out as the BBS shows them online (files.bbs: name, date, size, description, the long
         description wrapped under it), after the "heading" screen if there is one

     Bulletins keep the names the QWK readers know: BLT-1.<ext>, BLT-2.<ext> ... in the order of the settings (the extension is that of the
     version the caller gets), and TOREADER.EXT (QWKE, see below) describes them.

     TOREADER.EXT (QWKE 1.02, wmcbrine.com/mmail/specs/qwke.html), written when the packet has QWKE long names (OffExtraSpec.ToReader):
        ALIAS <handle>                 the caller's handle, when there is one
        AREA <conference> <flags>      for each conference that has messages in the packet; flags without a separator:
                a / p / g              how the caller takes the area: all messages, personal, personal and to All
                w                      the caller's own messages are included
                F                      the area is forced into the packets by the sysop
                P / O / X              private mail only / public mail only / either
                R                      the caller cannot post in it
                L / N / E              local, netmail, echomail area
                A                      an alias may be used as the name
        BULL BLT-<n>.<ext> <name>      a bulletin and its name (the setting)
     (KEYWORD, FILTER, TWIT, ATTACH and FILE lines are for features MK does not have.)

     The names are those of the offline mail settings (mkconfig: Offline Mail Parameters for mk; MKQwk Screens and Bulletins for the
     door).  A screen or bulletin is found as the BBS shows it to this caller (.avt, .ans or .asc in the text directory) and is put in
     the packet under its own name with the extension it has.  A name with no file is left out.  The files are written into the
     packet's work directory before the packet is packed, so every packet type carries them.

     Only the caller's packet gets them, never a network pass (a hub is not asked for its bulletins and new files).

     The user's new files date moves (OffExtrasCommit) only when the packet was made and kept, as the last read pointers do.
}

Interface

Uses MKGlobT, MKOffAbs, MKOffDL;

Const
  OffNewFilesName = 'newfiles.dat';

Type OffExtraSpec = Record
  Screens: Boolean;                    {the three screens}
  Bulletins: Boolean;
  NewFiles: Boolean;
  ToReader: Boolean;                   {write TOREADER.EXT (QWKE)}
  Alias: String[35];                   {the caller's handle ('' = none)}
  OwnMsgs: Boolean;                    {the packet has the caller's own messages (flag w)}
  Scr: Array[1..3] Of String[8];       {welcome, news, goodbye (names without extension)}
  Bull: Array[1..10] Of String[8];
  Head: String[8];                     {screen shown above the new files list ('' = none)}
  MaxLines: Word;                      {lines of the new files list at most (0 = 1000)}
  End;

Type OffExtraRes = Record
  NumScreens, NumBulletins: Word;
  NewFiles: LongInt;                   {files in the list}
  ListMade: Boolean;
  End;


Procedure OffAddExtras(Offline: AbsOffPtr; WorkPath: String; Var S: OffExtraSpec; Var Dl: OffDLResult; Var R: OffExtraRes);
Procedure OffExtrasCommit(Var R: OffExtraRes);
  {the packet is kept: the new files date of the user is today}


Implementation

Uses Dos, MKString, MKFile, MKCfgAbs, MKDoor, MKCodes, MKBFile;


Var
  BullLines: Array[1..10] Of String[80];     {the BULL lines of TOREADER.EXT}
  NumBullLines: Word;


Function AddScreenFile(WorkPath, Base: String; Var Name: String; Prefix: String): Boolean;
  {the screen named Base as this caller gets it, copied into the work directory; Name is what it is called there: Base, or Prefix
   (BLT-n) when there is one, with the extension of the file}
  Var
    Src: String;
    D: DirStr;
    N: NameStr;
    E: ExtStr;

  Begin
  AddScreenFile := False;
  Name := '';
  If Base = '' Then
    Exit;
  Src := BbsDisplay.ScreenFileExpand(Base);
  If Not FileExist(Src) Then
    Exit;
  FSplit(Src, D, N, E);
  If Prefix <> '' Then
    Name := Lower(Prefix) + Lower(E)
  Else
    Name := Lower(Base) + Lower(E);
  AddScreenFile := CopyFile(Src, WithBackSlash(WorkPath) + Name);
  End;


Procedure WriteLine(Var T: Text; Const S: String; Var Lines: Word; Max: Word);
  Begin
  If Lines < Max Then
    WriteLn(T, S);
  Inc(Lines);
  End;


Procedure MakeNewFiles(WorkPath: String; Var S: OffExtraSpec; Var R: OffExtraRes);
  Var
    T: Text;
    Sec: SecType;
    DT: DateTime;
    Since: LongInt;
    Area: Word;
    NumNew, SizeNew: LongInt;
    Lines, Max: Word;
    Head, Line, Desc: String;
    HF: Text;
    Dow: Word;

  Const
    StLen = 78;

  Begin
  R.NewFiles := 0;
  R.ListMade := False;
  Max := S.MaxLines;
  If Max = 0 Then
    Max := 1000;
  User.GetUserSec(Sec);
  User.GetUserNewFileDate(DT);
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
  PackTime(DT, Since);
  Assign(T, WithBackSlash(WorkPath) + OffNewFilesName);
  Rewrite(T);
  If IoResult <> 0 Then
    Exit;
  Lines := 0;
  If S.Head <> '' Then
    Begin                              {the heading screen of the list, as the caller's terminal gets it}
    Head := BbsDisplay.ScreenFileExpand(S.Head);
    If FileExist(Head) Then
      Begin
      Assign(HF, Head);
      FileMode := 0;
      Reset(HF);
      If IoResult = 0 Then
        Begin
        While Not Eof(HF) Do
          Begin
          ReadLn(HF, Line);
          WriteLine(T, Line, Lines, Max);
          End;
        Close(HF);
        If IoResult <> 0 Then;
        End;
      End;
    End;
  WriteLine(T, Config^.GetBbsName + ': new files since ' + FormattedDate(DT, 'MM-DD-YY'), Lines, Max);
  Area := 0;
  NumNew := 0;
  SizeNew := 0;
  NewF.NewFileInit;
  NewF.NewFileFirst(Sec, Since);
  While NewF.NewFileFound Do
    Begin
    If NewF.NewFileGetArea <> Area Then
      Begin
      Area := NewF.NewFileGetArea;
      WriteLine(T, '', Lines, Max);
      WriteLine(T, Config^.GetFileAreaName(Area), Lines, Max);
      End;
    Inc(NumNew);
    Inc(SizeNew, NewF.NewFileGetSize);
    Desc := WWrap(NewF.NewFileGetDesc, StLen - 32);
    Line := PadRight(Copy(NewF.NewFileGetName, 1, 13), ' ', 13);
    Line := Line + FormattedDosDate(NewF.NewFileGetDate, 'MM-DD-YY') + ' ';
    Line := Line + PadLeft(CommaStr(NewF.NewFileGetSize), ' ', 10) + ' ' + Desc;
    WriteLine(T, Line, Lines, Max);
    While Length(ExtraString) > 0 Do
      Begin
      Desc := WWrap('                                ' + ExtraString, StLen);
      WriteLine(T, Desc, Lines, Max);
      End;
    NewF.NewFileNext;
    End;
  NewF.NewFileDone;
  WriteLine(T, '', Lines, Max);
  If Lines > Max Then
    WriteLn(T, '(' + Long2Str(Lines - Max) + ' more line(s) of the list are left out)');
  WriteLn(T, CommaStr(NumNew) + ' New Files containing ' + CommaStr(SizeNew) + ' Bytes');
  Close(T);
  If IoResult <> 0 Then;
  R.NewFiles := NumNew;
  R.ListMade := True;
  End;


Function AreaFlags(A: Word; Mode: Byte; Var S: OffExtraSpec; Var Sec: SecType): String;
  {the flags of an AREA line of TOREADER.EXT}
  Var
    F: String;
    P: Word;

  Begin
  Case Mode Of
    omMy: F := 'p';
    omAllYour: F := 'g';
    Else F := 'a';
    End;
  If S.OwnMsgs Then
    F := F + 'w';
  If Config^.GetMsgForceOffline(A) Then
    F := F + 'F';
  P := Config^.GetMsgPermit(A);
  If ((P And 64) <> 0) And ((P And 128) <> 0) Then
    F := F + 'X'
  Else If (P And 64) <> 0 Then
    F := F + 'P'
  Else If (P And 128) <> 0 Then
    F := F + 'O';
  If Not Config^.MsgWriteAccess(A, Sec) Then
    F := F + 'R';
  Case Config^.GetMsgType(A) Of
    NetMail: F := F + 'N';
    EchoMail: F := F + 'E';
    Else F := F + 'L';
    End;
  If (P And 8) <> 0 Then
    F := F + 'A';
  AreaFlags := F;
  End;


Procedure MakeToReader(Offline: AbsOffPtr; WorkPath: String; Var S: OffExtraSpec; Var Dl: OffDLResult);
  Var
    T: Text;
    A: Word;
    Sec: SecType;
    i: Word;

  Begin
  User.GetUserSec(Sec);
  Assign(T, WithBackSlash(WorkPath) + 'toreader.ext');
  Rewrite(T);
  If IoResult <> 0 Then
    Exit;
  If S.Alias <> '' Then
    WriteLn(T, 'ALIAS ', S.Alias);
  For A := 1 To Config^.GetMaxMsgAreas Do
    If (A <= OffAreas) And Offline^.AreaInPacket(A) Then
      WriteLn(T, 'AREA ', A, ' ', AreaFlags(A, Dl.Mode[A], S, Sec));
  For i := 1 To NumBullLines Do
    WriteLn(T, 'BULL ', BullLines[i]);
  Close(T);
  If IoResult <> 0 Then;
  End;


Procedure OffAddExtras(Offline: AbsOffPtr; WorkPath: String; Var S: OffExtraSpec; Var Dl: OffDLResult; Var R: OffExtraRes);
  Var
    i, N: Word;
    Name: String;

  Begin
  R.NumScreens := 0;
  R.NumBulletins := 0;
  R.NewFiles := 0;
  R.ListMade := False;
  NumBullLines := 0;
  If S.Screens Then
    For i := 1 To 3 Do
      If AddScreenFile(WorkPath, S.Scr[i], Name, '') Then
        Begin
        Inc(R.NumScreens);
        Offline^.SetScreenFile(i, Name);        {CONTROL.DAT names the files that are really there}
        End;
  If S.Bulletins Then
    Begin
    N := 0;
    For i := 1 To 10 Do
      If AddScreenFile(WorkPath, S.Bull[i], Name, 'BLT-' + Long2Str(N + 1)) Then
        Begin
        Inc(N);
        Inc(R.NumBulletins);
        Inc(NumBullLines);
        BullLines[NumBullLines] := Name + ' ' + S.Bull[i];
        End;
    End;
  If S.NewFiles Then
    MakeNewFiles(WorkPath, S, R);
  If S.ToReader Then
    MakeToReader(Offline, WorkPath, S, Dl);
  End;


Procedure OffExtrasCommit(Var R: OffExtraRes);
  Var
    DT: DateTime;
    Dow: Word;

  Begin
  If Not R.ListMade Then
    Exit;
  GetDate(DT.Year, DT.Month, DT.Day, Dow);
  DT.Hour := 0;
  DT.Min := 0;
  DT.Sec := 0;
  User.SetUserNewFileDate(DT);
  User.WriteExtUser;                   {kept now: the door of a BBS does not write the whole record (that is the BBS's at log off)}
  End;


End.
