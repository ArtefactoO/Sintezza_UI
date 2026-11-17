local _, SUI = ...
local Text = SUI.Text

local M = SUI:RegisterModule("nameplates", {
    title = Text("Неймплейты", "Nameplates"),
    available = false,
    plates = {},
    activeUnits = {},
    pendingUnits = {},
})
SUI.Nameplates = M

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

-- 12.1 may return secret unit-derived values. They cannot be negated,
-- formatted or used as a table key; pcall alone is insufficient unless the
-- returned value is checked before Lua evaluates it.
local function SafePlainCall(func, ...)
    if type(func) ~= "function" then return nil, false end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then return nil, false end
    return value, true
end

local ROUND_MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\rounded\\"
local ringMasks = setmetatable({}, { __mode = "k" })

function M:GetNativePlateRounding(health, namespace)
    local eui = _G.EllesmereUI
    local ns = namespace or (self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace)
    local p = ns and ns.db and ns.db.profile
    if not (p and eui and Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
        and not (ns.NP_Blizz and ns.NP_Blizz())
        and not (ns.GetWrapBorderCastbar and ns.GetWrapBorderCastbar())) then return end
    local shapes = SUI:GetModule("fontCompatibility")
    local radius, corners = shapes:ResolveFrameShape(p.cornerRadius, p.cornerMask, 8, "plates")
    if radius < 1 then return end
    local style = ns.IsCustomBorderEnabled and ns.IsCustomBorderEnabled() and p.customBorderTexture or "solid"
    if eui.RoundedStyleOK and not eui.RoundedStyleOK(style) then return end
    local height = health and SafePlainCall(health.GetHeight, health) or tonumber(p.healthBarHeight)
    local width = health and SafePlainCall(health.GetWidth, health)
    if type(height) == "number" and height > 2 then
        if type(width) == "number" and width > 2 then height = math.min(height, width) end
        radius = math.min(radius, math.max(1, math.floor(height / 2 - .5)))
    end
    return math.min(16, math.floor(radius)), corners
end

local function SetRoundedArt(region, radius, corners, inverse)
    local base = inverse and "rounded-inv-" or "rounded-"
    local mask = corners == 15 and "" or ("-" .. corners)
    local wrap = inverse and "CLAMPTOWHITE" or "CLAMPTOBLACKADDITIVE"
    region:SetTexture(ROUND_MEDIA .. base .. radius .. mask .. ".tga", wrap, wrap)
    region:SetTextureSliceMargins(radius, radius, radius, radius)
    region:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

local function ExpandAround(region, health, pad)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", health, "TOPLEFT", -pad, pad)
    region:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", pad, -pad)
end

-- Texture-only outline: its aura button still owns visibility. The inverse
-- mask cuts the middle out so the health and text remain visible.
function M:PlaceRoundedPlateRing(texture, parent, health, radius, corners, gap, width)
    local state = ringMasks[texture]
    if not state then
        state = { hole = parent:CreateMaskTexture() }
        ringMasks[texture] = state
    end
    if state.health == health and state.radius == radius and state.corners == corners
        and state.gap == gap and state.width == width then return end
    if state.attached then texture:RemoveMaskTexture(state.hole) end
    local outer = gap + width
    SetRoundedArt(texture, math.max(1, math.min(16, math.floor(radius + outer + .5))), corners, false)
    SetRoundedArt(state.hole, math.max(1, math.min(16, math.floor(radius + gap + .5))), corners, true)
    ExpandAround(texture, health, outer)
    ExpandAround(state.hole, health, gap)
    texture:AddMaskTexture(state.hole)
    state.attached = true
    state.health, state.radius, state.corners, state.gap, state.width = health, radius, corners, gap, width
end

function M:ColorPlateEffectTexture(texture, r, g, b, a)
    if ringMasks[texture] then texture:SetVertexColor(r, g, b, a)
    else texture:SetColorTexture(r, g, b, a) end
end

local function UnitExistsPlain(unit)
    local value, readable = SafePlainCall(UnitExists, unit)
    return readable and value == true
end

function M:Profile()
    return SUI:GetModuleProfile("nameplates")
end

function M:IsTapColorPriority(unit)
    local profile = self:Profile()
    if IsSecret(unit) or not unit or not profile or not profile.enabled or profile.respectTapDenied == false then return false end
    local denied = SafePlainCall(UnitIsTapDenied, unit)
    return denied == true
end

local SELECTION_CLIPS = { "targetClipFill", "targetClipBg", "focusClipFill", "focusClipBg", "hoverClipFill", "hoverClipBg" }

local function RestoreSelectionClipAlpha(plate)
    local saved = plate and plate.__suiTargetClipAlpha
    if not saved then return end
    for clip, alpha in pairs(saved) do clip:SetAlpha(alpha) end
    plate.__suiTargetClipAlpha = nil
end

function M:UpdateSelectionClipAlpha(plate)
    if not plate or self.adapterKey ~= "ellesmere" then return end
    local tapped = self:IsTapColorPriority(plate.unit)
    local saved = plate.__suiTargetClipAlpha
    if not tapped then RestoreSelectionClipAlpha(plate); return end
    -- The owner still controls visibility and tint. Only the clip hosts'
    -- alpha changes; the selection glow and the bar's numbers keep drawing.
    for _, key in ipairs(SELECTION_CLIPS) do
        local clip = plate[key]
        local original = clip and saved and saved[clip]
        if clip then
            if original == nil then
                original = SafePlainCall(clip.GetAlpha, clip)
                if type(original) == "number" then
                    saved = saved or {}
                    saved[clip] = original
                end
            end
            if type(original) == "number" then clip:SetAlpha(0) end
        end
    end
    plate.__suiTargetClipAlpha = saved
end

function M:UpdateSelectionVisuals(plate)
    self:UpdateSelectionClipAlpha(plate)
    if plate and plate.health then
        local auraLevel = self.AuraRules and self.AuraRules:TopVisualLevel(plate.health)
        local overlayLevel = (auraLevel or plate.health:GetFrameLevel()) + 1
        for _, key in ipairs({ "targetClipFill", "targetClipBg", "focusClipFill", "focusClipBg" }) do
            local overlay = plate[key]
            if overlay then pcall(overlay.SetFrameLevel, overlay, overlayLevel) end
        end
    end
end

function M:RefreshSelectionVisuals()
    for _, plate in pairs(self.plates or {}) do self:UpdateSelectionVisuals(plate) end
end

function M:RefreshRuntimeFlags()
    local profile = self:Profile()
    -- EUI owns the native health fill. Interpolating that same StatusBar breaks
    -- both its pooled value and the aura-rule texture anchored to its fill.
    if profile then profile.smoothHealth = false end
    self.smoothHealthActive = false
    local rules = profile and profile.enabled and self.AuraRules and self.AuraRules:Profile()
    self.auraRulesOn = rules and rules.enabled == true or false
    self.runtimeWanted = profile and profile.enabled == true and (
        profile.respectTapDenied ~= false or self.auraRulesOn
        or self:GetBuffIconsPerRow() > 0) and true or false
end

function M:RefreshFeatureDemand()
    local before = self.runtimeWanted
    self:RefreshRuntimeFlags()
    if before ~= self.runtimeWanted then self:RefreshAll(true) end
end

function M:Shutdown()
    self:RefreshBuffRows()
    self:StopRetryLoop()
    wipe(self.pendingUnits)
    if not next(self.plates) and not (self.AuraRules and next(self.AuraRules.rigs)) then
        self.pendingShutdown = nil
        wipe(self.activeUnits)
        return
    end
    if InCombatLockdown and InCombatLockdown() then self.pendingShutdown = true; return end
    self.pendingShutdown = nil
    for unit in pairs(self.plates) do self:DetachPlate(unit) end
    wipe(self.activeUnits)
    if self.AuraRules then self.AuraRules:ResetRuntime() end
end

function M:WrapHealthBar(bar)
    -- Compatibility entry point only; intentionally does not replace native
    -- StatusBar methods.
end

function M:BindHealthBarOwner(unit, plate)
    local bar = plate and plate.health
    if not bar then return false end
    self:WrapHealthBar(bar)
    return false
end

function M:FindTargetPlate()
    local unit = "target"
    local direct = self.plates and self.plates[unit]
    if direct and direct.health then return unit, direct end
    for plateUnit, plate in pairs(self.plates or {}) do
        local isTarget, readable = SafePlainCall(UnitIsUnit, plateUnit, unit)
        if readable and isTarget and plate and plate.health then
            return plateUnit, plate
        end
    end
    return nil, nil
end


-- EllesmereUI creates the hover overlay lazily on first mouseover. Keep it one
-- tier above target/focus, which themselves sit above conditional aura paint.
-- Text and borders use their own higher tiers and remain untouched.
function M:UpdateHoverOverlay(plate)
    if not plate or not plate.health then return end
    local fill, background = plate.hoverClipFill, plate.hoverClipBg
    if not fill and not background then return end
    local auraLevel = self.AuraRules and self.AuraRules:TopVisualLevel(plate.health)
    local level = (auraLevel or plate.health:GetFrameLevel()) + 2
    if fill then pcall(fill.SetFrameLevel, fill, level) end
    if background then pcall(background.SetFrameLevel, background, level) end
    if self:IsTapColorPriority(plate.unit) then self:UpdateSelectionClipAlpha(plate) end
end

local function RestoreTapDebuffGate(plate, paint)
    local saved = plate.__suiTapDebuffGate
    plate.__suiTapDebuffGate = nil
    if saved and saved.unit == plate.unit and saved.paint == paint then
        paint(plate, saved.health, saved.border, saved.name)
    end
end

function M:ApplyNativeTapPriority(plate, nativePaint)
    local ns = self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace
    if not ns or not plate then return end
    local paint = ns.DebuffColors_Threat
    if not self:IsTapColorPriority(plate.unit) then
        local repaint = plate.__suiTapThreatRepaint
        plate.__suiTapThreatRepaint = nil
        -- The native health pass has already written the new unit's gates.
        if nativePaint then plate.__suiTapDebuffGate = nil
        else
            RestoreTapDebuffGate(plate, paint)
            if repaint and repaint == plate.unit and self.activeAdapter
                and type(self.activeAdapter.RestoreHealthColor) == "function" then
                self.activeAdapter:RestoreHealthColor(self, plate)
            end
        end
        return
    end
    if type(paint) == "function" then
        local saved = plate.__suiTapDebuffGate
        if nativePaint or not saved or saved.unit ~= plate.unit or saved.paint ~= paint then
            saved = saved or {}
            saved.unit, saved.paint = plate.unit, paint
            saved.health, saved.border, saved.name = plate._dcThreatH, plate._dcThreatB, plate._dcThreatN
            plate.__suiTapDebuffGate = saved
            -- EUI's own API gates the colour layers without changing aura data.
            paint(plate, 0, 0, 0)
        end
    end
    if plate._threatBdOn and type(plate.RepaintThreatBorder) == "function" then
        plate.__suiTapThreatRepaint = plate.unit
        plate._threatBdOn = nil
        plate._threatBdKr, plate._threatBdKg, plate._threatBdKb = nil, nil, nil
        plate:RepaintThreatBorder(plate.unit)
    end
    if plate._threatNameOn and plate.name then
        local profile = ns.db and ns.db.profile
        local color = profile and (profile.enemyNameTappedColor or profile.tapped)
            or ns.defaults and ns.defaults.tapped
        if color then
            plate.__suiTapThreatRepaint = plate.unit
            plate.name:SetTextColor(color.r, color.g, color.b, 1)
            plate._nameThR, plate._nameThG, plate._nameThB = nil, nil, nil
        end
    end
end

function M:AttachPlate(unit, forceRebind, skipAura)
    if not self.runtimeWanted then return false end
    local plate = self.GetAdapterPlate and self:GetAdapterPlate(unit)
    if not plate or not plate.health then return false end
    forceRebind = forceRebind or self.plates[unit] ~= plate
    self.pendingUnits[unit] = nil
    self.plates[unit] = plate
    self:RefreshBlizzardPlateBuffRows(plate)
    self:BindHealthBarOwner(unit, plate)
    if not plate.__suiColorHooked and type(plate.UpdateHealthColor) == "function" then
        plate.__suiColorHooked = true
        hooksecurefunc(plate, "UpdateHealthColor", function(target)
            if not M.runtimeWanted then return end
            M:ApplyNativeTapPriority(target, true)
            local rig = M:EnsureAuraBinding(target)
            if rig then M.AuraRules:RestackRig(rig) end
            M:UpdateSelectionVisuals(target)
            M:UpdateHoverOverlay(target)
        end)
    end
    self:ApplyNativeTapPriority(plate)
    local auraAttached = true
    if self.auraRulesOn and self.AuraRules and not skipAura then
        auraAttached = self.AuraRules:AttachPlate(unit, plate, forceRebind) ~= false
    end
    self:UpdateSelectionVisuals(plate)
    self:UpdateHoverOverlay(plate)
    return auraAttached
end

-- EUI reuses the same pooled plate frame for different nameplate tokens and
-- can also exchange bars around target/focus changes. Health colour refreshes
-- are a cheap event-driven point to verify identity. Rebind only on a real
-- mismatch; the normal hot path is just table comparisons.
function M:EnsureAuraBinding(plate)
    if not self.runtimeWanted or not self.auraRulesOn or not plate or not plate.health or not self.AuraRules then return nil end
    local unit = plate.unit
    if not unit or not UnitExistsPlain(unit) or not self.activeUnits[unit] then
        return self.AuraRules.rigs[plate.health]
    end

    local published = self.GetAdapterPlate and self:GetAdapterPlate(unit)
    if published and published ~= plate then plate = published end
    if not plate or not plate.health then return nil end

    for mappedUnit, mappedPlate in pairs(self.plates) do
        if mappedUnit ~= unit and mappedPlate == plate then
            self.plates[mappedUnit] = nil
            self.AuraRules:DetachPlate(mappedUnit)
        end
    end

    local rig = self.AuraRules.rigs[plate.health]
    if self.plates[unit] ~= plate
        or not rig
        or self.AuraRules.units[unit] ~= rig
        or rig.unit ~= unit
        or rig.tapDenied ~= self:IsTapColorPriority(unit)
        or rig.nativePlate ~= plate.nameplate then
        self.plates[unit] = plate
        self:BindHealthBarOwner(unit, plate)
        if not self.AuraRules:AttachPlate(unit, plate, true) then
            self.pendingUnits[unit] = true
            self:EnsureRetryLoop(true)
        end
        rig = self.AuraRules.rigs[plate.health]
    end
    return rig
end

-- NAME_PLATE_UNIT_ADDED can run before EllesmereUI publishes its plate. Retry
-- briefly, then suspend until another relevant plate/target event. This keeps
-- busy pulls reliable without leaving a permanent ticker after an EUI API break.
function M:QueueAttach(unit)
    if not self.runtimeWanted or not unit then return end
    local newlyPending = not self.pendingUnits[unit]
    self.pendingUnits[unit] = true
    self:EnsureRetryLoop(newlyPending)
    SUI:After(0, self, "nameplate attach", function()
        if M.pendingUnits[unit] and UnitExistsPlain(unit) and not M:AttachPlate(unit, true) then
            M.pendingUnits[unit] = true
        end
    end)
end

function M:DetachPlate(unit)
    local plate = self.plates[unit]
    self.activeUnits[unit] = nil
    self.pendingUnits[unit] = nil
    self.plates[unit] = nil
    RestoreSelectionClipAlpha(plate)
    if plate then
        local ns = self.adapterState and self.adapterState.namespace
        RestoreTapDebuffGate(plate, ns and ns.DebuffColors_Threat)
        plate.__suiTapThreatRepaint = nil
    end
    if self.AuraRules then self.AuraRules:DetachPlate(unit, plate) end
end

function M:RefreshAll(structural)
    self:RefreshRuntimeFlags()
    if not self.runtimeWanted then self:Shutdown(); return end
    self.pendingShutdown = nil
    if not self.available or not self.activeAdapter then self:Reconnect(); return end
    self:ForEachAdapterPlate(function(unit)
        self.activeUnits[unit] = true
        if not self:AttachPlate(unit, false, structural) then self.pendingUnits[unit] = true end
    end)
    if structural then
        if self.AuraRules then self.AuraRules:RebuildAll() end
        self:RefreshBuffRows()
    end
    self:EnsureRetryLoop(structural == true)
end

function M:ResyncSwappedBars()
    if not self.runtimeWanted then return end
    if not self.available or not self.activeAdapter then return end
    local changed = false
    for unit in pairs(self.activeUnits) do
        if not UnitExistsPlain(unit) then
            self:DetachPlate(unit)
        else
            local plate = self.GetAdapterPlate and self:GetAdapterPlate(unit)
            local rig = self.AuraRules and self.AuraRules.units[unit]
            local profile = self.AuraRules and self.AuraRules:Profile()
            local rulesEnabled = profile and profile.enabled
            if not plate or not plate.health then
                self.pendingUnits[unit] = true
            elseif rulesEnabled and (self.plates[unit] ~= plate or not rig or rig.healthBar ~= plate.health) then
                -- Publish every new plate reference before rebinding any aura
                -- container; ReconcilePlates resolves swaps in a second pass.
                self.plates[unit] = plate
                self.pendingUnits[unit] = nil
                self:BindHealthBarOwner(unit, plate)
                changed = true
            elseif not self.plates[unit] then
                self:AttachPlate(unit, true)
            end
        end
    end
    if changed and self.AuraRules then self.AuraRules:ReconcilePlates(true) end
    self:EnsureRetryLoop()
end

function M:RetryPending()
    for unit in pairs(self.pendingUnits) do
        if not self.activeUnits[unit] or not UnitExistsPlain(unit) then
            self.pendingUnits[unit] = nil
        else
            if not self:AttachPlate(unit, true) then self.pendingUnits[unit] = true end
        end
    end
    if not self:HasPendingUnits() then self:StopRetryLoop() end
end

function M:HasPendingUnits()
    return next(self.pendingUnits) ~= nil
end

function M:StopRetryLoop(suspended)
    if self.retryTicker then self.retryTicker:Cancel(); self.retryTicker = nil end
    self.retrySuspended = suspended == true
    if not suspended then self.retryStartedAt = nil end
end

function M:EnsureRetryLoop(force)
    if not self.runtimeWanted then self:StopRetryLoop(); return end
    if not self:HasPendingUnits() then self:StopRetryLoop(); return end
    if force then self.retrySuspended = nil; self.retryStartedAt = nil end
    if self.retrySuspended then return end
    if self.retryTicker then return end
    self.retryStartedAt = self.retryStartedAt or (GetTime and GetTime() or 0)
    self.retryTicker = C_Timer.NewTicker(.5, function()
        local ok = SUI:SafeModuleCall(M, "nameplate retry", function()
            M:RetryPending()
            if not M:HasPendingUnits() then return end
            local now = GetTime and GetTime() or 0
            if now - (M.retryStartedAt or now) >= 12 then
                M:StopRetryLoop(true)
                return
            end
            M:ResyncSwappedBars()
        end)
        if not ok then M:StopRetryLoop(true) end
    end)
end

function M:PrintStatus()
    local active, attached, pending, rigs, missing, mismatched = 0, 0, 0, 0, 0, 0
    for _ in pairs(self.activeUnits) do active = active + 1 end
    for _ in pairs(self.plates) do attached = attached + 1 end
    for _ in pairs(self.pendingUnits) do pending = pending + 1 end
    if self.AuraRules then for _ in pairs(self.AuraRules.rigs) do rigs = rigs + 1 end end
    if self.AuraRules then
        for unit in pairs(self.activeUnits) do
            local plate = self.plates[unit]
            local rig = plate and plate.health and self.AuraRules.rigs[plate.health]
            if not rig then missing = missing + 1
            elseif rig.unit ~= unit or self.AuraRules.units[unit] ~= rig then mismatched = mismatched + 1 end
        end
    end
    SUI:Print(Text("Адаптер неймплейтов: %s (%s)", "Nameplate adapter: %s (%s)"):format(
        self.adapterName or Text("нет", "none"), self.adapterKey or "—"))
    SUI:Print(Text("Неймплейты: активных %d, подключено %d, ожидает %d. Оформление аур: %d, отсутствует %d, расхождений %d",
        "Nameplates: active %d, attached %d, pending %d. Aura overlays: %d, missing %d, mismatched %d"):format(
        active, attached, pending, rigs, missing, mismatched))
    if self.AuraRules and self.AuraRules.GetDiagnostics then
        local data = self.AuraRules:GetDiagnostics()
        local mode = data.slotApiPresent == true and Text("слоты аур", "aura slots")
            or (data.slotApiPresent == false and Text("группы аур", "aura groups") or Text("нет данных", "unknown"))
        SUI:Print(Text("Ауры: %s, правил %d, контейнеров %d (слоты %d / группы %d), текстур %d, сбоев %d",
            "Auras: %s, rules %d, containers %d (slots %d / groups %d), textures %d, failures %d"):format(
            mode, data.rules, data.containers, data.slots, data.groups, data.visuals, data.failures))
        SUI:Print(Text("Слои аур: попыток создания %d, ошибок %d%s", "Aura overlays: build attempts %d, failures %d%s"):format(
            data.buildAttempts, data.buildFailures,
            data.lastBuildError and (" • " .. data.lastBuildError) or ""))
        SUI:Print(Text("Восстановление слоев: выполнено %d, подозрительных %d, блокировок %d, лимит %d",
            "Overlay repairs: completed %d, suspect %d, blocked %d, limit %d"):format(
            data.rigRepairs, data.suspectRigs, data.combatBlocked, data.repairCap))
        if data.rigs > 0 then
            local function Project(value) return math.floor(((value or 0) / data.rigs) * 40 + .5) end
            SUI:Print(Text("Оценка на 40 неймплейтов: контейнеров %d, текстур %d",
                "Estimate for 40 nameplates: containers %d, textures %d"):format(
                Project(data.containers), Project(data.visuals)))
        end
    end
    if self.AuraCatalog and self.AuraCatalog.GetLearnedCounts then
        local total, available = self.AuraCatalog:GetLearnedCounts()
        SUI:Print(Text("Ранее запомненные дебаффы: %d для этого класса, %d всего",
            "Previously remembered debuffs: %d for this class, %d total"):format(available, total))
    end
    if UnitExistsPlain("target") then
        local nativePlate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit("target")
        local activePlate
        for unit, plate in pairs(self.plates) do
            local same, readable = SafePlainCall(UnitIsUnit, unit, "target")
            if readable and same then activePlate = plate break end
        end
        local health = activePlate and activePlate.health
        local rig = health and self.AuraRules and self.AuraRules.rigs[health]
        local shown, total = 0, 0
        for _, record in ipairs(rig and rig.rules or {}) do
            for _, visual in ipairs(record.visuals or {}) do
                local texture = visual.texture
                if texture then
                    total = total + 1
                    local visible, readable = SafePlainCall(texture.IsShown, texture)
                    if readable and visible == true then shown = shown + 1 end
                end
            end
        end
        local healthLevel = health and SafePlainCall(health.GetFrameLevel, health) or nil
        local topLevel = health and self.AuraRules and self.AuraRules:TopVisualLevel(health) or nil
        SUI:Print(Text("Цель: неймплейт %s, полоса здоровья %s, слой аур %s",
            "Target: nameplate %s, health bar %s, aura overlay %s"):format(
            tostring(nativePlate), tostring(health), tostring(rig)))
        SUI:Print(Text("Слои цели: здоровье %s, верхний слой SUI %s, видимых текстур %d/%d, создан в бою %s, восстановлений %s",
            "Target layers: health %s, top SUI layer %s, visible textures %d/%d, built in combat %s, repairs %s"):format(
            tostring(healthLevel), tostring(topLevel), shown, total,
            tostring(rig and rig.builtInCombat == true), tostring(rig and rig.repairs or 0)))
    end
end

function M:RegisterEvents()
    if self.eventsRegistered then return end
    self.eventsRegistered = true
    SUI:RegisterModuleEvent(self, "NAME_PLATE_UNIT_ADDED")
    SUI:RegisterModuleEvent(self, "NAME_PLATE_UNIT_REMOVED")
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
    SUI:RegisterModuleEvent(self, "ZONE_CHANGED_NEW_AREA")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    SUI:RegisterModuleEvent(self, "PLAYER_TARGET_CHANGED")
    SUI:RegisterModuleEvent(self, "PLAYER_FOCUS_CHANGED")
    SUI:RegisterModuleEvent(self, "UNIT_FLAGS")
    SUI:RegisterModuleEvent(self, "UNIT_AURA")
    SUI:RegisterModuleEvent(self, "SPELLS_CHANGED")
    SUI:RegisterModuleEvent(self, "PLAYER_SPECIALIZATION_CHANGED")
    SUI:RegisterModuleEvent(self, "TRAIT_CONFIG_UPDATED")
    if SUI.isForever then SUI:RegisterModuleEvent(self, "CHARACTER_POINTS_CHANGED") end
end

function M:Reconnect()
    if not self.runtimeWanted then return false end
    if not self.ConnectNameplateAdapter then
        self.available = false
        return false
    end
    local connected, _, hooksOK = self:ConnectNameplateAdapter()
    if not connected then return false end
    if self.AuraRules then self.AuraRules:Initialize() end
    SUI:After(0, self, "nameplate adapter reconnect refresh", function() M:RefreshAll(true) end)
    return hooksOK
end

function M:Initialize()
    self:RefreshRuntimeFlags()
    self:RegisterEvents()
    if self.runtimeWanted then
        self:Reconnect()
    end
end

function M:OnProfileChanged()
    self:RefreshAll(true)
    if SUI.initialized then SUI:RefreshModuleEvents() end
end

function M:OnEvent(event, unit)
    if event == "PLAYER_REGEN_ENABLED" and self.pendingBuffRows then self:RefreshBuffRows() end
    if not self.runtimeWanted then
        if event == "PLAYER_REGEN_ENABLED" then self:Shutdown() end
        return
    end
    if not self.available and (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA") then
        self:Reconnect()
    end
    if event == "NAME_PLATE_UNIT_ADDED" then
        self.activeUnits[unit] = true
        if not self:AttachPlate(unit, true) then self:QueueAttach(unit) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then self:DetachPlate(unit)
    elseif event == "UNIT_AURA" then
        if self.AuraRules:SupportsTextColoring() and not IsSecret(unit) and type(unit) == "string" then
            self.AuraRules:QueueTextAuraRefresh(unit)
        end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        self:ResyncSwappedBars()
        if self.AuraRules then self.AuraRules:RefreshAll(false) end
        for _, plate in pairs(self.plates) do
            self:UpdateSelectionVisuals(plate)
            self:UpdateHoverOverlay(plate)
        end
        self:EnsureRetryLoop(true)
        -- EUI's target overlay/bar exchange can finish later in the same
        -- event dispatch.  One next-frame reconciliation observes the final
        -- ownership map without polling or a permanent OnUpdate.
        SUI:After(0, self, "target ownership refresh", function()
            M:ResyncSwappedBars()
            if M.AuraRules then M.AuraRules:RefreshAll(false) end
            M:RefreshSelectionVisuals()
        end)
    elseif event == "UNIT_FLAGS" then
        -- Tap ownership can change while the plate is already visible. Rebind
        -- aura containers immediately so EUI's grey tapped colour is revealed.
        if unit and self.activeUnits[unit] then self:AttachPlate(unit, true) end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
        or event == "CHARACTER_POINTS_CHANGED" then
        self:RefreshFeatureDemand()
        if self.AuraCatalog then self.AuraCatalog:Invalidate() end
        if self.AuraRules then self.AuraRules:RebuildAll() end
        SUI:RefreshModuleEvents()
        if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.AuraRules then
            if self.AuraRules.pendingRebuild then self.AuraRules:RebuildAll() end
            if self.AuraRules.RecoverAfterCombat then self.AuraRules:RecoverAfterCombat() end
        end
        self:RetryPending()
        self:ResyncSwappedBars()
    else self:RefreshAll(false) end
end
