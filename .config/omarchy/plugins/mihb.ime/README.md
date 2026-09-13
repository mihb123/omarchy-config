# mihb.ime — widget bộ gõ trên bar

Nhãn **EN / VI·L / VI·U** ở khu bên phải của bar, cùng panel cài đặt riêng cho
từng bộ gõ. Ba nhãn ứng với ba profile: bàn phím US, Lotus, Unikey.

| Chuột | Việc |
| --- | --- |
| Trái | đi vòng English → Lotus → Unikey — cùng việc với `Ctrl+Shift` |
| Phải | mở panel cài đặt của đúng bộ gõ đang dùng |
| Giữa | nạp lại fcitx5, đồng bộ lại từ viết tắt, kèm notification |
| Hover | thẻ trạng thái: bộ gõ, kiểu gõ, bảng mã và ba phím tắt trên |

Nhãn giữ một bề ngang cố định theo nhãn rộng nhất, để phần bar bên trái không
xê dịch mỗi lần đổi bộ gõ. Nhãn tô màu accent khi đang ở tiếng Việt.

Khi ứng dụng đang focus không có ngữ cảnh nhập (fcitx5 state `0` — hay gặp với
cửa sổ không có ô văn bản nào), nhãn
giữ trạng thái cuối và mờ đi, thẻ hover nói rõ lý do; script cũ báo `EN` trong
tình huống này nên hay gây hiểu nhầm.

## Panel

Hàng nút trên cùng chọn thẳng một trong ba profile; phần dưới đọc và ghi thẳng
cấu hình của addon fcitx5 tương ứng:

- **Tiếng Việt** — `lotus` hoặc `unikey`: kiểu gõ, cách chèn chữ (Lotus),
  bảng mã, kiểu `oà/òa`, kiểm tra chính tả, từ viết tắt.
- **Tiếng Anh** — addon `keyboard`: gợi ý từ, emoji trong gợi ý và trong quick
  phrase, gõ giữ phím.

Hàng cuối mở `unikey-macros` (quản lý từ viết tắt và quick phrase),
`fcitx-ime reload`, và bản cài đặt đầy đủ (`fcitx5-lotus-settings` hoặc
`fcitx5-configtool`).

## Panel mở thì fcitx5 đổi ngữ cảnh nhập

Panel là layer-shell có focus bàn phím, nên lúc mở nó fcitx5 chuyển sang ngữ
cảnh nhập của chính panel — ngữ cảnh mới luôn tắt (`ActiveByDefault=False`),
`fcitx5-remote` trả về `1 keyboard-us` bất kể ứng dụng bên dưới đang gõ tiếng
Việt. Widget xử lý bằng hai việc:

- **Đóng băng vòng đọc** trong lúc panel mở và thêm 500ms sau khi đóng. Không
  có nó thì bấm chuột phải là nhãn nhảy sang `EN` và panel bày cài đặt bàn
  phím US.
- **Hoãn mọi lượt đổi có English ở một đầu** tới khi panel đóng (150ms sau, lúc
  focus đã về ứng dụng). Gọi ngay thì `fcitx5-remote -o` / `-s keyboard-us` chỉ
  đổi ngữ cảnh của panel, ứng dụng không nhận gì. Đổi đi rồi đổi về chỗ cũ
  trước khi đóng thì không chạy lệnh nào.

Lotus ↔ Unikey không cần chờ: `fcitx5-remote -s` chọn input method cho cả
group, không tính theo ngữ cảnh nhập.

## Việc chia cho ai

- `scripts/ime-status` — hai lệnh `fcitx5-remote`, widget gọi mỗi giây. Chỉ có
  state và tên bộ gõ, để vòng lặp một giây không phải trả giá gì đáng kể.
- `~/.local/bin/fcitx-ime` — đọc/ghi cấu hình, đổi bộ gõ, đồng bộ từ viết tắt.
  Widget gọi khi bộ gõ đổi, khi mở panel và sau mỗi lần ghi.
- `fcitx-ime-window.service` — daemon nhớ profile theo từng cửa sổ (xem dưới).
  Widget không dính gì tới việc này: nó chỉ vẽ trạng thái hiện tại.

## Ba profile và trí nhớ theo cửa sổ

`Ctrl+Shift` đi vòng **English → Lotus → Unikey** và ghi lựa chọn đó cho cửa sổ
đang focus. `fcitx-ime-window.service` nghe `activewindowv2` trên socket sự kiện
của Hyprland và đặt lại đúng profile ấy mỗi khi bạn quay về cửa sổ đó.

Phím tắt chạy `~/.local/bin/fcitx-ime-cycle`, chỉ gửi một signal cho daemon
đang chạy: ~5ms, đúng bằng `fcitx5-remote -t` mà nó thay thế. Gọi thẳng
`fcitx-ime cycle` cũng ra cùng kết quả nhưng mất ~85ms — gần hết là thời gian
một tiến trình Python mới nạp `json` và `subprocess`, đủ lâu để nuốt ký tự đầu
tiên nếu gõ ngay sau khi nhả phím. Daemon không chạy thì script tự rơi về
đường chậm ấy.

Cửa sổ chưa từng thấy lấy profile lần cuối bạn chọn cho cùng app, và app chưa
từng gõ tiếng Việt thì ra English. Hai kho:

- `$XDG_RUNTIME_DIR/fcitx-ime/windows.json` — theo địa chỉ cửa sổ, chỉ sống
  trong một phiên Hyprland (địa chỉ cũ vô nghĩa sau khi đăng nhập lại).
- `~/.local/state/fcitx-ime/classes.json` — mặc định của từng app, ở lại lâu dài.

Xem cả hai bằng `fcitx-ime windows`. Chỉ lựa chọn của bạn mới đổi mặc định của
app; lúc daemon khôi phục một cửa sổ cũ thì nó không đụng vào mặc định đó.

Sau khi Hyprland báo focus xong, fcitx5 còn cần một nhịp mới chuyển ngữ cảnh
nhập, nên daemon đợi 80ms rồi mới đặt bộ gõ và đọc lại sau 250ms để đặt lại
nếu lệnh rơi vào ngữ cảnh cũ.

Ghi cấu hình bằng cách sửa tại chỗ trong `~/.config/fcitx5/conf/*.conf` rồi gọi
`ReloadAddonConfig` qua D-Bus, chứ không dùng `SetConfig`: `SetConfig` ghi lại
cả file theo dạng chuẩn của fcitx5 và xoá sạch chú thích tự thêm trong
`lotus.conf`.

## Sửa file này

Bar **không** nạp lại thay đổi trong `Ime.qml` khi lưu — phải `omarchy restart shell`.
