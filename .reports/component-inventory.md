# gnome-music-rb — upstream component inventory

Opening survey for the full-parity port. Upstream is **GNOME Music (PyGObject,
GTK4 + libadwaita)** read from `origin/master` in this repo.

> **Deviation from the brief.** The task named `origin/main` as the upstream
> ref. That ref does not exist here; upstream lives on **`origin/master`**
> (`git show origin/master:<path>`, `git ls-tree -r --name-only origin/master`).
> Everything below was read from `origin/master`.

Upstream is a GtkBuilder app: **33 `.ui` files under `data/ui/`** carry the
widget trees, CSS classes and signal handler names, and the matching
`gnomemusic/**/*.py` class carries the `Gtk.Template.Child`s, the action
groups and the callbacks. Per the `component-identification` skill, the
component is **the pair of files**, and both halves map to one `lib/*.rb`.

## Current state of the port

Refreshed at the latest commit on `ruby` (`d3e2336a`, "Fix TrackerStore
favorite writeback and drop unused gstreamer_pbutils"), which followed a run
of passes that wired the four mandatory binding gems for real
(`core_grilo`/Grilo cover lookup, `tracker_store`/Tsparql favorite
writeback), ported `EmbeddedArt`/`StoreArt`, `PauseOnSuspend`, and
`DiscListItem`. `lib/` on `ruby` now holds **73 files** (71 under `lib/`
proper plus the gem-scaffold version file); the scaffold `lib/gnome_music.rb`
requires `lib/main.rb`, which is the real `class App`, launched from
`exe/gnome-music`.

The `grilo`, `libmediaart`, `tsparql` and `soup3` gems (the four named in the
brief) are in the gemspec, the runtime Gemfile and the flake's typelib path,
and each is `require`d and exercised on a live code path: `core_grilo.rb`
calls `Grl::Registry`/`Grl::Source#resolve`, `media_art.rb` calls
`MediaArt`, `store_art.rb` calls `Soup3`, `tracker_store.rb` calls
`Tsparql::SparqlConnection`. `gstreamer_pbutils` was removed from the
gemspec in the latest commit because nothing under `lib/` requires it — the
brief's "do not re-declare a dependency that pass deliberately removed"
case. This inventory does not re-verify the full gem-wiring checklist
(gemspec/Gemfile/lock/typelib/drive-script-exercises-it); that is the
accountability pass's job, and `.reports/parity-accountability.md` already
covers it in detail.

**Component status: 47 of 47 user-facing components are present.** Every
`.ui`-backed widget, dialog, page, row, menu, toast and header bar — including
`DiscListItem`, the last gap from the previous survey — now has a `lib/*.rb`
file. Of the 25 supporting (non-widget) modules, 22 are present and 3 are
missing, down from 7: `core_grilo`, `store_art`, `embedded_art` and
`tracker_store` (upstream's local-db half) all landed since the previous
survey. What remains missing is `mpris` outright, and two sub-pieces that
are documented as blocked on a real binding gap rather than simply unwritten
(see Blockers below): the session-Tracker **collection browsing** half of
`trackerwrapper.py`/`localsearchwrapper.py` (`Tracker.SparqlConnection.bus_new`
has no usable binding), which means `core_model.rb` still has no real
music-collection data source.

| Status | Count | Which |
|---|---:|---|
| user-facing components present | 47 | every window, dialog, page, view, tile, row, menu, toast, header bar, playback control and list-item template, including `disc_list_item` |
| user-facing components missing | 0 | — |
| supporting modules present | 22 | `core_model`, `core_album`, `core_artist`, `core_disc`, `core_song`, `core_grilo`, `local_search_playlists`, `playlist`, `player`, `queue`, `gst_player`, `shuffle_list_model`, `music_logger`, `album_art`, `artist_art`, `song_art`, `media_art_loader`, `media_art`, `texture_cache`, `inhibit_suspend`, `pause_on_suspend`, `store_art`, `embedded_art`, `tracker_store` (local-db half only) |
| supporting modules missing | 3 | `mpris`; the session-Tracker **collection-browsing** half of `trackerwrapper.py` (`local_search_wrapper` equivalent) — blocked, not merely unwritten |

Totals upstream: 33 `.ui` files under `data/ui/`, 68 Python modules under
`gnomemusic/`, 1 GSettings schema, 1 stylesheet, 19 SPARQL queries, 74 `po/`
catalogues.

House shape follows the pilot at `gnome-contacts-rb`: flat `lib/<thing>.rb`,
one class per file, `# frozen_string_literal: true` then `require 'adwaita'`
and `require_relative` siblings, a comment naming the upstream file, widgets
as memoized accessors configured in `.tap`.

Per-component `present` is marked inline below as **present** / **MISSING**
on each heading.

---

# Components, in the order a user meets them

## 1. Application, global actions and the dialogs it opens

### `gnomemusic/application.py` → `lib/main.rb` (`class App`) — application — **present**
`Adw.Application` subclass. Not a widget, but it owns every global action and
accelerator, so it is its own unit.

| Facet | Detail |
|---|---|
| Actions (`app.`) | `about`, `help` (F1), `mute` (`<Ctrl>M`), `play_pause` (`<Ctrl>space`, AudioPlay, AudioPause), `preferences` (`<Ctrl>comma`), `quit` (`<Ctrl>Q`), `repeat_toggle` (`<Ctrl>R`), `shuffle_toggle` (`<Ctrl>S`), `song_next` (`<Ctrl>N`, AudioNext), `song_previous` (`<Ctrl>B`, AudioPrev), `song_stop` (AudioStop), `volume_decrease` (`<Ctrl>minus`, `<Ctrl>KP_Subtract`), `volume_increase` (`<Ctrl>plus`, `<Ctrl>equal`, `<Ctrl>KP_Add`) — 13 actions |
| Behaviour | `do_startup` forces `Adw.ColorScheme.PREFER_LIGHT`; `do_activate` builds `Window`, registers MPRIS, adds the `devel` CSS class when the app id is `org.gnome.Music.Devel` |
| Notes | `Adwaita::Application` is broken in the Ruby bindings — actions and accels go on `Gtk::Application` (see `ruby-gtk` skill) |

### `gnomemusic/about.py` → `lib/about_dialog.rb` — dialog — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | application name "Music", icon = app id, developer name "The GNOME Project", ~125 developers, 3 designers, `translator-credits`, website `apps.gnome.org/Music/`, issue url, `© The GNOME Music Developers`, GPL-2.0 |

### `data/ui/shortcuts-dialog.ui` → `lib/shortcuts_dialog.rb` — dialog — **present**
Standalone builder object (`AdwShortcutsDialog id="shortcuts_dialog"`), no
backing Python file — its own unit.

| Section | Items |
|---|---|
| General | Preferences (`app.preferences`), Search (`<Primary>F`), Help (`app.help`), Keyboard shortcuts (`app.shortcuts`), Quit (`app.quit`) |
| Playback | Play/Pause (`<Ctrl>space`), Next song (`<Ctrl>N`), Previous song (`<Ctrl>B`), Toggle repeat (`<Ctrl>R`), Toggle shuffle (`<Ctrl>S`), Increase volume (`<Ctrl>plus <Ctrl>equal`), Decrease volume (`<Ctrl>minus`), Toggle mute (`<Ctrl>M`) |
| Navigation | Go to Albums (`<Alt>1`), Go to Artists (`<Alt>2`), Go to Playlists (`<Alt>3`), Go back (`<Alt>Left`) |

> Note: the primary menu and this dialog both target `app.shortcuts`, which
> `application.py` never installs — upstream relies on GTK's built-in
> shortcuts action. The port must install it explicitly.

### `gnomemusic/widgets/preferencesdialog.py` + `data/ui/PreferencesDialog.ui` → `lib/preferences_dialog.rb` — dialog — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | title "Preferences" |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | "Player Settings", "Power Settings" |
| `Adw.ComboRow` | 2 | — | `notify::selected` | "Repeat Mode" (None/Song/All/Shuffle) → `settings.repeat`; "ReplayGain" + subtitle "Balance loudness between songs if ReplayGain metadata is found" (Disabled/Album/Track) → `settings.replaygain` |
| `Gtk.StringList` | 2 | — | — | the two models above |
| `Adw.SwitchRow` | 1 | — | — | "Inhibit Suspend" / "Only while playing" → `settings.inhibit-suspend` |

### `gnomemusic/windowplacement.py` → `lib/window_placement.rb` — support — **present**
Restores and saves `window-size` / `window-maximized`; connects
`notify::maximized`, `notify::default-height`, `notify::default-width`.

## 2. The main window

### `gnomemusic/window.py` + `data/ui/Window.ui` → `lib/window.rb` — window — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (dynamic, Devel build only) | — | 500×300 default, 360×294 min |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-pressed` → `_on_key_press` | type-to-search: a printable char opens the search view and seeds its text |
| `Gtk.ShortcutController` | 1 (controller) | — | — | built in code, holds the 6 `win.` accels |
| `Adw.ToolbarView` | 2 | — | — | outer (`top-bar-style`/`bottom-bar-style` raised) and `_main_toolbar_view` |
| `Adw.ToastOverlay` | 1 | — | — | host for `SongToast` / `PlaylistToast` |
| `Adw.NavigationView` | 1 | — | — | `replace_with_tags(["mainview"/"searchview"/"status"])` |
| `Adw.NavigationPage` | 1 | — | — | tag `mainview`, title "Main View" |
| `Gtk.Overlay` | 1 | — | — | |
| `Adw.ViewStack` | 1 | — | `notify::visible-child` | pages `albums`, `artists`, `playlists` added at runtime from `View` |
| `Gtk.ProgressBar` | 1 | `osd` | — | `_loading_progress`, pulsed by `NotificationManager`, hidden by default |
| `PlayerToolbar` | 1 | — | — | bottom bar, `revealed` toggled by `set_player_visible` |
| Actions (`win.`) | 6 | | | `navigate_back` (`<Alt>Left`), `search_bar_close` (Escape), `search_bar_open` (`<Ctrl>F`), `view_albums` (`<Alt>1`, `<Alt>KP_1`), `view_artists` (`<Alt>2`, `<Alt>KP_2`), `view_playlists` (`<Alt>3`, `<Alt>KP_3`) |
| Repeaters | the three main views, created lazily in `_switch_to_player_view` once songs are available |
| Conditional | `status` page when no songs / Tracker unavailable / Tracker outdated; `searchview` when search mode is active |

### `gnomemusic/widgets/headerbar.py` + `data/ui/HeaderBar.ui` → `lib/header_bar.rb` — header bar + primary menu — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | template root |
| `Adw.HeaderBar` | 1 | — | — | title widget swaps with state |
| `Gtk.MenuButton` | 1 | — | — | `open-menu-symbolic`, primary, tooltip "Menu", model `_primary_menu`; visible only in MAIN/EMPTY |
| `Gtk.ToggleButton` | 1 | — | `notify::active` (bound to `search-mode-active`) | `edit-find-symbolic`, tooltip "Search"; hidden in SEARCH state, insensitive in EMPTY |
| `Adw.ViewSwitcher` | 1 | — | — | built in code, policy WIDE, halign center; hidden in EMPTY |
| Menu `_primary_menu` | 4 items | | | Preferences (`app.preferences`), Keyboard Shortcuts (`app.shortcuts`), Help (`app.help`), About Music (`app.about`) |
| States | `MAIN`, `CHILD`, `SEARCH`, `EMPTY` — each changes title widget, menu-button and search-button visibility |

### `gnomemusic/widgets/searchheaderbar.py` + `data/ui/SearchHeaderBar.ui` → `lib/search_header_bar.rb` — header bar — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` / `Adw.HeaderBar` | 1 / 1 | — | — | |
| `Gtk.ToggleButton` | 1 | — | bound to `search-mode-active` | `edit-find-symbolic`, tooltip "Search" |
| `Gtk.SearchEntry` | 1 | `error` (dynamic, on NO_RESULT) | `search-changed` → `_search_entry_changed` | built in code: placeholder "Search songs, artists and albums", width 500, `search_delay` 250, halign center |
| `Gtk.ShortcutController` | 1 (controller) | — | — | Escape → `action(win.search_bar_close)` |

### `gnomemusic/widgets/statusnavigationpage.py` + `data/ui/StatusNavigationPage.ui` → `lib/status_navigation_page.rb` — empty/error page — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` | 1 | — | — | title "Music", tag `status` |
| `Adw.ToolbarView` | 1 | — | — | hosts its own `HeaderBar` in EMPTY state |
| `Adw.StatusPage` | 1 | — | — | icon `music-note-outline-symbolic` |
| `Adw.Clamp` | 1 | — | — | `_initial_state`, max 620 / tightening 500 — the welcome state |
| `Gtk.Picture` | 1 | — | — | `resource:///org/gnome/Music/icons/welcome-music.svg` |
| `Gtk.Label` | 2 | `title-1`, `body` | — | "Welcome to Music"; description is markup with a link to the XDG Music folder, or "Your XDG Music directory is not set." |
| States | `EMPTY` (welcome), `SEARCH` ("No Music Found" / "Try a Different Search"), `NO_TRACKER` ("GNOME Music could not connect to Tracker." / "Your music files cannot be indexed without Tracker running." / `dialog-error-symbolic`), `TRACKER_OUTDATED` ("Your system Tracker version seems outdated." / "Music needs Tracker version 3.0.0 or higher.") |

## 3. Albums

### `gnomemusic/views/albumsview.py` + `data/ui/AlbumsView.ui` → `lib/albums_view.rb` — page — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | name `albums`, title "Albums", icon `media-optical-cd-audio-symbolic` |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Gtk.GridView` | 1 | styled via `#albums gridview`, `#albums gridview > child`, `:hover/:selected` | `activate` → `_on_album_activated` | max 10 columns, single-click-activate |
| `Gtk.SignalListItemFactory` | 1 | — | `setup`, `bind` | builds one `AlbumCover` per album — **repeater**, N = albums |

### `gnomemusic/widgets/albumcover.py` + `data/ui/AlbumCover.ui` → `lib/album_cover.rb` — tile wrapper — **present**
`Gtk.FlowBoxChild`, CSS `tile` (`.tile:hover` in the stylesheet). Holds an `AlbumTile`.

### `gnomemusic/widgets/albumtile.py` + `data/ui/AlbumTile.ui` → `lib/album_tile.rb` — tile — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | — | `query-tooltip` | vertical, `has_tooltip`, valign start |
| `Gtk.Image` | 1 | `tile-image` | — | cover art |
| `Gtk.Label` | 2 | — / `artist-label` + `dim-label` | — | album title (wrap, ellipsize middle, 20 chars, 1 line), artist |

### `gnomemusic/widgets/albumnavigationpage.py` + `data/ui/AlbumNavigationPage.ui` → `lib/album_navigation_page.rb` — page — **present**
`Adw.NavigationPage` → `Adw.ToolbarView` → `Adw.HeaderBar` with `Adw.WindowTitle` (`_page_title`), content a `Gtk.ScrolledWindow` (hscrollbar never) holding an `AlbumWidget`.

### `gnomemusic/widgets/albumwidget.py` + `data/ui/AlbumWidget.ui` → `lib/album_widget.rb` — album detail — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` / `Adw.Clamp` | 1 / 1 | — | — | clamp max 1000, 48px top/bottom |
| `Gtk.Box` | 4 | — | — | album info row (spacing 32), details column, button row (spacing 12) |
| `Gtk.Image` | 1 | — | — | cover |
| `Gtk.Label` | 4 | `title-1`, `title-3`, `dim-label` ×2 | — | title, artist, released (markup), composer |
| `Gtk.Button` | 1 | `circular` | `clicked` → `_on_play_button_clicked` | 44×44, `media-playback-start-symbolic`, tooltip "Play" |
| `Gtk.MenuButton` | 1 | `circular` | — | 44×44, `view-more-symbolic`, direction none, model `album_menu` |
| `Gtk.ListBox` | 1 | `background` | — | `_disc_list_box`, selection none, 48px top |
| `Gtk.Label` (header) | N | `disc-label`, `heading` | — | per-disc header built in `_set_header_func` — **repeater** |
| `DiscBox` | N | — | `song-activated` → `_song_activated` | one per disc — **repeater** |
| Actions (`album.`) | 3 | | | `play`, `add_favorites`, `add_playlist` |
| Menu `album_menu` | 3 items | | | `_Play` → `album.play`, `Add to _Favorite Songs` → `album.add_favorites`, `_Add to Playlist…` → `album.add_playlist` |

### `gnomemusic/widgets/discbox.py` + `data/ui/DiscBox.ui` → `lib/disc_box.rb` — row — **present**
`Gtk.ListBoxRow` (not focusable/activatable/selectable) holding a `Gtk.ListBox`
with CSS `boxed-list`, selection none, `row-activated` → `_song_activated`;
one `SongWidget` per song (**repeater**).

### `data/ui/DiscListItem.ui` → `lib/disc_list_item.rb` — list item template — **present**
`Gtk.ListItem` template with no backing Python file (own unit): a vertical
`Gtk.Box`, a `Gtk.Label` bound to `CoreDisc.disc_nr`, and a `DiscBox` bound to
`CoreDisc.model`. Ported even though no upstream `.py`/`.ui` file references
it (see the previous survey's note #2) — kept for full parity rather than
dropped as dead code.

### `gnomemusic/widgets/songwidget.py` + `data/ui/SongWidget.ui` → `lib/song_widget.rb` — song row — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` | 1 | `songwidget` | — | not selectable |
| `Gtk.Box` | 5 | — | — | outer (spacing 6), number box (48px, homogeneous), `title_box`, `_artist_box` (hidden by default), `_album_duration_box` |
| `Gtk.Image` | 2 | `drag-handle` (+`:backdrop`) | — | `_dnd_icon` (`list-drag-handle-symbolic`, hidden), `_play_icon` |
| `Gtk.Label` | 5 | `dim-label`, `bold-label` | — | number, title, artist, album (hidden by default), duration; title gets dynamic styling in `_on_state_changed` |
| `StarToggle` | 1 | — | `toggled` | valign center, 12px margins |
| `Gtk.MenuButton` | 1 | `flat` | — | `view-more-symbolic`, hidden by default, popover is a `SongWidgetMenu` |
| `Gtk.DragSource` | 1 (controller) | — | `prepare` → `_on_drag_prepare`, `drag-begin` → `_on_drag_begin` | move; drag icon is a throwaway `Gtk.ListBox` |
| `Gtk.DropTarget` | 1 (controller) | — | `drop` → `_on_drop` | move, format `SongWidget`, preload — emits `widget-moved` |
| `Gtk.SizeGroup` | 1 (type) | — | — | horizontal, over title/artist/album-duration boxes |
| States | `State` enum drives the play icon and title styling (playing / played / unplayed) |

### `gnomemusic/widgets/songwidgetmenu.py` + `data/ui/SongWidgetMenu.ui` → `lib/song_widget_menu.rb` — menu — **present**

| Facet | Detail |
|---|---|
| Widget | `Gtk.PopoverMenu` template, autohide, position bottom, model `song-menu` |
| Menu items | `_Play` → `songwidget.play`, `_Add to Playlist…` → `songwidget.add_playlist`, `_Remove from Playlist` → `songwidget.remove_playlist`, plus `_Open Location` → `songwidget.open_location` built in code |
| Actions (`songwidget.`) | `play`, `add_playlist`, `open_location`, and `remove_playlist` **only** for a non-smart playlist; for a non-playlist context menu item index 2 is removed — **conditional** |

### `gnomemusic/widgets/startoggle.py` → `lib/star_toggle.rb` — button (no `.ui`) — **present**
`Gtk.ToggleButton`, CSS `star` + `flat` + `circular`, gains `starred` when
active and `interacted` on click (drives the `rotate_star`/`rotate_unstar`
keyframes in `style.css`). Icon `starred-symbolic`/`non-starred-symbolic`,
tooltip "Unstar"/"Star". Signals `toggled`, `clicked`.

## 4. Artists

### `gnomemusic/views/artistsview.py` + `data/ui/ArtistsView.ui` → `lib/artists_view.rb` — page — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | name `artists`, title "Artists", icon `music-artist-symbolic` |
| `Adw.OverlaySplitView` | 1 | — | — | |
| `Gtk.ScrolledWindow` | 2 | — | — | sidebar and content |
| `Gtk.ListView` | 1 | `navigation-sidebar` | `activate` → `_on_artist_activated` | |
| `Gtk.SignalListItemFactory` | 1 | — | `setup`, `bind` | one `ArtistTile` per artist, each wired to `clicked` — **repeater** |

### `gnomemusic/widgets/artisttile.py` + `data/ui/ArtistTile.ui` → `lib/artist_tile.rb` — sidebar row — **present**
`Gtk.Box` → inner `Gtk.Box` with `Gtk.Image` (cover) and `Gtk.Label`
(ellipsize end, 16/10px margins). A `Gtk.GestureClick` (controller) is added in
code, `pressed` → `_on_button_pressed`; emits `clicked`.

### `gnomemusic/widgets/artistnavigationpage.py` + `data/ui/ArtistNavigationPage.ui` → `lib/artist_navigation_page.rb` — page — **present**
`Adw.NavigationPage` title "Artist" → `Adw.ToolbarView` → `Adw.HeaderBar` +
`Gtk.ScrolledWindow` (hscrollbar never) holding an `ArtistAlbumsWidget`.

### `gnomemusic/widgets/artistalbumswidget.py` + `data/ui/ArtistAlbumsWidget.ui` → `lib/artist_albums_widget.rb` — **present**
`Gtk.Box` (vertical) → `Adw.Clamp` (max 1000) → `Gtk.ListBox` CSS `background`;
one `Gtk.ListBoxRow` holding an `AlbumWidget` per album, built in code —
**repeater**.

## 5. Playlists

### `gnomemusic/views/playlistsview.py` + `data/ui/PlaylistsView.ui` → `lib/playlists_view.rb` — page — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | name `playlists`, title "Playlists", icon `music-playlist-symbolic` |
| `Adw.OverlaySplitView` | 1 | — | — | |
| `Gtk.ScrolledWindow` | 1 | — | — | width request 220 |
| `Gtk.ListBox` | 1 | `navigation-sidebar` | `row-activated` → `_on_playlist_activated` | selection single, header func separates smart from user playlists |
| `Adw.Bin` | 1 | — | — | `_playlist_page`, hosts `PlaylistsWidget` |
| `PlaylistTile` | N | — | — | one per playlist — **repeater** |

### `gnomemusic/widgets/playlisttile.py` + `data/ui/PlaylistTile.ui` → `lib/playlist_tile.rb` — row — **present**
`Gtk.ListBoxRow` → `Gtk.Box` with `Gtk.Image` CSS `playlist-icon` (icon varies
by smart-playlist kind) and `Gtk.Label` (ellipsize end, 16/10px margins).

### `gnomemusic/widgets/playlistswidget.py` + `data/ui/PlaylistsWidget.ui` → `lib/playlists_widget.rb` — **present**
`Gtk.Box` (vertical) → `Adw.Clamp` (1000) with `PlaylistControls`, then
`Gtk.ScrolledWindow` → `Adw.Clamp` (1000) → `Gtk.ListBox` CSS `boxed-list`,
`row-activated` → `_on_song_activated`. Installs `win.playlist_play`; connects
`widget_moved` on each row for drag reorder. One `SongWidget` per song —
**repeater**.

### `gnomemusic/widgets/playlistcontrols.py` + `data/ui/PlaylistControls.ui` → `lib/playlist_controls.rb` — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 2 | — | — | vertical root (30px top), button row (spacing 12) |
| `Gtk.Stack` | 1 | — | — | `_name_stack`: label ↔ `renaming_dialog` page |
| `Gtk.Label` | 2 | `title-1`, `body` | — | "Playlist Name", songs count |
| `Gtk.Box` (rename) | 1 | `linked` | — | |
| `Gtk.Entry` | 1 | — | `activate` → `_on_playlist_renamed`, `changed` → `_on_rename_entry_changed` | |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-pressed` → `_on_rename_entry_key_pressed` | Escape cancels rename |
| `Gtk.Button` | 2 | `suggested-action` / `circular` | `clicked` → `_on_playlist_renamed` / `_on_play_button_clicked` | `_Done`; 44×44 play button, tooltip "Play" |
| `Gtk.MenuButton` | 1 | `circular` | — | 44×44, `view-more-symbolic`, direction none, model `playlistMenu` |
| Actions (`win.`) | 3 | | | `playlist_play`, `playlist_delete`, `playlist_rename` |
| Menu `playlistMenu` | 3 items | | | `_Play`, `_Delete`, `_Rename…` |
| Conditional | the menu is insensitive / rename disabled for smart playlists |

### `gnomemusic/widgets/playlistdialog.py` + `data/ui/PlaylistDialog.ui` → `lib/playlist_dialog.rb` — dialog — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | `view` | — | 400×500 |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1 / 1 | — | — | no end title buttons |
| `Gtk.Label` (title) | 1 | `title` | — | "Add to Playlist" |
| `Gtk.Button` | 4 | `suggested-action` ×3 | `clicked` → `_on_cancel_button_clicked` / `_on_selection` / `_on_editing_done` ×2 | `_Cancel`, `_Add` (insensitive until a row is selected), `C_reate`, `Add` |
| `Gtk.Stack` | 1 | — | — | `_empty_box` (first playlist) ↔ `_normal_box` (list) |
| `Gtk.Image` | 1 | `grey-image` | — | `music-note-outline-symbolic`, pixel size 100 |
| `Gtk.Label` | 1 | — | — | "Enter a name for your first playlist" |
| `Gtk.Entry` | 2 | — | `activate` → `_on_editing_done`, `changed` → `_on_add_playlist_entry_changed` | first-playlist entry (300px) and bottom-bar entry (placeholder "New Playlist…") |
| `Gtk.EventControllerFocus` | 2 (controllers) | — | `enter` → `_on_add_playlist_entry_focused` | |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Gtk.ListBox` | 1 | — | `selected-rows-changed` → `_on_selected_rows_changed` | selection single |
| `Gtk.Box` (bottom bar) | 1 | `linked` | — | |
| `PlaylistDialogRow` | N | — | — | one per user playlist — **repeater** |
| Conditional | `_empty_box` when there are no user playlists |

### `gnomemusic/widgets/playlistdialogrow.py` + `data/ui/PlaylistDialogRow.ui` → `lib/playlist_dialog_row.rb` — row — **present**
`Gtk.ListBoxRow` CSS `playlistdialog-row` (`:selected` and `:selected label`
rules) → `Gtk.Box` with `Gtk.Label` (ellipsize end, 8px margins) and
`Gtk.Image` `selection-mode-symbolic` (shown when selected).

## 6. Search

### `gnomemusic/views/searchview.py` + `data/ui/SearchView.ui` → `lib/search_view.rb` — page — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` | 1 | `view` | — | title "Search view", tag `searchview` |
| `Adw.ToolbarView` | 1 | — | — | hosts a `SearchHeaderBar` |
| `Gtk.Stack` | 1 | — | — | pages `main` and `status` |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | max 1600 |
| `Gtk.Box` | 4 | — | — | container (margins 20/120), artist header, album header, songs header — headers homogeneous |
| `Gtk.Label` | 3 | `search-header` | — | "Artists", "Albums", "Songs" |
| `Gtk.Button` | 2 | — | `clicked` → `_on_all_artists_clicked` / `_on_all_albums_clicked` | each a box of "View All" + `go-next-symbolic` |
| `Gtk.FlowBox` | 2 | — | `child-activated` → `_on_artist_activated` / `_on_album_activated` | 1–6 per line, homogeneous, selection none, hidden until there are results |
| `Gtk.ListBox` | 1 | `boxed-list` | `row-activated` → `_song_activated` | songs |
| `Adw.StatusPage` | 1 | — | — | "No Search Started" / "No Results Found" |
| `SongWidget` / `AlbumCover` / `ArtistSearchTile` | N each | — | — | **repeaters** |
| Conditional | artist and album sections hidden when their result set is empty; `status` page for no-search / no-results |

### `gnomemusic/widgets/albumssearchnavigationpage.py` + `data/ui/AlbumsSearchNavigationPage.ui` → `lib/albums_search_navigation_page.rb` — page — **present**
`Adw.NavigationPage` title "Albums" → toolbar view + header bar →
`Gtk.ScrolledWindow` → `Adw.Clamp` (1600) → `Gtk.Box` (margins 20/120) →
`Gtk.FlowBox` (1–6 per line, selection none), `child-activated` →
`_on_album_activated`; one `AlbumCover` per album — **repeater**.

### `gnomemusic/widgets/artistssearchnavigationpage.py` + `data/ui/ArtistsSearchNavigationPage.ui` → `lib/artists_search_navigation_page.rb` — page — **present**
Same shape, title "Artists", `_all_artists_flowbox`, `child-activated` →
`_on_artist_activated`; one `ArtistSearchTile` per artist — **repeater**.

### `gnomemusic/widgets/artistsearchtile.py` + `data/ui/ArtistSearchTile.ui` → `lib/artist_search_tile.rb` — tile — **present**
`Gtk.FlowBoxChild` CSS `tile` → `Gtk.Box` (`has_tooltip`, `query-tooltip` →
`_on_tooltip_query`) with `Gtk.Image` CSS `tile-image` and a `Gtk.Label`
(wrap, ellipsize middle, 20 chars, 1 line).

### `gnomemusic/search.py` → `lib/search.rb` — support — **present**
Holds `search-mode-active` and the `State` enum (`NONE`, `NO_RESULT`,
`RESULT`) the window and both header bars bind to.

## 7. Playback controls

### `gnomemusic/widgets/playertoolbar.py` + `data/ui/PlayerToolbar.ui` → `lib/player_toolbar.rb` — bottom bar — **present**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ActionBar` | 1 | — | — | `revealed` false by default |
| `Gtk.Box` | 5 | — | `query-tooltip` → `_on_tooltip_query` (song info box) | song info (spacing 8), labels column, buttons+scale column, buttons row (spacing 12), menu box (34px) |
| `Gtk.Image` | 2 | — | — | cover, `_play_pause_image` (`media-playback-start-symbolic`, icon size 2) |
| `Gtk.Label` | 4 | `bold-label`, `numeric` ×2 | — | title, artist (both ellipsize middle, 28 chars), progress time `0∶00`, duration `0∶00` |
| `Gtk.Button` | 3 | `circular` ×2, `pill` | `clicked` → `_on_prev_button_clicked` / `_on_play_button_clicked` / `_on_next_button_clicked` | `media-skip-backward/forward-symbolic`, tooltips "Previous"/"Play" (becomes "Pause")/"Next"; all insensitive until a song loads |
| `Adw.Clamp` | 1 | — | — | max 1000 |
| `SmoothScale` | 1 | `smooth-scale` | `value-changed` → `_on_progress_value_changed` | draw-value false |
| `RepeatModeButton` / `VolumeButton` | 1 / 1 | — | — | packed end |
| `TwoLineTip` | 1 | — | — | the tooltip widget |

### `gnomemusic/widgets/smoothscale.py` → `lib/smooth_scale.rb` — scale (no `.ui`) — **present**
`Gtk.Scale` subclass with per-pixel smoothing. `Gtk.GestureClick` (controller)
→ `pressed`/`released`; `change-value` → `_on_smooth_scale_seek`; follows the
player's `notify::state` and `notify::duration`; insensitive while STOPPED or
LOADING.

### `gnomemusic/widgets/repeatmodebutton.py` + `data/ui/RepeatModeButton.ui` → `lib/repeat_mode_button.rb` — **present**
`Gtk.Box` → `Gtk.MenuButton` CSS `circular`, direction up, accessible label
"Set Repeat Mode", icon changes per mode
(`media-playlist-consecutive-symbolic`, `…repeat-song-symbolic`,
`…repeat-symbolic`, `…shuffle-symbolic`). Builds a `Gio.Menu` of the four
`RepeatMode`s ("Shuffle/Repeat Off", "Repeat Song", "Repeat All", "Shuffle")
and a stateful action `repeatmenu.repeat` bound to the player's `repeat-mode`.

### `gnomemusic/widgets/volumebutton.py` + `data/ui/VolumeButton.ui` → `lib/volume_button.rb` — **present**
`Gtk.Box` → `Gtk.MenuButton` CSS `circular`, direction up, accessible label
"Adjust Volume", icon from volume level; popover (250px) with a
`Gtk.ToggleButton` CSS `circular`+`flat` (`audio-volume-muted-symbolic`,
accessible label "Mute/Unmute") and a `Gtk.Scale` on a `Gtk.Adjustment`
(0.0–1.0, step 0.01, page 0.1). Cubic↔linear volume conversion.

### `gnomemusic/widgets/twolinetip.py` + `data/ui/TwoLineTip.ui` → `lib/two_line_tip.rb` — tooltip — **present**
`Gtk.Box` (vertical) with two `Gtk.Label`s, the first CSS `bold-label`.

## 8. Toasts, notifications, chrome

### `gnomemusic/songtoast.py` → `lib/song_toast.rb` — toast — **present**
`Adw.Toast` "{song} removed from {playlist}", button "Undo", action
`toast.undo` installed on the window, `dismissed` → commit the removal.

### `gnomemusic/playlisttoast.py` → `lib/playlist_toast.rb` — toast — **present**
`Adw.Toast` "Playlist {title} removed", button "Undo", action `toast.undo`,
`dismissed` → commit the deletion.

### `gnomemusic/notificationmanager.py` → `lib/notification_manager.rb` — support — **present**
Refcounts loading operations and drives the window's `_loading_progress`
(`loading_visible` / `loading_pulse`).

### `data/style.css` → `lib/style.rb` (`Gtk::CssProvider`) — stylesheet — **present**
Classes defined upstream: `artist-label`, `tile`, `tile-image`,
`playlist-icon`, `disc-label`, `smooth-scale`, `grey-image`, `bold-label`,
`playlistdialog-row`, `search-header`, `drag-handle`, `songwidget`, `star`
(with `interacted`/`starred` and the `rotate_star`/`rotate_unstar` keyframes),
plus `#albums gridview` child/hover/selected rules.

### `data/org.gnome.Music.gschema.xml` → `lib/settings.rb` — settings — **present**
Keys: `window-size` (`[768, 600]`), `window-maximized` (true), `repeat`
(enum none/song/all/shuffle), `replaygain` (enum disabled/album/track),
`inhibit-suspend` (false).

### `gnomemusic/utils.py` → `lib/utils.rb` — support — **present**
`ArtSize`, `CoreObjectType`, `DefaultIconType`, `RepeatMode` (icon + label per
mode), `SongStateIcon`, `View` (ALBUM/ARTIST/PLAYLIST), "Unknown Artist",
duration formatting.

### `gnomemusic/coverpaintable.py` → `lib/cover_paintable.rb` — paintable — **present**
The rounded placeholder/cover art paintable every tile and the toolbar use.
Registered as a `GLib::Object` that includes `Gdk::Paintable` — `type_register`
has to come *before* the `include`, or the bindings leave the GType without
the interface — with `virtual_do_snapshot` /
`virtual_do_get_intrinsic_width` / `virtual_do_get_intrinsic_height`.
`get_flags` is deliberately not implemented: the bindings cannot marshal a
flags return value out of a Ruby virtual function.

### `gnomemusic/grilowrappers/smartplaylist.py` → `lib/smart_playlists.rb` — data + user-facing titles — **present**
Seven smart playlists shown in the playlists sidebar: "Most Played", "Never
Played", "Recently Played", "Recently Added", "Starred Songs",
"Insufficiently Tagged", "All Songs".

---

# Supporting (non-widget) upstream modules

Not components, but the port needs equivalents before any view has data.
17 of these exist on `ruby`; 8 do not. The `Present` column is authoritative.

| Upstream | Suggested `lib/*.rb` | Role | Present |
|---|---|---|---|
| `gnomemusic/coremodel.py` | `lib/core_model.rb` | all list models, `songs-available`, `queue-loaded` | yes |
| `gnomemusic/corealbum.py` | `lib/core_album.rb` | album object | yes |
| `gnomemusic/coreartist.py` | `lib/core_artist.rb` | artist object | yes |
| `gnomemusic/coredisc.py` | `lib/core_disc.rb` | disc object | yes |
| `gnomemusic/coresong.py` | `lib/core_song.rb` | song object | yes |
| `gnomemusic/coregrilo.py` | `lib/core_grilo.rb` | Grilo registry setup + remote cover-source `#resolve` lookup | yes (cover-lookup half only; the TrackerWrapper/LocalSearchWrapper ownership half is not ported — see Blockers) |
| `gnomemusic/grilowrappers/localsearchwrapper.py` | (no `lib/*.rb` — blocked) | SPARQL queries over the session Tracker indexer (collection browsing) | **no** — blocked, not merely unwritten (see Blockers) |
| `gnomemusic/grilowrappers/localsearchplaylists.py` | `lib/local_search_playlists.rb` | playlist storage | yes |
| `gnomemusic/grilowrappers/playlist.py` | `lib/playlist.rb` | playlist model | yes |
| `gnomemusic/trackerwrapper.py` | `lib/tracker_store.rb` | local Tracker (TinySparql) connection, favorite-tag writeback | yes (local-db half only; the session-indexer bus connection for collection browsing is not ported — see Blockers) |
| `gnomemusic/player.py` | `lib/player.rb` | playback state machine, `RepeatMode` | yes |
| `gnomemusic/queue.py` | `lib/queue.rb` | play queue | yes |
| `gnomemusic/gstplayer.py` | `lib/gst_player.rb` | GStreamer playbin, `Playback` enum | yes |
| `gnomemusic/shufflelistmodel.py` | `lib/shuffle_list_model.rb` | shuffle model | yes |
| `gnomemusic/mpris.py` | `lib/mpris.rb` | MPRIS2 D-Bus interface | **no** |
| `gnomemusic/albumart.py`, `artistart.py`, `songart.py`, `mediaartloader.py`, `texturecache.py` | `lib/album_art.rb`, `lib/artist_art.rb`, `lib/song_art.rb`, `lib/media_art_loader.rb`, `lib/texture_cache.rb` | cover-art pipeline | yes (all 5) |
| (libmediaart, `MediaArt` 2.0 GIR) | `lib/media_art.rb` | the MediaArt cache path and the directory cover lookup that fills it, per the Media Art Storage Spec; no MediaArt typelib in the dev shell | yes |
| `gnomemusic/storeart.py`, `embeddedart.py` | `lib/store_art.rb`, `lib/embedded_art.rb` | remote store art (downloads via Soup3, caches via the MediaArt gem); embedded art (tag-embedded cover extraction) | yes (both) |
| `gnomemusic/inhibitsuspend.py` | `lib/inhibit_suspend.rb` | suspend inhibitor while playing | yes |
| `gnomemusic/pauseonsuspend.py` | `lib/pause_on_suspend.rb` | logind `PrepareForSleep` delay lock | yes |
| `gnomemusic/musiclogger.py`, `asynciolimiter.py` | `lib/music_logger.rb`, (drop) | logging; the asyncio limiter is Python-specific plumbing | `music_logger` yes |
| `data/queries/*.rq` (19 files) | `lib/queries/` or inline | SPARQL used by the localsearch wrapper | n/a |
| `po/` (74 catalogues), `help/C/*.page` (10 pages) | translation / help infrastructure | **not built** — zero translation markers, zero catalogues, zero help pages exist anywhere in the port | n/a |

---

# Blockers and decisions needed before porting

1. **Upstream ref name.** The brief (in earlier passes) said `origin/main`;
   the only upstream ref in this clone is `origin/master`. Every step uses
   `master`.
2. ~~One user-facing component missing~~ — **resolved.** `disc_list_item.rb`
   is now ported (see above), even though no upstream `.py`/`.ui` file
   reaches `DiscListItem.ui`; it is kept for full parity with upstream's
   file set rather than dropped as dead code.
3. **The session-Tracker collection-browsing connection remains genuinely
   blocked, not merely unwritten.** Upstream reads the user's music
   collection by opening a *second* Tracker connection to the session-wide
   indexer/localsearch bus (`Tracker.SparqlConnection.bus_new`) and querying
   it via Grilo's `grl-tracker3` source. `core_grilo.rb` and
   `tracker_store.rb` both document, with the exact binding gap found by
   reading the gem source: `Tsparql::SparqlConnection.bus_new_async`'s block
   hands back a bare `Gio::Task` with no `bus_new_finish` anywhere in the
   `tsparql` gem, so the bus connection cannot be obtained through this
   binding as it stands. `tracker_store.rb` instead opens the port's own
   **local** Tracker database with the synchronous `SparqlConnection.new`
   constructor (a real, working GI call) and uses it only for the
   favorite-tag writeback. `core_model.rb` therefore still has no real
   music-collection data source — this is the single largest open question
   carried forward from the previous survey, now narrowed to one named
   binding gap instead of "no Grilo/Tracker bindings at all" (both gems do
   load and are used for real elsewhere: Grilo for cover-source lookup,
   Tsparql for the local favorite tag).
4. **MPRIS2** (`gnomemusic/mpris.py`) is still entirely unwritten — no
   `lib/mpris.rb`, no D-Bus interface registration anywhere in `lib/`. It
   needs a D-Bus story in Ruby (likely `Gio::DBusProxy`/`Gio::DBusExportedObject`
   via gio2, which is already a dependency); if it is dropped instead, say so
   explicitly rather than silently.
5. **GResource/GtkBuilder are not used by the port** by design, so the 33
   `.ui` trees are re-expressed as memoized widget methods — the mapping
   above is the contract for that, and it is now complete: every `.ui` file
   has a `lib/*.rb` counterpart.
6. **Translations were not built.** 74 `po/` catalogues exist upstream; the
   port has no gettext-equivalent marker anywhere in `lib/` or `exe/`, no
   `.po`/`.pot`/`.mo` file anywhere in the repository, and no catalogue
   infrastructure of any kind. This is not a scheduled later phase and not
   "out of scope" by any decision this port gets to make — upstream shipped
   74 languages, so upstream set the scope, and today's port ships English
   only, with every user-visible string a bare literal that a future pass
   would have to find and wrap by hand across `lib/*.rb`, because none of
   them carry a marker a wrapping step could search for. (`.reports/parity-translation-parity.md`
   from a previous pass covers this in more depth.)
7. **Binding quirks to respect** (see `.claude/skills/ruby-gtk`):
   `Adwaita::Application` is broken, so app actions and accelerators go on
   `Gtk::Application`; `Adwaita::NavigationPage.new(child, title)` is
   positional and needs its child first — relevant for the five navigation
   pages and `SearchView`; `Adwaita::Toast.new(message)` is positional.
