Unit MKPlat;
{ MKPlat - platform shims for the MK units (Free Pascal).

  The original Turbo Pascal code called DOS interrupts (INT 21h) and used
  inline assembler for a handful of operations.  Those are collected here,
  implemented with portable FPC RTL calls, so the rest of the MK units are
  plain Pascal and every platform-specific decision lives in this one file.

  Targets: Unix (Linux/BSD/macOS) via BaseUnix, Windows via the Windows unit.
  The Windows branches are untested. }

{$MODE OBJFPC}
{$H-}

Interface

Const
  { Result codes of MKLockRegion - same values the DOS INT 21h/5Ch used }
  mkLockOk        = 0;
  mkLockBadHandle = 6;
  mkLockViolation = $21;   { somebody else holds the region }
  mkLockFailed    = 5;     { anything else }

Procedure MKDelay(Ms: Word);
  { Sleep for Ms milliseconds (replaces Crt.Delay without pulling in Crt) }

Function  MKLockRegion(Handle: THandle; Start, Len: LongInt; Lock: Boolean): Word;
  { Lock or unlock a byte range of an open file; returns an mkLock* code.
    Start and Len are treated as unsigned 32-bit values. }

Procedure MKFlushHandle(Handle: THandle);
  { Push buffered data for an open file out to the disk }

Function  MKHandleIsDevice(Handle: THandle): Boolean;
  { True when the open handle is a character device (console, /dev/null, ...) }

Function  MKHandlePos(Handle: THandle): Int64;
  { Current OS file position of Handle (ignores Pascal-level buffering),
    or -1 on error }

Function  MKFileStamp(Handle: THandle; Var Size, MTimeNs: Int64): Boolean;
  { Size and modification time (nanoseconds, as precise as the file system
    keeps it) of an open file; used to notice that another process changed it }

Function  MKProcessID: LongInt;

Function  MKTicks: Int64;
  { Milliseconds from a monotonic clock (only differences mean anything) }

Function  MKLocalUtcOffset: LongInt;
  { Minutes EAST of UTC for this computer's time zone right now }

Implementation

{$IFDEF UNIX}
Uses BaseUnix, Unix, SysUtils;
{$ELSE}
{$IFDEF WINDOWS}
Uses Windows, SysUtils;
{$ELSE}
{$ERROR MKPlat has no implementation for this platform}
{$ENDIF}
{$ENDIF}


Procedure MKDelay(Ms: Word);
  Begin
  Sleep(Ms);
  End;


Function MKProcessID: LongInt;
  Begin
  MKProcessID := LongInt(GetProcessID);
  End;


Function MKTicks: Int64;
  Begin
  MKTicks := Int64(GetTickCount64);
  End;


Function MKLocalUtcOffset: LongInt;
  Begin
  MKLocalUtcOffset := - GetLocalTimeOffset;   {SysUtils reports minutes WEST of UTC}
  End;


{$IFDEF UNIX}

Const
  { fcntl lock types - the FPC RTL defines these on BSD but not on Linux }
  {$IFDEF LINUX}
  LockRead   = 0;
  LockWrite  = 1;
  LockUnlock = 2;
  {$ELSE}
  LockRead   = 1;
  LockWrite  = 3;
  LockUnlock = 2;
  {$ENDIF}

Function MKLockRegion(Handle: THandle; Start, Len: LongInt; Lock: Boolean): Word;
  Var
    FL: FLock;
    Res: cint;
    Err: cint;

  Begin
  If Len = 0 Then
    Begin
    MKLockRegion := mkLockOk;
    Exit;
    End;
  FillChar(FL, SizeOf(FL), 0);
  If Lock Then
    FL.l_type := LockWrite
  Else
    FL.l_type := LockUnlock;
  FL.l_whence := SEEK_SET;
  FL.l_start := Cardinal(Start);   {offsets are unsigned 32-bit, as under DOS;
  FL.l_len := Cardinal(Len);        e.g. MKMsgMer locks the byte at $FFFFFFFF}
  Res := fpFcntl(Handle, F_SETLK, FL);
  If (Res <> 0) And Lock And (fpGetErrno = ESysEBADF) Then
    Begin
    { A write lock needs a handle open for writing; DOS allowed locks on
      read-only handles, so fall back to a shared lock. }
    FL.l_type := LockRead;
    Res := fpFcntl(Handle, F_SETLK, FL);
    End;
  If Res = 0 Then
    MKLockRegion := mkLockOk
  Else
    Begin
    Err := fpGetErrno;
    If (Err = ESysEAGAIN) Or (Err = ESysEACCES) Then
      MKLockRegion := mkLockViolation
    Else If Err = ESysEBADF Then
      MKLockRegion := mkLockBadHandle
    Else
      MKLockRegion := mkLockFailed;
    End;
  End;


Procedure MKFlushHandle(Handle: THandle);
  Begin
  fpFsync(Handle);
  End;


Function MKHandleIsDevice(Handle: THandle): Boolean;
  Var
    St: Stat;

  Begin
  If fpFstat(Handle, St) = 0 Then
    MKHandleIsDevice := fpS_ISCHR(St.st_mode)
  Else
    MKHandleIsDevice := False;
  End;


Function MKHandlePos(Handle: THandle): Int64;
  Begin
  MKHandlePos := fpLseek(Handle, 0, SEEK_CUR);
  End;


Function MKFileStamp(Handle: THandle; Var Size, MTimeNs: Int64): Boolean;
  Var
    St: Stat;

  Begin
  MKFileStamp := False;
  If fpFstat(Handle, St) = 0 Then
    Begin
    Size := St.st_size;
    MTimeNs := Int64(St.st_mtime) * 1000000000 + Int64(St.st_mtime_nsec);
    MKFileStamp := True;
    End;
  End;

{$ELSE}  { Windows }

Function MKLockRegion(Handle: THandle; Start, Len: LongInt; Lock: Boolean): Word;
  Var
    Ok: Boolean;

  Begin
  If Len = 0 Then
    Begin
    MKLockRegion := mkLockOk;
    Exit;
    End;
  If Lock Then
    Ok := Windows.LockFile(Handle, DWORD(Start), 0, DWORD(Len), 0)
  Else
    Ok := Windows.UnlockFile(Handle, DWORD(Start), 0, DWORD(Len), 0);
  If Ok Then
    MKLockRegion := mkLockOk
  Else
    Case GetLastError Of
      ERROR_LOCK_VIOLATION: MKLockRegion := mkLockViolation;
      ERROR_INVALID_HANDLE: MKLockRegion := mkLockBadHandle;
      Else MKLockRegion := mkLockFailed;
      End;
  End;


Procedure MKFlushHandle(Handle: THandle);
  Begin
  FlushFileBuffers(Handle);
  End;


Function MKHandleIsDevice(Handle: THandle): Boolean;
  Begin
  MKHandleIsDevice := (GetFileType(Handle) = FILE_TYPE_CHAR);
  End;


Function MKHandlePos(Handle: THandle): Int64;
  Begin
  MKHandlePos := FileSeek(Handle, Int64(0), 1);
  End;


Function MKFileStamp(Handle: THandle; Var Size, MTimeNs: Int64): Boolean;
  Var
    FT: FILETIME;
    Hi: DWORD;
    Lo: DWORD;

  Begin
  MKFileStamp := False;
  Lo := GetFileSize(Handle, @Hi);
  If (Lo = DWORD(-1)) And (GetLastError <> NO_ERROR) Then
    Exit;
  Size := (Int64(Hi) Shl 32) Or Lo;
  If GetFileTime(Handle, Nil, Nil, @FT) Then
    Begin
    MTimeNs := ((Int64(FT.dwHighDateTime) Shl 32) Or FT.dwLowDateTime) * 100;
    MKFileStamp := True;
    End;
  End;

{$ENDIF}

End.
