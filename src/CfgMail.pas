Unit CfgMail;   {Mailer (mkbink) settings and links}

{$I MKB.Def}

{
     The settings are kept in Mailer.Mk (see MailerCfgType in MKGlobT).  The system's address, name, sysop and
     location are those of the BBS (General), the inbound and BSO outbound directories are the EchoMail
     Options.  mkbinkcfg turns all of it into the settings file the mailer reads.
}

Interface

Procedure DoCfgMailer;
Procedure DoCfgMailLinks;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgList, CfgBox;


Var
  Mail: ^MailerCfgType;


Procedure DoCfgMailer;
  Var
    F: CfgFormObj;
    Enabled, Listen, Cram, Plz, Nr, Unknown: Boolean;
    M: ^MailerCfgType;

  Begin
  If Not Config^.HasMailer Then
    Begin
    MsgBox('The mailer settings are kept by the MK configuration only');
    Exit;
    End;
  New(M);
  Config^.GetMailer(M^);
  Enabled := (M^.Flags And mcEnabled) <> 0;
  Listen := (M^.Flags And mcListen) <> 0;
  Cram := (M^.Flags And mcRequireCram) <> 0;
  Plz := (M^.Flags And mcPlz) <> 0;
  Nr := (M^.Flags And mcNr) <> 0;
  Unknown := (M^.Flags And mcAcceptUnknown) <> 0;
  F.Init('Mailer');
  F.Window(3, 4, 76, 19);
  F.At(2, 3, 2, 24);
  F.AddYesNo('Mailer enabled:', Enabled, 'Start the mailer (mkbink) with mklisten');
  F.At(2, 40, 2, 56);
  F.AddYesNo('Accept calls:', Listen, 'Answer calls from other systems');
  F.At(3, 3, 3, 24);
  F.AddNumber('Listen port:', M^.Port, 2, 1, 65535, 'TCP port for incoming calls (binkp is 24554)');
  F.At(3, 40, 3, 56);
  F.AddNumber('Max callers:', M^.MaxSessions, 1, 1, 100, 'Callers served at the same time');
  F.At(4, 3, 4, 24);
  F.AddString('Listen address:', M^.Bind, 40, 'Address to listen on, blank = all (127.0.0.1 = this machine only)');
  F.At(5, 3, 5, 24);
  F.AddNumber('Calls at once:', M^.MaxPolls, 1, 1, 100, 'Calls to other systems made at the same time');
  F.At(5, 40, 5, 56);
  F.AddNumber('Timeout (s):', M^.Timeout, 2, 5, 65535, 'Seconds without activity before a session is ended');
  F.At(6, 3, 6, 24);
  F.AddNumber('Retry after (s):', M^.RetryMin, 2, 1, 65535, 'Seconds before a failed call is tried again');
  F.At(6, 40, 6, 56);
  F.AddNumber('Longest (s):', M^.RetryMax, 2, 1, 65535, 'The wait doubles after each failure, up to this');
  F.At(7, 3, 7, 24);
  F.AddNumber('Look at mail (s):', M^.ScanInterval, 2, 1, 65535, 'Seconds between looks at the outbound for mail to send');
  F.At(7, 40, 7, 56);
  F.AddString('Domain:', M^.Domain, 20, 'Network domain added to our addresses, e.g. fidonet (blank = none)');
  F.At(9, 3, 9, 24);
  F.AddYesNo('Require CRAM:', Cram, 'Refuse cleartext passwords');
  F.At(9, 40, 9, 56);
  F.AddYesNo('Offer PLZ:', Plz, 'Offer compressed data (FTS-1029)');
  F.At(10, 3, 10, 24);
  F.AddYesNo('Ask NR mode:', Nr, 'Ask for non-reliable mode (FTS-1028), only for links that keep dropping');
  F.At(10, 40, 10, 56);
  F.AddYesNo('Accept unknown:', Unknown, 'Let a system that is not in the links list call us');
  F.At(11, 3, 11, 24);
  F.AddString('Its password:', M^.UnknownPwd, 30, 'Password for those systems');
  F.At(12, 3, 12, 24);
  F.AddString('No-password in:', M^.UnsecureIn, 60, 'Inbound directory for callers without a password, blank = the normal inbound');
  F.At(13, 3, 13, 24);
  F.AddString('After mail comes:', M^.OnInbound, 100, 'Command run with the received files as arguments (a tosser), blank = none');
  F.At(14, 3, 14, 24);
  F.AddNumber('Command limit (s):', M^.HookTimeout, 2, 0, 65535, 'Seconds before that command is stopped, 0 = 300');
  If F.Execute Then
    Begin
    M^.Flags := M^.Flags And Not (mcEnabled Or mcListen Or mcRequireCram Or mcPlz Or mcNr Or mcAcceptUnknown);
    If Enabled Then M^.Flags := M^.Flags Or mcEnabled;
    If Listen Then M^.Flags := M^.Flags Or mcListen;
    If Cram Then M^.Flags := M^.Flags Or mcRequireCram;
    If Plz Then M^.Flags := M^.Flags Or mcPlz;
    If Nr Then M^.Flags := M^.Flags Or mcNr;
    If Unknown Then M^.Flags := M^.Flags Or mcAcceptUnknown;
    If M^.RetryMax < M^.RetryMin Then
      M^.RetryMax := M^.RetryMin;
    Config^.SetMailer(M^);
    End;
  Dispose(M);
  End;


{------------------------------------------------------------ the links}

Function LinkStr(Item: Word): String;
  Var
    S: String;

  Begin
  With Mail^.Links[Item] Do
    Begin
    If Addr.Zone = 0 Then
      S := '(unused)'
    Else
      Begin
      S := PadRight(AddrStr(Addr), ' ', 18) + PadRight(Name, ' ', 20);
      If (Flags And mlAnswerOnly) <> 0 Then
        S := S + 'answers only'
      Else If Host <> '' Then
        S := S + Host;
      If (Flags And mlDisabled) <> 0 Then
        S := S + '  [off]';
      End;
    End;
  LinkStr := PadRight(Long2Str(Item), ' ', 3) + S;
  End;


Procedure EditLink(Item: Word);
  Var
    F: CfgFormObj;
    L: ^MailLinkType;
    AnswerOnly, Off: Boolean;
    PlzC, NrC: Byte;

  Begin
  New(L);
  L^ := Mail^.Links[Item];
  AnswerOnly := (L^.Flags And mlAnswerOnly) <> 0;
  Off := (L^.Flags And mlDisabled) <> 0;
  PlzC := 0;
  If (L^.Flags And mlPlzOff) <> 0 Then PlzC := 1;
  If (L^.Flags And mlPlzOn) <> 0 Then PlzC := 2;
  NrC := 0;
  If (L^.Flags And mlNrOff) <> 0 Then NrC := 1;
  If (L^.Flags And mlNrOn) <> 0 Then NrC := 2;
  If L^.Port = 0 Then
    L^.Port := 24554;
  F.Init('Link ' + Long2Str(Item));
  F.Window(3, 4, 76, 18);
  F.At(2, 3, 2, 9);
  F.AddNumber('Zone:', L^.Addr.Zone, 2, 0, 65535, 'Zone of the link (0 = this entry is not used)');
  F.At(2, 16, 2, 21);
  F.AddNumber('Net:', L^.Addr.Net, 2, 0, 65535, 'Net of the link');
  F.At(2, 28, 2, 34);
  F.AddNumber('Node:', L^.Addr.Node, 2, 0, 65535, 'Node of the link');
  F.At(2, 41, 2, 48);
  F.AddNumber('Point:', L^.Addr.Point, 2, 0, 65535, 'Point of the link');
  F.At(4, 3, 4, 9);
  F.AddString('Name:', L^.Name, 30, 'Name of the system, for the displays');
  F.At(5, 3, 5, 9);
  F.AddString('Host:', L^.Host, 60, 'Host name or IP address to call, blank = the nodelist (IBN / INA flags) says, else we cannot call it');
  F.At(6, 3, 6, 9);
  F.AddNumber('Port:', L^.Port, 2, 1, 65535, 'Port to call (binkp is 24554)');
  F.At(6, 20, 6, 38);
  F.AddNumber('Call every (min):', L^.PollMin, 2, 0, 65535, 'Call this often even with no mail waiting; 0 = only when mail is waiting');
  F.At(6, 47, 6, 61);
  F.AddNumber('Our address:', L^.UseAka, 1, 0, 10, 'Which of our addresses (1-10) to present first; 0 = the main one');
  F.At(8, 3, 8, 13);
  F.AddString('Password:', L^.Password, 30, 'Session password, blank = none');
  F.At(10, 3, 10, 19);
  F.AddYesNo('Answer only:', AnswerOnly, 'Never call this system, only answer its calls');
  F.At(10, 40, 10, 54);
  F.AddYesNo('Disabled:', Off, 'Keep the entry but do not use it');
  F.At(12, 3, 12, 19);
  F.AddChoice('PLZ:', PlzC, 1, 0, 'Default|Off|On', 'Compression with this link (Space or arrows change it)');
  F.At(12, 40, 12, 54);
  F.AddChoice('NR mode:', NrC, 1, 0, 'Default|Off|On', 'Non-reliable mode with this link (Space or arrows change it)');
  If F.Execute Then
    Begin
    L^.Flags := 0;
    If AnswerOnly Then L^.Flags := L^.Flags Or mlAnswerOnly;
    If Off Then L^.Flags := L^.Flags Or mlDisabled;
    If PlzC = 1 Then L^.Flags := L^.Flags Or mlPlzOff;
    If PlzC = 2 Then L^.Flags := L^.Flags Or mlPlzOn;
    If NrC = 1 Then L^.Flags := L^.Flags Or mlNrOff;
    If NrC = 2 Then L^.Flags := L^.Flags Or mlNrOn;
    If L^.Port = 24554 Then
      L^.Port := 0;
    Mail^.Links[Item] := L^;
    End;
  Dispose(L);
  End;


Procedure DoCfgMailLinks;
  Begin
  If Not Config^.HasMailer Then
    Begin
    MsgBox('The mailer settings are kept by the MK configuration only');
    Exit;
    End;
  New(Mail);
  Config^.GetMailer(Mail^);
  RunList('Mailer Links', MaxMailLinks, 64, LinkStr, EditLink);
  Config^.SetMailer(Mail^);
  Dispose(Mail);
  Mail := Nil;
  End;


End.
