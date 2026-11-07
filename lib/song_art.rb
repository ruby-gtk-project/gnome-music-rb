# frozen_string_literal: true

require 'adwaita'
require_relative 'embedded_art'
require_relative 'media_art'
require_relative 'music_logger'

# SongArt is the song art retrieval object.
#
# Ported from upstream's gnomemusic/songart.py. A song's art is its album's
# art, so the lookup is the album lookup keyed on the song's own album and
# artist tags: the MediaArt cache first, then EmbeddedArt's directory scan.
#
# As with AlbumArt, upstream's third source — a remote store reached through
# CoreGrilo — is not ported, because CoreGrilo itself is not ported.
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
          from_embedded_art
        end
      end
    end

    def from_embedded_art
      EmbeddedArt.new(logger: @log).tap do |embedded|
        embedded.on_art_found do |found|
          if found
            in_cache
          end
        end
        embedded.query(@coresong, @album)
      end
    end
end
