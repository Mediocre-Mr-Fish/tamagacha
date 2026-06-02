
function rescope(scope, env)
 return setmetatable(
  {}, {
   __index = function(_, k) return scope[k] or env[k] end,
   __newindex = scope
  }
 ), scope
end

function mod(a, b)
 return (a - 1) % b + 1
end

function btnp_axis(neg, pos)
 if (btnp(neg) ~= btnp(pos)) return btnp(pos) and 1 or -1
 return 0
end

function grid_coords(x1, y1, dx, dy, val, cols)
 return x1 + dx * ((val - 1) % cols), y1 + dy * ((val - 1) \ cols)
end

function grid_wrap(val, dx, dy, width, height)
 row = ((val - 1) \ width + dy) % height
 col = ((val - 1) % width + dx) % width
 return row * width + col + 1
end

function spr_scaled(n, x, y, scale, sw, sh, fh, fv)
 scale = scale or 1
 sw, sh = (sw or 1) * 8, (sh or 1) * 8
 sspr(n % 16 * 8, n \ 16 * 8, sw, sh, x, y, sw * scale, sh * scale, fh, fv)
end

-- toggle a value bewteen two presets
function toggle_val(val, target, fallback)
 return val == target and fallback or target
end

function accelerp(x0, v0, a, t)
 return x0 + v0 * t + a * t * t / 2
end
function lerp(a, b, t)
 return a + t * (b - a)
end
function rngf(a, b)
 return lerp(a, b, rnd())
end

function pad(str, len)
 str = tostring(str)
 while #str < (len or 2) do
  str = " " .. str
 end
 return str
end

function print_centered(text, x, y, col)
 if (col) color(col)
 print(text, x - print(text, 0, -8) / 2, y)
end

function draw_triangle(x1, y1, x2, y2, x3, y3, col)
 if (col) color(col)
 line(x1, y1, x2, y2)
 line(x3, y3)
 line(x1, y1)
end

---draw a rectangle with vectors
---@param pos1 vec2
---@param pos2 vec2
---@param col integer? if nil, use previous color
---@param fill boolean?
---@param as_dim boolean? if true, pos2 is relative to pos1
function rect_vec(pos1, pos2, col, fill, as_dim)
 if (col) color(col)
 if (as_dim) pos2 += pos1
 (fill and rectfill or rect)(pos1.x, pos1.y, pos2.x, pos2.y)
end
