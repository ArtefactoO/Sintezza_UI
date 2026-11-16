local _, SUI = ...
local M = SUI:RegisterModule("eventAlerts", {})
local isSecret = issecretvalue

local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_THREAT_SITUATION_UPDATE" }
local LIFECYCLE_EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
}

local function Public(value, expectedType)
    return not (isSecret and isSecret(value)) and type(value) == expectedType
end

local function Number(value)
    return Public(value, "number") and value > -math.huge and value < math.huge
end

local function Setting(value, fallback, low, high)
    if not Number(value) then return fallback end
    return math.max(low, math.min(high, math.floor(value + .5)))
end

local function PlayerAlive()
    if type(UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, dead = pcall(UnitIsDeadOrGhost, "player")
    return ok and Public(dead, "boolean") and not dead
end

local function PlayerInCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    local combat = InCombatLockdown()
    return Public(combat, "boolean") and combat
end

local function InDungeonOrRaid()
    if type(IsInInstance) ~= "function" then return false end
    local ok, inside, instanceType = pcall(IsInInstance)
    return ok and Public(inside, "boolean") and inside and Public(instanceType, "string")
        and (instanceType == "party" or instanceType == "raid")
end

local function HealthPercent()
    if type(UnitHealth) ~= "function" or type(UnitHealthMax) ~= "function" then return end
    local ok, current = pcall(UnitHealth, "player", false)
    if not (ok and Number(current) and current > 0) then return end
    local maxOK, maximum = pcall(UnitHealthMax, "player")
    if not (maxOK and Number(maximum) and maximum > 0) then return end
    return math.min(1, current / maximum) * 100
end

local function HasAggro()
    if type(UnitThreatSituation) ~= "function" then return end
    local ok, status = pcall(UnitThreatSituation, "player")
    if not ok or (isSecret and isSecret(status)) then return end
    if status == nil or status == 0 or status == 1 then return false end
    if status == 2 or status == 3 then return true end
end

local function Play(kind, detail)
    local alert = SUI.CombatAlert
    if alert and type(alert.PlayExtraAlert) == "function" then alert:PlayExtraAlert(kind, detail) end
end

function M:SampleHealth(silent)
    local percent = self.healthEnabled and self.alive and HealthPercent()
    if not percent then
        self.healthKnown = nil
        return
    end
    if percent >= self.rearm then
        self.healthArmed = true
    elseif percent <= self.threshold then
        if self.healthKnown and self.healthArmed and not silent then
            Play("healthAlert", math.max(1, math.floor(percent + .5)))
        end
        self.healthArmed = false
    elseif self.healthArmed == nil then
        self.healthArmed = true
    end
    self.healthKnown = true
end

function M:SampleAggro(silent)
    if not (self.aggroEnabled and self.alive and self.inCombat and self.inDungeon and InDungeonOrRaid()) then
        self.hasAggro = nil
        return
    end
    local previous, current = self.hasAggro, HasAggro()
    self.hasAggro = current
    if current == true and previous == false and not silent then Play("aggroAlert") end
end

function M:OnUnitEvent(event, unit)
    if not Public(unit, "string") or unit ~= "player" then return end
    if not PlayerAlive() then
        self.healthKnown, self.healthArmed, self.hasAggro = nil, nil, nil
        return
    end
    if event == "UNIT_THREAT_SITUATION_UPDATE" then
        self:SampleAggro()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        self:SampleHealth()
    end
end

function M:UpdateUnitEvents()
    local health = self.alive and self.healthEnabled and type(UnitHealth) == "function" and type(UnitHealthMax) == "function"
    local aggro = self.alive and self.aggroEnabled and self.inCombat and self.inDungeon and type(UnitThreatSituation) == "function"
    if not self.frame and (health or aggro) then
        local frame = CreateFrame("Frame")
        self.frame, self.bound = frame, {}
        frame:SetScript("OnEvent", function(_, event, unit)
            SUI:SafeModuleCall(M, "player alert event", M.OnUnitEvent, event, unit)
        end)
    end
    if not self.frame then return end
    for _, event in ipairs(UNIT_EVENTS) do
        local wanted = health
        if event == "UNIT_THREAT_SITUATION_UPDATE" then wanted = aggro end
        if wanted and self.bound[event] == nil then
            local valid = not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
            local ok, registered
            if valid and type(self.frame.RegisterUnitEvent) == "function" then
                ok, registered = pcall(self.frame.RegisterUnitEvent, self.frame, event, "player")
            end
            self.bound[event] = ok == true and registered ~= false
        elseif not wanted and self.bound[event] == true then
            self.frame:UnregisterEvent(event)
            self.bound[event] = nil
        end
    end
end

function M:OnProfileChanged()
    if not self.detectorReady then return end
    local profile = SUI:GetModuleProfile("combatAlert")
    local health = profile and profile.healthAlert
    local aggro = profile and profile.aggroAlert
    health = type(health) == "table" and health or nil
    aggro = type(aggro) == "table" and aggro or nil
    local healthEnabled = health ~= nil and health.enabled == true
    local aggroEnabled = aggro ~= nil and aggro.enabled == true
    local threshold = Setting(health and health.threshold, 25, 5, 90)
    local rearm = math.max(threshold + 1, Setting(health and health.rearm, 35, 6, 100))
    local changed = profile ~= self.profile
    local resetHealth = changed or healthEnabled ~= self.healthEnabled or threshold ~= self.threshold or rearm ~= self.rearm
    local resetAggro = changed or aggroEnabled ~= self.aggroEnabled
    if not (resetHealth or resetAggro) then return end

    self.profile = profile
    self.healthEnabled, self.aggroEnabled = healthEnabled, aggroEnabled
    self.threshold, self.rearm = threshold, rearm
    self.alive = PlayerAlive()
    self.inCombat, self.inDungeon = PlayerInCombat(), InDungeonOrRaid()
    if resetHealth then
        self.healthKnown, self.healthArmed = nil, nil
        self:SampleHealth(true)
    end
    if resetAggro then
        self.hasAggro = nil
        self:SampleAggro(true)
    end
    self:UpdateUnitEvents()
    if SUI.initialized then SUI:RefreshModuleEvents() end
end

function M:WantsEvent(event)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then return self.aggroEnabled end
    return self.healthEnabled or self.aggroEnabled
end

function M:OnEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        if self.inCombat then return end
        self.alive, self.inDungeon, self.inCombat = PlayerAlive(), InDungeonOrRaid(), true
        -- A new fight starts from a known neutral state.
        self.hasAggro = false
        self:SampleAggro()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.inCombat, self.hasAggro = false, nil
    elseif event == "PLAYER_DEAD" then
        self.alive, self.inCombat = false, false
        self.healthKnown, self.healthArmed, self.hasAggro = nil, nil, nil
    else
        if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            self.healthKnown, self.healthArmed = nil, nil
        end
        self.alive = PlayerAlive()
        self.inCombat, self.inDungeon = PlayerInCombat(), InDungeonOrRaid()
        -- Establish a baseline after entering an area or returning to life.
        self:SampleHealth(true)
        self:SampleAggro(true)
    end
    self:UpdateUnitEvents()
end

function M:Initialize()
    self.detectorReady = true
    for _, event in ipairs(LIFECYCLE_EVENTS) do SUI:RegisterModuleEvent(self, event) end
    self:OnProfileChanged()
end
