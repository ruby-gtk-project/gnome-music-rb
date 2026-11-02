# frozen_string_literal: true

require 'adwaita'
require_relative 'core_song'

# CoreDisc is one disc of an album.
#
# Ported from upstream's gnomemusic/coredisc.py: an id, a disc number, the
# summed duration of its songs and a model of those songs sorted by track
# number.
#
# Upstream asks CoreGrilo to fill the disc's filter model; the data source is
# not ported yet, so the songs are handed in by CoreAlbum, which groups the
# album's songs by disc number.
class CoreDisc < GLib::Object
  type_register

  include Utils::Observable

  attr_reader :id, :disc_nr

  def initialize(corealbum, nr, songs)
    super()

    @id = corealbum.id
    @disc_nr = nr
    @songs = songs.sort_by(&:track_number)
    @duration = @songs.sum(&:duration)
  end

  def songs = @songs.dup

  def duration = @duration

  def model
    @model ||= Gio::ListStore.new(CoreSong).tap do |store|
      @songs.each { |coresong| store.append(coresong) }
    end
  end

  # Drops a song from this disc. Upstream re-reads the whole disc from
  # Tracker; here the disc owns its songs, so it removes the one song.
  def remove_song_from_disc(song_id)
    @songs.index { |coresong| coresong.id == song_id }.then do |position|
      if position
        @songs.delete_at(position)
        model.remove(position)
        @duration = @songs.sum(&:duration)
        notify_property(:duration)
      end
    end
  end
end
