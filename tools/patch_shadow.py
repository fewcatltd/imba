"""WC3 1.31 refuses a `local` that redeclares a function parameter (1.26 allowed it).
Rename such locals (and their later uses inside the same function) to IMBA131_<fn>_<name>.
Semantics kept: in 1.26 the local simply overwrote the parameter slot from the point of declaration,
so code before the declaration (incl. earlier local initializers) saw the parameter, code after saw the local."""
import re, sys

def fix(text):
    out = []; changed = []
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        l = lines[i]
        m = re.match(r'^function (\w+) takes (.*?) returns \w+', l)
        if not m or m.group(2).strip() == 'nothing':
            out.append(l); i += 1; continue
        fn = m.group(1)
        params = [p.split()[-1] for p in m.group(2).split(',')]
        j = i + 1
        while not lines[j].startswith('endfunction'): j += 1
        body = lines[i+1:j]
        ren = {}
        nb = []
        for bl in body:
            lm = re.match(r'^(\s*local\s+\w+\s+(?:array\s+)?)(\w+)(.*)$', bl)
            if lm and lm.group(2) in params and lm.group(2) not in ren:
                old = lm.group(2); new = 'IMBA131_%s_%s' % (fn, old)
                # initializer of this very local still sees the parameter
                init = lm.group(3)
                for o, n in ren.items(): init = re.sub(r'\b%s\b' % o, n, init)
                ren[old] = new; changed.append((fn, old, new))
                nb.append(lm.group(1) + new + init); continue
            for o, n in ren.items():
                # do not touch string literals
                parts = re.split(r'("(?:[^"\\]|\\.)*")', bl)
                bl = ''.join(p if k % 2 else re.sub(r'(?<![\'\w])%s(?![\w\'])' % o, n, p) for k, p in enumerate(parts))
            nb.append(bl)
        out.append(l); out += nb; out.append(lines[j])
        i = j + 1
    return '\n'.join(out), changed

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    t = open(src, 'rb').read().decode('utf-8')
    t2, ch = fix(t)
    open(dst, 'wb').write(t2.encode('utf-8'))
    for c in ch: print('renamed', *c)
