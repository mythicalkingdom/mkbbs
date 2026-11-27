{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKSgr;   {Colour guard for text that is shown on a terminal with its own colours (UTF-8 terminals)}

{$I MKB.Def}

{
     The ANSI art of a BBS is drawn for a DOS screen: light gray on black.  A themed terminal (xterm, a Linux console ...)
     has other default colours, and a colour reset (ESC[0m, ESC[m) in the art goes to those.  The guard watches the
     text that goes out and says what has to be added so the DOS colours stay:

         First            at the start of the text, once: ESC[37;40m (light gray on black)
         Feed(Ch)         after each character of the text: '' or what to send now.  After a sequence with a reset that
                          does not set both a foreground and a background the missing one is added:
                          ESC[40m (no background), ESC[37m (no foreground) or ESC[37;40m (neither).

     Used by the BBS (MKDoor: text for a caller whose terminal wants UTF-8) and by mkcat.
}

Interface

Type
  SgrGuardObj = Object
    Started: Boolean;                  {First was given}
    State: Byte;                       {0 text, 1 after ESC, 2 inside ESC [ ...}
    Num: Integer;                      {the number being read, -1 = none yet}
    Reset, Bg, Fg: Boolean;            {this sequence resets / sets a background / sets a foreground}
    Procedure Init;
    Function  First: String;
    Function  Feed(Ch: Char): String;
    Private
    Procedure Number;
    End;


Implementation


Procedure SgrGuardObj.Init;
  Begin
  Started := False;
  State := 0;
  Num := -1;
  Reset := False;
  Bg := False;
  Fg := False;
  End;


Function SgrGuardObj.First: String;
  Begin
  If (Not Started) And (State = 0) Then
    Begin
    Started := True;
    First := #27'[37;40m';
    End
  Else
    First := '';
  End;


Procedure SgrGuardObj.Number;
  Begin
  If Num < 0 Then
    Num := 0;                          {an empty parameter means 0}
  If Num = 0 Then
    Reset := True;
  If ((Num >= 40) And (Num <= 48)) Or ((Num >= 100) And (Num <= 107)) Then
    Bg := True;
  If ((Num >= 30) And (Num <= 39)) Or ((Num >= 90) And (Num <= 97)) Then
    Fg := True;
  Num := -1;
  End;


Function SgrGuardObj.Feed(Ch: Char): String;
  Begin
  Feed := '';
  Case State Of
    0: If Ch = #27 Then
         State := 1;
    1: If Ch = '[' Then
         Begin
         State := 2;
         Num := -1;
         Reset := False;
         Bg := False;
         Fg := False;
         End
       Else
         State := 0;
    Else
      If Ch In ['0'..'9'] Then
        Begin
        If Num < 0 Then
          Num := 0;
        If Num < 1000 Then
          Num := Num * 10 + Ord(Ch) - 48;
        End
      Else If Ch = ';' Then
        Number
      Else If (Ch >= #64) And (Ch <= #126) Then
        Begin
        State := 0;
        If Ch = 'm' Then
          Begin
          Number;
          If Reset And Not (Bg And Fg) Then
            Begin                      {the DOS defaults: light gray on black}
            If Fg Then
              Feed := #27'[40m'
            Else If Bg Then
              Feed := #27'[37m'
            Else
              Feed := #27'[37;40m';
            End;
          End;
        End
      Else If Not (Ch In [#32..#63]) Then
        State := 0;
    End;
  End;


End.
