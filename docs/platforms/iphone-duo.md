# iPhone Duo (foldable) layouts

On a device that reports a hinge (the iPhone Duo on iOS 27.1+), the game and
the touch pad get their own areas for each posture instead of sharing one
screen. Ordinary iPhones, iPads and desktops are unchanged.

| Posture | Game | Touch pad |
| --- | --- | --- |
| Half open, clamshell (window taller than wide) | top half | full deck on the bottom half |
| Half open, book (window wider than tall) | left page | deck on the right page |
| Open flat, portrait | top | deck underneath |
| Open flat, landscape | centre | a rail for each thumb |
| Closed, cover screen, portrait | top | deck underneath |
| Closed, cover screen, landscape | full screen | standard overlay |

Nothing is placed on the fold. The layouts use the whole panel, including
the cover display's camera column and the home-indicator band; only the
cover display in landscape keeps its safe area, because content under its
camera column does not show. Positions and size edited in the touch layout
editor are saved per posture. The ... menu row opens along the bottom edge
of the game picture, clear of the controls.

## How it works

- `mobile/ios/native/GRHingeBridge.swift` attaches a `UIHingeInteraction`
  to the key window and exposes it to Lua as `love.system.getHinge()`
  (`"closed"|"partial"|"open"|"unknown", angle`), or nil without a hinge.
- `src/core/DuoPosture.lua` resolves the posture from the hinge and window
  geometry (outer display = long side under 760 pt; the fold is the middle
  of the inner display) and returns the game rect and control areas.
- `src/render/GameViewport.lua` uses the game rect as the default
  `render.viewport`; `src/core/TouchControls.lua` lays the pad out in the
  control areas and draws the deck behind it.

## Logging on the device

Each posture change prints one `[duo]` line (posture, hinge, angle, window,
pixel size, DPI scale, safe area). Create an empty `duo.log` in the save
directory (the app's Documents on iOS) and the lines are appended there too,
so they can be pulled off a phone with `xcrun devicectl`.

## Testing without a Duo

`POKEPORT_DUO_HINGE=closed|partial|open[:angle]` forces a hinge reading
(`off` disables the layouts). With `POKEPORT_TOUCH=1` and a desktop window
of the inner display's size (for example 669x951 for the clamshell), every
posture can be previewed on a desktop. Headless checks:

```bash
luajit tests/engine/duo_posture_test.lua
luajit tests/engine/duo_touch_controls_test.lua
```
