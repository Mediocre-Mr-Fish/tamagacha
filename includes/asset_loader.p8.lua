-- requires:
--  helper_functions

asset_loader = {}
root = root or ""
do
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
  asset_alloc = sfx_allocation,
  lru_list = {},
  source_list = {
   piao_piao = { file = "assets/tower.p8", y = 0, h = 3 },
   china = { file = "assets/tower.p8", y = 3, h = 1 },
   baka_mitai = { file = "assets/tower.p8", y = 4, h = 6 },
   binks_sake = { file = "minigames/fishing.p8", y = 0, h = 15 },
   jumping_machine = { file = "assets/home.p8", y = 0, h = 8 }
  }
 }
 sfx_allocation.wrapper_alloc = music_allocation

 spr_allocation = {
  type = "sprite",
  max_index = 0xff,
  addr = function(i)
   local sx, sy = grid_coords(0, 0, 4, 8, i + 1, 16)
   return sy * 64 + sx
  end,
  -- permanently reserve sprites here
  [0] = true
 }
 map_allocation = {
  type = "map",
  max_index = 0xfff,
  addr = function(x, y) return 0x2000 + y * 128 + x end,
  asset_alloc = spr_allocation,
  lru_list = {},
  source_list = {
   house = { file = "assets/home.p8", x = 0, y = 0, w = 24, h = 16 },
   shelf = { file = "assets/home.p8", x = 24, y = 0, w = 3, h = 1 },
   tower_segment = { file = "assets/tower.p8", x = 0, y = 0, w = 9, h = 5 },
   tower_ground = { file = "assets/tower.p8", x = 2, y = 5, w = 16, h = 10 }
  }
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
  if (current_music() == key) music(-1)
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

 function load_file(file)
  file = root .. file
  loaded_file = (loaded_file == file or reload(0x8000, 0, 0x4300, file) > 0) and file
  return loaded_file
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
  local mem_rows, mem_cols, mask, byte_is_empty = 7, 4, 0x00, function(byte) return byte == 0 end
  if wrapper_table.type == "music" then
   info.x = 0
   info.w = 4
   mem_rows, mem_cols, mask, byte_is_empty = 0, 68, 0xc0, function(byte) return byte & 0x40 ~= 0 end
  end

  local function copy(byte)
   -- check muted
   if (byte_is_empty(byte)) return byte
   -- check is duplicate
   local src = byte & (0xff - mask)
   local dst = assigned[src]
   if (dst) return byte & mask | dst
   -- allocate data
   dst = allocate(asset_table, key, 1)
   assigned[src] = dst
   for i = 0, mem_rows do
    memcpy(asset_table.addr(dst) + i * 64, 0x8000 + asset_table.addr(src) + i * 64, mem_cols)
   end
   return byte & mask | dst
  end

  -- find space to allocate
  info.allocation = allocate(wrapper_table, key, info.w * info.h)

  -- load the file if it isn't already
  assert(load_file(info.file), "missing file: " .. info.file)

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
    if spr ~= 0 then
     spr_scaled(
      spr, x + flip(celx, info.w, flip_x), y + flip(cely, info.h, flip_y), scale, 1, 1, flip_x,
      flip_y
     )
    end
   end
  end
 end
end