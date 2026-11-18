// MessageQWK.js on the other side of tests/qwkmsgtest.py
//   node qwkjs.mjs write <file> [rep]   the messages of "qwkmsgtest write"
//   node qwkjs.mjs read <file> [rep]    the file as JSON
import { MessageQWK } from "../javascript/MessageQWK.js";

const [cmd, file, mode] = process.argv.slice(2);
const rep = mode === "rep";

if (cmd === "write") {
  const m = new MessageQWK({ bbsId: "MKBBS", repMode: rep, mailType: rep ? "echomail" : "normal" });
  await m.setMessagePath(file);
  await m.createMessageBase();
  await m.openMessageBase();
  await m.startNewMessage();
  Object.assign(m.message, {
    from: "Mark May", to: "All", subject: "Café test", conference: 7, msgId: "1:110/290 6a0b0001",
    text: "Hello\nsecond line é\n", dateTime: new Date(2026, 10, 16, 13, 14, 0),
  });
  await m.writeMessage();
  await m.startNewMessage();
  Object.assign(m.message, {
    from: "Mark May", to: "Sysop", subject: "Reply", conference: 7, reference: 1, isPrivate: true,
    replyId: "1:110/290 6a0b0001", msgId: "1:110/290 6a0b0002", text: "reply body\n", dateTime: new Date(2026, 10, 16, 13, 15, 0),
  });
  await m.writeMessage();
  await m.startNewMessage();
  Object.assign(m.message, {
    from: "Mark May", to: "Bob", subject: "Other conference", conference: 12, isPrivate: true, isReceived: true,
    text: "three\n\nlines\n", dateTime: new Date(2026, 10, 17, 9, 5, 0),
  });
  await m.writeMessage();
  await m.closeMessageBase();
} else if (cmd === "read") {
  const m = new MessageQWK({ repMode: rep });
  await m.setMessagePath(file);
  await m.openMessageBase();
  const out = { info: await m.getBaseInfo(), messages: [] };
  let ok = await m.seekFirst();
  while (ok) {
    const h = m.message;
    const text = await m.getMessageText();
    out.messages.push({
      number: h.number, conference: h.conference, from: h.from, to: h.to, subject: h.subject, reference: h.reference,
      isPrivate: h.isPrivate, isReceived: h.isReceived, msgId: h.msgId, replyId: h.replyId, text,
      date: h.dateTime && h.dateTime.getTime(),
    });
    ok = await m.seekNext();
  }
  await m.closeMessageBase();
  console.log(JSON.stringify(out));
}
