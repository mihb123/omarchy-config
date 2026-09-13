-- Keyboard-driven mouse pointer.
--
-- Two ways in:
--   SUPER + M          enter mouse mode and stay there until Escape
--   SUPER + ALT + M    one shot: label everything clickable, pick one, click it
--
-- Inside mouse mode:
--   h j k l / arrows   move the pointer                  (hold to repeat)
--   SHIFT + h j k l    move in large steps               (hold to repeat)
--   CTRL  + h j k l    move in fine steps                (hold to repeat)
--   a                  jump to a detected target (pointer only, stay in mode)
--   SHIFT + A          jump to a detected target, click, and leave mode
--   g                  grid jump: pick a tile, then bisect it
--   s d f              left / middle / right click
--   RETURN or SPACE    left click, then leave mode
--   e r                scroll up / down                  (hold to repeat)
--   t y                scroll left / right               (hold to repeat)
--   u i / o p          scroll further per press, same four directions
--   c                  centre the pointer on the focused window
--   ESCAPE or q        leave mouse mode
--
-- Pointer movement is native: hl.get_cursor_pos() plus hl.dsp.cursor.move()
-- run inside the compositor, so holding a key does not spawn a process per
-- repeat. Clicking and scrolling need a virtual pointer device, which
-- Hyprland only exposes over the wire, so those shell out to wlrctl.
--
-- Requires: wl-kbptr (built with OpenCV, for target detection) and wlrctl.
--
-- There is deliberately no drag binding. Holding a button needs a device that
-- outlives the keypress, which wlrctl cannot do; ydotool can, but a uinput
-- button held while the compositor warps the pointer underneath it does not
-- behave like a real drag, so it was removed rather than left half-working.

local SUBMAP = "mouse"

local STEP      = 24 -- px per keypress
local STEP_BIG  = 140
local STEP_FINE = 4
-- wlrctl emits a finger-source axis event, which the compositor runs through a
-- touchpad acceleration curve, so these numbers are not pixels and the curve is
-- steep: measured against a terminal, 120 moves ~130px, 160 ~260px, 200 ~350px,
-- 240 ~500px -- and 300 scrolls ~130px *backwards*. Something wraps past ~240,
-- so treat that as the ceiling. Raising these further makes scrolling worse.
local SCROLL     = 120
local SCROLL_BIG = 240

-- wl-kbptr invocations. `detect` needs the OpenCV build; `--version` prints
-- "opencv" when the binary has it. The tile/bisect chain needs no screen
-- capture at all and works as a fallback on any surface.
local HINT       = "wl-kbptr -o modes=floating -o mode_floating.source=detect"
local HINT_CLICK = "wl-kbptr -o modes=floating,click -o mode_floating.source=detect"
local GRID       = "wl-kbptr -o modes=tile,bisect"

-- hl.exec_cmd runs the string through /bin/sh, so this re-enters the submap
-- once wl-kbptr has exited and released its keyboard grab.
local REENTER = [[hyprctl dispatch "hl.dsp.submap(\"]] .. SUBMAP .. [[\")"]]

-- Omarchy hides the pointer as soon as you type. That is exactly wrong while
-- driving the pointer from the keyboard, so suspend it for the duration.
-- hl.config merges, so this leaves the rest of the cursor block alone.
-- (`hyprctl keyword` is not an option here: it refuses to run against a Lua
-- config with "keyword can't work with non-legacy parsers".)
local function hide_on_key_press(enabled)
  hl.config({ cursor = { hide_on_key_press = enabled } })
end

local function enter_mouse_mode()
  hide_on_key_press(false)
  hl.dispatch(hl.dsp.submap(SUBMAP))
end

local function leave_mouse_mode()
  hide_on_key_press(true)
  hl.dispatch(hl.dsp.submap("reset"))
end

local function nudge(dx, dy)
  return function()
    local pos = hl.get_cursor_pos()
    hl.dispatch(hl.dsp.cursor.move({ x = pos.x + dx, y = pos.y + dy }))
  end
end

-- There is no "move to centre" dispatcher, but move_to_corner reports where it
-- landed, so read two opposite corners of the focused window and split them.
local function centre_on_window()
  hl.dispatch(hl.dsp.cursor.move_to_corner({ corner = 3 })) -- top left
  local top_left = hl.get_cursor_pos()
  hl.dispatch(hl.dsp.cursor.move_to_corner({ corner = 1 })) -- bottom right
  local bottom_right = hl.get_cursor_pos()
  hl.dispatch(hl.dsp.cursor.move({
    x = (top_left.x + bottom_right.x) / 2,
    y = (top_left.y + bottom_right.y) / 2,
  }))
end

-- wl-kbptr draws its own layer-shell overlay and grabs the keyboard, so the
-- submap has to be dropped first or every keystroke would hit these binds.
local function jump(command, come_back)
  return function()
    hl.dispatch(hl.dsp.submap("reset"))
    if come_back then
      hl.exec_cmd(command .. "; " .. REENTER)
    else
      hide_on_key_press(true)
      hl.exec_cmd(command)
    end
  end
end

local function click(button)
  return hl.dsp.exec_cmd("wlrctl pointer click " .. button)
end

local function scroll(dy, dx)
  return hl.dsp.exec_cmd("wlrctl pointer scroll " .. dy .. " " .. dx)
end

local held = { repeating = true }

hl.define_submap(SUBMAP, function()
  -- Move.
  for key, delta in pairs({
    h = { -1, 0 },
    l = { 1, 0 },
    k = { 0, -1 },
    j = { 0, 1 },
  }) do
    local dx, dy = delta[1], delta[2]
    hl.bind(key, nudge(dx * STEP, dy * STEP), held)
    hl.bind("SHIFT + " .. key, nudge(dx * STEP_BIG, dy * STEP_BIG), held)
    hl.bind("CTRL + " .. key, nudge(dx * STEP_FINE, dy * STEP_FINE), held)
  end

  for key, delta in pairs({
    left = { -1, 0 },
    right = { 1, 0 },
    up = { 0, -1 },
    down = { 0, 1 },
  }) do
    local dx, dy = delta[1], delta[2]
    hl.bind(key, nudge(dx * STEP, dy * STEP), held)
    hl.bind("SHIFT + " .. key, nudge(dx * STEP_BIG, dy * STEP_BIG), held)
    hl.bind("CTRL + " .. key, nudge(dx * STEP_FINE, dy * STEP_FINE), held)
  end

  -- Jump.
  hl.bind("a", jump(HINT, true))
  hl.bind("SHIFT + a", jump(HINT_CLICK, false))
  hl.bind("g", jump(GRID, true))
  hl.bind("c", centre_on_window)

  -- Click.
  hl.bind("s", click("left"))
  hl.bind("d", click("middle"))
  hl.bind("f", click("right"))
  hl.bind("return", function()
    hl.exec_cmd("wlrctl pointer click left")
    leave_mouse_mode()
  end)
  hl.bind("space", function()
    hl.exec_cmd("wlrctl pointer click left")
    leave_mouse_mode()
  end)

  -- Scroll. wlrctl takes vertical first, then horizontal.
  --
  -- The fast variants deliberately avoid SHIFT. wlrctl's axis event reaches the
  -- client while the real SHIFT key is still held, and GTK, Chromium and Firefox
  -- all read SHIFT + wheel as "scroll the other axis", so a shifted bind came out
  -- rotated 90 degrees. CTRL is zoom and ALT is history navigation, so the fast
  -- keys are plain: u i for vertical, o p for horizontal.
  hl.bind("e", scroll(-SCROLL, 0), held)
  hl.bind("r", scroll(SCROLL, 0), held)
  hl.bind("t", scroll(0, -SCROLL), held)
  hl.bind("y", scroll(0, SCROLL), held)
  hl.bind("u", scroll(-SCROLL_BIG, 0), held)
  hl.bind("i", scroll(SCROLL_BIG, 0), held)
  hl.bind("o", scroll(0, -SCROLL_BIG), held)
  hl.bind("p", scroll(0, SCROLL_BIG), held)

  -- Leave.
  hl.bind("escape", leave_mouse_mode)
  hl.bind("q", leave_mouse_mode)

  -- Uncomment to swallow every other key while in mouse mode, so a stray
  -- keystroke cannot leak into the focused window. It also blocks the media
  -- and volume keys, which is why it is off by default.
  -- hl.bind("catchall", function() end)
end)

o.bind("SUPER + M", "Mouse mode", enter_mouse_mode)
o.bind("SUPER + ALT + M", "Click a target", HINT_CLICK)
