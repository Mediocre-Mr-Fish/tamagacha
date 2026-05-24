pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
--[[jukebox.p8
proof of concept for dynamic asset allocation
assets are allocated to free space in the cart as needed
when space is unavailable, the oldest loaded asset is unloaded
crucially, this means the assets can at any index on the source cart
--[[]]

#include asset_loader.lua

do
 asset_loader = {}
 local _ENV = rescope(asset_loader, _ENV)

 -- loaded_file = nil

 sfx_allocation = {
  type = "sfx",
  max_index = 63,
  addr = function(i) return 0x3200 + i * 68 end
  -- permanently reserve sounds here
 }
 music_allocation = {
  type = "music",
  max_index = 63,
  addr = function(channel, pattern) return 0x3100 + pattern * 4 + channel end,
  lru_list = {},
  source_list = {},
  asset_alloc = sfx_allocation
 }
 sfx_allocation.wrapper_alloc = music_allocation

 spr_allocation = {
  type = "sprite",
  max_index = 0xff,
  addr = function(i)
   local sx, sy = grid_coords(0, 0, 4, 8, i + 1, 16)
   return sy * 64 + sx
  end
  -- permanently reserve sprites here
 }
 map_allocation = {
  type = "map",
  max_index = 0xfff,
  addr = function(x, y) return 0x2000 + y * 128 + x end,
  lru_list = {},
  source_list = {},
  asset_alloc = spr_allocation
 }
 spr_allocation.wrapper_alloc = map_allocation

 function allocate(tbl, key, length)
  local alloc

  for i = 0, tbl.max_index do
   if tbl[i] then
    -- reset if occupied
    alloc = nil
   else
    -- set start index
    alloc = alloc or i

    -- check if requisite length
    if i - alloc + 1 == length then
     -- mark allocation
     for a = alloc, i do
      tbl[a] = key
     end

     return alloc
    end
   end
  end

  assert(free(tbl), tbl.type .. " out of space: " .. length)
  return allocate(tbl, key, length)
 end

 function free(wrapper_table, key)
  wrapper_table = wrapper_table.wrapper_alloc or wrapper_table

  local freed = false

  key = del(wrapper_table.lru_list, key or wrapper_table.lru_list[1])
  if (not key) return freed
  wrapper_table.source_list[key].allocation = nil

  for tbl in all({ wrapper_table, wrapper_table.asset_alloc }) do
   for i = 0, tbl.max_index do
    if tbl[i] == key then
     tbl[i] = nil
     freed = true
    end
   end
  end
  return freed
 end

 function load_asset(wrapper_table, key)
  -- enforce that source info exists
  local info = assert(wrapper_table.source_list[key], key)

  -- refresh least recently used list
  if del(wrapper_table.lru_list, key) then
   add(wrapper_table.lru_list, key)
   return info
  end

  local asset_table = wrapper_table.asset_alloc
  local assigned = {}
  local copy
  if wrapper_table.type == "music" then
   info.x = 0
   info.w = 4
   copy = function(byte)
    -- check muted
    if (byte & 0x40 ~= 0) return byte
    -- check is duplicate
    local src = byte & 0x3f
    local dst = assigned[src]
    if (dst) return byte & 0xc0 | dst
    -- allocate data
    dst = allocate(asset_table, key, 1)
    assigned[src] = dst
    memcpy(asset_table.addr(dst), 0x8000 + asset_table.addr(src), 68)
    return byte & 0xc0 | dst
   end
  else
   copy = function(byte)
    -- check transparent
    if (byte == 0) return byte
    -- check is duplicate
    local dst = assigned[byte]
    if (dst) return dst
    -- allocate data
    dst = allocate(asset_table, key, 1)
    assigned[byte] = dst
    for i = 0, 7 do
     memcpy(asset_table.addr(dst) + i * 64, 0x8000 + asset_table.addr(byte) + i * 64, 4)
    end
    return dst
   end
  end

  -- find space to allocate
  info.allocation = allocate(wrapper_table, key, info.w * info.h)

  -- load the file if it isn't already
  if loaded_file ~= info.file then
   loaded_file = info.file
   reload(0x8000, 0, 0x4300, loaded_file)
  end

  for celx = 0, info.w - 1 do
   for cely = 0, info.h - 1 do
    poke(
     wrapper_table.addr(0, 0) + info.allocation + cely * info.w + celx,
     copy(peek(0x8000 + wrapper_table.addr(info.x + celx, info.y + cely)))
    )
   end
  end

  add(wrapper_table.lru_list, key)
  return info
 end

 -- load music from a file
 function load_music(key) return load_asset(music_allocation, key) end
 function load_map(key) return load_asset(map_allocation, key) end
 -- return the key of the currently playing music or nil
 function current_music() return music_allocation[stat(54) * 4] end

 -- load music and play it
 function play_music(key, force)
  if (not force and key == current_music()) return
  if (not key) return music(-1)
  music(load_music(key).allocation / 4)
 end

 -- load map and draw it
 function draw_map(key, x, y, scale, flip_x, flip_y)
  local function flip(val, top, bool)
   return (bool and top - 1 - val or val) * 8 * (scale or 1)
  end

  local info = load_map(key)
  for celx = 0, info.w - 1 do
   for cely = 0, info.h - 1 do
    local spr = peek(0x2000 + info.allocation + cely * info.w + celx)
    if (spr ~= 0) spr_scaled(spr, x + flip(celx, info.w, flip_x), y + flip(cely, info.h, flip_y), scale, 1, 1, flip_x, flip_y)
   end
  end
 end
end

__gfx__
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbb55bbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb5bb5bbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb3333b5bbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb330055bbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b9993355bbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b999333bbbbbbb7b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb33333bbbbb777b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb3333444444477b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb4444444444444b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb444444999444bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb444499944444bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbb44444444bbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001207001000000000000024000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
