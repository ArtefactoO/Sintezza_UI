local addonName, SUI = ...
local M = SUI:RegisterModule("transportMap", { bars = {}, active = {}, dockAnchors = {}, seenDocks = {}, minimapBars = {} })
local perf = _G.Sintezza_PerfAPI
if type(perf) ~= "table" or perf.version ~= 1 then perf = nil end
local visitPoint, clusterPoint, worldRefreshPoint, minimapRefreshPoint
if perf then
    local module = perf:RegisterModule(addonName, "transport", {
        title = "Transport timers", titleRu = "Таймеры транспорта",
    })
    if module then
        visitPoint = perf:RegisterPoint(module, "next_visit", {
            title = "Calculate dock departure", titleRu = "Расчет отправления", memory = true,
        })
        clusterPoint = perf:RegisterPoint(module, "cluster_visit", {
            title = "Choose cluster departure", titleRu = "Выбор отправления группы", memory = true,
        })
        worldRefreshPoint = perf:RegisterPoint(module, "world_refresh", {
            kind = "counter", title = "World map refreshes", titleRu = "Обновления карты мира",
        })
        minimapRefreshPoint = perf:RegisterPoint(module, "minimap_refresh", {
            kind = "counter", title = "Minimap refreshes", titleRu = "Обновления миникарты",
        })
    end
end
local CATALOG = SUI.TransportDocks
local LEGACY_MAX_AGE = 6 * 3600
local BAR_WIDTH, BAR_HEIGHT, BAR_GAP = 68, 18, 1
local MINI_WIDTH, MINI_HEIGHT = 38, 14
local TRACK_HEIGHT = 2
local PARCHMENT = { .77, .69, .52, .82 }
local INK = { .17, .12, .07, 1 }
local BORDER = { .35, .26, .16, .76 }
local TRAVEL = { .48, .30, .12, 1 }
local DOCKED = { .25, .36, .22, 1 }
local DEPART = SUI.Text("Отпр. ", "Dep. ")
local DOCK_TEMPLATE = "ShortestPathForeverDockPinTemplate"
local OPEN_SETS = { "boats", "zeppelins" }
local HANDOFF_GRACE, STITCHED_GAP = .5, 16
local OPEN_EVENTS = { "OpenMap_ViewChanged", "OpenMap_StitchedChanged" }
local MINIMAP_EVENTS = {
    PLAYER_ENTERING_WORLD = true, MINIMAP_UPDATE_ZOOM = true, ZONE_CHANGED = true,
    ZONE_CHANGED_NEW_AREA = true, ZONE_CHANGED_INDOORS = true,
    PLAYER_STARTED_MOVING = true, PLAYER_STOPPED_MOVING = true,
    PLAYER_CONTROL_GAINED = true, PLAYER_CONTROL_LOST = true,
}

local function Seconds(ms)
    local total = math.max(0, math.ceil(ms / 1000))
    return ("%d:%02d"):format(math.floor(total / 60), total % 60)
end

local function ReadSchedule(db)
    local anchors = db and db.anchors
    if type(anchors) ~= "table" then return end
    -- Shortest Path 1.34 moved sightings from realm buckets to account-wide route IDs.
    local realmAnchors = anchors[GetRealmName()]
    local legacy = type(realmAnchors) == "table"
    if legacy then anchors = realmAnchors end
    if not next(anchors) then return end
    return {
        anchors = anchors, maxAge = legacy and LEGACY_MAX_AGE or math.huge,
        now = GetServerTime(), faction = UnitFactionGroup("player"), db = db,
    }
end

local function NextVisit(dockID, schedule, filterKinds)
    local dock = CATALOG[dockID]
    if not dock then return end
    local db = schedule.db
    local best
    for index = 4, #dock do
        local visit = dock[index]
        local route, cycle, arrival, departure, kind, owner = unpack(visit)
        local observation = schedule.anchors[route]
        local enabled = not filterKinds
            or ((kind == "boat" or kind == "zeppelin") and db.pins ~= false)
            or ((kind == "lift" or kind == "tram") and db.transit ~= false)
        if enabled and (db.otherFaction or not owner or owner == schedule.faction) and type(observation) == "table"
            and type(observation.seen) == "number" and type(observation.epoch) == "number" then
            local age = schedule.now - observation.seen
            if age >= 0 and age <= schedule.maxAge then
                local now = (schedule.now * 1000 - observation.epoch) % cycle
                local sinceArrival = (now - arrival) % cycle
                local stay = (departure - arrival) % cycle
                local docked = sinceArrival < stay
                local arriveIn = docked and 0 or (arrival - now) % cycle
                local departIn = docked and stay - sinceArrival or arriveIn + stay
                if not best or departIn < best.departIn then
                    best = {
                        id = dockID, docked = docked, arriveIn = arriveIn, departIn = departIn, age = age,
                        fraction = docked and departIn / stay or arriveIn / (cycle - stay),
                    }
                end
            end
        end
    end
    return best
end
if visitPoint then
    local original = NextVisit
    NextVisit = function(...) return perf:Call(visitPoint, original, ...) end
end

local function Source()
    local spf = _G.ShortestPathForever
    local db = _G.ShortestPathForeverDB
    if type(spf) == "table" and spf.API and type(db) == "table" then return db end
end

local PREVIEW_DOCK, PREVIEW_MAP = 1, 1413 -- Ratchet, The Barrens

function M:GetPreviewVisit()
    local schedule = ReadSchedule(Source())
    return schedule and NextVisit(PREVIEW_DOCK, schedule, true)
end

local function ClusterVisit(docks, schedule, filterKinds)
    local best
    for _, dock in ipairs(docks) do
        local visit = NextVisit(dock.id, schedule, filterKinds)
        if visit and (not best or visit.departIn < best.departIn) then best = visit end
    end
    return best
end
if clusterPoint then
    local original = ClusterVisit
    ClusterVisit = function(...) return perf:Call(clusterPoint, original, ...) end
end

local function OpenMapStitch()
    local api, open = _G.OpenMapAPI, _G.OpenMap
    local stitch = type(open) == "table" and open.MapStitch
    if not (type(api) == "table" and type(api.IsStitched) == "function" and type(stitch) == "table"
        and type(stitch.GetPinSet) == "function" and type(stitch.FromYards) == "function") then return end
    local ok, stitched = pcall(api.IsStitched)
    if ok and not (issecretvalue and issecretvalue(stitched)) and stitched == true then return stitch, api end
end

local function DockKindMatches(dock, kind)
    for index = 4, #dock do
        local routeKind = dock[index][5]
        if routeKind == kind or (kind == "airship" and (routeKind == "boat" or routeKind == "zeppelin")) then
            return true
        end
    end
end

function M:OpenDock(stitch, pin)
    if self.stitch ~= stitch then
        self.stitch, self.stitchedDocks = stitch, {}
        for id, dock in pairs(CATALOG) do
            local u, v = stitch.FromYards(dock[1], dock[2], dock[3])
            if u and v then self.stitchedDocks[id] = { u, v } end
        end
    end
    if type(pin.u) ~= "number" or type(pin.v) ~= "number" then return end
    local nearest, limit = nil, .0015 ^ 2
    for id, point in pairs(self.stitchedDocks) do
        local distance = (point[1] - pin.u) ^ 2 + (point[2] - pin.v) ^ 2
        if distance < limit and DockKindMatches(CATALOG[id], pin.kind) then
            nearest, limit = id, distance
        end
    end
    return nearest
end

-- Shortest Path's dock frames carry their own pool and clustered stop IDs.
-- Inspect its two canvas containers once, then use that pool's active list.
function M:ShortestPool(map, now)
    local canvas = map.GetCanvas and map:GetCanvas()
    if not canvas then return end
    if self.canvas ~= canvas then
        self.canvas, self.pool, self.nextLookup = canvas, nil, nil
    end
    if self.pool or (self.nextLookup and now < self.nextLookup) then return self.pool end
    self.nextLookup = now + 3
    for _, host in ipairs({ canvas:GetChildren() }) do
        for _, layer in ipairs({ host:GetChildren() }) do
            for _, pin in ipairs({ layer:GetChildren() }) do
                local pool = pin.pool
                if pin.marker == "dock" and pin.view and pin.view.map == map
                    and pool and pool.template == DOCK_TEMPLATE and type(pool.active) == "table" then
                    self.pool = pool
                    return pool
                end
            end
        end
    end
end

local function CollectShortestDocks(map, pool, api, width, height, scale, seen)
    local known = {}
    for _, pin in ipairs(pool and pool.active or {}) do
        if pin:IsVisible() and pin.cluster and pin.cluster.docks then
            local x, y
            if type(pin.GetPosition) == "function" then x, y = pin:GetPosition() end
            local position = { x = x, y = y, level = pin:GetFrameLevel() }
            if x and y then
                known[#known + 1] = position
            else
                position.pin = pin
            end
            for _, dock in ipairs(pin.cluster.docks) do seen[dock.id] = seen[dock.id] or position end
        end
    end

    -- The public marker list still works when the pin pool cannot be found.
    -- Match an unrecognised dock marker in screen units, so zooming out does
    -- not accidentally pair it with a distant pier.
    local markers = _G.ForeverMapMarkers
    local read = markers and markers.ShortestPathForever
    if not (type(read) == "function" and api.CanvasFromWorldPos and width > 0 and height > 0 and scale > 0) then return end
    local reach = (24 * map:GetEffectiveScale() / scale) ^ 2
    local projected
    for _, marker in ipairs(read(map) or {}) do
        if marker.kind == "dock" and type(marker.x) == "number" and type(marker.y) == "number" then
            local matched = false
            for _, position in ipairs(known) do
                if position.x == marker.x and position.y == marker.y then matched = true; break end
            end
            if not matched then
                if not projected then
                    projected = {}
                    for id, dock in pairs(CATALOG) do
                        local x, y = api.CanvasFromWorldPos(dock[1], dock[2], dock[3])
                        if type(x) == "number" and type(y) == "number" then projected[id] = { x, y } end
                    end
                end
                local best, limit = nil, reach
                for id, point in pairs(projected) do
                    local distance = ((point[1] - marker.x) * width) ^ 2 + ((point[2] - marker.y) * height) ^ 2
                    if distance < limit or (distance == limit and best and id < best) then
                        best, limit = id, distance
                    end
                end
                if best and not seen[best] then seen[best] = marker end
            end
        end
    end
end

local function CreateTimerBar(parent, mini, preview)
    local width, height = BAR_WIDTH, BAR_HEIGHT
    if mini then width, height = MINI_WIDTH, MINI_HEIGHT end
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    -- Follow the pin's position and visibility while keeping its zoom out of the bar's size.
    if not preview and not mini and bar.SetIgnoreParentScale then
        bar:SetIgnoreParentScale(true)
        bar.fixedPinScale = true
    end
    bar:SetSize(width, height)
    bar:EnableMouse(false)
    SUI.Theme:Backdrop(bar, PARCHMENT, BORDER)
    local grain = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    grain:SetTexture(SUI.Theme.media .. "settings-grain.tga")
    grain:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    grain:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    grain:SetTexCoord(0, .52, 0, .13)
    grain:SetAlpha(.32)
    bar.label = bar:CreateFontString(nil, "OVERLAY")
    SUI.Theme:Font(bar.label, mini and 9 or 10, "", INK)
    bar.label:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, mini and -1 or -2)
    bar.label:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, mini and -1 or -2)
    bar.label:SetJustifyH("CENTER")
    bar.label:SetWordWrap(false)
    bar.track = bar:CreateTexture(nil, "ARTWORK")
    bar.track:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 4, 2)
    bar.track:SetSize(width - 8, TRACK_HEIGHT)
    bar.track:SetColorTexture(.36, .27, .17, .26)
    bar.fill = bar:CreateTexture(nil, "OVERLAY")
    bar.fill:SetPoint("BOTTOMLEFT", bar.track, "BOTTOMLEFT")
    bar.fill:SetHeight(TRACK_HEIGHT)
    return bar
end

function M:Bar(key, pin, mini)
    local bars = mini and self.minimapBars or self.bars
    local bar = bars[key]
    if bar then return bar end
    bar = CreateTimerBar(pin or self.driver, mini)
    if pin then bar:SetPoint("TOP", pin, "BOTTOM", 0, -BAR_GAP) end
    bars[key] = bar
    return bar
end

local function PaintVisit(bar, item, mini)
    local label
    if mini then
        label = Seconds(item.docked and item.departIn or item.arriveIn)
    elseif item.docked then
        label = DEPART .. Seconds(item.departIn)
    else
        label = Seconds(item.arriveIn) .. " / " .. Seconds(item.departIn)
    end
    bar.label:SetText((item.age > 3600 and "~" or "") .. label)
    bar.fill:SetWidth(math.max(1, bar.track:GetWidth() * item.fraction))
    bar.fill:SetColorTexture(unpack(item.docked and DOCKED or TRAVEL))
    bar:Show()
end

function M:HideBars()
    for key in pairs(self.active) do
        self.bars[key]:Hide()
    end
    wipe(self.active)
    wipe(self.seenDocks)
    self.handoffDeadline = nil
end

function M:PlaceDockBar(bar, item, canvas, api, mapScale, canvasScale)
    local anchor = self.dockAnchors[item.id]
    if not anchor then
        anchor = CreateFrame("Frame", nil, canvas)
        anchor:SetSize(1, 1)
        self.dockAnchors[item.id] = anchor
    elseif anchor:GetParent() ~= canvas then
        anchor:SetParent(canvas)
    end
    local x, y = item.canvasX, item.canvasY
    if anchor.canvas ~= canvas or anchor.x ~= x or anchor.y ~= y then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", canvas, "TOPLEFT", x, -y)
        anchor.canvas, anchor.x, anchor.y = canvas, x, y
    end
    -- Position and clipping follow the canvas, while the label keeps its UI size.
    if bar.dockAnchor ~= anchor or bar.dockGap ~= item.gap then
        if bar:GetParent() ~= anchor then bar:SetParent(anchor) end
        bar:ClearAllPoints()
        bar:SetPoint("TOP", anchor, "CENTER", 0, -item.gap)
        bar.dockAnchor, bar.dockGap = anchor, item.gap
    end
    local scale = bar.fixedPinScale and mapScale or mapScale / canvasScale
    if bar:GetScale() ~= scale then bar:SetScale(scale) end
    local art = api and api.ArtTopLevel and api.ArtTopLevel() or 0
    local level = math.max(canvas:GetFrameLevel(), art or 0, item.dockLevel or 0) + 12
    if bar:GetFrameLevel() ~= level then bar:SetFrameLevel(level) end
end

local function PinPosition(pin, mapScale)
    if not (pin and pin:IsVisible()) then return end
    local center, bottom, scale = pin:GetCenter(), pin:GetBottom(), pin:GetEffectiveScale()
    if center and bottom and scale > 0 then
        return center * scale, bottom * scale - BAR_GAP * mapScale, scale
    end
end

local function DockPosition(dock, api, mapID)
    if api and api.CanvasFromWorldPos then
        local x, y = api.CanvasFromWorldPos(dock[1], dock[2], dock[3])
        if type(x) == "number" and type(y) == "number" then return x, y end
    end
    if not (mapID and C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
    local id, point = C_Map.GetMapPosFromWorldPos(dock[1], CreateVector2D(dock[2], dock[3]), mapID)
    if id ~= mapID or not point then return end
    local x, y = point:GetXY()
    if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function PaintDockPreviewMap(frame, mini)
    if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return .5, .44 end
    local x, y = DockPosition(CATALOG[PREVIEW_DOCK], nil, PREVIEW_MAP)
    local layers = x and C_Map.GetMapArtLayers(PREVIEW_MAP)
    local layer = layers and layers[1]
    local files = layer and C_Map.GetMapArtLayerTextures(PREVIEW_MAP, 1)
    if not files or not files[1] then return .5, .44 end

    local tileWidth, tileHeight = layer.tileWidth, layer.tileHeight
    local width, height = layer.layerWidth, layer.layerHeight
    local columns = math.ceil(width / tileWidth)
    local aspect = frame:GetHeight() / frame:GetWidth()
    local viewWidth = math.min(width * (mini and .14 or .30), height / aspect)
    local viewHeight = viewWidth * aspect
    local left = math.max(0, math.min(width - viewWidth, x * width - viewWidth * .5))
    local top = math.max(0, math.min(height - viewHeight, y * height - viewHeight * .44))
    local right, bottom = left + viewWidth, top + viewHeight
    local scale = frame:GetWidth() / viewWidth

    for row = math.floor(top / tileHeight), math.ceil(bottom / tileHeight) - 1 do
        for column = math.floor(left / tileWidth), math.ceil(right / tileWidth) - 1 do
            local file = files[row * columns + column + 1]
            if file and file ~= 0 then
                local tx, ty = column * tileWidth, row * tileHeight
                local l, t = math.max(left, tx), math.max(top, ty)
                local r, b = math.min(right, tx + tileWidth), math.min(bottom, ty + tileHeight)
                local tile = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
                tile:SetTexture(file)
                tile:SetPoint("TOPLEFT", frame, "TOPLEFT", (l - left) * scale, -(t - top) * scale)
                tile:SetSize((r - l) * scale, (b - t) * scale)
                tile:SetTexCoord((l - tx) / tileWidth, (r - tx) / tileWidth, (t - ty) / tileHeight, (b - ty) / tileHeight)
            end
        end
    end
    return (x * width - left) / viewWidth, (y * height - top) / viewHeight
end

function M:CreateTransportPreview(parent, mini)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(147, 152)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.14, .22, .24, 1)
    local x, y = PaintDockPreviewMap(frame, mini)
    local pin = frame:CreateTexture(nil, "ARTWORK")
    pin:SetAtlas("flightmasterferry")
    local size = mini and 16 or 20
    pin:SetSize(size, size)
    pin:SetPoint("CENTER", frame, "TOPLEFT", x * frame:GetWidth(), -y * frame:GetHeight())
    local timer = CreateTimerBar(frame, mini, true)
    timer:SetPoint("TOP", pin, "BOTTOM", 0, -BAR_GAP)
    function frame:Refresh(visit, enabled)
        if enabled and visit then PaintVisit(timer, visit, mini) else timer:Hide() end
    end
    return frame
end

function M:Refresh()
    if worldRefreshPoint then perf:Count(worldRefreshPoint) end
    local map = self.map
    self:WatchOpenMap(_G.OpenMapAPI)
    local schedule = ReadSchedule(Source())
    if not schedule then self:HideBars(); return end
    local mapScale = map:GetEffectiveScale()
    local view = map.ScrollContainer or map
    local l, r, b, t = view:GetLeft(), view:GetRight(), view:GetBottom(), view:GetTop()
    if l and r and b and t then
        local viewScale = view:GetEffectiveScale()
        l, r, b, t = l * viewScale, r * viewScale, b * viewScale, t * viewScale
    end
    local choices, offered = {}, {}
    local function AddChoice(visit)
        if l and r and b and t and (visit.x < l or visit.x > r or visit.y < b or visit.y > t) then return end
        choices[#choices + 1] = visit
        offered[visit.id] = true
    end
    local function Offer(pin, nextVisit)
        if not nextVisit then return end
        local x, y, scale = PinPosition(pin, mapScale)
        if not x then return end
        nextVisit.pin = pin
        nextVisit.x, nextVisit.y = x, y
        nextVisit.pinScale = scale
        AddChoice(nextVisit)
    end
    local stitch, api = OpenMapStitch()
    local canvas = map.GetCanvas and map:GetCanvas()
    local stitched = stitch and canvas
    local combat = InCombatLockdown and InCombatLockdown()
    local pool = not combat and self:ShortestPool(map, schedule.now)
    local width, height, scale, left, top
    if canvas then
        width, height, scale = canvas:GetWidth(), canvas:GetHeight(), canvas:GetEffectiveScale()
        left, top = canvas:GetLeft(), canvas:GetTop()
    end
    local canvasReady = left and top and width > 0 and height > 0 and scale > 0
    local function PlaceAt(visit, x, y, gap)
        visit.canvasX, visit.canvasY = x * width, y * height
        visit.gap = gap or STITCHED_GAP
        visit.x = (left + visit.canvasX) * scale
        visit.y = (top - visit.canvasY) * scale - visit.gap * mapScale
    end
    if stitched then
        local time, seen = GetTime(), {}
        for _, name in ipairs(OPEN_SETS) do
            local set = stitch.GetPinSet(name)
            for _, pin in ipairs(set and set.pins or {}) do
                if pin:IsVisible() then
                    local id = self:OpenDock(stitch, pin)
                    if id then seen[id] = { pin = pin } end
                end
            end
        end
        if not combat then CollectShortestDocks(map, pool, api, width, height, scale, seen) end
        for id in pairs(seen) do self.seenDocks[id] = true end
        self.handoffDeadline = nil
        for id, state in pairs(self.seenDocks) do
            local deadline
            if not seen[id] then
                -- Start the grace period when the last visible pin disappears.
                deadline = state == true and time + HANDOFF_GRACE or state
                self.seenDocks[id] = deadline
            end
            if deadline and time >= deadline then
                self.seenDocks[id] = nil
            else
                if deadline then self.handoffDeadline = math.min(self.handoffDeadline or deadline, deadline) end
                local dock = CATALOG[id]
                local visit = dock and NextVisit(id, schedule)
                if visit then
                    local position = seen[id]
                    local pin = position and position.pin
                    local x, y = PinPosition(pin, mapScale)
                    if x and canvasReady then
                        PlaceAt(visit, (x / scale - left) / width, (top - (y + BAR_GAP * mapScale) / scale) / height, BAR_GAP)
                        visit.dockLevel = pin:GetFrameLevel()
                        AddChoice(visit)
                    elseif canvasReady then
                        if position then x, y = position.x, position.y end
                        if not x then x, y = DockPosition(dock, api, map:GetMapID()) end
                        if type(x) == "number" and type(y) == "number" then
                            visit.dockLevel = position and position.level
                            PlaceAt(visit, x, y)
                            AddChoice(visit)
                        end
                    end
                end
            end
        end
    else
        wipe(self.seenDocks)
        self.handoffDeadline = nil
        for _, pin in ipairs(pool and pool.active or {}) do
            if pin:IsVisible() and pin.cluster and pin.cluster.docks then
                Offer(pin, ClusterVisit(pin.cluster.docks, schedule))
            end
        end
    end
    if canvasReady and l and r and b and t then
        -- Use the dock's location when a provider hides or rebuilds its pins.
        local mapID = map:GetMapID()
        for id, dock in pairs(CATALOG) do
            local visit = not offered[id] and NextVisit(id, schedule, true)
            if visit then
                local x, y = DockPosition(dock, api, mapID)
                if type(x) == "number" and type(y) == "number" then
                    PlaceAt(visit, x, y)
                    visit.fallback = true
                    AddChoice(visit)
                end
            end
        end
    end
    table.sort(choices, function(a, b)
        if a.fallback ~= b.fallback then return not a.fallback end
        if a.departIn ~= b.departIn then return a.departIn < b.departIn end
        return a.id < b.id
    end)

    local claimed, placed, visible = {}, {}, {}
    for _, item in ipairs(choices) do
        if not claimed[item.id] then
            local clear = true
            for _, other in ipairs(placed) do
                if math.abs(other.x - item.x) < (BAR_WIDTH + 4) * mapScale
                    and math.abs(other.y - item.y) < (BAR_HEIGHT + 4) * mapScale then
                    clear = false
                    break
                end
            end
            if clear then
                local key = item.pin or item.id
                local bar = self:Bar(key, item.pin)
                if item.pin then
                    bar:SetScale(bar.fixedPinScale and mapScale or math.min(2, mapScale / item.pinScale))
                    bar:SetFrameLevel(item.pin:GetFrameLevel() + 2)
                else
                    self:PlaceDockBar(bar, item, canvas, api, mapScale, scale)
                end
                PaintVisit(bar, item, false)
                visible[key], claimed[item.id] = true, true
                placed[#placed + 1] = item
            end
        end
    end
    for key in pairs(self.active) do
        if not visible[key] then self.bars[key]:Hide() end
    end
    self.active = visible
end

local function TimerFits(x, y, halfWidth, halfHeight, square, occupied)
    local u = (math.abs(x) + MINI_WIDTH / 2 + 1) / halfWidth
    local v = (math.abs(y) + MINI_HEIGHT / 2 + 1) / halfHeight
    if u > 1 or v > 1 or (not square and u * u + v * v > 1) then return false end
    for _, other in ipairs(occupied) do
        if math.abs(other.x - x) < (other.width + MINI_WIDTH) / 2 + 1
            and math.abs(other.y - y) < (other.height + MINI_HEIGHT) / 2 + 1 then return false end
    end
    return true
end

function M:RefreshMinimap()
    if minimapRefreshPoint then perf:Count(minimapRefreshPoint) end
    local host, db = self.minimapHost, Source()
    if not (self.minimapEnabled and host and host:IsVisible() and db) or InCombatLockdown() then
        for _, bar in pairs(self.minimapBars) do bar:Hide() end
        return false
    end
    local cx, cy = host:GetCenter()
    local w, h = host:GetSize()
    local scale = host:GetEffectiveScale()
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local schedule = ReadSchedule(db)
    local docks, occupied, shown = {}, {}, {}
    local nearby = false
    if cx and cy and w > 0 and h > 0 and scale > 0 then
        for _, pin in ipairs({ host:GetChildren() }) do
            local entry = pin.entry
            local cluster = type(entry) == "table" and entry.cluster
            if pin:IsVisible() and type(cluster) == "table" and type(cluster.docks) == "table" then
                nearby = true
                local x, y = pin:GetCenter()
                if x and y then
                    local ratio = pin:GetEffectiveScale() / scale
                    local rect = { x = x * ratio - cx, y = y * ratio - cy,
                        width = pin:GetWidth() * ratio, height = pin:GetHeight() * ratio, pin = pin }
                    occupied[#occupied + 1] = rect
                    rect.visit = schedule and ClusterVisit(cluster.docks, schedule, true)
                    if rect.visit then docks[#docks + 1] = rect end
                end
            end
        end
    end
    for _, dock in ipairs(docks) do
        local x, y, pin, item = dock.x, dock.y, dock.pin, dock.visit
        local offset = dock.height / 2 + MINI_HEIGHT / 2 + BAR_GAP + 1
        local below = TimerFits(x, y - offset, w / 2, h / 2, square, occupied)
        if below or TimerFits(x, y + offset, w / 2, h / 2, square, occupied) then
            local bar = self:Bar(pin, pin, true)
            if bar.below ~= below then
                bar:ClearAllPoints()
                bar:SetPoint(below and "TOP" or "BOTTOM", pin, below and "BOTTOM" or "TOP", 0, below and -2 or 2)
                bar.below = below
            end
            PaintVisit(bar, item, true)
            shown[pin] = true
            occupied[#occupied + 1] = { x = x, y = y + (below and -offset or offset), width = MINI_WIDTH, height = MINI_HEIGHT }
        end
    end
    for pin, bar in pairs(self.minimapBars) do
        if not shown[pin] then bar:Hide() end
    end
    if nearby then return true end
    local speed = GetUnitSpeed and GetUnitSpeed("player")
    if type(speed) == "number" and not (issecretvalue and issecretvalue(speed)) and speed > 0 then return true end
    return UnitOnTaxi and UnitOnTaxi("player")
end

function M:UpdateMinimap()
    local host = _G.ShortestPathForeverMinimapPins
    if host and host ~= self.minimapHost then
        self.minimapHost = host
        host:HookScript("OnShow", function() self:QueueMinimap() end)
        host:HookScript("OnHide", function() self:UpdateMinimap() end)
    end
    local ok, keep = SUI:SafeModuleCall(self, "transport minimap", self.RefreshMinimap)
    if ok and keep then
        self.minimapTicker = self.minimapTicker or C_Timer.NewTicker(.5, function() self:UpdateMinimap() end)
    elseif self.minimapTicker then
        self.minimapTicker:Cancel()
        self.minimapTicker = nil
    end
end

function M:QueueMinimap()
    if not self.minimapEnabled or self.minimapQueued then return end
    self.minimapQueued = true
    SUI:After(.25, self, "transport minimap wake", function()
        self.minimapQueued = nil
        self:UpdateMinimap()
    end)
end

function M:WatchOpenMap(api)
    if self.watchedAPI == api then return end
    if self.watchedAPI then
        for _, event in ipairs(OPEN_EVENTS) do self.watchedAPI.UnregisterCallback(self, event) end
        self.watchedAPI = nil
    end
    if type(api) == "table" and type(api.RegisterCallback) == "function"
        and type(api.UnregisterCallback) == "function" then
        self.watchedAPI = api
        local function RequestLayout() self.driver.dirty = true end
        for _, event in ipairs(OPEN_EVENTS) do api.RegisterCallback(self, event, RequestLayout) end
    end
end

function M:UpdateDriver()
    local map = _G.WorldMapFrame
    local enabled = self.profile and SUI:GetFeature("transportMap") and Source() and map
    if enabled and not self.driver then
        local viewport = map.ScrollContainer or map
        local driver = CreateFrame("Frame", nil, viewport)
        self.map, self.driver = map, driver
        driver:SetAllPoints(viewport)
        if driver.SetClipsChildren then driver:SetClipsChildren(true) end
        driver:SetScript("OnShow", function(frame)
            frame.elapsed = 1
            self:WatchOpenMap(_G.OpenMapAPI)
        end)
        driver:SetScript("OnHide", function()
            self:WatchOpenMap(nil)
            self:HideBars()
        end)
        driver:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = (frame.elapsed or 1) + elapsed
            local mapID = self.watchedAPI and self.map:GetMapID()
            local expired = self.handoffDeadline and GetTime() >= self.handoffDeadline
            if frame.elapsed < 1 and not frame.dirty and not expired and mapID == frame.mapID then return end
            frame.elapsed, frame.dirty, frame.mapID = 0, nil, mapID
            SUI:SafeModuleCall(self, "transport map", self.Refresh)
        end)
    end
    if self.driver then
        self.driver:SetShown(not not enabled)
        if self.driver:IsVisible() then self:WatchOpenMap(_G.OpenMapAPI) end
    end
end

function M:OnProfileChanged()
    self.profile = SUI:GetModuleProfile("transportMap")
    self.minimapEnabled = SUI:GetFeature("transportMap.minimap")
    self:UpdateDriver()
    self:UpdateMinimap()
    self:QueueMinimap()
end

function M:WantsEvent(event)
    if not self.profile then return false end
    if MINIMAP_EVENTS[event] then return self.minimapEnabled end
    if not (self.profile.enabled or self.profile.minimap) then return false end
    return event ~= "ADDON_LOADED" or not self.driver or (self.profile.minimap and not self.minimapHost)
end

function M:OnEvent(event, addon)
    if MINIMAP_EVENTS[event] then
        self:QueueMinimap()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if self.driver then self.driver.dirty = true end
        if event == "PLAYER_REGEN_DISABLED" then self:UpdateMinimap() else self:QueueMinimap() end
        return
    end
    if event == "ADDON_LOADED" and addon ~= "ShortestPathForever" and addon ~= "Blizzard_WorldMap" and addon ~= "OpenMap" then return end
    self.minimapEnabled = SUI:GetFeature("transportMap.minimap")
    self:QueueMinimap()
    self:UpdateDriver()
    if event == "ADDON_LOADED" and not self.driver then
        SUI:After(0, self, "transport map load", self.UpdateDriver)
    end
    SUI:RefreshModuleEvents()
end

function M:Initialize()
    self:OnProfileChanged()
    SUI:RegisterModuleEvent(self, "ADDON_LOADED")
    SUI:RegisterModuleEvent(self, "PLAYER_LOGIN")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_DISABLED")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    for event in pairs(MINIMAP_EVENTS) do SUI:RegisterModuleEvent(self, event) end
end
