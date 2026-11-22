Program PwdTest;
{$MODE TP}
{ MKPwd: SHA-256, HMAC, PBKDF2 against known results, the hash block (set, check, wrong, upper flag, clear), record sizes }

Uses MKPwd, MKRCfgMK;

Var
  Fails: Integer;


Function Hex(Var D: Sha256Digest): String;
  Const Dg = '0123456789abcdef';
  Var i: Word; S: String;
  Begin
  S := '';
  For i := 0 To 31 Do
    S := S + Dg[(D[i] Shr 4) + 1] + Dg[(D[i] And 15) + 1];
  Hex := S;
  End;


Procedure Check(Ok: Boolean; Const What: String);
  Begin
  If Ok Then
    WriteLn('ok   pwd: ', What)
  Else
    Begin
    WriteLn('FAIL pwd: ', What);
    Inc(Fails);
    End;
  End;


Var
  D: Sha256Digest;
  S, S2: String;
  H, H2: PwHashType;
  Big: Array[1..300] Of Byte;
  i: Word;

Begin
Fails := 0;
S := 'abc';
Sha256Buf(@S[1], 3, D);
Check(Hex(D) = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'SHA-256 of "abc"');
Sha256Buf(@S[1], 0, D);
Check(Hex(D) = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'SHA-256 of nothing');
S := 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
Sha256Buf(@S[1], Length(S), D);
Check(Hex(D) = '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1', 'SHA-256 of 56 bytes (two blocks)');
FillChar(Big, 300, Ord('a'));
Sha256Buf(@Big, 300, D);
Check(Hex(D) = '9835fa6bf4e20a9b9ea812506302e98982721a6cf8d2cae67af57129bf21ae90', 'SHA-256 of 300 bytes');
S := 'Jefe'; S2 := 'what do ya want for nothing?';
HmacSha256(@S[1], 4, @S2[1], Length(S2), D);
Check(Hex(D) = '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843', 'HMAC-SHA256 (RFC 4231 case 2)');
S := 'password'; S2 := 'salt';
Pbkdf2Sha256(@S[1], 8, @S2[1], 4, 1, D);
Check(Hex(D) = '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b', 'PBKDF2 1 iteration');
Pbkdf2Sha256(@S[1], 8, @S2[1], 4, 2, D);
Check(Hex(D) = 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43', 'PBKDF2 2 iterations');
Pbkdf2Sha256(@S[1], 8, @S2[1], 4, 4096, D);
Check(Hex(D) = 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a', 'PBKDF2 4096 iterations');

Check(SizeOf(PwHashType) = 183, 'the hash block is 183 bytes (55 used, 128 reserved)');
Check(SizeOf(ExtUserType) = SizeOf(ExtUserBaseType) + SizeOf(PwHashType), 'the new record is the old one plus the hash block');
Check(ExtUsersNewSize = SizeOf(ExtUserType), 'ExtUsersNewSize');

PwdIterations := 500;
Check(PwdHashSet(H, 'Secret Pw', False), 'a hash is made');
Check(PwdHashIsSet(H), 'the block says it holds a hash');
Check(PwdHashCheck(H, 'Secret Pw'), 'the right password');
Check(Not PwdHashCheck(H, 'secret pw'), 'case counts (typed as set)');
Check(Not PwdHashCheck(H, 'Secret P'), 'a prefix is wrong');
Check(Not PwdHashCheck(H, ''), 'nothing is wrong');
Check(PwdHashSet(H2, 'Secret Pw', False) And (CompareByte(H.Salt, H2.Salt, 16) <> 0) And (CompareByte(H.Hash, H2.Hash, 32) <> 0), 'a new salt every time: another hash');
Check(Not PwdNeedsRehash(H), 'iterations are current');
PwdIterations := 1000;
Check(PwdNeedsRehash(H), 'fewer iterations than now: rehash');
Check(PwdHashSet(H, 'SECRET', True), 'a converted hash (upper case)');
Check(PwdHashCheck(H, 'SECRET'), 'converted: typed in upper case');
Check(PwdHashCheck(H, 'secret'), 'converted: typed in lower case');
Check(PwdHashCheck(H, 'Secret'), 'converted: typed in mixed case');
Check(Not PwdHashCheck(H, 'SECRE'), 'converted: wrong');
H2 := H;
H2.Algo := 9;
Check(Not PwdHashCheck(H2, 'SECRET'), 'an unknown algorithm never matches');
H2 := H;
H2.Version := 2;
Check(Not PwdHashCheck(H2, 'SECRET'), 'an unknown version never matches');
H2 := H;
H2.Iter := 0;
Check(Not PwdHashCheck(H2, 'SECRET'), 'no iterations never matches');
H2 := H;
H2.Hash[7] := H2.Hash[7] Xor 1;
Check(Not PwdHashCheck(H2, 'SECRET'), 'a damaged hash never matches');
PwdHashClear(H);
Check(Not PwdHashIsSet(H), 'cleared');
Check(Not PwdHashCheck(H, ''), 'a cleared block matches nothing');
Check(Not PwdHashCheck(H, 'SECRET'), 'a cleared block matches no password');
For i := 1 To 115 Do
  If H.Reserved[i] <> 0 Then
    Check(False, 'reserved bytes stay zero');
Check(SizeOf(PwHashType) = 183, 'the hash block is still 183 bytes (the state took 13 of the reserved ones)');
{the state of a password: when it was set, the failures, the lock}
Check(PwdHashSet(H, 'Secret', False), 'a hash is made');
Check((H.State.Changed > 1700000000) And (Abs(H.State.Changed - PwdNow) < 5), 'a new hash has the time it was made as Changed');
Check((H.State.Fails = 0) And (H.State.FailTime = 0) And (H.State.LockUntil = 0), '... and no failures, no lock');
H.State.Fails := 7; H.State.FailTime := 1234; H.State.LockUntil := 5678; H.State.Changed := 4242;
Check(PwdHashSetKeep(H, 'Other One', False) And PwdHashCheck(H, 'Other One') And (Not PwdHashCheck(H, 'Secret')), 'PwdHashSetKeep makes a new hash');
Check((H.State.Fails = 7) And (H.State.FailTime = 1234) And (H.State.LockUntil = 5678) And (H.State.Changed = 4242), '... and the state is the one that was there (a hash that is renewed is not a new password)');
PwdStateNew(H);
Check((H.State.Fails = 0) And (H.State.LockUntil = 0) And (Abs(H.State.Changed - PwdNow) < 5), 'PwdStateNew: set now, no failures, no lock');

WriteLn('failures: ', Fails);
If Fails > 0 Then Halt(1);
End.
