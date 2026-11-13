{$V-}
Unit CFGORIG;

{$I OPDEFINE.INC}


Interface
Procedure DoCfgOrig;

Implementation

uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,
  OpSelect,  OpEntry, CfgGlob, MKCfgAbs, MKString;

const
  idOrig1                = 0;

{Help index constants}
const
  hiOrig1                = 1;

Type UserRecord = Array[1..20] of String[55];

Var
  ES     : ScrollingEntryScreen;
  UR     : ^UserRecord;
  Status : Word;


{$F+}
procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
begin
  with ESP^ do
    case GetCurrentID of
      idOrig1                : ;
    end;
end;


procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idOrig1                : ;
    end;
end;


procedure IncChoice(var Value; ID : Word; Factor : Integer; var St : string);
  {-Increment a multiple choice field value and convert it to a string}
begin
end;

procedure ErrorHandler(UnitCode : Byte; var ErrCode : Word; Msg : string);
  {-Report errors}
begin
  RingBell;
end;

procedure DisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
  {-Display context sensitive help}
begin
end;
{$F-}

function InitEntryScreen : Word;
  Var
    i: Word;

const
  WinOptions = wBordered+wClear+wUserContents+wResizeable;

  begin
  with ES do
    begin
    if not InitCustom(6, 9, 75, 21, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Origin Lines ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

    For i := 1 to 20 Do
      Begin
      AddStringField(PadLeft(Long2Str(i),' ',2) + ':', i + 1, 4,
       CharStr('X', 55), i + 1, 8, 55, hiOrig1, UR^[i]);
      End;
    AllocateScreen;
    InitEntryScreen := RawError;
    end;
  end;


Procedure DoCfgOrig;
  Var
    i: Word;

  Begin
  New(UR);
  if MouseInstalled then
    with EsColors do begin
      {activate mouse cursor}
      SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
      ShowMouse;
      {enable mouse support}
      EntryCommands.cpOptionsOn(cpEnableMouse);
    end;
  Status := InitEntryScreen;
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  For i := 1 to 20 Do
    UR^[i] := Config^.GetOrigStr(i);
  ES.Process;
  ES.Erase;
  HideMouse;
  ES.Done;
  For i := 1 to 20 Do
    Config^.SetOrigStr(i, UR^[i]);
  Dispose(UR);
  End;


End.
