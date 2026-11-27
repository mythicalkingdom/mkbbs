{ SPDX-License-Identifier: GPL-3.0-or-later }
Program PcbDirTest;
{$MODE OBJFPC}{$H+}
{ the PCBoard DIR file lines of MKFileList (the examples are from PCBFiler's documentation) }
Uses SysUtils, MKFileList;

Var
  Fails: Integer = 0;

Procedure Check(Const What: String; Ok: Boolean);
  Begin
  If Ok Then
    WriteLn('ok   pcbdir: ', What)
  Else
    Begin
    WriteLn('FAIL pcbdir: ', What);
    Inc(Fails);
    End;
  End;

Function Dos(Y, M, D: Integer): LongInt;
  Begin
  Result := ((Y - 1980) Shl 25) Or (M Shl 21) Or (D Shl 16);
  End;

Var
  N, D, T: ShortString;
  Sz, Tm: LongInt;

Begin
Check('a primary line: name, size, date, description',
  PcbPrimary('PCBDEMO1.ZIP   315899  11-22-91  PCBoard 14.5a Demo Disk #1', N, Sz, Tm, D) And (N = 'PCBDEMO1.ZIP') And (Sz = 315899) And (Tm = Dos(1991, 11, 22)) And (D = 'PCBoard 14.5a Demo Disk #1'));
Check('size flush right in column 20, date in column 24, description in column 34 (the documented columns)',
  PcbPrimary('OVLSIZE.ZIP      7986  11-25-91  Use to adjust the size of the overlay buf', N, Sz, Tm, D) And (N = 'OVLSIZE.ZIP') And (Sz = 7986) And (D = 'Use to adjust the size of the overlay buf'));
Check('the other layout: DD-MMM-YY and a time after it',
  PcbPrimary('PCBFILER.ZIP    12345     15-NOV-93    00:00:00  ', N, Sz, Tm, D) And (N = 'PCBFILER.ZIP') And (Sz = 12345) And (Tm = Dos(1993, 11, 15)) And (D = ''));
Check('a file with a date from the year 2000 on (YY < 80)', PcbPrimary('A.ZIP 1 01-02-05 x', N, Sz, Tm, D) And (Tm = Dos(2005, 1, 2)));
Check('a line of files.bbs is not a PCBoard line', Not PcbPrimary('README.TXT      The readme of the area', N, Sz, Tm, D));
Check('text is not a primary line (a header)', Not PcbPrimary('PCBoard VROOM Overlay Size Adjustment', N, Sz, Tm, D));
Check('a rule line is not', Not PcbPrimary('-------------------------------------', N, Sz, Tm, D));
Check('an include line is not a primary line', Not PcbPrimary('%C:\PCB\DIR\DISCLAIM', N, Sz, Tm, D));
Check('an impossible date is not a primary line', Not PcbPrimary('A.ZIP 100 13-45-91 x', N, Sz, Tm, D));
Check('a secondary line: a space first, a bar, the bar is taken out',
  PcbSecondary('                               | in the VROOM OVERLAY version of PCBoard v', T) And (Pos('|', T) = 0) And (Pos('in the VROOM OVERLAY', T) > 0));
Check('a line without a bar is not secondary', Not PcbSecondary('   just text', T));
Check('a line that does not start with a space is not secondary', Not PcbSecondary('X | y', T));
Check('@X colour codes are taken out', PcbStripCodes('@X0EHello @X07world') = 'Hello world');
Check('an @ that is not a code stays', PcbStripCodes('mail me @ home') = 'mail me @ home');
WriteLn('failures: ', Fails);
If Fails > 0 Then
  Halt(1);
End.
