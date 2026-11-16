local _, SUI = ...
local Text = SUI.Text
local T, W = SUI.SettingsTheme, SUI.Widgets

local pickerSerial = 0

function W:SpellPicker(parent, placeholder, buildEntries, onPick)
    pickerSerial = pickerSerial + 1
    local picker = CreateFrame("Button", nil, parent, "BackdropTemplate")
    picker:SetHeight(28)
    picker.label = self:Label(picker, placeholder, 10, T.text)
    T:SkinButton(picker, picker.label, 10)
    T:DropdownArrow(picker, picker.label)

    local popupName = "Sintezza_UISpellPickerPopup" .. pickerSerial
    local popup = CreateFrame("Frame", popupName, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:SetClampedToScreen(true)
    popup:SetSize(340, 244)
    popup:Hide()
    T:MenuBackdrop(popup)
    T:Glow(popup, 0.76)
    table.insert(UISpecialFrames, popupName)

    popup.title = self:Label(popup, Text("Доступные дебаффы", "Available debuffs"), 11, T.text)
    popup.title:SetPoint("TOPLEFT", popup, "TOPLEFT", 10, -9)
    popup.count = self:Label(popup, "", 9, T.muted)
    popup.count:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -10, -9)
    popup.rows, popup.entries, popup.offset = {}, {}, 0
    local visibleRows = 7

    local function Render()
        local total = #popup.entries
        popup.offset = math.max(0, math.min(popup.offset, math.max(0, total - visibleRows)))
        popup.count:SetText(total .. Text(" доступно", " available"))
        for slot = 1, visibleRows do
            local row = popup.rows[slot]
            local entry = popup.entries[popup.offset + slot]
            row.entry = entry
            row:SetShown(entry ~= nil)
            row:SetBackdropBorderColor(0, 0, 0, 0)
            if entry then
                if popup.selectedIndex == popup.offset + slot then row:SetBackdropBorderColor(unpack(T.accent)) end
                row.icon:SetTexture(entry.icon or 134400)
                row.name:SetText(entry.name or (Text("Заклинание ", "Spell ") .. tostring(entry.spellID)))
                row.id:SetText(entry.tracked and Text("ДОБАВЛЕНО", "ADDED") or tostring(entry.spellID))
                row.known:SetShown(entry.learned and not entry.tracked)
                local nameColor = entry.tracked and T.muted or T.text
                local idColor = entry.tracked and T.accent or (entry.learned and T.warning or T.muted)
                row.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3], 1)
                row.id:SetTextColor(idColor[1], idColor[2], idColor[3], 1)
            end
        end
        popup.empty:SetShown(total == 0)
    end

    for slot = 1, visibleRows do
        local row = CreateFrame("Button", nil, popup, "BackdropTemplate")
        row:SetHeight(27)
        local y = -34 - ((slot - 1) * 28)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 7, y)
        row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -7, y)
        T:Backdrop(row, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        T:FrameIcon(row, row.icon)
        row.name = self:Label(row, "", 10, T.text)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -76, 0)
        row.id = self:Label(row, "", 9, T.muted)
        row.id:SetPoint("RIGHT", row, "RIGHT", -7, 0)
        row.known = T:Glyph(row, "check", 9, T.warning)
        row.known:SetPoint("RIGHT", row.id, "LEFT", -3, 0)
        local highlight = T:MenuHighlight(row)
        row:SetScript("OnEnter", function(self)
            highlight:SetShown(self.entry ~= nil and not self.entry.tracked)
        end)
        row:SetScript("OnLeave", function() highlight:Hide() end)
        row:HookScript("OnHide", function() highlight:Hide() end)
        row:SetScript("OnClick", function(self)
            if not self.entry or self.entry.tracked then return end
            popup:Hide(); onPick(self.entry.spellID)
        end)
        popup.rows[slot] = row
    end

    popup.empty = self:Label(popup, Text("Нет доступных аур. Добавь по ID заклинания.", "No auras available. Add one by spell ID."), 10, T.muted)
    popup.empty:SetPoint("CENTER", popup, "CENTER", 0, -6)
    popup.empty:SetJustifyH("CENTER")
    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(_, delta)
        popup.selectedIndex = nil
        popup.offset = popup.offset - (delta > 0 and 1 or -1); Render()
    end)
    popup:HookScript("OnShow", function() W.openSpellPicker = popup end)
    popup:HookScript("OnHide", function()
        if W.openSpellPicker == popup then W.openSpellPicker = nil end
    end)

    function popup:HandleSettingsKey(key, direction)
        if key == "ESCAPE" then self:Hide(); return true end
        if key == "ENTER" or key == "SPACE" then
            local entry = self.entries[self.selectedIndex or 0]
            if entry and not entry.tracked then
                self:Hide()
                onPick(entry.spellID)
            end
            return true
        end
        if key ~= "TAB" and key ~= "UP" and key ~= "DOWN" then return false end
        if key == "UP" then direction = -1 elseif key == "DOWN" then direction = 1 end
        local count = #self.entries
        local index = self.selectedIndex or (direction > 0 and 0 or 1)
        for _ = 1, count do
            index = (index + direction - 1) % count + 1
            if not self.entries[index].tracked then
                self.selectedIndex = index
                if index <= self.offset then self.offset = index - 1 end
                if index > self.offset + visibleRows then self.offset = index - visibleRows end
                Render()
                break
            end
        end
        return true
    end

    picker:SetScript("OnClick", function()
        if popup:IsShown() then popup:Hide(); return end
        popup:ClearAllPoints(); popup:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -5)
        popup:SetWidth(math.max(340, picker:GetWidth()))
        if W.openSpellPicker then W.openSpellPicker:Hide() end
        popup.entries = buildEntries() or {}; popup.offset = 0; popup.selectedIndex = nil
        Render(); popup:Show()
    end)
    picker:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 0.55) end)
    picker:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(T.line[1], T.line[2], T.line[3], T.line[4] or 1) end)
    picker:HookScript("OnHide", function() popup:Hide() end)
    picker.popup = popup
    return picker
end
