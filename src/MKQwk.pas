{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKQwk;

{$I MKB.Def}

{
     mkqwk [-L<name> | -R<name> | -A | -D | -U] [-P<language>]

     The offline mail door (QWK, Bluewave, text packets): the packet of the user's new mail for download, the replies for
     upload, and the user's settings.  Converted from MKQWK.PAS / MKQWKO.PAS.  Its settings are in config.mko (found as
     config.mko in the current directory or the BBS directory), the user records in users.mko in the directory that file
     names; the BBS is found as for mk (MK, RA, QUICK or SBBS = its configuration directory).

       -L<name>   local: the packet for that user (a blank is _ : Mark_May) is made in the current directory
       -R<name>   local: only the replies of that user
       -A         from the BBS (menu command 007): upload and then download, no menu
       -D         from the BBS: download only
       -U         from the BBS: upload only
       (none)     from the BBS: the menu

     From the BBS it is started by a menu command 007 (it runs on a pseudo terminal, see MKShell), which writes
     DORINFO1.DEF and EXITINFO.BBS for it in the current directory.
}

Uses
  MKQwkO, MKQwkG, MKFile, MKString, MKOpen, MKDoor, MKComAbs, Dos;


Begin
ProcessCmdLine;
If LocalMode Then
  Begin
  WriteLn;
  WriteLn('MKQwk Offline Maildoor - version 1.10');
  WriteLn('  Copyright 1994 by Mark May - Mythical Kingdom Software');
  WriteLn;
  End;
GetDir(0, OrigDir);                    {the current directory}
If LoadQwkCfg Then
  Begin
  MainQwk;
  End
Else
  WriteLn('Unable to load config.mko');
End.
