{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit QuoteCvt;
{$I MKB.Def}

Interface

Uses MKString, MKMsgAbs;

Function CvtQuoteStr(QStr:String; Var MsgOut: AbsMsgPtr): String;


Implementation


Function CvtQuoteStr(QStr:String; Var MsgOut: AbsMsgPtr): String;
  Var
    i: Word;
    v: Word;
    TStr: String;
    TStr2: String;
    CvtState: Word; {0=normal, 1=have percent}

  Begin
  i := 1;
  CvtState := 0;
  TStr := '';
  While i <= Length(QStr) Do
    Begin
    If CvtState = 0 Then
      Begin
      If QStr[i] = '%' Then
        Begin
        CvtState := 1;
        End
      Else
        Begin
        TStr[0] := Chr(Length(TStr) + 1);
        TStr[Length(TStr)] := QStr[i];
        End;
      End
    Else
      Begin
      Case QStr[i] of
        '%': Begin
             TStr := TStr + '%';
             End;
        'F','f': Begin
             CvtState := 0;
             TStr := TStr + MsgOut^.GetFrom;
             End;
        'T','t': Begin
             CvtState := 0;
             TStr := TStr + MsgOut^.GetTo;
             End;
        'S','s':
             Begin
             CvtState := 0;
             TStr := TStr + MsgOut^.GetSubj;
             End;
        'D','d':
             Begin
             CvtState := 0;
             TStr := TStr + MsgOut^.GetDate;
             End;
        'W','w':
             Begin
             CvtState := 0;
             TStr := TStr + Copy(MsgOut^.GetTime,1,5);
             End;
        Else
             Begin
             TStr := TStr + '%' + QStr[i];
             CvtState := 0;
             End;
        End;
      End;
    Inc(i);
    End;
  If CvtState = 1 Then
    Begin
    TStr[0] := Chr(Length(TStr) + 1);
    TStr[Length(TStr)] := '%';
    End;
  i := 1;
  TStr2 := '';
  While i <= Length(TStr) Do
    Begin
    If TStr[i] = '|' Then
      TStr2 := TStr2 + #13 + #10
    Else
      TStr2 := TStr2 + TStr[i];
    Inc(i);
    End;
  CvtQuoteStr := TStr2;
  End;

End.
