local _, SUI = ...

local M = SUI:RegisterModule("cooldownMasks", {
    title = SUI.Text("Иконки и откат", "Icons and cooldowns"),
    hookedActionBars = 0,
    hookedCooldownManager = 0,
})
SUI.CooldownMasks = M

local hooked = setmetatable({}, { __mode = "k" })
local owners = setmetatable({}, { __mode = "k" })
local guarded = setmetatable({}, { __mode = "k" })
local appliedCooldowns = setmetatable({}, { __mode = "k" })
local cooldownMasks = setmetatable({}, { __mode = "k" })
local privateEdges = setmetatable({}, { __mode = "k" })
local regionMasks = setmetatable({}, { __mode = "k" })
local mainSwipeProxies = setmetatable({}, { __mode = "k" })
local mainSwipeProxyFrames = setmetatable({}, { __mode = "k" })
local mainSwipeOwners = setmetatable({}, { __mode = "k" })
local mainSwipeActive = setmetatable({}, { __mode = "k" })
local mainSwipeStyled = setmetatable({}, { __mode = "k" })
local mainSwipeShowing = setmetatable({}, { __mode = "k" })
local chargeProxies = setmetatable({}, { __mode = "k" })
local chargeProxyFrames = setmetatable({}, { __mode = "k" })
local proxyAlphaHosts = setmetatable({}, { __mode = "k" })
local proxyTextHooked = setmetatable({}, { __mode = "k" })
local pending = {}
local flushScheduled = false
local scanScheduled = false
local hookedGlobals = {}
local actionBarRefreshScheduled = false
local chargeRefreshScheduled = false

local PROXY_SWIPE_MEDIA = "Interface\\AddOns\\Sintezza_UI\\Media\\CooldownMasks\\"
local PROXY_SWIPE_TEXTURES = {}
for _, shape in ipairs({ "circle", "csquare", "diamond", "hexagon", "portrait", "shield", "square" }) do
    PROXY_SWIPE_TEXTURES[shape] = {
        light = PROXY_SWIPE_MEDIA .. shape .. "-light.png",
        medium = PROXY_SWIPE_MEDIA .. shape .. "-medium.png",
        dark = PROXY_SWIPE_MEDIA .. shape .. "-dark.png",
    }
end

local function ResolveProxySwipeTexture(shape, opacity)
    local textures = PROXY_SWIPE_TEXTURES[shape]
    if not textures then return nil end
    local level = opacity < .47 and "light" or (opacity < .64 and "medium" or "dark")
    return textures[level]
end

-- Blizzard's hidden action buttons handle press-and-hold and can pass secret
-- cooldowns. Mask only EUI-owned buttons, using our own coalesced events.
local EUI_OWNED_ACTION_BAR_COOLDOWNS_SAFE = true
M.broadcasterIsolation = true

local function Profile()
    return SUI:GetModuleProfile("cooldownMasks")
end

function M:Profile()
    return Profile()
end

local function ModuleNamespace(addonName)
    return EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS[addonName]
end

function M:ActionBarNamespace()
    return ModuleNamespace("EllesmereUIActionBars")
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

function M:IsBlizzardCooldownViewerFrame(frame)
    -- EUI reparents Blizzard's pooled items, but the item's viewerFrame
    -- survives. Also check ancestors for descendants and aliased cooldowns.
    for _ = 1, 12 do
        if IsSecret(frame) then return true end
        if not frame then return false end
        if frame == EssentialCooldownViewer or frame == UtilityCooldownViewer
            or frame == BuffIconCooldownViewer or frame == BuffBarCooldownViewer
            or (frame.IsForbidden and frame:IsForbidden()) then return true end
        local viewer = frame.viewerFrame
        if IsSecret(viewer) or viewer then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return true
end

function M:ActionBarSwipeReady()
    local ns = self:ActionBarNamespace()
    local eab = ns and ns.EAB
    local settings = eab and eab.db and eab.db.profile
    -- EUI applies this through its own settings callback, so Sintezza_UI
    -- never has to change the protected EAB cooldown to hide its native fill.
    return settings and tonumber(settings.cdSwipeAlpha) == 0 or false
end

local function ScopeEnabled(kind)
    local profile = Profile()
    if not profile or not profile.enabled then return false end
    if kind == "actionBars" then
        return EUI_OWNED_ACTION_BAR_COOLDOWNS_SAFE and profile.actionBars ~= false
            and M:ActionBarSwipeReady()
    end
    if kind == "cooldownManager" then return profile.cooldownManager ~= false end
    return false
end

function M:HasVisuals()
    local p = Profile()
    if not p or not p.enabled then return false end
    if p.actionBars ~= false and ModuleNamespace("EllesmereUIActionBars") then return true end
    return ModuleNamespace("EllesmereUICooldownManager") ~= nil
        and (p.cooldownManager ~= false or (p.buffEffects and p.buffEffects.enabled ~= false)
            or (p.procEffects and p.procEffects.enabled == true))
end

local function ResolveActionBar(owner)
    local ns, button = owner.ns, owner.frame
    local data = ns and ns._eabFD and ns._eabFD[button]
    if not data or not data.shapeApplied or not data.shapeMaskPath then return end
    local shape = data.shapeName
    if not shape or shape == "none" or shape == "cropped" then return end
    return data.shapeMaskPath, data.shapeMask, shape
end

local function ResolveCooldownManager(owner)
    local ns, icon = owner.ns, owner.frame
    local data = ns and ns._ecmeFC and ns._ecmeFC[icon]
    if not data or not data.shapeApplied or not data.shapeName then return end
    local shape = data.shapeName
    if shape == "none" or shape == "cropped" then return end
    local path = ns.CDM_SHAPE_MASKS and ns.CDM_SHAPE_MASKS[shape]
    if not path then return end
    return path, data.shapeMask, shape
end

local resolvers = {
    actionBars = ResolveActionBar,
    cooldownManager = ResolveCooldownManager,
}

local function ResolveProxySwipeColor(owner)
    local eab = owner and owner.kind == "actionBars" and owner.ns and owner.ns.EAB
    local profile = eab and eab.db and eab.db.profile
    local color = profile and profile.cdSwipeColor
    if type(color) ~= "table" then return 0, 0, 0 end
    return tonumber(color.r) or 0, tonumber(color.g) or 0, tonumber(color.b) or 0
end

function M:GetSwipePreview()
    local ns = self:ActionBarNamespace()
    local bars = ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile and ns.EAB.db.profile.bars
    local shape
    local canReadShape = type(bars) == "table" and type(ns.AB_LayoutShape) == "function"
    for _, settings in pairs(canReadShape and bars or {}) do
        if type(settings) == "table" then
            local ok, name = pcall(ns.AB_LayoutShape, settings)
            if ok and not IsSecret(name) and PROXY_SWIPE_TEXTURES[name] and (not shape or name < shape) then shape = name end
        end
    end
    local usingExample = not shape
    shape = shape or "square"
    local p = Profile()
    local r, g, b = ResolveProxySwipeColor({ kind = "actionBars", ns = ns })
    local mask = not usingExample and ns.SHAPE_MASKS and ns.SHAPE_MASKS[shape]
    local border = not usingExample and ns.SHAPE_BORDERS and ns.SHAPE_BORDERS[shape]
    return ResolveProxySwipeTexture(shape, tonumber(p.mainSwipeAlpha) or .55),
        ResolveProxySwipeTexture(shape, tonumber(p.chargeSwipeAlpha) or .38), r, g, b, usingExample, mask, border
end


local function MaskTextureRegions(frame, mask, depth, alpha)
    if not frame or not mask or (depth or 0) > 4 then return end
    if frame.GetRegions then
        for index = 1, frame:GetNumRegions() do
            local region = select(index, frame:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture"
                and region ~= mask and region.AddMaskTexture then
                local applied = regionMasks[region]
                if applied and applied ~= mask and region.RemoveMaskTexture then
                    pcall(region.RemoveMaskTexture, region, applied)
                end
                pcall(region.AddMaskTexture, region, mask)
                if alpha and region.SetAlpha then pcall(region.SetAlpha, region, alpha) end
                regionMasks[region] = mask
            end
        end
    end
    if frame.GetChildren then
        for index = 1, frame:GetNumChildren() do
            MaskTextureRegions(select(index, frame:GetChildren()), mask, (depth or 0) + 1, alpha)
        end
    end
end

local function UnmaskTextureRegions(frame, mask, depth)
    if not frame or (depth or 0) > 4 then return end
    if frame.GetRegions then
        for index = 1, frame:GetNumRegions() do
            local region = select(index, frame:GetRegions())
            local applied = region and regionMasks[region]
            if applied and (not mask or applied == mask) then
                if region.RemoveMaskTexture then pcall(region.RemoveMaskTexture, region, applied) end
                regionMasks[region] = nil
            end
        end
    end
    if frame.GetChildren then
        for index = 1, frame:GetNumChildren() do
            UnmaskTextureRegions(select(index, frame:GetChildren()), mask, (depth or 0) + 1)
        end
    end
end


local EDGE_GETTERS = { SetDrawEdge = "GetDrawEdge", SetDrawBling = "GetDrawBling" }

local function HidePrivateEdges(cd)
    local restore = privateEdges[cd]
    if not restore then restore = {}; privateEdges[cd] = restore end
    for setter, getter in pairs(EDGE_GETTERS) do
        if restore[setter] == nil and type(cd[getter]) == "function" then
            local ok, value = pcall(cd[getter], cd)
            if ok and not IsSecret(value) and type(value) == "boolean" then restore[setter] = value end
        end
        if restore[setter] ~= nil and cd[setter] then pcall(cd[setter], cd, false) end
    end
end

local function RestorePrivateEdges(cd)
    local restore = privateEdges[cd]
    if not restore then return end
    privateEdges[cd] = nil
    for setter, value in pairs(restore) do
        if cd[setter] then pcall(cd[setter], cd, value) end
    end
end

local function RestoreCooldown(cd)
    if not cd then return false end
    local applied = appliedCooldowns[cd]
    local mask = applied and applied.mask or cooldownMasks[cd]
    if not applied and not mask and not privateEdges[cd] then return false end
    local owner = owners[cd]
    if owner and owner.kind == "cooldownManager"
        and (M:IsBlizzardCooldownViewerFrame(owner.frame) or M:IsBlizzardCooldownViewerFrame(cd)) then return false end
    guarded[cd] = true
    if owner and owner.kind == "cooldownManager" then
        RestorePrivateEdges(cd)
        -- EUI applies this same mask and swipe to its primary cooldown.
        if cd ~= owner.primaryCooldown then
            if mask and cd.RemoveMaskTexture then pcall(cd.RemoveMaskTexture, cd, mask) end
            local swipeFile = owner.ns.CdmSwipeFile
            if type(swipeFile) == "function" and cd.SetSwipeTexture then
                local ok, path = pcall(swipeFile)
                if ok and type(path) == "string" then pcall(cd.SetSwipeTexture, cd, path) end
            end
        end
    elseif mask and cd.RemoveMaskTexture then
        pcall(cd.RemoveMaskTexture, cd, mask)
    end
    UnmaskTextureRegions(cd, mask, 0)
    if mainSwipeProxyFrames[cd] then
        if cd.Clear then pcall(cd.Clear, cd) end
        if cd.Hide then pcall(cd.Hide, cd) end
    elseif chargeProxyFrames[cd] then
        if cd.Clear then pcall(cd.Clear, cd) end
        if cd.SetAlpha then pcall(cd.SetAlpha, cd, 1) end
    end
    appliedCooldowns[cd] = nil
    cooldownMasks[cd] = nil
    guarded[cd] = nil
    return true
end

local function ApplyCooldown(cd, owner)
    if not cd or not owner or not ScopeEnabled(owner.kind) then return end
    if cd.IsForbidden and cd:IsForbidden() then return end
    if owner.kind == "cooldownManager"
        and (M:IsBlizzardCooldownViewerFrame(owner.frame) or M:IsBlizzardCooldownViewerFrame(cd)) then return end
    local resolver = resolvers[owner.kind]
    if not resolver then return end
    local path, mask, shape = resolver(owner)
    if not path then return end
    local isMainProxy = mainSwipeProxyFrames[cd] == true
    local isChargeProxy = chargeProxyFrames[cd] == true
    local isProxy = isMainProxy or isChargeProxy
    local profile = Profile()
    local opacity = isMainProxy and (tonumber(profile.mainSwipeAlpha) or .55)
        or (isChargeProxy and (tonumber(profile.chargeSwipeAlpha) or .38))
    if opacity then opacity = math.max(.05, math.min(1, opacity)) end
    local swipePath = isProxy and ResolveProxySwipeTexture(shape, opacity) or path
    if isProxy then mask = nil end

    guarded[cd] = true
    local applied = appliedCooldowns[cd]
    local rebuildMask = not applied or applied.path ~= path or applied.mask ~= mask
        or applied.shape ~= shape or applied.swipePath ~= swipePath
    if rebuildMask then
        if mask and cd.RemoveMaskTexture and cd.AddMaskTexture then
            pcall(cd.RemoveMaskTexture, cd, mask)
            pcall(cd.AddMaskTexture, cd, mask)
            MaskTextureRegions(cd, mask, 0)
        end
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, swipePath or path) end
        appliedCooldowns[cd] = { path = path, mask = mask, shape = shape, swipePath = swipePath }
        cooldownMasks[cd] = mask
    end
    -- Cooldown creates some intrinsic swipe textures lazily, after the first
    -- duration is painted. Re-scan the small proxy subtree on every explicit
    -- compatibility refresh so those new regions cannot escape the EUI mask.
    if isProxy then
        -- Shape and opacity are baked into the local swipe texture; Retail
        -- cannot discard one without also discarding the other.
        local r, g, b = ResolveProxySwipeColor(owner)
        if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, r, g, b, 1) end
        pcall(cd.SetAlpha, cd, 1)
        if cd.SetIgnoreParentAlpha then pcall(cd.SetIgnoreParentAlpha, cd, false) end
        local host = proxyAlphaHosts[cd]
        if host then pcall(host.SetAlpha, host, 1) end
    end
    if mask then MaskTextureRegions(cd, mask, 0, isProxy and 1 or nil) end
    local shaped = shape ~= "square" and shape ~= "csquare"
    if owner.kind == "cooldownManager" then
        if Profile().hideSpark ~= false then HidePrivateEdges(cd)
        else RestorePrivateEdges(cd) end
    elseif Profile().hideSpark ~= false then
        -- Blizzard renders the rotating cooldown edge as an intrinsic layer.
        -- It is not clipped by either AddMaskTexture or SetSwipeTexture and its
        -- bright pointer protrudes past round/hexagonal buttons.  Keep the
        -- masked swipe and countdown, but suppress this unmaskable layer.  On
        -- 12.1 SetDrawEdge(false) can be undone internally; transparent edge
        -- colour remains reliable even when EUI re-enables edge drawing.
        if cd.SetDrawEdge then pcall(cd.SetDrawEdge, cd, false) end
        if cd.SetEdgeColor then pcall(cd.SetEdgeColor, cd, 1, 1, 1, 0) end
        if cd.SetDrawBling then pcall(cd.SetDrawBling, cd, false) end
    elseif cd.SetUseCircularEdge then
        pcall(cd.SetUseCircularEdge, cd, shaped)
    end
    guarded[cd] = nil
end

function M:RestoreEdges()
    -- Private CDM cooldowns restore their flags locally. The global EUI
    -- apply would also rebuild Blizzard's native viewers from addon code.
    local ns = ModuleNamespace("EllesmereUIActionBars")
    local eab = ns and ns.EAB
    if not self.broadcasterIsolation and eab and type(eab.ApplyCooldownEdge) == "function" then
        pcall(eab.ApplyCooldownEdge, eab)
    end
    self:ScheduleScan(0.05)
end

function M:SetHideSpark(value)
    Profile().hideSpark = value == true
    self:RefreshAll()
    if not Profile().hideSpark then
        self:RestoreEdges()
    end
end

local function Flush()
    flushScheduled = false
    for cd, owner in pairs(pending) do
        pending[cd] = nil
        ApplyCooldown(cd, owner)
    end
end

local function Queue(cd, owner)
    if not cd or not owner or not ScopeEnabled(owner.kind) then return end
    pending[cd] = owner
    if not flushScheduled then
        flushScheduled = true
        SUI:After(0, M, "cooldown queue", Flush)
    end
end

local function RegisterCooldown(cd, owner)
    if not cd or not cd.SetSwipeTexture then return end
    owners[cd] = owner
    if owner.kind == "actionBars" then
        Queue(cd, owner)
        return
    end
    if not hooked[cd] then
        hooked[cd] = true
        hooksecurefunc(cd, "SetSwipeTexture", function(self)
            if not guarded[self] then
                appliedCooldowns[self] = nil
                Queue(self, owners[self])
            end
        end)
        if cd.HookScript then
            cd:HookScript("OnShow", function(self)
                if not guarded[self] then
                    appliedCooldowns[self] = nil
                    Queue(self, owners[self])
                end
            end)
        end
        -- These are the non-structural calls that can restore the bright edge
        -- we intentionally suppress.  EUI 8.8.8 reapplies SetEdgeTexture while
        -- refreshing individual buff icons; on 12.1 that call can turn edge
        -- drawing back on even without a following SetDrawEdge(true).  Hook it
        -- as well, but do not hook SetCooldown/SetCooldownDuration: those fire
        -- continuously and do not change the mask or edge style.
        for _, method in ipairs({ "SetDrawEdge", "SetDrawBling", "SetEdgeTexture" }) do
            if type(cd[method]) == "function" then
                hooksecurefunc(cd, method, function(self, value)
                    if guarded[self] then return end
                    local restore = privateEdges[self]
                    if restore and EDGE_GETTERS[method] and not IsSecret(value) and type(value) == "boolean" then
                        restore[method] = value
                    end
                    Queue(self, owners[self])
                end)
            end
        end
    end
    Queue(cd, owner)
end

local function ClearMainSwipeVisual(native)
    if not mainSwipeShowing[native] then return end
    mainSwipeShowing[native] = nil
    local proxy = mainSwipeProxies[native]
    if proxy then
        mainSwipeStyled[proxy] = nil
        guarded[proxy] = true
        if proxy.Clear then pcall(proxy.Clear, proxy) end
        if proxy.Hide then pcall(proxy.Hide, proxy) end
        guarded[proxy] = nil
        local host = proxyAlphaHosts[proxy]
        if host then host:Hide() end
    end
end

local function ClearMainSwipeProxy(native)
    mainSwipeActive[native] = nil
    mainSwipeOwners[native] = nil
    ClearMainSwipeVisual(native)
end

local function ClearAllMainSwipeProxies()
    for native in pairs(mainSwipeProxies) do ClearMainSwipeProxy(native) end
end

local function PaintMainSwipeProxy(native, duration)
    local proxy, owner = mainSwipeProxies[native], mainSwipeOwners[native]
    if not proxy or not owner or not mainSwipeActive[native] or not ScopeEnabled("actionBars") then return end
    guarded[proxy] = true
    local painted = proxy.SetCooldownFromDurationObject
        and pcall(proxy.SetCooldownFromDurationObject, proxy, duration)
    if painted then
        if not mainSwipeStyled[proxy] then
            ApplyCooldown(proxy, owner)
            -- One bounded recheck after a newly active duration materializes
            -- its intrinsic texture; later cooldown events only update time.
            Queue(proxy, owner)
            mainSwipeStyled[proxy] = true
        end
        proxy:Show()
        local host = proxyAlphaHosts[proxy]
        local button = owner.frame
        local okVisible, visible = button and button.IsVisible and pcall(button.IsVisible, button)
        if host then host:SetShown(okVisible == true and visible == true) end
        mainSwipeShowing[native] = true
    else
        ClearMainSwipeVisual(native)
    end
    guarded[proxy] = nil
end

local function ActionForButton(button)
    if not button then return nil end
    local action
    if button.GetAttribute then
        local ok, value = pcall(button.GetAttribute, button, "action")
        if ok and not (issecretvalue and issecretvalue(value)) then action = value end
    end
    if action == nil and not (issecretvalue and issecretvalue(button.action)) then action = button.action end
    return type(action) == "number" and action or nil
end

local function SyncMainSwipeProxy(native)
    local owner = mainSwipeOwners[native]
    if not owner or not mainSwipeActive[native] then return end
    local action = ActionForButton(owner.frame)
    if not action or not C_ActionBar or not C_ActionBar.GetActionCooldownDuration then
        ClearMainSwipeVisual(native)
        return
    end
    if C_ActionBar.GetActionCooldown then
        local okInfo, info = pcall(C_ActionBar.GetActionCooldown, action)
        if okInfo and not (issecretvalue and issecretvalue(info)) and info ~= nil then
            local active = info.isActive
            if not (issecretvalue and issecretvalue(active)) and active == false then
                ClearMainSwipeVisual(native)
                return
            end
        end
    end
    local okDuration, duration = pcall(C_ActionBar.GetActionCooldownDuration, action)
    if okDuration and ((issecretvalue and issecretvalue(duration)) or duration ~= nil) then
        PaintMainSwipeProxy(native, duration)
    else
        ClearMainSwipeVisual(native)
    end
end

local function SetupMainSwipeProxy(button, native, owner)
    if not button or not native or not native.SetCooldownFromDurationObject then return false end
    mainSwipeOwners[native] = owner
    mainSwipeActive[native] = true
    local proxy = mainSwipeProxies[native]
    if not proxy then
        local level = math.max(button:GetFrameLevel(), native:GetFrameLevel() - 1)
        -- A child of an EAB action button can taint that button if Blizzard
        -- later re-adds it to the shared action-button broadcaster. Anchor an
        -- independent visual host instead of changing its child hierarchy.
        local host = CreateFrame("Frame", nil, UIParent)
        host:SetAllPoints(button)
        host:SetFrameStrata(button:GetFrameStrata())
        host:SetFrameLevel(math.max(0, level - 1))
        host:EnableMouse(false)
        host:Hide()
        proxy = CreateFrame("Cooldown", nil, host)
        proxy:SetAllPoints(host)
        proxy:SetFrameLevel(level)
        if proxy.SetIgnoreParentAlpha then proxy:SetIgnoreParentAlpha(false) end
        proxyAlphaHosts[proxy] = host
        proxy:SetHideCountdownNumbers(true)
        proxy:SetDrawEdge(false)
        proxy:SetDrawBling(false)
        proxy:SetDrawSwipe(true)
        proxy:EnableMouse(false)
        proxy:Hide()
        mainSwipeProxies[native] = proxy
        mainSwipeProxyFrames[proxy] = true
        RegisterCooldown(proxy, owner)
        ApplyCooldown(proxy, owner)
    else
        owners[proxy] = owner
        proxy:SetShown(mainSwipeShowing[native] == true)
        ApplyCooldown(proxy, owner)
    end

    SyncMainSwipeProxy(native)
    return true
end

local function ClearChargeProxy(button)
    local proxy = chargeProxies[button]
    if proxy and proxy.Clear then pcall(proxy.Clear, proxy) end
    local host = proxy and proxyAlphaHosts[proxy]
    if host then host:Hide() end
end

local function ClearAllChargeProxies()
    for button in pairs(chargeProxies) do ClearChargeProxy(button) end
end

local function SuppressProxyText(proxy)
    if not proxy or not proxy.GetRegions then return end
    if proxy.SetHideCountdownNumbers then pcall(proxy.SetHideCountdownNumbers, proxy, true) end
    for index = 1, proxy:GetNumRegions() do
        local region = select(index, proxy:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            pcall(region.SetAlpha, region, 0)
            pcall(region.Hide, region)
            if not proxyTextHooked[region] and region.HookScript then
                proxyTextHooked[region] = true
                region:HookScript("OnShow", function(self) self:Hide() end)
            end
        end
    end
end

local function ScheduleProxyTextSuppression(proxy)
    SuppressProxyText(proxy)
    SUI:After(0, M, "charge proxy text", function() SuppressProxyText(proxy) end)
    SUI:After(0.05, M, "charge proxy text delayed", function() SuppressProxyText(proxy) end)
end

local function SyncChargeProxy(button)
    local proxy = chargeProxies[button]
    if not proxy then return end
    if not ScopeEnabled("actionBars") then
        ClearChargeProxy(button)
        return
    end
    local action = ActionForButton(button)
    if not action or not C_ActionBar or not C_ActionBar.GetActionCharges then
        ClearChargeProxy(button)
        return
    end
    local okInfo, info = pcall(C_ActionBar.GetActionCharges, action)
    if not okInfo or (not (issecretvalue and issecretvalue(info)) and info == nil) then
        ClearChargeProxy(button)
        return
    end
    local okActive, active = pcall(function() return info.isActive end)
    if okActive and not (issecretvalue and issecretvalue(active)) and active == false then
        ClearChargeProxy(button)
        return
    end
    local okDuration, duration = pcall(C_ActionBar.GetActionChargeDuration, action)
    if okDuration and ((issecretvalue and issecretvalue(duration)) or duration ~= nil)
        and proxy.SetCooldownFromDurationObject then
        guarded[proxy] = true
        pcall(proxy.SetCooldownFromDurationObject, proxy, duration)
        local owner = owners[proxy]
        if owner then
            ApplyCooldown(proxy, owner)
            Queue(proxy, owner)
        end
        SuppressProxyText(proxy)
        guarded[proxy] = nil
        local host = proxyAlphaHosts[proxy]
        local okVisible, visible = button.IsVisible and pcall(button.IsVisible, button)
        if host then host:SetShown(okVisible == true and visible == true) end
    end
end

local function SetupChargeProxy(button, nativeCharge, owner)
    if not button then return end

    local proxy = chargeProxies[button]
    if not proxy then
        -- No CooldownFrameTemplate: it owns a countdown FontString and EUI's
        -- global cooldown-font hooks can reveal/update that number despite
        -- SetHideCountdownNumbers. A bare Cooldown has the swipe renderer but
        -- no text widget, so it cannot interfere with EUI's charge counter.
        local level = (button.cooldown and button.cooldown:GetFrameLevel()) or button:GetFrameLevel()
        local host = CreateFrame("Frame", nil, UIParent)
        host:SetAllPoints(button)
        host:SetFrameStrata(button:GetFrameStrata())
        host:SetFrameLevel(math.max(0, level - 1))
        host:EnableMouse(false)
        host:Hide()
        proxy = CreateFrame("Cooldown", nil, host)
        proxy:SetAllPoints(host)
        if proxy.SetIgnoreParentAlpha then proxy:SetIgnoreParentAlpha(false) end
        -- Keep the swipe with the icon/cooldown layer. Charge count, hotkey and
        -- other EUI text remain above it on the button's overlay layers.
        proxy:SetFrameLevel(level)
        proxyAlphaHosts[proxy] = host
        proxy:SetHideCountdownNumbers(true)
        proxy:SetDrawEdge(false)
        proxy:SetDrawBling(false)
        proxy:SetDrawSwipe(true)
        proxy:EnableMouse(false)
        host:SetAlpha(1)
        chargeProxies[button] = proxy
        chargeProxyFrames[proxy] = true
        RegisterCooldown(proxy, owner)
        ScheduleProxyTextSuppression(proxy)
    end
    SyncChargeProxy(button)
end

local function RefreshActionBarDurations()
    actionBarRefreshScheduled = false
    if not ScopeEnabled("actionBars") then return end
    for native in pairs(mainSwipeProxies) do
        if mainSwipeActive[native] then SyncMainSwipeProxy(native) end
    end
end

local function ScheduleActionBarDurations(delay)
    if actionBarRefreshScheduled or not ScopeEnabled("actionBars") then return end
    actionBarRefreshScheduled = true
    SUI:After(delay or .01, M, "action bar durations", RefreshActionBarDurations)
end

local function RefreshChargeDurations()
    chargeRefreshScheduled = false
    if not ScopeEnabled("actionBars") then return end
    for button in pairs(chargeProxies) do SyncChargeProxy(button) end
end

local function ScheduleChargeDurations(delay)
    if chargeRefreshScheduled or not ScopeEnabled("actionBars") then return end
    chargeRefreshScheduled = true
    SUI:After(delay or .04, M, "action bar charges", RefreshChargeDurations)
end

local COOLDOWN_KEYS = {
    "Cooldown", "cooldown", "CooldownFrame", "_cooldown", "__ECMECooldown",
    "chargeCooldown", "ChargeCooldown", "pandemicCooldown", "durationCooldown",
}

local function IsCooldown(frame)
    return frame and frame.GetObjectType and frame:GetObjectType() == "Cooldown"
end

function M:IsEUIOwnedActionButton(button)
    local name = button and button.GetName and button:GetName()
    return type(name) == "string" and name:match("^EABButton%d+$") ~= nil
end

-- EUI can place more than one Cooldown under an icon (main swipe, charge,
-- pandemic/fake-active and the 12.1 slot child). Returning the first one made
-- the result depend on creation order: one buff looked correct while the next
-- exposed another, still-square swipe. Collect the full subtree instead.
local CollectCooldowns
local function CollectChildren(ns, found, depth, ...)
    for index = 1, select("#", ...) do
        local child = select(index, ...)
        if IsCooldown(child) then found[child] = true
        else CollectCooldowns(child, ns, found, depth) end
    end
end

function CollectCooldowns(root, ns, found, depth)
    if not root or not root.GetChildren or (depth or 0) > 5 then return found end
    found = found or {}
    if M:IsBlizzardCooldownViewerFrame(root) then return found end
    local frameData = ns and ns._hookFrameData and ns._hookFrameData[root]
    if frameData and IsCooldown(frameData.cooldown) then found[frameData.cooldown] = true end
    for _, key in ipairs(COOLDOWN_KEYS) do
        local cooldown = root[key]
        if IsCooldown(cooldown) then found[cooldown] = true end
    end
    CollectChildren(ns, found, (depth or 0) + 1, root:GetChildren())
    return found
end

function M:ScanActionBars()
    if not ScopeEnabled("actionBars") then
        self.hookedActionBars = 0
        return 0
    end
    local ns = ModuleNamespace("EllesmereUIActionBars")
    if InCombatLockdown and InCombatLockdown() then
        ScheduleActionBarDurations(.01)
        return self.hookedActionBars or 0
    end
    self.hookedActionBars = 0
    if not ns or not ns.barButtons or not ns._eabFD then return 0 end
    local count, activeNative = 0, {}
    for _, buttons in pairs(ns.barButtons) do
        for _, button in ipairs(buttons) do
            local data = ns._eabFD[button]
            if self:IsEUIOwnedActionButton(button)
                and data and data.shapeApplied and data.shapeMaskPath then
                local owner = mainSwipeOwners[button.cooldown]
                if not owner or owner.frame ~= button then owner = { kind = "actionBars", ns = ns, frame = button } end
                local shapePath = ResolveActionBar(owner)
                if shapePath and button.cooldown
                    and SetupMainSwipeProxy(button, button.cooldown, owner) then
                    activeNative[button.cooldown] = true
                    count = count + 1
                end
                if shapePath then
                    -- EUI creates chargeCooldown lazily, sometimes in combat.
                    -- Prebuild our independent proxy while layout is mutable.
                    SetupChargeProxy(button, button.chargeCooldown, owner)
                end
            end
        end
    end
    for native in pairs(mainSwipeProxies) do
        if not activeNative[native] then ClearMainSwipeProxy(native) end
    end

    self.hookedActionBars = count
    return count
end

function M:ScanCooldownManager()
    local ns = ModuleNamespace("EllesmereUICooldownManager")
    self.hookedCooldownManager = 0
    if not ns or not ns._ecmeFC then return 0 end
    local count, seen = 0, {}
    local function RegisterIcon(icon, data)
        if not (data and data.shapeApplied and data.shapeName
            and data.shapeName ~= "none" and data.shapeName ~= "cropped")
            or self:IsBlizzardCooldownViewerFrame(icon) then return end
        local frameData = ns._hookFrameData and ns._hookFrameData[icon]
        local primary = (frameData and frameData.cooldown) or icon._cooldown or icon.Cooldown
        for cd in pairs(CollectCooldowns(icon, ns)) do
            if not seen[cd] and not self:IsBlizzardCooldownViewerFrame(cd) then
                seen[cd] = true
                count = count + 1
                RegisterCooldown(cd, { kind = "cooldownManager", ns = ns, frame = icon, primaryCooldown = primary })
            end
        end
    end
    for icon, data in pairs(ns._ecmeFC) do
        RegisterIcon(icon, data)
    end
    -- Fake-active and 12.1 slot frames can live only in the hook table while
    -- carrying shape metadata copied from their source icon.
    for icon in pairs(ns._hookFrameData or {}) do
        RegisterIcon(icon, ns._ecmeFC[icon])
    end
    self.hookedCooldownManager = count
    return count
end

function M:Scan()
    scanScheduled = false
    if not self:HasVisuals() then return end
    self:RestoreDisabledScopes()
    if not Profile().enabled then
        ClearAllMainSwipeProxies()
        ClearAllChargeProxies()
        self.hookedActionBars = 0
        self.hookedCooldownManager = 0
    else
        if ScopeEnabled("actionBars") then self:ScanActionBars() else self.hookedActionBars = 0 end
        if Profile().cooldownManager ~= false then self:ScanCooldownManager() else self.hookedCooldownManager = 0 end
    end
    if self.Effects and self.Effects:IsActive() then self.Effects:Scan() end
    if SUI.SettingsUI and SUI.SettingsUI.frame and SUI.SettingsUI.frame:IsShown() then
        SUI.SettingsUI:Refresh()
    end
end

function M:RestoreScope(kind)
    local changed = false
    for cd, owner in pairs(owners) do
        if owner and owner.kind == kind then changed = RestoreCooldown(cd) or changed end
    end
    if kind == "actionBars" then
        ClearAllMainSwipeProxies()
        ClearAllChargeProxies()
    end
    return changed
end

function M:RestoreDisabledScopes()
    self.restoredScopes = self.restoredScopes or {}
    local restored = false
    for _, kind in ipairs({ "actionBars", "cooldownManager" }) do
        if ScopeEnabled(kind) then
            self.restoredScopes[kind] = nil
        elseif not self.restoredScopes[kind] then
            restored = self:RestoreScope(kind) or restored
            self.restoredScopes[kind] = true
        end
    end
    if restored then self:RestoreEdges() end
end

function M:ScheduleScan(delay)
    if scanScheduled or not self:HasVisuals() then return end
    scanScheduled = true
    SUI:After(delay or 0, M, "cooldown scan", function() M:Scan() end)
end

function M:EnsureEUIHooks()
    if not self:HasVisuals() then return end
    if not self.broadcasterIsolation and self.BroadcasterGuard then self.BroadcasterGuard:Refresh() end
    if not (ScopeEnabled("cooldownManager") or (self.Effects and self.Effects:IsActive())) then return end
    for _, globalName in ipairs({ "_ECME_Apply" }) do
        local callback = _G[globalName]
        if type(callback) == "function" and hookedGlobals[globalName] ~= callback then
            hooksecurefunc(globalName, function() M:ScheduleScan(0.05) end)
            hookedGlobals[globalName] = _G[globalName]
        end
    end

end

function M:ShadeDiagnostic()
    local active = 0
    for native in pairs(mainSwipeProxies) do
        if mainSwipeActive[native] then active = active + 1 end
    end
    local profile = Profile()
    local mainAlpha = tonumber(profile.mainSwipeAlpha) or .55
    local chargeAlpha = tonumber(profile.chargeSwipeAlpha) or .38
    return SUI.Text("основной откат %.2f · заряды %.2f · слои отрисовки %d",
        "main %.2f · charges %.2f · visual proxies %d"):format(mainAlpha, chargeAlpha, active)
end

function M:Reconnect()
    self:EnsureEUIHooks()
    self:RefreshAll()
    return ModuleNamespace("EllesmereUIActionBars") ~= nil
        or ModuleNamespace("EllesmereUICooldownManager") ~= nil
end

function M:RefreshAll()
    self:RefreshRangeFade()
    self:EnsureEUIHooks()
    self:RestoreDisabledScopes()
    if not Profile().enabled or not ScopeEnabled("actionBars") then
        ClearAllMainSwipeProxies()
    end
    if not Profile().enabled or not ScopeEnabled("actionBars") then
        ClearAllChargeProxies()
        self.hookedActionBars = 0
    end
    if not ScopeEnabled("cooldownManager") then self.hookedCooldownManager = 0 end
    self:ScheduleScan(0)
    for cd, owner in pairs(owners) do Queue(cd, owner) end
    if self.Effects then self.Effects:RefreshAll() end
end

function M:OnEvent(event, unit)
    if not self.broadcasterIsolation and self.BroadcasterGuard then self.BroadcasterGuard:OnEvent(event) end
    if event == "PLAYER_LEAVING_WORLD" or event == "ADDON_RESTRICTION_STATE_CHANGED" then return end
    if event == "SPELL_UPDATE_CHARGES" then
        ScheduleChargeDurations(.04)
        -- EUI creates charge cooldowns lazily; discover only on this event.
        self:ScheduleScan(0.05)
        return
    end
    if event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN"
        or event == "ACTIONBAR_SLOT_CHANGED" then
        -- Cooldown events can arrive many times per second, and macro slot
        -- changes can burst. Keep one bounded pass instead of one per event.
        ScheduleActionBarDurations(event == "ACTIONBAR_SLOT_CHANGED" and .04 or .12)
        if event == "ACTIONBAR_SLOT_CHANGED" then ScheduleChargeDurations(.04) end
        return
    end
    if self.Effects then self.Effects:OnEvent(event, unit) end
    -- Stack effects update directly from UNIT_AURA.  A full icon-tree scan on
    -- every player aura pulse is unnecessary and expensive in combat.
    if event == "UNIT_AURA" then return end
    self:ScheduleScan(0.10)
end

function M:Initialize()
    self:RefreshRangeFade()
    if not self.broadcasterIsolation and self.BroadcasterGuard then self.BroadcasterGuard:Initialize() end
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
    SUI:RegisterModuleEvent(self, "PLAYER_SPECIALIZATION_CHANGED")
    SUI:RegisterModuleEvent(self, "TRAIT_CONFIG_UPDATED")
    SUI:RegisterModuleEvent(self, "SPELLS_CHANGED")
    SUI:RegisterModuleEvent(self, "SPELL_ACTIVATION_OVERLAY_SHOW")
    SUI:RegisterModuleEvent(self, "SPELL_ACTIVATION_OVERLAY_HIDE")
    SUI:RegisterModuleEvent(self, "UNIT_AURA")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_DISABLED")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    SUI:RegisterModuleEvent(self, "GROUP_ROSTER_UPDATE")
    SUI:RegisterModuleEvent(self, "ACTIONBAR_UPDATE_COOLDOWN")
    SUI:RegisterModuleEvent(self, "SPELL_UPDATE_COOLDOWN")
    SUI:RegisterModuleEvent(self, "ACTIONBAR_SLOT_CHANGED")
    SUI:RegisterModuleEvent(self, "SPELL_UPDATE_CHARGES")
    if SUI.isForever then SUI:RegisterModuleEvent(self, "CHARACTER_POINTS_CHANGED") end

    self:EnsureEUIHooks()

    self:ScheduleScan(0)
    if self:HasVisuals() then
        SUI:After(0.5, M, "startup scan", function() M:ScheduleScan(0) end)
        SUI:After(2.0, M, "startup scan delayed", function() M:ScheduleScan(0) end)
    end
end
