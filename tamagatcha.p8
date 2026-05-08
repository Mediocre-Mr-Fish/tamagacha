pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
is_runtime = false
function _init()
 is_runtime = true
 tokens = 10
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
end

function _update()
 update_hunger()
 update_happiness()
 if btnp(🅾️) and screen != 10 then
  screen = 0
 end
 if screen == 0 then
  check_player_inputs()
 elseif screen == 1 then
  --game
 elseif screen == 2 then
  --stats
 elseif screen == 3 then
  --gatcha
  update_gatcha()
 elseif screen == 4 then
  --setting
  update_settings()
 elseif screen == 5 then
  --snack
 elseif screen == 8 then
  --pet collection
 elseif screen == 9 then
  --adoption
 elseif screen == 10 then
  --gatcha animation
  update_gatcha_animation()
 end
end

function _draw()
 cls()
 if screen == 0 then
  draw_icons()
  draw_pet()
 elseif screen == 1 then
  --game
  draw_game_select()
 elseif screen == 2 then
  --stats
  draw_stats()
 elseif screen == 3 then
  --gatcha
  draw_gacha()
 elseif screen == 4 then
  --setting
  draw_settings()
 elseif screen == 5 then
  --snack
  draw_snacks()
 elseif screen == 8 then
  --pet collection
  draw_collection()
 elseif screen == 9 then
  --adoption
  draw_adoption()
 elseif screen == 10 then
  --gatcha animation
  draw_gatcha_animation()
 end
end
-->8
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

function update_hunger()
 if time() - last_fed > 2 then
  last_fed = time()
  --do this for all pets later
  for i in all(pets) do
   i.hunger -= 1
   if (i.hunger < 0) i.hunger = 0
  end
 end
end

function update_happiness()
 if time() - last_play > 4 then
  last_play = time()
  --do this for all pets later
  for i in all(pets) do
   i.happiness -= 1
   if (i.happiness < 0) i.happiness = 0
  end
 end
end

function add_hunger()
 pets[current_pet].hunger = pets[current_pet].hunger + 1
 if (pets[current_pet].hunger > 15) pets[current_pet].hunger = 15
end

function add_happiness()
 pets[current_pet].happiness = pets[current_pet].happiness + 1
 if (pets[current_pet].happiness > 15) pets[current_pet].happiness = 15
end

function check_player_inputs()
 current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 5, 2)

 if btnp(❎) then
  if icons[current_icon].name == "food" then
   add_hunger()
  elseif icons[current_icon].name == "left" then
   current_pet = mod(current_pet - 1, #pets)
  elseif icons[current_icon].name == "right" then
   current_pet = mod(current_pet + 1, #pets)
  else
   screen = current_icon - 1
   current_icon = 1
  end
 end
end

function draw_icons()
 for i in all(icons) do
  spr(i.sprite, i.x, i.y)
 end
 local curr_icon = icons[current_icon]
 -- spr(16,curr_icon.x,curr_icon.y)
 rect(curr_icon.x - 1, curr_icon.y - 1, curr_icon.x + 8, curr_icon.y + 8, 10)
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
end

function draw_pet()
 fillp(★)
 circfill(64, 64, 44, 3)
 --set gray to not draw
 palt(0b0000000000010000)
 pet = pets[current_pet]
 print(pet.name, 50, 20, 7)
 pet:spr_scaled(32, 32, 4)
 pal()
 fillp(█)
 for i = 1, #pets do
  circfill(71 - 7 * #pets + 14 * (i - 1), 105, 2, i == current_pet and 7 or 5)
 end
end

function draw_game_select()
 print("games in the works", 10, 40, 7)
end

function draw_stats()
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

function update_settings()
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

function draw_settings()
 print("sound", 20, 20, current_icon == 1 and 10 or 7)
 spr_scaled(16, 40, 30, 2, 1, 1)
 rect(20, 34, 28, 42, 7)
 if mute then
  print("🐱", 21, 36, 8)
  line(53, 35, 59, 41)
  line(53, 41, 59, 35)
 else
  line(54, 35, 54, 41)
  line(57, 32, 57, 44)
 end

 print("grim mode", 20, 60, current_icon == 2 and 10 or 7)
 rect(20, 74, 28, 82, 7)
 if grim then
  print("🐱", 21, 76, 8)
  pal(6, 8)
  print("✽", 43, 81, 8)
  print("★", 47, 78, 2)
  spr_scaled(50, 40, 70, 2, 1, 1)
  pal()
 else
  spr_scaled(50, 40, 70, 2, 1, 1)
 end

 print("❎ select  🅾️ exit", 20, 110, 5)
end

function draw_snacks()
 print("snacks menu in the works", 10, 40, 7)
end

function draw_collection()
 print("collections in the works", 10, 40, 7)
end

function draw_adoption()
 print("killing menu in the works", 10, 40, 7)
end

-->8
-- structs

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
function classfactory__pet(static_vars, parent)
 static_vars.id = #all_pets + 1
 return classfactory(static_vars, parent or class__pet, all_pets)
end

class__pet = classfactory({
 name = "default",
 immortal = false,
 sprite = 0,
 sprite_width = 2,
 sprite_height = 2
})
function class__pet.new()
 local self = setmetatable({}, class__pet)
 self.hunger = 15
 self.happiness = 15
 return self
end
function class__pet:spr(x, y)
 spr(self.sprite, x, y, self.sprite_width, self.sprite_height)
end
function class__pet:spr_scaled(x, y, scale)
 spr_scaled(self.sprite, x, y, scale, self.sprite_width, self.sprite_height)
end

pet_duck = classfactory__pet({ name = "arb duck", sprite = 6 })
pet_cheeto = classfactory__pet({ name = "cheeto", immortal = true, sprite = 8 })
pet_mimikyu = classfactory__pet({ name = "mimikyu", sprite = 10 })
pet_not_mimikyu = classfactory__pet({ name = "not mimikyu", sprite = 12 })
pet_squirrel = classfactory__pet({ name = "squirrel", sprite = 14 })
pet_turkey = classfactory__pet({ name = "turkey", sprite = 38 })
pet_owl = classfactory__pet({ name = "owl", sprite = 40 })

all_items = {
 { sprite = 32 },
 { sprite = 33 },
 { sprite = 34 },
 { sprite = 35 },
 { sprite = 36 }
}
num_item_types = 16

inventory = {}
for i = 1, num_item_types do
 if (all_items[i]) all_items[i].id = i inventory[i] = 0
end
max_item_stack = 0xff

pets = {
 pet_duck.new(),
 pet_cheeto.new(),
 pet_mimikyu.new(),
 pet_not_mimikyu.new(),
 pet_squirrel.new()
}
--1 based counting to access pet table
current_pet = 1
max_pets = 16

-- username_title_version
cartdata("real-fancy-fire_tamagacha_0-1")
function load_data()
 local addr = 0x5e00

 -- user data
 local user_data = peek(addr)
 --data exists
 mute = user_data & 0x1 ~= 0
 grim = user_data & 0x2 ~= 0
 addr += 1

 -- pets
 for i = 1, max_pets do
  local id, _, hunger, happiness = peek(addr, 4)
  if all_pets[id] then
   local pet = all_pets[id].new()
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
  addr,
  (mute and 0x1 or 0)
    + (grim and 0x2 or 0)
    + 0
    + 0
 )
 addr += 1

 -- pets
 for i = 1, max_pets do
  local pet = pets[i]

  if pet then
   poke(addr, pet.id, 0, pet.hunger, pet.happiness)
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
end

-- save_data()
-- load_data()

-->8
--gatcha page and animation
function update_gatcha()
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
   gatcha_animation_init()
  elseif tokens >= 10 then
   tokens -= 10
   screen = 10
   t = time()
   gatcha_animation_init()
  end
 end
end

function draw_gacha()
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
 print("🅾️ back", 100, 120, 5)
 if current_icon == 1 and tokens < 1 or current_icon == 2 and tokens < 10 then
  print("not enough tokens", 30, 90, 8)
 end
end

--------------------------------
--animation and selection
--------------------------------

function gatcha_animation_init()
 --one pull
 if current_icon == 1 then
  draw_list = { generate() }
  --10 pull
 elseif current_icon == 2 then
  draw_list = {}
  for i = 1, 10 do
   add(draw_list, generate())
  end
 end
 current_icon = 1
end

function generate()
 local l = { true, false, false, false, false }
 local s = rnd(l)
 local pet_ = rnd(all_pets)
 local item_ = rnd(all_items)
 return { pet = s, obj = s and pet_ or item_, delete = false }
end

function update_gatcha_animation()
 --skip animation button
 if btnp(🅾️) and under(6) then
  t -= 3
 elseif btnp(🅾️) then
  --add inventory/pets list
  for i in all(draw_list) do
   if i.pet and not i.delete then
    add(pets, i.obj.new())
   elseif not i.delete then
    -- MARK: ToDo- Rework items
    -- add(inventory, i.obj)
    inventory[i.obj.id] += 1
   end
  end
  screen = 0
 end
 if btnp(❎) then
  --mark obj for deletion
  draw_list[current_icon].delete = true
  if #draw_list == 1 then
   --start blender animation
   screen = 0
  end
 end
 if #draw_list ~= 1 and not under(6) then
  current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 5, 2)
 end
end

function under(length)
 return time() - t <= length
end

function draw_gatcha_animation()
 cls()
 --skip button
 if under(6) then
  print("🅾️ skip", 100, 120, 5)
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
  for i, j in pairs(draw_list) do
   local ix = (i - 1) % 5 * 26 + 4
   local iy = (i - 1) \ 5 * 46 + 33
   local shake = j.obj.sprite % 2 * 2 - 1
   if under(0.3) then
    print_item(j, ix, iy, 2)
   elseif under(0.6) then
    print_item(j, ix + shake, iy, 2)
   elseif under(0.9) then
    print_item(j, ix, iy, 2)
   elseif under(1.2) then
    print_item(j, ix - shake, iy, 2)
   elseif under(3) then
    print_item(j, ix, iy, 2)
   elseif under(6) then
    print_item(j, ix, iy, 2, true)
   else
    print_item(j, ix, iy, 2, true)
    --draw selector
    if current_icon == i then
     rect(ix - 1, iy - 1, ix + 16, iy + 16, 10)
    end
    if j.delete then
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
  print("❎ trash  🅾️ exit", 30, 110, 7)
 end
end

function print_item(item, x, y, size, open)
 if item.pet and open then
  item_size = 2
  size /= 2
 else
  item_size = 1
 end

 if open then
  sprite = item.obj.sprite
 elseif item.pet then
  sprite = 48 --egg
 else
  sprite = 49 --present box
 end
 palt(0b0000000000010000)
 spr_scaled(sprite, x, y, size, item_size, item_size)
 pal()
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
00000000000000000011111000011000001001100000a000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
0011100000001000011000110110110001100100000a9a00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
001011000001100001000001010001001000100000a999a0bbbbbbbbbbbbbbbbbbb44bbbbbb44bbb000000000000000000000000000000000000000000000000
01000100000100000000001000001000100010110a99a99abbbbbbbbbbbbbbbbbbb44bbbbbb44bbb000000000000000000000000000000000000000000000000
0100110000010000000011000011110011111100a9a999a0bbbbbbbb44444bbbbbb4444444444bbb000000000000000000000000000000000000000000000000
01011000001000000001000000000110001100000a9a9a00bbbbbb4994444bbbbbb4444444444bbb000000000000000000000000000000000000000000000000
011100000010000000100000100001000010000000a9a000bb44bb499449944bbbb4444444444bbb000000000000000000000000000000000000000000000000
0000000000100000001111101111110001000000000a0000bb044b449499444bbbb4004440044bbb000000000000000000000000000000000000000000000000
000770000007700000777700000000000000000000000000b8444b44999444bbbbb4444444444bbb000000000000000000000000000000000000000000000000
007777000078870007777770000000000000000000000000b8b99444994499bbbbb4449994444bbb000000000000000000000000000000000000000000000000
007777000772287005565570000000000000000000000000bbb9994449994bbbbbb4449994444bbb000000000000000000000000000000000000000000000000
077777700788776005575560000000000000000000000000bbb999999994bbbbbbb4444944444bbb000000000000000000000000000000000000000000000000
077777700777766007657760000000000000000000000000bbb4444444bbbbbbbbb444444444bbbb000000000000000000000000000000000000000000000000
077777700777666006777600000000000000000000000000bbbbb4444bbbbbbbbbbb44bbbb4bbbbb000000000000000000000000000000000000000000000000
077777700777666005656500000000000000000000000000bbbbbb4bbbbbbbbbbbbbb4bbbb4bbbbb000000000000000000000000000000000000000000000000
007777000077660000000000000000000000000000000000bbbbb444bbbbbbbbbbbb444bb444bbbb000000000000000000000000000000000000000000000000
