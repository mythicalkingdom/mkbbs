{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKHatch;

{$I MKB.Def}

{
     mkhatch -a <TAG> [-d <description>] [-l <long description line>]... [-r <replaces>] [-m <magic>] [-x] [-b mkbink] [-q] file ...

     Puts files into a file echo (TIC, see TIC-PLAN.md).  For each file: it is stored in the file area of the echo (copied, or moved with -x;
     the old file of that name and the files that -r names go, the line in files.bbs is made), and a TIC and the file go to each echo system the
     echo goes to (EchoMail > File Echoes > Echo To): they are given to the mailer (mkbink queue) and wait in the spool of the file
     echoes.  The echo has no file area of its own (pass-through): the file is only passed on, and with -x deleted afterwards.

        -a   the file echo (its tag, not case sensitive)
        -d   one line about the file (the Desc line); default: the name of the file
        -l   a line of the long description (the Ldesc lines): can be given more than once
        -r   a name (with * and ?) of files of the echo that this one replaces
        -m   a magic name for file requests
        -x   move the file instead of copying it
        -b   the mkbink program (default: next to mkhatch, else in the path)
        -q   say nothing except errors

     Exit status 0: done; 1: wrong call or no configuration; 2: a file could not be hatched.
     MK names the BBS configuration directory.  Runs one at a time with mktoss (the lock mktoss.lock in the inbound).
}

Uses
  BaseUnix, Unix, Dos, MKString, MKGlobT, MKFile, MKCfgAbs, MKCfgMK, MKCfgNew, MKTic, MKTicToss, MKBinkQ;

Var
  Quiet: Boolean;
  Tag, Desc, Repl, Magic: String;
  Ldesc: Array[1..TicMaxLdesc] Of String[250];
  NumLdesc: Word;
  MoveIt: Boolean;
  Files: Array[1..100] Of String;
  NumFiles: Word;
  i: Word;
  H: HatchSpec;
  Msg, InDir, OutDir, LogName: String;
  Failed: Boolean;
  A: AddrType;
  Fd: LongInt;
  Ours: Array[1..10] Of AddrType;
  NumOurs: Word;


Procedure Say(S: String);
  Var
    T: Text;

  Begin
  If Not Quiet Then
    WriteLn(S);
  If LogName <> '' Then
    Begin
    Assign(T, LogName);
    {$I-}
    Append(T);
    If IoResult <> 0 Then
      Rewrite(T);
    If IoResult = 0 Then
      Begin
      WriteLn(T, 'mkhatch: ', S);
      Close(T);
      End;
    If IoResult <> 0 Then;
    End;
  End;


Function HatchOurs(S: String): Boolean;
  Var
    X: AddrType;
    k: Word;

  Begin
  HatchOurs := False;
  If NumOurs = 0 Then
    Exit;
  If ParseAddr(S, Ours[1], X) Then
    For k := 1 To NumOurs Do
      If (Ours[k].Zone = X.Zone) And (Ours[k].Net = X.Net) And (Ours[k].Node = X.Node) And (Ours[k].Point = X.Point) Then
        HatchOurs := True;
  End;


Function HatchOurAddr(Sys: Word): String;
  Begin
  HatchOurAddr := AddrStr(Ours[1]);
  End;


Begin
Quiet := False;
Tag := ''; Desc := ''; Repl := ''; Magic := '';
NumLdesc := 0; NumFiles := 0; MoveIt := False;
i := 1;
While i <= ParamCount Do
  Begin
  If ParamStr(i) = '-q' Then
    Quiet := True
  Else If ParamStr(i) = '-x' Then
    MoveIt := True
  Else If (ParamStr(i) = '-a') And (i < ParamCount) Then
    Begin Inc(i); Tag := ParamStr(i); End
  Else If (ParamStr(i) = '-d') And (i < ParamCount) Then
    Begin Inc(i); Desc := ParamStr(i); End
  Else If (ParamStr(i) = '-r') And (i < ParamCount) Then
    Begin Inc(i); Repl := ParamStr(i); End
  Else If (ParamStr(i) = '-m') And (i < ParamCount) Then
    Begin Inc(i); Magic := ParamStr(i); End
  Else If (ParamStr(i) = '-b') And (i < ParamCount) Then
    Begin Inc(i); BinkProg := ParamStr(i); End
  Else If (ParamStr(i) = '-l') And (i < ParamCount) Then
    Begin
    Inc(i);
    If NumLdesc < TicMaxLdesc Then
      Begin
      Inc(NumLdesc);
      Ldesc[NumLdesc] := ParamStr(i);
      End;
    End
  Else If (ParamStr(i) <> '') And (ParamStr(i)[1] <> '-') Then
    Begin
    If NumFiles < 100 Then
      Begin
      Inc(NumFiles);
      Files[NumFiles] := ParamStr(i);
      End;
    End
  Else
    Begin
    WriteLn(StdErr, 'Usage: mkhatch -a <TAG> [-d <description>] [-l <long description line>]... [-r <replaces>] [-m <magic>] [-x] [-b mkbink] [-q] file ...');
    Halt(1);
    End;
  Inc(i);
  End;
If (Tag = '') Or (NumFiles = 0) Then
  Begin
  WriteLn(StdErr, 'Usage: mkhatch -a <TAG> [-d <description>] [-l <long description line>]... [-r <replaces>] [-m <magic>] [-x] [-b mkbink] [-q] file ...');
  Halt(1);
  End;
If DetectBbsType <> 1 Then
  Begin
  WriteLn(StdErr, 'mkhatch: set MK to the BBS configuration directory');
  Halt(1);
  End;
Config := NewMKConfig(False);
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, 'mkhatch: ', Config^.GetError, ': error loading the configuration files');
  Halt(1);
  End;
LogName := StripBoth(Config^.GetEchoLog, ' ');
InDir := StripBoth(Config^.GetEchoInPath, ' ');
OutDir := StripBoth(Config^.GetEchoOutPath, ' ');
If (InDir = '') Or (OutDir = '') Then
  Begin
  WriteLn(StdErr, 'mkhatch: no InBound or OutBound path (EchoMail Options)');
  Halt(1);
  End;
If InDir[Length(InDir)] <> '/' Then
  InDir := InDir + '/';
If OutDir[Length(OutDir)] <> '/' Then
  OutDir := OutDir + '/';
NumOurs := 0;
For i := 1 To 10 Do
  Begin
  Config^.GetAddr(i, A);
  If A.Zone <> 0 Then
    Begin
    Inc(NumOurs);
    Ours[NumOurs] := A;
    End;
  End;
If NumOurs = 0 Then
  Begin
  WriteLn(StdErr, 'mkhatch: the BBS has no address (General > Addresses)');
  Halt(1);
  End;
BinkOutDir := OutDir;
BinkZone := Ours[1].Zone;
BinkLog := Say;
TicLog := Say;
TicQueue := BinkQueue;
TicFlavour := EchoFlavour;
TicOurAddr := HatchOurAddr;
TicIsOurs := HatchOurs;
TicSpoolDir := OutDir + 'mktoss/tic/';
{$I-}
MkDir(Copy(InDir, 1, Length(InDir) - 1));
MkDir(Copy(OutDir, 1, Length(OutDir) - 1));
MkDir(Copy(OutDir, 1, Length(OutDir)) + 'mktoss');
If IoResult <> 0 Then;
Fd := fpOpen(InDir + 'mktoss.lock', O_WRONLY Or O_CREAT, $1B6);
If Fd >= 0 Then
  fpFlock(Fd, LOCK_EX);
Failed := False;
For i := 1 To NumFiles Do
  Begin
  FillChar(H, SizeOf(H), 0);
  H.Tag := Tag;
  H.FileName := Files[i];
  H.Desc := Desc;
  If H.Desc = '' Then
    Begin
    H.Desc := Files[i];
    While Pos('/', H.Desc) > 0 Do
      Delete(H.Desc, 1, Pos('/', H.Desc));
    End;
  H.Replaces := Repl;
  H.Magic := Magic;
  H.NumLdesc := NumLdesc;
  Move(Ldesc, H.Ldesc, SizeOf(H.Ldesc));
  H.Move := MoveIt;
  If TicHatch(H, Msg) Then
    Say(Msg)
  Else
    Begin
    Failed := True;
    WriteLn(StdErr, 'mkhatch: ', Files[i], ': ', Msg);
    End;
  End;
If Failed Then
  Halt(2);
End.
