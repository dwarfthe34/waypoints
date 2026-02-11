-- Waypoints CSM for Luanti
-- Persistent, per-server, death markers, hex colors
-- HUD shows:
--   Line 1 = waypoint name
--   Line 2 = "pos:" then the distance from teh waypoint
--   Line 3 = server label
-- Distance removed

local storage   = core.get_mod_storage()
local waypoints = {}
local hud_ids   = {}

-- Server identity

local function get_server_label()
    local info = core.get_server_info()
    if not info then
        return "singleplayer"
    end

    if info.name and info.name ~= "" then
        return info.name
    end

    if info.address then
        return info.address .. ":" .. (info.port or "?")
    end

    return "unknown"
end

local SERVER_LABEL = get_server_label()
local SERVER_KEY   = "waypoints::" .. SERVER_LABEL

-- Helpers

local function parse_hex(hex)
    if not hex then return 0x00FF00 end
    if #hex ~= 6 or not hex:match("^[%x]+$") then
        return 0x00FF00
    end
    return tonumber(hex, 16)
end

local function save()
    storage:set_string(SERVER_KEY, core.serialize(waypoints))
end

local function load()
    local raw = storage:get_string(SERVER_KEY)
    if raw ~= "" then
        waypoints = core.deserialize(raw) or {}
    end
end

-- HUD helpers

local function add_hud(name, data)
    if not core.localplayer then return end

    if hud_ids[name] then
        core.localplayer:hud_remove(hud_ids[name])
    end

    -- Line 1 = name, Line 2 = "pos:", Line 3 = server label
    local display_text = name .. "\npos:\n" .. SERVER_LABEL

    hud_ids[name] = core.localplayer:hud_add({
        hud_elem_type = "waypoint",
        name          = display_text,  -- first line = name, second = "pos:", third = server
        world_pos     = data.pos,
        number        = data.color
    })
end

local function refresh_all()
    for name, data in pairs(waypoints) do
        add_hud(name, data)
    end
end

-- Load stored waypoints
load()
core.after(0, refresh_all)

-- Chat commands

core.register_chatcommand("wp_add", {
    params = "<name> [hexcolor]",
    description = "Add waypoint (optional hex color)",
    func = function(param)
        local name, hex = param:match("^(%S+)%s*(%S*)$")
        if not name then
            return false, "Usage: /wp_add <name> [hexcolor]"
        end

        local pos   = vector.round(core.localplayer:get_pos())
        local color = parse_hex(hex)

        waypoints[name] = {
            pos   = pos,
            color = color
        }

        save()
        add_hud(name, waypoints[name])

        return true, SERVER_LABEL .. ": waypoint '" .. name .. "' added"
    end
})

core.register_chatcommand("wp_del", {
    params = "<name>",
    description = "Delete waypoint",
    func = function(name)
        if not waypoints[name] then
            return false, "No such waypoint"
        end

        if hud_ids[name] then
            core.localplayer:hud_remove(hud_ids[name])
            hud_ids[name] = nil
        end

        waypoints[name] = nil
        save()

        return true, "Waypoint deleted"
    end
})

core.register_chatcommand("wp_list", {
    description = "List waypoints",
    func = function()
        local list = {}
        for k in pairs(waypoints) do
            table.insert(list, k)
        end
        return true, "Waypoints (" .. SERVER_LABEL .. "): " .. table.concat(list, ", ")
    end
})
core.register_chatcommand("wp_edit", {
    params = "<name> <hexcolor>",
    description = "Edit a waypoint's color",
    func = function(param)
        local name, hex = param:match("^(%S+)%s+(%S+)$")
        if not name or not hex then
            return false, "Usage: /wp_edit <name> <hexcolor>"
        end

        local wp = waypoints[name]
        if not wp then
            return false, "Waypoints: (" .. name .. ") does not exist, please create it"
        end

        local color = parse_hex(hex)
        wp.color = color

        save()
        add_hud(name, wp)

        return true, "Waypoint '" .. name .. "' color updated to #" .. hex
    end
})

-- Automatic death waypoint at exact death location
core.register_on_hp_modification(function(hp)
    if not core.localplayer then return end
    if hp > 0 then return end  -- only trigger when HP drops to 0

    local pos = vector.round(core.localplayer:get_pos())
    waypoints["death"] = { pos = pos, color = 0xFF0000 }

    save()
    add_hud("death", waypoints["death"])
    core.display_chat_message("(c@#FF0f50)Death waypoint set at your death location")
    core.display_chat_message("(c@#FF0f60)Use '.wp_del death' to remove it")
end)

