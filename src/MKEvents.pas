Program MKEvents;

{$I MKB.Def}

{
     mkevents

     Prints the events of the BBS configuration (MK, or MKJSON, as for the other programs) for mklisten, which runs them:

        BBS <TAB> /directory/of/the/bbs/
        EVENT <TAB> n <TAB> status <TAB> minutes <TAB> days <TAB> errorlevel <TAB> forced <TAB> action <TAB> flags <TAB>
              late <TAB> latemin <TAB> latemax <TAB> timeout <TAB> command

     for every event that is not deleted, and, before it, for a hub pass (action 3) its map file:

        MAP <TAB> n <TAB> /directory/ID.map

     for every event that is not deleted.  status 1 = enabled, 2 = disabled; minutes = the time of day in minutes (0..1440);
     days = the bit mask (Sunday = 1); forced 0 normal, 1 forced, 2 delayable; the rest as EventExtType (MKGlobT, Events.Mk).
     Exit status 1 when the configuration cannot be loaded.  See EVENTS-PLAN.md.
}

Uses
  MKString, MKGlobT, MKCfgAbs, MKCfgMK, MKCfgNew;

Const
  Tab = #9;

Var
  Ext: ^EventsCfgType;
  n, Max: Word;
  T: Word;
  BbsPath: String;

Begin
Config := NewMKConfig(False);
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'mkevents: no configuration: set MK to the BBS configuration directory');
  Halt(1);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn(StdErr, 'mkevents: the configuration could not be loaded (', Config^.GetError, ')');
  Halt(1);
  End;
New(Ext);
Config^.GetEventExt(Ext^);
BbsPath := Config^.GetBbsPath;
If (BbsPath <> '') And (BbsPath[Length(BbsPath)] <> '/') Then
  BbsPath := BbsPath + '/';
WriteLn('BBS', Tab, BbsPath);
Max := Config^.GetMaxEvents;
If Max > MaxEventExt Then
  Max := MaxEventExt;
For n := 1 To Max Do
  If Config^.GetEventStatus(n) <> esDeleted Then
    Begin
    If Ext^.Ev[n].Action = eaHubPass Then            {the map file of the hub: its retry settings are read by mklisten}
      WriteLn('MAP', Tab, n, Tab, Config^.FindBbsFile(Ext^.Ev[n].Cmd + '.map'), Ext^.Ev[n].Cmd, '.map');
    T := Config^.GetEventTime(n);
    WriteLn('EVENT', Tab, n, Tab, Config^.GetEventStatus(n), Tab, Hi(T) * 60 + Lo(T), Tab, Config^.GetEventDays(n), Tab,
      Config^.GetEventEL(n), Tab, Config^.GetEventForced(n), Tab, Ext^.Ev[n].Action, Tab, Ext^.Ev[n].Flags, Tab,
      Ext^.Ev[n].Late, Tab, Ext^.Ev[n].LateMin, Tab, Ext^.Ev[n].LateMax, Tab, Ext^.Ev[n].TimeoutMin, Tab, Ext^.Ev[n].Cmd);
    End;
End.
