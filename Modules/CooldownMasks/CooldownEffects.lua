local _, SUI = ...
local M = SUI.CooldownMasks

local E = {
    records = setmetatable({}, { __mode = "k" }),
    iconsByCooldownID = {},
    procHooksInstalled = false,
}
M.Effects = E

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function RootProfile()
    local profile = M:Profile()
    return profile or {}
end

local function ModuleNamespace()
    return EllesmereUI and EllesmereUI._ModuleNS
        and EllesmereUI._ModuleNS.EllesmereUICooldownManager
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function CDMSettingsOpen()
    return CooldownViewerSettings and CooldownViewerSettings:IsShown()
end

function E:ClassSpecKey()
    return SUI:GetClassSpecScope()
end

function E:BuffEnabled() return RootProfile().enabled == true and self:BuffRoot().enabled ~= false end
function E:ProcEnabled() return RootProfile().enabled == true and self:ProcProfile().enabled == true end
function E:IsActive() return ModuleNamespace() ~= nil and (self:BuffEnabled() or self:ProcEnabled()) end

function E:ScopeLabel()
    local _, classToken, _, specName = self:ClassSpecKey()
    local className = classToken
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken] then
        className = LOCALIZED_CLASS_NAMES_MALE[classToken]
    elseif LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken] then
        className = LOCALIZED_CLASS_NAMES_FEMALE[classToken]
    end
    return tostring(className or classToken) .. " • " .. tostring(specName)
end

function E:BuffRoot()
    local profile = RootProfile()
    profile.buffEffects = type(profile.buffEffects) == "table" and profile.buffEffects or {}
    if profile.buffEffects.enabled == nil then profile.buffEffects.enabled = true end
    profile.buffEffects.speed = tonumber(profile.buffEffects.speed) or .80
    profile.buffEffects.intensity = tonumber(profile.buffEffects.intensity) or .70
    profile.buffEffects.scopes = type(profile.buffEffects.scopes) == "table" and profile.buffEffects.scopes or {}
    return profile.buffEffects
end

function E:BuffScope()
    local root = self:BuffRoot()
    local key, classToken, specID, specName = self:ClassSpecKey()
    local scope = root.scopes[key]
    if type(scope) ~= "table" then
        scope = { rules = {} }
        root.scopes[key] = scope
    end
    scope.rules = type(scope.rules) == "table" and scope.rules or {}
    scope.classToken, scope.specID, scope.specName = classToken, specID, specName
    return scope
end

function E:ProcProfile()
    local profile = RootProfile()
    profile.procEffects = type(profile.procEffects) == "table" and profile.procEffects or {}
    local proc = profile.procEffects
    if proc.enabled == nil then proc.enabled = false end
    proc.mode = proc.mode or "BOTH"
    proc.color = type(proc.color) == "table" and proc.color or { 1, .72, .18, .72 }
    proc.speed = tonumber(proc.speed) or .80
    proc.intensity = tonumber(proc.intensity) or .72
    proc.scale = tonumber(proc.scale) or 1.10
    return proc
end

local function CopyColor(value)
    value = type(value) == "table" and value or {}
    return {
        value.r or value[1] or .10,
        value.g or value[2] or 1,
        value.b or value[3] or .72,
        value.a or value[4] or .58,
    }
end

local function LevelDefaults(level)
    level = type(level) == "table" and level or {}
    level.threshold = math.max(2, math.min(20, tonumber(level.threshold) or 2))
    if level.mode ~= "PULSE" and level.mode ~= "BORDER" and level.mode ~= "BOTH" then level.mode = "BOTH" end
    level.color = CopyColor(level.color)
    level.sound = level.sound == true
    return level
end

local function SortUniqueLevels(levels)
    local originalOrder = {}
    for index, level in ipairs(levels) do originalOrder[level] = index end
    table.sort(levels, function(a, b)
        if a.threshold == b.threshold then return originalOrder[a] < originalOrder[b] end
        return a.threshold < b.threshold
    end)

    local used = {}
    for _, level in ipairs(levels) do
        local threshold = level.threshold
        if used[threshold] then
            local candidate = threshold + 1
            while candidate <= 20 and used[candidate] do candidate = candidate + 1 end
            if candidate > 20 then
                candidate = threshold - 1
                while candidate >= 2 and used[candidate] do candidate = candidate - 1 end
            end
            threshold = math.max(2, math.min(20, candidate))
            level.threshold = threshold
        end
        used[threshold] = true
    end
    table.sort(levels, function(a, b) return a.threshold < b.threshold end)
end

local function RuleDefaults(rule)
    rule.enabled = rule.enabled ~= false
    if type(rule.levels) ~= "table" or #rule.levels == 0 then
        rule.levels = { LevelDefaults({
            threshold = rule.threshold,
            mode = rule.mode,
            color = rule.color,
        }) }
    end
    for index = #rule.levels, 1, -1 do
        if type(rule.levels[index]) ~= "table" then table.remove(rule.levels, index)
        else LevelDefaults(rule.levels[index]) end
    end
    if #rule.levels == 0 then rule.levels[1] = LevelDefaults({}) end
    while #rule.levels > 4 do table.remove(rule.levels) end
    SortUniqueLevels(rule.levels)
    rule.onlyCombat = rule.onlyCombat == true
    rule.onlyGroup = rule.onlyGroup == true
    rule.threshold, rule.mode, rule.color = nil, nil, nil
    return rule
end

function E:NormalizeRule(rule) return rule and RuleDefaults(rule) end

function E:AddRuleLevel(rule)
    if not rule then return end
    RuleDefaults(rule)
    if #rule.levels >= 4 then return false end
    local previous = rule.levels[#rule.levels]
    rule.levels[#rule.levels + 1] = LevelDefaults({
        threshold = math.min(20, (previous and previous.threshold or 1) + 1),
        mode = previous and previous.mode or "BOTH",
        color = previous and previous.color or nil,
    })
    RuleDefaults(rule)
    return true
end

function E:RemoveRuleLevel(rule, index)
    if not rule then return end
    RuleDefaults(rule)
    if #rule.levels <= 1 then return false end
    table.remove(rule.levels, index)
    RuleDefaults(rule)
    return true
end

function E:ConditionsAllow(rule)
    if not rule then return false end
    if rule.onlyCombat and not UnitAffectingCombat("player") then return false end
    if rule.onlyGroup and not IsInGroup() then return false end
    return true
end

function E:GetRule(cooldownID, create, metadata)
    cooldownID = tonumber(cooldownID)
    if not cooldownID then return nil end
    local rules = self:BuffScope().rules
    local key = tostring(cooldownID)
    local rule = rules[key]
    if not rule and create then
        rule = RuleDefaults({ cooldownID = cooldownID })
        rules[key] = rule
    elseif rule then
        RuleDefaults(rule)
    end
    if rule and metadata then
        rule.cooldownID = cooldownID
        rule.spellID = tonumber(metadata.spellID) or rule.spellID
        rule.name = metadata.name or rule.name
        rule.icon = metadata.icon or rule.icon
    end
    return rule
end

function E:SetRuleEnabled(entry, enabled)
    local rule = self:GetRule(entry.cdID or entry.cooldownID, enabled, entry)
    if rule then rule.enabled = enabled == true end
    self:RefreshAll()
end

function E:GetTrackedBuffs()
    local ns = ModuleNamespace()
    local tracked = {}
    if ns and type(ns.EnumerateCDMViewerSpells) == "function" then
        local ok, result = pcall(ns.EnumerateCDMViewerSpells, true)
        if ok and type(result) == "table" then
            for _, entry in ipairs(result) do
                local spellID = tonumber(entry.sid)
                tracked[#tracked + 1] = {
                    cdID = entry.cdID,
                    spellID = spellID,
                    name = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID),
                    icon = spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID),
                }
            end
        end
    elseif ns and type(ns.GetAllCDMBuffSpells) == "function" then
        local ok, shown, other = pcall(ns.GetAllCDMBuffSpells)
        if ok then
            for _, list in ipairs({ shown, other }) do
                for _, entry in ipairs(type(list) == "table" and list or {}) do tracked[#tracked + 1] = entry end
            end
        end
    end
    local byID, entries = {}, {}
    for _, entry in ipairs(tracked) do
        local cdID = tonumber(entry.cdID)
        if cdID and not byID[cdID] then
            entry.cooldownID = cdID
            entry.name = entry.name or (entry.spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entry.spellID))
                or ("Cooldown " .. cdID)
            entry.icon = entry.icon or (entry.spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(entry.spellID))
                or 134400
            entry.tracked = true
            byID[cdID] = entry
            entries[#entries + 1] = entry
            self:GetRule(cdID, false, entry)
        end
    end
    for key, rule in pairs(self:BuffScope().rules) do
        local cdID = tonumber(rule.cooldownID) or tonumber(key)
        if cdID and not byID[cdID] then
            entries[#entries + 1] = {
                cdID = cdID, cooldownID = cdID, spellID = rule.spellID,
                name = rule.name or ("Cooldown " .. cdID), icon = rule.icon or 134400,
                tracked = false,
            }
        end
    end
    table.sort(entries, function(a, b)
        if a.tracked ~= b.tracked then return a.tracked end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return entries
end

local function ReadApplications(icon)
    local data = icon and icon.auraDataCached
    if data then
        local applications = data.applications
        -- In 12.1 the stack count becomes a secret number in combat. Do not
        -- branch on it or compare it with nil: pass it only to an explicitly
        -- restricted-safe native consumer such as StatusBar:SetValue.
        if IsSecret(applications) then return applications end
        if applications ~= nil then return applications end
    end
    local instanceID = icon and icon.auraInstanceID
    local unit = icon and icon.auraDataUnit
    if not IsSecret(instanceID) and instanceID and unit
        and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, instanceID)
        if ok and aura then
            local applications = aura.applications
            if IsSecret(applications) then return applications end
            if applications ~= nil then return applications end
        end
    end
    return 0
end

local function Parts(color, defaultAlpha)
    color = color or {}
    return color.r or color[1] or 1, color.g or color[2] or 1,
        color.b or color[3] or 1, color.a or color[4] or defaultAlpha or 1
end

local function ConfigurePulse(root, speed, intensity, play)
    speed = math.max(.20, math.min(2.5, tonumber(speed) or .80))
    intensity = math.max(.10, math.min(1, tonumber(intensity) or .70))
    if not root._pulse then
        local group = root:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        local fade = group:CreateAnimation("Alpha")
        fade:SetOrder(1)
        fade:SetSmoothing("IN_OUT")
        local rise = group:CreateAnimation("Alpha")
        rise:SetOrder(2)
        rise:SetSmoothing("IN_OUT")
        root._pulse = { group = group, fade = fade, rise = rise }
    end
    local pulse = root._pulse
    pulse.fade:SetDuration(speed * .5)
    pulse.rise:SetDuration(speed * .5)
    pulse.fade:SetFromAlpha(1)
    pulse.fade:SetToAlpha(math.max(.08, 1 - (intensity * .90)))
    pulse.rise:SetFromAlpha(math.max(.08, 1 - (intensity * .90)))
    pulse.rise:SetToAlpha(1)
    if play == false then
        pulse.group:Stop()
        root:SetAlpha(1)
    elseif not pulse.group:IsPlaying() then
        pulse.group:Play()
    end
end

local function StopPulse(root)
    if root and root._pulse then root._pulse.group:Stop() end
    if root then root:SetAlpha(1) end
end

local function ResolveShape(icon, ns)
    local data = ns and ns._ecmeFC and ns._ecmeFC[icon]
    local shape = data and data.shapeApplied and data.shapeName or nil
    if shape == "none" or shape == "cropped" then shape = nil end
    local maskPath = shape and ns.CDM_SHAPE_MASKS and ns.CDM_SHAPE_MASKS[shape]
    local borderPath = shape and ns.CDM_SHAPE_BORDERS and ns.CDM_SHAPE_BORDERS[shape]
    return shape, maskPath, borderPath, data and data.shapeMask, data
end

local function ApplyMask(texture, record, maskPath)
    record.appliedMasks = record.appliedMasks or setmetatable({}, { __mode = "k" })
    record.ownMasks = record.ownMasks or setmetatable({}, { __mode = "k" })
    local previous = record.appliedMasks[texture]
    local mask
    if maskPath and texture.GetParent then
        mask = record.ownMasks[texture]
        if not mask then
            local parent = texture:GetParent()
            if parent and parent.CreateMaskTexture then
                mask = parent:CreateMaskTexture()
                mask:SetAllPoints(parent)
                record.ownMasks[texture] = mask
            end
        end
        if mask then mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
    end
    if previous and previous ~= mask and texture.RemoveMaskTexture then
        pcall(texture.RemoveMaskTexture, texture, previous)
    end
    if mask and previous ~= mask and texture.AddMaskTexture then
        pcall(texture.AddMaskTexture, texture, mask)
    end
    record.appliedMasks[texture] = mask
end

local function SuppressEUIBuffGlows(record)
    local ns, icon = record and record.ns, record and record.icon
    local data = ns and ns._hookFrameData and ns._hookFrameData[icon]
    if not data or type(ns.StopNativeGlow) ~= "function" then return end
    local function Stop(overlay)
        if overlay and overlay._glowActive then pcall(ns.StopNativeGlow, overlay) end
    end
    Stop(data.buffGlowOverlay)
    Stop(data.maxStacksGlowOverlay)
    record.euiBuffGlowsSuppressed = true
end

local function ReleaseEUIBuffGlows(record)
    if not record or not record.euiBuffGlowsSuppressed then return end
    record.euiBuffGlowsSuppressed = nil
    local ns, icon = record.ns, record.icon
    local data = ns and ns._hookFrameData and ns._hookFrameData[icon]
    if not data then return end
    -- The next native EUI buff/charge pass will rebuild the appropriate glow.
    -- Clear only its state memo; never guess the user's EUI style or colour.
    if data.buffGlowActive then data.buffGlowActive = false end
    if data._maxStacksGlowOn then data._maxStacksGlowOn = false end
end

local function CreateStackLayer(record, index)
    local icon = record.icon
    if not record.stack then
        local stackRoot = CreateFrame("Frame", nil, icon)
        stackRoot:SetAllPoints(icon)
        stackRoot:SetFrameLevel(icon:GetFrameLevel())
        stackRoot:EnableMouse(false)
        record.stack = { root = stackRoot, layers = {} }
    end
    local stack = record.stack
    if stack.layers[index] then return stack.layers[index] end

    local root = CreateFrame("Frame", nil, stack.root)
    root:SetAllPoints(stack.root)
    root:SetFrameLevel(icon:GetFrameLevel() + index)
    root:EnableMouse(false)

    local fill = CreateFrame("StatusBar", nil, root)
    fill:SetAllPoints(root)
    fill:SetFrameLevel(root:GetFrameLevel())
    fill:SetStatusBarTexture(WHITE)
    local fillTexture = fill:GetStatusBarTexture()
    fillTexture:SetBlendMode("ADD")
    fillTexture:SetDrawLayer("ARTWORK", 6)

    local border = CreateFrame("StatusBar", nil, root)
    border:SetAllPoints(root)
    border:SetFrameLevel(root:GetFrameLevel())
    border:SetStatusBarTexture(WHITE)
    local borderTexture = border:GetStatusBarTexture()
    borderTexture:SetBlendMode("ADD")
    borderTexture:SetDrawLayer("ARTWORK", 7)

    local layer = {
        root = root, fill = fill, border = border,
        fillTexture = fillTexture, borderTexture = borderTexture,
    }
    stack.layers[index] = layer
    return layer
end

local function ConfigureStackLayers(record, ns, rule)
    RuleDefaults(rule)
    SuppressEUIBuffGlows(record)
    local stack = record.stack
    if not stack then CreateStackLayer(record, 1); stack = record.stack end
    local allowed = record.previewLevel ~= nil or E:ConditionsAllow(rule)
    stack.root:SetShown(allowed)
    if not allowed then
        for _, layer in ipairs(stack.layers) do StopPulse(layer.root); layer.root:Hide() end
        return
    end

    local _, maskPath, borderPath, _, shapeData = ResolveShape(record.icon, ns)
    local euiBorderLevel = shapeData and shapeData.shapeBorderFrame
        and shapeData.shapeBorderFrame.GetFrameLevel
        and shapeData.shapeBorderFrame:GetFrameLevel()
    local root = E:BuffRoot()
    for index, level in ipairs(rule.levels) do
        local layer = CreateStackLayer(record, index)
        local threshold = level.threshold or 2
        local r, g, b, a = Parts(level.color, .58)
        layer.root:SetFrameLevel(record.icon:GetFrameLevel() + index)
        layer.fill:SetFrameLevel(layer.root:GetFrameLevel())
        -- EUI's custom-shape border sits at icon + 2. Keep the tint below it,
        -- but place only our transparent ring above it so BOTH/BORDER remains
        -- visible without covering the stack counter or the icon artwork.
        layer.border:SetFrameLevel(math.max(
            layer.root:GetFrameLevel(),
            (euiBorderLevel or record.icon:GetFrameLevel()) + index
        ))
        layer.fill:SetMinMaxValues(threshold - 1, threshold)
        layer.border:SetMinMaxValues(threshold - 1, threshold)
        layer.fill:SetStatusBarColor(r, g, b, a)
        layer.border:SetStatusBarColor(r, g, b, math.min(1, a + .18))
        layer.fill:SetStatusBarTexture(WHITE)
        layer.fillTexture = layer.fill:GetStatusBarTexture()
        layer.fillTexture:SetBlendMode("ADD")
        layer.fillTexture:SetDrawLayer("ARTWORK", 6)
        ApplyMask(layer.fillTexture, record, maskPath)
        if borderPath then
            layer.border:SetStatusBarTexture(borderPath)
            layer.borderTexture = layer.border:GetStatusBarTexture()
            layer.borderTexture:SetBlendMode("ADD")
            layer.borderTexture:SetDrawLayer("ARTWORK", 7)
        else
            layer.border:SetStatusBarTexture(WHITE)
            layer.borderTexture = layer.border:GetStatusBarTexture()
        end
        local mode = level.mode or "BOTH"
        layer.fill:SetShown(mode == "PULSE" or mode == "BOTH")
        layer.border:SetShown(borderPath ~= nil and (mode == "BORDER" or mode == "BOTH"))
        layer.root:Show()
        ConfigurePulse(layer.root, root.speed, root.intensity, mode ~= "BORDER")
    end
    for index = #rule.levels + 1, #stack.layers do
        StopPulse(stack.layers[index].root)
        stack.layers[index].root:Hide()
    end
end

local function CreateProcLayer(record)
    local icon = record.icon
    local root = CreateFrame("Frame", nil, icon)
    root:SetAllPoints(icon)
    root:SetFrameLevel(icon:GetFrameLevel())
    root:EnableMouse(false)
    root:Hide()

    local fill = root:CreateTexture(nil, "ARTWORK", nil, 6)
    fill:SetAllPoints(icon)
    fill:SetTexture(WHITE)
    -- BLEND preserves the configured hue over blue/purple spell art. ADD
    -- mixed both colours and made gold look class-coloured pink/cyan.
    fill:SetBlendMode("BLEND")
    local border = root:CreateTexture(nil, "ARTWORK", nil, 7)
    border:SetBlendMode("ADD")
    record.proc = { root = root, fill = fill, border = border }
    return record.proc
end

local function ConfigureProcLayer(record, ns, profile, play)
    local proc = record.proc or CreateProcLayer(record)
    local _, maskPath, borderPath = ResolveShape(record.icon, ns)
    local r, g, b, a = Parts(profile.color, .72)
    proc.fill:SetTexture(WHITE)
    proc.fill:SetVertexColor(r, g, b, a * .45)
    ApplyMask(proc.fill, record, maskPath)
    local size = math.min(record.icon:GetWidth() or 36, record.icon:GetHeight() or 36)
    local extend = math.max(0, size * ((profile.scale or 1.10) - 1) * .5)
    proc.border:ClearAllPoints()
    proc.border:SetPoint("TOPLEFT", record.icon, "TOPLEFT", -extend, extend)
    proc.border:SetPoint("BOTTOMRIGHT", record.icon, "BOTTOMRIGHT", extend, -extend)
    if borderPath then proc.border:SetTexture(borderPath) else proc.border:SetTexture(nil) end
    proc.border:SetVertexColor(r, g, b, math.min(1, a + .20))
    local mode = profile.mode or "BOTH"
    proc.fill:SetShown(mode == "PULSE" or mode == "BOTH")
    proc.border:SetShown(borderPath ~= nil and (mode == "BORDER" or mode == "BOTH"))
    ConfigurePulse(proc.root, profile.speed, profile.intensity,
        play == true and (mode == "PULSE" or mode == "BOTH"))
end

function E:FeedStack(record)
    local stack = record and record.stack
    if not stack or not stack.root:IsShown() then return end
    if record.previewLevel then
        for index, layer in ipairs(stack.layers) do
            local level = record.rule and record.rule.levels and record.rule.levels[index]
            local value = index == record.previewLevel and level and level.threshold or 0
            layer.fill:SetValue(value)
            layer.border:SetValue(value)
        end
        return
    end
    local applications = ReadApplications(record.icon)
    self:FeedStackValue(record, applications, true)
end

local function ThresholdSound()
    return SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK or SOUNDKIT.ALARM_CLOCK_WARNING_3)
end

function E:PlayReadableThresholdSounds(record, value)
    local previous = record.lastReadableApplications
    record.lastReadableApplications = value
    if previous == nil or value <= previous or not record.rule then return end
    for _, level in ipairs(record.rule.levels or {}) do
        if level.sound and previous < level.threshold and value >= level.threshold then
            local sound = ThresholdSound()
            if sound then PlaySound(sound, "Master") end
        end
    end
end

function E:FeedStackValue(record, applications, suppressSound)
    SuppressEUIBuffGlows(record)
    local stack = record and record.stack
    if not stack or not stack.root:IsShown() then return false end

    -- A cached aura count can be a secret NUMBER in restricted combat. It
    -- cannot be inspected in Lua, but StatusBar:SetValue is an allowed native
    -- consumer. Keep the call protected as clients/addons may expose another
    -- secret type here.
    if IsSecret(applications) then
        local success = false
        for _, layer in ipairs(stack.layers) do
            local okFill = pcall(layer.fill.SetValue, layer.fill, applications)
            local okBorder = pcall(layer.border.SetValue, layer.border, applications)
            success = success or okFill or okBorder
        end
        return success
    end

    if applications == nil then return false end
    local value = tonumber(applications)
    if value == nil then
        -- Blizzard clears the Applications text below two stacks.
        value = 0
    end
    if suppressSound then record.lastReadableApplications = value
    else self:PlayReadableThresholdSounds(record, value) end
    for _, layer in ipairs(stack.layers) do
        layer.fill:SetValue(value)
        layer.border:SetValue(value)
    end
    return true
end

function E:ScheduleStackRefresh()
    if self.stackRefreshPending then return end
    self.stackRefreshPending = true

    -- UNIT_AURA may reach Sintezza_UI before Blizzard refreshes the cooldown
    -- viewer's auraDataCached table.  Re-read after the current event batch and
    -- once more after EllesmereUI's 0.1 s buff pass; no permanent ticker needed.
    SUI:After(0, M, "stack refresh", function()
        if E then E:UpdateStacks() end
    end)
    SUI:After(.12, M, "stack refresh delayed", function()
        E.stackRefreshPending = nil
        E:UpdateStacks()
    end)
end

local function VisibleCDMIcons(ns)
    local result = {}
    for _, icons in pairs((ns and ns.cdmBarIcons) or {}) do
        for _, icon in ipairs(icons) do
            if icon and not M:IsBlizzardCooldownViewerFrame(icon)
                and icon.cooldownID and icon.IsShown and icon:IsShown() then
                result[#result + 1] = icon
            end
        end
    end
    return result
end

function E:BindIcon(icon, ns)
    if M:IsBlizzardCooldownViewerFrame(icon) then return end
    local identity = icon and icon.cooldownID
    if IsSecret(identity) then return end
    local cooldownID = tonumber(identity)
    if not cooldownID then return end
    local record = self.records[icon]
    if not record then
        record = { icon = icon }
        self.records[icon] = record
    end
    record.seen = true
    record.cooldownID = cooldownID
    record.ns = ns
    self.iconsByCooldownID[cooldownID] = icon

    local buffRoot = self:BuffRoot()
    local rule = self:GetRule(cooldownID, false)
    record.rule = rule
    local moduleEnabled = RootProfile().enabled ~= false
    if moduleEnabled and buffRoot.enabled ~= false and rule and rule.enabled ~= false then
        ConfigureStackLayers(record, ns, rule)
        self:FeedStack(record)
    elseif record.stack then
        ReleaseEUIBuffGlows(record)
        record.stack.root:Hide()
    else
        ReleaseEUIBuffGlows(record)
    end

    local procProfile = self:ProcProfile()
    if moduleEnabled and procProfile.enabled then
        ConfigureProcLayer(record, ns, procProfile, record.procActive == true)
    elseif record.proc and not record.procActive then
        StopPulse(record.proc.root)
        record.proc.root:Hide()
    end
end

function E:Scan()
    if CDMSettingsOpen() then return end
    wipe(self.iconsByCooldownID)
    for _, record in pairs(self.records) do record.seen = nil end
    local ns = ModuleNamespace()
    if ns then
        for _, icon in ipairs(VisibleCDMIcons(ns)) do self:BindIcon(icon, ns) end
    end
    for _, record in pairs(self.records) do
        if not record.seen then
            if record.stack then record.stack.root:Hide() end
            if record.proc then record.proc.root:Hide() end
        end
    end
end

function E:UpdateStacks()
    if not self:BuffEnabled() then return end
    for _, record in pairs(self.records) do
        if record.seen and record.rule and record.rule.enabled ~= false then self:FeedStack(record) end
    end
end

local function SuppressEUIProc(record)
    local ns, icon = record.ns, record.icon
    local data = ns and ns._hookFrameData and ns._hookFrameData[icon]
    local overlay = (data and data.glowOverlay) or icon._glowOverlay
    if overlay and overlay._glowActive and type(ns.StopNativeGlow) == "function" then
        pcall(ns.StopNativeGlow, overlay)
        record.euiProcSuppressed = true
    end
end

local function ReleaseEUIProc(record)
    if not record or not record.euiProcSuppressed then return end
    record.euiProcSuppressed = nil
    local ns, icon = record.ns, record.icon
    if not ns or M:IsBlizzardCooldownViewerFrame(icon) then return end
    local data = ns._hookFrameData and ns._hookFrameData[icon]
    if not (data and data.procGlowActive == true and type(ns.StartNativeGlow) == "function") then return end
    local overlay = data.glowOverlay or icon._glowOverlay
    local glow = overlay and ns._cdmGlowRec and ns._cdmGlowRec[overlay]
    if glow and not overlay._glowActive then
        pcall(ns.StartNativeGlow, overlay, glow.style, glow.r, glow.g, glow.b, glow.opts)
    end
end

function E:ShowProc(icon)
    local profile = self:ProcProfile()
    if not profile.enabled or not icon then return end
    local ns = ModuleNamespace()
    local record = self.records[icon]
    if not record then self:BindIcon(icon, ns); record = self.records[icon] end
    if not record then return end
    record.procActive = true
    ConfigureProcLayer(record, ns, profile, true)
    SuppressEUIProc(record)
    record.proc.root:Show()
    if profile.mode == "PULSE" or profile.mode == "BOTH" then
        record.proc.root._pulse.group:Stop()
        record.proc.root._pulse.group:Play()
    else
        StopPulse(record.proc.root)
    end
end

function E:HideProc(icon)
    local record = icon and self.records[icon]
    if not record or not record.proc then return end
    record.procActive = nil
    StopPulse(record.proc.root)
    record.proc.root:Hide()
end

-- EllesmereUI resolves Blizzard's alert frame to the actual Cooldown Manager
-- icon before it sets procGlowActive.  That mapping includes transformed and
-- override spells and is more authoritative than duplicating it from a raw
-- ShowAlert frame.  Synchronize from that public module state after EUI's hook
-- has run; the legacy frame lookup remains only as a non-EUI fallback.
function E:SyncEUIProcState()
    if not self:ProcEnabled() then return false end
    local ns = ModuleNamespace()
    if not ns or not ns._hookFrameData then return false end
    local foundState = false
    for _, icon in ipairs(VisibleCDMIcons(ns)) do
        local data = ns._hookFrameData[icon]
        if data and data.procGlowActive ~= nil then
            foundState = true
            local record = self.records[icon]
            if not record then
                self:BindIcon(icon, ns)
                record = self.records[icon]
            end
            if data.procGlowActive then
                if record and not record.procActive then self:ShowProc(icon)
                elseif record then SuppressEUIProc(record) end
            elseif record and record.procActive then
                self:HideProc(icon)
            end
        end
    end
    return foundState
end

function E:PreviewProc()
    self:Scan()
    local icon
    for _, candidate in pairs(self.iconsByCooldownID) do icon = candidate break end
    if not icon then return false, SUI.Text("Нет видимой иконки Cooldown Manager.", "No visible Cooldown Manager icon.") end
    local wasEnabled = self:ProcProfile().enabled
    self:ProcProfile().enabled = true
    self:ShowProc(icon)
    self:ProcProfile().enabled = wasEnabled
    SUI:After(2.4, M, "proc preview", function()
        local record = E.records[icon]
        if record and record.procActive then E:HideProc(icon) end
    end)
    return true
end

function E:PreviewRule(cooldownID, levelIndex)
    self:Scan()
    local icon = self.iconsByCooldownID[tonumber(cooldownID)]
    if not icon then return false, SUI.Text("Этот баф сейчас не отображается в Cooldown Manager.", "This buff is not shown in Cooldown Manager.") end
    local record = self.records[icon]
    if not record or not record.rule then return false, SUI.Text("Сначала включите правило для бафа.", "Enable the buff rule first.") end
    RuleDefaults(record.rule)
    record.previewLevel = math.max(1, math.min(#record.rule.levels, tonumber(levelIndex) or 1))
    record.previewSerial = (record.previewSerial or 0) + 1
    local serial = record.previewSerial
    ConfigureStackLayers(record, record.ns, record.rule)
    self:FeedStack(record)
    SUI:After(2.4, M, "stack preview", function()
        if E.records[icon] == record and record.previewSerial == serial then
            record.previewLevel = nil
            ConfigureStackLayers(record, record.ns, record.rule)
            E:FeedStack(record)
        end
    end)
    return true
end

function E:RefreshAll()
    local buffEnabled, procEnabled = self:BuffEnabled(), self:ProcEnabled()
    if self:IsActive() then self:Scan(); self:UpdateStacks()
    else wipe(self.iconsByCooldownID) end
    if procEnabled then self:SyncEUIProcState() end
    for _, record in pairs(self.records) do
        if not buffEnabled then
            ReleaseEUIBuffGlows(record)
            record.previewLevel = nil
            record.previewSerial = (record.previewSerial or 0) + 1
            if record.stack then record.stack.root:Hide() end
        end
        if record.proc and not procEnabled then self:HideProc(record.icon) end
        if not procEnabled then ReleaseEUIProc(record) end
    end
end

function E:OnEvent(event, unit)
    if event == "UNIT_AURA" then
        if unit == "player" then
            self:UpdateStacks()
            self:ScheduleStackRefresh()
        end
        return
    end
    if event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        if RootProfile().enabled ~= false and self:ProcProfile().enabled then
            -- EUI consumes the same event and publishes procGlowActive. Defer
            -- twice so load order cannot make us read its previous state.
            SUI:After(0, M, "proc state sync", function() E:SyncEUIProcState() end)
            SUI:After(.05, M, "proc state sync delayed", function() E:SyncEUIProcState() end)
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
        or event == "GROUP_ROSTER_UPDATE" then
        self:RefreshAll()
        return
    end
    M:ScheduleScan(event == "PLAYER_ENTERING_WORLD" and .30 or .05)
end
