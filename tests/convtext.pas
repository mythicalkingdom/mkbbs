Program ConvText;   {helper of msgconvtest: convtext <area id> <number> : the text of a message as hex}
{$mode objfpc}{$H+}
Uses SysUtils, MKGlobT, MKMsgAbs, MKMsgHud, MKMsgJam, MKMsgSqu, MKMsgFid, MKMsgMer, MKMsgSyn, MKOpen;
Var
  M: AbsMsgPtr;
  S: String;
Begin
If Not OpenMsgArea(M, ParamStr(1)) Then Halt(2);
M^.SeekFirst(StrToInt(ParamStr(2)));
If M^.SeekFound Then
  Begin
  M^.MsgStartUp;
  M^.MsgTxtStartUp;
  S := '';
  While Not M^.EOM Do
    S := S + IntToHex(Ord(M^.GetChar), 2) + ' ';
  WriteLn(S);
  End;
End.
