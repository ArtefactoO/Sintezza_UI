local _, SUI = ...
local Text = SUI.Text
local M, T, W, B = SUI.TeleportPrompt, SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder

local function Profile() return M:Profile() end

local function BindAvailable(row, predicate)
    local refresh = row.Refresh
    function row:Refresh(...)
        if refresh then refresh(self, ...) end
        self:SetAvailable(predicate())
    end
    row:Refresh()
    return row
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, Text("Телепорт в подземелье", "Dungeon teleport"), nil, {
            { key = "main", title = Text("Основное", "General") },
            { key = "appearance", title = Text("Внешний вид", "Appearance") },
        })

    local state = B:AddSection(page, "main", Text("Состояние", "Status"))
    local enabled = W:Toggle(state, Text("Показывать телепорт", "Show teleport prompt"), function() return Profile().enabled ~= false end, function(value)
        Profile().enabled = value
        M:OnProfileChanged()
        page:Refresh()
    end)
    B:AddRow(page, state, enabled)
    BindAvailable(enabled, function() return not SUI.isForever end)
    local status = W:SettingRow(state, Text("Подключение", "Availability"))
    status.value = W:Label(status, "", 9, T.muted)
    status.value:SetPoint("LEFT", status, "LEFT", 150, 0)
    status.value:SetPoint("RIGHT", status, "RIGHT", 0, 0)
    status.value:SetJustifyH("RIGHT")
    B:AddRow(page, state, status)
    B:FinishCard(page, "main", state)

    local behavior = B:AddSection(page, "main", Text("Поведение", "Behavior"))
    local knownOnly = W:Toggle(behavior, Text("Только изученные порталы", "Learned portals only"), function() return Profile().knownOnly ~= false end, function(value)
        Profile().knownOnly = value
        if M.pendingEntry then M:ShowPrompt() end
    end)
    B:AddRow(page, behavior, knownOnly)
    local cooldown = W:Toggle(behavior, Text("Показывать перезарядку", "Show cooldown"), function() return Profile().showCooldown ~= false end, function(value)
        Profile().showCooldown = value
        M:UpdateCooldown()
    end)
    B:AddRow(page, behavior, cooldown)
    local autoHide = W:SliderRow(behavior, Text("Скрывать через, с", "Hide after, s"), 0, 30, 1, function() return Profile().autoHide or 0 end, function(value)
        Profile().autoHide = value
    end)
    B:AddRow(page, behavior, autoHide)
    BindAvailable(knownOnly, function() return Profile().enabled ~= false and not M:HasExternalConflict() end)
    BindAvailable(cooldown, function() return Profile().enabled ~= false and not M:HasExternalConflict() end)
    BindAvailable(autoHide, function() return Profile().enabled ~= false and not M:HasExternalConflict() end)
    B:FinishCard(page, "main", behavior)

    local preview = B:AddSection(page, "main", Text("Предпросмотр", "Preview"),
        Text("Показывается 5 секунд без телепортации.", "Shows for 5 seconds without teleporting."))
    local previewRow = CreateFrame("Frame", nil, preview)
    previewRow:SetHeight(32)
    local previewButton = W:Button(previewRow, Text("Показать карточку", "Show prompt"), function() M:Preview() end, true)
    previewButton:SetSize(158, 26)
    previewButton:SetPoint("LEFT")
    B:AddRow(page, preview, previewRow)
    B:FinishCard(page, "main", preview)

    local geometry = B:AddSection(page, "appearance", Text("Положение", "Position"))
    local scale = W:SliderRow(geometry, Text("Масштаб", "Scale"), .75, 1.35, .05, function() return Profile().scale or 1 end, function(value)
        Profile().scale = value; M:ApplyAppearance()
    end)
    B:AddRow(page, geometry, scale)
    local x = W:SliderRow(geometry, Text("Смещение X", "X offset"), -700, 700, 5, function() return Profile().x or 0 end, function(value)
        Profile().x = value; M:ApplyAppearance()
    end)
    B:AddRow(page, geometry, x)
    local y = W:SliderRow(geometry, Text("Смещение Y", "Y offset"), -500, 0, 5, function() return Profile().y or -58 end, function(value)
        Profile().y = value; M:ApplyAppearance()
    end)
    B:AddRow(page, geometry, y)
    BindAvailable(scale, function() return Profile().enabled ~= false and not M:HasExternalConflict() end)
    BindAvailable(x, function() return Profile().enabled ~= false and not M:HasExternalConflict() end)
    BindAvailable(y, function() return Profile().enabled ~= false and not M:HasExternalConflict() end)
    B:FinishCard(page, "appearance", geometry)

    B:SetPageFooter(page, {{
        title = Text("Сбросить модуль", "Reset module"), width = 132,
        callback = function()
            W:Confirm(Text("Сбросить настройки телепорта?", "Reset teleport settings?"), function()
                SUI:ResetModuleProfile("teleportPrompt")
            end)
        end,
    }})

    page.OnRefresh = function()
        local message, okay = M:Status()
        status.value:SetText(message)
        local color = okay and T.muted or T.warning
        status.value:SetTextColor(color[1], color[2], color[3], 1)
    end
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({
    key = "teleportPrompt",
    showInNav = not SUI.isForever,
    title = Text("Телепорт", "Teleport"),
    group = "ЭЛЕМЕНТЫ ИНТЕРФЕЙСА",
    order = 40,
    builder = BuildPage,
})
