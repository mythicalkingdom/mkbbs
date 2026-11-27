{ SPDX-License-Identifier: GPL-3.0-or-later }
program clientxfer;
{$mode tp}
{$H+}
{ clientxfer <host> <port> <user> <password> <work dir>: logs in to "mk -Q" (Login:, Password:, QWK:) with MKComClient, downloads the
  packet with the Zmodem of MKProt through the Telnet client session, uploads a reply packet with it (the file <work dir>/up.rep)
  and quits (tests/clientxfertest.py). }
uses BaseUnix, MKString, MKComAbs, MKComClient, MKProt, MKVideo, MKFile, Dos;

var S: AbsComPtr; Err: ShortString; P: ProtObj; Ok: Boolean;

function WaitFor(Want: String; Ms: LongInt): Boolean;
var Buf: String; T: LongInt; Ch: Char;
begin
  Buf := ''; T := 0;
  while (Pos(Want, Buf) = 0) and (T < Ms) do
  begin
    if S^.WaitForChar(100) then
    begin
      Ch := S^.GetChar;
      Buf := Buf + Ch;
      if Length(Buf) > 200 then Delete(Buf, 1, 100);
    end
    else Inc(T, 100);
  end;
  WaitFor := Pos(Want, Buf) > 0;
end;

procedure Say(T: String);
var i: Integer;
begin
  for i := 1 to Length(T) do S^.SendChar(T[i]);
  S^.FlushOut;
end;

begin
  S := ConnectTcp(ParamStr(1), Str2Long(ParamStr(2)), 5000, True, Err);
  if S = nil then begin writeln('error: ', Err); halt(1); end;
  ComSession := S;
  CurrentPort := 1; CurrentRate := 38400;
  ProtQuiet := True; ProtKeepInput := True;
  if not WaitFor('Login: ', 15000) then begin writeln('no login prompt'); halt(2); end;
  Say(ParamStr(3) + #13);
  if not WaitFor('Password: ', 5000) then begin writeln('no password prompt'); halt(2); end;
  Say(ParamStr(4) + #13);
  if not WaitFor('QWK: ', 5000) then begin writeln('no QWK prompt'); halt(2); end;
  writeln('logged in');
  { download }
  Say('D');
  P.Init; P.SetZmodem; P.SetRecvName('download.dat');
  Ok := P.Recv(ParamStr(5)) and (P.PI^.NumFiles > 0);
  P.Done;
  if Ok then writeln('download ok') else writeln('download failed');
  if not WaitFor('QWK: ', 8000) then begin writeln('no QWK prompt after the download'); halt(3); end;
  { upload }
  Say('U');
  if not WaitFor('Begin transfer now', 5000) then begin writeln('no upload start'); halt(4); end;
  P.Init; P.SetZmodem; P.AddSendFile(ParamStr(5) + '/up.rep');
  P.Send;
  Ok := (P.PI^.Error = 0) and (P.GetFileStatus(1) = 1);
  P.Done;
  if Ok then writeln('upload ok') else writeln('upload failed');
  if not WaitFor('QWK: ', 15000) then begin writeln('no QWK prompt after the upload'); halt(5); end;
  Say('Q');
  S^.Hangup;
  writeln('done');
end.
