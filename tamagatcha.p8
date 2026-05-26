pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- MARK: helper functions

function rescope(scope, env)
 return setmetatable(
  {}, {
   __index = function(_, k) return scope[k] or env[k] end,
   __newindex = scope
  }
 ), scope
end

function mod(a, b)
 return (a - 1) % b + 1
end

function btnp_axis(neg, pos)
 if (btnp(neg) ~= btnp(pos)) return btnp(pos) and 1 or -1
 return 0
end

function grid_coords(x1, y1, dx, dy, val, cols)
 return x1 + dx * ((val - 1) % cols), y1 + dy * ((val - 1) \ cols)
end

function grid_wrap(val, dx, dy, width, height)
 row = ((val - 1) \ width + dy) % height
 col = ((val - 1) % width + dx) % width
 return row * width + col + 1
end

function spr_scaled(n, x, y, scale, sw, sh, fh, fv)
 scale = scale or 1
 sw, sh = (sw or 1) * 8, (sh or 1) * 8
 sspr(n % 16 * 8, n \ 16 * 8, sw, sh, x, y, sw * scale, sh * scale, fh, fv)
end

-- toggle a value bewteen two presets
function toggle_val(val, target, fallback)
 return val == target and fallback or target
end

function accelerp(x0, v0, a, t)
 return x0 + v0 * t + a * t * t / 2
end
function lerp(a, b, t)
 return a + t * (b - a)
end
function rngf(a, b)
 return lerp(a, b, rnd())
end

function pad(str, len)
 str = tostring(str)
 while #str < (len or 2) do
  str = " " .. str
 end
 return str
end

-- encode a bool array as an integer
function encode_bitfield(bool_array)
 local ret = 0
 for i in all(bool_array) do
  ret = ret << 1
  if (i) ret += 1
 end
 return ret
end
-- decode an integer as a bool array
function decode_bitfield(integer, length)
 local ret = {}
 for _ = 1, length do
  add(ret, integer & 1 ~= 0, 1)
  integer = integer >> 1
 end
 return ret
end

function print_centered(text, x, y, col)
 if (col) color(col)
 print(text, x - print(text, 0, -8) / 2, y)
end

function draw_triangle(x1, y1, x2, y2, x3, y3, col)
 if (col) color(col)
 line(x1, y1, x2, y2)
 line(x3, y3)
 line(x1, y1)
end

---draw a rectangle with vectors
---@param pos1 vec2
---@param pos2 vec2
---@param col integer? if nil, use previous color
---@param fill boolean?
---@param as_dim boolean? if true, pos2 is relative to pos1
function rect_vec(pos1, pos2, col, fill, as_dim)
 if (col) color(col)
 if (as_dim) pos2 += pos1
 (fill and rectfill or rect)(pos1.x, pos1.y, pos2.x, pos2.y)
end

-->8
-- MARK: asset loader
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
  asset_alloc = sfx_allocation,
  lru_list = {},
  source_list = {
   piao_piao = { file = "music/1.p8", y = 0, h = 3 },
   china = { file = "music/1.p8", y = 3, h = 1 },
   baka_mitai = { file = "music/1.p8", y = 4, h = 6 },
   binks_sake = { file = "music/main.p8", y = 0, h = 15 }
  }
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
  asset_alloc = spr_allocation,
  lru_list = {},
  source_list = {
   house = { file = "maps/home.p8", x = 0, y = 0, w = 24, h = 16 },
   shelf = { file = "maps/home.p8", x = 24, y = 0, w = 3, h = 1 },
   tower_segment = { file = "maps/tower.p8", x = 0, y = 0, w = 9, h = 5 },
   tower_ground = { file = "maps/tower.p8", x = 2, y = 5, w = 16, h = 10 }
  }
 }
 spr_allocation.wrapper_alloc = map_allocation

 for i = 0, 63 do
  asset_loader.spr_allocation[i] = true
 end
 for i = 64, 79 do
  asset_loader.spr_allocation[i] = true
  asset_loader.spr_allocation[i + 16] = true
 end
 for i = 96, 97 do
  asset_loader.spr_allocation[i] = true
  asset_loader.spr_allocation[i + 16] = true
 end

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
  if (settings.mute) return
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
-- MARK: structs

-- a function to create pet classes
function classfactory(static_vars, parent, class_list)
 assert(not is_runtime, "classfactory should not be called at runtime.")

 local class = parent and setmetatable(static_vars, parent) or static_vars
 class.__index = class
 if class_list then
  add(class_list, class)
 end
 -- blank new() function
 -- override if instance variables are needed
 class.new = function()
  return setmetatable(parent and parent.new() or {}, class)
 end

 return class
end

-- function to check of an object the specifed class or a subclass of it
function is_instance(object, class)
 if object == class then return true end
 local metatable = getmetatable(object)

 -- follow the metatable heirarcy
 -- assumes there are no inheritance loops
 while metatable do
  if metatable == class then return true end
  metatable = getmetatable(metatable)
 end

 return false
end

anim_timeline = classfactory({})
function anim_timeline.new(durations)
 return setmetatable({ durations = durations, step = 0 }, anim_timeline)
end
function anim_timeline:start(from)
 self.t0 = time()
 self.step = from or 1
 return self:get()
end
function anim_timeline:update()
 while true do
  local step, t = self:get()
  local dur = self.durations[step]
  if not dur or t < dur then return step, t end

  self.step += 1
  self.t0 += dur
 end
end
function anim_timeline:get()
 return self.step, self.t0 and time() - self.t0 or 0
end

vec2 = classfactory({})
function vec2.new(x, y) return setmetatable({ x = x, y = y or x }, vec2) end
function vec2.rng(x0, y0, x1, y1) return vec2.new(rngf(x0, x1 or x0), rngf(y0 or x0, y1 or y0 or x0)) end
function vec2.setfrom(v, a) v.x, v.y = a.x, a.y return self end
function vec2.unpack(v) return v.x, v.y end
function vec2.length2(v) return v.x * v.x + v.y * v.y end
function vec2.to_cartesian(v) return vec2.new(v.x * cos(v.y), v.x * sin(v.y)) end
function vec2.__add(a, b) return vec2.new(a.x + b.x, a.y + b.y) end
function vec2.__sub(a, b) return vec2.new(a.x - b.x, a.y - b.y) end
function vec2.__mul(a, b) if type(a) == "number" then a, b = b, a end return vec2.new(a.x * b, a.y * b) end
function vec2.__div(a, b) return vec2.new(a.x / b, a.y / b) end
function vec2.__unm(a) return vec2.new(-a.x, -a.y) end
function vec2.__eq(a, b) return a.x == b.x and a.y == b.y end
function vec2.__tostring(v) return "(" .. v.x .. "," .. v.y .. ")" end
vec2_0 = vec2.new(0)
vec2_1 = vec2.new(1)
vec2_8 = vec2.new(8)
vec2_9 = vec2.new(9)

particle = classfactory({})
function particle:new() return setmetatable({ pos = vec2.new(0), vel = vec2.new(0), acc = vec2.new(0) }, particle) end
function particle:set_pos(vec) self.pos = vec * 1 return self end
function particle:set_vel(vec) self.vel = vec * 1 return self end
function particle:set_acc(vec) self.acc = vec * 1 return self end
function particle:stop(stop) self.stopped = stop ~= false end
function particle:update()
 if (self.stopped) return
 self.pos += self.vel
 self.vel += self.acc
end

glider = classfactory({}, vec2)
function glider.new(rate, x, y)
 local self = setmetatable(vec2.new(x or 0, y), glider)
 self.rate = rate
 self.target = nil
 return self
end
function glider:move()
 if self.target then
  local dv = self.target - self

  if dv:length2() < 0.25 then
   return self:teleport(self.target)
  end

  self:setfrom(self + (dv * self.rate))
 end

 return self
end
function glider:set_target(vec_or_nil, no_copy)
 -- if (vec_or_nil and not no_copy) vec_or_nil *= 1
 self.target = vec_or_nil * 1
 return self
end
function glider:teleport(vec)
 self:setfrom(vec)
 self.target = nil
 return self
end

loot_tables = {
 { name = "common", color = 6, weight = 5 },
 { name = "uncommon", color = 11, weight = 4 },
 { name = "rare", color = 12, weight = 3 },
 { name = "epic", color = 14, weight = 2 },
 { name = "legendary", color = 9, weight = 1 }
}
for loot_table in all(loot_tables) do
 loot_table.pool = {}
end

-- MARK: pet

class__pet = classfactory({
 name = "default",
 immortal = false,
 sprite = 0,
 sprite_width = 2,
 sprite_height = 2,
 transparent = 11, --lime
 color_variants = {},
 rarity = 3, -- rare
 meat = 3,
 bone = 2
})
function class__pet.new()
 local self = setmetatable({}, class__pet)
 self.hunger = 15
 self.happiness = 15
 self.color_variant = 0
 self.effects = {
  hunger_prot = 0,
  happiness_prot = 0,
  hunger_2x = 0,
  happiness_2x = 0
 }
 return self
end

all_pets = {}
num_pet_types = 0xff
function classfactory__pet(static_vars, parent)
 static_vars.id = #all_pets + 1
 assert(static_vars.id <= num_pet_types, "too many pet types!")
 return classfactory(static_vars, parent or class__pet, all_pets)
end

-- set the color variant
-- set 0 for default variant, set nil for random
function class__pet:set_color(int_or_nil)
 self.color_variant = int_or_nil or flr(rnd(#self.color_variants + 1))
 return self
end

-- set the pet-specific palette
-- make sure to reset afterwards
function class__pet:pal(obscured)
 pal()

 if obscured then
  for i = 0, 15 do
   pal(i, 5)
  end
 else
  if self.color_variant ~= 0 then
   pal(self.color_variants[self.color_variant])
  end
 end

 palt(0, false)
 palt(self.transparent, true)
end

-- draw the pet's sprite
function class__pet:spr_scaled(x, y, scale, no_pal, flip_x, flip_y)
 if not no_pal then self:pal() end

 if not scale or scale == 1 then
  spr(self.sprite, x, y, self.sprite_width, self.sprite_height, flip_x, flip_y)
 else
  spr_scaled(self.sprite, x, y, scale, self.sprite_width, self.sprite_height, flip_x, flip_y)
 end

 pal()
end

function class__pet:change_hunger(delta)
 self.hunger = mid(self.hunger + delta, 0, 0xf)
 return self
end
function class__pet:change_happiness(delta)
 self.happiness = mid(self.happiness + delta, 0, 0xf)
 return self
end
function class__pet:update_effects(dt)
 for key, time in pairs(self.effects) do
  self.effects[key] = mid(time - dt, 0, 0xff)
 end
 return self
end

function class__pet:is_dead()
 return not self.immortal and self.hunger == 0 and self.happiness == 0
end

classfactory__pet({
 name = "arb duck",
 sprite = 64,
 rarity = 2,
 color_variants = {
  { [3] = 4, [4] = 15 }
 }
})
classfactory__pet({
 name = "cheeto",
 sprite = 66,
 rarity = 5,
 immortal = true
})
classfactory__pet({
 name = "yoomimmick",
 sprite = 68,
 rarity = 4
})
classfactory__pet({
 name = "squirrel",
 sprite = 70,
 rarity = 2,
 color_variants = {
  { [6] = 9, [5] = 4 }
 }
})
classfactory__pet({
 name = "turkey",
 sprite = 72,
 rarity = 2
})
classfactory__pet({
 name = "owl",
 sprite = 74,
 rarity = 3
})
classfactory__pet({
 name = "horse",
 sprite = 76,
 rarity = 4,
 color_variants = {
  { [4] = 5, [5] = 4, [1] = 0 },
  { [4] = 6, [6] = 7, [1] = 5 }
 }
})
classfactory__pet({
 name = "cow",
 sprite = 78,
 rarity = 3
})
classfactory__pet({
 name = "shoop",
 sprite = 96,
 rarity = 2
})

-- map integer pet.id to bool
local discovered_pets = {}
for i = 1, num_pet_types do
 local pet = all_pets[i]
 discovered_pets[i] = false
 if pet then
  add(loot_tables[pet.rarity].pool, pet)
 end
end

-- MARK: item
all_items = {
 { sprite = 32, rarity = 1, name = "chocolate", func = function(pet) pet.effects.happiness_prot = 60 end },
 { sprite = 33, rarity = 1, name = "banana", func = function(pet) pet.effects.happiness_2x = 60 end },
 { sprite = 34, rarity = 2, name = "meatball", func = function(pet) pet.effects.hunger_2x = 60 end },
 { sprite = 35, rarity = 3, name = "rice", func = function() asset_loader.play_music("china") end },
 { sprite = 36, rarity = 2, name = "drumstick", func = function(pet) pet.effects.hunger_prot = 60 end },
 {
  sprite = 51, rarity = 3, name = "bomb", func = function(pet, pets)
   switch_screen(screens.loose_pet:with(del(pets, pet), screens.bomb))
  end
 }
}

for i, item in ipairs(all_items) do
 item.id = i
 item.count = 0
 add(loot_tables[item.rarity].pool, item)
end

max_item_stack = 0xff
function change_item_count(id, delta)
 local item = all_items[id]
 if (item) item.count = mid(item.count + delta, 0, max_item_stack)
end

max_pets = 16

-->8
-- MARK: main loop
local is_runtime
local gacha_tickets = 3
local food = 5
local bones = 0

local current_pet = 1
local pets = {}
function pets:add(pet)
 add(self, pet)
 discovered_pets[pet.id] = true
end
pets:add(all_pets[1].new():set_color())

local stat_timers = {
 { last_check = time(), base_interval = 7, func = class__pet.change_happiness },
 { last_check = time(), base_interval = 5, func = class__pet.change_hunger }
}

local screen = nil
function switch_screen(screen_or_nil)
 screen = screen_or_nil or screens.home
 if screen.init then
  screen:init()
 end

 save_data()
end

-- return the sprite and name for bone
function bone_censor()
 if settings.grim then
  return 54, "bones"
 end
 return 55, "rocks"
end

local t = time()
local dt = 0
function _init()
 is_runtime = true

 settings = {
  --optional turn sound off
  mute = false,
  --optionally reveal the blender heh
  grim = false
 }

 --progress of minigames
 grim_progress = 0

 load_data()
 switch_screen()
end

function _update()
 dt = time() - t
 t = time()

 for pet in all(pets) do
  pet:update_effects(dt)
 end

 for stat in all(stat_timers) do
  if time() - stat.last_check > stat.base_interval / (1 + #pets * 0.1) then
   stat.last_check = time()
   for pet in all(pets) do
    stat.func(pet, -1)
   end
  end
 end
 screen:update()
end

function _draw()
 cls()
 screen:draw()
end

-- MARK: save data

function load_data()
 -- username_title_version
 if not cartdata("real-fancy-fire_tama-gatcha_1-4") then
  return false
 end

 local addr = 0x5e00

 -- user data
 settings.mute, settings.grim = unpack(decode_bitfield(peek(addr), 8))
 addr += 1

 -- discovered pets
 local a, b = peek(addr, 2)
 discovered_pets = decode_bitfield(a << 8 | b, num_pet_types)
 addr += 2

 -- currencies
 gacha_tickets, food, bones = peek(addr, 3)
 addr += 3

 -- items
 for item in all(all_items) do
  item.count = peek(addr)
  addr += 1
 end

 -- pets
 for i = 1, max_pets do
  local class, color_variant, stats = peek(addr, 3)
  class = all_pets[class]
  -- nil or pet instance
  local pet = class and class.new()
  if pet then
   pet.color_variant = color_variant
   pet.hunger = stats \ 0xf
   pet.happiness = stats & 0xf
  end
  pets[i] = pet
  addr += 3
 end

 printh("data loaded")
 return true
end

function save_data()
 local addr = 0x5e00

 -- user settings
 poke(
  addr, encode_bitfield({
   settings.mute, settings.grim, false, false,
   false, false, false, false
  })
 )
 addr += 1

 -- discovered pets
 local bits = encode_bitfield(discovered_pets)
 poke(addr, bits >> 8, bits & 0xff)
 addr += 2

 -- currencies
 poke(addr, gacha_tickets, food, bones)
 addr += 3

 -- items
 for item in all(all_items) do
  poke(addr, item.count)
  addr += 1
 end

 -- pets
 for i = 1, max_pets do
  local pet = pets[i]

  if pet then
   poke(addr, pet.id, pet.color_variant, pet.hunger << 4 | pet.happiness)
  else
   poke(addr, 0, 0, 0)
  end

  addr += 3
 end

 printh("data saved")
end

-->8
-- MARK: screens
class__gridmenu = classfactory({ selection = 1, selectables = {} })
function class__gridmenu:init()
 for m in all(self.load_music or {}) do
  asset_loader.load_music(m)
 end
 for m in all(self.load_map or {}) do
  asset_loader.load_map(m)
 end

 self.sel_glider:teleport(self:grid_vec())
end
function class__gridmenu:update_sel()
 local s = min(#self.selectables, grid_wrap(self.selection, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), self.w, self.h))
 self.selection = s
 return s, self.selectables[s]
end
function class__gridmenu:glide()
 return self.sel_glider:set_target(self:grid_vec()):move()
end
function class__gridmenu:grid_vec(i)
 return vec2.new(grid_coords(self.x, self.y, self.dx, self.dy, i or self.selection, self.w))
end

screens = {}

function classfactory__gridmenu(static_vars)
 static_vars.sel_glider = glider.new(0.5)
 return classfactory(static_vars, class__gridmenu)
end

do
 local cloud
 function background_house()
  if not cloud or cloud.x > 53 then
   cloud = vec2.rng(0, 15, nil, 40)
  end

  cls(12)
  cloud.x += 0.1
  spr_scaled(62, cloud.x, cloud.y, 1, 2, 1)
  asset_loader.draw_map("house", -32, 0)
  rectfill(35, 16, 36, 55, 7)
 end
end

-- MARK: home
do
 screens.home = classfactory__gridmenu({
  x = 4, y = 3, dx = 28, dy = 114, w = 5, h = 2,
  selectables = {
   { name = "food", sprite = 1 },
   { name = "game", sprite = 2, screen = "game_select" },
   { name = "stats", sprite = 3 },
   { name = "gacha", sprite = 4, screen = "gacha" },
   { name = "settings", sprite = 5, screen = "settings" },

   { name = "snacks", sprite = 17, screen = "snacks" },
   { name = "left", sprite = 18 },
   { name = "right", sprite = 19 },
   { name = "pets", sprite = 20, screen = "collection" },
   { name = "adopt", sprite = 21 }
  },
  load_music = { "binks_sake" },
  load_map = { "house" },
  shift = 0
 })
 local _ENV, scn = rescope(screens.home, _ENV)
 camera_glider = glider.new(0.5)
 function update()
  current_pet = mid(current_pet, 1, #pets)
  local pet = pets[current_pet]
  if (pet) asset_loader.play_music("binks_sake")
  local sel, icon = update_sel(scn)
  glide(scn)

  if btnp(❎) then
   --disallows feeding or playing after death to prevent revives
   if (not pet or pet:is_dead()) and (icon.name == "food" or icon.name == "game") then
    return
   end

   if icon.screen then
    switch_screen(screens[icon.screen])
   end

   if icon.name == "food" then
    if food > 0 then
     pet:change_hunger(2)
     food -= 1
    else
     -- sfx
    end
   elseif icon.name == "left" then
    current_pet = mod(current_pet - 1, #pets)
   elseif icon.name == "right" then
    current_pet = mod(current_pet + 1, #pets)
   elseif sel == 3 then
    shift = toggle_val(shift, 32, 0)
    -- elseif sel == 6 then
    --  shift = toggle_val(shift, -32, 0)
   elseif pet and sel == 10 then
    switch_screen(screens.loose_pet:with(deli(pets, current_pet)))
    current_pet = mid(current_pet, 1, #pets)
   end
  end
  camera_glider:set_target(vec2.new(shift, 0)):move()
 end
 function draw()
  camera(camera_glider.x, camera_glider.y)
  background_house()
  local pet = pets[current_pet]

  -- carpet
  ovalfill(16, 72, 112, 104, 13)
  oval(16, 72, 112, 104, 1)

  if pet then
   --draw current pet
   print_centered(pet.name, 64, 20, 0)
   if pet:is_dead() then
    if settings.grim then
     spr_scaled(50, 52, 62, 4)
    else
     palt(0x0010)
     spr_scaled(12, 32, 32, 4, 2, 2)
     pal()
    end
   else
    pet:spr_scaled(32, 32, 4, false, shift > 0)
   end

   -- draw stats
   for p, props in ipairs({
    { stat = pet.hunger + 1, double = pet.effects.hunger_2x, icon = pet.effects.hunger_prot > 0 and 23 or 22 },
    { stat = pet.happiness + 1, double = pet.effects.happiness_2x, icon = pet.effects.happiness_prot > 0 and 7 or 6 }
   }) do
    local x = 116 + 16 * p
    for _ = 0, 1 do
     for i = 0, 3 do
      spr(props.icon, x, 58 - i * 10)
     end
     clip(0, 0, 256, 66 - (props.stat + props.stat \ 4) * 2)
     for c = 0, 15 do
      pal(c, 0)
     end
    end
    clip()
    pal()
    print_centered(props.stat, x + 5, 68, 7)
    if (props.double > 0) print_centered("2X", x + 4, 20)
   end
  end

  camera()

  for i, icon in ipairs(selectables) do
   local x, y = grid_vec(scn, i):unpack()
   spr(icon.sprite, x, y)
   if i == selection then
    print_centered(icon.name, 64, 110, 7)
   end
  end

  if pet then
   --stats icon reflecting pet status
   for i, stat in ipairs({ pet.hunger, pet.happiness }) do
    local x = 57 + i * 4
    stat = stat \ 2
    if not pet:is_dead() then
     rectfill(x, 10 - stat, x + 1, 10, 11)
    end
   end
  end

  --print food counter
  print(food, 3, 13, 7)

  --draw number of pets and current pet indicator
  pal()
  for i = 1, #pets do
   circfill(71 - 7 * #pets + 14 * (i - 1), 105, 2, i == current_pet and 7 or 5)
  end

  rect_vec(sel_glider - vec2_1, vec2_9, 10, false, true)
 end
end

-- MARK: game_select
do
 screens.game_select = classfactory__gridmenu({
  x = 8, y = 8, dx = 60, dy = 60, w = 2, h = 2,
  selectables = {
   { name = "math", key = "math" },
   { name = "maze", key = nil },
   { name = "fishing", key = "fishing" },
   { name = "you shouldn't see this", key = nil }
  }
 })
 local _ENV, scn = rescope(screens.game_select, _ENV)
 function update()
  local _, game = update_sel(scn)
  glide(scn)

  if btnp(🅾️) then
   switch_screen()
  elseif btnp(❎) then
   screens.minigame.current_game = games[game.key]
   switch_screen(screens.minigame)
  end
 end
 function screens.game_select:draw()
  fillp(█)
  for i, game in ipairs(selectables) do
   local x, y = grid_vec(scn, i):unpack()
   local col = 3

   -- MARK: ToDo: whatever this is
   if i == 4 then
    if settings.grim then
     game.name = grim_progress .. "/3"
    else
     game.name = "tbd"
     col = 5
    end
   end

   draw_panel(game.name, x, y, 52, 52, col)
  end
  rect_vec(sel_glider, vec2.new(52), 10, false, true)
 end
 function draw_panel(label, x, y, w, h, col)
  rectfill(x, y, x + w, y + h, col)
  print_centered(label, x + flr(w / 2), y + flr(h / 2) - 3, 7)
 end
end

-- MARK: settings
do
 screens.settings = {
  selection = 1,
  options = {
   -- not called 'settings' to reduce confusion
   { name = "mute sound", key = "mute" },
   { name = "grim mode", key = "grim" }
  }
 }
 local _ENV, scn = rescope(screens.settings, _ENV)
 function update()
  selection = grid_wrap(selection, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 1, 2)
  if btnp(🅾️) then
   switch_screen()
  elseif btnp(❎) then
   local key = scn.options[selection].key
   -- assumes settings are boolean
   settings[key] = not settings[key]
   if settings.mute then
    asset_loader.play_music()
   end
  end
 end
 function draw()
  for i, option in ipairs(options) do
   local y = 20 + (i - 1) * 40
   local setting = settings[option.key]

   print_centered(option.name, 64, y, i == selection and 10 or 7)
   draw_checkbox(45, y + 14, setting)
   if i == selection then
    print_centered(">           <", 64, y, 10)
   end
  end

  spr_scaled(16, 62, 30, 2, 1, 1)
  if settings.mute then
   -- red x
   line(75, 35, 81, 41, 8)
   line(75, 41, 81, 35)
  else
   -- white sound waves
   line(76, 35, 76, 41, 7)
   line(79, 32, 79, 44)
  end

  if settings.grim then
   -- bloody
   pal(6, 8)
   print("✽", 67, 81, 8)
   print("★", 71, 78, 2)
  end
  spr_scaled(50, 64, 70, 2, 1, 1)
  pal()

  print_centered("❎ select  🅾️ exit", 64, 110, 5)
 end
 function screens.settings.draw_checkbox(x, y, checked)
  rect(x, y, x + 8, y + 8, 7)
  if checked then
   print("🐱", x + 1, y + 2, 8)
  end
 end
end

-- MARK: snacks
do
 screens.snacks = classfactory__gridmenu({
  x = 8, y = 8, dx = 44, dy = 44, w = 3, h = 2,
  selectables = all_items
 })
 local _ENV, scn = rescope(screens.snacks, _ENV)
 function update()
  local _, item = update_sel(scn)
  glide(scn)

  if btnp(🅾️) then
   switch_screen()
  elseif btnp(❎) then
   if item.count > 0 then
    -- change_item_count not needed here
    item.count -= 1
    item.func(pets[current_pet], pets)
   else
    -- play error sound
   end
  end
 end
 function draw()
  for i, item in ipairs(selectables) do
   local amount = item.count
   local sx, sy = grid_vec(scn, i):unpack()

   spr_scaled(item.sprite, sx, sy, 3)

   print_centered(amount, sx - 5, sy, 7)
   if i == selection then
    print_centered(item.name, 64, 100, 7)
   end
  end
  rect_vec(sel_glider, vec2.new(24), 10, false, true)
  print_centered("🅾️ exit    ❎ use", 64, 110, 7)
 end
end

-- MARK: collection
do
 screens.collection = classfactory__gridmenu({
  x = 8, y = 8, dx = 32, dy = 32, w = 4, h = 4,
  selectables = all_pets
 })
 local _ENV, scn = rescope(screens.collection, _ENV)
 function update()
  update_sel(scn)
  glide(scn)

  if btnp(🅾️) then
   switch_screen()
  end
 end
 function draw()
  --draw all pets
  for i, pet_cls in pairs(selectables) do
   local sx, sy = scn:grid_vec(i):unpack()
   local name = pet_cls.name

   if discovered_pets[pet_cls.id] then
    pet_cls:spr_scaled(sx, sy, 1)
   else
    pet_cls:pal(true)
    pet_cls:spr_scaled(sx, sy, 1, true)
    name = "???"
   end

   if i == selection then
    print_centered(name, 64, 100, 7)
   end
  end
  rect_vec(sel_glider, vec2.new(16), 10, false, true)
  print_centered("🅾️ exit", 64, 110, 5)
 end
end

-- MARK: loose_pet
do
 screens.loose_pet = {}
 local _ENV = rescope(screens.loose_pet, _ENV)
 function with(self, pet_, force)
  pet = pet_
  target = force or decide(pet)
  return self
 end
 function init()
  if (target) target.pet = pet
  switch_screen(target)

  if pet.happiness > 0 then
   food += pet.meat * 4
   bones += pet.bone
  end

  pet = nil
  asset_loader.play_music()
  asset_loader.load_music("baka_mitai")
 end
 function decide(pet)
  if (pet.immortal) return screens.abandon
  if (not settings.grim) return screens.abandon
  if (pet.happiness == 0) return screens.talljump
  return screens.blender
 end
end
-- MARK: abandon
do
 screens.abandon = {
  timeline = anim_timeline.new({})
 }
 local _ENV = rescope(screens.abandon, _ENV)
 function init()
  _ENV.timeline:start()
 end
 function update()
  local step, t = timeline:update()
  if t > 4 and btnp(🅾️) then
   switch_screen()
  end
 end
 function draw()
  local step, t = timeline:get()
  local x = accelerp(24, 50, 0, t)
  pal()
  clip(0, 0, x + 8, 128)
  print_centered(pet.name .. " has left you", 64, 60, 6)
  clip()
  circfill(x + 2, 52, 4, 8)
  for i = 0, 2 do
   line(x + 2, 48 + i, x + 22, 68 + i, 4)
  end

  pet:spr_scaled(x, 44, 2, false, true, false)
  if t > 4 then
   asset_loader.play_music("baka_mitai")
   print("you received: " .. (pet.meat * 4) .. "   " .. pad(pet.bone), 16, 70, 6)
   spr(36, 82, 68)
   spr(bone_censor(), 102, 68)

   print_centered("🅾️ exit", 64, 110, 5)
  end
 end
end
-- MARK: talljump
do
 screens.talljump = {
  timeline = anim_timeline.new({ 1, 1.5, 2, 60, 6, 1 })
 }
 local _ENV = rescope(screens.talljump, _ENV)
 function init()
  timeline:start()
  gore_pool = {}
  splash = false
  y4 = 0
 end
 function update()
  local step, t = timeline:update()

  if #gore_pool < 2100 then
   for i = 1, 100 do
    local p = add(gore_pool, particle.new())
    p:set_pos(vec2.rng(80, 96, 96, nil))
    local vel = vec2.rng(1, 0, 7, 1):to_cartesian()
    if i < 25 then
     vel.y = -abs(vel.y)
     vel.x *= 0.4
    end
    vel.y *= abs(vel.y) * 0.5

    p:set_vel(vel)
    p:set_acc(vec2.new(0, 0.1))
   end
  end

  if step == 4 then
   if y4 > 88 then
    timeline:start(5)
   end
  elseif step >= 5 then
   for p in all(gore_pool) do
    if p.pos.y < -32 then
     p.vel.x *= 0.1
     p.vel.y = min(p.vel.y, 10)
    end

    if p.pos.y > 96 and rnd() < 0.75 then
     p:stop()
    end
    if p.pos.x < 48 and rnd() < 0.5 then
     p:stop()
    end
    p:update()
   end

   if step == 6 then
    asset_loader.play_music("baka_mitai")
   elseif step == 7 then
    if btnp(🅾️) then
     switch_screen()
    end
   end
  end
 end
 function draw()
  cls(12)
  local step, t = timeline:get()
  local draw_map = asset_loader.draw_map

  if step <= 2 then
   palt()
   spr_scaled(62, 16, 16, 1, 2, 1)
   spr_scaled(62, 96, 20, 1, 2, 1)
   local x, y = 48, 50
   if step == 2 then x, y = accelerp(48, 50, -25, t), accelerp(50, -50, 200, t) end
   pet:spr_scaled(x, y, 1, false, true, false)
   palt(0x0010)
   draw_map("tower_segment", 0, 62)
   draw_map("tower_segment", 0, 102)
  end

  if step == 3 then
   palt(0x0010)
   for i = 0, 5 do
    draw_map("tower_segment", 0, i * 40 - (t * 240) % 40)
   end
   pet:spr_scaled(
    88,
    accelerp(32, 32, 0, t),
    1, false, true, false
   )
  elseif step >= 4 then
   if step == 4 then
    y4 = accelerp(-128, 256 * 4, 0, t)
    pet:spr_scaled(80, y4, 1, false, true, false)
   end

   palt(0x0010)
   draw_map("tower_segment", -16, -24)
   draw_map("tower_segment", -16, 16)
   draw_map("tower_ground", 0, 56)

   if step >= 5 then
    -- draw particles
    for particle in all(gore_pool) do
     pset(particle.pos.x, particle.pos.y, 8)
    end
   end

   if step >= 6 then
    print_centered(pet.name .. " was sad.", 90, 48, 7)
   end
   if step == 7 then
    print_centered("🅾️ exit", 64, 110, 5)
   end
  end
 end
end
-- MARK: blender
do
 screens.blender = {
  timeline = anim_timeline.new({ 1, 0.5, 1.5, 1.5, 3 }),
  frame = 1
 }
 local _ENV = rescope(screens.blender, _ENV)
 function init()
  timeline:start()
  gore_pool = {}
  splash = false
 end
 function update()
  local step, t = timeline:update()

  if step >= 2 and step < 5 then
   update_particles()
   add_particles(2)
  elseif step == 5 then
   if not splash then
    splash = true
    add_particles(80)
    add_particles(pet.meat, 36)
    add_particles(pet.bone, 54)
   end
   update_particles()
  elseif step == 6 then
   asset_loader.play_music("baka_mitai")
   if btnp(🅾️) then
    switch_screen()
   end
  end
 end
 function draw()
  local step, t = timeline:get()

  draw_blender(55 + frame % 2, 52, step)

  if step == 1 then
   clip(0, 0, 128, 52)
   pet:spr_scaled(56, accelerp(-16, 20, 100, t))
   clip()
  elseif step >= 2 then
   draw_particles()
   if (step < 5) frame += 1
  end
  if (step > 5) print_centered("🅾️ exit", 64, 110, 5)
 end
 function draw_blender(x, y, step)
  pal()
  if step >= 4 then
   pal(6, 8)
  elseif step == 3 then
   pal(6, 14)
  end

  palt(0x0010)
  spr_scaled(14, x, y, 1, 2, 3)
 end
 function add_particles(num, sprite)
  for _ = 1, num do
   local p = add(gore_pool, particle.new())
   p:set_pos(vec2.rng(56, 51, 72, nil))
   p:set_vel(vec2.rng(-0.75, -1.75, 0.75, -0.5))
   p:set_acc(vec2.new(0, 0.1))
   if sprite then
    p.sprite = sprite
    p.flip = rnd() < 0.5
   end
  end
 end
 function update_particles()
  for p in all(gore_pool) do
   p:update()
   if p.pos.y > 76 then
    p.pos.y = 76
    p:stop()
   end
  end
 end
 function draw_particles()
  pal()
  for p in all(gore_pool) do
   if p.sprite then
    spr(p.sprite, p.pos.x - 4, p.pos.y - 7, 1, 1, p.flip)
   else
    pset(p.pos.x, p.pos.y, 8)
   end
  end
 end
end
-- MARK: bomb
do
 screens.bomb = {
  timeline = anim_timeline.new({ 2, 1 })
 }
 local _ENV = rescope(screens.bomb, _ENV)
 function init()
  timeline:start()
  gore_pool = {}
  splash = false
 end
 function update()
  local step, t = timeline:update()

  if step > 2 then
   if not splash then
    splash = true
    add_particles(1000)
    add_particles(pet.bone * 2, 54)
   end
   update_particles()
  end

  if step == 3 and t > 4 then
   asset_loader.play_music("baka_mitai")
   if btnp(🅾️) then
    switch_screen()
   end
  end
 end
 function draw()
  local step, t = timeline:get()
  print(step)
  print(t)

  local explodes = settings.grim and not pet.immortal

  if step == 1 then
   pet:spr_scaled(64, 56)
   spr(51, accelerp(-8, 64, -32, t), 64)
  elseif step == 2 then
   pet:spr_scaled(64, 56)
   spr(51, 56, 64)
  elseif step == 3 then
   if explodes then
    draw_particles()
   else
    spr(51, 56, 64)
    pet:spr_scaled(accelerp(64, 32, 0, t), 56, 1, nil, true)
   end
   if t > 3 then
    print_centered(pet.name .. " did not like that.", 64, 80, 7)
   end
   if t > 4 then
    print_centered("🅾️ exit", 64, 110, 5)
   end
  end
 end
 function add_particles(num, sprite)
  for _ = 1, num do
   local p = add(gore_pool, particle.new())
   p:set_pos(vec2.new(72, 60) + vec2.rng(0, 0, 8, 1):to_cartesian())
   p:set_vel(p.pos - vec2.new(64))
   p:set_acc(vec2.new(0, 0.1))
   if sprite then
    p.vel /= 4
    p.sprite = sprite
    p.flip = rnd() < 0.5
   end
  end
 end
 function update_particles()
  for p in all(gore_pool) do
   p:update()
   if p.pos.y > 76 then
    p.pos.y = 76
    p:stop()
   end
  end
 end
 function draw_particles()
  pal()
  for p in all(gore_pool) do
   if p.sprite then
    spr(p.sprite, p.pos.x - 4, p.pos.y - 7, 1, 1, p.flip)
   else
    pset(p.pos.x, p.pos.y, 8)
   end
  end
 end
end

-->8
--MARK: gacha

do
 screens.gacha = {}
 local _ENV, scn = rescope(screens.gacha, _ENV)

 function apply_bonus()
  weights = {}
  local sum = 0

  for loot_table in all(loot_tables) do
   sum += loot_table.weight
   add(weights, loot_table.weight)
  end
  local average = sum / #loot_tables
  sum = 0

  for i = 1, #weights do
   weights[i] = max(0, lerp(weights[i], average, bonus / 10))
   sum += weights[i]
  end

  for i = 1, #weights do
   weights[i] /= sum
  end
 end

 function init()
  rolls = 1
  bonus = 0
  apply_bonus()
 end
 function update()
  local x, y = btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️)
  rolls = mid(rolls - y, 1, 10)
  bonus = mid(bonus + x, 0, 64)
  if x ~= 0 then
   apply_bonus()
  end

  if btnp(🅾️) then
   switch_screen()
  elseif btnp(❎) then
   if gacha_tickets >= rolls and bones >= bonus * rolls then
    gacha_tickets -= rolls
    bones -= bonus * rolls
    switch_screen(screens.gacha_anim.with(weights, rolls))
   end
  end
 end
 function draw()
  --tickets icon
  spr(37, 0, 0)
  print(gacha_tickets, 10, 2, 9)
  spr(bone_censor(), 0, 8)
  print(bones, 10, 10, 9)

  print("⬆️", 8, 48, 9)
  print(pad(rolls) .. "   rolls")
  print("⬇️")

  print("⬅️" .. pad(bonus) .. "➡️ bonus", 0, 80)

  for i, loot_table in ipairs(loot_tables) do
   local x, y = lerp(64, 127, weights[i]), 24 + 12 * i
   rectfill(127, y, x, y + 2, 5)
   rectfill(64, y, x, y + 2, loot_table.color)
   print(pad(flr(weights[i] * 100)) .. "% " .. loot_table.name, 64, y - 6)
  end

  print_centered("❎ confirm   🅾️ back", 64, 110, 5)
 end
end

--MARK: gacha_anim
do
 screens.gacha_anim = classfactory__gridmenu({
  pull_type = nil,
  prizes_to_delete = {},
  timeline = anim_timeline.new({ 3, 1 }),
  monopull = nil,
  prizes = {}
 })
 local _ENV, scn = rescope(screens.gacha_anim, _ENV)

 function pull_gacha()
  local roll = rnd()
  for i, weight in ipairs(weights) do
   roll -= weight
   if roll <= 0 then
    local prize = rnd(loot_tables[i].pool)
    return is_instance(prize, class__pet) and prize.new():set_color() or prize
   end
  end
 end

 function with(weights_, rolls_)
  weights = weights_
  rolls = rolls_
  return scn
 end

 function init()
  monopull = nil
  prizes_to_delete = {}
  prizes = {}
  for _ = 1, rolls do
   add(prizes, pull_gacha())
  end

  if (rolls == 1) monopull = prizes[1]
  if monopull then
   x, y, dx, dy, w, h = 32, 108, 32, 8, 2, 1
   selectables = { "keep", "recycle" }
   if is_instance(monopull, class__pet) and screens.loose_pet.decide(monopull) == screens.abandon then
    selectables[2] = "release"
   end
  else
   x, y, dx, dy, w, h = 4, 33, 26, 46, 5, 2
   selectables = prizes
  end

  selection = 1
  sel_glider:teleport(grid_vec(scn))

  timeline:start()
  asset_loader.play_music("piao_piao")
 end
 function update()
  step, t = timeline:update()
  if btnp(🅾️) and step < 3 then
   step, t = timeline:start(3)
  elseif step == 3 then
   update_sel(scn)
   glide(scn)

   if monopull then
    if btnp(🅾️) then
     selection = 1
    end
    if btnp(❎) then
     if selection == 1 then
      keep_prize(monopull)
      switch_screen()
      return
     elseif selection == 2 then
      if discard_prize(monopull) then
       switch_screen(screens.loose_pet:with(monopull))
      else
       switch_screen()
      end
      return
     end
    end
   else
    if btnp(❎) then
     prizes_to_delete[selection] = not prizes_to_delete[selection]
    end
    if btnp(🅾️) then
     for i, prize in pairs(prizes) do
      if prizes_to_delete[selection] then
       discard_prize(prize)
      else
       keep_prize(prize)
      end
     end
     switch_screen()
     return
    end
   end
  end
 end
 function draw()
  local step, t = timeline:get()

  local shake = 0
  if step == 1 then
   print_centered("🅾️ skip", 64, 110, 5)
   shake = sin(t)
  end

  if monopull then
   draw_prize(monopull, 48 + shake, 48, 4, step > 1)
  else
   for i, prize in pairs(selectables) do
    local x, y = scn:grid_vec(i):unpack()
    shake *= -1
    draw_prize(prize, x + shake, y, 2, step > 1)

    if i == selection and step == 3 then
     print_centered(prize.name, 64, 102, loot_tables[prize.rarity].color)
    end

    if prizes_to_delete[i] then
     for j = 0, 3 do
      cx = x + j % 2
      cy = y + j \ 2
      line(cx, cy, cx + 15, cy + 15, 8)
      line(cx, cy + 15, cx + 15, cy, 8)
     end
    end
   end
  end

  if step == 3 then
   if monopull then
    for i, label in pairs(selectables) do
     local x, y = scn:grid_vec(i):unpack()
     print_centered(label, x + dx / 2, y + 1, 7)
    end
    print_centered(monopull.name, 64, 20, loot_tables[monopull.rarity].color)
    rect_vec(sel_glider - vec2_1, vec2.new(dx, dy), 10, false, true)
   else
    print_centered("❎ discard  🅾️ exit", 64, 110, 7)
    rect_vec(sel_glider - vec2_1, vec2.new(17), 10, false, true)
   end
  end
 end
 function draw_prize(prize, x, y, size, open)
  local is_pet = is_instance(prize, class__pet)
  if is_pet and open then
   prize:spr_scaled(x, y, size / 2)
   return
  end

  pal()

  --present box
  local sprite = 49

  if open then
   sprite = prize.sprite
   palt(prize.transparent, true)
  elseif is_pet then
   sprite = 48 --egg
   if prize.rarity == 5 then
    pal(7, 9)
   end
  end

  spr_scaled(sprite, x, y, size, 1, 1)
 end
 function keep_prize(prize)
  if is_instance(prize, class__pet) then
   pets:add(prize)
  else
   change_item_count(prize.id, 1)
  end
 end
 function discard_prize(prize)
  if is_instance(prize, class__pet) then
   food += prize.meat * 4
   bones += prize.bone
   return true
  else
   food += 4
   return false
  end
 end
end
-->8
--MARK: games

do
 screens.minigame = {}
 local _ENV = rescope(screens.minigame, _ENV)
 current_game = nil
 function init()
  if (current_game) current_game:init()
 end
 function update()
  if (current_game) current_game:update()
 end
 function screens.minigame:draw()
  if (current_game) current_game:draw()
 end

 function finish_game()
  if not current_game then return switch_screen() end
  local reward = current_game.reward or {}

  gacha_tickets += reward.gacha_tickets or 0
  food += reward.food or 3
  pets[current_pet]:change_happiness(reward.happiness or 0)

  current_game = nil

  switch_screen()
 end
end

games = {}
do
 games.math = {}
 local _ENV = rescope(games.math, _ENV)
 reward = {
  gacha_tickets = 2,
  food = 0,
  happiness = 15
 }
 operation_keys = { "+", "-", "*" }
 operations = {
  ["+"] = function(a, b) return a + b end,
  ["-"] = function(a, b) return a - b end,
  ["*"] = function(a, b) return a * b end
 }

 function init()
  progress = 0
  setup_question()
 end
 function setup_question()
  local a, b = flr(rnd(10)), flr(rnd(10))
  local op_key = rnd(operation_keys)

  local ans = operations[op_key](a, b)
  question_str = a .. op_key .. b

  options = {}

  --make sure no overlap answers
  local option_set = { [ans] = true }
  while #options < 3 do
   local new = ans + flr(rnd(6)) - 2
   if not option_set[new] then
    option_set[new] = true
    add(options, new)
   end
  end

  answer = flr(rnd(4))
  add(options, ans, answer + 1)
 end
 function update()
  if btnp(answer) then
   progress += 1

   if progress == 5 then
    screens.minigame:finish_game()
    return
   end

   setup_question()
  elseif btnp(0) or btnp(1) or btnp(2) or btnp(3) then
   progress = mid(0, progress - 1, 5)
   setup_question()
  end
 end
 function games.math:draw()
  print(progress .. "/5", 110, 3, 7)

  print_centered(question_str, 64, 61)

  print_centered(options[1], 34, 61)
  draw_triangle(22, 63, 40, 77, 40, 49)

  print_centered(options[2], 94, 61)
  draw_triangle(104, 63, 86, 77, 86, 49)

  print_centered(options[3], 64, 31)
  draw_triangle(63, 104, 77, 86, 49, 86)

  print_centered(options[4], 64, 91)
  draw_triangle(63, 22, 77, 40, 49, 40)
 end
end

do
 games.fishing = {}
 local _ENV = rescope(games.fishing, _ENV)
 reward_win = {
  gacha_tickets = 1,
  food = 3,
  happiness = 15
 }
 function init()
  fish_x = 50
  --ui ranges from 20 to 108

  escape_ui_x = 64
  new_esc_ui_x = 64

  user_ui_x = 21

  last⧗ = time()
  fish⧗ = time()
 end

 function update()
  if fish_x > 130 then
   --leave loss
   if time() - last⧗ > 3 then
    reward = nil
    screens.minigame:finish_game()
   end
   return
  elseif fish_x < 30 then
   --leave win
   if time() - last⧗ > 3 then
    reward = reward_win
    screens.minigame:finish_game()
   end
   return
  end

  if time() - last⧗ > 0.3 then
   if fish_x > 80 then
    fish_x += 5
   elseif user_ui_x > escape_ui_x and escape_ui_x + 10 > user_ui_x then
    fish_x -= 3
   else
    fish_x += 1
   end

   last⧗ = time()
  end

  --escape ui width == 20
  --ranges from 20 to 78
  if time() - fish⧗ > 2 then
   new_esc_ui_x = flr(rnd(1) * 58) + 20
   fish⧗ = time()
  end
  --move the fish_ui to new_esc_ui_x
  escape_ui_x += (new_esc_ui_x - escape_ui_x) * 0.1
  if btn(❎) then
   user_ui_x = min(user_ui_x + 3, 98)
  else
   user_ui_x = max(user_ui_x - 3, 21)
  end
 end

 function draw()
  if fish_x > 130 then
   --lose
   print_centered("you lost the fish", 63, 60, 7)
   return
  elseif fish_x < 30 then
   --win
   print_centered("you got the fish!", 63, 60, 7)
   print_centered("+3 food", 63, 68, 4)
   print_centered("+1 ticket", 63, 76, 9)
   return
  end

  print_centered("press ❎ to move hook", 63, 104, 7)
  print_centered("keep hook in blue zone", 63, 112, 7)
  fillp(█)
  rectfill(20, 40, 0, 60, 5)
  rectfill(0, 60, 128, 80, 1)

  --pet + fishing pole
  pets[current_pet]:spr_scaled(3, 25, 1, false, true, false)
  line(13, 36, 28, 23, 4)

  --fish
  rectfill(fish_x, 69, fish_x + 6, 71, 12)
  --fish ui
  rectfill(escape_ui_x, 91, escape_ui_x + 25, 99)

  --fishing line
  line(min(fish_x, 80), 69, 6)

  --line ui
  rectfill(user_ui_x, 91, user_ui_x + 10, 99)
  --ui box
  rect(20, 90, 108, 100, 7)
 end
end

__gfx__
00000000000000000000000007700770000000000006700000aaaa0000aaaa0000000000000000000000000000000000bbb666bbbb44bbbb7777777777777777
0000000000009900056776500770077009994080075776700aaaaaa00a777aa000000000000000000000000000000000bb6fff666444bbbb7666666666666667
007007000009979007777770077007700777705006777750aa0aa0aaa709a0aa00000000000000000000000000000000bb6f0ffff446bbbb7676666666666667
000770000099994007877570077007700777705077700776aa0aa0aa7a09a09a00000000000000000000000000000000bb6f00ffffff666b7676666666666667
000770000069440007777770077007700944455067700777aaaaaaaa7aaa999700000000000000000000000000000000b6ff0f0f0f0ffff6b76766666666667b
007007000675000006755760077007700444400005777760a000000aa000000900000000000000000000000000000000b6ff00ff0f0f0ff6b76766666666667b
0000000007000000006006000770077004444000076775700a0000a00a00009000000000000000000000000000000000b6fffffff0f0f0f6b76666666666667b
00000000000000000000000007700770000000000007600000aaaa000099990000000000000000000000000000000000bb666fff0ff00f6bb76666666666667b
000077000000000000000000000000000000000000000000000044000000aa0000000000000000000000000000000000bbbbb664fff0ff6bbb766666666667bb
0007770000600000000700000000700007007000000d10000044444000a777a000000000000000000000000000000000bbbbbbb4466f0f6bbb766666666667bb
77777700066e700000770000000077000777700000d11100044444440a7aaa9a00000000000000000000000000000000bbbbbb444bb666bbbb766666666667bb
7777770000eeee000777777777777770067760600dd11110044444450aa9999400000000000000000000000000000000bbbbbb44bbbbbbbbbb766666666667bb
77777700002eee0077777777777777770077006000655500088444450a99999400000000000000000000000000000000bbbbbb44bbbbbbbbbbb7666666667bbb
777777000002266007777777777777700077707000655500078844500799994000000000000000000000000000000000bbbbb444bbbbbbbbbbb7666666667bbb
000777000000060000770000000077000076770000655500776855007769440000000000000000000000000000000000bbbbb44bbbbbbbbbbbb7666666667bbb
000077000000000000070000000070000000000000000000660000006600000000000000000000000000000000000000bbbbb44bbbbbbbbbbbb7777777777bbb
00004400077000000000000000767700000044000000a0000000000000000000000000000000000000000000000000000000000000000000bbb1111111111bbb
004444400767000000f87f000677776000444440000a9a000000000000000000000000000000000000000000000000000000000000000000bbb1111111011bbb
04444444076700000f88fff0777767760444444400a999a00000000000000000000000000000000000000000000000000000000000000000bb110111100011bb
11664444007670000ffff87076777777044444450a99a99a0000000000000000000000000000000000000000000000000000000000000000bb111101110111bb
1116664400aaaaa008fff8806776776708844445a9a999a00000000000000000000000000000000000000000000000000000000000000000bb111111111111bb
111116660a99aa0a0f78ff7015555551078844500a9a9a000000000000000000000000000000000000000000000000000000000000000000b11111111111111b
011111060909aaa00088ff00115555117768550000a9a0000000000000000000000000000000000000000000000000000000000000000000b11111111111111b
00110000000099aa000000000111111066000000000a00000000000000000000000000000000000000000000000000000000000000000000b11111111111111b
00077000080000800077770000000660888888888888888800000770000070cc0000000000000000000000000000000000000000000000000066000660000000
007777008080080807777770000060a88888a8888a88888800000777000777cc0000000000000000000000000000000000000000000000000666606666066000
00777700088888800556557000756588888aaa88888888880000777700cc7cc00000000000000000000000000000000000000000000000006666666666666600
077777707778877705575560075555508aaaaaaa88a888880007770000ccccc00000000000000000000000000000000000000000000000006666666666666666
0777777006622660076577607555555588aaaaa888888888007770000ccccd000000000000000000000000000000000000000000000000006666666666666600
07777770077887700677760075555555888aaa8888a88888777700000cccdd000000000000000000000000000000000000000000000000000666666666660000
0777777007788770056565000755555088aa8aa88888888877700000cccd00000000000000000000000000000000000000000000000000000006666066000000
007777000778877000000000005555008aa888aa8a88888807700000cd0000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb020bbbbbbbbbbbbbbbbbbbbbb66bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4bbbb4bbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb52bbbbbb0000bbbbbbbbbbb666666bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4bb4bbbbbbbbbbbbbbbb7777bbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0eeebbb5fff220b6bb5bbbb6666556bbbbbbbbbbbbbbbbbbb44bbbbbb44bbbbbb114bbbbbbbbbbb44b77777777b44b
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4eeff55ff00bbbbb666bbbb6665555bbbbbbbbbbbbbbbbbbb44bbbbbb44bbbbb17111bbbbbbbbb4994577777754994
bb3333bbbbbbbbbbb9bbbbb9bbbbbbbbbbb57ff7ff0bbbbbb60766bbb6665bb5bbbbbbbb44444bbbbbb4444444444bbbbb40411bbbbbbbbbbb440577775044bb
bb33303bbbbbbbbbb99bbb99bbbbbbbbbb5f2ff2fff5bbbb660066bbb666bbbbbbbbbb4994444bbbbbb4444444444bbbb644e111bbbbbbbbbbbb55777755bbbb
b999333bbbbbbbbbb9999999bbbbbbbbbb4effffeef0bbbbf66666bbb6666bbbbb44bb499449944bbbb4444444444bbb74444111bb444bbbbbbb77777777bbbb
b999333bbbbbbb7bb9099099bbb9bbbbbb42f2f2eef0bbbbb6666566bb6665bbbb044b449499444bbbb4004440044bbbb5411411144444bbbbb7ffffffff7bbb
bb33333bbbbb777bb9999999bbb999bbbbb42f2fff0bbbbbbb5556666b66665bb8444b44999444bbbbb4444444444bbbbbb11411414444bbbbbf55ffff55fbbb
bb3333444444477bb99999999bbbb99bbbbb4ffff0bbbbbbbbbd666666b6655bb8b99444994499bbbbb4449994444bbbbbbb14414444441bbbbff5ffff5ffbbb
bb4444444444444bbb9979999bbbbb9bbbbbb4ff0bbbbbbbbb5dd56666bb655bbbb9994449994bbbbbb4449994444bbbbbb1b44414444411bbbffffffffffbbb
bb444444999444bbbb977794499bbb9bbbbb45f5f4bbbbbbbbbd566666b655bbbbb999999994bbbbbbb4444944444bbbbbbb44b44bb4b441bbbbffffffffbbbb
bb444499944444bbbb777794999bb99bbbb4f5f5ff0bbbbbbbbbd66666655bbbbbb4444444bbbbbbbbb444444444bbbbbbbb4bb4bbb6bb41bbbbb777777bbbbb
bbbb44444444bbbbbb777799999b99bbbbb0fffffee0bbbbbbbb6666655bbbbbbbbbb4444bbbbbbbbbbb44bbbb4bbbbbbbbb7bb4bbb5bb7bbbbbb757757bbbbb
bbbbbbbbbbbbbbbbb9777949999999bbbb5e0e0ee0e0bbbbbb55bb666bbbbbbbbbbbbb4bbbbbbbbbbbbbb4bbbb4bbbbbbbbbb5b7bbbbbb5bbbbb57577575bbbb
bbbbbbbbbbbbbbbbb977949999999bbbbb00d0d00d000bbbbbbbb55bbbbbbbbbbbbbb444bbbbbbbbbbbb444bb444bbbbbbbbbbb5bbbbbbbbbbb5bb5bb5bb5bbb
77bbbbbbbbbbbb770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7f7bbb777b7bb7f70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b77b77777777777b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb77777777777bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb777777777777bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b7770777770777bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b777777777777bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb770777770777bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb77700000777bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb7777777777bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb7777777777bbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbb6777776bbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb666666666bbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb665666566bbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb5b56665b5bbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb5bb5bbb5bb5bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
