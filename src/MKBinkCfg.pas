Program MKBinkCfg;

{$I MKB.Def}

{
     mkbinkcfg [-o file] [-n] [-f] [-q]

     Writes the settings file of the binkp mailer (mkbink run -f file) from the BBS configuration (the directory
     the environment variable MK names, as for mk and mkconfig).  The mailer knows nothing else about the BBS.

        our addresses, domain, name, sysop, location    General (Config.Mk), Mailer (Mailer.Mk)
        inbound directory, BSO outbound directory       EchoMail Options (EchoCfg.Mk)
        listening, retry times, links ...               Mailer, Mailer Links (Mailer.Mk)
        the tosser (mktoss) as on-inbound command       Mailer > Tosser, when the command is blank
        host of a link that has none                    the nodelist index (mknodeidx): IBN / INA flags

     Relative directories are taken from the BBS directory.  The file is made with mode 600 (it holds the link
     passwords), is replaced all at once, and is left alone when nothing in it would change, so a program that
     watches it (mklisten) can tell whether the mailer has to read it again.

        -o file   where to write it (default: mkbink.conf in the BBS directory; - = the screen)
        -n        only show what would be written
        -f        write the file even if the mailer is not enabled in the configuration
        -q        say nothing unless something is wrong

     Exit status: 0 = written (or unchanged), 1 = error, 3 = the mailer is not enabled (nothing written).
}

Uses
  BaseUnix, Dos, MKString, MKGlobT, MKFile, MKCfgAbs, MKCfgMK, MKNSrch;


Const
  LinksVersion = 1;

Var
  M: ^MailerCfgType;
  Errors: Word;
  OutName: String;
  ToScreen, Force, Quiet: Boolean;
  BbsPath: String;
  i: Word;
  T: Text;
  Valid: Array[1..10] Of Boolean;
  Addrs: Array[1..10] Of AddrType;
  Enabled: Boolean;
  Res: Word;
  Nodes: NodeListObj;
  NodesTried, NodesOk: Boolean;


Procedure Fail(Msg: String);
  Begin
  WriteLn(StdErr, 'mkbinkcfg: ' + Msg);
  Inc(Errors);
  End;


Function FmtAddr(Var A: AddrType): String;
  Begin
  FmtAddr := AddrStr(A);
  End;


Function TosserProg: String;
  {mktoss next to this program, else left to the path}
  Var
    Me: String;
    p: Word;

  Begin
  Me := ParamStr(0);
  p := Length(Me);
  While (p > 0) And (Me[p] <> '/') Do
    Dec(p);
  If (p > 0) And FileExist(Copy(Me, 1, p) + 'mktoss') Then
    TosserProg := Copy(Me, 1, p) + 'mktoss'
  Else
    TosserProg := 'mktoss';
  End;


Function NodelistHost(Var A: AddrType; Var Host: String; Var Port: Word): Boolean;
  {The internet address of a node from its nodelist line: the flags IBN (binkp), IBN:port, IBN:host, IBN:host:port
   and INA:host.  False when the nodelist has no index, no such node or no host name for it.}
  Var
    Line, Flag, Up, P1, P2, P3, INA: String;
    k, p: Word;
    HasIbn: Boolean;
    V: LongInt;

  Begin
  NodelistHost := False;
  Host := '';
  Port := 0;
  If A.Point <> 0 Then
    Exit;
  If Not NodesTried Then
    Begin
    NodesTried := True;
    Nodes.Init;
    Nodes.Load;
    NodesOk := Nodes.GetError = 0;
    If Not NodesOk Then
      WriteLn(StdErr, 'mkbinkcfg: note: no nodelist index (' + Config^.GetNodeListPath + Config^.GetNodeIdxName +
        '), links without a host are not looked up (mknodeidx builds it)');
    End;
  If Not NodesOk Then
    Exit;
  Line := Nodes.NodeStr(A);
  If Pos('Address Not Found', Line) > 0 Then
    Exit;
  HasIbn := False;
  INA := '';
  k := 7;
  Repeat
    Flag := GetNodeSection(Line, k);
    Inc(k);
    If Flag = '' Then
      Continue;
    Up := Upper(Flag);
    p := Pos(':', Up);
    If p = 0 Then
      Begin
      If Up = 'IBN' Then
        HasIbn := True;
      Continue;
      End;
    P1 := Copy(Up, 1, p - 1);
    P2 := Copy(Flag, p + 1, 255);
    P3 := '';
    p := Pos(':', P2);
    If p > 0 Then
      Begin
      P3 := Copy(P2, p + 1, 255);
      P2 := Copy(P2, 1, p - 1);
      End;
    If P1 = 'INA' Then
      INA := P2
    Else If P1 = 'IBN' Then
      Begin
      HasIbn := True;
      Val(P2, V, p);
      If (p = 0) And (V > 0) And (V < 65536) Then
        Port := V
      Else If P2 <> '' Then
        Begin
        Host := P2;
        Val(P3, V, p);
        If (p = 0) And (V > 0) And (V < 65536) Then
          Port := V;
        End;
      End;
  Until (Flag = '') Or (k > 60);
  If Host = '' Then
    Host := INA;
  NodelistHost := HasIbn And (Host <> '') And (Pos(' ', Host) = 0) And (Pos('#', Host) = 0);
  End;


Function Clean(S: String): String;
  {One line of text for the file: no control characters and nothing that reads as a comment}
  Var
    R: String;
    j: Word;

  Begin
  R := '';
  For j := 1 To Length(S) Do
    If S[j] >= ' ' Then
      R := R + S[j];
  While Pos(' #', R) > 0 Do
    R[Pos(' #', R) + 1] := '-';
  Clean := StripBoth(R, ' ');
  End;


Function AbsPath(P: String): String;
  {Slashes, relative to the BBS directory, no slash at the end}
  Begin
  P := StripBoth(P, ' ');
  For i := 1 To Length(P) Do
    If P[i] = '\' Then
      P[i] := '/';
  If P = '' Then
    Begin
    AbsPath := '';
    Exit;
    End;
  If P[1] <> '/' Then
    P := BbsPath + P;
  P := FExpand(P);
  While (Length(P) > 1) And (P[Length(P)] = '/') Do
    Dec(P[0]);
  AbsPath := P;
  End;


Procedure MakeDirs(P: String);
  Var
    j: Word;

  Begin
  For j := 2 To Length(P) + 1 Do
    If (j > Length(P)) Or (P[j] = '/') Then
      Begin
      {$I-}
      MkDir(Copy(P, 1, j - 1));
      {$I+}
      If IoResult <> 0 Then;
      End;
  End;


Procedure W(S: String);
  Begin
  WriteLn(T, S);
  End;


Procedure WTxt(Key, Val: String);
  Begin
  Val := Clean(Val);
  If Val <> '' Then
    W(Key + ' ' + Val);
  End;


Function YesNo(B: Boolean): String;
  Begin
  If B Then
    YesNo := 'yes'
  Else
    YesNo := 'no';
  End;


Procedure Generate;
  Var
    n, k, First: Word;
    A: AddrType;
    S, InDir, OutDir: String;
    Skip, FromList: Boolean;
    Pt, NPort: Word;

  Begin
  W('# Settings of the binkp mailer, made by mkbinkcfg from the BBS configuration.');
  W('# Do not edit: change the configuration (mkconfig) and run mkbinkcfg again.');
  W('version ' + Long2Str(LinksVersion));
  For n := 1 To 10 Do
    If Valid[n] Then
      W('address ' + FmtAddr(Addrs[n]));
  WTxt('domain', M^.Domain);
  WTxt('sysname', Config^.GetBbsName);
  WTxt('sysop', Config^.GetSysopName);
  WTxt('location', Config^.GetBbsLoc);
  InDir := AbsPath(Config^.GetEchoInPath);
  OutDir := AbsPath(Config^.GetEchoOutPath);
  If InDir = '' Then
    Fail('no InBound path (EchoMail Options)');
  If OutDir = '' Then
    Fail('no OutBound path (EchoMail Options)');
  W('inbound ' + InDir);
  If M^.UnsecureIn <> '' Then
    W('inbound-unsecure ' + AbsPath(M^.UnsecureIn));
  If (StripBoth(M^.OnInbound, ' ') = '') And ((M^.Flags And mcTosser) <> 0) Then
    W('on-inbound ' + TosserProg)             {the tosser, the mailer runs it after mail arrived}
  Else
    WTxt('on-inbound', M^.OnInbound);
  If M^.HookTimeout > 0 Then
    W('hook-timeout ' + Long2Str(M^.HookTimeout));
  W('bso ' + OutDir);
  W('listen ' + YesNo((M^.Flags And mcListen) <> 0));
  W('port ' + Long2Str(M^.Port));
  WTxt('bind', M^.Bind);
  W('max-sessions ' + Long2Str(M^.MaxSessions));
  W('max-polls ' + Long2Str(M^.MaxPolls));
  W('timeout ' + Long2Str(M^.Timeout));
  W('require-cram ' + YesNo((M^.Flags And mcRequireCram) <> 0));
  W('plz ' + YesNo((M^.Flags And mcPlz) <> 0));
  W('nr ' + YesNo((M^.Flags And mcNr) <> 0));
  W('accept-unknown ' + YesNo((M^.Flags And mcAcceptUnknown) <> 0));
  If (M^.Flags And mcAcceptUnknown) <> 0 Then
    WTxt('password', M^.UnknownPwd);
  W('retry-min ' + Long2Str(M^.RetryMin));
  W('retry-max ' + Long2Str(M^.RetryMax));
  W('scan-interval ' + Long2Str(M^.ScanInterval));
  For n := 1 To MaxMailLinks Do
    Begin
    A := M^.Links[n].Addr;
    If (A.Zone = 0) Or ((M^.Links[n].Flags And mlDisabled) <> 0) Then
      Continue;
    Skip := False;
    For k := 1 To n - 1 Do
      If (M^.Links[k].Addr.Zone <> 0) And ((M^.Links[k].Flags And mlDisabled) = 0) And
         AddrEqual(M^.Links[k].Addr, A) Then
        Begin
        Fail('links ' + Long2Str(k) + ' and ' + Long2Str(n) + ' have the same address ' + FmtAddr(A));
        Skip := True;
        End;
    If Skip Then
      Continue;
    If M^.Links[n].Password <> Clean(M^.Links[n].Password) Then
      Fail('link ' + Long2Str(n) + ' (' + FmtAddr(A) + '): the password has a blank followed by # or a control character, ' +
        'which the settings file cannot hold');
    W('');
    W('link ' + FmtAddr(A));
    S := Clean(M^.Links[n].Name);
    If S <> '' Then
      W('  name ' + S);
    S := Clean(M^.Links[n].Host);
    Pt := M^.Links[n].Port;
    FromList := False;
    If (S = '') And ((M^.Links[n].Flags And mlAnswerOnly) = 0) Then
      Begin
      If NodelistHost(A, S, NPort) Then
        Begin
        FromList := True;
        If Pt = 0 Then
          Pt := NPort;
        End
      Else
        S := '';
      End;
    If S <> '' Then
      Begin
      If FromList Then
        W('  host ' + S + '   # from the nodelist')
      Else
        W('  host ' + S);
      If (Pt <> 0) And (Pt <> 24554) Then
        W('  port ' + Long2Str(Pt));
      End;
    If M^.Links[n].Password <> '' Then
      W('  password ' + M^.Links[n].Password);
    If M^.Links[n].PollMin > 0 Then
      W('  poll ' + Long2Str(M^.Links[n].PollMin));
    If (M^.Links[n].Flags And mlAnswerOnly) <> 0 Then
      W('  answer-only yes');
    k := M^.Links[n].UseAka;
    If k > 0 Then
      Begin
      If (k <= 10) And Valid[k] Then
        W('  us ' + FmtAddr(Addrs[k]))
      Else
        Fail('link ' + Long2Str(n) + ' (' + FmtAddr(A) + '): our address ' + Long2Str(k) + ' is not set (General, Addresses)');
      End;
    If (M^.Links[n].Flags And mlPlzOn) <> 0 Then W('  plz yes');
    If (M^.Links[n].Flags And mlPlzOff) <> 0 Then W('  plz no');
    If (M^.Links[n].Flags And mlNrOn) <> 0 Then W('  nr yes');
    If (M^.Links[n].Flags And mlNrOff) <> 0 Then W('  nr no');
    End;
  End;


Function SameFile(A, B: String): Boolean;
  Var
    FA, FB: File;
    BA, BB: Array[1..4096] Of Byte;
    NA, NB: Word;
    Same: Boolean;

  Begin
  SameFile := False;
  Assign(FA, A);
  Assign(FB, B);
  {$I-}
  FileMode := 0;
  Reset(FA, 1);
  If IoResult <> 0 Then
    Exit;
  Reset(FB, 1);
  If IoResult <> 0 Then
    Begin
    Close(FA);
    Exit;
    End;
  {$I+}
  Same := FileSize(FA) = FileSize(FB);
  While Same And Not Eof(FA) Do
    Begin
    BlockRead(FA, BA, SizeOf(BA), NA);
    BlockRead(FB, BB, SizeOf(BB), NB);
    If (NA <> NB) Or (CompareByte(BA, BB, NA) <> 0) Then
      Same := False;
    End;
  Close(FA);
  Close(FB);
  SameFile := Same;
  End;


Begin
Errors := 0;
NodesTried := False;
NodesOk := False;
OutName := '';
ToScreen := False;
Force := False;
Quiet := False;
i := 1;
While i <= ParamCount Do
  Begin
  If ParamStr(i) = '-o' Then
    Begin
    Inc(i);
    OutName := ParamStr(i);
    If OutName = '-' Then
      ToScreen := True;
    End
  Else If ParamStr(i) = '-n' Then
    ToScreen := True
  Else If ParamStr(i) = '-f' Then
    Force := True
  Else If ParamStr(i) = '-q' Then
    Quiet := True
  Else
    Begin
    WriteLn(StdErr, 'Usage: mkbinkcfg [-o file] [-n] [-f] [-q]');
    Halt(1);
    End;
  Inc(i);
  End;
If DetectBbsType <> 1 Then
  Begin
  WriteLn(StdErr, 'mkbinkcfg: set MK to the BBS configuration directory (the mailer settings are kept by the MK configuration)');
  Halt(1);
  End;
Config := New(MKCfgObjPtr, Init);
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, 'mkbinkcfg: ' + Long2Str(Config^.GetError) + ': error loading the configuration files');
  Halt(1);
  End;
New(M);
Config^.GetMailer(M^);
BbsPath := Config^.GetBbsPath;
If (BbsPath <> '') And (BbsPath[Length(BbsPath)] <> '/') Then
  BbsPath := BbsPath + '/';
Enabled := (M^.Flags And mcEnabled) <> 0;
If (Not Enabled) And (Not Force) And (Not ToScreen) Then
  Begin
  If Not Quiet Then
    WriteLn('The mailer is not enabled in the configuration (Mailer); nothing written (-f writes it anyway)');
  Halt(3);
  End;
For i := 1 To 10 Do
  Begin
  Config^.GetAddr(i, Addrs[i]);
  Valid[i] := Addrs[i].Zone <> 0;
  End;
If Not Valid[1] Then
  Fail('the BBS has no main address (General, Addresses)');
If ToScreen Then
  Begin
  Assign(T, '');
  Rewrite(T);
  End
Else
  Begin
  If OutName = '' Then
    OutName := BbsPath + 'mkbink.conf';
  Assign(T, OutName + '.new');
  Res := 0;
  {$I-}
  Rewrite(T);
  {$I+}
  If IoResult <> 0 Then
    Begin
    Fail('cannot write ' + OutName + '.new');
    Halt(1);
    End;
  fpChmod(OutName + '.new', 384);
  End;
Generate;
Close(T);
If Errors > 0 Then
  Begin
  If Not ToScreen Then
    Erase(T);
  WriteLn(StdErr, 'mkbinkcfg: ' + Long2Str(Errors) + ' problem(s), nothing written');
  Halt(1);
  End;
If ToScreen Then
  Halt(0);
If SameFile(OutName, OutName + '.new') Then
  Begin
  Erase(T);
  If Not Quiet Then
    WriteLn(OutName + ' is up to date');
  End
Else
  Begin
  Assign(T, OutName + '.new');
  Rename(T, OutName);
  If IoResult <> 0 Then
    Begin
    Fail('cannot replace ' + OutName);
    Halt(1);
    End;
  fpChmod(OutName, 384);
  If Not Quiet Then
    WriteLn('Wrote ' + OutName);
  End;
End.
