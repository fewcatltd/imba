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
;  Инвентарь: шлёт родные клавиши WC3 (Numpad 7 8 4 5 1 2), калибровка не нужна.
;  Способности: кликает по ячейке панели команд. Положение панели вычисляется
;  по размеру окна; если клики промахиваются — «Калибровать».
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
CoordMode "Mouse", "Client"
CoordMode "ToolTip", "Screen"
GroupAdd "wc3", "ahk_exe Warcraft III.exe"
GroupAdd "wc3", "ahk_exe war3.exe"

INI := A_ScriptDir "\IMBA_Keys.ini"

; ---- инвентарь: id -> [клавиша WC3, по умолчанию]
INV := [["inv1", "Numpad7", "SC03C"], ["inv2", "Numpad8", "SC03D"],
        ["inv3", "Numpad4", "SC029"], ["inv4", "Numpad5", "SC002"],
        ["inv5", "Numpad1", "SC00F"], ["inv6", "Numpad2", "SC039"]]
; ---- способности: id -> [ряд, колонка, по умолчанию]; ряд 1 = верхний (Move/Stop/Hold/Attack)
ABL := [["a21", 2, 1, ""], ["a22", 2, 2, "SC020"], ["a23", 2, 3, "SC021"], ["a24", 2, 4, ""],
        ["a31", 3, 1, "SC010"], ["a32", 3, 2, "SC011"], ["a33", 3, 3, "SC012"], ["a34", 3, 4, "SC013"]]
; авто-положение панели команд (доли клиентской области окна): центры левой верхней и правой нижней кнопок
AUTO := [0.7994, 0.8040, 0.9606, 0.9475]

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
    keys[it[1]] := ToSC(IniRead(INI, "keys", it[1], it[4]))
calib := IniRead(INI, "grid", "calib", "")      ; "x1,y1,x2,y2" в пикселях клиента или пусто = авто
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

g.AddButton("x15 y170 w120 h30", "Калибровать").OnEvent("Click", StartCalib)
g.AddButton("x140 y170 w120 h30", "Авто-позиция").OnEvent("Click", ResetCalib)
status := g.AddText("x15 y208 w380 cGray", "")
g.OnEvent("Close", (*) => ExitApp())
g.Show("w410 h235")
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
            Add(keys[it[1]], AblPress.Bind(it[2], it[3]))
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

AblPress(r, c, hk) {
    if chat
        return PassThrough(hk)
    p := CellXY(r, c)
    if !p
        return PassThrough(hk)
    MouseGetPos &mx, &my
    Click p[1] " " p[2]
    MouseMove mx, my, 0
}

CellXY(r, c) {
    if calib != "" {
        a := StrSplit(calib, ",")
        x1 := a[1], y1 := a[2], x2 := a[3], y2 := a[4]
    } else {
        try WinGetClientPos , , &w, &h, "A"
        catch
            return 0
        x1 := w * AUTO[1], y1 := h * AUTO[2], x2 := w * AUTO[3], y2 := h * AUTO[4]
    }
    return [Round(x1 + (c - 1) * (x2 - x1) / 3), Round(y1 + (r - 1) * (y2 - y1) / 2)]
}

ToggleChat(*) {
    global chat
    chat := !chat
}
SetChat(v) {
    global chat
    chat := v
}

; ----------------------------- калибровка -----------------------------
calStep := 0, calP := []
StartCalib(*) {
    global calStep, calP
    calStep := 1, calP := []
    HotIfWinActive "ahk_group wc3"
    Hotkey "F8", CalibPoint, "On"
    HotIf
    status.Text := "Калибровка: в игре выбери героя, наведи на ЦЕНТР левой верхней кнопки (Двигаться) и нажми F8"
}
CalibPoint(*) {
    global calStep, calP, calib
    MouseGetPos &mx, &my
    calP.Push(mx, my)
    if calStep = 1 {
        calStep := 2
        status.Text := "Теперь наведи на ЦЕНТР правой нижней кнопки панели и нажми F8"
        ToolTip "Точка 1 сохранена. Теперь правая нижняя кнопка + F8", 10, 10
        SetTimer () => ToolTip(), -2500
        return
    }
    calib := calP[1] "," calP[2] "," calP[3] "," calP[4]
    IniWrite calib, INI, "grid", "calib"
    calStep := 0
    HotIfWinActive "ahk_group wc3"
    Hotkey "F8", "Off"
    HotIf
    ToolTip "Калибровка сохранена", 10, 10
    SetTimer () => ToolTip(), -2000
    ShowStatus()
}
ResetCalib(*) {
    global calib
    calib := ""
    IniWrite "", INI, "grid", "calib"
    ShowStatus()
}
ShowStatus() {
    status.Text := calib = "" ? "Панель команд: авто-позиция по размеру окна" : "Панель команд: откалибровано (" calib ")"
}
