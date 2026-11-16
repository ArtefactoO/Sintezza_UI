local _, SUI = ...
local M = SUI.Nameplates
local tracked = setmetatable({}, { __mode = "k" })
local installed = setmetatable({}, { __mode = "k" })

local function BuffContainer(frame)
    -- Ellesmere sets this boolean on its pooled enemy buff container only.
    return frame and type(frame._npcSlotVal) == "string" and type(frame._npcAttackable) == "boolean"
end

local function SlotGrowsUp(ns, slot)
    local profile = ns.db and ns.db.profile
    return profile and (slot == "topleft" or slot == "topright") and profile[slot .. "SlotGrowth"] == "up"
end

local function RequestedWidth(container, state)
    local profile = M:Profile()
    if not (M.adapterKey == "ellesmere" and profile.enabled and not state.nativeWidth
        and not SlotGrowsUp(state.namespace, container._npcSlotVal)) then return end
    local count = math.floor(tonumber(profile.buffIconsPerRow) or 0)
    if count < 2 then return end
    local ns = state.namespace
    local size = tonumber(ns.GetBuffIconSize()) or 24
    local spacing = tonumber(ns.GetAuraSpacing("buffs")) or 4
    return count * size + (count - 1) * spacing + .4
end

local function ApplyGroupSpacing(container, state, wrapping)
    if not container.SetAuraGroupLayout or not (wrapping or state.compactRows) then return true end
    local ns = state.namespace
    local size = tonumber(ns.GetBuffIconSize()) or 24
    local gap = tonumber(ns.GetAuraSpacing("buffs")) or 4
    local height = size
    local crop = ns.GetAuraCrop and ns.GetAuraCrop("buffs")
    if crop and ns.GetAuraCropHeight then height = ns.GetAuraCropHeight(crop, size) end
    local rowGap = wrapping and math.max(0, math.min(12, tonumber(M:Profile().buffRowSpacing) or 2)) or gap
    local key = table.concat({ wrapping and 1 or 0, size, height, gap, rowGap, container._npbSplit and 1 or 0 }, ":")
    if key == state.spacingKey then return true end

    local main = { elementWidth = size, elementHeight = height, elementSpacing = gap, lineSpacing = rowGap }
    -- The plain icons draw at the same size as the purgeable ones. Match their
    -- cells while wrapping so a small icon does not leave a wider empty slot.
    local plain = wrapping and main or { elementWidth = 24, elementHeight = 24, elementSpacing = 4, lineSpacing = 4 }
    local okMain = pcall(container.SetAuraGroupLayout, container, "np", main)
    local okPlain = pcall(container.SetAuraGroupLayout, container, "npnb", plain)
    local okSplit = not container._npbSplit or pcall(container.SetAuraGroupLayout, container, "np2", main)
    if okMain and okPlain and okSplit then
        state.compactRows, state.spacingKey = wrapping and true or nil, key
    elseif wrapping and (okMain or okPlain) then
        state.compactRows = true
    end
    return okMain and okPlain and okSplit
end

local function Apply(container, state, skipSpacing)
    local width = RequestedWidth(container, state)
    if width == state.width and (skipSpacing or not (width or state.compactRows)) then return end
    local setter = container.SetFlowLayoutMaximumLineSize or container.SetAuraLayoutRowWidth
    if not setter or (container.IsForbidden and container:IsForbidden()) then return end
    local combat = InCombatLockdown and InCombatLockdown()
    if combat and container.IsProtected and container:IsProtected() then
        M.pendingBuffRows = true
        return
    end
    if width ~= state.width then
        if pcall(setter, container, width or state.nativeWidth) then
            state.width = width
        else
            if combat then M.pendingBuffRows = true end
            return
        end
    end
    if not skipSpacing and not ApplyGroupSpacing(container, state, width ~= nil) and combat then
        M.pendingBuffRows = true
    end
end

local function Discover(plate, ns)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    -- Nameplate -> Ellesmere's bundle holder -> AuraContainer. Only walk
    -- those two levels on attachment or a settings change.
    for _, holder in ipairs({ plate:GetChildren() }) do
        if not (holder.IsForbidden and holder:IsForbidden()) then
            for _, frame in ipairs({ holder:GetChildren() }) do
                if BuffContainer(frame) then
                    local state = tracked[frame]
                    if not state then state = { namespace = ns }; tracked[frame] = state end
                    Apply(frame, state)
                    return
                end
            end
        end
    end
end

function M:InstallBuffRows(ns)
    if installed[ns] then return end
    local kit = EllesmereUI and EllesmereUI.AuraKit
    if not (kit and hooksecurefunc and type(kit.SetContainerRowWidth) == "function"
        and type(ns.NPC_AttachPlate) == "function" and type(ns.GetBuffIconSize) == "function"
        and type(ns.GetAuraSpacing) == "function") then return end
    installed[ns] = true
    hooksecurefunc(kit, "SetContainerRowWidth", function(container, nativeWidth)
        if not BuffContainer(container) then return end
        local state = tracked[container]
        if not state then state = { namespace = ns }; tracked[container] = state end
        state.nativeWidth, state.width, state.spacingKey = nativeWidth, nil, nil
        SUI:SafeModuleCall(M, "Ellesmere buff row width", function() Apply(container, state, true) end)
        -- AnchorNPContainer sets the group layouts after the width call.
        if not state.spacingQueued and (state.width or state.compactRows) then
            state.spacingQueued = true
            SUI:After(0, M, "Ellesmere buff row spacing", function()
                state.spacingQueued = nil
                Apply(container, state)
            end)
        end
    end)
    hooksecurefunc(ns, "NPC_AttachPlate", function(plate)
        if M.adapterKey == "ellesmere" and (tonumber(M:Profile().buffIconsPerRow) or 0) > 0 then
            SUI:SafeModuleCall(M, "Ellesmere buff row attachment", function() Discover(plate, ns) end)
        end
    end)
end

function M:RefreshBuffRows()
    self.pendingBuffRows = nil
    local ns = self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace
    if ns and installed[ns] and self:Profile().enabled and (tonumber(self:Profile().buffIconsPerRow) or 0) > 0 then
        for _, plate in pairs(ns.plates or {}) do Discover(plate, ns) end
    end
    for container, state in pairs(tracked) do Apply(container, state) end
end

function M:CanWrapBuffRows()
    local ns = self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace
    return ns and installed[ns] == true
end

