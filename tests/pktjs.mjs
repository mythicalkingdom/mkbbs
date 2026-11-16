// MessagePacket.js on the other side of tests/pkttest.py
//   node pktjs.mjs write <file>   the two messages of "pkttest write"
//   node pktjs.mjs read <file>    the packet as JSON
import { MessagePacket } from "../javascript/MessagePacket.js";

const [cmd, file] = process.argv.slice(2);

if (cmd === "write") {
  const m = new MessagePacket({ packet: { origin: "1:110/290", destination: "1:110/100", password: "SECRET" } });
  await m.setMessagePath(file);
  await m.startNewMessage();
  m.message.from = "Mark May"; m.message.to = "All"; m.message.subject = "Café test";
  m.message.area = "TEST.ECHO"; m.message.text = "Hello\nsecond line é\n";
  m.message.msgId = "1:110/290 6a0b0001";
  m.message.dateTime = new Date(2026, 10, 16, 13, 14, 0);
  await m.writeMessage();
  await m.startNewMessage();
  m.message.from = "Mark May"; m.message.to = "Sysop"; m.message.subject = "Net";
  m.message.originNetwork = "1:110/290.2"; m.message.destinationNetwork = "2:250/1.3";
  m.message.msgId = "1:110/290.2 6a0b0002";
  m.message.isPrivate = true; m.message.isCrash = true; m.message.text = "net body\n";
  m.message.dateTime = new Date(2026, 10, 16, 13, 14, 0);
  await m.writeMessage();
} else if (cmd === "read") {
  const m = new MessagePacket();
  await m.setMessagePath(file);
  await m.openMessageBase();
  const out = { packet: m.packetInfo, messages: [] };
  let ok = await m.seekFirst();
  while (ok) {
    const h = m.message;
    out.messages.push({
      number: h.number, from: h.from, to: h.to, subject: h.subject, area: h.area, msgId: h.msgId,
      origin: h.originNetwork, destination: h.destinationNetwork, attr: h.attr, cost: h.cost,
      text: await m.getMessageText(),
    });
    ok = await m.seekNext();
  }
  await m.closeMessageBase();
  console.log(JSON.stringify(out));
}
