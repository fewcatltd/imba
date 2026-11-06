"""Rebuild a protected WC3 MPQ into a clean one (like normal maps): no encryption, zlib only, no junk blocks.
Unnamed encrypted files: key recovered from the known first dword of the sector offset table."""
import struct, zlib, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import MPQ, hs, CT, decrypt, decompress, explode
M = 0xFFFFFFFF

def encrypt(data, key):
    s2 = 0xEEEEEEEE; out = bytearray(); n = len(data)//4
    for (v,) in struct.iter_unpack('<I', data[:n*4]):
        s2 = (s2 + CT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        e = (v ^ (key + s2)) & 0xFFFFFFFF
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        s2 = (v + s2 + (s2 << 5) + 3) & 0xFFFFFFFF
        out += struct.pack('<I', e)
    return bytes(out) + data[n*4:]

def recover_table_key(raw, csize, ns):
    e0, = struct.unpack('<I', raw[:4])
    want0 = 4*(ns+1)
    for b in range(256):
        seed2 = (0xEEEEEEEE + CT[0x400 + b]) & M
        k = ((e0 ^ want0) - seed2) & M
        if k & 0xFF != b: continue
        dec = struct.unpack('<%dI' % (ns+1), decrypt(raw[:4*(ns+1)], k))
        if dec[0] == want0 and dec[-1] == csize and all(dec[i] <= dec[i+1] for i in range(ns)):
            return (k + 1) & M
    return None

def plain_data(m, bi, name):
    pos, csize, fsize, flags = m.block[bi]
    if name is not None:
        return m.read_block(bi, name), 'named'
    if not flags & 0x10000:
        return m.read_block(bi, None), 'plain'
    raw = m.f[m.off+pos: m.off+pos+csize]
    if not flags & 0x300:
        return None, 'encrypted-uncompressed-unnamed'
    ns = (fsize + m.sector - 1)//m.sector
    key = recover_table_key(raw, csize, ns)
    if key is None:
        return None, 'key-not-found'
    offs = struct.unpack('<%dI' % (ns+1), decrypt(raw[:4*(ns+1)], (key-1) & M))
    out = bytearray()
    for s in range(ns):
        chunk = decrypt(raw[offs[s]:offs[s+1]], (key+s) & M)
        exp = min(m.sector, fsize - s*m.sector)
        if len(chunk) < exp:
            chunk = decompress(chunk) if flags & 0x200 else explode(chunk)
        out += chunk
    return bytes(out[:fsize]), 'key-recovered'

def pack_file(data, sector):
    fsize = len(data); ns = max(1, (fsize + sector - 1)//sector)
    secs = []
    for s in range(ns):
        chunk = data[s*sector:(s+1)*sector]
        c = b'\x02' + zlib.compress(chunk, 9)
        secs.append(c if len(c) < len(chunk) else chunk)
    if fsize == 0 or all(len(c) == min(sector, fsize - i*sector) for i, c in enumerate(secs)):
        return data, 0x80000000                        # store uncompressed like normal maps do
    offs = [4*(ns+1)]
    for c in secs: offs.append(offs[-1]+len(c))
    return struct.pack('<%dI' % (ns+1), *offs) + b''.join(secs), 0x80000200

def rebuild(src, dst, replacements, extra_names=()):
    m = MPQ(src)
    names = [n for n in (m.read('(listfile)') or b'').decode('latin1').splitlines() if n.strip()] + list(extra_names)
    byblock = {}
    for n in names:
        bi = m.find(n)
        if bi is not None: byblock.setdefault(bi, n)
    repl_bi = {m.find(n): d for n, d in replacements.items()}
    hdr512 = bytearray(m.f[:m.off])
    sshift = struct.unpack('<H', m.f[m.off+14:m.off+16])[0]
    sector = 512 << sshift
    used = sorted({h[4] for h in m.hash if h[4] < len(m.block)})
    newidx = {}; blocks = []; body = bytearray(); report = {}; raw_copied = []
    for bi in used:
        pos, csize, fsize, flags = m.block[bi]
        if bi in repl_bi:
            data, how = repl_bi[bi], 'replaced'
        else:
            data, how = plain_data(m, bi, byblock.get(bi))
        report[how] = report.get(how, 0) + 1
        p = 32 + len(body)
        if data is None:
            # cannot decrypt: copy raw bytes; allowed only when the key does not depend on position
            assert not flags & 0x20000, (bi, hex(flags))
            body += m.f[m.off+pos: m.off+pos+csize]
            blocks.append((p, csize, fsize, flags)); raw_copied.append(bi)
        else:
            stored, fl = pack_file(data, sector)
            body += stored
            blocks.append((p, len(stored), len(data), fl))
        newidx[bi] = len(blocks)-1
    hpos = 32 + len(body)
    hraw = bytearray()
    for h1, h2, loc, plat, bi in m.hash:
        if bi < len(m.block) and bi in newidx: nbi = newidx[bi]
        elif bi in (0xFFFFFFFF, 0xFFFFFFFE): nbi = bi
        else: h1 = h2 = 0xFFFFFFFF; loc = 0xFFFF; plat = 0xFFFF; nbi = 0xFFFFFFFF   # junk pointer -> empty slot
        hraw += struct.pack('<IIHHI', h1, h2, loc, plat, nbi)
    henc = encrypt(bytes(hraw), hs('(hash table)', 3))
    bpos = hpos + len(henc)
    benc = encrypt(b''.join(struct.pack('<IIII', *b) for b in blocks), hs('(block table)', 3))
    asz = bpos + len(benc)
    mpqh = struct.pack('<4sIIHHIIII', b'MPQ\x1a', 32, asz, 0, sshift, hpos, bpos, len(m.hash), len(blocks))
    open(dst, 'wb').write(bytes(hdr512) + mpqh + bytes(body) + henc + benc)
    return report, raw_copied, newidx
