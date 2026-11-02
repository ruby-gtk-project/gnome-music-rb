# frozen_string_literal: true

# Drives the port headlessly: opens the window, injects a small collection so
# the real views are built, walks the album and artist pages, opens each
# dialog and exercises the playlists view.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'tmpdir'
require 'gnome_music'

FAILURES = []

def check(label)
  yield
  puts "OK   #{label}"
rescue Exception => e # rubocop:disable Lint/RescueException
  FAILURES << label
  puts "FAIL #{label}: #{e.class}: #{e.message}"
  puts(e.backtrace.first(6).map { |line| "       #{line}" })
end

SONGS = [
  {
    id:                's1',
    title:             'Opening',
    artist:            'Alpha',
    album:             'First',
    album_urn:         'a1',
    duration:          184,
    track_number:      1,
    album_disc_number: 1,
    url:               'file:///tmp/one.ogg',
    play_count:        3,
    added:             Time.now.utc,
    publication_date:  '2019',
  },
  {
    id:                's2',
    title:             'Second',
    artist:            'Alpha',
    album:             'First',
    album_urn:         'a1',
    duration:          201,
    track_number:      2,
    album_disc_number: 1,
    url:               'file:///tmp/two.ogg',
    play_count:        0,
    added:             Time.now.utc,
  },
  {
    id:                's3',
    title:             'Ballad',
    artist:            'Beta',
    album:             'Second',
    album_urn:         'a2',
    duration:          240,
    track_number:      1,
    album_disc_number: 2,
    url:               'file:///tmp/three.ogg',
    play_count:        9,
    favorite:          true,
    added:             Time.now.utc,
  },
].freeze

app = GnomeMusic::Application.new(
  app_id:   'org.rubygtkproject.GnomeMusic.Smoke',
  flags:    :non_unique,
  settings: Settings.new(path: File.join(Dir.mktmpdir, 'settings.json')),
)

app.build
app.app.signal_connect('activate') do
  # The window shows the welcome page once the startup timeout upstream uses
  # has fired, so the first checks wait for it.
  GLib::Timeout.add(1400) do
    window = app.window

    check('window is realized') do
      unless window.visible?
        raise 'no window'
      end
    end
    check('icon theme carries the port icons') do
      theme = Gtk::IconTheme.get_for_display(Gdk::Display.default)
      unless theme.has_icon?('music-artist-symbolic')
        raise 'music-artist-symbolic missing'
      end
    end
    check('playlists loaded') do
      unless app.coremodel.playlists_model.n_items >= 7
        raise 'no smart playlists'
      end
    end
    check('empty state is showing') do
      unless window.navigation_view.visible_page.tag == 'status'
        raise 'wrong page'
      end
    end

    check('collection loads') do
      app.coremodel.load(SONGS)
      unless app.coremodel.songs.length == 3
        raise 'songs missing'
      end
      unless app.coremodel.albums.length == 2
        raise 'albums missing'
      end
      unless app.coremodel.artists.length == 2
        raise 'artists missing'
      end
    end

    check('views are built') do
      unless app.window.views.key?('albums')
        raise 'no albums view'
      end
      unless app.window.views.key?('artists')
        raise 'no artists view'
      end
      unless app.window.views.key?('playlists')
        raise 'no playlists view'
      end
    end

    check('album page pushes') do
      page = AlbumNavigationPage.new(app, app.coremodel.albums.first).build
      window.navigation_view.push(page)
      window.navigation_view.pop
    end

    check('artist page pushes') do
      page = ArtistNavigationPage.new(app, app.coremodel.artists.first).build
      window.navigation_view.push(page)
      window.navigation_view.pop
    end

    check('search filters') do
      app.coremodel.search('ballad')
      unless app.coremodel.songs_search.n_items == 1
        raise "songs_search=#{app.coremodel.songs_search.n_items}"
      end
      app.coremodel.search('')
    end

    check('search mode switches pages') do
      app.search.search_mode_active = true
      unless window.navigation_view.visible_page.tag == 'searchview'
        raise 'not on search view'
      end
      app.search.search_mode_active = false
    end

    check('preferences dialog opens') do
      PreferencesDialog.new(app).build.present(window)
    end

    check('shortcuts dialog opens') { ShortcutsDialog.new.build.present(window) }
    check('about dialog opens') { AboutDialog.show('org.gnome.Music', '0.1.0', window) }

    check('playlist creation and song add') do
      playlist = app.playlists.create('Smoke Test')
      app.coremodel.set_playlists(app.playlists.playlists)
      app.coremodel.refresh_user_playlists
      playlist.add_songs([app.coremodel.songs.first])
      unless playlist.count == 1
        raise 'song not added'
      end
      playlist.title = 'Renamed'
      unless playlist.title == 'Renamed'
        raise 'not renamed'
      end
    end

    check('add to playlist dialog opens') do
      PlaylistDialog.new(app, app.coremodel.songs.first(1)).build.present(window)
    end

    check('song widget builds with a menu') do
      coresong = app.coremodel.songs.first
      widget = SongWidget.new(coresong, can_dnd: true, show_artist_and_album: true).build
      widget.menu = SongWidgetMenu.new(app, widget, app.coremodel.albums.first).build
      widget.state = SongWidget::PLAYING
    end

    check('queue fills from an album') do
      app.coremodel.active_core_object = app.coremodel.albums.first
      unless app.coremodel.queue_model.n_items == 2
        raise 'queue empty'
      end
    end

    check('repeat mode round trips through settings') do
      app.player.repeat_mode = Utils::RepeatMode::SHUFFLE
      unless app.settings['repeat'] == 'shuffle'
        raise 'not stored'
      end
      app.player.repeat_mode = Utils::RepeatMode::NONE
    end

    check('player toolbar reveals on state change') do
      app.window.set_player_visible(true)
    end

    app.app.quit
    false
  end
end

app.run

puts(FAILURES.empty? ? 'SMOKE OK' : "SMOKE FAILURES: #{FAILURES.join(', ')}")
exit(FAILURES.empty? ? 0 : 1)
