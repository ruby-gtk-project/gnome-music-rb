# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist_controls'
require_relative 'song_widget'
require_relative 'song_widget_menu'

# PlaylistsWidget is the content side of the playlists view: the playlist
# controls above the playlist's songs.
#
# A direct port of upstream's gnomemusic/widgets/playlistswidget.py and
# data/ui/PlaylistsWidget.ui. The rows of a user playlist can be dragged to
# reorder it; the rows of a smart playlist cannot, and a smart playlist is
# re-run every time it is shown.
class PlaylistsWidget < Gtk::Box
  def initialize(application, playlists_view)
    super(:vertical, 0)

    @application = application
    @window = application.window
    @coremodel = application.coremodel
    @player = application.player
    @playlists_view = playlists_view
  end

  def build
    tap do |box|
      box.append(controls_clamp)
      box.append(songs_scroller)

      controls_clamp.child = playlist_controls.build
      playlist_controls.application = @application

      songs_scroller.child = songs_clamp
      songs_clamp.child = songs_list

      songs_list.signal_connect('row-activated') do |_, song_widget|
        play(song_widget.coresong)
        true
      end

      @playlists_view.on_current_playlist_changed { on_current_playlist_changed }
      @coremodel.on_smart_playlist_change { on_smart_playlist_change }

      @window.lookup_action('playlist_play').signal_connect('activate') { play(nil) }
    end
  end

  def rename_active? = playlist_controls.rename_active?

  # Memoized widget methods

  def controls_clamp
    @controls_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 1000
    end
  end

  def playlist_controls = @playlist_controls ||= PlaylistControls.new

  def songs_scroller
    @songs_scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.vexpand = true
    end
  end

  def songs_clamp
    @songs_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 1000
      clamp.valign = :start
    end
  end

  def songs_list
    @songs_list ||= Gtk::ListBox.new.tap do |list|
      list.margin_top = 20
      list.margin_bottom = 20
      list.add_css_class('boxed-list')
    end
  end

  private

    def on_current_playlist_changed
      @playlists_view.current_playlist.then do |playlist|
        if playlist
          show_playlist(playlist)
        end
      end
    end

    def show_playlist(playlist)
      songs_list.bind_model(playlist.model) { |coresong| create_song_widget(coresong, playlist) }

      if playlist.smart?
        playlist.update
      end

      playlist_controls.playlist = playlist
    end

    def create_song_widget(coresong, playlist)
      (!playlist.smart?).then do |can_dnd|
        SongWidget.new(coresong, can_dnd: can_dnd, show_artist_and_album: true)
                  .build
                  .tap { |song_widget| configure_song_widget(song_widget, playlist, can_dnd) }
      end
    end

    def configure_song_widget(song_widget, playlist, can_dnd)
      song_widget.show_song_number = false
      song_widget.menu = SongWidgetMenu.new(@application, song_widget, playlist).build

      if can_dnd
        song_widget.on_widget_moved do |source_position|
          on_song_widget_moved(song_widget, source_position)
        end
      end
    end

    def on_song_widget_moved(target, source_position)
      @playlists_view.current_playlist&.reorder(source_position, target.index)
    end

    def on_smart_playlist_change
      @playlists_view.current_playlist.then do |playlist|
        if playlist&.smart?
          playlist.update
        end
      end
    end

    def play(coresong)
      @coremodel.once_queue_loaded { @player.play(coresong) }
      @coremodel.active_core_object = @playlists_view.current_playlist
    end
end
