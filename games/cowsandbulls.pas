program CowsAndBulls;

uses
  Crt;

var
  Secret : string;
  Guess  : string;
  Bulls, Cows : integer;
  Guesses : integer;

function UniqueDigits(S : string) : boolean;
var
  i, j : integer;
begin
  UniqueDigits := true;

  for i := 1 to Length(S)-1 do
    for j := i+1 to Length(S) do
      if S[i] = S[j] then
      begin
        UniqueDigits := false;
        Exit;
      end;
end;

function GenerateSecret : string;
var
  S : string;
  D : char;
begin
  S := '';

  repeat
    D := Chr(Ord('1') + Random(9));   { first digit 1-9 }
    S := D;
  until Length(S) = 1;

  while Length(S) < 4 do
  begin
    D := Chr(Ord('0') + Random(10));
    if Pos(D,S) = 0 then
      S := S + D;
  end;

  GenerateSecret := S;
end;

procedure CountBullsAndCows(Secret, Guess : string;
                            var Bulls, Cows : integer);
var
  i : integer;
begin
  Bulls := 0;
  Cows := 0;

  for i := 1 to 4 do
  begin
    if Guess[i] = Secret[i] then
      Inc(Bulls)
    else if Pos(Guess[i], Secret) > 0 then
      Inc(Cows);
  end;
end;

function ValidGuess(S : string) : boolean;
var
  i : integer;
begin
  ValidGuess := false;

  if Length(S) <> 4 then Exit;

  if S[1] = '0' then Exit;

  for i := 1 to 4 do
    if not (S[i] in ['0'..'9']) then
      Exit;

  if not UniqueDigits(S) then Exit;

  ValidGuess := true;
end;

begin
  Randomize;

  Secret := GenerateSecret;
  Guesses := 0;

  ClrScr;
  Writeln('COWS AND BULLS');
  Writeln;
  Writeln('Guess the 4-digit number.');
  Writeln('All digits are different.');
  Writeln;
  Writeln('Bull = correct digit in correct position');
  Writeln('Cow  = correct digit in wrong position');
  Writeln;

  repeat
    Write('Enter guess: ');
    Readln(Guess);

    if not ValidGuess(Guess) then
    begin
      Writeln('Invalid guess. Enter 4 different digits.');
      Writeln;
      Continue;
    end;

    Inc(Guesses);

    CountBullsAndCows(Secret, Guess, Bulls, Cows);

    Writeln(Bulls, ' Bulls, ', Cows, ' Cows');
    Writeln;

  until Bulls = 4;

  Writeln('Congratulations!');
  Writeln('You found the number ', Secret);
  Writeln('Guesses: ', Guesses);

  Readln;
end.