pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- MARK: main loop
is_runtime = false
function _init()
 is_runtime = true
 gacha_tickets = 10
 food = 1
 bones = 0
 --multiplier for too many pets
 --equation in get_penalty_mult
 swarm_penalty = 0.1
 --baseline of when to decrease vars (sec)
 hunger_tick = 5
 happiness_tick = 7

 last_fed = time()
 last_play = time()

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
 update_hunger()
 update_happiness()
 screen:update()
end

function _draw()
 cls()
 screen:draw()
end

screen = nil
function switch_screen(screen_or_nil)
 screen = screen_or_nil or screens.home
 if screen.init then
  screen:init()
 end

 save_data()
end

-->8
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

current_music = {}
music_dir = {
 tbd0 = { file = "music/1.p8", track = 1 },
 rice_jingle = { file = "music/1.p8", track = 3 },
 pet_loss = { file = "music/1.p8", track = 4 }
}
function load_music(key, preload)
 if key == nil then
  current_music.track = nil
  return music(-1)
 end
 local entry = music_dir[key]
 if current_music.file ~= entry.file then
  -- MARK: ToDo: half sfx load size
  reload(0X3100, 0X3100, 0x0100, entry.file)
  reload(0X3200, 0X3200, 0x1100, entry.file)
  current_music.file = entry.file
 end
 if not settings.mute and not preload and current_music.track ~= entry.track then
  current_music.track = entry.track
  music(entry.track)
 end
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
-- big-endian
function encode_bitfield(bool_array)
 local ret = 0
 for i in all(bool_array) do
  ret = ret << 1
  if (i) ret += 1
 end
 return ret
end
-- decode an integer as a bool array
-- big-endian
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

function get_penalty_mult()
 return #pets * swarm_penalty + 1
end

function update_hunger()
 if time() - last_fed > hunger_tick / get_penalty_mult() then
  last_fed = time()
  --do this for all pets later
  for pet in all(pets) do
   pet:change_hunger(-1)
  end
 end
end

function update_happiness()
 if time() - last_play > happiness_tick / get_penalty_mult() then
  last_play = time()
  --do this for all pets later
  for pet in all(pets) do
   pet:change_happiness(-1)
  end
 end
end

function feed_pet()
 if (food == 0) return
 pets[current_pet]:change_hunger(2)
 food -= 1
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
 if (vec_or_nil and not no_copy) vec_or_nil *= 1
 self.target = vec_or_nil
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

all_pets = {}
num_pet_types = 15
function classfactory__pet(static_vars, parent)
 static_vars.id = #all_pets + 1
 assert(static_vars.id <= num_pet_types, "too many pet types!")
 return classfactory(static_vars, parent or class__pet, all_pets)
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
 return self
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

function class__pet:is_dead()
 return not self.immortal and self.hunger == 0 and self.happiness == 0
end

classfactory__pet({
 name = "arb duck",
 sprite = 6,
 rarity = 2,
 color_variants = {
  { [3] = 4, [4] = 15 }
 }
})
classfactory__pet({
 name = "cheeto",
 sprite = 8,
 rarity = 5,
 immortal = true
})
classfactory__pet({
 name = "yoomimmick",
 sprite = 12,
 rarity = 4
})
classfactory__pet({
 name = "squirrel",
 sprite = 14,
 rarity = 2,
 color_variants = {
  { [6] = 9, [5] = 4 }
 }
})
classfactory__pet({
 name = "turkey",
 sprite = 38,
 rarity = 2
})
classfactory__pet({
 name = "owl",
 sprite = 40,
 rarity = 3
})
classfactory__pet({
 name = "horse",
 sprite = 42,
 rarity = 4,
 color_variants = {
  { [4] = 5, [5] = 4, [1] = 0 },
  { [4] = 6, [6] = 7, [1] = 5 }
 }
})

-- map integer pet.id to bool
discovered_pets = {}
for i = 1, num_pet_types do
 local pet = all_pets[i]
 if pet then
  discovered_pets[i] = false
  add(loot_tables[pet.rarity].pool, pet)
 end
end

all_items = {
 { sprite = 32, rarity = 1, name = "chocolate" },
 { sprite = 33, rarity = 1, name = "banana" },
 { sprite = 34, rarity = 2, name = "meatball" },
 { sprite = 35, rarity = 3, name = "rice" },
 { sprite = 36, rarity = 2, name = "drumstick" },
 { sprite = 51, rarity = 3, name = "bomb" }
}
num_item_types = 16

inventory = {}
for i = 1, num_item_types do
 local item = all_items[i]
 if item then
  all_items[i].id = i
  inventory[i] = 0
  add(loot_tables[item.rarity].pool, item)
 end
end
max_item_stack = 0xff

discovered_pets[all_pets[1].id] = true
pets = {
 all_pets[1].new():set_color()
}
--1 based counting to access pet table
current_pet = 1
max_pets = 16

-- MARK: save data

function load_data()
 -- username_title_version
 if not cartdata("real-fancy-fire_tama-gatcha_1-3") then
  return false
 end

 local addr = 0x5e00

 -- user data
 settings.mute, settings.grim = unpack(decode_bitfield(peek(addr), 8))
 addr += 1

 -- discovered pets
 discovered_pets = decode_bitfield(peek2(addr), num_pet_types)
 addr += 2

 -- food
 food = peek(addr)
 addr += 1

 -- items
 for i = 1, num_item_types do
  inventory[i] = peek(addr)
  addr += 1
 end

 -- pets
 for i = 1, max_pets do
  local id, color_variant, hunger, happiness = peek(addr, 4)
  if all_pets[id] then
   local pet = all_pets[id].new()
   pet.color_variant = color_variant
   pet.hunger = hunger
   pet.happiness = happiness
   pets[i] = pet
  end
  addr += 4
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
 poke2(addr, encode_bitfield(discovered_pets))
 addr += 2

 -- food
 poke(addr, food)
 addr += 1

 -- items
 for i = 1, num_item_types do
  poke(addr, inventory[i])
  addr += 1
 end

 -- pets
 for i = 1, max_pets do
  local pet = pets[i]

  if pet then
   poke(addr, pet.id, pet.color_variant, pet.hunger, pet.happiness)
  else
   poke(addr, 0, 0, 0, 0)
  end

  addr += 4
 end

 printh("data saved")
end

-->8
-- MARK: screens
class__gridmenu = classfactory({ selection = 1, selectables = {} })
function class__gridmenu:init()
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
 local cloud = vec2_0
 function background_house()
  if cloud.x > 53 then
   cloud = vec2.rng(0, 15, nil, 40)
  end

  --house
  fillp(█)
  rectfill(0, 0, 128, 70, 15)

  --window
  rectfill(20, 15, 56, 50, 12)
  rect(20, 15, 56, 50, 7)
  rect(19, 14, 57, 51, 7)
  --add clouds here
  clip(21, 15, 35, 35)
  sspr(112, 16, 16, 16, cloud.x, cloud.y, 16, 16)
  clip()
  --middle
  line(38, 15, 38, 50, 7)
  line(37, 15, 37, 50, 7)

  --floor
  rectfill(0, 70, 128, 128, 4)
  rectfill(0, 70, 128, 65, 7)
  for i = 0, 40 do
   line(i * 10, 71, i * 10 - 20, 127, 9)
  end
 end
end

-- MARK: home
do
 screens.home = classfactory__gridmenu({
  x = 4, y = 3, dx = 28, dy = 114, w = 5, h = 2,
  selectables = {
   { name = "food", sprite = 1 },
   { name = "game", sprite = 2, screen = "game_select" },
   { name = "stats", sprite = 3, screen = "stats" },
   { name = "gacha", sprite = 4, screen = "gacha" },
   { name = "settings", sprite = 5, screen = "settings" },

   { name = "snacks", sprite = 17, screen = "snacks" },
   { name = "left", sprite = 18 },
   { name = "right", sprite = 19 },
   { name = "pets", sprite = 20, screen = "collection" },
   { name = "adopt", sprite = 21, screen = "loose_pet" }
  }
 })
 local _ENV, scn = rescope(screens.home, _ENV)
 function update()
  local _, icon = update_sel(scn)
  glide(scn)

  if btnp(❎) then
   --disallows feeding or playing after death to prevent revives
   if pets[current_pet]:is_dead() and (icon.name == "food" or icon.name == "game") then
    return
   end

   if icon.screen then
    switch_screen(screens[icon.screen])
   end

   if icon.name == "food" then
    feed_pet()
   elseif icon.name == "left" then
    current_pet = mod(current_pet - 1, #pets)
   elseif icon.name == "right" then
    current_pet = mod(current_pet + 1, #pets)
   end
  end
 end
 function draw()
  background_house()
  local pet = pets[current_pet]

  for i, icon in ipairs(selectables) do
   local x, y = grid_vec(scn, i):unpack()
   spr(icon.sprite, x, y)
   if i == selection then
    print_centered(icon.name, 64, 110, 7)
   end
  end

  --stats icon reflecting pet status
  -- fillp(█)
  local hunger_x = pet.hunger / 15 * 6
  local happy_x = pet.happiness / 15 * 6
  if hunger_x > 1 then
   rectfill(61, 4, 60 + hunger_x, 4, hunger_x > 3 and 11 or 8)
  end
  if happy_x > 1 then
   rectfill(61, 6, 60 + happy_x, 6, happy_x > 3 and 11 or 8)
  end

  --print food counter
  print(food, 3, 13, 7)

  --draw current pet
  -- fillp(★)
  -- circfill(64, 64, 44, 3)
  print_centered(pet.name, 64, 20, 7)
  if pet:is_dead() then
   spr_scaled(50, 52, 62, 4)
  else
   pet:spr_scaled(32, 32, 4)
  end

  --draw number of pets and current pet indicator
  pal()
  -- fillp(█)
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

-- MARK: stats
do
 screens.stats = {}
 local _ENV, scn = rescope(screens.stats, _ENV)
 function update()
  if btnp(🅾️) then
   switch_screen()
  end
 end
 function draw()
  local pet = pets[current_pet]
  print(pet.name, 20, 40, 7)
  fillp(█)
  --hunger bar
  print("hunger", 20, 52, 7)
  rectfill(20, 60, 108, 65, 5)
  rectfill(20, 60, 20 + 5.87 * pet.hunger, 65, 11)
  --happy bar
  print("happiness", 20, 72, 7)
  rectfill(20, 80, 108, 85, 5)
  rectfill(20, 80, 20 + 5.87 * pet.happiness, 85, 11)
 end
end

-- MARK: settings
do
 screens.settings = {
  selection = 1,
  options = {
   -- not called 'settings' to reduce confusion
   { name = "sound", key = "mute" },
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
  end
 end
 function draw()
  for i, option in ipairs(options) do
   local y = 20 + (i - 1) * 40
   local setting = settings[option.key]

   print_centered(option.name, 64, y, i == selection and 10 or 7)
   draw_checkbox(45, y + 14, setting)
  end

  spr_scaled(16, 62, 30, 2, 1, 1)
  if settings.mute then
   color(8)
   line(75, 35, 81, 41)
   line(75, 41, 81, 35)
  else
   line(76, 35, 76, 41)
   line(79, 32, 79, 44)
  end

  if settings.grim then
   pal(6, 8)
   print("✽", 67, 81, 8)
   print("★", 71, 78, 2)
   spr_scaled(50, 64, 70, 2, 1, 1)
   pal()
  else
   spr_scaled(50, 64, 70, 2, 1, 1)
  end

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
  update_sel(scn)
  glide(scn)

  if btnp(🅾️) then
   switch_screen()
  elseif btnp(❎) then
   if inventory[selection] > 0 then
    inventory[selection] -= 1
    --give pet status or ailment
   else
    -- play error sound
   end
  end
 end
 function draw()
  for i, prefab in ipairs(selectables) do
   local amount = inventory[i]
   local sx, sy = grid_vec(scn, i):unpack()

   spr_scaled(prefab.sprite, sx, sy, 3)

   print_centered(amount, sx - 5, sy, 7)
   if i == selection then
    print_centered(prefab.name, 64, 100, 7)
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
   local sx, sy = grid_vec(scn, i):unpack()
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
 function with(self, pet_)
  pet = pet_
  return self
 end
 function init()
  local pet = pet or deli(pets, current_pet)
  local target = decide(pet)
  if (target) target.pet = pet
  switch_screen(target)
  pet = nil
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
  load_music("pet_loss", true)
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
    if p.pos.x < 49 and rnd() < 0.5 then
     p:stop()
    end
    p:update()
   end

   if step == 6 then
    load_music("pet_loss")
   elseif step == 7 then
    if btnp(🅾️) then
     pet = nil
     switch_screen()
     return
    end
   end
  end
 end
 function draw()
  cls(12)
  local step, t = timeline:get()

  if step == 1 then
   rectfill(0, 64, 64, 128, 5)
   pet:spr_scaled(48, 50, 1, false, true, false)
   rectfill(0, 62, 66, 70, 6)
  elseif step == 2 then
   rectfill(0, 64, 64, 128, 5)
   pet:spr_scaled(
    accelerp(48, 50, -25, t),
    accelerp(50, -50, 200, t),
    1, false, true, false
   )
   rectfill(0, 62, 66, 70, 6)
  elseif step == 3 then
   rectfill(0, 0, 64, 128, 5)
   for i = -1, 5 do
    for x = 8, 48, 32 do
     local y = (t % 0.15) / 0.15 * -48 + i * 48
     rectfill(x, y, x + 16, y + 24, 0)
    end
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

   -- grass
   rectfill(0, 90, 127, 127, 3)
   -- building
   rectfill(0, 0, 48, 127, 5)
   for y = 80, 0, -48 do
    rectfill(1, y, 17, y - 24, 0)
   end
   -- road
   rectfill(0, 96, 127, 127, 0)
   if step >= 5 then
    draw_particles()
   end

   if step >= 6 then
    print_centered(pet.name .. " was sad.", 90, 48, 7)
   end
   if step == 7 then
    print_centered("🅾️ exit", 64, 110, 5)
   end
  end
 end
 function draw_particles()
  for particle in all(gore_pool) do
   pset(particle.pos.x, particle.pos.y, 8)
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
  load_music("pet_loss", true)
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
    add_particles(pet.bone, 66)
   end
   update_particles()
  elseif step == 6 then
   load_music("pet_loss")
   if btnp(🅾️) then
    pet = nil
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
  spr_scaled(64, x, y, 1, 2, 3)
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
  spr(66, 0, 8)
  print(bones, 10, 10, 9)

  print("⬆️", 8, 48, 9)
  print(pad(rolls) .. "   rolls")
  print("⬇️")

  print("⬅️" .. pad(bonus) .. "➡️ bones", 0, 80)

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
   add(pets, prize)
   discovered_pets[prize.id] = true
  else
   inventory[prize.id] += 1
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

screens.minigame = {
 current_game = nil
}
function screens.minigame:init()
 if self.current_game then
  self.current_game:init()
 end
end
function screens.minigame:update()
 if self.current_game then
  self.current_game:update()
 end
end
function screens.minigame:draw()
 if self.current_game then
  self.current_game:draw()
 end
end
function screens.minigame:finish_game()
 if not self.current_game then return switch_screen() end
 local reward = self.current_game.reward or {}

 gacha_tickets += reward.gacha_tickets or 0
 food += reward.food or 3
 pets[current_pet]:change_happiness(reward.happiness or 0)

 self.current_game = nil

 switch_screen()
end
games = {}

games.math = {
 reward = {
  gacha_tickets = 2,
  food = 0,
  happiness = 15
 },

 operation_keys = { "+", "-", "*" },
 operations = {
  ["+"] = function(a, b) return a + b end,
  ["-"] = function(a, b) return a - b end,
  ["*"] = function(a, b) return a * b end
 },

 progress = 0,
 question_str = "",
 options = {},
 answer = 1
}
function games.math:init()
 self.progress = 0
 self:setup_question()
end
function games.math:setup_question()
 local a, b = flr(rnd(10)), flr(rnd(10))
 local op_key = rnd(self.operation_keys)

 local ans = self.operations[op_key](a, b)
 self.question_str = a .. op_key .. b

 self.options = {}

 --make sure no overlap answers
 local option_set = { [ans] = true }
 while #self.options < 3 do
  local new = ans + flr(rnd(6)) - 2
  if not option_set[new] then
   option_set[new] = true
   add(self.options, new)
  end
 end

 self.answer = flr(rnd(4))
 add(self.options, ans, self.answer + 1)
end
function games.math:update()
 if btnp(self.answer) then
  self.progress += 1

  if self.progress == 5 then
   screens.minigame:finish_game()
   return
  end

  self:setup_question()
 elseif btnp(0) or btnp(1) or btnp(2) or btnp(3) then
  self.progress = mid(0, self.progress - 1, 5)
  self:setup_question()
 end
end
function games.math:draw()
 print(self.progress .. "/5", 110, 3, 7)

 print_centered(self.question_str, 64, 61)

 print_centered(self.options[1], 34, 61)
 draw_triangle(22, 63, 40, 77, 40, 49)

 print_centered(self.options[2], 94, 61)
 draw_triangle(104, 63, 86, 77, 86, 49)

 print_centered(self.options[3], 64, 31)
 draw_triangle(63, 104, 77, 86, 49, 86)

 print_centered(self.options[4], 64, 91)
 draw_triangle(63, 22, 77, 40, 49, 40)
end

games.fishing = {
 reward = nil,
 reward_win = {
  gacha_tickets = 1,
  food = 3,
  happiness = 15
 }
}
function games.fishing:init()
 local _ENV = rescope(self, _ENV)

 fish_x = 50
 --ui ranges from 20 to 108

 escape_ui_x = 64
 new_esc_ui_x = 64

 user_ui_x = 21

 last⧗ = time()
 fish⧗ = time()
end

function games.fishing:update()
 local _ENV = rescope(self, _ENV)

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
   reward = self.reward_win
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

function games.fishing:draw()
 local _ENV = rescope(self, _ENV)

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

__gfx__
000000000000000000000000000000000000000000067000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb050bbbbbbbbbbbbb020bbbbbbbbbbbbbbbbbbbbbb66bb
000000000000990005677650077777700999408007577670bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb05bbbbbb0000bbbb52bbbbbb0000bbbbbbbbbbb666666
007007000009979007777770000000000777705006777750bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0999bbb4aaa550bb0eeebbb5fff220b6bb5bbbb6666556
000770000099994007877570077777700777705077700776bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb499aa44aa00bbbbb4eeff55ff00bbbbb666bbbb6665555
000770000069440007777770000000000944455067700777bb3333bbbbbbbbbbb9bbbbb9bbbbbbbbbbb4aaaaaa0bbbb0bbb57ff7ff0bbbbbb60766bbb6665bb5
0070070006750000067557600bbbb0000444400005777760bb33303bbbbbbbbbb99bbb99bbbbbbbbbb4a0aa0aaa4bb04bb5f2ff2fff5bbbb660066bbb666bbbb
000000000700000000600600000000000444400007677570b999333bbbbbbbbbb9999999bbbbbbbbbb49aaaa99a0b444bb4effffeef0bbbbf66666bbb6666bbb
000000000000000000000000000000000000000000076000b999333bbbbbbb7bb9099099bbb9bbbbbb40a0a099a0b440bb42f2f2eef0bbbbb6666566bb6665bb
000077000000000000000000000000000000000000000000bb33333bbbbb777bb9999999bbb999bbbbb40a0aaa0b440bbbb42f2fff0bbbbbbb5556666b66665b
0007770000600000000700000000700007007000000d1000bb3333444444477bb99999999bbbb99bbbbb4aaaa0b44bbbbbbb4ffff0bbbbbbbbbd666666b6655b
77777700066e700000770000000077000777700000d11100bb4444444444444bbb9979999bbbbb9bbbbbb4aa0bb044bbbbbbb4ff0bbbbbbbbb5dd56666bb655b
7777770000eeee000777777777777770067760600dd11110bb444444999444bbbb977794499bbb9bbbbb40a0a4bb0440bbbb45f5f4bbbbbbbbbd566666b655bb
77777700002eee0077777777777777770077006000655500bb444499944444bbbb777794999bb99bbbb4a0a0aa00440bbbb4f5f5ff0bbbbbbbbbd66666655bbb
777777000002266007777777777777700077707000655500bbbb44444444bbbbbb777799999b99bbbbb0aaaaa9900bbbbbb0fffffee0bbbbbbbb6666655bbbbb
000777000000060000770000000077000076770000655500bbbbbbbbbbbbbbbbb9777949999999bbbb4909099090bbbbbb5e0e0ee0e0bbbbbb55bb666bbbbbbb
000077000000000000070000000070000000000000000000bbbbbbbbbbbbbbbbb977949999999bbbbb00000000000bbbbb00d0d00d000bbbbbbbb55bbbbbbbbb
00004400077000000000000000767700000044000000a000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
004444400767000000f87f000677776000444440000a9a00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4bb4bbbbbbbbbb00000000000000000000000000000000
04444444076700000f88fff0777767760444444400a999a0bbbbbbbbbbbbbbbbbbb44bbbbbb44bbbbbb114bbbbbbbbbb00000000000000000000000000000000
11664444007670000ffff87076777777044444450a99a99abbbbbbbbbbbbbbbbbbb44bbbbbb44bbbbb17111bbbbbbbbb00000000000000000000000000000000
1116664400aaaaa008fff8806776776708844445a9a999a0bbbbbbbb44444bbbbbb4444444444bbbbb40411bbbbbbbbb00000000000000000000000000000000
111116660a99aa0a0f78ff7015555551078844500a9a9a00bbbbbb4994444bbbbbb4444444444bbbb644e111bbbbbbbb00000000000000000000000000000000
011111060909aaa00088ff00115555117768550000a9a000bb44bb499449944bbbb4444444444bbb74444111bb444bbb00000000000000000000000000000000
00110000000099aa000000000111111066000000000a0000bb044b449499444bbbb4004440044bbbb5411411144444bb00000000000000000000000000000000
000770000007700000777700000006608888888888888888b8444b44999444bbbbb4444444444bbbbbb11411414444bb00000000000000000000000000000000
007777000078870007777770000060a88888a8888a888888b8b99444994499bbbbb4449994444bbbbbbb14414444441b00000000000000000000000000000000
00777700077228700556557000756588888aaa8888888888bbb9994449994bbbbbb4449994444bbbbbb1b4441444441100000000000000000000000000000000
077777700788776005575560075555508aaaaaaa88a88888bbb999999994bbbbbbb4444944444bbbbbbb44b44bb4b44100000000000000000000000000000000
0777777007777660076577607555555588aaaaa888888888bbb4444444bbbbbbbbb444444444bbbbbbbb4bb4bbb6bb4100000000000000000000000000000000
07777770077766600677760075555555888aaa8888a88888bbbbb4444bbbbbbbbbbb44bbbb4bbbbbbbbb7bb4bbb5bb7b00000000000000000000000000000000
0777777007776660056565000755555088aa8aa888888888bbbbbb4bbbbbbbbbbbbbb4bbbb4bbbbbbbbbb5b7bbbbbb5b00000000000000000000000000000000
007777000077660000000000005555008aa888aa8a888888bbbbb444bbbbbbbbbbbb444bb444bbbbbbbbbbb5bbbbbbbb00000000000000000000000000000000
77777777777777770000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76666666666666670000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76766666666666670000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76766666666666670007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b76766666666667b0077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b76766666666667b7777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b76666666666667b7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b76666666666667b0770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb766666666667bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb766666666667bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb766666666667bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb766666666667bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb7666666667bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb7666666667bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb7666666667bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb7777777777bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb1111111111bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb1111111011bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb110111100011bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb111101110111bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb111111111111bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b11111111111111b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b11111111111111b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b11111111111111b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
