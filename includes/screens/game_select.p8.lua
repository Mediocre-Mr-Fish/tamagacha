do
 screens.game_select = classfactory__gridmenu({
  x = 8, y = 8, dx = 60, w = 2, h = 2,
  selectables = {}
 })
 local _ENV, scn = rescope(screens.game_select, _ENV)

 for file in all(files_games) do
  file = is_cart(file)
  if file then
   local grim = sub(file, 1, 1) == "_"
   add(
    selectables, {
     name = sub(file, grim and 2 or 1, -4),
     file = file,
     grim = grim
    }
   )
  end
 end
 assert(#selectables > 0, "no game carts found.")
 h = (#selectables + 1) \ 2
 dy = 120 \ h
 panel_h = dy - 8

 function update()
  local _, game = update_sel(scn)
  glide(scn)

  if btnp(🅾️) then
   switch_screen()
  elseif btnp(❎) then
   if settings.grim or not game.grim then
    local file = (IS_HTML and "" or "games/") .. game.file
    load(file, "exit")
    load(file .. ".png", "exit")
   else
    sfx(0)
   end
  end
 end
 function screens.game_select:draw()
  fillp(█)
  for i, game in ipairs(selectables) do
   local x, y = grid_vec(scn, i):unpack()
   local shown = (settings.grim or not game.grim)

   draw_panel(shown and game.name or "n/a", x, y, 52, panel_h, shown and 3 or 5)
  end
  rect_vec(sel_glider, vec2.new(52, panel_h), 10, false, true)
 end
 function draw_panel(label, x, y, w, h, col)
  rectfill(x, y, x + w, y + h, col)
  print_centered(label, x + w \ 2, y + h \ 2 - 3, 7)
 end
end