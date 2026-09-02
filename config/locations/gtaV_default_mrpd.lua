Config.locations[#Config.locations + 1] = {
    enable = true,
    group = {
        "police",
    },
    blip = {
        enable = true,
        name = 'MRPD',
        sprite = 60,
        color = 38,
        scale = 0.8,
    },
    stash = {
        enable = true,
        coords = vector3(452.0, -980.0, 30.6),
        target = {
            enable = true,
            coords = vector3(452.0, -980.0, 30.6),
            size = vector3(1.0, 1.0, 1.0),
            heading = 90.0,
        },
        heading = 90.0,
    },
    armory = {
        enable = true,
        coords = vector3(452.0, -980.0, 30.6),
        target = {
            enable = true,
            coords = vector3(452.0, -980.0, 30.6),
            size = vector3(1.0, 1.0, 1.0),
            heading = 90.0,
        },
        heading = 90.0,
        items = {},
    },
    duty = { --- complered
        enable = true,
        interact_coords = vector3(440.9960, -981.0564, 30.6896),
        interact_distance = 5.0,
        target = {
            enable = false,
            coords = vec3(441.03112792969, -980.09350585938, 30.927663803101),
            size = vector3(0.35, 0.5, 0.5),
            distance = 1.5,
            heading = 70.0,
        },

        duty_counter = {
            enable = true,
            interact_coords = vector3(440.1849, -977.6011, 30.6896),
            interact_distance = 5.0,
            target = {
                enable = false,
                coords = vector3(439.41860961914, -977.59722900391, 30.569789886475),
                size = vector3(1.0, 1.0, 1.0),
                distance = 1.5,
                heading = 90.0,
            },
        },
    },

}