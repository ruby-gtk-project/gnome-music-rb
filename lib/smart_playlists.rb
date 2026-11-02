# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist'

# The smart playlists: the playlists Music builds for the user rather than
# the ones the user creates.
#
# Ported from upstream's gnomemusic/grilowrappers/smartplaylist.py. Each
# playlist keeps upstream's non-translatable tag text, its user facing title
# and its icon, and the same selection and ordering:
#
#   Most Played            play count, descending, 50 songs
#   Never Played           never played, least recently accessed first, 50
#   Recently Played        played in the last week, most recent first, 50
#   Recently Added         added in the last week, most recent first, 50
#   Starred Songs          the favorite tag, most recently added first
#   Insufficiently Tagged  no album or no artist
#   All Songs              everything, by artist, album, track number
#
# Upstream expresses each of these as a SPARQL query against Tracker. Tracker
# is not ported, so each playlist carries the same selection as a predicate
# over the collection CoreModel holds, and #update re-runs it.
class SmartPlaylist < Playlist
  type_register

  LIMIT = 50
  WEEK_IN_SECONDS = 7 * 86_400

  def initialize(collection:, store:)
    super(pl_id: self.class::TAG_TEXT, title: self.class::TITLE, store: store)

    @collection = collection
    @tag_text = self.class::TAG_TEXT
    @icon_name = self.class::ICON_NAME
  end

  def smart? = true

  def songs = select_songs(@collection.songs)

  def model
    @model ||= Gio::ListStore.new(CoreSong).tap do |store|
      songs.each { |coresong| store.append(coresong) }
    end
  end

  # Re-runs the selection. Upstream re-executes the query.
  def update
    songs.then do |current|
      model.tap do |store|
        store.remove_all
        current.each { |coresong| store.append(coresong) }
      end
    end
    notify_property(:count)
  end

  # The cut-off upstream computes as midnight, a week back, in UTC.
  def self.week_ago = Time.now.utc - WEEK_IN_SECONDS

  class MostPlayed < SmartPlaylist
    type_register

    TAG_TEXT = 'MOST_PLAYED'
    # TRANSLATORS: this is a playlist name
    TITLE = 'Most Played'
    ICON_NAME = 'audio-speakers-symbolic'

    def select_songs(songs)
      songs.select { |coresong| coresong.play_count.positive? }
           .sort_by { |coresong| -coresong.play_count }
           .first(LIMIT)
    end
  end

  class NeverPlayed < SmartPlaylist
    type_register

    TAG_TEXT = 'NEVER_PLAYED'
    # TRANSLATORS: this is a playlist name
    TITLE = 'Never Played'
    ICON_NAME = 'deaf-symbolic'

    def select_songs(songs)
      songs.select { |coresong| coresong.play_count.zero? }
           .sort_by { |coresong| coresong.fields[:last_accessed].to_s }
           .first(LIMIT)
    end
  end

  class RecentlyPlayed < SmartPlaylist
    type_register

    TAG_TEXT = 'RECENTLY_PLAYED'
    # TRANSLATORS: this is a playlist name
    TITLE = 'Recently Played'
    ICON_NAME = 'document-open-recent-symbolic'

    def select_songs(songs)
      SmartPlaylist.week_ago.then do |cut_off|
        songs.select { |coresong| coresong.last_played && coresong.last_played > cut_off }
             .sort_by { |coresong| -coresong.last_played.to_i }
             .first(LIMIT)
      end
    end
  end

  class RecentlyAdded < SmartPlaylist
    type_register

    TAG_TEXT = 'RECENTLY_ADDED'
    # TRANSLATORS: this is a playlist name
    TITLE = 'Recently Added'
    ICON_NAME = 'list-add-symbolic'

    def select_songs(songs)
      SmartPlaylist.week_ago.then do |cut_off|
        songs.select { |coresong| coresong.fields[:added] && coresong.fields[:added] > cut_off }
             .sort_by { |coresong| -coresong.fields[:added].to_i }
             .first(LIMIT)
      end
    end
  end

  class Favorites < SmartPlaylist
    type_register

    TAG_TEXT = 'FAVORITES'
    # TRANSLATORS: this is a playlist name
    TITLE = 'Starred Songs'
    ICON_NAME = 'starred-symbolic'

    def select_songs(songs)
      songs.select(&:favorite?)
           .sort_by { |coresong| -coresong.fields[:added].to_i }
    end
  end

  class InsufficientTagged < SmartPlaylist
    type_register

    TAG_TEXT = 'INSUFFICIENT_TAGGED'
    # TRANSLATORS: this is a playlist name indicating that the files are not
    # tagged enough to be displayed in the albums or artists views.
    TITLE = 'Insufficiently Tagged'
    ICON_NAME = 'question-round-symbolic'

    def select_songs(songs)
      songs.select do |coresong|
        coresong.album.to_s.strip.empty? || coresong.fields[:artist].to_s.strip.empty?
      end
    end
  end

  class AllSongs < SmartPlaylist
    type_register

    TAG_TEXT = 'ALL_SONGS'
    # TRANSLATORS: this is a playlist name
    TITLE = 'All Songs'
    ICON_NAME = 'folder-music-symbolic'

    def select_songs(songs)
      songs.sort_by do |coresong|
        [coresong.artist.to_s, coresong.album.to_s, coresong.track_number]
      end
    end
  end

  # The order the playlists view lists them in, which is upstream's order in
  # localsearchplaylists.py.
  ALL_SMART_PLAYLISTS = [
    MostPlayed,
    NeverPlayed,
    RecentlyPlayed,
    RecentlyAdded,
    Favorites,
    InsufficientTagged,
    AllSongs,
  ].freeze
end
