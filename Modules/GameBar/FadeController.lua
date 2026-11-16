local ADDON, SUI = ...
local SGB = SUI.GameBar

function SGB:FadeTo(alpha)
    local root = self.visualRoot or self.root
    if not root then return end
    if not self.fadeControllerFrame then self.fadeControllerFrame = CreateFrame("Frame") end
    local controller = self.fadeControllerFrame
    self.fadeTarget = alpha
    if math.abs(root:GetAlpha() - alpha) < .001 then
        root:SetAlpha(alpha)
        controller:SetScript("OnUpdate", nil)
        return
    end
    controller:SetScript("OnUpdate", function(frame, elapsed)
        local fadeFrame = SGB.visualRoot or SGB.root
        local current, target = fadeFrame:GetAlpha(), SGB.fadeTarget or alpha
        local duration = math.max(.01, SGB.profile.fadeDuration or .11)
        local step = elapsed / duration
        if current < target then
            current = math.min(target, current + step)
        else
            current = math.max(target, current - step)
        end
        fadeFrame:SetAlpha(current)
        if current == target then frame:SetScript("OnUpdate", nil) end
    end)
end

function SGB:IsPanelHovered()
    if self.root and self.root:IsMouseOver() then return true end
    for _, button in ipairs(self.buttons or {}) do
        if button:IsShown() and button:IsMouseOver() then return true end
    end
    return false
end

function SGB:OnPanelEnter()
    self.hoverGeneration = (self.hoverGeneration or 0) + 1
    if self.profile and self.profile.enabled then self:FadeTo(self.profile.hoverAlpha or 1) end
end

function SGB:OnPanelLeave()
    self.hoverGeneration = (self.hoverGeneration or 0) + 1
    local generation = self.hoverGeneration
    SUI:After(self.profile.fadeDelay or .04, self, "fade delay", function()
        if not SGB.root or generation ~= SGB.hoverGeneration then return end
        if not SGB:IsPanelHovered() then SGB:RefreshFade() end
    end)
end

function SGB:RefreshFade()
    if not self.root then return end
    if self.settingsOpen then
        self:FadeTo(self.profile.hoverAlpha or 1)
    elseif self:InCombat() and self.profile.combatVisibility == "SHOW" then
        self:FadeTo(self.profile.hoverAlpha or 1)
    elseif not self.profile.mouseover then
        self:FadeTo(self.profile.hoverAlpha or 1)
    elseif self:IsPanelHovered() then
        self:FadeTo(self.profile.hoverAlpha or 1)
    else
        -- Mouseover mode is strict: hidden while idle, visible on hover.
        -- Older profiles may carry a non-zero idleAlpha from the former
        -- ambiguous idle transparency slider; do not let it defeat the
        -- explicit mouseover toggle.
        self:FadeTo(0)
    end
end
