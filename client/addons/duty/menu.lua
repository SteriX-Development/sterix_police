--[[
    client/addons/duty/menu.lua

    ox_lib context menus for the duty time-tracking system. This file only
    displays what the server hands back - all permission checks and
    calculations already happened server-side (server/duty/boss.lua,
    server/duty/tracking.lua). Nothing here decides who can see what.

    /dutystats - opens the menu
    /duty      - dev/testing duty toggle, replace with your actual
                 job-item/duty-computer flow once you have one (the physical
                 marker/target in client/addons/duty/duty.lua already covers that)
]]

local OpenMyStats, OpenJobOverview, OpenEmployeeDetail, OpenJobStatistics, OpenDutyMenu

OpenMyStats = function()
    local stats = lib.callback.await('sterix_police:duty:getMyStats', false)
    if not stats then return end

    local options = {
        {
            title = 'Current Status',
            description = stats.onDuty and 'ON DUTY' or 'OFF DUTY',
            icon = stats.onDuty and 'circle-check' or 'circle-xmark',
            iconColor = stats.onDuty and '#2ecc71' or '#e74c3c',
            disabled = true,
        },
        {
            title = 'Current Shift',
            description = stats.onDuty and FormatDutyTime(stats.currentShift) or 'No Active Shift',
            icon = 'stopwatch',
            disabled = true,
        },
        {
            title = "Today's Total",
            description = FormatDutyTime(stats.today),
            icon = 'calendar-day',
            disabled = true,
        },
    }

    for _, day in ipairs(stats.history or {}) do
        if day.date ~= stats.todayDate then
            options[#options + 1] = {
                title = day.date,
                description = FormatDutyTime(day.seconds),
                icon = 'calendar',
                disabled = true,
            }
        end
    end

    lib.registerContext({
        id = 'sterix_police_duty_mystats',
        title = 'My Duty Statistics',
        menu = 'sterix_police_duty_main',
        options = options,
    })
    lib.showContext('sterix_police_duty_mystats')
end

OpenEmployeeDetail = function(employee)
    local history = lib.callback.await('sterix_police:duty:getEmployeeHistory', false, employee.identifier)

    local options = {
        {
            title = 'Status',
            description = employee.onDuty and 'ON DUTY' or 'OFF DUTY',
            disabled = true,
        },
    }

    if employee.onDuty then
        options[#options + 1] = {
            title = 'Current Shift',
            description = FormatDutyTime(employee.currentShift),
            disabled = true,
        }
    end

    for _, day in ipairs(history or {}) do
        options[#options + 1] = {
            title = day.date,
            description = FormatDutyTime(day.seconds),
            disabled = true,
        }
    end

    lib.registerContext({
        id = 'sterix_police_duty_employee',
        title = 'Employee: ' .. employee.name,
        menu = 'sterix_police_duty_overview',
        options = options,
    })
    lib.showContext('sterix_police_duty_employee')
end

OpenJobOverview = function()
    local employees = lib.callback.await('sterix_police:duty:getJobOverview', false)
    if not employees then
        Bridge.Notify('You are not authorized to view this.', 'error')
        return
    end

    local onDutyOptions, offDutyOptions = {}, {}

    for _, employee in ipairs(employees) do
        local option = {
            title = employee.name,
            description = employee.onDuty
                and ('Current Shift: %s\nToday: %s'):format(FormatDutyTime(employee.currentShift), FormatDutyTime(employee.today))
                or ('Today: %s'):format(FormatDutyTime(employee.today)),
            icon = employee.online and 'user' or 'user-slash',
            arrow = true,
            onSelect = function()
                OpenEmployeeDetail(employee)
            end,
        }

        if employee.onDuty then
            onDutyOptions[#onDutyOptions + 1] = option
        else
            offDutyOptions[#offDutyOptions + 1] = option
        end
    end

    local options = {}

    if #onDutyOptions > 0 then
        options[#options + 1] = { title = '— ON DUTY —', disabled = true }
        for _, option in ipairs(onDutyOptions) do options[#options + 1] = option end
    end

    if #offDutyOptions > 0 then
        options[#options + 1] = { title = '— OFF DUTY —', disabled = true }
        for _, option in ipairs(offDutyOptions) do options[#options + 1] = option end
    end

    options[#options + 1] = {
        title = 'Refresh',
        icon = 'rotate',
        onSelect = OpenJobOverview,
    }

    lib.registerContext({
        id = 'sterix_police_duty_overview',
        title = 'Job Duty Overview',
        menu = 'sterix_police_duty_main',
        options = options,
    })
    lib.showContext('sterix_police_duty_overview')
end

OpenJobStatistics = function()
    local stats = lib.callback.await('sterix_police:duty:getJobStatistics', false)
    if not stats then
        Bridge.Notify('You are not authorized to view this.', 'error')
        return
    end

    lib.registerContext({
        id = 'sterix_police_duty_jobstats',
        title = 'Job Statistics',
        menu = 'sterix_police_duty_main',
        options = {
            { title = 'Employees', description = tostring(stats.employeeCount), disabled = true },
            { title = 'Currently On Duty', description = tostring(stats.onDuty), disabled = true },
            { title = 'Currently Off Duty', description = tostring(stats.offDuty), disabled = true },
            { title = "Today's Total Job Hours", description = FormatDutyTime(stats.todayTotalSeconds), disabled = true },
            { title = 'Refresh', icon = 'rotate', onSelect = OpenJobStatistics },
        },
    })
    lib.showContext('sterix_police_duty_jobstats')
end

OpenDutyMenu = function()
    local context = lib.callback.await('sterix_police:duty:getContext', false)

    local options = {
        {
            title = 'My Duty Statistics',
            icon = 'user-clock',
            arrow = true,
            onSelect = OpenMyStats,
        },
    }

    if context and context.isBoss then
        options[#options + 1] = { title = 'Job Duty Overview', icon = 'users', arrow = true, onSelect = OpenJobOverview }
        options[#options + 1] = { title = 'Job Statistics', icon = 'chart-simple', arrow = true, onSelect = OpenJobStatistics }
    end

    lib.registerContext({
        id = 'sterix_police_duty_main',
        title = 'Duty Statistics',
        options = options,
    })
    lib.showContext('sterix_police_duty_main')
end

RegisterNetEvent('sterix_police:duty:client:openMenu', OpenDutyMenu)

-- dev/testing command only - the physical marker/target in
-- client/addons/duty/duty.lua is the real interaction, this is just for
-- quickly toggling duty during development without walking to it every time
RegisterCommand('duty', function()
    Bridge.ToggleDuty()
end, false)
