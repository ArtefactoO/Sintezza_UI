local _, SUI = ...

local M = SUI:RegisterModule("partyMap", { members = {}, pins = {} })
local ICON = Sintezza_Theme.icons.GameBar .. "GroupFinder-v2.tga"
local PIN_SHAPE = Sintezza_Theme.media .. "Diamond.tga"
local MENU_TITLE = SUI.Text("Сопартийцы на карте", "Party members on the map")
local BUTTON_LEVEL = 9600
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
local STRATA_RANK = {}
for index, strata in ipairs(STRATA) do STRATA_RANK[strata] = index end

local function MapOverlayLevel(map, offset)
    local view = map.ScrollContainer or map
    return math.min(math.max(map:GetFrameLevel(), view:GetFrameLevel()) + offset, 9999)
end

local function Public(value)
    if not (issecretvalue and issecretvalue(value)) then return value end
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return Public(a), Public(b), Public(c), Public(d) end
end

local function IsNumber(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function FrameRank(frame)
    return frame and STRATA_RANK[Call(frame.GetFrameStrata, frame)] or 0
end

local function OpenMapGroup(api)
    local stitch = api and _G.OpenMap and _G.OpenMap.MapStitch
    local group = stitch and Call(stitch.GetPinSet, "group")
    if type(group) == "table" then return group end
end

local function PartyOverlayLayer(map, view, group)
    local rank = math.max(STRATA_RANK.MEDIUM, FrameRank(map), FrameRank(view))
    local level = math.max(map:GetFrameLevel(), view:GetFrameLevel())
    local function Include(frame)
        rank = math.max(rank, FrameRank(frame))
        level = math.max(level, Call(frame.GetFrameLevel, frame) or 0)
    end
    local iter, state, key = Call(map.EnumeratePinsByTemplate, map, "GroupMembersPinTemplate")
    if type(iter) == "function" then
        for pin in iter, state, key do Include(pin) end
    end
    if group and group.frame then Include(group.frame) end
    if rank < #STRATA then return STRATA[rank + 1], 0 end
    return STRATA[rank], level + 1
end

local function InBounds(x, y)
    return IsNumber(x) and IsNumber(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

local function ReadPosition(pos)
    if not pos then return end
    local x, y = Call(pos.GetXY, pos)
    if type(pos) == "table" and not (IsNumber(x) and IsNumber(y)) then
        x, y = Public(pos.x), Public(pos.y)
    end
    if InBounds(x, y) and (x ~= 0 or y ~= 0) then return x, y end
end

local function PositionOn(unit, mapID)
    if C_Map and IsNumber(mapID) and mapID > 0 then
        return ReadPosition(Call(C_Map.GetPlayerMapPosition, mapID, unit))
    end
end

local parentByMap = {}
local function ParentMap(mapID)
    local cached = parentByMap[mapID]
    if cached ~= nil then return cached end
    local info = Call(C_Map.GetMapInfo, mapID)
    local parent = info and Public(info.parentMapID)
    if IsNumber(parent) then
        parentByMap[mapID] = parent > 0 and parent ~= mapID and parent or false
        return parentByMap[mapID]
    end
end

local function FindPosition(unit, fallbackMap)
    if not C_Map or Call(UnitIsConnected, unit) == false then return end
    local mapID = Call(C_Map.GetBestMapForUnit, unit)
    local x, y = PositionOn(unit, mapID)
    if x then return mapID, x, y end
    if fallbackMap and mapID ~= fallbackMap then
        x, y = PositionOn(unit, fallbackMap)
        if x then return fallbackMap, x, y end
    end
    local localMap = Call(C_Map.GetBestMapForUnit, "player")
    if localMap and localMap ~= mapID and localMap ~= fallbackMap then
        x, y = PositionOn(unit, localMap)
        if x then return localMap, x, y end
    end
    -- UnitPosition uses the opposite axis order from the map's world vector.
    local worldY, worldX, _, continent = Call(UnitPosition, unit)
    if IsNumber(worldX) and IsNumber(worldY) and IsNumber(continent) and (worldX ~= 0 or worldY ~= 0) then
        local world = Call(CreateVector2D, worldX, worldY)
        if world then
            local projected, position = Call(C_Map.GetMapPosFromWorldPos, continent, world)
            x, y = ReadPosition(position)
            if x and IsNumber(projected) and projected > 0 then return projected, x, y end
        end
    end
    -- Some clients only report a party member on the parent map.
    for _, start in pairs({ mapID, fallbackMap, localMap }) do
        local id = start
        for _ = 1, 4 do
            local parent = ParentMap(id)
            if not parent then break end
            if parent ~= mapID and parent ~= fallbackMap and parent ~= localMap then
                x, y = PositionOn(unit, parent)
                if x then return parent, x, y end
            end
            id = parent
        end
    end
    return nil, nil, nil, mapID
end

local function StitchedAPI()
    local api = SUI:GetOpenMapProjectionAPI()
    if api and Call(api.IsStitched) then return api end
end

local function OpenMapPosition(group, unit)
    if not group or type(group.pins) ~= "table" then return end
    for _, pin in ipairs(group.pins) do
        if pin.unit == unit and not pin.zone and Call(pin.IsShown, pin) then
            local u, v = Public(pin.u), Public(pin.v)
            if IsNumber(u) and IsNumber(v) then return u, v end
        end
    end
end

local function CanvasPosition(api, unit, hostMap, group)
    if api then
        local mapID, x, y = FindPosition(unit, hostMap)
        if mapID == hostMap then return x, y end
        local u, v
        if mapID then u, v = Call(api.WorldFromMap, mapID, x, y) end
        if not (IsNumber(u) and IsNumber(v)) then u, v = OpenMapPosition(group, unit) end
        if IsNumber(u) and IsNumber(v) then
            local cx, cy = Call(api.MapFromWorld, hostMap, u, v)
            -- The stitched view may show beyond the current host zone's bounds.
            if IsNumber(cx) and IsNumber(cy) then return cx, cy end
        end
        return PositionOn(unit, hostMap)
    end

    local x, y = PositionOn(unit, hostMap)
    if x then return x, y end
    local mapID, zx, zy = FindPosition(unit)
    if mapID and mapID ~= hostMap then
        local l, r, t, b = Call(C_Map.GetMapRectOnMap, mapID, hostMap)
        if IsNumber(l) and IsNumber(r) and IsNumber(t) and IsNumber(b) and l < r and t < b then
            x, y = l + (r - l) * zx, t + (b - t) * zy
            if InBounds(x, y) then return x, y end
        end
    end
end

local function MemberName(unit)
    local name, realm = Call(UnitFullName, unit)
    name = name or Call(UnitName, unit)
    if name and realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function Identity(unit, name)
    return Call(UnitGUID, unit) or name
end

local function SameName(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local realm = Call(GetNormalizedRealmName)
    if realm and realm ~= "" then
        if not a:find("-", 1, true) then a = a .. "-" .. realm end
        if not b:find("-", 1, true) then b = b .. "-" .. realm end
    end
    return a == b
end

local function RosterArea(unit, id, name)
    local raidIndex = tonumber(unit:match("^raid(%d+)$"))
    if raidIndex then
        local ok, _, _, _, _, _, _, zone = pcall(GetRaidRosterInfo, raidIndex)
        zone = ok and Public(zone)
        if zone and zone ~= "" then return zone end
    end
    if C_FriendList then
        local count = Call(C_FriendList.GetNumFriends) or 0
        for i = 1, count do
            local friend = Call(C_FriendList.GetFriendInfoByIndex, i)
            if friend and Public(friend.connected) and SameName(Public(friend.name), name) then
                local area = Public(friend.area)
                if area and area ~= "" then return area end
            end
        end
    end
    local count = Call(GetNumGuildMembers) or 0
    for i = 1, count do
        local ok, full, _, _, _, _, area, _, _, online, _, _, _, _, _, _, _, guid = pcall(GetGuildRosterInfo, i)
        if ok and Public(online) and (Public(guid) == id or SameName(Public(full), name)) then
            return Public(area)
        end
    end
end

local zonesByName
local function MapForArea(area)
    if type(area) ~= "string" or area == "" or not (C_Map and Enum and Enum.UIMapType) then return end
    if not zonesByName then
        local maps = Call(C_Map.GetMapChildrenInfo, 947, Enum.UIMapType.Zone, true) -- Azeroth
        if not maps or #maps == 0 then return end
        zonesByName = {}
        for _, info in ipairs(maps) do
            local name, id = Public(info.name), Public(info.mapID)
            if name and id then
                if zonesByName[name] == nil then zonesByName[name] = id
                elseif zonesByName[name] ~= id then zonesByName[name] = false end
            end
        end
    end
    return zonesByName[area] or nil
end

local function FindDestination(unit, id, name, currentMap)
    local mapID, x, y, knownZone = FindPosition(unit, currentMap)
    if mapID then return mapID, x, y end
    if Call(UnitIsConnected, unit) == false then return end
    local api = StitchedAPI()
    local u, v = OpenMapPosition(OpenMapGroup(api), unit)
    if u then
        local zone = Call(api.MapAt, u, v) or currentMap
        if IsNumber(zone) then
            x, y = Call(api.MapFromWorld, zone, u, v)
            if InBounds(x, y) then return zone, x, y end
        end
    end
    if IsNumber(knownZone) and knownZone > 0 then return knownZone end
    local area = RosterArea(unit, id, name)
    return MapForArea(area), nil, nil, area
end

function M:UpdateMembers()
    local members = self.members
    wipe(members)
    if not Call(IsInGroup) then return end
    local raid, subgroup = Call(IsInRaid)
    local count = raid and Call(GetNumGroupMembers) or Call(GetNumSubgroupMembers)
    if not IsNumber(count) then return end
    if raid then
        for i = 1, math.min(count, 40) do
            if Call(UnitIsUnit, "raid" .. i, "player") then
                local _, _, playerSubgroup = Call(GetRaidRosterInfo, i)
                subgroup = playerSubgroup
                break
            end
        end
        if not subgroup then return end
    end
    for i = 1, math.min(count, raid and 40 or 4) do
        local unit = (raid and "raid" or "party") .. i
        local _, _, memberSubgroup
        if raid then _, _, memberSubgroup = Call(GetRaidRosterInfo, i) end
        if (not raid or memberSubgroup == subgroup) and Call(UnitExists, unit) and not Call(UnitIsUnit, unit, "player") then
            local name = MemberName(unit)
            if name then
                local _, class = Call(UnitClass, unit)
                local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                members[#members + 1] = { unit = unit, name = name, id = Identity(unit, name), color = color }
            end
        end
    end
end

local function Diamond(parent, size, sublayer, r, g, b, a)
    local tex = parent:CreateTexture(nil, "ARTWORK", nil, sublayer)
    tex:SetTexture(PIN_SHAPE)
    tex:SetSize(size, size)
    tex:SetPoint("CENTER")
    tex:SetVertexColor(r, g, b, a)
    return tex
end

function M:GetPin(index)
    if self.pins[index] then return self.pins[index] end
    -- The canvas owns position and zoom. Draw the face outside its pin pass.
    local anchor = CreateFrame("Frame", nil, self.layer)
    anchor:SetSize(1, 1)
    local face = CreateFrame("Frame", nil, self.pinOverlay)
    face:SetSize(24, 24)
    face:SetPoint("CENTER", anchor, "CENTER")
    local pulse = Diamond(face, 26, -1, 1, 1, 1, 1)
    pulse:Hide()
    local animation = pulse:CreateAnimationGroup()
    local expand = animation:CreateAnimation("Scale")
    expand:SetOrigin("CENTER", 0, 0)
    expand:SetScaleFrom(1, 1)
    expand:SetScaleTo(1.55, 1.55)
    expand:SetDuration(.85)
    expand:SetSmoothing("OUT")
    local fade = animation:CreateAnimation("Alpha")
    fade:SetFromAlpha(.60)
    fade:SetToAlpha(0)
    fade:SetDuration(.85)
    animation:SetScript("OnFinished", function() pulse:Hide() end)
    face.pulse, face.pulseAnimation = pulse, animation
    Diamond(face, 24, 0, .04, .045, .06, 1)
    face.outline = Diamond(face, 20, 1, .9, .95, 1, 1)
    Diamond(face, 16, 2, .07, .085, .11, 1)
    face.number = face:CreateFontString(nil, "OVERLAY")
    face.number:SetPoint("CENTER")
    SUI.Theme:Font(face.number, 10, "OUTLINE", { 1, 1, 1, 1 })
    face.number:SetText(tostring(index))
    anchor.face = face
    self.pins[index] = anchor
    return anchor
end

local function HidePin(pin)
    pin:Hide()
    pin.face:Hide()
end

function M:HidePins()
    for _, pin in pairs(self.pins) do HidePin(pin) end
end

function M:DrawPins(mapID, api)
    local canvas = self.canvas
    local w, h = canvas:GetSize()
    if not mapID or w <= 0 or h <= 0 then self:HidePins(); return end
    local overlay = self.pinOverlay
    local group = OpenMapGroup(api)
    local strata, level = PartyOverlayLayer(self.map, overlay:GetParent(), group)
    if overlay:GetFrameStrata() ~= strata then overlay:SetFrameStrata(strata) end
    if overlay:GetFrameLevel() ~= level then overlay:SetFrameLevel(level) end
    for i, member in ipairs(self.members) do
        local selection = self.selected and self.selected.id == member.id and self.selected or nil
        local x, y
        if (self.profile.markers or selection) and Call(UnitIsConnected, member.unit) ~= false then
            x, y = CanvasPosition(api, member.unit, mapID, group)
        end
        if x then
            local pin = self:GetPin(i)
            if pin.x ~= x or pin.y ~= y or pin.w ~= w or pin.h ~= h then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
                pin.x, pin.y, pin.w, pin.h = x, y, w, h
            end
            local color = member.color
            local r, g, b = .9, .95, 1
            if color then r, g, b = color.r, color.g, color.b end
            pin.face.outline:SetVertexColor(r, g, b, 1)
            local faceLevel = overlay:GetFrameLevel() + (selection and 2 or 1)
            if pin.face:GetFrameLevel() ~= faceLevel then pin.face:SetFrameLevel(faceLevel) end
            pin:Show()
            pin.face:Show()
            if pin.selection ~= selection then
                local face = pin.face
                face.pulseAnimation:Stop()
                if selection then
                    face.pulse:SetVertexColor(r, g, b, 1)
                    face.pulse:Show()
                    face.pulseAnimation:Play()
                else
                    face.pulse:Hide()
                end
                pin.selection = selection
            end
        elseif self.pins[i] then HidePin(self.pins[i]) end
    end
    for index, pin in pairs(self.pins) do
        if index > #self.members then HidePin(pin) end
    end
end

function M:Tick(elapsed)
    local map = self.map
    local mapID = map:GetMapID()
    self.wait = (self.wait or 0) - elapsed
    if self.wait <= 0 or self.lastMapID ~= mapID then
        self.wait, self.lastMapID = .25, mapID
        SUI:SafeModuleCall(self, "update party map", self.DrawPins, mapID, StitchedAPI())
    end
    local scale = self.pinOverlay:GetEffectiveScale() / map:GetEffectiveScale()
    if scale <= 0 then return end
    for _, pin in pairs(self.pins) do
        if pin:IsShown() then
            local wanted = (pin.selection and 1.12 or 1) / scale
            if pin.face:GetScale() ~= wanted then pin.face:SetScale(wanted) end
        end
    end
end

function M:UpdateLayer()
    local wanted = self.profile.enabled and #self.members > 0 and (self.profile.markers or self.selected)
    local map = _G.WorldMapFrame
    local canvas = map and map.GetCanvas and map:GetCanvas()
    if wanted and canvas and self.canvas ~= canvas then
        if self.layer then
            self.layer:Hide()
            self.layer:SetScript("OnUpdate", nil)
            self.layer:SetScript("OnShow", nil)
            self.layer:SetScript("OnHide", nil)
        end
        self.layer = CreateFrame("Frame", nil, canvas)
        self.layer:SetAllPoints(canvas)
        self.layer:Hide()
        local view = map.ScrollContainer or map
        local overlay = CreateFrame("Frame", nil, view)
        overlay:SetAllPoints(view)
        overlay:SetFrameLevel(0)
        if overlay.SetClipsChildren then overlay:SetClipsChildren(true) end
        overlay:Hide()
        self.pinOverlay = overlay
        self.map, self.canvas, self.pins = map, canvas, {}
        self.layer:SetScript("OnShow", function() self.wait = 0; overlay:Show() end)
        self.layer:SetScript("OnHide", function() overlay:Hide(); self:HidePins() end)
    end
    if self.layer then
        self.wait = 0
        if wanted and canvas then
            self.layer:SetScript("OnUpdate", self.update)
            self.layer:Show()
        else
            self.layer:SetScript("OnUpdate", nil)
            self.layer:Hide()
        end
    end
end

function M:FocusMember(unit, id, name)
    if not self.profile.enabled then return end
    if InCombatLockdown and InCombatLockdown() then
        SUI:Print(SUI.Text("Перейти к игроку на карте можно после боя.", "You can jump to a party member on the map after combat."))
        return
    end
    local function StillMember()
        return Call(UnitExists, unit) and Identity(unit, MemberName(unit)) == id
    end
    if not StillMember() then return end
    local map = _G.WorldMapFrame
    local mapID = FindDestination(unit, id, name, map and map:GetMapID())
    if not mapID then
        SUI:Print(SUI.Text("Не удалось найти %s на карте.", "Could not find %s on the map."):format(name))
        return
    end
    self.request = (self.request or 0) + 1
    local request = self.request
    if not (map and map:IsShown()) then
        if type(ToggleWorldMap) == "function" then ToggleWorldMap()
        elseif C_Map and C_Map.OpenWorldMap then C_Map.OpenWorldMap(mapID) end
    end
    -- Opening the map can restore the last OpenMap view; jump after that work.
    SUI:After(0, self, "focus party map", function()
        map = _G.WorldMapFrame
        if self.request ~= request or not (map and map:IsShown() and StillMember())
            or (InCombatLockdown and InCombatLockdown()) then return end
        local mapID, x, y = FindDestination(unit, id, name, map:GetMapID())
        if not mapID then
            SUI:Print(SUI.Text("Не удалось найти %s на карте.", "Could not find %s on the map."):format(name))
            return
        end
        local exact = x ~= nil
        local function Glide()
            local api = StitchedAPI()
            if not api then return false end
            local u, v = Call(api.WorldFromMap, mapID, x or .5, y or .5)
            if not (IsNumber(u) and IsNumber(v)) then return false end
            local _, _, zoom = Call(api.GetView)
            local targetZoom = exact and math.max(IsNumber(zoom) and zoom or 1, 8) or 8
            return Call(api.ShowWorld, u, v, targetZoom) == true
        end
        if not Glide() then
            if map:GetMapID() ~= mapID and map.SetMapID then map:SetMapID(mapID) end
            if not Glide() and not StitchedAPI() and map:GetMapID() == mapID then
                if exact then
                    if map.PanAndZoomTo then map:PanAndZoomTo(x, y) end
                    -- Instant zoom may adjust the pan toward the old view.
                    if map.PanTo then map:PanTo(x, y) end
                elseif map.ResetZoom then
                    map:ResetZoom()
                end
            end
        end
        if not exact then
            self.selected = nil
            self:UpdateLayer()
            return
        end
        self.selected = { id = id }
        local selection = self.selected
        self:UpdateLayer()
        SUI:After(6, self, "clear party selection", function()
            if self.selected == selection then self.selected = nil; self:UpdateLayer() end
        end)
    end)
end

function M:OpenMenu(owner)
    if not (self.profile.enabled and MenuUtil and MenuUtil.CreateContextMenu) then return end
    self:UpdateMembers()
    self:UpdateLayer()
    SUI.SettingsTheme:OpenMenu(owner, function(_, root)
        if root.AddMenuAcquiredCallback and root.AddMenuReleasedCallback then
            root:AddMenuAcquiredCallback(function() SUI.SettingsTheme:PaintButton(owner, true) end)
            root:AddMenuReleasedCallback(function() SUI.SettingsTheme:PaintButton(owner, false) end)
        end
        root:CreateTitle(MENU_TITLE)
        if #self.members == 0 then root:CreateTitle(SUI.Text("Нет участников группы", "No party members")) end
        local map = _G.WorldMapFrame
        for index, member in ipairs(self.members) do
            local unit, id, name = member.unit, member.id, member.name
            local mapID, x, _, area = FindDestination(unit, id, name, map and map:GetMapID())
            local info = mapID and Call(C_Map.GetMapInfo, mapID)
            local zone = info and Public(info.name) or area
            local status = (Call(UnitIsConnected, unit) == false and SUI.Text("не в сети", "offline"))
                or (zone and (x and zone or zone .. (mapID and SUI.Text(" (только зона)", " (zone only)")
                    or SUI.Text(" (карта недоступна)", " (map unavailable)"))))
                or (not mapID and SUI.Text("местоположение неизвестно", "location unknown"))
            local label = index .. ". " .. name
            if status then label = label .. "  —  " .. status end
            root:CreateButton(label, function()
                SUI:SafeModuleCall(self, "select party member", self.FocusMember, unit, id, name)
            end)
        end
    end)
end

local MAP_BUTTON_PAD, MAP_BUTTON_GAP = 8, 4
local MAP_BUTTON_COLUMNS = 3

function M:RegisterMapCompanion(button)
    if self.mapCompanion ~= button then
        self.mapCompanion = button
        if self.mapButton then self.mapButton.layoutElapsed = .4 end
    end
    return self.mapButton
end

function M:PlaceMapButton(button, map)
    if InCombatLockdown() then return end
    local view = map.ScrollContainer or map
    local left, bottom, width, height = Call(view.GetRect, view)
    local scale = view:GetEffectiveScale()
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 or scale <= 0 then return end

    local blockers = {}
    local size = button:GetWidth()
    local companion = self.mapCompanion
    local below = companion and companion:IsShown() and companion:GetHeight() + MAP_BUTTON_GAP or 0
    local canvas = map.GetCanvas and map:GetCanvas()
    local minX = width - (size + MAP_BUTTON_PAD) * MAP_BUTTON_COLUMNS - MAP_BUTTON_GAP
    local function AddBounds(region, inheritedScale)
        if not region.IsVisible or not region:IsVisible() then return end
        local l, b, w, h = Call(region.GetRect, region)
        if not l or not b or not w or not h or w <= 0 or h <= 0 then return end
        local ratio = (region.GetEffectiveScale and region:GetEffectiveScale() or inheritedScale) / scale
        l, b, w, h = l * ratio - left, b * ratio - bottom, w * ratio, h * ratio
        -- Ignore broad panels and controls outside the strip along the right edge.
        if (h > 80 and w > 60) or b >= height or b + h <= 0 or l >= width or l + w <= minX then return end
        blockers[#blockers + 1] = { left = l, right = l + w, bottom = b, top = b + h }
        return true
    end

    local function Collect(parent)
        for _, child in ipairs({ parent:GetChildren() }) do
            if child ~= button and child ~= companion and child ~= view and child ~= canvas and child ~= map.BorderFrame
                and child ~= self.layer and child ~= self.pinOverlay and child:IsVisible() then
                AddBounds(child, scale)
                -- A full-size holder can contain tabs along the edge of the map.
                local childScale = child:GetEffectiveScale()
                for _, control in ipairs({ child:GetChildren() }) do AddBounds(control, childScale) end
                for _, region in ipairs({ child:GetRegions() }) do AddBounds(region, childScale) end
            end
        end
    end
    Collect(view)
    if map ~= view then Collect(map) end
    if map.BorderFrame and map.BorderFrame ~= view then Collect(map.BorderFrame) end

    local center = (height - size) / 2
    local minBottom = MAP_BUTTON_PAD + below
    local maxBottom = height - MAP_BUTTON_PAD - size
    local function SearchColumn(right, up)
        local b = math.max(center, minBottom)
        while b >= minBottom and b <= maxBottom do
            local nextBottom = b
            for _, box in ipairs(blockers) do
                if b - below < box.top + MAP_BUTTON_GAP and b + size > box.bottom - MAP_BUTTON_GAP
                    and right > box.left - MAP_BUTTON_GAP and right - size < box.right + MAP_BUTTON_GAP then
                    if up then
                        nextBottom = math.max(nextBottom, box.top + MAP_BUTTON_GAP + below)
                    else
                        nextBottom = math.min(nextBottom, box.bottom - MAP_BUTTON_GAP - size)
                    end
                end
            end
            if nextBottom == b then return b end
            b = nextBottom
        end
    end

    local x, y
    for column = 0, MAP_BUTTON_COLUMNS - 1 do
        local right = width - MAP_BUTTON_PAD - column * (size + MAP_BUTTON_PAD)
        if right - size < MAP_BUTTON_PAD then break end
        local above = SearchColumn(right, true)
        local below = SearchColumn(right, false)
        local b = above or below
        if above and below and center - below < above - center then b = below end
        if b then
            x, y = right - width, b - center
            break
        end
    end
    if not x then
        x, y = -MAP_BUTTON_PAD, math.max(0, center - MAP_BUTTON_PAD)
    end
    if x ~= button.mapX or y ~= button.mapY or view ~= button.mapView then
        button:ClearAllPoints()
        button:SetPoint("RIGHT", view, "RIGHT", x, y)
        button.mapX, button.mapY, button.mapView = x, y, view
    end
end

function M:UpdateMapButton()
    local map = _G.WorldMapFrame
    if self.profile.enabled and map and not self.mapButton and not InCombatLockdown() then
        local button = SUI.SettingsTheme:CreateMapIconButton(map, ICON, function(owner)
            GameTooltip:Hide()
            SUI:SafeModuleCall(self, "open party menu", self.OpenMenu, owner)
        end, true)
        button:EnableMouse(true)
        button:SetPoint("RIGHT", map.ScrollContainer or map, "RIGHT", -MAP_BUTTON_PAD, 0)
        button:HookScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_TOP")
            GameTooltip:AddLine(MENU_TITLE)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function(frame)
            if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
        end)
        button:HookScript("OnShow", function(frame)
            if not InCombatLockdown() then frame:SetFrameLevel(MapOverlayLevel(map, BUTTON_LEVEL)) end
            frame.layoutElapsed = .4
        end)
        button:SetScript("OnUpdate", function(frame, elapsed)
            frame.layoutElapsed = (frame.layoutElapsed or .4) + elapsed
            if frame.layoutElapsed < .4 then return end
            frame.layoutElapsed = 0
            SUI:SafeModuleCall(self, "place party map button", self.PlaceMapButton, frame, map)
        end)
        self.mapButton = button
    end
    if self.mapButton then
        if self.profile.enabled and map and not InCombatLockdown() then
            self.mapButton:SetFrameLevel(MapOverlayLevel(map, BUTTON_LEVEL))
        end
        self.mapButton:SetShown(self.profile.enabled)
    end
end

function M:OnProfileChanged()
    self.profile = SUI:GetModuleProfile(self.key)
    self.waitingForWorldMap = not _G.WorldMapFrame
    self.request = (self.request or 0) + 1
    self.selected = nil
    if self.profile.enabled then self:UpdateMembers() end
    self:UpdateMapButton()
    self:UpdateLayer()
end

function M:WantsEvent(event)
    if not self.profile or not self.profile.enabled then return false end
    if event == "ADDON_LOADED" then return self.waitingForWorldMap end
    return true
end

function M:OnEvent(event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_WorldMap" then return end
    self:UpdateMembers()
    if event ~= "GROUP_ROSTER_UPDATE" then self:UpdateMapButton() end
    self:UpdateLayer()
    if self.waitingForWorldMap and _G.WorldMapFrame then
        self.waitingForWorldMap = false
        SUI:RefreshModuleEvents()
    end
end

function M:Initialize()
    self.update = function(_, elapsed) self:Tick(elapsed) end
    self:OnProfileChanged()
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        SUI:RegisterModuleEvent(self, event)
    end
end
