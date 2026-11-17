local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")
local ALL = 15
M.SelectionGlowWidth = 18

local function ShapeMode(mode)
    if mode == "ROUND" or mode == "SQUARE" then return mode end
    return "AUTO"
end

local function Radius(radius)
    return math.max(0, math.min(16, math.floor(tonumber(radius) or 0)))
end

function M:GetFrameShapeMode(configured, key)
    local style
    if configured then style = self:Profile().roundedFrames else style = self.appliedFrameShape end
    if not style then return "AUTO", 0 end
    local localStyle = key and style.elements and style.elements[key]
    if type(localStyle) ~= "table" then localStyle = nil end
    local localMode = localStyle and localStyle.mode
    local mode = ShapeMode(localMode and localMode ~= "INHERIT" and localMode or style.shapeMode)
    local localRadius = localStyle and Radius(localStyle.radius) or 0
    local radius = mode == "ROUND" and (localRadius > 0 and localRadius or Radius(style.radius)) or 0
    return mode, radius
end

function M:UpdateFrameShapeMode()
    local style = self:Profile().roundedFrames
    local last = self.appliedFrameShape
    local mode, radius = ShapeMode(style.shapeMode), Radius(style.radius)
    if last and last.shapeMode == mode and last.radius == radius and not self.frameShapeChanged then return false end
    local snapshot = { shapeMode = mode, radius = radius, elements = {} }
    for key, settings in pairs(style.elements or {}) do
        if type(settings) == "table" then
            snapshot.elements[key] = { mode = settings.mode, radius = Radius(settings.radius) }
        end
    end
    self.appliedFrameShape, self.frameShapeChanged = snapshot, nil
    return true
end

function M:SetFrameShapeValue(key, field, value)
    local style = self:Profile().roundedFrames
    if key then
        local settings = type(style.elements[key]) == "table" and style.elements[key] or {}
        settings[field] = value
        style.elements[key] = settings
    else
        style[field] = value
    end
    self.frameShapeChanged = true
    self:ScheduleRoundedRefresh()
end

function M:ResolveFrameShape(radius, corners, fallback, key, configured)
    local mode, override = self:GetFrameShapeMode(configured == true, key)
    radius = tonumber(radius) or 0
    corners = math.floor(tonumber(corners) or ALL) % 16
    if mode == "SQUARE" then return 0, ALL end
    if mode == "ROUND" and override > 0 then return override, corners > 0 and corners or ALL end
    if radius < 1 or corners == 0 then
        if mode == "ROUND" then return fallback, ALL end
        return 0, ALL
    end
    return radius, corners
end

local function Module(name)
    local eui = _G.EllesmereUI
    return eui and eui._ModuleNS and eui._ModuleNS[name]
end

local function Combat()
    return InCombatLockdown and InCombatLockdown()
end

local function Accessible(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
end

local powerOwners = setmetatable({}, { __mode = "k" })
local applyingUnit

local function UnitSettings(frame)
    local ns = Module("EllesmereUIUnitFrames")
    local unit = frame._euiBaseUnit
    local internals = ns and ns._internals
    if not (unit and internals and internals.GetSettingsForUnit) then return end
    local settings = internals.GetSettingsForUnit(unit)
    local boss = unit:match("^boss%d$") and ns.UF_BossBorderSettings
    local mini = (unit == "pet" or unit == "targettarget" or unit == "focustarget") and ns.GetMiniDonorSettings
    local source = (boss and boss()) or (mini and mini(unit)) or settings
    return settings, source, ns, boss or mini
end

-- Supply the same roots and border as the native renderer when its profile
-- starts with radius 0 and therefore supplies no RoundCorners options.
local function UnitOptions(owner, frame)
    local settings, source, ns, small = UnitSettings(frame)
    if not (settings and source and frame._barClip and not frame._blizzArtFrame) then return end
    local pos = ns.UF_PowerPos and ns.UF_PowerPos(settings)
    local detached = pos == "detached_top" or pos == "detached_bottom"
    local corners = ALL
    if detached and settings.cornerJoinPower and EllesmereUI.RoundedJoinCorners then
        local upper, lower = EllesmereUI.RoundedJoinCorners(ALL)
        if (owner == frame) == (pos == "detached_bottom") then corners = upper else corners = lower end
    end
    if owner ~= frame then
        if detached then
            return { border = owner._pbBorder, style = settings.powerBorderStyle or "solid", corners = corners }
        end
        return
    end
    local profile = ns.db and ns.db.profile
    local style = settings.portraitStyle or (profile and profile.portraitStyle) or "attached"
    local bd = frame.Portrait and frame.Portrait.backdrop
    if not (bd and bd:IsShown() and (style == "attached" or (small and style == "detached"))) then bd = nil end
    local text = frame.BottomTextBar
    return {
        roots = { frame._barClip, text and not text._isDetached and text or nil },
        textures = { bd and bd._bg, bd and bd._2d, bd and bd._class },
        border = frame.unifiedBorder, clip = frame._barClip,
        style = source.borderTexture or "solid", corners = corners,
    }
end

local function ApplyUnitShape(owner, frame, radius, opts, fallbackOptions, key)
    if Combat() then M.pendingRoundedFrames = true; return end
    if not Accessible(owner) or not Accessible(frame) then return end
    local wanted, corners = M:ResolveFrameShape(radius, opts and opts.corners, 8, key)
    if wanted == 0 then
        if radius > 0 then
            applyingUnit = true
            local ok, err = pcall(EllesmereUI.RoundCorners, owner, 0)
            applyingUnit = nil
            if not ok then error(err) end
        end
    elseif wanted ~= radius or (opts and opts.corners == 0) then
        if not opts or radius <= 0 or opts.corners == 0 then opts = fallbackOptions(owner, frame) end
        if opts then
            applyingUnit = true
            local ok, err = pcall(EllesmereUI.RoundCorners, owner, wanted, opts)
            applyingUnit = nil
            if not ok then error(err) end
        else
            wanted = 0
        end
    end
    if owner == frame and frame._euiBaseUnit == "target" then
        local style = opts and opts.style or "solid"
        if EllesmereUI.RoundedStyleOK and not EllesmereUI.RoundedStyleOK(style) then wanted = 0 end
        M:RememberTargetShape(frame, wanted, opts and opts.corners or corners)
    end
end

local function RaidOptions(owner, ns)
    local d = ns.GetFFD and ns.GetFFD(owner)
    if not (d and d.styled and d.borderFrame and not d.kit and not d.stockEdge and not d._compactBorder) then return end
    local settings = d._isParty and ns._scaledPartyProxy or (d._isExtra and ns._scaledExtraProxy) or ns._scaledProfile
    if not settings then return end
    return { roots = { d.health, d.power, d.topNameBar, d.powerBorderFrame }, textures = { d.bg },
        border = d.borderFrame, style = settings.borderTexture or "solid", corners = ALL }
end

local function UnitRounded(owner, radius, opts)
    if applyingUnit or not Accessible(owner) then return end
    local frame = (owner._euiBaseUnit and owner.unifiedBorder and owner) or powerOwners[owner]
    radius = tonumber(radius) or 0
    if frame then
        if owner == frame and frame.Power then powerOwners[frame.Power] = frame end
        SUI:SafeModuleCall(M, "Ellesmere unit frame shape", function()
            local unit = frame._euiBaseUnit
            local key = "unit:" .. (unit:match("^boss%d$") and "boss" or unit)
            ApplyUnitShape(owner, frame, radius, opts, UnitOptions, key)
        end)
    else
        local raid = Module("EllesmereUIRaidFrames")
        if raid and raid._euiUnitButtons and raid._euiUnitButtons[owner] then
            SUI:SafeModuleCall(M, "Ellesmere group frame shape", function()
                local d = raid.GetFFD and raid.GetFFD(owner)
                local key = d and d._isParty and "euiParty" or "euiRaid"
                ApplyUnitShape(owner, owner, radius, opts, function(button) return RaidOptions(button, raid) end, key)
            end)
        end
    end
end

-- These providers paint synchronously. Borrow the shape fields just for the
-- second render, restoring their exact raw values even if the renderer fails.
-- The options profile, defaults and SavedVariables keep their own choices.
local rendering = false
local function RenderWithShape(config, fallback, key, render, ...)
    if rendering or type(config) ~= "table" or M:GetFrameShapeMode(false, key) == "AUTO" then return end
    local radius, corners = M:ResolveFrameShape(config.cornerRadius, config.cornerMask, fallback, key)
    local previousRadius, previousCorners = config.cornerRadius or 0, config.cornerMask or ALL
    if radius == previousRadius and (radius == 0 or corners == previousCorners) then return end
    local rawRadius, rawCorners = rawget(config, "cornerRadius"), rawget(config, "cornerMask")
    rendering = true
    rawset(config, "cornerRadius", radius)
    rawset(config, "cornerMask", corners)
    local ok, err = pcall(render, ...)
    rawset(config, "cornerRadius", rawRadius)
    rawset(config, "cornerMask", rawCorners)
    rendering = false
    if not ok then error(err) end
end

local hooks = setmetatable({}, { __mode = "k" })
local function Hook(namespace, method, callback)
    if not (namespace and type(namespace[method]) == "function") then return false end
    local methods = hooks[namespace]
    if not methods then methods = {}; hooks[namespace] = methods end
    if methods[method] then return false end
    hooksecurefunc(namespace, method, callback)
    methods[method] = true
    return true
end

local queuedNameplateChecks = {}

local function RepairNameplateShape(ns, unit)
    local eui, nameplates = _G.EllesmereUI, SUI.Nameplates
    local plate = ns.plates and ns.plates[unit]
    local health = plate and plate.health
    if not (nameplates and eui and type(eui.RoundCorners) == "function" and Accessible(plate)
        and Accessible(health) and plate:IsShown()) then return end
    local owner = plate.unit
    local token = plate.nameplate and plate.nameplate.namePlateUnitToken
    if (issecretvalue and (issecretvalue(owner) or issecretvalue(token)))
        or owner ~= unit or (token and token ~= unit) then return end
    local border = plate._customBorder
    local custom = ns.IsCustomBorderEnabled and ns.IsCustomBorderEnabled()
    if not nameplates:GetNativePlateRounding(custom and border or health, ns) then return end
    local ok, fill = pcall(health.GetStatusBarTexture, health)
    if not ok or (issecretvalue and issecretvalue(fill)) then return end
    if M:HasNativeNameplateMask(fill) ~= false and M:HasNativeNameplateMask(plate.healthBG) ~= false then return end
    if border and not Accessible(border) then return end
    if Combat() and ((plate.IsProtected and plate:IsProtected()) or (health.IsProtected and health:IsProtected())
        or (border and border.IsProtected and border:IsProtected())) then
        if not M.pendingNameplateSeams then
            M.pendingNameplateSeams = true
            SUI:RefreshModuleEvents()
        end
        return
    end
    if custom and not border and type(plate.ApplyBorder) == "function" then
        plate:ApplyBorder()
        return
    end
    -- The renderer can still have this texture in its mask cache after reuse.
    eui.RoundCorners(plate, 0)
    ns.NP_ApplyRounding(plate, "health")
end

function M:QueueNameplateRoundingCheck(unit)
    local ns = self.roundingNameplateNS
    if not ns or (issecretvalue and issecretvalue(unit)) or type(unit) ~= "string" or queuedNameplateChecks[unit] then return end
    queuedNameplateChecks[unit] = true
    SUI:After(0, self, "check nameplate rounding", function()
        local ok, err = true
        if self.roundingNameplateNS == ns then ok, err = pcall(RepairNameplateShape, ns, unit) end
        queuedNameplateChecks[unit] = nil
        if not ok then error(err) end
    end)
end

function M:InstallFrameShapeHooks()
    if not hooksecurefunc or not SUI:IntegrationEnabled("frames") then return end
    local changed = Hook(_G.EllesmereUI, "RoundCorners", UnitRounded)
    local nameplates = Module("EllesmereUINameplates")
    changed = Hook(nameplates, "NP_ApplyRounding", function(plate, part)
        if not (Accessible(plate) and Accessible(plate.health))
            or (Combat() and plate.IsProtected and plate:IsProtected()) then return end
        local profile = nameplates.db and nameplates.db.profile
        SUI:SafeModuleCall(M, "Ellesmere nameplate shape", function()
            RenderWithShape(profile, 8, "plates", nameplates.NP_ApplyRounding, plate)
        end)
        if not rendering and part ~= "cast" then M:QueueNameplateRoundingCheck(plate.unit) end
    end) or changed
    local roundingNS = nameplates and type(nameplates.NP_ApplyRounding) == "function" and nameplates or nil
    if self.roundingNameplateNS ~= roundingNS then
        self.roundingNameplateNS = roundingNS
        if SUI.initialized then SUI:RefreshModuleEvents() end
    end
    local resource = Module("EllesmereUIResourceBars")
    changed = Hook(resource, "ERB_RoundBar", function(bar, config)
        if not Combat() and Accessible(bar) then
            SUI:SafeModuleCall(M, "Ellesmere resource shape", function()
                local db = _G._ERB_AceDB
                local profile = db and db.profile
                local key = profile and config == profile.health and "health" or "mana"
                RenderWithShape(config, 4, key, resource.ERB_RoundBar, bar, config)
            end)
        end
    end) or changed
    changed = Hook(resource, "ERB_RoundSecondary", function(config, barType)
        if not Combat() then
            SUI:SafeModuleCall(M, "Ellesmere class resource shape", function()
                RenderWithShape(config, 4, "secondary", resource.ERB_RoundSecondary, config, barType)
            end)
        end
    end) or changed
    return changed
end

function M:RefreshNativeFrameShapes()
    if not SUI:IntegrationEnabled("frames") then return end
    local unit = Module("EllesmereUIUnitFrames")
    -- ReloadFrames is the native throttle stub. The real render is observed
    -- through RoundCorners, including when an Ellesmere profile is switched.
    if unit and type(unit.ReloadFrames) == "function" then unit.ReloadFrames() end
    local raid = Module("EllesmereUIRaidFrames")
    if raid and raid.db and raid._euiUnitButtons and next(raid._euiUnitButtons) then
        if type(raid.ReloadFrames) == "function" then raid.ReloadFrames() end
        if type(raid.ReloadPartyFrames) == "function" then raid.ReloadPartyFrames() end
    end
    local plates = Module("EllesmereUINameplates")
    if plates and plates.db and type(plates.RefreshBorder) == "function" then
        plates.RefreshBorder()
        if type(plates.NP_ApplyRounding) == "function" then
            for _, plate in pairs(plates.plates or {}) do
                if Accessible(plate) then plates.NP_ApplyRounding(plate, "cast") end
            end
            for _, plate in pairs(plates.friendlyPlates or {}) do
                if Accessible(plate) then plates.NP_ApplyRounding(plate, "cast") end
            end
        end
    end
    if type(_G._ERB_Apply) == "function" then _G._ERB_Apply() end
end

