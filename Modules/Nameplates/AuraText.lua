local _, SUI = ...
local M = SUI.Nameplates
local A = M.AuraRules
local health = { "hpNumber", "hpText" }
local labels = { "name", "levelText", "totText", "questText" }
local hooked = setmetatable({}, { __mode = "k" })
local nativeRigs = setmetatable({}, { __mode = "kv" })

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function TextUnit(rig)
    local plate = rig.plate
    if not rig.unit or not plate or plate.health ~= rig.healthBar then return end
    local unit = plate.unit
    if IsSecret(unit) or type(unit) ~= "string" then return end
    local native = plate.nameplate
    if native then
        local owner = native.namePlateUnitToken
        if IsSecret(owner) or owner ~= unit then return end
    end
    return unit
end

local function ReadDebuffs(unit)
    if not unit or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    local found = {}
    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL|PLAYER")
        if not ok then break end
        if not IsSecret(aura) then
            if type(aura) ~= "table" then break end
            if not canaccesstable or canaccesstable(aura) then
                local spell = aura.spellId
                if not IsSecret(spell) and type(spell) == "number" then found[spell] = true end
            end
        end
    end
    return found
end

local function Matches(record, found)
    if not record.conditionIDs then return false end
    for _, aliases in ipairs(record.conditionIDs) do
        local present
        for spell in pairs(aliases) do
            if found[spell] then present = true; break end
        end
        if not present then return false end
    end
    return true
end

local function NativeColor(text)
    local ok, r, g, b, a = pcall(text.GetTextColor, text)
    if not ok or IsSecret(r) or IsSecret(g) or IsSecret(b) or IsSecret(a)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
    return r, g, b, a or 1
end

local function Near(a, b)
    return a ~= nil and b ~= nil and math.abs(a - b) < .0001
end

local function Restore(text, saved)
    local r, g, b, a = NativeColor(text)
    if Near(r, saved.r) and Near(g, saved.g) and Near(b, saved.b) and Near(a, saved.a) then
        pcall(text.SetTextColor, text, unpack(saved.base))
    end
end

function A:RestoreTextColors(rig)
    for text, saved in pairs(rig.textColors or {}) do Restore(text, saved) end
    rig.textColors, rig.healthRule, rig.labelRule = nil, nil, nil
end

function A:PaintTextColors(rig)
    local plate = rig.plate
    if not rig.textUnit or TextUnit(rig) ~= rig.textUnit or not (rig.healthRule or rig.labelRule) then
        self:RestoreTextColors(rig)
        return
    end
    local desired = {}
    local function Add(fields, rule)
        if not rule then return end
        for _, field in ipairs(fields) do
            local text = plate[field]
            if text and text.GetTextColor and text.SetTextColor then desired[text] = rule end
        end
    end
    Add(health, rig.healthRule)
    Add(labels, rig.labelRule)
    local box = rig.labelRule and plate._fvLevelBox
    if box and box._fs and box._fs.GetTextColor and box._fs.SetTextColor then desired[box._fs] = rig.labelRule end
    local states = rig.textColors or {}
    rig.textColors = states
    for text, saved in pairs(states) do
        if not desired[text] then Restore(text, saved); states[text] = nil end
    end
    for text, rule in pairs(desired) do
        local r, g, b, a = NativeColor(text)
        if r then
            local saved = states[text]
            if not saved or not (Near(r, saved.r) and Near(g, saved.g) and Near(b, saved.b) and Near(a, saved.a)) then
                saved = { base = { r, g, b, a } }
            end
            local color = rule.color or {}
            local red, green, blue = color.r or color[1] or 1, color.g or color[2] or .35, color.b or color[3] or .75
            if (Near(r, red) and Near(g, green) and Near(b, blue)) or pcall(text.SetTextColor, text, red, green, blue, a) then
                saved.r, saved.g, saved.b, saved.a = red, green, blue, a
                states[text] = saved
            end
        end
    end
end

local function PlateTextRig(plate)
    local rig = A.rigs[plate.health]
    if rig and rig.plate == plate and rig.hasTextRules then return rig end
end

local function RefreshNativeText(plate)
    local rig = PlateTextRig(plate)
    if not rig then return end
    if TextUnit(rig) ~= rig.textUnit then
        A:RefreshTextColors(rig)
    elseif rig.healthRule or rig.labelRule then
        A:PaintTextColors(rig)
    end
end

local function RefreshTextOwner(plate)
    local rig = PlateTextRig(plate)
    if rig and TextUnit(rig) ~= rig.textUnit then A:RefreshTextColors(rig) end
end

local function HookNativeText(plate)
    if hooked[plate] then return end
    hooked[plate] = true
    for _, method in ipairs({ "ApplyHealthTextAppearance", "UpdateName", "RefreshNamePosition",
        "UpdateHealthColor", "UpdateQuestText" }) do
        if type(plate[method]) == "function" then hooksecurefunc(plate, method, RefreshNativeText) end
    end
    if type(plate.UpdateHealthValues) == "function" then hooksecurefunc(plate, "UpdateHealthValues", RefreshTextOwner) end
    if type(plate.SetUnit) == "function" then
        hooksecurefunc(plate, "SetUnit", function(owner) A:RefreshTextColors(PlateTextRig(owner)) end)
    end
    if type(plate.ClearUnit) == "function" then
        hooksecurefunc(plate, "ClearUnit", function(owner)
            local rig = PlateTextRig(owner)
            if rig then
                rig.textUnit = nil
                A:RestoreTextColors(rig)
            end
        end)
    end
end

function A:RefreshTextColors(rig)
    if not rig or not rig.hasTextRules then return end
    local plate = rig.plate
    if rig.unit and plate and plate.health == rig.healthBar then
        if plate.nameplate then nativeRigs[plate.nameplate] = rig end
        HookNativeText(plate)
    end
    local unit = TextUnit(rig)
    if rig.textUnit ~= unit then self:RestoreTextColors(rig) end
    rig.textUnit = unit
    rig.healthRule, rig.labelRule = nil, nil
    if unit and not M:IsTapColorPriority(unit) then
        local found = ReadDebuffs(unit)
        if found then
            for _, record in ipairs(rig.rules) do
                if (record.colorText or record.colorLabels)
                    and self:DesiredUnit(unit, false, record.rule) and Matches(record, found) then
                    if not rig.healthRule and record.colorText then rig.healthRule = record.rule end
                    if not rig.labelRule and record.colorLabels then rig.labelRule = record.rule end
                    if rig.healthRule and rig.labelRule then break end
                end
            end
        end
    end
    self:PaintTextColors(rig)
end

function A:QueueTextAuraRefresh(unit)
    local bound = self.units[unit]
    if bound and not bound.hasTextRules then return end
    if not bound and unit ~= "target" and unit ~= "focus" and not M.activeUnits[unit] then return end
    local rig = bound
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, native = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and not IsSecret(native) and native then
            local current = nativeRigs[native]
            if current and current.plate and current.plate.nameplate == native then rig = current end
        end
    end
    if not rig or not rig.hasTextRules or rig.textAuraPending then return end
    rig.textAuraPending = true
    -- Coalesce nameplate/target aliases and read after the client's aura update.
    SUI:After(0, M, "nameplate text aura", function()
        rig.textAuraPending = nil
        if A.rigs[rig.healthBar] == rig then A:RefreshTextColors(rig) end
    end)
end
