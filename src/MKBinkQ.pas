Unit MKBinkQ;   {Giving a file to the mailer (mkbink queue): shared by mktoss and mkhatch}

{$I MKB.Def}

Interface

Uses MKGlobT;

Var
  BinkProg: String;                    {the mkbink program ('' = next to this program, else in the path)}
  BinkOutDir: String;                  {the outbound directory (EchoMail Options), no slash at the end needed}
  BinkZone: Word;                      {the zone of the BSO outbound = our main zone}
  BinkLog: Procedure(S: String);       {where a failure is said (Nil = nowhere)}

Function BinkPath: String;
Function EchoFlavour(Sys: Word): Char;
  {the flavour of the echo system for what we send it: Immediate, Crash, Normal, Hold}
Function BinkQueue(Sys: Word; Flav: Char; Path: String; Act: Char): Boolean;
  {a file for the echo system: Act = ^ delete it after it was sent, # truncate it, else leave it}
Function QuoteForShell(S: String): String;

Implementation

Uses BaseUnix, Unix, MKString, MKFile, MKCfgAbs;


Function QuoteForShell(S: String): String;
  Var
    i: Word;
    R: String;

  Begin
  R := '''';
  For i := 1 To Length(S) Do
    If S[i] = '''' Then
      R := R + '''\'''''
    Else
      R := R + S[i];
  QuoteForShell := R + '''';
  End;


Function BinkPath: String;
  Var
    Me: String;
    p: Word;

  Begin
  If BinkProg <> '' Then
    Begin
    BinkPath := BinkProg;
    Exit;
    End;
  Me := ParamStr(0);
  p := Length(Me);
  While (p > 0) And (Me[p] <> '/') Do
    Dec(p);
  If (p > 0) And FileExist(Copy(Me, 1, p) + 'mkbink') Then
    BinkPath := Copy(Me, 1, p) + 'mkbink'
  Else
    BinkPath := 'mkbink';
  End;


Function EchoFlavour(Sys: Word): Char;
  Begin
  Case Config^.GetEchoToMailType(Sys) Of
    0: EchoFlavour := 'I';
    1: EchoFlavour := 'C';
    3: EchoFlavour := 'H';
    Else EchoFlavour := 'N';
    End;
  End;


Function BinkQueue(Sys: Word; Flav: Char; Path: String; Act: Char): Boolean;
  Var
    A: AddrType;
    Opt, O: String;
    Rc: LongInt;

  Begin
  Config^.GetEchoToAddr(Sys, A);
  Opt := '';
  If Act = '^' Then
    Opt := ' -x'
  Else If Act = '#' Then
    Opt := ' -T';
  O := BinkOutDir;
  If (O <> '') And (O[Length(O)] = '/') Then
    Delete(O, Length(O), 1);
  Rc := fpSystem(QuoteForShell(BinkPath) + ' queue -O ' + QuoteForShell(O) + ' -Z ' + Long2Str(BinkZone) + ' -t ' + AddrStr(A) +
    ' -F ' + Flav + Opt + ' ' + QuoteForShell(Path) + ' >/dev/null 2>&1');
  BinkQueue := Rc = 0;
  If (Rc <> 0) And (@BinkLog <> Nil) Then
    BinkLog('mkbink queue failed (status ' + Long2Str(Rc) + ') for ' + Path + ' to ' + AddrStr(A));
  End;


End.
