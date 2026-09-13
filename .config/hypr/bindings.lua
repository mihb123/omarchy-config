-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Cycle the input method (English -> Lotus -> Unikey) with Ctrl+Shift.
--
-- fcitx5-remote -t only ever toggles the group on and off, so it cannot reach a
-- third profile. The cycle walks all three in order and records the choice for
-- the focused window; fcitx-ime-window.service puts that profile back whenever
-- you return to the window. See ~/.local/bin/fcitx-ime.
--
-- fcitx-ime-cycle, not `fcitx-ime cycle`: it signals the running daemon, which
-- already has the interpreter warm (~5ms, same as the old fcitx5-remote -t).
-- Starting a fresh Python just to import json and subprocess costs ~85ms --
-- long enough to swallow the first keystroke after the shortcut. It falls back
-- to the slow path on its own if the daemon is not running.
--
-- Why this lives here instead of in fcitx5's "Trigger Input Method" hotkey:
-- Hyprland 0.56.2 delivers modifier *press* events to the input method's
-- keyboard grab but drops the matching *release* events (regression from the
-- keybinds refactor PR hyprwm/Hyprland#15568, reported as #15886). fcitx5 only
-- fires a modifier-only hotkey on release, so Ctrl+Shift can never reach it
-- while a text field is focused. Hyprland's own bind path still sees the
-- release, so do the toggle at the compositor level instead.
--
-- Both CTRL and SHIFT must be in the modmask: on a release event Hyprland
-- reports the mods as they were *before* the key was released, so releasing
-- Shift while Ctrl is held reports CTRL|SHIFT. A modmask of just CTRL never
-- matches. Both Shift_L/R and Control_L/R are bound so it fires whichever
-- modifier you let go of first.
--
-- non_consuming keeps the Ctrl/Shift key presses flowing to applications.
-- Chords are handled by Hyprland's shadowKeybinds(): pressing any other key
-- while Ctrl+Shift is held shadows these binds, so Ctrl+Shift+C, Ctrl+Shift+V
-- and friends do not toggle the input method.
local vi_toggle = { release = true, non_consuming = true }
-- Absolute path: Hyprland's exec does not inherit the login shell's PATH.
local ime_cycle = os.getenv("HOME") .. "/.local/bin/fcitx-ime-cycle"
o.bind("CTRL + SHIFT + Shift_L", "Cycle input method", ime_cycle, vi_toggle)
o.bind("CTRL + SHIFT + Shift_R", "Cycle input method", ime_cycle, vi_toggle)
o.bind("CTRL + SHIFT + Control_L", "Cycle input method", ime_cycle, vi_toggle)
o.bind("CTRL + SHIFT + Control_R", "Cycle input method", ime_cycle, vi_toggle)

-- Faster Keybindings menu (SUPER+K): ~460ms -> ~135ms.
--
-- Default binding was: o.bind("SUPER + K", "Keybindings", "omarchy-menu-keybindings")
-- Same menu, same rows, same dispatch. Two halves to the change:
--
--   ~/.local/bin/omarchy-menu-keybindings-fast
--     Caches the finished IPC payload rather than rebuilding it per open, so
--     the warm path is one fork. Skips the two JSON::PP perl runs the stock
--     script does every time (~53ms) and hands the payload to the shell over
--     a Unix socket instead of spawning the qs client (~90ms of Qt startup).
--     The cache self-invalidates on any change to ~/.config/hypr/*.lua or the
--     Omarchy default bindings and re-verifies against `hyprctl binds` in the
--     background once the menu is up. Force a rebuild:
--       omarchy-menu-keybindings-fast --refresh
--
--   ~/.config/omarchy/plugins/mihb.menu/
--     A clone of the omarchy.menu shell plugin whose row-height computation
--     no longer runs once per appended row (it was O(rows²): 234 height
--     passes for a 231-row menu). See its README.md.
--
-- Measure with: omarchy-keybindings-profile --compare
--
-- To go back to stock, delete these two lines (the clone can stay; it only
-- makes every menu open faster).
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keybindings", os.getenv("HOME") .. "/.local/bin/omarchy-menu-keybindings-fast")

-- Ensure Omawrite shortcut uses the custom build with 12px font size
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Omawrite", { launch = os.getenv("HOME") .. "/bin/omawrite" })

-- Play/Pause media with F12 (ThinkPad X1 Carbon Gen 7)
-- Supports both standard F12 and Fn+F12 (XF86Favorites) regardless of FnLock state
-- o.bind("F12", "Play/Pause media", "omarchy-shell media playPause", { locked = true })
o.bind("XF86Favorites", "Play/Pause media", "omarchy-shell media playPause", { locked = true })

-- Upload screenshot using system capture utility
o.bind("ALT + SHIFT + S", "Screenshot upload", os.getenv("HOME") .. "/bin/system/screenshot-upload.sh")




-- Hold-to-talk dictation with ~/Work/trans (F10), alongside Voxtype on F9.
--
-- F9 is Voxtype: Whisper base.en, English only, text typed at the cursor when
-- the key comes up. F10 is the livetrans path: Nemotron 3.5 streaming, Vietnamese
-- and English, words appearing in an overlay while you speak, and the finished
-- take on the clipboard to paste wherever you want.
--
-- Press and release are two bindings, exactly as Voxtype's own F9 pair: the
-- press opens a take, the release finalizes it. Each names its own language so
-- an English take through SHIFT+F10 does not leave the plain F10 in English.
--
-- The daemon that holds the model warm is livetrans-dictate.service
-- (`~/Work/trans/dictate install` created it). Neither binding waits for it:
-- the very first press after a cold boot starts it and is picked up when it is
-- ready, about a second later.
o.bind("F10", "Dictation vi (hold to talk)", os.getenv("HOME") .. "/Work/trans/dictate start -l vi")
o.bind("F10", "Dictation vi (stop)", os.getenv("HOME") .. "/Work/trans/dictate stop", { release = true })
o.bind("SHIFT + F10", "Dictation en (hold to talk)", os.getenv("HOME") .. "/Work/trans/dictate start -l en")
o.bind("SHIFT + F10", "Dictation en (stop)", os.getenv("HOME") .. "/Work/trans/dictate stop", { release = true })

-- The same dictation, latched instead of held: SUPER+F10 starts a take and the
-- next SUPER+F10 ends it. Holding a key is fine for a phrase and tiring for a
-- paragraph, so long dictation goes through the toggle and short dictation
-- through plain F10. Both drive the same daemon, so the two are the same take
-- if you mix them -- start held on F10, end latched on SUPER+F10, whatever.
--
-- The language rides along with the press and is applied only by the press
-- that opens a take: ending an English take with SUPER+SHIFT+F10 does not
-- leave the next Vietnamese one in English.
o.bind("SUPER + F10", "Dictation vi (toggle)", os.getenv("HOME") .. "/Work/trans/dictate toggle -l vi")
o.bind("SUPER + SHIFT + F10", "Dictation en (toggle)", os.getenv("HOME") .. "/Work/trans/dictate toggle -l en")

-- Multi-level window transparency cycle (Super + Backspace)
-- Overrides stock 2-level toggle with configurable multi-level cycle.
-- Config file: ~/.config/omarchy/transparency.conf
hl.unbind("SUPER + BACKSPACE")
o.bind("SUPER + BACKSPACE", "Cycle window transparency", os.getenv("HOME") .. "/bin/omarchy-hyprland-window-transparency-toggle")

-- Keyboard-driven mouse pointer (SUPER + M). See hypr/mouse-keys.lua.
require("hypr.mouse-keys")
