{ SPDX-License-Identifier: GPL-3.0-or-later }
program scripttest;
{$mode tp}
{$H+}
{ scripttest <host> <port> <script file | @profile> [name=value ...] [-z <work dir>] [-l <transcript>] [-r]:
  connects (Telnet; -r = raw) and runs the script of MKHubScr.  upload / download are stubs that print
  "UPLOAD <arg>" / "DOWNLOAD", or with -z the Zmodem of MKProt (the file <arg> is sent, files arrive in <work dir>).
  Prints "script ok" or "script failed: <text>" (tests/scripthubtest.py, tests/clientxfertest.py). }
uses MKString, MKComAbs, MKComClient, MKHubScr, MKProt, MKVideo, Dos;

var
  S: AbsComPtr; Err: ShortString; H: HubScriptObj; i, p: Integer; A, FName, Trans, Txt, Line: String;
  Raw: Boolean; F: Text; WorkDir: ShortString; UseZ: Boolean;

function Xfer(Upload: Boolean; Arg: ShortString): Boolean;
var P: ProtObj;
begin
  if not UseZ then
  begin
    if Upload then writeln('UPLOAD ', Arg) else writeln('DOWNLOAD');
    Xfer := True;
    exit;
  end;
  P.Init; P.SetZmodem;
  if Upload then
  begin
    P.AddSendFile(Arg);
    P.Send;
    Xfer := (P.PI^.Error = 0) and (P.GetFileStatus(1) = 1);
  end
  else
  begin
    P.SetRecvName('download.dat');
    Xfer := P.Recv(WorkDir) and (P.PI^.NumFiles > 0);
  end;
  P.Done;
end;

begin
  Raw := False; UseZ := False; Trans := ''; WorkDir := '.';
  S := ConnectTcp(ParamStr(1), Str2Long(ParamStr(2)), 5000, True, Err);
  if S = nil then begin writeln('error: ', Err); halt(1); end;
  ComSession := S; CurrentPort := 1; CurrentRate := 38400; ProtQuiet := True; ProtKeepInput := True;
  H.Init(S);
  FName := ParamStr(3);
  i := 4;
  while i <= ParamCount do
  begin
    A := ParamStr(i);
    if A = '-z' then begin UseZ := True; Inc(i); WorkDir := ParamStr(i); end
    else if A = '-t' then ProtTrace := True
    else if A = '-l' then begin Inc(i); Trans := ParamStr(i); end
    else begin
      p := Pos('=', A);
      if p > 0 then H.SetVar(Copy(A, 1, p - 1), Copy(A, p + 1, 200));
    end;
    Inc(i);
  end;
  if Trans <> '' then H.SetTranscript(Trans);
  H.SetXfer(Xfer);
  if FName[1] = '@' then Txt := HubProfile(Copy(FName, 2, 40))
  else begin
    Txt := '';
    Assign(F, FName); Reset(F);
    while not Eof(F) do begin ReadLn(F, Line); Txt := Txt + Line + #10; end;
    Close(F);
  end;
  if not H.Load(Txt) then begin writeln('script too long'); halt(1); end;
  if H.Run then writeln('script ok') else writeln('script failed: ', H.ErrText);
  writeln('carrier at the end: ', S^.GetCarrier);
  H.Done;
  S^.Hangup;
end.
