# Component parity — audit pass 3

Scope per the skill: for every component identified, does it *behave* the
same as upstream, not just exist. Builds on
`.reports/parity-component-identification.md` from this same pass.

## Behavioural parity holds for the widget layer

Re-driven fresh this pass (`xvfb-run ruby test/drive_smoke.rb` →
**SMOKE OK**, all 14 named checks; `test/drive_artwork.rb` → **ARTWORK OK**,
all 8 named checks; full transcript in `.reports/parity-test-parity.md`):

- Page navigation (album/artist push), search filtering and mode switching,
  preferences/shortcuts/about dialogs opening, playlist creation and
  add-to-playlist, song-widget menu construction, queue-fill-from-album,
  repeat-mode round-trip through settings, player-toolbar reveal-on-state,
  window placement save/restore, volume popover, two-line tip, and the
  playlist-toast undo/commit path all behave as their upstream counterpart
  specifies, confirmed by direct re-run, not by citing a log.
- **Favorite toggling now writes the tag back to Tracker for real**
  (`test/drive_smoke.rb`'s dedicated check, confirmed passing this pass).
  This was a real, fixed gap from an earlier pass (`d3e2336a`) and the fix
  holds under fresh re-run.

## Behavioural parity does not hold for the three things a music player exists to do

1. **Browsing your own music library.** Upstream: on startup, `CoreGrilo` +
   `LocalSearchWrapper` query the session Tracker miner and populate
   `CoreModel` with every song/album/artist Tracker has indexed; the user
   sees their collection. Port: nothing calls `CoreModel#load` outside of
   test fixtures that write arrays directly
   (`test/drive_music.rb:114-116`, confirmed by `grep -n "\.load(" lib/
   test/`, which finds no call to `CoreModel#load` inside `lib/` itself at
   all — only the drive script calls it, as a test setup). **A built build
   of this app, run by a real user with real music on disk, shows the empty
   welcome page every time**, indistinguishable from a user with no music
   at all. This is not a corner case; it is the primary use case.
2. **Remote cover art.** Upstream: `CoreGrilo` resolves a thumbnail URL from
   MusicBrainz/Last.fm/TheAudioDB and hands it to `StoreArt` to download,
   convert and cache, so an album with no local/embedded art still gets a
   picture. Port: `CoreGrilo#resolve_album_cover` cannot complete a single
   resolve call (`NotImplementedError`, rescued, logged — see
   `.reports/parity-component-identification.md`), and `StoreArt`, which
   would do the download/cache half, is never loaded into the running app.
   Confirmed by direct read of `lib/core_grilo.rb`'s `resolve_on` and a
   repo-wide `require_relative` grep, not inferred. Every album without
   local or embedded art shows the placeholder, indefinitely, in the port;
   upstream would eventually show a fetched cover.
3. **Gapless playback, ReplayGain, missing-codec installation.** All three
   documented plainly in `lib/gst_player.rb`'s class comment as absent
   because `Gtk::MediaFile` has no playbin3-equivalent hook. ReplayGain's
   preference row still exists in Preferences and is stored in
   `Settings`, but nothing reads it during playback (confirmed:
   `grep -n "replay_gain\|replaygain" lib/gst_player.rb lib/player.rb` →
   no hits outside `preferences_dialog.rb`/`settings.rb`), so toggling it
   has no audible effect — a UI control that silently does nothing is worse
   for a user than no control at all, because it actively misleads.

## MPRIS — zero behavioural surface, because zero file

Upstream exposes `org.mpris.MediaPlayer2` over D-Bus: GNOME Shell's media
controls, lock-screen controls, keyboard media keys routed through the
desktop (as opposed to the in-app `<Ctrl>` accelerators, which do work and
were re-confirmed this pass), and any `playerctl`-based tool all talk to
this interface. None of it exists in the port. This is a full component
absence already caught in the identification report; it is restated here
because it is also a behavioural gap for anyone who does not have the
app window focused, which upstream explicitly supports and the port cannot.

## Runtime gate: re-verified, now reproduces

Pass 2 flagged `drive_music.rb` failing to reproduce `DRIVE OK` twice. This
pass re-ran it fresh, independently, against current HEAD (`f324a75d`,
which specifically fixed the toast-dismissal segfault and widened the
watchdog that pass 2's failures were traced to):

```
$ nix develop --command xvfb-run -a ruby test/drive_music.rb
...
74 of 74 checks passed
DRIVE OK
[exit 0]
```

This reproduces the task's stated gate (`drive_ok=true, 74 checks, 0
failed`) for real, in this session, not by trusting the number handed to
this audit. `drive_smoke.rb` (14/14) and `drive_artwork.rb` (8/8) also
re-ran clean. The runtime gate is confirmed, not merely quoted — see
`.reports/parity-test-parity.md` for the full transcript.

**But a passing drive script is not the same claim as "the app works for a
user."** All three drive scripts build their fixtures by writing directly
into `CoreModel`'s backing arrays or by constructing widgets in isolation
(`test/drive_music.rb`, `test/drive_smoke.rb`, `test/drive_artwork.rb` —
none of them launches a real Tracker-backed startup). None of the 74+14+8
checks exercises `App#do_activate`'s real startup path with no fixture
injected, so none of them would ever fail on "the collection is always
empty" — the gap that matters most is structurally outside what the drive
suite's own fixture-injection style can detect. A component no check
exercises through its real entry point is unverified, not done, per this
round's own instruction.

## Verdict

Widget-level behavioural parity: **holds**, re-confirmed by fresh re-run.
Runtime gate: **confirmed reproducible** this pass, a genuine improvement
over pass 2. Whole-application behavioural parity: **does not hold** — the
three gaps above (no real library source, no working remote art, no MPRIS)
are not edge cases; they are the core value proposition of a music player,
and no drive check in the suite is shaped to catch any of them because
every drive script supplies its own fixtures instead of going through the
app's real startup path.
