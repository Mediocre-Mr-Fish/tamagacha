-- Non-module code for the Asset loader.
-- This allows the asset loader cartrige editor
-- to show an accurate token count.

---@diagnostic disable

-- MARK: helper functions
-- these functions should exist in the main cart already
function rescope(scope, env)
    return setmetatable(
        {}, {
            __index = function(_, k) return scope[k] or env[k] end,
            __newindex = scope
        }
    ), scope
end

function grid_coords(x1, y1, dx, dy, val, cols)
    return x1 + dx * ((val - 1) % cols), y1 + dy * flr((val - 1) / cols)
end

function grid_wrap(val, dx, dy, width, height)
    row = flr((val - 1) / width + dy) % height
    col = ((val - 1) % width + dx) % width
    return row * width + col + 1
end

function spr_scaled(n, x, y, scale, sw, sh, fh, fv)
    scale = scale or 1
    sw, sh = (sw or 1) * 8, (sh or 1) * 8
    sspr(n % 16 * 8, flr(n / 16) * 8, sw, sh, x, y, sw * scale, sh * scale, fh, fv)
end

function print_centered(text, x, y, col)
    if (col) then color(col) end
    print(text, x - print(text, 0, -8) / 2, y)
end

-- MARK: info setup
-- setup data to expore

function setup()
    asset_loader.music_allocation.source_list = {
        piao_piao = { file = "music/1.p8", y = 0, h = 3 },
        china = { file = "music/1.p8", y = 3, h = 1 },
        baka_mitai = { file = "music/1.p8", y = 4, h = 6 },
        binks_sake = { file = "music/main.p8", y = 0, h = 15 },
        jumping_machine = { file = "music/main2.p8", y = 0, h = 8 }
    }

    asset_loader.map_allocation.source_list = {
        house = { file = "maps/home.p8", x = 0, y = 0, w = 24, h = 16 },
        shelf = { file = "maps/home.p8", x = 24, y = 0, w = 3, h = 1 },
        tower_segment = { file = "maps/tower.p8", x = 0, y = 0, w = 9, h = 5 },
        tower_ground = { file = "maps/tower.p8", x = 2, y = 5, w = 16, h = 10 }
    }

    for _, value in ipairs({ 0, 1, 16, 17 }) do
        asset_loader.spr_allocation[value] = true
    end
    for _, value in ipairs({ 0 }) do
        asset_loader.sfx_allocation[value] = true
    end
end

-- MARK: operator functions
-- functions to explore the gallery



function pad(str, len)
    str = tostring(str)
    while #str < (len or 2) do
        str = " " .. str
    end
    return str
end

function capacity(alloc_tbl)
    local ret = 0
    for i = 0, alloc_tbl.max_index do
        if (alloc_tbl[i]) then ret = ret + 1 end
    end
    if alloc_tbl.type == "music" then
        ret = ret / 4
    end

    return pad(ret, #tostring(alloc_tbl.max_index + 1)) .. "/" .. tostring(alloc_tbl.max_index + 1)
end

function is_loaded(alloc_tbl, key)
    for entry in all(alloc_tbl.lru_list) do
        if (entry == key) then return true end
    end
    return false
end

function _init()
    setup()

    sound_mode = true
    show_map = nil
    select = 0
    tracks = {}
    maps = {}

    for key, _ in pairs(asset_loader.music_allocation.source_list) do
        local i = 1
        while i <= #tracks and tracks[i] < key do
            i = i + 1
        end
        add(tracks, key, i)
    end
    for key, _ in pairs(asset_loader.map_allocation.source_list) do
        local i = 1
        while i <= #maps and maps[i] < key do
            i = i + 1
        end
        add(maps, key, i)
    end
end

function _update()
    if (btnp() ~= 0) then show_map = false end
    if (btnp(0) ~= btnp(1)) then
        sound_mode = not sound_mode
        sfx(0)
    end
    if (btnp(2)) then
        select = select - 1
        sfx(0)
    end
    if (btnp(3)) then
        select = select + 1
        sfx(0)
    end
    select = select % (sound_mode and #tracks or #maps)
    if (sound_mode and btnp(5)) then asset_loader.play_music(tracks[select + 1], true) end
    if (sound_mode and btnp(4)) then asset_loader.play_music(nil) end
    if (not sound_mode and btnp(5)) then show_map = maps[select + 1] end
end

function _draw()
    cls()
    if show_map then
        asset_loader.draw_map(show_map, 0, 0)
        return
    end

    palt(11, true)
    sspr(0, 0, 16, 16, 96, 96, 32, 32)

    print_centered("gallery", 64, 0, 6)

    print("music:" .. capacity(asset_loader.music_allocation), 0, 18)
    print("sfx:  " .. capacity(asset_loader.sfx_allocation))
    for i, t in ipairs(tracks) do
        local color = 6
        if asset_loader.current_music() == t then
            color = 10
        elseif is_loaded(asset_loader.music_allocation, t) then
            color = 14
        end
        print((sound_mode and i == select + 1 and "> " or "  ") .. t, color)
    end

    print("map:  " .. capacity(asset_loader.map_allocation), 64, 18, 6)
    print("sprite:" .. capacity(asset_loader.spr_allocation))
    for i, m in ipairs(maps) do
        local color = 6
        if false then
            color = 10
        elseif is_loaded(asset_loader.map_allocation, m) then
            color = 14
        end
        print((not sound_mode and i == select + 1 and "> " or "  ") .. m, color)
    end


    print("❎ "
        .. (sound_mode and "play" or "show")
        .. (asset_loader.current_music() and " 🅾️ stop" or ""),
        0, 112, 6)
end
