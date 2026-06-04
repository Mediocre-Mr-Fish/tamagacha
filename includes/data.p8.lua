-- requires:
--  byte_streamer
--  class__pet
--  helper_functions

-- return boolean if the flag has been set
-- if `set` is not `nil`, set the flag, returning its original value
function flag(addr, set)
 local ret = peek(addr) ~= 0
 if (set ~= nil) poke(addr, tonum(set))
 return ret
end


function flag_skip_title(set)
 return flag(0x5000, set)
end

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

local inventory = { 0, 0, 0, 0, 0, 0 }

local pets = {}
function pets:add(pet) add(self, pet) end

--progress of minigames
local grim_progress = 0

-- MARK: load_data
function load_data()
 -- username_title_version
 if (not cartdata("real-fancy-fire_tama-gatcha_2-3")) return false
 byte_streamer.set_source(0x5e00)
 local read = byte_streamer.read

 -- user data
 local valid, mute, grim = unpack(byte_streamer.read_bin())
 if (not valid) return false
 settings.mute, settings.grim = mute, grim

 current_pet = read()

 -- currencies
 gacha_tickets, food, bones = read(3)

 -- items
 inventory = { read(6) }

 -- pets
 for i = 1, max_pets do
  local class = all_pets[byte_streamer.read_str(3)]
  -- nil or pet instance
  local pet = class and class.new()

  if pet then
   local color_variant, stats = read(2)
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
  true, settings.mute, settings.grim
 })

 write(current_pet)

 -- currencies
 write(gacha_tickets, food, bones)

 -- items
 write(unpack(inventory))

 -- pets
 for i = 1, max_pets do
  local pet = pets[i]

  if pet then
   byte_streamer.write_str(pet.id, 3)
   write(pet.variant.index, pet.hunger << 4 | pet.happiness)
  else
   write(0, 0, 0, 0, 0)
  end
 end

 printh("data saved")
end

function reset_data()
 byte_streamer.set_source(0x5e00)
 for _ = 1, 256 do
  byte_streamer.write(0)
 end
end