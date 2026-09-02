--[[
    server/addons/duty/boss.lua

    Boss/supervisor permission checks and job-wide views, plus the
    lib.callback endpoints the client menu (client/addons/duty/menu.lua) calls.

    Every function here re-derives identifier/job/permissions from `source`
    on the server - none of it is ever taken from the client. A boss can only
    ever see employees whose CURRENT server-side job matches their OWN
    current server-side job; the client is never trusted to do this
    filtering.
]]

---@param source number
--- Boss status comes straight from the framework's own job.isboss flag
--- (qb-core/qbx_core set this per grade in their job config). ESX has no
--- such flag - see bridge/esx/server.lua - so ESX bosses always read false
--- here; add your own check (e.g. against job.grade) if you need ESX boss
--- support.
function DutyTracking.IsJobBoss(source)
    local job = Bridge.GetJob(source)
    return job ~= nil and job.isboss == true
end

---@param source number caller - must be a boss, checked server-side
---@return { identifier: string, name: string, online: boolean, onDuty: boolean, currentShift: number, today: number }[]|nil, string|nil error
function DutyTracking.GetJobEmployees(source)
    if not DutyTracking.IsJobBoss(source) then return nil, 'not_boss' end

    local bossJob = Bridge.GetJob(source)
    if not bossJob then return nil, 'no_job' end

    local jobName = bossJob.name
    local seen = {}
    local employees = {}

    -- online employees - the live, authoritative source list, never the client
    for _, src in ipairs(GetPlayers()) do
        local employeeSource = tonumber(src)
        local job = Bridge.GetJob(employeeSource)

        if job and job.name == jobName then
            local identifier = Bridge.GetPlayerIdentifier(employeeSource)

            if identifier and not seen[identifier] then
                seen[identifier] = true
                employees[#employees + 1] = {
                    identifier = identifier,
                    name = Bridge.GetPlayerName(employeeSource),
                    online = true,
                    onDuty = DutyTracking.IsOnDuty(identifier),
                    currentShift = DutyTracking.GetCurrentShiftDuration(identifier),
                    today = DutyTracking.GetTodayTotal(identifier),
                }
            end
        end
    end

    -- offline employees - best effort, see Bridge.GetOfflineEmployees per framework
    if Bridge.GetOfflineEmployees then
        for _, employee in ipairs(Bridge.GetOfflineEmployees(jobName) or {}) do
            if not seen[employee.identifier] then
                seen[employee.identifier] = true
                employees[#employees + 1] = {
                    identifier = employee.identifier,
                    name = employee.name,
                    online = false,
                    onDuty = false, -- an offline employee cannot have a live shift
                    currentShift = 0,
                    today = DutyTracking.GetTodayTotal(employee.identifier),
                }
            end
        end
    end

    return employees
end

---@param source number caller - must be a boss
---@param targetIdentifier string
---@return { date: string, seconds: number }[]|nil, string|nil error
function DutyTracking.GetEmployeeDutyHistory(source, targetIdentifier)
    if not DutyTracking.IsJobBoss(source) then return nil, 'not_boss' end
    if type(targetIdentifier) ~= 'string' then return nil, 'invalid_target' end

    -- re-verify the target actually belongs to the boss's own job right now,
    -- rather than trusting that the client only ever asks about legitimate
    -- entries from the overview it was given
    local employees = DutyTracking.GetJobEmployees(source)
    local belongs = false

    for _, employee in ipairs(employees or {}) do
        if employee.identifier == targetIdentifier then
            belongs = true
            break
        end
    end

    if not belongs then return nil, 'not_same_job' end

    return DutyTracking.GetDailyDutyTotals(targetIdentifier, Config.Duty.HistoryDays)
end

---@param source number caller - must be a boss
---@return { employeeCount: number, onDuty: number, offDuty: number, todayTotalSeconds: number }|nil, string|nil error
function DutyTracking.GetJobDutyStatistics(source)
    if not DutyTracking.IsJobBoss(source) then return nil, 'not_boss' end

    local employees = DutyTracking.GetJobEmployees(source)
    if not employees then return nil, 'no_job' end

    local onDuty, offDuty, todayTotal = 0, 0, 0

    for _, employee in ipairs(employees) do
        if employee.onDuty then
            onDuty = onDuty + 1
        else
            offDuty = offDuty + 1
        end

        todayTotal = todayTotal + employee.today
    end

    return {
        employeeCount = #employees,
        onDuty = onDuty,
        offDuty = offDuty,
        todayTotalSeconds = todayTotal,
    }
end

---@param source number
---@return { onDuty: boolean, currentShift: number, today: number, todayDate: string, history: { date: string, seconds: number }[] }|nil
function DutyTracking.GetMyStats(source)
    local identifier = Bridge.GetPlayerIdentifier(source)
    if not identifier then return nil end

    return {
        onDuty = DutyTracking.IsOnDuty(identifier),
        currentShift = DutyTracking.GetCurrentShiftDuration(identifier),
        today = DutyTracking.GetTodayTotal(identifier),
        todayDate = os.date('%Y-%m-%d'), -- `os` is server-only in FiveM; the client can't compute this itself
        history = DutyTracking.GetDailyDutyTotals(identifier, Config.Duty.HistoryDays),
    }
end

-- ---------------------------------------------------------------------------
-- Client-facing callbacks (ox_lib) - see client/duty/menu.lua
-- ---------------------------------------------------------------------------

lib.callback.register('sterix_police:duty:getContext', function(source)
    -- UI hint only (whether to show boss options at all) - every actual data
    -- fetch below re-checks IsJobBoss(source) independently regardless of
    -- what this returns
    return { isBoss = DutyTracking.IsJobBoss(source) }
end)

lib.callback.register('sterix_police:duty:getMyStats', function(source)
    return DutyTracking.GetMyStats(source)
end)

lib.callback.register('sterix_police:duty:getJobOverview', function(source)
    return DutyTracking.GetJobEmployees(source)
end)

lib.callback.register('sterix_police:duty:getEmployeeHistory', function(source, targetIdentifier)
    return DutyTracking.GetEmployeeDutyHistory(source, targetIdentifier)
end)

lib.callback.register('sterix_police:duty:getJobStatistics', function(source)
    return DutyTracking.GetJobDutyStatistics(source)
end)
