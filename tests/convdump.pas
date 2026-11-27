{ SPDX-License-Identifier: GPL-3.0-or-later }
Program ConvDump;   {helper of msgconvtest: convdump <area id> : one line for each message that is not deleted: number, header fields, flags, links, a check sum of the text}
{$mode objfpc}{$H+}
Uses SysUtils, MKGlobT, MKMsgAbs, MKMsgHud, MKMsgJam, MKMsgSqu, MKMsgFid, MKMsgMer, MKMsgSyn, MKOpen;
Var
  M: AbsMsgPtr;
  T: AnsiString;
  O, D: AddrType;
  Sum: LongInt;
  i: Integer;
  C: Char;
  R: AnsiString;
  Skip: Boolean;
Begin
If Not OpenMsgArea(M, ParamStr(1)) Then
  Begin
  WriteLn('cannot open');
  Halt(2);
  End;
M^.SeekFirst(1);
While M^.SeekFound Do
  Begin
  M^.MsgStartUp;
  If Not M^.IsDeleted Then
    Begin
    M^.GetOrig(O);
    M^.GetDest(D);
    T := '';
    M^.MsgTxtStartUp;
    While Not M^.EOM Do
      Begin
      C := M^.GetChar;
      If Not (C In [#0, #10, #$8D]) Then
        T := T + C;
      End;
    If GetEnvironmentVariable('CONVDUMP_NOKLUDGE') <> '' Then        {a kind that keeps no kludge lines: compare without them}
      Begin
      R := '';
      Skip := False;
      For i := 1 To Length(T) Do
        Begin
        If (i = 1) Or (T[i - 1] = #13) Then
          Skip := T[i] = #1;
        If Not Skip Then
          R := R + T[i]
        Else If T[i] = #13 Then
          Skip := False;
        End;
      T := R;
      End;
    If T = '' Then
      T := #13;
    While (Length(T) > 1) And (T[Length(T)] = #13) Do        {a kind that does not keep blank lines at the end makes no difference}
      SetLength(T, Length(T) - 1);
    Sum := 0;
    For i := 1 To Length(T) Do
      Sum := (Sum * 31 + Ord(T[i])) And $FFFFFF;
    WriteLn(M^.GetMsgNum, '|', M^.GetFrom, '|', M^.GetTo, '|', M^.GetSubj, '|', M^.GetDate, '|', Copy(M^.GetTime, 1, 5), '|', O.Zone, ':', O.Net, '/', O.Node, '.', O.Point, '|',
      D.Zone, ':', D.Net, '/', D.Node, '.', D.Point, '|', Ord(M^.IsPriv), Ord(M^.IsRcvd), Ord(M^.IsLocal), Ord(M^.IsSent), '|', M^.GetRefer, '|', M^.GetSeeAlso, '|', Length(T), '|', Sum);
    End;
  M^.SeekNext;
  End;
M^.CloseMsgBase;
Dispose(M, Done);
End.
