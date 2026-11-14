Program NodeList;

Uses MKScrn, MKNSrch, OpCrt, MKCfgAbs, MKGlobT, MKString,
  MKCfgRa, MKCfgQb, MKCfgSB, MKCfgMK, MKFile, MKEnter;

Var
  Nodes: NodeListObj;
  Addr: AddrType;
  DAddr: AddrType;
  TmpStr: String;

Begin
Addr.Zone := 1;
Addr.Net := 1;
Addr.Node := 1;
Addr.Point := 0;
Case DetectBbsType of
  1: Config := New(MKCfgObjPtr, Init);
  2: Config := New(RACfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  Else
    Begin
    WriteLn('Bad bbs type');
    Halt(1);
    End;
  End;
Config^.Load;
Config^.GetAddr(1, DAddr);
If Not ParseAddr(ParamStr(1), DAddr, Addr) Then
  Begin
  WriteLn('Unable to parse address');
  Halt(10);
  End;
Nodes.Init;
Nodes.Load;
TmpStr := Nodes.NodeStr(Addr);
Nodes.Done;
Config^.Done;
If Length(GetNodeSection(TmpStr,0)) > 0 Then
  WriteLn('Type   = ' + GetNodeSection(TmpStr,0))
Else
  WriteLn('Type   = Node');
WriteLn('Number = ', GetNodeSection(TmpStr, 1));
WriteLn('System = ', GetNodeSection(TmpStr, 2));
WriteLn('City   = ', GetNodeSection(TmpStr, 3));
WriteLn('Sysop  = ', GetNodeSection(TmpStr, 4));
WriteLN('Phone  = ', GetNodeSection(TmpStr, 5));
WriteLn('Baud   = ', GetNodeSection(TmpStr, 6));
End.
