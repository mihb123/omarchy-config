import QtQuick
import qs.Commons
import qs.Ui

// Notification manager for the bar.
//
// Omarchy ships `omarchy.notifications` as a *service* only (see its
// manifest.json: kinds = ["service"]). It runs the daemon, paints the toasts,
// keeps a 10-entry history under ~/.local/state/omarchy/notifications/history/
// and owns the do-not-disturb flag — but it puts nothing in the bar. This
// widget is that missing front end.
//
// The service object itself is reachable through the shell's first-party
// registry, so this talks to it directly rather than shelling out to
// `omarchy-shell notifications ...` on every click.
BarIconButton {
  id: root

  // Filled in by the bar after loading (see plugins/bar/README.md,
  // "Custom user modules"). `bar` already exists on WidgetButton.
  property string moduleName: ""
  property var settings: ({})

  // firstPartyServiceFor() keys on the *manifest* id and does not follow a
  // clone's `clonedFrom` (shell.qml's serviceFor skips resolveEnabledId), so
  // ask for the local clone first and fall back to the built-in. That keeps
  // this widget working whether or not mihb.notifications is enabled.
  readonly property var service: bar && bar.shell
    ? (bar.shell.firstPartyServiceFor("mihb.notifications")
       || bar.shell.firstPartyServiceFor("omarchy.notifications"))
    : null
  readonly property bool dnd: service ? service.doNotDisturb === true : false
  readonly property int onScreen: service && service.popupModel ? service.popupModel.count : 0

  // 󰂛 bell-off (silenced) · 󱅫 bell-badge (toasts up) · 󰂚 bell (idle)
  text: dnd ? "󰂛" : (onScreen > 0 ? "󱅫" : "󰂚")

  // Paint in the urgent color while something is actually on screen, and fade
  // out while silenced, so the icon reads at a glance without a badge.
  active: onScreen > 0 && !dnd
  dimmed: dnd

  tooltipText: (dnd ? "Notifications silenced" : "Notifications")
    + (onScreen > 0 ? "  ·  " + onScreen + " on screen" : "")
    + "\nleft — history          SUPER + SHIFT + ALT + ,"
    + "\nright — " + (dnd ? "allow" : "silence") + "    SUPER + CTRL + ,"
    + "\nmiddle — dismiss all   SUPER + SHIFT + ,"

  onPressed: function(button) {
    if (!root.service) return

    if (button === Qt.RightButton)
      root.service.setDoNotDisturb(!root.service.doNotDisturb)
    else if (button === Qt.MiddleButton)
      root.service.clearPopups()
    else
      root.service.showRecentHistory()
  }
}
