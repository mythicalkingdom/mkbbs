program tosssetup;
{$mode tp}
{ tosssetup <inbound> <outbound> <unsecure> [<mailer port>]: (with a port the mailer is switched on with one link, the hub) (system 2 = 1:110/200 is added for the forwarding tests) the sample configuration (MK=...) made ready for tests/tosstest.py:
  echo paths, system 1 linked to areas 6 (MK), 9 (MKBETA, pass-through) and 10 (BBS), unzip as the zip unpacker }
uses MKString, MKGlobT, MKCfgAbs, MKCfgMK;
var M: ^MailerCfgType; A: AddrType; Code: Integer;
begin
  Config := New(MKCfgObjPtr, Init); Config^.Load;
  Config^.SetEchoInPath(ParamStr(1));
  Config^.SetEchoOutPath(ParamStr(2));
  Config^.SetEchoToArea(1, 6, True);
  Config^.SetEchoToArea(1, 9, True);
  Config^.SetEchoToArea(1, 10, True);
  Config^.SetEchoAreaPassThru(9, True);
  Config^.SetEchoAreaImportSeen(6, True);
  Config^.SetEchoAreaImportPath(6, True);
  Config^.SetEchoAreaHideSeen(6, True);
  Config^.SetEchoAreaHidePath(6, True);
  Config^.SetUnPackCmdLine(2, 'unzip -o -q');
  Config^.SetPackCmdLine(2, 'zip -q -j');
  { system 2: 1:110/200, packets sent as they are, normal flavour, linked to areas 6 and 9 }
  A.Zone := 1; A.Net := 110; A.Node := 200; A.Point := 0;
  Config^.SetEchoToAddr(2, A);
  Config^.SetEchoToPacker(2, 0);
  Config^.SetEchoToMailType(2, 2);
  Config^.SetEchoToPwd(2, 'pw2');
  Config^.SetEchoToArea(2, 6, True);
  Config^.SetEchoToArea(2, 9, True);
  Config^.SetEchoToHub(9, 1);          { area 9: the hub is system 1 (a pass-through area, system 2 takes it from us) }
  Config^.SetEchoLog('');
  New(M); Config^.GetMailer(M^);
  M^.UnsecureIn := ParamStr(3);
  M^.PktPwd[2] := 'pktpw2';
  M^.Flags := M^.Flags Or mcTosser;       { the tosser is switched on }
  if ParamCount >= 4 then begin
    { the mailer on, listening on the port, one link: the hub 1:110/100 that calls us with the password hubpw }
    Val(ParamStr(4), M^.Port, Code);
    M^.Flags := M^.Flags Or mcEnabled Or mcListen;
    M^.Links[1].Addr.Zone := 1; M^.Links[1].Addr.Net := 110; M^.Links[1].Addr.Node := 100; M^.Links[1].Addr.Point := 0;
    M^.Links[1].Name := 'Hub'; M^.Links[1].Password := 'hubpw'; M^.Links[1].Flags := mlAnswerOnly;
  end;
  Config^.SetMailer(M^); Dispose(M);
  Config^.Save;
end.
