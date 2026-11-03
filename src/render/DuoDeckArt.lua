-- Hardware-style art for the foldable control deck (src/core/DuoPosture.lua).
--
-- Every piece is drawn by one signed-distance-field shader instead of from
-- bitmaps, so it is crisp at any size and density (the Duo's 3x panels, a
-- desktop preview) and every edge is antialiased.  The look is a handheld's
-- face: a soft-touch shell with a faint grain, a recessed well under a
-- charcoal cross pad, domed berry-red A/B keys with a specular highlight,
-- and angled rubber START/SELECT pills.  Presses sink the key, flatten its
-- shadow and darken it, so a thumb can feel where it landed.
--
-- Pure presentation: TouchControls still owns layout, hit testing and input.

local DeckArt = {}

local SHADER_SRC = [[
uniform vec2 center;      // control centre, pixels
uniform vec2 halfSize;    // half extents, pixels
uniform float radius;     // corner radius, pixels
uniform float angle;      // rotation, radians
uniform float mode;       // 0 shell, 1 well, 2 cross, 3 dome, 4 pill, 5 shoulder, 6 slot
uniform float pressed;    // 0..1
uniform vec3 base;        // body colour
uniform float dir;        // cross: held arm 0 none, 1 up, 2 right, 3 down, 4 left
uniform float px;         // one LOVE unit in pixels (antialias width)

float sdBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec2 p = sc - center;
  float c = cos(angle), s = sin(angle);
  p = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
  float aa = max(1.0, px * 0.6);
  vec3 col = base;
  float d;
  float alpha;

  if (mode < 0.5) {
    // shell: soft-touch plastic, vertical sheen, faint grain, lit rim
    d = sdBox(p, halfSize, radius);
    float t = clamp((p.y + halfSize.y) / (2.0 * halfSize.y), 0.0, 1.0);
    col = base * (1.10 - 0.22 * t);
    col += (hash(floor(sc)) - 0.5) * 0.018;
    float rim = smoothstep(-3.0 * px, -0.5 * px, d) * step(p.y, 0.0);
    col += rim * 0.10 * (1.0 - t);
    float inner = smoothstep(-6.0 * px, 0.0, d) * step(0.0, p.y);
    col -= inner * 0.05;
    alpha = clamp(0.5 - d / aa, 0.0, 1.0);
    return vec4(col, alpha * color.a);
  }

  if (mode < 1.5) {
    // recessed well: darker floor, shadow on the upper lip, light on the lower
    d = length(p) - halfSize.x;
    float r = halfSize.x;
    col = base * 0.72;
    float lip = smoothstep(-0.16 * r, 0.0, d);
    float upper = clamp(-p.y / r, 0.0, 1.0);
    col -= lip * upper * 0.10;
    col += lip * clamp(p.y / r, 0.0, 1.0) * 0.08;
    alpha = clamp(0.5 - d / aa, 0.0, 1.0);
    return vec4(col, alpha * color.a);
  }

  if (mode < 2.5) {
    // cross pad: union of two rounded bars, bevel lit from the top-left,
    // the held arm rocks down (darker, light from the other side)
    float arm = halfSize.x;
    float w = arm * 0.36;
    float r = w * 0.28;
    float dH = sdBox(p, vec2(arm, w), r);
    float dV = sdBox(p, vec2(w, arm), r);
    d = min(dH, dV);
    // drop shadow first
    float sh = min(sdBox(p - vec2(0.0, 0.06 * arm), vec2(arm, w), r),
                   sdBox(p - vec2(0.0, 0.06 * arm), vec2(w, arm), r));
    float shadow = (1.0 - smoothstep(-0.02 * arm, 0.10 * arm, sh)) * 0.55 * (1.0 - pressed * 0.5);
    float edge = smoothstep(-0.16 * w, 0.0, d);
    vec2 n = normalize(p + vec2(0.0001));
    float light = dot(n, normalize(vec2(-0.6, -0.8)));
    col = base * (1.0 + 0.10 * (-p.y / arm));
    col += edge * light * 0.16;
    // concave centre dimple
    float dimple = smoothstep(w * 0.85, w * 0.15, length(p));
    col -= dimple * 0.06 * (0.5 - p.y / w);
    // embossed arrows, one per arm
    vec2 a = abs(p);
    float onArmV = step(a.x, w) * step(w, a.y);
    float onArmH = step(a.y, w) * step(w, a.x);
    float tipV = sdBox(vec2(a.x, a.y - arm * 0.72), vec2(w * 0.32 * (1.0 - (a.y - arm * 0.6) / (arm * 0.25)), arm * 0.08), 0.0);
    float tipH = sdBox(vec2(a.x - arm * 0.72, a.y), vec2(arm * 0.08, w * 0.32 * (1.0 - (a.x - arm * 0.6) / (arm * 0.25))), 0.0);
    float arrow = max(onArmV * (1.0 - smoothstep(-aa, aa, tipV)),
                      onArmH * (1.0 - smoothstep(-aa, aa, tipH)));
    col += arrow * 0.09;
    // held arm
    float held = 0.0;
    if (dir > 0.5 && dir < 1.5) held = onArmV * step(p.y, 0.0);
    if (dir > 1.5 && dir < 2.5) held = onArmH * step(0.0, p.x);
    if (dir > 2.5 && dir < 3.5) held = onArmV * step(0.0, p.y);
    if (dir > 3.5) held = onArmH * step(p.x, 0.0);
    col = mix(col, col * 0.5, held);
    col += held * edge * 0.05;
    float body = clamp(0.5 - d / aa, 0.0, 1.0);
    return vec4(col * body, max(body, shadow) * color.a);
  }

  if (mode < 3.5) {
    // domed key: radial body, rim shade, specular highlight, contact shadow
    float r = halfSize.x * (1.0 - 0.04 * pressed);
    vec2 q = p - vec2(0.0, 0.03 * r * pressed);
    d = length(q) - r;
    float sh = length(p - vec2(0.0, r * mix(0.10, 0.04, pressed))) - r;
    float shadow = (1.0 - smoothstep(-0.05 * r, 0.16 * r, sh)) * mix(0.55, 0.30, pressed);
    float t = length(q) / r;
    col = base * (1.08 - 0.25 * t * t);
    col -= smoothstep(0.80, 1.0, t) * 0.10;
    col *= (1.0 - 0.26 * pressed);
    // light from the top-left, a soft spec blob
    vec2 hp = q - vec2(-0.32 * r, -0.38 * r);
    float spec = exp(-dot(hp, hp) / (0.07 * r * r));
    col += spec * 0.30 * (1.0 - 0.6 * pressed);
    // thin lit rim along the bottom
    col += smoothstep(0.86, 0.98, t) * clamp(q.y / r, 0.0, 1.0) * 0.10;
    float body = clamp(0.5 - d / aa, 0.0, 1.0);
    return vec4(col * body, max(body, shadow) * color.a);
  }

  if (mode < 4.5) {
    // rubber pill (START / SELECT): matte, soft top light
    vec2 hs = halfSize * (1.0 - 0.05 * pressed);
    d = sdBox(p, hs, hs.y);
    float sh = sdBox(p - vec2(0.0, hs.y * 0.25), hs, hs.y);
    float shadow = (1.0 - smoothstep(-0.1 * hs.y, 0.5 * hs.y, sh)) * 0.45;
    float t = clamp((p.y + hs.y) / (2.0 * hs.y), 0.0, 1.0);
    col = base * (1.12 - 0.30 * t) * (1.0 - 0.18 * pressed);
    col += smoothstep(-0.25 * hs.y, 0.0, d) * (1.0 - t) * 0.08;
    float body = clamp(0.5 - d / aa, 0.0, 1.0);
    return vec4(col * body, max(body, shadow) * color.a);
  }

  if (mode > 5.5) {
    // speaker slot: a groove cut into the shell, lit on its lower lip
    d = sdBox(p, halfSize, halfSize.y);
    float t = clamp((p.y + halfSize.y) / (2.0 * halfSize.y), 0.0, 1.0);
    col = base * (0.35 + 0.25 * t);
    col += smoothstep(-0.3 * halfSize.y, 0.0, d) * t * 0.10;
    alpha = clamp(0.5 - d / aa, 0.0, 1.0);
    return vec4(col, alpha * color.a);
  }

  // shoulder key: wide rounded slab with a lit top edge
  vec2 hs = halfSize * (1.0 - 0.03 * pressed);
  d = sdBox(p, hs, radius);
  float sh = sdBox(p - vec2(0.0, hs.y * 0.18), hs, radius);
  float shadow = (1.0 - smoothstep(-0.1 * hs.y, 0.4 * hs.y, sh)) * 0.45;
  float t = clamp((p.y + hs.y) / (2.0 * hs.y), 0.0, 1.0);
  col = base * (1.15 - 0.30 * t) * (1.0 - 0.18 * pressed);
  col += smoothstep(-0.2 * hs.y, 0.0, d) * (1.0 - t) * 0.12;
  float body = clamp(0.5 - d / aa, 0.0, 1.0);
  return vec4(col * body, max(body, shadow) * color.a);
}
]]

-- palette: graphite shell, charcoal cross, berry keys, warm-grey rubber
DeckArt.PALETTE = {
  shell = { 0.155, 0.162, 0.185 },
  well = { 0.155, 0.162, 0.185 },
  cross = { 0.25, 0.258, 0.285 },
  key = { 0.66, 0.15, 0.32 },
  rubber = { 0.36, 0.37, 0.40 },
  shoulder = { 0.27, 0.28, 0.31 },
  ink = { 0.88, 0.88, 0.92 },
  label = { 0.60, 0.62, 0.68 },
}

local shader, shaderFailed
local fonts = {}

local function getShader()
  if shader or shaderFailed then return shader end
  local ok, res = pcall(love.graphics.newShader, SHADER_SRC)
  if ok then shader = res else
    shaderFailed = true
    print("[warn] DuoDeckArt shader failed: " .. tostring(res))
  end
  return shader
end

function DeckArt.available()
  return love and love.graphics and love.graphics.newShader and getShader() ~= nil
end

local function font(size)
  size = math.max(8, math.floor(size + 0.5))
  local f = fonts[size]
  if not f then
    f = love.graphics.newFont(size)
    fonts[size] = f
  end
  return f
end

local function dpi()
  local G = love.graphics
  return (G.getDPIScale and G.getDPIScale()) or 1
end

-- one shaded quad; geometry in LOVE units, converted to pixels for the
-- shader (screen_coords are pixels)
local function piece(mode, cx, cy, hw, hh, opts)
  opts = opts or {}
  local sh = getShader()
  local k = dpi()
  sh:send("center", { cx * k, cy * k })
  sh:send("halfSize", { hw * k, hh * k })
  sh:send("radius", (opts.radius or 0) * k)
  sh:send("angle", opts.angle or 0)
  sh:send("mode", mode)
  sh:send("pressed", opts.pressed and 1 or 0)
  sh:send("base", opts.base)
  sh:send("dir", opts.dir or 0)
  sh:send("px", k)
  local m = opts.margin or math.max(hw, hh) * 0.35
  local ext = math.max(hw, hh) + m
  love.graphics.rectangle("fill", cx - ext, cy - ext, ext * 2, ext * 2)
end

local function text(str, cx, cy, size, rgb, alpha, angle)
  local f = font(size * dpi()) -- rasterize at device pixels for crisp glyphs
  local k = dpi()
  love.graphics.setFont(f)
  local w, h = f:getWidth(str) / k, f:getHeight() / k
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(angle or 0)
  love.graphics.scale(1 / k, 1 / k)
  love.graphics.setColor(0, 0, 0, 0.35 * alpha)
  love.graphics.print(str, -w / 2 * k, -h / 2 * k + 1.2 * k)
  love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha)
  love.graphics.print(str, -w / 2 * k, -h / 2 * k)
  love.graphics.pop()
end

-- Panel behind every control area, plus a hairline at the fold.
function DeckArt.drawShell(duo, alphaMul)
  local P = DeckArt.PALETTE
  love.graphics.setShader(getShader())
  love.graphics.setColor(1, 1, 1, alphaMul)
  for _, c in ipairs(duo.controls) do
    local inset = 6
    local hw, hh = c.w / 2 - inset, c.h / 2 - inset
    piece(0, c.x + c.w / 2, c.y + c.h / 2, hw, hh,
          { base = P.shell, radius = math.min(26, math.min(c.w, c.h) * 0.07), margin = 1 })
  end
  -- speaker grille in the bottom-right corner of a full-width deck, the
  -- way a handheld's face has one; skipped where the corner is tight
  local c = duo.controls[1]
  if #duo.controls == 1 and c.h >= 260 then
    local k = math.min(c.w, c.h)
    local len, th = k * 0.085, math.max(3, k * 0.011)
    local gx, gy = c.x + c.w - k * 0.17, c.y + c.h - k * 0.15
    local ang = -0.5
    -- the shader rotates by `ang`, so a slot's long axis on screen is
    -- (cos, sin); step the slots along the perpendicular (-sin, cos)
    local nx, ny = -math.sin(ang), math.cos(ang)
    for i = 0, 4 do
      local off = (i - 2) * th * 2.8
      piece(6, gx + nx * off, gy + ny * off, len * 0.5, th * 0.5,
            { base = P.shell, angle = ang, margin = 2 })
    end
  end
  love.graphics.setShader()
end

-- All controls.  state = { dir = "up"|..., held = {a=true,...},
-- buttons = {"a","b",...}, hotbar = bool, alpha = 0..1 }
function DeckArt.drawControls(L, state)
  local P = DeckArt.PALETTE
  local alpha = state.alpha or 1
  local held = state.held or {}
  local sh = getShader()
  love.graphics.setShader(sh)
  love.graphics.setColor(1, 1, 1, alpha)

  -- cross pad in its well
  local dz = L.dpad
  piece(1, dz.cx, dz.cy, dz.w * 0.56, dz.w * 0.56, { base = P.well, margin = 2 })
  local dirs = { up = 1, right = 2, down = 3, left = 4 }
  piece(2, dz.cx, dz.cy, dz.w * 0.47, dz.w * 0.47,
        { base = P.cross, dir = dirs[state.dir] or 0, pressed = state.dir ~= nil })

  local shoulders = {}
  for _, btn in ipairs(state.buttons or {}) do
    local z = L[btn]
    if z then
      if btn == "a" or btn == "b" then
        piece(3, z.cx, z.cy, z.w * 0.5, z.w * 0.5, { base = P.key, pressed = held[btn] })
      elseif btn == "start" or btn == "select" then
        piece(4, z.cx, z.cy, z.w * 0.62, z.w * 0.2,
              { base = P.rubber, pressed = held[btn], angle = -0.42 })
      elseif btn == "l" or btn == "r" then
        local h = z.h or z.w * 0.5
        piece(5, z.cx, z.cy, z.w * 0.5, h * 0.5,
              { base = P.shoulder, pressed = held[btn], radius = h * 0.42 })
        shoulders[#shoulders + 1] = btn
      end
    end
  end
  if state.hotbar and L.hotbar then
    local z = L.hotbar
    piece(3, z.cx, z.cy, z.w * 0.5, z.w * 0.5,
          { base = P.rubber, pressed = state.hotbarOpen })
  end
  love.graphics.setShader()

  -- legends
  for _, btn in ipairs({ "a", "b" }) do
    local z = L[btn]
    if z then
      local sink = held[btn] and z.w * 0.03 or 0
      text(btn:upper(), z.cx, z.cy + sink, z.w * 0.42, P.ink, 0.92 * alpha)
    end
  end
  for _, btn in ipairs({ "select", "start" }) do
    local z = L[btn]
    if z then
      text(btn:upper(), z.cx, z.cy + z.w * 0.62, math.max(9, z.w * 0.30), P.label, 0.9 * alpha)
    end
  end
  for _, btn in ipairs(shoulders) do
    local z = L[btn]
    text(btn:upper(), z.cx, z.cy, (z.h or z.w * 0.5) * 0.5, P.label, 0.95 * alpha)
  end
  if state.hotbar and L.hotbar then
    local z = L.hotbar
    love.graphics.setColor(P.ink[1], P.ink[2], P.ink[3], 0.8 * alpha)
    for i = -1, 1 do
      love.graphics.circle("fill", z.cx + i * z.w * 0.22, z.cy, z.w * 0.065, 16)
    end
  end
end

return DeckArt
