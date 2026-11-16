local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")

local watched = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })

local function Public(value, kind)
    return type(value) == kind and not (issecretvalue and issecretvalue(value))
end

local function TooltipSkin()
    if not SUI:IntegrationEnabled("tooltip") then return end
    local eui, db = _G.EllesmereUI, _G.EllesmereUIDB
    if not (eui and type(eui.GetFontPath) == "function" and db and db.customTooltips ~= false
        and SUI:IsAddonLoaded("EllesmereUIBlizzardSkin")) then return end
    if eui.BlizzSkinPadStandDown and eui.BlizzSkinPadStandDown() then return end
    return eui, db
end

local function SameFont(path, expected)
    if not Public(path, "string") then return false end
    if path == expected then return true end
    return path:lower():gsub("/", "\\") == expected:lower():gsub("/", "\\")
end

local function FontWriter()
    local stack = debugstack and debugstack(2, 10, 0)
    if not Public(stack, "string") then return end
    for line in stack:gsub("\\", "/"):gmatch("[^\r\n]+") do
        local source = line:match("dOns/([^:\"%]]+%.lua)[\"%]]*:%d+")
            or line:match("/([^/:\"%]]+%.lua)[\"%]]*:%d+")
        if source and source ~= "TooltipFonts.lua" and not source:find("Sintezza_UI/", 1, true) then return source end
    end
end

local function Matches(state, path, size)
    return SameFont(path, state.path) and Public(size, "number") and size == state.size
end

local function ApplyLine(fs, state, eui)
    local current, currentSize = fs:GetFont()
    if Matches(state, current, currentSize) then return end
    if type(eui.SetFontFamily) == "function" then
        eui.SetFontFamily(fs, state.path, state.size, state.flags, false)
        current, currentSize = fs:GetFont()
    end
    if not Matches(state, current, currentSize) then fs:SetFont(state.path, state.size, state.flags) end
end

local function WatchTooltipLine(fs, state)
    local function Changed(path, size)
        if M.tooltipFontsApplying or not state.path or (fs.IsForbidden and fs:IsForbidden()) then return end
        if Matches(state, path, size) then return end
        local eui = TooltipSkin()
        if not eui then return end
        local source = FontWriter()
        if source then M.tooltipFontLastWriter = source end
        -- Mastercraft marks its lines before assigning Noto Sans and before
        -- restoring the pooled font object. Repair that write in the same
        -- tooltip pass, after its content has already been added.
        if fs.mcTip == state.tooltip or (source and source:lower():find("mastercraft/", 1, true)) then
            M.tooltipFontsApplying = true
            SUI:SafeModuleCall(M, "Mastercraft tooltip font", function() ApplyLine(fs, state, eui) end)
            M.tooltipFontsApplying = nil
        end
        M:QueueTooltipFontRefresh(state.tooltip)
    end
    hooksecurefunc(fs, "SetFont", function(_, path, size) Changed(path, size) end)
    if type(fs.SetFontObject) == "function" then
        hooksecurefunc(fs, "SetFontObject", function()
            if M.tooltipFontsApplying or (fs.IsForbidden and fs:IsForbidden()) then return end
            local ok, path, size = pcall(fs.GetFont, fs)
            if ok then Changed(path, size) end
        end)
    end
end

local function TrackLine(fs, tooltip, path, size, flags)
    if not fs or (fs.IsForbidden and fs:IsForbidden()) then return end
    local state = watched[fs]
    if not state then
        state = {}
        watched[fs] = state
        WatchTooltipLine(fs, state)
    end
    state.tooltip, state.path, state.size, state.flags = tooltip, path, size, flags
    return state
end

local function FontSettings(eui, db)
    local path = eui.GetFontPath("blizzardSkin")
    if not Public(path, "string") or path == "" then return end
    local flags = eui.GetFontOutlineFlag and eui.GetFontOutlineFlag("blizzardSkin") or ""
    local scale = tonumber(db.tooltipFontScale) or 1
    return path, flags, math.floor(11 * scale + .5), math.floor(13 * scale + .5)
end

local function TrackRow(tooltip, prefix, index, path, flags, body, title, eui, apply)
    local left, right = _G[prefix .. "Left" .. index], _G[prefix .. "Right" .. index]
    local ls = TrackLine(left, tooltip, path, index == 1 and title or body, flags)
    local rs = TrackLine(right, tooltip, path, body, flags)
    if apply then
        if ls then ApplyLine(left, ls, eui) end
        if rs then ApplyLine(right, rs, eui) end
    end
end

function M:RestoreTooltipFontLines(tooltip, eui, db)
    local path, flags, body, title = FontSettings(eui, db)
    local count = tooltip:NumLines()
    local name = hooked[tooltip]
    if not (name and path and Public(count, "number")) then return end
    local prefix = name .. "Text"
    for i = 1, count do TrackRow(tooltip, prefix, i, path, flags, body, title, eui, true) end
end

function M:QueueTooltipFontRefresh(tooltip)
    if not (tooltip and hooked[tooltip]) or pending[tooltip] or self.tooltipFontsApplying
        or not TooltipSkin() then return end
    pending[tooltip] = true
    SUI:After(0, self, "tooltip font refresh", function()
        pending[tooltip] = nil
        local eui, db = TooltipSkin()
        if not eui or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
        local shown = tooltip:IsShown()
        if not Public(shown, "boolean") or not shown then return end
        self.tooltipFontsApplying = true
        SUI:SafeModuleCall(self, "Ellesmere tooltip font", self.RestoreTooltipFontLines, tooltip, eui, db)
        self.tooltipFontsApplying = nil
    end)
end

function M:PrintTooltipFontStatus()
    local eui = TooltipSkin()
    if not eui then SUI:Print(SUI.Text("Шрифт подсказок Ellesmere сейчас не применяется.", "The Ellesmere tooltip font is inactive.")); return end
    local name = eui.GetFontName and eui.GetFontName("blizzardSkin") or eui.GetFontPath("blizzardSkin")
    SUI:Print(SUI.Text("Шрифт подсказок: ", "Tooltip font: ") .. (name or SUI.Text("не определен", "unknown")))
    SUI:Print(SUI.Text("Последняя обнаруженная замена: ", "Last detected override: ") .. (self.tooltipFontLastWriter or SUI.Text("пока не зафиксирована", "none detected")))
end

local PreviousInitialize = M.Initialize
function M:Initialize()
    if PreviousInitialize then PreviousInitialize(self) end
    if self.tooltipFontHooked or not hooksecurefunc or not SUI:IntegrationEnabled("tooltip") then return end
    self.tooltipFontHooked = true
    local function Queue(tt) self:QueueTooltipFontRefresh(tt) end
    local function TrackAddedRow(tt)
        local eui, db = TooltipSkin()
        local name = hooked[tt]
        if eui and name and not (tt.IsForbidden and tt:IsForbidden()) then
            local count = tt:NumLines()
            local path, flags, body, title = FontSettings(eui, db)
            if path and Public(count, "number") and count > 0 then
                TrackRow(tt, name .. "Text", count, path, flags, body, title, eui)
            end
        end
        Queue(tt)
    end
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tooltip = _G[name]
        if tooltip then
            hooked[tooltip] = name
            tooltip:HookScript("OnShow", Queue)
            for _, method in ipairs({ "AddLine", "AddDoubleLine", "SetText" }) do
                if type(tooltip[method]) == "function" then hooksecurefunc(tooltip, method, TrackAddedRow) end
            end
            if type(tooltip.Show) == "function" then hooksecurefunc(tooltip, "Show", Queue) end
        end
    end
    local processor, types = TooltipDataProcessor, Enum and Enum.TooltipDataType
    if processor and processor.AddTooltipPostCall and types then
        for _, kind in ipairs({ "Unit", "Item", "Spell" }) do
            if types[kind] then processor.AddTooltipPostCall(types[kind], Queue) end
        end
    end
end

