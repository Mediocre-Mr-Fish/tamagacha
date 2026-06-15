pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- tama-gatcha! add-on
-- asset viewer
#include includes/IS_DEMO.p8.lua
#include includes/helper_functions.p8.lua
#include includes/asset_loader.p8.lua

for _, value in ipairs({ 0, 1, 16, 17 }) do
 asset_loader.spr_allocation[value] = true
end
for _, value in ipairs({ 0 }) do
 asset_loader.sfx_allocation[value] = true
end

function capacity(alloc_tbl)
 local ret = 0
 for i = 0, alloc_tbl.max_index do
  if alloc_tbl[i] then ret = ret + 1 end
 end

 if (alloc_tbl.type == "music") then ret = ret / 4 end
 return pad(ret, #tostring(alloc_tbl.max_index + 1)) .. "/" .. tostring(alloc_tbl.max_index + 1)
end

function is_loaded(alloc_tbl, key)
 for entry in all(alloc_tbl.lru_list) do
  if (entry == key) then return true end
 end
 return false
end

function _init()
 sound_mode = true
 show_map = nil
 select = 0
 tracks = {}
 maps = {}

 for key, _ in pairs(asset_loader.music_allocation.source_list) do
  local i = 1
  while i <= #tracks and tracks[i] < key do
   i = i + 1
  end
  add(tracks, key, i)
 end
 for key, _ in pairs(asset_loader.map_allocation.source_list) do
  local i = 1
  while i <= #maps and maps[i] < key do
   i = i + 1
  end
  add(maps, key, i)
 end
end

function _update()
 if (btnp() ~= 0) then show_map = false end
 if (btnp(0) ~= btnp(1)) then
  sound_mode = not sound_mode
  sfx(0)
 end
 if btnp(2) then
  select = select - 1
  sfx(0)
 end
 if btnp(3) then
  select = select + 1
  sfx(0)
 end
 select = select % (sound_mode and #tracks or #maps)
 if (sound_mode and btnp(5)) then asset_loader.play_music(tracks[select + 1], true) end
 if btnp(4) then asset_loader.play_music(nil) end
 if (not sound_mode and btnp(5)) then show_map = maps[select + 1] end
end

function _draw()
 cls()
 if show_map then
  palt(0)
  asset_loader.draw_map(show_map, 0, 0)
  return
 end

 palt(11, true)
 sspr(0, 0, 16, 16, 96, 96, 32, 32)

 print_centered("gallery", 64, 0, 6)

 print("music:" .. capacity(asset_loader.music_allocation), 0, 18)
 print("sfx:  " .. capacity(asset_loader.sfx_allocation))
 for i, t in ipairs(tracks) do
  local color = 6
  if asset_loader.current_music() == t then
   color = 10
  elseif is_loaded(asset_loader.music_allocation, t) then
   color = 14
  end
  print((sound_mode and i == select + 1 and "> " or "  ") .. t, color)
 end

 print("map:  " .. capacity(asset_loader.map_allocation), 64, 18, 6)
 print("sprite:" .. capacity(asset_loader.spr_allocation))
 for i, m in ipairs(maps) do
  local color = 6
  if false then
   color = 10
  elseif is_loaded(asset_loader.map_allocation, m) then
   color = 14
  end
  print((not sound_mode and i == select + 1 and "> " or "  ") .. m, color)
 end

 print(
  "❎ "
    .. (sound_mode and "play" or "show")
    .. (asset_loader.current_music() and " 🅾️ stop" or ""),
  0, 112, 6
 )
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
__sfx__
000100001207001000000000000024000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
