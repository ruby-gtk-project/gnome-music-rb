# Test parity — audit pass 2

| | |
|---|---|
| Upstream | `master` @ `63527674` |
| Port | `ruby` @ `1dc12993` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

## Upstream census: still zero

Re-verified this pass:

```
git ls-tree -r --name-only origin/master | grep -iE 'test'   → no results
git show origin/master:meson.build | grep -i test            → no results
```

No `tests/` directory, no `*_test.py`, no `conftest.py`, no `meson.build`
`test(...)`. Upstream GNOME Music ships no automated test suite. Test
parity against upstream's (empty) suite is vacuously satisfied, same as
the last pass. This says nothing about the port's own verification.

## The port's own verification, re-run fresh this pass

```
spec/   → core_song_spec.rb, queue_spec.rb, utils_spec.rb, spec_helper.rb   (51 examples)
test/   → drive_smoke.rb, drive_artwork.rb, drive_music.rb, gtk_driver.rb
```

All four runnable suites were executed directly in this session, under the
dev shell's own printed commands, not read off a prior log:

| Suite | Command | Result this pass |
|---|---|---|
| `spec/` (RSpec) | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` | **51 examples, 0 failures** |
| `test/drive_smoke.rb` | `xvfb-run -a ruby test/drive_smoke.rb` | **SMOKE OK**, all 9 named checks pass |
| `test/drive_artwork.rb` | `xvfb-run -a ruby test/drive_artwork.rb` | **ARTWORK OK**, all 5 named checks pass |
| `test/drive_music.rb` | `xvfb-run -a ruby test/drive_music.rb` | **FAILED on both of two independent runs** — see below |

## `test/drive_music.rb` does not pass cleanly on re-run — this is the headline finding of this pass

The task handed this audit a runtime gate of `drive_ok=true, 110 checks
passed, 0 failed, 66 components`. `18 (smoke) + 18 (artwork) + 74 (music) =
110`, so `drive_music.rb` is almost all of that gate's weight. Re-running it
twice, independently, in this session:

```
Run 1:
    ok   dismissing without undo commits the delete
TIMEOUT after 90s - the app never finished its steps

74 of 74 checks passed
  errored step: watchdog timeout
DRIVE FAILED (1)

Run 2 (started separately, several minutes later):
    ok   dismissing without undo commits the delete
TIMEOUT after 90s - the app never finished its steps

74 of 74 checks passed
  errored step: watchdog timeout
DRIVE FAILED (1)
```

Both runs: every individual assertion inside a named step passes (`74 of
74`), and the *process itself* then hangs for 90 seconds after the last step
and is killed by the driver's own watchdog, which marks the whole run
**FAILED**, exit code 1. `DRIVE OK` was never printed by this audit's runs.
This is a drive run that does not pass, by the suite's own pass/fail
contract (`test/gtk_driver.rb`'s `report` method: any non-empty
`@errored_steps` makes the exit code 1 and the printed verdict
`DRIVE FAILED`), run against the exact commit (`1dc12993`) this task
describes as `drive_ok=true`.

Per this skill's own framing — "is every component exercised, and does the
suite that claims so actually run" — the answer this pass found is **no**,
the suite that was supposed to have run clean does not, when actually run.
A gate number quoted from a prior run is not evidence about this commit; it
is evidence about whatever commit and environment produced that prior run.
This audit re-ran it fresh, per the task's own instruction to treat a failed
or narrow drive run as a gap in its own right, and the fresh run failed
twice in a row.

(`drive_smoke.rb` and `drive_artwork.rb` were also re-run fresh and both
passed clean with no hang, so this is not a claim that nothing in the repo
runs — it is specifically `drive_music.rb`, and specifically something that
starts going wrong around its volume-button step, per the recurring
`GStreamer-Play-CRITICAL: gst_play_set_mute/set_volume: assertion
'GST_IS_PLAY (self)' failed` lines that appear in run 2's stderr after step
[19] and roughly every 10 seconds thereafter until the watchdog fires.)

## Where the suite does not reach, even when it does pass its own steps

Unchanged from the prior pass, re-confirmed:

- **Actually playing audio.** `.reports/drive-test-crash.md` documents
  `Player#play` segfaulting the process; all three drive scripts avoid any
  call path that reaches it. Re-confirmed: `grep -n "\.play\b" test/drive_*.rb`
  finds no call to `Player#play`, `win.playlist_play`, `app.play_pause` or a
  song-row activation anywhere in any of the three scripts.
- **CoreGrilo/TrackerWrapper/LocalSearchWrapper/MPRIS.** Still absent from
  `lib/`, so there is nothing for any test to drive. The 74 "music" checks
  load their song/album/artist fixtures by writing directly into
  `application.coremodel`'s arrays (`test/drive_music.rb:114-116` and
  surrounding setup), never through a Grilo/Tracker path — the drive suite
  cannot exercise a library-loading component that does not exist, so "66
  components covered" cannot include a real library scan, no matter how the
  number is read.
- **MPRIS.** Zero mention in any test file (`grep -ril mpris test/` returns
  nothing), because there is nothing to call.

## Verdict

Upstream test parity: **0/0, trivially met, no inherited safety net** —
unchanged from the prior pass. The port's own verification: **not clean**.
51 RSpec examples pass. `drive_smoke.rb` and `drive_artwork.rb` pass. The
one script carrying two-thirds of the stated runtime gate,
`drive_music.rb`, failed via watchdog timeout on both attempts to re-run it
in this audit, directly contradicting the `drive_ok=true` / `0 failed`
figures this task was handed. Treat the round's runtime gate as unverified
for `drive_music.rb` until it is re-run clean and that result is itself
reproduced, not merely quoted.
