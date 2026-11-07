# Component identification — audit pass 2

| | |
|---|---|
| Upstream | `master` @ `63527674` (the fork's upstream default branch — **there is no `origin/main`** in this repo; the task framing said `origin/main` but `git ls-remote` shows only `master` plus feature/wip branches, so this and every other report compares against `master`) |
| Port | `ruby` @ `1dc12993` |

## Note on the task's branch name

The task instructions said to read upstream from `origin/main`. That ref does
not exist here:

```
$ git fetch origin main
fatal: couldn't find remote ref main
$ git ls-remote origin | grep -iE 'master|main'
63527674ad21c3af3f34bf6677775397a7b65f84	refs/heads/master
```

Upstream GNOME Music's default branch is `master`. All five reports in this
pass compare the port against `origin/master`. This is stated once here so
it is not silently assumed correct in the other four documents.

## Scan totals (whole-app survey, not a parity verdict)

```
component-scan.sh upstream-worktree  > upstream_components.tsv   (482 rows)
component-scan.sh gnome-music-rb/.   > port_components.tsv       (350 rows)
```

| Axis | Upstream distinct | Port distinct |
|---|---:|---:|
| Widget types | 50 | 47 |
| CSS classes | 34 | 33 |
| Signals | 58 | 38 |
| Actions | 8 | 7 |

Read as a lead only, per the skill's own warning. Follow-up reading in
`parity-component-parity.md` resolves most of the apparent gaps as scan
artifacts (actions built from a frozen constant table rather than a literal
at the call site; GStreamer bus-message signals that the Ruby port's
`Gtk::MediaFile`-based player does not need because it is not watching a
`Gst.Bus`). A few are real and are carried into that report.

## File mapping (upstream source + `.ui` → port file)

Upstream ships 33 `data/ui/*.ui` templates, one per widget/dialog, each
paired with a `gnomemusic/widgets/*.py` or `gnomemusic/views/*.py` class. The
port merges each pair into one `lib/*.rb` file, per house style. The mapping
is 1-widget-file + 1-`.ui`-file → 1 `.rb` file throughout, with no file split
across two Ruby files and no two upstream widgets merged into one Ruby class.
Confirmed file-by-file; representative rows:

| Upstream source | Upstream `.ui` | Port |
|---|---|---|
| `gnomemusic/window.py` | `data/ui/Window.ui` | `lib/window.rb` |
| `gnomemusic/widgets/headerbar.py` | `data/ui/HeaderBar.ui` | `lib/header_bar.rb` |
| `gnomemusic/widgets/playertoolbar.py` | `data/ui/PlayerToolbar.ui` | `lib/player_toolbar.rb` |
| `gnomemusic/widgets/songwidget.py` | `data/ui/SongWidget.ui` | `lib/song_widget.rb` |
| `gnomemusic/widgets/preferencesdialog.py` | `data/ui/PreferencesDialog.ui` | `lib/preferences_dialog.rb` |
| — (no `.ui`) | `data/ui/shortcuts-dialog.ui` | `lib/shortcuts_dialog.rb` |
| `gnomemusic/about.py` | (built in code upstream too) | `lib/about_dialog.rb` |

## Supporting (non-widget) modules — census

| Upstream | Port | Present? |
|---|---|---|
| `gnomemusic/application.py` | `lib/main.rb` | yes (merges `Application` + the two-arg `GnomeMusic.in` entry point) |
| `gnomemusic/coremodel.py` | `lib/core_model.rb` | yes, with a documented behavioural difference (see component-parity) |
| `gnomemusic/coresong.py`/`corealbum.py`/`coreartist.py`/`coredisc.py` | `lib/core_song.rb`/`core_album.rb`/`core_artist.rb`/`core_disc.rb` | yes |
| `gnomemusic/player.py` | `lib/player.rb` | yes, gapless path missing (documented in-file) |
| `gnomemusic/gstplayer.py` | `lib/gst_player.rb` | yes, re-architected on `Gtk::MediaFile` (no Gst bindings for Ruby); ReplayGain and gapless preload absent |
| `gnomemusic/queue.py` | `lib/queue.rb` | yes |
| `gnomemusic/search.py` | `lib/search.rb` | yes |
| `gnomemusic/musiclogger.py` | `lib/music_logger.rb` | yes |
| `gnomemusic/notificationmanager.py` | `lib/notification_manager.rb` | yes |
| `gnomemusic/inhibitsuspend.py` | `lib/inhibit_suspend.rb` | yes |
| `gnomemusic/pauseonsuspend.py` | `lib/pause_on_suspend.rb` | yes (landed since the last pass, `c0847d38`) — confirmed `require_relative`d from `lib/main.rb` and instantiated in `lib/window.rb` |
| `gnomemusic/embeddedart.py` | `lib/embedded_art.rb` | yes (landed since the last pass, `f879f4cd`) — confirmed wired in, required from both `lib/album_art.rb` and `lib/song_art.rb` |
| `gnomemusic/storeart.py` | `lib/store_art.rb` | **file exists but is dead code** — never `require_relative`d from anywhere in `lib/`, by its own header comment, because loading `soup3` crashes the app elsewhere. See `parity-accountability.md`; this is a component-identification finding because the unit it names (remote cover art) does not actually exist in the running app despite the file being present |
| `gnomemusic/mediaartloader.py` | `lib/media_art_loader.rb` | yes |
| `gnomemusic/utils.py` | `lib/utils.rb` | yes |
| `gnomemusic/asynciolimiter.py` | — | missing, and reasonably so — it is an asyncio-specific semaphore; the port's `store_art.rb` comment even names that it has no caller yet, so the limiter has nothing to limit |
| `gnomemusic/coregrilo.py` | — | **MISSING** |
| `gnomemusic/trackerwrapper.py` | — | **MISSING** |
| `gnomemusic/grilowrappers/localsearchwrapper.py` | — | **MISSING** |
| `gnomemusic/grilowrappers/localsearchplaylists.py` | `lib/local_search_playlists.rb` | present as a file, but see below — it cannot do its job without `coregrilo`/`trackerwrapper` |
| `gnomemusic/grilowrappers/playlist.py` | `lib/playlist.rb` | present |
| `gnomemusic/grilowrappers/smartplaylist.py` | `lib/smart_playlists.rb` | present |
| `gnomemusic/mpris.py` | — | **MISSING**, confirmed by `grep -ril mpris lib/ exe/` returning nothing; upstream's `application.py` imports and registers `MPRIS` unconditionally, so this is not a minor feature |
| `gnomemusic/windowplacement.py` | `lib/window_placement.rb` | yes |

**Net change since the last audit (`.reports/component-inventory.md` /
`.reports/parity-component-parity.md`, both still in the tree from the prior
pass):** of the 7 modules that pass flagged missing, **3 have landed**
(`pause_on_suspend`, `embedded_art`, `store_art`-the-file) and **4 are still
missing** (`core_grilo`, `local_search_wrapper`, `tracker_wrapper`, `mpris`).
`store_art` landing as a file is not the same as the feature landing — see
above and `parity-accountability.md`.

## What this means for the rest of the app

`lib/local_search_playlists.rb`, `lib/playlist.rb` and `lib/smart_playlists.rb`
all exist and all name Grilo/Tracker in their own comments (confirmed:
`grep -l grilo lib/*.rb` returns these three plus `core_model.rb`,
`core_song.rb`, `core_album.rb`, `core_artist.rb`, `core_disc.rb`,
`album_art.rb`, `artist_art.rb`, `search_header_bar.rb`, `window.rb`,
`main.rb`). Every one of those files is written against a data source
(`CoreGrilo`) that does not exist in this port. The component these files
*identify as* — "the thing that loads your music from Tracker" — is not a
component that exists end to end anywhere in `lib/`. It is nine files that
each assume the other nine, minus the one that was never built, will supply
real data.

## Shortcuts dialog — confirmed complete

`data/ui/shortcuts-dialog.ui` lists 13 accelerators across 3 sections
(General, Playback, Navigation). `lib/shortcuts_dialog.rb`'s `SECTIONS`
constant lists all 13, same groupings, same key combinations
(`<Primary>comma`, `<Primary>F`, `F1`, `<Primary>question`, `<Primary>Q`,
`<Ctrl>space`, `<Ctrl>N`, `<Ctrl>B`, `<Ctrl>R`, `<Ctrl>S`,
`<Ctrl>plus <Ctrl>equal`, `<Ctrl>minus`, `<Ctrl>M`, `<Alt>1`, `<Alt>2`,
`<Alt>3`, `<Alt>Left`). No gap on this unit.

## Primary menu — confirmed complete

`data/ui/HeaderBar.ui`'s primary menu has 4 items (Preferences, Keyboard
Shortcuts, Help, About Music). `lib/header_bar.rb` builds all 4 with matching
labels and the matching `app.*` action names. No gap on this unit.

## Stylesheet — confirmed byte-identical

`data/style.css` (upstream, 104 lines) and the `Style::CSS` heredoc in
`lib/style.rb` are byte-for-byte identical, confirmed with a direct diff.
Loaded the same way (`Gtk::CssProvider` at `PRIORITY_APPLICATION`). No gap.
