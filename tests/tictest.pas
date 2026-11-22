program tictest;
{$mode tp}
{$H+}
{ MKTic: reading and writing TIC files, the Path and Seenby lines, the CRC of a file, dates, names that replace others }
uses MKString, MKTic;
var Fails: Integer; T, U: TicType; W: String; F: Text; Crc, Size: LongInt; i: Integer; Rc: Word;
procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   tic: ', N) else begin writeln('FAIL tic: ', N); Inc(Fails); end; end;
procedure Put(Name, Text: String);
begin Assign(F, Name); Rewrite(F); Write(F, Text); Close(F); end;
begin
  W := ParamStr(1);
  if W = '' then W := '.';
  if W[Length(W)] <> '/' then W := W + '/';
  { a TIC as another system writes it: mixed case keywords, LF only, an unknown line, a comment, blank lines, two Ldesc lines }
  Put(W + 'a.tic', 'Created by hpt/lnx 1.4.0'#10'area FSX_GEN'#10'AREADESC General files'#10'; a comment'#10#10 +
    'Origin 21:1/100'#10'From 21:1/101'#10'To 21:1/102'#10'File SAMPLE.ZIP'#10'Size 1234'#10'Date 1000000000'#10 +
    'Replaces SAMPLE*.ZIP'#10'Desc A sample file'#10'Ldesc first line'#10'LDESC second line'#10'Magic SAMPLE'#10'Crc 0a1B2c3D'#10 +
    'X-Extra something we do not know'#10'Path 21:1/100 1000000000 Sun Sep 09 01:46:40 2001 UTC hpt'#10 +
    'Path 21:1/101 1000000100 Sun Sep 09 01:48:20 2001 UTC hpt'#10'Seenby 21:1/100'#10'Seenby 21:1/101'#10'Pw SECRET'#10);
  Rc := TicParse(W + 'a.tic', T);
  Check('a TIC with LF line ends, mixed case keywords, a comment and blank lines is read', Rc = ticOk);
  Check('Area, Areadesc, Origin, From, To, File', (T.Area = 'FSX_GEN') and (T.AreaDesc = 'General files') and (T.Origin = '21:1/100') and
    (T.From = '21:1/101') and (T.ToAddr = '21:1/102') and (T.FileName = 'SAMPLE.ZIP'));
  Check('the case of the file name is kept as it is', T.FileName = 'SAMPLE.ZIP');
  Check('Size, Date and Crc (hex in any case)', T.HasSize and (T.Size = 1234) and (T.Date = 1000000000) and T.HasCrc and (T.Crc = $0A1B2C3D));
  Check('Replaces, Desc, Magic, Pw, Created', (T.Replaces = 'SAMPLE*.ZIP') and (T.Desc = 'A sample file') and (T.Magic = 'SAMPLE') and (T.Pw = 'SECRET') and
    (T.Created = 'by hpt/lnx 1.4.0'));
  Check('two Ldesc lines in order', (T.NumLdesc = 2) and (T.Ldesc[1] = 'first line') and (T.Ldesc[2] = 'second line'));
  Check('two Path lines and two Seenby lines in order', (T.NumPath = 2) and (T.NumSeen = 2) and (T.Seen[2] = '21:1/101') and (Copy(T.Path[2], 1, 9) = '21:1/101 '));
  Check('a keyword that is not known is kept whole', (T.NumOther = 1) and (T.Other[1] = 'X-Extra something we do not know'));
  Check('TicCheck: nothing is missing', TicCheck(T) = ticOk);

  { written and read again: the same }
  Check('TicWrite writes', TicWrite(W + 'b.tic', T));
  Rc := TicParse(W + 'b.tic', U);
  Check('what was written reads back the same (every field, the lines in order)', (Rc = ticOk) and (U.Area = T.Area) and (U.FileName = T.FileName) and
    (U.Size = T.Size) and (U.Crc = T.Crc) and (U.Date = T.Date) and (U.NumLdesc = 2) and (U.Ldesc[2] = 'second line') and (U.NumPath = 2) and
    (U.Path[1] = T.Path[1]) and (U.NumSeen = 2) and (U.Pw = 'SECRET') and (U.NumOther = 1) and (U.Replaces = T.Replaces) and (U.Created = T.Created));
  Assign(F, W + 'b.tic'); Reset(F); ReadLn(F, W); Close(F);
  Check('the written file has CR LF line ends and starts with Created', Pos('Created by hpt', W) = 1);
  W := ParamStr(1); if W = '' then W := '.'; if W[Length(W)] <> '/' then W := W + '/';

  { a CRC is 8 upper case hex digits }
  T.Crc := $00ABCDEF;
  Check('a CRC is written as 8 hex digits, upper case, with leading zeros', TicCrcStr(T.Crc) = '00ABCDEF');
  Check('a negative (high bit) CRC prints right', TicCrcStr(LongInt($CBF43926)) = 'CBF43926');

  { the checks }
  TicInit(U); U.Area := 'X'; U.HasCrc := True;
  Check('TicCheck: no File line', TicCheck(U) = ticNoName);
  U.FileName := 'F.ZIP'; U.Area := '';
  Check('TicCheck: no Area line', TicCheck(U) = ticNoArea);
  U.Area := 'X'; U.HasCrc := False;
  Check('TicCheck: no usable Crc', TicCheck(U) = ticBadCrc);
  Put(W + 'c.tic', 'Area X'#13#10'File F.ZIP'#13#10'Size 12x'#13#10'Crc 123456789'#13#10);
  Rc := TicParse(W + 'c.tic', U);
  Check('a Size that is not a number, a Crc of nine digits: CR LF line ends are read, the fields are bad', (Rc = ticOk) and (TicCheck(U) = ticBadSize) and (U.FileName = 'F.ZIP'));
  Put(W + 'd.tic', 'Area X'#13#10'File F.ZIP'#13#10'Crc 123456789'#13#10);
  TicParse(W + 'd.tic', U);
  Check('... and a Crc that is not 8 digits is no Crc', TicCheck(U) = ticBadCrc);
  Check('a TIC that is not there', TicParse(W + 'nothere.tic', U) = ticNoFile);

  { the CRC of a file: the check value of CRC-32 is CBF43926 for "123456789" }
  Put(W + 'crc.txt', '123456789');
  Check('TicFileCrc of "123456789": CBF43926, 9 bytes', TicFileCrc(W + 'crc.txt', Crc, Size) and (Crc = LongInt($CBF43926)) and (Size = 9));
  Put(W + 'empty.bin', '');
  Check('an empty file: CRC 00000000, size 0', TicFileCrc(W + 'empty.bin', Crc, Size) and (Crc = 0) and (Size = 0));
  Check('a file that is not there', not TicFileCrc(W + 'nothere.bin', Crc, Size));

  { dates: UTC }
  Check('TicDateStr(0) = Thu Jan 01 00:00:00 1970', TicDateStr(0) = 'Thu Jan 01 00:00:00 1970');
  Check('TicDateStr(1000000000) = Sun Sep 09 01:46:40 2001', TicDateStr(1000000000) = 'Sun Sep 09 01:46:40 2001');
  Check('a leap day: 951782400 = Tue Feb 29 00:00:00 2000', TicDateStr(951782400) = 'Tue Feb 29 00:00:00 2000');
  Check('the last second of a year: 1767225599 = Wed Dec 31 23:59:59 2025', TicDateStr(1767225599) = 'Wed Dec 31 23:59:59 2025');

  { the Path and Seenby lines }
  TicInit(U);
  TicAddPath(U, '21:1/100', 1000000000, 'mktoss');
  Check('TicAddPath: the address, the seconds, the date, UTC and the program', U.Path[1] = '21:1/100 1000000000 Sun Sep 09 01:46:40 2001 UTC mktoss');
  Check('TicInPath finds the address, not a longer or another one', TicInPath(U, '21:1/100') and (not TicInPath(U, '21:1/10')) and (not TicInPath(U, '21:1/100.5')) and (not TicInPath(U, '21:2/100')));
  Check('addresses are the same with a .0 point, another case or a domain', TicSameAddr('21:1/100', '21:1/100.0@fsxnet') and TicSameAddr('2:5020/1', ' 2:5020/1 '));
  TicAddSeen(U, '21:1/100'); TicAddSeen(U, '21:1/100.0'); TicAddSeen(U, '21:1/200');
  Check('TicAddSeen does not add one twice (.0 is the same)', (U.NumSeen = 2) and TicInSeen(U, '21:1/200') and (not TicInSeen(U, '21:1/300')));
  for i := 1 to TicMaxPath + 5 do TicAddPath(U, '21:9/' + Long2Str(i), 1000000000 + i, 'x');
  Check('too many Path lines: the oldest go, the newest stay', (U.NumPath = TicMaxPath) and TicInPath(U, '21:9/' + Long2Str(TicMaxPath + 5)) and (not TicInPath(U, '21:1/100')));

  { Replaces }
  Check('Replaces: * and ?, not case sensitive', TicMatchName('SAMPLE*.ZIP', 'sample03.zip') and TicMatchName('FILE?.ZIP', 'file1.zip') and
    (not TicMatchName('FILE?.ZIP', 'file12.zip')) and TicMatchName('*', 'anything.bin') and (not TicMatchName('SAMPLE.ZIP', 'SAMPLE2.ZIP')) and TicMatchName('A*B*C', 'aXXbYYc'));
  writeln('failures: ', Fails);
  if Fails > 0 then Halt(1);
end.
