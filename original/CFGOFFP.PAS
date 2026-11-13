{$R-,S-,I-,V-,B-}

Unit CFGOFFP;

interface

Procedure EditOffCfgP;

Implementation

{$I OPDEFINE.INC}

uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,
  OpSelect,  OpEntry, MKCfgAbs, CfgGlob;

{Entry field constants}
const
  idMaxMsg               = 0;
  idMaxConf              = idMaxMsg + 1;
  idCompRate             = idMaxConf + 1;
  idSafety               = idCompRate + 1;
  idAllowNew             = idSafety + 1;
  idForceNew             = idAllowNew + 1;
  idAllowScrn            = idForceNew + 1;
  idForceScrn            = idAllowScrn + 1;
  idAllowBull            = idForceScrn + 1;
  idForceBull            = idAllowBull + 1;
  idAllowFreq            = idForceBull + 1;
  idBull1                = idAllowFreq + 1;
  idWelcome              = idBull1 + 1;
  idBull2                = idWelcome + 1;
  idNews                 = idBull2 + 1;
  idBull3                = idNews + 1;
  idGoodBye              = idBull3 + 1;
  idBull4                = idGoodBye + 1;
  idBull5                = idBull4 + 1;
  idBull6                = idBull5 + 1;
  idBull7                = idBull6 + 1;
  idBull8                = idBull7 + 1;
  idBull9                = idBull8 + 1;
  idBull10               = idBull9 + 1;

{Help index constants}
const
  hiMaxMsg               = 1;
  hiMaxConf              = hiMaxMsg + 1;
  hiCompRate             = hiMaxConf + 1;
  hiSafety               = hiCompRate + 1;
  hiAllowNew             = hiSafety + 1;
  hiForceNew             = hiAllowNew + 1;
  hiAllowScrn            = hiForceNew + 1;
  hiForceScrn            = hiAllowScrn + 1;
  hiAllowBull            = hiForceScrn + 1;
  hiForceBull            = hiAllowBull + 1;
  hiAllowFreq            = hiForceBull + 1;
  hiBull1                = hiAllowFreq + 1;
  hiWelcome              = hiBull1 + 1;
  hiBull2                = hiWelcome + 1;
  hiNews                 = hiBull2 + 1;
  hiBull3                = hiNews + 1;
  hiGoodBye              = hiBull3 + 1;
  hiBull4                = hiGoodBye + 1;
  hiBull5                = hiBull4 + 1;
  hiBull6                = hiBull5 + 1;
  hiBull7                = hiBull6 + 1;
  hiBull8                = hiBull7 + 1;
  hiBull9                = hiBull8 + 1;
  hiBull10               = hiBull9 + 1;

type
  UserRecord =
    record
      MaxMsg               : Word;
      MaxConf              : Word;
      CompRate             : Word;
      Safety               : Word;
      AllowNew             : Boolean;
      ForceNew             : Boolean;
      AllowScrn            : Boolean;
      ForceScrn            : Boolean;
      AllowBull            : Boolean;
      ForceBull            : Boolean;
      AllowFreq            : Boolean;
      Bull1                : string[8];
      Welcome              : string[8];
      Bull2                : string[8];
      News                 : string[8];
      Bull3                : string[8];
      GoodBye              : string[8];
      Bull4                : string[8];
      Bull5                : string[8];
      Bull6                : string[8];
      Bull7                : string[8];
      Bull8                : string[8];
      Bull9                : string[8];
      Bull10               : string[8];
    end;

function InitEntryScreen(var ES : EntryScreen;
                         var UR : UserRecord;
                         var EsColors : ColorSet) : Word;
const
  Frame1 = '…»ªºÕÕ∫∫';
  WinOptions = wBordered+wClear+wUserContents;
begin
  with ES do begin
    if not InitCustom(3, 3, 75, 22, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Offline Mail Paramaters ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    AddTextField(
      '-----   Screens  ------', 10, 24);

  {idMaxMsg:}
    AddWordField(
      'Maximum Msgs Per Packet:', 2, 3,
      '9999', 2, 28,
      hiMaxMsg, 1, 4000, UR.MaxMsg);

  {idMaxConf:}
    AddWordField(
      'Maximum Msgs Per Area:', 2, 38,
      '9999', 2, 61,
      hiMaxConf, 1, 4000, UR.MaxConf);

  {idCompRate:}
    AddWordField(
      'Assumed Compression Rate:', 3, 3,
      '999', 3, 29,
      hiCompRate, 0, 100, UR.CompRate);

  {idSafety:}
    AddWordField(
      'Safety Time Buffer (Minutes):', 3, 38,
      '999', 3, 68,
      hiSafety, 0, 10, UR.Safety);

  {idAllowNew:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Allow New Files List:', 5, 3,
      'Y', 5, 25,
      hiAllowNew, UR.AllowNew);
    esFieldOptionsOff(efClickExit);

  {idForceNew:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Force New Files List:', 5, 38,
      'Y', 5, 60,
      hiForceNew, UR.ForceNew);
    esFieldOptionsOff(efClickExit);

  {idAllowScrn:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Allow BBS Screens:', 6, 3,
      'Y', 6, 22,
      hiAllowScrn, UR.AllowScrn);
    esFieldOptionsOff(efClickExit);

  {idForceScrn:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Force BBS Screens:', 6, 38,
      'Y', 6, 57,
      hiForceScrn, UR.ForceScrn);
    esFieldOptionsOff(efClickExit);

  {idAllowBull:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Allow Bulletins:', 7, 3,
      'Y', 7, 20,
      hiAllowBull, UR.AllowBull);
    esFieldOptionsOff(efClickExit);

  {idForceBull:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Force Bulletins:', 7, 38,
      'Y', 7, 55,
      hiForceBull, UR.ForceBull);
    esFieldOptionsOff(efClickExit);

  {idAllowFreq:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Allow File Requests:', 8, 3,
      'Y', 8, 24,
      hiAllowFreq, UR.AllowFreq);
    esFieldOptionsOff(efClickExit);

  {idBull1:}
    AddStringField(
      'Bulletin  1:', 11, 3,
      'XXXXXXXX', 11, 16, 8,
      hiBull1, UR.Bull1);

  {idWelcome:}
    AddStringField(
      'Welcome:', 11, 38,
      'XXXXXXXX', 11, 47, 8,
      hiWelcome, UR.Welcome);

  {idBull2:}
    AddStringField(
      'Bulletin  2:', 12, 3,
      'XXXXXXXX', 12, 16, 8,
      hiBull2, UR.Bull2);

  {idNews:}
    AddStringField(
      'News:', 12, 38,
      'XXXXXXXX', 12, 44, 8,
      hiNews, UR.News);

  {idBull3:}
    AddStringField(
      'Bulletin  3:', 13, 3,
      'XXXXXXXX', 13, 16, 8,
      hiBull3, UR.Bull3);

  {idGoodBye:}
    AddStringField(
      'GoodBye:', 13, 38,
      'XXXXXXXX', 13, 47, 8,
      hiGoodBye, UR.GoodBye);

  {idBull4:}
    AddStringField(
      'Bulletin  4:', 14, 3,
      'XXXXXXXX', 14, 16, 8,
      hiBull4, UR.Bull4);

  {idBull5:}
    AddStringField(
      'Bulletin  5:', 15, 3,
      'XXXXXXXX', 15, 16, 8,
      hiBull5, UR.Bull5);

  {idBull6:}
    AddStringField(
      'Bulletin  6:', 16, 3,
      'XXXXXXXX', 16, 16, 8,
      hiBull6, UR.Bull6);

  {idBull7:}
    AddStringField(
      'Bulletin  7:', 17, 3,
      'XXXXXXXX', 17, 16, 8,
      hiBull7, UR.Bull7);

  {idBull8:}
    AddStringField(
      'Bulletin  8:', 18, 3,
      'XXXXXXXX', 18, 16, 8,
      hiBull8, UR.Bull8);

  {idBull9:}
    AddStringField(
      'Bulletin  9:', 19, 3,
      'XXXXXXXX', 19, 16, 8,
      hiBull9, UR.Bull9);

  {idBull10:}
    AddStringField(
      'Bulletin 10:', 20, 3,
      'XXXXXXXX', 20, 16, 8,
      hiBull10, UR.Bull10);

    InitEntryScreen := RawError;
  end;
end;


Procedure EditOffCfgP;
  Var
    ES: ^EntryScreen;
    UR: ^UserRecord;

  Begin
  New(UR);
  New(ES);
  If InitEntryScreen(ES^, Ur^, ESColors) = 0 Then
    Begin
    UR^.MaxMsg := Config^.GetOffMax;
    UR^.MaxConf := Config^.GetOffConfMax;
    UR^.CompRate := Config^.GetOffCompRate;
    UR^.Safety := Config^.GetOffSafetyMin;
    UR^.AllowNew := Config^.GetOffAllowNew;
    UR^.ForceNew := Config^.GetOffForceNew;
    UR^.AllowScrn := Config^.GetOffAllowScrn;
    UR^.ForceScrn := Config^.GetOffForceScrn;
    UR^.AllowBull := Config^.GetOffAllowBull;
    UR^.ForceBull := Config^.GetOffForceBull;
    UR^.AllowFreq := Config^.GetOffAllowFreq;
    UR^.Bull1 := Config^.GetOffBulls(1);
    UR^.Welcome := Config^.GetOffScrns(1);
    UR^.Bull2 := Config^.GetOffBulls(2);
    UR^.News := Config^.GetOffScrns(2);
    UR^.Bull3 := Config^.GetOffBulls(3);
    UR^.GoodBye := Config^.GetOffScrns(3);
    UR^.Bull4 := Config^.GetOffBulls(4);
    UR^.Bull5 := Config^.GetOffBulls(5);
    UR^.Bull6 := Config^.GetOffBulls(6);
    UR^.Bull7 := Config^.GetOffBulls(7);
    UR^.Bull8 := Config^.GetOffBulls(8);
    UR^.Bull9 := Config^.GetOffBulls(9);
    UR^.Bull10 := Config^.GetOffBulls(10);
    ES^.Process;
    ES^.Erase;
    Config^.SetOffMax(UR^.MaxMsg);
    Config^.SetOffConfMax(UR^.MaxConf);
    Config^.SetOffCompRate(UR^.CompRate);
    Config^.SetOffSafetyMin(UR^.Safety);
    Config^.SetOffAllowNew(UR^.AllowNew);
    Config^.SetOffForceNew(UR^.ForceNew);
    Config^.SetOffAllowScrn(UR^.AllowScrn);
    Config^.SetOffForceScrn(UR^.ForceScrn);
    Config^.SetOffAllowBull(UR^.AllowBull);
    Config^.SetOffForceBull(UR^.ForceBull);
    Config^.SetOffAllowFreq(UR^.AllowFreq);
    Config^.SetOffBulls(1, UR^.Bull1);
    Config^.SetOffScrns(1, UR^.Welcome);
    Config^.SetOffBulls(2, UR^.Bull2);
    Config^.SetOffScrns(2, UR^.News);
    Config^.SetOffBulls(3, UR^.Bull3);
    Config^.SetOffScrns(3, UR^.GoodBye);
    Config^.SetOffBulls(4, UR^.Bull4);
    Config^.SetOffBulls(5, UR^.Bull5);
    Config^.SetOffBulls(6, UR^.Bull6);
    Config^.SetOffBulls(7, UR^.Bull7);
    Config^.SetOffBulls(8, UR^.Bull8);
    Config^.SetOffBulls(9, UR^.Bull9);
    Config^.SetOffBulls(10, UR^.Bull10);
    ES^.Done;
    End;
  Dispose(ES);
  Dispose(UR);
  End;

end.
