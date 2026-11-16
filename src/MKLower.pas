Program MKLower;

{$I MKB.Def}

{
     mklower [-w]

     Names are exact: the programs look for a file in the spelling the configuration or the menu gives, and
     the files they name themselves (config.mk, top.mnu ...) are lower case.  A BBS that was set up in DOS has
     references in mixed or upper case ("PROMPTS", a menu that goes to "REALTOP", a screen "Today") and the
     files may have been renamed to lower case since.  This program makes the references lower case:

        config.mk     the language file names of the languages (PROMPTS -> prompts)
        *.mnu         the name in the Data of the commands that take one: go to menu (1), gosub (2), clear gosub
                      and go to menu (4), screen (5), bulletin (6), questionnaire (12), screen with hot-keys (40),
                      screen with press enter (45) - the first word only, what follows (/M=116 ...) stays

     Directories and names of the files themselves are not touched, and neither are the paths and program
     names in other commands (7, 31, 48, 150 ...): they are used as they are.  The menus are those in the menu
     directories of the languages (mkconfig: General > Language).

     Without -w nothing is changed: it only lists what would be.  With -w each changed file is first copied
     to <name>.mixedcase (an existing copy is kept), then written.  The BBS is the one the environment
     variable MK names, as for mk.  Run it again and it finds nothing to do.

     Also listed, not changed: *.mnu files whose own name is not lower case (the programs would not find them) and
     references whose file is not there in that spelling.
}

Uses
  Dos, MKString, MKGlobT, MKFile, MKCfgAbs, MKCfgMK;


Const
  NameTypes = [1, 2, 4, 5, 6, 12, 40, 45];


Var
  Write_: Boolean;
  Cfg: MKCfgObjPtr;
  Changes, Warnings: Word;
  Done: Array[1..10] Of String;
  NumDone: Word;
  i, j: Word;


Function LowerStr(S: String): String;
  Var
    k: Word;

  Begin
  For k := 1 To Length(S) Do
    S[k] := LoCase(S[k]);
  LowerStr := S;
  End;


Function IsLower(S: String): Boolean;
  Begin
  IsLower := S = LowerStr(S);
  End;


Function FirstWord(S: String): String;
  Var
    p: Word;

  Begin
  p := Pos(' ', S);
  If p = 0 Then
    FirstWord := S
  Else
    FirstWord := Copy(S, 1, p - 1);
  End;


Function Backup(FN: String): Boolean;
  {A copy of the file next to it, once}
  Var
    Src, Dst: File;
    Buf: Array[1..4096] Of Byte;
    N, W: Word;
    BN: String;
    OldMode: Byte;

  Begin
  Backup := False;
  OldMode := FileMode;
  BN := FN + '.mixedcase';
  If FileExist(BN) Then
    Begin
    Backup := True;
    Exit;
    End;
  Assign(Src, FN);
  Assign(Dst, BN);
  FileMode := 0;
  Reset(Src, 1);
  If IoResult <> 0 Then
    Begin
    FileMode := OldMode;
    Exit;
    End;
  Rewrite(Dst, 1);
  If IoResult <> 0 Then
    Begin
    Close(Src);
    FileMode := OldMode;
    Exit;
    End;
  Repeat
    BlockRead(Src, Buf, SizeOf(Buf), N);
    If N > 0 Then
      BlockWrite(Dst, Buf, N, W);
  Until (N = 0) Or (IoResult <> 0);
  Close(Src);
  Close(Dst);
  FileMode := OldMode;
  Backup := True;
  End;


Procedure DoLanguages;
  {The language file names are String[8] fields, an array in Config.Mk: patch the file itself, so that nothing else in
   it changes (a load and save would write the paths expanded)}
  Var
    Probe: ^BbsCfg;
    Ofs: LongInt;
    F: File;
    FN: String;
    Rec: String[8];
    n: Word;
    Saved: Boolean;

  Begin
  New(Probe);
  Ofs := LongInt(PtrUInt(@Probe^.LangFile[1]) - PtrUInt(Probe));
  FN := Cfg^.FindBbsFile('config.mk') + 'config.mk';
  Dispose(Probe);
  Assign(F, FN);
  FileMode := 2;
  Reset(F, 1);
  If IoResult <> 0 Then
    Begin
    WriteLn('Cannot open ', FN);
    Inc(Warnings);
    Exit;
    End;
  Saved := False;
  For n := 1 To 10 Do
    Begin
    Seek(F, Ofs + LongInt(n - 1) * SizeOf(Rec));
    BlockRead(F, Rec, SizeOf(Rec));
    If (Length(Rec) > 0) And (Not IsLower(Rec)) Then
      Begin
      WriteLn('config.mk: language ', n, ' file name ', Rec, ' -> ', LowerStr(Rec));
      Inc(Changes);
      If Write_ Then
        Begin
        If Not Saved Then
          Begin
          Saved := True;
          If Not Backup(FN) Then
            Begin
            WriteLn('cannot make the copy of config.mk: left as it is');
            Inc(Warnings);
            Break;
            End;
          End;
        Rec := LowerStr(Rec);
        Seek(F, Ofs + LongInt(n - 1) * SizeOf(Rec));
        BlockWrite(F, Rec, SizeOf(Rec));
        End;
      End;
    End;
  Close(F);
  End;


Procedure DoMenuDir(Dir: String);
  Var
    SR: SearchRec;
    F: File;
    M: ^MenuType;
    FN, Old, W: String;
    n, NumRec: LongInt;
    Got: Word;
    Changed: Boolean;
    L: LongInt;

  Begin
  AddBackSlash(Dir);
  WriteLn('menus in ', Dir);
  FindFirst(Dir + '*', Archive + ReadOnly, SR);
  While DosError = 0 Do
    Begin
    If (Length(SR.Name) > 4) And (LowerStr(Copy(SR.Name, Length(SR.Name) - 3, 4)) = '.mnu') Then
      Begin
      If Not IsLower(SR.Name) Then
        Begin
        WriteLn('  ', SR.Name, ': the file name is not lower case: mk will not find this menu');
        Inc(Warnings);
        End
      Else
        Begin
        FN := Dir + SR.Name;
        New(M);
        Assign(F, FN);
        FileMode := 2;
        Reset(F, SizeOf(MenuType));
        If IoResult = 0 Then
          Begin
          NumRec := FileSize(F);
          Changed := False;
          For n := 1 To NumRec - 1 Do
            Begin
            Seek(F, n);
            BlockRead(F, M^, 1, Got);
            If (Got = 1) And (M^.Typ In NameTypes) And (Length(M^.Data) > 0) Then
              Begin
              Old := M^.Data;
              W := FirstWord(Old);
              If Not IsLower(W) Then
                Begin
                WriteLn('  ', SR.Name, ' item ', n, ' (type ', M^.Typ, '): ', Old, ' -> ',
                  LowerStr(W) + Copy(Old, Length(W) + 1, 80));
                Inc(Changes);
                If Write_ Then
                  Begin
                  If Not Changed Then
                    Begin
                    Close(F);
                    If Not Backup(FN) Then
                      Begin
                      WriteLn('  cannot make the copy of ', SR.Name, ': left as it is');
                      Inc(Warnings);
                      Break;
                      End;
                    Reset(F, SizeOf(MenuType));
                    Changed := True;
                    End;
                  M^.Data := LowerStr(W) + Copy(Old, Length(W) + 1, 80);
                  Seek(F, n);
                  BlockWrite(F, M^, 1);
                  If IoResult <> 0 Then
                    Begin
                    WriteLn('  cannot write ', SR.Name);
                    Inc(Warnings);
                    Break;
                    End;
                  End;
                End;
              End;
            End;
          Close(F);
          End;
        Dispose(M);
        End;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  End;


Begin
Write_ := False;
For i := 1 To ParamCount Do
  If ParamStr(i) = '-w' Then
    Write_ := True
  Else
    Begin
    WriteLn('Usage: mklower [-w]    (without -w: only list what would be changed)');
    Halt(2);
    End;
If DetectBbsType <> 1 Then
  Begin
  WriteLn(StdErr, 'mklower: set MK to the BBS configuration directory (it works on the MK format)');
  Halt(1);
  End;
Cfg := New(MKCfgObjPtr, Init);
Config := Cfg;
Cfg^.Load;
If Cfg^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, 'mklower: ', Cfg^.GetError, ': error loading the configuration files');
  Halt(1);
  End;
Changes := 0;
Warnings := 0;
NumDone := 0;
DoLanguages;
For i := 1 To 10 Do
  If Length(Cfg^.GetMnuPath(i)) > 0 Then
    Begin
    j := 1;
    While (j <= NumDone) And (Done[j] <> Cfg^.GetMnuPath(i)) Do
      Inc(j);
    If j > NumDone Then
      Begin
      Inc(NumDone);
      Done[NumDone] := Cfg^.GetMnuPath(i);
      DoMenuDir(Done[NumDone]);
      End;
    End;
WriteLn;
If Changes = 0 Then
  WriteLn('Nothing to do: every reference is lower case.')
Else If Write_ Then
  WriteLn(Changes, ' reference(s) made lower case (the files before: <name>.mixedcase).')
Else
  WriteLn(Changes, ' reference(s) would be made lower case.  Run  mklower -w  to do it.');
If Warnings > 0 Then
  WriteLn(Warnings, ' warning(s) above.');
End.
