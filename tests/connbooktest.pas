program connbooktest;
{ the phone book: plain and sealed, the wrong password, values kept as they are (blanks in a password, UTF-8), sorting, deleting }
{$mode objfpc}{$H+}
uses SysUtils, Classes, BaseUnix, MKConnBook;

var
  Fails: Integer = 0;

procedure Check(const Name: string; Ok: Boolean; const Info: string = '');
begin
  if Ok then WriteLn('ok   ', Name) else begin WriteLn('FAIL ', Name, '  ', Info); Inc(Fails); end;
end;

var
  Dir, FN, Why: string;
  B, B2: TConnBook;
  E: TConnEntry;
  S: TFileStream;
  Raw: string;
  St: Stat;
begin
  Dir := GetTempDir + 'connbook' + IntToStr(fpGetPid);
  FN := Dir + '/sub/phonebook';
  B := TConnBook.Create(FN);
  Check('no file: nothing is there, it loads empty', (not B.Exists) and (B.Load('', Why) = 0) and (B.Count = 0));
  ConnNewEntry(E);
  E.Name := 'Zeta BBS'; E.Host := 'zeta.example.org'; E.Port := 2323; E.Password := '  pass word  '; E.Login := 'Mark May'; E.Note := 'caf' + #$C3#$A9 + ' note'; E.Last := 100; E.Calls := 3;
  B.Add(E);
  ConnNewEntry(E);
  E.Name := 'alpha'; E.Host := '2001:db8::1'; E.Kind := ckSsh; E.Port := 22; E.SshUser := 'mark'; E.Utf8 := True; E.Last := 900;
  B.Add(E);
  ConnNewEntry(E);
  E.Name := 'Mid'; E.Host := 'mid.example.org'; E.Kind := ckTelnets; E.Port := 992; E.Last := 500; E.Script := 'x.scr';
  B.Add(E);
  Check('saved sealed: the folder is made (mode 700), the file is mode 600', B.Save('start', True, Why) and FileExists(FN) and (fpStat(FN, St) = 0) and ((St.st_mode and &777) = &600), Why);
  fpStat(Dir + '/sub', St);
  Check('... the folder is private', (St.st_mode and &777) = &700);
  S := TFileStream.Create(FN, fmOpenRead);
  SetLength(Raw, S.Size); S.ReadBuffer(Raw[1], S.Size); S.Free;
  Check('the file on disk has no host name and no password in it', (Pos('example.org', Raw) = 0) and (Pos('pass word', Raw) = 0) and (Copy(Raw, 1, 4) = 'MKCB'));
  B2 := TConnBook.Create(FN);
  Check('it says it is sealed, and a load without the password says so', B2.IsSealedOnDisk and (B2.Load('', Why) = 1));
  Check('a wrong password is refused', B2.Load('nope', Why) = 2);
  Check('the right password loads all three', (B2.Load('start', Why) = 0) and (B2.Count = 3) and B2.Sealed);
  Check('every field came back (blanks in the password, UTF-8 in the note, port, kind, charset, script, ssh user, last, calls)',
        (B2.Items[0].Password = '  pass word  ') and (B2.Items[0].Note = 'caf' + #$C3#$A9 + ' note') and (B2.Items[0].Port = 2323) and (B2.Items[0].Login = 'Mark May') and (B2.Items[0].Calls = 3) and (B2.Items[0].Last = 100)
        and (B2.Items[1].Kind = ckSsh) and (B2.Items[1].SshUser = 'mark') and B2.Items[1].Utf8 and (B2.Items[1].Host = '2001:db8::1') and (B2.Items[2].Kind = ckTelnets) and (B2.Items[2].Script = 'x.scr'));
  B2.SortByName;
  Check('sorted by name (not case sensitive): alpha, Mid, Zeta BBS', (B2.Items[0].Name = 'alpha') and (B2.Items[1].Name = 'Mid') and (B2.Items[2].Name = 'Zeta BBS'));
  B2.SortByLast;
  Check('sorted by the last call, the newest first', (B2.Items[0].Name = 'alpha') and (B2.Items[1].Name = 'Mid') and (B2.Items[2].Name = 'Zeta BBS'));
  Check('find, not case sensitive', (B2.Find('MID') = 1) and (B2.Find('nope') = -1));
  B2.Delete(1);
  Check('delete', (B2.Count = 2) and (B2.Find('Mid') = -1));
  Check('saved without a seal: plain text with the blocks', B2.Save('', False, Why) and not B2.IsSealedOnDisk);
  B := TConnBook.Create(FN);
  Check('a plain file loads with no password', (B.Load('', Why) = 0) and (B.Count = 2) and (not B.Sealed) and (B.Items[1].Password = '  pass word  '));
  ConnNewEntry(E); E.Name := 'two' + #10 + 'lines'; E.Host := 'h';
  B.Items[0] := E;
  B.Save('', False, Why);
  Check('a value with a line end in it is kept on one line', (B.Load('', Why) = 0) and (B.Count = 2) and (B.Items[0].Name = 'two lines'), Why);
  S := TFileStream.Create(FN, fmCreate); Raw := '[entry]'#10'name = x'#10'port = 99'#10'kind = nonsense'#10'bogus = 1'#10; S.WriteBuffer(Raw[1], Length(Raw)); S.Free;
  Check('what is not understood is left out (a kind that is none, a key that is not one), the rest is kept', (B.Load('', Why) = 0) and (B.Count = 1) and (B.Items[0].Kind = ckTelnet) and (B.Items[0].Port = 99));
  DeleteFile(FN); DeleteFile(FN + '.new'); RemoveDir(Dir + '/sub'); RemoveDir(Dir);
  WriteLn('failures: ', Fails);
  if Fails > 0 then Halt(1);
end.
