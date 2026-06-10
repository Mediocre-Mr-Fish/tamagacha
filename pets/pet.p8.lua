-- encode pet data in the sprite sheet
-- to save the data:
--   run cart
--   save label with f7
--   in a text editor, remove the __gfx__ section and rename __label__ to __gfx__

local black = 0
local navy = 1
local purple = 2
local green = 3
local brown = 4
local gray = 5
local light_gray = 6
local white = 7
local red = 8
local orange = 9
local yellow = 10
local lime = 11
local light_blue = 12
local blue = 13
local pink = 14
local beige = 15

-- requires:
--  helper_functions

-- MARK: rescope
function rescope(scope, env)
 return setmetatable(
  {}, {
   __index = function(_, k) return scope[k] or env[k] end,
   __newindex = scope
  }
 ), scope
end

byte_streamer = {}

do
 local _ENV = rescope(byte_streamer, _ENV)
 -- source = nil
 -- offset = 0
 -- source can be:
 --   integer: location in memory
 --   string: an ascii string
 --   table: a list of integers

 function set_source(src, pos)
  source, offset = src, pos or 0
 end

 function write(...)
  assert(source)

  local bytes = { ... }
  if type(source) == "number" then
   poke(source + offset, ...)
  elseif type(source) == "string" then
   source = sub(source, 1, offset) .. chr(...) .. sub(source, offset + #bytes + 1)
  elseif type(source) == "table" then
   for i, byte in ipairs(bytes) do
    source[offset + i] = byte
   end
  end
  offset += #bytes
 end

 function read(num)
  assert(source)
  local o = offset
  num = num or 1
  offset += num
  if type(source) == "number" then
   return peek(source + o, num)
  elseif type(source) == "string" then
   return ord(source, o + 1, num)
  elseif type(source) == "table" then
   local ret = {}
   for i = 1, num do
    add(ret, source[o + i])
   end
   return unpack(ret)
  end
 end

 function write_str(str, fixed_length)
  if (not fixed_length) write(#str)
  write(ord(str, 1, fixed_length or #str))
 end

 function read_str(fixed_length)
  return chr(read(fixed_length or read()))
 end

 function write_bin(bin_tbl)
  local num = 0
  for i = 0, 7 do
   num += (bin_tbl[i + 1] and 1 << i or 0)
  end
  write(num)
 end

 function read_bin()
  local num = read()
  local ret = {}
  for i = 0, 7 do
   ret[i + 1] = num & 1 << i ~= 0
  end
  return ret
 end
end

function _init()
 pet = pet
 byte_streamer.set_source(0x0)

 write = byte_streamer.write
 write_str = byte_streamer.write_str

 -- type 3 = pet
 write(3)

 write(#pet.spr_maps)
 for spr_map in all(pet.spr_maps) do
  write(spr_map.x, spr_map.y, spr_map.w, spr_map.h)
  write_str(spr_map.key)
 end

 write(pet.transparent, pet.immortal, pet.rarity, pet.meat, pet.bone)

 write(#pet.variants)
 for v, variant in ipairs(pet.variants) do
  for i = 0, 15 do
   write((variant[i] or i))
  end
  write(variant.weight or 1)
  write_str(variant.name)
 end

 local bytestr = ""
 for i = 0, byte_streamer.offset - 1 do
  if i % 64 == 0 then
   bytestr = bytestr .. "\n"
  end
  local b = tostr(peek(byte_streamer.source + i), 0x1)
  bytestr = bytestr .. sub(b, 6, 6) .. sub(b, 5, 5)
 end
 printh(bytestr)
end

function _draw()
 palt(0, false)
 spr(0, 0, 0, 16, 16)
end