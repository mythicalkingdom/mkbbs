Unit MKTarGz;        {tar archives (ustar) inside gzip: written and read here, nothing else is needed to make or open a backup}

{$mode objfpc}{$H+}

{
     TTarWriter makes name.tar.gz: AddFile copies a file from the disk (the checksum, SHA-1, and the size are returned as the data goes by), AddText makes a small text file.
     TTarReader goes through an archive entry by entry: Next gives the next name, size, mode and time, ReadData the bytes of the entry (Skip drops what is left of it).
     The names are stored without a leading slash; a name that does not fit the 100 + 155 characters of the ustar header is refused.  Archives made by tar and gzip are read too
     (regular files only; links and directories are skipped).
}

Interface

Uses SysUtils, Classes, zstream, BaseUnix;

Type
  TTarWriter = class
    private
      GZ: TGZFileStream;
      Failed: Boolean;
      procedure PutHeader(const Name: String; Size: Int64; Mode: LongInt; MTime: Int64);
    public
      Err: String;
      constructor Create(const FileName: String);
      function AddFile(const DiskPath, ArcName: String; var Sha: String; var Size: Int64): Boolean;
      function AddText(const ArcName, Text: String): Boolean;
      function Close: Boolean;
      destructor Destroy; override;
    end;

  TTarReader = class
    private
      GZ: TGZFileStream;
      Left, Pad: Int64;
    public
      Name: String;
      Size: Int64;
      Mode: LongInt;
      MTime: Int64;
      Err: String;
      constructor Create(const FileName: String);
      function Next: Boolean;                          {the next regular file; False at the end (Err is '' then) or when the archive is damaged}
      function ReadData(var Buf; N: LongInt): LongInt; {up to N bytes of the entry; 0 at its end}
      procedure Skip;
      destructor Destroy; override;
    end;

Function Sha1OfFile(const FileName: String; var Hex: String): Boolean;


Implementation

Uses sha1;

Const
  Blk = 512;


function Sha1OfFile(const FileName: String; var Hex: String): Boolean;
  Var
    F: TFileStream;
    Ctx: TSHA1Context;
    Buf: array[0..65535] of Byte;
    N: LongInt;
    D: TSHA1Digest;

  Begin
  Sha1OfFile := False;
  Try
    F := TFileStream.Create(FileName, fmOpenRead Or fmShareDenyNone);
  Except
    Exit;
  End;
  SHA1Init(Ctx);
  Repeat
    N := F.Read(Buf, SizeOf(Buf));
    If N > 0 Then
      SHA1Update(Ctx, Buf, N);
  Until N <= 0;
  F.Free;
  SHA1Final(Ctx, D);
  Hex := LowerCase(SHA1Print(D));
  Sha1OfFile := True;
  End;


procedure Oct(var H: array of Byte; At, Width: Integer; V: Int64);
  Var
    S: String;
    i: Integer;

  Begin
  S := '';
  If V = 0 Then
    S := '0';
  While V > 0 Do
    Begin
    S := Chr(48 + (V And 7)) + S;
    V := V Shr 3;
    End;
  While Length(S) < Width - 1 Do
    S := '0' + S;
  For i := 1 To Width - 1 Do
    H[At + i - 1] := Ord(S[i]);
  H[At + Width - 1] := 0;
  End;


constructor TTarWriter.Create(const FileName: String);
  Begin
  Inherited Create;
  Failed := False;
  Err := '';
  Try
    GZ := TGZFileStream.Create(FileName, gzopenwrite);
  Except
    On E: Exception Do
      Begin
      GZ := Nil;
      Failed := True;
      Err := 'cannot create ' + FileName + ': ' + E.Message;
      End;
  End;
  End;


procedure TTarWriter.PutHeader(const Name: String; Size: Int64; Mode: LongInt; MTime: Int64);
  Var
    H: array[0..Blk - 1] of Byte;
    N, Prefix, Nm: String;
    i, p, Sum: Integer;

  Begin
  FillChar(H, SizeOf(H), 0);
  N := Name;
  While (N <> '') And (N[1] = '/') Do
    Delete(N, 1, 1);
  Prefix := '';
  If Length(N) > 100 Then
    Begin
    p := 0;
    For i := Length(N) DownTo 1 Do
      If (N[i] = '/') And (i <= 156) And (Length(N) - i <= 100) Then
        Begin
        p := i;
        Break;
        End;
    If p = 0 Then
      Begin
      Failed := True;
      Err := 'the name is too long for a tar header: ' + Name;
      Exit;
      End;
    Prefix := Copy(N, 1, p - 1);
    Nm := Copy(N, p + 1, 100);
    End
  Else
    Nm := N;
  Move(Nm[1], H[0], Length(Nm));
  Oct(H, 100, 8, Mode And 4095);
  Oct(H, 108, 8, 0);
  Oct(H, 116, 8, 0);
  Oct(H, 124, 12, Size);
  Oct(H, 136, 12, MTime);
  FillChar(H[148], 8, 32);
  H[156] := Ord('0');
  Move('ustar', H[257], 5);
  H[263] := Ord('0');
  H[264] := Ord('0');
  If Prefix <> '' Then
    Move(Prefix[1], H[345], Length(Prefix));
  Sum := 0;
  For i := 0 To Blk - 1 Do
    Sum := Sum + H[i];
  Oct(H, 148, 7, Sum);
  H[154] := 0;
  H[155] := 32;
  GZ.WriteBuffer(H, Blk);
  End;


function TTarWriter.AddFile(const DiskPath, ArcName: String; var Sha: String; var Size: Int64): Boolean;
  Var
    F: TFileStream;
    Buf: array[0..65535] of Byte;
    N: LongInt;
    Ctx: TSHA1Context;
    D: TSHA1Digest;
    Total, Want: Int64;
    Zero: array[0..Blk - 1] of Byte;
    Mode: LongInt;
    MT: Int64;
    St: Stat;

  Begin
  AddFile := False;
  If Failed Then
    Exit;
  Try
    F := TFileStream.Create(DiskPath, fmOpenRead Or fmShareDenyNone);
  Except
    On E: Exception Do
      Begin
      Err := 'cannot read ' + DiskPath;
      Exit;
      End;
  End;
  Want := F.Size;
  MT := 0;
  Mode := &644;
  If fpStat(DiskPath, St) = 0 Then
    Begin
    MT := St.st_mtime;
    Mode := St.st_mode And 4095;
    End;
  PutHeader(ArcName, Want, Mode, MT);
  If Failed Then
    Begin
    F.Free;
    Exit;
    End;
  SHA1Init(Ctx);
  Total := 0;
  While Total < Want Do
    Begin
    N := F.Read(Buf, SizeOf(Buf));
    If N <= 0 Then
      Break;
    If Total + N > Want Then
      N := Want - Total;                     {the file grew while it was copied: what the header says}
    SHA1Update(Ctx, Buf, N);
    GZ.WriteBuffer(Buf, N);
    Inc(Total, N);
    End;
  F.Free;
  If Total < Want Then                       {it shrank: the entry is filled up with zeros so that the archive stays valid}
    Begin
    FillChar(Buf, SizeOf(Buf), 0);
    While Total < Want Do
      Begin
      N := SizeOf(Buf);
      If Total + N > Want Then
        N := Want - Total;
      SHA1Update(Ctx, Buf, N);
      GZ.WriteBuffer(Buf, N);
      Inc(Total, N);
      End;
    End;
  If (Want Mod Blk) <> 0 Then
    Begin
    FillChar(Zero, SizeOf(Zero), 0);
    GZ.WriteBuffer(Zero, Blk - (Want Mod Blk));
    End;
  SHA1Final(Ctx, D);
  Sha := LowerCase(SHA1Print(D));
  Size := Want;
  AddFile := True;
  End;


function TTarWriter.AddText(const ArcName, Text: String): Boolean;
  Var
    Zero: array[0..Blk - 1] of Byte;

  Begin
  AddText := False;
  If Failed Then
    Exit;
  PutHeader(ArcName, Length(Text), &600, fpTime);
  If Failed Then
    Exit;
  If Length(Text) > 0 Then
    GZ.WriteBuffer(Text[1], Length(Text));
  If (Length(Text) Mod Blk) <> 0 Then
    Begin
    FillChar(Zero, SizeOf(Zero), 0);
    GZ.WriteBuffer(Zero, Blk - (Length(Text) Mod Blk));
    End;
  AddText := True;
  End;


function TTarWriter.Close: Boolean;
  Var
    Zero: array[0..2 * Blk - 1] of Byte;

  Begin
  Close := False;
  If GZ <> Nil Then
    Begin
    If Not Failed Then
      Begin
      FillChar(Zero, SizeOf(Zero), 0);
      GZ.WriteBuffer(Zero, SizeOf(Zero));            {the end of a tar archive: two empty blocks}
      End;
    GZ.Free;
    GZ := Nil;
    End;
  Close := Not Failed;
  End;


destructor TTarWriter.Destroy;
  Begin
  If GZ <> Nil Then
    GZ.Free;
  Inherited Destroy;
  End;


constructor TTarReader.Create(const FileName: String);
  Begin
  Inherited Create;
  Left := 0;
  Pad := 0;
  Err := '';
  Try
    GZ := TGZFileStream.Create(FileName, gzopenread);
  Except
    On E: Exception Do
      Begin
      GZ := Nil;
      Err := 'cannot open ' + FileName + ': ' + E.Message;
      End;
  End;
  End;


function ReadFull(S: TStream; var Buf; N: LongInt): LongInt;
  Var
    Got, R: LongInt;

  Begin
  Got := 0;
  While Got < N Do
    Begin
    R := S.Read((PByte(@Buf) + Got)^, N - Got);
    If R <= 0 Then
      Break;
    Inc(Got, R);
    End;
  ReadFull := Got;
  End;


function FieldStr(const H: array of Byte; At, Len: Integer): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := At To At + Len - 1 Do
    Begin
    If H[i] = 0 Then
      Break;
    Result := Result + Chr(H[i]);
    End;
  End;


function FieldOct(const H: array of Byte; At, Len: Integer): Int64;
  Var
    i: Integer;

  Begin
  Result := 0;
  For i := At To At + Len - 1 Do
    Begin
    If (H[i] >= 48) And (H[i] <= 55) Then
      Result := Result * 8 + (H[i] - 48)
    Else If (H[i] = 0) Or (H[i] = 32) Then
      Begin
      If Result > 0 Then
        Break;
      End
    Else
      Break;
    End;
  End;


function TTarReader.Next: Boolean;
  Var
    H: array[0..Blk - 1] of Byte;
    Skipbuf: array[0..Blk - 1] of Byte;
    Sum, i, N: Integer;
    Typ: Byte;
    P: String;
    AllZero: Boolean;

  Begin
  Next := False;
  If GZ = Nil Then
    Exit;
  Skip;
  Repeat
    N := ReadFull(GZ, H, Blk);
    If N = 0 Then
      Exit;                                   {the end without the closing blocks: fine}
    If N < Blk Then
      Begin
      Err := 'the archive ends in the middle of a header (damaged)';
      Exit;
      End;
    AllZero := True;
    For i := 0 To Blk - 1 Do
      If H[i] <> 0 Then
        Begin
        AllZero := False;
        Break;
        End;
    If AllZero Then
      Exit;                                   {the end}
    Sum := 0;
    For i := 0 To Blk - 1 Do
      If (i >= 148) And (i < 156) Then
        Sum := Sum + 32
      Else
        Sum := Sum + H[i];
    If Sum <> FieldOct(H, 148, 8) Then
      Begin
      Err := 'a header of the archive is damaged (checksum)';
      Exit;
      End;
    Typ := H[156];
    Size := FieldOct(H, 124, 12);
    Name := FieldStr(H, 0, 100);
    P := FieldStr(H, 345, 155);
    If (P <> '') And (FieldStr(H, 257, 5) = 'ustar') Then
      Name := P + '/' + Name;
    Mode := FieldOct(H, 100, 8);
    MTime := FieldOct(H, 136, 12);
    Left := Size;
    Pad := (Blk - (Size Mod Blk)) Mod Blk;
    If (Typ = Ord('0')) Or (Typ = 0) Then
      Begin
      Next := True;
      Exit;
      End;
    Skip;                                     {a directory, a link, an extended header: not ours}
  Until False;
  End;


function TTarReader.ReadData(var Buf; N: LongInt): LongInt;
  Var
    R: LongInt;

  Begin
  ReadData := 0;
  If (GZ = Nil) Or (Left <= 0) Then
    Exit;
  If N > Left Then
    N := Left;
  R := ReadFull(GZ, Buf, N);
  Dec(Left, R);
  If R < N Then
    Begin
    Err := 'the archive ends in the middle of a file (damaged)';
    Left := 0;
    Pad := 0;
    End;
  ReadData := R;
  End;


procedure TTarReader.Skip;
  Var
    Buf: array[0..65535] of Byte;
    N: LongInt;

  Begin
  If GZ = Nil Then
    Exit;
  While Left > 0 Do
    Begin
    N := SizeOf(Buf);
    If N > Left Then
      N := Left;
    If ReadFull(GZ, Buf, N) < N Then
      Begin
      Err := 'the archive ends in the middle of a file (damaged)';
      Left := 0;
      Pad := 0;
      Exit;
      End;
    Dec(Left, N);
    End;
  If Pad > 0 Then
    Begin
    ReadFull(GZ, Buf, Pad);
    Pad := 0;
    End;
  End;


destructor TTarReader.Destroy;
  Begin
  If GZ <> Nil Then
    GZ.Free;
  Inherited Destroy;
  End;


End.
