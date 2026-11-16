program tosssetup;
{$mode tp}
{ tosssetup <inbound> <outbound> <unsecure>: (system 2 = 1:110/200 is added for the forwarding tests) the sample configuration (MK=...) made ready for tests/tosstest.py:
  echo paths, system 1 linked to areas 6 (MK), 9 (MKBETA, pass-through) and 10 (BBS), unzip as the zip unpacker }
uses MKString, MKGlobT, MKCfgAbs, MKCfgMK;
var M: ^MailerCfgType; A: AddrType;
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
  Config^.SetMailer(M^); Dispose(M);
  Config^.Save;
end.
