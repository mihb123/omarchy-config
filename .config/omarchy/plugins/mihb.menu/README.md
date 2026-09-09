# mihb.menu — the Omarchy menu, made fast to open

A clone of the built-in `omarchy.menu` (`omarchy plugin clone omarchy.menu`)
with three performance changes to `Menu.qml`. Everything else is upstream.

Cloning was necessary because `/usr/share/omarchy/` is owned by the package
and gets overwritten by `omarchy update`. The shell routes calls addressed to
`omarchy.menu` here automatically via `manifest.json`'s `omarchy.clonedFrom`,
so every existing caller keeps working unchanged.

## Why

`SUPER + K` (the keybindings menu, 231 rows) took ~460ms to appear. Measured
with `omarchy-keybindings-profile --compare`; the QML side was measured with
`OMARCHY_MENU_PERF=1` (see below).

| | before | after |
|---|---|---|
| `open()` inside the shell | 134 ms | 6–17 ms |
| `dmenuRowListHeight()` calls per open | 234 | 3 |
| time spent in height passes | 111 ms | 3–6 ms |
| key press → menu on screen | 460 ms | 136 ms |

## The three changes

### 1. Suspend the rows-height computation while the model is being filled

The cause of nearly all of it. `visibleRowsHeight` binds to
`displayModel.count`, and both `rowListHeight()` and `dmenuRowListHeight()`
walk *every* row in the model. Filling the model one row at a time re-ran a
height pass per row, so a 231-row menu did 234 passes over ~27k rows — an
O(rows²) open.

`suspendRowsHeight` makes those functions return the previously computed
value, so the intermediate evaluations are O(1); clearing it at the end of a
rebuild triggers exactly one real pass. The flag is set and cleared in a
`try/finally` wrapper (`rebuildDisplay` → `rebuildDisplayRows`) so no early
return or throw can leave the card frozen at a stale height.

The cached value lives in a plain JS object (`rowsHeightCache`), not a QML
property: writing a property from inside the binding would make it a
dependency of `visibleRowsHeight` and produce a binding loop.

### 2. One `displayModel.append(array)` instead of a per-row append

Smaller, and mostly redundant once (1) is in place — `ListModel` still emits a
count change per row even for a batched append — but it keeps the row building
and the model write separate, which is what makes (1) straightforward.

### 3. A Unix socket to open the menu without spawning `qs`

`omarchy-shell shell summon omarchy.menu <payload>` has to start the `qs`
client, and that Qt process costs ~90ms of dynamic linking before it moves a
byte — more than everything else on the path put together.

A `SocketServer` at `$XDG_RUNTIME_DIR/omarchy-menu-open.sock` takes one line
of JSON per connection: exactly the payload `shell.summon()` takes, routed
through `shell.summon()` so the host's open-panel bookkeeping is identical on
both paths. `socat` delivers it in ~2ms. The socket sits in `XDG_RUNTIME_DIR`
(mode 0700) — the same trust boundary the `qs` ipc socket already has.

`~/.local/bin/omarchy-menu-keybindings-fast` uses it and falls back to `qs ipc`
whenever the socket is not there.

## Profiling

The perf instrumentation is permanent but off unless the shell's environment
has `OMARCHY_MENU_PERF=1`:

```bash
while timeout 5 quickshell kill -p /usr/share/omarchy/shell --any-display; do :; done
hyprctl dispatch 'hl.dsp.exec_cmd("env OMARCHY_MENU_PERF=1 omarchy-launch-shell")'
# open the menu, then:
qs log -t 40 "$(ls -t /run/user/$UID/quickshell/by-id/*/log.qslog | head -1)" | grep menu-perf
```

Each open prints one line with a timestamp per phase plus `heightCalls` and
`heightMs`. `omarchy restart shell` puts it back to normal.

End-to-end timings: `omarchy-keybindings-profile --compare` (or `--trace`).

## Re-applying after an `omarchy update`

`.upstream/Menu.qml.baseline` is the upstream file this clone forked from and
`.upstream/menu-perf.patch` is the diff. When upstream changes:

```bash
diff -q /usr/share/omarchy/shell/plugins/menu/Menu.qml \
        ~/.config/omarchy/plugins/mihb.menu/.upstream/Menu.qml.baseline   # changed?

cd ~/.config/omarchy/plugins/mihb.menu
cp /usr/share/omarchy/shell/plugins/menu/Menu.qml Menu.qml
patch -p0 < .upstream/menu-perf.patch          # resolve any rejects by hand
cp Menu.qml .upstream/Menu.qml.baseline        # re-baseline
diff -u .upstream/Menu.qml.baseline Menu.qml > .upstream/menu-perf.patch
omarchy restart shell
```

Also copy `BarWidget.qml` and `MenuModel.js` across — they are unmodified.

If any of this becomes more trouble than it is worth, drop the whole thing:

```bash
omarchy plugin remove mihb.menu
# then in ~/.config/omarchy/shell.json remove "omarchy.menu" from disabledPlugins
# and the {"id": "mihb.menu"} entry from plugins[]
```

`~/.config/hypr/bindings.lua` can go back to stock by deleting the two
`SUPER + K` lines at the bottom.

## Note on `shell.json`

This plugin is enabled by a `{"id": "mihb.menu"}` entry in the top-level
`plugins[]` array. That entry matters: a third-party plugin counts as enabled
only while shell.json references it somewhere, and putting it in `plugins[]`
rather than relying on the bar-widget entry means rearranging the bar cannot
silently disable the menu. It was disabled exactly that way once already.
