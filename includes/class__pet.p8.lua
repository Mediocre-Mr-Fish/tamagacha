-- requires:
--  asset_loader
--  byte_streamer
--  helper_functions

all_pets = {}

max_pets = 16

class__pet = classfactory({})

function class__pet.new()
 local self = setmetatable({}, class__pet)
 self.hunger = 15
 self.happiness = 15
 self.effects = {
  hunger_prot = 0,
  happiness_prot = 0,
  hunger_2x = 0,
  happiness_2x = 0
 }
 self.variant = { index = 0, name = "default" }
 return self
end

-- set the color variant
-- set 1 for default variant, set nil for random
function class__pet:set_color(int_or_nil)
 self.variant = int_or_nil and self.variants[int_or_nil] or weighted_rnd(self.variants)
 self.name = self.variant.name
 return self
end

-- set the pet-specific palette
-- make sure to reset afterwards
function class__pet:pal(obscured)
 pal()

 if obscured then
  for i = 0, 15 do
   pal(i, 5)
  end
 else
  pal(self.variant)
 end

 palt(0, false)
 palt(self.transparent, true)
end

-- draw the pet's sprite
function class__pet:spr_scaled(key, x, y, scale, no_pal, flip_x, flip_y)
 if not no_pal then self:pal() end

 asset_loader.draw_map(self.file .. key, x, y, scale, flip_x, flip_y)

 pal()
end

function class__pet:change_hunger(delta)
 if (delta > 0 and self.effects.hunger_2x > 0) delta *= 2
 if (delta < 0 and self.effects.hunger_prot > 0) delta = 0
 self.hunger = mid(self.hunger + delta, 0, 0xf)
 return self
end
function class__pet:change_happiness(delta)
 if (delta > 0 and self.effects.happiness_2x > 0) delta *= 2
 if (delta < 0 and self.effects.happiness_prot > 0) delta = 0
 self.happiness = mid(self.happiness + delta, 0, 0xf)
 return self
end
function class__pet:update_effects(dt)
 for key, time in pairs(self.effects) do
  self.effects[key] = mid(time - dt, 0, 0xff)
 end
 return self
end

function class__pet:is_dead()
 return not self.immortal and self.hunger == 0 and self.happiness == 0
end

function class__pet.create_prefab(id, file)
 assert(asset_loader.load_file(file), file .. " not found")
 byte_streamer.set_source(0x8000)
 local read, read_str = byte_streamer.read, byte_streamer.read_str

 if (read() ~= 3) return
 local pet = {
  id = id,
  file = file,
  variants = {}
 }

 for _ = 1, read() do
  local info = { file = file }
  info.x, info.y, info.w, info.h = read(4)
  asset_loader.map_allocation.source_list[file .. read_str()] = info
 end

 pet.transparent, pet.immortal, pet.rarity, pet.meat, pet.bone = read(5)
 pet.immortal = pet.immortal ~= 0

 for v = 0, read() - 1 do
  local variant = add(pet.variants, { index = v })

  for i = 0, 15 do
   variant[i] = read()
  end

  variant.weight = read()
  variant.name = read_str()
 end

 all_pets[id] = add(all_pets, classfactory(pet, class__pet))
end

for i, file in pairs(files_pets) do
 file = is_cart(file)
 if file then
  class__pet.create_prefab(sub(file, 1, 3), "pets/" .. file)
 end
end
assert(#all_pets > 0, "no pets carts found.")