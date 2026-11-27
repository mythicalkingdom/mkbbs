{ SPDX-License-Identifier: GPL-3.0-or-later }
program stdtest;
{$mode tp}
{ MKComStd on a pipe: run as   printf 'abc' | stdtest   -> prints "ABC" (no more output once the caller is gone) }
uses MKComAbs, MKComStd;
var S: StdComObj; C: Char; N: Word;
begin
  S.Init;
  ComSession := @S;
  CommInit;
  while CommCarrier do
  begin
    if S.WaitForChar(200) then
    begin
      C := CommRecv;
      CommSend(UpCase(C));
      Inc(N);
    end;
  end;
  S.SendStr('[eof ' + Chr(48 + N mod 10) + ']');
  CommFlushOut;
  CommRelease;
  S.Done;
end.
