Program HubExecTest;
{$MODE TP}
Uses SysUtils, MKHubExec;
Var Fails: Integer;
Procedure Check(Name: String; Ok: Boolean);
  Begin
  If Ok Then WriteLn('ok   hub exec: ', Name) Else Begin WriteLn('FAIL hub exec: ', Name); Inc(Fails); End;
  End;
Var Out: AnsiString; R: LongInt; W: Array[0..9] Of String; N: Word;
Begin
Fails := 0;
N := HubExecWords('a "b c" "d\"e" f\g', W, 10);
Check('words: quotes and escapes', (N = 4) And (W[0] = 'a') And (W[1] = 'b c') And (W[2] = 'd"e') And (W[3] = 'f\g'));
HubExecVar('id', 'MYHUB');
HubExecVar('qwk', '/tmp/a b/x.qwk');
HubExecEnv('MK_HUB_PASSWORD', 'secret');
R := HubExecRun('/bin/echo %id% %qwk% 100%% ;ls', '', 10, Out);
Check('no shell, variables replaced, %% is a percent sign', (R = 0) And (Out = 'MYHUB /tmp/a b/x.qwk 100% ;ls' + #10));
R := HubExecRun('/bin/sh -c "echo $MK_HUB_PASSWORD; exit 3"', '', 10, Out);
Check('environment variable, exit status', (R = 3) And (Out = 'secret' + #10));
R := HubExecRun('sh -c "echo err 1>&2"', '', 10, Out);
Check('bare name found in PATH; stderr is captured', (R = 0) And (Out = 'err' + #10));
R := HubExecRun('/bin/sh -c "sleep 30"', '', 1, Out);
Check('a program that hangs is killed', R = -2);
R := HubExecRun('/nonexistent/prog', '', 5, Out);
Check('a program that is not there', (R = -1) And (Pos('no such file', Out) > 0));
R := HubExecRun('/bin/sh -c "sleep 30 & echo $!; exit 0"', '', 5, Out);
Check('a program that leaves a child: does not hang the call forever', (R = 0) Or (R = -2));
WriteLn('failures: ', Fails);
If Fails > 0 Then Halt(1);
End.
