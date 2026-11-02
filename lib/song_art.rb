# frozen_string_literal: true

require 'adwaita'
require_relative 'media_art'
require_relative 'music_logger'

# SongArt is the song art retrieval object.
#
# Ported from upstream's gnomemusic/songart.py. A song's art is its album's
# art, so the lookup is the album lookup keyed on the song's own album and
# artist tags: the MediaArt cache first, then the cover file next to the song
# itself.
#
# As with AlbumArt, upstream's third source — a remote store reached through
# CoreGrilo — is not ported, because the Grilo bindings are not in this
# fork's dev shell.
class SongArt
  def initialize(coresong, logger: nil)
    @coresong = coresong
    @album = coresong.album
    @artist = coresong.artist
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
          @coresong.thumbnail = uri
        else
          from_directory
        end
      end
    end

    def from_directory
      MediaArt.store_cover_from_directory(@coresong.url, @artist, @album).then do |uri|
        if uri
          @coresong.thumbnail = uri
        end
      end
    rescue StandardError => e
      @log.warning("Error: #{e.class}, #{e.message} for album: #{@album} by artist: #{@artist}")
    end
end
