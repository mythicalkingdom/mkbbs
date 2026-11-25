Unit MKDoorCfg;   {doors.cfg: the doors of the BBS (DOORS-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
     doors.cfg is a plain text file in the BBS directory.  A block for each door, started by its name in brackets; the menu item that runs a door
     (command 172) names it.  A # starts a comment (at the start of a line or after a space).

       [global]                          settings for all doors (optional)
       dosemu  = /usr/bin/dosemu         the dosemu2 program (default: dosemu on the path; the environment MKDOS_DOSEMU also says it)
       tmp     = /tmp/mkdosdoor-1000     where the work directories of DOS doors are made (default /tmp/mkdosdoor-<uid>; MKDOS_TMP)

       [lord]
       type      = dos                   dos (run in dosemu2) | native (a Linux program, as menu command 7)
       dir       = /bbs/doors/lord       the directory of the door (a DOS door: its files are linked into the work directory of the call)
       command   = START.BAT             what is run there; *N is the node (native: the other * codes of command 7 too)
       subdir    =                       DOS: run in this directory below dir
       com       = 1                     DOS: the COM port number the door is told
       dropfiles = dorinfo1.def door.sys callinfo.bbs     which drop files are written (default: dorinfo1.def door.sys)
       freeze    = no                    yes: the time of the caller does not run while the door does
       sandbox   = default               default | off | net (DOORS-PLAN.md C: not used yet)
       bind      = /bbs/doors/scores     more directories the sandbox shows, writable (any number of lines)
       robind    = /bbs/files            ... read only
}

Interface

Uses Classes;

Type
  TDoorDef = Record
    Name, Kind, Dir, Command, SubDir, DropFiles, Sandbox: String;
    Com: Integer;
    Freeze: Boolean;
    Binds, ROBinds: TStringList;
  End;

  TDoorCfg = Class
    Dosemu, Tmp: String;
    Doors: Array Of TDoorDef;
    Problems: TStringList;             {what could not be understood, with the line number: mkcheck says it}
    Constructor Create;
    Destructor Destroy; Override;
    Procedure Load(Const Path: String);
    Function Find(Const Name: String): Integer;       {the index in Doors, -1 when there is none}
  End;

Function DropFilesWanted(Const D: TDoorDef; Const FileName: String): Boolean;
Function SetLine(Const FileName: String; Line: Integer; Const NewText: String): Boolean;
  {the line (1 is the first) of a drop file is replaced (the COM port line); all line ends become CR LF}


Implementation

Uses SysUtils;


Constructor TDoorCfg.Create;
  Begin
  Problems := TStringList.Create;
  SetLength(Doors, 0);
  End;


Destructor TDoorCfg.Destroy;
  Var
    i: Integer;

  Begin
  For i := 0 To High(Doors) Do
    Begin
    Doors[i].Binds.Free;
    Doors[i].ROBinds.Free;
    End;
  Problems.Free;
  Inherited Destroy;
  End;


Function TDoorCfg.Find(Const Name: String): Integer;
  Var
    i: Integer;

  Begin
  Find := -1;
  For i := 0 To High(Doors) Do
    If LowerCase(Doors[i].Name) = LowerCase(Trim(Name)) Then
      Find := i;
  End;


Function YesNo(Const S: String; Var Ok: Boolean): Boolean;
  Begin
  Ok := True;
  YesNo := False;
  If (LowerCase(S) = 'yes') Or (LowerCase(S) = 'on') Or (S = '1') Or (LowerCase(S) = 'true') Then
    YesNo := True
  Else If Not ((LowerCase(S) = 'no') Or (LowerCase(S) = 'off') Or (S = '0') Or (LowerCase(S) = 'false')) Then
    Ok := False;
  End;


Procedure TDoorCfg.Load(Const Path: String);
  Var
    L: TStringList;
    i, p, Cur: Integer;
    S, K, V: String;
    InGlobal, Ok: Boolean;

  Procedure Bad(Const Why: String);
    Begin
    Problems.Add('line ' + IntToStr(i + 1) + ': ' + Why);
    End;

  Begin
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(Path);
    Except
      Exit;
    End;
    Cur := -1;
    InGlobal := False;
    For i := 0 To L.Count - 1 Do
      Begin
      S := Trim(L[i]);
      p := Pos(' #', S);
      If p > 0 Then
        S := Trim(Copy(S, 1, p - 1));
      If (S = '') Or (S[1] = '#') Or (S[1] = ';') Then
        Continue;
      If S[1] = '[' Then
        Begin
        If S[Length(S)] <> ']' Then
          Begin
          Bad('a block name starts with [ and ends with ]');
          Continue;
          End;
        S := Trim(Copy(S, 2, Length(S) - 2));
        If LowerCase(S) = 'global' Then
          Begin
          InGlobal := True;
          Cur := -1;
          End
        Else
          Begin
          InGlobal := False;
          If S = '' Then
            Begin
            Bad('a door needs a name');
            Cur := -1;
            Continue;
            End;
          If Find(S) >= 0 Then
            Bad('the door ' + S + ' is there twice (the first is used)');
          SetLength(Doors, Length(Doors) + 1);
          Cur := High(Doors);
          FillChar(Doors[Cur], SizeOf(TDoorDef), 0);
          Doors[Cur].Name := S;
          Doors[Cur].Kind := 'dos';
          Doors[Cur].Com := 1;
          Doors[Cur].DropFiles := 'dorinfo1.def door.sys';
          Doors[Cur].Sandbox := 'default';
          Doors[Cur].Binds := TStringList.Create;
          Doors[Cur].ROBinds := TStringList.Create;
          End;
        Continue;
        End;
      p := Pos('=', S);
      If p = 0 Then
        Begin
        Bad('a setting is  name = value');
        Continue;
        End;
      K := LowerCase(Trim(Copy(S, 1, p - 1)));
      V := Trim(Copy(S, p + 1, Length(S)));
      If InGlobal Then
        Begin
        If K = 'dosemu' Then Dosemu := V
        Else If K = 'tmp' Then Tmp := V
        Else Bad('unknown setting ' + K + ' in [global]');
        End
      Else If Cur < 0 Then
        Bad('the setting ' + K + ' is before the first [door]')
      Else
        With Doors[Cur] Do
          Begin
          If K = 'type' Then
            Begin
            Kind := LowerCase(V);
            If (Kind <> 'dos') And (Kind <> 'native') Then
              Bad('type is dos or native, not ' + V);
            End
          Else If K = 'dir' Then Dir := V
          Else If K = 'command' Then Command := V
          Else If K = 'subdir' Then SubDir := V
          Else If K = 'com' Then
            Begin
            Com := StrToIntDef(V, 0);
            If (Com < 1) Or (Com > 9) Then
              Begin
              Bad('com is a number from 1 to 9');
              Com := 1;
              End;
            End
          Else If K = 'dropfiles' Then DropFiles := LowerCase(V)
          Else If K = 'freeze' Then
            Begin
            Freeze := YesNo(LowerCase(V), Ok);
            If Not Ok Then
              Bad('freeze is yes or no');
            End
          Else If K = 'sandbox' Then
            Begin
            Sandbox := LowerCase(V);
            If (Sandbox <> 'default') And (Sandbox <> 'off') And (Sandbox <> 'net') Then
              Begin
              Bad('sandbox is default, off or net');
              Sandbox := 'default';
              End;
            End
          Else If K = 'bind' Then Binds.Add(V)
          Else If K = 'robind' Then ROBinds.Add(V)
          Else Bad('unknown setting ' + K);
          End;
      End;
  Finally
    L.Free;
  End;
  End;


Function DropFilesWanted(Const D: TDoorDef; Const FileName: String): Boolean;
  Begin
  DropFilesWanted := Pos(' ' + LowerCase(FileName) + ' ', ' ' + D.DropFiles + ' ') > 0;
  End;


Function SetLine(Const FileName: String; Line: Integer; Const NewText: String): Boolean;
  Var
    L: TStringList;
    i: Integer;
    S: String;

  Begin
  SetLine := False;
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(FileName);
    Except
      Exit;
    End;
    If Line <= L.Count Then
      L[Line - 1] := NewText;
    S := '';
    For i := 0 To L.Count - 1 Do
      S := S + TrimRight(L[i]) + #13#10;
    {written as it is: SaveToFile would end the lines with LF}
    With TFileStream.Create(FileName, fmCreate) Do
      Try
        If Length(S) > 0 Then
          WriteBuffer(S[1], Length(S));
      Finally
        Free;
      End;
    SetLine := True;
  Finally
    L.Free;
  End;
  End;


End.
