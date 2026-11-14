Program MKNodeList;

{$I MKB.Def}

{
     mknodelist 1:110/290

     Looks an address up in the nodelist (the index of the BBS: MK, RA, QUICK
     or SBBS names the config directory, as for mk) and shows the entry.
     An address without a zone, net or point is taken from the BBS's first
     address.
}

Uses
  MKNSrch, MKCfgAbs, MKGlobT, MKString, MKRCfgMK, MKRCfgRA, MKCfgQB, MKCfgSB, MKFile;

Var
  Nodes: NodeListObj;
  Addr: AddrType;
  DAddr: AddrType;
  TmpStr: String;

Begin
If ParamCount < 1 Then
  Begin
  WriteLn('Correct syntax is: MKNodeList Zone:Net/Node[.Point]');
  Halt(1);
  End;
Addr.Zone := 1;
Addr.Net := 1;
Addr.Node := 1;
Addr.Point := 0;
Config := Nil;
Case DetectBbsType Of
  1: Config := New(MKRCfgObjPtr, Init);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'Bad bbs type: set MK (or RA, QUICK, SBBS) to the BBS config directory');
  Halt(1);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, Long2Str(Config^.GetError) + ': Error loading config files');
  Halt(1);
  End;
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
Dispose(Config, Done);
If Length(GetNodeSection(TmpStr, 0)) > 0 Then
  WriteLn('Type   = ' + GetNodeSection(TmpStr, 0))
Else
  WriteLn('Type   = Node');
WriteLn('Number = ', GetNodeSection(TmpStr, 1));
WriteLn('System = ', GetNodeSection(TmpStr, 2));
WriteLn('City   = ', GetNodeSection(TmpStr, 3));
WriteLn('Sysop  = ', GetNodeSection(TmpStr, 4));
WriteLn('Phone  = ', GetNodeSection(TmpStr, 5));
WriteLn('Baud   = ', GetNodeSection(TmpStr, 6));
End.
