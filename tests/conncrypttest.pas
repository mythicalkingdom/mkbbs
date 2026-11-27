{ SPDX-License-Identifier: GPL-3.0-or-later }
program conncrypttest;
{ the cipher against RFC 8439, and the sealed file: it opens with the password, not with another, not when one byte is changed }
{$mode objfpc}{$H+}
uses SysUtils, MKConnCrypt;

var
  Fails: Integer = 0;

procedure Check(const Name: string; Ok: Boolean; const Info: string = '');
begin
  if Ok then WriteLn('ok   ', Name) else begin WriteLn('FAIL ', Name, '  ', Info); Inc(Fails); end;
end;

function Hex(const S: RawByteString): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do Result := Result + LowerCase(IntToHex(Ord(S[i]), 2));
end;

var
  Key: array[0..31] of Byte;
  Nonce: array[0..11] of Byte;
  Blk: array[0..63] of Byte;
  i: Integer;
  S, T, P: RawByteString;
const
  Msg = 'Ladies and Gentlemen of the class of ''99: If I could offer you only one tip for the future, sunscreen would be it.';
begin
  for i := 0 to 31 do Key[i] := i;
  FillChar(Nonce, 12, 0);
  Nonce[3] := 9; Nonce[7] := $4a;
  ChaCha20Block(Key, Nonce, 1, Blk);
  SetLength(S, 64); Move(Blk, S[1], 64);
  Check('ChaCha20 block (RFC 8439 2.3.2)', Copy(Hex(S), 1, 64) = '10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4e', Hex(S));
  FillChar(Nonce, 12, 0);
  Nonce[7] := $4a;
  S := Msg;
  ChaCha20Xor(Key, Nonce, 1, S[1], Length(S));
  Check('ChaCha20 encryption (RFC 8439 2.4.2)', (Copy(Hex(S), 1, 32) = '6e2e359a2568f98041ba0728dd0d6981') and (Length(S) = Length(Msg)), Hex(S));
  ChaCha20Xor(Key, Nonce, 1, S[1], Length(S));
  Check('and back', S = Msg);
  T := ConnSeal('name = a' + #10 + 'password = secret' + #10, 'start', 2000);
  Check('a sealed file has the magic and no plain text', ConnIsSealed(T) and (Pos('secret', T) = 0) and (Pos('name', T) = 0), Hex(Copy(T, 1, 20)));
  Check('it opens with the password', ConnOpen(T, 'start', P) and (P = 'name = a' + #10 + 'password = secret' + #10));
  Check('not with another password', not ConnOpen(T, 'Start', P) and (P = ''));
  S := T; S[40] := Chr(Ord(S[40]) xor 1);
  Check('not when a byte of the text is changed', not ConnOpen(S, 'start', P));
  S := T; S[Length(S)] := Chr(Ord(S[Length(S)]) xor 1);
  Check('not when the tag is changed', not ConnOpen(S, 'start', P));
  S := T; S[8] := Chr(Ord(S[8]) xor 1);
  Check('not when the iterations are changed', not ConnOpen(S, 'start', P));
  Check('a seal is new every time (salt and nonce)', ConnSeal('x', 'start', 2000) <> ConnSeal('x', 'start', 2000));
  Check('not sealed: plain text and the empty string', (not ConnIsSealed('[a]' + #10)) and not ConnIsSealed('') and not ConnOpen('[a]', 'x', P));
  Check('an empty text seals and opens', ConnOpen(ConnSeal('', 'pw', 2000), 'pw', P) and (P = ''));
  S := StringOfChar('x', 1000) + #0#255;
  Check('a long text with any bytes', ConnOpen(ConnSeal(S, '', 2000), '', P) and (P = S));
  WriteLn('failures: ', Fails);
  if Fails > 0 then Halt(1);
end.
