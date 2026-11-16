local ADDON, SUI = ...
local SRT = SUI.RaidTools
local ICON_PATH = Sintezza_Theme.icons.RaidTools
SRT.media = {
    target = ICON_PATH .. "Target_",
    world = ICON_PATH .. "World_",
    clear = ICON_PATH .. "Clear.tga",
    -- The ready button also opens the audit window on right click.  The
    -- denser checklist glyph matches that combined action and, unlike the
    -- thin shield outline, remains legible with GameBar's dark hover tint.
    ready = ICON_PATH .. "CommandAudit-v2.tga",
    pull = ICON_PATH .. "CommandPull-v2.tga",
    audit = ICON_PATH .. "CommandAudit-v2.tga",
    ping = "Interface\\Minimap\\Ping\\ping5",
}
function SRT:SetRaidIcon(texture, index)
    texture:SetTexture(self.media.target .. index .. ".tga")
    texture:SetTexCoord(0, 1, 0, 1)
end
function SRT:SetWorldIcon(texture, marker)
    texture:SetTexture(self.media.world .. marker .. ".tga")
    texture:SetTexCoord(0, 1, 0, 1)
end
