Program MKPwConv;

{$I MKB.Def}

{
     mkpwconv -x [directory]

     Expands extusers.bbs to the record of this version.  The extended user record has a block at its end for a hashed
     password (and 128 bytes kept for later); the file of the DOS version, or of an earlier build, has the shorter
     record, and the programs refuse to run on it (they say so).  One run on each BBS makes the file right: every record
     gets the empty hash block (the password stays in Users.Bbs as it was).

       directory   the BBS configuration directory (default: the environment variable MK)

     The old file is kept as extusers.bbs.old (nothing is done when that exists already, so a backup is never replaced).
     A file that is of the new size already is left alone.

     Exit status: 0 done or nothing to do, 1 the file could not be read or written, 2 the size fits neither record, 3 a
     backup of an earlier run is in the way.
}

Uses Dos, MKString, MKFile, MKPwd, MKRCfgMK;


Var
  Dir, FN, Bak: String;
  Old, New: Word;
  Fi, Fo: File;
  Buf: Array[1..4096] Of Byte;
  Zero: Array[1..4096] Of Byte;
  Rd, Wr: Word;
  Recs, i: LongInt;

Begin
If (ParamCount < 1) Or (Upper(ParamStr(1)) <> '-X') Then
  Begin
  WriteLn('mkpwconv -x [directory]   expand extusers.bbs to the record with the password hash block');
  Halt(1);
  End;
If ParamCount >= 2 Then
  Dir := ParamStr(2)
Else
  Dir := GetEnv('MK');
If Dir = '' Then
  Begin
  WriteLn('No BBS directory: give it or set MK');
  Halt(1);
  End;
If Dir[Length(Dir)] <> '/' Then
  Dir := Dir + '/';
FN := Dir + 'extusers.bbs';
Bak := FN + '.old';
Old := ExtUsersOldSize;
New := ExtUsersNewSize;
Case ExtUsersFormat(FN) Of
  0: Begin
     WriteLn(FN, ': nothing to do');
     Halt(0);
     End;
  2: Begin
     WriteLn(FN, ': the size ', SizeFile(FN), ' fits neither the old record (', Old, ') nor the new one (', New, ')');
     Halt(2);
     End;
  End;
If FileExist(Bak) Then
  Begin
  WriteLn(Bak, ' exists: move it away first');
  Halt(3);
  End;
Recs := SizeFile(FN) Div Old;
{the old file is kept: renamed, then the new one is written next to it}
Assign(Fi, FN);
Rename(Fi, Bak);
If IoResult <> 0 Then
  Begin
  WriteLn('Cannot rename ', FN);
  Halt(1);
  End;
Assign(Fi, Bak);
FileMode := 0;
Reset(Fi, 1);
Assign(Fo, FN);
Rewrite(Fo, 1);
If IoResult <> 0 Then
  Begin
  WriteLn('Cannot write ', FN);
  Halt(1);
  End;
FillChar(Zero, SizeOf(Zero), 0);
For i := 1 To Recs Do
  Begin
  Rd := 0;
  While Rd < Old Do
    Begin
    Wr := Old - Rd;
    If Wr > SizeOf(Buf) Then Wr := SizeOf(Buf);
    BlockRead(Fi, Buf, Wr, Wr);
    If Wr = 0 Then
      Begin
      WriteLn('Cannot read ', Bak);
      Halt(1);
      End;
    BlockWrite(Fo, Buf, Wr);
    Rd := Rd + Wr;
    End;
  BlockWrite(Fo, Zero, New - Old);
  End;
Close(Fi);
Close(Fo);
If IoResult <> 0 Then;
WriteLn(FN, ': ', Recs, ' records expanded from ', Old, ' to ', New, ' bytes (the old file: ', Bak, ')');
End.
