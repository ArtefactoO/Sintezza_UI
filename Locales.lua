local _, SUI = ...
local english = Sintezza_Theme:GetLocale() == "enUS"

function SUI.Text(russian, translation)
    return english and translation or russian
end

local groups = {
    ["ОБЗОР"] = "OVERVIEW",
    ["ПАНЕЛИ"] = "BARS",
    ["БОЙ"] = "COMBAT",
    ["ГРУППА И КАРТА"] = "GROUP & MAP",
    ["ОБЩЕЕ"] = "GENERAL",
    ["ЭЛЕМЕНТЫ ИНТЕРФЕЙСА"] = "INTERFACE ELEMENTS",
}

function SUI.NavGroupLabel(group)
    return english and groups[group] or group
end

if GetLocale() == "ruRU" then
    SUI.OpenXPText = {
        card = {
            ["UP NEXT"] = "ДАЛЕЕ",
            ["Step %d / %d"] = "Шаг %d / %d",
            ["You get this quest at this step"] = "На этом шаге вы получите задание",
            ["ALONG THE WAY"] = "ПО ПУТИ",
            ["DONE"] = "ВЫПОЛНЕНО",
            ["QUEST CHAIN"] = "ЦЕПОЧКА ЗАДАНИЙ",
        },
        accept = "Принять задание «%s»",
        turnin = "Сдать задание «%s»",
        talk = "Поговорите с NPC: ",
        click = "Нажмите на объект: ",
        kill = "Цель — ",
        loot = " — добыча: ",
        andWord = " и ",
        drop = "(шанс выпадения около %s%%)",
    }
end
