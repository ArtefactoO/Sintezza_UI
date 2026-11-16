local _, SUI = ...

local C = {}
SUI.TeleportPromptCatalog = C

-- Current Midnight season portal catalog. Spell IDs are static trusted
-- integers; LFG-derived values are used only to select one of these entries.
local PORTALS = {
    { spellID = 1286801, dungeonID = 3102, name = "The Blinding Vale", aliases = { "the blinding vale", "blinding vale", "слепящая долина" } },
    { spellID = 1286804, dungeonID = 3106, name = "Voidscar Arena", aliases = { "voidscar arena", "арена шрама бездны" } },
    { spellID = 1286807, dungeonID = 3051, name = "Den of Nalorakk", aliases = { "den of nalorakk", "den of nalorak", "берлога налоракка" } },
    { spellID = 1286809, dungeonID = 3090, name = "Murder Row", aliases = { "murder row", "закоулок душегубов" } },
    { spellID = 1286812, dungeonID = 3191, name = "Altar of Fangs", aliases = { "altar of fangs", "алтарь клыков" } },
    { spellID = 393256, dungeonID = 2361, name = "Ruby Life Pools", aliases = { "ruby life pools", "рубиновые омуты жизни" } },
    { spellID = 1286828, dungeonID = 1694, name = "Temple of Sethraliss", aliases = { "temple of sethraliss", "храм сетралисс" } },
    { spellID = 1286831, dungeonID = 1785, name = "Kings' Rest", aliases = { "kings' rest", "king's rest", "гробница королей" } },
}

local byName = {}

local function Normalize(value)
    if type(value) ~= "string" then return nil end
    value = value:lower():gsub("’", "'"):gsub("%s*%b()%s*$", "")
    value = value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return value ~= "" and value or nil
end

local function AddName(entry, value)
    local key = Normalize(value)
    if key then byName[key] = entry end
end

function C:Initialize()
    if self.initialized then return end
    self.initialized = true
    for _, entry in ipairs(PORTALS) do
        AddName(entry, entry.name)
        for _, alias in ipairs(entry.aliases or {}) do AddName(entry, alias) end
        if GetLFGDungeonInfo and entry.dungeonID then
            local ok, localizedName = pcall(GetLFGDungeonInfo, entry.dungeonID)
            if ok then AddName(entry, localizedName) end
        end
    end
end

function C:Resolve(displayName)
    self:Initialize()
    local key = Normalize(displayName)
    return key and byName[key] or nil
end

function C:First()
    return PORTALS[1]
end

function C:Entries()
    return PORTALS
end
