local ADDON, SUI = ...
local Text = SUI.Text
local SGB = SUI.GameBar
local G = _G
local ICON_PATH = Sintezza_Theme.icons.GameBar
local function guarded(label, fn)
    return function(...)
        if SGB:InCombat() then SGB:Error(Text("Недоступно в бою: %s", "Unavailable in combat: %s"):format(label)); return end
        local ok = SGB:SafeCall(fn, ...)
        if not ok then SGB:Error(Text("Недоступно: %s", "Unavailable: %s"):format(label)) end
    end
end
local function clickGlobal(name)
    return function()
        local button = G[name]
        if button and button.Click then button:Click() else SGB:Error(Text("Окно Blizzard не загружено или недоступно.", "Blizzard’s window is unavailable.")) end
    end
end
local function toggleCollections(tab)
    return guarded(Text("Коллекции", "Collections"), function()
        SGB:LoadBlizzardAddon("Blizzard_Collections")
        if G.CollectionsMicroButton then G.CollectionsMicroButton:Click() end
        if G.CollectionsJournal_SetTab then G.CollectionsJournal_SetTab(tab) end
    end)
end

SGB.ButtonRegistry = {
    CHARACTER = { label = Text("Персонаж", "Character"), icon = ICON_PATH .. "Character.tga", secure = true, click = guarded(Text("Окно персонажа", "Character window"), function() ToggleCharacter("PaperDollFrame") end) },
    SPELLBOOK = { label = Text("Книга заклинаний", "Spellbook"), icon = ICON_PATH .. "SpellBook.tga", secure = true, click = guarded(Text("Книга заклинаний", "Spellbook"), function()
        local open = G.PlayerSpellsUtil and G.PlayerSpellsUtil.ToggleSpellBookFrame
        if type(open) == "function" then open(); return true end
        local micro = G.SpellbookMicroButton or G.PlayerSpellsMicroButton
        if micro and micro.Click then micro:Click(); return true end
        return false
    end) },
    TALENTS = { label = Text("Таланты", "Talents"), icon = ICON_PATH .. "Talents-v2.tga", secure = true, click = guarded(Text("Таланты", "Talents"), function() return SUI:OpenTalents() end) },
    FRIENDS = { label = Text("Друзья", "Friends"), icon = ICON_PATH .. "Friends.tga", click = guarded(Text("Друзья", "Friends"), function() if G.ToggleFriendsFrame then G.ToggleFriendsFrame() else SGB:LoadBlizzardAddon("Blizzard_Communities"); if G.ToggleFriendsFrame then G.ToggleFriendsFrame() elseif G.FriendsFrame and G.ShowUIPanel then G.ShowUIPanel(G.FriendsFrame) else SGB:Error(Text("Окно друзей недоступно.", "The Friends window is unavailable.")) end end end), badge = "friends", events = { "FRIENDLIST_UPDATE" } },
    GUILD = { label = Text("Гильдия", "Guild"), icon = ICON_PATH .. "Guild.tga", secure = true, click = guarded(Text("Гильдия", "Guild"), function() if G.GuildMicroButton then G.GuildMicroButton:Click() elseif ToggleGuildFrame then ToggleGuildFrame() end end), badge = "guild", events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" } },
    GROUP_FINDER = { label = Text("Поиск группы", "Group Finder"), icon = ICON_PATH .. "GroupFinder-v2.tga", click = clickGlobal("LFDMicroButton") },
    PROFESSION = { label = Text("Профессии", "Professions"), icon = ICON_PATH .. "Profession.tga", secure = true, click = guarded(Text("Профессии", "Professions"), function() if ToggleProfessionsBook then ToggleProfessionsBook() else SGB:LoadBlizzardAddon("Blizzard_TradeSkillUI") end end) },
    GAMEMENU = { label = Text("Меню игры", "Game Menu"), icon = ICON_PATH .. "GameMenu.tga", secure = true, click = guarded(Text("Меню игры", "Game Menu"), function()
        local menu = G.GameMenuFrame
        if not menu then return end
        -- ToggleGameMenu dispatches the Escape handlers, including protected
        -- spell-cast cancellation. This button only opens or closes the menu.
        if menu:IsShown() then
            if G.GameMenuFrame_EscapePressed then G.GameMenuFrame_EscapePressed()
            elseif G.HideUIPanel then G.HideUIPanel(menu) end
        elseif not (G.AreAllPanelsDisallowed and G.AreAllPanelsDisallowed()) then
            if G.GameMenuFrame_Show then G.GameMenuFrame_Show()
            elseif G.ShowUIPanel then G.ShowUIPanel(menu) end
        end
    end) },
    HOME = { label = Text("Дом", "Housing"), icon = ICON_PATH .. "Home.tga", secure = true, help = Text("ЛКМ - телепорт домой.\nПКМ - открыть панель Housing.", "Left-click: teleport home.\nRight-click: Housing Dashboard."), unavailable = function() return not ((G.C_Housing and G.C_Housing.GetPlayerOwnedHouses) or G.HousingFramesUtil) end,
        click = function(button, mouse)
            if mouse == "RightButton" then
                if SGB:InCombat() then SGB:Error(Text("Housing Dashboard недоступен в бою.", "Housing Dashboard is unavailable in combat.")); return end
                if G.HousingFramesUtil and G.HousingFramesUtil.ToggleHousingDashboard then
                    SGB:SafeCall(G.HousingFramesUtil.ToggleHousingDashboard)
                else
                    SGB:Error(Text("Housing Dashboard недоступен.", "Housing Dashboard is unavailable."))
                end
            elseif mouse == "LeftButton" and not button:GetAttribute("house-guid") then
                if SGB:InCombat() then
                    SGB:Error(Text("Данные дома нельзя обновить в бою.", "Housing data cannot update in combat."))
                else
                    SGB:Error(Text("Данные дома пока недоступны.", "Housing data is unavailable."))
                    SGB:RequestHousingData()
                end
            end
        end },
    ACHIEVEMENTS = { label = Text("Достижения", "Achievements"), icon = ICON_PATH .. "Achievements.tga", click = guarded(Text("Достижения", "Achievements"), function() SGB:LoadBlizzardAddon("Blizzard_AchievementUI"); if ToggleAchievementFrame then ToggleAchievementFrame() elseif G.AchievementMicroButton then G.AchievementMicroButton:Click() end end) },
    ENCOUNTER_JOURNAL = { label = Text("Путеводитель", "Adventure Guide"), icon = ICON_PATH .. "EncounterJournal.tga", help = Text("ПКМ - еженедельные награды.", "Right-click: Great Vault."), click = function(_, mouse) if mouse == "RightButton" then if WeeklyRewards_ShowUI then SGB:SafeCall(WeeklyRewards_ShowUI) else SGB:Error(Text("Еженедельные награды недоступны.", "The Great Vault is unavailable.")) end else SGB:LoadBlizzardAddon("Blizzard_EncounterJournal"); if G.EJMicroButton then G.EJMicroButton:Click() else SGB:Error(Text("Путеводитель недоступен.", "The Adventure Guide is unavailable.")) end end end },
    COLLECTIONS = { label = Text("Коллекции", "Collections"), icon = ICON_PATH .. "Collections.tga", help = Text("ПКМ - призвать случайного избранного маунта.", "Right-click: summon a random favorite mount."), click = function(_, mouse) if mouse == "RightButton" then if C_MountJournal and C_MountJournal.SummonByID then SGB:SafeCall(C_MountJournal.SummonByID, 0) else SGB:Error(Text("Журнал маунтов недоступен.", "The Mount Journal is unavailable.")) end else toggleCollections(1)() end end },
    BLIZZARD_SHOP = { label = Text("Магазин Blizzard", "Blizzard Shop"), icon = ICON_PATH .. "BlizzardShop.tga", unavailable = function() return not G.StoreMicroButton end, secureClick = "StoreMicroButton" },
    BAGS = { label = Text("Сумки", "Bags"), icon = ICON_PATH .. "Bags.tga", click = function() if ToggleAllBags then ToggleAllBags() else SGB:Error(Text("Сумки недоступны.", "Bags are unavailable.")) end end },
}

if SUI.isForever then
    -- CharacterFrame's OnShow reads the player's protected health text in Forever.
    local character = SGB.ButtonRegistry.CHARACTER
    character.secureClick = "CharacterMicroButton"
    character.combatSecureClick = "CharacterMicroButton"
    character.click = nil

    local talents = SGB.ButtonRegistry.TALENTS
    talents.secureClick = { "EUI_TalentsRoute", "TalentMicroButton" }
    talents.click = nil

    local spellbook = SGB.ButtonRegistry.SPELLBOOK
    spellbook.secureClick = { "EUI_SpellbookRoute", "SpellbookMicroButton" }
    spellbook.click = nil

    SGB.ButtonRegistry.FRIENDS.combatSecureClick = "QuickJoinToastButton"
    SGB.ButtonRegistry.GUILD.combatSecureClick = "GuildMicroButton"
    SGB.ButtonRegistry.BAGS.combatSecureClick = "MainMenuBarBackpackButton"

    local legacy = SGB.ButtonRegistry.ACHIEVEMENTS
    legacy.label = Text("Наследие", "Legacy")
    legacy.click = guarded(Text("Наследие", "Legacy"), function()
        if type(G.ToggleLegacySystemUI) == "function" then G.ToggleLegacySystemUI(); return true end
        local micro = G.LegacyMicroButton
        if micro and micro.Click then micro:Click(); return true end
        return false
    end)
end

function SGB:GetButtonEntry(id) return self.ButtonRegistry[id] end
local foreverUnavailable = { HOME = true, ENCOUNTER_JOURNAL = true }
function SGB:IsButtonAvailable(id)
    return self.ButtonRegistry[id] ~= nil and not (SUI.isForever and foreverUnavailable[id])
end
function SGB:GetButtonChoices()
    local choices = { NONE = Text("(Пустой слот)", "(Empty slot)") }
    for id, entry in pairs(self.ButtonRegistry) do
        if self:IsButtonAvailable(id) then choices[id] = entry.label end
    end
    return choices
end
local function safeNumber(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and type(value) == "number" then return value end
    return nil
end

function SGB:RequestFriendList()
    if C_FriendList and C_FriendList.ShowFriends then
        return pcall(C_FriendList.ShowFriends)
    elseif type(ShowFriends) == "function" then
        return pcall(ShowFriends)
    end
    return false
end

-- Blizzard's Friends window combines realm friends with Battle.net friends.
-- The original badge only counted C_FriendList, so a Battle.net friend playing
-- WoW appeared in the window but never contributed to the badge.
function SGB:GetFriendCount()
    local online = 0
    local seenCharacters = {}

    local function addCharacter(name, realm)
        if type(name) ~= 'string' or name == '' then return false end
        local full = name
        if type(realm) == 'string' and realm ~= '' and not name:find('-', 1, true) then
            full = name .. '-' .. realm
        end
        local key = full:lower():gsub('%s+', '')
        if seenCharacters[key] then return false end
        seenCharacters[key] = true
        online = online + 1
        return true
    end

    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local total = safeNumber(C_FriendList.GetNumFriends) or 0
        for index = 1, total do
            local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, index)
            if ok and type(info) == 'table' and info.connected then addCharacter(info.name) end
        end
    end

    local totalBN = safeNumber(BNGetNumFriends) or 0
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        for index = 1, totalBN do
            local ok, account = pcall(C_BattleNet.GetFriendAccountInfo, index)
            if ok and type(account) == 'table' then
                local wowInfo
                local gameCount = C_BattleNet.GetFriendNumGameAccounts
                    and safeNumber(C_BattleNet.GetFriendNumGameAccounts, index) or 0
                if gameCount > 0 and C_BattleNet.GetFriendGameAccountInfo then
                    for gameIndex = 1, gameCount do
                        local okGame, info = pcall(C_BattleNet.GetFriendGameAccountInfo, index, gameIndex)
                        if okGame and type(info) == 'table' and info.isOnline and info.clientProgram == 'WoW' then
                            wowInfo = info
                            break
                        end
                    end
                else
                    local info = account.gameAccountInfo
                    if type(info) == 'table' and info.isOnline and info.clientProgram == 'WoW' then wowInfo = info end
                end
                if wowInfo then addCharacter(wowInfo.characterName or account.accountName, wowInfo.realmName) end
            end
        end
    end
    return online
end

function SGB:GetGuildCount()
    if IsInGuild and IsInGuild() and GetNumGuildMembers then return select(2, GetNumGuildMembers()) or 0 end
    return 0
end
function SGB:GetFreeBagSlots()
    if not C_Container or not C_Container.GetContainerNumFreeSlots then return 0 end
    local total = 0; for bag = 0, 5 do total = total + (C_Container.GetContainerNumFreeSlots(bag) or 0) end; return total
end
