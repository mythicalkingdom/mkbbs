"""the small DOS door of the dosemu2 tests: a .COM (INT 14h on COM1) that sends the first 6 bytes of DOOR.SYS, says HELLO FROM DOS, waits for a
character and answers GOT:<it>"""
import struct


def build_door():
    """the door: send the first 6 bytes of DOOR.SYS ("COM1:\\r"), then "HELLO FROM DOS", wait for a character, send GOT: and it, then CR LF; exit"""
    def asm(send, msg, fname, buf):
        c = bytearray()

        def call():
            pos = 0x100 + len(c)
            c.extend(b'\xE8' + struct.pack('<h', send - (pos + 3)))
        c += b'\xBA' + struct.pack('<H', fname) + b'\xB8\x00\x3D\xCD\x21'          # mov dx,fname; mov ax,3D00h; int 21h (open)
        jc = len(c); c += b'\x72\x00'                                               # jc skip
        c += b'\x89\xC3\xBA' + struct.pack('<H', buf) + b'\xB9\x06\x00\xB4\x3F\xCD\x21'  # mov bx,ax; mov dx,buf; mov cx,6; mov ah,3Fh; int 21h
        c += b'\xBE' + struct.pack('<H', buf) + b'\xB9\x06\x00'                     # mov si,buf; mov cx,6
        l0 = 0x100 + len(c)
        c += b'\xAC'                                                                # lodsb
        call()
        pos = 0x100 + len(c); c += b'\xE2' + struct.pack('<b', l0 - (pos + 2))      # loop
        c[jc + 1] = (0x100 + len(c)) - (0x100 + jc + 2)                             # skip:
        c += b'\xBE' + struct.pack('<H', msg)
        l1 = 0x100 + len(c)
        c += b'\xAC\x3C\x24'
        je = len(c); c += b'\x74\x00'
        call()
        pos = 0x100 + len(c); c += b'\xEB' + struct.pack('<b', l1 - (pos + 2))
        l2 = 0x100 + len(c)
        c[je + 1] = l2 - (0x100 + je + 2)
        c += b'\xB4\x02\x31\xD2\xCD\x14\xF6\xC4\x80'                                # receive
        pos = 0x100 + len(c); c += b'\x75' + struct.pack('<b', l2 - (pos + 2))
        c += b'\x50'
        for ch in b'GOT:':
            c += b'\xB0' + bytes([ch]); call()
        c += b'\x58'; call()
        for ch in b'\r\n':
            c += b'\xB0' + bytes([ch]); call()
        c += b'\xB8\x00\x4C\xCD\x21'
        s = 0x100 + len(c)
        c += b'\x50\xB4\x01\x31\xD2\xCD\x14\x58\xC3'                                # send: AL to COM1
        m = 0x100 + len(c)
        c += b'HELLO FROM DOS\r\n$'
        f = 0x100 + len(c)
        c += b'DOOR.SYS\x00'
        b = 0x100 + len(c)
        c += bytes(8)
        return c, s, m, f, b
    r = asm(0, 0, 0, 0)
    r = asm(*r[1:])
    r2 = asm(*r[1:])
    assert r[1:] == r2[1:] and r[0] == r2[0]
    return bytes(r[0])
