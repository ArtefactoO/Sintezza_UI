local ADDON, SUI = ...
local SRT = SUI.RaidTools

function SRT:GetPanelVisual(panel)
    return panel and (panel.visual or panel)
end

function SRT:IsPanelHovered(panel)
    return panel and panel:IsShown() and panel:IsMouseOver()
end

function SRT:FadePanelTo(panel, alpha)
    local visual = self:GetPanelVisual(panel)
    if not visual then return end
    panel.fadeGeneration = (panel.fadeGeneration or 0) + 1
    panel.fadeTarget = alpha
    if math.abs(visual:GetAlpha() - alpha) < .001 then
        visual:SetAlpha(alpha)
        visual:SetScript("OnUpdate", nil)
        return
    end
    visual:SetScript("OnUpdate", function(frame, elapsed)
        local target = panel.fadeTarget or alpha
        local duration = math.max(.01, tonumber(panel.cfg.fadeDuration) or .11)
        local current = frame:GetAlpha()
        local step = elapsed / duration
        if current < target then
            current = math.min(target, current + step)
        else
            current = math.max(target, current - step)
        end
        frame:SetAlpha(current)
        if current == target then frame:SetScript("OnUpdate", nil) end
    end)
end

function SRT:SchedulePanelFade(panel)
    if not panel or self.settingsOpen or not panel.cfg.mouseover then return end
    panel.fadeGeneration = (panel.fadeGeneration or 0) + 1
    local generation = panel.fadeGeneration
    SUI:After(tonumber(panel.cfg.fadeDelay) or .12, self, "fade delay", function()
        if not panel or generation ~= panel.fadeGeneration or SRT.settingsOpen then return end
        if not SRT:ShouldShowPanelVisual(panel) or not SRT:IsPanelHovered(panel) then SRT:FadePanelTo(panel, 0) end
    end)
end

function SRT:ConfigureFade(panel)
    panel:SetScript("OnEnter", function(p)
        if p.cfg.mouseover and SRT:ShouldShowPanelVisual(p) then
            SRT:FadePanelTo(p, p.cfg.hoverAlpha or 1)
        end
    end)
    panel:SetScript("OnLeave", function(p) SRT:SchedulePanelFade(p) end)
end

function SRT:RefreshFade(panel)
    if not panel then return end
    if not self:ShouldShowPanelVisual(panel) then
        self:FadePanelTo(panel, 0)
    elseif self.settingsOpen then
        -- Settings preview only overrides mouseover hiding.  The configured
        -- hover alpha, panel visibility and all visual styling stay intact.
        self:FadePanelTo(panel, panel.cfg.mouseover and (panel.cfg.hoverAlpha or 1) or 1)
    elseif not panel.cfg.mouseover then
        self:FadePanelTo(panel, 1)
    elseif self:IsPanelHovered(panel) then
        self:FadePanelTo(panel, panel.cfg.hoverAlpha or 1)
    else
        self:FadePanelTo(panel, 0)
    end
end
