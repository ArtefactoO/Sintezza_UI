local _, SUI = ...
local M = SUI:RegisterModule("lueurCompatibility", { title = "Lueur" })

local commands = {
    { key = "hideInCombat", command = "combat" },
    { key = "exclusive", command = "exclusive" },
}

local function Adapter()
    if not SUI.isForever or not SUI:IsAddonLoaded("Lueur") then return end
    local settings = _G.LueurDB
    local slash = _G.SlashCmdList and _G.SlashCmdList.LUEUR
    if _G.SLASH_LUEUR1 ~= "/lueur" or type(slash) ~= "function" or type(settings) ~= "table" then return end
    if type(settings.hideInCombat) ~= "boolean" or type(settings.exclusive) ~= "boolean" then return end
    return settings, slash
end

function M:IsAvailable()
    return Adapter() ~= nil
end

function M:RefreshAll()
    self.pending = false
    local settings, slash = Adapter()
    if not settings then return end
    local enabled = SUI:GetModuleProfile(self.key).enabled == true
    local restore = SUI.db.lueurCompatibilityRestore
    if type(restore) ~= "table" then restore = nil end
    if not enabled and not restore then return end
    if InCombatLockdown and InCombatLockdown() then
        self.pending = true
        return
    end

    -- Let Lueur manage its own interaction CVars and update its settings panel.
    -- Remember which account-wide settings we changed, even across a reload.
    restore = restore or {}
    SUI.db.lueurCompatibilityRestore = restore
    for _, option in ipairs(commands) do
        local key = option.key
        if enabled and settings[key] == false then
            slash(option.command)
            if settings[key] then restore[key] = true end
        elseif not enabled and restore[key] then
            if settings[key] then slash(option.command) end
            if not settings[key] then restore[key] = nil end
        end
    end
    if not next(restore) then SUI.db.lueurCompatibilityRestore = nil end
end

function M:WantsEvent()
    return self.pending
end

function M:OnEvent()
    self:RefreshAll()
end

function M:Initialize()
    if not SUI.isForever then return end
    self:RefreshAll()
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
end
