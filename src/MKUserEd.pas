Program MKUserEd;

{$I MKB.Def}

{
     User file editor for the MK BBS (Free Vision, text mode).  MK (or RA,
     QUICK, SBBS) names the BBS config directory, as for mk.  Converted from
     the Object Professional MKUSERED.

        Edit      change the user          Next / Prior   next / previous user
        First     Home     Last   End      Search         find a name (Alt-L: again)
        Add       a new user               Delete         mark / unmark deleted
        GoTo      a user number            Validate       apply a template (1-9)
        Alt-C     the validation templates Q / Esc        leave

     The screen shows the user at the current position of the user file; Edit
     opens all the fields in one dialog, OK writes them back.
}

Uses
  Objects, Drivers, Views, Menus, Dialogs, App,
  MKString, MKFile, MKGlobT, MKCfgAbs, MKRCfgMK, MKRCfgRA, MKCfgQB, MKCfgSB,
  MKName, MKUserFm, CfgBox, CfgPal, MKKbd;


Const
  cmEdit = 3200;
  cmNext = 3201;
  cmPrior = 3202;
  cmFirst = 3203;
  cmLast = 3204;
  cmSearch = 3205;
  cmAdd = 3206;
  cmDelete = 3207;
  cmGoTo = 3208;
  cmValidate = 3209;
  cmTemplates = 3210;
  cmSearchAgain = 3211;
  cmQuitEd = 3212;


{------------------------------------------------ the record on the screen}

Function Pad2(S: String; N: Word): String;
  Begin
  Pad2 := PadRight(S, ' ', N);
  End;


Function StarStr(S: String): String;
  Begin
  If Length(S) = 0 Then
    StarStr := ''
  Else
    Begin
    FillChar(S[1], Length(S), '*');
    StarStr := S;
    End;
  End;


{------------------------------------------------ the record on the screen}

{------------------------------------------------ lines of text}

Const
  MaxLines = 24;

Type
  PLinesView = ^LinesView;
  LinesView = Object(TView)
    Procedure Draw; Virtual;
    End;

Var
  Lines: Array[1..MaxLines] Of String[78];
  NLines: Word;
  ShowAnswers: Boolean;                {the lines of the view in the validation window}


Procedure LinesView.Draw;
  Var
    B: TDrawBuffer;
    Y: Integer;
    Color: Word;
    S: String;

  Begin
  Color := GetColor(1);
  For Y := 0 To Size.Y - 1 Do
    Begin
    MoveChar(B, ' ', Color, Size.X);
    If ShowAnswers Then
      Begin
      If Y + 1 <= AnswerCount Then
        MoveStr(B, AnswerLines[Y + 1], Color);
      End
    Else If Y + 1 <= NLines Then
      MoveStr(B, Lines[Y + 1], Color);
    WriteLine(0, Y, Size.X, 1, B);
    End;
  End;


Procedure BuildLines;
  Var
    L: String;

  Procedure Add(T: String);
    Begin
    If NLines < MaxLines Then
      Begin
      Inc(NLines);
      Lines[NLines] := T;
      End;
    End;

  Begin
  NLines := 0;
  Add(' Name:      ' + Pad2(UR.Name, 36) + ' Password:  ' + StarStr(UR.Password));
  Add(' Handle:    ' + Pad2(UR.Handle, 36) + ' Home Phone: ' + UR.HomePhone);
  Add(' Location:  ' + Pad2(UR.Location, 36) + ' Data Phone: ' + UR.DataPhone);
  Add('');
  Add(' Security: ' + Pad2(Long2Str(UR.Security.Level), 7) + 'Credit: ' + Pad2(Long2Str(UR.NM), 7) +
    'Pending: ' + Pad2(Long2Str(UR.Pending), 7) + 'Screen Length: ' + Long2Str(UR.ScrnLen));
  Add(' Msgs Entered: ' + Pad2(Long2Str(UR.Entered), 8) + 'Times Called: ' + Pad2(Long2Str(UR.Times), 8) +
    'Elapsed Time: ' + Long2Str(UR.Elapsed));
  Add(' UL #: ' + Pad2(Long2Str(UR.ULFiles), 7) + 'UL Kb: ' + Pad2(Long2Str(UR.ULK), 7) +
    'DL #: ' + Pad2(Long2Str(UR.DLFiles), 7) + 'DL Kb: ' + Pad2(Long2Str(UR.DLK), 7) +
    'Today Kb: ' + Long2Str(UR.TodayK));
  L := ' Deleted: ' + Pad2(YN(UR.Deleted), 4) + 'Screen Clear: ' + Pad2(YN(UR.ScrnClr), 4) +
    'More: ' + Pad2(YN(UR.More), 4) + 'Ansi: ' + Pad2(YN(UR.Ansi), 4) +
    'Avatar: ' + Pad2(YN(UR.Avatar), 4) + 'No Kill: ' + YN(UR.NoKill);
  Add(L);
  Add(' Ignore Hrs: ' + Pad2(YN(UR.IgnoreHrs), 5) + 'Full Screen Editor: ' + YN(UR.FullScr));
  Add('');
  Add(' Birthdate: ' + Pad2(UR.Birthdate, 10) + 'First Called: ' + Pad2(UR.FirstCall, 10) +
    'Expiration: ' + UR.Expire);
  Add(' Last Called: ' + UR.LastCall + ' ' + Pad2(UR.LastTime, 8) + 'New Files Date: ' + UR.NewDate);
  Add(' Page Tune: ' + Long2Str(UR.PageTune));
  Add(' Address: ' + Pad2(UR.Address, 42) + ' Zip Code: ' + UR.ZipCode);
  Add(' Comment: ' + UR.Comment);
  Add(' Protocol: ' + Pad2(UR.Protocol, 4) + 'Packer: ' + Pad2(UR.Packer, 4) +
    'Max Msgs: ' + Pad2(Long2Str(UR.MaxMsg), 7) + 'Max Per Area: ' + Pad2(Long2Str(UR.MaxArea), 7) +
    'Networks: ' + UR.NetStr);
  Add(' Off New Files: ' + Pad2(YN(UR.OffNew), 5) + 'Scrns: ' + Pad2(YN(UR.OffScrn), 5) +
    'Bulls: ' + Pad2(YN(UR.OffBull), 5) + 'Verify: ' + Pad2(YN(UR.OffVerify), 5) +
    'Flag: ' + YN(UR.OffFlag));
  Add(' Off Own Msg: ' + Pad2(YN(UR.OffOwn), 5) + 'All Your: ' + Pad2(YN(UR.OffAll), 5) +
    'Zero Pkt: ' + Pad2(YN(UR.OffZero), 5) + 'GateWay: ' + Pad2(YN(UR.OffGate), 5) +
    'Areas: ' + UR.OffCount);
  Add(' Time Bank Minutes: ' + Long2Str(UR.BankMin));
  End;


{------------------------------------------------ the validation window}

Type
  PValDlg = ^ValDlg;
  ValDlg = Object(TDialog)
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    End;


Procedure ValDlg.HandleEvent(Var Event: TEvent);
  Var
    N: Word;

  Begin
  If Event.What = evKeyDown Then
    Begin
    If (Event.CharCode >= '1') And (Event.CharCode <= '9') Then
      Begin
      N := Ord(Event.CharCode) - Ord('0');
      ClearEvent(Event);
      ApplyTemplate(N);
      MsgBox('The user was validated with template ' + Long2Str(N) + '.');
      Exit;
      End;
    If (Event.KeyCode = kbEsc) Or (UpCase(Event.CharCode) = 'Q') Or (UpCase(Event.CharCode) = 'N') Then
      Begin
      ClearEvent(Event);
      EndModal(cmCancel);
      Exit;
      End;
    End;
  Inherited HandleEvent(Event);
  End;


Procedure Validate;
  Var
    D: PValDlg;
    R: TRect;

  Begin
  R.Assign(0, 0, 76, 22);
  New(D, Init(R, 'User Validation - ' + UR.Name));
  D^.Options := D^.Options Or ofCentered;
  LoadAnswers;
  ShowAnswers := True;
  R.Assign(2, 2, 74, 18);
  D^.Insert(New(PLinesView, Init(R)));
  R.Assign(2, 18, 74, 20);
  D^.Insert(New(PStaticText, Init(R, '1-9 validate with that template (Alt-C edits them), Esc or Q closes')));
  R.Assign(31, 19, 45, 21);
  D^.Insert(New(PButton, Init(R, '~C~lose', cmCancel, bfDefault)));
  Application^.ExecView(D);
  Dispose(D, Done);
  ShowAnswers := False;
  End;


{------------------------------------------------ the application}

Type
  PUserWin = ^UserWin;
  UserWin = Object(TDialog)
    Rec: PLinesView;
    Procedure ShowRecord;
    End;

  UserApp = Object(TApplication)
    Win: PUserWin;
    Constructor Init;
    Procedure InitMenuBar; Virtual;
    Procedure InitStatusLine; Virtual;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Procedure DoCommand(Cmd: Word);
    Procedure Refresh;
    Procedure Search(First: Boolean);
    End;


Procedure UserWin.ShowRecord;
  Begin
  If Title <> Nil Then
    DisposeStr(Title);
  Title := NewStr('[ User ' + Long2Str(NameSearch.GetPos) + ' of ' + Long2Str(NameSearch.GetNumUsers) +
    ' ]' + Copy(' (DELETED)', 1, 10 * Ord(UR.Deleted)));
  If Frame <> Nil Then
    Frame^.DrawView;
  BuildLines;
  Rec^.DrawView;
  End;


Constructor UserApp.Init;
  Var
    R: TRect;

  Begin
  Inherited Init;
  DeskTop^.GetExtent(R);
  New(Win, Init(R, ''));
  Win^.Flags := wfMove;
  Win^.GetExtent(R);
  R.Grow(-1, -1);
  New(Win^.Rec, Init(R));
  Win^.Insert(Win^.Rec);
  DeskTop^.Insert(Win);
  Refresh;
  End;


Procedure UserApp.InitMenuBar;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewItem('~E~dit', '', kbNoKey, cmEdit, cmEdit,
    NewItem('~N~ext', '', kbNoKey, cmNext, cmNext,
    NewItem('~P~rior', '', kbNoKey, cmPrior, cmPrior,
    NewItem('~F~irst', '', kbNoKey, cmFirst, cmFirst,
    NewItem('~L~ast', '', kbNoKey, cmLast, cmLast,
    NewItem('~S~earch', '', kbNoKey, cmSearch, cmSearch,
    NewItem('~A~dd', '', kbNoKey, cmAdd, cmAdd,
    NewItem('~D~elete', '', kbNoKey, cmDelete, cmDelete,
    NewItem('~G~oTo', '', kbNoKey, cmGoTo, cmGoTo,
    NewItem('~V~alidate', '', kbNoKey, cmValidate, cmValidate,
    NewItem('~T~emplates', '', kbNoKey, cmTemplates, cmTemplates,
    NewItem('~Q~uit', '', kbNoKey, cmQuitEd, cmQuitEd,
    Nil)))))))))))))));
  End;


Procedure UserApp.InitStatusLine;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~Enter~ Edit', kbNoKey, cmEdit,
      NewStatusKey('~Up/Dn~ Prior/Next', kbNoKey, cmNext,
      NewStatusKey('~Home/End~ First/Last', kbNoKey, cmFirst,
      NewStatusKey('~Alt-L~ Search again', kbNoKey, cmSearchAgain,
      NewStatusKey('~Alt-C~ Templates', kbNoKey, cmTemplates,
      NewStatusKey('~Q~ Quit', kbNoKey, cmQuitEd, Nil)))))),
    Nil)));
  End;


Procedure UserApp.Refresh;
  Begin
  Win^.ShowRecord;
  End;


Procedure UserApp.Search(First: Boolean);
  Var
    TmpStr: String;
    Old: Word;
    Found: Boolean;

  Begin
  If First Then
    Begin
    TmpStr := '';
    If Not InputLine('Search for User', 'Name:', 35, TmpStr) Then
      Exit;
    If TmpStr = '' Then
      Exit;
    End;
  Old := NameSearch.GetPos;
  ProcessBox('* Searching *', '[ Please Wait ]');
  If First Then
    Found := NameSearch.SearchFirst(TmpStr)
  Else
    Found := NameSearch.SearchNext;
  EndProcessBox;
  If Not Found Then
    Begin
    NameSearch.GoToPosition(Old);
    MsgBox('Search name not found!');
    End;
  LoadUser;
  Refresh;
  End;


Procedure UserApp.DoCommand(Cmd: Word);
  Var
    Old: Word;
    TmpStr: String;
    N: LongInt;

  Begin
  Case Cmd Of
    cmEdit:
      Begin
      If EditUser Then
        Begin
        SaveUser;
        LoadUser;
        End;
      Refresh;
      End;
    cmNext:
      Begin
      If NameSearch.GetPos < NameSearch.GetNumUsers - 1 Then
        If NameSearch.Next Then;
      LoadUser;
      Refresh;
      End;
    cmPrior:
      Begin
      If NameSearch.GetPos > 0 Then
        If NameSearch.Prior Then;
      LoadUser;
      Refresh;
      End;
    cmFirst:
      Begin
      NameSearch.GoToPosition(0);
      LoadUser;
      Refresh;
      End;
    cmLast:
      Begin
      NameSearch.GoToPosition(NameSearch.GetNumUsers - 1);
      LoadUser;
      Refresh;
      End;
    cmSearch: Search(True);
    cmSearchAgain: Search(False);
    cmAdd:
      Begin
      Old := NameSearch.GetPos;
      NameSearch.GoToPosition(NameSearch.GetNumUsers);
      DefaultUser;
      If EditUser Then
        Begin
        If UR.Name = '' Then
          Begin
          MsgBox('A user needs a name: nothing was added.');
          NameSearch.GoToPosition(Old);
          End
        Else
          SaveUser;
        End
      Else
        NameSearch.GoToPosition(Old);
      LoadUser;
      Refresh;
      End;
    cmDelete:
      Begin
      NameSearch.SetDelete(Not NameSearch.IsDeleted);
      NameSearch.SaveChanges;
      LoadUser;
      Refresh;
      End;
    cmGoTo:
      Begin
      TmpStr := Long2Str(NameSearch.GetPos);
      If InputLine('Go To User Number', 'User Number:', 5, TmpStr) Then
        Begin
        N := Str2Long(TmpStr);
        If (N >= 0) And (N < NameSearch.GetNumUsers) Then
          Begin
          NameSearch.GoToPosition(N);
          LoadUser;
          Refresh;
          End
        Else
          MsgBox('There are users 0 to ' + Long2Str(NameSearch.GetNumUsers - 1));
        End;
      End;
    cmValidate:
      Begin
      Validate;
      LoadUser;
      Refresh;
      End;
    cmTemplates: EditTemplates;
    cmQuitEd:
      If DoYesNo('[ Exit Program ]', True) = 1 Then
        Message(@Self, evCommand, cmQuit, Nil);
    End;
  End;


Procedure UserApp.HandleEvent(Var Event: TEvent);
  Var
    Cmd: Word;

  Begin
  Cmd := 0;
  If Event.What = evKeyDown Then
    Begin
    Case Event.KeyCode Of
      kbEnter: Cmd := cmEdit;
      kbUp, kbPgUp: Cmd := cmPrior;
      kbDown, kbPgDn: Cmd := cmNext;
      kbHome: Cmd := cmFirst;
      kbEnd: Cmd := cmLast;
      kbAltC: Cmd := cmTemplates;
      kbAltL: Cmd := cmSearchAgain;
      kbEsc: Cmd := cmQuitEd;
      Else
        Case UpCase(Event.CharCode) Of
          'E': Cmd := cmEdit;
          'N': Cmd := cmNext;
          'P': Cmd := cmPrior;
          'F': Cmd := cmFirst;
          'L': Cmd := cmLast;
          'S': Cmd := cmSearch;
          'A': Cmd := cmAdd;
          'D': Cmd := cmDelete;
          'G': Cmd := cmGoTo;
          'V': Cmd := cmValidate;
          'T': Cmd := cmTemplates;
          'Q': Cmd := cmQuitEd;
          End;
      End;
    If Cmd <> 0 Then
      Begin
      ClearEvent(Event);
      DoCommand(Cmd);
      Exit;
      End;
    End;
  Inherited HandleEvent(Event);
  If Event.What = evCommand Then
    Begin
    If (Event.Command >= cmEdit) And (Event.Command <= cmQuitEd) Then
      Begin
      Cmd := Event.Command;
      ClearEvent(Event);
      DoCommand(Cmd);
      End;
    End;
  End;


Var
  A: UserApp;
  BbsType: Word;

Begin
BbsType := DetectBbsType;
Config := Nil;
Case BbsType Of
  1: Config := New(MKRCfgObjPtr, Init);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'Fatal Error: Environment variable not found (MK, RA, QUICK or SBBS)');
  Halt(42);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, 'Unable to Load BBS Config Info');
  Halt(41);
  End;
LoadCfg;
NameSearch.Init;
NameSearch.SetBbsType(BbsType);
NameSearch.GoToPosition(0);
LoadUser;
InstallKeyboard;                       {Esc and the Ctrl keys work}
MaroonOn;
A.Init;
A.Run;
A.Done;
MaroonOff;
NameSearch.Done;
SaveCfg;
Dispose(Config, Done);
End.
