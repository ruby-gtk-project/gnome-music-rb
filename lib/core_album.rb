# frozen_string_literal: true

require 'adwaita'
require_relative 'core_disc'

# CoreAlbum carries all the relevant information about an album.
#
# Ported from upstream's gnomemusic/corealbum.py: artist, composer, duration,
# id, title, url and year, plus a model of the album's discs sorted by disc
# number.
#
# Upstream asks CoreGrilo for the discs; the data source is not ported yet, so
# the album is built from the songs CoreModel groups for it and splits them
# into discs itself.
class CoreAlbum < GLib::Object
  type_register

  include Utils::Observable

  attr_reader :artist, :composer, :id, :title, :url, :year

  def initialize(fields, songs)
    super()

    @songs = songs
    @thumbnail = nil
    update(fields)
  end

  def update(fields)
    @artist = Utils.artist_from(fields)
    @composer = fields[:composer]
    @id = fields[:id]
    @title = Utils.title_from(fields)
    @url = fields[:url]
    @year = fields[:publication_date]
    notify_property(:updated)
  end

  def songs = @songs.dup

  # The summed duration of every disc, which is what the album widget's
  # "year, N minutes" line reports.
  def duration = discs.sum(&:duration)

  def discs
    @discs ||= @songs.group_by(&:album_disc_number)
                     .sort_by { |disc_nr, _| disc_nr }
                     .map { |disc_nr, disc_songs| CoreDisc.new(self, disc_nr, disc_songs) }
  end

  def model
    @model ||= Gio::ListStore.new(CoreDisc).tap do |store|
      discs.each { |coredisc| store.append(coredisc) }
    end
  end

  # Removes the given song from the given disc of this album.
  def remove_song_from_album(disc_nr, song_id)
    discs.find { |coredisc| coredisc.disc_nr == disc_nr }.then do |coredisc|
      if coredisc
        coredisc.remove_song_from_disc(song_id)
        notify_property(:duration)
      end
    end
  end

  # The album art uri, or "generic" while there is none. The art pipeline
  # (albumart.py and friends) is not ported yet, so every album reports the
  # generic cover.
  def thumbnail = @thumbnail ||= 'generic'

  def thumbnail=(value)
    @thumbnail = value
    notify_property(:thumbnail)
  end

  def corealbum = self
end
