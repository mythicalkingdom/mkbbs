// Areafix requests for tests/tosstest.py:  node tossareafix.mjs <dir>
import { MessagePacket } from "../javascript/MessagePacket.js";

const dir = process.argv[2];
const when = new Date(2026, 10, 16, 15, 0, 0);

async function packet(name, from, pwd, fn) {
  const m = new MessagePacket({ packet: { origin: from, destination: "1:110/290", password: pwd } });
  await m.setMessagePath(dir + "/" + name);
  await fn(async (o) => {
    await m.startNewMessage();
    Object.assign(m.message, { from: "Remote Sysop", subject: "pw2", dateTime: when, destinationNetwork: "1:110/290", isPrivate: true }, o);
    await m.writeMessage();
  });
}

// system 2, packet password right
await packet("0010aaa1.pkt", "1:110/200", "pktpw2", async (w) => {
  await w({ to: "Areafix", originNetwork: "1:110/200", subject: "pw2",
            text: "%QUERY\n-MK\n+BBS\n+NOSUCH\n+DAYTON_SYSOP\n-MKBETA\nday*_newsys\n%FROB\n--- tear line\n+LINUX\n" });
  await w({ to: "AreaMgr", originNetwork: "1:110/200", subject: "WRONG", text: "+LINUX\n" });
  await w({ to: "Areafix", originNetwork: "5:5/5", subject: "pw2", text: "+LINUX\n" });         // a sender that is not a system of ours
});
// system 1 (the hub), no packet password set for it
await packet("0010bbb1.pkt", "1:110/100", "", async (w) => {
  await w({ to: "areafix", originNetwork: "1:110/100", subject: "SECRET", text: "%LIST\n+LINUX\n-MK\n" });
});
// system 2 with the wrong packet password
await packet("0010ccc1.pkt", "1:110/200", "badpw", async (w) => {
  await w({ to: "Areafix", originNetwork: "1:110/200", subject: "pw2", text: "-DAYTON_SYSOP\n" });
});
