do
 screens.title = {}
 local _ENV, scn = rescope(screens.title, _ENV)
 timeline = anim_timeline.new({})
 gore_pool = {}

 selection = 1

 function init()
  timeline:start()
  play_music("super_idol")
 end

 function update()
  local step, t = timeline:update()

  selection = mod(selection + btnp_axis(⬆️, ⬇️), 3)

  local r = rnd()
  add_particles(1, r < 0.005 and 36 or r < .01 and 54)
  update_particles()

  if btnp(❎) then
   if selection == 1 then
    flag_skip_title(true)
    switch_screen()
   elseif selection == 2 then
    switch_screen(screens.settings)
   elseif selection == 3 then
    if IS_DEMO then
     reset_data()
     run()
    else
     load("gallery.p8", "exit")
     load("gallery.p8.png", "exit")
    end
   end
  end
 end

 function draw()
  cls(12)
  if settings.grim then
   pal(12, 1)
   pal(7, 2)
   pal(6, 5)
   pal(5, 0)
   pal(4, 5)
   pal(11, 4)
  end
  asset_loader.draw_map("title_bg", 0, 0)
  pal()

  if settings.grim then
   pal(9, 2)
   pal(10, 8)
  end
  asset_loader.draw_map("title_words", 12, 16, 2)
  pal()

  if settings.grim then
   draw_particles()
  end

  print_centered("play", 64, 96, selection == 1 and 10 or 0)
  print_centered("settings", 64, 102, selection == 2 and 10 or 0)
  local opt3 = "gallery"
  if IS_DEMO then
   print_centered("demo ver.", 102, 48, 8)
   opt3 = "reset data"
  end
  print_centered(opt3, 64, 108, selection == 3 and 10 or 0)

  print_centered(">            <", 64, 90 + selection * 6, 10)
 end

 function add_particles(num, sprite)
  for _ = 1, num do
   local p = add(gore_pool, particle.new())
   p:set_pos(vec2.rng(14, 46, 114, nil))
   p:set_vel(vec2_0)
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
   if p.pos.y > 128 then
    del(gore_pool, p)
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