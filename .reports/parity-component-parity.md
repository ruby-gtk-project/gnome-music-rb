# Component parity — gnome-music-rb vs upstream `origin/master`

Adversarial pass over `.reports/component-inventory.md`'s claims, checked
against the live `lib/` tree and the drive suite's actual coverage, not
against what the inventory says should be true.

## Headline: 7 of 25 supporting (non-widget) modules are still missing

The inventory document's own table says 8 supporting modules are missing.
One of those eight (`lib/disc_list_item.rb`) has since landed
(`b58be690`), re-verified present in this audit. The other **seven are
still missing**, verified directly against `lib/` in this audit:

| Upstream | Port file | Present? |
|---|---|---|
| `gnomemusic/coregrilo.py` | `lib/core_grilo.rb` | **MISSING** |
| `gnomemusic/grilowrappers/localsearchwrapper.py` | `lib/local_search_wrapper.rb` | **MISSING** |
| `gnomemusic/trackerwrapper.py` | `lib/tracker_wrapper.rb` | **MISSING** |
| `gnomemusic/mpris.py` | `lib/mpris.rb` | **MISSING** |
| `gnomemusic/storeart.py` | `lib/store_art.rb` | **MISSING** |
| `gnomemusic/embeddedart.py` | `lib/embedded_art.rb` | **MISSING** |
| `gnomemusic/pauseonsuspend.py` | `lib/pause_on_suspend.rb` | **MISSING** |

These are not cosmetic. Concretely, their absence means:

- **No real music library.** `core_grilo.py` / `trackerwrapper.py` /
  `localsearchwrapper.py` are how upstream actually queries Tracker (SPARQL)
  for the user's music. Without them, the port has no path from "files on
  disk" to `CoreSong`/`CoreAlbum`/`CoreArtist` — whatever the drive suite
  exercises is necessarily backed by fixture/stub data, not a real library
  scan. This is the single most central job of a music player and it is
  unbuilt.
- **No desktop integration.** `mpris.py` is GNOME Music's MPRIS2 server —
  the thing that lets the GNOME Shell media widget, lock screen controls,
  Bluetooth headset buttons, and every other MPRIS client control playback.
  None of that exists in the port. A user who pauses from their headset or
  checks "what's playing" from the shell gets nothing.
- **No remote or embedded cover art.** `storeart.py` and `embeddedart.py`
  are two of the three art sources upstream tries (the component inventory
  already flags these as blocked on absent GStreamer/Grilo bindings, not
  newly found here, but they are still gaps, not "out of scope").
- **No suspend-pause.** `pauseonsuspend.py` pauses playback when the system
  suspends. Not present.

`application.py`'s MPRIS registration call (`do_activate` registers MPRIS,
per the inventory's own description of `lib/main.rb`) has nothing to
register against, since `lib/mpris.rb` does not exist — meaning either
`lib/main.rb`'s port of that call is itself incomplete, or it silently does
nothing. Either way it is a gap on the `main.rb`/`App` component that the
inventory marked **present** without qualification.

## Behaviour axis: playback itself is unverified, and documented as crash-prone

`.reports/drive-test-crash.md` (already in the tree, re-verified in this
audit) documents that calling `Player#play` with a song whose GStreamer
source fails to set up **segfaults the whole Ruby process**, not raises a
catchable exception. The three drive scripts (`drive_smoke.rb`,
`drive_artwork.rb`, `drive_music.rb`) all **deliberately avoid** any code
path that reaches `Player#play` — confirmed by re-running
`test/drive_music.rb` under `nix develop --command xvfb-run -a ruby` in
this audit: it reports `49 of 49 checks passed` / `DRIVE OK`, and the
queueing check (`[13] queueing an album reveals the player toolbar`) stops
at "the player toolbar is revealed" — it never calls play.

Per component-parity's behaviour axis ("responds to exactly the same
signals and fires the same actions... not 'has a handler'"), `lib/player.rb`
and `lib/gst_player.rb` fail this axis outright: upstream's player plays
audio; this port's player, driven the same way a user would drive it
(open the app, pick a song, press play), crashes the process. That the
crash sits in a binding gap rather than in this port's own Ruby is true and
is honestly written up — but it does not change the user-facing fact: the
core feature does not work, and no check in the 49-check gate exercises
it, so "49 of 49 checks passed" cannot be read as "playback is fine."

## Secondary finding: a screenshot check fails inside a passing run

The same `drive_music.rb` run that reports `49 of 49 checks passed` also
prints, inline:

```
shot 07-search-no-results failed: RuntimeError: widget produced no render node (not realised yet?)
```

This failure is not counted against the 49/49 (it is a screenshot capture,
not one of the enumerated `ok` checks), so the gate is blind to it. It is
raised here because it is exactly the shape of thing the task's framing
warns about: a narrow definition of "check" lets a real runtime error ride
inside a run that reports fully green.

## What the inventory got right

Everything else the inventory marks **present** for widgets, dialogs, pages,
menus and the player toolbar's visible controls was spot-checked in this
audit against `lib/` and matches: `lib/disc_list_item.rb` now exists,
`lib/shortcuts_dialog.rb`, `lib/preferences_dialog.rb`,
`lib/status_navigation_page.rb` and the album/artist/playlist/search view
chain are all present and were exercised live by the drive run above
(album page, artist page, playlist create/rename/delete, search, three
dialogs, header bar menu, player toolbar mute/repeat/shuffle). That
coverage is real and this audit does not dispute it.

## Verdict

Component parity is **not met**. Seven supporting modules — covering the
actual music-library backend, desktop media integration, two of three
cover-art sources, and suspend handling — are absent, and the one
component whose entire job is "play the song" is both unverified by any
check and independently documented to crash the process when exercised.
