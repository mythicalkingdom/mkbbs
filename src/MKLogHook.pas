{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKLogHook;      {a way for the low level units to write a line in the log of the call (the log unit needs them, so they cannot use it)}

{$I MKB.Def}

{
     mk sets LogHook to a procedure that writes in the BBS log.  BbsLog(Text) is for what the sysop must be able to see in the log: a language file, a menu, a screen or a
     questionnaire that could not be loaded.  The same text is written once in a call (a menu that is missing is asked for each time its key is pressed), up to 60 different
     ones.  Programs that do not set the hook (the tools) write nothing.
}

Interface

Type LogProc = Procedure(S: String);

Var
  LogHook: LogProc;

Function LoadWhy(Code: Word): String;   {the words for the error codes of the loaders: 1000 / 3000 not found, 1010 / 3010 cannot be opened, 1020 cannot be read}
Procedure BbsLog(S: String);
Procedure BbsLogReset;                 {the next call: the same texts are written again}


Implementation

Const
  MaxSeen = 60;

Var
  Seen: Array[1..MaxSeen] Of String[120];
  NumSeen: Word;


Function LoadWhy(Code: Word): String;
  Begin
  Case Code Of
    1000, 3000: LoadWhy := 'not found';
    1010, 3010: LoadWhy := 'cannot be opened';
    1020: LoadWhy := 'cannot be read';
    Else LoadWhy := 'error ' + Chr(48 + (Code Div 1000) Mod 10) + Chr(48 + (Code Div 100) Mod 10) + Chr(48 + (Code Div 10) Mod 10) + Chr(48 + Code Mod 10);
    End;
  End;


Procedure BbsLogReset;
  Begin
  NumSeen := 0;
  End;


Procedure BbsLog(S: String);
  Var
    i: Word;
    Key: String[120];

  Begin
  If @LogHook = Nil Then
    Exit;
  Key := Copy(S, 1, 120);
  For i := 1 To NumSeen Do
    If Seen[i] = Key Then
      Exit;
  If NumSeen < MaxSeen Then
    Begin
    Inc(NumSeen);
    Seen[NumSeen] := Key;
    End;
  LogHook(S);
  End;


Begin
LogHook := Nil;
NumSeen := 0;
End.
