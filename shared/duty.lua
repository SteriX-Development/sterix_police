--[[
    shared/duty.lua

    Formatting shared by both realms: the server never sends pre-formatted
    strings (only raw seconds - see BRIDGE.md-style "server is authoritative"
    principle applied to duty data), so both client menus and any server-side
    debug printing use this same function.
]]

---@param seconds number
---@return string formatted e.g. "08h 30m"
function FormatDutyTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    return ('%02dh %02dm'):format(hours, minutes)
end
