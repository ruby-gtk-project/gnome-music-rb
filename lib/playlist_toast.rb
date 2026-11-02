# frozen_string_literal: true

require 'adwaita'

# PlaylistToast reports a playlist being deleted, and offers undo.
#
# A direct port of upstream's gnomemusic/playlisttoast.py: the playlist is
# staged for deletion straight away so it leaves the sidebar, and the
# deletion is either undone by the button or committed when the toast is
# dismissed.
#
# Upstream reaches the undo through a per-toast action it installs on the
# window with install_action, which the Ruby bindings do not expose; the
# toast's own button-clicked signal does the same job.
class PlaylistToast
  def initialize(application, playlist)
    @application = application
    @playlists = application.playlists
    @coremodel = application.coremodel
    @playlist = playlist
    @undo = false
  end

  def build
    @application.window.tap do |window|
      toast.tap do |t|
        t.button_label = 'Undo'
        t.signal_connect('button-clicked') { on_undo }
        t.signal_connect('dismissed') { on_dismissed }
      end

      @playlists.stage_deletion(@playlist)
      refresh_models
      window.add_toast(toast)
    end

    self
  end

  def toast = @toast ||= Adwaita::Toast.new("Playlist #{@playlist.title} removed")

  private

    def on_undo
      @undo = true
      @playlists.finish_deletion(@playlist, false)
      refresh_models
    end

    def on_dismissed
      unless @undo
        @playlists.finish_deletion(@playlist, true)
        refresh_models
      end
    end

    def refresh_models
      @coremodel.set_playlists(@playlists.playlists)
      @coremodel.refresh_user_playlists
    end
end
