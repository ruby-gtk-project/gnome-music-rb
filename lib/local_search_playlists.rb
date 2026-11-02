# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'time'
require 'fileutils'
require 'securerandom'
require_relative 'playlist'
require_relative 'smart_playlists'

# LocalSearchPlaylists owns the playlists: the seven smart ones Music builds
# and the ones the user creates.
#
# Ported from upstream's gnomemusic/grilowrappers/localsearchplaylists.py: it
# fills the playlists model, creates and deletes user playlists, and holds a
# deletion aside so the toast can undo it.
#
# Upstream stores user playlists in Tracker as nmm:Playlist resources and
# every operation is a SPARQL update. Tracker is not ported, so the same data
# — a title, a creation date and an ordered list of song urls — lives in a
# JSON file under XDG_DATA_HOME, and song urls are resolved back to CoreSongs
# through the collection. The playlists survive a restart, which is the part
# of the Tracker behaviour that matters to the user.
class LocalSearchPlaylists
  def initialize(collection:, path: nil)
    @collection = collection
    @path = path || default_path
    @playlists = []
    @staged = {}
  end

  # Builds the smart playlists and loads the user playlists from disk.
  def load
    SmartPlaylist::ALL_SMART_PLAYLISTS.each do |klass|
      @playlists << klass.new(collection: @collection, store: self)
    end

    read.each do |record|
      @playlists << playlist_from(record)
    end

    @playlists.dup
  end

  def playlists = @playlists.dup
  def user_playlists = @playlists.reject(&:smart?)
  def location = @path

  # Creates a user playlist and hands it back, so the dialog can select it.
  def create(title)
    Playlist.new(
      pl_id:         SecureRandom.uuid,
      title:         title,
      store:         self,
      creation_date: Time.now.utc,
    ).tap do |playlist|
      @playlists << playlist
      write
    end
  end

  # Takes a playlist out of the model, keeping it aside for the toast.
  def stage_deletion(playlist)
    @playlists.index(playlist).then do |position|
      if position
        @staged[playlist.pl_id] = position
        @playlists.delete_at(position)
      end
    end
  end

  # Finishes a staged deletion: committed deletes it, otherwise it goes back
  # where it was.
  def finish_deletion(playlist, commit)
    @staged.delete(playlist.pl_id).then do |position|
      if commit
        write
      else
        @playlists.insert(position || @playlists.length, playlist)
      end
    end
  end

  # --- Called by Playlist as its operations land -------------------------

  def rename(_playlist, _new_name) = write
  def add_songs(_playlist, _coresongs) = write
  def remove_song(_playlist, _position) = write
  def reorder(_playlist, _previous_position, _new_position) = write

  private

    def playlist_from(record)
      Playlist.new(
        pl_id:         record['id'],
        title:         record['title'],
        store:         self,
        creation_date: parse_time(record['creation-date']),
        songs:         songs_for(record['songs']),
      )
    end

    # Playlist entries are stored as song urls, which is how they survive a
    # collection reload: the song objects are rebuilt on every start.
    def songs_for(urls)
      @collection.songs.each_with_object({}) { |song, by_url| by_url[song.url] = song }
                 .then { |by_url| urls.to_a.filter_map { |url| by_url[url]&.duplicate } }
    end

    def parse_time(value)
      if value
        Time.parse(value).utc
      end
    rescue ArgumentError
      nil
    end

    def default_path
      File.join(
        ENV.fetch('XDG_DATA_HOME', File.expand_path('~/.local/share')),
        'ruby-music',
        'playlists.json',
      )
    end

    def read
      if File.exist?(@path)
        JSON.parse(File.read(@path))
      else
        []
      end
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      []
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(user_playlists.map { |playlist| record_for(playlist) }))
    end

    def record_for(playlist)
      {
        'id'            => playlist.pl_id,
        'title'         => playlist.title,
        'creation-date' => playlist.creation_date&.iso8601,
        'songs'         => playlist.songs.map(&:url),
      }
    end
end
