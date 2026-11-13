program dupetest;
{$mode tp}
uses MKFile, MKString, MKDupe;
var
  D: DupeObj; Fails: Integer; FN: String; i: LongInt; Dups: Integer;
procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
end;
begin
  FN := WithBackSlash(ParamStr(1)) + 'dupes.dat';
  if FileExist(FN) then EraseFile(FN);
  D.Init;
  D.SetDays(30);
  D.Open(FN, 1000);
  Check('file created at full size', SizeFile(FN) = 1000 * 8);
  Check('first sighting is not a dupe', not D.DupeCheck(123456));
  Check('second sighting is a dupe', D.DupeCheck(123456));
  Check('other value is not a dupe', not D.DupeCheck(654321));
  Dups := 0;
  for i := 1 to 100 do if D.DupeCheck(i * 7919) then Inc(Dups);
  Check('100 new values, no false dupes', Dups = 0);
  Dups := 0;
  for i := 1 to 100 do if D.DupeCheck(i * 7919) then Inc(Dups);
  Writeln('     ', Dups, ' of 100 repeats found (the table is lossy: slots overlap)');
  Check('most repeats found', Dups >= 90);
  D.CloseFile;
  D.Open(FN, 1000);
  Check('dupes survive a reopen', D.DupeCheck(123456));
  D.CloseFile;
  D.Done;
  writeln('failures: ', Fails);
  Halt(Fails);
end.
