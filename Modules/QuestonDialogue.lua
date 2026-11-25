local _, SUI = ...
if not SUI.isForever then return end

local module = SUI:RegisterModule("questonDialogue", {})

local function StyleChainCount(view, host, chain, _, _, paper)
    if not (paper and chain) then return end

    -- Queston uses its parchment colors for both DialogueUI themes.
    local dialogue = _G.DialogueUI_DB
    if type(dialogue) ~= "table" or dialogue.Theme ~= 2 then return end

    local plate = view.chainPlates[host]
    local text = plate and plate.text
    if not text or type(text.SetTextColor) ~= "function" then return end

    text:SetTextColor(unpack(SUI.Theme.warning))
    if type(text.SetShadowOffset) == "function" and type(text.SetShadowColor) == "function" then
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)
    end
end

function module:Attach()
    if self.attached or type(hooksecurefunc) ~= "function" then return end
    local queston = _G.QuestonForever
    local view = type(queston) == "table" and queston.DialogMarksView
    if type(view) ~= "table" or type(view.PaintChain) ~= "function" or type(view.chainPlates) ~= "table" then
        return
    end

    hooksecurefunc(view, "PaintChain", StyleChainCount)
    self.attached = true
end

function module:Initialize()
    self:Attach()
    if not self.attached then SUI:RegisterModuleEvent(self, "ADDON_LOADED") end
end

function module:WantsEvent()
    return not self.attached
end

function module:OnEvent(_, addon)
    if addon == "QuestonForever" then
        self:Attach()
        if self.attached then SUI:RefreshModuleEvents() end
    end
end
