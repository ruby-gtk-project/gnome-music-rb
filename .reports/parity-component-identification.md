# Component identification — audit pass 3

| | |
|---|---|
| Upstream | `master` @ `63527674` (unchanged since pass 2) |
| Port | `ruby` @ `f324a75d` |
| Since last pass | `283a6c33`, `0c0021e7`, `d3e2336a`, `9edd6a52`, `f324a75d` |

This pass re-derives the component list directly against `origin/master`
rather than trusting `.reports/component-inventory.md` (written in commit
`9edd6a52`, at HEAD `d3e2336a`) at face value, because that document is
itself an input this audit needs to check, not a substitute for checking.
Re-running its own method:

```
git ls-tree -r --name-only origin/master | grep '^data/ui/.*\.ui$' | wc -l   → 33
git ls-tree -r --name-only origin/master | grep '^gnomemusic/.*\.py$' | wc -l → 68
ls lib/*.rb | wc -l                                                           → 71
```

Counts match the inventory document's figures. No `.ui` file or Python
module under `gnomemusic/` was added, removed or renamed on `origin/master`
since the inventory was written, so its per-component table is re-affirmed
rather than re-copied here in full.

## Confirmed present, re-checked this pass

Every window, dialog, page, menu item, accelerator and empty/error state the
inventory lists as present was spot-checked again directly against upstream
source this pass (not re-read from the inventory doc):

- **Actions/accelerators**: `gnomemusic/application.py`'s 13 `app.*` actions
  all have a matching `add_action`/accelerator in `lib/main.rb`.
- **Dialogs**: about, preferences, shortcuts, playlist, playlist-dialog-row
  all present with matching rows/sections against their `.ui` files.
- **Empty/error states**: `data/ui/StatusView.ui`'s four states
  (`EMPTY`, `NO_MUSIC_FOUND`, `NO_TRACKER`, `TRACKER_OUTDATED`) all exist in
  `lib/status_navigation_page.rb` and are exercised by
  `test/drive_smoke.rb`'s status checks (re-run clean this pass, see
  `.reports/parity-test-parity.md`).
- `DiscListItem`, the one user-facing gap the prior pass's inventory named,
  is present at `lib/disc_list_item.rb`.

**47/47 user-facing components present**, matching the inventory's count.

## Supporting (non-widget) modules — re-confirmed gaps, one re-classified

The inventory's "22 present / 3 missing (MPRIS, session-Tracker collection
browsing)" needs a correction: **it undercounts how functional the
present-but-crippled modules are.** Two of the "present" 22 do not do the
thing their presence implies, once read past their constructor:

- **`CoreGrilo`** (`lib/core_grilo.rb`) is present as a file and is required
  on a live path (via `album_art.rb`), and its registry setup genuinely
  loads real Grilo plugins. But `Grl::Source#resolve` — the one call that
  actually fetches a thumbnail — unconditionally raises
  `NotImplementedError` through this gem's GList-marshalling gap, is
  rescued, and logged (`lib/core_grilo.rb:69-70`). **Every call to
  `#resolve_album_cover` resolves zero covers.** This is not "present with a
  known limitation on some inputs"; it is present and non-functional for
  its one job, for all inputs, unconditionally, confirmed by reading the
  `rescue` clause, not by running it (see `.reports/parity-accountability.md`
  for why this matters for how the commit introducing it was described).
- **`StoreArt`** (`lib/store_art.rb`) is present as a file, has its own
  passing tests when driven standalone, and is never `require_relative`d
  from any file reachable from `lib/main.rb` (confirmed:
  `grep -rn "require_relative 'store_art'" lib/` → no hits anywhere outside
  its own spec). A component that nothing in the running app loads is not a
  present component for a user; it is dead code with tests.

Still missing outright, unchanged from the inventory:

- **MPRIS** (`gnomemusic/mpris.py`) — zero file under `lib/`, zero mention
  of "mpris" anywhere in `lib/` (`grep -ril mpris lib/` → empty). Desktop
  media-key integration, `playerctl`/GNOME Shell's media controls, and
  Shell's "now playing" surface all have nothing to talk to.
- **Session-Tracker collection browsing**
  (`gnomemusic/trackerwrapper.py`/`localsearchwrapper.py`'s browsing half)
  — blocked on the same kind of gem-binding gap as `CoreGrilo#resolve`
  (`Tracker.SparqlConnection.bus_new` has no usable binding, per
  `lib/tracker_store.rb:15` and `lib/core_grilo.rb:19-21`). **This is the
  component that fills `CoreModel`'s collection from the user's actual music
  library.** Its absence means the window this port launches shows the
  empty-collection welcome state unconditionally — not as one state among
  several a real user reaches sometimes, but as the only state a real user
  ever reaches, because nothing else ever calls `CoreModel#load` with real
  tags outside of a test harness that injects them directly.

## Corrected component count

| Status | Count |
|---|---:|
| User-facing components present and functional | 47 |
| Supporting modules present and functional | 20 |
| Supporting modules present as files but non-functional on their one job (`CoreGrilo#resolve`, `StoreArt` unwired) | 2 |
| Supporting modules missing outright (`MPRIS`, collection-browsing) | 2 |
| Compound effect | **The app has no real music library in normal use, and no working remote cover art, regardless of the 47/47 widget count.** |

The 47/47 widget figure is accurate and is not where this pass's finding is.
The finding is that "component present" and "component does its job" have
drifted apart for two supporting modules in a way the inventory's framing
(a flat present/missing table) does not surface, and that matters far more
for a music player than any individual dialog: a library browser with every
page built and no data to show in any of them is not a near-complete port.
