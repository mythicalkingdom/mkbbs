Unit MKCfgJs;   {The MK configuration kept in one JSON file (bbsconfig.json) instead of the .mk record files}

{$MODE OBJFPC}
{$H+}
{$PACKRECORDS 1}
{$WARN SYMBOL_DEPRECATED OFF}
{$I-}
{$V-}

(*
     MKJsonCfgObj is MKCfgObj (MKCfgMK) with another place to keep the data: where MKCfgObj reads and writes config.mk,
     messages.mk, files.mk, echocfg.mk and mailer.mk, this one reads and writes the sections of one file:

         {
           "version": 1,
           "config":   { ... the fields of config.mk ... },
           "messages": { "1": { ... }, "6": { ... } },        message areas, only those in use
           "files":    { "1": { ... } },                       file areas, only those in use
           "echo":     { ... echocfg.mk: directories, systems, areas ... },
           "mailer":   { ... mailer.mk ... }
         }

     The fields have the names of the record fields (Struct.MK, MKGlobT.pas); CfgJson.Inc (made by tools/genjsoncfg.py)
     turns the records into JSON and back.  What is not in the file is zero/empty (or, for "mailer", the default).
     Text is UTF-8 in the file (the records keep it in CP437).  Everything else in MKCfgObj is the same: the object
     is used like it.

     Which file:
         environment variable MKJSON   the file, or the directory that has bbsconfig.json
         (MKJSON not set)              bbsconfig.json in the MK directory (MKCfgObj's BbsPath)
     The main directory of the BBS is the MK environment variable when it is set, else the directory of the file.
     JsonConfigWanted tells that MKJSON is set (a program that chooses between the record files and the JSON file).
*)

Interface

Uses MKGlobT, MKCfgAbs, MKCfgMK;

Const
  JsonEnvName = 'MKJSON';
  JsonFileName = 'bbsconfig.json';
  JsonCfgVersion = 1;
  jeNoFile = 2;                        {Error: no bbsconfig.json}
  jeBadJson = 2001;                    {Error: the file is not JSON or not an object}
  jeSaveFailed = 2002;                 {Error: the file could not be written}


Type
  MKJsonCfgObj = Object(MKCfgObj)
    Function  EnvBbsPath: ShortString; Virtual;
    Procedure MKLoad; Virtual;
    Procedure MKSave; Virtual;
    Function  SaveEchoCfg: Word; Virtual;
    Function  SaveFileNames: ShortString; Virtual;
    Function  SaveFileName(FN: ShortString): ShortString; Virtual;
    Function  JsonFile: ShortString;     {the file that is used}
    End;
  MKJsonCfgObjPtr = ^MKJsonCfgObj;


Function JsonConfigWanted: Boolean;    {The MKJSON environment variable is set}
Function JsonConfigFile(BbsPath: ShortString): ShortString;   {The file: MKJSON, else BbsPath + bbsconfig.json}


Implementation

Uses SysUtils, Classes, fpjson, jsonparser, MKCp437;


Function ShortOk(Var S: ShortString; Max: Integer): ShortString;
  {A string whose length byte is more than the room it has (garbage in the record) is empty}
  Begin
  If Length(S) > Max Then
    Result := ''
  Else
    Result := S;
  End;


Function PasToJson(S: ShortString): RawByteString;
  {CP437 bytes -> UTF-8}
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If S[i] = #0 Then
      {a NUL is not text (and the JSON parser of FPC folds two \u0000 in a row): left out}
    Else If Ord(S[i]) < 128 Then
      Result := Result + S[i]
    Else
      Result := Result + Cp437ToUtf8(Ord(S[i]));
  End;


Function JsonToPas(S: RawByteString): ShortString;
  {UTF-8 -> CP437 bytes (a character that has no CP437 code is a ?)}
  Var
    i, n: Integer;
    U: Cardinal;
    B: Byte;

  Begin
  Result := '';
  i := 1;
  While (i <= Length(S)) And (Length(Result) < 255) Do
    Begin
    B := Ord(S[i]);
    If B < 128 Then
      Begin
      Result := Result + S[i];
      Inc(i);
      End
    Else
      Begin
      If B >= $F0 Then
        Begin
        U := B And $07;
        n := 3;
        End
      Else If B >= $E0 Then
        Begin
        U := B And $0F;
        n := 2;
        End
      Else If B >= $C0 Then
        Begin
        U := B And $1F;
        n := 1;
        End
      Else
        Begin
        U := 0;
        n := 0;
        End;
      Inc(i);
      While (n > 0) And (i <= Length(S)) And ((Ord(S[i]) And $C0) = $80) Do
        Begin
        U := (U Shl 6) Or (Ord(S[i]) And $3F);
        Inc(i);
        Dec(n);
        End;
      If (U > 0) And (U < 65536) And (Utf8ToCp437(U) <> 0) Then
        Result := Result + Chr(Utf8ToCp437(U))
      Else
        Result := Result + '?';
      End;
    End;
  End;


Function JsonChar(C: Char): TJSONData;
  Begin
  If (Ord(C) >= 32) And (Ord(C) < 127) Then
    Result := TJSONString.Create(C)
  Else
    Result := TJSONInt64Number.Create(Ord(C));
  End;


Function JsonChar2(D: TJSONData; Def: Char): Char;
  Var
    S: ShortString;

  Begin
  Result := Def;
  If D.JSONType = jtString Then
    Begin
    S := JsonToPas(D.AsString);
    If Length(S) > 0 Then
      Result := S[1];
    End
  Else If D.JSONType = jtNumber Then
    Result := Chr(D.AsInteger And 255);
  End;


Function JsonBool(D: TJSONData; Def: Boolean): Boolean;
  Begin
  Result := Def;
  If D.JSONType = jtBoolean Then
    Result := D.AsBoolean
  Else If D.JSONType = jtNumber Then
    Result := D.AsInt64 <> 0;
  End;


Function JsonNum(D: TJSONData; Def, Lo, Hi: Int64): Int64;
  Begin
  Result := Def;
  If D.JSONType = jtNumber Then
    Begin
    Result := D.AsInt64;
    If Result < Lo Then
      Result := Lo;
    If Result > Hi Then
      Result := Hi;
    End
  Else If D.JSONType = jtBoolean Then
    Result := Ord(D.AsBoolean);
  End;


Function JsonStr(D: TJSONData; Def: ShortString): ShortString;
  Begin
  Result := Def;
  If D.JSONType = jtString Then
    Result := JsonToPas(D.AsString);
  End;


{$I CfgJson.Inc}


Function JsonConfigWanted: Boolean;
  Begin
  Result := GetEnvironmentVariable(JsonEnvName) <> '';
  End;


Function JsonConfigFile(BbsPath: ShortString): ShortString;
  Var
    E: String;

  Begin
  E := GetEnvironmentVariable(JsonEnvName);
  If E = '' Then
    Result := BbsPath + JsonFileName
  Else If (E[Length(E)] = '/') Or DirectoryExists(E) Then
    Result := IncludeTrailingPathDelimiter(E) + JsonFileName
  Else
    Result := E;
  End;


Function MKJsonCfgObj.EnvBbsPath: ShortString;
  Begin
  Result := GetEnvironmentVariable('MK');
  If (Result = '') And JsonConfigWanted Then
    Result := ExtractFilePath(ExpandFileName(JsonConfigFile('')));
  End;


Function MKJsonCfgObj.JsonFile: ShortString;
  Begin
  Result := JsonConfigFile(CfgInfo^.BbsPath);
  End;


Function MKJsonCfgObj.SaveFileNames: ShortString;
  Begin
  Result := JsonFileName;
  End;


Function MKJsonCfgObj.SaveFileName(FN: ShortString): ShortString;
  Begin
  Result := JsonFile;
  End;


Function ReadTree(FN: String): TJSONObject;
  {the file as a JSON object, Nil when it is not there or is not one}
  Var
    F: TFileStream;
    D: TJSONData;
    OldCp: TSystemCodePage;

  Begin
  Result := Nil;
  If Not FileExists(FN) Then
    Exit;
  OldCp := DefaultSystemCodePage;
  DefaultSystemCodePage := CP_UTF8;     {the parser must keep the UTF-8 bytes as they are}
  Try
    Try
      F := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
      Try
        D := GetJSON(F, True);
      Finally
        F.Free;
      End;
    Except
      D := Nil;
    End;
  Finally
    DefaultSystemCodePage := OldCp;
  End;
  If (D <> Nil) And (D.JSONType = jtObject) Then
    Result := TJSONObject(D)
  Else
    D.Free;
  End;


Procedure MKJsonCfgObj.MKLoad;
  Var
    Root: TJSONObject;
    D, E: TJSONData;
    i: Integer;
    FN: String;

  Begin
  New(MKCfg);
  New(MKMsg);
  New(MKFile);
  New(MKEcho);
  New(MKMail);
  MailerDefaults(MKMail^);
  FillChar(MKCfg^, SizeOf(MKCfg^), 0);
  FillChar(MKMsg^, SizeOf(MKMsg^), 0);
  FillChar(MKFile^, SizeOf(MKFile^), 0);
  FillChar(MKEcho^, SizeOf(MKEcho^), 0);
  FN := JsonFile;
  If Not FileExists(FN) Then
    Error := jeNoFile
  Else
    Begin
    Root := ReadTree(FN);
    If Root = Nil Then
      Error := jeBadJson
    Else
      Begin
      Error := 0;
      Try
        D := Root.Find('config');
        If (D <> Nil) And (D.JSONType = jtObject) Then
          JsonFrom_BbsCfg(TJSONObject(D), MKCfg^);
        D := Root.Find('messages');
        If (D <> Nil) And (D.JSONType = jtObject) Then
          For i := 1 To 500 Do
            Begin
            E := TJSONObject(D).Find(IntToStr(i));
            If (E <> Nil) And (E.JSONType = jtObject) Then
              JsonFrom_MsgAreaType(TJSONObject(E), MKMsg^[i]);
            End;
        D := Root.Find('files');
        If (D <> Nil) And (D.JSONType = jtObject) Then
          For i := 1 To 300 Do
            Begin
            E := TJSONObject(D).Find(IntToStr(i));
            If (E <> Nil) And (E.JSONType = jtObject) Then
              JsonFrom_FileAreaType(TJSONObject(E), MKFile^[i]);
            End;
        D := Root.Find('echo');
        If (D <> Nil) And (D.JSONType = jtObject) Then
          JsonFrom_EchoCfgType(TJSONObject(D), MKEcho^);
        D := Root.Find('mailer');
        If (D <> Nil) And (D.JSONType = jtObject) Then
          JsonFrom_MailerCfgType(TJSONObject(D), MKMail^);
      Finally
        Root.Free;
      End;
      End;
    End;
  If Error = 0 Then
    CfgInfo^.Loaded := True
  Else
    Begin
    CfgInfo^.Loaded := False;
    Dispose(MKCfg);
    Dispose(MKMsg);
    Dispose(MKFile);
    Dispose(MKEcho);
    Dispose(MKMail);
    End;
  End;


Function WriteTree(FN: String; Root: TJSONObject): Word;
  Var
    F: TFileStream;
    S: RawByteString;
    OldCp: TSystemCodePage;

  Begin
  Result := 0;
  OldCp := DefaultSystemCodePage;
  DefaultSystemCodePage := CP_UTF8;
  S := Root.FormatJSON + #10;
  DefaultSystemCodePage := OldCp;
  Try
    F := TFileStream.Create(FN, fmCreate);
    Try
      If Length(S) > 0 Then
        F.WriteBuffer(S[1], Length(S));
    Finally
      F.Free;
    End;
  Except
    Result := jeSaveFailed;
  End;
  End;


Function EchoToJson(Var Echo: EchoCfgType): TJSONObject;
  Begin
  Result := JsonTo_EchoCfgType(Echo);
  End;


Procedure MKJsonCfgObj.MKSave;
  Var
    Root, S, E: TJSONObject;
    i: Integer;

  Begin
  Root := TJSONObject.Create;
  Try
    Root.Add('version', JsonCfgVersion);
    Root.Add('config', JsonTo_BbsCfg(MKCfg^));
    S := TJSONObject.Create;
    For i := 1 To 500 Do
      Begin
      E := JsonTo_MsgAreaType(MKMsg^[i]);
      If MKMsg^[i].Name <> '' Then
        S.Add(IntToStr(i), E)
      Else
        E.Free;
      End;
    Root.Add('messages', S);
    S := TJSONObject.Create;
    For i := 1 To 300 Do
      Begin
      E := JsonTo_FileAreaType(MKFile^[i]);
      If MKFile^[i].Name <> '' Then
        S.Add(IntToStr(i), E)
      Else
        E.Free;
      End;
    Root.Add('files', S);
    Root.Add('echo', EchoToJson(MKEcho^));
    Root.Add('mailer', JsonTo_MailerCfgType(MKMail^));
    Error := WriteTree(JsonFile, Root);
  Finally
    Root.Free;
  End;
  End;


Function MKJsonCfgObj.SaveEchoCfg: Word;
  {only the "echo" section: the rest of the file is read again and kept as it is (another program may have changed it)}
  Var
    Root: TJSONObject;
    i: Integer;

  Begin
  Root := ReadTree(JsonFile);
  If Root = Nil Then
    Begin
    MKSave;
    Result := Error;
    Exit;
    End;
  Try
    i := Root.IndexOfName('echo');
    If i >= 0 Then
      Root.Delete(i);
    Root.Add('echo', EchoToJson(MKEcho^));
    Result := WriteTree(JsonFile, Root);
  Finally
    Root.Free;
  End;
  End;


Initialization
  JsonInitZero;

End.
