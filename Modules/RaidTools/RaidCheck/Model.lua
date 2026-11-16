local ADDON, SUI = ...
local SRT = SUI.RaidTools

function SRT:BuildRoster()
    local rows = {}
    local count = (IsInRaid and IsInRaid()) and GetNumGroupMembers() or ((IsInGroup and IsInGroup()) and GetNumSubgroupMembers() + 1 or 1)
    for i = 1, count do
        local unit = (IsInRaid and IsInRaid()) and "raid" .. i or (i == 1 and "player" or "party" .. (i - 1))
        local name, realm = UnitName(unit)
        if name then
            local _, class = UnitClass(unit)
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
            local online = UnitIsConnected and UnitIsConnected(unit)
            local ready = GetReadyCheckStatus and GetReadyCheckStatus(unit) or nil
            if ready == "waiting" then ready = "PENDING" end
            rows[#rows + 1] = { unit = unit, name = realm and realm ~= "" and name .. "-" .. realm or name, class = class or "PRIEST", role = role, online = online ~= false, ready = ready or "PENDING", aura = {} }
        end
    end
    return rows
end

function SRT:SortRoster(rows)
    if self.profile.raidCheck.sort ~= "NOT_READY" then return rows end
    table.sort(rows, function(a, b)
        local ap = (not a.online) and 0 or (a.ready == "notready" and 1 or (a.ready == "PENDING" and 2 or 3))
        local bp = (not b.online) and 0 or (b.ready == "notready" and 1 or (b.ready == "PENDING" and 2 or 3))
        return ap == bp and a.name < b.name or ap < bp
    end)
    return rows
end
