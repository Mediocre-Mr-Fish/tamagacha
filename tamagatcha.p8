pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function _init()
 hunger=100
 happiness=100
 tokens=10
 last_fed=time()
 icons={
  {name="food"   ,x=3  ,y=3  ,sprite=1},
  {name="game"   ,x=31 ,y=3  ,sprite=2},
  {name="stats"  ,x=60 ,y=3  ,sprite=3},
  {name="gacha"  ,x=89 ,y=3  ,sprite=4},
  {name="setting",x=117,y=3  ,sprite=5},
  
  {name="snack"  ,x=3  ,y=117,sprite=17},
  {name="left"   ,x=31 ,y=117,sprite=18},
  {name="right"  ,x=60 ,y=117,sprite=19},
  {name="pets"   ,x=89 ,y=117,sprite=20},
  {name="adopt"  ,x=117,y=117,sprite=21}
 }
 current_icon=1
 screen=0
 clamp = mid
 --general use timer
 t = time()
end

function _update()
 update_hunger()
 if screen==0 then
  check_player_inputs()
 elseif screen==1 then
  --game
 elseif screen==2 then
  --stats
 elseif screen==3 then
  --gatcha
  update_gatcha()
 elseif screen==4 then
  --setting
 elseif screen==5 then
  --snack
 elseif screen==8 then
  --pet collection
 elseif screen==9 then
  --adoption
 elseif screen==10 then
  --gatcha animation
  update_gatcha_animation()
 end
end


function _draw()
 cls()
 --[[
 print inventory for debugging
 for i in all(inventory) do
  print(i)
 end
 ]]
 if screen==0 then
  draw_icons()
  draw_pet()
 elseif screen==1 then
  --game
  draw_game_select()
 elseif screen==2 then
  --stats
  draw_stats()
 elseif screen==3 then
  --gatcha
  draw_gacha()
 elseif screen==4 then
  --setting
  draw_settings()
 elseif screen==5 then
  --snack
  draw_snacks()
 elseif screen==8 then
  --pet collection
  draw_collection()
 elseif screen==9 then
  --adoption
  draw_adoption()
 elseif screen==10 then
  --gatcha animation
  draw_gatcha_animation()
 end
end
-->8
function update_hunger()
 if time()-last_fed>2 then
  last_fed=time()
  --do this for all pets later
  pets[current_pet].hunger-=1
  if (pets[current_pet].hunger<0) pets[current_pet].hunger=0
 end
end

function add_hunger()
 hunger=hunger+1
 if (hunger>15) hunger=15
end

function check_player_inputs()
 if btnp(⬅️) then
  current_icon=clamp(1,current_icon-1,#icons)
 elseif btnp(➡️) then
  current_icon=clamp(1,current_icon+1,#icons)
 elseif btnp(⬇️) and current_icon<6 then
  current_icon=current_icon+5
 elseif btnp(⬆️) and current_icon>5 then
  current_icon=current_icon-5
 elseif btnp(❎) then
  if icons[current_icon].name=="food" then
   add_hunger()
  elseif icons[current_icon].name=="left" then
   current_pet=clamp(1,current_pet-1,#pets)
  elseif icons[current_icon].name=="right" then
   current_pet=clamp(1,current_pet+1,#pets)
  else
   screen=current_icon-1
   current_icon=1
  end
 end
end

function draw_icons()
	for i in all(icons) do
	 spr(i.sprite,i.x,i.y)
	end
	local curr_icon = icons[current_icon]
	spr(16,curr_icon.x,curr_icon.y)
end

function draw_pet()
	fillp(★)
	circfill(64,64,44,3)
	--set gray to not draw
	palt(0b0000000000010000)
	print(pets[current_pet].name,50,20,7)
	sspr(pets[current_pet].spr[1],pets[current_pet].spr[2],16,16,32,32,64,64)
	pal()
	fillp(█)
	for i=1,#pets do
	 circfill(71-7*#pets+14*(i-1),105,2,i==current_pet and 7 or 5)
	end
end

function draw_game_select()
	print("games in the works",10,40,7)
end

function draw_stats()
	print(pets[current_pet].name,20,40,7)
 fillp(█)
 --hunger bar
 print("hunger",20,52,7)
 rectfill(20,60,108,65,5)
 rectfill(20,60,20+5.87*pets[current_pet].hunger,65,11)
 --happy bar
end

function draw_settings()
	print("settings in the works",10,40,7)
end

function draw_snacks()
	print("snacks menu in the works",10,40,7)
end

function draw_collection()
	print("collections in the works",10,40,7)
end

function draw_adoption()
	print("killing menu in the works",10,40,7)
end


-->8
pet_struct = { immortal = false }
pet_struct.__index = pet_struct

function pet_struct.new()
    local self = setmetatable({}, pet_struct)
    self.name = "default"
    self.hunger = 15
    self.happiness = 15
    self.spr = {0,0}
    return self
end

pet_duck = setmetatable({}, pet_struct)
pet_duck.__index = pet_duck
function pet_duck.new()
    local self = setmetatable(pet_struct.new(), pet_duck)
    self.name = "arb duck"
    self.spr = {48,0}
    return self
end

pet_cheeto = setmetatable(
    { immortal = true },
    pet_struct
)
pet_cheeto.__index = pet_cheeto
function pet_cheeto.new()
    local self = setmetatable(pet_struct.new(), pet_cheeto)
    self.name = "cheeto"
    self.spr = {64,0}
    return self
end

pet_mimikyu = setmetatable({}, pet_struct)
pet_mimikyu.__index = pet_mimikyu
function pet_mimikyu.new()
    local self = setmetatable(pet_struct.new(), pet_mimikyu)
    self.name = "mimikyu"
    self.spr = {80,0}
    return self
end

pet_not_mimikyu = setmetatable({}, pet_struct)
pet_not_mimikyu.__index = pet_not_mimikyu
function pet_not_mimikyu.new()
    local self = setmetatable(pet_struct.new(), pet_not_mimikyu)
    self.name = "not mimikyu"
    self.spr = {96,0}
    return self
end

all_pets={pet_duck,
 pet_cheeto,
 pet_mimikyu,
 pet_not_mimikyu}
 
all_items={
{spr = {0,16}},
{spr = {8,16}},
{spr = {16,16}},
{spr = {24,16}},
{spr = {32,16}}
}

inventory = {

}

pets = {pet_duck.new()}
--1 based counting to access pet table
current_pet = 1
-->8
--gatcha page and animation
function update_gatcha()
 if btnp(🅾️) then
  screen=0
 elseif current_icon==1and btnp(➡️) then
  current_icon=2
 elseif current_icon==2and btnp(⬅️) then
  current_icon=1
 elseif btnp(❎) then
  if current_icon==1 and tokens>=1then
   tokens-=1
   screen=10
   t=time()
   gatcha_animation_init()
  elseif tokens>=10 then
   tokens-=10
   screen=10
   t=time()
   gatcha_animation_init()
  end
 end
end

function draw_gacha()
 cls()
 --rectfill(0,0,128,128,15)
 --tickets icon
 spr(37,105,0)
 print(tokens,115,2,9)
 --1-pull choice
 rectfill(3,49,62,79,4)
 print("1-pull",5,51,7)
 line(5,59,60,59)
 print("20% chance for",5,63)
 print("pet egg")
 --10-pull choice
 rectfill(66,49,125,79,9)
 print("10-pull",68,51,7)
 line(68,59,123,59)
 print("guaranteed 3",68,63)
 print("pet egg drop")
 --selector
 local l=63*(current_icon-1)
 rect(l+3,49,l+62,79,10)
 --back icon
 print("🅾️ back",100,120,5)
 if current_icon==1 and tokens<1 or current_icon==2 and tokens<10 then
  print("not enough tokens",30,90,8)
 end
end

--------------------------------
--animation
--------------------------------

function gatcha_animation_init()
 --one pull
 if current_icon==1 then
 	draw_list={generate()}
 --10 pull
 elseif current_icon==2 then
 	draw_list={}
 	for i=1,10 do
 	 add(draw_list,generate())
 	end
 end
 --add inventory/pets list
 for i in all(draw_list) do
  if i.pet then
   add(pets,i.obj)
  else
   add(inventory,i.obj)
  end
 end
end

function generate()
 	local l={true,false,false,false,false}
 	local s=rnd(l)
 	local pet_ = rnd(all_pets).new()
 	local item_ = rnd(all_items)
 	return {pet=s,obj=s and pet_ or item_}
end

function update_gatcha_animation()
 --skip animation button
 if btnp(🅾️) then
  t-=3
 end
end

function under(length)
 return time()-t<=length
end

function draw_gatcha_animation()
 cls()
 --skip button
 print("🅾️ skip",100,120,5)
 print(draw_list[1].obj.spr)
 --1 pull
 if #draw_list==1 then
	 if under(0.3) then
	  print_item(draw_list[1],48,48,32)
	 elseif under(0.6) then
	  print_item(draw_list[1],47,48,32)
	 elseif under(0.9) then
	  print_item(draw_list[1],48,48,32)
	 elseif under(1.2) then
	  print_item(draw_list[1],49,48,32)
	 elseif under(3) then
	  print_item(draw_list[1],48,48,32)
	 elseif under(6) then
	  print_item(draw_list[1],48,48,32,true)
	 else
	  screen=0
	 end
 else
  for i,j in pairs(draw_list) do
   local ix=(i-1)%5*26+4
   local iy=(i-1)\5*46+33
   local shake=j.obj.spr[1]/8%2*2-1
	  if under(0.3) then
		  print_item(j,ix,iy,16)
		 elseif under(0.6) then
		  print_item(j,ix+shake,iy,16)
		 elseif under(0.9) then
		  print_item(j,ix,iy,16)
		 elseif under(1.2) then
		  print_item(j,ix-shake,iy,16)
		 elseif under(3) then
		  print_item(j,ix,iy,16)
		 elseif under(6) then
		  print_item(j,ix,iy,16,true)
		 else
	   screen=0
		 end
  end
 end
end

function print_item(item,x,y,size,open)
 if item.pet and open then
  item_size=16
 else
  item_size=8
 end
 if open then 
  item_location=item.obj.spr
 elseif item.pet then
  item_location={0,24}
 else
  item_location={8,24}
 end
 palt(0b0000000000010000)
 sspr(item_location[1],item_location[2],item_size,item_size,x,y,size,size)
 pal()
end
__gfx__
000000000000000000000000000000000000000000067000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb050bbbbbbbbbbbbb020bbbbbbbbbb0000000000000000
0000000000009900056776500bbbb7700999408007577670bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb05bbbbbb0000bbbb52bbbbbb0000b0000000000000000
007007000009979007777770000000000777705006777750bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0999bbb4aaa550bb0eeebbb5fff2200000000000000000
0007700000999940078775700bbbb0000777705077700776bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb499aa44aa00bbbbb4eeff55ff00bbb0000000000000000
000770000069440007777770000000000944455067700777bb3333bbbbbbbbbbb9bbbbb9bbbbbbbbbbb4aaaaaa0bbbb0bbb57ff7ff0bbbbb0000000000000000
007007000675000006755760087777000444400005777760bb33303bbbbbbbbbb99bbb99bbbbbbbbbb4a0aa0aaa4bb04bb5f2ff2fff5bbbb0000000000000000
000000000700000000600600000000000444400007677570b999333bbbbbbbbbb9999999bbbbbbbbbb49aaaa99a0b444bb4effffeef0bbbb0000000000000000
000000000000000000000000000000000000000000076000b999333bbbbbbb7bb9099099bbb9bbbbbb40a0a099a0b440bb42f2f2eef0bbbb0000000000000000
aaaaaaaa0000000000000000000000000000000000000000bb33333bbbbb777bb9999999bbb999bbbbb40a0aaa0b440bbbb42f2fff0bbbbb0000000000000000
a000000a00000600000700000000700007007000000d1000bb3333444444477bb99999999bbbb99bbbbb4aaaa0b44bbbbbbb4ffff0bbbbbb0000000000000000
a000000a0007e66000770000000077000777700000d11100bb4444444444444bbb9979999bbbbb9bbbbbb4aa0bb044bbbbbbb4ff0bbbbbbb0000000000000000
a000000a00eeee000777777777777770067760600dd11110bb444444999444bbbb977794499bbb9bbbbb40a0a4bb0440bbbb45f5f4bbbbbb0000000000000000
a000000a00eee20077777777777777770077006000655500bb444499944444bbbb777794999bb99bbbb4a0a0aa00440bbbb4f5f5ff0bbbbb0000000000000000
a000000a0662200007777777777777700077707000655500bbbb44444444bbbbbb777799999b99bbbbb0aaaaa9900bbbbbb0fffffee0bbbb0000000000000000
a000000a0060000000770000000077000076770000655500bbbbbbbbbbbbbbbbb9777949999999bbbb4909099090bbbbbb5e0e0ee0e0bbbb0000000000000000
aaaaaaaa0000000000070000000070000000000000000000bbbbbbbbbbbbbbbbb977949999999bbbbb00000000000bbbbb00d0d00d000bbb0000000000000000
00000000000000000011111000011000001001100000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000
0011100000001000011000110110110001100100000a9a0000000000000000000000000000000000000000000000000000000000000000000000000000000000
001011000001100001000001010001001000100000a999a000000000000000000000000000000000000000000000000000000000000000000000000000000000
01000100000100000000001000001000100010110a99a99a00000000000000000000000000000000000000000000000000000000000000000000000000000000
0100110000010000000011000011110011111100a9a999a000000000000000000000000000000000000000000000000000000000000000000000000000000000
01011000001000000001000000000110001100000a9a9a0000000000000000000000000000000000000000000000000000000000000000000000000000000000
011100000010000000100000100001000010000000a9a00000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000100000001111101111110001000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700007887000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700077228700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770078877600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077776600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077766600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077766600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700007766000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
