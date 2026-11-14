Unit MKMenuO;

Interface

Implementation

Uses Overlay;


Begin
OvrFileMode := 64;
OvrInit('MKMENU.OVR');
If OvrResult <> 0 Then
  Begin
  WriteLn(OvrResult, ' Error loading MKMENU.OVR');
  Halt(1);
  End;
OvrSetBuf(64000);
OvrInitEMS;
If ((OvrResult < 0) and (OvrResult > -5)) Then
  Begin
  WriteLn(OvrResult, ' Error loading MKMENU.OVR' );
  Halt(1);
  End;
End.
