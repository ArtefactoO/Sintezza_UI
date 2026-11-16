local _, SUI = ...
local M = SUI:RegisterModule("shortestPathMinimap", {})
local Painter = {}
Painter.__index = Painter
local ADDON = "ShortestPathForever"
local SUPPORTED_VERSION = "v1.37.1"
local ART = "Interface\\AddOns\\Sintezza_UI\\Media\\ShortestPathDot.tga"
local WORLD_POOL = "ShortestPathForeverRoutePinTemplate"
local DOT_SIZE = 6.5
local ENTER_TIME, LEAVE_TIME = .24, .20
local SLIDE_TIME = .14 -- Bridge the 100 ms minimap samples before settling.

local function Number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function CanPaint(host)
    local layer = host and host.strokeLayer
    local animation = layer and layer.animation
    if layer and host.GetParent and host.IsVisible and host.GetFrameLevel and host.IsProtected
        and not host:IsProtected() and layer.SetAlpha and animation and animation.Play and animation.IsPlaying
        and type(host.lines) == "table" and type(host.underlines) == "table" and type(host.dots) == "table"
        and hooksecurefunc and CreateFrame then
        return true
    end
end

local function SupportedHost()
    local host = _G.ShortestPathForeverMinimapRoute
    if C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(ADDON, "Version") == SUPPORTED_VERSION and CanPaint(host) then
        return host
    end
end

function M:IsSupported()
    return SupportedHost() ~= nil
end

local function Fade(texture, from, to, duration)
    local group = texture:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(from)
    alpha:SetToAlpha(to)
    alpha:SetDuration(duration)
    alpha:SetSmoothing("IN_OUT")
    return group, alpha
end

local function NewMarker(frame)
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(ART)
    texture:Hide()
    local enter, enterAlpha = Fade(texture, 0, 1, ENTER_TIME)
    local scale = enter:CreateAnimation("Scale")
    scale:SetScaleFrom(.94, .94)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(ENTER_TIME)
    scale:SetSmoothing("OUT")
    if scale.SetOrigin then scale:SetOrigin("CENTER", 0, 0) end
    local leave, leaveAlpha = Fade(texture, 1, 0, LEAVE_TIME)
    local marker = {
        texture = texture, enter = enter, leave = leave,
        enterAlpha = enterAlpha, leaveAlpha = leaveAlpha,
    }
    leave:SetScript("OnFinished", function()
        marker.leaving = nil
        texture:Hide()
    end)
    return marker
end

local function Progress(alpha)
    local read = alpha.GetSmoothProgress or alpha.GetProgress
    local value = read and read(alpha)
    return Number(value) and math.max(0, math.min(1, value)) or 1
end

local function Reveal(marker)
    local from = 0
    if marker.leaving then
        from = marker.leaveFrom * (1 - Progress(marker.leaveAlpha))
        marker.leaving = nil
        marker.leave:Stop()
    end
    marker.active, marker.enterFrom = true, from
    marker.enterAlpha:SetFromAlpha(from)
    marker.texture:Show()
    marker.enter:Play()
end

function Painter:ReleaseMarker(marker, animate)
    if not marker.active and (not marker.leaving or animate) then return end
    self.moving[marker] = nil
    marker.active = nil
    if animate then
        local from = 1
        if marker.enter:IsPlaying() then
            from = marker.enterFrom + (1 - marker.enterFrom) * Progress(marker.enterAlpha)
        end
        marker.enter:Stop()
        marker.leaving = true
        marker.leaveFrom = from
        marker.leaveAlpha:SetFromAlpha(from)
        marker.leave:Play()
    else
        marker.leaving = nil
        marker.enter:Stop()
        marker.leave:Stop()
        marker.texture:Hide()
    end
end

function Painter:ReleaseNative()
    for region, alpha in pairs(self.native) do
        local current = region:GetAlpha()
        if Number(current) and current == 0 then region:SetAlpha(alpha) end
        self.native[region] = nil
    end
end

function Painter:Clear(animate)
    self:ReleaseNative()
    for _, marker in ipairs(self.markers) do
        self:ReleaseMarker(marker, animate)
    end
    self:RefreshMotion()
    if not animate then self.map = nil end
end

local function Anchor(line, host)
    if not (line and line.GetStartPoint and line.GetEndPoint and line.GetAlpha and line.SetAlpha) then return end
    local start, startTo, x1, y1 = line:GetStartPoint()
    local finish, finishTo, x2, y2 = line:GetEndPoint()
    if issecretvalue and (issecretvalue(start) or issecretvalue(finish)
        or issecretvalue(startTo) or issecretvalue(finishTo)) then return end
    if start == "TOPLEFT" and finish == "TOPLEFT" and startTo == host and finishTo == host
        and Number(x1) and Number(y1) and Number(x2) and Number(y2) then
        return (x1 + x2) / 2, (y1 + y2) / 2
    end
end

function Painter:Collect(width, height)
    local host, used = self.host, self.host.used
    if not Number(used) then return end
    if used == 0 then return 0 end
    local map, radius, px, py, cos, sin
    if self.world then
        map = host.drawMap
        local shown = host.view.map:GetMapID()
        if not (Number(map) and Number(shown) and map == shown and host:GetScale() == 1) then return end
    else
        local facing = host.lastFacing
        px, py, map, radius = host.lastX, host.lastY, host.lastMap, host.lastRadius
        if not (Number(radius) and radius > 0 and Number(facing)
            and Number(px) and Number(py) and Number(map)) then return end
        cos, sin = math.cos(facing), math.sin(facing)
    end
    local count = 0
    for index = 1, used do
        if host.dots[index] then
            local core, outline = host.lines[index], host.underlines[index]
            local x, y = Anchor(core, host)
            if not (x and outline and outline.SetAlpha and outline.GetAlpha and count < self.limit) then return end
            local alpha = core:GetAlpha()
            if not Number(alpha) then return end
            count = count + 1
            local point = self.points[count] or {}
            self.points[count] = point
            point.x, point.y = x, y
            if self.world then
                point.matchX, point.matchY = x, y
            else
                local east, north = (x * 2 / width - 1) * radius, (y * 2 / height + 1) * radius
                point.matchX, point.matchY = px + east * sin + north * cos, py - east * cos + north * sin
            end
            point.alpha = alpha == 0 and self.native[core] or alpha
            point.core, point.outline = core, outline
        end
    end
    return count, map, radius
end

function Painter:Match(point, map, generation, maxDistance)
    local best, free
    for _, marker in ipairs(self.markers) do
        if marker.generation ~= generation then
            if (marker.active or marker.leaving) and marker.map == map then
                local dx, dy = point.matchX - marker.matchX, point.matchY - marker.matchY
                local distance = dx * dx + dy * dy
                if distance <= maxDistance then
                    best, maxDistance = marker, distance
                end
            elseif not marker.active and not marker.leaving then
                free = free or marker
            end
        end
    end
    if best then return best end
    if free then return free end
    if #self.markers < self.limit * 2 then
        local marker = NewMarker(self.frame)
        self.markers[#self.markers + 1] = marker
        return marker
    end
end

function Painter:Suppress(region)
    local alpha = region:GetAlpha()
    if Number(alpha) and alpha ~= 0 then
        self.native[region] = alpha
        region:SetAlpha(0)
    end
end

local function Place(frame, marker, x, y)
    if marker.x == x and marker.y == y then return end
    marker.x, marker.y = x, y
    marker.texture:SetPoint("CENTER", frame, "TOPLEFT", x, y)
end

function Painter:Move(marker, x, y, snap)
    if snap or not marker.active then
        self.moving[marker] = nil
        marker.targetX, marker.targetY = x, y
        Place(self.frame, marker, x, y)
    elseif marker.targetX ~= x or marker.targetY ~= y then
        marker.fromX, marker.fromY = marker.x, marker.y
        marker.targetX, marker.targetY = x, y
        self.moving[marker] = 0
    end
end

function Painter:Animate(frame, elapsed)
    for marker, age in pairs(self.moving) do
        age = age + elapsed
        if age >= SLIDE_TIME then
            Place(frame, marker, marker.targetX, marker.targetY)
            self.moving[marker] = nil
        else
            local t = age / SLIDE_TIME
            t = t + t * t * (1 - t)
            Place(frame, marker, marker.fromX + (marker.targetX - marker.fromX) * t,
                marker.fromY + (marker.targetY - marker.fromY) * t)
            self.moving[marker] = age
        end
    end
    self:RefreshMotion()
end

function Painter:RefreshMotion()
    local active = next(self.moving) ~= nil
    if self.frame and self.animating ~= active then
        self.animating = active
        self.frame:SetScript("OnUpdate", active and self.onUpdate or nil)
    end
end

function Painter:DeferHide()
    if self.hideQueued then return end
    self.hideQueued = true
    SUI:After(0, M, "Shortest Path world map hide", function()
        self.hideQueued = nil
        if not self.host:IsVisible() then
            self:Clear(not InCombat() and self.host:GetParent():IsVisible())
        end
    end)
end

function Painter:Draw()
    local host = self.host
    if (not self.world and host ~= _G.ShortestPathForeverMinimapRoute)
        or host:IsProtected() or host.strokeLayer.animation:IsPlaying() then
        self:Clear(false)
        return
    end
    if not host:IsVisible() then
        if self.world then
            -- Shortest Path releases and reacquires this pin in one refresh.
            self:DeferHide()
        else
            self:Clear(host:GetParent():IsVisible())
        end
        return
    end

    local width, height = host:GetSize()
    local scale = host:GetEffectiveScale()
    if not (Number(width) and width > 0 and Number(height) and height > 0 and Number(scale) and scale > 0) then
        self:Clear(false)
        return
    end
    local count, map, radius = self:Collect(width, height)
    if not count or count == 0 then
        self:Clear(count == 0)
        return
    end

    self:ReleaseNative()
    if self.map and self.map ~= map then self:Clear(false) end
    local resized = self.radius ~= radius or self.width ~= width or self.height ~= height or self.scale ~= scale
    self.map = map
    self.radius, self.width, self.height, self.scale = radius, width, height, scale
    local generation = (self.generation or 0) + 1
    self.generation = generation
    local size = DOT_SIZE / scale
    local maxDistance = radius and (9 * radius / (scale * math.min(width, height))) ^ 2 or (5 / scale) ^ 2
    for index = 1, count do
        local point = self.points[index]
        local marker = self:Match(point, map, generation, maxDistance)
        if marker then
            local texture = marker.texture
            if marker.size ~= size then
                texture:SetSize(size, size)
                marker.size = size
            end
            if marker.alpha ~= point.alpha then
                texture:SetAlpha(point.alpha)
                marker.alpha = point.alpha
            end
            self:Move(marker, point.x, point.y, resized)
            if not marker.active then Reveal(marker) end
            marker.map, marker.generation = map, generation
            marker.matchX, marker.matchY = point.matchX, point.matchY
            self:Suppress(point.core)
            self:Suppress(point.outline)
        end
    end
    for _, marker in ipairs(self.markers) do
        if marker.generation ~= generation then self:ReleaseMarker(marker, true) end
    end
    self:RefreshMotion()
end

local function Connect(host, world)
    local self = setmetatable({
        host = host, world = world, limit = world and 384 or 96,
        markers = {}, native = {}, points = {}, moving = {},
    }, Painter)
    self.frame = CreateFrame("Frame", nil, host:GetParent())
    self.frame:SetAllPoints(world and host.view.canvas or host)
    self.frame:SetFrameLevel(host:GetFrameLevel() + 1)
    self.frame:EnableMouse(false)
    self.onUpdate = function(frame, elapsed) self:Animate(frame, elapsed) end
    local function Draw() self:Draw() end
    local context = world and "Shortest Path world map draw" or "Shortest Path minimap draw"

    -- Route.lua ends each settled Paint by restoring its stroke layer's alpha.
    self.repaint = function()
        if not M.enabled or self.failed or (world and M.world ~= self) then return end
        if not world and host.revision ~= M.worldRevision then
            M.worldRevision = host.revision
            M:QueueWorld()
        end
        if not SUI:SafeModuleCall(M, context, Draw) then
            self.failed = true
            self:Clear(false)
        end
    end
    hooksecurefunc(host.strokeLayer, "SetAlpha", self.repaint)
    hooksecurefunc(host.strokeLayer.animation, "Play", self.repaint)
    if world then
        host:HookScript("OnHide", function()
            if M.enabled and M.world == self then self:DeferHide() end
        end)
    end
    return self
end

local function FindWorldPin(map)
    local canvas = map.GetCanvas and map:GetCanvas()
    if not (canvas and canvas.GetChildren) then return end
    for _, root in ipairs({ canvas:GetChildren() }) do
        for _, layer in ipairs({ root:GetChildren() }) do
            for _, pin in ipairs({ layer:GetChildren() }) do
                local view = pin.view
                if view and view.canvas == canvas and view.pools and pin.pool
                    and view.pools[WORLD_POOL] == pin.pool and CanPaint(pin) then
                    return pin
                end
            end
        end
    end
end

function M:QueueWorld(delay)
    local map = self.watchedMap
    local settings = _G.ShortestPathForeverDB
    if not self.enabled or self.world or self.worldQueued or InCombat() or not (map and map:IsVisible()) then return end
    if settings and settings.mapLine == false then return end
    self.worldQueued = true
    SUI:After(delay or 0, self, "find Shortest Path world map pin", function()
        self.worldQueued = nil
        if not self.enabled or self.world or InCombat() or self.watchedMap ~= map or not map:IsVisible() then return end
        local pin = FindWorldPin(map)
        if pin then
            self.world = Connect(pin, true)
            self.world.repaint()
        elseif not delay then
            self:QueueWorld(.1)
        end
    end)
end

function M:WatchWorld()
    local map = _G.WorldMapFrame
    if not (map and map.HookScript) then return end
    if self.watchedMap ~= map then
        if self.world then
            self.world:Clear(false)
            self.world = nil
        end
        self.watchedMap = map
        map:HookScript("OnShow", function()
            if self.watchedMap == map then self:QueueWorld() end
        end)
    end
    self:QueueWorld()
end

function M:OnProfileChanged()
    local profile = SUI:GetModuleProfile(self.key)
    local host = SUI.isForever and profile and profile.enabled and SupportedHost()
    if not host or (self.minimap and self.minimap.host ~= host) then
        self.enabled = false
        if self.minimap then self.minimap:Clear(false) end
        if self.world then self.world:Clear(false) end
        return
    end
    if not self.minimap then
        if InCombat() then return end
        self.minimap = Connect(host, false)
    end
    self.enabled = true
    self:WatchWorld()
    self.minimap.failed = nil
    self.minimap.repaint()
    if self.world then
        self.world.failed = nil
        self.world.repaint()
    end
end

function M:OnEvent(event, addon)
    if event == "ADDON_LOADED" and addon ~= ADDON and addon ~= "Blizzard_WorldMap" then return end
    self:OnProfileChanged()
end

function M:WantsEvent()
    local profile = SUI:GetModuleProfile(self.key)
    return profile and profile.enabled == true
end

function M:Initialize()
    if not SUI.isForever then return end
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        SUI:RegisterModuleEvent(self, event)
    end
    self:OnProfileChanged()
end
