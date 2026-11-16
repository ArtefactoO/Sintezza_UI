local addon, SUI = ...
local T, Text = Sintezza_Theme, SUI.Text
local M = SUI:RegisterModule("combatFont", {})
local media = T.media
local custom = "Interface\\AddOns\\" .. addon .. "\\Media\\CombatFonts\\Custom\\"
local existing = "Interface\\AddOns\\FontMagicCustomFonts\\Custom\\"
local indexed = "Interface\\AddOns\\Sintezza_UI_LocalFonts\\Media\\"
local globals = { "DAMAGE_TEXT_FONT", "COMBAT_TEXT_FONT" }
local builtin = {
    { id = "DEFAULT", label = Text("Прежний шрифт", "Previous font"), source = "game" },
    { id = "FIRA", label = "Fira Sans Bold", path = media .. "FiraSans Bold.ttf", source = "bundled", digits = 10, russian = 66, latin = 52 },
    { id = "FIRA_MEDIUM", label = "Fira Sans Medium", path = media .. "FiraSans Medium.ttf", source = "bundled", digits = 10, russian = 66, latin = 52 },
    { id = "SPECTRAL", label = "Spectral Medium", path = media .. "Spectral-Medium.ttf", source = "bundled", digits = 10, russian = 66, latin = 52 },
    { id = "RUBIK", label = "Rubik Wet Paint", path = "Interface\\AddOns\\" .. addon .. "\\Media\\CombatFonts\\RubikWetPaint-Regular.ttf",
        source = "bundled", digits = 10, russian = 66, latin = 52 },
}
local stock = {
    { "FRIZQT__.TTF", "Friz Quadrata" }, { "FRIZQT___CYR.TTF", "Friz Quadrata Cyrillic" },
    { "ARIALN.TTF", "Arial Narrow" }, { "SKURRI.TTF", "Skurri" },
    { "SKURRI_CYR.TTF", "Skurri Cyrillic" }, { "MORPHEUS.TTF", "Morpheus" },
    { "MORPHEUS_CYR.TTF", "Morpheus Cyrillic" }, { "2002.TTF", "2002" },
    { "K_Pagetext.ttf", "K PageText" }, { "arhei.ttf", "Arhei" },
    { "arheiuhk_bd.ttf", "Arhei UHK Bold" }, { "ARKai_T.ttf", "AR Kai T" },
    { "ARKai_C.ttf", "AR Kai C" }, { "bhei00m.ttf", "Bhei" },
    { "bKAI00M.TTF", "Bkai" }, { "BLEI00D.TTF", "Blei" },
}

local function Public(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function FontPath(value)
    value = Public(value)
    if type(value) == "string" and value ~= "" then return value end
end

local function SamePath(left, right)
    if left == right then return true end
    return left and right and left:lower():gsub("/", "\\") == right:lower():gsub("/", "\\")
end

local function PathKey(path)
    return path:lower():gsub("/", "\\")
end

local function ReadFont(font)
    if not font or not font.GetFont then return end
    local ok, path, size, flags = pcall(font.GetFont, font)
    if not ok then return end
    path, size, flags = FontPath(path), Public(size), Public(flags)
    if path and type(size) == "number" and size > 0 then return path, size, flags or "" end
end

local function WriteFont(font, path, size, flags)
    if not font or type(font.SetFont) ~= "function" then return false end
    if not pcall(font.SetFont, font, path, size, flags) then return false end
    return SamePath(ReadFont(font), path) == true
end

local function SharedMedia()
    return LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)
end

function M:Profile()
    return SUI:GetModuleProfile("combatFont")
end

function M:OtherOwner()
    if SUI:IsAddonLoaded("FontMagic") then return "FontMagic" end
end

local function EllesmereOverridesFont()
    local settings = _G.EllesmereUIDB
    return SUI:IsAddonLoaded("EllesmereUI") and type(settings) == "table" and FontPath(settings.fctFont) ~= nil
end

function M:CanOverride()
    return not self:OtherOwner() and (FontPath(_G.DAMAGE_TEXT_FONT) ~= nil
        or FontPath(_G.COMBAT_TEXT_FONT) ~= nil or ReadFont(_G.CombatTextFont) ~= nil)
end

function M:Probe(path)
    if not path or InCombatLockdown() or not CreateFont then return false end
    self.probe = self.probe or CreateFont("Sintezza_UICombatFontProbe")
    return WriteFont(self.probe, path, 16, "")
end

local function CustomPath(id)
    local source, digits = id:match("^(%a+):(%d+)$")
    local index = tonumber(digits)
    if not index or index < 1 or index > 20 then return end
    if source == "CUSTOM" then return custom .. index .. ".ttf" end
    if source == "FONTMAGIC" then return existing .. index .. ".ttf" end
end

function M:CanonicalID(id)
    local slots = Sintezza_UI_IndexedCombatFontSlots
    local target = type(slots) == "table" and slots[id]
    return type(target) == "string" and target or id
end

function M:PathFor(id)
    id = self:CanonicalID(id)
    if type(id) ~= "string" then return end
    for _, font in ipairs(builtin) do if id == font.id then return font.path end end
    for _, font in ipairs(stock) do if id == "STOCK:" .. font[1] then return "Fonts\\" .. font[1] end end
    local hash = id:match("^LOCAL:([0-9a-f]+)$")
    if hash and #hash == 64 and type(Sintezza_UI_LocalCombatFonts) == "table" and Sintezza_UI_LocalCombatFonts[hash] then
        return indexed .. hash .. ".ttf"
    end
    local name = id:match("^LSM:(.+)$")
    local mediaLibrary = name and SharedMedia()
    if mediaLibrary then return FontPath(mediaLibrary:Fetch("font", name, true)) end
    return CustomPath(id)
end

function M:ListFonts()
    if not self.files and not InCombatLockdown() then
        local files = {}
        local function Offer(font)
            if self:Probe(font.path) then files[#files + 1] = font end
        end
        for _, font in ipairs(stock) do
            Offer({ id = "STOCK:" .. font[1], label = font[2], path = "Fonts\\" .. font[1], source = "game" })
        end
        local manifest = Sintezza_UI_LocalCombatFonts
        if type(manifest) == "table" then
            local fonts = {}
            for hash, meta in pairs(manifest) do
                if type(hash) == "string" and #hash == 64 and hash:match("^[0-9a-f]+$")
                    and type(meta) == "table" and type(meta.label) == "string" then
                    fonts[#fonts + 1] = { id = "LOCAL:" .. hash, label = meta.label, path = indexed .. hash .. ".ttf",
                        source = "custom", russian = meta.russian, latin = meta.latin, digits = meta.digits }
                end
            end
            table.sort(fonts, function(a, b) return a.label < b.label end)
            for _, font in ipairs(fonts) do Offer(font) end
        end
        local function AddSlots(source, name)
            for index = 1, 20 do
                local id = source .. ":" .. index
                local indexedSlots = Sintezza_UI_IndexedCombatFontSlots
                if type(indexedSlots) ~= "table" or not indexedSlots[id] then
                    Offer({ id = id, label = name .. " #" .. index, source = "custom", path = CustomPath(id) })
                end
            end
        end
        AddSlots("CUSTOM", Text("Свой шрифт", "Custom font"))
        AddSlots("FONTMAGIC", "FontMagic")
        self.files = files
    end
    local results, byPath = {}, {}
    local function Add(font)
        local key = font.path and PathKey(font.path)
        if key and byPath[key] then
            if self:CanonicalID(self:Profile().font) == font.id then
                local original = results[byPath[key]]
                font.digits, font.russian, font.latin = original.digits, original.russian, original.latin
                results[byPath[key]] = font
            end
            return
        end
        results[#results + 1] = font
        if key then byPath[key] = #results end
    end
    for _, font in ipairs(builtin) do Add(font) end
    for _, font in ipairs(self.files or {}) do Add(font) end
    local mediaLibrary = SharedMedia()
    for _, name in ipairs(mediaLibrary and mediaLibrary:List("font") or {}) do
        local id = "LSM:" .. name
        local path = self:PathFor(id)
        if path then Add({ id = id, label = name, path = path, source = "shared" }) end
    end
    return results
end

function M:NativeFont()
    return self.originals and (self.originals.DAMAGE_TEXT_FONT or self.originals.COMBAT_TEXT_FONT or self.originals.framePath)
        or FontPath(_G.DAMAGE_TEXT_FONT) or FontPath(_G.COMBAT_TEXT_FONT) or ReadFont(_G.CombatTextFont)
        or T.Theme:GetGameTextFont()
end

function M:Restore()
    local previous = self.originals
    if not previous then return false end
    for _, key in ipairs(globals) do
        if previous[key] and SamePath(FontPath(_G[key]), self.appliedPath) then _G[key] = previous[key] end
    end
    if previous.framePath and SamePath(ReadFont(previous.frame), self.appliedPath) then
        WriteFont(previous.frame, previous.framePath, previous.frameSize, previous.frameFlags)
    end
    self.originals, self.appliedPath = nil, nil
    return true
end

function M:ApplyToAlert(text, size, flags)
    return self.alertPath ~= nil and WriteFont(text, self.alertPath, size, flags)
end

function M:Apply(profile, startup)
    if InCombatLockdown() then self.pending = true; return "combat" end
    self.pending = nil
    profile = profile or self:Profile()
    local id = profile and profile.enabled and profile.font
    local path = id and self:PathFor(id)
    if path and not self:Probe(path) then path = nil end
    if not path and type(id) == "string" and self:CanonicalID(id) ~= id then
        local fallback = CustomPath(id)
        if self:Probe(fallback) then path = fallback end
    end
    self.alertPath = profile and profile.useInAlerts ~= false and path or nil
    if not path or not self:CanOverride() then
        local restored = self:Restore()
        if restored and not startup then T:RefreshAppearance() end
        if id and id ~= "DEFAULT" then
            if not path then return "missing" end
            if self:OtherOwner() then return "owner" end
            return "unsupported"
        end
        return restored and "restored" or "native"
    end

    if self.appliedPath ~= path then self:Restore() end
    local previous = self.originals or {}
    local applied = false
    for _, key in ipairs(globals) do
        local original = FontPath(_G[key])
        if original then
            if not SamePath(original, path) then
                previous[key] = original
                _G[key] = path
            end
            applied = true
        end
    end
    local native = _G.CombatTextFont
    local before, size, flags = ReadFont(native)
    if before then
        if SamePath(before, path) then
            applied = true
        elseif WriteFont(native, path, size, flags) then
            previous.frame, previous.framePath, previous.frameSize, previous.frameFlags = native, before, size, flags
            applied = true
        end
    end
    if applied then
        self.originals, self.appliedPath = previous, path
        if not startup then T:RefreshAppearance() end
    end
    return applied and "applied" or "unsupported"
end

function M:Update()
    local previous = self.alertPath
    self.status = self:Apply()
    if previous ~= self.alertPath and SUI.CombatAlert then
        SUI.CombatAlert:ApplyAppearance()
        SUI.CombatAlert:ApplyStealthAppearance()
    end
    SUI:RefreshModuleEvents()
end

function M:OnProfileChanged()
    self:Update()
end

function M:WantsEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then return self.pending end
    if event == "PLAYER_ENTERING_WORLD" and not self.firstWorld then return false end
    local profile = self:Profile()
    return profile and profile.enabled and profile.font ~= "DEFAULT"
end

function M:CheckLoginPriority()
    if self.priorityQueued or not self.appliedPath or not EllesmereOverridesFont()
        or not (C_Timer and C_Timer.After) then return end
    self.priorityQueued = true
    -- EllesmereUI also assigns the font during login. Check once after event dispatch.
    SUI:After(0, self, "combat font login priority", function()
        self.priorityQueued = nil
        local applied = self.appliedPath
        if not applied then return end
        local damage = FontPath(_G.DAMAGE_TEXT_FONT)
        local combat = FontPath(_G.COMBAT_TEXT_FONT)
        local text = ReadFont(_G.CombatTextFont)
        if (damage and not SamePath(damage, applied)) or (combat and not SamePath(combat, applied))
            or (text and not SamePath(text, applied)) then
            self:Update()
            if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
        end
    end)
end

function M:OnEvent(event, loaded)
    if event ~= "ADDON_LOADED" or loaded == "Blizzard_CombatText" or loaded == "FontMagic" or loaded == "EllesmereUI" then
        if event == "PLAYER_ENTERING_WORLD" then self.firstWorld = false end
        self:Update()
        if event ~= "PLAYER_REGEN_ENABLED" and loaded ~= "FontMagic" then self:CheckLoginPriority() end
        if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
    end
end

function M:Initialize()
    self.firstWorld = true
    SUI:RegisterModuleEvent(self, "ADDON_LOADED")
    SUI:RegisterModuleEvent(self, "PLAYER_LOGIN")
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    self:Update()
end

-- The client can cache the damage font before PLAYER_LOGIN.
local db = _G.Sintezza_UIDB
local profiles = type(db) == "table" and db.profiles
local saved = type(profiles) == "table" and profiles[db.activeProfile or "Default"]
local modules = type(saved) == "table" and saved.modules
local startupProfile = type(modules) == "table" and modules.combatFont
if type(startupProfile) == "table" and startupProfile.enabled then
    SUI:SafeModuleCall(M, "startup combat font", M.Apply, startupProfile, true)
end
