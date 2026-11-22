Unit MKTic;   {TIC files (file echoes): read, write, the Path and Seenby lines, the CRC of a file.  See TIC-PLAN.md}

{
  A TIC is a text file with a line  Keyword value  for each field.  The format is that of FSC-0087 and of the common tossers (the text of
  the FSC could not be read when this was written: this is what the tossers write and read, checked against TICs of other systems when
  there are some; the keywords are not case sensitive, a field this unit does not know is kept and written again).

     Area <tag>            the file echo
     Areadesc <text>       what the echo is
     Origin <address>      the system that hatched the file
     From <address>        the system the file comes from (the one that sent this TIC)
     To <address>          the system it is for
     File <name>           the name of the file
     Fullname <name>       the long name of the file
     Replaces <name>       a file of the echo this one replaces (wildcards)
     Desc <text>           one line about the file
     Ldesc <text>          a line of a longer description (more than one Ldesc line)
     Size <bytes>
     Date <seconds>        the date of the file: seconds since 1970 (a text date is kept as it is)
     Crc <hex>             the CRC-32 of the file: 8 hexadecimal digits
     Created <text>        the program that made the TIC
     Magic <name>          a magic name for file requests
     Path <address> <seconds> <date> <program>    one line for each system the file went through (the last one last)
     Seenby <address>      the systems that have the file or are to get it
     Pw <password>         the password of the receiving system

  Lines end with CR LF or LF.  A line with no keyword, or that starts with ';', is ignored.
}

{$I MKB.Def}

Interface

Const
  TicMaxLdesc = 60;
  TicMaxPath = 40;
  TicMaxSeen = 150;
  TicMaxOther = 20;

  ticOk = 0;
  ticNoFile = 1;                       {the TIC could not be read}
  ticNoName = 2;                       {no File line}
  ticNoArea = 3;                       {no Area line}
  ticBadSize = 4;                      {a Size that is not a number}
  ticBadCrc = 5;                       {a Crc that is not 8 hex digits}

Type
  TicType = Record
    Area, AreaDesc, Origin, From, ToAddr, FileName, FullName, Replaces, Desc, Created, Magic, Pw: String;
    DateRaw: String;                   {the Date field as it was}
    Size: LongInt;
    HasSize: Boolean;
    Date: LongInt;                     {seconds since 1970 when DateRaw is a number, else 0}
    Crc: LongInt;
    HasCrc: Boolean;
    NumLdesc: Word;
    Ldesc: Array[1..TicMaxLdesc] Of String[250];
    NumPath: Word;
    Path: Array[1..TicMaxPath] Of String[120];     {each Path line without its keyword}
    NumSeen: Word;
    Seen: Array[1..TicMaxSeen] Of String[60];      {each Seenby address}
    NumOther: Word;
    Other: Array[1..TicMaxOther] Of String[250];   {lines of keywords not known, whole}
    End;
  TicPtr = ^TicType;

Procedure TicInit(Var T: TicType);
Function  TicParse(FileName: String; Var T: TicType): Word;
  {ticOk, or ticNoFile; the other errors are TicCheck's}
Function  TicCheck(Var T: TicType): Word;
  {ticOk, ticNoName, ticNoArea, ticBadSize, ticBadCrc: what a TIC must have to be used}
Function  TicWrite(FileName: String; Var T: TicType): Boolean;
Function  TicFileCrc(FileName: String; Var Crc: LongInt; Var Size: LongInt): Boolean;
  {the CRC-32 and the size of a file}
Function  TicCrcStr(Crc: LongInt): String;
  {8 hexadecimal digits, upper case}
Function  TicHexCrc(S: String; Var Crc: LongInt): Boolean;
Function  TicDateStr(Secs: LongInt): String;
  {'Mon Jan 01 00:00:00 2001' (UTC)}
Procedure TicAddPath(Var T: TicType; Addr: String; Secs: LongInt; Prog: String);
Procedure TicAddSeen(Var T: TicType; Addr: String);
Function  TicInPath(Var T: TicType; Addr: String): Boolean;
Function  TicInSeen(Var T: TicType; Addr: String): Boolean;
Function  TicSameAddr(A, B: String): Boolean;
  {zone:net/node[.point][@domain]: the same system whatever the case, a .0 point or the domain}
Function  TicMatchName(Pattern, Name: String): Boolean;
  {* and ? as in a DOS name, not case sensitive: for Replaces}

Implementation

Uses MKString, Crc32;


Procedure TicInit(Var T: TicType);
  Begin
  FillChar(T, SizeOf(T), 0);
  End;


Function Trim(S: String): String;
  Begin
  While (S <> '') And (S[1] In [' ', #9]) Do
    Delete(S, 1, 1);
  While (S <> '') And (S[Length(S)] In [' ', #9, #13, #10]) Do
    Delete(S, Length(S), 1);
  Trim := S;
  End;


Function UpperS(S: String): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    S[i] := UpCase(S[i]);
  UpperS := S;
  End;


Function Digits(S: String; Var N: LongInt): Boolean;
  {S is a decimal number}
  Var
    i: Word;

  Begin
  Digits := False;
  If (S = '') Or (Length(S) > 10) Then
    Exit;
  N := 0;
  For i := 1 To Length(S) Do
    Begin
    If Not (S[i] In ['0'..'9']) Then
      Exit;
    N := N * 10 + Ord(S[i]) - 48;
    End;
  Digits := True;
  End;


Function TicHexCrc(S: String; Var Crc: LongInt): Boolean;
  Var
    i: Word;
    V: Int64;
    C: Char;

  Begin
  TicHexCrc := False;
  S := Trim(S);
  If (Length(S) > 2) And (S[1] = '0') And (UpCase(S[2]) = 'X') Then
    Delete(S, 1, 2);
  If (S = '') Or (Length(S) > 8) Then
    Exit;
  V := 0;
  For i := 1 To Length(S) Do
    Begin
    C := UpCase(S[i]);
    If C In ['0'..'9'] Then
      V := V * 16 + Ord(C) - 48
    Else If C In ['A'..'F'] Then
      V := V * 16 + Ord(C) - 55
    Else
      Exit;
    End;
  Crc := LongInt(V And $FFFFFFFF);
  TicHexCrc := True;
  End;


Function TicCrcStr(Crc: LongInt): String;
  Const
    Hex: String[16] = '0123456789ABCDEF';
  Var
    S: String;
    i: Integer;
    V: LongInt;

  Begin
  S := '';
  V := Crc;
  For i := 1 To 8 Do
    Begin
    S := Hex[(V And 15) + 1] + S;
    V := (V Shr 4) And $0FFFFFFF;
    End;
  TicCrcStr := S;
  End;


Function TicParse(FileName: String; Var T: TicType): Word;
  Var
    F: Text;
    L, K, V: String;
    p: Word;
    X: LongInt;

  Begin
  TicInit(T);
  TicParse := ticNoFile;
  Assign(F, FileName);
  FileMode := 0;
  Reset(F);
  If IoResult <> 0 Then
    Exit;
  TicParse := ticOk;
  While Not Eof(F) Do
    Begin
    ReadLn(F, L);
    L := Trim(L);
    If (L = '') Or (L[1] = ';') Then
      Continue;
    p := 1;
    While (p <= Length(L)) And (Not (L[p] In [' ', #9])) Do
      Inc(p);
    K := UpperS(Copy(L, 1, p - 1));
    V := Trim(Copy(L, p, 255));
    If K = 'AREA' Then
      T.Area := V
    Else If K = 'AREADESC' Then
      T.AreaDesc := V
    Else If K = 'ORIGIN' Then
      T.Origin := V
    Else If K = 'FROM' Then
      T.From := V
    Else If K = 'TO' Then
      T.ToAddr := V
    Else If K = 'FILE' Then
      T.FileName := V
    Else If (K = 'FULLNAME') Or (K = 'FILENAME') Then
      T.FullName := V
    Else If K = 'REPLACES' Then
      T.Replaces := V
    Else If K = 'DESC' Then
      T.Desc := V
    Else If K = 'LDESC' Then
      Begin
      If T.NumLdesc < TicMaxLdesc Then
        Begin
        Inc(T.NumLdesc);
        T.Ldesc[T.NumLdesc] := V;
        End;
      End
    Else If K = 'SIZE' Then
      Begin
      T.HasSize := Digits(V, X);
      If T.HasSize Then
        T.Size := X
      Else
        T.Size := -1;
      End
    Else If K = 'DATE' Then
      Begin
      T.DateRaw := V;
      If Digits(V, X) Then
        T.Date := X;
      End
    Else If K = 'CRC' Then
      Begin
      T.HasCrc := TicHexCrc(V, X);
      If T.HasCrc Then
        T.Crc := X
      Else
        T.Crc := 0;
      End
    Else If K = 'CREATED' Then
      T.Created := V
    Else If K = 'MAGIC' Then
      T.Magic := V
    Else If K = 'PW' Then
      T.Pw := V
    Else If K = 'PATH' Then
      Begin
      If T.NumPath < TicMaxPath Then
        Begin
        Inc(T.NumPath);
        T.Path[T.NumPath] := V;
        End;
      End
    Else If K = 'SEENBY' Then
      Begin
      If T.NumSeen < TicMaxSeen Then
        Begin
        Inc(T.NumSeen);
        T.Seen[T.NumSeen] := V;
        End;
      End
    Else If T.NumOther < TicMaxOther Then
      Begin
      Inc(T.NumOther);
      T.Other[T.NumOther] := L;
      End;
    End;
  Close(F);
  If IoResult <> 0 Then;
  End;


Function TicCheck(Var T: TicType): Word;
  Begin
  TicCheck := ticOk;
  If T.FileName = '' Then
    TicCheck := ticNoName
  Else If T.Area = '' Then
    TicCheck := ticNoArea
  Else If T.Size < 0 Then
    TicCheck := ticBadSize
  Else If Not T.HasCrc Then
    TicCheck := ticBadCrc;
  End;


Function TicWrite(FileName: String; Var T: TicType): Boolean;
  Var
    F: Text;
    i: Word;

  Procedure W(K, V: String);
    Begin
    If V <> '' Then
      Write(F, K, ' ', V, #13#10);
    End;

  Begin
  TicWrite := False;
  Assign(F, FileName);
  Rewrite(F);
  If IoResult <> 0 Then
    Exit;
  W('Created', T.Created);
  W('Area', T.Area);
  W('Areadesc', T.AreaDesc);
  W('Origin', T.Origin);
  W('From', T.From);
  W('To', T.ToAddr);
  W('File', T.FileName);
  W('Fullname', T.FullName);
  If T.HasSize Then
    Write(F, 'Size ', T.Size, #13#10);
  If T.DateRaw <> '' Then
    W('Date', T.DateRaw)
  Else If T.Date <> 0 Then
    Write(F, 'Date ', T.Date, #13#10);
  W('Replaces', T.Replaces);
  W('Magic', T.Magic);
  W('Desc', T.Desc);
  For i := 1 To T.NumLdesc Do
    Write(F, 'Ldesc ', T.Ldesc[i], #13#10);
  If T.HasCrc Then
    W('Crc', TicCrcStr(T.Crc));
  For i := 1 To T.NumPath Do
    Write(F, 'Path ', T.Path[i], #13#10);
  For i := 1 To T.NumSeen Do
    Write(F, 'Seenby ', T.Seen[i], #13#10);
  For i := 1 To T.NumOther Do
    Write(F, T.Other[i], #13#10);
  W('Pw', T.Pw);
  Close(F);
  TicWrite := IoResult = 0;
  End;


Function TicFileCrc(FileName: String; Var Crc: LongInt; Var Size: LongInt): Boolean;
  Var
    F: File;
    Buf: Array[0..16383] Of Byte;
    N, i: LongInt;
    C: LongInt;

  Begin
  TicFileCrc := False;
  Assign(F, FileName);
  FileMode := 0;
  Reset(F, 1);
  If IoResult <> 0 Then
    Exit;
  C := LongInt($FFFFFFFF);
  Size := 0;
  Repeat
    BlockRead(F, Buf, SizeOf(Buf), N);
    If IoResult <> 0 Then
      Begin
      Close(F);
      Exit;
      End;
    For i := 0 To N - 1 Do
      C := UpdC32(Buf[i], C);
    Size := Size + N;
  Until N = 0;
  Close(F);
  If IoResult <> 0 Then;
  Crc := C Xor LongInt($FFFFFFFF);
  TicFileCrc := True;
  End;


Function TicDateStr(Secs: LongInt): String;
  Const
    Days: Array[0..6] Of String[3] = ('Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed');
    Months: Array[1..12] Of String[3] = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  Var
    D, S, Z, Era, Doe, Yoe, Y, Doy, Mp, Dd, M: LongInt;

  Function Two(N: LongInt): String;
    Begin
    If N < 10 Then
      Two := '0' + Chr(48 + N)
    Else
      Two := Chr(48 + N Div 10) + Chr(48 + N Mod 10);
    End;

  Begin
  D := Secs Div 86400;
  S := Secs Mod 86400;
  Z := D + 719468;                      {days from 0000-03-01: the civil date of a day number}
  Era := Z Div 146097;
  Doe := Z - Era * 146097;
  Yoe := (Doe - Doe Div 1460 + Doe Div 36524 - Doe Div 146096) Div 365;
  Y := Yoe + Era * 400;
  Doy := Doe - (365 * Yoe + Yoe Div 4 - Yoe Div 100);
  Mp := (5 * Doy + 2) Div 153;
  Dd := Doy - (153 * Mp + 2) Div 5 + 1;
  If Mp < 10 Then
    M := Mp + 3
  Else
    M := Mp - 9;
  If M <= 2 Then
    Inc(Y);
  TicDateStr := Days[D Mod 7] + ' ' + Months[M] + ' ' + Two(Dd) + ' ' + Two(S Div 3600) + ':' + Two((S Mod 3600) Div 60) + ':' +
    Two(S Mod 60) + ' ' + Chr(48 + Y Div 1000) + Chr(48 + (Y Div 100) Mod 10) + Chr(48 + (Y Div 10) Mod 10) + Chr(48 + Y Mod 10);
  End;


Function Norm(A: String): String;
  {an address as it is compared: no domain, no blanks, upper case, no .0 point}
  Var
    p: Word;

  Begin
  A := UpperS(Trim(A));
  p := Pos('@', A);
  If p > 0 Then
    A := Copy(A, 1, p - 1);
  If (Length(A) > 2) And (Copy(A, Length(A) - 1, 2) = '.0') Then
    Delete(A, Length(A) - 1, 2);
  Norm := A;
  End;


Function TicSameAddr(A, B: String): Boolean;
  Begin
  TicSameAddr := Norm(A) = Norm(B);
  End;


Procedure TicAddPath(Var T: TicType; Addr: String; Secs: LongInt; Prog: String);
  Var
    S: String;
    i: Word;

  Begin
  S := Addr + ' ' + Long2Str(Secs) + ' ' + TicDateStr(Secs) + ' UTC ' + Prog;
  If T.NumPath >= TicMaxPath Then
    Begin                              {the oldest goes}
    For i := 2 To TicMaxPath Do
      T.Path[i - 1] := T.Path[i];
    T.NumPath := TicMaxPath - 1;
    End;
  Inc(T.NumPath);
  T.Path[T.NumPath] := S;
  End;


Procedure TicAddSeen(Var T: TicType; Addr: String);
  Begin
  If TicInSeen(T, Addr) Or (T.NumSeen >= TicMaxSeen) Then
    Exit;
  Inc(T.NumSeen);
  T.Seen[T.NumSeen] := Addr;
  End;


Function TicInPath(Var T: TicType; Addr: String): Boolean;
  Var
    i, p: Word;
    S: String;

  Begin
  TicInPath := False;
  For i := 1 To T.NumPath Do
    Begin
    S := T.Path[i];
    p := Pos(' ', S);
    If p = 0 Then
      p := Length(S) + 1;
    If TicSameAddr(Copy(S, 1, p - 1), Addr) Then
      TicInPath := True;
    End;
  End;


Function TicInSeen(Var T: TicType; Addr: String): Boolean;
  Var
    i: Word;

  Begin
  TicInSeen := False;
  For i := 1 To T.NumSeen Do
    If TicSameAddr(T.Seen[i], Addr) Then
      TicInSeen := True;
  End;


Function Match(P, N: String): Boolean;
  Begin
  If P = '' Then
    Match := N = ''
  Else If P[1] = '*' Then
    Begin
    Match := Match(Copy(P, 2, 255), N) Or ((N <> '') And Match(P, Copy(N, 2, 255)));
    End
  Else If N = '' Then
    Match := False
  Else If (P[1] = '?') Or (P[1] = N[1]) Then
    Match := Match(Copy(P, 2, 255), Copy(N, 2, 255))
  Else
    Match := False;
  End;


Function TicMatchName(Pattern, Name: String): Boolean;
  Begin
  TicMatchName := Match(UpperS(Pattern), UpperS(Name));
  End;


End.
