pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function _init()
 hunger = 100
 happiness = 100
 tokens = 10
 last_fed = time()
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
 clamp = mid
 --general use timer
 t = time()
end

function _update()
 update_hunger()
 if btnp(🅾️) then
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
 print(icons[current_icon].name == "left")
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
  pets[current_pet].hunger -= 1
  if (pets[current_pet].hunger < 0) pets[current_pet].hunger = 0
 end
end

function add_hunger()
 hunger = hunger + 1
 if (hunger > 15) hunger = 15
end

function check_player_inputs()
 current_icon = grid_wrap(current_icon, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 5, 2)

 if btnp(❎) then
  if icons[current_icon].name == "food" then
   add_hunger()
  elseif icons[current_icon].name == "left" then
   current_pet = clamp(1, current_pet - 1, #pets)
  elseif icons[current_icon].name == "right" then
   current_pet = clamp(1, current_pet + 1, #pets)
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
end

function draw_settings()
 print("settings in the works", 10, 40, 7)
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
pet_struct = {
 name = "default",
 immortal = false,
 sprite = 0,
 sprite_width = 2,
 sprite_height = 2
}
pet_struct.__index = pet_struct

function pet_struct.new()
 local self = setmetatable({}, pet_struct)
 self.hunger = 15
 self.happiness = 15
 return self
end

function pet_struct:spr(x, y)
 spr(self.sprite, x, y, self.sprite_width, self.sprite_height)
end
function pet_struct:spr_scaled(x, y, scale)
 spr_scaled(self.sprite, x, y, scale, self.sprite_width, self.sprite_height)
end
pet_duck = setmetatable(
 { name = "arb duck", sprite = 6 },
 pet_struct
)
pet_duck.__index = pet_duck
function pet_duck.new()
 local self = setmetatable(pet_struct.new(), pet_duck)
 return self
end

pet_cheeto = setmetatable(
 { name = "cheeto", immortal = true, sprite = 8 },
 pet_struct
)
pet_cheeto.__index = pet_cheeto
function pet_cheeto.new()
 local self = setmetatable(pet_struct.new(), pet_cheeto)
 return self
end

pet_mimikyu = setmetatable(
 { name = "mimikyu", sprite = 10 },
 pet_struct
)
pet_mimikyu.__index = pet_mimikyu
function pet_mimikyu.new()
 local self = setmetatable(pet_struct.new(), pet_mimikyu)
 return self
end

pet_not_mimikyu = setmetatable(
 { name = "not mimikyu", sprite = 12 },
 pet_struct
)
pet_not_mimikyu.__index = pet_not_mimikyu
function pet_not_mimikyu.new()
 local self = setmetatable(pet_struct.new(), pet_not_mimikyu)
 return self
end

pet_squirrel = setmetatable(
 { name = "squirrel", sprite = 14 },
 pet_struct
)
pet_squirrel.__index = pet_squirrel
function pet_squirrel.new()
 local self = setmetatable(pet_struct.new(), pet_squirrel)
 return self
end

pet_turkey = setmetatable(
 { name = "turkey", sprite = 38 },
 pet_struct
)
pet_turkey.__index = pet_turkey
function pet_turkey.new()
 local self = setmetatable(pet_struct.new(), pet_turkey)
 return self
end

pet_owl = setmetatable(
 { name = "owl", sprite = 40 },
 pet_struct
)
pet_owl.__index = pet_owl
function pet_owl.new()
 local self = setmetatable(pet_struct.new(), pet_owl)
 return self
end

all_pets = {
 pet_duck,
 pet_cheeto,
 pet_mimikyu,
 pet_not_mimikyu,
 pet_squirrel,
 pet_turkey,
 pet_owl
}

all_items = {
 { sprite = 32 },
 { sprite = 33 },
 { sprite = 34 },
 { sprite = 35 },
 { sprite = 36 }
}

inventory = {}
pets = { pet_duck.new(), pet_cheeto.new(), pet_mimikyu.new(), pet_not_mimikyu.new() }
--1 based counting to access pet table
current_pet = 1

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
--animation
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
 --add inventory/pets list
 for i in all(draw_list) do
  if i.pet then
   add(pets, i.obj)
  else
   add(inventory, i.obj)
  end
 end
end

function generate()
 local l = { true, false, false, false, false }
 local s = rnd(l)
 local pet_ = rnd(all_pets).new()
 local item_ = rnd(all_items)
 return { pet = s, obj = s and pet_ or item_ }
end

function update_gatcha_animation()
 --skip animation button
 if btnp(🅾️) then
  t -= 3
 end
end

function under(length)
 return time() - t <= length
end

function draw_gatcha_animation()
 cls()
 --skip button
 print("🅾️ skip", 100, 120, 5)
 --1 pull
 if #draw_list == 1 then
  if under(0.3) then
   print_item(draw_list[1], 48, 48, 32)
  elseif under(0.6) then
   print_item(draw_list[1], 47, 48, 32)
  elseif under(0.9) then
   print_item(draw_list[1], 48, 48, 32)
  elseif under(1.2) then
   print_item(draw_list[1], 49, 48, 32)
  elseif under(3) then
   print_item(draw_list[1], 48, 48, 32)
  elseif under(6) then
   print_item(draw_list[1], 48, 48, 32, true)
  else
   screen = 0
  end
 else
  for i, j in pairs(draw_list) do
   local ix = (i - 1) % 5 * 26 + 4
   local iy = (i - 1) \ 5 * 46 + 33
   local shake = j.obj.spr[1] / 8 % 2 * 2 - 1
   if under(0.3) then
    print_item(j, ix, iy, 16)
   elseif under(0.6) then
    print_item(j, ix + shake, iy, 16)
   elseif under(0.9) then
    print_item(j, ix, iy, 16)
   elseif under(1.2) then
    print_item(j, ix - shake, iy, 16)
   elseif under(3) then
    print_item(j, ix, iy, 16)
   elseif under(6) then
    print_item(j, ix, iy, 16, true)
   else
    screen = 0
   end
  end
 end
end

function print_item(item, x, y, size, open)
 if item.pet and open then
  item_size = 2
 else
  item_size = 1
 end

 if open then
  sprite = item.obj.sprite
 elseif item.pet then
  sprite = 48 --egg
 else
  sprite = 49 --bloody egg
 end
 palt(0b0000000000010000)
 -- MARK: SPRITE
 -- sspr(item_location[1], item_location[2], item_size, item_size, x, y, size, size)
 spr_scaled(sprite, x, y, size / 8, item_size, item_size)
 pal()
end

__gfx__
000000000000000000000000000000000000000000067000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb050bbbbbbbbbbbbb020bbbbbbbbbbbbbbbbbbbbbbbbbb
0000000000009900056776500bbbb7700999408007577670bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb05bbbbbb0000bbbb52bbbbbb0000bbbbbbbbbbbbbbbbb
007007000009979007777770000000000777705006777750bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0999bbb4aaa550bb0eeebbb5fff220bbbbbbbbbbbbbb44
0007700000999940078775700bbbb0000777705077700776bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb499aa44aa00bbbbb4eeff55ff00bbbbbbbbbbbbbb44444
000770000069440007777770000000000944455067700777bb3333bbbbbbbbbbb9bbbbb9bbbbbbbbbbb4aaaaaa0bbbb0bbb57ff7ff0bbbbbbbbbbbbbbbb4444b
007007000675000006755760087777000444400005777760bb33303bbbbbbbbbb99bbb99bbbbbbbbbb4a0aa0aaa4bb04bb5f2ff2fff5bbbbbbb444bbbb44444b
000000000700000000600600000000000444400007677570b999333bbbbbbbbbb9999999bbbbbbbbbb49aaaa99a0b444bb4effffeef0bbbbbbb040bbbb4444bb
000000000000000000000000000000000000000000076000b999333bbbbbbb7bb9099099bbb9bbbbbb40a0a099a0b440bb42f2f2eef0bbbbbbb444bbb4444bbb
aaaaaaaa0000000000000000000000000000000000000000bb33333bbbbb777bb9999999bbb999bbbbb40a0aaa0b440bbbb42f2fff0bbbbbbbbb444b44444bbb
a000000a00000600000700000000700007007000000d1000bb3333444444477bb99999999bbbb99bbbbb4aaaa0b44bbbbbbb4ffff0bbbbbbbbbb444444444bbb
a000000a0007e66000770000000077000777700000d11100bb4444444444444bbb9979999bbbbb9bbbbbb4aa0bb044bbbbbbb4ff0bbbbbbbbbb444444444bbbb
a000000a00eeee000777777777777770067760600dd11110bb444444999444bbbb977794499bbb9bbbbb40a0a4bb0440bbbb45f5f4bbbbbbbbbb4444444bbbbb
a000000a00eee20077777777777777770077006000655500bb444499944444bbbb777794999bb99bbbb4a0a0aa00440bbbb4f5f5ff0bbbbbbbbb4b4bbbbbbbbb
a000000a0662200007777777777777700077707000655500bbbb44444444bbbbbb777799999b99bbbbb0aaaaa9900bbbbbb0fffffee0bbbbbbbbbbbbbbbbbbbb
a000000a0060000000770000000077000076770000655500bbbbbbbbbbbbbbbbb9777949999999bbbb4909099090bbbbbb5e0e0ee0e0bbbbbbbbbbbbbbbbbbbb
aaaaaaaa0000000000070000000070000000000000000000bbbbbbbbbbbbbbbbb977949999999bbbbb00000000000bbbbb00d0d00d000bbbbbbbbbbbbbbbbbbb
00000000000000000011111000011000001001100000a000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
0011100000001000011000110110110001100100000a9a00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
001011000001100001000001010001001000100000a999a0bbbbbbbbbbbbbbbbbbb44bbbbbb44bbb000000000000000000000000000000000000000000000000
01000100000100000000001000001000100010110a99a99abbbbbbbbbbbbbbbbbbb44bbbbbb44bbb000000000000000000000000000000000000000000000000
0100110000010000000011000011110011111100a9a999a0bbbbbbbb44444bbbbbb4444444444bbb000000000000000000000000000000000000000000000000
01011000001000000001000000000110001100000a9a9a00bbbbbb4994444bbbbbb4444444444bbb000000000000000000000000000000000000000000000000
011100000010000000100000100001000010000000a9a000bb44bb499449944bbbb4444444444bbb000000000000000000000000000000000000000000000000
0000000000100000001111101111110001000000000a0000bb044b449499444bbbb4004440044bbb000000000000000000000000000000000000000000000000
000770000007700000000000000000000000000000000000b8444b44999444bbbbb4444444444bbb000000000000000000000000000000000000000000000000
007777000078870000000000000000000000000000000000b8b99444994499bbbbb4449994444bbb000000000000000000000000000000000000000000000000
007777000772287000000000000000000000000000000000bbb9994449994bbbbbb4449994444bbb000000000000000000000000000000000000000000000000
077777700788776000000000000000000000000000000000bbb999999994bbbbbbb4444944444bbb000000000000000000000000000000000000000000000000
077777700777766000000000000000000000000000000000bbb4444444bbbbbbbbb444444444bbbb000000000000000000000000000000000000000000000000
077777700777666000000000000000000000000000000000bbbbb4444bbbbbbbbbbb44bbbb4bbbbb000000000000000000000000000000000000000000000000
077777700777666000000000000000000000000000000000bbbbbb4bbbbbbbbbbbbbb4bbbb4bbbbb000000000000000000000000000000000000000000000000
007777000077660000000000000000000000000000000000bbbbb444bbbbbbbbbbbb444bb444bbbb000000000000000000000000000000000000000000000000
