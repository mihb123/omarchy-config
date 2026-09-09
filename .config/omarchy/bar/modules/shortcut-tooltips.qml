import QtQuick

// Give the bar widgets a hover tooltip naming their keyboard shortcut.
//
// The machinery is already there: every bar icon descends from Ui/WidgetButton,
// which owns a `tooltipText` property and a hover MouseArea that calls
// bar.showTooltip()/hideTooltip(). Most first-party widgets just never set
// `tooltipText` — only the tray, the active-window label and the media widget
// do. So this fills it in from the outside.
//
// Doing it here rather than with `omarchy plugin clone` on each widget is
// deliberate: a clone forks several hundred to two thousand lines of QML per
// icon into ~/.config and freezes it at today's version, for a one-line change.
// This file leans on a handful of internals instead — bar.moduleSlots,
// slot.moduleName, WidgetButton.tooltipText/slotSize and, for the indicators,
// BarIndicator.activeTooltipText/inactiveTooltipText/effectiveActive. If
// Omarchy ever renames those the tooltips quietly stop appearing and nothing
// else breaks.
//
// This module paints nothing; it takes a zero-width slot purely to be handed a
// `bar` reference.

Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  implicitWidth: 0
  implicitHeight: 0

  // Bar widget id -> whole tooltip, for widgets that have none of their own.
  // `omarchy plugin list` prints the ids, `omarchy menu keybindings --print`
  // prints the shortcuts. Widgets not listed keep their own tooltip (the tray)
  // or stay bare. The left section (omarchy.menu — SUPER + SPACE,
  // omarchy.workspaces) can be labelled here too.
  readonly property var labels: ({
    // right section
    "omarchy.audio":         "Audio\nSUPER + CTRL + A",
    "omarchy.network":       "Network\nSUPER + CTRL + W",
    "omarchy.bluetooth":     "Bluetooth\nSUPER + CTRL + B",
    "omarchy.monitor":       "Display\nSUPER + CTRL + D",
    "omarchy.power":         "Power\nSUPER + CTRL + P",
    "omarchy.agents":        "Agents\nSUPER + SHIFT + CTRL + A",
    "omarchy.tailscale":     "Tailscale",

    // center section
    "omarchy.clock":         "Calendar\nSUPER + CTRL + ALT + D",
    "omarchy.weather":       "Weather\nSUPER + CTRL + ALT + W",
    "omarchy.system-update": "Omarchy update"
  })

  // The indicators inside omarchy.indicators are a different case: each one
  // already has a tooltip of its own, and two of them are live (Reminder counts
  // down, Dictation reports its state). So these are appended to whatever the
  // indicator is saying rather than replacing it, and a shortcut can differ by
  // state — pressing Reminder shows the list when one is pending and opens the
  // set-reminder flow when none is. A plain string means "same either way".
  readonly property var indicatorShortcuts: ({
    "Dnd":             "SUPER + CTRL + ,",
    "NightLight":      "SUPER + CTRL + N",
    "StayAwake":       "SUPER + CTRL + I",
    "ScreenRecording": "ALT + PRINT",
    "Dictation":       "SUPER + CTRL + X",
    "Reminder":        { "active": "SUPER + CTRL + ALT + R", "inactive": "SUPER + CTRL + R" }
  })

  function suffixFor(spec, active) {
    if (!spec) return ""
    if (typeof spec === "string") return spec
    return String((active ? spec.active : spec.inactive) || "")
  }

  // `registeredBar` is unique to Ui/WidgetButton — the base every bar button
  // extends, icon (BarIconButton) or text label (the clock). It is what
  // separates the button sitting in the bar from the ordinary Ui/Button and
  // Ui/PanelActionButton instances inside a widget's popup, which extend Item
  // directly and carry their own unrelated tooltipText.
  function isBarButton(item) {
    return !!item && ("registeredBar" in item) && ("tooltipText" in item)
  }

  function isIndicator(item) {
    return isBarButton(item) && ("activeTooltipText" in item) && ("effectiveActive" in item)
  }

  // The widget's own bar button: first match wins, and we stop descending
  // there rather than walking the whole popup tree behind it.
  function barButtonIn(item, depth) {
    if (!item || depth > 4) return null
    if (isBarButton(item)) return item

    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) {
      var hit = barButtonIn(kids[i], depth + 1)
      if (hit) return hit
    }
    return null
  }

  // Indicators sit deep inside omarchy.indicators (Row > area > block > Loader
  // > Row > IndicatorLoader > Loader > BarIndicator) and are mounted more than
  // once — an active block and an inactive one, in both bar orientations. So
  // collect all of them; labelling is idempotent.
  function collectIndicators(item, depth, out) {
    if (!item || depth > 12) return
    if (isIndicator(item)) {
      out.push(item)
      return
    }

    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) collectIndicators(kids[i], depth + 1, out)
  }

  // Rebind rather than assign, so the indicator's own live text keeps updating
  // and the shortcut rides along underneath it. Reading activeTooltipText and
  // inactiveTooltipText (never tooltipText) is what keeps this idempotent.
  function labelIndicator(button, spec) {
    button.tooltipText = Qt.binding(function() {
      var base = button.effectiveActive ? button.activeTooltipText : button.inactiveTooltipText
      var suffix = root.suffixFor(spec, button.effectiveActive)
      if (!suffix) return base
      return base ? base + "\n" + suffix : suffix
    })
  }

  // Returns the number of labels still waiting on a widget to finish loading.
  function apply() {
    if (!bar || !bar.moduleSlots) return -1

    var seen = {}
    var slots = bar.moduleSlots

    for (var i = 0; i < slots.length; i++) {
      var slot = slots[i]
      if (!slot || !slot.activeItem) continue

      var label = labels[slot.moduleName]
      if (label) {
        var button = barButtonIn(slot.activeItem, 0)
        if (button) {
          button.tooltipText = label
          seen[slot.moduleName] = true
        }
      }

      if (slot.moduleName !== "omarchy.indicators" && slot.moduleName !== "mihb.indicators") continue

      var found = []
      collectIndicators(slot.activeItem, 0, found)

      for (var j = 0; j < found.length; j++) {
        var indicator = found[j]
        var spec = indicatorShortcuts[indicator.moduleName]
        if (!spec) continue

        labelIndicator(indicator, spec)
        seen[indicator.moduleName] = true
      }
    }

    var pending = 0
    for (var id in labels) if (!seen[id]) pending++
    for (var indicatorId in indicatorShortcuts) if (!seen[indicatorId]) pending++
    return pending
  }

  // Slots register themselves before their Loader has produced an item, so the
  // first pass usually finds nothing to label. Retry briefly, then give up
  // rather than poll the bar forever.
  Timer {
    id: settle
    interval: 250
    repeat: true
    property int tries: 0
    onTriggered: {
      tries++
      var pending = root.apply()
      if (pending === 0 || tries >= 20) stop()
    }
  }

  function rescan() {
    settle.tries = 0
    settle.restart()
    Qt.callLater(root.apply)
  }

  Component.onCompleted: rescan()
  onBarChanged: rescan()

  // A bar reconfiguration (drag-to-reorder, a shell.json edit, enabling a
  // widget) rebuilds the slots, so the labels have to go on again.
  Connections {
    target: root.bar
    ignoreUnknownSignals: true
    function onModuleSlotsChanged() { root.rescan() }
  }
}
