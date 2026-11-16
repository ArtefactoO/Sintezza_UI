local _, SUI = ...
local Text = SUI.Text
local M = SUI.Nameplates

local C = { availableCache = nil, relatedCache = {} }
M.AuraCatalog = C

local AURA_CATEGORIES = {
    "TrackedBuff",
    "TrackedBar",
    "SpecAgnosticTracked",
}

local ALL_CATEGORIES = {
    "TrackedBuff",
    "TrackedBar",
    "SpecAgnosticTracked",
    "Essential",
    "SpecAgnosticEssential",
    "Utility",
    "EquipSlotTracked",
}

local EXTRA_AURAS = {
    { ability = 102793, aura = 127797 }, -- Ursol's Vortex
}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsPlain(value)
    return not IsSecret(value) and value ~= nil
end

function C:SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and not IsSecret(name) and name ~= nil then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and not IsSecret(name) and name ~= nil then return name end
    end
    return "Spell " .. tostring(spellID)
end

local function DisplaySpellName(spellID, name)
    if name == ("Spell " .. tostring(spellID)) then
        return Text("Заклинание %s", "Spell %s"):format(tostring(spellID))
    end
    return name
end

function C:SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and not IsSecret(icon) and icon ~= nil then return icon end
    end
    if GetSpellInfo then
        local ok, _, _, icon = pcall(GetSpellInfo, spellID)
        if ok and not IsSecret(icon) and icon ~= nil then return icon end
    end
    return 134400
end

local function IsHarmful(spellID)
    if not (C_Spell and C_Spell.IsSpellHarmful) then return true end
    local ok, harmful = pcall(C_Spell.IsSpellHarmful, spellID)
    if not ok or IsSecret(harmful) then return true end
    return harmful ~= false
end

local function CategoryID(name)
    return Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory[name]
end

local function CategoryEntries(name)
    local category = CategoryID(name)
    if not category or not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet then
        return {}
    end
    local ok, entries = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category)
    return ok and IsPlain(entries) and type(entries) == "table" and entries or {}
end

local function LearnedStore()
    local db = SUI.db or _G.Sintezza_UIDB
    if type(db) ~= "table" then return nil end
    db.learnedDebuffs = type(db.learnedDebuffs) == "table" and db.learnedDebuffs or {}
    return db.learnedDebuffs
end

local function CurrentClass()
    local _, class = UnitClass("player")
    return type(class) == "string" and class or nil
end

function C:IsLearnedAvailable(spellID, entry)
    if type(entry) ~= "table" then return false end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and not IsSecret(known) and known == true then return true end
    end
    if IsSpellKnownOrOverridesKnown then
        local ok, known = pcall(IsSpellKnownOrOverridesKnown, spellID)
        if ok and not IsSecret(known) and known == true then return true end
    end
    local class = CurrentClass()
    return class ~= nil and type(entry.classes) == "table" and entry.classes[class] == true
end

function C:RememberLearnedDebuff(spellID, name)
    if IsSecret(spellID) or type(spellID) ~= "number" or spellID < 1 then return false end
    local store = LearnedStore()
    if not store then return false end
    local entry = store[spellID]
    local hasName = not IsSecret(name) and type(name) == "string" and name ~= ""
    local class = CurrentClass()
    if type(entry) == "table" then
        local changed = false
        if hasName and entry.name ~= name then entry.name, changed = name, true end
        entry.classes = type(entry.classes) == "table" and entry.classes or {}
        local learnedForClass = class and entry.classes[class] ~= true or false
        if learnedForClass then entry.classes[class], changed = true, true end
        if changed then self.availableCache = nil end
        return learnedForClass
    end
    local classes = {}
    if class then classes[class] = true end
    store[spellID] = {
        name = hasName and name or self:SpellName(spellID),
        classes = classes,
        seen = time and time() or 0,
    }
    self.availableCache = nil
    return true
end

function C:LearnFromUnit(unit)
    if type(unit) ~= "string" or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return 0 end
    if UnitExists then
        local ok, present = pcall(UnitExists, unit)
        if not ok or IsSecret(present) or present ~= true then return 0 end
    end
    local learned = 0
    -- Only event-selected target/focus/nameplate units reach this scan. Aura
    -- secrecy turns the first unreadable result into a quiet no-op.
    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL|PLAYER")
        if not ok or IsSecret(aura) then break end
        if type(aura) ~= "table" then break end
        local spellID, name = aura.spellId, aura.name
        if IsSecret(spellID) or IsSecret(name) then break end
        if type(spellID) == "number" and self:RememberLearnedDebuff(spellID, name) then
            learned = learned + 1
        end
    end
    return learned
end

function C:GetLearnedAuras()
    local result = {}
    for spellID, entry in pairs(LearnedStore() or {}) do
        if type(spellID) == "number" and self:IsLearnedAvailable(spellID, entry) then
            result[#result + 1] = {
                spellID = spellID,
                name = DisplaySpellName(spellID, type(entry.name) == "string" and entry.name or self:SpellName(spellID)),
                icon = self:SpellIcon(spellID),
                learned = true,
            }
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function C:GetLearnedCounts()
    local total, available = 0, 0
    for spellID, entry in pairs(LearnedStore() or {}) do
        total = total + 1
        if type(spellID) == "number" and self:IsLearnedAvailable(spellID, entry) then available = available + 1 end
    end
    return total, available
end

function C:GetAvailableAuras()
    if self.availableCache then return self.availableCache end

    local result, seenID, seenName = {}, {}, {}
    local function Add(spellID, learned, storedName)
        if not IsPlain(spellID) or seenID[spellID] or (not learned and not IsHarmful(spellID)) then return end
        local name = DisplaySpellName(spellID, type(storedName) == "string" and storedName or self:SpellName(spellID))
        if not IsPlain(name) or seenName[name] then return end
        seenID[spellID], seenName[name] = true, true
        result[#result + 1] = {
            spellID = spellID,
            name = name,
            icon = self:SpellIcon(spellID),
            learned = learned == true,
        }
    end

    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        for _, categoryName in ipairs(AURA_CATEGORIES) do
            for _, cooldownID in ipairs(CategoryEntries(categoryName)) do
                local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
                if ok and not IsSecret(info) and type(info) == "table" then
                    local hasAura = info.hasAura
                    local selfAura = info.selfAura
                    local overrideSpellID = info.overrideSpellID
                    local baseSpellID = info.spellID
                    if IsPlain(hasAura) and hasAura == true
                        and not IsSecret(selfAura) and selfAura ~= true then
                        if IsPlain(overrideSpellID) then Add(overrideSpellID)
                        elseif IsPlain(baseSpellID) then Add(baseSpellID) end
                    end
                end
            end
        end
    end

    for _, entry in ipairs(EXTRA_AURAS) do
        local known = false
        if IsPlayerSpell then
            local ok, value = pcall(IsPlayerSpell, entry.ability)
            known = ok and not IsSecret(value) and value == true
        end
        if known then Add(entry.aura) end
    end

    for _, entry in ipairs(self:GetLearnedAuras()) do
        Add(entry.spellID, true, entry.name)
    end

    table.sort(result, function(a, b) return a.name < b.name end)
    self.availableCache = result
    return result
end

function C:IsAuraAvailable(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local wanted = self:RelatedSpellIDs(spellID)
    for _, aura in ipairs(self:GetAvailableAuras()) do
        if aura.spellID == spellID or wanted[aura.spellID] then return true end
        local related = self:RelatedSpellIDs(aura.spellID)
        if related[spellID] then return true end
        for relatedID in pairs(wanted) do
            if related[relatedID] then return true end
        end
    end
    if IsPlayerSpell then
        for relatedID in pairs(wanted) do
            local ok, known = pcall(IsPlayerSpell, relatedID)
            if ok and not IsSecret(known) and known == true then return true end
        end
    end
    return false
end
function C:RelatedSpellIDs(spellID)
    spellID = tonumber(spellID)
    if not spellID then return {} end
    if self.relatedCache[spellID] then return self.relatedCache[spellID] end

    local result = { [spellID] = true }
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        for _, categoryName in ipairs(ALL_CATEGORIES) do
            for _, cooldownID in ipairs(CategoryEntries(categoryName)) do
                local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
                if ok and info then
                    local baseSpellID = IsPlain(info.spellID) and info.spellID or nil
                    local overrideSpellID = IsPlain(info.overrideSpellID) and info.overrideSpellID or nil
                    local linkedIDs = IsPlain(info.linkedSpellIDs) and type(info.linkedSpellIDs) == "table"
                        and info.linkedSpellIDs or {}
                    local linked = baseSpellID == spellID or overrideSpellID == spellID
                    if not linked then
                        for _, id in ipairs(linkedIDs) do
                            if IsPlain(id) and id == spellID then linked = true break end
                        end
                    end
                    if linked then
                        if baseSpellID then result[baseSpellID] = true end
                        if overrideSpellID then result[overrideSpellID] = true end
                        for _, id in ipairs(linkedIDs) do
                            if IsPlain(id) then result[id] = true end
                        end
                    end
                end
            end
        end
    end
    -- Cooldown Viewer can publish linked IDs a little later than the first
    -- request after login/spec change. Do not permanently cache the lone
    -- fallback ID: a later build may then discover the real aura/override IDs.
    local count = 0
    for _ in pairs(result) do count = count + 1 end
    if count > 1 then self.relatedCache[spellID] = result end
    return result
end

function C:Invalidate()
    self.availableCache = nil
    wipe(self.relatedCache)
end
