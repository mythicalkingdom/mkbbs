program charsettest;
{$mode tp}
{ CP437 <-> UTF-8: the character table, the choice by terminal type, and the translation in DoorUser's text
  output and input on a scripted session whose terminal type can be set. }
uses Dos, MKString, MKFile, MKComAbs, MKDoor, MKCp437;

Type
  TermCom = Object(AbsComObj)
    Inp: String;
    Outp: String;
    Up: Boolean;
    Term: String;
    Constructor Init;
    Function  GetCarrier: Boolean; Virtual;
    Function  InEmpty: Boolean; Virtual;
    Function  GetChar: Char; Virtual;
    Function  PeekChar: Char; Virtual;
    Procedure SendChar(Ch: Char); Virtual;
    Function  GetTermType: String; Virtual;
    Function  GetCommInfo: String; Virtual;
    End;

Constructor TermCom.Init; begin Inherited Init; Inp := ''; Outp := ''; Up := True; Term := ''; end;
Function TermCom.GetCarrier: Boolean; begin GetCarrier := Up; end;
Function TermCom.InEmpty: Boolean; begin InEmpty := Length(Inp) = 0; end;
Function TermCom.GetChar: Char;
  begin if Length(Inp) > 0 then begin GetChar := Inp[1]; Delete(Inp, 1, 1); end else GetChar := #0; end;
Function TermCom.PeekChar: Char; begin if Length(Inp) > 0 then PeekChar := Inp[1] else PeekChar := #0; end;
Procedure TermCom.SendChar(Ch: Char); begin Outp := Outp + Ch; end;
Function TermCom.GetTermType: String; begin GetTermType := Term; end;
Function TermCom.GetCommInfo: String; begin GetCommInfo := 'Terminal test'; end;

var
  Fails: Integer;
  L: TermCom;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
  Flush(Output);
end;

function Hex(S: String): String;
const D: String = '0123456789ABCDEF';
var i: Integer; R: String;
begin R := ''; for i := 1 to Length(S) do R := R + D[Ord(S[i]) shr 4 + 1] + D[Ord(S[i]) and 15 + 1] + ' '; Hex := R; end;

procedure Begin_(Term: String; Mode: Byte);
begin
  User.Done; User.Init;
  L.Init; L.Term := Term; CharsetMode := Mode;
  ComSession := @L;
end;

var i: Integer; S, Enc: String; U: Word; T: Text; Ch: Char; Ok: Boolean;
begin
  { the table }
  Check('ASCII is not touched', Cp437ToUtf8(Ord('A')) = 'A');
  Check('B0 (shade) is U+2591', Cp437ToUtf8($B0) = #$E2#$96#$91);
  Check('C9 (box corner) is U+2554', Cp437ToUtf8($C9) = #$E2#$95#$94);
  Check('CD (double line) is U+2550', Cp437ToUtf8($CD) = #$E2#$95#$90);
  Check('82 (e acute) is U+00E9', Cp437ToUtf8($82) = #$C3#$A9);
  Check('E9 (theta) is U+0398', Cp437ToUtf8($E9) = #$CE#$98);
  Check('FF (no-break space) is U+00A0', Cp437ToUtf8($FF) = #$C2#$A0);
  Ok := True;
  for i := 128 to 255 do begin                         { every code comes back as itself }
    Enc := Cp437ToUtf8(i);
    if Length(Enc) = 2 then U := ((Ord(Enc[1]) and $1F) shl 6) or (Ord(Enc[2]) and $3F)
    else U := ((Ord(Enc[1]) and $0F) shl 12) or ((Ord(Enc[2]) and $3F) shl 6) or (Ord(Enc[3]) and $3F);
    if Utf8ToCp437(U) <> i then Ok := False;
  end;
  Check('all 128 codes round trip through UTF-8', Ok);
  Check('a character CP437 does not have (euro sign) is 0', Utf8ToCp437($20AC) = 0);

  { the terminal type }
  Check('xterm-256color wants UTF-8', TermWantsUtf8('xterm-256color'));
  Check('XTERM, vt100, linux, PuTTY, screen, tmux want UTF-8',
    TermWantsUtf8('XTERM') and TermWantsUtf8('vt100') and TermWantsUtf8('linux') and TermWantsUtf8('PuTTY') and
    TermWantsUtf8('screen.xterm-256color') and TermWantsUtf8('tmux-256color'));
  Check('ANSI-BBS, ANSI, syncterm, pcansi want CP437',
    (Not TermWantsUtf8('ANSI-BBS')) and (Not TermWantsUtf8('ansi')) and (Not TermWantsUtf8('syncterm')) and (Not TermWantsUtf8('PCANSI')));
  Check('an unknown or empty terminal type is left as CP437', (Not TermWantsUtf8('')) and (Not TermWantsUtf8('whatever')));

  User.Init;
  { output }
  S := 'Box '#$C9#$CD#$BB' '#$B0' '#27'[1;31m'#$82;
  Begin_('ANSI-BBS', 0); User.DisplayStr(S);
  Check('ANSI-BBS: the bytes go out as they are', L.Outp = S);
  Begin_('xterm', 0); User.DisplayStr(S);
  Check('xterm: the box characters are UTF-8, the ESC sequence is not touched: ' + Hex(Copy(L.Outp, 1, 16)),
    L.Outp = #27'[37;40mBox '#$E2#$95#$94#$E2#$95#$90#$E2#$95#$97' '#$E2#$96#$91' '#27'[1;31m'#$C3#$A9);
  Begin_('xterm', 0); User.DisplayStr(#27'[0m'#27'[0;1;34m'#27'[0;42mx'#27'[m'#27'[1;31;44my');
  Check('xterm: a colour reset gets light gray / black unless it sets them itself: ' + Hex(Copy(L.Outp, 1, 40)),
    L.Outp = #27'[0m'#27'[37;40m'#27'[0;1;34m'#27'[40m'#27'[0;42m'#27'[37m'+'x'#27'[m'#27'[37;40m'#27'[1;31;44my');
  Begin_('xterm', 1); User.DisplayStr(S);
  Check('forced CP437 (-UCP437) on an xterm: as they are', L.Outp = S);
  Begin_('ANSI-BBS', 2); User.DisplayStr(S);
  Check('forced UTF-8 (-UUTF8) on ANSI-BBS: UTF-8', Pos(#$E2#$95#$94, L.Outp) > 0);
  Begin_('', 0); User.DisplayStr(S);
  Check('an unknown terminal: as they are', L.Outp = S);
  Begin_('xterm', 0); User.DisplayChr(#$C4);
  Check('DisplayChr translates too', L.Outp = #$E2#$94#$80);
  Begin_('xterm', 0); User.DisplayStrLn('plain text');
  Check('plain ASCII is the same on every terminal', L.Outp = 'plain text'#13#10);
  Assign(T, 'cp437file.txt'); Rewrite(T); Write(T, 'File '#$DB#$DB' ok'); Close(T);
  Begin_('xterm', 0); User.DisplayFile('cp437file.txt');
  Check('DisplayFile translates', L.Outp = 'File '#$E2#$96#$88#$E2#$96#$88' ok');
  Begin_('ANSI-BBS', 0); User.DisplayFile('cp437file.txt');
  Check('... and leaves a BBS terminal alone', L.Outp = 'File '#$DB#$DB' ok');
  {$I-} Erase(T); {$I+} if IoResult <> 0 then;

  { input }
  Begin_('xterm', 0); L.Inp := #$C3#$A9;
  Ok := User.InputChr(Ch);
  Check('a UTF-8 caller types e acute (C3 A9): CP437 82', Ok and (Ch = #$82) and (Length(L.Inp) = 0));
  Begin_('xterm', 0); L.Inp := #$E2#$95#$90'x';
  Ok := User.InputChr(Ch);
  Check('a box character typed (E2 95 90): CP437 CD, the next key is untouched', Ok and (Ch = #$CD) and (L.Inp = 'x'));
  Begin_('xterm', 0); L.Inp := #$E2#$82#$AC;
  Ok := User.InputChr(Ch);
  Check('a character CP437 does not have (euro): ?', Ok and (Ch = '?'));
  Begin_('xterm', 0); L.Inp := #$C3'a';
  Ok := User.InputChr(Ch);
  Check('a broken sequence (C3 then a): ?, and the a is still there', Ok and (Ch = '?') and (L.Inp = 'a'));
  Begin_('ANSI-BBS', 0); L.Inp := #$82;
  Ok := User.InputChr(Ch);
  Check('a CP437 caller: the byte is as it is', Ok and (Ch = #$82));
  Begin_('xterm', 0); L.Inp := 'Abc';
  Ok := User.InputChr(Ch);
  Check('ASCII input is unchanged', Ok and (Ch = 'A'));

  CharsetMode := 0;
  writeln('failures: ', Fails);
  Halt(Fails);
end.
