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

      -- Disable 3-finger drag to prevent text selection and gesture conflicts.
      drag_3fg = 0,

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
-- (Legacy static definitions commented out; gestures are now managed dynamically
-- by user.trackpad-gestures via gestures-generated.lua)
--------------------------------------------------------------------------------

-- local function swipe(fingers, direction, action)
--   hl.gesture({
--     fingers = fingers,
--     direction = direction,
--     action = { start = action },
--   })
-- end

-- local function run(cmd)
--   return function()
--     hl.exec_cmd(cmd)
--   end
-- end

-- Three-Finger Gestures (legacy)
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
-- swipe(3, "up", ...)
-- swipe(3, "down", ...)

-- Four-Finger Gestures (legacy)
-- swipe(4, "left", run("omarchy-brightness-display 5%-"))
-- swipe(4, "right", run("omarchy-brightness-display +5%"))
-- swipe(4, "up", run("omarchy-audio-output-volume raise"))
-- swipe(4, "down", run("omarchy-audio-output-volume lower"))

-- user.trackpad-gestures:start
local trackpad_config_home = os.getenv("XDG_CONFIG_HOME")
if not trackpad_config_home or trackpad_config_home == "" then trackpad_config_home = os.getenv("HOME") .. "/.config" end
local trackpad_gesture_config = trackpad_config_home .. "/hypr/gestures-generated.lua"
local trackpad_gesture_loader = loadfile(trackpad_gesture_config)
if trackpad_gesture_loader then trackpad_gesture_loader() end
-- user.trackpad-gestures:end
