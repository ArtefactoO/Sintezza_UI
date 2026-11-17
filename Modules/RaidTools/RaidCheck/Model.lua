local ADDON, SUI = ...
local SRT = SUI.RaidTools

local function Readable(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function SRT:BuildRoster()
    local rows = {}
    local inRaid = IsInRaid and IsInRaid()
    local count = inRaid and GetNumGroupMembers() or ((IsInGroup and IsInGroup()) and GetNumSubgroupMembers() + 1 or 1)
    for i = 1, count do
        local unit = inRaid and "raid" .. i or (i == 1 and "player" or "party" .. (i - 1))
        local name, realm = UnitName(unit)
        name, realm = Readable(name), Readable(realm)
        if name then
            local _, class = UnitClass(unit)
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
            local online = UnitIsConnected and UnitIsConnected(unit)
            rows[#rows + 1] = {
                unit = unit, name = realm and realm ~= "" and name .. "-" .. realm or name,
                class = Readable(class), role = Readable(role),
                online = Readable(online),
                ready = "PENDING", aura = {},
            }
        end
    end
    return rows
end

function SRT:SortRoster(rows)
    if self.profile.raidCheck.sort ~= "NOT_READY" then return rows end
    table.sort(rows, function(a, b)
        local ap = (a.online == false) and 0 or (a.ready == "notready" and 1 or (a.ready == "PENDING" and 2 or 3))
        local bp = (b.online == false) and 0 or (b.ready == "notready" and 1 or (b.ready == "PENDING" and 2 or 3))
        return ap == bp and a.name < b.name or ap < bp
    end)
    return rows
end
