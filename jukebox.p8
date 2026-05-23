pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
--[[jukebox.p8
proof of concept for dynamic asset allocation
assets are allocated to free space in the cart as needed
when space is unavailable, the oldest loaded asset is unloaded
crucially, this means the assets can at any index on the source cart
--[[]]

function rescope(scope, env)
 return setmetatable(
  {}, {
   __index = function(_, k) return scope[k] or env[k] end,
   __newindex = scope
  }
 ), scope
end

do
 asset_loader = {}
 local _ENV = rescope(asset_loader, _ENV)

 loaded_file = nil
 music_last_used = {}
 music_allocation = {}
 sfx_allocation = {
  -- permanently reserve sfx here
 }

 music_list = {
  piao_piao = { file = "music/1.p8", start = 0, length = 3 },
  china = { file = "music/1.p8", start = 3, length = 1 },
  baka_mitai = { file = "music/1.p8", start = 4, length = 5 },
  binks_sake = { file = "music/main.p8", start = 0, length = 15 }
 }

 --  deallocate music
 function release_music(key)
  local sfx_released, music_released = 0, 0

  -- if no key is specified, release the oldest used music
  -- remove the key from the allocation list
  key = del(music_last_used, key or music_last_used[1])
  -- if that music wasn't allocated, abort
  if (not key) return sfx_released, music_released
  -- unmark list entry as allocated
  music_list[key].allocation = nil

  for i = 0, 63 do
   -- free all associated sfx
   if sfx_allocation[i] == key then
    sfx_allocation[i] = nil
    sfx_released += 1
   end
   -- free all associated music
   if music_allocation[i] == key then
    music_allocation[i] = nil
    music_released += 1
   end
  end

  return sfx_released, music_released
 end

 -- allocate a sfx to a free index and return that index
 -- if no space is available, try to release some music, assert if not possible
 function allocate_sfx(key)
  -- iterate through sfx allocation
  for i = 0, 63 do
   -- if unallocated:
   if not sfx_allocation[i] then
    sfx_allocation[i] = key
    return i
   end
  end

  -- attempt to release sound memory
  assert(release_music() > 0, "out of sfx space")
  return allocate_sfx(key)
 end

 -- allocate music to a free chunk and return its index
 -- if no space is available, try to release some music, assert if not possible
 function allocate_music(key, length)
  local alloc = nil

  -- iterate through music indexes
  for i = 0, 63 do
   if music_allocation[i] then
    -- reset if occupied
    alloc = nil
   else
    -- set index if free
    alloc = alloc or i
    -- check if requisite length
    if i - alloc + 1 == length then
     -- mark allocation
     for a = alloc, i do
      music_allocation[a] = key
     end

     return alloc
    end
   end
  end

  -- attempt to release sound memory
  local _, music_released = release_music()
  assert(music_released > 0, "out of music space")
  return allocate_music(key, length)
 end

 -- load music from a file
 function load_music(key)
  -- enforce that music info exists
  local info = assert(music_list[key], key)

  -- if the music has been allocated already,
  -- move it to the top of the list
  if del(music_last_used, key) then
   add(music_last_used, key)
   return info.allocation
  end

  -- use stop position if specified
  if (info.stop) info.length = info.stop - info.start + 1
  -- find space to allocate
  info.allocation = allocate_music(key, info.length)
  local alloc = 0x3100 + info.allocation * 4

  -- load the file if it isn't already
  if loaded_file ~= info.file then
   loaded_file = info.file
   -- user data 0x4300 to 0x5600

   -- load music patterns
   reload(0x4300, 0x3100, 0x0100, loaded_file)
   -- load sfx
   reload(0x4400, 0x3200, 0x1100, loaded_file)
  end

  local assigned = {}
  for i = 0, info.length - 1 do
   for p, p_byte in ipairs({ peek(0x4300 + (info.start + i) * 4, 4) }) do
    local src_sfx = p_byte & 0x3f
    local dst_sfx = src_sfx

    -- only load sfx if not muted
    if p_byte & 0x40 == 0 then
     dst_sfx = assigned[src_sfx]
     if not dst_sfx then
      dst_sfx = allocate_sfx(key)
      memcpy(0x3200 + dst_sfx * 68, 0x4400 + src_sfx * 68, 68)
      assigned[src_sfx] = dst_sfx
     end
    end
    poke(alloc + i * 4 + p - 1, p_byte & 0xc0 | dst_sfx)
   end
  end

  add(music_last_used, key)

  return info.allocation
 end

 -- return the key of the currently playing music or nil
 function current_music() return music_allocation[stat(54)] end

 -- load music and play it
 function play_music(key, force)
  if (not force and key == current_music()) return
  if (not key) return music(-1)
  music(load_music(key))
 end
end

function _init()
 select = 0
 tracks = {}
 for key, _ in pairs(asset_loader.music_list) do
  local i = 1
  while i <= #tracks and tracks[i] < key do
   i += 1
  end
  add(tracks, key, i)
 end

 function sounds_used(tbl)
  local ret = 0
  for i = 0, 63 do
   if (tbl[i]) ret += 1
  end
  return (ret < 10 and " " .. ret or ret) .. "/64"
 end
end
function _update()
 if (btnp(⬆️)) select -= 1
 if (btnp(⬇️)) select += 1
 select %= #tracks
 if (btnp(❎)) asset_loader.play_music(tracks[select + 1])
 if (btnp(🅾️)) asset_loader.play_music(nil)
end
function _draw()
 cls(0)

 palt(11, true)
 sspr(0, 0, 16, 16, 96, 96, 32, 32)

 print("music loader demo", 30, 0)
 print("music: " .. sounds_used(asset_loader.music_allocation), 0, 18)
 print("sfx:   " .. sounds_used(asset_loader.sfx_allocation))
 print("playing: " .. tostr(asset_loader.current_music()))
 for i, t in ipairs(tracks) do
  print((i == select + 1 and "> " or "  ") .. t)
 end
 print("❎ play 🅾️ stop", 0, 112)
end

__gfx__
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbb55bbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb5bb5bbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb3333b5bbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb330055bbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b9993355bbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b999333bbbbbbb7b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb33333bbbbb777b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb3333444444477b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb4444444444444b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb444444999444bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb444499944444bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbb44444444bbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
