# frozen_string_literal: true

require 'adwaita'
require_relative 'core_album'
require_relative 'core_artist'
require_relative 'core_song'
require_relative 'playlist'
require_relative 'queue'
require_relative 'shuffle_list_model'
require_relative 'utils'

# CoreModel provides all the global list models used in Music.
#
# Ported from upstream's gnomemusic/coremodel.py. Music keeps a hierarchy of
# data objects with list models holding what the user has:
#
#   CoreArtist -> CoreAlbum -> CoreDisc -> CoreSong
#
# with playlists alongside it:
#
#   LocalSearchPlaylists -> Playlist -> CoreSong
#
# and the queue as a copy of whichever of those is playing.
#
# Two things differ from upstream. First, upstream's models are chains of
# Gtk.FlattenListModel and Gtk.SortListModel fed by the Tracker wrappers; the
# collection here is held as Ruby arrays with list stores built in sorted
# order on top, because reading an object back out of a GTK model can hand
# back a wrapper for memory the store has already dropped. Second, upstream's
# search is a Tracker query driven by CoreGrilo; the data source is not ported
# yet, so #search filters the collection in process through Gtk::CustomFilter.
#
# The recent-queue slice upstream keeps for MPRIS is not here: MPRIS is not
# ported yet.
class CoreModel
  include Utils::Observable

  def initialize(search)
    @search = search
    @songs = []
    @albums = []
    @artists = []
    @active_core_object = nil
    @songs_available = false
    @query = ''
    @queue_loaded_listeners = []
    @once_listeners = {}
    @smart_playlist_listeners = []
  end

  # --- The collection ----------------------------------------------------

  def songs = @songs.dup
  def albums = @albums.dup
  def artists = @artists.dup

  # Fills the collection from the tag hashes a data source produced. The data
  # sources themselves (coregrilo.py, localsearchwrapper.py) are not ported
  # yet; this is the entry point they fill.
  def load(song_fields)
    song_fields.map { |fields| CoreSong.new(fields) }.then do |coresongs|
      @songs = coresongs.sort { |a, b| songs_sort(a, b) }
      build_albums
      build_artists
      refill_stores
      update_songs_available
    end
  end

  def songs_model
    @songs_model ||= Gio::ListStore.new(CoreSong).tap do |store|
      @songs.each { |coresong| store.append(coresong) }
    end
  end

  def albums_model
    @albums_model ||= Gio::ListStore.new(CoreAlbum).tap do |store|
      @albums.each { |corealbum| store.append(corealbum) }
    end
  end

  def artists_model
    @artists_model ||= Gio::ListStore.new(CoreArtist).tap do |store|
      @artists.each { |coreartist| store.append(coreartist) }
    end
  end

  def songs_available? = @songs_available

  # --- Playlists ---------------------------------------------------------

  # The playlists model, in upstream's order: the smart playlists first, by
  # natural order of their titles, then the user's, newest first.
  def playlists_model
    @playlists_model ||= Gio::ListStore.new(Playlist)
  end

  def playlists = playlists_store

  def set_playlists(playlists)
    @playlists = playlists.sort { |a, b| playlists_sort(a, b) }
    playlists_model.tap do |store|
      store.remove_all
      @playlists.each { |playlist| store.append(playlist) }
    end
  end

  def user_playlists_model
    @user_playlists_model ||= Gio::ListStore.new(Playlist)
  end

  def refresh_user_playlists
    user_playlists_model.tap do |store|
      store.remove_all
      playlists_store.reject(&:smart?).each { |playlist| store.append(playlist) }
    end
  end

  def smart_playlists_changed
    @smart_playlist_listeners.dup.each(&:call)
  end

  def on_smart_playlist_change(&block)
    @smart_playlist_listeners << block
    block
  end

  # --- Search ------------------------------------------------------------

  # Filters the collection by the given term. Upstream hands the term to
  # Grilo, which queries Tracker; here it narrows the three search models.
  def search(term)
    @query = Utils.normalize_caseless(term)
    [songs_search_filter, albums_search_filter, artists_search_filter].each do |filter|
      filter.changed(Gtk::FilterChange::DIFFERENT)
    end
    @query
  end

  def search_term = @query

  def songs_search = @songs_search ||= Gtk::FilterListModel.new(songs_model, songs_search_filter)
  def albums_search = @albums_search ||= Gtk::FilterListModel.new(albums_model, albums_search_filter)

  def artists_search
    @artists_search ||= Gtk::FilterListModel.new(artists_model, artists_search_filter)
  end

  def songs_search_filter
    @songs_search_filter ||= Gtk::CustomFilter.new do |coresong|
      matches?(coresong.title, coresong.artist, coresong.album)
    end
  end

  def albums_search_filter
    @albums_search_filter ||= Gtk::CustomFilter.new do |corealbum|
      matches?(corealbum.title, corealbum.artist)
    end
  end

  def artists_search_filter
    @artists_search_filter ||= Gtk::CustomFilter.new do |coreartist|
      matches?(coreartist.artist)
    end
  end

  # --- The queue ---------------------------------------------------------

  def queue_model = @queue_model ||= Gio::ListStore.new(CoreSong)
  def queue = @queue ||= ShuffleListModel.new(queue_model)

  def on_queue_loaded(&block)
    @queue_loaded_listeners << block
    block
  end

  def off_queue_loaded(block)
    @queue_loaded_listeners.delete(block)
  end

  # Registers a listener that runs for the next queue load only, which is how
  # upstream's callers connect to queue-loaded and disconnect inside the
  # handler before telling the player to play.
  def once_queue_loaded(&block)
    on_queue_loaded do |queue_type|
      off_queue_loaded(@once_listeners.delete(block))
      block.call(queue_type)
    end.then { |listener| (@once_listeners ||= {})[block] = listener }
  end

  def active_core_object = @active_core_object

  # Sets what is playing — an album, an artist, a playlist, a search result or
  # the songs view — and fills the queue from it.
  def active_core_object=(value)
    @active_core_object = value

    case value
    when CoreAlbum then set_queue(PlayQueue::ALBUM, album_songs(value))
    when CoreArtist then set_queue(PlayQueue::ARTIST, artist_songs(value))
    when Playlist then set_queue(PlayQueue::PLAYLIST, value.songs)
    else set_queue(*songs_queue)
    end
  end

  private

    def playlists_store = @playlists ||= []

    # If the search view is up, the queue is the search result; otherwise it
    # is the songs view.
    def songs_queue
      if @search.search_mode_active?
        [PlayQueue::SEARCH_RESULT, filtered_songs]
      else
        [PlayQueue::SONGS, @songs]
      end
    end

    def filtered_songs
      @songs.select { |coresong| matches?(coresong.title, coresong.artist, coresong.album) }
    end

    def album_songs(corealbum) = corealbum.discs.flat_map(&:songs)

    def artist_songs(coreartist)
      coreartist.albums.flat_map { |corealbum| album_songs(corealbum) }
    end

    # The queue holds copies, so the playback state of the queue does not
    # write back onto the rows of the view the user is browsing.
    def set_queue(queue_type, coresongs)
      queue_model.tap do |store|
        store.remove_all
        coresongs.each { |coresong| store.append(coresong.duplicate) }
      end

      @queue_loaded_listeners.dup.each { |listener| listener.call(queue_type) }
    end

    def matches?(*fields)
      @query.empty? || fields.any? do |field|
        Utils.normalize_caseless(field).include?(@query)
      end
    end

    # Upstream sorts songs by title, then artist, then album, each in natural
    # order.
    def songs_sort(song_a, song_b)
      [
        [song_a.title, song_b.title],
        [song_a.artist, song_b.artist],
        [song_a.album, song_b.album],
      ].lazy.map { |field_a, field_b| natural_compare(field_a, field_b) }
       .find(&:nonzero?) || 0
    end

    # Upstream sorts the smart playlists first, by natural order of their
    # titles, then the user's playlists, newest first.
    def playlists_sort(playlist_a, playlist_b)
      if playlist_a.smart? && playlist_b.smart?
        natural_compare(playlist_a.title, playlist_b.title)
      elsif playlist_a.smart?
        -1
      elsif playlist_b.smart?
        1
      else
        playlist_b.creation_date.to_i <=> playlist_a.creation_date.to_i
      end
    end

    def build_albums
      @albums = @songs.group_by { |coresong| [coresong.album.to_s, coresong.artist.to_s] }
                      .map { |(album, _artist), album_songs| album_for(album, album_songs) }
                      .sort { |a, b| natural_compare(a.title, b.title) }
    end

    def album_for(album, album_songs)
      album_songs.first.then do |first|
        CoreAlbum.new(
          {
            id:               first.album_urn || "album:#{album}:#{first.artist}",
            title:            album,
            artist:           first.artist,
            album_artist:     first.fields[:album_artist],
            composer:         first.fields[:composer],
            publication_date: first.fields[:publication_date],
            url:              first.url,
          },
          album_songs,
        )
      end
    end

    def build_artists
      @artists = @albums.group_by(&:artist)
                        .map { |artist, artist_albums| artist_for(artist, artist_albums) }
                        .sort { |a, b| natural_compare(a.artist, b.artist) }
    end

    def artist_for(artist, artist_albums)
      CoreArtist.new({ id: "artist:#{artist}", artist: artist }, artist_albums)
    end

    def natural_compare(name_a, name_b)
      Utils.natural_sort_names(name_a, name_b).then do |ordering|
        case ordering
        when Gtk::Ordering::SMALLER then -1
        when Gtk::Ordering::LARGER then 1
        else 0
        end
      end
    end

    def refill_stores
      [[songs_model, @songs], [albums_model, @albums], [artists_model, @artists]].each do |store, items|
        store.remove_all
        items.each { |item| store.append(item) }
      end
    end

    def update_songs_available
      @songs.any?.then do |available|
        if @songs_available != available
          @songs_available = available
          notify_property(:songs_available)
        end
      end
    end
end
