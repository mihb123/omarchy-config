# mihb.ime — widget bộ gõ trên bar

Nhãn **VI / EN** ở khu bên phải của bar, cùng panel cài đặt riêng cho từng bộ gõ.

| Chuột | Việc |
| --- | --- |
| Trái | đổi giữa tiếng Việt (Lotus) và tiếng Anh (bàn phím US) — cùng việc với `Ctrl+Shift` |
| Phải | mở panel cài đặt của đúng bộ gõ đang dùng |
| Giữa | nạp lại fcitx5, đồng bộ lại từ viết tắt, kèm notification |
| Hover | thẻ trạng thái: bộ gõ, kiểu gõ, bảng mã và ba phím tắt trên |

Nhãn tô màu accent khi đang ở tiếng Việt. Khi ứng dụng đang focus không có ngữ
cảnh nhập (fcitx5 state `0` — hay gặp với cửa sổ không có ô văn bản nào), nhãn
giữ trạng thái cuối và mờ đi, thẻ hover nói rõ lý do; script cũ báo `EN` trong
tình huống này nên hay gây hiểu nhầm.

## Panel

Panel đọc và ghi thẳng cấu hình của addon fcitx5 tương ứng:

- **Tiếng Việt** — `lotus` hoặc `unikey`: bộ máy, kiểu gõ, cách chèn chữ (Lotus),
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
- **Hoãn việc bật/tắt tiếng Việt** tới khi panel đóng (150ms sau, lúc focus đã
  về ứng dụng). Gọi ngay thì `fcitx5-remote -o` / `-s keyboard-us` chỉ đổi ngữ
  cảnh của panel, ứng dụng không nhận gì. Đổi đi rồi đổi về chỗ cũ trước khi
  đóng thì không chạy lệnh nào.

Đổi bộ máy Lotus ↔ Unikey không cần chờ: `fcitx5-remote -s` chọn input method
cho cả group, không tính theo ngữ cảnh nhập.

## Việc chia cho ai

- `scripts/ime-status` — hai lệnh `fcitx5-remote`, widget gọi mỗi giây. Chỉ có
  state và tên bộ gõ, để vòng lặp một giây không phải trả giá gì đáng kể.
- `~/.local/bin/fcitx-ime` — đọc/ghi cấu hình, đổi bộ gõ, đồng bộ từ viết tắt.
  Widget gọi khi bộ gõ đổi, khi mở panel và sau mỗi lần ghi.

Ghi cấu hình bằng cách sửa tại chỗ trong `~/.config/fcitx5/conf/*.conf` rồi gọi
`ReloadAddonConfig` qua D-Bus, chứ không dùng `SetConfig`: `SetConfig` ghi lại
cả file theo dạng chuẩn của fcitx5 và xoá sạch chú thích tự thêm trong
`lotus.conf`.

## Sửa file này

Bar **không** nạp lại thay đổi trong `Ime.qml` khi lưu — phải `omarchy restart shell`.
