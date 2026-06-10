do
 screens.settings = {
  selection = 1,
  options = {
   -- not called 'settings' to reduce confusion
   { name = "mute music", key = "mute" },
   { name = "grim mode", key = "grim" }
  }
 }
 local _ENV, scn = rescope(screens.settings, _ENV)
 function update()
  selection = grid_wrap(selection, btnp_axis(⬅️, ➡️), btnp_axis(⬆️, ⬇️), 1, 2)
  if btnp(🅾️) then
   switch_screen(not flag_skip_title() and screens.title)
  elseif btnp(❎) then
   local key = scn.options[selection].key
   -- assumes settings are boolean
   settings[key] = not settings[key]
   if settings.mute then
    play_music()
   end
  end
 end
 function draw()
  for i, option in ipairs(options) do
   local y = 20 + (i - 1) * 40
   local setting = settings[option.key]

   print_centered(option.name, 64, y, i == selection and 10 or 7)
   draw_checkbox(45, y + 14, setting)
   if i == selection then
    print_centered(">           <", 64, y, 10)
   end
  end

  spr_scaled(16, 62, 30, 2, 1, 1)
  if settings.mute then
   -- red x
   line(75, 35, 81, 41, 8)
   line(75, 41, 81, 35)
  else
   -- white sound waves
   line(76, 35, 76, 41, 7)
   line(79, 32, 79, 44)
  end

  if settings.grim then
   -- bloody
   pal(6, 8)
   print("✽", 67, 81, 8)
   print("★", 71, 78, 2)
  end
  spr_scaled(50, 64, 70, 2, 1, 1)
  pal()

  print_centered("❎ select  🅾️ exit", 64, 110, 5)
 end
 function screens.settings.draw_checkbox(x, y, checked)
  rect(x, y, x + 8, y + 8, 7)
  if checked then
   print("🐱", x + 1, y + 2, 8)
  end
 end
end