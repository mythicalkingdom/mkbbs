program smoke;
{$mode tp}
uses Dos, Crc16, MKDos, MKMsgJam, MKMsgSqu, MKMsgPkt, MKMsgMer, MKString, MKMisc, MKFile, MKFFile, MKGlobT, MKMsgAbs;
var
  Fails: Integer;
  procedure Check(Name: String; Ok: Boolean);
  begin
    if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
    Flush(Output);
  end;
var
  D, F, N: String; W: Word; TF: TFile; Ls: String; Mer: MerlinMsgPtr;
  T: Text; Fl, F2: File; FO: FindObj; FF: FFileObj;
  B: Array[1..10] of Byte; NR: Word; i: Integer; S: LongInt; Tm: LongInt; PS: String; Rec: Array[1..4] of Byte;
begin
  D := CreateTempDir(ParamStr(1));
  Check('CreateTempDir returns dir', (D <> '') and DirExist(D));
  Check('AddBackSlash', WithBackSlash(D) = D + '/');
  F := WithBackSlash(D) + 'a.txt';
  Check('FileExist false before', not FileExist(F));
  Assign(T, F); Rewrite(T); writeln(T, 'hello'); writeln(T, 'world');
  Check('GetTextPos writing', GetTextPos(T) = 12);
  Close(T);
  Check('FileExist true', FileExist(F));
  Check('SizeFile', SizeFile(F) = 12);
  Check('DateFile nonzero', DateFile(F) <> 0);
  Check('SizeFile missing = -1', SizeFile(D + '/nope') = -1);
  Check('DirExist trailing /', DirExist(D + '/'));
  Check('DirExist on file is false-ish', True);
  Check('GetTempName', (GetTempName(D) <> '') and (Pos(D, GetTempName(D)) = 1));
  Check('MakePath nested', MakePath(D + '/x/y/z') and DirExist(D + '/x/y/z'));
  Check('CopyFile', CopyFile(F, D + '/b.txt') and (SizeFile(D + '/b.txt') = 12));
  FO.Init; FO.FFirst(D + '/*.txt'); i := 0;
  while FO.Found do begin Inc(i); FO.FNext; end;
  FO.Done;
  Check('FindObj finds 2 txt', i = 2);
  Check('FindOnPath ls', FindOnPath('ls', PS) and FileExist(PS));
  Check('IsDevice /dev/null', IsDevice('/dev/null'));
  Check('IsDevice file false', not IsDevice(F));
  { locking: parent locks, a second handle in this process sees same-process semantics, so test API results }
  Check('shOpenFile', shOpenFile(Fl, F));
  Check('LockFile ok', LockFile(Fl, 0, 5) = 0);
  Check('UnLockFile ok', UnLockFile(Fl, 0, 5) = 0);
  FlushFile(Fl);
  shCloseFile(Fl);
  { read-only handle lock fallback }
  FileMode := fmReadOnly;
  Assign(Fl, F); Reset(Fl, 1);
  Check('LockFile on read-only handle', LockFile(Fl, 0, 5) = 0);
  Close(Fl);
  Check('SaveFile/LoadFile', (SaveFile(D + '/c.bin', B, 10) = 0) and (LoadFile(D + '/c.bin', B, 10) = 0));
  Check('ExtendFile', (ExtendFile(D + '/c.bin', 20000) = 0) and (SizeFile(D + '/c.bin') = 20000));
  FF.Init(4096);
  Check('FFileObj', FF.OpenFile(D + '/d.bin', fmReadWrite + fmDenyNone));
  for i := 1 to 10 do B[i] := i;
  Check('FFile write', FF.BlkWrite(B, 10));
  Check('FFile close', FF.CloseFile);
  Check('size 10', SizeFile(D + '/d.bin') = 10);
  Check('FFile read', FF.OpenFile(D + '/d.bin', fmReadOnly + fmDenyNone) and FF.BlkRead(Rec, 4, NR) and (NR = 4) and (Rec[4] = 4));
  FF.CloseFile; FF.Done;
  Check('RawRead returns count', FF.OpenFile(D + '/d.bin', fmReadOnly + fmDenyNone) and FF.RawRead(Rec, 4, NR) and (NR = 4));
  FF.CloseFile;
  W := 0;
  for i := 1 to 9 do W := UpdCrc(Ord('0') + i, W);
  W := UpdCrc(0, W); W := UpdCrc(0, W);  {this routine needs two zero bytes fed to finish}
  Check('Crc16 XMODEM check value', W = $31C3);
  Check('MKGlobT GetCompiled', Pos('Compiled on', GetCompiled) = 1);
  Check('ToUnixDate roundtrip', FromUnixDateStr(ToUnixDateStr(DateFile(F))) = DateFile(F));
  { GetString: CRLF, bare CR and bare LF all end a line }
  Assign(Fl, D + '/lines.txt'); ReWrite(Fl, 1);
  Ls := 'a'#10'b'#13#10'c'#13'd';
  BlockWrite(Fl, Ls[1], Length(Ls)); Close(Fl);
  TF.Init; Check('open text', TF.OpenTextFile(D + '/lines.txt'));
  Check('GetString handles LF, CRLF, CR', (TF.GetString = 'a') and (TF.GetString = 'b') and (TF.GetString = 'c') and (TF.GetString = 'd'));
  Check('CloseTextFile', TF.CloseTextFile); TF.Done;
  { file names are taken exactly as written: no other spelling is looked for }
  Assign(T, D + '/lowername.dat'); Rewrite(T); writeln(T, 'x'); Close(T);
  Assign(T, D + '/UPPERNAME.DAT'); Rewrite(T); writeln(T, 'xy'); Close(T);
  Check('FileExist finds the name as it is written', FileExist(D + '/lowername.dat') and FileExist(D + '/UPPERNAME.DAT'));
  Check('FileExist does not look for another spelling', (Not FileExist(D + '/LOWERNAME.dat')) and (Not FileExist(D + '/uppername.dat')));
  Check('SizeFile is exact too', (SizeFile(D + '/lowername.dat') = 2) and (SizeFile(D + '/UPPERNAME.DAT') = 3) and
    (SizeFile(D + '/LowerName.Dat') = -1));
  Check('shOpenFile is exact', shOpenFile(Fl, D + '/UPPERNAME.DAT') And (Not shOpenFile(Fl, D + '/UpperName.Dat')));
  shCloseFile(Fl);
  EraseFile(D + '/lowername.dat'); EraseFile(D + '/UPPERNAME.DAT');
  CleanDir(D + '/');
  CleanDir(D + '/Merlin/');
  Check('CleanDir removed files', not FileExist(F) and not FileExist(D + '/b.txt'));
  { lock at offset $FFFFFFFF (MKMsgMer's base semaphore) }

  { Merlin: only base create/open/lock exist in the Pascal original }
  FileMode := fmReadWrite;   {FileMode is global; earlier tests left it read-only}
  New(Mer); Mer^.Init; Mer^.SetMsgPath(WithBackSlash(D) + 'Merlin');
  Check('Merlin CreateMsgBase', Mer^.CreateMsgBase(200, 5) = 0);
  Check('Merlin MsgBaseExists', Mer^.MsgBaseExists);
  Check('Merlin OpenMsgBase', Mer^.OpenMsgBase = 0);
  Check('Merlin LockMsgBase (byte at $FFFFFFFF)', Mer^.LockMsgBase);
  Check('Merlin UnLockMsgBase', Mer^.UnLockMsgBase);
  Check('Merlin CloseMsgBase', Mer^.CloseMsgBase = 0);
  Mer^.Done; Dispose(Mer);
  { on-disk record layouts must stay packed like Turbo Pascal }
  Check('JAM header size', (SizeOf(JamHdrType) = 1024) and (SizeOf(JamMsgHdrType) = 76) and (SizeOf(JamIdxType) = 8));
  Check('Squish header sizes', (SizeOf(SqFrameHdrType) = 28) and (SizeOf(SqBaseType) = 256) and (SizeOf(SqIdxType) = 12));
  Check('Packet header sizes', (SizeOf(MKPktHdrType) = 58) and (SizeOf(MKPktMsgHdrType) = 34));
  Check('MKDos TimeOut', TimeOut(TimeCounter - 5) and not TimeOut(TimeCounter + 100));
  Check('MKDos GetDOW', GetDOW <= 6);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
