"""Достать файл(ы) из карты.

    python3 tools/unpack.py maps/DotA_Imba_Legends_v5.1g.w3x war3map.j out/war3map.j
    python3 tools/unpack.py maps/DotA_Imba_Legends_v5.1g.w3x --list
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import MPQ

m = MPQ(sys.argv[1])
if sys.argv[2] == '--list':
    print((m.read('(listfile)') or b'').decode('latin1'))
else:
    d = m.read(sys.argv[2])
    if d is None: sys.exit('нет такого файла (или он без имени в listfile)')
    os.makedirs(os.path.dirname(os.path.abspath(sys.argv[3])), exist_ok=True)
    open(sys.argv[3], 'wb').write(d)
    print(len(d), 'bytes ->', sys.argv[3])
