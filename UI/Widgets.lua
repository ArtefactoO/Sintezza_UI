local _, SUI = ...
local Text = SUI.Text
local W = Sintezza_Theme:CreateWidgets(SUI.SettingsTheme)
SUI.Widgets = W

function W.onToggle()
    if SUI.initialized then SUI:RefreshModuleEvents() end
end

function W:FeatureToggle(parent, id, label, description, guard, changed)
    local dependency = SUI:GetFeatureRequirementLabel(id)
    local row = self:Toggle(parent, label, function() return SUI:GetFeature(id) end, function(value)
        if SUI:SetFeature(id, value) and changed then changed() end
    end, description or (dependency and (Text("Требуется ", "Requires ") .. dependency)), true)
    return self:BindAvailability(row, function()
        local available, reason = SUI:GetFeatureAvailability(id)
        if not available then return false, reason end
        if guard then return guard() end
        return true
    end)
end
