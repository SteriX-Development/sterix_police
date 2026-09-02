--[[
    server/addons/duty/tracking.lua

    The duty time-tracking engine. Server-authoritative: every timestamp,
    identifier and calculation here comes from the server, never the client.

    Concepts (do not mix these up - see BRIDGE.md-style separation):
      - CURRENT SHIFT: the duration of the player's presently active duty
        session (now - startTime), regardless of how many calendar days it
        has crossed.
      - DAILY TOTAL: all duty time attributed to one calendar date, summed
        across every (possibly many) shifts the player worked that day.
      - JOB TOTAL: daily totals summed across every employee of a job - see
        server/addons/duty/boss.lua.

    ActiveShifts (in-memory, per identifier):
        {
            source = number,       -- current player source (for lookups on disconnect)
            startTime = number,    -- unix seconds the shift actually started - never mutated
            flushedUntil = number, -- unix seconds up to which player_duty_days already has this
                                    -- shift's time recorded - this is the "watermark"
        }

    Race-safety rule followed throughout this file: whenever the in-memory
    watermark (ActiveShifts[id] or the table itself) needs to change alongside
    an async oxmysql call, the watermark is updated to its FINAL value
    synchronously, before the await. That way any other coroutine (a
    concurrent off-duty request, a disconnect, the midnight thread) that reads
    it mid-await always sees a correct, non-overlapping range to work with -
    see FinalizeShift, the midnight thread, and the restart recovery below.
]]

DutyTracking = DutyTracking or {}

local ActiveShifts = {}

-- Guards against a player toggling duty in the first instant after resource
-- start, before EnsureTables() has finished creating the tables on a brand
-- new install - every entry point that touches the database waits on this.
local tablesReady = false

local function WaitForTables()
    while not tablesReady do
        Wait(50)
    end
end

-- ---------------------------------------------------------------------------
-- Time helpers
-- ---------------------------------------------------------------------------

local function GetDayStart(ts)
    local t = os.date('*t', ts)
    t.hour, t.min, t.sec = 0, 0, 0
    return os.time(t)
end

local function GetDateString(ts)
    return os.date('%Y-%m-%d', ts)
end

-- ---------------------------------------------------------------------------
-- Database
-- ---------------------------------------------------------------------------

---@param identifier string
---@param date string YYYY-MM-DD
---@param seconds number
function DutyTracking.AddDutyTime(identifier, date, seconds)
    if not seconds or seconds <= 0 then return end

    MySQL.insert.await([[
        INSERT INTO player_duty_days (identifier, duty_date, total_seconds)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE total_seconds = total_seconds + VALUES(total_seconds)
    ]], { identifier, date, math.floor(seconds) })
end

---@param identifier string
---@param date string YYYY-MM-DD
---@return number seconds
function DutyTracking.GetDailyDutyTotal(identifier, date)
    local row = MySQL.single.await('SELECT total_seconds FROM player_duty_days WHERE identifier = ? AND duty_date = ?', { identifier, date })
    return row and row.total_seconds or 0
end

---@param identifier string
---@param days number how many most-recent days to return
---@return { date: string, seconds: number }[] newest first
function DutyTracking.GetDailyDutyTotals(identifier, days)
    local rows = MySQL.query.await('SELECT duty_date, total_seconds FROM player_duty_days WHERE identifier = ? ORDER BY duty_date DESC LIMIT ?', { identifier, days })
    local results = {}

    for _, row in ipairs(rows or {}) do
        results[#results + 1] = { date = row.duty_date, seconds = row.total_seconds }
    end

    return results
end

function DutyTracking.SaveActiveDuty(identifier, startTime, flushedUntil)
    MySQL.insert.await([[
        INSERT INTO player_active_duty (identifier, shift_start, last_flushed)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE shift_start = VALUES(shift_start), last_flushed = VALUES(last_flushed)
    ]], { identifier, startTime, flushedUntil })
end

function DutyTracking.UpdateActiveDutyFlush(identifier, flushedUntil)
    MySQL.update.await('UPDATE player_active_duty SET last_flushed = ? WHERE identifier = ?', { flushedUntil, identifier })
end

function DutyTracking.RemoveActiveDuty(identifier)
    MySQL.query.await('DELETE FROM player_active_duty WHERE identifier = ?', { identifier })
end

---@return { identifier: string, shift_start: number, last_flushed: number }[]
function DutyTracking.LoadAllActiveDuty()
    return MySQL.query.await('SELECT identifier, shift_start, last_flushed FROM player_active_duty') or {}
end

--- Auto-installer: creates both tables (see sql/install.sql) if they don't
--- already exist, so this resource works out of the box without requiring a
--- manual SQL import. Safe to run on every resource start - CREATE TABLE IF
--- NOT EXISTS is a no-op once the tables are there. Awaited before anything
--- else touches the database (see the onResourceStart handler below), so a
--- completely fresh database still works on first boot.
function DutyTracking.EnsureTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS player_duty_days (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(100) NOT NULL,
            duty_date DATE NOT NULL,
            total_seconds INT NOT NULL DEFAULT 0,

            UNIQUE KEY unique_player_day (identifier, duty_date),
            INDEX idx_identifier_date (identifier, duty_date)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS player_active_duty (
            identifier VARCHAR(100) PRIMARY KEY,
            shift_start BIGINT NOT NULL,
            last_flushed BIGINT NOT NULL
        )
    ]])

    tablesReady = true
end

-- ---------------------------------------------------------------------------
-- Shift processing - the one place that turns a time range into daily totals
-- ---------------------------------------------------------------------------

---@param identifier string
---@param fromTime number unix seconds, inclusive
---@param toTime number unix seconds, exclusive
--- Splits [fromTime, toTime) at every midnight boundary it crosses and adds
--- each day's seconds to that day's row. Handles same-day, midnight-crossing,
--- and multi-day (any number of days) ranges identically - never just
--- `toTime - fromTime` assigned to the starting date.
function DutyTracking.ProcessShift(identifier, fromTime, toTime)
    if not identifier or not fromTime or not toTime or toTime <= fromTime then
        return
    end

    local cursor = fromTime

    while cursor < toTime do
        local nextDayStart = GetDayStart(cursor) + 86400
        local segmentEnd = math.min(toTime, nextDayStart)
        local seconds = segmentEnd - cursor

        if seconds > 0 then
            DutyTracking.AddDutyTime(identifier, GetDateString(cursor), seconds)
        end

        cursor = segmentEnd
    end
end

-- ---------------------------------------------------------------------------
-- Live state
-- ---------------------------------------------------------------------------

---@param identifier string
function DutyTracking.IsOnDuty(identifier)
    return ActiveShifts[identifier] ~= nil
end

---@param identifier string
---@return number seconds 0 if not on duty
function DutyTracking.GetCurrentShiftDuration(identifier)
    local shift = ActiveShifts[identifier]
    if not shift then return 0 end

    return os.time() - shift.startTime
end

---@param identifier string
---@return number seconds completed sessions today + live portion of today's active session
function DutyTracking.GetTodayTotal(identifier)
    local now = os.time()
    local total = DutyTracking.GetDailyDutyTotal(identifier, GetDateString(now))

    local shift = ActiveShifts[identifier]
    if shift then
        local liveFrom = math.max(shift.flushedUntil, GetDayStart(now))
        local liveSeconds = now - liveFrom

        if liveSeconds > 0 then
            total = total + liveSeconds
        end
    end

    return total
end

-- ---------------------------------------------------------------------------
-- On duty / off duty
-- ---------------------------------------------------------------------------

---@param source number
---@return boolean started false if already on duty (prevents duplicate sessions)
function DutyTracking.GoOnDuty(source)
    local identifier = Bridge.GetPlayerIdentifier(source)
    if not identifier then return false end

    WaitForTables()

    if ActiveShifts[identifier] then
        return false
    end

    local now = os.time()
    ActiveShifts[identifier] = { source = source, startTime = now, flushedUntil = now }
    DutyTracking.SaveActiveDuty(identifier, now, now)

    return true
end

---@param identifier string
---@param endTime? number defaults to os.time()
---@return boolean finalized false if there was no active shift (prevents double counting)
function DutyTracking.FinalizeShift(identifier, endTime)
    local shift = ActiveShifts[identifier]
    if not shift then
        return false
    end

    -- clear immediately (synchronously, before any await below) so a
    -- concurrent call for the same identifier - a disconnect firing right as
    -- an explicit off-duty request is mid-flight, for example - sees no
    -- active shift and safely no-ops instead of double-processing this shift
    ActiveShifts[identifier] = nil

    endTime = endTime or os.time()

    if endTime > shift.flushedUntil then
        DutyTracking.ProcessShift(identifier, shift.flushedUntil, endTime)
    end

    DutyTracking.RemoveActiveDuty(identifier)

    return true
end

---@param source number
---@return boolean finalized
function DutyTracking.GoOffDuty(source)
    local identifier = Bridge.GetPlayerIdentifier(source)
    if not identifier then return false end

    return DutyTracking.FinalizeShift(identifier)
end

---@param source number
--- Looks the source up by scanning ActiveShifts instead of asking the
--- framework for the player's identifier, because by the time `playerDropped`
--- reaches this resource the framework's own player object may already be
--- gone (other resources' playerDropped handlers may run first).
function DutyTracking.HandlePlayerDropped(source)
    for identifier, shift in pairs(ActiveShifts) do
        if shift.source == source then
            DutyTracking.FinalizeShift(identifier, os.time())
            return
        end
    end
end

AddEventHandler('playerDropped', function(_reason)
    local source = source
    DutyTracking.HandlePlayerDropped(source)
end)

-- bridge/server.lua's toggleDuty handler flips the framework's own job.onduty
-- flag and broadcasts the RESULT here. We react to that actual new state
-- rather than independently toggling our own ActiveShifts flag - if we
-- toggled independently, our state and the framework's flag could start one
-- step out of sync (e.g. a player already on duty before this tracking
-- system ever saw them) and would then stay inverted on every subsequent
-- toggle forever after. Reacting to the real state self-heals that instead.
AddEventHandler('sterix_police:bridge:server:dutyChanged', function(source, onDuty)
    local identifier = Bridge.GetPlayerIdentifier(source)
    if not identifier then return end

    WaitForTables()

    if onDuty == nil then
        -- framework has no native duty concept (e.g. ESX - see
        -- bridge/esx/server.lua) - our own tracking state is the only
        -- source of truth that exists, so just flip whatever we have
        onDuty = not (ActiveShifts[identifier] ~= nil)
    end

    if onDuty then
        DutyTracking.GoOnDuty(source)
    else
        DutyTracking.FinalizeShift(identifier)
    end
end)

-- ---------------------------------------------------------------------------
-- Midnight rollover while still on duty
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local now = os.time()
        local nextMidnight = GetDayStart(now) + 86400
        Wait((nextMidnight - now + 1) * 1000)

        local today = GetDayStart(os.time())

        for identifier, shift in pairs(ActiveShifts) do
            if shift.flushedUntil < today then
                local from = shift.flushedUntil
                shift.flushedUntil = today -- advance the watermark before awaiting (see file header)

                DutyTracking.ProcessShift(identifier, from, today)
                DutyTracking.UpdateActiveDutyFlush(identifier, today)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Server restart recovery
--
-- Active shifts persist in player_active_duty (shift_start, last_flushed).
-- On resource start we read every row and, for each:
--   - if that identifier is currently connected (this was a resource-only
--     restart, e.g. `restart sterix_police`), we resume live tracking and
--     immediately catch up any time that elapsed while the resource was
--     down via the same ProcessShift used everywhere else - no special
--     restart-only math, so it can't drift out of sync with normal operation.
--   - if nobody matching is connected (the server itself restarted/crashed
--     while they were on duty), we cannot know their exact disconnect time.
--     Best-effort: finalize the shift as of right now (the earliest moment we
--     can act) and close it out, rather than either losing the time entirely
--     or leaving a stale row that could double-count later. This is
--     necessarily an approximation - there is no way to recover the true
--     disconnect time after a hard crash.
-- We never blindly delete player_active_duty rows on startup without first
-- processing them into player_duty_days.
-- ---------------------------------------------------------------------------

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    CreateThread(function()
        DutyTracking.EnsureTables() -- must finish before anything below queries these tables

        local rows = DutyTracking.LoadAllActiveDuty()
        if #rows == 0 then return end

        local now = os.time()
        local onlineByIdentifier = {}

        for _, src in ipairs(GetPlayers()) do
            local source = tonumber(src)
            local identifier = Bridge.GetPlayerIdentifier(source)
            if identifier then
                onlineByIdentifier[identifier] = source
            end
        end

        for _, row in ipairs(rows) do
            local matchedSource = onlineByIdentifier[row.identifier]

            if matchedSource then
                -- set the FINAL watermark up front (see file header) so a
                -- concurrent off-duty request during the catch-up below still
                -- resolves to a correct, non-overlapping range
                ActiveShifts[row.identifier] = { source = matchedSource, startTime = row.shift_start, flushedUntil = now }

                DutyTracking.ProcessShift(row.identifier, row.last_flushed, now)
                DutyTracking.UpdateActiveDutyFlush(row.identifier, now)
            else
                DutyTracking.ProcessShift(row.identifier, row.last_flushed, now)
                DutyTracking.RemoveActiveDuty(row.identifier)

                print(('[sterix_police] duty: recovered stale active shift for %s on resource start (player offline, closed as of restart time)'):format(row.identifier))
            end
        end
    end)
end)
