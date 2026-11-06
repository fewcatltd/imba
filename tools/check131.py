"""Статическая проверка war3map.j на то, что ломало загрузку в WC3 1.31 («Ошибка при чтении карты»).

    python3 tools/check131.py src/war3map.j

Проверяет:
  1. local с тем же именем, что параметр функции (ПОДТВЕРЖДЁННАЯ причина ошибки в 1.31) -> tools/patch_shadow.py
  2. строки длиннее 1000 символов (в 5.1g разбиты на IMBA131_Cond1..3 превентивно)
  3. невалидный UTF-8 (в 5.1g переведён в UTF-8 превентивно)
  4. локальные переменные, объявленные после обычных операторов
Это не полноценный компилятор: «чисто» здесь не гарантирует, что карта откроется.
"""
import re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patch_shadow import fix

def check(raw):
    errs = []
    try:
        t = raw.decode('utf-8')
    except UnicodeDecodeError as e:
        errs.append('невалидный UTF-8 около байта %d' % e.start)
        t = raw.decode('latin1')
    for name, old, new in fix(t)[1]:
        errs.append('%s: local %s совпадает с именем параметра' % (name, old))
    for i, l in enumerate(t.split('\n'), 1):
        if len(l) > 1000:
            errs.append('строка %d длиной %d > 1000' % (i, len(l)))
    fn = None; seen = False
    for i, l in enumerate(t.split('\n'), 1):
        s = l.strip()
        if re.match(r'^(constant\s+)?function\s', s): fn = s.split()[1]; seen = False; continue
        if s.startswith('endfunction'): fn = None; continue
        if fn is None or not s or s.startswith('//'): continue
        if s.startswith('local '):
            if seen: errs.append('строка %d (%s): local после операторов' % (i, fn))
        else:
            seen = True
    return errs

if __name__ == '__main__':
    e = check(open(sys.argv[1], 'rb').read())
    print('\n'.join(e) if e else 'ok')
    sys.exit(1 if e else 0)
