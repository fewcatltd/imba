; =====================================================================
;  IMBA grid hotkeys (как в iCCup): клавиша = клик по ячейке панели команд
;  Нужен AutoHotkey v2 (https://www.autohotkey.com). Работает только когда
;  активно окно Warcraft III, буквы карты при этом не важны.
;
;  Первый запуск — калибровка (в игре, выбрав героя):
;    Ctrl+Alt+1  — навести мышь на ЦЕНТР левой верхней кнопки (Move / Двигаться)
;    Ctrl+Alt+2  — навести мышь на ЦЕНТР правой нижней кнопки панели команд
;  Позиции сохраняются в imba_hotkeys.ini рядом со скриптом.
;  При смене разрешения или режима окна — откалибровать заново.
;
;  Q W E R      — нижний ряд (скиллы)
;  F D T        — средний ряд, ячейки 1-3
;  Ctrl+Q/W/E/R — изучить скилл (жмёт «Изучить» и нужную кнопку)
;  Shift работает как обычно (очередь приказов).
;  Enter        — чат: пока он открыт, буквы печатаются как обычно
;                 (Enter закрывает, Esc сбрасывает, если сбилось)
;  Ctrl+Alt+H   — выключить/включить скрипт
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
CoordMode "Mouse", "Client"
CoordMode "ToolTip", "Client"

; ---- раскладка: клавиша -> [ряд, колонка]; ряд 1 сверху, колонка 1 слева ----
KEYS := Map(
    "q", [3, 1], "w", [3, 2], "e", [3, 3], "r", [3, 4],
    "f", [2, 1], "d", [2, 2], "t", [2, 3]
)
LEARN_BTN := [2, 4]                                  ; кнопка «Изучить» (O) у героя
LEARN := Map("q", 1, "w", 2, "e", 3, "r", 4)         ; Ctrl+клавиша -> колонка в меню изучения (ряд 1)
WC3 := "ahk_exe Warcraft III.exe"

INI := A_ScriptDir "\imba_hotkeys.ini"
gx1 := IniRead(INI, "grid", "x1", ""), gy1 := IniRead(INI, "grid", "y1", "")
gx2 := IniRead(INI, "grid", "x2", ""), gy2 := IniRead(INI, "grid", "y2", "")
chat := false
enabled := true

HotIfWinActive WC3
for k, cell in KEYS
    Hotkey "*" k, PressCell.Bind(cell)
for k, col in LEARN
    Hotkey "^" k, LearnSkill.Bind(col)
Hotkey "~*Enter", ToggleChat
Hotkey "~*NumpadEnter", ToggleChat
Hotkey "~*Esc", (*) => SetChat(false)
Hotkey "^!1", Calib.Bind(1)
Hotkey "^!2", Calib.Bind(2)
Hotkey "^!h", ToggleEnabled
HotIf

Calibrated() => gx1 != "" && gy1 != "" && gx2 != "" && gy2 != ""

CellXY(r, c) {
    x := gx1 + (c - 1) * (gx2 - gx1) / 3
    y := gy1 + (r - 1) * (gy2 - gy1) / 2
    return [Round(x), Round(y)]
}

ClickCell(r, c) {
    p := CellXY(r, c)
    MouseGetPos &mx, &my
    Click p[1] " " p[2]
    MouseMove mx, my, 0
}

PassThrough(hk) {
    ; отдать игре исходную клавишу (чат, выключено, нет калибровки)
    key := RegExReplace(hk, "^[*^~!+#]+")
    Send "{Blind}{" key "}"
}

PressCell(cell, hk) {
    if (!enabled || chat || !Calibrated()) {
        if (!Calibrated() && enabled && !chat)
            Tip("Сначала калибровка: Ctrl+Alt+1 и Ctrl+Alt+2")
        return PassThrough(hk)
    }
    ClickCell(cell[1], cell[2])
}

LearnSkill(col, hk) {
    if (!enabled || chat || !Calibrated())
        return PassThrough(hk)
    p1 := CellXY(LEARN_BTN[1], LEARN_BTN[2]), p2 := CellXY(1, col)
    MouseGetPos &mx, &my
    Click p1[1] " " p1[2]
    Sleep 40
    Click p2[1] " " p2[2]
    MouseMove mx, my, 0
}

ToggleChat(*) {
    global chat
    chat := !chat
}

SetChat(v) {
    global chat
    chat := v
}

ToggleEnabled(*) {
    global enabled, chat
    enabled := !enabled, chat := false
    Tip(enabled ? "IMBA hotkeys: ВКЛ" : "IMBA hotkeys: ВЫКЛ")
}

Calib(n, *) {
    global gx1, gy1, gx2, gy2
    MouseGetPos &mx, &my
    if (n = 1) {
        gx1 := mx, gy1 := my
        IniWrite mx, INI, "grid", "x1"
        IniWrite my, INI, "grid", "y1"
    } else {
        gx2 := mx, gy2 := my
        IniWrite mx, INI, "grid", "x2"
        IniWrite my, INI, "grid", "y2"
    }
    Tip("Точка " n " сохранена (" mx ", " my ")" (Calibrated() ? " — готово" : ""))
}

Tip(s) {
    ToolTip s, 10, 10
    SetTimer () => ToolTip(), -1500
}
