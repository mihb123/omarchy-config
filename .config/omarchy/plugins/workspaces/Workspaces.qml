import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "workspaces"

  property var activeWorkspaceIds: []

  function workspaceById(id) {
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function getActiveWorkspaceIds() {
    var ids = []
    var focusedId = 1
    if (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id > 0) {
      focusedId = Hyprland.focusedWorkspace.id
    }

    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (ws && ws.id > 0 && ws.id <= 20) {
        var hasWindows = ws.toplevels !== null && ws.toplevels.values && ws.toplevels.values.length > 0
        if (hasWindows || ws.id === focusedId) {
          if (ids.indexOf(ws.id) === -1) ids.push(ws.id)
        }
      }
    }

    if (ids.indexOf(focusedId) === -1 && focusedId > 0) {
      ids.push(focusedId)
    }

    ids.sort(function(a, b) { return a - b })
    return ids
  }

  function updateList() {
    var newIds = getActiveWorkspaceIds()
    if (JSON.stringify(newIds) !== JSON.stringify(root.activeWorkspaceIds)) {
      root.activeWorkspaceIds = newIds
    }
  }

  function focusWorkspace(id) {
    var cmd = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })")
    if (root.bar && root.bar.run) {
      root.bar.run(cmd)
    }
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      root.updateList()
    }
  }

  Timer {
    id: refreshTimer
    interval: 250
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.updateList()
  }

  Component.onCompleted: root.updateList()

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: root.vertical ? root.barSize : Math.max(1, grid.implicitWidth + trailingGap)
  implicitHeight: root.vertical ? Math.max(1, grid.implicitHeight + trailingGap) : root.barSize

  GridLayout {
    id: grid
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    columns: root.vertical ? 1 : Math.max(1, root.activeWorkspaceIds.length)
    columnSpacing: root.vertical ? 0 : Style.space(4)
    rowSpacing: root.vertical ? Style.space(4) : 0

    Repeater {
      model: root.activeWorkspaceIds

      WidgetButton {
        id: wsBtn
        required property int modelData

        readonly property var wsObj: root.workspaceById(modelData)
        readonly property bool hasWindows: wsObj !== null && wsObj.toplevels !== null && wsObj.toplevels.values && wsObj.toplevels.values.length > 0
        readonly property bool isCurrent: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        labelVisible: false
        hasVisualContent: true
        horizontalMargin: 0
        verticalPadding: 0
        fixedWidth: root.vertical ? root.barSize : Style.space(26)
        fixedHeight: root.vertical ? Style.space(26) : root.barSize
        tooltipText: "Workspace " + modelData + (isCurrent ? " (Active)" : (hasWindows ? " (Has windows)" : ""))

        onPressed: function() { root.focusWorkspace(modelData) }

        Rectangle {
          id: pill
          anchors.centerIn: parent
          width: Style.space(24)
          height: Style.space(22)
          radius: Style.space(6)
          color: wsBtn.isCurrent ? Color.accent : (btnMouse.containsMouse ? Style.hoverFillFor(Color.foreground, Color.foreground) : Qt.rgba(1, 1, 1, 0.08))
          border.color: wsBtn.isCurrent ? Color.accent : Qt.rgba(1, 1, 1, 0.15)
          border.width: 1

          Behavior on color {
            ColorAnimation { duration: 120 }
          }

          Text {
            anchors.centerIn: parent
            text: String(wsBtn.modelData)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.weight: wsBtn.isCurrent ? Font.Bold : Font.DemiBold
            color: wsBtn.isCurrent ? Color.background : (root.bar ? root.bar.barForeground : Color.foreground)

            Behavior on color {
              ColorAnimation { duration: 120 }
            }
          }

          // Small dot indicator for inactive workspace with windows
          Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(2)
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(3)
            height: Style.space(3)
            radius: Style.space(1.5)
            color: Color.accent
            visible: !wsBtn.isCurrent && wsBtn.hasWindows
          }
        }

        MouseArea {
          id: btnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(wsBtn.modelData)
        }
      }
    }
  }
}
