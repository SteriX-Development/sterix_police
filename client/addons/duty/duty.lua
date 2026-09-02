
local function JobInGroup(groups, jobName)
    if not groups or not jobName then return false end
    for i = 1, #groups do
        if groups[i] == jobName then return true end
    end
    return false
end

local function IsJobAllowed(groups)
    if not groups or #groups == 0 then return true end
    local job = Bridge.GetJob()
    if not job then return false end
    for i = 1, #groups do
        if groups[i] == job.name then
            return true
        end
    end
    return false
end

local function InitializeDuty()
    for k, v in pairs(Config.locations) do
        if not v.enable then goto continue end
        if v.duty and v.duty.enable then

            if v.duty.duty_counter and v.duty.duty_counter.enable then
                if v.duty.duty_counter.target and v.duty.duty_counter.target.enable then
                    if Config.Target == 'ox_target' then
                        exports.ox_target:addBoxZone({
                            name = "sterix_police:duty_counter_" .. k,
                            coords = v.duty.duty_counter.target.coords,
                            size = v.duty.duty_counter.target.size,
                            rotation = v.duty.duty_counter.target.heading,
                            debug = true,
                            distance = v.duty.duty_counter.target.distance or 1.5,
                            options = {
                                {
                                    label = 'Check In/Out Duties',
                                    icon = 'fas fa-briefcase',
                                    groups = v.group,
                                    onSelect = function()
                                        TriggerEvent('sterix_police:duty:client:openMenu')
                                    end,
                                },
                            },
                        })
                    end
                else
                    CreateThread(function()
                        local coords = v.duty.duty_counter.interact_coords
                        local groups = v.group
                        local showedText = false

                        while true do
                            local sleep = 1000
                            local playerCoords = GetEntityCoords(PlayerPedId())
                            local dist = #(playerCoords - coords)

                            if dist < v.duty.duty_counter.interact_distance then
                                sleep = 0

                                if IsJobAllowed(groups) then
                                    DrawMarker(21, coords.x, coords.y, coords.z , 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0, 150, 255, 100, false, true, 2, true, nil, nil, false)

                                    if dist < 1.0 then
                                        if not showedText then
                                            lib.showTextUI('[E] Check In/Out Duties')
                                            showedText = true
                                        end

                                        if IsControlJustPressed(0, 38) then
                                            TriggerEvent('sterix_police:duty:client:openMenu')
                                        end
                                    elseif showedText then
                                        lib.hideTextUI()
                                        showedText = false
                                    end
                                elseif showedText then
                                    lib.hideTextUI()
                                    showedText = false
                                end
                            elseif showedText then
                                lib.hideTextUI()
                                showedText = false
                            end

                            Wait(sleep)
                        end
                    end)
                end
        
                                
            end

            ---- Duty
            if v.duty.target and v.duty.target.enable then
                if Config.Target == 'ox_target' then
                    exports.ox_target:addBoxZone({
                        name = "sterix_police:duty_" .. k,
                        coords = v.duty.target.coords,
                        size = v.duty.target.size,
                        rotation = v.duty.target.heading,
                        debug = true,
                        distance = v.duty.target.distance or 1.5,
                        options = {
                            {
                                label = 'Toggle Duty',
                                icon = 'fas fa-briefcase',
                                groups = v.group,
                                onSelect = function()
                                    Bridge.ToggleDuty()
                                end,
                            },
                        },
                    })

                end
            else

                CreateThread(function()
                    local coords = v.duty.interact_coords
                    local groups = v.group
                    local showedText = false

                    while true do
                        local sleep = 1000
                        local playerCoords = GetEntityCoords(PlayerPedId())
                        local dist = #(playerCoords - coords)

                        if dist < v.duty.interact_distance then
                            sleep = 0

                            if IsJobAllowed(groups) then
                                DrawMarker(21, coords.x, coords.y, coords.z , 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0, 150, 255, 100, false, true, 2, true, nil, nil, false)

                                if dist < 1.0 then
                                    if not showedText then
                                        lib.showTextUI('[E] Toggle Duty')
                                        showedText = true
                                    end

                                    if IsControlJustPressed(0, 38) then
                                        Bridge.ToggleDuty()
                                    end
                                elseif showedText then
                                    lib.hideTextUI()
                                    showedText = false
                                end
                            elseif showedText then
                                lib.hideTextUI()
                                showedText = false
                            end
                        elseif showedText then
                            lib.hideTextUI()
                            showedText = false
                        end

                        Wait(sleep)
                    end
                end)

            end

        end
        ::continue::
    end

end
InitializeDuty()



RegisterNetEvent('sterix_police:bridge:client:playerLoaded', function()
    Wait(500)
    print("shuff")

    local job = Bridge.GetJob()
    if not job then return end

    for k, v in pairs(Config.locations) do
        if not v.enable then goto continue end
        if JobInGroup(v.group, job.name) then
            if job.onduty then
                Bridge.SetDuty(false)
            end
            break
        end
        ::continue::
    end
end)




RegisterNetEvent('sterix_police:bridge:client:resourceStop', function()
    lib.hideTextUI()

    for k, v in pairs(Config.locations) do
        if not v.enable then goto continue end
        if v.duty and v.duty.enable then
            if v.duty.target and v.duty.target.enable then
                exports.ox_target:removeZone("sterix_police:duty_" .. k)
            end
        end
        ::continue::
    end
end)
