# frozen_string_literal: true

require 'adwaita'
require_relative 'embedded_art'
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
# two are here. The remote store is not, because it hangs off CoreGrilo,
# which needs a Tracker-backed Grilo source this port does not have yet.
#
# Upstream's five-per-second limiter is an asyncio rate limiter; here the
# cache lookup is deferred to an idle callback, so a view that builds two
# hundred covers at once never stats two hundred cache paths inside one
# frame, and EmbeddedArt's own directory scan is deferred the same way.
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
          from_embedded_art
        end
      end
    end

    # Upstream retries the cache after EmbeddedArt reports success, since
    # EmbeddedArt itself just wrote the file the cache lookup now finds.
    def from_embedded_art
      EmbeddedArt.new(logger: @log).tap do |embedded|
        embedded.on_art_found do |found|
          if found
            in_cache
          end
        end
        embedded.query(@corealbum, @album)
      end
    end
end
