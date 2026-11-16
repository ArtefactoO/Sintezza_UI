local _, SUI = ...
local M = SUI:RegisterModule("chatWhisperErrors", { recent = {}, report = {} })
local WINDOW, MAX_TARGETS, MAX_REPORT = 12, 128, 8
local PREFIX_OWNER = {
    FGPeer = "ForeverGuide",
    FGL = "ForeverGuide",
    FlowUp = "FlowUp",
    OpenMapLoc = "OpenMap",
    ShortPath1 = "Shortest Path Forever",
}

local function Plain(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

local function Key(name)
    if not Plain(name) or name == "" or #name > 128 or name:find("[%c|]") then return end
    -- Forever can print a surname with a space after the send used a hyphen.
    return name:lower():gsub("[%s%-]+", " ")
end

local function NotFound(message, template)
    if not Plain(template) then return end
    local a, b = template:find("%1$s", 1, true)
    if not a then a, b = template:find("%s", 1, true) end
    if not a then return end
    local head, tail = template:sub(1, a - 1), template:sub(b + 1)
    if #message <= #head + #tail or message:sub(1, #head) ~= head then return end
    if tail ~= "" and message:sub(-#tail) ~= tail then return end
    return message:sub(#head + 1, #message - #tail)
end

function M:Remember(channel, target, prefix)
    if not self.enabled or not Plain(channel) or channel ~= "WHISPER" then return end
    local key = Key(target)
    if not key or (prefix ~= nil and not Key(prefix)) then return end
    local now, count = GetTime(), 0
    for name, entry in pairs(self.recent) do
        if now - entry.at > WINDOW then self.recent[name] = nil
        else count = count + 1 end
    end
    local entry = self.recent[key]
    if not entry then
        if count >= MAX_TARGETS then
            -- If tracking overflows, show errors until the ambiguous window ends.
            self.overflowAt = now
            return
        end
        entry = { addon = {} }
        self.recent[key] = entry
    end
    entry.at = now
    if prefix then
        for id, sentAt in pairs(entry.addon) do
            if now - sentAt > WINDOW then entry.addon[id] = nil end
        end
        entry.addon[prefix] = now
    else
        entry.manual = now
    end
end

function M:Filter(message)
    if not self.enabled or not Plain(message) then return false end
    local name = NotFound(message, ERR_CHAT_PLAYER_NOT_FOUND_S) or NotFound(message, ERR_CHAT_PLAYER_NOT_FOUND)
    local key = Key(name)
    local entry = key and self.recent[key]
    if not entry then return false end
    local now = GetTime()
    if now - entry.at > WINDOW or (entry.manual and now - entry.manual <= WINDOW)
        or (self.overflowAt and now - self.overflowAt <= WINDOW) then return false end

    local labels = {}
    for prefix, sentAt in pairs(entry.addon) do
        if now - sentAt <= WINDOW then
            local addon = PREFIX_OWNER[prefix]
            labels[#labels + 1] = addon and (addon .. " (" .. prefix .. ")") or prefix
        end
    end
    if #labels == 0 then return false end
    table.sort(labels)
    local source = table.concat(labels, " / ")
    local last = self.report[#self.report]
    if not last or last.name ~= name or last.source ~= source or now - last.at > 1 then
        if #self.report >= MAX_REPORT then table.remove(self.report, 1) end
        self.report[#self.report + 1] = { name = name, source = source, at = now }
    end
    return true
end

function M:InstallHooks()
    if self.hooked or type(hooksecurefunc) ~= "function" then return end
    local function Addon(prefix, _, channel, target)
        if Plain(prefix) and prefix ~= "" then self:Remember(channel, target, prefix) end
    end
    local function Manual(_, channel, _, target)
        self:Remember(channel, target)
    end
    local chat = C_ChatInfo
    if chat and type(chat.SendAddonMessage) == "function" then
        hooksecurefunc(chat, "SendAddonMessage", Addon)
    elseif type(_G.SendAddonMessage) == "function" then
        hooksecurefunc("SendAddonMessage", Addon)
    else
        return
    end
    if chat and type(chat.SendAddonMessageLogged) == "function" then
        hooksecurefunc(chat, "SendAddonMessageLogged", Addon)
    end
    if chat and type(chat.SendChatMessage) == "function" then
        hooksecurefunc(chat, "SendChatMessage", Manual)
    end
    if type(_G.SendChatMessage) == "function" then
        hooksecurefunc("SendChatMessage", Manual)
    end
    self.hooked = true
end

function M:OnProfileChanged()
    local profile = SUI:GetModuleProfile(self.key)
    self.enabled = SUI.isForever and profile and profile.enabled == true
    if not self.enabled then
        wipe(self.recent)
        self.overflowAt = nil
        return
    end
    self:InstallHooks()
    local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if self.hooked and add and not self.installedFilter then
        add("CHAT_MSG_SYSTEM", function(_, _, message) return self:Filter(message) end)
        self.installedFilter = true
    end
end

function M:Initialize()
    self:OnProfileChanged()
    SUI:RegisterModuleEvent(self, "PLAYER_LOGIN")
end

function M:WantsEvent()
    return self.enabled and not self.installedFilter
end

function M:OnEvent()
    self:OnProfileChanged()
    if self.installedFilter then SUI:RefreshModuleEvents() end
end

function M:PrintStatus()
    if not self.installedFilter then
        SUI:Print(SUI.Text("Журнал ошибок служебных сообщений недоступен.", "The addon whisper error log is unavailable."))
    elseif #self.report == 0 then
        SUI:Print(SUI.Text("Служебных сообщений в журнале пока нет.", "The addon whisper log is empty."))
    else
        for _, entry in ipairs(self.report) do
            SUI:Print(entry.name .. " — " .. entry.source)
        end
    end
end
