Unit MKOffQwk;       {QWK Offline mail Object}

{$I MKB.Def}

{
     MKOffQwk - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}


Interface

Uses MKGlobT, MKMsgAbs, MKOffAbs,
  Dos;


Const QIdxSize = 3000;
Const QwkBufSize = 150;
Const MaxQwkPers = 300;
Const QwkConfs = 2000;

Type QwkIdxType = Record
  QwkPtr: LongInt;
  MsgConf: Byte;
  End;


Type QwkImportRec = Record
  SeekPos: LongInt;
  Area: Word;
  End;


Type QwkRecType = Array[1..128] of Char;
Type QwkBufType = Array[0..QwkBufSize] of QwkRecType;
Type PersArray = Array[1..MaxQwkPers] of QwkIdxType;
Type QwkIdxArray = Array[1..QIdxSize] of QwkIdxType;
Type QwkAreaType = Array[1..QIdxSize] of Word;
Type QwkImportIdx = Array[1..QIdxSize] of QwkImportRec;


Type QwkInfo = Record
  MsgPath: String;
  NumMsgs: Word;
  QwkWorkNum: LongInt;
  PersExported: Word;
  ConfExported: Array[1..QwkConfs] of Word;
  ConfImported: Array[1..QwkConfs] of Boolean;
  NumExported: Word;
  BufStart: LongInt;     {Record number of first record in buffer}
  QwkNumRead: Integer;   {Number of read records in the buffer}
  NeedWritten: Array[0..QwkBufSize] of Boolean; {buffer needs written}
  QwkFile: File;         {QWK/REP file}
  QwkError: Word;        {Status from QWK file activity}
  QwkCurrPos: Word;      {Current char within QwkRec}
  ReplyMsgs: Word;       {number of msgs in reply packet}
  BBSId: String[8];
  End;


Type QwkOffObj = Object(AbsOffObj)
  QwkBuf: ^QwkBufType;   {Qwk record buffer}
  CQwkRec: ^QwkRecType;  {Active Qwk record pointer}
  QI: ^QwkInfo;
  Pers: ^PersArray;
  MsgExport: ^QwkIdxArray;
  QwkArea: ^QwkAreaType;
  QwkIn: ^QwkImportIdx;
  Constructor Init; {Initialize}
  Destructor Done; Virtual; {Done}
  Procedure SetPath(MP: String); Virtual; {Set msg path/other info}
  Procedure SetBBSID(ID: String); Virtual; {Set bbs id/filename}
  Function  StartPacket: Word; Virtual; {Do Packet startup tasks}
  Function  ClosePacket: Word; Virtual; {Do Packet finish tasks}
  Function  AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean; Virtual;
  Function  GetArchiveName(Packer: Word): String; Virtual;
  Function  GetReplyName: String; Virtual;
  Function  GetExtractSpec: String; Virtual;
  Procedure PutHdrStr(St: String; Loc: Word);
  Procedure PutStr(Var St: String);
  Function  GetHdrStr(Start:Integer; NumChar:Integer):String;
  Procedure PersIdx;
  Procedure DoIdx;
  Procedure DoControl;
  Procedure WriteDoorId;
  Procedure SetNeedWritten(QN: LongInt);
  Procedure FlushQwkBuf;
  Procedure SetCQwkRec(QN: LongInt);
  Procedure BuildIndex; {build index of areas/msgs from rep packet}
  Procedure ImportPacket; Virtual;
  End;


Type QwkOffPtr = ^QwkOffObj;


Implementation


Uses MKString, MKFile, MKCfgAbs, MKUsrAbs, MKDos, MKQwkG;


Function Bas2Lng(InValue: LongInt): LongInt;
  Var
    Temp: LongInt;
    Negative: Boolean;
    Expon: Integer;

  Begin
    If InValue And $00800000 <> 0 Then
      Negative := True
    Else
      Negative := False;
    Expon := InValue shr 24;
    Expon := Expon and $ff;
    Temp := InValue and $007FFFFF;
    Temp := Temp or $00800000;
    Expon := Expon - 152;
    If Expon < 0 Then Temp := Temp shr Abs(Expon)
      Else Temp := Temp shl Expon;
    If Negative Then
      Bas2Lng := -Temp
    Else
      Bas2Lng := Temp;
    If Expon = 0 Then
      Bas2Lng := 0;
  End;


Function Lng2Bas(InValue: LongInt): LongInt;
  Var
    Negative: Boolean;
    Expon: LongInt;

  Begin
  If InValue = 0 Then
    Lng2Bas := 0
  Else
    Begin
    If InValue < 0 Then
      Begin
      Negative := True;
      InValue := Abs(InValue);
      End
    Else
      Negative := False;
    Expon := 152;
    If InValue < $007FFFFF Then
      While ((InValue and $00800000) = 0) Do
        Begin
        InValue := InValue shl 1;
        Dec(Expon);
        End
    Else
      While ((InValue And $FF000000) <> 0) Do
        Begin
        InValue := InValue shr 1;
        Inc(Expon);
        End;
    InValue := InValue And $007FFFFF;
    If Negative Then
      InValue := InValue Or $00800000;
    Lng2Bas := InValue + (Expon shl 24);
    End;
  End;


Constructor QwkOffObj.Init;
  Begin
  New(QI);
  End;


Destructor QwkOffObj.Done;
  Begin
  Dispose(QI);
  End;


Procedure QwkOffObj.SetPath(MP: String);
  Begin
  QI^.MsgPath := WithBackSlash(MP);
  End;


Procedure QwkOffObj.SetNeedWritten(QN: LongInt);
  Var
    BC: LongInt;

  Begin
  BC := Qn - QI^.BufStart;
  If ((BC >= 0) and (BC <= QwkBufSize)) Then
    QI^.NeedWritten[BC] := True;
  End;


Procedure QwkOffObj.FlushQwkBuf;
  Var
    i: Integer;

  Begin
  i := QwkBufSize;
  While ((Not QI^.NeedWritten[i]) and (i >= 0)) Do
    Dec(i);
  Inc(i);
  If i > 0 Then
    Begin
    Seek(QI^.QwkFile, QI^.BufStart);
    QI^.QwkError := IoResult;
    If QI^.QwkError = 0 Then
      Begin
      BlockWrite(QI^.QwkFile, QwkBuf^, i);
      QI^.QwkError := IoResult;
      End;
    QI^.BufStart := -3000;
    For i := 0 to QwkBufSize Do
      QI^.NeedWritten[i] := False;
    End;
  End;


Procedure QwkOffObj.SetCQwkRec(QN: LongInt);
  Var
    i: Word;

  Begin
  QI^.QwkError := 0;
  If ((QN >= QI^.BufStart) and (Qn < (QI^.BufStart + QwkBufSize))) Then
    CQwkRec := @QwkBuf^[QN - QI^.BufStart]
  Else
    Begin
    FlushQwkBuf;
    QI^.BufStart := Qn;
    Seek(QI^.QwkFile, QI^.BufStart);
    QI^.QwkError := IoResult;
    If QI^.QwkError = 0 Then
      Begin
      BlockRead(QI^.QwkFile, QwkBuf^, QwkBufSize, QI^.QwkNumRead);
      QI^.QwkError := IoResult;
      End;
    For i := 0 to QwkBufSize Do
      QI^.NeedWritten[i] := False;
    CQwkRec := @QwkBuf^[0];
    End;
  End;


Procedure QwkOffObj.PutHdrStr(St: String; Loc: Word);
  Var
    i: Word;

  Begin
  For i := 1 to Length(St) Do
    CQwkRec^[Loc + i - 1] := St[i];
  End;


Function QwkOffObj.GetHdrStr(Start:Integer; NumChar:Integer):String;
  Var
    TempStr: String;
    I: Integer;
    Count: Integer;

  Begin
  If ((Start + NumChar) > 129) Then
    NumChar := 129 - Start;
  TempStr := '';
  Count := 0;
  I := Start;
  While Count < NumChar Do
    Begin
    TempStr[Count + 1] := CQwkRec^[Start + Count];
    Inc(Count);
    End;
  TempStr[0] := Chr(NumChar);
  GetHdrStr := TempStr;
  End;



Procedure QwkOffObj.PutStr(Var St: String);
  Var
    i: Word;

  Begin
  For i := 1 to Length(St) Do
    Begin
    Inc(QI^.QwkCurrPos);
    If QI^.QwkCurrPos > 128 Then
      Begin
      Inc(QI^.QwkWorkNum);
      QI^.QwkCurrPos := 1;
      SetCQwkRec(QI^.QwkWorkNum);
      SetNeedWritten(QI^.QwkWorkNum);
      End;
    CQwkRec^[QI^.QwkCurrPos] := St[i];
    End;
  End;



Function QwkOffObj.AddMsg(Var Msg: AbsMsgObj; Area: Word; ToYou: Boolean): Boolean;
  Const
    StrLen = 72;

  Var
    TmpStr: String;
    i: Word;
    MsgStartQwk: LongInt;
    Crc: LongInt;
    TAddr: AddrType;

  Begin
  If QI^.NumExported < QIdxSize Then
    Begin
    Inc(QI^.QwkWorkNum);
    SetCQwkRec(QI^.QwkWorkNum);
    MsgStartQwk := QI^.QwkWorkNum;
    If ((ToYou) and (QI^.PersExported < MaxQwkPers)) Then
      Begin
      Inc(QI^.PersExported);
      Pers^[QI^.PersExported].MsgConf := Area and $ff;
      Pers^[QI^.PersExported].QwkPtr := MsgStartQwk;
      End;
    Inc(QI^.NumExported);
    Inc(QI^.ConfExported[Area]);
    MsgExport^[QI^.NumExported].QwkPtr := MsgStartQwk;
    MsgExport^[QI^.NumExported].MsgConf := Area and $ff;
    QwkArea^[QI^.NumExported] := Area;
    SetNeedWritten(QI^.QwkWorkNum);
    QI^.QwkCurrPos := 129;
    FillChar(CQwkRec^, SizeOf(QwkRecType), ' ');
    If Msg.IsRcvd Then
      Begin
      If Msg.IsPriv Then
        CQwkRec^[1] := '*'
      Else
        CQwkRec^[1] := '-'
      End
    Else
      Begin
      If Msg.IsPriv Then
        CQwkRec^[1] := '+'
      Else
        CQwkRec^[1] := ' '
      End;
    TmpStr := PadRight(Copy(Long2Str(Msg.GetMsgNum),1,7),' ',7); {msg num}
    PutHdrStr(TmpStr, 2);
    PutHdrStr(Msg.GetDate, 9);
    PutHdrStr(Copy(Msg.GetTime, 1, 5), 17);
    PutHdrStr(Upper(Copy(Msg.GetTo, 1, 25)), 22);
    PutHdrStr(Upper(Copy(Msg.GetFrom, 1, 25)), 47);
    If Config^.GetMsgType(Area) = NetMail Then
      Begin
      Msg.GetOrig(TAddr);
      PutHdrStr('@' + AddrStr(TAddr),72);
      End
    Else
      PutHdrStr(Copy(Msg.GetSubj, 1, 25), 72);
    PutHdrStr(PadRight(Copy(Long2Str(Msg.GetRefer),1,8),' ',8), 109);
    CQwkRec^[123] := #225;
    CQwkRec^[124] := Chr(Lo(Area));
    CQwkRec^[125] := Chr(Area shr 8);
    CQwkRec^[128] := ' ';
    Msg.MsgTxtStartUp;
    If Config^.GetMsgType(Area) = NetMail Then
      Begin
      TmpStr := 'Subj: ' + Msg.GetSubj;
      PutStr(TmpStr);
      End;
    TmpStr := Msg.GetString(StrLen);
    TmpStr[0] := Chr(Length(TmpStr) + 1);
    TmpStr[Length(TmpStr)] := #227;
    While (Not Msg.EOM) or (Length(TmpStr) > 1) Do
      Begin
      If (TmpStr[1] <> #1) Then
        PutStr(TmpStr);
      TmpStr := Msg.GetString(StrLen);
      TmpStr[0] := Chr(Length(TmpStr) + 1);
      TmpStr[Length(TmpStr)] := #227;
      End;
    If QI^.QwkCurrPos < 128 Then
      Begin
      For i := QI^.QwkCurrPos + 1 to 128 Do
      CQwkRec^[i] := ' ';
      End;
    SetCQwkRec(MsgStartQwk);
    PutHdrStr(PadRight(Long2Str(QI^.QwkWorkNum + 1 - MsgStartQwk),' ',6),117);
    SetNeedWritten(MsgStartQwk);
    SetCQwkRec(QI^.QwkWorkNum);
    AddMsg := True;
    End
  Else
    AddMsg := False;
  End;


Function QwkOffObj.GetArchiveName(Packer: Word): String;
  Begin
  GetArchiveName := QI^.BBSID + '.QWK';
  End;


Procedure QwkOffObj.PersIdx;
  Var
    i: Word;
    PersFile: File;

  Begin
  If QI^.PersExported > 0 Then
    Begin
    For i := 1 to QI^.PersExported Do
      Pers^[i].QwkPtr := Lng2Bas(Pers^[i].QwkPtr + 1);
    Assign(PersFile, ResolveCase(QI^.MsgPath + 'PERSONAL.NDX'));
    ReWrite(PersFile, 5);
    BlockWrite(PersFile, Pers^, QI^.PersExported);
    Close(PersFile);
    If IoResult <> 0 Then;
    End;
  End;



Procedure QwkOffObj.WriteDoorId;
  Var
    CFile: Text;
    i: Word;
    Ext: String[4];
    TempStr: String;

  Begin
  If IoResult <> 0 Then;
  Assign (CFile, ResolveCase(QI^.MsgPath + 'DOOR.ID'));
  ReWrite(CFile);
  WriteLn(CFile, 'DOOR = MKQwk');
  WriteLn(CFile, 'VERSION = 1.1');
  WriteLn(CFile, 'SYSTEM = Mythical Kingdom');
  WriteLn(CFile, 'CONTROLNAME = MKQWK');
  WriteLn(CFile, 'CONTROLTYPE = ADD');
  WriteLn(CFile, 'CONTROLTYPE = DROP');
  WriteLn(CFile, 'CONTROLTYPE = RESET');
  WriteLn(CFile, 'CONTROLTYPE = BLTS');
  WriteLn(CFile, 'CONTROLTYPE = FILES');
  WriteLn(CFile, 'CONTROLTYPE = NEWS');
  Close(CFile);
  If IoResult <> 0 Then;
  End;


Procedure QwkOffObj.DoControl;
  Var
    CF: Text;
    NumAvail: Word;
    Sec: SecType;
    i: Word;

  Begin
  If IoResult <> 0 Then;
  FileMode := fmReadWrite + fmDenyNone;
  Assign(CF, ResolveCase(QI^.MsgPath + 'Control.Dat'));
  ReWrite(CF);
  If IoResult <> 0 Then;
  WriteLn(CF, Config^.GetBBSName);
  WriteLn(CF, Config^.GetBBSLoc);
  WriteLn(CF, Config^.GetBBSPhone);
  WriteLn(CF, Upper(Config^.GetSysopName) + ',Sysop');
  WriteLn(CF, '0 ,' + QCfg.BoardId);
  WriteLn(CF, FormattedDosDate(GetDosDate,'MM-DD-YYYY,') + TimeStr(GetDosDate));
  WriteLn(CF, Upper(User^.GetUserName));
  WriteLn(CF);
  WriteLn(CF,'0');
  WriteLn(CF,'0');
  User^.GetUserSec(@Sec);
  NumAvail := 0;
  For i := 1 to QwkConfs Do
    Begin
    If Config^.MsgReadAccess(i, Sec) Then
      Inc(NumAvail);
    End;
  WriteLn(CF,NumAvail);
  WriteLn(CF, '0');
  WriteLn(CF, 'Area 0');
  For i := 1 to QwkConfs Do
    Begin
    If Config^.MsgReadAccess(i, Sec) Then
      Begin
      WriteLn(CF, i);
      WriteLn(CF, Config^.GetMsgShortName(i));
      End;
    End;
  WriteLn(CF, 'Welcome.Ans');
  WriteLn(CF, 'News.Ans');
  WriteLn(CF, 'GoodBye.Ans');
  WriteLn(CF, '0');
  WriteLn(CF, User^.GetUserScrLength);
  WriteLn(CF, Upper(User^.GetUserName));
  WriteLn(CF, ExtractWord(User^.GetUserName, 1));
  WriteLn(CF, User^.GetUserCity);
  WriteLn(CF, User^.GetUserDataPhone);
  WriteLn(CF, User^.GetUserVoicePhone);
  WriteLn(CF, User^.GetUserSecLevel);
  WriteLn(CF, '00-00-00'); {expire date}
  WriteLn(CF, DateStr(GetDosDate));
  WriteLn(CF, TimeStr(GetDosDate));
  WriteLn(CF, User^.GetUserTimesCalled);
  If IoResult <> 0 Then;
  Close(CF);
  If IoResult <> 0 Then;
  End;


Procedure QwkOffObj.DoIdx;
  Var
    i: Word;
    IdxPointer: Word;
    OrgPointer: Word;
    IdxFile: File;
    FileStr: String;
    QwkIdx: ^QwkIdxArray;

  Begin
  If QI^.PersExported > 0 Then
    PersIdx;
  New(QwkIdx);
  If QwkIdx <> Nil Then
    Begin
    For i := 1 to QwkConfs do
      Begin
      If QI^.ConfExported[i] > 0 Then
        Begin
        IdxPointer := 0;
        FileStr := ConCat(QI^.MsgPath, PadLeft(Long2Str(i),'0',3),'.NDX');
        Assign(IdxFile, ResolveCase(FileStr));
        ReWrite(IdxFile,SizeOf(QwkIdxType));
        For OrgPointer := 1 to QI^.NumExported Do
          Begin
          If QwkArea^[OrgPointer] = i Then
            Begin
            Inc(IdxPointer);
            QwkIdx^[IdxPointer].MsgConf := i and $ff;
            QwkIdx^[IdxPointer].QwkPtr := Lng2Bas(MsgExport^[OrgPointer].QwkPtr + 1);
            End;
          End;
        BlockWrite(IdxFile, QwkIdx^, IdxPointer);
        Close(IdxFile);
        If Ioresult <> 0 Then;
        End;
      End;
    Dispose(QwkIdx);
    End;
  End;



Function QwkOffObj.StartPacket: Word;
  Var
    i: Word;
    QError: Word;

  Begin
  New(QwkBuf);
  New(Pers);
  New(MsgExport);
  New(QwkArea);
  If (QwkBuf=Nil) or (QI=Nil) or (Pers=Nil) or (MsgExport=Nil) or (QwkArea=Nil) Then
    QError := 1000
  Else
    QError := 0;
  IF QError = 0 Then
    Begin
    QI^.PersExported := 0;
    Assign(QI^.QwkFile, ResolveCase(QI^.MsgPath + 'Messages.Dat'));
    ReWrite(QI^.QwkFile, 128);
    If IoResult <> 0 Then
      QError := 1001;
    End;
  If QError = 0 Then
    Begin
    QI^.BufStart := -1000;
    QI^.QwkNumRead := 0;
    For i := 0 to QwkBufSize Do
    QI^.NeedWritten[i] := False;
    QI^.QwkWorkNum := 0;
    SetCQwkRec(QI^.QwkWorkNum);
    FillChar(CQwkRec^, SizeOf(QwkRecType), ' ');
    PutHdrStr('Produced by Mythical Kingdom Software - Copyright Mark May', 1);
    SetNeedWritten(0);
    For i := 1 to QwkConfs Do
      QI^.ConfExported[i] := 0;
    QI^.NumExported := 0;
    End;
  StartPacket :=  QError;
  End;


Function QwkOffObj.ClosePacket: Word;
  Begin
  FlushQwkBuf;
  Close(QI^.QwkFile);
  ClosePacket := IoResult;
  DoIdx;
  DoControl;
  WriteDoorId;
  Dispose(Pers);
  Dispose(QwkArea);
  Dispose(MsgExport);
  Dispose(QwkBuf);
  End;


Function QwkOffObj.GetReplyName: String;
  Begin
  GetReplyName := QI^.BBSID + '.REP';
  End;


Function QwkOffObj.GetExtractSpec: String;
  Begin
  GetExtractSpec := QI^.BBSID + '.MSG';
  End;


Procedure QwkOffObj.BuildIndex;
  Type CharSet = Set of Char;
  Var
    i: Word;
    MaxNum: LongInt;
    NumBlocks: LongInt;
    LastMsgEnd: LongInt;
    QwkWorkNum: LongInt;

  Const
    DateSep = ['-','/', #196];

  Begin
  LastMsgEnd := 0;
  QI^.ReplyMsgs := 0;
  For i := 0 To QwkConfs Do
    QI^.ConfImported[i] := False;
  MaxNum := FileSize(QI^.QwkFile);
  QwkWorkNum := 1;
  While (QwkWorkNum <= MaxNum) Do
    Begin
    SetCQwkRec(QwkWorkNum);
    If ((CQwkRec^[11] in DateSep) and (CQwkRec^[14] in DateSep) and
    (CQwkRec^[19] = ':')) Then
      Begin
      Inc(QI^.ReplyMsgs);
      QwkIn^[QI^.ReplyMsgs].Area := Ord(CQwkRec^[124]);
      If CQwkRec^[125] <> ' ' Then
      Inc(QwkIn^[QI^.ReplyMsgs].Area, (Word(Ord(CQwkRec^[125])) * 256));
      QI^.ConfImported[QwkIn^[QI^.ReplyMsgs].Area] := True;
      QwkIn^[QI^.ReplyMsgs].SeekPos := QwkWorkNum;
      NumBlocks := Str2Long(StripBoth(GetHdrStr(117, 6),' '));
      If NumBlocks < 1 Then
        NumBlocks := 1;
      Inc(QwkWorkNum, NumBlocks);
      LastMsgEnd := QwkWorkNum - 1;
      End
    Else
      Begin
      NumBlocks := 1;
      Inc(QwkWorkNum, NumBlocks);
      End;
    End;
  End;



Procedure QwkOffObj.ImportPacket;
  Begin
  New(QwkIn);
  {** open file **}
  BuildIndex;
  {** toss mail **}
  {** close file **}
  Dispose(QwkIn);
  End;


Procedure QwkOffObj.SetBBSId(ID: String);
  Begin
  QI^.BBSId := Id;
  End;


End.
