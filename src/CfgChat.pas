Unit CfgChat;   {Multi-node chat settings (Chat.Mk); see MCHAT-PLAN.md}

{$I MKB.Def}

Interface

Procedure DoCfgChat;                   {Chat: the switch and the abuse controls}

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgBox;


Procedure DoCfgChat;
  Var
    F: CfgFormObj;
    O: ^ChatCfgType;

  Begin
  If Not Config^.HasChat Then
    Begin
    MsgBox('Multi-node chat is kept by the MK configuration only');
    Exit;
    End;
  New(O);
  Config^.GetChat(O^);
  F.Init('Multi-node Chat');
  F.Window(3, 3, 76, 21);
  F.At(2, 3, 2, 22);
  F.AddYesNo('Chat is on:', O^.Enabled, 'Callers on different nodes can talk to each other in one room. OFF unless you turn it on. Every line is logged; you can watch and remove callers in mkmon');
  F.At(3, 3, 3, 22);
  F.AddString('Room name:', O^.RoomName, 20, 'The name the callers see');
  F.At(4, 3, 4, 22);
  F.AddNumber('Lowest level:', O^.MinLevel, 5, 0, 65535, 'The lowest security level that may join. Raise it to keep new users out until you have looked at them');
  F.At(5, 3, 5, 22);
  F.AddNumber('Line length:', O^.MaxLine, 3, 0, 250, 'Characters in a line (longer is cut), 0 = 160');
  F.At(6, 3, 6, 22);
  F.AddNumber('History lines:', O^.History, 3, 0, 50, 'Lines of the room a caller sees when joining');
  F.At(7, 3, 7, 22);
  F.AddNumber('Minutes per call:', O^.MaxMinutes, 5, 0, 65535, 'Minutes a caller may spend in the room each call, 0 = no limit');
  F.At(9, 3, 9, 22);
  F.AddNumber('Flood: lines:', O^.FloodLines, 3, 0, 255, 'More lines than this within the time below mutes the caller; 0 = no flood limit');
  F.At(10, 3, 10, 22);
  F.AddNumber('Flood: seconds:', O^.FloodSecs, 3, 0, 255, 'The time the lines are counted over');
  F.At(11, 3, 11, 22);
  F.AddNumber('Mute minutes:', O^.MuteMinutes, 3, 0, 255, 'How long a caller who flooded the room cannot speak');
  F.At(13, 3, 13, 22);
  F.AddFile('Word file:', O^.WordFile, 60, 'A text file with a word or phrase on each line; blank = no filter');
  F.At(14, 3, 14, 22);
  F.AddChoice('Word action:', O^.WordAction, 1, 0, 'Mask with *|Refuse the line', 'What happens to a line with a word of the file in it');
  F.At(16, 3, 16, 22);
  F.AddYesNo('Private /msg:', O^.PrivateMsg, 'Callers may send a private line to a node or a user (it is logged like the rest)');
  F.At(17, 3, 17, 22);
  F.AddYesNo('Show handles:', O^.ShowHandle, 'Show the handle instead of the name when the user has one');
  F.At(18, 3, 18, 22);
  F.AddYesNo('Log every line:', O^.LogChat, 'Every line, private ones too, goes to chat.log with the node and the user');
  If F.Execute Then
    Config^.SetChat(O^);
  Dispose(O);
  End;


End.
