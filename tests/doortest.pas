program doortest;
{$mode tp}
{ MKVCrt (virtual screen), MKScrn, MKAvatar (ANSI), MKMusic and MKDoor on a
  loopback session. }
uses Dos, MKString, MKFile, MKVCrt, MKScrn, MKAvatar, MKMusic, MKComAbs, MKDoor;

Type
  LoopCom = Object(AbsComObj)
    Inp: String;
    Outp: String;
    Up: Boolean;
    Constructor Init;
    Function  GetCarrier: Boolean; Virtual;
    Procedure Hangup; Virtual;
    Function  InEmpty: Boolean; Virtual;
    Function  GetChar: Char; Virtual;
    Function  PeekChar: Char; Virtual;
    Procedure SendChar(Ch: Char); Virtual;
    Function  GetCommInfo: String; Virtual;
    End;

Constructor LoopCom.Init; begin Inherited Init; Inp := ''; Outp := ''; Up := True; end;
Function LoopCom.GetCarrier: Boolean; begin GetCarrier := Up; end;
Procedure LoopCom.Hangup; begin Up := False; end;
Function LoopCom.InEmpty: Boolean; begin InEmpty := Length(Inp) = 0; end;
Function LoopCom.GetChar: Char;
  begin if Length(Inp) > 0 then begin GetChar := Inp[1]; Delete(Inp, 1, 1); end else GetChar := #0; end;
Function LoopCom.PeekChar: Char; begin if Length(Inp) > 0 then PeekChar := Inp[1] else PeekChar := #0; end;
Procedure LoopCom.SendChar(Ch: Char); begin Outp := Outp + Ch; end;
Function LoopCom.GetCommInfo: String; begin GetCommInfo := 'Loopback'; end;

Type
  WinCom = Object(LoopCom)
    Cols, Rows, Ver: Word;
    Function  GetWindowSize(Var C, R: Word): Boolean; Virtual;
    Function  WindowVersion: Word; Virtual;
    End;
Function WinCom.GetWindowSize(Var C, R: Word): Boolean;
  begin C := Cols; R := Rows; GetWindowSize := (Cols > 0) and (Rows > 0); end;
Function WinCom.WindowVersion: Word; begin WindowVersion := Ver; end;

var
  Fails: Integer;
  L: LoopCom;
  WC: WinCom;
  S: String;
  i: Integer;
  Pt: Pointer;
  T: Text;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
  Flush(Output);
end;

function Row(Y: Byte): String;       { characters of one screen row }
var X: Byte; R: String;
begin
  R := '';
  for X := 1 to ScrnWidth do R := R + Chr(Lo(GetScrnWord(X, Y)));
  while (Length(R) > 0) and (R[Length(R)] = ' ') do Dec(R[0]);
  Row := R;
end;

begin
  { virtual screen and the Crt calls }
  Check('screen 80x25', (VCols = 80) and (VRows = 25) and (ScrnWidth = 80) and (ScrnHeight = 25));
  ClrScr;
  Write(VOut, 'Hello');
  Check('Write(VOut)', (Row(1) = 'Hello') and (WhereX = 6) and (WhereY = 1));
  WriteLn(VOut, ' world');
  Check('WriteLn moves down', (Row(1) = 'Hello world') and (WhereX = 1) and (WhereY = 2));
  GotoXY(10, 5); TextAttr := $1F; Write(VOut, 'X');
  Check('GotoXY + attribute', (GetScrnWord(10, 5) = Ord('X') + $1F00));
  Check('#8 backspace', true);
  Write(VOut, 'AB'#8'C');
  Check('backspace overwrites', (Chr(Lo(GetScrnWord(11, 5))) = 'A') and (Chr(Lo(GetScrnWord(12, 5))) = 'C'));
  TextAttr := $07;
  Window(5, 5, 10, 7); ClrScr;
  Check('window cursor is relative', (WhereX = 1) and (WhereY = 1));
  Write(VOut, '123456789');
  Check('wraps inside the window', (WhereX = 4) and (WhereY = 2));
  Write(VOut, #13#10#13#10#13#10);
  Check('scrolls inside the window', WhereY = 3);
  Window(1, 1, 80, 25);
  GotoXY(1, 25); WriteLn(VOut, 'bottom'); Write(VOut, 'x');
  Check('scrolls the screen at the bottom', (Row(24) = 'bottom'));
  { MKScrn }
  ClrScr; Write(VOut, 'saveme');
  Check('SaveScrnRegion', SaveScrnRegion(1, 1, 10, 2, Pt));
  ClrScr; Check('cleared', Row(1) = '');
  RestoreScrnRegion(1, 1, 10, 2, Pt);
  Check('RestoreScrnRegion', Row(1) = 'saveme');
  ClrScr; GotoXY(1, 1); WriteLn(VOut, 'one'); WriteLn(VOut, 'two'); WriteLn(VOut, 'three');
  ScrollScrnRegionUp(1, 1, 10, 3, 1);
  Check('ScrollScrnRegionUp', (Row(1) = 'two') and (Row(2) = 'three') and (Row(3) = ''));
  ScrollScrnRegionDown(1, 1, 10, 3, 1);
  Check('ScrollScrnRegionDown', (Row(1) = '') and (Row(2) = 'two') and (Row(3) = 'three'));
  { MKAvatar: ANSI }
  ClrScr; GotoXY(1, 1); TextAttr := $07;
  AvStr(#27'[2J'#27'[3;5HHi'#27'[1;31mRed'#27'[0mZ');
  Check('ANSI cursor position + text', Row(3) = '    HiRedZ');
  Check('ANSI colour: bright red', Lo(GetScrnWord(7, 3)) = Ord('R'));
  Check('ANSI attribute', Hi(GetScrnWord(7, 3)) = $0C);
  Check('ANSI reset', Hi(GetScrnWord(10, 3)) = $07);
  AvStr(#27'[2J'); Check('ANSI clear screen', (Row(3) = '') and (WhereX = 1) and (WhereY = 1));
  AvStr(#27'[5B'#27'[10CX');
  Check('ANSI cursor down/forward', Chr(Lo(GetScrnWord(11, 6))) = 'X');
  AvStr(#27'[20A');
  Check('ANSI cursor up stops at the top', WhereY = 1);
  Check('AnsiColor', AnsiColor(7, 0) <> '');
  Check('not inside an escape', not InAvatar);
  PlayInit; Play('T120 O3 L8 CDEFG');
  Check('Play does not sound or wait', SoundHz = 0);
  { MKDoor on a loopback session }
  L.Init;
  ComSession := @L;
  User.Init;
  ClrScr;
  User.DisplayStr('Hello caller');
  Check('DisplayStr reaches the caller', L.Outp = 'Hello caller');
  Check('DisplayStr also drawn locally', Row(1) = 'Hello caller');
  User.DisplayNewLine;
  User.DisplayStrLn('line two');
  Check('DisplayStrLn', (Copy(L.Outp, 13, 2) = #13#10) and (Row(2) = 'line two'));
  L.Inp := 'x';
  S := ''; 
  Check('CheckHot', User.CheckHot('XYZ') = 'X');
  L.Inp := 'abc'#13;
  S := User.InputStr('', 10);
  Check('InputStr', S = 'abc');
  Check('still ok', User.OK);
  L.Up := False;
  User.CheckInput;
  Check('lost carrier detected', not User.OK and (User.GetNotOkReason = 3));
  L.Up := True;
  { drop file, written in lower case; ReadDorInfo asks for DORINFO1.DEF }
  Assign(T, WithBackSlash(ParamStr(1)) + 'dorinfo1.def'); Rewrite(T);
  writeln(T, 'Test BBS'); writeln(T, 'Sys'); writeln(T, 'Op'); writeln(T, 'COM1');
  writeln(T, '38400 BAUD,N,8,1'); writeln(T, '0'); writeln(T, 'Jane'); writeln(T, 'Doe');
  writeln(T, 'Cincinnati'); writeln(T, '1'); writeln(T, '50'); writeln(T, '45');
  Close(T);
  User.ReadDorInfo(WithBackSlash(ParamStr(1)));
  Check('ReadDorInfo: caller is remote', DoorRemote);
  Check('ReadDorInfo: baud', User.UserInfo^.ExitInfo.Baud = 38400);
  Check('ReadDorInfo: time limit', User.UserInfo^.TimeLimit = 2700);
  Erase(T);
  { the caller's window size sets the screen length of the session }
  WC.Init; WC.Cols := 0; WC.Rows := 0; WC.Ver := 0;
  ComSession := @WC;
  User.SetUserScrLength(20);
  Check('no report: the stored screen length', User.GetUserScrLength = 20);
  WC.Cols := 80; WC.Rows := 30; WC.Ver := 1;
  Check('report: rows - 1 for the prompt', User.GetUserScrLength = 29);
  Check('the record keeps its own value', User.UserInfo^.ExitInfo.User.ScrnLen = 20);
  User.UserInfo^.CurrLines := 28;
  User.CheckMore;
  Check('more prompt counts at the new length (not yet at 29)', User.UserInfo^.CurrLines = 29);
  WC.Rows := 50; WC.Ver := 2;
  Check('resize is followed', User.GetUserScrLength = 49);
  WC.Rows := 200; WC.Ver := 3;
  Check('limited to 66', User.GetUserScrLength = 66);
  WC.Rows := 3; WC.Ver := 4;
  Check('absurd height keeps the last good value', User.GetUserScrLength = 66);
  User.SetUserScrLength(40);
  Check('an explicit choice wins', User.GetUserScrLength = 40);
  User.SetUserScrLength(23);
  User.DetectWindow;
  Check('DetectWindow for a new user: unknown height keeps 23 (rows 3)', User.GetUserScrLength = 23);
  WC.Rows := 25; WC.Ver := 5;
  User.SetUserScrLength(23);
  User.DetectWindow;
  Check('DetectWindow for a new user takes the window', User.GetUserScrLength = 24);
  ComSession := @L;
  User.Done;
  ComSession := Nil;
  writeln('failures: ', Fails);
  Halt(Fails);
end.
