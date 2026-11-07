# Component parity — audit pass 2

| | |
|---|---|
| Upstream | `master` @ `63527674` (see `parity-component-identification.md` — `origin/main` does not exist in this repo) |
| Port | `ruby` @ `1dc12993` |

This supersedes the prior pass's `.reports/parity-component-parity.md`
content (kept below it is not; this file is overwritten, and the prior
findings are re-verified here rather than re-stated on trust).

## Headline: 4 of 7 previously-missing supporting modules are still missing; the ones that landed did not all land working

Re-verified directly against `lib/`:

| Upstream | Port file | Present? | Wired into the running app? |
|---|---|---|---|
| `gnomemusic/coregrilo.py` | `lib/core_grilo.rb` | **MISSING** | n/a |
| `gnomemusic/grilowrappers/localsearchwrapper.py` | `lib/local_search_wrapper.rb` | **MISSING** | n/a |
| `gnomemusic/trackerwrapper.py` | `lib/tracker_wrapper.rb` | **MISSING** | n/a |
| `gnomemusic/mpris.py` | `lib/mpris.rb` | **MISSING** | n/a |
| `gnomemusic/storeart.py` | `lib/store_art.rb` | present | **NO** — never required from `lib/main.rb` or anywhere else; the file's own header explains why (loading `soup3` crashes the app later). A file that exists but is never loaded is not a built component |
| `gnomemusic/embeddedart.py` | `lib/embedded_art.rb` | present | yes — required from `album_art.rb` and `song_art.rb` |
| `gnomemusic/pauseonsuspend.py` | `lib/pause_on_suspend.rb` | present | yes — required from `main.rb`, instantiated in `window.rb` |

So the real count of "features that work end to end" moved from 0/7 to
**2/7** this pass (`embedded_art`, `pause_on_suspend`), not 3/7 — `store_art`
landing as inert source is not a parity gain for the cover-art component.

## No real music library — still true, confirmed again this pass

`core_grilo.py`/`trackerwrapper.py`/`localsearchwrapper.py` are how upstream
turns "files on disk, indexed by Tracker" into `CoreSong`/`CoreAlbum`/
`CoreArtist` objects. None of the three exists in the port. Confirmed by
running the drive suite with `grep`: `test/drive_music.rb` populates
`application.coremodel` by calling private/direct mutators
(`coremodel.songs`, `.albums`, `.artists` — fixture arrays assembled in the
test itself), never through any Grilo/Tracker path, because there is no such
path to call. Every "songs loaded" / "albums loaded" check in the 110-check
gate is checking test-authored fixture data, not a working library scanner.
This is not a new finding — the prior pass found it — but it is unchanged
and still the single largest functional gap in the app: **a user who runs
this port sees an empty collection and the welcome page forever**, which
`lib/main.rb`'s own comment confirms: "Until the data source lands the
collection is empty, which is the state upstream shows the welcome page
for."

## No MPRIS — still true, confirmed again this pass

```
$ grep -ril mpris lib/ exe/
(no output)
```

`gnomemusic/application.py` imports `from gnomemusic.mpris import MPRIS` and
constructs it unconditionally in `Application.__init__`/`do_startup`. The
port's `lib/main.rb` has no equivalent call and no `Mpris` class exists
anywhere in `lib/`. Concretely: a user of this port cannot control playback
from the GNOME Shell media widget, the lock screen, a Bluetooth headset's
play/pause button, or any other MPRIS client. This is full desktop
integration, zero of it present, same as the last pass.

## Playback itself: the gate's "110 checks, 0 failed" does not include actually playing a song, and the drive run is not clean when re-run

`lib/gst_player.rb`'s own header comment documents that `Gtk::MediaFile` (the
substitute for upstream's `playbin3`, since there are no Gst bindings for
Ruby) segfaults the process when its GStreamer source setup fails off the
main thread — `.reports/drive-test-crash.md` (pre-existing, re-verified not
re-tested further since nothing changed) names the exact backtrace. All three
drive scripts "deliberately avoid" (their own comment, `test/drive_music.rb`
trailing block) any call that reaches `Player#play`.

**New this pass: re-running `test/drive_music.rb` twice in this session, each
run reports the per-step checks as `74 of 74 checks passed` and then,
immediately after, `TIMEOUT after 90s - the app never finished its steps` /
`errored step: watchdog timeout` / `DRIVE FAILED (1)`.** This directly
contradicts the runtime gate this task was handed (`drive_ok=true`, `110
checks passed`, `0 failed`). Transcript, run 1:

```
$ nix develop --command xvfb-run -a ruby test/drive_music.rb
...
[21] the playlist toast actually undoes the delete it offers
    ok   staging the deletion removed it from the model
    ok   the undo button brings the playlist back
    ok   dismissing without undo commits the delete
TIMEOUT after 90s - the app never finished its steps

74 of 74 checks passed
  errored step: watchdog timeout
DRIVE FAILED (1)
```

Run 2, independently started a few minutes later, produced the identical
shape of failure (same last step, same watchdog message, same `DRIVE FAILED
(1)`). Along the way, run 2's stderr showed a recurring, periodic error not
present in the earlier `.reports/drive-test-run.md` transcript:

```
(ruby:NNNNNN): GStreamer-Play-CRITICAL **: gst_play_set_mute: assertion 'GST_IS_PLAY (self)' failed
(ruby:NNNNNN): GStreamer-Play-CRITICAL **: gst_play_set_volume: assertion 'GST_IS_PLAY (self)' failed
```
repeating roughly every 10 seconds after step [19] (the volume button check,
which calls `player.volume=`/`mute=` on a `GstPlayer` whose `Gtk::MediaFile`
has never had a real `file=` set). This is consistent with `Gtk::MediaFile`
retrying its internal GStreamer-backend setup on a timer and failing every
time, and it is the most plausible proximate cause of the watchdog firing:
something keeps the app busy enough, or keeps a reference alive long enough,
that the driver's own `GLib::Timeout`-scheduled "advance to the next step"
callback never gets to run `application.quit`.

This was run twice, independently, with the identical outcome both times, so
it is not reported here as a one-off flake from a loaded machine. **Whatever
produced the `drive_ok=true, 110/110` gate this task was handed did not
reproduce when this audit re-ran the same script against the same commit.**
`drive_smoke.rb` (18/18) and `drive_artwork.rb` (18/18) were also re-run in
this session and both passed cleanly with no hang — the failure is specific
to `drive_music.rb`, and specific to something that starts going wrong
around its volume-button step.

Per this skill's instruction to treat a failed or narrow drive run as a gap
in its own right: **the runtime gate for this round should be read as
`drive_ok=false` for `drive_music.rb`**, not as the `true` this task states,
until someone fixes whatever the volume-button step leaves running and
re-confirms a clean exit.

## Signals axis — scan deltas resolved by reading

The 20 "missing" signal names from the raw scan diff are almost entirely
explained, not gaps:

- `message::*`, `about-to-finish`, `clock-tick` (upstream spells it
  `clock-tick`; actually `GstClock`'s `callback`, see upstream
  `_on_clock_tick`), `source-added`/`source-removed`, `discovered`: all
  `Gst.Bus`/`playbin3`-specific signals the port's `Gtk::MediaFile`
  architecture does not use, because it is not watching a `Gst.Bus` at all.
  Correspondence, not a gap, **except** that it is also where ReplayGain and
  gapless preload live — see `lib/gst_player.rb`'s own comment, already
  covered above.
- `notify::repeat-mode`, `notify::search-state`, `notify::search-text`,
  `notify::state`, `notify::title`: these are `GObject.Property` definitions
  upstream exposes as `notify::*` for other code to watch. The port uses the
  house `Utils::Observable` mixin (plain Ruby callbacks) instead of GObject
  properties for its own internal state — a correspondence, confirmed by
  reading `lib/utils.rb`'s `Observable` module and its use across
  `core_model.rb`, `player.rb`, `queue.rb`.
- `song-activated`, `song-changed`, `queue-loaded`, `widget-moved`,
  `texture`, `events`, `art-found`: custom upstream `GObject.Signal`
  declarations on classes the port represents with plain Ruby method calls
  and the `Observable` mixin instead of real GObject signals. Same
  correspondence.
- `response` (on `Gtk.MessageDialog`/`Adw.AlertDialog`): present in the port
  too — `grep -rn "signal_connect('response'" lib/` finds it in
  `playlist_dialog.rb`; the scan missed it because of how the handler is
  wired, not because it is absent. Scan artifact.

None of the above changes the verdict on MPRIS, CoreGrilo, ReplayGain,
gapless playback or the drive-run hang — those remain real, independently
confirmed gaps regardless of how the signal-count delta reads.

## Actions axis — scan deltas resolved by reading

`app.help`, `app.preferences`, `app.quit`, `app.shortcuts` and the four
"extra" actions (`add_favorites`, `add_playlist`, `play`,
`remove_playlist`) are scan artifacts, not gaps or extras. `lib/main.rb`'s
`APP_ACTIONS` and `lib/window.rb`'s `WINDOW_ACTIONS` are frozen hashes of
`name => accelerators`, read in a loop by `Gio::SimpleAction.new(name)` — the
scan's action stream only catches a literal string at the `SimpleAction.new`
call site, exactly the failure mode the `component-identification` skill
warns about ("Actions whose name is never a literal"). Read in full,
`APP_ACTIONS` has 14 entries and `WINDOW_ACTIONS` (not reproduced here, see
`lib/window.rb`) covers playlist/navigation actions including
`add_favorites`/`play`/etc. No gap here; `toast.undo` (upstream's one real
action-based toast) is legitimately replaced by a direct `button-clicked`
signal connection in `lib/playlist_toast.rb`/`song_toast.rb` — same observable
behaviour, named correspondence.

## Preferences dialog, primary menu, shortcuts dialog, stylesheet — parity

See `parity-component-identification.md` for the detail; all four are
confirmed at full parity on type/CSS/label/accelerator for this pass.

## Verdict

Component parity is **not met**. Confirmed, unresolved gaps, in order of
user impact: (1) no real music library (CoreGrilo/TrackerWrapper/
LocalSearchWrapper absent — the app shows an empty collection permanently),
(2) no MPRIS (zero desktop playback integration), (3) `Player#play` crashes
the process on the one binding path available, and the drive suite that is
supposed to prove the app runs does not, in this audit's re-run, exit
cleanly, (4) no ReplayGain audio processing despite a settings row that
implies there is one, (5) no gapless playback, (6) remote cover art
(`StoreArt`) exists as a file and is wired into nothing.
