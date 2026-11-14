Unit MKCodes;
{$I MKB.Def}

Interface

Uses MKFile, MKGlobT, MKComAbs;


Type DisplayInfoType = Record
  DFile: File;
  TmpStr : String;
  CharsRead: Word;
  NoAbort: Boolean;
  HotStop: Boolean;
  HotStr: String;
  KeyChar: Char;
  TChar: Char;
  FileName: String;
  DisplayError: Word;
  State: Word;         {0=normal 1=^F 2=^K}
  Sec: SecType;
  End;


Type BbsDisplayObj = Object
  DInfo: ^DisplayInfoType;
  Procedure Init;
  Procedure Done;
  Function GetError: Word;
  Function DisplayBbsFile(FileName: String; HotStr: String): Char;
  Function ScreenFileExpand(FileName: String): String;
  Procedure DisplayStr(Var DStr: String); {translate codes and display}
  Procedure ResetState; {reset state}
  End;


Var
  BbsDisplay: BbsDisplayObj;


Implementation

Uses
      MKVCrt,
  MKDoor, MKCfgAbs, MKString, MKSys, MKDos, MKAvatar, MKOfflin;



Procedure BbsDisplayObj.Init;
  Begin
  New(DInfo);
  ResetState;
  End;


Procedure BbsDisplayObj.Done;
  Begin
  Dispose(DInfo);
  End;


Procedure BbsDisplayObj.ResetState;
  Begin
  DInfo^.State := 0;
  DInfo^.NoAbort := False;
  DInfo^.HotStop := False;
  DInfo^.HotStr := '';
  DInfo^.KeyChar := #0;
  DInfo^.DisplayError := 0;
  End;


Procedure BbsDisplayObj.DisplayStr(Var DStr: String);
  Type  ByteArray = Array[1..4] of Byte;
  Var
    i: Word;
    HotCount: Word;

  Const
    HotFreq = 16;

  Begin
  User.GetUserSec(DInfo^.Sec);
  HotCount := HotFreq;
  User.CheckInput;
  i := 1;
  While ((i <= Length(DStr)) and (User.Ok) and (Not DInfo^.HotStop)) Do
    Begin
    If InAvatar Then
      User.DisplayChr(DStr[i])
    Else
    Case DInfo^.State Of
      0: Begin
         Case DStr[i] Of
           '': User.WaitEnter;
           '': DInfo^.NoAbort := True;
           '': DInfo^.NoAbort := False;
           '': User.SetMore(True);
           '': User.SetMore(False);
           '': DInfo^.State := 1;
           #9 : User.DisplayStr('        ');
           #10: Begin
                User.DisplayChr(#10);
                User.CheckMore;
                If User.StopMore Then
                  DInfo^.HotStop := True;
                End;
           '': DInfo^.State := 2;
           '': User.ClearScreen;
           '': Delay(1000);
           #26: ;
           Else
             User.DisplayChr(DStr[i]);
           End;
         End;
      1: Begin                {^F}
         DInfo^.State := 0;
         Case UpCase(DStr[i]) Of
           '': Begin
                User.DisplayChr('');
                DInfo^.State := 1;
                End;
           '': Begin
                User.DisplayChr('');
                DInfo^.State := 2;
                End;
           'A': User.DisplayStr(User.GetUserName);
           'B': User.DisplayStr(User.GetUserCity);
           'C': User.DisplayStr(User.GetUserPwd);
           'D': User.DisplayStr(User.GetUserDataPhone);
           'E': User.DisplayStr(User.GetUserVoicePhone);
           'F': User.DisplayStr(User.GetUserLastDate);
           'G': User.DisplayStr(User.GetUserLastTime);
           'H': User.DisplayStr(Flag2Str(ByteArray(DInfo^.Sec.Flags)[1]));
           'I': User.DisplayStr(Flag2Str(ByteArray(DInfo^.Sec.Flags)[2]));
           'J': User.DisplayStr(Flag2Str(ByteArray(DInfo^.Sec.Flags)[3]));
           'K': User.DisplayStr(Flag2Str(ByteArray(DInfo^.Sec.Flags)[4]));
           'L': User.DisplayStr(CommaStr(User.GetUserCredit - User.GetUserPending));
           'M': User.DisplayStr(CommaStr(User.GetUserMsgsEntered));
           'N': User.DisplayStr(CommaStr(User.GetUserCombRead));
           'O': User.DisplayStr(CommaStr(DInfo^.Sec.Level));
           'P': User.DisplayStr(CommaStr(User.GetUserTimesCalled));
           'Q': User.DisplayStr(CommaStr(User.GetUserULFiles));
           'R': User.DisplayStr(CommaStr(User.GetUserULK));
           'S': User.DisplayStr(CommaStr(User.GetUserDLFiles));
           'T': User.DisplayStr(CommaStr(User.GetUserDLK));
           'U': User.DisplayStr(CommaStr(User.GetUserElapsed));
           'V': User.DisplayStr(CommaStr(User.GetUserScrLength));
           'W': User.DisplayStr(ExtractWord(User.GetUserName,1));
           'X': If User.GetUserAnsi Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           'Y': If User.GetUserMore Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           'Z': If User.GetUserScrnClr Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '0': If User.GetUserFullEd Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '8': If User.GetUserAvatar Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '!': User.DisplayStr(CommaStr(User.GetUserOffMax));
           '@': User.DisplayStr(CommaStr(User.GetUserOffConfMax));
           '#': If GetUserOffTypeNum > 0 Then
                  User.DisplayStr(Prompts.GetString(345 + GetUserOffTypeNum));
                  {offline mail packet type}
           '$': If GetUserProtNum > 0 Then
                  User.DisplayStr(Config^.GetProtName(GetUserProtNum));
                  {protocol type}
           '%': If GetUserPackerNum > 0 Then
                  User.DisplayStr(Config^.GetPackName(GetUserPackerNum));
                  {packer type}
           '^': User.DisplayStr(Prompts.GetString(370));
           '&': User.DisplayStr(Prompts.GetString(371));
           '*': User.DisplayStr(Prompts.GetString(372));
           '(': User.DisplayStr(Prompts.GetString(373));
           ')': User.DisplayStr(Prompts.GetString(374));
           '-': User.DisplayStr(Prompts.GetString(375));
           '=': User.DisplayStr(Prompts.GetString(376));
           ';': User.DisplayStr(Prompts.GetString(377));
           ':': User.DisplayStr(Prompts.GetString(378));
           '<': User.DisplayStr(Prompts.GetString(379));
           End;
         End;
      2: Begin                {^K}
         DInfo^.State := 0;
         Case UpCase(DStr[i]) Of
           '': Begin
                User.DisplayChr('');
                DInfo^.State := 1;
                End;
           '': Begin
                User.DisplayChr('');
                DInfo^.State := 2;
                End;
           'A': User.DisplayStr(CommaStr(User.GetSystemCalls));
           'B': User.DisplayStr(User.GetSystemLastCaller);
           'C': User.DisplayStr(CommaStr(SysStats.GetNumberOfMsgs));
           'D': User.DisplayStr(CommaStr(1));
           'E': User.DisplayStr(CommaStr(SysStats.GetNumberOfMsgs));
           'F': User.DisplayStr(CommaStr(User.GetUserPageTimes));
           'G': User.DisplayStr(DowStr(GetDow));
           'H': User.DisplayStr(CommaStr(SysStats.GetNumUsers));
           'I': User.DisplayStr(Copy(TimeStr(GetDosDate),1,5));
           'J': User.DisplayStr(FormattedDosDate(GetDosDate, Prompts.GetString(58)));
           'K': User.DisplayStr(CommaStr(User.GetUserSecondsOn Div 60));
           'L': User.DisplayStr(CommaStr(User.GetUserSecondsOn));
           'M': User.DisplayStr(CommaStr(
                 (User.GetUserElapsed + User.GetUserSecondsOn) Div 60));
           'N': User.DisplayStr(CommaStr(
                 User.GetUserElapsed + User.GetUserSecondsOn));
           'O': User.DisplayStr(CommaStr(User.TimeRemain Div 60));
           'P': User.DisplayStr(CommaStr(User.TimeRemain));
           'Q': User.DisplayStr(CommaStr(User.GetUserTimeLimit));
           'R': User.DisplayStr(CommaStr(User.GetUserBaud));
           'S': User.DisplayStr(DowShortStr(GetDow));
           'T': User.DisplayStr(CommaStr(User.GetUserDLLimit));
           'V': User.DisplayStr(User.GetNextEventStr);
           'Y': User.DisplayStr(Config^.GetMsgName(User.GetUserMsgTemplate));
           'Z': User.DisplayStr(Config^.GetFileAreaName(User.GetUserFileTemplate));
           '1': User.DisplayStr(CommaStr(User.GetUserMsgTemplate));
           '2': User.DisplayStr(CommaStr(User.GetUserFileTemplate));
           '!': If User.GetUserOffNew Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '@': If User.GetUserOffScrn Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '#': If User.GetUserOffBull Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '$': If User.GetUserOffVerify Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '^': If User.GetUserOffFlag Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '&': If User.GetUserOffOwn Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '*': If User.GetUserOffAllYour Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           '(': If User.GetUserOffZero Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           ')': If User.GetUserOffGate Then
                  User.DisplayStr(Prompts.GetString(18))
                Else
                  User.DisplayStr(Prompts.GetString(19));
           End;
         End;
      End; {End Case}
    Dec(HotCount);
    If HotCount < 1 Then
      Begin
      HotCount := HotFreq;
      If User.InputChr(DInfo^.TChar) Then
        Begin
        DInfo^.TChar := UpCase(DInfo^.TChar);
        If ((DInfo^.TChar <> #0) And (Pos(DInfo^.TChar, DInfo^.HotStr) > 0)) Then
          Begin
          DInfo^.KeyChar := DInfo^.TChar;
          DInfo^.HotStop := True;
          CommFlushOut;
          End; {End Good char}
        End; {End If InputChar}
      End; {End If HotCount < 1}
    Inc(I);
    End;
  End;


Function BbsDisplayObj.GetError: Word;
  Begin
  GetError := DInfo^.DisplayError;
  End;


Function BbsDisplayObj.ScreenFileExpand(FileName: String): String;
  Begin
  If ((User.GetUserAvatar) And
  (FileExist(Config^.GetTxtPath(User.GetUserLanguage) + FileName + '.AVT'))) Then
    ScreenFileExpand := Config^.GetTxtPath(User.GetUserLanguage) + FileName + '.AVT'
  Else If ((User.GetUserAvatar) And
  (FileExist(Config^.GetTxtPath(1) + FileName + '.AVT'))) Then
    ScreenFileExpand := Config^.GetTxtPath(1) + FileName + '.AVT'
  Else If ((User.GetUserAnsi) And
  (FileExist(Config^.GetTxtPath(User.GetUserLanguage) + FileName + '.ANS'))) Then
    ScreenFileExpand := Config^.GetTxtPath(User.GetUserLanguage) + FileName + '.ANS'
  Else If ((User.GetUserAnsi) And
  (FileExist(Config^.GetTxtPath(1) + FileName + '.ANS'))) Then
    ScreenFileExpand := Config^.GetTxtPath(1) + FileName + '.ANS'
  Else If
  (FileExist(Config^.GetTxtPath(User.GetUserLanguage) + FileName + '.ASC')) Then
    ScreenFileExpand := Config^.GetTxtPath(User.GetUserLanguage) + FileName + '.ASC'
  Else If
  (FileExist(Config^.GetTxtPath(1) + FileName + '.ASC')) Then
    ScreenFileExpand := Config^.GetTxtPath(1) + FileName + '.ASC'
  Else
    ScreenFileExpand := FileName;
  End;


Function BbsDisplayObj.DisplayBbsFile(FileName: String; HotStr: String): Char;
  Begin
  User.SetMore(True);
  User.ResetLines(1);
  User.SetStopMore(False);
  DInfo^.State := 0;
  DInfo^.NoAbort := False;
  DInfo^.HotStop := False;
  DInfo^.HotStr := Upper(HotStr);
  DInfo^.KeyChar := #0;
  DInfo^.TChar := #0;
  DInfo^.DisplayError := 0;
  DInfo^.FileName := ScreenFileExpand(FileName);
  If Not FileExist(DInfo^.FileName) Then
    DInfo^.DisplayError := 3000;
  If DInfo^.DisplayError = 0 Then
    Begin
    Assign(DInfo^.DFile, ResolveCase(DInfo^.FileName));
    FileMode := fmReadOnly + fmDenyNone;
    If Not shReset(DInfo^.DFile, 1) Then
      DInfo^.DisplayError := 3010;
    End;
  If DInfo^.DisplayError = 0 Then
    Begin
    If Not shRead(DInfo^.DFile, DInfo^.TmpStr[1], 255,
      DInfo^.CharsRead) Then;
    DInfo^.TmpStr[0] := Chr(DInfo^.CharsRead);
    While (Length(DInfo^.TmpStr) > 0) and (Not DInfo^.HotStop) and (User.Ok) Do
      Begin
      DisplayStr(DInfo^.TmpStr);
      If Not shRead(DInfo^.DFile, DInfo^.TmpStr[1], 255,
        DInfo^.CharsRead) Then;
      DInfo^.TmpStr[0] := Chr(DInfo^.CharsRead);
      End;
    End;
  Close(DInfo^.DFile);
  If IoResult <> 0 Then;
  DisplayBbsFile := DInfo^.KeyChar;
  End;


End.
