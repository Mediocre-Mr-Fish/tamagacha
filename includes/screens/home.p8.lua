
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
   { name = "collection", sprite = 20 },
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
   elseif pet and sel == 9 then
    load("collection.p8", "exit")
    load("collection.p8.png", "exit")
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
   circfill(67.5 - 3.5 * #pets + 7 * (i - 1), 105, 2, i == current_pet and 7 or 5)
  end

  rect_vec(sel_glider - vec2_1, vec2_9, 10, false, true)
 end
end