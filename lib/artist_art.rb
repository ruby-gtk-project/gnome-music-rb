# frozen_string_literal: true

require 'adwaita'
require_relative 'media_art'
require_relative 'music_logger'

# ArtistArt is the artist art retrieval object.
#
# Ported from upstream's gnomemusic/artistart.py: a CoreArtist asks for one
# the first time anybody reads its thumbnail, and it sets that thumbnail when
# the MediaArt cache holds a picture of the artist.
#
# Upstream falls back to a remote store through CoreGrilo when the cache is
# empty. That is the only other source an artist picture has — unlike album
# art, there is nothing on disk beside the music to read it from — and it
# needs the Grilo bindings this fork's dev shell does not carry, so the cache
# is all this looks at. Pictures another GNOME media application has already
# cached are found, and anything else leaves the artist on the placeholder.
class ArtistArt
  def initialize(coreartist, logger: nil)
    @coreartist = coreartist
    @artist = coreartist.artist
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
      MediaArt.cached_uri(@artist, nil, 'artist').then do |uri|
        if uri
          @coreartist.thumbnail = uri
        end
      end
    rescue StandardError => e
      @log.warning("Error: #{e.class}, #{e.message} for artist: #{@artist}")
    end
end
