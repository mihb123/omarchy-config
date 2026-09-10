# Giữ custom Omarchy bằng `cfg`

Cập nhật 11/09/2026 · Omarchy `4.0.2-1` · btrfs + snapper

---

## Mô hình

Một git repo với git-dir và work-tree tách rời:

```
lịch sử  →  ~/.dotfiles
file thật →  $HOME  và  ~/.config/
```

**Config không bị di chuyển, không thành symlink.** `~/.config/hypr/bindings.lua` vẫn là file thật ở đúng chỗ, nên Hyprland và các migration của Omarchy đọc/ghi bình thường. Đó là lý do không dùng `stow`/`chezmoi`.

| Thành phần | Đường dẫn |
| --- | --- |
| Repo | `~/.dotfiles` |
| Lệnh | `~/.local/bin/cfg` |
| Lệnh lưu | `~/.local/bin/cfg-save` (gọi qua `cfg save`) |
| Manifest hệ thống | `~/.local/bin/cfg-snapshot` → `~/.local/share/system-manifest/` |
| Quy tắc ignore | `~/.config/cfg/ignore` — **được track**, đi theo `push` |
| Hook sau update | `~/.config/omarchy/hooks/post-update.d/zz-cfg-autocommit.hook` |
| Remote | `debi-git:/home/git/repos/omarchy-dotfile.git` |

Cấu hình repo: `core.bare=false`, `status.showUntrackedFiles=all`, `core.excludesFile=~/.config/cfg/ignore`.

---

## Hằng ngày

```bash
cfg save              # stage + commit MỌI thay đổi, kể cả file mới
cfg save -n           # xem trước, không commit
cfg save "thông điệp" # commit với message của mình
cfg status            # đang đổi gì
cfg diff              # đổi dòng nào
cfg log --oneline
```

Không cần `cfg add` từng file. `cfg` = `git`, mọi lệnh git đều dùng được.

**`cfg save` tự bảo vệ:**

- File > 1MB → **dừng** và in tên file. Không có rào này thì `agy` (203MB), `uv` (48MB) sẽ lọt vào git.
- Thư mục có `.git` riêng → **tự bỏ qua**, tự ghi vào `~/.config/cfg/ignore`, rồi tiếp tục commit phần còn lại.

---

## Phạm vi theo dõi

`~/.config` được theo dõi **toàn bộ** (blacklist mode), chỉ chặn danh sách đã biết là nặng hoặc chỉ chứa state: browser, `nvm`, `Antigravity IDE`, `obsidian`, `dconf`, `pulse`, `ibus`, `go/telemetry`.

→ **Tool mới cài tự động được theo dõi**, không phải sửa `ignore`.

Ngoài `~/.config`: `~/.zshrc`, `.bashrc`, `.profile`, script text + symlink trong `~/.local/bin`, `~/.claude/settings.json`, `~/.local/share/system-manifest/`, và chính file này.

Loại trừ: `*.bak*`, `*.log`, `*.pid`, `*cache*`, `session.json`, ảnh raster + font (`*.jpg *.png *.ttf ...`), ELF binary trong `.local/bin`, secret (`*.key *.pem *_rsa`).

Kiểm tra lý do một file bị bỏ: `cfg check-ignore -v <file>`

---

## Quanh `omarchy update`

Thứ tự `omarchy update` thật sự chạy (đọc từ `omarchy-update` trên máy):

```
prune cache → snapper snapshot → keyring → pacman -Syu → migrations
→ hook post-update → AUR → mise → orphans → analyze logs → restart
```

**Config trong `~/.config` được giữ.** Default nằm ở `/usr/share/omarchy/config/` (read-only) và không bị copy đè. Phần lớn migration sửa tại chỗ bằng `jq`/`awk` và có guard (`[[ -f ... ]] ||`, `grep -Fq`, so sha256).

Ngoại lệ cần biết: migration **có thể** gọi `omarchy-refresh-config`, lệnh này `cp -f` default lên file của mình — nhưng luôn lưu `.bak.<timestamp>` và in diff ra. Không mất, chỉ cần đọc log update.

Trước update:

```bash
cfg save                                  # phải sạch trước khi update
cfg tag "pre-update-$(date +%Y%m%d-%H%M)"
omarchy update
```

Sau update, hook đã tự commit phần config bị đổi:

```bash
cfg show HEAD          # update đã đổi CHÍNH XÁC những gì
cfg log --oneline
hyprctl configerrors   # nếu có sửa Hyprland
```

Rồi thử tay các thứ đã custom: IME, gestures, phím tắt, bar, terminal. Không lỗi parse ≠ hoạt động.

**Nếu hỏng:**

- Một file: `cfg checkout HEAD~1 -- .config/hypr/bindings.lua`
- Cả hệ thống: reboot → chọn snapshot pre-update trong limine

**Đừng bao giờ chạy:** `omarchy reinstall`, `omarchy refresh shell|hyprland`, `pacman -Syu`, `yay -Syu`. Ba cái đầu ghi đè default lên config (có tạo `.bak`), cái cuối bỏ qua snapshot + migrations.

---

## `cfg` KHÔNG bảo vệ những thứ này

| Thứ | Vì sao / xử lý thế nào |
| --- | --- |
| **Plugin nvim** (`~/.local/share/nvim`, 347MB, 53 repo con) | Không track. `~/.config/nvim/lazy-lock.json` đã ghim commit từng plugin → máy mới chỉ cần `:Lazy restore`. |
| **`~/bin`** | Repo riêng: `git@github.com:mihb123/script.git`. Commit bằng `git -C ~/bin`. |
| **`user.trackpad-gestures`** | Repo riêng: `github.com/mpweaver/omarchy-trackpad-gestures`. |
| **Plugin clone** (`mihb.menu`, `mihb.ime`, `mihb.notifications`, `mihb.indicators`, `runcat`, `quick-settings`, `workspaces`) | Là bản chụp tĩnh. **Update Omarchy không cập nhật chúng**, và migration nhắm id `omarchy.*` sẽ bỏ qua widget đã đổi tên. Sau update nếu bar lạ → so clone với bản mới trong `/usr/share/omarchy/shell/`. |
| **`/etc`** | Ngoài `$HOME`. Snapper lo phần này. |
| **Binary/package** | Chỉ có *danh sách* trong `system-manifest/`, không có nội dung. |

Symlink được lưu **là symlink**, không lưu nội dung đích (`livetrans`, `transcribe`, `ytdl` → `~/Work/…` thuộc repo dự án).

---

## Backup ra remote

Local đang đi trước `origin`. Đẩy lên:

```bash
cfg push -u origin main      # -u để lần sau chỉ cần `cfg push`
cfg push origin --tags
```

Đọc diff trước khi push để không đưa token/password lên server.

---

## Dựng lại trên máy mới

```bash
git clone --bare debi-git:/home/git/repos/omarchy-dotfile.git ~/.dotfiles
cfg() { git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" "$@"; }
cfg config core.bare false
cfg config status.showUntrackedFiles all
cfg checkout                              # xem file trùng trước, backup rồi mới ép
cfg config core.excludesFile "$HOME/.config/cfg/ignore"
nvim  # :Lazy restore
```

`core.excludesFile` phải set **sau** checkout, vì `~/.config/cfg/ignore` nằm trong chính repo.

---

## Bảo trì

`cfg save` dùng `add -A`, nên một lần lỡ tay có thể băm cả `$HOME` vào repo. Đã từng xảy ra: repo phình lên **1179 MB** vì object mồ côi (`agy` 205MB, blob 420MB, tmp_obj 165MB). Kiểm tra và dọn:

```bash
du -sh ~/.dotfiles                        # bình thường < 1MB
cfg count-objects -vH
cfg reflog expire --expire=now --expire-unreachable=now --all
cfg gc --prune=now
```

Whitelist tầng gốc + hai rào an toàn khiến chuyện này khó lặp lại, nhưng vẫn nên xem `du -sh` định kỳ.

---

## Xoá sạch setup này

```bash
rm -rf ~/.dotfiles ~/.local/bin/cfg ~/.local/bin/cfg-save \
       ~/.config/cfg ~/.config/omarchy/hooks/post-update.d/zz-cfg-autocommit.hook
```

Config trên đĩa không hề bị ảnh hưởng.
