{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKNodeHost;   {The internet address of a node from the nodelist index (mknodeidx), for mkbinkcfg and the mailer screen of mkmon}

{$I MKB.Def}

Interface

Uses
  MKGlobT;

Function NodelistHost(Var A: AddrType; Var Host: String; Var Port: Word; Var Why: String): Boolean;
  {The flags IBN (binkp), IBN:port, IBN:host, IBN:host:port and INA:host of the node's line; the port is 0 when
   the line has none.  The index is the one of the BBS (Config); all the nodelists it covers are searched (the zone
   number picks the list, so networks with their own zones, such as fsxnet, work next to Fidonet's).}


Implementation

Uses
  MKString, MKCfgAbs, MKNSrch, MKNet;

Var
  Nodes: NodeListObj;
  NodesTried, NodesOk: Boolean;


Function NodelistHost(Var A: AddrType; Var Host: String; Var Port: Word; Var Why: String): Boolean;
  {The internet address of a node from its nodelist line: the flags IBN (binkp), IBN:port, IBN:host, IBN:host:port
   and INA:host.  False when the nodelist has no index, no such node or no host name for it; Why says which.}
  Var
    Line, Flag, Up, P1, P2, INA: String;
    SplitHost: AnsiString;
    SplitPort: LongInt;
    k, p: Word;
    HasIbn, Good: Boolean;
    V: LongInt;

  Begin
  NodelistHost := False;
  Host := '';
  Port := 0;
  Why := '';
  If A.Point <> 0 Then
    Begin
    Why := 'a point is not looked up';
    Exit;
    End;
  If Not NodesTried Then
    Begin
    NodesTried := True;
    Nodes.Init;
    Nodes.Load;
    NodesOk := Nodes.GetError = 0;
    End;
  If Not NodesOk Then
    Begin
    Why := 'no nodelist index (' + Config^.GetNodeListPath + Config^.GetNodeIdxName + '; mknodeidx builds it)';
    Exit;
    End;
  Line := Nodes.NodeStr(A);
  If Pos('Address Not Found', Line) > 0 Then
    Begin
    Why := 'not in the nodelist';
    Exit;
    End;
  HasIbn := False;
  INA := '';
  k := 7;
  Repeat
    Flag := GetNodeSection(Line, k);
    Inc(k);
    If Flag = '' Then
      Continue;
    Up := Upper(Flag);
    p := Pos(':', Up);
    If p = 0 Then
      Begin
      If Up = 'IBN' Then
        HasIbn := True;
      Continue;
      End;
    P1 := Copy(Up, 1, p - 1);
    P2 := Copy(Flag, p + 1, 255);                  {what follows the first colon: port, host, host:port, [v6], [v6]:port, a bare IPv6 address}
    If P1 = 'INA' Then
      Begin
      If NetSplitHostPort(P2, SplitHost, SplitPort) Then
        INA := SplitHost;
      End
    Else If P1 = 'IBN' Then
      Begin
      HasIbn := True;
      Val(P2, V, p);
      If (p = 0) And (V > 0) And (V < 65536) Then
        Port := V
      Else If NetSplitHostPort(P2, SplitHost, SplitPort) Then
        Begin
        Host := SplitHost;
        If (SplitPort > 0) And (SplitPort < 65536) Then
          Port := SplitPort;
        End;
      End;
  Until (Flag = '') Or (k > 60);
  If Host = '' Then
    Host := INA;
  Good := HasIbn And (Host <> '') And (Pos(' ', Host) = 0) And (Pos('#', Host) = 0);
  NodelistHost := Good;
  If Not HasIbn Then
    Why := 'the nodelist has no IBN flag for it'
  Else If Not Good Then
    Why := 'the nodelist has no host name for it';
  End;

Begin
NodesTried := False;
NodesOk := False;
End.
