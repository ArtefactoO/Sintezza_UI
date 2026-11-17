local ADDON, SUI = ...
local SRT = SUI.RaidTools

-- Deliberately small and versioned. Every category is ANY: the compact audit
-- answers whether one recognizable effect of that family is visible, not
-- whether the group owns every possible raid buff. Restricted data stays UNKNOWN.
SRT.auraRegistryVersion = 4
SRT.auraRegistry = {
    -- In 12.1 Well Fed does not expose one stable whitelisted spell ID.  The
    -- generic Well Fed icon is the readable identity used by the current EUI
    -- reminder as well; keep legacy spell IDs only as a compatibility fallback.
    food = { mode = "ANY", iconIDs = { 136000 }, spellIDs = { 104280, 327706, 368301 } },
    flask = { mode = "ANY", spellIDs = {
        188033, 251836, 307185,
        432473, 432021, 431974, 431973, 431972, 431971,
        1235110, 1235108, 1235111, 1235057, 1239355,
        1235113, 1235114, 1235115, 1235116,
    } },
    rune = { mode = "ANY", spellIDs = {
        270058, 393438, 432013,
        1264426, 453250, 1234969, 1242347, 347901,
    } },
    buffs = { mode = "ANY", spellIDs = { 1459, 6673, 21562 } },
}
if SUI.isForever then
    -- Forever uses the Well Fed icon, ranked party spells, and classic and Mount Hyjal flask auras.
    SRT.auraRegistry.food.spellIDs = {}
    SRT.auraRegistry.flask.spellIDs = { 17626, 17627, 17628, 17629, 1293740, 1293741, 1293742, 1293743 }
    SRT.auraRegistry.buffs.spellIDs = {
        1459, 1460, 1461, 10156, 10157, 23028,
        1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564,
        1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850,
    }
    SRT.auraRegistry.rune.spellIDs = {}
end

local spellLookup, iconLookup = {}, {}
for category, definition in pairs(SRT.auraRegistry) do
    for _, spellID in ipairs(definition.spellIDs or {}) do spellLookup[spellID] = category end
    for _, iconID in ipairs(definition.iconIDs or {}) do iconLookup[iconID] = category end
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function AuraIdentity(aura)
    return aura.spellId, aura.icon
end

local function ScanUnit(unit, online)
    local result = { food = "UNKNOWN", flask = "UNKNOWN", rune = "UNKNOWN", buffs = "UNKNOWN" }
    if not (unit and online and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return result end
    local seen, complete = {}, true
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
        complete = ok and not IsSecret(restricted) and restricted == false
    end
    local readable = { food = true, flask = true, rune = not SUI.isForever, buffs = true }
    for index = 1, 81 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok then complete = false; break end
        if IsSecret(aura) then complete = false; break end
        if aura == nil then break end
        if index > 80 then complete = false; break end

        local identityOK, spellID, iconID = pcall(AuraIdentity, aura)
        if not identityOK then complete = false; break end
        if IsSecret(iconID) then
            readable.food = false
        else
            local iconCategory = iconLookup[iconID]
            if iconCategory then seen[iconCategory] = true end
        end
        if IsSecret(spellID) then
            if not SUI.isForever then readable.food = false end
            readable.flask, readable.rune, readable.buffs = false, false, false
        else
            local spellCategory = spellLookup[spellID]
            if spellCategory then seen[spellCategory] = true end
        end
    end
    for category in pairs(result) do
        if seen[category] then
            result[category] = "PRESENT"
        elseif complete and readable[category] then
            result[category] = "MISSING"
        end
    end
    return result
end

function SRT:ScanAuras(rows, force)
    local cols = self.profile.raidCheck.columns
    if not (cols.food or cols.flask or cols.rune or cols.buffs) then return end
    self.auditAuraCache = self.auditAuraCache or {}
    self.auraDirtyUnits = self.auraDirtyUnits or {}
    for _, row in ipairs(rows) do
        local unit = row.unit
        local visible = not UnitIsVisible or UnitIsVisible(unit)
        local canScan = row.online and not IsSecret(visible) and visible == true
        local cached = self.auditAuraCache[unit]
        if force or self.auraDirtyUnits[unit] or not cached or cached.canScan ~= canScan or cached.name ~= row.name then
            cached = { name = row.name, canScan = canScan, result = ScanUnit(unit, canScan) }
            self.auditAuraCache[unit] = cached
        end
        row.aura = cached.result
        self.auraDirtyUnits[unit] = nil
    end
end

function SRT:QueueAuraScan(unit)
    if IsSecret(unit) then return end
    if type(unit) ~= "string" or not (unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$")) then return end
    self.auraDirtyUnits = self.auraDirtyUnits or {}
    self.auraDirtyUnits[unit] = true
    if self.auraPending or not (self.audit and self.audit:IsShown()) then return end
    self.auraPending = true
    SUI:After(.15, self, "raid aura scan", function()
        self.auraPending = nil
        if self.audit and self.audit:IsShown() then self:RefreshAudit(false) end
    end)
end
