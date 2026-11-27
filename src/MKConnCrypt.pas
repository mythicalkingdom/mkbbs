{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKConnCrypt;   {the phone book of mkconnect, sealed with the start password: ChaCha20 and HMAC-SHA256 (MKCONNECT-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
  A sealed file:
        "MKCB"  version 1 (1 byte)  iterations (4 bytes, big endian)  salt (16)  nonce (12)  the text, encrypted  tag (32)
  The password goes through PBKDF2-HMAC-SHA256 (the iterations, the salt) to a master key; the key of the cipher and the key of the tag are two HMAC-SHA256 of the master key
  (the words "mkconnect enc" and "mkconnect mac").  The cipher is ChaCha20 (RFC 8439, block counter from 1), the tag is the HMAC-SHA256 of everything before it, checked in constant time
  before anything is decrypted: a wrong password and a damaged file are both "does not open".  The salt and the nonce are new for every save.
}

Interface

Const
  ConnIterations = 100000;

Type
  { the keys of a password: derived once (it takes about a second) and kept, so that a program that saves often does not wait for it each time; every save has a new nonce }
  TSealKeys = Record
    Valid: Boolean;
    Salt: Array[0..15] Of Byte;
    Iter: LongInt;
    Enc, Mac: Array[0..31] Of Byte;
    Password: RawByteString;           {the password they came from}
  End;

Function ConnNewKeys(Const Password: RawByteString; Iter: LongInt; Out K: TSealKeys): Boolean;   {a new salt}
Function ConnSealWith(Const Plain: RawByteString; Const K: TSealKeys): RawByteString;
Function ConnOpenKeep(Const Data, Password: RawByteString; Out Plain: RawByteString; Out K: TSealKeys): Boolean;   {the keys of the file's own salt, for the next saves}

Function ConnSeal(Const Plain, Password: RawByteString; Iter: LongInt = ConnIterations): RawByteString;
Function ConnIsSealed(Const Data: RawByteString): Boolean;
Function ConnOpen(Const Data, Password: RawByteString; Out Plain: RawByteString): Boolean;   {False: not sealed, a wrong password or a damaged file}

{ ChaCha20 on its own (the tests check it against RFC 8439) }
Procedure ChaCha20Xor(Const Key; Const Nonce; Counter: LongWord; Var Data; N: LongInt);
Procedure ChaCha20Block(Const Key; Const Nonce; Counter: LongWord; Out Block: Array Of Byte);

Implementation

Uses MKPwd;

Const
  Magic = 'MKCB';
  HeadLen = 4 + 1 + 4 + 16 + 12;


Function Rol(X: LongWord; N: Byte): LongWord;
  Begin
  Result := (X Shl N) Or (X Shr (32 - N));
  End;


Procedure QR(Var S: Array Of LongWord; a, b, c, d: Integer);
  Begin
  S[a] := S[a] + S[b]; S[d] := Rol(S[d] Xor S[a], 16);
  S[c] := S[c] + S[d]; S[b] := Rol(S[b] Xor S[c], 12);
  S[a] := S[a] + S[b]; S[d] := Rol(S[d] Xor S[a], 8);
  S[c] := S[c] + S[d]; S[b] := Rol(S[b] Xor S[c], 7);
  End;


Function LE32(Const P; Off: Integer): LongWord;
  Var
    B: PByte;

  Begin
  B := PByte(@P) + Off;
  Result := LongWord(B[0]) Or (LongWord(B[1]) Shl 8) Or (LongWord(B[2]) Shl 16) Or (LongWord(B[3]) Shl 24);
  End;


Procedure ChaCha20Block(Const Key; Const Nonce; Counter: LongWord; Out Block: Array Of Byte);
  Var
    S, W: Array[0..15] Of LongWord;
    i: Integer;

  Begin
  S[0] := $61707865; S[1] := $3320646e; S[2] := $79622d32; S[3] := $6b206574;
  For i := 0 To 7 Do
    S[4 + i] := LE32(Key, 4 * i);
  S[12] := Counter;
  For i := 0 To 2 Do
    S[13 + i] := LE32(Nonce, 4 * i);
  W := S;
  For i := 1 To 10 Do
    Begin
    QR(W, 0, 4, 8, 12); QR(W, 1, 5, 9, 13); QR(W, 2, 6, 10, 14); QR(W, 3, 7, 11, 15);
    QR(W, 0, 5, 10, 15); QR(W, 1, 6, 11, 12); QR(W, 2, 7, 8, 13); QR(W, 3, 4, 9, 14);
    End;
  For i := 0 To 15 Do
    Begin
    W[i] := W[i] + S[i];
    Block[4 * i] := W[i] And $FF;
    Block[4 * i + 1] := (W[i] Shr 8) And $FF;
    Block[4 * i + 2] := (W[i] Shr 16) And $FF;
    Block[4 * i + 3] := (W[i] Shr 24) And $FF;
    End;
  End;


Procedure ChaCha20Xor(Const Key; Const Nonce; Counter: LongWord; Var Data; N: LongInt);
  Var
    B: Array[0..63] Of Byte;
    P: PByte;
    i, k: LongInt;

  Begin
  P := PByte(@Data);
  i := 0;
  While i < N Do
    Begin
    ChaCha20Block(Key, Nonce, Counter, B);
    Inc(Counter);
    For k := 0 To 63 Do
      If i + k < N Then
        P[i + k] := P[i + k] Xor B[k];
    Inc(i, 64);
    End;
  End;


Procedure Keys(Const Password: RawByteString; Const Salt; Iter: LongInt; Out EncKey, MacKey: Sha256Digest);
  Var
    Master: Sha256Digest;
    A, B: RawByteString;

  Begin
  If Password = '' Then
    Pbkdf2Sha256(Nil, 0, @Salt, 16, Iter, Master)
  Else
    Pbkdf2Sha256(@Password[1], Length(Password), @Salt, 16, Iter, Master);
  A := 'mkconnect enc';
  B := 'mkconnect mac';
  HmacSha256(@Master, 32, @A[1], Length(A), EncKey);
  HmacSha256(@Master, 32, @B[1], Length(B), MacKey);
  End;


Function SameBytes(Const A, B; N: Word): Boolean;   {in constant time}
  Var
    i: Integer;
    D: Byte;

  Begin
  D := 0;
  For i := 0 To N - 1 Do
    D := D Or (PByte(@A)[i] Xor PByte(@B)[i]);
  Result := D = 0;
  End;


Function ConnNewKeys(Const Password: RawByteString; Iter: LongInt; Out K: TSealKeys): Boolean;
  Var
    Ek, Mk: Sha256Digest;

  Begin
  K.Valid := False;
  Result := RandomBytes(K.Salt, 16);
  If Not Result Then
    Exit;
  Keys(Password, K.Salt, Iter, Ek, Mk);
  Move(Ek, K.Enc, 32);
  Move(Mk, K.Mac, 32);
  K.Iter := Iter;
  K.Password := Password;
  K.Valid := True;
  End;


Function ConnSealWith(Const Plain: RawByteString; Const K: TSealKeys): RawByteString;
  Var
    Nonce: Array[0..11] Of Byte;
    Tag: Sha256Digest;
    Body, Head: RawByteString;
    i: Integer;

  Begin
  Result := '';
  If (Not K.Valid) Or (Not RandomBytes(Nonce, 12)) Then
    Exit;
  Body := Plain;
  If Body <> '' Then
    ChaCha20Xor(K.Enc, Nonce, 1, Body[1], Length(Body));
  Head := Magic + #1 + Chr((K.Iter Shr 24) And $FF) + Chr((K.Iter Shr 16) And $FF) + Chr((K.Iter Shr 8) And $FF) + Chr(K.Iter And $FF);
  For i := 0 To 15 Do
    Head := Head + Chr(K.Salt[i]);
  For i := 0 To 11 Do
    Head := Head + Chr(Nonce[i]);
  Result := Head + Body;
  HmacSha256(@K.Mac, 32, @Result[1], Length(Result), Tag);
  SetLength(Head, 32);
  Move(Tag, Head[1], 32);
  Result := Result + Head;
  End;


Function ConnIsSealed(Const Data: RawByteString): Boolean;
  Begin
  Result := (Length(Data) >= HeadLen + 32) And (Copy(Data, 1, 4) = Magic);
  End;


Function ConnSeal(Const Plain, Password: RawByteString; Iter: LongInt): RawByteString;
  Var
    Salt: Array[0..15] Of Byte;
    Nonce: Array[0..11] Of Byte;
    Ek, Mk, Tag: Sha256Digest;
    Body: RawByteString;
    Head: RawByteString;
    i: Integer;

  Begin
  If (Not RandomBytes(Salt, 16)) Or (Not RandomBytes(Nonce, 12)) Then
    Begin
    Result := '';
    Exit;
    End;
  Keys(Password, Salt, Iter, Ek, Mk);
  Body := Plain;
  If Body <> '' Then
    ChaCha20Xor(Ek, Nonce, 1, Body[1], Length(Body));
  Head := Magic + #1 + Chr((Iter Shr 24) And $FF) + Chr((Iter Shr 16) And $FF) + Chr((Iter Shr 8) And $FF) + Chr(Iter And $FF);
  For i := 0 To 15 Do
    Head := Head + Chr(Salt[i]);
  For i := 0 To 11 Do
    Head := Head + Chr(Nonce[i]);
  Result := Head + Body;
  HmacSha256(@Mk, 32, @Result[1], Length(Result), Tag);
  SetLength(Head, 32);
  Move(Tag, Head[1], 32);
  Result := Result + Head;
  End;


Function ConnOpen(Const Data, Password: RawByteString; Out Plain: RawByteString): Boolean;
  Var
    Iter: LongInt;
    Salt, Nonce: Array[0..15] Of Byte;
    Ek, Mk, Tag: Sha256Digest;
    N: LongInt;
    i: Integer;

  Begin
  Result := False;
  Plain := '';
  If (Not ConnIsSealed(Data)) Or (Data[5] <> #1) Then
    Exit;
  Iter := (Ord(Data[6]) Shl 24) Or (Ord(Data[7]) Shl 16) Or (Ord(Data[8]) Shl 8) Or Ord(Data[9]);
  If (Iter < 1000) Or (Iter > 5000000) Then
    Exit;
  For i := 0 To 15 Do
    Salt[i] := Ord(Data[10 + i]);
  For i := 0 To 11 Do
    Nonce[i] := Ord(Data[26 + i]);
  Keys(Password, Salt, Iter, Ek, Mk);
  N := Length(Data) - 32;
  HmacSha256(@Mk, 32, @Data[1], N, Tag);
  If Not SameBytes(Tag, Data[N + 1], 32) Then
    Exit;
  Plain := Copy(Data, HeadLen + 1, N - HeadLen);
  If Plain <> '' Then
    ChaCha20Xor(Ek, Nonce, 1, Plain[1], Length(Plain));
  Result := True;
  End;


Function ConnOpenKeep(Const Data, Password: RawByteString; Out Plain: RawByteString; Out K: TSealKeys): Boolean;
  Var
    Iter: LongInt;
    Salt: Array[0..15] Of Byte;
    Nonce: Array[0..11] Of Byte;
    Ek, Mk, Tag: Sha256Digest;
    N: LongInt;
    i: Integer;

  Begin
  Result := False;
  Plain := '';
  K.Valid := False;
  If (Not ConnIsSealed(Data)) Or (Data[5] <> #1) Then
    Exit;
  Iter := (Ord(Data[6]) Shl 24) Or (Ord(Data[7]) Shl 16) Or (Ord(Data[8]) Shl 8) Or Ord(Data[9]);
  If (Iter < 1000) Or (Iter > 5000000) Then
    Exit;
  For i := 0 To 15 Do
    Salt[i] := Ord(Data[10 + i]);
  For i := 0 To 11 Do
    Nonce[i] := Ord(Data[26 + i]);
  Keys(Password, Salt, Iter, Ek, Mk);
  N := Length(Data) - 32;
  HmacSha256(@Mk, 32, @Data[1], N, Tag);
  If Not SameBytes(Tag, Data[N + 1], 32) Then
    Exit;
  Plain := Copy(Data, HeadLen + 1, N - HeadLen);
  If Plain <> '' Then
    ChaCha20Xor(Ek, Nonce, 1, Plain[1], Length(Plain));
  Move(Salt, K.Salt, 16);
  K.Iter := Iter;
  Move(Ek, K.Enc, 32);
  Move(Mk, K.Mac, 32);
  K.Password := Password;
  K.Valid := True;
  Result := True;
  End;


End.
