"""Собрать новую версию карты: берём предыдущую карту как контейнер и подменяем в ней файлы из src/.

    python3 tools/build.py maps/DotA_Imba_Legends_v5.1g.w3x maps/DotA_Imba_Legends_v5.1h.w3x

По умолчанию подменяются src/war3map.j и src/war3map.w3i. Перед сборкой запускается check131.
Дополнительные файлы: --file "war3map.wts=src/war3map.wts" (имя внутри архива = путь на диске).
"""
import sys, os, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mpq import MPQ
from mpq_rebuild import rebuild
import check131

ROOT = os.path.dirname(HERE)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('base'); ap.add_argument('out')
    ap.add_argument('--file', action='append', default=[], help='имя_в_архиве=путь')
    ap.add_argument('--skip-check', action='store_true')
    a = ap.parse_args()
    repl = {'war3map.j': os.path.join(ROOT, 'src', 'war3map.j'),
            'war3map.w3i': os.path.join(ROOT, 'src', 'war3map.w3i')}
    for f in a.file:
        k, v = f.split('=', 1); repl[k] = v
    data = {k: open(v, 'rb').read() for k, v in repl.items()}
    if not a.skip_check:
        errs = check131.check(data['war3map.j'])
        if errs:
            print('\n'.join(errs)); sys.exit('check131: скрипт не пройдёт в 1.31, сборка остановлена')
    base = MPQ(a.base)
    for k in data:
        if base.find(k) is None: sys.exit('в базовой карте нет файла %s' % k)
    report = rebuild(a.base, a.out, data)[0]
    out = MPQ(a.out)
    for k, v in data.items():
        assert out.read(k) == v, k
    print('ok', a.out, os.path.getsize(a.out), report)

if __name__ == '__main__':
    main()
