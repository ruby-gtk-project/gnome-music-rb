# frozen_string_literal: true

require 'adwaita'

# Utils holds the small helpers shared across the port.
#
# Ported from upstream's gnomemusic/utils.py: the ArtSize, RepeatMode,
# SongStateIcon, View, DefaultIconType and CoreObjectType enumerations, the
# title/artist fallbacks, the mm:ss formatter and the natural-order comparison
# used by every sorter.
#
# Upstream's enums are Python Enum classes; here they are frozen value objects
# and constant lookups, which is as far as Ruby needs to go.
module Utils
  # Icon sizes, in pixels. Upstream's ArtSize carries width and height.
  ArtSize = Data.define(:width, :height)

  ART_SIZES = {
    xsmall: ArtSize.new(width: 42, height: 42),
    small:  ArtSize.new(width: 74, height: 74),
    medium: ArtSize.new(width: 192, height: 192),
    large:  ArtSize.new(width: 256, height: 256),
  }.freeze

  # The type of CoreObject a caller was handed, upstream's CoreObjectType.
  CORE_OBJECT_TYPES = %i[album artist song].freeze

  # The placeholder icons shown until artwork arrives, upstream's
  # DefaultIconType.
  DEFAULT_ICONS = {
    album:  'folder-music-symbolic',
    artist: 'music-artist-symbolic',
  }.freeze

  # The icons the song rows use for playback and validation state, upstream's
  # SongStateIcon.
  SONG_STATE_ICONS = {
    error:   'dialog-error-symbolic',
    playing: 'media-playback-start-symbolic',
  }.freeze

  # The three main views, in the order the view switcher shows them.
  # Upstream's View IntEnum.
  VIEWS = %i[album artist playlist].freeze

  # RepeatMode carries the value stored in settings, the icon the repeat
  # button shows and the label its menu lists — upstream packs the same three
  # into one Enum member.
  class RepeatMode
    attr_reader :value, :nick, :icon, :label

    def initialize(value, nick, icon, label)
      @value = value
      @nick = nick
      @icon = icon
      @label = label
    end

    # Translators: "shuffle" causes tracks to play in random order.
    NONE = new(
      0,
      'none',
      'media-playlist-consecutive-symbolic',
      'Shuffle/Repeat Off',
    )
    SONG = new(
      1,
      'song',
      'media-playlist-repeat-song-symbolic',
      'Repeat Song',
    )
    ALL = new(
      2,
      'all',
      'media-playlist-repeat-symbolic',
      'Repeat All',
    )
    SHUFFLE = new(
      3,
      'shuffle',
      'media-playlist-shuffle-symbolic',
      'Shuffle',
    )

    ALL_MODES = [NONE, SONG, ALL, SHUFFLE].freeze

    def self.from_value(value) = ALL_MODES.find { |mode| mode.value == value } || NONE
    def self.from_nick(nick) = ALL_MODES.find { |mode| mode.nick == nick.to_s } || NONE

    def to_s = @nick
  end

  # Observable is what this port uses where upstream relies on GObject
  # properties and bind_property.
  #
  # The Ruby bindings cannot install GObject properties on a Ruby subclass of
  # GLib::Object, so there is nothing for bind_property to bind to. Callers
  # register a block instead and the setter announces the change by name,
  # which covers every binding upstream sets up on the core objects.
  module Observable
    # Registers a listener. The block is called with the name of the property
    # that changed, so one listener can watch a whole object.
    def on_notify(&block)
      observers << block
      block
    end

    def off_notify(block)
      observers.delete(block)
    end

    def notify_property(name)
      observers.dup.each { |observer| observer.call(name) }
    end

    def observers = @observers ||= []
  end

  # The preferred artist for a media item: the album artist if there is one,
  # the track artist otherwise, and a placeholder when neither is known.
  def self.artist_from(fields)
    [fields[:album_artist], fields[:artist]]
      .map { |value| value.to_s.strip }
      .find { |value| !value.empty? } || 'Unknown Artist'
  end

  # The title of a media item. Upstream falls back to the file's display name
  # with underscores turned into spaces when the tags carry no title.
  def self.title_from(fields)
    fields[:title].to_s.strip.then do |title|
      if title.empty?
        title_from_url(fields[:url])
      else
        title
      end
    end
  end

  def self.title_from_url(url)
    url.to_s.strip.then do |uri|
      if uri.empty?
        'NO URL'
      else
        File.basename(Gio::File.new_for_uri(uri).parse_name).tr('_', ' ')
      end
    end
  end

  # Converts a time in seconds to a mm:ss string.
  def self.seconds_to_string(duration)
    duration.to_i.abs.then do |seconds|
      format('%<minutes>d:%<seconds>02d', minutes: seconds / 60, seconds: seconds % 60)
    end
  end

  # A normalized, casefolded version of a string, so names with accents sort
  # and compare the way a reader expects.
  def self.normalize_caseless(text)
    text.to_s.unicode_normalize(:nfkd).downcase
  end

  # Natural order comparison of two strings: "Album 3" sorts before
  # "Album 10". Returns a Gtk::Ordering value, as upstream does.
  def self.natural_sort_names(name_a, name_b)
    extract_numbers(name_a).then do |extract_a|
      extract_numbers(name_b).then do |extract_b|
        compare_extracts(extract_a, extract_b)
      end
    end
  end

  # Splits a string into a list of strings and integers, so the integers are
  # compared as numbers.
  def self.extract_numbers(text)
    normalize_caseless(text).split(/(\d+)/).map do |part|
      if part.match?(/\A\d+\z/)
        [1, part.to_i, '']
      else
        [0, 0, part]
      end
    end
  end

  def self.compare_extracts(extract_a, extract_b)
    (extract_a <=> extract_b).then do |result|
      case result
      when nil, 0 then Gtk::Ordering::EQUAL
      when -1 then Gtk::Ordering::SMALLER
      else Gtk::Ordering::LARGER
      end
    end
  end

  # A numeric field from a tag hash, or zero when it is missing or empty.
  def self.int_from(fields, field)
    fields[field].to_i
  end
end
