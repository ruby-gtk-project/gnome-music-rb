# frozen_string_literal: true

require 'adwaita'
require_relative 'song_art'
require_relative 'utils'

# CoreSong carries everything the app knows about one song.
#
# Ported from upstream's gnomemusic/coresong.py. The fields are the ones
# upstream reads out of a Tracker cursor: album, album urn, disc number,
# artist, duration, id, play count, title, track number, url, the favorite
# tag and the last played timestamp.
#
# It is a GLib::Object subclass because it lives in a Gio::ListStore. The
# Ruby bindings cannot install GObject properties on a Ruby subclass, so the
# properties upstream binds to are plain accessors here and listeners come
# from Utils::Observable; see utils.rb.
class CoreSong < GLib::Object
  type_register

  include Utils::Observable

  # Song validation status, upstream's CoreSong.Validation.
  PENDING = 0
  IN_PROGRESS = 1
  FAILED = 2
  SUCCEEDED = 3

  attr_reader :id,
    :album,
    :album_urn,
    :album_disc_number,
    :artist,
    :duration,
    :play_count,
    :title,
    :track_number,
    :url,
    :fields

  def initialize(fields)
    super()

    @state = nil
    @validation = PENDING
    @favorite = false
    @last_played = nil
    @thumbnail = nil

    @id = fields[:id]
    update(fields)
  end

  # Two songs are the same song when they carry the same identifier, which is
  # what upstream's __eq__ compares.
  def ==(other) = other.is_a?(CoreSong) && other.id == @id
  alias eql? ==

  def hash = @id.hash

  def update(fields)
    @fields = fields
    @album = fields[:album].to_s
    @album_urn = fields[:album_urn]
    @album_disc_number = Utils.int_from(fields, :album_disc_number)
    @artist = Utils.artist_from(fields)
    @duration = Utils.int_from(fields, :duration)
    if fields[:favorite]
      @favorite = true
    else
      @favorite = false
    end
    @last_played = fields[:last_played]
    @play_count = Utils.int_from(fields, :play_count)
    @title = Utils.title_from(fields)
    @track_number = Utils.int_from(fields, :track_number)
    @url = fields[:url]
    notify_property(:updated)
  end

  def state = @state

  # The playback state the song rows show. The values are
  # SongWidget::PLAYED, PLAYING and UNPLAYED.
  def state=(state)
    if @state != state
      @state = state
      notify_property(:state)
    end
  end

  def validation = @validation

  def validation=(validation)
    if @validation != validation
      @validation = validation
      notify_property(:validation)
    end
  end

  def favorite? = @favorite

  # Upstream writes the favorite tag back to Tracker here. The Tracker
  # writeback lives in coregrilo.py, which is not ported yet, so starring a
  # song holds for the session the same way it does before upstream's
  # writeback completes.
  def favorite=(favorite)
    if @favorite != favorite
      @favorite = favorite
      notify_property(:favorite)
    end
  end

  def last_played = @last_played

  def last_played=(value)
    if value
      @last_played = value
      notify_property(:last_played)
    end
  end

  def bump_play_count
    @play_count += 1
    notify_property(:play_count)
  end

  # The album art uri, or "generic" while there is none. The first read
  # starts the art lookup and reports the generic cover, as upstream's
  # thumbnail property does.
  def thumbnail
    if @thumbnail.nil?
      @thumbnail = 'generic'
      SongArt.new(self)
    end

    @thumbnail
  end

  def thumbnail=(value)
    @thumbnail = value
    notify_property(:thumbnail)
  end

  # A copy carrying the same tags, which is how the queue holds its own songs
  # without sharing state with the collection.
  def duplicate = CoreSong.new(@fields)
end
