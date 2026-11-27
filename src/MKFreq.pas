{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKFreq;

{$I MKB.Def}

{
     mkfreq <requester> <secure|unsecure> <request file> <answer file>
     mkfreq -S <srif file>

     Answers an FTN file request (FTS-0006): the command that mkbink runs for each .req it receives (the "on-freq" line of
     its settings, which mkbinkcfg writes when Mailer > File requests is on).  Which BBS it works for comes from the
     environment variable MK, as for mk and mkconfig.

       requester      the address of the system that asked (1:110/290)
       secure         the session had a password (unsecure: it had none)
       request file   one request per line:  name [!password] [+time | -time]
                      (the time is an update request, UNIX seconds: + = the files that match and are newer than that time,
                      - = those dated up to and including it; the dates are those of the files)
       answer file    what this program writes for mkbink: tab separated lines
                        SEND<TAB>/absolute/path          send the file, keep it
                        SEND<TAB>/absolute/path<TAB>^    send it, delete it after (a list made for this request)
                        NOTE<TAB>text                    what was refused or not found, and why

     mkfreq -S <srif file> is the same for a mailer that speaks SRIF (FSC-0086 / FSP-1040), such as binkd:

          exec "mkfreq -S *S" *.req                       (binkd.cfg: *S is the SRIF file)

     The requester is the first AKA, secure is RemoteStatus PROTECTED, the request file is RequestList and what is found goes
     to ResponseList, one name a line: "+" in front keeps the file, "=" erases it after it was sent (only the list that this
     program makes for a "@LIST" name has it; no file of a file area is ever marked).  There are no NOTE lines then; the netmail
     note of "Tell by netmail" is made as usual.  The environment variable MKBINK_TMP (mkbink sets it) names the directory for
     the list; without it the list is made next to the response list.

     What a system may have:

       * A security profile (level and flags like a caller's): the one of its link in Mailer Links (File request access), or,
         when that is blank (level 0), the global "file request security" of the File Requests page.  A system gets what a caller with that
         security could list and download: only file areas that have the option "Allow file requests" (mkconfig, Files), whose
         listing and download security the profile meets.
       * Magic names: the file named in the Mailer page ("Magic names file"), lines   NAME  path  [password]   (; or # starts a
         comment).  The path may have * and ? in its last part; "@LIST" makes a list of the files the profile may request
         (the name of the request becomes the name of the list file, kept for the one request).  A magic name is not looked up
         in the file areas.  Its password (if there is one) must follow the name in the request, "!password", and the session
         must be secure.
       * Otherwise the name (wildcards * and ?, not case sensitive) is looked for in the files of those file areas.
       * Limits: files and kilobytes per request (the Mailer page); what is over is not sent and said so.  mkbink keeps its own
         limits as well.
       * A name with a slash or a backslash, or that starts with a dot, a plus or a minus, is not a file name and is refused.

     Output on standard output is the log of mkbink (one line per request, passwords are not written).  Exit status: 0 answered
     (also when nothing was found), 1 the configuration or the files of the request could not be read.
}

Uses
  BaseUnix, Dos, MKString, MKFile, MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKWild;


Const
  MaxFound = 200;
  DefaultMaxFiles = 20;
  MaxReport = 60;

Var
  M: ^MailerCfgType;
  Secure: Boolean;
  SrifMode: Boolean;                   {mkfreq -S: an SRIF file in, a response list out}
  Who, ReqFile, AnsFile: String;
  Requester: AddrType;
  Profile: SecType;
  MaxFiles: LongInt;
  MaxKb: LongInt;
  Ans: Text;
  Sent: Array[1..MaxFound] Of String[200];
  NSent: Word;
  TotalBytes: LongInt;
  MagicN: Word;
  MagicName: Array[1..60] Of String[20];
  MagicPath: Array[1..60] Of String[120];
  MagicPwd: Array[1..60] Of String[20];
  CurSign: Char;                                 {the request line asks for files + newer than, - up to and including, CurTime}
  CurTime: Int64;
  NameMatches: Word;                             {files whose name matched, before the date was looked at}
  Report: Array[1..MaxReport] Of String[100];   {what was refused or not found: the text of the netmail}
  NReport: Word;


Function ReadSrif(Const Name: String): Boolean;
  {The SRIF file of the mailer: the first AKA is who asked, RemoteStatus says secure, RequestList and ResponseList the files}
  Var
    F: Text;
    L, Key, Val: String;
    p: Word;
    GotAka: Boolean;

  Begin
  ReadSrif := False;
  Who := '';
  ReqFile := '';
  AnsFile := '';
  Secure := False;
  GotAka := False;
  Assign(F, Name);
  FileMode := 0;
  Reset(F);
  If IoResult <> 0 Then
    Exit;
  While Not Eof(F) Do
    Begin
    ReadLn(F, L);
    L := StripBoth(L, ' ');
    p := Pos(' ', L);
    If p > 0 Then
      Begin
      Key := Upper(Copy(L, 1, p - 1));
      Val := StripBoth(Copy(L, p + 1, 250), ' ');
      If (Key = 'AKA') And (Not GotAka) Then
        Begin
        p := Pos('@', Val);
        If p > 0 Then
          Val := Copy(Val, 1, p - 1);                {the domain is not part of the address here}
        Who := Val;
        GotAka := True;
        End
      Else If Key = 'REQUESTLIST' Then
        ReqFile := Val
      Else If Key = 'RESPONSELIST' Then
        AnsFile := Val
      Else If Key = 'REMOTESTATUS' Then
        Secure := Upper(Val) = 'PROTECTED';
      End;
    End;
  Close(F);
  If IoResult <> 0 Then;
  ReadSrif := (Who <> '') And (ReqFile <> '') And (AnsFile <> '');
  End;


Procedure Note(Const S: String);
  Begin
  If Not SrifMode Then
    WriteLn(Ans, 'NOTE', #9, S);
  If NReport < MaxReport Then
    Begin
    Inc(NReport);
    Report[NReport] := Copy(S, 1, 100);
    End;
  End;


Procedure LogLine(Const S: String);
  Begin
  WriteLn('mkfreq: ', S);
  End;


Function Mask(Const S: String): String;
  {a request line with its password hidden}
  Var
    p: Word;

  Begin
  p := Pos(' !', S);
  If p > 0 Then
    Mask := Copy(S, 1, p + 1) + '***'
  Else
    Mask := S;
  End;


Function AbsPath(P: String): String;
  Begin
  If (P <> '') And (P[1] <> '/') Then
    P := Config^.GetBbsPath + P;
  AbsPath := P;
  End;


Function WithSlash(P: String): String;
  Begin
  If (P <> '') And (P[Length(P)] <> '/') Then
    P := P + '/';
  WithSlash := P;
  End;


Function AlreadySent(Const P: String): Boolean;
  Var
    i: Word;

  Begin
  AlreadySent := False;
  For i := 1 To NSent Do
    If Sent[i] = P Then
      AlreadySent := True;
  End;


Function FileSizeOf(Const P: String): LongInt;
  Var
    SR: SearchRec;

  Begin
  FileSizeOf := -1;
  FindFirst(P, AnyFile, SR);
  If DosError = 0 Then
    FileSizeOf := SR.Size;
  FindClose(SR);
  End;


{ the file is queued for sending unless a limit says no; Delete = send it and delete it after.  False: a limit was reached (said) }
Function AddFile(Const Path: String; Delete: Boolean; Const Req: String): Boolean;
  Var
    Sz: LongInt;

  Begin
  AddFile := True;
  If AlreadySent(Path) Then
    Exit;
  Sz := FileSizeOf(Path);
  If Sz < 0 Then
    Exit;
  If (MaxFiles > 0) And (NSent >= MaxFiles) Then
    Begin
    Note(Req + ': stopped, at most ' + Long2Str(MaxFiles) + ' files for one request');
    AddFile := False;
    Exit;
    End;
  If (MaxKb > 0) And ((TotalBytes + Sz) Div 1024 > MaxKb) Then
    Begin
    Note(Req + ': stopped, at most ' + Long2Str(MaxKb) + ' KB for one request');
    AddFile := False;
    Exit;
    End;
  If NSent >= MaxFound Then
    Begin
    AddFile := False;
    Exit;
    End;
  Inc(NSent);
  Sent[NSent] := Path;
  Inc(TotalBytes, Sz);
  If SrifMode Then
    Begin
    If Delete Then
      WriteLn(Ans, '=', Path)
    Else
      WriteLn(Ans, '+', Path);
    End
  Else
    Begin
    Write(Ans, 'SEND', #9, Path);
    If Delete Then
      Write(Ans, #9, '^');
    WriteLn(Ans);
    End;
  End;


{ the modification time of a file, UNIX seconds (UTC) }
Function FileTime(Const P: String): Int64;
  Var
    St: Stat;

  Begin
  FileTime := 0;
  If fpStat(P, St) = 0 Then
    FileTime := St.st_mtime;
  End;


{ does the date of the file fit the update request of the line (none: always)? }
Function DateOk(Const P: String): Boolean;
  Begin
  DateOk := True;
  If CurSign = '+' Then
    DateOk := FileTime(P) > CurTime
  Else If CurSign = '-' Then
    DateOk := FileTime(P) <= CurTime;
  End;


{ the files of one directory (or the one file) that match Pattern, which may have * and ? in its last part }
Function AddMatching(Dir, Pattern, Req: String): Word;
  Var
    SR: SearchRec;
    Found: Word;
    More: Boolean;

  Begin
  Found := 0;
  More := True;
  Dir := WithSlash(Dir);
  FindFirst(Dir + '*', AnyFile, SR);
  While (DosError = 0) And More Do
    Begin
    If (SR.Attr And Directory) = 0 Then
      If DosMatch(Upper(Pattern), Upper(SR.Name)) Then
        Begin
        Inc(NameMatches);
        If DateOk(Dir + SR.Name) Then
          Begin
          Inc(Found);
          More := AddFile(Dir + SR.Name, False, Req);
          End;
        End;
    FindNext(SR);
    End;
  FindClose(SR);
  AddMatching := Found;
  End;


{ does the profile meet a security requirement? }
Function Meets(Var Need: SecType): Boolean;
  Begin
  Meets := Access(Profile, Need);
  End;


Function AreaAllowed(i: Word): Boolean;
  Var
    V, D: SecType;

  Begin
  AreaAllowed := False;
  If Config^.GetFileAreaName(i) = '' Then
    Exit;
  If Not Config^.GetFileFreq(i) Then
    Exit;
  If Config^.GetFileAreaPath(i) = '' Then
    Exit;
  Config^.GetFileViewSecurity(i, V);
  Config^.GetFileDLSecurity(i, D);
  AreaAllowed := Meets(V) And Meets(D);
  End;


Var
  Searched, NoFreq, Blocked, Missing: String;           {what the last search looked at and why it left areas out (for the log)}


Procedure AddName(Var L: String; Const S: String);
  Begin
  If Length(L) < 150 Then
    Begin
    If L <> '' Then
      L := L + ', ';
    L := L + S;
    End;
  End;


Function SearchAreas(Pattern, Req: String): Word;
  Var
    i: Word;
    Found: Word;
    V, D: SecType;
    St: Stat;

  Begin
  Found := 0;
  Searched := '';
  NoFreq := '';
  Blocked := '';
  Missing := '';
  For i := 1 To Config^.GetMaxFileAreas Do
    If (Config^.GetFileAreaName(i) <> '') And (Config^.GetFileAreaPath(i) <> '') Then
      Begin
      If Not Config^.GetFileFreq(i) Then
        AddName(NoFreq, Config^.GetFileAreaName(i))
      Else If AreaAllowed(i) Then
        Begin
        AddName(Searched, Config^.GetFileAreaName(i));
        If fpStat(AbsPath(Config^.GetFileAreaPath(i)), St) <> 0 Then
          AddName(Missing, Config^.GetFileAreaName(i) + ' (' + Config^.GetFileAreaPath(i) + ')');
        Found := Found + AddMatching(AbsPath(Config^.GetFileAreaPath(i)), Pattern, Req);
        End
      Else
        Begin
        Config^.GetFileViewSecurity(i, V);
        Config^.GetFileDLSecurity(i, D);
        AddName(Blocked, Config^.GetFileAreaName(i) + ' (view ' + Long2Str(V.Level) + ', download ' + Long2Str(D.Level) + ')');
        End;
      End;
  SearchAreas := Found;
  End;


{ a list of the files the profile may request, in a file next to the answer file }
Function MakeList(Name: String; Var ListPath: String): Boolean;
  Var
    T: Text;
    i: Word;
    SR: SearchRec;
    Dir: String;
    p: Word;
    N: LongInt;

  Begin
  MakeList := False;
  p := Length(AnsFile);
  While (p > 0) And (AnsFile[p] <> '/') Do
    Dec(p);
  Dir := Copy(AnsFile, 1, p);
  If GetEnv('MKBINK_TMP') <> '' Then
    Dir := WithSlash(GetEnv('MKBINK_TMP'));       {the one place whose files may be deleted after they were sent}
  ListPath := Dir + Lower(Name) + '.lst';
  Assign(T, ListPath);
  Rewrite(T);
  If IoResult <> 0 Then
    Exit;
  WriteLn(T, 'Files that can be requested from ', Config^.GetBbsName);
  WriteLn(T);
  N := 0;
  For i := 1 To Config^.GetMaxFileAreas Do
    If AreaAllowed(i) Then
      Begin
      WriteLn(T, Config^.GetFileAreaName(i));
      Dir := WithSlash(AbsPath(Config^.GetFileAreaPath(i)));
      FindFirst(Dir + '*', AnyFile, SR);
      While DosError = 0 Do
        Begin
        If (SR.Attr And Directory) = 0 Then
          Begin
          WriteLn(T, '  ', PadRight(SR.Name, ' ', 14), SR.Size:10);
          Inc(N);
          End;
        FindNext(SR);
        End;
      FindClose(SR);
      WriteLn(T);
      End;
  WriteLn(T, N, ' file(s)');
  Close(T);
  MakeList := IoResult = 0;
  End;


Procedure LoadMagic;
  Var
    T: Text;
    L, W1, W2, W3: String;

  Begin
  MagicN := 0;
  If M^.ReqMagicFile = '' Then
    Exit;
  Assign(T, AbsPath(M^.ReqMagicFile));
  Reset(T);
  If IoResult <> 0 Then
    Begin
    LogLine('cannot read the magic names file ' + AbsPath(M^.ReqMagicFile));
    Exit;
    End;
  While Not Eof(T) Do
    Begin
    ReadLn(T, L);
    L := StripBoth(L, ' ');
    If (L = '') Or (L[1] = ';') Or (L[1] = '#') Then
      Continue;
    W1 := ExtractWord(L, 1);
    W2 := ExtractWord(L, 2);
    W3 := ExtractWord(L, 3);
    If (W1 = '') Or (W2 = '') Or (MagicN >= 60) Then
      Continue;
    Inc(MagicN);
    MagicName[MagicN] := Upper(W1);
    MagicPath[MagicN] := W2;
    MagicPwd[MagicN] := W3;
    End;
  Close(T);
  If IoResult <> 0 Then;
  End;


Function FindMagic(Name: String): Word;
  Var
    i: Word;

  Begin
  FindMagic := 0;
  For i := 1 To MagicN Do
    If MagicName[i] = Upper(Name) Then
      FindMagic := i;
  End;


Function SamePwd(A, B: String): Boolean;
  Begin
  SamePwd := (Upper(A) = Upper(B));
  End;


Function ValidName(Const N: String): Boolean;
  Var
    i: Word;

  Begin
  ValidName := False;
  If (N = '') Or (N[1] = '.') Or (N[1] = '+') Or (N[1] = '-') Then
    Exit;
  For i := 1 To Length(N) Do
    If (N[i] = '/') Or (N[i] = '\') Or (N[i] < ' ') Then
      Exit;
  ValidName := True;
  End;


Procedure MakeDirs(Path: String);
  {every directory of Path (ending in /)}
  Var
    i: Word;

  Begin
  For i := 2 To Length(Path) Do
    If Path[i] = '/' Then
      Begin
      MkDir(Copy(Path, 1, i - 1));
      If IoResult <> 0 Then;
      End;
  End;


{ the netmail that tells the requester what could not be sent: a note for mktoss, which posts it }
Procedure WriteNote;
  Var
    T: Text;
    Dir, Name: String;
    i: Word;
    Us: AddrType;
    Hh, Mm, Ss, Hs: Word;

  Begin
  Dir := StripBoth(Config^.GetEchoOutPath, ' ');
  If Dir = '' Then
    Begin
    LogLine('no OutBound path (EchoMail Options): no note for the requester');
    Exit;
    End;
  Dir := AbsPath(WithSlash(Dir)) + 'mktoss/freq/';
  MakeDirs(Dir);
  GetTime(Hh, Mm, Ss, Hs);
  Name := Dir + Long2Str(Hh * 3600 + Mm * 60 + Ss) + '-' + Long2Str(Random(100000)) + '.note';
  Assign(T, Name);
  Rewrite(T);
  If IoResult <> 0 Then
    Begin
    LogLine('cannot write the note ' + Name);
    Exit;
    End;
  Config^.GetAddr(1, Us);
  WriteLn(T, 'TO ', Who);
  WriteLn(T, 'SUBJECT Your file request to ', AddrStr(Us));
  WriteLn(T);
  WriteLn(T, 'You asked ', Config^.GetBbsName, ' (', AddrStr(Us), ') for files.');
  WriteLn(T);
  WriteLn(T, 'Not sent:');
  For i := 1 To NReport Do
    WriteLn(T, '  ', Report[i]);
  WriteLn(T);
  If NSent > 0 Then
    WriteLn(T, NSent, ' file(s) are sent to you apart from these.')
  Else
    WriteLn(T, 'No file is sent.');
  Close(T);
  If IoResult <> 0 Then;
  LogLine('a note for the requester is written (' + Name + ')');
  End;


{ one line of the request file }
Procedure DoRequest(Line: String);
  Var
    Name, Pwd, Tok, Shown: String;
    i: Word;
    Mg: Word;
    Found: Word;
    ListPath: String;
    p: Word;
    Dir, Pat: String;
    Digits: Boolean;
    k: Word;

  Begin
  Line := StripBoth(Line, ' ');
  If Line = '' Then
    Exit;
  Shown := Mask(Line);
  Name := ExtractWord(Line, 1);
  Pwd := '';
  CurSign := ' ';
  CurTime := 0;
  For i := 2 To WordCount(Line) Do
    Begin
    Tok := ExtractWord(Line, i);
    If Tok[1] = '!' Then
      Pwd := Copy(Tok, 2, 20)
    Else If (Tok[1] = '+') Or (Tok[1] = '-') Then
      Begin
      Digits := (Length(Tok) >= 2) And (Length(Tok) <= 11);
      For k := 2 To Length(Tok) Do
        If Not (Tok[k] In ['0'..'9']) Then
          Digits := False;
      If Not Digits Then
        Begin
        Note(Name + ': the update request ' + Tok + ' is not a sign and a time (at most 10 digits)');
        LogLine(Shown + ': a bad update request');
        Exit;
        End;
      CurSign := Tok[1];
      CurTime := 0;
      For k := 2 To Length(Tok) Do
        CurTime := CurTime * 10 + (Ord(Tok[k]) - Ord('0'));
      End;
    End;
  NameMatches := 0;
  If Not ValidName(Name) Then
    Begin
    Note(Name + ': not a file name that can be requested');
    LogLine(Shown + ': not a valid name');
    Exit;
    End;
  Mg := FindMagic(Name);
  If Mg > 0 Then
    Begin
    If MagicPwd[Mg] <> '' Then
      Begin
      If Not Secure Then
        Begin
        Note(Name + ': needs a session with a password');
        LogLine(Shown + ': magic name needs a secure session');
        Exit;
        End;
      If Not SamePwd(Pwd, MagicPwd[Mg]) Then
        Begin
        Note(Name + ': the password is missing or wrong');
        LogLine(Shown + ': magic name, wrong or missing password');
        Exit;
        End;
      End;
    If Upper(MagicPath[Mg]) = '@LIST' Then
      Begin
      If MakeList(Name, ListPath) Then
        Begin
        If AddFile(ListPath, True, Name) Then;
        LogLine(Shown + ': the list of files');
        End
      Else
        Note(Name + ': the list could not be made');
      Exit;
      End;
    Pat := AbsPath(MagicPath[Mg]);
    p := Length(Pat);
    While (p > 0) And (Pat[p] <> '/') Do
      Dec(p);
    Dir := Copy(Pat, 1, p);
    Found := AddMatching(Dir, Copy(Pat, p + 1, 120), Name);
    If (Found = 0) And (NameMatches = 0) Then
      Note(Name + ': not found');
    LogLine(Shown + ': magic name, ' + Long2Str(Found) + ' file(s)' + Copy(' (nothing that fits the date)', 1, 29 * Ord((Found = 0) And (NameMatches > 0))));
    Exit;
    End;
  Found := SearchAreas(Name, Name);
  {an update request that finds nothing new is no problem, and no note: only a name that matches nothing is "not found"}
  If (Found = 0) And (NameMatches = 0) Then
    Note(Name + ': not found');
  LogLine(Shown + ': ' + Long2Str(Found) + ' file(s)' + Copy(' (nothing that fits the date)', 1, 29 * Ord((Found = 0) And (NameMatches > 0))));
  If (Found = 0) And (NameMatches = 0) Then
    Begin                                    {the log says why a file was not found (the requester is told only "not found")}
    If Searched <> '' Then
      LogLine('  looked in: ' + Searched)
    Else
      LogLine('  no file area could be looked in');
    If Blocked <> '' Then
      LogLine('  areas that allow requests but whose security this system does not meet (its level is ' + Long2Str(Profile.Level) +
        '; Mailer Links: File request level, or the file request security of the File Requests page): ' + Blocked);
    If Missing <> '' Then
      LogLine('  folders that do not exist (a path longer than 50 characters is cut short): ' + Missing);
    If NoFreq <> '' Then
      LogLine('  areas without "Allow file requests" (mkconfig: Files > Areas): ' + NoFreq);
    End;
  End;


Var
  F: File;
  Buf: Array[1..2048] Of Byte;
  Got: Word;
  L: String;
  k, Lines: Word;
  LinkNo: Word;

Begin
NReport := 0;
Randomize;
SrifMode := False;
If (ParamCount = 2) And (ParamStr(1) = '-S') Then
  Begin
  If Not ReadSrif(ParamStr(2)) Then
    Begin
    WriteLn('mkfreq: cannot use the SRIF file ', ParamStr(2));
    Halt(1);
    End;
  SrifMode := True;
  End
Else
  Begin
  If ParamCount < 4 Then
    Begin
    WriteLn('Usage: mkfreq <requester> <secure|unsecure> <request file> <answer file>');
    WriteLn('       mkfreq -S <srif file>');
    Halt(1);
    End;
  Who := ParamStr(1);
  Secure := Upper(ParamStr(2)) = 'SECURE';
  ReqFile := ParamStr(3);
  AnsFile := ParamStr(4);
  End;
Config := NewMKConfig(False);                   {the whole configuration (the mailer settings are not in the read-only one)}
If Config = Nil Then
  Begin
  WriteLn('mkfreq: no configuration: set MK to the BBS configuration directory');
  Halt(1);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn('mkfreq: the configuration could not be loaded (', Config^.GetError, ')');
  Halt(1);
  End;
New(M);
Config^.GetMailer(M^);
FillChar(Requester, SizeOf(Requester), 0);
Assign(Ans, AnsFile);
Rewrite(Ans);
If IoResult <> 0 Then
  Begin
  WriteLn('mkfreq: cannot write ', AnsFile);
  Halt(1);
  End;
If (M^.Flags And mcFileReq) = 0 Then
  Begin
  Note('file requests are not answered here');
  LogLine('file requests are switched off (Mailer > File requests)');
  Close(Ans);
  Halt(0);
  End;
{who is asking: the link, its security profile; else the global file request security}
Profile := M^.ReqSec;
LinkNo := 0;
If ParseAddr(Who, Requester, Requester) Then
  Begin
  For k := 1 To MaxMailLinks Do
    If (M^.Links[k].Addr.Zone <> 0) And ((M^.Links[k].Flags And mlDisabled) = 0) Then
      If AddrEqual(M^.Links[k].Addr, Requester) Then
        LinkNo := k;
  If LinkNo > 0 Then
    If M^.Links[LinkNo].ReqSec.Level > 0 Then
      Profile := M^.Links[LinkNo].ReqSec;
  End;
If (Profile.Level = 0) And (Profile.Flags = 0) Then
  Begin
  Note('file requests are not allowed for your system');
  LogLine(Who + ': no file request access is set up (level 0)');
  Close(Ans);
  Halt(0);
  End;
MaxFiles := M^.ReqMaxFiles;
If MaxFiles = 0 Then
  MaxFiles := DefaultMaxFiles;
MaxKb := M^.ReqMaxKb;
NSent := 0;
TotalBytes := 0;
LoadMagic;
LogLine(Who + ' (' + Copy('unsecure', 1 + 2 * Ord(Secure), 8 - 2 * Ord(Secure)) + Copy(', SRIF', 1, 6 * Ord(SrifMode)) + ', level ' + Long2Str(Profile.Level) + ')');
{the request file: lines end in CR (the spec), LF or CR LF}
Assign(F, ReqFile);
FileMode := 0;
Reset(F, 1);
If IoResult <> 0 Then
  Begin
  WriteLn('mkfreq: cannot read the request ', ReqFile);
  Close(Ans);
  Halt(1);
  End;
L := '';
Lines := 0;
Repeat
  BlockRead(F, Buf, SizeOf(Buf), Got);
  For k := 1 To Got Do
    If (Buf[k] = 13) Or (Buf[k] = 10) Then
      Begin
      If (L <> '') And (Lines < 200) Then
        Begin
        Inc(Lines);
        DoRequest(L);
        End;
      L := '';
      End
    Else If (Length(L) < 200) And (Buf[k] >= 32) Then
      L := L + Chr(Buf[k]);
Until Got = 0;
If (L <> '') And (Lines < 200) Then
  DoRequest(L);
Close(F);
If IoResult <> 0 Then;
Close(Ans);
If IoResult <> 0 Then;
LogLine(Long2Str(NSent) + ' file(s) in the answer, ' + Long2Str(TotalBytes) + ' bytes');
If (NReport > 0) And ((M^.ReqAttr And rqAnswerMail) <> 0) Then
  WriteNote;
End.
