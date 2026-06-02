pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
#include includes/helper_functions.p8.lua
#include includes/asset_loader.p8.lua
#include includes/byte_streamer.p8.lua

for i = 0, 3 do
 asset_loader.sfx_allocation[i] = true
end
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

-->8
-- MARK: structs

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
#include includes/class__pet.p8.lua

-- map integer pet.id to bool
-- local discovered_pets = {}
for i = 1, 0xff do
 local pet = all_pets[i]
 -- discovered_pets[i] = false
 if pet then
  add(loot_tables[pet.rarity].pool, pet)
 end
end

-- MARK: item
all_items = {
 { sprite = 32, rarity = 1, name = "chocolate", func = function(pet) pet.effects.happiness_prot = 60 end },
 { sprite = 33, rarity = 1, name = "banana", func = function(pet) pet.effects.happiness_2x = 60 end },
 { sprite = 34, rarity = 2, name = "meatball", func = function(pet) pet.effects.hunger_2x = 60 end },
 {
  sprite = 35, rarity = 3, name = "rice", func = function()
   play_music("china", true)
  end
 },
 { sprite = 36, rarity = 2, name = "drumstick", func = function(pet) pet.effects.hunger_prot = 60 end },
 {
  sprite = 51, rarity = 3, name = "bomb", func = function(pet, pets)
   switch_screen(screens.loose_pet:with(del(pets, pet), screens.bomb))
  end
 }
}

-->8
-- MARK: main loop
#include includes/data.p8.lua
pets:add(all_pets[1].new():set_color())

for i, item in ipairs(all_items) do
 item.id = i
 add(loot_tables[item.rarity].pool, item)
 function item.count(delta)
  local count = inventory[i]
  if (count) inventory[i] = mid(count + (delta or 0), 0, 0xff)
  return inventory[i]
 end
end

-- wrapper for playing music with respect to mute
function play_music(key, force)
 if not settings.mute or not key then
  asset_loader.play_music(key, force)
 end
end

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

local dt, t = 0, time()

function _init()
 load_data()
 switch_screen()
end

function _update()
 dt, t = time() - t, time()

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
  load_music = { "jumping_machine" },
  load_map = { "house" },
  shift = 0
 })
 local _ENV, scn = rescope(screens.home, _ENV)
 camera_glider = glider.new(0.5)
 function update()
  current_pet = mid(current_pet, 1, #pets)
  local pet = pets[current_pet]
  if (pet) play_music("jumping_machine")
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
     sfx(0)
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
    pet:spr_scaled("hd", 32, 32, 2, false, shift > 0)
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
   { name = "maze", key = "maze" },
   { name = "fishing", key = "fishing" },
   { name = "you shouldn't see this", key = nil }
  }
 })
 local _ENV, scn = rescope(screens.game_select, _ENV)
 function update()
  local _, game = update_sel(scn)
  glide(scn)

  -- MARK: ToDo: whatever this is
  local game4 = selectables[4]
  if settings.grim then
   -- game4.name = grim_progress .. "/3"
   game4.name = "secret"
   game4.key = "secret"
   game4.col = nil
  else
   game4.name = "tbd"
   game4.key = nil
   game4.col = 5
  end

  if btnp(🅾️) then
   switch_screen()
  elseif btnp(❎) then
   if game.key then
    load("minigames/" .. game.key .. ".p8", "exit", game.key)
   end
  end
 end
 function screens.game_select:draw()
  fillp(█)
  for i, game in ipairs(selectables) do
   local x, y = grid_vec(scn, i):unpack()

   draw_panel(game.name, x, y, 52, 52, game.col or 3)
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
   { name = "mute music", key = "mute" },
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
    play_music()
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
   if item.count() > 0 then
    item.count(-1)
    item.func(pets[current_pet], pets)
   else
    sfx(0)
   end
  end
 end
 function draw()
  for i, item in ipairs(selectables) do
   local amount = item.count()
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

   -- if discovered_pets[pet_cls.id] then
   --  pet_cls:spr_scaled(sx, sy, 1)
   -- else
   --  pet_cls:pal(true)
   --  pet_cls:spr_scaled(sx, sy, 1, true)
   --  name = "???"
   -- end

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
  play_music()
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

  pet:spr_scaled("thumbnail", x, 44, 2, false, true, false)
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
    play_music("baka_mitai")
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
   pet:spr_scaled("thumbnail", x, y, 1, false, true, false)
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
    "thumbnail",
    88,
    accelerp(32, 32, 0, t),
    1, false, true, false
   )
  elseif step >= 4 then
   if step == 4 then
    y4 = accelerp(-128, 256 * 4, 0, t)
    pet:spr_scaled("thumbnail", 80, y4, 1, false, true, false)
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
   sfx(2)
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
   pet:spr_scaled("thumbnail", 56, accelerp(-16, 20, 100, t))
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
  explodes = settings.grim and not pet.immortal
 end
 function update()
  local step, t = timeline:update()

  if step > 2 then
   if explodes and not splash then
    splash = true
    sfx(3)
    add_particles(1000)
    add_particles(pet.bone * 2, 54)
   end
   update_particles()
  end

  if step == 3 and t > 5 then
   play_music("baka_mitai")
   if btnp(🅾️) then
    switch_screen()
   end
  end
 end
 function draw()
  local step, t = timeline:get()

  if step == 1 then
   pet:spr_scaled("thumbnail", 64, 56)
   spr(51, accelerp(-8, 64, -32, t), 64)
  elseif step == 2 then
   pet:spr_scaled("thumbnail", 64, 56)
   spr(51, 56, 64)
  elseif step == 3 then
   if explodes then
    draw_particles()
   else
    spr(51, 56, 64)
    pet:spr_scaled("thumbnail", accelerp(64, 32, 0, t), 56, 1, nil, true)
   end
   if t > 3 then
    print_centered(pet.name .. " did not like that.", 64, 80, 7)
   end
   if t > 5 then
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
   prize:spr_scaled("thumbnail", x, y, size / 2)
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
   prize.count(1)
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
__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffaaaaaaaaaafffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffaffffffffaffffffffffffffffffffffffffffffffffffffffffffffff77ff77ffffffffffffffffffffffffffffffffffffffffffffffffffff67fffffff
fffaffff99ffaffffffffffffffffffff567765ffffffffffffffffffffff77ff77ffffffffffffffffffffff9994f8ffffffffffffffffffffff757767fffff
fffafff9979faffffffffffffffffffff777777ffffffffffffffffffffff77ff77ffffffffffffffffffffff7777f5ffffffffffffffffffffff677775fffff
fffaff99994faffffffffffffffffffff787757ffffffffffffffffffffff77ff77ffffffffffffffffffffff7777f5fffffffffffffffffffff777ff776ffff
fffaff6944ffaffffffffffffffffffff777777ffffffffffffffffffffff77ff77ffffffffffffffffffffff944455fffffffffffffffffffff677ff777ffff
fffaf675ffffaffffffffffffffffffff675576ffffffffffffffffffffff77ff77ffffffffffffffffffffff4444ffffffffffffffffffffffff577776fffff
fffaf7ffffffafffffffffffffffffffff6ff6fffffffffffffffffffffff77ff77ffffffffffffffffffffff4444ffffffffffffffffffffffff767757fffff
fffaffffffffaffffffffffffffffffffffffffffffffffffffffffffffffbbffbbffffffffffffffffffffffffffffffffffffffffffffffffffff76fffffff
fffaaaaaaaaaafffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fff77ff77ff777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffff7fff7ff7f7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffff7fff7ff777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffff7fff7ffff7ff7777777777777777777777777777777777777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fff777f777fff7ff7777777777777777777777777777777777777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77cccccccccccccccc0070f0f000f000f000ff00fffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccc0c770f0f0fff0ffff0ff0f0fffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccc0c77000f00ff00fff0ff0f0fffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccc0c770f0f0fff0ffff0ff0f0fffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77cccccccccccccccc0070f0f000f000ff0ff00ffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff7766ccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc77ccccccccccccccccc77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc79999cccccccccccccc77ffff9999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc79999cccccccccccccc77ffff9999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc79999cccccccccccccc77ffff9999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc79999cccccccccccccc77ffff9999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc799999999cccccccccc7799999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff77ccccccccccccccccc799999999cccccccccc7799999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff777777777777777777779999999977777777777799999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff777777777777777777779999999977777777777799999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999999999999999999999999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999999999999999999999999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999999999999999999999999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999999999999999999999999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999000099999999000099999999ffffffffffff9999ffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999000099999999000099999999ffffffffffff9999ffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999000099999999000099999999ffffffffffff9999ffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999000099999999000099999999ffffffffffff9999ffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999999999999999999999999999ffffffffffff999999999999ffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999999999999999999999999999ffffffffffff999999999999ffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffff9999999999999999999999999999ffffffffffff999999999999ffffffffffffffffffffffffffffffffffffffff
77777777777777777777777777777777777799999999999999999999999999997777777777779999999999997777777777777777777777777777777777777777
77777777777777777777777777777777777799999999999999999999999999999999777777777777777799999999777777777777777777777777777777777777
77777777777777777777777777777777777799999999999999999999999999999999777777777777777799999999777777777777777777777777777777777777
77777777777777777777777777777777777799999999999999999999999999999999777777777777777799999999777777777777777777777777777777777777
77777777777777777777777777777777777799999999999999999999999999999999777777777777777799999999777777777777777777777777777777777777
44444449444444494444444944444449444444499999999977779999999999999999111111114449444444499999444944444449444444494444444944444449
44444449444444494444444944444449444444499999999977779999999999999999dddddddd1111111114499999444944444449444444494444444944444449
44444449444444494444444944444449444444419999999977779999999999999999ddddddddddddddddd1119999444944444449444444494444444944444449
444444944444449444444494444444944441111d9999999977779999999999999999dddddddddddddddddddd9999119444444494444444944444449444444494
44444494444444944444449444444491111ddddd999977777777777799994444444499999999dddddddddddd9999dd1111444494444444944444449444444494
4444449444444494444444944444111ddddddddd999977777777777799994444444499999999dddddddddddd9999dddddd111494444444944444449444444494
4444494444444944444449444411dddddddddddd999977777777777799994444444499999999dddddddddddd9999ddddddddd114444449444444494444444944
44444944444449444444494411dddddddddddddd999977777777777799994444444499999999dddddddddddd9999ddddddddddd1144449444444494444444944
444449444444494444444911dddddddddddddddd777777777777777799994444999999999999dddddddd99999999ddddddddddddd11449444444494444444944
4444944444449444444491dddddddddddddddddd777777777777777799994444999999999999dddddddd99999999ddddddddddddddd194444444944444449444
444494444444944444411ddddddddddddddddddd777777777777777799994444999999999999dddddddd99999999dddddddddddddddd11444444944444449444
4444944444449444441ddddddddddddddddddddd777777777777777799994444999999999999dddddddd99999999dddddddddddddddddd144444944444449444
4449444444494444441ddddddddddddddddddddd777777777777777799999999999999999999dddd99999999dddddddddddddddddddddd144449444444494444
444944444449444441dddddddddddddddddddddd777777777777777799999999999999999999dddd99999999ddddddddddddddddddddddd14449444444494444
44494444444944441ddddddddddddddddddddddd777777777777777799999999999999999999dddd99999999dddddddddddddddddddddddd1449444444494444
44944444449444441ddddddddddddddddddddddd777777777777777799999999999999999999dddd99999999dddddddddddddddddddddddd1494444444944444
44944444449444441ddddddddddddddddddd9999777777777777999944449999999999999999999999999999dddddddddddddddddddddddd1494444444944444
44944444449444441ddddddddddddddddddd9999777777777777999944449999999999999999999999999999dddddddddddddddddddddddd1494444444944444
49444444494444441ddddddddddddddddddd9999777777777777999944449999999999999999999999999999dddddddddddddddddddddddd1944444449444444
494444444944444441dddddddddddddddddd9999777777777777999944449999999999999999999999999999ddddddddddddddddddddddd14944444449444444
4944444449444444491ddddddddddddddddd999977777777999944449999999999999999999999999999dddddddddddddddddddddddddd144944444449444444
9444444494444444941ddddddddddddddddd999977777777999944449999999999999999999999999999dddddddddddddddddddddddddd149444444494444444
944444449444444494411ddddddddddddddd999977777777999944449999999999999999999999999999dddddddddddddddddddddddd11449444444494444444
9444444494444444944441dddddddddddddd999977777777999944449999999999999999999999999999ddddddddddddddddddddddd144449444444494444444
444444494444444944444411ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd11444494444444944444449
44444449444444494444444911ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1144444494444444944444449
4444444944444449444444494411ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd119444444494444444944444449
4444449444444494444444944444111ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd111494444444944444449444444494
44444494444444944444449444444491111ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1111444494444444944444449444444494
444444944444449444444494444444944441111ddddddddddddddddddddddddddddddddddddddddddddddddddd11119444444494444444944444449444444494
44444944444449444444494444444944444449411111ddddddddddddddddddddddddddddddddddddddddd1111144494444444944444449444444494444444944
44444944444449444444494444444944444777444444111115551dddddddddd555dddddddddd1555111119444445554444444944444449444444494444444944
44444944444449444444494444444944447777744444494455555111111111555551111111115555544449444455555444444944444449444444494444444944
44449444444494444444944444449444447777744444944455555444444494555554944444445555544494444455555444449444444494444444944444449444
44449444444494444444944444449444447777744444944455555444444494555554944444445555544494444455555444449444444494444444944444449444
44449444444494444444944444449444444777444444944445559444444494455544944444449555444494444445554444449444444494444444944444449444
44494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444
44494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444
44494444444944444449444444494444444944444449444444494444777947744779774444494444444944444449444444494444444944444449444444494444
44944444449444444494444444944444449444444494444444944444749474747474747444944444449444444494444444944444449444444494444444944444
44944444449444444494444444944444449444444494444444944444779474747474747444944444449444444494444444944444449444444494444444944444
44944444449444444494444444944444449444444494444444944444749474747474747444944444449444444494444444944444449444444494444444944444
49444444494444444944444449444444494444444944444449444444794477447744777449444444494444444944444449444444494444444944444449444444
49444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444
49444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444
94444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444
94444464944444449444444494444444944744449444444494444444944444447444444494444444944444449744744494444444944444449444444d14444444
9444466e74444444944444449444444494774444944444449444444494444444774444449444444494444444977774449444444494444444944444d111444444
444444eeee44444944444449444444494777777744444449444444494444777777744449444444494444444946776469444444494444444944444dd111144449
4444442eee4444494444444944444449777777774444444944444449444477777777444944444449444444494477446944444449444444494444446555444449
44444442266444494444444944444449477777774444444944444449444477777774444944444449444444494477747944444449444444494444446555444449
44444494464444944444449444444494447744944444449444444494444444947744449444444494444444944476779444444494444444944444446555444494
44444494444444944444449444444494444744944444449444444494444444947444449444444494444444944444449444444494444444944444449444444494
44444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494
44444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944
44444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944444449444444494444444944

__sfx__
000600001e4502d4001e4502640015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000001a06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000276502f6503a6502f650336502c6503b650366503a6502c650236502f650386503865030650326503165039650236502a650266502d650386502d6502665032650236503a6502c6503a650326502e650
00040000396503d6503f6503e6503d6503f6503d6503e6503c6503b65038650306502b6502a6501f6501d6501a65019650176501665016650156501665015650176501465010650116500e650086500465000650
__music__
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344
00 42424344

