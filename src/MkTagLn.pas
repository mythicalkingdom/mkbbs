Unit MKTagLn;
{$I MKB.Def}

Interface

Procedure InitTags; {Initialize taglines}
Procedure FreeTags; {Free memory allocated to taglines}
Procedure LoadTags(FN: String); {Load taglines from file}
Procedure DeleteTag(TagNum: Word); {Delete tagline}
Procedure AddTag(TagNum: Word; TagStr: String); {Add/change tagline}
Procedure SaveTags(FN: String); {Save taglines to file}
Function  GetTag(TagNum: Word): String; {Get specific tagline number}
Function  GetNextTag(Var TagNum: Word): String; {Get tagline starting at tagnum}


Const
  MaxTags = 2000;


Var
  NumTags: Word;


Implementation


Uses MKFile, MKString,
  Dos;

Type StrPtr = ^String;

Var
  TagList: Array[1..MaxTags] of StrPtr;
  TagAlloc: Array[1..MaxTags] of Boolean;


Procedure InitTags;
  Var
    i: Word;

  Begin
  For i := 1 to MaxTags Do
    TagAlloc[i] := False;
  NumTags :=  0;
  End;


Procedure FreeTags;
  Var
    i: Word;

  Begin
  If NumTags > 0 Then
    Begin
    NumTags := 0;
    For i := 1 to MaxTags Do
      Begin
      If TagAlloc[i] Then
        Begin
        FreeMem(TagList[i], Length(TagList[i]^) + 1);
        TagAlloc[i] := False;
        End;
      End;
    End;
  End;


Procedure LoadTags(FN: String);
  Var
    TF: TFile;
    TmpStr: String;

  Begin
  FreeTags;
  If FileExist(FN) Then
    Begin
    TF.Init;
    If TF.OpenTextFile(FN) Then
      Begin
      TmpStr := TF.GetString;
      While ((TF.StringFound) And (NumTags < MaxTags)) Do
        Begin
        Inc(NumTags);
        GetMem(TagList[NumTags], Length(TmpStr) + 1);
        TagAlloc[NumTags] := True;
        TagList[NumTags]^ := TmpStr;
        TmpStr := TF.GetString;
        End;
      If TF.CloseTextFile Then;
      End;
    TF.Done;
    End;
  End;


Procedure DeleteTag(TagNum: Word);
  Begin
  If TagAlloc[TagNum] Then
    Begin
    FreeMem(TagList[TagNum], Length(TagList[TagNum]^) + 1);
    TagAlloc[TagNum] := False;
    Dec(NumTags);
    End;
  End;


Procedure AddTag(TagNum: Word; TagStr: String);
  Begin
  If Not TagAlloc[TagNum] Then
    Inc(NumTags)
  Else
    FreeMem(TagList[TagNum], Length(TagList[TagNum]^) + 1);
  GetMem(TagList[TagNum], Length(TagStr) + 1);
  TagList[TagNum]^ := TagStr;
  TagAlloc[TagNum] := True;
  End;


Procedure SaveTags(FN: String);
  Var
    F: Text;
    i: Word;

  Begin
  Assign(F, FN);
  ReWrite(F);
  If IoResult <> 0 Then;
  For i := 1 to MaxTags Do
    Begin
    If TagAlloc[i] Then
      Begin
      If Length(TagList[i]^) > 0 Then
        Begin
        WriteLn(F, TagList[i]^);
        If IoResult <> 0 Then;
        End;
      End;
    End;
  Close(F);
  If IoResult <> 0 Then;
  End;


Function GetTag(TagNum: Word): String;
  Begin
  If TagAlloc[TagNum] Then
    GetTag := TagList[TagNum]^
  Else
    GetTag := '';
  End;


Function  GetNextTag(Var TagNum: Word): String;
  Var
    HasWrapped: Boolean;
    SearchOver: Boolean;
    i: Word;

  Begin
  If NumTags = 0 Then
    GetNextTag := ''
  Else
    Begin
    If ((TagNum < 1) or (TagNum > MaxTags)) Then
      TagNum := 1;
    HasWrapped := False;
    SearchOver := False;
    i := TagNum;
    While Not SearchOver Do
      Begin
      If TagAlloc[i] Then
        Begin
        If Length(TagList[i]^) > 0 Then
          Begin
          SearchOver := True;
          GetNextTag := TagList[i]^;
          TagNum := i;
          End;
        End;
      If Not SearchOver Then
        Begin
        Inc(i);
        If ((i > MaxTags) and (Not HasWrapped)) Then
          Begin
          i := 1;
          HasWrapped := True;
          End;
        If ((HasWrapped) And (i >= TagNum)) Then
          Begin
          SearchOver := True;
          GetNextTag := '';
          End;
        End;
      End;
    End;
  End;


End.
