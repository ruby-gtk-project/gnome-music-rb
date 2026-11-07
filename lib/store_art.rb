# frozen_string_literal: true

require 'adwaita'
require 'fileutils'
require 'gdk_pixbuf2'
require 'soup3'
require_relative 'media_art'
require_relative 'music_logger'

# StoreArt stores a remote cover at a uri into the MediaArt cache.
#
# Ported from upstream's gnomemusic/storeart.py: given a CoreAlbum,
# CoreArtist or CoreSong and a remote art uri, it downloads the image with
# Soup, decodes it, re-encodes it as a jpeg and writes it into the cache at
# the path MediaArt.get_file computes for that object, then sets the
# object's thumbnail to the cached file's uri.
#
# Upstream fetches with `Soup.Session#send_and_read_async` and decodes with
# `GdkPixbuf.Pixbuf.new_from_stream_async`. The Ruby bindings carry the
# former (gem `soup3`) but not a usable async decode: `GdkPixbuf::Pixbuf`
# defines `new_from_stream_async` but no matching `_finish` method, and the
# `Gio::Task` the async call hands back only exposes `propagate_pointer`,
# which returns a raw, unwrapped pointer integer with nothing in the
# bindings to turn it back into a `GdkPixbuf::Pixbuf`. The bytes are already
# fully buffered in memory by the time Soup's callback runs, so the decode
# here goes through `GdkPixbuf::PixbufLoader` fed the whole byte string at
# once, which is synchronous but does no further I/O — the GTK media
# loaders elsewhere in this port (see MediaArtLoader) make the same
# trade-off once their bytes are in hand.
#
# Upstream's ten-way asyncio semaphore limiting concurrent downloads is not
# ported: nothing in this port yet calls #start from a context where two
# hundred lookups would fire at once (CoreGrilo, which would drive this from
# search results and artist/album detail pages, is not ported either).
#
# This class works on its own — loaded standalone and driven through a
# throwaway Soup server and GLib main loop, #start correctly fetches,
# decodes, re-encodes and caches a remote image. It is deliberately NOT
# required from lib/main.rb, i.e. not loaded into the running application:
# doing so (`require 'soup3'` anywhere before the app's GTK main loop runs)
# makes the app segfault later, deep in unrelated code
# (lib/playlist_toast.rb's `@coremodel.refresh_user_playlists`), reproduced
# three times in a row with a plain `require 'soup3'` and no StoreArt
# instance ever created. That shape — a crash far from the code that
# triggered it — is the signature of memory corruption, and it tracks with
# the trap flake.nix already documents for this app's binding gems: typelibs
# have to come from one nixpkgs or GObject registers a type twice. Whatever
# the exact cause, `soup3` cannot be loaded inside this process yet, so
# nothing in lib/ requires this file. A future CoreGrilo port, which is what
# would actually call #start, needs that interaction root-caused first.
class StoreArt
  def initialize(logger: nil)
    @log = logger || MusicLogger.new
    @session = Soup::Session.new
    @finished_listeners = []
  end

  # Registers a listener for the end of the store, called with no
  # arguments, matching upstream's "finished" signal.
  def on_finished(&block)
    @finished_listeners << block
    block
  end

  # Starts storing the art at `uri` for `coreobject`, a CoreAlbum,
  # CoreArtist or CoreSong. `coreobjecttype` is one of
  # Utils::CORE_OBJECT_TYPES (:album, :artist or :song).
  def start(coreobject, uri, coreobjecttype)
    @coreobject = coreobject
    @artist = coreobject.artist
    @album, prefix = album_and_prefix(coreobjecttype)

    if uri.to_s.empty?
      finish
    else
      success, file = MediaArt.get_file(@artist, @album, prefix)

      if success
        @file = file
        fetch(uri)
      else
        finish
      end
    end
  end

  private

    def album_and_prefix(coreobjecttype)
      case coreobjecttype
      when :album then [@coreobject.title, 'album']
      when :song then [@coreobject.album, 'album']
      else [nil, 'artist']
      end
    end

    def fetch(uri)
      Soup::Message.new('GET', uri).then do |message|
        @session.send_and_read_async(message, GLib::PRIORITY_DEFAULT, nil) do |source, result|
          begin
            save(source.send_and_read_finish(result))
          rescue GLib::Error => e
            @log.debug(
              "Failed to get remote art: #{e.domain}, #{e.message} for album: " \
              "#{@album} by artist: #{@artist}",
            )
            finish
          end
        end
      end
    end

    def save(gbytes)
      decode(gbytes).then do |pixbuf|
        if pixbuf
          write(pixbuf)
        else
          finish
        end
      end
    end

    def decode(gbytes)
      GdkPixbuf::PixbufLoader.new.tap do |loader|
        loader.write(gbytes.to_s)
        loader.close
      end.pixbuf
    rescue GLib::Error => e
      @log.warning("Error: #{e.domain}, #{e.message}")
      nil
    end

    def write(pixbuf)
      if @file.query_exists
        # File already exists: another concurrent lookup won the race.
        finish
      else
        _, buffer = pixbuf.save_to_bufferv('jpeg', [], [])
        FileUtils.mkdir_p(File.dirname(@file.path))
        File.binwrite(@file.path, buffer.pack('C*'))
        @coreobject.thumbnail = @file.uri
        finish
      end
    rescue GLib::Error, SystemCallError => e
      @log.warning(
        "Error: #{e.class}, #{e.message} for album: #{@album} by artist: #{@artist}",
      )
      finish
    end

    def finish
      @finished_listeners.dup.each(&:call)
    end
end
