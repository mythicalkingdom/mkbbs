Unit CfgNuser;   {Converted from CFGNUSER for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgNUser;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;


Type UserRecord = Record
  AskHome: Boolean;
  AskData: Boolean;
  NewCredit: Word;
  AskBirth: Boolean;
  AskGender: Boolean;
  AskHandle: Boolean;
  AskAddr: Boolean;
  BitName: Boolean;
  OneWord: Boolean;
  ReAsk: Boolean;
  End;

Var
  UR: ^UserRecord;

Procedure DoCfgNUser;
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.AskHome := Config^.GetAskVoicePhone;
  UR^.AskData := Config^.GetAskDataPhone;
  UR^.AskBirth := Config^.GetAskBirthDate;
  UR^.AskGender := Config^.GetAskGender;
  UR^.AskHandle := Config^.GetAskHandle;
  UR^.AskAddr := Config^.GetAskAddr;
  UR^.BitName := Config^.GetSevenBitNames;
  UR^.OneWord := Config^.GetOneWordName;
  UR^.ReAsk := Config^.GetReAsk;
  UR^.NewCredit := Config^.GetNewUserNMCredit;
  F.Init('User Configuration');
  F.Window(8, 7, 71, 18);
  F.At(2, 3, 2, 25);
  F.AddYesNo('Ask Home/Voice Phone:', UR^.AskHome, 'Ask Home/Voice Phone');
  F.At(2, 31, 2, 56);
  F.AddYesNo('Ask Data/Business Phone:', UR^.AskData, 'Ask Data/Business Phone');
  F.At(4, 3, 4, 19);
  F.AddNumber('Netmail Credit:', UR^.NewCredit, 2, 0, 32767, 'Netmail Credit');
  F.At(4, 28, 4, 43);
  F.AddYesNo('Ask BirthDate:', UR^.AskBirth, 'Ask BirthDate');
  F.At(4, 49, 4, 61);
  F.AddYesNo('Ask Gender:', UR^.AskGender, 'Ask Gender');
  F.At(6, 3, 6, 19);
  F.AddYesNo('Ask for Handle:', UR^.AskHandle, 'Ask for Handle');
  F.At(6, 24, 6, 41);
  F.AddYesNo('Ask for Address:', UR^.AskAddr, 'Ask for Address');
  F.At(8, 3, 8, 22);
  F.AddYesNo('Force 7 bit Names:', UR^.BitName, 'Force 7 bit Names');
  F.At(8, 27, 8, 49);
  F.AddYesNo('Allow One Word Names:', UR^.OneWord, 'Allow One Word Names');
  F.At(10, 3, 10, 33);
  F.AddYesNo('Re-Ask Questions with Blanks:', UR^.ReAsk, 'Re-Ask Questions with Blanks');
  If F.Execute Then
    Begin
    Config^.SetAskVoicePhone(UR^.AskHome);
    Config^.SetAskDataPhone(UR^.AskData);
    Config^.SetAskBirthDate(UR^.AskBirth);
    Config^.SetAskGender(UR^.AskGender);
    Config^.SetAskHandle(UR^.AskHandle);
    Config^.SetAskAddr(UR^.AskAddr);
    Config^.SetSevenBitNames(UR^.BitName);
    Config^.SetOneWordName(UR^.OneWord);
    Config^.SetReAsk(UR^.ReAsk);
    Config^.SetNewUserNMCredit(UR^.NewCredit);
    End;
    Dispose(UR);
  End;


End.
