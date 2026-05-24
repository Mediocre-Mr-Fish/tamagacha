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

-- MARK: info setup
-- setup data to expore

function setup()
    asset_loader.music_allocation.source_list = {
        piao_piao = { file = "music/1.p8", y = 0, h = 3 },
        china = { file = "music/1.p8", y = 3, h = 1 },
        baka_mitai = { file = "music/1.p8", y = 4, h = 5 },
        binks_sake = { file = "music/main.p8", y = 0, h = 15 }
    }

    asset_loader.map_allocation.source_list = {
        house = { file = "unused/background.p8", x = 0, y = 0, w = 16, h = 16 }
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

function sounds_used(tbl)
    local ret = 0
    for i = 0, 63 do
        if (tbl[i]) then ret = ret + 1 end
    end
    return (ret < 10 and " " .. ret or ret) .. "/64"
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
    if (sound_mode and btnp(5)) then asset_loader.play_music(tracks[select + 1]) end
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

    print("music loader demo", 30, 0, 6)
    print("music: " .. sounds_used(asset_loader.music_allocation), 0, 18)
    print("sfx:   " .. sounds_used(asset_loader.sfx_allocation))
    for i, t in ipairs(tracks) do
        print((sound_mode and i == select + 1 and "> " or "  ") .. t,
            asset_loader.current_music() == t and 10 or 6
        )
    end

    print("maps", 64, 18, 6)
    for i, m in ipairs(maps) do
        print((not sound_mode and i == select + 1 and "> " or "  ") .. m)
    end
    print("❎ play 🅾️ stop", 0, 112)
end
