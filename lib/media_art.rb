# frozen_string_literal: true

require 'adwaita'
require 'gio2'
require 'libmediaart'
require_relative 'music_logger'

# Convenience helpers on top of the real MediaArt GObject Introspection
# bindings (gem `libmediaart`, typelib `MediaArt-2.0`).
#
# Upstream reaches the on-disk album/artist art cache through
# MediaArt.get_file, which computes the cache path for an artist/title pair
# under the Media Art Storage Spec, and through MediaArt::Process#uri, which
# scans a track's directory for a cover file and links it into that cache.
# gnomemusic/albumart.py, artistart.py and songart.py all call the former
# directly; the latter is reached through EmbeddedArt (lib/embedded_art.rb).
#
# An earlier round of this port hand-rolled both of those — the checksum
# path, the stripped/normalized name, the directory cover scan — because the
# dev shell carried no MediaArt typelib. The typelib and the `libmediaart`
# gem are both in the dev shell now (see flake.nix's gtkStack and the
# gemspec), so this file reopens the real MediaArt module instead of
# shadowing it with a reimplementation.
module MediaArt
  # The cache file MediaArt.get_file computes for an artist/title pair, or
  # nil when libmediaart could not compute one (no artist and no title).
  # `prefix` is "album" or "artist", MediaArt.get_file's third argument,
  # exactly as upstream calls it.
  def self.cache_file(artist, title, prefix)
    success, file = get_file(artist, title, prefix)

    if success
      file
    end
  end

  def self.cache_uri(artist, title, prefix) = cache_file(artist, title, prefix)&.uri
  def self.cache_path(artist, title, prefix) = cache_file(artist, title, prefix)&.path

  # The uri of the cached art for an artist/title pair, or nil when nothing
  # is cached yet.
  def self.cached_uri(artist, title, prefix)
    cache_file(artist, title, prefix).then do |file|
      if file&.query_exists
        file.uri
      end
    end
  end

  # Looks for a cover file in the directory the given track lives in and
  # links it into the cache, the way upstream's
  # `MediaArt.Process.uri_async(MediaArt.Type.ALBUM, ...)` does for a local
  # file. Returns the cache uri on success and nil when the track is not
  # local, its directory holds no cover, or the process call fails.
  def self.store_cover_from_directory(url, artist, title)
    if url.to_s.empty?
      nil
    else
      process.uri(Type::ALBUM, ProcessFlags::NONE, url, artist, title)
      cached_uri(artist, title, 'album')
    end
  rescue GLib::Error => e
    MusicLogger.new.warning(
      "Error: #{e.domain}, #{e.message} for album: #{title} by artist: #{artist}",
    )
    nil
  end

  # The shared MediaArt::Process instance every lookup scans directories
  # through, as upstream's EmbeddedArt keeps one for the app's lifetime.
  def self.process = @process ||= Process.new
end
