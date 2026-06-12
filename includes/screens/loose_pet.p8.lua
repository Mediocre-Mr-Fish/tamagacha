-- MARK: loose_pet
do
 screens.loose_pet = {}
 local _ENV = rescope(screens.loose_pet, _ENV)
 function with(self, pet_, force)
  pet = pet_
  target = force or decide(pet)
  return self
 end
 function init()
  if (target) target.pet = pet
  switch_screen(target)

  if pet.happiness > 0 then
   food += pet.meat * 4
   bones += pet.bone
  end

  pet = nil
  play_music()
  asset_loader.load_music("baka_mitai")
 end
 function decide(pet)
  if (pet.immortal) return screens.abandon
  if (not settings.grim) return screens.abandon
  if (pet.happiness == 0) return screens.talljump
  return screens.blender
 end
end
-- MARK: abandon
do
 screens.abandon = {
  timeline = anim_timeline.new({})
 }
 local _ENV = rescope(screens.abandon, _ENV)
 function init()
  _ENV.timeline:start()
 end
 function update()
  local step, t = timeline:update()
  if t > 4 and btnp(🅾️) then
   switch_screen()
  end
 end
 function draw()
  local step, t = timeline:get()
  local x = accelerp(24, 50, 0, t)
  pal()
  clip(0, 0, x + 8, 128)
  print_centered(pet.name .. " has left you", 64, 60, 6)
  clip()
  circfill(x + 2, 52, 4, 8)
  for i = 0, 2 do
   line(x + 2, 48 + i, x + 22, 68 + i, 4)
  end

  pet:spr_scaled("thumbnail", x, 44, 2, false, true, false)
  if t > 4 then
   asset_loader.play_music("baka_mitai")
   if pet.happiness > 0 then
    print("you received: " .. (pet.meat * 4) .. "   " .. pad(pet.bone), 16, 70, 6)
    spr(36, 82, 68)
    spr(bone_censor(), 102, 68)
   end

   print_centered("🅾️ exit", 64, 110, 5)
  end
 end
end
-- MARK: talljump
do
 screens.talljump = {
  timeline = anim_timeline.new({ 1, 1.5, 2, 60, 6, 1 })
 }
 local _ENV = rescope(screens.talljump, _ENV)
 function init()
  timeline:start()
  gore_pool = {}
  splash = false
  y4 = 0
  asset_loader.load_map("tower_ground")
 end
 function update()
  local step, t = timeline:update()

  if #gore_pool < 2100 then
   for i = 1, 100 do
    local p = add(gore_pool, particle.new())
    p:set_pos(vec2.rng(80, 96, 96, nil))
    local vel = vec2.rng(1, 0, 7, 1):to_cartesian()
    if i < 25 then
     vel.y = -abs(vel.y)
     vel.x *= 0.4
    end
    vel.y *= abs(vel.y) * 0.5

    p:set_vel(vel)
    p:set_acc(vec2.new(0, 0.1))
   end
  end

  if step == 4 then
   if y4 > 88 then
    timeline:start(5)
   end
  elseif step >= 5 then
   for p in all(gore_pool) do
    if p.pos.y < -32 then
     p.vel.x *= 0.1
     p.vel.y = min(p.vel.y, 10)
    end

    if p.pos.y > 96 and rnd() < 0.75 then
     p:stop()
    end
    if p.pos.x < 48 and rnd() < 0.5 then
     p:stop()
    end
    p:update()
   end

   if step == 6 then
    play_music("baka_mitai")
   elseif step == 7 then
    if btnp(🅾️) then
     switch_screen()
    end
   end
  end
 end
 function draw()
  cls(12)
  local step, t = timeline:get()
  local draw_map = asset_loader.draw_map

  if step <= 2 then
   palt()
   spr_scaled(62, 16, 16, 1, 2, 1)
   spr_scaled(62, 96, 20, 1, 2, 1)
   local x, y = 48, 50
   if step == 2 then x, y = accelerp(48, 50, -25, t), accelerp(50, -50, 200, t) end
   pet:spr_scaled("thumbnail", x, y, 1, false, true, false)
   palt(0x0010)
   draw_map("tower_segment", 0, 62)
   draw_map("tower_segment", 0, 102)
  end

  if step == 3 then
   palt(0x0010)
   for i = 0, 5 do
    draw_map("tower_segment", 0, i * 40 - (t * 240) % 40)
   end
   pet:spr_scaled(
    "thumbnail",
    88,
    accelerp(32, 32, 0, t),
    1, false, true, false
   )
  elseif step >= 4 then
   if step == 4 then
    y4 = accelerp(-128, 256 * 4, 0, t)
    pet:spr_scaled("thumbnail", 80, y4, 1, false, true, false)
   end

   palt(0x0010)
   draw_map("tower_segment", -16, -24)
   draw_map("tower_segment", -16, 16)
   draw_map("tower_ground", 0, 56)

   if step >= 5 then
    -- draw particles
    for particle in all(gore_pool) do
     pset(particle.pos.x, particle.pos.y, 8)
    end
   end

   if step >= 6 then
    print_centered(pet.name .. " was sad.", 90, 48, 7)
   end
   if step == 7 then
    print_centered("🅾️ exit", 64, 109, 6)
   end
  end
 end
end
-- MARK: blender
do
 screens.blender = {
  timeline = anim_timeline.new({ 1, 0.5, 1.5, 1.5, 3 }),
  frame = 1
 }
 local _ENV = rescope(screens.blender, _ENV)
 function init()
  timeline:start()
  gore_pool = {}
  splash = false
 end
 function update()
  local step, t = timeline:update()

  if step >= 2 and step < 5 then
   update_particles()
   add_particles(2)
   sfx(2)
  elseif step == 5 then
   if not splash then
    splash = true
    add_particles(80)
    add_particles(pet.meat, 36)
    add_particles(pet.bone, 54)
   end
   update_particles()
  elseif step == 6 then
   asset_loader.play_music("baka_mitai")
   if btnp(🅾️) then
    switch_screen()
   end
  end
 end
 function draw()
  local step, t = timeline:get()

  draw_blender(55 + frame % 2, 52, step)

  if step == 1 then
   clip(0, 0, 128, 52)
   pet:spr_scaled("thumbnail", 56, accelerp(-16, 20, 100, t))
   clip()
  elseif step >= 2 then
   draw_particles()
   if (step < 5) frame += 1
  end
  if (step > 5) print_centered("🅾️ exit", 64, 110, 5)
 end
 function draw_blender(x, y, step)
  pal()
  if step >= 4 then
   pal(6, 8)
  elseif step == 3 then
   pal(6, 14)
  end

  palt(0x0010)
  spr_scaled(14, x, y, 1, 2, 3)
 end
 function add_particles(num, sprite)
  for _ = 1, num do
   local p = add(gore_pool, particle.new())
   p:set_pos(vec2.rng(56, 51, 72, nil))
   p:set_vel(vec2.rng(-0.75, -1.75, 0.75, -0.5))
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
   if p.pos.y > 76 then
    p.pos.y = 76
    p:stop()
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
-- MARK: bomb
do
 screens.bomb = {
  timeline = anim_timeline.new({ 2, 1 })
 }
 local _ENV = rescope(screens.bomb, _ENV)
 function init()
  timeline:start()
  gore_pool = {}
  splash = false
  explodes = settings.grim and not pet.immortal
 end
 function update()
  local step, t = timeline:update()

  if step > 2 then
   if explodes and not splash then
    splash = true
    sfx(3)
    add_particles(1000)
    add_particles(pet.bone * 2, 54)
   end
   update_particles()
  end

  if step == 3 and t > 5 then
   play_music("baka_mitai")
   if btnp(🅾️) then
    switch_screen()
   end
  end
 end
 function draw()
  local step, t = timeline:get()

  if step == 1 then
   pet:spr_scaled("thumbnail", 64, 56)
   spr(51, accelerp(-8, 64, -32, t), 64)
  elseif step == 2 then
   pet:spr_scaled("thumbnail", 64, 56)
   spr(51, 56, 64)
  elseif step == 3 then
   if explodes then
    draw_particles()
   else
    spr(51, 56, 64)
    pet:spr_scaled("thumbnail", accelerp(64, 32, 0, t), 56, 1, nil, true)
   end
   if t > 3 then
    print_centered(pet.name .. " did not like that.", 64, 80, 7)
   end
   if t > 5 then
    print_centered("🅾️ exit", 64, 110, 5)
   end
  end
 end
 function add_particles(num, sprite)
  for _ = 1, num do
   local p = add(gore_pool, particle.new())
   p:set_pos(vec2.new(72, 60) + vec2.rng(0, 0, 8, 1):to_cartesian())
   p:set_vel(p.pos - vec2.new(64))
   p:set_acc(vec2.new(0, 0.1))
   if sprite then
    p.vel /= 4
    p.sprite = sprite
    p.flip = rnd() < 0.5
   end
  end
 end
 function update_particles()
  for p in all(gore_pool) do
   p:update()
   if p.pos.y > 76 then
    p.pos.y = 76
    p:stop()
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