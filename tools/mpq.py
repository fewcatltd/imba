import struct, zlib, bz2, sys, os

def _crypt_table():
    t = [0]*0x500; seed = 0x00100001
    for i in range(0x100):
        idx = i
        for _ in range(5):
            seed = (seed*125+3) % 0x2AAAAB; a = (seed & 0xFFFF) << 16
            seed = (seed*125+3) % 0x2AAAAB; b = seed & 0xFFFF
            t[idx] = a | b; idx += 0x100
    return t
CT = _crypt_table()

def hs(s, typ):
    s1, s2 = 0x7FED7FED, 0xEEEEEEEE
    for c in s.upper().replace('/', '\\').encode('latin1'):
        s1 = (CT[(typ << 8) + c] ^ (s1 + s2)) & 0xFFFFFFFF
        s2 = (c + s1 + s2 + (s2 << 5) + 3) & 0xFFFFFFFF
    return s1

def decrypt(data, key):
    s2 = 0xEEEEEEEE; out = bytearray(); n = len(data)//4
    vals = struct.unpack('<%dI' % n, data[:n*4])
    for v in vals:
        s2 = (s2 + CT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        d = (v ^ (key + s2)) & 0xFFFFFFFF
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        s2 = (d + s2 + (s2 << 5) + 3) & 0xFFFFFFFF
        out += struct.pack('<I', d)
    return bytes(out) + data[n*4:]

def explode(data):
    # PKWARE DCL implode decompressor
    import io
    LenBits=[3,2,3,3,4,4,4,5,5,5,5,6,6,6,7,7]
    LenCode=[5,3,1,6,10,2,12,20,4,24,8,48,16,32,64,0]
    ExLenBits=[0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8]
    LenBase=[0,1,2,3,4,5,6,7,8,10,14,22,38,70,134,262]
    DistBits=[2,4,4,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8]
    DistCode=[0x03,0x0D,0x05,0x19,0x09,0x11,0x01,0x3E,0x1E,0x2E,0x0E,0x36,0x16,0x26,0x06,0x3A,0x1A,0x2A,0x0A,0x32,0x12,0x22,0x42,0x02,0x7C,0x3C,0x5C,0x1C,0x6C,0x2C,0x4C,0x0C,0x74,0x34,0x54,0x14,0x64,0x24,0x44,0x04,0x78,0x38,0x58,0x18,0x68,0x28,0x48,0x08,0xF0,0x70,0xB0,0x30,0xD0,0x50,0x90,0x10,0xE0,0x60,0xA0,0x20,0xC0,0x40,0x80,0x00]
    def build(bits, codes):
        d={}
        for i,(b,c) in enumerate(zip(bits,codes)): d[(b,c)]=i
        return d
    LT=build(LenBits,LenCode); DT=build(DistBits,DistCode)
    ctype=data[0]; dsize=data[1]; pos=2; bitbuf=0; nb=0
    def getbits(n):
        nonlocal bitbuf, nb, pos
        while nb < n:
            if pos >= len(data): raise EOFError
            bitbuf |= data[pos] << nb; pos += 1; nb += 8
        v = bitbuf & ((1<<n)-1); bitbuf >>= n; nb -= n; return v
    def decode(table, maxb):
        code=0
        for l in range(1, maxb+1):
            code |= getbits(1) << (l-1)
            if (l,code) in table: return table[(l,code)]
        raise ValueError('bad code')
    out=bytearray()
    try:
        while True:
            if getbits(1):
                li = decode(LT, 7); ln = LenBase[li] + (getbits(ExLenBits[li]) if ExLenBits[li] else 0) + 2
                if ln == 519: break
                di = decode(DT, 8)
                if ln == 2: dist = (di << 2) | getbits(2)
                else: dist = (di << dsize) | getbits(dsize)
                dist += 1
                for _ in range(ln): out.append(out[-dist])
            else:
                if ctype == 0: out.append(getbits(8))
                else: raise NotImplementedError('ascii mode')
    except EOFError: pass
    return bytes(out)

def decompress(buf):
    m = buf[0]; d = buf[1:]
    if m & 0x10: d = bz2.decompress(d)
    if m & 0x08: d = explode(d)
    if m & 0x02: d = zlib.decompress(d)
    if m & ~0x1A: raise NotImplementedError('comp %x' % m)
    return d

class MPQ:
    def __init__(self, path):
        self.f = open(path, 'rb').read()
        off = self.f.find(b'MPQ\x1a')
        while off % 512: off = self.f.find(b'MPQ\x1a', off+1)
        self.off = off
        _, hsz, asz, ver, sshift, hpos, bpos, hcnt, bcnt = struct.unpack('<4sIIHHIIII', self.f[off:off+32])
        self.sector = 512 << (sshift & 0xF if sshift > 15 else sshift)
        if sshift > 15: self.sector = 512 << 3
        self.sector = 512 << sshift
        ht = decrypt(self.f[off+hpos:off+hpos+hcnt*16], hs('(hash table)', 3))
        bt = decrypt(self.f[off+bpos:off+bpos+bcnt*16], hs('(block table)', 3))
        self.hash = [struct.unpack('<IIHHI', ht[i*16:i*16+16]) for i in range(hcnt)]
        self.block = [struct.unpack('<IIII', bt[i*16:i*16+16]) for i in range(bcnt)]
        self.hcnt = hcnt
    def find(self, name):
        i = hs(name, 0) % self.hcnt; a, b = hs(name, 1), hs(name, 2)
        for _ in range(self.hcnt):
            h1, h2, loc, plat, bi = self.hash[i]
            if bi == 0xFFFFFFFF: return None
            if h1 == a and h2 == b and bi != 0xFFFFFFFE and bi < len(self.block): return bi
            i = (i+1) % self.hcnt
        return None
    def read(self, name):
        bi = self.find(name)
        if bi is None: return None
        return self.read_block(bi, name)
    def read_block(self, bi, name=None):
        pos, csize, fsize, flags = self.block[bi]
        if not flags & 0x80000000: return None
        raw = self.f[self.off+pos:self.off+pos+csize]
        key = None
        if flags & 0x10000:
            if name is None: raise ValueError('need name')
            key = hs(name.split('\\')[-1], 3)
            if flags & 0x20000: key = ((key + pos) ^ fsize) & 0xFFFFFFFF
        if flags & 0x1000000:  # single unit
            if key is not None: raw = decrypt(raw, key)
            return decompress(raw) if (flags & 0x200 and csize < fsize) else raw[:fsize]
        if not flags & 0x300:
            if key is not None: raw = decrypt(raw, key)
            return raw[:fsize]
        ns = (fsize + self.sector - 1)//self.sector
        tbl = raw[:(ns+1)*4]
        if key is not None: tbl = decrypt(tbl, (key-1) & 0xFFFFFFFF)
        offs = struct.unpack('<%dI' % (ns+1), tbl[:(ns+1)*4])
        out = bytearray()
        for s in range(ns):
            chunk = raw[offs[s]:offs[s+1]]
            if key is not None: chunk = decrypt(chunk, (key+s) & 0xFFFFFFFF)
            exp = min(self.sector, fsize - s*self.sector)
            if len(chunk) < exp:
                chunk = decompress(chunk) if flags & 0x200 else explode(chunk)
            out += chunk
        return bytes(out[:fsize])
