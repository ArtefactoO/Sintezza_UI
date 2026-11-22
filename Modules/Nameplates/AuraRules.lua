local _, SUI = ...
local Text = SUI.Text
local M = SUI.Nameplates

local A = {
    rigs = {}, units = {}, pendingRebuild = false, MAX_CONDITIONS = 2,
    rigCache = setmetatable({}, { __mode = "k" }),
    combatBlockedBars = setmetatable({}, { __mode = "k" }),
    repairAttempts = setmetatable({}, { __mode = "k" }),
    slotApiPresent = nil,
    buildAttempts = 0, buildFailures = 0,
    rigRepairs = 0,
    MIN_BORDER_THICKNESS = 1, MAX_BORDER_THICKNESS = 4,
}
M.AuraRules = A

-- Aura fills share the health bar's frame level and use texture sublevels for
-- rule priority. EllesmereUI target/focus/hover clips sit at health+1, so they
-- remain visibly above the rule colour as intended.
local BASE_LEVEL_OFFSET = 0
local LEVELS_PER_RULE = 0
local RANK_INSET = 0.5
local RANK_INSET_MAX = 1
local MAX_RIG_REPAIRS = 1
local DEFAULT_RULE_COLOR = { r = 1, g = .35, b = .75, a = 1 }
local visualTargets = { "HEALTH", "BORDER" }

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function SafePlainCall(func, ...)
    if type(func) ~= "function" then return nil, false end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) or value == nil then return nil, false end
    return value, true
end

-- Probe the real container at build time. Blizzard_AuraContainer may not be
-- loaded during ADDON_LOADED, which made early cached probes incorrectly fall
-- back to ten pooled buttons for the entire session.
local function SlotsAvailable(container)
    local present = type(container.AddAuraSlot) == "function"
    A.slotApiPresent = present
    return present
end

function A:DesiredUnit(unit, tapDenied, rule)
    if tapDenied then return nil end
    if unit and rule.showOnTarget == false then
        local isTarget, readable = SafePlainCall(UnitIsUnit, unit, "target")
        if readable and isTarget then unit = nil end
    end
    if unit and rule.showOnFocus == false then
        local isFocus, readable = SafePlainCall(UnitIsUnit, unit, "focus")
        if readable and isFocus then unit = nil end
    end
    return unit
end

local function BindContainer(record, container, unit, force)
    -- A nameplate token is stable as text but not as identity: Blizzard can
    -- resolve the same "nameplateN" to a different secure unit after target
    -- changes or frame recycling.  Caching the token therefore skips a
    -- required SetUnit and leaves the aura button on the previous creature.
    -- This path is event-driven (plate/target/focus changes), not polled, so
    -- always reassigning here is both correct and inexpensive.
    if unit then
        container:SetUnit(unit)
        container:SetEnabled(true)
    else
        container:SetEnabled(false)
    end
    record.bindings = record.bindings or setmetatable({}, { __mode = "k" })
    record.bindings[container] = unit or false
end

function A:RootProfile()
    local profile = M:Profile()
    return profile and profile.auraRules
end

function A:ClassSpecKey()
    return SUI:GetClassSpecScope()
end

function A:Profile()
    local root = self:RootProfile()
    if not root then return nil end
    root.scopes = type(root.scopes) == "table" and root.scopes or {}
    local key, classToken, specID, specName = self:ClassSpecKey()
    local scope = root.scopes[key]
    if not scope then
        scope = { enabled = false, rules = {} }
        root.scopes[key] = scope
    end
    scope.enabled = scope.enabled == true
    scope.rules = type(scope.rules) == "table" and scope.rules or {}
    scope.classToken, scope.specID, scope.specName = classToken, specID, specName
    return scope
end

function A:ScopeLabel()
    local _, classToken, _, specName = self:ClassSpecKey()
    local className = classToken
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken] then
        className = LOCALIZED_CLASS_NAMES_MALE[classToken]
    elseif LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken] then
        className = LOCALIZED_CLASS_NAMES_FEMALE[classToken]
    end
    if not className or className == "UNKNOWN" then className = Text("Неизвестный класс", "Unknown class") end
    return className .. " · " .. tostring(specName)
end

function A:IsRuleAvailable(rule)
    local catalog = M.AuraCatalog
    if not catalog or not catalog.IsAuraAvailable then return true end
    for _, condition in ipairs(self:Conditions(rule)) do
        if not catalog:IsAuraAvailable(condition.spellID) then return false, condition.spellID end
    end
    return true
end

function A:IsRestrictedBuild()
    return InCombatLockdown and InCombatLockdown()
end

function A:Conditions(rule)
    if type(rule.conditions) ~= "table" then rule.conditions = {} end
    if #rule.conditions == 0 and type(rule.spellID) == "number" and rule.spellID > 0 then
        rule.conditions[1] = { spellID = rule.spellID }
    end
    for index = #rule.conditions, 1, -1 do
        local condition = rule.conditions[index]
        local spellID = type(condition) == "table" and tonumber(condition.spellID) or tonumber(condition)
        if spellID and spellID > 0 then
            rule.conditions[index] = { spellID = spellID }
        else
            table.remove(rule.conditions, index)
        end
    end
    -- Keep the first spell mirrored for downgrade compatibility. Current
    -- builds use conditions exclusively, but 0.7.20 and older read spellID.
    rule.spellID = rule.conditions[1] and rule.conditions[1].spellID or nil
    return rule.conditions
end

function A:SortRules()
    local profile = self:Profile()
    if not profile then return end
    local order = {}
    for index, rule in ipairs(profile.rules or {}) do
        self:Conditions(rule)
        order[rule] = index
    end
    table.sort(profile.rules, function(a, b)
        local ac, bc = #self:Conditions(a), #self:Conditions(b)
        if ac ~= bc then return ac > bc end
        return order[a] < order[b]
    end)
end

function A:EnabledRules()
    local profile = self:Profile()
    local result = {}
    if not profile or not profile.enabled then return result end
    self:SortRules()
    for index, rule in ipairs(profile.rules or {}) do
        local conditions = self:Conditions(rule)
        local available, missingSpellID = self:IsRuleAvailable(rule)
        rule.autoUnavailable = not available
        rule.missingSpellID = missingSpellID
        if rule.enabled ~= false and #conditions > 0 and #conditions <= self.MAX_CONDITIONS then
            result[#result + 1] = rule
        end
    end
    return result
end

-- A higher rule covers a lower rule when every lower condition is contained
-- in the higher one. In that case the higher opaque fill already hides the
-- lower fill completely and both may stay flush with the health bar. Only
-- genuinely disjoint rules need a small geometric step to prevent a lower
-- colour leaking around an aura button whose secure strata cannot be read.
function A:RuleCovers(higher, lower)
    local remaining = {}
    for _, condition in ipairs(self:Conditions(lower)) do
        remaining[condition.spellID] = true
    end
    for _, condition in ipairs(self:Conditions(higher)) do
        remaining[condition.spellID] = nil
    end
    return next(remaining) == nil
end

function A:SupportsTextColoring()
    return M.adapterKey == "ellesmere"
end

function A:HasColorTarget(rule, target)
    if rule and type(rule.colorTargets) == "table" then return rule.colorTargets[target] == true end
    local legacy = rule and rule.colorTarget
    if legacy ~= "BORDER" and legacy ~= "TEXT" then legacy = "HEALTH" end
    return target == legacy
end

function A:SetColorTargetEnabled(rule, target, enabled)
    if not rule or (target ~= "HEALTH" and target ~= "BORDER" and target ~= "TEXT" and target ~= "LABELS") then return false end
    if type(rule.colorTargets) ~= "table" then
        rule.colorTargets = {
            HEALTH = self:HasColorTarget(rule, "HEALTH") or nil,
            BORDER = self:HasColorTarget(rule, "BORDER") or nil,
            TEXT = self:HasColorTarget(rule, "TEXT") or nil,
        }
    end
    rule.colorTargets[target] = enabled and true or nil
    return self:RebuildAll()
end

local function NormalizeThickness(value)
    return math.max(A.MIN_BORDER_THICKNESS,
        math.min(A.MAX_BORDER_THICKNESS, math.floor((tonumber(value) or SUI.AuraRuleDefaults.borderThickness) + .5)))
end

function A:BorderThickness(rule)
    return NormalizeThickness(rule and rule.borderThickness)
end

function A:RuleInsets(rules)
    local insets = {}
    for index, rule in ipairs(rules or {}) do
        local targetInsets = {}
        for _, target in ipairs(visualTargets) do
            if self:HasColorTarget(rule, target) then
                local inset = 0
                for higher = 1, index - 1 do
                    if insets[higher][target] and not self:RuleCovers(rules[higher], rule) then
                        inset = math.max(inset, insets[higher][target] + RANK_INSET)
                    end
                end
                targetInsets[target] = math.min(RANK_INSET_MAX, inset)
            end
        end
        insets[index] = targetInsets
    end
    return insets
end

local function AnchorTexture(texture, healthBar, inset)
    local fill = healthBar:GetStatusBarTexture() or healthBar
    inset = inset or 0
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", fill, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -inset, inset)
end

-- Keep the coloured edge inside the HP bar and leave room for the other
-- layers. Thin bars may use a smaller width to keep their centres open.
local function PlaceRuleBorder(textures, parent, healthBar, inset, size, radius, corners)
    local edgeInset = 1 + (inset or 0)
    local height = SafePlainCall(healthBar.GetHeight, healthBar)
    if type(height) == "number" and height >= 3 then
        local half = (height - 1) / 2
        edgeInset = math.min(edgeInset, half - 1)
        size = math.min(size, half - edgeInset)
    end
    if radius then
        M:PlaceRoundedPlateRing(textures[1], parent, healthBar, radius, corners, -(edgeInset + size), size)
        return
    end
    textures[1]:SetPoint("TOPLEFT", healthBar, "TOPLEFT", edgeInset, -edgeInset)
    textures[1]:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", -edgeInset, -edgeInset)
    textures[1]:SetHeight(size)
    textures[2]:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", edgeInset, edgeInset)
    textures[2]:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -edgeInset, edgeInset)
    textures[2]:SetHeight(size)
    textures[3]:SetPoint("TOPLEFT", healthBar, "TOPLEFT", edgeInset, -(edgeInset + size))
    textures[3]:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", edgeInset, edgeInset + size)
    textures[3]:SetWidth(size)
    textures[4]:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", -edgeInset, -(edgeInset + size))
    textures[4]:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -edgeInset, edgeInset + size)
    textures[4]:SetWidth(size)
end

-- The aura button still owns visibility. Store the geometry separately so a
-- width change never has to rebuild its secure container or change priority.
local function CreateRuleTextures(parent, healthBar, rule, border, inset, sublevel, color, alpha, namespace)
    local textures = {}
    local radius, corners
    if border then radius, corners = M:GetNativePlateRounding(healthBar, namespace) end
    local size = A:BorderThickness(rule)
    if radius and parent.CreateMaskTexture then
        local texture = parent:CreateTexture(nil, "OVERLAY", nil, sublevel)
        textures[1] = texture
        local ok = pcall(PlaceRuleBorder, textures, parent, healthBar, inset, size, radius, corners)
        if ok then
            texture:SetVertexColor(color.r, color.g, color.b, alpha or 1)
            if texture.SetIgnoreParentAlpha then texture:SetIgnoreParentAlpha(false) end
            return textures, radius, corners
        end
        texture:Hide()
    end
    for index = 1, border and 4 or 1 do
        local texture = parent:CreateTexture(nil, "OVERLAY", nil, sublevel)
        texture:SetColorTexture(color.r, color.g, color.b, alpha or 1)
        if texture.SetIgnoreParentAlpha then texture:SetIgnoreParentAlpha(false) end
        textures[index] = texture
    end
    if border then PlaceRuleBorder(textures, parent, healthBar, inset, size)
    else AnchorTexture(textures[1], healthBar, inset) end
    return textures
end

function A:PaintPreviewBorder(frame, health, rule, color, namespace, radius, corners, alpha)
    if not color then frame:Hide(); return end
    frame.previewBorders = frame.previewBorders or {}
    local key = (radius or 0) * 16 + (corners or 0)
    local textures = frame.previewBorders[key]
    if not textures then
        textures = CreateRuleTextures(frame, health, rule, true, 0, 5, color, alpha or 1, namespace)
        frame.previewBorders[key] = textures
    end
    PlaceRuleBorder(textures, frame, health, 0, self:BorderThickness(rule),
        #textures == 1 and radius or nil, corners)
    if frame.previewTextures ~= textures then
        for _, texture in ipairs(frame.previewTextures or {}) do texture:Hide() end
        for _, texture in ipairs(textures) do texture:Show() end
        frame.previewTextures = textures
    end
    for _, texture in ipairs(textures) do
        M:ColorPlateEffectTexture(texture, color.r, color.g, color.b, alpha or 1)
    end
    frame:Show()
end

local function UpdateBorderThickness(record, healthBar)
    local size = A:BorderThickness(record.rule)
    if record.borderThickness == size then return end
    for _, border in ipairs(record.borders) do
        PlaceRuleBorder(border.textures, border.parent, healthBar, border.inset, size, border.radius, border.corners)
    end
    record.borderThickness = size
end

function A:RefreshBorderThickness(rule)
    if self:IsRestrictedBuild() then self.pendingBorderThickness = true; return end
    if not rule then self.pendingBorderThickness = nil end
    for healthBar, rig in pairs(self.rigs) do
        for _, record in ipairs(rig.rules) do
            if not rule or record.rule == rule then UpdateBorderThickness(record, healthBar) end
        end
    end
end

function A:SetBorderThickness(rule, value)
    local size = NormalizeThickness(value)
    if not rule or self:BorderThickness(rule) == size then return end
    rule.borderThickness = size
    self:RefreshBorderThickness(rule)
end

local function RuleBaseLevel(rig)
    local level, readable = SafePlainCall(rig.healthBar.GetFrameLevel, rig.healthBar)
    if not readable or type(level) ~= "number" then return nil end
    return level + BASE_LEVEL_OFFSET
end

local function SpellSignature(condition)
    if not condition then return "" end
    local ids = M.AuraCatalog and M.AuraCatalog:RelatedSpellIDs(condition.spellID)
    if not ids then return condition.spellID end
    local sorted = {}
    for id in pairs(ids) do sorted[#sorted + 1] = id end
    table.sort(sorted)
    return condition.spellID .. "=" .. table.concat(sorted, ",")
end

function A:ConfigurationSignature(rules)
    local parts = {}
    local radius, corners = M:GetNativePlateRounding()
    if radius then parts[1] = "round:" .. radius .. ":" .. corners end
    for index, rule in ipairs(rules or self:EnabledRules()) do
        local conditions = self:Conditions(rule)
        local color = rule.color or {}
        parts[#parts + 1] = table.concat({
            index,
            self:HasColorTarget(rule, "HEALTH") and 1 or 0,
            self:HasColorTarget(rule, "BORDER") and 1 or 0,
            self:HasColorTarget(rule, "TEXT") and 1 or 0,
            self:HasColorTarget(rule, "LABELS") and 1 or 0,
            SpellSignature(conditions[1]), SpellSignature(conditions[2]),
            rule.showOnTarget == false and 0 or 1,
            rule.showOnFocus == false and 0 or 1,
            color.r or color[1] or 1, color.g or color[2] or 1,
            color.b or color[3] or 1, color.a or color[4] or 1,
        }, ":")
    end
    return table.concat(parts, "|")
end

function A:RestackRig(rig)
    if not rig or not rig.healthBar then return end
    local base = RuleBaseLevel(rig)
    if not base then return end
    local needsApply = rig.lastStackBase ~= base
    if not needsApply then
        -- EUI can reparent pooled containers without changing the numeric base.
        -- A restricted aura container can also refuse GetFrameLevel entirely;
        -- remember that instance so health-colour hooks do not retry it.
        for _, record in ipairs(rig.rules or {}) do
            local root = record.containers and record.containers[1]
            if root and root.GetFrameLevel and not (rig.unreadableStackRoots and rig.unreadableStackRoots[root]) then
                local level, readable = SafePlainCall(root.GetFrameLevel, root)
                if not readable or type(level) ~= "number" then
                    rig.unreadableStackRoots = rig.unreadableStackRoots or setmetatable({}, { __mode = "k" })
                    rig.unreadableStackRoots[root] = true
                elseif level ~= record.level then
                    needsApply = true
                    break
                end
            end
        end
    end
    if not needsApply then return end
    rig.lastStackBase = base
    for _, record in ipairs(rig.rules or {}) do
        record.level = base + (record.borderOnly and 1 or 0)
            + ((rig.ruleCount or 1) - (record.rank or 1)) * LEVELS_PER_RULE
        for _, container in ipairs(record.containers or {}) do
            pcall(container.SetFrameLevel, container, record.level)
        end
        for _, host in ipairs(record.visualHosts or {}) do
            pcall(host.SetFrameLevel, host, record.level + (record.visualHostOffsets[host] or 0))
        end
    end
end

-- Aura data is secret in 12.1, so a two-condition rule is an ancestry chain:
-- each pooled button for condition 1 owns a container for condition 2. The
-- tint lives on the deepest button and therefore exists only while both
-- ancestors are visible. This is the same deterministic AND gate used by the
-- current PlateTweaks design. More than two conditions is deliberately refused.
function A:BuildRule(rig, healthBar, rule, rank, insets)
    local conditions = self:Conditions(rule)
    local fill = self:HasColorTarget(rule, "HEALTH")
    local border = self:HasColorTarget(rule, "BORDER")
    local borderOnly = border and not fill
    local text = self:SupportsTextColoring() and self:HasColorTarget(rule, "TEXT")
    local labels = self:SupportsTextColoring() and self:HasColorTarget(rule, "LABELS")
    local base = RuleBaseLevel(rig)
    if not base then error("health bar frame level unavailable") end
    local level = base + (borderOnly and 1 or 0)
        + ((rig.ruleCount or 1) - rank) * LEVELS_PER_RULE
    local record = {
        rule = rule,
        rank = rank,
        containers = {},
        visuals = {},
        borders = {},
        borderThickness = self:BorderThickness(rule),
        visualHosts = {},
        visualHostOffsets = {},
        borderOnly = borderOnly,
        colorText = text,
        colorLabels = labels,
        bindings = setmetatable({}, { __mode = "k" }),
        failures = 0,
        slotContainers = 0,
        groupContainers = 0,
        conditionCount = #conditions,
        level = level,
        insets = insets,
    }
    if #conditions == 0 or #conditions > self.MAX_CONDITIONS then
        record.unsupported = true
        return record
    end
    record.conditionIDs = {}
    for index, condition in ipairs(conditions) do
        local id = condition.spellID
        record.conditionIDs[index] = M.AuraCatalog and M.AuraCatalog:RelatedSpellIDs(id) or { [id] = true }
    end

    local function MakeVisuals(parent, isBorder, visualInset, sublevel, color, alpha)
        local activeRule = record.rule or rule
        local textures, radius, corners = CreateRuleTextures(parent, healthBar, activeRule, isBorder, visualInset, sublevel, color, alpha)
        if isBorder then
            record.borders[#record.borders + 1] = {
                textures = textures, parent = parent, inset = visualInset, radius = radius, corners = corners,
            }
        end
        return textures
    end

    local function AddVisual(button, target)
        local isBorder = target == "BORDER"
        local offset = isBorder and fill and 1 or 0
        local host = button
        if offset > 0 then
            host = CreateFrame("Frame", nil, button)
            host:SetAllPoints(healthBar)
        end
        pcall(host.SetFrameLevel, host, record.level + offset)
        local color = record.rule.color or DEFAULT_RULE_COLOR
        record.visualHosts[#record.visualHosts + 1] = host
        record.visualHostOffsets[host] = offset
        for _, texture in ipairs(MakeVisuals(host, isBorder, record.insets[target], math.max(-8, 5 - rank), color, 1)) do
            record.visuals[#record.visuals + 1] = { owner = host, texture = texture }
        end
    end

    local AttachContainer
    AttachContainer = function(parent, depth)
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        if not ok or not container then
            record.failures = record.failures + 1
            record.error = record.error or tostring(container)
            return
        end
        container:SetEnabled(false)
        container:SetSize(1, 1)
        pcall(container.SetAllPoints, container, healthBar)
        pcall(container.SetFrameLevel, container, record.level)
        local key = "SUI" .. tostring(rank) .. "D" .. tostring(depth)
        local useSlot = SlotsAvailable(container)
        local register = useSlot and container.AddAuraSlot or container.AddAuraGroup
        record.containers[#record.containers + 1] = container
        local okRegister, registerError = pcall(register, container, key, "HARMFUL|PLAYER", {
            candidateFilters = { includeSpellIDs = record.conditionIDs[depth] },
            maxFrameCount = not useSlot and 1 or nil,
            layout = not useSlot and { elementWidth = 1, elementHeight = 1 } or nil,
            initializeFrame = function(button)
                pcall(button.SetFrameLevel, button, record.level)
                button:EnableMouse(false)
                if depth < #conditions then AttachContainer(button, depth + 1)
                else
                    if fill then AddVisual(button, "HEALTH") end
                    if border then AddVisual(button, "BORDER") end
                end
            end,
        })
        if not okRegister then
            record.failures = record.failures + 1
            record.error = record.error or tostring(registerError)
            container:Hide()
            return
        end
        if useSlot then record.slotContainers = record.slotContainers + 1
        else record.groupContainers = record.groupContainers + 1 end
        BindContainer(record, container, self:DesiredUnit(rig.unit, rig.tapDenied, rule), true)
    end

    if fill or border then AttachContainer(healthBar, 1) end
    if text or labels then
        local ok, err = pcall(self.BuildTextSensors, self, record, healthBar)
        if ok then rig.hasTextRules = true
        else record.textError = IsSecret(err) and "secret error" or tostring(err) end
    end
    return record
end

function A:SetRigUnit(rig, unit, force)
    local relayout = rig.unit ~= unit or rig.textPlate ~= rig.plate
    rig.unit = unit
    rig.tapDenied = M:IsTapColorPriority(unit)
    self:RestackRig(rig)
    for _, record in ipairs(rig.rules or {}) do
        local rule = record.rule
        local bind = self:DesiredUnit(unit, rig.tapDenied, rule)
        record.boundUnit = bind
        for _, container in ipairs(record.containers) do
            pcall(container.SetFrameLevel, container, record.level)
            if unit then container:Show() end
            BindContainer(record, container, bind, force)
        end
        for _, sensor in ipairs(record.textSensors or {}) do
            BindContainer(record, sensor, bind, force)
        end
        for _, host in ipairs(record.visualHosts or {}) do
            pcall(host.SetFrameLevel, host, record.level + (record.visualHostOffsets[host] or 0))
        end
    end
    if rig.hasTextRules then
        if unit and rig.plate then self:HookTextOwner(rig.plate) end
        self:RefreshTextLayers(rig, nil, relayout)
        rig.textPlate = rig.plate
    end
end

function A:RetireRig(rig)
    if not rig then return end
    self:SetRigUnit(rig, nil)
    for _, record in ipairs(rig.rules or {}) do
        for _, visual in ipairs(record.visuals or {}) do
            if visual.texture then pcall(visual.texture.Hide, visual.texture) end
        end
        for _, container in ipairs(record.containers or {}) do container:Hide() end
    end
end
function A:IsRigSound(rig)
    if not rig or rig.builtInCombat then return false end
    for _, record in ipairs(rig.rules or {}) do
        if (record.failures or 0) > 0 then return false end
        if record.textError then return false end
    end
    return true
end

function A:DiscardRig(rig)
    if not rig then return end
    local healthBar, unit = rig.healthBar, rig.unit
    self:RetireRig(rig)
    if healthBar and self.rigs[healthBar] == rig then self.rigs[healthBar] = nil end
    if unit and self.units[unit] == rig then self.units[unit] = nil end
end

function A:ResetRuntime()
    for _, rig in pairs(self.rigs or {}) do self:RetireRig(rig) end
    self.rigs, self.units = {}, {}
    self.rigCache = setmetatable({}, { __mode = "k" })
    self.combatBlockedBars = setmetatable({}, { __mode = "k" })
    self.repairAttempts = setmetatable({}, { __mode = "k" })
    self.pendingRebuild = false
    self.pendingBorderThickness = nil
    self.rigRepairs = 0
end

function A:BuildRig(healthBar, repairs)
    local enabledRules = self:EnabledRules()
    local signature = self:ConfigurationSignature(enabledRules)
    local cachedBySignature = self.rigCache[healthBar]
    local cached = cachedBySignature and cachedBySignature[signature]
    if cached and self:IsRigSound(cached) then
        cachedBySignature[signature] = nil
        cached.ruleCount = #enabledRules
        cached.signature = signature
        local insets = self:RuleInsets(enabledRules)
        for rank, record in ipairs(cached.rules or {}) do
            record.rule, record.rank, record.insets = enabledRules[rank], rank, insets[rank]
            UpdateBorderThickness(record, healthBar)
            -- RetireRig hides textures; reusing the cached shape must reveal
            -- them again under their still-disabled aura containers.
            for _, visual in ipairs(record.visuals or {}) do visual.texture:Show() end
        end
        self.rigs[healthBar] = cached
        return cached
    elseif cached then
        cachedBySignature[signature] = nil
        self:RetireRig(cached)
    end
    local rig = {
        healthBar = healthBar,
        rules = {},
        ruleCount = #enabledRules,
        repairs = tonumber(repairs) or 0,
        builtInCombat = self:IsRestrictedBuild() == true,
    }
    rig.signature = signature
    local insets = self:RuleInsets(enabledRules)
    local buildError
    for rank, rule in ipairs(enabledRules) do
        local record = self:BuildRule(rig, healthBar, rule, rank, insets[rank])
        record.rank = rank
        rig.rules[#rig.rules + 1] = record
        if (record.failures or 0) > 0 then
            buildError = buildError or record.error or ("rule " .. tostring(rank) .. " did not build completely")
        end
    end
    if buildError then
        self:RetireRig(rig)
        error(buildError)
    end
    self.rigs[healthBar] = rig
    return rig
end

function A:TryBuildRig(healthBar, repairs)
    if self:IsRestrictedBuild() and self.combatBlockedBars[healthBar] then return nil end
    self.buildAttempts = (self.buildAttempts or 0) + 1
    local ok, rig = pcall(self.BuildRig, self, healthBar, repairs)
    if ok and rig then
        self.combatBlockedBars[healthBar] = nil
        self.repairAttempts[healthBar] = nil
        self.lastBuildError = nil
        self.lastReportedBuildError = nil
        local diagnostics = SUI.Diagnostics
        local state = diagnostics and diagnostics.errors and diagnostics.errors[M.key]
        if state and state.context == "nameplate aura rig" then diagnostics:ClearModuleError(M.key) end
        return rig
    end
    self.buildFailures = (self.buildFailures or 0) + 1
    if self:IsRestrictedBuild() then self.combatBlockedBars[healthBar] = true end
    self.lastBuildError = IsSecret(rig) and "secret error" or tostring(rig or "unknown build error")
    if SUI.Diagnostics and self.lastReportedBuildError ~= self.lastBuildError then
        SUI.Diagnostics:RecordError(M.key, "nameplate aura rig", self.lastBuildError)
        self.lastReportedBuildError = self.lastBuildError
    end
    return nil
end

function A:TopVisualLevel(healthBar)
    local rig = self.rigs[healthBar]
    local top
    for _, record in ipairs(rig and rig.rules or {}) do
        if #record.containers > 0 and record.level and (not top or record.level > top) then top = record.level end
        -- Secure aura buttons can refuse the requested level and keep the
        -- level inherited from their container.  Read the real value when the
        -- client allows it so target/shade overlays never land underneath a
        -- randomly selected pooled button.
        for _, host in ipairs(record.visualHosts or {}) do
            local level, readable = SafePlainCall(host.GetFrameLevel, host)
            if readable and type(level) == "number" and (not top or level > top) then top = level end
        end
    end
    return top
end

function A:AttachPlate(unit, plate, forceRebind)
    if not plate or not plate.health then return false end
    local profile = self:Profile()
    if not profile or not profile.enabled then
        self:DetachPlate(unit)
        return true
    end
    local previous = self.units[unit]
    local firstBinding = previous == nil or previous.unit ~= unit
    if previous and previous.healthBar ~= plate.health then
        self:DiscardRig(previous)
        firstBinding = true
    end

    local healthBar = plate.health
    local rig = self.rigs[healthBar]
    local repairs = self.repairAttempts[healthBar] or (rig and rig.repairs) or 0
    if rig and not self:IsRestrictedBuild() and not self:IsRigSound(rig)
        and repairs < MAX_RIG_REPAIRS then
        local oldRig = rig
        repairs = repairs + 1
        self.repairAttempts[healthBar] = repairs
        local candidate = self:TryBuildRig(healthBar, repairs)
        if candidate then
            self:DiscardRig(oldRig)
            self.rigRepairs = (self.rigRepairs or 0) + 1
            rig = candidate
            firstBinding = true
        else
            -- Keep the old bounded fallback. Secure frames cannot be destroyed,
            -- and retrying a failed repair on every attach would leak more.
            self.rigs[healthBar] = oldRig
            rig = oldRig
        end
    end
    if not rig then
        -- Build once immediately so plates appearing in combat can still work.
        -- Any combat-built rig is suspect and receives one bounded repair after
        -- lockdown. An explicit combat failure blocks repeated attempts on this
        -- bar until PLAYER_REGEN_ENABLED, avoiding secure-frame churn.
        rig = self:TryBuildRig(healthBar, repairs)
        if not rig then return false end
    end
    rig.plate = plate
    rig.nativePlate = plate.nameplate
    self.units[unit] = rig
    self:SetRigUnit(rig, unit, forceRebind or firstBinding)
    if M.UpdateSelectionVisuals then M:UpdateSelectionVisuals(plate) end
    if M.UpdateHoverOverlay then M:UpdateHoverOverlay(plate) end
    return true
end

-- EllesmereUI may exchange health-bar objects between nameplate unit tokens
-- when the target/focus changes.  Rebinding one unit at a time is unsafe for a
-- swap: the first unit can temporarily claim the second unit's rig, then the
-- second AttachPlate retires that same rig and leaves the first mapping stale.
-- Build the complete bar -> unit map first, detach changed rigs, and only then
-- attach them to their final owners.
function A:ReconcilePlates(force)
    local nextUnits, desiredByRig, plateByRig = {}, {}, {}

    for unit, plate in pairs(M.plates or {}) do
        if M.activeUnits[unit] and plate and plate.health then
            local rig = self.rigs[plate.health]
            if not rig then rig = self:TryBuildRig(plate.health) end
            if rig and not desiredByRig[rig] then
                nextUnits[unit] = rig
                desiredByRig[rig] = unit
                plateByRig[rig] = plate
            elseif not rig then
                M.pendingUnits[unit] = true
            end
        end
    end

    -- First remove every stale binding.  This is what makes an A <-> B swap
    -- atomic from the aura engine's point of view.
    for _, rig in pairs(self.rigs) do
        local desired = desiredByRig[rig]
        if rig.unit ~= desired then self:SetRigUnit(rig, nil, true) end
    end

    self.units = nextUnits
    for unit, rig in pairs(nextUnits) do
        rig.plate = plateByRig[rig]
        rig.nativePlate = rig.plate and rig.plate.nameplate
        self:SetRigUnit(rig, unit, force == true or rig.unit ~= unit)
        if M.UpdateSelectionVisuals then M:UpdateSelectionVisuals(rig.plate) end
        if M.UpdateHoverOverlay then M:UpdateHoverOverlay(rig.plate) end
    end
end

function A:DetachPlate(unit)
    local rig = self.units[unit]
    self.units[unit] = nil
    if rig then self:SetRigUnit(rig, nil) end
end
function A:RecoverAfterCombat()
    if self:IsRestrictedBuild() then return false end
    if self.pendingBorderThickness then self:RefreshBorderThickness() end
    wipe(self.combatBlockedBars)
    for unit, plate in pairs(M.plates or {}) do
        local rig = plate and plate.health and self.rigs[plate.health]
        if not rig or not self:IsRigSound(rig) then
            if not self:AttachPlate(unit, plate, true) then M.pendingUnits[unit] = true end
        end
    end
    return true
end

function A:RebuildAll()
    if self:IsRestrictedBuild() then self.pendingRebuild = true; return false end
    local signature = self:ConfigurationSignature()
    local unchanged = next(self.rigs) ~= nil
    for _, rig in pairs(self.rigs) do
        if rig.signature ~= signature or not self:IsRigSound(rig) then unchanged = false; break end
    end
    if unchanged then
        self.pendingRebuild = false
        self:RefreshAll()
        return true
    end
    local old = self.rigs
    self.rigs, self.units = {}, {}
    for healthBar, rig in pairs(old) do
        local sound = self:IsRigSound(rig)
        self:RetireRig(rig)
        if sound then
            local cache = self.rigCache[healthBar]
            if not cache then cache = {}; self.rigCache[healthBar] = cache end
            cache[rig.signature or ""] = rig
        end
    end
    self.pendingRebuild = false
    for unit, plate in pairs(M.plates) do
        if not self:AttachPlate(unit, plate) then M.pendingUnits[unit] = true end
    end
    return true
end

function A:RefreshAll()
    for unit, rig in pairs(self.units) do self:SetRigUnit(rig, unit) end
    if self.pendingRebuild and not self:IsRestrictedBuild() then self:RebuildAll() end
end

function A:ApplyRuleAppearance(rule)
    for _, rig in pairs(self.rigs) do
        for _, record in ipairs(rig.rules or {}) do
            if record.rule == rule then
                local color = rule.color or DEFAULT_RULE_COLOR
                for _, visual in ipairs(record.visuals or {}) do
                    if visual.texture then M:ColorPlateEffectTexture(visual.texture, color.r, color.g, color.b, 1) end
                end
            end
        end
        if rig.hasTextRules then self:RefreshTextLayers(rig, nil, true) end
    end
end

function A:GetDiagnostics()
    local result = {
        rigs = 0, rules = 0, containers = 0, visuals = 0,
        failures = 0, unsupported = 0, slots = 0, groups = 0,
        slotApiPresent = self.slotApiPresent,
        suspectRigs = 0,
        rigRepairs = self.rigRepairs or 0,
        repairCap = MAX_RIG_REPAIRS,
        combatBlocked = 0,
        buildAttempts = self.buildAttempts or 0,
        buildFailures = self.buildFailures or 0,
        lastBuildError = self.lastBuildError,
    }
    for _ in pairs(self.combatBlockedBars) do result.combatBlocked = result.combatBlocked + 1 end
    for _, rig in pairs(self.rigs) do
        result.rigs = result.rigs + 1
        if not self:IsRigSound(rig) then result.suspectRigs = result.suspectRigs + 1 end
        for _, record in ipairs(rig.rules or {}) do
            result.rules = result.rules + 1
            result.containers = result.containers + #record.containers + #(record.textSensors or {})
            result.visuals = result.visuals + #(record.visuals or {})
            result.failures = result.failures + (record.failures or 0)
            if record.textError then
                result.failures = result.failures + 1
                result.lastBuildError = result.lastBuildError or record.textError
            end
            result.slots = result.slots + (record.slotContainers or 0)
            result.groups = result.groups + (record.groupContainers or 0)
            if record.unsupported then result.unsupported = result.unsupported + 1 end
        end
    end
    return result
end

function A:AddRule(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 then return false, Text("Укажи ID заклинания.", "Enter a valid spell ID.") end
    local profile = self:Profile()
    for _, rule in ipairs(profile.rules) do
        local conditions = self:Conditions(rule)
        if #conditions == 1 and conditions[1].spellID == spellID then
            return false, Text("Правило для этого дебаффа уже есть.", "A rule for this debuff already exists.")
        end
    end
    profile.rules[#profile.rules + 1] = {
        enabled = true,
        spellID = spellID,
        conditions = { { spellID = spellID } },
        color = { r = 1, g = 0.35, b = 0.75, a = 1 },
        showOnTarget = true,
        showOnFocus = true,
        colorTarget = SUI.AuraRuleDefaults.colorTarget,
        borderThickness = SUI.AuraRuleDefaults.borderThickness,
    }
    self:SortRules(); self:RebuildAll()
    return true
end

function A:AddCondition(rule, spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 then return false, Text("Укажи ID заклинания.", "Enter a valid spell ID.") end
    local conditions = self:Conditions(rule)
    if #conditions >= self.MAX_CONDITIONS then
        return false, Text("В правиле может быть не больше %d дебаффов.", "A rule can have at most %d debuffs."):format(self.MAX_CONDITIONS)
    end
    for _, condition in ipairs(conditions) do
        if condition.spellID == spellID then
            return false, Text("Этот дебафф уже есть в правиле.", "This debuff is already in the rule.")
        end
    end
    conditions[#conditions + 1] = { spellID = spellID }
    self:SortRules(); self:RebuildAll()
    return true
end

function A:RemoveCondition(rule, conditionIndex)
    local conditions = self:Conditions(rule)
    if #conditions <= 1 then
        return false, Text("В правиле нужен хотя бы один дебафф.", "A rule needs at least one debuff.")
    end
    table.remove(conditions, conditionIndex)
    rule.spellID = conditions[1] and conditions[1].spellID or nil
    self:SortRules(); self:RebuildAll()
    return true
end

function A:RemoveRule(index)
    local profile = self:Profile()
    table.remove(profile.rules, index)
    self:RebuildAll()
end

function A:Initialize()
    local profile = self:Profile()
    if profile then
        for _, rule in ipairs(profile.rules or {}) do self:Conditions(rule) end
        self:SortRules()
    end
end
