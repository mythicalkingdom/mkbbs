Unit MKQwkImp;       {the messages of a QWK message file go into message areas}

{$I MKB.Def}

{
     MKQwkImp - the import side of QWK mail, for the reply packet of a caller (REP) and, later, for the
     packet of a QWK network host.  The file is read with MKMsgQwk (MESSAGES.DAT / <BBSID>.MSG); what
     is BBS specific is told by two procedures of the caller:

       Map(Conf, T, Moved)   where does conference Conf go: fill in T (area id, kind of area, forced
                             From name ...) and return True, or return False to refuse the whole
                             conference.  Moved says the conference was not found and T is the
                             place for such messages.
       Note(Code, Conf, M)   something happened (qi... codes); for qiPosted M is the message that was
                             written (GetMsgNum, ...), else Nil.

     QwkImportFile goes through the conferences of the file in turn and writes each message the way mk
     writes one that is entered (MKEnter): the area is opened once per conference, SetMailType by the
     kind of area, StartNewMsg, the fields, the text and WriteMsg.
       - the text: kludge (^A) lines of the packet are left out (KeepKludges True keeps them; with QwkStripCtrlA the
         Ctrl-A colour codes of the other lines are taken out and those lines stay); for echomail
         and netmail areas T.TearLine and T.OriginLine follow the text
       - names: T.ForceFrom replaces the From name (a caller must not post as somebody else), else the
         names are in Proper case (QWK has them in upper case)
       - a message to All is public; T.PrivMode says whether private is the choice of the message (0), always (1)
         or never (2)
       - netmail (T.Kind = mmtNetMail): the subject field holds @address and the real subject is the first
         line "Subj: ..." of the text (as the offline mail door writes it); a message without a good address
         is skipped as grunged
       - T.ReDate gives the messages today's date, else the date they were written
       - duplicates: with a file name in DupeFN the messages are checked by a CRC of conference, names,
         subject, date and time (MKDupe, 15 days), the file is made if it is not there
     Control messages: a message to SBBS or MK (as Synchronet networks send them) is not posted when the caller of
     QwkImportFile has set QwkControl: the procedure gets the conference and the subject ("ADD", "DROP 12" ...) and
     returns True when it took the message.  They are handled before the conferences are mapped (a node may drop
     an area it cannot write to).
     Costs, crash / immediate netmail flags and QWKE long names are not handled yet.
}


Interface

Uses MKGlobT, MKMsgAbs;


Const
  qiPosted = 1;       {Note codes: a message was written}
  qiDupe = 2;         {skipped: was posted before}
  qiGrunged = 3;      {skipped: no From name, or a netmail without an address}
  qiRefused = 4;      {a conference that Map refused: its messages are not posted}
  qiFailed = 5;       {a message or an area that could not be written / opened}
  qiMoved = 6;        {the messages of a conference are put in the area for bad messages}
  qiControl = 7;      {a control message (to SBBS or MK) was taken by QwkControl}


Const
  QwkStripCtrlA: Boolean = False;     {when set: a Ctrl-A and the character after it (the colour and attribute codes of a Synchronet
                                       packet) are taken out of the text of every message, and a line that began with one is kept
                                       (without it the whole line goes: it is taken for a kludge).  A real kludge line (^AMSGID: ...)
                                       is dealt with as before (left out unless KeepKludges).  QWK network passes: "strip-ctrla" in the map file}

Type QwkImpTarget = Record
  AreaId: String[60];             {message area id string, as MKOpen wants it}
  Area: Word;                     {the number of the area (for the caller's own use)}
  Kind: MsgMailType;
  ForceFrom: String[35];          {'' = the name of the message}
  OrigAddr: AddrType;             {netmail: the address of the area}
  PrivMode: Byte;                 {0 as the message says, 1 always private, 2 never private}
  Local: Boolean;                 {SetLocal}
  Echo: Boolean;                  {SetEcho}
  ReDate: Boolean;
  KeepKludges: Boolean;
  Create: Boolean;                {the message base is made when it is not there (the areas of a network)}
  TearLine: String[80];
  OriginLine: String[100];
  End;


Type QwkImpResult = Record
  Msgs: LongInt;                  {messages in the file}
  Posted: LongInt;
  Dupes: LongInt;
  Grunged: LongInt;
  Refused: LongInt;
  Moved: LongInt;                 {counted in Posted, too}
  Control: LongInt;               {control messages (QwkControl took them)}
  Failed: LongInt;
  End;


Type QwkImpMapProc = Function(Conf: LongInt; Var T: QwkImpTarget; Var Moved: Boolean): Boolean;
Type QwkImpNoteProc = Procedure(Code: Word; Conf: LongInt; Msg: AbsMsgPtr);


Type QwkImpControlProc = Function(Conf: LongInt; Subj: String): Boolean;
Var QwkControl: QwkImpControlProc;     {Nil = messages to SBBS and MK are posted like the others}


Function QwkImportFile(FN: String; DupeFN: String; Map: QwkImpMapProc; Note: QwkImpNoteProc;
  Var R: QwkImpResult): Word;
  {0 or the error of MKMsgQwk (1001 no such file, 1003 not a QWK file ...)}


Implementation


Uses MKString, MKOpen, MKMsgQwk, MKDupe, Crc32,
  Dos;


Const
  DupeSize = 4000;
  DupeDays = 15;


Function Z2(N: LongInt): String;
  Begin
  Z2 := Chr(48 + (N Div 10) Mod 10) + Chr(48 + N Mod 10);
  End;


Procedure CrcString(Var Crc: LongInt; InStr: String);
  Var
    i: Word;

  Begin
  For i := 1 To Length(InStr) Do
    Crc := UpdC32(Ord(InStr[i]), Crc);
  End;


Procedure InitTarget(Var T: QwkImpTarget);
  Begin
  FillChar(T, SizeOf(T), 0);
  T.Kind := mmtNormal;
  T.Local := True;
  T.Echo := True;
  End;


Function IsControl(ToName: String): Boolean;
  Begin
  ToName := Upper(StripBoth(ToName, ' '));
  IsControl := Assigned(QwkControl) And ((ToName = 'SBBS') Or (ToName = 'MK'));
  End;


Function IsKludgeLine(Const L: String): Boolean;
  {^A, then 2 or more upper case letters or digits, then a colon or a blank: ^AMSGID: ..., ^AFMPT 3, ^AINTL ...}
  Var
    i: Word;

  Begin
  IsKludgeLine := False;
  If (Length(L) < 4) Or (L[1] <> #1) Then
    Exit;
  i := 2;
  While (i <= Length(L)) And (L[i] In ['A'..'Z', '0'..'9']) Do
    Inc(i);
  IsKludgeLine := (i >= 4) And (i <= Length(L)) And (L[i] In [':', ' ']);
  End;


Procedure StripCtrlA(Var L: String);
  Var
    i: Word;
    R: String;

  Begin
  R := '';
  i := 1;
  While i <= Length(L) Do
    If L[i] = #1 Then
      Inc(i, 2)
    Else
      Begin
      R := R + L[i];
      Inc(i);
      End;
  L := R;
  End;


Procedure PostOne(Var Q: QwkMsgObj; Msg: AbsMsgPtr; Var T: QwkImpTarget; Conf: LongInt;
  Var Dup: DupeObj; UseDupe: Boolean; Note: QwkImpNoteProc; Var R: QwkImpResult);
  Var
    From, ToName, Subj, SubjField, Date, Time, Line: String;
    Crc: LongInt;
    Dest: AddrType;
    Pv: Boolean;
    C: Char;
    First: Boolean;
    Yy, Mo, Dd, Dw, Hh, Mi, Ss, Cs: Word;
    Res: Word;

  Procedure Emit(CR: Boolean);
    {Line is a whole line (CR) or a piece of one: kludge lines are left out, the "Subj:" line of a netmail gives the subject}
    Begin
    If QwkStripCtrlA And (Not IsKludgeLine(Line)) Then
      StripCtrlA(Line);
    If (Length(Line) > 0) And (Line[1] = #1) And (Not T.KeepKludges) Then
      Line := ''
    Else If First And (T.Kind = mmtNetMail) And (Copy(Line, 1, 6) = 'Subj: ') Then
      Begin
      Subj := Copy(Line, 7, 72);
      Line := '';
      End
    Else
      Begin
      Msg^.DoString(Line);
      If CR Then
        Msg^.DoChar(#13);
      End;
    First := False;
    Line := '';
    End;

  Begin
  From := StripBoth(Q.GetFrom, ' ');
  SubjField := Q.GetSubj;
  If From = '' Then
    Begin
    Inc(R.Grunged);
    Note(qiGrunged, Conf, Nil);
    Exit;
    End;
  ToName := StripBoth(Q.GetTo, ' ');
  If ToName = '' Then
    ToName := 'ALL';
  If IsControl(ToName) Then
    Exit;                               {taken before (QwkControl)}
  Date := Q.GetDate;
  Time := Q.GetTime;
  Subj := SubjField;
  If T.Kind = mmtNetMail Then
    Begin
    If (Length(SubjField) < 2) Or (SubjField[1] <> '@') Or
       (Not ParseAddr(Copy(SubjField, 2, 60), T.OrigAddr, Dest)) Then
      Begin
      Inc(R.Grunged);
      Note(qiGrunged, Conf, Nil);
      Exit;
      End;
    Subj := '';
    End;
  {a message that was posted before}
  If UseDupe Then
    Begin
    Crc := -1;
    CrcString(Crc, ToName);
    CrcString(Crc, From);
    CrcString(Crc, SubjField);
    CrcString(Crc, Date);
    CrcString(Crc, Time);
    Crc := UpdC32(Conf And 255, Crc);
    Crc := UpdC32((Conf Shr 8) And 255, Crc);
    If Dup.DupeCheck(Crc) Then
      Begin
      Inc(R.Dupes);
      Note(qiDupe, Conf, Nil);
      Exit;
      End;
    End;
  If T.ForceFrom <> '' Then
    From := T.ForceFrom
  Else
    From := Proper(From);
  ToName := Proper(ToName);
  Case T.PrivMode Of
    1: Pv := True;
    2: Pv := False;
    Else Pv := Q.IsPriv;
    End;
  If Upper(ToName) = 'ALL' Then
    Pv := False;
  If T.ReDate Then
    Begin
    Dos.GetDate(Yy, Mo, Dd, Dw);
    Dos.GetTime(Hh, Mi, Ss, Cs);
    Date := Z2(Mo) + '-' + Z2(Dd) + '-' + Z2(Yy Mod 100);
    Time := Z2(Hh) + ':' + Z2(Mi);
    End;
  {the text, line by line}
  Msg^.StartNewMsg;
  If T.Kind = mmtNetMail Then
    Begin
    Msg^.SetDest(Dest);
    Msg^.SetOrig(T.OrigAddr);
    End;
  Q.MsgTxtStartUp;
  Line := '';
  First := True;
  C := Q.GetChar;
  While Not Q.EOM Do
    Begin
    If C = #13 Then
      Emit(True)
    Else
      Begin
      Line := Line + C;
      If Length(Line) >= 255 Then
        Emit(False);                    {a very long line goes on in the next piece}
      End;
    C := Q.GetChar;
    End;
  If Line <> '' Then
    Emit(False);
  If (T.Kind <> mmtNormal) And (T.TearLine <> '') Then
    Begin
    Msg^.DoStringLn(T.TearLine);
    If T.OriginLine <> '' Then
      Msg^.DoStringLn(T.OriginLine);
    End;
  Msg^.SetFrom(From);
  Msg^.SetTo(ToName);
  Msg^.SetSubj(Subj);
  Msg^.SetPriv(Pv);
  Msg^.SetDate(Date);
  Msg^.SetTime(Time);
  Msg^.SetLocal(T.Local);
  Msg^.SetEcho(T.Echo);
  Msg^.SetRefer(Q.GetRefer);
  Res := Msg^.WriteMsg;
  If Res = 0 Then
    Begin
    Inc(R.Posted);
    Note(qiPosted, Conf, Msg);
    End
  Else
    Begin
    Inc(R.Failed);
    Note(qiFailed, Conf, Nil);
    End;
  End;


Function QwkImportFile(FN: String; DupeFN: String; Map: QwkImpMapProc; Note: QwkImpNoteProc;
  Var R: QwkImpResult): Word;
  Var
    Q: QwkMsgObj;
    T: QwkImpTarget;
    Dup: DupeObj;
    UseDupe, Moved: Boolean;
    Conf: LongInt;
    N: LongInt;
    Msg: AbsMsgPtr;
    E: Word;

  Begin
  FillChar(R, SizeOf(R), 0);
  Q.Init;
  Q.SetMsgPath(FN);
  Q.SetReadCharset(qcAuto);
  Q.SetQwke(qkAuto);                   {QWKE long names and subjects, where they fit the header}
  E := Q.OpenMsgBase;
  If E <> 0 Then
    Begin
    QwkImportFile := E;
    Q.Done;
    Exit;
    End;
  UseDupe := DupeFN <> '';
  If UseDupe Then
    Begin
    Dup.Init;
    Dup.Open(DupeFN, DupeSize);
    Dup.SetDays(DupeDays);
    End;
  Conf := -1;
  Repeat
    Conf := Q.NextConf(Conf);
    If Conf >= 0 Then
      Begin
      Q.SetConference(Conf);
      Q.SeekFirst(1);
      N := Q.NumberOfMsgs;
      Inc(R.Msgs, N);
      If Assigned(QwkControl) Then
        Begin
        While Q.SeekFound Do
          Begin
          Q.MsgStartUp;
          If IsControl(Q.GetTo) Then
            Begin
            If QwkControl(Conf, Q.GetSubj) Then;
            Inc(R.Control);
            Note(qiControl, Conf, Nil);
            End;
          Q.SeekNext;
          End;
        Q.SeekFirst(1);
        End;
      InitTarget(T);
      Moved := False;
      If (Not Map(Conf, T, Moved)) Or (T.AreaId = '') Then
        Begin
        Inc(R.Refused, N);
        Note(qiRefused, Conf, Nil);
        End
      Else If Not ((T.Create And OpenOrCreateMsgArea(Msg, T.AreaId)) Or ((Not T.Create) And OpenMsgArea(Msg, T.AreaId))) Then
        Begin
        Inc(R.Failed, N);
        Note(qiFailed, Conf, Nil);
        End
      Else
        Begin
        If Moved Then
          Begin
          Inc(R.Moved, N);
          Note(qiMoved, Conf, Nil);
          End;
        Msg^.SetMailType(T.Kind);
        While Q.SeekFound Do
          Begin
          Q.MsgStartUp;
          PostOne(Q, Msg, T, Conf, Dup, UseDupe, Note, R);
          Q.SeekNext;
          End;
        If CloseMsgArea(Msg) Then;
        End;
      End;
  Until Conf < 0;
  If UseDupe Then
    Begin
    Dup.CloseFile;
    Dup.Done;
    End;
  Q.CloseMsgBase;
  Q.Done;
  QwkImportFile := 0;
  End;


End.
