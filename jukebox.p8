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

 loaded_file = nil

 sfx_allocation = {
  type = "sfx",
  max_index = 63,
  addr = function(i) return 0x3200 + i * 68 end
  -- permanently reserve sfx here
 }
 music_allocation = {
  type = "music",
  max_index = 63,
  addr = function(i) return 0x3100 + i * 4 end,
  row_width = 1,
  lru_list = {},
  source_list = {}
 }
 music_allocation.asset_alloc = sfx_allocation
 sfx_allocation.wrapper_alloc = music_allocation

 sprite_allocation = {
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
  row_width = 128,
  lru_list = {},
  source_list = {}
 }
 map_allocation.asset_alloc = sprite_allocation
 sprite_allocation.wrapper_alloc = map_allocation
 function allocate(tbl, key, length)
  local alloc = nil

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

  assert(free(tbl, nil), tbl.type .. " out of space: " .. length)
  return allocate(tbl, key, length)
 end

 function free(wrapper_table, key)
  wrapper_table = wrapper_table.wrapper_alloc or wrapper_table
  local asset_table = wrapper_table.asset_alloc

  local freed = false

  key = del(wrapper_table.lru_list, key or wrapper_table.lru_list[1])
  if (not key) return freed
  wrapper_table.source_list[key].allocation = nil

  for tbl in all({ wrapper_table, asset_table }) do
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

  local length
  if info.w then
   length = info.w * info.h
  end
  -- find space to allocate
  info.allocation = allocate(wrapper_table, key, length)

  -- load the file if it isn't already
  if loaded_file ~= info.file then
   loaded_file = info.file
   reload(0x8000, 0, 0x4300, loaded_file)
  end

  local asset_table = wrapper_table.asset_alloc
  local assigned = {}

  -- for row = 0, info.length - 1 do
  --  for column = 0, (info.height or 4) - 1 do
  --   local byte = peek(0x8000 + wrapper_table.addr(info.start + row * wrapper_table.row_width) + column)
  --   if wrapper_table.type == "music" then
  --    -- not muted
  --    if byte & 0x40 == 0 then
  --     local src_sfx = byte & 0x3f
  --     local dst_sfx = assigned[src_sfx]
  --     if not dst_sfx then
  --      dst_sfx = allocate(asset_table, key, 1)
  --      memcpy(asset_table.addr(dst_sfx), 0x8000 + asset_table.addr(src_sfx), 68)
  --      assigned[src_sfx] = dst_sfx
  --     end
  --     byte = byte & 0xc0 | dst_sfx
  --    end
  --   end
  --   poke(wrapper_table.addr(info.allocation + row) + column, byte)
  --  end
  -- end

  for celx = 0, info.w - 1 do
   for cely = 0, info.h - 1 do
    local byte = peek(0x8000 + wrapper_table.addr(info.x + celx, info.y + cely))
    if byte ~= 0 then
     local dst = assigned[byte]
     if not dst then
      dst = allocate(asset_table, key, 1)
      assigned[byte] = dst
      for i = 0, 7 do
       memcpy(asset_table.addr(dst) + i * 64, 0x8000 + asset_table.addr(byte) + i * 64, 4)
      end
     end
     byte = dst
    end
    poke(0x2000 + info.allocation + cely * info.w + celx, byte)
   end
  end

  add(wrapper_table.lru_list, key)
  return info
 end

 -- load music from a file
 function load_music(key) return load_asset(music_allocation, key) end
 function load_map(key) return load_asset(map_allocation, key) end
 -- return the key of the currently playing music or nil
 function current_music() return music_allocation[stat(54)] end

 -- load music and play it
 function play_music(key, force)
  if (not force and key == current_music()) return
  if (not key) return music(-1)
  music(load_music(key).allocation)
 end

 -- load map and draw it
 function draw_map(key, x, y, scale, flip_x, flip_y)
  local function flip(val, top, bool)
   return (bool and top - 1 - val or val) * 8 * (scale or 1)
  end

  local info = load_map(key)
  for celx = 0, info.w - 1 do
   for cely = 0, info.h - 1 do
    spr_scaled(
     peek(0x2000 + info.allocation + cely * info.w + celx),
     x + flip(celx, info.w, flip_x),
     y + flip(cely, info.h, flip_y),
     scale, 1, 1, flip_x, flip_y
    )
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
