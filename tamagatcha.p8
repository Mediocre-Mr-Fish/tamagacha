pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- MARK: main loop
is_runtime = false
function _init()
 is_runtime = true
 tokens = 10
 food = 1
 --multiplier for too many pets
 --equation in get_penalty_mult
 swarm_penalty = 0.1
 --baseline of when to decrease vars (sec)
 hunger_tick = 5
 happiness_tick = 7

 last_fed = time()
 last_play = time()
 --general use timer
 t = time()

 icons = {
  { name = "food", x = 3, y = 3, sprite = 1 },
  { name = "game", x = 31, y = 3, sprite = 2 },
  { name = "stats", x = 60, y = 3, sprite = 3 },
  { name = "gacha", x = 89, y = 3, sprite = 4 },
  { name = "setting", x = 117, y = 3, sprite = 5 },

  { name = "snack", x = 3, y = 117, sprite = 17 },
  { name = "left", x = 31, y = 117, sprite = 18 },
  { name = "right", x = 60, y = 117, sprite = 19 },
  { name = "pets", x = 89, y = 117, sprite = 20 },
  { name = "adopt", x = 117, y = 117, sprite = 21 }
 }
 current_icon = 1
 screen = 0
 --allows for the use of clamp function
 clamp = mid

 --optional turn sound off
 mute = false
 --optionally reveal the blender heh
 grim = false
 --progress of minigames
 grim_progress = 0
end

function _update()
 update_hunger()
 update_happiness()

 if btnp(🅾️) and screen != 10 then
  switch_screen(0)
 end

 if screen == 0 then
  screens.home.update()
 elseif screen == 1 then
  --game
  screens.game_select.update()
 elseif screen == 2 then
  --stats
 elseif screen == 3 then
  --gacha
  screens.gacha.update()
 elseif screen == 4 then
  --setting
  screens.settings.update()
 elseif screen == 5 then
  --snack
  screens.snacks.update()
 elseif screen == 8 then
  --pet collection
  screens.collection.update()
 elseif screen == 9 then
  --adoption
 elseif screen == 10 then
  --gacha animation
  screens.gacha_anim.update()
 elseif screen == 11 then
  --game 1 math
  update_math_game()
 elseif screen == 12 then
  --game 2 maze
 elseif screen == 13 then
  --game 3 idk
 elseif screen == 14 then
  --game 4 in progress
 end
end

function _draw()
 cls()
 if screen == 0 then
  screens.home.draw()
 elseif screen == 1 then
  --game
  screens.game_select.draw()
 elseif screen == 2 then
  --stats
  screens.stats.draw()
 elseif screen == 3 then
  --gacha
  screens.gacha.draw()
 elseif screen == 4 then
  --setting
  screens.settings.draw()
 elseif screen == 5 then
  --snack
  screens.snacks.draw()
 elseif screen == 8 then
  --pet collection
  screens.collection.draw()
 elseif screen == 9 then
  --adoption
  screens.adoption.draw()
 elseif screen == 10 then
  --gacha animation
  screens.gacha_anim.draw()
 elseif screen == 11 then
  --game 1 math
  draw_math_game()
 elseif screen == 12 then
  --game 2 maze
 elseif screen == 13 then
  --game 3 idk
 elseif screen == 14 then
  --game 4 in progress
 end
end

function switch_screen(new)
 current_icon = screen + 1
 if screen >= 10 then
  --takes into account game screens
  --and animation screens
  current_icon = 1
  --init game 1
 end
 if new == 11 then
  setup_question()
  current_icon = 0
 end
 screen = new
end

-->8
-- MARK: helper functions

function mod(a, b)
 return (a - 1) % b + 1
end

function btnp_axis(neg, pos)
 if (btnp(neg) ~= btnp(pos)) return btnp(pos) and 1 or -1
 return 0
end

function grid_wrap(val, dx, dy, width, height)
 row = ((val - 1) \ width + dy) % height
 col = ((val - 1) % width + dx) % width
 return row * width + col + 1
end

function spr_scaled(n, x, y, scale, sw, sh)
 scale = scale or 1
 sw, sh = (sw or 1) * 8, (sh or 1) * 8
 sspr(n % 16 * 8, n \ 16 * 8, sw, sh, x, y, sw * scale, sh * scale)
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
  add(ret, integer & 1, 0)
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

function get_penalty_mult()
 return #pets * swarm_penalty + 1
end

function update_hunger()
 if time() - last_fed > hunger_tick / get_penalty_mult() then
  last_fed = time()
  --do this for all pets later
  for pet in all(pets) do
   pet.hunger = max(pet.hunger - 1, 0)
  end
 end
end

function update_happiness()
 if time() - last_play > happiness_tick / get_penalty_mult() then
  last_play = time()
  --do this for all pets later
  for pet in all(pets) do
   pet.happiness = max(pet.happiness - 1, 0)
  end
 end
end

function add_hunger()
 if (food == 0) return
 pets[current_pet].hunger = min(pets[current_pet].hunger + 2, 15)
 food -= 1
end

function add_happiness()
 pets[current_pet].happiness = min(pets[current_pet].happiness + 2, 15)
end

function is_dead(pet)
 return not pet.immortal and pet.hunger == 0 and pet.happiness == 0
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

all_pets = {}
num_pet_types = 15
function classfactory__pet(static_vars, parent)
 static_vars.id = #all_pets + 1
 assert(static_vars.id <= num_pet_types, "too many pet types!")
 return classfactory(static_vars, parent or class__pet, all_pets)
end

class__pet = classfactory({
 name = "default",
 immortal = false,
 sprite = 0,
 sprite_width = 2,
 sprite_height = 2,
 transparent = 11, --lime
 color_variants = {}
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
function class__pet:spr_scaled(x, y, scale, no_pal)
 if not no_pal then self:pal() end

 if not scale or scale == 1 then
  spr(self.sprite, x, y, self.sprite_width, self.sprite_height)
 else
  spr_scaled(self.sprite, x, y, scale, self.sprite_width, self.sprite_height)
 end

 pal()
end

pet_duck = classfactory__pet({ name = "arb duck", sprite = 6 })
pet_cheeto = classfactory__pet({ name = "cheeto", immortal = true, sprite = 8 })
pet_mimikyu = classfactory__pet({ name = "mimikyu", sprite = 10 })
pet_not_mimikyu = classfactory__pet({ name = "not mimikyu", sprite = 12 })
pet_squirrel = classfactory__pet({
 name = "squirrel", sprite = 14, color_variants = {
  { [6] = 9, [5] = 4 }
 }
})
pet_turkey = classfactory__pet({ name = "turkey", sprite = 38 })
pet_owl = classfactory__pet({ name = "owl", sprite = 40 })

-- map integer pet.id to bool
discovered_pets = {}
for i = 1, num_pet_types do
 local pet = all_pets[i]
 if (pet) discovered_pets[i] = false
end

discovered_pets[pet_duck.id] = true

all_items = {
 { sprite = 32 },
 { sprite = 33 },
 { sprite = 34 },
 { sprite = 35 },
 { sprite = 36 },
 { sprite = 51 }
}
num_item_types = 16

inventory = {}
for i = 1, num_item_types do
 local item = all_items[i]
 if item then
  all_items[i].id = i
  inventory[i] = 0
 end
end
max_item_stack = 0xff

pets = {
 pet_duck.new()
 --pet_squirrel.new():set_color()
}
--1 based counting to access pet table
current_pet = 1
max_pets = 16

-- MARK: save data

-- username_title_version
cartdata("real-fancy-fire_tama-gatcha_1-0")
function load_data()
 local addr = 0x5e00

 -- user data
 mute, grim, _, _ = decode_bitfield(peek(addr), 4)
 addr += 1

 -- discovered pets
 discovered_pets = decode_bitfield(peek(addr), num_pet_types)
 addr += 4

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

 -- items
 for i = 1, num_item_types do
  inventory[i] = peek2(addr)
  addr += 2
 end
end

function save_data()
 local addr = 0x5e00

 -- user settings
 poke(
  addr, encode_bitfield({
   mute, grim, false, false,
   false, false, false, false
  })
 )
 addr += 1

 -- discovered pets
 poke4(addr, encode_bitfield(discovered_pets))
 addr += 2

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

 -- items
 for i = 1, num_item_types do
  poke2(addr, inventory[i])
  addr += 2
 end
 printh("data saved")
end

save_data()
-- load_data()

-->8
-- MARK: screens
screens = {
 home = {},
 game_select = {},
 stats = {},
 settings = {},
 snacks = {},
 collection = {},
 adoption = {},
 gacha = {},
 gacha_anim = {}
}

function screens.home.update()
 current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 5, 2)

 if btnp(❎) then
  --disallows feeding or playing after death to prevent revives
  if is_dead(pets[current_pet]) and (current_icon == 1 or current_icon == 2) then
   return
  end
  if icons[current_icon].name == "food" then
   add_hunger()
  elseif icons[current_icon].name == "left" then
   current_pet = mod(current_pet - 1, #pets)
  elseif icons[current_icon].name == "right" then
   current_pet = mod(current_pet + 1, #pets)
  else
   switch_screen(current_icon - 1)
   current_icon = 1
  end
 end
end
function screens.home.draw()
 for i in all(icons) do
  spr(i.sprite, i.x, i.y)
 end
 local curr_icon = icons[current_icon]
 rect(curr_icon.x - 1, curr_icon.y - 1, curr_icon.x + 8, curr_icon.y + 8, 10)

 print_centered(curr_icon.name, 64, 110, 7)

 --stats icon reflecting pet status
 fillp(█)
 local hunger_x = pets[current_pet].hunger / 15 * 6
 local happy_x = pets[current_pet].happiness / 15 * 6
 if hunger_x > 1 then
  rectfill(61, 4, 60 + hunger_x, 4, hunger_x > 3 and 11 or 8)
 end
 if happy_x > 1 then
  rectfill(61, 6, 60 + happy_x, 6, happy_x > 3 and 11 or 8)
 end

 --print food counter
 print(food, 3, 13, 7)

 --draw current pet
 fillp(★)
 circfill(64, 64, 44, 3)
 pet = pets[current_pet]
 print_centered(pet.name, 64, 20, 7)
 if is_dead(pet) then
  spr_scaled(50, 52, 62, 4)
 else
  pet:spr_scaled(32, 32, 4)
 end
 --draw number of pets and current pet indicator
 pal()
 fillp(█)
 for i = 1, #pets do
  circfill(71 - 7 * #pets + 14 * (i - 1), 105, 2, i == current_pet and 7 or 5)
 end
end

function screens.game_select.update()
 current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 2, 2)
 if btnp(❎) then
  switch_screen(current_icon + 10)
 end
end
function screens.game_select.draw()
 fillp(█)
 rectfill(8, 8, 60, 60, 3)
 print_centered("math", 34, 31, 7)
 rectfill(68, 8, 120, 60, 3)
 print_centered("maze", 94, 31, 7)
 rectfill(8, 68, 60, 120, 3)
 print_centered("idk yet", 34, 91, 7)
 rectfill(68, 68, 120, 120, grim and 3 or 5)
 if grim then
  print_centered(grim_progress .. "/3", 94, 91, 7)
 else
  print_centered("tbd", 94, 91, 7)
 end
 --selector
 local x = 8 + (current_icon - 1) % 2 * 60
 local y = 8 + (current_icon - 1) \ 2 * 60
 rect(x, y, x + 52, y + 52, 10)
end

function screens.stats.update()
 -- do nothing
end
function screens.stats.draw()
 print(pets[current_pet].name, 20, 40, 7)
 fillp(█)
 --hunger bar
 print("hunger", 20, 52, 7)
 rectfill(20, 60, 108, 65, 5)
 rectfill(20, 60, 20 + 5.87 * pets[current_pet].hunger, 65, 11)
 --happy bar
 print("happiness", 20, 72, 7)
 rectfill(20, 80, 108, 85, 5)
 rectfill(20, 80, 20 + 5.87 * pets[current_pet].happiness, 85, 11)
end

function screens.settings.update()
 current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 1, 2)
 if btnp(❎) then
  if current_icon == 1 then
   --sound
   mute = not mute
  elseif current_icon == 2 then
   --grim mode
   grim = not grim
  end
 end
end
function screens.settings.draw()
 print_centered("sound", 64, 20, current_icon == 1 and 10 or 7)
 spr_scaled(16, 62, 30, 2, 1, 1)
 rect(45, 34, 53, 42, 7)
 if mute then
  print("🐱", 46, 36, 8)
  line(75, 35, 81, 41)
  line(75, 41, 81, 35)
 else
  line(76, 35, 76, 41)
  line(79, 32, 79, 44)
 end

 print_centered("grim mode", 64, 60, current_icon == 2 and 10 or 7)
 rect(45, 74, 53, 82, 7)
 if grim then
  print("🐱", 46, 76, 8)
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

function screens.snacks.update()
 local last_icon = current_icon
 current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 3, 2)
 if btnp(❎) and inventory[current_icon] ~= 0 then
  if x_pressed and inventory[current_icon] > 0 then
   inventory[current_icon] -= 1
   x_pressed = false
   --give pet status or ailment
  else
   x_pressed = true
  end
 end
end
function screens.snacks.draw()
 for i, item_amount in pairs(inventory) do
  local sx = 8 + (i - 1) % 3 * 44
  local sy = 8 + (i - 1) \ 3 * 44
  spr_scaled(all_items[i].sprite, sx, sy, 3)
  print_centered(item_amount, sx - 5, sy, 7)
  if i == current_icon then
   rect(sx - 1, sy - 1, sx + 24, sy + 24, 10)
  end
 end
 if x_pressed then
  print_centered("🅾️ return    ❎ use", 64, 110, 5)
 else
  print_centered("🅾️ exit", 64, 110, 5)
 end
end

function screens.collection.update()
 local last_icon = current_icon
 current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 4, 2)
 --there is no 8-th pet rn
 --deny access to 8th tile in grid
 if current_icon == 8 then
  current_icon = last_icon
 end
end
function screens.collection.draw()
 --draw all pets
 for i, pet_cls in pairs(all_pets) do
  local sx = 8 + (i - 1) % 4 * 32
  local sy = 8 + (i - 1) \ 4 * 32
  if i == current_icon then
   rect(sx - 1, sy - 1, sx + 16, sy + 16, 10)
  end
  if discovered_pets[pet_cls.id] then
   --draw normal
   if i == current_icon then
    print_centered(pet_cls.name, 64, 100, 7)
   end
   pet_cls:spr_scaled(sx, sy, 1)
  else
   --draw grayed out
   if i == current_icon then
    print_centered("???", 64, 100, 7)
   end
   pet_cls:pal(true)
   pet_cls:spr_scaled(sx, sy, 1, true)
  end
 end
 print_centered("🅾️ exit", 64, 110, 5)
end

function screens.adoption.update()
 -- do nothing
end
function screens.adoption.draw()
 print("killing menu in the works", 10, 40, 7)
end

-->8
--MARK: gacha page and animation
function screens.gacha.update()
 if btnp(🅾️) then
  screen = 0
 elseif current_icon == 1 and btnp(➡️) then
  current_icon = 2
 elseif current_icon == 2 and btnp(⬅️) then
  current_icon = 1
 elseif btnp(❎) then
  if current_icon == 1 and tokens >= 1 then
   tokens -= 1
   screen = 10
   t = time()
   gacha_animation_init()
  elseif tokens >= 10 then
   tokens -= 10
   screen = 10
   t = time()
   gacha_animation_init()
  end
 end
end
function screens.gacha.draw()
 cls()
 --rectfill(0,0,128,128,15)
 --tickets icon
 spr(37, 105, 0)
 print(tokens, 115, 2, 9)
 --1-pull choice
 rectfill(3, 49, 62, 79, 4)
 print("1-pull", 5, 51, 7)
 line(5, 59, 60, 59)
 print("20% chance for", 5, 63)
 print("pet egg")
 --10-pull choice
 rectfill(66, 49, 125, 79, 9)
 print("10-pull", 68, 51, 7)
 line(68, 59, 123, 59)
 print("guaranteed 3", 68, 63)
 print("pet egg drop")
 --selector
 local l = 63 * (current_icon - 1)
 rect(l + 3, 49, l + 62, 79, 10)
 --back icon
 print_centered("🅾️ back", 64, 110, 5)
 if current_icon == 1 and tokens < 1 or current_icon == 2 and tokens < 10 then
  print("not enough tokens", 30, 90, 8)
 end
end

--------------------------------
--animation and selection
--------------------------------

function gacha_animation_init()
 prizes_to_delete = {}

 --one pull
 if current_icon == 1 then
  draw_list = { pull_gacha() }
  --10 pull
 elseif current_icon == 2 then
  draw_list = {}
  for i = 1, 10 do
   add(draw_list, pull_gacha())
  end
 end
 current_icon = 1
end

function pull_gacha()
 local rolled_pet = rnd(1) < 0.2
 return rolled_pet and rnd(all_pets) or rnd(all_items)
end

function screens.gacha_anim.update()
 --skip animation button
 if btnp(🅾️) and under(6) then
  t -= 3
 elseif btnp(🅾️) then
  -- exit the screen
  --add inventory/pets list
  for i, prize in pairs(draw_list) do
   if prizes_to_delete[i] then
    -- MARK: ToDo add food system
   elseif is_instance(prize, class__pet) then
    add(pets, prize.new())
    discovered_pets[prize.id] = true
   else
    -- MARK: ToDo make item class
    inventory[prize.id] += 1
   end
  end
  switch_screen(0)
 end

 if btnp(❎) then
  --mark obj for deletion
  -- draw_list[current_icon].delete = true
  prizes_to_delete[current_icon] = true
  if #draw_list == 1 then
   --start blender animation
   switch_screen(0)
  end
 end

 if #draw_list ~= 1 and not under(6) then
  current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 5, 2)
 end
end

function under(length)
 return time() - t <= length
end

function screens.gacha_anim.draw()
 cls()
 --skip button
 if under(6) then
  print_centered("🅾️ skip", 64, 110, 5)
 end
 --1 pull
 if #draw_list == 1 then
  if under(0.3) then
   print_item(draw_list[1], 48, 48, 4)
  elseif under(0.6) then
   print_item(draw_list[1], 47, 48, 4)
  elseif under(0.9) then
   print_item(draw_list[1], 48, 48, 4)
  elseif under(1.2) then
   print_item(draw_list[1], 49, 48, 4)
  elseif under(3) then
   print_item(draw_list[1], 48, 48, 4)
  elseif under(6) then
   print_item(draw_list[1], 48, 48, 4, true)
  else
   print_item(draw_list[1], 48, 48, 4, true)
  end
 else
  for i, prize in pairs(draw_list) do
   local ix = (i - 1) % 5 * 26 + 4
   local iy = (i - 1) \ 5 * 46 + 33
   local shake = prize.sprite % 2 * 2 - 1
   if under(0.3) then
    print_item(prize, ix, iy, 2)
   elseif under(0.6) then
    print_item(prize, ix + shake, iy, 2)
   elseif under(0.9) then
    print_item(prize, ix, iy, 2)
   elseif under(1.2) then
    print_item(prize, ix - shake, iy, 2)
   elseif under(3) then
    print_item(prize, ix, iy, 2)
   elseif under(6) then
    print_item(prize, ix, iy, 2, true)
   else
    print_item(prize, ix, iy, 2, true)
    --draw selector
    if current_icon == i then
     rect(ix - 1, iy - 1, ix + 16, iy + 16, 10)
    end
    if prizes_to_delete[i] then
     line(ix - 1, iy - 1, ix + 16, iy + 16, 8)
     line(ix - 1, iy + 16, ix + 16, iy - 1, 8)
     --thicker lines
     line(ix - 2, iy - 1, ix + 15, iy + 16, 8)
     line(ix - 2, iy + 16, ix + 15, iy - 1, 8)
    end
   end
  end
 end
 if not under(6) then
  print_centered("❎ trash  🅾️ exit", 64, 110, 7)
 end
end

function print_item(item, x, y, size, open)
 if is_instance(item, class__pet) and open then
  item_size = 2
  size /= 2
 else
  item_size = 1
 end

 if open then
  sprite = item.sprite
 elseif item.pet then
  sprite = 48 --egg
 else
  sprite = 49 --present box
 end
 palt(0b0000000000010000)
 spr_scaled(sprite, x, y, size, item_size, item_size)
 pal()
end

-->8
--MARK: games

--MARK: ToDo: generalize games into classes
function finish_game()
 tokens += 2
 switch_screen(0)
 pets[current_pet].happiness = 15
 food += 3
end

function in_options(this)
 for option in all(options) do
  if this == option then
   return true
  end
 end
end

function get_str()
 local operation = { "+", "-", "*" }
 return num1 .. operation[i] .. num2
end

function setup_question()
 num1 = flr(rnd(10))
 num2 = flr(rnd(10))
 i = flr(rnd(3)) + 1
 ans_index = flr(rnd(4))
 algs = { num1 + num2, num1 - num2, num1 * num2 }
 ans = algs[i]
 options = {}
 --make sure no overlap answers
 add(options, ans)
 repeat
  new = ans + flr(rnd(6)) - 2
  if not in_options(new) then
   add(options, new)
  end
 until #options == 4
 del(options, ans)
 add(options, ans, ans_index + 1)
end

function update_math_game()
 if btnp(ans_index) then
  current_icon += 1
  setup_question()
  if current_icon == 5 then
   --finished game
   finish_game()
  end
 elseif btnp(0) or btnp(1) or btnp(2) or btnp(3) then
  current_icon = clamp(0, current_icon - 1, 5)
  setup_question()
 end
end

function draw_math_game()
 print(current_icon .. "/5", 110, 3, 7)

 print_centered(get_str(), 64, 61)
 print_centered(options[1], 34, 61)
 draw_triangle(22, 63, 40, 77, 40, 49)

 print_centered(options[2], 94, 61)
 draw_triangle(104, 63, 86, 77, 86, 49)

 print_centered(options[3], 64, 31)
 draw_triangle(63, 104, 77, 86, 49, 86)

 print_centered(options[4], 64, 91)
 draw_triangle(63, 22, 77, 40, 49, 40)
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
0007770000000600000700000000700007007000000d1000bb3333444444477bb99999999bbbb99bbbbb4aaaa0b44bbbbbbb4ffff0bbbbbbbbbd666666b6655b
777777000007e66000770000000077000777700000d11100bb4444444444444bbb9979999bbbbb9bbbbbb4aa0bb044bbbbbbb4ff0bbbbbbbbb5dd56666bb655b
7777770000eeee000777777777777770067760600dd11110bb444444999444bbbb977794499bbb9bbbbb40a0a4bb0440bbbb45f5f4bbbbbbbbbd566666b655bb
7777770000eee20077777777777777770077006000655500bb444499944444bbbb777794999bb99bbbb4a0a0aa00440bbbb4f5f5ff0bbbbbbbbbd66666655bbb
777777000662200007777777777777700077707000655500bbbb44444444bbbbbb777799999b99bbbbb0aaaaa9900bbbbbb0fffffee0bbbbbbbb6666655bbbbb
000777000060000000770000000077000076770000655500bbbbbbbbbbbbbbbbb9777949999999bbbb4909099090bbbbbb5e0e0ee0e0bbbbbb55bb666bbbbbbb
000077000000000000070000000070000000000000000000bbbbbbbbbbbbbbbbb977949999999bbbbb00000000000bbbbb00d0d00d000bbbbbbbb55bbbbbbbbb
00004400077000000000000000767700000044000000a000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
004444400767000000f87f000677776000444440000a9a00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
04444444076700000f88fff0777767760444444400a999a0bbbbbbbbbbbbbbbbbbb44bbbbbb44bbb000000000000000000000000000000000000000000000000
11664444007670000ffff87076777777444444450a99a99abbbbbbbbbbbbbbbbbbb44bbbbbb44bbb000000000000000000000000000000000000000000000000
1116664400aaaaa008fff8806776776748844445a9a999a0bbbbbbbb44444bbbbbb4444444444bbb000000000000000000000000000000000000000000000000
111116660a99aa0a0f78ff7015555551078844500a9a9a00bbbbbb4994444bbbbbb4444444444bbb000000000000000000000000000000000000000000000000
011111060909aaa00088ff00115555117768550000a9a000bb44bb499449944bbbb4444444444bbb000000000000000000000000000000000000000000000000
00110000000099aa000000000111111066000000000a0000bb044b449499444bbbb4004440044bbb000000000000000000000000000000000000000000000000
000770000007700000777700000006608888888888888888b8444b44999444bbbbb4444444444bbb000000000000000000000000000000000000000000000000
007777000078870007777770000060a88888a8888a888888b8b99444994499bbbbb4449994444bbb000000000000000000000000000000000000000000000000
00777700077228700556557000756588888aaa8888888888bbb9994449994bbbbbb4449994444bbb000000000000000000000000000000000000000000000000
077777700788776005575560075555508aaaaaaa88a88888bbb999999994bbbbbbb4444944444bbb000000000000000000000000000000000000000000000000
0777777007777660076577607555555588aaaaa888888888bbb4444444bbbbbbbbb444444444bbbb000000000000000000000000000000000000000000000000
07777770077766600677760075555555888aaa8888a88888bbbbb4444bbbbbbbbbbb44bbbb4bbbbb000000000000000000000000000000000000000000000000
0777777007776660056565000755555088aa8aa888888888bbbbbb4bbbbbbbbbbbbbb4bbbb4bbbbb000000000000000000000000000000000000000000000000
007777000077660000000000005555008aa888aa8a888888bbbbb444bbbbbbbbbbbb444bb444bbbb000000000000000000000000000000000000000000000000
