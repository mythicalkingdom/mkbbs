program clienttest;
{$mode tp}
{$H+}
{ clienttest <host> <port> [raw]: connects with MKComClient, prints what the server sends as "got <hex>" (about 1.5 s), then sends
  "ping" CR and the byte 255 and hangs up (tests/clienttest.py).  "clienttest <host> <port> fail" only reports the error. }
uses MKString, MKComAbs, MKComClient, Dos;

var S: AbsComPtr; Err: ShortString; i: Integer; Ch: Char; Hex: String; T: LongInt;
const H = '0123456789abcdef';
begin
  S := ConnectTcp(ParamStr(1), Str2Long(ParamStr(2)), 3000, ParamStr(3) <> 'raw', Err);
  if S = nil then begin writeln('error: ', Err); halt(1); end;
  writeln('connected');
  Hex := '';
  for i := 1 to 15 do
    while S^.WaitForChar(100) do
    begin
      Ch := S^.GetChar;
      Hex := Hex + H[Ord(Ch) shr 4 + 1] + H[Ord(Ch) and 15 + 1];
    end;
  writeln('got ', Hex);
  S^.SendChar('p'); S^.SendChar('i'); S^.SendChar('n'); S^.SendChar('g'); S^.SendChar(#13); S^.SendChar(#255);
  S^.FlushOut;
  S^.Hangup;
  writeln('done');
end.
