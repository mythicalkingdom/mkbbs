{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CompDt;

Interface

Function GetCompileDate: String;

Implementation

{$I Compiled.Inc}

Function GetCompileDate: String;
  Begin
  GetCompileDate := Compiled;
  End;

End.
