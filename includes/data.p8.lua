-- requires:
--  byte_streamer
--  class__pet
--  helper_functions


-- MARK: data

local settings = {
 --optional turn sound off
 mute = false,
 --optionally reveal the blender heh
 grim = false
}

local current_pet = 1

local gacha_tickets = 3
local food = 5
local bones = 0

local pets = {}
function pets:add(pet) add(self, pet) end
pets:add(all_pets[1].new():set_color())

--progress of minigames
local grim_progress = 0

-- MARK: load_data
function load_data()
 -- username_title_version
 if (not cartdata("real-fancy-fire_tama-gatcha_2-1")) return false
 byte_streamer.set_source(0x5e00)
 local read = byte_streamer.read

 -- user data
 settings.mute, settings.grim = unpack(byte_streamer.read_bin())

 current_pet = read()

 -- currencies
 gacha_tickets, food, bones = read(3)

 -- items
 for item in all(all_items) do
  item.count = read()
 end

 -- pets
 for i = 1, max_pets do
  local id, color_variant, stats = read(3)
  local class = all_pets[id]
  -- nil or pet instance
  local pet = class and class.new()
  if pet then
   pet:set_color(color_variant + 1)
   pet.hunger = stats \ 0xf
   pet.happiness = stats & 0xf
  end
  pets[i] = pet
 end

 printh("data loaded")
 return true
end

-- MARK: save_data
function save_data()
 byte_streamer.set_source(0x5e00)
 local write = byte_streamer.write

 -- user settings
 byte_streamer.write_bin({
  settings.mute, settings.grim
 })

 write(current_pet)

 -- currencies
 write(gacha_tickets, food, bones)

 -- items
 for item in all(all_items) do
  write(item.count)
 end

 -- pets
 for i = 1, max_pets do
  local pet = pets[i]

  if pet then
   write(pet.id, pet.variant.index, pet.hunger << 4 | pet.happiness)
  else
   write(0, 0, 0)
  end
 end

 printh("data saved")
end