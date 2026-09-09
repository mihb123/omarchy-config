import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "quick-settings"
  ipcTarget: "quick-settings"

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "quick-settings-view"
    function set(viewName: string): void {
      if (viewName === "main" || !viewName) {
        if (!root.opened) root.open()
      } else {
        root.openOmarchyPanel(viewName)
      }
    }
  }

  property int volume: 65
  property bool muted: false
  property int brightness: 50
  property bool wifiConnected: true
  property string wifiSsid: "Wi-Fi"
  property bool btPowered: false
  property string btDevice: "Off"
  property bool tailscaleConnected: true
  property string tailscaleIp: ""
  property string displayName: "eDP-1"
  property bool nightlightActive: false

  Process {
    id: statusProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/quick-settings/scripts/status"]
    stdout: SplitParser {
      onRead: function(data) {
        var str = String(data).trim()
        if (!str) return
        try {
          var obj = JSON.parse(str)
          if (obj.audio) {
            root.volume = obj.audio.volume
            root.muted = obj.audio.muted
          }
          if (obj.brightness) root.brightness = obj.brightness.percent
          if (obj.wifi) {
            root.wifiConnected = obj.wifi.connected
            root.wifiSsid = obj.wifi.ssid
          }
          if (obj.bluetooth) {
            root.btPowered = obj.bluetooth.powered
            root.btDevice = obj.bluetooth.device
          }
          if (obj.tailscale) {
            root.tailscaleConnected = obj.tailscale.connected
            root.tailscaleIp = obj.tailscale.ip
          }
          if (obj.display) {
            root.displayName = obj.display.name || "eDP-1"
            root.nightlightActive = obj.display.nightlight
          }
        } catch(e) {}
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!statusProc.running) statusProc.running = true
    }
  }

  onOpenedChanged: {
    if (opened) {
      closeAllNativePanels()
      root.refresh()
    }
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runCmd(cmd) {
    if (root.bar) root.bar.run(cmd)
    Qt.callLater(function() { refreshTimer.restart(); root.refresh() })
  }

  function setVolume(val) {
    root.volume = val
    runCmd("pamixer --set-volume " + val)
  }

  function toggleMute() {
    root.muted = !root.muted
    runCmd("pamixer -t")
  }

  function setBrightness(val) {
    root.brightness = val
    runCmd("brightnessctl set " + val + "%")
  }

  function toggleWifi() {
    runCmd("nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on")
  }

  function toggleBluetooth() {
    runCmd("bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on")
  }

  function toggleTailscale() {
    runCmd("tailscale status | head -n 1 | grep -q '100\\.' && tailscale down || tailscale up")
  }

  function launchAgent() {
    root.close()
    runCmd("omarchy agent")
  }

  function toggleNightlight() {
    runCmd("omarchy toggle nightlight")
  }

  function closeAllNativePanels() {
    if (networkLoader.item && networkLoader.item.opened) networkLoader.item.close()
    if (bluetoothLoader.item && bluetoothLoader.item.opened) bluetoothLoader.item.close()
    if (audioLoader.item && audioLoader.item.opened) audioLoader.item.close()
    if (monitorLoader.item && monitorLoader.item.opened) monitorLoader.item.close()
    if (tailscaleLoader.item && tailscaleLoader.item.opened) tailscaleLoader.item.close()
    if (agentsLoader.item && agentsLoader.item.opened) agentsLoader.item.close()
  }

  function openOmarchyPanel(name) {
    root.close()
    closeAllNativePanels()
    Qt.callLater(function() {
      if (name === "wifi" || name === "network") {
        if (networkLoader.item) networkLoader.item.open()
      } else if (name === "bluetooth" || name === "bt") {
        if (bluetoothLoader.item) bluetoothLoader.item.open()
      } else if (name === "audio" || name === "volume") {
        if (audioLoader.item) audioLoader.item.open()
      } else if (name === "display" || name === "brightness" || name === "monitor") {
        if (monitorLoader.item) monitorLoader.item.open()
      } else if (name === "tailscale") {
        if (tailscaleLoader.item) tailscaleLoader.item.open()
      } else if (name === "agents" || name === "agent") {
        if (agentsLoader.item) agentsLoader.item.open()
      }
    })
  }

  onBarChanged: {
    if (networkLoader.item) networkLoader.item.bar = root.bar
    if (bluetoothLoader.item) bluetoothLoader.item.bar = root.bar
    if (audioLoader.item) audioLoader.item.bar = root.bar
    if (monitorLoader.item) monitorLoader.item.bar = root.bar
    if (tailscaleLoader.item) tailscaleLoader.item.bar = root.bar
    if (agentsLoader.item) agentsLoader.item.bar = root.bar
  }


  // Top Bar Pill Button
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 8
    fixedWidth: vertical ? -1 : Math.max(88, Math.round(barRow.implicitWidth + Style.space(20)))
    fixedHeight: vertical ? Style.space(28) : -1
    tooltipText: "Quick Settings (Control Center)\nClick to open · Wi-Fi: " + root.wifiSsid + " · Vol: " + root.volume + "%"

    onPressed: root.toggle()

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.space(3)
      anchors.bottomMargin: Style.space(3)
      radius: Style.space(12)
      color: buttonMouse.containsMouse || root.opened ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1, 1, 1, 0.08)
      border.color: root.opened ? Color.accent : Qt.rgba(1, 1, 1, 0.15)
      border.width: 1
    }

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: Style.space(7)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󱄅"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        color: root.opened ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Style.space(12)
        color: Qt.rgba(1, 1, 1, 0.2)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        color: root.wifiConnected ? (root.bar ? root.bar.barForeground : Color.foreground) : Qt.rgba(1,1,1,0.3)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        color: root.btPowered ? (root.bar ? root.bar.barForeground : Color.foreground) : Qt.rgba(1,1,1,0.3)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.muted ? "" : (root.volume > 50 ? "" : (root.volume > 0 ? "" : ""))
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        color: root.muted ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.barForeground : Color.foreground)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.tailscaleConnected
        text: "󰒊"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        color: root.tailscaleConnected ? (root.bar ? root.bar.barForeground : Color.foreground) : Qt.rgba(1,1,1,0.3)
      }
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggle()
    }
  }

  // Loaders for default Omarchy service panels
  Loader {
    id: networkLoader
    anchors.fill: button
    visible: false
    active: true
    source: "/usr/share/omarchy/shell/plugins/panels/network/Panel.qml"
    onLoaded: { if (item) item.bar = root.bar }
  }

  Loader {
    id: bluetoothLoader
    anchors.fill: button
    visible: false
    active: true
    source: "/usr/share/omarchy/shell/plugins/panels/bluetooth/Panel.qml"
    onLoaded: { if (item) item.bar = root.bar }
  }

  Loader {
    id: audioLoader
    anchors.fill: button
    visible: false
    active: true
    source: "/usr/share/omarchy/shell/plugins/panels/audio/Panel.qml"
    onLoaded: { if (item) item.bar = root.bar }
  }

  Loader {
    id: monitorLoader
    anchors.fill: button
    visible: false
    active: true
    source: "/usr/share/omarchy/shell/plugins/panels/monitor/Panel.qml"
    onLoaded: { if (item) item.bar = root.bar }
  }

  Loader {
    id: tailscaleLoader
    anchors.fill: button
    visible: false
    active: true
    source: "/usr/share/omarchy/shell/plugins/panels/tailscale/Panel.qml"
    onLoaded: { if (item) item.bar = root.bar }
  }

  Loader {
    id: agentsLoader
    anchors.fill: button
    visible: false
    active: true
    source: "/usr/share/omarchy/shell/plugins/agents/Panel.qml"
    onLoaded: { if (item) item.bar = root.bar }
  }



  // Dropdown Popup Panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(400)
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(16))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        // ================= HEADER =================
        Item {
          width: parent.width
          height: Style.space(28)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Quick Settings"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.weight: Font.Bold
            color: root.bar ? root.bar.foreground : Color.foreground
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.space(13)
            color: closeMouse.containsMouse ? Style.hoverFillFor(Color.urgent, Color.urgent) : Qt.rgba(1, 1, 1, 0.06)

            Text {
              anchors.centerIn: parent
              text: ""
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              color: closeMouse.containsMouse ? (root.bar ? root.bar.urgent : Color.urgent) : Qt.rgba(1, 1, 1, 0.6)
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(12)

          Column {
            width: parent.width
            spacing: Style.space(8)

            // Volume Slider Row with '>'
            Row {
              width: parent.width
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: Style.space(6)
                color: volMouse.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1, 1, 1, 0.06)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: root.muted ? "" : (root.volume > 50 ? "" : "")
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  color: root.muted ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.foreground : Color.foreground)
                }

                MouseArea {
                  id: volMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleMute()
                }
              }

              PanelSlider {
                id: volSlider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(32 + 42 + 28 + 24)
                bar: root.bar
                value: root.volume
                minimum: 0
                maximum: 100
                step: 1
                onMoved: function(v) { root.setVolume(Math.round(v)) }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(42)
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "Mute" : (root.volume + "%")
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                color: root.bar ? root.bar.foreground : Color.foreground
              }

              Rectangle {
                width: Style.space(28)
                height: Style.space(28)
                radius: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                color: volChevronM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1, 1, 1, 0.06)

                Text {
                  anchors.centerIn: parent
                  text: ""
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: volChevronM.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.5)
                }

                MouseArea {
                  id: volChevronM
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openOmarchyPanel("audio")
                }
              }
            }

            // Brightness Slider Row with '>'
            Row {
              width: parent.width
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(28)
                height: Style.space(28)
                radius: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.06)

                Text {
                  anchors.centerIn: parent
                  text: "󰃠"
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.iconLarge
                  color: Color.accent
                }
              }

              Slider {
                id: brightSlider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(28 + 42 + 28 + 24)
                from: 5
                to: 100
                value: root.brightness
                stepSize: 5
                onMoved: function() { root.setBrightness(Math.round(value)) }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(42)
                horizontalAlignment: Text.AlignRight
                text: root.brightness + "%"
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                color: root.bar ? root.bar.foreground : Color.foreground
              }

              Rectangle {
                width: Style.space(28)
                height: Style.space(28)
                radius: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                color: brightChevronM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1, 1, 1, 0.06)

                Text {
                  anchors.centerIn: parent
                  text: ""
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: brightChevronM.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.5)
                }

                MouseArea {
                  id: brightChevronM
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openOmarchyPanel("display")
                }
              }
            }
          }

          PanelSeparator { width: parent.width }

          // 6 Quick Settings Tiles
          Grid {
            width: parent.width
            columns: 2
            spacing: Style.space(8)

            // 1. Wi-Fi Tile
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: Style.space(52)
              radius: Style.space(8)
              color: root.wifiConnected ? Style.selectedFillFor(Color.foreground, Color.accent) : (wifiLeftM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1,1,1,0.06))
              border.color: root.wifiConnected ? Color.accent : Qt.rgba(1,1,1,0.12)
              border.width: 1

              Row {
                anchors.fill: parent

                Item {
                  width: parent.width - Style.space(34)
                  height: parent.height

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(4)
                    spacing: Style.space(8)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: ""
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.title
                      color: root.wifiConnected ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - Style.space(28)

                      Text {
                        text: "Wi-Fi"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                        color: root.bar ? root.bar.foreground : Color.foreground
                      }
                      Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.wifiSsid
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      }
                    }
                  }

                  MouseArea {
                    id: wifiLeftM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWifi()
                  }
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 1
                  height: Style.space(22)
                  color: Qt.rgba(1, 1, 1, 0.15)
                }

                Item {
                  width: Style.space(33)
                  height: parent.height

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: Style.space(3)
                    radius: Style.space(6)
                    color: wifiRightM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : "transparent"
                  }

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    color: wifiRightM.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.55)
                  }

                  MouseArea {
                    id: wifiRightM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openOmarchyPanel("wifi")
                  }
                }
              }
            }

            // 2. Bluetooth Tile
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: Style.space(52)
              radius: Style.space(8)
              color: root.btPowered ? Style.selectedFillFor(Color.foreground, Color.accent) : (btLeftM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1,1,1,0.06))
              border.color: root.btPowered ? Color.accent : Qt.rgba(1,1,1,0.12)
              border.width: 1

              Row {
                anchors.fill: parent

                Item {
                  width: parent.width - Style.space(34)
                  height: parent.height

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(4)
                    spacing: Style.space(8)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: ""
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.title
                      color: root.btPowered ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - Style.space(28)

                      Text {
                        text: "Bluetooth"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                        color: root.bar ? root.bar.foreground : Color.foreground
                      }
                      Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.btDevice
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      }
                    }
                  }

                  MouseArea {
                    id: btLeftM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleBluetooth()
                  }
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 1
                  height: Style.space(22)
                  color: Qt.rgba(1, 1, 1, 0.15)
                }

                Item {
                  width: Style.space(33)
                  height: parent.height

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: Style.space(3)
                    radius: Style.space(6)
                    color: btRightM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : "transparent"
                  }

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    color: btRightM.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.55)
                  }

                  MouseArea {
                    id: btRightM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openOmarchyPanel("bluetooth")
                  }
                }
              }
            }

            // 3. Tailscale Tile
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: Style.space(52)
              radius: Style.space(8)
              color: root.tailscaleConnected ? Style.selectedFillFor(Color.foreground, Color.accent) : (tsLeftM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1,1,1,0.06))
              border.color: root.tailscaleConnected ? Color.accent : Qt.rgba(1,1,1,0.12)
              border.width: 1

              Row {
                anchors.fill: parent

                Item {
                  width: parent.width - Style.space(34)
                  height: parent.height

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(4)
                    spacing: Style.space(8)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰒊"
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.title
                      color: root.tailscaleConnected ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - Style.space(28)

                      Text {
                        text: "Tailscale"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                        color: root.bar ? root.bar.foreground : Color.foreground
                      }
                      Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.tailscaleConnected ? (root.tailscaleIp || "Connected") : "Disconnected"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      }
                    }
                  }

                  MouseArea {
                    id: tsLeftM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleTailscale()
                  }
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 1
                  height: Style.space(22)
                  color: Qt.rgba(1, 1, 1, 0.15)
                }

                Item {
                  width: Style.space(33)
                  height: parent.height

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: Style.space(3)
                    radius: Style.space(6)
                    color: tsRightM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : "transparent"
                  }

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    color: tsRightM.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.55)
                  }

                  MouseArea {
                    id: tsRightM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openOmarchyPanel("tailscale")
                  }
                }
              }
            }

            // 4. Agents Tile
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: Style.space(52)
              radius: Style.space(8)
              color: agLeftM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1,1,1,0.06)
              border.color: Qt.rgba(1,1,1,0.12)
              border.width: 1

              Row {
                anchors.fill: parent

                Item {
                  width: parent.width - Style.space(34)
                  height: parent.height

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(4)
                    spacing: Style.space(8)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󱚣"
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.title
                      color: Color.accent
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - Style.space(28)

                      Text {
                        text: "Agents"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                        color: root.bar ? root.bar.foreground : Color.foreground
                      }
                      Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "Launch Agent"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      }
                    }
                  }

                  MouseArea {
                    id: agLeftM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchAgent()
                  }
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 1
                  height: Style.space(22)
                  color: Qt.rgba(1, 1, 1, 0.15)
                }

                Item {
                  width: Style.space(33)
                  height: parent.height

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: Style.space(3)
                    radius: Style.space(6)
                    color: agRightM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : "transparent"
                  }

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    color: agRightM.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.55)
                  }

                  MouseArea {
                    id: agRightM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openOmarchyPanel("agents")
                  }
                }
              }
            }

            // 5. Display / Night Light Tile
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: Style.space(52)
              radius: Style.space(8)
              color: root.nightlightActive ? Style.selectedFillFor(Color.foreground, Color.accent) : (nlLeftM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1,1,1,0.06))
              border.color: root.nightlightActive ? Color.accent : Qt.rgba(1,1,1,0.12)
              border.width: 1

              Row {
                anchors.fill: parent

                Item {
                  width: parent.width - Style.space(34)
                  height: parent.height

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(4)
                    spacing: Style.space(8)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰍹"
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.title
                      color: root.nightlightActive ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - Style.space(28)

                      Text {
                        text: "Night Light"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                        color: root.bar ? root.bar.foreground : Color.foreground
                      }
                      Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.nightlightActive ? "Active" : root.displayName
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      }
                    }
                  }

                  MouseArea {
                    id: nlLeftM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleNightlight()
                  }
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 1
                  height: Style.space(22)
                  color: Qt.rgba(1, 1, 1, 0.15)
                }

                Item {
                  width: Style.space(33)
                  height: parent.height

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: Style.space(3)
                    radius: Style.space(6)
                    color: nlRightM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : "transparent"
                  }

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    color: nlRightM.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.55)
                  }

                  MouseArea {
                    id: nlRightM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openOmarchyPanel("display")
                  }
                }
              }
            }

            // 6. Activity / Btop Tile
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: Style.space(52)
              radius: Style.space(8)
              color: btopM.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1,1,1,0.06)
              border.color: Qt.rgba(1,1,1,0.12)
              border.width: 1

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: ""
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.title
                  color: Color.accent
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(28)

                  Text {
                    text: "Activity"
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.weight: Font.DemiBold
                    color: root.bar ? root.bar.foreground : Color.foreground
                  }
                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Open Btop"
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                  }
                }
              }

              MouseArea {
                id: btopM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openBtop()
              }
            }
          }
        }
      }
    }
  }
}
