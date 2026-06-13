pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- tama-gatcha! add-on
-- save editor
#include includes/IS_HTML.p8.lua
#include includes/helper_functions.p8.lua
#include includes/asset_loader.p8.lua
#include includes/byte_streamer.p8.lua
#include includes/class__pet.p8.lua
#include includes/data.p8.lua

local unsaved = false
local changes = {}

function or_call(val_or_func)
 if type(val_or_func) == "function" then
  return val_or_func()
 end
 return val_or_func
end

function contigify_pets()
 local dst = 1
 for src = 1, max_pets do
  if pets[src] then
   if dst ~= src then pets[dst], pets[src] = pets[src], nil end
   dst += 1
  end
 end
end

local tabs = {
 "data",
 "settings",
 "currency",
 "inventory",
 data = {
  "reload data",
  "save data",
  -- "reset data",
  ["reload data"] = {
   type = "button",
   desc = "discard changes",
   set = function()
    load_data()
    unsaved = false
    changes = {}
   end
  },
  ["save data"] = {
   type = "button",
   desc = "save changes",
   set = function()
    contigify_pets()
    save_data()
    unsaved = false
    changes = {}
   end
  },
  ["reset data"] = {
   type = "button",
   set = function()
    reset_data()
    unsaved = false
    changes = {}
   end
  }
 },
 settings = {
  "data_is_valid",
  "mute",
  "grim",
  "current_pet",
  data_is_valid = {
   type = "boolean",
   get = function() return data_is_valid end,
   set = function(v) data_is_valid = v end,
   desc = "if false, use default data\non next boot"
  },
  mute = {
   type = "boolean",
   get = function() return settings.mute end,
   set = function(v) settings.mute = v end,
   desc = "mute music\nsfx not affected"
  },
  grim = {
   type = "boolean",
   get = function() return settings.grim end,
   set = function(v) settings.grim = v end,
   desc = "use gruesome pet deaths\nand enable secret minigame"
  },
  current_pet = {
   type = "number",
   min = 1,
   max = 16,
   get = function() return current_pet end,
   set = function(v) current_pet = v end,
   desc = "the currently selected pet"
  }
 },
 currency = {
  "food",
  "tickets",
  "bones",
  food = {
   type = "number",
   desc = "food to feed pets with",
   min = 0,
   max = 255,
   step = 16,
   get = function() return food end,
   set = function(v) food = v end
  },
  tickets = {
   type = "number",
   desc = "tickets to roll gacha with",
   min = 0,
   max = 255,
   step = 16,
   get = function() return gacha_tickets end,
   set = function(v) gacha_tickets = v end
  },
  bones = {
   type = "number",
   desc = "bones to boost gacha chances with",
   min = 0,
   max = 255,
   step = 16,
   get = function() return bones end,
   set = function(v) bones = v end
  }
 },
 inventory = {
  "chocolate",
  "banana",
  "meatball",
  "rice",
  "drumstick",
  "bomb",
  chocolate = {
   type = "number",
   desc = "prevents happiness reduction\nfor 60 seconds",
   min = 0,
   max = 255,
   step = 16,
   get = function() return inventory[1] end,
   set = function(v) inventory[1] = v end
  },
  banana = {
   type = "number",
   desc = "doubles happiness gain\nfor 60 seconds",
   min = 0,
   max = 255,
   step = 16,
   get = function() return inventory[2] end,
   set = function(v) inventory[2] = v end
  },
  meatball = {
   type = "number",
   desc = "doubles hunger gain\nfor 60 seconds",
   min = 0,
   max = 255,
   step = 16,
   get = function() return inventory[3] end,
   set = function(v) inventory[3] = v end
  },
  rice = {
   type = "number",
   desc = "fill hunger to maximum",
   min = 0,
   max = 255,
   step = 16,
   get = function() return inventory[4] end,
   set = function(v) inventory[4] = v end
  },
  drumstick = {
   type = "number",
   desc = "prevents hunger reduction\nfor 60 seconds",
   min = 0,
   max = 255,
   step = 16,
   get = function() return inventory[5] end,
   set = function(v) inventory[5] = v end
  },
  bomb = {
   type = "number",
   desc = "kills the current pet\ndouble bones but no meat",
   min = 0,
   max = 255,
   step = 16,
   get = function() return inventory[6] end,
   set = function(v) inventory[6] = v end
  }
 }
}

local pets_enum = { "[none]", ["[none]"] = 1 }
for i, pet in ipairs(all_pets) do
 add(pets_enum, pet.id)
 pets_enum[pet.id] = i + 1
end

for i = 1, max_pets do
 add(tabs, "pet" .. i)
 tabs["pet" .. i] = {
  "id",
  "variant",
  "hunger",
  "happiness",
  id = {
   type = "enum",
   desc = "the id of the pet\n\"[none]\" removes the pet",
   values = pets_enum,
   get = function() return (pets[i] or { id = "[none]" }).id end,
   set = function(v)
    if v == "[none]" then
     pets[i] = nil
    else
     pets[i] = all_pets[v].new()
    end
   end
  },
  variant = {
   type = "number",
   desc = "color variant of the pet",
   min = 0,
   max = function()
    return pets[i] and (#pets[i].variants - 1) or 0
   end,
   step = 4,
   get = function() return pets[i] and pets[i].variant.index or 0 end,
   set = function(v)
    if pets[i] then
     pets[i]:set_color(v + 1)
    end
   end
  },
  hunger = {
   type = "number",
   desc = "current hunger value of the pet",
   min = 0,
   max = 15,
   step = 4,
   get = function() return pets[i] and pets[i].hunger or 0 end,
   set = function(v)
    if pets[i] then
     pets[i].hunger = v
    end
   end
  },
  happiness = {
   type = "number",
   desc = "current happiness value of the pet",
   min = 0,
   max = 15,
   step = 4,
   get = function() return pets[i] and pets[i].happiness or 0 end,
   set = function(v)
    if pets[i] then
     pets[i].happiness = v
    end
   end
  }
 }
end

function hybrid_get(tbl, index)
 return tbl[index], tbl[tbl[index]]
end

local tab_sel = 1
local opt_sel = 1
local c_val = nil

function _init()
 load_data()
end

function _update()
 local tab_name, tab = hybrid_get(tabs, tab_sel)
 local opt_name, opt = hybrid_get(tab, opt_sel)

 if c_val == nil then
  -- unselected
  tab_sel = mod(tab_sel + btnp_axis(0, 1), #tabs)
  opt_sel = mod(opt_sel + btnp_axis(2, 3), #tab)

  if btnp(5) then
   -- set to current value
   if opt.type == "button" then
    opt.set()
   else
    c_val = opt.get()
   end
  end
 else
  -- selected
  if btnp(4) then
   -- cancel change
   c_val = nil
  elseif btnp(5) then
   -- confirm change
   if c_val ~= opt.get() then
    -- if different, mark changed
    opt.set(c_val)
    changes[opt] = true
    unsaved = true
   end
   c_val = nil
  end

  local h, v = btnp_axis(0, 1), btnp_axis(3, 2)

  if c_val ~= nil then
   if opt.type == "boolean" then
    if h ~= 0 or v ~= 0 then
     c_val = not c_val
    end
   elseif opt.type == "number" then
    c_val += v + h * (opt.step or 1)

    if c_val > or_call(opt.max) then c_val = or_call(opt.min) end
    if c_val < or_call(opt.min) then c_val = or_call(opt.max) end
   elseif opt.type == "enum" then
    local i = opt.values[c_val]
    i = mod(i + v, #opt.values)
    c_val = opt.values[i]
   end
  end
 end
end

function _draw()
 cls(1)
 print(unsaved and "unsaved" or "", 8)

 local tab_name = tabs[tab_sel]
 local tab = tabs[tab_name]
 print(tab_name, 6)
 print("")

 local changing = c_val ~= nil
 for i, opt_name in ipairs(tab) do
  local opt = tab[opt_name]
  local selected = i == opt_sel

  local selector = selected and "> " or "  "
  local value = ""

  if opt.type ~= "button" then
   value = ": "
   if selected and changing then
    value ..= tostr(c_val)
   else
    value ..= tostr(opt.get())
   end
  end

  local color = selected and changing and 10 or changes[opt] and 14 or 6
  print(selector .. opt_name .. value, color)
 end

 local _, b = hybrid_get(tab, opt_sel)
 if (b) print(b.desc, 0, 96, 6)
end

function pet_menu()
end
