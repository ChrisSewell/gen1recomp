-- The touch pad on a foldable: each Duo posture lays the pad out in its own
-- control area and keeps its own saved layout bucket, so editing the
-- clamshell pad never moves the flat or phone layouts.  Port-only
-- affordance, no pokered cite.
--   luajit tests/engine/duo_touch_controls_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local Duo = require("src.core.DuoPosture")
local TC = require("src.core.TouchControls")

love.window = love.window or {}
local function setWindow(w, h, sx, sy, sw, sh)
  love.window.getSafeArea = function() return sx or 0, sy or 0, sw or w, sh or h end
  love.graphics.getDimensions = function() return w, h end
  Duo.invalidate()
  TC.layoutW, TC.L = nil, nil
end

TC:init()
TC:applyOptions({ touchControls = { enabled = true } })

-- no hinge: the stock phone layout and the portrait bucket
Duo.forced = nil
setWindow(402, 874)
local L = TC:layout()
eq(TC.bucketKey, "portrait", "no hinge uses the portrait bucket")
check(TC.duo == nil, "no deck without a hinge")

-- clamshell: the whole pad sits in the bottom half, below the fold
Duo.forced = { status = "partial", angle = 100 }
setWindow(669, 951, 0, 0, 669, 917)
L = TC:layout()
eq(TC.bucketKey, "duo_clamshell", "clamshell has its own bucket")
check(TC.duo ~= nil, "clamshell draws a deck")
for _, n in ipairs({ "dpad", "a", "b", "start", "select" }) do
  check(L[n].cy - L[n].w / 2 > 951 / 2, n .. " sits below the fold")
end

-- editing the clamshell pad leaves flat and phone layouts alone
TC:setControlCenter("dpad", 120, 800)
check(TC.layouts.duo_clamshell.positions.dpad ~= nil, "clamshell edit saved")
check(TC.layouts.portrait.positions == nil, "portrait bucket untouched")
local snap = TC:config()
check(snap.layouts.duo_clamshell ~= nil, "config carries the clamshell bucket")
local round = TC.normalizeConfig(snap)
check(round.layouts.duo_clamshell.positions.dpad ~= nil, "clamshell bucket round-trips")

-- flat open, landscape: two rails, d-pad left of the game, A right of it
Duo.forced = { status = "open", angle = 180 }
setWindow(890, 626, 0, 0, 890, 592)
L = TC:layout()
eq(TC.bucketKey, "duo_flat_landscape", "flat landscape bucket")
check(TC.layouts.duo_flat_landscape.positions == nil, "flat starts from defaults")
local p = Duo.current()
check(L.dpad.cx + L.dpad.w / 2 <= p.game.x, "d-pad left of the game")
check(L.a.cx - L.a.w / 2 >= p.game.x + p.game.w, "A right of the game")

-- cover landscape keeps the stock overlay and the landscape bucket
Duo.forced = { status = "closed", angle = 0 }
setWindow(678, 466, 84, 0, 594, 432)
TC:layout()
eq(TC.bucketKey, "landscape", "cover landscape uses the stock landscape bucket")

-- a posture change re-lays the pad out (and buzzes, a no-op in the stub)
Duo.forced = { status = "partial", angle = 100 }
setWindow(669, 951, 0, 0, 669, 917)
TC:layout()
Duo.forced = { status = "open", angle = 180 }
love.graphics.getDimensions = function() return 626, 890 end
love.window.getSafeArea = function() return 0, 0, 626, 856 end
TC.layoutW = nil
TC:layout()
eq(TC.bucketKey, "duo_flat_portrait", "opening flat switches buckets")

Duo.forced = nil
T.finish("duo_touch_controls")
