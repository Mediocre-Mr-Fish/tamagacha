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