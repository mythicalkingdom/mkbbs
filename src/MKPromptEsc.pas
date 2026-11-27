{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKPromptEsc;   {Backslash codes in a menu prompt: \n a line break, \f<c> and \k<c> the display codes ^F and ^K, \\ a backslash}

{$I MKB.Def}

{
     A prompt is typed in mkmenu, which does not take control characters, so the codes that a screen holds as control characters have a form that can be typed:

         \n        a line break (carriage return and line feed)
         \f<c>     the user code ^F<c>   (\fA the caller's name, \fO the security level ...)
         \k<c>     the system code ^K<c> (\kO the minutes left, \kZ the current file area ...)
         \\        a backslash
         \t<p><c>  the statistics code ^T<p><c>: a period letter (T W M Y A) and an item letter (MKStatsRead: \tMC the calls of this month)

     Any other backslash is kept as it is (together with the character after it), and so is a \f or \k at the end of the text.  The expanded text goes through the ordinary display (MKCodes), which
     does the rest.
}

Interface

Function ExpandPromptEscapes(S: String): String;

Implementation

Function ExpandPromptEscapes(S: String): String;
  Var
    i: Word;
    R: String;
    C: Char;

  Begin
  R := '';
  i := 1;
  While i <= Length(S) Do
    Begin
    If (S[i] = '\') And (i < Length(S)) Then
      Begin
      C := S[i + 1];
      If C = 'n' Then
        Begin
        R := R + #13#10;
        Inc(i, 2);
        End
      Else If C = '\' Then
        Begin
        R := R + '\';
        Inc(i, 2);
        End
      Else If ((C = 't') Or (C = 'T')) And (i + 3 <= Length(S)) Then
        Begin
        R := R + #20 + S[i + 2] + S[i + 3];
        Inc(i, 4);
        End
      Else If ((C = 'f') Or (C = 'F') Or (C = 'k') Or (C = 'K')) And (i + 2 <= Length(S)) Then
        Begin
        If (C = 'f') Or (C = 'F') Then
          R := R + #6
        Else
          R := R + #11;
        R := R + S[i + 2];
        Inc(i, 3);
        End
      Else
        Begin
        R := R + S[i];
        Inc(i);
        End;
      End
    Else
      Begin
      R := R + S[i];
      Inc(i);
      End;
    End;
  ExpandPromptEscapes := R;
  End;

End.
