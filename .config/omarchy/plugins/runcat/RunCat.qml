import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "runcat"

  property real cpuUsage: 0.0
  property int currentFrame: 0

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function updateSpeed() {
    var ms = Math.ceil((25 / Math.sqrt(root.cpuUsage + 30) - 2) * 200)
    animTimer.interval = Math.max(30, Math.min(500, ms))
  }

  Timer {
    id: animTimer
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      root.currentFrame = (root.currentFrame + 1) % 5
    }
  }

  Process {
    id: cpuProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/runcat/scripts/runcat-cpu"]
    running: true
    stdout: SplitParser {
      onRead: function(data) {
        var str = String(data).trim()
        if (!str) return
        var val = parseFloat(str)
        if (!isNaN(val)) {
          root.cpuUsage = Math.max(0, Math.min(100, val))
          root.updateSpeed()
        }
      }
    }
    onExited: function(exitCode) {
      if (root.visible) restartTimer.start()
    }
  }

  Timer {
    id: restartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!cpuProc.running) cpuProc.running = true
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 6
    fixedWidth: vertical ? -1 : Math.round(contentRow.implicitWidth + scaledHorizontalMargin * 2)

    tooltipText: "RunCat  ·  " + Math.round(root.cpuUsage) + "% CPU\nleft — System Monitor (btop)"

    onTooltipTextChanged: {
      if (tooltipHovered && root.bar) {
        root.bar.showTooltip(button, tooltipText)
      }
    }

    onPressed: function(b) {
      if (b === Qt.LeftButton && root.bar) {
        root.bar.run("omarchy-launch-or-focus-tui btop")
      }
    }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      Item {
        id: catCanvas
        width: 20
        height: 20
        implicitWidth: 20
        implicitHeight: 20
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: 5
          Item {
            anchors.fill: parent
            visible: root.currentFrame === index

            Image {
              id: frameImg
              anchors.fill: parent
              fillMode: Image.PreserveAspectFit
              sourceSize.width: Math.round(Math.max(16, width) * (Screen.devicePixelRatio || 1))
              sourceSize.height: Math.round(Math.max(16, height) * (Screen.devicePixelRatio || 1))
              source: Qt.resolvedUrl("icons/sprite-" + index + ".svg")
              visible: false
              layer.enabled: true
            }

            MultiEffect {
              anchors.fill: frameImg
              source: frameImg
              colorization: 1.0
              colorizationColor: (root.cpuUsage >= 85) ? (root.bar ? root.bar.urgent : Color.urgent) : button.foreground
            }
          }
        }
      }

      Text {
        id: cpuLabel
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.cpuUsage) + "%"
        color: (root.cpuUsage >= 85) ? (root.bar ? root.bar.urgent : Color.urgent) : button.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering

        Behavior on color {
          enabled: !root.bar || root.bar.foregroundAnimationEnabled
          ColorAnimation { duration: 160 }
        }
      }
    }
  }
}
