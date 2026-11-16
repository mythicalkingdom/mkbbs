// the mail that tests/tosstest.py puts in the inbound:  node tosspkts.mjs <dir>
import { MessagePacket } from "../javascript/MessagePacket.js";
import fs from "node:fs";

const dir = process.argv[2];
const when = new Date(2026, 10, 16, 13, 14, 0);

async function packet(name, from, to, fn) {
  const m = new MessagePacket({ packet: { origin: from, destination: to, password: "" }, tearline: "test", originText: "Test System" });
  await m.setMessagePath(dir + "/" + name);
  await fn(async (o) => {
    await m.startNewMessage();
    Object.assign(m.message, { from: "Remote User", to: "All", subject: "subject", dateTime: when, text: "line one\nline two\n" }, o);
    await m.writeMessage();
  });
}

// from the hub (1:110/100), a known system
await packet("0001aaaa.pkt", "1:110/100", "1:110/290", async (w) => {
  await w({ area: "MK", subject: "first mail", msgId: "1:110/100 11111111", kludges: ["PID: Test 1.0"] });
  await w({ area: "MK", subject: "first mail", msgId: "1:110/100 11111111" });                    // the same again
  await w({ area: "mk", subject: "second, tag in lower case", msgId: "1:110/100 22222222" });
  await w({ area: "NOSUCHAREA", subject: "unknown area", msgId: "1:110/100 33333333" });
  await w({ area: "LINUX", subject: "area the hub is not linked to", msgId: "1:110/100 44444444" });
  await w({ area: "MKBETA", subject: "pass-through area", msgId: "1:110/100 55555555" });
  await w({ area: "BBS", subject: "no msgid", to: "Sysop" });
  await w({ subject: "netmail for us", to: "Mark May", originNetwork: "1:110/100", destinationNetwork: "1:110/290", isPrivate: true, msgId: "1:110/100 66666666" });
  await w({ subject: "netmail for 2:250/1", to: "Someone", originNetwork: "1:110/100.5", destinationNetwork: "2:250/1", isPrivate: true, msgId: "1:110/100.5 77777777" });
});
// from a system that is not in the list
await packet("0002bbbb.pkt", "9:9/9", "1:110/290", async (w) => {
  await w({ area: "MK", subject: "from a stranger", msgId: "9:9/9 88888888" });
});
// a second packet from the hub: mail that was there before (duplicate), and new
await packet("0003cccc.pkt", "1:110/100", "1:110/290", async (w) => {
  await w({ area: "MK", subject: "first mail", msgId: "1:110/100 11111111" });
  await w({ area: "MK", subject: "third mail", msgId: "1:110/100 99999999" });
});
fs.writeFileSync(dir + "/notmail.txt", "not a packet\n");
// a file that is called .pkt and is not one
fs.writeFileSync(dir + "/0004dddd.pkt", "this is not a packet at all, not even 58 bytes? no\n");
