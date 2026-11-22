local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")
local roundedArt = "Interface\\AddOns\\EllesmereUI\\media\\rounded\\rounded-"
local targetShape = {}
local marker
local markerPending
local plateMarkers = setmetatable({}, { __mode = "k" })
local markerPlates = setmetatable({}, { __mode = "k" })
local markerShowHooks = setmetatable({}, { __mode = "k" })
local markerTextureHooks = setmetatable({}, { __mode = "k" })
local pendingPlates = {}
local plateRetryDelays = { .12, .16, .36, 2.8 }
local plateHooks = setmetatable({}, { __mode = "k" })
local shownBuffs = setmetatable({}, { __mode = "k" })
local glowHooks = setmetatable({}, { __mode = "k" })
local playerDispelMasks = setmetatable({}, { __mode = "k" })
local dispelStyleHooks = setmetatable({}, { __mode = "k" })
local dispelKitHooks = setmetatable({}, { __mode = "k" })

local function Public(v)
    return type(v) == "number" and not (issecretvalue and issecretvalue(v))
end

local function ScheduleMarker()
    if markerPending then return end
    markerPending = true
    SUI:After(0, M, "Does It Die target shape", function()
        markerPending = nil
        M:ApplyDamageMarkerShape()
    end)
end

function M:RememberTargetShape(frame, radius, corners)
    if targetShape.frame == frame and targetShape.radius == radius and targetShape.corners == corners then return end
    targetShape.frame, targetShape.radius, targetShape.corners = frame, radius, corners
    if marker then ScheduleMarker() end
end

local function ClearDamageMask(state)
    for texture in pairs(state.masked) do
        pcall(texture.RemoveMaskTexture, texture, state.boundMask or state.mask)
        state.masked[texture] = nil
    end
    state.mask:Hide()
    if state.forecastMask then
        for texture in pairs(state.forecastMasked) do pcall(texture.RemoveMaskTexture, texture, state.forecastMask) end
        wipe(state.forecastMasked)
        state.forecastMask:Hide()
    end
    state.frame, state.radius, state.corners, state.span, state.boundMask, state.nativeMask = nil, nil, nil, nil, nil, nil
end

local function SetRoundedMaskArt(mask, radius, corners)
    local suffix = corners == 15 and "" or "-" .. corners
    mask:SetTexture(roundedArt .. radius .. suffix .. ".tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetTextureSliceMargins(radius, radius, radius, radius)
    mask:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

local function BindDamageMarker(bar)
    if not (bar.GetStatusBarTexture and bar:GetStatusBarTexture() and bar.CreateMaskTexture) then return end
    local state = { bar = bar, mask = bar:CreateMaskTexture(), masked = {} }
    state.mask:Hide()
    hooksecurefunc(bar, "SetPoint", ScheduleMarker)
    hooksecurefunc(bar, "SetAllPoints", ScheduleMarker)
    bar:HookScript("OnShow", ScheduleMarker)
    return state
end

function M:ApplyDamageMarkerShape()
    local state = marker
    if not state then return end
    local frame, radius, corners = targetShape.frame, targetShape.radius, targetShape.corners
    local _, anchor = state.bar:GetPoint(1)
    if not (frame and radius and radius > 0 and anchor == frame.Health) then
        if state.frame then ClearDamageMask(state) end
        return
    end
    local height = frame:GetHeight()
    if Public(height) and height > 2 then radius = math.min(radius, math.floor((height - 1) / 2)) end
    radius = math.max(1, math.min(16, math.floor(radius)))
    corners = corners or 15
    if state.frame == frame and state.radius == radius and state.corners == corners then return end
    ClearDamageMask(state)
    -- Clip the native marker to the same stationary silhouette as its host.
    -- The moving damage span keeps its own fill, outline, and animations.
    local mask = state.mask
    SetRoundedMaskArt(mask, radius, corners)
    mask:ClearAllPoints()
    mask:SetAllPoints(frame)
    mask:Show()
    for _, child in ipairs({ state.bar:GetChildren() }) do
        for _, texture in ipairs({ child:GetRegions() }) do
            if texture:GetObjectType() == "Texture" and texture.AddMaskTexture then
                if pcall(texture.AddMaskTexture, texture, mask) then state.masked[texture] = true end
            end
        end
    end
    state.frame, state.radius, state.corners = frame, radius, corners
end

local function IsAnchoredTo(region, target)
    local ok, _, anchor = pcall(region.GetPoint, region, 1)
    return ok and not (issecretvalue and issecretvalue(anchor)) and anchor == target
end

local function ReadTexturePath(texture, get)
    if not get then return end
    local ok, path = pcall(get, texture)
    if ok and type(path) == "string" and not (issecretvalue and issecretvalue(path)) and path ~= "" then
        return path:lower():gsub("\\", "/")
    end
end

local function TexturePath(texture)
    return ReadTexturePath(texture, texture.GetTextureFilePath) or ReadTexturePath(texture, texture.GetTexture)
end

local function GetMaskCount(texture)
    if not (texture and texture.GetNumMaskTextures and texture.GetMaskTexture) then return end
    local ok, count = pcall(texture.GetNumMaskTextures, texture)
    if ok and Public(count) then return count end
end

local function GetMaskAt(texture, index)
    local ok, mask = pcall(texture.GetMaskTexture, texture, index)
    if ok and not (issecretvalue and issecretvalue(mask)) then return mask end
end

local function HasMask(texture, wanted)
    local count = GetMaskCount(texture)
    if count == nil then return end
    local unreadable
    for index = 1, count do
        local mask = GetMaskAt(texture, index)
        if mask == wanted then return true end
        if not mask then unreadable = true end
    end
    if not unreadable then return false end
end

local function AddMask(texture, mask)
    if HasMask(texture, mask) == true then return true end
    local ok = pcall(texture.AddMaskTexture, texture, mask)
    return ok and HasMask(texture, mask) ~= false
end

local function NativeHealthMask(texture)
    local count = GetMaskCount(texture)
    if count == nil then return end
    local readable = true
    for index = 1, count do
        local mask = GetMaskAt(texture, index)
        local path = mask and TexturePath(mask)
        local radius, corners
        if path then radius, corners = path:match("/ellesmereui/media/rounded/rounded%-(%d+)%-?(%d*)") end
        if radius then return mask, tonumber(radius), tonumber(corners) or 15, true end
        if not path then readable = false end
    end
    return nil, nil, nil, readable
end

local function PlayerHealthMask(health)
    local background, radius, corners, readable = NativeHealthMask(health.bg)
    if background then return background, radius, corners, true end
    local ok, fill = pcall(health.GetStatusBarTexture, health)
    if ok and not (issecretvalue and issecretvalue(fill)) then
        local native, r, c, fillReadable = NativeHealthMask(fill)
        return native, r, c, fillReadable or readable
    end
    return nil, nil, nil, readable
end

local function FitPlayerDispelMask(texture, state, native, radius, corners)
    local mask = state.mask
    local attached = state.attached and HasMask(texture, mask) ~= false
    if attached and state.native == native and state.radius == radius and state.corners == corners then return end
    if attached then texture:RemoveMaskTexture(mask) end
    state.attached = nil
    if not native then return end
    SetRoundedMaskArt(mask, radius, corners)
    mask:ClearAllPoints()
    mask:SetAllPoints(native)
    state.native, state.radius, state.corners = native, radius, corners
    state.attached = AddMask(texture, mask)
end

local function InstallPlayerDispelMasks(eui)
    local unit = eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIUnitFrames
    local kit = unit and eui.AuraKit
    if not (kit and type(kit.styles) == "table" and type(kit.MakeInitializer) == "function"
        and type(kit.RestyleSoon) == "function" and type(eui.RoundCorners) == "function") or dispelKitHooks[kit] then return end
    dispelKitHooks[kit] = true

    local function HookStyle(key)
        if type(key) ~= "string" or not key:match("^uf:player:dispelfill:") then return end
        local style = kit.styles[key]
        if not (style and style.fillSet and type(style.applyExtra) == "function") or dispelStyleHooks[style] then return end
        dispelStyleHooks[style] = true
        hooksecurefunc(style, "applyExtra", function(button, data, currentStyle)
            local texture, health = data.overlay, currentStyle.healthFrame
            if not (texture and health and SUI:IntegrationEnabled("frames")) then return end
            -- Capture the actual gradient while AuraKit is styling its slot. The
            -- mask lives with that texture even when the button becomes restricted.
            SUI:SafeModuleCall(M, "player dispel overlay mask", function()
                local state = playerDispelMasks[texture]
                if not state then
                    if kit.CanTouchButton and not kit.CanTouchButton(button) then
                        if kit.DeferRestyle then kit.DeferRestyle(key) end
                        return
                    end
                    if not button.CreateMaskTexture then return end
                    state = { mask = button:CreateMaskTexture(), health = health }
                    playerDispelMasks[texture] = state
                end
                local native, radius, corners, readable = PlayerHealthMask(health)
                if readable or native then FitPlayerDispelMask(texture, state, native, radius, corners) end
            end)
        end)
    end

    hooksecurefunc(kit, "MakeInitializer", HookStyle)
    hooksecurefunc(kit, "RestyleSoon", HookStyle)
    hooksecurefunc(eui, "RoundCorners", function(owner)
        if not (owner and owner._euiBaseUnit == "player" and owner.Health) then return end
        local health = owner.Health
        local native, radius, corners, readable = PlayerHealthMask(health)
        if not (native or readable) then return end
        for texture, state in pairs(playerDispelMasks) do
            if state.health == health then
                SUI:SafeModuleCall(M, "player dispel overlay shape", function()
                    FitPlayerDispelMask(texture, state, native, radius, corners)
                end)
            end
        end
    end)
    for key in pairs(kit.styles) do
        if type(key) == "string" and key:match("^uf:player:dispelfill:") then kit.RestyleSoon(key) end
    end
end

function M:HasNativeNameplateMask(texture)
    local mask, _, _, readable = NativeHealthMask(texture)
    if readable then return mask ~= nil end
end

local function InspectNameplateMarker(child, health, cast)
    if child == health or child == cast or child:GetObjectType() ~= "StatusBar"
        or (child.IsForbidden and child:IsForbidden()) then return end
    local ok, span = pcall(child.GetStatusBarTexture, child)
    if not ok or (issecretvalue and issecretvalue(span)) then span = nil end
    local fill, outline, artwork, overlay, didArt = false, 0, 0, 0, false
    local textures = {}
    for _, texture in ipairs({ child:GetRegions() }) do
        if texture:GetObjectType() == "Texture" and texture ~= span and texture.AddMaskTexture then
            textures[#textures + 1] = texture
            local path = TexturePath(texture)
            if path and path:find("/doesitdieadvanced/textures/", 1, true) then didArt = true end
            local layer = texture:GetDrawLayer()
            if layer == "ARTWORK" then artwork = artwork + 1
            elseif layer == "OVERLAY" then overlay = overlay + 1 end
            if span and IsAnchoredTo(texture, span) then
                if layer == "ARTWORK" then fill = true
                elseif layer == "OVERLAY" then outline = outline + 1 end
            end
        end
    end
    if didArt and #textures >= 5 then return textures, 3 end
    if fill and outline == 4 and IsAnchoredTo(child, health) then return textures, 2 end
    -- DIDA 1.2 builds four segment StatusBars, five fill regions and
    -- four outline regions. Match that shape when its anchors are secret.
    if overlay ~= 4 or artwork < 5 then return end
    local segments = 0
    for _, segment in ipairs({ child:GetChildren() }) do
        if segment:GetObjectType() == "StatusBar" then segments = segments + 1 end
    end
    if segments == 4 then return textures, 1 end
end

local function IsVisibleMarker(bar)
    local ok, visible = pcall(bar.IsVisible or bar.IsShown, bar)
    return ok and not (issecretvalue and issecretvalue(visible)) and visible == true
end

local function SearchMarkerHost(host, plate, health, found, depth)
    if not host or (host.IsForbidden and host:IsForbidden()) then return end
    local children = { pcall(host.GetChildren, host) }
    if not children[1] then return end
    for i = 2, #children do
        local child = children[i]
        if child ~= plate then
            local ok, textures, score = pcall(InspectNameplateMarker, child, health, plate.cast)
            if ok and textures then
                score = score + (IsVisibleMarker(child) and 4 or 0)
                if score > found.score then
                    found.bar, found.textures, found.score = child, textures, score
                end
            elseif depth > 0 then
                SearchMarkerHost(child, plate, health, found, depth - 1)
            end
        end
    end
end

local function FindNameplateMarker(plate, health)
    local found = { score = 0 }
    -- DIDA can attach to the displayed Ellesmere plate or to the base
    -- Blizzard plate while pointing at a bar provided by another addon.
    SearchMarkerHost(plate, plate, health, found, 1)
    local base = plate.nameplate
    if not base and plate.unit and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, native = pcall(C_NamePlate.GetNamePlateForUnit, plate.unit)
        if ok and not (issecretvalue and issecretvalue(native)) then base = native end
    end
    if base and base ~= plate then SearchMarkerHost(base, plate, health, found, 1) end
    return found.bar, found.textures
end

local function PrepareForecastMask(state, span, radius)
    local mask = state.forecastMask or state.bar:CreateMaskTexture()
    state.forecastMask = mask
    state.forecastMasked = state.forecastMasked or {}
    SetRoundedMaskArt(mask, radius, 15)
    mask:ClearAllPoints()
    -- Anchor to the prediction's own fill. The client shrinks the sliced
    -- corners on a narrow prediction; Lua never needs the span's dimensions.
    mask:SetAllPoints(span)
    mask:Show()
    return mask
end

local function SyncNameplateMarker(plate, ns, state)
    local health = plate.health
    if not health then return end
    local rect = health
    local custom = plate._customBorder
    if custom and custom:IsShown() and ns.IsCustomBorderEnabled and ns.IsCustomBorderEnabled() then rect = custom end
    local radius, corners = SUI.Nameplates:GetNativePlateRounding(rect, ns)
    if radius and plate._npJoinCast and plate.cast and plate.cast:IsShown() and EllesmereUI.RoundedJoinCorners then
        corners = EllesmereUI.RoundedJoinCorners(corners)
    end
    if not radius then
        if state.frame then ClearDamageMask(state) end
        state.ready = true
        return true
    end
    local inset = 1
    local eui = _G.EllesmereUI
    local pp = eui and eui.PP
    local cont = pp and pp.GetBorders and pp.GetBorders(rect)
    local scale = rect:GetEffectiveScale()
    local edge = cont and cont:IsShown() and cont._snapEdge
    if Public(scale) and scale > 0 and pp and Public(pp.perfect) then
        local pixel = pp.perfect / scale
        if Public(edge) then
            local borderScale = cont:GetEffectiveScale()
            if Public(borderScale) then inset = math.max(1, edge * borderScale / scale + pixel) end
        end
    end
    local native, nativeRadius, nativeCorners = NativeHealthMask(plate.healthBG)
    if not native then
        local ok, fill = pcall(health.GetStatusBarTexture, health)
        if ok and not (issecretvalue and issecretvalue(fill)) then
            native, nativeRadius, nativeCorners = NativeHealthMask(fill)
        end
    end
    radius = nativeRadius or math.max(1, math.floor(radius - inset + .5))
    corners = nativeCorners or corners
    local healthMask = state.mask
    local ok, span = pcall(state.bar.GetStatusBarTexture, state.bar)
    if not ok or (issecretvalue and issecretvalue(span)) then span = nil end
    if state.ready and state.frame == rect and state.radius == radius and state.corners == corners
        and state.span == span and state.inset == inset and state.nativeMask == native then return true end
    state.ready = false
    ClearDamageMask(state)
    -- Copy the health silhouette onto a mask owned by the DIDA marker.
    -- Anchors track the target's live scale, but the mask stays in the
    -- marker's render group rather than sharing a mask across plate layers.
    SetRoundedMaskArt(healthMask, radius, corners)
    healthMask:ClearAllPoints()
    if native then
        healthMask:SetAllPoints(native)
    else
        healthMask:SetPoint("TOPLEFT", rect, "TOPLEFT", inset, -inset)
        healthMask:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", -inset, inset)
    end
    healthMask:Show()
    state.boundMask, state.nativeMask = healthMask, native
    local forecast
    if span then
        local prepared, result = pcall(PrepareForecastMask, state, span, radius)
        if prepared then forecast = result end
    end
    local ready = forecast ~= nil
    for _, texture in ipairs(state.textures) do
        if AddMask(texture, healthMask) then state.masked[texture] = true
        else ready = false end
        if forecast then
            if AddMask(texture, forecast) then state.forecastMasked[texture] = true
            else ready = false end
        end
    end
    state.frame, state.radius, state.corners, state.span, state.inset = rect, radius, corners, span, inset
    state.ready = ready
    return ready
end

local function RefreshMarkerMasks(bar, checkMasks)
    local owner = markerPlates[bar]
    local state = owner and plateMarkers[owner]
    if not state or state.bar ~= bar then return end
    if checkMasks then
        for texture in pairs(state.masked) do
            if HasMask(texture, state.boundMask) == false
                or (state.forecastMask and HasMask(texture, state.forecastMask) == false) then
                state.ready = false
                break
            end
        end
    end
    SUI:SafeModuleCall(M, "refresh Does It Die mask", function()
        SyncNameplateMarker(owner, M.didPlateNS, state)
    end)
end

local function BindNameplateMarker(plate)
    local state = plateMarkers[plate]
    if state and state.health == plate.health and IsVisibleMarker(state.bar) then return state end
    local bar, textures = FindNameplateMarker(plate, plate.health)
    if not bar then return state end
    if state and state.bar == bar then return state end
    if state then
        ClearDamageMask(state)
        markerPlates[state.bar] = nil
    end
    local other = markerPlates[bar]
    local previous = other and plateMarkers[other]
    if previous and previous.bar == bar then
        ClearDamageMask(previous)
        plateMarkers[other] = nil
    end
    state = { bar = bar, mask = bar:CreateMaskTexture(), textures = textures, masked = {} }
    state.mask:Hide()
    plateMarkers[plate], markerPlates[bar] = state, plate
    for _, texture in ipairs(textures) do
        if type(texture.SetTexture) == "function" and not markerTextureHooks[texture] then
            markerTextureHooks[texture] = true
            hooksecurefunc(texture, "SetTexture", function()
                local owner = markerPlates[bar]
                local current = owner and plateMarkers[owner]
                if not current or current.bar ~= bar or not current.boundMask or current.pendingPaint then return end
                current.pendingPaint = true
                SUI:After(0, M, "restore Does It Die masks after repaint", function()
                    current.pendingPaint = nil
                    RefreshMarkerMasks(bar, true)
                end)
            end)
        end
    end
    if bar.HookScript and not markerShowHooks[bar] then
        markerShowHooks[bar] = true
        bar:HookScript("OnShow", function() RefreshMarkerMasks(bar, true) end)
    end
    return state
end

function M:QueueNameplateDamageMarker(unit)
    local ns = self.didPlateNS
    if not ns or type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) then return end
    if unit == "target" then
        local target = ns._cachedTargetPlate
        unit = target and target.unit
    end
    local db = _G.DoesItDieAdvancedDB
    if not (type(unit) == "string" and unit:match("^nameplate%d+$"))
        or pendingPlates[unit] or (db and (db.nameplateMode == "off" or db.showMarkers == false)) then return end
    local current = ns.plates and ns.plates[unit]
    local cached = current and plateMarkers[current]
    if cached and cached.ready and cached.health == current.health and IsVisibleMarker(cached.bar) then return end
    local attempts = 0
    local function Try()
        local plate = ns.plates and ns.plates[unit]
        if plate and plate.health and not (plate.IsForbidden and plate:IsForbidden()) then
            local okBind, state = pcall(BindNameplateMarker, plate)
            if not okBind then state = nil end
            if state then
                state.health = plate.health
                local ok, ready = pcall(SyncNameplateMarker, plate, ns, state)
                if ok and ready then
                    pendingPlates[unit] = nil
                    return
                end
            end
        end
        attempts = attempts + 1
        if plateRetryDelays[attempts] and UnitExists(unit) then
            SUI:After(plateRetryDelays[attempts], M, "find Does It Die nameplate marker", Try)
        else
            pendingPlates[unit] = nil
        end
    end
    pendingPlates[unit] = true
    SUI:After(0, M, "find Does It Die nameplate marker", Try)
end

local function InstallNameplateDamageMasks(eui)
    local ns = eui._ModuleNS and eui._ModuleNS.EllesmereUINameplates
    if not (ns and type(ns.NP_ApplyRounding) == "function" and SUI.Nameplates) then return end
    local new = M.didPlateNS ~= ns
    M.didPlateNS = ns
    if not plateHooks[ns] then
        plateHooks[ns] = true
        hooksecurefunc(ns, "NP_ApplyRounding", function(plate)
            local state = plate and plateMarkers[plate]
            if state then
                SUI:SafeModuleCall(M, "Does It Die nameplate shape", function()
                    SyncNameplateMarker(plate, ns, state)
                end)
            end
        end)
    end
    if new then
        SUI:RefreshModuleEvents()
        for unit in pairs(ns.plates or {}) do M:QueueNameplateDamageMarker(unit) end
    end
end

function M:PrintDidaShapeStatus()
    local ns = self.didPlateNS
    local plate = ns and ns._cachedTargetPlate
    if ns and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, native = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        if ok and not (issecretvalue and issecretvalue(native)) and native
            and (not plate or plate.nameplate ~= native) then
            plate = nil
            for _, candidate in pairs(ns.plates or {}) do
                if candidate.nameplate == native then plate = candidate; break end
            end
        end
    end
    if not plate and SUI.Nameplates then
        local _, candidate = SUI.Nameplates:FindTargetPlate()
        plate = candidate
    end
    if not (plate and plate.health) then
        SUI:Print(SUI.Text("Does It Die — выбери цель с видимым неймплейтом.", "Does It Die · Select a target with a visible nameplate."))
        return
    end
    if not ns then
        SUI:Print(SUI.Text("Does It Die — интеграция неймплейтов не загружена.", "Does It Die · The nameplate integration is not loaded."))
        return
    end
    local ok, state = pcall(BindNameplateMarker, plate)
    if not ok or not state then
        SUI:Print(SUI.Text("Does It Die — виджет не найден на фреймах Ellesmere и Blizzard.", "Does It Die · No widget found on Ellesmere or Blizzard frames."))
        return
    end
    state.health = plate.health
    pcall(SyncNameplateMarker, plate, ns, state)
    local count = 0
    for texture in pairs(state.masked) do
        if HasMask(texture, state.boundMask) ~= false then count = count + 1 end
    end
    local source = not state.boundMask and SUI.Text("нет", "none") or (state.nativeMask and SUI.Text("Sintezza UI по форме Ellesmere", "Sintezza UI with the Ellesmere shape") or "Sintezza UI")
    SUI:Print((SUI.Text("Does It Die — маска %s, текстур %d/%d, радиус %s.", "Does It Die · Mask %s, textures %d/%d, radius %s.")):format(source, count,
        #state.textures, tostring(state.radius or 0)))
end

local function ApplyReminderGlow(glows, wrapper, spec, width, height, host, extra)
    local icon = host == "icon" and wrapper and wrapper:GetParent()
    if not (icon and icon._eabrGlowWrapper == wrapper and spec) then return end
    local style = glows.STYLES and glows.STYLES[spec.style]
    local shape = icon._eabrShape
    local eui = _G.EllesmereUI
    local border = shape and eui.SHAPE_BORDERS and eui.SHAPE_BORDERS[shape.shape]
    if not (style and style.procedural and border and extra and extra.shapeMask
        and M:GetFrameShapeMode() ~= "SQUARE") then
        shownBuffs[wrapper] = nil
        return
    end
    if InCombatLockdown and InCombatLockdown() then M.pendingRoundedFrames = true; return end
    local old = shownBuffs[wrapper]
    local data = wrapper._euiSgData
    if old and data and data.glow:IsShown() and old.border == border and old.mask == extra.shapeMask
        and old.width == width and old.height == height and old.r == spec.r and old.g == spec.g and old.b == spec.b then
        return
    end
    local options = { maskPath = extra.maskPath, borderPath = border, shapeMask = extra.shapeMask }
    if old and old.mask ~= extra.shapeMask and data then
        pcall(data.glow.RemoveMaskTexture, data.glow, old.mask)
    end
    glows.StopProceduralAnts(wrapper)
    glows.StartShapeGlow(wrapper, width or 36, spec.r or 1, spec.g or .82, spec.b or 0, 1.2, options)
    shownBuffs[wrapper] = { border = border, mask = extra.shapeMask, width = width, height = height,
        r = spec.r, g = spec.g, b = spec.b }
end

local function InstallCDMBuffGlow(eui, glows)
    local ns = eui._ModuleNS and eui._ModuleNS.EllesmereUICooldownManager
    if not (ns and type(glows.StartProceduralAnts) == "function"
        and type(glows.StopProceduralAnts) == "function" and type(glows.StartShapeGlow) == "function")
        or glowHooks[ns] then return end
    glowHooks[ns] = true
    hooksecurefunc(glows, "StartProceduralAnts", function(wrapper, _, _, _, _, r, g, b, width, height)
        if not wrapper or wrapper._euiGlowPreview then return end
        local icon = wrapper:GetParent()
        local fd = icon and ns._hookFrameData and ns._hookFrameData[icon]
        if not fd then return end
        local fc = ns._ecmeFC and ns._ecmeFC[icon]
        if wrapper ~= fd.buffGlowOverlay and wrapper ~= fd.maxStacksGlowOverlay then
            if wrapper ~= fd.glowOverlay and wrapper ~= fd.pandemicOverlay then return end
            local bar = fc and fc.barKey and ns.GetBarData and ns.GetBarData(fc.barKey)
            if not (bar and ns.IsBarBuffFamily and ns.IsBarBuffFamily(bar)) then return end
        end
        local shape = fc and fc.shapeApplied and fc.shapeName
        local maskPath = shape and ns.CDM_SHAPE_MASKS and ns.CDM_SHAPE_MASKS[shape]
        local borderPath = shape and ns.CDM_SHAPE_BORDERS and ns.CDM_SHAPE_BORDERS[shape]
        if not (maskPath and borderPath and Public(width) and Public(height)) then return end
        if (wrapper.IsForbidden and wrapper:IsForbidden())
            or (InCombatLockdown and InCombatLockdown() and wrapper.IsProtected and wrapper:IsProtected()) then return end
        SUI:SafeModuleCall(M, "Ellesmere CDM buff contour", function()
            -- Keep textures on the glow overlay, so CDM's visibility and
            -- threshold masks can still manage them.
            glows.StartShapeGlow(wrapper, math.min(width, height), r, g, b, 1.2,
                { maskPath = maskPath, borderPath = borderPath, anchorFrame = wrapper })
            glows.StopProceduralAnts(wrapper)
        end)
    end)
end

function M:RefreshShapeOverlays()
    if not hooksecurefunc then return end
    local bar = _G.DoesItDieAdvancedRemaining
    local eui = _G.EllesmereUI
    if SUI:IntegrationEnabled("frames") then InstallPlayerDispelMasks(eui) end
    if SUI:IntegrationEnabled("dida") and not marker and bar and eui and Enum
        and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched then
        marker = BindDamageMarker(bar)
    end
    if marker then
        ScheduleMarker()
        if eui then InstallNameplateDamageMasks(eui) end
    end

    local glows = eui and eui.Glows
    if glows and SUI:IntegrationEnabled("cdmglow") then InstallCDMBuffGlow(eui, glows) end
    if glows and SUI:IntegrationEnabled("glow") and not glowHooks[glows] and type(glows.StartSpecGlow) == "function"
        and type(glows.StopProceduralAnts) == "function" and type(glows.StartShapeGlow) == "function" then
        glowHooks[glows] = true
        hooksecurefunc(glows, "StartSpecGlow", function(...)
            SUI:SafeModuleCall(M, "Ellesmere buff reminder outline", function(_, ...)
                ApplyReminderGlow(glows, ...)
            end, ...)
        end)
        if _G._EABR_RequestRefresh then _G._EABR_RequestRefresh() end
    end
    local mode = self:GetFrameShapeMode()
    local changed = self.reminderShapeMode ~= mode
    self.reminderShapeMode = mode
    if mode == "SQUARE" and next(shownBuffs) and glows and glows.StopGlow then
        for wrapper in pairs(shownBuffs) do glows.StopGlow(wrapper) end
        wipe(shownBuffs)
    end
    if changed and _G._EABR_RequestRefresh then _G._EABR_RequestRefresh() end
end

