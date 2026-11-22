local _, SUI = ...
local A = SUI.Nameplates.AuraRules
local FILTER = "HARMFUL|PLAYER"
local CLIP_WIDTH = 512
local CLIP_HEIGHT = 300
local healthFields = { "hpNumber", "hpText" }
local labelFields = { "name", "levelText", "totText", "questText", "_classicLevel", "_fvLevelBox" }
local hooked = setmetatable({}, { __mode = "k" })

function A:BuildTextSensors(record, healthBar)
    local holder = CreateFrame("Frame", nil, healthBar)
    holder:SetAllPoints(healthBar)
    holder:SetAlpha(0)
    holder:EnableMouse(false)

    -- Blizzard sizes an aura group to its matching button. Anchor the text
    -- clips to that rect so the renderer handles visibility, even with secret auras.
    local sensors = {}
    for index, ids in ipairs(record.conditionIDs) do
        local sensor = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
        sensor:SetPoint("TOPLEFT", holder, "TOPLEFT", -97, 96)
        sensor:SetSize(1, 1)
        sensor:SetEnabled(false)
        sensor:AddAuraGroup("SUIText", FILTER, {
            candidateFilters = { includeSpellIDs = ids },
            maxFrameCount = 1,
            layout = { elementWidth = CLIP_WIDTH, elementHeight = 1 },
            initializeFrame = function(button) button:EnableMouse(false) end,
        })
        sensors[index] = sensor
    end
    record.textSensors = sensors
    record.groupContainers = record.groupContainers + #sensors
end

local function NewLayer(record, host)
    local root = CreateFrame("Frame", nil, host, "DisableUntrustedLayoutScriptsTemplate")
    root:SetAllPoints(host)
    root:EnableMouse(false)
    local clips, parent = {}, root
    for index, sensor in ipairs(record.textSensors) do
        local clip = CreateFrame("Frame", nil, parent)
        clip:SetClipsChildren(true)
        clip:EnableMouse(false)
        clip:SetPoint("TOPLEFT", sensor, "TOPLEFT", 0, CLIP_HEIGHT)
        clip:SetPoint("BOTTOMRIGHT", sensor, "BOTTOMRIGHT", 0, -CLIP_HEIGHT)
        clips[index], parent = clip, clip
    end
    return { root = root, clips = clips, copy = parent:CreateFontString(nil, "OVERLAY") }
end

local function StyleLayer(layer, source, host, record, ruleCount)
    local root, copy = layer.root, layer.copy
    if root:GetParent() ~= host then
        root:SetParent(host)
        root:ClearAllPoints()
        root:SetAllPoints(host)
    end
    local strata = host:GetFrameStrata()
    local level = host:GetFrameLevel() + 1 + (ruleCount - record.rank) * 3
    root:SetFrameStrata(strata)
    root:SetFrameLevel(level)
    for index, clip in ipairs(layer.clips) do
        clip:SetFrameStrata(strata)
        clip:SetFrameLevel(level + index)
    end

    local fontObject = source:GetFontObject()
    local families = EllesmereUI and EllesmereUI._fontFamilySet
    if fontObject and families and families[fontObject] then
        copy:SetFontObject(fontObject)
    else
        local font, size, flags = source:GetFont()
        if font then copy:SetFont(font, size, flags or "") end
    end
    copy:ClearAllPoints()
    copy:SetAllPoints(source)
    copy:SetJustifyH(source:GetJustifyH())
    copy:SetJustifyV(source:GetJustifyV())
    copy:SetWordWrap(source:CanWordWrap())
    copy:SetNonSpaceWrap(source:CanNonSpaceWrap())
    copy:SetMaxLines(source:GetMaxLines())
    copy:SetShadowColor(source:GetShadowColor())
    copy:SetShadowOffset(source:GetShadowOffset())
    copy:SetAlpha(source:GetAlpha())
    local color = record.rule.color or {}
    local _, _, _, alpha = source:GetTextColor()
    if issecretvalue and issecretvalue(alpha) then alpha = nil end
    copy:SetTextColor(color.r or color[1] or 1, color.g or color[2] or .35, color.b or color[3] or .75, alpha or 1)
    layer.source = source
end

local function SyncFields(rig, record, fields, active, layout)
    local layers = record.textLayers
    for _, field in ipairs(fields) do
        local layer = layers[field]
        local source = active and rig.plate[field]
        if source and field == "_fvLevelBox" then source = source._fs end
        if source and source.GetText and source:IsShown() then
            if layout or not layer or layer.source ~= source then
                local host = source:GetParent()
                layer = layer or NewLayer(record, host)
                layers[field] = layer
                StyleLayer(layer, source, host, record, rig.ruleCount)
            end
            -- Forward the rendered string directly, including secret health text.
            layer.copy:SetText(source:GetText())
            layer.root:Show()
        elseif layer then
            layer.root:Hide()
        end
    end
end

local function OwnsPlate(rig)
    local plate = rig.plate
    if not rig.unit or not plate or plate.health ~= rig.healthBar then return false end
    local unit = plate.unit
    if (issecretvalue and issecretvalue(unit)) or unit ~= rig.unit then return false end
    local native = plate.nameplate
    if not native then return true end
    local owner = native.namePlateUnitToken
    return not (issecretvalue and issecretvalue(owner)) and owner == unit
end

function A:RefreshTextLayers(rig, channel, layout)
    local ownsPlate = OwnsPlate(rig)
    if not ownsPlate then channel = nil end
    for _, record in ipairs(rig.rules) do
        if record.textSensors then
            local active = ownsPlate and record.boundUnit == rig.unit
            record.textLayers = record.textLayers or {}
            if record.colorText and channel ~= "LABELS" then
                SyncFields(rig, record, healthFields, active, layout)
            end
            if record.colorLabels and channel ~= "TEXT" then
                SyncFields(rig, record, labelFields, active, layout)
            end
        end
    end
end

local function Hook(plate, method, channel, layout)
    if type(plate[method]) ~= "function" then return end
    hooksecurefunc(plate, method, function(owner)
        local rig = A.rigs[owner.health]
        if rig and rig.hasTextRules and rig.plate == owner then
            A:RefreshTextLayers(rig, channel, layout)
        end
    end)
end

function A:HookTextOwner(plate)
    if hooked[plate] then return end
    hooked[plate] = true
    Hook(plate, "SetUnit", nil, true)
    Hook(plate, "ClearUnit")
    Hook(plate, "ApplyTarget", nil, true)
    Hook(plate, "ApplyHealthTextAppearance", nil, true)
    Hook(plate, "RefreshNamePosition", "LABELS", true)
    Hook(plate, "UpdateQuestText", "LABELS", true)
    Hook(plate, "UpdateName", "LABELS")
    Hook(plate, "ApplyNameVisibility", "LABELS")
    Hook(plate, "UpdateToT", "LABELS")
    Hook(plate, "UpdateHealthValues", "TEXT")
end
