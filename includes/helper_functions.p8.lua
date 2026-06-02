-- MARK: rescope
function rescope(scope, env)
 return setmetatable(
  {}, {
   __index = function(_, k) return scope[k] or env[k] end,
   __newindex = scope
  }
 ), scope
end

-- MARK: math

function mod(a, b)
 return (a - 1) % b + 1
end

function grid_coords(x1, y1, dx, dy, val, cols)
 return x1 + dx * ((val - 1) % cols), y1 + dy * ((val - 1) \ cols)
end

function grid_wrap(val, dx, dy, width, height)
 row = ((val - 1) \ width + dy) % height
 col = ((val - 1) % width + dx) % width
 return row * width + col + 1
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

-- MARK: input

function btnp_axis(neg, pos)
 if (btnp(neg) ~= btnp(pos)) return btnp(pos) and 1 or -1
 return 0
end

-- MARK: display

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

function spr_scaled(n, x, y, scale, sw, sh, fh, fv)
 scale = scale or 1
 sw, sh = (sw or 1) * 8, (sh or 1) * 8
 sspr(n % 16 * 8, n \ 16 * 8, sw, sh, x, y, sw * scale, sh * scale, fh, fv)
end

function rect_vec(pos1, pos2, col, fill, as_dim)
 if (col) color(col)
 if (as_dim) pos2 += pos1
 (fill and rectfill or rect)(pos1.x, pos1.y, pos2.x, pos2.y)
end

function draw_triangle(x1, y1, x2, y2, x3, y3, col)
 if (col) color(col)
 line(x1, y1, x2, y2)
 line(x3, y3)
 line(x1, y1)
end

-- MARK: classes

-- a function to create pet classes
function classfactory(static_vars, parent, class_list)
 assert(not is_runtime, "classfactory should not be called at runtime.")

 local class = parent and setmetatable(static_vars, parent) or static_vars
 class.__index = class
 if class_list then
  add(class_list, class)
 end
 -- blank new() function
 -- override if instance variables are needed
 class.new = function()
  return setmetatable(parent and parent.new() or {}, class)
 end

 return class
end

-- function to check of an object the specifed class or a subclass of it
function is_instance(object, class)
 if object == class then return true end
 local metatable = getmetatable(object)

 -- follow the metatable heirarcy
 -- assumes there are no inheritance loops
 while metatable do
  if metatable == class then return true end
  metatable = getmetatable(metatable)
 end

 return false
end

-- MARK: vec2
vec2 = classfactory({})
function vec2.new(x, y) return setmetatable({ x = x, y = y or x }, vec2) end
function vec2.rng(x0, y0, x1, y1) return vec2.new(rngf(x0, x1 or x0), rngf(y0 or x0, y1 or y0 or x0)) end
function vec2.setfrom(v, a) v.x, v.y = a.x, a.y return self end
function vec2.unpack(v) return v.x, v.y end
function vec2.length2(v) return v.x * v.x + v.y * v.y end
function vec2.to_cartesian(v) return vec2.new(v.x * cos(v.y), v.x * sin(v.y)) end
function vec2.__add(a, b) return vec2.new(a.x + b.x, a.y + b.y) end
function vec2.__sub(a, b) return vec2.new(a.x - b.x, a.y - b.y) end
function vec2.__mul(a, b) if type(a) == "number" then a, b = b, a end return vec2.new(a.x * b, a.y * b) end
function vec2.__div(a, b) return vec2.new(a.x / b, a.y / b) end
function vec2.__unm(a) return vec2.new(-a.x, -a.y) end
function vec2.__eq(a, b) return a.x == b.x and a.y == b.y end
function vec2.__tostring(v) return "(" .. v.x .. "," .. v.y .. ")" end
vec2_0 = vec2.new(0)
vec2_1 = vec2.new(1)
vec2_8 = vec2.new(8)
vec2_9 = vec2.new(9)