# frozen_string_literal: true

require 'adwaita'
require_relative 'media_art'
require_relative 'music_logger'

# AlbumArt is the album art retrieval object.
#
# Ported from upstream's gnomemusic/albumart.py: a CoreAlbum asks for one the
# first time anybody reads its thumbnail, and it sets that thumbnail as soon
# as it has found art for the album.
#
# Upstream looks in three places in turn: the MediaArt cache, the album's own
# files through EmbeddedArt, and a remote store through CoreGrilo. The first
# two are here — the cache, and the cover file sitting in the album's
# directory, which is the half of EmbeddedArt that does not need GStreamer's
# tag readers. The remote store is not: it hangs off CoreGrilo, which needs
# the Grilo bindings this fork's dev shell does not carry.
#
# Upstream's five-per-second limiter is a asyncio rate limiter; here the
# lookup is deferred to an idle callback, so a view that builds two hundred
# covers at once never stats two hundred directories inside one frame.
class AlbumArt
  def initialize(corealbum, logger: nil)
    @corealbum = corealbum
    @album = corealbum.title
    @artist = corealbum.artist
    @log = logger || MusicLogger.new

    schedule
  end

  private

    def schedule
      GLib::Idle.add do
        in_cache
        false
      end
    end

    def in_cache
      MediaArt.cached_uri(@artist, @album, 'album').then do |uri|
        if uri
          @corealbum.thumbnail = uri
        else
          from_directory
        end
      end
    end

    def from_directory
      MediaArt.store_cover_from_directory(@corealbum.url, @artist, @album).then do |uri|
        if uri
          @corealbum.thumbnail = uri
        end
      end
    rescue StandardError => e
      @log.warning("Error: #{e.class}, #{e.message} for album: #{@album} by artist: #{@artist}")
    end
end
