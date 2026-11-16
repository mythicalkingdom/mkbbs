// file attach netmail that arrives, for tests/tosstest.py:  node tossattach.mjs <dir>
import { MessagePacket } from "../javascript/MessagePacket.js";

const dir = process.argv[2];
const when = new Date(2026, 10, 16, 17, 0, 0);
const m = new MessagePacket({ packet: { origin: "1:110/100", destination: "1:110/290", password: "" } });
await m.setMessagePath(dir + "/0020aaa1.pkt");
async function w(o) {
  await m.startNewMessage();
  Object.assign(m.message, { from: "Remote User", dateTime: when, isPrivate: true, isFileAttach: true, originNetwork: "1:110/100", text: "here is a file\n" }, o);
  await m.writeMessage();
}
await w({ to: "Mark May", subject: "incoming.zip", destinationNetwork: "1:110/290" });       // for us
await w({ to: "Someone", subject: "transit.bin", destinationNetwork: "2:250/1" });           // for another system
