local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")

local function WithFractionBelowOne(options)
    local config = options.config
    if type(config.GetAbbreviateNumberData) ~= "function" then return end
    local rows = config:GetAbbreviateNumberData()
    local last = rows[#rows]
    if not last or last.breakpoint ~= 1 then return end

    -- Leave Ellesmere's shared config and its existing tiers intact.
    rows[#rows + 1] = {
        breakpoint = 0,
        abbreviation = "",
        significandDivisor = 0.1,
        fractionDivisor = 10,
        abbreviationIsGlobal = false,
    }
    local compact = { config = CreateAbbreviateConfig(rows) }
    local sample = AbbreviateNumbers(0.57142857142857, compact)
    if sample:match("^0[.,][56]$") then return compact end
end

function M:InstallMeterNumbers()
    if self.meterNumbersInstalled or not SUI.isForever or not SUI:IntegrationEnabled("meters") then return end
    if not SUI:IsAddonLoaded("EllesmereUIDamageMeters") then return end
    local eui = EllesmereUI
    if not eui or type(eui.AbbreviateNumber) ~= "function"
        or type(eui.NumberFormatOptions) ~= "function"
        or type(CreateAbbreviateConfig) ~= "function" or type(AbbreviateNumbers) ~= "function" then return end

    local original = eui.AbbreviateNumber
    local optionsByConfig = {}
    eui.AbbreviateNumber = function(value, forceWestern)
        local options = eui.NumberFormatOptions("meter", forceWestern)
        local config = options and options.config
        if not config then return original(value, forceWestern) end

        local compact = optionsByConfig[config]
        if compact == nil then
            local ok, result = pcall(WithFractionBelowOne, options)
            compact = ok and result or false
            optionsByConfig[config] = compact
        end
        if compact then
            -- Use the same native path as Ellesmere for secret combat numbers.
            return AbbreviateNumbers(tonumber(value) or 0, compact)
        end
        return original(value, forceWestern)
    end
    self.meterNumbersInstalled = true
end
