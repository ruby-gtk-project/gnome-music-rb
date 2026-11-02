# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist'
require_relative 'playlist_dialog'
require_relative 'song_toast'

# SongWidgetMenu is the menu on a song row.
#
# Ported from upstream's gnomemusic/widgets/songwidgetmenu.py and
# data/ui/SongWidgetMenu.ui: Play, Add to Playlist… and, for a song in a
# user playlist, Remove from Playlist. As upstream does, the remove item is
# dropped from the model when the row is not in a playlist.
#
# Upstream's "Open Location" item is built but never added to the menu, and
# its callback does nothing; it is left out here rather than ported as an
# item that does nothing.
class SongWidgetMenu < Gtk::PopoverMenu
  def initialize(application, song_widget, coreobject)
    super()

    @application = application
    @coremodel = application.coremodel
    @player = application.player
    @window = application.window
    @song_widget = song_widget
    @coreobject = coreobject
    @coresong = resolve_coresong

    self.autohide = true
    self.position = :bottom
  end

  def build
    tap do |popover|
      popover.menu_model = menu_model
      popover.insert_action_group('songwidget', action_group)

      action_group.tap do |group|
        group.add_action(action('play') { play_song })
        group.add_action(action('add_playlist') { add_to_playlist })

        if removable?
          group.add_action(action('remove_playlist') { remove_from_playlist })
        end
      end
    end
  end

  def menu_model
    @menu_model ||= Gio::Menu.new.tap do |menu|
      menu.append('_Play', 'songwidget.play')
      menu.append('_Add to Playlist…', 'songwidget.add_playlist')

      if removable?
        menu.append('_Remove from Playlist', 'songwidget.remove_playlist')
      end
    end
  end

  def action_group = @action_group ||= Gio::SimpleActionGroup.new

  private

    def resolve_coresong
      if @song_widget.respond_to?(:coresong)
        @song_widget.coresong
      else
        @coreobject
      end
    end

    def removable? = @coreobject.is_a?(Playlist) && !@coreobject.smart?

    def action(name, &block)
      Gio::SimpleAction.new(name).tap do |simple_action|
        simple_action.signal_connect('activate') { block.call }
      end
    end

    # The queue has to be loaded before the player can be told what to play,
    # which is why upstream waits for the queue-loaded signal.
    def play_song
      popdown
      @coremodel.once_queue_loaded { @player.play(@coresong) }
      @coremodel.active_core_object = @coreobject
    end

    def add_to_playlist
      popdown
      PlaylistDialog.new(@application, [@coresong]).tap do |dialog|
        dialog.build
        dialog.present(@window)
      end
    end

    def remove_from_playlist
      popdown
      SongToast.new(
        @application,
        @coreobject,
        @song_widget.index,
        @coresong,
      ).build
    end
end
