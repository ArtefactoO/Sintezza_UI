local _, SUI = ...
local M = SUI.Nameplates
if not M then return end

local adapters = {}
M.nameplateAdapters = adapters

local function IsAddonLoaded(name)
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) == true
end

local function SafeObjectType(frame)
    if not frame or type(frame.GetObjectType) ~= "function" then return nil end
    local ok, objectType = pcall(frame.GetObjectType, frame)
    return ok and objectType or nil
end

function M:RegisterNameplateAdapter(adapter)
    if type(adapter) ~= "table" or type(adapter.key) ~= "string"
        or type(adapter.Probe) ~= "function" or type(adapter.GetPlate) ~= "function" then return false end
    adapters[#adapters + 1] = adapter
    table.sort(adapters, function(left, right)
        return (tonumber(left.priority) or 0) > (tonumber(right.priority) or 0)
    end)
    return true
end

function M:GetAdapterPlate(unit)
    local adapter = self.activeAdapter
    if not adapter or not unit then return nil end
    local ok, plate = pcall(adapter.GetPlate, adapter, self, unit)
    if ok then return plate end
    if SUI.Diagnostics then SUI.Diagnostics:RecordError(self.key, "adapter get plate", plate) end
    return nil
end

function M:ForEachAdapterPlate(callback)
    local adapter = self.activeAdapter
    if not adapter or type(callback) ~= "function" or type(adapter.Iterate) ~= "function" then return end
    local ok, err = pcall(adapter.Iterate, adapter, self, callback)
    if not ok and SUI.Diagnostics then SUI.Diagnostics:RecordError(self.key, "adapter iterate", err) end
end

function M:ConnectNameplateAdapter()
    local selected, state
    for _, adapter in ipairs(adapters) do
        local ok, candidate = pcall(adapter.Probe, adapter, self)
        if ok and candidate then selected, state = adapter, candidate; break end
        if not ok and SUI.Diagnostics then
            SUI.Diagnostics:RecordError(self.key, "adapter probe " .. adapter.key, candidate)
        end
    end
    if not selected then
        self.available = false
        self.adapterKey, self.adapterName = nil, nil
        return false, false, false
    end

    local changed = self.activeAdapter ~= nil and self.activeAdapter ~= selected
    if changed then
        local units = {}
        for unit in pairs(self.plates or {}) do units[#units + 1] = unit end
        for _, unit in ipairs(units) do self:DetachPlate(unit) end
        self:StopRetryLoop()
        if self.AuraRules and self.AuraRules.ResetRuntime then self.AuraRules:ResetRuntime() end
        wipe(self.plates); wipe(self.activeUnits); wipe(self.pendingUnits)
    end

    self.activeAdapter, self.adapterState = selected, state
    self.adapterKey, self.adapterName = selected.key, selected.name or selected.key
    self.namespace, self.available = state.namespace, true
    if type(selected.InstallHooks) ~= "function" then return true, changed, true end
    local ok, hookResult = pcall(selected.InstallHooks, selected, self)
    if not ok and SUI.Diagnostics then
        SUI.Diagnostics:RecordError(self.key, "adapter hooks " .. selected.key, hookResult)
    end
    return true, changed, ok and hookResult ~= false
end

-- Preferred path: the original full EllesmereUI integration.
local EllesmereAdapter = {
    key = "ellesmere", name = "EllesmereUI", priority = 100,
}

function EllesmereAdapter:Probe()
    local namespace = EllesmereUI and EllesmereUI._ModuleNS
        and EllesmereUI._ModuleNS.EllesmereUINameplates
    return namespace and type(namespace.plates) == "table" and { namespace = namespace } or nil
end

function EllesmereAdapter:GetPlate(module, unit)
    local namespace = module.adapterState and module.adapterState.namespace
    return namespace and namespace.plates and namespace.plates[unit] or nil
end

function EllesmereAdapter:Iterate(module, callback)
    local namespace = module.adapterState and module.adapterState.namespace
    for unit, plate in pairs(namespace and namespace.plates or {}) do callback(unit, plate) end
end

function EllesmereAdapter:RestoreHealthColor(_, plate)
    return plate and type(plate.UpdateHealthColor) == "function" and pcall(plate.UpdateHealthColor, plate) or false
end

function EllesmereAdapter:InstallHooks(module)
    local namespace = module.adapterState and module.adapterState.namespace
    if not namespace then return false end
    module.hookedNamespaces = module.hookedNamespaces or setmetatable({}, { __mode = "k" })
    local hooked = module.hookedNamespaces[namespace]
    if not hooked then hooked = {}; module.hookedNamespaces[namespace] = hooked end
    local hookFailed
    local function EnsureHook(method, callback)
        local current = namespace[method]
        if type(current) ~= "function" then
            hookFailed = true
            if SUI.Diagnostics then
                SUI.Diagnostics:RecordError(module.key, "hook " .. method, "EllesmereUI method is unavailable")
            end
            return
        end
        if hooked[method] == current then return end
        local ok, err = pcall(hooksecurefunc, namespace, method, callback)
        if ok then hooked[method] = namespace[method]
        else
            hookFailed = true
            if SUI.Diagnostics then SUI.Diagnostics:RecordError(module.key, "hook " .. method, err) end
        end
    end
    EnsureHook("EnsureHoverOverlay", function(plate) if M.runtimeWanted then M:UpdateHoverOverlay(plate) end end)
    EnsureHook("EnsureTargetOverlay", function(plate)
        if not M.runtimeWanted then return end
        local rig = plate and plate.health and M.AuraRules and M.AuraRules.rigs[plate.health]
        if rig then M.AuraRules:RestackRig(rig) end
        M:UpdateSelectionVisuals(plate); M:UpdateHoverOverlay(plate)
    end)
    if not (hooked.RefreshBorder or hooked.RefreshAllSettings) then
        module.auraRoundRadius, module.auraRoundCorners = module:GetNativePlateRounding()
    end
    local function RefreshRoundedEffects()
        if not M.runtimeWanted then return end
        local radius, corners = M:GetNativePlateRounding()
        if radius == M.auraRoundRadius and corners == M.auraRoundCorners then return end
        M.auraRoundRadius, M.auraRoundCorners = radius, corners
        if M.roundedEffectsPending then return end
        M.roundedEffectsPending = true
        SUI:After(0, M, "refresh rounded nameplate effects", function()
            M.roundedEffectsPending = nil
            if M.runtimeWanted then M:RefreshAll(true) end
        end)
    end
    for _, method in ipairs({ "RefreshBorder", "RefreshAllSettings" }) do
        if type(namespace[method]) == "function" then EnsureHook(method, RefreshRoundedEffects) end
    end
    module:InstallBuffRows(namespace)
    return not hookFailed
end

M:RegisterNameplateAdapter(EllesmereAdapter)

-- Safe fallback for Blizzard plates. It does not take ownership of Blizzard's
-- native colour, range alpha, borders or selection art.
local BlizzardAdapter = {
    key = "blizzard", name = "Blizzard", priority = 10,
    wrappers = setmetatable({}, { __mode = "k" }),
}
local THIRD_PARTY_OWNERS = {
    "Plater", "Platynator", "Kui_Nameplates", "NeatPlates",
    "TidyPlates_ThreatPlates", "ThreatPlates",
}

function BlizzardAdapter:Probe()
    if not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then return nil end
    for _, addon in ipairs(THIRD_PARTY_OWNERS) do if IsAddonLoaded(addon) then return nil end end
    return {}
end

function BlizzardAdapter:Normalize(native, unit)
    local unitFrame = native and native.UnitFrame
    local healthContainer = unitFrame and unitFrame.HealthBarsContainer
    local health = healthContainer and healthContainer.healthBar
        or (unitFrame and (unitFrame.healthBar or unitFrame.HealthBar))
    if SafeObjectType(health) ~= "StatusBar" then return nil end
    local wrapper = self.wrappers[native]
    if wrapper and wrapper.health ~= health then wrapper = nil end
    if not wrapper then
        wrapper = { adapterKey = self.key, frame = native, nameplate = native }
        self.wrappers[native] = wrapper
    end
    wrapper.unit, wrapper.root, wrapper.health = unit, unitFrame, health
    wrapper.healthBG = health.background or health.Background or health.bg
    local casts = unitFrame and unitFrame.CastBarsContainer
    wrapper.cast = casts and casts.castBar or (unitFrame and (unitFrame.castBar or unitFrame.CastBar))
    wrapper.absorbOverflow = health.overAbsorbGlow or health.totalAbsorbOverlay
    return wrapper
end

function BlizzardAdapter:GetPlate(_, unit)
    local ok, native = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    return ok and native and self:Normalize(native, unit) or nil
end

function BlizzardAdapter:Iterate(module, callback)
    local seen = {}
    for index = 1, 40 do
        local unit = "nameplate" .. index
        local plate = self:GetPlate(module, unit)
        if plate and not seen[plate] then seen[plate] = true; callback(unit, plate) end
    end
end

function M:UsesBlizzardNameplates()
    if self.adapterKey and self.adapterKey ~= "blizzard" then return false end
    return not EllesmereAdapter:Probe() and BlizzardAdapter:Probe() ~= nil
end

M:RegisterNameplateAdapter(BlizzardAdapter)
