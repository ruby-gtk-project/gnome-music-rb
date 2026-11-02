# frozen_string_literal: true

require 'adwaita'
require_relative 'core_song'

# Playlist is one playlist and the songs in it.
#
# Ported from upstream's gnomemusic/grilowrappers/playlist.py: the count,
# creation date, icon name, id, title and the model of songs, plus the
# operations the UI drives — adding songs, renaming, reordering and the
# three-step song deletion (stage, undo, finish) the toast needs.
#
# Upstream runs each operation as a SPARQL update against Tracker. Tracker is
# not ported, so the playlist asks its store to persist the change; see
# local_search_playlists.rb for what that store is.
class Playlist < GLib::Object
  type_register

  include Utils::Observable

  DEFAULT_ICON = 'music-playlist-symbolic'

  attr_reader :pl_id, :creation_date, :tag_text, :icon_name

  def initialize(pl_id:, title:, store:, creation_date: nil, songs: [])
    super()

    @pl_id = pl_id
    @title = title
    @store = store
    @creation_date = creation_date
    @songs = songs
    @songs_todelete = []
    @tag_text = nil
    @icon_name = DEFAULT_ICON
  end

  def smart? = false

  def title = @title

  def title=(new_name)
    if !new_name.to_s.empty? && new_name != @title
      @title = new_name
      @store.rename(self, new_name)
      notify_property(:title)
    end
  end

  def count = songs.length

  def songs = @songs.dup

  def model
    @model ||= Gio::ListStore.new(CoreSong).tap do |store|
      @songs.each { |coresong| store.append(coresong) }
    end
  end

  # Adds songs to the playlist. Each song is copied, as upstream does, so the
  # playlist's rows carry their own playback state.
  def add_songs(coresongs)
    coresongs.each do |coresong|
      coresong.duplicate.tap do |copy|
        @songs << copy
        model.append(copy)
      end
    end
    @store.add_songs(self, coresongs)
    notify_property(:count)
  end

  # Takes the song out of the view, keeping it aside until the toast is either
  # dismissed or undone.
  def stage_song_deletion(coresong, index)
    @songs_todelete << coresong
    @songs.delete_at(index)
    model.remove(index)
    notify_property(:count)
  end

  def undo_pending_song_deletion(coresong, position)
    @songs_todelete.delete(coresong)
    @songs.insert(position, coresong)
    model.insert(position, coresong)
    notify_property(:count)
  end

  # Commits a staged deletion.
  def finish_song_deletion(coresong, position)
    @songs_todelete.delete(coresong)
    @store.remove_song(self, position)
  end

  # Moves a song within the playlist.
  def reorder(previous_position, new_position)
    @songs.delete_at(previous_position).then do |coresong|
      if coresong
        @songs.insert(new_position, coresong)
        model.remove(previous_position)
        model.insert(new_position, coresong)
        @store.reorder(self, previous_position, new_position)
      end
    end
  end
end
