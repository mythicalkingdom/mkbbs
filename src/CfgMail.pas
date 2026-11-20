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
Procedure DoCfgRoutes;
Procedure DoCfgFreq;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgList, CfgBox, CfgSec2;


Var
  Mail: ^MailerCfgType;


Procedure DoCfgMailer;
  Var
    F: CfgFormObj;
    Enabled, Listen, Cram, Plz, Nr, Unknown, Tosser: Boolean;
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
  Tosser := (M^.Flags And mcTosser) <> 0;
  F.Init('Mailer');
  F.Window(3, 4, 76, 21);
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
  F.At(15, 3, 15, 24);
  F.AddYesNo('Tosser:', Tosser, 'Run mktoss: after mail arrives (when the command above is blank) and from mklisten''s scan');
  If F.Execute Then
    Begin
    M^.Flags := M^.Flags And Not (mcEnabled Or mcListen Or mcRequireCram Or mcPlz Or mcNr Or mcAcceptUnknown Or mcTosser);
    If Enabled Then M^.Flags := M^.Flags Or mcEnabled;
    If Listen Then M^.Flags := M^.Flags Or mcListen;
    If Cram Then M^.Flags := M^.Flags Or mcRequireCram;
    If Plz Then M^.Flags := M^.Flags Or mcPlz;
    If Nr Then M^.Flags := M^.Flags Or mcNr;
    If Unknown Then M^.Flags := M^.Flags Or mcAcceptUnknown;
    If Tosser Then M^.Flags := M^.Flags Or mcTosser;
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
  F.Window(3, 4, 76, 20);
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
  F.At(14, 3, 14, 23);
  F.AddNumber('File request level:', L^.ReqSec.Level, 2, 0, 65535,
    'Security of this system for file requests (File Requests page); 0 = the file request user.  F2 sets the flags');
  F.OnF2(EditSecurity, @L^.ReqSec, '[ File request access of this system ]');
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



Procedure DoCfgFreq;
  Var
    F: CfgFormObj;
    On, Unsecure, Netmail: Boolean;
    M: ^MailerCfgType;

  Begin
  If Not Config^.HasMailer Then
    Begin
    MsgBox('The mailer settings are kept by the MK configuration only');
    Exit;
    End;
  New(M);
  Config^.GetMailer(M^);
  On := (M^.Flags And mcFileReq) <> 0;
  Unsecure := (M^.ReqAttr And rqUnsecure) <> 0;
  Netmail := (M^.ReqAttr And rqAnswerMail) <> 0;
  F.Init('File Requests');
  F.Window(3, 4, 76, 17);
  F.At(2, 3, 2, 28);
  F.AddYesNo('Answer file requests:', On, 'Answer FTN file requests (mkbink runs mkfreq for each request file that arrives)');
  F.At(3, 3, 3, 28);
  F.AddYesNo('Without a password:', Unsecure, 'Also answer systems that called without a session password (never password protected names)');
  F.At(4, 3, 4, 28);
  F.AddYesNo('Tell by netmail:', Netmail, 'Send a netmail to the requester saying what was found and what was refused');
  F.At(6, 3, 6, 28);
  F.AddNumber('File request user:', M^.ReqSec.Level, 2, 0, 65535,
    'Security of a system that has none of its own (Mailer Links); level 0 and no flags = such systems get nothing.  F2 sets the flags');
  F.OnF2(EditSecurity, @M^.ReqSec, '[ File request user ]');
  F.At(8, 3, 8, 28);
  F.AddString('Magic names file:', M^.ReqMagicFile, 60, 'Text file with lines  NAME path [password]  (@LIST = a list of the files); blank = none');
  F.At(10, 3, 10, 28);
  F.AddNumber('Most files:', M^.ReqMaxFiles, 2, 0, 65535, 'Files sent for one request, 0 = 20');
  F.At(11, 3, 11, 28);
  F.AddNumber('Most KB:', M^.ReqMaxKb, 4, 0, 100000000, 'Kilobytes sent for one request, 0 = no limit');
  F.At(13, 3, 13, 76);
  F.AddText('Files come from file areas with "Allow file requests".');
  If F.Execute Then
    Begin
    M^.Flags := M^.Flags And Not mcFileReq;
    If On Then M^.Flags := M^.Flags Or mcFileReq;
    M^.ReqAttr := M^.ReqAttr And Not (rqUnsecure Or rqAnswerMail);
    If Unsecure Then M^.ReqAttr := M^.ReqAttr Or rqUnsecure;
    If Netmail Then M^.ReqAttr := M^.ReqAttr Or rqAnswerMail;
    Config^.SetMailer(M^);
    End;
  Dispose(M);
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


{------------------------------------------------------------ netmail routing}

Const
  FlavNames = 'As the message says|Immediate|Crash|Normal|Hold|Direct';

Function RouteStr(Item: Word): String;
  Var
    S: String;

  Begin
  With Mail^.Routes[Item] Do
    Begin
    If Via = 0 Then
      S := '(unused)'
    Else
      Begin
      S := PadRight(Pat, ' ', 42) + 'via ' + Long2Str(Via);
      If Flav <> rfDefault Then
        Case Flav Of
          rfImmediate: S := S + ' immediate';
          rfCrash: S := S + ' crash';
          rfNormal: S := S + ' normal';
          rfHold: S := S + ' hold';
          rfDirect: S := S + ' direct';
          End;
      End;
    End;
  RouteStr := PadRight(Long2Str(Item), ' ', 3) + S;
  End;


Procedure EditRoute(Item: Word);
  Var
    F: CfgFormObj;
    R: ^RouteType;

  Begin
  New(R);
  R^ := Mail^.Routes[Item];
  F.Init('Route ' + Long2Str(Item));
  F.Window(5, 6, 74, 15);
  F.At(2, 3, 2, 14);
  F.AddString('Addresses:', R^.Pat, 40, 'Zone:net/node.point with * for anything, blank separated, ! in front = not (2:*/* 1:110/*)');
  F.At(4, 3, 4, 14);
  F.AddNumber('Send via:', R^.Via, 1, 0, 32, 'Number of the echo system (EchoMail > Systems) that gets the mail; 0 = this route is not used');
  F.At(6, 3, 6, 14);
  F.AddChoice('Flavour:', R^.Flav, 1, 0, FlavNames, 'How it is sent (Space or arrows change it)');
  If F.Execute Then
    Mail^.Routes[Item] := R^;
  Dispose(R);
  End;


Procedure DoCfgRoutes;
  Begin
  If Not Config^.HasMailer Then
    Begin
    MsgBox('The routing is kept by the MK configuration only');
    Exit;
    End;
  New(Mail);
  Config^.GetMailer(Mail^);
  RunList('Netmail Routing',
    MaxRoutes, 64, RouteStr, EditRoute);
  Config^.SetMailer(Mail^);
  Dispose(Mail);
  Mail := Nil;
  End;


End.
