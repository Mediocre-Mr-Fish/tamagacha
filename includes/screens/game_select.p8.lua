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
    load("games/" .. game.key .. ".p8", "exit")
    load("games/" .. game.key .. ".p8.png", "exit")
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
