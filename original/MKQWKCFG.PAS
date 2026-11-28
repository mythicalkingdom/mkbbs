Program MKQwkCfg;
{$M 32768, 200000, 655360}

Uses Overlay, MKQMenu, MKQCfgG, MKQwkG;

{$O MKRCfgMK}
{$O MKRCfgRA}
{$O MKRCfgR2}
{$O MKCfgQB}
{$O MKCfgSB}
{$O MKRCfgEz}

Begin
WriteLn('MKQwkCfg - Offline Mail Door Configuration');
WriteLn('Please wait - loading BBS and config information');
OvrFileMode := 64;
OvrInit('MKQWKCFG.OVR');
If OvrResult <> 0 Then
  Begin
  WriteLn(OvrResult, ' Error loading MKQWKCFG.OVR');
  Halt(1);
  End;
OvrSetBuf(32000);
OvrInitEMS;
If ((OvrResult < 0) and (OvrResult > -5)) Then
  Begin
  WriteLn(OvrResult, ' Error loading MKQWKCFG.OVR' );
  Halt(1);
  End;
LoadBbsCfg;
SetDefaults;
CfgInit;
LoadQwkCfg;
DoBanner;
MainMenu;
If Not SaveQwkCfg Then
  WriteLn('Error saving changes');
CfgDone;
End.
