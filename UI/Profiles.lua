local _, SUI = ...
local Text = SUI.Text
local W = SUI.Widgets

local function BuildPage(parent)
    local page, canvas = W:Page(parent)
    local active = W:Section(canvas, Text("Активный профиль", "Active profile"), Text("Защищенные изменения применяются после боя.", "Protected changes apply after combat."))
    active:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -12)
    active:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -12)
    active:SetHeight(84)
    local activeRow = W:ChoiceRow(active, Text("Профиль", "Profile"), function()
        local result = {}; for _, name in ipairs(SUI:ProfileNames()) do result[name] = name end; return result
    end, function() return SUI.db.activeProfile end, function(name) SUI:SwitchProfile(name) end)
    activeRow:SetPoint("TOPLEFT", active, "TOPLEFT", 0, -46)
    activeRow:SetPoint("TOPRIGHT", active, "TOPRIGHT", 0, -46)

    local manage = W:Section(canvas, Text("Управление", "Manage profiles"))
    manage:SetPoint("TOPLEFT", active, "BOTTOMLEFT", 0, -10)
    manage:SetPoint("TOPRIGHT", active, "BOTTOMRIGHT", 0, -10)
    manage:SetHeight(130)
    local input = W:EditBox(manage, Text("Имя профиля", "Profile name"), function() end)
    input:SetPoint("TOPLEFT", manage, "TOPLEFT", 0, -36)
    input:SetWidth(240)
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local create = W:Button(manage, Text("Создать", "Create"), function()
        local ok, err = SUI:CreateProfile(input:GetText(), false); if not ok then SUI:Print(err) end; page:Refresh()
    end, true)
    create:SetSize(104, 26); create:SetPoint("LEFT", input, "RIGHT", 8, 0)
    local copy = W:Button(manage, Text("Копировать", "Copy"), function()
        local ok, err = SUI:CreateProfile(input:GetText(), true); if not ok then SUI:Print(err) end; page:Refresh()
    end)
    copy:SetSize(112, 26); copy:SetPoint("LEFT", create, "RIGHT", 8, 0)

    local rename = W:Button(manage, Text("Переименовать", "Rename"), function()
        local ok, err = SUI:RenameProfile(SUI.db.activeProfile, input:GetText()); if not ok then SUI:Print(err) end; page:Refresh()
    end)
    rename:SetSize(128, 26); rename:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -10)
    local remove = W:Button(manage, Text("Удалить", "Delete"), function()
        local name = SUI.db.activeProfile
        W:Confirm(Text("Удалить профиль ", "Delete profile ") .. name .. "?", function() local ok, err = SUI:DeleteProfile(name); if not ok then SUI:Print(err) end; page:Refresh() end)
    end)
    remove:SetSize(104, 26); remove:SetPoint("LEFT", rename, "RIGHT", 8, 0)
    local reset = W:Button(manage, Text("Сбросить профиль", "Reset profile"), function()
        local name = SUI.db.activeProfile
        local message = Text("Сбросить настройки модулей и окна в профиле «%s» до исходных?",
            "Restore default module and window settings for profile “%s”?"):format(name)
        W:Confirm(message, function()
            if SUI.db.activeProfile == name then SUI:ResetProfile(); page:Refresh() end
        end)
    end)
    reset:SetSize(128, 26); reset:SetPoint("LEFT", remove, "RIGHT", 8, 0)

    local modules = W:Section(canvas, Text("Сброс отдельных модулей", "Reset individual modules"))
    modules:SetPoint("TOPLEFT", manage, "BOTTOMLEFT", 0, -10)
    modules:SetPoint("TOPRIGHT", manage, "BOTTOMRIGHT", 0, -10)
    modules:SetHeight(130)
    local names = {
        { "gameBar", Text("Игровая панель", "Game Bar") }, { "raidTools", Text("Рейд-инструменты", "Raid Tools") },
        { "nameplates", Text("Неймплейты", "Nameplates") }, { "cooldownMasks", Text("Иконки и откат", "Icons and cooldowns") },
        { "fontCompatibility", "DandersFrames" },
        { "interactionEffects", Text("Hover-анимации", "Hover animations") },
    }
    for index, entry in ipairs(names) do
        local button = W:Button(modules, entry[2], function()
            W:Confirm(Text("Сбросить модуль «", "Reset module «") .. entry[2] .. "»?", function() SUI:ResetModuleProfile(entry[1]); page:Refresh() end)
        end)
        button:SetSize(150, 26)
        local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
        button:SetPoint("TOPLEFT", modules, "TOPLEFT", column * 160, -48 - row * 34)
    end

    function page:Refresh() activeRow:Refresh() end
    return page
end

SUI:RegisterSettingsPage({ key = "profiles", title = Text("Профили", "Profiles"), group = "ОБЩЕЕ", order = 20, builder = BuildPage })
