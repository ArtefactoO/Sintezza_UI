local _, SUI = ...
local Text = SUI.Text
local SGB = SUI.GameBar
local T = SUI.Theme
local lastGuildRequest

local ROLE_LABELS = {
    TANK = Text("ТАНК", "TANK"),
    HEALER = Text("ЛЕК", "HEAL"),
    DAMAGER = Text("ДД", "DPS"),
}

local function requestGuildRoster()
    local now = GetTime and GetTime() or 0
    if lastGuildRequest and now - lastGuildRequest < 5 then return end
    lastGuildRequest = now
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        pcall(C_GuildInfo.GuildRoster)
    elseif GuildRoster then
        pcall(GuildRoster)
    end
end

local function miniTooltipProfile()
    local profile = SGB.profile
    local mini = profile and profile.miniBar
    local tooltip = type(mini) == "table" and mini.tooltip
    return type(tooltip) == "table" and tooltip or {}
end

local function shortName(name)
    if type(name) ~= "string" or name == "" then return "?" end
    if Ambiguate then return Ambiguate(name, "short") end
    return name:match("^[^-]+") or name
end

local function splitName(name, explicitRealm)
    if type(name) ~= "string" then return "?", explicitRealm end
    local base, realm = name:match("^([^-]+)%-(.+)$")
    return base or name, explicitRealm or realm
end

local function realmKey(realm)
    if type(realm) ~= "string" or realm == "" then return nil end
    return realm:lower():gsub("[%s%-']", ""):gsub("’", "")
end

local function nameKey(name, realm)
    if type(name) ~= "string" or name == "" then return nil end
    local base, parsedRealm = splitName(name, realm)
    local full = base
    local normalizedRealm = realmKey(parsedRealm)
    if normalizedRealm then full = full .. "-" .. normalizedRealm end
    return full:lower():gsub("%s+", "")
end

local function classColor(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return color and color.r or .9, color and color.g or .9, color and color.b or .9
end

local function friendClass(info)
    if info.guid and GetPlayerInfoByGUID then
        local ok, _, classFile = pcall(GetPlayerInfoByGUID, info.guid)
        if ok then return classFile end
    end
end

local function groupContext()
    local context = {
        names = {},
        zone = type(GetZoneText) == "function" and GetZoneText() or nil,
    }
    local function addUnit(unit)
        if UnitExists and not UnitExists(unit) then return end
        local name, realm
        if UnitFullName then
            local ok, n, r = pcall(UnitFullName, unit)
            if ok then name, realm = n, r end
        elseif UnitName then
            local ok, n = pcall(UnitName, unit)
            if ok then name = n end
        end
        local key = nameKey(name, realm)
        if not key then return end
        local role
        if UnitGroupRolesAssigned then
            local ok, value = pcall(UnitGroupRolesAssigned, unit)
            if ok and value ~= "NONE" then role = value end
        end
        context.names[key] = role or true
        local shortKey = nameKey(name)
        if shortKey and not context.names[shortKey] then context.names[shortKey] = role or true end
    end

    if IsInRaid and IsInRaid() then
        local total = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, total do addUnit("raid" .. index) end
    elseif IsInGroup and IsInGroup() then
        addUnit("player")
        local total = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for index = 1, total do addUnit("party" .. index) end
    else
        addUnit("player")
    end
    return context
end

local function applyContext(row, context)
    local key = nameKey(row.name, row.realm)
    local shortKey = nameKey(row.name)
    local groupValue = key and context.names[key] or (shortKey and context.names[shortKey])
    row.inGroup = groupValue ~= nil
    row.role = type(groupValue) == "string" and groupValue or nil
    row.sameZone = type(row.zone) == "string" and row.zone ~= "" and row.zone == context.zone
end

local function addUnique(rows, seen, row)
    local key = nameKey(row.name, row.realm)
    if not key or seen[key] then return end
    seen[key] = true
    rows[#rows + 1] = row
end

local function collectFriends()
    local rows, seen = {}, {}
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local okTotal, total = pcall(C_FriendList.GetNumFriends)
        total = okTotal and tonumber(total) or 0
        for index = 1, total do
            local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, index)
            if ok and type(info) == "table" and info.connected then
                local name, realm = splitName(info.name)
                addUnique(rows, seen, {
                    name = name,
                    realm = realm,
                    level = info.level,
                    zone = info.area,
                    classFile = friendClass(info),
                    afk = info.afk == true,
                    dnd = info.dnd == true,
                })
            end
        end
    end

    local totalBN = BNGetNumFriends and BNGetNumFriends() or 0
    if type(totalBN) ~= "number" then totalBN = 0 end
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        for index = 1, totalBN do
            local okAccount, account = pcall(C_BattleNet.GetFriendAccountInfo, index)
            if okAccount and type(account) == "table" then
                local gameAccounts = {}
                local gameCount = 0
                if C_BattleNet.GetFriendNumGameAccounts then
                    local okCount, count = pcall(C_BattleNet.GetFriendNumGameAccounts, index)
                    gameCount = okCount and tonumber(count) or 0
                end
                if gameCount > 0 and C_BattleNet.GetFriendGameAccountInfo then
                    for gameIndex = 1, gameCount do
                        local okGame, info = pcall(C_BattleNet.GetFriendGameAccountInfo, index, gameIndex)
                        if okGame and type(info) == "table" then gameAccounts[#gameAccounts + 1] = info end
                    end
                elseif type(account.gameAccountInfo) == "table" then
                    gameAccounts[1] = account.gameAccountInfo
                end
                for _, info in ipairs(gameAccounts) do
                    if info.isOnline and info.clientProgram == "WoW" then
                        local classFile
                        if info.classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
                            local okClass, classInfo = pcall(C_CreatureInfo.GetClassInfo, info.classID)
                            classFile = okClass and classInfo and classInfo.classFile
                        end
                        addUnique(rows, seen, {
                            name = info.characterName or account.accountName or "?",
                            realm = info.realmName,
                            level = info.characterLevel,
                            zone = info.areaName,
                            classFile = classFile,
                            afk = account.isAFK == true,
                            dnd = account.isDND == true,
                        })
                    end
                end
            end
        end
    end
    return rows
end

local function collectGuild()
    local rows = {}
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return rows end
    local total = GetNumGuildMembers() or 0
    for index = 1, total do
        local ok, name, _, _, level, _, zone, _, _, online, status, classFile, _, _, isMobile =
            pcall(GetGuildRosterInfo, index)
        if ok and name and online and not isMobile then
            local base, realm = splitName(name)
            rows[#rows + 1] = {
                name = base,
                realm = realm,

                level = level,
                zone = zone,
                classFile = classFile,
                afk = status == 1,
                dnd = status == 2,
            }
        end
    end
    return rows
end

local function sortRows(rows)
    table.sort(rows, function(a, b)
        local aName = type(a.name) == "string" and a.name:lower() or ""
        local bName = type(b.name) == "string" and b.name:lower() or ""
        return aName < bName
    end)
end

local function playerText(row, profile, currentRealm)
    local name = shortName(row.name)
    local rowRealm = realmKey(row.realm)
    if profile.showRealm ~= false and rowRealm and rowRealm ~= currentRealm then
        name = name .. "-" .. row.realm
    end
    if profile.showGroupRole ~= false and row.role and ROLE_LABELS[row.role] then
        name = "[" .. ROLE_LABELS[row.role] .. "] " .. name
    end
    if row.afk then name = name .. Text("  АФК", "  AFK")
    elseif row.dnd then name = name .. Text("  Занят", "  DND") end

    local level = type(row.level) == "number" and tostring(row.level) or "—"
    local zone = type(row.zone) == "string" and row.zone ~= "" and row.zone or "—"
    return name, level, zone
end

local function buildLines(title, rows)
    local profile = miniTooltipProfile()
    local context = groupContext()
    local currentRealm
    if type(GetNormalizedRealmName) == "function" then
        local ok, realm = pcall(GetNormalizedRealmName)
        if ok then currentRealm = realmKey(realm) end
    end
    if not currentRealm and type(GetRealmName) == "function" then
        local ok, realm = pcall(GetRealmName)
        if ok then currentRealm = realmKey(realm) end
    end
    local groupRows, zoneRows, otherRows = {}, {}, {}
    local groupCount, zoneCount, afkCount = 0, 0, 0

    for _, row in ipairs(rows) do
        applyContext(row, context)
        if row.inGroup then groupCount = groupCount + 1 end
        if row.sameZone then zoneCount = zoneCount + 1 end
        if row.afk or row.dnd then afkCount = afkCount + 1 end
        if profile.groupByContext ~= false and row.inGroup then
            groupRows[#groupRows + 1] = row
        elseif profile.groupByContext ~= false and row.sameZone then
            zoneRows[#zoneRows + 1] = row
        else
            otherRows[#otherRows + 1] = row
        end
    end
    sortRows(groupRows)
    sortRows(zoneRows)
    sortRows(otherRows)

    local lines = {
        { kind = "header", left = title, right = tostring(#rows) },
    }
    if #rows == 0 then
        lines[#lines + 1] = { kind = "empty", left = Text("Никого нет в сети.", "No one is online.") }
        return lines
    end

    local maximum = math.max(5, math.min(50, tonumber(profile.maxRows) or 24))
    local shown, omitted = 0, 0
    local hadPriority = #groupRows > 0 or #zoneRows > 0
    local sections
    if profile.groupByContext ~= false then
        sections = {
            { title = Text("В моей группе", "In my group"), rows = groupRows },
            { title = Text("В моей зоне", "In my zone"), rows = zoneRows },
            { title = hadPriority and Text("Остальные", "Others") or nil, rows = otherRows },
        }
    else
        local all = {}
        for _, row in ipairs(rows) do all[#all + 1] = row end
        sortRows(all)
        sections = { { rows = all } }
    end

    for _, section in ipairs(sections) do
        if #section.rows > 0 then
            if section.title then
                lines[#lines + 1] = { kind = "section", left = section.title, right = tostring(#section.rows) }
            end
            for _, row in ipairs(section.rows) do
                if shown < maximum then
                    local left, level, zone = playerText(row, profile, currentRealm)
                    local r, g, b = classColor(row.classFile)
                    lines[#lines + 1] = {
                        kind = "player",
                        left = left,
                        level = level,
                        zone = zone,
                        color = { r, g, b },
                        inGroup = row.inGroup,
                        sameZone = row.sameZone,
                    }
                    shown = shown + 1
                else
                    omitted = omitted + 1
                end
            end
        end
    end
    if omitted > 0 then
        lines[#lines + 1] = { kind = "more", left = Text("…и еще ", "…and ") .. omitted }
    end
    lines[#lines + 1] = {
        kind = "summary",
        left = Text("В группе: %d   •   В твоей зоне: %d   •   АФК / занят: %d", "In group: %d   •   In your zone: %d   •   AFK/DND: %d"):format(groupCount, zoneCount, afkCount),
    }
    return lines
end

local function acquireLine(frame, index)
    local line = frame.lines[index]
    if line then return line end
    line = CreateFrame("Frame", nil, frame)
    line.background = line:CreateTexture(nil, "BACKGROUND")
    line.background:SetAllPoints()
    line.left = line:CreateFontString(nil, "OVERLAY")
    line.left:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.left:SetPoint("RIGHT", line, "CENTER", -5, 0)
    line.left:SetJustifyH("LEFT")
    line.left:SetWordWrap(false)
    line.right = line:CreateFontString(nil, "OVERLAY")
    line.right:SetPoint("LEFT", line, "CENTER", 5, 0)
    line.right:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    line.right:SetJustifyH("RIGHT")
    line.right:SetWordWrap(false)
    line.level = line:CreateFontString(nil, "OVERLAY")
    line.level:SetJustifyH("RIGHT")
    line.level:SetWordWrap(false)
    line.zone = line:CreateFontString(nil, "OVERLAY")
    line.zone:SetJustifyH("LEFT")
    line.zone:SetWordWrap(false)
    frame.lines[index] = line
    return line
end

local function createSocialTooltip()
    if SGB.socialTooltip then return SGB.socialTooltip end
    local frame = SGB:CreateSegment(UIParent, "Sintezza_GameBarSocialTooltip")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1000)
    frame.glowBorder:SetFrameLevel(1001)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame.lines = {}
    frame:Hide()
    SGB.socialTooltip = frame
    return frame
end

local function showSocialTooltip(owner, title, rows)
    local frame = createSocialTooltip()
    local profile = miniTooltipProfile()
    local font = SGB:GetFont(profile.font)
    local flags = SGB:GetFontFlags(profile.outline, "OUTLINE")
    local fontSize = math.max(8, math.min(16, tonumber(profile.fontSize) or 10))
    local width = math.max(280, math.min(600, tonumber(profile.width) or 390))
    local padding = math.max(4, math.min(24, tonumber(profile.padding) or 10))
    local spacing = math.max(0, math.min(12, tonumber(profile.rowSpacing) or 2))
    local lines = buildLines(title, rows)
    local y = padding
    local innerWidth = width - padding * 2
    local nameWidth = math.floor(innerWidth * .47)
    local levelWidth = math.max(30, math.floor(fontSize * 3.4))
    local columnGap = math.max(5, math.floor(fontSize * .7))

    SGB:ApplySegmentStyle(frame, profile)
    for index, data in ipairs(lines) do
        local line = acquireLine(frame, index)
        local size = data.kind == "header" and fontSize + 2 or fontSize
        local height = size + (data.kind == "header" and 7 or 4)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -y)
        line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padding, -y)
        line:SetHeight(height)
        line.left:SetFont(font, size, flags)
        line.right:SetFont(font, size, flags)
        line.level:SetFont(font, size, flags)
        line.zone:SetFont(font, size, flags)
        line.left:SetText(data.left or "")
        line.right:SetText(data.right or "")
        line.level:SetText(data.level or "")
        line.zone:SetText(data.zone or "")
        line.background:SetColorTexture(0, 0, 0, 0)

        if data.kind == "header" then
            line.left:SetTextColor(.32, .82, 1, 1)
            line.right:SetTextColor(.32, .82, 1, 1)
            line.background:SetColorTexture(.04, .10, .12, .72)
        elseif data.kind == "section" then
            line.left:SetTextColor(.62, .76, .80, 1)
            line.right:SetTextColor(.62, .76, .80, 1)
        elseif data.kind == "player" then
            local color = data.color or { .9, .9, .9 }
            line.left:SetTextColor(color[1], color[2], color[3], 1)
            line.level:SetTextColor(.76, .76, .76, 1)
            line.zone:SetTextColor(.76, .76, .76, 1)
            if data.inGroup then
                line.background:SetColorTexture(.05, .30, .26, .28)
            elseif data.sameZone then
                line.background:SetColorTexture(.08, .15, .18, .22)
            end
        elseif data.kind == "summary" then
            line.left:SetTextColor(.58, .64, .67, 1)
            line.right:SetText("")
        else
            line.left:SetTextColor(.58, .58, .58, 1)
            line.right:SetTextColor(.58, .58, .58, 1)
        end

        line.left:ClearAllPoints()
        if data.kind == "player" then
            line.left:SetPoint("LEFT", line, "LEFT", 0, 0)
            line.left:SetWidth(nameWidth)
            line.level:ClearAllPoints()
            line.level:SetPoint("LEFT", line, "LEFT", nameWidth + columnGap, 0)
            line.level:SetWidth(levelWidth)
            line.zone:ClearAllPoints()
            line.zone:SetPoint("LEFT", line.level, "RIGHT", columnGap, 0)
            line.zone:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            line.right:SetText("")
        elseif data.kind == "summary" then
            line.left:SetPoint("LEFT", line, "LEFT", 0, 0)
            line.left:SetPoint("RIGHT", line, "RIGHT", 0, 0)
        else
            line.left:SetPoint("LEFT", line, "LEFT", 0, 0)
            line.left:SetPoint("RIGHT", line, "CENTER", -5, 0)
        end
        line:Show()
        y = y + height + spacing
    end
    for index = #lines + 1, #frame.lines do frame.lines[index]:Hide() end

    frame:SetSize(width, math.max(28, y - spacing + padding))
    frame.owner = owner
    frame.kind = owner and owner.entryID
    frame:ClearAllPoints()
    frame:SetPoint("TOP", owner, "BOTTOM", 0, -6)
    frame:Show()
    SGB.activeSocialTooltipOwner = owner
end

function SGB:ShowTooltip(button)
    if not button or not button.entry then return end
    if button.entryID == "FRIENDS" then
        if GameTooltip then GameTooltip:Hide() end
        showSocialTooltip(button, Text("Друзья в игре", "Friends online"), collectFriends())
    elseif button.entryID == "GUILD" then
        requestGuildRoster()
        if GameTooltip then GameTooltip:Hide() end
        showSocialTooltip(button, Text("Гильдия в игре", "Guild members online"), collectGuild())
    end
end

function SGB:RefreshActiveTooltip()
    local owner = self.activeSocialTooltipOwner
    if not owner or not owner.IsMouseOver or not owner:IsMouseOver() then return end
    self:ShowTooltip(owner)
end

function SGB:HideTooltip()
    self.activeSocialTooltipOwner = nil
    if self.socialTooltip then
        self.socialTooltip.owner = nil
        self.socialTooltip:Hide()
    end
    if GameTooltip then GameTooltip:Hide() end
end
