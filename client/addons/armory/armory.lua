local function InitializeArmory()
    -- Initialize the armory system here
    print("Armory system initialized.")

    for k, v in pairs(Config.locations) do
        if not v.enable then goto continue end
        if v.armory and v.armory.enable then
            print("Armory enabled at location: " .. k)
            -- Additional initialization logic for the armory can go here
        end
        ::continue::
    end
end

InitializeArmory()

RegisterNetEvent('sterix_police:bridge:client:resourceStop', function()
    InitializeArmory()
end)