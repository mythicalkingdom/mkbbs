{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKPwd;          {Hashed passwords: SHA-256, HMAC, PBKDF2 and the hash block of the ExtUsers.Bbs record}

{$I MKB.Def}

{
     A user's password is normally the Pwd field of Users.Bbs (plain text, as in the DOS days).  A password can be kept as a
     hash instead: the Pwd field then holds "*" and the PwHash block at the end of the user's ExtUsers.Bbs record (Struct.MK:
     PwHashType) holds a salted PBKDF2-HMAC-SHA256 hash.  Only MK configurations (MK, MK JSON) do this; the other BBS
     formats have no place for it.

       PwdHashSet     makes the hash of a password (a new salt every time) and fills the block
       PwdHashCheck   is this the password?  Typed exactly as it was set.  A block with phUpper (made by the conversion of an
                      old plain password, which was compared in upper case) also takes the typed password in upper case
       PwdHashIsSet   the block holds a hash
       PwdHashClear   the block is empty again (Algo 0)
       PwdNeedsRehash the hash was made with fewer iterations than PwdIterations is now

     The check is made in constant time and fails closed: an unknown version or algorithm never matches.

     ExtUsersFormat looks at the size of extusers.bbs: this version has a longer record than the DOS one (the hash block and
     128 bytes for the future), and a file of the old size must be expanded first (mkpwconv -x).
}


Interface


Uses MKRCfgMK;


Type
  Sha256Digest = Array[0..31] Of Byte;


Const
  pmPlain = 0;                           {passwords stay as they are (the default)}
  pmHashNew = 1;                         {a new or changed password is stored as a hash}
  pmConvert = 2;                         {as pmHashNew, and a plain password is converted when its owner logs in}
  PwdMaxPlain = 15;                      {longest plain password (the Pwd field of Users.Bbs)}
  PwdMaxHashed = 50;

Var
  PwdMode: Byte;                         {pmPlain, pmHashNew or pmConvert: MK configurations only}
  PwdIterations: LongInt;                {iterations for a new hash (default 20000)}
  ExtUsersBad: Boolean;                  {set when extusers.bbs was left alone because it has the old record size}


Procedure Sha256Buf(Data: Pointer; N: LongInt; Var Dig: Sha256Digest);
Procedure HmacSha256(Key: Pointer; KeyLen: LongInt; Msg: Pointer; MsgLen: LongInt; Var Dig: Sha256Digest);
Procedure Pbkdf2Sha256(Pwd: Pointer; PwdLen: LongInt; Salt: Pointer; SaltLen: LongInt; Iter: LongInt; Var Dig: Sha256Digest);

Function  RandomBytes(Var Buf; N: Word): Boolean;      {from the system's random source; False when there is none}

Function  PwdHashSet(Var H: PwHashType; Const Typed: String; Upper: Boolean): Boolean;
Function  PwdHashCheck(Const H: PwHashType; Const Typed: String): Boolean;
Function  PwdHashIsSet(Const H: PwHashType): Boolean;
Procedure PwdHashClear(Var H: PwHashType);
Function  PwdNeedsRehash(Const H: PwHashType): Boolean;
Function  PwdNow: LongInt;                             {seconds since 1970 (UTC)}
Function  PwdHashSetKeep(Var H: PwHashType; Const Typed: String; Upper: Boolean): Boolean;
  {as PwdHashSet, but the state of the block (when the password was set, the failures, the lock) stays: for a hash that is renewed or converted, not for a new password}
Procedure PwdStateNew(Var H: PwHashType);
  {a password was set: the state starts again (set now, no failures, no lock)}

Procedure PwdModeFromConfig;                           {PwdMode := what the configuration says (always plain for RA, QuickBBS, SuperBBS)}
Function  ExtUsersFormat(FileName: String): Integer;   {0 fine (or no file), 1 DOS size (expand it), 2 a size that fits neither}
Function  ExtUsersOldSize: Word;                       {the size of the old record}
Function  ExtUsersNewSize: Word;


Implementation


Uses BaseUnix, MKString, MKFile, MKCfgAbs;


Const
  K256: Array[0..63] Of LongWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2);

  HashVersion = 1;
  AlgoPbkdf2Sha256 = 1;


Type
  Sha256Ctx = Record
    H: Array[0..7] Of LongWord;
    Buf: Array[0..63] Of Byte;
    BufLen: LongInt;
    Total: LongInt;                      {bytes so far (passwords and salts are short)}
    End;

  ByteArr = Array[0..65534] Of Byte;
  ByteArrPtr = ^ByteArr;


Function Ror(X: LongWord; N: Byte): LongWord;
  Begin
  Ror := (X Shr N) Or (X Shl (32 - N));
  End;


Procedure Sha256Init(Var C: Sha256Ctx);
  Begin
  C.H[0] := $6a09e667; C.H[1] := $bb67ae85; C.H[2] := $3c6ef372; C.H[3] := $a54ff53a;
  C.H[4] := $510e527f; C.H[5] := $9b05688c; C.H[6] := $1f83d9ab; C.H[7] := $5be0cd19;
  C.BufLen := 0;
  C.Total := 0;
  End;


Procedure Sha256Block(Var C: Sha256Ctx; Var Blk: Array Of Byte);
  Var
    W: Array[0..63] Of LongWord;
    A, B, Cc, D, E, F, G, H, T1, T2, S0, S1: LongWord;
    i: Word;

  Begin
  For i := 0 To 15 Do
    W[i] := (LongWord(Blk[i * 4]) Shl 24) Or (LongWord(Blk[i * 4 + 1]) Shl 16) Or
            (LongWord(Blk[i * 4 + 2]) Shl 8) Or LongWord(Blk[i * 4 + 3]);
  For i := 16 To 63 Do
    Begin
    S0 := Ror(W[i - 15], 7) Xor Ror(W[i - 15], 18) Xor (W[i - 15] Shr 3);
    S1 := Ror(W[i - 2], 17) Xor Ror(W[i - 2], 19) Xor (W[i - 2] Shr 10);
    W[i] := W[i - 16] + S0 + W[i - 7] + S1;
    End;
  A := C.H[0]; B := C.H[1]; Cc := C.H[2]; D := C.H[3];
  E := C.H[4]; F := C.H[5]; G := C.H[6]; H := C.H[7];
  For i := 0 To 63 Do
    Begin
    S1 := Ror(E, 6) Xor Ror(E, 11) Xor Ror(E, 25);
    T1 := H + S1 + ((E And F) Xor ((Not E) And G)) + K256[i] + W[i];
    S0 := Ror(A, 2) Xor Ror(A, 13) Xor Ror(A, 22);
    T2 := S0 + ((A And B) Xor (A And Cc) Xor (B And Cc));
    H := G; G := F; F := E; E := D + T1;
    D := Cc; Cc := B; B := A; A := T1 + T2;
    End;
  C.H[0] := C.H[0] + A; C.H[1] := C.H[1] + B; C.H[2] := C.H[2] + Cc; C.H[3] := C.H[3] + D;
  C.H[4] := C.H[4] + E; C.H[5] := C.H[5] + F; C.H[6] := C.H[6] + G; C.H[7] := C.H[7] + H;
  End;


Procedure Sha256Update(Var C: Sha256Ctx; Data: Pointer; N: LongInt);
  Var
    P: ByteArrPtr;
    i: LongInt;

  Begin
  P := ByteArrPtr(Data);
  Inc(C.Total, N);
  For i := 0 To N - 1 Do
    Begin
    C.Buf[C.BufLen] := P^[i];
    Inc(C.BufLen);
    If C.BufLen = 64 Then
      Begin
      Sha256Block(C, C.Buf);
      C.BufLen := 0;
      End;
    End;
  End;


Procedure Sha256Final(Var C: Sha256Ctx; Var Dig: Sha256Digest);
  Var
    Bits: LongInt;
    Pad: Byte;
    Len: Array[0..7] Of Byte;
    i: Word;

  Begin
  Bits := C.Total;
  Pad := $80;
  Sha256Update(C, @Pad, 1);
  Pad := 0;
  While C.BufLen <> 56 Do
    Sha256Update(C, @Pad, 1);
  FillChar(Len, 8, 0);
  {the bit count: 64 bits, big endian (the length is far below 2^29 bytes)}
  Len[4] := Byte((Bits Shr 21) And $FF);
  Len[5] := Byte((Bits Shr 13) And $FF);
  Len[6] := Byte((Bits Shr 5) And $FF);
  Len[7] := Byte((Bits Shl 3) And $FF);
  Len[3] := Byte((Bits Shr 29) And $FF);
  Sha256Update(C, @Len, 8);
  For i := 0 To 7 Do
    Begin
    Dig[i * 4] := Byte(C.H[i] Shr 24);
    Dig[i * 4 + 1] := Byte(C.H[i] Shr 16);
    Dig[i * 4 + 2] := Byte(C.H[i] Shr 8);
    Dig[i * 4 + 3] := Byte(C.H[i]);
    End;
  End;


Procedure Sha256Buf(Data: Pointer; N: LongInt; Var Dig: Sha256Digest);
  Var
    C: Sha256Ctx;

  Begin
  Sha256Init(C);
  Sha256Update(C, Data, N);
  Sha256Final(C, Dig);
  End;


Type
  HmacCtx = Record                       {the states after the key blocks: each HMAC starts from copies}
    Inner, Outer: Sha256Ctx;
    End;


Procedure HmacInit(Var M: HmacCtx; Key: Pointer; KeyLen: LongInt);
  Var
    K: Array[0..63] Of Byte;
    Pad: Array[0..63] Of Byte;
    D: Sha256Digest;
    i: Word;

  Begin
  FillChar(K, 64, 0);
  If KeyLen > 64 Then
    Begin
    Sha256Buf(Key, KeyLen, D);
    Move(D, K, 32);
    End
  Else If KeyLen > 0 Then
    Move(Key^, K, KeyLen);
  For i := 0 To 63 Do
    Pad[i] := K[i] Xor $36;
  Sha256Init(M.Inner);
  Sha256Update(M.Inner, @Pad, 64);
  For i := 0 To 63 Do
    Pad[i] := K[i] Xor $5c;
  Sha256Init(M.Outer);
  Sha256Update(M.Outer, @Pad, 64);
  FillChar(K, 64, 0);
  FillChar(Pad, 64, 0);
  End;


Procedure HmacRun(Var M: HmacCtx; Msg: Pointer; MsgLen: LongInt; Var Dig: Sha256Digest);
  Var
    I, O: Sha256Ctx;
    D: Sha256Digest;

  Begin
  I := M.Inner;
  Sha256Update(I, Msg, MsgLen);
  Sha256Final(I, D);
  O := M.Outer;
  Sha256Update(O, @D, 32);
  Sha256Final(O, Dig);
  End;


Procedure HmacSha256(Key: Pointer; KeyLen: LongInt; Msg: Pointer; MsgLen: LongInt; Var Dig: Sha256Digest);
  Var
    M: HmacCtx;

  Begin
  HmacInit(M, Key, KeyLen);
  HmacRun(M, Msg, MsgLen, Dig);
  End;


Procedure Pbkdf2Sha256(Pwd: Pointer; PwdLen: LongInt; Salt: Pointer; SaltLen: LongInt; Iter: LongInt; Var Dig: Sha256Digest);
  Var
    M: HmacCtx;
    S: Array[0..63] Of Byte;
    U, T: Sha256Digest;
    i: LongInt;
    j: Word;

  Begin
  FillChar(Dig, 32, 0);
  If (SaltLen < 0) Or (SaltLen > 60) Or (Iter < 1) Then
    Exit;
  HmacInit(M, Pwd, PwdLen);
  If SaltLen > 0 Then
    Move(Salt^, S, SaltLen);
  S[SaltLen] := 0; S[SaltLen + 1] := 0; S[SaltLen + 2] := 0; S[SaltLen + 3] := 1;   {INT(1): one block of 32 bytes}
  HmacRun(M, @S, SaltLen + 4, U);
  T := U;
  For i := 2 To Iter Do
    Begin
    HmacRun(M, @U, 32, U);
    For j := 0 To 31 Do
      T[j] := T[j] Xor U[j];
    End;
  Dig := T;
  FillChar(U, 32, 0);
  End;


Function RandomBytes(Var Buf; N: Word): Boolean;
  Var
    F: File;
    Got: Word;

  Begin
  RandomBytes := False;
  Assign(F, '/dev/urandom');
  FileMode := 0;
  Reset(F, 1);
  If IoResult <> 0 Then
    Exit;
  BlockRead(F, Buf, N, Got);
  If IoResult = 0 Then
    RandomBytes := (Got = N);
  Close(F);
  If IoResult <> 0 Then;
  End;


Function SameBytes(Const A, B; N: Word): Boolean;   {constant time}
  Var
    PA, PB: ByteArrPtr;
    D: Byte;
    i: Word;

  Begin
  PA := @A;
  PB := @B;
  D := 0;
  For i := 0 To N - 1 Do
    D := D Or (PA^[i] Xor PB^[i]);
  SameBytes := (D = 0);
  End;


Function PwdHashIsSet(Const H: PwHashType): Boolean;
  Begin
  PwdHashIsSet := (H.Algo <> 0);
  End;


Procedure PwdHashClear(Var H: PwHashType);
  Begin
  FillChar(H, SizeOf(H), 0);
  End;


Function PwdHashSet(Var H: PwHashType; Const Typed: String; Upper: Boolean): Boolean;
  Var
    Salt: Array[1..16] Of Byte;
    D: Sha256Digest;
    P: String;

  Begin
  PwdHashSet := False;
  If Not RandomBytes(Salt, 16) Then
    Exit;
  If Upper Then
    P := MKString.Upper(Typed)
  Else
    P := Typed;
  If PwdIterations < 1 Then
    PwdIterations := 20000;
  Pbkdf2Sha256(@P[1], Length(P), @Salt, 16, PwdIterations, D);
  PwdHashClear(H);
  H.Version := HashVersion;
  H.Algo := AlgoPbkdf2Sha256;
  If Upper Then
    H.Flags := phUpper;
  H.Iter := PwdIterations;
  Move(Salt, H.Salt, 16);
  Move(D, H.Hash, 32);
  FillChar(D, 32, 0);
  FillChar(P, SizeOf(P), 0);
  PwdStateNew(H);
  PwdHashSet := True;
  End;


Function PwdNow: LongInt;
  Begin
  PwdNow := fpTime;
  End;


Procedure PwdStateNew(Var H: PwHashType);
  Begin
  FillChar(H.State, SizeOf(H.State), 0);
  H.State.Changed := PwdNow;
  End;


Function PwdHashSetKeep(Var H: PwHashType; Const Typed: String; Upper: Boolean): Boolean;
  Var
    N: PwHashType;

  Begin
  PwdHashSetKeep := False;
  If PwdHashSet(N, Typed, Upper) Then
    Begin
    N.State := H.State;
    H := N;
    PwdHashSetKeep := True;
    End;
  End;


Function TryHash(Const H: PwHashType; Var P: String): Boolean;
  Var
    D: Sha256Digest;

  Begin
  Pbkdf2Sha256(@P[1], Length(P), @H.Salt, 16, H.Iter, D);
  TryHash := SameBytes(D, H.Hash, 32);
  FillChar(D, 32, 0);
  End;


Function PwdHashCheck(Const H: PwHashType; Const Typed: String): Boolean;
  Var
    P: String;
    Ok: Boolean;

  Begin
  PwdHashCheck := False;
  If (H.Version <> HashVersion) Or (H.Algo <> AlgoPbkdf2Sha256) Then
    Exit;
  If (H.Iter < 1) Or (H.Iter > 10000000) Then
    Exit;
  P := Typed;
  Ok := TryHash(H, P);
  If (Not Ok) And ((H.Flags And phUpper) <> 0) Then
    Begin
    P := MKString.Upper(Typed);
    Ok := TryHash(H, P);
    End;
  FillChar(P, SizeOf(P), 0);
  PwdHashCheck := Ok;
  End;


Function PwdNeedsRehash(Const H: PwHashType): Boolean;
  Begin
  PwdNeedsRehash := PwdHashIsSet(H) And (H.Iter < PwdIterations);
  End;


Procedure PwdModeFromConfig;
  Begin
  PwdMode := pmPlain;
  If Config <> Nil Then
    PwdMode := Config^.GetPwdMode;
  If PwdMode > pmConvert Then
    PwdMode := pmPlain;
  End;


Function ExtUsersOldSize: Word;
  Begin
  ExtUsersOldSize := SizeOf(ExtUserBaseType);
  End;


Function ExtUsersNewSize: Word;
  Begin
  ExtUsersNewSize := SizeOf(ExtUserType);
  End;


Function ExtUsersFormat(FileName: String): Integer;
  Var
    Sz: LongInt;

  Begin
  ExtUsersFormat := 0;
  If Not FileExist(FileName) Then
    Exit;
  Sz := SizeFile(FileName);
  If (Sz Mod SizeOf(ExtUserType)) = 0 Then
    ExtUsersFormat := 0
  Else If (Sz Mod SizeOf(ExtUserBaseType)) = 0 Then
    ExtUsersFormat := 1
  Else
    ExtUsersFormat := 2;
  End;


Begin
PwdIterations := 20000;
PwdMode := pmPlain;
End.
