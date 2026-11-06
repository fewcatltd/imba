; =====================================================================
;  IMBA Keys — клавиши инвентаря и способностей, как в лаунчере iCCup.
;  Нужен AutoHotkey v2: https://www.autohotkey.com  (запуск двойным кликом)
;
;  • Галочки можно включать и выключать в любой момент, прямо во время игры.
;  • Клик по кнопке — нажми новую клавишу, кнопку мыши (средняя, боковые) или
;    крутни колесо (Esc — отмена, Backspace — убрать).
;  • Работает только когда активно окно Warcraft III. Закрыл окно — всё выключилось.
;  • Чат: после Enter клавиши печатаются как обычно, пока чат не закрыт.
;  • Shift + клавиша = то же с Shift (очередь приказов).
;
;  Инвентарь: шлёт родные клавиши WC3 (Numpad 7 8 4 5 1 2).
;  Способности: шлёт букву ячейки (низ Q W E R, середина T D F, «Изучить» O).
;  Чтобы у скиллов IMBA были именно эти буквы, нужна галочка «Буквы по ячейкам»:
;  она кладёт CustomKeys_IMBA.txt как Документы\Warcraft III\CustomKeys.txt
;  (твой старый CustomKeys.txt уходит в .backup и возвращается при выключении).
;  Перед другими картами (DotA и т.д.) эту галочку снимай — файл действует на все карты.
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
CoordMode "ToolTip", "Screen"
GroupAdd "wc3", "ahk_exe Warcraft III.exe"
GroupAdd "wc3", "ahk_exe war3.exe"

INI := A_ScriptDir "\IMBA_Keys.ini"

; ---- инвентарь: id -> [клавиша WC3, по умолчанию]
INV := [["inv1", "Numpad7", "SC03C"], ["inv2", "Numpad8", "SC03D"],
        ["inv3", "Numpad4", "SC029"], ["inv4", "Numpad5", "SC002"],
        ["inv5", "Numpad1", "SC00F"], ["inv6", "Numpad2", "SC039"]]
; ---- способности: id -> [ряд, колонка, буква ячейки, по умолчанию]
;      ряд 2: T D F O(«Изучить»), ряд 3: Q W E R — такие буквы даёт CustomKeys_IMBA.txt
ABL := [["a21", 2, 1, "SC014", ""], ["a22", 2, 2, "SC020", "SC020"], ["a23", 2, 3, "SC021", "SC021"], ["a24", 2, 4, "SC018", ""],
        ["a31", 3, 1, "SC010", "SC010"], ["a32", 3, 2, "SC011", "SC011"], ["a33", 3, 3, "SC012", "SC012"], ["a34", 3, 4, "SC013", "SC013"]]
CK_SRC := A_ScriptDir "\CustomKeys_IMBA.txt"
CK_DST := A_MyDocuments "\Warcraft III\CustomKeys.txt"
CK_TAG := "IMBA Legends"

; подписи на кнопках — по английской раскладке
NAMES := Map("SC029", "~", "SC002", "1", "SC003", "2", "SC004", "3", "SC005", "4", "SC006", "5",
    "SC007", "6", "SC008", "7", "SC009", "8", "SC00A", "9", "SC00B", "0",
    "SC010", "Q", "SC011", "W", "SC012", "E", "SC013", "R", "SC014", "T", "SC015", "Y", "SC016", "U",
    "SC017", "I", "SC018", "O", "SC019", "P", "SC01E", "A", "SC01F", "S", "SC020", "D", "SC021", "F",
    "SC022", "G", "SC023", "H", "SC024", "J", "SC025", "K", "SC026", "L", "SC02C", "Z", "SC02D", "X",
    "SC02E", "C", "SC02F", "V", "SC030", "B", "SC031", "N", "SC032", "M", "SC00F", "Tab", "SC039", "Space")

; кнопки мыши, которые можно назначать (левая/правая — нет, ими кликают по окну)
MOUSE := Map("MButton", "Mouse3", "XButton1", "Mouse4", "XButton2", "Mouse5",
             "WheelUp", "Wheel ↑", "WheelDown", "Wheel ↓")

keys := Map()
for it in INV
    keys[it[1]] := ToSC(IniRead(INI, "keys", it[1], it[3]))
for it in ABL
    keys[it[1]] := ToSC(IniRead(INI, "keys", it[1], it[5]))
chat := false
active := Map()

; ------------------------------- GUI -------------------------------
g := Gui("-MaximizeBox", "IMBA Keys")
g.SetFont("s10", "Segoe UI")
btn := Map()

invOn := g.AddCheckbox("x15 y12 w200", "Клавиши инвентаря")
invOn.Value := Integer(IniRead(INI, "on", "inv", 1))
invOn.OnEvent("Click", Changed)
for i, it in INV {
    col := Mod(i - 1, 2), row := (i - 1) // 2
    b := g.AddButton(Format("x{} y{} w60 h40", 15 + col * 64, 40 + row * 44), Pretty(keys[it[1]]))
    b.OnEvent("Click", BindKey.Bind(it[1]))
    btn[it[1]] := b
}

ablOn := g.AddCheckbox("x170 y12 w220", "Клавиши способностей")
ablOn.Value := Integer(IniRead(INI, "on", "abl", 1))
ablOn.OnEvent("Click", Changed)
for it in ABL {
    b := g.AddButton(Format("x{} y{} w52 h40", 170 + (it[3] - 1) * 56, 40 + (it[2] - 2) * 44), Pretty(keys[it[1]]))
    b.OnEvent("Click", BindKey.Bind(it[1]))
    btn[it[1]] := b
}
g.AddText("x170 y132 w225 cGray", "ряд 2 и ряд 3 панели команд")

ckOn := g.AddCheckbox("x15 y170 w380", "Буквы по ячейкам (CustomKeys для IMBA)")
ckOn.Value := IsOurCK() ? 1 : 0
ckOn.OnEvent("Click", ToggleCK)
status := g.AddText("x15 y196 w385 h36 cGray", "")
g.OnEvent("Close", (*) => ExitApp())
g.Show("w410 h240")
ShowStatus()
Rebind()

; ------------------------------ логика ------------------------------
; все клавиши храним как скан-коды (SC0xx): не зависит от раскладки (RU/EN) и от спецсимволов
ToSC(k) {
    if (k = "")
        return ""
    if RegExMatch(k, "i)^SC[0-9A-F]+$")
        return StrUpper(k)
    if MOUSE.Has(k)
        return k
    if (k = "``" || k = "~")                          ; при русской раскладке по символу не находится
        return "SC029"
    sc := GetKeySC(k)
    return sc ? Format("SC{:03X}", sc) : ""
}

Pretty(k) {
    if (k = "")
        return "—"
    if NAMES.Has(k)
        return NAMES[k]
    if MOUSE.Has(k)
        return MOUSE[k]
    n := GetKeyName(k)
    return n = "" ? k : (StrLen(n) = 1 ? StrUpper(n) : n)
}

Changed(*) {
    IniWrite invOn.Value, INI, "on", "inv"
    IniWrite ablOn.Value, INI, "on", "abl"
    Rebind()
}

BindKey(id, *) {
    b := btn[id]
    b.Text := "..."
    got := 0
    ih := InputHook("T5")
    ih.KeyOpt("{All}", "NS")                         ; ловим любую клавишу и не пускаем её дальше
    ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-N-S")
    ih.OnKeyDown := OnKD
    OnKD(h, vk, sc) {                                ; скан-код берём прямо из нажатия — без раскладки
        got := sc
        h.Stop()
    }
    MouseCap(name, *) {                              ; кнопка мыши / колесо
        got := name
        ih.Stop()
    }
    HotIf
    for m in MOUSE
        Hotkey m, MouseCap.Bind(m), "On"
    ih.Start(), ih.Wait()
    for m in MOUSE
        Hotkey m, "Off"
    if (!got || got = 0x01) {                        ; таймаут или Esc — отмена
        b.Text := Pretty(keys[id])
        return
    }
    if (Type(got) = "String")
        k := got
    else
        k := (got = 0x0E || got = 0x153) ? "" : Format("SC{:03X}", got)   ; Backspace / Delete — убрать
    if (k != "") {                                    ; одна клавиша — одна кнопка
        for oid, ok in keys
            if (oid != id && ok = k) {
                keys[oid] := ""
                btn[oid].Text := "—"
                IniWrite "", INI, "keys", oid
            }
    }
    keys[id] := k
    b.Text := Pretty(k)
    IniWrite k, INI, "keys", id
    Rebind()
}

Rebind() {
    global active
    HotIfWinActive "ahk_group wc3"
    for hk in active
        Hotkey hk, "Off"
    active := Map()
    if invOn.Value
        for it in INV
            Add(keys[it[1]], InvPress.Bind(it[2]))
    if ablOn.Value
        for it in ABL
            Add(keys[it[1]], AblPress.Bind(it[4]))
    for hk in ["~*Enter", "~*NumpadEnter"]
        Hotkey hk, ToggleChat, "On"
    Hotkey "~*Esc", (*) => SetChat(false), "On"
    HotIf
}

Add(k, fn) {
    if (k = "")
        return
    for hk in [k, "+" k] {                          ; без Ctrl/Alt — Alt+Tab и прочее не трогаем
        Hotkey hk, fn, "On"
        active[hk] := 1
    }
}

PassThrough(hk) {
    k := RegExReplace(hk, "^\+")
    Send "{Blind}{" k "}"
}

InvPress(nk, hk) {
    if chat
        return PassThrough(hk)
    if !GetKeyState("NumLock", "T")                 ; предметы WC3 = цифры на Numpad, нужен NumLock
        SetNumLockState "On"
    Send "{Blind}{" nk "}"
}

AblPress(letter, hk) {
    if chat
        return PassThrough(hk)
    Send "{Blind}{" letter "}"
}

ToggleChat(*) {
    global chat
    chat := !chat
}
SetChat(v) {
    global chat
    chat := v
}

; ------------------------- CustomKeys (буквы по ячейкам) -------------------------
IsOurCK() {
    try return FileExist(CK_DST) && InStr(FileRead(CK_DST), CK_TAG)
    return false
}
ToggleCK(*) {
    try {
        if ckOn.Value {
            if !FileExist(CK_SRC)
                throw Error("рядом с программой нет файла CustomKeys_IMBA.txt")
            DirCreate A_MyDocuments "\Warcraft III"
            if (FileExist(CK_DST) && !IsOurCK())
                FileMove CK_DST, CK_DST ".backup", 1        ; твой файл — в резерв
            FileCopy CK_SRC, CK_DST, 1
        } else {
            if IsOurCK()
                FileDelete CK_DST
            if FileExist(CK_DST ".backup")
                FileMove CK_DST ".backup", CK_DST, 1        ; вернуть твой файл
        }
    } catch as e {
        ckOn.Value := IsOurCK() ? 1 : 0
        MsgBox "Не получилось: " e.Message, "IMBA Keys", 48
    }
    ShowStatus()
}
ShowStatus() {
    status.Text := IsOurCK()
        ? "Буквы по ячейкам: ВКЛ. Если игра уже запущена — перезапусти её. Перед DotA и другими картами сними галочку."
        : "Буквы по ячейкам: выкл (у скиллов родные буквы карты)."
}
