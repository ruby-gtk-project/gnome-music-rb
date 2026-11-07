# Drive-testing gate — this run

Per the `ruby-gtk-testing` skill: proving the port runs, not just parses.

## What ran

- `test/drive_smoke.rb` — `nix develop --command xvfb-run -a ruby test/drive_smoke.rb` → `SMOKE OK` (18/18).
- `test/drive_artwork.rb` — same invocation → `ARTWORK OK` (18/18, two expected `Gio::IOError::NotFound` /
  `PixbufError::UnknownType` warnings are the fixtures the checks deliberately feed it).
- `test/drive_music.rb` (GtkDriver-shaped, extended this pass) →
  `74 of 74 checks passed` / `DRIVE OK`.
- `spec/` (`rspec --require spec_helper spec`) → `51 examples, 0 failures`.

## A real bug found and fixed, not a check loosened

`test/drive_music.rb`'s new status-page checks (step 15) failed on first
write: `EMPTY shows the welcome clamp, not AdwStatusPage's own icon/title`.
The screenshot it took (`tmp/shots/00-empty-state.png`, captured by the
unmodified step 0 at the very start of this same run) showed why — the
window's content area was **entirely blank** under the header bar. No
welcome picture, no "Welcome to Music", nothing.

Cause, confirmed against `origin/master:gnomemusic/widgets/statusnavigationpage.py`:
upstream keeps `AdwStatusPage` itself permanently visible and toggles
visibility *inside* it — between its own built-in icon/title/description
clamp (reached by walking its internal widget tree, upstream's own
"Hack to get to AdwClamp" comment) and a custom welcome clamp installed as
its `child` property. The port instead toggled `status_page.visible`
itself off for the EMPTY state while leaving the welcome clamp nested
*inside* that now-hidden status page — so hiding the parent hid the
welcome content too, with nothing left visible at all. Confirmed in
isolation (`gtk_widget_is_visible` on a child widget does reflect its
ancestors' visibility in this GTK4, even though the raw `visible` property
on the child itself stays `true`), then confirmed as the exact shape of
upstream's own widget tree by reading `data/ui/StatusNavigationPage.ui`.

Fix: `lib/status_navigation_page.rb` now ports upstream's real structure —
`adw_clamp` (status_page's own built-in content, found by walking
`first_child` four times, exactly as upstream's `__init__` does) and
`initial_state` (the welcome clamp) are toggled against each other, and
`status_page.visible` is never touched. Re-screenshotted after the fix
(`tmp/shots/00-empty-state.png`, `tmp/shots/14-status-no-tracker.png`):
both now render their actual content.

## Coverage added this pass

`test/drive_music.rb` already covered 49 checks across the window, every
view/page/dialog, the player toolbar and playlist CRUD. This pass added 25
more checks (steps 14–21) for components that existed in `lib/` but were
never driven by any test: the full 7-playlist `SmartPlaylist` catalogue
(selection and ordering), all four `StatusNavigationPage` states (not just
EMPTY, found the bug above), `NotificationManager`'s loading-indicator
push/pop and `#loading` block, `WindowPlacement`'s restore-on-build and its
debounced resize-to-settings write, `VolumeButton`'s scale/adjustment,
`TwoLineTip`, and `PlaylistToast`'s actual undo *and* actual commit-on-dismiss
paths (the pre-existing step only checked that a toast appeared, not that
either button did the right thing).

## Still not exercised, and why

- `lib/core_grilo.rb`, `lib/local_search_wrapper.rb`,
  `lib/tracker_wrapper.rb`, `lib/mpris.rb` do not exist in this port yet
  (confirmed absent from `lib/` in this pass) — nothing to drive.
- Actually playing audio (`Player#play` reaching a real `Gtk::MediaFile`
  source) is not driven, and should not be: `.reports/drive-test-crash.md`
  (pre-existing, re-confirmed not re-tested further in this pass since
  nothing about it changed) documents that it segfaults the whole process
  on a `glib2`/`Gtk::MediaFile` threading hazard, not a port defect — no
  rescue in this codebase can run before that crash happens.
