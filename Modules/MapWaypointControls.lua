local _, SUI = ...
local M = SUI:RegisterModule("mapWaypointControls", {})
local PRIORITY = 2000 -- Before OpenMap's drop-pin handler (1000).
local PIN_LEVEL = 8650
local ROUTE_OWNER = "Sintezza_UI"
local OPENXP_OWNER = "OpenXP"
local GOAL_TEMPLATE = "ShortestPathForeverGoalPinTemplate"

local function OpenWorldMapModule()
    local open = _G.OpenMap
    if open and open.GetModule then return open:GetModule("worldmap") end
end

local function ShortestPath()
    local addon = _G.ShortestPathForever
    return addon and addon.API
end

local function OwnsRoute(api)
    return api and api.CurrentStop and api.CurrentStop(ROUTE_OWNER) ~= nil
end

local function OpenXPRoute(api)
    return api and api.CurrentStop and SUI:IsAddonLoaded("OpenXP")
        and not SUI:IsAddonLoaded("RXPGuides")
        and (api.CurrentStop(OPENXP_OWNER) or api.CurrentStop("RestedXP"))
end

local function RouteDrawsStop(map)
    local markers = _G.ForeverMapMarkers
    local read = markers and markers.ShortestPathForever
    if not read then return false end
    for _, marker in ipairs(read(map) or {}) do
        -- Our itinerary has exactly one stop. Docks and portals belong to
        -- the route's transport layer and are not the destination.
        if marker.kind == "stop" then return true end
    end
    return false
end

function M:GuardRouteStop(canvas)
    -- Shortest Path's stop pin handles right-click outside the map's click
    -- registry. Leave removal of our route to the Ctrl+right-click watcher.
    if self.stopCanvas ~= canvas then
        self.stopCanvas, self.stopPool = canvas, nil
    end
    if not self.stopPool then
        for _, host in ipairs({ canvas:GetChildren() }) do
            for _, layer in ipairs({ host:GetChildren() }) do
                for _, pin in ipairs({ layer:GetChildren() }) do
                    if pin.marker == "stop" and pin.pool and pin.pool.template == GOAL_TEMPLATE then
                        self.stopPool = pin.pool
                        break
                    end
                end
                if self.stopPool then break end
            end
            if self.stopPool then break end
        end
    end
    for _, pin in ipairs(self.stopPool and self.stopPool.active or {}) do
        local handler = pin.OnMouseClickAction
        self.stopHandlers = self.stopHandlers or setmetatable({}, { __mode = "k" })
        if type(handler) == "function" and self.stopHandlers[pin] ~= handler then
            local function guarded(frame, button, ...)
                if button == "RightButton" and self.enabled and self.routePoint and OwnsRoute(ShortestPath()) then
                    return
                end
                return handler(frame, button, ...)
            end
            self.stopHandlers[pin] = guarded
            pin.OnMouseClickAction = guarded
        end
    end
end

local function Allowed()
    return not (InCombatLockdown and InCombatLockdown())
end

local function Modified()
    return IsControlKeyDown() and not IsShiftKeyDown() and not IsAltKeyDown()
end

local function Number(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function Fraction(value)
    return Number(value) and value >= 0 and value <= 1
end

local function Coordinates(id, x, y)
    return Number(id) and id > 0 and Fraction(x) and Fraction(y)
end

local function ReadPosition(position)
    if (issecretvalue and issecretvalue(position)) or (type(position) ~= "table" and type(position) ~= "userdata") then return end
    local x, y
    if type(position.GetXY) == "function" then
        x, y = position:GetXY()
    else
        x, y = position.x, position.y
    end
    if Fraction(x) and Fraction(y) then return x, y end
end

local function ReadMapPoint(point)
    if (issecretvalue and issecretvalue(point)) or (type(point) ~= "table" and type(point) ~= "userdata") then return end
    local x, y = ReadPosition(point.position)
    if Coordinates(point.uiMapID, x, y) then return point.uiMapID, x, y end
end

local function GuideCaller()
    if not debugstack then return end
    -- Ignore our hook's own frame. The first addon above it is the caller,
    -- so a native route bend written by Shortest Path cannot be mistaken
    -- for the guide's destination, even when the guide started that journey.
    local stack = debugstack(2, 10, 0)
    if type(stack) ~= "string" or (issecretvalue and issecretvalue(stack)) then return end
    for line in stack:lower():gsub("\\", "/"):gmatch("[^\r\n]+") do
        if line:match("%.lua[\"%]]*:%d+") and not line:find("/modules/mapwaypointcontrols.lua", 1, true) then
            if line:find("/flowup/core.lua", 1, true) then return "FlowUp" end
            if line:find("/foreverguide/core.lua", 1, true) then return "ForeverGuide" end
            return
        end
    end
end

local function StitchedAPI()
    local api = _G.OpenMapAPI
    if api and api.major == 1 and api.IsStitched and api.IsStitched() then
        return api
    end
end

local function CursorPoint(map, u, v)
    local api = StitchedAPI()
    if api then
        if not (Number(u) and Number(v)) and api.CursorPosition then
            u, v = api.CursorPosition()
        end
        if Number(u) and Number(v) then
            local point = { u = u, v = v }
            local id = api.MapAt and api.MapAt(u, v)
            if id and api.MapFromWorld then
                local x, y = api.MapFromWorld(id, u, v)
                if Coordinates(id, x, y) then point.mapID, point.x, point.y = id, x, y end
            end
            return point
        end
    end
    local x, y = map:GetNormalizedCursorPosition()
    local id = map:GetMapID()
    if Coordinates(id, x, y) then return { mapID = id, x = x, y = y } end
end

function M:ClearExternal()
    if not Allowed() then return false end

    local spf = ShortestPath()
    if OwnsRoute(spf) and spf.Cancel then
        spf.Cancel(ROUTE_OWNER)
    elseif spf and spf.Cancel and spf.CurrentStop and spf.CurrentStop(OPENXP_OWNER) then
        spf.Cancel(OPENXP_OWNER)
    else
        -- The public cancel only accepts routes created by the calling owner.
        local binding = _G.ShortestPathForeverClearJourneyButton
        local handler = binding and binding.GetScript and binding:GetScript("OnClick")
        if handler then
            handler(binding, "LeftButton")
        elseif spf and spf.Active and spf.Active() then
            return false
        end
    end

    local navigation = _G.WaypointUIAPI and _G.WaypointUIAPI.Navigation
    if navigation and navigation.GetUserNavigation and navigation.ClearUserNavigation
        and navigation.GetUserNavigation() then
        -- We clear the shared point below. Suppress any advance to another pin.
        navigation.ClearUserNavigation(true, true)
    end

    -- Shortest Path may have restored a previous point as part of its reset.
    -- Clear that shared point last, along with OpenMap's temporary fallback.
    local open = OpenWorldMapModule()
    if open and open.ClearPin then
        open.ClearPin()
    elseif C_Map and C_Map.ClearUserWaypoint then
        C_Map.ClearUserWaypoint()
    end
    return true
end

function M:ResetNavigation()
    self.clearingExternal = true
    local ok, cleared = SUI:SafeModuleCall(self, "clear other navigation", self.ClearExternal)
    self.clearingExternal = nil
    return ok and cleared == true
end

function M:Clear()
    if not self:ApplyNavigation() then return false end
    self.point = nil
    self.routePoint = nil
    self.externalPending = nil
    if self.pin then self.pin:Hide() end
    return true
end

function M:Place(map, u, v)
    local point = CursorPoint(map, u, v)
    return point ~= nil and self:ReplacePoint(point, true)
end

local function Project(map, point)
    local id = map:GetMapID()
    local api = StitchedAPI()
    if api and id and api.MapFromWorld then
        local u, v = point.u, point.v
        if not u and point.mapID and api.WorldFromMap then
            u, v = api.WorldFromMap(point.mapID, point.x, point.y)
        end
        if Number(u) and Number(v) then
            local x, y = api.MapFromWorld(id, u, v)
            if Number(x) and Number(y) then return x, y end
        end
    end
    if not point.mapID then return end
    if id == point.mapID then
        return point.x, point.y
    elseif id and CreateVector2D and C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos then
        local continent, world = C_Map.GetWorldPosFromMapPos(point.mapID, CreateVector2D(point.x, point.y))
        if not (continent and world) then return end
        local result, position = C_Map.GetMapPosFromWorldPos(continent, world, id)
        if result == id and position then
            return ReadPosition(position)
        end
    end
end

function M:Draw()
    local map, point = self.map, self.point
    local canvas = map and map.GetCanvas and map:GetCanvas()
    local x, y
    if self.enabled and canvas and point and map:IsVisible() then x, y = Project(map, point) end
    -- Shortest Path hides its map layer in combat. Keep our own pin visible
    -- until the route can supply its destination again.
    if Allowed() and Number(x) and Number(y) and point == self.routePoint
        and OwnsRoute(ShortestPath()) and RouteDrawsStop(map) then
        self:GuardRouteStop(canvas)
        if self.pin then self.pin:Hide() end
        return true
    end
    local w, h, scale
    if Number(x) and Number(y) then
        w, h = canvas:GetSize()
        scale = canvas:GetEffectiveScale() / map:GetEffectiveScale()
    end
    if not w or w <= 0 or h <= 0 or scale <= 0 then
        if self.pin then self.pin:Hide() end
        return false
    end
    if not self.pin then
        -- Follow the canvas like our party markers. Keep the position on a
        -- canvas child and counter-scale only the artwork, not its anchor.
        local pin = CreateFrame("Frame", nil, canvas)
        pin:SetSize(1, 1)
        local face = CreateFrame("Frame", nil, pin)
        face:SetSize(30, 30)
        face:SetPoint("CENTER")
        local icon = face:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Waypoint-MapPin-Tracked") then
            icon:SetAtlas("Waypoint-MapPin-Tracked")
        else
            icon:SetTexture("Interface\\Minimap\\Ping\\ping5")
        end
        self.pin, self.face = pin, face
    end
    local pin = self.pin
    local offsetX, offsetY = x * w, -y * h
    if pin.canvas ~= canvas or pin.x ~= offsetX or pin.y ~= offsetY then
        if pin:GetParent() ~= canvas then pin:SetParent(canvas) end
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", offsetX, offsetY)
        pin.canvas, pin.x, pin.y = canvas, offsetX, offsetY
    end
    local level = math.min((map.ScrollContainer or map):GetFrameLevel() + PIN_LEVEL, PIN_LEVEL + 1000)
    if self.face:GetFrameLevel() ~= level then self.face:SetFrameLevel(level) end
    if self.face:GetScale() ~= 1 / scale then self.face:SetScale(1 / scale) end
    pin:Show()
    return pin:IsVisible()
end

function M:StartRoute(point)
    local api = ShortestPath()
    if not (api and api.Navigate and api.CurrentStop and api.Cancel) or not Coordinates(point.mapID, point.x, point.y) then return end
    if api.Navigate(ROUTE_OWNER, point.mapID, point.x, point.y, point.title or SUI.Text("Личная метка", "Personal waypoint")) then
        self.routePoint = point
        self:Draw()
    end
end

function M:ApplyNavigation(point, navigate)
    if not Allowed() then
        self.deferredNavigation = { point = point, navigate = navigate }
        return true
    end
    if not self:ResetNavigation() then return false end
    self.deferredNavigation = nil
    self.externalPending, self.routePoint = nil, nil
    if point and navigate then SUI:SafeModuleCall(self, "route to personal waypoint", self.StartRoute, point) end
    return true
end

function M:ReplacePoint(point, navigate, allowOffscreen)
    local previous = self.point
    self.point = point
    local ok, visible = SUI:SafeModuleCall(self, "draw personal waypoint", self.Draw)
    if ok and (visible or allowOffscreen) and self:ApplyNavigation(point, navigate) then return true end
    -- Keep the shared point if the map isn't ready or can't project it.
    self.point = previous
    SUI:SafeModuleCall(self, "restore personal waypoint", self.Draw)
    return false
end

function M:AdoptExternal(openMapPoint, controlHeld, guidePoint)
    if not self.enabled or self.clearingExternal or self.deferredNavigation then return end
    if guidePoint then
        if not SUI:IntegrationEnabled("guides") then return end
        -- Guides can send a destination before opening the map or while a
        -- different zone is shown. Store the point even if it can't draw yet.
        self:ReplacePoint(guidePoint, true, true)
        return
    end
    if not Allowed() then return end
    if openMapPoint then
        self:ReplacePoint(openMapPoint, true)
        return
    end
    if not controlHeld then return end

    -- Shortest Path can publish a waypoint while planning or replace it at the next bend.
    local spf = ShortestPath()
    if spf and spf.Journey then
        local journey, reason = spf.Journey()
        if journey or reason == "loading" then return end
    end
    if OwnsRoute(spf) or OpenXPRoute(spf) or (spf and spf.Active and spf.Active()) then return end
    local id, x, y = ReadMapPoint(C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint())
    if not id then
        local open = OpenWorldMapModule()
        if open and open.WaypointPoint then id, x, y = open.WaypointPoint() end
    end
    if Coordinates(id, x, y) then
        self:ReplacePoint({ mapID = id, x = x, y = y })
    end
end

function M:QueueExternal(openMapPoint, controlHeld, guidePoint)
    if not self.enabled or self.clearingExternal then return end
    if self.externalPending then
        local request = self.externalPending
        local previous = request.guidePoint
        if guidePoint and guidePoint.source == "ForeverGuide" and (request.guideBatch
            or (previous and previous.source == guidePoint.source and (previous.mapID ~= guidePoint.mapID
                or previous.x ~= guidePoint.x or previous.y ~= guidePoint.y))) then
            -- "All books in TomTom" is a batch. One personal pin cannot
            -- represent it, so leave the provider's own handling in charge.
            request.guideBatch, request.guidePoint = true, nil
        elseif openMapPoint or guidePoint then
            request.openMapPoint, request.guidePoint = openMapPoint, guidePoint
        end
        if controlHeld then self.externalPending.controlHeld = true end
        return
    end
    local request = { openMapPoint = openMapPoint, controlHeld = controlHeld, guidePoint = guidePoint }
    self.externalPending = request
    SUI:After(0, self, "adopt personal waypoint", function()
        if self.externalPending ~= request then return end
        self.externalPending = nil
        if not request.guideBatch or request.openMapPoint or request.guidePoint then
            self:AdoptExternal(request.openMapPoint, request.controlHeld, request.guidePoint)
        end
    end)
end

function M:WatchGuideWaypoints()
    if not (self.enabled and SUI:IntegrationEnabled("guides") and hooksecurefunc
        and (SUI:IsAddonLoaded("FlowUp") or SUI:IsAddonLoaded("ForeverGuide"))) then return end
    local tomtom = _G.TomTom
    if not SUI:IsAddonLoaded("TomTom") and tomtom and type(tomtom.AddWaypoint) == "function" then
        self.guideTomTomHooks = self.guideTomTomHooks or setmetatable({}, { __mode = "k" })
        if not self.guideTomTomHooks[tomtom] then
            hooksecurefunc(tomtom, "AddWaypoint", function(_, id, x, y, opts)
                if not (self.enabled and SUI:IntegrationEnabled("guides") and Coordinates(id, x, y) and type(opts) == "table"
                    and opts.persistent == false) then return end
                local source = GuideCaller()
                if not source then return end
                local title = opts.title
                if type(title) ~= "string" or (issecretvalue and issecretvalue(title)) then title = nil end
                self:QueueExternal(nil, nil, { mapID = id, x = x, y = y, title = title, source = source })
            end)
            self.guideTomTomHooks[tomtom] = true
        end
    end
    if not self.guideNativeHook and C_Map and C_Map.SetUserWaypoint and C_Map.GetUserWaypoint then
        hooksecurefunc(C_Map, "SetUserWaypoint", function(point)
            if not self.enabled or not SUI:IntegrationEnabled("guides") then return end
            local source = GuideCaller()
            if not source then return end
            local id, x, y = ReadMapPoint(point)
            if not id then return end
            local actualId, actualX, actualY = ReadMapPoint(C_Map.GetUserWaypoint())
            if id == actualId and math.abs(x - actualX) < .000001 and math.abs(y - actualY) < .000001 then
                self:QueueExternal(nil, nil, { mapID = id, x = x, y = y, source = source })
            end
        end)
        self.guideNativeHook = true
    end
end

local function OpenXPStop(guide)
    local frame = guide.arrowFrame
    local element = frame.element
    local profile = guide.settings and guide.settings.profile
    local step = element and element.step
    if not (guide.currentGuide and profile and profile.showEnabled ~= false
        and step and step.active and element.arrow and not element.hidden and not element.skip
        and not (element.generated and element.generated ~= 0)
        and not (element.parent and (element.parent.completed or element.parent.skip))
        and not (element.text and element.completed)
        and (not guide.hideArrow or frame.wrongContinent)) then return end
    local x, y = element.x, element.y
    if not (Number(x) and Number(y)) then return end
    x, y = x / 100, y / 100
    if not Coordinates(element.zone, x, y) then return end
    local title = element.title
    if not (issecretvalue and issecretvalue(title)) and title == nil then title = step.arrowtext end
    if not (issecretvalue and issecretvalue(title)) and title == nil then title = step.title end
    return element.zone, x, y, title
end

local OPENXP_ARROW_REGIONS = { "texture", "text", "dialBg", "dialRing", "arrived", "oxpDist", "oxpLabel" }

function M:RefreshOpenXPArrow(api)
    if not Allowed() then
        if self.openXPGuide then self.openXPDeferred = true end
        return
    end
    local frame = self.openXPGuide and self.openXPGuide.arrowFrame
    local settings = _G.ShortestPathForeverDB
    local hide = self.enabled and SUI:IntegrationEnabled("openxp") and frame and settings and settings.restedxpHideArrow ~= false
        and OpenXPRoute(api) and api.Active and api.Active()
    if not hide then
        if self.openXPArrowAlpha then
            for region, alpha in pairs(self.openXPArrowAlpha) do region:SetAlpha(alpha) end
            self.openXPArrowAlpha = nil
        end
        return
    end

    -- OpenXP updates the pointer's visibility itself. Hide the regions without
    -- hiding its frame, which the guide uses to decide when to advance.
    local saved = self.openXPArrowAlpha or setmetatable({}, { __mode = "k" })
    self.openXPArrowAlpha = saved
    for _, key in ipairs(OPENXP_ARROW_REGIONS) do
        local region = frame[key]
        if region and saved[region] == nil and region.GetAlpha and region.SetAlpha then
            local alpha = region:GetAlpha()
            if Number(alpha) then
                saved[region] = alpha
                region:SetAlpha(0)
            end
        end
    end
end

function M:SyncOpenXP()
    if not Allowed() then
        self.openXPDeferred = true
        return
    end
    self.openXPDeferred = nil
    local api = ShortestPath()
    self:RefreshOpenXPArrow(api)
    if not (api and (api.version == 1 or api.version == 2) and type(api.NavigateRoute) == "function"
        and type(api.CurrentStop) == "function" and type(api.Cancel) == "function"
        and type(api.Active) == "function") then return end
    local guide = self.openXPGuide
    local settings = _G.ShortestPathForeverDB
    local map, x, y, title
    if self.enabled and SUI:IntegrationEnabled("openxp") and guide and settings
        and settings.restedxp ~= false and settings.journey ~= false then
        map, x, y, title = OpenXPStop(guide)
    end
    if not map then
        self.openXPLast = nil
        if api.CurrentStop(OPENXP_OWNER) then api.Cancel(OPENXP_OWNER) end
        return
    end
    local previous = self.openXPLast
    if previous and previous.map == map and math.abs(previous.x - x) < .001
        and math.abs(previous.y - y) < .001 then return end
    local owned = api.CurrentStop(OPENXP_OWNER)
    local otherJourney = api.CurrentStop("RestedXP") or (not owned and api.Active())
    if not (owned or otherJourney) and api.Journey then
        local journey, reason = api.Journey()
        if reason == "loading" then return end
        otherJourney = journey
    end
    if (issecretvalue and issecretvalue(title)) or type(title) ~= "string" or title == "" then title = "OpenXP" end
    local stop = { map = map, x = x, y = y, title = title, hold = true }
    self.openXPLast = stop
    if otherJourney then return end
    if not api.NavigateRoute(OPENXP_OWNER, { stop }) and owned then api.Cancel(OPENXP_OWNER) end
    self:RefreshOpenXPArrow(api)
end

function M:QueueOpenXP()
    if not Allowed() then
        self.openXPDeferred = true
        return
    end
    if self.openXPQueued then return end
    self.openXPQueued = true
    SUI:After(0, self, "follow OpenXP step", function()
        self.openXPQueued = nil
        self:SyncOpenXP()
    end)
end

function M:WatchOpenXP()
    local guide = _G.RXP
    if not (self.enabled and SUI:IntegrationEnabled("openxp") and hooksecurefunc and ShortestPath() and SUI:IsAddonLoaded("OpenXP")
        and not SUI:IsAddonLoaded("RXPGuides") and guide and guide.arrowFrame
        and type(guide.UpdateMap) == "function" and type(guide.UpdateGotoSteps) == "function") then return end
    if self.openXPGuide == guide then return end
    self.openXPGuide = guide
    local function queue()
        if self.enabled and SUI:IntegrationEnabled("openxp") and self.openXPGuide == guide then self:QueueOpenXP() end
    end
    hooksecurefunc(guide, "UpdateMap", queue)
    hooksecurefunc(guide, "UpdateGotoSteps", queue)
    if type(guide.ResetArrowPosition) == "function" then hooksecurefunc(guide, "ResetArrowPosition", queue) end
    if guide.settings and type(guide.settings.ToggleActive) == "function" then
        hooksecurefunc(guide.settings, "ToggleActive", queue)
    end
end

function M:OnJourneyChanged()
    local api = ShortestPath()
    self:RefreshOpenXPArrow(api)
    if OwnsRoute(api) then
        self:Draw()
        return
    end
    if self.routePoint then
        -- The route can finish or be cancelled independently. Keep the
        -- personal marker until the player removes it with Ctrl+right-click.
        self.routePoint = nil
        self:Draw()
    end
end

function M:WatchJourneys()
    local api = ShortestPath()
    if self.enabled and api and api.Subscribe and not self.unsubscribe then
        self.unsubscribe = api.Subscribe(function()
            SUI:SafeModuleCall(self, "update personal route", self.OnJourneyChanged)
        end)
    elseif not self.enabled and self.unsubscribe then
        self.unsubscribe()
        self.unsubscribe = nil
    end
end

function M:WatchOpenMap()
    local open = OpenWorldMapModule()
    if not (self.enabled and open) then return end
    if type(open.DropWaypoint) == "function" and open.DropWaypoint ~= self.openMapDrop then
        -- Clicks on map icons can skip the canvas handler. They use the same
        -- OpenMap entry point just before it creates a note and opens the editor.
        local drop = open.DropWaypoint
        self.openMapDrop = function(u, v, ...)
            if self.enabled and self.map and Modified() then
                SUI:SafeModuleCall(self, "place personal waypoint from OpenMap", self.Place, self.map, u, v)
                return
            end
            return drop(u, v, ...)
        end
        open.DropWaypoint = self.openMapDrop
    end
    if open.TrackPoint and self.openMapHook ~= open and hooksecurefunc then
        self.openMapHook = open
        -- OpenMap's own fallback point doesn't fire USER_WAYPOINT_UPDATED.
        hooksecurefunc(open, "TrackPoint", function(id, x, y)
            if self.enabled and not self.clearingExternal and Modified() and Coordinates(id, x, y) then
                self:QueueExternal({ mapID = id, x = x, y = y })
            end
        end)
    end
end

function M:Click(map, button)
    if not self.enabled or not Modified() then return false end
    if button == "LeftButton" then return self:Place(map) end
    if button == "RightButton" then
        local cleared = self:Clear()
        if cleared and self.rightClick then self.rightClick.handled = true end
        return cleared
    end
    return false
end

function M:WatchRightClick(map)
    local watcher = CreateFrame("Frame", nil, map)
    local function InMap()
        return map.ScrollContainer and map.ScrollContainer:IsMouseOver()
    end
    watcher:SetScript("OnShow", function(frame)
        frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
        frame:RegisterEvent("GLOBAL_MOUSE_UP")
        SUI:SafeModuleCall(self, "show personal waypoint", self.Draw)
        self:QueueExternal()
    end)
    watcher:SetScript("OnUpdate", function(frame, elapsed)
        if not self.point then return end
        frame.elapsed = (frame.elapsed or 0) + elapsed
        if frame.elapsed < .15 then return end
        frame.elapsed = 0
        SUI:SafeModuleCall(self, "update personal waypoint", self.Draw)
    end)
    watcher:SetScript("OnHide", function(frame)
        frame:UnregisterAllEvents()
        self.rightClick = nil
    end)
    watcher:SetScript("OnEvent", function(_, event, button)
        if button ~= "RightButton" then return end
        if event == "GLOBAL_MOUSE_DOWN" then
            self.rightClick = nil
            if Modified() and InMap() then
                local x, y = GetCursorPosition()
                self.rightClick = { x = x, y = y }
            end
            return
        end
        local click = self.rightClick
        if not click then return end
        local x, y = GetCursorPosition()
        if not Modified() or not InMap()
            or (x - click.x)^2 + (y - click.y)^2 > 64 then
            self.rightClick = nil
            return
        end
        -- Shortest Path handles its own goal frames outside the canvas registry.
        -- Let its click finish before clearing anything it may have restored.
        SUI:After(0, self, "clear waypoint after pin click", function()
            if self.rightClick ~= click then return end
            self.rightClick = nil
            if self.enabled and not click.handled then self:Clear() end
        end)
    end)
    self.watcher = watcher
    watcher:Hide()
    watcher:SetShown(self.enabled)
end

function M:Attach()
    local map = _G.WorldMapFrame
    if self.map or not (self.enabled and map and map.AddCanvasClickHandler) then return end
    map:AddCanvasClickHandler(function(_, button)
        local ok, handled = SUI:SafeModuleCall(self, "map waypoint click", self.Click, map, button)
        return ok and handled == true
    end, PRIORITY)
    self.map = map
    self:WatchRightClick(map)
end

function M:OnProfileChanged()
    self.enabled = SUI:GetFeature(self.key)
    self:Attach()
    if self.watcher then self.watcher:SetShown(self.enabled) end
    self:WatchJourneys()
    self:WatchOpenMap()
    self:WatchGuideWaypoints()
    self:WatchOpenXP()
    if self.openXPGuide then self:QueueOpenXP() end
    if self.enabled then
        self.cancelAfterCombat = nil
        self:QueueExternal()
    else
        self.externalPending = nil
        self.routePoint = nil
        self.deferredNavigation = nil
        self:CancelOwnedRoute()
        if self.pin then self.pin:Hide() end
    end
end

function M:CancelOwnedRoute()
    local api = ShortestPath()
    self.cancelAfterCombat = nil
    if not (OwnsRoute(api) and api.Cancel) then return end
    if Allowed() then api.Cancel(ROUTE_OWNER)
    else self.cancelAfterCombat = true end
end

function M:Initialize()
    self:OnProfileChanged()
    SUI:RegisterModuleEvent(self, "ADDON_LOADED")
    SUI:RegisterModuleEvent(self, "PLAYER_LOGIN")
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
    SUI:RegisterModuleEvent(self, "USER_WAYPOINT_UPDATED")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
end

function M:WantsEvent(event)
    return self.enabled or ((self.cancelAfterCombat or self.openXPDeferred) and event == "PLAYER_REGEN_ENABLED")
end

function M:OnEvent(event, addon)
    if not self.enabled then
        if event == "PLAYER_REGEN_ENABLED" then
            self:CancelOwnedRoute()
            if self.openXPDeferred then self:QueueOpenXP() end
        end
        return
    end
    if event == "ADDON_LOADED" and addon ~= "Blizzard_WorldMap" and addon ~= "ShortestPathForever"
        and addon ~= "OpenMap" and addon ~= "WaypointUI" and addon ~= "FlowUp"
        and addon ~= "ForeverGuide" and addon ~= "TomTom" and addon ~= "OpenXP" then return end
    self:Attach()
    self:WatchJourneys()
    self:WatchOpenMap()
    if event ~= "USER_WAYPOINT_UPDATED" then
        self:WatchGuideWaypoints()
        self:WatchOpenXP()
        if self.openXPGuide then
            if event == "PLAYER_ENTERING_WORLD" and not OpenXPRoute(ShortestPath()) then self.openXPLast = nil end
            self:QueueOpenXP()
        end
    end
    if event == "PLAYER_REGEN_ENABLED" and self.deferredNavigation then
        local request = self.deferredNavigation
        self:ApplyNavigation(request.point, request.navigate)
    end
    self:QueueExternal(nil, event == "USER_WAYPOINT_UPDATED" and Modified())
end
