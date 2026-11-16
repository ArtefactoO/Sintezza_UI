local _, SUI = ...

function SUI:Initialize()
    if self.initialized then return end
    self:InitializeDatabase()
    self.InterfaceFonts:AdoptLegacySelection(self.db)

    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        if module and module.Initialize then
            local ok, err = self:SafeModuleCall(module, "initialize", module.Initialize)
            module.initialized = ok
            if ok then
                module.initializeError = nil
            else
                module.initializeError = tostring(err)
            end
        end
    end

    if self.SettingsUI then self.SettingsUI:Initialize() end
    if self.MinimapButton then self.MinimapButton:Initialize() end
    self.initialized = true
    self:RefreshModuleEvents()
end
