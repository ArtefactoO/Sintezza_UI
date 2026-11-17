local _, SUI = ...
local M = SUI:RegisterModule("shortestPathMinimap", {})
local Painter = {}
Painter.__index = Painter
local ADDON = "ShortestPathForever"
local ART = "Interface\\AddOns\\Sintezza_UI\\Media\\ShortestPathDot.tga"
local WORLD_POOL = "ShortestPathForeverRoutePinTemplate"
local TINT_ART = "Interface\\AddOns\\Sintezza_UI\\Media\\ShortestPathDotTint.tga"
local ENTER_TIME, LEAVE_TIME = .24, .20
local SLIDE_TIME = .14 -- Bridge the 100 ms minimap samples before settling.

local function Number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function CanPaint(host)
    local hostType = type(host)
    if hostType ~= "table" and hostType ~= "userdata" then return false end
    local layer = host.strokeLayer
    local layerType = type(layer)
    if layerType ~= "table" and layerType ~= "userdata" then return false end
    local animation = layer.animation
    local animationType = type(animation)
    if animationType ~= "table" and animationType ~= "userdata" then return false end
    return animation and type(layer.SetAlpha) == "function"
        and type(animation.Play) == "function" and type(animation.IsPlaying) == "function"
        and type(host.GetParent) == "function" and type(host.IsVisible) == "function"
        and type(host.GetFrameLevel) == "function" and type(host.GetEffectiveScale) == "function"
        and type(host.GetSize) == "function" and type(host.IsProtected) == "function"
        and not host:IsProtected()
        and type(host.lines) == "table" and type(host.underlines) == "table" and type(host.dots) == "table"
        and type(hooksecurefunc) == "function" and type(CreateFrame) == "function"
end

local function SupportedHost()
    local host = _G.ShortestPathForeverMinimapRoute
    if CanPaint(host) then return host end
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

function M:GetDotStyle()
    local profile = SUI:GetModuleProfile("shortestPathMinimap") or {}
    local defaults = SUI.RouteDotDefaults
    local size, color = tonumber(profile.dotSize), profile.dotColor
    if not size or size ~= size then size = defaults.size end
    local parts = type(color) == "table" and color or defaults.color
    return math.max(4, math.min(16, size)), parts
end

local function StyleDot(marker, size, color)
    local r, g, b, a = color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1
    local gold = SUI.RouteDotDefaults.color
    local texture = marker.texture
    if marker.size ~= size then
        texture:SetSize(size, size)
        marker.size = size
    end
    if r == marker.r and g == marker.g and b == marker.b and a == marker.colorAlpha then return end
    local original = r == gold[1] and g == gold[2] and b == gold[3]
    texture:SetTexture(original and ART or TINT_ART)
    if original then texture:SetVertexColor(1, 1, 1, a) else texture:SetVertexColor(r, g, b, a) end
    marker.r, marker.g, marker.b, marker.colorAlpha = r, g, b, a
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

function Painter:PaintMarkers(count, map, snap, maxDistance, scale)
    local generation = (self.generation or 0) + 1
    self.generation = generation
    local size, color = M:GetDotStyle()
    for index = 1, count do
        local point = self.points[index]
        local marker = self:Match(point, map, generation, maxDistance)
        if marker then
            local texture = marker.texture
            StyleDot(marker, size / scale, color)
            if marker.alpha ~= point.alpha then
                texture:SetAlpha(point.alpha)
                marker.alpha = point.alpha
            end
            self:Move(marker, point.x, point.y, snap)
            if not marker.active then Reveal(marker) end
            marker.map, marker.generation = map, generation
            marker.matchX, marker.matchY = point.matchX, point.matchY
            if point.core then self:Suppress(point.core) end
            if point.outline then self:Suppress(point.outline) end
        end
    end
    for _, marker in ipairs(self.markers) do
        if marker.generation ~= generation then self:ReleaseMarker(marker, true) end
    end
    self:RefreshMotion()
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
    local maxDistance = radius and (9 * radius / (scale * math.min(width, height))) ^ 2 or (5 / scale) ^ 2
    self:PaintMarkers(count, map, resized, maxDistance, scale)
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

function M:CreateRoutePreview(parent, imageName, points, startX, startY)
    local assets = "Interface\\AddOns\\Sintezza_UI\\Media\\MapPreview\\"
    local art = assets .. imageName
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(147, 152)
    frame:SetClipsChildren(true)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexCoord(0, 147 / 256, 0, 152 / 256)
    local previewLayer = CreateFrame("Frame", nil, frame)
    previewLayer:SetAllPoints()
    local arrow = previewLayer:CreateTexture(nil, "OVERLAY")
    local arrowSize = imageName == "Mini" and 38 or 61
    arrow:SetSize(arrowSize, arrowSize)
    arrow:SetTexture(assets .. "PlayerArrow.png")

    local painter = setmetatable({ frame = previewLayer, markers = {}, native = {}, moving = {},
        points = {}, limit = #points }, Painter)
    painter.onUpdate = function(owner, elapsed) painter:Animate(owner, elapsed) end

    local path = { { startX, startY, 0 } }
    local total = 0
    for index = #points, 1, -1 do
        local a, b = path[#path], points[index]
        total = total + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        path[#path + 1] = { b[1], b[2], total }
    end

    local function Position(distance)
        local segment = 2
        while segment < #path and path[segment][3] < distance do segment = segment + 1 end
        local a, b = path[segment - 1], path[segment]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local part = (distance - a[3]) / (b[3] - a[3])
        local x, y = a[1] + dx * part, a[2] + dy * part
        -- Pan the map under the arrow as the player advances. Stable map coordinates
        -- let the painter match and glide the existing markers between redraws.
        local panX, panY = (startX - x) * .46, (startY - y) * .24
        arrow:SetPoint("CENTER", frame, "TOPLEFT", x + panX, -(y + panY))
        arrow:SetRotation(math.atan2(-dy, dx) - 2.12)
        -- The sample art has no extra canvas beyond its crop, so use a slight zoom.
        local left, top = (19 - panX * .72) / 256, (28 - panY * .72) / 256
        background:SetTexCoord(left, left + 108 / 256, top, top + 112 / 256)
        return panX, panY
    end

    local lookAhead = total * .62

    local function Paint(distance, panX, panY)
        local count = 0
        for index, point in ipairs(points) do
            local ahead = path[#path - index + 1][3] - distance
            if ahead > 0 and ahead <= lookAhead then
                count = count + 1
                local item = painter.points[count] or {}
                painter.points[count] = item
                item.x, item.y = point[1] + panX, -(point[2] + panY)
                item.matchX, item.matchY, item.alpha = point[1], point[2], 1
            end
        end
        painter:PaintMarkers(count, imageName, false, 1, math.max(.1, frame:GetEffectiveScale()))
    end

    local function Stop()
        frame.elapsed, frame.nextSample = nil, nil
        frame:SetScript("OnUpdate", nil)
        painter:Clear(false)
    end

    function frame:Refresh()
        if not self:IsVisible() then return end
        local enabled = SUI:GetFeatureSetting("shortestPathMinimap") == true
        background:SetTexture(art .. (enabled and "Travel.png" or (SUI:IsAddonLoaded(ADDON) and ".png" or "Clean.png")))
        arrow:SetShown(enabled)
        if not enabled then
            Stop()
            background:SetTexCoord(0, 147 / 256, 0, 152 / 256)
        elseif not self.elapsed then
            Paint(0, Position(0))
        end
    end

    function frame:Play()
        if not SUI:GetFeatureSetting("shortestPathMinimap") then return end
        Stop()
        self.elapsed, self.nextSample = 0, 0
        Position(0)
        self:SetScript("OnUpdate", function(owner, elapsed)
            local time = owner.elapsed + elapsed
            if time >= 6 then
                Stop()
                Paint(0, Position(0))
                return
            end
            owner.elapsed = time
            local distance = total * math.min(1, time / 5.5)
            local panX, panY = Position(distance)
            if time >= owner.nextSample then
                owner.nextSample = time + .1
                Paint(distance, panX, panY)
            end
        end)
    end
    frame:SetScript("OnShow", frame.Refresh)
    frame:SetScript("OnHide", Stop)
    return frame
end

local function FindWorldPin(map)
    local canvas = map.GetCanvas and map:GetCanvas()
    if not (canvas and canvas.GetChildren) then return end
    for _, root in ipairs({ canvas:GetChildren() }) do
        for _, layer in ipairs({ root:GetChildren() }) do
            for _, pin in ipairs({ layer:GetChildren() }) do
                local view = pin.view
                if type(view) == "table" and view.map == map and view.canvas == canvas
                    and type(view.pools) == "table" and pin.pool and view.pools[WORLD_POOL] == pin.pool
                    and type(pin.GetScale) == "function" and type(pin.HookScript) == "function" and CanPaint(pin) then
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
