do
 screens.title = {}
 local _ENV, scn = rescope(screens.title, _ENV)
 timeline = anim_timeline.new({})

 selection = 1
 function init()
  timeline:start()
  play_music("super_idol")
 end

 function update()
  local step, t = timeline:update()

  selection = mod(selection + btnp_axis(⬆️, ⬇️), 3)

  if btnp(❎) then
   if selection == 1 then
    flag_skip_title(true)
    switch_screen()
   elseif selection == 2 then
    switch_screen(screens.settings)
   elseif selection == 3 then
    reset_data()
    run()
   end
  end
 end

 function draw()
  if settings.grim then
   pal(12, 1)
   pal(7, 8)
   pal(6, 5)
   pal(5, 0)
   pal(4, 5)
   pal(11, 4)
  end
  asset_loader.draw_map("title", 0, 0)
  pal()
  print_centered("play", 64, 96, selection == 1 and 10 or 0)
  print_centered("settings", 64, 102, selection == 2 and 10 or 0)
  print_centered("reset data", 64, 108, selection == 3 and 10 or 0)
  print_centered(">            <", 64, 90 + selection * 6, 10)
 end
end