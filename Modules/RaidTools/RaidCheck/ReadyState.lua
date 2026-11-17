local ADDON, SUI = ...
local SRT = SUI.RaidTools

function SRT:ResetReadyState()
    self.readyCache = {}
    self.readyCheckActive = false
    self.readyCheckFinal = false
end

function SRT:ApplyReadyState(rows)
    rows = type(rows) == "table" and rows or {}
    self.readyCache = self.readyCache or {}
    for _, row in ipairs(rows) do
        local current = GetReadyCheckStatus and GetReadyCheckStatus(row.unit) or nil
        if issecretvalue and issecretvalue(current) then current = nil end
        if current == "waiting" then current = "PENDING" end
        if current then
            row.ready = current
            self.readyCache[row.name] = current
        elseif (self.readyCheckActive or self.readyCheckFinal) and self.readyCache[row.name] then
            row.ready = self.readyCache[row.name]
        end
    end
    return rows
end
