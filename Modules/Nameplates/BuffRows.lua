local _, SUI = ...
local M = SUI.Nameplates
local tracked = setmetatable({}, { __mode = "k" })
local installed = setmetatable({}, { __mode = "k" })
local stockLayouts = setmetatable({}, { __mode = "k" })
local stockBlocked = setmetatable({}, { __mode = "k" })
local STOCK_ROWS = 2

local function Plain(value)
    return not issecretvalue or not issecretvalue(value)
end

local function Accessible(frame)
    if not Plain(frame) or (type(frame) ~= "table" and type(frame) ~= "userdata") then return false end
    local ok, allowed = pcall(function()
        local forbidden = frame.IsForbidden and frame:IsForbidden()
        if not Plain(forbidden) or forbidden then return false end
        if not frame.CanBeAccessedInContext then return true end
        local accessible = frame:CanBeAccessedInContext()
        return Plain(accessible) and accessible == true
    end)
    return ok and allowed
end

function M:CanWrapBlizzardBuffRows()
    return SUI.isForever and self:UsesBlizzardNameplates()
        and NamePlateAurasMixin and type(NamePlateAurasMixin.RefreshAuras) == "function"
        and GridLayoutFrameMixin and type(GridLayoutFrameMixin.Layout) == "function" or false
end

function M:BuffRowsProfileKey()
    if self:UsesBlizzardNameplates() then return "blizzardBuffIconsPerRow" end
    return "buffIconsPerRow"
end

function M:GetBuffIconsPerRow()
    return tonumber(self:Profile()[self:BuffRowsProfileKey()]) or 0
end

local function StockColumns()
    if not M:Profile().enabled or not M:CanWrapBlizzardBuffRows() then return end
    local count = tonumber(M:Profile().blizzardBuffIconsPerRow)
    if count == 3 or count == 4 or count == 5 then return count end
end

local function ReadStockLayout(list)
    local limit, stride = list.maxAuraItemsDisplayed, list.stride
    local gap, lockedHeight, height = list.childYPadding, list.needsFixedHeight, list.fixedHeight
    if not (Plain(limit) and Plain(stride) and Plain(gap) and Plain(lockedHeight) and Plain(height)) then return end
    if type(limit) ~= "number" or type(stride) ~= "number" or type(gap) ~= "number"
        or type(lockedHeight) ~= "boolean" or (height ~= nil and type(height) ~= "number") then return end
    return { limit = limit, stride = stride, gap = gap, lockedHeight = lockedHeight, height = height }
end

local function WriteStockLayout(list, layout)
    list.maxAuraItemsDisplayed, list.stride, list.childYPadding = layout.limit, layout.stride, layout.gap
    list.needsFixedHeight, list.fixedHeight = layout.lockedHeight, layout.height
end

local function RefreshStockLayout(auras, list)
    if not auras:IsVisible() or not list:IsShown() then return end
    local unit = auras.unitToken
    if Plain(unit) and type(unit) == "string" then auras:RefreshAuras() end
end

local function ApplyStockLayout(auras, list, columns, gap)
    local state = stockLayouts[list]
    if not Accessible(auras) or not Accessible(list) then return end
    if InCombatLockdown and InCombatLockdown() then
        if state or columns then M.pendingBuffRows = true end
        return
    end
    if columns and stockBlocked[list] then return end
    if not columns and not state then return end
    local protected = list.IsProtected and list:IsProtected()
    if not Plain(protected) or protected then return end
    local current = ReadStockLayout(list)
    if not current then return end
    if columns and state and current.limit == STOCK_ROWS * columns and current.stride == columns
        and current.gap == gap and not current.lockedHeight and current.height == nil then return end

    local wanted = columns and { limit = STOCK_ROWS * columns, stride = columns, gap = gap, lockedHeight = false }
        or state.original
    local ok, err = pcall(function()
        WriteStockLayout(list, wanted)
        RefreshStockLayout(auras, list)
    end)
    if ok then
        stockLayouts[list] = columns and (state or { auras = auras, original = current }) or nil
    elseif columns then
        stockBlocked[list] = true
        local original = state and state.original or current
        if pcall(WriteStockLayout, list, original) then
            stockLayouts[list] = nil
        else
            stockLayouts[list] = state or { auras = auras, original = original }
        end
        if SUI.Diagnostics then SUI.Diagnostics:RecordError(M.key, "Blizzard buff rows", err) end
    else
        -- Keep the restored fields if Blizzard's redraw is unavailable. The
        -- next native aura update will build the original layout from them.
        if pcall(WriteStockLayout, list, wanted) then stockLayouts[list] = nil end
    end
end

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

local function BuffGeometry(ns)
    local size = tonumber(ns.GetBuffIconSize()) or 24
    local gap = tonumber(ns.GetAuraSpacing("buffs")) or 4
    local crop = ns.GetAuraCrop and ns.GetAuraCrop("buffs")
    local height = crop and ns.GetAuraCropHeight and ns.GetAuraCropHeight(crop, size) or size
    return size, height, gap
end

local function ConfiguredGap()
    return math.max(0, math.min(12, tonumber(M:Profile().buffRowSpacing) or 2))
end

function M:GetBuffPreviewLayout()
    local stock = StockColumns()
    if stock then
        local size = NamePlateConstants and NamePlateConstants.AURA_ITEM_HEIGHT or 20
        return stock, size, size, 0, ConfiguredGap(), stock * STOCK_ROWS
    end
    if self:UsesBlizzardNameplates() then return end
    local profile = self:Profile()
    local columns = math.floor(tonumber(profile.buffIconsPerRow) or 0)
    if not profile.enabled or columns < 2 or not self:CanWrapBuffRows() then return end
    local size, height, gap = BuffGeometry(self.adapterState.namespace)
    return columns, size, height, gap, ConfiguredGap()
end

local function ApplyGroupSpacing(container, state, wrapping)
    if not container.SetAuraGroupLayout or not (wrapping or state.compactRows) then return true end
    local size, height, gap = BuffGeometry(state.namespace)
    local rowGap = wrapping and ConfiguredGap() or gap
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

function M:RefreshBlizzardPlateBuffRows(plate)
    if self.adapterKey ~= "blizzard" then return end
    local columns = StockColumns()
    if not columns and not next(stockLayouts) then return end
    local root = plate and plate.root
    if not Accessible(root) then return end
    local auras = root.AurasFrame
    if not Accessible(auras) or type(auras.RefreshAuras) ~= "function" then return end
    local list = auras.BuffListFrame
    if Accessible(list) and type(list.Layout) == "function" then
        ApplyStockLayout(auras, list, columns, ConfiguredGap())
    end
end

function M:RefreshBuffRows()
    self.pendingBuffRows = nil
    local stock = StockColumns()
    if stock then
        for _, plate in pairs(self.plates) do self:RefreshBlizzardPlateBuffRows(plate) end
    else
        for list, state in pairs(stockLayouts) do ApplyStockLayout(state.auras, list) end
        wipe(stockBlocked)
    end
    local ns = self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace
    if ns and installed[ns] and self:Profile().enabled and (tonumber(self:Profile().buffIconsPerRow) or 0) > 0 then
        for _, plate in pairs(ns.plates or {}) do Discover(plate, ns) end
    end
    for container, state in pairs(tracked) do Apply(container, state) end
end

function M:CanWrapBuffRows()
    if self:CanWrapBlizzardBuffRows() then return true end
    local ns = self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace
    return ns and installed[ns] == true
end

