# Test parity — audit pass 3

| | |
|---|---|
| Upstream | `master` @ `63527674` |
| Port | `ruby` @ `f324a75d` |
| Upstream tests | 0 (re-verified: `git ls-tree -r --name-only origin/master \| grep -iE 'test'` → no results; no `tests/`, no `meson.build` `test(...)`) |
| Ported | 0 |
| Gaps against upstream's own suite | 0 (vacuous — upstream ships none) |

Unchanged from pass 2: upstream GNOME Music has no automated test suite, so
test parity *against upstream* is trivially satisfied. This says nothing
about whether the port's own verification works, which is the rest of this
document and the part that actually matters.

## The port's own suites, all re-run fresh this pass, not cited from a prior log

| Suite | Command | Result this pass |
|---|---|---|
| `spec/` (RSpec) | `xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'` | **51 examples, 0 failures** |
| `test/drive_smoke.rb` | `xvfb-run -a ruby test/drive_smoke.rb` | **SMOKE OK**, 14/14 named checks |
| `test/drive_artwork.rb` | `xvfb-run -a ruby test/drive_artwork.rb` | **ARTWORK OK**, 8/8 named checks |
| `test/drive_music.rb` | `xvfb-run -a ruby test/drive_music.rb` | **DRIVE OK**, 74/74 checks |

Note on running RSpec: the dev shell's own printed command (`ruby -e
'require "rspec/core"; ...'`, no `xvfb-run`) fails in this sandbox with
`Gtk::InitError: failed to initialize GTK` — `spec/core_song_spec.rb`
transitively loads `lib/core_song.rb` → `require 'adwaita'`, which needs a
display. Wrapping the same command in `xvfb-run -a` (consistent with how
every other suite in this project is run) fixes it and the suite passes
clean. This is an environment-shaping note, not a port defect — recorded
here so the next pass does not waste a cycle rediscovering it.

## Headline change from pass 2: the previously non-reproducing gate now reproduces

Pass 2's single most serious finding was that `drive_music.rb` failed via a
90-second watchdog timeout on two independent re-runs, directly
contradicting the `drive_ok=true` gate it had been handed. Commit
`f324a75d` (after pass 2) fixed the actual bug (`PlaylistToast`'s dismiss
path was hand-emitting a signal instead of calling `#dismiss`, which left
libadwaita's own toast-overlay bookkeeping out of step and segfaulted
during cleanup) and widened the watchdog from 90s to 600s to tolerate slow
Xvfb software-rendered animation under load. This pass re-ran
`drive_music.rb` fresh, once, start to finish:

```
[21] the playlist toast actually undoes the delete it offers
    ok   staging the deletion removed it from the model
    ok   the undo button brings the playlist back
    ok   dismissing without undo commits the delete

74 of 74 checks passed
DRIVE OK
[exit 0]
```

This is a genuine, confirmed fix, not a re-quoted number: the exact failure
pass 2 reproduced twice (hang after the toast-dismissal step, watchdog
firing, `DRIVE FAILED`) is gone, and the step that used to precede the hang
(`dismissing without undo commits the delete`) now completes and the run
finishes clean. **Treat this round's `drive_ok=true, 74 checks, 0 failed`
gate as confirmed**, unlike pass 2's identical-looking number, which this
audit could not reproduce.

## Where the suite still does not reach — unchanged from pass 2, this is not a regression report, it is a standing gap

- **Actually playing audio.** `.reports/drive-test-crash.md` (pass 1)
  documents `Player#play` segfaulting; re-checked this pass:
  `grep -n "\.play\b" test/drive_*.rb` still finds no call to `Player#play`,
  `win.playlist_play`, `app.play_pause`, or a song-row activation in any of
  the three drive scripts. 74+14+8 = 96 checks, zero of which play a sound.
- **A real startup path.** All three drive scripts seed `CoreModel`
  directly or construct widgets standalone; none of them calls
  `App#do_activate` with no fixture and lets the real (absent) Tracker data
  source run. So "66 components covered" (the inventory's figure) or "22
  components" (this round's stated gate) cannot include "the collection
  loads for real" no matter how the count is read — there is no such
  component yet to cover. See `.reports/parity-component-parity.md` for why
  this is the single most consequential untested path in the app.
- **MPRIS.** `grep -ril mpris test/` → no results, because there is nothing
  to call (see identification report).
- **CoreGrilo's actual resolve call.** The drive suite never calls
  `CoreGrilo#resolve_album_cover` directly or indirectly — `grep -rn
  "resolve_album_cover\|CoreGrilo" test/` → no results — so no test in the
  suite would ever catch that it unconditionally raises and is swallowed.
  This is exactly the kind of gap "a component no check exercises is
  unverified, not done" is warning against: `CoreGrilo` is in the "73
  files" count and in the inventory's "present" column, and no test touches
  the one method it exists to provide.

## Verdict

Upstream test parity: 0/0, trivially met, unchanged. The port's own
verification: **all four runnable suites pass clean on fresh re-run this
pass**, including `drive_music.rb`, whose prior-pass failure is confirmed
fixed rather than merely asserted fixed. This is real, verified progress
since pass 2. It does not, however, mean the suite's coverage is complete:
real playback, real library loading, MPRIS, and `CoreGrilo`'s one real
method are all outside what any passing check in this repo currently
exercises.
