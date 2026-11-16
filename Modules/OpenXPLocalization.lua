local _, SUI = ...
local L = SUI.OpenXPText
if not SUI.isForever or not L or select(4, GetBuildInfo()) ~= 16001 then return end

local M = SUI:RegisterModule("openXPLocalization", {})
local isSecret = _G.issecretvalue

local function IsText(value)
    return not (isSecret and isSecret(value)) and type(value) == "string" and value ~= ""
end

local function ReadName(entity, id)
    if entity and type(entity.name) == "function" then
        local name = entity.name(id)
        if IsText(name) then return name end
    end
end

local function ReadRawName(entity, id)
    if entity and type(entity.GetRaw) == "function" then
        local name = entity.GetRaw(id, "name")
        if IsText(name) then return name end
    end
end

local function QuestLine(text, element)
    local tag = element.tag
    local id = tonumber(element.questId)
    if not id or id < 1 or (tag ~= "accept" and tag ~= "turnin") then return end
    local title
    if tag == "accept" then
        title = text:match("^Accept (.+)$") or text:match("^Принять (.+)$")
    else
        title = text:match("^Turn in (.+)$") or text:match("^Сдать (.+)$")
    end
    if not title or title:find("|", 1, true) or title:find("\n", 1, true) then return end

    local db = _G.LibQuestieDB
    local quests = db and db.Quest
    local base, localized = ReadRawName(quests, id), ReadName(quests, id)
    local current = IsText(element.title) and element.title or nil
    if title ~= "*quest*" and title ~= base and title ~= localized and title ~= current then return end
    if localized and localized ~= base then return L[tag]:format(localized) end
    local getTitle = C_QuestLog and C_QuestLog.GetTitleForQuestID
    local clientTitle = getTitle and getTitle(id)
    if IsText(clientTitle) then localized = clientTitle end
    if localized then return L[tag]:format(localized) end
end

local ENTITY_SLOT = { Npc = 1, Object = 2, Item = 3 }

local function EntityName(db, kind, source, step)
    local entity = db and db[kind]
    if not (entity and step and step.elements and type(entity.GetRaw) == "function") then return end
    local slot = ENTITY_SLOT[kind]
    local found, ambiguous
    local function Consider(id)
        if not id or ReadRawName(entity, id) ~= source then return end
        local name = ReadName(entity, id)
        if kind == "Item" and (not name or name == source) then
            local getItem = C_Item and C_Item.GetItemInfo
            local itemName = getItem and getItem(id)
            if IsText(itemName) then name = itemName end
        end
        if not name then return end
        if found and name ~= found then ambiguous = true end
        found = name
    end

    local quests = db.Quest
    for _, e in ipairs(step.elements) do
        if kind == "Item" and (e.tag == "collect" or e.tag == "collectmultiple") then
            Consider(tonumber(e.id))
        elseif kind == "Npc" and (e.tag == "target" or e.tag == "mob") then
            for _, unit in ipairs(e.unitlist or {}) do
                Consider(tonumber(unit) or type(unit) == "string" and tonumber(unit:match("::(%d+)$")))
            end
        end
        local id = tonumber(e.questId)
        if quests and id and id > 0 then
            local field = e.tag == "accept" and quests.startedBy or e.tag == "turnin" and quests.finishedBy
            local endpoints = type(field) == "function" and field(id)
            for _, entityId in ipairs(endpoints and endpoints[slot] or {}) do Consider(entityId) end
            local objectives = e.tag == "complete" and type(quests.objectives) == "function" and quests.objectives(id)
            for _, objective in ipairs(objectives and objectives[slot] or {}) do Consider(objective[1]) end
        end
    end
    if not ambiguous then return found end
end

local COLOR_ROLES = {
    RXP_FRIENDLY_ = "Npc", RXP_ENEMY_ = "Npc",
    RXP_LOOT_ = "Item", RXP_BUY_ = "Item", RXP_PICK_ = "Object",
}

local function LocalizeLine(guide, text, element)
    if not element or not IsText(text) then return text end
    local quest = QuestLine(text, element)
    if quest then return quest end
    local colors = guide.guideTextColors or {}
    local db = _G.LibQuestieDB
    local function ReplaceName(code, source)
        local role = COLOR_ROLES[code]
        if not role then
            local hex = code:upper()
            local defaults = colors.default or {}
            for marker, kind in pairs(COLOR_ROLES) do
                local color = colors[marker] or defaults[marker]
                if type(color) == "string" and color:upper() == hex then
                    role = kind
                    break
                end
            end
        end
        local name = role and EntityName(db, role, source, element.step)
        if role == "Object" and (not name or name == source) then
            name = EntityName(db, "Item", source, element.step)
        end
        if role == "Npc" and (not name or name == source) and type(guide.GetCreatureName) == "function" then
            name = guide.GetCreatureName(source)
        end
        return "|c" .. code .. (IsText(name) and name or source) .. "|r"
    end

    local localized = text:gsub("|c(RXP_[A-Z]+_)([^|]+)|r", ReplaceName)
    localized = localized:gsub("|c(%x%x%x%x%x%x%x%x)([^|]+)|r", ReplaceName)
    localized = localized:gsub("^Talk to (|c)", L.talk .. "%1")
    localized = localized:gsub("^Click the (|c)", L.click .. "%1")
    localized = localized:gsub("^Kill (|c)", L.kill .. "%1")
    localized = localized:gsub("^Убить (|c)", L.kill .. "%1")
    localized = localized:gsub("(|r) and (|c)", "%1" .. L.andWord .. "%2")
    localized = localized:gsub("|r%. Loot them for (|c)", "|r" .. L.loot .. "%1")
    return (localized:gsub("%(about (%d+)%% drop%)", function(chance) return L.drop:format(chance) end))
end

local function LocalizeZone(guide, card)
    local active = guide.currentGuide
    local display = active and (active.displayname or active.name)
    if not IsText(display) or card.detour or not card.frame:IsShown() then return end
    local zone = display:match("^%d+%s*%-%s*%d+%s+(.+)$") or display
    local map = guide.mapId and guide.mapId[zone]
    if not map then return end
    for _, child in ipairs({card.frame:GetChildren()}) do
        local label = child.zone
        if label and child.range and child.step and type(label.GetText) == "function"
            and label:GetText() == zone:upper() then
            local info = C_Map.GetMapInfo(map)
            if not info or not IsText(info.name) or info.name == zone then return end
            label:SetText(info.name)
            label:SetWidth(0)
            local maxWidth = math.max(50, card.frame:GetWidth() - 150)
            if label:GetStringWidth() > maxWidth then label:SetWidth(maxWidth) end
            return
        end
    end
end

function M:GetGuide()
    if not SUI:IsAddonLoaded("OpenXP") or not LibStub then return end
    local ace = LibStub("AceAddon-3.0", true)
    local guide = ace and type(ace.GetAddon) == "function" and ace:GetAddon("OpenXP", true)
    local card = guide and guide.card
    if not (card and type(card.Refresh) == "function" and type(guide.ReplaceNpcIds) == "function") then return end
    return guide, card
end

function M:Attach()
    if self.attached or not SUI:IntegrationEnabled("questie") then return end
    local guide, card = self:GetGuide()
    if not guide then return end
    local original = guide.ReplaceNpcIds
    guide.ReplaceNpcIds = function(text, element, ...)
        local rendered = original(text, element, ...)
        local ok, localized = pcall(LocalizeLine, guide, rendered, element)
        return ok and localized or rendered
    end
    self.attached = true

    local aceLocale = LibStub("AceLocale-3.0", true)
    local strings = aceLocale and type(aceLocale.GetLocale) == "function" and aceLocale:GetLocale("OpenXP", true)
    if strings then
        for key, value in pairs(L.card) do
            local existing = rawget(strings, key)
            if not existing or existing == key then strings[key] = value end
        end
    end
    if hooksecurefunc and card.frame and C_Map and C_Map.GetMapInfo then
        local lastFull
        hooksecurefunc(card, "Refresh", function()
            if card.lastFull and card.lastFull ~= lastFull then
                lastFull = card.lastFull
                pcall(LocalizeZone, guide, card)
            end
        end)
    end
end

function M:Initialize()
    self:Attach()
    SUI:RegisterModuleEvent(self, "ADDON_LOADED")
end

function M:WantsEvent()
    return not self.attached and SUI:IntegrationEnabled("questie")
end

function M:OnEvent(_, name)
    if name == "OpenXP" then self:Attach() end
end
