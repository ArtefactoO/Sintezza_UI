local _, SUI = ...
local shared = Sintezza_Theme
local function Settings() return SUI.db end
SUI.InterfaceFonts = shared.Fonts
SUI.SettingsTheme = shared:ForAddon(Settings)
SUI.Theme = shared:ForAddon(Settings, shared.Theme)
