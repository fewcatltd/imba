import re
DEF={'integer':'0','real':'0.','boolean':'false','string':'""'}
def functions(t):
    """return list of (name, start_idx, end_idx(after endfunction line), returns) in order"""
    out=[]
    for m in re.finditer(r'^(constant\s+)?function\s+(\w+)\s+takes\s+.*?\s+returns\s+(\w+)\s*\r?$', t, re.M):
        e=t.index('\nendfunction', m.end())
        e2=t.index('\n', e+1) if t.find('\n',e+1)>=0 else len(t)
        out.append((m.group(2), m.start(), e2, m.group(3), m.end()))
    return out
def stub(t, keep):
    fs=functions(t); res=[]; last=0
    for name,s,e,ret,hend in fs:
        res.append(t[last:s])
        if name in keep:
            res.append(t[s:e])
        else:
            nl='\r\n'
            body = '' if ret=='nothing' else 'return %s%s' % (DEF.get(ret,'null'), nl)
            res.append(t[s:hend] + '\n' + body + 'endfunction\r')
        last=e
    res.append(t[last:])
    return ''.join(res)
