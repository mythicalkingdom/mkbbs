Program MKMsgConv;

{$mode objfpc}{$H+}

{
     mkmsgconv: copies a message area into a new base of another kind (MSGCONV-PLAN.md).

       mkmsgconv [-c config dir] -a <areas> | -k <type>  -t <type>  [-d file id] [-n] [-s] [-m] [-f] [-v] [-q]

         -a    the areas: numbers, separated by commas, and ranges (3,7,10-20)
         -k    every area of this kind (H S F J M Y) instead of -a
         -t    the new kind: H Hudson, S Squish, F Fido *.msg, J JAM, M Merlin, Y Synchronet
         -d    the file id of the new base (default: the area's own file id, or area<N>); Squish, JAM, Merlin, Synchronet: a file name below the
               message path of the area, Fido: a directory name; Hudson uses the board number of the area and the message path
         -n    a dry run: the copy is made in a scratch directory (and removed), so what the new kind cannot hold is counted exactly; nothing is written to the BBS
         -s    after the copy checked out: the area is of the new kind (and has the new file id) in the configuration: config.mk and bbsconfig.json both, when both are there; the old files stay
         -m    keep the number map (old new) in <BBS dir>/convmap/area<N>.map
         -f    go on although the new base already has messages (they stay, the copy is added), a caller is on line, a non-empty destination
         -v    each message
         -q    only the summary

     The old base is never changed.  The new base is written beside it, read again and compared with the old one, message by message; the report says
     what the new kind could not hold (a cut subject ...).  The configuration is not changed (the report says what to set in mkconfig).
     The last-read pointer of every user (users.bbs) is moved through the map to the new base: the new number of the last message at or below the old pointer (JAM by the check sum of the name).
     A caller on line (useron.bbs) stops it (exit 3; -f: anyway): run it in an exclusive event.  The scan mark of the tosser is not touched: the next scan reads the new base once from the
     start (everything converted is sent already, so nothing goes out twice).
     A message waiting to be sent (an echomail message of this system that the tosser has not scanned, a netmail not sent) stops the area: run mktoss first.

     The exit code: 0 done, 1 not usable (options, no configuration), 2 an area was refused or failed.
}

Uses SysUtils, Classes, BaseUnix, Unix,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKMsgAbs, MKMsgHud, MKMsgJam, MKMsgSqu, MKMsgFid, MKMsgMer, MKMsgSyn, MKOpen, MKFile, MKCfgMK, MKCfgJs;

Type
  TFlags = Record
    Local, Crash, KillSent, Sent, FAttach, ReqRct, ReqAud, RetRct, FileReq, Hold, Rcvd, Priv: Boolean;
    End;

Var
  Dry, Verbose, Quiet, Force, KeepMap, Switch: Boolean;
  DestType: Char = ' ';
  FileIdOpt: String = '';
  AreaList: TStringList;
  KindFilter: Char = ' ';
  Failed: Boolean = False;
  TotalMsgs, TotalAreas, TotalOk: LongInt;
  OldNum, NewNum: Array Of LongInt;      {the map of the area being converted, in the order of the old numbers}
  NMap: LongInt;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkmsgconv: ', S);
  Halt(Code);
  End;


Function KindName(C: Char): String;
  Begin
  Case UpCase(C) Of
    'H': KindName := 'Hudson';
    'S': KindName := 'Squish';
    'F': KindName := 'Fido *.msg';
    'J': KindName := 'JAM';
    'M': KindName := 'Merlin';
    'Y': KindName := 'Synchronet';
    'E': KindName := 'Ezycom';
    'B': KindName := 'PCBoard';
    Else
      KindName := C;
    End;
  End;


Function MapNew(Old: LongInt): LongInt;
  {the new number of an old one; 0 when the old message is not in the new base (it was deleted, or does not exist)}
  Var
    Lo, Hi, Mid: LongInt;

  Begin
  MapNew := 0;
  Lo := 0;
  Hi := NMap - 1;
  While Lo <= Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If OldNum[Mid] = Old Then
      Begin
      MapNew := NewNum[Mid];
      Exit;
      End
    Else If OldNum[Mid] < Old Then
      Lo := Mid + 1
    Else
      Hi := Mid - 1;
    End;
  End;


Procedure GetFlags(M: AbsMsgPtr; Var F: TFlags);
  Begin
  F.Local := M^.IsLocal;
  F.Crash := M^.IsCrash;
  F.KillSent := M^.IsKillSent;
  F.Sent := M^.IsSent;
  F.FAttach := M^.IsFAttach;
  F.ReqRct := M^.IsReqRct;
  F.ReqAud := M^.IsReqAud;
  F.RetRct := M^.IsRetRct;
  F.FileReq := M^.IsFileReq;
  F.Hold := M^.IsHold;
  F.Rcvd := M^.IsRcvd;
  F.Priv := M^.IsPriv;
  End;


Function SameFlags(Var A, B: TFlags): Boolean;
  Begin
  SameFlags := (A.Local = B.Local) And (A.Crash = B.Crash) And (A.KillSent = B.KillSent) And (A.Sent = B.Sent) And (A.FAttach = B.FAttach) And
    (A.ReqRct = B.ReqRct) And (A.ReqAud = B.ReqAud) And (A.RetRct = B.RetRct) And (A.FileReq = B.FileReq) And (A.Hold = B.Hold) And
    (A.Rcvd = B.Rcvd) And (A.Priv = B.Priv);
  End;


Function MsgText(M: AbsMsgPtr): AnsiString;
  {the text as it is kept, in one form for every kind: the characters of the message, kludge lines and line ends (CR) included; what only some kinds add is left out: the NUL that ends
   Hudson, Squish and *.msg text, the LF that Synchronet puts after a CR, the soft CR (#$8D)}
  Var
    S: AnsiString;
    C: Char;
    n: LongInt;

  Begin
  S := '';
  n := 0;
  M^.MsgTxtStartUp;
  While (Not M^.EOM) And (n < 4000000) Do
    Begin
    C := M^.GetChar;
    If (C <> #0) And (C <> #10) And (C <> #$8D) Then
      S := S + C;
    Inc(n);
    End;
  If S = '' Then
    S := #13;                              {every kind keeps at least the end of a line (Merlin and Synchronet refuse a message with no text)}
  MsgText := S;
  End;


Function NoKludges(Const T: AnsiString): AnsiString;
  {the text without its kludge lines (a line that starts with ^A)}
  Var
    i: LongInt;
    Skip: Boolean;
    R: AnsiString;

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
  If R = '' Then
    R := #13;
  NoKludges := R;
  End;


Function SameText(Const A, B: AnsiString): Boolean;
  {the same text; a kind that does not keep blank lines at the end does not make a difference}
  Var
    X, Y: AnsiString;

  Begin
  X := A;
  Y := B;
  While (Length(X) > 1) And (X[Length(X)] = #13) Do
    SetLength(X, Length(X) - 1);
  While (Length(Y) > 1) And (Y[Length(Y)] = #13) Do
    SetLength(Y, Length(Y) - 1);
  SameText := X = Y;
  End;


Function Scratch(Const Tag: String): String;
  Begin
  Scratch := '/tmp/mkmsgconv-' + IntToStr(fpGetPid) + '-' + Tag + '/';
  End;


Procedure RemoveTree(Const Dir: String);
  Var
    SR: TSearchRec;
    P: String;
    St: Stat;

  Begin
  If FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If (SR.Name <> '.') And (SR.Name <> '..') Then
        Begin
        P := IncludeTrailingPathDelimiter(Dir) + SR.Name;
        If (fpLStat(P, St) = 0) And fpS_ISDIR(St.st_mode) Then
          RemoveTree(P)
        Else
          fpUnlink(P);
        End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  fpRmDir(Dir);
  End;


Function DestId(A: Word; Const Dir: String): String;
  {the area id of the new base: by the rules of the configuration (what the id would be if the area were of the new kind), or in the scratch directory Dir (a dry run)}
  Var
    OldF, Fid, Id, Base: String;

  Begin
  OldF := Config^.GetMsgFileId(A);
  Fid := FileIdOpt;
  If Fid = '' Then
    Fid := OldF;
  If Fid = '' Then
    Fid := 'area' + IntToStr(A);
  {the rules of the configuration (MKCfgObj.GetMsgAreaId), for the new kind: Hudson is the board of the area number in the first message path, the others a file id below the path of the area}
  If Dir <> '' Then
    Base := Dir
  Else If UpCase(DestType) = 'H' Then
    Base := Config^.GetMsgPath(1)
  Else
    Base := Config^.GetMsgPath(Config^.GetMsgPathNum(A));
  If (Base <> '') And (Base[Length(Base)] <> '/') Then
    Base := Base + '/';
  Case UpCase(DestType) Of
    'H': Id := 'H' + RightStr('000' + IntToStr(A), 3) + Base;
    'F': Id := 'F' + Base + Fid + '/';
    Else
      Id := UpCase(DestType) + Base + Fid;
    End;
  DestId := Id;
  End;


Function FileIdFor(A: Word): String;
  {the file id the new base has in the configuration: -d, else the old one, else area<N> (Hudson has none: the board is the area number)}
  Begin
  If UpCase(DestType) = 'H' Then
    Begin
    FileIdFor := '';
    Exit;
    End;
  FileIdFor := FileIdOpt;
  If FileIdOpt = '' Then
    FileIdFor := Config^.GetMsgFileId(A);
  If FileIdFor = '' Then
    FileIdFor := 'area' + IntToStr(A);
  End;


Function SwitchStore(Obj: CfgObjPtr; A: Word; Fid: String; Const What: String): String;
  {sets the kind and the file id of the area in one store of the configuration and saves it; '' when it went, else why not}
  Begin
  SwitchStore := '';
  Obj^.Load;
  If Obj^.GetError <> 0 Then
    Begin
    SwitchStore := What + ' cannot be loaded (' + IntToStr(Obj^.GetError) + ')';
    Exit;
    End;
  Obj^.SetMsgBaseType(A, UpCase(DestType));
  Obj^.SetMsgFileId(A, Fid);
  Obj^.Save;
  End;


Function SwitchArea(A: Word; Const Dst: String): String;
  {-s: the area is of the new kind in the configuration: the store in use, and the other one too when both exist (config.mk and bbsconfig.json are kept in step).  Then the configuration is read again and must give
   the new base for the area.  '' when it went, else why not}
  Var
    Obj: CfgObjPtr;
    Fid, Dir, E, Chk: String;
    Chk2: CfgObjPtr;
    InUseJson: Boolean;

  Begin
  SwitchArea := '';
  Fid := FileIdFor(A);
  Dir := IncludeTrailingPathDelimiter(Config^.GetBbsPath);
  InUseJson := JsonConfigWanted;
  Obj := NewMKConfig(False);
  E := SwitchStore(Obj, A, Fid, Copy('bbsconfig.json', 1, 14 * Ord(InUseJson)) + Copy('config.mk', 1, 9 * Ord(Not InUseJson)));
  Dispose(Obj, Done);
  If E <> '' Then
    Begin
    SwitchArea := E;
    Exit;
    End;
  If InUseJson Then
    Begin
    If FileExists(Dir + 'config.mk') Then
      Begin
      Obj := New(MKCfgObjPtr, Init);
      E := SwitchStore(Obj, A, Fid, 'config.mk');
      Dispose(Obj, Done);
      End;
    End
  Else If FileExists(JsonConfigFile(Dir)) Then
    Begin
    Obj := New(MKJsonCfgObjPtr, Init);
    E := SwitchStore(Obj, A, Fid, 'bbsconfig.json');
    Dispose(Obj, Done);
    End;
  If E <> '' Then
    Begin
    SwitchArea := E;
    Exit;
    End;
  Chk2 := NewMKConfig(True);
  Chk2^.Load;
  Chk := Chk2^.GetMsgAreaId(A);
  Dispose(Chk2, Done);
  If Chk <> Dst Then
    SwitchArea := 'the configuration gives ' + Chk + ' for the area, not ' + Dst;
  End;


Function Convert(A: Word; Const Src, Dst: String; Out Cut: String; Out Err: String): LongInt;
  {copies the messages of the base Src into the base Dst and checks the copy; the number of messages copied, -1 when it failed (Err says why).  Cut: what the new kind could not hold}
  Var
    S, D, C: AbsMsgPtr;
    Orig, Dest, O2, D2: AddrType;
    F, F2: TFlags;
    Txt, Txt2: AnsiString;
    n, i, Nw: LongInt;
    Num: LongInt;
    Pend: Boolean;
    Echo, Net: Boolean;
    CutFrom, CutTo, CutSubj, CutDate, CutAddr, CutFlags, CutCost, CutKludge, Bad: LongInt;
    Refs, Sees, Nexts: Array Of LongInt;

  Begin
  Convert := -1;
  Cut := '';
  Err := '';
  If Not OpenMsgArea(S, Src) Then
    Begin
    Err := 'the old base cannot be opened';
    Exit;
    End;
  Net := Config^.GetMsgType(A) = NetMail;
  Echo := Config^.GetMsgType(A) = EchoMail;
  {a message waiting to be sent stops the area}
  S^.SeekFirst(1);
  While S^.SeekFound Do
    Begin
    S^.MsgStartUp;
    If Not S^.IsDeleted Then
      Begin
      Pend := S^.IsLocal And (Not S^.IsSent) And ((Echo And S^.IsEchoed) Or Net);
      If Pend Then
        Begin
        Err := 'message ' + IntToStr(S^.GetMsgNum) + ' waits to be sent: run mktoss first';
        If CloseMsgArea(S) Then;
        Exit;
        End;
      End;
    S^.SeekNext;
    End;
  If Not OpenOrCreateMsgArea(D, Dst) Then
    Begin
    Err := 'the new base cannot be made (' + Dst + ')';
    If CloseMsgArea(S) Then;
    Exit;
    End;
  If (D^.NumberOfMsgs > 0) And (Not Force) Then
    Begin
    Err := 'the new base already holds ' + IntToStr(D^.NumberOfMsgs) + ' message(s): -f adds to them';
    If CloseMsgArea(S) Then;
    If CloseMsgArea(D) Then;
    Exit;
    End;
  NMap := 0;
  SetLength(OldNum, 0);
  SetLength(NewNum, 0);
  SetLength(Refs, 0);
  SetLength(Sees, 0);
  SetLength(Nexts, 0);
  n := 0;
  S^.SeekFirst(1);
  While S^.SeekFound Do
    Begin
    S^.MsgStartUp;
    If Not S^.IsDeleted Then
      Begin
      Num := S^.GetMsgNum;
      S^.GetOrig(Orig);
      S^.GetDest(Dest);
      GetFlags(S, F);
      Txt := MsgText(S);
      D^.StartNewMsg;
      D^.SetFrom(S^.GetFrom);
      D^.SetTo(S^.GetTo);
      D^.SetSubj(S^.GetSubj);
      D^.SetDate(S^.GetDate);
      D^.SetTime(S^.GetTime);
      D^.SetCost(S^.GetCost);
      NMap := n;                                {what is written so far can be linked at once (a reply to an earlier message); some kinds cannot change a link afterwards}
      D^.SetRefer(MapNew(S^.GetRefer));
      D^.SetOrig(Orig);
      D^.SetDest(Dest);
      D^.SetLocal(F.Local);
      D^.SetRcvd(F.Rcvd);
      D^.SetPriv(F.Priv);
      D^.SetCrash(F.Crash);
      D^.SetKillSent(F.KillSent);
      D^.SetSent(F.Sent);
      D^.SetFAttach(F.FAttach);
      D^.SetReqRct(F.ReqRct);
      D^.SetReqAud(F.ReqAud);
      D^.SetRetRct(F.RetRct);
      D^.SetFileReq(F.FileReq);
      D^.SetHold(F.Hold);
      D^.SetEcho(False);                       {nothing that waits to be sent comes this far}
      For i := 1 To Length(Txt) Do
        D^.DoChar(Txt[i]);
      If D^.WriteMsg <> 0 Then
        Begin
        Err := 'the new base refused message ' + IntToStr(Num);
        If CloseMsgArea(S) Then;
        If CloseMsgArea(D) Then;
        Exit;
        End;
      Nw := D^.GetHighMsgNum;
      If n >= Length(OldNum) Then
        Begin
        SetLength(OldNum, Length(OldNum) + 512);
        SetLength(NewNum, Length(NewNum) + 512);
        SetLength(Refs, Length(Refs) + 512);
        SetLength(Sees, Length(Sees) + 512);
        SetLength(Nexts, Length(Nexts) + 512);
        End;
      OldNum[n] := Num;
      NewNum[n] := Nw;
      Refs[n] := S^.GetRefer;
      Sees[n] := S^.GetSeeAlso;
      Nexts[n] := S^.GetNextSeeAlso;
      Inc(n);
      If Verbose Then
        WriteLn('  #', Num, ' -> #', Nw);
      End;
    S^.SeekNext;
    End;
  NMap := n;
  {the reply links, with the new numbers}
  For i := 0 To n - 1 Do
    If (UpCase(DestType) <> 'Y') And ((Sees[i] <> 0) Or (Nexts[i] <> 0) Or ((Refs[i] <> 0) And (MapNew(Refs[i]) > NewNum[i]))) Then      {a link that was not known when the message was written (Synchronet keeps its reply links as written)}
      Begin
      D^.SeekFirst(NewNum[i]);
      If D^.SeekFound Then
        Begin
        D^.MsgStartUp;
        If D^.GetMsgNum = NewNum[i] Then
          Begin
          D^.SetRefer(MapNew(Refs[i]));
          D^.SetSeeAlso(MapNew(Sees[i]));
          D^.SetNextSeeAlso(MapNew(Nexts[i]));
          D^.ReWriteHdr;
          End;
        End;
      End;
  If CloseMsgArea(D) Then;
  If CloseMsgArea(S) Then;
  {the new base is read again and compared with the old one}
  If (Not OpenMsgArea(S, Src)) Or (Not OpenMsgArea(C, Dst)) Then
    Begin
    Err := 'the bases cannot be opened again to check the copy';
    Exit;
    End;
  CutFrom := 0; CutTo := 0; CutSubj := 0; CutDate := 0; CutAddr := 0; CutFlags := 0; CutCost := 0; CutKludge := 0; Bad := 0;
  i := 0;
  S^.SeekFirst(1);
  While S^.SeekFound Do
    Begin
    S^.MsgStartUp;
    If Not S^.IsDeleted Then
      Begin
      If i >= n Then
        Begin
        Inc(Bad);
        Break;
        End;
      C^.SeekFirst(NewNum[i]);
      If Not C^.SeekFound Then
        Inc(Bad)
      Else
        Begin
        C^.MsgStartUp;
        Txt := MsgText(S);
        Txt2 := MsgText(C);
        If (Not SameText(Txt, Txt2)) And (UpCase(DestType) = 'Y') And SameText(NoKludges(Txt), NoKludges(Txt2)) Then
          Inc(CutKludge)                        {Synchronet keeps no kludge lines in the text}
        Else If Not SameText(Txt, Txt2) Then
          Begin
          Inc(Bad);
          If Verbose Then
            WriteLn('  #', S^.GetMsgNum, ': the text differs (', Length(Txt), ' / ', Length(Txt2), ' characters)');
          End;
        If S^.GetFrom <> C^.GetFrom Then Inc(CutFrom);
        If S^.GetTo <> C^.GetTo Then Inc(CutTo);
        If S^.GetSubj <> C^.GetSubj Then Inc(CutSubj);
        If (S^.GetDate <> C^.GetDate) Or (Copy(S^.GetTime, 1, 5) <> Copy(C^.GetTime, 1, 5)) Then Inc(CutDate);
        If S^.GetCost <> C^.GetCost Then Inc(CutCost);
        S^.GetOrig(O2); C^.GetOrig(Orig); S^.GetDest(D2); C^.GetDest(Dest);
        If (O2.Zone <> Orig.Zone) Or (O2.Net <> Orig.Net) Or (O2.Node <> Orig.Node) Or (O2.Point <> Orig.Point) Or
           (D2.Zone <> Dest.Zone) Or (D2.Net <> Dest.Net) Or (D2.Node <> Dest.Node) Or (D2.Point <> Dest.Point) Then
          Inc(CutAddr);
        GetFlags(S, F);
        GetFlags(C, F2);
        If Not SameFlags(F, F2) Then Inc(CutFlags);
        End;
      Inc(i);
      End;
    S^.SeekNext;
    End;
  If i <> n Then
    Inc(Bad);
  If CloseMsgArea(S) Then;
  If CloseMsgArea(C) Then;
  If CutKludge > 0 Then Cut := Cut + ', ' + IntToStr(CutKludge) + ' message(s) lost their kludge lines (Synchronet keeps none in the text)';
  If CutFrom > 0 Then Cut := Cut + ', ' + IntToStr(CutFrom) + ' from name(s) cut';
  If CutTo > 0 Then Cut := Cut + ', ' + IntToStr(CutTo) + ' to name(s) cut';
  If CutSubj > 0 Then Cut := Cut + ', ' + IntToStr(CutSubj) + ' subject(s) cut';
  If CutDate > 0 Then Cut := Cut + ', ' + IntToStr(CutDate) + ' date(s) or time(s) changed';
  If CutAddr > 0 Then Cut := Cut + ', ' + IntToStr(CutAddr) + ' with an address the new kind does not keep';
  If CutCost > 0 Then Cut := Cut + ', ' + IntToStr(CutCost) + ' with a cost the new kind does not keep';
  If CutFlags > 0 Then Cut := Cut + ', ' + IntToStr(CutFlags) + ' with flags the new kind does not keep';
  If Bad > 0 Then
    Begin
    Err := 'the check failed: ' + IntToStr(Bad) + ' message(s) are not the same in the new base (text or number)';
    Exit;
    End;
  Convert := n;
  End;


Procedure WriteMap(A: Word);
  Var
    F: Text;
    i: LongInt;
    Dir: String;

  Begin
  Dir := IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'convmap';
  ForceDirectories(Dir);
  AssignFile(F, Dir + '/area' + IntToStr(A) + '.map');
  {$I-}
  ReWrite(F);
  {$I+}
  If IOResult <> 0 Then
    Begin
    WriteLn(StdErr, 'mkmsgconv: the map cannot be written in ', Dir);
    Exit;
    End;
  WriteLn(F, '# mkmsgconv: area ', A, ', old new');
  For i := 0 To NMap - 1 Do
    WriteLn(F, OldNum[i], ' ', NewNum[i]);
  CloseFile(F);
  End;


Function MapAtOrBelow(Old: LongInt): LongInt;
  {the new number of the last message that was at or below the old number (0 when there is none): where a caller who had read up to Old stands in the new base}
  Var
    Lo, Hi, Mid: LongInt;

  Begin
  MapAtOrBelow := 0;
  Lo := 0;
  Hi := NMap - 1;
  While Lo <= Hi Do
    Begin
    Mid := (Lo + Hi) Div 2;
    If OldNum[Mid] <= Old Then
      Begin
      MapAtOrBelow := NewNum[Mid];
      Lo := Mid + 1;
      End
    Else
      Hi := Mid - 1;
    End;
  End;


Function CallersOnLine: String;
  {the names of the callers on line (useron.bbs), '' when nobody is}
  Var
    UO: UserOnType;
    Fn: String;
    k, N: LongInt;

  Begin
  CallersOnLine := '';
  Fn := IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'useron.bbs';
  If Not FileExists(Fn) Then
    Exit;
  N := SizeFile(Fn) Div SizeOf(UserOnType);
  For k := 0 To N - 1 Do
    If LoadFilePos(Fn, UO, SizeOf(UO), k * SizeOf(UO)) = 0 Then
      If (UO.Name <> '') And (UO.Status <> uoNotAvail) And (UO.Status <> uoWait) Then
        Begin
        CallersOnLine := UO.Name + ' (node ' + IntToStr(UO.Node) + ')';
        Exit;
        End;
  End;


Function CopyLastRead(Src, Dst: String; Write: Boolean): LongInt;
  {the last-read pointer of every user of users.bbs, through the map: the new base gets the new number of the last message at or below the old pointer.  JAM keeps its pointers by the
   check sum of the user's name, the others by the record number in users.bbs.  The number of pointers set (or, with Write False, that would be set); -1 when a base cannot be opened}
  Var
    S, D: AbsMsgPtr;
    Fn: String;
    U: UsersType;
    N, k, Old, New, Cnt: LongInt;
    SJ, DJ: Boolean;

  Begin
  CopyLastRead := 0;
  Fn := Config^.FindBbsFile('users.bbs') + 'users.bbs';
  If Not FileExists(Fn) Then
    Exit;
  If Not OpenMsgArea(S, Src) Then
    Begin
    CopyLastRead := -1;
    Exit;
    End;
  D := Nil;
  If Write And (UpCase(Dst[1]) <> 'Y') Then
    If Not OpenMsgArea(D, Dst) Then
      Begin
      If CloseMsgArea(S) Then;
      CopyLastRead := -1;
      Exit;
      End;
  SJ := UpCase(Src[1]) = 'J';
  DJ := UpCase(Dst[1]) = 'J';
  N := SizeFile(Fn) Div SizeOf(UsersType);
  Cnt := 0;
  For k := 0 To N - 1 Do
    If LoadFilePos(Fn, U, SizeOf(U), k * SizeOf(U)) = 0 Then
      Begin
      If SJ Then
        Old := S^.GetLastRead(JamStrCrc(U.Name))
      Else
        Old := S^.GetLastRead(k);
      If Old > 0 Then
        Begin
        New := MapAtOrBelow(Old);
        If New > 0 Then
          Begin
          If Write And (D <> Nil) Then
            If DJ Then
              D^.SetLastRead(JamStrCrc(U.Name), New)
            Else
              D^.SetLastRead(k, New);
          Inc(Cnt);
          End;
        End;
      End;
  If CloseMsgArea(S) Then;
  If D <> Nil Then
    If CloseMsgArea(D) Then;
  CopyLastRead := Cnt;
  End;


Procedure DoArea(A: Word);
  Var
    Name, Src, Dst, Cut, Err, Tmp: String;
    N, Lr: LongInt;
    From: Char;

  Begin
  Name := Config^.GetMsgName(A);
  From := UpCase(Config^.GetMsgBaseType(A));
  Src := Config^.GetMsgAreaId(A);
  If Src = '' Then
    Begin
    WriteLn('area ', A, ' ', Name, ': REFUSED, the area has no base (its kind has no id here)');
    Failed := True;
    Exit;
    End;
  If From = UpCase(DestType) Then
    Begin
    If Not Quiet Then
      WriteLn('area ', A, ' ', Name, ': already ', KindName(From), ', left alone');
    Exit;
    End;
  Inc(TotalAreas);
  Tmp := '';
  If Dry Then
    Begin
    Tmp := Scratch(IntToStr(A));
    ForceDirectories(Tmp);
    Dst := DestId(A, Tmp);
    End
  Else
    Dst := DestId(A, '');
  If Dst = '' Then
    Begin
    WriteLn('area ', A, ' ', Name, ': REFUSED, the new kind has no base for this area');
    Failed := True;
    Exit;
    End;
  If (Not Dry) And (UpCase(DestType) <> 'H') Then
    ForceDirectories(ExtractFilePath(Copy(Dst, 2, 255)));
  N := Convert(A, Src, Dst, Cut, Err);
  If Dry And (Tmp <> '') Then
    RemoveTree(Tmp);
  If N < 0 Then
    Begin
    WriteLn('area ', A, ' ', Name, ': REFUSED, ', Err, ' (', Src, ' -> ', Dst, ')');
    Failed := True;
    Exit;
    End;
  Inc(TotalOk);
  Inc(TotalMsgs, N);
  If KeepMap And (Not Dry) Then
    WriteMap(A);
  Lr := CopyLastRead(Src, Dst, Not Dry);
  If Lr > 0 Then
    If UpCase(DestType) = 'Y' Then
      Cut := Cut + ', ' + IntToStr(Lr) + ' last-read pointer(s) dropped (Synchronet keeps none)'
    Else
      Cut := Cut + ', ' + IntToStr(Lr) + ' last-read pointer(s) ' + Copy('would be ', 1, 9 * Ord(Dry)) + 'moved';
  If Switch And (Not Dry) Then
    Begin
    Err := SwitchArea(A, Dst);
    If Err <> '' Then
      Begin
      WriteLn('area ', A, ' ', Name, ': copied and checked, but NOT switched: ', Err);
      Failed := True;
      End
    Else
      Cut := Cut + ', the area is ' + KindName(DestType) + ' in the configuration now';
    End;
  If Quiet And (Err = '') Then
    Exit;
  If Dry Then
    WriteLn('area ', A, ' ', Name, ': ', KindName(From), ' -> ', KindName(DestType), ', would copy ', N, ' message(s), the copy checked out', Cut)
  Else
    WriteLn('area ', A, ' ', Name, ': ', KindName(From), ' -> ', KindName(DestType), ', copied ', N, ' message(s) into ', Dst, ', checked', Cut);
  End;


Function InAreaList(A: Word): Boolean;
  Var
    i, p, Lo, Hi: Integer;
    T: String;

  Begin
  InAreaList := False;
  For i := 0 To AreaList.Count - 1 Do
    Begin
    T := AreaList[i];
    p := Pos('-', T);
    If p > 0 Then
      Begin
      Lo := StrToIntDef(Copy(T, 1, p - 1), -1);
      Hi := StrToIntDef(Copy(T, p + 1, 10), -1);
      If (A >= Lo) And (A <= Hi) Then
        InAreaList := True;
      End
    Else If StrToIntDef(T, -1) = A Then
      InAreaList := True;
    End;
  End;


Var
  i, k: Integer;
  A, S, ConfDir: String;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;

Begin
ConfDir := '';
AreaList := TStringList.Create;
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-n' Then Dry := True
  Else If A = '-v' Then Verbose := True
  Else If A = '-q' Then Quiet := True
  Else If A = '-f' Then Force := True
  Else If A = '-m' Then KeepMap := True
  Else If A = '-s' Then Switch := True
  Else If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else If A = '-a' Then
    Begin
    Inc(i);
    AreaList.Delimiter := ',';
    AreaList.StrictDelimiter := True;
    AreaList.DelimitedText := ParamStr(i);
    End
  Else If A = '-k' Then
    Begin
    Inc(i);
    S := UpCase(ParamStr(i));
    If (Length(S) <> 1) Or (Pos(S, 'HSFJMYEB') = 0) Then
      Die(1, '-k needs a kind: H S F J M Y E B');
    KindFilter := S[1];
    End
  Else If A = '-t' Then
    Begin
    Inc(i);
    S := UpCase(ParamStr(i));
    If (Length(S) <> 1) Or (Pos(S, 'HSFJMY') = 0) Then
      Die(1, '-t needs the new kind: H Hudson, S Squish, F Fido *.msg, J JAM, M Merlin, Y Synchronet');
    DestType := S[1];
    End
  Else If A = '-d' Then
    Begin
    Inc(i);
    FileIdOpt := ParamStr(i);
    End
  Else
    Begin
    WriteLn('usage: mkmsgconv [-c config dir] -a <areas> | -k <kind>  -t <kind>  [-d file id] [-n] [-s] [-m] [-f] [-v] [-q]');
    Halt(1);
    End;
  Inc(i);
  End;
If DestType = ' ' Then
  Die(1, 'say the new kind with -t (H S F J M Y)');
If (AreaList.Count = 0) And (KindFilter = ' ') Then
  Die(1, 'say which areas: -a 3,7,10-20 or -k <kind>');
If (ConfDir <> '') And (GetEnvironmentVariable('MK') <> ConfDir) Then
  Begin                                                    {-c names the configuration directory: this program starts again with MK set to it}
  Argv := TStringList.Create;
  Argv.Add(ParamStr(0));
  i := 1;
  While i <= ParamCount Do
    Begin
    If ParamStr(i) = '-c' Then
      Inc(i)
    Else
      Argv.Add(ParamStr(i));
    Inc(i);
    End;
  SetLength(PArgv, Argv.Count + 1);
  For i := 0 To Argv.Count - 1 Do
    PArgv[i] := PChar(Argv[i]);
  PArgv[Argv.Count] := Nil;
  SetLength(EnvP, GetEnvironmentVariableCount + 2);
  SetLength(EnvS, GetEnvironmentVariableCount + 2);
  k := 0;
  For i := 1 To GetEnvironmentVariableCount Do
    If Copy(GetEnvironmentString(i), 1, 3) <> 'MK=' Then
      Begin
      EnvS[k] := GetEnvironmentString(i);
      Inc(k);
      End;
  EnvS[k] := 'MK=' + ConfDir;
  Inc(k);
  For i := 0 To k - 1 Do
    EnvP[i] := PChar(EnvS[i]);
  EnvP[k] := Nil;
  fpExecve(ParamStr(0), PPChar(@PArgv[0]), PPChar(@EnvP[0]));
  Die(1, 'cannot start again with MK set');
  End;
BbsType := DetectBbsType;
Config := Nil;
Case BbsType Of
  1: Config := NewMKConfig(True);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Die(1, 'No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory, or use -c');
Config^.Load;
If Config^.GetError <> 0 Then
  Die(1, IntToStr(Config^.GetError) + ': Error loading config files');
If (Not Dry) And (Not Force) And (CallersOnLine <> '') Then
  Die(3, 'a caller is on line: ' + CallersOnLine + '.  The last-read pointers would be moved under the caller: run it in an exclusive event (-f: anyway)');
For i := 1 To Config^.GetMaxMsgAreas Do
  If Config^.GetMsgName(i) <> '' Then
    If ((KindFilter <> ' ') And (UpCase(Config^.GetMsgBaseType(i)) = KindFilter)) Or ((KindFilter = ' ') And InAreaList(i)) Then
      DoArea(i);
If TotalAreas = 0 Then
  Begin
  WriteLn('no area of that kind or number');
  Halt(1);
  End;
WriteLn(TotalMsgs, ' message(s) in ', TotalOk, ' of ', TotalAreas, ' area(s) ', Copy('would be ', 1, 9 * Ord(Dry)), 'converted to ', KindName(DestType), Copy(' (a dry run: nothing was written)', 1, 34 * Ord(Dry)),
  Copy('; the configuration is unchanged: set the kind and file id of the area in mkconfig to use the new base (or convert with -s)', 1, 120 * Ord(Not (Dry Or Switch))));
If Failed Then
  Halt(2);
End.
