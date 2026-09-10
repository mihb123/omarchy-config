import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget bộ gõ trên bar.
//
//   trái   — đổi giữa tiếng Việt (Lotus/Unikey) và tiếng Anh (bàn phím US)
//   phải   — panel cài đặt của đúng bộ gõ đang dùng
//   giữa   — nạp lại fcitx5 và đồng bộ lại từ viết tắt
//
// Trạng thái đến từ scripts/ime-status (hai lệnh fcitx5-remote, mỗi giây).
// Cấu hình chi tiết đọc/ghi qua ~/.local/bin/fcitx-ime và chỉ gọi khi cần:
// lúc bộ gõ đổi, lúc mở panel, sau mỗi lần ghi.
//
// state của fcitx5 tính theo từng ngữ cảnh nhập (ShareInputState=No), nên khi
// ứng dụng đang focus không có ngữ cảnh nhập (state 0) thì cả VI lẫn EN đều
// sai: widget giữ nhãn cuối cùng và làm mờ, thay vì báo EN như script cũ.
//
// Cùng lý do đó, panel mở là một layer-shell có focus bàn phím: fcitx5 đổi
// sang ngữ cảnh nhập của chính panel, mà ngữ cảnh mới thì luôn tắt
// (ActiveByDefault=False). Nên trong lúc panel mở:
//
//   * vòng đọc trạng thái bị đóng băng — không thì mở panel ra là nhãn nhảy
//     sang EN và panel bày cài đặt bàn phím US;
//   * bật/tắt tiếng Việt hoãn tới lúc panel đóng, khi focus đã về ứng dụng —
//     gọi ngay thì chỉ đổi ngữ cảnh của panel, ứng dụng không nhận gì;
//   * đổi bộ máy (Lotus/Unikey) thì đổi ngay được, vì fcitx5 chọn input
//     method cho cả group chứ không theo từng ngữ cảnh.
Panel {
  id: root
  moduleName: "mihb.ime"
  ipcTarget: "ime"

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string home: Quickshell.env("HOME")
  readonly property string imeTool: home + "/.local/bin/fcitx-ime"
  readonly property string statusScript: home + "/.config/omarchy/plugins/mihb.ime/scripts/ime-status"

  property int imeState: -1
  property string im: ""
  property string mode: "unknown"      // "vi" | "en" | "unknown"
  property string lastMode: "vi"
  property string engine: "lotus"      // lotus | unikey | keyboard-us
  property string addon: "lotus"       // lotus | unikey | keyboard
  property string viEngine: "lotus"
  property var values: ({})
  property int macroCount: 0
  property int phraseCount: 0
  property bool hasLotus: true
  property bool hasUnikey: false
  property string pendingMode: ""      // mode chờ áp dụng khi panel đóng
  property string modeOnOpen: ""       // mode lúc mở panel

  // Panel đang giữ focus bàn phím (và một nhịp sau khi đóng, chờ compositor
  // trả focus về ứng dụng): trạng thái fcitx5 đọc được lúc này là của panel.
  readonly property bool statusFrozen: opened || refocusGrace.running

  readonly property string shownMode: mode === "unknown" ? lastMode : mode
  readonly property bool vietnamese: shownMode === "vi"
  readonly property bool noContext: mode === "unknown"
  readonly property string modeLabel: vietnamese ? "Tiếng Việt" : "English"
  readonly property string engineLabel: engine === "lotus" ? "Lotus"
    : (engine === "unikey" ? "Unikey" : "Bàn phím US")
  readonly property string methodLabel: String(values.InputMethod || "")
  readonly property string charsetLabel: String(values.OutputCharset || "")

  // ------------------------------------------------------------- trạng thái

  function applyStatus(raw) {
    if (root.statusFrozen) return

    var data
    try {
      data = JSON.parse(String(raw || "").trim())
    } catch (e) {
      return
    }

    var previousEngine = root.engine
    var previousMode = root.mode

    root.imeState = Number(data.state)
    root.im = String(data.im || "")

    if (root.imeState === 2) {
      root.mode = "vi"
      root.engine = (root.im === "unikey" || root.im === "lotus") ? root.im : root.viEngine
    } else if (root.imeState === 1) {
      root.mode = "en"
      root.engine = "keyboard-us"
    } else {
      root.mode = "unknown"
    }

    if (root.mode !== "unknown") root.lastMode = root.mode
    if (root.engine !== previousEngine || root.mode !== previousMode) root.refreshDetail()
  }

  function applyDetail(raw) {
    var data
    try {
      data = JSON.parse(String(raw || "").trim())
    } catch (e) {
      return
    }

    root.values = data.values || ({})
    root.addon = String(data.addon || "lotus")
    root.viEngine = String(data.viEngine || "lotus")
    root.macroCount = Number(data.macroCount || 0)
    root.phraseCount = Number(data.phraseCount || 0)
    root.hasLotus = data.hasLotus === true
    root.hasUnikey = data.hasUnikey === true
  }

  function refreshDetail() {
    if (!detailProc.running) detailProc.running = true
  }

  // ------------------------------------------------------------- thao tác

  // Vẽ ngay trạng thái mong đợi, để nhãn và panel không phải đợi vòng đọc.
  function paintMode(target) {
    root.mode = target === "en" ? "en" : "vi"
    root.engine = target === "en" ? "keyboard-us"
      : ((target === "lotus" || target === "unikey") ? target : root.viEngine)
    root.lastMode = root.mode
    root.refreshDetail()
  }

  function switchMode(target) {
    if (root.opened) {
      // Panel còn giữ focus: ghi nhận rồi áp dụng khi đóng (xem đầu file).
      root.pendingMode = target
      root.paintMode(target)
      return
    }

    Util.execArgv([root.imeTool, "switch", target])
    root.paintMode(target)
    statusDelay.restart()
  }

  // Bộ máy là input method của cả group, không tính theo ngữ cảnh nhập, nên
  // đổi được ngay cả khi panel đang giữ focus bàn phím.
  function switchEngine(name) {
    Util.execArgv([root.imeTool, "switch", name])
    root.engine = name
    root.refreshDetail()
  }

  function setValue(key, value) {
    // Vẽ ngay giá trị mới rồi mới ghi, để công tắc không đợi vòng đọc lại.
    var next = ({})
    for (var k in root.values) next[k] = root.values[k]
    next[key] = String(value)
    root.values = next

    Util.execArgv([root.imeTool, "set", root.addon, key, String(value)])
    detailDelay.restart()
  }

  function toggleValue(key) {
    setValue(key, String(root.values[key]) === "True" ? "False" : "True")
  }

  function runDetached(command) {
    Util.execArgv(["bash", "-lc", command])
    root.close()
  }

  Process {
    id: statusProc
    command: [root.statusScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: detailProc
    command: [root.imeTool, "status", "--engine", root.engine]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDetail(text)
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  // Sau khi đổi bộ gõ, fcitx5 cần một nhịp mới báo trạng thái mới.
  Timer {
    id: statusDelay
    interval: 250
    repeat: false
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  // Panel nhả focus bàn phím ngay lúc đóng; đợi thêm một nhịp cho chắc rồi
  // mới đổi bộ gõ, để lệnh rơi vào ngữ cảnh nhập của ứng dụng (đo trên máy
  // này: 50ms đã đủ).
  Timer {
    id: pendingDelay
    interval: 150
    repeat: false
    onTriggered: {
      var target = root.pendingMode
      root.pendingMode = ""
      if (target === "") return
      Util.execArgv([root.imeTool, "switch", target])
      refocusGrace.restart()
    }
  }

  // Giữ đóng băng thêm một quãng sau khi đóng panel: vòng đọc chỉ nói đúng
  // khi focus đã về ứng dụng và lệnh đổi bộ gõ đã có hiệu lực.
  Timer {
    id: refocusGrace
    interval: 500
    repeat: false
  }

  // Sau khi ghi config: đọc lại giá trị hiệu lực (fcitx5 có thể từ chối).
  Timer {
    id: detailDelay
    interval: 450
    repeat: false
    onTriggered: root.refreshDetail()
  }

  Component.onCompleted: root.refreshDetail()

  onOpenedChanged: {
    if (opened) {
      tooltip.shown = false
      root.modeOnOpen = root.shownMode
      root.pendingMode = ""
      root.refreshDetail()
      return
    }

    refocusGrace.restart()
    // Đổi đi rồi đổi về chỗ cũ thì khỏi làm gì: `switch vi` còn bật bộ gõ cho
    // ngữ cảnh đang tắt, nên chạy lại vẫn là một thay đổi thật.
    if (root.pendingMode !== "" && root.pendingMode !== root.modeOnOpen) pendingDelay.restart()
    else root.pendingMode = ""
  }

  // ------------------------------------------- thành phần dùng lại trong panel

  component HintKey: Text {
    textFormat: Text.PlainText
    color: Color.tooltip.text
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
  }

  component HintText: Text {
    textFormat: Text.PlainText
    color: Qt.darker(Color.tooltip.text, 1.35)
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
  }

  component RowTitle: Text {
    textFormat: Text.PlainText
    color: root.bar ? root.bar.foreground : Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  component RowHint: Text {
    textFormat: Text.PlainText
    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.45)
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  component ToggleRow: Item {
    id: toggleRow

    property string label: ""
    property string hint: ""
    property string configKey: ""
    readonly property bool on: String(root.values[configKey]) === "True"

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Style.space(30), labels.implicitHeight + Style.space(8))

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: -Style.space(6)
      anchors.rightMargin: -Style.space(6)
      radius: Style.cornerRadius
      color: rowMouse.containsMouse
        ? Style.hoverFillFor(Color.foreground, Color.accent, Color.urgent)
        : "transparent"
    }

    Column {
      id: labels
      anchors.left: parent.left
      anchors.right: knob.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      RowTitle { width: parent.width; text: toggleRow.label }
      RowHint { width: parent.width; text: toggleRow.hint; visible: toggleRow.hint !== "" }
    }

    ToggleSwitch {
      id: knob
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: toggleRow.on
      interactive: false
      hasCursor: rowMouse.containsMouse
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleValue(toggleRow.configKey)
    }
  }

  component ChoiceRow: Item {
    id: choiceRow

    property string label: ""
    property string configKey: ""
    property var options: []

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Style.space(30), picker.implicitHeight + Style.space(4))

    RowTitle {
      anchors.left: parent.left
      anchors.right: picker.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: choiceRow.label
    }

    Dropdown {
      id: picker
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(150)
      showLabel: false
      options: choiceRow.options
      value: String(root.values[choiceRow.configKey] || "")
      onChanged: function(next) { root.setValue(choiceRow.configKey, next) }
    }
  }

  component ActionRow: Item {
    id: actionRow

    property string icon: ""
    property string label: ""
    property string hint: ""
    signal activated()

    width: parent ? parent.width : 0
    implicitHeight: Style.space(30)

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: -Style.space(6)
      anchors.rightMargin: -Style.space(6)
      radius: Style.cornerRadius
      color: actionMouse.containsMouse
        ? Style.hoverFillFor(Color.foreground, Color.accent, Color.urgent)
        : "transparent"
    }

    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: actionRow.icon
        color: actionMouse.containsMouse
          ? Color.accent
          : (root.bar ? root.bar.foreground : Color.foreground)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      RowTitle {
        anchors.verticalCenter: parent.verticalCenter
        text: actionRow.label
      }

      Item { width: 1; height: 1 }
    }

    RowHint {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: actionRow.hint
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actionRow.activated()
    }
  }

  // -------------------------------------------------------------- nhãn bar

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vietnamese ? "VI" : "EN"
    active: root.vietnamese
    activeColor: Color.accent
    dimmed: root.noContext
    fontSize: Style.font.body
    horizontalMargin: 7.5
    // Tooltip mặc định của bar là text phẳng, căn giữa; thẻ hover bên dưới
    // thay chỗ nó nên để trống ở đây.
    tooltipText: ""

    onPressed: function(pressedButton) {
      tooltip.shown = false
      if (pressedButton === Qt.RightButton) root.toggle()
      else if (pressedButton === Qt.MiddleButton) Util.execArgv([root.imeTool, "reload", "--notify"])
      else {
        root.switchMode(root.vietnamese ? "en" : "vi")
        if (root.opened) root.close()
      }
    }
  }

  Timer {
    id: hoverDelay
    interval: 350
    repeat: false
    onTriggered: if (button.tooltipHovered && !root.opened) tooltip.shown = true
  }

  Connections {
    target: button
    function onTooltipHoveredChanged() {
      if (button.tooltipHovered) {
        hoverDelay.restart()
      } else {
        hoverDelay.stop()
        tooltip.shown = false
      }
    }
  }

  // ------------------------------------------------------------ thẻ hover
  //
  // PopupWindow riêng thay vì PopupCard: PopupCard gọi bar.requestPopout khi
  // mở, tức là chỉ đưa chuột qua nhãn này đã đóng panel đang mở ở widget
  // khác. Một tooltip thì không được phép làm thế.

  PopupWindow {
    id: tooltip

    property bool shown: false

    visible: shown || tipCard.opacity > 0
    color: "transparent"
    implicitWidth: Math.ceil(tipColumn.implicitWidth + Style.space(24))
    implicitHeight: Math.ceil(tipColumn.implicitHeight + Style.space(20))

    anchor {
      id: tipAnchor
      window: button.QsWindow.window
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        var window = button.QsWindow.window
        if (!window || !root.bar) return

        var localX = button.width / 2 - tooltip.implicitWidth / 2
        var localY = button.height + Style.gapsOut
        if (root.bar.position === "bottom") localY = -tooltip.implicitHeight - Style.gapsOut

        var point = window.contentItem.mapFromItem(button, localX, localY)
        point.x = Math.max(Style.gapsOut,
          Math.min(point.x, window.width - tooltip.implicitWidth - Style.gapsOut))

        tipAnchor.rect.x = Math.round(point.x)
        tipAnchor.rect.y = Math.round(point.y)
      }
    }

    BorderSurface {
      id: tipCard
      anchors.fill: parent
      color: Color.tooltip.background
      borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
      radius: Style.cornerRadius
      opacity: tooltip.shown ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }

      Column {
        id: tipColumn
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Style.space(12)
        anchors.topMargin: Style.space(10)
        spacing: Style.space(6)

        Text {
          text: root.modeLabel
          textFormat: Text.PlainText
          color: Color.tooltip.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          text: {
            if (root.vietnamese) {
              var parts = [root.engineLabel]
              if (root.methodLabel) parts.push(root.methodLabel)
              if (root.charsetLabel) parts.push(root.charsetLabel)
              return parts.join(" · ")
            }
            return "Bàn phím US · " + root.phraseCount + " quick phrase"
          }
          textFormat: Text.PlainText
          color: Qt.darker(Color.tooltip.text, 1.35)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Text {
          visible: root.noContext
          text: "Ứng dụng đang mở không dùng bộ gõ"
          textFormat: Text.PlainText
          color: root.bar ? root.bar.urgent : Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Rectangle {
          width: tipHints.implicitWidth
          height: 1
          color: Qt.rgba(Color.tooltip.text.r, Color.tooltip.text.g, Color.tooltip.text.b, 0.22)
        }

        // Grid tự căn cột theo ô rộng nhất, nên hai cột thẳng hàng mà không
        // cần đo chữ bằng tay.
        Grid {
          id: tipHints
          columns: 2
          rowSpacing: Style.space(3)
          columnSpacing: Style.space(10)

          HintKey { text: "Trái · Ctrl+Shift" }
          HintText { text: root.vietnamese ? "sang English" : "sang Tiếng Việt" }

          HintKey { text: "Phải" }
          HintText { text: "cài đặt " + root.engineLabel }

          HintKey { text: "Giữa" }
          HintText { text: "nạp lại fcitx5" }
        }
      }
    }
  }

  // ------------------------------------------------------------------ panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(330)
    contentHeight: panel.fittedContentHeight(content.implicitHeight + Style.space(8))

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        // -------------------------------------------------------- đầu panel

        Item {
          width: parent.width
          implicitHeight: Style.space(24)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.vietnamese ? "Bộ gõ tiếng Việt" : "Bộ gõ tiếng Anh"
            textFormat: Text.PlainText
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          RowHint {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.noContext ? "không có ngữ cảnh nhập" : root.engineLabel
          }
        }

        ButtonGroup {
          width: parent.width
          spacing: Style.space(6)
          focusable: false
          value: root.shownMode
          options: [
            { value: "vi", label: "Tiếng Việt" },
            { value: "en", label: "English" }
          ]
          onChanged: function(next) { root.switchMode(next) }
        }

        PanelSeparator {}

        // ------------------------------------------------- bộ gõ tiếng Việt

        Column {
          width: parent.width
          spacing: Style.space(2)
          visible: root.vietnamese

          PanelSectionHeader {
            text: "Bộ máy"
            visible: root.hasLotus && root.hasUnikey
          }

          ButtonGroup {
            width: parent.width
            spacing: Style.space(6)
            focusable: false
            visible: root.hasLotus && root.hasUnikey
            value: root.engine
            options: [
              { value: "lotus", label: "Lotus" },
              { value: "unikey", label: "Unikey" }
            ]
            onChanged: function(next) { root.switchEngine(next) }
          }

          Item { width: 1; implicitHeight: Style.space(6); visible: root.hasLotus && root.hasUnikey }

          ChoiceRow {
            label: "Kiểu gõ"
            configKey: "InputMethod"
            options: root.addon === "lotus"
              ? ["Telex", "VNI", "Telex + VNI", "VIQR", "Telex + VNI + VIQR"]
              : ["Telex", "VNI", "VIQR", "Simple Telex"]
          }

          ChoiceRow {
            label: "Cách chèn chữ"
            configKey: "Mode"
            visible: root.addon === "lotus"
            options: ["Uinput (Smooth)", "Uinput (Super Smooth)", "Uinput (Slow)", "Preedit", "Surrounding Text"]
          }

          ChoiceRow {
            label: "Bảng mã"
            configKey: "OutputCharset"
            options: root.addon === "lotus"
              ? ["Unicode", "TCVN3 (ABC)", "VNI Windows", "VIQR"]
              : ["Unicode", "TCVN3", "VNI Win", "VIQR"]
          }

          ToggleRow {
            label: "Kiểu oà, uý"
            hint: "thay vì òa, úy"
            configKey: "ModernStyle"
          }

          ToggleRow {
            label: "Kiểm tra chính tả"
            hint: "tự bỏ dấu khi từ không hợp lệ"
            configKey: "SpellCheck"
          }

          ToggleRow {
            label: "Từ viết tắt"
            hint: root.macroCount + " từ · dùng chung Lotus và Unikey"
            configKey: root.addon === "lotus" ? "EnableMacro" : "Macro"
          }
        }

        // -------------------------------------------------- bàn phím tiếng Anh

        Column {
          width: parent.width
          spacing: Style.space(2)
          visible: !root.vietnamese

          ToggleRow {
            label: "Gợi ý từ khi gõ"
            hint: "bảng ứng viên của bàn phím US"
            configKey: "EnableHintByDefault"
          }

          ToggleRow {
            label: "Emoji trong gợi ý"
            configKey: "EnableEmoji"
          }

          ToggleRow {
            label: "Emoji trong quick phrase"
            hint: root.phraseCount + " quick phrase · Super+;"
            configKey: "EnableQuickPhraseEmoji"
          }

          ToggleRow {
            label: "Giữ phím ra ký tự đặc biệt"
            configKey: "EnableLongPress"
          }
        }

        PanelSeparator {}

        Column {
          width: parent.width
          spacing: Style.space(2)

          ActionRow {
            icon: "\uf031"
            label: root.vietnamese ? "Quản lý từ viết tắt" : "Quản lý quick phrase"
            hint: root.vietnamese ? root.macroCount + " từ" : root.phraseCount + " mục"
            onActivated: root.runDetached("unikey-macros")
          }

          ActionRow {
            icon: "\uf021"
            label: "Nạp lại fcitx5"
            hint: "đồng bộ lại từ viết tắt"
            onActivated: root.runDetached("fcitx-ime reload --notify")
          }

          ActionRow {
            icon: "\uf013"
            label: root.engine === "lotus" ? "Cài đặt đầy đủ Lotus" : "Cài đặt fcitx5"
            hint: root.engine === "lotus" ? "fcitx5-lotus-settings" : "fcitx5-configtool"
            onActivated: root.runDetached(
              root.engine === "lotus" ? "fcitx5-lotus-settings" : "fcitx5-configtool")
          }
        }
      }
    }
  }
}
