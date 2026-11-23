Program HubReplayUnit;
{$MODE TP}
Uses MKHubReplay;
Var Fails: Integer; P: Boolean;
Procedure Check(N: String; Ok: Boolean);
  Begin
  If Ok Then WriteLn('ok   hub replay: ', N) Else Begin WriteLn('FAIL hub replay: ', N); Inc(Fails); End;
  End;
Begin
Check('exact', ReplayMatch('lion'#13, 'lion'#13, P));
Check('partial', (Not ReplayMatch('lion'#13, 'li', P)) And P);
Check('different', (Not ReplayMatch('lion'#13, 'x', P)) And (Not P));
Check('stars match the password', ReplayMatch('********'#13, 'sEcr3t'#13, P));
Check('stars with a start', ReplayMatch('pw ********'#13, 'pw abc'#13, P));
Check('stars: wrong start', (Not ReplayMatch('pw ********'#13, 'xx abc'#13, P)) And (Not P));
Check('stars: not ended yet', (Not ReplayMatch('********'#13, 'abc', P)) And P);
WriteLn('failures: ', Fails);
If Fails > 0 Then Halt(1);
End.
