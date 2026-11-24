Unit MKMenus;
{$I MKB.Def}

Interface

Uses MKGlobT, MKRCfgMK;

Const
  MaxMenuItems = 50;


Type MenuArray = Array[0..MaxMenuItems] of MenuType;


Type MenuInfoType = Record
  Error: Word;
  NumItems: Word;
  GlobalItems: Word;
  Sec: SecType;
  Key: Char;
  CurrItem: Word;
  HotString: String;
  Name: String[08];
  End;


Type MenuObj = Object
  Menu: ^MenuArray;
  MenuInfo: ^MenuInfoType;
  Global: ^MenuArray;
  Procedure Init;                           {Initialize}
  Procedure Load(FN: String);               {Load file name}
  Procedure GlobalLoad(FN: String); {Load global menu file name}
  Function  GetName: String;                {Get name of menu}
  Function  GetKey(Item: Word): Char; {Get menu key}
  Function  GetType(Item: Word): Byte;      {Get type of specified item}
  Function  GetPrompt(Item: Word): String;  {Get prompt for specified item}
  Function  GetData(Item: Word): String;    {Get data for specified item}
  Function  GetNormal(Item: Word): Byte; {Get normal attribute}
  Function  GetHi: Byte; {Get highlight attribute}
  Function  GetError: Word;                 {Get error}
  Procedure SetSecurity(Var Sec: SecType);  {Set security level to be used}
  Function  ItemFirst(Key: Char): Word;     {Get first matching menu item}
  Function  ItemNext: Word;                 {Get next matching menu item}
  Function  GetHotKeys: String;             {Get string of hot keys}
  Function  LoadHotKeys: String;            {Initialize hot keys curr menu}
  Function  NumItems: Word; {Number of menu items}
  Function  HasAccess(Item: Word): Boolean; {Has security access to curr item}
  Procedure Done;                           {Done}
  End;


Var
  Menu: MenuObj;

Implementation


Uses MKFile, MKString, MKCfgAbs, MKDoor, MKLogHook,
  Dos;


Function MenuObj.NumItems: Word;
  Begin
  NumItems := MenuInfo^.NumItems + MenuInfo^.GlobalItems;
  End;


Function MenuObj.HasAccess(Item: Word): Boolean;
  Begin
  If Item <= MenuInfo^.NumItems Then
    HasAccess := ((MenuInfo^.Sec.Level >= Menu^[Item].Security) And
     ((MenuInfo^.Sec.Flags and Menu^[Item].Flags) = Menu^[Item].Flags))
  Else
    HasAccess := ((MenuInfo^.Sec.Level >= Global^[Item - MenuInfo^.NumItems].Security) And
     ((MenuInfo^.Sec.Flags and Global^[Item - MenuInfo^.NumItems].Flags) =
     Global^[Item - MenuInfo^.NumItems].Flags));
  End;


Procedure MenuObj.Init;                      {Initialize}
  Begin
  New(Menu);
  New(Global);
  New(MenuInfo);
  MenuInfo^.Error := 0;
  MenuInfo^.HotString := '';
  MenuInfo^.NumItems := 0;
  MenuInfo^.GlobalItems := 0;
  End;


Procedure MenuObj.Load(FN: String);          {Load file name}
  Var
    F: File;
    NumRead: Word;
    MenuPath: String;

  Begin
  If Pos('.',FN) > 0 Then
    FN := Copy(FN, 1, Pos('.', FN) - 1);
  MenuInfo^.Error := 0;
  MenuInfo^.Name := Copy(FN,1,8);
  FN := FN + '.mnu';
  MenuPath := '';
  If FileExist(Config^.GetMnuPath(User.GetUserLanguage) + FN) Then
    MenuPath := Config^.GetMnuPath(User.GetUserLanguage);
  If MenuPath = '' Then
    If FileExist(Config^.GetMnuPath(1) + FN) Then
      MenuPath := Config^.GetMnuPath(1);
  If MenuPath = '' Then
    MenuInfo^.Error := 1000;
  If MenuInfo^.Error = 0 Then
    Begin
    Assign(F, MenuPath + FN);
    FileMode := fmReadOnly + fmDenyNone;
    If Not shReset(F, SizeOf(MenuType)) Then
      MenuInfo^.Error := 1010;
    End;
  If MenuInfo^.Error = 0 Then
    If Not shRead(F, Menu^, MaxMenuItems + 1, MenuInfo^.NumItems) Then
      MenuInfo^.Error := 1020;
  Close(F);
  If IoResult <> 0 Then;
  If MenuInfo^.Error = 0 Then
    Dec(MenuInfo^.NumItems)
  Else
    Begin
    MenuInfo^.NumItems := 0;
    BbsLog('Menu ' + FN + ' could not be loaded (' + LoadWhy(MenuInfo^.Error) + '; looked in ' + Config^.GetMnuPath(User.GetUserLanguage) + Copy(' and ' + Config^.GetMnuPath(1), 1, 200 * Ord(Config^.GetMnuPath(User.GetUserLanguage) <> Config^.GetMnuPath(1))) + ')');
    End;
  MenuInfo^.HotString := LoadHotKeys;
  End;


Procedure MenuObj.GlobalLoad(FN: String);
  Var
    F: File;
    NumRead: Word;
    MenuPath: String;
    Error: Word;

  Begin
  Error := 0;
  If Pos('.',FN) > 0 Then
    FN := Copy(FN, 1, Pos('.', FN) - 1);
  FN := FN + '.mnu';
  MenuPath := '';
  If FileExist(Config^.GetMnuPath(User.GetUserLanguage) + FN) Then
    MenuPath := Config^.GetMnuPath(User.GetUserLanguage);
  If MenuPath = '' Then
    If FileExist(Config^.GetMnuPath(1) + FN) Then
      MenuPath := Config^.GetMnuPath(1);
  If MenuPath = '' Then
    Error := 1000;
  If Error = 0 Then
    Begin
    Assign(F, MenuPath + FN);
    FileMode := fmReadOnly + fmDenyNone;
    If Not shReset(F, SizeOf(MenuType)) Then
      Error := 1010;
    End;
  If Error = 0 Then
    If Not shRead(F, Global^, MaxMenuItems + 1, MenuInfo^.GlobalItems) Then
      Error := 1020;
  Close(F);
  If IoResult <> 0 Then;
  If Error = 0 Then
    Dec(MenuInfo^.GlobalItems)
  Else
    Begin
    MenuInfo^.GlobalItems := 0;
    If Error <> 1000 Then                  {a BBS may have no global menu: only one that is there and cannot be read is a fault}
      BbsLog('Menu ' + FN + ' could not be loaded (' + LoadWhy(Error) + ')');
    End;
  MenuInfo^.HotString := LoadHotKeys;
  End;


Function MenuObj.GetHotKeys: String;
  Begin
  GetHotKeys := MenuInfo^.HotString;
  End;


Function MenuObj.GetName: String;                {Get name of menu}
  Begin
  GetName := MenuInfo^.Name;
  End;


Function MenuObj.GetType(Item: Word): Byte;      {Get type of specified item}
  Begin
  If Item <= MenuInfo^.NumItems Then
    GetType := Menu^[Item].Typ
  Else
    GetType := Global^[Item - MenuInfo^.NumItems].Typ;
  End;


Function MenuObj.GetKey(Item: Word): Char; {Get menu key}
  Begin
  If Item <= MenuInfo^.NumItems Then
    GetKey := Menu^[Item].Key
  Else
    GetKey := Global^[Item - MenuInfo^.NumItems].Key;
  End;


Function MenuObj.GetNormal(Item: Word): Byte;
  Begin
  If Item <= MenuInfo^.NumItems Then
    GetNormal := Menu^[Item].FgColor or (Menu^[Item].BgColor shl 4)
  Else
    GetNormal := Global^[Item - MenuInfo^.NumItems].FgColor
    or (Global^[Item - MenuInfo^.NumItems].BgColor shl 4);
  End;


Function MenuObj.GetHi: Byte;
  Begin
  GetHi := Menu^[0].Typ or (Menu^[0].Security shl 4);;
  End;


Function MenuObj.GetPrompt(Item: Word): String; {Get prompt for specified item}
  Begin
  If Item <= MenuInfo^.NumItems Then
    GetPrompt := Menu^[Item].Prompt
  Else
    GetPrompt := Global^[Item - MenuInfo^.NumItems].Prompt;
  End;


Function MenuObj.GetData(Item: Word): String; {Get data for specified item}
  Begin
  If Item <= MenuInfo^.NumItems Then
    GetData := Menu^[Item].Data
  Else
    GetData := Global^[Item - MenuInfo^.NumItems].Data;
  End;


Function MenuObj.GetError: Word;                 {Get error}
  Begin
  GetError := MenuInfo^.Error;
  End;


Procedure MenuObj.SetSecurity(Var Sec: SecType); {Set security level to be used}
  Begin
  MenuInfo^.Sec := Sec;
  End;


Function MenuObj.ItemFirst(Key: Char): Word; {Get first matching menu item}
  Begin
  MenuInfo^.Key := Key;
  MenuInfo^.CurrItem := 0;
  ItemFirst := ItemNext;
  End;


Function MenuObj.ItemNext: Word;            {Get next matching menu item}
  Var
    Found: Boolean;

  Begin
  Found := False;
  While ((Not Found) and (MenuInfo^.CurrItem <= NumItems)) Do
    Begin
    Inc(MenuInfo^.CurrItem);
    If ((MenuInfo^.Key = GetKey(MenuInfo^.CurrItem)) And
    HasAccess(MenuInfo^.CurrItem)) Then
      Found := True;
    End;
  If Found Then
    ItemNext := MenuInfo^.CurrItem
  Else
    ItemNext := 0;
  End;


Function MenuObj.LoadHotKeys: String;         {Get string of hot keys}
  Var
    TmpStr: String;
    i: Word;

  Begin
  i := 1;
  TmpStr := '';
  While i <= NumItems Do
    Begin
    If (HasAccess(i)) Then
      If GetKey(i) <> #1 Then
        TmpStr := TmpStr + UpCase(GetKey(i));
    Inc(i);
    End;
  TmpStr := TmpStr + ' ' + #13;
  LoadHotKeys := TmpStr;
  End;


Procedure MenuObj.Done;                      {Done}
  Begin
  Dispose(Menu);
  Dispose(Global);
  Dispose(MenuInfo);
  End;


End.
