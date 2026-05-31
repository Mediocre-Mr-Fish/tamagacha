pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-->8
-- MARK: helper functions
function rescope(...)
 local scopes = { ... }
 return setmetatable(
  {}, {
   __index = function(_, k)
    for scope in all(scopes) do
     if scope[k] ~= nil then return scope[k] end
    end
   end,
   __newindex = scopes[1]
  }
 ), unpack(scopes)
end
function grid_coords(x1, y1, dx, dy, val, cols)
 return x1 + dx * ((val - 1) % cols), y1 + dy * ((val - 1) \ cols)
end
function spr_scaled(n, x, y, scale, sw, sh, fh, fv)
 scale = scale or 1
 sw, sh = (sw or 1) * 8, (sh or 1) * 8
 sspr(n % 16 * 8, n \ 16 * 8, sw, sh, x, y, sw * scale, sh * scale, fh, fv)
end
function pad(str, len, char)
 str = tostring(str)
 char = char or " "
 while #str < (len or 2) do
  str = char .. str
 end
 return str
end

function print_table(t, space)
 space = space or ""
 for k, v in pairs(t) do
  if type(v) == "table" then
   print_table(v, space .. " ")
  else
   printh(space .. tostr(k) .. ", " .. tostr(v))
  end
 end
end

-->8
-- MARK: asset_loader
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
  end,
  -- permanently reserve sprites here
  -- spite 0 must be reserved if it isn't already
  [0] = true
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
    if (spr ~= 0) spr_scaled(spr, x + flip(celx, info.w, flip_x), y + flip(cely, info.h, flip_y), scale, 1, 1, flip_x, flip_y)
   end
  end
 end
end

-->8
-- MARK: byte_streamer
do
 byte_streamer = {}
 local _ENV = rescope(byte_streamer, _ENV)
 source = nil
 -- source can be:
 --   integer: location in memory
 --   string: an ascii string
 --   table: a list of integers
 offset = 0

 function set_source(src, pos)
  source, offset = src, pos or 0
 end

 function write(...)
  assert(source)

  local bytes = { ... }
  if type(source) == "number" then
   poke(source + offset, ...)
  elseif type(source) == "string" then
   source = sub(source, 1, offset) .. chr(...) .. sub(source, offset + #bytes + 1)
  elseif type(source) == "table" then
   for i, byte in ipairs(bytes) do
    source[offset + i] = byte
   end
  end
  offset += #bytes
 end

 function read(num)
  assert(source)
  local o = offset
  num = num or 1
  offset += num
  if type(source) == "number" then
   return peek(source + o, num)
  elseif type(source) == "string" then
   return ord(source, o + 1, num)
  elseif type(source) == "table" then
   local ret = {}
   for i = 1, num do
    add(ret, source[o + i])
   end
   return unpack(ret)
  end
 end

 function write_str(str)
  write(#str, ord(str, 1, #str))
 end
 function read_str()
  return chr(read(read()))
 end
end

-->8
-- MARK: pet mock-up
do
 pet_prefabs = { num = 0 }

 class__pet = {}
 class__pet.__index = class__pet

 function class__pet:spr(key, x, y)
  palt(0, false)
  palt(self.transparent, true)
  asset_loader.draw_map(self.file .. key, x, y)
 end

 function class__pet.create_prefab(id)
  local file = "pets/" .. pad(id, 3, "0") .. ".p8"
  if not asset_loader.load_file(file) then
   -- printh(file .. " not found")
   return
  end

  byte_streamer.set_source(0x8000)
  local read, read_str = byte_streamer.read, byte_streamer.read_str

  assert(read() == 3)

  local pet = setmetatable(
   {
    id = id,
    file = file,
    spr_maps = {}, variants = {}
   }, class__pet
  )
  pet_prefabs[id] = pet
  pet_prefabs.num += 1

  for _ = 1, read() do
   local info = { file = file }
   info.x, info.y, info.w, info.h = read(4)
   asset_loader.map_allocation.source_list[file .. read_str()] = info
  end

  pet.transparent, pet.immortal, pet.rarity, pet.meat, pet.bone = read(5)

  for _ = 1, read() do
   local variant = add(pet.variants, {})

   for i = 0, 15 do
    variant[i] = read()
   end

   variant.name = read_str()
  end

  return pet
 end
end

-->8
-- MARK: main
function _init()
 t, dt = time(), 0
 for i = 1, 15 do
  class__pet.create_prefab(i)
 end

 selection = 1
 sel_var = 1
end

function _update()
 dt, t = time() - t, time()
 if btnp(0) then selection -= 1 end
 if btnp(1) then selection += 1 end
 if btnp(2) then sel_var += 1 end
 if btnp(3) then sel_var -= 1 end
 selection = (selection - 1) % pet_prefabs.num + 1
 sel_var = (sel_var - 1) % #pet_prefabs[selection].variants + 1
end

function _draw()
 local pet = pet_prefabs[selection]
 local variant = pet.variants[sel_var]

 cls(1)

 print("pet: " .. selection .. "/" .. pet_prefabs.num, 0, 0)
 print("var: " .. sel_var .. "/" .. #pet.variants)

 pal(variant)
 print(variant.name, 64, 56)

 pet:spr("thumbnail", 32, 64)
 pet:spr("body", 64, 64)
 local x, y = 64 + sin(t), 64 + abs(cos(t))
 pet:spr("head", x, y)
 if t % 3 > 0.1 then
  pet:spr("eye", x, y)
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
