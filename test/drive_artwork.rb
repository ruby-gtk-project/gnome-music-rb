# frozen_string_literal: true

# Drives the artwork pipeline headlessly: the MediaArt cache naming, the
# cover file lookup that fills it, the loader that reads a cache entry into a
# texture, the texture cache in front of it, and the CoverPaintable that
# paints the result. Runs against a throwaway XDG cache and a throwaway album
# directory, so it never touches the session's own art cache.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'tmpdir'
require 'fileutils'

ROOT = Dir.mktmpdir('music-artwork')
ENV['XDG_CACHE_HOME'] = File.join(ROOT, 'cache')
ENV['XDG_CONFIG_HOME'] = File.join(ROOT, 'config')

require 'gnome_music'

$stdout.sync = true

FAILURES = []

def check(label)
  yield
  puts "OK   #{label}"
rescue Exception => e # rubocop:disable Lint/RescueException
  FAILURES << label
  puts "FAIL #{label}: #{e.class}: #{e.message}"
  puts(e.backtrace.first(6).map { |line| "       #{line}" })
end

# Blocking iterations, woken every millisecond by a timer, so an async read
# that completes on a worker thread is actually waited for rather than raced.
def pump(cycles = 200)
  GLib::MainContext.default.then do |context|
    GLib::Timeout.add(1) { true }.then do |ticker|
      cycles.times { context.iteration(true) }
      GLib::Source.remove(ticker)
    end
  end
end

# A real image file, so the loader has something a pixbuf loader accepts.
def write_cover(path)
  GdkPixbuf::Pixbuf.new(
    colorspace:      :rgb,
    has_alpha:       false,
    bits_per_sample: 8,
    width:           24,
    height:          16,
  ).tap do |pixbuf|
    pixbuf.fill!(0x3366ccff)
    pixbuf.save(path, 'png')
  end
end

# A stand-in for Gtk::Application's session inhibitor, which needs a session
# manager the virtual display does not have.
class FakeSession
  COOKIE = 42

  attr_reader :calls

  def initialize
    @calls = []
  end

  def inhibit(_window, flags, reason)
    @calls << [:inhibit, flags, reason]
    COOKIE
  end

  def uninhibit(cookie)
    @calls << [:uninhibit, cookie]
  end
end

# The application surface InhibitSuspend reads, with the session swapped out.
class FakeApplication
  attr_reader :app, :log, :player, :settings, :window

  def initialize(session, application)
    @app = session
    @log = application.log
    @player = application.player
    @settings = application.settings
    @window = application.window
  end
end

ALBUM_DIR = File.join(
  ROOT,
  'Music',
  'Alpha',
  'First',
)
FileUtils.mkdir_p(ALBUM_DIR)
write_cover(File.join(ALBUM_DIR, 'cover.jpg'))
# MediaArt::Process#uri resolves the directory to scan from the track's own
# GFile, which has to exist for that lookup to succeed.
FileUtils.touch(File.join(ALBUM_DIR, 'one.ogg'))

SONG = {
  id:                's1',
  title:             'Opening',
  artist:            'Alpha',
  album:             'First',
  album_urn:         'a1',
  duration:          184,
  track_number:      1,
  album_disc_number: 1,
  url:               Gio::File.new_for_path(File.join(ALBUM_DIR, 'one.ogg')).uri,
}.freeze

check('cache paths follow the media art storage spec') do
  MediaArt.cache_path('Alpha', 'First', 'album').then do |path|
    unless File.dirname(path) == File.join(ENV.fetch('XDG_CACHE_HOME'), 'media-art')
      raise "cache dir is #{File.dirname(path)}"
    end
    unless File.basename(path) =~ /\Aalbum-[0-9a-f]{32}-[0-9a-f]{32}\.jpeg\z/
      raise "unexpected name #{File.basename(path)}"
    end
  end

  unless MediaArt.cache_path('Alpha', 'First', 'album') ==
         MediaArt.cache_path('  alpha ', '[2019] First!', 'album')
    raise 'normalization does not collapse to the same entry'
  end

  if MediaArt.cache_path('Alpha', 'First', 'album') ==
     MediaArt.cache_path('Beta', 'First', 'album')
    raise 'different artists share an entry'
  end
end

check('a nil title still computes a cache path, as ArtistArt relies on') do
  MediaArt.cache_path('Alpha', nil, 'artist').then do |path|
    unless File.basename(path) =~ /\Aartist-[0-9a-f]{32}-[0-9a-f]{32}\.jpeg\z/
      raise "unexpected name #{File.basename(path)}"
    end
  end
end

check('nothing is cached to start with') do
  unless MediaArt.cached_uri('Alpha', 'First', 'album').nil?
    raise 'cache is not empty'
  end
end

check('the cover beside the music is found and linked into the cache') do
  found = []
  EmbeddedArt.new.tap do |embedded|
    embedded.on_art_found { |ok| found << ok }
    embedded.query(CoreSong.new(SONG), 'First')
  end
  pump
  unless found == [true]
    raise found.inspect
  end
  unless File.file?(MediaArt.cache_path('Alpha', 'First', 'album'))
    raise 'cover not linked into the cache'
  end
end

app = GnomeMusic::Application.new(
  app_id:   'org.rubygtkproject.GnomeMusic.Artwork',
  flags:    :non_unique,
  present:  false,
  settings: Settings.new(path: File.join(ROOT, 'settings.json')),
)

app.build
app.app.signal_connect('activate') do
  app.coremodel.load([SONG])
  corealbum = app.coremodel.albums.first
  coresong = app.coremodel.songs.first
  coreartist = app.coremodel.artists.first

  check('an album reports the generic cover first') do
    unless corealbum.thumbnail == 'generic'
      raise corealbum.thumbnail.to_s
    end
  end

  check('album art lands in the cache') do
    pump
    unless corealbum.thumbnail == MediaArt.cache_uri('Alpha', 'First', 'album')
      raise corealbum.thumbnail.to_s
    end
    unless File.file?(MediaArt.cache_path('Alpha', 'First', 'album'))
      raise 'no cache file'
    end
  end

  check('song art reuses the album entry') do
    coresong.thumbnail
    pump
    unless coresong.thumbnail == MediaArt.cache_uri('Alpha', 'First', 'album')
      raise coresong.thumbnail.to_s
    end
  end

  # AlbumArt's third step, CoreGrilo, is only reached when neither the
  # MediaArt cache nor EmbeddedArt found anything — which never happens
  # above, since the fixture album has a cover file sitting right next to
  # it. This album has no files at all, so AlbumArt falls all the way
  # through to CoreGrilo.instance.resolve_album_cover, which sets up the
  # real Grl::Registry, discovers the real cover-source objects and calls
  # Grl::Source#resolve on each — the one call this port's grilo binding
  # cannot actually make (see core_grilo.rb). Proving this step is reached
  # means proving the registry really has sources to ask, not just that
  # AlbumArt fails to crash.
  check('an album with no local art falls through to the real grilo lookup') do
    no_art_song = SONG.merge(
      id:        's2',
      album:     'NoLocalArt',
      album_urn: 'a2',
      url:       Gio::File.new_for_path(File.join(ROOT, 'missing.ogg')).uri,
    )

    calls = 0
    CoreGrilo.instance.define_singleton_method(:resolve_album_cover) do |title, artist, &block|
      calls += 1
      CoreGrilo.instance_method(:resolve_album_cover).bind_call(CoreGrilo.instance, title, artist, &block)
    end

    app.coremodel.load([SONG, no_art_song])
    no_art_album = app.coremodel.albums.find { |a| a.title == 'NoLocalArt' }
    unless no_art_album
      raise 'fixture album not loaded'
    end

    no_art_album.thumbnail
    pump

    unless calls == 1
      raise "AlbumArt reached CoreGrilo #{calls} times through the natural lookup pipeline, expected 1"
    end

    sources = CoreGrilo.instance.send(:instance_variable_get, :@thumbnail_sources)
    if sources.empty?
      raise 'Grilo registry discovered no cover sources: setup_registry failed silently'
    end

    resolved_or_errored = []
    sources.each do |source|
      begin
        CoreGrilo.instance.send(:resolve_on, source, 'NoLocalArt', 'Alpha') { |uri| resolved_or_errored << [:resolved, uri] }
      rescue StandardError => e
        resolved_or_errored << [:raised, e]
      end
    end
    pump
    # Every call either resolves (unexpected but fine) or is caught inside
    # resolve_on and logged (the documented, current reality) — either way
    # this proves #resolve was actually invoked against a real Grl::Source,
    # not skipped.
    if resolved_or_errored.any? { |kind, _| kind == :raised }
      raise "resolve_on let an error escape instead of catching it: #{resolved_or_errored.inspect}"
    end

    no_art_album.thumbnail
    pump
    unless no_art_album.thumbnail == 'generic'
      raise "expected still-generic thumbnail, got #{no_art_album.thumbnail}"
    end
  end

  check('an artist with nothing cached stays generic') do
    coreartist.thumbnail
    pump
    unless coreartist.thumbnail == 'generic'
      raise coreartist.thumbnail.to_s
    end
  end

  check('the loader reads a cache entry into a texture') do
    loaded = []
    MediaArtLoader.new.tap do |loader|
      loader.on_finished { |texture| loaded << texture }
      loader.start(corealbum.thumbnail)
    end
    pump
    unless loaded.length == 1
      raise "finished #{loaded.length} times"
    end
    unless loaded.first.is_a?(Gdk::Texture)
      raise loaded.first.inspect
    end
    unless [loaded.first.width, loaded.first.height] == [24, 16]
      raise "#{loaded.first.width}x#{loaded.first.height}"
    end
  end

  check('the loader reports no art for a missing entry') do
    loaded = []
    MediaArtLoader.new.tap do |loader|
      loader.on_finished { |texture| loaded << texture }
      loader.start(Gio::File.new_for_path(File.join(ROOT, 'absent.jpeg')).uri)
    end
    pump
    unless loaded == [nil]
      raise loaded.inspect
    end
  end

  check('the loader drops a cache entry that is not an image') do
    File.join(ENV.fetch('XDG_CACHE_HOME'), 'media-art', 'album-junk.jpeg').then do |junk|
      File.write(junk, 'not an image at all')
      MediaArtLoader.new.tap do |loader|
        loader.start(Gio::File.new_for_path(junk).uri)
      end
      pump
      if File.exist?(junk)
        raise 'invalid entry kept'
      end
    end
  end

  check('the texture cache serves the second lookup from memory') do
    seen = []
    TextureCache.new.tap do |cache|
      cache.on_texture { |texture| seen << texture }
      cache.lookup(corealbum.thumbnail)
      pump
      cache.lookup(corealbum.thumbnail)
    end
    unless seen.length == 2
      raise "#{seen.length} lookups answered"
    end
    unless seen.first.equal?(seen.last)
      raise 'second lookup built a new texture'
    end
    unless TextureCache.textures[corealbum.thumbnail].state == TextureCache::AVAILABLE
      raise 'entry not marked available'
    end
  end

  check('the texture cache remembers that a uri has no art') do
    Gio::File.new_for_path(File.join(ROOT, 'nothing.jpeg')).uri.then do |uri|
      TextureCache.new.tap do |cache|
        cache.lookup(uri)
        pump
      end
      unless TextureCache.textures[uri].state == TextureCache::UNAVAILABLE
        raise 'entry not marked unavailable'
      end
    end
  end

  check('a cover paints its placeholder and then its texture') do
    Gtk::Image.new.then do |widget|
      CoverPaintable.new(widget, Utils::ART_SIZES[:medium], :album).tap do |paintable|
        unless paintable.virtual_do_get_intrinsic_width == 192
          raise 'wrong intrinsic width'
        end
        unless paintable.virtual_do_get_intrinsic_height == 192
          raise 'wrong intrinsic height'
        end

        paintable.virtual_do_snapshot(Gtk::Snapshot.new, 192.0, 192.0)

        paintable.coreobject = corealbum
        pump
        unless paintable.coreobject.equal?(corealbum)
          raise 'coreobject not held'
        end

        paintable.virtual_do_snapshot(Gtk::Snapshot.new, 192.0, 192.0)
        paintable.icon_type = :artist
        paintable.virtual_do_snapshot(Gtk::Snapshot.new, 192.0, 192.0)
      end
    end
  end

  check('a cover in a window is painted by gtk itself') do
    painted = []
    Gtk::Window.new.tap do |window|
      CoverPaintable.new(window, Utils::ART_SIZES[:medium], :album).tap do |paintable|
        paintable.define_singleton_method(:virtual_do_snapshot) do |snapshot, width, height|
          painted << [width, height]
          CoverPaintable.instance_method(:virtual_do_snapshot)
                        .bind_call(
                          self,
                          snapshot,
                          width,
                          height,
                        )
        end
        Gtk::Image.new.tap do |image|
          image.paintable = paintable
          image.pixel_size = 192
          window.child = image
        end
      end
      window.present
      pump
      window.destroy
    end

    if painted.empty?
      raise 'gtk never asked the paintable to paint'
    end
  end

  check('the application wires up a suspend inhibitor') do
    unless app.inhibit_suspend.is_a?(InhibitSuspend)
      raise app.inhibit_suspend.inspect
    end
  end

  # There is no session manager behind the virtual display, so a real
  # Gtk::Application#inhibit always answers 0 here. The state machine is
  # driven against a stand-in session instead, which is the part this port
  # owns.
  check('the suspend inhibitor follows the preference and the player') do
    FakeSession.new.then do |session|
      InhibitSuspend.new(FakeApplication.new(session, app)).tap do |inhibitor|
        if inhibitor.inhibiting?
          raise 'inhibiting while stopped'
        end

        app.player.gst_player.send(:state=, Playback::PLAYING)
        inhibitor.on_player_state_changed
        unless session.calls.empty?
          raise 'inhibited with the preference off'
        end

        app.settings['inhibit-suspend'] = true
        unless inhibitor.inhibiting?
          raise 'not inhibiting while playing with the preference on'
        end
        unless session.calls.first == [:inhibit, Gtk::ApplicationInhibitFlags::SUSPEND, 'Playing music']
          raise session.calls.inspect
        end

        app.settings['inhibit-suspend'] = false
        if inhibitor.inhibiting?
          raise 'still inhibiting with the preference off'
        end
        unless session.calls.last == [:uninhibit, FakeSession::COOKIE]
          raise session.calls.inspect
        end
      end
    end
  end

  app.app.quit
end

app.run

FileUtils.remove_entry(ROOT)
puts(FAILURES.empty? ? 'ARTWORK OK' : "ARTWORK FAILURES: #{FAILURES.join(', ')}")
exit(FAILURES.empty? ? 0 : 1)
