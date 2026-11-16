local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")
local states = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local queued = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\rounded\\rounded-"
local SQUARE = "Interface\\AddOns\\DandersFrames\\Media\\DF_SquareBorder"

local function PublicNumber(v)
    return type(v) == "number" and not (issecretvalue and issecretvalue(v))
end

local function SetArt(texture, radius, inverse)
    local wrap = inverse and "CLAMPTOWHITE" or "CLAMPTOBLACKADDITIVE"
    local name = inverse and "inv-" or ""
    assert(texture:SetTexture(MEDIA .. name .. radius .. ".tga", wrap, wrap) ~= false, "rounded dispel texture unavailable")
    texture:SetTextureSliceMargins(radius, radius, radius, radius)
    texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

local function RoundedRadius(value, w, h)
    return math.max(1, math.min(16, math.floor(value + .5), math.floor((math.min(w, h) - 1) / 2)))
end

local function SquareCrop(size, width)
    -- Danders' DF_SquareBorder artwork has a band one quarter of the image wide.
    local fraction = width / math.max(size, 1)
    if fraction >= .25 then return 0 end
    return (.25 - fraction) / (1 - 2 * fraction)
end

local function ClearRing(texture, state)
    if state.attached then pcall(texture.RemoveMaskTexture, texture, state.mask) end
    texture:ClearTextureSlice()
    texture:SetTexture(SQUARE)
    local x, y = state.cropX, state.cropY
    texture:SetTexCoord(x, 1 - x, y, 1 - y)
end

local function ClearGradients(state)
    for texture, gradient in pairs(state.gradients) do
        pcall(texture.RemoveMaskTexture, texture, gradient.mask)
        state.gradients[texture] = nil
    end
end

local function ClearState(state)
    ClearGradients(state)
    for texture, ring in pairs(state.rings) do
        pcall(ClearRing, texture, ring)
        state.rings[texture] = nil
    end
    for _, entry in pairs(state.gradientMasks) do entry.mask:Hide() end
    state.radius, state.inset = nil, nil
    state.factory, state.factoryVersion, state.factoryGeneration = nil, nil, nil
end

local function Gradient(state, texture)
    if not (texture and texture.AddMaskTexture) then return end
    local gradient = state.gradients[texture]
    if gradient then gradient.pass = state.pass; return end
    local ok, parent = pcall(texture.GetParent, texture)
    if not (ok and parent and parent.CreateMaskTexture) then return end
    -- TOP/BOTTOM and full gradients use different hosts in the aura factory.
    local entry = state.gradientMasks[parent]
    if not entry then
        local created, mask = pcall(parent.CreateMaskTexture, parent)
        if not (created and mask) then return end
        entry = { mask = mask }
        state.gradientMasks[parent] = entry
    end
    local mask = entry.mask
    local radius, inset = state.radius, state.inset
    if entry.radius ~= radius or entry.inset ~= inset then
        SetArt(mask, radius, false)
        mask:ClearAllPoints()
        mask:SetPoint("TOPLEFT", state.frame, "TOPLEFT", inset, -inset)
        mask:SetPoint("BOTTOMRIGHT", state.frame, "BOTTOMRIGHT", -inset, inset)
        entry.radius, entry.inset = radius, inset
    end
    mask:Show()
    local attached, result = pcall(texture.AddMaskTexture, texture, mask)
    if attached and result ~= false then
        state.gradients[texture] = { mask = mask, pass = state.pass }
    end
end

local function Ring(state, texture, outer, inner, width)
    if not (texture and texture.ClearTextureSlice and texture.AddMaskTexture) then return end
    local r = state.rings[texture]
    if not r then
        local parent = texture:GetParent()
        if not (parent and parent.CreateMaskTexture) then return end
        r = { mask = parent:CreateMaskTexture() }
        state.rings[texture] = r
    end
    r.pass = state.pass
    r.cropX, r.cropY = state.cropX, state.cropY
    local ok = pcall(function()
        if r.outer ~= outer or r.inner ~= inner or r.width ~= width then
            if r.attached then texture:RemoveMaskTexture(r.mask); r.attached = nil end
            SetArt(r.mask, inner, true)
            r.mask:ClearAllPoints()
            r.mask:SetPoint("TOPLEFT", texture, "TOPLEFT", width, -width)
            r.mask:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT", -width, width)
            r.mask:Show()
            texture:AddMaskTexture(r.mask)
            r.attached = true
            SetArt(texture, outer, false)
            r.outer, r.inner, r.width = outer, inner, width
        end
        -- AddDispelTypeTexture can make GetTexCoord secret. Danders may
        -- reapply its square crop, so write the known rounded coordinates.
        texture:SetTexCoord(0, 1, 0, 1)
    end)
    if not ok then
        pcall(ClearRing, texture, r)
        state.rings[texture] = nil
    end
end

local function Widget(state, widget, outer, inner, width)
    if not widget then return end
    local bar = widget.gradient
    if bar and bar.GetStatusBarTexture then
        local ok, texture = pcall(bar.GetStatusBarTexture, bar)
        if ok then Gradient(state, texture) end
    end
    Gradient(state, widget.nativeGradient)
    Gradient(state, widget.gradientDarken)
    Gradient(state, widget.gradientTop)
    Gradient(state, widget.gradientBottom)
    Gradient(state, widget.gradientLeft)
    Gradient(state, widget.gradientRight)
    pcall(Ring, state, widget.borderRing, outer, inner, width)
end

function M:SyncDandersDispelShape(frame, radius)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    radius = radius or self:GetDandersShapeRadius(frame)
    local state = states[frame]
    if not (state or radius > 0) then return end
    if InCombatLockdown and InCombatLockdown() then
        pending[frame] = true
        self.pendingDispelShape = true
        return
    end
    if radius <= 0 then
        if state then ClearState(state) end
        return
    end
    if not (Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched and frame.CreateMaskTexture) then return end
    local df = self:GetDanders()
    local db = df and df.GetFrameDB and df:GetFrameDB(frame)
    if not db then return end
    local handle = frame.dispelFactory
    local slots = handle and handle.GetOverlaySlots and handle:GetOverlaySlots()
    if not (slots or frame.dfDispelOverlay) then
        if state then ClearState(state) end
        return
    end
    local w, h = frame:GetSize()
    if not (PublicNumber(w) and PublicNumber(h) and math.min(w, h) > 2) then return end
    local nativeWidth = tonumber(db.dispelBorderSize) or 2
    local width = math.max(1, nativeWidth)
    local outset = tonumber(db.dispelBorderInset) or 0
    if db.pixelPerfect and df.PixelPerfect then
        width, outset = df:PixelPerfect(width), df:PixelPerfect(outset)
        nativeWidth = nativeWidth >= 1 and width or df:PixelPerfect(nativeWidth)
    end
    local outer = RoundedRadius(radius + outset, w + 2 * outset, h + 2 * outset)
    local inner = RoundedRadius(radius + outset - width, w + 2 * (outset - width), h + 2 * (outset - width))
    local inset = 1
    local pp = EllesmereUI and EllesmereUI.PP
    local scale = frame:GetEffectiveScale()
    if pp and PublicNumber(pp.perfect) and PublicNumber(scale) and scale > 0 then inset = pp.perfect / scale end
    local fillRadius = RoundedRadius(radius - inset, w - 2 * inset, h - 2 * inset)
    if not state then
        state = {
            frame = frame, gradients = {}, gradientMasks = setmetatable({}, { __mode = "k" }),
            rings = {}, pass = 0,
        }
        states[frame] = state
    end
    if state.radius ~= fillRadius or state.inset ~= inset then
        ClearGradients(state)
        state.radius, state.inset = fillRadius, inset
    end
    state.pass = state.pass + 1
    state.cropX = SquareCrop(w + 2 * outset, nativeWidth)
    state.cropY = SquareCrop(h + 2 * outset, nativeWidth)
    Widget(state, frame.dfDispelOverlay, outer, inner, width)
    for _, btn in pairs(slots or {}) do
        Widget(state, btn.dfDispelWidget, outer, inner, width)
        for _, texture in pairs(btn.dfDispelEdgeTex or {}) do Gradient(state, texture) end
        pcall(Ring, state, btn.dfDispelRing, outer, inner, width)
    end
    for texture, gradient in pairs(state.gradients) do
        if gradient.pass ~= state.pass then
            pcall(texture.RemoveMaskTexture, texture, gradient.mask)
            state.gradients[texture] = nil
        end
    end
    for texture, ring in pairs(state.rings) do
        if ring.pass ~= state.pass then
            pcall(ClearRing, texture, ring)
            state.rings[texture] = nil
        end
    end
    state.factory, state.factoryVersion, state.factoryGeneration =
        handle, frame.dfDispelFactoryVersion, frame.dfDispelStyledGen
end

function M:RefreshPendingDispelShapes()
    self.pendingDispelShape = nil
    for frame in pairs(pending) do
        pending[frame] = nil
        SUI:SafeModuleCall(self, "Danders dispel shape", self.SyncDandersDispelShape, frame)
    end
end

function M:InstallDandersDispelShape(df)
    if not hooksecurefunc or hooked[df] then return end
    hooked[df] = true
    local function Queue(frame)
        if not frame or queued[frame] or pending[frame] then return end
        if not states[frame] and M:GetDandersShapeRadius(frame) <= 0 then return end
        queued[frame] = true
        SUI:After(0, M, "Danders dispel shape", function()
            queued[frame] = nil
            M:SyncDandersDispelShape(frame)
        end)
    end
    local hasFactory = type(df.DriveDispelOverlayFactory) == "function"
    if hasFactory then
        hooksecurefunc(df, "DriveDispelOverlayFactory", function(_, frame)
            if not frame then return end
            local state, handle = states[frame], frame.dispelFactory
            local version = frame.dfDispelFactoryVersion
            if state and handle and state.factory == handle and version ~= nil
                and state.factoryVersion == version and state.factoryGeneration == frame.dfDispelStyledGen then return end
            Queue(frame)
        end)
    end
    if type(df.UpdateDispelOverlay) == "function" then
        hooksecurefunc(df, "UpdateDispelOverlay", function(_, frame)
            if not frame then return end
            local legacy = frame.dfDispelOverlay
            if not hasFactory or not frame.dispelFactory or (legacy and legacy:IsShown()) then Queue(frame) end
        end)
    end
end

