-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Configure keyboard and touchpad
hl.config({
  input = {
    -- Restore normal Caps Lock behavior (disables Omarchy's compose:caps default)
    kb_options = "",

    touchpad = {
      -- Use natural (inverse) scrolling.
      natural_scroll = true,

      -- Tap to click (1 finger: left, 2 fingers: right, 3 fingers: middle).
      tap_to_click = true,
      tap_button_map = "lrm",
      clickfinger_behavior = true,

      -- Left-click-and-drag with three fingers.
      drag_3fg = 1,

      -- Control the speed of scrolling.
      scroll_factor = 0.4,

      -- Keep touchpad active while typing.
      disable_while_typing = false,
    },
  },
})

-- App-specific touchpad scroll speeds.
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

--------------------------------------------------------------------------------
-- Touchpad Gestures
--------------------------------------------------------------------------------
--
-- Every gesture below is discrete, not 1:1: it fires the moment Hyprland
-- recognizes the swipe direction (about 5px of travel) rather than waiting for
-- you to lift your fingers. The one exception is 3-finger horizontal, which
-- keeps the built-in animated workspace swipe.
--
-- The mechanism is the shape of `action`. A bare `action = function() ... end`
-- is the legacy end-only form and only runs on finger lift; the table form
-- `action = { start = ..., update = ..., finish = ... }` lets you pick the
-- phase. Using only `start` is what makes these fire immediately.
--
-- Directions are physical finger movement, unaffected by natural_scroll:
-- "left" means the fingers moved left.

-- Register a gesture that fires as soon as the swipe is recognized.
local function swipe(fingers, direction, action)
  hl.gesture({
    fingers = fingers,
    direction = direction,
    -- Hyprland C++ supports table actions ({ start = ... }), but the generated stubs only declare string|function.
    ---@diagnostic disable-next-line: assign-type-mismatch
    action = { start = action },
  })
end

-- Wrap a dispatcher-building function so a failure in one gesture can't take
-- the whole config down.
local function dispatch(build)
  return function()
    pcall(function()
      hl.dispatch(build())
    end)
  end
end

local function run(cmd)
  return function()
    hl.exec_cmd(cmd)
  end
end

--------------------------------------------------------------------------------
-- Three-Finger Gestures
--------------------------------------------------------------------------------

-- 3-finger horizontal: Change workspace with the smooth 1:1 swipe animation.
--
-- This is the one gesture that is deliberately NOT discrete: the built-in
-- "workspace" action tracks your fingers and commits on release, which is the
-- whole point of it.
hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})

-- Helper to inspect active workspace tiled layout safely
local function active_layout()
  local ok, ws = pcall(hl.get_active_workspace)
  return (ok and ws and ws.tiled_layout) or "dwindle"
end

-- 3-finger up: See all windows in the current workspace
-- In "scrolling" layout: fits all columns into view.
-- In "dwindle" (or other layouts): exits fullscreen if active window is fullscreen.
swipe(3, "up", function()
  pcall(function()
    if active_layout() == "scrolling" then
      hl.dispatch(hl.dsp.layout("fit all"))
    else
      local win = hl.get_active_window()
      if win and (win.fullscreen == 1 or win.fullscreen == true) then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0 }))
      end
    end
  end)
end)

-- 3-finger down: Return to focused/active window
-- In "scrolling" layout: zooms in on active window/column.
-- In "dwindle" (or other layouts): restores or brings active window to top.
swipe(3, "down", function()
  pcall(function()
    if active_layout() == "scrolling" then
      hl.dispatch(hl.dsp.layout("fit active"))
    else
      local win = hl.get_active_window()
      if win and (win.fullscreen == 1 or win.fullscreen == true) then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0 }))
      else
        hl.dispatch(hl.dsp.window.bring_to_top())
      end
    end
  end)
end)

--------------------------------------------------------------------------------
-- Four-Finger Gestures
--------------------------------------------------------------------------------

-- 4-finger left: Brightness down
swipe(4, "left", run("omarchy-brightness-display 5%-"))

-- 4-finger right: Brightness up
swipe(4, "right", run("omarchy-brightness-display +5%"))

-- 4-finger up: Volume up
swipe(4, "up", run("omarchy-audio-output-volume raise"))

-- 4-finger down: Volume down
swipe(4, "down", run("omarchy-audio-output-volume lower"))
