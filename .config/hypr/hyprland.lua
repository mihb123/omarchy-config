-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("hypr.tapescroll")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Telegram Media viewer: open images/videos in fullscreen instead of a tiled sub-window
o.window({ class = "^(org\\.telegram\\.desktop|telegramdesktop)$", title = "^Media viewer$" }, { fullscreen = true })

-- Ghostty: tiếng chuông (bell) chỉ đánh dấu cửa sổ là urgent, không giật focus.
-- Bell-features mặc định có "attention", nên mỗi lần chuông kêu Ghostty sẽ xin
-- được focus. Nếu một tab SSH chết mà chế độ báo focus (DECSET 1004) vẫn còn,
-- thì zsh kêu chuông mỗi lần bạn rời cửa sổ, và Hyprland kéo bạn về workspace
-- đó chỉ sau khoảng 15 ms. Xem: hypr-focus-debug report
o.window("com.mitchellh.ghostty", { focus_on_activate = false })

-- Flameshot GUI: overlay nổi phủ kín màn hình, không chen vào layout tiling.
-- Mặc định Hyprland mở nó như một cửa sổ tiled rồi mới fullscreen, nên ở
-- workspace scrolling nó được chèn thành một cột mới: các cột bên cạnh bị đẩy
-- ra và cuộn theo, lúc đóng lại thì layout dồn cột về chỗ cũ (cái giật) và
-- focus rơi vào cột mà layout chọn thay vì cửa sổ bạn đang dùng. Cho nó float
-- thì layout không bị đụng tới.
o.window("^flameshot$", {
  tag = "-default-opacity",
  float = true,
  move = { 0, 0 },
  size = { "(monitor_w)", "(monitor_h)" },
  no_anim = true,
  border_size = 0,
  rounding = 0,
  no_shadow = true,
  opacity = "1 1",
})

-- Ctrl+O trong flameshot: lưu rồi mở bằng imv thay vì hiện hộp chọn app.
-- Chỉ bind khi cửa sổ flameshot đang mở để Ctrl+O ở các app khác vẫn bình thường.
local flameshot_open_bind

hl.on("window.open", function(window)
  if window.class == "flameshot" and not flameshot_open_bind then
    flameshot_open_bind = hl.bind(
      "CTRL + O",
      hl.dsp.exec_cmd(os.getenv("HOME") .. "/bin/system/flameshot-open-viewer.sh"),
      { description = "Flameshot: lưu và mở bằng imv" }
    )
  end
end)

hl.on("window.close", function(window)
  if window.class == "flameshot" and flameshot_open_bind then
    flameshot_open_bind:unbind()
    flameshot_open_bind = nil
  end
end)

-- HyprMod managed settings
require("hyprland-gui")
