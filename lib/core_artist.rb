# frozen_string_literal: true

require 'adwaita'
require_relative 'core_album'

# CoreArtist carries all the relevant information about an artist.
#
# Ported from upstream's gnomemusic/coreartist.py: the artist name, an id and
# a model of the artist's albums sorted by year.
#
# Upstream asks CoreGrilo to fill the album filter model; the data source is
# not ported yet, so CoreModel hands the artist its albums.
class CoreArtist < GLib::Object
  type_register

  include Utils::Observable

  attr_reader :artist, :id

  def initialize(fields, albums)
    super()

    @albums = albums
    @thumbnail = nil
    update(fields)
  end

  def update(fields)
    @id = fields[:id]
    @artist = Utils.artist_from(fields)
    notify_property(:updated)
  end

  def albums = @albums.sort_by { |corealbum| corealbum.year.to_s }

  def model
    @model ||= Gio::ListStore.new(CoreAlbum).tap do |store|
      albums.each { |corealbum| store.append(corealbum) }
    end
  end

  # The artist art uri, or "generic" while there is none. The art pipeline
  # (artistart.py and friends) is not ported yet, so every artist reports the
  # generic image.
  def thumbnail = @thumbnail ||= 'generic'

  def thumbnail=(value)
    @thumbnail = value
    notify_property(:thumbnail)
  end
end
