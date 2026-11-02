# frozen_string_literal: true

require 'adwaita'
require 'digest'
require 'fileutils'

# MediaArt is the on-disk album and artist art cache, and the local cover
# lookup that fills it.
#
# Upstream reaches both through the libmediaart library's GObject bindings
# (MediaArt 2.0): MediaArt.get_file computes the cache path for an
# artist/album pair, and MediaArt.Process.uri_async scans a track's directory
# for a cover file and links it into that cache. There is no MediaArt typelib
# in this fork's dev shell and no Ruby binding for it, so both are
# implemented here against the Media Art Storage Spec libmediaart itself
# follows:
#
#   $XDG_CACHE_HOME/media-art/<prefix>-<md5(artist)>-<md5(title)>.jpeg
#
# where each name is stripped of bracketed blocks and punctuation, has its
# whitespace runs collapsed, and is lowercased and NFKD normalized before
# hashing; an absent name hashes a single space. Files another GNOME media
# application has already cached are therefore found here too.
module MediaArt
  # The file names libmediaart treats as a directory's cover, in the order it
  # prefers them.
  COVER_NAMES = %w[
    cover
    front
    folder
    albumart
    album
    .folder
  ].freeze

  COVER_EXTENSIONS = %w[jpeg jpg png].freeze

  # The punctuation the storage spec removes outright.
  INVALID_CHARACTERS = /[()_{}\[\]!@#$^&*+=|\\\/"'?<>~`]/
  BRACKETED_BLOCKS = /\([^)]*\)|\{[^}]*\}|\[[^\]]*\]|<[^>]*>/

  # The cache directory, created on demand.
  def self.cache_dir
    File.join(GLib.user_cache_dir, 'media-art')
  end

  # The path the given artist/title pair caches its art at. `prefix` is
  # "album" or "artist", as upstream's MediaArt.get_file calls are.
  def self.cache_path(artist, title, prefix)
    File.join(cache_dir, "#{prefix}-#{checksum(artist)}-#{checksum(title)}.jpeg")
  end

  def self.cache_uri(artist, title, prefix)
    Gio::File.new_for_path(cache_path(artist, title, prefix)).uri
  end

  # The uri of the cached art for the pair, or nil when nothing is cached.
  def self.cached_uri(artist, title, prefix)
    cache_path(artist, title, prefix).then do |path|
      if File.file?(path) && File.size(path).positive?
        Gio::File.new_for_path(path).uri
      end
    end
  end

  # Looks for a cover file in the directory the given track lives in and
  # copies it into the cache, which is what MediaArt.Process.uri_async does
  # for a local file. Returns the cache uri on success and nil when the track
  # is not local or its directory holds no cover.
  def self.store_cover_from_directory(url, artist, title)
    directory_cover(url).then do |cover|
      if cover
        copy_into_cache(cover, cache_path(artist, title, 'album'))
      end
    end
  end

  # The first cover file in the directory of the given track uri, or nil.
  def self.directory_cover(url)
    track_directory(url).then do |directory|
      if directory
        preferred_cover(directory, entries_by_name(directory))
      end
    end
  end

  # The candidate cover names, in the order libmediaart prefers them.
  def self.cover_file_names
    COVER_NAMES.flat_map { |name| COVER_EXTENSIONS.map { |ext| "#{name}.#{ext}" } }
  end

  # The directory's entries keyed by their lowercased name, so a cover is
  # found whatever case it was written in.
  def self.entries_by_name(directory)
    Dir.children(directory).to_h { |entry| [entry.downcase, entry] }
  rescue SystemCallError
    {}
  end

  def self.preferred_cover(directory, entries)
    cover_file_names.lazy
                    .map { |name| entries[name] }
                    .compact
                    .map { |entry| File.join(directory, entry) }
                    .find { |path| File.file?(path) && File.size(path).positive? }
  end

  # The normalized checksum of one name, per the storage spec.
  def self.checksum(text)
    strip_invalid_entities(text).then do |stripped|
      if stripped.empty?
        Digest::MD5.hexdigest(' ')
      else
        Digest::MD5.hexdigest(stripped)
      end
    end
  end

  # Removes bracketed blocks and punctuation, collapses whitespace runs, then
  # lowercases and NFKD normalizes, as libmediaart's
  # media_art_strip_invalid_entities does.
  def self.strip_invalid_entities(text)
    text.to_s
        .gsub(BRACKETED_BLOCKS, ' ')
        .gsub(INVALID_CHARACTERS, '')
        .gsub(/\s+/, ' ')
        .strip
        .downcase
        .unicode_normalize(:nfkd)
  end

  # The local directory a track uri lives in, or nil when the uri is not a
  # local file.
  def self.track_directory(url)
    url.to_s.then do |uri|
      if uri.empty?
        nil
      else
        local_parent(uri)
      end
    end
  end

  def self.copy_into_cache(source, destination)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(source, destination)
    Gio::File.new_for_path(destination).uri
  rescue SystemCallError
    nil
  end

  def self.local_parent(uri)
    Gio::File.new_for_uri(uri).parent.then do |parent|
      if parent&.path && File.directory?(parent.path)
        parent.path
      end
    end
  rescue StandardError
    nil
  end
end
