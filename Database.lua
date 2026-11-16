local _, SUI = ...

local DEFAULT_PROFILE = "Default"
local CURRENT_SCHEMA = 66
SUI.AuraRuleDefaults = { colorTarget = "HEALTH", borderThickness = 1 }
SUI.NameplateThreatBorderDefault = 2
local function color(r, g, b, a) return { r, g, b, a } end

local defaults = {
    modules = {
        integrations = {},
        interactionEffects = {
            enabled = true,
            intensity = .08,
        },
        lueurCompatibility = { enabled = SUI.isForever },
        partyMap = { enabled = SUI.isForever, markers = true },
        mapDisplay = { stackTabs = false },
        transportMap = { enabled = SUI.isForever, minimap = SUI.isForever },
        chatWhisperErrors = { enabled = SUI.isForever },
        mapWaypointControls = { enabled = SUI.isForever },
        shortestPathMinimap = { enabled = false },
        combatAlert = {
            enabled = true,
            showEnter = true,
            showLeave = true,
            reducedMotion = false,
            style = "BOTH",
            visualStyle = "SWORDS",
            stealthVisualStyle = "EYE",
            useThemeColors = true,
            customText = {},
            enterText = "В БОЙ",
            leaveText = "БОЙ ОКОНЧЕН",
            enterColor = color(.98, .36, .10, 1),
            leaveColor = color(.12, .84, .70, 1),
            font = "INTERFACE",
            fontSize = 32,
            swordSize = 94,
            swordDistance = 84,
            glowIntensity = .72,
            speed = 1,
            leaveDelay = .20,
            x = 0,
            y = 115,
            stealthEnabled = true,
            showStealthEnter = true,
            showStealthLeave = true,
            stealthEnterText = "СКРЫТНОСТЬ",
            stealthLeaveText = "СКРЫТНОСТЬ СНЯТА",
            stealthEnterColor = color(.58, .38, .98, 1),
            stealthLeaveColor = color(.62, .76, .88, 1),
            stealthFont = "INTERFACE",
            stealthFontSize = 19,
            stealthIconSize = 58,
            stealthGlowIntensity = .42,
            stealthX = 0,
            stealthY = 35,
            healthAlert = {
                enabled = false,
                threshold = 25,
                rearm = 35,
                style = "PULSE",
                text = "",
                useThemeColors = true,
                color = color(.98, .34, .29, 1),
                size = 68,
                fontSize = 27,
                x = 0,
                y = -85,
                mode = "BOTH",
            },
            aggroAlert = {
                enabled = false,
                style = "THREAT",
                text = "",
                useThemeColors = true,
                color = color(.98, .61, .26, 1),
                size = 68,
                fontSize = 27,
                x = 0,
                y = -205,
                mode = "BOTH",
            },
        },
        teleportPrompt = {
            enabled = true,
            knownOnly = true,
            showCooldown = true,
            autoHide = 0,
            scale = 1,
            x = 0,
            y = -58,
        },
        gameBar = {
            enabled = true, locked = true, point = "TOP", relativePoint = "TOP", x = 0, y = 0,
            scale = 1, mouseover = true, idleAlpha = 0, hoverAlpha = 1, fadeDuration = .11, fadeDelay = .04,
            combatVisibility = "SHOW_ON_HOVER", hideInPetBattle = false,
            appearance = {
                iconSize = 20, buttonSpacing = 7, panelPadding = 4, segmentGap = 10,
                timeWidth = 102, timeHeight = 39, verticalAlignment = 0,
                backdropEnabled = true, backdropColor = color(.02, .02, .02, .88),
                borderColor = color(.08, .08, .08, 1), borderSize = 1, borderStyle = "GLOW",
                iconColor = color(1, 1, 1, 1), iconScale = .9, iconAlpha = .9,
                hoverColorMode = "CUSTOM", hoverColor = color(.35, .75, 1, 1),
                timeFont = "DEFAULT", timeFontSize = 25, timeOutline = "OUTLINE", showSeconds = false,
            },
            leftButtons = { "CHARACTER", "SPELLBOOK", "TALENTS", "FRIENDS", "GUILD", "GROUP_FINDER", "PROFESSION" },
            rightButtons = { "GAMEMENU", "HOME", "ACHIEVEMENTS", "ENCOUNTER_JOURNAL", "COLLECTIONS", "BLIZZARD_SHOP", "BAGS" },
            hiddenButtons = {},
            clock = { enabled = true, localTime = true, twentyFourHour = true, updateInterval = 60, flashColon = false, showSystemInfo = false },
            miniBar = {
                enabled = true, locked = true,
                scale = .9, x = 0, y = -4, spacing = 4, padding = 4,
                mouseover = false, hoverAlpha = 1, fadeDuration = .11, fadeDelay = .04,
                combatVisibility = "SHOW_ON_HOVER", hideInPetBattle = false,
                restingX = 2, restingY = -4,
                autoWidth = true, width = 230, height = 30, contentYOffset = 0,
                clockWidth = 48, socialWidth = 32, fpsWidth = 43, latencyWidth = 48,
                socialIconSize = 18, restingSize = 24,
                showClock = true, showResting = true, showFriends = true, showGuild = true,
                showFPS = true, showLatency = true,
                hideZeroCounts = true, twentyFourHour = true, showSeconds = false,
                appearance = {
                    backdropEnabled = true, backdropColor = color(.02, .02, .02, .88),
                    borderColor = color(.08, .08, .08, 1), borderSize = 1, borderStyle = "GLOW",
                    iconColor = color(1, 1, 1, 1), iconAlpha = .9,
                    textColor = color(1, 1, 1, 1), textAlpha = 1, restingAlpha = .62,
                    hoverColorMode = "CUSTOM", hoverColor = color(.35, .75, 1, 1),
                    font = "DEFAULT", clockFontSize = 14, dataFontSize = 10, outline = "OUTLINE",
                    badgeFont = "DEFAULT", badgeFontSize = 10,
                    badgeColor = color(1, .82, 0, 1), badgeOutline = "OUTLINE",
                    badgeX = 0, badgeY = 4,
                },
                tooltip = {
                    font = "DEFAULT", fontSize = 10, outline = "OUTLINE",
                    width = 390, padding = 10, rowSpacing = 2, maxRows = 24,
                    groupByContext = true, showRealm = true, showGroupRole = true,
                    backdropEnabled = true, backdropColor = color(.02, .02, .02, .92),
                    borderColor = color(.08, .08, .08, 1), borderSize = 1, borderStyle = "GLOW",
                },
            },
        },
        specBar = {
            enabled = true, showActive = true, showLoot = true, locked = true, point = "TOP", relativePoint = "TOP", x = 0, y = -55, scale = 1,
            mouseover = false, hoverAlpha = 1, fadeDuration = .11, fadeDelay = .04,
            combatVisibility = "SHOW_ON_HOVER", hideInPetBattle = false,
        },
        raidTools = {
            enabled = true, locked = true, editMode = false,
            appearance = {
                iconSize = 23, spacing = 3, padding = 4, iconInset = 3,
                iconColor = color(1, 1, 1, 1), iconScale = .9, iconAlpha = .9,
                hoverColorMode = "CUSTOM", hoverColor = color(.35, .75, 1, 1),
                backdropEnabled = true, backdrop = color(.015, .018, .016, .88),
                borderStyle = "GLOW", borderSize = 1, border = color(0, 0, 0, 1),
                buttonBackdrop = color(.035, .04, .045, .94), buttonBorder = color(.16, .18, .19, 1),
                accent = color(.16, .70, .66, 1), font = "DEFAULT", fontSize = 12, outline = "OUTLINE",
            },
            panels = {
                TARGET = { enabled = true, point = "TOP", relativePoint = "TOP", x = -155, y = -52, scale = 1, orientation = "HORIZONTAL", mouseover = false, idleAlpha = .22, hoverAlpha = 1, fadeDelay = .12, fadeDuration = .11 },
                WORLD = { enabled = true, hideWhenUnavailable = true, point = "TOP", relativePoint = "TOP", x = 88, y = -52, scale = 1, orientation = "HORIZONTAL", mouseover = false, idleAlpha = .22, hoverAlpha = 1, fadeDelay = .12, fadeDuration = .11 },
                CONTROL = { enabled = true, point = "TOP", relativePoint = "TOP", x = 0, y = -92, scale = 1, orientation = "HORIZONTAL", mouseover = false, idleAlpha = .22, hoverAlpha = 1, fadeDelay = .12, fadeDuration = .11 },
                PING = { enabled = false, point = "TOP", relativePoint = "TOP", x = 0, y = -132, scale = 1, orientation = "HORIZONTAL", mouseover = false, idleAlpha = .22, hoverAlpha = 1, fadeDelay = .12, fadeDuration = .11 },
            },
            actions = { readyCheck = true, pullTimer = true, worldClear = true, pullSeconds = 10, useMouseover = true },
            raidCheck = {
                enabled = true, autoShow = true, autoHide = true, autoHideDelay = 4,
                onlyLeaderAssist = false, sort = "NOT_READY",
                columns = { food = true, flask = true, rune = true, buffs = true },
                point = "CENTER", relativePoint = "CENTER", x = 0, y = 120, scale = 1, locked = false,
            },
        },
        combatFont = { enabled = false, font = "DEFAULT", useInAlerts = true },
        fontCompatibility = {
            enabled = true,
            absorbInset = true,
            borderMedia = true,
            fonts = { ["Expressway, Bold"] = true },
            roundedFrames = {
                shapeMode = "AUTO",
                radius = 0,
                elements = {},
            },
        },
        nameplates = {
            enabled = true,
            learnDebuffs = true,
            buffIconsPerRow = 4,
            buffRowSpacing = 2,
            textStyles = {
                name = "outlineShadow", level = "outlineShadow", health = "native",
                target = "native", quest = "native", castName = "native",
                castTarget = "native", castTime = "native",
            },
            smoothHealth = false,
            openWorldThreat = true,
            nearThreat = true,
            threatBorderEnabled = true,
            threatBorderThickness = SUI.NameplateThreatBorderDefault,
            threatFillEnabled = false,
            respectTapDenied = true,
            aggroColor = { r = 0.86, g = 0.24, b = 0.22 },
            nearColor = { r = 0.95, g = 0.68, b = 0.18 },
            aggroFillColor = { r = 0.70, g = 0.08, b = 0.04 },
            nearFillColor = { r = 0.72, g = 0.34, b = 0.05 },
            targetPattern = {
                enabled = true,
                texture = "diagonal",
                opacity = .28,
                scale = 1,
                coverBackground = false,
            },
            auraRules = {
                scopes = {},
                pandemic = {
                    enabled = false,
                    pulse = true,
                    pulseSpeed = 0.35,
                    color = { r = 1, g = 1, b = 1, a = 0.45 },
                },
            },
        },
        cooldownMasks = {
            enabled = true,
            actionBars = true,
            cooldownManager = true,
            rangeFade = true,
            rangeOpacity = .45,
            rangeColorEnabled = false,
            rangeColor = color(.8, .1, .1),
            hideSpark = true,
            mainSwipeAlpha = 0.55,
            chargeSwipeAlpha = 0.38,
            buffEffects = {
                enabled = true,
                speed = .80,
                intensity = .70,
                scopes = {},
            },
            procEffects = {
                enabled = false,
                mode = "BOTH",
                color = color(1, .72, .18, .72),
                speed = .80,
                intensity = .72,
                scale = 1.10,
            },
        },
    },
}
SUI.defaults = defaults

-- Forever has its own local SavedVariables. Start with only the settings
-- launcher and UI feedback; the player selects the overlays they want.
if SUI.isForever then
    local modules = defaults.modules
    for _, key in ipairs({ "gameBar", "specBar", "combatAlert", "teleportPrompt", "raidTools",
        "fontCompatibility", "nameplates", "cooldownMasks" }) do
        modules[key].enabled = false
    end
    modules.gameBar.miniBar.enabled = false
    modules.fontCompatibility.absorbInset = false
    modules.fontCompatibility.borderMedia = false
    modules.nameplates.learnDebuffs = false
    modules.raidTools.raidCheck.columns.flask = false
    modules.raidTools.raidCheck.columns.rune = false
end

local function DeepCopy(source)
    if type(source) ~= "table" then return source end
    local result = {}
    for key, value in pairs(source) do result[key] = DeepCopy(value) end
    return result
end
SUI.DeepCopy = DeepCopy

local function ArrayKind(value)
    if type(value) ~= "table" or next(value) == nil then return nil end
    local count, numeric = 0, true
    for key, item in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return nil end
        count = math.max(count, key)
        if type(item) ~= "number" then numeric = false end
    end
    for index = 1, count do if value[index] == nil then return nil end end
    return numeric and "vector" or "array"
end

local function ApplyDefaults(source, destination)
    for key, value in pairs(source) do
        if type(value) == "table" then
            local arrayKind = ArrayKind(value)
            if type(destination[key]) ~= "table" then
                destination[key] = DeepCopy(value)
            elseif arrayKind == "vector" then
                for index, item in ipairs(value) do
                    if destination[key][index] == nil then destination[key][index] = item end
                end
            elseif arrayKind ~= "array" then
                ApplyDefaults(value, destination[key])
            end
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end
SUI.ApplyDefaults = ApplyDefaults

local function CleanObsoleteProfileFields(profile)
    local modules = profile and profile.modules
    local gameBar = type(modules) == "table" and modules.gameBar
    local mini = type(gameBar) == "table" and gameBar.miniBar
    local tooltip = type(mini) == "table" and mini.tooltip
    if type(tooltip) == "table" then tooltip.showGuildRank = nil end
    local nameplates = modules and modules.nameplates
    if not nameplates then return end
    nameplates.threatStyle = nil
    nameplates.nonTargetShade = nil
    local auraRoot = nameplates.auraRules
    if type(auraRoot) ~= "table" then return end
    auraRoot.enabled, auraRoot.rules, auraRoot.legacyMigrated = nil, nil, nil
    for _, scope in pairs(auraRoot.scopes or {}) do
        for _, rule in ipairs(scope.rules or {}) do
            rule.action, rule.border, rule.priority = nil, nil, nil
        end
    end
end

local function MigrateCooldownRules(profile)
    local modules = profile and profile.modules
    local effects = modules and modules.cooldownMasks and modules.cooldownMasks.buffEffects
    local scopes = type(effects) == "table" and effects.scopes or nil
    for _, scope in pairs(type(scopes) == "table" and scopes or {}) do
        local rules = type(scope) == "table" and scope.rules or nil
        for _, rule in pairs(type(rules) == "table" and rules or {}) do
            if type(rule) == "table" and (type(rule.levels) ~= "table" or #rule.levels == 0) then
                rule.levels = {{
                    threshold = tonumber(rule.threshold) or 2,
                    mode = rule.mode or "BOTH",
                    color = DeepCopy(type(rule.color) == "table" and rule.color or { .10, 1, .72, .58 }),
                    sound = false,
                }}
            end
            if type(rule) == "table" then rule.threshold, rule.mode, rule.color = nil, nil, nil end
        end
    end
end

local function MigrateInteractionEffects(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local effects = profile.modules.interactionEffects
    if type(effects) ~= "table" then
        effects = {}
        profile.modules.interactionEffects = effects
    end
    if type(effects.enabled) ~= "boolean" then effects.enabled = true end
    effects.intensity = math.max(.03, math.min(.15, tonumber(effects.intensity) or .08))
end

local function MigrateCombatAlert(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local alert = profile.modules.combatAlert
    if type(alert) ~= "table" then
        alert = {}
        profile.modules.combatAlert = alert
    end
    if type(alert.enabled) ~= "boolean" then alert.enabled = true end
    if type(alert.showEnter) ~= "boolean" then alert.showEnter = true end
    if type(alert.showLeave) ~= "boolean" then alert.showLeave = true end
    if type(alert.reducedMotion) ~= "boolean" then alert.reducedMotion = false end
    if type(alert.stealthEnabled) ~= "boolean" then alert.stealthEnabled = true end
    if type(alert.showStealthEnter) ~= "boolean" then alert.showStealthEnter = true end
    if type(alert.showStealthLeave) ~= "boolean" then alert.showStealthLeave = true end
    if alert.style ~= "BOTH" and alert.style ~= "TEXT" and alert.style ~= "SWORDS" then alert.style = "BOTH" end
    if type(alert.enterText) ~= "string" or alert.enterText == "" then alert.enterText = "В БОЙ" end
    if type(alert.leaveText) ~= "string" or alert.leaveText == "" then alert.leaveText = "БОЙ ОКОНЧЕН" end
    if type(alert.stealthEnterText) ~= "string" or alert.stealthEnterText == "" then alert.stealthEnterText = "СКРЫТНОСТЬ" end
    if type(alert.stealthLeaveText) ~= "string" or alert.stealthLeaveText == "" then alert.stealthLeaveText = "СКРЫТНОСТЬ СНЯТА" end
    if type(alert.enterColor) ~= "table" then alert.enterColor = { .98, .36, .10, 1 } end
    if type(alert.leaveColor) ~= "table" then alert.leaveColor = { .12, .84, .70, 1 } end
    if type(alert.stealthEnterColor) ~= "table" then alert.stealthEnterColor = { .58, .38, .98, 1 } end
    if type(alert.stealthLeaveColor) ~= "table" then alert.stealthLeaveColor = { .62, .76, .88, 1 } end
    alert.fontSize = math.max(20, math.min(52, tonumber(alert.fontSize) or 32))
    alert.swordSize = math.max(56, math.min(148, tonumber(alert.swordSize) or 94))
    alert.swordDistance = math.max(30, math.min(150, tonumber(alert.swordDistance) or 84))
    alert.glowIntensity = math.max(0, math.min(1, tonumber(alert.glowIntensity) or .72))
    alert.speed = math.max(.50, math.min(1.75, tonumber(alert.speed) or 1))
    alert.leaveDelay = math.max(0, math.min(.60, tonumber(alert.leaveDelay) or .20))
    alert.x = math.max(-600, math.min(600, tonumber(alert.x) or 0))
    alert.y = math.max(-400, math.min(400, tonumber(alert.y) or 115))
    alert.stealthFontSize = math.max(12, math.min(30, tonumber(alert.stealthFontSize) or 19))
    alert.stealthIconSize = math.max(42, math.min(88, tonumber(alert.stealthIconSize) or 58))
    alert.stealthGlowIntensity = math.max(0, math.min(1, tonumber(alert.stealthGlowIntensity) or .42))
    alert.stealthX = math.max(-600, math.min(600, tonumber(alert.stealthX) or 0))
    alert.stealthY = math.max(-400, math.min(400, tonumber(alert.stealthY) or 35))
end
local function MigrateTeleportPrompt(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local prompt = profile.modules.teleportPrompt
    if type(prompt) ~= "table" then
        prompt = {}
        profile.modules.teleportPrompt = prompt
    end
    if type(prompt.enabled) ~= "boolean" then prompt.enabled = true end
    if type(prompt.knownOnly) ~= "boolean" then prompt.knownOnly = true end
    if type(prompt.showCooldown) ~= "boolean" then prompt.showCooldown = true end
    prompt.autoHide = math.max(0, math.min(30, tonumber(prompt.autoHide) or 0))
    prompt.scale = math.max(.75, math.min(1.35, tonumber(prompt.scale) or 1))
    prompt.x = math.max(-700, math.min(700, tonumber(prompt.x) or 0))
    prompt.y = math.max(-500, math.min(0, tonumber(prompt.y) or -58))
end

local function MigrateNameplateTargetPattern(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local nameplates = profile.modules.nameplates
    if type(nameplates) ~= "table" then
        nameplates = {}
        profile.modules.nameplates = nameplates
    end
    local pattern = nameplates.targetPattern
    if type(pattern) ~= "table" then
        pattern = {}
        nameplates.targetPattern = pattern
    end
    if type(pattern.enabled) ~= "boolean" then pattern.enabled = true end
    if type(pattern.texture) ~= "string" then pattern.texture = "diagonal" end
    pattern.opacity = math.max(.05, math.min(.70, tonumber(pattern.opacity) or .28))
    pattern.scale = math.max(.5, math.min(2, tonumber(pattern.scale) or 1))
    if type(pattern.coverBackground) ~= "boolean" then pattern.coverBackground = false end
end

local function MigrateNameplateThreatLayers(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local nameplates = profile.modules.nameplates
    if type(nameplates) ~= "table" then
        nameplates = {}
        profile.modules.nameplates = nameplates
    end
    if type(nameplates.threatBorderEnabled) ~= "boolean" then nameplates.threatBorderEnabled = true end
    if type(nameplates.threatFillEnabled) ~= "boolean" then nameplates.threatFillEnabled = false end
    if type(nameplates.aggroFillColor) ~= "table" then nameplates.aggroFillColor = { .70, .08, .04 } end
    if type(nameplates.nearFillColor) ~= "table" then nameplates.nearFillColor = { .72, .34, .05 } end
end

local function DisableTaintUnsafeActionBarCooldowns(profile)
    local modules = type(profile) == "table" and profile.modules
    local cooldowns = type(modules) == "table" and modules.cooldownMasks
    if type(cooldowns) == "table" then cooldowns.actionBars = false end
end

local function EnableEUIOwnedActionBarCooldowns(profile)
    local modules = type(profile) == "table" and profile.modules
    local cooldowns = type(modules) == "table" and modules.cooldownMasks
    if type(cooldowns) == "table" then cooldowns.actionBars = true end
end

local function MigrateCooldownSwipeAlphas(profile)
    local modules = type(profile) == "table" and profile.modules
    local cooldowns = type(modules) == "table" and modules.cooldownMasks
    if type(cooldowns) ~= "table" then return end
    cooldowns.mainSwipeAlpha = math.max(.05, math.min(1, tonumber(cooldowns.mainSwipeAlpha) or .55))
    cooldowns.chargeSwipeAlpha = math.max(.05, math.min(1, tonumber(cooldowns.chargeSwipeAlpha) or .38))
end

local function MigrateGameBarMiniBar(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local gameBar = profile.modules.gameBar
    if type(gameBar) ~= "table" then
        gameBar = {}
        profile.modules.gameBar = gameBar
    end
    local mini = gameBar.miniBar
    if type(mini) ~= "table" then
        mini = {}
        gameBar.miniBar = mini
    end
    if type(mini.enabled) ~= "boolean" then mini.enabled = true end
    if type(mini.showResting) ~= "boolean" then mini.showResting = true end
    if type(mini.showFriends) ~= "boolean" then mini.showFriends = true end
    if type(mini.showGuild) ~= "boolean" then mini.showGuild = true end
    if type(mini.showFPS) ~= "boolean" then mini.showFPS = true end
    if type(mini.showLatency) ~= "boolean" then mini.showLatency = true end
    mini.scale = tonumber(mini.scale) or .9
    mini.x = tonumber(mini.x) or 0
    mini.y = tonumber(mini.y) or -4
    mini.spacing = tonumber(mini.spacing) or 4
    mini.padding = tonumber(mini.padding) or 4
end

local function MigrateGameBarMiniAppearance(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local gameBar = profile.modules.gameBar
    if type(gameBar) ~= "table" then
        gameBar = {}
        profile.modules.gameBar = gameBar
    end
    local mini = gameBar.miniBar
    if type(mini) ~= "table" then
        mini = {}
        gameBar.miniBar = mini
    end
    local source = type(gameBar.appearance) == "table" and gameBar.appearance or {}
    local appearance = mini.appearance
    if type(appearance) ~= "table" then
        appearance = {}
        mini.appearance = appearance
    end
    if type(appearance.backdropEnabled) ~= "boolean" then appearance.backdropEnabled = source.backdropEnabled ~= false end
    if type(appearance.backdropColor) ~= "table" then appearance.backdropColor = DeepCopy(source.backdropColor or { .02, .02, .02, .88 }) end
    if type(appearance.borderColor) ~= "table" then appearance.borderColor = DeepCopy(source.borderColor or { .08, .08, .08, 1 }) end
    if appearance.borderStyle ~= "SOLID" and appearance.borderStyle ~= "GLOW" then appearance.borderStyle = source.borderStyle == "SOLID" and "SOLID" or "GLOW" end
    appearance.borderSize = math.max(0, math.min(4, tonumber(appearance.borderSize) or tonumber(source.borderSize) or 1))
    if type(appearance.iconColor) ~= "table" then appearance.iconColor = DeepCopy(source.iconColor or { 1, 1, 1, 1 }) end
    appearance.iconAlpha = math.max(.1, math.min(1, tonumber(appearance.iconAlpha) or tonumber(source.iconAlpha) or .9))
    if type(appearance.textColor) ~= "table" then appearance.textColor = { 1, 1, 1, 1 } end
    appearance.textAlpha = math.max(.1, math.min(1, tonumber(appearance.textAlpha) or 1))
    appearance.restingAlpha = math.max(.1, math.min(1, tonumber(appearance.restingAlpha) or .62))
    if appearance.hoverColorMode ~= "CLASS" and appearance.hoverColorMode ~= "CUSTOM" then
        appearance.hoverColorMode = source.hoverColorMode == "CLASS" and "CLASS" or "CUSTOM"
    end
    if type(appearance.hoverColor) ~= "table" then appearance.hoverColor = DeepCopy(source.hoverColor or { .35, .75, 1, 1 }) end
    if type(appearance.font) ~= "string" then appearance.font = type(source.timeFont) == "string" and source.timeFont or "DEFAULT" end
    appearance.clockFontSize = math.max(10, math.min(24, tonumber(appearance.clockFontSize) or 14))
    appearance.dataFontSize = math.max(8, math.min(18, tonumber(appearance.dataFontSize) or 10))
    appearance.badgeFontSize = math.max(8, math.min(18, tonumber(appearance.badgeFontSize) or 10))
    if appearance.outline ~= "NONE" and appearance.outline ~= "OUTLINE" and appearance.outline ~= "THICKOUTLINE" then
        appearance.outline = source.timeOutline or "OUTLINE"
    end
    mini.restingX = tonumber(mini.restingX) or 2
    mini.restingY = tonumber(mini.restingY) or -4
end

local function MigrateGameBarMiniGeometry(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local gameBar = profile.modules.gameBar
    if type(gameBar) ~= "table" then
        gameBar = {}
        profile.modules.gameBar = gameBar
    end
    local mini = gameBar.miniBar
    if type(mini) ~= "table" then
        mini = {}
        gameBar.miniBar = mini
    end
    local appearance = mini.appearance
    if type(appearance) ~= "table" then
        appearance = {}
        mini.appearance = appearance
    end
    if type(mini.autoWidth) ~= "boolean" then mini.autoWidth = true end
    mini.width = math.max(120, math.min(600, tonumber(mini.width) or 230))
    mini.height = math.max(22, math.min(80, tonumber(mini.height) or 30))
    mini.contentYOffset = math.max(-20, math.min(20, tonumber(mini.contentYOffset) or 0))
    mini.clockWidth = math.max(36, math.min(120, tonumber(mini.clockWidth) or 48))
    mini.socialWidth = math.max(20, math.min(80, tonumber(mini.socialWidth) or 32))
    mini.fpsWidth = math.max(32, math.min(120, tonumber(mini.fpsWidth) or 43))
    mini.latencyWidth = math.max(32, math.min(120, tonumber(mini.latencyWidth) or 48))
    mini.socialIconSize = math.max(12, math.min(36, tonumber(mini.socialIconSize) or 18))
    mini.restingSize = math.max(16, math.min(40, tonumber(mini.restingSize) or 24))
    if type(mini.hideZeroCounts) ~= "boolean" then mini.hideZeroCounts = true end
    local clock = type(gameBar.clock) == "table" and gameBar.clock or {}
    local mainAppearance = type(gameBar.appearance) == "table" and gameBar.appearance or {}
    if type(mini.twentyFourHour) ~= "boolean" then mini.twentyFourHour = clock.twentyFourHour ~= false end
    if type(mini.showSeconds) ~= "boolean" then mini.showSeconds = mainAppearance.showSeconds == true end
    if type(appearance.badgeFont) ~= "string" then appearance.badgeFont = appearance.font or "DEFAULT" end
    if type(appearance.badgeColor) ~= "table" then appearance.badgeColor = { 1, .82, 0, 1 } end
    if appearance.badgeOutline ~= "NONE" and appearance.badgeOutline ~= "OUTLINE" and appearance.badgeOutline ~= "THICKOUTLINE" then
        appearance.badgeOutline = appearance.outline or "OUTLINE"
    end
    appearance.badgeFontSize = math.max(8, math.min(24, tonumber(appearance.badgeFontSize) or 10))
    appearance.badgeX = math.max(-20, math.min(20, tonumber(appearance.badgeX) or 0))
    appearance.badgeY = math.max(-20, math.min(20, tonumber(appearance.badgeY) or 4))
end

local function MigrateGameBarMiniSocialTooltip(profile)
    if type(profile) ~= "table" then return end
    profile.modules = type(profile.modules) == "table" and profile.modules or {}
    local gameBar = profile.modules.gameBar
    if type(gameBar) ~= "table" then
        gameBar = {}
        profile.modules.gameBar = gameBar
    end
    local mini = gameBar.miniBar
    if type(mini) ~= "table" then
        mini = {}
        gameBar.miniBar = mini
    end
    if type(mini.locked) ~= "boolean" then mini.locked = true end
    if type(mini.mouseover) ~= "boolean" then mini.mouseover = false end
    mini.hoverAlpha = math.max(.1, math.min(1, tonumber(mini.hoverAlpha) or 1))
    mini.fadeDuration = math.max(.03, math.min(1, tonumber(mini.fadeDuration) or .11))
    mini.fadeDelay = math.max(.03, math.min(1, tonumber(mini.fadeDelay) or .04))
    if mini.combatVisibility ~= "SHOW" and mini.combatVisibility ~= "HIDE" and mini.combatVisibility ~= "SHOW_ON_HOVER" then
        mini.combatVisibility = "SHOW_ON_HOVER"
    end
    if type(mini.hideInPetBattle) ~= "boolean" then mini.hideInPetBattle = false end

    local tooltip = mini.tooltip
    if type(tooltip) ~= "table" then
        tooltip = {}
        mini.tooltip = tooltip
    end
    if type(tooltip.font) ~= "string" then tooltip.font = "DEFAULT" end
    tooltip.fontSize = math.max(8, math.min(16, tonumber(tooltip.fontSize) or 10))
    if tooltip.outline ~= "NONE" and tooltip.outline ~= "OUTLINE" and tooltip.outline ~= "THICKOUTLINE" then
        tooltip.outline = "OUTLINE"
    end
    tooltip.width = math.max(280, math.min(600, tonumber(tooltip.width) or 390))
    tooltip.padding = math.max(4, math.min(24, tonumber(tooltip.padding) or 10))
    tooltip.rowSpacing = math.max(0, math.min(12, tonumber(tooltip.rowSpacing) or 2))
    tooltip.maxRows = math.max(5, math.min(50, tonumber(tooltip.maxRows) or 24))
    if type(tooltip.groupByContext) ~= "boolean" then tooltip.groupByContext = true end

    if type(tooltip.showRealm) ~= "boolean" then tooltip.showRealm = true end
    if type(tooltip.showGroupRole) ~= "boolean" then tooltip.showGroupRole = true end
end

local function MigrateGameBarMiniTooltipAppearance(profile)
    MigrateGameBarMiniSocialTooltip(profile)
    local tooltip = profile.modules.gameBar.miniBar.tooltip
    tooltip.showGuildRank = nil
    if type(tooltip.backdropEnabled) ~= "boolean" then tooltip.backdropEnabled = true end
    if type(tooltip.backdropColor) ~= "table" then tooltip.backdropColor = { .02, .02, .02, .92 } end
    if type(tooltip.borderColor) ~= "table" then tooltip.borderColor = { .08, .08, .08, 1 } end
    tooltip.borderSize = math.max(0, math.min(4, tonumber(tooltip.borderSize) or 1))
    if tooltip.borderStyle ~= "SOLID" and tooltip.borderStyle ~= "GLOW" then tooltip.borderStyle = "GLOW" end
end

local function MigrateLearnedDebuffs(db)
    local source = type(db.learnedDebuffs) == "table" and db.learnedDebuffs or {}
    local normalized = {}
    for key, entry in pairs(source) do
        local spellID = tonumber(key)
        if spellID and spellID >= 1 and spellID % 1 == 0 and type(entry) == "table" then
            entry.name = type(entry.name) == "string" and entry.name or nil
            entry.classes = type(entry.classes) == "table" and entry.classes or {}
            if type(entry.class) == "string" then entry.classes[entry.class] = true end
            entry.class = nil
            for class, learned in pairs(entry.classes) do
                if type(class) ~= "string" or learned ~= true then entry.classes[class] = nil end
            end
            entry.seen = tonumber(entry.seen) or 0
            normalized[spellID] = entry
        end
    end
    db.learnedDebuffs = normalized
end

local function MigrateAuraRuleAppearance(profile)
    local modules = type(profile) == "table" and profile.modules
    local nameplates = type(modules) == "table" and modules.nameplates
    local root = type(nameplates) == "table" and nameplates.auraRules
    local scopes = type(root) == "table" and root.scopes
    for _, scope in pairs(type(scopes) == "table" and scopes or {}) do
        local rules = type(scope) == "table" and scope.rules
        for _, rule in pairs(type(rules) == "table" and rules or {}) do
            if type(rule) == "table" then
                for key, value in pairs(SUI.AuraRuleDefaults) do
                    if rule[key] == nil then rule[key] = value end
                end
                if type(rule.colorTargets) ~= "table" then
                    local target = rule.colorTarget
                    if target ~= "BORDER" and target ~= "TEXT" then target = "HEALTH" end
                    rule.colorTargets = { [target] = true }
                end
            end
        end
    end
end

local function RunMigrations(db)
    local previous = tonumber(db.schemaVersion) or 0
    if previous < 9 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            CleanObsoleteProfileFields(profile)
            MigrateCooldownRules(profile)
        end
    end
    if previous < 10 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateInteractionEffects(profile)
        end
    end
    if previous < 14 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateNameplateTargetPattern(profile)
        end
    end
    if previous < 15 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            DisableTaintUnsafeActionBarCooldowns(profile)
        end
    end
    if previous < 16 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateGameBarMiniBar(profile)
        end
    end
    if previous < 17 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateGameBarMiniAppearance(profile)
        end
    end
    if previous < 18 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateGameBarMiniGeometry(profile)
        end
    end
    if previous < 19 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            EnableEUIOwnedActionBarCooldowns(profile)
        end
    end
    if previous < 20 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateGameBarMiniSocialTooltip(profile)
        end
    end
    if previous < 21 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateGameBarMiniTooltipAppearance(profile)
        end
    end
    if previous < 22 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateNameplateTargetPattern(profile)
        end
    end
    if previous < 23 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateCooldownSwipeAlphas(profile)
        end
    end
    if previous < 26 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateNameplateThreatLayers(profile)
        end
    end
    if previous < 28 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateCombatAlert(profile)
        end
    end
    if previous < 29 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateTeleportPrompt(profile)
        end
    end
    if previous < 30 then MigrateLearnedDebuffs(db) end
    if previous < 32 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            if type(profile) == "table" then
                profile.modules = type(profile.modules) == "table" and profile.modules or {}
                if type(profile.modules.specBar) ~= "table" then profile.modules.specBar = {} end
            end
        end
    end
    if previous < 33 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local bar = type(modules) == "table" and modules.specBar
            if type(bar) == "table" then
                if bar.mouseover == nil then bar.mouseover = false end
                if bar.hoverAlpha == nil then bar.hoverAlpha = 1 end
                if bar.fadeDuration == nil then bar.fadeDuration = .11 end
                if bar.fadeDelay == nil then bar.fadeDelay = .04 end
                if bar.combatVisibility == nil then bar.combatVisibility = "SHOW_ON_HOVER" end
                if bar.hideInPetBattle == nil then bar.hideInPetBattle = false end
            end
        end
    end
    if previous < 31 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateAuraRuleAppearance(profile)
        end
    end
    if previous < 34 then
        -- Add the independent feature switches without replacing old choices.
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            if type(profile) == "table" then ApplyDefaults(defaults, profile) end
        end
    end
    if previous < 35 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local cooldowns = type(modules) == "table" and modules.cooldownMasks
            if type(cooldowns) == "table" then
                if cooldowns.rangeFade == nil then cooldowns.rangeFade = defaults.modules.cooldownMasks.rangeFade end
                if cooldowns.rangeOpacity == nil then cooldowns.rangeOpacity = defaults.modules.cooldownMasks.rangeOpacity end
            end
        end
    end
    if previous < 36 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" and modules.lueurCompatibility == nil then
                modules.lueurCompatibility = DeepCopy(defaults.modules.lueurCompatibility)
            end
        end
    end
    if previous < 37 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" and modules.partyMap == nil then
                modules.partyMap = DeepCopy(defaults.modules.partyMap)
            end
        end
    end
    if previous < 38 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" and modules.transportMap == nil then
                modules.transportMap = DeepCopy(defaults.modules.transportMap)
            end
        end
    end
    if previous < 39 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local alert = type(modules) == "table" and modules.combatAlert
            if type(alert) == "table" then
                for _, key in ipairs({ "font", "stealthFont" }) do
                    if type(alert[key]) ~= "string" or alert[key] == "" then
                        alert[key] = defaults.modules.combatAlert[key]
                    end
                end
            end
        end
    end
    if previous < 40 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local partyMap = type(modules) == "table" and modules.partyMap
            if type(partyMap) == "table" then
                partyMap.launcher, partyMap.angle = nil, nil
            end
        end
    end
    if previous < 41 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" and modules.chatWhisperErrors == nil then
                modules.chatWhisperErrors = DeepCopy(defaults.modules.chatWhisperErrors)
            end
        end
    end
    if previous < 42 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" and modules.mapWaypointControls == nil then
                modules.mapWaypointControls = DeepCopy(defaults.modules.mapWaypointControls)
            end
        end
    end
    if previous < 43 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            if type(profile) == "table" then
                profile.modules = type(profile.modules) == "table" and profile.modules or {}
                local fonts = profile.modules.fontCompatibility
                if type(fonts) ~= "table" then
                    fonts = {}
                    profile.modules.fontCompatibility = fonts
                end
                local rounded = type(fonts.roundedFrames) == "table" and fonts.roundedFrames or {}
                fonts.roundedFrames = rounded
                if rounded.shapeMode == nil then rounded.shapeMode = "AUTO" end
                rounded.enabled, rounded.dandersFrames, rounded.unitFrames, rounded.nameplates = nil, nil, nil, nil
                rounded.color, rounded.borderSize, rounded.outset = nil, nil, nil
            end
        end
    end
    if previous < 44 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local fonts = type(profile) == "table" and type(profile.modules) == "table" and profile.modules.fontCompatibility
            local shape = type(fonts) == "table" and fonts.roundedFrames
            if type(shape) == "table" then
                if shape.radius == nil then shape.radius = 0 end
                if type(shape.elements) ~= "table" then shape.elements = {} end
            end
        end
    end
    if previous < 45 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            local color = type(plates) == "table" and plates.aggroColor
            if type(color) == "table" and color.r == .95 and color.g == .42 and color.b == .12 then
                local nextColor = defaults.modules.nameplates.aggroColor
                color.r, color.g, color.b = nextColor.r, nextColor.g, nextColor.b
            end
        end
    end
    if previous < 46 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            if type(plates) == "table" and plates.buffIconsPerRow == nil then
                plates.buffIconsPerRow = defaults.modules.nameplates.buffIconsPerRow
            end
        end
    end
    if previous < 48 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            if type(plates) == "table" then
                local styles = type(plates.textStyles) == "table" and plates.textStyles or {}
                local legacy = plates.nameStyle
                if legacy == "native" or legacy == "outline" or legacy == "shadow" or legacy == "outlineShadow" then
                    if styles.name == nil then styles.name = legacy end
                    if styles.level == nil then styles.level = legacy end
                end
                plates.textStyles, plates.nameStyle = styles, nil
            end
        end
    end
    if previous < 49 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            if type(plates) == "table" and plates.buffRowSpacing == nil then
                plates.buffRowSpacing = defaults.modules.nameplates.buffRowSpacing
            end
        end
    end
    if previous < 50 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateAuraRuleAppearance(profile)
        end
    end
    if previous < 51 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            if type(plates) == "table" and plates.threatBorderThickness == nil then
                plates.threatBorderThickness = defaults.modules.nameplates.threatBorderThickness
            end
        end
    end
    if previous < 54 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            MigrateAuraRuleAppearance(profile)
        end
    end
    if previous < 55 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local transport = type(modules) == "table" and modules.transportMap
            if type(transport) == "table" and transport.minimap == nil then
                transport.minimap = transport.enabled == true and defaults.modules.transportMap.minimap
            end
        end
    end
    if previous < 57 then
        for name, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            if type(plates) == "table" and (plates.executeDamageThreshold ~= nil
                or plates.executeDamageAuto ~= nil or plates.executeMarkerStyle ~= nil) then
                if type(db.executeArchive) ~= "table" then db.executeArchive = {} end
                db.executeArchive[name] = {
                    executeDamageThreshold = plates.executeDamageThreshold,
                    executeDamageAuto = plates.executeDamageAuto,
                    executeMarkerStyle = DeepCopy(plates.executeMarkerStyle),
                }
                plates.executeDamageThreshold, plates.executeDamageAuto, plates.executeMarkerStyle = nil, nil, nil
            end
        end
    end
    if previous < 58 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            if type(plates) == "table" then plates.nonTargetFade = nil end
        end
    end
    if previous < 59 then
        local rangeDefaults = defaults.modules.cooldownMasks
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local cooldowns = type(modules) == "table" and modules.cooldownMasks
            if type(cooldowns) == "table" then
                if cooldowns.rangeColorEnabled == nil then cooldowns.rangeColorEnabled = rangeDefaults.rangeColorEnabled end
                if cooldowns.rangeColor == nil then cooldowns.rangeColor = DeepCopy(rangeDefaults.rangeColor) end
            end
        end
    end
    if previous < 60 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" and modules.shortestPathMinimap == nil then
                modules.shortestPathMinimap = DeepCopy(defaults.modules.shortestPathMinimap)
            end
        end
    end
    if previous < 61 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local font = type(modules) == "table" and modules.combatFont
            if type(font) == "table" and font.useInAlerts == nil then
                font.useInAlerts = defaults.modules.combatFont.useInAlerts
            end
        end
    end
    if previous < 62 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" then
                if modules.integrations == nil then modules.integrations = {} end
                local alerts = modules.combatAlert
                if type(alerts) == "table" then
                    if alerts.visualStyle == nil then alerts.visualStyle = defaults.modules.combatAlert.visualStyle end
                    if alerts.useThemeColors == nil then alerts.useThemeColors = defaults.modules.combatAlert.useThemeColors end
                    if type(alerts.customText) ~= "table" then alerts.customText = {} end
                end
            end
        end
    end
    if previous < 63 then
        local stealthStyles = { EYE = true, SEAL = true, CREST = true, EMBERS = true, SLASH = true }
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local alerts = type(modules) == "table" and modules.combatAlert
            if type(alerts) == "table" and not stealthStyles[alerts.stealthVisualStyle] then
                alerts.stealthVisualStyle = stealthStyles[alerts.visualStyle] and alerts.visualStyle
                    or defaults.modules.combatAlert.stealthVisualStyle
            end
        end
    end
    if previous < 64 then
        local alertDefaults = defaults.modules.combatAlert
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local alerts = type(modules) == "table" and modules.combatAlert
            if type(alerts) == "table" then
                for _, key in ipairs({ "healthAlert", "aggroAlert" }) do
                    if type(alerts[key]) ~= "table" then alerts[key] = DeepCopy(alertDefaults[key]) end
                end
            end
        end
    end
    if previous < 65 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            if type(modules) == "table" and modules.mapDisplay == nil then
                modules.mapDisplay = DeepCopy(defaults.modules.mapDisplay)
            end
        end
    end
    if previous < 66 then
        for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            local modules = type(profile) == "table" and profile.modules
            local display = type(modules) == "table" and modules.mapDisplay
            if type(display) == "table" then
                display.questPriority, display.dedupeQuests = nil, nil
            end
        end
    end
    db.schemaVersion = math.max(previous, CURRENT_SCHEMA)
end

local function LegacyProfile(db, activeKey)
    if type(db) ~= "table" or type(db.profiles) ~= "table" then return nil end
    local name = db[activeKey]
    return type(name) == "string" and db.profiles[name] or nil
end

function SUI:ImportLegacyDatabases()
    self.db.imports = type(self.db.imports) == "table" and self.db.imports or {}
    if self.db.imports.unifiedModulesV1 then return end
    local target = self.profile.modules
    local gameBar = LegacyProfile(_G.StandaloneGameBarDB, "profile")
    local raidTools = LegacyProfile(_G.StandaloneRaidToolsDB, "activeProfile")
    if gameBar then target.gameBar = DeepCopy(gameBar) end
    if raidTools then target.raidTools = DeepCopy(raidTools) end
    ApplyDefaults(defaults.modules.gameBar, target.gameBar)
    ApplyDefaults(defaults.modules.raidTools, target.raidTools)
    self.db.imports.unifiedModulesV1 = true
end

function SUI:InitializeDatabase()
    if type(Sintezza_UIDB) ~= "table" then Sintezza_UIDB = {} end
    local db = Sintezza_UIDB
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    if type(db.minimap.hidden) ~= "boolean" then db.minimap.hidden = false end
    if type(db.minimap.angle) ~= "number" then db.minimap.angle = 225 end
    db.activeProfile = type(db.activeProfile) == "string" and db.activeProfile or DEFAULT_PROFILE
    db.profiles = type(db.profiles) == "table" and db.profiles or {}
    if type(db.profiles[db.activeProfile]) ~= "table" then db.profiles[db.activeProfile] = DeepCopy(defaults) end
    RunMigrations(db)
    for _, profile in pairs(db.profiles) do
        ApplyDefaults(defaults, profile)
        CleanObsoleteProfileFields(profile)
    end
    self.db, self.profile = db, db.profiles[db.activeProfile]
    self:ImportLegacyDatabases()
    ApplyDefaults(defaults, self.profile)
end

function SUI:GetProfile() return self.profile end
function SUI:GetModuleProfile(key)
    local profile = self:GetProfile()
    return profile and profile.modules and profile.modules[key]
end

function SUI:ProfileNames()
    local names = {}
    for name in pairs(self.db.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function SUI:ApplyActiveProfile()
    self.profile = self.db.profiles[self.db.activeProfile]
    ApplyDefaults(defaults, self.profile)
    local allOkay = true
    for _, key in ipairs(self.moduleOrder) do
        local module = self:GetModule(key)
        if module and module.OnProfileChanged then
            local ok = self:SafeModuleCall(module, "profile changed", module.OnProfileChanged)
            allOkay = allOkay and ok
        elseif module and module.RefreshAll then
            local ok = self:SafeModuleCall(module, "profile refresh", module.RefreshAll, true)
            allOkay = allOkay and ok
        end
    end
    if self.HoverEffects then self.HoverEffects:RefreshAll() end
    self:RefreshModuleEvents()
    if self.SettingsUI then self.SettingsUI:Refresh() end
    return allOkay
end

function SUI:SwitchProfile(name)
    if type(name) ~= "string" or not self.db.profiles[name] then return false, SUI.Text("Профиль не найден.", "Profile not found.") end
    self.db.activeProfile = name
    local ok = self:ApplyActiveProfile()
    return ok, ok and nil or SUI.Text("Профиль выбран, но один из модулей не применил настройки. Подробности — в диагностике.", "Profile selected. A module failed to apply its settings. See Diagnostics.")
end

function SUI:CreateProfile(name, copyCurrent)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" or self.db.profiles[name] then return false, SUI.Text("Введите уникальное имя профиля.", "Enter a unique profile name.") end
    self.db.profiles[name] = DeepCopy(copyCurrent and self.profile or defaults)
    return self:SwitchProfile(name)
end

function SUI:RenameProfile(oldName, newName)
    newName = type(newName) == "string" and newName:match("^%s*(.-)%s*$") or ""
    if oldName == DEFAULT_PROFILE then return false, SUI.Text("Профиль Default нельзя переименовать.", "The Default profile cannot be renamed.") end
    if not self.db.profiles[oldName] or newName == "" or self.db.profiles[newName] then return false, SUI.Text("Введите уникальное имя профиля.", "Enter a unique profile name.") end
    self.db.profiles[newName], self.db.profiles[oldName] = self.db.profiles[oldName], nil
    if self.db.activeProfile == oldName then self.db.activeProfile = newName end
    local ok = self:ApplyActiveProfile()
    return ok, ok and nil or SUI.Text("Профиль переименован, но один из модулей не применил настройки.", "Profile renamed. A module failed to apply its settings.")
end

function SUI:DeleteProfile(name)
    if name == DEFAULT_PROFILE then return false, SUI.Text("Профиль Default нельзя удалить.", "The Default profile cannot be deleted.") end
    if not self.db.profiles[name] then return false, SUI.Text("Профиль не найден.", "Profile not found.") end
    self.db.profiles[name] = nil
    if self.db.activeProfile == name then self.db.activeProfile = DEFAULT_PROFILE end
    local ok = self:ApplyActiveProfile()
    return ok, ok and nil or SUI.Text("Профиль удален, но один из модулей не применил активный профиль.", "Profile deleted. A module failed to apply the active profile.")
end

function SUI:ResetProfile()
    self.db.profiles[self.db.activeProfile] = DeepCopy(defaults)
    return self:ApplyActiveProfile()
end

function SUI:ResetModuleProfile(key)
    if not defaults.modules[key] then return false end
    self.profile.modules[key] = DeepCopy(defaults.modules[key])
    local module = self:GetModule(key)
    local ok = true
    if module and module.OnProfileChanged then ok = self:SafeModuleCall(module, "module reset", module.OnProfileChanged)
    elseif module and module.RefreshAll then ok = self:SafeModuleCall(module, "module reset", module.RefreshAll, true) end
    self:RefreshModuleEvents()
    if self.SettingsUI then self.SettingsUI:Refresh() end
    return ok
end

function SUI:ResetModuleProfilePreserving(key, preservedSections)
    local moduleDefaults = defaults.modules[key]
    local current = self.profile.modules[key]
    if type(moduleDefaults) ~= "table" or type(current) ~= "table" then return false end
    local preserved = {}
    for _, section in ipairs(type(preservedSections) == "table" and preservedSections or {}) do
        if current[section] ~= nil then preserved[section] = DeepCopy(current[section]) end
    end
    self.profile.modules[key] = DeepCopy(moduleDefaults)
    for section, value in pairs(preserved) do self.profile.modules[key][section] = value end
    local module = self:GetModule(key)
    local ok = true
    if module and module.OnProfileChanged then ok = self:SafeModuleCall(module, "module partial reset", module.OnProfileChanged)
    elseif module and module.RefreshAll then ok = self:SafeModuleCall(module, "module partial reset", module.RefreshAll, true) end
    self:RefreshModuleEvents()
    if self.SettingsUI then self.SettingsUI:Refresh() end
    return ok
end

function SUI:ResetModuleSection(key, section)
    local moduleDefaults = defaults.modules[key]
    if type(moduleDefaults) ~= "table" or type(moduleDefaults[section]) ~= "table" then return false end
    self.profile.modules[key][section] = DeepCopy(moduleDefaults[section])
    local module = self:GetModule(key)
    local ok = true
    if module and module.OnProfileChanged then ok = self:SafeModuleCall(module, "module section reset", module.OnProfileChanged)
    elseif module and module.RefreshAll then ok = self:SafeModuleCall(module, "module section reset", module.RefreshAll, true) end
    self:RefreshModuleEvents()
    if self.SettingsUI then self.SettingsUI:Refresh() end
    return ok
end
