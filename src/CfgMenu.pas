Unit CfgMenu;   {Main menu of the configuration editor (Free Vision)}

{$I MKB.Def}

{
     The menu tree and hints are those of the Object Professional version.
     Screens that are converted are called from HandleEvent; the others show
     a "not converted yet" box.  DoMenu returns what the sysop chose when
     leaving: 1 = save the changes, 2 = leave them unsaved.
}

Interface

Function DoMenu: Word;

Implementation

Uses Objects, Drivers, Views, Menus, App, MsgBox, MKString, MKGlobT, MKCfgAbs,
  CfgPal, CfgPath, CfgGen, CfgNuser, CfgSec, CfgSec2, CfgPage, CfgResp, CfgEl,
  CfgXfer, CfgEopt, CfgPLan, CfgPAddr, CfgPPack, CfgFArea, CfgOff;

Const
  cmGeneral = 1000;
  cmPaths = 1001;
  cmLanguage = 1002;
  cmNewUsers = 1003;
  cmSecOptions = 1004;
  cmSecNewUser = 1005;
  cmSecAttach = 1006;
  cmSecRequest = 1007;
  cmSecCrash = 1008;
  cmSecForceCrash = 1009;
  cmSecDelete = 1010;
  cmSecUnReceive = 1011;
  cmAddresses = 1012;
  cmPaging = 1013;
  cmModemResp = 1014;
  cmErrorLevels = 1015;
  cmDoors = 1016;
  cmPackers = 1017;
  cmOfflineType = 1018;
  cmMsgAreas = 1019;
  cmMsgOptions = 1020;
  cmOrigin = 1021;
  cmFastCombined = 1022;
  cmFastAnsi = 1023;
  cmFastHiBit = 1024;
  cmFastTaglines = 1025;
  cmFastFido = 1026;
  cmFastTear = 1027;
  cmFastOffline = 1028;
  cmFastForceOff = 1029;
  cmFastDefComb = 1030;
  cmFastReadOrig = 1031;
  cmFastImpPath = 1032;
  cmFastHidePath = 1033;
  cmFastImpSeen = 1034;
  cmFastHideSeen = 1035;
  cmOffCfg = 1036;
  cmFileAreas = 1037;
  cmFileOptions = 1038;
  cmEvents = 1039;
  cmEchoSys = 1040;
  cmEchoOpt = 1041;
  cmQuitCfg = 1042;
  cmQuitDlg = 2000;

Procedure EditConfigSec(Cmd: Word);
  Var
    Sec: SecType;

  Begin
  Case Cmd Of
    cmSecNewUser:    Begin Config^.GetNewUserSec(Sec); EnterSec(Sec, 'New User'); Config^.SetNewUserSec(Sec); End;
    cmSecAttach:     Begin Config^.GetAttachSec(Sec); EnterSec(Sec, 'File Attach'); Config^.SetAttachSec(Sec); End;
    cmSecRequest:    Begin Config^.GetRequestSec(Sec); EnterSec(Sec, 'File Request'); Config^.SetRequestSec(Sec); End;
    cmSecCrash:      Begin Config^.GetCrashNMSec(Sec); EnterSec(Sec, 'Crash NM'); Config^.SetCrashNMSec(Sec); End;
    cmSecForceCrash: Begin Config^.GetForceCrashNMSec(Sec); EnterSec(Sec, 'Force Crash NM'); Config^.SetForceCrashNMSec(Sec); End;
    cmSecDelete:     Begin Config^.GetDeleteSec(Sec); EnterSec(Sec, 'Msg Delete'); Config^.SetDeleteSec(Sec); End;
    cmSecUnReceive:  Begin Config^.GetUnRcvSec(Sec); EnterSec(Sec, 'Msg UnReceive'); Config^.SetUnRcvSec(Sec); End;
    End;
  End;


Type
  CfgApp = Object(TApplication)
    Chosen: Word;
    Constructor Init;
    Procedure InitMenuBar; Virtual;
    Procedure InitStatusLine; Virtual;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Procedure NotYet(Name: String);
    Procedure AskQuit;
    End;

  PCfgStatus = ^CfgStatus;
  CfgStatus = Object(TStatusLine)
    Function Hint(AHelpCtx: Word): String; Virtual;
    End;


Function CfgStatus.Hint(AHelpCtx: Word): String;
  Begin
  Hint := '';
  Case AHelpCtx Of
    cmGeneral: Hint := 'General Set-up';
    cmPaths: Hint := 'Set-up Paths and Directories';
    cmLanguage: Hint := 'Set-up Languages';
    cmNewUsers: Hint := 'Set-up new user defaults';
    cmSecOptions: Hint := 'Security Options';
    cmSecNewUser: Hint := 'New User Security';
    cmSecAttach: Hint := 'File Attach Security';
    cmSecRequest: Hint := 'File Request Security';
    cmSecCrash: Hint := 'Crash Netmail Security';
    cmSecForceCrash: Hint := 'Security to Force Crash Netmail';
    cmSecDelete: Hint := 'Security to Delete Msgs To/From Caller';
    cmSecUnReceive: Hint := 'Security to UnReceive a Message';
    cmAddresses: Hint := 'Set-up System Addresses';
    cmPaging: Hint := 'Set-up Paging options';
    cmModemResp: Hint := 'Modem connect response strings';
    cmErrorLevels: Hint := 'ErrorLevels for Baud rates';
    cmDoors: Hint := 'Doors available from Log-on';
    cmPackers: Hint := 'Archive compression setup';
    cmOfflineType: Hint := 'Offline Mail Packet Types';
    cmMsgAreas: Hint := 'Message area configuration';
    cmMsgOptions: Hint := 'Message Configuration Options';
    cmOrigin: Hint := 'Set Origin Line Text';
    cmFastCombined: Hint := 'Fast Allow Combined Access';
    cmFastAnsi: Hint := 'Fast Allow Ansi';
    cmFastHiBit: Hint := 'Fast Allow Hi-Bit Characters';
    cmFastTaglines: Hint := 'Fast Allow Offline Reader Taglines';
    cmFastFido: Hint := 'Fast Add Fido Info';
    cmFastTear: Hint := 'Fast Allow Offline Reader Tearlines';
    cmFastOffline: Hint := 'Fast Allow Offline Access';
    cmFastForceOff: Hint := 'Fast Force for Offline';
    cmFastDefComb: Hint := 'Fast Default Combined';
    cmFastReadOrig: Hint := 'Fast Use Offline Reader Origin';
    cmFastImpPath: Hint := 'Fast Import Path Line';
    cmFastHidePath: Hint := 'Fast Hide Imported Path Line';
    cmFastImpSeen: Hint := 'Fast Import Seen-By';
    cmFastHideSeen: Hint := 'Fast Hide Imported Seen-By';
    cmOffCfg: Hint := 'Offline mail options/settings';
    cmFileAreas: Hint := 'File Area Configuration';
    cmFileOptions: Hint := 'File Transfer Options Configuration';
    cmEvents: Hint := 'Setup Events';
    cmEchoSys: Hint := 'Systems Exchanging EchoMail';
    cmEchoOpt: Hint := 'EchoMail Options';
    cmQuitCfg: Hint := 'Quit and Save Changes';
    End;
  End;


Constructor CfgApp.Init;
  Begin
  Inherited Init;
  Chosen := 0;
  End;


Procedure CfgApp.InitMenuBar;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
      NewSubMenu('~G~eneral', hcNoContext,
        NewMenu(
          NewItem('~G~eneral', '', kbNoKey, cmGeneral, cmGeneral,
            NewItem('~B~bs Paths', '', kbNoKey, cmPaths, cmPaths,
            NewItem('~L~anguage', '', kbNoKey, cmLanguage, cmLanguage,
            NewItem('~N~ew Users', '', kbNoKey, cmNewUsers, cmNewUsers,
            NewSubMenu('~S~ecurity', hcNoContext,
            NewMenu(
              NewItem('~O~ptions', '', kbNoKey, cmSecOptions, cmSecOptions,
                NewItem('~N~ew User', '', kbNoKey, cmSecNewUser, cmSecNewUser,
                NewItem('~A~ttach', '', kbNoKey, cmSecAttach, cmSecAttach,
                NewItem('~R~equest', '', kbNoKey, cmSecRequest, cmSecRequest,
                NewItem('~C~rash NM', '', kbNoKey, cmSecCrash, cmSecCrash,
                NewItem('~F~orce Crash NM', '', kbNoKey, cmSecForceCrash, cmSecForceCrash,
                NewItem('~D~elete', '', kbNoKey, cmSecDelete, cmSecDelete,
                NewItem('~U~nReceive', '', kbNoKey, cmSecUnReceive, cmSecUnReceive,
                Nil))))))))),
            NewItem('~A~ddresses', '', kbNoKey, cmAddresses, cmAddresses,
            NewItem('~P~aging', '', kbNoKey, cmPaging, cmPaging,
            NewItem('~M~odem Resp', '', kbNoKey, cmModemResp, cmModemResp,
            NewItem('~E~rrorLevels', '', kbNoKey, cmErrorLevels, cmErrorLevels,
            NewItem('~D~oors', '', kbNoKey, cmDoors, cmDoors,
            NewItem('Pa~c~kers', '', kbNoKey, cmPackers, cmPackers,
            NewItem('~O~ffline Type', '', kbNoKey, cmOfflineType, cmOfflineType,
            Nil))))))))))))),
        NewSubMenu('~M~essages', hcNoContext,
        NewMenu(
          NewItem('~A~reas', '', kbNoKey, cmMsgAreas, cmMsgAreas,
            NewItem('~M~sg Options', '', kbNoKey, cmMsgOptions, cmMsgOptions,
            NewItem('~O~rigin Lines', '', kbNoKey, cmOrigin, cmOrigin,
            NewSubMenu('~F~ast Options', hcNoContext,
            NewMenu(
              NewItem('~C~ombined', '', kbNoKey, cmFastCombined, cmFastCombined,
                NewItem('~A~nsi', '', kbNoKey, cmFastAnsi, cmFastAnsi,
                NewItem('~H~i-Bit Chars', '', kbNoKey, cmFastHiBit, cmFastHiBit,
                NewItem('~T~aglines', '', kbNoKey, cmFastTaglines, cmFastTaglines,
                NewItem('~F~ido Info', '', kbNoKey, cmFastFido, cmFastFido,
                NewItem('~R~eader Tearlines', '', kbNoKey, cmFastTear, cmFastTear,
                NewItem('~O~ffline', '', kbNoKey, cmFastOffline, cmFastOffline,
                NewItem('Forc~e~ Offline', '', kbNoKey, cmFastForceOff, cmFastForceOff,
                NewItem('~D~efault Combined', '', kbNoKey, cmFastDefComb, cmFastDefComb,
                NewItem('Reader Or~i~gin', '', kbNoKey, cmFastReadOrig, cmFastReadOrig,
                NewItem('I~m~port Path', '', kbNoKey, cmFastImpPath, cmFastImpPath,
                NewItem('Hide ~P~ath', '', kbNoKey, cmFastHidePath, cmFastHidePath,
                NewItem('Import ~S~een-By', '', kbNoKey, cmFastImpSeen, cmFastImpSeen,
                NewItem('Hide See~n~-By', '', kbNoKey, cmFastHideSeen, cmFastHideSeen,
                Nil))))))))))))))),
            NewItem('Off~l~ine', '', kbNoKey, cmOffCfg, cmOffCfg,
            Nil)))))),
        NewSubMenu('~F~iles', hcNoContext,
        NewMenu(
          NewItem('~A~reas', '', kbNoKey, cmFileAreas, cmFileAreas,
            NewItem('~O~ptions', '', kbNoKey, cmFileOptions, cmFileOptions,
            Nil))),
        NewItem('~E~vents', '', kbNoKey, cmEvents, cmEvents,
        NewSubMenu('E~c~hoMail', hcNoContext,
        NewMenu(
          NewItem('~S~ystems', '', kbNoKey, cmEchoSys, cmEchoSys,
            NewItem('~O~ptions', '', kbNoKey, cmEchoOpt, cmEchoOpt,
            Nil))),
        NewItem('~Q~uit', '', kbNoKey, cmQuitCfg, cmQuitCfg,
        Nil))))))
    )));
  End;


Procedure CfgApp.InitStatusLine;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New(PCfgStatus, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F10~ Menu', kbF10, cmMenu,
      NewStatusKey('~Alt-X~ Quit', kbAltX, cmQuitDlg, Nil)),
    Nil)));
  End;


Procedure CfgApp.NotYet(Name: String);
  Begin
  MessageBox('"' + Name + '" has not been converted to Free Vision yet.',
    Nil, mfInformation + mfOKButton);
  End;


Procedure CfgApp.AskQuit;
  Begin
  Case MessageBox('Save the changes to the configuration?', Nil,
    mfConfirmation + mfYesNoCancel) Of
    cmYes: Begin Chosen := 1; EndModal(cmQuit); End;
    cmNo: Begin Chosen := 2; EndModal(cmQuit); End;
    End;
  End;


Procedure CfgApp.HandleEvent(Var Event: TEvent);
  Begin
  Inherited HandleEvent(Event);
  If Event.What = evCommand Then
    Begin
    Case Event.Command Of
      cmQuitDlg, cmQuitCfg: AskQuit;
      cmPaths: DoCfgPath;
      cmGeneral: DoCfgGen;
      cmLanguage: DoCfgPLan;
      cmNewUsers: DoCfgNUser;
      cmSecOptions: DoCfgSec;
      cmSecNewUser, cmSecAttach, cmSecRequest, cmSecCrash, cmSecForceCrash,
      cmSecDelete, cmSecUnReceive: EditConfigSec(Event.Command);
      cmAddresses: DoCfgPAddr;
      cmPaging: DoCfgPage;
      cmModemResp: DoCfgResp;
      cmErrorLevels: DoCfgEL;
      cmDoors: NotYet('Doors');
      cmPackers: DoCfgPPack;
      cmOfflineType: DoCfgOffType;
      cmMsgAreas: NotYet('Areas');
      cmMsgOptions: NotYet('Msg Options');
      cmOrigin: NotYet('Origin Lines');
      cmFastCombined: NotYet('Combined');
      cmFastAnsi: NotYet('Ansi');
      cmFastHiBit: NotYet('Hi-Bit Chars');
      cmFastTaglines: NotYet('Taglines');
      cmFastFido: NotYet('Fido Info');
      cmFastTear: NotYet('Reader Tearlines');
      cmFastOffline: NotYet('Offline');
      cmFastForceOff: NotYet('Force Offline');
      cmFastDefComb: NotYet('Default Combined');
      cmFastReadOrig: NotYet('Reader Origin');
      cmFastImpPath: NotYet('Import Path');
      cmFastHidePath: NotYet('Hide Path');
      cmFastImpSeen: NotYet('Import Seen-By');
      cmFastHideSeen: NotYet('Hide Seen-By');
      cmOffCfg: NotYet('Offline');
      cmFileAreas: DoCfgFArea;
      cmFileOptions: DoCfgXfer;
      cmEvents: NotYet('Events');
      cmEchoSys: NotYet('Systems');
      cmEchoOpt: DoCfgEOpt;
      Else Exit;
      End;
    ClearEvent(Event);
    End;
  End;


Function DoMenu: Word;
  Var
    A: CfgApp;

  Begin
  MaroonOn;
  A.Init;
  A.Run;
  DoMenu := A.Chosen;
  A.Done;
  MaroonOff;
  End;


End.
